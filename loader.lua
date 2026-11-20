--!nocheck
-- ==============================================================
--  PHANTOM SCANNER v18.1 — FULL GAME COVERAGE + ANTI-FREEZE
--  UI: Rayfield (primary) → inline fallback
--  New: CoreGui/CorePackages/Backpack walk, getscripts()/
--       getloadedModules()/getrunningScripts() discovery,
--       script type classification (Script/LocalScript/
--       ModuleScript/CoreScript/Dynamic), no export cap.
-- ==============================================================

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local HttpService        = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

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
local setclipboard      = getExecFunc("setclipboard")
local identifyexecutor  = getExecFunc("identifyexecutor")
local hookmetamethod    = getExecFunc("hookmetamethod")
local getrawmetatable   = getExecFunc("getrawmetatable")
local setreadonly       = getExecFunc("setreadonly")
local getnamecallmethod = getExecFunc("getnamecallmethod")
-- NEW v18: script discovery functions
local getscripts        = getExecFunc("getscripts")
local getloadedModules  = getExecFunc("getloadedModules")
local getrunningScripts = getExecFunc("getrunningScripts")

if not writefile then warn("[Phantom v18] CRITICAL: writefile not available. Cannot save.") end

-- ============== GAME IDENTITY ==============

local GameName = "UnknownGame"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name and info.Name ~= "" then GameName = info.Name end
end)

local PlaceId = game.PlaceId

local executorInfo = "Unknown"
pcall(function()
    local n, v = identifyexecutor()
    executorInfo = tostring(n) .. (v and (" v" .. tostring(v)) or "")
end)

local function sanitizeFilename(str)
    return tostring(str):gsub("[^%w%-_]", "_"):sub(1, 50)
end

local safeGameName = sanitizeFilename(GameName)
local timestamp = os.time()
local EXPORT_FILENAME = safeGameName .. "_" .. tostring(PlaceId) .. ".txt"

-- ============== SAVE HELPERS ==============

local SAVED_PATH = nil

local function attemptSave(content)
    if not writefile then return nil end
    local ok, err = pcall(function() writefile(EXPORT_FILENAME, content) end)
    if ok then
        print("[Phantom SAVE] OK: " .. EXPORT_FILENAME)
        return EXPORT_FILENAME
    end
    print("[Phantom SAVE] direct write failed: " .. tostring(err))
    local retryName = safeGameName .. "_" .. tostring(PlaceId) .. "_" .. tostring(timestamp) .. ".txt"
    local ok2 = pcall(function() writefile(retryName, content) end)
    if ok2 then
        print("[Phantom SAVE] OK (retry): " .. retryName)
        return retryName
    end
    local shortName = "phantom_" .. tostring(timestamp) .. ".txt"
    local ok3 = pcall(function() writefile(shortName, content) end)
    if ok3 then
        print("[Phantom SAVE] OK (short): " .. shortName)
        return shortName
    end
    print("[Phantom SAVE] ALL ATTEMPTS FAILED")
    return nil
end

-- ============== UI LIB: Rayfield ONLY → inline fallback ==============
-- Kai's standing instruction: Rayfield only, no WindUI

local UI
local usingLib = "unknown"

local rayfieldUrls = {
    "https://raw.githubusercontent.com/Dawid-scripts/Rayfield/main/source",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
    "https://raw.githubusercontent.com/EazyAD/Rayfield/main/source",
    "https://pastebin.com/raw/BtmqPqQ0",
    "https://raw.githubusercontent.com/iRayfield/Rayfield/main/source",
}
for _, url in ipairs(rayfieldUrls) do
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if ok and src and #src > 1000 and src:find("CreateWindow", 1, true) then
        local ok2, lib = pcall(function() return loadstring(src)() end)
        if ok2 and lib and lib.CreateWindow then
            UI = lib
            usingLib = "rayfield"
            print("[Phantom UI] Rayfield loaded from " .. url)
            break
        end
    end
end

-- No WindUI — Kai said Rayfield only. Straight to inline if Rayfield fails.

-- Normalize API across all three backends
if usingLib == "rayfield" then
    -- Rayfield: CreateWindow -> MakeWindow, CreateTab -> MakeTab
    -- No native Description field — use CreateParagraph above each element
    local Rayfield = UI
    local Shim = {}
    function Shim:MakeWindow(opts)
        local w = Rayfield:CreateWindow({
            Name = opts.Title,
            LoadingTitle = opts.Title,
            LoadingSubtitle = opts.Author or "SMITH",
            ConfigurationSaving = { Enabled = false },
            KeySystem = false,
        })
        function w:MakeTab(tOpts)
            local tab = Rayfield:CreateTab(tOpts.Title, tOpts.Icon)
            -- wrap each Create method to normalize names
            local wrapped = {}
            function wrapped:AddParagraph(pOpts)
                Rayfield:CreateParagraph({ Title = pOpts.Title or "", Content = pOpts.Description or "" })
            end
            function wrapped:AddSection(sOpts)
                if sOpts.Description and sOpts.Description ~= "" then
                    Rayfield:CreateParagraph({ Title = sOpts.Title or "", Content = sOpts.Description })
                else
                    Rayfield:CreateSection(sOpts.Title or "")
                end
            end
            function wrapped:AddButton(bOpts)
                if bOpts.Description and bOpts.Description ~= "" then
                    Rayfield:CreateParagraph({ Title = "", Content = bOpts.Description })
                end
                Rayfield:CreateButton({ Name = bOpts.Title, Callback = bOpts.Callback })
            end
            function wrapped:AddToggle(tOpts)
                if tOpts.Description and tOpts.Description ~= "" then
                    Rayfield:CreateParagraph({ Title = "", Content = tOpts.Description })
                end
                Rayfield:CreateToggle({ Name = tOpts.Title, CurrentValue = tOpts.Default or false, Callback = tOpts.Callback })
            end
            function wrapped:AddSlider(sOpts)
                if sOpts.Description and sOpts.Description ~= "" then
                    Rayfield:CreateParagraph({ Title = "", Content = sOpts.Description })
                end
                Rayfield:CreateSlider({
                    Name = sOpts.Title,
                    Range = { sOpts.Min, sOpts.Max },
                    Increment = 1,
                    Suffix = "",
                    CurrentValue = sOpts.Default,
                    Callback = sOpts.Callback,
                })
            end
            function wrapped:AddDropdown(dOpts)
                if dOpts.Description and dOpts.Description ~= "" then
                    Rayfield:CreateParagraph({ Title = "", Content = dOpts.Description })
                end
                local dd = Rayfield:CreateDropdown({
                    Name = dOpts.Title,
                    Options = dOpts.Values or {},
                    CurrentOption = dOpts.Default or (dOpts.Values and dOpts.Values[1]) or "",
                    Callback = dOpts.Callback,
                })
                return dd
            end
            function wrapped:AddInput(iOpts)
                if iOpts.Description and iOpts.Description ~= "" then
                    Rayfield:CreateParagraph({ Title = "", Content = iOpts.Description })
                end
                Rayfield:CreateInput({
                    Name = iOpts.Title,
                    PlaceholderText = iOpts.Placeholder or "",
                    Callback = iOpts.Callback,
                })
            end
            return wrapped
        end
        return w
    end
    function Shim:Notify(nOpts)
        Rayfield:Notify({ Title = nOpts.Title, Content = nOpts.Content, Duration = nOpts.Time or 4 })
    end
    function Shim:Init() end
    function Shim:Destroy()
        pcall(function() Rayfield:Destroy() end)
    end
    UI = Shim

