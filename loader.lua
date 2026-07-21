--!nocheck
-- ============================================
-- ULTIMATE ADVANCED HUB V10
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera

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

-- ============================================
-- STATE
-- ============================================
local State = {}
State.ESP_Enabled = false
State.ESP_Box = true
State.ESP_Name = true
State.ESP_Distance = true
State.ESP_Tracers = false
State.ESP_Health = false
State.ESP_Skeleton = false
State.ESP_HeadDot = false
State.ESP_Rainbow = false
State.ESP_BoxColor = Color3.fromRGB(255, 0, 0)
State.ESP_NameColor = Color3.fromRGB(255, 255, 255)
State.ESP_TracerColor = Color3.fromRGB(255, 255, 255)
State.ESP_Objects = {}

State.Aimbot_Mode = "Off"
State.Aimbot_ToggleActive = false
State.Aimbot_FOV = 120
State.Aimbot_Smooth = 0
State.Aimbot_WallCheck = true
State.Aimbot_TeamCheck = true
State.Aimbot_ShowFOV = true
State.Aimbot_TargetPart = "Head"
State.Aimbot_RainbowFOV = false
State.Aimbot_FOVColor = Color3.fromRGB(255, 255, 255)

State.SilentAim_Enabled = false
State.CurrentTarget = nil
State.CachedSilentTarget = nil

State.Fly_Enabled = false
State.Fly_Speed = 50
State.Speed_Enabled = false
State.Speed_Amt = 50
State.InfJump_Enabled = false

State.Scanner_Dropdown = nil
State.FoundScripts = {}

-- ============================================
-- VISUALS SETUP
-- ============================================
local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "UniversalVisuals"
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true

pcall(function()
    ESPGui.Parent = gethui()
end)
if not ESPGui.Parent then
    pcall(function()
        ESPGui.Parent = CoreGui
    end)
end
if not ESPGui.Parent then
    ESPGui.Parent = LP:WaitForChild("PlayerGui")
end

local FOVCircle = Instance.new("Frame")
FOVCircle.Size = UDim2.new(0, 240, 0, 240)
FOVCircle.Position = UDim2.new(0.5, -120, 0.5, -120)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Parent = ESPGui
FOVCircle.Visible = false

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Color = Color3.fromRGB(255, 255, 255)
FOVStroke.Thickness = 1.5
FOVStroke.Transparency = 0.5
FOVStroke.Parent = FOVCircle

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(0.5, 0)
FOVCorner.Parent = FOVCircle

-- ============================================
-- ESP FUNCTIONS
-- ============================================
local function createESP(player)
    if State.ESP_Objects[player] then
        return
    end
    
    local frame = Instance.new("Frame")
    frame.BackgroundTransparency = 1
    frame.Parent = ESPGui

    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = State.ESP_BoxColor
    stroke.Thickness = 2
    stroke.Parent = box

    local nameLbl = Instance.new("TextLabel")
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = State.ESP_NameColor
    nameLbl.TextStrokeTransparency = 0.5
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.Visible = false
    nameLbl.Parent = frame

    local distLbl = Instance.new("TextLabel")
    distLbl.BackgroundTransparency = 1
    distLbl.TextColor3 = Color3.fromRGB(255, 255, 100)
    distLbl.TextStrokeTransparency = 0.5
    distLbl.Font = Enum.Font.Gotham
    distLbl.TextSize = 10
    distLbl.Visible = false
    distLbl.Parent = frame

    local healthBg = Instance.new("Frame")
    healthBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    healthBg.BorderSizePixel = 0
    healthBg.Visible = false
    healthBg.Parent = frame

    local healthFill = Instance.new("Frame")
    healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBg

    local tracer = Instance.new("Frame")
    tracer.BackgroundColor3 = State.ESP_TracerColor
    tracer.BorderSizePixel = 0
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    tracer.Size = UDim2.new(0, 1, 0, 1)
    tracer.Visible = false
    tracer.Parent = frame

    local headDot = Instance.new("Frame")
    headDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    headDot.Size = UDim2.fromOffset(8, 8)
    headDot.BorderSizePixel = 0
    headDot.AnchorPoint = Vector2.new(0.5, 0.5)
    headDot.Visible = false
    headDot.Parent = frame
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = headDot

    local skeletonLines = {}
    for i = 1, 14 do
        local line = Instance.new("Frame")
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        line.BorderSizePixel = 0
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Size = UDim2.new(0, 1, 0, 1)
        line.Visible = false
        line.Parent = frame
        table.insert(skeletonLines, line)
    end

    State.ESP_Objects[player] = {
        Frame = frame, 
        Box = box, 
        Tracer = tracer, 
        Name = nameLbl, 
        Dist = distLbl,
        HealthBg = healthBg,
        HealthFill = healthFill,
        HeadDot = headDot,
        Skeleton = skeletonLines
    }
