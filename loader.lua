--!nocheck
-- ==============================================================
--  PHANTOM SCANNER v13 — UNIFIED SINGLE-WALK ENGINE
--  One tree walk captures everything | Time-sliced | Unfreezable
--  Pass A: unified walk (scripts+remotes+objects+values+assets)
--  Pass B: fast source grab (getsrc/bytecode only)
--  Pass C: optional on-demand decompile
-- ==============================================================

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local HttpService          = game:GetService("HttpService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
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
if CFG.scanCoreGui == nil then CFG.scanCoreGui = false end
if CFG.frameBudgetMS == nil then CFG.frameBudgetMS = 8 end
if CFG.valueFilterJunk == nil then CFG.valueFilterJunk = true end
if CFG.maxInstances == nil then CFG.maxInstances = 1000000 end

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
    stats            = {
        total = 0, source = 0, bytecode = 0, needDecomp = 0, failed = 0, deduped = 0,
        instancesWalked = 0, containersFailed = 0
    },
    deepScanning     = false,
    busy             = false,
    cancelScan       = false,
    lastExportPath   = "",
    scanStart        = 0,
    scanDuration     = 0,
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
    remoteArgs       = "",
    decompiling      = false
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
            Name = "Phantom Scanner v13",
            LoadingTitle = GameName,
            LoadingSubtitle = "unified engine | unfreezable",
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

-- ==============================================================
--  UNIFIED WALK ENGINE
--  one pass, everything classified, time-sliced per frame
-- ==============================================================

local junkValueNames = {
    OriginalSize = true,
    OriginalPosition = true,
    AvatarPartScaleType = true
}

-- containers to walk, resolved at scan time
local function getContainers()
    local list = {}
    local function tryAdd(svc, name)
        pcall(function()
            local s = game:GetService(svc)
            if s then list[#list + 1] = {s, name} end
        end)
    end
    tryAdd("Workspace", "Workspace")
    tryAdd("ReplicatedStorage", "ReplicatedStorage")
    tryAdd("ReplicatedFirst", "ReplicatedFirst")
    tryAdd("StarterGui", "StarterGui")
    tryAdd("StarterPack", "StarterPack")
    tryAdd("StarterPlayer", "StarterPlayer")
    tryAdd("Lighting", "Lighting")
    tryAdd("SoundService", "SoundService")
    tryAdd("Teams", "Teams")
    tryAdd("ServerScriptService", "ServerScriptService")
    tryAdd("ServerStorage", "ServerStorage")
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
    if CFG.scanCoreGui then
        pcall(function()
            local cg = gethui and gethui() or game:GetService("CoreGui")
            if cg then list[#list + 1] = {cg, "CoreGui"} end
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

-- THE unified walk. classifies every instance in one traversal.
-- time-budgeted: yields whenever this frame's ms budget is spent.
local function unifiedWalk(progressCb)
    -- reset all collections
    State.results = {}
    State.hashes = {}
    State.remotes = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}}
    State.objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}}
    State.assets = {sounds = {}, animations = {}, decals = {}, meshes = {}}
    State.stats.instancesWalked = 0
    State.stats.containersFailed = 0

    local budget = CFG.frameBudgetMS / 1000
    local frameStart = os.clock()
    local yielded = false

    local function maybeYield(force)
        if force or (os.clock() - frameStart) >= budget then
            if progressCb then
                progressCb(State.stats.instancesWalked)
            end
            RunService.RenderStepped:Wait()
            frameStart = os.clock()
            yielded = true
        end
    end

    for _, cd in ipairs(getContainers()) do
        if State.cancelScan then break end

        -- per-container: pcall'd so one broken container never kills the scan
        local ok, err = pcall(function()
            local stack = {cd[1]}
            while #stack > 0 do
                if State.cancelScan then return end
                if State.stats.instancesWalked >= CFG.maxInstances then
                    notify("Walk", "Instance cap reached (" .. CFG.maxInstances .. ") — results still valid", 5)
                    return
                end

                local node = table.remove(stack)
                local gotKids, children = pcall(node.GetChildren, node)
                if not gotKids then
                    -- instance died or is protected — skip quietly
                    maybeYield(true)
                else
                    for _, inst in ipairs(children) do
                        State.stats.instancesWalked = State.stats.instancesWalked + 1

                        -- class check via ClassName string (cheaper than IsA chain)
                        local cls = inst.ClassName

                        -- scripts
                        if cls == "LocalScript" or cls == "Script" or cls == "ModuleScript" then
                            table.insert(stack, inst)
                            local okPath, path = pcall(inst.GetFullName, inst)
                            if okPath then
                                local hash = quickHash(path .. "|" .. cls)
                                if CFG.dedup and State.hashes[hash] then
                                    State.stats.deduped = State.stats.deduped + 1
                                else
                                    State.hashes[hash] = true
                                    table.insert(State.results, {
                                        path = path,
                                        name = inst.Name,
                                        className = cls,
                                        inst = inst,
                                        source = "",
                                        size = 0,
                                        status = "PENDING"
                                    })
                                end
                            end

                        -- remotes
                        elseif cls == "RemoteEvent" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP then
                                table.insert(State.remotes.events, {path = p, name = inst.Name})
                            end
                        elseif cls == "RemoteFunction" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP then
                                table.insert(State.remotes.functions, {path = p, name = inst.Name})
                            end
                        elseif cls == "BindableEvent" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP then
                                table.insert(State.remotes.bindables, {path = p, name = inst.Name})
                            end
                        elseif cls == "BindableFunction" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP then
                                table.insert(State.remotes.bindableFuncs, {path = p, name = inst.Name})
                            end

                        -- interactables
                        elseif cls == "ProximityPrompt" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP then
                                table.insert(State.objects.prompts, {path = p, name = inst.Name})
                            end
                        elseif cls == "ClickDetector" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP then
                                table.insert(State.objects.clickDetectors, {path = p, name = inst.Name})
                            end
                        elseif cls == "SpawnLocation" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP then
                                local okPos, pos = pcall(function() return tostring(inst.Position) end)
                                table.insert(State.objects.spawns, {path = p, pos = okPos and pos or "?"})
                            end

                        -- values (with junk filter)
                        elseif cls == "IntValue" or cls == "NumberValue" or cls == "StringValue"
                            or cls == "BoolValue" or cls == "ObjectValue" then
                            if not (CFG.valueFilterJunk and junkValueNames[inst.Name]) then
                                local okP, p = pcall(inst.GetFullName, inst)
                                if okP then
                                    local entry = {path = p, class = cls, ref = inst}
                                    pcall(function() entry.val = tostring(inst.Value):sub(1, 80) end)
                                    table.insert(State.objects.values, entry)
                                end
                            end

                        -- assets
                        elseif cls == "Sound" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP then
                                local id = ""
                                pcall(function() id = tostring(inst.SoundId) end)
                                table.insert(State.assets.sounds, {path = p, id = id})
                            end
                        elseif cls == "Animation" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP then
                                local id = ""
                                pcall(function() id = tostring(inst.AnimationId) end)
                                table.insert(State.assets.animations, {path = p, id = id})
                            end
                        elseif cls == "SpecialMesh" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP then
                                local id = ""
                                pcall(function() id = tostring(inst.MeshId) end)
                                table.insert(State.assets.meshes, {path = p, id = id})
                            end
                        end

                        -- models with humanoids = NPCs (check via FindFirstChildOfClass on Model cls only)
                        if cls == "Model" then
                            local hum = inst:FindFirstChildOfClass("Humanoid")
                            if hum and not Players:GetPlayerFromCharacter(inst) then
                                local okP, p = pcall(inst.GetFullName, inst)
                                if okP then
                                    local root = inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart
                                    local px, py, pz
                                    if root then
                                        pcall(function()
                                            px, py, pz = root.Position.X, root.Position.Y, root.Position.Z
                                        end)
                                    end
                                    table.insert(State.objects.humanoids, {
                                        path = p,
                                        name = inst.Name,
                                        hp = hum.Health,
                                        mhp = hum.MaxHealth,
                                        ws = hum.WalkSpeed,
                                        pos = px and string.format("%.1f, %.1f, %.1f", px, py, pz) or "?",
                                        px = px, py = py, pz = pz
                                    })
                                end
                            end
                            table.insert(stack, inst)
                        elseif cls == "MeshPart" or cls == "Decal" then
                            -- decal texture / meshpart meshid
                            if cls == "Decal" then
                                local okP, p = pcall(inst.GetFullName, inst)
                                if okP then
                                    local tex = ""
                                    pcall(function() tex = tostring(inst.Texture) end)
                                    table.insert(State.assets.decals, {path = p, tex = tex})
                                end
                            end
                            table.insert(stack, inst)
                        else
                            table.insert(stack, inst)
                        end

                        maybeYield(false)
                    end
                end
            end
        end)

        if not ok then
            State.stats.containersFailed = State.stats.containersFailed + 1
            warn("[Phantom] container walk failed: " .. tostring(err))
        end
        -- yield between containers regardless
        RunService.RenderStepped:Wait()
    end

    State.stats.total = #State.results
    return yielded
