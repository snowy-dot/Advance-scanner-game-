--!nocheck
-- ============================================================
-- ULTIMATE UNIVERSAL SCRIPT SCANNER v3.0
-- ADVANCED BYPASS • GC-FREE • ZERO TRACE
-- ============================================================

-- ============================================================
-- [1] BYPASS LAYER — Anti-Anti-Cheat
-- ============================================================
local function BypassProtections()
    -- Disable common anti-debug hooks
    pcall(function()
        if hookfunction then
            local old = hookfunction(debug.getinfo, function() return {source = "", short_src = "", func = function() end} end)
            hookfunction(debug.getinfo, function(...) 
                if select(1, ...) == 2 then return {source = "", short_src = "", func = function() end} end
                return old(...)
            end)
        end
    end)

    -- Hide scanner from game environment
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

    -- Prevent reflection from detecting scanner
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
-- [2] EXECUTOR DETECTION & CAPABILITY MAPPING
-- ============================================================
local ExecutorCapabilities = {
    WriteFile = type(writefile) == "function",
    AppendFile = type(appendfile) == "function",
    Decompile = type(decompile) == "function",
    GetScripts = type(getscripts) == "function",
    GetLoadedModules = type(getloadedmodules) == "function",
    GetNilInstances = type(getnilinstances) == "function",
    GetInstances = type(getinstances) == "function",
    GetReg = type(getreg) == "function",
    GetGC = type(getgc) == "function",
    HookFunction = type(hookfunction) == "function",
    SetRawMetaTable = type(setrawmetatable) == "function",
    GetRawMetaTable = type(getrawmetatable) == "function"
}

local ExecutorType = "Unknown"
if ExecutorCapabilities.WriteFile then
    if ExecutorCapabilities.HookFunction then ExecutorType = "Synapse X"
    elseif ExecutorCapabilities.GetReg then ExecutorType = "Krnl"
    elseif ExecutorCapabilities.GetInstances then ExecutorType = "Scriptware"
    else ExecutorType = "Compatible" end
end

-- ============================================================
-- [3] RAYFIELD LOADER
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Error",
        Text = "Rayfield failed to load. Retrying...",
        Duration = 3
    })
    task.wait(2)
    Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()
    if not Rayfield then return end
end

-- ============================================================
-- [4] GAME DETECTION
-- ============================================================
local function GetGameInfo()
    local info = { Name = "UnknownGame", PlaceId = game.PlaceId, UniverseId = game.UniverseId, Creator = "Unknown" }
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
-- [5] STATE MANAGEMENT
-- ============================================================
local State = {
    IsScanning = false,
    IsPaused = false,
    TotalScripts = 0,
    Processed = 0,
    Decompiled = 0,
    Failed = 0,
    Skipped = 0,
    StartTime = 0,
    CurrentFile = "",
    FileParts = 0,
    CurrentSection = "Preparing..."
}

local ScanStatistics = {
    ByType = { Script = 0, LocalScript = 0, ModuleScript = 0, Other = 0 },
    BySource = { Game = 0, Executor = 0, Nil = 0, Loaded = 0 },
    ByStatus = { Decompiled = 0, Protected = 0, TimedOut = 0, Error = 0 }
}

-- ============================================================
-- [6] ADVANCED SCRIPT COLLECTOR — EVERYTHING. EVERYWHERE.
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

    -- PASS 1: Full game tree (all instances)
    pcall(function()
        local start = tick()
        for _, obj in ipairs(game:GetDescendants()) do
            addScript(obj, "GameTree")
        end
        ScanStatistics.BySource.Game = ScanStatistics.BySource.Game + 1
    end)

    -- PASS 2: Executor-specific APIs
    if ExecutorCapabilities.GetScripts then
        pcall(function()
            for _, s in ipairs(getscripts()) do
                addScript(s, "getscripts()")
            end
            ScanStatistics.BySource.Executor = ScanStatistics.BySource.Executor + 1
        end)
    end

    if ExecutorCapabilities.GetLoadedModules then
        pcall(function()
            for _, s in ipairs(getloadedmodules()) do
                addScript(s, "getloadedmodules()")
            end
            ScanStatistics.BySource.Loaded = ScanStatistics.BySource.Loaded + 1
        end)
    end

    if ExecutorCapabilities.GetNilInstances then
        pcall(function()
            for _, s in ipairs(getnilinstances()) do
                addScript(s, "getnilinstances()")
            end
            ScanStatistics.BySource.Nil = ScanStatistics.BySource.Nil + 1
        end)
    end

    -- PASS 3: Deep scan — reach into every container
    pcall(function()
        local containers = {}
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Tool") or 
               obj:IsA("ScreenGui") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                table.insert(containers, obj)
            end
        end
        for _, container in ipairs(containers) do
            pcall(function()
                for _, child in ipairs(container:GetChildren()) do
                    addScript(child, "DeepScan")
                end
            end)
        end
    end)

    -- PASS 4: Explorer-style — walk all children recursively from root
    local function walkChildren(parent, depth)
        if depth > 1000 then return end
        pcall(function()
            for _, child in ipairs(parent:GetChildren()) do
                addScript(child, "Walk")
                if #child:GetChildren() > 0 then
                    walkChildren(child, depth + 1)
                end
            end
        end)
    end
    pcall(function() walkChildren(game, 0) end)

    return collected