end

local function removeESP(player)
    if State.ESP_Objects[player] then
        State.ESP_Objects[player].Frame:Destroy()
        State.ESP_Objects[player] = nil
    end
end

Players.PlayerRemoving:Connect(removeESP)

local function drawLine(lineFrame, p1, p2)
    local dist = (p2 - p1).Magnitude
    local angle = math.atan2(p2.Y - p1.Y, p2.X - p1.X)
    lineFrame.Position = UDim2.fromOffset((p1.X + p2.X) / 2, (p1.Y + p2.Y) / 2)
    lineFrame.Size = UDim2.fromOffset(dist, 1)
    lineFrame.Rotation = math.deg(angle)
    lineFrame.Visible = true
end

-- ============================================
-- AIMBOT LOGIC
-- ============================================
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDist = State.Aimbot_FOV
    local screenCenter = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LP and player.Character then
            local isTeam = false
            if State.Aimbot_TeamCheck and player.Team == LP.Team then
                isTeam = true
            end

            if not isTeam then
                local targetPart = player.Character:FindFirstChild(State.Aimbot_TargetPart)
                if not targetPart then targetPart = player.Character:FindFirstChild("Head") end
                if not targetPart then targetPart = player.Character:FindFirstChild("HumanoidRootPart") end
                if not targetPart then targetPart = player.Character:FindFirstChild("Torso") end
                if not targetPart then targetPart = player.Character:FindFirstChild("UpperTorso") end

                local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")

                if targetPart and myHrp then
                    local screenPos, onScreen = Cam:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if dist < shortestDist then
                            local visible = true
                            if State.Aimbot_WallCheck then
                                local rayParams = RaycastParams.new()
                                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                                rayParams.FilterDescendantsInstances = {LP.Character, player.Character}
                                local result = workspace:Raycast(myHrp.Position, (targetPart.Position - myHrp.Position).Unit * (targetPart.Position - myHrp.Position).Magnitude, rayParams)
                                if result then
                                    visible = false
                                end
                            end
                            
                            if visible then
                                shortestDist = dist
                                closestPlayer = player
                            end
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F then
        if State.Aimbot_Mode == "Toggle (Press F)" then
            State.Aimbot_ToggleActive = not State.Aimbot_ToggleActive
        end
    end
    if input.KeyCode == Enum.KeyCode.Space then
        if State.InfJump_Enabled and LP.Character then
            local hum = LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

