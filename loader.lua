--!nocheck
-- ==============================================================
--  PHANTOM SCANNER v11.2 — FREEZE FIX EDITION
--  Budgeted decompile | Yielding scans | Chunked export
-- ==============================================================

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local HttpService          = game:GetService("HttpService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local ReplicatedFirst      = game:GetService("ReplicatedFirst")
local Workspace            = game:GetService("Workspace")
local StarterGui           = game:GetService("StarterGui")
local StarterPack          = game:GetService("StarterPack")
local StarterPlayer        = game:GetService("StarterPlayer")
local ServerScriptService  = game:GetService("ServerScriptService")
local Lighting             = game:GetService("Lighting")
local SoundService         = game:GetService("SoundService")
local Teams                = game:GetService("Teams")
local MarketplaceService   = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local unpack = table.unpack or unpack

local function getExecFunc(name)
    local ok, fn = pcall(function() return getgenv()[name] end)
    if ok and type(fn) == "function" then return fn end
    return _G[name]
end

local getsrc            = getExecFunc("getsrc")
local decompile         = getExecFunc("decompile")
local getscriptbytecode = getExecFunc("getscriptbytecode")
local writefile         = getExecFunc("writefile")
local readfile          = getExecFunc("readfile")
local isfolder          = getExecFunc("isfolder")
local makefolder        = getExecFunc("makefolder")
local isfile            = getExecFunc("isfile")
local setclipboard      = getExecFunc("setclipboard")
local newcclosure       = getExecFunc("newcclosure")
local getrawmetatable   = getExecFunc("getrawmetatable")
local setreadonly       = getExecFunc("setreadonly")
local getnamecallmethod = getExecFunc("getnamecallmethod")
local identifyexecutor  = getExecFunc("identifyexecutor")

local GameName = "UnknownGame"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name and info.Name ~= "" then GameName = info.Name end
end)
if GameName == "UnknownGame" then
    pcall(function() if game.Name ~= "" then GameName = game.Name end end)
end

local function sanitizeFilename(str)
    return tostring(str):gsub("[^%w%-_]", "_"):sub(1, 60)
end
local safeGameName = sanitizeFilename(GameName)

local executorInfo = "Unknown"
pcall(function()
    local n, v = identifyexecutor()
    executorInfo = tostring(n) .. (v and (" v" .. tostring(v)) or "")
end)

print("[Phantom] Game: " .. GameName)
print("[Phantom] Executor: " .. executorInfo)

-- config
local CONFIG_FILE = "PhantomScanner/config.json"

local function saveConfig(cfg)
    if writefile then
        pcall(function()
            if isfolder and makefolder and not isfolder("PhantomScanner") then
                makefolder("PhantomScanner")
            end
            writefile(CONFIG_FILE, HttpService:JSONEncode(cfg))
        end)
    end
end

local function loadConfig()
    if readfile and isfile and isfile(CONFIG_FILE) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)
        if ok and type(data) == "table" then return data end
    end
    return {}
end

local CFG = loadConfig()
if CFG.dedup == nil then CFG.dedup = true end
if CFG.safeMode == nil then CFG.safeMode = true end
if CFG.skipCoreGui == nil then CFG.skipCoreGui = true end
if CFG.scanCoreGui == nil then CFG.scanCoreGui = false end
if CFG.maxSourceKB == nil then CFG.maxSourceKB = 300 end
if CFG.maxTotalMB == nil then CFG.maxTotalMB = 30 end

-- state
local State = {
    results          = {},
    hashes           = {},
    remotes          = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}},
    objects          = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}},
    assets           = {sounds = {}, animations = {}, decals = {}, meshes = {}},
    acDetections     = {},
    bdDetections     = {},
    webhookHits      = {},
    requireMap       = {},
    deepData         = {remoteCalls = {}, promptHits = {}, spawns = {}},
    stats            = {total = 0, success = 0, failed = 0, deduped = 0, bytecode = 0, skippedCore = 0, truncated = 0},
    deepScanning     = false,
    busy             = false,
    cancelScan       = false,
    lastExportPath   = "",
    scanStart        = 0,
    scanDuration     = 0,
    sourceBytes      = 0,
    selectedScript   = nil,
    selectedNPC      = nil,
    selectedValue    = nil,
    selectedRemote   = nil,
    filteredScripts  = {},
    remoteList       = {},
    filteredValues   = {},
    _searchQuery     = "",
    _valueQuery      = "",
    _newValue        = "",
    remotePath       = "",
    remoteArgs       = ""
}

local connections = {}
local restoreHook
local refreshScriptDropdown

-- rayfield
local Rayfield, Window
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if ok and type(result) == "table" then
        Rayfield = result
        Window = Rayfield:CreateWindow({
            Name = "Phantom Scanner v11.2",
            LoadingTitle = GameName,
            LoadingSubtitle = "by snowy-dot | v11.2",
            ConfigurationSaving = {Enabled = false},
            KeySystem = false
        })
    else
        warn("[Phantom] RAYFIELD LOAD FAILED: " .. tostring(result))
        return
    end
end

local function notify(title, content, dur)
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = dur or 4
        })
    end)
end

-- ============== SCANNER CORE ==============

