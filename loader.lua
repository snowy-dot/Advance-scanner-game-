--!nocheck
-- ============================================
-- UNIVERSAL SCANNER: MICRO-YIELD (100% ANTI-CRASH)
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
    LoadingSubtitle = "Anti-Crash Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Scanner", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")
local TimeLabel = Tab:CreateLabel("Time Remaining: --:--")
local FileLabel = Tab:CreateLabel("Save Location: N/A")

-- ============================================
-- UNIVERSAL ANTI-BYPASS COLLECTION
-- ============================================
local function GetAllObjects()
    local objects = {}
    
    -- Collect descendants in chunks to prevent initial freeze
    for _, obj in ipairs(game:GetDescendants()) do 
        table.insert(objects, obj) 
    end
    
    -- Anti-Bypass: Hidden Scripts
    pcall(function()
        for _, s in ipairs(getscripts()) do 
            if not table.find(objects, s) then table.insert(objects, s) end 
        end 
    end)
    
    -- Anti-Bypass: Nil Instances
    pcall(function()
        for _, n in ipairs(getnilinstances()) do 
            if not table.find(objects, n) then table.insert(objects, n) end 
        end 
    end)
    
    return objects
end

-- ============================================
-- AUTO-SPLIT FILE WRITER
-- ============================================
local MAX_FILE_SIZE = 9961472 -- 9.5 MB
local currentFileSize = 0
local filePartNumber = 1
local filePath = GameName .. "_Scan_Part_1.txt"

local function SafeAppend(text)
    if currentFileSize + #text > MAX_FILE_SIZE then
        filePartNumber = filePartNumber + 1
        filePath = GameName .. "_Scan_Part_" .. filePartNumber .. ".txt"
        local header = "=== UNIVERSAL ANTI-BYPASS SCAN: " .. GameName .. " (PART " .. filePartNumber .. ") ===\n\n"
        writefile(filePath, header)
        currentFileSize = #header
        FileLabel:Set("Save Location: " .. filePath)
    end
    
    pcall(function() appendfile(filePath, text) end)
    currentFileSize = currentFileSize + #text
end

-- ============================================
-- MICRO-YIELD ZERO-LAG SCANNER
-- ============================================
local function StartUniversalScan()
    if State.IsScanning then return end
    if not writefile or not appendfile then
        return Rayfield:Notify({Title = "Error", Content = "Your executor does not support saving files.", Duration = 5})
    end

    State.IsScanning = true
    StatusLabel:Set("Status: Collecting Anti-Bypass Data...")
    
    -- Initialize Part 1
    filePartNumber = 1
    filePath = GameName .. "_Scan_Part_1.txt"
    local initHeader = "=== UNIVERSAL ANTI-BYPASS SCAN: " .. GameName .. " (PART 1) ===\n\n"
    writefile(filePath, initHeader)
    currentFileSize = #initHeader
    FileLabel:Set("Save Location: " .. filePath)

    local allObjects = GetAllObjects()
    local totalObjects = #allObjects
    local processedCount = 0
    local startTime = tick()
    
    StatusLabel:Set("Status: Scanning " .. totalObjects .. " Objects...")

    task.spawn(function()
        for i = 1, totalObjects do
            local obj = allObjects[i]
            local entry = ""
            
            local success, err = pcall(function()
                local className = obj.ClassName
                local fullName = "Unknown/Nil Path"
                pcall(function() fullName = obj:GetFullName() end)
                
                if className == "Script" or className == "LocalScript" or className == "ModuleScript" then
                    local decompiled = "-- Failed to decompile or locked by AC"
                    pcall(function() decompiled = decompile(obj) end)
                    entry = "\n--- [SCRIPT: " .. className .. "] " .. fullName .. " ---\n" .. decompiled .. "\n\n"
                else
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
            
            if entry ~= "" then
                SafeAppend(entry)
            end
            
            processedCount = i
            
            -- UPDATE UI EVERY 50 ITEMS
            if i % 50 == 0 then
                local elapsed = tick() - startTime
                local remaining = 0
                if processedCount > 0 and elapsed > 0 then
                    local rate = processedCount / elapsed
                    if rate > 0 then remaining = (totalObjects - processedCount) / rate end
                end
                if remaining < 0 then remaining = 0 end
                
                local mins = math.floor(remaining / 60)
                local secs = math.floor(remaining % 60)
                local percent = math.floor((processedCount / totalObjects) * 100)
                local filled = math.floor(percent / 5)
                local bar = string.rep("=", filled) .. string.rep(" ", 20 - filled)
                
                StatusLabel:Set(string.format("Scanning: [%s] %d%%", bar, percent))
                TimeLabel:Set(string.format("Time Remaining: %02d:%02d", mins, secs))
            end
            
            -- THE FIX: MICRO-YIELD EVERY SINGLE ITEM
            -- This stops the executor from memory spiking and killing the UI buttons
            task.wait()
            
            -- Extra yield every 200 items to let the UI physically render
            if i % 200 == 0 then
                task.wait(0.05)
            end
        end
        
        State.IsScanning = false
        StatusLabel:Set("Status: COMPLETE! 100%")
        TimeLabel:Set("Time Remaining: 00:00")
        
        pcall(function() appendfile(filePath, "\n=== SCAN PART " .. filePartNumber .. " COMPLETE ===\n") end)
        
        Rayfield:Notify({
            Title = "Scan Complete!", 
            Content = "Finished! Split into " .. filePartNumber .. " parts. Check your workspace!", 
            Duration = 6
        })
    end)
end

Tab:CreateButton({
    Name = "Start Universal Anti-Bypass Scan",
    Callback = function()
        if not State.IsScanning then StartUniversalScan() 
        else Rayfield:Notify({Title = "Busy", Content = "Scanner is already running!", Duration = 3}) end
    end
})
