--!nocheck
-- ============================================
-- ADVANCED SCANNER + AUTO-SAVE 50MB FILES
-- ============================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")
local LP = Players.LocalPlayer

-- Load Rayfield
local Rayfield = nil
pcall(function() Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))() end)
if not Rayfield then
    pcall(function() Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))() end)
end
if not Rayfield then return end

-- State
local State = {}
State.Scanner_Dropdown = nil
State.Batches = {}
State.ScanCoreScripts = false
State.IsScanning = false

-- ============================================
-- BATCH SCANNER LOGIC (Standard 3500 lines)
-- ============================================
local MAX_BATCH_LINES = 3500

local function copyBatchToClipboard(batchName)
    if batchName == "None" then return end
    local batchNum = tonumber(string.match(batchName, "%d+"))
    if batchNum and State.Batches[batchNum] then
        if setclipboard then
            setclipboard(State.Batches[batchNum])
            Rayfield:Notify({Title = "Copied", Content = batchName .. " copied to clipboard!", Duration = 3})
        else
            print(State.Batches[batchNum])
        end
    end
end

local function scanGameForScripts()
    if State.IsScanning then return end
    State.IsScanning = true
    
    task.spawn(function()
        State.Batches = {}
        local currentBatchArray = {}
        local currentBatchLines = 0
        local currentBatchCount = 1
        local totalScriptsScanned = 0
        local yieldCounter = 0

        if not decompile then
            Rayfield:Notify({Title = "Error", Content = "No decompile()", Duration = 3})
            State.IsScanning = false
            return
        end

        Rayfield:Notify({Title = "Scanning", Content = "Scanning scripts...", Duration = 3})

        local descendants = game:GetDescendants()
        for _, obj in ipairs(descendants) do
            yieldCounter = yieldCounter + 1
            if yieldCounter % 50 == 0 then task.wait() end

            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                local fullName = obj:GetFullName()
                local isCore = string.find(fullName, "CoreGui") or string.find(fullName, "RobloxScript")
                if not (isCore and not State.ScanCoreScripts) then
                    local decompSuccess, source = pcall(function() return decompile(obj) end)
                    if decompSuccess and source then
                        totalScriptsScanned = totalScriptsScanned + 1
                        local scriptEntry = "=== " .. fullName .. " ===\n" .. source .. "\n\n"
                        local _, lines = string.gsub(scriptEntry, "\n", "")
                        lines = lines + 1
                        
                        if currentBatchLines + lines > MAX_BATCH_LINES then
                            State.Batches[currentBatchCount] = table.concat(currentBatchArray, "")
                            currentBatchCount = currentBatchCount + 1
                            currentBatchArray = {}
                            currentBatchLines = 0
                        end
                        table.insert(currentBatchArray, scriptEntry)
                        currentBatchLines = currentBatchLines + lines
                    end
                end
            end
        end

        if #currentBatchArray > 0 then
            State.Batches[currentBatchCount] = table.concat(currentBatchArray, "")
        end

        local batchOptions = {"None"}
        for i = 1, #State.Batches do
            local batchName = "Batch " .. tostring(i)
            local lineCount = #string.split(State.Batches[i], "\n")
            table.insert(batchOptions, batchName .. " (" .. tostring(lineCount) .. " lines)")
        end

        pcall(function()
            if State.Scanner_Dropdown then
                State.Scanner_Dropdown:Refresh(batchOptions, true)
            end
        end)
        
        print("done")
        Rayfield:Notify({Title = "Done", Content = "Scanned " .. totalScriptsScanned .. " scripts.", Duration = 5})
        State.IsScanning = false
    end)
end

local function saveBatchesToFile()
    if #State.Batches == 0 then return end
    if not writefile then return end
    local fullContent = ""
    for i = 1, #State.Batches do
        fullContent = fullContent .. State.Batches[i] .. "\n\n--- BATCH BREAK ---\n\n"
    end
    pcall(function() writefile("Game_Scan_Batches.txt", fullContent) end)
    Rayfield:Notify({Title = "Saved", Content = "Saved to workspace folder.", Duration = 5})
end

-- ============================================
-- AUTO-SAVE 50MB FILES LOGIC
-- ============================================
local MAX_FILE_CHARS = 50000000 -- 50MB

