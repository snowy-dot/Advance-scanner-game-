    DeepScan.connections.monsterTick = RunService.Heartbeat:Connect(function()
        if not DeepScan.active then return end
        if tick() - lastMove < 5 then return end
        lastMove = tick()
        local mf = Workspace:FindFirstChild("Monsters")
            or Workspace:FindFirstChild("Enemies")
            or Workspace:FindFirstChild("NPCs")
            or Workspace:FindFirstChild("Mobs")
        if mf then
            for _, m in ipairs(mf:GetChildren()) do
                local root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("RootPart")
                if root then
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    DeepScan.data.monsterMoves.push({
                        time=os.date("%H:%M:%S"),
                        name=m.Name,
                        pos=tostring(root.Position),
                        vel=tostring(root.AssemblyLinearVelocity.Magnitude),
                        hp=hum and hum.Health or 0,
                    })
                end
            end
        end
    end)

    -- Player position sampling
    local lastPP = 0
    DeepScan.connections.playerTick = RunService.Heartbeat:Connect(function()
        if not DeepScan.active then return end
        if tick() - lastPP < 10 then return end
        lastPP = tick()
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    DeepScan.data.playerPos.push({
                        t=os.date("%H:%M:%S"), who=p.Name, pos=tostring(root.Position)
                    })
                end
            end
        end
    end)

    -- __namecall hook (existence-checked this time)
    pcall(function()
        local mt = getrawmetatable(game)
        if mt and type(hookmetamethod) == "function" then
            DeepScan.originalNamecall = mt.__namecall
            local safe_nc = _newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" or method == "InvokeServer" then
                    local args = {...}
                    local argStrs = {}
                    for i, a in ipairs(args) do
                        local t = typeof(a)
                        argStrs[i] = (t == "Instance") and a.ClassName or tostring(a):sub(1,60)
                    end
                    DeepScan.data.remoteCalls.push({
                        time=os.date("%H:%M:%S"),
                        remote=tostring(self.Name),
                        method=tostring(method),
                        args=table.concat(argStrs, ", "),
                    })
                end
                return DeepScan.originalNamecall(self, ...)
            end)
            setreadonly(mt, false)
            mt.__namecall = safe_nc
            setreadonly(mt, true)
            DeepScan.hooked = true
        elseif mt then
            -- fallback manual hook without hookmetamethod
            DeepScan.originalNamecall = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" or method == "InvokeServer" then
                    DeepScan.data.remoteCalls.push({
                        time=os.date("%H:%M:%S"),
                        remote=tostring(self.Name),
                        method=tostring(method),
                        args="?",
                    })
                end
                return DeepScan.originalNamecall(self, ...)
            end
            setreadonly(mt, true)
            DeepScan.hooked = true
        end
    end)

    -- auto-stop timer
    task.delay(durationSec, function()
        if DeepScan.active then
            DeepScan.stop()
        end
    end)
end

