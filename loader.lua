--!nocheck
-- Universal Game Scanner v6.1 — [K]vk Edition (Fixed)
-- Full feature set with auto-save fix
-- Keybind: Right Ctrl to toggle

-- FORWARD DECLARE
local Rayfield

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Teams = game:GetService("Teams")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0, client = 0, server = 0, module = 0 },
    lastFilename = "",
    maxDepth = 0,
    remoteSniffData = {},
    lastScanResults = nil,
    selectedScript = nil,
}

local connections = {}
local ProgressGui
local ProgressFill
local ProgressLabel
local ProgressPercent
local ProgressDetail
local ProgressTrack

-- ============================================
-- GAME NAME
-- ============================================
local GameName = game.Name
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then GameName = info.Name end
end)
local safeName = GameName:gsub("[^%w%-_]", "_")

-- ============================================
-- PARENT FINDER
-- ============================================
local function getParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================
-- PROGRESS GUI
-- ============================================
local function buildProgressGUI()
    if ProgressGui then ProgressGui:Destroy() end
    ProgressGui = Instance.new("ScreenGui")
    ProgressGui.Name = "ScannerProgress"
    ProgressGui.ResetOnSpawn = false
    ProgressGui.IgnoreGuiInset = true
    ProgressGui.Enabled = false
    ProgressGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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

    ProgressTrack = Instance.new("Frame")
    ProgressTrack.Size = UDim2.new(1, -20, 0, 8)
    ProgressTrack.Position = UDim2.new(0, 10, 0, 34)
    ProgressTrack.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    ProgressTrack.BorderSizePixel = 0
    ProgressTrack.ZIndex = 101
    ProgressTrack.ClipsDescendants = true
    ProgressTrack.Parent = frame
    Instance.new("UICorner", ProgressTrack).CornerRadius = UDim.new(1, 0)

    ProgressFill = Instance.new("Frame")
    ProgressFill.Size = UDim2.new(0, 0, 1, 0)
    ProgressFill.BackgroundColor3 = Color3.fromRGB(100, 130, 255)
    ProgressFill.BorderSizePixel = 0
    ProgressFill.ZIndex = 102
    ProgressFill.Parent = ProgressTrack
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
    if total > 0 then pct = math.floor((current / total) * 100) end
    ProgressFill.Size = UDim2.new(pct / 100, 0, 1, 0)
    ProgressPercent.Text = tostring(pct) .. "%"
    ProgressLabel.Text = string.format("[%d / %d] %s", current, total, containerName or "")
    local detail = scriptPath or ""
    if #detail > 55 then detail = "..." .. detail:sub(-52) end
    ProgressDetail.Text = detail
end

-- ============================================
-- SAFE NOTIFY
-- ============================================
local function safeNotify(title, content)
    pcall(function()
        if Rayfield and Rayfield.Notify then
            Rayfield:Notify({Title = title, Content = content, Duration = 6})
        end
    end)
end

-- ============================================
-- SOURCE EXTRACTION
-- ============================================
local function getScriptSource(script)
    if type(getsrc) == "function" then
        local ok, result = pcall(getsrc, script)
        if ok and type(result) == "string" and #result > 0 then return result, "OK" end
    end
    if type(decompile) == "function" then
        local ok, result = pcall(decompile, script)
        if ok and type(result) == "string" and #result > 0 then return result, "OK" end
    end
    if type(getscriptbytecode) == "function" then
        local ok, result = pcall(getscriptbytecode, script)
        if ok and type(result) == "string" and #result > 0 then return result, "BYTECODE" end
    end
    return nil, "FAILED"
end

-- ============================================
-- CONTAINERS
-- ============================================
local function getContainers()
    local list = {
        {Workspace, "Workspace"},
        {ReplicatedStorage, "ReplicatedStorage"},
        {ServerScriptService, "ServerScriptService"},
        {StarterGui, "StarterGui"},
        {StarterPlayer, "StarterPlayer"},
    }
    pcall(function() table.insert(list, {game:GetService("CoreGui"), "CoreGui"}) end)
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerScripts") then
            table.insert(list, {LocalPlayer.PlayerScripts, "PlayerScripts"})
        end
        if LocalPlayer:FindFirstChild("PlayerGui") then
            table.insert(list, {LocalPlayer.PlayerGui, "PlayerGui"})
        end
    end)
    pcall(function() table.insert(list, {game:GetService("Lighting"), "Lighting"}) end)
    return list
end

-- ============================================
-- AUTO-CATEGORY
-- ============================================
local categoryKeywords = {
    Combat = {"combat", "punch", "attack", "damage", "weapon", "gun", "melee", "fight", "kill", "health"},
    Movement = {"movement", "walkspeed", "fly", "noclip", "jump", "gravity", "velocity", "dash", "sprint", "shiftlock", "camera"},
    UI = {"gui", "frame", "button", "ui", "hud", "menu", "interface", "screen", "panel"},
    Economy = {"shop", "buy", "currency", "cash", "coin", "reward", "spin", "egg", "pet", "rebirth", "upgrade"},
    NPC = {"npc", "monster", "enemy", "boss", "ai", "bot", "creature"},
    Admin = {"cmdr", "command", "admin", "ban", "kick", "teleport", "warn"},
    Remote = {"remote", "fire", "server", "replicate", "event"},
}

