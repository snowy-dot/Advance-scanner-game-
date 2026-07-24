--!nocheck
-- ============================================
-- ULTRA SCANNER: MULTI-THREAD + ANTI-CRASH + FULL DUMP
-- ============================================
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then return end

local GameName = "UnknownGame"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then GameName = string.gsub(info.Name, "[^%w_]", "_") end
end)

local State = { IsScanning = false }

local Window = Rayfield:CreateWindow({
    Name = "Ultra Game Scanner",
    LoadingTitle = "Initializing Scanner",
    LoadingSubtitle = "Multi-Thread Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Ultra Scanner", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")
local TimeLabel = Tab:CreateLabel("Time Remaining: --:--")

-- ============================================
-- ANTI-CRASH BUFFERED WRITER
-- ============================================
local WriteQueue = {}
local IsWriting = false

local function ProcessWriteQueue(filePath)
    if IsWriting then return end
    IsWriting = true
    task.spawn(function()
        while #WriteQueue > 0 do
            local chunk = table.remove(WriteQueue, 1)
            pcall(function() appendfile(filePath, chunk) end)
            task.wait(0.05) -- Yield slightly to prevent disk I/O crashes
        end
        IsWriting = false
    end)
end

-- ============================================
-- MULTI-THREADED SCAN LOGIC
-- ============================================
local function StartUltraScan()
    if State.IsScanning then return end
    if not writefile or not appendfile or not makefolder then
        return Rayfield:Notify({Title = "Error", Content = "Executor lacks file functions.", Duration = 5})
    end

    State.IsScanning = true
    
    -- Setup Folder & File
    local folderName = "GameScannerExports"
    if not isfolder(folderName) then makefolder(folderName) end
    local filePath = folderName .. "/" .. GameName .. "_UltraScan.txt"
    writefile(filePath, "=== ULTRA GAME SCAN: " .. GameName .. " ===\n\n")

    StatusLabel:Set("Status: Collecting Objects...")
    
    -- Collect EVERYTHING
    local allObjects = game:GetDescendants()
    local totalObjects = #allObjects
    local processedCount = 0
    local startTime = tick()
    
    -- Multi-threading setup (Simulates using device CPU cores to boost speed)
    local MAX_WORKERS = 20 
    local activeWorkers = 0
    local currentIndex = 1

    local function ProcessItem(obj)
        local entry = ""
        local className = obj.ClassName
        local fullName = obj:GetFullName()
        
        if className == "Script" or className == "LocalScript" or className == "ModuleScript" then
            local success, decompiled = pcall(function() return decompile(obj) end)
            entry = "\n--- [SCRIPT: " .. className .. "] " .. fullName .. " ---\n"
            if success and decompiled then
                entry = entry .. decompiled .. "\n\n"
            else
                entry = entry .. "-- Failed to decompile or locked.\n\n"
            end
        else
            -- Dump properties of models, parts, buildings, etc.
            entry = "\n[" .. className .. "] " .. fullName .. "\n"
            -- Safely grab a few common properties without crashing
            if pcall(function() return obj.Name end) then entry = entry .. "Name: " .. obj.Name .. "\n" end
            if obj:IsA("BasePart") then
                entry = entry .. "Position: " .. tostring(obj.Position) .. "\n"
                entry = entry .. "Size: " .. tostring(obj.Size) .. "\n"
                entry = entry .. "Material: " .. tostring(obj.Material) .. "\n"
            elseif obj:IsA("Model") then
                entry = entry .. "PrimaryPart: " .. tostring(obj.PrimaryPart) .. "\n"
            end
        end
        
        table.insert(WriteQueue, entry)
        processedCount = processedCount + 1
    end

    -- Worker Loop
    task.spawn(function()
        while currentIndex <= totalObjects do
            if activeWorkers < MAX_WORKERS then
                activeWorkers = activeWorkers + 1
                local objToProcess = allObjects[currentIndex]
                currentIndex = currentIndex + 1
                
                task.spawn(function()
                    local success, err = pcall(function()
                        ProcessItem(objToProcess)
                    end)
                    activeWorkers = activeWorkers - 1
                    
                    -- Update Progress & Time
                    if processedCount % 50 == 0 then
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
                        
                        -- Trigger disk write
                        if #WriteQueue > 0 then ProcessWriteQueue(filePath) end
                    end
                end)
            else
                task.wait() -- Yield if all workers are busy
            end
        end
        
        -- Wait for workers to finish
        while activeWorkers > 0 do task.wait(0.1) end
        
        -- Write remaining queue
        while #WriteQueue > 0 do 
            ProcessWriteQueue(filePath) 
            task.wait(0.1) 
        end
        
        -- Finish
        State.IsScanning = false
        StatusLabel:Set("Status: COMPLETE! 100%")
        TimeLabel:Set("Time Remaining: 00:00")
        Rayfield:Notify({Title = "Scan Complete!", Content = "Dumped " .. totalObjects .. " objects to file.", Duration = 6})
    end)
end

-- Button
Tab:CreateButton({
    Name = "Start Ultra Full Game Scan",
    Callback = function()
        if not State.IsScanning then
            StartUltraScan()
        else
            Rayfield:Notify({Title = "Busy", Content = "Scanner is already running!", Duration = 3})
        end
    end
})
