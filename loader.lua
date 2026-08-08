--!nocheck
-- ============================================================
-- APEX SCRIPT SCANNER v6.0 — RAYFIELD UI
-- Universal Decompiler | Anti-Cheat Bypass | Full Extraction
-- ============================================================

if getgenv().ScannerRunning then return end
getgenv().ScannerRunning = true

-- ============================================================
-- ANTI-CHEAT BYPASS SYSTEM
-- ============================================================
local BypassState = { HooksInstalled = false, HiddenInstances = {} }
local ScannerInstances = setmetatable({}, { __mode = "k" })

local function HideInstance(inst)
    if typeof(inst) == "Instance" then
        ScannerInstances[inst] = true
        BypassState.HiddenInstances[inst] = true
    end
end

local function SanitizeString(str)
    if type(str) ~= "string" then return str end
    return str
        :gsub("[Ss]canner", "GameCore")
        :gsub("[Bb]ypass", "Security")
        :gsub("APEX", "Core")
        :gsub("loader", "init")
        :gsub("Rayfield", "Interface")
end

local function InstallBypass()
    -- Identity elevation
    pcall(function()
        if setidentity then setidentity(7) end
        if getthreadcontext then getthreadcontext(7) end
        if setthreadcontext then setthreadcontext(7) end
        if syn and syn.set_thread_identity then syn.set_thread_identity(7) end
    end)

    -- Hook debug functions to hide scanner traces
    pcall(function()
        if hookfunction and not BypassState.HooksInstalled then

            -- debug.getinfo
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

            -- debug.traceback
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

            -- error
            local oldError = error
            local function HookedError(msg, level)
                if type(msg) == "string" then msg = SanitizeString(msg) end
                return oldError(msg, level)
            end
            if newcclosure then
                hookfunction(error, newcclosure(HookedError))
            else
                hookfunction(error, HookedError)
            end

            -- print/warn filtering
            local oldPrint = print
            local function HookedPrint(...)
                local args = { ... }
                for i, v in ipairs(args) do
                    if type(v) == "string" then args[i] = SanitizeString(v) end
                end
                return oldPrint(table.unpack(args))
            end
            if newcclosure then
                hookfunction(print, newcclosure(HookedPrint))
            else
                hookfunction(print, HookedPrint)
            end

            BypassState.HooksInstalled = true
        end
    end)

    -- Metamethod hooks for anti-cheat detection evasion
    pcall(function()
        if hookmetamethod and getrawmetatable and setreadonly then
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)

            local inNamecall = false
            local function HookedNamecall(self, ...)
                if inNamecall then return oldNamecall(self, ...) end
                inNamecall = true
                local method = getnamecallmethod and getnamecallmethod() or ""
                inNamecall = false

                -- Block anti-cheat remote calls
                if method == "FireServer" or method == "InvokeServer" then
                    local name = self.Name or ""
                    if name:match("[Aa]nti[Cc]heat") or name:match("[Aa][Cc]") or
                       name:match("[Dd]etect") or name:match("[Kk]ick") or
                       name:match("[Bb]an") or name:match("[Ss]ecurity") then
                        return
                    end
                end

                -- Filter GetService calls that might detect scanner
                if method == "GetService" then
                    local arg = select(1, ...)
                    if type(arg) == "string" and (arg:match("[Ss]canner") or arg:match("[Bb]ypass")) then
                        return oldNamecall(self, "Workspace")
                    end
                end

                return oldNamecall(self, ...)
            end

            if newcclosure then
                hookmetamethod(game, "__namecall", newcclosure(HookedNamecall))
            else
                hookmetamethod(game, "__namecall", HookedNamecall)
            end

            setreadonly(mt, true)
        end
    end)

    -- Destroy anti-cheat scripts if found
    pcall(function()
        local descenders = {
            game:GetService("ReplicatedFirst"),
            game:GetService("ReplicatedStorage"),
            game:GetService("ServerScriptService"),
        }
        for _, parent in ipairs(descenders) do
            for _, child in ipairs(parent:GetDescendants()) do
                if child:IsA("LocalScript") or child:IsA("Script") then
                    local name = child.Name:lower()
                    if name:match("anti") or name:match("cheat") or name:match("detect") or
                       name:match("security") or name:match("kick") or name:match("ban") then
                        pcall(function() child.Disabled = true end)
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end)
end

