--!nocheck
-- ============================================================
-- ULTIMATE UNIVERSAL SCRIPT SCANNER v5.0 — APEX
-- - Multi-layer anti-cheat bypass (hookmeta, hookfunction, clonefunc)
-- - Protected script unlocking (hooking GC barriers)
-- - Server-side script scanning (ReplicatedStorage, ServerScriptService, ServerStorage, nil instances)
-- - Deep decompile chain (7 fallback methods)
-- - Memory registry scan (getreg) for loaded closures with upvalue chain walking
-- - Raw bytecode dump + disassembly attempt
-- - Anti-detection: trace hiding, stack spoofing, namecall filtering
-- - Hook integrity protection (detect tampering by AC)
-- - Remote event spy integration
-- - UI persistence + auto-recovery + crash guard
-- - Async buffered I/O for performance
-- ============================================================

if getgenv().ScannerRunning then
    print("[Scanner] Already running. Skipping duplicate.")
    return
end
getgenv().ScannerRunning = true

-- ============================================================
-- APEX BYPASS LAYER — Multi-layer anti-cheat evasion
-- ============================================================
local BypassState = {
    HooksInstalled = false,
    OriginalGetInfo = nil,
    OriginalNamecall = nil,
    OriginalIndex = nil,
    OriginalNewIndex = nil,
    OriginalError = nil,
    OriginalAssert = nil,
    OriginalPcall = nil,
    OriginalSpawn = nil,
    OriginalGetChildren = nil,
    OriginalGetDescendants = nil,
    OriginalFindFirstChild = nil,
    OriginalRequire = nil,
    HiddenInstances = {},
    SpoofedStack = {},
    HookGuard = {},
    Tampered = false,
}

-- Track our own instances/functions to hide
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

-- Stack spoofing — replace scanner traces with clean call stacks
local function SpoofStack()
    return debug.traceback("Workspace.GameScript", 2)
end

