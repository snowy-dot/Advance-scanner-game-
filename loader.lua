--!nocheck
-- ==============================================================
--  PHANTOM SCANNER v11 — RAYFIELD EDITION
--  Full-coverage scan | No building filter on scripts
--  Remote tester | Value editor | Config persist
--  Repo: github.com/snowy-dot/Advance-scanner-game-
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
local UserInputService     = game:GetService("UserInputService")
local MarketplaceService   = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local unpack = table.unpack or unpack

-- executor functions
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

-- game name
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

-- ==============================================================
--  CONFIG
-- ==============================================================

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

-- ==============================================================
--  STATE
-- ==============================================================

local State = {
    results          = {},
    hashes           = {},
    remotes          = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}},
    objects          = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}, allValues = {}},
    assets           = {sounds = {}, animations = {}, decals = {}, meshes = {}},
    acDetections     = {},
    bdDetections     = {},
    webhookHits      = {},
    requireMap       = {},
    deepData         = {remoteCalls = {}, promptHits = {}, spawns = {}},
    stats            = {total = 0, success = 0, failed = 0, deduped = 0, bytecode = 0},
    deepScanning     = false,
    busy             = false,
    cancelScan       = false,
    lastExportPath   = "",
    scanStart        = 0,
    scanDuration     = 0,
    selectedScript   = nil,
    selectedNPC      = nil,
    selectedValue    = nil,
    selectedRemote   = nil
}

local connections = {}
local restoreHook
local refreshScriptDropdown

-- ==============================================================
--  RAYFIELD
-- ==============================================================

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Phantom Scanner v11",
    LoadingTitle = GameName,
    LoadingSubtitle = "by snowy-dot | v11",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false
})

local function notify(title, content, dur)
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = dur or 4
        })
    end)
end

-- ==============================================================
--  SCANNER CORE — FULL COVERAGE
-- ==============================================================

