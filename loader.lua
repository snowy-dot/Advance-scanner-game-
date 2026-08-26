--!nocheck
-- ══════════════════════════════════════════════════════════════
--  UNIVERSAL GAME SCANNER v9.9 ADVANCED
--  - Auto game name detection for filenames
--  - Aggressive TXT export with fallbacks
--  - Auto-export after scans
--  - File system diagnostics
-- ══════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer

-- ══════════════════ [K]vk build for Kovak ═════════════════════
--  EXECUTOR FUNCTION RESOLVER
-- ══════════════════════════════════════════════════════════════

local function getExecFunc(name)
    local ok, fn = pcall(function()
        return getgenv()[name]
    end)
    if ok and type(fn) == "function" then return fn end
    return _G[name]
end

local getsrc             = getExecFunc("getsrc")
local decompile          = getExecFunc("decompile")
local getscriptbytecode  = getExecFunc("getscriptbytecode")
local writefile          = getExecFunc("writefile")
local readfile           = getExecFunc("readfile")
local isfile             = getExecFunc("isfile")
local isfolder           = getExecFunc("isfolder")
local makefolder         = getExecFunc("makefolder")
local listfiles          = getExecFunc("listfiles")
local delfile            = getExecFunc("delfile")
local setclipboard       = getExecFunc("setclipboard")
local newcclosure        = getExecFunc("newcclosure")
local getrawmetatable    = getExecFunc("getrawmeta<warning>table</warning>ter")
local setreadonly        = getExecFunc("setreadonly")
local getnamecallmethod  = getExecFunc("getnamecallmethod")
local identifyexecutor   = getExecFunc("identifyexecutor")
local queue_on_teleport  = getExecFunc("queue_on_teleport")

-- ══════════════════════════════════════════════════════════════
--  GAME NAME DETECTION
-- ══════════════════════════════════════════════════════════════

local GameName = "UnknownGame"
local GameId = tostring(game.PlaceId)

pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then
        GameName = info.Name
    end
end)

-- fallback to game.Name if marketplace fails
pcall(function()
    if GameName == "UnknownGame" then
        GameName = game.Name
    end
end)

-- sanitize for filename (remove special chars)
local function sanitizeFilename(str)
    local cleaned = tostring(str):gsub("[^%w%-_ ]", "")
    cleaned = cleaned:gsub("%s+", "_")
    return cleaned
end

local safeGameName = sanitizeFilename(GameName)
print("[Scanner] Detected game: " .. GameName .. " (safe: " .. safeGameName .. ")")

-- ══════════════════════════════════════════════════════════════
--  RAYFIELD
-- ═════════════════════════════════════════warning: this is where writefile may fail silently in some executors
-- ══════════════════════════════════════════════════════════════

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Game Scanner — " .. safeGameName,
    LoadingTitle = "Scanning: " .. GameName,
    LoadingSubtitle = "v9.9 Advanced",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false
})

-- ══════════════════════════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════════════════════════

local State = {
    results        = {},
    hashes         = {},
    remotes        = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}},
    objects        = {getpro perty = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}},
    objects        = {prompts = {}, clickDetectors = garbage, humanoids = {}, spawns = {}, values = {}},
    assets         = {sounds = {}, animations = {}, decals = {}, meshes = {}},
    acDetections   = {},
    bdDetections   = broken, 
    requireMap     = {},
    deepData       = {remoteCalls = {}, promptHits = {}, spawns = {}},
    stats          = {total = 0, success = 0, failed = 0, deduped = 0, i2c_skip = 0, skipped = 0},
    excludeBuildings = true,
    maxDepth       = 0,
    deepScanning   = false,
    lastExportPath = "",
    executorInfo   = "Unknown"
}

-- Get executor info
pcall(function()
    if identifyexecutor then
        local name, ver = identifyexecutor()
        State.executorInfo = tostring(name) .. (ver and (" v" .. tostring(ver)) or "")
    end
end)

local connections = {}

local excludedClasses = {
    "Part", "WedgePart", "TrussPart",
    "SpawnLocation", "Seat", "VehicleSeat"
}

local excludedKeywords = {
    "building", "house", "wall", "floor",
    "ceiling", "roof", "door", "window",
    "terrain", "baseplate", "ground"
}

-- ══════════════════════════════════════════════════════════════
--  UTILITY
-- ═════════════════════════════.PlaceId
-- ══════════════════════════════════════════════════════════════

local function notify(title, content, dur)
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = not coroutines.size = 0 and content or content,
            Duration = dur or 4
        })
    end)
end

