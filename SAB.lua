-- ============================================
-- 🧠 STEAL A BRAINROT - DELTA iOS SCRIPT v3.0
-- Anti-Cheat + Anti-TP Advanced Bypass
-- Loadstring Version
-- ============================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- ============================================
-- ⚙️ SETTINGS
-- ============================================

local Settings = {
    InstantSteal = false,
    Speed = false,
    MapESP = false,
    BaseESP = false,
    SpeedValue = 16,
    DrawDistance = 999999,
}

-- ============================================
-- 🛡️ ANTI-CHEAT BYPASS
-- ============================================

local function DisableAntiCheatDetection()
    local function BlockDetection()
        pcall(function()
            for _, v in pairs(Workspace:GetDescendants()) do
                if v:IsA("LocalScript") or v:IsA("Script") then
                    if v.Name:lower():find("anticheat") or v.Name:lower():find("anti") or v.Name:lower():find("detect") then
                        v.Disabled = true
                    end
                end
            end
        end)
    end
    RunService.Heartbeat:Connect(BlockDetection)
end

-- ============================================
-- ⚡ ADVANCED TELEPORT BYPASS (3 METHODS)
-- ============================================

local TPMethod = 1

local function AdvancedTeleport(targetPos, smooth)
    if not Character or not HumanoidRootPart then return end
    smooth = smooth or true
    local startPos = HumanoidRootPart.Position
    local distance = (startPos - targetPos).Magnitude
    
    local function MethodVelocity()
        pcall(function()
            if not HumanoidRootPart then return end
            local BV = Instance.new("BodyVelocity")
            BV.Velocity = (targetPos - HumanoidRootPart.Position).Unit * 200
            BV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            BV.Parent = HumanoidRootPart
            wait(0.05)
            BV:Destroy()
            HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        end)
    end
    
    local function MethodMoveTo()
        pcall(function()
            if not Character or not Character:FindFirstChild("Humanoid") then return end
            local Humanoid = Character.Humanoid
            local steps = smooth and math.ceil(distance / 15) or 1
            for i = 1, steps do
                if not HumanoidRootPart then break end
                local newPos = startPos:Lerp(targetPos, i / steps)
                Humanoid:MoveTo(newPos)
                HumanoidRootPart.CFrame = CFrame.new(newPos)
                wait(0.03)
            end
            HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        end)
    end
    
    local function MethodCFrame()
        pcall(function()
            if not HumanoidRootPart then return end
            local originalCanCollide = HumanoidRootPart.CanCollide
            HumanoidRootPart.CanCollide = false
            if smooth then
                for i = 0, 1, 0.05 do
                    if not HumanoidRootPart then break end
                    HumanoidRootPart.CFrame = CFrame.new(startPos:Lerp(targetPos, i))
                    wait(0.02)
                end
            end
            HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            wait(0.05)
            HumanoidRootPart.CanCollide = originalCanCollide
        end)
    end
    
    if TPMethod == 1 then
        MethodVelocity()
    elseif TPMethod == 2 then
        MethodMoveTo()
    else
        MethodCFrame()
    end
    TPMethod = TPMethod % 3 + 1
end

-- ============================================
-- 🎨 GUI SETUP
-- ============================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "StealABrainrotMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Toggle Button
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(0, 50, 0, 50)
ToggleButton.Position = UDim2.new(0, 10, 0, 10)
ToggleButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 20
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "☰"
ToggleButton.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 10)
ToggleCorner.Parent = ToggleButton

-- Main Menu
local MenuFrame = Instance.new("Frame")
MenuFrame.Name = "MenuFrame"
MenuFrame.Size = UDim2.new(0, 280, 0, 280)
MenuFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
MenuFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MenuFrame.BorderSizePixel = 0
MenuFrame.Visible = false
MenuFrame.Parent = ScreenGui

local MenuCorner = Instance.new("UICorner")
MenuCorner.CornerRadius = UDim.new(0, 15)
MenuCorner.Parent = MenuFrame

-- Title
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(1, 0, 0, 40)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
TitleLabel.TextColor3 = Color3.fromRGB(200, 100, 255)
TitleLabel.TextSize = 16
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "🧠 MRLD Insta Stealer"
TitleLabel.Parent = MenuFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 15)
TitleCorner.Parent = TitleLabel

