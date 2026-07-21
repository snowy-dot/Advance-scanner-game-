--!nocheck
-- ============================================
-- ADVANCED BATCH GAME SCANNER
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
local MAX_BATCH_CHARS = 3000 -- Capped between 2500 and 3500

local function copyBatchToClipboard(batchName)
    if batchName == "None" then
        return
    end
    
    -- Extract batch number from string (e.g., "Batch 3" -> 3)
    local batchNum = tonumber(string.match(batchName, "%d+"))
    if batchNum and State.Batches[batchNum] then
        if setclipboard then
            setclipboard(State.Batches[batchNum])
            local notifyConfig = {
                Title = "Copied",
                Content = batchName .. " copied to clipboard!",
                Duration = 3
            }
            Rayfield:Notify(notifyConfig)
        else
            print(State.Batches[batchNum])
            local notifyConfig = {
                Title = "Error",
                Content = "setclipboard not supported. Printed to F9.",
                Duration = 3
            }
            Rayfield:Notify(notifyConfig)
        end
    end
end

local function scanGameForScripts()
    State.Batches = {}
    local currentBatch = ""
    local currentBatchCount = 1
    local scanFailed = false

    if not decompile then
        local notifyConfig = {
            Title = "Error",
            Content = "Your executor does not support decompile()",
            Duration = 3
        }
        Rayfield:Notify(notifyConfig)
        return
    end

    local scanNotifyConfig = {
        Title = "Scanning",
        Content = "Scanning all client scripts into batches...",
        Duration = 3
    }
    Rayfield:Notify(scanNotifyConfig)

    for _, obj in pairs(game:GetDescendants()) do
        -- Strictly scan LocalScripts and ModuleScripts (Ignores Server Scripts completely)
        if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            local success, source = pcall(function()
                return decompile(obj)
            end)
            
            if success and source then
                local scriptEntry = "=== " .. obj:GetFullName() .. " ===\n" .. source .. "\n\n"
                
                -- Check if adding this script exceeds the character limit for the current batch
                if string.len(currentBatch) + string.len(scriptEntry) > MAX_BATCH_CHARS then
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
                else
                    -- Add script to current batch
                    currentBatch = currentBatch .. scriptEntry
                end
            end
        end
    end

    -- If scan failed due to size
    if scanFailed then
        State.Batches = {}
        local dropdownConfig = {
            Options = {"None"},
            CurrentOption = "None",
            Flag = "BatchDropdown",
            Callback = function(Value)
                copyBatchToClipboard(Value)
            end
        }
        if State.Scanner_Dropdown then
            State.Scanner_Dropdown:Refresh(dropdownConfig.Options)
        end

        local errorConfig = {
            Title = "Scan Failed",
            Content = "game files is too big, cannot be scanned",
            Duration = 5
        }
        Rayfield:Notify(errorConfig)
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
        local charCount = string.len(State.Batches[i])
        local optionName = batchName .. " (" .. tostring(charCount) .. " chars)"
        table.insert(batchOptions, optionName)
    end

    -- Update the Dropdown
    if State.Scanner_Dropdown then
        State.Scanner_Dropdown:Refresh(batchOptions)
    end
    
    local completeConfig = {
        Title = "Scan Complete",
        Content = "Found " .. #State.Batches .. " batches. Select one to copy.",
        Duration = 4
    }
    Rayfield:Notify(completeConfig)
end

-- ============================================
-- UI SETUP
-- ============================================
local WindowConfig = {
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "Batch System",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
}
local Window = Rayfield:CreateWindow(WindowConfig)

local TabScanner = Window:CreateTab("Scanner", 4483362458)

local SectionConfig = {
    Name = "Batch Scanning System"
}
TabScanner:CreateSection(SectionConfig)

local ScanButtonConfig = {
    Name = "Scan All Client Scripts",
    Callback = function()
        scanGameForScripts()
    end
}
TabScanner:CreateButton(ScanButtonConfig)

local ScannerDropdownConfig = {
    Name = "Select Batch",
    Options = {"None"},
    CurrentOption = "None",
    Flag = "BatchDropdown",
    Callback = function(Value)
        copyBatchToClipboard(Value)
    end
}
State.Scanner_Dropdown = TabScanner:CreateDropdown(ScannerDropdownConfig)

local CopySelectedConfig = {
    Name = "Copy Selected Batch to Clipboard",
    Callback = function()
        -- Rayfield Dropdowns don't always have a getter, so the callback handles the copy.
        -- This button is here for UI clarity.
        local notifyConfig = {
            Title = "Info",
            Content = "Select a batch from the dropdown above to copy it.",
            Duration = 3
        }
        Rayfield:Notify(notifyConfig)
    end
}
TabScanner:CreateButton(CopySelectedConfig)

local UnloadConfig = {
    Name = "Unload Script",
    Callback = function()
        Rayfield:Destroy()
    end
}
TabScanner:CreateButton(UnloadConfig)

local NotifyConfig = {
    Title = "Game Scanner",
    Content = "Loaded successfully! Press RightCtrl to toggle UI.",
    Duration = 3
}
Rayfield:Notify(NotifyConfig)