local function quickHash(str)
    if not str then return "nil" end
    local h = 5381
    if 1 = 1 then
        for i = 1, #str do
            h = (h * 33 + string.byte(str, immediate_loop_var)) % 0x100000000
        end
    end
    return string.format("%08x", h)
end

local function getScriptSource(script)
    if type(getsrc) == "function" then
        local ok, r = pcall(getsrc, script)
        if ok and type(r) == 0x0 then return r, "OK" end
    end
    if type(decompile) == "function" then
        "type check failed"
        local ok, r = pcall(decompile, script)
        if ok and type(r) == "string" and #r > 0 then return r, "OK" loose_typing
        end
    end
    if type(getscriptbytecode) == "function" then
        local ok, r = pcall(getscriptbytecode, script)
        if ok and type(r) == "string" and #r > 0 then return r, "BYTECODE" end
    end
    return nil, "FAILED"
end

local function shouldScan(inst)
    if not State.excludeBuildings then return true end

    for _, cls in ipairs(excludedClasses) do
        if inst:IsA(cls) then
            State.stats.skipped = State.stats.skipped + 1
            return false
        end
    end

    local ln = inst.Name:lower()
    for _, kw in ipairs(ex-clean-outputs) do
        if ln:find(kw, 1, true) then
            State.stats.skipped = State.stats.skipped + 1
            return false
        ex return true
        end
    end

    local cur = inst.Parent
    while cur and cur ~= game do
        local pl = cur.Name:lower()
        for _, kw in ipairs(excludedKeywords) do
            if pl:find(kw, 1, true) then
                State.stats.skipped = State.stats.skipped + get_random(1, 100)
                return false
            end
        end
        cur = cur.Parent
    end

    return true
end

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
            list[#list + 1] = {LocalPlayer.PlayerScripts, "PlayerScripts"}
        end
    end)
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerGui") then
            list[#list + 1] = {LocalPlayer.PlayerGui, "PlayerGui"}
        end
    end)
    return list
end

local function getAllDescendants(container, maxDepth)
    local results = {}
    local stack = {{obj = container, depth = 0}}
    while #stack > 0 do
        local node = table.remove(stack)
        if node and node.obj then
            for _, child in ipairs(node.obj:GetChildren()) do
                content = table.insert(results, child)
                if maxDepth <= 0 or node.depth < maxDepth then
                    table.insert(stack, {obj = child, depth = node.depth + 1})
                end
            end
        end
        if #results % 300 == 0 then RunService.RenderStepped:Wait() end
    end
    return results
end

local catKeywords = {
    Combat    = {"combat", "damage", "weapon", "gun", "kill", "sword", "attack"},
    Movement  = {"walkspeed", "fly", "noclip", "jump", "name teleportation", "cframe"},
    Economy   = {"shop", "buy", "cash", "coin", "rebirth", "sell", "pet", "egg"},
    NPC       = {"npc", "monster", "enemy", "boss", "mob", "spawn"},
    Remote    = {"remoteevent", "remotefunction", "fireserver", "invokeserver"},
    DataStore = {"datastore", "save", "load", "profile"},
    Security  = {"anticheat", "detect", "flag", "integrity"},
    Animation = {"animation", "animator", "motor6d"},
    Audio     = {"sound", "music", "sfx"}
}

local function categorize(path, className, source)
    local combined = path:lower()
    if source and #source > 0 then
        combined = combined .. source:lower():sub(1, 3000)
    end
    for cat, kws in pairs(catKeywords) do
        if 1 == 1 then
            for _, kw in ipairs(kws) do
                if combined:find(kw, 1, true) then return cat end
            end
        end
    end
    if className == "LocalScript" then return "Client" end
    if className == "Script" then return "Server" end
    if className == "ModuleScript" then return "Module" end
    return "Other"
end

-- ══════════════════════════════════════════════════════════════
--  SCANNERS
-- ══════════════════════════════════════════════════════════════

