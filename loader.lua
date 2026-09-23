--!nocheck
-- ==============================================================
--  PHANTOM RECON DROP v1
--  Paste → scan → full briefing. No UI. One shot.
--  Output: F9 console + "PhantomRecon_<game>.txt"
-- ==============================================================

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local HttpService        = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer

local function getExecFunc(name)
    local ok, fn = pcall(function() return getgenv()[name] end)
    if ok and type(fn) == "function" then return fn end
    return _G[name]
end

local getsrc            = getExecFunc("getsrc")
local decompile         = getExecFunc("decompile")
local getscriptbytecode = getExecFunc("getscriptbytecode")
local writefile         = getExecFunc("writefile")
local isfolder          = getExecFunc("isfolder")
local makefolder        = getExecFunc("makefolder")
local setclipboard      = getExecFunc("setclipboard")
local identifyexecutor  = getExecFunc("identifyexecutor")

local GameName = "UnknownGame"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name and info.Name ~= "" then GameName = info.Name end
end)

local safeGameName = tostring(GameName):gsub("[^%w%-_]", "_"):sub(1, 50)

local executorInfo = "Unknown"
pcall(function()
    local n, v = identifyexecutor()
    executorInfo = tostring(n)
end)

local function sendNotif(title, msg, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = msg, Duration = dur or 4
        })
    end)
end

sendNotif("Phantom Recon", "Scanning " .. GameName .. "...", 5)
print("[Phantom] =========================================")
print("[Phantom] RECON DROP STARTED: " .. GameName)
print("[Phantom] =========================================")

-- ==============================================================
--  UNIFIED WALK (v13/14 engine — unfreezable)
-- ==============================================================

local scripts = {}
local scriptHashes = {}
local remotes = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}}
local objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}}
local assets = {sounds = {}, animations = {}, meshes = {}, decals = {}}
local stats = {instancesWalked = 0, containersFailed = 0, deduped = 0}

local remoteHashes = {}
local valueHashes = {}
local objHashes = {}

local junkValues = {
    OriginalSize = true,
    OriginalPosition = true,
    AvatarPartScaleType = true
}

local containers = {}
local function tryAdd(svc)
    pcall(function()
        local s = game:GetService(svc)
        if s then table.insert(containers, s) end
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
        table.insert(containers, LocalPlayer.PlayerScripts)
    end
end)
pcall(function()
    if LocalPlayer:FindFirstChild("PlayerGui") then
        table.insert(containers, LocalPlayer.PlayerGui)
    end
end)

local walkStart = os.clock()
local frameStart = os.clock()

local function maybeYield()
    if (os.clock() - frameStart) >= 0.008 then
        RunService.RenderStepped:Wait()
        frameStart = os.clock()
    end
end

