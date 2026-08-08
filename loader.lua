--!nocheck
-- Universal Game Scanner — Rayfield Edition v3
-- Features: Progress bar, auto-save to workspace folder
-- Keybind: Right Ctrl to toggle

local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

local Window = Rayfield:CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "by He",
   ConfigurationSaving = { Enabled = false },
   Discord = { Enabled = false },
   KeySettings = {
      Key = Enum.KeyCode.RightControl,
      OnPress = function() end,
   }
})

local TabScan = Window:CreateTab("Scanner")
local TabExport = Window:CreateTab("Export")

local State = {
    scanning = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0 },
    lastFilename = ""
}

-- ============================================
-- PROGRESS BAR GUI
-- ============================================
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local function getParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

local ProgressGui = Instance.new("ScreenGui")
ProgressGui.Name = "ScannerProgress"
ProgressGui.ResetOnSpawn = false
ProgressGui.IgnoreGuiInset = true
ProgressGui.Enabled = false
ProgressGui.Parent = getParent()

local ProgressFrame = Instance.new("Frame")
ProgressFrame.Size = UDim2.new(0, 420, 0, 64)
ProgressFrame.Position = UDim2.new(0.5, -210, 1, -90)
ProgressFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ProgressFrame.BorderSizePixel = 0
ProgressFrame.Parent = ProgressGui
Instance.new("UICorner", ProgressFrame).CornerRadius = UDim.new(0, 8)

local ProgressStroke = Instance.new("UIStroke")
ProgressStroke.Color = Color3.fromRGB(100, 130, 255)
ProgressStroke.Thickness = 1
ProgressStroke.Parent = ProgressFrame

local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Size = UDim2.new(1, -80, 0, 18)
ProgressLabel.Position = UDim2.new(0, 10, 0, 6)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Text = "Initializing..."
ProgressLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
ProgressLabel.Font = Enum.Font.GothamBold
ProgressLabel.TextSize = 11
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
ProgressLabel.TextTruncate = Enum.TextTruncate.AtEnd
ProgressLabel.Parent = ProgressFrame

local ProgressPercent = Instance.new("TextLabel")
ProgressPercent.Size = UDim2.new(0, 60, 0, 18)
ProgressPercent.Position = UDim2.new(1, -68, 0, 6)
ProgressPercent.BackgroundTransparency = 1
ProgressPercent.Text = "0%"
ProgressPercent.TextColor3 = Color3.fromRGB(100, 130, 255)
ProgressPercent.Font = Enum.Font.GothamBold
ProgressPercent.TextSize = 11
ProgressPercent.TextXAlignment = Enum.TextXAlignment.Right
ProgressPercent.Parent = ProgressFrame

local ProgressTrack = Instance.new("Frame")
ProgressTrack.Size = UDim2.new(1, -20, 0, 8)
ProgressTrack.Position = UDim2.new(0, 10, 0, 34)
ProgressTrack.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
ProgressTrack.BorderSizePixel = 0
ProgressTrack.Parent = ProgressFrame
Instance.new("UICorner", ProgressTrack).CornerRadius = UDim.new(1, 0)

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(100, 130, 255)
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressTrack
Instance.new("UICorner", ProgressFill).CornerRadius = UDim.new(1, 0)

local ProgressDetail = Instance.new("TextLabel")
ProgressDetail.Size = UDim2.new(1, -20, 0, 14)
ProgressDetail.Position = UDim2.new(0, 10, 0, 46)
ProgressDetail.BackgroundTransparency = 1
ProgressDetail.Text = ""
ProgressDetail.TextColor3 = Color3.fromRGB(150, 150, 160)
ProgressDetail.Font = Enum.Font.Gotham
ProgressDetail.TextSize = 9
ProgressDetail.TextXAlignment = Enum.TextXAlignment.Left
ProgressDetail.TextTruncate = Enum.TextTruncate.AtEnd
ProgressDetail.Parent = ProgressFrame

