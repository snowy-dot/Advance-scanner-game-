--!nocheck
-- ============================================
-- ADVANCED SCANNER + FULL GAME DECOMPILE (FIXED UI)
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
-- FULL GAME DECOMPILE & BATCH LOGIC
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

local function scanFullGame()
    if State.IsScanning then return end
    State.IsScanning = true
    
    task.spawn(function()
        State.Batches = {}
        local currentBatchArray = {}
        local currentBatchLines = 0
        local currentBatchCount = 1
        local totalItemsScanned = 0
        local yieldCounter = 0

        if not decompile then
            Rayfield:Notify({Title = "Error", Content = "Your executor does not support decompile()", Duration = 3})
            State.IsScanning = false
            return
        end

        Rayfield:Notify({Title = "Scanning", Content = "Decompiling full game. This may take a minute...", Duration = 5})

        local descendants = game:GetDescendants()
        for _, obj in ipairs(descendants) do
            yieldCounter = yieldCounter + 1
            -- Yield every 50 items to prevent UI from freezing/disappearing
            if yieldCounter % 50 == 0 then
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
                
                -- Gather key properties based on class (Optimized for memory)
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
            
            -- Add to batch
            if entry ~= "" then
                local _, lines = string.gsub(entry, "\n", "")
                lines = lines + 1
                
                if currentBatchLines + lines > MAX_BATCH_LINES then
                    State.Batches[currentBatchCount] = table.concat(currentBatchArray, "")
                    currentBatchCount = currentBatchCount + 1
                    currentBatchArray = {}
                    currentBatchLines = 0
                end
                
                table.insert(currentBatchArray, entry)
                currentBatchLines = currentBatchLines + lines
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
        
        Rayfield:Notify({Title = "Scan Complete", Content = "Decompiled " .. totalItemsScanned .. " items into " .. #State.Batches .. " batches.", Duration = 5})
        State.IsScanning = false
    end)
end

local function saveAllToSingleFile()
    if #State.Batches == 0 then
        Rayfield:Notify({Title = "Error", Content = "No data found. Scan the game first.", Duration = 3})
        return
    end
    if not writefile then
        Rayfield:Notify({Title = "Error", Content = "Your executor does not support writefile()", Duration = 3})
        return
    end
    local fullFileArray = {}
    for i = 1, #State.Batches do
        table.insert(fullFileArray, State.Batches[i])
    end
    local fullContent = table.concat(fullFileArray, "\n\n--- BATCH BREAK ---\n\n")
    local fileName = "💀💀Full_Game_Decompile💀💀.txt"
    pcall(function() writefile(fileName, fullContent) end)
    Rayfield:Notify({Title = "Saved", Content = "Saved all data to " .. fileName, Duration = 6})
end

-- ============================================
-- UI SETUP
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "Full Decompile Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabScanner = Window:CreateTab("Scanner", 4483362458)

TabScanner:CreateSection("Full Game Decompile")
TabScanner:CreateButton({
    Name = "Scan Full Game (Scripts + Everything)",
    Callback = function()
        scanFullGame()
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
    Name = "Save All Batches to Single File",
    Callback = function()
        saveAllToSingleFile()
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
