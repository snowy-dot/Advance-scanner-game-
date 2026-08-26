--!nocheck
-- ══════════════════════════════════════════════════════════════
--  UNIVERSAL GAME SCANNER v9.1
--  Repo: snowy-dot/Advance-scanner-game-
--  Loader: loadstring(game:HttpGet("YOUR_RAW_URL"))()
-- ══════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

-- ── RAYFIELD LOAD ──────────────────────────────────────────────
local Rayfield = nil
local rayfieldSources = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source"
}

for _, url in ipairs(rayfieldSources) do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and result and result.CreateWindow then
        Rayfield = result
        break
    end
end

if not Rayfield then
    warn("[Scanner] Rayfield failed to load, console-only mode")
end

-- ── STATE ──────────────────────────────────────────────────────
local State = {
    scanning       = false,
    deepScanning   = false,
    results        = {},
    hashes         = {},
    remotes        = {events={}, functions={}, bindables={}, bindableFuncs={}},
    objects        = {prompts={}, clickDetectors={}, humanoids={}, spawns={}, values={}},
    assets         = {sounds={}, animations={}, decals={}, meshes={}},
    acDetections   = {},
    bdDetections   = {},
    requireMap     = {},
    keywordResults = {},
    stats          = {total=0, success=0, failed=0, deduped=0, skipped=0},
    excludeBuildings = true,
    maxDepth       = 0,
    deepData       = {remoteCalls={}, promptHits={}, spawns={}}
}

local connections = {}

local excludedClasses = {
    "Part", "WedgePart", "CornerWedgePart", "TrussPart",
    "SpawnLocation", "Seat", "VehicleSeat"
}
local excludedKeywords = {
    "building","house","wall","floor","ceiling","roof",
    "door","window","structure","terrain","baseplate","ground"
}

-- ── UTILITY ────────────────────────────────────────────────────
local function quickHash(str)
    if not str then return "nil" end
    local h = 5381
    for i = 1, #str do
        h = (h * 33) ~ string.byte(str, i)
        h = h % 0x100000000
    end
    return string.format("%08x", h)
end

local function getScriptSource(script)
    if type(getsrc) == "function" then
        local ok, r = pcall(getsrc, script)
        if ok and type(r) == "string" and #r > 0 then return r, "OK" end
    end
    if type(decompile) == "function" then
        local ok, r = pcall(decompile, script)
        if ok and type(r) == "string" and #r > 0 then return r, "OK" end
    end
    if type(getscriptbytecode) == "function" then
        local ok, r = pcall(getscriptbytecode, script)
        if ok and type(r) == "string" and #r > 0 then return r, "BYTECODE" end
    end
    return nil, "FAILED"
end

local function notify(title, content, dur)
    dur = dur or 4
    pcall(function()
        if Rayfield and Rayfield.Notify then
            Rayfield:Notify({Title=title, Content=content, Duration=dur})
        else
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title=title, Text=content, Duration=dur})
        end
    end)
end

-- ── BUILDING FILTER ────────────────────────────────────────────
local function shouldScan(inst)
    if not State.excludeBuildings then return true end

    for _, cls in ipairs(excludedClasses) do
        if inst:IsA(cls) then
            State.stats.skipped += 1
            return false
        end
    end

    local ln = inst.Name:lower()
    for _, kw in ipairs(excludedKeywords) do
        if ln:find(kw, 1, true) then
            State.stats.skipped += 1
            return false
        end
    end

    local cur = inst.Parent
    while cur and cur ~= game do
        local pl = cur.Name:lower()
        for _, kw in ipairs(excludedKeywords) do
            if pl:find(kw, 1, true) then
                State.stats.skipped += 1
                return false
            end
        end
        cur = cur.Parent
    end

    return true
end

-- ── CONTAINERS ─────────────────────────────────────────────────
local function getContainers()
    local list = {
        {Workspace, "Workspace"},
        {ReplicatedStorage, "ReplicatedStorage"},
        {game:GetService("ServerScriptService"), "ServerScriptService"},
        {StarterGui, "StarterGui"},
        {game:GetService("StarterPlayer"), "StarterPlayer"}
    }
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerScripts") then
            list[#list+1] = {LocalPlayer.PlayerScripts, "PlayerScripts"}
        end
    end)
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerGui") then
            list[#list+1] = {LocalPlayer.PlayerGui, "PlayerGui"}
        end
    end)
    return list
end

