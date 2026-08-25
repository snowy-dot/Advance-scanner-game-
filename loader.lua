--!nocheck
-- Universal Game Scanner v8.0 — [K]vk
-- v7.2 base + Full rewrite: iterative scanning, remote profiling, anti-cheat detection,
-- asset extraction, dependency mapping, JSON export, attribute scanning, AC detection,
-- backdoor detection, one-pass object scanning, proper metatable restoration

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
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
    deepScanning = false,
    results = {},
    scriptHashes = {},
    stats = {
        total = 0, success = 0, failed = 0, bytecode = 0,
        client = 0, server = 0, module = 0, deduped = 0,
    },
    lastFilename = "",
    maxDepth = 0,
    remotes = {
        events = {}, functions = {},
        bindables = {}, bindableFuncs = {},
        profiles = {},
    },
    objects = {
        prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {},
        highlights = {}, billboards = {}, surfaces = {},
        values = {}, configurations = {},
    },
    assets = {
        sounds = {}, animations = {}, decals = {},
        meshes = {}, textures = {}, models = {},
    },
    teams = {},
    leaderstats = {},
    guis = {},
    executorCaps = {},
    executorInfo = "",
    keywordResults = {},
    touchEvents = {},
    antiCheatDetections = {},
    backdoorDetections = {},
    requireMap = {},
    attributes = {},
    tags = {},
    deepData = {
        promptInteractions = {},
        monsterSpawns = {},
        monsterMoves = {},
        workspaceAdds = {},
        workspaceRemoves = {},
        remoteCalls = {},
        remoteCallProfiles = {},
        playerPositions = {},
        attributeChanges = {},
        humanoidStateChanges = {},
        startTime = 0,
    },
    autoRunComplete = false,
    execCapsComplete = false,
    deepScanDuration = 300,
    originalNamecall = nil,
    namecallHooked = false,
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
-- SAFE HASH (for dedup)
-- ============================================
local function quickHash(str)
    if not str then return "nil" end
    local h = 5381
    for i = 1, #str, 1 do
        h = (h * 33) ~ string.byte(str, i)
        h = h % 0x100000000
    end
    return string.format("%08x", h)
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
-- ITERATIVE DESCENDANT SCANNER (no recursion)
-- ============================================
local function getDescendantsIterative(container, maxDepth)
    local results = {}
    local stack = { {instance = container, depth = 0} }

    while #stack > 0 do
        local node = table.remove(stack)
        local children = node.instance:GetChildren()
        for _, child in ipairs(children) do
            table.insert(results, child)
            if maxDepth <= 0 or node.depth + 1 < maxDepth then
                table.insert(stack, {instance = child, depth = node.depth + 1})
            end
        end
        if #results % 200 == 0 then
            RunService.RenderStepped:Wait()
        end
    end

    return results
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
-- AUTO-CATEGORY (expanded)
-- ============================================
local categoryKeywords = {
    Combat = {"combat", "punch", "attack", "damage", "weapon", "gun", "melee", "fight", "kill", "health", "sword", "block", "parry", "dodge"},
    Movement = {"movement", "walkspeed", "fly", "noclip", "jump", "gravity", "velocity", "dash", "sprint", "shiftlock", "camera", "cframe", "teleport", "tp"},
    UI = {"gui", "frame", "button", "ui", "hud", "menu", "interface", "screen", "panel", "label", "textbox", "scroll"},
    Economy = {"shop", "buy", "currency", "cash", "coin", "reward", "spin", "egg", "pet", "rebirth", "upgrade", "sell", "trade", "inventory", "storage"},
    NPC = {"npc", "monster", "enemy", "boss", "ai", "bot", "creature", "mob", "spawn", "wave", "round"},
    Admin = {"cmdr", "command", "admin", "ban", "kick", "teleport", "warn", "mod", "staff", "permission"},
    Remote = {"remote", "fire", "server", "replicate", "event", "invoke", "bindable"},
    DataStore = {"datastore", "save", "load", "profile", "session", "cache", "reconcile"},
    Networking = {"http", "request", "webhook", "api", "fetch", "json", "encode", "decode"},
    Security = {"anticheat", "anti-cheat", "cheat", "exploit", "detect", "flag", "suspect", "verify", "integrity", "checksum"},
    Animation = {"animation", "animate", "track", "playback", "keyframe", "rig", "motor6d"},
    Audio = {"sound", "audio", "music", "sfx", "volume", "playlist"},
}

local function categorizeScript(path, className, source)
    local pathLower = path:lower()
    local sourceLower = source and source:lower() or ""

    for category, keywords in pairs(categoryKeywords) do
        for _, keyword in ipairs(keywords) do
            if pathLower:match(keyword) or (sourceLower and sourceLower:match(keyword)) then
                return category
            end
        end
    end

    if className == "LocalScript" then return "Client"
    elseif className == "Script" then return "Server"
    elseif className == "ModuleScript" then return "Module"
    end
    return "Other"
end

