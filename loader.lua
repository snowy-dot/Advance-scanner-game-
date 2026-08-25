-- ============================================
-- RAYFIELD (v8.0 fix — multi-URL fallback + emergency GUI)
-- ============================================
local RayfieldLoaded = false

-- Try multiple Rayfield URLs
local rayfieldURLs = {
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/master/source.lua",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/rayfield/main/source.lua",
}

if type(loadstring) == "function" then
    for _, url in ipairs(rayfieldURLs) do
        if not RayfieldLoaded then
            pcall(function()
                local source = game:HttpGet(url)
                if source and #source > 100 then
                    local fn = loadstring(source)
                    if fn then
                        Rayfield = fn()
                        if Rayfield then
                            RayfieldLoaded = true
                            print("[K]vk: Rayfield loaded from " .. url)
                        end
                    end
                end
            end)
        end
    end
end

-- If Rayfield still failed, try direct game:LoadString on the sirius domain
if not RayfieldLoaded then
    pcall(function()
        Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
        if Rayfield then RayfieldLoaded = true end
    end)
end

-- ============================================
-- EMERGENCY FALLBACK GUI (if Rayfield completely fails)
-- ============================================
local EmergencyGui
local function buildEmergencyGUI()
    if EmergencyGui then EmergencyGui:Destroy() end
    EmergencyGui = Instance.new("ScreenGui")
    EmergencyGui.Name = "ScannerEmergency"
    EmergencyGui.ResetOnSpawn = false
    EmergencyGui.IgnoreGuiInset = true
    EmergencyGui.Enabled = true
    EmergencyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    EmergencyGui.Parent = getParent()

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 480, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -240, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = EmergencyGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 100, 100)
    stroke.Thickness = 2
    stroke.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 36)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 0.5
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    title.Text = "Scanner v8.0 — EMERGENCY MODE (Rayfield failed)"
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.Parent = mainFrame
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

    local btnContainer = Instance.new("Frame")
    btnContainer.Size = UDim2.new(1, -20, 1, -50)
    btnContainer.Position = UDim2.new(0, 10, 0, 40)
    btnContainer.BackgroundTransparency = 1
    btnContainer.Parent = mainFrame

    local btnList = Instance.new("UIListLayout")
    btnList.Padding = UDim.new(0, 6)
    btnList.Parent = btnContainer

    local function makeBtn(text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(235, 235, 240)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.Parent = btnContainer
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    makeBtn("Scan Game + Auto-Analyze", function() performScan() end)
    makeBtn("Re-run All Sub-Scans", function() autoRunAllScans() end)
    makeBtn("Start 1-Min Deep Scan", function() startDeepScan(60) end)
    makeBtn("Start 5-Min Deep Scan", function() startDeepScan(300) end)
    makeBtn("Stop Deep Scan", function()
        State.deepScanning = false
        if connections.deepWorkspace then connections.deepWorkspace:Disconnect() connections.deepWorkspace = nil end
        if connections.deepWorkspaceRem then connections.deepWorkspaceRem:Disconnect() connections.deepWorkspaceRem = nil end
        if connections.deepMonsterMove then connections.deepMonsterMove:Disconnect() connections.deepMonsterMove = nil end
        if connections.deepPlayerPos then connections.deepPlayerPos:Disconnect() connections.deepPlayerPos = nil end
        restoreNamecallHook()
    end)
    makeBtn("Export JSON", function()
        local f = autoSaveDump(true)
        if f then print("Saved: " .. f) end
    end)
    makeBtn("Print Full Stats", function()
        print(string.format("Scripts: %d | OK: %d | Failed: %d | Deduped: %d", State.stats.total, State.stats.success, State.stats.failed, State.stats.deduped))
        print(string.format("Remotes: %d Events, %d Functions, %d Bindables, %d BindableFuncs", #State.remotes.events, #State.remotes.functions, #State.remotes.bindables, #State.remotes.bindableFuncs))
        print(string.format("Objects: %d Prompts, %d Clicks, %d NPCs, %d Spawns", #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids, #State.objects.spawns))
        print(string.format("Assets: %d Sounds, %d Animations, %d Decals, %d Meshes", #State.assets.sounds, #State.assets.animations, #State.assets.decals, #State.assets.meshes))
        print(string.format("AC: %d | Backdoors: %d | Require: %d | Attrs: %d | Tags: %d", #State.antiCheatDetections, #State.backdoorDetections, #State.requireMap, #State.attributes, #State.tags))
        print(string.format("Executor: %s — %d/%d functions", State.executorInfo, execTotalAvailable, execTotalChecked))
    end)
    makeBtn("Print Remotes", function()
        for _, r in ipairs(State.remotes.events) do print("[Event] " .. r.path) end
        for _, r in ipairs(State.remotes.functions) do print("[Func] " .. r.path) end
        for _, r in ipairs(State.remotes.bindables) do print("[Bindable] " .. r.path) end
        for _, r in ipairs(State.remotes.bindableFuncs) do print("[BindableFunc] " .. r.path) end
    end)
    makeBtn("Print AC & Backdoors", function()
        for _, d in ipairs(State.antiCheatDetections) do print(string.format("[AC] %s:%d (%s) %s", d.script, d.line, d.pattern, d.text)) end
        for _, d in ipairs(State.backdoorDetections) do print(string.format("[BD] %s:%d (%s) %s", d.script, d.line, d.pattern, d.text)) end
    end)
    makeBtn("Clear Results", function()
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
        print("[K]vk: All cleared")
    end)

    -- Keybind toggle
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.RightControl then
            EmergencyGui.Enabled = not EmergencyGui.Enabled
        end
    end)

    print("[K]vk: Emergency GUI built (Rayfield failed to load)")
end

-- ============================================
-- BUILD UI (Rayfield or Emergency)
-- ============================================
local Window

if RayfieldLoaded and Rayfield then
    -- We have Rayfield, build the full UI
    Window = Rayfield:CreateWindow({
        Name = "Universal Scanner v8.0 — " .. GameName,
        LoadingTitle = "Scanning " .. GameName,
        LoadingSubtitle = "v8.0 — Iterative Scan + Remote Profiling + AC Detection",
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

    print("[K]vk: Universal Game Scanner v8.0 loaded with Rayfield for " .. GameName)
    safeNotify("Scanner v8.0 Loaded", "Press Right Ctrl to toggle UI\nScan Game button to start everything")

else
    -- Rayfield failed, build emergency GUI
    warn("[K]vk: Rayfield failed to load from all URLs. Building emergency GUI...")
    buildEmergencyGUI()
end
