--!strict
--[[
    Aim Assist + ESP Test Harness V7.2
    Roblox Studio / Own Experience Testing
    Roblox Studio APIs only

    V7.2
    • Persistent floating GUI open/close button
    • RightShift menu toggle retained
    • Compact ESP typography
    • Distance-based ESP text scaling
    • Shorter Name / Distance / Health text
    • Thin Skeleton renderer for R6 + R15
    • White Skeleton + dark outline
    • White Tracer + dark outline
    • Better ESP box contrast
    • No temporary Model creation during ESP updates
    • Reset Defaults refreshes GUI controls
    • FIXED: Toggle buttons update ON/OFF immediately
    • FIXED: Reset Defaults refreshes every toggle/cycle/slider
    • AIM / ESP / SETTINGS / DEBUG retained
    • Smoothness default 0.18
    • PredictionTime default 0.12s
    • Multi-point visibility
    • Visibility grace / reacquisition
    • Better tight-space targeting
    • ESP wall check
    • Proper player cleanup
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- =========================================================
-- CONFIG
-- =========================================================

local Config: {[string]: any} = {
    AimEnabled = false,

    AimToggleKey = Enum.KeyCode.E,
    MenuToggleKey = Enum.KeyCode.RightShift,

    RequireAimKey = false,
    AimKey = Enum.UserInputType.MouseButton2,

    AimMode = "Smooth",
    TargetPriority = "Crosshair",
    AimPart = "Auto",
    TeamFilter = "Enemy",

    FOV = 55,
    Smoothness = 0.18,
    MaxDistance = 500,

    PredictionEnabled = true,
    PredictionTime = 0.08,
    MaxPredictionOffset = 10,

    VisibilityCheck = true,
    MultiPointVisibility = true,
    VisibilityGraceTime = 0.16,
    TargetSwitchDelay = 0.10,

    ESPEnabled = true,
    ESPBox = true,
    ESPName = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPTracer = false,
    ESPSkeleton = false,

    ESPTeamFilter = "Enemy",
    ESPAliveOnly = true,
    ESPWallCheck = false,
    ESPMaxDistance = 1000,

    ESPTextScale = 0.80,

    FOVVisible = true,
    Debug = false,
}

local DEFAULTS: {[string]: any} = table.clone(Config)

-- =========================================================
-- COLORS
-- =========================================================

local ESP_MAIN_COLOR = Color3.fromRGB(255, 255, 255)
local ESP_OUTLINE_COLOR = Color3.fromRGB(15, 15, 15)

-- =========================================================
-- CAMERA
-- =========================================================

local Camera = Workspace.CurrentCamera

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

-- =========================================================
-- HELPERS
-- =========================================================

local function characterOf(player: Player): Model?
    local character = player.Character

    if character and character.Parent then
        return character
    end

    return nil
end

local function humanoidOf(character: Model): Humanoid?
    return character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(character: Model): BasePart?
    local root = character:FindFirstChild("HumanoidRootPart")

    if root and root:IsA("BasePart") then
        return root
    end

    return nil
end

local function headOf(character: Model): BasePart?
    local head = character:FindFirstChild("Head")

    if head and head:IsA("BasePart") then
        return head
    end

    return nil
end

local function bodyPartOf(character: Model): BasePart?
    local names = {
        "UpperTorso",
        "Torso",
        "HumanoidRootPart",
    }

    for _, name in ipairs(names) do
        local part = character:FindFirstChild(name)

        if part and part:IsA("BasePart") then
            return part
        end
    end

    return nil
end

local function alive(player: Player): boolean
    local character = characterOf(player)

    if not character then
        return false
    end

    local humanoid = humanoidOf(character)

    return humanoid ~= nil and humanoid.Health > 0
end

local function teamAllowed(
    player: Player,
    mode: string
): boolean

    if player == LocalPlayer then
        return false
    end

    if mode == "All" then
        return true
    end

    if mode == "Enemy" then
        if LocalPlayer.Team == nil
            or player.Team == nil then
            return true
        end

        return player.Team ~= LocalPlayer.Team
    end

    if mode == "Same Team" then
        if LocalPlayer.Team == nil
            or player.Team == nil then
            return false
        end

        return player.Team == LocalPlayer.Team
    end

    return true
end

local function distanceTo(player: Player): number?
    local myCharacter = characterOf(LocalPlayer)
    local targetCharacter = characterOf(player)

    if not myCharacter or not targetCharacter then
        return nil
    end

    local myRoot = rootOf(myCharacter)
    local targetRoot = rootOf(targetCharacter)

    if not myRoot or not targetRoot then
        return nil
    end

    return (
        targetRoot.Position
        - myRoot.Position
    ).Magnitude
end

local function screenDistance(
    worldPosition: Vector3
): (number, boolean, Vector3)

    if not Camera then
        return math.huge, false, Vector3.zero
    end

    local point, visible =
        Camera:WorldToViewportPoint(worldPosition)

    local center = Vector2.new(
        Camera.ViewportSize.X / 2,
        Camera.ViewportSize.Y / 2
    )

    local screenPoint = Vector2.new(
        point.X,
        point.Y
    )

    return (
        screenPoint - center
    ).Magnitude,
    (
        visible
        and point.Z > 0
    ),
    point
end

-- =========================================================
-- VISIBILITY
-- =========================================================

local function makeRayParams(
    targetCharacter: Model
): RaycastParams

    local params = RaycastParams.new()

    params.FilterType =
        Enum.RaycastFilterType.Exclude

    params.IgnoreWater = true

    local exclude: {Instance} = {}

    local myCharacter =
        characterOf(LocalPlayer)

    if myCharacter then
        table.insert(
            exclude,
            myCharacter
        )
    end

    table.insert(
        exclude,
        targetCharacter
    )

    params.FilterDescendantsInstances =
        exclude

    return params
end

local function rayVisible(
    targetCharacter: Model,
    origin: Vector3,
    targetPoint: Vector3,
    forceCheck: boolean?
): boolean

    if not Config.VisibilityCheck
        and not forceCheck then
        return true
    end

    local direction =
        targetPoint - origin

    if direction.Magnitude <= 0.01 then
        return true
    end

    local params =
        makeRayParams(targetCharacter)

    local currentOrigin = origin
    local remaining = direction

    for _ = 1, 8 do

        local result =
            Workspace:Raycast(
                currentOrigin,
                remaining,
                params
            )

        if not result then
            return true
        end

        local hit = result.Instance

        if hit:IsA("BasePart")
            and not hit.CanCollide then

            currentOrigin =
                result.Position
                + remaining.Unit * 0.02

            remaining =
                targetPoint
                - currentOrigin

            if remaining.Magnitude <= 0.02 then
                return true
            end

        else
            return false
        end
    end

    return false
end

local function samples(
    part: BasePart
): {Vector3}

    local cf = part.CFrame
    local half = part.Size * 0.5

    local points = {
        cf.Position,

        cf:PointToWorldSpace(
            Vector3.new(
                half.X * 0.85,
                0,
                0
            )
        ),

        cf:PointToWorldSpace(
            Vector3.new(
                -half.X * 0.85,
                0,
                0
            )
        ),

        cf:PointToWorldSpace(
            Vector3.new(
                0,
                half.Y * 0.85,
                0
            )
        ),

        cf:PointToWorldSpace(
            Vector3.new(
                0,
                -half.Y * 0.85,
                0
            )
        ),

        cf:PointToWorldSpace(
            Vector3.new(
                0,
                0,
                half.Z * 0.85
            )
        ),

        cf:PointToWorldSpace(
            Vector3.new(
                0,
                0,
                -half.Z * 0.85
            )
        ),
    }

    if Config.MultiPointVisibility then

        table.insert(
            points,
            cf:PointToWorldSpace(
                Vector3.new(
                    half.X * 0.65,
                    half.Y * 0.65,
                    0
                )
            )
        )

        table.insert(
            points,
            cf:PointToWorldSpace(
                Vector3.new(
                    -half.X * 0.65,
                    half.Y * 0.65,
                    0
                )
            )
        )

        table.insert(
            points,
            cf:PointToWorldSpace(
                Vector3.new(
                    half.X * 0.65,
                    -half.Y * 0.65,
                    0
                )
            )
        )

        table.insert(
            points,
            cf:PointToWorldSpace(
                Vector3.new(
                    -half.X * 0.65,
                    -half.Y * 0.65,
                    0
                )
            )
        )
    end

    return points
end

local function bestPointOnPart(
    targetCharacter: Model,
    part: BasePart
): (Vector3?, number)

    local best: Vector3? = nil
    local bestScore = math.huge

    if not Camera then
        return nil, math.huge
    end

    for _, point in ipairs(
        samples(part)
    ) do

        local d, onScreen =
            screenDistance(point)

        if onScreen
            and d <= Config.FOV then

            if rayVisible(
                targetCharacter,
                Camera.CFrame.Position,
                point
            ) then

                if d < bestScore then
                    best = point
                    bestScore = d
                end
            end
        end
    end

    return best, bestScore
end

local function bestAimPoint(
    player: Player
): (Vector3?, BasePart?, number)

    local character =
        characterOf(player)

    if not character then
        return nil, nil, math.huge
    end

    local head =
        headOf(character)

    local body =
        bodyPartOf(character)

    local function inspect(
        part: BasePart?
    ): (Vector3?, BasePart?, number)

        if not part then
            return nil, nil, math.huge
        end

        local point, score =
            bestPointOnPart(
                character,
                part
            )

        return point, part, score
    end

    if Config.AimPart == "Head" then
        return inspect(head)
    end

    if Config.AimPart == "Body" then
        return inspect(body)
    end

    local hp, hpart, hs =
        inspect(head)

    local bp, bpart, bs =
        inspect(body)

    if hp
        and (
            not bp
            or hs <= bs + 35
        ) then

        return hp, hpart, hs
    end

    return bp, bpart, bs
end

-- =========================================================
-- TARGETING
-- =========================================================

type TargetState = {
    player: Player?,
    point: Vector3?,
    lastVisibleAt: number,
    nextSwitchAt: number,
}

local targetState: TargetState = {
    player = nil,
    point = nil,
    lastVisibleAt = 0,
    nextSwitchAt = 0,
}

local function validTarget(
    player: Player
): boolean

    if player == LocalPlayer then
        return false
    end

    if not alive(player) then
        return false
    end

    if not teamAllowed(
        player,
        Config.TeamFilter
    ) then
        return false
    end

    local distance =
        distanceTo(player)

    if not distance then
        return false
    end

    if distance > Config.MaxDistance then
        return false
    end

    return true
end

local function targetScore(
    player: Player
): number

    local _, _, crosshairScore =
        bestAimPoint(player)

    if Config.TargetPriority
        == "Crosshair" then

        return crosshairScore
    end

    if Config.TargetPriority
        == "Closest" then

        return distanceTo(player)
            or math.huge
    end

    if Config.TargetPriority
        == "Lowest Health" then

        local character =
            characterOf(player)

        local humanoid =
            character
            and humanoidOf(character)

        return humanoid
            and humanoid.Health
            or math.huge
    end

    return crosshairScore
end

local function findTarget():
    (Player?, Vector3?)

    local bestPlayer: Player? = nil
    local bestPoint: Vector3? = nil
    local bestScore = math.huge

    for _, player in ipairs(
        Players:GetPlayers()
    ) do

        if validTarget(player) then

            local point =
                bestAimPoint(player)

            if point then

                local score =
                    targetScore(player)

                if score < bestScore then
                    bestScore = score
                    bestPlayer = player
                    bestPoint = point
                end
            end
        end
    end

    return bestPlayer, bestPoint
end

local function currentTargetStillGood():
    (boolean, Vector3?)

    local player =
        targetState.player

    if not player
        or not validTarget(player) then

        return false, nil
    end

    local point =
        bestAimPoint(player)

    if point then

        targetState.lastVisibleAt =
            os.clock()

        targetState.point =
            point

        return true, point
    end

    if targetState.point then

        if (
            os.clock()
            - targetState.lastVisibleAt
        ) <= Config.VisibilityGraceTime then

            return true,
            targetState.point
        end
    end

    return false, nil
end

local function updateTarget():
    (Player?, Vector3?)

    local now = os.clock()

    if targetState.player then

        local good, point =
            currentTargetStillGood()

        if good then
            return targetState.player, point
        end

        if now < targetState.nextSwitchAt then
            return nil, nil
        end

        targetState.player = nil
        targetState.point = nil
    end

    if now < targetState.nextSwitchAt then
        return nil, nil
    end

    local player, point =
        findTarget()

    if player then

        targetState.player =
            player

        targetState.point =
            point

        targetState.lastVisibleAt =
            now

        targetState.nextSwitchAt =
            now + Config.TargetSwitchDelay
    end

    return player, point
end

local function predictedPoint(
    point: Vector3,
    targetPlayer: Player
): Vector3

    if not Config.PredictionEnabled then
        return point
    end

    local character =
        characterOf(targetPlayer)

    local root =
        character
        and rootOf(character)

    if not root then
        return point
    end

    local offset =
        root.AssemblyLinearVelocity
        * Config.PredictionTime

    local maxOffset =
        Config.MaxPredictionOffset

    if offset.Magnitude > maxOffset then

        offset =
            offset.Unit
            * maxOffset
    end

    return point + offset
end

local function aimAt(
    worldPosition: Vector3
)

    if not Camera then
        return
    end

    local desired =
        CFrame.lookAt(
            Camera.CFrame.Position,
            worldPosition
        )

    if Config.AimMode == "Snap" then

        Camera.CFrame =
            desired

    else

        local alpha =
            math.clamp(
                Config.Smoothness,
                0.01,
                1
            )

        Camera.CFrame =
            Camera.CFrame:Lerp(
                desired,
                alpha
            )
    end
end

local function aimKeyHeld(): boolean

    if not Config.RequireAimKey then
        return true
    end

    return UserInputService:IsMouseButtonPressed(
        Config.AimKey
    )
end

-- =========================================================
-- GUI
-- =========================================================

local oldGui =
    PlayerGui:FindFirstChild(
        "AimAssistESP_TestHarness_V72"
    )

if oldGui then
    oldGui:Destroy()
end

local gui =
    Instance.new("ScreenGui")

gui.Name =
    "AimAssistESP_TestHarness_V72"

gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = PlayerGui

-- =========================================================
-- FOV
-- =========================================================

local fovCircle =
    Instance.new("Frame")

fovCircle.Name =
    "FOVCircle"

fovCircle.AnchorPoint =
    Vector2.new(0.5, 0.5)

fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0

fovCircle.Size =
    UDim2.fromOffset(
        Config.FOV * 2,
        Config.FOV * 2
    )

fovCircle.Position =
    UDim2.fromScale(
        0.5,
        0.5
    )

fovCircle.Parent = gui

local fovStroke =
    Instance.new("UIStroke")

fovStroke.Thickness = 1
fovStroke.Color =
    ESP_MAIN_COLOR

fovStroke.Parent =
    fovCircle

local fovCorner =
    Instance.new("UICorner")

fovCorner.CornerRadius =
    UDim.new(1, 0)

fovCorner.Parent =
    fovCircle

-- =========================================================
-- MENU
-- =========================================================

local menu =
    Instance.new("Frame")

menu.Name = "Menu"

menu.Size =
    UDim2.fromOffset(
        620,
        430
    )

menu.Position =
    UDim2.fromScale(
        0.5,
        0.5
    )

menu.AnchorPoint =
    Vector2.new(0.5, 0.5)

menu.BackgroundTransparency = 0.08
menu.BorderSizePixel = 0
menu.Visible = true
menu.Parent = gui

local menuCorner =
    Instance.new("UICorner")

menuCorner.CornerRadius =
    UDim.new(0, 10)

menuCorner.Parent =
    menu

local title =
    Instance.new("TextLabel")

title.Size =
    UDim2.new(
        1,
        -65,
        0,
        42
    )

title.Position =
    UDim2.fromOffset(
        15,
        4
    )

title.BackgroundTransparency = 1

title.Text =
    "Aim Assist + ESP Test Harness V7.2"

title.TextSize = 18

title.TextXAlignment =
    Enum.TextXAlignment.Left

title.Parent = menu

local close =
    Instance.new("TextButton")

close.Size =
    UDim2.fromOffset(
        38,
        32
    )

close.Position =
    UDim2.new(
        1,
        -45,
        0,
        8
    )

close.Text = "×"
close.TextSize = 22

close.Parent = menu

close.Activated:Connect(function()
    menu.Visible = false
end)

-- =========================================================
-- FLOATING OPEN BUTTON
-- =========================================================

local openButton =
    Instance.new("TextButton")

openButton.Name =
    "OpenGUI"

openButton.AnchorPoint =
    Vector2.new(1, 1)

openButton.Position =
    UDim2.new(
        1,
        -18,
        1,
        -18
    )

openButton.Size =
    UDim2.fromOffset(
        48,
        48
    )

openButton.BackgroundTransparency =
    0.08

openButton.Text = "☰"
openButton.TextSize = 20

openButton.Font =
    Enum.Font.GothamBold

openButton.AutoButtonColor = true
openButton.ZIndex = 200
openButton.Parent = gui

local openCorner =
    Instance.new("UICorner")

openCorner.CornerRadius =
    UDim.new(1, 0)

openCorner.Parent =
    openButton

local openStroke =
    Instance.new("UIStroke")

openStroke.Thickness = 1
openStroke.Color =
    ESP_OUTLINE_COLOR

openStroke.Parent =
    openButton

openButton.Activated:Connect(function()
    menu.Visible =
        not menu.Visible
end)

-- =========================================================
-- TABS
-- =========================================================

local tabs =
    Instance.new("Frame")

tabs.Size =
    UDim2.new(
        1,
        -20,
        0,
        36
    )

tabs.Position =
    UDim2.fromOffset(
        10,
        48
    )

tabs.BackgroundTransparency = 1
tabs.Parent = menu

local content =
    Instance.new("Frame")

content.Size =
    UDim2.new(
        1,
        -20,
        1,
        -92
    )

content.Position =
    UDim2.fromOffset(
        10,
        88
    )

content.BackgroundTransparency = 1
content.Parent = menu

local pages: {[string]: Frame} = {}

local function makePage(
    name: string
): Frame

    local page =
        Instance.new("Frame")

    page.Name = name

    page.Size =
        UDim2.fromScale(
            1,
            1
        )

    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = content

    pages[name] = page

    return page
end

local aimPage =
    makePage("AIM")

local espPage =
    makePage("ESP")

local settingsPage =
    makePage("SETTINGS")

local debugPage =
    makePage("DEBUG")

local currentTab = "AIM"

local function showPage(
    name: string
)

    currentTab = name

    for pageName, page in pairs(
        pages
    ) do

        page.Visible =
            pageName == name
    end
end

local tabNames = {
    "AIM",
    "ESP",
    "SETTINGS",
    "DEBUG",
}

for index, name in ipairs(
    tabNames
) do

    local button =
        Instance.new("TextButton")

    button.Size =
        UDim2.fromOffset(
            140,
            32
        )

    button.Position =
        UDim2.fromOffset(
            (index - 1) * 150,
            0
        )

    button.Text = name
    button.TextSize = 14
    button.Parent = tabs

    button.Activated:Connect(function()
        showPage(name)
    end)
end

showPage("AIM")

-- =========================================================
-- GUI CONTROL SYSTEM
-- =========================================================

local function makeLabel(
    parent: Instance,
    text: string,
    x: number,
    y: number
): TextLabel

    local l =
        Instance.new("TextLabel")

    l.Size =
        UDim2.fromOffset(
            280,
            28
        )

    l.Position =
        UDim2.fromOffset(
            x,
            y
        )

    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = 14

    l.TextXAlignment =
        Enum.TextXAlignment.Left

    l.Parent = parent

    return l
end

type RefreshFunction = () -> ()

local refreshFunctions:
    {RefreshFunction} = {}

local function buttonControl(
    parent: Instance,
    text: string,
    x: number,
    y: number,
    callback: () -> ()
): TextButton

    local b =
        Instance.new("TextButton")

    b.Size =
        UDim2.fromOffset(
            270,
            30
        )

    b.Position =
        UDim2.fromOffset(
            x,
            y
        )

    b.Text = text
    b.TextSize = 13
    b.Parent = parent

    b.Activated:Connect(callback)

    return b
end

-- =========================================================
-- FIXED TOGGLE CONTROL
-- =========================================================

local function toggleControl(
    parent: Instance,
    key: string,
    text: string,
    x: number,
    y: number
): TextButton

    local b: TextButton

    local function refresh()

        local enabled =
            Config[key] == true

        b.Text =
            string.format(
                "%s: %s",
                text,
                enabled
                    and "ON"
                    or "OFF"
            )
    end

    b =
        buttonControl(
            parent,
            "",
            x,
            y,
            function()

                Config[key] =
                    not (
                        Config[key] == true
                    )

                -- FIX:
                -- Refresh immediately after clicking.
                refresh()
            end
        )

    table.insert(
        refreshFunctions,
        refresh
    )

    refresh()

    return b
end

-- =========================================================
-- CYCLE CONTROL
-- =========================================================

local function cycleControl(
    parent: Instance,
    key: string,
    text: string,
    values: {string},
    x: number,
    y: number
): TextButton

    local b: TextButton

    local function refresh()

        b.Text =
            string.format(
                "%s: %s",
                text,
                tostring(
                    Config[key]
                )
            )
    end

    b =
        buttonControl(
            parent,
            "",
            x,
            y,
            function()

                local current =
                    tostring(
                        Config[key]
                    )

                local index =
                    table.find(
                        values,
                        current
                    )
                    or 1

                index += 1

                if index > #values then
                    index = 1
                end

                Config[key] =
                    values[index]

                refresh()
            end
        )

    table.insert(
        refreshFunctions,
        refresh
    )

    refresh()

    return b
end

-- =========================================================
-- SLIDER
-- =========================================================

type SliderData = {
    key: string,
    min: number,
    max: number,
    step: number,
    label: TextLabel,
    track: Frame,
    fill: Frame,
    knob: Frame,
}

local sliders:
    {SliderData} = {}

local function roundStep(
    value: number,
    step: number
): number

    return math.floor(
        value / step + 0.5
    ) * step
end

local function sliderControl(
    parent: Instance,
    key: string,
    text: string,
    min: number,
    max: number,
    step: number,
    x: number,
    y: number
): SliderData

    local labelObject =
        makeLabel(
            parent,
            "",
            x,
            y
        )

    local track =
        Instance.new("Frame")

    track.Size =
        UDim2.fromOffset(
            210,
            8
        )

    track.Position =
        UDim2.fromOffset(
            x,
            y + 27
        )

    track.BorderSizePixel = 0
    track.Parent = parent

    local trackCorner =
        Instance.new("UICorner")

    trackCorner.CornerRadius =
        UDim.new(1, 0)

    trackCorner.Parent =
        track

    local fill =
        Instance.new("Frame")

    fill.Size =
        UDim2.fromScale(
            0,
            1
        )

    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner =
        Instance.new("UICorner")

    fillCorner.CornerRadius =
        UDim.new(1, 0)

    fillCorner.Parent =
        fill

    local knob =
        Instance.new("Frame")

    knob.AnchorPoint =
        Vector2.new(
            0.5,
            0.5
        )

    knob.Size =
        UDim2.fromOffset(
            12,
            12
        )

    knob.Position =
        UDim2.fromScale(
            0,
            0.5
        )

    knob.BorderSizePixel = 0
    knob.Parent = track

    local knobCorner =
        Instance.new("UICorner")

    knobCorner.CornerRadius =
        UDim.new(1, 0)

    knobCorner.Parent =
        knob

    local data: SliderData = {
        key = key,
        min = min,
        max = max,
        step = step,
        label = labelObject,
        track = track,
        fill = fill,
        knob = knob,
    }

    table.insert(
        sliders,
        data
    )

    local dragging = false

    local function refresh()

        local value =
            tonumber(
                Config[key]
            )
            or min

        local alpha =
            math.clamp(
                (
                    value - min
                )
                / (
                    max - min
                ),
                0,
                1
            )

        labelObject.Text =
            string.format(
                "%s: %s",
                text,
                tostring(value)
            )

        fill.Size =
            UDim2.fromScale(
                alpha,
                1
            )

        knob.Position =
            UDim2.fromScale(
                alpha,
                0.5
            )
    end

    local function setFromX(
        xPosition: number
    )

        local left =
            track.AbsolutePosition.X

        local width =
            track.AbsoluteSize.X

        if width <= 0 then
            return
        end

        local alpha =
            math.clamp(
                (
                    xPosition - left
                )
                / width,
                0,
                1
            )

        local value =
            min
            + (
                max - min
            ) * alpha

        value =
            math.clamp(
                roundStep(
                    value,
                    step
                ),
                min,
                max
            )

        Config[key] = value

        refresh()
    end

    track.InputBegan:Connect(
        function(input)

            if input.UserInputType
                == Enum.UserInputType.MouseButton1
                or input.UserInputType
                == Enum.UserInputType.Touch then

                dragging = true

                setFromX(
                    input.Position.X
                )
            end
        end
    )

    UserInputService.InputChanged:Connect(
        function(input)

            if not dragging then
                return
            end

            if input.UserInputType
                == Enum.UserInputType.MouseMovement
                or input.UserInputType
                == Enum.UserInputType.Touch then

                setFromX(
                    input.Position.X
                )
            end
        end
    )

    UserInputService.InputEnded:Connect(
        function(input)

            if input.UserInputType
                == Enum.UserInputType.MouseButton1
                or input.UserInputType
                == Enum.UserInputType.Touch then

                dragging = false
            end
        end
    )

    table.insert(
        refreshFunctions,
        refresh
    )

    refresh()

    return data
end

-- =========================================================
-- AIM PAGE
-- =========================================================

toggleControl(
    aimPage,
    "AimEnabled",
    "Aim Enabled",
    10,
    5
)

cycleControl(
    aimPage,
    "AimMode",
    "Mode",
    {
        "Smooth",
        "Snap",
    },
    10,
    42
)

cycleControl(
    aimPage,
    "TargetPriority",
    "Priority",
    {
        "Crosshair",
        "Closest",
        "Lowest Health",
    },
    10,
    79
)

cycleControl(
    aimPage,
    "AimPart",
    "Aim Part",
    {
        "Auto",
        "Head",
        "Body",
    },
    10,
    116
)

cycleControl(
    aimPage,
    "TeamFilter",
    "Team Filter",
    {
        "Enemy",
        "Same Team",
        "All",
    },
    10,
    153
)

toggleControl(
    aimPage,
    "PredictionEnabled",
    "Prediction",
    10,
    190
)

toggleControl(
    aimPage,
    "VisibilityCheck",
    "Visibility Check",
    10,
    227
)

toggleControl(
    aimPage,
    "MultiPointVisibility",
    "Multi-Point",
    10,
    264
)

toggleControl(
    aimPage,
    "RequireAimKey",
    "Require RMB",
    10,
    301
)

sliderControl(
    aimPage,
    "FOV",
    "FOV",
    40,
    500,
    1,
    320,
    5
)

sliderControl(
    aimPage,
    "Smoothness",
    "Smoothness",
    0.01,
    1,
    0.01,
    320,
    77
)

sliderControl(
    aimPage,
    "PredictionTime",
    "Prediction Time",
    0,
    0.30,
    0.01,
    320,
    149
)

sliderControl(
    aimPage,
    "MaxDistance",
    "Max Distance",
    50,
    2000,
    10,
    320,
    221
)

sliderControl(
    aimPage,
    "VisibilityGraceTime",
    "Visibility Grace",
    0,
    0.50,
    0.01,
    320,
    293
)

-- =========================================================
-- ESP PAGE
-- =========================================================

toggleControl(
    espPage,
    "ESPEnabled",
    "ESP Enabled",
    10,
    5
)

toggleControl(
    espPage,
    "ESPBox",
    "Box",
    10,
    42
)

toggleControl(
    espPage,
    "ESPName",
    "Name",
    10,
    79
)

toggleControl(
    espPage,
    "ESPDistance",
    "Distance",
    10,
    116
)

toggleControl(
    espPage,
    "ESPHealth",
    "Health",
    10,
    153
)

toggleControl(
    espPage,
    "ESPTracer",
    "Tracer",
    10,
    190
)

toggleControl(
    espPage,
    "ESPSkeleton",
    "Skeleton",
    10,
    227
)

toggleControl(
    espPage,
    "ESPAliveOnly",
    "Alive Only",
    10,
    264
)

toggleControl(
    espPage,
    "ESPWallCheck",
    "Wall Check",
    10,
    301
)

cycleControl(
    espPage,
    "ESPTeamFilter",
    "Team Filter",
    {
        "Enemy",
        "Same Team",
        "All",
    },
    320,
    5
)

sliderControl(
    espPage,
    "ESPMaxDistance",
    "Max Distance",
    100,
    2500,
    10,
    320,
    47
)

sliderControl(
    espPage,
    "ESPTextScale",
    "Text Scale",
    0.50,
    1.00,
    0.05,
    320,
    119
)

makeLabel(
    espPage,
    "Compact ESP • white + dark outline",
    320,
    175
)

makeLabel(
    espPage,
    "Smaller text reduces overlap",
    320,
    202
)

-- =========================================================
-- SETTINGS PAGE
-- =========================================================

toggleControl(
    settingsPage,
    "FOVVisible",
    "FOV Circle",
    10,
    5
)

buttonControl(
    settingsPage,
    "Reset Defaults",
    10,
    42,
    function()

        for key, value in pairs(
            DEFAULTS
        ) do

            Config[key] = value
        end

        targetState.player = nil
        targetState.point = nil

        targetState.lastVisibleAt = 0
        targetState.nextSwitchAt = 0

        -- FIX:
        -- Refresh every registered GUI control.
        for _, refresh in ipairs(
            refreshFunctions
        ) do

            refresh()
        end
    end
)

makeLabel(
    settingsPage,
    "RightShift = menu on/off",
    10,
    95
)

makeLabel(
    settingsPage,
    "E = aim on/off",
    10,
    125
)

makeLabel(
    settingsPage,
    "RMB = optional hold-to-aim",
    10,
    155
)

makeLabel(
    settingsPage,
    "Prediction uses velocity, not literal ping.",
    10,
    185
)

makeLabel(
    settingsPage,
    "☰ button = open/close GUI",
    10,
    215
)

-- =========================================================
-- DEBUG PAGE
-- =========================================================

local debugLabel =
    makeLabel(
        debugPage,
        "Debug: OFF",
        10,
        5
    )

local targetLabel =
    makeLabel(
        debugPage,
        "Target: none",
        10,
        38
    )

local pointLabel =
    makeLabel(
        debugPage,
        "Aim point: none",
        10,
        71
    )

local distanceLabel =
    makeLabel(
        debugPage,
        "Distance: --",
        10,
        104
    )

local statusLabel =
    makeLabel(
        debugPage,
        "Status: idle",
        10,
        137
    )

toggleControl(
    debugPage,
    "Debug",
    "Debug",
    10,
    180
)

-- =========================================================
-- MENU DRAGGING
-- =========================================================

do

    local dragging = false
    local dragStart = Vector2.zero
    local startPosition = menu.Position

    title.InputBegan:Connect(
        function(input)

            if input.UserInputType
                == Enum.UserInputType.MouseButton1
                or input.UserInputType
                == Enum.UserInputType.Touch then

                dragging = true

                dragStart =
                    input.Position

                startPosition =
                    menu.Position
            end
        end
    )

    UserInputService.InputChanged:Connect(
        function(input)

            if not dragging then
                return
            end

            if input.UserInputType
                ~= Enum.UserInputType.MouseMovement
                and input.UserInputType
                ~= Enum.UserInputType.Touch then

                return
            end

            local delta =
                input.Position
                - dragStart

            menu.Position =
                UDim2.new(
                    startPosition.X.Scale,
                    startPosition.X.Offset
                        + delta.X,

                    startPosition.Y.Scale,
                    startPosition.Y.Offset
                        + delta.Y
                )
        end
    )

    UserInputService.InputEnded:Connect(
        function(input)

            if input.UserInputType
                == Enum.UserInputType.MouseButton1
                or input.UserInputType
                == Enum.UserInputType.Touch then

                dragging = false
            end
        end
    )
end

-- =========================================================
-- ESP TYPES
-- =========================================================

type ESPLine = {
    outer: Frame,
    inner: Frame,
}

type ESPBundle = {
    gui: ScreenGui,

    box: Frame,
    boxStroke: UIStroke,

    name: TextLabel,
    nameStroke: UIStroke,

    distance: TextLabel,
    distanceStroke: UIStroke,

    health: TextLabel,
    healthStroke: UIStroke,

    tracer: ESPLine,

    skeleton: {
        [string]: ESPLine,
    },
}

local espObjects:
    {[Player]: ESPBundle} = {}

-- =========================================================
-- SKELETON JOINTS
-- =========================================================

local skeletonJoints: {{string}} = {

    -- R15

    {"Head", "UpperTorso"},

    {"UpperTorso", "LowerTorso"},

    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},

    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},

    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},

    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},

    -- R6

    {"Torso", "Head"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

-- =========================================================
-- ESP LINE
-- =========================================================

local function createESPLine(
    parent: Instance
): ESPLine

    local outer =
        Instance.new("Frame")

    outer.AnchorPoint =
        Vector2.new(
            0.5,
            0.5
        )

    outer.BorderSizePixel = 0

    outer.BackgroundColor3 =
        ESP_OUTLINE_COLOR

    outer.Visible = false
    outer.ZIndex = 1
    outer.Parent = parent

    local inner =
        Instance.new("Frame")

    inner.AnchorPoint =
        Vector2.new(
            0.5,
            0.5
        )

    inner.BorderSizePixel = 0

    inner.BackgroundColor3 =
        ESP_MAIN_COLOR

    inner.Visible = false
    inner.ZIndex = 2
    inner.Parent = parent

    return {
        outer = outer,
        inner = inner,
    }
end

local function setESPLine(
    line: ESPLine,
    a: Vector2,
    b: Vector2,
    visible: boolean
)

    if not visible then
        line.outer.Visible = false
        line.inner.Visible = false
        return
    end

    local delta =
        b - a

    local length =
        delta.Magnitude

    if length < 1 then
        line.outer.Visible = false
        line.inner.Visible = false
        return
    end

    local center =
        (a + b) * 0.5

    local rotation =
        math.deg(
            math.atan2(
                delta.Y,
                delta.X
            )
        )

    -- Dark outline

    line.outer.Position =
        UDim2.fromOffset(
            center.X,
            center.Y
        )

    line.outer.Size =
        UDim2.fromOffset(
            length,
            3
        )

    line.outer.Rotation =
        rotation

    line.outer.Visible = true

    -- White inner line

    line.inner.Position =
        UDim2.fromOffset(
            center.X,
            center.Y
        )

    line.inner.Size =
        UDim2.fromOffset(
            length,
            1
        )

    line.inner.Rotation =
        rotation

    line.inner.Visible = true
end

local function hideESPLine(
    line: ESPLine
)

    line.outer.Visible = false
    line.inner.Visible = false
end

-- =========================================================
-- TEXT
-- =========================================================

local function configureText(
    text: TextLabel,
    stroke: UIStroke
)

    text.BackgroundTransparency = 1

    text.TextColor3 =
        ESP_MAIN_COLOR

    text.TextStrokeColor3 =
        ESP_OUTLINE_COLOR

    text.TextStrokeTransparency = 0

    text.Font =
        Enum.Font.GothamMedium

    text.TextWrapped = false

    text.TextXAlignment =
        Enum.TextXAlignment.Center

    stroke.Color =
        ESP_OUTLINE_COLOR

    stroke.Thickness = 0
end

-- =========================================================
-- CREATE ESP
-- =========================================================

local function createESP(
    player: Player
): ESPBundle

    local existing =
        espObjects[player]

    if existing then
        return existing
    end

    local eGui =
        Instance.new("ScreenGui")

    eGui.Name =
        "ESP_" .. player.UserId

    eGui.ResetOnSpawn = false
    eGui.IgnoreGuiInset = true
    eGui.DisplayOrder = 998
    eGui.Parent = gui

    -- BOX

    local box =
        Instance.new("Frame")

    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.Parent = eGui

    local boxStroke =
        Instance.new("UIStroke")

    boxStroke.Thickness = 1
    boxStroke.Color =
        ESP_MAIN_COLOR

    boxStroke.Parent = box

    -- NAME

    local nameText =
        Instance.new("TextLabel")

    nameText.AnchorPoint =
        Vector2.new(
            0.5,
            1
        )

    nameText.Size =
        UDim2.fromOffset(
            180,
            16
        )

    nameText.TextSize = 11

    nameText.TextTruncate =
        Enum.TextTruncate.AtEnd

    nameText.Visible = false
    nameText.Parent = eGui

    local nameStroke =
        Instance.new("UIStroke")

    nameStroke.Parent =
        nameText

    configureText(
        nameText,
        nameStroke
    )

    -- DISTANCE

    local distanceText =
        Instance.new("TextLabel")

    distanceText.AnchorPoint =
        Vector2.new(
            0.5,
            0
        )

    distanceText.Size =
        UDim2.fromOffset(
            140,
            15
        )

    distanceText.TextSize = 10

    distanceText.Visible = false
    distanceText.Parent = eGui

    local distanceStroke =
        Instance.new("UIStroke")

    distanceStroke.Parent =
        distanceText

    configureText(
        distanceText,
        distanceStroke
    )

    -- HEALTH

    local healthText =
        Instance.new("TextLabel")

    healthText.AnchorPoint =
        Vector2.new(
            0.5,
            0
        )

    healthText.Size =
        UDim2.fromOffset(
            140,
            15
        )

    healthText.TextSize = 10

    healthText.Visible = false
    healthText.Parent = eGui

    local healthStroke =
        Instance.new("UIStroke")

    healthStroke.Parent =
        healthText

    configureText(
        healthText,
        healthStroke
    )

    -- TRACER

    local tracer =
        createESPLine(eGui)

    -- SKELETON

    local skeleton:
        {[string]: ESPLine} = {}

    for _, joint in ipairs(
        skeletonJoints
    ) do

        local key =
            joint[1]
            .. ">"
            .. joint[2]

        skeleton[key] =
            createESPLine(eGui)
    end

    local bundle: ESPBundle = {
        gui = eGui,

        box = box,
        boxStroke = boxStroke,

        name = nameText,
        nameStroke = nameStroke,

        distance = distanceText,
        distanceStroke = distanceStroke,

        health = healthText,
        healthStroke = healthStroke,

        tracer = tracer,

        skeleton = skeleton,
    }

    espObjects[player] =
        bundle

    return bundle
end

-- =========================================================
-- HIDE ESP
-- =========================================================

local function hideBundle(
    bundle: ESPBundle
)

    bundle.box.Visible = false
    bundle.name.Visible = false
    bundle.distance.Visible = false
    bundle.health.Visible = false

    hideESPLine(
        bundle.tracer
    )

    for _, line in pairs(
        bundle.skeleton
    ) do

        hideESPLine(line)
    end
end

-- =========================================================
-- CLEANUP
-- =========================================================

local function cleanupESP(
    player: Player
)

    local bundle =
        espObjects[player]

    if not bundle then
        return
    end

    bundle.gui:Destroy()

    espObjects[player] = nil
end

-- =========================================================
-- SCREEN BOUNDS
-- =========================================================

local function projectBounds(
    character: Model
): (Vector2?, Vector2?, boolean)

    if not Camera then
        return nil, nil, false
    end

    local minX = math.huge
    local minY = math.huge

    local maxX = -math.huge
    local maxY = -math.huge

    local anyFront = false

    for _, instance in ipairs(
        character:GetDescendants()
    ) do

        if instance:IsA("BasePart") then

            local half =
                instance.Size * 0.5

            local cf =
                instance.CFrame

            for sx = -1, 1, 2 do

                for sy = -1, 1, 2 do

                    for sz = -1, 1, 2 do

                        local world =
                            cf:PointToWorldSpace(
                                Vector3.new(
                                    half.X * sx,
                                    half.Y * sy,
                                    half.Z * sz
                                )
                            )

                        local screen =
                            Camera:WorldToViewportPoint(
                                world
                            )

                        if screen.Z > 0 then

                            anyFront = true

                            minX =
                                math.min(
                                    minX,
                                    screen.X
                                )

                            minY =
                                math.min(
                                    minY,
                                    screen.Y
                                )

                            maxX =
                                math.max(
                                    maxX,
                                    screen.X
                                )

                            maxY =
                                math.max(
                                    maxY,
                                    screen.Y
                                )
                        end
                    end
                end
            end
        end
    end

    if not anyFront then
        return nil, nil, false
    end

    local viewport =
        Camera.ViewportSize

    minX =
        math.clamp(
            minX,
            0,
            viewport.X
        )

    maxX =
        math.clamp(
            maxX,
            0,
            viewport.X
        )

    minY =
        math.clamp(
            minY,
            0,
            viewport.Y
        )

    maxY =
        math.clamp(
            maxY,
            0,
            viewport.Y
        )

    if maxX <= minX
        or maxY <= minY then

        return nil, nil, false
    end

    return
        Vector2.new(
            minX,
            minY
        ),
        Vector2.new(
            maxX,
            maxY
        ),
        true
end

-- =========================================================
-- DISTANCE TEXT SIZE
-- =========================================================

local function getESPTextSize(
    distance: number
): number

    local scale =
        math.clamp(
            tonumber(
                Config.ESPTextScale
            ) or 0.8,
            0.5,
            1
        )

    local distanceFactor =
        math.clamp(
            1 - (
                distance / 1500
            ),
            0.62,
            1
        )

    return math.clamp(
        math.floor(
            13
            * scale
            * distanceFactor
            + 0.5
        ),
        8,
        12
    )
end

-- =========================================================
-- UPDATE SKELETON
-- =========================================================

local function updateSkeleton(
    bundle: ESPBundle,
    character: Model,
    visible: boolean
)

    if not visible
        or not Config.ESPSkeleton then

        for _, line in pairs(
            bundle.skeleton
        ) do

            hideESPLine(line)
        end

        return
    end

    if not Camera then
        return
    end

    for _, joint in ipairs(
        skeletonJoints
    ) do

        local aPart =
            character:FindFirstChild(
                joint[1]
            )

        local bPart =
            character:FindFirstChild(
                joint[2]
            )

        local key =
            joint[1]
            .. ">"
            .. joint[2]

        local line =
            bundle.skeleton[key]

        if aPart
            and bPart
            and aPart:IsA("BasePart")
            and bPart:IsA("BasePart") then

            local a =
                Camera:WorldToViewportPoint(
                    aPart.Position
                )

            local b =
                Camera:WorldToViewportPoint(
                    bPart.Position
                )

            local aVisible =
                a.Z > 0

            local bVisible =
                b.Z > 0

            setESPLine(
                line,

                Vector2.new(
                    a.X,
                    a.Y
                ),

                Vector2.new(
                    b.X,
                    b.Y
                ),

                aVisible
                and bVisible
            )

        else

            hideESPLine(line)
        end
    end
end

-- =========================================================
-- UPDATE ESP
-- =========================================================

local function updateESP(
    player: Player
)

    local bundle =
        createESP(player)

    if not Config.ESPEnabled then
        hideBundle(bundle)
        return
    end

    if not teamAllowed(
        player,
        Config.ESPTeamFilter
    ) then

        hideBundle(bundle)
        return
    end

    local character =
        characterOf(player)

    if not character then
        hideBundle(bundle)
        return
    end

    local humanoid =
        humanoidOf(character)

    local root =
        rootOf(character)

    if not root then
        hideBundle(bundle)
        return
    end

    if Config.ESPAliveOnly then

        if not humanoid
            or humanoid.Health <= 0 then

            hideBundle(bundle)
            return
        end
    end

    local distance =
        distanceTo(player)

    if not distance
        or distance > Config.ESPMaxDistance then

        hideBundle(bundle)
        return
    end

    if not Camera then
        hideBundle(bundle)
        return
    end

    -- IMPORTANT:
    -- Force the ESP wall check even if AIM visibility is disabled.

    if Config.ESPWallCheck then

        if not rayVisible(
            character,
            Camera.CFrame.Position,
            root.Position,
            true
        ) then

            hideBundle(bundle)
            return
        end
    end

    local minV, maxV, ok =
        projectBounds(character)

    if not ok
        or not minV
        or not maxV then

        hideBundle(bundle)
        return
    end

    local center =
        (minV + maxV) * 0.5

    local width =
        math.max(
            2,
            maxV.X - minV.X
        )

    local height =
        math.max(
            2,
            maxV.Y - minV.Y
        )

    -- =====================================================
    -- BOX
    -- =====================================================

    bundle.box.Position =
        UDim2.fromOffset(
            minV.X,
            minV.Y
        )

    bundle.box.Size =
        UDim2.fromOffset(
            width,
            height
        )

    bundle.box.Visible =
        Config.ESPBox

    -- =====================================================
    -- COMPACT TEXT
    -- =====================================================

    local textSize =
        getESPTextSize(
            distance
        )

    bundle.name.TextSize =
        textSize

    bundle.distance.TextSize =
        math.max(
            8,
            textSize - 1
        )

    bundle.health.TextSize =
        math.max(
            8,
            textSize - 1
        )

    -- =====================================================
    -- NAME
    -- =====================================================

    bundle.name.Position =
        UDim2.fromOffset(
            center.X,
            minV.Y - 2
        )

    bundle.name.Text =
        player.DisplayName

    bundle.name.Visible =
        Config.ESPName

    -- =====================================================
    -- DISTANCE
    -- =====================================================

    bundle.distance.Position =
        UDim2.fromOffset(
            center.X,
            maxV.Y + 2
        )

    bundle.distance.Text =
        string.format(
            "%.0fm",
            distance
        )

    bundle.distance.Visible =
        Config.ESPDistance

    -- =====================================================
    -- HEALTH
    -- =====================================================

    if humanoid then

        bundle.health.Position =
            UDim2.fromOffset(
                center.X,
                maxV.Y + 17
            )

        bundle.health.Text =
            string.format(
                "HP %.0f",
                math.max(
                    0,
                    humanoid.Health
                )
            )

        bundle.health.Visible =
            Config.ESPHealth

    else

        bundle.health.Visible = false
    end

    -- =====================================================
    -- TRACER
    -- =====================================================

    if Config.ESPTracer then

        local viewport =
            Camera.ViewportSize

        setESPLine(
            bundle.tracer,

            Vector2.new(
                viewport.X / 2,
                viewport.Y
            ),

            center,

            true
        )

    else

        hideESPLine(
            bundle.tracer
        )
    end

    -- =====================================================
    -- SKELETON
    -- =====================================================

    updateSkeleton(
        bundle,
        character,
        true
    )
end

-- =========================================================
-- PLAYER EVENTS
-- =========================================================

Players.PlayerRemoving:Connect(
    function(player)

        cleanupESP(player)

        if targetState.player
            == player then

            targetState.player = nil
            targetState.point = nil

            targetState.lastVisibleAt = 0
            targetState.nextSwitchAt = 0
        end
    end
)

for _, player in ipairs(
    Players:GetPlayers()
) do

    if player ~= LocalPlayer then
        createESP(player)
    end
end

Players.PlayerAdded:Connect(
    function(player)

        if player ~= LocalPlayer then
            createESP(player)
        end
    end
)

-- =========================================================
-- INPUT
-- =========================================================

UserInputService.InputBegan:Connect(
    function(input, processed)

        if processed then
            return
        end

        if input.KeyCode ==
            Config.MenuToggleKey then

            menu.Visible =
                not menu.Visible

            return
        end

        if input.KeyCode ==
            Config.AimToggleKey then

            Config.AimEnabled =
                not (
                    Config.AimEnabled == true
                )

            -- Keep GUI state synchronized
            -- when using E as the toggle key.

            for _, refresh in ipairs(
                refreshFunctions
            ) do

                refresh()
            end

            return
        end
    end
)

-- =========================================================
-- MAIN LOOP
-- =========================================================

local espAccumulator = 0
local debugAccumulator = 0

RunService.RenderStepped:Connect(
    function(dt)

        -- =================================================
        -- FOV
        -- =================================================

        if Camera then

            fovCircle.Position =
                UDim2.fromOffset(
                    Camera.ViewportSize.X / 2,
                    Camera.ViewportSize.Y / 2
                )

            fovCircle.Size =
                UDim2.fromOffset(
                    Config.FOV * 2,
                    Config.FOV * 2
                )

            fovCircle.Visible =
                Config.FOVVisible
        end

        -- =================================================
        -- AIM
        -- =================================================

        if Config.AimEnabled
            and aimKeyHeld() then

            local player, point =
                updateTarget()

            if player and point then

                aimAt(
                    predictedPoint(
                        point,
                        player
                    )
                )
            end

        else

            targetState.player = nil
            targetState.point = nil
        end

        -- =================================================
        -- ESP
        -- =================================================

        espAccumulator += dt

        if espAccumulator >= 0.033 then

            espAccumulator = 0

            for _, player in ipairs(
                Players:GetPlayers()
            ) do

                if player ~= LocalPlayer then
                    updateESP(player)
                end
            end
        end

        -- =================================================
        -- DEBUG
        -- =================================================

        debugAccumulator += dt

        if debugAccumulator >= 0.10 then

            debugAccumulator = 0

            if Config.Debug then

                debugLabel.Text =
                    "Debug: ON | Tab: "
                    .. currentTab

                if targetState.player then

                    targetLabel.Text =
                        "Target: "
                        .. targetState.player.Name

                    if targetState.point then

                        pointLabel.Text =
                            string.format(
                                "Aim point: %.1f, %.1f, %.1f",

                                targetState.point.X,
                                targetState.point.Y,
                                targetState.point.Z
                            )

                    else

                        pointLabel.Text =
                            "Aim point: none"
                    end

                    local distance =
                        distanceTo(
                            targetState.player
                        )

                    if distance then

                        distanceLabel.Text =
                            string.format(
                                "Distance: %.1f",
                                distance
                            )

                    else

                        distanceLabel.Text =
                            "Distance: --"
                    end

                    statusLabel.Text =
                        "Status: locked"

                else

                    targetLabel.Text =
                        "Target: none"

                    pointLabel.Text =
                        "Aim point: none"

                    distanceLabel.Text =
                        "Distance: --"

                    if Config.AimEnabled then

                        statusLabel.Text =
                            "Status: searching"

                    else

                        statusLabel.Text =
                            "Status: idle"
                    end
                end

            else

                debugLabel.Text =
                    "Debug: OFF"

                targetLabel.Text =
                    "Target: hidden"

                pointLabel.Text =
                    "Aim point: hidden"

                distanceLabel.Text =
                    "Distance: hidden"

                statusLabel.Text =
                    "Status: hidden"
            end
        end
    end
)
