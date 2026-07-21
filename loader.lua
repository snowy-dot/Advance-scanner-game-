--!nocheck
-- ============================================
-- ADVANCED GAME SCANNER ONLY
-- ============================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

-- Load Rayfield
local Rayfield = nil
pcall(function()
    local response = game:HttpGet('https://sirius.menu/rayfield')
    local func = loadstring(response)
    if func then
        Rayfield = func()
    end
end)

if not Rayfield then
    pcall(function()
        local response = game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua')
        local func = loadstring(response)
        if func then
            Rayfield = func()
        end
    end)
end

if not Rayfield then
    print("Rayfield failed to load")
    return
end

-- State
local State = {}
State.Scanner_Dropdown = nil
State.FoundScripts = {}

-- ============================================
-- SCANNER LOGIC
-- ============================================
local function copyScriptToClipboard(scriptName)
    for _, data in pairs(State.FoundScripts) do
        if data.Name == scriptName then
            if setclipboard then
                setclipboard(data.Source)
                Rayfield:Notify({
                    Title = "Copied",
                    Content = "Script copied to your clipboard!",
                    Duration = 3
                })
            else
                print(data.Source)
                Rayfield:Notify({
                    Title = "Error",
                    Content = "setclipboard not supported. Printed to F9.",
                    Duration = 3
                })
            end
            return
        end
    end
end

local function scanGameForScripts()
    State.FoundScripts = {}
    local scriptNames = {"None"}

    if not decompile then
        Rayfield:Notify({
            Title = "Error",
            Content = "Your executor does not support decompile()",
            Duration = 3
        })
        return
    end

    Rayfield:Notify({
        Title = "Scanning",
        Content = "Scanning Local/Module scripts... UI may freeze briefly.",
        Duration = 3
    })

    for _, obj in pairs(game:GetDescendants()) do
        -- Strictly scan LocalScripts and ModuleScripts (Ignores Server Scripts completely)
        if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            local success, source = pcall(function()
                return decompile(obj)
            end)
            
            if success and source then
                local lowerSrc = string.lower(source)
                local isGunScript = false
                
                if string.find(lowerSrc, "raycast") then isGunScript = true end
                if string.find(lowerSrc, "firearm") then isGunScript = true end
                if string.find(lowerSrc, "bullet") then isGunScript = true end
                if string.find(lowerSrc, "shoot") then isGunScript = true end
                if string.find(lowerSrc, "fireserver") then isGunScript = true end
                if string.find(lowerSrc, "weapon") then isGunScript = true end
                
                if isGunScript then
                    table.insert(State.FoundScripts, {
                        Name = obj:GetFullName(),
                        Source = source
                    })
                    table.insert(scriptNames, obj:GetFullName())
                end
            end
        end
    end

    if State.Scanner_Dropdown then
        State.Scanner_Dropdown:Refresh(scriptNames)
    end
    
    Rayfield:Notify({
        Title = "Scan Complete",
        Content = "Found " .. #State.FoundScripts .. " potential scripts.",
        Duration = 3
    })
end

-- ============================================
-- UI SETUP
-- ============================================
local WindowConfig = {
    Name = "Game Scanner",
    LoadingTitle = "Scanner",
    LoadingSubtitle = "by Rayfield",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
}
local Window = Rayfield:CreateWindow(WindowConfig)

local TabScanner = Window:CreateTab("Scanner", 4483362458)

local ScanButtonConfig = {
    Name = "Scan Game for Gun/Combat Scripts",
    Callback = function()
        scanGameForScripts()
    end
}
TabScanner:CreateButton(ScanButtonConfig)

local ScannerDropdownConfig = {
    Name = "Found Scripts (Click to Copy)",
    Options = {"None"},
    CurrentOption = "None",
    Callback = function(Value)
        if Value ~= "None" then
            copyScriptToClipboard(Value)
        end
    end
}
State.Scanner_Dropdown = TabScanner:CreateDropdown(ScannerDropdownConfig)

local CopyAllConfig = {
    Name = "Copy All Found Scripts to Clipboard",
    Callback = function()
        local allScripts = ""
        for _, data in pairs(State.FoundScripts) do
            allScripts = allScripts .. "=== " .. data.Name .. " ===\n" .. data.Source .. "\n\n"
        end
        if setclipboard then
            setclipboard(allScripts)
            Rayfield:Notify({
                Title = "Copied All",
                Content = "All scripts copied to clipboard!",
                Duration = 3
            })
        else
            print(allScripts)
            Rayfield:Notify({
                Title = "Error",
                Content = "setclipboard not supported. Printed to F9.",
                Duration = 3
            })
        end
    end
}
TabScanner:CreateButton(CopyAllConfig)

local UnloadConfig = {
    Name = "Unload Script",
    Callback = function()
        Rayfield:Destroy()
    end
}
TabScanner:CreateButton(UnloadConfig)

local NotifyConfig = {
    Title = "Game Scanner",
    Content = "Loaded successfully! Press RightCtrl to toggle UI.",
    Duration = 3
}
Rayfield:Notify(NotifyConfig)