for _, container in ipairs(containers) do
    local ok, err = pcall(function()
        local stack = {container}
        while #stack > 0 do
            local node = table.remove(stack)
            local gotKids, children = pcall(node.GetChildren, node)
            if gotKids then
                for _, inst in ipairs(children) do
                    stats.instancesWalked = stats.instancesWalked + 1
                    local cls = inst.ClassName

                    if cls == "LocalScript" or cls == "Script" or cls == "ModuleScript" then
                        table.insert(stack, inst)
                        local okP, path = pcall(inst.GetFullName, inst)
                        if okP and not scriptHashes[path .. "|" .. cls] then
                            scriptHashes[path .. "|" .. cls] = true
                            table.insert(scripts, {
                                path = path,
                                name = inst.Name,
                                className = cls,
                                inst = inst,
                                source = "",
                                status = "PENDING"
                            })
                        else
                            stats.deduped = stats.deduped + 1
                        end

                    elseif cls == "RemoteEvent" then
                        local okP, p = pcall(inst.GetFullName, inst)
                        if okP and not remoteHashes[p] then
                            remoteHashes[p] = true
                            table.insert(remotes.events, {path = p, name = inst.Name})
                        end
                    elseif cls == "RemoteFunction" then
                        local okP, p = pcall(inst.GetFullName, inst)
                        if okP and not remoteHashes[p] then
                            remoteHashes[p] = true
                            table.insert(remotes.functions, {path = p, name = inst.Name})
                        end
                    elseif cls == "BindableEvent" then
                        local okP, p = pcall(inst.GetFullName, inst)
                        if okP and not remoteHashes[p] then
                            remoteHashes[p] = true
                            table.insert(remotes.bindables, {path = p, name = inst.Name})
                        end
                    elseif cls == "BindableFunction" then
                        local okP, p = pcall(inst.GetFullName, inst)
                        if okP and not remoteHashes[p] then
                            remoteHashes[p] = true
                            table.insert(remotes.bindableFuncs, {path = p, name = inst.Name})
                        end

                    elseif cls == "ProximityPrompt" then
                        local okP, p = pcall(inst.GetFullName, inst)
                        if okP and not objHashes[p] then
                            objHashes[p] = true
                            table.insert(objects.prompts, {path = p, name = inst.Name})
                        end
                    elseif cls == "ClickDetector" then
                        local okP, p = pcall(inst.GetFullName, inst)
                        if okP and not objHashes[p] then
                            objHashes[p] = true
                            table.insert(objects.clickDetectors, {path = p, name = inst.Name})
                        end
                    elseif cls == "SpawnLocation" then
                        local okP, p = pcall(inst.GetFullName, inst)
                        if okP and not objHashes[p] then
                            objHashes[p] = true
                            local pos = "?"
                            pcall(function() pos = tostring(inst.Position) end)
                            table.insert(objects.spawns, {path = p, pos = pos})
                        end

                    elseif cls == "IntValue" or cls == "NumberValue" or cls == "StringValue"
                        or cls == "BoolValue" or cls == "ObjectValue" then
                        if not junkValues[inst.Name] then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not valueHashes[p] then
                                valueHashes[p] = true
                                local entry = {path = p, class = cls, ref = inst}
                                pcall(function() entry.val = tostring(inst.Value):sub(1, 60) end)
                                table.insert(objects.values, entry)
                            end
                        end

                    elseif cls == "Sound" then
                        local okP, p = pcall(inst.GetFullName, inst)
                        if okP and not objHashes[p] then
                            objHashes[p] = true
                            local id = ""
                            pcall(function() id = tostring(inst.SoundId) end)
                            table.insert(assets.sounds, {path = p, id = id})
                        end
                    elseif cls == "Animation" then
                        local okP, p = pcall(inst.GetFullName, inst)
                        if okP and not objHashes[p] then
                            objHashes[p] = true
                            local id = ""
                            pcall(function() id = tostring(inst.AnimationId) end)
                            table.insert(assets.animations, {path = p, id = id})
                        end

                    elseif cls == "Model" then
                        local isChar = Players:GetPlayerFromCharacter(inst)
                        if not isChar then
                            local hum = inst:FindFirstChildOfClass("Humanoid")
                            if hum and not objHashes[inst:GetFullName()] then
                                local okP, p = pcall(inst.GetFullName, inst)
                                if okP then
                                    objHashes[p] = true
                                    local root = inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart
                                    local px, py, pz
                                    if root then
                                        pcall(function()
                                            px, py, pz = root.Position.X, root.Position.Y, root.Position.Z
                                        end)
                                    end
                                    table.insert(objects.humanoids, {
                                        path = p, name = inst.Name,
                                        hp = hum.Health, mhp = hum.MaxHealth,
                                        pos = px and string.format("%.1f,%.1f,%.1f", px, py, pz) or "?",
                                        px = px, py = py, pz = pz
                                    })
                                end
                            end
                        end
                        table.insert(stack, inst)
                    else
                        table.insert(stack, inst)
                    end

                    maybeYield()
                end
            else
                maybeYield()
            end
        end
    end)

    if not ok then
        stats.containersFailed = stats.containersFailed + 1
        warn("[Phantom] container failed: " .. tostring(err))
    end
    RunService.RenderStepped:Wait()