-- ============================================
-- SILENT AIM HOOKS (Universal + Game Specific)
-- ============================================
pcall(function()
    -- 1. Universal Raycast Hook
    local OldNamecall
    OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if not checkcaller() and State.SilentAim_Enabled and State.CachedSilentTarget and self == workspace then
            local targetChar = State.CachedSilentTarget.Character
            if targetChar then
                local targetPart = targetChar:FindFirstChild(State.Aimbot_TargetPart)
                if not targetPart then targetPart = targetChar:FindFirstChild("Head") end
                
                if targetPart then
                    if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "FindPartOnRayWithWhitelist" then
                        local origin = args[1].Origin
                        local oldDir = args[1].Direction
                        local newDir = (targetPart.Position - origin)
                        if oldDir.Magnitude > 0 then
                            newDir = newDir.Unit * oldDir.Magnitude
                        end
                        args[1] = Ray.new(origin, newDir)
                    elseif method == "Raycast" then
                        local origin = args[1]
                        local oldDir = args[2]
                        local newDir = (targetPart.Position - origin)
                        if oldDir and oldDir.Magnitude > 0 then
                            newDir = newDir.Unit * oldDir.Magnitude
                        end
                        args[2] = newDir
                    end
                end
            end
        end
        return OldNamecall(self, table.unpack(args))
    end)

    -- 2. Game Specific FastCast Hook (WeaponManager)
    local WeaponManagerPath = game:GetService("ReplicatedStorage"):FindFirstChild("Common")
    if WeaponManagerPath and WeaponManagerPath:FindFirstChild("Managers") then
        WeaponManagerPath = WeaponManagerPath.Managers:FindFirstChild("WeaponManager")
    else
        WeaponManagerPath = nil
    end

    if WeaponManagerPath then
        local WeaponManager = require(WeaponManagerPath)
        local OldCast = WeaponManager.cast
        
        WeaponManager.cast = function(origin, direction, speed, maxDist, ignoreList, callbacks, ...)
            if State.SilentAim_Enabled and State.CachedSilentTarget then
                local target = State.CachedSilentTarget.Character
                if target then
                    local targetPart = target:FindFirstChild(State.Aimbot_TargetPart)
                    if not targetPart then targetPart = target:FindFirstChild("Head") end
                    if not targetPart then targetPart = target:FindFirstChild("HumanoidRootPart") end
                    
                    if targetPart then
                        local newDir = (targetPart.Position - origin).Unit
                        local oldCallbacks = callbacks or {}
                        local newCallbacks = {}
                        for k, v in pairs(oldCallbacks) do newCallbacks[k] = v end
                        
                        local oldOnHitCharacter = newCallbacks.onHitCharacter
                        newCallbacks.onHitCharacter = function(hitChar, hitPart, raycastResult, activeCast)
                            if activeCast then
                                activeCast.direction = direction
                            end
                            if oldOnHitCharacter then
                                return oldOnHitCharacter(hitChar, hitPart, raycastResult, activeCast)
                            end
                        end
                        return OldCast(origin, newDir, speed, maxDist, ignoreList, newCallbacks, ...)
                    end
                end
            end
            return OldCast(origin, direction, speed, maxDist, ignoreList, callbacks, ...)
        end
    end
