--!nocheck
-- Universal Game Scanner v8.1 - nil-safe compact build

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

local State = {
    scanning = false, deepScanning = false,
    results = {}, scriptHashes = {},
    stats = {total=0, success=0, failed=0, bytecode=0, client=0, server=0, module=0, deduped=0},
    lastFilename = "", maxDepth = 0,
    remotes = {events={}, functions={}, bindables={}, bindableFuncs={}, profiles={}},
    objects = {prompts={}, clickDetectors={}, humanoids={}, spawns={}, highlights={}, billboards={}, surfaces={}, values={}, configurations={}},
    assets = {sounds={}, animations={}, decals={}, meshes={}, textures={}},
    teams = {}, leaderstats = {}, guis = {}, executorCaps = {},
    executorInfo = "Unknown",
    keywordResults = {}, touchEvents = {},
    antiCheatDetections = {}, backdoorDetections = {}, requireMap = {},
    attributes = {}, tags = {},
    deepData = {
        promptInteractions={}, monsterSpawns={}, monsterMoves={},
        workspaceAdds={}, workspaceRemoves={}, remoteCalls={},
        remoteCallProfiles={}, playerPositions={},
        attributeChanges={}, humanoidStateChanges={}, startTime=0,
    },
    autoRunComplete = false, execCapsComplete = false,
    deepScanDuration = 300,
    originalNamecall = nil, namecallHooked = false,
}

local connections = {}
local ProgressGui, ProgressFill, ProgressLabel, ProgressPercent, ProgressDetail, ProgressTrack

local GameName = game.Name or "Unknown"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then GameName = info.Name end
end)
local safeName = tostring(GameName):gsub("[^%w%-_]", "_")

local function getParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

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
    if total and total > 0 then pct = math.floor((current / total) * 100) end
    if ProgressFill then ProgressFill.Size = UDim2.new(pct / 100, 0, 1, 0) end
    if ProgressPercent then ProgressPercent.Text = tostring(pct) .. "%" end
    if ProgressLabel then ProgressLabel.Text = tostring(label or "") end
    local d = tostring(detail or "")
    if #d > 55 then d = "..." .. string.sub(d, -52) end
    if ProgressDetail then ProgressDetail.Text = d end
end

local function safeNotify(title, content)
    pcall(function()
        if Rayfield and Rayfield.Notify then
            Rayfield:Notify({Title=tostring(title), Content=tostring(content), Duration=6})
        end
    end)
end

local function quickHash(str)
    if not str then return "nil" end
    local h = 5381
    for i = 1, #str do
        h = (h * 33) ~ string.byte(str, i)
        h = h % 0x100000000
    end
    return string.format("%08x", h)
end

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

local function getDescendantsIterative(container, maxDepth)
    local results = {}
    local stack = {{instance=container, depth=0}}
    while #stack > 0 do
        local node = table.remove(stack)
        if node and node.instance then
            local children = node.instance:GetChildren()
            for _, child in ipairs(children) do
                table.insert(results, child)
                if maxDepth <= 0 or node.depth + 1 < maxDepth then
                    table.insert(stack, {instance=child, depth=node.depth + 1})
                end
            end
        end
        if #results % 200 == 0 then RunService.RenderStepped:Wait() end
    end
    return results
end

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
    pcall(function() table.insert(list, {Lighting, "Lighting"}) end)
    return list
end

local categoryKeywords = {
    Combat={"combat","punch","attack","damage","weapon","gun","melee","fight","kill","health","sword","block","parry"},
    Movement={"movement","walkspeed","fly","noclip","jump","gravity","velocity","dash","sprint","shiftlock","camera","cframe","teleport"},
    UI={"gui","frame","button","ui","hud","menu","interface","screen","panel","label","textbox"},
    Economy={"shop","buy","currency","cash","coin","reward","spin","egg","pet","rebirth","upgrade","sell","trade","inventory"},
    NPC={"npc","monster","enemy","boss","ai","bot","creature","mob","spawn","wave","round"},
    Admin={"cmdr","command","admin","ban","kick","teleport","warn","mod","staff","permission"},
    Remote={"remote","fire","server","replicate","event","invoke","bindable"},
    DataStore={"datastore","save","load","profile","session","cache","reconcile"},
    Networking={"http","request","webhook","api","fetch","json","encode","decode"},
    Security={"anticheat","anti-cheat","anti_cheat","cheat","exploit","detect","flag","suspect","verify","integrity","checksum","tamper"},
    Animation={"animation","animate","track","playback","keyframe","rig","motor6d"},
    Audio={"sound","audio","music","sfx","volume","playlist"},
}

local function categorizeScript(path, className, source)
    local pL = tostring(path):lower()
    local sL = (source and tostring(source):lower()) or ""
    for category, keywords in pairs(categoryKeywords) do
        for _, kw in ipairs(keywords) do
            if pL:find(kw, 1, true) or (sL and sL:find(kw, 1, true)) then
                return category
            end
        end
    end
    if className == "LocalScript" then return "Client"
    elseif className == "Script" then return "Server"
    elseif className == "ModuleScript" then return "Module" end
    return "Other"
end

