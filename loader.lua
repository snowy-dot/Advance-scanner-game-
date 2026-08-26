--!nocheck
-- ══════════════════════════════════════════════════════════════
--  UNIVERSAL GAME SCANNER v9.0
--  Bypass Scanner | Excludes Buildings | Rayfield UI
--  Base: snowy-dot/Advance-scanner-game- (improved)
-- ══════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Teams = game:GetService("Teams")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

-- ── RAYFIELD LOAD ─────────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ── STATE ──────────────────────────────────────────────────────
local State = {
    scanning = false,
    deepScanning = false,
    results = {},
    hashes = {},
    remotes = {events={}, functions={}, bindables={}, bindableFuncs={}},
    objects = {prompts={}, clickDetectors={}, humanoids={}, spawns={}, values={} },
    assets = {sounds={}, animations={}, decals={}, meshes={}},
    acDetections = {},
    bdDetections = {},
    requireMap = {},
    keywordResults = {},
    stats = {total=0, success=0, failed=0, deduped=0, skipped=0},
    excludeBuildings = true,
    maxDepth = 0,
}

local connections = {}

-- Building exclusion lists
local excludedClasses = {
    "Part", "WedgePart", "CornerWedgePart", "TrussPart",
    "SpawnLocation", "Seat", "VehicleSeat"
}
local excludedKeywords = {
    "building","house","wall","floor","ceiling","roof",
    "door","window","structure","terrain","baseplate","ground","map"
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
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = dur or 5
        })
    end)
end

-- ── BUILDING FILTER ───────────────────────────────────────────
local function shouldScan(instance)
    if not State.excludeBuildings then return true end
    
    -- Skip building-class parts
    for _, cls in ipairs(excludedClasses) do
        if instance:IsA(cls) then
            State.stats.skipped += 1
            return false
        end
    end
    
    -- Skip instances with building-related names
    local lower = instance.Name:lower()
    for _, kw in ipairs(excludedKeywords) do
        if lower:find(kw, 1, true) then
            State.stats.skipped += 1
            return false
        end
    end
    
    -- Check parent chain
    local current = instance.Parent
    while current and current ~= game do
        local pl = current.Name:lower()
        for _, kw in ipairs(excludedKeywords) do
            if pl:find(kw, 1, true) then
                State.stats.skipped += 1
                return false
            end
        end
        current = current.Parent
    end
    
    return true
end