-- ============================================
-- SOURCE EXTRACTION
-- ============================================
local function getScriptSource(script)
    if type(getsrc) == "function" then
        local ok, result = pcall(getsrc, script)
        if ok and type(result) == "string" and #result > 0 then
            return result, "OK"
        end
    end
    if type(decompile) == "function" then
        local ok, result = pcall(decompile, script)
        if ok and type(result) == "string" and #result > 0 then
            return result, "OK"
        end
    end
    if type(getscriptbytecode) == "function" then
        local ok, result = pcall(getscriptbytecode, script)
        if ok and type(result) == "string" and #result > 0 then
            return result, "BYTECODE"
        end
    end
    return nil, "FAILED"
end

-- ============================================
-- CONTAINERS
-- ============================================
local function getContainers()
    local list = {
        {game:GetService("Workspace"), "Workspace"},
        {game:GetService("ReplicatedStorage"), "ReplicatedStorage"},
        {game:GetService("ServerScriptService"), "ServerScriptService"},
        {game:GetService("StarterGui"), "StarterGui"},
        {game:GetService("StarterPlayer"), "StarterPlayer"},
    }
    pcall(function()
        table.insert(list, {game:GetService("CoreGui"), "CoreGui"})
    end)
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        if lp:FindFirstChild("PlayerScripts") then
            table.insert(list, {lp.PlayerScripts, "PlayerScripts"})
        end
        if lp:FindFirstChild("PlayerGui") then
            table.insert(list, {lp.PlayerGui, "PlayerGui"})
        end
    end)
    return list
end

-- ============================================
-- PROGRESS UPDATE
-- ============================================
local function updateProgress(current, total, containerName, scriptPath)
    local pct = 0
    if total > 0 then
        pct = math.floor((current / total) * 100)
    end
    
    ProgressFill.Size = UDim2.new(pct / 100, 0, 1, 0)
    ProgressPercent.Text = tostring(pct) .. "%"
    ProgressLabel.Text = string.format("[%d / %d] %s", current, total, containerName or "")
    
    local detail = scriptPath or ""
    if #detail > 55 then
        detail = "..." .. detail:sub(-52)
    end
    ProgressDetail.Text = detail
end

-- ============================================
-- AUTO-SAVE
-- ============================================
local function autoSaveDump()
    if #State.results == 0 then return nil end
    
    local content = "============================================\n"
    content = content .. "Universal Game Scanner Dump\n"
    content = content .. "Game: " .. game.Name .. "\n"
    content = content .. "Place ID: " .. tostring(game.PlaceId) .. "\n"
    content = content .. "Job ID: " .. tostring(game.JobId) .. "\n"
    content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    content = content .. string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d\n",
        State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed)
    content = content .. "============================================\n\n"
    
    content = content .. "SCRIPT INDEX:\n"
    content = content .. string.rep("-", 80) .. "\n"
    for i, r in ipairs(State.results) do
        content = content .. string.format("[%d] %s | %s | %s\n", i, r.path, r.class, r.status)
    end
    content = content .. "\n"
    
    for i, r in ipairs(State.results) do
        content = content .. "\n============================================\n"
        content = content .. string.format("SCRIPT [%d]: %s\n", i, r.path)
        content = content .. "CLASS: " .. r.class .. "\n"
        content = content .. "STATUS: " .. r.status .. "\n"
        content = content .. "============================================\n"
        if r.source then
            content = content .. r.source .. "\n"
        else
            content = content .. "-- [NO SOURCE AVAILABLE]\n"
        end
    end
    
    local filename = "scan_" .. game.Name:gsub("[^%w]", "_") .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    
    if type(writefile) == "function" then
        local ok = pcall(writefile, filename, content)
        if ok then
            State.lastFilename = filename
            return filename
        end
    end
    
    return nil
end

