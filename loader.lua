--!nocheck
-- ============================================================
-- APEX SCRIPT SCANNER v7.5 -- INDIVIDUAL FILE OUTPUT
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
    GetRawMetatable = type(getrawmetatable) == "function",
    SetReadOnly = type(setreadonly) == "function",
    DebugGetUpvalues = type(debug.getupvalues) == "function",
    DebugGetConstants = type(debug.getconstants) == "function",
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
if ExecutorName == "Unknown" and Capabilities.WriteFile then
    ExecutorName = "Compatible"
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
    StatusText = "Ready",
    TimeText = "--:--",
    SuccessText = "Decompiled: 0 | Failed: 0 | Bytecode: 0",
    CountText = "Total Scripts: 0",
    FileText = "Save: Not started",
    OutputFolder = "",
}

local function SafeWriteFile(path, content) pcall(function() writefile(path, content) end) end
local function SafeMakeFolder(path) pcall(function() makefolder(path) end) end

ScanState.OutputFolder = GameInfo.Name .. "_APEX_Scan"
SafeMakeFolder(ScanState.OutputFolder)
SafeMakeFolder(ScanState.OutputFolder .. "/LocalScripts")
SafeMakeFolder(ScanState.OutputFolder .. "/ModuleScripts")
SafeMakeFolder(ScanState.OutputFolder .. "/Closures")
SafeMakeFolder(ScanState.OutputFolder .. "/ServerScripts_PROTECTED")
SafeMakeFolder(ScanState.OutputFolder .. "/Bytecode")

-- ============================================================
-- SANITIZE FILENAME
-- ============================================================
local function SanitizeFilename(name)
    return (name or "unknown"):gsub("[^%w_%.%-]", "_"):sub(1, 100)
end

local function GetUniquePath(folder, name, ext)
    local base = SanitizeFilename(name)
    local path = folder .. "/" .. base .. ext
    local counter = 1
    while true do
        local exists = false
        pcall(function()
            if isfile and isfile(path) then exists = true end
        end)
        if not exists then break end
        counter = counter + 1
        path = folder .. "/" .. base .. "_" .. counter .. ext
    end
    return path
end

