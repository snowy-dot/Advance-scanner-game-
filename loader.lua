--!nocheck
-- ============================================================
-- ULTIMATE UNIVERSAL SCRIPT SCANNER v4.0 — ADVANCED
-- - Bytecode bypass (hookmeta, getscriptbytecode, getscriptclosure)
-- - Server-side script scanning (ReplicatedStorage, ServerScriptService, nil instances)
-- - Deep decompile (multi-method fallback chain)
-- - Anti-detection hooks
-- - Memory registry scan (getreg) for loaded closures
-- - Raw bytecode dump fallback
-- - UI persistence + auto-recovery
-- ============================================================

if getgenv().ScannerRunning then
    print("[Scanner] Already running. Skipping duplicate.")
    return
end
getgenv().ScannerRunning = true

-- ============================================================
-- ADVANCED BYPASS LAYER
-- ============================================================
local BypassState = {
    HooksInstalled = false,
    OriginalGetInfo = nil,
    OriginalNamecall = nil,
    HiddenScripts = {},
}

local function InstallBypass()
    -- Hook debug.getinfo to hide scanner traces
    pcall(function()
        if hookfunction and not BypassState.HooksInstalled then
            local oldGetInfo = debug.getinfo
            BypassState.OriginalGetInfo = oldGetInfo
            hookfunction(debug.getinfo, function(...)
                local args = {...}
                local info = oldGetInfo(...)
                if info and type(info) == "table" then
                    if info.source and info.source:match("Scanner") then
                        info.source = ""
                        info.short_src = ""
                    end
                    if info.func then
                        local originalFunc = info.func
                        info.func = function() return originalFunc end
                    end
                end
                return info
            end)
            BypassState.HooksInstalled = true
        end
    end)

    -- Hook namecall to intercept script integrity checks
    pcall(function()
        if hookmetamethod and not BypassState.OriginalNamecall then
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            BypassState.OriginalNamecall = oldNamecall

            setreadonly(mt, false)
            mt.__namecall = function(self, ...)
                local method = getnamecallmethod()
                if method == "GetFullName" and self == script then
                    return "Game.Workspace.Scanner"
                end
                return oldNamecall(self, ...)
            end
            setreadonly(mt, true)
        end
    end)

    -- Hook GetDescendants to hide scanner internals
    pcall(function()
        local mt = getrawmetatable(game)
        if mt then
            setreadonly(mt, false)
            local oldIndex = mt.__index
            mt.__index = function(t, k)
                if k == "GetDescendants" then
                    return function(self)
                        local results = {}
                        local raw = oldIndex(self, "GetDescendants")(self)
                        for _, v in ipairs(raw) do
                            if typeof(v) == "Instance" and v ~= script and v.Name ~= "ScriptScanner" and v.Name ~= "Scanner" then
                                table.insert(results, v)
                            end
                        end
                        return results
                    end
                end
                return oldIndex(t, k)
            end
            setreadonly(mt, true)
        end
    end)

    -- Hide from script monitoring systems
    pcall(function()
        if hookfunction then
            local oldError = error
            hookfunction(error, function(msg, level)
                if type(msg) == "string" and msg:match("[Ss]canner") then
                    return oldError("Unexpected behavior", level)
                end
                return oldError(msg, level)
            end)
        end
    end)
end

InstallBypass()

-- ============================================================
-- EXECUTOR CAPABILITIES — DETECT EVERYTHING
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
    GetThreadContext = type(getthreadcontext) == "function",
    GetIdentity = type(getidentity) == "function" or type(getthreadcontext) == "function",
    SaveInstance = type(saveinstance) == "function",
    Loadstring = type(loadstring) == "function",
    HookFunction = type(hookfunction) == "function",
    HookMeta = type(hookmetamethod) == "function",
    GetRawMetatable = type(getrawmetatable) == "function",
    SetRawMetatable = type(setrawmetatable) == "function",
    Getfenv = type(getfenv) == "function",
    Setfenv = type(setfenv) == "function",
    DebugGetUpvalues = type(debug.getupvalues) == "function",
    DebugSetUpvalue = type(debug.setupvalue) == "function",
    DebugGetConstants = type(debug.getconstants) == "function",
}

local ExecutorName = "Unknown"
if Capabilities.WriteFile then
    if Capabilities.GetReg and Capabilities.GetScriptBytecode then
        ExecutorName = "Synapse/Fluxus"
    elseif Capabilities.GetReg then
        ExecutorName = "Krnl"
    elseif Capabilities.GetScriptClosure then
        ExecutorName = "ScriptWare"
    else
        ExecutorName = "Compatible"
    end
end

-- Elevate identity if possible
pcall(function()
    if setidentity then setidentity(7) end
    if getthreadcontext then getthreadcontext(7) end
end)