-- ============================================
-- SCAN LOGIC
-- ============================================
local function performScan()
    if State.scanning then return end
    State.scanning = true
    State.results = {}
    State.stats = { total = 0, success = 0, failed = 0, bytecode = 0 }
    State.lastFilename = ""
    
    ProgressGui.Enabled = true
    updateProgress(0, 0, "Counting", "scripts...")
    
    local containers = getContainers()
    
    -- Pass 1: Count total scripts
    local totalScripts = 0
    for _, containerData in ipairs(containers) do
        local container = containerData[1]
        if container then
            for _, child in ipairs(container:GetDescendants()) do
                if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    totalScripts = totalScripts + 1
                end
            end
            task.wait()
        end
    end
    State.stats.total = totalScripts
    
    -- Pass 2: Extract sources with progress
    local current = 0
    for _, containerData in ipairs(containers) do
        local container = containerData[1]
        local name = containerData[2]
        if container then
            for _, child in ipairs(container:GetDescendants()) do
                if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    current = current + 1
                    local path = child:GetFullName()
                    local className = child.ClassName
                    
                    updateProgress(current, totalScripts, name, path)
                    
                    local src, status = getScriptSource(child)
                    
                    if status == "OK" then
                        State.stats.success = State.stats.success + 1
                    elseif status == "BYTECODE" then
                        State.stats.bytecode = State.stats.bytecode + 1
                    else
                        State.stats.failed = State.stats.failed + 1
                    end
                    
                    table.insert(State.results, {
                        path = path,
                        class = className,
                        status = status,
                        source = src
                    })
                    
                    if current % 5 == 0 then
                        task.wait()
                    end
                end
            end
        end
    end
    
    -- Auto-save
    updateProgress(State.stats.total, State.stats.total, "Saving", "to workspace folder...")
    task.wait(0.5)
    
    local savedFile = autoSaveDump()
    
    ProgressGui.Enabled = false
    State.scanning = false
    
    if savedFile then
        Rayfield:Notify({
            Title = "Scan Complete & Saved",
            Content = string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d\nSaved: %s",
                State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed, savedFile),
            Duration = 8
        })
    else
        Rayfield:Notify({
            Title = "Scan Complete",
            Content = string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d\nAuto-save failed — use Export tab",
                State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed),
            Duration = 8
        })
    end
end

-- ============================================
-- SCAN TAB BUTTONS
-- ============================================
TabScan:CreateButton({
    Name = "Scan Game",
    Callback = function()
        performScan()
    end
})

TabScan:CreateButton({
    Name = "Clear Results",
    Callback = function()
        State.results = {}
        State.stats = { total = 0, success = 0, failed = 0, bytecode = 0 }
        State.lastFilename = ""
        Rayfield:Notify({
            Title = "Cleared",
            Content = "All results cleared.",
            Duration = 3
        })
    end
})

TabScan:CreateButton({
    Name = "Show Stats",
    Callback = function()
        Rayfield:Notify({
            Title = "Current Stats",
            Content = string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d",
                State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed),
            Duration = 6
        })
    end
})

-- ============================================
-- EXPORT TAB BUTTONS
-- ============================================
TabExport:CreateButton({
    Name = "Re-export Full Dump",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({Title = "Error", Content = "Run a scan first.", Duration = 3})
            return
        end
        if type(writefile) ~= "function" then
            Rayfield:Notify({Title = "Error", Content = "writefile not supported.", Duration = 3})
            return
        end
        
        local content = "============================================\n"
        content = content .. "Universal Game Scanner Dump\n"
        content = content .. "Game: " .. game.Name .. "\n"
        content = content .. "Place ID: " .. tostring(game.PlaceId) .. "\n"
        content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        content = content .. string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d\n",
            State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed)
        content = content .. "============================================\n\n"
        content = content .. "SCRIPT INDEX:\n"
        content = content .. string.rep("-", 80) .. "\n"
        for i, r in ipairs(State.results) do
            content = content .. string.format("[%d] %s | %s | %s\n", i, r.path, r.class, r.status)
        end
        content = content .. "\n"
        for i, r in ipairs(State.results) do
            content = content .. "\n============================================\n"
            content = content .. string.format("SCRIPT [%d]: %s\n", i, r.path)
            content = content .. "CLASS: " .. r.class .. "\n"
            content = content .. "STATUS: " .. r.status .. "\n"
            content = content .. "============================================\n"
            if r.source then
                content = content .. r.source .. "\n"
            else
                content = content .. "-- [NO SOURCE AVAILABLE]\n"
            end
        end
        local filename = "scan_" .. game.Name:gsub("[^%w]", "_") .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
        local ok = pcall(writefile, filename, content)
        if ok then
            State.lastFilename = filename
            Rayfield:Notify({Title = "Exported", Content = "Saved to: " .. filename, Duration = 5})
        else
            Rayfield:Notify({Title = "Error", Content = "Failed to write file.", Duration = 5})
        end
    end
})

