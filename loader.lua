--!nocheck
-- ==============================================================
--  PHANTOM SCANNER v16.1 — HEADLESS+ / ONE-BUTTON GUI
--  1 button (SCAN ALL), progress bar, live status.
--  Scans everything: scripts, remotes, players, NPCs, values,
--  prompts, spawns, sounds, animations. Single .txt export.
--  Verify: last line prints BUILD OK.
-- ==============================================================

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local HttpService        = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService       = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local unpack = table.unpack or unpack

-- ============== EXECUTOR FUNC RESOLUTION ==============

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
local newcclosure       = getExecFunc("newcclosure")
local getrawmetatable   = getExecFunc("getrawmetatable")
local setreadonly       = getExecFunc("setreadonly")
local getnamecallmethod = getExecFunc("getnamecallmethod")
local identifyexecutor  = getExecFunc("identifyexecutor")

-- ============== GAME IDENTITY ==============

local GameName = "UnknownGame"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name and info.Name ~= "" then GameName = info.Name end
end)

local PlaceId = game.PlaceId
local JobId = game.JobId

local executorInfo = "Unknown"
pcall(function()
    local n, v = identifyexecutor()
    executorInfo = tostring(n) .. (v and (" v" .. tostring(v)) or "")
end)

local function sanitizeFilename(str)
    return tostring(str):gsub("[^%w%-_]", "_"):sub(1, 60)
end

local safeGameName = sanitizeFilename(GameName)
local ROOT_FOLDER = "PhantomScanner"
local timestamp = os.time()
local EXPORT_PATH = ROOT_FOLDER .. "/" .. safeGameName .. "_" .. tostring(PlaceId) .. "_" .. tostring(timestamp) .. ".txt"

local function ensureFolder(path)
    if isfolder and makefolder then
        if not isfolder(path) then
            pcall(makefolder, path)
        end
    end
end

ensureFolder(ROOT_FOLDER)

-- ============== GUI ==============

local gui = Instance.new("ScreenGui")
gui.Name = "PhantomScanner_" .. tostring(math.random(1000, 9999))
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    gui.Parent = gethui and gethui() or game:GetService("CoreGui")
end)
if not gui.Parent then
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.new(0, 320, 0, 210)
frame.Position = UDim2.new(0.5, -160, 0.5, -105)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 60, 160)
stroke.Thickness = 1.5
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 30)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "PHANTOM v16.1"
title.TextColor3 = Color3.fromRGB(200, 180, 255)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -20, 0, 16)
subtitle.Position = UDim2.new(0, 10, 0, 34)
subtitle.BackgroundTransparency = 1
subtitle.Text = GameName
subtitle.TextColor3 = Color3.fromRGB(140, 140, 160)
subtitle.TextSize = 11
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextTruncate = Enum.TextTruncate.AtEnd
subtitle.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 58)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "idle — press SCAN ALL to begin"
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.Parent = frame

-- progress bar
local barBG = Instance.new("Frame")
barBG.Size = UDim2.new(1, -20, 0, 18)
barBG.Position = UDim2.new(0, 10, 0, 84)
barBG.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
barBG.BorderSizePixel = 0
barBG.Parent = frame

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 6)
barCorner.Parent = barBG

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(130, 90, 220)
barFill.BorderSizePixel = 0
barFill.Parent = barBG

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 6)
fillCorner.Parent = barFill

local pctLabel = Instance.new("TextLabel")
pctLabel.Size = UDim2.new(1, 0, 1, 0)
pctLabel.BackgroundTransparency = 1
pctLabel.Text = "0%"
pctLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
pctLabel.TextSize = 11
pctLabel.Font = Enum.Font.GothamBold
pctLabel.Parent = barBG

-- stats line (live counters)
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 34)
statsLabel.Position = UDim2.new(0, 10, 0, 108)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "scripts: 0 | remotes: 0 | npcs: 0\nplayers: 0 | values: 0 | items: 0"
statsLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
statsLabel.TextSize = 11
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Parent = frame

