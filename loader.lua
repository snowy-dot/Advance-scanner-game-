--!nocheck
-- ============================================
-- ADVANCED BATCH GAME SCANNER (LINE CAP)
-- ============================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

-- Load Rayfield
local Rayfield = nil
pcall(function()
    local response = game:HttpGet('https://sirius.menu/rayfield')
    local func = loadstring(response)
    if func then
        Rayfield = func()
    end
end)

if not Rayfield then
    pcall(function()
        local response = game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua')
        local func = loadstring(response)
        if func then
            Rayfield = func()
        end
    end)
end

if not Rayfield then
    print("Rayfield failed to load")
    return
end

-- State
local State = {}
State.Scanner_Dropdown = nil
State.Batches = {}

-- ============================================
-- BATCH SCANNER LOGIC
-- ============================================
local MAX_BATCHES = 10
local MAX_BATCH_LINES = 3500 -- Capped at 3500 lines per batch

local function copyBatchToClipboard(batchName)
    if batchName == "None" then
        return
    end
    
    local batchNum = tonumber(string.match(batchName, "%d+"))
    if batchNum and State.Batches[batchNum] then
        if setclipboard then
            setclipboard(State.Batches[batchNum])
            Rayfield:Notify({
                Title = "Copied",
                Content = batchName .. " copied to clipboard!",
                Duration = 3
            })
        else
            print(State.Batches[batchNum])
            Rayfield:Notify({
                Title = "Error",
                Content = "setclipboard not supported. Printed to F9.",
                Duration = 3
            })
        end
    end
end

local function scanGameForScripts()
    State.Batches = {}
    local currentBatch = ""
    local currentBatchLines = 0
    local currentBatchCount = 1
    local scanFailed = false

    if not decompile then
        Rayfield:Notify({
            Title = "Error",
            Content = "Your executor does not support decompile()",
            Duration = 3
        })
        return
    end

    Rayfield:Notify({
        Title = "Scanning",
        Content = "Scanning all client scripts into batches...",
        Duration = 3
    })

    for _, obj in pairs(game:GetDescendants()) do
        if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            local success, source = pcall(function()
                return decompile(obj)
            end)
            
            if success and source then
                local scriptEntry = "=== " .. obj:GetFullName() .. " ===\n" .. source .. "\n\n"
                
                -- Calculate lines in this specific script
                local lines = #string.split(scriptEntry, "\n")
                
                -- Check if adding this script exceeds the line limit for the current batch
                if currentBatchLines + lines > MAX_BATCH_LINES then
                    -- Save the current batch
                    State.Batches[currentBatchCount] = currentBatch
                    currentBatchCount = currentBatchCount + 1
                    
                    -- Check if we exceeded the 10 batch limit
                    if currentBatchCount > MAX_BATCHES then
                        scanFailed = true
                        break
                    end
                    
                    -- Start a new batch with the current script
                    currentBatch = scriptEntry
                    currentBatchLines = lines
                else
                    -- Add script to current batch and increase line count
                    currentBatch = currentBatch .. scriptEntry
                    currentBatchLines = currentBatchLines + lines
                end
            end
        end
    end

    -- If scan failed due to size
    if scanFailed then
        State.Batches = {}
        if State.Scanner_Dropdown then
            State.Scanner_Dropdown:Refresh({"None"})
        end

        Rayfield:Notify({
            Title = "Scan Failed",
            Content = "game files is too big, cannot be scanned",
            Duration = 5
        })
        return
    end

    -- Save the final remaining batch if it has content
    if string.len(currentBatch) > 0 then
        State.Batches[currentBatchCount] = currentBatch
    end

    -- Build dropdown options for the UI
    local batchOptions = {"None"}
    for i = 1, #State.Batches do
        local batchName = "Batch " .. tostring(i)
        local lineCount = #string.split(State.Batches[i], "\n")
        local optionName = batchName .. " (" .. tostring(lineCount) .. " lines)"
        table.insert(batchOptions, optionName)
    end

    -- Update the Dropdown
    if State.Scanner_Dropdown then
        State.Scanner_Dropdown:Refresh(batchOptions)
    end
    
    Rayfield:Notify({
        Title = "Scan Complete",
        Content = "Found " .. #State.Batches .. " batches. Select one to copy.",
        Duration = 4
    })
end

-- ============================================
-- UI SETUP
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "Line Cap System",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabScanner = Window:CreateTab("Scanner", 4483362458)

TabScanner:CreateSection("Batch Scanning System")

TabScanner:CreateButton({
    Name = "Scan All Client Scripts",
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
    Name = "Copy Selected Batch to Clipboard",
    Callback = function()
        Rayfield:Notify({
            Title = "Info",
            Content = "Select a batch from the dropdown above to copy it.",
            Duration = 3
        })
    end
})

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