-- Create Button Function
local function CreateButton(name, text, position)
    local Button = Instance.new("TextButton")
    Button.Name = name
    Button.Size = UDim2.new(0.9, 0, 0, 45)
    Button.Position = UDim2.new(0.05, 0, position, 0)
    Button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Button.TextColor3 = Color3.fromRGB(180, 100, 255)
    Button.TextSize = 14
    Button.Font = Enum.Font.Gotham
    Button.Text = text
    Button.Parent = MenuFrame
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 10)
    ButtonCorner.Parent = Button
    return Button
end

local InstantStealButton = CreateButton("InstantSteal", "Instant steal (ON)", 0.15)
local SpeedButton = CreateButton("Speed", "Speed (Off)", 0.35)
local MapESPButton = CreateButton("MapESP", "Map ESP (ON)", 0.55)
local BaseESPButton = CreateButton("BaseESP", "My Base ESP (ON)", 0.75)

local DiscordLabel = Instance.new("TextLabel")
DiscordLabel.Size = UDim2.new(1, 0, 0, 30)
DiscordLabel.Position = UDim2.new(0, 0, 0.95, 0)
DiscordLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
DiscordLabel.TextColor3 = Color3.fromRGB(100, 150, 255)
DiscordLabel.TextSize = 11
DiscordLabel.Font = Enum.Font.Gotham
DiscordLabel.Text = "discord.gg/2yYuqnxbzu"
DiscordLabel.Parent = MenuFrame

-- ============================================
-- 🔄 BUTTON EVENTS
-- ============================================

ToggleButton.MouseButton1Click:Connect(function()
    MenuFrame.Visible = not MenuFrame.Visible
    ToggleButton.BackgroundColor3 = MenuFrame.Visible and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(100, 100, 255)
end)

InstantStealButton.MouseButton1Click:Connect(function()
    Settings.InstantSteal = not Settings.InstantSteal
    InstantStealButton.TextColor3 = Settings.InstantSteal and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(180, 100, 255)
    InstantStealButton.Text = Settings.InstantSteal and "Instant steal (ON)" or "Instant steal (OFF)"
end)

SpeedButton.MouseButton1Click:Connect(function()
    Settings.Speed = not Settings.Speed
    SpeedButton.TextColor3 = Settings.Speed and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(180, 100, 255)
    SpeedButton.Text = Settings.Speed and "Speed (On)" or "Speed (Off)"
end)

MapESPButton.MouseButton1Click:Connect(function()
    Settings.MapESP = not Settings.MapESP
    MapESPButton.TextColor3 = Settings.MapESP and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(180, 100, 255)
    MapESPButton.Text = Settings.MapESP and "Map ESP (ON)" or "Map ESP (OFF)"
end)

BaseESPButton.MouseButton1Click:Connect(function()
    Settings.BaseESP = not Settings.BaseESP
    BaseESPButton.TextColor3 = Settings.BaseESP and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(180, 100, 255)
    BaseESPButton.Text = Settings.BaseESP and "My Base ESP (ON)" or "My Base ESP (OFF)"
end)

-- ============================================
-- 🧠 FIND MY BASE
-- ============================================

local function FindMyBase()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("base") and obj:FindFirstChild("Humanoid") == nil then
            if obj.Name:lower():find("my") then
                return obj
            end
        end
    end
    return nil
end

-- ============================================
-- 🧠 DETECT BRAINROT IN HAND
-- ============================================

local function IsBrainrotInHand()
    if not Character then return false end
    for _, v in pairs(Character:GetChildren()) do
        if v:IsA("Model") and (v.Name:lower():find("brainrot") or v.Name:lower():find("meowl") or 
            v.Name:lower():find("elephant") or v.Name:lower():find("divine")) then
            return true, v
        end
    end
    return false, nil
end

-- ============================================
-- ⚡ INSTANT STEAL
-- ============================================

local LastStealTime = 0
local StealCooldown = 1

