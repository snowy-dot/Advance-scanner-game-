--!nocheck
-- ============================================================
-- APEX SCRIPT SCANNER v5.2 — FLUENT UI
-- - Fluent library (github release asset, no rate limiting)
-- - 10-layer anti-cheat bypass
-- - 7-method decompile fallback chain
-- - Registry scan with upvalue chain walking
-- - Remote event spy
-- - Connection dumper
-- - Nil instance scanner
-- - Buffered async file I/O
-- - Anti-tamper hook guard
-- ============================================================

if getgenv().ScannerRunning then
    print("[Scanner] Already running.")
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
    if typeof(inst) == "Instance" then ScannerInstances[inst] = true end
end

local function HideFunction(fn)
    if type(fn) == "function" then ScannerFunctions[fn] = true end
end

local function InstallApexBypass()
    -- Layer 1: debug.getinfo scrub
    pcall(function()
        if hookfunction and not BypassState.HooksInstalled then
            local oldGetInfo = debug.getinfo
            BypassState.OriginalGetInfo = oldGetInfo
            local function FilteredGetInfo(...)
                local info = oldGetInfo(...)
                if info and type(info) == "table" then
                    if info.source and (info.source:match("Scanner") or info.source:match("[Bb]ypass")) then
                        info.source = "Workspace.GameScript"
                    end
                    if info.short_src and (info.short_src:match("Scanner") or info.short_src:match("[Bb]ypass")) then
                        info.short_src = "GameScript"
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

    -- Layer 2: __namecall hook
    pcall(function()
        if hookmetamethod and not BypassState.OriginalNamecall then
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            BypassState.OriginalNamecall = oldNamecall
            setreadonly(mt, false)
            local newNamecall
            if newcclosure then
                newNamecall = newcclosure(function(self, ...)
                    local method = getnamecallmethod()
                    if method == "GetFullName" and ScannerInstances[self] then
                        return "Workspace.GameScript"
                    end
                    if method == "FindService" then
                        local svc = select(1, ...)
                        if svc and (svc:match("[Aa]nti[Cc]heat") or svc:match("[Pp]rotect") or svc:match("[Ss]hield")) then
                            return nil
                        end
                    end
                    if method == "GetChildren" or method == "GetDescendants" then
                        local results = oldNamecall(self, ...)
                        if type(results) == "table" then
                            local filtered = {}
                            for _, v in ipairs(results) do
                                if not ScannerInstances[v] and v.Name ~= "Scanner" and v.Name ~= "Fluent" and v.Name ~= "ApexUI" then
                                    table.insert(filtered, v)
                                end
                            end
                            return filtered
                        end
                    end
                    if method == "FindFirstChild" then
                        local name = select(1, ...)
                        if name and (name:match("[Ss]canner") or name:match("Fluent") or name:match("ApexUI")) then
                            return nil
                        end
                    end
                    if method == "IsA" and ScannerInstances[self] then
                        local cn = select(1, ...)
                        if cn == "LocalScript" or cn == "Script" or cn == "ModuleScript" then
                            return false
                        end
                    end
                    return oldNamecall(self, ...)
                end)
            else
                newNamecall = function(self, ...)
                    return oldNamecall(self, ...)
                end
            end
            mt.__namecall = newNamecall
            setreadonly(mt, true)
            HideFunction(newNamecall)
        end
    end)

    -- Layer 3: __index hook
    pcall(function()
        local mt = getrawmetatable(game)
        if mt and hookmetamethod then
            setreadonly(mt, false)
            local oldIndex = mt.__index
            BypassState.OriginalIndex = oldIndex
            local newIndex
            if newcclosure then
                newIndex = newcclosure(function(t, k)
                    if k == "Name" and ScannerInstances[t] then return "GameScript" end
                    if k == "ClassName" and ScannerInstances[t] then return "Script" end
                    if k == "Disabled" and ScannerInstances[t] then return true end
                    if (k == "Source" or k == "Bytecode") and ScannerInstances[t] then return "" end
                    return oldIndex(t, k)
                end)
            else
                newIndex = oldIndex
            end
            mt.__index = newIndex
            setreadonly(mt, true)
        end
    end)

    -- Layer 4: error/assert/traceback hooks
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
                    tb = tb:gsub("[Ff]luent", "GameUI")
                end
                return tb
            end
            hookfunction(debug.traceback, FilteredTraceback)
            HideFunction(FilteredTraceback)
        end
    end)

    -- Layer 5: identity elevation
    pcall(function()
        if setidentity then setidentity(7) end
        if getthreadcontext then getthreadcontext(7) end
        if setthreadcontext then setthreadcontext(7) end
    end)

    -- Layer 6: getloadedmodules filter
    pcall(function()
        if hookfunction and getloadedmodules then
            local oldGetLoadedModules = getloadedmodules
            local function FilteredGetLoadedModules()
                local results = oldGetLoadedModules()
                local filtered = {}
                for _, mod in ipairs(results) do
                    if not ScannerInstances[mod] then table.insert(filtered, mod) end
                end
                return filtered
            end
            hookfunction(getloadedmodules, FilteredGetLoadedModules)
            HideFunction(FilteredGetLoadedModules)
        end
    end)

    -- Layer 7: anti-tamper guard
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
    IsLuaLclosure = type(islclosure) == "function",
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
    local info = { Name = "UnknownGame", PlaceId = game.PlaceId, Creator = "Unknown", JobId = game.JobId or "N/A" }
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
-- FLUENT LIBRARY LOADER
-- ============================================================
local Fluent = nil

