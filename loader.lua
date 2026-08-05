--!nocheck
-- ============================================================
-- APEX SCRIPT SCANNER v5.1 — NATIVE UI (NO EXTERNAL DEPENDENCY)
-- ============================================================

if getgenv().ScannerRunning then
    print("[Scanner] Already running. Skipping duplicate.")
    return
end
getgenv().ScannerRunning = true

-- ============================================================
-- APEX BYPASS LAYER
-- ============================================================
local BypassState = {
    HooksInstalled = false,
    OriginalGetInfo = nil,
    OriginalNamecall = nil,
    OriginalIndex = nil,
    OriginalError = nil,
    OriginalAssert = nil,
    Tampered = false,
}

local ScannerInstances = {}
local ScannerFunctions = {}

local function HideInstance(inst)
    if typeof(inst) == "Instance" then
        ScannerInstances[inst] = true
    end
end

local function HideFunction(fn)
    if type(fn) == "function" then
        ScannerFunctions[fn] = true
    end
end

local function InstallApexBypass()
    pcall(function()
        if hookfunction and not BypassState.HooksInstalled then
            local oldGetInfo = debug.getinfo
            BypassState.OriginalGetInfo = oldGetInfo

            local function FilteredGetInfo(...)
                local info = oldGetInfo(...)
                if info and type(info) == "table" then
                    if info.source then
                        if info.source:match("Scanner") or info.source:match("[Bb]ypass") then
                            info.source = "Workspace.GameScript"
                        end
                    end
                    if info.short_src then
                        if info.short_src:match("Scanner") or info.short_src:match("[Bb]ypass") then
                            info.short_src = "GameScript"
                        end
                    end
                    if info.func and ScannerFunctions[info.func] then
                        info.func = nil
                        info.source = "Workspace.GameScript"
                        info.short_src = "GameScript"
                        info.what = "C"
                    end
                end
                return info
            end
            hookfunction(debug.getinfo, FilteredGetInfo)
            HideFunction(FilteredGetInfo)
            BypassState.HooksInstalled = true
        end
    end)

    pcall(function()
        if hookmetamethod and not BypassState.OriginalNamecall then
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            BypassState.OriginalNamecall = oldNamecall

            setreadonly(mt, false)
            mt.__namecall = newcclosure and newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "GetFullName" and ScannerInstances[self] then
                    return "Workspace.GameScript"
                end
                if method == "FindService" then
                    local service = select(1, ...)
                    if service and (service:match("[Aa]nti[Cc]heat") or service:match("[Pp]rotect")) then
                        return nil
                    end
                end
                if method == "GetChildren" or method == "GetDescendants" then
                    local results = oldNamecall(self, ...)
                    if type(results) == "table" then
                        local filtered = {}
                        for _, v in ipairs(results) do
                            if not ScannerInstances[v] and v.Name ~= "Scanner" and v.Name ~= "ApexUI" then
                                table.insert(filtered, v)
                            end
                        end
                        return filtered
                    end
                end
                if method == "FindFirstChild" then
                    local name = select(1, ...)
                    if name and (name:match("[Ss]canner") or name:match("ApexUI")) then
                        return nil
                    end
                end
                if method == "IsA" and ScannerInstances[self] then
                    local className = select(1, ...)
                    if className == "LocalScript" or className == "Script" or className == "ModuleScript" then
                        return false
                    end
                end
                return oldNamecall(self, ...)
            end) or function(self, ...) return oldNamecall(self, ...) end
            setreadonly(mt, true)
        end
    end)

    pcall(function()
        local mt = getrawmetatable(game)
        if mt and hookmetamethod then
            setreadonly(mt, false)
            local oldIndex = mt.__index
            BypassState.OriginalIndex = oldIndex
            mt.__index = newcclosure and newcclosure(function(t, k)
                if k == "Name" and ScannerInstances[t] then return "GameScript" end
                if k == "ClassName" and ScannerInstances[t] then return "Script" end
                if k == "Disabled" and ScannerInstances[t] then return true end
                if (k == "Source" or k == "Bytecode") and ScannerInstances[t] then return "" end
                return oldIndex(t, k)
            end) or oldIndex
            setreadonly(mt, true)
        end
    end)

    pcall(function()
        if hookfunction then
            local oldError = error
            BypassState.OriginalError = oldError
            local function FilteredError(msg, level)
                if type(msg) == "string" and (msg:match("[Ss]canner") or msg:match("[Bb]ypass")) then
                    return oldError("Unexpected behavior", level)
                end
                return oldError(msg, level)
            end
            hookfunction(error, FilteredError)
            HideFunction(FilteredError)

            local oldAssert = assert
            BypassState.OriginalAssert = oldAssert
            local function FilteredAssert(cond, msg, ...)
                if type(msg) == "string" and (msg:match("[Ss]canner") or msg:match("[Bb]ypass")) then
                    return oldAssert(cond, "Assertion failed", ...)
                end
                return oldAssert(cond, msg, ...)
            end
            hookfunction(assert, FilteredAssert)
            HideFunction(FilteredAssert)

            local oldTraceback = debug.traceback
            local function FilteredTraceback(msg, level)
                local tb = oldTraceback(msg, level)
                if type(tb) == "string" then
                    tb = tb:gsub("[Ss]canner", "GameScript")
                    tb = tb:gsub("[Bb]ypass", "CoreScript")
                end
                return tb
            end
            hookfunction(debug.traceback, FilteredTraceback)
            HideFunction(FilteredTraceback)
        end
    end)

    pcall(function()
        if setidentity then setidentity(7) end
        if getthreadcontext then getthreadcontext(7) end
        if setthreadcontext then setthreadcontext(7) end
    end)

    -- Anti-tamper guard
    pcall(function()
        task.spawn(function()
            while true do
                task.wait(2)
                pcall(function()
                    local mt = getrawmetatable(game)
                    if mt and BypassState.OriginalNamecall then
                        if mt.__namecall == BypassState.OriginalNamecall then
                            BypassState.Tampered = true
                            InstallApexBypass()
                            return
                        end
                    end
                end)
            end
        end)
    end)
