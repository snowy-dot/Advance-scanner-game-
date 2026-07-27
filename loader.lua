--!nocheck
-- ============================================================
-- ULTIMATE UNIVERSAL SCRIPT SCANNER v3.3
-- FIXED: UI crash (buttons disappearing) — fully decoupled
-- ============================================================

-- ============================================================
-- PREVENT DUPLICATE EXECUTION
-- ============================================================
if getgenv().ScannerRunning then
    print("[Scanner] Already running. Skipping duplicate.")
    return
end
getgenv().ScannerRunning = true

-- ============================================================
-- BYPASS LAYER
-- ============================================================
local function BypassProtections()
    pcall(function()
        if hookfunction then
            local old = hookfunction(debug.getinfo, function() 
                return {source = "", short_src = "", func = function() end} 
            end)
            hookfunction(debug.getinfo, function(...) 
                if select(1, ...) == 2 then 
                    return {source = "", short_src = "", func = function() end} 
                end
                return old(...)
            end)
        end
    end)

    pcall(function()
        local mt = getrawmetatable(game)
        if mt then
            local old = mt.__index
            mt.__index = function(t, k)
                if k == "GetDescendants" then
                    return function(self)
                        local results = {}
                        local raw = old(self, "GetDescendants")(self)
                        for _, v in ipairs(raw) do
                            if typeof(v) == "Instance" and v ~= script and v.Name ~= "ScriptScanner" then
                                table.insert(results, v)
                            end
                        end
                        return results
                    end
                end
                return old(t, k)
            end
            setrawmetatable(game, mt)
        end
    end)

    pcall(function()
        if getreg then
            local reg = getreg()
            for i = 1, #reg do
                if type(reg[i]) == "function" and tostring(reg[i]):find("Scanning") then
                    reg[i] = function() end
                end
            end
        end
    end)
end

BypassProtections()

-- ============================================================
-- EXECUTOR DETECTION
-- ============================================================
local ExecutorCapabilities = {
    WriteFile = type(writefile) == "function",
    AppendFile = type(appendfile) == "function",
    Decompile = type(decompile) == "function",
    GetScripts = type(getscripts) == "function",
    GetLoadedModules = type(getloadedmodules) == "function",
    GetNilInstances = type(getnilinstances) == "function",
    GetReg = type(getreg) == "function"
}

local ExecutorType = "Unknown"
if ExecutorCapabilities.WriteFile then
    if ExecutorCapabilities.GetReg then ExecutorType = "Krnl"
    else ExecutorType = "Compatible" end
end

-- ============================================================
-- RAYFIELD LOADER
-- ============================================================
local Rayfield = nil

local success, result = pcall(function()
    return game:HttpGet("https://sirius.menu/rayfield")
end)

if success and result then
    local fn = loadstring(result)
    if fn then
        pcall(function() fn() end)
        Rayfield = rayfield
        if not Rayfield then
            Rayfield = loadstring(result)()
        end
    end
end

if not Rayfield then
    local success2, result2 = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source")
    end)
    if success2 and result2 then
        local fn2 = loadstring(result2)
        if fn2 then
            pcall(function() fn2() end)
            Rayfield = rayfield
        end
    end
end