end)

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
-- MAIN RENDER LOOP
-- ============================================
RunService.Heartbeat:Connect(function()
    State.CurrentTarget = getClosestPlayer()

    if State.CurrentTarget then
        State.CachedSilentTarget = State.CurrentTarget
    end

    if State.Aimbot_ShowFOV and (State.Aimbot_Mode ~= "Off" or State.SilentAim_Enabled) then
        FOVCircle.Visible = true
        local size = State.Aimbot_FOV * 2
        FOVCircle.Size = UDim2.fromOffset(size, size)
        FOVCircle.Position = UDim2.new(0.5, -size/2, 0.5, -size/2)
        if State.Aimbot_RainbowFOV then
            local hue = tick() % 5 / 5
            FOVStroke.Color = Color3.fromHSV(hue, 1, 1)
        else
            FOVStroke.Color = State.Aimbot_FOVColor
        end
    else
        FOVCircle.Visible = false
    end

    local aimbotActive = false
    if State.Aimbot_Mode == "Always" then
        aimbotActive = true
    elseif State.Aimbot_Mode == "Toggle (Press F)" then
        aimbotActive = State.Aimbot_ToggleActive
    elseif State.Aimbot_Mode == "Hold (Right Mouse)" then
        aimbotActive = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    if aimbotActive and State.CurrentTarget then
        local targetChar = State.CurrentTarget.Character
        if targetChar then
            local targetPart = targetChar:FindFirstChild(State.Aimbot_TargetPart)
            if not targetPart then targetPart = targetChar:FindFirstChild("Head") end
            if not targetPart then targetPart = targetChar:FindFirstChild("HumanoidRootPart") end

            if targetPart then
                local targetPos = targetPart.Position
                local camPos = Cam.CFrame.Position
                if (targetPos - camPos).Magnitude > 0.1 then
                    local targetCFrame = CFrame.lookAt(camPos, targetPos)
                    if State.Aimbot_Smooth == 0 then
                        Cam.CFrame = targetCFrame
                    else
                        local alpha = 1 / State.Aimbot_Smooth
                        Cam.CFrame = Cam.CFrame:Lerp(targetCFrame, alpha)
                    end
                end
            end
        end
    end

    if LP.Character then
        local hum = LP.Character:FindFirstChildOfClass("Humanoid")
        local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
        
        if hum and hrp then
            if State.Speed_Enabled then
                if hum.WalkSpeed ~= State.Speed_Amt then
                    hum.WalkSpeed = State.Speed_Amt
                end
            else
                if hum.WalkSpeed ~= 16 then
                    hum.WalkSpeed = 16
                end
            end

            if State.Fly_Enabled then
                if not hum.PlatformStand then hum.PlatformStand = true end
                local d = Vector3.new(0,0,0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + Cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - Cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - Cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + Cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then d = d - Vector3.new(0, 1, 0) end
                
                if d.Magnitude > 0 then
                    hrp.AssemblyLinearVelocity = d.Unit * State.Fly_Speed
                else
                    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                end
                hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + Cam.CFrame.LookVector)
            else
                if hum.PlatformStand then hum.PlatformStand = false end
            end
        end
    end

    if not State.ESP_Enabled then
        return
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LP then
            if not State.ESP_Objects[player] then
                createESP(player)
            end

            local obj = State.ESP_Objects[player]
            if player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                local head = player.Character:FindFirstChild("Head")
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                
                if hrp and head and hum then
                    local headScreen, onScreen = Cam:WorldToViewportPoint(head.Position)
                    
                    if onScreen then
                        local legScreen = Cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        local height = math.abs(headScreen.Y - legScreen.Y)
                        if height < 10 then
                            height = 10
                        end
                        local width = height / 2

                        if State.ESP_Rainbow then
                            local hue = tick() % 5 / 5
                            local color = Color3.fromHSV(hue, 1, 1)
                            obj.Box.UIStroke.Color = color
                            obj.Name.TextColor3 = color
                            obj.Tracer.BackgroundColor3 = color
                        else
                            obj.Box.UIStroke.Color = State.ESP_BoxColor
                            obj.Name.TextColor3 = State.ESP_NameColor
                            obj.Tracer.BackgroundColor3 = State.ESP_TracerColor
                        end

                        obj.Box.Position = UDim2.fromOffset(headScreen.X - width/2, headScreen.Y)
                        obj.Box.Size = UDim2.fromOffset(width, height)
                        obj.Box.Visible = State.ESP_Box

                        if State.ESP_HeadDot then
                            obj.HeadDot.Position = UDim2.fromOffset(headScreen.X, headScreen.Y)
                            obj.HeadDot.Visible = true
                        else
                            obj.HeadDot.Visible = false
                        end

                        if State.ESP_Name then
                            obj.Name.Position = UDim2.fromOffset(headScreen.X, headScreen.Y - 15)
                            obj.Name.Text = player.Name
                            obj.Name.Visible = true
                        else
                            obj.Name.Visible = false
                        end

                        if State.ESP_Distance then
                            local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                            local dist = 0
                            if myHrp then
                                dist = math.floor((myHrp.Position - hrp.Position).Magnitude)
                            end
                            obj.Dist.Position = UDim2.fromOffset(headScreen.X, headScreen.Y - 30)
                            obj.Dist.Text = dist .. "m"
                            obj.Dist.Visible = true
                        else
                            obj.Dist.Visible = false
                        end

                        if State.ESP_Health then
                            local hp = hum.Health / hum.MaxHealth
                            obj.HealthBg.Position = UDim2.fromOffset(headScreen.X - width/2 - 5, headScreen.Y)
                            obj.HealthBg.Size = UDim2.new(0, 3, 0, height)
                            obj.HealthFill.Size = UDim2.new(1, 0, hp, 0)
                            obj.HealthFill.BackgroundColor3 = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
                            obj.HealthBg.Visible = true
                        else
                            obj.HealthBg.Visible = false
                        end

                        if State.ESP_Tracers then
                            local p1 = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y)
                            local p2 = Vector2.new(headScreen.X, headScreen.Y)
                            drawLine(obj.Tracer, p1, p2)
                        else
                            obj.Tracer.Visible = false
                        end

                        if State.ESP_Skeleton then
                            for _, line in pairs(obj.Skeleton) do
                                line.Visible = false
                            end
                            
                            local bones = {
                                {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
                                {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
                                {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
                                {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
                                {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
                            }
                            
                            if not player.Character:FindFirstChild("UpperTorso") then
                                bones = {
                                    {"Head", "Torso"},
                                    {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
                                    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
                                }
                            end

                            local lineIdx = 1
                            for _, bone in pairs(bones) do
                                local part1 = player.Character:FindFirstChild(bone[1])
                                local part2 = player.Character:FindFirstChild(bone[2])
                                if part1 and part2 then
                                    local p1, on1 = Cam:WorldToViewportPoint(part1.Position)
                                    local p2, on2 = Cam:WorldToViewportPoint(part2.Position)
                                    if on1 and on2 and p1.Z > 0 and p2.Z > 0 then
                                        if obj.Skeleton[lineIdx] then
                                            drawLine(obj.Skeleton[lineIdx], Vector2.new(p1.X, p1.Y), Vector2.new(p2.X, p2.Y))
                                        end
                                    end
                                    lineIdx = lineIdx + 1
                                end
                            end
                        else
                            for _, line in pairs(obj.Skeleton) do
                                line.Visible = false
                            end
                        end
                    else
                        obj.Box.Visible = false
                        obj.Name.Visible = false
                        obj.Dist.Visible = false
                        obj.HealthBg.Visible = false
                        obj.Tracer.Visible = false
                        obj.HeadDot.Visible = false
                        for _, line in pairs(obj.Skeleton) do
                            line.Visible = false
                        end
                    end
                else
                    obj.Box.Visible = false
                    obj.Name.Visible = false
                    obj.Dist.Visible = false
                    obj.HealthBg.Visible = false
                    obj.Tracer.Visible = false
                    obj.HeadDot.Visible = false
                    for _, line in pairs(obj.Skeleton) do
                        line.Visible = false
                    end
                end
            else
                obj.Box.Visible = false
                obj.Name.Visible = false
                obj.Dist.Visible = false
                obj.HealthBg.Visible = false
                obj.Tracer.Visible = false
                obj.HeadDot.Visible = false
                for _, line in pairs(obj.Skeleton) do
                    line.Visible = false
                end
            end
        end
    end
end)

-- ============================================
-- UI SETUP
-- ============================================
local WindowConfig = {
    Name = "Ultimate Hub V10",
    LoadingTitle = "Ultimate Hub",
    LoadingSubtitle = "Advanced Edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
}
local Window = Rayfield:CreateWindow(WindowConfig)

local TabLocal = Window:CreateTab("Local", 4483362458)
local TabESP = Window:CreateTab("ESP", 4483362458)
local TabAimbot = Window:CreateTab("Aimbot", 4483362458)
local TabScanner = Window:CreateTab("Scanner", 4483362458)
local TabMisc = Window:CreateTab("Misc", 4483362458)

-- Local Tab
local FlyConfig = {
    Name = "Enable Fly",
    CurrentValue = false,
    Callback = function(Value) State.Fly_Enabled = Value end
}
TabLocal:CreateToggle(FlyConfig)

local FlySpeedConfig = {
    Name = "Fly Speed",
    Range = {10, 500},
    Increment = 1,
    CurrentValue = 50,
    Callback = function(Value) State.Fly_Speed = Value end
}
TabLocal:CreateSlider(FlySpeedConfig)

local SpeedConfig = {
    Name = "Enable Speed",
    CurrentValue = false,
    Callback = function(Value) State.Speed_Enabled = Value end
}
TabLocal:CreateToggle(SpeedConfig)

local SpeedAmtConfig = {
    Name = "Speed Amount",
    Range = {16, 500},
    Increment = 1,
    CurrentValue = 50,
    Callback = function(Value) State.Speed_Amt = Value end
}
TabLocal:CreateSlider(SpeedAmtConfig)

local InfJumpConfig = {
    Name = "Infinite Jump",
    CurrentValue = false,
    Callback = function(Value) State.InfJump_Enabled = Value end
}
TabLocal:CreateToggle(InfJumpConfig)

-- ESP Tab
local ESPEnableConfig = {
    Name = "Enable ESP",
    CurrentValue = false,
    Callback = function(Value) State.ESP_Enabled = Value end
}
TabESP:CreateToggle(ESPEnableConfig)

local ESPBoxConfig = {
    Name = "Box ESP",
    CurrentValue = true,
    Callback = function(Value) State.ESP_Box = Value end
}
TabESP:CreateToggle(ESPBoxConfig)

local ESPNameConfig = {
    Name = "Name ESP",
    CurrentValue = true,
    Callback = function(Value) State.ESP_Name = Value end
}
TabESP:CreateToggle(ESPNameConfig)

local ESPDistConfig = {
    Name = "Distance ESP",
    CurrentValue = true,
    Callback = function(Value) State.ESP_Distance = Value end
}
TabESP:CreateToggle(ESPDistConfig)

local ESPHealthConfig = {
    Name = "Health Bar ESP",
    CurrentValue = false,
    Callback = function(Value) State.ESP_Health = Value end
}
TabESP:CreateToggle(ESPHealthConfig)

local ESPTracerConfig = {
    Name = "Tracers",
    CurrentValue = false,
    Callback = function(Value) State.ESP_Tracers = Value end
}
TabESP:CreateToggle(ESPTracerConfig)

local ESPSkelConfig = {
    Name = "Skeleton ESP",
    CurrentValue = false,
    Callback = function(Value) State.ESP_Skeleton = Value end
}
TabESP:CreateToggle(ESPSkelConfig)

local ESPHeadDotConfig = {
    Name = "Head Dot",
    CurrentValue = false,
    Callback = function(Value) State.ESP_HeadDot = Value end
}
TabESP:CreateToggle(ESPHeadDotConfig)

local ESPRainbowConfig = {
    Name = "Rainbow ESP",
    CurrentValue = false,
    Callback = function(Value) State.ESP_Rainbow = Value end
}
TabESP:CreateToggle(ESPRainbowConfig)

local ESPBoxColorConfig = {
    Name = "Box Color",
    Color = Color3.fromRGB(255, 0, 0),
    Callback = function(Value) State.ESP_BoxColor = Value end
}
TabESP:CreateColorPicker(ESPBoxColorConfig)

local ESPNameColorConfig = {
    Name = "Name Color",
    Color = Color3.fromRGB(255, 255, 255),
    Callback = function(Value) State.ESP_NameColor = Value end
}
TabESP:CreateColorPicker(ESPNameColorConfig)

local ESPTracerColorConfig = {
    Name = "Tracer Color",
    Color = Color3.fromRGB(255, 255, 255),
    Callback = function(Value) State.ESP_TracerColor = Value end
}
TabESP:CreateColorPicker(ESPTracerColorConfig)

-- Aimbot Tab
local AimbotModeConfig = {
    Name = "Aimbot Mode",
    Options = {"Off", "Always", "Toggle (Press F)", "Hold (Right Mouse)"},
    CurrentOption = "Off",
    Callback = function(Value) State.Aimbot_Mode = Value end
}
TabAimbot:CreateDropdown(AimbotModeConfig)

local SilentAimConfig = {
    Name = "Enable Silent Aim (Universal + Game Specific)",
    CurrentValue = false,
    Callback = function(Value) State.SilentAim_Enabled = Value end
}
TabAimbot:CreateToggle(SilentAimConfig)

local AimbotTargetConfig = {
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "Torso", "UpperTorso"},
    CurrentOption = "Head",
    Callback = function(Value) State.Aimbot_TargetPart = Value end
}
TabAimbot:CreateDropdown(AimbotTargetConfig)

local AimbotFOVConfig = {
    Name = "Aimbot FOV",
    Range = {10, 500},
    Increment = 1,
    CurrentValue = 120,
    Callback = function(Value) State.Aimbot_FOV = Value end
}
TabAimbot:CreateSlider(AimbotFOVConfig)

local AimbotSmoothConfig = {
    Name = "Smoothness (0 = Instant, 1 = Fast, 20 = Smooth)",
    Range = {0, 20},
    Increment = 1,
    CurrentValue = 0,
    Callback = function(Value) State.Aimbot_Smooth = Value end
}
TabAimbot:CreateSlider(AimbotSmoothConfig)

local AimbotWallConfig = {
    Name = "Wall Check",
    CurrentValue = true,
    Callback = function(Value) State.Aimbot_WallCheck = Value end
}
TabAimbot:CreateToggle(AimbotWallConfig)

local AimbotTeamConfig = {
    Name = "Team Check",
    CurrentValue = true,
    Callback = function(Value) State.Aimbot_TeamCheck = Value end
}
TabAimbot:CreateToggle(AimbotTeamConfig)

local AimbotShowFOVConfig = {
    Name = "Show FOV Circle",
    CurrentValue = true,
    Callback = function(Value) State.Aimbot_ShowFOV = Value end
}
TabAimbot:CreateToggle(AimbotShowFOVConfig)

local AimbotRainbowFOVConfig = {
    Name = "Rainbow FOV",
    CurrentValue = false,
    Callback = function(Value) State.Aimbot_RainbowFOV = Value end
}
TabAimbot:CreateToggle(AimbotRainbowFOVConfig)

local AimbotFOVColorConfig = {
    Name = "FOV Circle Color",
    Color = Color3.fromRGB(255, 255, 255),
    Callback = function(Value) State.Aimbot_FOVColor = Value end
}
TabAimbot:CreateColorPicker(AimbotFOVColorConfig)

-- Scanner Tab
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
        end
    end
}
TabScanner:CreateButton(CopyAllConfig)

-- Misc Tab
local UnloadConfig = {
    Name = "Unload Script (Dead Switch)",
    Callback = function()
        pcall(function() RunService:UnbindFromRenderStep("UniversalHubLoop") end)
        for player, obj in pairs(State.ESP_Objects) do
            obj.Frame:Destroy()
        end
        State.ESP_Objects = {}
        if ESPGui then ESPGui:Destroy() end
        Rayfield:Destroy()
    end
}
TabMisc:CreateButton(UnloadConfig)

local NotifyConfig = {
    Title = "Ultimate Hub V10",
    Content = "Loaded successfully! Press RightCtrl to toggle UI.",
    Duration = 3
}
Rayfield:Notify(NotifyConfig)