TabExport:CreateButton({
    Name = "Export Index Only",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({Title = "Error", Content = "Run a scan first.", Duration = 3})
            return
        end
        if type(writefile) ~= "function" then
            Rayfield:Notify({Title = "Error", Content = "writefile not supported.", Duration = 3})
            return
        end
        local content = "Script Index for " .. game.Name .. "\n"
        content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        content = content .. string.rep("-", 80) .. "\n"
        for i, r in ipairs(State.results) do
            content = content .. string.format("[%d] %s | %s | %s\n", i, r.path, r.class, r.status)
        end
        local filename = "index_" .. game.Name:gsub("[^%w]", "_") .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
        pcall(writefile, filename, content)
        Rayfield:Notify({Title = "Exported", Content = "Index saved to: " .. filename, Duration = 5})
    end
})

TabExport:CreateButton({
    Name = "Copy Stats to Clipboard",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({Title = "Error", Content = "Run a scan first.", Duration = 3})
            return
        end
        if type(setclipboard) ~= "function" then
            Rayfield:Notify({Title = "Error", Content = "setclipboard not supported.", Duration = 3})
            return
        end
        local text = "Game: " .. game.Name .. " | Place: " .. tostring(game.PlaceId) .. "\n"
        text = text .. string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d\n\n",
            State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed)
        for i, r in ipairs(State.results) do
            text = text .. string.format("[%d] %s | %s | %s\n", i, r.path, r.class, r.status)
        end
        pcall(setclipboard, text)
        Rayfield:Notify({Title = "Copied", Content = "Stats copied to clipboard!", Duration = 3})
    end
})

TabExport:CreateButton({
    Name = "Copy All Source Code",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({Title = "Error", Content = "Run a scan first.", Duration = 3})
            return
        end
        if type(setclipboard) ~= "function" then
            Rayfield:Notify({Title = "Error", Content = "setclipboard not supported.", Duration = 3})
            return
        end
        local text = ""
        for i, r in ipairs(State.results) do
            if r.source and r.status == "OK" then
                text = text .. "-- " .. r.path .. " (" .. r.class .. ")\n"
                text = text .. "-- " .. string.rep("-", 60) .. "\n"
                text = text .. r.source .. "\n\n"
            end
        end
        if #text == 0 then
            Rayfield:Notify({Title = "Error", Content = "No extractable source found.", Duration = 3})
            return
        end
        pcall(setclipboard, text)
        Rayfield:Notify({Title = "Copied", Content = "All source code copied!", Duration = 3})
    end
})

TabExport:CreateButton({
    Name = "Show Last Saved File",
    Callback = function()
        if State.lastFilename == "" then
            Rayfield:Notify({Title = "Error", Content = "No file saved yet.", Duration = 3})
            return
        end
        Rayfield:Notify({
            Title = "Last Saved File",
            Content = "Filename: " .. State.lastFilename,
            Duration = 6
        })
    end
})

Rayfield:LoadConfiguration()
print("[Universal Scanner v3] Loaded — Right Ctrl to toggle")