else
    -- Inline fallback UI (API-compatible)
    warn("[Phantom UI] Rayfield unreachable — building inline fallback")
    usingLib = "inline"
    local UserInputService = game:GetService("UserInputService")
    local parentTarget
    pcall(function() parentTarget = game:GetService("CoreGui") end)
    if not parentTarget then parentTarget = LocalPlayer:WaitForChild("PlayerGui") end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Phantom_v18"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 9999
    screenGui.Parent = parentTarget

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 560, 0, 480)
    mainFrame.Position = UDim2.new(0, 20, 0, 20)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0, 8) c1.Parent = mainFrame

    local titleBar = Instance.new("TextLabel")
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    titleBar.TextColor3 = Color3.fromRGB(220, 200, 255)
    titleBar.Font = Enum.Font.SourceSansBold
    titleBar.TextSize = 15
    titleBar.Text = "  Phantom Scanner v18 (fallback)"
    titleBar.TextXAlignment = Enum.TextXAlignment.Left
    titleBar.Parent = mainFrame

    local tabBar = Instance.new("Frame")
    tabBar.Position = UDim2.new(0, 0, 0, 32)
    tabBar.Size = UDim2.new(1, 0, 0, 28)
    tabBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame
    local tcl = Instance.new("UIListLayout")
    tcl.FillDirection = Enum.FillDirection.Horizontal
    tcl.Padding = UDim.new(0, 2)
    tcl.Parent = tabBar

    local content = Instance.new("ScrollingFrame")
    content.Position = UDim2.new(0, 8, 0, 68)
    content.Size = UDim2.new(1, -16, 1, -76)
    content.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 4
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.Parent = mainFrame

    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local tabs = {}
    local tabButtons = {}
    local function showTab(name)
        for _, t in ipairs(tabs) do t.frame.Visible = (t.name == name) end
        for _, b in ipairs(tabButtons) do
            b.BackgroundColor3 = (b.Name == name) and Color3.fromRGB(70, 90, 130) or Color3.fromRGB(35, 35, 42)
        end
    end

    local function makeControl(parent, h)
        local f = Instance.new("TextButton")
        f.Size = UDim2.new(1, 0, 0, h or 28)
        f.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
        f.TextColor3 = Color3.fromRGB(245, 245, 250)
        f.Font = Enum.Font.SourceSans
        f.TextSize = 13
        f.AutoButtonColor = true
        f.Parent = parent
        local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 4) cc.Parent = f
        return f
    end

    local function makeDescLabel(parent, text)
        if not text or text == "" then return end
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 16)
        l.BackgroundTransparency = 1
        l.TextColor3 = Color3.fromRGB(140, 140, 160)
        l.Font = Enum.Font.SourceSansItalic
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = "  " .. text
        l.Parent = parent
    end

    local Shim = {}
    function Shim:MakeWindow(opts)
        local window = {}
        function window:MakeTab(tOpts)
            local tab = { name = tOpts.Title }
            local tb = Instance.new("TextButton")
            tb.Name = tOpts.Title
            tb.Size = UDim2.new(0, 85, 1, 0)
            tb.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
            tb.TextColor3 = Color3.fromRGB(220, 220, 230)
            tb.Font = Enum.Font.SourceSans
            tb.TextSize = 12
            tb.Text = tOpts.Title
            tb.Parent = tabBar
            tb.MouseButton1Click:Connect(function() showTab(tOpts.Title) end)
            table.insert(tabButtons, tb)
            local tf = Instance.new("Frame")
            tf.Size = UDim2.new(1, 0, 1, 0)
            tf.BackgroundTransparency = 1
            tf.Visible = false
            tf.Parent = content
            local tfl = Instance.new("UIListLayout")
            tfl.Padding = UDim.new(0, 4)
            tfl.Parent = tf
            tab.frame = tf

            function tab:AddParagraph(pOpts)
                local p = Instance.new("TextLabel")
                p.Size = UDim2.new(1, 0, 0, 32)
                p.BackgroundTransparency = 1
                p.TextColor3 = Color3.fromRGB(200, 200, 220)
                p.Font = Enum.Font.SourceSans
                p.TextSize = 12
                p.TextXAlignment = Enum.TextXAlignment.Left
                p.TextYAlignment = Enum.TextYAlignment.Top
                p.TextWrapped = true
                p.Text = (pOpts.Title or "") .. (pOpts.Description and (": " .. pOpts.Description) or "")
                p.Parent = tf
            end

            function tab:AddSection(sOpts)
                makeDescLabel(tf, sOpts.Description)
                local s = Instance.new("TextLabel")
                s.Size = UDim2.new(1, 0, 0, 22)
                s.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
                s.TextColor3 = Color3.fromRGB(255, 200, 100)
                s.Font = Enum.Font.SourceSansBold
                s.TextSize = 13
                s.TextXAlignment = Enum.TextXAlignment.Left
                s.Text = "  " .. (sOpts.Title or "")
                s.Parent = tf
            end

            function tab:AddButton(bOpts)
                makeDescLabel(tf, bOpts.Description)
                local b = makeControl(tf, 28)
                b.Text = bOpts.Title
                b.MouseButton1Click:Connect(function() bOpts.Callback() end)
            end

            function tab:AddToggle(tOpts)
                makeDescLabel(tf, tOpts.Description)
                local state = tOpts.Default or false
                local b = makeControl(tf, 28)
                local function refresh()
                    b.Text = tOpts.Title .. ": " .. (state and "ON" or "OFF")
                    b.BackgroundColor3 = state and Color3.fromRGB(40, 100, 60) or Color3.fromRGB(38, 38, 46)
                end
                refresh()
                b.MouseButton1Click:Connect(function()
                    state = not state
                    refresh()
                    tOpts.Callback(state)
                end)
            end

            function tab:AddSlider(sOpts)
                makeDescLabel(tf, sOpts.Description)
                local vals = {}
                local step = (sOpts.Max - sOpts.Min) / 10
                for i = 0, 10 do
                    table.insert(vals, math.floor(sOpts.Min + step * i))
                end
                local idx = 1
                for i, v in ipairs(vals) do
                    if v == sOpts.Default then
                        idx = i
                        break
                    end
                end
                local b = makeControl(tf, 28)
                local function refresh()
                    b.Text = sOpts.Title .. ": " .. tostring(vals[idx])
                end
                refresh()
                b.MouseButton1Click:Connect(function()
                    idx = idx % #vals + 1
                    refresh()
                    sOpts.Callback(vals[idx])
                end)
            end

            function tab:AddDropdown(dOpts)
                makeDescLabel(tf, dOpts.Description)
                local optsList = dOpts.Values or {}
                local sel = dOpts.Default or optsList[1]
                local b = makeControl(tf, 28)
                local function refresh()
                    b.Text = (dOpts.Title or "") .. ": " .. tostring(sel):sub(1, 40)
                end
                refresh()
                b.MouseButton1Click:Connect(function()
                    local i = table.find(optsList, sel) or 0
                    i = i % #optsList + 1
                    sel = optsList[i]
                    refresh()
                    dOpts.Callback(sel)
                end)
            end

            function tab:AddInput(iOpts)
                makeDescLabel(tf, iOpts.Description)
                local box = Instance.new("TextBox")
                box.Size = UDim2.new(1, 0, 0, 28)
                box.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
                box.TextColor3 = Color3.fromRGB(245, 245, 250)
                box.Font = Enum.Font.SourceSans
                box.TextSize = 13
                box.PlaceholderText = iOpts.Placeholder or ""
                box.Text = iOpts.Default or ""
                box.Parent = tf
                local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 4) cc.Parent = box
                box.FocusLost:Connect(function() iOpts.Callback(box.Text) end)
            end

            table.insert(tabs, tab)
            if #tabs == 1 then showTab(tab.name) end
            return tab
        end
        return window
    end

    function Shim:Notify(nOpts)
        local notif = Instance.new("Frame")
        notif.Size = UDim2.new(0, 240, 0, 50)
        notif.Position = UDim2.new(1, -260, 1, -70)
        notif.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        notif.Parent = screenGui
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = notif
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -12, 0, 18)
        t.Position = UDim2.new(0, 6, 0, 4)
        t.BackgroundTransparency = 1
        t.TextColor3 = Color3.fromRGB(255, 200, 100)
        t.Font = Enum.Font.SourceSansBold
        t.TextSize = 14
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Text = nOpts.Title or ""
        t.Parent = notif
        local b = Instance.new("TextLabel")
        b.Size = UDim2.new(1, -12, 0, 24)
        b.Position = UDim2.new(0, 6, 0, 22)
        b.BackgroundTransparency = 1
        b.TextColor3 = Color3.fromRGB(220, 220, 220)
        b.Font = Enum.Font.SourceSans
        b.TextSize = 12
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.TextWrapped = true
        b.Text = nOpts.Content or ""
        b.Parent = notif
        task.delay(nOpts.Time or 4, function() notif:Destroy() end)
    end

    function Shim:Init() end
    function Shim:Destroy() pcall(function() screenGui:Destroy() end) end
    UI = Shim
end

-- ============== CONFIG (mutable from Settings tab) ==============

local CFG = {
    frameBudgetMS   = 8,
    maxInstances    = 5000000,  -- v18: raised from 1M to 5M
    decompRetries   = 2,
    decompWait      = 1,
    saveBytecode    = true,
    maxBytecodeDump = 50000,    -- v18: raised from 20k
    skipCharacters  = false,
    maxSourceChars  = 500000,   -- v18: raised from 300k
    scanCoreGui     = true,     -- v18: new — walk CoreGui/CorePackages
    scanBackpack    = true,     -- v18: new — walk player backpack tools
    useExecDiscovery = true,    -- v18: new — use getscripts/getloadedModules/getrunningScripts
    yieldChunk       = 10,      -- v18.2: lowered from 25 to 10 (stronger anti-freeze)
    maxScripts      = 0,       -- v18.1: 0 = no limit, set N to cap script count
    skipWorkspace   = false,   -- v18.2: skip Workspace descent (for massive games like CC2)
    wsDepthLimit     = 5,       -- v18.2: default 5 — catches scripts in Workspace.Folder.Script but not car parts
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
    scriptTypes = {Script = 0, LocalScript = 0, ModuleScript = 0, CoreScript = 0, Dynamic = 0},
    stats = {
        total = 0, source = 0, bytecode = 0, needDecomp = 0, failed = 0, deduped = 0,
        instancesWalked = 0, containersFailed = 0,
        execDiscovered = 0, -- v18: scripts found via executor functions
    },
    scanning = false,
    lastScan = nil,
    lastFingerprint = nil,
    lastGenre = nil,
    lastExport = nil,
}

