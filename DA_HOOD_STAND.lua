local _S = {
    bxor = bit32.bxor,
    rshift = bit32.rshift,
    lshift = bit32.lshift,
    char = string.char,
    byte = string.byte,
    sub = string.sub,
    gsub = string.gsub,
    unpack = table.unpack or unpack
}

local function ProtectEnvironment()
    local env = getfenv()
    if not env.game or not env.workspace then
        warn("Incompatible Environment Detected!")
        return false
    end
    return true
end

if not ProtectEnvironment() then return end

getgenv().Owner = "Mahdirml123i"

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    HttpService = game:GetService("HttpService"),
    CoreGui = game:GetService("CoreGui"),
    TweenService = game:GetService("TweenService"),  -- Added for smooth movement
    TeleportService = game:GetService("TeleportService")  -- Added for rejoin command
}

local LocalPlayer = Services.Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Config = {
    WalkSpeed = 16,
    JumpPower = 50,
    KillAura = false,
    AuraRange = 20,
    FlySpeed = 50,
    Flying = false,
    AutoFarm = false,
    StandMode = false
}

local SafePosition = Vector3.new(-500, 50, 500)  -- Updated safe location for .uns command

local function ResetChatToDefault()
    local ChatFrame = LocalPlayer.PlayerGui:FindFirstChild("Chat") and LocalPlayer.PlayerGui.Chat:FindFirstChild("Frame")
    if ChatFrame then
        ChatFrame.Position = UDim2.new(0, 0, 1, -100)
        ChatFrame.Visible = true
        warn("Chat returned to default state.")
    end
end
ResetChatToDefault()

local UI = {}
function UI:CreateWindow(title)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MoonStand_Private"
    ScreenGui.Parent = Services.CoreGui
    ScreenGui.ResetOnSpawn = false

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = ScreenGui
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Main.BorderSizePixel = 0
    Main.Position = UDim2.new(0.5, -200, 0.5, -150)
    Main.Size = UDim2.new(0, 400, 0, 300)
    Main.ClipsDescendants = true

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = Main

    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Parent = Main
    Header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Header.Size = UDim2.new(1, 0, 0, 40)

    local Title = Instance.new("TextLabel")
    Title.Parent = Header
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.Size = UDim2.new(1, -30, 1, 0)
    Title.Font = Enum.Font.GothamBold
    Title.Text = title
    Title.TextColor3 = Color3.fromRGB(200, 200, 200)
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local Container = Instance.new("ScrollingFrame")
    Container.Name = "Container"
    Container.Parent = Main
    Container.BackgroundTransparency = 1
    Container.Position = UDim2.new(0, 10, 0, 50)
    Container.Size = UDim2.new(1, -20, 1, -60)
    Container.CanvasSize = UDim2.new(0, 0, 0, 0)
    Container.ScrollBarThickness = 0

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Parent = Container
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 8)

    -- Dragging Logic
    local dragging, dragInput, dragStart, startPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)
    Header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    return Container
end

local Container = UI:CreateWindow("MOONSTAND PRIVATE V1")

local function AddToggle(text, callback)
    local ToggleFrame = Instance.new("TextButton")
    ToggleFrame.Parent = Container
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    ToggleFrame.Size = UDim2.new(1, 0, 0, 40)
    ToggleFrame.AutoButtonColor = false
    ToggleFrame.Text = ""

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 6)
    UICorner.Parent = ToggleFrame

    local Label = Instance.new("TextLabel")
    Label.Parent = ToggleFrame
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Font = Enum.Font.Gotham
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(180, 180, 180)
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local Indicator = Instance.new("Frame")
    Indicator.Parent = ToggleFrame
    Indicator.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    Indicator.Position = UDim2.new(1, -45, 0.5, -10)
    Indicator.Size = UDim2.new(0, 30, 0, 20)

    local IndCorner = Instance.new("UICorner")
    IndCorner.CornerRadius = UDim.new(1, 0)
    IndCorner.Parent = Indicator

    local State = false
    ToggleFrame.MouseButton1Click:Connect(function()
        State = not State
        Indicator.BackgroundColor3 = State and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
        callback(State)
    end)
end

local function AddSlider(text, min, max, default, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Parent = Container
    SliderFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    SliderFrame.Size = UDim2.new(1, 0, 0, 50)

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 6)
    UICorner.Parent = SliderFrame

    local Label = Instance.new("TextLabel")
    Label.Parent = SliderFrame
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 15, 0, 5)
    Label.Size = UDim2.new(1, -30, 0, 20)
    Label.Font = Enum.Font.Gotham
    Label.Text = text .. ": " .. default
    Label.TextColor3 = Color3.fromRGB(180, 180, 180)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local Bar = Instance.new("Frame")
    Bar.Parent = SliderFrame
    Bar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Bar.Position = UDim2.new(0, 15, 0, 30)
    Bar.Size = UDim2.new(1, -30, 0, 6)

    local Fill = Instance.new("Frame")
    Fill.Parent = Bar
    Fill.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)

    local function UpdateSlider(input)
        local pos = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        local val = math.floor(min + (max - min) * pos)
        Label.Text = text .. ": " .. val
        callback(val)
    end

    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            UpdateSlider(input)
            local move; move = Services.UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    UpdateSlider(input)
                end
            end)
            local release; release = Services.UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    move:Disconnect()
                    release:Disconnect()
                end
            end)
        end
    end)
