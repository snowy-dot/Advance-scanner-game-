--!nocheck
-- ============================================================
-- APEX SCRIPT SCANNER v6.3 — SELF-CONTAINED UI (NO DEPENDENCIES)
-- ============================================================

if getgenv().ScannerRunning then return end
getgenv().ScannerRunning = true

-- ============================================================
-- BYPASS
-- ============================================================
local BypassState = { HooksInstalled = false }

local function SanitizeString(str)
    if type(str) ~= "string" then return str end
    return str
        :gsub("[Ss]canner", "GameCore")
        :gsub("[Bb]ypass", "Security")
        :gsub("APEX", "Core")
end

local function InstallBypass()
    pcall(function()
        if setidentity then setidentity(7) end
        if getthreadcontext then getthreadcontext(7) end
        if setthreadcontext then setthreadcontext(7) end
        if syn and syn.set_thread_identity then syn.set_thread_identity(7) end
    end)

    pcall(function()
        if hookfunction and not BypassState.HooksInstalled then
            local oldGetInfo = debug.getinfo
            local inGetInfo = false
            local function HookedGetInfo(...)
                if inGetInfo then return oldGetInfo(...) end
                inGetInfo = true
                local info = oldGetInfo(...)
                inGetInfo = false
                if info and type(info) == "table" then
                    if info.source then info.source = SanitizeString(info.source) end
                    if info.short_src then info.short_src = SanitizeString(info.short_src) end
                end
                return info
            end
            if newcclosure then
                hookfunction(debug.getinfo, newcclosure(HookedGetInfo))
            else
                hookfunction(debug.getinfo, HookedGetInfo)
            end

            local oldTraceback = debug.traceback
            local inTraceback = false
            local function HookedTraceback(msg, level)
                if inTraceback then return oldTraceback(msg, level) end
                inTraceback = true
                local tb = oldTraceback(msg, level)
                inTraceback = false
                if type(tb) == "string" then tb = SanitizeString(tb) end
                return tb
            end
            if newcclosure then
                hookfunction(debug.traceback, newcclosure(HookedTraceback))
            else
                hookfunction(debug.traceback, HookedTraceback)
            end

            BypassState.HooksInstalled = true
        end
    end)
end

InstallBypass()

-- ============================================================
-- CAPABILITIES
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
    IsLuaLclosure = type(islclosure) == "function",
    IdentifyExec = type(identifyexecutor) == "function",
}

local ExecutorName = "Unknown"
pcall(function()
    if identifyexecutor then
        local name, version = identifyexecutor()
        if name then ExecutorName = name .. (version and (" " .. version) or "") end
    end
end)
if ExecutorName == "Unknown" then
    if Capabilities.GetReg and Capabilities.GetScriptBytecode and Capabilities.CloneFunction then
        ExecutorName = "Synapse X"
    elseif Capabilities.GetReg and Capabilities.GetScriptBytecode then
        ExecutorName = "Fluxus / Solara"
    elseif Capabilities.GetReg then
        ExecutorName = "Krnl / Hydrogen"
    elseif Capabilities.GetScriptClosure then
        ExecutorName = "Script-Ware"
    elseif Capabilities.Newcclosure then
        ExecutorName = "Wave / CodeX"
    elseif Capabilities.WriteFile then
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
        local mp = game:GetService("MarketplaceService")
        local product = mp:GetProductInfo(game.PlaceId)
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
-- NOTIFY
-- ============================================================
local function Notify(title, text, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title or "",
            Text = text or "",
            Duration = dur or 3,
        })
    end)
end

-- ============================================================
-- SELF-CONTAINED UI — NO EXTERNAL LIBS
-- ============================================================
local UI = {}
local MainWindow = nil
local Pages = {}

local function getGuiParent()
    local parent = nil
    pcall(function() parent = gethui() end)
    if parent and parent:IsA("Instance") then return parent end
    parent = game:GetService("CoreGui")
    return parent
end

local function make(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function BuildWindow()
    local parent = getGuiParent()

    -- remove old
    pcall(function()
        local old = parent:FindFirstChild("ApexScannerGui")
        if old then old:Destroy() end
    end)

    local ScreenGui = make("ScreenGui", {
        Name = "ApexScannerGui",
        ResetOnSpawn = false,
        DisplayOrder = 9999,
        IgnoreGuiInset = true,
        Parent = parent,
    })

    -- Dragging state
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local MainFrame = make("Frame", {
        Name = "MainFrame",
        Size = UDim2.new(0, 600, 0, 420),
        Position = UDim2.new(0.5, -300, 0.5, -210),
        BackgroundColor3 = Color3.fromRGB(20, 20, 25),
        BorderSizePixel = 0,
        Parent = ScreenGui,
    })

    make("UICorner", {
        CornerRadius = UDim.new(0, 8),
        Parent = MainFrame,
    })

    -- Title bar
    local TitleBar = make("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(30, 30, 38),
        BorderSizePixel = 0,
        Parent = MainFrame,
    })

    make("UICorner", {
        CornerRadius = UDim.new(0, 8),
        Parent = TitleBar,
    })

    local TitleLabel = make("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = "APEX SCANNER v6.3 | " .. GameInfo.Name,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TitleBar,
    })

    -- Close button
    local CloseBtn = make("TextButton", {
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0, 5),
        BackgroundColor3 = Color3.fromRGB(200, 50, 50),
        Text = "X",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        Parent = TitleBar,
    })
    make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = CloseBtn })
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)

    -- Dragging
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Sidebar
    local Sidebar = make("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 140, 1, -40),
        Position = UDim2.new(0, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(25, 25, 32),
        BorderSizePixel = 0,
        Parent = MainFrame,
    })

    local SidebarList = make("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Sidebar,
    })

    -- Content area
    local ContentArea = make("Frame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -140, 1, -40),
        Position = UDim2.new(0, 140, 0, 40),
        BackgroundColor3 = Color3.fromRGB(20, 20, 25),
        BorderSizePixel = 0,
        Parent = MainFrame,
    })

    -- Scrolling frame for content
    local ContentScroll = make("ScrollingFrame", {
        Name = "ContentScroll",
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = ContentArea,
    })

    make("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = ContentScroll,
    })

    MainWindow = {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        Sidebar = Sidebar,
        ContentScroll = ContentScroll,
    }

    return MainWindow