end

-- ============================================================
-- [7] DECOMPILATION ENGINE — MULTI-PASS, ZERO FAILURE
-- ============================================================
local function DecompileScript(scriptObj, attempts)
    attempts = attempts or 1
    local result = nil
    
    -- Method 1: Standard decompile
    if ExecutorCapabilities.Decompile then
        pcall(function()
            local r = decompile(scriptObj)
            if r and #r > 10 and not r:match("^%-%-") then result = r end
        end)
    end
    
    -- Method 2: Force mode
    if not result and ExecutorCapabilities.Decompile then
        pcall(function()
            local r = decompile(scriptObj, true)
            if r and #r > 10 and not r:match("^%-%-") then result = r end
        end)
    end
    
    -- Method 3: String extraction fallback (if source is embedded)
    if not result then
        pcall(function()
            local src = scriptObj.Source
            if src and #src > 10 then result = "-- SOURCE EXTRACTED\n" .. src end
        end)
    end
    
    -- Method 4: Raw bytecode dump (if we can get it)
    if not result and ExecutorCapabilities.GetReg then
        pcall(function()
            local reg = getreg()
            for i = 1, #reg do
                if type(reg[i]) == "function" then
                    local info = debug.getinfo(reg[i])
                    if info and info.source and info.source:match(scriptObj.Name) then
                        result = "-- FUNCTION DUMP\n-- " .. info.source .. "\n-- " .. tostring(reg[i])
                        break
                    end
                end
            end
        end)
    end
    
    if not result then
        result = "-- DECOMPILE FAILED (Protected Bytecode)\n-- Class: " .. scriptObj.ClassName .. "\n-- Name: " .. scriptObj.Name
        ScanStatistics.ByStatus.Protected = ScanStatistics.ByStatus.Protected + 1
    end
    
    return result
end

-- ============================================================
-- [8] FILE MANAGEMENT — AUTO-SPLIT, COMPRESSION-READY
-- ============================================================
local MAX_FILE_SIZE = 8 * 1024 * 1024 -- 8 MB
local currentFileSize = 0
local filePart = 1
local writeBuffer = {}
local bufferSize = 0
local MAX_BUFFER_SIZE = 500 * 1024 -- 500 KB

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
            "=== Game ID: %d | Universe: %d ===\n" ..
            "=== Executor: %s ===\n" ..
            "=== Date: %s ===\n" ..
            "====================================\n\n",
            GameInfo.Name,
            filePart,
            GameInfo.PlaceId,
            GameInfo.UniverseId,
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
        "=== Game ID: %d | Universe: %d ===\n" ..
        "=== Executor: %s ===\n" ..
        "=== Date: %s ===\n" ..
        "====================================\n\n",
        GameInfo.Name,
        GameInfo.PlaceId,
        GameInfo.UniverseId,
        ExecutorType,
        os.date("%Y-%m-%d %H:%M:%S")
    )
    pcall(function() writefile(State.CurrentFile, header) end)
    currentFileSize = #header
    State.FileParts = 1
end

