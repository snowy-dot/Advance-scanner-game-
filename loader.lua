--!nocheck
-- ============================================
-- ADVANCED UNLIMITED BATCH GAME SCANNER (FIXED)
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
State.ScanCoreScripts = false
State.IsScanning = false

-- ============================================
-- BATCH SCANNER LOGIC
-- ============================================
local MAX_BATCH_LINES = 3500

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
    if State.IsScanning then
        return
    end
    State.IsScanning = true
    
    -- Run the scan in a separate thread so the UI doesn't freeze or yield
    task.spawn(function()
        State.Batches = {}
        local currentBatch = ""
        local currentBatchLines = 0
        local currentBatchCount = 1
        local totalScriptsScanned = 0
        local yieldCounter = 0

        if not decompile then
            Rayfield:Notify({
                Title = "Error",
                Content = "Your executor does not support decompile()",
                Duration = 3
            })
            State.IsScanning = false
            return
        end

        Rayfield:Notify({
            Title = "Scanning",
            Content = "Scanning game into unlimited batches...",
            Duration = 3
        })

        local descendants = game:GetDescendants()
        for _, obj in pairs(descendants) do
            -- Yield every 50 scripts to prevent game crash
            yieldCounter = yieldCounter + 1
            if yieldCounter % 50 == 0 then
                task.wait()
            end

            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                local fullName = obj:GetFullName()
                local isCore = string.find(fullName, "CoreGui") or string.find(fullName, "RobloxScript")
                
                -- If it's a core script and we aren't scanning cores, skip it
                if not (isCore and not State.ScanCoreScripts) then
                    local success, source = pcall(function()
                        return decompile(obj)
                    end)
                    
                    if success and source then
                        totalScriptsScanned = totalScriptsScanned + 1
                        local scriptEntry = "=== " .. fullName .. " ===\n" .. source .. "\n\n"
                        
                        local _, lines = string.gsub(scriptEntry, "\n", "")
                        lines = lines + 1
                        
                        if currentBatchLines + lines > MAX_BATCH_LINES then
                            State.Batches[currentBatchCount] = currentBatch
                            currentBatchCount = currentBatchCount + 1
                            currentBatch = scriptEntry
                            currentBatchLines = lines
                        else
                            currentBatch = currentBatch .. scriptEntry
                            currentBatchLines = currentBatchLines + lines
                        end
                    end
                end
            end
        end

        if string.len(currentBatch) > 0 then
            State.Batches[currentBatchCount] = currentBatch
        end

        local batchOptions = {"None"}
        for i = 1, #State.Batches do
            local batchName = "Batch " .. tostring(i)
            local lineCount = #string.split(State.Batches[i], "\n")
            local optionName = batchName .. " (" .. tostring(lineCount) .. " lines)"
            table.insert(batchOptions, optionName)
        end

        -- Safely update the Dropdown
        pcall(function()
            if State.Scanner_Dropdown then
                State.Scanner_Dropdown:Refresh(batchOptions)
            end
        end)
        
        Rayfield:Notify({
            Title = "Scan Complete",
            Content = "Scanned " .. totalScriptsScanned .. " scripts into " .. #State.Batches .. " batches.",
            Duration = 5
        })
        
        State.IsScanning = false
    end)
end

local function saveBatchesToFiles()
    if #State.Batches == 0 then
        Rayfield:Notify({
            Title = "Error",
            Content = "No batches found. Scan the game first.",
            Duration = 3
        })
        return
    end

    if not writefile then
        Rayfield:Notify({
            Title = "Error",
            Content = "Your executor does not support writefile()",
            Duration = 3
        })
        return
    end

    local folderName = "GameScan_" .. tostring(os.time())
    for i = 1, #State.Batches do
        local fileName = folderName .. "/Batch_" .. tostring(i) .. ".txt"
        pcall(function()
            writefile(fileName, State.Batches[i])
        end)
    end

    Rayfield:Notify({
        Title = "Saved",
        Content = "Saved " .. #State.Batches .. " batches to workspace folder.",
        Duration = 5
    })
end

-- ============================================
-- UI SETUP
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "Unlimited Batch System",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabScanner = Window:CreateTab("Scanner", 4483362458)

TabScanner:CreateSection("Scanner Settings")

TabScanner:CreateToggle({
    Name = "Scan Roblox CoreScripts",
    CurrentValue = false,
    Flag = "ScanCore",
    Callback = function(Value)
        State.ScanCoreScripts = Value
    end
})

TabScanner:CreateSection("Scanning Tools")

TabScanner:CreateButton({
    Name = "Scan All Client Scripts",
    Callback = function()
        scanGameForScripts()
    end
})

TabScanner:CreateSection("Batch Export System")

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
    Name = "Save All Batches to Files (PC)",
    Callback = function()
        saveBatchesToFiles()
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
