--!nocheck
-- ==============================================================
--  PHANTOM SCANNER v10.1
--  Custom UI | Click-to-copy | Remote tester | Config persist
--  Repo: github.com/snowy-dot/Advance-scanner-game-
-- ==============================================================

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local HttpService          = game:GetService("HttpService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local Workspace            = game:GetService("Workspace")
local StarterGui           = game:GetService("StarterGui")
local StarterPlayer        = game:GetService("StarterPlayer")
local ServerScriptService  = game:GetService("ServerScriptService")
local UserInputService     = game:GetService("UserInputService")
local TweenService         = game:GetService("TweenService")
local MarketplaceService   = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local unpack = table.unpack or unpack

-- executor function resolver
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

-- game name detection
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

-- ==============================================================
--  THEME
-- ==============================================================

local Theme = {
    bg       = Color3.fromRGB(16, 16, 22),
    bg2      = Color3.fromRGB(24, 24, 32),
    bg3      = Color3.fromRGB(32, 32, 42),
    accent   = Color3.fromRGB(138, 99, 255),
    text     = Color3.fromRGB(235, 235, 245),
    textDim  = Color3.fromRGB(130, 130, 148),
    success  = Color3.fromRGB(80, 220, 130),
    danger   = Color3.fromRGB(255, 90, 90),
    warning  = Color3.fromRGB(255, 190, 70),
    border   = Color3.fromRGB(48, 48, 62)
}

local accentElements = {}
local function registerAccent(inst, prop)
    table.insert(accentElements, {inst = inst, prop = prop})
end

-- ==============================================================
--  CONFIG (persist between sessions)
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
    objects          = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}},
    assets           = {sounds = {}, animations = {}, decals = {}, meshes = {}},
    acDetections     = {},
    bdDetections     = {},
    webhookHits      = {},
    requireMap       = {},
    deepData         = {remoteCalls = {}, promptHits = {}, spawns = {}},
    stats            = {total = 0, success = 0, failed = 0, deduped = 0, skipped = 0},
    excludeBuildings = CFG.excludeBuildings ~= false,
    maxDepth         = CFG.maxDepth or 0,
    deepScanning     = false,
    busy             = false,
    cancelScan       = false,
    lastExportPath   = "",
    scanStart        = 0,
    scanDuration     = 0
}

local connections = {}
local restoreHook -- forward declaration (needed by close button)
local refreshScriptList -- forward declaration
local populateRemotes -- forward declaration

local function persistConfig()
    pcall(function()
        saveConfig({
            excludeBuildings = State.excludeBuildings,
            maxDepth = State.maxDepth,
            accent = {
                math.floor(Theme.accent.R * 255 + 0.5),
                math.floor(Theme.accent.G * 255 + 0.5),
                math.floor(Theme.accent.B * 255 + 0.5)
            }
        })
    end)
end

local function setAccent(color)
    Theme.accent = color
    for _, e in ipairs(accentElements) do
        pcall(function() e.inst[e.prop] = color end)
    end
    for _, p in ipairs(pillRegistry) do
        pcall(function()
            p.pill.BackgroundColor3 = p.get() and color or Theme.bg
        end)
    end
end

local excludedClasses = {
    "Part", "WedgePart", "TrussPart", "Seat", "VehicleSeat"
}

local excludedKeywords = {
    "building", "house", "wall", "floor",
    "ceiling", "roof", "door", "window",
    "terrain", "baseplate", "ground"
}

-- ==============================================================
--  UI HELPERS
-- ==============================================================

local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = inst end
    end
    inst.Parent = props.Parent
    return inst
end

local function corner(inst, radius)
    return create("UICorner", {CornerRadius = UDim.new(0, radius or 6), Parent = inst})
end

local function stroke(inst, color, thickness)
    return create("UIStroke", {
        Color = color or Theme.border,
        Thickness = thickness or 1,
        Parent = inst
    })
end

local function tween(inst, props, dur)
    local t = TweenService:Create(inst, TweenInfo.new(dur or 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

-- ==============================================================
--  GUI ROOT
-- ==============================================================

pcall(function()
    local root = gethui and gethui() or game:GetService("CoreGui")
    for _, g in ipairs(root:GetChildren()) do
        if g.Name == "PhantomScannerUI" then g:Destroy() end
    end
end)

local parentGui = game:GetService("CoreGui")
local protected = false
pcall(function()
    if gethui then
        parentGui = gethui()
        protected = true
    end
end)

local ScreenGui = create("ScreenGui", {
    Name = "PhantomScannerUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = parentGui
})
if not protected then
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
    end)
end

local Main = create("Frame", {
    Name = "Main",
    Size = UDim2.new(0, 760, 0, 480),
    Position = UDim2.new(0.5, -380, 0.5, -240),
    BackgroundColor3 = Theme.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = ScreenGui
})
corner(Main, 10)
stroke(Main, Theme.border, 1)

-- topbar
local TopBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = Theme.bg2,
    BorderSizePixel = 0,
    Parent = Main
})
corner(TopBar, 10)
create("Frame", {
    Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0, 0, 1, -10),
    BackgroundColor3 = Theme.bg2,
    BorderSizePixel = 0,
    Parent = TopBar
})

local TitleIcon = create("TextLabel", {
    Size = UDim2.new(0, 24, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "◈",
    TextColor3 = Theme.accent,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    Parent = TopBar
})
registerAccent(TitleIcon, "TextColor3")

create("TextLabel", {
    Size = UDim2.new(0, 300, 1, 0),
    Position = UDim2.new(0, 40, 0, 0),
    BackgroundTransparency = 1,
    Text = "PHANTOM // Game Scanner v10.1",
    TextColor3 = Theme.text,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TopBar
})

local gameLabel = create("TextLabel", {
    Size = UDim2.new(0, 280, 1, 0),
    Position = UDim2.new(1, -330, 0, 0),
    BackgroundTransparency = 1,
    Text = GameName,
    TextColor3 = Theme.textDim,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = TopBar
})

local MinBtn = create("TextButton", {
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -70, 0, 4),
    BackgroundColor3 = Theme.bg3,
    Text = "—",
    TextColor3 = Theme.textDim,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent = TopBar
})
corner(MinBtn, 6)

local CloseBtn = create("TextButton", {
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -36, 0, 4),
    BackgroundColor3 = Theme.bg3,
    Text = "✕",
    TextColor3 = Theme.danger,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent = TopBar
})
corner(CloseBtn, 6)