local function getContainers()
    local list = {
        {Workspace, "Workspace"},
        {ReplicatedStorage, "ReplicatedStorage"},
        {ReplicatedFirst, "ReplicatedFirst"},
        {StarterGui, "StarterGui"},
        {StarterPack, "StarterPack"},
        {StarterPlayer, "StarterPlayer"},
        {Lighting, "Lighting"},
        {SoundService, "SoundService"},
        {Teams, "Teams"},
        {Players, "Players"}
    }
    pcall(function() list[#list+1] = {game:GetService("ServerScriptService"), "ServerScriptService"} end)
    pcall(function() list[#list+1] = {game:GetService("ServerStorage"), "ServerStorage"} end)
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
    if CFG.scanCoreGui then
        pcall(function()
            local cg = gethui and gethui() or game:GetService("CoreGui")
            if cg then list[#list+1] = {cg, "CoreGui"} end
        end)
    end
    return list
end

local function quickHash(str)
    if not str then return "nil" end
    local h = 5381
    for i = 1, #str do
        h = (h * 33 + string.byte(str, i)) % 0x100000000
    end
    return string.format("%08x", h)
end

-- FIX 1: single source of truth for tree walking, always yields
local function getAllDescendants(container)
    local results = {}
    local stack = {container}
    while #stack > 0 do
        if State.cancelScan then break end
        local node = table.remove(stack)
        local ok, children = pcall(function() return node:GetChildren() end)
        if ok and children then
            for _, child in ipairs(children) do
                table.insert(results, child)
                table.insert(stack, child)
            end
        end
        if #results % 250 == 0 then
            RunService.RenderStepped:Wait()
        end
    end
    return results
end

-- FIX 2: budgeted source grab — truncates + skips instead of freezing
local function getScriptSource(script, isCoreGui)
    -- hard skip: budget exhausted
    local maxTotal = CFG.maxTotalMB * 1000000
    if State.sourceBytes >= maxTotal then
        return nil, "BUDGET"
    end

    -- coregui scripts: bytecode-fast path or full skip
    if isCoreGui and CFG.skipCoreGui then
        return nil, "CORESKIP"
    end

    local maxSrc = CFG.maxSourceKB * 1000
    local src, status

    if type(getsrc) == "function" then
        local ok, r = pcall(getsrc, script)
        if ok and type(r) == "string" and #r > 0 then
            src = r
            status = "OK"
        end
    end

    if not src and type(decompile) == "function" then
        for _ = 1, 2 do
            local ok, r = pcall(decompile, script)
            if ok and type(r) == "string" and #r > 0 then
                src = r
                status = "OK"
                break
            end
        end
    end

    if not src and type(getscriptbytecode) == "function" then
        local ok, r = pcall(getscriptbytecode, script)
        if ok and type(r) == "string" and #r > 0 then
            src = r
            status = "BYTECODE"
        end
    end

    if src then
        if #src > maxSrc then
            src = src:sub(1, maxSrc)
            State.stats.truncated = State.stats.truncated + 1
        end
        State.sourceBytes = State.sourceBytes + #src
    end

    if src then
        return src, status
    end
    return nil, "FAILED"
end

local catKeywords = {
    Combat    = {"combat", "damage", "weapon", "gun", "kill", "sword", "attack"},
    Movement  = {"walkspeed", "fly", "noclip", "jump", "teleport", "cframe"},
    Economy   = {"shop", "buy", "cash", "coin", "rebirth", "sell", "pet", "egg"},
    NPC       = {"npc", "monster", "enemy", "boss", "mob", "spawn"},
    Remote    = {"remoteevent", "remotefunction", "fireserver", "invokeserver"},
    DataStore = {"datastore", "save", "load", "profile"},
    Security  = {"anticheat", "detect", "flag", "integrity"},
    Animation = {"animation", "animator", "motor6d"},
    Audio     = {"sound", "music", "sfx"}
}

local function splitLines(source)
    local lines = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function categorize(path, className, source)
    local combined = path:lower()
    if source and #source > 0 then
        combined = combined .. source:lower():sub(1, 3000)
    end
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

local function scanScripts(progressCb)
    State.results = {}
    State.hashes = {}
    State.sourceBytes = 0
    State.stats.total = 0
    State.stats.success = 0
    State.stats.failed = 0
    State.stats.deduped = 0
    State.stats.bytecode = 0
    State.stats.skippedCore = 0
    State.stats.truncated = 0

    local allScripts = {}
    for _, cd in ipairs(getContainers()) do
        pcall(function()
            for _, d in ipairs(getAllDescendants(cd[1])) do
                if d:IsA("LocalScript") or d:IsA("Script") or d:IsA("ModuleScript") then
                    table.insert(allScripts, {inst = d, container = cd[2]})
                end
            end
        end)
        if State.cancelScan then break end
    end

    State.stats.total = #allScripts
    notify("Scripts", "Found " .. #allScripts .. " — scanning with budget...", 3)

    local yieldEvery = CFG.safeMode and 1 or 5

    for i, entry in ipairs(allScripts) do
        if State.cancelScan then break end
        local s = entry.inst
        local isCore = (entry.container == "CoreGui")
        if s.Parent then
            local path = s:GetFullName()
            local hash = quickHash(path .. "|" .. s.ClassName)
            if CFG.dedup and State.hashes[hash] then
                State.stats.deduped = State.stats.deduped + 1
            else
                State.hashes[hash] = true

                if isCore and CFG.skipCoreGui then
                    State.stats.skippedCore = State.stats.skippedCore + 1
                else
                    local src, status = getScriptSource(s, isCore)
                    local cls = s.ClassName
                    table.insert(State.results, {
                        path = path,
                        name = s.Name,
                        className = cls,
                        category = categorize(path, cls, src),
                        source = src or "",
                        size = src and #src or 0,
                        status = status
                    })
                    if status == "OK" then
                        State.stats.success = State.stats.success + 1
                    elseif status == "BYTECODE" then
                        State.stats.bytecode = State.stats.bytecode + 1
                    else
                        State.stats.failed = State.stats.failed + 1
                    end
                end
            end
        end
        if i % yieldEvery == 0 then
            if progressCb then
                progressCb(i, #allScripts)
            end
            RunService.RenderStepped:Wait()
        end
        if i % 100 == 0 then
            task.wait()
        end
    end
end

-- FIX 3: remotes/objects/assets use the yielding walker, not raw GetDescendants
local function scanRemotes()
    State.remotes = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}}
    for _, cd in ipairs(getContainers()) do
        pcall(function()
            for _, d in ipairs(getAllDescendants(cd[1])) do
                if d:IsA("RemoteEvent") then
                    table.insert(State.remotes.events, {path = d:GetFullName(), name = d.Name})
                elseif d:IsA("RemoteFunction") then
                    table.insert(State.remotes.functions, {path = d:GetFullName(), name = d.Name})
                elseif d:IsA("BindableEvent") then
                    table.insert(State.remotes.bindables, {path = d:GetFullName(), name = d.Name})
                elseif d:IsA("BindableFunction") then
                    table.insert(State.remotes.bindableFuncs, {path = d:GetFullName(), name = d.Name})
                end
            end
        end)
        if State.cancelScan then break end
    end
    notify("Remotes", string.format("Events: %d | Functions: %d",
        #State.remotes.events, #State.remotes.functions), 4)
end

local function scanObjects()
    State.objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}}
    pcall(function()
        for _, d in ipairs(getAllDescendants(Workspace)) do
            if d:IsA("ProximityPrompt") then
                table.insert(State.objects.prompts, {path = d:GetFullName(), name = d.Name})
            elseif d:IsA("ClickDetector") then
                table.insert(State.objects.clickDetectors, {path = d:GetFullName(), name = d.Name})
            elseif d:IsA("Model") then
                local hum = d:FindFirstChildOfClass("Humanoid")
                if hum and not Players:GetPlayerFromCharacter(d) then
                    local root = d:FindFirstChild("HumanoidRootPart") or d.PrimaryPart
                    local p = root and root.Position
                    table.insert(State.objects.humanoids, {
                        path = d:GetFullName(),
                        name = d.Name,
                        hp = hum.Health,
                        mhp = hum.MaxHealth,
                        ws = hum.WalkSpeed,
                        pos = p and string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z) or "?",
                        px = p and p.X,
                        py = p and p.Y,
                        pz = p and p.Z
                    })
                end
            elseif d:IsA("SpawnLocation") then
                table.insert(State.objects.spawns, {path = d:GetFullName(), pos = tostring(d.Position)})
            end
        end
    end)
    for _, root in ipairs({Workspace, ReplicatedStorage}) do
        pcall(function()
            for _, d in ipairs(getAllDescendants(root)) do
                if d:IsA("IntValue") or d:IsA("NumberValue") or d:IsA("StringValue")
                or d:IsA("BoolValue") or d:IsA("ObjectValue") or d:IsA("Vector3Value") then
                    local entry = {path = d:GetFullName(), class = d.ClassName, ref = d}
                    pcall(function() entry.val = tostring(d.Value):sub(1, 80) end)
                    table.insert(State.objects.values, entry)
                end
            end
        end)
        if State.cancelScan then break end
    end
    notify("Objects", string.format("NPCs: %d | Prompts: %d | Values: %d",
        #State.objects.humanoids, #State.objects.prompts, #State.objects.values), 4)
end

local function scanAssets()
    State.assets = {sounds = {}, animations = {}, decals = {}, meshes = {}}
    for _, root in ipairs({Workspace, ReplicatedStorage}) do
        pcall(function()
            for _, d in ipairs(getAllDescendants(root)) do
                if d:IsA("Sound") then
                    table.insert(State.assets.sounds, {path = d:GetFullName(), id = tostring(d.SoundId)})
                elseif d:IsA("Animation") then
                    table.insert(State.assets.animations, {path = d:GetFullName(), id = tostring(d.AnimationId)})
                elseif d:IsA("Decal") then
                    table.insert(State.assets.decals, {path = d:GetFullName(), tex = tostring(d.Texture)})
                elseif d:IsA("SpecialMesh") or d:IsA("MeshPart") then
                    table.insert(State.assets.meshes, {path = d:GetFullName(), id = tostring(d.MeshId or "")})
                end
            end
        end)
        if State.cancelScan then break end
    end
    notify("Assets", string.format("Sounds: %d | Anims: %d | Meshes: %d",
        #State.assets.sounds, #State.assets.animations, #State.assets.meshes), 4)
end

-- FIX 4: security scan yields between scripts
local function scanSecurity()
    State.acDetections = {}
    State.bdDetections = {}
    State.webhookHits = {}
    State.requireMap = {}

    local acPatterns = {"anticheat", "anti-cheat", "exploit", "detect", "flag", "tamper", "noclip", "speedhack", "kick", "crash", "rejoin", "ban"}
    local bdPatterns = {"loadstring(game:httpget", "require(", "backdoor", "getfenv(", "setfenv(", "getgenv("}
    local webhookPatterns = {"discord.com/api/webhooks", "discordapp.com/api/webhooks", "webhook"}

    for si, r in ipairs(State.results) do
        if r.source and #r.source > 0 and r.status == "OK" then
            local lines = splitLines(r.source)
            for li, line in ipairs(lines) do
                local ll = line:lower()
                for _, pat in ipairs(acPatterns) do
                    if ll:find(pat, 1, true) then
                        table.insert(State.acDetections, {script = r.path, line = li, pattern = pat, text = line:gsub("^%s+", ""):sub(1, 100)})
                        break
                    end
                end
                for _, pat in ipairs(bdPatterns) do
                    if ll:find(pat, 1, true) then
                        table.insert(State.bdDetections, {script = r.path, line = li, pattern = pat, text = line:gsub("^%s+", ""):sub(1, 100)})
                        break
                    end
                end
                for _, pat in ipairs(webhookPatterns) do
                    if ll:find(pat, 1, true) then
                        table.insert(State.webhookHits, {script = r.path, line = li, pattern = pat, text = line:gsub("^%s+", ""):sub(1, 120)})
                        break
                    end
                end
                if ll:find("require(", 1, true) then
                    local arg = line:match("require%s*%(%s*(.-)%s*%)") or "?"
                    table.insert(State.requireMap, {script = r.path, target = arg:sub(1, 80), text = line:gsub("^%s+", ""):sub(1, 100)})
                end
            end
        end
        if si % 25 == 0 then
            RunService.RenderStepped:Wait()
        end
    end
    notify("Security", string.format("AC: %d | BD: %d | Webhooks: %d",
        #State.acDetections, #State.bdDetections, #State.webhookHits), 5)
end

-- path resolver + templates (unchanged logic)
local function resolvePath(path)
    local parts = {}
    for p in path:gmatch("[^%.]+") do
        table.insert(parts, p)
    end
    if #parts == 0 then return nil end
    local cur = game
    for i, p in ipairs(parts) do
        if i == 1 then
            local ok, svc = pcall(function() return game:GetService(p) end)
            if ok and svc then
                cur = svc
            else
                cur = game:FindFirstChild(p)
            end
        else
            cur = cur:FindFirstChild(p)
        end
        if not cur then return nil end
    end
    return cur
end

local function pathToCode(path)
    local parts = {}
    for p in path:gmatch("[^%.]+") do
        table.insert(parts, p)
    end
    if #parts == 0 then return "-- invalid path" end
    local code = 'local obj = game:GetService("' .. parts[1] .. '")'
    for i = 2, #parts do
        code = code .. ':WaitForChild("' .. parts[i] .. '")'
    end
    return code
end

local function generateTemplates()
    local buf = {"-- PHANTOM REMOTE TEMPLATES -- " .. GameName, "-- paste into executor, edit args", ""}
    for _, e in ipairs(State.remotes.events) do
        local var = "evt" .. tostring(#buf)
        table.insert(buf, "-- " .. e.path)
        table.insert(buf, "local " .. var .. " = " .. pathToCode(e.path))
        table.insert(buf, var .. ":FireServer(--[[ args ]])")
        table.insert(buf, "")
    end
    for _, f in ipairs(State.remotes.functions) do
        local var = "fn" .. tostring(#buf)
        table.insert(buf, "-- " .. f.path)
        table.insert(buf, "local " .. var .. " = " .. pathToCode(f.path))
        table.insert(buf, "local result = " .. var .. ":InvokeServer(--[[ args ]])")
        table.insert(buf, "")
    end
    return table.concat(buf, "\n")
end

local function generateSmartTemplates()
    local buf = {"-- SMART TEMPLATES (observed deep-scan calls)", ""}
    local observed, order = {}, {}
    for _, c in ipairs(State.deepData.remoteCalls) do
        if not observed[c.path] then
            observed[c.path] = {calls = {}, method = c.method}
            table.insert(order, c.path)
        end
        table.insert(observed[c.path].calls, c)
    end
    for _, path in ipairs(order) do
        local data = observed[path]
        table.insert(buf, "-- " .. path .. "  (observed " .. #data.calls .. "x)")
        table.insert(buf, "local remote = " .. pathToCode(path))
        table.insert(buf, "-- args: " .. data.calls[1].args)
        if data.method == "FireServer" then
            table.insert(buf, "remote:FireServer(--[[ replicate args ]])")
        else
            table.insert(buf, "local result = remote:InvokeServer(--[[ replicate args ]])")
        end
        table.insert(buf, "")
    end
    if #order == 0 then
        table.insert(buf, "-- none yet. run deep scan while playing.")
    end
    return table.concat(buf, "\n")
end

-- ============== EXPORT (FIX 5: chunked writes, capped clipboard) ==============

local CLIPBOARD_LIMIT = 1500000
local CHUNK_SIZE = 3000000

local function writeSingle(content, baseName, ext)
    local timestamp = tostring(os.time())
    local attemptPaths = {
        baseName .. "_" .. timestamp .. ext,
        "PhantomScanner/" .. baseName .. "_" .. timestamp .. ext,
        "scan_" .. timestamp .. ext
    }
    if writefile then
        for _, path in ipairs(attemptPaths) do
            local ok = pcall(function()
                if isfolder and makefolder then
                    local folderInPath = path:match("^(.+)/[^/]+$")
                    if folderInPath and not isfolder(folderInPath) then
                        makefolder(folderInPath)
                    end
                end
                writefile(path, content)
            end)
            if ok then return path end
        end
    end
    return nil
end

local function writeChunked(buf, baseName, ext)
    local out = table.concat(buf, "\n")
    if #out <= CHUNK_SIZE then
        local p = writeSingle(out, baseName, ext)
        return p, #out
    end
    -- multi-part export
    local parts = math.ceil(#out / CHUNK_SIZE)
    local savedAny = false
    for i = 1, parts do
        local s = (i - 1) * CHUNK_SIZE + 1
        local e = math.min(i * CHUNK_SIZE, #out)
        local chunk = out:sub(s, e)
        local p = writeSingle(chunk, baseName .. "_part" .. i, ext)
        if p then savedAny = true end
        RunService.RenderStepped:Wait()
    end
    if savedAny then
        return baseName .. "_part1-.." .. parts .. ext, #out
    end
    return nil, #out
end

local function buildReportBuf(includeSources)
    local buf = {}
    local function add(t) table.insert(buf, t) end

    add("==========================================")
    add("  PHANTOM SCANNER v11.2 EXPORT")
    add("==========================================")
    add("Game: " .. GameName)
    add("Place ID: " .. tostring(game.PlaceId))
    add("Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    add("Executor: " .. executorInfo)
    add("Scan Duration: " .. string.format("%.1fs", State.scanDuration))
    add("Source Collected: " .. string.format("%.1f MB", State.sourceBytes / 1000000))
    add("")
    add("========== STATS ==========")
    add("Total Scripts: " .. State.stats.total)
    add("Successful (source): " .. State.stats.success)
    add("Bytecode only: " .. State.stats.bytecode)
    add("Failed (server-only/budget): " .. State.stats.failed)
    add("Deduped: " .. State.stats.deduped)
    add("CoreGui skipped: " .. State.stats.skippedCore)
    add("Truncated: " .. State.stats.truncated)
    add("")
    add("========== REMOTES ==========")
    add("--- RemoteEvents (" .. #State.remotes.events .. ") ---")
    for _, e in ipairs(State.remotes.events) do add(e.path) end
    add("--- RemoteFunctions (" .. #State.remotes.functions .. ") ---")
    for _, f in ipairs(State.remotes.functions) do add(f.path) end
    add("--- BindableEvents (" .. #State.remotes.bindables .. ") ---")
    for _, b in ipairs(State.remotes.bindables) do add(b.path) end
    add("--- BindableFunctions (" .. #State.remotes.bindableFuncs .. ") ---")
    for _, b in ipairs(State.remotes.bindableFuncs) do add(b.path) end
    add("")
    add("========== OBJECTS ==========")
    add("--- ProximityPrompts (" .. #State.objects.prompts .. ") ---")
    for _, p in ipairs(State.objects.prompts) do add(p.path) end
    add("--- ClickDetectors (" .. #State.objects.clickDetectors .. ") ---")
    for _, c in ipairs(State.objects.clickDetectors) do add(c.path) end
    add("--- NPCs (" .. #State.objects.humanoids .. ") ---")
    for _, n in ipairs(State.objects.humanoids) do
        add(n.name .. " | HP:" .. tostring(n.hp) .. "/" .. tostring(n.mhp)
            .. " WS:" .. tostring(n.ws) .. " | " .. n.path .. " @ " .. n.pos)
    end
    add("--- SpawnLocations (" .. #State.objects.spawns .. ") ---")
    for _, s in ipairs(State.objects.spawns) do add(s.path .. " @ " .. s.pos) end
    add("--- Values (" .. #State.objects.values .. ") ---")
    for _, v in ipairs(State.objects.values) do
        add("[" .. v.class .. "] " .. v.path .. " = " .. tostring(v.val))
    end
    add("")
    add("========== ASSETS ==========")
    add("--- Sounds (" .. #State.assets.sounds .. ") ---")
    for _, s in ipairs(State.assets.sounds) do add(s.path .. " | " .. s.id) end
    add("--- Animations (" .. #State.assets.animations .. ") ---")
    for _, a in ipairs(State.assets.animations) do add(a.path .. " | " .. a.id) end
    add("--- Decals (" .. #State.assets.decals .. ") ---")
    for _, d in ipairs(State.assets.decals) do add(d.path .. " | " .. d.tex) end
    add("--- Meshes (" .. #State.assets.meshes .. ") ---")
    for _, m in ipairs(State.assets.meshes) do add(m.path .. " | " .. m.id) end
    add("")
    add("========== SECURITY ==========")
    add("--- AntiCheat (" .. #State.acDetections .. ") ---")
    for _, d in ipairs(State.acDetections) do
        add(d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
        add("  " .. d.text)
    end
    add("--- Backdoors (" .. #State.bdDetections .. ") ---")
    for _, d in ipairs(State.bdDetections) do
        add(d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
        add("  " .. d.text)
    end
    add("--- Webhooks (" .. #State.webhookHits .. ") ---")
    for _, d in ipairs(State.webhookHits) do
        add(d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
        add("  " .. d.text)
    end
    add("--- Requires (" .. #State.requireMap .. ") ---")
    for _, r in ipairs(State.requireMap) do add(r.script .. " -> " .. r.target) end
    add("")
    add("========== DEEP SCAN ==========")
    add("--- Remote Calls (" .. #State.deepData.remoteCalls .. ") ---")
    for _, c in ipairs(State.deepData.remoteCalls) do
        add("[" .. c.time .. "] " .. c.method .. "." .. c.remote)
        add("  Path: " .. c.path)
        add("  Args: " .. c.args)
    end
    add("--- Prompt Hits (" .. #State.deepData.promptHits .. ") ---")
    for _, c in ipairs(State.deepData.promptHits) do
        add("[" .. c.time .. "] " .. c.prompt .. " | " .. c.path)
    end
    add("--- Spawns (" .. #State.deepData.spawns .. ") ---")
    for _, c in ipairs(State.deepData.spawns) do
        add("[" .. c.time .. "] " .. c.name .. " | " .. c.path)
    end
    add("")

    if includeSources then
        add("========== SCRIPT SOURCES ==========")
        add("")
        for ri, r in ipairs(State.results) do
            add("------ " .. r.path .. " [" .. r.className .. "] ------")
            add("Category: " .. r.category .. " | Size: " .. r.size .. " | Status: " .. r.status)
            add("")
            if r.source and #r.source > 0 then
                add(r.source)
            else
                add("[NO SOURCE AVAILABLE]")
            end
            add("")
            if ri % 50 == 0 then
                RunService.RenderStepped:Wait()
            end
        end
    end

    return buf
end

local function exportTXT(includeSources)
    if includeSources == nil then includeSources = true end
    local buf = buildReportBuf(includeSources)
    local saved, size = writeChunked(buf, safeGameName, ".txt")

    if saved then
        State.lastExportPath = saved
        if setclipboard and size <= CLIPBOARD_LIMIT then
            -- clipboard only for small reports; big ones freeze
            local out = table.concat(buf, "\n")
            setclipboard(out)
        end
        local note = size > CLIPBOARD_LIMIT and " (too big for clipboard)" or " + clipboard"
        notify("Export Saved", saved .. note, 6)
        return true
    else
        notify("Export Failed", "writefile unavailable", 6)
        return false
    end
end

local function exportSourcesToFiles()
    if not writefile then
        notify("Export", "writefile unavailable", 4)
        return
    end
    local folder = safeGameName .. "_sources"
    if makefolder and not isfolder(folder) then
        pcall(makefolder, folder)
    end
    local count = 0
    for i, r in ipairs(State.results) do
        if r.source and #r.source > 0 and (r.status == "OK" or r.status == "BYTECODE") then
            local fname = folder .. "/" .. sanitizeFilename(r.name) .. "_" .. i .. ".lua"
            pcall(writefile, fname, "-- " .. r.path .. "\n-- " .. r.className .. " | " .. r.category .. "\n\n" .. r.source)
            count = count + 1
            if count % 20 == 0 then
                RunService.RenderStepped:Wait()
            end
        end
    end
    notify("Sources", "Saved " .. count .. " files to " .. folder, 5)
end

-- ============== DEEP SCAN ==============

local originalNamecall = nil
local namecallHooked = false

restoreHook = function()
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

local function disconnectDeep()
    if connections.promptAdded then
        pcall(function() connections.promptAdded:Disconnect() end)
        connections.promptAdded = nil
    end
    if connections.spawnWatch then
        pcall(function() connections.spawnWatch:Disconnect() end)
        connections.spawnWatch = nil
    end
end

local function startDeepScan(duration)
    duration = duration or 300
    if State.deepScanning then
        notify("Deep Scan", "Already running", 3)
        return
    end
    State.deepScanning = true
    State.deepData = {remoteCalls = {}, promptHits = {}, spawns = {}}
    notify("Deep Scan", "Monitoring " .. duration .. "s — play normally", 5)

    pcall(function()
        for _, d in ipairs(getAllDescendants(Workspace)) do
            if d:IsA("ProximityPrompt") then
                d.Triggered:Connect(function(plr)
                    if plr == LocalPlayer then
                        table.insert(State.deepData.promptHits, {
                            time = os.date("%H:%M:%S"),
                            prompt = d.Name,
                            path = d:GetFullName()
                        })
                    end
                end)
            end
        end
    end)

    connections.promptAdded = Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("ProximityPrompt") then
            d.Triggered:Connect(function(plr)
                if plr == LocalPlayer then
                    table.insert(State.deepData.promptHits, {
                        time = os.date("%H:%M:%S"),
                        prompt = d.Name,
                        path = d:GetFullName()
                    })
                end
            end)
        end
    end)

    connections.spawnWatch = Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then
            table.insert(State.deepData.spawns, {
                time = os.date("%H:%M:%S"),
                name = d.Name,
                path = d:GetFullName()
            })
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
                    argStr = argStr .. "[" .. i .. "]:" .. t .. "=" .. tostring(arg):sub(1, 30) .. " "
                end
                table.insert(State.deepData.remoteCalls, {
                    time = os.date("%H:%M:%S"),
                    method = method,
                    remote = self.Name,
                    path = self:GetFullName(),
                    args = argStr
                })
            end
            return originalNamecall(self, ...)
        end)
        setreadonly(mt, true)
        namecallHooked = true
    end)

    task.delay(duration, function()
        if State.deepScanning then
            restoreHook()
            disconnectDeep()
            State.deepScanning = false
            notify("Deep Scan Done", string.format("Calls: %d | Prompts: %d | Spawns: %d",
                #State.deepData.remoteCalls, #State.deepData.promptHits, #State.deepData.spawns), 6)
        end
    end)
end

local function stopDeepScan()
    if not State.deepScanning then return end
    State.deepScanning = false
    disconnectDeep()
    restoreHook()
    notify("Deep Scan Stopped", string.format("Calls: %d | Prompts: %d | Spawns: %d",
        #State.deepData.remoteCalls, #State.deepData.promptHits, #State.deepData.spawns), 5)
end

local function runDiagnostics()
    local lines = {}
    local function log(t) table.insert(lines, t) end
    log("=== PHANTOM DIAGNOSTICS ===")
    log("Executor: " .. executorInfo)
    log("writefile: " .. tostring(type(writefile)))
    log("getsrc: " .. tostring(type(getsrc)))
    log("decompile: " .. tostring(type(decompile)))
    log("getscriptbytecode: " .. tostring(type(getscriptbytecode)))
    log("Source budget: " .. CFG.maxTotalMB .. "MB used " .. string.format("%.1f", State.sourceBytes / 1000000) .. "MB")
    log("GameName: " .. GameName)
    log("PlaceId: " .. tostring(game.PlaceId))
    local report = table.concat(lines, "\n")
    print(report)
    return report
end

local function runScanPipeline(progressCb)
    State.busy = true
    State.cancelScan = false
    State.scanStart = os.clock()

    scanScripts(progressCb)
    if not State.cancelScan then scanRemotes() end
    if not State.cancelScan then scanObjects() end
    if not State.cancelScan then scanAssets() end
    if not State.cancelScan then scanSecurity() end

    State.scanDuration = os.clock() - State.scanStart
    local wasCancelled = State.cancelScan
    State.busy = false
    State.cancelScan = false

    if wasCancelled then
        notify("Scan", "Cancelled", 3)
    else
        notify("Scan Complete", string.format("%.1fs | %d scripts | %d remotes | %d values",
            State.scanDuration, State.stats.total,
            #State.remotes.events + #State.remotes.functions,
            #State.objects.values), 6)
    end
end

-- ============== TABS ==============

local TabMain = Window:CreateTab("Main", 4483345998)
TabMain:CreateSection("Scanner Control")

local progressLabel = TabMain:CreateLabel("ready.")

TabMain:CreateButton({
    Name = "FULL SCAN (everything)",
    Callback = function()
        task.spawn(function()
            runScanPipeline(function(done, total)
                pcall(function()
                    progressLabel:Set(string.format(
                        "scanning... %d / %d (%d%%) | src %.1fMB",
                        done, total, math.floor(done / total * 100),
                        State.sourceBytes / 1000000))
                end)
            end)
            pcall(function()
                progressLabel:Set(string.format(
                    "done in %.1fs — OK:%d BC:%d Fail:%d Dup:%d CoreSkip:%d Trunc:%d",
                    State.scanDuration, State.stats.success,
                    State.stats.bytecode, State.stats.failed,
                    State.stats.deduped, State.stats.skippedCore,
                    State.stats.truncated))
            end)
            if refreshScriptDropdown then refreshScriptDropdown() end
        end)
    end
})

TabMain:CreateButton({
    Name = "Scripts Only",
    Callback = function()
        task.spawn(function()
            State.busy = true
            State.cancelScan = false
            State.scanStart = os.clock()
            scanScripts(function(done, total)
                pcall(function()
                    progressLabel:Set(string.format("scanning... %d / %d", done, total))
                end)
            end)
            State.scanDuration = os.clock() - State.scanStart
            State.busy = false
            pcall(function()
                progressLabel:Set(string.format("scripts done in %.1fs", State.scanDuration))
            end)
            if refreshScriptDropdown then refreshScriptDropdown() end
        end)
    end
})

TabMain:CreateButton({
    Name = "Cancel Current Scan",
    Callback = function()
        if State.busy then
            State.cancelScan = true
            notify("Scan", "Cancelling...", 2)
        end
    end
})

TabMain:CreateSection("Individual Scans")

TabMain:CreateButton({Name = "Remotes Only", Callback = function() task.spawn(scanRemotes) end})
TabMain:CreateButton({
    Name = "Objects + Assets",
    Callback = function() task.spawn(function() scanObjects() scanAssets() end) end
})
TabMain:CreateButton({Name = "Security Scan", Callback = function() task.spawn(scanSecurity) end})
TabMain:CreateButton({
    Name = "Diagnostics (F9 console)",
    Callback = function()
        local report = runDiagnostics()
        notify("Diagnostics", report:sub(1, 120) .. "...", 5)
    end
})

-- scripts tab
local TabScr = Window:CreateTab("Scripts", 4483345998)
TabScr:CreateSection("Search + Select")

TabScr:CreateInput({
    Name = "Search (name or path)",
    PlaceholderText = "type to filter scripts...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        State._searchQuery = text or ""
        if refreshScriptDropdown then refreshScriptDropdown() end
    end
})

local filterOptions = {"All", "Combat", "Movement", "Economy", "NPC", "Remote",
    "DataStore", "Security", "Animation", "Audio", "Client", "Server", "Module", "Other"}
local filterIndex = 1

TabScr:CreateDropdown({
    Name = "Category Filter",
    Options = filterOptions,
    CurrentOption = {"All"},
    Callback = function(opt)
        for i, name in ipairs(filterOptions) do
            if name == opt[1] then filterIndex = i break end
        end
        if refreshScriptDropdown then refreshScriptDropdown() end
    end
})

local scriptSelectDropdown = TabScr:CreateDropdown({
    Name = "Select Script",
    Options = {"run a scan first"},
    CurrentOption = {},
    Callback = function(opt)
        State.selectedScript = nil
        if opt and opt[1] then
            local idx = tonumber(opt[1]:match("#(%d+)$"))
            if idx and State.filteredScripts[idx] then
                State.selectedScript = State.filteredScripts[idx]
            end
        end
    end
})

TabScr:CreateSection("Actions")

TabScr:CreateButton({
    Name = "Copy Selected Source",
    Callback = function()
        local r = State.selectedScript
        if not r then notify("Scripts", "No script selected", 3) return end
        local content = (r.source and #r.source > 0) and r.source
            or ("-- no source available\n-- path: " .. r.path)
        if setclipboard then
            setclipboard(content)
            notify("Copied", r.name .. " (" .. tostring(#content) .. " bytes)", 3)
        end
    end
})

TabScr:CreateButton({
    Name = "Copy Selected Path",
    Callback = function()
        local r = State.selectedScript
        if not r then notify("Scripts", "No script selected", 3) return end
        if setclipboard then setclipboard(r.path) notify("Copied", r.path, 3) end
    end
})

TabScr:CreateButton({
    Name = "Save Selected Source to File",
    Callback = function()
        local r = State.selectedScript
        if not r then notify("Scripts", "No script selected", 3) return end
        if writefile then
            local fname = safeGameName .. "_" .. sanitizeFilename(r.name) .. ".lua"
            pcall(writefile, fname, "-- " .. r.path .. "\n\n" .. (r.source or ""))
            notify("Saved", fname, 3)
        end
    end
})

TabScr:CreateButton({
    Name = "Copy ALL Sources (capped 1.5MB)",
    Callback = function()
        task.spawn(function()
            local all = {}
            local total = 0
            for _, r in ipairs(State.results) do
                if (r.status == "OK" or r.status == "BYTECODE") and r.source and #r.source > 0 then
                    total = total + #r.source
                    if total > CLIPBOARD_LIMIT then
                        notify("Copy", "Capped at 1.5MB — use file export for everything", 5)
                        break
                    end
                    table.insert(all, "--===== " .. r.path .. " [" .. r.className .. "] =====")
                    table.insert(all, r.source)
                    table.insert(all, "")
                end
            end
            local out = table.concat(all, "\n")
            if setclipboard and #out > 0 then
                setclipboard(out)
                notify("Copy", tostring(#out) .. " bytes", 3)
            end
        end)
    end
})

refreshScriptDropdown = function()
    task.spawn(function()
        local query = (State._searchQuery or ""):lower()
        local selCat = filterOptions[filterIndex]
        State.filteredScripts = {}
        local options = {}

        for _, r in ipairs(State.results) do
            local matchesCat = (selCat == "All") or (r.category == selCat)
            local matchesQuery = (query == "")
                or r.name:lower():find(query, 1, true)
                or r.path:lower():find(query, 1, true)
            if matchesCat and matchesQuery then
                table.insert(State.filteredScripts, r)
                local tag = (r.status == "OK") and "OK" or (r.status == "BYTECODE" and "BC" or "X")
                table.insert(options, tag .. " [" .. r.className .. "] " .. r.name .. " #" .. tostring(#State.filteredScripts))
                if #options >= 150 then break end
            end
        end

        if #options == 0 then
            options = {"no matches — scan first?"}
        end

        pcall(function()
            scriptSelectDropdown:Refresh(options)
        end)
    end)
end

-- remotes tab
local TabRem = Window:CreateTab("Remotes", 4483345998)
TabRem:CreateSection("Remote Tester")

local remoteSelectDropdown = TabRem:CreateDropdown({
    Name = "Select Remote",
    Options = {"scan first"},
    CurrentOption = {},
    Callback = function(opt)
        State.selectedRemote = nil
        if opt and opt[1] then
            local idx = tonumber(opt[1]:match("#(%d+)$"))
            if idx and State.remoteList[idx] then
                State.selectedRemote = State.remoteList[idx]
                State.remotePath = State.remoteList[idx].path
                notify("Loaded", State.remoteList[idx].path, 3)
            end
        end
    end
})

TabRem:CreateInput({
    Name = "Remote Path (auto-filled on select)",
    PlaceholderText = "Workspace.RemoteName",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) State.remotePath = text or "" end
})

TabRem:CreateInput({
    Name = "Args (comma-separated)",
    PlaceholderText = '5, true, "hello", nil',
    RemoveTextAfterFocusLost = false,
    Callback = function(text) State.remoteArgs = text or "" end
})

local function parseArgs(str)
    local args = {}
    if not str or str == "" then return args end
    for chunk in string.gmatch(str, "[^,]+") do
        local v = chunk:match("^%s*(.-)%s*$")
        if v == "true" then
            v = true
        elseif v == "false" then
            v = false
        elseif v == "nil" then
            v = nil
        elseif tonumber(v) then
            v = tonumber(v)
        else
            local q = v:match('^"(.*)"$') or v:match("^'(.*)'$")
            v = q or v
        end
        table.insert(args, v)
    end
    return args
end

TabRem:CreateButton({
    Name = "Check Path (resolve + class)",
    Callback = function()
        task.spawn(function()
            local obj = resolvePath(State.remotePath)
            if obj then
                notify("Resolved", obj.ClassName .. " | " .. obj:GetFullName(), 5)
            else
                notify("Failed", "Cannot resolve: " .. tostring(State.remotePath), 4)
            end
        end)
    end
})

TabRem:CreateButton({
    Name = "Fire RemoteEvent",
    Callback = function()
        task.spawn(function()
            local obj = resolvePath(State.remotePath)
            if not obj then notify("Error", "Resolve failed", 4) return end
            if not obj:IsA("RemoteEvent") then
                notify("Error", "Not a RemoteEvent (" .. obj.ClassName .. ")", 4)
                return
            end
            local args = parseArgs(State.remoteArgs)
            local ok, err = pcall(function() obj:FireServer(unpack(args)) end)
            notify(ok and "Fired" or "Error",
                ok and (tostring(#args) .. " args") or tostring(err), 4)
        end)
    end
})

TabRem:CreateButton({
    Name = "Invoke RemoteFunction",
    Callback = function()
        task.spawn(function()
            local obj = resolvePath(State.remotePath)
            if not obj then notify("Error", "Resolve failed", 4) return end
            if not obj:IsA("RemoteFunction") then
                notify("Error", "Not a RemoteFunction (" .. obj.ClassName .. ")", 4)
                return
            end
            local args = parseArgs(State.remoteArgs)
            local ok, res = pcall(function() return obj:InvokeServer(unpack(args)) end)
            if ok then
                local s
                if type(res) == "table" then
                    local e, j = pcall(function() return HttpService:JSONEncode(res) end)
                    s = (e and j) or tostring(res)
                else
                    s = tostring(res)
                end
                notify("Returned", s:sub(1, 200), 6)
            else
                notify("Error", tostring(res), 5)
            end
        end)
    end
})

TabRem:CreateSection("Templates")

TabRem:CreateButton({
    Name = "Generate + Copy Templates",
    Callback = function()
        task.spawn(function()
            local t = generateTemplates()
            if setclipboard then setclipboard(t) end
            pcall(writefile, safeGameName .. "_templates.lua", t)
            notify("Templates", "Copied + saved", 5)
        end)
    end
})

TabRem:CreateButton({
    Name = "Smart Templates (deep scan)",
    Callback = function()
        task.spawn(function()
            local t = generateSmartTemplates()
            if setclipboard then setclipboard(t) end
            pcall(writefile, safeGameName .. "_smart_templates.lua", t)
            notify("Smart Templates", #State.deepData.remoteCalls .. " calls processed", 5)
        end)
    end
})

local function refreshRemoteDropdown()
    task.spawn(function()
        State.remoteList = {}
        local options = {}
        for _, e in ipairs(State.remotes.events) do
            table.insert(State.remoteList, {path = e.path, name = e.name})
            table.insert(options, "EV " .. e.name .. " #" .. tostring(#State.remoteList))
        end
        for _, f in ipairs(State.remotes.functions) do
            table.insert(State.remoteList, {path = f.path, name = f.name})
            table.insert(options, "FN " .. f.name .. " #" .. tostring(#State.remoteList))
        end
        if #options == 0 then options = {"scan first"} end
        pcall(function() remoteSelectDropdown:Refresh(options) end)
    end)
end

-- objects tab
local TabObj = Window:CreateTab("Objects", 4483345998)
TabObj:CreateSection("NPCs")

local npcDropdown = TabObj:CreateDropdown({
    Name = "Select NPC",
    Options = {"scan first"},
    CurrentOption = {},
    Callback = function(opt)
        State.selectedNPC = nil
        if opt and opt[1] then
            local idx = tonumber(opt[1]:match("#(%d+)$"))
            if idx and State.objects.humanoids[idx] then
                State.selectedNPC = State.objects.humanoids[idx]
            end
        end
    end
})

TabObj:CreateButton({
    Name = "Refresh NPC List",
    Callback = function()
        task.spawn(function()
            local options = {}
            for i, n in ipairs(State.objects.humanoids) do
                table.insert(options, n.name .. " #" .. tostring(i))
            end
            if #options == 0 then options = {"no NPCs — scan first"} end
            pcall(function() npcDropdown:Refresh(options) end)
            notify("NPCs", tostring(#State.objects.humanoids) .. " found", 3)
        end)
    end
})

TabObj:CreateButton({
    Name = "Teleport to Selected NPC",
    Callback = function()
        local n = State.selectedNPC
        if not n then notify("Objects", "Select an NPC first", 3) return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and n.px then
            hrp.CFrame = CFrame.new(n.px, n.py + 2, n.pz)
            notify("Teleported", "to " .. n.name, 3)
        end
    end
})

TabObj:CreateButton({
    Name = "Object Counts (F9)",
    Callback = function()
        print("=== OBJECTS ===")
        print("Prompts: " .. #State.objects.prompts)
        print("ClickDetectors: " .. #State.objects.clickDetectors)
        print("NPCs: " .. #State.objects.humanoids)
        print("Values: " .. #State.objects.values)
        notify("Objects", "Details in F9", 4)
    end
})

-- values tab
local TabVal = Window:CreateTab("Values", 4483345998)
TabVal:CreateSection("Value Editor")

local valueDropdown = TabVal:CreateDropdown({
    Name = "Select Value",
    Options = {"search below first"},
    CurrentOption = {},
    Callback = function(opt)
        State.selectedValue = nil
        if opt and opt[1] then
            local idx = tonumber(opt[1]:match("#(%d+)$"))
            if idx and State.filteredValues[idx] then
                State.selectedValue = State.filteredValues[idx]
                notify("Selected", State.filteredValues[idx].path, 4)
            end
        end
    end
})

TabVal:CreateInput({
    Name = "Search values",
    PlaceholderText = "Speed, Enabled, DoorKey...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) State._valueQuery = text or "" end
})

TabVal:CreateButton({
    Name = "Search Values",
    Callback = function()
        task.spawn(function()
            local query = (State._valueQuery or ""):lower()
            State.filteredValues = {}
            local options = {}
            for _, v in ipairs(State.objects.values) do
                if query == "" or v.path:lower():find(query, 1, true) then
                    table.insert(State.filteredValues, v)
                    table.insert(options, "[" .. v.class:sub(1,3) .. "] " .. v.path:sub(-50)
                        .. " = " .. tostring(v.val) .. " #" .. tostring(#State.filteredValues))
                    if #State.filteredValues >= 100 then break end
                end
            end
            if #options == 0 then options = {"no matches"} end
            pcall(function() valueDropdown:Refresh(options) end)
            notify("Values", tostring(#State.filteredValues) .. " matching", 3)
        end)
    end
})

TabVal:CreateInput({
    Name = "New Value (true/false/number/text)",
    PlaceholderText = "true",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) State._newValue = text or "" end
})

TabVal:CreateButton({
    Name = "Apply to Selected Value",
    Callback = function()
        local v = State.selectedValue
        if not v then notify("Values", "Select a value first", 3) return end
        local inst = v.ref
        if not inst or not inst.Parent then
            notify("Values", "Instance gone", 4)
            return
        end
        local ok = pcall(function()
            local raw = State._newValue or ""
            if inst:IsA("BoolValue") then
                inst.Value = (raw:lower() == "true")
            elseif inst:IsA("NumberValue") or inst:IsA("IntValue") then
                inst.Value = tonumber(raw) or 0
            else
                inst.Value = raw
            end
        end)
        notify(ok and "Value Set" or "Error", v.path, 4)
    end
})

-- security tab
local TabSec = Window:CreateTab("Security", 4483345998)
TabSec:CreateSection("Detections")

TabSec:CreateButton({
    Name = "Print Security Report (F9)",
    Callback = function()
        print("=== SECURITY REPORT ===")
        print("--- AntiCheat (" .. #State.acDetections .. ") ---")
        for i, d in ipairs(State.acDetections) do
            if i > 50 then print("...more") break end
            print(d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
            print("  " .. d.text)
        end
        print("--- Backdoors (" .. #State.bdDetections .. ") ---")
        for i, d in ipairs(State.bdDetections) do
            if i > 50 then print("...more") break end
            print(d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
            print("  " .. d.text)
        end
        print("--- Webhooks (" .. #State.webhookHits .. ") ---")
        for i, d in ipairs(State.webhookHits) do
            if i > 30 then print("...more") break end
            print(d.script .. ":L" .. d.line .. " | " .. d.text)
        end
        notify("Security", "Report in F9", 5)
    end
})

TabSec:CreateButton({
    Name = "Copy Security Report",
    Callback = function()
        local buf = {"=== SECURITY ==="}
        for _, d in ipairs(State.acDetections) do
            table.insert(buf, "AC: " .. d.script .. ":L" .. d.line .. " [" .. d.pattern .. "] " .. d.text)
        end
        for _, d in ipairs(State.bdDetections) do
            table.insert(buf, "BD: " .. d.script .. ":L" .. d.line .. " [" .. d.pattern .. "] " .. d.text)
        end
        for _, d in ipairs(State.webhookHits) do
            table.insert(buf, "WH: " .. d.script .. ":L" .. d.line .. " " .. d.text)
        end
        if setclipboard then
            setclipboard(table.concat(buf, "\n"))
            notify("Security", "Copied", 3)
        end
    end
})

-- deep scan tab
local TabDeep = Window:CreateTab("Deep Scan", 4483345998)
TabDeep:CreateSection("Live Monitor")

local deepStatsLabel = TabDeep:CreateLabel("calls: 0 | prompts: 0 | spawns: 0")

task.spawn(function()
    while true do
        if State.deepScanning then
            pcall(function()
                deepStatsLabel:Set(string.format("calls: %d | prompts: %d | spawns: %d",
                    #State.deepData.remoteCalls, #State.deepData.promptHits, #State.deepData.spawns))
            end)
        end
        task.wait(1)
    end
end)

TabDeep:CreateButton({Name = "Start Deep Scan (300s)", Callback = function() startDeepScan(300) end})
TabDeep:CreateButton({Name = "Start Deep Scan (60s)", Callback = function() startDeepScan(60) end})
TabDeep:CreateButton({Name = "Stop Deep Scan", Callback = function() stopDeepScan() end})

TabDeep:CreateButton({
    Name = "Print Remote Calls (F9)",
    Callback = function()
        print("=== REMOTE CALLS (" .. #State.deepData.remoteCalls .. ") ===")
        for i, c in ipairs(State.deepData.remoteCalls) do
            if i > 80 then print("...more") break end
            print("[" .. c.time .. "] " .. c.method .. "." .. c.remote)
            print("  Path: " .. c.path)
            print("  Args: " .. c.args)
        end
        notify("Deep Scan", "Calls in F9", 4)
    end
})

-- export tab
local TabExp = Window:CreateTab("Export", 4483345998)
TabExp:CreateSection("Export Options")

local exportLabel = TabExp:CreateLabel("filename: " .. safeGameName .. "_<timestamp>.txt")

TabExp:CreateButton({
    Name = "Export Full Report + Sources (chunked)",
    Callback = function()
        task.spawn(function()
            exportTXT(true)
            pcall(function()
                exportLabel:Set("last: " .. (State.lastExportPath ~= "" and State.lastExportPath or "failed"))
            end)
        end)
    end
})

TabExp:CreateButton({
    Name = "Export Report ONLY (fast, no sources)",
    Callback = function()
        task.spawn(function()
            exportTXT(false)
            pcall(function()
                exportLabel:Set("last: " .. (State.lastExportPath ~= "" and State.lastExportPath or "failed"))
            end)
        end)
    end
})

TabExp:CreateButton({
    Name = "Export Sources as .lua Files",
    Callback = function() task.spawn(exportSourcesToFiles) end
})

TabExp:CreateButton({
    Name = "Export Remote Templates",
    Callback = function()
        task.spawn(function()
            local t = generateTemplates()
            local saved = writeSingle(t, safeGameName .. "_templates", ".lua")
            if setclipboard then setclipboard(t) end
            notify("Templates", saved or "clipboard only", 5)
        end)
    end
})

TabExp:CreateButton({
    Name = "Export Smart Templates",
    Callback = function()
        task.spawn(function()
            local t = generateSmartTemplates()
            local saved = writeSingle(t, safeGameName .. "_smart", ".lua")
            if setclipboard then setclipboard(t) end
            notify("Smart Templates", saved or "clipboard only", 5)
        end)
    end
})

-- settings tab
local TabSet = Window:CreateTab("Settings", 4483345998)
TabSet:CreateSection("Performance (anti-freeze)")

TabSet:CreateToggle({
    Name = "Safe Mode (yield every script — slowest, safest)",
    CurrentValue = CFG.safeMode,
    Flag = "SafeModeToggle",
    Callback = function(v)
        CFG.safeMode = v
        saveConfig(CFG)
        notify("Setting", v and "Safe Mode ON" or "Safe Mode OFF (faster, riskier)", 3)
    end
})

TabSet:CreateToggle({
    Name = "Skip CoreGui Scripts (recommended)",
    CurrentValue = CFG.skipCoreGui,
    Flag = "SkipCoreGuiToggle",
    Callback = function(v)
        CFG.skipCoreGui = v
        saveConfig(CFG)
        notify("Setting", v and "CoreGui skip ON" or "CoreGui skip OFF", 3)
    end
})

TabSet:CreateToggle({
    Name = "Scan CoreGui Container (noise warning)",
    CurrentValue = CFG.scanCoreGui,
    Flag = "ScanCoreGuiToggle",
    Callback = function(v)
        CFG.scanCoreGui = v
        saveConfig(CFG)
        notify("Setting", v and "CoreGui scanning ON" or "CoreGui scanning OFF", 3)
    end
})

TabSet:CreateSlider({
    Name = "Max Source Size per Script (KB)",
    Range = {50, 1000},
    Increment = 50,
    Suffix = "KB",
    CurrentValue = CFG.maxSourceKB,
    Flag = "MaxSourceKB",
    Callback = function(v)
        CFG.maxSourceKB = v
        saveConfig(CFG)
    end
})

TabSet:CreateSlider({
    Name = "Total Source Budget (MB)",
    Range = {5, 100},
    Increment = 5,
    Suffix = "MB",
    CurrentValue = CFG.maxTotalMB,
    Flag = "MaxTotalMB",
    Callback = function(v)
        CFG.maxTotalMB = v
        saveConfig(CFG)
    end
})

TabSet:CreateSection("Scan Config")

TabSet:CreateToggle({
    Name = "Deduplicate Scripts",
    CurrentValue = CFG.dedup,
    Flag = "DedupToggle",
    Callback = function(v)
        CFG.dedup = v
        saveConfig(CFG)
        notify("Setting", v and "Dedup ON" or "Dedup OFF", 3)
    end
})

-- wire dropdown refresh after scans
local origRunPipeline = runScanPipeline
runScanPipeline = function(cb)
    origRunPipeline(cb)
    refreshRemoteDropdown()
end

local origScanRemotes = scanRemotes
scanRemotes = function()
    origScanRemotes()
    refreshRemoteDropdown()
end

print("=== PHANTOM SCANNER v11.2 loaded ===")
print("=== Game: " .. GameName .. " ===")
notify("Phantom Ready", GameName .. " | v11.2 (anti-freeze) loaded", 6)