local function scanAndAutoSave()
    if State.IsScanning then return end
    State.IsScanning = true
    
    task.spawn(function()
        local currentArray = {}
        local currentSize = 0
        local fileCount = 1
        local totalItems = 0
        local yieldCounter = 0

        if not decompile then
            Rayfield:Notify({Title = "Error", Content = "No decompile()", Duration = 3})
            State.IsScanning = false
            return
        end
        
        if not writefile then
            Rayfield:Notify({Title = "Error", Content = "No writefile()", Duration = 3})
            State.IsScanning = false
            return
        end

        Rayfield:Notify({Title = "Scanning", Content = "Auto-saving 50MB files. Do not close the game.", Duration = 5})

        local descendants = game:GetDescendants()
        for _, obj in ipairs(descendants) do
            yieldCounter = yieldCounter + 1
            -- Yield every 25 items to prevent UI from freezing
            if yieldCounter % 25 == 0 then
                task.wait()
            end

            local fullName = obj:GetFullName()
            local className = obj.ClassName
            local entry = ""
            
            -- 1. If it's a script, decompile it
            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                local isCore = string.find(fullName, "CoreGui") or string.find(fullName, "RobloxScript")
                if not (isCore and not State.ScanCoreScripts) then
                    local decompSuccess, source = pcall(function() return decompile(obj) end)
                    if decompSuccess and source then
                        totalItems = totalItems + 1
                        entry = "--- SCRIPT: " .. fullName .. " (" .. className .. ") ---\n" .. source .. "\n\n"
                    end
                end
            -- 2. If it's an Instance, dump its properties
            else
                totalItems = totalItems + 1
                local props = {}
                
                if obj:IsA("BasePart") then
                    table.insert(props, "Pos: " .. tostring(obj.Position))
                    table.insert(props, "Size: " .. tostring(obj.Size))
                elseif obj:IsA("ValueBase") then
                    table.insert(props, "Value: " .. tostring(obj.Value))
                elseif obj:IsA("Sound") then
                    table.insert(props, "SoundId: " .. tostring(obj.SoundId))
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    table.insert(props, "Texture: " .. tostring(obj.Texture))
                elseif obj:IsA("TextButton") or obj:IsA("TextLabel") then
                    table.insert(props, "Text: " .. tostring(obj.Text))
                end
                
                local propString = ""
                if #props > 0 then
                    propString = " | " .. table.concat(props, " | ")
                end
                entry = "--- INSTANCE: " .. fullName .. " (" .. className .. ")" .. propString .. " ---\n"
            end
            
            -- Check if adding this entry exceeds 50MB
            if entry ~= "" then
                local entryLength = #entry
                
                if currentSize + entryLength > MAX_FILE_CHARS then
                    -- Save current file
                    local fileData = table.concat(currentArray, "")
                    pcall(function() writefile("Scan_Part_" .. tostring(fileCount) .. ".txt", fileData) end)
                    
                    -- Reset for next file
                    currentArray = {}
                    currentSize = 0
                    fileCount = fileCount + 1
                end
                
                table.insert(currentArray, entry)
                currentSize = currentSize + entryLength
            end
        end

        -- Save the final remaining file
        if #currentArray > 0 then
            local fileData = table.concat(currentArray, "")
            pcall(function() writefile("Scan_Part_" .. tostring(fileCount) .. ".txt", fileData) end)
        end

        print("done")
        Rayfield:Notify({Title = "Done", Content = "Scan complete! Saved " .. fileCount .. " 50MB files to workspace.", Duration = 5})
        State.IsScanning = false
    end)
end

-- ============================================
-- UI SETUP
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "Auto-Save Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabScanner = Window:CreateTab("Scanner", 4483362458)

TabScanner:CreateSection("Auto-Save Full Decompile")
TabScanner:CreateButton({
    Name = "Scan Everything (Auto-Save 50MB Files)",
    Callback = function()
        scanAndAutoSave()
    end
})

TabScanner:CreateSection("Standard Batch Scan (3500 lines)")
TabScanner:CreateButton({
    Name = "Scan Client Scripts (Batches)",
    Callback = function()
        scanGameForScripts()
    end
})

State.Scanner_Dropdown = TabScanner:CreateDropdown({
    Name = "Select Batch",
    Options = {"None"},
    CurrentOption = "None",
    Flag = "BatchDropdown",
    Callback = function(Value)
        copyBatchToClipboard(Value)
    end
})

TabScanner:CreateButton({
    Name = "Save Batches to Single File",
    Callback = function()
        saveBatchesToFile()
    end
})

TabScanner:CreateSection("Scanner Settings")
TabScanner:CreateToggle({
    Name = "Scan Roblox CoreScripts",
    CurrentValue = false,
    Flag = "ScanCore",
    Callback = function(Value)
        State.ScanCoreScripts = Value
    end
})

TabScanner:CreateSection("System")
TabScanner:CreateButton({
    Name = "Unload Script",
    Callback = function()
        Rayfield:Destroy()
    end
})

Rayfield:Notify({
    Title = "Game Scanner",
    Content = "Loaded successfully! Press RightCtrl to toggle UI.",
    Duration = 3
})