-- ============== WALK ENGINE (v18: expanded containers) ==============

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
    -- standard services
    if not CFG.skipWorkspace then
        tryAdd("Workspace")
    end
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
    -- v18 NEW: RobloxReplicatedStorage (server-only replicated storage)
    tryAdd("RobloxReplicatedStorage")

    -- player-specific containers
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
    -- v18 NEW: player backpack (contains tools with LocalScripts)
    if CFG.scanBackpack then
        pcall(function()
            if LocalPlayer:FindFirstChild("Backpack") then
                list[#list + 1] = LocalPlayer.Backpack
            end
        end)
    end

    -- v18 NEW: CoreGui and CorePackages (Roblox internal scripts)
    if CFG.scanCoreGui then
        tryAdd("CoreGui")
        tryAdd("CorePackages")
        pcall(function()
            local cg = game:GetService("CoreGui")
            if cg then
                -- also walk VersionedApp subfolders
                for _, child in ipairs(cg:GetChildren()) do
                    list[#list + 1] = child
                end
            end
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

local function buildStatsLine()
    return string.format(
        "scripts: %d | remotes: %d | npcs: %d\nplayers: %d | values: %d | items: %d\nScript: %d | Local: %d | Module: %d | Core: %d | Dynamic: %d",
        State.stats.total,
        #State.remotes.events + #State.remotes.functions,
        #State.objects.humanoids,
        #State.objects.players,
        #State.objects.values,
        #State.objects.tools,
        State.scriptTypes.Script,
        State.scriptTypes.LocalScript,
        State.scriptTypes.ModuleScript,
        State.scriptTypes.CoreScript,
        State.scriptTypes.Dynamic
    )
end

local function classifyScript(cls)
    if cls == "Script" then
        return "Script"
    elseif cls == "LocalScript" then
        return "LocalScript"
    elseif cls == "ModuleScript" then
        return "ModuleScript"
    elseif cls == "CoreScript" then
        return "CoreScript"
    else
        return "Dynamic"
    end
end

local function addScriptEntry(path, name, className, inst)
    local hash = quickHash(path .. "|" .. className)
    if State.hashes[hash] then
        State.stats.deduped = State.stats.deduped + 1
        return false
    end
    State.hashes[hash] = true
    local scriptType = classifyScript(className)
    State.scriptTypes[scriptType] = (State.scriptTypes[scriptType] or 0) + 1
    table.insert(State.results, {
        path = path,
        name = name,
        className = className,
        scriptType = scriptType,
        inst = inst,
        source = "",
        bytecode = "",
        size = 0,
        status = "PENDING"
    })
    State.stats.total = #State.results
    return true
end

local function unifiedWalk()
    State.results = {}
    State.hashes = {}
    State.remotes = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}}
    State.objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}, players = {}, tools = {}}
    State.assets  = {sounds = {}, animations = {}}
    State.scriptTypes = {Script = 0, LocalScript = 0, ModuleScript = 0, CoreScript = 0, Dynamic = 0}
    State.stats.instancesWalked = 0
    State.stats.containersFailed = 0
    State.stats.total = 0
    State.stats.execDiscovered = 0

    local remoteHashes = {}
    local valueHashes = {}
    local objHashes = {}

    local budget = CFG.frameBudgetMS / 1000
    local frameStart = os.clock()

    local yieldCounter = 0
    local function maybeYield()
        yieldCounter = yieldCounter + 1
        if yieldCounter >= CFG.yieldChunk or (os.clock() - frameStart) >= budget then
            task.wait()
            frameStart = os.clock()
            yieldCounter = 0
        end
    end

    for _, container in ipairs(getContainers()) do
        if not State.scanning then break end
        local isWorkspace = container == game:GetService("Workspace")
        local ok, err = pcall(function()
            -- v18.2: depth-limited stack for Workspace (prevents descending into 50k+ car parts)
            local stack = {{node = container, depth = 0}}
            while #stack > 0 do
                if not State.scanning then return end
                if State.stats.instancesWalked >= CFG.maxInstances then return end

                local item = table.remove(stack)
                local node = item.node
                local depth = item.depth
                -- v18.2: skip descending into Workspace if depth limit exceeded
                if isWorkspace and CFG.wsDepthLimit > 0 and depth >= CFG.wsDepthLimit then
                    maybeYield()
                    continue
                end
                local gotKids, children = pcall(node.GetChildren, node)
                if not gotKids then
                    maybeYield()
                else
                    for _, inst in ipairs(children) do
                        State.stats.instancesWalked = State.stats.instancesWalked + 1
                        local cls = inst.ClassName

                        if cls == "LocalScript" or cls == "Script" or cls == "ModuleScript" or cls == "CoreScript" then
                            table.insert(stack, {node = inst, depth = depth + 1})
                            local okPath, path = pcall(inst.GetFullName, inst)
                            if okPath then
                                addScriptEntry(path, inst.Name, cls, inst)
                            end

                        elseif cls == "RemoteEvent" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not remoteHashes[p] then
                                remoteHashes[p] = true
                                table.insert(State.remotes.events, {path = p, name = inst.Name, inst = inst})
                            end
                        elseif cls == "RemoteFunction" then
                            local okP, p = pcall(inst.GetFullName, inst)
                            if okP and not remoteHashes[p] then
                                remoteHashes[p] = true
                                table.insert(State.remotes.functions, {path = p, name = inst.Name, inst = inst})
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
                            table.insert(stack, {node = inst, depth = depth + 1})

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
                                        name = plr.Name, displayName = plr.DisplayName, userId = plr.UserId,
                                        path = p, hp = hum and hum.Health or 0, mhp = hum and hum.MaxHealth or 0,
                                        ws = hum and hum.WalkSpeed or 0, pos = posStr
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
                                            pcall(function() px, py, pz = root.Position.X, root.Position.Y, root.Position.Z end)
                                        end
                                        table.insert(State.objects.humanoids, {
                                            path = p, name = inst.Name, hp = hum.Health, mhp = hum.MaxHealth,
                                            ws = hum.WalkSpeed, px = px, py = py, pz = pz
                                        })
                                    end
                                end
                            end
                            table.insert(stack, {node = inst, depth = depth + 1})
                        else
                            table.insert(stack, {node = inst, depth = depth + 1})
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
        task.wait()
    end

    State.stats.total = #State.results
end

-- ============== v18 NEW: EXECUTOR SCRIPT DISCOVERY ==============
-- Catches scripts NOT in the instance tree: dynamically loaded,
-- injected, required at runtime, loadstring'd, etc.

local function discoverExecutorScripts()
    if not CFG.useExecDiscovery then return end
    local before = #State.results

    -- getscripts() — returns ALL script instances including ones not in tree
    if getscripts then
        pcall(function()
            local allScripts = getscripts()
            if type(allScripts) == "table" then
                local discCount = 0
                for _, s in ipairs(allScripts) do
                    if not State.scanning then break end
                    discCount = discCount + 1
                    if discCount % 25 == 0 then task.wait() end
                    if typeof(s) == "Instance" and (s:IsA("LocalScript") or s:IsA("Script") or s:IsA("ModuleScript") or s.ClassName == "CoreScript") then
                        local okPath, path = pcall(s.GetFullName, s)
                        if okPath then
                            local cls = s.ClassName
                            -- mark as Dynamic if it's not in the normal tree (no parent in game services)
                            local inTree = false
                            pcall(function()
                                inTree = s:IsDescendantOf(game)
                            end)
                            if not inTree then
                                path = "[DYNAMIC] " .. path
                                cls = "Dynamic"
                            end
                            addScriptEntry(path, s.Name, cls, s)
                        end
                    end
                end
            end
        end)
    end

    -- getloadedModules() — returns loaded ModuleScripts
    if getloadedModules then
        pcall(function()
            local modules = getloadedModules()
            if type(modules) == "table" then
                local modCount = 0
                for _, m in ipairs(modules) do
                    if not State.scanning then break end
                    modCount = modCount + 1
                    if modCount % 25 == 0 then task.wait() end
                    if typeof(m) == "Instance" then
                        local okPath, path = pcall(m.GetFullName, m)
                        if okPath then
                            local inTree = false
                            pcall(function() inTree = m:IsDescendantOf(game) end)
                            if not inTree then
                                path = "[LOADED-MODULE] " .. path
                            end
                            addScriptEntry(path, m.Name, m.ClassName, m)
                        end
                    end
                end
            end
        end)
    end

    -- getrunningScripts() — returns running script threads
    if getrunningScripts then
        pcall(function()
            local running = getrunningScripts()
            if type(running) == "table" then
                for idx, r in ipairs(running) do
                    if not State.scanning then break end
                    if idx % 25 == 0 then task.wait() end
                    -- running scripts may be thread objects or instances
                    local name = "?"
                    local path = "[RUNNING-" .. idx .. "]"
                    pcall(function()
                        if typeof(r) == "Instance" then
                            name = r.Name
                            local okP, p = pcall(r.GetFullName, r)
                            if okP then path = "[RUNNING] " .. p end
                            addScriptEntry(path, name, r.ClassName, r)
                        elseif type(r) == "table" then
                            name = r.Name or r.name or "[thread-" .. idx .. "]"
                            path = "[RUNNING] " .. tostring(name)
                            -- running thread without an instance — can't grab source easily
                            table.insert(State.results, {
                                path = path, name = name, className = "Dynamic",
                                scriptType = "Dynamic",
                                inst = nil, source = "", bytecode = "", size = 0,
                                status = "RUNTIME-THREAD"
                            })
                            State.scriptTypes.Dynamic = State.scriptTypes.Dynamic + 1
                            State.stats.total = #State.results
                        end
                    end)
                end
            end
        end)
    end

    State.stats.execDiscovered = #State.results - before
    if State.stats.execDiscovered > 0 then
        print("[Phantom v18] executor discovery found " .. State.stats.execDiscovered .. " additional scripts")
    end
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
        -- v18.2: respect maxScripts cap to prevent freeze on games with 1000+ scripts
        if CFG.maxScripts > 0 and i > CFG.maxScripts then
            UI:Notify({ Title = "Source cap", Content = "Stopped at " .. CFG.maxScripts .. " scripts (adjustable in Settings)", Time = 3 })
            break
        end
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
            if r.status ~= "RUNTIME-THREAD" then
                r.status = "GONE"
                State.stats.failed = State.stats.failed + 1
            end
        end

        -- v18.1: yield after EVERY script — getsrc/decompile can block 50-500ms each
        task.wait()
        if i % 50 == 0 then
            UI:Notify({ Title = "Progress", Content = "sources: " .. i .. "/" .. #State.results, Time = 1 })
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
    if #targets == 0 then return end
    for i, r in ipairs(targets) do
        if not State.scanning then break end
        local success = decompileOne(r)
        if not success then
            r.status = "FAILED"
            State.stats.failed = State.stats.failed + 1
        end
        -- v18.1: yield after every decompile — decompile can block 100-500ms
        task.wait()
    end
end

-- ============== SECURITY SCAN (expanded patterns) ==============

local function scanSecurity()
    State.acDetections = {}
    State.bdDetections = {}
    State.webhookHits = {}
    State.requireMap = {}

    local acPatterns = {
        "anticheat", "anti-cheat", "exploit", "detect", "flag", "tamper", "noclip",
        "speedhack", "kick", "crash", "rejoin", "ban", "teleport", "fly", "godmode",
        "infinite jump", "walkspeed", "jumppower", "hipheight", "antiexploit",
        "gotchildren", "getchildren", "fireserver", "invokeserver", "characteradded",
        "walkonwalls", "instantteleport", "server sided check", "clientcheck",
        "aimbot", "esp", "wallhack", "silentaim", "triggerbot",
    }
    local bdPatterns = {
        "loadstring(game:httpget", "require(", "backdoor", "getfenv(", "setfenv(", "getgenv(",
        "loadstring(", "httpget(", "httpservice:jsondecode", "scripts serviced",
        "setclipboard", "writefile", "readfile", "loadfile",
    }
    local webhookPatterns = {
        "discord.com/api/webhooks", "discordapp.com/api/webhooks", "webhook",
        "discord.com/api/v9/webhooks", "discord.com/api/v10/webhooks",
        "discord.com/api/v11/webhooks", "discord.com/api/v12/webhooks",
    }

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
        if si % 25 == 0 then
            task.wait()
        end
    end
end

-- ============== GENRE DETECT (expanded) ==============

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
            advice = {"currency/income remotes are the target", "rebirth/upgrade remotes often have thin validation", "auto-farm = loop the collect remote with observed cooldown"}},
        {name = "Tower / Obby", kws = {"obby", "stage", "checkpoint", "tower", "parkour", "killbrick", "jumps", "floor"},
            advice = {"checkpoint remotes = skip-to-stage is classic", "killbricks client-editable visually", "stage values replicated = check values"}},
        {name = "Horror / Survival", kws = {"monster", "jumpscare", "night", "survive", "hide", "escape", "spawnmonster", "chase", "scary", "demon"},
            advice = {"ESP on monsters is main weapon", "door/escape remotes usually validate items", "monster paths/values may replicate"}},
        {name = "Shooter / Fighting", kws = {"gun", "shoot", "damage", "bullet", "weapon", "reload", "ammo", "health", "kill", "hit", "sword", "attack", "combat"},
            advice = {"hit/damage remotes ALWAYS validated in shooters", "weapon data often client-side = visual mods work", "ESP + name tags are the safe surface"}},
        {name = "Roleplay / Social", kws = {"house", "furniture", "job", "work", "roleplay", "adopt", "family", "money", "buy", "shop", "vehicle", "car", "eat", "perk", "skin"},
            advice = {"job/work remotes replicate real actions", "vehicle remotes often accept simple args", "furniture/building remotes usually validate ownership"}},
        {name = "Racing / Vehicle", kws = {"car", "vehicle", "race", "speed", "drive", "engine", "wheel", "crush", "drift", "chassis", "seat"},
            advice = {"vehicle physics often client-predicted", "race checkpoint remotes can be distance-validated", "vehicle stats replicated = free intel"}},
        {name = "Clicker / Incremental", kws = {"click", "tap", "mult", "multiplier", "pet", "egg", "hatch", "clicks", "cps", "energy"},
            advice = {"click remotes are the core loop", "pet hatch remotes validate currency server-side", "multiplier values client-visible = check for writable boosts"}},
        {name = "Social Hangout", kws = {"emote", "music", "boombox", "radio", "avatar", "vip", "social", "chat", "dance"},
            advice = {"mostly client-visual surface", "few exploit targets", "boombox/music remotes sometimes accept any id"}},
        {name = "Strategy / Building", kws = {"build", "place", "construct", "tile", "grid", "unit", "army", "war", "resource", "gather"},
            advice = {"placement remotes may validate terrain", "unit move/attack remotes are the loop", "resource values often client-visible"}},
        {name = "Adventure / RPG", kws = {"quest", "npc", "dialogue", "level", "xp", "skill", "magic", "spell", "inventory", "loot", "dungeon"},
            advice = {"quest remotes often validate progress server-side", "loot/drop values may be client-replicated", "skill cooldowns client-side = no-CD possible"}},
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
        return {name = best.name, confidence = math.min(95, 40 + bestScore * 2), advice = best.advice}
    end
    return {name = "Unclassified / Hybrid", confidence = 30, advice = {"no strong genre signature", "run traffic capture to discover the loop"}}
end

-- ============== FINGERPRINT (expanded signals) ==============

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
    end

    if stateCount > 20 and srcRatio >= 0.3 then
        fp.clientAuthSignals = fp.clientAuthSignals + 2
        table.insert(fp.signals, stateCount .. " game-state values client-visible — likely writable")
    end

    if #State.webhookHits > 0 then
        table.insert(fp.risks, "GAME LOGS TO DISCORD WEBHOOKS")
        fp.serverAuthSignals = fp.serverAuthSignals + 1
    end

    if #State.acDetections > 20 then
        fp.serverAuthSignals = fp.serverAuthSignals + 2
        table.insert(fp.signals, #State.acDetections .. " anti-cheat pattern hits")
        table.insert(fp.risks, "STRONG AC SIGNATURE — expect validation on all remotes")
    elseif #State.acDetections > 0 then
        table.insert(fp.signals, #State.acDetections .. " anti-cheat pattern hits (mild)")
    end

    if #State.bdDetections > 0 then
        table.insert(fp.risks, "BACKDOOR PATTERNS DETECTED — possible server script injection")
    end

    -- v18 NEW: CoreScript count signal
    if State.scriptTypes.CoreScript > 0 then
        table.insert(fp.signals, State.scriptTypes.CoreScript .. " CoreScripts found (Roblox internal)")
    end

    -- v18 NEW: Dynamic script count signal
    if State.scriptTypes.Dynamic > 0 then
        table.insert(fp.signals, State.scriptTypes.Dynamic .. " dynamically-loaded scripts (not in instance tree)")
        table.insert(fp.risks, "DYNAMIC SCRIPTS PRESENT — runtime-loaded code may bypass static analysis")
    end

    local score = fp.serverAuthSignals - fp.clientAuthSignals
    if score >= 4 then
        fp.tier, fp.tierName, fp.confidence = "TIER 3", "server-auth + hardened", 85
        table.insert(fp.recommendations, "SAFE: TPs, ESP, fullbright, data browsers")
        table.insert(fp.recommendations, "AVOID: economy/damage remotes")
    elseif score >= 1 then
        fp.tier, fp.tierName, fp.confidence = "TIER 2", "hybrid validation", 70
        table.insert(fp.recommendations, "SAFE: movement, ESP, TPs, prompt automation")
        table.insert(fp.recommendations, "TEST-ON-ALT: any remote that spends/moves/creates")
    else
        fp.tier, fp.tierName, fp.confidence = "TIER 1", "client-authoritative", 75
        table.insert(fp.recommendations, "FULL SURFACE: value edits, remote firing, auto-farm")
    end

    return fp
end

-- ============== EXPORT BUILDER (v18: no truncation, script types) ==============

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
    add("  PHANTOM SCANNER v18.1 EXPORT")
    add("==========================================")
    add("Game: " .. GameName)
    add("Place ID: " .. tostring(PlaceId))
    add("Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    add("Executor: " .. executorInfo)
    add("UI Library: " .. usingLib)
    add("Instances Walked: " .. State.stats.instancesWalked)
    add("Executor-Discovered Scripts: " .. State.stats.execDiscovered)
    add("")

    add("==================================================")
    add("  BRIEFING")
    add("==================================================")
    add("TIER: " .. fp.tier .. " — " .. fp.tierName .. " (" .. fp.confidence .. "%)")
    add("GENRE: " .. genre.name .. " (" .. genre.confidence .. "%)")
    add("")
    add("-- TIER SIGNALS --")
    for _, s in ipairs(fp.signals) do add("  * " .. s) end
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
    add("-- GENRE PLAYS --")
    for _, a in ipairs(genre.advice) do add("  + " .. a) end
    add("")
    add("-- NUMBERS --")
    add("  Scripts: " .. State.stats.total .. " | src:" .. State.stats.source .. " bc:" .. State.stats.bytecode .. " fail:" .. State.stats.failed)
    add("  Remotes: " .. #State.remotes.events .. "E / " .. #State.remotes.functions .. "F")
    add("  Players: " .. #State.objects.players .. " | NPCs: " .. #State.objects.humanoids)
    add("  Values: " .. #State.objects.values .. " | Items: " .. #State.objects.tools)
    add("  Prompts: " .. #State.objects.prompts .. " | Spawns: " .. #State.objects.spawns)
    add("")
    add("-- SCRIPT TYPES (v18) --")
    add("  Script (server): " .. State.scriptTypes.Script)
    add("  LocalScript (client): " .. State.scriptTypes.LocalScript)
    add("  ModuleScript (shared): " .. State.scriptTypes.ModuleScript)
    add("  CoreScript (Roblox internal): " .. State.scriptTypes.CoreScript)
    add("  Dynamic (runtime-loaded): " .. State.scriptTypes.Dynamic)
    add("")

    add("========== SECURITY ==========")
    add("--- Anti-Cheat Patterns (" .. #State.acDetections .. ") ---")
    for i, d in ipairs(State.acDetections) do
        if i > 100 then
            add("  ...more")
            break
        end
        add("  " .. d.script .. " [line " .. d.line .. "] (" .. d.pattern .. "): " .. d.text)
    end
    add("")
    add("--- Backdoor/Loadstring (" .. #State.bdDetections .. ") ---")
    for i, d in ipairs(State.bdDetections) do
        if i > 100 then
            add("  ...more")
            break
        end
        add("  " .. d.script .. " [line " .. d.line .. "] (" .. d.pattern .. "): " .. d.text)
    end
    add("")
    add("--- Webhooks (" .. #State.webhookHits .. ") ---")
    for i, d in ipairs(State.webhookHits) do
        if i > 50 then
            add("  ...more")
            break
        end
        add("  " .. d.script .. " [line " .. d.line .. "]: " .. d.text)
    end
    add("")

    add("========== PLAYERS ==========")
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
    add("Total: " .. State.stats.total .. " | SOURCE:" .. State.stats.source .. " BYTECODE:" .. State.stats.bytecode .. " FAILED:" .. State.stats.failed)
    add("Types: Script=" .. State.scriptTypes.Script .. " LocalScript=" .. State.scriptTypes.LocalScript .. " ModuleScript=" .. State.scriptTypes.ModuleScript .. " CoreScript=" .. State.scriptTypes.CoreScript .. " Dynamic=" .. State.scriptTypes.Dynamic)
    add("")
    -- v18: NO TRUNCATION — list every single script
    for i, r in ipairs(State.results) do
        add("--------------------------------------------------")
        add("[" .. i .. "/" .. State.stats.total .. "] " .. r.className .. " (" .. (r.scriptType or "?") .. ") | " .. r.path)
        add("STATUS: " .. r.status .. " | SIZE: " .. r.size)
        add("--------------------------------------------------")
        if r.status == "SOURCE" and #r.source > 0 then
            local src = r.source
            if #src > CFG.maxSourceChars then
                src = src:sub(1, CFG.maxSourceChars) .. "\n-- [TRUNCATED — full: " .. #r.source .. " chars]"
            end
            add(src)
        elseif r.status == "BYTECODE" and CFG.saveBytecode and #r.bytecode > 0 then
            local bc = r.bytecode
            if #bc > CFG.maxBytecodeDump then
                bc = bc:sub(1, CFG.maxBytecodeDump) .. "\n-- [BYTECODE TRUNCATED]"
            end
            add("-- BYTECODE:")
            add(bc)
        elseif r.status == "FAILED" then
            add("-- decompile failed")
        elseif r.status == "GONE" then
            add("-- script destroyed")
        elseif r.status == "RUNTIME-THREAD" then
            add("-- runtime thread (no instance — source not grabbable via getsrc/decompile)")
        else
            add("-- no data")
        end
        add("")
        if i % 5 == 0 then
            task.wait()
        end
    end

    add("==========================================")
    add("  END OF EXPORT — PHANTOM v18.1")
    add("==========================================")

    return table.concat(buf, "\n")
end

-- ============== REMOTE SPY ==============

local Spy = {
    enabled = false,
    log = {},
    maxLog = 200,
    hookInstalled = false,
    originalNamecall = nil,
}

local function spyFormat(entry)
    local argStr = ""
    if entry.args and #entry.args > 0 then
        local parts = {}
        for i, a in ipairs(entry.args) do
            if i > 5 then break end
            local s = "?"
            pcall(function()
                if type(a) == "string" then
                    s = '"' .. a:sub(1, 30) .. (#a > 30 and "..." or "") .. '"'
                elseif type(a) == "table" then
                    s = "{table:" .. tostring(a) .. "}"
                else
                    s = tostring(a):sub(1, 30)
                end
            end)
            table.insert(parts, s)
        end
        argStr = table.concat(parts, ", ")
    end
    return string.format("[%s] %s.%s(%s)", entry.time, entry.remote, entry.method, argStr)
end

local function spyPush(entry)
    table.insert(Spy.log, entry)
    if #Spy.log > Spy.maxLog then
        table.remove(Spy.log, 1)
    end
end

local function installSpyHook()
    if Spy.hookInstalled then return end
    if not hookmetamethod or not getrawmetatable or not setreadonly or not getnamecallmethod then
        warn("[Phantom Spy] executor missing hookmetamethod/getrawmetatable/setreadonly/getnamecallmethod")
        return false
    end

    local mt = getrawmetatable(game)
    local original = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = function(self, ...)
        local method = getnamecallmethod()
        if Spy.enabled and (method == "FireServer" or method == "InvokeServer") then
            local isRemote = false
            pcall(function()
                isRemote = self:IsA("RemoteEvent") or self:IsA("RemoteFunction")
            end)
            if isRemote then
                local path = "?"
                pcall(function() path = self:GetFullName() end)
                spyPush({
                    time = os.date("%H:%M:%S"),
                    remote = path,
                    method = method,
                    args = {...},
                })
            end
        end
        return original(self, ...)
    end
    setreadonly(mt, true)
    Spy.hookInstalled = true
    Spy.originalNamecall = original
    return true
end

local function uninstallSpyHook()
    if not Spy.hookInstalled then return end
    if getrawmetatable and setreadonly and Spy.originalNamecall then
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__namecall = Spy.originalNamecall
        setreadonly(mt, true)
    end
    Spy.hookInstalled = false
    Spy.originalNamecall = nil
end

local function spyEnable()
    if not installSpyHook() then return false end
    Spy.enabled = true
    Spy.log = {}
    return true
end

local function spyDisable()
    Spy.enabled = false
end

local function spyGetText()
    if #Spy.log == 0 then return "no remote calls captured yet" end
    local lines = {}
    for _, e in ipairs(Spy.log) do
        table.insert(lines, spyFormat(e))
    end
    return table.concat(lines, "\n")
end

local function spyCopyLog()
    if not setclipboard then return false end
    setclipboard(spyGetText())
    return true
end

-- ============== SCRIPT BROWSER HELPERS ==============

local function getScriptPathList()
    local list = {}
    for _, r in ipairs(State.results) do
        local display = string.format("[%s][%s] %s", r.status, r.scriptType or "?", r.path)
        if #display > 90 then display = display:sub(1, 87) .. "..." end
        table.insert(list, display)
    end
    return list
end

local function findScriptByDisplay(display)
    for _, r in ipairs(State.results) do
        local d = string.format("[%s][%s] %s", r.status, r.scriptType or "?", r.path)
        if #d > 90 then d = d:sub(1, 87) .. "..." end
        if d == display then return r end
    end
    return nil
end

local function getRemotePathList()
    local list = {}
    for _, e in ipairs(State.remotes.events) do
        table.insert(list, "[E] " .. e.path)
    end
    for _, f in ipairs(State.remotes.functions) do
        table.insert(list, "[F] " .. f.path)
    end
    return list
end

local function getObjectList(kind)
    if kind == "npcs" then
        local list = {}
        for _, n in ipairs(State.objects.humanoids) do
            table.insert(list, string.format("%s | HP:%s/%s | %s", n.name, tostring(n.hp), tostring(n.mhp), n.path))
        end
        return list
    elseif kind == "players" then
        local list = {}
        for _, p in ipairs(State.objects.players) do
            table.insert(list, string.format("%s (%s) | HP:%s/%s", p.name, p.displayName, tostring(p.hp), tostring(p.mhp)))
        end
        return list
    elseif kind == "values" then
        local list = {}
        for _, v in ipairs(State.objects.values) do
            table.insert(list, string.format("[%s] %s = %s", v.class, v.path, tostring(v.val or "?")))
        end
        return list
    elseif kind == "tools" then
        local list = {}
        for _, t in ipairs(State.objects.tools) do
            table.insert(list, t.path .. (t.tip ~= "" and (" | " .. t.tip) or ""))
        end
        return list
    elseif kind == "prompts" then
        local list = {}
        for _, p in ipairs(State.objects.prompts) do table.insert(list, p.path) end
        return list
    elseif kind == "clicks" then
        local list = {}
        for _, c in ipairs(State.objects.clickDetectors) do table.insert(list, c.path) end
        return list
    elseif kind == "spawns" then
        local list = {}
        for _, s in ipairs(State.objects.spawns) do table.insert(list, s.path .. " @ " .. s.pos) end
        return list
    end
    return {}
end

local function copyText(text)
    if not setclipboard then
        UI:Notify({ Title = "Clipboard", Content = "setclipboard not available", Time = 3 })
        return false
    end
    setclipboard(text)
    UI:Notify({ Title = "Copied", Content = #text .. " chars on clipboard", Time = 2 })
    return true
end

-- ============== SCAN STAGE RUNNERS ==============

local function runStage(name, fn, doneMsg)
    if State.scanning then
        UI:Notify({ Title = "Busy", Content = "Another scan is running", Time = 2 })
        return
    end
    State.scanning = true
    UI:Notify({ Title = "Scan", Content = name .. " started...", Time = 2 })
    task.spawn(function()
        local ok, err = pcall(fn)
        State.scanning = false
        if ok then
            UI:Notify({ Title = "Done", Content = doneMsg, Time = 3 })
        else
            UI:Notify({ Title = "Error", Content = tostring(err):sub(1, 100), Time = 5 })
            warn("[Phantom] " .. name .. " error: " .. tostring(err))
        end
    end)
end

local function stageWalkOnly()
    UI:Notify({ Title = "Walking", Content = "Scanning containers + executor discovery...", Time = 2 })
    unifiedWalk()
    if CFG.useExecDiscovery then
        UI:Notify({ Title = "Discovery", Content = "Running executor script discovery...", Time = 2 })
        discoverExecutorScripts()
    end
    State.lastScan = os.time()
    print("[Phantom v18.1] walk complete: " .. State.stats.total .. " scripts, " .. (#State.remotes.events + #State.remotes.functions) .. " remotes, " .. State.stats.execDiscovered .. " exec-discovered")
end

local function stageGrabSources()
    if #State.results == 0 then
        UI:Notify({ Title = "Walk first", Content = "No scripts in memory — run Walk first", Time = 3 })
        return
    end
    grabSources()
    print("[Phantom v18] sources grabbed: " .. State.stats.source .. " src, " .. State.stats.bytecode .. " bc")
end

local function stageDecompileFailed()
    if #State.results == 0 then
        UI:Notify({ Title = "Walk first", Content = "No scripts in memory", Time = 3 })
        return
    end
    decompileAllRemaining()
    print("[Phantom v18] decompile retry done")
end

local function stageSecurity()
    if #State.results == 0 then
        UI:Notify({ Title = "Walk first", Content = "No scripts in memory", Time = 3 })
        return
    end
    scanSecurity()
    print("[Phantom v18] security scan: " .. #State.acDetections .. " AC, " .. #State.bdDetections .. " backdoor, " .. #State.webhookHits .. " webhook")
end

local function stageAnalyze()
    local genre = detectGenre()
    local fp = analyzeFingerprint()
    State.lastGenre = genre
    State.lastFingerprint = fp
    print("[Phantom v18] analysis: " .. fp.tier .. " / " .. genre.name)
end

local function stageExport()
    if not State.lastFingerprint then stageAnalyze() end
    local export = buildExport(State.lastFingerprint, State.lastGenre)
    State.lastExport = export
    local path = attemptSave(export)
    if path then
        SAVED_PATH = path
        UI:Notify({ Title = "Saved", Content = path, Time = 4 })
    else
        UI:Notify({ Title = "Save failed", Content = "Check F9 — all writes failed", Time = 4 })
    end
end

local function stageFullScan()
    UI:Notify({ Title = "Full Scan", Content = "Stage 1/6: Deep walk...", Time = 2 })
    unifiedWalk()
    if CFG.useExecDiscovery then
        UI:Notify({ Title = "Full Scan", Content = "Stage 1b: Executor discovery...", Time = 2 })
        discoverExecutorScripts()
    end
    UI:Notify({ Title = "Full Scan", Content = "Stage 2/6: Grabbing sources (" .. #State.results .. " scripts)...", Time = 2 })
    grabSources()
    UI:Notify({ Title = "Full Scan", Content = "Stage 3/6: Decompiling failed...", Time = 2 })
    decompileAllRemaining()
    UI:Notify({ Title = "Full Scan", Content = "Stage 4/6: Security scan...", Time = 2 })
    scanSecurity()
    UI:Notify({ Title = "Full Scan", Content = "Stage 5/6: Tier + genre analysis...", Time = 2 })
    stageAnalyze()
    UI:Notify({ Title = "Full Scan", Content = "Stage 6/6: Building export...", Time = 2 })
    stageExport()
    State.lastScan = os.time()
end

-- ============== UI BUILD ==============

local Window = UI:MakeWindow({
    Title = "Phantom Scanner v18",
    Author = "SMITH",
    Size = UDim2.fromOffset(570, 480),
})

-- ===== Overview tab =====
local OverviewTab = Window:MakeTab({
    Title = "Overview",
    Icon = "rbxassetid://4370306966",
    Description = "Run scan stages and view game info",
})

OverviewTab:AddParagraph({
    Title = "Game: " .. GameName,
    Description = "Place ID: " .. tostring(PlaceId) .. " | Executor: " .. executorInfo .. " | UI: " .. usingLib,
})

OverviewTab:AddSection({ Title = "Scan Stages", Description = "Run each stage independently or all at once. v18 adds executor script discovery (getscripts/getloadedModules/getrunningScripts)." })

OverviewTab:AddButton({
    Title = "Run Full Scan",
    Description = "Walk ALL containers (incl CoreGui/CorePackages/Backpack), discover executor-hidden scripts, grab sources, decompile failed, scan security, classify tier+genre, export to .txt. One-shot everything.",
    Callback = function() runStage("Full scan", stageFullScan, "Full scan complete — check save path") end,
})

OverviewTab:AddButton({
    Title = "Deep Walk (all containers + executor discovery)",
    Description = "Walks every container including CoreGui, CorePackages, RobloxReplicatedStorage, and player Backpack. Then runs getscripts()/getloadedModules()/getrunningScripts() to catch scripts NOT in the instance tree (dynamically loaded, injected, runtime-required). No source grab — fast inventory.",
    Callback = function() runStage("Deep walk", stageWalkOnly, "Walk complete — see Stats tab") end,
})

OverviewTab:AddButton({
    Title = "Grab Sources Only",
    Description = "Re-runs source extraction (getsrc / getscriptbytecode) on scripts already walked. Does NOT walk again — run this after Deep Walk if you want readable sources.",
    Callback = function() runStage("Grab sources", stageGrabSources, "Sources grabbed — see Scripts tab") end,
})

OverviewTab:AddButton({
    Title = "Decompile Failed",
    Description = "Re-tries the decompile function on scripts that returned NODECOMP on first pass. Some executors decompile on second attempt after warming up.",
    Callback = function() runStage("Decompile retry", stageDecompileFailed, "Decompile retry complete") end,
})

OverviewTab:AddButton({
    Title = "Security Scan",
    Description = "Pattern-matches grabbed sources for anti-cheat keywords, backdoor patterns (loadstring/require/getfenv), Discord webhook URLs, and require() calls. Output appears in Security tab.",
    Callback = function() runStage("Security scan", stageSecurity, "Security scan complete — see Security tab") end,
})

OverviewTab:AddButton({
    Title = "Tier + Genre Detect",
    Description = "Classifies the game into TIER 1/2/3 based on remote naming, source visibility, state-value count, AC pattern density, webhook presence, dynamic script presence. Also detects genre. Output in Stats tab.",
    Callback = function() runStage("Analyze", stageAnalyze, "Analysis complete — see Stats tab") end,
})

OverviewTab:AddSection({ Title = "Export" })

OverviewTab:AddButton({
    Title = "Export to File",
    Description = "Builds the full .txt export (v18 format — includes script type breakdown, no script count cap) and writes to workspace root. Filename: <GameName>_<PlaceID>.txt.",
    Callback = function()
        if not State.lastExport then
            if #State.results == 0 then
                UI:Notify({ Title = "Nothing to export", Content = "Run a scan first", Time = 3 })
                return
            end
            stageAnalyze()
        end
        stageExport()
    end,
})

OverviewTab:AddButton({
    Title = "Copy Export to Clipboard",
    Description = "Builds the export text and copies to clipboard instead of writing to file.",
    Callback = function()
        if not State.lastExport then
            if #State.results == 0 then
                UI:Notify({ Title = "Nothing to export", Content = "Run a scan first", Time = 3 })
                return
            end
            stageAnalyze()
            State.lastExport = buildExport(State.lastFingerprint, State.lastGenre)
        end
        copyText(State.lastExport)
    end,
})

OverviewTab:AddButton({
    Title = "Copy Save Path",
    Description = "Copies the path of the last saved .txt file to clipboard.",
    Callback = function()
        if SAVED_PATH then
            copyText(SAVED_PATH)
        else
            UI:Notify({ Title = "No save", Content = "Nothing saved yet", Time = 2 })
        end
    end,
})

-- ===== Stats tab =====
local StatsTab = Window:MakeTab({
    Title = "Stats",
    Icon = "rbxassetid://4370306966",
    Description = "Live scan counts, script type breakdown, and tier/genre result",
})

StatsTab:AddParagraph({
    Title = "Live counts",
    Description = "Updates after each scan stage. Shows script type breakdown (v18) and tier/genre.",
})

local statsParagraph
statsParagraph = StatsTab:AddParagraph({
    Title = "No scan yet",
    Description = "",
})

StatsTab:AddButton({
    Title = "Refresh Stats",
    Description = "Re-reads current State and updates the paragraph above.",
    Callback = function()
        if statsParagraph and statsParagraph.Set then
            statsParagraph:Set({ Title = "Stats", Description = buildStatsLine() })
        end
    end,
})

task.spawn(function()
    while true do
        task.wait(2)
        if statsParagraph and statsParagraph.Set then
            pcall(function() statsParagraph:Set({ Title = "Stats", Description = buildStatsLine() }) end)
        end
    end
end)

-- ===== Scripts tab =====
local ScriptsTab = Window:MakeTab({
    Title = "Scripts",
    Icon = "rbxassetid://4370306966",
    Description = "Browse ALL scripts found (including CoreScript and Dynamic) and copy their source",
})

ScriptsTab:AddParagraph({
    Title = "Script browser",
    Description = "v18 shows script type in the dropdown: [STATUS][TYPE] path. Types: Script (server), LocalScript (client), ModuleScript (shared), CoreScript (Roblox internal), Dynamic (runtime-loaded).",
})

local selectedScript = nil
local scriptDropdown = ScriptsTab:AddDropdown({
    Title = "Script",
    Description = "All scripts found during last walk + executor discovery.",
    Values = {"(none — run Deep Walk first)"},
    Default = "(none — run Deep Walk first)",
    Callback = function(v) selectedScript = v end,
})

ScriptsTab:AddButton({
    Title = "Refresh Script List",
    Description = "Rebuilds the dropdown from current State. Run after Deep Walk or Grab Sources.",
    Callback = function()
        local list = getScriptPathList()
        if #list == 0 then
            UI:Notify({ Title = "Empty", Content = "Run Deep Walk first", Time = 2 })
            return
        end
        if scriptDropdown and scriptDropdown.Refresh then
            scriptDropdown:Refresh(list, "Refresh")
        end
        UI:Notify({ Title = "Loaded", Content = #list .. " scripts", Time = 2 })
    end,
})

ScriptsTab:AddButton({
    Title = "Copy Source to Clipboard",
    Description = "Copies the selected script's source to clipboard. Only works if status is SOURCE. If BYTECODE, copies bytecode. If RUNTIME-THREAD, nothing to copy.",
    Callback = function()
        if not selectedScript then
            UI:Notify({ Title = "Pick one", Content = "Select a script first", Time = 2 })
            return
        end
        local entry = findScriptByDisplay(selectedScript)
        if not entry then
            UI:Notify({ Title = "Not found", Content = "Script missing from state", Time = 2 })
            return
        end
        local text = ""
        if entry.status == "SOURCE" then
            text = entry.source
        elseif entry.status == "BYTECODE" then
            text = entry.bytecode
        else
            UI:Notify({ Title = "No data", Content = "Status: " .. entry.status, Time = 2 })
            return
        end
        copyText(text)
    end,
})

ScriptsTab:AddButton({
    Title = "Force Decompile Selected",
    Description = "Re-runs the decompile function on the selected script, ignoring cached results.",
    Callback = function()
        if not selectedScript then return end
        local entry = findScriptByDisplay(selectedScript)
        if not entry then return end
        task.spawn(function()
            local ok = decompileOne(entry)
            if ok then
                UI:Notify({ Title = "Decompiled", Content = "Source now available", Time = 2 })
            else
                UI:Notify({ Title = "Failed", Content = "Decompile returned empty", Time = 3 })
            end
        end)
    end,
})

-- ===== Remotes tab =====
local RemotesTab = Window:MakeTab({
    Title = "Remotes",
    Icon = "rbxassetid://4370306966",
    Description = "Browse remotes and live-spy FireServer/InvokeServer calls",
})

RemotesTab:AddParagraph({
    Title = "Remote inventory",
    Description = "After a Walk, all RemoteEvents and RemoteFunctions appear here. [E] = event (FireServer), [F] = function (InvokeServer).",
})

local selectedRemote = nil
local remoteDropdown = RemotesTab:AddDropdown({
    Title = "Remote",
    Description = "Pick a remote to copy its path",
    Values = {"(none — run Deep Walk first)"},
    Default = "(none — run Deep Walk first)",
    Callback = function(v) selectedRemote = v end,
})

RemotesTab:AddButton({
    Title = "Refresh Remote List",
    Description = "Rebuilds the dropdown from current State.",
    Callback = function()
        local list = getRemotePathList()
        if #list == 0 then
            UI:Notify({ Title = "Empty", Content = "Run Deep Walk first", Time = 2 })
            return
        end
        if remoteDropdown and remoteDropdown.Refresh then
            remoteDropdown:Refresh(list, "Refresh")
        end
        UI:Notify({ Title = "Loaded", Content = #list .. " remotes", Time = 2 })
    end,
})

RemotesTab:AddButton({
    Title = "Copy Selected Remote Path",
    Description = "Copies the remote's full path (without [E]/[F] prefix) to clipboard.",
    Callback = function()
        if not selectedRemote then return end
        local path = selectedRemote:gsub("^%[[EF]%] ", "")
        copyText(path)
    end,
})

RemotesTab:AddButton({
    Title = "Copy All Remotes",
    Description = "Copies the full remote list to clipboard.",
    Callback = function()
        local list = getRemotePathList()
        copyText(table.concat(list, "\n"))
    end,
})

RemotesTab:AddSection({ Title = "Live Remote Spy", Description = "Hook __namecall to capture FireServer/InvokeServer calls in real time" })

RemotesTab:AddToggle({
    Title = "Enable Live Spy",
    Description = "Installs a hookmetamethod hook on game.__namecall that logs every FireServer and InvokeServer call. Hook stays installed until toggled off or unloaded. Requires hookmetamethod/getrawmetatable/setreadonly/getnamecallmethod.",
    Default = false,
    Callback = function(v)
        if v then
            local ok = spyEnable()
            if ok then
                UI:Notify({ Title = "Spy ON", Content = "Capturing FireServer / InvokeServer", Time = 2 })
            else
                UI:Notify({ Title = "Spy failed", Content = "Executor missing required functions", Time = 4 })
            end
        else
            spyDisable()
            UI:Notify({ Title = "Spy OFF", Content = "Hook kept installed, just not logging", Time = 2 })
        end
    end,
})

RemotesTab:AddButton({
    Title = "Copy Spy Log",
    Description = "Copies the last 200 captured remote calls to clipboard.",
    Callback = function()
        if #Spy.log == 0 then
            UI:Notify({ Title = "Empty", Content = "No calls captured yet", Time = 2 })
            return
        end
        copyText(spyGetText())
    end,
})

RemotesTab:AddButton({
    Title = "Clear Spy Log",
    Description = "Empties the spy log buffer.",
    Callback = function()
        Spy.log = {}
        UI:Notify({ Title = "Cleared", Content = "Spy log reset", Time = 1 })
    end,
})

RemotesTab:AddButton({
    Title = "Print Spy Log to Console",
    Description = "Dumps the spy log to F9 developer console.",
    Callback = function()
        if #Spy.log == 0 then
            print("[Phantom Spy] no calls captured")
            return
        end
        print("[Phantom Spy] === " .. #Spy.log .. " calls ===")
        for _, e in ipairs(Spy.log) do
            print("[Phantom Spy] " .. spyFormat(e))
        end
        print("[Phantom Spy] === end ===")
        UI:Notify({ Title = "Printed", Content = #Spy.log .. " calls in F9", Time = 2 })
    end,
})

-- ===== Objects tab =====
local ObjectsTab = Window:MakeTab({
    Title = "Objects",
    Icon = "rbxassetid://4370306966",
    Description = "Browse NPCs, players, values, tools, prompts, click detectors, spawns",
})

local selectedObjectKind = "npcs"
local selectedObject = nil

local objectKindDropdown = ObjectsTab:AddDropdown({
    Title = "Object kind",
    Description = "Which object list to browse.",
    Values = {"npcs", "players", "values", "tools", "prompts", "clicks", "spawns"},
    Default = "npcs",
    Callback = function(v) selectedObjectKind = v end,
})

local objectListDropdown = ObjectsTab:AddDropdown({
    Title = "Items",
    Description = "Refresh after picking a kind.",
    Values = {"(refresh first)"},
    Default = "(refresh first)",
    Callback = function(v) selectedObject = v end,
})

ObjectsTab:AddButton({
    Title = "Refresh Item List",
    Description = "Rebuilds the items dropdown for the selected object kind.",
    Callback = function()
        local list = getObjectList(selectedObjectKind)
        if #list == 0 then
            UI:Notify({ Title = "Empty", Content = "No " .. selectedObjectKind .. " (walk first?)", Time = 2 })
            return
        end
        if objectListDropdown and objectListDropdown.Refresh then
            objectListDropdown:Refresh(list, "Refresh")
        end
        UI:Notify({ Title = "Loaded", Content = #list .. " " .. selectedObjectKind, Time = 2 })
    end,
})

ObjectsTab:AddButton({
    Title = "Copy Selected Item",
    Description = "Copies the selected item's display line to clipboard.",
    Callback = function()
        if not selectedObject or selectedObject == "(refresh first)" then return end
        copyText(selectedObject)
    end,
})

ObjectsTab:AddButton({
    Title = "Copy All Items (Current Kind)",
    Description = "Copies every item in the current kind's list to clipboard.",
    Callback = function()
        local list = getObjectList(selectedObjectKind)
        if #list == 0 then return end
        copyText(table.concat(list, "\n"))
    end,
})

-- ===== Security tab =====
local SecurityTab = Window:MakeTab({
    Title = "Security",
    Icon = "rbxassetid://4370306966",
    Description = "Anti-cheat, backdoor, and webhook detection results",
})

SecurityTab:AddParagraph({
    Title = "Security report",
    Description = "Run Security Scan stage first. Counts shown below; click buttons to copy full reports.",
})

local secParagraph
secParagraph = SecurityTab:AddParagraph({
    Title = "No scan yet",
    Description = "Run Security Scan from Overview tab",
})

local function refreshSecurity()
    local text = string.format(
        "Anti-Cheat pattern hits: %d\nBackdoor pattern hits: %d\nWebhook hits: %d\nRequire() calls: %d",
        #State.acDetections, #State.bdDetections, #State.webhookHits, #State.requireMap
    )
    if #State.acDetections > 20 then
        text = text .. "\n\n! STRONG AC SIGNATURE — expect validated remotes"
    elseif #State.acDetections > 0 then
        text = text .. "\n\n~ mild AC signature"
    end
    if #State.bdDetections > 0 then
        text = text .. "\n\n! BACKDOOR PATTERNS — possible server-side injection"
    end
    if #State.webhookHits > 0 then
        text = text .. "\n\n! DISCORD WEBHOOKS — game logs to Discord"
    end
    return text
end

SecurityTab:AddButton({
    Title = "Refresh Security Summary",
    Description = "Updates the paragraph above with current detection counts.",
    Callback = function()
        if secParagraph and secParagraph.Set then
            secParagraph:Set({ Title = "Security summary", Description = refreshSecurity() })
        end
    end,
})

SecurityTab:AddButton({
    Title = "Copy AC Report",
    Description = "Copies all anti-cheat pattern hits to clipboard.",
    Callback = function()
        if #State.acDetections == 0 then
            UI:Notify({ Title = "Empty", Content = "No AC hits", Time = 2 })
            return
        end
        local lines = {}
        for i, d in ipairs(State.acDetections) do
            if i > 100 then
                table.insert(lines, "...more")
                break
            end
            table.insert(lines, string.format("%s [L%d] (%s): %s", d.script, d.line, d.pattern, d.text))
        end
        copyText(table.concat(lines, "\n"))
    end,
})

SecurityTab:AddButton({
    Title = "Copy Backdoor Report",
    Description = "Copies all backdoor pattern hits to clipboard.",
    Callback = function()
        if #State.bdDetections == 0 then
            UI:Notify({ Title = "Empty", Content = "No backdoor hits", Time = 2 })
            return
        end
        local lines = {}
        for i, d in ipairs(State.bdDetections) do
            if i > 100 then
                table.insert(lines, "...more")
                break
            end
            table.insert(lines, string.format("%s [L%d] (%s): %s", d.script, d.line, d.pattern, d.text))
        end
        copyText(table.concat(lines, "\n"))
    end,
})

SecurityTab:AddButton({
    Title = "Copy Webhook Report",
    Description = "Copies all Discord webhook URL hits to clipboard.",
    Callback = function()
        if #State.webhookHits == 0 then
            UI:Notify({ Title = "Empty", Content = "No webhook hits", Time = 2 })
            return
        end
        local lines = {}
        for i, d in ipairs(State.webhookHits) do
            if i > 50 then
                table.insert(lines, "...more")
                break
            end
            table.insert(lines, string.format("%s [L%d]: %s", d.script, d.line, d.text))
        end
        copyText(table.concat(lines, "\n"))
    end,
})

-- ===== Settings tab =====
local SettingsTab = Window:MakeTab({
    Title = "Settings",
    Icon = "rbxassetid://4370306966",
    Description = "Tune scan performance, coverage, and output limits",
})

SettingsTab:AddParagraph({
    Title = "Performance",
    Description = "Frame budget controls how often the scan yields to Roblox.",
})

SettingsTab:AddSlider({
    Title = "Frame Budget (ms)",
    Description = "Max ms per frame before yielding. 8 = balanced. Higher = faster scan, more lag.",
    Min = 1, Max = 30, Default = 8,
    Callback = function(v) CFG.frameBudgetMS = v end,
})

SettingsTab:AddSlider({
    Title = "Max Instances",
    Description = "Hard cap on instances walked. 5M default (v18 raised from 1M).",
    Min = 10000, Max = 10000000, Default = 5000000,
    Callback = function(v) CFG.maxInstances = v end,
})

SettingsTab:AddSlider({
    Title = "Decompile Retries",
    Description = "How many times to retry decompile on empty result.",
    Min = 1, Max = 5, Default = 2,
    Callback = function(v) CFG.decompRetries = v end,
})

SettingsTab:AddSection({ Title = "v18 Coverage Options" })

SettingsTab:AddToggle({
    Title = "Scan CoreGui / CorePackages",
    Description = "When ON, walks Roblox internal services (CoreGui, CorePackages) for CoreScripts. These are Roblox's own UI/system scripts — usually not game-relevant but included for completeness. ON by default.",
    Default = true,
    Callback = function(v) CFG.scanCoreGui = v end,
})

SettingsTab:AddToggle({
    Title = "Scan Player Backpack",
    Description = "When ON, walks the local player's Backpack for tool-embedded LocalScripts. Catches scripts inside equipped/stored tools. ON by default.",
    Default = true,
    Callback = function(v) CFG.scanBackpack = v end,
})

SettingsTab:AddToggle({
    Title = "Use Executor Script Discovery",
    Description = "When ON, uses getscripts()/getloadedModules()/getrunningScripts() to find scripts NOT in the instance tree. ON by default.",
    Default = true,
    Callback = function(v) CFG.useExecDiscovery = v end,
})

SettingsTab:AddSection({ Title = "v18.2 Anti-Freeze (Large Games)" })

SettingsTab:AddToggle({
    Title = "Skip Workspace Entirely",
    Description = "When ON, does not walk Workspace at all. Use for games like Car Crushers 2 where Workspace has 50k+ parts and no scripts. Scripts in ReplicatedStorage/ServerScriptService/etc are still scanned.",
    Default = false,
    Callback = function(v) CFG.skipWorkspace = v end,
})

SettingsTab:AddSlider({
    Title = "Workspace Depth Limit",
    Description = "Max depth to descend into Workspace. 5 = catches Workspace.Folder.Script but skips car part nests. 0 = unlimited (will freeze on massive games).",
    Min = 0, Max = 20, Default = 5,
    Callback = function(v) CFG.wsDepthLimit = v end,
})

SettingsTab:AddSlider({
    Title = "Yield Chunk Size (anti-freeze)",
    Description = "Yield to Roblox every N items processed. 10 = very smooth (slower scan). 50 = faster but may stutter. Default 10.",
    Min = 1, Max = 100, Default = 10,
    Callback = function(v) CFG.yieldChunk = v end,
})

SettingsTab:AddSlider({
    Title = "Max Scripts to Grab Source",
    Description = "Cap on how many scripts to extract source from. 0 = no limit. Set to 200 if game has 1000+ scripts.",
    Min = 0, Max = 5000, Default = 0,
    Callback = function(v) CFG.maxScripts = v end,
})

SettingsTab:AddSection({ Title = "Output limits" })

SettingsTab:AddSlider({
    Title = "Max Source Chars (per script)",
    Description = "Per-script source cap in export. 500k default (v18 raised from 300k).",
    Min = 10000, Max = 2000000, Default = 500000,
    Callback = function(v) CFG.maxSourceChars = v end,
})

SettingsTab:AddSlider({
    Title = "Max Bytecode Dump (per script)",
    Description = "Per-script bytecode cap. 50k default (v18 raised from 20k).",
    Min = 1000, Max = 200000, Default = 50000,
    Callback = function(v) CFG.maxBytecodeDump = v end,
})

SettingsTab:AddToggle({
    Title = "Save Bytecode",
    Description = "When ON, scripts that only yielded bytecode still get it dumped.",
    Default = true,
    Callback = function(v) CFG.saveBytecode = v end,
})

SettingsTab:AddSection({ Title = "Unload" })

SettingsTab:AddButton({
    Title = "Unload Scanner (Killswitch)",
    Description = "Destroys UI, disables remote spy hook (restores original __namecall), clears all state. Clean teardown.",
    Callback = function()
        spyDisable()
        uninstallSpyHook()
        State.results = {}
        State.hashes = {}
        State.remotes = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}}
        State.objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}, players = {}, tools = {}}
        State.assets = {sounds = {}, animations = {}}
        State.acDetections = {}
        State.bdDetections = {}
        State.webhookHits = {}
        State.requireMap = {}
        Spy.log = {}
        UI:Destroy()
        print("[Phantom v18] unloaded — all state cleared, spy hook restored")
    end,
})

-- ============== INIT ==============

UI:Init()

print("[Phantom v18.1] loaded — Game: " .. GameName)
print("[Phantom v18.1] UI: " .. usingLib)
print("[Phantom v18.1] Executor: " .. executorInfo)
print("[Phantom v18.1] Save target: " .. EXPORT_FILENAME)
print("[Phantom v18.1] NEW: Anti-freeze (yield every script), CoreGui/Backpack walk, executor discovery, script types")
print("[Phantom v18.1] Tabs: Overview / Stats / Scripts / Remotes / Objects / Security / Settings")
print("BUILD OK")