end

local function CreatePage(name, icon)
    local tab = make("TextButton", {
        Size = UDim2.new(1, -10, 0, 32),
        BackgroundColor3 = Color3.fromRGB(35, 35, 45),
        Text = "  " .. name,
        TextColor3 = Color3.fromRGB(180, 180, 190),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
        Parent = MainWindow.Sidebar,
    })
    make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = tab })

    local pageFrame = make("Frame", {
        Name = name .. "Page",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = MainWindow.ContentScroll,
    })
    make("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = pageFrame,
    })

    local page = {
        Button = tab,
        Frame = pageFrame,
        Controls = {},
    }

    tab.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do
            p.Frame.Visible = false
            p.Button.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            p.Button.TextColor3 = Color3.fromRGB(180, 180, 190)
        end
        pageFrame.Visible = true
        tab.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        tab.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)

    Pages[name] = page
    return page
end

local function AddSection(page, name)
    local label = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Color3.fromRGB(120, 120, 140),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = page.Frame,
    })
    return label
end

local function AddLabel(page, text)
    local label = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Color3.fromRGB(200, 200, 210),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Parent = page.Frame,
    })
    return {
        Set = function(_, v)
            pcall(function() label.Text = v end)
        end
    }
end

local function AddParagraph(page, title, content)
    local frame = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = page.Frame,
    })
    make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = frame })
    make("UIListLayout", {
        Padding = UDim.new(0, 4),
        Parent = frame,
    })
    make("UIPadding", {
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        Parent = frame,
    })

    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame,
    })
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = content,
        TextColor3 = Color3.fromRGB(160, 160, 175),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = frame,
    })
end

local function AddButton(page, title, desc, callback)
    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(35, 35, 45),
        Text = "",
        BorderSizePixel = 0,
        Parent = page.Frame,
    })
    make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })

    make("TextLabel", {
        Size = UDim2.new(1, -20, 0, 18),
        Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = btn,
    })
    if desc then
        make("TextLabel", {
            Size = UDim2.new(1, -20, 0, 14),
            Position = UDim2.new(0, 10, 0, 20),
            BackgroundTransparency = 1,
            Text = desc,
            TextColor3 = Color3.fromRGB(120, 120, 135),
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = btn,
        })
    end

    btn.MouseButton1Click:Connect(function()
        pcall(callback)
    end)

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    end)

    return btn
end

local function AddToggle(page, title, desc, default, callback)
    local state = default or false

    local frame = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        Text = "",
        BorderSizePixel = 0,
        Parent = page.Frame,
    })
    make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = frame })

    make("TextLabel", {
        Size = UDim2.new(1, -60, 0, 18),
        Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame,
    })
    if desc then
        make("TextLabel", {
            Size = UDim2.new(1, -60, 0, 14),
            Position = UDim2.new(0, 10, 0, 20),
            BackgroundTransparency = 1,
            Text = desc,
            TextColor3 = Color3.fromRGB(120, 120, 135),
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = frame,
        })
    end

    local toggleIndicator = make("Frame", {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(1, -46, 0.5, -9),
        BackgroundColor3 = state and Color3.fromRGB(60, 160, 80) or Color3.fromRGB(60, 60, 70),
        Parent = frame,
    })
    make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = toggleIndicator })

    local toggleKnob = make("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Parent = toggleIndicator,
    })
    make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = toggleKnob })

    frame.MouseButton1Click:Connect(function()
        state = not state
        toggleIndicator.BackgroundColor3 = state and Color3.fromRGB(60, 160, 80) or Color3.fromRGB(60, 60, 70)
        toggleKnob.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        pcall(callback, state)
    end)

    return {
        Set = function(_, v)
            state = v
            toggleIndicator.BackgroundColor3 = state and Color3.fromRGB(60, 160, 80) or Color3.fromRGB(60, 60, 70)
            toggleKnob.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        end
    }
end

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
    IncludeConnections = true,
    SplitByService = true,
    IncludeCoreScripts = false,
    TotalScripts = 0,
    Processed = 0,
    Decompiled = 0,
    Failed = 0,
    BytecodeDumped = 0,
    RemotesFound = 0,
    ConnectionsFound = 0,
    StartTime = 0,
    CurrentFile = "",
    StatusText = "Ready",
    TimeText = "--:--",
    SuccessText = "Decompiled: 0 | Protected: 0 | Bytecode: 0",
    CountText = "Total Scripts: 0",
    FileText = "Save: Not started",
    OutputFolder = "",
}

local function SafeWriteFile(path, content) pcall(function() writefile(path, content) end) end
local function SafeAppendFile(path, content) pcall(function() appendfile(path, content) end) end
local function SafeMakeFolder(path) pcall(function() makefolder(path) end) end

ScanState.OutputFolder = GameInfo.Name .. "_APEX_Scan"
SafeMakeFolder(ScanState.OutputFolder)

-- ============================================================
-- REMOTE SPY
-- ============================================================
local RemotesLog = {}
local RemoteSpyActive = false