InstallBypass()

-- ============================================================
-- CAPABILITIES DETECTION
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
    GetScriptHash = type(getscripthash) == "function",
    SaveInstance = type(saveinstance) == "function",
    Loadstring = type(loadstring) == "function",
    HookFunction = type(hookfunction) == "function",
    HookMeta = type(hookmetamethod) == "function",
    GetRawMetatable = type(getrawmetatable) == "function",
    SetReadOnly = type(setreadonly) == "function",
    DebugGetUpvalues = type(debug.getupvalues) == "function",
    DebugGetConstants = type(debug.getconstants) == "function",
    DebugSetUpvalue = type(debug.setupvalue) == "function",
    CloneFunction = type(clonefunction) == "function",
    GetInstances = type(getinstances) == "function",
    GetConnections = type(getconnections) == "function",
    SetClipboard = type(setclipboard) == "function",
    Gethui = type(gethui) == "function",
    Newcclosure = type(newcclosure) == "function",
    IsLuaLclosure = type(islclosure) == "function",
    GetLoadedModules2 = type(getloadedmodules) == "function",
    Firesignal = type(firesignal) == "function",
    GetCallStack = type(getcallstack) == "function",
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
        ClassName = "Game",
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
-- RAYFIELD UI LOADER
-- ============================================================
local Rayfield = nil