local function InstantSteal()
    if not Settings.InstantSteal then return end
    local currentTime = tick()
    if currentTime - LastStealTime < StealCooldown then return end
    
    local hasBrainrot, brainrot = IsBrainrotInHand()
    if not hasBrainrot then return end
    
    local myBase = FindMyBase()
    if not myBase then return end
    
    local basePos = myBase:FindFirstChild("HumanoidRootPart") and myBase.HumanoidRootPart.Position or 
                    (myBase.PrimaryPart and myBase.PrimaryPart.Position) or myBase.Position
    
    LastStealTime = currentTime
    TitleLabel.Text = "🧠 Stealing..."
    TitleLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    AdvancedTeleport(basePos + Vector3.new(0, 5, 0), true)
    wait(0.5)
    TitleLabel.Text = "🧠 MRLD Insta Stealer"
    TitleLabel.TextColor3 = Color3.fromRGB(200, 100, 255)
end

-- ============================================
-- ⚡ SPEED RESTORE
-- ============================================

local function SpeedRestore()
    if not Settings.Speed or not Character or not Character:FindFirstChild("Humanoid") then return end
    local Humanoid = Character.Humanoid
    if Humanoid.WalkSpeed < Settings.SpeedValue then
        Humanoid.WalkSpeed = Settings.SpeedValue
    end
end

-- ============================================
-- 👁️ ESP BOXES
-- ============================================

local ESPBoxes = {}

local function FindMostExpensiveBrainrot()
    local maxPrice = 0
    local mostExpensive = nil
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:lower():find("brainrot") or obj.Name:lower():find("meowl") or 
            obj.Name:lower():find("elephant") or obj.Name:lower():find("divine")) then
            local priceStr = obj.Name:match("$([0-9.]+)")
            if priceStr then
                local price = tonumber(priceStr) or 0
                if price > maxPrice then
                    maxPrice = price
                    mostExpensive = obj
                end
            end
        end
    end
    return mostExpensive
end

local function DrawESP()
    for _, box in pairs(ESPBoxes) do
        pcall(function() box:Destroy() end)
    end
    ESPBoxes = {}
    
    if Settings.MapESP then
        local mostExp = FindMostExpensiveBrainrot()
        if mostExp and mostExp:FindFirstChild("PrimaryPart") and mostExp.PrimaryPart then
            local pos = mostExp.PrimaryPart.Position
            local dist = (HumanoidRootPart.Position - pos).Magnitude
            if dist < Settings.DrawDistance then
                local box = Instance.new("Part")
                box.Shape = Enum.PartType.Block
                box.Size = Vector3.new(3, 3, 3)
                box.CanCollide = false
                box.CFrame = CFrame.new(pos)
                box.Color = Color3.fromRGB(0, 255, 100)
                box.Transparency = 0.5
                box.Parent = Workspace
                table.insert(ESPBoxes, box)
            end
        end
    end
    
    if Settings.BaseESP then
        local myBase = FindMyBase()
        if myBase and myBase:FindFirstChild("PrimaryPart") and myBase.PrimaryPart then
            local pos = myBase.PrimaryPart.Position
            local dist = (HumanoidRootPart.Position - pos).Magnitude
            if dist < Settings.DrawDistance then
                local box = Instance.new("Part")
                box.Shape = Enum.PartType.Block
                box.Size = Vector3.new(6, 6, 6)
                box.CanCollide = false
                box.CFrame = CFrame.new(pos)
                box.Color = Color3.fromRGB(0, 200, 255)
                box.Transparency = 0.6
                box.Parent = Workspace
                table.insert(ESPBoxes, box)
            end
        end
    end
end

-- ============================================
-- 🔄 MAIN LOOP
-- ============================================

RunService.Heartbeat:Connect(function()
    if Character and HumanoidRootPart then
        if Settings.Speed then SpeedRestore() end
        if Settings.InstantSteal then InstantSteal() end
        if Settings.MapESP or Settings.BaseESP then DrawESP() end
    end
end)

-- ============================================
-- 🔄 CHARACTER RESPAWN
-- ============================================

LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
end)

-- ============================================
-- 🛡️ ACTIVATE ANTI-CHEAT BYPASS
-- ============================================

DisableAntiCheatDetection()

print("✅ Steal A Brainrot Script v3.0 Loaded!")
print("📌 Click ☰ button to toggle menu")
print("🛡️ Anti-Cheat + Anti-TP Bypass Active!")