-- ============================================================
-- RAYFIELD LOADER — with fallback
-- ============================================================
local Rayfield = nil

local function LoadRayfield()
    local urls = {
        "https://sirius.menu/rayfield",
        "https://raw.githubusercontent.com/shlexware/Rayfield/main/source"
    }
    for _, url in ipairs(urls) do
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and res then
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
                end            end
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
            } end
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
    TotalScripts = 0,
    Processed = 0,
    Decompiled = 0,
    Failed = 0,
    BytecodeDumped = 0,
    StartTime = 0,
    CurrentFile = "",
    FileParts = 0,
    StatusText = "Ready",
    TimeText = "--:--",
    SuccessText = "Decompiled: 0 | Protected: 0 | Bytecode: 0",
    CountText = "Total Scripts Found: 0",
    FileText = "Save Location: Not started"
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
            Name = "Advanced Script Scanner v4.0",
            LoadingTitle = "Initializing Advanced Bypass",
            LoadingSubtitle = "Hooking bytecode protections...",
            ConfigurationSaving = { Enabled = false },
            KeySystem = false
        })

        pcall(function()
            for _, gui in ipairs(game.CoreGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name == "Rayfield" then
                    UIScreenGui = gui
                    gui.ResetOnSpawn = false
                    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                    gui.DisplayOrder = 999
                    gui.IgnoreGuiInset = true
                end
            end
        end)

        UIMainTab = UIWindow:CreateTab("Scanner", 4483362458)

        UIMainTab:CreateParagraph({
            Title = "Game Info",
            Content = string.format("Name: %s\nID: %d\nCreator: %s\nExecutor: %s\nJobID: %s",
                GameInfo.Name, GameInfo.PlaceId, GameInfo.Creator, ExecutorName, GameInfo.JobId)
        })

        UIMainTab:CreateDivider()

        -- SCAN OPTIONS
        UIMainTab:CreateParagraph({ Title = "Scan Options", Content = "Toggle what to include:" })

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
            Name = "Include Server Scripts (SSS/RS)",
            CurrentValue = true,
            Callback = function(val) ScanState.IncludeServer = val end
        })

        UIMainTab:CreateToggle({
            Name = "Deep Scan (upvalues/constants)",
            CurrentValue = true,
            Callback = function(val) ScanState.DeepScan = val end
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

        UIMainTab:CreateDivider()

        UIMainTab:CreateButton({
            Name = "Reset UI (If buttons disappear)",
            Callback = RecreateUI
        })

        -- ADVANCED TAB
        local advTab = UIWindow:CreateTab("Advanced", 4483362458)

        advTab:CreateParagraph({
            Title = "Advanced Tools",
            Content = "Extra extraction methods"
        })

        advTab:CreateButton({
            Name = "Dump All Bytecode (Raw)",
            Callback = function()
                task.spawn(DumpAllBytecode)
            end
        })

        advTab:CreateButton({
            Name = "Scan Registry Closures",
            Callback = function()
                task.spawn(ScanRegistry)
            end
        })

        advTab:CreateButton({
            Name = "Dump ServerScriptService",
            Callback = function()
                task.spawn(DumpServerScripts)
            end
        })

        advTab:CreateButton({
            Name = "Export Full Game (saveinstance)",
            Callback = function()
                if Capabilities.SaveInstance then
                    pcall(function()
                        saveinstance(GameInfo.Name .. "_FullExport.rbxl")
                    end)
                    Rayfield:Notify({ Title = "Export", Content = "Game exported to workspace.", Duration = 5 })
                else
                    Rayfield:Notify({ Title = "Unsupported", Content = "saveinstance not available.", Duration = 3 })
                end
            end
        })

        advTab:CreateButton({
            Name = "Print Executor Capabilities",
            Callback = function()
                print("=== EXECUTOR CAPABILITIES ===")
                for k, v in pairs(Capabilities) do
                    print(string.format("  %s: %s", k, tostring(v)))
                end
                print("=============================")
                Rayfield:Notify({ Title = "Check Console", Content = "Capabilities printed to dev console.", Duration = 3 })
            end
        })

        Rayfield:Notify({
            Title = "Scanner Ready",
            Content = string.format("Loaded: %s | Executor: %s", GameInfo.Name, ExecutorName),
            Duration = 4
        })

        ScanState.StatusText = "Ready. Press 'Start Full Scan' to begin."
        UIExists = true

        print("[Scanner] UI built. v4.0 Advanced.")
        print("[Scanner] Bytecode bypass: " .. (Capabilities.GetScriptBytecode and "ACTIVE" or "LIMITED"))
        print("[Scanner] Server scan: " .. (ScanState.IncludeServer and "ENABLED" or "DISABLED"))
    end)
end

-- ============================================================
-- ADVANCED SCRIPT COLLECTOR
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

    -- 1. Game tree descendants (includes ServerScriptService if accessible)
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            addScript(obj, "GameTree")
        end
    end)

    -- 2. Explicit ServerScriptService scan
    if ScanState.IncludeServer then
        pcall(function()
            local sss = game:GetService("ServerScriptService")
            for _, obj in ipairs(sss:GetDescendants()) do
                addScript(obj, "ServerScriptService")
            end
        end)

        -- 3. ReplicatedStorage scripts (often server-loaded modules)
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
    end

    -- 5. getscripts() — all running scripts including server
    if Capabilities.GetScripts then
        pcall(function()
            for _, s in ipairs(getscripts()) do
                addScript(s, "getscripts()")
            end
        end)
    end

    -- 6. getloadedmodules() — all loaded module scripts
    if Capabilities.GetLoadedModules then
        pcall(function()
            for _, s in ipairs(getloadedmodules()) do
                addScript(s, "getloadedmodules()")
            end
        end)
    end

    -- 7. getnilinstances() — nil-parented scripts (hidden scripts)
    if ScanState.IncludeNil and Capabilities.GetNilInstances then
        pcall(function()
            for _, s in ipairs(getnilinstances()) do
                addScript(s, "getnilinstances()")
            end
        end)
    end

    -- 8. getreg() — scan registry for script closures
    if ScanState.IncludeReg and Capabilities.GetReg then
        pcall(function()
            local reg = getreg()
            for _, v in ipairs(reg) do
                if type(v) == "function" then
                    local info = debug.getinfo(v)
                    if info and info.source and info.source:match("%.lua$") then
                        local scriptName = info.short_src or info.source
                        local fakeObj = {
                            Name = scriptName,
                            ClassName = "Function",
                            Disabled = false,
                            GetFullName = function() return scriptName end,
                            Source = "getreg()",
                        }
                        -- Store closure for deep extraction
                        table.insert(collected, {
                            Object = fakeObj,
                            Closure = v,
                            Name = scriptName,
                            Class = "Closure",
                            Disabled = false,
                            Source = "getreg()"
                        })
                    end
                end
            end
        end)
    end

    return collected
