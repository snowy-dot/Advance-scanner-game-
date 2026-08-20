--!nocheck
-- Universal Game Scanner v7.2 — [K]vk
-- v7.1 base + Enhanced Executor Capability Checker with Custom GUI
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
    remotes = { events = {}, functions = {} },
    objects = { prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {} },
    teams = {},
    leaderstats = {},
    guis = {},
    executorCaps = {},
    keywordResults = {},
    touchEvents = {},
    deepData = {
        promptInteractions = {},
        monsterSpawns = {},
        monsterMoves = {},
        workspaceAdds = {},
        remoteCalls = {},
        playerPositions = {},
        startTime = 0,
    },
    autoRunComplete = false,
    execCapsComplete = false,
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
    elseif className == "ModuleScript" then return "Module"
    end
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
-- REMOTE SCANNER
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
                    })
                elseif desc:IsA("RemoteFunction") then
                    table.insert(State.remotes.functions, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        parent = desc.Parent and desc.Parent.Name or "",
                    })
                end
            end
        end)
    end
    scanContainer(ReplicatedStorage)
    scanContainer(Workspace)
    pcall(function() scanContainer(ServerScriptService) end)
    print(string.format("[Auto] Remotes: %d Events, %d Functions", #State.remotes.events, #State.remotes.functions))
    return State.remotes
end

-- ============================================
-- OBJECT SCANNER
-- ============================================
local function autoScanObjects()
    State.objects = { prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {} }
    pcall(function()
        for _, desc in pairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                table.insert(State.objects.prompts, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    parent = desc.Parent and desc.Parent.Name or "",
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
                    path = desc:GetFullName(),
                    name = desc.Name,
                    position = tostring(desc.Position),
                    duration = desc.Duration,
                    neutral = desc.Neutral,
                })
            end
        end
    end)
    pcall(function()
        for _, desc in pairs(Workspace:GetDescendants()) do
            if desc:IsA("Model") then
                local hum = desc:FindFirstChildOfClass("Humanoid")
                if hum and not Players:GetPlayerFromCharacter(desc) then
                    local root = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChild("RootPart") or desc.PrimaryPart
                    local childNames = {}
                    for _, c in pairs(desc:GetChildren()) do table.insert(childNames, c.Name) end
                    table.insert(State.objects.humanoids, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        health = hum.Health,
                        maxHealth = hum.MaxHealth,
                        walkSpeed = hum.WalkSpeed,
                        jumpHeight = hum.JumpHeight,
                        position = root and tostring(root.Position) or "unknown",
                        hasAnimator = desc:FindFirstChildOfClass("Animator") ~= nil,
                        childCount = #desc:GetChildren(),
                        children = table.concat(childNames, ", "),
                    })
                end
            end
        end
    end)
    print(string.format("[Auto] Objects: %d Prompts, %d Clicks, %d NPCs, %d Spawns",
        #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns))
    return State.objects
end

-- ============================================
-- TEAMS & STATS
-- ============================================
local function autoScanTeamsStats()
    State.teams = {}
    State.leaderstats = {}
    pcall(function()
        for _, team in pairs(Teams:GetChildren()) do
            if team:IsA("Team") then
                local playerNames = {}
                for _, p in pairs(team:GetPlayers()) do table.insert(playerNames, p.Name) end
                table.insert(State.teams, {
                    name = team.Name,
                    color = tostring(team.TeamColor.Color),
                    players = #team:GetPlayers(),
                    autoAssignable = team.AutoAssignable,
                    playerNames = table.concat(playerNames, ", "),
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
-- GUI SCANNER
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
-- EXECUTOR CAPABILITY CHECKER (ENHANCED v7.2)
-- ============================================
local execFuncDefs = {
    {name = "firetouchinterest", desc = "Fire touch events", category = "Interaction"},
    {name = "fireproximityprompt", desc = "Fire proximity prompts", category = "Interaction"},
    {name = "fireclickdetector", desc = "Fire click detectors", category = "Interaction"},
    {name = "getrawmetatable", desc = "Get raw metatable", category = "Metatable"},
    {name = "setreadonly", desc = "Set table readonly", category = "Metatable"},
    {name = "getnamecallmethod", desc = "Get namecall method", category = "Metatable"},
    {name = "newcclosure", desc = "Anti-tamper closure", category = "Metatable"},
    {name = "hookfunction", desc = "Hook functions", category = "Metatable"},
    {name = "hookmetamethod", desc = "Hook metamethods", category = "Metatable"},
    {name = "setclipboard", desc = "Copy to clipboard", category = "Utility"},
    {name = "writefile", desc = "Write files", category = "Utility"},
    {name = "readfile", desc = "Read files", category = "Utility"},
    {name = "appendfile", desc = "Append to files", category = "Utility"},
    {name = "makefolder", desc = "Create folders", category = "Utility"},
    {name = "isfolder", desc = "Check folder exists", category = "Utility"},
    {name = "listfiles", desc = "List files in folder", category = "Utility"},
    {name = "delfile", desc = "Delete files", category = "Utility"},
    {name = "delfolder", desc = "Delete folders", category = "Utility"},
    {name = "decompile", desc = "Decompile scripts", category = "Decompiler"},
    {name = "getsrc", desc = "Get script source", category = "Decompiler"},
    {name = "getscriptbytecode", desc = "Get bytecode", category = "Decompiler"},
    {name = "getscripthash", desc = "Get script hash", category = "Decompiler"},
    {name = "getscripts", desc = "Get all scripts", category = "Decompiler"},
    {name = "getrunningscripts", desc = "Get running scripts", category = "Decompiler"},
    {name = "gethui", desc = "Get CoreGui parent", category = "Environment"},
    {name = "getgenv", desc = "Global environment", category = "Environment"},
    {name = "getreg", desc = "Get registry", category = "Environment"},
    {name = "getrenv", desc = "Get registry env", category = "Environment"},
    {name = "getidentity", desc = "Get security identity", category = "Environment"},
    {name = "getthreadidentity", desc = "Get thread identity", category = "Environment"},
    {name = "syn_request", desc = "Synapse HTTP request", category = "Network"},
    {name = "request", desc = "HTTP request", category = "Network"},
    {name = "http_get", desc = "HTTP GET", category = "Network"},
    {name = "http_post", desc = "HTTP POST", category = "Network"},
    {name = "websocket", desc = "WebSocket support", category = "Network"},
    {name = "loadstring", desc = "Load string", category = "Execution"},
    {name = "loadstringEx", desc = "Extended loadstring", category = "Execution"},
    {name = "setsimulationradius", desc = "Set simulation radius", category = "Execution"},
    {name = "getcustomasset", desc = "Get custom asset", category = "Asset"},
    {name = "getcustomassetfunc", desc = "Custom asset function", category = "Asset"},
    {name = "saveinstance", desc = "Save instance", category = "Asset"},
    {name = "getinstances", desc = "Get all instances", category = "Instance"},
    {name = "getnilinstances", desc = "Get nil instances", category = "Instance"},
    {name = "gethiddenproperty", desc = "Get hidden property", category = "Instance"},
    {name = "sethiddenproperty", desc = "Set hidden property", category = "Instance"},
    {name = "isluau", desc = "Check if Luau", category = "Instance"},
}

local execSeen = {}
local uniqueExecFuncs = {}
for _, f in ipairs(execFuncDefs) do
    if not execSeen[f.name] then
        execSeen[f.name] = true
        table.insert(uniqueExecFuncs, f)
    end
end
execFuncDefs = uniqueExecFuncs

local execTotalAvailable = 0
local execTotalChecked = 0

local function autoCheckExecutor()
    State.executorCaps = {}
    execTotalAvailable = 0
    execTotalChecked = 0

    for _, f in ipairs(execFuncDefs) do
        local avail = false
        pcall(function()
            local env = getfenv()
            if type(env[f.name]) == "function" then
                avail = true
            end
        end)
        if not avail then
            pcall(function()
                if type(_G[f.name]) == "function" or type(getgenv()[f.name]) == "function" then
                    avail = true
                end
            end)
        end
        table.insert(State.executorCaps, { name = f.name, desc = f.desc, category = f.category, available = avail })
        execTotalChecked = execTotalChecked + 1
        if avail then execTotalAvailable = execTotalAvailable + 1 end
    end

    State.execCapsComplete = true
    print(string.format("[Auto] Executor: %d/%d functions available", execTotalAvailable, execTotalChecked))
    return State.executorCaps
end

-- ============================================
-- KEYWORD SEARCH
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
-- TOUCH EVENTS
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
-- DEEP SCAN
-- ============================================
local function startDeepScan(duration)
    duration = duration or 300
    if State.deepScanning then return end
    State.deepScanning = true
    State.deepData = {
        promptInteractions = {},
        monsterSpawns = {},
        monsterMoves = {},
        workspaceAdds = {},
        remoteCalls = {},
        playerPositions = {},
        startTime = tick(),
    }
    safeNotify("Deep Scan", string.format("Starting %d-second deep monitoring...", duration))
    print("[Deep Scan] Monitoring game for " .. duration .. " seconds...")

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
                        print("[Deep] Prompt triggered: " .. desc.Name)
                    end
                end)
            end
        end
    end)

    connections.deepWorkspace = Workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("Model") and desc:FindFirstChildOfClass("Humanoid") then
            local hum = desc:FindFirstChildOfClass("Humanoid")
            local root = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChild("RootPart")
            local childNames = {}
            for _, c in pairs(desc:GetChildren()) do table.insert(childNames, c.Name) end
            table.insert(State.deepData.monsterSpawns, {
                time = os.date("%H:%M:%S"),
                name = desc.Name,
                path = desc:GetFullName(),
                health = hum and hum.Health or 0,
                maxHealth = hum and hum.MaxHealth or 0,
                walkSpeed = hum and hum.WalkSpeed or 0,
                position = root and tostring(root.Position) or "unknown",
                children = table.concat(childNames, ", "),
            })
            print("[Deep] Monster/NPC spawned: " .. desc.Name)
        else
            table.insert(State.deepData.workspaceAdds, {
                time = os.date("%H:%M:%S"),
                name = desc.Name,
                class = desc.ClassName,
                path = desc:GetFullName(),
            })
        end
    end)

    local lastMoveSample = 0
    connections.deepMonsterMove = RunService.Heartbeat:Connect(function()
        if not State.deepScanning then return end
        if tick() - lastMoveSample < 5 then return end
        lastMoveSample = tick()
        local monsters = Workspace:FindFirstChild("Monsters")
        if monsters then
            for _, monster in pairs(monsters:GetChildren()) do
                local root = monster:FindFirstChild("HumanoidRootPart") or monster:FindFirstChild("RootPart")
                if root then
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
    end)

    local lastPlayerSample = 0
    connections.deepPlayerPos = RunService.Heartbeat:Connect(function()
        if not State.deepScanning then return end
        if tick() - lastPlayerSample < 10 then return end
        lastPlayerSample = tick()
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
                    if #State.deepData.playerPositions[player.Name] > 50 then
                        table.remove(State.deepData.playerPositions[player.Name], 1)
                    end
                end
            end
        end
    end)

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

    task.spawn(function()
        task.wait(duration)
        State.deepScanning = false
        if connections.deepWorkspace then connections.deepWorkspace:Disconnect() connections.deepWorkspace = nil end
        if connections.deepMonsterMove then connections.deepMonsterMove:Disconnect() connections.deepMonsterMove = nil end
        if connections.deepPlayerPos then connections.deepPlayerPos:Disconnect() connections.deepPlayerPos = nil end
        if type(writefile) == "function" then
            local filename = "deepscan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
            local content = "============================================\n"
            content = content .. "Deep Scan Report — " .. GameName .. "\n"
            content = content .. "Duration: " .. duration .. " seconds\n"
            content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
            content = content .. "============================================\n\n"
            content = content .. string.format("PROMPT INTERACTIONS (%d):\n", #State.deepData.promptInteractions)
            for _, p in ipairs(State.deepData.promptInteractions) do
                content = content .. string.format("  [%s] %s at %s\n", p.time, p.prompt, p.path)
            end
            content = content .. string.format("\nMONSTER SPAWNS (%d):\n", #State.deepData.monsterSpawns)
            for _, m in ipairs(State.deepData.monsterSpawns) do
                content = content .. string.format("  [%s] %s | HP: %d/%d | Speed: %d | Children: %s\n", m.time, m.name, m.health, m.maxHealth, m.walkSpeed, m.children)
            end
            content = content .. string.format("\nMONSTER MOVEMENT (%d):\n", #State.deepData.monsterMoves)
            for _, m in ipairs(State.deepData.monsterMoves) do
                content = content .. string.format("  [%s] %s | Pos: %s | Speed: %d | HP: %d\n", m.time, m.name, m.position, m.walkSpeed, m.health)
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
            safeNotify("Deep Scan Complete", string.format("Saved: %s\nPrompts: %d | Spawns: %d | Remotes: %d",
                filename, #State.deepData.promptInteractions, #State.deepData.monsterSpawns, #State.deepData.remoteCalls))
        else
            safeNotify("Deep Scan Complete", "Data in memory. Use Print button.")
        end
    end)
end

-- ============================================
-- AUTO-RUN ALL SUB-SCANS
-- ============================================
local function autoRunAllScans()
    if State.autoRunComplete then return end
    safeNotify("Auto-Scan", "Running all sub-scanners automatically...")
    print("[Auto] Starting automatic sub-scans...")

    updateProgress(0, 8, "Auto-Scan", "Scanning remotes...")
    autoScanRemotes()
    task.wait(0.3)
    updateProgress(1, 8, "Auto-Scan", "Scanning workspace objects...")
    autoScanObjects()
    task.wait(0.3)
    updateProgress(2, 8, "Auto-Scan", "Scanning teams & stats...")
    autoScanTeamsStats()
    task.wait(0.3)
    updateProgress(3, 8, "Auto-Scan", "Scanning GUIs...")
    autoScanGUIs()
    task.wait(0.3)
    updateProgress(4, 8, "Auto-Scan", "Checking executor...")
    autoCheckExecutor()
    task.wait(0.3)
    updateProgress(5, 8, "Auto-Scan", "Searching keywords...")
    autoKeywordSearch()
    task.wait(0.3)
    updateProgress(6, 8, "Auto-Scan", "Scanning touch events...")
    autoScanTouchEvents()
    task.wait(0.3)
    updateProgress(7, 8, "Auto-Scan", "Executor caps complete...")
    updateProgress(8, 8, "Auto-Scan", "Complete!")
    task.wait(0.3)

    State.autoRunComplete = true
    safeNotify("Auto-Scan Complete", string.format("Remotes: %d | Objects: %d | Teams: %d | GUIs: %d | Keywords: %d | Exec Caps: %d/%d",
        #State.remotes.events + #State.remotes.functions,
        #State.objects.prompts + #State.objects.clickDetectors + #State.objects.humanoids,
        #State.teams,
        #State.guis,
        #State.keywordResults,
        execTotalAvailable, execTotalChecked))
    print("[Auto] All sub-scans complete.")
end

-- ============================================
-- AUTO-SAVE DUMP
-- ============================================
local function autoSaveDump()
    if #State.results == 0 then return nil end
    if type(writefile) ~= "function" then return nil end

    local filename = "scan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    local content = "============================================\n"
    content = content .. "Universal Game Scanner v7.2 Dump\n"
    content = content .. "Game: " .. GameName .. "\n"
    content = content .. "Place ID: " .. tostring(game.PlaceId) .. "\n"
    content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    content = content .. string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d\n", State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed)
    content = content .. string.format("Executor: %d/%d functions available\n", execTotalAvailable, execTotalChecked)
    content = content .. "============================================\n\n"
    content = content .. "SCRIPT INDEX:\n"
    content = content .. string.rep("-", 100) .. "\n"
    for i, r in ipairs(State.results) do
        local t = ""
        if r.class == "LocalScript" then t = "CLIENT"
        elseif r.class == "Script" then t = "SERVER"
        elseif r.class == "ModuleScript" then t = "MODULE" end
        content = content .. string.format("[%d] %s | %s | %s | %s | %s | %s\n", i, r.container, r.class, r.status, r.category or "Other", t, r.path)
    end
    content = content .. "\n"
    for i, r in ipairs(State.results) do
        content = content .. string.format("\n=== SCRIPT [%d] ===\nPath: %s\nClass: %s\nStatus: %s\n============================================\n", i, r.path, r.class, r.status)
        if r.source then content = content .. r.source .. "\n"
        else content = content .. "-- [NO SOURCE]\n" end
    end

    pcall(writefile, filename, content)
    State.lastFilename = filename
    print("[Scan] Saved to " .. filename)
    return filename
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

    updateProgress(totalScripts, totalScripts, "Saving", "to workspace...")
    task.wait(0.3)
    local savedFile = autoSaveDump()
    ProgressGui.Enabled = false
    State.scanning = false

    autoRunAllScans()

    if savedFile then
        safeNotify("Scan Complete & Auto-Analyzed",
            string.format("%d scripts | OK: %d | Failed: %d\nAuto-ran: Remotes, Objects, Teams, GUI, Executor, Keywords\nSaved: %s",
            State.stats.total, State.stats.success, State.stats.failed, savedFile))
    else
        safeNotify("Scan Complete (No Save)",
            string.format("%d scripts | OK: %d | Failed: %d\nwritefile not available",
            State.stats.total, State.stats.success, State.stats.failed))
    end
end

-- ============================================
-- RAYFIELD
-- ============================================
local rayfieldOk = false
pcall(function()
    Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()
    rayfieldOk = true
end)
if not rayfieldOk or not Rayfield then
    pcall(function()
        Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
end
if not Rayfield then
    warn("[K]vk: Rayfield failed to load.")
    return
end

local Window = Rayfield:CreateWindow({
    Name = "Universal Scanner v7.2 — " .. GameName,
    LoadingTitle = "Scanning " .. GameName,
    LoadingSubtitle = "v7.2 — Auto-Everything + Deep Scan + Enhanced Exec Checker",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySettings = { Key = Enum.KeyCode.RightControl, OnPress = function() end }
})

-- ============================================
-- TAB: SCANNER
-- ============================================
local TabScan = Window:CreateTab("Scanner")

TabScan:CreateButton({ Name = "Scan Game + Auto-Analyze", Callback = function() performScan() end })
TabScan:CreateSlider({ Name = "Max Scan Depth (0 = Unlimited)", Range = {0, 10}, Increment = 1, Suffix = "levels", CurrentValue = 0, Flag = "MaxDepth", Callback = function(val) State.maxDepth = val end })
TabScan:CreateButton({ Name = "Re-run All Sub-Scans", Callback = function() autoRunAllScans() end })
TabScan:CreateButton({ Name = "Clear All Results", Callback = function()
    State.results = {}
    State.stats = { total = 0, success = 0, failed = 0, bytecode = 0, client = 0, server = 0, module = 0 }
    State.remotes = { events = {}, functions = {} }
    State.objects = { prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {} }
    State.teams = {}
    State.leaderstats = {}
    State.guis = {}
    State.keywordResults = {}
    State.touchEvents = {}
    State.autoRunComplete = false
    State.execCapsComplete = false
    State.lastFilename = ""
    safeNotify("Scanner", "All results cleared.")
end })
TabScan:CreateButton({ Name = "Show Full Stats", Callback = function()
    local text = string.format("Scripts: %d | OK: %d | Failed: %d\nClient: %d | Server: %d | Module: %d\n\nRemotes: %d Events, %d Functions\nObjects: %d Prompts, %d Clicks, %d NPCs, %d Spawns\nTeams: %d | Leaderstats: %d | GUIs: %d\nKeywords: %d | Touch Events: %d\n\nExecutor: %d/%d functions available",
        State.stats.total, State.stats.success, State.stats.failed,
        State.stats.client, State.stats.server, State.stats.module,
        #State.remotes.events, #State.remotes.functions,
        #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns,
        #State.teams, #State.leaderstats, #State.guis,
        #State.keywordResults, #State.touchEvents,
        execTotalAvailable, execTotalChecked)
    safeNotify("Full Stats", text)
    print(text)
end })

-- ============================================
-- TAB: DEEP SCAN
-- ============================================
local TabDeep = Window:CreateTab("Deep Scan")

TabDeep:CreateButton({ Name = "Start 5-Minute Deep Scan", Callback = function() startDeepScan(300) end })
TabDeep:CreateButton({ Name = "Start 1-Minute Quick Deep Scan", Callback = function() startDeepScan(60) end })
TabDeep:CreateButton({ Name = "Stop Deep Scan Early", Callback = function()
    State.deepScanning = false
    if connections.deepWorkspace then connections.deepWorkspace:Disconnect() connections.deepWorkspace = nil end
    if connections.deepMonsterMove then connections.deepMonsterMove:Disconnect() connections.deepMonsterMove = nil end
    if connections.deepPlayerPos then connections.deepPlayerPos:Disconnect() connections.deepPlayerPos = nil end
    safeNotify("Deep Scan", "Stopped early.")
end })
TabDeep:CreateButton({ Name = "Print Deep Scan Data", Callback = function()
    print("=== DEEP SCAN DATA ===")
    print(string.format("Prompt Interactions: %d", #State.deepData.promptInteractions))
    for _, p in ipairs(State.deepData.promptInteractions) do print(string.format("  [%s] %s at %s", p.time, p.prompt, p.path)) end
    print(string.format("\nMonster Spawns: %d", #State.deepData.monsterSpawns))
    for _, m in ipairs(State.deepData.monsterSpawns) do print(string.format("  [%s] %s | HP: %d/%d | Speed: %d | Children: %s", m.time, m.name, m.health, m.maxHealth, m.walkSpeed, m.children)) end
    print(string.format("\nRemote Calls: %d", #State.deepData.remoteCalls))
    for _, r in ipairs(State.deepData.remoteCalls) do print(string.format("  [%s] %s (%s) args: %s", r.time, r.remoteName, r.method, r.args)) end
    print(string.format("\nMonster Movement: %d", #State.deepData.monsterMoves))
    for _, m in ipairs(State.deepData.monsterMoves) do print(string.format("  [%s] %s | Pos: %s | Speed: %d", m.time, m.name, m.position, m.walkSpeed)) end
    print(string.format("\nWorkspace Additions: %d", #State.deepData.workspaceAdds))
    for _, w in ipairs(State.deepData.workspaceAdds) do print(string.format("  [%s] %s (%s) at %s", w.time, w.name, w.class, w.path)) end
    safeNotify("Deep Scan", "Data printed to F9.")
end })
TabDeep:CreateButton({ Name = "Copy Deep Scan Data", Callback = function()
    if type(setclipboard) ~= "function" then return end
    local text = "=== DEEP SCAN DATA ===\n"
    text = text .. string.format("Prompt Interactions: %d\n", #State.deepData.promptInteractions)
    for _, p in ipairs(State.deepData.promptInteractions) do text = text .. string.format("  [%s] %s at %s\n", p.time, p.prompt, p.path) end
    text = text .. string.format("\nMonster Spawns: %d\n", #State.deepData.monsterSpawns)
    for _, m in ipairs(State.deepData.monsterSpawns) do text = text .. string.format("  [%s] %s | HP: %d/%d | Speed: %d | Children: %s\n", m.time, m.name, m.health, m.maxHealth, m.walkSpeed, m.children) end
    text = text .. string.format("\nRemote Calls: %d\n", #State.deepData.remoteCalls)
    for _, r in ipairs(State.deepData.remoteCalls) do text = text .. string.format("  [%s] %s (%s) args: %s\n", r.time, r.remoteName, r.method, r.args) end
    pcall(setclipboard, text)
    safeNotify("Deep Scan", "Copied!")
end })
TabDeep:CreateSlider({ Name = "Custom Duration (seconds)", Range = {30, 600}, Increment = 30, Suffix = "sec", CurrentValue = 300, Flag = "DeepScanDur", Callback = function(val) State.deepScanDuration = val end })
TabDeep:CreateButton({ Name = "Start Custom Duration Deep Scan", Callback = function()
    local dur = Rayfield.Flags.DeepScanDur and Rayfield.Flags.DeepScanDur.Value or 300
    startDeepScan(dur)
end })

-- ============================================
-- TAB: AUTO RESULTS
-- ============================================
local TabResults = Window:CreateTab("Auto Results")

TabResults:CreateButton({ Name = "Print All Remotes", Callback = function()
    print("=== REMOTE EVENTS (" .. #State.remotes.events .. ") ===")
    for _, r in ipairs(State.remotes.events) do print("  [Event] " .. r.path) end
    print("\n=== REMOTE FUNCTIONS (" .. #State.remotes.functions .. ") ===")
    for _, r in ipairs(State.remotes.functions) do print("  [Func] " .. r.path) end
    safeNotify("Remotes", string.format("%d Events, %d Functions. Check F9.", #State.remotes.events, #State.remotes.functions))
end })
TabResults:CreateButton({ Name = "Print All Objects", Callback = function()
    print("=== OBJECTS ===")
    print(string.format("ProximityPrompts: %d", #State.objects.prompts))
    for _, p in ipairs(State.objects.prompts) do print(string.format("  [%s] %s (hold: %.1f)", p.name, p.path, p.holdDuration)) end
    print(string.format("\nClickDetectors: %d", #State.objects.clickDetectors))
    for _, c in ipairs(State.objects.clickDetectors) do print("  " .. c.path) end
    print(string.format("\nNPCs/Monsters: %d", #State.objects.humanoids))
    for _, h in ipairs(State.objects.humanoids) do print(string.format("  %s | HP: %.0f/%.0f | Speed: %.0f | Children: %s", h.path, h.health, h.maxHealth, h.walkSpeed, h.children)) end
    print(string.format("\nSpawnLocations: %d", #State.objects.spawns))
    for _, s in ipairs(State.objects.spawns) do print("  " .. s.path) end
    safeNotify("Objects", string.format("Prompts: %d | Clicks: %d | NPCs: %d | Spawns: %d", #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns))
end })
TabResults:CreateButton({ Name = "Print Teams & Stats", Callback = function()
    print("=== TEAMS ===")
    for _, t in ipairs(State.teams) do print(string.format("  %s | Color: %s | Players: %d (%s)", t.name, t.color, t.players, t.playerNames)) end
    print("\n=== LEADERSTATS ===")
    for _, s in ipairs(State.leaderstats) do print(string.format("  %s (%s) = %s", s.name, s.class, s.value)) end
    safeNotify("Teams & Stats", string.format("Teams: %d | Stats: %d", #State.teams, #State.leaderstats))
end })
TabResults:CreateButton({ Name = "Print Keyword Results", Callback = function()
    print("=== KEYWORD SEARCH ===")
    for _, kr in ipairs(State.keywordResults) do
        print(string.format("--- '%s' (%d matches) ---", kr.keyword, kr.count))
        for _, m in ipairs(kr.matches) do print(string.format("  [%s:%d]", m.script, m.line)) end
    end
    safeNotify("Keywords", string.format("%d keywords.", #State.keywordResults))
end })
TabResults:CreateButton({ Name = "Print Touch Events", Callback = function()
    print("=== TOUCH EVENTS (" .. #State.touchEvents .. ") ===")
    for _, t in ipairs(State.touchEvents) do print(string.format("  [%s:%d] %s", t.script, t.line, t.text)) end
    safeNotify("Touch Events", string.format("%d found.", #State.touchEvents))
end })
TabResults:CreateButton({ Name = "Print All GUIs", Callback = function()
    print("=== GUIS ===")
    for _, g in ipairs(State.guis) do print(string.format("  [%s] %s | Enabled: %s | Children: %d", g.container, g.path, tostring(g.enabled), g.childCount)) end
    safeNotify("GUIs", string.format("%d ScreenGuis.", #State.guis))
end })

-- ============================================
-- TAB: EXEC CAPS — OVERVIEW
-- ============================================
local TabExecOverview = Window:CreateTab("Exec Caps")

TabExecOverview:CreateButton({
    Name = "Run Full Capability Check",
    Callback = function()
        autoCheckExecutor()
        safeNotify("Check Complete", string.format("%d/%d functions available", execTotalAvailable, execTotalChecked))
    end
})

TabExecOverview:CreateButton({
    Name = "Print Results to Console (F9)",
    Callback = function()
        if #State.executorCaps == 0 then autoCheckExecutor() end
        print("============================================")
        print("EXECUTOR CAPABILITY REPORT")
        print(string.format("Available: %d / %d", execTotalAvailable, execTotalChecked))
        print("============================================")
        for _, c in ipairs(State.executorCaps) do
            print(string.format("  [%s] %-25s %-30s %s",
                c.category, c.name, c.desc, c.available and "YES" or "NO"))
        end
        print("============================================")
        safeNotify("Printed", "Check F9 console for full report.")
    end
})

TabExecOverview:CreateButton({
    Name = "Copy Results to Clipboard",
    Callback = function()
        if #State.executorCaps == 0 then autoCheckExecutor() end
        if type(setclipboard) ~= "function" then
            safeNotify("Error", "setclipboard not available.")
            return
        end
        local text = "============================================\n"
        text = text .. "EXECUTOR CAPABILITY REPORT\n"
        text = text .. string.format("Date: %s\n", os.date("%Y-%m-%d %H:%M:%S"))
        text = text .. string.format("Available: %d / %d\n", execTotalAvailable, execTotalChecked)
        text = text .. "============================================\n\n"

        local categories = {}
        for _, c in ipairs(State.executorCaps) do
            if not categories[c.category] then categories[c.category] = {} end
            table.insert(categories[c.category], c)
        end

        local catOrder = {"Interaction", "Metatable", "Utility", "Decompiler", "Environment", "Network", "Execution", "Asset", "Instance"}
        for _, cat in ipairs(catOrder) do
            if categories[cat] then
                text = text .. string.format("=== %s ===\n", cat:upper())
                for _, c in ipairs(categories[cat]) do
                    text = text .. string.format("  %-25s %-30s %s\n",
                        c.name, c.desc, c.available and "[YES]" or "[NO]")
                end
                text = text .. "\n"
            end
        end

        for cat, items in pairs(categories) do
            local found = false
            for _, c in ipairs(catOrder) do if c == cat then found = true break end end
            if not found then
                text = text .. string.format("=== %s ===\n", cat:upper())
                for _, c in ipairs(items) do
                    text = text .. string.format("  %-25s %-30s %s\n",
                        c.name, c.desc, c.available and "[YES]" or "[NO]")
                end
                text = text .. "\n"
            end
        end

        pcall(setclipboard, text)
        safeNotify("Copied", "Full report copied to clipboard.")
    end
})

TabExecOverview:CreateButton({
    Name = "Save Report to File",
    Callback = function()
        if #State.executorCaps == 0 then autoCheckExecutor() end
        if type(writefile) ~= "function" then
            safeNotify("Error", "writefile not available.")
            return
        end
        local filename = "execcap_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
        local content = "============================================\n"
        content = content .. "Executor Capability Report\n"
        content = content .. string.format("Date: %s\n", os.date("%Y-%m-%d %H:%M:%S"))
        content = content .. string.format("Available: %d / %d\n", execTotalAvailable, execTotalChecked)
        content = content .. "============================================\n\n"

        local categories = {}
        for _, c in ipairs(State.executorCaps) do
            if not categories[c.category] then categories[c.category] = {} end
            table.insert(categories[c.category], c)
        end

        local catOrder = {"Interaction", "Metatable", "Utility", "Decompiler", "Environment", "Network", "Execution", "Asset", "Instance"}
        for _, cat in ipairs(catOrder) do
            if categories[cat] then
                content = content .. string.format("=== %s ===\n", cat:upper())
                for _, c in ipairs(categories[cat]) do
                    content = content .. string.format("  %-25s %-30s %s\n",
                        c.name, c.desc, c.available and "[YES]" or "[NO]")
                end
                content = content .. "\n"
            end
        end

        for cat, items in pairs(categories) do
            local found = false
            for _, c in ipairs(catOrder) do if c == cat then found = true break end end
            if not found then
                content = content .. string.format("=== %s ===\n", cat:upper())
                for _, c in ipairs(items) do
                    content = content .. string.format("  %-25s %-30s %s\n",
                        c.name, c.desc, c.available and "[YES]" or "[NO]")
                end
                content = content .. "\n"
            end
        end

        pcall(writefile, filename, content)
        safeNotify("Saved", "Report saved to: " .. filename)
    end
})

TabExecOverview:CreateButton({
    Name = "Print Available Only",
    Callback = function()
        if #State.executorCaps == 0 then autoCheckExecutor() end
        print("=== AVAILABLE FUNCTIONS ===")
        for _, c in ipairs(State.executorCaps) do
            if c.available then
                print(string.format("  [%s] %-25s %s", c.category, c.name, c.desc))
            end
        end
        safeNotify("Printed", "Check F9 console.")
    end
})

TabExecOverview:CreateButton({
    Name = "Print Missing Only",
    Callback = function()
        if #State.executorCaps == 0 then autoCheckExecutor() end
        print("=== MISSING FUNCTIONS ===")
        for _, c in ipairs(State.executorCaps) do
            if not c.available then
                print(string.format("  [%s] %-25s %s", c.category, c.name, c.desc))
            end
        end
        safeNotify("Printed", "Check F9 console.")
    end
})

-- ============================================
-- TAB: EXEC CAPS — BY CATEGORY
-- ============================================
local TabExecCat = Window:CreateTab("Exec Categories")

local catOrder = {"Interaction", "Metatable", "Utility", "Decompiler", "Environment", "Network", "Execution", "Asset", "Instance"}

for _, cat in ipairs(catOrder) do
    TabExecCat:CreateButton({
        Name = "Check " .. cat,
        Callback = function()
            if #State.executorCaps == 0 then autoCheckExecutor() end
            local count = 0
            local avail = 0
            print(string.format("=== %s CAPABILITIES ===", cat:upper()))
            for _, c in ipairs(State.executorCaps) do
                if c.category == cat then
                    count = count + 1
                    if c.available then avail = avail + 1 end
                    print(string.format("  %-25s %-30s %s",
                        c.name, c.desc, c.available and "YES" or "NO"))
                end
            end
            print(string.format("Total: %d/%d available\n", avail, count))
            safeNotify(cat, string.format("%d/%d available", avail, count))
        end
    })
end

-- ============================================
-- TAB: EXPORT
-- ============================================
local TabExport = Window:CreateTab("Export")

TabExport:CreateButton({ Name = "Export Full Dump (.txt)", Callback = function()
    if #State.results == 0 then safeNotify("Error", "Run a scan first.") return end
    local file = autoSaveDump()
    if file then safeNotify("Exported", "Saved to: " .. file) else safeNotify("Error", "Export failed.") end
end })
TabExport:CreateButton({ Name = "Copy Full Report", Callback = function()
    if type(setclipboard) ~= "function" then return end
    local text = "=== SCAN REPORT ===\n"
    text = text .. string.format("Scripts: %d | OK: %d | Failed: %d\n", State.stats.total, State.stats.success, State.stats.failed)
    text = text .. string.format("Remotes: %d Events, %d Functions\n", #State.remotes.events, #State.remotes.functions)
    text = text .. string.format("Objects: %d Prompts, %d Clicks, %d NPCs, %d Spawns\n", #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns)
    text = text .. string.format("Teams: %d | Leaderstats: %d | GUIs: %d\n", #State.teams, #State.leaderstats, #State.guis)
    text = text .. string.format("Executor: %d/%d functions available\n", execTotalAvailable, execTotalChecked)
    text = text .. "\n=== REMOTE EVENTS ===\n"
    for _, r in ipairs(State.remotes.events) do text = text .. r.path .. "\n" end
    text = text .. "\n=== REMOTE FUNCTIONS ===\n"
    for _, r in ipairs(State.remotes.functions) do text = text .. r.path .. "\n" end
    text = text .. "\n=== NPCS ===\n"
    for _, h in ipairs(State.objects.humanoids) do
        text = text .. string.format("%s | HP: %.0f/%.0f | Speed: %.0f\n", h.path, h.health, h.maxHealth, h.walkSpeed)
    end
    pcall(setclipboard, text)
    safeNotify("Exported", "Copied!")
end })
TabExport:CreateButton({ Name = "Show Last File", Callback = function()
    if State.lastFilename == "" then safeNotify("Error", "No file saved yet.") return end
    safeNotify("Last File", State.lastFilename)
end })

-- ============================================
-- TAB: MISC
-- ============================================
local TabMisc = Window:CreateTab("Misc")

TabMisc:CreateButton({ Name = "Re-check Executor", Callback = function() autoCheckExecutor() safeNotify("Executor", string.format("Re-checked: %d/%d", execTotalAvailable, execTotalChecked)) end })
TabMisc:CreateButton({ Name = "Server Hop", Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end) end })
TabMisc:CreateButton({ Name = "Copy Job ID", Callback = function() pcall(function() if type(setclipboard) == "function" then setclipboard(game.JobId) safeNotify("Misc", "Copied.") end end) end })
TabMisc:CreateButton({ Name = "Destroy UI", Callback = function()
    for _, conn in pairs(connections) do pcall(function() if conn and conn.Disconnect then conn:Disconnect() end end) end
    pcall(function() Rayfield:Destroy() end)
end })

TabMisc:CreateLabel("Universal Scanner v7.2 — [K]vk Advanced")
TabMisc:CreateLabel("Press Right Ctrl to toggle")
TabMisc:CreateLabel("Auto-runs all sub-scans on startup")
TabMisc:CreateLabel("Deep Scan: 5-min live monitoring")
TabMisc:CreateLabel("Enhanced Executor Capability Checker")
TabMisc:CreateLabel("46 functions checked, 9 categories")

-- ============================================
-- AUTO-RUN ON STARTUP
-- ============================================
task.spawn(function()
    task.wait(3)
    autoRunAllScans()
end)

-- ============================================
-- INIT
-- ============================================
Rayfield:LoadConfiguration()
print("[Universal Scanner v7.2] Loaded — Game: " .. GameName)
print("[v7.2] Auto-scans on startup, Deep Scan ready, Enhanced Exec Checker ready.")