local function getAllDescendants(container, maxDepth)
    local results = {}
    local stack = {{obj=container, depth=0}}

    while #stack > 0 do
        local node = table.remove(stack)
        if node and node.obj then
            for _, child in ipairs(node.obj:GetChildren()) do
                table.insert(results, child)
                if maxDepth <= 0 or node.depth < maxDepth then
                    table.insert(stack, {obj=child, depth=node.depth+1})
                end
            end
        end
        if #results % 300 == 0 then RunService.RenderStepped:Wait() end
    end

    return results
end

-- ── CATEGORIZE ─────────────────────────────────────────────────
local catKeywords = {
    Combat={"combat","damage","weapon","gun","kill","sword","attack"},
    Movement={"walkspeed","fly","noclip","jump","teleport","cframe"},
    Economy={"shop","buy","cash","coin","rebirth","sell","pet","egg"},
    NPC={"npc","monster","enemy","boss","mob","spawn"},
    Remote={"remoteevent","remotefunction","fireserver","invokeserver"},
    DataStore={"datastore","save","load","profile"},
    Security={"anticheat","detect","flag","integrity","checksum"},
    Networking={"httpget","request","webhook","jsonencode"},
    Animation={"animation","animator","motor6d"},
    Audio={"sound","music","sfx"}
}

local function categorize(path, className, source)
    local combined = path:lower()
    if source and #source > 0 then
        combined = combined .. source:lower():sub(1, 5000)
    end
    for cat, kws in pairs(catKeywords) do
        for _, kw in ipairs(kws) do
            if combined:find(kw, 1, true) then return cat end
        end
    end
    if className == "LocalScript"   then return "Client" end
    if className == "Script"        then return "Server" end
    if className == "ModuleScript"  then return "Module" end
    return "Other"
end