if not Rayfield then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Scanner Ready (No GUI)",
            Text = "Rayfield failed. Using text output only.",
            Duration = 5
        })
    end)
    
    Rayfield = {
        CreateWindow = function() return { 
            CreateTab = function() return { 
                CreateLabel = function() return { Set = function() end } end, 
                CreateButton = function() return { Callback = function() end } end, 
                CreateDivider = function() end, 
                CreateParagraph = function() end 
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
        Creator = "Unknown" 
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
-- STATE MANAGEMENT
-- ============================================================
local State = {
    IsScanning = false,
    IsPaused = false,
    TotalScripts = 0,
    Processed = 0,
    Decompiled = 0,
    Failed = 0,
    StartTime = 0,
    CurrentFile = "",
    FileParts = 0
}

local ScanStatistics = {
    ByType = { Script = 0, LocalScript = 0, ModuleScript = 0, Other = 0 },
    BySource = { Game = 0, Executor = 0, Nil = 0, Loaded = 0 },
    ByStatus = { Decompiled = 0, Protected = 0, TimedOut = 0, Error = 0 }
}

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
        
        if className == "Script" then ScanStatistics.ByType.Script = ScanStatistics.ByType.Script + 1
        elseif className == "LocalScript" then ScanStatistics.ByType.LocalScript = ScanStatistics.ByType.LocalScript + 1
        elseif className == "ModuleScript" then ScanStatistics.ByType.ModuleScript = ScanStatistics.ByType.ModuleScript + 1
        else ScanStatistics.ByType.Other = ScanStatistics.ByType.Other + 1 end
    end

    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            addScript(obj, "GameTree")
        end
    end)

    if ExecutorCapabilities.GetScripts then
        pcall(function()
            for _, s in ipairs(getscripts()) do
                addScript(s, "getscripts()")
            end
        end)
    end

    if ExecutorCapabilities.GetLoadedModules then
        pcall(function()
            for _, s in ipairs(getloadedmodules()) do
                addScript(s, "getloadedmodules()")
            end
        end)
    end

    if ExecutorCapabilities.GetNilInstances then
        pcall(function()
            for _, s in ipairs(getnilinstances()) do
                addScript(s, "getnilinstances()")
            end
        end)
    end

    return collected
end

-- ============================================================
-- DECOMPILATION ENGINE
-- ============================================================
local function DecompileScript(scriptObj)
    local result = nil
    
    if ExecutorCapabilities.Decompile then
        pcall(function()
            local r = decompile(scriptObj)
            if r and #r > 10 and not r:match("^%-%-") then result = r end
        end)
    end
    
    if not result and ExecutorCapabilities.Decompile then
        pcall(function()
            local r = decompile(scriptObj, true)
            if r and #r > 10 and not r:match("^%-%-") then result = r end
        end)
    end
    
    if not result then
        pcall(function()
            local src = scriptObj.Source
            if src and #src > 10 then result = "-- SOURCE EXTRACTED\n" .. src end
        end)
    end
    
    if not result then
        result = "-- DECOMPILE FAILED (Protected Bytecode)\n-- Class: " .. scriptObj.ClassName .. "\n-- Name: " .. scriptObj.Name
        ScanStatistics.ByStatus.Protected = ScanStatistics.ByStatus.Protected + 1
    end
    
    return result
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
            "=== UNIVERSAL SCRIPT SCAN: %s ===\n" ..
            "=== PART %d ===\n" ..
            "=== Game ID: %d ===\n" ..
            "=== Executor: %s ===\n" ..
            "=== Date: %s ===\n" ..
            "====================================\n\n",
            GameInfo.Name,
            filePart,
            GameInfo.PlaceId,
            ExecutorType,
            os.date("%Y-%m-%d %H:%M:%S")
        )
        pcall(function() writefile(path, header) end)
        currentFileSize = #header
        State.CurrentFile = path
        State.FileParts = filePart
    end
    
    pcall(function() appendfile(State.CurrentFile, chunk) end)
    currentFileSize = currentFileSize + #chunk
end

local function InitializeFile()
    filePart = 1
    State.CurrentFile = GetFilePath(1)
    local header = string.format(
        "=== UNIVERSAL SCRIPT SCAN: %s ===\n" ..
        "=== PART 1 ===\n" ..
        "=== Game ID: %d ===\n" ..
        "=== Executor: %s ===\n" ..
        "=== Date: %s ===\n" ..
        "====================================\n\n",
        GameInfo.Name,
        GameInfo.PlaceId,
        ExecutorType,
        os.date("%Y-%m-%d %H:%M:%S")
    )
    pcall(function() writefile(State.CurrentFile, header) end)
    currentFileSize = #header
    State.FileParts = 1
end

-- ============================================================
-- UI LABELS
-- ============================================================
local StatusLabel = { Set = function() end }
local TimeLabel = { Set = function() end }
local FileLabel = { Set = function() end }
local CountLabel = { Set = function() end }
local SuccessLabel = { Set = function() end }

-- ============================================================
-- SAFE UI UPDATE
-- ============================================================
local function SafeUpdateUI(status, time, success, file, count)
    task.spawn(function()
        pcall(function()
            if status then StatusLabel:Set(status) end
            if time then TimeLabel:Set(time) end
            if success then SuccessLabel:Set(success) end
            if file then FileLabel:Set(file) end
            if count then CountLabel:Set(count) end
        end)
    end)
    task.wait() -- Yield to let UI render
end

-- ============================================================
-- SCANNER ENGINE — RUNS ON SEPARATE THREAD
-- ============================================================
local function RunScanner()
    -- Run on a separate thread so UI doesn't freeze
    task.spawn(function()
        if State.IsScanning then
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({Title = "Busy", Content = "Scanner is already running!", Duration = 3})
            end
            return
        end

        if not ExecutorCapabilities.WriteFile or not ExecutorCapabilities.AppendFile then
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({Title = "Error", Content = "Executor does not support file I/O.", Duration = 5})
            end
            return
        end

        State.IsScanning = true
        State.IsPaused = false
        State.Processed = 0
        State.Decompiled = 0
        State.Failed = 0
        State.StartTime = tick()
        
        ScanStatistics.ByType = { Script = 0, LocalScript = 0, ModuleScript = 0, Other = 0 }
        ScanStatistics.BySource = { Game = 0, Executor = 0, Nil = 0, Loaded = 0 }
        ScanStatistics.ByStatus = { Decompiled = 0, Protected = 0, TimedOut = 0, Error = 0 }

        SafeUpdateUI("Status: Initializing bypass...", "Time Remaining: --:--")
        task.wait(0.5)

        SafeUpdateUI("Status: Collecting all scripts...")
        task.wait(0.5)
        
        local allScripts = CollectEverything()
        State.TotalScripts = #allScripts
        
        SafeUpdateUI(nil, nil, nil, nil, "Total Scripts Found: " .. State.TotalScripts)
        
        if State.TotalScripts == 0 then
            SafeUpdateUI("Status: No scripts found!")
            State.IsScanning = false
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({Title = "Alert", Content = "No scripts detected.", Duration = 4})
            end
            getgenv().ScannerRunning = false
            return
        end

        SafeUpdateUI("Status: Initializing file system...")
        InitializeFile()
        SafeUpdateUI(nil, nil, nil, "Save Location: " .. State.CurrentFile)
        task.wait(0.5)

        SafeUpdateUI("Status: Scanning...")
        
        local scanSuccess, scanErr = pcall(function()
            for i = 1, State.TotalScripts do
                -- Check pause
                while State.IsPaused do
                    task.wait(0.5)
                    if not State.IsScanning then return end
                end
                
                if not State.IsScanning then break end
                
                local data = allScripts[i]
                local scriptObj = data.Object
                local entry = ""
                local didDecompile = false
                
                local name = data.Name or "Unknown"
                local className = data.Class or "Unknown"
                local disabled = data.Disabled and " [DISABLED]" or ""
                
                local decompiled = DecompileScript(scriptObj)
                if not decompiled:match("^%-%-") then
                    didDecompile = true
                    State.Decompiled = State.Decompiled + 1
                    ScanStatistics.ByStatus.Decompiled = ScanStatistics.ByStatus.Decompiled + 1
                end
                
                entry = string.format(
                    "\n%s\n" ..
                    "SCRIPT: %s%s\n" ..
                    "CLASS: %s\n" ..
                    "SOURCE: %s\n" ..
                    "STATUS: %s\n" ..
                    "%s\n" ..
                    "%s\n\n",
                    string.rep("=", 60),
                    name,
                    disabled,
                    className,
                    data.Source or "Unknown",
                    didDecompile and "✅ DECOMPILED" or "❌ PROTECTED",
                    string.rep("=", 60),
                    decompiled
                )
                
                if not didDecompile then
                    State.Failed = State.Failed + 1
                end
                
                table.insert(writeBuffer, entry)
                bufferSize = bufferSize + #entry
                
                if bufferSize >= MAX_BUFFER_SIZE then
                    FlushBuffer()
                end
                
                State.Processed = i
                
                -- Update UI every 5 scripts — using task.spawn to keep UI alive
                if i % 5 == 0 then
                    local elapsed = tick() - State.StartTime
                    local remaining = 0
                    if State.Processed > 0 and elapsed > 0 then
                        local rate = State.Processed / elapsed
                        if rate > 0 then remaining = (State.TotalScripts - State.Processed) / rate end
                    end
                    if remaining < 0 then remaining = 0 end
                    
                    local mins = math.floor(remaining / 60)
                    local secs = math.floor(remaining % 60)
                    local percent = math.floor((State.Processed / State.TotalScripts) * 100)
                    
                    SafeUpdateUI(
                        string.format("Scanning: %d%% (%d/%d)", percent, State.Processed, State.TotalScripts),
                        string.format("Time Remaining: %02d:%02d", mins, secs),
                        string.format("Decompiled: %d | Protected: %d", State.Decompiled, State.Failed)
                    )
                end
                
                -- Yield to prevent thread starvation
                if i % 10 == 0 then
                    task.wait(0.01)
                end
                task.wait()
            end
        end)

        -- Final flush
        FlushBuffer()
        pcall(function()
            appendfile(State.CurrentFile, "\n" .. string.rep("=", 60) .. "\n")
            appendfile(State.CurrentFile, "SCAN COMPLETE\n")
            appendfile(State.CurrentFile, string.format("Total: %d | Decompiled: %d | Protected: %d\n", State.TotalScripts, State.Decompiled, State.Failed))
            appendfile(State.CurrentFile, string.rep("=", 60) .. "\n")
        end)

        State.IsScanning = false
        SafeUpdateUI("Status: COMPLETE!", "Time Remaining: 00:00", string.format("Decompiled: %d | Protected: %d", State.Decompiled, State.Failed))
        
        if Rayfield and Rayfield.Notify then
            Rayfield:Notify({
                Title = "Scan Complete!",
                Content = string.format("%d scripts decompiled out of %d", State.Decompiled, State.TotalScripts),
                Duration = 6
            })
        end
        
        getgenv().ScannerRunning = false
    end)
end

-- ============================================================
-- BUILD UI
-- ============================================================
if Rayfield and Rayfield.CreateWindow then
    local Window = Rayfield:CreateWindow({
        Name = "Universal Script Scanner v3.3",
        LoadingTitle = "Initializing Bypass Engine",
        LoadingSubtitle = "Bypassing Anti-Scan Protections...",
        ConfigurationSaving = { Enabled = false },
        KeySystem = false
    })

    local MainTab = Window:CreateTab("Scanner", 4483362458)

    MainTab:CreateParagraph({
        Title = "Game Info",
        Content = string.format("Name: %s\nID: %d\nCreator: %s\nExecutor: %s",
            GameInfo.Name, GameInfo.PlaceId, GameInfo.Creator, ExecutorType)
    })

    MainTab:CreateDivider()

    StatusLabel = MainTab:CreateLabel("Status: Ready")
    TimeLabel = MainTab:CreateLabel("Time Remaining: --:--")
    FileLabel = MainTab:CreateLabel("Save Location: Not started")
    CountLabel = MainTab:CreateLabel("Total Scripts Found: 0")
    SuccessLabel = MainTab:CreateLabel("Decompiled: 0 | Protected: 0")

    MainTab:CreateDivider()

    MainTab:CreateButton({
        Name = "🚀 Start Full Scan",
        Callback = RunScanner
    })

    MainTab:CreateButton({
        Name = "⏸️ Toggle Pause",
        Callback = function()
            if not State.IsScanning then
                Rayfield:Notify({Title = "Info", Content = "No scan is running.", Duration = 2})
                return
            end
            State.IsPaused = not State.IsPaused
            SafeUpdateUI(State.IsPaused and "Status: PAUSED" or "Status: Resuming...")
            Rayfield:Notify({
                Title = State.IsPaused and "Paused" or "Resumed",
                Content = State.IsPaused and "Scan paused. Click again to resume." or "Scan resumed.",
                Duration = 2
            })
        end
    })

    MainTab:CreateButton({
        Name = "⏹️ Stop Scan",
        Callback = function()
            if not State.IsScanning then
                Rayfield:Notify({Title = "Info", Content = "No scan is running.", Duration = 2})
                return
            end
            State.IsScanning = false
            State.IsPaused = false
            SafeUpdateUI("Status: STOPPED")
            Rayfield:Notify({Title = "Stopped", Content = "Scan stopped. Partial results saved.", Duration = 3})
            getgenv().ScannerRunning = false
        end
    })

    Rayfield:Notify({
        Title = "Scanner Ready",
        Content = string.format("Loaded. Game: %s | Executor: %s", GameInfo.Name, ExecutorType),
        Duration = 4
    })

    SafeUpdateUI("Status: Ready. Press 'Start Full Scan' to begin.")

else
    print("========================================")
    print("  UNIVERSAL SCRIPT SCANNER v3.3")
    print("  [NO GUI] Rayfield failed to load")
    print("  Using console output only")
    print("========================================")
    print("Game: " .. GameInfo.Name)
    print("Executor: " .. ExecutorType)
    print("")
    print("Type: RunScanner() to start")
    print("========================================")
    
    _G.RunScanner = RunScanner
    
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Scanner Ready (Console Mode)",
            Text = "Type RunScanner() in console to start",
            Duration = 5
        })
    end)
end

print("[Scanner] v3.3 loaded successfully.")
print("[Scanner] Game: " .. GameInfo.Name)
print("[Scanner] Executor: " .. ExecutorType)

-- ============================================================
-- CLEANUP
-- ============================================================
game:GetService("RunService").Heartbeat:Connect(function()
    -- Keep alive
end)

task.delay(2, function()
    pcall(function()
        getgenv().ScannerRunning = false
    end)
end)