-- ── CONTAINERS ────────────────────────────────────────────────
local function getContainers()
    local list = {
        {Workspace, "Workspace"},
        {ReplicatedStorage, "ReplicatedStorage"},
        {game:GetService("ServerScriptService"), "ServerScriptService"},
        {StarterGui, "StarterGui"},
        {game:GetService("StarterPlayer"), "StarterPlayer"},
    }
    pcall(function()
        list[#list+1] = {LocalPlayer.PlayerScripts, "PlayerScripts"}
    end)
    pcall(function()
        list[#list+1] = {LocalPlayer.PlayerGui, "PlayerGui"}
    end)
    return list
end

-- Iterative traversal (no stack overflow on huge games)
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

-- ── CATEGORIZATION ────────────────────────────────────────────
local catKeywords = {
    Combat={"combat","damage","weapon","gun","kill","sword","attack"},
    Movement={"walkspeed","fly","noclip","jump","teleport","cframe","dash"},
    Economy={"shop","buy","cash","coin","rebirth","sell","currency","pet","egg"},
    NPC={"npc","monster","enemy","boss","ai","mob","spawn"},
    Remote={"remoteevent","remotefunction","fireserver","invokeserver"},
    DataStore={"datastore","save","load","profile"},
    Security={"anticheat","detect","flag","integrity","checksum"},
    Networking={"httpget","request","webhook","jsonencode"},
    Animation={"animation","animator","motor6d","keyframe"},
    Audio={"sound","music","sfx","volume"},
}

local function categorize(path, className, source)
    local combined = path:lower() .. ((source and #source > 0) and source:lower() or "")
    for cat, kws in pairs(catKeywords) do
        for _, kw in ipairs(kws) do
            if combined:find(kw, 1, true) then return cat end
        end
    end
    if className == "LocalScript" then return "Client" end
    if className == "Script" then return "Server" end
    if className == "ModuleScript" then return "Module" end
    return "Other"
end

-- ── CORE SCAN: SCRIPTS + MODULES ─────────────────────────────
local function scanScripts()
    State.results = {}
    State.hashes = {}
    State.stats = {total=0, success=0, failed=0, deduped=0, skipped=State.stats.skipped}
    
    local containers = getContainers()
    local allScripts = {}
    
    -- Collect all script-type instances
    for _, cd in ipairs(containers) do
        pcall(function()
            local desc = getAllDescendants(cd[1], State.maxDepth)
            for _, d in ipairs(desc) do
                if d:IsA("LocalScript") or d:IsA("Script") or d:IsA("ModuleScript") then
                    table.insert(allScripts, {inst=d, container=cd[2]})
                end
            end
        end)
    end
    
    State.stats.total = #allScripts
    notify("Scanner", string.format("Found %d scripts. Scanning...", #allScripts), 3)
    
    for i, entry in ipairs(allScripts) do
        local script = entry.inst
        
        if script.Parent and shouldScan(script) then
            local path = script:GetFullName()
            local hash = quickHash(path)
            
            if not State.hashes[hash] then
                State.hashes[hash] = true
                
                local source, status = getScriptSource(script)
                local className = script.ClassName
                local category = categorize(path, className, source)
                
                table.insert(State.results, {
                    path = path,
                    name = script.Name,
                    className = className,
                    category = category,
                    container = entry.container,
                    source = source or "",
                    size = source and #source or 0,
                    status = status,
                    hash = hash
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
        
        if i % 25 == 0 then RunService.RenderStepped:Wait() end
    end
    
    notify("Scan Complete",
        string.format("✅ %d OK | ❌ %d Failed | 🔄 %d Deduped | 🚫 %d Skipped",
            State.stats.success, State.stats.failed, State.stats.deduped, State.stats.skipped), 6)
end

-- ── REMOTE SCANNER ────────────────────────────────────────────
local function scanRemotes()
    State.remotes = {events={}, functions={}, bindables={}, bindableFuncs={}}
    
    for _, cd in ipairs(getContainers()) do
        pcall(function()
            for _, d in ipairs(cd[1]:GetDescendants()) do
                if d:IsA("RemoteEvent") then
                    table.insert(State.remotes.events, {
                        path=d:GetFullName(), name=d.Name,
                        parent=d.Parent and d.Parent.Name or "?"
                    })
                elseif d:IsA("RemoteFunction") then
                    table.insert(State.remotes.functions, {
                        path=d:GetFullName(), name=d.Name,
                        parent=d.Parent and d.Parent.Name or "?"
                    })
                elseif d:IsA("BindableEvent") then
                    table.insert(State.remotes.bindables, {path=d:GetFullName(), name=d.Name})
                elseif d:IsA("BindableFunction") then
                    table.insert(State.remotes.bindableFuncs, {path=d:GetFullName(), name=d.Name})
                end
            end
        end)
    end
    
    local total = #State.remotes.events + #State.remotes.functions +
                  #State.remotes.bindables + #State.remotes.bindableFuncs
    notify("Remotes Found",
        string.format("Events: %d | Functions: %d | Bindables: %d",
            #State.remotes.events, #State.remotes.functions, total - #State.remotes.events - #State.remotes.functions), 4)
end

-- ── OBJECT SCANNER ────────────────────────────────────────────
local function scanObjects()
    State.objects = {prompts={}, clickDetectors={}, humanoids={}, spawns={}, values={}}
    
    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if shouldScan(d) then
                if d:IsA("ProximityPrompt") then
                    table.insert(State.objects.prompts, {
                        path=d:GetFullName(), name=d.Name,
                        holdDuration=d.HoldDuration, enabled=d.Enabled,
                        actionText=d.ActionText, objectText=d.ObjectText
                    })
                elseif d:IsA("ClickDetector") then
                    table.insert(State.objects.clickDetectors, {
                        path=d:GetFullName(), name=d.Name,
                        maxDist=d.MaxActivationDistance
                    })
                elseif d:IsA("SpawnLocation") then
                    table.insert(State.objects.spawns, {
                        path=d:GetFullName(), name=d.Name,
                        pos=tostring(d.Position), neutral=d.Neutral
                    })
                end
                
                if d:IsA("Model") then
                    local hum = d:FindFirstChildOfClass("Humanoid")
                    if hum and not Players:GetPlayerFromCharacter(d) then
                        local root = d:FindFirstChild("HumanoidRootPart") or d.PrimaryPart
                        table.insert(State.objects.humanoids, {
                            path=d:GetFullName(), name=d.Name,
                            hp=hum.Health, maxHp=hum.MaxHealth,
                            speed=hum.WalkSpeed, jump=hum.JumpPower,
                            pos=root and tostring(root.Position) or "?"
                        })
                    end
                end
                
                if d:IsA("IntValue") or d:IsA("NumberValue") or d:IsA("StringValue") or d:IsA("BoolValue") then
                    table.insert(State.objects.values, {
                        path=d:GetFullName(), name=d.Name,
                        class=d.ClassName, value=tostring(d.Value):sub(1,60)
                    })
                end
            end
        end
    end)
end

-- ── ASSET SCANNER ─────────────────────────────────────────────
local function scanAssets()
    State.assets = {sounds={}, animations={}, decals={}, meshes={}}
    
    for _, root in ipairs({Workspace, ReplicatedStorage}) do
        pcall(function()
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("Sound") then
                    table.insert(State.assets.sounds, {path=d:GetFullName(), id=tostring(d.SoundId), vol=d.Volume})
                elseif d:IsA("Animation") then
                    table.insert(State.assets.animations, {path=d:GetFullName(), id=tostring(d.AnimationId)})
                elseif d:IsA("Decal") then
                    table.insert(State.assets.decals, {path=d:GetFullName(), tex=tostring(d.Texture)})
                elseif d:IsA("SpecialMesh") or d:IsA("MeshPart") then
                    table.insert(State.assets.meshes, {path=d:GetFullName(), class=d.ClassName, meshId=tostring(d.MeshId or "")})
                end
            end
        end)
    end
end

-- ── SECURITY SCAN: ANTICHEAT + BACKDOORS ─────────────────────
local acPatterns = {"anticheat","anti-cheat","exploit","detect","flag","tamper","velocity","noclip","speedhack","kick","crash"}
local bdPatterns = {"loadstring(game:HttpGet","require%(","backdoor","getfenv(","setfenv(","admin%.","SourceCode"}

local function scanSecurity()
    State.acDetections = {}
    State.bdDetections = {}
    State.requireMap = {}
    
    for _, r in ipairs(State.results) do
        if r.source and #r.source > 0 and r.status == "OK" then
            local lower = r.source:lower()
            local lines = r.source:split("\n")
            
            for li, line in ipairs(lines) do
                local ll = line:lower()
                
                for _, pat in ipairs(acPatterns) do
                    if ll:find(pat, 1, true) then
                        table.insert(State.acDetections, {
                            script=r.path, line=li, pattern=pat,
                            text=line:gsub("^%s+",""):sub(1,100)
                        })
                        break
                    end
                end
                
                for _, pat in ipairs(bdPatterns) do
                    if ll:find(pat, 1, true) then
                        table.insert(State.bdDetections, {
                            script=r.path, line=li, pattern=pat,
                            text=line:gsub("^%s+",""):sub(1,100)
                        })
                        break
                    end
                end
                
                if ll:find("require(", 1, true) then
                    local arg = line:match("require%s*%(%s*(.-)%s*%)") or "?"
                    table.insert(State.requireMap, {
                        script=r.path, target=arg:sub(1,80),
                        text=line:gsub("^%s+",""):sub(1,100)
                    })
                end
            end
        end
    end
    
    notify("Security Scan",
        string.format("AC: %d detections | BD: %d | Requires: %d",
            #State.acDetections, #State.bdDetections, #State.requireMap), 5)
end

-- ── KEYWORD ENGINE ────────────────────────────────────────────
local keywords = {"FireServer","InvokeServer","WalkSpeed","Health","Damage","Teleport","CFrame","DataStore","loadstring","require","HttpGet"}

local function scanKeywords()
    State.keywordResults = {}
    
    for _, kw in ipairs(keywords) do
        local matches = {keyword=kw, count=0, hits={}}
        local sk = kw:lower()
        
        for _, r in ipairs(State.results) do
            if r.source and r.status == "OK" then
                local lines = r.source:split("\n")
                for ln, line in ipairs(lines) do
                    if line:lower():find(sk, 1, true) then
                        matches.count += 1
                        if #matches.hits < 5 then
                            table.insert(matches.hits, {
                                script=r.path, line=ln,
                                text=line:gsub("^%s+",""):sub(1,90)
                            })
                        end
                    end
                end
            end
        end
        
        if matches.count > 0 then
            table.insert(State.keywordResults, matches)
        end
    end
end

-- ── DEEP SCAN SYSTEM ──────────────────────────────────────────
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

State.deepData = {
    remoteCalls = {},
    promptHits = {},
    spawns = {},
}

local function startDeepScan(duration)
    duration = duration or 300
    if State.deepScanning then return end
    State.deepScanning = true
    
    State.deepData = {remoteCalls={}, promptHits={}, spawns={}}
    notify("Deep Scan", "Monitoring for "..duration.."s...", 4)
    
    -- Prompt trigger logging
    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                d.Triggered:Connect(function(plr)
                    if plr == LocalPlayer then
                        table.insert(State.deepData.promptHits, {
                            time=os.date("%H:%M:%S"),
                            prompt=d.Name, path=d:GetFullName()
                        })
                    end
                end)
            end
        end
    end)
    
    -- Workspace spawn watcher
    connections.spawnWatch = Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then
            table.insert(State.deepData.spawns, {
                time=os.date("%H:%M:%S"), name=d.Name,
                path=d:GetFullName()
            })
        end
    end)
    
    -- Namecall hook for FireServer/InvokeServer
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        if not originalNamecall then originalNamecall = mt.__namecall end
        
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                local args = {...}
                local argStr = ""
                for i, arg in ipairs(args) do
                    local t = typeof(arg) == "Instance" and arg.ClassName or type(arg)
                    argStr = argStr .. string.format("[%d]:%s=%s ", i, t, tostring(arg):sub(1,30))
                end
                table.insert(State.deepData.remoteCalls, {
                    time=os.date("%H:%M:%S"),
                    method=method,
                    remote=self.Name,
                    path=self:GetFullName(),
                    args=argStr
                })
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

function stopDeepScan()
    if not State.deepScanning then return end
    State.deepScanning = false
    
    if connections.spawnWatch then connections.spawnWatch:Disconnect() end
    restoreHook()
    
    notify("Deep Scan Done",
        string.format("Calls: %d | Prompts: %d | Spawns: %d",
            #State.deepData.remoteCalls, #State.deepData.promptHits, #State.deepData.spawns), 6)
end

-- ── EXPORT ────────────────────────────────────────────────────
local function exportJSON()
    local export = {
        meta={
            time=os.date("%Y-%m-%d %H:%M:%S"),
            placeId=game.PlaceId,
            jobId=game.JobId,
            version="v9.0"
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
        local fname = "scanner_" .. tostring(game.PlaceId) .. "_" .. os.time() .. ".json"
        writefile(fname, json)
        notify("Export", "Saved to workspace/"..fname, 5)
    end
    
    if setclipboard then
        setclipboard(json)
        notify("Clipboard", "Full JSON copied!", 3)
    end
end

-- ── RAYFIELD UI BUILD ─────────────────────────────────────────
local Window = Rayfield:CreateWindow({
    Name = "Universal Game Scanner v9.0",
    LoadingTitle = "Game Scanner",
    LoadingSubtitle = "by snowy-dot & [K]vk",
    ConfigurationSaving = {
        Enabled = false
    },
    KeySystem = false
})

-- TAB: MAIN
local TabMain = Window:CreateTab("Main", 4483362458)

TabMain:CreateSection("Scanner Control")

TabMain:CreateButton({
    Name = "🔍 Full Scan (Scripts + Modules)",
    Callback = function()
        task.spawn(scanScripts)
    end
})

TabMain:CreateButton({
    Name = "📡 Scan Remotes Only",
    Callback = function()
        task.spawn(scanRemotes)
    end
})

TabMain:CreateButton({
    Name = "🎯 Scan Objects + Assets",
    Callback = function()
        task.spawn(function()
            scanObjects()
            scanAssets()
        end)
    end
})

TabMain:CreateButton({
    Name = "🔥 Run Everything",
    Callback = function()
        task.spawn(function()
            scanScripts()
            scanRemotes()
            scanObjects()
            scanAssets()
            scanSecurity()
            scanKeywords()
            notify("Done", "All scans complete!", 4)
        end)
    end
})

TabMain:CreateSection("Statistics")

local StatsLabel = TabMain:CreateLabel("Total: 0 | Success: 0 | Failed: 0 | Deduped: 0 | Skipped Buildings: 0")

TabMain:CreateButton({
    Name = "📊 Refresh Stats",
    Callback = function()
        StatsLabel:Set(string.format(
            "Total: %d | ✅ %d | ❌ %d | 🔄 %d | 🏗️ %d",
            State.stats.total, State.stats.success, State.stats.failed,
            State.stats.deduped, State.stats.skipped))
    end
})

-- TAB: SCRIPTS
local TabScripts = Window:CreateTab("Scripts", 4483362458)

TabScripts:CreateSection("Filter & Browse")

local ScriptOutput = TabScripts:CreateLabel("Run a scan to see results here.")

local selectedCat = "All"
TabScripts:CreateDropdown({
    Name = "Category Filter",
    Options = {"All","Combat","Movement","Economy","NPC","Remote","DataStore","Security","Networking","Animation","Audio","Client","Server","Module","Other"},
    CurrentOption = "All",
    Callback = function(opt)
        selectedCat = opt[1]
        local out = ""
        local count = 0
        for _, r in ipairs(State.results) do
            if selectedCat == "All" or r.category == selectedCat then
                count += 1
                if count <= 40 then
                    local icon = r.status == "OK" and "✅" or "❌"
                    out = out .. icon .. " [" .. r.className .. "] " .. r.name ..
                          "\n   📁 " .. r.path .. "\n\n"
                end
            end
        end
        if count == 0 then out = "No results for filter." end
        if count > 40 then out = out .. "...+" .. (count-40) .. " more\n" end
        ScriptOutput:Set(out)
    end
})

TabScripts:CreateButton({
    Name = "📋 Copy All Source Code",
    Callback = function()
        local all = ""
        for _, r in ipairs(State.results) do
            if r.status == "OK" and r.source and #r.source > 0 then
                all = all .. "-- ===== " .. r.path .. " [" .. r.className .. "] =====\n"
                all = all .. r.source .. "\n\n"
            end
        end
        if setclipboard then setclipboard(all) end
        notify("Copy", "All script sources copied ("..#all.." bytes)", 4)
    end
})

-- TAB: SECURITY
local TabSec = Window:CreateTab("Security", 4483362458)

TabSec:CreateSection("Anti-Cheat Detections")

local ACLabel = TabSec:CreateLabel("No detections yet.")

TabSec:CreateButton({
    Name = "🛡️ Show Anti-Cheat Hits",
    Callback = function()
        local out = ""
        for i, d in ipairs(State.acDetections) do
            if i > 30 then break end
            out = out .. string.format("%s:L%d [%s]\n  %s\n\n", 
                d.script, d.line, d.pattern, d.text)
        end
        if out == "" then out = "Clean." end
        ACLabel:Set(out)
    end
})

TabSec:CreateSection("Backdoor Detections")

local BDLabel = TabSec:CreateLabel("No detections yet.")

TabSec:CreateButton({
    Name = "🔓 Show Backdoor Hits",
    Callback = function()
        local out = ""
        for i, d in ipairs(State.bdDetections) do
            if i > 30 then break end
            out = out .. string.format("%s:L%d [%s]\n  %s\n\n",
                d.script, d.line, d.pattern, d.text)
        end
        if out == "" then out = "Clean." end
        BDLabel:Set(out)
    end
})

TabSec:CreateSection("Require Map")

local ReqLabel = TabSec:CreateLabel("No require() calls found.")

TabSec:CreateButton({
    Name = "🔗 Show Require Map",
    Callback = function()
        local out = ""
        for i, d in ipairs(State.requireMap) do
            if i > 30 then break end
            out = out .. string.format("%s → %s\n  %s\n\n", d.script, d.target, d.text)
        end
        if out == "" then out = "None found." end
        ReqLabel:Set(out)
    end
})

-- TAB: REMOTES
local TabRemotes = Window:CreateTab("Remotes", 4483362458)

TabRemotes:CreateSection("Found Remotes")

local RemoteLabel = TabRemotes:CreateLabel("Press 'Scan Remotes' first.")

TabRemotes:CreateButton({
    Name = "📡 Refresh Remote List",
    Callback = function()
        local out = ""
        out = out .. "── RemoteEvents ──\n"
        for i, e in ipairs(State.remotes.events) do
            if i > 20 then out = out .. "...more\n" break end
            out = out .. "• " .. e.path .. "\n"
        end
        out = out .. "\n── RemoteFunctions ──\n"
        for i, f in ipairs(State.remotes.functions) do
            if i > 20 then out = out .. "...more\n" break end
            out = out .. "• " .. f.path .. "\n"
        end
        if out == "" then out = "Nothing found." end
        RemoteLabel:Set(out)
    end
})

-- TAB: DEEP SCAN
local TabDeep = Window:CreateTab("Deep Scan", 4483362458)

TabDeep:CreateSection("Live Monitoring")

TabDeep:CreateButton({
    Name = "▶ Start Deep Scan (300s)",
    Callback = function()
        startDeepScan(300)
    end
})

TabDeep:CreateButton({
    Name = "⏹ Stop Deep Scan",
    Callback = function()
        stopDeepScan()
    end
})

local DeepLabel = TabDeep:CreateLabel("No deep data yet.")

TabDeep:CreateButton({
    Name = "👁 View Captured Remote Calls",
    Callback = function()
        local out = ""
        for i, c in ipairs(State.deepData.remoteCalls) do
            if i > 30 then break end
            out = out .. string.format("[%s] %s %s\n  Path: %s\n  Args: %s\n\n",
                c.time, c.method, c.remote, c.path, c.args)
        end
        if out == "" then out = "No calls captured yet." end
        DeepLabel:Set(out)
    end
})

-- TAB: SETTINGS
local TabSettings = Window:CreateTab("Settings", 4483362458)

TabSettings:CreateSection("Filters")

TabSettings:CreateToggle({
    Name = "🏗️ Exclude Buildings / Structures",
    CurrentValue = true,
    Flag = "ExcludeBuildings",
    Callback = function(val)
        State.excludeBuildings = val
        notify("Setting", val and "Building exclusion ON" or "Building exclusion OFF", 3)
    end
})

TabSettings:CreateSlider({
    Name = "Max Scan Depth (0 = unlimited)",
    Range = {0, 15},
    Increment = 1,
    Suffix = "lvl",
    CurrentValue = 0,
    Flag = "MaxDepth",
    Callback = function(val)
        State.maxDepth = val
    end
})

-- TAB: EXPORT
local TabExport = Window:CreateTab("Export", 4483362458)

TabExport:CreateSection("Dump Results")

TabExport:CreateButton({
    Name = "💾 Export All to JSON",
    Callback = function()
        exportJSON()
    end
})

TabExport:CreateButton({
    Name = "📋 Copy Security Report",
    Callback = function()
        local report = ""
        report = report .. "=== SECURITY REPORT ===\n"
        report = report .. "AntiCheat: " .. #State.acDetections .. " hits\n"
        for _, d in ipairs(State.acDetections) do
            report = report .. string.format("  %s:L%d [%s] %s\n", d.script, d.line, d.pattern, d.text)
        end
        report = report .. "\nBackdoors: " .. #State.bdDetections .. " hits\n"
        for _, d in ipairs(State.bdDetections) do
            report = report .. string.format("  %s:L%d [%s] %s\n", d.script, d.line, d.pattern, d.text)
        end
        if setclipboard then setclipboard(report) end
        notify("Copied", "Security report copied.", 3)
    end
})

-- ── INIT ──────────────────────────────────────────────────────
notify("Scanner Ready", "Universal Game Scanner v9.0 loaded.\nPress Right Shift to toggle UI.", 6)

print("═══════════════════════════════════════")
print("   Universal Game Scanner v9.0 ready")
print("   Buildings excluded from scanning")
print("═══════════════════════════════════════")
