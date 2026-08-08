--!nocheck
-- ============================================================
-- APEX SCRIPT SCANNER v7.2 -- RAYFIELD (CLEAN)
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
    MakeFolder = type(makefolder) == "function",
    Decompile = type(decompile) == "function",
    GetScripts = type(getscripts) == "function",
    GetLoadedModules = type(getloadedmodules) == "function",
    GetNilInstances = type(getnilinstances) == "function",
    GetInstances = type(getinstances) == "function",
    GetScriptBytecode = type(getscriptbytecode) == "function",
    GetScriptClosure = type(getscriptclosure) == "function",
    GetSenv = type(getsenv) == "function",
    SaveInstance = type(saveinstance) == "function",
    HookFunction = type(hookfunction) == "function",
    GetRawMetatable = type(getrawmetatable) == "function",
    SetReadOnly = type(setreadonly) == "function",
    DebugGetUpvalues = type(debug.getupvalues) == "function",
    DebugGetConstants = type(debug.getconstants) == "function",
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
    if Capabilities.GetScriptBytecode and Capabilities.Newcclosure then
        ExecutorName = "Advanced"
    elseif Capabilities.WriteFile then
        ExecutorName = "Compatible"
    end
end

-- ============================================================
-- GAME INFO
-- ============================================================
local function GetGameInfo()
    local info = { Name = "UnknownGame", PlaceId = game.PlaceId, Creator = "Unknown", JobId = game.JobId or "N/A" }
    pcall(function()
        local product = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
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
            Title = title or "", Text = text or "", Duration = dur or 3,
        })
    end)
end

-- ============================================================
-- RAYFIELD LOADER -- NO LOCAL SHADOWING
-- ============================================================
local RayfieldReady = false

local function LoadRayfield()
    -- clear stale global
    _G.Rayfield = nil
    Rayfield = nil

    local urls = {
        "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
        "https://github.com/shlexware/Rayfield/raw/main/source",
    }
    for _, url in ipairs(urls) do
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and src and #src > 500 then
            local fn = loadstring(src)
            if fn then
                local ok2, err = pcall(fn)
                if ok2 then
                    -- check global directly, no local involved
                    if Rayfield then
                        RayfieldReady = true
                        return
                    end
                    if _G.Rayfield then
                        Rayfield = _G.Rayfield
                        RayfieldReady = true
                        return
                    end
                else
                    print("[Apex] Rayfield exec error: " .. tostring(err):sub(1, 200))
                end
            end
        end
    end
    print("[Apex] Rayfield failed to load, using fallback UI")
end

LoadRayfield()

-- ============================================================
-- UI WRAPPER
-- ============================================================
local function UINotify(title, content, dur)
    if RayfieldReady and Rayfield then
        pcall(function()
            Rayfield:Notify({ Title = title, Content = content, Duration = dur or 3 })
        end)
    else
        Notify(title, content, dur)
    end
end

-- ============================================================
-- STATE
-- ============================================================
local ScanState = {
    IsScanning = false,
    IsPaused = false,
    TotalScripts = 0,
    Processed = 0,
    Decompiled = 0,
    Failed = 0,
    BytecodeDumped = 0,
    StartTime = 0,
    CurrentFile = "",
    StatusText = "Ready",
    TimeText = "--:--",
    SuccessText = "Decompiled: 0 | Failed: 0 | Bytecode: 0",
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
-- SCRIPT COLLECTOR
-- ============================================================
local function CollectAllScripts()
    local collected = {}
    local seen = {}

    local function addScript(obj, source)
        if typeof(obj) ~= "Instance" then return end
        local isScript = false
        pcall(function()
            if obj:IsA("Script") or obj:IsA("LocalScript") or
               obj:IsA("ModuleScript") or obj:IsA("BaseScript") then
                isScript = true
            end
        end)
        if not isScript then return end

        local key = tostring(obj)
        if seen[key] then return end
        seen[key] = true

        local fullName = "Unknown"
        local className = "Unknown"
        local isDisabled = false
        pcall(function()
            fullName = obj:GetFullName()
            className = obj.ClassName
            isDisabled = obj.Disabled == true
        end)

        table.insert(collected, {
            Object = obj, Name = fullName, Class = className,
            Disabled = isDisabled, Source = source or "Unknown",
        })
    end

    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do addScript(obj, "GameTree") end
    end)
    if Capabilities.GetScripts then
        pcall(function() for _, s in ipairs(getscripts()) do addScript(s, "getscripts()") end end)
    end
    if Capabilities.GetLoadedModules then
        pcall(function() for _, s in ipairs(getloadedmodules()) do addScript(s, "getloadedmodules()") end end)
    end
    if Capabilities.GetNilInstances then
        pcall(function() for _, s in ipairs(getnilinstances()) do addScript(s, "getnilinstances()") end end)
    end
    if Capabilities.GetInstances then
        pcall(function() for _, inst in ipairs(getinstances()) do addScript(inst, "getinstances()") end end)
    end

    return collected