end

InstallApexBypass()
HideFunction(InstallApexBypass)

-- ============================================================
-- EXECUTOR CAPABILITIES
-- ============================================================
local Capabilities = {
    WriteFile = type(writefile) == "function",
    AppendFile = type(appendfile) == "function",
    IsFile = type(isfile) == "function",
    ReadFile = type(readfile) == "function",
    MakeFolder = type(makefolder) == "function",
    Decompile = type(decompile) == "function",
    GetScripts = type(getscripts) == "function",
    GetLoadedModules = type(getloadedmodules) == "function",
    GetNilInstances = type(getnilinstances) == "function",
    GetReg = type(getreg) == "function",
    GetScriptBytecode = type(getscriptbytecode) == "function",
    GetScriptClosure = type(getscriptclosure) == "function",
    SaveInstance = type(saveinstance) == "function",
    Loadstring = type(loadstring) == "function",
    HookFunction = type(hookfunction) == "function",
    HookMeta = type(hookmetamethod) == "function",
    GetRawMetatable = type(getrawmetatable) == "function",
    SetReadOnly = type(setreadonly) == "function",
    DebugGetUpvalues = type(debug.getupvalues) == "function",
    DebugGetConstants = type(debug.getconstants) == "function",
    CloneFunction = type(clonefunction) == "function",
    GetInstances = type(getinstances) == "function",
    GetConnections = type(getconnections) == "function",
    SetClipboard = type(setclipboard) == "function",
    Gethui = type(gethui) == "function",
    Newcclosure = type(newcclosure) == "function",
}

local ExecutorName = "Unknown"
if Capabilities.WriteFile then
    if Capabilities.GetReg and Capabilities.GetScriptBytecode and Capabilities.CloneFunction then
        ExecutorName = "Synapse X"
    elseif Capabilities.GetReg and Capabilities.GetScriptBytecode then
        ExecutorName = "Fluxus"
    elseif Capabilities.GetReg then
        ExecutorName = "Krnl/Hydrogen"
    elseif Capabilities.GetScriptClosure then
        ExecutorName = "Script-Ware"
    elseif Capabilities.Newcclosure then
        ExecutorName = "Wave/CodeX"
    else
        ExecutorName = "Compatible"
    end
end

-- ============================================================
-- GAME INFO
-- ============================================================
local function GetGameInfo()
    local info = {
        Name = "UnknownGame",
        PlaceId = game.PlaceId,
        Creator = "Unknown",
        JobId = game.JobId or "N/A",
    }
    pcall(function()
        local marketplace = game:GetService("MarketplaceService")
        local product = marketplace:GetProductInfo(game.PlaceId)
        if product then
            info.Name = string.gsub(product.Name or "UnknownGame", "[^%w_]", "_")
            info.Creator = product.Creator and product.Creator.Name or "Unknown"
        end
    end)
    if info.Name == "" or info.Name == "UnknownGame" then
        info.Name = "Place_" .. tostring(game.PlaceId)
    end
    return info
end

local GameInfo = GetGameInfo()

-- ============================================================
-- STATE
-- ============================================================
local ScanState = {
    IsScanning = false,
    IsPaused = false,
    IncludeBytecode = true,
    IncludeReg = true,
    IncludeNil = true,
    IncludeServer = true,
    DeepScan = true,
    IncludeRemotes = true,
    TotalScripts = 0,
    Processed = 0,
    Decompiled = 0,
    Failed = 0,
    BytecodeDumped = 0,
    RemotesFound = 0,
    StartTime = 0,
    CurrentFile = "",
    StatusText = "Ready",
    TimeText = "--:--",
    SuccessText = "Decompiled: 0 | Protected: 0 | Bytecode: 0",
    CountText = "Total Scripts: 0",
    FileText = "Save: Not started",
}

-- ============================================================
-- NATIVE UI — NO EXTERNAL DEPENDENCY
-- ============================================================
local UI = {}
local ScreenGui = nil
local MainFrame = nil
local TabButtons = {}
local TabPages = {}
local ActiveTab = nil
local UIElements = {}

local function GetParent()
    local parent = game:GetService("CoreGui")
    pcall(function()
        if Capabilities.Gethui then
            parent = gethui()
        end
    end)
    return parent
end

local function MakeDraggable(frame)
    local dragging = false
    local dragStart, startPos

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function CreateElement(className, props, parent)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    if parent then inst.Parent = parent end
    return inst
end

-- Colors
local C = {
    BG = Color3.fromRGB(20, 20, 25),
    BG2 = Color3.fromRGB(30, 30, 38),
    Accent = Color3.fromRGB(88, 101, 242),
    Accent2 = Color3.fromRGB(120, 130, 255),
    Text = Color3.fromRGB(230, 230, 235),
    TextDim = Color3.fromRGB(150, 150, 160),
    Green = Color3.fromRGB(87, 242, 135),
    Red = Color3.fromRGB(237, 66, 69),
    Yellow = Color3.fromRGB(254, 231, 92),
    ToggleOff = Color3.fromRGB(50, 50, 55),
    ToggleOn = Color3.fromRGB(87, 242, 135),
}

