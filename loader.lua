--!nocheck
-- Executor Capability Checker v1.0 — [K]vk
-- Custom GUI with latest Rayfield
-- Keybind: Right Ctrl to toggle

local Rayfield
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

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
-- EXECUTOR CAPABILITY DEFINITIONS
-- ============================================
local executorFuncs = {
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
    {name = "setsimulationradius", desc = "Set sim radius", category = "Execution"},
    {name = "getcustomasset", desc = "Get custom asset", category = "Asset"},
    {name = "getcustomassetfunc", desc = "Custom asset function", category = "Asset"},
    {name = "saveinstance", desc = "Save instance", category = "Asset"},
    {name = "getinstances", desc = "Get all instances", category = "Instance"},
    {name = "getnilinstances", desc = "Get nil instances", category = "Instance"},
    {name = "gethiddenproperty", desc = "Get hidden property", category = "Instance"},
    {name = "sethiddenproperty", desc = "Set hidden property", category = "Instance"},
    {name = "isluau", desc = "Check if Luau", category = "Instance"},
    {name = "gethui", desc = "Get HUI", category = "Environment"},
}

-- Remove duplicates
local seen = {}
local uniqueFuncs = {}
for _, f in ipairs(executorFuncs) do
    if not seen[f.name] then
        seen[f.name] = true
        table.insert(uniqueFuncs, f)
    end
end
executorFuncs = uniqueFuncs

-- ============================================
-- CAPABILITY CHECKER
-- ============================================
local capResults = {}
local totalAvailable = 0
local totalChecked = 0

local function checkAllCaps()
    capResults = {}
    totalAvailable = 0
    totalChecked = 0

    for _, f in ipairs(executorFuncs) do
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
        table.insert(capResults, {
            name = f.name,
            desc = f.desc,
            category = f.category,
            available = avail,
        })
        totalChecked = totalChecked + 1
        if avail then totalAvailable = totalAvailable + 1 end
    end

    return capResults
end

-- ============================================
-- RAYFIELD LOAD
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
    Name = "Executor Capability Checker v1.0",
    LoadingTitle = "Checking Executor...",
    LoadingSubtitle = "Analyzing available functions",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySettings = { Key = Enum.KeyCode.RightControl, OnPress = function() end }
})

-- ============================================
-- TAB: OVERVIEW
-- ============================================
local TabOverview = Window:CreateTab("Overview")

TabOverview:CreateButton({
    Name = "Run Full Capability Check",
    Callback = function()
        checkAllCaps()
        safeNotify("Check Complete", string.format("%d/%d functions available", totalAvailable, totalChecked))
    end
})

TabOverview:CreateButton({
    Name = "Print Results to Console (F9)",
    Callback = function()
        if #capResults == 0 then
            safeNotify("Error", "Run a check first.")
            return
        end
        print("============================================")
        print("EXECUTOR CAPABILITY REPORT")
        print(string.format("Available: %d / %d", totalAvailable, totalChecked))
        print("============================================")
        for _, c in ipairs(capResults) do
            print(string.format("  %-25s %-30s [%s] %s",
                c.name, c.desc, c.category, c.available and "YES" or "NO"))
        end
        print("============================================")
        safeNotify("Printed", "Check F9 console for full report.")
    end
})

TabOverview:CreateButton({
    Name = "Copy Results to Clipboard",
    Callback = function()
        if #capResults == 0 then
            safeNotify("Error", "Run a check first.")
            return
        end
        if type(setclipboard) ~= "function" then
            safeNotify("Error", "setclipboard not available.")
            return
        end
        local text = "============================================\n"
        text = text .. "EXECUTOR CAPABILITY REPORT\n"
        text = text .. string.format("Available: %d / %d\n", totalAvailable, totalChecked)
        text = text .. "============================================\n\n"

        -- Group by category
        local categories = {}
        for _, c in ipairs(capResults) do
            if not categories[c.category] then categories[c.category] = {} end
            table.insert(categories[c.category], c)
        end

        for cat, items in pairs(categories) do
            text = text .. string.format("--- %s ---\n", cat:upper())
            for _, c in ipairs(items) do
                text = text .. string.format("  %-25s %-30s %s\n",
                    c.name, c.desc, c.available and "[YES]" or "[NO]")
            end
            text = text .. "\n"
        end

        pcall(setclipboard, text)
        safeNotify("Copied", "Full report copied to clipboard.")
    end
})

