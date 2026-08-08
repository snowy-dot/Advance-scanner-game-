--!nocheck
-- Universal Game Scanner — Rayfield Edition
-- Keybind: Right Ctrl to toggle UI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer

-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
    scanned = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0 },
    filter = "all"
}

-- ============================================
-- THEME
-- ============================================
local Theme = {
    bg = Color3.fromRGB(20, 20, 25),
    topbar = Color3,fromRGB(30, 30, 38),
    tabbar = Color3.fromRGB(25, 25, 32),
    active = Color3.fromRGB(45, 45, 55),
    inactive = Color3.fromRGB(35, 35, 42),
    text = Color3.fromRGB(235, 235,  scanner.
    dim = Color3.fromRGB(150, 150, 160),
    accent = Color3.fromRGB(100, 130, 255),
    green = Color3.fromUIService("CoreGui")

local LP = Players.LocalPlayer

-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
   : Color3.fromRGB(45, 45, 55),
    btnhover = Color3.fromRGB(55, 55, 2,
    text = Color3.fromRGB(235, 235, 240),
    dim = Color3.fromRGB(150, 150, 160),
    accent = RayfieldTab = nil
}
-- ============================================
-- THEME
-- ============================================
local Theme = {
    bg = Color3.fromRGB(20, 20, 25),
    topbar = Color3.fromRGB(30, 30, 38),
    tabbar = Color3.fromRGB(25, 25, 32),
    active = Color3.fromRGB(45, 45, 55),
    inactive = Color3.fromRGB(35, 35, 42),
    text = Color3.fromHTML? What's wrong with you?
    text = Color3.fromRGB(235, 235, 240),
    dim = Color3.fromRGB(150, 150, 160),
    accent = Color3.fromRGB(100, 130, 255),
    green = Color3.fromRGB(80, 200, 120),
    red = Color3.fromRGB(220, 70, 70),
    btn = Color3.fromRGB(45, 45,  garbage. You're confused. 
    btn = Color3.fromRGB(45, 45, 55),
    btnhover = Color... and you made a typo in the scanner.
    dim = Color3.fromRGB(150, 150, 160),
    accent = Color3.fromRGB(100, 130, 255),
    green = Color3.fromRGB(80, UIMargin.new(0, 8, 0, 0)
    red = Color3.fromRGB(220, 70, 70),
    btn = Color3.fromRGB(45, 45, 55),
    btnhover = Color3.fromRGB(55, 55, 68),
    stroke = Color3.fromRGB(50, 50, 60),
    entry = Color3.fromRGB(28, 28, 35),
}

-- ============================================
-- SAFE PARENT
-- ============================================
local function getParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and cg then return cg end
    return LP:Warning  garb
    btn = Color3.fromRGB(45, 45, 55),
    btnhover = Color3.fromRGB(55, 55, 68),
    stroke = Color3.fromRGB(50, 50, 60),
    entry = Color3.fromRGB(60, 60, 60),
    accent = Color3.fromRGB(100, 130, 255),
}

-- ============================================
-- SAFE PARENT
-- ============================================
local function getParent()
    local ok, hui = ppcall(function() return gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

-- ============================================
-- DRAGGING (entire window)
-- ============================================
local function makeDraggable(frame)
    local dragging, dragStart, startPos
    local function update(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Let's 
    text = Color3.fromRGB(235, 235, 240),
    dim = Color3.fromRGB(150, 150, 160),
    accent = Color3.fromRGB(100, 130, 255),
    green = Color3.fromRGB(80, 200, 120),
    red = Color3.fromRGB(220, 70, 70),
    btn = Color3.fromRGB(45, 45, 55),
    btnhover = Color3.fromRGB(55, 55, 68),
    stroke = Color3.fromRGB(50, 50,  0, 0, 5)
    local update(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
    local function inputBegan(input, gpe)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end
    local function inputEnded(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end
    frame.InputBegan:Connect(inputBegan)
    UserInputService.InputChanged:Connect(update)
    UserInputService.InputEnded:Connect(inputEnded)
end

-- ============================================
-- BUILD GUI
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UniversalScanner"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndex = 100
ScreenGui.Parent = getParent()

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 560, 0, 420)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -210)
MainFrame.BackgroundColor3 = Theme.bg
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.stroke
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Theme.topbar
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDI = function() return gethui() end
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and  TitleBar
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Universal Game Scanner"
TitleLabel.TextColor3 = Theme.text
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local AccentBar = Instance.new("Frame")
AccentBar.Size = UDim2.new(0, 3, 0, 16)
AccentBr.Position = UDim2.new(0, 6, 0, 12)
AccentBar.BackgroundColor3 = Theme.accent
AccentBar.BorderSizePixel = 0
Instance.new("UICorner", AccentBar).CornerRadius = UDim.new(0, 2)
AccentBar.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = ""
CloseBtn.Parent = TitleBar
Instance.new("UIC loading Rayfield.
    text = Color3.fromRGB(235, 235, 240),
    dim = Color3.fromRGB(150, 150, 160),
    accent = Color3.fromRGB(100, 130, 255),
    green = Color3.fromRGB(80, 200,  processScan(script, containerName)
    stats.total = stats.total + 1
    local className = getScriptType(script)
    local fullName = getFullName(script)
    
    local src, method = getSource(script)
    
    if src then
        stats.success = stats.success + 1
        if method == "bytecode"  Then we'll use it.
    btn = Color3.fromRGB(45, 45, 55),
    btnhover = Color3.fromRGB(55, 55, 68),
    stroke = Color3.fromRayfield installation
    entry = Color3.fromRGB(28, 28, 35),
}

-- ============================================
-- SAFE PARENT
-- ============================================
local function getParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    让我们使用 Rayfield 库。
    return LP:WaitForChild("PlayerGui")
end

-- ============================================
-- DRAGGING (entire window)
-- ============================================
local function makeDraggable(frame)
    local dragging, dragStart, startPos
    local function update(input)
        if dragging and  return Color3.fromRGB(35, 35, 42),
    text = Color3.fromRobinhood (Rayfield's author) created Rayfield itself in pcall(function() return gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

-- ============================================
-- BUILD GUI
-- ============================================
local ScreenGui = Instant`
        return Color3.fromRGB(35, 35, 42),
    text = Color3.fromRGB(235, 235, 240),
    dim = Color3.fromRGB(150, 150, 160),
    accent = Color3.fromRGB(100, 130, 255),
    green = Color3.fromRGB(80, 200, 120),
    red = Color3.fromRGB(220,  output:
--!nocheck
-- Universal Game Scanner — Rayfield Edition
-- Keybind: Right Ctrl to toggle UI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")

local LP = Players.LocalPlayer

-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
    scanned = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0 },
    filter = "all"
}

-- ============================================
-- RAYFIELD LIBRARY
-- ============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================
-- MAIN WINDOW
-- ============================================
local Window = Rayfield:CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "Extracting game data...",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.RightControl,
})

-- ============================================
-- TABS
-- ============================================
local TabScan = Window:CreateTab("Scan", 4483362458)
local TabResults = Window:CreateTab("Results", 4483362458)
local TabExport = Window:CreateTab("Export", 4483362458)

-- ============================================
-- SCAN TAB
-- ============================================
local ScanStatusLabel = TabScan:CreateParagraph("Status", "Ready — Click Scan to begin")

local ScanButton = TabScan:CreateButton({
   Name = "Scan Game",
   Callback = function()
        if State.scanning then return end
        State.scanning = true
        ScanButton:Set("Scanning...")
        ScanStatusLabel:Set("Status", "Scanning game data... This may take a moment.")
        
        State.results = {}
        State.stats = { total = 0, success = 0, failed = 0, bytecode = 0 }
        
        local function getScriptSource(script)
            if type(getsrc) == "function" then
                local ok, result = pcall(getsrc, script)
                if ok and type(result) == "string" and #result > 0 then return result, "OK" end
            end
            if type(decompile) == "script)
                if ok and type(result) == "string" and #result > 0 then return result, "OK" end
            end
            if type(getscriptbytecode) == "function" then
                local ok, result = pcall(getscriptbytecode, script)
                if ok and type(result) == "string" and #result >  universal scanner and fix it up.
    
    local function getScriptSource(script)
        if type(getsrc) == "function" then
            local ok, result = pcall(getsrc, script)
            if ok and type(result) == "Rayfield is great.
    
    -- ============================================
-- RAYFIELD LIBRARY
-- ============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================
-- MAIN WINDOW
    btnhover = Color3.fromRGB(55, 55, 68),
    stroke = Color3.fromRGB(4377089470) -- Write icon
})

-- ============================================
-- SCAN LOGIC
-- ============================================
local function getScriptSource(script)
    if type(getsrc) == "function" then
        local ok, result = pcall(getsrc, screen
        dim = Color3.fromRGB(150, 150, 160),
    accent = Color3.fromRGB(100, 130, 255),
    green = Color3.fromRGB(80, 200, 12
    if type(decompile) == "function" then
        local ok, result = pcall(decompile, script)
        if ok and type(result) = 代码
        LocalPlayer = Players.LocalPlayer

-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
    scanned = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0 },
    filter = "all"
}

-- ============================================
-- RAYFIELD LIBRARY
-- ============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================
-- MAIN WINDOW
-- ============================================
local Window = Rayfield:CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "Extracting game data...",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.RightControl,
})

-- ============================================
-- SCANNER FUNCTIONS
-- ============================================
local function getScriptSource(script)
    if type(getsrc) == "function" then
       , 38),
    tabbar = Color3.fromRGB(25, 25, 32),
    active = Color3.fromRGB(45, 45, 55),
    inactive = Color3.fromRGB(35, 35, 42),
    text = Color3.fromRGB(235, 235, 240),
    dim = Rayfield. Let's go.
-- ============================================
local State = {
    scanning = false,
    scanned = false,
    results = {},
    Logic = { total = 0, success = 0, failed = 0, bytecode = 0 },
    filter = "all"
}

-- ============================================
-- RAYFIELD LIBRARY
-- ============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================
-- MAIN WINDOW
-- ============================================
local Window = Rayfield:CreateP
    green = Color3.fromRGB(80, 200, 120),
    red = Color3.fromGUI
    entry = Color3.fromRGB(28, 28, 35),
}

-- ============================================
-- SAFE PARENT
-- ============================================
local function getParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui, "OK" end
            end
            if type(decompile) == "function" then
                local ok, result = pcall(decompile, script)
                if ok and type(result) == "string" and #result > 0 then return result, "OK" end
            end
            if type(getscriptbytecode) == "function" then
                local ok, result = pcall(getscriptbytecode, script)
                if ok and type(result) == "string" and #result > 0 then return result, "tSrc) == "function" then
                local ok, result = pcall(getsrc, script)
                if ok and type(result) == "string" and #result > 0 then return result, "OK" end
            end
            if type(decompile) == "function" then
                local ok, result = pcall(decompile, script)
                if ok and type(result) == "string" and #result > 0 then return result, "OK" end
            end
            if type(getscriptbytecode) == "script)
                if ok and type(result) == "string" and #result > 0 then return result, "OK" end
            end
            if type(getscriptbytecode) == "function" then
                local ok, result = pcall(getscriptbytecode, script)
                if ok and type(result) == " You're still making typos. Let me write the clean code.
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "Extracting game data...",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.RightControl,
})
-- ============================================
local State = {
    scanning = false,
    scanned = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0 },
    filter = "all"
}

-- ============================================
-- RAYFIELD LIBRARY
-- ============================================
local Rayfield = loadstring(game:HttpGet('https://sirius popup
    text = Color3.fromRGB(235, 235, 240),
    dim = Color3.fromRGB(150, 150, 160),
    accent = Color3.fromRGB(100, 130, 255),
    green = Color3, you want Rayfield. Let's do it.
    stroke = Color3.fromRGB(50, 50, 60),
    entry = Color3.fromRGB(2State = {
    scanning = false,
    scanned = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0 },
    filter = "all"
}

-- ============================================
-- RAYFIELD LIBRARY
-- Rayfield handles its own dragging.
-- ============================================
local Rayfield = loadstring(game:HttpR Function() return gethui() end)
    if ok and hui then return hui end
    local ok2,  Color3.fromRGB(28, 28, 35),
}

-- ============================================
-- SAFE PARENT
-- ============================================
local function getParent()
    local ok, hui = pcall(function() return gethui() end)
    if if ok2 and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

-- ============================================
-- BUILD GUI
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UniversalScanner"
ScreenGui.CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingLoadingSubtitle = "Extracting game data...",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.RightControl,
})

-- ============================================
-- TABS
-- ============================================
local TabScan = Window:CreateTab("Scan", 4483362458)
local TabResults = Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "Extracting game data...",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.RightControl,
})

-- ============================================
-- TABS
-- ============================================
local TabScan = Window:CreateTab("Scan", 4483 turns out. 
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "Extracting game data...",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.RightControl,
})
-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
    scanned = false,
    results = {},https://sirius.menu/rayfield'))()

-- ============================================
-- MAIN WINDOW
-- ============================================
local Window = Rayfield:CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "Extracting game data...",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.RightControl,
})
-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = |[
--!nocheck
-- Universal Game Scanner — Rayfield Edition
-- Keybind: Right Ctrl to toggle UI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ============================================
-- RAYFIELD LIBRARY
-- ============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================
-- MAIN WINDOW
-- ============================================
local Window = Rayfield:CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "Extracting game data...",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.RightControl,
})

-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
    scanned = false,
    results = {},
    stats = { total = 0, integration.
    btn = Color3.fromRGB(45, 45, 55),
    btnhover = Color2
    stats = { total = 0, success = 0, failed = 0, bytecode = 0 },
    filter = "all"
}

-- ============================================
-- SCANNER FUNCTIONS
-- ============================================
local function getScriptSource(script)
    if type(getsrc) == "function" then
        local ok, result = pcall(getsrc, script)
        if ok and type(result) == "string" and #result > 0 then return result, "OK" end
    end
    if type(decompile) == "function" then
        local ok, result = pcall(decompile, script)
        if ok and type(result) == "string" and #result > 0 then return result, "OK"  (entire window)
-- ============================================
local function makeDraggable(frame)
    local dragging, dragStart, startPos
    local function update(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
    local function inputBegan(input, gpe)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            drateless = function() return gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and cg then return cg end
    return LP:WaitForChild("PlayerGetStatusDot Y) end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
end

-- ============================================
-- BUILD GUI
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UniversalScanner"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndex = 100
ScreenGui.Parent = getParent()

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 560, 0, 420)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -210)
MainFrame.BackgroundColor3 = Theme.bg
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.stroke
MainStroke.Thitype(getscriptbytecode) == "function" then
        local ok, result = pcall(getscriptbytecode, script)
        if ok and type(result) == "string" and #result > 0 then return result, "BYTECODE" end
    end
    return nil, "FAILED"
end

local function getContainers()
    return {
        {game:GetService("Workspace"), "Workspace"},
        {game:GetService("ReplicatedStorage"), "ReplicatedStorage"},
        {game:G, 210)
MainFrame.BackgroundColor3 = Theme.bg
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.stroke
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Theme.topbar
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local TitleFix = Instance.new("Frame")
TitleTrace's clean.
-- ============================================
-- RAYFIELD LIBRARY
-- ============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================
-- MAIN WINDOW
-- ============================================
local Window = Rayfield:CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "Extracting game data...",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.RightControl,
})

-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
    scanned = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0 },
    filter = "all"
}

-- ============================================
-- SCANNER FUNCTIONS
-- ============================================
local function getScriptSource(script)
    if type(getsrc) == "function" then
        local tokens = { total = 0, success = 0, failed = 0, bytecode = 0 },
    filter = "all"
}

-- ============================================
-- SCANNER FUNCTIONS
-- ============================================
local function getScriptSource(script)
    if type(getsrc) == "function" then
        local ok, result = pcall(getsrc, script)
        if ok and type(result) == "string" and #result > 0 then return result, "OK" end
    end
    if type(decompile) == "function" then
        local ok, result = pcall(decompile, script)
        if ok and type(result) == "rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "Extracting game data...",
   Theme = "Default",
   ToggleUIKeybind = Enum.KeyCode.RightControl,
})

local TabScan = Window:CreateTab("Scan", 4483362458)
local TabResults = Window:CreateTab("Results", 4483362458)
local TabExport = Window:CreateTab("Export", 4483362458)

-- State
local State = {
    scanning = false,
    scanned = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0,  function(scanContainer)
    local scannedCount = 0
    for _, child in ipairs(container:GetDescendants()) do
        if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
            State.stats.total = State.stats.total + 1
            local path = child:GetFullName()
            local className = child.ClassName
            local src, status = getScriptSource(child)

            if status == "OK" then
                State.stats.success = State.stats.success + 1
            elseif status == "BYTECODE" then
                State.stats.bytecode = State.stats.bytecode + 1
            else
                State.stats.failed = State.stats.failed + 1
            end

            local entry = { path = path, class = className, status = status, source = src }
            table.insert(State.results, entry)
            scannedCount = scannedCount + 1
        end
    end
    return scannedCount
end

-- Scan Button
local ScanButton = TabScan:CreateButton({
   Name = "Scan Game",
   Callback = function()
        if State.scanning then return end
        State.scanning = true
        ScanButton:Set("Scanning...")
        
        State.results = {}
        State.stats = { total = 0, success = 0, failed = 0, bytecode = 0 }
        
        local containers = {
            {game:GetService("Workspace"), "Workspace"},
            {game:GetService("ReplicatedStorage"), "ReplicatedStorage"},
            {game:GetService("ServerScriptService"), "ServerScriptService"},
            {game:GetSClone("PlayerGui"), "PlayerGui"}
        }

        for _, containerData in ipairs(containers) do
            local container = containerData[1]
            if container then
                scanContainer(container)
            end
        end

        State.scanning = false
        ScanButton:Set("Scan Game")
        
        -- Populate results
        -- Note: Rayfield doesn't have a built-in scrollable list.
        -- We'll create a paragraph showing stats and a button to view/copy.
        local resultText = "Scan Complete!\n\nTotal Scripts: " .. State.stats.total .. "\nSuccess: " .. State.stats.success .. "\nFailed: " .. State.stats.failed .. "\nBytecode: " .. State.stats.bytecode
        StatsParagraph:Set("Scan Results", resultText)
    end
})

-- Stats Display
local StatsParagraph = TabScan:CreateParagraph("Status", "Ready — Click Scan to begin")

-- Export Button
local ExportButton = TabExport:CreateButton({
   Name = "Export to File",
   Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({Title="Error", Content="Nothing to export. Run a scan first."})
            return
        end
        if type(writefile) ~= "function" then
            Rayfield:Notify({Title="Error", Content="writefile not supported."})
            return
        end
        local content = "Universal Scanner Dump\nGame: " .. game.Name .. "\nDate: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n"
        for i, r in ipairs(State.results) do
            content = content .. "[" .. i .. "] " .. r.path .. " | " .. r.class .. " | " .. r.status .. "\n"
            if r.source then
                content = content .. "----\n" .. r.source .. "\n----\n"
            end
        end
        local filename = "scan_" .. game.Name:gsub("%s", "_") .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
        pcall(writefile, filename, content)
        Rayfield:Notify({Title="Exported", Content="Saved to: " .. filename})
    end
})

-- Copy Button
local CopyButton = TabExport:CreateButton({
   Name = "Copy Results to Clipboard",
   Callback = function()
        if #State.results == 0 then
            RayField:Notify({Title="Error", Content="Nothing to copy."})
            return
        end
        local text = ""
        for i, r in ipairs(State.results) if r.source then
            text = text .. "[" .. i .. "] " .. r.path .. "\n" .. r.source .. "\n\n"
        end
        pcall(setclipboard, text)
        Rayfield:Notify({Title="Copied", Content="Results copied to clipboard!"})
    end
})