-- ── SCAN SCRIPTS ───────────────────────────────────────────────
local function scanScripts()
    State.results = {}
    State.hashes  = {}
    State.stats.total   = 0
    State.stats.success = 0
    State.stats.failed  = 0
    State.stats.deduped = 0

    local allScripts = {}

    for _, cd in ipairs(getContainers()) do
        pcall(function()
            for _, d in ipairs(getAllDescendants(cd[1], State.maxDepth)) do
                if d:IsA("LocalScript") or d:IsA("Script") or d:IsA("ModuleScript") then
                    table.insert(allScripts, {inst=d, container=cd[2]})
                end
            end
        end)
    end

    State.stats.total = #allScripts
    notify("Scanner", "Found " .. #allScripts .. " scripts", 3)

    for i, entry in ipairs(allScripts) do
        local s = entry.inst
        if s.Parent and shouldScan(s) then
            local path = s:GetFullName()
            local hash = quickHash(path)

            if not State.hashes[hash] then
                State.hashes[hash] = true
                local src, status = getScriptSource(s)
                local cls = s.ClassName
                table.insert(State.results, {
                    path=path, name=s.Name, className=cls,
                    category=categorize(path, cls, src),
                    container=entry.container,
                    source=src or "", size=(src and #src or 0),
                    status=status, hash=hash
                })
                if status == "OK" then
                    State.stats.success += 1
                else
                    State.stats.failed += 1
                end
            else
                State.stats.deduped += 1
            end
        end
        if i % 20 == 0 then RunService.RenderStepped:Wait() end
    end

    notify("Scan Complete",
        string.format("✅%d ❌%d 🔄%d 🚫%d",
        State.stats.success, State.stats.failed, State.stats.deduped, State.stats.skipped), 5)
end

-- ── SCAN REMOTES ───────────────────────────────────────────────
local function scanRemotes()
    State.remotes = {events={}, functions={}, bindables={}, bindableFuncs={}}

    for _, cd in ipairs(getContainers()) do
        pcall(function()
            for _, d in ipairs(cd[1]:GetDescendants()) do
                if d:IsA("RemoteEvent") then
                    table.insert(State.remotes.events, {path=d:GetFullName(), name=d.Name})
                elseif d:IsA("RemoteFunction") then
                    table.insert(State.remotes.functions, {path=d:GetFullName(), name=d.Name})
                elseif d:IsA("BindableEvent") then
                    table.insert(State.remotes.bindables, {path=d:GetFullName(), name=d.Name})
                elseif d:IsA("BindableFunction") then
                    table.insert(State.remotes.bindableFuncs, {path=d:GetFullName(), name=d.Name})
                end
            end
        end)
    end

    notify("Remotes",
        string.format("E:%d F:%d BE:%d BF:%d",
        #State.remotes.events, #State.remotes.functions,
        #State.remotes.bindables, #State.remotes.bindableFuncs), 4)
end

-- ── SCAN OBJECTS ───────────────────────────────────────────────
local function scanObjects()
    State.objects = {prompts={}, clickDetectors={}, humanoids={}, spawns={}, values={}};

    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if shouldScan(d) then
                if d:IsA("ProximityPrompt") then
                    table.insert(State.objects.prompts, {
                        path=d:GetFullName(), name=d.Name,
                        hold=d.HoldDuration, action=tostring(d.ActionText)})
                elseif d:IsA("ClickDetector") then
                    table.insert(State.objects.clickDetectors, {path=d:GetFullName(), name=d.Name})
                elseif d:IsA("Model") then
                    local hum = d:FindFirstChildOfClass("Humanoid")
                    if hum and not Players:GetPlayerFromCharacter(d) then
                        local root = d:FindFirstChild("HumanoidRootPart") or d.PrimaryPart
                        table.insert(State.objects.humanoids, {
                            path=d:GetFullName(), name=d.Name,
                            hp=hum.Health, mhp=hum.MaxHealth,
                            ws=hum.WalkSpeed,
                            pos=root and tostring(root.Position) or "?"})
                    end
                elseif d:IsA("SpawnLocation") then
                    table.insert(State.objects.spawns, {path=d:GetFullName(), pos=tostring(d.Position)})
                end

                if d:IsA("IntValue") or d:IsA("NumberValue") or
                   d:IsA("StringValue") or d:IsA("BoolValue") then
                    table.insert(State.objects.values, {
                        path=d:GetFullName(), class=d.ClassName,
                        val=tostring(d.Value):sub(1, 60)})
                end
            end
        end
    end)

    notify("Objects",
        string.format("P:%d CD:%d NPC:%d SP:%d V:%d",
        #State.objects.prompts, #State.objects.clickDetectors,
        #State.objects.humanoids, #State.objects.spawns, #State.objects.values), 4)
end

-- ── SCAN ASSETS ────────────────────────────────────────────────
local function scanAssets()
    State.assets = {sounds={}, animations={}, decals={}, meshes={}}

    for _, root in ipairs({Workspace, ReplicatedStorage}) do
        pcall(function()
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("Sound") then
                    table.insert(State.assets.sounds, {path=d:GetFullName(), id=tostring(d.SoundId)})
                elseif d:IsA("Animation") then
                    table.insert(State.assets.animations, {path=d:GetFullName(), id=tostring(d.AnimationId)})
                elseif d:IsA("Decal") then
                    table.insert(State.assets.decals, {path=d:GetFullName(), tex=tostring(d.Texture)})
                elseif d:IsA("SpecialMesh") or d:IsA("MeshPart") then
                    table.insert(State.assets.meshes, {path=d:GetFullName(), id=tostring(d.MeshId or "")})
                end
            end
        end)
    end

    notify("Assets",
        string.format("S:%d A:%d D:%d M:%d",
        #State.assets.sounds, #State.assets.animations,
        #State.assets.decals, #State.assets.meshes), 4)
end

-- ── SECURITY SCAN ──────────────────────────────────────────────
local acPatterns = {"anticheat","anti-cheat","exploit","detect","flag","tamper","velocity","noclip","speedhack","kick","crash"}
local bdPatterns = {"loadstring(game:httpget","require(","backdoor","getfenv(","setfenv(","admin%.","sourcecode"}

local function scanSecurity()
    State.acDetections = {}
    State.bdDetections = {}
    State.requireMap   = {}

    for _, r in ipairs(State.results) do
        if r.source and #r.source > 0 and r.status == "OK" then
            local lines = r.source:split("\n")

            for li, line in ipairs(lines) do
                local ll = line:lower()

                for _, pat in ipairs(acPatterns) do
                    if ll:find(pat, 1, true) then
                        table.insert(State.acDetections, {
                            script=r.path, line=li, pattern=pat,
                            text=line:gsub("^%s+", ""):sub(1, 100)})
                        break
                    end
                end

                for _, pat in ipairs(bdPatterns) do
                    if ll:find(pat, 1, true) then
                        table.insert(State.bdDetections, {
                            script=r.path, line=li, pattern=pat,
                            text=line:gsub("^%s+", ""):sub(1, 100)})
                        break
                    end
                end

                if ll:find("require(", 1, true) then
                    local arg = line:match("require%s*%(%s*(.-)%s*%)") or "?"
                    table.insert(State.requireMap, {
                        script=r.path, target=arg:sub(1, 80),
                        text=line:gsub("^%s+", ""):sub(1, 100)})
                end
            end
        end
    end

    notify("Security",
        string.format("AC:%d BD:%d Req:%d",
        #State.acDetections, #State.bdDetections, #State.requireMap), 5)
end

-- ── KEYWORD SCAN ───────────────────────────────────────────────
local keywordsList = {"FireServer","InvokeServer","WalkSpeed","Health","Damage","Teleport","CFrame","DataStore","loadstring","require"}

local function scanKeywords()
    State.keywordResults = {}
    for _, kw in ipairs(keywordsList) do
        local m = {keyword=kw, count=0, hits={}}
        local sk = kw:lower()

        for _, r in ipairs(State.results) do
            if r.source and r.status == "OK" then
                local lines = r.source:split("\n")
                for ln, line in ipairs(lines) do
                    if line:lower():find(sk, 1, true) then
                        m.count += 1
                        if #m.hits < 5 then
                            table.insert(m.hits, {
                                script=r.path, line=ln,
                                text=line:gsub("^%s+", ""):sub(1, 90)})
                        end
                    end
                end
            end
        end
        if m.count > 0 then table.insert(State.keywordResults, m) end
    end
end

-- ── DEEP SCAN ──────────────────────────────────────────────────
local originalNamecall = nil
local namecallHooked = false

local function restoreHook()
    if namecallHooked and originalNamecall then
        pcall(function()
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__namecall = originalNamecall
            setreadonly(mt, true)
        end)
        namecallHooked = false
    end
end

local function startDeepScan(duration)
    duration = duration or 300
    if State.deepScanning then return end
    State.deepScanning = true
    State.deepData = {remoteCalls={}, promptHits={}, spawns={}}
    notify("Deep Scan", "Monitoring " .. duration .. "s...", 4)

    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                d.Triggered:Connect(function(plr)
                    if plr == LocalPlayer then
                        table.insert(State.deepData.promptHits, {
                            time=os.date("%H:%M:%S"),
                            prompt=d.Name, path=d:GetFullName()})
                    end
                end)
            end
        end
    end)

    connections.spawnWatch = Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then
            table.insert(State.deepData.spawns, {
                time=os.date("%H:%M:%S"),
                name=d.Name, path=d:GetFullName()})
        end
    end)

    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        originalNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                local args = {...}
                local argStr = ""
                for i, arg in ipairs(args) do
                    local t = typeof(arg) == "Instance" and arg.ClassName or type(arg)
                    argStr = argStr .. string.format("[%d]:%s=%s ",
                        i, t, tostring(arg):sub(1, 30))
                end
                table.insert(State.deepData.remoteCalls, {
                    time=os.date("%H:%M:%S"),
                    method=method, remote=self.Name,
                    path=self:GetFullName(), args=argStr})
            end
            return originalNamecall(self, ...)
        end)
        setreadonly(mt, true)
        namecallHooked = true
    end)

    delay(duration, function()
        if State.deepScanning then stopDeepScan() end
    end)
end

local function stopDeepScan()
    if not State.deepScanning then return end
    State.deepScanning = false
    if connections.spawnWatch then connections.spawnWatch:Disconnect() end
    restoreHook()
    notify("Deep Scan Done",
        string.format("Calls:%d Prompts:%d Spawns:%d",
        #State.deepData.remoteCalls,
        #State.deepData.promptHits, #State.deepData.spawns), 6)
end

-- ── EXPORT ─────────────────────────────────────────────────────
local function exportJSON()
    local export = {
        meta={
            time=os.date("%Y-%m-%d %H:%M:%S"),
            placeId=game.PlaceId,
            jobId=game.JobId,
            version="v9.1"
        },
        stats=State.stats,
        scripts=State.results,
        remotes=State.remotes,
        objects=State.objects,
        assets=State.assets,
        security={
            antiCheat=State.acDetections,
            backdoors=State.bdDetections,
            requires=State.requireMap
        },
        keywords=State.keywordResults,
        deepData=State.deepData
    }
    local json = HttpService:JSONEncode(export)

    if writefile then
        local fname = "scanner_" .. game.PlaceId .. "_" .. os.time() .. ".json"
        writefile(fname, json)
        notify("Export", "Saved: workspace/" .. fname, 5)
    end
    if setclipboard then
        setclipboard(json)
        notify("Clipboard", "Full JSON copied!", 3)
    end
end

-- ══════════════════════════════════════════════════════════════
--  RAYFIELD UI
-- ══════════════════════════════════════════════════════════════

local Window = nil

if Rayfield then
    Window = Rayfield:CreateWindow({
        Name = "Game Scanner v9.1",
        LoadingTitle = "Universal Scanner",
        LoadingSubtitle = "snowy-dot build",
        ConfigurationSaving = {Enabled = false},
        KeySystem = false
    })

    -- TAB MAIN
    local TabMain = Window:CreateTab("Main", 4483345998)
    TabMain:CreateSection("Scanner Control")

    TabMain:CreateButton({
        Name = "🔍 Full Scan (Everything)",
        Callback = function()
            task.spawn(function()
                scanScripts(); scanRemotes(); scanObjects()
                scanAssets(); scanSecurity(); scanKeywords()
                notify("Done", "All scans complete", 4)
            end)
        end
    })

    TabMain:CreateButton({
        Name = "📜 Scripts Only",
        Callback = function() task.spawn(scanScripts) end
    })

    TabMain:CreateButton({
        Name = "📡 Remotes Only",
        Callback = function() task.spawn(scanRemotes) end
    })

    TabMain:CreateButton({
        Name = "🎯 Objects + Assets",
        Callback = function()
            task.spawn(function()
                scanObjects(); scanAssets()
            end)
        end
    })

    TabMain:CreateSection("Stats")
    local StatsLabel = TabMain:CreateLabel("Run a scan first.")
    TabMain:CreateButton({
        Name = "🔄 Refresh Stats",
        Callback = function()
            StatsLabel:Set(string.format(
                "Total:%d ✅%d ❌%d 🔄%d 🚫%d",
                State.stats.total, State.stats.success,
                State.stats.failed, State.stats.deduped, State.stats.skipped))
        end
    })

    -- TAB SCRIPTS
    local TabScr = Window:CreateTab("Scripts", 4483345998)
    TabScr:CreateSection("Browse")
    local ScriptOutput = TabScr:CreateLabel("Run scan first.")
    local selCat = "All"

    TabScr:CreateDropdown({
        Name = "Category Filter",
        Options = {"All","Combat","Movement","Economy","NPC","Remote","DataStore","Security","Networking","Animation","Audio","Client","Server","Module","Other"},
        CurrentOption = "All",
        Callback = function(opt)
            selCat = opt[1]
            local out = ""
            local count = 0
            for _, r in ipairs(State.results) do
                if selCat == "All" or r.category == selCat then
                    count += 1
                    if count <= 40 then
                        local icon = r.status == "OK" and "✅" or "❌"
                        out = out .. icon .. "[" .. r.className .. "] "
                              .. r.name .. "\n   " .. r.path .. "\n\n"
                    end
                end
            end
            if count == 0 then out = "No results." end
            if count > 40 then out = out .. "...+" .. (count-40) .. " more\n" end
            ScriptOutput:Set(out)
        end
    })

    TabScr:CreateButton({
        Name = "📋 Copy All Sources",
        Callback = function()
            local all = ""
            for _, r in ipairs(State.results) do
                if r.status == "OK" and r.source and #r.source > 0 then
                    all = all .. "--=====" .. r.path .. " ["..r.className.."] =====\n"
                          .. r.source .. "\n\n"
                end
            end
            if setclipboard then setclipboard(all) end
            notify("Copy", "Copied " .. #all .. " bytes", 3)
        end
    })

    -- TAB SECURITY
    local TabSec = Window:CreateTab("Security", 4483345998)
    TabSec:CreateSection("Detections")
    local SecLabel = TabSec:CreateLabel("No data yet.")
    TabSec:CreateButton({
        Name = "🛡️ Show Anti-Cheat Hits",
        Callback = function()
            local out = ""
            for i, d in ipairs(State.acDetections) do
                if i > 30 then break end
                out = out .. string.format("%s:L%d [%s]\n  %s\n\n",
                    d.script, d.line, d.pattern, d.text)
            end
            SecLabel:Set(out == "" and "Clean." or out)
        end
    })
    TabSec:CreateButton({
        Name = "🔓 Show Backdoor Hits",
        Callback = function()
            local out = ""
            for i, d in ipairs(State.bdDetections) do
                if i > 30 then break end
                out = out .. string.format("%s:L%d [%s]\n  %s\n\n",
                    d.script, d.line, d.pattern, d.text)
            end
            SecLabel:Set(out == "" and "Clean." or out)
        end
    })
    TabSec:CreateButton({
        Name = "🔗 Show Require Map",
        Callback = function()
            local out = ""
            for i, d in ipairs(State.requireMap) do
                if i > 30 then break end
                out = out .. string.format("%s → %s\n  %s\n\n",
                    d.script, d.target, d.text)
            end
            SecLabel:Set(out == "" and "None." or out)
        end
    })

    -- TAB REMOTES
    local TabRem = Window:CreateTab("Remotes", 4483345998)
    TabRem:CreateSection("Found Remotes")
    local RemLabel = TabRem:CreateLabel("No data yet.")
    TabRem:CreateButton({
        Name = "📡 Refresh Remote List",
        Callback = function()
            local out = ""
            out = out .. "── Events ("..#State.remotes.events..") ──\n"
            for i, e in ipairs(State.remotes.events) do
                if i > 25 then out = out .. "...more\n" break end
                out = out .. "• " .. e.path .. "\n"
            end
            out = out .. "\n── Functions ("..#State.remotes.functions..") ──\n"
            for i, f in ipairs(State.remotes.functions) do
                if i > 25 then out = out .. "...more\n" break end
                out = out .. "• " .. f.path .. "\n"
            end
            RemLabel:Set(out == "" and "Nothing found." or out)
        end
    })

    -- TAB DEEP SCAN
    local TabDeep = Window:CreateTab("Deep Scan", 4483345998)
    TabDeep:CreateSection("Live Monitor")
    TabDeep:CreateButton({
        Name = "▶ Start Deep Scan (300s)",
        Callback = function() startDeepScan(300) end
    })
    TabDeep:CreateButton({
        Name = "⏹ Stop Deep Scan",
        Callback = function() stopDeepScan() end
    })
    local DeepLabel = TabDeep:CreateLabel("No captures yet.")
    TabDeep:CreateButton({
        Name = "👁 View Remote Calls",
        Callback = function()
            local out = ""
            for i, c in ipairs(State.deepData.remoteCalls) do
                if i > 30 then break end
                out = out .. string.format("[%s] %s.%s\n  Path:%s\n  Args:%s\n\n",
                    c.time, c.method, c.remote, c.path, c.args)
            end
            DeepLabel:Set(out == "" and "No calls captured." or out)
        end
    })

    -- TAB EXPORT
    local TabExp = Window:CreateTab("Export", 4483345998)
    TabExp:CreateSection("Dump Results")
    TabExp:CreateButton({
        Name = "💾 Export All to JSON",
        Callback = function() exportJSON() end
    })
    TabExp:CreateButton({
        Name = "📋 Copy Security Report",
        Callback = function()
            local rpt = "===SECURITY REPORT===\n"
            rpt = rpt.."AntiCheat:"..#State.acDetections.." hits\n"
            for _, d in ipairs(State.acDetections) do
                rpt = rpt..string.format("  %s:L%d [%s] %s\n",
                    d.script, d.line, d.pattern, d.text)
            end
            rpt = rpt.."\nBackdoors:"..#State.bdDetections.." hits\n"
            for _, d in ipairs(State.bdDetections) do
                rpt = rpt..string.format("  %s:L%d [%s] %s\n",
                    d.script, d.line, d.pattern, d.text)
            end
            if setclipboard then setclipboard(rpt) end
            notify("Copy", "Security report copied", 3)
        end
    })

    -- TAB SETTINGS
    local TabSet = Window:CreateTab("Settings", 4483345998)
    TabSet:CreateSection("Filter Config")
    TabSet:CreateToggle({
        Name = "🏗️ Exclude Buildings",
        CurrentValue = true,
        Flag = "ExcludeBuildings",
        Callback = function(v)
            State.excludeBuildings = v
            notify("Setting", v and "Buildings excluded" or "Buildings included", 3)
        end
    })
    TabSet:CreateSlider({
        Name = "Max Depth (0=∞)",
        Range = {0, 15}, Increment = 1, Suffix = "lvl",
        CurrentValue = 0, Flag = "MaxDepth",
        Callback = function(v) State.maxDepth = v end
    })

    notify("Scanner Ready", "v9.1 loaded.\nRight Shift toggles UI.", 6)

else
    -- No Rayfield? Run quick console-only auto-scan
    print("[Scanner] Console mode running...")
    task.spawn(scanScripts)
    task.spawn(scanRemotes)
    notify("Console Mode", "Rayfield unavailable, basic scan started", 5)
end

print("═══ Universal Game Scanner v9.1 loaded ═══")