local function LoadRayfield()
    local urls = {
        "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
        "https://raw.githubusercontent.com/shlexware/Rayfield/source",
        "https://github.com/shlexware/Rayfield/raw/main/source",
    }
    for _, url in ipairs(urls) do
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and src and #src > 500 then
            local fn = loadstring(src)
            if fn then
                local ok2, result = pcall(fn)
                if ok2 and (Rayfield or _G.Rayfield) then
                    Rayfield = Rayfield or _G.Rayfield
                    return
                end
                pcall(function() fn() end)
                if Rayfield then return end
                if _G.Rayfield then Rayfield = _G.Rayfield; return end
            end
        end
    end

    -- Fallback: Orion Lib
    if not Rayfield then
        local ok, src = pcall(function()
            return game:HttpGet("https://raw.githubusercontent.com/Jun0deps/Orion/main/source")
        end)
        if ok and src and #src > 500 then
            local fn = loadstring(src)
            if fn then
                pcall(function() fn() end)
                if OrionLib then
                    Rayfield = setmetatable({ _Orion = true }, {
                        __index = function(t, k)
                            if k == "CreateWindow" then
                                return function(config)
                                    local win = OrionLib:MakeWindow({
                                        Name = config.Name or "Apex Scanner",
                                        HidePremium = true,
                                        SaveConfig = false,
                                        IntroText = "Apex Scanner",
                                    })
                                    return setmetatable({}, {
                                        __index = function(_, key)
                                            if key == "CreateTab" then
                                                return function(tc)
                                                    local tab = win:MakeTab({
                                                        Name = tc.Title or "Tab",
                                                        Icon = tc.Icon,
                                                    })
                                                    return setmetatable({}, {
                                                        __index = function(_, tk)
                                                            if tk == "CreateLabel" then
                                                                return function(text)
                                                                    return { Set = function(_, v) end }, tab:AddLabel(type(text) == "table" and text.Title or tostring(text))
                                                                end
                                                            end
                                                            if tk == "CreateParagraph" then
                                                                return function(p) tab:AddParagraph(p.Title or "", p.Content or "") end
                                                            end
                                                            if tk == "CreateButton" then
                                                                return function(b)
                                                                    tab:AddButton({
                                                                        Name = b.Title or "Button",
                                                                        Callback = b.Callback or function() end,
                                                                    })
                                                                end
                                                            end
                                                            if tk == "CreateToggle" then
                                                                return function(tg)
                                                                    local t = tab:AddToggle({
                                                                        Name = tg.Title or "Toggle",
                                                                        Default = tg.Default or false,
                                                                        Callback = tg.Callback or function() end,
                                                                    })
                                                                    return { Set = function(_, v) t:Set(v) end }
                                                                end
                                                            end
                                                            if tk == "CreateSlider" then
                                                                return function(sl)
                                                                    local s = tab:AddSlider({
                                                                        Name = sl.Title or "Slider",
                                                                        Min = sl.Range and sl.Range[1] or 1,
                                                                        Max = sl.Range and sl.Range[2] or 100,
                                                                        Default = sl.Default or 1,
                                                                        Callback = sl.Callback or function() end,
                                                                    })
                                                                    return { Set = function(_, v) s:Set(v) end }
                                                                end
                                                            end
                                                            if tk == "CreateDropdown" then
                                                                return function(dd)
                                                                    local d = tab:AddDropdown({
                                                                        Name = dd.Title or "Dropdown",
                                                                        Options = dd.Options or {},
                                                                        Default = dd.Default or "",
                                                                        Callback = dd.Callback or function() end,
                                                                    })
                                                                    return { Set = function(_, v) d:Refresh(v) end }
                                                                end
                                                            end
                                                            if tk == "CreateInput" then
                                                                return function(inp)
                                                                    tab:AddTextbox({
                                                                        Name = inp.Title or "Input",
                                                                        Default = inp.Default or "",
                                                                        Callback = inp.Callback or function() end,
                                                                    })
                                                                    return { Set = function() end }
                                                                end
                                                            end
                                                            if tk == "CreateDivider" then return function() end end
                                                            if tk == "CreateSection" then
                                                                return function(name) tab:AddSection(name) end
                                                            end
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
                                    OrionLib:MakeNotification({
                                        Title = n.Title or "",
                                        Content = n.Content or "",
                                        Duration = n.Duration or 3,
                                    })
                                end
                            end
                        end
                    })
                    return
                end
            end
        end
    end

    -- Final stub
    if not Rayfield then
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Scanner",
                Text = "Rayfield + Orion failed. Using stub.",
                Duration = 5,
            })
        end)
        Rayfield = {
            CreateWindow = function()
                return {
                    CreateTab = function()
                        return {
                            CreateLabel = function() return { Set = function() end } end,
                            CreateParagraph = function() end,
                            CreateButton = function() return { Callback = function() end } end,
                            CreateToggle = function() return { Set = function() end } end,
                            CreateSlider = function() return { Set = function() end } end,
                            CreateDropdown = function() return { Set = function() end } end,
                            CreateInput = function() return { Set = function() end } end,
                            CreateDivider = function() end,
                            CreateSection = function() end,
                        }
                    end,
                    Destroy = function() end,
                }
            end,
            Notify = function() end,
        }
    end
end

LoadRayfield()

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
    IncludeUpvalueChain = true,
    IncludeCoreScripts = false,
    SplitByService = true,
    MaxConcurrency = 1,
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
    ScriptLog = {},
}

-- ============================================================
-- SAFE FILE OPS
-- ============================================================
local function SafeWriteFile(path, content)
    pcall(function() writefile(path, content) end)
end

local function SafeAppendFile(path, content)
    pcall(function() appendfile(path, content) end)
end

local function SafeMakeFolder(path)
    pcall(function() makefolder(path) end)
end

-- Create organized output folder
ScanState.OutputFolder = GameInfo.Name .. "_APEX_Scan"
SafeMakeFolder(ScanState.OutputFolder)

-- ============================================================
-- REMOTE SPY
-- ============================================================
local RemotesLog = {}
local RemoteSpyActive = false
local RemoteCallLog = {}

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
                            RemotesLog[fn] = {
                                Name = fn,
                                Type = obj.ClassName,
                                Hits = 0,
                                Args = {},
                            }
                            ScanState.RemotesFound = ScanState.RemotesFound + 1
                        end
                    end
                end
            end)
            task.wait(3)
        end
    end)

    -- Hook remotes for call logging
    pcall(function()
        if Capabilities.HookMeta then
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)

            local inNamecall = false
            local function HookedNamecall(self, ...)
                if inNamecall then return oldNamecall(self, ...) end
                inNamecall = true
                local method = getnamecallmethod and getnamecallmethod() or ""
                inNamecall = false

                if (method == "FireServer" or method == "InvokeServer") and
                   (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
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

            if newcclosure then
                hookmetamethod(game, "__namecall", newcclosure(HookedNamecall))
            else
                hookmetamethod(game, "__namecall", HookedNamecall)
            end
            setreadonly(mt, true)
        end
    end)