-- sidebar
local Sidebar = create("Frame", {
    Size = UDim2.new(0, 158, 1, -38),
    Position = UDim2.new(0, 0, 0, 38),
    BackgroundColor3 = Theme.bg2,
    BorderSizePixel = 0,
    Parent = Main
})
corner(Sidebar, 10)
create("Frame", {
    Size = UDim2.new(1, 0, 0, 10),
    BackgroundColor3 = Theme.bg2,
    BorderSizePixel = 0,
    Parent = Sidebar
})

create("UIListLayout", {
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = Sidebar
})
create("UIPadding", {
    PaddingTop = UDim.new(0, 8),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    Parent = Sidebar
})

-- content area
local Content = create("Frame", {
    Size = UDim2.new(1, -158, 1, -38),
    Position = UDim2.new(0, 158, 0, 38),
    BackgroundTransparency = 1,
    Parent = Main
})

-- status bar
local StatusBar = create("TextLabel", {
    Size = UDim2.new(1, -158, 0, 24),
    Position = UDim2.new(0, 158, 1, -24),
    BackgroundColor3 = Theme.bg2,
    Text = "  idle | " .. executorInfo,
    TextColor3 = Theme.textDim,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    BorderSizePixel = 0,
    Parent = Main
})
corner(StatusBar, 10)
create("Frame", {
    Size = UDim2.new(0, 12, 1, 0),
    BackgroundColor3 = Theme.bg2,
    BorderSizePixel = 0,
    Parent = StatusBar
})

local function setStatus(text, color)
    StatusBar.Text = "  " .. text
    StatusBar.TextColor3 = color or Theme.textDim
end

-- drag
do
    local dragging = false
    local dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- RightCtrl hide/show keybind
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        Main.Visible = not Main.Visible
    end
end)

-- minimize / close
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(Main, {Size = UDim2.new(0, 760, 0, 38)})
        MinBtn.Text = "+"
    else
        tween(Main, {Size = UDim2.new(0, 760, 0, 480)})
        MinBtn.Text = "—"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    if restoreHook then pcall(restoreHook) end
    for _, c in pairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    tween(Main, {Size = UDim2.new(0, 760, 0, 0)}, 0.15)
    task.delay(0.2, function() ScreenGui:Destroy() end)
end)

-- ==============================================================
--  NOTIFICATIONS
-- ==============================================================

local notifHolder = create("Frame", {
    Size = UDim2.new(0, 280, 1, -20),
    Position = UDim2.new(1, -290, 0, 10),
    BackgroundTransparency = 1,
    Parent = ScreenGui
})
create("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    Parent = notifHolder
})

local function notify(title, msg, dur, nColor)
    task.spawn(function()
        local n = create("Frame", {
            Size = UDim2.new(1, 0, 0, 64),
            BackgroundColor3 = Theme.bg2,
            BorderSizePixel = 0,
            Parent = notifHolder
        })
        corner(n, 8)
        stroke(n, nColor or Theme.border, 1)

        create("TextLabel", {
            Size = UDim2.new(1, -16, 0, 20),
            Position = UDim2.new(0, 8, 0, 6),
            BackgroundTransparency = 1,
            Text = title,
            TextColor3 = nColor or Theme.accent,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = n
        })
        create("TextLabel", {
            Size = UDim2.new(1, -16, 0, 34),
            Position = UDim2.new(0, 8, 0, 27),
            BackgroundTransparency = 1,
            Text = msg,
            TextColor3 = Theme.text,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = n
        })

        n.Position = UDim2.new(1, 300, 0, 0)
        tween(n, {Position = UDim2.new(0, 0, 0, 0)}, 0.25)
        task.wait(dur or 4)
        tween(n, {Position = UDim2.new(1, 300, 0, 0)}, 0.25)
        task.wait(0.3)
        n:Destroy()
    end)
end

-- ==============================================================
--  TAB SYSTEM + WIDGET BUILDERS
-- ==============================================================

local tabs = {}
local activeTab = nil
local orderCounter = 0
local function nextOrder()
    orderCounter = orderCounter + 1
    return orderCounter
end

local function makeTab(name, icon)
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.bg2,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
        LayoutOrder = #tabs + 1,
        Parent = Sidebar
    })
    corner(btn, 6)

    create("TextLabel", {
        Size = UDim2.new(0, 22, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = icon,
        TextColor3 = Theme.textDim,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        Parent = btn
    })
    local lbl = create("TextLabel", {
        Size = UDim2.new(1, -34, 1, 0),
        Position = UDim2.new(0, 32, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Theme.textDim,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = btn
    })

    local page = create("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -32),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = Content
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page
    })

    local tab = {name = name, btn = btn, page = page, lbl = lbl}
    tabs[name] = tab

    btn.MouseEnter:Connect(function()
        if activeTab ~= name then tween(btn, {BackgroundColor3 = Theme.bg3}) end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= name then tween(btn, {BackgroundColor3 = Theme.bg2}) end
    end)
    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(tabs) do
            t.page.Visible = false
            t.btn.BackgroundColor3 = Theme.bg2
            t.lbl.TextColor3 = Theme.textDim
        end
        page.Visible = true
        btn.BackgroundColor3 = Theme.bg3
        lbl.TextColor3 = Theme.accent
        activeTab = name
    end)

    return page
end

local function sec(page, title)
    local s = create("TextLabel", {
        Size = UDim2.new(1, -8, 0, 24),
        BackgroundTransparency = 1,
        Text = "▸ " .. title,
        TextColor3 = Theme.accent,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = nextOrder(),
        Parent = page
    })
    registerAccent(s, "TextColor3")
    return s
end

local function button(page, text, callback, height)
    local b = create("TextButton", {
        Size = UDim2.new(1, -8, 0, height or 34),
        BackgroundColor3 = Theme.bg3,
        Text = text,
        TextColor3 = Theme.text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        LayoutOrder = nextOrder(),
        Parent = page
    })
    corner(b, 6)
    stroke(b, Theme.border, 1)
    b.MouseEnter:Connect(function()
        tween(b, {BackgroundColor3 = Theme.accent, BackgroundTransparency = 0.7})
    end)
    b.MouseLeave:Connect(function()
        tween(b, {BackgroundColor3 = Theme.bg3, BackgroundTransparency = 0})
    end)
    b.MouseButton1Click:Connect(callback)
    return b
end

