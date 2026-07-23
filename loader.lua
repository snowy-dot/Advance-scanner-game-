--!nocheck
-- ============================================
-- ADVANCED SCANNER + FULL UI + DIRECT WRITE
-- ============================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")
local LP = Players.LocalPlayer

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then return end

-- Get Game Name for File Saving
local GameName = "UnknownGame"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then
        GameName = string.gsub(info.Name, "[^%w_]", "_")
    end
end)

-- State
local State = {}
State.Scanner_Dropdown = nil
State.Batches = {}
State.ScanCoreScripts = false
State.IsScanning = false

-- ============================================
-- UI SETUP (All buttons restored)
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "Anti-Crash Full UI",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabScanner = Window:CreateTab("Scanner", 4483362458)

TabScanner:CreateSection("Full Game Decompile (Crash-Proof)")
local ScanButton = TabScanner:CreateButton({
    Name = "Scan Everything (Direct Save to Disk)",
    Callback = function() end
})

local ProgressLabel = TabScanner:CreateParagraph({
    Name = "Status",
    Content = "Idle"
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
    Callback = function(Value)
        if Value == "None" then return end
        local batchNum = tonumber(string.match(Value, "%d+"))
        if batchNum and State.Batches[batchNum] then
            if setclipboard then
                setclipboard(State.Batches[batchNum])
                Rayfield:Notify({Title = "Copied", Content = Value .. " copied to clipboard!", Duration = 3})
            else
                print(State.Batches[batchNum])
            end
        end
    end
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

TabScanner:CreateSection("Hierarchy & Info Dump")
TabScanner:CreateButton({
    Name = "Dump Full Hierarchy (Map Layout)",
    Callback = function()
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
        local services = {"Workspace", "Lighting", "ReplicatedStorage", "Players", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer"}
        for _, serviceName in pairs(services) do
            local service = game:GetService(serviceName)
            if service then
                table.insert(output, "\n=== " .. serviceName .. " ===")
                for _, child in pairs(service:GetChildren()) do
                    dumpInstance(child, 1)
                end
            end
        end
        local data = table.concat(output, "\n")
        if setclipboard then
            setclipboard(data)
            Rayfield:Notify({Title = "Copied", Content = "Full Hierarchy copied to clipboard!", Duration = 3})
        else
            print(data)
        end
    end
})

TabScanner:CreateButton({
    Name = "Dump Full Info (All Properties)",
    Callback = function()
        local output = {}
        local function dumpInstance(inst)
            local info = inst.Name .. " (" .. inst.ClassName .. ")"
            if inst:IsA("BasePart") then
                info = info .. " | Pos: " .. tostring(inst.Position) .. " | Size: " .. tostring(inst.Size)
            end
            table.insert(output, info)
        end
        local services = {"Workspace", "Lighting", "ReplicatedStorage", "Players", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer"}
        for _, serviceName in pairs(services) do
            local service = game:GetService(serviceName)
            if service then
                table.insert(output, "\n=== " .. serviceName .. " ===")
                for _, desc in pairs(service:GetDescendants()) do
                    dumpInstance(desc)
                end
            end
        end
        local data = table.concat(output, "\n")
        if setclipboard then
            setclipboard(data)
            Rayfield:Notify({Title = "Copied", Content = "Full Info copied to clipboard!", Duration = 3})
        else
            print(data)
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

-- ============================================
-- DIRECT WRITE SCAN LOGIC (Anti-Crash)
-- ============================================
ScanButton.Callback = function()
    if State.IsScanning then return end
    State.IsScanning = true
    
    task.spawn(function()
        local fileName = GameName .. "_Full_Decompile.txt"
        local totalItems = #game:GetDescendants()
        local currentIndex = 0
        local yieldCounter = 0

        if not decompile then
            ProgressLabel:Set({Title = "Status", Content = "Error: No decompile()"})
            State.IsScanning = false
            return
        end
        
        if not writefile or not appendfile then
            ProgressLabel:Set({Title = "Status", Content = "Error: No writefile/appendfile"})
            State.IsScanning = false
            return
        end

        -- Initialize file
        writefile(fileName, "--- GAME SCAN START ---\n")
        ProgressLabel:Set({Title = "Status", Content = "Scanning 0% (Streaming to disk)..."})
        task.wait(0.5)

        local descendants = game:GetDescendants()
        for _, obj in ipairs(descendants) do
            currentIndex = currentIndex + 1
            yieldCounter = yieldCounter + 1
            
            -- Yield and update progress every 500 items
            if yieldCounter % 500 == 0 then
                task.wait()
                local percent = math.floor((currentIndex / totalItems) * 100)
                ProgressLabel:Set({Title = "Status", Content = "Progress: " .. percent .. "%"})
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
                
                if #props > 0 then
                    local propString = " | " .. table.concat(props, " | ")
                    entry = "--- INSTANCE: " .. fullName .. " (" .. className .. ")" .. propString .. " ---\n"
                end
            end
            
            -- Write directly to disk immediately (Zero RAM buildup)
            if entry ~= "" then
                pcall(function() appendfile(fileName, entry) end)
            end
        end

        pcall(function() appendfile(fileName, "--- GAME SCAN END ---\n") end)
        ProgressLabel:Set({Title = "Status", Content = "Done! Saved to " .. fileName})
        print("done")
        Rayfield:Notify({Title = "Done", Content = "Scan complete! Check workspace folder.", Duration = 5})
        State.IsScanning = false
    end)
end

-- ============================================
-- BATCH SCAN LOGIC
-- ============================================
BatchButton.Callback = function()
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
            ProgressLabel:Set({Title = "Status", Content = "Error: No decompile()"})
            State.IsScanning = false
            return
        end

        ProgressLabel:Set({Title = "Status", Content = "Scanning scripts..."})

        local descendants = game:GetDescendants()
        for _, obj in ipairs(descendants) do
            currentIndex = currentIndex + 1
            yieldCounter = yieldCounter + 1
            if yieldCounter % 50 == 0 then
                task.wait()
                local percent = math.floor((currentIndex / totalItems) * 100)
                ProgressLabel:Set({Title = "Status", Content = "Batch Progress: " .. percent .. "%"})
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
                        
                        if currentBatchLines + lines > 3500 then
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
        
        ProgressLabel:Set({Title = "Status", Content = "Batch Scan Done."})
        print("done")
        Rayfield:Notify({Title = "Done", Content = "Scanned " .. totalScriptsScanned .. " scripts.", Duration = 5})
        State.IsScanning = false
    end)
end

Rayfield:Notify({
    Title = "Game Scanner",
    Content = "Loaded successfully! Press RightCtrl to toggle UI.",
    Duration = 3
})
