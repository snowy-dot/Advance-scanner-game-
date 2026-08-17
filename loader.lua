--!nocheck
-- Universal Game Scanner — Rayfield Edition v5
-- Auto-detects real game name, full source dump with metadata
-- Keybind: Right Ctrl to toggle | Improvements by [K]vk

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

local LP = Players.LocalPlayer

-- ============================================
-- GAME NAME DETECTION
-- ============================================
local GameName = game.Name
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then
        GameName = info.Name
    end
end)

local safeName = GameName:gsub("[^%w%-_]", "_")

local Window = Rayfield:CreateWindow({
   Name = "Universal Scanner — " .. GameName,
   LoadingTitle = "Scanning " .. GameName,
   LoadingSubtitle = "Place ID: " .. tostring(game.PlaceId),
   ConfigurationSaving = { Enabled = false },
   Discord = { Enabled = false },
   KeySettings = {
      Key = Enum.KeyCode.RightControl,
      OnPress = function() end,
   }
})

local TabScan = Window:CreateTab("Scanner")
local TabExport = Window:CreateTab("Export")
local TabViewer = Window:CreateTab("Script Viewer")
local TabSearch = Window:CreateTab("Search")

local State = {
    scanning = false,
    results = {},
    filteredResults = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0 },
    lastFilename = "",
    selectedScript = nil,
    currentFilter = "",
    currentStatusFilter = "ALL",
}

-- ============================================
-- PARENT FINDER
-- ============================================
local function getParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

-- ============================================
-- PROGRESS BAR (FIXED)
-- ============================================
local ProgressGui
local ProgressFill
local ProgressLabel
local ProgressPercent
local ProgressDetail

local function buildProgressGUI()
    if ProgressGui then ProgressGui:Destroy() end

    ProgressGui = Instance.new("ScreenGui")
    ProgressGui.Name = "ScannerProgress"
    ProgressGui.ResetOnSpawn = false
    ProgressGui.IgnoreGuiInset = true
    ProgressGui.Enabled = false
    ProgressGui.Parent = getParent()

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 420, 0, 64)
    frame.Position = UDim2.new(0.5, -210, 1, -90)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    frame.BorderSizePixel = 0
    frame.ZIndex = 100
    frame.Parent = ProgressGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 130, 255)
    stroke.Thickness = 1
    stroke.Parent = frame

    ProgressLabel = Instance.new("TextLabel")
    ProgressLabel.Size = UDim2.new(1, -80, 0, 18)
    ProgressLabel.Position = UDim2.new(0, 10, 0, 6)
    ProgressLabel.BackgroundTransparency = 1
    ProgressLabel.Text = "Initializing..."
    ProgressLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
    ProgressLabel.Font = Enum.Font.GothamBold
    ProgressLabel.TextSize = 11
    ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
    ProgressLabel.TextTruncate = Enum.TextTruncate.AtEnd
    ProgressLabel.ZIndex = 101
    ProgressLabel.Parent = frame

    ProgressPercent = Instance.new("TextLabel")
    ProgressPercent.Size = UDim2.new(0, 60, 0, 18)
    ProgressPercent.Position = UDim2.new(1, -68, 0, 6)
    ProgressPercent.BackgroundTransparency = 1
    ProgressPercent.Text = "0%"
    ProgressPercent.TextColor3 = Color3.fromRGB(100, 130, 255)
    ProgressPercent.Font = Enum.Font.GothamBold
    ProgressPercent.TextSize = 11
    ProgressPercent.TextXAlignment = Enum.TextXAlignment.Right
    ProgressPercent.ZIndex = 101
    ProgressPercent.Parent = frame

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 8)
    track.Position = UDim2.new(0, 10, 0, 34)
    track.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    track.BorderSizePixel = 0
    track.ZIndex = 101
    track.ClipsDescendants = true  -- FIXED: prevents fill overflow
    track.Parent = frame
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    ProgressFill = Instance.new("Frame")
    ProgressFill.Size = UDim2.new(0, 0, 1, 0)
    ProgressFill.BackgroundColor3 = Color3.fromRGB(100, 130, 255)
    ProgressFill.BorderSizePixel = 0
    ProgressFill.ZIndex = 102
    ProgressFill.Parent = track
    Instance.new("UICorner", ProgressFill).CornerRadius = UDim.new(1, 0)

    ProgressDetail = Instance.new("TextLabel")
    ProgressDetail.Size = UDim2.new(1, -20, 0, 14)
    ProgressDetail.Position = UDim2.new(0, 10, 0, 46)
    ProgressDetail.BackgroundTransparency = 1
    ProgressDetail.Text = ""
    ProgressDetail.TextColor3 = Color3.fromRGB(150, 150, 160)
    ProgressDetail.Font = Enum.Font.Gotham
    ProgressDetail.TextSize = 9
    ProgressDetail.TextXAlignment = Enum.TextXAlignment.Left
    ProgressDetail.TextTruncate = Enum.TextTruncate.AtEnd
    ProgressDetail.ZIndex = 101
    ProgressDetail.Parent = frame
