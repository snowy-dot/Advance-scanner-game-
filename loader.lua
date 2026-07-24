--!nocheck
-- ============================================
-- UNIVERSAL SCRIPT SCANNER: ANTI-CHEAT BYPASS + TURBO
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
    LoadingSubtitle = "Scripts Only Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Script Scanner", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")
local TimeLabel = Tab:CreateLabel("Time Remaining: --:--")
local FileLabel = Tab:CreateLabel("Save Location: N/A")

-- ============================================
-- ANTI-CHEAT BYPASS COLLECTION
-- ============================================
local function GetAllScripts()
    local scripts = {}
    local seen = {}
    
    local function addScript(s)
        if s and not seen[s] then
            -- Only grab actual code scripts
            if s:IsA("Script") or s:IsA("LocalScript") or s:IsA("ModuleScript") then
                seen[s] = true
                table.insert(scripts, s)
            end
        end
    end
    
    -- 1. Standard game scripts (In case they aren't hiding)
    for _, obj in ipairs(game:GetDescendants()) do addScript(obj) end
    
    -- 2. EXECUTOR BYPASS: Force grab all running scripts (Bypasses hidden/local scripts)
    pcall(function() for _, s in ipairs(getscripts()) do addScript(s) end end)
    
    -- 3. EXECUTOR BYPASS: Force grab Nil Scripts (Anti-cheats hide here)
    pcall(function() for _, s in ipairs(getnilinstances()) do addScript(s) end end)
    
    -- 4. EXECUTOR BYPASS: Force grab Loaded Modules
    pcall(function() for _, s in ipairs(getloadedmodules()) do addScript(s) end end)
    
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
local MAX_BUFFER_SIZE = 500000 -- Flush to disk every ~0.5MB

local function FlushBuffer()
    if #writeBuffer == 0 then return end
    
    local chunk = table.concat(writeBuffer, "\n")
    writeBuffer = {}
    bufferSize = 0
    
    if currentFileSize + #chunk > MAX_FILE_SIZE then
        filePartNumber = filePartNumber + 1
        filePath = GameName .. "_Scripts_Part_" .. filePartNumber .. ".txt"
        local header = "=== UNIVERSAL SCRIPT SCAN: " .. GameName .. " (PART " .. filePartNumber .. ") ===\n\n"
        writefile(filePath, header)
        currentFileSize = #header
        FileLabel:Set("Save Location: " .. filePath)
    end
    
    pcall(function() appendfile(filePath, chunk) end)
    currentFileSize = currentFileSize + #chunk
end

-- ============================================
-- TURBO SCANNER
-- ============================================
local function StartScriptScan()
    if State.IsScanning then return end
    if not writefile or not appendfile then
        return Rayfield:Notify({Title = "Error", Content = "Your executor does not support saving files.", Duration = 5})
    end

    State.IsScanning = true
    StatusLabel:Set("Status: Forcing Anti-Cheat Bypass...")
    
    filePartNumber = 1
    filePath = GameName .. "_Scripts_Part_1.txt"
    local initHeader = "=== UNIVERSAL SCRIPT SCAN: " .. GameName .. " (PART 1) ===\n\n"
    writefile(filePath, initHeader)
    currentFileSize = #initHeader
    FileLabel:Set("Save Location: " .. filePath)

    local allScripts = GetAllScripts()
    local totalScripts = #allScripts
    local processedCount = 0
    local startTime = tick()
    
    StatusLabel:Set("Status: Decompiling " .. totalScripts .. " Scripts...")

    task.spawn(function()
        for i = 1, totalScripts do
            local scriptObj = allScripts[i]
            local entry = ""
            
            pcall(function()
                local className = scriptObj.ClassName
                local fullName = "Unknown/Nil Path"
                pcall(function() fullName = scriptObj:GetFullName() end)
                
                local decompiled = "-- Failed to decompile or locked"
                pcall(function() decompiled = decompile(scriptObj) end)
                
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
            
            -- Yield every 10 scripts to balance speed and UI stability
            if i % 10 == 0 then
                task.wait()
            end
            
            -- Update UI & Clean RAM every 100 scripts
            if i % 100 == 0 then
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
                
                StatusLabel:Set(string.format("Scanning: [%s] %d%%", bar, percent))
                TimeLabel:Set(string.format("Time Remaining: %02d:%02d", mins, secs))
                
                -- Force RAM cleanup to prevent UI disappearing
                collectgarbage("collect")
            end
        end
        
        FlushBuffer()
        
        State.IsScanning = false
        StatusLabel:Set("Status: COMPLETE! 100%")
        TimeLabel:Set("Time Remaining: 00:00")
        
        pcall(function() appendfile(filePath, "\n=== SCAN PART " .. filePartNumber .. " COMPLETE ===\n") end)
        
        Rayfield:Notify({
            Title = "Bypass & Scan Complete!", 
            Content = "Decompiled " .. totalScripts .. " scripts into " .. filePartNumber .. " parts.", 
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