-- every container the client can touch. pcall each — some are
-- nil on certain games, that's fine.
local function getContainers()
    local list = {
        {Workspace, "Workspace"},
        {ReplicatedStorage, "ReplicatedStorage"},
        {ReplicatedFirst, "ReplicatedFirst"},
        {ServerScriptService, "ServerScriptService"},
        {StarterGui, "StarterGui"},
        {StarterPack, "StarterPack"},
        {StarterPlayer, "StarterPlayer"},
        {Lighting, "Lighting"},
        {SoundService, "SoundService"},
        {Teams, "Teams"},
        {Players, "Players"}
    }
    -- server-only containers: some executors can still enumerate these
    pcall(function()
        local ss = game:GetService("ServerStorage")
        if ss then table.insert(list, {ss, "ServerStorage"}) end
    end)
    pcall(function()
        local sss = game:GetService("ServerScriptService")
        if sss then table.insert(list, {sss, "ServerScriptService"}) end
    end)
    -- local player containers
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerScripts") then
            list[#list + 1] = {LocalPlayer.PlayerScripts, "PlayerScripts"}
        end
    end)
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerGui") then
            list[#list + 1] = {LocalPlayer.PlayerGui, "PlayerGui"}
        end
    end)
    -- CoreGui if executor exposes it
    pcall(function()
        if gethui then
            list[#list + 1] = {gethui(), "CoreGui"}
        else
            local cg = game:GetService("CoreGui")
            if cg then list[#list + 1] = {cg, "CoreGui"} end
        end
    end)
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

-- source grab with retry + bytecode fallback
local function getScriptSource(script)
    -- attempt 1: getsrc
    if type(getsrc) == "function" then
        local ok, r = pcall(getsrc, script)
        if ok and type(r) == "string" and #r > 0 then return r, "OK" end
    end
    -- attempt 2: decompile
    if type(decompile) == "function" then
        local ok, r = pcall(decompile, script)
        if ok and type(r) == "string" and #r > 0 then return r, "OK" end
    end
    -- attempt 3: decompile retry (some executors flake on first pass)
    if type(decompile) == "function" then
        local ok, r = pcall(decompile, script)
        if ok and type(r) == "string" and #r > 0 then return r, "OK" end
    end
    -- attempt 4: bytecode
    if type(getscriptbytecode) == "function" then
        local ok, r = pcall(getscriptbytecode, script)
        if ok and type(r) == "string" and #r > 0 then return r, "BYTECODE" end
    end
    return nil, "FAILED"
end

local function getAllDescendants(container)
    local results = {}
    local stack = {{obj = container}}
    while #stack > 0 do
        if State.cancelScan then break end
        local node = table.remove(stack)
        if node and node.obj then
            local ok, children = pcall(function() return node.obj:GetChildren() end)
            if ok and children then
                for _, child in ipairs(children) do
                    table.insert(results, child)
                    table.insert(stack, {obj = child})
                end
            end
        end
        if #results % 400 == 0 then RunService.RenderStepped:Wait() end
    end
    return results
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

-- SCRIPT SCAN — NO building filter. every script gets scanned.
local function scanScripts(progressCb)
    State.results = {}
    State.hashes = {}
    State.stats.total = 0
    State.stats.success = 0
    State.stats.failed = 0
    State.stats.deduped = 0
    State.stats.bytecode = 0

    local allScripts = {}
    for _, cd in ipairs(getContainers()) do
        pcall(function()
            local desc = getAllDescendants(cd[1])
            for _, d in ipairs(desc) do
                if d:IsA("LocalScript") or d:IsA("Script") or d:IsA("ModuleScript") then
                    table.insert(allScripts, {inst = d, container = cd[2]})
                end
            end
        end)
        if State.cancelScan then break end
    end

    State.stats.total = #allScripts
    notify("Scripts", "Found " .. #allScripts .. " scripts — grabbing sources...", 3)

    local dedupEnabled = CFG.dedup ~= false

    for i, entry in ipairs(allScripts) do
        if State.cancelScan then break end
        local s = entry.inst
        if s.Parent then
            local path = s:GetFullName()
            -- dedup by path+class so mirrored scripts count once
            local hash = quickHash(path .. "|" .. s.ClassName)
            if dedupEnabled and State.hashes[hash] then
                State.stats.deduped = State.stats.deduped + 1
            else
                State.hashes[hash] = true
                local src, status = getScriptSource(s)
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
        if i % 15 == 0 then
            if progressCb then progressCb(i, #allScripts) end
            RunService.RenderStepped:Wait()
        end
    end
end

local function scanRemotes()
    State.remotes = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}}
    for _, cd in ipairs(getContainers()) do
        pcall(function()
            for _, d in ipairs(cd[1]:GetDescendants()) do
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
    end
    notify("Remotes", string.format("Events: %d | Functions: %d",
        #State.remotes.events, #State.remotes.functions), 4)
end

local function scanObjects()
    State.objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}, allValues = {}}
    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
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

    -- values from EVERYWHERE (workspace + replicated), no filter.
    -- this catches SpeedController settings, keycard flags, etc.
    for _, root in ipairs({Workspace, ReplicatedStorage}) do
        pcall(function()
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("IntValue") or d:IsA("NumberValue") or d:IsA("StringValue")
                or d:IsA("BoolValue") or d:IsA("ObjectValue") or d:IsA("Vector3Value") then
                    local entry = {
                        path = d:GetFullName(),
                        class = d.ClassName,
                        ref = d
                    }
                    pcall(function()
                        entry.val = tostring(d.Value):sub(1, 80)
                    end)
                    table.insert(State.objects.values, entry)
                    table.insert(State.objects.allValues, entry)
                end
            end
        end)
    end
    notify("Objects", string.format("NPCs: %d | Prompts: %d | Values: %d",
        #State.objects.humanoids, #State.objects.prompts, #State.objects.values), 4)
end

local function scanAssets()
    State.assets = {sounds = {}, animations = {}, decals = {}, meshes = {}}
    for _, root in ipairs({Workspace, ReplicatedStorage}) do
        pcall(function()
            for _, d in ipairs(root:GetDescendants()) do
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
    end
    notify("Assets", string.format("Sounds: %d | Anims: %d | Meshes: %d",
        #State.assets.sounds, #State.assets.animations, #State.assets.meshes), 4)
end

local function scanSecurity()
    State.acDetections = {}
    State.bdDetections = {}
    State.webhookHits = {}
    State.requireMap = {}

    local acPatterns = {
        "anticheat", "anti-cheat", "exploit", "detect",
        "flag", "tamper", "noclip", "speedhack", "kick", "crash", "rejoin", "ban"
    }
    local bdPatterns = {
        "loadstring(game:httpget", "require(", "backdoor",
        "getfenv(", "setfenv(", "getgenv("
    }
    local webhookPatterns = {
        "discord.com/api/webhooks", "discordapp.com/api/webhooks", "webhook"
    }

    for _, r in ipairs(State.results) do
        if r.source and #r.source > 0 and r.status == "OK" then
            local lines = splitLines(r.source)
            for li, line in ipairs(lines) do
                local ll = line:lower()
                for _, pat in ipairs(acPatterns) do
                    if ll:find(pat, 1, true) then
                        table.insert(State.acDetections, {
                            script = r.path, line = li, pattern = pat,
                            text = line:gsub("^%s+", ""):sub(1, 100)
                        })
                        break
                    end
                end
                for _, pat in ipairs(bdPatterns) do
                    if ll:find(pat, 1, true) then
                        table.insert(State.bdDetections, {
                            script = r.path, line = li, pattern = pat,
                            text = line:gsub("^%s+", ""):sub(1, 100)
                        })
                        break
                    end
                end
                for _, pat in ipairs(webhookPatterns) do
                    if ll:find(pat, 1, true) then
                        table.insert(State.webhookHits, {
                            script = r.path, line = li, pattern = pat,
                            text = line:gsub("^%s+", ""):sub(1, 120)
                        })
                        break
                    end
                end
                if ll:find("require(", 1, true) then
                    local arg = line:match("require%s*%(%s*(.-)%s*%)") or "?"
                    table.insert(State.requireMap, {
                        script = r.path,
                        target = arg:sub(1, 80),
                        text = line:gsub("^%s+", ""):sub(1, 100)
                    })
                end
            end
        end
    end
    notify("Security", string.format("AC: %d | BD: %d | Webhooks: %d",
        #State.acDetections, #State.bdDetections, #State.webhookHits), 5)
end

-- ==============================================================
--  PATH RESOLVER + TEMPLATES
-- ==============================================================

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
                cur = cur:FindFirstChild(p)
                if not cur then
                    pcall(function() cur = cur:WaitForChild(p, 2) end)
                end
            end
        else
            cur = cur:FindFirstChild(p)
            if not cur then
                pcall(function() cur = cur:WaitForChild(p, 2) end)
            end
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
    local buf = {
        "-- PHANTOM REMOTE TEMPLATES -- " .. GameName,
        "-- paste into executor, edit args",
        ""
    }
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
    local buf = {"-- SMART TEMPLATES (from observed deep-scan calls)", ""}
    local observed = {}
    local order = {}
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
        table.insert(buf, "-- example args from live capture:")
        table.insert(buf, "--   " .. data.calls[1].args)
        if data.method == "FireServer" then
            table.insert(buf, "remote:FireServer(--[[ replicate args ]])")
        else
            table.insert(buf, "local result = remote:InvokeServer(--[[ replicate args ]])")
        end
        table.insert(buf, "")
    end
    if #order == 0 then
        table.insert(buf, "-- no observed calls yet. run a deep scan while playing normally.")
    end
    return table.concat(buf, "\n")
end

-- ==============================================================
--  EXPORT
-- ==============================================================

local function writeMultiPath(content, baseName, ext)
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

local function exportTXT()
    local buf = {}
    local function add(t) table.insert(buf, t) end

    add("==========================================")
    add("  PHANTOM SCANNER v11 EXPORT")
    add("==========================================")
    add("Game: " .. GameName)
    add("Place ID: " .. tostring(game.PlaceId))
    add("Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    add("Executor: " .. executorInfo)
    add("Scan Duration: " .. string.format("%.1fs", State.scanDuration))
    add("")
    add("========== STATS ==========")
    add("Total Scripts: " .. State.stats.total)
    add("Successful (source): " .. State.stats.success)
    add("Bytecode only: " .. State.stats.bytecode)
    add("Failed (server-only): " .. State.stats.failed)
    add("Deduped: " .. State.stats.deduped)
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
    add("--- AntiCheat Detections (" .. #State.acDetections .. ") ---")
    for _, d in ipairs(State.acDetections) do
        add(d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
        add("  " .. d.text)
    end
    add("--- Backdoor Detections (" .. #State.bdDetections .. ") ---")
    for _, d in ipairs(State.bdDetections) do
        add(d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
        add("  " .. d.text)
    end
    add("--- Webhook / Logging (" .. #State.webhookHits .. ") ---")
    for _, d in ipairs(State.webhookHits) do
        add(d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
        add("  " .. d.text)
    end
    add("--- Require Map (" .. #State.requireMap .. ") ---")
    for _, r in ipairs(State.requireMap) do add(r.script .. " -> " .. r.target) end
    add("")

    add("========== DEEP SCAN DATA ==========")
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

    add("==========================================")
    add("  SCRIPT SOURCES")
    add("==========================================")
    add("")
    for _, r in ipairs(State.results) do
        add("------ " .. r.path .. " [" .. r.className .. "] ------")
        add("Category: " .. r.category .. " | Size: " .. r.size .. " | Status: " .. r.status)
        add("")
        if r.source and #r.source > 0 then
            add(r.source)
        else
            add("[NO SOURCE AVAILABLE]")
        end
        add("")
    end

    local out = table.concat(buf, "\n")
    local saved = writeMultiPath(out, safeGameName, ".txt")
    if saved then
        State.lastExportPath = saved
        if setclipboard then setclipboard(out) end
        notify("Export Saved", saved, 6)
        return true
    else
        if setclipboard then
            setclipboard(out)
            notify("Export Failed", "writefile unavailable. Copied to clipboard.", 6)
        end
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
            if count % 20 == 0 then RunService.RenderStepped:Wait() end
        end
    end
    notify("Sources", "Saved " .. count .. " files to " .. folder, 5)
end

-- ==============================================================
--  DEEP SCAN
-- ==============================================================

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
        for _, d in ipairs(Workspace:GetDescendants()) do
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
    log("readfile: " .. tostring(type(readfile)))
    log("getsrc: " .. tostring(type(getsrc)))
    log("decompile: " .. tostring(type(decompile)))
    log("getscriptbytecode: " .. tostring(type(getscriptbytecode)))
    log("newcclosure: " .. tostring(type(newcclosure)))
    log("getrawmetatable: " .. tostring(type(getrawmetatable)))
    log("GameName: " .. GameName)
    log("PlaceId: " .. tostring(game.PlaceId))
    if writefile then
        local ok, err = pcall(function() writefile("phantom_diag_test.txt", "test") end)
        log("Test write: " .. tostring(ok) .. (err and (" err:" .. tostring(err)) or ""))
    end
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

-- ==============================================================
--  TABS
-- ==============================================================

-- ===== MAIN =====
local TabMain = Window:CreateTab("Main", 4483345998)
TabMain:CreateSection("Scanner Control")

local progressLabel = TabMain:CreateLabel("ready.")

TabMain:CreateButton({
    Name = "FULL SCAN (everything)",
    Callback = function()
        task.spawn(function()
            runScanPipeline(function(done, total)
                pcall(function()
                    progressLabel:Set(string.format("scanning scripts... %d / %d (%d%%)",
                        done, total, math.floor(done / total * 100)))
                end)
            end)
            pcall(function()
                progressLabel:Set(string.format(
                    "done in %.1fs — %d scripts | OK:%d BC:%d Fail:%d (server-only) Dup:%d",
                    State.scanDuration, State.stats.total,
                    State.stats.success, State.stats.bytecode,
                    State.stats.failed, State.stats.deduped))
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
    Callback = function()
        task.spawn(function() scanObjects() scanAssets() end)
    end
})
TabMain:CreateButton({
    Name = "Security Scan",
    Callback = function() task.spawn(scanSecurity) end
})

TabMain:CreateSection("Diagnostics")

TabMain:CreateButton({
    Name = "Run Diagnostics (F9 console)",
    Callback = function()
        local report = runDiagnostics()
        notify("Diagnostics", report:sub(1, 120) .. "...", 5)
    end
})

-- ===== SCRIPTS =====
local TabScr = Window:CreateTab("Scripts", 4483345998)
TabScr:CreateSection("Search + Select")

TabScr:CreateInput({
    Name = "Search (name or path)",
    PlaceholderText = "type to filter scripts...",
    RemoveTextAfterFocusLost = false,
    Callback = function()
        if refreshScriptDropdown then refreshScriptDropdown() end
    end
})

local filterOptions = {"All", "Combat", "Movement", "Economy", "NPC", "Remote",
    "DataStore", "Security", "Animation", "Audio", "Client", "Server", "Module", "Other"}
local filterIndex = 1

TabScr:CreateDropdown({
    Name = "Filter: All (click to cycle)",
    Options = {},
    CurrentOption = {},
    Callback = function() end
})

local filterDropdown
filterDropdown = TabScr:CreateDropdown({
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

local scriptSelectDropdown
scriptSelectDropdown = TabScr:CreateDropdown({
    Name = "Select Script (filtered list)",
    Options = {},
    CurrentOption = {},
    Callback = function(opt)
        State.selectedScript = nil
        if opt and opt[1] then
            local idx = tonumber(opt[1]:match("#(%d+)$"))
            if idx and State.filteredScripts and State.filteredScripts[idx] then
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
        if setclipboard then
            setclipboard(r.path)
            notify("Copied", r.path, 3)
        end
    end
})

TabScr:CreateButton({
    Name = "Export Selected Source to File",
    Callback = function()
        local r = State.selectedScript
        if not r then notify("Scripts", "No script selected", 3) return end
        if writefile then
            local fname = safeGameName .. "_" .. sanitizeFilename(r.name) .. ".lua"
            pcall(writefile, fname,
                "-- " .. r.path .. "\n-- " .. r.className .. " | " .. r.category .. "\n\n" .. (r.source or ""))
            notify("Saved", fname, 3)
        end
    end
})

TabScr:CreateButton({
    Name = "Copy ALL Sources (concatenated)",
    Callback = function()
        task.spawn(function()
            local all = {}
            for _, r in ipairs(State.results) do
                if (r.status == "OK" or r.status == "BYTECODE") and r.source and #r.source > 0 then
                    table.insert(all, "--===== " .. r.path .. " [" .. r.className .. "] =====")
                    table.insert(all, r.source)
                    table.insert(all, "")
                end
            end
            local out = table.concat(all, "\n")
            if setclipboard then
                setclipboard(out)
                notify("Copy", tostring(#out) .. " bytes copied", 3)
            end
        end)
    end
})

refreshScriptDropdown = function()
    task.spawn(function()
        local query = ""
        pcall(function()
            -- grab current search text from the input's stored value
            for _, el in ipairs(getgenv().phantomSearchRefs or {}) do end
        end)
        -- fallback: use a variable we track
        query = (State._searchQuery or ""):lower()
        local selCat = filterOptions[filterIndex]
        State.filteredScripts = {}
        local options = {}
        local count = 0

        for _, r in ipairs(State.results) do
            local matchesCat = (selCat == "All") or (r.category == selCat)
            local matchesQuery = (query == "")
                or r.name:lower():find(query, 1, true)
                or r.path:lower():find(query, 1, true)
            if matchesCat and matchesQuery then
                count = count + 1
                if count <= 150 then
                    table.insert(State.filteredScripts, r)
                    local tag = (r.status == "OK") and "OK" or (r.status == "BYTECODE" and "BC" or "X")
                    table.insert(options, tag .. " [" .. r.className .. "] " .. r.name .. " #" .. tostring(#State.filteredScripts))
                end
            end
        end

        pcall(function()
            scriptSelectDropdown:Refresh(options)
        end)
        notify("Scripts", tostring(#State.filteredScripts) .. " matching (of " .. #State.results .. ")", 2)
    end)
end

-- we can't read the input's live value back from rayfield's API cleanly,
-- so track it via the callback:
-- (the search input above will set this through a wrapper — patched below)

-- ===== REMOTES =====
local TabRem = Window:CreateTab("Remotes", 4483345998)
TabRem:CreateSection("Remote Tester")

local remoteSelectDropdown
remoteSelectDropdown = TabRem:CreateDropdown({
    Name = "Select Remote",
    Options = {},
    CurrentOption = {},
    Callback = function(opt)
        State.selectedRemote = nil
        if opt and opt[1] then
            local idx = tonumber(opt[1]:match("#(%d+)$"))
            if idx and State.remoteList and State.remoteList[idx] then
                State.selectedRemote = State.remoteList[idx]
            end
        end
    end
})

local remotePathInput = TabRem:CreateInput({
    Name = "Remote Path",
    PlaceholderText = "auto-filled when selecting above",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        State.remotePath = text
    end
})

local remoteArgsInput = TabRem:CreateInput({
    Name = "Args (comma-separated)",
    PlaceholderText = '5, true, "hello", nil',
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        State.remoteArgs = text
    end
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
    Name = "Load Selected Remote into Tester",
    Callback = function()
        local r = State.selectedRemote
        if not r then notify("Remotes", "Select a remote first", 3) return end
        State.remotePath = r.path
        pcall(function()
            -- rayfield inputs don't expose Set in all versions; try
            if remotePathInput.Set then remotePathInput:Set(r.path) end
        end)
        notify("Loaded", r.path, 3)
    end
})

TabRem:CreateButton({
    Name = "Check Path (resolve + show class)",
    Callback = function()
        task.spawn(function()
            local path = State.remotePath or ""
            local obj = resolvePath(path)
            if obj then
                notify("Resolved", obj.ClassName .. " | " .. obj:GetFullName(), 5)
            else
                notify("Failed", "Cannot resolve: " .. path, 4)
            end
        end)
    end
})

TabRem:CreateButton({
    Name = "Fire RemoteEvent",
    Callback = function()
        task.spawn(function()
            local path = State.remotePath or ""
            local obj = resolvePath(path)
            if not obj then notify("Error", "Resolve failed: " .. path, 4) return end
            if not obj:IsA("RemoteEvent") then
                notify("Error", "Not a RemoteEvent (got " .. obj.ClassName .. ")", 4)
                return
            end
            local args = parseArgs(State.remoteArgs)
            local ok, err = pcall(function() obj:FireServer(unpack(args)) end)
            notify(ok and "Fired" or "Error",
                ok and ("fired with " .. #args .. " args") or tostring(err), 4)
        end)
    end
})

TabRem:CreateButton({
    Name = "Invoke RemoteFunction",
    Callback = function()
        task.spawn(function()
            local path = State.remotePath or ""
            local obj = resolvePath(path)
            if not obj then notify("Error", "Resolve failed: " .. path, 4) return end
            if not obj:IsA("RemoteFunction") then
                notify("Error", "Not a RemoteFunction (got " .. obj.ClassName .. ")", 4)
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
        end
    end
})

TabRem:CreateSection("Templates")

TabRem:CreateButton({
    Name = "Generate + Copy Remote Templates",
    Callback = function()
        task.spawn(function()
            local t = generateTemplates()
            if setclipboard then setclipboard(t) end
            pcall(writefile, safeGameName .. "_templates.lua", t)
            notify("Templates", "Copied to clipboard + saved", 5)
        end)
    end
})

TabRem:CreateButton({
    Name = "Generate Smart Templates (deep scan)",
    Callback = function()
        task.spawn(function()
            local t = generateSmartTemplates()
            if setclipboard then setclipboard(t) end
            pcall(writefile, safeGameName .. "_smart_templates.lua", t)
            notify("Smart Templates", #State.deepData.remoteCalls .. " observed calls processed", 5)
        end)
    end
})

local function refreshRemoteDropdown()
    task.spawn(function()
        State.remoteList = {}
        local options = {}
        for _, e in ipairs(State.remotes.events) do
            table.insert(State.remoteList, {path = e.path, name = e.name, kind = "event"})
            table.insert(options, "⚡ " .. e.name .. " #" .. tostring(#State.remoteList))
        end
        for _, f in ipairs(State.remotes.functions) do
            table.insert(State.remoteList, {path = f.path, name = f.name, kind = "function"})
            table.insert(options, "⚡ " .. f.name .. " (fn) #" .. tostring(#State.remoteList))
        end
        pcall(function() remoteSelectDropdown:Refresh(options) end)
    end)
end

-- ===== OBJECTS / NPCs =====
local TabObj = Window:CreateTab("Objects", 4483345998)
TabObj:CreateSection("NPCs")

local npcDropdown
npcDropdown = TabObj:CreateDropdown({
    Name = "Select NPC",
    Options = {},
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
                table.insert(options, "◎ " .. n.name .. " (HP " .. tostring(n.hp) .. ") #" .. tostring(i))
            end
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

TabObj:CreateSection("Stats")

TabObj:CreateButton({
    Name = "Show Object Counts (F9 console)",
    Callback = function()
        print("=== OBJECTS ===")
        print("Prompts: " .. #State.objects.prompts)
        print("ClickDetectors: " .. #State.objects.clickDetectors)
        print("NPCs: " .. #State.objects.humanoids)
        print("Values: " .. #State.objects.values)
        print("=== FIRST 30 PROMPTS ===")
        for i, p in ipairs(State.objects.prompts) do
            if i > 30 then break end
            print(p.path)
        end
        notify("Objects", "Details in F9 console", 4)
    end
})

-- ===== VALUES =====
local TabVal = Window:CreateTab("Values", 4483345998)
TabVal:CreateSection("Value Editor")

local valueDropdown
valueDropdown = TabVal:CreateDropdown({
    Name = "Select Value (search below first)",
    Options = {},
    CurrentOption = {},
    Callback = function(opt)
        State.selectedValue = nil
        if opt and opt[1] then
            local idx = tonumber(opt[1]:match("#(%d+)$"))
            if idx and State.filteredValues and State.filteredValues[idx] then
                State.selectedValue = State.filteredValues[idx]
                notify("Value", State.filteredValues[idx].path .. " = " .. tostring(State.filteredValues[idx].val), 5)
            end
        end
    end
})

TabVal:CreateInput({
    Name = "Search values (name or path)",
    PlaceholderText = 'e.g. Speed, Enabled, DoorKey',
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        State._valueQuery = text
    end
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
                    table.insert(options, "[" .. v.class .. "] " .. v.path:sub(-60) .. " = " .. tostring(v.val) .. " #" .. tostring(#State.filteredValues))
                    if #State.filteredValues >= 100 then break end
                end
            end
            pcall(function() valueDropdown:Refresh(options) end)
            notify("Values", tostring(#State.filteredValues) .. " matching", 3)
        end)
    end
})

TabVal:CreateInput({
    Name = "New Value (type depends on class)",
    PlaceholderText = "true / false / 0.5 / text",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        State._newValue = text
    end
})

TabVal:CreateButton({
    Name = "Apply to Selected Value",
    Callback = function()
        local v = State.selectedValue
        if not v then notify("Values", "Select a value first", 3) return end
        local inst = v.ref
        if not inst or not inst.Parent then
            notify("Values", "Instance no longer exists", 4)
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
        if ok then
            notify("Value Set", v.path, 4)
        else
            notify("Error", "Failed to set value", 4)
        end
    end
})

TabVal:CreateSection("Quick Presets (Ear Game specific)")

TabVal:CreateButton({
    Name = "List All Monster SpeedControllers (F9)",
    Callback = function()
        print("=== MONSTER SPEED CONTROLLERS ===")
        for _, v in ipairs(State.objects.values) do
            if v.path:find("SpeedController") then
                print("[" .. v.class .. "] " .. v.path .. " = " .. tostring(v.val))
            end
        end
        notify("Values", "SpeedControllers in F9 console", 4)
    end
})

TabVal:CreateButton({
    Name = "Disable All Monster SpeedControllers",
    Callback = function()
        task.spawn(function()
            local count = 0
            for _, v in ipairs(State.objects.values) do
                if v.path:find("SpeedController") and v.path:find("Enabled") then
                    local inst = v.ref
                    if inst and inst.Parent then
                        pcall(function() inst.Value = false end)
                        count = count + 1
                    end
                end
            end
            notify("Values", "Disabled " .. count .. " SpeedControllers", 5)
        end)
    end
})

TabVal:CreateButton({
    Name = "Re-enable All SpeedControllers",
    Callback = function()
        task.spawn(function()
            local count = 0
            for _, v in ipairs(State.objects.values) do
                if v.path:find("SpeedController") and v.path:find("Enabled") then
                    local inst = v.ref
                    if inst and inst.Parent then
                        pcall(function() inst.Value = true end)
                        count = count + 1
                    end
                end
            end
            notify("Values", "Enabled " .. count .. " SpeedControllers", 5)
        end)
    end
})

-- ===== SECURITY =====
local TabSec = Window:CreateTab("Security", 4483345998)
TabSec:CreateSection("Detections (F9 console for full lists)")

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
            print(d.script .. ":L" .. d.line)
            print("  " .. d.text)
        end
        print("--- Requires (" .. #State.requireMap .. ") ---")
        for i, d in ipairs(State.requireMap) do
            if i > 30 then print("...more") break end
            print(d.script .. " -> " .. d.target)
        end
        notify("Security", "Full report in F9 console", 5)
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

-- ===== DEEP SCAN =====
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

TabDeep:CreateSection("Captured Data (F9 console)")

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
        notify("Deep Scan", "Calls in F9 console", 4)
    end
})

TabDeep:CreateButton({
    Name = "Print Prompt Hits (F9)",
    Callback = function()
        print("=== PROMPT HITS (" .. #State.deepData.promptHits .. ") ===")
        for i, c in ipairs(State.deepData.promptHits) do
            if i > 50 then print("...more") break end
            print("[" .. c.time .. "] " .. c.prompt .. " | " .. c.path)
        end
        notify("Deep Scan", "Prompt hits in F9 console", 4)
    end
})

-- ===== EXPORT =====
local TabExp = Window:CreateTab("Export", 4483345998)
TabExp:CreateSection("Export Options")

local exportLabel = TabExp:CreateLabel("filename: " .. safeGameName .. "_<timestamp>.txt")

TabExp:CreateButton({
    Name = "Export Full Report (TXT)",
    Callback = function()
        task.spawn(function()
            exportTXT()
            pcall(function()
                exportLabel:Set("last: " .. (State.lastExportPath ~= "" and State.lastExportPath or "clipboard only"))
            end)
        end)
    end
})

TabExp:CreateButton({
    Name = "Export Sources as .lua Files",
    Callback = function()
        task.spawn(exportSourcesToFiles)
    end
})

TabExp:CreateButton({
    Name = "Export Remote Templates (.lua)",
    Callback = function()
        task.spawn(function()
            local t = generateTemplates()
            local saved = writeMultiPath(t, safeGameName .. "_templates", ".lua")
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
            local saved = writeMultiPath(t, safeGameName .. "_smart", ".lua")
            if setclipboard then setclipboard(t) end
            notify("Smart Templates", saved or "clipboard only", 5)
        end)
    end
})

TabExp:CreateButton({
    Name = "Copy Full Report to Clipboard",
    Callback = function()
        task.spawn(exportTXT)
    end
})

-- ===== SETTINGS =====
local TabSet = Window:CreateTab("Settings", 4483345998)
TabSet:CreateSection("Scan Config")

TabSet:CreateToggle({
    Name = "Deduplicate Scripts (StarterGui mirrors)",
    CurrentValue = CFG.dedup ~= false,
    Flag = "DedupToggle",
    Callback = function(v)
        CFG.dedup = v
        saveConfig(CFG)
        notify("Setting", v and "Dedup ON" or "Dedup OFF (raw counts)", 3)
    end
})

TabSet:CreateSlider({
    Name = "Max Depth (0 = unlimited) — deprecated, full scan ignores",
    Range = {0, 15},
    Increment = 1,
    Suffix = "lvl",
    CurrentValue = 0,
    Flag = "MaxDepthSlider",
    Callback = function(v) end
})

-- search input tracking: rayfield input callback gives us the text,
-- patch it into state for the script dropdown
-- (declared here so the Scripts tab search callback can reach it)
local _origSearchCallback
-- hook: we re-create tracking via the input's callback above is limited,
-- so we poll getgenv trick is ugly — instead we patch State._searchQuery
-- directly in the input callback. The input above already fires callback
-- with text, but our callback didn't store it. Fix by monitoring:
task.spawn(function()
    -- rayfield stores input values internally; simplest reliable approach:
    -- intercept via the callback we defined. Since we can't retro-patch,
    -- the search input's Callback above calls refreshScriptDropdown which
    -- reads State._searchQuery. We set it here on a polling basis from the
    -- TextBox rayfield creates (find it by placeholder).
    task.wait(2)
    pcall(function()
        local rf = (gethui and gethui() or game:GetService("CoreGui"))
        for _, d in ipairs(rf:GetDescendants()) do
            if d:IsA("TextBox") and d.PlaceholderText and d.PlaceholderText:find("type to filter scripts") then
                d:GetPropertyChangedSignal("Text"):Connect(function()
                    State._searchQuery = d.Text
                end)
                break
            end
        end
    end)
end)

-- restore saved config values into state
if CFG.dedup == nil then CFG.dedup = true end

print("=== PHANTOM SCANNER v11 loaded ===")
print("=== Game: " .. GameName .. " ===")
print("=== Executor: " .. executorInfo .. " ===")

notify("Phantom Ready", GameName .. " | v11 (Rayfield) loaded", 6)