end

buildProgressGUI()

local function updateProgress(current, total, containerName, scriptPath)
    local pct = 0
    if total > 0 then
        pct = math.floor((current / total) * 100)
    end
    -- direct assignment, no tween
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
        if LP:FindFirstChild("PlayerScripts") then
            table.insert(list, {LP.PlayerScripts, "PlayerScripts"})
        end
        if LP:FindFirstChild("PlayerGui") then
            table.insert(list, {LP.PlayerGui, "PlayerGui"})
        end
    end)
    -- also scan Lighting and SoundService (some games hide scripts there)
    pcall(function()
        table.insert(list, {game:GetService("Lighting"), "Lighting"})
    end)
    return list
end

-- ============================================
-- AUTO-SAVE (STREAM-WRITE, NO MEMORY BOMB)
-- ============================================
local function autoSaveDump()
    if #State.results == 0 then return nil end

    local filename = "scan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"

    if type(writefile) ~= "function" then
        return nil
    end

    -- write header first
    local header = "============================================\n"
    header = header .. "Universal Game Scanner Dump\n"
    header = header .. "Game: " .. GameName .. "\n"
    header = header .. "Place ID: " .. tostring(game.PlaceId) .. "\n"
    header = header .. "Job ID: " .. tostring(game.JobId) .. "\n"
    header = header .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    header = header .. string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d\n",
        State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed)
    header = header .. "============================================\n\n"
    header = header .. "SCRIPT INDEX:\n"
    header = header .. string.rep("-", 100) .. "\n"
    header = header .. string.format("%-5s | %-20s | %-15s | %-12s | %s\n", "#", "Container", "Class", "Status", "Path")
    header = header .. string.rep("-", 100) .. "\n"

    -- build index
    for i, r in ipairs(State.results) do
        header = header .. string.format("[%-4d] | %-20s | %-15s | %-12s | %s\n",
            i, r.container, r.class, r.status, r.path)
    end
    header = header .. "\n"

    -- write initial file
    local ok = pcall(writefile, filename, header)
    if not ok then return nil end

    -- append each script individually using appendfile if available
    for i, r in ipairs(State.results) do
        local chunk = "\n============================================\n"
        chunk = chunk .. string.format("SCRIPT [%d]\n", i)
        chunk = chunk .. "Game: " .. GameName .. "\n"
        chunk = chunk .. "Container: " .. r.container .. "\n"
        chunk = chunk .. "Class: " .. r.class .. "\n"
        chunk = chunk .. "Path: " .. r.path .. "\n"
        chunk = chunk .. "Status: " .. r.status .. "\n"
        chunk = chunk .. "============================================\n"
        if r.source then
            chunk = chunk .. r.source .. "\n"
        else
            chunk = chunk .. "-- [NO SOURCE AVAILABLE]\n"
        end

        -- use appendfile if available, otherwise rebuild (fallback)
        if type(appendfile) == "function" then
            pcall(appendfile, filename, chunk)
        else
            -- fallback: read current, append, rewrite
            -- only do this for small result sets
            if #State.results <= 100 then
                local ok2, existing = pcall(readfile, filename)
                if ok2 then
                    pcall(writefile, filename, existing .. chunk)
                end
            end
        end

        -- yield every 20 scripts to prevent freeze
        if i % 20 == 0 then
            task.wait(0.02)
        end
    end

    State.lastFilename = filename
    return filename
end

-- ============================================
-- PER-SCRIPT FILE EXPORT (NEW)
-- ============================================
local function exportIndividualScripts()
    if #State.results == 0 then return false end
    if type(writefile) ~= "function" then return false end

    local folderName = "scripts_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S")
    if type(makefolder) == "function" then
        pcall(makefolder, folderName)
    end

    for i, r in ipairs(State.results) do
        if r.source then
            local safePath = r.path:gsub("[^%w%-_]", "_")
            -- truncate long paths
            if #safePath > 80 then
                safePath = safePath:sub(-80)
            end
            local filename = string.format("%s/%03d_%s.lua", folderName, i, safePath)
            local content = string.format(
                "-- Game: %s\n-- Container: %s\n-- Class: %s\n-- Path: %s\n-- Status: %s\n%s\n",
                GameName, r.container, r.class, r.path, r.status, r.source
            )
            pcall(writefile, filename, content)
        end

        if i % 20 == 0 then
            task.wait(0.02)
        end
    end

    return folderName