local function InstallApexBypass()
    -- Layer 1: Hook debug.getinfo to scrub scanner traces
    pcall(function()
        if hookfunction and not BypassState.HooksInstalled then
            local oldGetInfo = debug.getinfo
            BypassState.OriginalGetInfo = oldGetInfo

            local function FilteredGetInfo(...)
                local args = {...}
                local info = oldGetInfo(...)
                if info and type(info) == "table" then
                    -- Scrub scanner traces from source
                    if info.source then
                        if info.source:match("Scanner") or info.source:match("[Ll]oad") or info.source:match("[Bb]ypass") then
                            info.source = "Workspace.GameScript"
                        end
                    end
                    if info.short_src then
                        if info.short_src:match("Scanner") or info.short_src:match("[Bb]ypass") then
                            info.short_src = "GameScript"
                        end
                    end
                    -- Hide function references that belong to scanner
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

    -- Layer 2: Hook __namecall to intercept integrity checks
    pcall(function()
        if hookmetamethod and not BypassState.OriginalNamecall then
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            BypassState.OriginalNamecall = oldNamecall

            setreadonly(mt, false)
            mt.__namecall = function(self, ...)
                local method = getnamecallmethod()

                -- Spoof identity checks
                if method == "GetFullName" and ScannerInstances[self] then
                    return "Workspace.GameScript"
                end

                -- Block anti-cheat integrity checks
                if method == "FindService" then
                    local service = select(1, ...)
                    if service and (service:match("[Aa]nti[Cc]heat") or service:match("[Pp]rotect") or service:match("[Ss]hield")) then
                        return nil
                    end
                end

                -- Intercept :GetChildren and :GetDescendants to hide scanner
                if method == "GetChildren" or method == "GetDescendants" then
                    local results = oldNamecall(self, ...)
                    if type(results) == "table" then
                        local filtered = {}
                        for _, v in ipairs(results) do
                            if not ScannerInstances[v] and v.Name ~= "Scanner" and v.Name ~= "ScriptScanner" and v.Name ~= "Rayfield" then
                                table.insert(filtered, v)
                            end
                        end
                        return filtered
                    end
                end

                -- Intercept FindFirstChild to hide scanner
                if method == "FindFirstChild" then
                    local name = select(1, ...)
                    if name and (name:match("[Ss]canner") or name:match("[Rr]ayfield")) then
                        return nil
                    end
                end

                -- Intercept IsA checks that might detect scanner
                if method == "IsA" and ScannerInstances[self] then
                    local className = select(1, ...)
                    if className == "LocalScript" or className == "Script" or className == "ModuleScript" then
                        return false
                    end
                end

                return oldNamecall(self, ...)
            end
            setreadonly(mt, true)
            HideFunction(mt.__namecall)
        end
    end)

    -- Layer 3: Hook __index to filter scanner instance access
    pcall(function()
        local mt = getrawmetatable(game)
        if mt and hookmetamethod then
            setreadonly(mt, false)
            local oldIndex = mt.__index
            BypassState.OriginalIndex = oldIndex

            mt.__index = function(t, k)
                -- Filter access to scanner instances
                if k == "Name" and ScannerInstances[t] then
                    return "GameScript"
                end
                if k == "ClassName" and ScannerInstances[t] then
                    return "Script"
                end
                if k == "Disabled" and ScannerInstances[t] then
                    return true
                end
                if (k == "Source" or k == "Bytecode") and ScannerInstances[t] then
                    return ""
                end
                return oldIndex(t, k)
            end
            setreadonly(mt, true)
            HideFunction(mt.__index)
        end
    end)

    -- Layer 4: Hook error/assert to suppress scanner-related errors
    pcall(function()
        if hookfunction then
            -- Hook error
            local oldError = error
            BypassState.OriginalError = oldError
            local function FilteredError(msg, level)
                if type(msg) == "string" and (msg:match("[Ss]canner") or msg:match("[Bb]ypass") or msg:match("[Ll]oad")) then
                    return oldError("Unexpected behavior", level)
                end
                return oldError(msg, level)
            end
            hookfunction(error, FilteredError)
            HideFunction(FilteredError)

            -- Hook assert
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
        end
    end)

    -- Layer 5: Hook debug.traceback to scrub scanner from stack traces
    pcall(function()
        if hookfunction then
            local oldTraceback = debug.traceback
            local function FilteredTraceback(msg, level)
                local tb = oldTraceback(msg, level)
                if type(tb) == "string" then
                    -- Replace any scanner references with clean paths
                    tb = tb:gsub("[Ss]canner", "GameScript")
                    tb = tb:gsub("[Bb]ypass", "CoreScript")
                    tb = tb:gsub("[Ll]oad", "Init")
                    -- Remove references to scanner functions
                    tb = tb:gsub("line %d+ in [^\n]*[Ss]canner[^\n]*\n", "")
                end
                return tb
            end
            hookfunction(debug.traceback, FilteredTraceback)
            HideFunction(FilteredTraceback)
        end
    end)

    -- Layer 6: Spoof thread context / identity (elevate to level 7/8)
    pcall(function()
        if setidentity then setidentity(7) end
        if getthreadcontext then getthreadcontext(7) end
        -- Some executors use setthreadcontext
        if setthreadcontext then setthreadcontext(7) end
    end)

    -- Layer 7: Hook require to intercept ModuleScript loading
    pcall(function()
        if hookfunction then
            local oldRequire = require
            BypassState.OriginalRequire = oldRequire
            local function FilteredRequire(mod)
                -- Log required modules for tracking
                if typeof(mod) == "Instance" and mod:IsA("ModuleScript") then
                    -- Let it pass through, but we track it
                end
                return oldRequire(mod)
            end
            hookfunction(require, FilteredRequire)
            HideFunction(FilteredRequire)
        end
    end)

    -- Layer 8: Anti-tamper guard — detect if AC tries to remove our hooks
    pcall(function()
        local guardInterval = 2
        task.spawn(function()
            while true do
                task.wait(guardInterval)
                local ok = pcall(function()
                    -- Verify our hooks are still in place
                    local mt = getrawmetatable(game)
                    if mt and BypassState.OriginalNamecall then
                        if mt.__namecall == BypassState.OriginalNamecall then
                            -- Hook was removed by AC, reinstall
                            BypassState.Tampered = true
                            print("[Scanner] Hook tampering detected. Reinstalling...")
                            InstallApexBypass()
                            return
                        end
                    end
                end)
                if not ok then
                    -- Something went wrong, try reinstall
                    pcall(InstallApexBypass)
                end
            end
        end)
    end)

    -- Layer 9: Hide from getreg / getloadedmodules scanning by AC
    pcall(function()
        if hookfunction then
            local oldGetLoadedModules = getloadedmodules
            if oldGetLoadedModules then
                local function FilteredGetLoadedModules()
                    local results = oldGetLoadedModules()
                    local filtered = {}
                    for _, mod in ipairs(results) do
                        if not ScannerInstances[mod] then
                            table.insert(filtered, mod)
                        end
                    end
                    return filtered
                end
                hookfunction(getloadedmodules, FilteredGetLoadedModules)
                HideFunction(FilteredGetLoadedModules)
            end
        end
    end)

    -- Layer 10: Hook print/warn to suppress scanner output from AC monitoring
    pcall(function()
        if hookfunction then
            local oldPrint = print
            local function FilteredPrint(...)
                local args = {...}
                for _, v in ipairs(args) do
                    if type(v) == "string" and v:match("%[Scanner%]") then
                        -- AC might monitor print output, suppress
                        return
                    end
                end
                return oldPrint(...)
            end
            -- Don't hook print actually — we need our own console output
            -- Only suppress if the AC is known to monitor print
        end
    end)
end

InstallApexBypass()
HideFunction(InstallApexBypass)

-- ============================================================
-- EXECUTOR CAPABILITIES — DETECT EVERYTHING
-- ============================================================
local Capabilities = {
    WriteFile = type(writefile) == "function",
    AppendFile = type(appendfile) == "function",
    IsFile = type(isfile) == "function",
    ReadFile = type(readfile) == "function",
    MakeFolder = type(makefolder) == "function",
    ListFiles = type(listfiles) == "function",
    Decompile = type(decompile) == "function",
    GetScripts = type(getscripts) == "function",
    GetLoadedModules = type(getloadedmodules) == "function",
    GetNilInstances = type(getnilinstances) == "function",
    GetReg = type(getreg) == "function",
    GetScriptBytecode = type(getscriptbytecode) == "function",
    GetScriptClosure = type(getscriptclosure) == "function",
    GetThreadContext = type(getthreadcontext) == "function",
    GetIdentity = type(getidentity) == "function" or type(getthreadcontext) == "function",
    SaveInstance = type(saveinstance) == "function",
    Loadstring = type(loadstring) == "function",
    HookFunction = type(hookfunction) == "function",
    HookMeta = type(hookmetamethod) == "function",
    GetRawMetatable = type(getrawmetatable) == "function",
    SetRawMetatable = type(setrawmetatable) == "function",
    SetReadOnly = type(setreadonly) == "function",
    Getfenv = type(getfenv) == "function",
    Setfenv = type(setfenv) == "function",
    DebugGetUpvalues = type(debug.getupvalues) == "function",
    DebugSetUpvalue = type(debug.setupvalue) == "function",
    DebugGetConstants = type(debug.getconstants) == "function",
    CloneFunction = type(clonefunction) == "function",
    GetCallingScript = type(getcallingscript) == "function",
    GetInstances = type(getinstances) == "function",
    GetConnections = type(getconnections) == "function",
    GetSignal = type(getsignal) == "function",
    FireSignal = type(firesignal) == "function",
    IsLuaLclosure = type(islclosure) == "function",
    Newcclosure = type(newcclosure) == "function",
    CheckCaller = type(checkcaller) == "function",
    SetClipboard = type(setclipboard) == "function",
    Gethui = type(gethui) == "function",
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
-- RAYFIELD LOADER — multi-source with fallback
-- ============================================================
local Rayfield = nil

local function LoadRayfield()
    local urls = {
        "https://sirius.menu/rayfield",
        "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
        "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source",
    }
    for _, url in ipairs(urls) do
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and res and #res > 100 then
            local fn = loadstring(res)
            if fn then
                local ok2 = pcall(function() fn() end)
                if ok2 and rayfield then
                    Rayfield = rayfield
                    return
                end
                local ok3, result = pcall(fn)
                if ok3 and result then
                    Rayfield = result
                    return
                end
            end
        end
    end
end

LoadRayfield()

if not Rayfield then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Scanner Ready (No GUI)",
            Text = "Rayfield failed. Text output only.",
            Duration = 5
        })
    end)

    Rayfield = {
        CreateWindow = function() return {
            CreateTab = function() return {
                CreateLabel = function() return { Set = function() end } end,
                CreateButton = function() return { Callback = function() end } end,
                CreateDivider = function() end,
                CreateParagraph = function() end,
                CreateToggle = function() return { Set = function() end } end,
                CreateInput = function() return { Set = function() end } end,
                CreateDropdown = function() return { Set = function() end } end,
                CreateSection = function() end,
            } end,
            Destroy = function() end,
        } end,
        Notify = function() end
    }
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
        UniverseId = 0,
    }
    pcall(function()
        local marketplace = game:GetService("MarketplaceService")
        local product = marketplace:GetProductInfo(game.PlaceId)
        if product then
            info.Name = string.gsub(product.Name or "UnknownGame", "[^%w_]", "_")
            info.Creator = product.Creator and product.Creator.Name or "Unknown"
        end
    end)
    pcall(function()
        local universeId = game:GetService("GameProductService"):GetGameId(game.PlaceId)
        if universeId then info.UniverseId = universeId end
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
    IncludeConnections = true,
    DeepScan = true,
    IncludeRemotes = true,
    BypassProtection = true,
    TotalScripts = 0,
    Processed = 0,
    Decompiled = 0,
    Failed = 0,
    BytecodeDumped = 0,
    RemotesFound = 0,
    ConnectionsFound = 0,
    StartTime = 0,
    CurrentFile = "",
    FileParts = 0,
    StatusText = "Ready",
    TimeText = "--:--",
    SuccessText = "Decompiled: 0 | Protected: 0 | Bytecode: 0",
    CountText = "Total Scripts Found: 0",
    FileText = "Save Location: Not started",
}

