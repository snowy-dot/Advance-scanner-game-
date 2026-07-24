--!nocheck
-- ============================================
-- ADVANCED UNIVERSAL SCANNER: ANTI-BYPASS + ZERO-LAG
-- ============================================
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then return end

local GameName = "UnknownGame"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then GameName = string.gsub(info.Name, "[^%w_]", "_") end
end)

local State = { IsScanning = false }

local Window = Rayfield:CreateWindow({
    Name = "Universal Scanner",
    LoadingTitle = "Initializing Stealth Scanner",
    LoadingSubtitle = "Anti-Bypass Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Scanner", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")
local TimeLabel = Tab:CreateLabel("Time Remaining: --:--")

-- ============================================
-- UNIVERSAL ANTI-BYPASS COLLECTION
-- ============================================
local function GetAllObjects()
    local objects = {}
    
    -- 1. Standard Descendants (Models, Parts, Buildings)
    for _, obj in ipairs(game:GetDescendants()) do
        table.insert(objects, obj)
    end
    
    -- 2. Anti-Bypass: Grab Hidden Scripts (Executor API)
    pcall(function()
        for _, scriptObj in ipairs(getscripts()) do
            if not table.find(objects, scriptObj) then
                table.insert(objects, scriptObj)
            end
        end
    end)
    
    -- 3. Anti-Bypass: Grab Nil Instances (Destroyed but running memory)
    pcall(function()
        for _, nilObj in ipairs(getnilinstances()) do
            if not table.find(objects, nilObj) then
                table.insert(objects, nilObj)
            end
        end
    end)
    
    return objects
end

-- ============================================
-- SEQUENTIAL ZERO-LAG SCANNER
-- ============================================
local function StartUniversalScan()
    if State.IsScanning then return end
    if not writefile or not appendfile or not makefolder then
        return Rayfield:Notify({Title = "Error", Content = "Executor lacks file functions.", Duration = 5})
    end

    State.IsScanning = true
    StatusLabel:Set("Status: Collecting Anti-Bypass Data...")
    
    local folderName = "GameScannerExports"
    if not isfolder(folderName) then makefolder(folderName) end
    local filePath = folderName .. "/" .. GameName .. "_UniversalScan.txt"
    writefile(filePath, "=== UNIVERSAL ANTI-BYPASS SCAN: " .. GameName .. " ===\n\n")

    local allObjects = GetAllObjects()
    local totalObjects = #allObjects
    local processedCount = 0
    local startTime = tick()
    
    StatusLabel:Set("Status: Scanning " .. totalObjects .. " Objects...")

    -- Sequential Loop with Yielding (Fixes 99% stuck bug)
    task.spawn(function()
        for i = 1, totalObjects do
            local obj = allObjects[i]
            local entry = ""
            
            local success, err = pcall(function()
                local className = obj.ClassName
                local fullName = pcall(function() return obj:GetFullName() end) and obj:GetFullName() or "Unknown/Nil Path"
                
                -- If it's a script, decompile it
                if className == "Script" or className == "LocalScript" or className == "ModuleScript" then
                    local decompiled = "-- Failed to decompile or locked by AC"
                    pcall(function() decompiled = decompile(obj) end)
                    entry = "\n--- [SCRIPT: " .. className .. "] " .. fullName .. " ---\n" .. decompiled .. "\n\n"
                else
                    -- If it's a model/part, dump its properties
                    entry = "\n[" .. className .. "] " .. fullName .. "\n"
                    pcall(function() entry = entry .. "Name: " .. obj.Name .. "\n" end)
                    if obj:IsA("BasePart") then
                        pcall(function() 
                            entry = entry .. "Position: " .. tostring(obj.Position) .. "\n"
                            entry = entry .. "Size: " .. tostring(obj.Size) .. "\n"
                            entry = entry .. "Material: " .. tostring(obj.Material) .. "\n"
                        end)
                    elseif obj:IsA("Model") then
                        pcall(function() entry = entry .. "PrimaryPart: " .. tostring(obj.PrimaryPart) .. "\n" end)
                    end
                end
            end)
            
            -- Append to file directly (Safe Disk I/O)
            if entry ~= "" then
                pcall(function() appendfile(filePath, entry) end)
            end
            
            processedCount = i
            
            -- Update UI & Yield every 50 items to prevent 99% freeze and game lag
            if i % 50 == 0 then
                local elapsed = tick() - startTime
                local rate = processedCount / elapsed
                local remaining = (totalObjects - processedCount) / rate
                
                local mins = math.floor(remaining / 60)
                local secs = math.floor(remaining % 60)
                
                local percent = math.floor((processedCount / totalObjects) * 100)
                local filled = math.floor(percent / 5)
                local bar = string.rep("=", filled) .. string.rep(" ", 20 - filled)
                
                StatusLabel:Set(string.format("Scanning: [%s] %d%%", bar, percent))
                TimeLabel:Set(string.format("Time Remaining: %02d:%02d", mins, secs))
                
                -- THE FIX: Yield to executor to prevent timeout and UI crash
                task.wait()
            end
        end
        
        -- 100% Guaranteed Completion
        State.IsScanning = false
        StatusLabel:Set("Status: COMPLETE! 100%")
        TimeLabel:Set("Time Remaining: 00:00")
        Rayfield:Notify({Title = "Scan Complete!", Content = "Successfully bypassed and dumped " .. totalObjects .. " objects.", Duration = 6})
    end)
end

Tab:CreateButton({
    Name = "Start Universal Anti-Bypass Scan",
    Callback = function()
        if not State.IsScanning then StartUniversalScan() 
        else Rayfield:Notify({Title = "Busy", Content = "Scanner is already running!", Duration = 3}) end
    end
})
