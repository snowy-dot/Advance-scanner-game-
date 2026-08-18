--!nocheck
-- Universal Game Scanner v7 — [K]vk Advanced Edition
-- Auto-scans remotes, objects, teams, stats, GUI, executor, keywords
-- Deep Scan: 5-minute live monitoring of game interactions, monster movement, object spawning
-- Auto-saves everything to organized files
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
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
    deepScanning = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0, client = 0, server = 0, module = 0 },
    lastFilename = "",
    maxDepth = 0,
    -- auto-collected data
    remotes = { events = {}, functions = {} },
    objects = { prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, touchParts = {} },
    teams = {},
    leaderstats = {},
    guis = {},
    executorCaps = {},
    keywordResults = {},
    touchEvents = {},
    -- deep scan data
    deepData = {
        promptInteractions = {},
        touchInteractions = {},
        monsterSpawns = {},
        monsterMoves = {},
        workspaceAdds = {},
        remoteCalls = {},
        playerPositions = {},
        startTime = 0,
    },
    autoRunComplete = false,
}

local connections = {}
local ProgressGui, ProgressFill, ProgressLabel, ProgressPercent, ProgressDetail, ProgressTrack

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

local function updateProgress(current, total, label, detail)
    local pct = 0
    if total > 0 then pct = math.floor((current / total) * 100) end
    ProgressFill.Size = UDim2.new(pct / 100, 0, 1, 0)
    ProgressPercent.Text = tostring(pct) .. "%"
    ProgressLabel.Text = label or ""
    local d = detail or ""
    if #d > 55 then d = "..." .. d:sub(-52) end
    ProgressDetail.Text = d
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
-- REMOTE SCANNER (AUTO)
-- ============================================
local function autoScanRemotes()
    State.remotes = { events = {}, functions = {} }
    local function scanContainer(container)
        pcall(function()
            for _, desc in pairs(container:GetDescendants()) do
                if desc:IsA("RemoteEvent") then
                    table.insert(State.remotes.events, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        parent = desc.Parent and desc.Parent.Name or "",
                        location = desc:GetFullName():split(".")[1] or "",
                    })
                elseif desc:IsA("RemoteFunction") then
                    table.insert(State.remotes.functions, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        parent = desc.Parent and desc.Parent.Name or "",
                        location = desc:GetFullName():split(".")[1] or "",
                    })
                end
            end
        end)
    end
    scanContainer(ReplicatedStorage)
    scanContainer(Workspace)
    pcall(function() scanContainer(game:GetService("ServerScriptService") end)
    print(string.format("[Auto] Remotes: %d Events, %d Functions", #State.remotes.events, #State.remotes.functions))
    return State.remotes
end

-- ============================================
-- OBJECT SCANNER (AUTO)
-- ============================================
local function autoScanObjects()
    State.objects = { prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, touchParts = {} }
    pcall(function()
        for _, desc in pairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                table.insert(State.objects.prompts, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    parent = desc.Parent and desc.Parent.Name or "",
                    gp = desc.Parent and desc.Parent.Parent and desc.Parent.Parent.Name or "",
                    holdDuration = desc.HoldDuration,
                    enabled = desc.Enabled,
                    actionText = desc.ActionText or "",
                    objectText = desc.ObjectText or "",
                })
            elseif desc:IsA("ClickDetector") then
                table.insert(State.objects.clickDetectors, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    parent = desc.Parent and desc.Parent.Name or "",
                })
            elseif desc:IsA("SpawnLocation") then
                table.insert(State.objects.spawns, {
                    path = desc.GetFullName and desc:GetFullName() or desc.Name,
                    name = desc.Name,
                    position = tostring(desc.Position),
                    duration = desc.Duration,
                    neutral = desc.Neutral,
                })
            end
        end
    end)
    -- NPCs/Monsters with Humanoid
    pcall(function()
        for _, desc in pairs(Workspace:GetDescendants()) do
            if desc:IsA("Model") then
                local hum = desc:FindFirstChildOfClass("Humanoid")
                if hum and not Players:GetPlayerFromCharacter(desc) then
                    local root = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChild("RootPart") or desc.PrimaryPart
                    table.insert(State.objects.humanoids, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        health = hum.Health,
                        maxHealth = hum.MaxHealth,
                        walkSpeed = hum.WalkSpeed,
                        jumpHeight = hum.JumpHeight,
                        position = root and tostring(root.Position) or "unknown",
                        hasAnimator = desc:FindFirstChildOfClass("Animator) ~= nil,
                        childCount = #desc:GetChildren(),
                        children = (function()
                            local names = {}
                            for _, c in pairs(desc:GetChildren()) do table.insert(names, c.Name) end
                            return table.concat(names, ", ")
                        end)(),
                    })
                end
            end
        end
    end)
    print(string.format("[Auto] Objects: %d Prompts, %d ClickDetectors, %d NPCs, %d Spawns",
        #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns))
    return State.objects
end

-- ============================================
-- TEAMS & STATS SCANNER (AUTO)
-- ============================================
local function autoScanTeamsStats()
    State.teams = {}
    State.leaderstats = {}
    pcall(function()
        for _, team in pairs(Teams:GetChildren()) do
            if team:IsA("Team") then
                table.insert(State.teams, {
                    name = team.Name,
                    color = tostring(team.TeamColor.Color),
                    players = #team:GetPlayers(),
                    autoAssignable = team.AutoAssignable,
                    playerNames = (function()
                        local names = {}
                        for _, p in pairs(team:GetPlayers()) do table.insert(names, p.Name) end
                        return table.concat(names, ", ")
                    end)(),
                })
            end
        end
    end)
    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            for _, stat in pairs(ls:GetChildren()) do
                table.insert(State.leaderstats, {
                    name = stat.Name,
                    class = stat.ClassName,
                    value = tostring(stat.Value),
                })
            end
        end
    end)
    print(string.format("[Auto] Teams: %d, Leaderstats: %d", #State.teams, #State.leaderstats))
    return { teams = State.teams, leaderstats = State.leaderstats }
end

-- ============================================
-- GUI SCANNER (AUTO)
-- ============================================
local function autoScanGUIs()
    State.guis = {}
    local function scanContainer(container, containerName)
        pcall(function()
            for _, desc in pairs(container:GetDescendants()) do
                if desc:IsA("ScreenGui") then
                    local childCount = 0
                    for _ in pairs(desc:GetDescendants()) do childCount = childCount + 1 end
                    table.insert(State.guis, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        container = containerName,
                        enabled = desc.Enabled,
                        childCount = childCount,
                    })
                end
            end
        end)
    end
    scanContainer(StarterGui, "StarterGui")
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then scanContainer(pg, "PlayerGui") end
    print(string.format("[Auto] GUIs: %d ScreenGuis", #State.guis))
    return State.guis
end

-- ============================================
-- EXECUTOR CHECK (AUTO)
-- ============================================
local function autoCheckExecutor()
    State.executorCaps = {}
    local funcs = {
        { "firetouchinterest", "Fire touch events" }, { "fireproximityprompt", "Fire proximity prompts" },
        { "getrawmetatable", "Get raw metatable" }, { "setreadonly", "Set table readonly" },
        { "setclipboard", "Copy to clipboard" }, { "writefile", "Write files" },
        { "readfile", "Read files" }, { "appendfile", "Append to files" },
        { "makefolder", "Create folders" }, { "decompile", "Decompile scripts" },
        { "getsrc", "Get script source" }, { "getscriptbytecode", "Get bytecode" },
        { "gethui", "Get CoreGui parent" }, { "getgenv", "Global env" },
        { "loadstring", "Load string" }, { "request", "HTTP request" },
        { "setsimulationradius", "Set sim radius" }, { "newcclosure", "Anti-tamper closure" },
    }
    local available = 0
    for _, f in ipairs(funcs) do
        local avail = false
        pcall(function()
            local env = getfenv()
            if type(env[f[1]]) == "function" then avail = true available = available + 1 end
        end)
        table.insert(State.executorCaps, { name = f[1], desc = f[2], available = avail })
    end
    print(string.format("[Auto] Executor: %d/%d functions available", available, #State.executorCaps))
    return State.executorCaps
end

-- ============================================
-- KEYWORD SEARCH (AUTO)
-- ============================================
local function autoKeywordSearch()
    if #State.results == 0 then return {} end
    local keywords = {
        "FireServer", "InvokeServer", "WalkSpeed", "Gravity", "Health", "Damage",
        "Currency", "Cash", "Coin", "Rebirth", "Spin", "Buy", "Sell", "Reward",
        "Touched", "ProximityPrompt", "ClickDetector", "Teleport", "CFrame",
        "Humanoid", "Monster", "NPC", "Boss", "RemoteEvent", "RemoteFunction",
        "LocalScript", "Script", "ModuleScript", "Workspace", "ReplicatedStorage",
    }
    State.keywordResults = {}
    local totalMatches = 0
    for _, kw in ipairs(keywords) do
        local kwMatches = { keyword = kw, count = 0, matches = {} }
        for _, r in ipairs(State.results) do
            if r.source and r.status == "OK" then
                local sourceLower = r.source:lower()
                local searchKw = kw:lower()
                local startPos = sourceLower:find(searchKw, 1, true)
                local count = 0
                while startPos do
                    count = count + 1
                    if count <= 3 then
                        local lineNum = 1
                        for i = 1, startPos - 1 do
                            if r.source:sub(i, i) == "\n" then lineNum = lineNum + 1 end
                    end
                    table.insert(kwMatches.matches, { script = r.path, line = lineNum })
                    end
                    startPos = sourceLower:find(searchKw, startPos + 1, true)
                end
                kwMatches.count = kwMatches.count + count
                totalMatches = totalMatches + count
            end
        end
        if kwMatches.count > 0 then
            table.insert(State.keywordResults, kwMatches)
        end
    end
    print(string.format("[Auto] Keywords: %d matches across %d keywords", totalMatches, #State.keywordResults))
    return State.keywordResults
end

-- ============================================
-- TOUCH EVENT DETECTOR (AUTO)
-- ============================================
local function autoScanTouchEvents()
    State.touchEvents = {}
    for _, r in ipairs(State.results) do
        if r.source and r.status == "OK" then
            if r.source:lower():find("touched") then
                local lines = r.source:split("\n")
                for lineNum, line in ipairs(lines) do
                    if line:lower():find("touched") then
                        table.insert(State.touchEvents, {
                            script = r.path,
                            line = lineNum,
                            text = line:gsub("^%s+", ""):sub(1, 150),
                            category = r.category,
                        })
                    end
                end
            end
        end
    end
    print(string.format("[Auto] Touch Events: %d found", #State.touchEvents))
    return State.touchEvents
end

-- ============================================
-- DEEP SCAN — 5-MINUTE LIVE MONITORING
-- ============================================
local function startDeepScan(duration)
    duration = duration or 300 -- 5 minutes default
    if State.deepScanning then return end
    State.deepScanning = true
    State.deepData = {
        promptInteractions = {},
        touchInteractions = {},
        monsterSpawns = {},
        monsterMoves = {},
        workspaceAdds = {},
        remoteCalls = {},
        playerPositions = {},
        startTime = tick(),
    }
    safeNotify("Deep Scan", string.format("Starting %d-second deep monitoring...", duration))
    print("[Deep Scan] Monitoring game for " .. duration .. " seconds...")

    -- 1. Monitor ProximityPrompt triggers
    pcall(function()
        for _, desc in pairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                desc.Triggered:Connect(function(player)
                    if player == LocalPlayer then
                        table.insert(State.deepData.promptInteractions, {
                            time = os.date("%H:%M:%S"),
                            prompt = desc.Name,
                            path = desc:GetFullName(),
                            player = player.Name,
                        })
                        print("[Deep] Prompt triggered: " .. desc.Name .. " at " .. desc:GetFullName())
                    end
                end)
            end
        end
    end)

    -- 2. Monitor Workspace child additions (new objects spawning)
    connections.deepWorkspace = Workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("Model") and desc:FindFirstChildOfClass("Humanoid") then
            local hum = desc:FindFirstChildOfClass("Humanoid")
            local root = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChild("RootPart")
            table.insert(State.deepData.monsterSpawns, {
                time = os.date("%H:%M:%S"),
                name = desc.Name,
                path = desc:GetFullName(),
                health = hum and hum.Health or 0,
                maxHealth = hum and hum.MaxHealth or 0,
                walkSpeed = hum and hum.WalkSpeed or 0,
                position = root and tostring(root.Position) or "unknown",
                childNames = (function()
                    local names = {}
                    for _, c in pairs(desc:GetChildren()) do table.insert(names, c.Name) end
                    return table.concat(names, ", ")
                end)(),
            })
            print("[Deep] Monster/NPC spawned: " .. desc.Name)
        elseif desc:IsA("BasePart") or desc:IsA("Model") then
            table.insert(State.deepData.workspaceAdds, {
                time = os.date("%H:%M:%S"),
                name = desc.Name,
                class = desc.ClassName,
                path = desc:GetFullName(),
            })
        end
    end)

    -- 3. Monitor RemoteEvent calls via __namecall hook
    pcall(function()
        local mt = getrawmetatable(game)
        if mt then
            local oldNamecall
            setreadonly(mt, false)
            oldNamecall = mt.__namecall
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" and self:IsA("RemoteEvent") then
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
                    table.insert(State.deepData.remoteCalls, {
                        time = os.date("%H:%M:%S"),
                        remote = self:GetFullName(),
                        remoteName = self.Name,
                        method = method,
                        args = argStr,
                    })
                    if #State.deepData.remoteCalls > 1000 then table.remove(State.deepData.remoteCalls, 1) end
                end
                return oldNamecall(self, ...)
            end)
            setreadonly(mt, true)
        end
    end)

    -- 4. Monitor monster movement (every 5 seconds)
    connections.deepMonsterMove = RunService.Heartbeat:Connect(function()
        if not State.deepScanning then return end
        local monsters = Workspace:FindFirstChild("Monsters")
        if monsters then
            for _, monster in pairs(monsters:GetChildren()) do
                local root = monster:FindFirstChild("HumanoidRootPart") or monster:FindFirstChild("RootPart")
                if root then
                    -- sample every 5 seconds
                    if not connections.deepMonsterMove._lastSample or (tick() - connections.deepMonsterMove._lastSample) >= 5 then
                        connections.deepMonsterMove._lastSample = tick()
                        local hum = monster:FindFirstChildOfClass("Humanoid")
                        table.insert(State.deepData.monsterMoves, {
                            time = os.date("%H:%M:%S"),
                            name = monster.Name,
                            position = tostring(root.Position),
                            velocity = tostring(root.AssemblyLinearVelocity),
                            walkSpeed = hum and hum.WalkSpeed or 0,
                            health = hum and hum.Health or 0,
                        })
                        if #State.deepData.monsterMoves > 500 then table.remove(State.deepData.monsterMoves, 1) end
                    end
                end
            end
        end
    end)

    -- 5. Track player positions (every 10 seconds)
    connections.deepPlayerPos = RunService.Heartbeat:Connect(function()
        if not State.deepScanning then return end
        if not connections.deepPlayerPos._lastSample or (tick() - connections.deepPlayerPos._lastSample) >= 10 then
            connections.deepPlayerPos._lastSample = tick()
            for _, player in pairs(Players:GetPlayers()) do
                if player.Character then
                    local root = player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        if not State.deepData.playerPositions[player.Name] then
                            State.deepData.playerPositions[player.Name] = {}
                        end
                        table.insert(State.deepData.playerPositions[player.Name], {
                            time = os.date("%H:%M:%S"),
                            position = tostring(root.Position),
                            velocity = tostring(root.AssemblyLinearVelocity.Magnitude),
                        })
                        if #State.deepData.playerPositions[player.Name] > 100 then
                            table.remove(State.deepData.playerPositions[player.Name], 1)
                        end
                    end
            end
            end
        end
    end)

    -- 6. Stop after duration
    task.spawn(function()
        task.wait(duration)
        State.deepScanning = false
        if connections.deepWorkspace then connections.deepWorkspace:Disconnect() connections.deepWorkspace = nil end
        if connections.deepMonsterMove then connections.deepMonsterMove:Disconnect() connections.deepMonsterMove = nil end
        if connections.deepPlayerPos then connections.deepPlayerPos:Disconnect() connections.deepPlayerPos = nil end

        -- save deep scan data
        local filename = "deepscan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
        if type(writefile) == "function" then
            local content = "============================================\n"
            content = content .. "Deep Scan Report — " .. GameName .. "\n"
            content = content .. "Duration: " .. duration .. " seconds\n"
            content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
            content = content .. "============================================\n\n"

            content = content .. string.format("PROMPT INTERACTIONS (%d):\n", #State.deepData.promptInteractions)
            for _, p in ipairs(State.deepData.promptInteractions) do
                content = content .. string.format("  [%s] %s at %s\n", p.time, p.prompt, p.path)
            end

            content = content .. string.format("\nMONSTER/NPC SPAWNS (%d):\n", #State.deepData.monsterSpawns)
            for _, m in ipairs(State.deepData.monsterSpawns) do
                content = content .. string.format("  [%s] %s | HP: %d/%d | Speed: %d | Children: %s\n", m.time, m.name, m.health, m.maxHealth, m.walkSpeed, m.childNames)
            end

            content = content .. string.format("\nMONSTER MOVEMENT SAMPLES (%d):\n", #State.deepData.monsterMoves)
            for _, m in ipairs(State.deepData.monsterMoves) do
                content = content .. string.format("  [%s] %s | Pos: %s | Vel: %s | Speed: %d | HP: %d\n", m.time, m.name, m.position, m.velocity, m.walkSpeed, m.health)
            end

            content = content .. string.format("\nREMOTE CALLS (%d):\n", #State.deepData.remoteCalls)
            for _, r in ipairs(State.deepData.remoteCalls) do
                content = content .. string.format("  [%s] %s (%s) args: %s\n", r.time, r.remoteName, r.method, r.args)
            end

            content = content .. string.format("\nWORKSPACE ADDITIONS (%d):\n", #State.deepData.workspaceAdds)
            for _, w in ipairs(State.deepData.workspaceAdds) do
                content = content .. string.format("  [%s] %s (%s) at %s\n", w.time, w.name, w.class, w.path)
            end

            content = content .. "\nPLAYER POSITIONS:\n"
            for playerName, positions in pairs(State.deepData.playerPositions) do
                content = content .. string.format("  %s (%d samples):\n", playerName, #positions)
                for _, p in ipairs(positions) do
                    content = content .. string.format("    [%s] %s (vel: %s)\n", p.time, p.position, p.velocity)
                end
            end

            pcall(writefile, filename, content)
            print("[Deep Scan] Saved to " .. filename)
            safeNotify("Deep Scan Complete", string.format("Report saved to %s\nPrompts: %d | Spawns: %d | Remotes: %d | Moves: %d",
                filename, #State.deepData.promptInteractions, #State.deepData.monsterSpawns, #State.deepData.remoteCalls, #State.deepData.monsterMoves))
        else
            safeNotify("Deep Scan Complete", "Data logged to console (F9)")
            print("[Deep Scan] Data logged to console")
        end
    end)
end

-- ============================================
-- AUTO-RUN: ALL SUB-SCANNERS
-- ============================================
local function autoRunAllScans()
    if State.autoRunComplete then return end
    safeNotify("Auto-Scan", "Running all sub-scanners automatically...")
    print("[Auto] Starting automatic sub-scans...")

    updateProgress(0, 6, "Auto-Scan", "Scanning remotes...")
    autoScanRemotes()
    task.wait(0.5)

    updateProgress(1, 6, "Auto-Scan", "Scanning workspace objects...")
    autoScanObjects()
    task.wait(0.5)

    updateProgress(2, 6, "Auto-Scan", "Scanning teams & stats...")
    autoScanTeamsStats()
    task.wait(0.5)

    updateProgress(3, 6, "Auto-Scan", "Scanning GUIs...")
    autoScanGUIs()
    task.wait(0.5)

    updateProgress(4, 6, "Auto-Scan", "Checking executor...")
    autoCheckExecutor()
    task.wait(0.5)

    updateProgress(5, 6, "Auto-Scan", "Searching keywords...")
    autoKeywordSearch()
    autoScanTouchEvents()
    updateProgress(6, 6, "Auto-Scan", "Complete!")
    task.wait(0.3)

    State.autoRunComplete = true
    safeNotify("Auto-Scan Complete", string.format("Remotes: %d | Objects: %d | Teams: %d | GUIs: %d | Keywords: %d",
        #State.remotes.events + #State.remotes.functions,
        #State.objects.prompts + #State.objects.clickDetectors + #State.objects.humanoids,
        #State.teams,
        #State.guis,
        #State.keywordResults))
    print("[Auto] All sub-scans complete.")
end

-- ============================================
-- MAIN SCRIPT SCAN
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

    -- Count
    local totalScripts = 0
    for _, cd in ipairs(containers) do
        local container = cd[1]
        if container then
            local d = State.maxDepth > 0 and getDescendantsWithDepth(container, State.maxDepth) or container:GetDescendants()
            for _, child in pairs(d) do
                if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    totalScripts = totalScripts + 1
                end
            end
            RunService.RenderStepped:Wait()
        end
    end
    State.stats.total = totalScripts

    -- Extract
    local current = 0
    for _, cd in ipairs(containers) do
        local container = cd[1]
        local name = cd[2]
        if container then
            local d = State.maxDepth > 0 and getDescendantsWithDepth(container, State.maxDepth) or container:GetDescendants()
            for _, child in pairs(d) do
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
                    elseif className == "Script") then State.stats.server = State.stats.server + 1
                    elseif className == "ModuleScript") then State.stats.module = State.stats.module + 1 end
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

    -- Auto-save dump
    updateProgress(totalScripts, totalScripts, "Saving", "to workspace...")
    task.wait(0.3)

    if #State.results > 0 and type(writefile) == "function" then
        local filename = "scan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
        local content = "============================================\n"
        content = content .. "Universal Game Scanner v7 Dump\n"
        content = content .. "Game: " .. GameName .. "\n"
        content = content .. "Place ID: " .. tostring(game.PlaceId) .. "\n"
        content = content .. "Job ID: " .. tostring(game.JobId) .. "\n"
        content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        content = content .. string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d | Client: %d | Server: %d | Module: %d\n",
            State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed,
            State.stats.client, State.stats.server, State.stats.module)
        content = content .. "============================================\n\n"
        -- index
        content = content .. "SCRIPT INDEX:\n" .. string.rep("-", 120) .. "\n"
        content = content .. string.format("%-5s | %-15s | %-15s | %-8s | %-12s | %-8s | %s\n", "#", "Container", "Class", "Status", "Category", "Type", "Path")
        content = content .. string.rep("-", 120) .. "\n"
        for i, r in ipairs(State.results) do
            local t = r.class == "LocalScript" and "CLIENT" or r.class == "Script" and "SERVER" or r.class == "ModuleScript" and "MODULE" or ""
            content = content .. string.format("[%-4d] | %-15s | %-15s | %-8s | %-12s | %-8s | %s\n",
                i, r.container, r.class, r.status, r.category or "Other", t, r.path)
        end
        content = content .. "\n"
        -- source
        for i, r in ipairs(State.results) do
            content = content .. string.format("\n=== SCRIPT [%d] ===\nGame: %s\nContainer: %s\nClass: %s\nCategory: %s\nPath: %s\nStatus: %s\n============================================\n",
                i, GameName, r.container, r.class, r.category or "Other", r.path, r.status)
            if r.source then content = content .. r.source .. "\n" else content = content .. "-- [NO SOURCE]\n" end
            if i % 25 == 0 and type(appendfile) == "function" then
                if i == 25 then pcall(writefile, filename, content) else pcall(appendfile, filename, "")
                end
                content = ""
            end
        end
        if #content > 0 then
            if type(appendfile) == "function" and #State.results > 25 then
                pcall(appendfile, filename, content)
            else
                pcall(writefile, filename, content)
            end
        end
        State.lastFilename = filename
        print("[Scan] Saved to " .. filename)
    end

    ProgressGui.Enabled = false
    State.scanning = false

    -- AUTO-RUN ALL SUB-SCANS
    autoRunAllScans()

    safeNotify("Scan Complete & Auto-Analyzed",
        string.format("%d scripts | OK: %d | Failed: %d\nAuto-ran: Remotes, Objects, Teams, GUI, Executor, Keywords\nSaved: %s",
        State.stats.total, State.stats.success, State.stats.failed, State.lastFilename))
end

-- ============================================
-- RAYFIELD
-- ============================================
pcall(function()
    Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()
end)
if not Rayfield then
    pcall(function() Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))() end)
end
if not Rayfield then warn("[K]vk: Rayfield failed.") return end

local Window = Rayfield:CreateWindow({
    Name = "Universal Scanner v7 — " .. GameName,
    LoadingTitle = "Scanning " .. GameName,
    LoadingSubtitle = "v7 — Advanced Auto-Analysis + Deep Scan",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySettings = { Key = Enum.KeyCode.RightControl, OnPress = function() end }
})

-- ============================================
-- TAB: SCANNER (AUTO EVERYTHING)
-- ============================================
local TabScan = Window:CreateTab("Scanner")

TabScan:CreateButton({ Name = "Scan Game + Auto-Analyze", Callback = function() performScan() end })

TabScan:CreateSlider({ Name = "Max Scan Depth (0 = Unlimited)", Range = {0, 10}, Increment = 1, Suffix = "levels", CurrentValue = 0, Flag = "MaxDepth", Callback = function(val) State.maxDepth = val end })

TabScan:CreateToggle({
    Name = "Auto-Run All Sub-Scans After Main Scan",
    CurrentValue = true,
    Flag = "AutoSubScans",
    Callback = function(state)
        -- this is always on by default, toggle just stores preference
        safeNotify("Auto-Scan", state and "Sub-scans will auto-run after main scan" or "Sub-scans disabled")
    end
})

TabScan:CreateButton({
    Name = "Re-run All Sub-Scans (Remotes, Objects, Teams, GUI, Executor, Keywords)",
    Callback = function()
        autoRunAllScans()
    end
})

TabScan:CreateButton({
    Name = "Clear All Results",
    Callback = function()
        State.results = {}
        State.stats = { total = 0, success = 0, failed = 0, bytecode = 0, client = 0, server = 0, module = 0 }
        State.remotes = { events = {}, functions = {} }
        State.objects = { prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, touchParts = {} }
        State.teams = {}
        State.leaderstats = {}
        State.guis = {}
        State.keywordResults = {}
        State.touchEvents = {}
        State.autoRunComplete = false
        State.lastFilename = ""
        safeNotify("Scanner", "All results cleared.")
    end
})

TabScan:CreateButton({
    Name = "Show Full Stats",
    Callback = function()
        local text = string.format("Scripts: %d | OK: %d | Failed: %d\nClient: %d | Server: %d | Module: %d\n\nRemotes: %d Events, %d Functions\nObjects: %d Prompts, %d Clicks, %d NPCs, %d Spawns\nTeams: %d | Leaderstats: %d | GUIs: %d\nKeywords: %d matches | Touch Events: %d",
            State.stats.total, State.stats.success, State.stats.failed,
            State.stats.client, State.stats.server, State.stats.module,
            #State.remotes.events, #State.remotes.functions,
            #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns,
            #State.teams, #State.leaderstats, #State.guis,
            #State.keywordResults, #State.touchEvents)
        safeNotify("Full Stats", text)
        print(text)
    end
})

-- ============================================
-- TAB: DEEP SCAN (5-MIN LIVE MONITOR)
-- ============================================
local TabDeep = Window:CreateTab("Deep Scan")

TabDeep:CreateButton({
    Name = "Start 5-Minute Deep Scan (Live Monitor)",
    Callback = function()
        startDeepScan(300)
    end
})

TabDeep:CreateButton({
    Name = "Start 1-Minute Quick Deep Scan",
    Callback = function()
        startDeepScan(60)
    end
})

TabDeep:CreateButton({
    Name = "Stop Deep Scan Early",
    Callback = function()
        State.deepScanning = false
        if connections.deepWorkspace then connections.deepWorkspace:Disconnect() connections.deepWorkspace = nil end
        if connections.deepMonsterMove then connections.deepMonsterMove:Disconnect() connections.deepMonsterMove = nil end
        if connections.deepPlayerPos then connections.deepPlayerPos:Disconnect() connections.deepPlayerPos = nil end
        safeNotify("Deep Scan", "Stopped early. Data in memory.")
    end
})

TabDeep:CreateButton({
    Name = "Print Deep Scan Data to Console",
    Callback = function()
        print("=== DEEP SCAN DATA ===")
        print(string.format("Prompt Interactions: %d", #State.deepData.promptInteractions))
        for _, p in ipairs(State.deepData.promptInteractions) do
            print(string.format("  [%s] %s at %s", p.time, p.prompt, p.path))
        end
        print(string.format("\nMonster Spawns: %d", #State.deepData.monsterSpawns))
        for _, m in ipairs(State.deepData.monsterSpawns) do
            print(string.format("  [%s] %s | HP: %d/%d | Speed: %d | Children: %s", m.time, m.name, m.health, m.maxHealth, m.walkSpeed, m.childNames))
        end
        print(string.format("\nRemote Calls: %d", #State.deepData.remoteCalls))
        for _, r in ipairs(State.deepData.remoteCalls) do
            print(string.format("  [%s] %s (%s) args: %s", r.time, r.remoteName, r.method, r.args))
        end
        print(string.format("\nMonster Movement Samples: %d", #State.deepData.monsterMoves))
        for _, m in ipairs(State.deepData.monsterMoves) do
            print(string.format("  [%s] %s | Pos: %s | Speed: %d", m.time, m.name, m.position, m.walkSpeed))
        end
        print(string.format("\nWorkspace Additions: %d", #State.deepData.workspaceAdds))
        for _, w in ipairs(State.deepData.workspaceAdds) do
            print(string.format("  [%s] %s (%s) at %s", w.time, w.name, w.class, w.path))
        end
        safeNotify("Deep Scan", "Data printed to F9.")
    end
})

TabDeep:CreateButton({
    Name = "Copy Deep Scan Data to Clipboard",
    Callback = function()
        if type(setclipboard) ~= "function" then return end
        local text = "=== DEEP SCAN DATA ===\n"
        text = text .. string.format("Prompt Interactions: %d\n", #State.deepData.promptInteractions)
        for _, p in ipairs(State.deepData.promptInteractions) do
            text = text .. string.format("  [%s] %s at %s\n", p.time, p.prompt, p.path)
        end
        text = text .. string.format("\nMonster Spawns: %d\n", #State.deepData.monsterSpawns)
        for _, m in ipairs(State.deepData.monsterSpawns) do
            text = text .. string.format("  [%s] %s | HP: %d/%d | Speed: %d | Children: %s\n", m.time, m.name, m.health, m.maxHealth, m.walkSpeed, m.childNames)
        end
        text = text .. string.format("\nRemote Calls: %d\n", #State.deepData.remoteCalls)
        for _, r in ipairs(State.deepData.remoteCalls) do
            text = text .. string.format("  [%s] %s (%s) args: %s\n", r.time, r.remoteName, r.method, r.args)
        end
        pcall(setclipboard, text)
        safeNotify("Deep Scan", "Data copied to clipboard.")
    end
})

TabDeep:CreateSlider({
    Name = "Deep Scan Duration (seconds)",
    Range = {30, 600},
    Increment = 30,
    Suffix = "sec",
    CurrentValue = 300,
    Flag = "DeepScanDuration",
    Callback = function(val) State.deepScanDuration = val end
})

TabDeep:CreateButton({
    Name = "Start Custom Duration Deep Scan",
    Callback = function()
        local dur = Rayfield.Flags.DeepScanDuration and Rayfield.Flags.DeepScanDuration.Value or 300
        startDeepScan(dur)
    end
})

-- ============================================
-- TAB: AUTO RESULTS (AUTO-COLLECTED)
-- ============================================
local TabResults = Window:CreateTab("Auto Results")

TabResults:CreateButton({
    Name = "Print All Remote Events & Functions",
    Callback = function()
        print("=== REMOTE EVENTS (" .. #State.remotes.events .. ") ===")
        for _, r in ipairs(State.remotes.events) do print("  [Event] " .. r.path) end
        print("\n=== REMOTE FUNCTIONS (" .. #State.remotes.functions .. ") ===")
        for _, r in ipairs(State.remotes.functions) do print("  [Func] " .. r.path) end
        safeNotify("Remotes", string.format("%d Events, %d Functions. Check F9.", #State.remotes.events, #State.remotes.functions))
    end
})

TabResults:CreateButton({
    Name = "Print All Workspace Objects",
    Callback = function()
        print("=== OBJECTS ===")
        print(string.format("ProximityPrompts: %d", #State.objects.prompts))
        for _, p in ipairs(State.objects.prompts) do print(string.format("  [%s] %s (parent: %s, hold: %.1f, text: %s)", p.name, p.path, p.parent, p.holdDuration, p.objectText or ""))
        end
        print(string.format("\nClickDetectors: %d", #State.objects.clickDetectors))
        for _, c in ipairs(State.objects.clickDetectors) do print("  " .. c.path) end
        print(string.format("\nNPCs/Monsters: %d", #State.objects.humanoids))
        for _, h in ipairs(State.objects.humanoids) do print(string.format("  %s | HP: %.0f/%.0f | Speed: %.0f | Children: %s", h.path, h.health, h.maxHealth, h.walkSpeed, h.children)) end
        print(string.format("\nSpawnLocations: %d", #State.objects.spawns))
        for _, s in ipairs(State.objects.spawns) do print("  " .. s.path) end
        safeNotify("Objects", string.format("Prompts: %d | Clicks: %d | NPCs: %d | Spawns: %d", #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns))
    end
})

TabResults:CreateButton({
    Name = "Print Teams & Leaderstats",
    Callback = function()
        print("=== TEAMS ===")
        for _, t in ipairs(State.teams) do print(string.format("  %s | Color: %s | Players: %d (%s)", t.name, t.color, t.players, t.playerNames)) end
        print("\n=== LEADERSTATS ===")
        for _, s in ipairs(State.leaderstats) do print(string.format("  %s (%s) = %s", s.name, s.class, s.value)) end
        safeNotify("Teams & Stats", string.format("Teams: %d | Leaderstats: %d", #State.teams, #State.leaderstats))
    end
})

TabResults:CreateButton({
    Name = "Print Executor Capabilities",
    Callback = function()
        print("=== EXECUTOR CAPABILITIES ===")
        for _, c in ipairs(State.executorCaps) do
            print(string.format("  %-25s %-25s %s", c.name, c.desc, c.available and "YES" or "NO")
        end
        safeNotify("Executor", string.format("%d/%d available. Check F9.", #State.executorCaps, #State.executorCaps))
    end
})

TabResults:CreateButton({
    Name = "Print Keyword Search Results",
    Callback = function()
        print("=== KEYWORD SEARCH ===")
        for _, kr in ipairs(State.keywordResults) do
            print(string.format("--- '%s' (%d matches) ---", kr.keyword, kr.count))
            for _, m in ipairs(kr.matches) do print(string.format("  [%s:%d] %s", m.script, m.line, m.script))
        end
        safeNotify("Keywords", string.format("%d keywords with matches.", #State.keywordResults))
    end
})

TabResults:CreateButton({
    Name = "Print Touch Events",
    Callback = function()
        print("=== TOUCH EVENTS (" .. #State.touchEvents .. ") ===")
        for _, t in ipairs(State.touchEvents) do
            print(string.format("  [%s:%d] %s", t.script, t.line, t.text))
        end
        safeNotify("Touch Events", string.format("%d found.", #State.touchEvents))
    end
})

TabResults:CreateButton({
    Name = "Print All GUIs",
    Callback = function()
        print("=== GUIS ===")
        for _, g in ipairs(State.guis) do
            print(string.format("  [%s] %s | Enabled: %s | Children: %d", g.container, g.path, tostring(g.enabled), g.childCount))
        end
        safeNotify("GUIs", string.format("%d ScreenGuis.", #State.guis))
    end
})

-- ============================================
-- TAB: EXPORT (AUTO-SAVE EVERYTHING)
-- ============================================
local TabExport = Window:CreateTab("Export")

TabExport:CreateButton({
    Name = "Export Full Dump (.txt)",
    Callback = function()
        if #State.results == 0 then safeNotify("Error", "Run a scan first.") return end
        if type(writefile) ~= "function" then safeNotify("Error", "writefile not available") return end
        local filename = "scan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
        -- build and write
        local content = "============================================\n"
        content = content .. "Universal Game Scanner v7 Dump\n"
        content = content .. "Game: " .. GameName .. "\n"
        content = content .. "Place ID: " .. tostring(game.PlaceId) .. "\n"
        content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        content = content .. string.format("Total: %d | OK: %d | Failed: %d\n", State.stats.total, State.stats.success, State.stats.failed)
        content = content .. "============================================\n\n"
        -- add all auto-collected data
        content = content .. string.format("=== REMOTES (%d Events, %d Functions) ===\n", #State.remotes.events, #State.remotes.functions)
        for _, r in ipairs(State.remotes.events) do content = content .. "[Event] " .. r.path .. "\n" end
        for _, r in ipairs(State.remotes.functions) do content = content .. "[Func] " .. r.path .. "\n"
        content = content .. "\n=== OBJECTS ===\n"
        content = content .. string.format("ProximityPrompts: %d\n", #State.objects.prompts)
        for _, p in ipairs(State.objects.prompts) do content = content .. string.format("  [%s] %s (hold: %.1f)\n", p.name, p.path, p.holdDuration)
        content = content .. string.format("\nClickDetectors: %d\n", #State.objects.clickDetectors)
        for _, c in ipairs(State.objects.clickDetectors) do content = content .. "  " .. c.path .. "\n"
        content = content .. string.format("\nNPCs/Monsters: %d\n", #State.objects.humanoids)
        for _, h in ipairs(State.objects.humanoids) do
            content = content .. string.format("  %s | HP: %.0f/%.0f | Speed: %.0f | Children: %s\n", h.path, h.health, h.maxHealth, h.walkSpeed, h.children)
        end
        content = content .. string.format("\nSpawnLocations: %d\n", #State.objects.spawns)
        for _, s in ipairs(State.objects.spawns) do content = content .. "  " .. s.path .. "\n"
        content = content .. "\n=== TEAMS ===\n"
        for _, t in ipairs(State.teams) do content = content .. string.format("  %s | Color: %s | Players: %d\n", t.name, t.color, t.players)
        content = content .. "\n=== LEADERSTATS ===\n"
        for _, s in ipairs(State.leaderstats) do content = content .. string.format("  %s (%s) = %s\n", s.name, s.class, s.value)
        content = content .. "\n=== EXECUTOR CAPABILITIES ===\n"
        for _, c in ipairs(State.executorCaps) do content = content .. string.format("  %-25s %-25s %s\n", c.name, c.desc, c.available and "YES" or "NO")
        content = content .. "\n=== SCRIPT INDEX ===\n"
        for i, r in ipairs(State.results) do
            local t = r.class == "LocalScript" and "CLIENT" or r.class == "Script" and "SERVER" or r.class == "ModuleScript" and "MODULE" or ""
            content = content .. string.format("[%d] %s | %s | %s | %s | %s | %s\n", i, r.container, r.class, r.status, r.category or "Other", t, r.path)
        end
        -- full source
        for i, r in ipairs(State.results) do
            content = content .. string.format("\n=== SCRIPT [%d] ===\nPath: %s\nClass: %s\nCategory: %s\nStatus: %s\n============================================\n", i, r.path, r.class, r.category or "Other", r.status)
            if r.source then content = content .. r.source .. "\n"
            else content = content .. "-- [NO SOURCE]\n"
        end
        pcall(writefile, filename, content)
        State.lastFilename = filename
        safeNotify("Exported", "Saved to: " .. filename)
    end
})

TabExport:CreateButton({
    Name = "Export Deep Scan Report",
    Callback = function()
        if type(writefile) ~= "function" then return end
        local filename = "deepscan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
        local content = "Deep Scan Report — " .. GameName .. "\n"
        content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        content = content .. string.format("Duration: %d seconds\n\n", tick() - State.deepData.startTime)
        content = content .. string.format("Prompt Interactions: %d\n", #State.deepData.promptInteractions)
        for _, p in ipairs(State.deepData.promptInteractions) do
            content = content .. string.format("  [%s] %s at %s\n", p.time, p.prompt, p.path)
        end
        content = content .. string.format("\nMonster Spawns: %d\n", #State.deepData.monsterSpawns)
        for _, m in ipairs(State.deepData.monsterSpawns) do
            content = content .. string.format("  [%s] %s | HP: %d/%d | Speed: %d | Children: %s\n", m.time, m.name, m.health, m.maxHealth, m.walkSpeed, m.childNames)
        end
        content = content .. string.format("\nRemote Calls: %d\n", #State.deepData.remoteCalls)
        for _, r in ipairs(State.deepData.remoteCalls) do
            content = content .. string.format("  [%s] %s (%s) args: %s\n", r.time, r.remoteName, r.method, r.args)
        end
        pcall(writefile, filename, content)
        safeNotify("Exported", "Deep scan saved to: " .. filename)
    end
})

TabExport:CreateButton({
    Name = "Copy Full Report to Clipboard",
    Callback = function()
        if type(setclipboard) ~= "function" then return end
        local text = "=== SCAN REPORT ===\n"
        text = text .. string.format("Scripts: %d | OK: %d | Failed: %d\n", State.stats.total, State.stats.success, State.stats.failed)
        text = text .. string.format("Remotes: %d Events, %d Functions\n", #State.remotes.events, #State.remotes.functions)
        text = text .. string.format("Objects: %d Prompts, %d Clicks, %d NPCs, %d Spawns\n", #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns)
        text = text .. string.format("Teams: %d | Leaderstats: %d | GUIs: %d\n", #State.teams, #State.leaderstats, #State.guis)
        text = text .. string.format("Keywords: %d keywords with matches\n", #State.keywordResults)
        text = text .. string.format("Touch Events: %d\n", #State.touchEvents)
        text = text .. string.format("Executor: %d/%d functions available\n\n", 
            (function() local c = 0 for _, cap in ipairs(State.executorCaps) do if cap.available then c = c + 1 end end return c end)(), #State.executorCaps)
        text = text .. "=== REMOTE EVENTS ===\n"
        for _, r in ipairs(State.remotes.events) do text = text .. r.path .. "\n" end
        text = text .. "\n=== REMOTE FUNCTIONS ===\n"
        for _, r in ipairs(State.remotes.functions) do text = text .. r.path .. "\n" end
        text = text .. "\n=== PROMPTS ===\n"
        for _, p in ipairs(State.objects.prompts) do text = text .. p.path .. "\n" end
        text = text .. "\n=== NPCs ===\n"
        for _, h in ipairs(State.objects.humanoids) do
            text = text .. string.format("%s | HP: %.0f/%.0f | Speed: %.0f\n", h.path, h.health, h.maxHealth, h.walkSpeed)
        end
        text = text .. "\n=== TEAMS ===\n"
        for _, t in ipairs(State.teams) do text = text .. string.format("%s | %s | Players: %d\n", t.name, t.color, t.players) end
        pcall(setclipboard, text)
        safeNotify("Exported", "Full report copied!")
    end
})

TabExport:CreateButton({
    Name = "Show Last Saved File",
    Callback = function()
        if State.lastFilename == "" then safeNotify("Error", "No file saved yet.") return end
        safeNotify("Last File", State.lastFilename)
    end
})

-- ============================================
-- TAB: MISC
-- ============================================
local TabMisc = Window:CreateTab("Misc")

TabMisc:CreateButton({
    Name = "Re-check Executor Capabilities",
    Callback = function()
        autoCheckExecutor()
        safeNotify("Executor", "Re-checked. Check F9.")
    end
})

TabMisc:CreateButton({
    Name = "Server Hop",
    Callback = function()
        pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)
    end
})

TabMisc:CreateButton({
    Name = "Copy Job ID",
    Callback = function()
        pcall(function()
            if type(setclipboard) == "function" then
                setclipboard(game.JobId)
                safeNotify("Misc", "Job ID copied.")
            end
        end)
    end
})

TabMisc:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        for _, conn in pairs(connections) do
            pcall(function() if conn and conn.Disconnect then conn:Disconnect() end end)
        end
        pcall(function() Rayfield:Destroy() end)
    end
})

TabMisc:CreateLabel("Universal Scanner v7 — [K]vk Advanced")
TabMisc:CreateLabel("Press Right Ctrl to toggle")
TabMisc:CreateLabel("Auto-runs: Remotes, Objects, Teams, Stats, GUI, Executor, Keywords, Touch Events")
TabMisc:CreateLabel("Deep Scan: Live monitoring for 5 minutes")
TabMisc:CreateLabel("Auto-saves: Full dump + Deep scan report")
TabMisc:CreateLabel("Everything is automatic. Just press Scan Game.")

-- ============================================
-- AUTO-RUN ON STARTUP
-- ============================================
task.spawn(function()
    task.wait(3) -- wait for game to load
    safeNotify("Auto-Scan", "Running all sub-scanners automatically on startup...")
    autoRunAllScans()
end)

-- ============================================
-- INIT
-- ============================================
Rayfield:LoadConfiguration()
print("[Universal Scanner v7] Loaded — Game: " .. GameName)
print("[v7] Features: Auto-Scan, Deep Scan (5-min monitor), Auto-save, Keyword search, Remote sniffer")
print("[v7] Everything auto-runs. Just press Scan Game or wait for auto-scan.")
