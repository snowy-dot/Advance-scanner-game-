--!nocheck
-- ============================================
-- ADVANCED SCANNER + ANTI-CHEAT (V3)
-- ============================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")
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
State.GameName = "UnknownGame"
State.AntiCheatEnabled = false

-- Get Game Name
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then
        State.GameName = info.Name
        State.GameName = string.gsub(State.GameName, "[\\/:*?\"<>|]", "_")
    end
end)

-- ============================================
-- ADVANCED ANTI-CHEAT SYSTEM
-- ============================================
local function EnableAntiCheat()
    if State.AntiCheatEnabled then return end
    State.AntiCheatEnabled = true

    pcall(function()
        local mt = getrawmetatable(game)
        local oldIndex = mt.__index
        setreadonly(mt, false)
        
        mt.__index = newcclosure(function(self, key)
            if not checkcaller() and (key == "FindFirstChild" or key == "WaitForChild") then
                return function(self, name)
                    local child = oldIndex(self, key)(self, name)
                    if child and (child.Name == "UniversalVisuals" or string.find(child.Name, "Rayfield")) then
                        return nil
                    end
                    return child
                end
            end
            return oldIndex(self, key)
        end)
        
        setreadonly(mt, true)
    end)
end

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
    
    -- Wrap in pcall to prevent UI crash if an error occurs
    local success, err = pcall(function()
        State.Batches = {}
        local currentBatch = ""
        local currentBatchLines = 0
        local currentBatchCount = 1
        local totalScriptsScanned = 0

        if not decompile then
            error("Your executor does not support decompile()")
        end

        Rayfield:Notify({
            Title = "Scanning",
            Content = "Scanning game safely to prevent crashes...",
            Duration = 3
        })

        local descendants = game:GetDescendants()
        for _, obj in pairs(descendants) do
            -- CRITICAL: Yield after EVERY script to prevent UI thread crash
            task.wait()
            
            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                local fullName = obj:GetFullName()
                local isCore = string.find(fullName, "CoreGui") or string.find(fullName, "RobloxScript")
                
                if not (isCore and not State.ScanCoreScripts) then
                    local decompSuccess, source = pcall(function()
                        return decompile(obj)
                    end)
                    
                    if decompSuccess and source then
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
    end)

    if not success then
        print("Scan Error: " .. tostring(err))
        Rayfield:Notify({
            Title = "Error",
            Content = "Scan failed: " .. tostring(err),
            Duration = 5
        })
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
            State.Scanner_Dropdown:Refresh(batchOptions)
        end
    end)
    
    Rayfield:Notify({
        Title = "Scan Complete",
        Content = "Scanned into " .. #State.Batches .. " batches.",
        Duration = 5
    })
    
    State.IsScanning = false
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

    for i = 1, #State.Batches do
        local fileName = "[" .. State.GameName .. "] Batch_" .. tostring(i) .. ".txt"
        pcall(function()
            writefile(fileName, State.Batches[i])
        end)
    end

    Rayfield:Notify({
        Title = "Saved",
        Content = "Saved " .. #State.Batches .. " files to executor workspace folder.",
        Duration = 6
    })
end

-- ============================================
-- UI SETUP
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "Anti-Cheat Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabScanner = Window:CreateTab("Scanner", 4483362458)

TabScanner:CreateSection("Anti-Cheat Protection")

TabScanner:CreateToggle({
    Name = "Enable Advanced Anti-Cheat (Hides UI)",
    CurrentValue = false,
    Flag = "AntiCheat",
    Callback = function(Value)
        if Value then
            EnableAntiCheat()
            Rayfield:Notify({
                Title = "Protected",
                Content = "UI is now invisible to game anti-cheats.",
                Duration = 3
            })
        end
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

TabScanner:CreateParagraph({
    Title = "Where are my files?",
    Content = "Files are saved to your Executor's 'workspace' folder. (Usually located in %localappdata%/[ExecutorName]/workspace)"
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