local function categorizeScript(path, className)
    local pathLower = path:lower()
    for category, keywords in pairs(categoryKeywords) do
        for _, keyword in ipairs(keywords) do
            if pathLower:match(keyword) then return category end
        end
    end
    if className == "LocalScript" then return "Client"
    elseif className == "Script" then return "Server"
    elseif className == "ModuleScript" then return "Module" end
    return "Other"
end

-- ============================================
-- DEPTH SCANNER
-- ============================================
local function getDescendantsWithDepth(container, maxDepth)
    local results = {}
    local function scan(parent, currentDepth)
        if maxDepth > 0 and currentDepth >= maxDepth then return end
        for _, child in pairs(parent:GetChildren()) do
            table.insert(results, child)
            scan(child, currentDepth + 1)
        end
    end
    scan(container, 0)
    return results
end

-- ============================================
-- AUTO-SAVE (FIXED)
-- ============================================
local function autoSaveDump()
    if #State.results == 0 then return nil end
    if type(writefile) ~= "function" then
        print("[K]vk Scanner: writefile not available — cannot save to workspace.")
        return nil
    end

    local filename = "scan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"

    -- build header
    local content = "============================================\n"
    content = content .. "Universal Game Scanner v6.1 Dump\n"
    content = content .. "Game: " .. GameName .. "\n"
    content = content .. "Place ID: " .. tostring(game.PlaceId) .. "\n"
    content = content .. "Job ID: " .. tostring(game.JobId) .. "\n"
    content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    content = content .. string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d | Client: %d | Server: %d | Module: %d\n",
        State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed,
        State.stats.client, State.stats.server, State.stats.module)
    content = content .. "============================================\n\n"

    -- script index
    content = content .. "SCRIPT INDEX:\n"
    content = content .. string.rep("-", 120) .. "\n"
    content = content .. string.format("%-5s | %-15s | %-15s | %-8s | %-12s | %-8s | %s\n", "#", "Container", "Class", "Status", "Category", "Type", "Path")
    content = content .. string.rep("-", 120) .. "\n"
    for i, r in ipairs(State.results) do
        local scriptType = ""
        if r.class == "LocalScript" then scriptType = "CLIENT"
        elseif r.class == "Script" then scriptType = "SERVER"
        elseif r.class == "ModuleScript" then scriptType = "MODULE" end
        content = content .. string.format("[%-4d] | %-15s | %-15s | %-8s | %-12s | %-8s | %s\n",
            i, r.container, r.class, r.status, r.category or "Other", scriptType, r.path)
    end
    content = content .. "\n"

    -- try writefile with full content
    local writeOk = pcall(writefile, filename, content)
    if not writeOk then
        print("[K]vk Scanner: writefile failed for full dump. Trying appendfile fallback...")
    end

    -- append each script individually (works even if writefile fails for large content)
    for i, r in ipairs(State.results) do
        local chunk = "\n============================================\n"
        chunk = chunk .. string.format("SCRIPT [%d]\n", i)
        chunk = chunk .. "Game: " .. GameName .. "\n"
        chunk = chunk .. "Container: " .. r.container .. "\n"
        chunk = chunk .. "Class: " .. r.class .. "\n"
        chunk = chunk .. "Category: " .. (r.category or "Other") .. "\n"
        chunk = chunk .. "Path: " .. r.path .. "\n"
        chunk = chunk .. "Status: " .. r.status .. "\n"
        chunk = chunk .. "============================================\n"
        if r.source then
            chunk = chunk .. r.source .. "\n"
        else
            chunk = chunk .. "-- [NO SOURCE AVAILABLE]\n"
        end

        if type(appendfile) == "function" then
            pcall(appendfile, filename, chunk)
        else
            -- fallback: read current, append, rewrite
            local ok2, existing = pcall(readfile, filename)
            if ok2 and existing then
                pcall(writefile, filename, existing .. chunk)
            end
        end

        if i % 25 == 0 then task.wait(0.02) end
    end

    State.lastFilename = filename
    print("[K]vk Scanner: Saved to " .. filename)
    return filename
end

