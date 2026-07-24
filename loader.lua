--!nocheck
-- ============================================
-- UNIVERSAL SCRIPT SCANNER: BRUTALLY HONEST EDITION
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
    LoadingSubtitle = "Honest Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Script Scanner", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")
local TimeLabel = Tab:CreateLabel("Time Remaining: --:--")
local FileLabel = Tab:CreateLabel("Save Location: N/A")
local CountLabel = Tab:CreateLabel("Total Scripts Found: 0")
local SuccessLabel = Tab:CreateLabel("Successfully Decompiled: 0")

-- ============================================
-- STRICT & DEDUPLICATED SCRIPT COLLECTION
-- ============================================
local function GetAllScripts()
    local scripts = {}
    local seen = {}
    
    local function add(s)
        if s == nil then return end
        
        -- STRICT CLASS CHECK: Ignore Parts, Models, etc.
        local class = ""
        pcall(function() class = s.ClassName end)
        if class ~= "Script" and class ~= "LocalScript" and class ~= "ModuleScript" then
            return
        end
        
        -- DEDUPLICATION: Don't add the same script twice
        local fullName = "Unknown"
        pcall(function() fullName = s:GetFullName() end)
        
        if not seen[fullName] then
            seen[fullName] = true
            table.insert(scripts, s)
        end
    end

    -- 1. Standard game tree
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do add(obj) end
    end)
    
    -- 2. Executor API
    pcall(function() if getscripts then for _, s in ipairs(getscripts()) do add(s) end end end)
    pcall(function() if getloadedmodules then for _, s in ipairs(getloadedmodules()) do add(s) end end end)
    pcall(function() if getnilinstances then for _, s in ipairs(getnilinstances()) do add(s) end end end)
    
    return scripts
end

-- ============================================
-- SAFE DECOMPILE WITH FALLBACK
-- ============================================
local function SafeDecompile(scriptObj)
    if type(decompile) ~= "function" then return "-- Executor missing decompile function" end
    
    local result = nil
    
    -- Attempt 1: Standard decompile
    local ok1 = pcall(function() result = decompile(scriptObj) end)
    if ok1 and result and #result > 0 then return result end
    
    -- Attempt 2: Fallback decompile mode (used by some executors)
    local ok2 = pcall(function() result = decompile(scriptObj, true) end)
    if ok2 and result and #result > 0 then return result end
    
    return "-- Failed to decompile (Bytecode locked or unsupported)"
end

-- ============================================
-- MEMORY BUFFER + AUTO-SPLIT SYSTEM
-- ============================================
local MAX_FILE_SIZE = 9961472 -- 9.5 MB
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
    StatusLabel:Set("Status: Waiting 3s for game to load...")
    task.wait(3)
    
    StatusLabel:Set("Status: Collecting Scripts Strictly...")
    
    filePartNumber = 1
    filePath = GameName .. "_Scripts_Part_1.txt"
    local initHeader = "=== UNIVERSAL SCRIPT SCAN: " .. GameName .. " (PART 1) ===\n\n"
    pcall(function() writefile(filePath, initHeader) end)
    currentFileSize = #initHeader
    FileLabel:Set("Save Location: " .. filePath)

    local allScripts = GetAllScripts()
    local totalScripts = #allScripts
    
    CountLabel:Set("Total Scripts Found: " .. totalScripts)
    
    if totalScripts == 0 then
        StatusLabel:Set("Status: No scripts found!")
        State.IsScanning = false
        return
    end
    
    local processedCount = 0
    local successCount = 0
    local startTime = tick()
    
    StatusLabel:Set("Status: Decompiling " .. totalScripts .. " Scripts...")

    task.spawn(function()
        -- NO MASTER PCALL: If something errors, we want to know, not skip the rest of the scan
        for i = 1, totalScripts do
            local scriptObj = allScripts[i]
            local entry = ""
            local didSucceed = false
            
            -- Per-script pcall so one bad script doesn't stop the loop
            local ok, err = pcall(function()
                local className = "Unknown"
                local fullName = "Unknown"
                
                pcall(function() className = scriptObj.ClassName end)
                pcall(function() fullName = scriptObj:GetFullName() end)
                
                local decompiled = SafeDecompile(scriptObj)
                if not decompiled:match("^%-%-") then
                    didSucceed = true
                end
                
                entry = "\n========================================\n"
                entry = entry .. "SCRIPT: " .. fullName .. "\n"
                entry = entry .. "CLASS: " .. className .. "\n"
                entry = entry .. "========================================\n"
                entry = entry .. decompiled .. "\n\n"
            end)
            
            if not ok then
                entry = "\n========================================\n"
                entry = entry .. "SCRIPT: Error\n"
                entry = entry .. "========================================\n"
                entry = entry .. "Scanner skipped this script due to error: " .. tostring(err) .. "\n\n"
            end
            
            if entry ~= "" then
                table.insert(writeBuffer, entry)
                bufferSize = bufferSize + #entry
                if didSucceed then successCount = successCount + 1 end
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
                
                pcall(function()
                    StatusLabel:Set(string.format("Scanning: [%s] %d%%", bar, percent))
                    TimeLabel:Set(string.format("Time Remaining: %02d:%02d", mins, secs))
                    SuccessLabel:Set("Successfully Decompiled: " .. successCount .. " / " .. totalScripts)
                end)
            end
            
            -- Clean RAM every 25 scripts to prevent UI crash
            if i % 25 == 0 then
                collectgarbage("collect")
            end
        end
        
        FlushBuffer()
        
        State.IsScanning = false
        pcall(function()
            StatusLabel:Set("Status: COMPLETE! 100%")
            TimeLabel:Set("Time Remaining: 00:00")
            SuccessLabel:Set("Successfully Decompiled: " .. successCount .. " / " .. totalScripts)
        end)
        
        pcall(function() appendfile(filePath, "\n=== SCAN PART " .. filePartNumber .. " COMPLETE ===\n") end)
        
        Rayfield:Notify({
            Title = "Scan Truthfully Complete!", 
            Content = "Scanned " .. processedCount .. " scripts. " .. successCount .. " decompiled successfully.", 
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