local function autoScanRemotes()
    State.remotes = {events={}, functions={}, bindables={}, bindableFuncs={}, profiles={}}
    local function scanContainer(container)
        pcall(function()
            for _, desc in ipairs(container:GetDescendants()) do
                if desc:IsA("RemoteEvent") then
                    table.insert(State.remotes.events, {path=desc:GetFullName(), name=desc.Name, parent=tostring(desc.Parent and desc.Parent.Name or "")})
                elseif desc:IsA("RemoteFunction") then
                    table.insert(State.remotes.functions, {path=desc:GetFullName(), name=desc.Name, parent=tostring(desc.Parent and desc.Parent.Name or "")})
                elseif desc:IsA("BindableEvent") then
                    table.insert(State.remotes.bindables, {path=desc:GetFullName(), name=desc.Name, parent=tostring(desc.Parent and desc.Parent.Name or "")})
                elseif desc:IsA("BindableFunction") then
                    table.insert(State.remotes.bindableFuncs, {path=desc:GetFullName(), name=desc.Name, parent=tostring(desc.Parent and desc.Parent.Name or "")})
                end
            end
        end)
    end
    scanContainer(ReplicatedStorage)
    scanContainer(Workspace)
    pcall(function() scanContainer(ServerScriptService) end)
    pcall(function() scanContainer(StarterGui) end)
    pcall(function() scanContainer(StarterPlayer) end)
    pcall(function() if LocalPlayer:FindFirstChild("PlayerGui") then scanContainer(LocalPlayer.PlayerGui) end end)
    pcall(function() if LocalPlayer:FindFirstChild("PlayerScripts") then scanContainer(LocalPlayer.PlayerScripts) end end)
    print(string.format("[Auto] Remotes: %d Events, %d Functions, %d Bindables, %d BindableFuncs",
        #State.remotes.events, #State.remotes.functions, #State.remotes.bindables, #State.remotes.bindableFuncs))
    return State.remotes
end

local function autoScanObjects()
    State.objects = {prompts={}, clickDetectors={}, humanoids={}, spawns={}, highlights={}, billboards={}, surfaces={}, values={}, configurations={}}
    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                table.insert(State.objects.prompts, {path=desc:GetFullName(), name=desc.Name, holdDuration=desc.HoldDuration, enabled=desc.Enabled, maxActivationDistance=desc.MaxActivationDistance, actionText=tostring(desc.ActionText or ""), objectText=tostring(desc.ObjectText or "")})
            elseif desc:IsA("ClickDetector") then
                table.insert(State.objects.clickDetectors, {path=desc:GetFullName(), name=desc.Name, maxActivationDistance=desc.MaxActivationDistance})
            elseif desc:IsA("SpawnLocation") then
                table.insert(State.objects.spawns, {path=desc:GetFullName(), name=desc.Name, position=tostring(desc.Position), duration=desc.Duration, neutral=desc.Neutral})
            elseif desc:IsA("Highlight") then
                table.insert(State.objects.highlights, {path=desc:GetFullName(), name=desc.Name, enabled=desc.Enabled, fillColor=tostring(desc.FillColor)})
            elseif desc:IsA("BillboardGui") then
                table.insert(State.objects.billboards, {path=desc:GetFullName(), name=desc.Name, enabled=desc.Enabled, size=tostring(desc.Size), alwaysOnTop=desc.AlwaysOnTop})
            elseif desc:IsA("SurfaceGui") then
                table.insert(State.objects.surfaces, {path=desc:GetFullName(), name=desc.Name, enabled=desc.Enabled, face=tostring(desc.Face)})
            elseif desc:IsA("Model") then
                local hum = desc:FindFirstChildOfClass("Humanoid")
                if hum and not Players:GetPlayerFromCharacter(desc) then
                    local root = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChild("RootPart") or desc.PrimaryPart
                    local childNames = {}
                    for _, c in ipairs(desc:GetChildren()) do table.insert(childNames, tostring(c.Name)) end
                    table.insert(State.objects.humanoids, {
                        path=desc:GetFullName(), name=desc.Name,
                        health=hum.Health, maxHealth=hum.MaxHealth,
                        walkSpeed=hum.WalkSpeed, jumpHeight=hum.JumpHeight,
                        position=root and tostring(root.Position) or "unknown",
                        hasAnimator=desc:FindFirstChildOfClass("Animator") ~= nil,
                        childCount=#desc:GetChildren(),
                        children=table.concat(childNames, ", "),
                        rigType=tostring(hum.RigType),
                        displayName=tostring(hum.DisplayName or ""),
                    })
                end
            end
            if desc:IsA("IntValue") or desc:IsA("NumberValue") or desc:IsA("StringValue") or desc:IsA("BoolValue") or desc:IsA("CFrameValue") or desc:IsA("Color3Value") or desc:IsA("Vector3Value") or desc:IsA("ObjectValue") or desc:IsA("BrickColorValue") then
                table.insert(State.objects.values, {path=desc:GetFullName(), name=desc.Name, class=desc.ClassName, value=tostring(desc.Value):sub(1, 100)})
            end
            if desc:IsA("Configuration") then
                local cv = {}
                for _, c in ipairs(desc:GetChildren()) do
                    if c:IsA("ValueBase") then table.insert(cv, tostring(c.Name) .. "=" .. tostring(c.Value):sub(1, 50)) end
                end
                table.insert(State.objects.configurations, {path=desc:GetFullName(), name=desc.Name, children=table.concat(cv, ", ")})
            end
        end
    end)
    print(string.format("[Auto] Objects: %d Prompts, %d Clicks, %d NPCs, %d Spawns, %d HL, %d BB, %d SG, %d Val, %d Cfg",
        #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns,
        #State.objects.highlights, #State.objects.billboards, #State.objects.surfaces, #State.objects.values, #State.objects.configurations))
    return State.objects
end

local function autoScanAssets()
    State.assets = {sounds={}, animations={}, decals={}, meshes={}, textures={}}
    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("Sound") then
                table.insert(State.assets.sounds, {path=desc:GetFullName(), name=desc.Name, soundId=tostring(desc.SoundId), volume=desc.Volume, looped=desc.Looped})
            elseif desc:IsA("Animation") then
                table.insert(State.assets.animations, {path=desc:GetFullName(), name=desc.Name, animationId=tostring(desc.AnimationId)})
            elseif desc:IsA("Decal") then
                table.insert(State.assets.decals, {path=desc:GetFullName(), name=desc.Name, texture=tostring(desc.Texture)})
            elseif desc:IsA("SpecialMesh") or desc:IsA("MeshPart") then
                table.insert(State.assets.meshes, {path=desc:GetFullName(), name=desc.Name, class=desc.ClassName, meshId=tostring(desc.MeshId or ""), textureId=tostring(desc.TextureID or "")})
            elseif desc:IsA("Texture") then
                table.insert(State.assets.textures, {path=desc:GetFullName(), name=desc.Name, texture=tostring(desc.Texture)})
            end
        end
    end)
    pcall(function()
        for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
            if desc:IsA("Sound") then
                table.insert(State.assets.sounds, {path=desc:GetFullName(), name=desc.Name, soundId=tostring(desc.SoundId), volume=desc.Volume, looped=desc.Looped})
            elseif desc:IsA("Animation") then
                table.insert(State.assets.animations, {path=desc:GetFullName(), name=desc.Name, animationId=tostring(desc.AnimationId)})
            end
        end
    end)
    print(string.format("[Auto] Assets: %d Sounds, %d Animations, %d Decals, %d Meshes, %d Textures",
        #State.assets.sounds, #State.assets.animations, #State.assets.decals, #State.assets.meshes, #State.assets.textures))
    return State.assets
end

local function autoScanAttributes()
    State.attributes = {}
    for _, cd in ipairs(getContainers()) do
        pcall(function()
            for _, desc in ipairs(cd[1]:GetDescendants()) do
                local attrs = desc:GetAttributes()
                local count = 0
                local strs = {}
                for name, value in pairs(attrs) do
                    count = count + 1
                    table.insert(strs, tostring(name) .. "=" .. tostring(value):sub(1, 50))
                end
                if count > 0 then
                    table.insert(State.attributes, {path=desc:GetFullName(), name=desc.Name, class=desc.ClassName, count=count, attributes=table.concat(strs, ", ")})
                end
            end
        end)
    end
    print(string.format("[Auto] Attributes: %d instances", #State.attributes))
    return State.attributes
end

local function autoScanTags()
    State.tags = {}
    local allTags = {}
    for _, cd in ipairs(getContainers()) do
        pcall(function()
            for _, desc in ipairs(cd[1]:GetDescendants()) do
                local tags = CollectionService:GetTags(desc)
                for _, tag in ipairs(tags) do
                    allTags[tag] = allTags[tag] or {}
                    table.insert(allTags[tag], {path=desc:GetFullName(), name=desc.Name, class=desc.ClassName})
                end
            end
        end)
    end
    for tag, instances in pairs(allTags) do
        table.insert(State.tags, {tag=tag, count=#instances, instances=instances})
    end
    table.sort(State.tags, function(a, b) return a.count > b.count end)
    print(string.format("[Auto] Tags: %d unique", #State.tags))
    return State.tags
end

local function autoScanTeamsStats()
    State.teams = {}
    State.leaderstats = {}
    pcall(function()
        for _, team in ipairs(Teams:GetChildren()) do
            if team:IsA("Team") then
                local pn = {}
                for _, p in ipairs(team:GetPlayers()) do table.insert(pn, p.Name) end
                table.insert(State.teams, {name=team.Name, color=tostring(team.TeamColor.Color), players=#team:GetPlayers(), autoAssignable=team.AutoAssignable, playerNames=table.concat(pn, ", ")})
            end
        end
    end)
    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            for _, stat in ipairs(ls:GetChildren()) do
                table.insert(State.leaderstats, {name=stat.Name, class=stat.ClassName, value=tostring(stat.Value)})
            end
        end
    end)
    print(string.format("[Auto] Teams: %d, Leaderstats: %d", #State.teams, #State.leaderstats))
    return {teams=State.teams, leaderstats=State.leaderstats}
end

local function autoScanGUIs()
    State.guis = {}
    local function scanC(container, cname)
        pcall(function()
            for _, desc in ipairs(container:GetDescendants()) do
                if desc:IsA("ScreenGui") then
                    local cc = 0
                    for _ in ipairs(desc:GetDescendants()) do cc = cc + 1 end
                    table.insert(State.guis, {path=desc:GetFullName(), name=desc.Name, container=cname, enabled=desc.Enabled, childCount=cc})
                end
            end
        end)
    end
    scanC(StarterGui, "StarterGui")
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then scanC(pg, "PlayerGui") end
    print(string.format("[Auto] GUIs: %d", #State.guis))
    return State.guis
end

local execFuncDefs = {
    {n="firetouchinterest",d="Fire touch",c="Interaction"},
    {n="fireproximityprompt",d="Fire prompts",c="Interaction"},
    {n="fireclickdetector",d="Fire clicks",c="Interaction"},
    {n="getrawmetatable",d="Raw metatable",c="Metatable"},
    {n="setreadonly",d="Set readonly",c="Metatable"},
    {n="getnamecallmethod",d="Namecall method",c="Metatable"},
    {n="newcclosure",d="Anti-tamper",c="Metatable"},
    {n="hookfunction",d="Hook functions",c="Metatable"},
    {n="hookmetamethod",d="Hook metamethods",c="Metatable"},
    {n="setclipboard",d="Clipboard",c="Utility"},
    {n="writefile",d="Write files",c="Utility"},
    {n="readfile",d="Read files",c="Utility"},
    {n="appendfile",d="Append files",c="Utility"},
    {n="makefolder",d="Make folder",c="Utility"},
    {n="isfolder",d="Is folder",c="Utility"},
    {n="listfiles",d="List files",c="Utility"},
    {n="delfile",d="Delete file",c="Utility"},
    {n="delfolder",d="Delete folder",c="Utility"},
    {n="decompile",d="Decompile",c="Decompiler"},
    {n="getsrc",d="Get source",c="Decompiler"},
    {n="getscriptbytecode",d="Bytecode",c="Decompiler"},
    {n="getscripthash",d="Script hash",c="Decompiler"},
    {n="getscripts",d="All scripts",c="Decompiler"},
    {n="getrunningscripts",d="Running scripts",c="Decompiler"},
    {n="gethui",d="CoreGui parent",c="Environment"},
    {n="getgenv",d="Global env",c="Environment"},
    {n="getreg",d="Registry",c="Environment"},
    {n="getrenv",d="Reg env",c="Environment"},
    {n="getidentity",d="Identity",c="Environment"},
    {n="getthreadidentity",d="Thread identity",c="Environment"},
    {n="syn_request",d="Synapse HTTP",c="Network"},
    {n="request",d="HTTP request",c="Network"},
    {n="http_get",d="HTTP GET",c="Network"},
    {n="http_post",d="HTTP POST",c="Network"},
    {n="websocket",d="WebSocket",c="Network"},
    {n="queue_on_teleport",d="Queue teleport",c="Network"},
    {n="loadstring",d="Load string",c="Execution"},
    {n="setsimulationradius",d="Sim radius",c="Execution"},
    {n="setfpscap",d="FPS cap",c="Execution"},
    {n="identifyexecutor",d="Identify exec",c="Execution"},
    {n="getcustomasset",d="Custom asset",c="Asset"},
    {n="saveinstance",d="Save instance",c="Asset"},
    {n="getinstances",d="All instances",c="Instance"},
    {n="getnilinstances",d="Nil instances",c="Instance"},
    {n="gethiddenproperty",d="Hidden prop",c="Instance"},
    {n="sethiddenproperty",d="Set hidden",c="Instance"},
    {n="isluau",d="Is Luau",c="Instance"},
    {n="base64encode",d="Base64 enc",c="Crypto"},
    {n="base64decode",d="Base64 dec",c="Crypto"},
    {n="mouse1click",d="Mouse click",c="Misc"},
    {n="keypress",d="Key press",c="Misc"},
    {n="keyrelease",d="Key release",c="Misc"},
}

local execTotalAvailable = 0
local execTotalChecked = 0

local function autoCheckExecutor()
    State.executorCaps = {}
    execTotalAvailable = 0
    execTotalChecked = 0
    State.executorInfo = "Unknown"
    pcall(function()
        if type(identifyexecutor) == "function" then
            local name, ver = identifyexecutor()
            if name then
                State.executorInfo = tostring(name) .. (ver and (" v" .. tostring(ver)) or "")
            end
        end
    end)
    for _, f in ipairs(execFuncDefs) do
        local avail = false
        pcall(function()
            local env = getfenv()
            if type(env[f.n]) == "function" then avail = true end
        end)
        if not avail then
            pcall(function()
                if type(_G[f.n]) == "function" then avail = true end
            end)
        end
        if not avail then
            pcall(function()
                if type(getgenv) == "function" then
                    local g = getgenv()
                    if type(g[f.n]) == "function" then avail = true end
                end
            end)
        end
        table.insert(State.executorCaps, {name=f.n, desc=f.d, category=f.c, available=avail})
        execTotalChecked = execTotalChecked + 1
        if avail then execTotalAvailable = execTotalAvailable + 1 end
    end
    State.execCapsComplete = true
    print(string.format("[Auto] Executor: %s - %d/%d", tostring(State.executorInfo), execTotalAvailable, execTotalChecked))
    return State.executorCaps
end

local function autoKeywordSearch()
    if #State.results == 0 then return {} end
    local keywords = {"FireServer","InvokeServer","WalkSpeed","Gravity","Health","Damage","Currency","Cash","Coin","Rebirth","Buy","Sell","Touched","ProximityPrompt","ClickDetector","Teleport","CFrame","Humanoid","Monster","NPC","Boss","RemoteEvent","RemoteFunction","getfenv","setfenv","loadstring","require","DataStore","HttpService","JSONEncode","exploit","cheat","backdoor","kick","ban","admin"}
    State.keywordResults = {}
    local total = 0
    for _, kw in ipairs(keywords) do
        local matches = {keyword=kw, count=0, matches={}}
        local sk = kw:lower()
        for _, r in ipairs(State.results) do
            if r.source and r.status == "OK" then
                local lines = r.source:split("\n")
                for lineNum, line in ipairs(lines) do
                    if line:lower():find(sk, 1, true) then
                        matches.count = matches.count + 1
                        if #matches.matches < 5 then
                            table.insert(matches.matches, {script=r.path, line=lineNum, text=line:gsub("^%s+", ""):sub(1, 120)})
                        end
                    end
                end
            end
        end
        if matches.count > 0 then
            table.insert(State.keywordResults, matches)
            total = total + matches.count
        end
    end
    print(string.format("[Auto] Keywords: %d matches, %d keywords", total, #State.keywordResults))
    return State.keywordResults
end

local acPatterns = {"anticheat","anti-cheat","anti_cheat","cheat","exploit","detect","flag","suspect","verify","integrity","checksum","tamper","velocity","fly","noclip","speedhack","walkspeed","jumppower","teleport","godmode","bypass","kick","crash","shutdown","monitor","track"}
local bdPatterns = {"loadstring","HttpGet","http_get","request(","game:HttpGet","pcall%(loadstring","loadstring%(game","require%(game","getfenv","setfenv","Backdoor","backdoor","admin%.","command%.","SourceCode","getsrc"}

local function autoScanACBackdoors()
    State.antiCheatDetections = {}
    State.backdoorDetections = {}
    for _, r in ipairs(State.results) do
        if r.source and r.status == "OK" then
            local sl = r.source:lower()
            local lines = r.source:split("\n")
            for _, pat in ipairs(acPatterns) do
                local pl = pat:lower()
                if sl:find(pl, 1, true) then
                    for ln, line in ipairs(lines) do
                        if line:lower():find(pl, 1, true) then
                            table.insert(State.antiCheatDetections, {script=r.path, line=ln, pattern=pat, text=line:gsub("^%s+",""):sub(1,150), category=tostring(r.category)})
                        end
                    end
                end
            end
            for _, pat in ipairs(bdPatterns) do
                local pl = pat:lower()
                if sl:find(pl, 1, true) then
                    for ln, line in ipairs(lines) do
                        if line:lower():find(pl, 1, true) then
                            table.insert(State.backdoorDetections, {script=r.path, line=ln, pattern=pat, text=line:gsub("^%s+",""):sub(1,150), category=tostring(r.category)})
                        end
                    end
                end
            end
        end
    end
    print(string.format("[Auto] AC: %d, Backdoors: %d", #State.antiCheatDetections, #State.backdoorDetections))
    return {ac=State.antiCheatDetections, bd=State.backdoorDetections}
end

local function autoScanRequireMap()
    State.requireMap = {}
    if #State.results == 0 then return {} end
    for _, r in ipairs(State.results) do
        if r.source and r.status == "OK" then
            local lines = r.source:split("\n")
            for ln, line in ipairs(lines) do
                if line:lower():find("require%(", 1, true) then
                    local arg = line:match("require%s*%(%s*(.-)%s*%)") or line:match("require%s+(.+)") or "unknown"
                    table.insert(State.requireMap, {script=r.path, line=ln, target=tostring(arg):sub(1,100), text=line:gsub("^%s+",""):sub(1,150), category=tostring(r.category)})
                end
            end
        end
    end
    print(string.format("[Auto] Require Map: %d calls", #State.requireMap))
    return State.requireMap
end

local function autoScanTouchEvents()
    State.touchEvents = {}
    for _, r in ipairs(State.results) do
        if r.source and r.status == "OK" then
            if r.source:lower():find("touched", 1, true) then
                local lines = r.source:split("\n")
                for ln, line in ipairs(lines) do
                    if line:lower():find("touched", 1, true) then
                        table.insert(State.touchEvents, {script=r.path, line=ln, text=line:gsub("^%s+",""):sub(1,150), category=tostring(r.category)})
                    end
                end
            end
        end
    end
    print(string.format("[Auto] Touch Events: %d", #State.touchEvents))
    return State.touchEvents
end

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
    duration = duration or 300
    if State.deepScanning then return end
    State.deepScanning = true
    State.deepData = {promptInteractions={}, monsterSpawns={}, monsterMoves={}, workspaceAdds={}, workspaceRemoves={}, remoteCalls={}, remoteCallProfiles={}, playerPositions={}, attributeChanges={}, humanoidStateChanges={}, startTime=tick()}
    safeNotify("Deep Scan", "Starting " .. tostring(duration) .. "s monitoring...")

    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                desc.Triggered:Connect(function(player)
                    if player == LocalPlayer then
                        table.insert(State.deepData.promptInteractions, {time=os.date("%H:%M:%S"), prompt=desc.Name, path=desc:GetFullName(), player=player.Name})
                    end
                end)
            end
        end
    end)

    connections.deepWS = Workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("Model") and desc:FindFirstChildOfClass("Humanoid") then
            local hum = desc:FindFirstChildOfClass("Humanoid")
            local root = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChild("RootPart")
            local cn = {}
            for _, c in ipairs(desc:GetChildren()) do table.insert(cn, tostring(c.Name)) end
            table.insert(State.deepData.monsterSpawns, {time=os.date("%H:%M:%S"), name=desc.Name, path=desc:GetFullName(), health=hum and hum.Health or 0, maxHealth=hum and hum.MaxHealth or 0, walkSpeed=hum and hum.WalkSpeed or 0, position=root and tostring(root.Position) or "unknown", children=table.concat(cn, ", ")})
        else
            table.insert(State.deepData.workspaceAdds, {time=os.date("%H:%M:%S"), name=desc.Name, class=desc.ClassName, path=desc:GetFullName()})
        end
    end)

    connections.deepWSR = Workspace.DescendantRemoving:Connect(function(desc)
        if not Players:GetPlayerFromCharacter(desc) then
            table.insert(State.deepData.workspaceRemoves, {time=os.date("%H:%M:%S"), name=desc.Name, class=desc.ClassName, path=desc:GetFullName()})
            if #State.deepData.workspaceRemoves > 500 then table.remove(State.deepData.workspaceRemoves, 1) end
        end
    end)

    local lastMove = 0
    connections.deepMM = RunService.Heartbeat:Connect(function()
        if not State.deepScanning then return end
        if tick() - lastMove < 5 then return end
        lastMove = tick()
        local mf = Workspace:FindFirstChild("Monsters") or Workspace:FindFirstChild("Enemies") or Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("Mobs")
        if mf then
            for _, m in ipairs(mf:GetChildren()) do
                local root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("RootPart")
                if root then
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    table.insert(State.deepData.monsterMoves, {time=os.date("%H:%M:%S"), name=m.Name, position=tostring(root.Position), velocity=tostring(root.AssemblyLinearVelocity), walkSpeed=hum and hum.WalkSpeed or 0, health=hum and hum.Health or 0})
                    if #State.deepData.monsterMoves > 500 then table.remove(State.deepData.monsterMoves, 1) end
                end
            end
        end
    end)

    local lastPP = 0
    connections.deepPP = RunService.Heartbeat:Connect(function()
        if not State.deepScanning then return end
        if tick() - lastPP < 10 then return end
        lastPP = tick()
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    if not State.deepData.playerPositions[p.Name] then State.deepData.playerPositions[p.Name] = {} end
                    table.insert(State.deepData.playerPositions[p.Name], {time=os.date("%H:%M:%S"), position=tostring(root.Position), velocity=tostring(root.AssemblyLinearVelocity.Magnitude)})
                    if #State.deepData.playerPositions[p.Name] > 50 then table.remove(State.deepData.playerPositions[p.Name], 1) end
                end
            end
        end
    end)

    pcall(function()
        local mt = getrawmetatable(game)
        if mt then
            setreadonly(mt, false)
            if not State.originalNamecall then State.originalNamecall = mt.__namecall end
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" or method == "InvokeServer" then
                    local args = {...}
                    local argTypes = {}
                    local argStr = ""
                    for i, arg in ipairs(args) do
                        local ti = type(arg)
                        if typeof(arg) == "Instance" then ti = arg.ClassName end
                        table.insert(argTypes, tostring(ti))
                        if i > 1 then argStr = argStr .. ", " end
                        if type(arg) == "string" then argStr = argStr .. '"' .. tostring(arg:sub(1, 50)) .. '"'
                        elseif type(arg) == "number" then argStr = argStr .. tostring(arg)
                        elseif type(arg) == "boolean" then argStr = argStr .. tostring(arg)
                        elseif typeof(arg) == "Instance" then argStr = argStr .. tostring(arg.ClassName)
                        else argStr = argStr .. tostring(type(arg)) end
                    end
                    table.insert(State.deepData.remoteCalls, {time=os.date("%H:%M:%S"), remote=self:GetFullName(), remoteName=tostring(self.Name), method=tostring(method), args=argStr, argTypes=table.concat(argTypes, ", ")})
                    if #State.deepData.remoteCalls > 1000 then table.remove(State.deepData.remoteCalls, 1) end
                    local rk = tostring(self.Name)
                    if not State.deepData.remoteCallProfiles[rk] then
                        State.deepData.remoteCallProfiles[rk] = {name=tostring(self.Name), path=self:GetFullName(), method=tostring(method), callCount=0, argTypeHistory={}}
                    end
                    local prof = State.deepData.remoteCallProfiles[rk]
                    prof.callCount = prof.callCount + 1
                    table.insert(prof.argTypeHistory, table.concat(argTypes, ", "))
                    if #prof.argTypeHistory > 20 then table.remove(prof.argTypeHistory, 1) end
                end
                return State.originalNamecall(self, ...)
            end)
            setreadonly(mt, true)
            State.namecallHooked = true
        end
    end)

    task.spawn(function()
        task.wait(duration)
        State.deepScanning = false
        if connections.deepWS then connections.deepWS:Disconnect() connections.deepWS = nil end
        if connections.deepWSR then connections.deepWSR:Disconnect() connections.deepWSR = nil end
        if connections.deepMM then connections.deepMM:Disconnect() connections.deepMM = nil end
        if connections.deepPP then connections.deepPP:Disconnect() connections.deepPP = nil end
        restoreNamecallHook()
        if type(writefile) == "function" then
            local fn = "deepscan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
            local c = "Deep Scan v8.1 - " .. tostring(GameName) .. "\n"
            c = c .. string.format("Duration: %ss\n\n", tostring(duration))
            c = c .. string.format("PROMPTS (%d):\n", #State.deepData.promptInteractions)
            for _, p in ipairs(State.deepData.promptInteractions) do c = c .. string.format("  [%s] %s at %s\n", tostring(p.time), tostring(p.prompt), tostring(p.path)) end
            c = c .. string.format("\nSPAWNS (%d):\n", #State.deepData.monsterSpawns)
            for _, m in ipairs(State.deepData.monsterSpawns) do c = c .. string.format("  [%s] %s HP:%d/%d Spd:%d\n", tostring(m.time), tostring(m.name), m.health or 0, m.maxHealth or 0, m.walkSpeed or 0) end
            c = c .. string.format("\nREMOTE CALLS (%d):\n", #State.deepData.remoteCalls)
            for _, r in ipairs(State.deepData.remoteCalls) do c = c .. string.format("  [%s] %s (%s) args:%s types:%s\n", tostring(r.time), tostring(r.remoteName), tostring(r.method), tostring(r.args), tostring(r.argTypes)) end
            c = c .. string.format("\nADDS (%d):\n", #State.deepData.workspaceAdds)
            for _, w in ipairs(State.deepData.workspaceAdds) do c = c .. string.format("  [%s] %s (%s)\n", tostring(w.time), tostring(w.name), tostring(w.class)) end
            c = c .. string.format("\nREMOVES (%d):\n", #State.deepData.workspaceRemoves)
            for _, w in ipairs(State.deepData.workspaceRemoves) do c = c .. string.format("  [%s] %s (%s)\n", tostring(w.time), tostring(w.name), tostring(w.class)) end
            c = c .. "\nREMOTE PROFILES:\n"
            for name, prof in pairs(State.deepData.remoteCallProfiles) do
                c = c .. string.format("  %s (%s) - %d calls\n", tostring(name), tostring(prof.method), prof.callCount or 0)
                for i, t in ipairs(prof.argTypeHistory) do if i <= 5 then c = c .. "    [" .. tostring(i) .. "] " .. tostring(t) .. "\n" end end
            end
            pcall(writefile, fn, c)
            print("[Deep] Saved: " .. fn)
            safeNotify("Deep Scan Done", "Saved: " .. fn)
        else
            safeNotify("Deep Scan Done", "In memory only")
        end
    end)
end

local function autoSaveDump(useJSON)
    if #State.results == 0 then return nil end
    if type(writefile) ~= "function" then return nil end
    local fn = "scan_" .. safeName .. "_" .. os.date("%Y%m%d_%H%M%S") .. (useJSON and ".json" or ".txt")
    if useJSON and HttpService then
        local export = {version="8.1", game=tostring(GameName), placeId=tostring(game.PlaceId), date=os.date("%Y-%m-%d %H:%M:%S"), executor=tostring(State.executorInfo), scripts={}}
        for i, r in ipairs(State.results) do
            export.scripts[i] = {index=i, path=tostring(r.path), class=tostring(r.class), status=tostring(r.status), container=tostring(r.container), category=tostring(r.category), source=r.source}
        end
        pcall(writefile, fn, HttpService:JSONEncode(export))
    else
        local c = "Scanner v8.1 Dump\nGame: " .. tostring(GameName) .. "\nPlaceID: " .. tostring(game.PlaceId) .. "\nDate: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\nExec: " .. tostring(State.executorInfo) .. "\n"
        c = c .. string.format("Total:%d OK:%d Fail:%d Dup:%d\n\n", State.stats.total, State.stats.success, State.stats.failed, State.stats.deduped)
        c = c .. "SCRIPT INDEX:\n"
        for i, r in ipairs(State.results) do
            c = c .. string.format("[%d] %s|%s|%s|%s|%s\n", i, tostring(r.container), tostring(r.class), tostring(r.status), tostring(r.category or "Other"), tostring(r.path))
        end
        c = c .. "\n"
        for i, r in ipairs(State.results) do
            c = c .. string.format("\n=== [%d] ===\nPath: %s\nClass: %s\nStatus: %s\n", i, tostring(r.path), tostring(r.class), tostring(r.status))
            if r.source then c = c .. r.source .. "\n" else c = c .. "-- NO SOURCE\n" end
        end
        pcall(writefile, fn, c)
    end
    State.lastFilename = fn
    print("[Scan] Saved: " .. fn)
    return fn
end

local function performScan()
    if State.scanning then return end
    State.scanning = true
    State.results = {}
    State.scriptHashes = {}
    State.stats = {total=0, success=0, failed=0, bytecode=0, client=0, server=0, module=0, deduped=0}
    if not ProgressGui or not ProgressGui.Parent then buildProgressGUI() end
    ProgressGui.Enabled = true
    updateProgress(0, 1, "Counting", "scripts...")
    local containers = getContainers()
    local total = 0
    for _, cd in ipairs(containers) do
        if cd[1] then
            local d = State.maxDepth > 0 and getDescendantsIterative(cd[1], State.maxDepth) or cd[1]:GetDescendants()
            for _, child in ipairs(d) do
                if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then total = total + 1 end
            end
            RunService.RenderStepped:Wait()
        end
    end
    State.stats.total = total
    local current = 0
    for _, cd in ipairs(containers) do
        if cd[1] then
            local d = State.maxDepth > 0 and getDescendantsIterative(cd[1], State.maxDepth) or cd[1]:GetDescendants()
            for _, child in ipairs(d) do
                if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    current = current + 1
                    local path = child:GetFullName()
                    local cn = child.ClassName
                    updateProgress(current, total, tostring(cd[2]), path)
                    local src, status = getScriptSource(child)
                    local hash = quickHash(src or path)
                    if State.scriptHashes[hash] then
                        State.stats.deduped = State.stats.deduped + 1
                    else
                        State.scriptHashes[hash] = true
                        if status == "OK" then State.stats.success = State.stats.success + 1
                        elseif status == "BYTECODE" then State.stats.bytecode = State.stats.bytecode + 1
                        else State.stats.failed = State.stats.failed + 1 end
                        if cn == "LocalScript" then State.stats.client = State.stats.client + 1
                        elseif cn == "Script" then State.stats.server = State.stats.server + 1
                        elseif cn == "ModuleScript" then State.stats.module = State.stats.module + 1 end
                        local cat = categorizeScript(path, cn, src)
                        table.insert(State.results, {path=path, class=cn, status=status, source=src, container=tostring(cd[2]), category=cat, instance=child, hash=hash})
                    end
                    if current % 10 == 0 then task.wait(0.01) end
                end
            end
        end
    end
    updateProgress(total, total, "Saving", "...")
    task.wait(0.3)
    local saved = autoSaveDump(false)
    ProgressGui.Enabled = false
    State.scanning = false
    -- Auto-run sub-scans
    if not State.autoRunComplete then
        safeNotify("Auto-Scan", "Running sub-scanners...")
        local steps = 11
        updateProgress(0, steps, "Auto", "Remotes...")
        autoScanRemotes()
        task.wait(0.2)
        updateProgress(1, steps, "Auto", "Objects...")
        autoScanObjects()
        task.wait(0.2)
        updateProgress(2, steps, "Auto", "Teams...")
        autoScanTeamsStats()
        task.wait(0.2)
        updateProgress(3, steps, "Auto", "GUIs...")
        autoScanGUIs()
        task.wait(0.2)
        updateProgress(4, steps, "Auto", "Assets...")
        autoScanAssets()
        task.wait(0.2)
        updateProgress(5, steps, "Auto", "Attributes...")
        autoScanAttributes()
        task.wait(0.2)
        updateProgress(6, steps, "Auto", "Tags...")
        autoScanTags()
        task.wait(0.2)
        updateProgress(7, steps, "Auto", "Executor...")
        autoCheckExecutor()
        task.wait(0.2)
        updateProgress(8, steps, "Auto", "Keywords...")
        autoKeywordSearch()
        task.wait(0.2)
        updateProgress(9, steps, "Auto", "Touch...")
        autoScanTouchEvents()
        task.wait(0.2)
        updateProgress(10, steps, "Auto", "AC/Backdoors...")
        autoScanACBackdoors()
        autoScanRequireMap()
        task.wait(0.2)
        updateProgress(11, steps, "Auto", "Done!")
        State.autoRunComplete = true
    end
    if saved then
        safeNotify("Scan Complete", string.format("%d scripts | OK:%d | Fail:%d | Dup:%d | Exec:%s", State.stats.total, State.stats.success, State.stats.failed, State.stats.deduped, tostring(State.executorInfo)))
    else
        safeNotify("Scan Complete", string.format("%d scripts | OK:%d | Fail:%d (no writefile)", State.stats.total, State.stats.success, State.stats.failed))
    end
end

-- ============================================
-- LOAD RAYFIELD
-- ============================================
local Rayfield
local RayfieldLoaded = false

if type(loadstring) == "function" then
    pcall(function()
        Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()
        if Rayfield then RayfieldLoaded = true end
    end)
end
if not RayfieldLoaded and type(loadstring) == "function" then
    pcall(function()
        Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
        if Rayfield then RayfieldLoaded = true end
    end)
end

-- ============================================
-- BUILD UI
-- ============================================
if RayfieldLoaded and Rayfield then
    local Window = Rayfield:CreateWindow({
        Name = "Scanner v8.1 - " .. tostring(GameName),
        LoadingTitle = "Scanning " .. tostring(GameName),
        LoadingSubtitle = "v8.1 nil-safe",
        ConfigurationSaving = {Enabled = false},
        Discord = {Enabled = false},
        KeySettings = {Key = Enum.KeyCode.RightControl, OnPress = function() end}
    })

    local T1 = Window:CreateTab("Scanner")
    T1:CreateButton({Name = "Scan Game + Auto-Analyze", Callback = function() performScan() end})
    T1:CreateSlider({Name = "Max Depth (0=All)", Range = {0,10}, Increment = 1, Suffix = "lv", CurrentValue = 0, Flag = "MaxDepth", Callback = function(v) State.maxDepth = v end})
    T1:CreateButton({Name = "Re-run Sub-Scans", Callback = function()
        if #State.results == 0 then safeNotify("Error", "Run a scan first") return end
        State.autoRunComplete = false
        -- Run all sub-scans inline
        autoScanRemotes()
        task.wait(0.1)
        autoScanObjects()
        task.wait(0.1)
        autoScanTeamsStats()
        task.wait(0.1)
        autoScanGUIs()
        task.wait(0.1)
        autoScanAssets()
        task.wait(0.1)
        autoScanAttributes()
        task.wait(0.1)
        autoScanTags()
        task.wait(0.1)
        autoCheckExecutor()
        task.wait(0.1)
        autoKeywordSearch()
        task.wait(0.1)
        autoScanTouchEvents()
        task.wait(0.1)
        autoScanACBackdoors()
        autoScanRequireMap()
        State.autoRunComplete = true
        safeNotify("Done", "Sub-scans complete")
    end})
    T1:CreateButton({Name = "Export JSON", Callback = function()
        local f = autoSaveDump(true)
        if f then safeNotify("Export", "Saved: " .. f) else safeNotify("Export", "Need writefile + scan first") end
    end})
    T1:CreateButton({Name = "Clear All", Callback = function()
        State.results = {}
        State.scriptHashes = {}
        State.stats = {total=0,success=0,failed=0,bytecode=0,client=0,server=0,module=0,deduped=0}
        State.remotes = {events={},functions={},bindables={},bindableFuncs={},profiles={}}
        State.objects = {prompts={},clickDetectors={},humanoids={},spawns={},highlights={},billboards={},surfaces={},values={},configurations={}}
        State.assets = {sounds={},animations={},decals={},meshes={},textures={}}
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
        safeNotify("Cleared", "All results reset")
    end})
    T1:CreateButton({Name = "Full Stats", Callback = function()
        local t = string.format("Scripts:%d OK:%d Fail:%d Dup:%d\nRemotes:%dE %dF %dB %dBF\nObjects:%dP %dC %dNPC %dS\nAssets:%dS %dA %dD %dM\nAC:%d BD:%d Req:%d Attr:%d Tag:%d\nExec:%s %d/%d",
            State.stats.total, State.stats.success, State.stats.failed, State.stats.deduped,
            #State.remotes.events, #State.remotes.functions, #State.remotes.bindables, #State.remotes.bindableFuncs,
            #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns,
            #State.assets.sounds, #State.assets.animations, #State.assets.decals, #State.assets.meshes,
            #State.antiCheatDetections, #State.backdoorDetections, #State.requireMap, #State.attributes, #State.tags,
            tostring(State.executorInfo), execTotalAvailable, execTotalChecked)
        safeNotify("Stats", t)
        print(t)
    end})

    local T2 = Window:CreateTab("Deep Scan")
    T2:CreateButton({Name = "5-Min Deep Scan", Callback = function() startDeepScan(300) end})
    T2:CreateButton({Name = "1-Min Quick Deep", Callback = function() startDeepScan(60) end})
    T2:CreateButton({Name = "Stop Deep Scan", Callback = function()
        State.deepScanning = false
        if connections.deepWS then connections.deepWS:Disconnect() connections.deepWS = nil end
        if connections.deepWSR then connections.deepWSR:Disconnect() connections.deepWSR = nil end
        if connections.deepMM then connections.deepMM:Disconnect() connections.deepMM = nil end
        if connections.deepPP then connections.deepPP:Disconnect() connections.deepPP = nil end
        restoreNamecallHook()
        safeNotify("Stopped", "Deep scan stopped, hook restored")
    end})
    T2:CreateButton({Name = "Print Deep Data", Callback = function()
        for _, p in ipairs(State.deepData.promptInteractions) do print("[P]" .. tostring(p.time) .. " " .. tostring(p.prompt)) end
        for _, m in ipairs(State.deepData.monsterSpawns) do print("[S]" .. tostring(m.time) .. " " .. tostring(m.name) .. " HP:" .. tostring(m.health)) end
        for _, r in ipairs(State.deepData.remoteCalls) do print("[R]" .. tostring(r.time) .. " " .. tostring(r.remoteName) .. " (" .. tostring(r.method) .. ") " .. tostring(r.args)) end
        safeNotify("Deep Data", "Printed to F9")
    end})
    T2:CreateButton({Name = "Copy Deep Data", Callback = function()
        if type(setclipboard) ~= "function" then safeNotify("Error", "No setclipboard") return end
        local t = ""
        for _, r in ipairs(State.deepData.remoteCalls) do t = t .. tostring(r.remoteName) .. " (" .. tostring(r.method) .. ") args:" .. tostring(r.args) .. " types:" .. tostring(r.argTypes) .. "\n" end
        pcall(setclipboard, t)
        safeNotify("Copied", "Deep data to clipboard")
    end})
    T2:CreateSlider({Name = "Custom Duration", Range = {30,600}, Increment = 30, Suffix = "s", CurrentValue = 300, Flag = "DSDur", Callback = function(v) State.deepScanDuration = v end})
    T2:CreateButton({Name = "Start Custom Deep", Callback = function() startDeepScan(State.deepScanDuration or 300) end})

    local T3 = Window:CreateTab("Results")
    T3:CreateButton({Name = "Print Remotes", Callback = function()
        for _, r in ipairs(State.remotes.events) do print("[E] " .. tostring(r.path)) end
        for _, r in ipairs(State.remotes.functions) do print("[F] " .. tostring(r.path)) end
        for _, r in ipairs(State.remotes.bindables) do print("[B] " .. tostring(r.path)) end
        for _, r in ipairs(State.remotes.bindableFuncs) do print("[BF] " .. tostring(r.path)) end
        safeNotify("Remotes", string.format("%dE %dF %dB %dBF - F9", #State.remotes.events, #State.remotes.functions, #State.remotes.bindables, #State.remotes.bindableFuncs))
    end})
    T3:CreateButton({Name = "Print Objects", Callback = function()
        for _, p in ipairs(State.objects.prompts) do print("[PP] " .. tostring(p.path) .. " hold:" .. tostring(p.holdDuration)) end
        for _, c in ipairs(State.objects.clickDetectors) do print("[CD] " .. tostring(c.path)) end
        for _, h in ipairs(State.objects.humanoids) do print("[NPC] " .. tostring(h.path) .. " HP:" .. tostring(h.health) .. "/" .. tostring(h.maxHealth) .. " Spd:" .. tostring(h.walkSpeed)) end
        for _, v in ipairs(State.objects.values) do print("[VAL] " .. tostring(v.path) .. " = " .. tostring(v.value)) end
        safeNotify("Objects", "Printed to F9")
    end})
    T3:CreateButton({Name = "Print Assets", Callback = function()
        for _, s in ipairs(State.assets.sounds) do print("[SND] " .. tostring(s.path) .. " id:" .. tostring(s.soundId)) end
        for _, a in ipairs(State.assets.animations) do print("[ANIM] " .. tostring(a.path) .. " id:" .. tostring(a.animationId)) end
        safeNotify("Assets", "Printed to F9")
    end})
    T3:CreateButton({Name = "Print AC + Backdoors", Callback = function()
        for _, d in ipairs(State.antiCheatDetections) do print("[AC] " .. tostring(d.script) .. ":" .. tostring(d.line) .. " (" .. tostring(d.pattern) .. ") " .. tostring(d.text)) end
        for _, d in ipairs(State.backdoorDetections) do print("[BD] " .. tostring(d.script) .. ":" .. tostring(d.line) .. " (" .. tostring(d.pattern) .. ") " .. tostring(d.text)) end
        safeNotify("Security", string.format("AC:%d BD:%d", #State.antiCheatDetections, #State.backdoorDetections))
    end})
    T3:CreateButton({Name = "Print Require Map", Callback = function()
        for _, r in ipairs(State.requireMap) do print("[REQ] " .. tostring(r.script) .. ":" .. tostring(r.line) .. " -> " .. tostring(r.target)) end
        safeNotify("Require", string.format("%d calls - F9", #State.requireMap))
    end})
    T3:CreateButton({Name = "Print Attrs + Tags", Callback = function()
        for _, a in ipairs(State.attributes) do print("[ATTR] " .. tostring(a.path) .. " (" .. tostring(a.count) .. ") " .. tostring(a.attributes)) end
        for _, t in ipairs(State.tags) do print("[TAG] " .. tostring(t.tag) .. " (" .. tostring(t.count) .. ")") end
        safeNotify("Attrs/Tags", string.format("%d attrs, %d tags - F9", #State.attributes, #State.tags))
    end})
    T3:CreateButton({Name = "Print Exec Caps", Callback = function()
        print("Executor: " .. tostring(State.executorInfo))
        for _, c in ipairs(State.executorCaps) do print(string.format("  %s %s - %s", c.available and "[Y]" or "[N]", tostring(c.name), tostring(c.desc))) end
        safeNotify("Exec", string.format("%s - %d/%d", tostring(State.executorInfo), execTotalAvailable, execTotalChecked))
    end})
    T3:CreateButton({Name = "Copy Remotes", Callback = function()
        if type(setclipboard) ~= "function" then return end
        local t = ""
        for _, r in ipairs(State.remotes.events) do t = t .. tostring(r.path) .. "\n" end
        for _, r in ipairs(State.remotes.functions) do t = t .. tostring(r.path) .. "\n" end
        pcall(setclipboard, t)
        safeNotify("Copied", "Remotes to clipboard")
    end})

    print("[K]vk: Scanner v8.1 loaded with Rayfield - " .. tostring(GameName))
    safeNotify("v8.1 Loaded", "Right Ctrl to toggle\nPress Scan Game to start")

else
    -- Emergency fallback GUI (no Rayfield)
    warn("[K]vk: Rayfield failed. Building emergency GUI...")
    local eg = Instance.new("ScreenGui")
    eg.Name = "ScannerEmergency"
    eg.ResetOnSpawn = false
    eg.IgnoreGuiInset = true
    eg.Enabled = true
    eg.Parent = getParent()

    local mf = Instance.new("Frame")
    mf.Size = UDim2.new(0, 380, 0, 450)
    mf.Position = UDim2.new(0.5, -190, 0.5, -225)
    mf.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mf.BorderSizePixel = 0
    mf.Active = true
    mf.Draggable = true
    mf.Parent = eg
    Instance.new("UICorner", mf).CornerRadius = UDim.new(0, 8)

    local st = Instance.new("UIStroke")
    st.Color = Color3.fromRGB(255, 100, 100)
    st.Thickness = 2
    st.Parent = mf

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, 0, 0, 30)
    tl.BackgroundTransparency = 0.3
    tl.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    tl.Text = "Scanner v8.1 - Emergency Mode"
    tl.TextColor3 = Color3.fromRGB(255, 100, 100)
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 12
    tl.Parent = mf
    Instance.new("UICorner", tl).CornerRadius = UDim.new(0, 8)

    local bc = Instance.new("Frame")
    bc.Size = UDim2.new(1, -20, 1, -40)
    bc.Position = UDim2.new(0, 10, 0, 35)
    bc.BackgroundTransparency = 1
    bc.Parent = mf

    Instance.new("UIListLayout", bc).Padding = UDim.new(0, 5)

    local function mkBtn(txt, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 30)
        b.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        b.Text = txt
        b.TextColor3 = Color3.fromRGB(235, 235, 240)
        b.Font = Enum.Font.Gotham
        b.TextSize = 11
        b.Parent = bc
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    mkBtn("Scan Game + Auto-Analyze", function() performScan() end)
    mkBtn("Re-run Sub-Scans", function()
        if #State.results == 0 then return end
        autoScanRemotes()
        autoScanObjects()
        autoScanTeamsStats()
        autoScanGUIs()
        autoScanAssets()
        autoScanAttributes()
        autoScanTags()
        autoCheckExecutor()
        autoKeywordSearch()
        autoScanTouchEvents()
        autoScanACBackdoors()
        autoScanRequireMap()
        print("[K]vk: Sub-scans done")
    end)
    mkBtn("1-Min Deep Scan", function() startDeepScan(60) end)
    mkBtn("5-Min Deep Scan", function() startDeepScan(300) end)
    mkBtn("Stop Deep Scan", function()
        State.deepScanning = false
        if connections.deepWS then connections.deepWS:Disconnect() end
        if connections.deepWSR then connections.deepWSR:Disconnect() end
        if connections.deepMM then connections.deepMM:Disconnect() end
        if connections.deepPP then connections.deepPP:Disconnect() end
        restoreNamecallHook()
    end)
    mkBtn("Export JSON", function()
        local f = autoSaveDump(true)
        if f then print("Saved: " .. f) end
    end)
    mkBtn("Print Remotes", function()
        for _, r in ipairs(State.remotes.events) do print("[E] " .. tostring(r.path)) end
        for _, r in ipairs(State.remotes.functions) do print("[F] " .. tostring(r.path)) end
    end)
    mkBtn("Print AC + Backdoors", function()
        for _, d in ipairs(State.antiCheatDetections) do print("[AC] " .. tostring(d.script) .. ":" .. tostring(d.line) .. " " .. tostring(d.text)) end
        for _, d in ipairs(State.backdoorDetections) do print("[BD] " .. tostring(d.script) .. ":" .. tostring(d.line) .. " " .. tostring(d.text)) end
    end)
    mkBtn("Print Stats", function()
        print(string.format("Scripts:%d OK:%d Fail:%d Dup:%d", State.stats.total, State.stats.success, State.stats.failed, State.stats.deduped))
        print(string.format("Remotes:%dE %dF | AC:%d BD:%d | Exec:%s %d/%d",
            #State.remotes.events, #State.remotes.functions, #State.antiCheatDetections, #State.backdoorDetections,
            tostring(State.executorInfo), execTotalAvailable, execTotalChecked))
    end)
    mkBtn("Clear All", function()
        State.results = {}
        State.scriptHashes = {}
        State.stats = {total=0,success=0,failed=0,bytecode=0,client=0,server=0,module=0,deduped=0}
        State.remotes = {events={},functions={},bindables={},bindableFuncs={},profiles={}}
        State.objects = {prompts={},clickDetectors={},humanoids={},spawns={},highlights={},billboards={},surfaces={},values={},configurations={}}
        State.assets = {sounds={},animations={},decals={},meshes={},textures={}}
        State.antiCheatDetections = {}
        State.backdoorDetections = {}
        State.requireMap = {}
        State.attributes = {}
        State.tags = {}
        State.autoRunComplete = false
        print("[K]vk: Cleared")
    end)

    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.RightControl then eg.Enabled = not eg.Enabled end
    end)

    print("[K]vk: Emergency GUI built for " .. tostring(GameName))
end