end

-- ============================================
-- FILTERED RESULTS
-- ============================================
local function applyFilter()
    State.filteredResults = {}
    local filter = State.currentFilter:lower()
    local statusFilter = State.currentStatusFilter

    for i, r in ipairs(State.results) do
        local matchesName = true
        local matchesStatus = true

        if filter ~= "" then
            matchesName = r.path:lower():find(filter, 1, true) ~= nil or
                          r.container:lower():find(filter, 1, true) ~= nil or
                          r.class:lower():find(filter, 1, true) ~= nil
        end

        if statusFilter ~= "ALL" then
            matchesStatus = r.status == statusFilter
        end

        if matchesName and matchesStatus then
            table.insert(State.filteredResults, {index = i, data = r})
        end
    end
end

-- ============================================
-- SCAN LOGIC
-- ============================================
local function performScan()
    if State.scanning then return end
    State.scanning = true
    State.results = {}
    State.filteredResults = {}
    State.stats = { total = 0, success = 0, failed = 0, bytecode = 0 }
    State.lastFilename = ""

    -- rebuild progress GUI in case it was destroyed
    if not ProgressGui or not ProgressGui.Parent then
        buildProgressGUI()
    end

    ProgressGui.Enabled = true
    updateProgress(0, 1, "Counting", "scripts...")

    local containers = getContainers()

    -- Pass 1: Count (use pairs, not ipairs)
    local totalScripts = 0
    for _, containerData in ipairs(containers) do
        local container = containerData[1]
        if container then
            local descendants = container:GetDescendants()
            for _, child in pairs(descendants) do
                if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    totalScripts = totalScripts + 1
                end
            end
            -- yield once per container, not per script
            RunService.RenderStepped:Wait()
        end
    end
    State.stats.total = totalScripts

    -- Pass 2: Extract
    local current = 0
    for _, containerData in ipairs(containers) do
        local container = containerData[1]
        local name = containerData[2]
        if container then
            local descendants = container:GetDescendants()
            for _, child in pairs(descendants) do
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
                        source = src,
                        container = name,
                        instance = child,  -- keep ref for viewer
                    })

                    -- yield every 10 scripts (not every 5)
                    if current % 10 == 0 then
                        task.wait(0.01)
                    end
                end
            end
        end
    end

    -- Auto-save
    updateProgress(totalScripts, totalScripts, "Saving", "to workspace folder...")
    task.wait(0.3)

    local savedFile = autoSaveDump()

    ProgressGui.Enabled = false
    State.scanning = false

    -- apply current filter to refresh viewer
    applyFilter()

    if savedFile then
        Rayfield:Notify({
            Title = "Scan Complete & Saved",
            Content = string.format("Game: %s\nTotal: %d | OK: %d | Bytecode: %d | Failed: %d\nSaved: %s",
                GameName, State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed, savedFile),
            Duration = 8
        })
    else
        Rayfield:Notify({
            Title = "Scan Complete",
            Content = string.format("Game: %s\nTotal: %d | OK: %d | Bytecode: %d | Failed: %d\nAuto-save failed — use Export tab",
                GameName, State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed),
            Duration = 8
        })
    end
end

-- ============================================
-- SCAN TAB
-- ============================================
TabScan:CreateButton({
    Name = "Scan Game",
    Callback = function()
        performScan()
    end
})

TabScan:CreateToggle({
    Name = "Auto-Export Individual Scripts",
    CurrentValue = false,
    Flag = "AutoExportIndividual",
    Callback = function(state)
        State.autoExportIndividual = state
    end
})

TabScan:CreateButton({
    Name = "Clear Results",
    Callback = function()
        State.results = {}
        State.filteredResults = {}
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
            Title = GameName .. " — Stats",
            Content = string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d",
                State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed),
            Duration = 6
        })
    end
})

-- ============================================
-- EXPORT TAB
-- ============================================
TabExport:CreateButton({
    Name = "Re-export Full Dump",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({Title = "Error", Content = "Run a scan first.", Duration = 3})
            return
        end
        local savedFile = autoSaveDump()
        if savedFile then
            Rayfield:Notify({Title = "Exported", Content = "Saved to: " .. savedFile, Duration = 5})
        else
            Rayfield:Notify({Title = "Error", Content = "Failed to write file.", Duration = 5})
        end
    end
})