end

local walkTime = os.clock() - walkStart
print(string.format("[Phantom] walk done: %d instances in %.1fs", stats.instancesWalked, walkTime))
sendNotif("Walk Done", stats.instancesWalked .. " instances | " .. #scripts .. " scripts", 4)

-- ==============================================================
--  FAST SOURCE GRAB (no decompile — instant)
-- ==============================================================

local srcStart = os.clock()
frameStart = os.clock()
local countSource, countBytecode, countNeed = 0, 0, 0

for i, r in ipairs(scripts) do
    local s = r.inst
    if s and s.Parent then
        local got = false
        if getsrc then
            local ok, src = pcall(getsrc, s)
            if ok and type(src) == "string" and #src > 0 then
                r.source = src
                r.status = "SOURCE"
                countSource = countSource + 1
                got = true
            end
        end
        if not got and getscriptbytecode then
            local ok, bc = pcall(getscriptbytecode, s)
            if ok and type(bc) == "string" and #bc > 0 then
                r.status = "BYTECODE"
                countBytecode = countBytecode + 1
                got = true
            end
        end
        if not got then
            r.status = "UNREACHABLE"
            countNeed = countNeed + 1
        end
    else
        r.status = "GONE"
        countNeed = countNeed + 1
    end
    if (os.clock() - frameStart) >= 0.008 then
        RunService.RenderStepped:Wait()
        frameStart = os.clock()
    end
end

local srcTime = os.clock() - srcStart
print(string.format("[Phantom] sources: %d ok | %d bytecode | %d unreachable (%.1fs)",
    countSource, countBytecode, countNeed, srcTime))

-- ==============================================================
--  SECURITY PATTERN SCAN (on captured sources)
-- ==============================================================

local acHits, bdHits, webhookHits, requireHits = {}, {}, {}, {}

local acPatterns = {"anticheat", "anti-cheat", "exploit", "detect", "flag", "tamper", "noclip", "speedhack", "kick", "crash", "rejoin", "ban"}
local bdPatterns = {"loadstring(game:httpget", "require(", "backdoor", "getfenv(", "setfenv(", "getgenv("}
local webhookPatterns = {"discord.com/api/webhooks", "discordapp.com/api/webhooks", "webhook"}

frameStart = os.clock()
for si, r in ipairs(scripts) do
    if r.status == "SOURCE" and #r.source > 0 then
        local lines = {}
        for line in (r.source .. "\n"):gmatch("(.-)\n") do
            table.insert(lines, line)
        end
        for li, line in ipairs(lines) do
            local ll = line:lower()
            for _, pat in ipairs(acPatterns) do
                if ll:find(pat, 1, true) then
                    table.insert(acHits, r.path .. ":L" .. li .. " [" .. pat .. "] " .. line:gsub("^%s+", ""):sub(1, 80))
                    break
                end
            end
            for _, pat in ipairs(bdPatterns) do
                if ll:find(pat, 1, true) then
                    table.insert(bdHits, r.path .. ":L" .. li .. " [" .. pat .. "]")
                    break
                end
            end
            for _, pat in ipairs(webhookPatterns) do
                if ll:find(pat, 1, true) then
                    table.insert(webhookHits, r.path .. ":L" .. li .. " | " .. line:gsub("^%s+", ""):sub(1, 100))
                    break
                end
            end
        end
    end
    if si % 40 == 0 then RunService.RenderStepped:Wait() end
end

-- ==============================================================
--  FINGERPRINT CLASSIFICATION
-- ==============================================================

local fp = {
    serverScore = 0,
    clientScore = 0,
    signals = {},
    risks = {},
    verdict = "?",
    advice = {}
}

-- validation bindables = big red flag
local validationNames = {"dataverification", "validate", "anticheat", "securitycheck", "verifyaction", "integritycheck"}
for _, b in ipairs(remotes.bindables) do
    local low = b.path:lower()
    for _, vn in ipairs(validationNames) do
        if low:find(vn, 1, true) then
            fp.serverScore = fp.serverScore + 3
            table.insert(fp.signals, "VALIDATION BINDABLE: " .. b.path)
            break
        end
    end
end

-- obfuscated remote naming = pro codebase
local totalLen, totalRemotes, shortNames = 0, 0, 0
for _, e in ipairs(remotes.events) do
    totalLen = totalLen + #e.name
    totalRemotes = totalRemotes + 1
    if #e.name <= 3 then shortNames = shortNames + 1 end
end
if totalRemotes > 0 then
    local avgLen = totalLen / totalRemotes
    if avgLen < 4 or (shortNames / totalRemotes) > 0.3 then
        fp.serverScore = fp.serverScore + 2
        table.insert(fp.signals, string.format("obfuscated remotes (avg name %.1f chars)", avgLen))
    else
        fp.clientScore = fp.clientScore + 1
        table.insert(fp.signals, string.format("descriptive remotes (avg name %.1f chars)", avgLen))
    end
end

-- source visibility
local totalScripts = countSource + countBytecode + countNeed
local srcRatio = totalScripts > 0 and (countSource / totalScripts) or 0
if srcRatio > 0.7 then
    fp.clientScore = fp.clientScore + 2
    table.insert(fp.signals, string.format("high source visibility (%.0f%% readable)", srcRatio * 100))
elseif srcRatio < 0.3 and totalScripts > 0 then
    fp.serverScore = fp.serverScore + 2
    table.insert(fp.signals, string.format("low source visibility (%.0f%% readable)", srcRatio * 100))
end

-- game-state values
local statePatterns = {"cash", "coin", "money", "gem", "token", "point", "score", "level", "xp", "health", "ammo", "gold", "credit"}
local stateCount = 0
for _, v in ipairs(objects.values) do
    local low = v.path:lower()
    for _, sp in ipairs(statePatterns) do
        if low:find(sp, 1, true) then
            stateCount = stateCount + 1
            break
        end
    end
end
if stateCount > 20 then
    fp.clientScore = fp.clientScore + 2
    table.insert(fp.signals, stateCount .. " game-state values replicated client-side")
end

-- webhooks = snitching
if #webhookHits > 0 then
    fp.serverScore = fp.serverScore + 1
    table.insert(fp.risks, "GAME LOGS TO DISCORD WEBHOOKS — actions may be reported live")
end

-- classify
local score = fp.serverScore - fp.clientScore
if score >= 4 then
    fp.verdict = "TIER 3 — HARDENED (server-auth + likely obfuscated/validated)"
    fp.advice = {
        "SAFE: teleport menu (from spawn coords), ESP, fullbright, data browsers",
        "AVOID: firing economy/damage remotes — validation active, ban risk real",
        "RECON: remote map + traffic capture is your only real intel here",
        "client code likely VM-packed — decompile output will be garbage"
    }
elseif score >= 1 then
    fp.verdict = "TIER 2 — HYBRID (client visuals free, actions validated)"
    fp.advice = {
        "SAFE: movement mods, ESP, TPs, prompt automation, client visuals",
        "TEST-ON-ALT: any remote that spends/moves/creates resources",
        "capture live traffic while playing — replicate exact observed args only",
        "never invent arguments on validated remotes"
    }
else
    fp.verdict = "TIER 1 — CLIENT-AUTHORITATIVE (full surface)"
    fp.advice = {
        "value edits, remote firing, auto-farm loops all viable",
        "start with game-state values — often directly writable",
        "remotes likely accept simple args — test freely"
    }
end

if srcRatio < 0.3 and score < 1 then
    table.insert(fp.risks, "client sources mostly unreadable — logic is elsewhere")
end

-- ==============================================================
--  BUILD THE BRIEFING
-- ==============================================================

local buf = {}
local function add(t) table.insert(buf, t) end
local function line(t) print(t) table.insert(buf, t) end

add("╔══════════════════════════════════════════════════╗")
add("  PHANTOM RECON BRIEFING")
add("╚══════════════════════════════════════════════════╝")
add("Game: " .. GameName)
add("Place: " .. tostring(game.PlaceId))
add("Executor: " .. executorInfo)
add("Scanned: " .. os.date("%Y-%m-%d %H:%M:%S"))
add("Walk: " .. stats.instancesWalked .. " instances in " .. string.format("%.1fs", walkTime))
if stats.containersFailed > 0 then
    add("⚠ " .. stats.containersFailed .. " containers failed to walk (results may be partial)")
end

add("")
add("═══════════ VERDICT ═══════════")
add(fp.verdict)
add("")
add("SIGNALS:")
for _, s in ipairs(fp.signals) do
    add("  • " .. s)
end
add("")
if #fp.risks > 0 then
    add("RISKS:")
    for _, r in ipairs(fp.risks) do
        add("  ⚠ " .. r)
    end
    add("")
end
add("APPROACH:")
for _, a in ipairs(fp.advice) do
    add("  → " .. a)
end

add("")
add("═══════════ CODE COVERAGE ═══════════")
add(string.format("Scripts found: %d (deduped %d)", #scripts, stats.deduped))
add(string.format("Source readable: %d (%.0f%%)", countSource, srcRatio * 100))
add("Bytecode only: " .. countBytecode)
add("Unreachable (server-only/VM): " .. countNeed)
if countSource > 0 then
    add("")
    add("KEY CAPTURED SCRIPTS (largest client-readable):")
    local sized = {}
    for _, r in ipairs(scripts) do
        if r.status == "SOURCE" and #r.source > 0 then
            table.insert(sized, r)
        end
    end
    table.sort(sized, function(a, b) return #a.source > #b.source end)
    for i = 1, math.min(15, #sized) do
        add(string.format("  [%6d bytes] %s", #sized[i].source, sized[i].path))
    end
end

add("")
add("═══════════ REMOTE MAP (" .. (#remotes.events + #remotes.functions) .. " total) ═══════════")
add("RemoteEvents: " .. #remotes.events)
add("RemoteFunctions: " .. #remotes.functions)
add("Bindables: " .. (#remotes.bindables + #remotes.bindableFuncs))
add("")
if #remotes.events > 0 then
    add("ALL REMOTE EVENTS:")
    for _, e in ipairs(remotes.events) do
        add("  " .. e.path)
    end
    add("")
end
if #remotes.functions > 0 then
    add("ALL REMOTE FUNCTIONS:")
    for _, f in ipairs(remotes.functions) do
        add("  " .. f.path)
    end
    add("")
end
if #remotes.bindables > 0 then
    add("BINDABLE EVENTS (server-internal signals — read these for validation warnings):")
    for _, b in ipairs(remotes.bindables) do
        add("  " .. b.path)
    end
    add("")
end

add("═══════════ INTERACTABLES ═══════════")
add("ProximityPrompts: " .. #objects.prompts)
add("ClickDetectors: " .. #objects.clickDetectors)
add("NPCs: " .. #objects.humanoids)
for _, n in ipairs(objects.humanoids) do
    add("  " .. n.name .. " | HP:" .. tostring(n.hp) .. "/" .. tostring(n.mhp) .. " | " .. n.path .. " @ " .. n.pos)
end
add("SpawnLocations: " .. #objects.spawns .. " (teleport targets)")
for _, s in ipairs(objects.spawns) do
    add("  " .. s.path .. " @ " .. s.pos)
end

add("")
add("═══════════ GAME-STATE VALUES (" .. stateCount .. " candidates) ═══════════")
for _, v in ipairs(objects.values) do
    local low = v.path:lower()
    for _, sp in ipairs(statePatterns) do
        if low:find(sp, 1, true) then
            add("  [" .. v.class .. "] " .. v.path .. " = " .. tostring(v.val))
            break
        end
    end
end
add("")
add("ALL VALUES (" .. #objects.values .. " total, first 200):")
for i, v in ipairs(objects.values) do
    if i > 200 then add("  ...+" .. (#objects.values - 200) .. " more in full dump") break end
    add("  [" .. v.class .. "] " .. v.path .. " = " .. tostring(v.val))
end

add("")
add("═══════════ SECURITY FINDINGS ═══════════")
add("Anti-cheat mentions: " .. #acHits)
for i, h in ipairs(acHits) do
    if i > 15 then add("  ...more") break end
    add("  " .. h)
end
add("Backdoor patterns: " .. #bdHits)
for i, h in ipairs(bdHits) do
    if i > 10 then add("  ...more") break end
    add("  " .. h)
end
add("Webhook logging: " .. #webhookHits)
for i, h in ipairs(webhookHits) do
    if i > 10 then add("  ...more") break end
    add("  " .. h)
end

add("")
add("═══════════ ASSETS ═══════════")
add("Sounds: " .. #assets.sounds .. " | Animations: " .. #assets.animations)
add("(full lists in saved file)")

add("")
add("═══════════ NEXT STEP ═══════════")
add("Run traffic capture while playing normally to map")
add("real argument patterns. That file + this briefing =")
add("everything needed to build a script for this game.")
add("")
add("=== END BRIEFING ===")

-- ==============================================================
--  OUTPUT
-- ==============================================================

local report = table.concat(buf, "\n")
print(report)

-- full dump with sources appended
local fullDump = {report}
table.insert(fullDump, "")
table.insert(fullDump, "═══════════ SCRIPT SOURCES ═══════════")
table.insert(fullDump, "")
for ri, r in ipairs(scripts) do
    table.insert(fullDump, "------ " .. r.path .. " [" .. r.className .. "] ------")
    table.insert(fullDump, "Status: " .. r.status)
    table.insert(fullDump, "")
    if #r.source > 0 then
        table.insert(fullDump, r.source)
    else
        table.insert(fullDump, "[NO SOURCE — " .. r.status .. "]")
    end
    table.insert(fullDump, "")
    if ri % 50 == 0 then RunService.RenderStepped:Wait() end
end
local fullOut = table.concat(fullDump, "\n")

-- chunked save (no freeze on big games)
if writefile then
    local CHUNK = 3000000
    local ts = tostring(os.time())
    if #fullOut <= CHUNK then
        local fname = "PhantomRecon_" .. safeGameName .. "_" .. ts .. ".txt"
        pcall(writefile, fname, fullOut)
        print("[Phantom] saved: " .. fname)
        sendNotif("Recon Saved", fname, 6)
    else
        local parts = math.ceil(#fullOut / CHUNK)
        for i = 1, parts do
            local s = (i - 1) * CHUNK + 1
            local e = math.min(i * CHUNK, #fullOut)
            local fname = "PhantomRecon_" .. safeGameName .. "_" .. ts .. "_part" .. i .. ".txt"
            pcall(writefile, fname, fullOut:sub(s, e))
            RunService.RenderStepped:Wait()
        end
        print("[Phantom] saved: " .. parts .. " parts (report too big for one file)")
        sendNotif("Recon Saved", parts .. " part files", 6)
    end
else
    sendNotif("Recon Done", "no writefile — report in F9 only", 6)
end

-- clipboard: briefing only (small), never the sources
if setclipboard then
    pcall(setclipboard, report)
    print("[Phantom] briefing copied to clipboard")
end

sendNotif("Phantom Recon", fp.verdict:sub(1, 40), 8)
print("[Phantom] RECON DROP COMPLETE")