local function StartRemoteSpy()
    if RemoteSpyActive then return end
    RemoteSpyActive = true

    task.spawn(function()
        while RemoteSpyActive do
            pcall(function()
                for _, obj in ipairs(game:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        local fn = obj:GetFullName()
                        if not RemotesLog[fn] then
                            RemotesLog[fn] = { Name = fn, Type = obj.ClassName, Hits = 0, Args = {} }
                            ScanState.RemotesFound = ScanState.RemotesFound + 1
                        end
                    end
                end
            end)
            task.wait(3)
        end
    end)

    pcall(function()
        if Capabilities.HookMeta and Capabilities.Newcclosure then
            local oldNamecall
            local function HookedNamecall(self, ...)
                local method = getnamecallmethod and getnamecallmethod() or ""
                if (method == "FireServer" or method == "InvokeServer") and
                   (typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction"))) then
                    local fullName = self:GetFullName()
                    if RemotesLog[fullName] then
                        RemotesLog[fullName].Hits = RemotesLog[fullName].Hits + 1
                        local args = { ... }
                        if #args > 0 and #RemotesLog[fullName].Args < 10 then
                            table.insert(RemotesLog[fullName].Args, args)
                        end
                    end
                end
                return oldNamecall(self, ...)
            end
            oldNamecall = hookmetamethod(game, "__namecall", newcclosure(HookedNamecall))
        end
    end)
end

-- ============================================================
-- BUILD UI
-- ============================================================
local StatusRef = { Set = function() end }
local TimeRef = { Set = function() end }
local FileRef = { Set = function() end }
local CountRef = { Set = function() end }
local SuccessRef = { Set = function() end }
local RemoteCountRef = { Set = function() end }
local RemoteConnRef = { Set = function() end }

local function BuildUI()
    BuildWindow()

    -- MAIN PAGE
    local mainPage = CreatePage("Scanner", "scan")

    AddSection(mainPage, "Game Info")
    AddParagraph(mainPage, GameInfo.Name,
        string.format("Place ID: %d\nCreator: %s\nExecutor: %s\nJobID: %s\nBypass: %s",
            GameInfo.PlaceId, GameInfo.Creator, ExecutorName, GameInfo.JobId,
            BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))

    AddSection(mainPage, "Scan Options")
    AddToggle(mainPage, "Bytecode Dump", "Raw hex extraction when decompile fails", true, function(v) ScanState.IncludeBytecode = v end)
    AddToggle(mainPage, "Registry Scan (getreg)", "Scan memory registry for loaded closures", true, function(v) ScanState.IncludeReg = v end)
    AddToggle(mainPage, "Nil Instances", "Scan for nil-parented hidden scripts", true, function(v) ScanState.IncludeNil = v end)
    AddToggle(mainPage, "Server Scripts", "SSS, SS, RS, StarterPlayer, StarterGui, StarterPack", true, function(v) ScanState.IncludeServer = v end)
    AddToggle(mainPage, "Deep Scan", "Walk upvalue chains, extract constants, closure analysis", true, function(v) ScanState.DeepScan = v end)
    AddToggle(mainPage, "Remote Spy", "Track all RemoteEvents and RemoteFunctions", true, function(v) ScanState.IncludeRemotes = v end)
    AddToggle(mainPage, "Connection Mapper", "Map all signal connections with source info", true, function(v) ScanState.IncludeConnections = v end)
    AddToggle(mainPage, "Split Output By Service", "Organize decompiled scripts into separate folders", true, function(v) ScanState.SplitByService = v end)
    AddToggle(mainPage, "Include CoreScripts", "Attempt extraction of Roblox CoreScripts (experimental)", false, function(v) ScanState.IncludeCoreScripts = v end)

    AddSection(mainPage, "Status")
    StatusRef = AddLabel(mainPage, "Status: Ready")
    TimeRef = AddLabel(mainPage, "Time: --:--")
    FileRef = AddLabel(mainPage, "Save: Not started")
    CountRef = AddLabel(mainPage, "Total Scripts: 0")
    SuccessRef = AddLabel(mainPage, "Decompiled: 0 | Protected: 0 | Bytecode: 0")

    AddSection(mainPage, "Controls")
    AddButton(mainPage, "Start Full Scan", "Begin exhaustive script collection and decompilation", function() RunScanner() end)
    AddButton(mainPage, "Toggle Pause", "Pause / resume current scan", function()
        if not ScanState.IsScanning then return end
        ScanState.IsPaused = not ScanState.IsPaused
        ScanState.StatusText = ScanState.IsPaused and "PAUSED" or "Resuming..."
    end)
    AddButton(mainPage, "Stop Scan", "Abort current scan", function()
        ScanState.IsScanning = false
        ScanState.IsPaused = false
        ScanState.StatusText = "STOPPED"
        getgenv().ScannerRunning = false
        Notify("Scanner", "Scan stopped.", 3)
    end)

    -- ADVANCED PAGE
    local advPage = CreatePage("Advanced", "wrench")

    AddSection(advPage, "Extraction")
    AddButton(advPage, "Dump All Bytecode (Raw Hex)", "Extract raw bytecode from every script", function() task.spawn(DumpAllBytecode) end)
    AddButton(advPage, "Scan Registry Closures", "Deep scan getreg() for Lua closures", function() task.spawn(ScanRegistry) end)
    AddButton(advPage, "Dump Server Scripts", "SSS, SS, RS, StarterPlayer, StarterGui, StarterPack", function() task.spawn(DumpServerScripts) end)
    AddButton(advPage, "Dump Nil Instances", "Extract nil-parented hidden scripts", function() task.spawn(DumpNilInstances) end)
    AddButton(advPage, "Dump All Connections", "Map all signal connections with source info", function() task.spawn(DumpConnections) end)
    AddButton(advPage, "Deep Upvalue Trace", "Walk upvalue chains from all loaded closures", function() task.spawn(DeepUpvalueTrace) end)
    AddButton(advPage, "Extract String Constants", "Pull all string constants from every closure in registry", function() task.spawn(ExtractAllStringConstants) end)

    AddSection(advPage, "Export")
    AddButton(advPage, "Export Full Game (saveinstance)", "Save entire game as .rbxl file", function()
        if Capabilities.SaveInstance then
            Notify("Export", "Exporting...", 3)
            pcall(function() saveinstance({ filename = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_FullExport.rbxl" }) end)
            Notify("Export", "Game exported.", 5)
        else
            Notify("Unsupported", "saveinstance not available.", 3)
        end
    end)
    AddButton(advPage, "Copy Save Path", "Copy output folder path to clipboard", function()
        if Capabilities.SetClipboard then
            pcall(function() setclipboard(ScanState.OutputFolder) end)
            Notify("Copied", "Path copied.", 2)
        end
    end)
    AddButton(advPage, "Generate Scan Report", "Create a summary report of all extracted scripts", function() task.spawn(GenerateReport) end)

    AddSection(advPage, "System")
    AddButton(advPage, "Print Executor Capabilities", "Dump all executor functions to dev console", function()
        print("========================================")
        print("  EXECUTOR: " .. ExecutorName)
        print("  BYPASS: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
        print("========================================")
        for k, v in pairs(Capabilities) do
            print(string.format("  %-25s %s", k, tostring(v)))
        end
        print("========================================")
        Notify("Console", "Check F9 console.", 3)
    end)
    AddButton(advPage, "Reinstall Bypass", "Re-run anti-cheat bypass hooks", function()
        BypassState.HooksInstalled = false
        InstallBypass()
        Notify("Bypass", "Reinstalled: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"), 4)
    end)

    -- REMOTE SPY PAGE
    local remotePage = CreatePage("Remote Spy", "radio")

    AddSection(remotePage, "Monitor")
    RemoteCountRef = AddLabel(remotePage, "Remotes Found: 0")
    RemoteConnRef = AddLabel(remotePage, "Connections: 0")

    AddSection(remotePage, "Controls")
    AddButton(remotePage, "Start Remote Spy", "Begin monitoring all remote events", function()
        StartRemoteSpy()
        Notify("Remote Spy", "Monitoring started.", 3)
    end)
    AddButton(remotePage, "Stop Remote Spy", "Stop monitoring remote events", function()
        RemoteSpyActive = false
        Notify("Remote Spy", "Stopped.", 3)
    end)
    AddButton(remotePage, "Export Remote Log", "Save all discovered remotes to file", function()
        local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_RemoteSpy.txt"
        local content = "=== REMOTE SPY DUMP ===\nGame: " .. GameInfo.Name .. "\nDate: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n"
        for name, data in pairs(RemotesLog) do
            content = content .. string.format("Name: %s\nType: %s\nHits: %d\n", data.Name, data.Type, data.Hits)
            if #data.Args > 0 then
                content = content .. "Captured Arguments:\n"
                for i, argSet in ipairs(data.Args) do
                    local argStr = {}
                    for _, arg in ipairs(argSet) do table.insert(argStr, tostring(arg):sub(1, 200)) end
                    content = content .. string.format("  [%d] %s\n", i, table.concat(argStr, ", "))
                end
            end
            content = content .. string.rep("-", 50) .. "\n"
        end
        SafeWriteFile(path, content)
        Notify("Exported", "Saved to " .. path, 3)
    end)
    AddButton(remotePage, "Fire All Remotes (Test)", "Fire every RemoteEvent with no args", function()
        local count = 0
        pcall(function()
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    pcall(function() obj:FireServer() end)
                    count = count + 1
                end
            end
        end)
        Notify("Fired", count .. " RemoteEvents fired.", 3)
    end)

    -- Select first page
    if Pages["Scanner"] then
        Pages["Scanner"].Frame.Visible = true
        Pages["Scanner"].Button.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        Pages["Scanner"].Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

    -- UI Updater
    task.spawn(function()
        while true do
            task.wait(0.3)
            pcall(function()
                StatusRef:Set(ScanState.StatusText)
                TimeRef:Set(ScanState.TimeText)
                FileRef:Set(ScanState.FileText)
                CountRef:Set(ScanState.CountText)
                SuccessRef:Set(ScanState.SuccessText)
                RemoteCountRef:Set("Remotes Found: " .. ScanState.RemotesFound)
                RemoteConnRef:Set("Connections: " .. ScanState.ConnectionsFound)
            end)
        end
    end)

    Notify("Apex Scanner", "Ready | " .. GameInfo.Name .. " | " .. ExecutorName, 5)

    print("========================================")
    print("  APEX SCANNER v6.3 — SELF-CONTAINED")
    print("  Executor: " .. ExecutorName)
    print("  Bypass: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
    print("  Game: " .. GameInfo.Name .. " (" .. GameInfo.PlaceId .. ")")
    print("========================================")
end

-- ============================================================
-- SCRIPT COLLECTOR
-- ============================================================
local function CollectEverything()
    local collected = {}
    local seen = {}

    local function addScript(scriptObj, source, service)
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
            Source = source or "Unknown",
            Service = service or "Unknown",
        })
    end

    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            local svc = "Unknown"
            pcall(function()
                local parent = obj:FindFirstAncestorWhichIsA("ServiceProvider")
                if parent then svc = parent.Name end
            end)
            addScript(obj, "GameTree", svc)
        end
    end)

    if ScanState.IncludeServer then
        local services = {
            { "ServerScriptService", "ServerScriptService" },
            { "ReplicatedStorage", "ReplicatedStorage" },
            { "ServerStorage", "ServerStorage" },
            { "StarterGui", "StarterGui" },
            { "StarterPack", "StarterPack" },
        }
        for _, svcData in ipairs(services) do
            pcall(function()
                local svc = game:GetService(svcData[1])
                for _, obj in ipairs(svc:GetDescendants()) do addScript(obj, svcData[2], svcData[2]) end
            end)
        end
        pcall(function()
            local sp = game:GetService("StarterPlayer")
            if sp then
                local sps = sp:FindFirstChild("StarterPlayerScripts")
                if sps then
                    for _, obj in ipairs(sps:GetDescendants()) do addScript(obj, "StarterPlayerScripts", "StarterPlayerScripts") end
                end
                local spc = sp:FindFirstChild("StarterCharacterScripts")
                if spc then
                    for _, obj in ipairs(spc:GetDescendants()) do addScript(obj, "StarterCharacterScripts", "StarterCharacterScripts") end
                end
            end
        end)
    end

    if Capabilities.GetScripts then
        pcall(function() for _, s in ipairs(getscripts()) do addScript(s, "getscripts()", "Executor") end end)
    end
    if Capabilities.GetLoadedModules then
        pcall(function() for _, s in ipairs(getloadedmodules()) do addScript(s, "getloadedmodules()", "LoadedModules") end end)
    end
    if ScanState.IncludeNil and Capabilities.GetNilInstances then
        pcall(function() for _, s in ipairs(getnilinstances()) do addScript(s, "getnilinstances()", "NilParented") end end)
    end
    if Capabilities.GetInstances then
        pcall(function() for _, inst in ipairs(getinstances()) do addScript(inst, "getinstances()", "AllInstances") end end)
    end

    if ScanState.IncludeCoreScripts then
        pcall(function()
            local cg = game:GetService("CoreGui")
            for _, obj in ipairs(cg:GetDescendants()) do addScript(obj, "CoreGui", "CoreGui") end
        end)
        pcall(function()
            local players = game:GetService("Players")
            for _, player in ipairs(players:GetPlayers()) do
                local pg = player:FindFirstChild("PlayerGui")
                if pg then
                    for _, obj in ipairs(pg:GetDescendants()) do addScript(obj, "PlayerGui", "PlayerGui") end
                end
            end
        end)
    end

    if ScanState.IncludeReg and Capabilities.GetReg then
        pcall(function()
            local reg = getreg()
            for _, v in ipairs(reg) do
                if type(v) == "function" then
                    local isLua = true
                    if Capabilities.IsLuaLclosure then isLua = islclosure(v) end
                    if isLua then
                        local info = debug.getinfo(v)
                        if info and info.what == "Lua" and info.source and #info.source > 0 then
                            local key = info.short_src or info.source
                            if not seen["reg:" .. key .. ":" .. tostring(v)] then
                                seen["reg:" .. key .. ":" .. tostring(v)] = true
                                table.insert(collected, {
                                    Object = nil,
                                    Closure = v,
                                    Name = key,
                                    Class = "Closure",
                                    Disabled = false,
                                    Source = "getreg()",
                                    Service = "Registry",
                                })
                            end
                        end
                    end
                end
            end
        end)
    end

    if ScanState.DeepScan and Capabilities.DebugGetUpvalues and Capabilities.GetReg then
        pcall(function()
            local reg = getreg()
            for _, v in ipairs(reg) do
                if type(v) == "function" then
                    local isLua = true
                    if Capabilities.IsLuaLclosure then isLua = islclosure(v) end
                    if isLua then
                        pcall(function()
                            local upvals = debug.getupvalues(v)
                            if upvals then
                                for _, uv in ipairs(upvals) do
                                    if typeof(uv) == "Instance" then
                                        addScript(uv, "upvalue-chain", "UpvalueChain")
                                    end
                                end
                            end
                        end)
                    end
                end
            end
        end)
    end

    return collected
end

-- ============================================================
-- DECOMPILE — 8 METHOD CHAIN
-- ============================================================
local function DecompileScript(scriptObj, closure)
    if Capabilities.Decompile and scriptObj then
        local result = nil
        pcall(function() result = decompile(scriptObj) end)
        if result and #result > 10 then return result, "decompiled" end
        pcall(function() result = decompile(scriptObj, true) end)
        if result and #result > 10 then return result, "decompile(true)" end
    end

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

    if scriptObj then
        local result = nil
        pcall(function() result = scriptObj.Source end)
        if result and #result > 10 then return "-- .Source property\n" .. result, ".Source" end
        pcall(function()
            if Capabilities.GetRawMetatable and Capabilities.SetReadOnly then
                local mt = getrawmetatable(scriptObj)
                if mt then
                    setreadonly(mt, false)
                    result = rawget(scriptObj, "Source")
                    setreadonly(mt, true)
                end
            end
        end)
        if result and #result > 10 then return "-- rawget .Source\n" .. result, "rawget(.Source)" end
    end

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
                    if i > 200 then break end
                    stringSection = stringSection .. string.format("  [%d] %q\n", i, s)
                end
            end
            ScanState.BytecodeDumped = ScanState.BytecodeDumped + 1
            return "-- BYTECODE DUMP\n-- Length: " .. len .. " bytes\n\n" .. table.concat(hexDump, "\n") .. stringSection, "bytecode"
        end
    end

    if closure and ScanState.DeepScan then
        local result = "-- CLOSURE ANALYSIS\n"
        local hasData = false
        pcall(function()
            if Capabilities.DebugGetUpvalues then
                local upvals = debug.getupvalues(closure)
                if upvals and #upvals > 0 then
                    hasData = true
                    result = result .. "\n-- UPVALUES (" .. #upvals .. "):\n"
                    for i, v in ipairs(upvals) do
                        result = result .. string.format("  [%d] %s: %s\n", i, type(v), tostring(v):sub(1, 500))
                        if typeof(v) == "Instance" then
                            pcall(function() result = result .. string.format("      -> %s (%s)\n", v:GetFullName(), v.ClassName) end)
                        end
                    end
                end
            end
        end)
        pcall(function()
            if Capabilities.DebugGetConstants then
                local consts = debug.getconstants(closure)
                if consts and #consts > 0 then
                    hasData = true
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
                hasData = true
                result = result .. "\n-- DEBUG INFO:\n"
                result = result .. "  source: " .. tostring(info.source) .. "\n"
                result = result .. "  what: " .. tostring(info.what) .. "\n"
                result = result .. "  lines: " .. tostring(info.linedefined) .. "-" .. tostring(info.lastlinedefined) .. "\n"
                result = result .. "  nups: " .. tostring(info.nups) .. "\n"
            end
        end)
        if hasData then return result, "closure-analysis" end
    end

    local fallback = "-- DECOMPILE FAILED — All methods exhausted.\n"
    if scriptObj then
        pcall(function()
            fallback = fallback .. "-- Script: " .. scriptObj:GetFullName() .. "\n"
            fallback = fallback .. "-- Class: " .. scriptObj.ClassName .. "\n"
            fallback = fallback .. "-- Disabled: " .. tostring(scriptObj.Disabled) .. "\n"
        end)
    end
    return fallback, "failed"
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
local currentService = ""

local function GetServiceFolder(service)
    local folder = ScanState.OutputFolder .. "/" .. (service or "Misc")
    SafeMakeFolder(folder)
    return folder
end

local function GetFilePath(service, part)
    if ScanState.SplitByService and service and service ~= "Unknown" then
        return GetServiceFolder(service) .. "/" .. GameInfo.Name .. "_Part_" .. part .. ".lua"
    else
        return ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_Scripts_Part_" .. part .. ".txt"
    end
end

local function FlushBuffer()
    if #writeBuffer == 0 then return end
    local chunk = table.concat(writeBuffer, "\n")
    writeBuffer = {}
    bufferSize = 0
    if currentFileSize + #chunk > MAX_FILE_SIZE then
        filePart = filePart + 1
        local path = GetFilePath(currentService, filePart)
        SafeWriteFile(path, string.format("-- APEX SCAN PART %d\n-- Date: %s\n\n", filePart, os.date("%Y-%m-%d %H:%M:%S")))
        currentFileSize = 0
        ScanState.CurrentFile = path
        ScanState.FileText = "Save: " .. path
    end
    SafeAppendFile(ScanState.CurrentFile, chunk)
    currentFileSize = currentFileSize + #chunk
end

local function SwitchService(service)
    FlushBuffer()
    currentService = service or "Misc"
    filePart = 1
    local path = GetFilePath(currentService, filePart)
    SafeWriteFile(path, string.format(
        "-- ============================================================\n" ..
        "-- APEX SCRIPT SCAN: %s | SERVICE: %s\n" ..
        "-- Game ID: %d | JobID: %s\n" ..
        "-- Executor: %s\n" ..
        "-- Date: %s\n" ..
        "-- ============================================================\n\n",
        GameInfo.Name, currentService, GameInfo.PlaceId, GameInfo.JobId, ExecutorName, os.date("%Y-%m-%d %H:%M:%S")))
    currentFileSize = 0
    ScanState.CurrentFile = path
    ScanState.FileText = "Save: " .. path
end

local function InitializeFile()
    filePart = 1
    currentService = "Main"
    local path = GetFilePath("Main", 1)
    SafeWriteFile(path, string.format(
        "-- ============================================================\n" ..
        "-- APEX SCRIPT SCAN: %s\n" ..
        "-- Game ID: %d | JobID: %s\n" ..
        "-- Executor: %s | Bypass: %s\n" ..
        "-- Date: %s\n" ..
        "-- ============================================================\n\n",
        GameInfo.Name, GameInfo.PlaceId, GameInfo.JobId, ExecutorName,
        BypassState.HooksInstalled and "ACTIVE" or "LIMITED",
        os.date("%Y-%m-%d %H:%M:%S")))
    currentFileSize = 0
    ScanState.CurrentFile = path
    ScanState.FileText = "Save: " .. path
end

-- ============================================================
-- ADVANCED TOOLS
-- ============================================================
function DumpAllBytecode()
    task.spawn(function()
        if not Capabilities.GetScriptBytecode then
            Notify("Error", "getscriptbytecode not supported.", 4)
            return
        end
        ScanState.StatusText = "Dumping bytecode..."
        local allScripts = {}
        pcall(function()
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    table.insert(allScripts, obj)
                end
            end
        end)
        if Capabilities.GetScripts then
            pcall(function() for _, s in ipairs(getscripts()) do table.insert(allScripts, s) end end)
        end
        if Capabilities.GetNilInstances then
            pcall(function() for _, s in ipairs(getnilinstances()) do
                if s:IsA("Script") or s:IsA("LocalScript") or s:IsA("ModuleScript") then
                    table.insert(allScripts, s)
                end
            end end)
        end
        local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_BytecodeDump.txt"
        SafeWriteFile(path, "=== BYTECODE DUMP ===\n")
        local count = 0
        for i, s in ipairs(allScripts) do
            pcall(function()
                local bc = getscriptbytecode(s)
                if bc and #bc > 0 then
                    SafeAppendFile(path, string.format("\n%s\n%s\nLength: %d bytes\n",
                        string.rep("=", 60), s:GetFullName(), #bc))
                    count = count + 1
                end
            end)
            ScanState.StatusText = string.format("Bytecode: %d/%d", i, #allScripts)
            task.wait()
        end
        ScanState.StatusText = "Bytecode done: " .. count
        Notify("Bytecode", count .. " scripts dumped.", 5)
    end)
end

function ScanRegistry()
    task.spawn(function()
        if not Capabilities.GetReg then
            Notify("Error", "getreg not supported.", 4)
            return
        end
        ScanState.StatusText = "Scanning registry..."
        local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_RegistryDump.txt"
        SafeWriteFile(path, "=== REGISTRY DUMP ===\n\n")
        local count = 0
        local entries = {}
        local reg = getreg()
        for _, v in ipairs(reg) do
            if type(v) == "function" then
                local info = debug.getinfo(v)
                if info and info.source and #info.source > 0 then
                    local entry = string.format("Function: %s\n  Source: %s\n  Lines: %s-%s\n  What: %s\n",
                        tostring(v), info.short_src or info.source,
                        tostring(info.linedefined), tostring(info.lastlinedefined),
                        tostring(info.what))
                    pcall(function()
                        if Capabilities.DebugGetUpvalues then
                            local upvals = debug.getupvalues(v)
                            if upvals then
                                for i, uv in ipairs(upvals) do
                                    entry = entry .. string.format("  [upval %d] %s: %s\n", i, type(uv), tostring(uv):sub(1, 200))
                                    if typeof(uv) == "Instance" then
                                        pcall(function() entry = entry .. string.format("    -> %s (%s)\n", uv:GetFullName(), uv.ClassName) end)
                                    end
                                end
                            end
                        end
                    end)
                    pcall(function()
                        if Capabilities.DebugGetConstants then
                            local consts = debug.getconstants(v)
                            if consts then
                                for i, c in ipairs(consts) do
                                    entry = entry .. string.format("  [const %d] %s: %s\n", i, type(c), tostring(c):sub(1, 200))
                                end
                            end
                        end
                    end)
                    entry = entry .. string.rep("-", 50) .. "\n"
                    table.insert(entries, entry)
                    count = count + 1
                    if count % 50 == 0 then
                        SafeAppendFile(path, table.concat(entries, "\n"))
                        entries = {}
                        task.wait()
                    end
                end
            end
        end
        if #entries > 0 then SafeAppendFile(path, table.concat(entries, "\n")) end
        ScanState.StatusText = "Registry done: " .. count
        Notify("Registry", count .. " closures found.", 5)
    end)
end

function DumpServerScripts()
    task.spawn(function()
        ScanState.StatusText = "Dumping server scripts..."
        local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_ServerScripts.txt"
        SafeWriteFile(path, "=== SERVER SCRIPT DUMP ===\n\n")
        local services = {
            "ServerScriptService", "ServerStorage", "ReplicatedStorage",
            "StarterPlayer", "StarterGui", "StarterPack",
        }
        local count = 0
        for _, serviceName in ipairs(services) do
            pcall(function()
                local service = game:GetService(serviceName)
                for _, obj in ipairs(service:GetDescendants()) do
                    if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                        local decompiled, method = DecompileScript(obj)
                        SafeAppendFile(path, string.format(
                            "\n%s\nSCRIPT: %s\nCLASS: %s\nSERVICE: %s\nSTATUS: %s\n%s\n%s\n\n",
                            string.rep("=", 60), obj:GetFullName(), obj.ClassName, serviceName,
                            method == "failed" and "PROTECTED" or "EXTRACTED (" .. method .. ")",
                            string.rep("=", 60), decompiled))
                        count = count + 1
                        task.wait()
                    end
                end
            end)
            ScanState.StatusText = string.format("Server: %d (%s)", count, serviceName)
        end
        ScanState.StatusText = "Server done: " .. count
        Notify("Server Dump", count .. " scripts saved.", 5)
    end)
end

function DumpNilInstances()
    task.spawn(function()
        if not Capabilities.GetNilInstances then
            Notify("Error", "getnilinstances not supported.", 4)
            return
        end
        ScanState.StatusText = "Dumping nil instances..."
        local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_NilInstances.txt"
        SafeWriteFile(path, "=== NIL INSTANCE DUMP ===\n\n")
        local count = 0
        for _, obj in ipairs(getnilinstances()) do
            pcall(function()
                if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local decompiled, method = DecompileScript(obj)
                    SafeAppendFile(path, string.format(
                        "\nNIL: %s\nCLASS: %s\nSTATUS: %s\n%s\n\n",
                        obj.Name, obj.ClassName,
                        method == "failed" and "PROTECTED" or "EXTRACTED (" .. method .. ")",
                        decompiled))
                    count = count + 1
                end
            end)
            task.wait()
        end
        ScanState.StatusText = "Nil done: " .. count
        Notify("Nil Dump", count .. " nil scripts found.", 5)
    end)
end

function DumpConnections()
    task.spawn(function()
        if not Capabilities.GetConnections then
            Notify("Error", "getconnections not supported.", 4)
            return
        end
        ScanState.StatusText = "Dumping connections..."
        local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_Connections.txt"
        SafeWriteFile(path, "=== CONNECTIONS DUMP ===\n\n")
        local count = 0
        pcall(function()
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or
                   obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
                    local entry = string.format("\nSIGNAL: %s (%s)\n", obj:GetFullName(), obj.ClassName)
                    pcall(function()
                        if obj:IsA("RemoteEvent") or obj:IsA("BindableEvent") then
                            local prop = obj:IsA("RemoteEvent") and "OnClientEvent" or "Event"
                            local conns = getconnections(obj[prop] or obj.Event)
                            entry = entry .. string.format("  %s: %d connections\n", prop, #conns)
                            for i, conn in ipairs(conns) do
                                if conn.Function then
                                    local info = debug.getinfo(conn.Function)
                                    entry = entry .. string.format("    [%d] %s (lines %s-%s)\n",
                                        i, info.short_src or "unknown",
                                        tostring(info.linedefined), tostring(info.lastlinedefined))
                                end
                            end
                        end
                    end)
                    entry = entry .. string.rep("-", 50) .. "\n"
                    SafeAppendFile(path, entry)
                    count = count + 1
                end
            end
        end)
        ScanState.StatusText = "Connections done: " .. count
        Notify("Connections", count .. " signals mapped.", 5)
    end)
end

function DeepUpvalueTrace()
    task.spawn(function()
        if not Capabilities.GetReg or not Capabilities.DebugGetUpvalues then
            Notify("Error", "getreg/getupvalues not supported.", 4)
            return
        end
        ScanState.StatusText = "Tracing upvalue chains..."
        local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_UpvalueTrace.txt"
        SafeWriteFile(path, "=== DEEP UPVALUE TRACE ===\n\n")
        local count = 0
        local visited = {}
        local function traceClosure(fn, depth)
            if depth > 8 then return end
            if visited[fn] then return end
            visited[fn] = true
            pcall(function()
                local upvals = debug.getupvalues(fn)
                if upvals then
                    for i, uv in ipairs(upvals) do
                        local entry = string.format("[%d:%d] ", depth, i)
                        if typeof(uv) == "Instance" then
                            local fullName = "Unknown"
                            pcall(function() fullName = uv:GetFullName() end)
                            entry = entry .. "Instance: " .. fullName .. " (" .. uv.ClassName .. ")\n"
                            if uv:IsA("Script") or uv:IsA("LocalScript") or uv:IsA("ModuleScript") then
                                local decompiled, method = DecompileScript(uv)
                                entry = entry .. "  STATUS: " .. (method == "failed" and "PROTECTED" or "EXTRACTED") .. "\n"
                                entry = entry .. "  SOURCE:\n" .. decompiled:sub(1, 5000) .. "\n"
                            end
                            count = count + 1
                        elseif type(uv) == "function" then
                            local info = debug.getinfo(uv)
                            entry = entry .. "Function: " .. (info.short_src or info.source or "unknown") .. "\n"
                            traceClosure(uv, depth + 1)
                        else
                            entry = entry .. type(uv) .. ": " .. tostring(uv):sub(1, 200) .. "\n"
                        end
                        SafeAppendFile(path, entry)
                    end
                end
            end)
        end
        local reg = getreg()
        for _, v in ipairs(reg) do
            if type(v) == "function" and not visited[v] then
                traceClosure(v, 0)
                if count % 25 == 0 then task.wait() end
            end
        end
        ScanState.StatusText = "Upvalue trace done: " .. count
        Notify("Upvalue Trace", count .. " instances found.", 5)
    end)
end

function ExtractAllStringConstants()
    task.spawn(function()
        if not Capabilities.GetReg then
            Notify("Error", "getreg not supported.", 4)
            return
        end
        ScanState.StatusText = "Extracting string constants..."
        local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_StringConstants.txt"
        SafeWriteFile(path, "=== STRING CONSTANTS EXTRACTION ===\n\n")
        local count = 0
        local allStrings = {}
        local reg = getreg()
        for _, v in ipairs(reg) do
            if type(v) == "function" then
                pcall(function()
                    if Capabilities.DebugGetConstants then
                        local consts = debug.getconstants(v)
                        if consts then
                            for _, c in ipairs(consts) do
                                if type(c) == "string" and #c >= 3 and #c <= 500 then
                                    if not allStrings[c] then
                                        allStrings[c] = true
                                        SafeAppendFile(path, string.format("[%d] %q\n", count + 1, c))
                                        count = count + 1
                                    end
                                end
                            end
                        end
                    end
                end)
                if count % 100 == 0 then task.wait() end
            end
        end
        ScanState.StatusText = "Strings extracted: " .. count
        Notify("Strings", count .. " unique strings found.", 5)
    end)
end

function GenerateReport()
    task.spawn(function()
        ScanState.StatusText = "Generating report..."
        local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_Report.txt"
        local report = string.format(
            "========================================\n" ..
            "  APEX SCANNER REPORT\n" ..
            "========================================\n" ..
            "Game: %s\nPlace ID: %d\nCreator: %s\nJobID: %s\n" ..
            "Executor: %s\nBypass: %s\nDate: %s\n\n" ..
            "SCAN RESULTS:\n  Total Scripts: %d\n  Decompiled: %d\n  Protected: %d\n" ..
            "  Bytecode: %d\n  Remotes: %d\n  Connections: %d\n\n" ..
            "OUTPUT: %s\n========================================\n",
            GameInfo.Name, GameInfo.PlaceId, GameInfo.Creator, GameInfo.JobId,
            ExecutorName, BypassState.HooksInstalled and "ACTIVE" or "LIMITED",
            os.date("%Y-%m-%d %H:%M:%S"),
            ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed,
            ScanState.BytecodeDumped, ScanState.RemotesFound, ScanState.ConnectionsFound,
            ScanState.OutputFolder
        )
        SafeWriteFile(path, report)
        ScanState.StatusText = "Report saved."
        Notify("Report", "Saved to " .. path, 4)
    end)
end

-- ============================================================
-- MAIN SCANNER
-- ============================================================
function RunScanner()
    task.spawn(function()
        if ScanState.IsScanning then return end
        if not Capabilities.WriteFile or not Capabilities.AppendFile then
            Notify("Error", "writefile/appendfile not available.", 5)
            return
        end

        ScanState.IsScanning = true
        ScanState.IsPaused = false
        ScanState.Processed = 0
        ScanState.Decompiled = 0
        ScanState.Failed = 0
        ScanState.BytecodeDumped = 0
        ScanState.RemotesFound = 0
        ScanState.ConnectionsFound = 0
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
            Notify("Scanner", "No scripts found.", 5)
            return
        end

        InitializeFile()
        ScanState.StatusText = "Scanning..."

        if ScanState.SplitByService then
            table.sort(allScripts, function(a, b)
                return (a.Service or "ZZZ") < (b.Service or "ZZZ")
            end)
        end

        pcall(function()
            local lastService = nil
            for i = 1, ScanState.TotalScripts do
                while ScanState.IsPaused do
                    task.wait(0.5)
                    if not ScanState.IsScanning then return end
                end
                if not ScanState.IsScanning then break end

                local data = allScripts[i]

                if ScanState.SplitByService and data.Service ~= lastService then
                    SwitchService(data.Service or "Misc")
                    lastService = data.Service
                end

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

                local entry = string.format(
                    "\n%s\nSCRIPT: %s%s\nCLASS: %s\nSOURCE: %s\nSERVICE: %s\nSTATUS: %s\n%s\n%s\n\n",
                    string.rep("=", 60), data.Name, data.Disabled and " [DISABLED]" or "",
                    data.Class, data.Source, data.Service or "Unknown",
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
        SafeAppendFile(ScanState.CurrentFile, string.format(
            "\n=== SCAN COMPLETE ===\nTotal: %d | Extracted: %d | Protected: %d | Bytecode: %d\nDate: %s\n",
            ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped,
            os.date("%Y-%m-%d %H:%M:%S")))

        ScanState.IsScanning = false
        ScanState.StatusText = "COMPLETE!"
        ScanState.TimeText = "00:00"

        GenerateReport()

        Notify("Scan Complete!",
            string.format("%d/%d extracted | %d bytecode | %d protected",
                ScanState.Decompiled, ScanState.TotalScripts, ScanState.BytecodeDumped, ScanState.Failed),
            6)

        if Capabilities.SetClipboard then
            pcall(function() setclipboard(ScanState.OutputFolder) end)
        end

        RemoteSpyActive = false
        getgenv().ScannerRunning = false
    end)
end

-- ============================================================
-- STARTUP
-- ============================================================
BuildUI()