end

-- ============================================================
-- DECOMPILE
-- ============================================================
local function DecompileScript(scriptObj)
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
        if cl and Capabilities.Decompile then
            local result = nil
            pcall(function() result = decompile(cl) end)
            if result and #result > 10 then return result, "closure+decompile" end
        end
    end

    if scriptObj then
        local result = nil
        pcall(function() result = scriptObj.Source end)
        if result and #result > 10 then return "-- .Source\n" .. result, ".Source" end
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

    if Capabilities.GetSenv and scriptObj then
        local env = nil
        pcall(function() env = getsenv(scriptObj) end)
        if env and type(env) == "table" then
            local result = "-- SCRIPT ENVIRONMENT (getsenv)\n-- Script: " ..
                (scriptObj and scriptObj:GetFullName() or "unknown") .. "\n\n"
            local count = 0
            for k, v in pairs(env) do
                count = count + 1
                local valStr = tostring(v):sub(1, 500)
                if type(v) == "function" then
                    local info = debug.getinfo(v)
                    valStr = string.format("function [%s:%s-%s]",
                        info.source or "?", tostring(info.linedefined), tostring(info.lastlinedefined))
                elseif typeof(v) == "Instance" then
                    pcall(function() valStr = v:GetFullName() .. " (" .. v.ClassName .. ")" end)
                end
                result = result .. string.format("  [%s] %s = %s\n", tostring(k), type(v), valStr)
            end
            if count > 0 then return result, "getsenv" end
        end
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
            return "-- BYTECODE DUMP\n-- Length: " .. len .. " bytes\n\n" ..
                   table.concat(hexDump, "\n") .. stringSection, "bytecode"
        end
    end

    if Capabilities.GetScriptClosure and scriptObj then
        local cl = nil
        pcall(function() cl = getscriptclosure(scriptObj) end)
        if cl then
            local result = "-- CLOSURE ANALYSIS\n"
            local hasData = false
            pcall(function()
                if Capabilities.DebugGetUpvalues then
                    local upvals = debug.getupvalues(cl)
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
                    local consts = debug.getconstants(cl)
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
                local info = debug.getinfo(cl)
                if info then
                    hasData = true
                    result = result .. "\n-- DEBUG INFO:\n"
                    result = result .. "  source: " .. tostring(info.source) .. "\n"
                    result = result .. "  lines: " .. tostring(info.linedefined) .. "-" .. tostring(info.lastlinedefined) .. "\n"
                end
            end)
            if hasData then return result, "closure-analysis" end
        end
    end

    local fallback = "-- DECOMPILE FAILED\n"
    if scriptObj then
        pcall(function()
            fallback = fallback .. "-- Script: " .. scriptObj:GetFullName() .. "\n"
            fallback = fallback .. "-- Class: " .. scriptObj.ClassName .. "\n"
            fallback = fallback .. "-- Disabled: " .. tostring(scriptObj.Disabled) .. "\n"
            fallback = fallback .. "-- Note: Server Scripts do not replicate source to client\n"
        end)
    end
    return fallback, "failed"
end