local function label(page, text, height)
    return create("TextLabel", {
        Size = UDim2.new(1, -8, 0, height or 20),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.textDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = nextOrder(),
        Parent = page
    })
end

-- clickable row: click = copy | optional side button = custom action
local function row(page, mainText, subText, copyText, accentColor, sideText, sideCb)
    local hasSide = sideText ~= nil
    local r = create("TextButton", {
        Size = UDim2.new(1, -8, 0, subText and 40 or 26),
        BackgroundColor3 = Theme.bg2,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
        LayoutOrder = nextOrder(),
        Parent = page
    })
    corner(r, 5)
    stroke(r, Theme.border, 1)

    local w = hasSide and -74 or -16
    create("TextLabel", {
        Size = UDim2.new(1, w, 0, 16),
        Position = UDim2.new(0, 8, 0, 3),
        BackgroundTransparency = 1,
        Text = mainText,
        TextColor3 = accentColor or Theme.text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = r
    })
    if subText then
        create("TextLabel", {
            Size = UDim2.new(1, w, 0, 14),
            Position = UDim2.new(0, 8, 0, 21),
            BackgroundTransparency = 1,
            Text = subText,
            TextColor3 = Theme.textDim,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = r
        })
    end

    if hasSide then
        local sb = create("TextButton", {
            Size = UDim2.new(0, 54, 0, subText and 26 or 18),
            Position = UDim2.new(1, -62, 0.5, subText and -13 or -9),
            BackgroundColor3 = Theme.bg3,
            Text = sideText,
            TextColor3 = Theme.accent,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            Parent = r
        })
        corner(sb, 5)
        sb.MouseButton1Click:Connect(function()
            if sideCb then sideCb() end
        end)
    end

    r.MouseEnter:Connect(function() tween(r, {BackgroundColor3 = Theme.bg3}) end)
    r.MouseLeave:Connect(function() tween(r, {BackgroundColor3 = Theme.bg2}) end)
    r.MouseButton1Click:Connect(function()
        if copyText and setclipboard then
            setclipboard(copyText)
            setStatus("copied: " .. mainText:sub(1, 55), Theme.success)
        end
    end)
    return r
end

local pillRegistry = {}

local function toggle(page, name, default, callback)
    local t = create("TextButton", {
        Size = UDim2.new(1, -8, 0, 32),
        BackgroundColor3 = Theme.bg3,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
        LayoutOrder = nextOrder(),
        Parent = page
    })
    corner(t, 6)

    create("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Theme.text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = t
    })

    local pill = create("Frame", {
        Size = UDim2.new(0, 40, 0, 18),
        Position = UDim2.new(1, -50, 0.5, -9),
        BackgroundColor3 = default and Theme.accent or Theme.bg,
        BorderSizePixel = 0,
        Parent = t
    })
    corner(pill, 9)

    local knob = create("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Theme.text,
        BorderSizePixel = 0,
        Parent = pill
    })
    corner(knob, 7)

    local value = default
    table.insert(pillRegistry, {
        pill = pill,
        get = function() return value end
    })

    t.MouseButton1Click:Connect(function()
        value = not value
        tween(pill, {BackgroundColor3 = value and Theme.accent or Theme.bg})
        tween(knob, {Position = value and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)})
        callback(value)
    end)
    return t
end