local function LoadFluent()
    -- Fluent is distributed as a github release asset — no rate limiting
    local urls = {
        "https://github.com/dvrzz/Fluent/releases/latest/download/Fluent.txt",
        "https://raw.githubusercontent.com/dvrzz/Fluent/main/Fluent.txt",
        "https://raw.githubusercontent.com/dvrzz/Fluent/master/Fluent.txt",
    }
    for _, url in ipairs(urls) do
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and src and #src > 500 then
            local fn = loadstring(src)
            if fn then
                local ok2, result = pcall(fn)
                if ok2 and result then
                    Fluent = result
                    return
                end
                -- Some versions return global
                local ok3 = pcall(function() fn() end)
                if ok3 and Fluent then return end
                if ok3 and _G.Fluent then Fluent = _G.Fluent; return end
                if ok3 and fluent then Fluent = fluent; return end
            end
        end
    end

    -- Fallback: try Orion
    if not Fluent then
        local ok, src = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Jun0deps/Orion/main/source") end)
        if ok and src and #src > 500 then
            local fn = loadstring(src)
            if fn then
                pcall(function() fn() end)
                if OrionLib then
                    -- Wrap Orion to match Fluent API
                    Fluent = setmetatable({ _Orion = true }, {
                        __index = function(t, k)
                            if k == "CreateWindow" then
                                return function(config)
                                    local win = OrionLib:MakeWindow(config)
                                    return setmetatable({}, {
                                        __index = function(_, key)
                                            if key == "CreateTab" then
                                                return function(tabConfig)
                                                    local tab = win:MakeTab(tabConfig)
                                                    return setmetatable({}, {
                                                        __index = function(_, tk)
                                                            if tk == "CreateLabel" then return function(text) return { Set = function(s) end }, tab:AddLabel(text) end end
                                                            if tk == "CreateParagraph" then return function(p) tab:AddParagraph(p.Title, p.Content) end end
                                                            if tk == "CreateButton" then return function(b) tab:AddButton(b) end end
                                                            if tk == "CreateToggle" then return function(tg) local t = tab:AddToggle(tg); return { Set = function(v) t:Set(v) end } end end
                                                            if tk == "CreateDivider" then return function() tab:AddSection("—") end end
                                                            if tk == "CreateSection" then return function(name) tab:AddSection(name) end end
                                                            if tk == "CreateSlider" then return function(s) return tab:AddSlider(s) end end
                                                            if tk == "CreateDropdown" then return function(d) return tab:AddDropdown(d) end end
                                                            if tk == "CreateInput" then return function(i) return { Set = function() end } end end
                                                        end
                                                    })
                                                end
                                            end
                                            if k == "Destroy" then return function() OrionLib:Destroy() end end
                                        end
                                    })
                                end
                            end
                            if k == "Notify" then
                                return function(n)
                                    OrionLib:MakeNotification({ Title = n.Title or "", Content = n.Content or "", Duration = n.Duration or 3 })
                                end
                            end
                        end
                    })
                    return
                end
            end
        end
    end

    -- Final fallback: native stub
    if not Fluent then
        Fluent = {
            CreateWindow = function()
                return {
                    CreateTab = function()
                        local stub = {
                            CreateLabel = function() return { Set = function() end } end,
                            CreateParagraph = function() end,
                            CreateButton = function() return { Callback = function() end } end,
                            CreateToggle = function() return { Set = function() end } end,
                            CreateDivider = function() end,
                            CreateSection = function() end,
                            CreateSlider = function() return { Set = function() end } end,
                            CreateDropdown = function() return { Set = function() end } end,
                            CreateInput = function() return { Set = function() end } end,
                        }
                        return stub
                    end,
                    Destroy = function() end,
                }
            end,
            Notify = function() end,
        }
    end
end

LoadFluent()

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
    ConnectionsFound = 0,
    StartTime = 0,
    CurrentFile = "",
    StatusText = "Ready",
    TimeText = "--:--",
    SuccessText = "Decompiled: 0 | Protected: 0 | Bytecode: 0",
    CountText = "Total Scripts: 0",
    FileText = "Save: Not started",
}

-- ============================================================
-- SAFE WRITE UTILITIES
-- ============================================================
local function SafeWriteFile(path, content)
    pcall(function() writefile(path, content) end)
    if not isfile or not isfile(path) then
        pcall(function() writefile(path, content) end)
    end
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
                        local fn = obj:GetFullName()
                        if not RemotesLog[fn] then
                            RemotesLog[fn] = { Name = fn, Type = obj.ClassName, Hits = 0 }
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
                    ScanState.ConnectionsFound = ScanState.ConnectionsFound + #conns
                end
            end
        end
    end)
end

-- ============================================================
-- UI REFERENCES
-- ============================================================
local UIWindow = nil
local UIScreenGui = nil
local UIExists = false
local StatusRef = { Set = function() end }
local TimeRef = { Set = function() end }
local FileRef = { Set = function() end }
local CountRef = { Set = function() end }
local SuccessRef = { Set = function() end }
local RemoteCountRef = { Set = function() end }
local RemoteConnRef = { Set = function() end }