TabOverview:CreateButton({
    Name = "Save Report to File",
    Callback = function()
        if #capResults == 0 then
            safeNotify("Error", "Run a check first.")
            return
        end
        if type(writefile) ~= "function" then
            safeNotify("Error", "writefile not available.")
            return
        end
        local filename = "execcap_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
        local content = "============================================\n"
        content = content .. "Executor Capability Report\n"
        content = content .. string.format("Date: %s\n", os.date("%Y-%m-%d %H:%M:%S"))
        content = content .. string.format("Available: %d / %d\n", totalAvailable, totalChecked)
        content = content .. "============================================\n\n"

        local categories = {}
        for _, c in ipairs(capResults) do
            if not categories[c.category] then categories[c.category] = {} end
            table.insert(categories[c.category], c)
        end

        for cat, items in pairs(categories) do
            content = content .. string.format("=== %s ===\n", cat:upper())
            for _, c in ipairs(items) do
                content = content .. string.format("  %-25s %-30s %s\n",
                    c.name, c.desc, c.available and "[YES]" or "[NO]")
            end
            content = content .. "\n"
        end

        pcall(writefile, filename, content)
        safeNotify("Saved", "Report saved to: " .. filename)
    end
})

-- ============================================
-- TAB: INTERACTION
-- ============================================
local TabInteraction = Window:CreateTab("Interaction")

TabInteraction:CreateButton({
    Name = "Check Interaction Functions",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        local count = 0
        local avail = 0
        for _, c in ipairs(capResults) do
            if c.category == "Interaction" then
                count = count + 1
                if c.available then avail = avail + 1 end
            end
        end
        safeNotify("Interaction", string.format("%d/%d available", avail, count))
    end
})

TabInteraction:CreateButton({
    Name = "Print Interaction Caps",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        print("=== INTERACTION CAPABILITIES ===")
        for _, c in ipairs(capResults) do
            if c.category == "Interaction" then
                print(string.format("  %-25s %-30s %s",
                    c.name, c.desc, c.available and "YES" or "NO"))
            end
        end
        safeNotify("Printed", "Check F9 console.")
    end
})

-- ============================================
-- TAB: METATABLE
-- ============================================
local TabMeta = Window:CreateTab("Metatable")

TabMeta:CreateButton({
    Name = "Check Metatable Functions",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        local count = 0
        local avail = 0
        for _, c in ipairs(capResults) do
            if c.category == "Metatable" then
                count = count + 1
                if c.available then avail = avail + 1 end
            end
        end
        safeNotify("Metatable", string.format("%d/%d available", avail, count))
    end
})

TabMeta:CreateButton({
    Name = "Print Metatable Caps",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        print("=== METATABLE CAPABILITIES ===")
        for _, c in ipairs(capResults) do
            if c.category == "Metatable" then
                print(string.format("  %-25s %-30s %s",
                    c.name, c.desc, c.available and "YES" or "NO"))
            end
        end
        safeNotify("Printed", "Check F9 console.")
    end
})

-- ============================================
-- TAB: UTILITY
-- ============================================
local TabUtil = Window:CreateTab("Utility")

TabUtil:CreateButton({
    Name = "Check Utility Functions",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        local count = 0
        local avail = 0
        for _, c in ipairs(capResults) do
            if c.category == "Utility" then
                count = count + 1
                if c.available then avail = avail + 1 end
            end
        end
        safeNotify("Utility", string.format("%d/%d available", avail, count))
    end
})

TabUtil:CreateButton({
    Name = "Print Utility Caps",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        print("=== UTILITY CAPABILITIES ===")
        for _, c in ipairs(capResults) do
            if c.category == "Utility" then
                print(string.format("  %-25s %-30s %s",
                    c.name, c.desc, c.available and "YES" or "NO"))
            end
        end
        safeNotify("Printed", "Check F9 console.")
    end
})

-- ============================================
-- TAB: DECOMPILER
-- ============================================
local TabDecomp = Window:CreateTab("Decompiler")

TabDecomp:CreateButton({
    Name = "Check Decompiler Functions",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        local count = 0
        local avail = 0
        for _, c in ipairs(capResults) do
            if c.category == "Decompiler" then
                count = count + 1
                if c.available then avail = avail + 1 end
            end
        end
        safeNotify("Decompiler", string.format("%d/%d available", avail, count))
    end
})

TabDecomp:CreateButton({
    Name = "Print Decompiler Caps",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        print("=== DECOMPILER CAPABILITIES ===")
        for _, c in ipairs(capResults) do
            if c.category == "Decompiler" then
                print(string.format("  %-25s %-30s %s",
                    c.name, c.desc, c.available and "YES" or "NO"))
            end
        end
        safeNotify("Printed", "Check F9 console.")
    end
})

-- ============================================
-- TAB: ENVIRONMENT
-- ============================================
local TabEnv = Window:CreateTab("Environment")

TabEnv:CreateButton({
    Name = "Check Environment Functions",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        local count = 0
        local avail = 0
        for _, c in ipairs(capResults) do
            if c.category == "Environment" then
                count = count + 1
                if c.available then avail = avail + 1 end
            end
        end
        safeNotify("Environment", string.format("%d/%d available", avail, count))
    end
})

TabEnv:CreateButton({
    Name = "Print Environment Caps",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        print("=== ENVIRONMENT CAPABILITIES ===")
        for _, c in ipairs(capResults) do
            if c.category == "Environment" then
                print(string.format("  %-25s %-30s %s",
                    c.name, c.desc, c.available and "YES" or "NO"))
            end
        end
        safeNotify("Printed", "Check F9 console.")
    end
})