local function slider(page, name, min, max, default, callback)
    local holder = create("Frame", {
        Size = UDim2.new(1, -8, 0, 44),
        BackgroundColor3 = Theme.bg3,
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(),
        Parent = page
    })
    corner(holder, 6)

    local valLbl = create("TextLabel", {
        Size = UDim2.new(0, 60, 0, 18),
        Position = UDim2.new(1, -66, 0, 4),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = Theme.accent,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = holder
    })
    registerAccent(valLbl, "TextColor3")

    create("TextLabel", {
        Size = UDim2.new(1, -80, 0, 18),
        Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Theme.text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    })

    local bar = create("Frame", {
        Size = UDim2.new(1, -20, 0, 6),
        Position = UDim2.new(0, 10, 0, 30),
        BackgroundColor3 = Theme.bg,
        BorderSizePixel = 0,
        Parent = holder
    })
    corner(bar, 3)

    local fill = create("Frame", {
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        Parent = bar
    })
    corner(fill, 3)
    registerAccent(fill, "BackgroundColor3")

    local sliding = false
    local function update(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        valLbl.Text = tostring(val)
        callback(val)
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    return holder
end

local function clearList(frame)
    for _, c in ipairs(frame:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
    end
end

-- ==============================================================
--  SCANNER CORE
-- ==============================================================

local function quickHash(str)
    if not str then return "nil" end
    local h = 5381
    for i = 1, #str do
        h = (h * 33 + string.byte(str, i)) % 0x100000000
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

local function shouldScan(inst)
    if not State.excludeBuildings then return true end
    for _, cls in ipairs(excludedClasses) do
        if inst:IsA(cls) then
            State.stats.skipped = State.stats.skipped + 1
            return false
        end
    end
    local ln = inst.Name:lower()
    for _, kw in ipairs(excludedKeywords) do
        if ln:find(kw, 1, true) then
            State.stats.skipped = State.stats.skipped + 1
            return false
        end
    end
    local cur = inst.Parent
    while cur and cur ~= game do
        local pl = cur.Name:lower()
        for _, kw in ipairs(excludedKeywords) do
            if pl:find(kw, 1, true) then
                State.stats.skipped = State.stats.skipped + 1
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
        {ServerScriptService, "ServerScriptService"},
        {StarterGui, "StarterGui"},
        {StarterPlayer, "StarterPlayer"}
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
        if State.cancelScan then break end
        local node = table.remove(stack)
        if node and node.obj then
            for _, child in ipairs(node.obj:GetChildren()) do
                table.insert(results, child)
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
        if State.cancelScan then break end
    end

    State.stats.total = #allScripts
    notify("Scripts", "Found " .. #allScripts .. " scripts", 3)

    for i, entry in ipairs(allScripts) do
        if State.cancelScan then break end
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
                    className = cls,
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
    State.objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, values = {}}
    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if shouldScan(d) then
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
                if d:IsA("ValueBase") then
                    local ok, val = pcall(function() return tostring(d.Value):sub(1, 60) end)
                    table.insert(State.objects.values, {
                        path = d:GetFullName(),
                        class = d.ClassName,
                        val = ok and val or "?"
                    })
                end
            end
        end
    end)
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
        #State.acDetections, #State.bdDetections, #State.webhookHits), 5,
        (#State.bdDetections > 0) and Theme.warning or nil)
end

-- ==============================================================
--  PATH RESOLVER + TEMPLATE GENERATION
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
                cur = cur:FindFirstChild(p) or cur:WaitForChild(p, 3)
            end
        else
            cur = cur:FindFirstChild(p) or cur:WaitForChild(p, 3)
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
        "-- note: if the first part of a path isn't a service, replace GetService with game:WaitForChild",
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
            local ok, err = pcall(function()
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

    table.insert(buf, "==========================================")
    table.insert(buf, "  PHANTOM SCANNER v10.1 EXPORT")
    table.insert(buf, "==========================================")
    table.insert(buf, "Game: " .. GameName)
    table.insert(buf, "Place ID: " .. tostring(game.PlaceId))
    table.insert(buf, "Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(buf, "Executor: " .. executorInfo)
    table.insert(buf, "Scan Duration: " .. string.format("%.1fs", State.scanDuration))
    table.insert(buf, "")

    table.insert(buf, "========== STATS ==========")
    table.insert(buf, "Total Scripts: " .. State.stats.total)
    table.insert(buf, "Successful: " .. State.stats.success)
    table.insert(buf, "Failed: " .. State.stats.failed)
    table.insert(buf, "Deduped: " .. State.stats.deduped)
    table.insert(buf, "Skipped (Buildings): " .. State.stats.skipped)
    table.insert(buf, "")

    table.insert(buf, "========== REMOTES ==========")
    table.insert(buf, "--- RemoteEvents (" .. #State.remotes.events .. ") ---")
    for _, e in ipairs(State.remotes.events) do table.insert(buf, e.path) end
    table.insert(buf, "--- RemoteFunctions (" .. #State.remotes.functions .. ") ---")
    for _, f in ipairs(State.remotes.functions) do table.insert(buf, f.path) end
    table.insert(buf, "--- BindableEvents (" .. #State.remotes.bindables .. ") ---")
    for _, b in ipairs(State.remotes.bindables) do table.insert(buf, b.path) end
    table.insert(buf, "--- BindableFunctions (" .. #State.remotes.bindableFuncs .. ") ---")
    for _, b in ipairs(State.remotes.bindableFuncs) do table.insert(buf, b.path) end
    table.insert(buf, "")

    table.insert(buf, "========== OBJECTS ==========")
    table.insert(buf, "--- ProximityPrompts (" .. #State.objects.prompts .. ") ---")
    for _, p in ipairs(State.objects.prompts) do table.insert(buf, p.path) end
    table.insert(buf, "--- ClickDetectors (" .. #State.objects.clickDetectors .. ") ---")
    for _, c in ipairs(State.objects.clickDetectors) do table.insert(buf, c.path) end
    table.insert(buf, "--- NPCs (" .. #State.objects.humanoids .. ") ---")
    for _, n in ipairs(State.objects.humanoids) do
        table.insert(buf, n.name .. " | HP:" .. tostring(n.hp) .. "/" .. tostring(n.mhp)
            .. " WS:" .. tostring(n.ws) .. " | " .. n.path .. " @ " .. n.pos)
    end
    table.insert(buf, "--- SpawnLocations (" .. #State.objects.spawns .. ") ---")
    for _, s in ipairs(State.objects.spawns) do
        table.insert(buf, s.path .. " @ " .. s.pos)
    end
    table.insert(buf, "--- Values (" .. #State.objects.values .. ") ---")
    for _, v in ipairs(State.objects.values) do
        table.insert(buf, "[" .. v.class .. "] " .. v.path .. " = " .. v.val)
    end
    table.insert(buf, "")

    table.insert(buf, "========== ASSETS ==========")
    table.insert(buf, "--- Sounds (" .. #State.assets.sounds .. ") ---")
    for _, s in ipairs(State.assets.sounds) do table.insert(buf, s.path .. " | " .. s.id) end
    table.insert(buf, "--- Animations (" .. #State.assets.animations .. ") ---")
    for _, a in ipairs(State.assets.animations) do table.insert(buf, a.path .. " | " .. a.id) end
    table.insert(buf, "--- Decals (" .. #State.assets.decals .. ") ---")
    for _, d in ipairs(State.assets.decals) do table.insert(buf, d.path .. " | " .. d.tex) end
    table.insert(buf, "--- Meshes (" .. #State.assets.meshes .. ") ---")
    for _, m in ipairs(State.assets.meshes) do table.insert(buf, m.path .. " | " .. m.id) end
    table.insert(buf, "")

    table.insert(buf, "========== SECURITY ==========")
    table.insert(buf, "--- AntiCheat Detections (" .. #State.acDetections .. ") ---")
    for _, d in ipairs(State.acDetections) do
        table.insert(buf, d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
        table.insert(buf, "  " .. d.text)
    end
    table.insert(buf, "--- Backdoor Detections (" .. #State.bdDetections .. ") ---")
    for _, d in ipairs(State.bdDetections) do
        table.insert(buf, d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
        table.insert(buf, "  " .. d.text)
    end
    table.insert(buf, "--- Webhook / Logging (" .. #State.webhookHits .. ") ---")
    for _, d in ipairs(State.webhookHits) do
        table.insert(buf, d.script .. ":L" .. d.line .. " [" .. d.pattern .. "]")
        table.insert(buf, "  " .. d.text)
    end
    table.insert(buf, "--- Require Map (" .. #State.requireMap .. ") ---")
    for _, r in ipairs(State.requireMap) do
        table.insert(buf, r.script .. " -> " .. r.target)
    end
    table.insert(buf, "")

    table.insert(buf, "========== DEEP SCAN DATA ==========")
    table.insert(buf, "--- Remote Calls (" .. #State.deepData.remoteCalls .. ") ---")
    for _, c in ipairs(State.deepData.remoteCalls) do
        table.insert(buf, "[" .. c.time .. "] " .. c.method .. "." .. c.remote)
        table.insert(buf, "  Path: " .. c.path)
        table.insert(buf, "  Args: " .. c.args)
    end
    table.insert(buf, "--- Prompt Hits (" .. #State.deepData.promptHits .. ") ---")
    for _, c in ipairs(State.deepData.promptHits) do
        table.insert(buf, "[" .. c.time .. "] " .. c.prompt .. " | " .. c.path)
    end
    table.insert(buf, "--- Spawns (" .. #State.deepData.spawns .. ") ---")
    for _, c in ipairs(State.deepData.spawns) do
        table.insert(buf, "[" .. c.time .. "] " .. c.name .. " | " .. c.path)
    end
    table.insert(buf, "")

    table.insert(buf, "==========================================")
    table.insert(buf, "  SCRIPT SOURCES")
    table.insert(buf, "==========================================")
    table.insert(buf, "")

    for _, r in ipairs(State.results) do
        table.insert(buf, "------ " .. r.path .. " [" .. r.className .. "] ------")
        table.insert(buf, "Category: " .. r.category .. " | Size: " .. r.size .. " | Status: " .. r.status)
        table.insert(buf, "")
        if r.source and #r.source > 0 then
            table.insert(buf, r.source)
        else
            table.insert(buf, "[NO SOURCE AVAILABLE]")
        end
        table.insert(buf, "")
    end

    local out = table.concat(buf, "\n")
    local saved = writeMultiPath(out, safeGameName, ".txt")

    if saved then
        State.lastExportPath = saved
        if setclipboard then setclipboard(out) end
        notify("Export Saved", saved, 6, Theme.success)
        setStatus("exported: " .. saved, Theme.success)
        return true
    else
        if setclipboard then
            setclipboard(out)
            notify("Export Failed", "writefile unavailable. Report copied to clipboard.", 6, Theme.danger)
        else
            notify("Export Failed", "writefile and clipboard unavailable", 6, Theme.danger)
        end
        return false
    end
end

local function exportSourcesToFiles()
    if not writefile then
        notify("Export", "writefile unavailable", 4, Theme.danger)
        return
    end
    local folder = safeGameName .. "_sources"
    if makefolder and not isfolder(folder) then
        pcall(makefolder, folder)
    end
    local count = 0
    for i, r in ipairs(State.results) do
        if r.source and #r.source > 0 and r.status == "OK" then
            local fname = folder .. "/" .. sanitizeFilename(r.name) .. "_" .. i .. ".lua"
            pcall(writefile, fname, "-- " .. r.path .. "\n-- " .. r.className .. " | " .. r.category .. "\n\n" .. r.source)
            count = count + 1
            if count % 20 == 0 then RunService.RenderStepped:Wait() end
        end
    end
    notify("Sources", "Saved " .. count .. " files to " .. folder, 5, Theme.success)
    setStatus("sources exported: " .. count .. " files", Theme.success)
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
    setStatus("deep scan running (" .. duration .. "s)", Theme.warning)

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
                #State.deepData.remoteCalls, #State.deepData.promptHits, #State.deepData.spawns), 6, Theme.success)
            setStatus("deep scan complete", Theme.success)
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
    setStatus("deep scan stopped", Theme.textDim)
end

-- ==============================================================
--  DIAGNOSTICS
-- ==============================================================

local function runDiagnostics()
    local lines = {}
    local function log(t) table.insert(lines, t) end

    log("=== PHANTOM DIAGNOSTICS ===")
    log("Executor: " .. executorInfo)
    log("writefile: " .. tostring(type(writefile)))
    log("readfile: " .. tostring(type(readfile)))
    log("isfolder: " .. tostring(type(isfolder)))
    log("makefolder: " .. tostring(type(makefolder)))
    log("setclipboard: " .. tostring(type(setclipboard)))
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
        if ok and readfile then
            local ok2, content = pcall(function() return readfile("phantom_diag_test.txt") end)
            log("Test read: " .. tostring(ok2) .. " content=" .. tostring(content))
        end
    end

    if makefolder and isfolder then
        pcall(function()
            if not isfolder("PhantomScanner") then makefolder("PhantomScanner") end
        end)
        log("Folder PhantomScanner: " .. tostring(isfolder("PhantomScanner")))
    end

    local report = table.concat(lines, "\n")
    print(report)
    return report
end

-- ==============================================================
--  SCAN PIPELINE
-- ==============================================================

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
        setStatus("scan cancelled", Theme.warning)
    else
        setStatus(string.format("scan done in %.1fs | %d scripts | %d remotes",
            State.scanDuration, State.stats.total,
            #State.remotes.events + #State.remotes.functions), Theme.success)
    end
end

-- ==============================================================
--  BUILD TABS
-- ==============================================================

-- ===== MAIN =====
local TabMain = makeTab("Main", "◈")

sec(TabMain, "Scanner Control")

local progressLabel = label(TabMain, "ready.", 20)

button(TabMain, "⬤  FULL SCAN", function()
    if State.busy then return end
    task.spawn(function()
        runScanPipeline(function(done, total)
            progressLabel.Text = string.format("scanning scripts... %d / %d (%d%%)",
                done, total, math.floor(done / total * 100))
        end)
        progressLabel.Text = string.format("done in %.1fs — %d scripts found",
            State.scanDuration, State.stats.total)
        if refreshScriptList then refreshScriptList() end
    end)
end, 40)

button(TabMain, "Scripts Only", function()
    if State.busy then return end
    task.spawn(function()
        State.busy = true
        State.cancelScan = false
        State.scanStart = os.clock()
        scanScripts(function(done, total)
            progressLabel.Text = string.format("scanning... %d / %d", done, total)
        end)
        State.scanDuration = os.clock() - State.scanStart
        State.busy = false
        progressLabel.Text = string.format("scripts done in %.1fs", State.scanDuration)
        if refreshScriptList then refreshScriptList() end
    end)
end)

button(TabMain, "Cancel Current Scan", function()
    if State.busy then
        State.cancelScan = true
        setStatus("cancelling...", Theme.warning)
    end
end)

sec(TabMain, "Individual Scans")

button(TabMain, "Remotes Only", function() task.spawn(scanRemotes) end)
button(TabMain, "Objects + Assets", function()
    task.spawn(function() scanObjects() scanAssets() end)
end)
button(TabMain, "Security Scan (uses script results)", function() task.spawn(scanSecurity) end)

sec(TabMain, "Diagnostics")

local diagLabel = label(TabMain, "not run yet.", 120)
button(TabMain, "Run Diagnostics", function()
    task.spawn(function()
        local report = runDiagnostics()
        diagLabel.Text = report:sub(1, 600)
        notify("Diagnostics", "Full report in F9 console", 4)
    end)
end)

-- ===== SCRIPTS =====
local TabScr = makeTab("Scripts", "≡")

sec(TabScr, "Search + Filter")

local searchBox = create("TextBox", {
    Size = UDim2.new(1, -8, 0, 32),
    BackgroundColor3 = Theme.bg3,
    Text = "",
    PlaceholderText = "search scripts by name or path...",
    PlaceholderColor3 = Theme.textDim,
    TextColor3 = Theme.text,
    TextSize = 13,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    LayoutOrder = nextOrder(),
    Parent = TabScr
})
corner(searchBox, 6)
create("UIPadding", {PaddingLeft = UDim.new(0, 10), Parent = searchBox})

local filterOptions = {"All", "Combat", "Movement", "Economy", "NPC", "Remote",
    "DataStore", "Security", "Animation", "Audio", "Client", "Server", "Module", "Other"}
local filterIndex = 1

local filterBtn = button(TabScr, "Filter: All (click to cycle)", function()
    filterIndex = (filterIndex % #filterOptions) + 1
    filterBtn.Text = "Filter: " .. filterOptions[filterIndex] .. " (click to cycle)"
    if refreshScriptList then refreshScriptList() end
end)

sec(TabScr, "Script List (click row = copy source)")

local scriptCountLabel = label(TabScr, "no scripts scanned yet.", 18)
local scriptListFrame = create("Frame", {
    Size = UDim2.new(1, -8, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = nextOrder(),
    Parent = TabScr
})
create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scriptListFrame})

refreshScriptList = function()
    clearList(scriptListFrame)

    local query = searchBox.Text:lower()
    local selCat = filterOptions[filterIndex]
    local count = 0

    for _, r in ipairs(State.results) do
        local matchesCat = (selCat == "All") or (r.category == selCat)
        local matchesQuery = (query == "")
            or r.name:lower():find(query, 1, true)
            or r.path:lower():find(query, 1, true)

        if matchesCat and matchesQuery then
            count = count + 1
            if count <= 150 then
                local statusColor = (r.status == "OK") and Theme.success or Theme.danger
                local statusTag = (r.status == "OK") and "[OK]" or ("[" .. r.status .. "]")
                row(scriptListFrame,
                    statusTag .. " [" .. r.className .. "] " .. r.name .. "  •  " .. r.category,
                    r.path .. "  •  " .. tostring(r.size) .. " bytes",
                    (r.source and #r.source > 0) and r.source or ("-- no source -- path: " .. r.path),
                    statusColor)
            end
        end
    end

    scriptCountLabel.Text = count .. " scripts shown" .. (count > 150 and " (first 150)" or "")
end

-- debounced search (token-based, no lag on every keystroke)
local searchToken = 0
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchToken = searchToken + 1
    local myToken = searchToken
    task.delay(0.12, function()
        if myToken == searchToken then refreshScriptList() end
    end)
end)

button(TabScr, "Copy ALL Sources (concatenated)", function()
    task.spawn(function()
        local all = {}
        for _, r in ipairs(State.results) do
            if r.status == "OK" and r.source and #r.source > 0 then
                table.insert(all, "--===== " .. r.path .. " [" .. r.className .. "] =====")
                table.insert(all, r.source)
                table.insert(all, "")
            end
        end
        local out = table.concat(all, "\n")
        if setclipboard then
            setclipboard(out)
            notify("Copy", tostring(#out) .. " bytes copied", 3, Theme.success)
        end
    end)
end)

-- ===== REMOTES =====
local TabRem = makeTab("Remotes", "⚡")

sec(TabRem, "Remote List (click = copy path | [use] = load into tester)")

local remListFrame = create("Frame", {
    Size = UDim2.new(1, -8, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = nextOrder(),
    Parent = TabRem
})
create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = remListFrame})

button(TabRem, "Refresh Remote List", function() task.spawn(populateRemotes) end)

sec(TabRem, "Remote Tester")

local pathBox = create("TextBox", {
    Size = UDim2.new(1, -8, 0, 30),
    BackgroundColor3 = Theme.bg3,
    Text = "",
    PlaceholderText = "remote path (click [use] on a row or paste)...",
    PlaceholderColor3 = Theme.textDim,
    TextColor3 = Theme.text,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    LayoutOrder = nextOrder(),
    Parent = TabRem
})
corner(pathBox, 6)
create("UIPadding", {PaddingLeft = UDim.new(0, 10), Parent = pathBox})

local argsBox = create("TextBox", {
    Size = UDim2.new(1, -8, 0, 30),
    BackgroundColor3 = Theme.bg3,
    Text = "",
    PlaceholderText = 'args comma-separated: 5, true, "hello", nil',
    PlaceholderColor3 = Theme.textDim,
    TextColor3 = Theme.text,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    LayoutOrder = nextOrder(),
    Parent = TabRem
})
corner(argsBox, 6)
create("UIPadding", {PaddingLeft = UDim.new(0, 10), Parent = argsBox})

local testResult = label(TabRem, "no action yet.", 34)

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

button(TabRem, "Check Path (resolve + show class)", function()
    task.spawn(function()
        local obj = resolvePath(pathBox.Text)
        if obj then
            testResult.Text = "✓ " .. obj.ClassName .. " | " .. obj:GetFullName()
            setStatus("resolved: " .. obj.ClassName, Theme.success)
        else
            testResult.Text = "✗ resolve failed: " .. pathBox.Text
            setStatus("resolve failed", Theme.danger)
        end
    end)
end)

button(TabRem, "Fire RemoteEvent", function()
    task.spawn(function()
        local obj = resolvePath(pathBox.Text)
        if not obj then
            testResult.Text = "✗ resolve failed: " .. pathBox.Text
            return
        end
        if not obj:IsA("RemoteEvent") then
            testResult.Text = "✗ not a RemoteEvent (got " .. obj.ClassName .. ")"
            return
        end
        local args = parseArgs(argsBox.Text)
        local ok, err = pcall(function() obj:FireServer(unpack(args)) end)
        testResult.Text = ok and ("✓ fired with " .. #args .. " args") or ("✗ error: " .. tostring(err))
        setStatus(ok and "remote fired" or "fire error", ok and Theme.success or Theme.danger)
    end)
end)

button(TabRem, "Invoke RemoteFunction", function()
    task.spawn(function()
        local obj = resolvePath(pathBox.Text)
        if not obj then
            testResult.Text = "✗ resolve failed: " .. pathBox.Text
            return
        end
        if not obj:IsA("RemoteFunction") then
            testResult.Text = "✗ not a RemoteFunction (got " .. obj.ClassName .. ")"
            return
        end
        local args = parseArgs(argsBox.Text)
        local ok, res = pcall(function() return obj:InvokeServer(unpack(args)) end)
        if ok then
            local s
            if type(res) == "table" then
                local e, j = pcall(function() return HttpService:JSONEncode(res) end)
                s = (e and j) or tostring(res)
            else
                s = tostring(res)
            end
            testResult.Text = "✓ returned: " .. s:sub(1, 250)
        else
            testResult.Text = "✗ error: " .. tostring(res)
        end
        setStatus(ok and "invoke done" or "invoke error", ok and Theme.success or Theme.danger)
    end)
end)

populateRemotes = function()
    clearList(remListFrame)

    for i, e in ipairs(State.remotes.events) do
        if i > 100 then break end
        row(remListFrame, "⚡ " .. e.name, e.path, e.path, nil, "use", function()
            pathBox.Text = e.path
            setStatus("loaded into tester: " .. e.name, Theme.success)
        end)
    end
    for i, f in ipairs(State.remotes.functions) do
        if i > 100 then break end
        row(remListFrame, "⚡ " .. f.name .. " (function)", f.path, f.path, Theme.warning, "use", function()
            pathBox.Text = f.path
            setStatus("loaded into tester: " .. f.name, Theme.success)
        end)
    end

    if #State.remotes.events == 0 and #State.remotes.functions == 0 then
        label(remListFrame, "no remotes found. run a scan first.", 20)
    end
end

sec(TabRem, "Templates")

button(TabRem, "Generate + Copy Remote Templates", function()
    task.spawn(function()
        local t = generateTemplates()
        if setclipboard then setclipboard(t) end
        pcall(writefile, safeGameName .. "_templates.lua", t)
        notify("Templates", "Copied to clipboard + saved to file", 5, Theme.success)
    end)
end)

button(TabRem, "Generate Smart Templates (from deep scan)", function()
    task.spawn(function()
        local t = generateSmartTemplates()
        if setclipboard then setclipboard(t) end
        pcall(writefile, safeGameName .. "_smart_templates.lua", t)
        notify("Smart Templates", tostring(#State.deepData.remoteCalls) .. " observed calls processed", 5, Theme.success)
    end)
end)

-- ===== OBJECTS =====
local TabObj = makeTab("Objects", "◎")

sec(TabObj, "NPCs (click = copy path | [TP] = teleport)")

local objListFrame = create("Frame", {
    Size = UDim2.new(1, -8, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = nextOrder(),
    Parent = TabObj
})
create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = objListFrame})

button(TabObj, "Show NPCs", function()
    clearList(objListFrame)
    for _, n in ipairs(State.objects.humanoids) do
        row(objListFrame,
            "◎ " .. n.name .. "  |  HP " .. tostring(n.hp) .. "/" .. tostring(n.mhp) .. "  WS " .. tostring(n.ws),
            n.pos, n.path, nil, "TP", function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and n.px then
                    hrp.CFrame = CFrame.new(n.px, n.py, n.pz)
                    setStatus("teleported to " .. n.name, Theme.success)
                end
            end)
    end
    if #State.objects.humanoids == 0 then
        label(objListFrame, "no NPCs. scan first.", 20)
    end
end)

button(TabObj, "Show Prompts + Values", function()
    clearList(objListFrame)
    for i, p in ipairs(State.objects.prompts) do
        if i > 40 then break end
        row(objListFrame, "▣ " .. p.name, p.path, p.path)
    end
    for i, v in ipairs(State.objects.values) do
        if i > 40 then break end
        row(objListFrame, "[" .. v.class .. "] " .. v.path, "= " .. v.val, v.path .. " = " .. v.val)
    end
    if #State.objects.prompts == 0 and #State.objects.values == 0 then
        label(objListFrame, "nothing found. scan first.", 20)
    end
end)

-- ===== SECURITY =====
local TabSec = makeTab("Security", "⛨")

sec(TabSec, "Detections (click row = copy line)")

local secListFrame = create("Frame", {
    Size = UDim2.new(1, -8, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = nextOrder(),
    Parent = TabSec
})
create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = secListFrame})

local function populateSec()
    clearList(secListFrame)

    if #State.acDetections > 0 then
        label(secListFrame, "⛨ " .. #State.acDetections .. " anti-cheat related lines:", 18)
    end
    for i, d in ipairs(State.acDetections) do
        if i > 40 then break end
        local shortName = d.script:match("[^%.]+$") or d.script
        row(secListFrame, "⛨ " .. shortName .. ":L" .. d.line .. " [" .. d.pattern .. "]",
            d.text, d.text, Theme.danger)
    end

    if #State.bdDetections > 0 then
        label(secListFrame, "⚑ " .. #State.bdDetections .. " potential backdoor lines:", 18)
    end
    for i, d in ipairs(State.bdDetections) do
        if i > 40 then break end
        local shortName = d.script:match("[^%.]+$") or d.script
        row(secListFrame, "⚑ " .. shortName .. ":L" .. d.line .. " [" .. d.pattern .. "]",
            d.text, d.text, Theme.warning)
    end

    if #State.webhookHits > 0 then
        label(secListFrame, "📡 " .. #State.webhookHits .. " webhook/logging refs (game may report exploiters):", 18)
    end
    for i, d in ipairs(State.webhookHits) do
        if i > 20 then break end
        local shortName = d.script:match("[^%.]+$") or d.script
        row(secListFrame, "📡 " .. shortName .. ":L" .. d.line, d.text, d.text, Theme.warning)
    end

    if #State.requireMap > 0 then
        label(secListFrame, "Require map (" .. #State.requireMap .. "):", 18)
    end
    for i, d in ipairs(State.requireMap) do
        if i > 30 then break end
        local shortName = d.script:match("[^%.]+$") or d.script
        row(secListFrame, "→ " .. shortName .. " requires: " .. d.target, d.text, d.text)
    end

    if #State.acDetections == 0 and #State.bdDetections == 0 and #State.webhookHits == 0 then
        label(secListFrame, "clean. run full scan first to populate.", 20)
    end
end

button(TabSec, "Refresh Security View", populateSec)

-- ===== DEEP SCAN =====
local TabDeep = makeTab("Deep Scan", "◉")

sec(TabDeep, "Live Monitor")

button(TabDeep, "▶ Start Deep Scan (300s)", function() startDeepScan(300) end)
button(TabDeep, "▶ Start Deep Scan (60s)", function() startDeepScan(60) end)
button(TabDeep, "■ Stop Deep Scan", stopDeepScan)

local deepStatsLabel = label(TabDeep, "calls: 0 | prompts: 0 | spawns: 0", 18)

task.spawn(function()
    while ScreenGui.Parent do
        if State.deepScanning then
            deepStatsLabel.Text = string.format("calls: %d | prompts: %d | spawns: %d",
                #State.deepData.remoteCalls, #State.deepData.promptHits, #State.deepData.spawns)
        end
        task.wait(1)
    end
end)

sec(TabDeep, "Captured Data (click = copy)")

local deepListFrame = create("Frame", {
    Size = UDim2.new(1, -8, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = nextOrder(),
    Parent = TabDeep
})
create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = deepListFrame})

local function showDeep(kind)
    clearList(deepListFrame)

    if kind == "calls" then
        for i, c in ipairs(State.deepData.remoteCalls) do
            if i > 60 then break end
            row(deepListFrame, "[" .. c.time .. "] " .. c.method .. "." .. c.remote,
                c.args, c.path .. " -- args: " .. c.args)
        end
        if #State.deepData.remoteCalls == 0 then
            label(deepListFrame, "no calls captured yet.", 20)
        end
    elseif kind == "prompts" then
        for i, c in ipairs(State.deepData.promptHits) do
            if i > 60 then break end
            row(deepListFrame, "[" .. c.time .. "] " .. c.prompt, c.path, c.path)
        end
        if #State.deepData.promptHits == 0 then
            label(deepListFrame, "no prompt hits.", 20)
        end
    elseif kind == "spawns" then
        for i, c in ipairs(State.deepData.spawns) do
            if i > 60 then break end
            row(deepListFrame, "[" .. c.time .. "] " .. c.name, c.path, c.path)
        end
        if #State.deepData.spawns == 0 then
            label(deepListFrame, "no spawns captured.", 20)
        end
    end
end

button(TabDeep, "View Remote Calls", function() showDeep("calls") end)
button(TabDeep, "View Prompt Hits", function() showDeep("prompts") end)
button(TabDeep, "View Spawns", function() showDeep("spawns") end)

-- ===== EXPORT =====
local TabExp = makeTab("Export", "⬇")

sec(TabExp, "Export Options")

local exportLabel = label(TabExp, "filename format: " .. safeGameName .. "_<timestamp>.txt", 18)

button(TabExp, "⬇ Export Full Report (TXT)", function()
    task.spawn(function()
        exportTXT()
        exportLabel.Text = "last saved: " .. (State.lastExportPath ~= "" and State.lastExportPath or "clipboard only")
    end)
end)

button(TabExp, "⬇ Export Sources as Individual .lua Files", function()
    task.spawn(exportSourcesToFiles)
end)

button(TabExp, "⬇ Export Remote Templates (.lua)", function()
    task.spawn(function()
        local t = generateTemplates()
        local saved = writeMultiPath(t, safeGameName .. "_templates", ".lua")
        if setclipboard then setclipboard(t) end
        notify("Templates", saved or "clipboard only", 5, Theme.success)
    end)
end)

button(TabExp, "⬇ Export Smart Templates (deep scan data)", function()
    task.spawn(function()
        local t = generateSmartTemplates()
        local saved = writeMultiPath(t, safeGameName .. "_smart", ".lua")
        if setclipboard then setclipboard(t) end
        notify("Smart Templates", saved or "clipboard only", 5, Theme.success)
    end)
end)

button(TabExp, "📋 Copy Full Report to Clipboard", function()
    task.spawn(exportTXT)
end)

-- ===== SETTINGS =====
local TabSet = makeTab("Settings", "⚙")

sec(TabSet, "Scan Config (auto-saved)")

toggle(TabSet, "Exclude Buildings", State.excludeBuildings, function(v)
    State.excludeBuildings = v
    persistConfig()
    notify("Setting", v and "Buildings excluded" or "Buildings included", 3)
end)

slider(TabSet, "Max Depth (0 = unlimited)", 0, 15, State.maxDepth, function(v)
    State.maxDepth = v
    persistConfig()
end)

sec(TabSet, "Accent Color")

local accentColors = {
    {name = "Purple", c = Color3.fromRGB(138, 99, 255)},
    {name = "Cyan",   c = Color3.fromRGB(0, 190, 255)},
    {name = "Green",  c = Color3.fromRGB(60, 220, 130)},
    {name = "Orange", c = Color3.fromRGB(255, 150, 50)},
    {name = "Red",    c = Color3.fromRGB(255, 80, 80)},
    {name = "Pink",   c = Color3.fromRGB(255, 100, 180)}
}

for _, ac in ipairs(accentColors) do
    button(TabSet, "●  " .. ac.name, function()
        setAccent(ac.c)
        persistConfig()
        notify("Theme", "Accent set to " .. ac.name, 2)
    end, 28)
end

-- ==============================================================
--  INIT
-- ==============================================================

gameLabel.Text = GameName:sub(1, 40)

-- restore saved accent
if CFG.accent and type(CFG.accent) == "table" and #CFG.accent == 3 then
    pcall(function()
        setAccent(Color3.fromRGB(CFG.accent[1], CFG.accent[2], CFG.accent[3]))
    end)
end

-- activate main tab
for _, t in pairs(tabs) do
    t.page.Visible = false
    t.btn.BackgroundColor3 = Theme.bg2
    t.lbl.TextColor3 = Theme.textDim
end
tabs["Main"].page.Visible = true
tabs["Main"].btn.BackgroundColor3 = Theme.bg3
tabs["Main"].lbl.TextColor3 = Theme.accent
activeTab = "Main"

-- open animation
Main.Size = UDim2.new(0, 760, 0, 0)
Main.Position = UDim2.new(0.5, -380, 0.5, 0)
tween(Main, {Size = UDim2.new(0, 760, 0, 480), Position = UDim2.new(0.5, -380, 0.5, -240)}, 0.35)

print("=== PHANTOM SCANNER v10.1 loaded ===")
print("=== Game: " .. GameName .. " ===")
print("=== Executor: " .. executorInfo .. " ===")
print("=== Keybind: RightCtrl = hide/show ===")

notify("Phantom Ready", GameName .. " | v10.1 loaded", 5, Theme.success)
setStatus("ready | RightCtrl hides | " .. executorInfo, Theme.success)
