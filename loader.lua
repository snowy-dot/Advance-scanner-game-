--!nocheck
-- ============================================
-- ADVANCED SCANNER + FULL HIERARCHY DUMP
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

        Rayfield:Notify({Title = "Scanning", Content = "Scanning all client scripts into batches...", Duration = 3})

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
        
        Rayfield:Notify({Title = "Scan Complete", Content = "Scanned " .. totalScriptsScanned .. " scripts into " .. #State.Batches .. " batches.", Duration = 5})
        State.IsScanning = false
    end)
end

local function saveAllToSingleFile()
    if #State.Batches == 0 then
        Rayfield:Notify({Title = "Error", Content = "No scripts found. Scan the game first.", Duration = 3})
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
    local fileName = "💀💀Game_Scan💀💀.txt"
    pcall(function() writefile(fileName, fullContent) end)
    Rayfield:Notify({Title = "Saved", Content = "Saved all scripts to " .. fileName, Duration = 6})
end

-- ============================================
-- HIERARCHY & INFO DUMP LOGIC
-- ============================================
local function dumpHierarchy()
    local output = {}
    local function dumpInstance(inst, depth)
        local indent = string.rep("  ", depth)
        table.insert(output, indent .. inst.Name .. " (" .. inst.ClassName .. ")")
        if depth < 5 then
            for _, child in pairs(inst:GetChildren()) do
                dumpInstance(child, depth + 1)
            end
        end
    end
    
    local services = {"Workspace", "Lighting", "ReplicatedStorage", "Players", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer"}
    for _, serviceName in pairs(services) do
        local service = game:GetService(serviceName)
        if service then
            table.insert(output, "\n=== " .. serviceName .. " ===")
            for _, child in pairs(service:GetChildren()) do
                dumpInstance(child, 1)
            end
        end
    end
    return table.concat(output, "\n")
end

local function dumpFullInfo()
    local output = {}
    local function dumpInstance(inst)
        local info = inst.Name .. " (" .. inst.ClassName .. ")"
        if inst:IsA("BasePart") then
            info = info .. " | Pos: " .. tostring(inst.Position) .. " | Size: " .. tostring(inst.Size)
        end
        table.insert(output, info)
    end
    
    local services = {"Workspace", "Lighting", "ReplicatedStorage", "Players", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer"}
    for _, serviceName in pairs(services) do
        local service = game:GetService(serviceName)
        if service then
            table.insert(output, "\n=== " .. serviceName .. " ===")
            for _, desc in pairs(service:GetDescendants()) do
                dumpInstance(desc)
            end
        end
    end
    return table.concat(output, "\n")
end

-- ============================================
-- UI SETUP
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "Hierarchy Edition",
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
    Name = "Save All Batches to Single File",
    Callback = function()
        saveAllToSingleFile()
    end
})

TabScanner:CreateSection("Full Game Dump")
TabScanner:CreateButton({
    Name = "Dump Full Hierarchy (Map Layout)",
    Callback = function()
        local data = dumpHierarchy()
        if setclipboard then
            setclipboard(data)
            Rayfield:Notify({Title = "Copied", Content = "Full Hierarchy copied to clipboard!", Duration = 3})
        else
            print(data)
            Rayfield:Notify({Title = "Printed", Content = "Full Hierarchy printed to F9 console.", Duration = 3})
        end
    end
})
TabScanner:CreateButton({
    Name = "Dump Full Info (All Properties)",
    Callback = function()
        local data = dumpFullInfo()
        if setclipboard then
            setclipboard(data)
            Rayfield:Notify({Title = "Copied", Content = "Full Info copied to clipboard!", Duration = 3})
        else
            print(data)
            Rayfield:Notify({Title = "Printed", Content = "Full Info printed to F9 console.", Duration = 3})
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