-- ============================================================
-- FILE MANAGEMENT
-- ============================================================
local currentFileSize = 0
local filePart = 1
local writeBuffer = {}
local bufferSize = 0
local MAX_FILE_SIZE = 10 * 1024 * 1024
local MAX_BUFFER_SIZE = 1024 * 1024

local function FlushBuffer()
    if #writeBuffer == 0 then return end
    local chunk = table.concat(writeBuffer, "\n")
    writeBuffer = {}
    bufferSize = 0
    if currentFileSize + #chunk > MAX_FILE_SIZE then
        filePart = filePart + 1
        ScanState.CurrentFile = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_Part_" .. filePart .. ".txt"
        SafeWriteFile(ScanState.CurrentFile, string.format("-- APEX SCAN PART %d\n-- Date: %s\n\n", filePart, os.date("%Y-%m-%d %H:%M:%S")))
        currentFileSize = 0
        ScanState.FileText = "Save: " .. ScanState.CurrentFile
    end
    SafeAppendFile(ScanState.CurrentFile, chunk)
    currentFileSize = currentFileSize + #chunk
end

local function InitializeFile()
    filePart = 1
    ScanState.CurrentFile = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_Scripts_Part_1.txt"
    SafeWriteFile(ScanState.CurrentFile, string.format(
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
    ScanState.FileText = "Save: " .. ScanState.CurrentFile
end

-- ============================================================
-- MAIN SCANNER
-- ============================================================
function RunScanner()
    task.spawn(function()
        if ScanState.IsScanning then return end
        if not Capabilities.WriteFile or not Capabilities.AppendFile then
            UINotify("Error", "writefile/appendfile not available.", 5)
            return
        end

        ScanState.IsScanning = true
        ScanState.IsPaused = false
        ScanState.Processed = 0
        ScanState.Decompiled = 0
        ScanState.Failed = 0
        ScanState.BytecodeDumped = 0
        ScanState.StartTime = tick()
        ScanState.StatusText = "Collecting scripts..."

        local allScripts = CollectAllScripts()
        ScanState.TotalScripts = #allScripts
        ScanState.CountText = "Total Scripts: " .. ScanState.TotalScripts

        if ScanState.TotalScripts == 0 then
            ScanState.StatusText = "No scripts found!"
            ScanState.IsScanning = false
            getgenv().ScannerRunning = false
            UINotify("Scanner", "No scripts found.", 5)
            return
        end

        InitializeFile()
        ScanState.StatusText = "Scanning..."

        for i = 1, ScanState.TotalScripts do
            while ScanState.IsPaused do
                task.wait(0.5)
                if not ScanState.IsScanning then return end
            end
            if not ScanState.IsScanning then break end

            local data = allScripts[i]
            local decompiled, method = DecompileScript(data.Object)

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
                "\n%s\nSCRIPT: %s%s\nCLASS: %s\nSOURCE: %s\nSTATUS: %s\n%s\n%s\n\n",
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
                ScanState.SuccessText = string.format("Decompiled: %d | Failed: %d | Bytecode: %d",
                    ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped)
            end
            task.wait()
        end

        FlushBuffer()
        SafeAppendFile(ScanState.CurrentFile, string.format(
            "\n=== SCAN COMPLETE ===\nTotal: %d | Decompiled: %d | Failed: %d | Bytecode: %d\nDate: %s\n",
            ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped,
            os.date("%Y-%m-%d %H:%M:%S")))

        ScanState.IsScanning = false
        ScanState.StatusText = "COMPLETE!"
        ScanState.TimeText = "00:00"

        UINotify("Scan Complete!",
            string.format("%d/%d decompiled | %d bytecode | %d failed",
                ScanState.Decompiled, ScanState.TotalScripts, ScanState.BytecodeDumped, ScanState.Failed),
            6)

        if Capabilities.SetClipboard then
            pcall(function() setclipboard(ScanState.OutputFolder) end)
        end

        getgenv().ScannerRunning = false
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

local function BuildUI()
    local Window

    if RayfieldReady and Rayfield then
        Window = Rayfield:CreateWindow({
            Name = "Apex Scanner v7.2 | " .. GameInfo.Name,
            LoadingTitle = "Apex Scanner",
            LoadingSubtitle = "Loading...",
            Theme = "Default",
            ConfigurationSaving = { Enabled = false },
            Keybind = Enum.KeyCode.RightControl,
        })
    else
        -- Fallback UI
        local parent = nil
        pcall(function() parent = gethui() end)
        if not parent or not parent:IsA("Instance") then parent = game:GetService("CoreGui") end

        pcall(function()
            local old = parent:FindFirstChild("ApexFallback")
            if old then old:Destroy() end
        end)

        local sg = Instance.new("ScreenGui")
        sg.Name = "ApexFallback"
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 9999
        sg.IgnoreGuiInset = true
        sg.Parent = parent

        local mf = Instance.new("Frame")
        mf.Size = UDim2.new(0, 500, 0, 350)
        mf.Position = UDim2.new(0.5, -250, 0.5, -175)
        mf.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        mf.BorderSizePixel = 0
        mf.Parent = sg
        Instance.new("UICorner", mf).CornerRadius = UDim.new(0, 8)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 35)
        title.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        title.Text = "  APEX SCANNER v7.2 (Fallback)"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.BorderSizePixel = 0
        title.Parent = mf
        Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -20, 1, -55)
        scroll.Position = UDim2.new(0, 10, 0, 45)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Parent = mf
        local ll = Instance.new("UIListLayout")
        ll.Padding = UDim.new(0, 6)
        ll.Parent = scroll

        local function mkLabel(text)
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, 0, 0, 20)
            l.BackgroundTransparency = 1
            l.Text = text
            l.TextColor3 = Color3.fromRGB(200, 200, 210)
            l.Font = Enum.Font.Gotham
            l.TextSize = 12
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = scroll
            return { Set = function(_, v) pcall(function() l.Text = v end) end }
        end

        local function mkButton(text, cb)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 32)
            b.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            b.Text = text
            b.TextColor3 = Color3.fromRGB(255, 255, 255)
            b.Font = Enum.Font.GothamBold
            b.TextSize = 13
            b.BorderSizePixel = 0
            b.Parent = scroll
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            b.MouseButton1Click:Connect(function() pcall(cb) end)
        end

        local fakeTab = {}
        function fakeTab:CreateSection(name)
            local s = Instance.new("TextLabel")
            s.Size = UDim2.new(1, 0, 0, 22)
            s.BackgroundTransparency = 1
            s.Text = name
            s.TextColor3 = Color3.fromRGB(130, 130, 145)
            s.Font = Enum.Font.GothamBold
            s.TextSize = 11
            s.TextXAlignment = Enum.TextXAlignment.Left
            s.Parent = scroll
        end
        function fakeTab:CreateParagraph(p)
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 0)
            f.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
            f.BorderSizePixel = 0
            f.AutomaticSize = Enum.AutomaticSize.Y
            f.Parent = scroll
            Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, 0, 0, 0)
            t.BackgroundTransparency = 1
            t.Text = (p.Title or "") .. "\n" .. (p.Content or "")
            t.TextColor3 = Color3.fromRGB(200, 200, 210)
            t.Font = Enum.Font.Gotham
            t.TextSize = 12
            t.TextWrapped = true
            t.TextXAlignment = Enum.TextXAlignment.Left
            t.TextYAlignment = Enum.TextYAlignment.Top
            t.AutomaticSize = Enum.AutomaticSize.Y
            t.Parent = f
            local pad = Instance.new("UIPadding", f)
            pad.PaddingTop = UDim.new(0, 8)
            pad.PaddingBottom = UDim.new(0, 8)
            pad.PaddingLeft = UDim.new(0, 10)
            pad.PaddingRight = UDim.new(0, 10)
        end
        function fakeTab:CreateLabel(text) return mkLabel(text) end
        function fakeTab:CreateButton(b) mkButton(b.Title or "Button", b.Callback) end

        Window = {
            CreateTab = function(_, tc)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, 0, 0, 28)
                l.BackgroundTransparency = 1
                l.Text = "=== " .. (tc.Title or "Tab") .. " ==="
                l.TextColor3 = Color3.fromRGB(255, 255, 255)
                l.Font = Enum.Font.GothamBold
                l.TextSize = 14
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.Parent = scroll
                return fakeTab
            end
        }
    end

    -- MAIN TAB
    local MainTab = Window:CreateTab({ Title = "Scanner", Icon = "scan" })

    MainTab:CreateSection("Game Info")
    MainTab:CreateParagraph({
        Title = GameInfo.Name,
        Content = string.format("Place ID: %d\nCreator: %s\nExecutor: %s\nJobID: %s\nBypass: %s\nUI: %s",
            GameInfo.PlaceId, GameInfo.Creator, ExecutorName, GameInfo.JobId,
            BypassState.HooksInstalled and "ACTIVE" or "LIMITED",
            RayfieldReady and "Rayfield" or "Fallback")
    })

    MainTab:CreateSection("Status")
    StatusRef = MainTab:CreateLabel("Status: Ready")
    TimeRef = MainTab:CreateLabel("Time: --:--")
    FileRef = MainTab:CreateLabel("Save: Not started")
    CountRef = MainTab:CreateLabel("Total Scripts: 0")
    SuccessRef = MainTab:CreateLabel("Decompiled: 0 | Failed: 0 | Bytecode: 0")

    MainTab:CreateSection("Controls")
    MainTab:CreateButton({
        Title = "Start Full Scan",
        Description = "Collect and decompile ALL scripts in the game",
        Callback = function() RunScanner() end
    })
    MainTab:CreateButton({
        Title = "Toggle Pause",
        Description = "Pause / resume scan",
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
            UINotify("Scanner", "Scan stopped.", 3)
        end
    })

    -- ADVANCED TAB
    local AdvTab = Window:CreateTab({ Title = "Advanced", Icon = "wrench" })

    AdvTab:CreateSection("Export")
    AdvTab:CreateButton({
        Title = "Copy Save Path",
        Description = "Copy output folder to clipboard",
        Callback = function()
            if Capabilities.SetClipboard then
                pcall(function() setclipboard(ScanState.OutputFolder) end)
                UINotify("Copied", ScanState.OutputFolder, 3)
            end
        end
    })

    if Capabilities.SaveInstance then
        AdvTab:CreateButton({
            Title = "Export Full Game (saveinstance)",
            Description = "Save entire game as .rbxl",
            Callback = function()
                pcall(function() saveinstance({ filename = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_FullExport.rbxl" }) end)
                UINotify("Export", "Game exported.", 5)
            end
        })
    end

    AdvTab:CreateSection("System")
    AdvTab:CreateButton({
        Title = "Print Executor Capabilities",
        Description = "Check F9 console",
        Callback = function()
            print("========================================")
            print("  EXECUTOR: " .. ExecutorName)
            print("  BYPASS: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
            print("  RAYFIELD: " .. (RayfieldReady and "LOADED" or "FALLBACK"))
            print("========================================")
            for k, v in pairs(Capabilities) do
                print(string.format("  %-25s %s", k, tostring(v)))
            end
            print("========================================")
            UINotify("Console", "Check F9.", 3)
        end
    })

    -- UI UPDATER
    task.spawn(function()
        while true do
            task.wait(0.3)
            pcall(function()
                StatusRef:Set(ScanState.StatusText)
                TimeRef:Set(ScanState.TimeText)
                FileRef:Set(ScanState.FileText)
                CountRef:Set(ScanState.CountText)
                SuccessRef:Set(ScanState.SuccessText)
            end)
        end
    end)

    UINotify("Apex Scanner", "Ready | " .. GameInfo.Name .. " | " .. ExecutorName .. " | " .. (RayfieldReady and "Rayfield" or "Fallback"), 5)

    print("========================================")
    print("  APEX SCANNER v7.2 -- RAYFIELD")
    print("  Executor: " .. ExecutorName)
    print("  Bypass: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
    print("  Rayfield: " .. (RayfieldReady and "LOADED" or "FALLBACK"))
    print("  Game: " .. GameInfo.Name .. " (" .. GameInfo.PlaceId .. ")")
    print("========================================")
end

BuildUI()