-- ============================================
-- TAB: NETWORK
-- ============================================
local TabNet = Window:CreateTab("Network")

TabNet:CreateButton({
    Name = "Check Network Functions",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        local count = 0
        local avail = 0
        for _, c in ipairs(capResults) do
            if c.category == "Network" then
                count = count + 1
                if c.available then avail = avail + 1 end
            end
        end
        safeNotify("Network", string.format("%d/%d available", avail, count))
    end
})

TabNet:CreateButton({
    Name = "Print Network Caps",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        print("=== NETWORK CAPABILITIES ===")
        for _, c in ipairs(capResults) do
            if c.category == "Network" then
                print(string.format("  %-25s %-30s %s",
                    c.name, c.desc, c.available and "YES" or "NO"))
            end
        end
        safeNotify("Printed", "Check F9 console.")
    end
})

-- ============================================
-- TAB: ALL RESULTS
-- ============================================
local TabAll = Window:CreateTab("All Results")

TabAll:CreateButton({
    Name = "Print Everything",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        print("============================================")
        print("FULL EXECUTOR CAPABILITY REPORT")
        print(string.format("Available: %d / %d", totalAvailable, totalChecked))
        print("============================================")
        for _, c in ipairs(capResults) do
            print(string.format("  [%s] %-25s %-30s %s",
                c.category, c.name, c.desc, c.available and "YES" or "NO"))
        end
        print("============================================")
        safeNotify("Printed", "Check F9 console for full report.")
    end
})

TabAll:CreateButton({
    Name = "Print Available Only",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        print("=== AVAILABLE FUNCTIONS ===")
        for _, c in ipairs(capResults) do
            if c.available then
                print(string.format("  [%s] %-25s %s", c.category, c.name, c.desc))
            end
        end
        safeNotify("Printed", "Check F9 console.")
    end
})

TabAll:CreateButton({
    Name = "Print Missing Only",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        print("=== MISSING FUNCTIONS ===")
        for _, c in ipairs(capResults) do
            if not c.available then
                print(string.format("  [%s] %-25s %s", c.category, c.name, c.desc))
            end
        end
        safeNotify("Printed", "Check F9 console.")
    end
})

TabAll:CreateButton({
    Name = "Copy Full Report",
    Callback = function()
        if #capResults == 0 then checkAllCaps() end
        if type(setclipboard) ~= "function" then
            safeNotify("Error", "setclipboard not available.")
            return
        end
        local text = "============================================\n"
        text = text .. "EXECUTOR CAPABILITY REPORT\n"
        text = text .. string.format("Date: %s\n", os.date("%Y-%m-%d %H:%M:%S"))
        text = text .. string.format("Available: %d / %d\n", totalAvailable, totalChecked)
        text = text .. "============================================\n\n"

        local categories = {}
        for _, c in ipairs(capResults) do
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

        -- Any remaining categories
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

-- ============================================
-- TAB: MISC
-- ============================================
local TabMisc = Window:CreateTab("Misc")

TabMisc:CreateButton({
    Name = "Re-check All",
    Callback = function()
        checkAllCaps()
        safeNotify("Re-checked", string.format("%d/%d available", totalAvailable, totalChecked))
    end
})

TabMisc:CreateButton({
    Name = "Check Specific Function",
    Callback = function()
        -- Simple inline check
        local funcsToCheck = {
            "firetouchinterest", "fireproximityprompt", "decompile", "getsrc",
            "getrawmetatable", "setreadonly", "newcclosure", "hookfunction",
            "request", "setclipboard", "writefile", "readfile", "loadstring",
            "getgenv", "gethui", "setsimulationradius",
        }
        print("=== QUICK CHECK ===")
        for _, fname in ipairs(funcsToCheck) do
            local avail = false
            pcall(function()
                local env = getfenv()
                if type(env[fname]) == "function" then avail = true end
            end)
            print(string.format("  %-25s %s", fname, avail and "YES" or "NO"))
        end
        safeNotify("Quick Check", "Printed to F9 console.")
    end
})

TabMisc:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        pcall(function()
            Rayfield:Destroy()
        end)
    end
})

TabMisc:CreateLabel("Executor Capability Checker v1.0")
TabMisc:CreateLabel("Press Right Ctrl to toggle")
TabMisc:CreateLabel("Checks 45+ executor functions")
TabMisc:CreateLabel("Categorized by type")

-- ============================================
-- AUTO-RUN ON STARTUP
-- ============================================
task.spawn(function()
    task.wait(2)
    checkAllCaps()
    safeNotify("Ready", string.format("%d/%d functions available", totalAvailable, totalChecked))
end)

-- ============================================
-- INIT
-- ============================================
Rayfield:LoadConfiguration()
print("[Executor Capability Checker v1.0] Loaded.")
print(string.format("[ECC] %d functions will be checked on startup.", #executorFuncs))
