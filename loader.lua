--!nocheck
-- ============================================================
-- APEX SCRIPT SCANNER v5.3 — FLUENT UI (STACK FIX)
-- ============================================================

if getgenv().ScannerRunning then return end
getgenv().ScannerRunning = true

-- ============================================================
-- SAFE BYPASS — no metamethod hooks (causes C stack overflow)
-- ============================================================
local BypassState = { HooksInstalled = false }
local ScannerInstances = {}

local function HideInstance(inst)
    if typeof(inst) == "Instance" then ScannerInstances[inst] = true end
end

local function InstallBypass()
    -- Only hook debug functions and error — these are safe and don't recurse
    pcall(function()
        if hookfunction and not BypassState.HooksInstalled then
            -- Hook debug.getinfo
            local oldGetInfo = debug.getinfo
            local gettingInfo = false
            local function FilteredGetInfo(...)
                if gettingInfo then return oldGetInfo(...) end
                gettingInfo = true
                local info = oldGetInfo(...)
                gettingInfo = false
                if info and type(info) == "table" then
                    if info.source and (info.source:match("Scanner") or info.source:match("[Bb]ypass")) then
                        info.source = "Workspace.GameScript"
                    end
                    if info.short_src and (info.short_src:match("Scanner") or info.short_src:match("[Bb]ypass")) then
                        info.short_src = "GameScript"
                    end
                end
                return info
            end
            if newcclosure then
                hookfunction(debug.getinfo, newcclosure(FilteredGetInfo))
            else
                hookfunction(debug.getinfo, FilteredGetInfo)
            end

            -- Hook debug.traceback
            local oldTraceback = debug.traceback
            local tracingBack = false
            local function FilteredTraceback(msg, level)
                if tracingBack then return oldTraceback(msg, level) end
                tracingBack = true
                local tb = oldTraceback(msg, level)
                tracingBack = false
                if type(tb) == "string" then
                    tb = tb:gsub("[Ss]canner", "GameScript")
                    tb = tb:gsub("[Bb]ypass", "CoreScript")
                end
                return tb
            end
            if newcclosure then
                hookfunction(debug.traceback, newcclosure(FilteredTraceback))
            else
                hookfunction(debug.traceback, FilteredTraceback)
            end

            -- Hook error
            local oldError = error
            local function FilteredError(msg, level)
                if type(msg) == "string" and (msg:match("[Ss]canner") or msg:match("[Bb]ypass")) then
                    return oldError("Unexpected behavior", level)
                end
                return oldError(msg, level)
            end
            if newcclosure then
                hookfunction(error, newcclosure(FilteredError))
            else
                hookfunction(error, FilteredError)
            end

            BypassState.HooksInstalled = true
        end
    end)

    -- Identity elevation — safe, no recursion possible
    pcall(function()
        if setidentity then setidentity(7) end
        if getthreadcontext then getthreadcontext(7) end
        if setthreadcontext then setthreadcontext(7) end
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
-- FLUENT LOADER
-- ============================================================
local Fluent = nil

local function LoadFluent()
    local urls = {
        "https://github.com/dvrzz/Fluent/releases/latest/download/Fluent.txt",
        "https://raw.githubusercontent.com/dvrzz/Fluent/main/Fluent.txt",
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
                pcall(function() fn() end)
                if _G.Fluent then Fluent = _G.Fluent; return end
                if fluent then Fluent = fluent; return end
            end
        end
    end

    -- Fallback: Orion
    if not Fluent then
        local ok, src = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Jun0deps/Orion/main/source") end)
        if ok and src and #src > 500 then
            local fn = loadstring(src)
            if fn then
                pcall(function() fn() end)
                if OrionLib then
                    Fluent = setmetatable({ _Orion = true }, {
                        __index = function(t, k)
                            if k == "CreateWindow" then
                                return function(config)
                                    local win = OrionLib:MakeWindow(config)
                                    return setmetatable({}, {
                                        __index = function(_, key)
                                            if key == "CreateTab" then
                                                return function(tc)
                                                    local tab = win:MakeTab(tc)
                                                    return setmetatable({}, {
                                                        __index = function(_, tk)
                                                            if tk == "CreateLabel" then return function(text) return { Set = function() end }, tab:AddLabel(text) end end
                                                            if tk == "CreateParagraph" then return function(p) tab:AddParagraph(p.Title, p.Content) end end
                                                            if tk == "CreateButton" then return function(b) tab:AddButton(b) end end
                                                            if tk == "CreateToggle" then return function(tg) local t = tab:AddToggle(tg); return { Set = function(v) t:Set(v) end } end end
                                                            if tk == "CreateDivider" then return function() end end
                                                            if tk == "CreateSection" then return function(name) tab:AddSection(name) end end
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
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Scanner",
                Text = "Fluent + Orion failed. Using stub UI.",
                Duration = 5
            })
        end)
        Fluent = {
            CreateWindow = function()
                return {
                    CreateTab = function()
                        local s = {
                            CreateLabel = function() return { Set = function() end } end,
                            CreateParagraph = function() end,
                            CreateButton = function() return { Callback = function() end } end,
                            CreateToggle = function() return { Set = function() end } end,
                            CreateDivider = function() end,
                            CreateSection = function() end,
                            CreateDropdown = function() return { Set = function() end } end,
                        }
                        return s
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
-- SAFE WRITE
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
local UIExists = false
local StatusRef = { Set = function() end }
local TimeRef = { Set = function() end }
local FileRef = { Set = function() end }
local CountRef = { Set = function() end }
local SuccessRef = { Set = function() end }
local RemoteCountRef = { Set = function() end }
local RemoteConnRef = { Set = function() end }

-- ============================================================
-- BUILD UI
-- ============================================================
function BuildUI()
    pcall(function()
        if UIWindow and UIWindow.Destroy then
            pcall(function() UIWindow:Destroy() end)
        end
    end)

    pcall(function()
        local Window = Fluent:CreateWindow({
            Title = "Apex Scanner v5.3",
            SubTitle = GameInfo.Name .. " | " .. ExecutorName,
            TabWidth = 160,
            Size = UDim2.fromOffset(580, 460),
            Acrylic = true,
            Theme = "Dark",
            MinSize = Vector2.new(470, 380),
        })
        UIWindow = Window

        -- Hide UI
        pcall(function()
            local parent = Capabilities.Gethui and gethui() or game:GetService("CoreGui")
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("ScreenGui") and (child.Name:match("Fluent") or child.Name:match("Window")) then
                    child.ResetOnSpawn = false
                    child.DisplayOrder = 9999
                    child.IgnoreGuiInset = true
                    HideInstance(child)
                end
            end
        end)

        -- ── MAIN TAB ──
        local MainTab = Window:CreateTab("Scanner", "scan")

        MainTab:CreateSection("Game Info")
        MainTab:CreateParagraph({
            Title = GameInfo.Name,
            Content = string.format("Place ID: %d\nCreator: %s\nExecutor: %s\nJobID: %s",
                GameInfo.PlaceId, GameInfo.Creator, ExecutorName, GameInfo.JobId)
        })

        MainTab:CreateSection("Scan Options")

        MainTab:CreateToggle({
            Title = "Bytecode Dump",
            Description = "Raw hex dump when decompile fails",
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
            Description = "SSS, SS, RS, StarterPlayer, StarterGui, StarterPack",
            Default = true,
            Callback = function(v) ScanState.IncludeServer = v end
        })

        MainTab:CreateToggle({
            Title = "Deep Scan",
            Description = "Walk upvalue chains, extract constants",
            Default = true,
            Callback = function(v) ScanState.DeepScan = v end
        })

        MainTab:CreateToggle({
            Title = "Remote Spy",
            Description = "Track all RemoteEvents and RemoteFunctions",
            Default = true,
            Callback = function(v) ScanState.IncludeRemotes = v end
        })

        MainTab:CreateSection("Status")

        StatusRef = MainTab:CreateLabel("Status: Ready")
        TimeRef = MainTab:CreateLabel("Time: --:--")
        FileRef = MainTab:CreateLabel("Save: Not started")
        CountRef = MainTab:CreateLabel("Total Scripts: 0")
        SuccessRef = MainTab:CreateLabel("Decompiled: 0 | Protected: 0 | Bytecode: 0")

        MainTab:CreateSection("Controls")

        MainTab:CreateButton({
            Title = "Start Full Scan",
            Description = "Begin exhaustive script collection and decompilation",
            Callback = RunScanner
        })

        MainTab:CreateButton({
            Title = "Toggle Pause",
            Description = "Pause / resume current scan",
            Callback = function()
                if not ScanState.IsScanning then return end
                ScanState.IsPaused = not ScanState.IsPaused
                ScanState.StatusText = ScanState.IsPaused and "PAUSED" or "Resuming..."
            end
        })

        MainTab:CreateButton({
            Title = "Stop Scan",
            Description = "Abort current scan",
            Callback = function()
                ScanState.IsScanning = false
                ScanState.IsPaused = false
                ScanState.StatusText = "STOPPED"
                getgenv().ScannerRunning = false
            end
        })

        MainTab:CreateButton({
            Title = "Rebuild UI",
            Description = "Destroy and recreate the interface",
            Callback = function()
                UIExists = false
                BuildUI()
            end
        })

        -- ── ADVANCED TAB ──
        local AdvTab = Window:CreateTab("Advanced", "wrench")

        AdvTab:CreateParagraph({
            Title = "Advanced Extraction Tools",
            Content = "Deep extraction methods for protected scripts"
        })

        AdvTab:CreateSection("Extraction")

        AdvTab:CreateButton({
            Title = "Dump All Bytecode (Raw Hex)",
            Description = "Extract raw bytecode from every script",
            Callback = function() task.spawn(DumpAllBytecode) end
        })

        AdvTab:CreateButton({
            Title = "Scan Registry Closures",
            Description = "Deep scan getreg() for Lua closures",
            Callback = function() task.spawn(ScanRegistry) end
        })

        AdvTab:CreateButton({
            Title = "Dump Server Scripts",
            Description = "SSS, SS, RS, StarterPlayer, StarterGui, StarterPack",
            Callback = function() task.spawn(DumpServerScripts) end
        })

        AdvTab:CreateButton({
            Title = "Dump Nil Instances",
            Description = "Extract nil-parented hidden scripts",
            Callback = function() task.spawn(DumpNilInstances) end
        })

        AdvTab:CreateButton({
            Title = "Dump All Connections",
            Description = "Map all signal connections with source info",
            Callback = function() task.spawn(DumpConnections) end
        })

        AdvTab:CreateSection("Export")

        AdvTab:CreateButton({
            Title = "Export Full Game (saveinstance)",
            Description = "Save entire game as .rbxl",
            Callback = function()
                if Capabilities.SaveInstance then
                    pcall(function() saveinstance({ filename = GameInfo.Name .. "_FullExport.rbxl" }) end)
                    Fluent:Notify({ Title = "Export", Content = "Game exported.", Duration = 5 })
                else
                    Fluent:Notify({ Title = "Unsupported", Content = "saveinstance not available.", Duration = 3 })
                end
            end
        })

        AdvTab:CreateButton({
            Title = "Copy Save Path",
            Description = "Copy current output file path to clipboard",
            Callback = function()
                if Capabilities.SetClipboard and ScanState.CurrentFile ~= "" then
                    pcall(function() setclipboard(ScanState.CurrentFile) end)
                    Fluent:Notify({ Title = "Copied", Content = "Path copied.", Duration = 2 })
                end
            end
        })

        AdvTab:CreateSection("System")

        AdvTab:CreateButton({
            Title = "Print Executor Capabilities",
            Description = "Dump all executor functions to console",
            Callback = function()
                print("=== EXECUTOR CAPABILITIES ===")
                for k, v in pairs(Capabilities) do
                    print(string.format("  %s: %s", k, tostring(v)))
                end
                print(string.format("  Executor: %s", ExecutorName))
                print(string.format("  Bypass: %s", BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
                print("=============================")
                Fluent:Notify({ Title = "Console", Content = "Check dev console.", Duration = 3 })
            end
        })

        -- ── REMOTE SPY TAB ──
        local RemoteTab = Window:CreateTab("Remote Spy", "radio")

        RemoteTab:CreateParagraph({
            Title = "Remote Event Monitor",
            Content = "Tracks all RemoteEvents and RemoteFunctions"
        })

        RemoteCountRef = RemoteTab:CreateLabel("Remotes Found: 0")
        RemoteConnRef = RemoteTab:CreateLabel("Connections: 0")

        RemoteTab:CreateSection("Controls")

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
            Description = "Save all discovered remotes to file",
            Callback = function()
                local path = GameInfo.Name .. "_RemoteSpy.txt"
                local content = "=== REMOTE SPY DUMP ===\n\n"
                for name, data in pairs(RemotesLog) do
                    content = content .. string.format("Name: %s\nType: %s\n---\n", data.Name, data.Type)
                end
                SafeWriteFile(path, content)
                Fluent:Notify({ Title = "Exported", Content = "Saved to " .. path, Duration = 3 })
            end
        })

        RemoteTab:CreateButton({
            Title = "Fire All Remotes (Test)",
            Description = "Fire every RemoteEvent with no args",
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

        UIExists = true

        Fluent:Notify({
            Title = "Scanner Ready",
            Content = string.format("%s | %s", GameInfo.Name, ExecutorName),
            Duration = 5
        })

        print("========================================")
        print("  APEX SCRIPT SCANNER v5.3 — STACK FIX")
        print("  Executor: " .. ExecutorName)
        print("  Bypass: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
        print("========================================")
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
        local services = { "ServerScriptService", "ReplicatedStorage", "ServerStorage", "StarterGui", "StarterPack" }
        for _, svcName in ipairs(services) do
            pcall(function()
                local svc = game:GetService(svcName)
                for _, obj in ipairs(svc:GetDescendants()) do addScript(obj, svcName) end
            end)
        end
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
                            table.insert(collected, {
                                Object = nil,
                                Closure = v,
                                Name = info.short_src or info.source,
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
            return "-- BYTECODE DUMP\n-- Length: " .. len .. " bytes\n\n" ..
                   table.concat(hexDump, "\n") .. stringSection, "bytecode"
        end
    end

    if closure and ScanState.DeepScan then
        local result = "-- CLOSURE ANALYSIS\n\n"

        pcall(function()
            if Capabilities.DebugGetUpvalues then
                local upvals = debug.getupvalues(closure)
                if upvals and #upvals > 0 then
                    result = result .. "-- UPVALUES (" .. #upvals .. "):\n"
                    for i, v in ipairs(upvals) do
                        result = result .. string.format("  [%d] %s: %s\n", i, type(v), tostring(v):sub(1, 500))
                        if typeof(v) == "Instance" then
                            pcall(function() result = result .. string.format("      -> %s (%s)\n", v:GetFullName(), v.ClassName) end)
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
                result = result .. "  lines: " .. tostring(info.linedefined) .. "-" .. tostring(info.lastlinedefined) .. "\n"
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
    SafeWriteFile(ScanState.CurrentFile, string.format(
        "=== APEX SCRIPT SCAN: %s ===\nGame ID: %d | JobID: %s\nExecutor: %s\nDate: %s\n\n",
        GameInfo.Name, GameInfo.PlaceId, GameInfo.JobId, ExecutorName, os.date("%Y-%m-%d %H:%M:%S")))
    currentFileSize = 0
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
            pcall(function() for _, s in ipairs(getscripts()) do table.insert(allScripts, s) end end)
        end
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
        Fluent:Notify({ Title = "Bytecode", Content = count .. " scripts dumped.", Duration = 5 })
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
        SafeWriteFile(path, "=== REGISTRY DUMP ===\n\n")
        local count = 0
        local reg = getreg()
        local entries = {}
        for _, v in ipairs(reg) do
            if type(v) == "function" then
                local info = debug.getinfo(v)
                if info and info.source and #info.source > 0 then
                    local entry = string.format("Function: %s\n  Source: %s\n  Lines: %s-%s\n",
                        tostring(v), info.short_src or info.source,
                        tostring(info.linedefined), tostring(info.lastlinedefined))
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
        Fluent:Notify({ Title = "Registry", Content = count .. " closures found.", Duration = 5 })
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
                        SafeAppendFile(path, string.format("\n%s\nSCRIPT: %s\nCLASS: %s\nSERVICE: %s\nSTATUS: %s\n%s\n%s\n\n",
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
        SafeWriteFile(path, "=== NIL INSTANCE DUMP ===\n\n")
        local count = 0
        for _, obj in ipairs(getnilinstances()) do
            pcall(function()
                if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local decompiled, method = DecompileScript(obj)
                    SafeAppendFile(path, string.format("\nNIL: %s\nCLASS: %s\nSTATUS: %s\n%s\n\n",
                        obj.Name, obj.ClassName,
                        method == "failed" and "PROTECTED" or "EXTRACTED (" .. method .. ")",
                        decompiled))
                    count = count + 1
                end
            end)
            task.wait()
        end
        ScanState.StatusText = "Nil done: " .. count
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
        Fluent:Notify({ Title = "Connections", Content = count .. " signals mapped.", Duration = 5 })
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

                local entry = string.format("\n%s\nSCRIPT: %s%s\nCLASS: %s\nSOURCE: %s\nSTATUS: %s\n%s\n%s\n\n",
                    string.rep("=", 60), data.Name, data.Disabled and " [DISABLED]" or "",
                    data.Class, data.Source,
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
            "\n=== SCAN COMPLETE ===\nTotal: %d | Extracted: %d | Protected: %d | Bytecode: %d\n",
            ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped))

        ScanState.IsScanning = false
        ScanState.StatusText = "COMPLETE!"
        ScanState.TimeText = "00:00"

        Fluent:Notify({
            Title = "Scan Complete!",
            Content = string.format("%d/%d extracted | %d bytecode | %d protected",
                ScanState.Decompiled, ScanState.TotalScripts, ScanState.BytecodeDumped, ScanState.Failed),
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
