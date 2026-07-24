--!nocheck
-- ============================================
-- UNIVERSAL SCRIPT SCANNER: BULLETPROOF EDITION
-- ============================================
local MarketplaceService = game:GetService("MarketplaceService")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then return end

local GameName = "UnknownGame"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then GameName = string.gsub(info.Name, "[^%w_]", "_") end
end)

local State = { IsScanning = false }

local Window = Rayfield:CreateWindow({
    Name = "Universal Script Scanner",
    LoadingTitle = "Initializing Bypass",
    LoadingSubtitle = "Bulletproof Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Script Scanner", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")
local TimeLabel = Tab:CreateLabel("Time Remaining: --:--")
local FileLabel = Tab:CreateLabel("Save Location: N/A")

-- ============================================
-- BULLETPROOF SCRIPT COLLECTION
-- ============================================
local function GetAllScripts()
    local scripts = {}
    local seen = {}
    
    local function addScript(s)
        if s == nil then return end
        if seen[s] then return end
        
        local isScript = false
        -- Safely check if it's a script without crashing
        pcall(function()
            if s:IsA("Script") or s:IsA("LocalScript") or s:IsA("ModuleScript") then
                isScript = true
            end
        end)
        
        if isScript then
            seen[s] = true
            table.insert(scripts, s)
        end
    end
    
    pcall(function() for _, obj in ipairs(game:GetDescendants()) do addScript(obj) end end)
    pcall(function() if getscripts then for _, s in ipairs(getscripts()) do addScript(s) end end end)
    pcall(function() if getnilinstances then for _, s in ipairs(getnilinstances()) do addScript(s) end end end)
    pcall(function() if getloadedmodules then for _, s in ipairs(getloadedmodules()) do addScript(s) end end end)
    
    return scripts
end

-- ============================================
-- MEMORY BUFFER + AUTO-SPLIT SYSTEM
-- ============================================
local MAX_FILE_SIZE = 9961472 -- 9.5 MB limit
local currentFileSize = 0
local filePartNumber = 1
local filePath = GameName .. "_Scripts_Part_1.txt"

local writeBuffer = {}
local bufferSize = 0
local MAX_BUFFER_SIZE = 500000

local function FlushBuffer()
    if #writeBuffer == 0 then return end
    local chunk = table.concat(writeBuffer, "\n")
    writeBuffer = {}
    bufferSize = 0
    
    if currentFileSize + #chunk > MAX_FILE_SIZE then
        filePartNumber = filePartNumber + 1
        filePath = GameName .. "_Scripts_Part_" .. filePartNumber .. ".txt"
        local header = "=== UNIVERSAL SCRIPT SCAN: " .. GameName .. " (PART " .. filePartNumber .. ") ===\n\n"
        pcall(function() writefile(filePath, header) end)
        currentFileSize = #header
        FileLabel:Set("Save Location: " .. filePath)
    end
    
    pcall(function() appendfile(filePath, chunk) end)
    currentFileSize = currentFileSize + #chunk
end

-- ============================================
-- BULLETPROOF SCANNER
-- ============================================
local function StartScriptScan()
    if State.IsScanning then return end
    if not writefile or not appendfile then
        return Rayfield:Notify({Title = "Error", Content = "Your executor does not support saving files.", Duration = 5})
    end

    State.IsScanning = true
    StatusLabel:Set("Status: Collecting Hidden Scripts...")
    
    filePartNumber = 1
    filePath = GameName .. "_Scripts_Part_1.txt"
    local initHeader = "=== UNIVERSAL SCRIPT SCAN: " .. GameName .. " (PART 1) ===\n\n"
    
    local writeSuccess, writeErr = pcall(function() writefile(filePath, initHeader) end)
    if not writeSuccess then
        Rayfield:Notify({Title = "File Error", Content = "Cannot write to disk: " .. tostring(writeErr), Duration = 6})
        State.IsScanning = false
        return
    end
    
    currentFileSize = #initHeader
    FileLabel:Set("Save Location: " .. filePath)

    local allScripts = GetAllScripts()
    local totalScripts = #allScripts
    
    if totalScripts == 0 then
        StatusLabel:Set("Status: No scripts found!")
        State.IsScanning = false
        return
    end
    
    local processedCount = 0
    local startTime = tick()
    
    StatusLabel:Set("Status: Decompiling " .. totalScripts .. " Scripts...")

    task.spawn(function()
        -- MASTER PCALL: If anything inside the loop errors, it catches it and continues
        local success, err = pcall(function()
            for i = 1, totalScripts do
                local scriptObj = allScripts[i]
                local entry = ""
                
                -- Safely extract all data
                pcall(function()
                    local className = "Unknown"
                    local fullName = "Unknown"
                    
                    pcall(function() className = scriptObj.ClassName end)
                    
                    local successName, nameResult = pcall(function() return scriptObj:GetFullName() end)
                    if successName and type(nameResult) == "string" then
                        fullName = nameResult
                    else
                        pcall(function() fullName = tostring(scriptObj) end)
                    end
                    
                    local decompiled = "-- Failed to decompile or unsupported"
                    if type(decompile) == "function" then
                        pcall(function() 
                            local r = decompile(scriptObj)
                            if r and #r > 0 then decompiled = r end
                        end)
                    end
                    
                    entry = "\n========================================\n"
                    entry = entry .. "SCRIPT: " .. fullName .. "\n"
                    entry = entry .. "CLASS: " .. className .. "\n"
                    entry = entry .. "========================================\n"
                    entry = entry .. decompiled .. "\n\n"
                end)
                
                if entry ~= "" then
                    table.insert(writeBuffer, entry)
                    bufferSize = bufferSize + #entry
                end
                
                if bufferSize >= MAX_BUFFER_SIZE then
                    FlushBuffer()
                end
                
                processedCount = i
                
                -- YIELD & UPDATE UI EVERY 5 SCRIPTS
                if i % 5 == 0 then
                    task.wait()
                    
                    local elapsed = tick() - startTime
                    local remaining = 0
                    if processedCount > 0 and elapsed > 0 then
                        local rate = processedCount / elapsed
                        if rate > 0 then remaining = (totalScripts - processedCount) / rate end
                    end
                    if remaining < 0 then remaining = 0 end
                    
                    local mins = math.floor(remaining / 60)
                    local secs = math.floor(remaining % 60)
                    local percent = math.floor((processedCount / totalScripts) * 100)
                    local filled = math.floor(percent / 5)
                    local bar = string.rep("=", filled) .. string.rep(" ", 20 - filled)
                    
                    -- Wrap UI updates in pcall so UI errors don't kill the loop
                    pcall(function()
                        StatusLabel:Set(string.format("Scanning: [%s] %d%%", bar, percent))
                        TimeLabel:Set(string.format("Time Remaining: %02d:%02d", mins, secs))
                    end)
                end
                
                -- Clean RAM every 25 scripts
                if i % 25 == 0 then
                    collectgarbage("collect")
                end
            end
        end)
        
        if not success then
            print("Scanner encountered an error but is saving what it has: " .. tostring(err))
        end
        
        FlushBuffer()
        
        State.IsScanning = false
        pcall(function()
            StatusLabel:Set("Status: COMPLETE! 100%")
            TimeLabel:Set("Time Remaining: 00:00")
        end)
        
        pcall(function() appendfile(filePath, "\n=== SCAN PART " .. filePartNumber .. " COMPLETE ===\n") end)
        
        Rayfield:Notify({
            Title = "Bypass & Scan Complete!", 
            Content = "Decompiled " .. processedCount .. " scripts into " .. filePartNumber .. " parts.", 
            Duration = 6
        })
    end)
end

Tab:CreateButton({
    Name = "Start Universal Script Bypass",
    Callback = function()
        if not State.IsScanning then StartScriptScan() 
        else Rayfield:Notify({Title = "Busy", Content = "Scanner is already running!", Duration = 3}) end
    end
})