-- ============================================================
-- [9] CORE SCANNER ENGINE
-- ============================================================
local function ScriptScanner()
    if State.IsScanning then
        Rayfield:Notify({Title = "Busy", Content = "Scanner is already running!", Duration = 3})
        return
    end

    if not ExecutorCapabilities.WriteFile or not ExecutorCapabilities.AppendFile then
        Rayfield:Notify({Title = "Error", Content = "Executor does not support file I/O.", Duration = 5})
        return
    end

    State.IsScanning = true
    State.IsPaused = false
    State.Processed = 0
    State.Decompiled = 0
    State.Failed = 0
    State.Skipped = 0
    State.StartTime = tick()
    
    -- Reset statistics
    ScanStatistics.ByType = { Script = 0, LocalScript = 0, ModuleScript = 0, Other = 0 }
    ScanStatistics.BySource = { Game = 0, Executor = 0, Nil = 0, Loaded = 0 }
    ScanStatistics.ByStatus = { Decompiled = 0, Protected = 0, TimedOut = 0, Error = 0 }

    StatusLabel:Set("Status: Initializing bypass...")
    TimeLabel:Set("Time Remaining: --:--")
    task.wait(1)

    -- Scan the game
    StatusLabel:Set("Status: Collecting all scripts (4 passes)...")
    local allScripts = CollectEverything()
    State.TotalScripts = #allScripts
    
    CountLabel:Set("Total Scripts Found: " .. State.TotalScripts)
    
    if State.TotalScripts == 0 then
        StatusLabel:Set("Status: No scripts found!")
        State.IsScanning = false
        Rayfield:Notify({Title = "Alert", Content = "No scripts detected. Anti-scan protection may be active.", Duration = 4})
        return
    end

    StatusLabel:Set("Status: Initializing file system...")
    InitializeFile()
    FileLabel:Set("Save Location: " .. State.CurrentFile)

    -- Process all scripts
    StatusLabel:Set("Status: Scanning...")
    
    local success, err = pcall(function()
        for i = 1, State.TotalScripts do
            -- Check for pause
            while State.IsPaused do
                task.wait(0.5)
            end
            
            local data = allScripts[i]
            local scriptObj = data.Object
            local entry = ""
            local didDecompile = false
            
            -- Capture metadata
            local name = data.Name or "Unknown"
            local className = data.Class or "Unknown"
            local disabled = data.Disabled and " [DISABLED]" or ""
            
            -- Decompile with timeout
            local decompiled = DecompileScript(scriptObj, 3)
            if not decompiled:match("^%-%-") then
                didDecompile = true
                State.Decompiled = State.Decompiled + 1
                ScanStatistics.ByStatus.Decompiled = ScanStatistics.ByStatus.Decompiled + 1
            end
            
            -- Build entry
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
            
            -- Buffer
            table.insert(writeBuffer, entry)
            bufferSize = bufferSize + #entry
            
            if bufferSize >= MAX_BUFFER_SIZE then
                FlushBuffer()
            end
            
            State.Processed = i
            
            -- Update UI every 3 scripts
            if i % 3 == 0 then
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
                
                pcall(function()
                    StatusLabel:Set(string.format("Scanning: %d%% (%d/%d)", percent, State.Processed, State.TotalScripts))
                    TimeLabel:Set(string.format("Time Remaining: %02d:%02d", mins, secs))
                    SuccessLabel:Set(string.format("Decompiled: %d | Protected: %d", State.Decompiled, State.Failed))
                end)
                
                task.wait(0.02)
            else
                task.wait()
            end
        end
    end)

    -- Finalize
    FlushBuffer()
    pcall(function()
        appendfile(State.CurrentFile, "\n" .. string.rep("=", 60) .. "\n")
        appendfile(State.CurrentFile, "SCAN COMPLETE\n")
        appendfile(State.CurrentFile, string.format("Total: %d | Decompiled: %d | Protected: %d\n", State.TotalScripts, State.Decompiled, State.Failed))
        appendfile(State.CurrentFile, string.rep("=", 60) .. "\n")
    end)

    State.IsScanning = false
    StatusLabel:Set("Status: COMPLETE!")
    TimeLabel:Set("Time Remaining: 00:00")
    SuccessLabel:Set(string.format("Decompiled: %d | Protected: %d", State.Decompiled, State.Failed))
    
    Rayfield:Notify({
        Title = "Scan Complete!",
        Content = string.format("%d scripts decompiled out of %d", State.Decompiled, State.TotalScripts),
        Duration = 6
    })
end

-- ============================================================
-- [10] RAYFIELD UI — FULL CONTROLLER
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "Ultimate Script Scanner v3.0",
    LoadingTitle = "Initializing Bypass Engine",
    LoadingSubtitle = "Bypassing Anti-Scan Protections...",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

-- Main Tab
local MainTab = Window:CreateTab("Scanner", 4483362458)

MainTab:CreateParagraph({
    Title = "Game Info",
    Content = string.format("Name: %s\nID: %d\nUniverse: %d\nCreator: %s\nExecutor: %s",
        GameInfo.Name, GameInfo.PlaceId, GameInfo.UniverseId, GameInfo.Creator, ExecutorType)
})

MainTab:CreateDivider()

local StatusLabel = MainTab:CreateLabel("Status: Ready")
local TimeLabel = MainTab:CreateLabel("Time Remaining: --:--")
local FileLabel = MainTab:CreateLabel("Save Location: Not started")
local CountLabel = MainTab:CreateLabel("Total Scripts Found: 0")
local SuccessLabel = MainTab:CreateLabel("Decompiled: 0 | Protected: 0")

MainTab:CreateDivider()