TabExport:CreateButton({
    Name = "Export Individual Script Files",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({Title = "Error", Content = "Run a scan first.", Duration = 3})
            return
        end
        local folder = exportIndividualScripts()
        if folder then
            Rayfield:Notify({
                Title = "Exported",
                Content = string.format("%d scripts saved to folder: %s/", #State.results, folder),
                Duration = 6
            })
        else
            Rayfield:Notify({Title = "Error", Content = "Export failed. writefile/makefolder not available.", Duration = 5})
        end
    end
})

TabExport:CreateButton({
    Name = "Export Index Only (with metadata)",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({Title = "Error", Content = "Run a scan first.", Duration = 3})
            return
        end
        if type(writefile) ~= "function" then
            Rayfield:Notify({Title = "Error", Content = "writefile not supported.", Duration = 3})
            return
        end

        local content = "Script Index for " .. GameName .. "\n"
        content = content .. "Place ID: " .. tostring(game.PlaceId) .. "\n"
        content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        content = content .. string.rep("-", 100) .. "\n"
        content = content .. string.format("%-5s | %-20s | %-15s | %-12s | %s\n", "#", "Container", "Class", "Status", "Path")
        content = content .. string.rep("-", 100) .. "\n"
        for i, r in ipairs(State.results) do
            content = content .. string.format("[%-4d] | %-20s | %-15s | %-12s | %s\n",
                i, r.container, r.class, r.status, r.path)
        end

        local filename = "index_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
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

        local text = "Game: " .. GameName .. " | Place: " .. tostring(game.PlaceId) .. "\n"
        text = text .. string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d\n\n",
            State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed)
        for i, r in ipairs(State.results) do
            text = text .. string.format("[%d] %s | %s | %s | %s\n", i, r.container, r.class, r.status, r.path)
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
                text = text .. "-- Game: " .. GameName .. "\n"
                text = text .. "-- Container: " .. r.container .. "\n"
                text = text .. "-- Class: " .. r.class .. "\n"
                text = text .. "-- Path: " .. r.path .. "\n"
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

-- ============================================
-- SCRIPT VIEWER TAB (NEW)
-- ============================================
local viewerDropdown
local viewerSourceLabel

local function refreshViewerList()
    applyFilter()

    local options = {}
    for _, entry in ipairs(State.filteredResults) do
        local r = entry.data
        local label = string.format("[%d] %s — %s (%s)", entry.index, r.container, r.class, r.status)
        -- truncate for dropdown readability
        if #label > 60 then
            label = label:sub(1, 57) .. "..."
        end
        table.insert(options, label)
    end

    if #options == 0 then
        options = {"No scripts found — run a scan or adjust filter"}
    end

    -- destroy and recreate dropdown
    if viewerDropdown then
        pcall(function() viewerDropdown:Destroy() end)
    end

    viewerDropdown = TabViewer:CreateDropdown({
        Name = "Select Script",
        Options = options,
        CurrentOption = options[1],
        Flag = "ViewerDropdown",
        Callback = function(option)
            -- find the selected script
            for i, entry in ipairs(State.filteredResults) do
                local r = entry.data
                local label = string.format("[%d] %s — %s (%s)", entry.index, r.container, r.class, r.status)
                if #label > 60 then
                    label = label:sub(1, 57) .. "..."
                end
                if label == option then
                    State.selectedScript = entry.index

                    -- update source display
                    local sourceText = r.source or "-- [NO SOURCE AVAILABLE]"
                    local metaText = string.format(
                        "Script #%d\nContainer: %s\nClass: %s\nPath: %s\nStatus: %s\n\n%s",
                        entry.index, r.container, r.class, r.path, r.status, sourceText
                    )

                    if viewerSourceLabel then
                        pcall(function() viewerSourceLabel:Destroy() end)
                    end

                    viewerSourceLabel = TabViewer:CreateParagraph({
                        Name = "Source Code",
                        Content = metaText,
                    })
                    break
                end
            end
        end
    })
end

TabViewer:CreateButton({
    Name = "Refresh Script List",
    Callback = function()
        refreshViewerList()
        Rayfield:Notify({
            Title = "Viewer",
            Content = string.format("%d scripts available.", #State.filteredResults),
            Duration = 3
        })
    end
})

TabViewer:CreateButton({
    Name = "Copy Selected Script Source",
    Callback = function()
        if not State.selectedScript then
            Rayfield:Notify({Title = "Error", Content = "Select a script first.", Duration = 3})
            return
        end
        if type(setclipboard) ~= "function" then
            Rayfield:Notify({Title = "Error", Content = "setclipboard not supported.", Duration = 3})
            return
        end
        local r = State.results[State.selectedScript]
        if r and r.source then
            pcall(setclipboard, r.source)
            Rayfield:Notify({Title = "Copied", Content = "Source copied to clipboard!", Duration = 3})
        else
            Rayfield:Notify({Title = "Error", Content = "No source available for this script.", Duration = 3})
        end
    end
})

TabViewer:CreateButton({
    Name = "Save Selected Script to File",
    Callback = function()
        if not State.selectedScript then
            Rayfield:Notify({Title = "Error", Content = "Select a script first.", Duration = 3})
            return
        end
        if type(writefile) ~= "function" then
            Rayfield:Notify({Title = "Error", Content = "writefile not supported.", Duration = 3})
            return
        end
        local r = State.results[State.selectedScript]
        if r and r.source then
            local safePath = r.path:gsub("[^%w%-_]", "_")
            if #safePath > 80 then safePath = safePath:sub(-80) end
            local filename = string.format("script_%03d_%s.lua", State.selectedScript, safePath)
            local content = string.format(
                "-- Game: %s\n-- Container: %s\n-- Class: %s\n-- Path: %s\n-- Status: %s\n%s\n",
                GameName, r.container, r.class, r.path, r.status, r.source
            )
            pcall(writefile, filename, content)
            Rayfield:Notify({Title = "Saved", Content = "Saved to: " .. filename, Duration = 4})
        else
            Rayfield:Notify({Title = "Error", Content = "No source available for this script.", Duration = 3})
        end
    end
})

-- ============================================
-- SEARCH TAB (NEW)
-- ============================================
TabSearch:CreateInput({
    Name = "Search by Name/Path",
    PlaceholderText = "e.g. Invisivel, RemoteEvent, module",
    RemoveTextWhenFocusLost = false,
    Callback = function(text)
        State.currentFilter = text or ""
        applyFilter()
        Rayfield:Notify({
            Title = "Search",
            Content = string.format("Found %d matching scripts.", #State.filteredResults),
            Duration = 3
        })
    end
})

TabSearch:CreateDropdown({
    Name = "Filter by Status",
    Options = {"ALL", "OK", "BYTECODE", "FAILED"},
    CurrentOption = "ALL",
    Flag = "StatusFilter",
    Callback = function(option)
        State.currentStatusFilter = option
        applyFilter()
    end
})

TabSearch:CreateButton({
    Name = "Show Filtered Results in Console",
    Callback = function()
        if #State.filteredResults == 0 then
            print("[K]vk Scanner: No results matching current filter.")
            return
        end
        print(string.format("[K]vk Scanner: %d results matching filter:", #State.filteredResults))
        for _, entry in ipairs(State.filteredResults) do
            local r = entry.data
            print(string.format("  [%d] %s | %s | %s | %s", entry.index, r.container, r.class, r.status, r.path))
        end
        Rayfield:Notify({
            Title = "Search",
            Content = string.format("%d results printed to console.", #State.filteredResults),
            Duration = 3
        })
    end
})

TabSearch:CreateButton({
    Name = "Copy Filtered Source to Clipboard",
    Callback = function()
        if #State.filteredResults == 0 then
            Rayfield:Notify({Title = "Error", Content = "No results matching filter.", Duration = 3})
            return
        end
        if type(setclipboard) ~= "function" then
            Rayfield:Notify({Title = "Error", Content = "setclipboard not supported.", Duration = 3})
            return
        end

        local text = ""
        for _, entry in ipairs(State.filteredResults) do
            local r = entry.data
            if r.source then
                text = text .. string.format("-- [%d] %s | %s | %s\n", entry.index, r.container, r.class, r.path)
                text = text .. r.source .. "\n\n"
            end
        end

        if #text == 0 then
            Rayfield:Notify({Title = "Error", Content = "No source in filtered results.", Duration = 3})
            return
        end

        pcall(setclipboard, text)
        Rayfield:Notify({Title = "Copied", Content = "Filtered source copied!", Duration = 3})
    end
})

TabSearch:CreateButton({
    Name = "Refresh Viewer with Filtered Results",
    Callback = function()
        refreshViewerList()
    end
})

-- ============================================
-- INIT
-- ============================================
Rayfield:LoadConfiguration()
print("[Universal Scanner v5] Loaded — Game: " .. GameName .. " — Right Ctrl to toggle")
print("[K]vk improvements: fixed progress bar, pairs() scan, search tab, script viewer, per-script export")