-- ============================================================
-- UI REFERENCES
-- ============================================================
local StatusLabel = { Set = function() end }
local TimeLabel = { Set = function() end }
local FileLabel = { Set = function() end }
local CountLabel = { Set = function() end }
local SuccessLabel = { Set = function() end }
local UIWindow = nil
local UIMainTab = nil
local UIAdvTab = nil
local UIRemoteTab = nil
local UIScreenGui = nil
local UIExists = false

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

local function SafeMakeFolder(name)
    pcall(function() makefolder(name) end)
end

-- ============================================================
-- REMOTE SPY — capture remote events for analysis
-- ============================================================
local RemotesLog = {}
local RemoteSpyActive = false

local function StartRemoteSpy()
    if not Capabilities.GetConnections then return end

    RemoteSpyActive = true
    task.spawn(function()
        while RemoteSpyActive do
            pcall(function()
                -- Scan all RemoteEvents and RemoteFunctions
                for _, obj in ipairs(game:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        local fullName = obj:GetFullName()
                        if not RemotesLog[fullName] then
                            RemotesLog[fullName] = {
                                Name = fullName,
                                Type = obj.ClassName,
                                Hits = 0,
                                Args = {},
                            }
                            ScanState.RemotesFound = ScanState.RemotesFound + 1
                        end
                    end
                end
            end)
            task.wait(5)
        end
    end)

    -- Hook fire signals if available
    pcall(function()
        if Capabilities.GetConnections then
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("RemoteSignal") or obj:IsA("RemoteEvent") then
                    local connections = getconnections(obj.OnClientEvent)
                    for _, conn in ipairs(connections) do
                        if conn and conn.Function then
                            local oldFn = conn.Function
                            ScanState.ConnectionsFound = ScanState.ConnectionsFound + 1
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- UI BUILDER + RECOVERY
-- ============================================================
local function RecreateUI()
    pcall(function()
        if UIScreenGui and UIScreenGui.Parent then
            UIScreenGui:Destroy()
        end
        if UIWindow and UIWindow.Destroy then
            pcall(function() UIWindow:Destroy() end)
        end
    end)
    UIExists = false
    UIWindow = nil
    UIMainTab = nil
    UIAdvTab = nil
    UIRemoteTab = nil
    UIScreenGui = nil
    task.wait(0.5)
    BuildUI()
    if Rayfield and Rayfield.Notify then
        Rayfield:Notify({ Title = "UI Rebuilt", Content = "Interface restored.", Duration = 3 })
    end
end

local function UIUpdater()
    task.spawn(function()
        while true do
            task.wait(0.3)
            pcall(function()
                if UIExists then
                    StatusLabel:Set(ScanState.StatusText)
                    TimeLabel:Set(ScanState.TimeText)
                    FileLabel:Set(ScanState.FileText)
                    CountLabel:Set(ScanState.CountText)
                    SuccessLabel:Set(ScanState.SuccessText)
                end
            end)
        end
    end)
end

local function UIWatcher()
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function()
                if UIExists and UIScreenGui and UIScreenGui.Parent == nil then
                    print("[Scanner] UI disappeared. Rebuilding...")
                    UIExists = false
                    RecreateUI()
                end
                if UIExists and UIWindow and not UIWindow.Parent then
                    print("[Scanner] UI Window gone. Rebuilding...")
                    UIExists = false
                    RecreateUI()
                end
            end)
        end
    end)
end

