--!nocheck
-- ============================================
-- ADVANCED SCANNER + ANTI-CRASH DIRECT WRITE
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

-- ============================================
-- UI SETUP
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Advanced Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "Direct Write Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabScanner = Window:CreateTab("Scanner", 4483362458)

TabScanner:CreateSection("Full Game Decompile")
local ScanButton = TabScanner:CreateButton({
    Name = "Scan Everything (Direct Save to Disk)",
    Callback = function() end
})

local ProgressLabel = TabScanner:CreateParagraph({
    Name = "Status",
    Content = "Idle"
})

TabScanner:CreateSection("System")
TabScanner:CreateButton({
    Name = "Unload Script",
    Callback = function()
        Rayfield:Destroy()
    end
})

-- ============================================
-- SCANNER LOGIC (Direct Write / Anti-Crash)
-- ============================================
local IsScanning = false

ScanButton.Callback = function()
    if IsScanning then return end
    IsScanning = true
    
    task.spawn(function()
        local fileName = GameName .. "_Full_Decompile.txt"
        local totalItems = #game:GetDescendants()
        local currentIndex = 0
        local yieldCounter = 0

        if not decompile then
            ProgressLabel:Set({Title = "Status", Content = "Error: No decompile()"})
            IsScanning = false
            return
        end
        
        if not writefile then
            ProgressLabel:Set({Title = "Status", Content = "Error: No writefile()"})
            IsScanning = false
            return
        end

        -- Initialize the file (clears any old data)
        writefile(fileName, "--- GAME SCAN START ---\n")
        
        -- Check if appendfile is supported
        local useAppend = appendfile ~= nil
        
        if not useAppend then
            ProgressLabel:Set({Title = "Status", Content = "Error: Executor missing appendfile(). Cannot stream."})
            IsScanning = false
            return
        end

        ProgressLabel:Set({Title = "Status", Content = "Scanning 0% (Streaming to disk)..."})
        task.wait(0.5)

        local descendants = game:GetDescendants()
        for _, obj in ipairs(descendants) do
            currentIndex = currentIndex + 1
            yieldCounter = yieldCounter + 1
            
            -- Yield and update progress every 500 items to prevent UI lockup
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
                if not isCore then
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
            
            -- Write directly to disk immediately (Zero RAM usage)
            if entry ~= "" then
                pcall(function() appendfile(fileName, entry) end)
            end
        end

        -- Finalize file
        pcall(function() appendfile(fileName, "--- GAME SCAN END ---\n") end)

        ProgressLabel:Set({Title = "Status", Content = "Done! Saved to " .. fileName})
        print("done")
        Rayfield:Notify({Title = "Done", Content = "Scan complete! Check workspace folder.", Duration = 5})
        IsScanning = false
    end)
end

Rayfield:Notify({
    Title = "Game Scanner",
    Content = "Loaded successfully! Press RightCtrl to toggle UI.",
    Duration = 3
})