--=============================================================
-- EXPORT
--=============================================================
local function exportResults()
    local out = {}
    out[#out+1] = ("=== Universal Game Scanner v9.0 ===")
    out[#out+1] = ("Game: %s | PlaceId: %d"):format(tostring(GameName), game.PlaceId)
    out[#out+1] = ("Executor: %s"):format(State.executorInfo)
    out[#out+1] = ("Scan: %d scripts found / %d OK / %d bytecode / %d failed\n"):
        format(State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed)

    out[#out+1] = "--- SCRIPTS ---"
    for _, r in ipairs(State.results) do
        out[#out+1] = ("[%s][%s] %s (%s)"):format(r.className, r.status, r.path, r.hash)
    end

    out[#out+1] = "\n--- REMOTES ---"
    out[#out+1] = ("Events (%d):"):format(#State.remotes.events)
    for _, e in ipairs(State.remotes.events) do out[#out+1] = "  "..e.path end
    out[#out+1] = ("Functions (%d):"):format(#State.remotes.functions)
    for _, f in ipairs(State.remotes.functions) do out[#out+1] = "  "..f.path end
    out[#out+1] = ("Bindables (%d/%d):"):format(#State.remotes.bindables, #State.remotes.bindableFuncs)
    for _, b in ipairs(State.remotes.bindables) do out[#out+1] = "  "..b.path end

    out[#out+1] = "\n--- OBJECTS ---"
    out[#out+1] = ("Prompts (%d), ClickDetectors (%d), NPCs (%d), Spawns (%d), Highlights (%d), BBGui (%d), SurfaceGui (%d), Values (%d), Configs (%d)"):
        format(#State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids,
               #State.objects.spawns, #State.objects.highlights, #State.objects.billboards,
               #State.objects.surfaces, #State.objects.values, #State.objects.configurations)

    out[#out+1] = "\n--- ASSETS ---"
    out[#out+1] = ("Sounds (%d), Animations (%d), Decals (%d), Meshes (%d), Textures (%d)"):
        format(#State.assets.sounds, #State.assets.animations,
               #State.assets.decals, #State.assets.meshes, #State.assets.textures)

    if #State.keywordResults > 0 then
        out[#out+1] = "\n--- KEYWORD HITS ---"
        for _, kr in ipairs(State.keywordResults) do
            out[#out+1] = ("%s : %d matches"):format(kr.keyword, kr.count)
            for _, m in ipairs(kr.matches) do
                out[#out+1] = ("    %s:%d -> %s"):format(m.script, m.line, m.text)
            end
        end
    end

    if #State.acDetections > 0 then
        out[#out+1] = "\n--- ANTI-CHEAT PATTERNS ---"
        for _, d in ipairs(State.acDetections) do
            out[#out+1] = ("[%s] %s:%d -> %s"):format(d.pattern, d.script, d.line, d.text)
        end
    end

    if #State.bdDetections > 0 then
        out[#out+1] = "\n--- BACKDOOR SUSPECTS ---"
        for _, d in ipairs(State.bdDetections) do
            out[#out+1] = ("[%s] %s:%d -> %s"):format(d.pattern, d.script, d.line, d.text)
        end
    end

    if #State.requireMap > 0 then
        out[#out+1] = "\n--- REQUIRE MAP ---"
        for _, r in ipairs(State.requireMap) do
            out[#out+1] = ("%s -> %s (line %s)"):format(r.script, r.target, tostring(r.line))
        end
    end

    return table.concat(out, "\n")
end

local function saveToFile(content)
    if not _writefile then
        notify("Export", "writefile unavailable on this executor.", 5)
        return nil
    end
    _makefolder("UGS_Scans")
    local fname = ("UGS_Scans/%s_%s.txt"):format(safeName, os.date("%Y%m%d_%H%M%S"))
    local ok = pcall(_writefile, fname, content)
    if ok then notify("Export", "Saved to "..fname, 6) return fname end
    notify("Export", "Write failed.", 5)
    return nil
end

local function toClipboard(text)
    if not _setclipboard then
        notify("Clipboard", "setclipboard unavailable.", 4)
        return
    end
    _setclipboard(text)
    notify("Clipboard", "Copied "..#text.." chars.", 3)
end

--=============================================================
-- RAYFIELD UI
--=============================================================
local Window = Rayfield:CreateWindow({
    Name = "Universal Game Scanner v9.0",
    LoadingTitle = "UGS",
    LoadingSubtitle = "by Kovak's edition",
    ConfigurationSaving = {
        Enabled = false,
    },
})
getgenv().__UGS_Window = Window

local TabMain   = Window:CreateTab("Main", "scan-search")
local TabScripts= Window:CreateTab("Scripts", "file-code")
local TabRemote = Window:CreateTab("Remotes", "satellite-dish")
local TabObjects= Window:CreateTab("Objects", "box")
local TabAnalysis=Window:CreateTab("Analysis", "search")
local TabDeep   = Window:CreateTab("Deep Scan", "activity")
local TabExec   = Window:CreateTab("Executor", "cpu")
local TabInfo   = Window:CreateTab("Info", "info")

--// MAIN
TabMain:CreateSection("Control")

local runBtn = TabMain:CreateButton({
    Name = "Run Full Scan",
    Callback = function()
        if State.scanning then notify("Scanner", "Already scanning.", 3) return end
        State.scanning = true
        ScanCancelled = false

        task.spawn(function()
            local steps = {
                {"Scripts", scanScripts},
                {"Remotes", scanRemotes},
                {"Objects", scanObjects},
                {"Assets", scanAssets},
                {"Attributes", scanAttributes},
                {"Tags", scanTags},
                {"Teams/Stats", scanTeamsStats},
                {"GUIs", scanGUIs},
                {"Executor Caps", scanExecutorCaps},
            }
            local total = #steps
            for i, step in ipairs(steps) do
                if ScanCancelled then break end
                Rayfield:SetStatus(("Scanning %s (%d/%d)..."):format(step[1], i, total))
                task.spawn(step[2])
                task.wait(0.05)
            end

            Rayfield:SetStatus("Analyzing sources...")
            analyzeSources()

            State.scanning = false
            Rayfield:SetStatus(("Done. %d scripts, %d keywords hit, %d AC patterns."):
                format(State.stats.total, #State.keywordResults, #State.acDetections))
            notify("Scan Complete",
                ("Total scripts: %d\nOK: %d | BC: %d | Failed: %d\nKeywords: %d categories\nAC: %d hits | BD: %d suspects"):
                format(State.stats.total, State.stats.success, State.stats.bytecode,
                       State.stats.failed, #State.keywordResults,
                       #State.acDetections, #State.bdDetections), 8)
        end)
    end,
})

TabMain:CreateButton({
    Name = "Cancel Current Scan",
    Callback = function() ScanCancelled = true end,
})

local lastExportText = ""
TabMain:CreateButton({
    Name = "Export to file + clipboard",
    Callback = function()
        if #State.results == 0 then notify("Export", "Nothing to export yet.", 3) return end
        lastExportText = exportResults()
        toClipboard(lastExportText)
        saveToFile(lastExportText)
    end,
})

TabMain:CreateDivider()
TabMain:CreateLabel(("Game: %s | PlaceId: %d"):format(GameName, game.PlaceId))

--// SCRIPTS TAB
TabScripts:CreateSection("Script Results")
local scriptListLabel = TabScripts:CreateLabel("No scripts scanned yet.")
local scriptDetailBtn = TabScripts:CreateInput({
    Name = "Get Source by Index",
    PlaceholderText = "Enter index (1..N)",
    RemoveTextAfterFocusLost = false,
    Callback = function(val)
        local idx = tonumber(val)
        if not idx or not State.results[idx] then
            notify("Source", "Invalid index.", 3)
            return
        end
        local r = State.results[idx]
        local head = r.source and r.source:sub(1, 4000) or "(no source)"
        toClipboard(head)
        notify(r.className .. ": " .. r.path,
            ("Status: %s | Hash: %s\nFirst %d chars copied to clipboard."):
            format(r.status, r.hash, #head), 8)
    end,
})

-- refresh Scripts tab when user opens it via Main export
TabScripts:CreateButton({
    Name = "[Refresh list]",
    Callback = function()
        if #State.results == 0 then
            scriptListLabel:Set("No scripts scanned yet.")
        else
            local lines = {}
            lines[1] = ("%d scripts | OK:%d BC:%d FAIL:%d\n"):format(
                State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed)
            local maxShow = math.min(#State.results, 80)
            for i = 1, maxShow do
                local r = State.results[i]
                lines[#lines+1] = ("[%d][%s|%s] %s"):format(i, r.status, r.className, r.path)
            end
            if #State.results > maxShow then
                lines[#lines+1] = ("... +%d more (use index lookup)"):format(#State.results - maxShow)
            end
            scriptListLabel:Set(table.concat(lines, "\n"))
        end
    end,
})

--// REMOTES TAB
TabRemote:CreateSection("Discovered Remotes")
local remoteLabel = TabRemote:CreateLabel("Not scanned.")
TabRemote:CreateButton({
    Name = "[Refresh remotes]",
    Callback = function()
        local L = {}
        L[#L+1] = ("Events (%d):"):format(#State.remotes.events)
        for i, e in ipairs(State.remotes.events) do L[#L+1] = "  "..e.path end
        L[#L+1] = ("Functions (%d):"):format(#State.remotes.functions)
        for i, f in ipairs(State.remotes.functions) do L[#L+1] = "  "..f.path end
        L[#L+1] = ("Bindables (%d/%d)"):format(#State.remotes.bindables, #State.remotes.bindableFuncs)
        remoteLabel:Set(table.concat(L, "\n"))
    end,
})

TabRemote:CreateSection("Fire Remote (test)")
TabRemote:CreateParagraph({Title="Warning", Content="Firing an unknown remote can get you kicked/banned. Use with judgment."})
local fireInput = TabRemote:CreateInput({
    Name = "Remote Event Path",
    PlaceholderText = "Path or partial path to a RemoteEvent",
    RemoveTextAfterFocusLost = false,
    Callback = function(pathInput) end,
})
local fireArgsInput = TabRemote:CreateInput({
    Name = "Args (comma-sep; types auto)",
    PlaceholderText = 'Example: Hello, 123, true',
    RemoveTextAfterFocusLost = false,
    Callback = function(argInput) end,
})

TabRemote:CreateButton({
    Name = "Fire RemoteEvent with Args",
    Callback = function()
        if not fireInput or fireInput == "" then notify("Fire", "No path given.", 3) return end
        local target = nil
        for _, e in ipairs(State.remotes.events) do
            if e.path == fireInput or e.path:lower():find(fireInput:lower(), 1, true) then
                target = e
                break
            end
        end
        if not target then notify("Fire", "Remote not found in results.", 3) return end

        -- resolve actual Instance from full path
        local parts = string.split(target.path, ".")
        local inst = game
        for i = 2, #parts do  -- skip leading "game"
            if inst then inst = inst:FindFirstChild(parts[i]) end
        end
        if not inst or not inst:IsA("RemoteEvent") then
            notify("Fire", "Instance lookup failed.", 4)
            return
        end

        -- parse args
        local args = {}
        if fireArgsInput and fireArgsInput ~= "" then
            for tok in fireArgsInput:gmatch("[^,]+") do
                tok = tok:gsub("^%s+", ""):gsub("%s+$", "")
                if tok == "true" then table.insert(args, true)
                elseif tok == "false" then table.insert(args, false)
                elseif tonumber(tok) then table.insert(args, tonumber(tok))
                else table.insert(args, tok) end
            end
        end

        notify("Firing", target.name, 3)
        task.spawn(function()
            inst:FireServer(unpack(args))
        end)
    end,
})

--// OBJECTS TAB
TabObjects:CreateSection("World Objects")
local objLabel = TabObjects:CreateLabel("Not scanned.")
TabObjects:CreateButton({
    Name = "[Refresh objects]",
    Callback = function()
        objLabel:Set(("Prompts: %d\nClickDetectors: %d\nNPCs/Humanoids: %d\nSpawns: %d\nHighlights: %d\nBillboards: %d\nSurfaces: %d\nValues: %d\nConfigs: %d\n\nAssets:\nSounds %d | Anims %d | Decals %d | Meshes %d"):
            format(
                #State.objects.prompts, #State.objects.clickDetectors, #State.objects.humanoids,
                #State.objects.spawns, #State.objects.highlights, #State.objects.billboards,
                #State.objects.surfaces, #State.objects.values, #State.objects.configurations,
                #State.assets.sounds, #State.assets.animations, #State.assets.decals, #State.assets.meshes))
    end,
})

--// ANALYSIS TAB
TabAnalysis:CreateSection("Keyword / AC / Backdoor Hits")
local analysisLabel = TabAnalysis:CreateLabel("Not analyzed.")
TabAnalysis:CreateButton({
    Name = "[Refresh analysis]",
    Callback = function()
        local L = {}

        if #State.keywordResults > 0 then
            L[#L+1] = "== Keywords =="
            for _, k in ipairs(State.keywordResults) do
                L[#L+1] = ("%s: %d hits"):format(k.keyword, k.count)
                for _, m in ipairs(k.matches) do
                    L[#L+1] = ("   %s:%d %s"):format(m.script:match("[^.]+$") or "?", m.line, m.text)
                end
            end
        end

        if #State.acDetections > 0 then
            L[#L+1] = "\n== Anti-cheat suspect patterns =="
            for _, d in ipairs(State.acDetections) do
                L[#L+1] = ("[%s] %s:%d %s"):format(d.pattern, d.script:match("[^.]+$"), d.line, d.text)
            end
        end

        if #State.bdDetections > 0 then
            L[#L+1] = "\n== Backdoor suspects =="
            for _, d in ipairs(State.bdDetections) do
                L[#L+1] = ("[%s] %s:%d %s"):format(d.pattern, d.script:match("[^.]+$"), d.line, d.text)
            end
        end

        if #State.requireMap > 0 then
            L[#L+1] = "\n== Require calls =="
            for _, r in ipairs(State.requireMap) do
                L[#L+1] = ("%s -> %s"):format(r.script:match("[^.]+$"), r.target)
            end
        end

        analysisLabel:Set((#L > 0) and table.concat(L, "\n") or "No hits.")
    end,
})

--// DEEP SCAN TAB
TabDeep:CreateSection("Live Monitoring")
local deepStatusLabel = TabDeep:CreateLabel("Idle.")
local durInput = TabDeep:CreateSlider({
    Name = "Duration (sec)",
    Range = {30, 1800}, Increment = 30,
    Suffix = "s", CurrentValue = 300,
    Flag = "DeepDur",
    Callback = function(v) end,
})
local durValue = 300

TabDeep:CreateToggle({
    Name = "Apply slider on start",
    CurrentValue = true,
    Flag = "UseDeepDur",
    Callback = function(v) end,
})

TabDeep:CreateButton({
    Name = "Start Deep Scan",
    Callback = function()
        local useDur = Rayfield.Flags.UseDeepDur
        local chosen = useDur and Rayfield.Flags.DeepDur or 300
        DeepScan.start(chosen)
        deepStatusLabel:Set(("Running for %ds..."):format(chosen))
    end,
})

TabDeep:CreateButton({
    Name = "Stop Deep Scan",
    Callback = function()
        DeepScan.stop()
        deepStatusLabel:Set("Stopped.")
    end,
})

TabDeep:CreateButton({
    Name = "Dump Deep Data to clipboard",
    Callback = function()
        local dd = DeepScan.data
        local L = {"=== DEEP SCAN DUMP ==="}
        L[#L+1] = ("Prompt Interactions: %d"):format(dd.prompts.count())
        for item in pairs(dd.prompts.items()) do
            L[#L+1] = ("  [%s] %s"):format(item.time or "?", item.path or "?")
        end
        L[#L+1] = ("Monster Spawns: %d"):format(dd.monsterSpawns.count())
        for _, m in ipairs(dd.monsterSpawns.items()) do
            L[#L+1] = ("  [%s] %s hp=%s pos=%s"):format(m.time, m.name, tostring(m.hp), tostring(m.pos))
        end
        L[#L+1] = ("Monster Moves sampled: %d"):format(dd.monsterMoves.count())
        for _, m in ipairs(dd.monsterMoves.items()) do
            L[#L+1] = ("  [%s] %s pos=%s vel=%s hp=%s"):format(m.time, m.name, m.pos, m.vel, tostring(m.hp))
        end
        L[#L+1] = ("WS Adds: %d | Removes: %d"):format(dd.workspaceAdds.count(), dd.workspaceRms.count())
        L[#L+1] = ("Remote Calls captured: %d"):format(dd.remoteCalls.count())
        for _, r in ipairs(dd.remoteCalls.items()) do
            L[#L+1] = ("  [%s] %s:%s(%s)"):format(r.time, r.remote, r.method, r.args)
        end
        L[#L+1] = ("Player Pos samples: %d"):format(dd.playerPos.count())

        local text = table.concat(L, "\n")
        toClipboard(text)
        notify("Deep Dump", ("%d chars copied."):format(#text), 5)
    end,
})

task.spawn(function()
    while true do
        if DeepScan.active then
            local elapsed = os.time() - DeepScan.data.startTime
            deepStatusLabel:Set(("Running... %ds elapsed. PromptHits=%d MonSpawns=%d RemoteCalls=%d"):
                format(elapsed,
                    DeepScan.data.prompts.count(),
                    DeepScan.data.monsterSpawns.count(),
                    DeepScan.data.remoteCalls.count()))
        end
        task.wait(2)
    end
end)

--// EXECUTOR TAB
TabExec:CreateSection("Capabilities")
local execLabel = TabExec:CreateLabel("Probing...")
TabExec:CreateButton({
    Name = "[Probe executor]",
    Callback = function()
        scanExecutorCaps()
        local byCat = {}
        for _, c in ipairs(State.executorCaps) do
            byCat[c.cat] = byCat[c.cat] or {yes={}, no={}}
            if c.avail then table.insert(byCat[c.cat].yes, c.name)
            else table.insert(byCat[c.cat].no, c.name) end
        end
        local L = {"Executor: "..State.executorInfo}
        local totalYes = 0
        for cat, data in pairs(byCat) do
            totalYes += #data.yes
            if #data.yes > 0 then
                L[#L+1] = ("\n["..cat.."] ✓ "..table.concat(data.yes, ", "))
            end
            if #data.no > 0 then
                L[#L+1] = "["..cat.."] ✗ "..table.concat(data.no, ", ")
            end
        end
        execLabel:Set(table.concat(L, "\n"))
        notify("Executor Probe", ("%s supports %d/%d functions."):format(
            State.executorInfo, totalYes, #State.executorCaps), 6)
    end,
})

--// INFO TAB
TabInfo:CreateSection("About")
TabInfo:CreateParagraph({Title="Universal Game Scanner v9.0", Content=[[
Rewritten from v8.1.

FIXES:
- Traversal yield fixed (per-node yield instead of modulo check that broke past batches)
- O(n) capped buffers replaced with O(1) ring buffer class
- Keyword search single-pass per source instead of O(N*M*lines)
- All ProximityPrompt connections tracked and torn down on stop
- Full deep-scan teardown restores original __namecall properly
- newcclosure existence-checked with fallback shim
- Executor probe uses existence-checked functions only

USAGE:
- Run Full Scan → wait → Export to clipboard/file
- Check Analysis tab for keyword & anticheat hits
- Fire RemoteEvent tab to test specific remotes
- Deep Scan for live monitoring (remotes/spawns/prompts)

NOTES:
- Nothing is sent anywhere. All data stays local.
- Bytecode-only scripts still count as "success" but have no source.
]]})

notify("UGS v9.0 loaded",
    ("Game: %s\nPress 'Run Full Scan' on Main tab."):format(GameName), 8)

Rayfield:SetStatus("Ready — awaiting scan.")