-- SCAN ALL button
local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(1, -20, 0, 38)
scanBtn.Position = UDim2.new(0, 10, 0, 152)
scanBtn.BackgroundColor3 = Color3.fromRGB(110, 70, 200)
scanBtn.Text = "SCAN ALL"
scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
scanBtn.TextSize = 15
scanBtn.Font = Enum.Font.GothamBold
scanBtn.AutoButtonColor = true
scanBtn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = scanBtn

-- minimize / close
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 12
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = frame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- ============== GUI HELPERS ==============

local function setStatus(text)
    statusLabel.Text = text
end

local function setProgress(pct)
    -- pct: 0-1
    pct = math.clamp(pct, 0, 1)
    barFill.Size = UDim2.new(pct, 0, 1, 0)
    pctLabel.Text = tostring(math.floor(pct * 100)) .. "%"
end

local function setStats(line)
    statsLabel.Text = line
end

local function flashButton(color, text)
    scanBtn.BackgroundColor3 = color
    scanBtn.Text = text
end

local function notifyResult(success, msg)
    -- small in-frame flash instead of external notify
    if success then
        flashButton(Color3.fromRGB(60, 180, 100), "DONE")
    else
        flashButton(Color3.fromRGB(200, 60, 60), "ERROR")
    end
    setStatus(msg)
    task.delay(4, function()
        flashButton(Color3.fromRGB(110, 70, 200), "SCAN ALL")
    end)
end

-- ============== CONFIG ==============

local CFG = {
    frameBudgetMS   = 8,
    maxInstances    = 1000000,
    decompRetries   = 2,
    decompWait      = 1,
    saveBytecode    = true,
    maxBytecodeDump = 20000,
    skipCharacters  = false, -- now we WANT player characters tracked
    maxSourceChars  = 500000,
}

-- ============== STATE ==============

local State = {
    results = {},
    hashes = {},
    remotes = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}},
    objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}, players = {}, tools = {}},
    assets  = {sounds = {}, animations = {}},
    acDetections = {},
    bdDetections = {},
    webhookHits = {},
    requireMap = {},
    stats = {
        total = 0, source = 0, bytecode = 0, needDecomp = 0, failed = 0, deduped = 0,
        instancesWalked = 0, containersFailed = 0
    },
    scanning = false
}

-- ============== WALK ENGINE ==============

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

local function buildStatsLine()
    return string.format(
        "scripts: %d | remotes: %d | npcs: %d\nplayers: %d | values: %d | items: %d",
        State.stats.total,
        #State.remotes.events + #State.remotes.functions,
        #State.objects.humanoids,
        #State.objects.players,
        #State.objects.values,
        #State.objects.tools
    )
end