-- ============================================
-- MAIN SCAN
-- ============================================
local function performScan()
    if State.scanning then return end
    State.scanning = true
    State.results = {}
    State.stats = { total = 0, success = 0, failed = 0, bytecode = 0, client = 0, server = 0, module = 0 }

    if not ProgressGui or not ProgressGui.Parent then buildProgressGUI() end
    ProgressGui.Enabled = true
    updateProgress(0, 1, "Counting", "scripts...")

    local containers = getContainers()

    -- Pass 1: Count
    local totalScripts = 0
    for _, containerData in ipairs(containers) do
        local container = containerData[1]
        if container then
            local descendants = State.maxDepth > 0 and getDescendantsWithDepth(container, State.maxDepth) or container:GetDescendants()
            for _, child in pairs(descendants) do
                if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    totalScripts = totalScripts + 1
                end
            end
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
            local descendants = State.maxDepth > 0 and getDescendantsWithDepth(container, State.maxDepth) or container:GetDescendants()
            for _, child in pairs(descendants) do
                if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    current = current + 1
                    local path = child:GetFullName()
                    local className = child.ClassName
                    updateProgress(current, totalScripts, name, path)

                    local src, status = getScriptSource(child)

                    if status == "OK" then State.stats.success = State.stats.success + 1
                    elseif status == "BYTECODE" then State.stats.bytecode = State.stats.bytecode + 1
                    else State.stats.failed = State.stats.failed + 1 end

                    if className == "LocalScript" then State.stats.client = State.stats.client + 1
                    elseif className == "Script" then State.stats.server = State.stats.server + 1
                    elseif className == "ModuleScript" then State.stats.module = State.stats.module + 1 end

                    local category = categorizeScript(path, className)

                    table.insert(State.results, {
                        path = path, class = className, status = status,
                        source = src, container = name, category = category, instance = child,
                    })

                    if current % 10 == 0 then task.wait(0.01) end
                end
            end
        end
    end

    -- AUTO-SAVE (FIXED — now actually saves)
    updateProgress(totalScripts, totalScripts, "Saving", "to executor workspace...")
    task.wait(0.3)
    local savedFile = autoSaveDump()

    ProgressGui.Enabled = false
    State.scanning = false

    if savedFile then
        safeNotify("Scan Complete & Saved",
            string.format("%d scripts | OK: %d | Failed: %d\nSaved: %s",
                State.stats.total, State.stats.success, State.stats.failed, savedFile))
    else
        safeNotify("Scan Complete (Save Failed)",
            string.format("%d scripts | OK: %d | Failed: %d\nwritefile unavailable — use Export tab",
                State.stats.total, State.stats.success, State.stats.failed))
    end
end

-- ============================================
-- REMOTE SCANNER
-- ============================================
local function scanRemotes()
    local remotes = { events = {}, functions = {} }
    local function scanContainer(container)
        pcall(function()
            for _, desc in pairs(container:GetDescendants()) do
                if desc:IsA("RemoteEvent") then
                    table.insert(remotes.events, { path = desc:GetFullName(), name = desc.Name, instance = desc })
                elseif desc:IsA("RemoteFunction") then
                    table.insert(remotes.functions, { path = desc:GetFullName(), name = desc.Name, instance = desc })
                end
            end
        end)
    end
    scanContainer(ReplicatedStorage)
    scanContainer(Workspace)
    return remotes
end

-- ============================================
-- OBJECT SCANNER
-- ============================================
local function scanObjects()
    local objects = { proximityPrompts = {}, clickDetectors = {}, humanoids = {}, spawnLocations = {} }
    pcall(function()
        for _, desc in pairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                table.insert(objects.proximityPrompts, { path = desc:GetFullName(), name = desc.Name, parent = desc.Parent and desc.Parent.Name or "", holdDuration = desc.HoldDuration })
            elseif desc:IsA("ClickDetector") then
                table.insert(objects.clickDetectors, { path = desc:GetFullName(), name = desc.Name })
            elseif desc:IsA("SpawnLocation") then
                table.insert(objects.spawnLocations, { path = desc:GetFullName(), name = desc.Name, position = tostring(desc.Position) })
            end
        end
    end)
    pcall(function()
        for _, desc in pairs(Workspace:GetDescendants()) do
            if desc:IsA("Model") then
                local hum = desc:FindFirstChildOfClass("Humanoid")
                if hum and not Players:GetPlayerFromCharacter(desc) then
                    table.insert(objects.humanoids, { path = desc:GetFullName(), name = desc.Name, health = hum.Health, maxHealth = hum.MaxHealth, walkSpeed = hum.WalkSpeed })
                end
            end
        end
    end)
    return objects
end

-- ============================================
-- KEYWORD SEARCH
-- ============================================
local function searchKeywords(keywords)
    local results = {}
    for _, kw in ipairs(keywords) do
        local kwResults = { keyword = kw, matches = {} }
        for _, r in ipairs(State.results) do
            if r.source and r.status == "OK" then
                local sourceLower = r.source:lower()
                local searchKw = kw:lower()
                local startPos = sourceLower:find(searchKw, 1, true)
                while startPos do
                    local lineNum = 1
                    local lineStart = 1
                    for i = 1, startPos - 1 do
                        if r.source:sub(i, i) == "\n" then lineNum = lineNum + 1 lineStart = i + 1 end
                    end
                    local lineEnd = r.source:find("\n", startPos, true) or #r.source
                    local lineText = r.source:sub(lineStart, math.min(lineEnd, lineStart + 200))
                    table.insert(kwResults.matches, { script = r.path, line = lineNum, text = lineText:gsub("^%s+", ""):sub(1, 150), category = r.category })
                    startPos = sourceLower:find(searchKw, startPos + 1, true)
                end
            end
        end
        table.insert(results, kwResults)
    end
    return results
end

