--!nocheck
-- ==============================================================
--  PHANTOM SCANNER v15 — MULTIVERSE EDITION
--  Works on any game. Knows what kind of game it's in.
--  Remembers every game it has ever scanned.
--
--  NEW IN v15:
--    - GENRE ENGINE: auto-detects game type + tailored exploit advice
--    - PROFILE MEMORY: per-PlaceId history, revisit greetings
--    - All v14 intel: fingerprint, traffic+returns, coverage, map
--    - All v13 engine guarantees: unfreezable, unified walk
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

local function sanitizeFilename(str)
    return tostring(str):gsub("[^%w%-_]", "_"):sub(1, 60)
end
local safeGameName = sanitizeFilename(GameName)
local PlaceId = game.PlaceId

local executorInfo = "Unknown"
pcall(function()
    local n, v = identifyexecutor()
    executorInfo = tostring(n) .. (v and (" v" .. tostring(v)) or "")
end)

print("[Phantom v15] Game: " .. GameName)
print("[Phantom v15] Place: " .. tostring(PlaceId))

-- ==============================================================
--  CONFIG + PROFILE MEMORY
-- ==============================================================

local CONFIG_FILE = "PhantomScanner/config.json"
local PROFILES_FILE = "PhantomScanner/profiles.json"

local function ensureFolder()
    if isfolder and makefolder and not isfolder("PhantomScanner") then
        pcall(makefolder, "PhantomScanner")
    end
end

local function saveJson(path, data)
    if writefile then
        pcall(function()
            ensureFolder()
            writefile(path, HttpService:JSONEncode(data))
        end)
    end
end

local function loadJson(path)
    if readfile and isfile and isfile(path) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if ok and type(data) == "table" then return data end
    end
    return nil
end

local CFG = loadJson(CONFIG_FILE) or {}
if CFG.dedup == nil then CFG.dedup = true end
if CFG.scanCoreGui == nil then CFG.scanCoreGui = false end
if CFG.frameBudgetMS == nil then CFG.frameBudgetMS = 8 end
if CFG.maxInstances == nil then CFG.maxInstances = 1000000 end
if CFG.captureReturns == nil then CFG.captureReturns = true end
if CFG.skipCharacters == nil then CFG.skipCharacters = true end

-- profiles: history of every game ever scanned
local PROFILES = loadJson(PROFILES_FILE) or {}
local thisProfile = PROFILES[tostring(PlaceId)]

local function saveProfile(summary)
    PROFILES[tostring(PlaceId)] = summary
    saveJson(PROFILES_FILE, PROFILES)
end

local function persistConfig()
    saveJson(CONFIG_FILE, CFG)
end

-- ==============================================================
--  STATE
-- ==============================================================

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
    deepData         = {remoteCalls = {}, promptHits = {}, spawns = {}, returns = {}},
    stats            = {
        total = 0, source = 0, bytecode = 0, needDecomp = 0, failed = 0, deduped = 0,
        instancesWalked = 0, containersFailed = 0
    },
    fingerprint      = nil,
    genre            = nil,
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
            Name = "Phantom Scanner v15 MULTIVERSE",
            LoadingTitle = GameName,
            LoadingSubtitle = "universal recon | genre-aware",
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

-- revisit greeting from profile memory
task.spawn(function()
    task.wait(1.5)
    if thisProfile then
        notify("Welcome Back",
            "last scan: " .. tostring(thisProfile.date) ..
            " | " .. tostring(thisProfile.tier) ..
            " | " .. tostring(thisProfile.genre), 8)
        print("[Phantom] PROFILE MEMORY — scanned before:")
        print("  date: " .. tostring(thisProfile.date))
        print("  tier: " .. tostring(thisProfile.tier))
        print("  genre: " .. tostring(thisProfile.genre))
        print("  scripts: " .. tostring(thisProfile.scripts))
        print("  instances: " .. tostring(thisProfile.instances))
    else
        print("[Phantom] first visit to this game — profile will be saved")
    end
end)

-- ==============================================================
--  UNIFIED WALK ENGINE
-- ==============================================================

local junkValueNames = {
    OriginalSize = true,
    OriginalPosition = true,
    AvatarPartScaleType = true
}

