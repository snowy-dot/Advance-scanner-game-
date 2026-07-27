--!nocheck
-- ============================================================
-- ULTIMATE UNIVERSAL SCRIPT SCANNER v3.5
-- FINAL FIX: UI persistence + auto-recovery + anti-crash
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
-- STATE
-- ============================================================
local ScanState = {
    IsScanning = false,
    IsPaused = false,
    TotalScripts = 0,
    Processed = 0,
    Decompiled = 0,
    Failed = 0,
    StartTime = 0,
    CurrentFile = "",
    FileParts = 0,
    StatusText = "Ready",
    TimeText = "--:--",
    SuccessText = "Decompiled: 0 | Protected: 0",
    CountText = "Total Scripts Found: 0",
    FileText = "Save Location: Not started"
}

-- ============================================================
-- UI LABELS (Stored globally)
-- ============================================================
local StatusLabel = { Set = function() end }
local TimeLabel = { Set = function() end }
local FileLabel = { Set = function() end }
local CountLabel = { Set = function() end }
local SuccessLabel = { Set = function() end }

-- ============================================================
-- UI WINDOW REFERENCE — For recovery
-- ============================================================
local UIWindow = nil
local UIMainTab = nil
local UIScreenGui = nil
local UIExists = false

-- ============================================================
-- RECREATE UI — Restores buttons if they disappear
-- ============================================================
local function RecreateUI()
    pcall(function()
        -- Destroy old UI if it exists
        if UIScreenGui and UIScreenGui.Parent then
            UIScreenGui:Destroy()
        end
        if UIWindow and UIWindow.Destroy then
            UIWindow:Destroy()
        end
    end)
    
    UIExists = false
    UIWindow = nil
    UIMainTab = nil
    UIScreenGui = nil
    
    -- Wait a moment
    task.wait(0.5)
    
    -- Build new UI
    BuildUI()
    
    -- Notify
    if Rayfield and Rayfield.Notify then
        Rayfield:Notify({
            Title = "UI Rebuilt",
            Content = "The UI has been restored.",
            Duration = 3
        })
    end
end