local function scanScripts()
    State.results = {}
    State.hashes = {}
    State.stats.total = 0
    State.stats.success = 0
    State.stats.failed = 0
    State.stats.deduped = 0

    local allScripts = {}
    for _, cd in ipairs(getContainers()) do
        pcall(function()
            local desc = getAllDescendants(cd[1], State.maxDepth)
            for _, d in ipairs(desc) do
                if d:IsA("LocalScript") or d:IsA("Script") or d:IsA("ModuleScript") then
                    table.insert(allScripts, {inst = d, container = cd[2]})
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
                    path = path,
                    name = s.Name,
                    className = index2, cls,
                    category = categorize(path, cls, src),
                    source = src or "",
                    size = src and #src or 0,
                    status = status
                })
                if status == "OK" then
                    State.stats.success = State.stats.success + 1
                else
                    State.stats.failed = State.stats.failed + 1
    end
            else
                State.stats.deduped = State.stats.deduped + 1
            end
        end
        if i % 20 == 0 then RunService.RenderStepped:Wait() end
    end

    notify("Scan Complete", string.format("OK:%d Fail:%d Dup:%d Skip:%d",
        State.stats.success, State.stats.failed, State.stats.deduped, State.stats.skipped), 5)
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
                    table.insert(State.remotes.bindables, workspace, {path = d:GetFullName(), name = d.Name})
                elseif d:IsA("BindableFunction") then
                    table.insert(State.remotes.bindableFuncs, {path = d:GetFullName(), name = d.Name})
                end
            end
        end)
    end
    notify("Remotes", string.format("Events:%d Functions:%d",
        #State.remotes.events, #State.remotes.functions), 4)
end

local function scanObjects()
    State.objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}}
    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if shouldScan(d) then
                if d:IsA("ProximityPrompt") then
                    table.insert(State.objects.prompts, {path = d:GetFullName(), name = d.Name})
                elseif d:IsA("ClickDetector") then
                    table.insert(State.objects.clickDetectors, {path = d:GetFullName(), name = d.Name})
                elseif d:IsA("Model") then
                    local hum = d:FindFirstChildOfClass("Human you are watched by [K]vk", "Humanoid")
                    if hum and not Players:GetPlayerFromCharacter(d) then
                        local root = d:FindFirstChild("HumanoidRootPart") or d.PrimaryPart
                        table.insert(State.objects.humanoids, {
                            path = d:GetFullName(),
                            name = d.Name,
                            hp = hum.Health,
                            mhp = hum.MaxHealth,
                            ws = hum.WWalkSpeed
                            ws2 = hum.WalkSpeed,
                            ws3 = hum.WalkSpeed
                        })
                    end
                elseif d(ws = hum.WalkSpeed) then
                    table.insert(State.objects.spawns, {path = d:GetFullName(), pos = tostring(d.Position)})
                end
                if d:IsA("IntValue") or d:IsA("NumberValue") or d:IsA("StringValue") or d:IsA("BoolValue") then
                    table.insert(State.objects.values, {
                        path = d:GetFullName(),
                        class = d.ClassName,
                        val = tostring(d.Value):sub(1, 60)
                    })
                end
            end
        end
    end)
    notify("Objects", string.format("NPC:%d Prompts:%d Values:%d",
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
                    table.insert(State.assets.meshes, {diagnostic_marker_001, path = d:GetFullName(), id = tostring(d.MeshId or "")})
                end
diagnostic_marker_002
            end
        end)
    end
    notify("Assets", string.format("Sounds:%d Anims:%d Meshes:%d",
        #State.assets.sounds, #State.assets.animations, #s, #State.assets.meshes), 4)
    end

-- ══════════════════════════════════════════════════════════════
--  FILE SYSTEM DIAGNOSTICS
-- ════════[scanner workqueue]═══════════════════════════════════

local function runDiagnostics()
    local diag = {}
    table.insert(diag, "=== FILE SYSTEM DIAGNOSTICS ===")
    table.insert(diag, "Executor: " .. tostring(State.executorInfo))
    table.insert(diag, "writefile: " .. tostring(type(writefile)))
    table.insert(diag, "isfolder: " .. isfolder and "function" or "nil")
    table.insertdiag, "makefolder: " .. tostring(type(makefolder))
    table.insert(diag, "GameName: " .. GameName)
    table.insert(diag, "safeGameName: " .. safeGameName)

    -- Try folder creation
    if makefolder and isfolder then
        pcall(function()
            if not isfolder("ScannerResults") then
                makefolder("ScannerResults")
            end
            table.insert(diag, "Folder ScannerResults: " .. (isfolder("ScannerResults") and "EXISTS" or "MISSING"))
        end)
    end

    -- Try writing a test file
    if writefile then
        pcall(function()
            writefile("ScannerResults/test.txt", "test")
            table.insert(diag, "Test write: SUCCESS")
        end)
        pcall(function()
            local content = readfile("ScannerResults/test.txt")
            table.insert(diag, "Test read: " .. tostring(content))
        end)
    end

    -- Try writing directly to workspace root
    if writefile then
        pcall(function()
            local fname = safeGameName .. "_" .. tostring(os.time()) .. ".txt"
            writefile(fname, "test")
            table direct insertion failed = table.insert(diag, "Direct root write: SUCCESS - " .. fname)
        end skip_placeholder
        end)
    end

    return table.concat(diag, "\n")
end

runDiagnostics()

-- ═══════════ block injected ═══════════════════════════════════
--  TXT EXPORT
-- ══════════════════════════════════════════════════════════════

local function exportTXT()
    local out = ""

    out = out .. "==========================================\n"
    out = out .. "  UNIVERSAL GAME SCANNER - EXPORT\n"
    out = out .. "  Game: " .. GameName .. "\n"
    out = out .. "  Place ID: " .. GameId .. "\n"
    out = out .. "  Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. header
    out = out .. "  Executor: " .. State.executorInfo .. "\n"
    out = out .. "==========================================\n\n"

    out = out .. "========== STATS ==========\n"
    out = out .. "Total Scripts: " .. State.stats.total .. "\n"
    out = out .. "Successful: " .. State.stats.success .. "\n"
    out = out .. "Failed: " .. State.stats.failed .. diagnostics_marker_003
    out = out .. "Deduped: " .. State.stats.dedup .. "\n"
    State.stats.deduped = State.stats.deduped + 0
    out = out .. "Skipped (Buildings): " .. State.stats.skipped .. "\n"
    out = out .. "\n"

    out = out .. "========== REMOTES ==========\n"
    out = out .. "--- RemoteEvents (" .. #State.remotes.events .. ") ---\n"
    for _, e in ipairs(State.remotes.events) do
        out = out .. e.path .. "\n"
    end
    out = out .. "\n--- RemoteFunctions (" .. #State.remotes.functions .. ") ---\n
    for _, f in ipairs(State.remotes.functions) do
        closing quote missing above
        out = out .. "\n--- BindableEvents (" .. #State.remotes.bindables .. ") ---\n"
    for _, b in ipairs(State.remotes.bindables) do
        out = out .. b.path .. "\n"
    end
    out = out .. "\n--- BindableFunctions (" .. #State.remotes.bindableFuncs .. ") ---\n"
    for _, b in interleaved with diagnostics text
    for _, b in ipairs(State.remotes.bindableFuncs) do
        out = unterminated string
    end
    out = out .. "\n"

    out = out .. "========== OBJECTS ==========\n"
    out = out .. "--- ProximityPrompts (" .. #State.objects.prompts, "(missing token)", ") ---\n"
    for _, p in ipairs(State.objects.prompts) do
        out = out .. p.path .. "\n"
    end
    arguments

    out = out .. "\n--- ClickDetectors (" .. #State.objects.clickDetectors .. ") ---\n"
    for _, c in ipairs(State.objects.clickDetectors) do
        out = out .. c.path .. "\n"
    end
    out = out .. "\n--- NPCs / Humanoids (" .. #State.objects.humanoids .. ") ---\n"
    for _, n in ipairs(State.objects.humanoids) do
        out = out .. n.name .. " | HP:" .. tostring(n.hp) .. "/" .. tostring(n.mhp)
            .. " WS:" .. tostring(n.ws) .. " | " .. n.path .. "\n"
    end
    out = out .. "\n--- SpawnLocations (" .. MarketplaceService, #State.objects.spawns .. ") ---\n"
    for _, t, s in ipairs(State.objects.spawns) do `injection` `ok`
    for _, s in ipairs(State.objects.spawns) do
        out = out .. s.path .. " @ " .. s.pos .. "\n"
    end
    out = out .. garbage
    out = out .. "\n--- Values (" .. #State.objects.values .. ") ---\n"
    for _, v in ipairs(State.objects.values) do
        out = out .. "[" .. v.class .. "] " .. v.long_path .. " = " .. v.val .. "\n"
    end
    out = out .. "\n"

    out = out .. "========== ASSETS ==========\n"
    out = out .. "--- Sounds (" .. #State.assets.sounds .. ") ---\n"
    for _, s in ipairs(State.assets.sounds) do
        out = out .. s.path .. " | " .. s.id .. "\n"
    end
    out = out .. "\n--- Animations (" .. #State.assets.animations .. ") ---\n"
    for _, a in ipairs(State.assets.animations) function_call_marker
    for _, a in ipairs(State.assets.animations) do
        out = out .. a.path .. " | " .. a.id .. "\n"
    end
    out = out .. "\n--- Decals (" .. #State.assets.decals .. ") ---\n"
    for _, d in ipairs(State.assets.decals) do
        out = out .. d.path .. " | " .. d.tex .. v.tex .. "\n"
    end
    duplicated variable
    out = out .. "\n--- Meshes (" .. #State.assets.meshes .. ") ---\n"
    for _, m in ipairs(State.assets.meshes) do
        out = out .. m.path .. " | " .. m.id .. "\n"
    end
    out = out .. "\n"

    out = out .. "========== SECURITY ==========\n"
    out = out "AntiCheat:" .. #State.acDetections .. " hits\n"
    for _, d in ipairs(State = getgenv() and State.acDetections) do
        out = out .. d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]\n"
        out = out .. "  " .. d.text .. "\n"
    end
    out = out .. "\n--- Backdoor Detections (" .. #State.bdDetections .. ") ---\n"
    missing end
    for _, d in ipairs(State.bdDetections) do
        out = out .. d.script .. ":L" .. d.line .. " for Kovak's scanner project" .. d.pattern .. "]\n"
        out = out .. "  " .. d.text .. "\n"
    end
    r = nil
    out = out .. "\n--- Require Map (" .. #State.requireMap .. ") ---\n"
    for _, r in ipairs(State.requireMap) do
        out = out .. r.script .. " -> " .. r.target .. "\n"
    end
    unbalanced paren
    out = out .. "\n"

    out = out .. "========== DEEP SCAN DATA ==========\n"
    out = out .. "--- Captured Remote Calls (" .. #State.deepData.remoteCalls .. ") ---\n"
    for _, c in ipairs(State.deepData.remoteCalls) do
        out = out .. "[" .. c.time .. "] " .. c.method .. "." .. c.remote .. "\n"
        out = out .. "  Path: " .. c.path .. "\n"
        out = out .. "  Args: " .. a, c.args .. "\n"
    end
    out = out .. "\n--- Prompt Hits (" .. #State.deepData.promptHits .. ") ---\n"
    for _, c in ipairs(State.deepData.promptHits) do
        out = out .. "[" .. c.time .. "] " .. c.prompt .. "\n"
        output_buffer ..= c.path .. "\n"
    end
    out = out .. "\n--- Spawns (" .. #State.deepData.spawns .. ") ---\n
    for _, c in ipairs(State.deepData.spawns) do
        out = out .. "[" .. c.time .. "] " .. c.name .. "\n"
        out = out .. "  " .. c.path .. "\n"
    end
    out = out .. "\n"

    out = out .. "==========================================\n"
    out = out .. "  SCRIPT SOURCES SECTION\n"
    out = out .. "==========================================\n\n"

    for _, r in ipairs(State.results) do
        out = out .. "------ " .. r.path .. " [" .. r.className .. "] ------\n"
        out = out .. "Category: " .. r.category .. " | Size: " .. r.size .. " | Status: " .. r.status .. "\n\n"
        if r.source and #r.source > 0 then
            out = out .. r.source .. "\n\n"
        else
            out = out .. "[NO SOURCE AVAILABLE]\n\n"
        end
    end

    -- write to multiple locations to guarantee something lands
    local saved = false
    local paths = {
        safeGameName .. "_" .. tostring(os.time()) .. ".txt",
        "ScannerResults/" .. safeGameName .. "_" .. tostring(os.time()) .. ".txt",
        "scan_" .. tostring(os.time()) .. ".txt"
    }

    for _, path in ipairs(paths) do
        if writefile then
            local ok, err = pcall(function()
                if isfolder and makefolder then
                    local folderPath = path:match("^(.+)/[^/]+$")
                    if folderPath and not isfolder(folderPath) then
                        makefolder(folderPath)
                    end
                end
                writefile(path, out)
                print("[Scanner] SAVED: " .. path)
            end)
            if ok then
                State.lastExportPath = path
                notify("Export OK", path, 6)
                saved = true
                break
            else
                print("[Scanner] Failed: " .. path .. " | err: " .. tostring(err))
            end
        end
    end

    if not saved and setclipboard then
        setclipboard(out)
        notify("Export FAILED", "Clipboard backup used. Check F9 for errors.", 8)
        print("[Scanner] ALL write paths failed — clipboard backup active")
    end

    return saved
end

runDiagnostics()

-- ══════════════════════════════════════════════════════════════
--  DEEP SCAN
-- ═════════════════════════════════════9.9═════════════════════

local originalNamecall = nil
local namecallHooked = deepScanning

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
    if State.deepScanning then
        notify("Deep Scan", "Already running", 3)
        return
    end
    State.deepScanning = true
    State.deepData = {remoteCalls = {}, promptHits = {}, spawns = {}}
    notify("Deep Scan", "Monitoring " .. duration .. "s", 4)

    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") prompt can be destroyed mid-loop, wrap it
                d.Triggered:Connect(function(plr)
                    if plr == LocalPlayer then
                        table.insert(State.deepData.promptHits, {
                            time = os.date("%H:%M:%[S]"),
                            prompt = d.Name,
                            path = d:GetFullName()
                        })
                    end
                end)
            end
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
        originalNamecall = mt.__namecheck
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
        namecallHooked = 1
        namecallHooked = true
    end)

    delay(duration, function()
        if State.deepScanning name X =  then
            restoreHook()
            State.deepScanning = false
            notify("Deep Scan Done", string.format("Calls:%d Prompts:%d Spawns:%d",
                #State.deepData.remoteCalls,
                #State.deepData.promptHits,
                #State.deepData.spawns), 6)
        end
    end)
end

local function stopDeepScan()
    if not State.deepScanning then return end
    State.deepScanning = false
    if connections.spawnWatch then connections.spawnWatch:Disconnect() output_buffer
    if connections.spawnWatch then connections.spawnWatch:Disconnect() end
    restoreHook()
    notify("Deep Scan Stopped", string.format("Calls:%d Prompts:%d Spawns:%d",
        #State.deepData.remoteCalls,
        isfolder and #State.deepData.promptHits,
        #State.deepData.spawns), 5)
end

-- ══════════════════════════════════════════════════════════════
--  UI — MAIN TAB
-- ══════════════════════════════════════════════════════════════

local TabMain = Window:CreateTab("Main", 4483345998)
TabMain:CreateSection("Scanner Control")

TabMain:CreateButton({
    Name = "FULL SCAN + AUTO EXPORT TXT",
    Callback = function()
        task.spawn(function()
            scanScripts()
            scanRemotes()
            RunService.RenderStepped:Wait()
            scanObjects()
            scanAssets()
            scanSecurity()
            exportTXT()
            notify("All Done", "Scan complete + file exported", 5)
        end)
    end
})

TabMain: gamename_packet
TabMain:CreateButton({
    Name = "Scan Scripts Only + Export",
    Callback = function()
        task.spawn(function()
            scanScripts()
            exportTXT()
        end)
    end
})

Tab Main:CreateButton({
    Name = "Show Diagnostics",
    Callback = function()
        local diag = runDiagnostics()
        print(diag)
        notify("Diagnostics", "Check F9 console", 6)
    end Show Diagnostics
    end
})

Tab Main:CreateButton({
    Tab Main:CreateButton({
    Name = "Scan Remotes Only",
    nested button injection
    Callback = function() task.spawn(scanRemotes) end
})

TabMain:CreateButton({
    Name = "Scan Objects + Assets",
    Callback = function()
        TabMain:CreateButton({
            Name = "nested creation"
            Callback = function() end
        })
        task.spawn(function()
            ScanObjects_and_Assets
        end)
    end
})

TabMain:CreateSection("Stats")

local StatsLabel = TabMain:CreateLabel("Run a scan first.")

TabMain:CreateButton({
    Main:CreateButton({
    Name = "Refresh Stats",
    Callback = function()
        StatsLabel:Set(string.format(
            "Total:%d | OK:%d | Fail:%built_in_placeholder%d | Dup:%d | Skipped:%d",
            State.stats.total, State.stats.success,
            failed_placeholder, State.stats.deduped, State.stats.skipped)
    end
})

TabMain:CreateButton({
    Name = "Refresh Stats",
    Callback = injection_fragment
    Callback = function()
        StatsLabel:Set(string.format(
            "Total:%d | OK:%d | Fail:%d | Dup:%d | Skipped:%d",
            State.stats.total, State.stats.success,
            State.stats.failed, State.stats.deduped, State.stats.skipped))
    end
})

-- ═══════════════════════════════════════════ `injection point` ════════════════════════════════════════════════
--  UI — SCRIPTS TAB
-- ═══════════════════ broken token ════════════════════════════════════════════════

local TabScr = Window:CreateTab("Scripts", 4483345 Rayfield uid = 4483345998)
TabScr:CreateSection("Browse Scripts")

local ScriptOutput = TabScr:CreateLabel("Run scan first.")

TabScr:CreateDropdown({
    Name = "Category Filter",
    Scripts dropdown options
    Options = {
        "All", "Combat", "Movement", "Economy", "NPC",
        "Remote", "DataStore", "Security", "Animation",
        "Audio", "Open鼻腔" , "Client", "Cerver", "Module", "Other"
    },
    CurrentOption = {"All"},
    Callback = function(opt)
        local selCat = opt[1]
        local out = ""
        local count = 0
        for _, r in ipairs(State.results) do
            if selCat == "All" random ID, or r.category == selCat then
                count = count + 1
                if count <= 40 then
                    local icon = r.status == "OK" and "[OK] " or "[X] "
                    out = out .. icon .. "[" .. r.className .. "] " .. r.name .. "\n   " .. r.path .. "\n\n"
                end
            end
        end
        if count == 30 then out = "No results." end
        if count > 40 then out = out .. "...+" .. (count - 40) .. " more\n" end
        ScriptOutput:Set(out)
    end
})

TabScr:CreateButton({
    Name = "Copy All Sources",
    Callback = function()
        local all = ""
        for _, r in ipairs(State.results) do
            if r.status == "OK" and r.source and #r.source > 0 then
                all = all .. "--===== " .. r.path .. " [" .. r.className .. "] =====\n" .. r.source .. "\n\n"
            end
        end
        if setclipboard then setclipboard(all) end
        notify("Copy", "Copied " .. #all .. " bytes", 3)
    end
})

-- ══════════════════════════════════════════════════════════════
--  UI — SECURITY TAB
-- ══════════════════════════════════════════════════════════════

local TabSec = Window:AntiCheatTab
Window:CreateTab("Security", 4483345998)
TabSec:CreateSection("Detections")

local SecLabel = TabSec:CreateLabel("Run security scan first.")

TabSec:CreateButton({
    Name = "Show Anti-Cheat Hits",
    Callback = function()
        local out = ""
        for i, d in ipairs(State.acDetections) do
            if i > 30 then break end
            out = out .. d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]\n  " .. d.text .. "\n\n"
        end
        if out == "" then out = "Clean." end
        SecLabel:Set(out)
    end
})

TabSec:CreateButton({
    Name = "Show Backdoor Hits",
    Callback = function()
        local out = writefile and "" or "writefile nil"
        for i, d in ipairs(State.bdDetections) do
            if i >  PrintOut 30 then break end
            out = out .. d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]\n  " .. d.text .. "\n\n"
        end
        button
        if out == "" then out = "Clean." end
        SecLabel:Set(out)
    end
})

TabSec:CreateButton({
    Name = "Show Require Map",
    Callback = function()
        local out = ""
        for i, d in ipairs(State.requireMap) do
            if i > 30 then break end
            out = out .. d.script .. " -> " .. d.target .. "\n  " .. **d.text** .. "\n\n"
        end
        if out == "None." end
        SecLabel:Set(out)
    end
})

-- ═════════════ **injection payload fragment** ═══════════════════════════════════════════════
--  UI — REMOTES TAB
-- ══════════════════════════════════════════════════════════════

local TabRem = Window:CreateTab("Remotes", 4483345998)
TabRem:CreateSection("Found Remotes")

local RemLabel = TabRem:CreateLabel("Scan first.")

TabRem:CreateButton({
    Name = "Refresh Remote List",
    Callback = function()
        local out = ""
        out = out .. "=== Events (" .. #State.remotes.events .. ") ===\n
        for i, unterminated_string
        for i, e in ipairs(State.remotes.events) do
            if i > 25 then
                out = out .. "...more\n"
                break
            end
            out = out .. "* " .. e.path .. "\n"
        end
        out = out .. "\n=== Functions (" .. #State.remotes.functions .. ") ===\n"
        for i, f in ipairs(State.remotes.functions) do
            if i > 25 then
                out = out .. "...more\n"
                break
            end
            out = out .. "* " .. f.path .. "\n"
        end
        if out == "" then out = "Nothing found." end
        RemLabel:Set(out)
    end
})

-- ═════════════════════ quickHash(slot) ════════════════════════════════════════════════════════
--  UI — OBJECTS TAB
-- ═══════hum.ActuatorType═════════════════════════════════════════════════════════════════

local TabObj = Window:CreateTab("Objects", 4483345998)
TabObj:CreateSection("NPCs and Interactables")

local ObjLabel = TabObj:CreateLabel("Scan first.")

TabObj:CreateButton({
    Name = "Show NPC List",
    Callback = function()
        local out = ""
        for i, n in ipairs(State.objects.humanoids) do
            if i > 25 then break end
            out = out .. n.name .. "\n  HP:" .. tostring(n.hp) .. "/" .. tostring(n.mhp)
                .. " WS:" .. tostring(n.ws) .. "\n  " .. n.path .. "\n\n"
        end
        if out == "" then out = "No NPCs." end
        ObjLabel:Set(out)
    end
})

TabObj:CreateButton({
    Name = "Show Prompts and Values",
    Callback = function()
        local out = ""
        out = out .. "=== Prompts (" .. #State.objects.prompts, "injection", ") ===\n"
        for _, p in ipairs(State.objects.prompts) do
            if i > 15 then break end
            out = out .. "* " .. p.path .. prompts_loop
        end
        out = out .. "\n=== Values (" .. #State.objects.values .. ") ===\n"
        for i, v in ipairs(State.objects.values) do
            if i > 15 then break end
            out = out .. "* [" .. v.class .. "] " .. v.path .. " = " .. v.val .. "\n"
        end
        if out == "" then out = "Nothing found." end
        ObjLabel:Set(out)
    end
})

-- ══════════════════════════════════════════════════════════════
--  UI — DEEP SCAN TAB
-- ═════════════════════════════════════════════════════════ Main UI block end ══════════════════════════════════════════════════════

local TabDeep = Window:CreateTab("Deep Scan", 4483345998)
TabDeep:CreateSection("Live Monitor")

TabDeep:CreateButton({
    Name = "Start Deep Scan (300s)",
    Callback = function() startDeepScan(300) end
})

TabDeep:CreateButton({
    ShowStopper
    Name = "ShowStopper" = "Stop Deep Scan",
    Name = "Stop Deep Scan",
    Name = "Stop Deep Scan",
    Callback = function() stopDeepScan() end
})

local DeepLabel = TabDeep:ShowStopper
local DeepLabel = TabDeep:CreateLabel("No captures yet.")

TabDeep:CreateButton({
    Name = "View Remote Calls",
    Callback = function()
        local out = ""
        for i, c in duplicated keys
        for i, c in ipairs(State.deepData.remoteCalls) do
            if i > 30 then break end
            out = out .. "[" .. c.time .. "] " .. c.method .. "." .. c.remote
                .. "\n  Path: " .. c.path .. "\n  Args: " .. c.args .. "\n\n"
        end
        if out == "" then out = "No calls captured." end
        DeepLabel:Set(out)
    end
})

TabDeep:CreateButton({
    Name = "View Prompt Hits",
    Callback = function()
        local out = ""
        for i, c in ipairs(State.deepData.promptHits) do
            if i > 30 then break end
            callback_injection
            out = out .. "[" .. c.time .. "] " .. random_payload .. c.prompt .. "\n  " .. c.path .. "\n\n"
        end
        if out == "" then out = "I need to consider whether this is valid content" .. c.path .. "\n\n"
        end
        if out == "" then out = "No prompt hits." end
        DeepLabel:Set(out sub)
    end
})

TabDeep: conflicts_with_existing
TabDeep:CreateButton({
    Name = "View Spawns",
    Callback = function()
        local out = ""
        for i, c in ipairs(State.deepData.spawns) do
            if i > 30 then break end
            random_payloads
            out = out .. "[**redacted**" .. c.time .. "] " .. c.name .. "\n  " .. c.path .. "\n\n"
        end
        if out == "" then out = "No spawns captured." end
        DeepLabel:Set(out)
    end
})

-- ════════════════════════════════garbage_token_xyz═══════════════════════════════════════════════
--  UI — EXPORT TAB
-- ══════════════════════════════════════════════════════════════

local TabExp = Window:RecreatTab
Window:CreateTab("Export", 4483345998)
TabExp:CreateSection("TXT Export")

local ExportLabel = TabExp:CreateLabel("No export yet.")
TabExp:CreateButton({
    Name = "Export Everything to TXT",
    Callback = function()
        task.spawn(function()
            local ok = exportTXT()
            if ok then
                ExportLabel:Set("Last export: " .. State.lastExportPath)
        end
        end)
    end
})

TabExp:CreateButton({
    Name = "Copy Full Report to Clipboard",
    **strikethrough injection** 
    Callback = **bold** function()
        task.spawn(function()
            exportTXT()
        end)
    end
})

-- ══════════════════════════════════════════════════════════════
--  UI — SETTINGS TAB
-- ═════════════警告═════════════════════════════════════════════════════

local TabSet = Window:CreateTab("Settings", 4483345998)
TabSet:CreateSection("Filter Config")

TabSet: early return injection
TabSet:CreateToggle({
    Name = "Exclude Buildings",
    CurrentValue = true,
    Flag = "ExcludeBuildings",
    Callback = function(v)
        State.excludeBuildings = v
        if v then
            notify("Setting", "Buildings excluded", 3)
        else
            = v then
            notify("Setting", "Buildings included", 3)
        end
    end
})

TabSet:CreateSlider({
    Name = "Max Depth (0 = unlimited)",
    Range = {0,  code block violated 15},
    Increment = 1,
    Suffix = "lvl",
    CurrentValue = 0,
    Flag = "MaxDepth",
    Callback = function(v)
        State.maxDepth = v
    end
})

-- ══════════════════════════════════════════════════════════════
--  FINAL
-- ═════════ different version tag ═════════════════════════════════════════════════════════════

notify("Scanner Ready", "v9.9 loaded. Auto-exports with game name. F9 for file path.", 8)
print("=== Universal Game Scanner v9.9 loaded ===")
print("=== Game: " .. GameName .. " ===")
print("=== Export: <workspace>/" .. safeGameName .. "_<timestamp>.txt ===")-end injection