-- ============================================================
-- SCRIPT COLLECTOR
-- ============================================================
local function CollectAllScripts()
    local collected = {}
    local seen = {}

    local function addScript(obj, source)
        if typeof(obj) ~= "Instance" then return end
        local isScript = false
        local scriptType = "Unknown"
        pcall(function()
            if obj:IsA("LocalScript") then
                isScript = true
                scriptType = "LocalScript"
            elseif obj:IsA("ModuleScript") then
                isScript = true
                scriptType = "ModuleScript"
            elseif obj:IsA("Script") or obj:IsA("BaseScript") then
                isScript = true
                scriptType = "Script"
            end
        end)
        if not isScript then return end

        local key = tostring(obj)
        if seen[key] then return end
        seen[key] = true

        local fullName = "Unknown"
        local isDisabled = false
        pcall(function()
            fullName = obj:GetFullName()
            isDisabled = obj.Disabled == true
        end)

        table.insert(collected, {
            Object = obj,
            Name = fullName,
            Class = scriptType,
            Disabled = isDisabled,
            Source = source or "Unknown",
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
-- MAIN SCANNER
-- ============================================================
function RunScanner()
    task.spawn(function()
        if ScanState.IsScanning then return end
        if not Capabilities.WriteFile then
            Notify("Error", "writefile not available.", 5)
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
            Notify("Scanner", "No scripts found.", 5)
            return
        end

        -- Write index file
        local indexPath = ScanState.OutputFolder .. "/_INDEX.txt"
        local indexContent = string.format(
            "========================================\n" ..
            "  APEX SCRIPT SCANNER v7.5\n" ..
            "  Game: %s (Place ID: %d)\n" ..
            "  Creator: %s\n" ..
            "  Executor: %s\n" ..
            "  Bypass: %s\n" ..
            "  Date: %s\n" ..
            "  Total Scripts: %d\n" ..
            "========================================\n\n",
            GameInfo.Name, GameInfo.PlaceId, GameInfo.Creator, ExecutorName,
            BypassState.HooksInstalled and "ACTIVE" or "LIMITED",
            os.date("%Y-%m-%d %H:%M:%S"),
            ScanState.TotalScripts
        )
        indexContent = indexContent .. "SCRIPT INDEX:\n"
        indexContent = indexContent .. string.rep("-", 80) .. "\n"

        for i, data in ipairs(allScripts) do
            local status = "PENDING"
            indexContent = indexContent .. string.format("[%d] %s | CLASS: %s | PATH: %s\n",
                i, status, data.Class, data.Name)
        end

        SafeWriteFile(indexPath, indexContent)
        ScanState.FileText = "Save: " .. ScanState.OutputFolder
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

            -- Determine output folder based on script type and status
            local folder
            if method == "failed" then
                if data.Class == "Script" then
                    folder = ScanState.OutputFolder .. "/ServerScripts_PROTECTED"
                else
                    folder = ScanState.OutputFolder .. "/Closures"
                end
            elseif method == "bytecode" then
                folder = ScanState.OutputFolder .. "/Bytecode"
            elseif data.Class == "LocalScript" then
                folder = ScanState.OutputFolder .. "/LocalScripts"
            elseif data.Class == "ModuleScript" then
                folder = ScanState.OutputFolder .. "/ModuleScripts"
            else
                folder = ScanState.OutputFolder .. "/Closures"
            end

            -- Build file content with metadata header
            local fileContent = string.format(
                "-- ============================================================\n" ..
                "-- APEX SCRIPT SCAN\n" ..
                "-- ============================================================\n" ..
                "-- Path: %s\n" ..
                "-- Class: %s\n" ..
                "-- Source: %s\n" ..
                "-- Status: %s\n" ..
                "-- Disabled: %s\n" ..
                "-- Method: %s\n" ..
                "-- Date: %s\n" ..
                "-- ============================================================\n\n",
                data.Name, data.Class, data.Source,
                method == "failed" and "PROTECTED" or "EXTRACTED (" .. method .. ")",
                tostring(data.Disabled), method,
                os.date("%Y-%m-%d %H:%M:%S")
            )
            fileContent = fileContent .. decompiled

            -- Save individual file
            local filePath = GetUniquePath(folder, data.Name, ".lua")
            SafeWriteFile(filePath, fileContent)

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

        -- Update index with results
        local finalIndex = string.format(
            "========================================\n" ..
            "  APEX SCRIPT SCANNER v7.5 -- COMPLETE\n" ..
            "  Game: %s (Place ID: %d)\n" ..
            "  Creator: %s\n" ..
            "  Executor: %s\n" ..
            "  Bypass: %s\n" ..
            "  Date: %s\n" ..
            "  Total Scripts: %d\n" ..
            "  Decompiled: %d\n" ..
            "  Failed (Server Scripts): %d\n" ..
            "  Bytecode: %d\n" ..
            "========================================\n\n",
            GameInfo.Name, GameInfo.PlaceId, GameInfo.Creator, ExecutorName,
            BypassState.HooksInstalled and "ACTIVE" or "LIMITED",
            os.date("%Y-%m-%d %H:%M:%S"),
            ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed, ScanState.BytecodeDumped
        )
        finalIndex = finalIndex .. "SCRIPT INDEX:\n"
        finalIndex = finalIndex .. string.rep("-", 80) .. "\n"

        for i, data in ipairs(allScripts) do
            local decompiled, method = DecompileScript(data.Object)
            finalIndex = finalIndex .. string.format("[%d] %s | CLASS: %s | PATH: %s\n",
                i,
                method == "failed" and "PROTECTED" or "OK",
                data.Class, data.Name)
        end

        SafeWriteFile(indexPath, finalIndex)

        ScanState.IsScanning = false
        ScanState.StatusText = "COMPLETE!"
        ScanState.TimeText = "00:00"

        Notify("Scan Complete!",
            string.format("%d/%d decompiled | %d bytecode | %d protected",
                ScanState.Decompiled, ScanState.TotalScripts, ScanState.BytecodeDumped, ScanState.Failed),
            6)

        if Capabilities.SetClipboard then
            pcall(function() setclipboard(ScanState.OutputFolder) end)
        end

        getgenv().ScannerRunning = false
    end)
end

-- ============================================================
-- DRAGGING HELPER
-- ============================================================
local function MakeDraggable(frame)
    local dragging = false
    local dragStart = nil
    local startPos = nil

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

-- ============================================================
-- BUILD UI
-- ============================================================
local StatusRef = { Set = function() end }
local TimeRef = { Set = function() end }
local FileRef = { Set = function() end }
local CountRef = { Set = function() end }
local SuccessRef = { Set = function() end }

local function getGuiParent()
    local parent = nil
    pcall(function() parent = gethui() end)
    if parent and parent:IsA("Instance") then return parent end
    return game:GetService("CoreGui")
end

local function BuildUI()
    local parent = getGuiParent()

    pcall(function()
        local old = parent:FindFirstChild("ApexScanner")
        if old then old:Destroy() end
    end)

    local sg = Instance.new("ScreenGui")
    sg.Name = "ApexScanner"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 9999
    sg.IgnoreGuiInset = true
    sg.Parent = parent

    local mf = Instance.new("Frame")
    mf.Name = "MainFrame"
    mf.Size = UDim2.new(0, 520, 0, 400)
    mf.Position = UDim2.new(0.5, -260, 0.5, -200)
    mf.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    mf.BorderSizePixel = 0
    mf.Parent = sg
    Instance.new("UICorner", mf).CornerRadius = UDim.new(0, 8)

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mf
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

    local cover = Instance.new("Frame")
    cover.Size = UDim2.new(1, 0, 0, 12)
    cover.Position = UDim2.new(0, 0, 1, -12)
    cover.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
    cover.BorderSizePixel = 0
    cover.Parent = titleBar

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -80, 1, 0)
    titleText.Position = UDim2.new(0, 12, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "  APEX SCANNER v7.5 | " .. GameInfo.Name
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 14
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 28, 0, 28)
    minBtn.Position = UDim2.new(1, -64, 0, 4)
    minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    minBtn.Text = "-"
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 16
    minBtn.BorderSizePixel = 0
    minBtn.Parent = titleBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -32, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, 0, 1, -36)
    contentArea.Position = UDim2.new(0, 0, 0, 36)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mf

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -16)
    scroll.Position = UDim2.new(0, 8, 0, 8)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = contentArea

    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0, 6)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent = scroll

    MakeDraggable(titleBar)

    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            contentArea.Visible = false
            mf.Size = UDim2.new(0, 520, 0, 36)
        else
            contentArea.Visible = true
            mf.Size = UDim2.new(0, 520, 0, 400)
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        ScanState.IsScanning = false
        getgenv().ScannerRunning = false
        sg:Destroy()
    end)

    local orderCounter = 0
    local function nextOrder()
        orderCounter = orderCounter + 1
        return orderCounter
    end

    local function mkSection(name)
        local s = Instance.new("TextLabel")
        s.Size = UDim2.new(1, 0, 0, 22)
        s.BackgroundTransparency = 1
        s.Text = name
        s.TextColor3 = Color3.fromRGB(130, 130, 145)
        s.Font = Enum.Font.GothamBold
        s.TextSize = 11
        s.TextXAlignment = Enum.TextXAlignment.Left
        s.LayoutOrder = nextOrder()
        s.Parent = scroll
    end

    local function mkLabel(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 20)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = Color3.fromRGB(200, 200, 210)
        l.Font = Enum.Font.Gotham
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.LayoutOrder = nextOrder()
        l.Parent = scroll
        return { Set = function(_, v) pcall(function() l.Text = v end) end }
    end

    local function mkParagraph(title, content)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 0)
        f.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        f.BorderSizePixel = 0
        f.AutomaticSize = Enum.AutomaticSize.Y
        f.LayoutOrder = nextOrder()
        f.Parent = scroll
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
        local cl = Instance.new("UIListLayout")
        cl.Padding = UDim.new(0, 4)
        cl.Parent = f
        local pad = Instance.new("UIPadding", f)
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)

        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 0, 18)
        tl.BackgroundTransparency = 1
        tl.Text = title
        tl.TextColor3 = Color3.fromRGB(255, 255, 255)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 14
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.Parent = f

        local ct = Instance.new("TextLabel")
        ct.Size = UDim2.new(1, 0, 0, 0)
        ct.BackgroundTransparency = 1
        ct.Text = content
        ct.TextColor3 = Color3.fromRGB(160, 160, 175)
        ct.Font = Enum.Font.Gotham
        ct.TextSize = 12
        ct.TextWrapped = true
        ct.TextXAlignment = Enum.TextXAlignment.Left
        ct.TextYAlignment = Enum.TextYAlignment.Top
        ct.AutomaticSize = Enum.AutomaticSize.Y
        ct.Parent = f
    end

    local function mkButton(title, desc, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 36)
        b.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        b.Text = ""
        b.BorderSizePixel = 0
        b.LayoutOrder = nextOrder()
        b.Parent = scroll
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, -20, 0, 18)
        tl.Position = UDim2.new(0, 10, 0, 3)
        tl.BackgroundTransparency = 1
        tl.Text = title
        tl.TextColor3 = Color3.fromRGB(255, 255, 255)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 13
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.Parent = b

        if desc then
            local dl = Instance.new("TextLabel")
            dl.Size = UDim2.new(1, -20, 0, 14)
            dl.Position = UDim2.new(0, 10, 0, 20)
            dl.BackgroundTransparency = 1
            dl.Text = desc
            dl.TextColor3 = Color3.fromRGB(120, 120, 135)
            dl.Font = Enum.Font.Gotham
            dl.TextSize = 11
            dl.TextXAlignment = Enum.TextXAlignment.Left
            dl.Parent = b
        end

        b.MouseButton1Click:Connect(function() pcall(cb) end)
        b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(45, 45, 58) end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = Color3.fromRGB(35, 35, 45) end)
    end

    -- BUILD CONTENT
    mkSection("=== Scanner ===")

    mkParagraph(GameInfo.Name,
        string.format("Place ID: %d\nCreator: %s\nExecutor: %s\nJobID: %s\nBypass: %s\nOutput: %s/",
            GameInfo.PlaceId, GameInfo.Creator, ExecutorName, GameInfo.JobId,
            BypassState.HooksInstalled and "ACTIVE" or "LIMITED",
            ScanState.OutputFolder))

    mkSection("Status")
    StatusRef = mkLabel("Status: Ready")
    TimeRef = mkLabel("Time: --:--")
    FileRef = mkLabel("Save: Not started")
    CountRef = mkLabel("Total Scripts: 0")
    SuccessRef = mkLabel("Decompiled: 0 | Failed: 0 | Bytecode: 0")

    mkSection("Controls")
    mkButton("Start Full Scan", "Collect and decompile ALL scripts - saves each as individual file", function() RunScanner() end)
    mkButton("Toggle Pause", "Pause / resume scan", function()
        if not ScanState.IsScanning then return end
        ScanState.IsPaused = not ScanState.IsPaused
        ScanState.StatusText = ScanState.IsPaused and "PAUSED" or "Resuming..."
    end)
    mkButton("Stop Scan", "Abort current scan", function()
        ScanState.IsScanning = false
        ScanState.IsPaused = false
        ScanState.StatusText = "STOPPED"
        getgenv().ScannerRunning = false
        Notify("Scanner", "Scan stopped.", 3)
    end)

    mkSection("=== Advanced ===")

    mkButton("Copy Save Path", "Copy output folder to clipboard", function()
        if Capabilities.SetClipboard then
            pcall(function() setclipboard(ScanState.OutputFolder) end)
            Notify("Copied", ScanState.OutputFolder, 3)
        end
    end)

    if Capabilities.SaveInstance then
        mkButton("Export Full Game (saveinstance)", "Save entire game as .rbxl", function()
            pcall(function() saveinstance({ filename = ScanState.OutputFolder .. "/" .. GameInfo.Name .. "_FullExport.rbxl" }) end)
            Notify("Export", "Game exported.", 5)
        end)
    end

    mkButton("Print Executor Capabilities", "Check F9 console", function()
        print("========================================")
        print("  EXECUTOR: " .. ExecutorName)
        print("  BYPASS: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
        print("========================================")
        for k, v in pairs(Capabilities) do
            print(string.format("  %-25s %s", k, tostring(v)))
        end
        print("========================================")
        Notify("Console", "Check F9.", 3)
    end)

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

    Notify("Apex Scanner", "Ready | " .. GameInfo.Name .. " | " .. ExecutorName, 5)

    print("========================================")
    print("  APEX SCANNER v7.5 -- INDIVIDUAL FILES")
    print("  Executor: " .. ExecutorName)
    print("  Bypass: " .. (BypassState.HooksInstalled and "ACTIVE" or "LIMITED"))
    print("  Game: " .. GameInfo.Name .. " (" .. GameInfo.PlaceId .. ")")
    print("  Output: " .. ScanState.OutputFolder .. "/")
    print("    /LocalScripts/")
    print("    /ModuleScripts/")
    print("    /Closures/")
    print("    /Bytecode/")
    print("    /ServerScripts_PROTECTED/")
    print("    _INDEX.txt")
    print("========================================")
end

BuildUI()
