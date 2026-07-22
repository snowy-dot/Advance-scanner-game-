--!nocheck
-- ============================================
-- ADVANCED SCANNER + 50MB DIVISIONS
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

-- 50MB Division State
local MAX_DIV_CHARS = 50000000 -- 50MB in characters
State.Divisions = {} -- Will hold the final 50MB strings
State.DivisionArrays = {} -- Will hold the arrays before joining
State.CurrentDiv = 1
State.CurrentDivSize = 0

-- ============================================
-- BATCH SCANNER LOGIC (3500 lines)
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
            Rayfield:Notify({Title = "Error", Content = "setclipboard not supported.", Duration = 3})
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
            Rayfield:Notify({Title = "Error", Content = "Your executor does not support decompile()", Duration = 3})
            State.IsScanning = false
            return
        end

        Rayfield:Notify({Title = "Scanning", Content = "Scanning scripts into batches...", Duration = 3})

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
            local optionName = batchName .. " (" .. tostring(lineCount) .. " lines)"
            table.insert(batchOptions, optionName)
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
    if #State.Batches == 0 then
        Rayfield:Notify({Title = "Error", Content = "No data found. Scan first.", Duration = 3})
        return
    end
    if not writefile then return end
    local fullContent = ""
    for i = 1, #State.Batches do
        fullContent = fullContent .. State.Batches[i] .. "\n\n--- BATCH BREAK ---\n\n"
    end
    pcall(function() writefile("Game_Scan_Batches.txt", fullContent) end)
    Rayfield:Notify({Title = "Saved", Content = "Saved to workspace folder.", Duration = 5})
end

-- ============================================
-- 50MB DIVISION SCAN LOGIC
-- ============================================
local function scanFullGame50MB()
    if State.IsScanning then return end
    State.IsScanning = true
    
    task.spawn(function()
        -- Reset Division State
        State.Divisions = {}
        State.DivisionArrays = {{}}
        State.CurrentDiv = 1
        State.CurrentDivSize = 0
        
        local totalItemsScanned = 0
        local yieldCounter = 0

        if not decompile then
            Rayfield:Notify({Title = "Error", Content = "Your executor does not support decompile()", Duration = 3})
            State.IsScanning = false
            return
        end

        Rayfield:Notify({Title = "Scanning", Content = "Decompiling EVERYTHING into 50MB Divisions. Please wait...", Duration = 5})

        local descendants = game:GetDescendants()
        for _, obj in ipairs(descendants) do
            yieldCounter = yieldCounter + 1
            -- Yield every 25 items to prevent freezing
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
                        totalItemsScanned = totalItemsScanned + 1
                        entry = "--- SCRIPT: " .. fullName .. " (" .. className .. ") ---\n" .. source .. "\n\n"
                    end
                end
            -- 2. If it's an Instance, dump its properties
            else
                totalItemsScanned = totalItemsScanned + 1
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
            
            -- Add to 50MB Division
            if entry ~= "" then
                local entryLength = #entry
                
                -- If adding this exceeds 50MB, finalize current division and move to next
                if State.CurrentDivSize + entryLength > MAX_DIV_CHARS then
                    State.Divisions[State.CurrentDiv] = table.concat(State.DivisionArrays[State.CurrentDiv], "")
                    State.CurrentDiv = State.CurrentDiv + 1
                    State.DivisionArrays[State.CurrentDiv] = {}
                    State.CurrentDivSize = 0
                end
                
                table.insert(State.DivisionArrays[State.CurrentDiv], entry)
                State.CurrentDivSize = State.CurrentDivSize + entryLength
            end
        end

        -- Finalize the last division
        if #State.DivisionArrays[State.CurrentDiv] > 0 then
            State.Divisions[State.CurrentDiv] = table.concat(State.DivisionArrays[State.CurrentDiv], "")
        end

        -- Update the Division Dropdown
        local divOptions = {"None"}
        for i = 1, #State.Divisions do
            local sizeMB = math.floor((#State.Divisions[i] / 1024) / 1024)
            table.insert(divOptions, "Division " .. tostring(i) .. " (" .. tostring(sizeMB) .. " MB)")
        end
        pcall(function()
            if State.DivisionDropdown then
                State.DivisionDropdown:Refresh(divOptions, true)
            end
        end)

        print("done")
        Rayfield:Notify({Title = "Done", Content = "Scan complete! " .. totalItemsScanned .. " items in " .. #State.Divisions .. " Divisions.", Duration = 5})
        State.IsScanning = false
    end)
end

local function copyDivisionToClipboard(divName)
    if divName == "None" then return end
    local divNum = tonumber(string.match(divName, "%d+"))
    if divNum and State.Divisions[divNum] then
        if setclipboard then
            setclipboard(State.Divisions[divNum])
            Rayfield:Notify({Title = "Copied", Content = divName .. " copied to clipboard!", Duration = 3})
        else
            print(State.Divisions[divNum])
        end
    end
end

local function saveDivisionsToFile()
    if #State.Divisions == 0 then
        Rayfield:Notify({Title = "Error", Content = "No data found. Run 50MB Scan first.", Duration = 3})
        return
    end
    if not writefile then return end
    for i = 1, #State.Divisions do
        pcall(function() writefile("Division_" .. tostring(i) .. "_50MB.txt", State.Divisions[i]) end)
    end
    Rayfield:Notify({Title = "Saved", Content = "All Divisions saved to workspace folder.", Duration = 5})
end

-- ============================================
-- UI SETUP
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "50MB Division Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabScanner = Window:CreateTab("Scanner", 4483362458)

TabScanner:CreateSection("50MB Full Game Decompile")
TabScanner:CreateButton({
    Name = "Scan Full Game (50MB Divisions)",
    Callback = function()
        scanFullGame50MB()
    end
})

State.DivisionDropdown = TabScanner:CreateDropdown({
    Name = "Select Division (Up to 50MB)",
    Options = {"None"},
    CurrentOption = "None",
    Flag = "DivDropdown",
    Callback = function(Value)
        copyDivisionToClipboard(Value)
    end
})

TabScanner:CreateButton({
    Name = "Save All Divisions to Files",
    Callback = function()
        saveDivisionsToFile()
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