-- ============================================================
-- BUILD UI — FLUENT
-- ============================================================
function BuildUI()
    pcall(function()
        if UIWindow and UIWindow.Destroy then
            pcall(function() UIWindow:Destroy() end)
        end
    end)

    local Window = Fluent:CreateWindow({
        Title = "Apex Script Scanner v5.2",
        SubTitle = GameInfo.Name .. " | " .. ExecutorName,
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = true,
        Theme = "Dark",
        MinSize = Vector2.new(470, 380),
    })
    UIWindow = Window

    -- Hide the UI
    pcall(function()
        local parent = Capabilities.Gethui and gethui() or game:GetService("CoreGui")
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("ScreenGui") and (child.Name:match("Fluent") or child.Name:match("Window")) then
                UIScreenGui = child
                child.ResetOnSpawn = false
                child.DisplayOrder = 9999
                child.IgnoreGuiInset = true
                HideInstance(child)
            end
        end
    end)

    -- ── MAIN TAB ──
    local MainTab = Window:CreateTab("Scanner", "scan")

    local InfoSection = MainTab:CreateSection("Game Info")
    MainTab:CreateParagraph({
        Title = GameInfo.Name,
        Content = string.format("Place ID: %d\nCreator: %s\nExecutor: %s\nJobID: %s",
            GameInfo.PlaceId, GameInfo.Creator, ExecutorName, GameInfo.JobId)
    })

    local OptSection = MainTab:CreateSection("Scan Options")

    MainTab:CreateToggle({
        Title = "Bytecode Dump",
        Description = "Raw hex dump of script bytecode when decompile fails",
        Default = true,
        Callback = function(v) ScanState.IncludeBytecode = v end
    })

    MainTab:CreateToggle({
        Title = "Registry Scan (getreg)",
        Description = "Scan memory registry for loaded closures",
        Default = true,
        Callback = function(v) ScanState.IncludeReg = v end
    })

    MainTab:CreateToggle({
        Title = "Nil Instances",
        Description = "Scan for nil-parented hidden scripts",
        Default = true,
        Callback = function(v) ScanState.IncludeNil = v end
    })

    MainTab:CreateToggle({
        Title = "Server Scripts",
        Description = "ServerScriptService, ServerStorage, ReplicatedStorage",
        Default = true,
        Callback = function(v) ScanState.IncludeServer = v end
    })

    MainTab:CreateToggle({
        Title = "Deep Scan",
        Description = "Walk upvalue chains, extract constants & environments",
        Default = true,
        Callback = function(v) ScanState.DeepScan = v end
    })

    MainTab:CreateToggle({
        Title = "Remote Spy",
        Description = "Track all RemoteEvents and RemoteFunctions",
        Default = true,
        Callback = function(v) ScanState.IncludeRemotes = v end
    })

    local StatSection = MainTab:CreateSection("Status")

    StatusRef = MainTab:CreateLabel("Status: Ready")
    TimeRef = MainTab:CreateLabel("Time Remaining: --:--")
    FileRef = MainTab:CreateLabel("Save Location: Not started")
    CountRef = MainTab:CreateLabel("Total Scripts Found: 0")
    SuccessRef = MainTab:CreateLabel("Decompiled: 0 | Protected: 0 | Bytecode: 0")

    local ActionSection = MainTab:CreateSection("Controls")

    MainTab:CreateButton({
        Title = "Start Full Scan",
        Description = "Begin exhaustive script collection and decompilation",
        Callback = RunScanner
    })

    MainTab:CreateButton({
        Title = "Toggle Pause",
        Description = "Pause / resume the current scan",
        Callback = function()
            if not ScanState.IsScanning then
                Fluent:Notify({ Title = "Info", Content = "No scan running.", Duration = 2 })
                return
            end
            ScanState.IsPaused = not ScanState.IsPaused
            ScanState.StatusText = ScanState.IsPaused and "PAUSED" or "Resuming..."
            Fluent:Notify({
                Title = ScanState.IsPaused and "Paused" or "Resumed",
                Content = ScanState.IsPaused and "Click again to resume." or "Scan resumed.",
                Duration = 2
            })
        end
    })

    MainTab:CreateButton({
        Title = "Stop Scan",
        Description = "Abort the current scan (partial results saved)",
        Callback = function()
            if not ScanState.IsScanning then return end
            ScanState.IsScanning = false
            ScanState.IsPaused = false
            ScanState.StatusText = "STOPPED"
            getgenv().ScannerRunning = false
            Fluent:Notify({ Title = "Stopped", Content = "Scan aborted. Partial results saved.", Duration = 3 })
        end
    })

    MainTab:CreateButton({
        Title = "Reinstall Bypass Hooks",
        Description = "Force reinstall all anti-cheat bypass hooks",
        Callback = function()
            BypassState.HooksInstalled = false
            InstallApexBypass()
            Fluent:Notify({ Title = "Bypass", Content = "All hooks reinstalled.", Duration = 3 })
        end
    })

    MainTab:CreateButton({
        Title = "Rebuild UI",
        Description = "Destroy and recreate the Fluent interface",
        Callback = function()
            UIExists = false
            BuildUI()
        end
    })

    -- ── ADVANCED TAB ──
    local AdvTab = Window:CreateTab("Advanced", "wrench")

    AdvTab:CreateParagraph({
        Title = "Advanced Extraction Tools",
        Content = "Deep extraction methods for protected and locked scripts"
    })

    local ExtSection = AdvTab:CreateSection("Extraction")

    AdvTab:CreateButton({
        Title = "Dump All Bytecode (Raw Hex)",
        Description = "Extract raw bytecode from every script in the game",
        Callback = function() task.spawn(DumpAllBytecode) end
    })

    AdvTab:CreateButton({
        Title = "Scan Registry Closures",
        Description = "Deep scan getreg() for loaded Lua closures with upvalues",
        Callback = function() task.spawn(ScanRegistry) end
    })

    AdvTab:CreateButton({
        Title = "Dump ServerScriptService",
        Description = "Dump all scripts from SSS, SS, RS, StarterPlayer, StarterGui, StarterPack",
        Callback = function() task.spawn(DumpServerScripts) end
    })

    AdvTab:CreateButton({
        Title = "Dump Nil Instances",
        Description = "Extract scripts parented to nil (hidden by game)",
        Callback = function() task.spawn(DumpNilInstances) end
    })

    AdvTab:CreateButton({
        Title = "Dump All Connections",
        Description = "Map all signal connections with source info",
        Callback = function() task.spawn(DumpConnections) end
    })

    local ExportSection = AdvTab:CreateSection("Export")

    AdvTab:CreateButton({
        Title = "Export Full Game (saveinstance)",
        Description = "Save the entire game as a .rbxl file",
        Callback = function()
            if Capabilities.SaveInstance then
                pcall(function() saveinstance({ filename = GameInfo.Name .. "_FullExport.rbxl" }) end)
                Fluent:Notify({ Title = "Export", Content = "Game exported to workspace.", Duration = 5 })
            else
                Fluent:Notify({ Title = "Unsupported", Content = "saveinstance not available on this executor.", Duration = 3 })
            end
        end
    })

    local SysSection = AdvTab:CreateSection("System")

    AdvTab:CreateButton({
        Title = "Print Executor Capabilities",
        Description = "Dump all detected executor functions to console",
        Callback = function()
            print("========================================")
            print("  EXECUTOR CAPABILITIES")
            print("========================================")
            for k, v in pairs(Capabilities) do
                print(string.format("  %s: %s", k, tostring(v)))
            end
            print(string.format("  Executor: %s", ExecutorName))
            print(string.format("  Bypass Hooks: %s", BypassState.HooksInstalled and "INSTALLED" or "FAILED"))
            print(string.format("  Tamper Detected: %s", BypassState.Tampered and "YES" or "NO"))
            print("========================================")
            Fluent:Notify({ Title = "Console", Content = "Capabilities printed to dev console.", Duration = 3 })
        end
    })

    AdvTab:CreateButton({
        Title = "Copy Save Path to Clipboard",
        Description = "Copy the current scan output file path",
        Callback = function()
            if Capabilities.SetClipboard and ScanState.CurrentFile ~= "" then
                pcall(function() setclipboard(ScanState.CurrentFile) end)
                Fluent:Notify({ Title = "Copied", Content = "Path copied to clipboard.", Duration = 2 })
            else
                Fluent:Notify({ Title = "Error", Content = "No file path to copy. Run a scan first.", Duration = 3 })
            end
        end
    })

    -- ── REMOTE SPY TAB ──
    local RemoteTab = Window:CreateTab("Remote Spy", "radio")

    RemoteTab:CreateParagraph({
        Title = "Remote Event Monitor",
        Content = "Tracks all RemoteEvents and RemoteFunctions in the game.\nMonitors connections and firing patterns."
    })

    RemoteCountRef = RemoteTab:CreateLabel("Remotes Found: 0")
    RemoteConnRef = RemoteTab:CreateLabel("Connections: 0")

    local SpySection = RemoteTab:CreateSection("Controls")

    RemoteTab:CreateButton({
        Title = "Start Remote Spy",
        Description = "Begin monitoring all remote events",
        Callback = function()
            StartRemoteSpy()
            Fluent:Notify({ Title = "Remote Spy", Content = "Monitoring started.", Duration = 3 })
        end
    })

    RemoteTab:CreateButton({
        Title = "Export Remote Log",
        Description = "Save all discovered remotes to a file",
        Callback = function()
            local path = GameInfo.Name .. "_RemoteSpy.txt"
            local content = "=== REMOTE SPY DUMP: " .. GameInfo.Name .. " ===\n"
            content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n"
            for name, data in pairs(RemotesLog) do
                content = content .. string.format("Name: %s\nType: %s\n---\n", data.Name, data.Type)
            end
            SafeWriteFile(path, content)
            Fluent:Notify({ Title = "Exported", Content = "Saved to " .. path, Duration = 3 })
        end
    })

    RemoteTab:CreateButton({
        Title = "Fire All Remotes (Test)",
        Description = "Fire every RemoteEvent with no args — for discovery",
        Callback = function()
            local count = 0
            pcall(function()
                for _, obj in ipairs(game:GetDescendants()) do
                    if obj:IsA("RemoteEvent") then
                        pcall(function() obj:FireServer() end)
                        count = count + 1
                    end
                end
            end)
            Fluent:Notify({ Title = "Fired", Content = count .. " RemoteEvents fired.", Duration = 3 })
        end
    })

    local RemoteListSection = RemoteTab:CreateSection("Discovered Remotes")
    local RemoteListText = RemoteTab:CreateLabel("Run spy then check exported file for full list.")

    -- ── SETTINGS TAB ──
    local SettingsTab = Window:CreateTab("Settings", "settings")

    SettingsTab:CreateParagraph({
        Title = "About",
        Content = "Apex Script Scanner v5.2\nFluent UI Edition\n\nBypass Layers: 7\nDecompile Methods: 7\nScript Sources: 13\n\nBuilt for He."
    })

    local ThemeSection = SettingsTab:CreateSection("Theme")

    SettingsTab:CreateDropdown({
        Title = "Theme",
        Description = "Change the UI color scheme",
        Values = { "Dark", "Light", "Amoled", "Darker" },
        Default = "Dark",
        Callback = function(val)
            pcall(function()
                if Fluent.SetTheme then Fluent:SetTheme(val) end
            end)
        end
    })

    local AcrylicSection = SettingsTab:CreateSection("Effects")

    SettingsTab:CreateToggle({
        Title = "Acrylic Background",
        Description = "Toggle the acrylic blur effect (may impact performance)",
        Default = true,
        Callback = function(v)
            pcall(function()
                if Fluent.ToggleAcrylic then Fluent:ToggleAcrylic(v) end
            end)
        end
    })

    -- ── UI UPDATER ──
    task.spawn(function()
        while true do
            task.wait(0.3)
            pcall(function()
                if UIExists then
                    StatusRef:Set(ScanState.StatusText)
                    TimeRef:Set(ScanState.TimeText)
                    FileRef:Set(ScanState.FileText)
                    CountRef:Set(ScanState.CountText)
                    SuccessRef:Set(ScanState.SuccessText)
                    RemoteCountRef:Set("Remotes Found: " .. ScanState.RemotesFound)
                    RemoteConnRef:Set("Connections: " .. ScanState.ConnectionsFound)
                end
            end)
        end
    end)

    -- ── UI WATCHER ──
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function()
                if UIExists and UIScreenGui and UIScreenGui.Parent == nil then
                    print("[Scanner] UI destroyed. Rebuilding...")
                    UIExists = false
                    BuildUI()
                end
            end)
        end
    end)

    UIExists = true

    Fluent:Notify({
        Title = "Scanner Ready",
        Content = string.format("%s | %s", GameInfo.Name, ExecutorName),
        Duration = 5
    })

    print("========================================")
    print("  APEX SCRIPT SCANNER v5.2 — FLUENT UI")
    print("  Executor: " .. ExecutorName)
    print("  Bypass: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
    print("  Bytecode: " .. (Capabilities.GetScriptBytecode and "SUPPORTED" or "UNSUPPORTED"))
    print("  Registry: " .. (Capabilities.GetReg and "SUPPORTED" or "UNSUPPORTED"))
    print("  Nil Instances: " .. (Capabilities.GetNilInstances and "SUPPORTED" or "UNSUPPORTED"))
    print("  Connections: " .. (Capabilities.GetConnections and "SUPPORTED" or "UNSUPPORTED"))
    print("  SaveInstance: " .. (Capabilities.SaveInstance and "SUPPORTED" or "UNSUPPORTED"))
    print("========================================")
end

-- ============================================================
-- SCRIPT COLLECTOR — 13 SOURCES
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

    -- 1. Game tree
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do addScript(obj, "GameTree") end
    end)

    -- 2-7. Services
    if ScanState.IncludeServer then
        local services = {
            { "ServerScriptService", "SSS" },
            { "ReplicatedStorage", "RS" },
            { "ServerStorage", "SS" },
            { "StarterGui", "SG" },
            { "StarterPack", "SP" },
        }
        for _, svc in ipairs(services) do
            pcall(function()
                local service = game:GetService(svc[1])
                for _, obj in ipairs(service:GetDescendants()) do addScript(obj, svc[2]) end
            end)
        end

        -- StarterPlayer sub-folders
        pcall(function()
            local sp = game:GetService("StarterPlayer")
            if sp then
                local sps = sp:FindFirstChild("StarterPlayerScripts")
                if sps then for _, obj in ipairs(sps:GetDescendants()) do addScript(obj, "SPS") end end
                local spc = sp:FindFirstChild("StarterCharacterScripts")
                if spc then for _, obj in ipairs(spc:GetDescendants()) do addScript(obj, "SPC") end end
            end
        end)
    end

    -- 8. getscripts()
    if Capabilities.GetScripts then
        pcall(function()
            for _, s in ipairs(getscripts()) do addScript(s, "getscripts()") end
        end)
    end

    -- 9. getloadedmodules()
    if Capabilities.GetLoadedModules then
        pcall(function()
            for _, s in ipairs(getloadedmodules()) do addScript(s, "getloadedmodules()") end
        end)
    end

    -- 10. getnilinstances()
    if ScanState.IncludeNil and Capabilities.GetNilInstances then
        pcall(function()
            for _, s in ipairs(getnilinstances()) do addScript(s, "getnilinstances()") end
        end)
    end

    -- 11. getinstances()
    if Capabilities.GetInstances then
        pcall(function()
            for _, inst in ipairs(getinstances()) do addScript(inst, "getinstances()") end
        end)
    end

    -- 12. getreg() closures
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

    -- 13. Upvalue chain walk
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
                            elseif type(uv) == "function" then
                                local info = debug.getinfo(uv)
                                if info and info.what == "Lua" and info.source and #info.source > 0 then
                                    local scriptName = info.short_src or info.source
                                    local key = scriptName .. "|upvalue"
                                    if not seen[key] then
                                        seen[key] = true
                                        table.insert(collected, {
                                            Object = nil,
                                            Closure = uv,
                                            Name = scriptName,
                                            Class = "Closure(upvalue)",
                                            Disabled = false,
                                            Source = "upvalue-chain"
                                        })
                                    end
                                end
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

        pcall(function() result = decompile(scriptObj, false) end)
        if result and #result > 10 then return result, "decompile(false)" end
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
                    else
                        hexLine = hexLine .. "   "
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
                stringSection = "\n\n-- STRING CONSTANTS EXTRACTED:\n"
                for i, s in ipairs(stringsFound) do
                    if i > 100 then break end
                    stringSection = stringSection .. string.format("  [%d] %q\n", i, s)
                end
            end

            ScanState.BytecodeDumped = ScanState.BytecodeDumped + 1
            return "-- BYTECODE DUMP\n-- Length: " .. len .. " bytes\n-- Hex cap: " .. limit .. "\n\n" ..
                   table.concat(hexDump, "\n") .. stringSection, "bytecode"
        end
    end

    -- Method 5-7: Closure analysis
    if closure and ScanState.DeepScan then
        local result = "-- CLOSURE ANALYSIS (decompile failed)\n\n"

        pcall(function()
            if Capabilities.DebugGetUpvalues then
                local upvals = debug.getupvalues(closure)
                if upvals and #upvals > 0 then
                    result = result .. "-- UPVALUES (" .. #upvals .. "):\n"
                    for i, v in ipairs(upvals) do
                        result = result .. string.format("  [%d] %s: %s\n", i, type(v), tostring(v):sub(1, 500))
                        if type(v) == "function" then
                            pcall(function()
                                local inner = debug.getupvalues(v)
                                if inner and #inner > 0 then
                                    result = result .. string.format("      inner (%d):\n", #inner)
                                    for j, iv in ipairs(inner) do
                                        result = result .. string.format("        [%d.%d] %s: %s\n", i, j, type(iv), tostring(iv):sub(1, 200))
                                    end
                                end
                            end)
                        end
                        if typeof(v) == "Instance" then
                            pcall(function()
                                result = result .. string.format("      -> Instance: %s (%s)\n", v:GetFullName(), v.ClassName)
                            end)
                        end
                    end
                    result = result .. "\n"
                end
            end
        end)

        pcall(function()
            if Capabilities.DebugGetConstants then
                local consts = debug.getconstants(closure)
                if consts and #consts > 0 then
                    result = result .. "-- CONSTANTS (" .. #consts .. "):\n"
                    for i, v in ipairs(consts) do
                        result = result .. string.format("  [%d] %s: %s\n", i, type(v), tostring(v):sub(1, 300))
                    end
                    result = result .. "\n"
                end
            end
        end)

        pcall(function()
            local info = debug.getinfo(closure)
            if info then
                result = result .. "-- DEBUG INFO:\n"
                result = result .. "  source: " .. tostring(info.source) .. "\n"
                result = result .. "  short_src: " .. tostring(info.short_src) .. "\n"
                result = result .. "  lines: " .. tostring(info.linedefined) .. "-" .. tostring(info.lastlinedefined) .. "\n"
                result = result .. "  what: " .. tostring(info.what) .. "\n"
                result = result .. "  nparams: " .. tostring(info.nparams) .. "\n"
                result = result .. "  nups: " .. tostring(info.nups) .. "\n"
            end
        end)

        if #result > 50 then return result, "closure-analysis" end
    end

    return "-- DECOMPILE FAILED (Protected Bytecode)\n-- All 7 methods exhausted.\n", "failed"
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
        SafeWriteFile(path, string.format(
            "=== APEX SCRIPT SCAN: %s ===\n=== PART %d ===\nGame ID: %d | JobID: %s\nExecutor: %s\nDate: %s\n\n",
            GameInfo.Name, filePart, GameInfo.PlaceId, GameInfo.JobId, ExecutorName, os.date("%Y-%m-%d %H:%M:%S")))
        currentFileSize = 0
        ScanState.CurrentFile = path
        ScanState.FileParts = filePart
        ScanState.FileText = "Save: " .. path
    end

    SafeAppendFile(ScanState.CurrentFile, chunk)
    currentFileSize = currentFileSize + #chunk
end

local function InitializeFile()
    filePart = 1
    ScanState.CurrentFile = GetFilePath(1)
    SafeWriteFile(ScanState.CurrentFile, string.format(
        "=== APEX SCRIPT SCAN: %s ===\n=== PART 1 ===\nGame ID: %d | JobID: %s\nExecutor: %s\nDate: %s\n\n",
        GameInfo.Name, GameInfo.PlaceId, GameInfo.JobId, ExecutorName, os.date("%Y-%m-%d %H:%M:%S")))
    currentFileSize = 0
    ScanState.FileParts = 1
    ScanState.FileText = "Save: " .. ScanState.CurrentFile
end

-- ============================================================
-- ADVANCED TOOLS
-- ============================================================
function DumpAllBytecode()
    task.spawn(function()
        if not Capabilities.GetScriptBytecode then
            Fluent:Notify({ Title = "Error", Content = "getscriptbytecode not supported.", Duration = 4 })
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
            pcall(function()
                for _, s in ipairs(getscripts()) do table.insert(allScripts, s) end
            end)
        end
        if Capabilities.GetNilInstances then
            pcall(function()
                for _, s in ipairs(getnilinstances()) do table.insert(allScripts, s) end
            end)
        end

        local path = GameInfo.Name .. "_BytecodeDump.txt"
        SafeWriteFile(path, "=== BYTECODE DUMP: " .. GameInfo.Name .. " ===\n")
        local count = 0

        for i, s in ipairs(allScripts) do
            pcall(function()
                local bc = getscriptbytecode(s)
                if bc and #bc > 0 then
                    local entry = string.format("\n%s\n%s\nBytecode Length: %d bytes\n", string.rep("=", 60), s:GetFullName(), #bc)
                    SafeAppendFile(path, entry)
                    local rawPath = GameInfo.Name .. "_BC_" .. tostring(s):gsub("[^%w_]", "_") .. ".bin"
                    pcall(function() writefile(rawPath, bc) end)
                    count = count + 1
                end
            end)
            ScanState.StatusText = string.format("Bytecode: %d/%d", i, #allScripts)
            task.wait()
        end

        ScanState.StatusText = "Bytecode done: " .. count .. " scripts"
        Fluent:Notify({ Title = "Bytecode Dump", Content = count .. " scripts dumped.", Duration = 5 })
    end)
end

function ScanRegistry()
    task.spawn(function()
        if not Capabilities.GetReg then
            Fluent:Notify({ Title = "Error", Content = "getreg not supported.", Duration = 4 })
            return
        end
        ScanState.StatusText = "Scanning registry..."

        local path = GameInfo.Name .. "_RegistryDump.txt"
        SafeWriteFile(path, "=== REGISTRY CLOSURE DUMP: " .. GameInfo.Name .. " ===\n\n")
        local count = 0
        local reg = getreg()
        local entries = {}

        for _, v in ipairs(reg) do
            if type(v) == "function" then
                local isLua = true
                if Capabilities.IsLuaLclosure then isLua = islclosure(v) end
                if isLua then
                    local info = debug.getinfo(v)
                    if info and info.source and #info.source > 0 then
                        local entry = string.format(
                            "Function: %s\n  Source: %s\n  Line: %s-%s\n  What: %s\n  Params: %s\n  Upvalues: %s\n",
                            tostring(v), info.short_src or info.source,
                            tostring(info.linedefined), tostring(info.lastlinedefined),
                            info.what or "unknown", tostring(info.nparams), tostring(info.nups))

                        pcall(function()
                            if Capabilities.DebugGetUpvalues then
                                local upvals = debug.getupvalues(v)
                                if upvals and #upvals > 0 then
                                    entry = entry .. "  Upvalues:\n"
                                    for i, uv in ipairs(upvals) do
                                        entry = entry .. string.format("    [%d] %s: %s\n", i, type(uv), tostring(uv):sub(1, 300))
                                        if type(uv) == "function" then
                                            pcall(function()
                                                local inner = debug.getupvalues(uv)
                                                if inner then
                                                    for j, iv in ipairs(inner) do
                                                        entry = entry .. string.format("      [%d.%d] %s: %s\n", i, j, type(iv), tostring(iv):sub(1, 200))
                                                    end
                                                end
                                            end)
                                        end
                                        if typeof(uv) == "Instance" then
                                            pcall(function()
                                                entry = entry .. string.format("      -> %s (%s)\n", uv:GetFullName(), uv.ClassName)
                                            end)
                                        end
                                    end
                                end
                            end
                        end)

                        pcall(function()
                            if Capabilities.DebugGetConstants then
                                local consts = debug.getconstants(v)
                                if consts and #consts > 0 then
                                    entry = entry .. "  Constants:\n"
                                    for i, c in ipairs(consts) do
                                        entry = entry .. string.format("    [%d] %s: %s\n", i, type(c), tostring(c):sub(1, 300))
                                    end
                                end
                            end
                        end)

                        entry = entry .. string.rep("-", 40) .. "\n"
                        table.insert(entries, entry)
                        count = count + 1

                        if count % 50 == 0 then
                            SafeAppendFile(path, table.concat(entries, "\n"))
                            entries = {}
                            ScanState.StatusText = string.format("Registry: %d closures", count)
                            task.wait()
                        end
                    end
                end
            end
        end

        if #entries > 0 then
            SafeAppendFile(path, table.concat(entries, "\n"))
        end

        ScanState.StatusText = "Registry done: " .. count .. " closures"
        Fluent:Notify({ Title = "Registry Scan", Content = count .. " closures found.", Duration = 5 })
    end)
end

function DumpServerScripts()
    task.spawn(function()
        ScanState.StatusText = "Dumping server scripts..."

        local path = GameInfo.Name .. "_ServerScripts.txt"
        SafeWriteFile(path, "=== SERVER SCRIPT DUMP: " .. GameInfo.Name .. " ===\n\n")
        local services = { "ServerScriptService", "ServerStorage", "ReplicatedStorage", "StarterPlayer", "StarterGui", "StarterPack" }
        local count = 0

        for _, serviceName in ipairs(services) do
            pcall(function()
                local service = game:GetService(serviceName)
                SafeAppendFile(path, string.format("\n%s\n%s\n\n", string.rep("=", 60), serviceName))

                for _, obj in ipairs(service:GetDescendants()) do
                    if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                        local name = obj:GetFullName()
                        local class = obj.ClassName
                        local disabled = obj.Disabled and " [DISABLED]" or ""

                        local decompiled, method = DecompileScript(obj)
                        local status = method == "failed" and "PROTECTED" or "EXTRACTED (" .. method .. ")"

                        local entry = string.format(
                            "\n%s\nSCRIPT: %s%s\nCLASS: %s\nSERVICE: %s\nSTATUS: %s\n%s\n%s\n\n",
                            string.rep("=", 60), name, disabled, class, serviceName,
                            status, string.rep("=", 60), decompiled)

                        SafeAppendFile(path, entry)
                        count = count + 1
                        ScanState.StatusText = string.format("Server: %d (%s)", count, serviceName)
                        task.wait()
                    end
                end
            end)
        end

        ScanState.StatusText = "Server dump done: " .. count
        Fluent:Notify({ Title = "Server Dump", Content = count .. " scripts saved.", Duration = 5 })
    end)
end

function DumpNilInstances()
    task.spawn(function()
        if not Capabilities.GetNilInstances then
            Fluent:Notify({ Title = "Error", Content = "getnilinstances not supported.", Duration = 4 })
            return
        end
        ScanState.StatusText = "Dumping nil instances..."

        local path = GameInfo.Name .. "_NilInstances.txt"
        SafeWriteFile(path, "=== NIL INSTANCE DUMP: " .. GameInfo.Name .. " ===\n\n")
        local count = 0

        for _, obj in ipairs(getnilinstances()) do
            pcall(function()
                if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local name = "nil::" .. (obj.Name or "Unknown")
                    local class = obj.ClassName
                    local disabled = obj.Disabled and " [DISABLED]" or ""

                    local decompiled, method = DecompileScript(obj)
                    local status = method == "failed" and "PROTECTED" or "EXTRACTED (" .. method .. ")"

                    SafeAppendFile(path, string.format(
                        "\n%s\nNIL SCRIPT: %s%s\nCLASS: %s\nSTATUS: %s\n%s\n%s\n\n",
                        string.rep("=", 60), name, disabled, class, status,
                        string.rep("=", 60), decompiled))
                    count = count + 1
                end
            end)
            ScanState.StatusText = string.format("Nil: %d", count)
            task.wait()
        end

        ScanState.StatusText = "Nil dump done: " .. count
        Fluent:Notify({ Title = "Nil Dump", Content = count .. " nil scripts found.", Duration = 5 })
    end)
end

function DumpConnections()
    task.spawn(function()
        if not Capabilities.GetConnections then
            Fluent:Notify({ Title = "Error", Content = "getconnections not supported.", Duration = 4 })
            return
        end
        ScanState.StatusText = "Dumping connections..."

        local path = GameInfo.Name .. "_Connections.txt"
        SafeWriteFile(path, "=== CONNECTIONS DUMP: " .. GameInfo.Name .. " ===\n\n")
        local count = 0

        pcall(function()
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or
                   obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
                    local entry = string.format("\n%s\nSIGNAL: %s\nCLASS: %s\n", string.rep("=", 60), obj:GetFullName(), obj.ClassName)

                    pcall(function()
                        local conns = getconnections(obj.OnClientEvent)
                        entry = entry .. string.format("  OnClientEvent: %d connections\n", #conns)
                        for i, conn in ipairs(conns) do
                            entry = entry .. string.format("    [%d] Enabled: %s\n", i, tostring(conn.Enabled))
                            if conn.Function then
                                local info = debug.getinfo(conn.Function)
                                if info then
                                    entry = entry .. string.format("        Source: %s\n", info.short_src or info.source or "unknown")
                                    entry = entry .. string.format("        Lines: %s-%s\n", tostring(info.linedefined), tostring(info.lastlinedefined))
                                end
                            end
                        end
                    end)

                    if obj:IsA("RemoteFunction") then
                        pcall(function()
                            local conns = getconnections(obj.OnClientInvoke)
                            entry = entry .. string.format("  OnClientInvoke: %d connections\n", #conns)
                        end)
                    end

                    entry = entry .. string.rep("-", 40) .. "\n"
                    SafeAppendFile(path, entry)
                    count = count + 1
                end
            end
        end)

        -- UI button connections
        pcall(function()
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                    local conns = getconnections(obj.MouseButton1Click)
                    if conns and #conns > 0 then
                        local entry = string.format("\nUI BUTTON: %s (%d connections)\n", obj:GetFullName(), #conns)
                        for i, conn in ipairs(conns) do
                            if conn.Function then
                                local info = debug.getinfo(conn.Function)
                                entry = entry .. string.format("  [%d] %s\n", i, info.short_src or "unknown")
                            end
                        end
                        SafeAppendFile(path, entry)
                        count = count + 1
                    end
                end
            end
        end)

        ScanState.StatusText = "Connections done: " .. count
        Fluent:Notify({ Title = "Connections", Content = count .. " signals mapped.", Duration = 5 })
    end)
end

-- ============================================================
-- MAIN SCANNER
-- ============================================================
function RunScanner()
    task.spawn(function()
        if ScanState.IsScanning then
            Fluent:Notify({ Title = "Busy", Content = "Already scanning!", Duration = 3 })
            return
        end
        if not Capabilities.WriteFile or not Capabilities.AppendFile then
            Fluent:Notify({ Title = "Error", Content = "No file I/O support on this executor.", Duration = 5 })
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
        ScanState.StatusText = "Initializing..."
        ScanState.TimeText = "--:--"

        task.wait(0.3)

        -- Re-elevate
        pcall(function()
            if setidentity then setidentity(7) end
            if getthreadcontext then getthreadcontext(7) end
            if setthreadcontext then setthreadcontext(7) end
        end)

        if ScanState.IncludeRemotes then StartRemoteSpy() end

        ScanState.StatusText = "Collecting scripts..."
        local allScripts = CollectEverything()
        ScanState.TotalScripts = #allScripts
        ScanState.CountText = "Total Scripts: " .. ScanState.TotalScripts

        if ScanState.TotalScripts == 0 then
            ScanState.StatusText = "No scripts found!"
            ScanState.IsScanning = false
            getgenv().ScannerRunning = false
            Fluent:Notify({ Title = "Alert", Content = "No scripts detected.", Duration = 4 })
            return
        end

        ScanState.StatusText = "Initializing file system..."
        InitializeFile()
        task.wait(0.3)

        ScanState.StatusText = "Scanning..."

        pcall(function()
            for i = 1, ScanState.TotalScripts do
                while ScanState.IsPaused do
                    task.wait(0.5)
                    if not ScanState.IsScanning then return end
                end
                if not ScanState.IsScanning then break end

                local data = allScripts[i]
                local scriptObj = data.Object
                local closure = data.Closure

                local decompiled, method = DecompileScript(scriptObj, closure)

                if method and method ~= "failed" then
                    if method == "bytecode" then
                        ScanState.BytecodeDumped = ScanState.BytecodeDumped + 1
                    else
                        ScanState.Decompiled = ScanState.Decompiled + 1
                    end
                else
                    ScanState.Failed = ScanState.Failed + 1
                end

                local statusIcon = (method == "failed") and "PROTECTED" or ("EXTRACTED (" .. method .. ")")

                local entry = string.format(
                    "\n%s\nSCRIPT: %s%s\nCLASS: %s\nSOURCE: %s\nSTATUS: %s\n%s\n%s\n\n",
                    string.rep("=", 60),
                    data.Name, data.Disabled and " [DISABLED]" or "",
                    data.Class, data.Source,
                    statusIcon,
                    string.rep("=", 60),
                    decompiled)

                table.insert(writeBuffer, entry)
                bufferSize = bufferSize + #entry

                if bufferSize >= MAX_BUFFER_SIZE then
                    FlushBuffer()
                end

                ScanState.Processed = i

                if i % 5 == 0 then
                    local elapsed = tick() - ScanState.StartTime
                    local remaining = 0
                    if ScanState.Processed > 0 and elapsed > 0 then
                        local rate = ScanState.Processed / elapsed
                        if rate > 0 then remaining = (ScanState.TotalScripts - ScanState.Processed) / rate end
                    end
                    if remaining < 0 then remaining = 0 end
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

        -- Write summary
        SafeAppendFile(ScanState.CurrentFile, string.format(
            "\n%s\nAPEX SCAN COMPLETE\nTotal: %d | Extracted: %d | Protected: %d | Bytecode: %d\nRemotes: %d | Connections: %d\nElapsed: %.1fs\n%s\n",
            string.rep("=", 60),
            ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped,
            ScanState.RemotesFound, ScanState.ConnectionsFound,
            tick() - ScanState.StartTime,
            string.rep("=", 60)))

        -- Export remote log if collected
        if ScanState.RemotesFound > 0 then
            pcall(function()
                local remotePath = GameInfo.Name .. "_RemoteSpy.txt"
                local content = "=== REMOTE SPY DUMP: " .. GameInfo.Name .. " ===\n\n"
                for name, data in pairs(RemotesLog) do
                    content = content .. string.format("Name: %s\nType: %s\n---\n", data.Name, data.Type)
                end
                SafeWriteFile(remotePath, content)
            end)
        end

        ScanState.IsScanning = false
        ScanState.StatusText = "COMPLETE!"
        ScanState.TimeText = "00:00"
        ScanState.SuccessText = string.format("Extracted: %d | Protected: %d | Bytecode: %d",
            ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped)

        Fluent:Notify({
            Title = "Scan Complete!",
            Content = string.format("%d/%d extracted | %d bytecode | %d protected | %d remotes",
                ScanState.Decompiled, ScanState.TotalScripts, ScanState.BytecodeDumped, ScanState.Failed, ScanState.RemotesFound),
            Duration = 6
        })

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

task.delay(2, function()
    pcall(function() getgenv().ScannerRunning = false end)
end)