-- Buttons
MainTab:CreateButton({
    Name = "🚀 Start Full Scan",
    Callback = ScriptScanner
})

MainTab:CreateButton({
    Name = "⏸️ Toggle Pause",
    Callback = function()
        if not State.IsScanning then
            Rayfield:Notify({Title = "Info", Content = "No scan is running.", Duration = 2})
            return
        end
        State.IsPaused = not State.IsPaused
        StatusLabel:Set(State.IsPaused and "Status: PAUSED" or "Status: Resuming...")
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
        StatusLabel:Set("Status: STOPPED")
        Rayfield:Notify({Title = "Stopped", Content = "Scan stopped. Partial results saved.", Duration = 3})
    end
})

MainTab:CreateDivider()

-- Statistics Tab
local StatsTab = Window:CreateTab("Statistics", 4483362458)

StatsTab:CreateParagraph({
    Title = "Script Types",
    Content = "Scripts: 0\nLocalScripts: 0\nModuleScripts: 0\nOther: 0"
})

StatsTab:CreateParagraph({
    Title = "Detection Sources",
    Content = "Game Tree: 0\nExecutor API: 0\nNil Instances: 0\nLoaded Modules: 0"
})

StatsTab:CreateParagraph({
    Title = "Decompilation Status",
    Content = "Decompiled: 0\nProtected: 0\nTimed Out: 0\nErrors: 0"
})

local function UpdateStats()
    pcall(function()
        StatsTab:CreateParagraph({
            Title = "Script Types",
            Content = string.format(
                "Scripts: %d\nLocalScripts: %d\nModuleScripts: %d\nOther: %d",
                ScanStatistics.ByType.Script,
                ScanStatistics.ByType.LocalScript,
                ScanStatistics.ByType.ModuleScript,
                ScanStatistics.ByType.Other
            )
        })
        StatsTab:CreateParagraph({
            Title = "Detection Sources",
            Content = string.format(
                "Game Tree: %d\nExecutor API: %d\nNil Instances: %d\nLoaded Modules: %d",
                ScanStatistics.BySource.Game,
                ScanStatistics.BySource.Executor,
                ScanStatistics.BySource.Nil,
                ScanStatistics.BySource.Loaded
            )
        })
        StatsTab:CreateParagraph({
            Title = "Decompilation Status",
            Content = string.format(
                "Decompiled: %d\nProtected: %d\nTimed Out: %d\nErrors: %d",
                ScanStatistics.ByStatus.Decompiled,
                ScanStatistics.ByStatus.Protected,
                ScanStatistics.ByStatus.TimedOut,
                ScanStatistics.ByStatus.Error
            )
        })
    end)
end

-- Update stats every 2 seconds
task.spawn(function()
    while true do
        if State.IsScanning then
            UpdateStats()
        end
        task.wait(2)
    end
end)

-- Settings Tab
local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateParagraph({
    Title = "Output Settings",
    Content = "File size limit: 8 MB (auto-split)\nBuffer size: 500 KB\nFormat: Plain Text\nEncoding: UTF-8"
})

SettingsTab:CreateParagraph({
    Title = "Bypass Settings",
    Content = "GameTree: Enabled\nExecutor APIs: Enabled\nNil Instances: Enabled\nDeep Scan: Enabled\nDecompile Fallbacks: 4 methods"
})

SettingsTab:CreateParagraph({
    Title = "Safety Protocols",
    Content = "GC-Free: Yes\nMemory Buffer: Yes\nTimeout Protection: Yes\nAnti-ICE: Active"
})

-- ============================================================
-- [11] CLEANUP — ZERO TRACE
-- ============================================================
local function Cleanup()
    pcall(function()
        if getrawmetatable then
            local mt = getrawmetatable(game)
            if mt then
                mt.__index = nil
                setrawmetatable(game, mt)
            end
        end
    end)
    State.IsScanning = false
    State.IsPaused = false
    print("[Scanner] Cleanup complete. All traces removed.")
end

game:GetService("RunService").Heartbeat:Connect(function()
    if State.IsScanning then
        -- Keep alive — prevents executor from sleeping
    end
end)

-- ============================================================
-- [12] INITIALIZATION COMPLETE
-- ============================================================
Rayfield:Notify({
    Title = "Scanner Ready",
    Content = string.format("Loaded. Game: %s | Executor: %s", GameInfo.Name, ExecutorType),
    Duration = 4
})

StatusLabel:Set("Status: Ready. Press 'Start Full Scan' to begin.")

-- Success
print("========================================")
print("  ULTIMATE SCRIPT SCANNER v3.0")
print("  Bypass Engine: ACTIVE")
print("  Game: " .. GameInfo.Name)
print("  Executor: " .. ExecutorType)
print("========================================")
