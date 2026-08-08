--!nocheck
-- Universal Game Scanner — Rayfield Edition
-- Keybind: Right Ctrl to toggle

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Universal Game Scanner",
   LoadingTitle = "Universal Scanner",
   LoadingSubtitle = "by He",
   ConfigurationSaving = {
      Enabled = false,
   },
   Discord = {
      Enabled = false,
   },
   KeySettings = {
      Key = Enum.KeyCode.RightControl,
      OnPress = function() end,
   }
})

local TabScan = Window:CreateTab("Scanner", 4483362458)
local TabExport = Window:CreateTab("Export", 4483362458)

-- ============================================
-- STATE
-- ============================================
local State = {
    scanning = false,
    results = {},
    stats = { total = 0, success = 0, failed = 0, bytecode = 0 }
}

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
-- SCAN LOGIC
-- ============================================
local Paragraph = nil
local LastResultsText = ""

local function updateParagraph()
    local text = string.format(
        "Total Scripts: %d\nExtracted: %d\nBytecode: %d\nFailed: %d",
        State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed
    )
    LastResultsText = text
    if Paragraph then
        Paragraph:Set("Scan Results", text)
    end
end

local function performScan()
    if State.scanning then return end
    State.scanning = true
    State.results = {}
    State.stats = { total = 0, success = 0, failed = 0, bytecode = 0 }
    updateParagraph()

    local containers = getContainers()

    for _, containerData in ipairs(containers) do
        local container = containerData[1]
        local name = containerData[2]
        if container then
            for _, child in ipairs(container:GetDescendants()) do
                if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    State.stats.total = State.stats.total + 1
                    local path = child:GetFullName()
                    local className = child.ClassName
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

                    updateParagraph()
                    task.wait()
                end
            end
        end
    end

    State.scanning = false
    Rayfield:Notify({
        Title = "Scan Complete",
        Content = string.format("Found %d scripts. %d extracted, %d bytecode, %d failed.", State.stats.total, State.stats.success, State.stats.bytecode, State.stats.failed),
        Duration = 5
    })
end

-- ============================================
-- SCAN TAB
-- ============================================
Paragraph = TabScan:CreateParagraph("Scan Results", "No scan performed yet. Click the button below.")

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
        updateParagraph()
        Rayfield:Notify({
            Title = "Cleared",
            Content = "All scan results have been cleared.",
            Duration = 3
        })
    end
})

-- ============================================
-- EXPORT TAB
-- ============================================
TabExport:CreateButton({
    Name = "Export Full Dump to File",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({
                Title = "Error",
                Content = "Nothing to export. Run a scan first.",
                Duration = 3
            })
            return
        end

        if type(writefile) ~= "function" then
            Rayfield:Notify({
                Title = "Error",
                Content = "writefile is not supported by your executor.",
                Duration = 3
            })
            return
        end

        local content = "============================================\n"
        content = content .. "Universal Game Scanner Dump\n"
        content = content .. "Game: " .. game.Name .. "\n"
        content = content .. "Place ID: " .. tostring(game.PlaceId) .. "\n"
        content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        content = content .. "Total: " .. State.stats.total .. " | OK: " .. State.stats.success .. " | Bytecode: " .. State.stats.bytecode .. " | Failed: " .. State.stats.failed .. "\n"
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
        local ok, err = pcall(writefile, filename, content)
        if ok then
            Rayfield:Notify({
                Title = "Exported",
                Content = "Saved to: " .. filename,
                Duration = 5
            })
        else
            Rayfield:Notify({
                Title = "Error",
                Content = "Failed to write file: " .. tostring(err),
                Duration = 5
            })
        end
    end
})

TabExport:CreateButton({
    Name = "Export Script Index Only",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({
                Title = "Error",
                Content = "Nothing to export. Run a scan first.",
                Duration = 3
            })
            return
        end

        if type(writefile) ~= "function" then
            Rayfield:Notify({
                Title = "Error",
                Content = "writefile is not supported.",
                Duration = 3
            })
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
        Rayfield:Notify({
            Title = "Exported",
            Content = "Index saved to: " .. filename,
            Duration = 5
        })
    end
})

TabExport:CreateButton({
    Name = "Copy Stats to Clipboard",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({
                Title = "Error",
                Content = "Nothing to copy. Run a scan first.",
                Duration = 3
            })
            return
        end

        if type(setclipboard) ~= "function" then
            Rayfield:Notify({
                Title = "Error",
                Content = "setclipboard is not supported.",
                Duration = 3
            })
            return
        end

        local text = "Universal Scanner Results\n"
        text = text .. "Game: " .. game.Name .. " | Place: " .. tostring(game.PlaceId) .. "\n"
        text = text .. "Total: " .. State.stats.total .. " | OK: " .. State.stats.success .. " | Bytecode: " .. State.stats.bytecode .. " | Failed: " .. State.stats.failed .. "\n\n"
        for i, r in ipairs(State.results) do
            text = text .. string.format("[%d] %s | %s | %s\n", i, r.path, r.class, r.status)
        end

        pcall(setclipboard, text)
        Rayfield:Notify({
            Title = "Copied",
            Content = "Results copied to clipboard!",
            Duration = 3
        })
    end
})

TabExport:CreateButton({
    Name = "Copy All Source Code",
    Callback = function()
        if #State.results == 0 then
            Rayfield:Notify({
                Title = "Error",
                Content = "Nothing to copy. Run a scan first.",
                Duration = 3
            })
            return
        end

        if type(setclipboard) ~= "function" then
            Rayfield:Notify({
                Title = "Error",
                Content = "setclipboard is not supported.",
                Duration = 3
            })
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
            Rayfield:Notify({
                Title = "Error",
                Content = "No extractable source found.",
                Duration = 3
            })
            return
        end

        pcall(setclipboard, text)
        Rayfield:Notify({
            Title = "Copied",
            Content = "All source code copied to clipboard!",
            Duration = 3
        })
    end
})

-- ============================================
-- INIT
-- ============================================
Rayfield:LoadConfiguration()

print("[Universal Scanner] Loaded — Right Ctrl to toggle UI")