function BuildUI()
    -- Destroy old UI if exists
    pcall(function()
        local parent = GetParent()
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == "ApexUI" then
                child:Destroy()
            end
        end
    end)

    ScreenGui = CreateElement("ScreenGui", {
        Name = "ApexUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
        IgnoreGuiInset = true,
    })
    pcall(function() ScreenGui.Parent = GetParent() end)
    HideInstance(ScreenGui)

    -- Main window frame
    MainFrame = CreateElement("Frame", {
        Name = "MainWindow",
        Size = UDim2.new(0, 520, 0, 420),
        Position = UDim2.new(0.5, -260, 0.5, -210),
        BackgroundColor3 = C.BG,
        BorderSizePixel = 0,
        Active = true,
    }, ScreenGui)

    -- Rounded corners
    CreateElement("UICorner", { CornerRadius = UDim.new(0, 8) }, MainFrame)

    -- Drop shadow
    CreateElement("UIStroke", {
        Color = Color3.fromRGB(0, 0, 0),
        Thickness = 1,
        Transparency = 0.5,
    }, MainFrame)

    -- Title bar
    local TitleBar = CreateElement("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C.Accent,
        BorderSizePixel = 0,
    }, MainFrame)
    CreateElement("UICorner", { CornerRadius = UDim.new(0, 8) }, TitleBar)

    -- Fix bottom corners of title bar
    CreateElement("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = C.Accent,
        BorderSizePixel = 0,
    }, TitleBar)

    local TitleLabel = CreateElement("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "APEX SCRIPT SCANNER v5.1",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, TitleBar)

    -- Close button
    local CloseBtn = CreateElement("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -32, 0, 4),
        BackgroundColor3 = C.Red,
        Text = "X",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    }, TitleBar)
    CreateElement("UICorner", { CornerRadius = UDim.new(0, 6) }, CloseBtn)
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        getgenv().ScannerRunning = false
    end)

    -- Minimize button
    local MinBtn = CreateElement("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -64, 0, 4),
        BackgroundColor3 = C.BG2,
        Text = "—",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    }, TitleBar)
    CreateElement("UICorner", { CornerRadius = UDim.new(0, 6) }, MinBtn)

    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            MainFrame.Size = UDim2.new(0, 520, 0, 36)
        else
            MainFrame.Size = UDim2.new(0, 520, 0, 420)
        end
    end)

    MakeDraggable(TitleBar)

    -- Tab bar
    local TabBar = CreateElement("Frame", {
        Name = "TabBar",
        Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundColor3 = C.BG2,
        BorderSizePixel = 0,
    }, MainFrame)

    -- Content area
    local ContentArea = CreateElement("Frame", {
        Name = "Content",
        Size = UDim2.new(1, 0, 1, -68),
        Position = UDim2.new(0, 0, 0, 68),
        BackgroundColor3 = C.BG,
        BorderSizePixel = 0,
    }, MainFrame)

    -- Scrolling frame for tab content
    local ContentScroller = CreateElement("ScrollingFrame", {
        Name = "Scroller",
        Size = UDim2.new(1, -16, 1, -8),
        Position = UDim2.new(0, 8, 0, 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, ContentArea)

    -- Tab system
    local tabOrder = {}
    local function CreateTab(name, icon)
        local tabPage = CreateElement("Frame", {
            Name = name,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
        }, ContentScroller)

        local layout = CreateElement("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, tabPage)

        local tabBtn = CreateElement("TextButton", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = C.BG,
            Text = name,
            TextColor3 = C.TextDim,
            TextSize = 13,
            Font = Enum.Font.GothamSemibold,
            BorderSizePixel = 0,
            AutoButtonColor = false,
        }, TabBar)

        CreateElement("UICorner", { CornerRadius = UDim.new(0, 0) }, tabBtn)

        -- Auto-size tab buttons
        table.insert(tabOrder, tabBtn)

        local function UpdateTabSizes()
            local count = #tabOrder
            local width = 1 / count
            for i, btn in ipairs(tabOrder) do
                btn.Size = UDim2.new(width, -2, 1, 0)
                btn.Position = UDim2.new(width * (i - 1), 1, 0, 0)
            end
        end
        UpdateTabSizes()

        tabBtn.MouseButton1Click:Connect(function()
            for _, btn in ipairs(tabOrder) do
                btn.TextColor3 = C.TextDim
                btn.BackgroundColor3 = C.BG
            end
            tabBtn.TextColor3 = C.Text
            tabBtn.BackgroundColor3 = C.Accent

            for _, page in ipairs(TabPages) do
                page.Visible = false
            end
            tabPage.Visible = true
            ActiveTab = tabPage
        end)

        table.insert(TabPages, tabPage)

        -- Auto-activate first tab
        if #tabOrder == 1 then
            tabBtn.TextColor3 = C.Text
            tabBtn.BackgroundColor3 = C.Accent
            tabPage.Visible = true
            ActiveTab = tabPage
        end

        -- Helper functions for this tab
        local tab = {}

        function tab:CreateLabel(text)
            local label = CreateElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = C.Text,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                LayoutOrder = #tabPage:GetChildren(),
            }, tabPage)
            table.insert(UIElements, {obj = label, type = "label"})
            return {
                Set = function(newText)
                    label.Text = newText
                end
            }
        end

        function tab:CreateParagraph(title, content)
            local frame = CreateElement("Frame", {
                Size = UDim2.new(1, 0, 0, 60),
                BackgroundColor3 = C.BG2,
                BorderSizePixel = 0,
                LayoutOrder = #tabPage:GetChildren(),
            }, tabPage)
            CreateElement("UICorner", { CornerRadius = UDim.new(0, 6) }, frame)

            local tLabel = CreateElement("TextLabel", {
                Size = UDim2.new(1, -16, 0, 18),
                Position = UDim2.new(0, 8, 0, 6),
                BackgroundTransparency = 1,
                Text = title,
                TextColor3 = C.Accent2,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, frame)

            local cLabel = CreateElement("TextLabel", {
                Size = UDim2.new(1, -16, 0, 36),
                Position = UDim2.new(0, 8, 0, 24),
                BackgroundTransparency = 1,
                Text = content,
                TextColor3 = C.TextDim,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
            }, frame)

            -- Auto-resize frame
            local lines = select(2, content:gsub("\n", "\n")) + 1
            frame.Size = UDim2.new(1, 0, 0, 24 + (lines * 14) + 6)
        end

        function tab:CreateButton(name, callback)
            local btn = CreateElement("TextButton", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = C.BG2,
                Text = "",
                BorderSizePixel = 0,
                AutoButtonColor = true,
                LayoutOrder = #tabPage:GetChildren(),
            }, tabPage)
            CreateElement("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)

            local label = CreateElement("TextLabel", {
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = C.Text,
                TextSize = 12,
                Font = Enum.Font.GothamSemibold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, btn)

            local arrow = CreateElement("TextLabel", {
                Size = UDim2.new(0, 20, 1, 0),
                Position = UDim2.new(1, -24, 0, 0),
                BackgroundTransparency = 1,
                Text = "→",
                TextColor3 = C.Accent2,
                TextSize = 14,
                Font = Enum.Font.GothamBold,
            }, btn)

            btn.MouseButton1Click:Connect(function()
                pcall(callback)
            end)

            return { Callback = callback }
        end

        function tab:CreateToggle(name, defaultVal, callback)
            local frame = CreateElement("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = C.BG2,
                BorderSizePixel = 0,
                LayoutOrder = #tabPage:GetChildren(),
            }, tabPage)
            CreateElement("UICorner", { CornerRadius = UDim.new(0, 6) }, frame)

            local label = CreateElement("TextLabel", {
                Size = UDim2.new(1, -60, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = C.Text,
                TextSize = 12,
                Font = Enum.Font.GothamSemibold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, frame)

            local toggleBtn = CreateElement("TextButton", {
                Size = UDim2.new(0, 40, 0, 20),
                Position = UDim2.new(1, -48, 0.5, -10),
                BackgroundColor3 = defaultVal and C.ToggleOn or C.ToggleOff,
                Text = "",
                BorderSizePixel = 0,
            }, frame)
            CreateElement("UICorner", { CornerRadius = UDim.new(0, 10) }, toggleBtn)

            local knob = CreateElement("Frame", {
                Size = UDim2.new(0, 16, 0, 16),
                Position = defaultVal and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
            }, toggleBtn)
            CreateElement("UICorner", { CornerRadius = UDim.new(0, 8) }, knob)

            local toggled = defaultVal
            toggleBtn.MouseButton1Click:Connect(function()
                toggled = not toggled
                toggleBtn.BackgroundColor3 = toggled and C.ToggleOn or C.ToggleOff
                if toggled then
                    knob:TweenPosition(UDim2.new(1, -18, 0.5, -8), "Out", "Quad", 0.15, true)
                else
                    knob:TweenPosition(UDim2.new(0, 2, 0.5, -8), "Out", "Quad", 0.15, true)
                end
                pcall(callback, toggled)
            end)

            return { Set = function(val) toggled = val; toggleBtn.BackgroundColor3 = val and C.ToggleOn or C.ToggleOff end }
        end

        function tab:CreateDivider()
            CreateElement("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = C.BG2,
                BorderSizePixel = 0,
                LayoutOrder = #tabPage:GetChildren(),
            }, tabPage)
        end

        function tab:CreateSection(name)
            local label = CreateElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = C.Accent2,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = #tabPage:GetChildren(),
            }, tabPage)
        end

        return tab
    end

    -- ── BUILD TABS ──

    -- MAIN TAB
    local mainTab = CreateTab("Scanner")

    mainTab:CreateParagraph("Game Info",
        string.format("Name: %s\nID: %d\nCreator: %s\nExecutor: %s\nJobID: %s",
            GameInfo.Name, GameInfo.PlaceId, GameInfo.Creator, ExecutorName, GameInfo.JobId))

    mainTab:CreateDivider()
    mainTab:CreateSection("Scan Options")

    mainTab:CreateToggle("Include Bytecode Dump", true, function(v) ScanState.IncludeBytecode = v end)
    mainTab:CreateToggle("Include Registry Scan (getreg)", true, function(v) ScanState.IncludeReg = v end)
    mainTab:CreateToggle("Include Nil Instances", true, function(v) ScanState.IncludeNil = v end)
    mainTab:CreateToggle("Include Server Scripts (SSS/RS/SS)", true, function(v) ScanState.IncludeServer = v end)
    mainTab:CreateToggle("Deep Scan (upvalues/constants)", true, function(v) ScanState.DeepScan = v end)
    mainTab:CreateToggle("Remote Event Spy", true, function(v) ScanState.IncludeRemotes = v end)

    mainTab:CreateDivider()
    mainTab:CreateSection("Status")

    local StatusLabel = mainTab:CreateLabel("Status: Ready")
    local TimeLabel = mainTab:CreateLabel("Time Remaining: --:--")
    local FileLabel = mainTab:CreateLabel("Save Location: Not started")
    local CountLabel = mainTab:CreateLabel("Total Scripts Found: 0")
    local SuccessLabel = mainTab:CreateLabel("Decompiled: 0 | Protected: 0 | Bytecode: 0")

    mainTab:CreateDivider()
    mainTab:CreateButton("Start Full Scan", RunScanner)

    mainTab:CreateButton("Toggle Pause", function()
        if not ScanState.IsScanning then return end
        ScanState.IsPaused = not ScanState.IsPaused
        ScanState.StatusText = ScanState.IsPaused and "PAUSED" or "Resuming..."
    end)

    mainTab:CreateButton("Stop Scan", function()
        ScanState.IsScanning = false
        ScanState.IsPaused = false
        ScanState.StatusText = "STOPPED"
        getgenv().ScannerRunning = false
    end)

    -- ADVANCED TAB
    local advTab = CreateTab("Advanced")

    advTab:CreateParagraph("Advanced Tools", "Deep extraction methods for protected/locked scripts")

    advTab:CreateButton("Dump All Bytecode (Raw Hex)", function() task.spawn(DumpAllBytecode) end)
    advTab:CreateButton("Scan Registry Closures (getreg)", function() task.spawn(ScanRegistry) end)
    advTab:CreateButton("Dump ServerScriptService", function() task.spawn(DumpServerScripts) end)
    advTab:CreateButton("Dump Nil Instances", function() task.spawn(DumpNilInstances) end)
    advTab:CreateButton("Dump All Connections", function() task.spawn(DumpConnections) end)

    advTab:CreateButton("Export Full Game (saveinstance)", function()
        if Capabilities.SaveInstance then
            pcall(function() saveinstance({ filename = GameInfo.Name .. "_FullExport.rbxl" }) end)
        end
    end)

    advTab:CreateButton("Reinstall Bypass Hooks", function() InstallApexBypass() end)

    advTab:CreateButton("Print Executor Capabilities", function()
        print("=== EXECUTOR CAPABILITIES ===")
        for k, v in pairs(Capabilities) do
            print(string.format("  %s: %s", k, tostring(v)))
        end
        print(string.format("  Executor: %s", ExecutorName))
        print("=============================")
    end)

    -- REMOTE SPY TAB
    local remoteTab = CreateTab("Remote Spy")

    remoteTab:CreateParagraph("Remote Event Monitor",
        "Tracks all RemoteEvents and RemoteFunctions in the game")

    local RemoteCountLabel = remoteTab:CreateLabel("Remotes Found: 0")
    local RemoteConnLabel = remoteTab:CreateLabel("Connections: 0")

    remoteTab:CreateButton("Start Remote Spy", function()
        StartRemoteSpy()
    end)

    remoteTab:CreateButton("Export Remote Log", function()
        local path = GameInfo.Name .. "_RemoteSpy.txt"
        local content = "=== REMOTE SPY DUMP ===\n\n"
        for name, data in pairs(RemotesLog) do
            content = content .. string.format("Name: %s\nType: %s\n---\n", data.Name, data.Type)
        end
        SafeWriteFile(path, content)
    end)

    remoteTab:CreateButton("Fire All Remotes (Test)", function()
        pcall(function()
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    pcall(function() obj:FireServer() end)
                end
            end
        end)
    end)

    -- UI Updater loop
    task.spawn(function()
        while true do
            task.wait(0.3)
            pcall(function()
                StatusLabel:Set(ScanState.StatusText)
                TimeLabel:Set(ScanState.TimeText)
                FileLabel:Set(ScanState.FileText)
                CountLabel:Set(ScanState.CountText)
                SuccessLabel:Set(ScanState.SuccessText)
                RemoteCountLabel:Set("Remotes Found: " .. ScanState.RemotesFound)
                RemoteConnLabel:Set("Connections: " .. ScanState.ConnectionsFound)
            end)
        end
    end)

    -- UI Watcher — auto-rebuild if destroyed
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function()
                if not ScreenGui or not ScreenGui.Parent then
                    print("[Scanner] UI destroyed. Rebuilding...")
                    BuildUI()
                end
            end)
        end
    end)

    -- Notify on load
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Apex Scanner Ready",
            Text = string.format("%s | %s", GameInfo.Name, ExecutorName),
            Duration = 4
        })
    end)

    print("========================================")
    print("  APEX SCRIPT SCANNER v5.1 — NATIVE UI")
    print("  Executor: " .. ExecutorName)
    print("  Bypass: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
    print("  Bytecode: " .. (Capabilities.GetScriptBytecode and "SUPPORTED" or "UNSUPPORTED"))
    print("========================================")
end

-- ============================================================
-- SAFE WRITE UTILITIES
-- ============================================================
local function SafeWriteFile(path, content)
    pcall(function() writefile(path, content) end)
end

local function SafeAppendFile(path, content)
    pcall(function() appendfile(path, content) end)
end

-- ============================================================
-- REMOTE SPY
-- ============================================================
local RemotesLog = {}
local RemoteSpyActive = false

function StartRemoteSpy()
    RemoteSpyActive = true
    task.spawn(function()
        while RemoteSpyActive do
            pcall(function()
                for _, obj in ipairs(game:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        local fullName = obj:GetFullName()
                        if not RemotesLog[fullName] then
                            RemotesLog[fullName] = {
                                Name = fullName,
                                Type = obj.ClassName,
                                Hits = 0,
                            }
                            ScanState.RemotesFound = ScanState.RemotesFound + 1
                        end
                    end
                end
            end)
            task.wait(5)
        end
    end)

    pcall(function()
        if Capabilities.GetConnections then
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    local conns = getconnections(obj.OnClientEvent)
                    for _, conn in ipairs(conns) do
                        ScanState.ConnectionsFound = ScanState.ConnectionsFound + 1
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- SCRIPT COLLECTOR
-- ============================================================
local function CollectEverything()
    local collected = {}
    local seen = {}

    local function addScript(scriptObj, source)
        if typeof(scriptObj) ~= "Instance" then return end
        local isScript = false
        pcall(function()
            if scriptObj:IsA("Script") or scriptObj:IsA("LocalScript") or
               scriptObj:IsA("ModuleScript") or scriptObj:IsA("BaseScript") then
                isScript = true
            end
        end)
        if not isScript then return end

        local fullName = "Unknown"
        local className = "Unknown"
        local isDisabled = false
        pcall(function()
            fullName = scriptObj:GetFullName()
            className = scriptObj.ClassName
            isDisabled = scriptObj.Disabled == true
        end)

        local key = fullName .. "|" .. tostring(scriptObj)
        if seen[key] then return end
        seen[key] = true

        table.insert(collected, {
            Object = scriptObj,
            Name = fullName,
            Class = className,
            Disabled = isDisabled,
            Source = source or "Unknown"
        })
    end

    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do addScript(obj, "GameTree") end
    end)

    if ScanState.IncludeServer then
        pcall(function()
            local sss = game:GetService("ServerScriptService")
            for _, obj in ipairs(sss:GetDescendants()) do addScript(obj, "SSS") end
        end)
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            for _, obj in ipairs(rs:GetDescendants()) do addScript(obj, "RS") end
        end)
        pcall(function()
            local ss = game:GetService("ServerStorage")
            for _, obj in ipairs(ss:GetDescendants()) do addScript(obj, "SS") end
        end)
        pcall(function()
            local sp = game:GetService("StarterPlayer")
            if sp then
                local sps = sp:FindFirstChild("StarterPlayerScripts")
                if sps then for _, obj in ipairs(sps:GetDescendants()) do addScript(obj, "SPS") end end
                local spc = sp:FindFirstChild("StarterCharacterScripts")
                if spc then for _, obj in ipairs(spc:GetDescendants()) do addScript(obj, "SPC") end end
            end
        end)
        pcall(function()
            local sg = game:GetService("StarterGui")
            for _, obj in ipairs(sg:GetDescendants()) do addScript(obj, "SG") end
        end)
        pcall(function()
            local sp = game:GetService("StarterPack")
            for _, obj in ipairs(sp:GetDescendants()) do addScript(obj, "SP") end
        end)
    end

    if Capabilities.GetScripts then
        pcall(function()
            for _, s in ipairs(getscripts()) do addScript(s, "getscripts()") end
        end)
    end
    if Capabilities.GetLoadedModules then
        pcall(function()
            for _, s in ipairs(getloadedmodules()) do addScript(s, "getloadedmodules()") end
        end)
    end
    if ScanState.IncludeNil and Capabilities.GetNilInstances then
        pcall(function()
            for _, s in ipairs(getnilinstances()) do addScript(s, "getnilinstances()") end
        end)
    end
    if Capabilities.GetInstances then
        pcall(function()
            for _, inst in ipairs(getinstances()) do addScript(inst, "getinstances()") end
        end)
    end

    -- Registry scan
    if ScanState.IncludeReg and Capabilities.GetReg then
        pcall(function()
            local reg = getreg()
            for _, v in ipairs(reg) do
                if type(v) == "function" then
                    local isLua = true
                    if Capabilities.Newcclosure then isLua = islclosure(v) end
                    if isLua then
                        local info = debug.getinfo(v)
                        if info and info.what == "Lua" and info.source and #info.source > 0 then
                            local scriptName = info.short_src or info.source
                            table.insert(collected, {
                                Object = nil,
                                Closure = v,
                                Name = scriptName,
                                Class = "Closure",
                                Disabled = false,
                                Source = "getreg()"
                            })
                        end
                    end
                end
            end
        end)
    end

    -- Upvalue chain walk
    if ScanState.DeepScan and Capabilities.DebugGetUpvalues and Capabilities.GetReg then
        pcall(function()
            local reg = getreg()
            for _, v in ipairs(reg) do
                if type(v) == "function" then
                    local upvals = debug.getupvalues(v)
                    if upvals then
                        for _, uv in ipairs(upvals) do
                            if typeof(uv) == "Instance" then
                                addScript(uv, "upvalue-chain")
                            end
                        end
                    end
                end
            end
        end)
    end

    return collected
end

-- ============================================================
-- DECOMPILE — 7 METHOD CHAIN
-- ============================================================
local function DecompileScript(scriptObj, closure)
    -- Method 1: decompile(Instance)
    if Capabilities.Decompile and scriptObj then
        local result = nil
        pcall(function() result = decompile(scriptObj) end)
        if result and #result > 10 then return result, "decompiled" end

        pcall(function() result = decompile(scriptObj, true) end)
        if result and #result > 10 then return result, "decompile(true)" end
    end

    -- Method 2: getscriptclosure → decompile
    if Capabilities.GetScriptClosure and scriptObj then
        local cl = nil
        pcall(function() cl = getscriptclosure(scriptObj) end)
        if cl then
            if Capabilities.Decompile then
                local result = nil
                pcall(function() result = decompile(cl) end)
                if result and #result > 10 then return result, "closure+decompile" end
            end
            closure = closure or cl
        end
    end

    -- Method 3: .Source property
    if scriptObj then
        local result = nil
        pcall(function() result = scriptObj.Source end)
        if result and #result > 10 then return "-- .Source\n" .. result, ".Source" end

        pcall(function()
            local mt = getrawmetatable(scriptObj)
            if mt then
                setreadonly(mt, false)
                result = rawget(scriptObj, "Source")
                setreadonly(mt, true)
            end
        end)
        if result and #result > 10 then return "-- rawget .Source\n" .. result, "rawget(.Source)" end
    end

    -- Method 4: Bytecode hex dump
    if Capabilities.GetScriptBytecode and scriptObj then
        local bytecode = nil
        pcall(function() bytecode = getscriptbytecode(scriptObj) end)
        if bytecode and #bytecode > 0 then
            local hexDump = {}
            local len = #bytecode
            local limit = math.min(len, 50000)

            for i = 1, limit, 16 do
                local hexLine = ""
                local asciiLine = ""
                for j = 0, 15 do
                    if i + j <= limit then
                        local byte = string.byte(bytecode, i + j) or 0
                        hexLine = hexLine .. string.format("%02X ", byte)
                        asciiLine = asciiLine .. (byte >= 32 and byte < 127 and string.char(byte) or ".")
                    end
                end
                table.insert(hexDump, string.format("%08X  %-48s  %s", i - 1, hexLine, asciiLine))
            end

            local stringsFound = {}
            for match in bytecode:gmatch("[%w%p ]{4,}") do
                if #match >= 4 and #match <= 200 then table.insert(stringsFound, match) end
            end

            local stringSection = ""
            if #stringsFound > 0 then
                stringSection = "\n\n-- STRING CONSTANTS:\n"
                for i, s in ipairs(stringsFound) do
                    if i > 100 then break end
                    stringSection = stringSection .. string.format("  [%d] %q\n", i, s)
                end
            end

            ScanState.BytecodeDumped = ScanState.BytecodeDumped + 1
            return "-- BYTECODE DUMP\n-- Length: " .. len .. " bytes\n\n" .. table.concat(hexDump, "\n") .. stringSection, "bytecode"
        end
    end

    -- Method 5: Closure analysis
    if closure and ScanState.DeepScan then
        local result = "-- CLOSURE ANALYSIS\n\n"

        pcall(function()
            if Capabilities.DebugGetUpvalues then
                local upvals = debug.getupvalues(closure)
                if upvals and #upvals > 0 then
                    result = result .. "-- UPVALUES (" .. #upvals .. "):\n"
                    for i, v in ipairs(upvals) do
                        result = result .. string.format("  [%d] %s: %s\n", i, type(v), tostring(v):sub(1, 300))
                        if typeof(v) == "Instance" then
                            pcall(function() result = result .. string.format("      → %s (%s)\n", v:GetFullName(), v.ClassName) end)
                        end
                    end
                end
            end
        end)

        pcall(function()
            if Capabilities.DebugGetConstants then
                local consts = debug.getconstants(closure)
                if consts and #consts > 0 then
                    result = result .. "\n-- CONSTANTS (" .. #consts .. "):\n"
                    for i, v in ipairs(consts) do
                        result = result .. string.format("  [%d] %s: %s\n", i, type(v), tostring(v):sub(1, 300))
                    end
                end
            end
        end)

        pcall(function()
            local info = debug.getinfo(closure)
            if info then
                result = result .. "\n-- DEBUG INFO:\n"
                result = result .. "  source: " .. tostring(info.source) .. "\n"
                result = result .. "  lines: " .. tostring(info.linedefined) .. "-" .. tostring(info.lastlinedefined) .. "\n"
                result = result .. "  what: " .. tostring(info.what) .. "\n"
            end
        end)

        if #result > 50 then return result, "closure-analysis" end
    end

    return "-- DECOMPILE FAILED — All methods exhausted.\n", "failed"
end

-- ============================================================
-- FILE MANAGEMENT
-- ============================================================
local MAX_FILE_SIZE = 10 * 1024 * 1024
local currentFileSize = 0
local filePart = 1
local writeBuffer = {}
local bufferSize = 0
local MAX_BUFFER_SIZE = 1024 * 1024

local function GetFilePath(part)
    return GameInfo.Name .. "_Scripts_Part_" .. part .. ".txt"
end

local function FlushBuffer()
    if #writeBuffer == 0 then return end
    local chunk = table.concat(writeBuffer, "\n")
    writeBuffer = {}
    bufferSize = 0

    if currentFileSize + #chunk > MAX_FILE_SIZE then
        filePart = filePart + 1
        local path = GetFilePath(filePart)
        SafeWriteFile(path, string.format("=== APEX SCAN PART %d ===\nDate: %s\n\n", filePart, os.date("%Y-%m-%d %H:%M:%S")))
        currentFileSize = 0
        ScanState.CurrentFile = path
        ScanState.FileText = "Save: " .. path
    end

    SafeAppendFile(ScanState.CurrentFile, chunk)
    currentFileSize = currentFileSize + #chunk
end

local function InitializeFile()
    filePart = 1
    ScanState.CurrentFile = GetFilePath(1)
    SafeWriteFile(ScanState.CurrentFile,
        string.format("=== APEX SCRIPT SCAN: %s ===\nGame ID: %d | JobID: %s\nExecutor: %s\nDate: %s\n\n",
            GameInfo.Name, GameInfo.PlaceId, GameInfo.JobId, ExecutorName, os.date("%Y-%m-%d %H:%M:%S")))
    currentFileSize = 0
    ScanState.FileText = "Save: " .. ScanState.CurrentFile
end

-- ============================================================
-- ADVANCED TOOLS
-- ============================================================
function DumpAllBytecode()
    task.spawn(function()
        if not Capabilities.GetScriptBytecode then return end
        ScanState.StatusText = "Dumping bytecode..."
        local allScripts = {}
        pcall(function()
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    table.insert(allScripts, obj)
                end
            end
        end)
        local path = GameInfo.Name .. "_BytecodeDump.txt"
        SafeWriteFile(path, "=== BYTECODE DUMP ===\n")
        local count = 0
        for i, s in ipairs(allScripts) do
            pcall(function()
                local bc = getscriptbytecode(s)
                if bc and #bc > 0 then
                    SafeAppendFile(path, string.format("\n%s\n%s\nLength: %d bytes\n", string.rep("=", 60), s:GetFullName(), #bc))
                    count = count + 1
                end
            end)
            ScanState.StatusText = string.format("Bytecode: %d/%d", i, #allScripts)
            task.wait()
        end
        ScanState.StatusText = "Bytecode done: " .. count
    end)
end

function ScanRegistry()
    task.spawn(function()
        if not Capabilities.GetReg then return end
        ScanState.StatusText = "Scanning registry..."
        local path = GameInfo.Name .. "_RegistryDump.txt"
        SafeWriteFile(path, "=== REGISTRY DUMP ===\n\n")
        local count = 0
        local reg = getreg()
        for _, v in ipairs(reg) do
            if type(v) == "function" then
                local info = debug.getinfo(v)
                if info and info.source and #info.source > 0 then
                    local entry = string.format("Function: %s\n  Source: %s\n  Lines: %s-%s\n", tostring(v), info.short_src or info.source, tostring(info.linedefined), tostring(info.lastlinedefined))
                    pcall(function()
                        if Capabilities.DebugGetUpvalues then
                            local upvals = debug.getupvalues(v)
                            if upvals then
                                for i, uv in ipairs(upvals) do
                                    entry = entry .. string.format("  [%d] %s: %s\n", i, type(uv), tostring(uv):sub(1, 200))
                                end
                            end
                        end
                    end)
                    entry = entry .. string.rep("-", 40) .. "\n"
                    SafeAppendFile(path, entry)
                    count = count + 1
                    if count % 50 == 0 then task.wait() end
                end
            end
        end
        ScanState.StatusText = "Registry done: " .. count
    end)
end

function DumpServerScripts()
    task.spawn(function()
        ScanState.StatusText = "Dumping server scripts..."
        local path = GameInfo.Name .. "_ServerScripts.txt"
        SafeWriteFile(path, "=== SERVER SCRIPT DUMP ===\n\n")
        local services = { "ServerScriptService", "ServerStorage", "ReplicatedStorage", "StarterPlayer", "StarterGui", "StarterPack" }
        local count = 0
        for _, serviceName in ipairs(services) do
            pcall(function()
                local service = game:GetService(serviceName)
                for _, obj in ipairs(service:GetDescendants()) do
                    if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                        local decompiled, method = DecompileScript(obj)
                        local entry = string.format("\n%s\nSCRIPT: %s\nCLASS: %s\nSERVICE: %s\nSTATUS: %s\n%s\n%s\n\n",
                            string.rep("=", 60), obj:GetFullName(), obj.ClassName, serviceName,
                            method == "failed" and "PROTECTED" or "EXTRACTED (" .. method .. ")",
                            string.rep("=", 60), decompiled)
                        SafeAppendFile(path, entry)
                        count = count + 1
                        task.wait()
                    end
                end
            end)
            ScanState.StatusText = string.format("Server: %d (%s)", count, serviceName)
        end
        ScanState.StatusText = "Server dump done: " .. count
    end)
end

function DumpNilInstances()
    task.spawn(function()
        if not Capabilities.GetNilInstances then return end
        ScanState.StatusText = "Dumping nil instances..."
        local path = GameInfo.Name .. "_NilInstances.txt"
        SafeWriteFile(path, "=== NIL INSTANCE DUMP ===\n\n")
        local count = 0
        for _, obj in ipairs(getnilinstances()) do
            pcall(function()
                if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local decompiled, method = DecompileScript(obj)
                    SafeAppendFile(path, string.format("\nNIL: %s\nCLASS: %s\nSTATUS: %s\n%s\n\n",
                        obj.Name, obj.ClassName, method == "failed" and "PROTECTED" or "EXTRACTED", decompiled))
                    count = count + 1
                end
            end)
            task.wait()
        end
        ScanState.StatusText = "Nil dump done: " .. count
    end)
end

function DumpConnections()
    task.spawn(function()
        if not Capabilities.GetConnections then return end
        ScanState.StatusText = "Dumping connections..."
        local path = GameInfo.Name .. "_Connections.txt"
        SafeWriteFile(path, "=== CONNECTIONS DUMP ===\n\n")
        local count = 0
        pcall(function()
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") then
                    local entry = string.format("\nSIGNAL: %s (%s)\n", obj:GetFullName(), obj.ClassName)
                    pcall(function()
                        local conns = getconnections(obj.OnClientEvent)
                        entry = entry .. string.format("  OnClientEvent: %d connections\n", #conns)
                        for i, conn in ipairs(conns) do
                            if conn.Function then
                                local info = debug.getinfo(conn.Function)
                                entry = entry .. string.format("    [%d] %s\n", i, info.short_src or "unknown")
                            end
                        end
                    end)
                    entry = entry .. string.rep("-", 40) .. "\n"
                    SafeAppendFile(path, entry)
                    count = count + 1
                end
            end
        end)
        ScanState.StatusText = "Connections done: " .. count
    end)
end

-- ============================================================
-- MAIN SCANNER
-- ============================================================
function RunScanner()
    task.spawn(function()
        if ScanState.IsScanning then return end
        if not Capabilities.WriteFile or not Capabilities.AppendFile then return end

        ScanState.IsScanning = true
        ScanState.IsPaused = false
        ScanState.Processed = 0
        ScanState.Decompiled = 0
        ScanState.Failed = 0
        ScanState.BytecodeDumped = 0
        ScanState.RemotesFound = 0
        ScanState.StartTime = tick()
        ScanState.StatusText = "Collecting scripts..."
        ScanState.TimeText = "--:--"

        if ScanState.IncludeRemotes then StartRemoteSpy() end

        local allScripts = CollectEverything()
        ScanState.TotalScripts = #allScripts
        ScanState.CountText = "Total Scripts: " .. ScanState.TotalScripts

        if ScanState.TotalScripts == 0 then
            ScanState.StatusText = "No scripts found!"
            ScanState.IsScanning = false
            getgenv().ScannerRunning = false
            return
        end

        InitializeFile()
        ScanState.StatusText = "Scanning..."

        pcall(function()
            for i = 1, ScanState.TotalScripts do
                while ScanState.IsPaused do
                    task.wait(0.5)
                    if not ScanState.IsScanning then return end
                end
                if not ScanState.IsScanning then break end

                local data = allScripts[i]
                local decompiled, method = DecompileScript(data.Object, data.Closure)

                if method and method ~= "failed" then
                    if method == "bytecode" then
                        ScanState.BytecodeDumped = ScanState.BytecodeDumped + 1
                    else
                        ScanState.Decompiled = ScanState.Decompiled + 1
                    end
                else
                    ScanState.Failed = ScanState.Failed + 1
                end

                local entry = string.format("\n%s\nSCRIPT: %s\nCLASS: %s\nSOURCE: %s\nSTATUS: %s\n%s\n%s\n\n",
                    string.rep("=", 60), data.Name, data.Class, data.Source,
                    method == "failed" and "PROTECTED" or "EXTRACTED (" .. method .. ")",
                    string.rep("=", 60), decompiled)

                table.insert(writeBuffer, entry)
                bufferSize = bufferSize + #entry
                if bufferSize >= MAX_BUFFER_SIZE then FlushBuffer() end

                ScanState.Processed = i
                if i % 5 == 0 then
                    local elapsed = tick() - ScanState.StartTime
                    local remaining = (ScanState.Processed > 0 and elapsed > 0)
                        and ((ScanState.TotalScripts - ScanState.Processed) / (ScanState.Processed / elapsed)) or 0
                    local mins = math.floor(remaining / 60)
                    local secs = math.floor(remaining % 60)
                    local pct = math.floor((ScanState.Processed / ScanState.TotalScripts) * 100)
                    ScanState.StatusText = string.format("Scanning: %d%% (%d/%d)", pct, ScanState.Processed, ScanState.TotalScripts)
                    ScanState.TimeText = string.format("Time: %02d:%02d", mins, secs)
                    ScanState.SuccessText = string.format("Decompiled: %d | Protected: %d | Bytecode: %d",
                        ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped)
                end
                task.wait()
            end
        end)

        FlushBuffer()
        SafeAppendFile(ScanState.CurrentFile, string.format("\n=== SCAN COMPLETE ===\nTotal: %d | Extracted: %d | Protected: %d | Bytecode: %d\n",
            ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped))

        ScanState.IsScanning = false
        ScanState.StatusText = "COMPLETE!"
        ScanState.TimeText = "00:00"

        if Capabilities.SetClipboard then
            pcall(function() setclipboard(ScanState.CurrentFile) end)
        end
        getgenv().ScannerRunning = false
    end)
end

-- ============================================================
-- START
-- ============================================================
BuildUI()