end

-- ============================================================
-- ADVANCED DECOMPILATION — MULTI-METHOD FALLBACK
-- ============================================================
local function DecompileScript(scriptObj, closure)

    -- Method 1: Standard decompile
    if Capabilities.Decompile and scriptObj then
        local result = nil
        pcall(function()
            result = decompile(scriptObj)
        end)
        if result and #result > 10 then
            return result, "decompiled"
        end

        -- Method 2: decompile with true flag (some executors)
        pcall(function()
            result = decompile(scriptObj, true)
        end)
        if result and #result > 10 then
            return result, "decompiled(true)"
        end
    end

    -- Method 3: getscriptclosure → decompile the closure
    if Capabilities.GetScriptClosure and scriptObj then
        local result = nil
        pcall(function()
            local cl = getscriptclosure(scriptObj)
            if cl then
                result = decompile(cl)
            end
        end)
        if result and #result > 10 then
            return result, "getscriptclosure"
        end
    end

    -- Method 4: Direct .Source property (if accessible)
    if scriptObj then
        local result = nil
        pcall(function()
            result = scriptObj.Source
        end)
        if result and #result > 10 then
            return "-- SOURCE EXTRACTED (.Source)\n" .. result, ".Source"
        end
    end

    -- Method 5: Bytecode dump via getscriptbytecode
    if Capabilities.GetScriptBytecode and scriptObj then
        local bytecode = nil
        pcall(function()
            bytecode = getscriptbytecode(scriptObj)
        end)
        if bytecode and #bytecode > 0 then
            -- Convert to hex dump for analysis
            local hexDump = {}
            local len = #bytecode
            local limit = math.min(len, 10000) -- cap at 10k bytes
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
            return "-- BYTECODE DUMP (decompile failed, raw bytecode)\n-- Length: " .. len .. " bytes\n\n" .. dump, "bytecode"
        end
    end

    -- Method 6: If we have a closure, try debug.getupvalues + getconstants
    if closure and ScanState.DeepScan then
        local result = "-- CLOSURE ANALYSIS (decompile failed)\n"
        pcall(function()
            if Capabilities.DebugGetUpvalues then
                local upvals = debug.getupvalues(closure)
                if upvals and #upvals > 0 then
                    result = result .. "\n-- UPVALUES (" .. #upvals .. "):\n"
                    for i, v in ipairs(upvals) do
                        result = result .. string.format("  [%d] %s: %s\n", i, type(v), tostring(v):sub(1, 200))
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
                        result = result .. string.format("  [%d] %s: %s\n", i, type(v), tostring(v):sub(1, 200))
                    end
                end
            end
        end)
        if #result > 50 then
            return result, "closure-analysis"
        end
    end

    return "-- DECOMPILE FAILED (Protected Bytecode)\n-- All methods exhausted.\n", "failed"
