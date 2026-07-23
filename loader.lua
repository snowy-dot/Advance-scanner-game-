--!nocheck
-- ============================================
-- ADVANCED GAME SCANNER + PROGRESS BAR + ANTI-CRASH
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
State.IsScanning = false
State.ScanCoreScripts = false

-- ============================================
-- UI SETUP
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner Initializing",
    LoadingSubtitle = "Direct Write Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabScanner = Window:CreateTab("Scanner", 4483362458)

-- UI Elements
local StatusLabel = TabScanner:CreateLabel("Status: Idle")

local CoreScriptsToggle = TabScanner:CreateToggle({
    Name = "Scan CoreScripts (May cause lag)",
    CurrentValue = false,
    Flag = "CoreScriptsToggle",
    Callback = function(Value)
        State.ScanCoreScripts = Value
    end
})

-- Function to generate ASCII progress bar
local function getProgressBar(current, total)
    local percent = math.floor((current / total) * 100)
    local filled = math.floor(percent / 5)
    local bar = string.rep("=", filled) .. string.rep(" ", 20 - filled)
    return string.format("[%s] %d%% (%d/%d)", bar, percent, current, total)
end

-- Scan Button
local ScanButton = TabScanner:CreateButton({
    Name = "Start Full Game Scan",
    Callback = function()
        if State.IsScanning then
            Rayfield:Notify({Title = "Busy", Content = "Scanner is already running!", Duration = 3})
            return
        end
        
        if not writefile or not appendfile or not makefolder then
            Rayfield:Notify({Title = "Error", Content = "Your executor lacks file writing support.", Duration = 5})
            return
        end

        State.IsScanning = true
        ScanButton:Set("Scan in Progress...")
        StatusLabel:Set("Collecting Scripts... Please wait.")
        
        task.wait(0.5)
        
        -- 1. Collect all scripts first to get a total count for the progress bar
        local scriptsToScan = {}
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") or obj:IsA("Script") then
                if State.ScanCoreScripts or not obj:IsDescendantOf(CoreGui) then
                    table.insert(scriptsToScan, obj)
                end
            end
        end
        
        local totalScripts = #scriptsToScan
        if totalScripts == 0 then
            StatusLabel:Set("Status: No scripts found!")
            State.IsScanning = false
            ScanButton:Set("Start Full Game Scan")
            return
        end

        -- 2. Setup File Directory
        local folderName = "GameScannerExports"
        if not isfolder(folderName) then
            makefolder(folderName)
        end
        local fileName = folderName .. "/" .. GameName .. "_Scan.txt"
        
        -- Clear existing file
        writefile(fileName, "=== GAME SCAN START: " .. GameName .. " ===\nTotal Scripts: " .. totalScripts .. "\n\n")
        
        -- 3. Scan and write directly to disk (Anti-Crash)
        local scannedCount = 0
        local successCount = 0
        
        for i, scriptObj in ipairs(scriptsToScan) do
            -- Update UI every 10 scripts to prevent UI lag
            if i % 10 == 0 then
                StatusLabel:Set("Scanning...\n" .. getProgressBar(i, totalScripts))
            end
            
            -- Decompile script safely
            local success, decompiled = pcall(function()
                if decompile then 
                    return decompile(scriptObj) 
                else 
                    return "-- Decompile function not available in this executor"
                end
            end)
            
            if success and decompiled then
                local entry = "\n========================================\n"
                entry = entry .. "SCRIPT: " .. scriptObj:GetFullName() .. "\n"
                entry = entry .. "========================================\n"
                entry = entry .. decompiled .. "\n\n"
                
                -- Append directly to file (Zero RAM usage)
                appendfile(fileName, entry)
                successCount = successCount + 1
            end
            
            scannedCount = i
            -- Yield periodically to prevent executor timeout
            if i % 50 == 0 then
                task.wait()
            end
        end

        -- 4. Finish up
        StatusLabel:Set("Status: Complete!\n" .. getProgressBar(scannedCount, totalScripts) .. "\nSaved to GameScannerExports folder!")
        ScanButton:Set("Start Full Game Scan")
        State.IsScanning = false
        
        Rayfield:Notify({
            Title = "Scan Complete!",
            Content = "Successfully decompiled " .. successCount .. " scripts.\nCheck your executor's workspace folder!",
            Duration = 6
        })
    end
})

Rayfield:LoadConfiguration()