-- ============================================
-- REMOTE SCANNER (expanded: all containers + bindables)
-- ============================================
local function autoScanRemotes()
    State.remotes = {
        events = {}, functions = {},
        bindables = {}, bindableFuncs = {},
        profiles = {},
    }

    local function scanContainer(container)
        pcall(function()
            for _, desc in ipairs(container:GetDescendants()) do
                if desc:IsA("RemoteEvent") then
                    table.insert(State.remotes.events, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        parent = desc.Parent and desc.Parent.Name or "",
                        className = "RemoteEvent",
                    })
                elseif desc:IsA("RemoteFunction") then
                    table.insert(State.remotes.functions, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        parent = desc.Parent and desc.Parent.Name or "",
                        className = "RemoteFunction",
                    })
                elseif desc:IsA("BindableEvent") then
                    table.insert(State.remotes.bindables, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        parent = desc.Parent and desc.Parent.Name or "",
                        className = "BindableEvent",
                    })
                elseif desc:IsA("BindableFunction") then
                    table.insert(State.remotes.bindableFuncs, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        parent = desc.Parent and desc.Parent.Name or "",
                        className = "BindableFunction",
                    })
                end
            end
        end)
    end

    scanContainer(ReplicatedStorage)
    scanContainer(Workspace)
    pcall(function() scanContainer(ServerScriptService) end)
    pcall(function() scanContainer(StarterGui) end)
    pcall(function() scanContainer(StarterPlayer) end)
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerGui") then
            scanContainer(LocalPlayer.PlayerGui)
        end
    end)
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerScripts") then
            scanContainer(LocalPlayer.PlayerScripts)
        end
    end)

    local total = #State.remotes.events + #State.remotes.functions +
                  #State.remotes.bindables + #State.remotes.bindableFuncs
    print(string.format("[Auto] Remotes: %d Events, %d Functions, %d Bindables, %d BindableFuncs (%d total)",
        #State.remotes.events, #State.remotes.functions,
        #State.remotes.bindables, #State.remotes.bindableFuncs, total))
    return State.remotes
end

-- ============================================
-- OBJECT SCANNER (one-pass + expanded types)
-- ============================================
local function autoScanObjects()
    State.objects = {
        prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {},
        highlights = {}, billboards = {}, surfaces = {},
        values = {}, configurations = {},
    }

    pcall(function()
        local descendants = Workspace:GetDescendants()

        for _, desc in ipairs(descendants) do
            if desc:IsA("ProximityPrompt") then
                table.insert(State.objects.prompts, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    parent = desc.Parent and desc.Parent.Name or "",
                    holdDuration = desc.HoldDuration,
                    enabled = desc.Enabled,
                    actionText = desc.ActionText or "",
                    objectText = desc.ObjectText or "",
                    keyboardEnabled = desc.KeyboardEnabled,
                    gamepadEnabled = desc.GamepadEnabled,
                    maxActivationDistance = desc.MaxActivationDistance,
                })
            elseif desc:IsA("ClickDetector") then
                table.insert(State.objects.clickDetectors, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    parent = desc.Parent and desc.Parent.Name or "",
                    maxActivationDistance = desc.MaxActivationDistance,
                    cursorIcon = desc.CursorIcon or "",
                })
            elseif desc:IsA("SpawnLocation") then
                table.insert(State.objects.spawns, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    position = tostring(desc.Position),
                    duration = desc.Duration,
                    neutral = desc.Neutral,
                    enabled = desc.Enabled,
                    teamColor = tostring(desc.TeamColor),
                    spawnLocationType = tostring(desc.SpawnLocationType),
                })
            elseif desc:IsA("Highlight") then
                table.insert(State.objects.highlights, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    enabled = desc.Enabled,
                    fillTransparency = desc.FillTransparency,
                    outlineTransparency = desc.OutlineTransparency,
                    fillColor = tostring(desc.FillColor),
                    outlineColor = tostring(desc.OutlineColor),
                })
            elseif desc:IsA("BillboardGui") then
                table.insert(State.objects.billboards, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    enabled = desc.Enabled,
                    size = tostring(desc.Size),
                    alwaysOnTop = desc.AlwaysOnTop,
                    lightInfluence = desc.LightInfluence,
                    maxDistance = desc.MaxDistance,
                })
            elseif desc:IsA("SurfaceGui") then
                table.insert(State.objects.surfaces, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    enabled = desc.Enabled,
                    canvasSize = tostring(desc.CanvasSize),
                    face = tostring(desc.Face),
                })
            elseif desc:IsA("Model") then
                local hum = desc:FindFirstChildOfClass("Humanoid")
                if hum and not Players:GetPlayerFromCharacter(desc) then
                    local root = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChild("RootPart") or desc.PrimaryPart
                    local childNames = {}
                    for _, c in ipairs(desc:GetChildren()) do table.insert(childNames, c.Name) end

                    local stateList = {}
                    pcall(function()
                        for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
                            if hum:GetStateEnabled(state) then
                                table.insert(stateList, tostring(state))
                            end
                        end
                    end)

                    local attrs = {}
                    pcall(function()
                        for _, name in ipairs(desc:GetAttributes()) do
                            table.insert(attrs, name .. "=" .. tostring(desc:GetAttribute(name)))
                        end
                    end)

                    table.insert(State.objects.humanoids, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        health = hum.Health,
                        maxHealth = hum.MaxHealth,
                        walkSpeed = hum.WalkSpeed,
                        jumpHeight = hum.JumpHeight,
                        jumpPower = hum.JumpPower,
                        position = root and tostring(root.Position) or "unknown",
                        hasAnimator = desc:FindFirstChildOfClass("Animator") ~= nil,
                        childCount = #desc:GetChildren(),
                        children = table.concat(childNames, ", "),
                        states = table.concat(stateList, ", "),
                        attributes = table.concat(attrs, ", "),
                        rigType = tostring(hum.RigType),
                        displayName = hum.DisplayName or "",
                    })
                end
            end

            -- Value objects
            if desc:IsA("IntValue") or desc:IsA("NumberValue") or
               desc:IsA("StringValue") or desc:IsA("BoolValue") or
               desc:IsA("CFrameValue") or desc:IsA("Color3Value") or
               desc:IsA("Vector3Value") or desc:IsA("ObjectValue") or
               desc:IsA("BrickColorValue") or desc:IsA("RayValue") or
               desc:IsA("RangeValue") or desc:IsA("BinaryStringValue") then
                table.insert(State.objects.values, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    class = desc.ClassName,
                    value = tostring(desc.Value):sub(1, 100),
                })
            end

            if desc:IsA("Configuration") then
                local childValues = {}
                for _, c in ipairs(desc:GetChildren()) do
                    if c:IsA("ValueBase") then
                        table.insert(childValues, c.Name .. "=" .. tostring(c.Value):sub(1, 50))
                    end
                end
                table.insert(State.objects.configurations, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    children = table.concat(childValues, ", "),
                })
            end
        end

        if #descendants % 500 == 0 then
            RunService.RenderStepped:Wait()
        end
    end)

    print(string.format("[Auto] Objects: %d Prompts, %d Clicks, %d NPCs, %d Spawns, %d Highlights, %d Billboards, %d Surfaces, %d Values, %d Configs",
        #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns,
        #State.objects.highlights, #State.objects.billboards, #State.objects.surfaces,
        #State.objects.values, #State.objects.configurations))
    return State.objects
end

-- ============================================
-- ASSET SCANNER (new v8.0)
-- ============================================
local function autoScanAssets()
    State.assets = { sounds = {}, animations = {}, decals = {}, meshes = {}, textures = {}, models = {} }

    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("Sound") then
                table.insert(State.assets.sounds, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    soundId = desc.SoundId,
                    volume = desc.Volume,
                    looped = desc.Looped,
                    playing = desc.IsPlaying,
                    playbackSpeed = desc.PlaybackSpeed,
                })
            elseif desc:IsA("Animation") then
                table.insert(State.assets.animations, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    animationId = desc.AnimationId,
                })
            elseif desc:IsA("Decal") then
                table.insert(State.assets.decals, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    texture = desc.Texture,
                    face = tostring(desc.Face),
                })
            elseif desc:IsA("SpecialMesh") or desc:IsA("MeshPart") then
                local meshId = desc.MeshId or desc.MeshId
                local texId = desc.TextureID or desc.TextureId
                table.insert(State.assets.meshes, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    class = desc.ClassName,
                    meshId = meshId or "",
                    textureId = texId or "",
                })
            elseif desc:IsA("Texture") then
                table.insert(State.assets.textures, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    texture = desc.Texture,
                    face = tostring(desc.Face),
                })
            end
        end
    end)

    pcall(function()
        for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
            if desc:IsA("Sound") then
                table.insert(State.assets.sounds, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    soundId = desc.SoundId,
                    volume = desc.Volume,
                    looped = desc.Looped,
                    playing = desc.IsPlaying,
                })
            elseif desc:IsA("Animation") then
                table.insert(State.assets.animations, {
                    path = desc:GetFullName(),
                    name = desc.Name,
                    animationId = desc.AnimationId,
                })
            end
        end
    end)

    local total = #State.assets.sounds + #State.assets.animations + #State.assets.decals +
                  #State.assets.meshes + #State.assets.textures + #State.assets.models
    print(string.format("[Auto] Assets: %d Sounds, %d Animations, %d Decals, %d Meshes, %d Textures (%d total)",
        #State.assets.sounds, #State.assets.animations, #State.assets.decals,
        #State.assets.meshes, #State.assets.textures, total))
    return State.assets
end

-- ============================================
-- ATTRIBUTE SCANNER (new v8.0)
-- ============================================
local function autoScanAttributes()
    State.attributes = {}
    local containers = getContainers()

    for _, cd in ipairs(containers) do
        pcall(function()
            for _, desc in ipairs(cd[1]:GetDescendants()) do
                local attrs = desc:GetAttributes()
                local count = 0
                for _ in pairs(attrs) do count = count + 1 end
                if count > 0 then
                    local attrStrs = {}
                    for name, value in pairs(attrs) do
                        table.insert(attrStrs, name .. "=" .. tostring(value):sub(1, 50))
                    end
                    table.insert(State.attributes, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        class = desc.ClassName,
                        count = count,
                        attributes = table.concat(attrStrs, ", "),
                    })
                end
            end
        end)
    end

    print(string.format("[Auto] Attributes: %d instances with attributes", #State.attributes))
    return State.attributes
end

-- ============================================
-- COLLECTION SERVICE TAG SCANNER (new v8.0)
-- ============================================
local function autoScanTags()
    State.tags = {}

    pcall(function()
        local allTags = {}
        local containers = getContainers()

        for _, cd in ipairs(containers) do
            pcall(function()
                for _, desc in ipairs(cd[1]:GetDescendants()) do
                    local tags = CollectionService:GetTags(desc)
                    if #tags > 0 then
                        for _, tag in ipairs(tags) do
                            allTags[tag] = allTags[tag] or {}
                            table.insert(allTags[tag], {
                                path = desc:GetFullName(),
                                name = desc.Name,
                                class = desc.ClassName,
                            })
                        end
                    end
                end
            end)
        end

        for tag, instances in pairs(allTags) do
            table.insert(State.tags, {
                tag = tag,
                count = #instances,
                instances = instances,
            })
        end

        table.sort(State.tags, function(a, b) return a.count > b.count end)
    end)

    print(string.format("[Auto] Tags: %d unique CollectionService tags", #State.tags))
    return State.tags
end

-- ============================================
-- TEAMS & STATS (expanded)
-- ============================================
local function autoScanTeamsStats()
    State.teams = {}
    State.leaderstats = {}

    pcall(function()
        for _, team in ipairs(Teams:GetChildren()) do
            if team:IsA("Team") then
                local playerNames = {}
                for _, p in ipairs(team:GetPlayers()) do table.insert(playerNames, p.Name) end
                table.insert(State.teams, {
                    name = team.Name,
                    color = tostring(team.TeamColor.Color),
                    players = #team:GetPlayers(),
                    autoAssignable = team.AutoAssignable,
                    playerNames = table.concat(playerNames, ", "),
                    teamColorName = tostring(team.TeamColor),
                })
            end
        end
    end)

    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            for _, stat in ipairs(ls:GetChildren()) do
                table.insert(State.leaderstats, {
                    name = stat.Name,
                    class = stat.ClassName,
                    value = tostring(stat.Value),
                })
            end
        end
    end)

    -- Also scan for other stat folders
    pcall(function()
        for _, child in ipairs(LocalPlayer:GetChildren()) do
            if child.Name ~= "leaderstats" and child:IsA("Folder") then
                for _, stat in ipairs(child:GetChildren()) do
                    if stat:IsA("ValueBase") then
                        table.insert(State.leaderstats, {
                            name = child.Name .. "." .. stat.Name,
                            class = stat.ClassName,
                            value = tostring(stat.Value),
                        })
                    end
                end
            end
        end
    end)

    print(string.format("[Auto] Teams: %d, Leaderstats: %d", #State.teams, #State.leaderstats))
    return { teams = State.teams, leaderstats = State.leaderstats }
end

-- ============================================
-- GUI SCANNER (expanded)
-- ============================================
local function autoScanGUIs()
    State.guis = {}

    local function scanContainer(container, containerName)
        pcall(function()
            for _, desc in ipairs(container:GetDescendants()) do
                if desc:IsA("ScreenGui") then
                    local childCount = 0
                    local frameCount = 0
                    local buttonCount = 0
                    local labelCount = 0
                    for _, d in ipairs(desc:GetDescendants()) do
                        childCount = childCount + 1
                        if d:IsA("Frame") then frameCount = frameCount + 1
                        elseif d:IsA("TextButton") or d:IsA("ImageButton") then buttonCount = buttonCount + 1
                        elseif d:IsA("TextLabel") or d:IsA("ImageLabel") then labelCount = labelCount + 1 end
                    end
                    table.insert(State.guis, {
                        path = desc:GetFullName(),
                        name = desc.Name,
                        container = containerName,
                        enabled = desc.Enabled,
                        childCount = childCount,
                        frames = frameCount,
                        buttons = buttonCount,
                        labels = labelCount,
                        resetOnSpawn = desc.ResetOnSpawn,
                        ignoreGuiInset = desc.IgnoreGuiInset,
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
-- EXECUTOR CAPABILITY CHECKER (v8.0 — massively expanded)
-- ============================================
local execFuncDefs = {
    -- Interaction
    {name = "firetouchinterest", desc = "Fire touch events", category = "Interaction"},
    {name = "fireproximityprompt", desc = "Fire proximity prompts", category = "Interaction"},
    {name = "fireclickdetector", desc = "Fire click detectors", category = "Interaction"},
    {name = "firesignal", desc = "Fire signal/event", category = "Interaction"},
    {name = "firecallback", desc = "Fire callback", category = "Interaction"},
    -- Metatable
    {name = "getrawmetatable", desc = "Get raw metatable", category = "Metatable"},
    {name = "setreadonly", desc = "Set table readonly", category = "Metatable"},
    {name = "getreadonly", desc = "Get readonly state", category = "Metatable"},
    {name = "getnamecallmethod", desc = "Get namecall method", category = "Metatable"},
    {name = "newcclosure", desc = "Anti-tamper closure", category = "Metatable"},
    {name = "hookfunction", desc = "Hook functions", category = "Metatable"},
    {name = "hookmetamethod", desc = "Hook metamethods", category = "Metatable"},
    {name = "iscclosure", desc = "Check C closure", category = "Metatable"},
    {name = "islclosure", desc = "Check Lua closure", category = "Metatable"},
    {name = "iswxclosure", desc = "Check WX closure", category = "Metatable"},
    -- Utility
    {name = "setclipboard", desc = "Copy to clipboard", category = "Utility"},
    {name = "writefile", desc = "Write files", category = "Utility"},
    {name = "readfile", desc = "Read files", category = "Utility"},
    {name = "appendfile", desc = "Append to files", category = "Utility"},
    {name = "makefolder", desc = "Create folders", category = "Utility"},
    {name = "isfolder", desc = "Check folder exists", category = "Utility"},
    {name = "isfile", desc = "Check file exists", category = "Utility"},
    {name = "listfiles", desc = "List files in folder", category = "Utility"},
    {name = "delfile", desc = "Delete files", category = "Utility"},
    {name = "delfolder", desc = "Delete folders", category = "Utility"},
    {name = "loadfile", desc = "Load file", category = "Utility"},
    {name = "dofile", desc = "Do file", category = "Utility"},
    -- Decompiler
    {name = "decompile", desc = "Decompile scripts", category = "Decompiler"},
    {name = "getsrc", desc = "Get script source", category = "Decompiler"},
    {name = "getscriptbytecode", desc = "Get bytecode", category = "Decompiler"},
    {name = "getscripthash", desc = "Get script hash", category = "Decompiler"},
    {name = "getscripts", desc = "Get all scripts", category = "Decompiler"},
    {name = "getrunningscripts", desc = "Get running scripts", category = "Decompiler"},
    {name = "getscriptclosure", desc = "Get script closure", category = "Decompiler"},
    {name = "getsymbol", desc = "Get symbol", category = "Decompiler"},
    -- Environment
    {name = "gethui", desc = "Get CoreGui parent", category = "Environment"},
    {name = "getgenv", desc = "Global environment", category = "Environment"},
    {name = "getreg", desc = "Get registry", category = "Environment"},
    {name = "getrenv", desc = "Get registry env", category = "Environment"},
    {name = "getidentity", desc = "Get security identity", category = "Environment"},
    {name = "getthreadidentity", desc = "Get thread identity", category = "Environment"},
    {name = "setidentity", desc = "Set security identity", category = "Environment"},
    {name = "setthreadidentity", desc = "Set thread identity", category = "Environment"},
    {name = "syn_setidentity", desc = "Synapse set identity", category = "Environment"},
    {name = "getcallingstack", desc = "Get calling stack", category = "Environment"},
    {name = "getcallingscript", desc = "Get calling script", category = "Environment"},
    -- Network
    {name = "syn_request", desc = "Synapse HTTP request", category = "Network"},
    {name = "request", desc = "HTTP request", category = "Network"},
    {name = "http_get", desc = "HTTP GET", category = "Network"},
    {name = "http_post", desc = "HTTP POST", category = "Network"},
    {name = "http_request", desc = "HTTP request (alt)", category = "Network"},
    {name = "websocket", desc = "WebSocket support", category = "Network"},
    {name = "websocketsend", desc = "WebSocket send", category = "Network"},
    {name = "websocketconnect", desc = "WebSocket connect", category = "Network"},
    {name = "queue_on_teleport", desc = "Queue on teleport", category = "Network"},
    -- Execution
    {name = "loadstring", desc = "Load string", category = "Execution"},
    {name = "loadstringEx", desc = "Extended loadstring", category = "Execution"},
    {name = "setsimulationradius", desc = "Set simulation radius", category = "Execution"},
    {name = "setfpscap", desc = "Set FPS cap", category = "Execution"},
    {name = "getfpscap", desc = "Get FPS cap", category = "Execution"},
    {name = "identifyexecutor", desc = "Identify executor", category = "Execution"},
    {name = "lz4compress", desc = "LZ4 compress", category = "Execution"},
    {name = "lz4decompress", desc = "LZ4 decompress", category = "Execution"},
    -- Asset
    {name = "getcustomasset", desc = "Get custom asset", category = "Asset"},
    {name = "getcustomassetfunc", desc = "Custom asset function", category = "Asset"},
    {name = "saveinstance", desc = "Save instance", category = "Asset"},
    {name = "saveinstanceEx", desc = "Extended save instance", category = "Asset"},
    -- Instance
    {name = "getinstances", desc = "Get all instances", category = "Instance"},
    {name = "getnilinstances", desc = "Get nil instances", category = "Instance"},
    {name = "gethiddenproperty", desc = "Get hidden property", category = "Instance"},
    {name = "sethiddenproperty", desc = "Set hidden property", category = "Instance"},
    {name = "isluau", desc = "Check if Luau", category = "Instance"},
    {name = "getinitializedstate", desc = "Get initialized state", category = "Instance"},
    -- Crypto
    {name = "crypt.hash", desc = "Crypt hash", category = "Crypto"},
    {name = "crypt.base64encode", desc = "Base64 encode", category = "Crypto"},
    {name = "crypt.base64decode", desc = "Base64 decode", category = "Crypto"},
    {name = "base64encode", desc = "Base64 encode (alt)", category = "Crypto"},
    {name = "base64decode", desc = "Base64 decode (alt)", category = "Crypto"},
    -- Drawing
    {name = "drawing", desc = "Drawing API", category = "Drawing"},
    {name = "Drawing", desc = "Drawing API (alt)", category = "Drawing"},
    {name = "drawtext", desc = "Draw text", category = "Drawing"},
    -- Debug
    {name = "getloadedmodules", desc = "Get loaded modules", category = "Debug"},
    {name = "getloadedfunctions", desc = "Get loaded functions", category = "Debug"},
    -- Misc
    {name = "setclipboard", desc = "Set clipboard", category = "Misc"},
    {name = "random", desc = "Random override", category = "Misc"},
    {name = "mouse1click", desc = "Mouse1 click", category = "Misc"},
    {name = "mouse1press", desc = "Mouse1 press", category = "Misc"},
    {name = "mouse1release", desc = "Mouse1 release", category = "Misc"},
    {name = "mouse2click", desc = "Mouse2 click", category = "Misc"},
    {name = "keypress", desc = "Key press", category = "Misc"},
    {name = "keyrelease", desc = "Key release", category = "Misc"},
    {name = "keyclick", desc = "Key click", category = "Misc"},
    {name = "isrenderstep", desc = "Is render step", category = "Misc"},
}

-- Deduplicate
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
local execByCategory = {}

local function autoCheckExecutor()
    State.executorCaps = {}
    execTotalAvailable = 0
    execTotalChecked = 0
    execByCategory = {}

    -- Try to identify executor
    State.executorInfo = "Unknown"
    pcall(function()
        if type(identifyexecutor) == "function" then
            local name, version = identifyexecutor()
            if name then
                State.executorInfo = name .. (version and (" v" .. tostring(version)) or "")
            end
        end
    end)
    if State.executorInfo == "Unknown" then
        pcall(function()
            if type(getgenv) == "function" then
                local g = getgenv()
                if g.syn then State.executorInfo = "Synapse X"
                elseif g.Krnl then State.executorInfo = "Krnl"
                elseif g.ScriptWare then State.executorInfo = "Script Ware"
                elseif g.Fluxus then State.executorInfo = "Fluxus"
                elseif g.Electron then State.executorInfo = "Electron"
                end
            end
        end)
    end

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
                if type(_G[f.name]) == "function" then avail = true end
            end)
        end
        if not avail then
            pcall(function()
                if type(getgenv) == "function" then
                    local g = getgenv()
                    if type(g[f.name]) == "function" then avail = true end
                end
            end)
        end
        if not avail and f.name:find("%.") then
            pcall(function()
                local parts = {}
                for part in f.name:gmatch("[^%.]+") do table.insert(parts, part) end
                if #parts == 2 then
                    local g = getgenv()
                    if g[parts[1]] and type(g[parts[1]][parts[2]]) == "function" then avail = true end
                end
            end)
        end

        table.insert(State.executorCaps, {
            name = f.name,
            desc = f.desc,
            category = f.category,
            available = avail,
        })

        execByCategory[f.category] = execByCategory[f.category] or {total = 0, available = 0}
        execByCategory[f.category].total = execByCategory[f.category].total + 1
        if avail then
            execByCategory[f.category].available = execByCategory[f.category].available + 1
            execTotalAvailable = execTotalAvailable + 1
        end
        execTotalChecked = execTotalChecked + 1
    end

    State.execCapsComplete = true
    print(string.format("[Auto] Executor: %s — %d/%d functions available",
        State.executorInfo, execTotalAvailable, execTotalChecked))
    return State.executorCaps
end

-- ============================================
-- KEYWORD SEARCH (optimized: line split instead of char-by-char)
-- ============================================
local function autoKeywordSearch()
    if #State.results == 0 then return {} end

    local keywords = {
        "FireServer", "InvokeServer", "WalkSpeed", "Gravity", "Health", "Damage",
        "Currency", "Cash", "Coin", "Rebirth", "Spin", "Buy", "Sell", "Reward",
        "Touched", "ProximityPrompt", "ClickDetector", "Teleport", "CFrame",
        "Humanoid", "Monster", "NPC", "Boss", "RemoteEvent", "RemoteFunction",
        "LocalScript", "Script", "ModuleScript", "Workspace", "ReplicatedStorage",
        "getfenv", "setfenv", "loadstring", "require", "pcall", "spawn",
        "DataStore", "HttpService", "JSONEncode", "JSONDecode", "game.HttpGet",
        "crypt", "base64", "exploit", "cheat", "backdoor", "admin",
        "kick", "ban", "teleport", "Instance.new", "math.random",
        "os.time", "tick", "wait", "task.wait", "RunService",
        "UserInputService", "ContextActionService", "TweenService",
        "BindableEvent", "BindableFunction", "CollectionService",
    }

    State.keywordResults = {}
    local totalMatches = 0

    for _, kw in ipairs(keywords) do
        local kwMatches = { keyword = kw, count = 0, matches = {} }
        local searchKw = kw:lower()

        for _, r in ipairs(State.results) do
            if r.source and r.status == "OK" then
                -- Split source into lines ONCE, search per line
                local lines = r.source:split("\n")
                for lineNum, line in ipairs(lines) do
                    local lineLower = line:lower()
                    if lineLower:find(searchKw, 1, true) then
                        kwMatches.count = kwMatches.count + 1
                        if #kwMatches.matches < 5 then
                            table.insert(kwMatches.matches, {
                                script = r.path,
                                line = lineNum,
                                text = line:gsub("^%s+", ""):sub(1, 120),
                            })
                        end
                    end
                end
            end
        end

        if kwMatches.count > 0 then
            table.insert(State.keywordResults, kwMatches)
            totalMatches = totalMatches + kwMatches.count
        end
    end

    print(string.format("[Auto] Keywords: %d matches across %d keywords", totalMatches, #State.keywordResults))
    return State.keywordResults
end

-- ============================================
-- ANTI-CHEAT & BACKDOOR DETECTION (new v8.0)
-- ============================================
local antiCheatPatterns = {
    "anticheat", "anti-cheat", "anti_cheat", "ac_", "cheat", "exploit",
    "detect", "flag", "suspect", "verify", "integrity", "checksum",
    "sanitycheck", "tamper", "velocity", "fly", "noclip", "speedhack",
    "walkspeed", "jumppower", "teleport", "instant", "godmode",
    "infinite", "unlim", "bypass", "kick", "crash", "shutdown",
    "shadow", "monitor", "track", "screenshot", "record",
}

local backdoorPatterns = {
    "loadstring", "HttpGet", "http_get", "request(",
    "game:HttpGet", "sync_to_server", "syn.request",
    "pcall%(loadstring", "loadstring%(game",
    "require%(game", "getfenv", "setfenv",
    "local source = ", "loadstring%(source",
    "ExecuteScript", "RunScript", "RemoteAccess",
    "Backdoor", "backdoor", "admin%.",
    "command%.", "SourceCode", "getsrc",
}

local function autoScanAntiCheatBackdoors()
    State.antiCheatDetections = {}
    State.backdoorDetections = {}

    for _, r in ipairs(State.results) do
        if r.source and r.status == "OK" then
            local sourceLower = r.source:lower()
            local lines = r.source:split("\n")

            -- Anti-cheat detection
            for _, pattern in ipairs(antiCheatPatterns) do
                local patLower = pattern:lower()
                if sourceLower:find(patLower, 1, true) then
                    for lineNum, line in ipairs(lines) do
                        if line:lower():find(patLower, 1, true) then
                            local alreadyDetected = false
                            for _, det in ipairs(State.antiCheatDetections) do
                                if det.script == r.path and det.line == lineNum then
                                    alreadyDetected = true
                                    break
                                end
                            end
                            if not alreadyDetected then
                                table.insert(State.antiCheatDetections, {
                                    script = r.path,
                                    line = lineNum,
                                    pattern = pattern,
                                    text = line:gsub("^%s+", ""):sub(1, 150),
                                    category = r.category,
                                })
                            end
                        end
                    end
                end
            end

            -- Backdoor detection
            for _, pattern in ipairs(backdoorPatterns) do
                local patLower = pattern:lower()
                if sourceLower:find(patLower, 1, true) then
                    for lineNum, line in ipairs(lines) do
                        if line:lower():find(patLower, 1, true) then
                            table.insert(State.backdoorDetections, {
                                script = r.path,
                                line = lineNum,
                                pattern = pattern,
                                text = line:gsub("^%s+", ""):sub(1, 150),
                                category = r.category,
                            })
                        end
                    end
                end
            end
        end
    end

    print(string.format("[Auto] Anti-Cheat: %d detections | Backdoors: %d detections",
        #State.antiCheatDetections, #State.backdoorDetections))
    return {antiCheat = State.antiCheatDetections, backdoors = State.backdoorDetections}
end

-- ============================================
-- REQUIRE DEPENDENCY MAPPER (new v8.0)
-- ============================================
local function autoScanRequireMap()
    State.requireMap = {}
    if #State.results == 0 then return {} end

    local requirePattern = "require%("

    for _, r in ipairs(State.results) do
        if r.source and r.status == "OK" then
            local lines = r.source:split("\n")
            for lineNum, line in ipairs(lines) do
                if line:lower():find(requirePattern, 1, true) then
                    -- Try to extract the require argument
                    local arg = line:match("require%s*%(%s*(.-)s*%)")
                    if not arg then
                        arg = line:match("require%s+(.+)")
                    end
                    table.insert(State.requireMap, {
                        script = r.path,
                        line = lineNum,
                        target = arg and arg:sub(1, 100) or "unknown",
                        text = line:gsub("^%s+", ""):sub(1, 150),
                        category = r.category,
                    })
                end
            end
        end
    end

    print(string.format("[Auto] Require Map: %d require() calls found", #State.requireMap))
    return State.requireMap
end

-- ============================================
-- TOUCH EVENTS (optimized)
-- ============================================
local function autoScanTouchEvents()
    State.touchEvents = {}
    for _, r in ipairs(State.results) do
        if r.source and r.status == "OK" then
            if r.source:lower():find("touched", 1, true) then
                local lines = r.source:split("\n")
                for lineNum, line in ipairs(lines) do
                    if line:lower():find("touched", 1, true) then
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
-- DEEP SCAN (v8.0 — expanded with state changes, attr changes, removals)
-- ============================================
local function restoreNamecallHook()
    if State.namecallHooked and State.originalNamecall then
        pcall(function()
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__namecall = State.originalNamecall
            setreadonly(mt, true)
        end)
        State.namecallHooked = false
        State.originalNamecall = nil
    end
end

local function startDeepScan(duration)
    duration = duration or State.deepScanDuration or 300
    if State.deepScanning then return end
    State.deepScanning = true
    State.deepData = {
        promptInteractions = {},
        monsterSpawns = {},
        monsterMoves = {},
        workspaceAdds = {},
        workspaceRemoves = {},
        remoteCalls = {},
        remoteCallProfiles = {},
        playerPositions = {},
        attributeChanges = {},
        humanoidStateChanges = {},
        startTime = tick(),
    }
    safeNotify("Deep Scan", string.format("Starting %d-second deep monitoring...", duration))
    print("[Deep Scan] Monitoring game for " .. duration .. " seconds...")

    -- Prompt interactions
    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
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

    -- Workspace additions
    connections.deepWorkspace = Workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("Model") and desc:FindFirstChildOfClass("Humanoid") then
            local hum = desc:FindFirstChildOfClass("Humanoid")
            local root = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChild("RootPart")
            local childNames = {}
            for _, c in ipairs(desc:GetChildren()) do table.insert(childNames, c.Name) end
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

            -- Track humanoid state changes for this new entity
            if hum then
                pcall(function()
                    local lastState = hum:GetState()
                    local stateConn
                    stateConn = RunService.Heartbeat:Connect(function()
                        if not State.deepScanning or not desc.Parent then
                            if stateConn then stateConn:Disconnect() end
                            return
                        end
                        local currentState = hum:GetState()
                        if currentState ~= lastState then
                            table.insert(State.deepData.humanoidStateChanges, {
                                time = os.date("%H:%M:%S"),
                                entity = desc.Name,
                                path = desc:GetFullName(),
                                from = tostring(lastState),
                                to = tostring(currentState),
                                health = hum.Health,
                            })
                            lastState = currentState
                        end
                    end)
                end)
            end
        else
            table.insert(State.deepData.workspaceAdds, {
                time = os.date("%H:%M:%S"),
                name = desc.Name,
                class = desc.ClassName,
                path = desc:GetFullName(),
            })
        end
    end)

    -- Workspace removals (new)
    connections.deepWorkspaceRem = Workspace.DescendantRemoving:Connect(function(desc)
        if not Players:GetPlayerFromCharacter(desc) then
            table.insert(State.deepData.workspaceRemoves, {
                time = os.date("%H:%M:%S"),
                name = desc.Name,
                class = desc.ClassName,
                path = desc:GetFullName(),
            })
            if #State.deepData.workspaceRemoves > 500 then
                table.remove(State.deepData.workspaceRemoves, 1)
            end
        end
    end)

    -- Monster movement sampling
    local lastMoveSample = 0
    connections.deepMonsterMove = RunService.Heartbeat:Connect(function()
        if not State.deepScanning then return end
        if tick() - lastMoveSample < 5 then return end
        lastMoveSample = tick()

        local monsters = Workspace:FindFirstChild("Monsters")
        if not monsters then
            -- Try common folder names
            for _, folderName in ipairs({"Enemies", "NPCs", "Mobs", "Creatures", "AI", "Hostiles"}) do
                monsters = Workspace:FindFirstChild(folderName)
                if monsters then break end
            end
        end

        if monsters then
            for _, monster in ipairs(monsters:GetChildren()) do
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

    -- Player position sampling
    local lastPlayerSample = 0
    connections.deepPlayerPos = RunService.Heartbeat:Connect(function()
        if not State.deepScanning then return end
        if tick() - lastPlayerSample < 10 then return end
        lastPlayerSample = tick()
        for _, player in ipairs(Players:GetPlayers()) do
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

    -- Attribute change monitoring (new)
    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("Model") or desc:IsA("Part") or desc:IsA("Humanoid") then
                local initialAttrs = desc:GetAttributes()
                for attrName, attrValue in pairs(initialAttrs) do
                    desc.AttributeChanged:Connect(function(changedName)
                        if changedName == attrName and State.deepScanning then
                            local newVal = desc:GetAttribute(changedName)
                            table.insert(State.deepData.attributeChanges, {
                                time = os.date("%H:%M:%S"),
                                instance = desc.Name,
                                path = desc:GetFullName(),
                                attribute = changedName,
                                oldValue = tostring(attrValue),
                                newValue = tostring(newVal),
                            })
                            if #State.deepData.attributeChanges > 500 then
                                table.remove(State.deepData.attributeChanges, 1)
                            end
                        end
                    end)
                end
            end
        end
    end)

    -- Remote call interception with proper hooking
    pcall(function()
        local mt = getrawmetatable(game)
        if mt then
            setreadonly(mt, false)
            if not State.originalNamecall then
                State.originalNamecall = mt.__namecall
            end
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if (method == "FireServer" or method == "InvokeServer") and self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
                    local args = {...}
                    local argTypes = {}
                    local argStr = ""
                    for i, arg in ipairs(args) do
                        local t = type(arg)
                        local tinfo = t
                        if t == "userdata" and typeof(arg) ~= "userdata" then tinfo = typeof(arg) end
                        if typeof(arg) == "Instance" then tinfo = arg.ClassName end
                        table.insert(argTypes, tinfo)
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
                        argTypes = table.concat(argTypes, ", "),
                    })
                    if #State.deepData.remoteCalls > 1000 then table.remove(State.deepData.remoteCalls, 1) end

                    -- Build remote profile
                    local remoteKey = self.Name
                    if not State.deepData.remoteCallProfiles[remoteKey] then
                        State.deepData.remoteCallProfiles[remoteKey] = {
                            name = self.Name,
                            path = self:GetFullName(),
                            method = method,
                            callCount = 0,
                            argTypeHistory = {},
                        }
                    end
                    local profile = State.deepData.remoteCallProfiles[remoteKey]
                    profile.callCount = profile.callCount + 1
                    table.insert(profile.argTypeHistory, table.concat(argTypes, ", "))
                    if #profile.argTypeHistory > 20 then table.remove(profile.argTypeHistory, 1) end
                end
                return State.originalNamecall(self, ...)
            end)
            setreadonly(mt, true)
            State.namecallHooked = true
        end
    end)

    -- Auto-stop after duration
    task.spawn(function()
        task.wait(duration)
        State.deepScanning = false
        if connections.deepWorkspace then connections.deepWorkspace:Disconnect() connections.deepWorkspace = nil end
        if connections.deepWorkspaceRem then connections.deepWorkspaceRem:Disconnect() connections.deepWorkspaceRem = nil end
        if connections.deepMonsterMove then connections.deepMonsterMove:Disconnect() connections.deepMonsterMove = nil end
        if connections.deepPlayerPos then connections.deepPlayerPos:Disconnect() connections.deepPlayerPos = nil end
        restoreNamecallHook()

        if type(writefile) == "function" then
            local filename = "deepscan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
            local content = "============================================\n"
            content = content .. "Deep Scan Report v8.0 — " .. GameName .. "\n"
            content = content .. "Executor: " .. State.executorInfo .. "\n"
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
                content = content .. string.format("  [%s] %s (%s) args: %s [types: %s]\n", r.time, r.remoteName, r.method, r.args, r.argTypes or "")
            end

            content = content .. "\nREMOTE PROFILES:\n"
            for remoteName, profile in pairs(State.deepData.remoteCallProfiles) do
                content = content .. string.format("  %s (%s) — %d calls, path: %s\n", remoteName, profile.method, profile.callCount, profile.path)
                content = content .. "    Arg type samples:\n"
                for i, types in ipairs(profile.argTypeHistory) do
                    if i <= 5 then content = content .. "      [" .. i .. "] " .. types .. "\n" end
                end
            end

            content = content .. string.format("\nWORKSPACE ADDITIONS (%d):\n", #State.deepData.workspaceAdds)
            for _, w in ipairs(State.deepData.workspaceAdds) do
                content = content .. string.format("  [%s] %s (%s) at %s\n", w.time, w.name, w.class, w.path)
            end

            content = content .. string.format("\nWORKSPACE REMOVALS (%d):\n", #State.deepData.workspaceRemoves)
            for _, w in ipairs(State.deepData.workspaceRemoves) do
                content = content .. string.format("  [%s] %s (%s) at %s\n", w.time, w.name, w.class, w.path)
            end

            content = content .. string.format("\nHUMANOID STATE CHANGES (%d):\n", #State.deepData.humanoidStateChanges)
            for _, s in ipairs(State.deepData.humanoidStateChanges) do
                content = content .. string.format("  [%s] %s: %s -> %s (HP: %d)\n", s.time, s.entity, s.from, s.to, s.health)
            end

            content = content .. string.format("\nATTRIBUTE CHANGES (%d):\n", #State.deepData.attributeChanges)
            for _, a in ipairs(State.deepData.attributeChanges) do
                content = content .. string.format("  [%s] %s.%s: %s -> %s\n", a.time, a.instance, a.attribute, a.oldValue, a.newValue)
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
            safeNotify("Deep Scan Complete", string.format("Saved: %s\nPrompts: %d | Spawns: %d | Remotes: %d | Profiles: %d",
                filename, #State.deepData.promptInteractions, #State.deepData.monsterSpawns,
                #State.deepData.remoteCalls, 0))
        else
            safeNotify("Deep Scan Complete", "Data in memory. Use Print button.")
        end
    end)
end

-- ============================================
-- AUTO-RUN ALL SUB-SCANS (v8.0 — expanded)
-- ============================================
local function autoRunAllScans()
    if State.autoRunComplete then return end
    safeNotify("Auto-Scan", "Running all sub-scanners automatically...")
    print("[Auto] Starting automatic sub-scans...")

    local totalSteps = 11
    updateProgress(0, totalSteps, "Auto-Scan", "Scanning remotes...")
    autoScanRemotes()
    task.wait(0.3)

    updateProgress(1, totalSteps, "Auto-Scan", "Scanning workspace objects...")
    autoScanObjects()
    task.wait(0.3)

    updateProgress(2, totalSteps, "Auto-Scan", "Scanning teams & stats...")
    autoScanTeamsStats()
    task.wait(0.3)

    updateProgress(3, totalSteps, "Auto-Scan", "Scanning GUIs...")
    autoScanGUIs()
    task.wait(0.3)

    updateProgress(4, totalSteps, "Auto-Scan", "Scanning assets...")
    autoScanAssets()
    task.wait(0.3)

    updateProgress(5, totalSteps, "Auto-Scan", "Scanning attributes...")
    autoScanAttributes()
    task.wait(0.3)

    updateProgress(6, totalSteps, "Auto-Scan", "Scanning CollectionService tags...")
    autoScanTags()
    task.wait(0.3)

    updateProgress(7, totalSteps, "Auto-Scan", "Checking executor...")
    autoCheckExecutor()
    task.wait(0.3)

    updateProgress(8, totalSteps, "Auto-Scan", "Searching keywords...")
    autoKeywordSearch()
    task.wait(0.3)

    updateProgress(9, totalSteps, "Auto-Scan", "Scanning touch events...")
    autoScanTouchEvents()
    task.wait(0.3)

    updateProgress(10, totalSteps, "Auto-Scan", "Scanning anti-cheat & backdoors...")
    autoScanAntiCheatBackdoors()
    autoScanRequireMap()
    task.wait(0.3)

    updateProgress(11, totalSteps, "Auto-Scan", "Complete!")
    task.wait(0.3)

    State.autoRunComplete = true

    safeNotify("Auto-Scan Complete", string.format(
        "Remotes: %d | Objects: %d | Teams: %d | GUIs: %d | Assets: %d | Attrs: %d | Tags: %d | Keywords: %d | AC: %d | Backdoors: %d | Require: %d | Exec: %d/%d (%s)",
        #State.remotes.events + #State.remotes.functions + #State.remotes.bindables + #State.remotes.bindableFuncs,
        #State.objects.prompts + #State.objects.clickDetectors + #State.objects.humanoids,
        #State.teams,
        #State.guis,
        #State.assets.sounds + #State.assets.animations + #State.assets.decals + #State.assets.meshes + #State.assets.textures,
        #State.attributes,
        #State.tags,
        #State.keywordResults,
        #State.antiCheatDetections,
        #State.backdoorDetections,
        #State.requireMap,
        execTotalAvailable, execTotalChecked,
        State.executorInfo
    ))
    print("[Auto] All sub-scans complete.")
end

-- ============================================
-- AUTO-SAVE DUMP (text + JSON option)
-- ============================================
local function autoSaveDump(useJSON)
    if #State.results == 0 then return nil end
    if type(writefile) ~= "function" then return nil end

    local ext = useJSON and ".json" or ".txt"
    local filename = "scan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ext

    if useJSON and type(HttpService) then
        local export = {
            version = "8.0",
            game = GameName,
            placeId = game.PlaceId,
            date = os.date("%Y-%m-%d %H:%M:%S"),
            executor = State.executorInfo,
            stats = State.stats,
            executorCaps = State.executorCaps,
            scripts = {},
        }
        for i, r in ipairs(State.results) do
            export.scripts[i] = {
                index = i,
                path = r.path,
                class = r.class,
                status = r.status,
                container = r.container,
                category = r.category,
                source = r.source,
            }
        end
        local jsonText = HttpService:JSONEncode(export)
        pcall(writefile, filename, jsonText)
    else
        local content = "============================================\n"
        content = content .. "Universal Game Scanner v8.0 Dump\n"
        content = content .. "Game: " .. GameName .. "\n"
        content = content .. "Place ID: " .. tostring(game.PlaceId) .. "\n"
        content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        content = content .. "Executor: " .. State.executorInfo .. "\n"
        content = content .. string.format("Total: %d | OK: %d | Bytecode: %d | Failed: %d | Deduped: %d\n",
            State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed, State.stats.deduped)
        content = content .. string.format("Executor Caps: %d/%d functions available\n", execTotalAvailable, execTotalChecked)
        content = content .. "============================================\n\n"

        content = content .. "SCRIPT INDEX:\n"
        content = content .. string.rep("-", 100) .. "\n"
        for i, r in ipairs(State.results) do
            local t = ""
            if r.class == "LocalScript" then t = "CLIENT"
            elseif r.class == "Script" then t = "SERVER"
            elseif r.class == "ModuleScript" then t = "MODULE" end
            content = content .. string.format("[%d] %s | %s | %s | %s | %s | %s\n",
                i, r.container, r.class, r.status, r.category or "Other", t, r.path)
        end
        content = content .. "\n"

        for i, r in ipairs(State.results) do
            content = content .. string.format("\n=== SCRIPT [%d] ===\nPath: %s\nClass: %s\nStatus: %s\nCategory: %s\n============================================\n",
                i, r.path, r.class, r.status, r.category or "Other")
            if r.source then
                content = content .. r.source .. "\n"
            else
                content = content .. "-- [NO SOURCE]\n"
            end
        end

        pcall(writefile, filename, content)
    end

    State.lastFilename = filename
    print("[Scan] Saved to " .. filename)
    return filename
end

-- ============================================
-- MAIN SCRIPT SCAN (v8.0 — with dedup + iterative)
-- ============================================
local function performScan()
    if State.scanning then return end
    State.scanning = true
    State.results = {}
    State.scriptHashes = {}
    State.stats = {
        total = 0, success = 0, failed = 0, bytecode = 0,
        client = 0, server = 0, module = 0, deduped = 0,
    }

    if not ProgressGui or not ProgressGui.Parent then buildProgressGUI() end
    ProgressGui.Enabled = true
    updateProgress(0, 1, "Counting", "scripts...")

    local containers = getContainers()
    local totalScripts = 0
    for _, cd in ipairs(containers) do
        local container = cd[1]
        if container then
            local d = State.maxDepth > 0 and getDescendantsIterative(container, State.maxDepth) or container:GetDescendants()
            for _, child in ipairs(d) do
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
            local d = State.maxDepth > 0 and getDescendantsIterative(container, State.maxDepth) or container:GetDescendants()
            for _, child in ipairs(d) do
                if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    current = current + 1
                    local path = child:GetFullName()
                    local className = child.ClassName
                    updateProgress(current, totalScripts, name, path)

                    local src, status = getScriptSource(child)

                    -- Deduplication by hash
                    local hash = quickHash(src or path)
                    if State.scriptHashes[hash] then
                        State.stats.deduped = State.stats.deduped + 1
                    else
                        State.scriptHashes[hash] = true
                        if status == "OK" then State.stats.success = State.stats.success + 1
                        elseif status == "BYTECODE" then State.stats.bytecode = State.stats.bytecode + 1
                        else State.stats.failed = State.stats.failed + 1 end

                        if className == "LocalScript" then State.stats.client = State.stats.client + 1
                        elseif className == "Script" then State.stats.server = State.stats.server + 1
                        elseif className == "ModuleScript" then State.stats.module = State.stats.module + 1 end

                        local category = categorizeScript(path, className, src)
                        table.insert(State.results, {
                            path = path,
                            class = className,
                            status = status,
                            source = src,
                            container = name,
                            category = category,
                            instance = child,
                            hash = hash,
                        })
                    end

                    if current % 10 == 0 then task.wait(0.01) end
                end
            end
        end
    end

    updateProgress(totalScripts, totalScripts, "Saving", "to workspace...")
    task.wait(0.3)

    local savedFile = autoSaveDump(false)
    ProgressGui.Enabled = false
    State.scanning = false

    autoRunAllScans()

    if savedFile then
        safeNotify("Scan Complete & Auto-Analyzed",
            string.format("%d scripts | OK: %d | Failed: %d | Deduped: %d\nExecutor: %s\nSaved: %s",
            State.stats.total, State.stats.success, State.stats.failed, State.stats.deduped,
            State.executorInfo, savedFile))
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
    Name = "Universal Scanner v8.0 — " .. GameName,
    LoadingTitle = "Scanning " .. GameName,
    LoadingSubtitle = "v8.0 — Iterative Scan + Remote Profiling + AC Detection + Asset/Attr/Tag Scan",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySettings = { Key = Enum.KeyCode.RightControl, OnPress = function() end }
})

-- ============================================
-- TAB: SCANNER
-- ============================================
local TabScan = Window:CreateTab("Scanner")

TabScan:CreateButton({
    Name = "Scan Game + Auto-Analyze",
    Callback = function() performScan() end
})

TabScan:CreateSlider({
    Name = "Max Scan Depth (0 = Unlimited)",
    Range = {0, 10},
    Increment = 1,
    Suffix = "levels",
    CurrentValue = 0,
    Flag = "MaxDepth",
    Callback = function(val) State.maxDepth = val end
})

TabScan:CreateButton({
    Name = "Re-run All Sub-Scans",
    Callback = function() autoRunAllScans() end
})

TabScan:CreateButton({
    Name = "Export as JSON",
    Callback = function()
        local f = autoSaveDump(true)
        if f then safeNotify("JSON Export", "Saved: " .. f)
        else safeNotify("JSON Export", "Failed — writefile or scan results needed") end
    end
})

TabScan:CreateButton({
    Name = "Clear All Results",
    Callback = function()
        State.results = {}
        State.scriptHashes = {}
        State.stats = {total = 0, success = 0, failed = 0, bytecode = 0, client = 0, server = 0, module = 0, deduped = 0}
        State.remotes = {events = {}, functions = {}, bindables = {}, bindableFuncs = {}, profiles = {}}
        State.objects = {prompts = {}, clickDetectors = {}, humanoids = {}, spawns = {}, highlights = {}, billboards = {}, surfaces = {}, values = {}, configurations = {}}
        State.assets = {sounds = {}, animations = {}, decals = {}, meshes = {}, textures = {}, models = {}}
        State.teams = {}
        State.leaderstats = {}
        State.guis = {}
        State.keywordResults = {}
        State.touchEvents = {}
        State.antiCheatDetections = {}
        State.backdoorDetections = {}
        State.requireMap = {}
        State.attributes = {}
        State.tags = {}
        State.autoRunComplete = false
        State.execCapsComplete = false
        State.lastFilename = ""
        safeNotify("Scanner", "All results cleared.")
    end
})

TabScan:CreateButton({
    Name = "Show Full Stats",
    Callback = function()
        local text = string.format(
            "Scripts: %d | OK: %d | Failed: %d | Deduped: %d\nClient: %d | Server: %d | Module: %d\n\n" ..
            "Remotes: %d Events, %d Functions\nBindables: %d Events, %d Functions\n\n" ..
            "Objects: %d Prompts, %d Clicks, %d NPCs, %d Spawns\nHighlights: %d | Billboards: %d | Surfaces: %d\nValues: %d | Configs: %d\n\n" ..
            "Assets: %d Sounds, %d Animations, %d Decals, %d Meshes, %d Textures\n\n" ..
            "Teams: %d | Leaderstats: %d | GUIs: %d\nAttributes: %d | Tags: %d\n\n" ..
            "Keywords: %d | Touch Events: %d\nAC Detections: %d | Backdoors: %d | Require Calls: %d\n\n" ..
            "Executor: %s — %d/%d functions",
            State.stats.total, State.stats.success, State.stats.failed, State.stats.deduped,
            State.stats.client, State.stats.server, State.stats.module,
            #State.remotes.events, #State.remotes.functions,
            #State.remotes.bindables, #State.remotes.bindableFuncs,
            #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns,
            #State.objects.highlights, #State.objects.billboards, #State.objects.surfaces,
            #State.objects.values, #State.objects.configurations,
            #State.assets.sounds, #State.assets.animations, #State.assets.decals, #State.assets.meshes, #State.assets.textures,
            #State.teams, #State.leaderstats, #State.guis,
            #State.attributes, #State.tags,
            #State.keywordResults, #State.touchEvents,
            #State.antiCheatDetections, #State.backdoorDetections, #State.requireMap,
            State.executorInfo, execTotalAvailable, execTotalChecked)
        safeNotify("Full Stats v8.0", text)
        print(text)
    end
})

-- ============================================
-- TAB: DEEP SCAN
-- ============================================
local TabDeep = Window:CreateTab("Deep Scan")

TabDeep:CreateButton({
    Name = "Start 5-Minute Deep Scan",
    Callback = function() startDeepScan(300) end
})

TabDeep:CreateButton({
    Name = "Start 1-Minute Quick Deep Scan",
    Callback = function() startDeepScan(60) end
})

TabDeep:CreateButton({
    Name = "Stop Deep Scan Early",
    Callback = function()
        State.deepScanning = false
        if connections.deepWorkspace then connections.deepWorkspace:Disconnect() connections.deepWorkspace = nil end
        if connections.deepWorkspaceRem then connections.deepWorkspaceRem:Disconnect() connections.deepWorkspaceRem = nil end
        if connections.deepMonsterMove then connections.deepMonsterMove:Disconnect() connections.deepMonsterMove = nil end
        if connections.deepPlayerPos then connections.deepPlayerPos:Disconnect() connections.deepPlayerPos = nil end
        restoreNamecallHook()
        safeNotify("Deep Scan", "Stopped early. Namecall hook restored.")
    end
})

TabDeep:CreateButton({
    Name = "Print Deep Scan Data",
    Callback = function()
        print("=== DEEP SCAN DATA v8.0 ===")
        print(string.format("Prompt Interactions: %d", #State.deepData.promptInteractions))
        for _, p in ipairs(State.deepData.promptInteractions) do print(string.format("  [%s] %s at %s", p.time, p.prompt, p.path)) end
        print(string.format("\nMonster Spawns: %d", #State.deepData.monsterSpawns))
        for _, m in ipairs(State.deepData.monsterSpawns) do print(string.format("  [%s] %s | HP: %d/%d | Speed: %d | Children: %s", m.time, m.name, m.health, m.maxHealth, m.walkSpeed, m.children)) end
        print(string.format("\nRemote Calls: %d", #State.deepData.remoteCalls))
        for _, r in ipairs(State.deepData.remoteCalls) do print(string.format("  [%s] %s (%s) args: %s [types: %s]", r.time, r.remoteName, r.method, r.args, r.argTypes or "")) end
        print(string.format("\nMonster Movement: %d", #State.deepData.monsterMoves))
        for _, m in ipairs(State.deepData.monsterMoves) do print(string.format("  [%s] %s | Pos: %s | Speed: %d", m.time, m.name, m.position, m.walkSpeed)) end
        print(string.format("\nWorkspace Additions: %d", #State.deepData.workspaceAdds))
        for _, w in ipairs(State.deepData.workspaceAdds) do print(string.format("  [%s] %s (%s) at %s", w.time, w.name, w.class, w.path)) end
        print(string.format("\nWorkspace Removals: %d", #State.deepData.workspaceRemoves))
        for _, w in ipairs(State.deepData.workspaceRemoves) do print(string.format("  [%s] %s (%s) at %s", w.time, w.name, w.class, w.path)) end
        print(string.format("\nHumanoid State Changes: %d", #State.deepData.humanoidStateChanges))
        for _, s in ipairs(State.deepData.humanoidStateChanges) do print(string.format("  [%s] %s: %s -> %s (HP: %d)", s.time, s.entity, s.from, s.to, s.health)) end
        print(string.format("\nAttribute Changes: %d", #State.deepData.attributeChanges))
        for _, a in ipairs(State.deepData.attributeChanges) do print(string.format("  [%s] %s.%s: %s -> %s", a.time, a.instance, a.attribute, a.oldValue, a.newValue)) end
        print("\nRemote Profiles:")
        for name, profile in pairs(State.deepData.remoteCallProfiles) do
            print(string.format("  %s (%s) — %d calls", name, profile.method, profile.callCount))
            for i, types in ipairs(profile.argTypeHistory) do
                if i <= 5 then print("    [" .. i .. "] " .. types) end
            end
        end
        safeNotify("Deep Scan", "Data printed to F9.")
    end
})

TabDeep:CreateButton({
    Name = "Copy Deep Scan Data",
    Callback = function()
        if type(setclipboard) ~= "function" then return end
        local text = "=== DEEP SCAN DATA v8.0 ===\n"
        text = text .. string.format("Prompt Interactions: %d\n", #State.deepData.promptInteractions)
        for _, p in ipairs(State.deepData.promptInteractions) do text = text .. string.format("  [%s] %s at %s\n", p.time, p.prompt, p.path) end
        text = text .. string.format("\nMonster Spawns: %d\n", #State.deepData.monsterSpawns)
        for _, m in ipairs(State.deepData.monsterSpawns) do text = text .. string.format("  [%s] %s | HP: %d/%d | Speed: %d | Children: %s\n", m.time, m.name, m.health, m.maxHealth, m.walkSpeed, m.children) end
        text = text .. string.format("\nRemote Calls: %d\n", #State.deepData.remoteCalls)
        for _, r in ipairs(State.deepData.remoteCalls) do text = text .. string.format("  [%s] %s (%s) args: %s [types: %s]\n", r.time, r.remoteName, r.method, r.args, r.argTypes or "") end
        text = text .. "\nRemote Profiles:\n"
        for name, profile in pairs(State.deepData.remoteCallProfiles) do
            text = text .. string.format("  %s (%s) — %d calls\n", name, profile.method, profile.callCount)
            for i, types in ipairs(profile.argTypeHistory) do
                if i <= 5 then text = text .. "    [" .. i .. "] " .. types .. "\n" end
            end
        end
        pcall(setclipboard, text)
        safeNotify("Deep Scan", "Copied!")
    end
})

TabDeep:CreateSlider({
    Name = "Custom Duration (seconds)",
    Range = {30, 600},
    Increment = 30,
    Suffix = "sec",
    CurrentValue = 300,
    Flag = "DeepScanDur",
    Callback = function(val) State.deepScanDuration = val end
})

TabDeep:CreateButton({
    Name = "Start Custom Duration Deep Scan",
    Callback = function()
        local dur = State.deepScanDuration or 300
        startDeepScan(dur)
    end
})

-- ============================================
-- TAB: AUTO RESULTS
-- ============================================
local TabResults = Window:CreateTab("Auto Results")

TabResults:CreateButton({
    Name = "Print All Remotes (Events + Functions + Bindables)",
    Callback = function()
        print("=== REMOTE EVENTS (" .. #State.remotes.events .. ") ===")
        for _, r in ipairs(State.remotes.events) do print("  [Event] " .. r.path) end
        print("\n=== REMOTE FUNCTIONS (" .. #State.remotes.functions .. ") ===")
        for _, r in ipairs(State.remotes.functions) do print("  [Func] " .. r.path) end
        print("\n=== BINDABLE EVENTS (" .. #State.remotes.bindables .. ") ===")
        for _, r in ipairs(State.remotes.bindables) do print("  [Bindable] " .. r.path) end
        print("\n=== BINDABLE FUNCTIONS (" .. #State.remotes.bindableFuncs .. ") ===")
        for _, r in ipairs(State.remotes.bindableFuncs) do print("  [BindableFunc] " .. r.path) end
        safeNotify("Remotes", string.format("%d Events, %d Functions, %d Bindables, %d BindableFuncs. Check F9.",
            #State.remotes.events, #State.remotes.functions,
            #State.remotes.bindables, #State.remotes.bindableFuncs))
    end
})

TabResults:CreateButton({
    Name = "Print All Objects",
    Callback = function()
        print("=== OBJECTS ===")
        print(string.format("ProximityPrompts: %d", #State.objects.prompts))
        for _, p in ipairs(State.objects.prompts) do print(string.format("  [%s] %s (hold: %.1f, range: %d)", p.name, p.path, p.holdDuration, p.maxActivationDistance)) end
        print(string.format("\nClickDetectors: %d", #State.objects.clickDetectors))
        for _, c in ipairs(State.objects.clickDetectors) do print(string.format("  [%s] %s (range: %d)", c.name, c.path, c.maxActivationDistance)) end
        print(string.format("\nNPCs/Humanoids: %d", #State.objects.humanoids))
        for _, h in ipairs(State.objects.humanoids) do print(string.format("  [%s] %s | HP: %d/%d | Speed: %d | States: %s", h.name, h.path, h.health, h.maxHealth, h.walkSpeed, h.states)) end
        print(string.format("\nSpawnLocations: %d", #State.objects.spawns))
        for _, s in ipairs(State.objects.spawns) do print(string.format("  [%s] %s at %s", s.name, s.path, s.position)) end
        print(string.format("\nHighlights: %d", #State.objects.highlights))
        for _, h in ipairs(State.objects.highlights) do print(string.format("  [%s] %s (fill: %s)", h.name, h.path, h.fillColor)) end
        print(string.format("\nBillboardGuis: %d", #State.objects.billboards))
        for _, b in ipairs(State.objects.billboards) do print(string.format("  [%s] %s (size: %s, top: %s)", b.name, b.path, b.size, tostring(b.alwaysOnTop))) end
        print(string.format("\nSurfaceGuis: %d", #State.objects.surfaces))
        for _, s in ipairs(State.objects.surfaces) do print(string.format("  [%s] %s (face: %s)", s.name, s.path, s.face)) end
        print(string.format("\nValue Objects: %d", #State.objects.values))
        for _, v in ipairs(State.objects.values) do print(string.format("  [%s] %s = %s (%s)", v.name, v.path, v.value, v.class)) end
        print(string.format("\nConfigurations: %d", #State.objects.configurations))
        for _, c in ipairs(State.objects.configurations) do print(string.format("  [%s] %s: %s", c.name, c.path, c.children)) end
        safeNotify("Objects", "Printed to F9.")
    end
})

TabResults:CreateButton({
    Name = "Print All Assets",
    Callback = function()
        print("=== ASSETS ===")
        print(string.format("Sounds: %d", #State.assets.sounds))
        for _, s in ipairs(State.assets.sounds) do print(string.format("  [%s] %s id: %s vol: %.1f", s.name, s.path, s.soundId, s.volume)) end
        print(string.format("\nAnimations: %d", #State.assets.animations))
        for _, a in ipairs(State.assets.animations) do print(string.format("  [%s] %s id: %s", a.name, a.path, a.animationId)) end
        print(string.format("\nDecals: %d", #State.assets.decals))
        for _, d in ipairs(State.assets.decals) do print(string.format("  [%s] %s tex: %s", d.name, d.path, d.texture)) end
        print(string.format("\nMeshes: %d", #State.assets.meshes))
        for _, m in ipairs(State.assets.meshes) do print(string.format("  [%s] %s mesh: %s tex: %s", m.name, m.path, m.meshId, m.textureId)) end
        print(string.format("\nTextures: %d", #State.assets.textures))
        for _, t in ipairs(State.assets.textures) do print(string.format("  [%s] %s tex: %s", t.name, t.path, t.texture)) end
        safeNotify("Assets", "Printed to F9.")
    end
})

TabResults:CreateButton({
    Name = "Print Anti-Cheat & Backdoor Detections",
    Callback = function()
        print("=== ANTI-CHEAT DETECTIONS (" .. #State.antiCheatDetections .. ") ===")
        for _, d in ipairs(State.antiCheatDetections) do
            print(string.format("  [%s:%d] (%s) %s: %s", d.script, d.line, d.pattern, d.category, d.text))
        end
        print("\n=== BACKDOOR DETECTIONS (" .. #State.backdoorDetections .. ") ===")
        for _, d in ipairs(State.backdoorDetections) do
            print(string.format("  [%s:%d] (%s) %s: %s", d.script, d.line, d.pattern, d.category, d.text))
        end
        safeNotify("Security Scan", string.format("AC: %d | Backdoors: %d", #State.antiCheatDetections, #State.backdoorDetections))
    end
})

TabResults:CreateButton({
    Name = "Print Require() Dependency Map",
    Callback = function()
        print("=== REQUIRE DEPENDENCY MAP (" .. #State.requireMap .. ") ===")
        for _, r in ipairs(State.requireMap) do
            print(string.format("  [%s:%d] -> %s", r.script, r.line, r.target))
            print("    " .. r.text)
        end
        safeNotify("Require Map", string.format("%d require() calls. Check F9.", #State.requireMap))
    end
})

TabResults:CreateButton({
    Name = "Print Attributes & Tags",
    Callback = function()
        print("=== ATTRIBUTES (" .. #State.attributes .. ") ===")
        for _, a in ipairs(State.attributes) do
            print(string.format("  [%s] %s (%d attrs): %s", a.name, a.path, a.count, a.attributes))
        end
        print("\n=== COLLECTION SERVICE TAGS (" .. #State.tags .. ") ===")
        for _, t in ipairs(State.tags) do
            print(string.format("  Tag: %s (%d instances)", t.tag, t.count))
            for _, inst in ipairs(t.instances) do
                print(string.format("    - %s (%s) at %s", inst.name, inst.class, inst.path))
            end
        end
        safeNotify("Attrs & Tags", string.format("%d attrs, %d tags. Check F9.", #State.attributes, #State.tags))
    end
})

TabResults:CreateButton({
    Name = "Print Remote Profiles (from Deep Scan)",
    Callback = function()
        print("=== REMOTE PROFILES ===")
        for name, profile in pairs(State.deepData.remoteCallProfiles) do
            print(string.format("  %s (%s) — %d calls, path: %s", name, profile.method, profile.callCount, profile.path))
            print("    Arg type samples:")
            for i, types in ipairs(profile.argTypeHistory) do
                if i <= 10 then print("      [" .. i .. "] " .. types) end
            end
        end
        safeNotify("Remote Profiles", "Printed to F9.")
    end
})

TabResults:CreateButton({
    Name = "Print Executor Capabilities",
    Callback = function()
        print("=== EXECUTOR: " .. State.executorInfo .. " ===")
        print(string.format("Available: %d/%d\n", execTotalAvailable, execTotalChecked))
        local byCat = {}
        for _, cap in ipairs(State.executorCaps) do
            byCat[cap.category] = byCat[cap.category] or {}
            table.insert(byCat[cap.category], cap)
        end
        for cat, caps in pairs(byCat) do
            local avail = 0
            for _, c in ipairs(caps) do if c.available then avail = avail + 1 end end
            print(string.format("[%s] %d/%d available:", cat, avail, #caps))
            for _, c in ipairs(caps) do
                print(string.format("  %s — %s", c.available and "[Y]" or "[N]", c.name))
            end
            print("")
        end
        safeNotify("Executor", string.format("%s — %d/%d functions", State.executorInfo, execTotalAvailable, execTotalChecked))
    end
})

TabResults:CreateButton({
    Name = "Copy Remotes to Clipboard",
    Callback = function()
        if type(setclipboard) ~= "function" then return end
        local text = "=== REMOTES ===\n"
        text = text .. string.format("Events (%d):\n", #State.remotes.events)
        for _, r in ipairs(State.remotes.events) do text = text .. "  " .. r.path .. "\n" end
        text = text .. string.format("\nFunctions (%d):\n", #State.remotes.functions)
        for _, r in ipairs(State.remotes.functions) do text = text .. "  " .. r.path .. "\n" end
        text = text .. string.format("\nBindables (%d):\n", #State.remotes.bindables)
        for _, r in ipairs(State.remotes.bindables) do text = text .. "  " .. r.path .. "\n" end
        text = text .. string.format("\nBindableFuncs (%d):\n", #State.remotes.bindableFuncs)
        for _, r in ipairs(State.remotes.bindableFuncs) do text = text .. "  " .. r.path .. "\n" end
        pcall(setclipboard, text)
        safeNotify("Clipboard", "Remotes copied!")
    end
})

print("[K]vk: Universal Game Scanner v8.0 loaded for " .. GameName)
safeNotify("Scanner v8.0 Loaded", "Press Right Ctrl to toggle UI\nScan Game button to start everything")