end

-- ============================================================
-- FILE MANAGEMENT
-- ============================================================
local MAX_FILE_SIZE = 8 * 1024 * 1024
local currentFileSize = 0
local filePart = 1
local writeBuffer = {}
local bufferSize = 0
local MAX_BUFFER_SIZE = 500 * 1024

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
            "=== ADVANCED SCRIPT SCAN: %s ===\n" ..
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
        "=== ADVANCED SCRIPT SCAN: %s ===\n" ..
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

        local path = GameInfo.Name .. "_BytecodeDump.txt"
        SafeWriteFile(path, "=== BYTECODE DUMP: " .. GameInfo.Name .. " ===\n")
        local count = 0

        for i, s in ipairs(allScripts) do
            pcall(function()
                local bc = getscriptbytecode(s)
                if bc and #bc > 0 then
                    local entry = string.format("\n%s\n%s\nBytecode Length: %d\n", string.rep("=", 60), s:GetFullName(), #bc)
                    SafeAppendFile(path, entry)
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
                local info = debug.getinfo(v)
                if info and info.source and #info.source > 0 then
                    local entry = string.format(
                        "Function: %s\n  Source: %s\n  Line: %s-%s\n  What: %s\n",
                        tostring(v), info.short_src or info.source,
                        tostring(info.linedefined), tostring(info.lastlinedefined),
                        info.what or "unknown"
                    )

                    -- Deep scan: extract upvalues
                    pcall(function()
                        if Capabilities.DebugGetUpvalues then
                            local upvals = debug.getupvalues(v)
                            if upvals and #upvals > 0 then
                                entry = entry .. "  Upvalues:\n"
                                for i, uv in ipairs(upvals) do
                                    entry = entry .. string.format("    [%d] %s: %s\n", i, type(uv), tostring(uv):sub(1, 300))
                                end
                            end
                        end
                    end)

                    -- Deep scan: extract constants
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
                end
            end
        end

        SafeAppendFile(path, table.concat(entries, "\n"))
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

        local services = { "ServerScriptService", "ServerStorage", "ReplicatedStorage" }
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
                        local status = method == "failed" and "PROTECTED" or "DECOMPILED (" .. method .. ")"

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
        ScanState.StartTime = tick()
        ScanState.StatusText = "Initializing..."
        ScanState.TimeText = "--:--"

        task.wait(0.5)

        -- Elevate identity again before scanning
        pcall(function()
            if setidentity then setidentity(7) end
            if getthreadcontext then getthreadcontext(7) end
        end)

        ScanState.StatusText = "Collecting scripts (advanced)..."
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

                local statusIcon = (method == "failed") and "PROTECTED" or ("DECOMPILED (" .. method .. ")")

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
        pcall(function()
            appendfile(ScanState.CurrentFile, "\n" .. string.rep("=", 60) .. "\n")
            appendfile(ScanState.CurrentFile, "SCAN COMPLETE\n")
            appendfile(ScanState.CurrentFile, string.format("Total: %d | Decompiled: %d | Protected: %d | Bytecode: %d\n",
                ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped))
            appendfile(ScanState.CurrentFile, string.rep("=", 60) .. "\n")
        end)

        ScanState.IsScanning = false
        ScanState.StatusText = "COMPLETE!"
        ScanState.TimeText = "Time Remaining: 00:00"
        ScanState.SuccessText = string.format("Decompiled: %d | Protected: %d | Bytecode: %d",
            ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped)

        if Rayfield then
            Rayfield:Notify({
                Title = "Scan Complete!",
                Content = string.format("%d/%d extracted | %d bytecode dumps | %d protected",
                    ScanState.Decompiled, ScanState.TotalScripts, ScanState.BytecodeDumped, ScanState.Failed),
                Duration = 6
            })
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

print("========================================")
print("  ADVANCED SCRIPT SCANNER v4.0")
print("  Bytecode Bypass: " .. (Capabilities.GetScriptBytecode and "ACTIVE" or "LIMITED"))
print("  Server Scan: " .. (ScanState.IncludeServer and "ENABLED" or "DISABLED"))
print("  Registry Scan: " .. (ScanState.IncludeReg and "ENABLED" or "DISABLED"))
print("  Nil Instances: " .. (ScanState.IncludeNil and "ENABLED" or "DISABLED"))
print("  Deep Scan: " .. (ScanState.DeepScan and "ENABLED" or "DISABLED"))
print("  Executor: " .. ExecutorName)
print("========================================")

task.delay(2, function()
    pcall(function() getgenv().ScannerRunning = false end)
end)