end

-- PASS B: fast source grab (getsrc + bytecode only, never decompile)
local function grabSources(progressCb)
    State.stats.source = 0
    State.stats.bytecode = 0
    State.stats.needDecomp = 0
    State.stats.failed = 0

    local budget = CFG.frameBudgetMS / 1000
    local frameStart = os.clock()

    for i, r in ipairs(State.results) do
        if State.cancelScan then break end
        local s = r.inst
        if s and s.Parent then
            local got = false
            if getsrc then
                local ok, src = pcall(getsrc, s)
                if ok and type(src) == "string" and #src > 0 then
                    r.source = src
                    r.size = #src
                    r.status = "SOURCE"
                    State.stats.source = State.stats.source + 1
                    got = true
                end
            end
            if not got and getscriptbytecode then
                local ok, bc = pcall(getscriptbytecode, s)
                if ok and type(bc) == "string" and #bc > 0 then
                    r.status = "BYTECODE"
                    State.stats.bytecode = State.stats.bytecode + 1
                    got = true
                end
            end
            if not got then
                r.status = "NODECOMP"
                State.stats.needDecomp = State.stats.needDecomp + 1
            end
        else
            r.status = "GONE"
            State.stats.failed = State.stats.failed + 1
        end

        if (os.clock() - frameStart) >= budget then
            if progressCb then progressCb(i, #State.results) end
            RunService.RenderStepped:Wait()
            frameStart = os.clock()
        end
    end
end

-- PASS C: on-demand decompile (single or all remaining)
local function decompileOne(entry)
    if not decompile then
        return nil, "decompile not available"
    end
    local inst = entry.inst
    if not inst or not inst.Parent then
        return nil, "script gone"
    end
    for _ = 1, 2 do
        local ok, r = pcall(decompile, inst)
        if ok and type(r) == "string" and #r > 0 then
            entry.source = r
            entry.size = #r
            entry.status = "SOURCE"
            State.stats.needDecomp = State.stats.needDecomp - 1
            State.stats.source = State.stats.source + 1
            return r, nil
        end
    end
    return nil, "decompile failed (likely server-only or VM-packed)"
end

local function decompileAllRemaining(progressCb)
    if State.decompiling then return end
    local targets = {}
    for _, r in ipairs(State.results) do
        if r.status == "NODECOMP" and r.inst and r.inst.Parent then
            table.insert(targets, r)
        end
    end
    if #targets == 0 then
        notify("Pass C", "Nothing needs decompiling", 3)
        return
    end
    State.decompiling = true
    notify("Pass C", "Decompiling " .. #targets .. " — cancelable", 4)

    local ok, fail = 0, 0
    for i, r in ipairs(targets) do
        if State.cancelScan then break end
        local _, err = decompileOne(r)
        if r.status == "SOURCE" then
            ok = ok + 1
        else
            fail = fail + 1
            r.status = "FAILED"
            State.stats.failed = State.stats.failed + 1
        end
        if progressCb then progressCb(i, #targets, ok, fail) end
        RunService.RenderStepped:Wait()
        RunService.RenderStepped:Wait()
    end
    State.decompiling = false
    notify("Pass C done", "OK: " .. ok .. " | failed: " .. fail, 6)
end

-- security scan (unchanged logic, on captured sources)
local function splitLines(source)
    local lines = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function scanSecurity()
    State.acDetections = {}
    State.bdDetections = {}
    State.webhookHits = {}
    State.requireMap = {}

    local acPatterns = {"anticheat", "anti-cheat", "exploit", "detect", "flag", "tamper", "noclip", "speedhack", "kick", "crash", "rejoin", "ban"}
    local bdPatterns = {"loadstring(game:httpget", "require(", "backdoor", "getfenv(", "setfenv(", "getgenv("}
    local webhookPatterns = {"discord.com/api/webhooks", "discordapp.com/api/webhooks", "webhook"}

    for si, r in ipairs(State.results) do
        if r.source and #r.source > 0 and r.status == "SOURCE" then
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
        if si % 40 == 0 then
            RunService.RenderStepped:Wait()
        end
    end
    notify("Security", string.format("AC: %d | BD: %d | Webhooks: %d",
        #State.acDetections, #State.bdDetections, #State.webhookHits), 5)
end

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
    local buf = {"-- PHANTOM REMOTE TEMPLATES -- " .. GameName, "", ""}
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

-- export
local CHUNK_SIZE = 3000000
local CLIPBOARD_LIMIT = 1500000

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
    local parts = math.ceil(#out / CHUNK_SIZE)
    local savedAny = false
    for i = 1, parts do
        local s = (i - 1) * CHUNK_SIZE + 1
        local e = math.min(i * CHUNK_SIZE, #out)
        local p = writeSingle(out:sub(s, e), baseName .. "_part" .. i, ext)
        if p then savedAny = true end
        RunService.RenderStepped:Wait()
    end
    if savedAny then
        return baseName .. "_part1-" .. parts .. ext, #out
    end
    return nil, #out
end

local function buildReportBuf(includeSources)
    local buf = {}
    local function add(t) table.insert(buf, t) end

    add("==========================================")
    add("  PHANTOM SCANNER v13 EXPORT")
    add("==========================================")
    add("Game: " .. GameName)
    add("Place ID: " .. tostring(game.PlaceId))
    add("Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    add("Executor: " .. executorInfo)
    add("Scan Duration: " .. string.format("%.1fs", State.scanDuration))
    add("Instances Walked: " .. State.stats.instancesWalked)
    add("Containers Failed: " .. State.stats.containersFailed)
    add("")
    add("========== STATS ==========")
    add("Total Scripts: " .. State.stats.total)
    add("Source captured: " .. State.stats.source)
    add("Bytecode proven: " .. State.stats.bytecode)
    add("Needs decompile: " .. State.stats.needDecomp)
    add("Failed/gone: " .. State.stats.failed)
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
            add("Status: " .. r.status .. " | Size: " .. r.size)
            add("")
            if r.source and #r.source > 0 then
                add(r.source)
            else
                add("[NO SOURCE — Pass C decompile or server-only]")
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
            setclipboard(table.concat(buf, "\n"))
        end
        local note = size > CLIPBOARD_LIMIT and " (clipboard skipped)" or " + clipboard"
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
        if r.source and #r.source > 0 and r.status == "SOURCE" then
            local fname = folder .. "/" .. sanitizeFilename(r.name) .. "_" .. i .. ".lua"
            pcall(writefile, fname, "-- " .. r.path .. "\n-- " .. r.className .. "\n\n" .. r.source)
            count = count + 1
            if count % 20 == 0 then
                RunService.RenderStepped:Wait()
            end
        end
    end
    notify("Sources", "Saved " .. count .. " files", 5)
end

-- deep scan
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

-- full pipeline
local function runFullScan(progressCb)
    State.busy = true
    State.cancelScan = false
    State.scanStart = os.clock()

    -- pass A: unified walk
    unifiedWalk(function(walked)
        pcall(function()
            progressCb("walking... " .. walked .. " instances")
        end)
    end)

    -- pass B: sources
    grabSources(function(i, total)
        pcall(function()
            progressCb("sources... " .. i .. " / " .. total)
        end)
    end)

    -- security
    scanSecurity()

    State.scanDuration = os.clock() - State.scanStart
    State.busy = false
    State.cancelScan = false

    notify("Scan Complete",
        string.format("%.1fs | %d instances | %d scripts | src:%d bc:%d need:%d",
            State.scanDuration, State.stats.instancesWalked, State.stats.total,
            State.stats.source, State.stats.bytecode, State.stats.needDecomp), 8)
end

-- ============== TABS ==============

local TabMain = Window:CreateTab("Main", 4483345998)
TabMain:CreateSection("Unified Scanner")

local progressLabel = TabMain:CreateLabel("ready.")

TabMain:CreateButton({
    Name = "SCAN (walk + sources, one pass)",
    Callback = function()
        task.spawn(function()
            runFullScan(function(text)
                pcall(function() progressLabel:Set(text) end)
            end)
            pcall(function()
                progressLabel:Set(string.format(
                    "done %.1fs | %d instances | %d scripts | src:%d bc:%d need:%d | walkfail:%d",
                    State.scanDuration, State.stats.instancesWalked,
                    State.stats.total, State.stats.source,
                    State.stats.bytecode, State.stats.needDecomp,
                    State.stats.containersFailed))
            end)
            if refreshScriptDropdown then refreshScriptDropdown() end
        end)
    end
}, 40)

TabMain:CreateButton({
    Name = "PASS C: Decompile All Remaining",
    Callback = function()
        task.spawn(function()
            decompileAllRemaining(function(done, total, ok, fail)
                pcall(function()
                    progressLabel:Set(string.format("passC... %d / %d | ok:%d fail:%d", done, total, ok, fail))
                end)
            end)
            if refreshScriptDropdown then refreshScriptDropdown() end
        end)
    end
})

TabMain:CreateButton({
    Name = "Cancel",
    Callback = function()
        if State.busy or State.decompiling then
            State.cancelScan = true
            notify("Scan", "Cancelling...", 2)
        end
    end
})

TabMain:CreateButton({
    Name = "Security Scan (on captured sources)",
    Callback = function() task.spawn(scanSecurity) end
})

-- scripts tab
local TabScr = Window:CreateTab("Scripts", 4483345998)
TabScr:CreateSection("Search + Select")

TabScr:CreateInput({
    Name = "Search",
    PlaceholderText = "filter by name or path...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        State._searchQuery = text or ""
        if refreshScriptDropdown then refreshScriptDropdown() end
    end
})

local filterOptions = {"All", "Combat", "Movement", "Economy", "NPC", "Remote",
    "DataStore", "Security", "Client", "Server", "Module", "Other", "NEEDS-DECOMP"}
local filterIndex = 1

local function categorize(path, className)
    local combined = path:lower()
    local catKeywords = {
        Combat = {"combat", "damage", "weapon", "gun", "kill", "sword"},
        Movement = {"walkspeed", "fly", "noclip", "jump", "teleport"},
        Economy = {"shop", "buy", "cash", "coin", "rebirth", "sell"},
        NPC = {"npc", "monster", "enemy", "boss", "mob"},
        Remote = {"remoteevent", "remotefunction", "fireserver"},
        DataStore = {"datastore", "save", "profile"},
        Security = {"anticheat", "detect", "flag"}
    }
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
    Options = {"scan first"},
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
    Name = "Decompile SELECTED (one script)",
    Callback = function()
        local r = State.selectedScript
        if not r then notify("Scripts", "Select first", 3) return end
        task.spawn(function()
            notify("Decompiling", r.name, 3)
            local src, err = decompileOne(r)
            if src then
                notify("Done", r.name .. " (" .. #src .. " bytes)", 4)
            else
                notify("Failed", tostring(err), 4)
            end
        end)
    end
})

TabScr:CreateButton({
    Name = "Copy Selected Source",
    Callback = function()
        local r = State.selectedScript
        if not r then notify("Scripts", "Select first", 3) return end
        local content = (r.source and #r.source > 0) and r.source or ("-- no source -- path: " .. r.path)
        if setclipboard then
            setclipboard(content)
            notify("Copied", r.name, 3)
        end
    end
})

TabScr:CreateButton({
    Name = "Copy Selected Path",
    Callback = function()
        local r = State.selectedScript
        if not r then notify("Scripts", "Select first", 3) return end
        if setclipboard then setclipboard(r.path) notify("Copied", r.path, 3) end
    end
})

TabScr:CreateButton({
    Name = "Copy ALL Sources (capped 1.5MB)",
    Callback = function()
        task.spawn(function()
            local all = {}
            local total = 0
            for _, r in ipairs(State.results) do
                if r.status == "SOURCE" and r.source and #r.source > 0 then
                    total = total + #r.source
                    if total > CLIPBOARD_LIMIT then
                        notify("Copy", "Capped — use file export", 5)
                        break
                    end
                    table.insert(all, "--===== " .. r.path .. " =====")
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
            if r.category == nil then
                r.category = categorize(r.path, r.className)
            end
            local matchesCat
            if selCat == "All" then
                matchesCat = true
            elseif selCat == "NEEDS-DECOMP" then
                matchesCat = (r.status == "NODECOMP")
            else
                matchesCat = (r.category == selCat)
            end
            local matchesQuery = (query == "")
                or r.name:lower():find(query, 1, true)
                or r.path:lower():find(query, 1, true)
            if matchesCat and matchesQuery then
                table.insert(State.filteredScripts, r)
                local tag
                if r.status == "SOURCE" then tag = "OK"
                elseif r.status == "BYTECODE" then tag = "BC"
                elseif r.status == "NODECOMP" then tag = "?"
                else tag = "X" end
                table.insert(options, tag .. " [" .. r.className .. "] " .. r.name .. " #" .. tostring(#State.filteredScripts))
                if #options >= 150 then break end
            end
        end

        if #options == 0 then options = {"no matches"} end
        pcall(function() scriptSelectDropdown:Refresh(options) end)
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
    Name = "Remote Path",
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
    Name = "Check Path",
    Callback = function()
        task.spawn(function()
            local obj = resolvePath(State.remotePath)
            if obj then
                notify("Resolved", obj.ClassName .. " | " .. obj:GetFullName(), 5)
            else
                notify("Failed", "Cannot resolve", 4)
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
            notify("Smart Templates", #State.deepData.remoteCalls .. " calls", 5)
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
            if #options == 0 then options = {"no NPCs"} end
            pcall(function() npcDropdown:Refresh(options) end)
            notify("NPCs", tostring(#State.objects.humanoids) .. " found", 3)
        end)
    end
})

TabObj:CreateButton({
    Name = "Teleport to Selected NPC",
    Callback = function()
        local n = State.selectedNPC
        if not n then notify("Objects", "Select first", 3) return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and n.px then
            hrp.CFrame = CFrame.new(n.px, n.py + 2, n.pz)
            notify("Teleported", "to " .. n.name, 3)
        end
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
    Name = "New Value",
    PlaceholderText = "true / 0.5 / text",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) State._newValue = text or "" end
})

TabVal:CreateButton({
    Name = "Apply to Selected",
    Callback = function()
        local v = State.selectedValue
        if not v then notify("Values", "Select first", 3) return end
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
        notify(ok and "Set" or "Error", v.path, 4)
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

-- export tab
local TabExp = Window:CreateTab("Export", 4483345998)
TabExp:CreateSection("Export")

local exportLabel = TabExp:CreateLabel("filename: " .. safeGameName .. "_<ts>.txt")

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
    Name = "Export Report ONLY (instant)",
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

-- settings tab
local TabSet = Window:CreateTab("Settings", 4483345998)
TabSet:CreateSection("Performance")

TabSet:CreateSlider({
    Name = "Frame Budget (ms per frame, higher = faster + riskier)",
    Range = {2, 16},
    Increment = 1,
    Suffix = "ms",
    CurrentValue = CFG.frameBudgetMS,
    Flag = "FrameBudget",
    Callback = function(v)
        CFG.frameBudgetMS = v
        saveConfig(CFG)
    end
})

TabSet:CreateSlider({
    Name = "Instance Cap (hard stop)",
    Range = {100000, 2000000},
    Increment = 100000,
    Suffix = "inst",
    CurrentValue = CFG.maxInstances,
    Flag = "MaxInstances",
    Callback = function(v)
        CFG.maxInstances = v
        saveConfig(CFG)
    end
})

TabSet:CreateSection("Filters")

TabSet:CreateToggle({
    Name = "Filter Junk Values (attachments etc)",
    CurrentValue = CFG.valueFilterJunk,
    Flag = "JunkFilter",
    Callback = function(v)
        CFG.valueFilterJunk = v
        saveConfig(CFG)
        notify("Setting", v and "Junk filter ON" or "Junk filter OFF", 3)
    end
})

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

TabSet:CreateToggle({
    Name = "Scan CoreGui (noisy)",
    CurrentValue = CFG.scanCoreGui,
    Flag = "CoreGuiToggle",
    Callback = function(v)
        CFG.scanCoreGui = v
        saveConfig(CFG)
        notify("Setting", v and "CoreGui ON" or "CoreGui OFF", 3)
    end
})

-- wire dropdown refresh
local origRunFullScan = runFullScan
runFullScan = function(cb)
    origRunFullScan(cb)
    refreshRemoteDropdown()
end

print("=== PHANTOM SCANNER v13 loaded ===")
print("=== Game: " .. GameName .. " ===")
notify("Phantom v13", "Unified engine — one walk, unfreezable", 6)