-- ============================================================
-- UI UPDATER — Every 0.3 seconds
-- ============================================================
local function UIUpdater()
    task.spawn(function()
        while true do
            task.wait(0.3)
            pcall(function()
                -- Check if UI still exists
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

-- ============================================================
-- UI RECOVERY WATCHER — Detects if UI disappears
-- ============================================================
local function UIWatcher()
    task.spawn(function()
        local lastCheck = tick()
        while true do
            task.wait(2)
            pcall(function()
                -- Check if UI still exists
                if UIExists and UIScreenGui and UIScreenGui.Parent == nil then
                    -- UI was destroyed or removed
                    print("[Scanner] UI disappeared! Rebuilding...")
                    UIExists = false
                    RecreateUI()
                end
                
                -- Also check if Rayfield window still exists
                if UIExists and UIWindow and not UIWindow.Parent then
                    -- Rayfield window was destroyed
                    print("[Scanner] UI Window disappeared! Rebuilding...")
                    UIExists = false
                    RecreateUI()
                end
            end)
        end
    end)
end

-- ============================================================
-- BUILD UI — Called once, and again if UI disappears
-- ============================================================
function BuildUI()
    if not Rayfield or not Rayfield.CreateWindow then
        print("[Scanner] Rayfield not available. No UI to build.")
        return
    end
    
    pcall(function()
        UIWindow = Rayfield:CreateWindow({
            Name = "Universal Script Scanner v3.5",
            LoadingTitle = "Initializing Bypass Engine",
            LoadingSubtitle = "Bypassing Anti-Scan Protections...",
            ConfigurationSaving = { Enabled = false },
            KeySystem = false
        })

        -- Get the ScreenGui from Rayfield's window
        pcall(function()
            -- Rayfield stores its ScreenGui in the window object
            -- We need to find it
            for _, gui in ipairs(game.CoreGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name == "Rayfield" then
                    UIScreenGui = gui
                    -- Force it to stay on top
                    gui.ResetOnSpawn = false
                    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                    gui.DisplayOrder = 999
                    -- Set ignore gui inset
                    gui.IgnoreGuiInset = true
                    print("[Scanner] UI locked to top layer (DisplayOrder: 999)")
                end
            end
        end)

        UIMainTab = UIWindow:CreateTab("Scanner", 4483362458)

        UIMainTab:CreateParagraph({
            Title = "Game Info",
            Content = string.format("Name: %s\nID: %d\nCreator: %s\nExecutor: %s",
                GameInfo.Name, GameInfo.PlaceId, GameInfo.Creator, ExecutorType)
        })

        UIMainTab:CreateDivider()

        StatusLabel = UIMainTab:CreateLabel("Status: Ready")
        TimeLabel = UIMainTab:CreateLabel("Time Remaining: --:--")
        FileLabel = UIMainTab:CreateLabel("Save Location: Not started")
        CountLabel = UIMainTab:CreateLabel("Total Scripts Found: 0")
        SuccessLabel = UIMainTab:CreateLabel("Decompiled: 0 | Protected: 0")

        UIMainTab:CreateDivider()

        UIMainTab:CreateButton({
            Name = "🚀 Start Full Scan",
            Callback = RunScanner
        })

        UIMainTab:CreateButton({
            Name = "⏸️ Toggle Pause",
            Callback = function()
                if not ScanState.IsScanning then
                    Rayfield:Notify({Title = "Info", Content = "No scan is running.", Duration = 2})
                    return
                end
                ScanState.IsPaused = not ScanState.IsPaused
                ScanState.StatusText = ScanState.IsPaused and "Status: PAUSED" or "Status: Resuming..."
                Rayfield:Notify({
                    Title = ScanState.IsPaused and "Paused" or "Resumed",
                    Content = ScanState.IsPaused and "Scan paused. Click again to resume." or "Scan resumed.",
                    Duration = 2
                })
            end
        })

        UIMainTab:CreateButton({
            Name = "⏹️ Stop Scan",
            Callback = function()
                if not ScanState.IsScanning then
                    Rayfield:Notify({Title = "Info", Content = "No scan is running.", Duration = 2})
                    return
                end
                ScanState.IsScanning = false
                ScanState.IsPaused = false
                ScanState.StatusText = "STOPPED"
                Rayfield:Notify({Title = "Stopped", Content = "Scan stopped. Partial results saved.", Duration = 3})
                getgenv().ScannerRunning = false
            end
        })

        UIMainTab:CreateDivider()

        UIMainTab:CreateButton({
            Name = "🔄 Reset UI (If buttons disappear)",
            Callback = function()
                RecreateUI()
            end
        })

        Rayfield:Notify({
            Title = "Scanner Ready",
            Content = string.format("Loaded. Game: %s | Executor: %s", GameInfo.Name, ExecutorType),
            Duration = 4
        })

        ScanState.StatusText = "Ready. Press 'Start Full Scan' to begin."
        UIExists = true
        
        print("[Scanner] UI built successfully.")
        print("[Scanner] UI locked to top layer. Press ESC won't hide it.")
        print("[Scanner] If buttons disappear, click 'Reset UI'.")
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
        result = "-- DECOMPILE FAILED (Protected Bytecode)"
        ScanState.Failed = ScanState.Failed + 1
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
        ScanState.CurrentFile = path
        ScanState.FileParts = filePart
        ScanState.FileText = "Save Location: " .. path
    end
    
    pcall(function() appendfile(ScanState.CurrentFile, chunk) end)
    currentFileSize = currentFileSize + #chunk
end

local function InitializeFile()
    filePart = 1
    ScanState.CurrentFile = GetFilePath(1)
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
    pcall(function() writefile(ScanState.CurrentFile, header) end)
    currentFileSize = #header
    ScanState.FileParts = 1
    ScanState.FileText = "Save Location: " .. ScanState.CurrentFile
end

-- ============================================================
-- SCANNER ENGINE
-- ============================================================
function RunScanner()
    task.spawn(function()
        if ScanState.IsScanning then
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

        ScanState.IsScanning = true
        ScanState.IsPaused = false
        ScanState.Processed = 0
        ScanState.Decompiled = 0
        ScanState.Failed = 0
        ScanState.StartTime = tick()
        ScanState.StatusText = "Initializing..."
        ScanState.TimeText = "--:--"
        
        task.wait(0.5)

        ScanState.StatusText = "Collecting scripts..."
        local allScripts = CollectEverything()
        ScanState.TotalScripts = #allScripts
        ScanState.CountText = "Total Scripts Found: " .. ScanState.TotalScripts
        
        if ScanState.TotalScripts == 0 then
            ScanState.StatusText = "No scripts found!"
            ScanState.IsScanning = false
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({Title = "Alert", Content = "No scripts detected.", Duration = 4})
            end
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
                local entry = ""
                local didDecompile = false
                
                local name = data.Name or "Unknown"
                local className = data.Class or "Unknown"
                local disabled = data.Disabled and " [DISABLED]" or ""
                
                local decompiled = DecompileScript(scriptObj)
                if not decompiled:match("^%-%-") then
                    didDecompile = true
                    ScanState.Decompiled = ScanState.Decompiled + 1
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
                
                table.insert(writeBuffer, entry)
                bufferSize = bufferSize + #entry
                
                if bufferSize >= MAX_BUFFER_SIZE then
                    FlushBuffer()
                end
                
                ScanState.Processed = i
                
                -- Update state every 5 scripts
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
                    ScanState.SuccessText = string.format("Decompiled: %d | Protected: %d", ScanState.Decompiled, ScanState.Failed)
                end
                
                task.wait()
            end
        end)

        FlushBuffer()
        pcall(function()
            appendfile(ScanState.CurrentFile, "\n" .. string.rep("=", 60) .. "\n")
            appendfile(ScanState.CurrentFile, "SCAN COMPLETE\n")
            appendfile(ScanState.CurrentFile, string.format("Total: %d | Decompiled: %d | Protected: %d\n", ScanState.TotalScripts, ScanState.Decompiled, ScanState.Failed))
            appendfile(ScanState.CurrentFile, string.rep("=", 60) .. "\n")
        end)

        ScanState.IsScanning = false
        ScanState.StatusText = "COMPLETE!"
        ScanState.TimeText = "Time Remaining: 00:00"
        ScanState.SuccessText = string.format("Decompiled: %d | Protected: %d", ScanState.Decompiled, ScanState.Failed)
        
        if Rayfield and Rayfield.Notify then
            Rayfield:Notify({
                Title = "Scan Complete!",
                Content = string.format("%d scripts decompiled out of %d", ScanState.Decompiled, ScanState.TotalScripts),
                Duration = 6
            })
        end
        
        getgenv().ScannerRunning = false
    end)
end

-- ============================================================
-- START EVERYTHING
-- ============================================================

-- Build the UI
BuildUI()

-- Start UI updater
UIUpdater()

-- Start UI recovery watcher
UIWatcher()

-- Console output
print("========================================")
print("  UNIVERSAL SCRIPT SCANNER v3.5")
print("  UI PERSISTENCE ENABLED")
print("  Auto-recovery: ACTIVE")
print("  DisplayOrder: 999 (Always on top)")
print("========================================")
print("Game: " .. GameInfo.Name)
print("Executor: " .. ExecutorType)
print("")
print("If UI disappears:")
print("  1. Press ESC then click back to Roblox")
print("  2. Click the 'Reset UI' button in the scanner")
print("  3. UI will auto-recover in 2-3 seconds")
print("========================================")

-- ============================================================
-- CLEANUP
-- ============================================================
task.delay(2, function()
    pcall(function()
        getgenv().ScannerRunning = false
    end)
end)