end

-- ============================================================
-- UI REFERENCES
-- ============================================================
local UIWindow = nil
local StatusRef = { Set = function() end }
local TimeRef = { Set = function() end }
local FileRef = { Set = function() end }
local CountRef = { Set = function() end }
local SuccessRef = { Set = function() end }
local RemoteCountRef = { Set = function() end }
local RemoteConnRef = { Set = function() end }

-- ============================================================
-- BUILD RAYFIELD UI
-- ============================================================
function BuildUI()
    pcall(function()
        if UIWindow and UIWindow.Destroy then
            pcall(function() UIWindow:Destroy() end)
        end
    end)

    pcall(function()
        local Window = Rayfield:CreateWindow({
            Name = "Apex Scanner v6.0 | " .. GameInfo.Name,
            LoadingTitle = "Apex Scanner",
            LoadingSubtitle = "Initializing extraction suite...",
            Theme = "Default",
            ConfigurationSaving = { Enabled = false },
            Keybind = Enum.KeyCode.RightControl,
        })
        UIWindow = Window

        -- Hide from anti-cheat
        pcall(function()
            local parent = Capabilities.Gethui and gethui() or game:GetService("CoreGui")
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("ScreenGui") then
                    child.ResetOnSpawn = false
                    child.DisplayOrder = 9999
                    child.IgnoreGuiInset = true
                    HideInstance(child)
                end
            end
        end)

        -- ── MAIN TAB ──
        local MainTab = Window:CreateTab("Scanner", "scan")

        MainTab:CreateSection("Game Information")
        MainTab:CreateParagraph({
            Title = GameInfo.Name,
            Content = string.format(
                "Place ID: %d\nCreator: %s\nExecutor: %s\nJobID: %s\nBypass: %s",
                GameInfo.PlaceId, GameInfo.Creator, ExecutorName, GameInfo.JobId,
                BypassState.HooksInstalled and "ACTIVE" or "LIMITED"
            )
        })

        MainTab:CreateSection("Scan Options")

        MainTab:CreateToggle({
            Title = "Bytecode Dump",
            Description = "Raw hex extraction when decompile fails",
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
            Description = "Walk upvalue chains, extract constants, closure analysis",
            Default = true,
            Callback = function(v) ScanState.DeepScan = v end
        })

        MainTab:CreateToggle({
            Title = "Remote Spy",
            Description = "Track all RemoteEvents and RemoteFunctions with call logging",
            Default = true,
            Callback = function(v) ScanState.IncludeRemotes = v end
        })

        MainTab:CreateToggle({
            Title = "Connection Mapper",
            Description = "Map all signal connections with source info",
            Default = true,
            Callback = function(v) ScanState.IncludeConnections = v end
        })

        MainTab:CreateToggle({
            Title = "Split Output By Service",
            Description = "Organize decompiled scripts into separate folders by service",
            Default = true,
            Callback = function(v) ScanState.SplitByService = v end
        })

        MainTab:CreateToggle({
            Title = "Include CoreScripts",
            Description = "Attempt extraction of Roblox CoreScripts (experimental)",
            Default = false,
            Callback = function(v) ScanState.IncludeCoreScripts = v end
        })

        MainTab:CreateSection("Status Dashboard")

        StatusRef = MainTab:CreateLabel("Status: Ready")
        TimeRef = MainTab:CreateLabel("Time: --:--")
        FileRef = MainTab:CreateLabel("Save: Not started")
        CountRef = MainTab:CreateLabel("Total Scripts: 0")
        SuccessRef = MainTab:CreateLabel("Decompiled: 0 | Protected: 0 | Bytecode: 0")

        MainTab:CreateSection("Controls")

        MainTab:CreateButton({
            Title = "Start Full Scan",
            Description = "Begin exhaustive universal script collection and decompilation",
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
            Description = "Abort current scan immediately",
            Callback = function()
                ScanState.IsScanning = false
                ScanState.IsPaused = false
                ScanState.StatusText = "STOPPED"
                getgenv().ScannerRunning = false
                Rayfield:Notify({ Title = "Scanner", Content = "Scan stopped.", Duration = 3 })
            end
        })

        MainTab:CreateButton({
            Title = "Destroy UI",
            Description = "Close the scanner interface",
            Callback = function()
                ScanState.IsScanning = false
                getgenv().ScannerRunning = false
                if UIWindow and UIWindow.Destroy then
                    pcall(function() UIWindow:Destroy() end)
                end
            end
        })

        -- ── ADVANCED TAB ──
        local AdvTab = Window:CreateTab("Advanced", "wrench")

        AdvTab:CreateParagraph({
            Title = "Advanced Extraction Tools",
            Content = "Deep extraction methods for protected and obfuscated scripts"
        })

        AdvTab:CreateSection("Extraction")

        AdvTab:CreateButton({
            Title = "Dump All Bytecode (Raw Hex)",
            Description = "Extract raw bytecode from every script with string constant extraction",
            Callback = function() task.spawn(DumpAllBytecode) end
        })

        AdvTab:CreateButton({
            Title = "Scan Registry Closures",
            Description = "Deep scan getreg() for Lua closures with upvalue chains",
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
            Description = "Map all signal connections with source info and function details",
            Callback = function() task.spawn(DumpConnections) end
        })

        AdvTab:CreateButton({
            Title = "Deep Upvalue Trace",
            Description = "Walk upvalue chains from all loaded closures to find hidden scripts",
            Callback = function() task.spawn(DeepUpvalueTrace) end
        })

        AdvTab:CreateButton({
            Title = "Extract String Constants",
            Description = "Pull all string constants from every closure in registry",
            Callback = function() task.spawn(ExtractAllStringConstants) end
        })

        AdvTab:CreateSection("Export")

        AdvTab:CreateButton({
            Title = "Export Full Game (saveinstance)",
            Description = "Save entire game as .rbxl file",
            Callback = function()
                if Capabilities.SaveInstance then
                    Rayfield:Notify({ Title = "Export", Content = "Exporting game...", Duration = 3 })
                    pcall(function()
                        saveinstance({
                            filename = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_FullExport.rbxl",
                        })
                    end)
                    Rayfield:Notify({ Title = "Export", Content = "Game exported.", Duration = 5 })
                else
                    Rayfield:Notify({ Title = "Unsupported", Content = "saveinstance not available.", Duration = 3 })
                end
            end
        })

        AdvTab:CreateButton({
            Title = "Copy Save Path",
            Description = "Copy current output folder path to clipboard",
            Callback = function()
                if Capabilities.SetClipboard then
                    pcall(function() setclipboard(ScanState.OutputFolder) end)
                    Rayfield:Notify({ Title = "Copied", Content = "Path copied to clipboard.", Duration = 2 })
                end
            end
        })

        AdvTab:CreateButton({
            Title = "Generate Scan Report",
            Description = "Create a summary report of all extracted scripts",
            Callback = function() task.spawn(GenerateReport) end
        })

        AdvTab:CreateSection("System")

        AdvTab:CreateButton({
            Title = "Print Executor Capabilities",
            Description = "Dump all executor functions to dev console",
            Callback = function()
                print("========================================")
                print("  EXECUTOR CAPABILITIES")
                print("  Executor: " .. ExecutorName)
                print("  Bypass: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
                print("========================================")
                for k, v in pairs(Capabilities) do
                    print(string.format("  %-25s %s", k, tostring(v)))
                end
                print("========================================")
                Rayfield:Notify({ Title = "Console", Content = "Check dev console (F9).", Duration = 3 })
            end
        })

        AdvTab:CreateButton({
            Title = "Reinstall Bypass",
            Description = "Re-run anti-cheat bypass hooks",
            Callback = function()
                BypassState.HooksInstalled = false
                InstallBypass()
                Rayfield:Notify({
                    Title = "Bypass",
                    Content = "Bypass reinstalled: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"),
                    Duration = 4
                })
            end
        })

        -- ── REMOTE SPY TAB ──
        local RemoteTab = Window:CreateTab("Remote Spy", "radio")

        RemoteTab:CreateParagraph({
            Title = "Remote Event Monitor",
            Content = "Tracks all RemoteEvents and RemoteFunctions with call logging and argument capture"
        })

        RemoteCountRef = RemoteTab:CreateLabel("Remotes Found: 0")
        RemoteConnRef = RemoteTab:CreateLabel("Connections: 0")

        RemoteTab:CreateSection("Controls")

        RemoteTab:CreateButton({
            Title = "Start Remote Spy",
            Description = "Begin monitoring all remote events with argument capture",
            Callback = function()
                StartRemoteSpy()
                Rayfield:Notify({ Title = "Remote Spy", Content = "Monitoring started.", Duration = 3 })
            end
        })

        RemoteTab:CreateButton({
            Title = "Stop Remote Spy",
            Description = "Stop monitoring remote events",
            Callback = function()
                RemoteSpyActive = false
                Rayfield:Notify({ Title = "Remote Spy", Content = "Monitoring stopped.", Duration = 3 })
            end
        })

        RemoteTab:CreateButton({
            Title = "Export Remote Log",
            Description = "Save all discovered remotes with call counts and arguments to file",
            Callback = function()
                local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_RemoteSpy.txt"
                local content = "=== REMOTE SPY DUMP ===\n"
                content = content .. "Game: " .. GameInfo.Name .. "\n"
                content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n"

                for name, data in pairs(RemotesLog) do
                    content = content .. string.format("Name: %s\n", data.Name)
                    content = content .. string.format("Type: %s\n", data.Type)
                    content = content .. string.format("Hits: %d\n", data.Hits)
                    if #data.Args > 0 then
                        content = content .. "Captured Arguments:\n"
                        for i, argSet in ipairs(data.Args) do
                            local argStr = {}
                            for _, arg in ipairs(argSet) do
                                table.insert(argStr, tostring(arg):sub(1, 200))
                            end
                            content = content .. string.format("  [%d] %s\n", i, table.concat(argStr, ", "))
                        end
                    end
                    content = content .. string.rep("-", 50) .. "\n"
                end

                SafeWriteFile(path, content)
                Rayfield:Notify({ Title = "Exported", Content = "Saved to " .. path, Duration = 3 })
            end
        })

        RemoteTab:CreateButton({
            Title = "Fire All Remotes (Test)",
            Description = "Fire every RemoteEvent with no arguments for discovery",
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
                Rayfield:Notify({ Title = "Fired", Content = count .. " RemoteEvents fired.", Duration = 3 })
            end
        })

        -- ── UI UPDATER ──
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

        Rayfield:Notify({
            Title = "Apex Scanner Ready",
            Content = string.format("%s | %s | Bypass: %s", GameInfo.Name, ExecutorName,
                BypassState.HooksInstalled and "ACTIVE" or "LIMITED"),
            Duration = 5
        })

        print("========================================")
        print("  APEX SCRIPT SCANNER v6.0 — RAYFIELD")
        print("  Executor: " .. ExecutorName)
        print("  Bypass: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
        print("  Game: " .. GameInfo.Name .. " (" .. GameInfo.PlaceId .. ")")
        print("========================================")
    end)
end

-- ============================================================
-- SCRIPT COLLECTOR — UNIVERSAL
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

    -- Walk entire game tree
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

    -- Server-side services
    if ScanState.IncludeServer then
        local services = {
            { "ServerScriptService", "ServerScriptService" },
            { "ReplicatedStorage", "ReplicatedStorage" },
            { "ServerStorage", "ServerStorage" },
            { "StarterGui", "StarterGui" },
            { "StarterPack", "StarterPack" },
        }
        for _, svcData in ipairs(services) do
            local svcName, svcLabel = svcData[1], svcData[2]
            pcall(function()
                local svc = game:GetService(svcName)
                for _, obj in ipairs(svc:GetDescendants()) do addScript(obj, svcLabel, svcLabel) end
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

    -- getscripts()
    if Capabilities.GetScripts then
        pcall(function()
            for _, s in ipairs(getscripts()) do addScript(s, "getscripts()", "Executor") end
        end)
    end

    -- getloadedmodules()
    if Capabilities.GetLoadedModules then
        pcall(function()
            for _, s in ipairs(getloadedmodules()) do addScript(s, "getloadedmodules()", "LoadedModules") end
        end)
    end

    -- getnilinstances()
    if ScanState.IncludeNil and Capabilities.GetNilInstances then
        pcall(function()
            for _, s in ipairs(getnilinstances()) do addScript(s, "getnilinstances()", "NilParented") end
        end)
    end

    -- getinstances()
    if Capabilities.GetInstances then
        pcall(function()
            for _, inst in ipairs(getinstances()) do addScript(inst, "getinstances()", "AllInstances") end
        end)
    end

    -- CoreScripts (experimental)
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

    -- Registry scan for closures
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

    -- Deep upvalue chain walk
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
    -- Method 1: Direct decompile
    if Capabilities.Decompile and scriptObj then
        local result = nil
        pcall(function() result = decompile(scriptObj) end)
        if result and #result > 10 then return result, "decompiled" end

        -- Method 2: decompile with aggressive flag
        pcall(function() result = decompile(scriptObj, true) end)
        if result and #result > 10 then return result, "decompile(true)" end
    end

    -- Method 3: getscriptclosure + decompile
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

    -- Method 4: .Source property
    if scriptObj then
        local result = nil
        pcall(function() result = scriptObj.Source end)
        if result and #result > 10 then return "-- .Source property\n" .. result, ".Source" end

        -- Method 5: rawget .Source via metatable
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

    -- Method 6: Bytecode hex dump + string extraction
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

            -- Extract string constants from bytecode
            local stringsFound = {}
            for match in bytecode:gmatch("[%w%p ]{4,}") do
                if #match >= 4 and #match <= 200 then table.insert(stringsFound, match) end
            end

            local stringSection = ""
            if #stringsFound > 0 then
                stringSection = "\n\n-- STRING CONSTANTS EXTRACTED FROM BYTECODE:\n"
                for i, s in ipairs(stringsFound) do
                    if i > 200 then break end
                    stringSection = stringSection .. string.format("  [%d] %q\n", i, s)
                end
            end

            ScanState.BytecodeDumped = ScanState.BytecodeDumped + 1
            return "-- BYTECODE DUMP\n-- Length: " .. len .. " bytes\n-- Source: " ..
                   (scriptObj and scriptObj:GetFullName() or "closure") ..
                   "\n\n" .. table.concat(hexDump, "\n") .. stringSection, "bytecode"
        end
    end

    -- Method 7: Closure analysis (upvalues + constants)
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
                            pcall(function()
                                result = result .. string.format("      -> %s (%s)\n", v:GetFullName(), v.ClassName)
                            end)
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

    -- Method 8: Save fallback info
    local fallback = "-- DECOMPILE FAILED — All 8 methods exhausted.\n"
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
-- FILE MANAGEMENT — SPLIT BY SERVICE
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
            Rayfield:Notify({ Title = "Error", Content = "getscriptbytecode not supported.", Duration = 4 })
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
        Rayfield:Notify({ Title = "Bytecode", Content = count .. " scripts dumped.", Duration = 5 })
    end)
end

function ScanRegistry()
    task.spawn(function()
        if not Capabilities.GetReg then
            Rayfield:Notify({ Title = "Error", Content = "getreg not supported.", Duration = 4 })
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
                                        pcall(function()
                                            entry = entry .. string.format("    -> %s (%s)\n", uv:GetFullName(), uv.ClassName)
                                        end)
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
        Rayfield:Notify({ Title = "Registry", Content = count .. " closures found.", Duration = 5 })
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
        Rayfield:Notify({ Title = "Server Dump", Content = count .. " scripts saved.", Duration = 5 })
    end)
end

function DumpNilInstances()
    task.spawn(function()
        if not Capabilities.GetNilInstances then
            Rayfield:Notify({ Title = "Error", Content = "getnilinstances not supported.", Duration = 4 })
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
        Rayfield:Notify({ Title = "Nil Dump", Content = count .. " nil scripts found.", Duration = 5 })
    end)
end

function DumpConnections()
    task.spawn(function()
        if not Capabilities.GetConnections then
            Rayfield:Notify({ Title = "Error", Content = "getconnections not supported.", Duration = 4 })
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
        Rayfield:Notify({ Title = "Connections", Content = count .. " signals mapped.", Duration = 5 })
    end)
end

function DeepUpvalueTrace()
    task.spawn(function()
        if not Capabilities.GetReg or not Capabilities.DebugGetUpvalues then
            Rayfield:Notify({ Title = "Error", Content = "getreg/getupvalues not supported.", Duration = 4 })
            return
        end
        ScanState.StatusText = "Tracing upvalue chains..."
        local path = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_UpvalueTrace.txt"
        SafeWriteFile(path, "=== DEEP UPVALUE TRACE ===\n\n")
        local count = 0
        local visited = {}

        local function traceClosure(fn, depth, parent)
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
                            traceClosure(uv, depth + 1, fn)
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
                traceClosure(v, 0, nil)
                if count % 25 == 0 then task.wait() end
            end
        end

        ScanState.StatusText = "Upvalue trace done: " .. count
        Rayfield:Notify({ Title = "Upvalue Trace", Content = count .. " instances found.", Duration = 5 })
    end)
end

function ExtractAllStringConstants()
    task.spawn(function()
        if not Capabilities.GetReg then
            Rayfield:Notify({ Title = "Error", Content = "getreg not supported.", Duration = 4 })
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
        Rayfield:Notify({ Title = "Strings", Content = count .. " unique strings found.", Duration = 5 })
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
            "Game: %s\n" ..
            "Place ID: %d\n" ..
            "Creator: %s\n" ..
            "JobID: %s\n" ..
            "Executor: %s\n" ..
            "Bypass: %s\n" ..
            "Date: %s\n\n" ..
            "SCAN RESULTS:\n" ..
            "  Total Scripts: %d\n" ..
            "  Decompiled: %d\n" ..
            "  Protected (Failed): %d\n" ..
            "  Bytecode Dumped: %d\n" ..
            "  Remotes Found: %d\n" ..
            "  Connections Mapped: %d\n\n" ..
            "OUTPUT LOCATION: %s\n" ..
            "========================================\n",
            GameInfo.Name, GameInfo.PlaceId, GameInfo.Creator, GameInfo.JobId,
            ExecutorName, BypassState.HooksInstalled and "ACTIVE" or "LIMITED",
            os.date("%Y-%m-%d %H:%M:%S"),
            ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed,
            ScanState.BytecodeDumped, ScanState.RemotesFound, ScanState.ConnectionsFound,
            ScanState.OutputFolder
        )
        SafeWriteFile(path, report)
        ScanState.StatusText = "Report saved."
        Rayfield:Notify({ Title = "Report", Content = "Saved to " .. path, Duration = 4 })
    end)
end

-- ============================================================
-- MAIN SCANNER
-- ============================================================
function RunScanner()
    task.spawn(function()
        if ScanState.IsScanning then return end
        if not Capabilities.WriteFile or not Capabilities.AppendFile then
            Rayfield:Notify({ Title = "Error", Content = "writefile/appendfile not available.", Duration = 5 })
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
            Rayfield:Notify({ Title = "Scanner", Content = "No scripts found.", Duration = 5 })
            return
        end

        InitializeFile()
        ScanState.StatusText = "Scanning..."

        -- Sort by service for organized output
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

                -- Switch service folder if needed
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

                -- Log to script log
                table.insert(ScanState.ScriptLog, {
                    Name = data.Name,
                    Class = data.Class,
                    Service = data.Service,
                    Method = method,
                })

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

        -- Auto-generate report
        GenerateReport()

        Rayfield:Notify({
            Title = "Scan Complete!",
            Content = string.format("%d/%d extracted | %d bytecode | %d protected",
                ScanState.Decompiled, ScanState.TotalScripts, ScanState.BytecodeDumped, ScanState.Failed),
            Duration = 6
        })

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