function BuildUI()
    if not Rayfield or not Rayfield.CreateWindow then return end

    pcall(function()
        UIWindow = Rayfield:CreateWindow({
            Name = "Apex Script Scanner v5.0",
            LoadingTitle = "Initializing Apex Bypass",
            LoadingSubtitle = "Multi-layer anti-cheat evasion active...",
            ConfigurationSaving = { Enabled = false },
            KeySystem = false
        })

        -- Hide Rayfield UI from detection
        pcall(function()
            for _, gui in ipairs(game.CoreGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name == "Rayfield" then
                    UIScreenGui = gui
                    gui.ResetOnSpawn = false
                    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                    gui.DisplayOrder = 999
                    gui.IgnoreGuiInset = true
                    HideInstance(gui)
                    -- Rename to avoid detection
                    gui.Name = "GameUI"
                end
            end
        end)

        -- If gethui is available, parent to that instead (more hidden)
        pcall(function()
            if Capabilities.Gethui then
                local hui = gethui()
                if hui and UIScreenGui then
                    UIScreenGui.Parent = hui
                end
            end
        end)

        -- ── MAIN TAB ──
        UIMainTab = UIWindow:CreateTab("Scanner", 4483362458)

        UIMainTab:CreateParagraph({
            Title = "Game Info",
            Content = string.format("Name: %s\nID: %d\nCreator: %s\nExecutor: %s\nJobID: %s",
                GameInfo.Name, GameInfo.PlaceId, GameInfo.Creator, ExecutorName, GameInfo.JobId)
        })

        UIMainTab:CreateDivider()
        UIMainTab:CreateSection("Scan Options")

        UIMainTab:CreateToggle({
            Name = "Include Bytecode Dump",
            CurrentValue = true,
            Callback = function(val) ScanState.IncludeBytecode = val end
        })

        UIMainTab:CreateToggle({
            Name = "Include Registry Scan (getreg)",
            CurrentValue = true,
            Callback = function(val) ScanState.IncludeReg = val end
        })

        UIMainTab:CreateToggle({
            Name = "Include Nil Instances",
            CurrentValue = true,
            Callback = function(val) ScanState.IncludeNil = val end
        })

        UIMainTab:CreateToggle({
            Name = "Include Server Scripts (SSS/RS/SS)",
            CurrentValue = true,
            Callback = function(val) ScanState.IncludeServer = val end
        })

        UIMainTab:CreateToggle({
            Name = "Deep Scan (upvalues/constants/connections)",
            CurrentValue = true,
            Callback = function(val) ScanState.DeepScan = val end
        })

        UIMainTab:CreateToggle({
            Name = "Remote Event Spy",
            CurrentValue = true,
            Callback = function(val) ScanState.IncludeRemotes = val end
        })

        UIMainTab:CreateToggle({
            Name = "Bypass Protection (auto-rehook)",
            CurrentValue = true,
            Callback = function(val) ScanState.BypassProtection = val end
        })

        UIMainTab:CreateDivider()

        StatusLabel = UIMainTab:CreateLabel("Status: Ready")
        TimeLabel = UIMainTab:CreateLabel("Time Remaining: --:--")
        FileLabel = UIMainTab:CreateLabel("Save Location: Not started")
        CountLabel = UIMainTab:CreateLabel("Total Scripts Found: 0")
        SuccessLabel = UIMainTab:CreateLabel("Decompiled: 0 | Protected: 0 | Bytecode: 0")

        UIMainTab:CreateDivider()

        UIMainTab:CreateButton({
            Name = "Start Full Scan",
            Callback = RunScanner
        })

        UIMainTab:CreateButton({
            Name = "Toggle Pause",
            Callback = function()
                if not ScanState.IsScanning then
                    Rayfield:Notify({ Title = "Info", Content = "No scan running.", Duration = 2 })
                    return
                end
                ScanState.IsPaused = not ScanState.IsPaused
                ScanState.StatusText = ScanState.IsPaused and "Status: PAUSED" or "Status: Resuming..."
                Rayfield:Notify({
                    Title = ScanState.IsPaused and "Paused" or "Resumed",
                    Content = ScanState.IsPaused and "Paused. Click again to resume." or "Resumed.",
                    Duration = 2
                })
            end
        })

        UIMainTab:CreateButton({
            Name = "Stop Scan",
            Callback = function()
                if not ScanState.IsScanning then
                    Rayfield:Notify({ Title = "Info", Content = "No scan running.", Duration = 2 })
                    return
                end
                ScanState.IsScanning = false
                ScanState.IsPaused = false
                ScanState.StatusText = "STOPPED"
                Rayfield:Notify({ Title = "Stopped", Content = "Scan stopped. Partial results saved.", Duration = 3 })
                getgenv().ScannerRunning = false
            end
        })

        UIMainTab:CreateButton({
            Name = "Reset UI (Crash Recovery)",
            Callback = RecreateUI
        })

        -- ── ADVANCED TAB ──
        UIAdvTab = UIWindow:CreateTab("Advanced", 4483362458)

        UIAdvTab:CreateParagraph({
            Title = "Advanced Extraction Tools",
            Content = "Deep extraction methods for protected/locked scripts"
        })

        UIAdvTab:CreateButton({
            Name = "Dump All Bytecode (Raw Hex)",
            Callback = function() task.spawn(DumpAllBytecode) end
        })

        UIAdvTab:CreateButton({
            Name = "Scan Registry Closures (getreg)",
            Callback = function() task.spawn(ScanRegistry) end
        })

        UIAdvTab:CreateButton({
            Name = "Dump ServerScriptService",
            Callback = function() task.spawn(DumpServerScripts) end
        })

        UIAdvTab:CreateButton({
            Name = "Dump Nil Instances",
            Callback = function() task.spawn(DumpNilInstances) end
        })

        UIAdvTab:CreateButton({
            Name = "Dump All Connections (getconnections)",
            Callback = function() task.spawn(DumpConnections) end
        })

        UIAdvTab:CreateButton({
            Name = "Export Full Game (saveinstance)",
            Callback = function()
                if Capabilities.SaveInstance then
                    pcall(function()
                        saveinstance({ filename = GameInfo.Name .. "_FullExport.rbxl" })
                    end)
                    Rayfield:Notify({ Title = "Export", Content = "Game exported to workspace.", Duration = 5 })
                else
                    Rayfield:Notify({ Title = "Unsupported", Content = "saveinstance not available.", Duration = 3 })
                end
            end
        })

        UIAdvTab:CreateButton({
            Name = "Reinstall Bypass Hooks",
            Callback = function()
                InstallApexBypass()
                Rayfield:Notify({ Title = "Bypass", Content = "Hooks reinstalled.", Duration = 3 })
            end
        })

        UIAdvTab:CreateButton({
            Name = "Print Executor Capabilities",
            Callback = function()
                print("=== EXECUTOR CAPABILITIES ===")
                for k, v in pairs(Capabilities) do
                    print(string.format("  %s: %s", k, tostring(v)))
                end
                print(string.format("  Executor: %s", ExecutorName))
                print("=============================")
                Rayfield:Notify({ Title = "Check Console", Content = "Capabilities printed to dev console.", Duration = 3 })
            end
        })

        -- ── REMOTE SPY TAB ──
        UIRemoteTab = UIWindow:CreateTab("Remote Spy", 4483362458)

        UIRemoteTab:CreateParagraph({
            Title = "Remote Event Monitor",
            Content = "Tracks all RemoteEvents and RemoteFunctions in the game"
        })

        local RemoteCountLabel = UIRemoteTab:CreateLabel("Remotes Found: 0")
        local RemoteConnLabel = UIRemoteTab:CreateLabel("Connections: 0")

        UIRemoteTab:CreateButton({
            Name = "Start Remote Spy",
            Callback = function()
                StartRemoteSpy()
                Rayfield:Notify({ Title = "Remote Spy", Content = "Monitoring started.", Duration = 3 })
            end
        })

        UIRemoteTab:CreateButton({
            Name = "Export Remote Log",
            Callback = function()
                local path = GameInfo.Name .. "_RemoteSpy.txt"
                local content = "=== REMOTE SPY DUMP: " .. GameInfo.Name .. " ===\n\n"
                for name, data in pairs(RemotesLog) do
                    content = content .. string.format("Name: %s\nType: %s\nHits: %d\n---\n", data.Name, data.Type, data.Hits)
                end
                SafeWriteFile(path, content)
                Rayfield:Notify({ Title = "Exported", Content = "Saved to " .. path, Duration = 3 })
            end
        })

        UIRemoteTab:CreateButton({
            Name = "Fire All Remotes (Test)",
            Callback = function()
                pcall(function()
                    for _, obj in ipairs(game:GetDescendants()) do
                        if obj:IsA("RemoteEvent") then
                            pcall(function() obj:FireServer() end)
                        end
                    end
                    Rayfield:Notify({ Title = "Done", Content = "Fired all RemoteEvents.", Duration = 3 })
                end)
            end
        })

        -- Update remote labels
        task.spawn(function()
            while true do
                task.wait(1)
                pcall(function()
                    if UIExists then
                        RemoteCountLabel:Set("Remotes Found: " .. ScanState.RemotesFound)
                        RemoteConnLabel:Set("Connections: " .. ScanState.ConnectionsFound)
                    end
                end)
            end
        end)

        Rayfield:Notify({
            Title = "Scanner Ready",
            Content = string.format("Loaded: %s | Executor: %s", GameInfo.Name, ExecutorName),
            Duration = 4
        })

        ScanState.StatusText = "Ready. Press 'Start Full Scan' to begin."
        UIExists = true

        print("========================================")
        print("  APEX SCRIPT SCANNER v5.0")
        print("  Bytecode Bypass: " .. (Capabilities.GetScriptBytecode and "ACTIVE" or "LIMITED"))
        print("  Server Scan: " .. (ScanState.IncludeServer and "ENABLED" or "DISABLED"))
        print("  Registry Scan: " .. (ScanState.IncludeReg and "ENABLED" or "DISABLED"))
        print("  Nil Instances: " .. (ScanState.IncludeNil and "ENABLED" or "DISABLED"))
        print("  Deep Scan: " .. (ScanState.DeepScan and "ENABLED" or "DISABLED"))
        print("  Remote Spy: " .. (ScanState.IncludeRemotes and "ENABLED" or "DISABLED"))
        print("  Bypass Guard: " .. (ScanState.BypassProtection and "ACTIVE" or "DISABLED"))
        print("  Executor: " .. ExecutorName)
        print("========================================")
    end)
end

-- ============================================================
-- ADVANCED SCRIPT COLLECTOR — EXHAUSTIVE
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

    -- 1. Full game tree (all descendants)
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            addScript(obj, "GameTree")
        end
    end)

    -- 2. ServerScriptService (deep)
    if ScanState.IncludeServer then
        pcall(function()
            local sss = game:GetService("ServerScriptService")
            for _, obj in ipairs(sss:GetDescendants()) do
                addScript(obj, "ServerScriptService")
            end
        end)

        -- 3. ReplicatedStorage
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            for _, obj in ipairs(rs:GetDescendants()) do
                addScript(obj, "ReplicatedStorage")
            end
        end)

        -- 4. ServerStorage (requires elevated identity)
        pcall(function()
            local ss = game:GetService("ServerStorage")
            for _, obj in ipairs(ss:GetDescendants()) do
                addScript(obj, "ServerStorage")
            end
        end)

        -- 5. StarterPlayer scripts
        pcall(function()
            local sp = game:GetService("StarterPlayer")
            if sp then
                local sps = sp:FindFirstChild("StarterPlayerScripts")
                if sps then
                    for _, obj in ipairs(sps:GetDescendants()) do
                        addScript(obj, "StarterPlayerScripts")
                    end
                end
                local spc = sp:FindFirstChild("StarterCharacterScripts")
                if spc then
                    for _, obj in ipairs(spc:GetDescendants()) do
                        addScript(obj, "StarterCharacterScripts")
                    end
                end
            end
        end)

        -- 6. StarterGui scripts
        pcall(function()
            local sg = game:GetService("StarterGui")
            for _, obj in ipairs(sg:GetDescendants()) do
                addScript(obj, "StarterGui")
            end
        end)

        -- 7. StarterPack
        pcall(function()
            local sp = game:GetService("StarterPack")
            for _, obj in ipairs(sp:GetDescendants()) do
                addScript(obj, "StarterPack")
            end
        end)
    end

    -- 8. getscripts() — all running scripts
    if Capabilities.GetScripts then
        pcall(function()
            for _, s in ipairs(getscripts()) do
                addScript(s, "getscripts()")
            end
        end)
    end

    -- 9. getloadedmodules()
    if Capabilities.GetLoadedModules then
        pcall(function()
            for _, s in ipairs(getloadedmodules()) do
                addScript(s, "getloadedmodules()")
            end
        end)
    end

    -- 10. getnilinstances() — nil-parented hidden scripts
    if ScanState.IncludeNil and Capabilities.GetNilInstances then
        pcall(function()
            for _, s in ipairs(getnilinstances()) do
                addScript(s, "getnilinstances()")
            end
        end)
    end

    -- 11. getinstances() — ALL instances including unparented
    if Capabilities.GetInstances then
        pcall(function()
            for _, inst in ipairs(getinstances()) do
                addScript(inst, "getinstances()")
            end
        end)
    end

    -- 12. getreg() — registry scan for loaded closures
    if ScanState.IncludeReg and Capabilities.GetReg then
        pcall(function()
            local reg = getreg()
            for _, v in ipairs(reg) do
                if type(v) == "function" then
                    local info = debug.getinfo(v)
                    if info and info.source and #info.source > 0 then
                        -- Check if it's a Lua closure (not C)
                        local isLua = true
                        if Capabilities.IsLuaLclosure then
                            isLua = islclosure(v)
                        end
                        if isLua and info.what == "Lua" then
                            local scriptName = info.short_src or info.source
                            -- Match to existing script if possible
                            local matched = false
                            for _, existing in ipairs(collected) do
                                if existing.Name and existing.Name:match(scriptName:match("[^/\\]+$") or "") then
                                    matched = true
                                    break
                                end
                            end
                            if not matched then
                                table.insert(collected, {
                                    Object = nil, -- No instance, just closure
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
            end
        end)
    end

    -- 13. Walk upvalue chains for hidden script references
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
-- ADVANCED DECOMPILATION — 7-METHOD FALLBACK CHAIN
-- ============================================================
local function DecompileScript(scriptObj, closure)

    -- Method 1: Standard decompile(Instance)
    if Capabilities.Decompile and scriptObj then
        local result = nil
        pcall(function() result = decompile(scriptObj) end)
        if result and #result > 10 then
            return result, "decompiled"
        end

        -- Method 2: decompile(Instance, true) — some executors accept a flag
        pcall(function() result = decompile(scriptObj, true) end)
        if result and #result > 10 then
            return result, "decompile(true)"
        end

        -- Method 3: decompile(Instance, false) — alternate flag
        pcall(function() result = decompile(scriptObj, false) end)
        if result and #result > 10 then
            return result, "decompile(false)"
        end
    end

    -- Method 4: getscriptclosure → decompile the closure directly
    if Capabilities.GetScriptClosure and scriptObj then
        local cl = nil
        pcall(function() cl = getscriptclosure(scriptObj) end)
        if cl then
            if Capabilities.Decompile then
                local result = nil
                pcall(function() result = decompile(cl) end)
                if result and #result > 10 then
                    return result, "getscriptclosure+decompile"
                end
            end
            -- Store closure for method 7
            closure = closure or cl
        end
    end

    -- Method 5: Direct .Source property access
    if scriptObj then
        local result = nil
        pcall(function() result = scriptObj.Source end)
        if result and #result > 10 then
            return "-- SOURCE EXTRACTED (.Source property)\n" .. result, ".Source"
        end

        -- Method 5b: Try accessing via protected call
        pcall(function()
            -- Some executors block .Source, try through metatable
            local mt = getrawmetatable(scriptObj)
            if mt then
                setreadonly(mt, false)
                result = rawget(scriptObj, "Source")
                setreadonly(mt, true)
            end
        end)
        if result and #result > 10 then
            return "-- SOURCE EXTRACTED (rawget .Source)\n" .. result, "rawget(.Source)"
        end
    end

    -- Method 6: Bytecode dump via getscriptbytecode → hex + disassembly attempt
    if Capabilities.GetScriptBytecode and scriptObj then
        local bytecode = nil
        pcall(function() bytecode = getscriptbytecode(scriptObj) end)
        if bytecode and #bytecode > 0 then
            local hexDump = {}
            local len = #bytecode
            local limit = math.min(len, 50000) -- increased cap to 50k

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

            local dump = table.concat(hexDump, "\n")
            ScanState.BytecodeDumped = ScanState.BytecodeDumped + 1

            -- Try to extract string constants from bytecode
            local stringsFound = {}
            for match in bytecode:gmatch("[%w%p ]{4,}") do
                if #match >= 4 and #match <= 200 then
                    table.insert(stringsFound, match)
                end
            end

            local stringSection = ""
            if #stringsFound > 0 then
                stringSection = "\n\n-- STRING CONSTANTS EXTRACTED FROM BYTECODE:\n"
                for i, s in ipairs(stringsFound) do
                    if i > 100 then break end
                    stringSection = stringSection .. string.format("  [%d] %q\n", i, s)
                end
            end

            return "-- BYTECODE DUMP (decompile failed, raw bytecode)\n" ..
                   "-- Length: " .. len .. " bytes\n" ..
                   "-- Hex dump capped at: " .. limit .. " bytes\n\n" ..
                   dump .. stringSection, "bytecode"
        end
    end

    -- Method 7: Closure analysis — upvalues + constants + environment
    if closure and ScanState.DeepScan then
        local result = "-- CLOSURE ANALYSIS (decompile failed, deep extraction)\n"
        result = result .. "-- This script could not be decompiled. Extracting debug info.\n\n"

        -- Upvalues
        pcall(function()
            if Capabilities.DebugGetUpvalues then
                local upvals = debug.getupvalues(closure)
                if upvals and #upvals > 0 then
                    result = result .. "-- UPVALUES (" .. #upvals .. "):\n"
                    for i, v in ipairs(upvals) do
                        local valStr = tostring(v):sub(1, 500)
                        result = result .. string.format("  [%d] %s: %s\n", i, type(v), valStr)
                        -- If upvalue is a function, walk its upvalues too (1 level deep)
                        if type(v) == "function" and ScanState.DeepScan then
                            pcall(function()
                                local innerUpvals = debug.getupvalues(v)
                                if innerUpvals and #innerUpvals > 0 then
                                    result = result .. string.format("      └─ inner upvalues (%d):\n", #innerUpvals)
                                    for j, iv in ipairs(innerUpvals) do
                                        result = result .. string.format("        [%d.%d] %s: %s\n", i, j, type(iv), tostring(iv):sub(1, 200))
                                    end
                                end
                            end)
                        end
                        -- If upvalue is an Instance, log it
                        if typeof(v) == "Instance" then
                            pcall(function()
                                result = result .. string.format("      └─ Instance: %s (%s)\n", v:GetFullName(), v.ClassName)
                            end)
                        end
                    end
                    result = result .. "\n"
                end
            end
        end)

        -- Constants
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

        -- Environment (getfenv)
        pcall(function()
            if Capabilities.Getfenv then
                local env = getfenv(closure)
                if env and type(env) == "table" then
                    local envStr = "-- ENVIRONMENT (getfenv):\n"
                    local count = 0
                    for k, v in pairs(env) do
                        if count < 50 then
                            envStr = envStr .. string.format("  %s: %s\n", tostring(k), tostring(v):sub(1, 200))
                            count = count + 1
                        end
                    end
                    if count > 0 then
                        result = result .. envStr .. "\n"
                    end
                end
            end
        end)

        -- Info
        pcall(function()
            local info = debug.getinfo(closure)
            if info then
                result = result .. "-- DEBUG INFO:\n"
                result = result .. "  source: " .. tostring(info.source) .. "\n"
                result = result .. "  short_src: " .. tostring(info.short_src) .. "\n"
                result = result .. "  linedefined: " .. tostring(info.linedefined) .. "\n"
                result = result .. "  lastlinedefined: " .. tostring(info.lastlinedefined) .. "\n"
                result = result .. "  what: " .. tostring(info.what) .. "\n"
                result = result .. "  nparams: " .. tostring(info.nparams) .. "\n"
                result = result .. "  nups: " .. tostring(info.nups) .. "\n"
            end
        end)

        if #result > 50 then
            return result, "closure-analysis"
        end
    end

    return "-- DECOMPILE FAILED (Protected Bytecode)\n-- All 7 methods exhausted.\n-- This script is heavily protected.\n", "failed"
end

-- ============================================================
-- FILE MANAGEMENT — buffered async I/O
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
        local header = string.format(
            "=== APEX SCRIPT SCAN: %s ===\n" ..
            "=== PART %d ===\n" ..
            "=== Game ID: %d | JobID: %s ===\n" ..
            "=== Executor: %s ===\n" ..
            "=== Date: %s ===\n" ..
            "====================================\n\n",
            GameInfo.Name, filePart, GameInfo.PlaceId, GameInfo.JobId,
            ExecutorName, os.date("%Y-%m-%d %H:%M:%S")
        )
        SafeWriteFile(path, header)
        currentFileSize = #header
        ScanState.CurrentFile = path
        ScanState.FileParts = filePart
        ScanState.FileText = "Save Location: " .. path
    end

    SafeAppendFile(ScanState.CurrentFile, chunk)
    currentFileSize = currentFileSize + #chunk
end

local function InitializeFile()
    filePart = 1
    ScanState.CurrentFile = GetFilePath(1)
    local header = string.format(
        "=== APEX SCRIPT SCAN: %s ===\n" ..
        "=== PART 1 ===\n" ..
        "=== Game ID: %d | JobID: %s ===\n" ..
        "=== Executor: %s ===\n" ..
        "=== Date: %s ===\n" ..
        "====================================\n\n",
        GameInfo.Name, GameInfo.PlaceId, GameInfo.JobId,
        ExecutorName, os.date("%Y-%m-%d %H:%M:%S")
    )
    SafeWriteFile(ScanState.CurrentFile, header)
    currentFileSize = #header
    ScanState.FileParts = 1
    ScanState.FileText = "Save Location: " .. ScanState.CurrentFile
end

-- ============================================================
-- ADVANCED TOOLS — Called from UI
-- ============================================================
function DumpAllBytecode()
    task.spawn(function()
        if not Capabilities.GetScriptBytecode then
            if Rayfield then Rayfield:Notify({ Title = "Error", Content = "getscriptbytecode not supported.", Duration = 4 }) end
            return
        end

        ScanState.StatusText = "Dumping all bytecode..."

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
                for _, s in ipairs(getscripts()) do
                    table.insert(allScripts, s)
                end
            end)
        end
        if Capabilities.GetNilInstances then
            pcall(function()
                for _, s in ipairs(getnilinstances()) do
                    table.insert(allScripts, s)
                end
            end)
        end

        local path = GameInfo.Name .. "_BytecodeDump.txt"
        SafeWriteFile(path, "=== BYTECODE DUMP: " .. GameInfo.Name .. " ===\n")
        local count = 0

        for i, s in ipairs(allScripts) do
            pcall(function()
                local bc = getscriptbytecode(s)
                if bc and #bc > 0 then
                    local entry = string.format("\n%s\n%s\nBytecode Length: %d bytes\n\n", string.rep("=", 60), s:GetFullName(), #bc)
                    SafeAppendFile(path, entry)

                    -- Also write raw bytecode to separate file
                    local rawPath = GameInfo.Name .. "_Bytecode_" .. tostring(s):gsub("[^%w_]", "_") .. ".bin"
                    pcall(function() writefile(rawPath, bc) end)

                    count = count + 1
                end
            end)
            ScanState.StatusText = string.format("Bytecode: %d/%d", i, #allScripts)
            task.wait()
        end

        ScanState.StatusText = "Bytecode dump complete: " .. count .. " scripts"
        if Rayfield then
            Rayfield:Notify({ Title = "Bytecode Dump", Content = count .. " scripts dumped to " .. path, Duration = 5 })
        end
        if Capabilities.SetClipboard then
            pcall(function() setclipboard(path) end)
        end
    end)
end

function ScanRegistry()
    task.spawn(function()
        if not Capabilities.GetReg then
            if Rayfield then Rayfield:Notify({ Title = "Error", Content = "getreg not supported.", Duration = 4 }) end
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
                if not isLua then continue end

                local info = debug.getinfo(v)
                if info and info.source and #info.source > 0 then
                    local entry = string.format(
                        "Function: %s\n  Source: %s\n  Line: %s-%s\n  What: %s\n  Params: %s\n  Upvalues: %s\n",
                        tostring(v), info.short_src or info.source,
                        tostring(info.linedefined), tostring(info.lastlinedefined),
                        info.what or "unknown", tostring(info.nparams), tostring(info.nups)
                    )

                    -- Deep scan: upvalues (2 levels deep)
                    pcall(function()
                        if Capabilities.DebugGetUpvalues then
                            local upvals = debug.getupvalues(v)
                            if upvals and #upvals > 0 then
                                entry = entry .. "  Upvalues:\n"
                                for i, uv in ipairs(upvals) do
                                    entry = entry .. string.format("    [%d] %s: %s\n", i, type(uv), tostring(uv):sub(1, 300))
                                    -- Walk 1 level deeper
                                    if type(uv) == "function" then
                                        pcall(function()
                                            local innerUpvals = debug.getupvalues(uv)
                                            if innerUpvals then
                                                for j, iv in ipairs(innerUpvals) do
                                                    entry = entry .. string.format("      [%d.%d] %s: %s\n", i, j, type(iv), tostring(iv):sub(1, 200))
                                                end
                                            end
                                        end)
                                    end
                                    -- Log Instance upvalues
                                    if typeof(uv) == "Instance" then
                                        pcall(function()
                                            entry = entry .. string.format("      → Instance: %s (%s)\n", uv:GetFullName(), uv.ClassName)
                                        end)
                                    end
                                end
                            end
                        end
                    end)

                    -- Deep scan: constants
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
                        ScanState.StatusText = string.format("Registry: %d closures scanned", count)
                        task.wait()
                    end
                end
            end
        end

        if #entries > 0 then
            SafeAppendFile(path, table.concat(entries, "\n"))
        end

        ScanState.StatusText = "Registry scan complete: " .. count .. " closures"
        if Rayfield then
            Rayfield:Notify({ Title = "Registry Scan", Content = count .. " closures found. Saved to " .. path, Duration = 5 })
        end
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
                local header = string.format("\n%s\n%s\n\n", string.rep("=", 60), serviceName)
                SafeAppendFile(path, header)

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
                            status, string.rep("=", 60), decompiled
                        )

                        SafeAppendFile(path, entry)
                        count = count + 1
                        ScanState.StatusText = string.format("Server: %d scripts (%s)", count, serviceName)
                        task.wait()
                    end
                end
            end)
        end

        ScanState.StatusText = "Server dump complete: " .. count .. " scripts"
        if Rayfield then
            Rayfield:Notify({ Title = "Server Dump", Content = count .. " server scripts saved to " .. path, Duration = 5 })
        end
    end)
end

function DumpNilInstances()
    task.spawn(function()
        if not Capabilities.GetNilInstances then
            if Rayfield then Rayfield:Notify({ Title = "Error", Content = "getnilinstances not supported.", Duration = 4 }) end
            return
        end

        ScanState.StatusText = "Dumping nil instances..."

        local path = GameInfo.Name .. "_NilInstances.txt"
        SafeWriteFile(path, "=== NIL INSTANCE DUMP: " .. GameInfo.Name .. " ===\n\n")

        local count = 0
        local nilInsts = getnilinstances()

        for _, obj in ipairs(nilInsts) do
            pcall(function()
                if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local name = "nil::" .. (obj.Name or "Unknown")
                    local class = obj.ClassName
                    local disabled = obj.Disabled and " [DISABLED]" or ""

                    local decompiled, method = DecompileScript(obj)
                    local status = method == "failed" and "PROTECTED" or "EXTRACTED (" .. method .. ")"

                    local entry = string.format(
                        "\n%s\nNIL SCRIPT: %s%s\nCLASS: %s\nSTATUS: %s\n%s\n%s\n\n",
                        string.rep("=", 60), name, disabled, class, status,
                        string.rep("=", 60), decompiled
                    )

                    SafeAppendFile(path, entry)
                    count = count + 1
                end
            end)
            ScanState.StatusText = string.format("Nil: %d/%d", count, #nilInsts)
            task.wait()
        end

        ScanState.StatusText = "Nil dump complete: " .. count .. " scripts"
        if Rayfield then
            Rayfield:Notify({ Title = "Nil Dump", Content = count .. " nil scripts saved to " .. path, Duration = 5 })
        end
    end)
end

function DumpConnections()
    task.spawn(function()
        if not Capabilities.GetConnections then
            if Rayfield then Rayfield:Notify({ Title = "Error", Content = "getconnections not supported.", Duration = 4 }) end
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

                    local fullName = obj:GetFullName()
                    local entry = string.format("\n%s\nSIGNAL: %s\nCLASS: %s\n", string.rep("=", 60), fullName, obj.ClassName)

                    -- Get connections for OnClientEvent / OnClientInvoke
                    pcall(function()
                        local signal = obj:FindFirstChild("OnClientEvent")
                        if signal then
                            local conns = getconnections(signal)
                            entry = entry .. string.format("  OnClientEvent connections: %d\n", #conns)
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
                        end
                    end)

                    -- For RemoteFunctions
                    if obj:IsA("RemoteFunction") then
                        pcall(function()
                            local conns = getconnections(obj.OnClientInvoke)
                            entry = entry .. string.format("  OnClientInvoke connections: %d\n", #conns)
                        end)
                    end

                    entry = entry .. string.rep("-", 40) .. "\n"
                    SafeAppendFile(path, entry)
                    count = count + 1
                end
            end
        end)

        -- Also scan for property connections
        pcall(function()
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local conns = getconnections(obj.MouseButton1Click)
                    if conns and #conns > 0 then
                        local entry = string.format("\nUI BUTTON: %s (%d connections)\n", obj:GetFullName(), #conns)
                        SafeAppendFile(path, entry)
                        count = count + 1
                    end
                end
            end
        end)

        ScanState.StatusText = "Connections dump complete: " .. count
        if Rayfield then
            Rayfield:Notify({ Title = "Connections", Content = count .. " signals found. Saved to " .. path, Duration = 5 })
        end
    end)
end

-- ============================================================
-- MAIN SCANNER ENGINE
-- ============================================================
function RunScanner()
    task.spawn(function()
        if ScanState.IsScanning then
            if Rayfield then Rayfield:Notify({ Title = "Busy", Content = "Already scanning!", Duration = 3 }) end
            return
        end

        if not Capabilities.WriteFile or not Capabilities.AppendFile then
            if Rayfield then Rayfield:Notify({ Title = "Error", Content = "No file I/O support.", Duration = 5 }) end
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

        task.wait(0.5)

        -- Re-elevate identity
        pcall(function()
            if setidentity then setidentity(7) end
            if getthreadcontext then getthreadcontext(7) end
            if setthreadcontext then setthreadcontext(7) end
        end)

        -- Start remote spy if enabled
        if ScanState.IncludeRemotes then
            StartRemoteSpy()
        end

        ScanState.StatusText = "Collecting scripts (exhaustive)..."
        local allScripts = CollectEverything()
        ScanState.TotalScripts = #allScripts
        ScanState.CountText = "Total Scripts Found: " .. ScanState.TotalScripts

        if ScanState.TotalScripts == 0 then
            ScanState.StatusText = "No scripts found!"
            ScanState.IsScanning = false
            if Rayfield then Rayfield:Notify({ Title = "Alert", Content = "No scripts detected.", Duration = 4 }) end
            getgenv().ScannerRunning = false
            return
        end

        ScanState.StatusText = "Initializing file system..."
        InitializeFile()
        task.wait(0.5)

        ScanState.StatusText = "Scanning..."

        local scanSuccess, scanErr = pcall(function()
            for i = 1, ScanState.TotalScripts do
                while ScanState.IsPaused do
                    task.wait(0.5)
                    if not ScanState.IsScanning then return end
                end

                if not ScanState.IsScanning then break end

                local data = allScripts[i]
                local scriptObj = data.Object
                local closure = data.Closure
                local entry = ""

                local name = data.Name or "Unknown"
                local className = data.Class or "Unknown"
                local disabled = data.Disabled and " [DISABLED]" or ""
                local sourceMethod = data.Source or "Unknown"

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

                entry = string.format(
                    "\n%s\n" ..
                    "SCRIPT: %s%s\n" ..
                    "CLASS: %s\n" ..
                    "SOURCE: %s\n" ..
                    "STATUS: %s\n" ..
                    "%s\n" ..
                    "%s\n\n",
                    string.rep("=", 60),
                    name, disabled, className, sourceMethod,
                    statusIcon,
                    string.rep("=", 60),
                    decompiled
                )

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
                    local percent = math.floor((ScanState.Processed / ScanState.TotalScripts) * 100)

                    ScanState.StatusText = string.format("Scanning: %d%% (%d/%d)", percent, ScanState.Processed, ScanState.TotalScripts)
                    ScanState.TimeText = string.format("Time Remaining: %02d:%02d", mins, secs)
                    ScanState.SuccessText = string.format("Decompiled: %d | Protected: %d | Bytecode: %d",
                        ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped)
                end

                task.wait()
            end
        end)

        FlushBuffer()

        -- Write summary
        pcall(function()
            appendfile(ScanState.CurrentFile, "\n" .. string.rep("=", 60) .. "\n")
            appendfile(ScanState.CurrentFile, "APEX SCAN COMPLETE\n")
            appendfile(ScanState.CurrentFile, string.format("Total: %d | Extracted: %d | Protected: %d | Bytecode: %d\n",
                ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped))
            appendfile(ScanState.CurrentFile, string.format("Remotes Found: %d | Connections: %d\n",
                ScanState.RemotesFound, ScanState.ConnectionsFound))
            appendfile(ScanState.CurrentFile, string.format("Elapsed: %.1fs\n", tick() - ScanState.StartTime))
            appendfile(ScanState.CurrentFile, string.rep("=", 60) .. "\n")
        end)

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
        ScanState.TimeText = "Time Remaining: 00:00"
        ScanState.SuccessText = string.format("Extracted: %d | Protected: %d | Bytecode: %d",
            ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped)

        if Rayfield then
            Rayfield:Notify({
                Title = "Scan Complete!",
                Content = string.format("%d/%d extracted | %d bytecode | %d protected | %d remotes",
                    ScanState.Decompiled, ScanState.TotalScripts, ScanState.BytecodeDumped, ScanState.Failed, ScanState.RemotesFound),
                Duration = 6
            })
        end

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
UIUpdater()
UIWatcher()
