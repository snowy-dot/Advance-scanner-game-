--!nocheck
-- ============================================
-- ADVANCED SCANNER + ANTI-CRASH AUTO-SAVE
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

-- Get Game Name for File Saving
local GameName = "UnknownGame"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then
        GameName = string.gsub(info.Name, "[^%w_]", "_")
    end
end)

-- ============================================
-- UI ELEMENTS (Declared early to update progress)
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "Anti-Crash Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabScanner = Window:CreateTab("Scanner", 4483362458)

TabScanner:CreateSection("Auto-Save Full Decompile")
local ScanButton = TabScanner:CreateButton({
    Name = "Scan Everything (Auto-Save 50MB Files)",
    Callback = function() end -- Callback set later
})

local ProgressLabel = TabScanner:CreateParagraph({
    Name = "Progress",
    Content = "Progress: 0%"
})

TabScanner:CreateSection("Standard Batch Scan (3500 lines)")
local BatchButton = TabScanner:CreateButton({
    Name = "Scan Client Scripts (Batches)",
    Callback = function() end
})

State.Scanner_Dropdown = TabScanner:CreateDropdown({
    Name = "Select Batch",
    Options = {"None"},
    CurrentOption = "None",
    Flag = "BatchDropdown",
    Callback = function(Value) end
})

TabScanner:CreateButton({
    Name = "Save Batches to Single File",
    Callback = function()
        if #State.Batches == 0 then return end
        if not writefile then return end
        local fullContent = ""
        for i = 1, #State.Batches do
            fullContent = fullContent .. State.Batches[i] .. "\n\n--- BATCH BREAK ---\n\n"
        end
        pcall(function() writefile("Game_Scan_Batches.txt", fullContent) end)
        Rayfield:Notify({Title = "Saved", Content = "Saved to workspace folder.", Duration = 5})
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

-- ============================================
-- BATCH SCANNER LOGIC
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
State.Scanner_Dropdown.Callback = copyBatchToClipboard

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
        local totalItems = #game:GetDescendants()
        local currentIndex = 0

        if not decompile then
            Rayfield:Notify({Title = "Error", Content = "No decompile()", Duration = 3})
            State.IsScanning = false
            return
        end

        Rayfield:Notify({Title = "Scanning", Content = "Scanning scripts...", Duration = 3})

        local descendants = game:GetDescendants()
        for _, obj in ipairs(descendants) do
            currentIndex = currentIndex + 1
            yieldCounter = yieldCounter + 1
            if yieldCounter % 50 == 0 then
                task.wait()
                local percent = math.floor((currentIndex / totalItems) * 100)
                ProgressLabel:Set({Title = "Progress", Content = "Progress: " .. percent .. "%"})
            end

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
        
        ProgressLabel:Set({Title = "Progress", Content = "Progress: 100%"})
        print("done")
        Rayfield:Notify({Title = "Done", Content = "Scanned " .. totalScriptsScanned .. " scripts.", Duration = 5})
        State.IsScanning = false
    end)
end
BatchButton.Callback = scanGameForScripts

-- ============================================
-- AUTO-SAVE 50MB FILES LOGIC
-- ============================================
local MAX_FILE_CHARS = 50000000 -- 50MB in characters

local function scanAndAutoSave()
    if State.IsScanning then return end
    State.IsScanning = true
    
    task.spawn(function()
        local currentArray = {}
        local currentSize = 0
        local fileCount = 1
        local totalItems = #game:GetDescendants()
        local currentIndex = 0
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
        ProgressLabel:Set({Title = "Progress", Content = "Progress: 0%"})

        local descendants = game:GetDescendants()
        for _, obj in ipairs(descendants) do
            currentIndex = currentIndex + 1
            yieldCounter = yieldCounter + 1
            
            -- Aggressive yielding to prevent UI crash
            if yieldCounter % 25 == 0 then
                task.wait(0.05)
                local percent = math.floor((currentIndex / totalItems) * 100)
                ProgressLabel:Set({Title = "Progress", Content = "Progress: " .. percent .. "%"})
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
                        entry = "--- SCRIPT: " .. fullName .. " (" .. className .. ") ---\n" .. source .. "\n\n"
                    end
                end
            -- 2. If it's an Instance, dump its properties
            else
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
            
            -- Add to 50MB File
            if entry ~= "" then
                local entryLength = #entry
                
                if currentSize + entryLength > MAX_FILE_CHARS then
                    -- Save current 50MB file
                    local fileData = table.concat(currentArray, "")
                    local fileName = GameName .. "_" .. tostring(fileCount) .. ".txt"
                    pcall(function() writefile(fileName, fileData) end)
                    
                    -- Clear memory to prevent crash
                    currentArray = {}
                    currentSize = 0
                    fileCount = fileCount + 1
                    collectgarbage("collect")
                end
                
                table.insert(currentArray, entry)
                currentSize = currentSize + entryLength
            end
        end

        -- Save the final remaining file
        if #currentArray > 0 then
            local fileData = table.concat(currentArray, "")
            local fileName = GameName .. "_" .. tostring(fileCount) .. ".txt"
            pcall(function() writefile(fileName, fileData) end)
        end

        ProgressLabel:Set({Title = "Progress", Content = "Progress: 100%"})
        print("done")
        Rayfield:Notify({Title = "Done", Content = "Scan complete! Saved " .. fileCount .. " 50MB files to workspace.", Duration = 5})
        State.IsScanning = false
    end)
end
ScanButton.Callback = scanAndAutoSave

Rayfield:Notify({
    Title = "Game Scanner",
    Content = "Loaded successfully! Press RightCtrl to toggle UI.",
    Duration = 3
})