local function getContainers()
    local list = {}
    local function tryAdd(svc)
        pcall(function()
            local s = game:GetService(svc)
            if s then list[#list + 1] = s end
        end)
    end
    tryAdd("Workspace")
    tryAdd("ReplicatedStorage")
    tryAdd("ReplicatedFirst")
    tryAdd("StarterGui")
    tryAdd("StarterPack")
    tryAdd("StarterPlayer")
    tryAdd("Lighting")
    tryAdd("SoundService")
    tryAdd("Teams")
    tryAdd("ServerScriptService")
    tryAdd("ServerStorage")
    tryAdd("Players")
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerScripts") then
            list[#list + 1] = LocalPlayer.PlayerScripts
        end
    end)
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerGui") then
            list[#list + 1] = LocalPlayer.PlayerGui
        end
    end)
    if CFG.scanCoreGui then
        pcall(function()
            local cg = gethui and gethui() or game:GetService("CoreGui")
            if cg then list[#list + 1] = cg end
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

local function unifiedWalk(progressCb)
    State.results = {}
    State.hashes = {}
    State.remotes = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}}
    State.objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}}
    State.assets = {sounds = {}, animations = {}, decals = {}, meshes = {}}
    State.stats.instancesWalked = 0
    State.stats.containersFailed = 0

    local remoteHashes = {}
    local valueHashes = {}
    local objHashes = {}

    local budget = CFG.frameBudgetMS / 1000
    local frameStart = os.clock()

    local function maybeYield(force)
        if force or (os.clock() - frameStart) >= budget then
            if progressCb then progressCb(State.stats.instancesWalked) end
            RunService.RenderStepped:Wait()
            frameStart = os.clock()
        end
    end

    for _, container in ipairs(getContainers()) do
        if State.cancelScan then break end
        local ok, err = pcall(function()
            local stack = {container}
            while #stack > 0 do
                if State.cancelScan then return end
                if State.stats.instancesWalked >= CFG.maxInstances then
                    notify("Walk", "Instance cap reached — results valid", 5)
                    return
                end

                local node = table.remove(stack)
                local gotKids, children = pcall(node.GetChildren, node)
                if not gotKids then
                    maybeYield(true)
                else
                    for _, inst in ipairs(children) do
                        State.stats.instancesWalked = State.stats.instancesWalked + 1
                        local cls = inst.ClassName

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

                        elseif cls == "RemoteEvent" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not remoteHashes[p] then
                                remoteHashes[p] = true
                                table.insert(State.remotes.events, {path = p, name = inst.Name})
                            end
                        elseif cls == "RemoteFunction" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not remoteHashes[p] then
                                remoteHashes[p] = true
                                table.insert(State.remotes.functions, {path = p, name = inst.Name})
                            end
                        elseif cls == "BindableEvent" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not remoteHashes[p] then
                                remoteHashes[p] = true
                                table.insert(State.remotes.bindables, {path = p, name = inst.Name})
                            end
                        elseif cls == "BindableFunction" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not remoteHashes[p] then
                                remoteHashes[p] = true
                                table.insert(State.remotes.bindableFuncs, {path = p, name = inst.Name})
                            end

                        elseif cls == "ProximityPrompt" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not objHashes[p] then
                                objHashes[p] = true
                                table.insert(State.objects.prompts, {path = p, name = inst.Name})
                            end
                        elseif cls == "ClickDetector" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not objHashes[p] then
                                objHashes[p] = true
                                table.insert(State.objects.clickDetectors, {path = p, name = inst.Name})
                            end
                        elseif cls == "SpawnLocation" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not objHashes[p] then
                                objHashes[p] = true
                                local okPos, pos = pcall(function() return tostring(inst.Position) end)
                                table.insert(State.objects.spawns, {path = p, pos = okPos and pos or "?"})
                            end

                        elseif cls == "IntValue" or cls == "NumberValue" or cls == "StringValue"
                            or cls == "BoolValue" or cls == "ObjectValue" then
                            if not junkValueNames[inst.Name] then
                                local okP, p = pcall(inst.GetFullName, inst)
                                if okP and not valueHashes[p] then
                                    valueHashes[p] = true
                                    local entry = {path = p, class = cls, ref = inst}
                                    pcall(function() entry.val = tostring(inst.Value):sub(1, 80) end)
                                    table.insert(State.objects.values, entry)
                                end
                            end

                        elseif cls == "Sound" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not objHashes[p] then
                                objHashes[p] = true
                                local id = ""
                                pcall(function() id = tostring(inst.SoundId) end)
                                table.insert(State.assets.sounds, {path = p, id = id})
                            end
                        elseif cls == "Animation" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not objHashes[p] then
                                objHashes[p] = true
                                local id = ""
                                pcall(function() id = tostring(inst.AnimationId) end)
                                table.insert(State.assets.animations, {path = p, id = id})
                            end

                        elseif cls == "Model" then
                            local isChar = CFG.skipCharacters and Players:GetPlayerFromCharacter(inst)
                            if not isChar then
                                local hum = inst:FindFirstChildOfClass("Humanoid")
                                if hum then
                                    local okP, p = pcall(inst.GetFullName, inst)
                                    if okP and not objHashes[p] then
                                        objHashes[p] = true
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
        RunService.RenderStepped:Wait()
    end

    State.stats.total = #State.results
end

-- ==============================================================
--  CODE COVERAGE
-- ==============================================================

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
    return nil, "failed (server-only or VM-packed)"
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

-- ==============================================================
--  SECURITY SCAN
-- ==============================================================

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
end

-- ==============================================================
--  GENRE ENGINE — what kind of game is this?
-- ==============================================================

local function detectGenre()
    local g = {
        name = "unknown",
        confidence = 0,
        matched = {},
        advice = {}
    }

    -- build searchable corpus from paths + remotes + values
    local corpus = ""
    for _, e in ipairs(State.remotes.events) do
        corpus = corpus .. e.path:lower() .. " "
    end
    for _, f in ipairs(State.remotes.functions) do
        corpus = corpus .. f.path:lower() .. " "
    end
    for _, v in ipairs(State.objects.values) do
        corpus = corpus .. v.path:lower() .. " "
    end
    for _, n in ipairs(State.objects.humanoids) do
        corpus = corpus .. n.name:lower() .. " "
    end

    local function countAll(keywords)
        local total = 0
        for _, kw in ipairs(keywords) do
            local _, c = corpus:gsub(kw, "")
            total = total + c
        end
        return total
    end

    -- genre profiles: signature keyword sets
    local genres = {
        {
            name = "Tycoon / Simulator",
            sig = countAll({"tycoon", "dropper", "collector", "rebirth", "prestige", "autofarm", "upgrade", "factory", "cash", "income", "plot"}),
            advice = {
                "currency/income remotes are the target — find the 'collect' or 'claim' pattern in traffic",
                "rebirth/upgrade remotes often have thin validation in sims",
                "auto-farm = loop the collect remote with observed cooldown"
            }
        },
        {
            name = "Tower / Obby",
            sig = countAll({"obby", "stage", "checkpoint", "tower", "parkour", "killbrick", "jumps", "floor"}),
            advice = {
                "checkpoint remotes = the whole exploit surface — skip-to-stage is the classic",
                "killbricks are client-editable visually — walk through them locally",
                "leaderstage values replicated = check Values tab for stage number"
            }
        },
        {
            name = "Horror / Survival",
            sig = countAll({"monster", "jumpscare", "night", "survive", "hide", "escape", "spawnmonster", "chase", "scary", "demon"}),
            advice = {
                "monster AI often server-side but monster PATHS/values may replicate — check values",
                "ESP on monsters is the main weapon — highlights through walls",
                "door/escape remotes usually validate items (keycards) — deep scan the unlock sequence"
            }
        },
        {
            name = "Shooter / Fighting",
            sig = countAll({"gun", "shoot", "damage", "bullet", "weapon", "reload", "ammo", "health", "kill", "hit", "sword", "attack", "combat"}),
            advice = {
                "hit/damage remotes are ALWAYS validated in shooters — never forge",
                "weapon data (fire rate, spread) often client-side = visual mods work",
                "ESP + aimbot-adjacent features (name tags) are the safe surface"
            }
        },
        {
            name = "Roleplay / Social",
            sig = countAll({"house", "furniture", "job", "work", "roleplay", "adopt", "family", "money", "buy", "shop", "vehicle", "car"}),
            advice = {
                "job/work remotes replicate real actions — TP farming through the actual loop is safest",
                "vehicle remotes (spawn/teleport) often accept simple args — test on alt",
                "furniture/building placement remotes usually validate ownership"
            }
        },
        {
            name = "Racing / Vehicle",
            sig = countAll({"car", "vehicle", "race", "speed", "drive", "engine", "wheel", "crush", "drift", "chassis", "seat"}),
            advice = {
                "vehicle physics often client-predicted = speed/handling mods work visually",
                "race checkpoint remotes can be distance-validated — check traffic gaps",
                "vehicle stats replicated as values = database browsing is free intel"
            }
        },
        {
            name = "Clicker / Incremental",
            sig = countAll({"click", "tap", "mult", "multiplier", "pet", "egg", "hatch", "clicks", "cps", "energy"}),
            advice = {
                "click remotes are the core loop — capture natural click rate in deep scan, match it",
                "pet hatch remotes usually validate currency server-side",
                "multiplier values client-visible = check for writable boosts"
            }
        },
        {
            name = "Social Hangout",
            sig = countAll({"emote", "music", "boombox", "radio", "avatar", "vip", "social", "chat", "dance"}),
            advice = {
                "mostly client-visual surface — emotes, music, avatar mods",
                "few exploit targets; this genre is about cosmetic freedom",
                "boombox/music remotes sometimes accept any id — test on alt"
            }
        }
    }

    -- pick best match
    local best, bestScore = nil, 0
    for _, genre in ipairs(genres) do
        if genre.sig > bestScore then
            best = genre
            bestScore = genre.sig
        end
    end

    if best and bestScore >= 3 then
        g.name = best.name
        g.confidence = math.min(95, 40 + bestScore * 2)
        g.matched = {"signal strength: " .. bestScore .. " keyword hits"}
        g.advice = best.advice
    else
        g.name = "Unclassified / Hybrid"
        g.confidence = 30
        g.advice = {
            "no strong genre signature — rely on the tier fingerprint instead",
            "run deep scan during normal play to discover the game's own loop"
        }
    end

    State.genre = g
    return g
end

-- ==============================================================
--  FINGERPRINT ENGINE (with Pizza Place lesson baked in)
-- ==============================================================

local function analyzeFingerprint()
    local fp = {
        tier = "?",
        tierName = "unknown",
        confidence = 0,
        signals = {},
        risks = {},
        recommendations = {},
        clientAuthSignals = 0,
        serverAuthSignals = 0,
        obfuscationScore = 0
    }

    -- game-state value count (needed by the contradiction check)
    local statePatterns = {"cash", "coin", "money", "gem", "token", "point", "score", "level", "xp", "health", "ammo", "inventory", "gold", "credit"}
    local stateCount = 0
    for _, v in ipairs(State.objects.values) do
        local low = v.path:lower()
        for _, sp in ipairs(statePatterns) do
            if low:find(sp, 1, true) then
                stateCount = stateCount + 1
                break
            end
        end
    end
    fp.stateCount = stateCount

    -- validation bindables
    local validationNames = {"dataverification", "validate", "anticheat", "securitycheck", "verifyaction", "integritycheck"}
    local foundValidation = false
    for _, b in ipairs(State.remotes.bindables) do
        local low = b.path:lower()
        for _, vn in ipairs(validationNames) do
            if low:find(vn, 1, true) then
                foundValidation = true
                table.insert(fp.signals, "validation bindable: " .. b.path)
                break
            end
        end
    end
    if foundValidation then
        fp.serverAuthSignals = fp.serverAuthSignals + 3
        table.insert(fp.risks, "SERVER-SIDE ACTION VALIDATION DETECTED — economy remotes are fingerprinted")
    end

    -- remote naming entropy
    local totalLen, totalRemotes, shortNames = 0, 0, 0
    for _, e in ipairs(State.remotes.events) do
        totalLen = totalLen + #e.name
        totalRemotes = totalRemotes + 1
        if #e.name <= 3 then shortNames = shortNames + 1 end
    end
    if totalRemotes > 0 then
        local avgLen = totalLen / totalRemotes
        if avgLen < 4 or (shortNames / totalRemotes) > 0.3 then
            fp.obfuscationScore = fp.obfuscationScore + 2
            table.insert(fp.signals, string.format("obfuscated remote naming (avg %.1f chars)", avgLen))
            table.insert(fp.risks, "PROFESSIONAL CODEBASE — assume all remotes validated")
        else
            table.insert(fp.signals, string.format("descriptive remote naming (avg %.1f chars)", avgLen))
            fp.clientAuthSignals = fp.clientAuthSignals + 1
        end
    end

    -- source visibility WITH the legacy-server-auth contradiction check
    local total = State.stats.source + State.stats.bytecode + State.stats.needDecomp + State.stats.failed
    local srcRatio = total > 0 and (State.stats.source / total) or 0
    if srcRatio > 0.7 then
        fp.clientAuthSignals = fp.clientAuthSignals + 2
        table.insert(fp.signals, string.format("high source visibility (%.0f%% readable)", srcRatio * 100))
    elseif srcRatio < 0.3 and total > 0 then
        fp.serverAuthSignals = fp.serverAuthSignals + 3
        table.insert(fp.signals, string.format("low source visibility (%.0f%% readable)", srcRatio * 100))

        -- the Pizza Place lesson: display-only state values in low-vis games
        if stateCount > 20 then
            table.insert(fp.risks, "game-state values are DISPLAY-ONLY (server ledger) — client edits won't persist")
            fp.clientAuthSignals = fp.clientAuthSignals - 2
        end
    end

    -- game-state values (in high-visibility games only = real surface)
    if stateCount > 20 and srcRatio >= 0.3 then
        fp.clientAuthSignals = fp.clientAuthSignals + 2
        table.insert(fp.signals, stateCount .. " game-state values client-visible — likely writable")
        table.insert(fp.recommendations, "check Values tab for currency/inventory — try editing")
    end

    -- webhooks
    if #State.webhookHits > 0 then
        table.insert(fp.risks, "GAME LOGS TO DISCORD WEBHOOKS — actions may be reported live")
        fp.serverAuthSignals = fp.serverAuthSignals + 1
    end

    -- anti-cheat density
    if #State.acDetections > 10 then
        fp.serverAuthSignals = fp.serverAuthSignals + 1
        table.insert(fp.signals, #State.acDetections .. " anti-cheat lines in source")
    end

    -- classify
    local score = fp.serverAuthSignals - fp.clientAuthSignals
    if score >= 4 then
        fp.tier = "TIER 3"
        fp.tierName = "server-auth + hardened"
        fp.confidence = 85
        table.insert(fp.recommendations, "SAFE: TPs, ESP, fullbright, replicated-data browsers")
        table.insert(fp.recommendations, "AVOID: economy/damage remotes — validation + ban teams")
        table.insert(fp.recommendations, "USE: deep scan for protocol recon only")
    elseif score >= 1 then
        fp.tier = "TIER 2"
        fp.tierName = "hybrid validation"
        fp.confidence = 70
        table.insert(fp.recommendations, "SAFE: movement, ESP, TPs, prompt automation")
        table.insert(fp.recommendations, "TEST-ON-ALT: any remote that spends/moves/creates")
        table.insert(fp.recommendations, "USE: deep scan → replicate exact observed args")
    else
        fp.tier = "TIER 1"
        fp.tierName = "client-authoritative"
        fp.confidence = 75
        table.insert(fp.recommendations, "FULL SURFACE: value edits, remote firing, auto-farm")
        table.insert(fp.recommendations, "start with game-state values — probably writable")
    end

    if fp.obfuscationScore >= 2 and fp.tier == "TIER 1" then
        fp.tier = "TIER 2"
        fp.confidence = 60
        table.insert(fp.risks, "downgraded to tier 2 — obfuscation despite visible sources")
    end

    State.fingerprint = fp
    return fp
end

-- ==============================================================
--  REPORTS
-- ==============================================================

local function buildFingerprintReport()
    local fp = State.fingerprint or analyzeFingerprint()
    local g = State.genre or detectGenre()
    local buf = {}
    local function add(t) table.insert(buf, t) end

    add("╔══════════════════════════════════════════╗")
    add("  PHANTOM v15 — MULTIVERSE BRIEFING")
    add("╚══════════════════════════════════════════╝")
    add("Game: " .. GameName)
    add("Place: " .. tostring(PlaceId))
    add("")
    add("TIER: " .. fp.tier .. " — " .. fp.tierName .. " (" .. fp.confidence .. "% confidence)")
    add("GENRE: " .. g.name .. " (" .. g.confidence .. "% confidence)")
    add("")
    add("── TIER SIGNALS ──")
    for _, s in ipairs(fp.signals) do
        add("  • " .. s)
    end
    if #fp.signals == 0 then add("  (none)") end
    add("")
    add("── GENRE EVIDENCE ──")
    for _, m in ipairs(g.matched) do
        add("  • " .. m)
    end
    add("")
    add("── RISKS ──")
    for _, r in ipairs(fp.risks) do
        add("  ⚠ " .. r)
    end
    if #fp.risks == 0 then add("  none flagged") end
    add("")
    add("── TIER APPROACH ──")
    for _, rec in ipairs(fp.recommendations) do
        add("  → " .. rec)
    end
    add("")
    add("── GENRE-SPECIFIC PLAYS ──")
    for _, a in ipairs(g.advice) do
        add("  ★ " .. a)
    end
    add("")
    add("── NUMBERS ──")
    add("  Scripts: " .. State.stats.total .. " | src:" .. State.stats.source .. " bc:" .. State.stats.bytecode .. " need:" .. State.stats.needDecomp .. " fail:" .. State.stats.failed)
    add("  Remotes: " .. #State.remotes.events .. "E / " .. #State.remotes.functions .. "F")
    add("  Values: " .. #State.objects.values .. " (game-state: " .. fp.stateCount .. ")")
    add("  NPCs: " .. #State.objects.humanoids .. " | Prompts: " .. #State.objects.prompts .. " | Spawns: " .. #State.objects.spawns)
    add("  Traffic: " .. #State.deepData.remoteCalls .. " calls | " .. #State.deepData.returns .. " returns")

    return table.concat(buf, "\n")
end

local function buildStructureMap()
    local buf = {}
    local function add(t) table.insert(buf, t) end

    add("════════ STRUCTURE MAP ════════")

    local systems = {}
    for _, e in ipairs(State.remotes.events) do
        local parent = e.path:match("^(.+)%.[^%.]+$") or "root"
        systems[parent] = systems[parent] or {events = 0, funcs = 0}
        systems[parent].events = systems[parent].events + 1
    end
    for _, f in ipairs(State.remotes.functions) do
        local parent = f.path:match("^(.+)%.[^%.]+$") or "root"
        systems[parent] = systems[parent] or {events = 0, funcs = 0}
        systems[parent].funcs = systems[parent].funcs + 1
    end

    local sorted = {}
    for name, data in pairs(systems) do
        table.insert(sorted, {name = name, events = data.events, funcs = data.funcs})
    end
    table.sort(sorted, function(a, b)
        return (a.events + a.funcs) > (b.events + b.funcs)
    end)

    add("REMOTE SUB-SYSTEMS:")
    for i, s in ipairs(sorted) do
        if i > 40 then add("  ...+" .. (#sorted - 40) .. " more") break end
        add(string.format("  [%dE/%dF] %s", s.events, s.funcs, s.name))
    end

    return table.concat(buf, "\n")
end

-- ==============================================================
--  DEEP SCAN v2 (returns + cooldowns)
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

local function serializeArg(arg)
    local t = typeof(arg)
    if t == "Instance" then
        return "Instance:" .. arg.ClassName .. "(" .. arg.Name .. ")"
    elseif t == "CFrame" then
        local p = arg.Position
        return string.format("CFrame(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
    elseif t == "Vector3" then
        return string.format("V3(%.1f,%.1f,%.1f)", arg.X, arg.Y, arg.Z)
    elseif t == "Color3" then
        return string.format("Color(%d,%d,%d)", arg.R * 255, arg.G * 255, arg.B * 255)
    elseif t == "table" then
        local ok, j = pcall(function() return HttpService:JSONEncode(arg) end)
        if ok and j then
            return "table:" .. j:sub(1, 80)
        end
        return "table:" .. tostring(arg):sub(1, 40)
    elseif t == "string" then
        return '"' .. tostring(arg):sub(1, 40) .. '"'
    else
        return t .. ":" .. tostring(arg):sub(1, 30)
    end
end

local function startDeepScan(duration)
    duration = duration or 300
    if State.deepScanning then
        notify("Deep Scan", "Already running", 3)
        return
    end
    State.deepScanning = true
    State.deepData = {remoteCalls = {}, promptHits = {}, spawns = {}, returns = {}}
    notify("Deep Scan", "Monitoring " .. duration .. "s — play the core loop", 6)

    connections.promptAdded = workspace.DescendantAdded:Connect(function(d)
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

    connections.spawnWatch = workspace.DescendantAdded:Connect(function(d)
        if d:IsA("Model") and not (CFG.skipCharacters and Players:GetPlayerFromCharacter(d)) then
            if d:FindFirstChildOfClass("Humanoid") then
                table.insert(State.deepData.spawns, {
                    time = os.date("%H:%M:%S"),
                    name = d.Name,
                    path = d:GetFullName()
                })
            end
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
                    argStr = argStr .. "[" .. i .. "] " .. serializeArg(arg) .. "  "
                end

                local call = {
                    time = os.date("%H:%M:%S"),
                    clock = os.clock(),
                    method = method,
                    remote = self.Name,
                    path = self:GetFullName(),
                    args = argStr,
                    argCount = #args
                }
                table.insert(State.deepData.remoteCalls, call)

                if method == "InvokeServer" and CFG.captureReturns then
                    local results = {originalNamecall(self, ...)}
                    local retStr = ""
                    for i, res in ipairs(results) do
                        retStr = retStr .. "[" .. i .. "] " .. serializeArg(res) .. "  "
                    end
                    table.insert(State.deepData.returns, {
                        time = call.time,
                        remote = self.Name,
                        path = call.path,
                        returns = retStr
                    })
                    return unpack(results)
                end
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
            notify("Deep Scan Done",
                string.format("Calls: %d | Returns: %d | Prompts: %d",
                    #State.deepData.remoteCalls, #State.deepData.returns, #State.deepData.promptHits), 7)
        end
    end)
end

local function stopDeepScan()
    if not State.deepScanning then return end
    State.deepScanning = false
    disconnectDeep()
    restoreHook()
    notify("Deep Scan Stopped", string.format("Calls: %d | Returns: %d",
        #State.deepData.remoteCalls, #State.deepData.returns), 5)
end

local function analyzeTraffic()
    local buf = {}
    local function add(t) table.insert(buf, t) end

    add("════════ TRAFFIC ANALYSIS ════════")
    add("Total calls: " .. #State.deepData.remoteCalls)
    add("Captured returns: " .. #State.deepData.returns)
    add("")

    local freq = {}
    local order = {}
    local lastCallTime = {}
    local minGaps = {}
    for _, c in ipairs(State.deepData.remoteCalls) do
        if not freq[c.path] then
            freq[c.path] = 0
            table.insert(order, c.path)
        end
        freq[c.path] = freq[c.path] + 1
        if lastCallTime[c.path] then
            local gap = c.clock - lastCallTime[c.path]
            if not minGaps[c.path] or gap < minGaps[c.path] then
                minGaps[c.path] = gap
            end
        end
        lastCallTime[c.path] = c.clock
    end
    table.sort(order, function(a, b) return freq[a] > freq[b] end)

    add("── FREQUENCY + DETECTED COOLDOWNS ──")
    for i, path in ipairs(order) do
        if i > 40 then add("  ...+" .. (#order - 40) .. " more") break end
        local gapStr = minGaps[path] and string.format("min-gap %.2fs", minGaps[path]) or "single"
        add(string.format("  %3dx | %s | %s", freq[path], gapStr, path))
    end

    if #State.deepData.returns > 0 then
        add("")
        add("── SERVER RETURN VALUES ──")
        for i, r in ipairs(State.deepData.returns) do
            if i > 30 then add("  ...more") break end
            add("  [" .. r.time .. "] " .. r.remote)
            add("    → " .. r.returns)
        end
    end

    add("")
    add("── SAFETY NOTES ──")
    for path, gap in pairs(minGaps) do
        if gap < 0.1 and freq[path] > 5 then
            add("  ⚠ " .. path .. " fires <100ms apart naturally — don't spam faster")
        end
    end

    return table.concat(buf, "\n")
end

-- ==============================================================
--  TEMPLATES + EXPORT
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
    local buf = {"-- PHANTOM REMOTE TEMPLATES -- " .. GameName, ""}
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
    local buf = {"-- SMART TEMPLATES (from live traffic)", ""}
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
        table.insert(buf, "-- observed args: " .. data.calls[1].args)
        if data.method == "FireServer" then
            table.insert(buf, "remote:FireServer(--[[ replicate exact args ]])")
        else
            table.insert(buf, "local result = remote:InvokeServer(--[[ replicate exact args ]])")
        end
        table.insert(buf, "")
    end
    if #order == 0 then
        table.insert(buf, "-- no traffic yet. run deep scan + play the core loop.")
    end
    return table.concat(buf, "\n")
end

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

local function exportTXT(includeSources)
    if includeSources == nil then includeSources = true end

    local buf = {}
    local function add(t) table.insert(buf, t) end

    add("==========================================")
    add("  PHANTOM SCANNER v15 MULTIVERSE EXPORT")
    add("==========================================")
    add("Game: " .. GameName)
    add("Place ID: " .. tostring(PlaceId))
    add("Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    add("Executor: " .. executorInfo)
    add("Scan Duration: " .. string.format("%.1fs", State.scanDuration))
    add("Instances Walked: " .. State.stats.instancesWalked)
    add("Containers Failed: " .. State.stats.containersFailed)
    add("")

    if not State.fingerprint then analyzeFingerprint() end
    if not State.genre then detectGenre() end
    for _, line in ipairs(buildFingerprintReport():split("\n")) do
        add(line)
    end
    add("")
    for _, line in ipairs(buildStructureMap():split("\n")) do
        add(line)
    end
    add("")

    if #State.deepData.remoteCalls > 0 then
        for _, line in ipairs(analyzeTraffic():split("\n")) do
            add(line)
        end
        add("")
    end

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
    add("========== DEEP SCAN RAW ==========")
    add("--- Remote Calls (" .. #State.deepData.remoteCalls .. ") ---")
    for _, c in ipairs(State.deepData.remoteCalls) do
        add("[" .. c.time .. "] " .. c.method .. "." .. c.remote)
        add("  Path: " .. c.path)
        add("  Args: " .. c.args)
    end
    add("--- Invoke Returns (" .. #State.deepData.returns .. ") ---")
    for _, r in ipairs(State.deepData.returns) do
        add("[" .. r.time .. "] " .. r.remote)
        add("  Returns: " .. r.returns)
    end
    add("--- Prompt Hits (" .. #State.deepData.promptHits .. ") ---")
    for _, c in ipairs(State.deepData.promptHits) do
        add("[" .. c.time .. "] " .. c.prompt .. " | " .. c.path)
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
                add("[NO SOURCE — Pass C or server-only]")
            end
            add("")
            if ri % 50 == 0 then
                RunService.RenderStepped:Wait()
            end
        end
    end

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

-- full pipeline with profile save
local function runFullScan(progressCb)
    State.busy = true
    State.cancelScan = false
    State.scanStart = os.clock()

    unifiedWalk(function(walked)
        pcall(function() progressCb("walking... " .. walked .. " instances") end)
    end)

    grabSources(function(i, total)
        pcall(function() progressCb("sources... " .. i .. " / " .. total) end)
    end)

    scanSecurity()
    analyzeFingerprint()
    detectGenre()

    State.scanDuration = os.clock() - State.scanStart
    State.busy = false
    State.cancelScan = false

    -- save profile for multiverse memory
    local fp = State.fingerprint
    saveProfile({
        date = os.date("%Y-%m-%d %H:%M"),
        tier = fp.tier .. " " .. fp.tierName,
        genre = State.genre.name,
        scripts = State.stats.total,
        instances = State.stats.instancesWalked,
        remotes = #State.remotes.events + #State.remotes.functions,
        values = #State.objects.values
    })

    notify("Scan Complete",
        string.format("%.1fs | %d inst | %s — %s | %s",
            State.scanDuration, State.stats.instancesWalked,
            fp.tier, fp.tierName, State.genre.name), 9)
end

-- ==============================================================
--  TABS
-- ==============================================================

local TabMain = Window:CreateTab("Main", 4483345998)
TabMain:CreateSection("Multiverse Recon")

local progressLabel = TabMain:CreateLabel("ready.")

TabMain:CreateButton({
    Name = "SCAN (walk + sources + tier + genre)",
    Callback = function()
        task.spawn(function()
            runFullScan(function(text)
                pcall(function() progressLabel:Set(text) end)
            end)
            local fp = State.fingerprint
            pcall(function()
                progressLabel:Set(string.format(
                    "done %.1fs | %d inst | %d scripts | %s | %s",
                    State.scanDuration, State.stats.instancesWalked,
                    State.stats.total, fp.tier, State.genre.name))
            end)
            if refreshScriptDropdown then refreshScriptDropdown() end
        end)
    end
}, 40)

TabMain:CreateButton({
    Name = "Pass C: Decompile All Remaining",
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

TabMain:CreateSection("Intelligence")

TabMain:CreateButton({
    Name = "Full Briefing (F9 + clipboard)",
    Callback = function()
        task.spawn(function()
            if not State.fingerprint then analyzeFingerprint() end
            if not State.genre then detectGenre() end
            local report = buildFingerprintReport()
            print(report)
            if setclipboard then setclipboard(report) end
            notify("Briefing", State.fingerprint.tier .. " | " .. State.genre.name, 7)
        end)
    end
})

TabMain:CreateButton({
    Name = "Structure Map (F9)",
    Callback = function()
        task.spawn(function()
            print(buildStructureMap())
            notify("Structure", "Map in F9", 5)
        end)
    end
})

TabMain:CreateButton({
    Name = "Traffic Analysis (F9)",
    Callback = function()
        task.spawn(function()
            if #State.deepData.remoteCalls == 0 then
                notify("Traffic", "No traffic — run deep scan first", 4)
                return
            end
            print(analyzeTraffic())
            if writefile then
                writeSingle(analyzeTraffic(), safeGameName .. "_traffic", ".txt")
            end
            notify("Traffic", "Analysis in F9 + saved", 6)
        end
    end
})

TabMain:CreateButton({
    Name = "Scan History (all games remembered) — F9",
    Callback = function()
        task.spawn(function()
            print("=== PHANTOM MULTIVERSE HISTORY ===")
            local count = 0
            for pid, prof in pairs(PROFILES) do
                count = count + 1
                print(string.format("[%s] %s | %s | %s | scripts:%s",
                    pid, tostring(prof.date), tostring(prof.tier), tostring(prof.genre), tostring(prof.scripts)))
            end
            print("total games: " .. count)
            notify("History", count .. " games remembered", 4)
        end)
    end
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
    Name = "Decompile SELECTED",
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
                ok and (tostring(#args) .. " args — watch for delayed kick") or tostring(err), 5)
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
                notify("Returned", s:sub(1, 200), 7)
                print("[Phantom invoke] " .. State.remotePath .. " → " .. s)
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
    Name = "Smart Templates (from traffic)",
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
    PlaceholderText = "cash, health, enabled...",
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

TabVal:CreateButton({
    Name = "Find Game-State Values (F9)",
    Callback = function()
        task.spawn(function()
            local patterns = {"cash", "coin", "money", "gem", "token", "point", "score", "level", "xp", "health", "ammo", "inventory", "gold", "credit"}
            local count = 0
            print("=== GAME-STATE VALUE CANDIDATES ===")
            for _, v in ipairs(State.objects.values) do
                local low = v.path:lower()
                for _, sp in ipairs(patterns) do
                    if low:find(sp, 1, true) then
                        print("[" .. v.class .. "] " .. v.path .. " = " .. tostring(v.val))
                        count = count + 1
                        break
                    end
                end
                if count > 100 then print("...more") break end
            end
            notify("Values", count .. " candidates in F9", 5)
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
TabDeep:CreateSection("Live Traffic Monitor")

local deepStatsLabel = TabDeep:CreateLabel("calls: 0 | returns: 0 | prompts: 0")

task.spawn(function()
    while true do
        if State.deepScanning then
            pcall(function()
                deepStatsLabel:Set(string.format("calls: %d | returns: %d | prompts: %d",
                    #State.deepData.remoteCalls, #State.deepData.returns, #State.deepData.promptHits))
            end)
        end
        task.wait(1)
    end
end)

TabDeep:CreateButton({Name = "Start Deep Scan (300s) — play the core loop", Callback = function() startDeepScan(300) end})
TabDeep:CreateButton({Name = "Start Deep Scan (60s)", Callback = function() startDeepScan(60) end})
TabDeep:CreateButton({Name = "Stop Deep Scan", Callback = function() stopDeepScan() end})

TabDeep:CreateButton({
    Name = "Print Traffic Analysis (F9)",
    Callback = function()
        task.spawn(function()
            if #State.deepData.remoteCalls == 0 then
                notify("Traffic", "No data yet", 3)
                return
            end
            print(analyzeTraffic())
            notify("Traffic", "Analysis in F9", 4)
        end)
    end
})

-- export tab
local TabExp = Window:CreateTab("Export", 4483345998)
TabExp:CreateSection("Export")

local exportLabel = TabExp:CreateLabel("filename: " .. safeGameName .. "_<ts>.txt")

TabExp:CreateButton({
    Name = "Export FULL RECON (briefing + map + traffic + data + sources)",
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
    Name = "Export Intel ONLY (instant)",
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
    Name = "Frame Budget (ms per frame)",
    Range = {2, 16},
    Increment = 1,
    Suffix = "ms",
    CurrentValue = CFG.frameBudgetMS,
    Flag = "FrameBudget",
    Callback = function(v)
        CFG.frameBudgetMS = v
        persistConfig()
    end
})

TabSet:CreateSlider({
    Name = "Instance Cap",
    Range = {100000, 2000000},
    Increment = 100000,
    Suffix = "inst",
    CurrentValue = CFG.maxInstances,
    Flag = "MaxInstances",
    Callback = function(v)
        CFG.maxInstances = v
        persistConfig()
    end
})

TabSet:CreateSection("Behavior")

TabSet:CreateToggle({
    Name = "Skip Player Characters",
    CurrentValue = CFG.skipCharacters,
    Flag = "SkipChars",
    Callback = function(v)
        CFG.skipCharacters = v
        persistConfig()
        notify("Setting", v and "Char skip ON" or "OFF", 3)
    end
})

TabSet:CreateToggle({
    Name = "Capture InvokeServer Returns",
    CurrentValue = CFG.captureReturns,
    Flag = "CaptureRet",
    Callback = function(v)
        CFG.captureReturns = v
        persistConfig()
        notify("Setting", v and "Return capture ON" or "OFF", 3)
    end
})

TabSet:CreateToggle({
    Name = "Deduplicate",
    CurrentValue = CFG.dedup,
    Flag = "DedupToggle",
    Callback = function(v)
        CFG.dedup = v
        persistConfig()
        notify("Setting", v and "Dedup ON" or "OFF", 3)
    end
})

TabSet:CreateToggle({
    Name = "Scan CoreGui (noisy)",
    CurrentValue = CFG.scanCoreGui,
    Flag = "CoreGuiToggle",
    Callback = function(v)
        CFG.scanCoreGui = v
        persistConfig()
        notify("Setting", v and "CoreGui ON" or "OFF", 3)
    end
})

TabSet:CreateSection("Profile Memory")

TabSet:CreateButton({
    Name = "Clear This Game's Profile",
    Callback = function()
        PROFILES[tostring(PlaceId)] = nil
        saveJson(PROFILES_FILE, PROFILES)
        thisProfile = nil
        notify("Profile", "Cleared — next load counts as first visit", 4)
    end
})

TabSet:CreateButton({
    Name = "Wipe ALL Profiles",
    Callback = function()
        PROFILES = {}
        saveJson(PROFILES_FILE, PROFILES)
        thisProfile = nil
        notify("Profile", "All history wiped", 4)
    end
})

-- wire refresh
local origRunFullScan = runFullScan
runFullScan = function(cb)
    origRunFullScan(cb)
    refreshRemoteDropdown()
end

print("=== PHANTOM SCANNER v15 MULTIVERSE loaded ===")
print("=== Game: " .. GameName .. " ===")
print("=== Pipeline: SCAN → Tier+Genre → Deep Scan → Smart Templates ===")
notify("Phantom v15", "Multiverse loaded — " .. GameName, 6)
