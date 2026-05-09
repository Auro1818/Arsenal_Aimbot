-- ============================================================
--  STEAL A BRAINROT - Teleport về Base
--  Đặt vào: ServerScriptService > Script
--
--  Workspace cần có:
--  Bases (Folder)
--  ├── Base1 (Model) → Platform (Part)
--  ├── Base2 (Model) → Platform (Part)
--  ├── Base3 (Model) → Platform (Part)
--  ├── Base4 (Model) → Platform (Part)
--  ├── Base5 (Model) → Platform (Part)
--  └── Base6 (Model) → Platform (Part)
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Tự tạo RemoteEvent
local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
    or Instance.new("Folder", ReplicatedStorage)
folder.Name = "RemoteEvents"

local AssignBase = folder:FindFirstChild("AssignBase")
    or Instance.new("RemoteEvent", folder)
AssignBase.Name = "AssignBase"

local ToggleSteal = folder:FindFirstChild("ToggleSteal")
    or Instance.new("RemoteEvent", folder)
ToggleSteal.Name = "ToggleSteal"

-- Tự tạo LocalScript GUI
local starterScripts = game:GetService("StarterPlayer").StarterPlayerScripts
if not starterScripts:FindFirstChild("BaseGUI") then
    local ls = Instance.new("LocalScript")
    ls.Name = "BaseGUI"
    ls.Source = [[
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("RemoteEvents")
local AssignBase = folder:WaitForChild("AssignBase")
local ToggleSteal = folder:WaitForChild("ToggleSteal")

local isOn = false

-- GUI
local sg = Instance.new("ScreenGui", player.PlayerGui)
sg.Name = "BaseGUI"
sg.ResetOnSpawn = false

local panel = Instance.new("Frame", sg)
panel.Size = UDim2.new(0, 220, 0, 120)
panel.Position = UDim2.new(0, 20, 0.5, -60)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke", panel)
stroke.Color = Color3.fromRGB(100, 100, 255)
stroke.Thickness = 2

local label = Instance.new("TextLabel", panel)
label.Size = UDim2.new(1, -20, 0, 35)
label.Position = UDim2.new(0, 10, 0, 8)
label.BackgroundTransparency = 1
label.Text = "📍 Base: Đang chờ..."
label.TextColor3 = Color3.fromRGB(180, 220, 255)
label.TextScaled = true
label.Font = Enum.Font.GothamBold

local btn = Instance.new("TextButton", panel)
btn.Size = UDim2.new(0.85, 0, 0, 50)
btn.Position = UDim2.new(0.075, 0, 0, 55)
btn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
btn.Text = "▶  BẬT - Về Base"
btn.TextColor3 = Color3.new(1,1,1)
btn.TextScaled = true
btn.Font = Enum.Font.GothamBold
btn.BorderSizePixel = 0
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

local function update()
    if isOn then
        btn.Text = "⏹  TẮT - Dừng"
        btn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        stroke.Color = Color3.fromRGB(255, 80, 80)
    else
        btn.Text = "▶  BẬT - Về Base"
        btn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        stroke.Color = Color3.fromRGB(100, 100, 255)
    end
end

btn.MouseButton1Click:Connect(function()
    isOn = not isOn
    ToggleSteal:FireServer(isOn)
    update()
    local d = TweenService:Create(btn, TweenInfo.new(0.08), {Size = UDim2.new(0.8,0,0,44)})
    d:Play()
    d.Completed:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), {Size = UDim2.new(0.85,0,0,50)}):Play()
    end)
end)

AssignBase.OnClientEvent:Connect(function(baseName)
    label.Text = "📍 Base của bạn: " .. baseName
end)
]]
    ls.Parent = starterScripts
end

-- ============================================================
-- SERVER LOGIC
-- ============================================================
local BasesFolder    = workspace:WaitForChild("Bases")
local availableBases = {"Base1","Base2","Base3","Base4","Base5","Base6"}
local assignedBases  = {}
local playerBases    = {}

local function teleportToBase(player)
    local baseName = playerBases[player]
    if not baseName then return end

    local model    = BasesFolder:FindFirstChild(baseName)
    if not model then return end

    local platform = model:FindFirstChild("Platform")
    if not platform then return end

    local char = player.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.CFrame = CFrame.new(platform.Position + Vector3.new(0, 5, 0))
end

Players.PlayerAdded:Connect(function(player)
    for _, baseName in ipairs(availableBases) do
        if not assignedBases[baseName] then
            assignedBases[baseName] = player
            playerBases[player]     = baseName
            task.wait(2)
            AssignBase:FireClient(player, baseName)
            print(player.Name .. " → " .. baseName)
            break
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local base = playerBases[player]
    if base then assignedBases[base] = nil end
    playerBases[player] = nil
end)

ToggleSteal.OnServerEvent:Connect(function(player, isOn)
    if isOn then
        teleportToBase(player)
    end
end)

print("✅ Steal a Brainrot - Script chạy!")