-- ============================================
-- EXECUTOR CHECK
-- ============================================
local function checkExecutor()
    local caps = {}
    local funcs = {
        { "firetouchinterest", "Fire touch events" }, { "fireproximityprompt", "Fire proximity prompts" },
        { "getrawmetatable", "Get raw metatable" }, { "setreadonly", "Set table readonly" },
        { "setclipboard", "Copy to clipboard" }, { "writefile", "Write files" },
        { "readfile", "Read files" }, { "appendfile", "Append to files" },
        { "makefolder", "Create folders" }, { "decompile", "Decompile scripts" },
        { "getsrc", "Get script source" }, { "getscriptbytecode", "Get bytecode" },
        { "gethui", "Get CoreGui parent" }, { "getgenv", "Global env" },
        { "loadstring", "Load string" }, { "request", "HTTP request" },
        { "setsimulationradius", "Set sim radius" },
    }
    for _, f in ipairs(funcs) do
        local available = false
        pcall(function()
            local env = getfenv()
            if type(env[f[1]]) == "function" then available = true end
        end)
        table.insert(caps, { name = f[1], desc = f[2], available = available })
    end
    return caps
end

-- ============================================
-- TEAM & LEADERSTAT SCANNER
-- ============================================
local function scanTeamsAndStats()
    local data = { teams = {}, leaderstats = {} }
    pcall(function()
        for _, team in pairs(Teams:GetChildren()) do
            if team:IsA("Team") then
                table.insert(data.teams, { name = team.Name, color = tostring(team.TeamColor.Color), players = #team:GetPlayers(), autoAssignable = team.AutoAssignable })
            end
        end
    end)
    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            for _, stat in pairs(ls:GetChildren()) do
                table.insert(data.leaderstats, { name = stat.Name, class = stat.ClassName, value = tostring(stat.Value) })
            end
        end
    end)
    return data
end

-- ============================================
-- GUI SCANNER
-- ============================================
local function scanGUIs()
    local guis = {}
    local function scanContainer(container, containerName)
        pcall(function()
            for _, desc in pairs(container:GetDescendants()) do
                if desc:IsA("ScreenGui") then
                    local childCount = 0
                    for _ in pairs(desc:GetDescendants()) do childCount = childCount + 1 end
                    table.insert(guis, { path = desc:GetFullName(), name = desc.Name, container = containerName, enabled = desc.Enabled, childCount = childCount })
                end
            end
        end)
    end
    scanContainer(StarterGui, "StarterGui")
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then scanContainer(pg, "PlayerGui") end
    return guis
end

-- ============================================
-- TOUCH EVENT DETECTOR
-- ============================================
local function scanTouchEvents()
    local touches = {}
    for _, r in ipairs(State.results) do
        if r.source and r.status == "OK" then
            if r.source:lower():find("touched") then
                local lines = r.source:split("\n")
                for lineNum, line in ipairs(lines) do
                    if line:lower():find("touched") then
                        table.insert(touches, { script = r.path, line = lineNum, text = line:gsub("^%s+", ""):sub(1, 150), category = r.category })
                    end
                end
            end
        end
    end
    return touches
end

-- ============================================
-- REMOTE SNIFFER
-- ============================================
local function startRemoteSniffer()
    local snifferData = {}
    local mt = getrawmetatable(game)
    if not mt then return snifferData, nil end

    local oldNamecall
    pcall(function()
        setreadonly(mt, false)
        oldNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                local args = {...}
                local argStr = ""
                for i, arg in ipairs(args) do
                    if i > 1 then argStr = argStr .. ", " end
                    if type(arg) == "string" then argStr = argStr .. '"' .. arg:sub(1, 50) .. '"'
                    elseif type(arg) == "number" then argStr = argStr .. tostring(arg)
                    elseif type(arg) == "boolean" then argStr = argStr .. tostring(arg)
                    elseif typeof(arg) == "Instance" then argStr = argStr .. arg.ClassName
                    else argStr = argStr .. type(arg) end
                end
                table.insert(snifferData, { remote = self:GetFullName(), remoteName = self.Name, method = method, args = argStr, time = os.date("%H:%M:%S") })
                if #snifferData > 500 then table.remove(snifferData, 1) end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end)

    return snifferData, function()
        pcall(function()
            setreadonly(mt, false)
            mt.__namecall = oldNamecall
            setreadonly(mt, true)
        end)
    end
end

-- ============================================
-- JSON EXPORT
-- ============================================
local function exportJSON(data, filename)
    if type(writefile) ~= "function" then return nil end
    local json = HttpService:JSONEncode(data)
    pcall(writefile, filename, json)
    return filename
end

-- ============================================
-- RAYFIELD
-- ============================================
pcall(function()
    Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()
end)
if not Rayfield then
    pcall(function()
        Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
end
if not Rayfield then warn("[K]vk Scanner: Rayfield failed to load.") return end

local Window = Rayfield:CreateWindow({
    Name = "Universal Scanner v6.1 — " .. GameName,
    LoadingTitle = "Scanning " .. GameName,
    LoadingSubtitle = "v6.1 — Auto-Save Fixed",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySettings = { Key = Enum.KeyCode.RightControl, OnPress = function() end }
})

-- ============================================
-- TAB: SCANNER
-- ============================================
local TabScan = Window:CreateTab("Scanner")

TabScan:CreateButton({ Name = "Scan Game", Callback = function() performScan() end })

TabScan:CreateSlider({ Name = "Max Scan Depth (0 = Unlimited)", Range = {0, 10}, Increment = 1, Suffix = "levels", CurrentValue = 0, Flag = "MaxDepth", Callback = function(val) State.maxDepth = val end })

TabScan:CreateButton({ Name = "Clear Results", Callback = function()
    State.results = {}
    State.stats = { total = 0, success = 0, failed = 0, bytecode = 0, client = 0, server = 0, module = 0 }
    State.lastFilename = ""
    safeNotify("Scanner", "Results cleared.")
end })

TabScan:CreateButton({ Name = "Show Stats", Callback = function()
    safeNotify(GameName, string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d\nClient: %d | Server: %d | Module: %d",
        State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed, State.stats.client, State.stats.server, State.stats.module))
end })

TabScan:CreateButton({ Name = "Show Category Breakdown", Callback = function()
    local cats = {}
    for _, r in ipairs(State.results) do cats[r.category or "Other"] = (cats[r.category or "Other"] or 0) + 1 end
    local text = ""
    for cat, count in pairs(cats) do text = text .. cat .. ": " .. count .. "\n" end
    if text == "" then text = "No results." end
    print("=== Category Breakdown ===\n" .. text)
    safeNotify("Categories", text)
end })

-- ============================================
-- TAB: REMOTES
-- ============================================
local TabRemote = Window:CreateTab("Remotes")

TabRemote:CreateButton({ Name = "Scan Remote Events & Functions", Callback = function()
    local remotes = scanRemotes()
    print("=== REMOTE SCAN ===\nRemoteEvents: " .. #remotes.events .. " | RemoteFunctions: " .. #remotes.functions)
    for _, r in ipairs(remotes.events) do print("  [Event] " .. r.path) end
    for _, r in ipairs(remotes.functions) do print("  [Func] " .. r.path) end
    safeNotify("Remotes", string.format("%d Events + %d Functions. Check F9.", #remotes.events, #remotes.functions))
end })

TabRemote:CreateButton({ Name = "Copy All Remote Paths", Callback = function()
    if type(setclipboard) ~= "function" then safeNotify("Error", "setclipboard not available") return end
    local remotes = scanRemotes()
    local text = "=== Remote Events ===\n"
    for _, r in ipairs(remotes.events) do text = text .. r.path .. "\n" end
    text = text .. "\n=== Remote Functions ===\n"
    for _, r in ipairs(remotes.functions) do text = text .. r.path .. "\n" end
    pcall(setclipboard, text)
    safeNotify("Remotes", "Copied to clipboard!")
end })

TabRemote:CreateButton({ Name = "Export Remote List to File", Callback = function()
    if type(writefile) ~= "function" then safeNotify("Error", "writefile not available") return end
    local remotes = scanRemotes()
    local content = "Remotes for " .. GameName .. "\n" .. string.rep("-", 80) .. "\nEVENTS:\n"
    for _, r in ipairs(remotes.events) do content = content .. r.path .. "\n" end
    content = content .. "\nFUNCTIONS:\n"
    for _, r in ipairs(remotes.functions) do content = content .. r.path .. "\n" end
    local filename = "remotes_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    pcall(writefile, filename, content)
    safeNotify("Exported", "Saved to: " .. filename)
end })

local snifferStop = nil
TabRemote:CreateToggle({ Name = "Remote Argument Sniffer", CurrentValue = false, Flag = "Sniffer", Callback = function(state)
    if state then
        State.remoteSniffData, snifferStop = startRemoteSniffer()
        safeNotify("Sniffer", "Active. Fire any remote to log.")
    else
        if snifferStop then snifferStop() snifferStop = nil end
        print("=== SNIFFER DATA ===")
        for _, e in ipairs(State.remoteSniffData) do print(string.format("[%s] %s (%s) args: %s", e.time, e.remoteName, e.method, e.args)) end
        safeNotify("Sniffer", string.format("Stopped. %d calls logged. Check F9.", #State.remoteSniffData))
    end
end })

TabRemote:CreateButton({ Name = "Copy Sniffer Data", Callback = function()
    if type(setclipboard) ~= "function" then return end
    local text = "=== SNIFFER DATA ===\n"
    for _, e in ipairs(State.remoteSniffData) do text = text .. string.format("[%s] %s (%s) args: %s\n", e.time, e.remoteName, e.method, e.args) end
    pcall(setclipboard, text)
    safeNotify("Sniffer", "Copied!")
end })

-- ============================================
-- TAB: OBJECTS
-- ============================================
local TabObjects = Window:CreateTab("Objects")

TabObjects:CreateButton({ Name = "Scan Workspace Objects", Callback = function()
    local obj = scanObjects()
    print("=== OBJECT SCAN ===")
    print(string.format("ProximityPrompts: %d | ClickDetectors: %d | NPCs: %d | Spawns: %d", #obj.proximityPrompts, #obj.clickDetectors, #obj.humanoids, #obj.spawnLocations))
    for _, p in ipairs(obj.proximityPrompts) do print("  [Prompt] " .. p.path) end
    for _, c in ipairs(obj.clickDetectors) do print("  [Click] " .. c.path) end
    for _, h in ipairs(obj.humanoids) do print(string.format("  [NPC] %s | HP: %.0f/%.0f | Speed: %.0f", h.path, h.health, h.maxHealth, h.walkSpeed)) end
    for _, s in ipairs(obj.spawnLocations) do print("  [Spawn] " .. s.path) end
    safeNotify("Objects", string.format("Prompts: %d | Clicks: %d | NPCs: %d | Spawns: %d", #obj.proximityPrompts, #obj.clickDetectors, #obj.humanoids, #obj.spawnLocations))
end })

TabObjects:CreateButton({ Name = "Copy Object List", Callback = function()
    if type(setclipboard) ~= "function" then return end
    local obj = scanObjects()
    local text = "=== ProximityPrompts ===\n"
    for _, p in ipairs(obj.proximityPrompts) do text = text .. p.path .. "\n" end
    text = text .. "\n=== ClickDetectors ===\n"
    for _, c in ipairs(obj.clickDetectors) do text = text .. c.path .. "\n" end
    text = text .. "\n=== NPCs ===\n"
    for _, h in ipairs(obj.humanoids) do text = text .. string.format("%s | HP: %.0f/%.0f | Speed: %.0f\n", h.path, h.health, h.maxHealth, h.walkSpeed) end
    text = text .. "\n=== SpawnLocations ===\n"
    for _, s in ipairs(obj.spawnLocations) do text = text .. s.path .. "\n" end
    pcall(setclipboard, text)
    safeNotify("Objects", "Copied!")
end })

-- ============================================
-- TAB: KEYWORD SEARCH
-- ============================================
local TabSearch = Window:CreateTab("Keyword Search")

local searchInput = "FireServer, WalkSpeed, Gravity, Health, Currency, Rebirth, Spin, Buy, Reward, Touched"

TabSearch:CreateInput({ Name = "Keywords (comma separated)", PlaceholderText = "FireServer, WalkSpeed...", RemoveTextWhenFocusLost = false, Callback = function(text) searchInput = text or "" end })

TabSearch:CreateButton({ Name = "Search All Scripts", Callback = function()
    if #State.results == 0 then safeNotify("Error", "Run a scan first.") return end
    local keywords = {}
    for kw in searchInput:gmatch("[^,]+") do kw = kw:gsub("^%s+", ""):gsub("%s+$", "") if #kw > 0 then table.insert(keywords, kw) end end
    local results = searchKeywords(keywords)
    local total = 0
    print("=== KEYWORD SEARCH ===")
    for _, kr in ipairs(results) do
        print(string.format("\n--- '%s' (%d matches) ---", kr.keyword, #kr.matches))
        for _, m in ipairs(kr.matches) do print(string.format("  [%s:%d] %s", m.script, m.line, m.text)) total = total + 1 end
    end
    safeNotify("Search", string.format("%d matches across %d keywords. Check F9.", total, #keywords))
end })

TabSearch:CreateButton({ Name = "Quick Search: FireServer", Callback = function()
    if #State.results == 0 then return end
    local results = searchKeywords({"FireServer"})
    print("=== FireServer REFERENCES ===")
    for _, m in ipairs(results[1].matches) do print(string.format("  [%s:%d] %s", m.script, m.line, m.text)) end
    safeNotify("Search", string.format("%d FireServer refs. Check F9.", #results[1].matches))
end })

TabSearch:CreateButton({ Name = "Quick Search: Touched Events", Callback = function()
    if #State.results == 0 then return end
    local touches = scanTouchEvents()
    print("=== TOUCH EVENTS ===")
    for _, t in ipairs(touches) do print(string.format("  [%s:%d] %s", t.script, t.line, t.text)) end
    safeNotify("Search", string.format("%d touch events. Check F9.", #touches))
end })

TabSearch:CreateButton({ Name = "Copy Search Results", Callback = function()
    if #State.results == 0 or type(setclipboard) ~= "function" then return end
    local keywords = {}
    for kw in searchInput:gmatch("[^,]+") do kw = kw:gsub("^%s+", ""):gsub("%s+$", "") if #kw > 0 then table.insert(keywords, kw) end end
    local results = searchKeywords(keywords)
    local text = ""
    for _, kr in ipairs(results) do
        text = text .. string.format("--- '%s' (%d matches) ---\n", kr.keyword, #kr.matches)
        for _, m in ipairs(kr.matches) do text = text .. string.format("[%s:%d] %s\n", m.script, m.line, m.text) end
        text = text .. "\n"
    end
    pcall(setclipboard, text)
    safeNotify("Search", "Copied!")
end })

-- ============================================
-- TAB: EXECUTOR
-- ============================================
local TabExec = Window:CreateTab("Executor")

TabExec:CreateButton({ Name = "Check Executor Capabilities", Callback = function()
    local caps = checkExecutor()
    local available = 0
    print("=== EXECUTOR CAPABILITIES ===")
    for _, c in ipairs(caps) do
        local status = c.available and "YES" or "NO"
        print(string.format("  %-25s %-25s %s", c.name, c.desc, status))
        if c.available then available = available + 1 end
    end
    safeNotify("Executor", string.format("%d/%d available. Check F9.", available, #caps))
end })

TabExec:CreateButton({ Name = "Copy Capability List", Callback = function()
    if type(setclipboard) ~= "function" then return end
    local caps = checkExecutor()
    local text = "=== EXECUTOR CAPABILITIES ===\n"
    for _, c in ipairs(caps) do text = text .. string.format("%-25s %-25s %s\n", c.name, c.desc, c.available and "YES" or "NO") end
    pcall(setclipboard, text)
    safeNotify("Executor", "Copied!")
end })

-- ============================================
-- TAB: TEAMS & STATS
-- ============================================
local TabTeams = Window:CreateTab("Teams & Stats")

TabTeams:CreateButton({ Name = "Scan Teams", Callback = function()
    local data = scanTeamsAndStats()
    print("=== TEAMS ===")
    for _, t in ipairs(data.teams) do print(string.format("  %s | Color: %s | Players: %d", t.name, t.color, t.players)) end
    safeNotify("Teams", string.format("%d teams. Check F9.", #data.teams))
end })

TabTeams:CreateButton({ Name = "Scan Leaderstats", Callback = function()
    local data = scanTeamsAndStats()
    print("=== LEADERSTATS ===")
    for _, s in ipairs(data.leaderstats) do print(string.format("  %s (%s) = %s", s.name, s.class, s.value)) end
    safeNotify("Stats", string.format("%d stats. Check F9.", #data.leaderstats))
end })

TabTeams:CreateButton({ Name = "Copy Teams & Stats", Callback = function()
    if type(setclipboard) ~= "function" then return end
    local data = scanTeamsAndStats()
    local text = "=== TEAMS ===\n"
    for _, t in ipairs(data.teams) do text = text .. string.format("%s | %s | Players: %d\n", t.name, t.color, t.players) end
    text = text .. "\n=== LEADERSTATS ===\n"
    for _, s in ipairs(data.leaderstats) do text = text .. string.format("%s (%s) = %s\n", s.name, s.class, s.value) end
    pcall(setclipboard, text)
    safeNotify("Teams", "Copied!")
end })

-- ============================================
-- TAB: GUI SCANNER
-- ============================================
local TabGUI = Window:CreateTab("GUI Scanner")

TabGUI:CreateButton({ Name = "Scan All ScreenGuis", Callback = function()
    local guis = scanGUIs()
    print("=== GUI SCAN ===")
    for _, g in ipairs(guis) do print(string.format("  [%s] %s | Enabled: %s | Children: %d", g.container, g.path, tostring(g.enabled), g.childCount)) end
    safeNotify("GUI", string.format("%d ScreenGuis. Check F9.", #guis))
end })

TabGUI:CreateButton({ Name = "Copy GUI List", Callback = function()
    if type(setclipboard) ~= "function" then return end
    local guis = scanGUIs()
    local text = "=== SCREEN GUIS ===\n"
    for _, g in ipairs(guis) do text = text .. string.format("[%s] %s | Enabled: %s | Children: %d\n", g.container, g.path, tostring(g.enabled), g.childCount) end
    pcall(setclipboard, text)
    safeNotify("GUI", "Copied!")
end })

-- ============================================
-- TAB: SCRIPT VIEWER
-- ============================================
local TabViewer = Window:CreateTab("Script Viewer")

TabViewer:CreateButton({ Name = "List All Scripts", Callback = function()
    if #State.results == 0 then safeNotify("Error", "Run a scan first.") return end
    print("=== SCRIPT LIST ===")
    for i, r in ipairs(State.results) do
        local t = r.class == "LocalScript" and "[CLIENT]" or r.class == "Script" and "[SERVER]" or "[MODULE]"
        print(string.format("  [%d] %s %s (%s) [%s]", i, t, r.path, r.status, r.category or "Other"))
    end
    safeNotify("Viewer", string.format("%d scripts. Check F9.", #State.results))
end })

TabViewer:CreateInput({ Name = "Search Scripts by Name", PlaceholderText = "Type name...", RemoveTextWhenFocusLost = false, Callback = function(text)
    if not text or #text < 2 then return end
    local results = {}
    for i, r in ipairs(State.results) do
        if r.path:lower():find(text:lower(), 1, true) then table.insert(results, { index = i, data = r }) end
    end
    print(string.format("=== SEARCH: '%s' (%d) ===", text, #results))
    for _, e in ipairs(results) do
        local t = e.data.class == "LocalScript" and "[CLIENT]" or e.data.class == "Script" and "[SERVER]" or "[MODULE]"
        print(string.format("  [%d] %s %s (%s)", e.index, t, e.data.path, e.data.status))
    end
    safeNotify("Search", string.format("%d matches. Check F9.", #results))
end })

TabViewer:CreateButton({ Name = "Copy Selected Script Source", Callback = function()
    if not State.selectedScript then safeNotify("Error", "Search for a script first.") return end
    local r = State.results[State.selectedScript]
    if r and r.source and type(setclipboard) == "function" then pcall(setclipboard, r.source) safeNotify("Viewer", "Copied!") end
end })

TabViewer:CreateButton({ Name = "Save Selected Script to File", Callback = function()
    if not State.selectedScript then return end
    if type(writefile) ~= "function" then return end
    local r = State.results[State.selectedScript]
    if r and r.source then
        local sp = r.path:gsub("[^%w%-_]", "_") if #sp > 80 then sp = sp:sub(-80) end
        local filename = string.format("script_%03d_%s.lua", State.selectedScript, sp)
        pcall(writefile, filename, string.format("-- %s\n-- %s\n-- %s\n%s\n", GameName, r.path, r.status, r.source))
        safeNotify("Saved", filename)
    end
end })

-- ============================================
-- TAB: DIFF MODE
-- ============================================
local TabDiff = Window:CreateTab("Diff Mode")

TabDiff:CreateButton({ Name = "Save Current Scan as Baseline", Callback = function()
    if #State.results == 0 then safeNotify("Error", "Run a scan first.") return end
    State.lastScanResults = {}
    for _, r in ipairs(State.results) do table.insert(State.lastScanResults, { path = r.path, class = r.class, status = r.status, category = r.category }) end
    safeNotify("Diff", string.format("Baseline saved: %d scripts.", #State.lastScanResults))
end })

TabDiff:CreateButton({ Name = "Compare vs Baseline", Callback = function()
    if not State.lastScanResults or #State.lastScanResults == 0 then safeNotify("Error", "Save baseline first.") return end
    if #State.results == 0 then safeNotify("Error", "Run a scan first.") return end
    local base = {} for _, r in ipairs(State.lastScanResults) do base[r.path] = r end
    local curr = {} for _, r in ipairs(State.results) do curr[r.path] = r end
    local added, removed, changed = {}, {}, {}
    for _, r in ipairs(State.results) do if not base[r.path] then table.insert(added, r.path) elseif base[r.path].status ~= r.status or base[r.path].category ~= r.category then table.insert(changed, { path = r.path, old = base[r.path].status, new = r.status }) end end
    for _, r in ipairs(State.lastScanResults) do if not curr[r.path] then table.insert(removed, r.path) end end
    print("=== DIFF REPORT ===")
    print(string.format("Added: %d | Removed: %d | Changed: %d", #added, #removed, #changed))
    for _, p in ipairs(added) do print("  + " .. p) end
    for _, p in ipairs(removed) do print("  - " .. p) end
    for _, c in ipairs(changed) do print(string.format("  * %s (%s->%s)", c.path, c.old, c.new)) end
    safeNotify("Diff", string.format("Added: %d | Removed: %d | Changed: %d. Check F9.", #added, #removed, #changed))
end })

-- ============================================
-- TAB: EXPORT
-- ============================================
local TabExport = Window:CreateTab("Export")

TabExport:CreateButton({ Name = "Re-export Full Dump (.txt)", Callback = function()
    if #State.results == 0 then safeNotify("Error", "Run a scan first.") return end
    local file = autoSaveDump()
    if file then safeNotify("Exported", "Saved to: " .. file) else safeNotify("Error", "Export failed.") end
end })

TabExport:CreateButton({ Name = "Export as JSON", Callback = function()
    if #State.results == 0 then return end
    local data = { game = GameName, placeId = game.PlaceId, date = os.date("%Y-%m-%d %H:%M:%S"), stats = State.stats, scripts = {} }
    for i, r in ipairs(State.results) do table.insert(data.scripts, { index = i, path = r.path, class = r.class, status = r.status, category = r.category, container = r.container, hasSource = r.source ~= nil }) end
    local filename = "scan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
    if exportJSON(data, filename) then safeNotify("Exported", "JSON: " .. filename) else safeNotify("Error", "JSON export failed.") end
end })

TabExport:CreateButton({ Name = "Export Index Only", Callback = function()
    if #State.results == 0 then return end
    if type(writefile) ~= "function" then return end
    local content = "Index for " .. GameName .. "\n" .. string.rep("-", 120) .. "\n"
    for i, r in ipairs(State.results) do content = content .. string.format("[%d] %s | %s | %s | %s\n", i, r.container, r.class, r.status, r.path) end
    local filename = "index_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    pcall(writefile, filename, content)
    safeNotify("Exported", filename)
end })

TabExport:CreateButton({ Name = "Copy All Source Code", Callback = function()
    if #State.results == 0 or type(setclipboard) ~= "function" then return end
    local text = ""
    for _, r in ipairs(State.results) do if r.source and r.status == "OK" then text = text .. "-- " .. r.path .. "\n" .. r.source .. "\n\n" end end
    pcall(setclipboard, text)
    safeNotify("Exported", "All source copied!")
end })

TabExport:CreateButton({ Name = "Copy Stats", Callback = function()
    if #State.results == 0 or type(setclipboard) ~= "function" then return end
    local text = "Game: " .. GameName .. "\nTotal: " .. State.stats.total .. " | OK: " .. State.stats.success .. " | Failed: " .. State.stats.failed .. "\n"
    local cats = {} for _, r in ipairs(State.results) do cats[r.category or "Other"] = (cats[r.category or "Other"] or 0) + 1 end
    text = text .. "\nCategories:\n" for cat, count in pairs(cats) do text = text .. "  " .. cat .. ": " .. count .. "\n" end
    pcall(setclipboard, text)
    safeNotify("Exported", "Stats copied!")
end })

TabExport:CreateButton({ Name = "Show Last Saved File", Callback = function()
    if State.lastFilename == "" then safeNotify("Error", "No file saved yet.") return end
    safeNotify("Last File", State.lastFilename)
end })

-- ============================================
-- INIT
-- ============================================
Rayfield:LoadConfiguration()
print("[Universal Scanner v6.1] Loaded — Game: " .. GameName)
print("Press Right Ctrl to toggle.")