local function unifiedWalk()
    State.results = {}
    State.hashes = {}
    State.remotes = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}}
    State.objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}, players = {}, tools = {}}
    State.assets  = {sounds = {}, animations = {}}
    State.stats.instancesWalked = 0
    State.stats.containersFailed = 0
    State.stats.total = 0

    local remoteHashes = {}
    local valueHashes = {}
    local objHashes = {}

    local budget = CFG.frameBudgetMS / 1000
    local frameStart = os.clock()

    local function maybeYield()
        if (os.clock() - frameStart) >= budget then
            RunService.RenderStepped:Wait()
            frameStart = os.clock()
            setStats(buildStatsLine())
        end
    end

    for _, container in ipairs(getContainers()) do
        if not State.scanning then break end
        local ok, err = pcall(function()
            local stack = {container}
            while #stack > 0 do
                if not State.scanning then return end
                if State.stats.instancesWalked >= CFG.maxInstances then
                    setStatus("instance cap reached — results valid")
                    return
                end

                local node = table.remove(stack)
                local gotKids, children = pcall(node.GetChildren, node)
                if not gotKids then
                    maybeYield()
                else
                    for _, inst in ipairs(children) do
                        State.stats.instancesWalked = State.stats.instancesWalked + 1
                        local cls = inst.ClassName

                        if cls == "LocalScript" or cls == "Script" or cls == "ModuleScript" then
                            table.insert(stack, inst)
                            local okPath, path = pcall(inst.GetFullName, inst)
                            if okPath then
                                local hash = quickHash(path .. "|" .. cls)
                                if State.hashes[hash] then
                                    State.stats.deduped = State.stats.deduped + 1
                                else
                                    State.hashes[hash] = true
                                    table.insert(State.results, {
                                        path = path,
                                        name = inst.Name,
                                        className = cls,
                                        inst = inst,
                                        source = "",
                                        bytecode = "",
                                        size = 0,
                                        status = "PENDING"
                                    })
                                    State.stats.total = #State.results
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

                        elseif cls == "Tool" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not objHashes[p] then
                                objHashes[p] = true
                                local tip = ""
                                pcall(function() tip = tostring(inst.ToolTip) end)
                                table.insert(State.objects.tools, {path = p, name = inst.Name, tip = tip})
                            end
                            table.insert(stack, inst)

                        elseif cls == "IntValue" or cls == "NumberValue" or cls == "StringValue"
                            or cls == "BoolValue" or cls == "ObjectValue" then
                            if not junkValueNames[inst.Name] then
                                local okP, p = pcall(inst.GetFullName, inst)
                                if okP and not valueHashes[p] then
                                    valueHashes[p] = true
                                    local entry = {path = p, class = cls}
                                    pcall(function() entry.val = tostring(inst.Value):sub(1, 120) end)
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
                            local plr = Players:GetPlayerFromCharacter(inst)
                            if plr then
                                -- player character tracked
                                local okP, p = pcall(inst.GetFullName, inst)
                                if okP and not objHashes[p] then
                                    objHashes[p] = true
                                    local hum = inst:FindFirstChildOfClass("Humanoid")
                                    local root = inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart
                                    local posStr = "?"
                                    if root then
                                        pcall(function()
                                            posStr = string.format("%.1f, %.1f, %.1f", root.Position.X, root.Position.Y, root.Position.Z)
                                        end)
                                    end
                                    table.insert(State.objects.players, {
                                        name = plr.Name,
                                        displayName = plr.DisplayName,
                                        userId = plr.UserId,
                                        path = p,
                                        hp = hum and hum.Health or 0,
                                        mhp = hum and hum.MaxHealth or 0,
                                        ws = hum and hum.WalkSpeed or 0,
                                        pos = posStr
                                    })
                                end
                            else
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

-- ============== SOURCE GRAB + DECOMPILE ==============

local function grabSources()
    State.stats.source = 0
    State.stats.bytecode = 0
    State.stats.needDecomp = 0
    State.stats.failed = 0

    local budget = CFG.frameBudgetMS / 1000
    local frameStart = os.clock()

    for i, r in ipairs(State.results) do
        if not State.scanning then break end
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
                    r.bytecode = bc
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

        setProgress(i / math.max(1, #State.results))
        setStatus("grabbing sources... " .. i .. "/" .. #State.results)

        if (os.clock() - frameStart) >= budget then
            RunService.RenderStepped:Wait()
            frameStart = os.clock()
        end
    end
end

local function decompileOne(entry)
    if not decompile then return false end
    local inst = entry.inst
    if not inst or not inst.Parent then return false end

    for _ = 1, CFG.decompRetries do
        local ok, r = pcall(decompile, inst)
        if ok and type(r) == "string" and #r > 0 then
            entry.source = r
            entry.size = #r
            entry.status = "SOURCE"
            entry.bytecode = ""
            State.stats.needDecomp = State.stats.needDecomp - 1
            State.stats.source = State.stats.source + 1
            return true
        end
    end
    return false
end

local function decompileAllRemaining()
    local targets = {}
    for _, r in ipairs(State.results) do
        if r.status == "NODECOMP" and r.inst and r.inst.Parent then
            table.insert(targets, r)
        end
    end

    if #targets == 0 then
        setStatus("decompile: nothing needed")
        return
    end

    local ok, fail = 0, 0
    for i, r in ipairs(targets) do
        if not State.scanning then break end
        local success = decompileOne(r)
        if success then
            ok = ok + 1
        else
            fail = fail + 1
            r.status = "FAILED"
            State.stats.failed = State.stats.failed + 1
        end

        setProgress(i / math.max(1, #targets))
        setStatus("decompiling... " .. i .. "/" .. #targets .. " (ok:" .. ok .. " fail:" .. fail .. ")")

        for _ = 1, CFG.decompWait do
            RunService.RenderStepped:Wait()
        end
    end
end

-- ============== SECURITY SCAN ==============

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
            local lines = {}
            for line in (r.source .. "\n"):gmatch("(.-)\n") do
                table.insert(lines, line)
            end
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
                    table.insert(State.requireMap, {script = r.path, target = arg:sub(1, 80)})
                end
            end
        end
        if si % 40 == 0 then
            RunService.RenderStepped:Wait()
        end
    end
end

-- ============== FINGERPRINT + GENRE ==============

local function detectGenre()
    local corpus = ""
    for _, e in ipairs(State.remotes.events) do corpus = corpus .. e.path:lower() .. " " end
    for _, f in ipairs(State.remotes.functions) do corpus = corpus .. f.path:lower() .. " " end
    for _, v in ipairs(State.objects.values) do corpus = corpus .. v.path:lower() .. " " end

    local function countAll(keywords)
        local total = 0
        for _, kw in ipairs(keywords) do
            local _, c = corpus:gsub(kw, "")
            total = total + c
        end
        return total
    end

    local genres = {
        {name = "Tycoon / Simulator", kws = {"tycoon", "dropper", "collector", "rebirth", "prestige", "autofarm", "upgrade", "factory", "cash", "income", "plot"},
            advice = {"currency/income remotes are the target — find the collect/claim pattern", "rebirth/upgrade remotes often have thin validation in sims", "auto-farm = loop the collect remote with observed cooldown"}},
        {name = "Tower / Obby", kws = {"obby", "stage", "checkpoint", "tower", "parkour", "killbrick", "jumps", "floor"},
            advice = {"checkpoint remotes = whole exploit surface — skip-to-stage is classic", "killbricks client-editable visually — walk through locally", "stage values replicated = check values for stage number"}},
        {name = "Horror / Survival", kws = {"monster", "jumpscare", "night", "survive", "hide", "escape", "spawnmonster", "chase", "scary", "demon"},
            advice = {"monster AI server-side but paths/values may replicate — check values", "ESP on monsters is main weapon — highlights through walls", "door/escape remotes usually validate items — deep scan unlock sequence"}},
        {name = "Shooter / Fighting", kws = {"gun", "shoot", "damage", "bullet", "weapon", "reload", "ammo", "health", "kill", "hit", "sword", "attack", "combat"},
            advice = {"hit/damage remotes ALWAYS validated in shooters — never forge", "weapon data (fire rate, spread) often client-side = visual mods work", "ESP + name tags are the safe surface"}},
        {name = "Roleplay / Social", kws = {"house", "furniture", "job", "work", "roleplay", "adopt", "family", "money", "buy", "shop", "vehicle", "car", "eat", "perk", "skin"},
            advice = {"job/work remotes replicate real actions — TP farming through the actual loop is safest", "vehicle remotes often accept simple args — test on alt", "furniture/building placement remotes usually validate ownership"}},
        {name = "Racing / Vehicle", kws = {"car", "vehicle", "race", "speed", "drive", "engine", "wheel", "crush", "drift", "chassis", "seat"},
            advice = {"vehicle physics often client-predicted = speed/handling mods work visually", "race checkpoint remotes can be distance-validated — check traffic gaps", "vehicle stats replicated as values = database browsing is free intel"}},
        {name = "Clicker / Incremental", kws = {"click", "tap", "mult", "multiplier", "pet", "egg", "hatch", "clicks", "cps", "energy"},
            advice = {"click remotes are the core loop — capture natural click rate, match it", "pet hatch remotes usually validate currency server-side", "multiplier values client-visible = check for writable boosts"}},
        {name = "Social Hangout", kws = {"emote", "music", "boombox", "radio", "avatar", "vip", "social", "chat", "dance"},
            advice = {"mostly client-visual surface — emotes, music, avatar mods", "few exploit targets; genre is about cosmetic freedom", "boombox/music remotes sometimes accept any id — test on alt"}},
    }

    local best, bestScore = nil, 0
    for _, g in ipairs(genres) do
        local sig = countAll(g.kws)
        if sig > bestScore then
            best = g
            bestScore = sig
        end
    end

    if best and bestScore >= 3 then
        return {
            name = best.name,
            confidence = math.min(95, 40 + bestScore * 2),
            advice = best.advice
        }
    end

    return {
        name = "Unclassified / Hybrid",
        confidence = 30,
        advice = {"no strong genre signature — rely on tier fingerprint", "run traffic capture during normal play to discover the loop"}
    }
end

local function analyzeFingerprint()
    local fp = {
        tier = "TIER 1", tierName = "client-authoritative", confidence = 75,
        signals = {}, risks = {}, recommendations = {},
        clientAuthSignals = 0, serverAuthSignals = 0, obfuscationScore = 0, stateCount = 0
    }

    local statePatterns = {"cash", "coin", "money", "gem", "token", "point", "score", "level", "xp", "health", "ammo", "inventory", "gold", "credit", "wins", "currency"}
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
        table.insert(fp.risks, "SERVER-SIDE ACTION VALIDATION DETECTED — economy remotes fingerprinted")
    end

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

    local total = State.stats.source + State.stats.bytecode + State.stats.needDecomp + State.stats.failed
    local srcRatio = total > 0 and (State.stats.source / total) or 0

    if srcRatio > 0.7 then
        fp.clientAuthSignals = fp.clientAuthSignals + 2
        table.insert(fp.signals, string.format("high source visibility (%.0f%% readable)", srcRatio * 100))
    elseif srcRatio < 0.3 and total > 0 then
        fp.serverAuthSignals = fp.serverAuthSignals + 3
        table.insert(fp.signals, string.format("low source visibility (%.0f%% readable)", srcRatio * 100))
        if stateCount > 20 then
            table.insert(fp.risks, "game-state values are DISPLAY-ONLY (server ledger) — client edits won't persist")
            fp.clientAuthSignals = fp.clientAuthSignals - 2
        end
    end

    if stateCount > 20 and srcRatio >= 0.3 then
        fp.clientAuthSignals = fp.clientAuthSignals + 2
        table.insert(fp.signals, stateCount .. " game-state values client-visible — likely writable")
        table.insert(fp.recommendations, "check values for currency/inventory — try editing")
    end

    if #State.webhookHits > 0 then
        table.insert(fp.risks, "GAME LOGS TO DISCORD WEBHOOKS — actions may be reported live")
        fp.serverAuthSignals = fp.serverAuthSignals + 1
    end

    if #State.acDetections > 10 then
        fp.serverAuthSignals = fp.serverAuthSignals + 1
        table.insert(fp.signals, #State.acDetections .. " anti-cheat lines in source")
    end

    local score = fp.serverAuthSignals - fp.clientAuthSignals
    if score >= 4 then
        fp.tier, fp.tierName, fp.confidence = "TIER 3", "server-auth + hardened", 85
        table.insert(fp.recommendations, "SAFE: TPs, ESP, fullbright, replicated-data browsers")
        table.insert(fp.recommendations, "AVOID: economy/damage remotes — validation + ban teams")
    elseif score >= 1 then
        fp.tier, fp.tierName, fp.confidence = "TIER 2", "hybrid validation", 70
        table.insert(fp.recommendations, "SAFE: movement, ESP, TPs, prompt automation")
        table.insert(fp.recommendations, "TEST-ON-ALT: any remote that spends/moves/creates")
    else
        fp.tier, fp.tierName, fp.confidence = "TIER 1", "client-authoritative", 75
        table.insert(fp.recommendations, "FULL SURFACE: value edits, remote firing, auto-farm")
    end

    if fp.obfuscationScore >= 2 and fp.tier == "TIER 1" then
        fp.tier, fp.confidence = "TIER 2", 60
        table.insert(fp.risks, "downgraded to tier 2 — obfuscation despite visible sources")
    end

    return fp
end

-- ============== EXPORT BUILDER ==============

local function fmtNPC(n)
    local posStr = "?"
    if n.px then
        posStr = string.format("%.1f, %.1f, %.1f", n.px, n.py, n.pz)
    end
    return string.format("%s | HP:%s/%s WS:%s | %s @ %s",
        n.name, tostring(n.hp), tostring(n.mhp), tostring(n.ws), n.path, posStr)
end

local function fmtPlayer(p)
    return string.format("%s (%s) | UserID:%d | HP:%s/%s WS:%s | %s @ %s",
        p.name, p.displayName, p.userId, tostring(p.hp), tostring(p.mhp), tostring(p.ws), p.path, p.pos)
end

local function buildExport(fp, genre)
    local buf = {}
    local function add(t) buf[#buf + 1] = t end

    add("==========================================")
    add("  PHANTOM SCANNER v16.1 EXPORT")
    add("==========================================")
    add("Game: " .. GameName)
    add("Place ID: " .. tostring(PlaceId))
    add("Job ID: " .. tostring(JobId))
    add("Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    add("Executor: " .. executorInfo)
    add("Instances Walked: " .. State.stats.instancesWalked)
    add("Containers Failed: " .. State.stats.containersFailed)
    add("")

    add("==================================================")
    add("  PHANTOM v16.1 — BRIEFING")
    add("==================================================")
    add("TIER: " .. fp.tier .. " — " .. fp.tierName .. " (" .. fp.confidence .. "% confidence)")
    add("GENRE: " .. genre.name .. " (" .. genre.confidence .. "% confidence)")
    add("")
    add("-- TIER SIGNALS --")
    if #fp.signals > 0 then
        for _, s in ipairs(fp.signals) do add("  * " .. s) end
    else
        add("  (none)")
    end
    add("")
    add("-- RISKS --")
    if #fp.risks > 0 then
        for _, r in ipairs(fp.risks) do add("  ! " .. r) end
    else
        add("  none flagged")
    end
    add("")
    add("-- TIER APPROACH --")
    for _, rec in ipairs(fp.recommendations) do add("  > " .. rec) end
    add("")
    add("-- GENRE-SPECIFIC PLAYS --")
    for _, a in ipairs(genre.advice) do add("  + " .. a) end
    add("")
    add("-- NUMBERS --")
    add("  Scripts: " .. State.stats.total .. " | src:" .. State.stats.source .. " bc:" .. State.stats.bytecode .. " need:" .. State.stats.needDecomp .. " fail:" .. State.stats.failed)
    add("  Remotes: " .. #State.remotes.events .. "E / " .. #State.remotes.functions .. "F | Bindables: " .. #State.remotes.bindables .. "E / " .. #State.remotes.bindableFuncs .. "F")
    add("  Players: " .. #State.objects.players .. " | NPCs: " .. #State.objects.humanoids)
    add("  Values: " .. #State.objects.values .. " (game-state: " .. fp.stateCount .. ")")
    add("  Items/Tools: " .. #State.objects.tools .. " | Prompts: " .. #State.objects.prompts .. " | Spawns: " .. #State.objects.spawns)
    add("")

    add("========= STRUCTURE MAP =========")
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
    table.sort(sorted, function(a, b) return (a.events + a.funcs) > (b.events + b.funcs) end)
    add("REMOTE SUB-SYSTEMS:")
    for i, s in ipairs(sorted) do
        if i > 40 then add("  ...+" .. (#sorted - 40) .. " more") break end
        add(string.format("  [%dE/%dF] %s", s.events, s.funcs, s.name))
    end
    add("")

    add("========== SECURITY ==========")
    add("--- Anti-Cheat Patterns (" .. #State.acDetections .. ") ---")
    for i, d in ipairs(State.acDetections) do
        if i > 100 then add("  ...+" .. (#State.acDetections - 100) .. " more") break end
        add("  " .. d.script .. " [line " .. d.line .. "] (" .. d.pattern .. "): " .. d.text)
    end
    add("")
    add("--- Backdoor / Loadstring Patterns (" .. #State.bdDetections .. ") ---")
    for i, d in ipairs(State.bdDetections) do
        if i > 100 then add("  ...+" .. (#State.bdDetections - 100) .. " more") break end
        add("  " .. d.script .. " [line " .. d.line .. "] (" .. d.pattern .. "): " .. d.text)
    end
    add("")
    add("--- Webhooks (" .. #State.webhookHits .. ") ---")
    for i, d in ipairs(State.webhookHits) do
        if i > 50 then add("  ...+" .. (#State.webhookHits - 50) .. " more") break end
        add("  " .. d.script .. " [line " .. d.line .. "]: " .. d.text)
    end
    add("")
    add("--- Require Map (" .. #State.requireMap .. ") ---")
    for i, d in ipairs(State.requireMap) do
        if i > 100 then add("  ...+") break end
        add("  " .. d.script .. " -> " .. d.target)
    end
    add("")

    add("========== PLAYERS ==========")
    add("--- Players (" .. #State.objects.players .. ") ---")
    for _, p in ipairs(State.objects.players) do add(fmtPlayer(p)) end
    add("")

    add("========== REMOTES ==========")
    add("--- RemoteEvents (" .. #State.remotes.events .. ") ---")
    for _, e in ipairs(State.remotes.events) do add(e.path) end
    add("")
    add("--- RemoteFunctions (" .. #State.remotes.functions .. ") ---")
    for _, f in ipairs(State.remotes.functions) do add(f.path) end
    add("")
    add("--- BindableEvents (" .. #State.remotes.bindables .. ") ---")
    for _, b in ipairs(State.remotes.bindables) do add(b.path) end
    add("")
    add("--- BindableFunctions (" .. #State.remotes.bindableFuncs .. ") ---")
    for _, b in ipairs(State.remotes.bindableFuncs) do add(b.path) end
    add("")

    add("========== OBJECTS ==========")
    add("--- ProximityPrompts (" .. #State.objects.prompts .. ") ---")
    for _, p in ipairs(State.objects.prompts) do add(p.path) end
    add("")
    add("--- ClickDetectors (" .. #State.objects.clickDetectors .. ") ---")
    for _, c in ipairs(State.objects.clickDetectors) do add(c.path) end
    add("")
    add("--- NPCs (" .. #State.objects.humanoids .. ") ---")
    for _, n in ipairs(State.objects.humanoids) do add(fmtNPC(n)) end
    add("")
    add("--- Items/Tools (" .. #State.objects.tools .. ") ---")
    for _, t in ipairs(State.objects.tools) do
        add(t.path .. (t.tip ~= "" and (" | tooltip: " .. t.tip) or ""))
    end
    add("")
    add("--- SpawnLocations (" .. #State.objects.spawns .. ") ---")
    for _, s in ipairs(State.objects.spawns) do add(s.path .. " @ " .. s.pos) end
    add("")
    add("--- Values (" .. #State.objects.values .. ") ---")
    for _, v in ipairs(State.objects.values) do
        add("[" .. v.class .. "] " .. v.path .. " = " .. tostring(v.val or "?"))
    end
    add("")

    add("========== ASSETS ==========")
    add("--- Sounds (" .. #State.assets.sounds .. ") ---")
    for _, s in ipairs(State.assets.sounds) do add(s.path .. " | " .. s.id) end
    add("")
    add("--- Animations (" .. #State.assets.animations .. ") ---")
    for _, a in ipairs(State.assets.animations) do add(a.path .. " | " .. a.id) end
    add("")

    add("========== SCRIPT SOURCES ==========")
    add("Total: " .. State.stats.total .. " scripts | SOURCE:" .. State.stats.source .. " BYTECODE:" .. State.stats.bytecode .. " FAILED:" .. State.stats.failed)
    add("")
    for i, r in ipairs(State.results) do
        add("--------------------------------------------------")
        add("[" .. i .. "/" .. State.stats.total .. "] " .. r.className .. " | " .. r.path)
        add("STATUS: " .. r.status .. " | SIZE: " .. r.size)
        add("--------------------------------------------------")
        if r.status == "SOURCE" and #r.source > 0 then
            local src = r.source
            if #src > CFG.maxSourceChars then
                src = src:sub(1, CFG.maxSourceChars) .. "\n-- [TRUNCATED at " .. CFG.maxSourceChars .. " chars — full size: " .. #r.source .. "]"
            end
            add(src)
        elseif r.status == "BYTECODE" and CFG.saveBytecode and #r.bytecode > 0 then
            local bc = r.bytecode
            if #bc > CFG.maxBytecodeDump then
                bc = bc:sub(1, CFG.maxBytecodeDump) .. "\n-- [BYTECODE TRUNCATED at " .. CFG.maxBytecodeDump .. " chars — full size: " .. #r.bytecode .. "]"
            end
            add("-- BYTECODE (decompile failed — raw dump):")
            add(bc)
        elseif r.status == "FAILED" then
            add("-- decompile failed (server-only or VM-packed)")
        elseif r.status == "GONE" then
            add("-- script destroyed before capture")
        else
            add("-- no data")
        end
        add("")
        if i % 20 == 0 then
            RunService.RenderStepped:Wait()
        end
    end

    add("==========================================")
    add("  END OF EXPORT — PHANTOM v16.1")
    add("==========================================")

    return table.concat(buf, "\n")
end

-- ============== WRITE EXPORT ==============

local function writeExport(content)
    local ok = pcall(function()
        writefile(EXPORT_PATH, content)
    end)
    if ok then
        return true, math.floor(#content / 1024)
    end

    -- fallback: compact index
    print("[Phantom] full write failed — retrying compact export")
    local compact = {}
    compact[#compact + 1] = "PHANTOM v16.1 COMPACT EXPORT (full write failed)"
    compact[#compact + 1] = "Game: " .. GameName .. " | Place: " .. tostring(PlaceId)
    for _, r in ipairs(State.results) do
        compact[#compact + 1] = r.className .. " | " .. r.status .. " | " .. r.path
    end
    local ok2 = pcall(function()
        writefile(EXPORT_PATH, table.concat(compact, "\n"))
    end)
    if ok2 then
        return true, math.floor(#table.concat(compact, "\n") / 1024)
    end
    return false, 0
end

-- ============== MAIN SCAN RUNNER ==============

local function runFullScan()
    if State.scanning then return end
    State.scanning = true
    scanBtn.AutoButtonColor = false

    setProgress(0)
    setStatus("starting scan...")
    setStats("scripts: 0 | remotes: 0 | npcs: 0\nplayers: 0 | values: 0 | items: 0")

    task.spawn(function()
        local scanStart = os.clock()
        local success, errMsg = pcall(function()
            -- PHASE 1: walk
            setStatus("walking instances...")
            unifiedWalk()
            setProgress(0.25)

            -- PHASE 2: grab sources
            setStatus("grabbing sources...")
            grabSources()
            setProgress(0.5)

            -- PHASE 3: decompile
            decompileAllRemaining()
            setProgress(0.7)

            -- PHASE 4: security
            setStatus("scanning security patterns...")
            scanSecurity()
            setProgress(0.8)

            -- PHASE 5: analysis
            setStatus("analyzing fingerprint...")
            local genre = detectGenre()
            local fp = analyzeFingerprint()
            setProgress(0.9)

            -- PHASE 6: export
            setStatus("building export file...")
            local export = buildExport(fp, genre)
            local written, kb = writeExport(export)
            setProgress(1)

            local dur = string.format("%.1fs", os.clock() - scanStart)

            if written then
                notifyResult(true, "DONE in " .. dur .. " — " .. kb .. " KB saved")
                print("==============================================")
                print("  PHANTOM v16.1 SCAN COMPLETE")
                print("  Output: " .. EXPORT_PATH)
                print("  Scripts: " .. State.stats.total .. " | src:" .. State.stats.source .. " | bc:" .. State.stats.bytecode .. " | fail:" .. State.stats.failed)
                print("  Tier: " .. fp.tier .. " | Genre: " .. genre.name)
                print("==============================================")
                print("BUILD OK")
            else
                notifyResult(false, "scan done but write failed — check executor storage")
            end
        end)

        if not success then
            notifyResult(false, "scan error: " .. tostring(errMsg))
            warn("[Phantom] scan error: " .. tostring(errMsg))
        end

        State.scanning = false
        scanBtn.AutoButtonColor = true
    end)
end

scanBtn.MouseButton1Click:Connect(runFullScan)

print("[Phantom v16.1] loaded — GUI ready")
print("[Phantom v16.1] Game: " .. GameName .. " | Place: " .. tostring(PlaceId))
print("BUILD OK")