end

local lastOwnerPosition = nil  -- For performance: track last position to avoid unnecessary updates

local function SetIntangible(state)
    if LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = not state
            end
        end
        if LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.PlatformStand = state
        end
        -- Add/Remove BodyVelocity for floating
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("BodyVelocity")
            if state then
                if not bv then
                    bv = Instance.new("BodyVelocity")
                    bv.Name = "BodyVelocity"
                    bv.Parent = hrp
                    bv.MaxForce = Vector3.new(0, 4000, 0)  -- Only upward force
                    bv.Velocity = Vector3.new(0, 10, 0)  -- Gentle upward velocity to stay floating
                end
            else
                if bv then bv:Destroy() end
            end
        end
    end
end

local function StandBehindOwner()
    local ownerPlayer = Services.Players:FindFirstChild(getgenv().Owner)
    if ownerPlayer and ownerPlayer.Character and ownerPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local ownerHRP = ownerPlayer.Character.HumanoidRootPart
        local standHRP = LocalPlayer.Character.HumanoidRootPart

        -- Performance check: only teleport if owner has moved significantly
        if not lastOwnerPosition or (ownerHRP.Position - lastOwnerPosition).Magnitude > 1 then
            lastOwnerPosition = ownerHRP.Position
            local direction = ownerHRP.CFrame.LookVector * -5
            local behindPos = (ownerHRP.CFrame + direction).Position
            -- Set position behind owner at the same Y level + 5 studs to prevent falling
            local targetPosition = Vector3.new(behindPos.X, ownerHRP.Position.Y + 5, behindPos.Z)

            -- Fast fly-teleport: Set position only to avoid camera issues
            standHRP.Position = targetPosition
            -- Orient towards owner without affecting camera
            standHRP.CFrame = CFrame.new(targetPosition, ownerHRP.Position)
        end
    end
end

local function MoveToSafe()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local standHRP = LocalPlayer.Character.HumanoidRootPart
        local targetPosition = SafePosition + Vector3.new(0, 5, 0)  -- Slight height

        -- Fast teleport to safe position
        standHRP.Position = targetPosition
        warn("Moving to safe position.")
    end
end

local function ExecuteCommand(message)
    local cmd = string.lower(message)
    if cmd == ".s" then
        Config.StandMode = true
        lastOwnerPosition = nil  -- Reset for fresh tracking
        SetIntangible(true)  -- Make intangible and enable flying
        warn("Stand Mode Activated: Following Owner (Fast Fly-Teleport & Intangible).")
    elseif cmd == ".uns" then
        Config.StandMode = false
        SetIntangible(false)  -- Restore collisions
        MoveToSafe()
        warn("Stand Mode Deactivated: Moving to safe position.")
    elseif cmd == "rj!" then
        warn("Rejoining the same server...")
        local success, err = pcall(function()
            Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
        end)
        if not success then
            warn("Failed to rejoin: " .. err)
        end
    end
end

-- Track Owner's Chat
local ownerPlayer = Services.Players:FindFirstChild(getgenv().Owner)
if ownerPlayer then
    ownerPlayer.Chatted:Connect(function(message)
        ExecuteCommand(message)
    end)
else
    warn("Owner not found in game.")
end

-- Ensure script runs after character loads
LocalPlayer.CharacterAdded:Connect(function(character)
    wait(1)  -- Wait for character to fully load
    if Config.StandMode then
        SetIntangible(true)
    end
end)

local function GetClosest()
    local target = nil
    local dist = Config.AuraRange
    for _, p in pairs(Services.Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local d = (LocalPlayer.Character.HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
            if d < dist then
                dist = d
                target = p
            end
        end
    end
    return target
end

-- Combat Features
AddToggle("Kill Aura", function(v) Config.KillAura = v end)
AddSlider("Aura Range", 10, 100, 20, function(v) Config.AuraRange = v end)

Services.RunService.Heartbeat:Connect(function()
    if Config.StandMode then
        StandBehindOwner()
    end
    if Config.KillAura then
        local target = GetClosest()
        if target then
            -- Logic for attacking (Customizable)
        end
    end
end)

AddSlider("WalkSpeed", 16, 200, 16, function(v)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = v
    end
end)

AddSlider("JumpPower", 50, 500, 50, function(v)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.JumpPower = v
    end
end)

AddToggle("Infinite Jump", function(v)
    local connection
    if v then
        connection = Services.UserInputService.JumpRequest:Connect(function()
            LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    else
        if connection then connection:Disconnect() end
    end
end)

print("MoonStand Private V1 Loaded Successfully!")
warn("Security Layer Active: Function Aliasing Enabled.")
warn("Chat Listening Enabled for Owner: " .. getgenv().Owner)
warn("Standby Mode Active: Waiting for Commands.")
warn("Chat returned to default state after execute.")
