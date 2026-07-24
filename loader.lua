--!nocheck
-- ============================================
-- UNIVERSAL SCRIPT SCANNER: DIAGNOSTIC & TIMEOUT
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
    LoadingSubtitle = "Diagnostic Edition",
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
        local class = ""
        pcall(function() class = s.ClassName end)
        if class ~= "Script" and class ~= "LocalScript" and class ~= "ModuleScript" then return end
        
        local fullName = "Unknown"
        pcall(function() fullName = s:GetFullName() end)
        if not seen[fullName] then
            seen[fullName] = true
            table.insert(scripts, s)
        end
    end

    pcall(function() for _, obj in ipairs(game:GetDescendants()) do add(obj) end end)
    pcall(function() if getscripts then for _, s in ipairs(getscripts()) do add(s) end end end)
    pcall(function() if getloadedmodules then for _, s in ipairs(getloadedmodules()) do add(s) end end end)
    pcall(function() if getnilinstances then for _, s in ipairs(getnilinstances()) do add(s) end end end)
    
    return scripts
end

-- ============================================
-- TIMEOUT DECOMPILE FUNCTION (PREVENTS HANGING)
-- ============================================
local function SafeDecompile(scriptObj)
    if type(decompile) ~= "function" then return "-- Executor missing decompile function" end
    
    local result = nil
    local done = false
    
    -- Run decompile in a separate thread so we can abandon it if it hangs
    task.spawn(function()
        pcall(function()
            local r = decompile(scriptObj)
            if r and #r > 0 then result = r end
        end)
        -- Fallback attempt
        if not result then
            pcall(function()
                local r2 = decompile(scriptObj, true)
                if r2 and #r2 > 0 then result = r2 end
            end)
        end
        done = true
    end)
    
    -- Wait max 1 second for decompile to finish
    local t = 0
    while not done and t < 1.0 do
        task.wait(0.1)
        t = t + 0.1
    end
    
    if not done then return "-- DECOMPILE TIMED OUT (Anti-Decompile Protection)" end
    if result == nil then return "-- Failed to decompile (Bytecode locked)" end
    return result
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
-- DIAGNOSTIC SCANNER
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
    
    task.spawn(function()
        -- DIAGNOSTIC PCALL: If the loop crashes, it will tell us exactly why
        local success, err = pcall(function()
            for i = 1, totalScripts do
                local scriptObj = allScripts[i]
                local entry = ""
                local didSucceed = false
                
                -- INSTANT UI UPDATE: Shows exactly which script we are on
                pcall(function()
                    StatusLabel:Set("Status: Scanning Script " .. i .. " of " .. totalScripts .. "...")
                end)
                
                local ok, perr = pcall(function()
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
                    entry = entry .. "SCRIPT: Error on script " .. i .. "\n"
                    entry = entry .. "========================================\n"
                    entry = entry .. "Error: " .. tostring(perr) .. "\n\n"
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
                
                -- Update Time & Success Count every 5 scripts
                if i % 5 == 0 then
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
                    
                    pcall(function()
                        StatusLabel:Set(string.format("Scanning: %d%%", percent))
                        TimeLabel:Set(string.format("Time Remaining: %02d:%02d", mins, secs))
                        SuccessLabel:Set("Successfully Decompiled: " .. successCount .. " / " .. totalScripts)
                    end)
                    
                    collectgarbage("collect")
                end
                
                -- Micro yield to prevent thread blocking
                task.wait()
            end
        end)
        
        -- IF THE LOOP CRASHED, SHOW IT ON THE UI
        if not success then
            pcall(function()
                StatusLabel:Set("CRASHED! Error: " .. tostring(err))
            end)
            print("SCANNER CRASHED: " .. tostring(err))
        else
            FlushBuffer()
            pcall(function()
                StatusLabel:Set("Status: COMPLETE! 100%")
                TimeLabel:Set("Time Remaining: 00:00")
                SuccessLabel:Set("Successfully Decompiled: " .. successCount .. " / " .. totalScripts)
            end)
            
            pcall(function() appendfile(filePath, "\n=== SCAN PART " .. filePartNumber .. " COMPLETE ===\n") end)
            
            Rayfield:Notify({
                Title = "Scan Complete!", 
                Content = "Scanned " .. processedCount .. " scripts. " .. successCount .. " decompiled successfully.", 
                Duration = 6
            })
        end
        
        State.IsScanning = false
    end)
end

Tab:CreateButton({
    Name = "Start Universal Script Bypass",
    Callback = function()
        if not State.IsScanning then StartScriptScan() 
        else Rayfield:Notify({Title = "Busy", Content = "Scanner is already running!", Duration = 3}) end
    end
})
