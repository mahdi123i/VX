local _S = {
    bxor = bit32.bxor,
    rshift = bit32.rshift,
    lshift = bit32.lshift,
    char = string.char,
    byte = string.byte,
    sub = string.sub,
    gsub = string.sub,
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

getgenv().Owner = "Kareemasde"

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    HttpService = game:GetService("HttpService"),
    CoreGui = game:GetService("CoreGui"),
    TweenService = game:GetService("TweenService"),
    TeleportService = game:GetService("TeleportService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage")
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
    StandMode = false,
    CurrentGun = nil,
    AutoReload = false
}

local SafePosition = Vector3.new(211.795, 48.394, -595)

local isOwnerTouching = false

-- DA HOOD GUN CONFIGURATION
local GunConfig = {
    ["lmg"] = {
        DisplayName = "LMG",
        ToolName = "LMG",
        ItemName = "LMG",
        Price = 3750
    },
    ["aug"] = {
        DisplayName = "AUG",
        ToolName = "AUG",
        ItemName = "AUG",
        Price = 0
    },
    ["shotty"] = {
        DisplayName = "Shotgun",
        ToolName = "Shotgun",
        ItemName = "Shotgun",
        Price = 1250
    },
    ["db"] = {
        DisplayName = "Double Barrel",
        ToolName = "Double-Barrel SG",
        ItemName = "Double-Barrel SG",
        Price = 1400
    },
    ["ar"] = {
        DisplayName = "AR",
        ToolName = "AR",
        ItemName = "AR",
        Price = 1000
    },
    ["smg"] = {
        DisplayName = "SMG",
        ToolName = "SMG",
        ItemName = "SMG",
        Price = 750
    },
    ["rev"] = {
        DisplayName = "Revolver",
        ToolName = "Revolver",
        ItemName = "Revolver",
        Price = 1300
    }
}

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

local lastOwnerPosition = nil

local function GetPlayerFromPart(part)
    local character = part.Parent
    if character and character:IsA("Model") then
        return Services.Players:GetPlayerFromCharacter(character)
    end
    return nil
end

local function SetIntangible(state)
    if LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = not state
                part.Transparency = state and 1 or 0
            end
        end
        if LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.PlatformStand = state
            local animator = LocalPlayer.Character.Humanoid:FindFirstChild("Animator")
            if animator then
                animator:Destroy()
            end
        end
    end
end

-- DA HOOD GUN FUNCTIONS

local function BuyGunDaHood(gunType)
    local gunData = GunConfig[gunType]
    if not gunData then
        warn("Unknown gun type: " .. gunType)
        return false
    end
    
    -- Da Hood uses MainEvent remote for buying items
    local MainEvent = Services.ReplicatedStorage:FindFirstChild("MainEvent")
    if not MainEvent then
        warn("MainEvent not found! Cannot buy gun.")
        return false
    end
    
    -- Try multiple buy formats for Da Hood
    local success = false
    
    -- Method 1: Standard buy format
    pcall(function()
        MainEvent:FireServer("BuyItem", gunData.ItemName)
    end)
    
    -- Method 2: Try with item table
    pcall(function()
        MainEvent:FireServer("BuyItem", {["Item"] = gunData.ItemName})
    end)
    
    -- Method 3: Try ToggleItem (some games use this)
    pcall(function()
        MainEvent:FireServer("ToggleItem", gunData.ItemName)
    end)
    
    warn("Attempted to buy " .. gunData.DisplayName .. " using multiple methods")
    Config.CurrentGun = gunType
    return true
end

local function EquipGun(gunType)
    local gunData = GunConfig[gunType]
    if not gunData then return false end
    
    wait(1.5)  -- Wait longer for gun to appear in backpack
    
    -- Try multiple tool name formats
    local possibleNames = {
        gunData.ToolName,  -- [LMG]
        gunData.ItemName,  -- LMG
        string.upper(gunData.ItemName),  -- LMG
        string.lower(gunData.ItemName)   -- lmg
    }
    
    local gun = nil
    
    -- Search in backpack
    for _, name in pairs(possibleNames) do
        gun = LocalPlayer.Backpack:FindFirstChild(name)
        if gun then
            warn("Found gun in backpack: " .. name)
            break
        end
    end
    
    -- Search in character (already equipped)
    if not gun and LocalPlayer.Character then
        for _, name in pairs(possibleNames) do
            gun = LocalPlayer.Character:FindFirstChild(name)
            if gun then
                warn("Gun already equipped: " .. name)
                return true
            end
        end
    end
    
    -- Search recursively in backpack
    if not gun then
        for _, item in pairs(LocalPlayer.Backpack:GetDescendants()) do
            if item:IsA("Tool") then
                for _, name in pairs(possibleNames) do
                    if string.find(string.lower(item.Name), string.lower(name)) then
                        gun = item
                        warn("Found gun recursively: " .. item.Name)
                        break
                    end
                end
                if gun then break end
            end
        end
    end
    
    if gun and gun:IsA("Tool") then
        if gun.Parent == LocalPlayer.Backpack then
            LocalPlayer.Character.Humanoid:EquipTool(gun)
            warn("Equipped " .. gun.Name)
            return true
        end
        return true
    else
        warn("Gun not found after purchase. Checking all backpack items:")
        for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
            warn("  - " .. item.Name .. " (" .. item.ClassName .. ")")
        end
        return false
    end
end

local function ReloadGun()
    if not LocalPlayer.Character then return end
    
    local currentTool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not currentTool then return end
    
    -- Da Hood reload: Access the tool's reload remote/function directly
    local MainEvent = Services.ReplicatedStorage:FindFirstChild("MainEvent")
    if MainEvent then
        local success = pcall(function()
            -- Da Hood uses MainEvent for reloading
            MainEvent:FireServer("Reload", currentTool)
        end)
        
        if success then
            warn("Reloaded gun via MainEvent")
            return
        end
    end
    
    -- Fallback: Try to find and use tool's reload bindable
    local reloadBindable = currentTool:FindFirstChild("Reload")
    if reloadBindable and reloadBindable:IsA("BindableEvent") then
        pcall(function()
            reloadBindable:Fire()
        end)
        warn("Reloaded gun via Bindable")
        return
    end
    
    warn("Could not find reload method")
end

local lastReloadTime = 0
local function AutoReloadLoop()
    Services.RunService.Heartbeat:Connect(function()
        if Config.AutoReload and Config.CurrentGun and LocalPlayer.Character then
            local currentTool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if currentTool then
                -- Look for ammo value in the tool
                local ammo = currentTool:FindFirstChild("Ammo")
                if ammo and ammo:IsA("IntValue") then
                    if ammo.Value <= 5 and (tick() - lastReloadTime) > 2 then
                        ReloadGun()
                        lastReloadTime = tick()
                    end
                end
            end
        end
    end)
end

AutoReloadLoop()

local function StandBehindOwner()
    local ownerPlayer = Services.Players:FindFirstChild(getgenv().Owner)
    if ownerPlayer and ownerPlayer.Character and ownerPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local ownerHRP = ownerPlayer.Character.HumanoidRootPart
        local standHRP = LocalPlayer.Character.HumanoidRootPart

        if not isOwnerTouching then
            local direction = ownerHRP.CFrame.LookVector * -5
            local behindPos = (ownerHRP.CFrame + direction).Position
            standHRP.Position = Vector3.new(behindPos.X, ownerHRP.Position.Y, behindPos.Z)
            standHRP.CFrame = CFrame.new(standHRP.Position, ownerHRP.Position)
        end
    end
end

local function MoveToSafe()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local standHRP = LocalPlayer.Character.HumanoidRootPart
        local targetCFrame = CFrame.new(SafePosition)
        standHRP.CFrame = targetCFrame
        warn("Moving to safe position.")
    end
end

local function ExecuteCommand(message)
    local cmd = string.lower(message)
    if cmd == ".s" then
        Config.StandMode = true
        lastOwnerPosition = nil
        SetIntangible(true)
        warn("Stand Mode Activated: Following Owner (Frozen, No Animations, Transparent).")
    elseif cmd == ".uns" then
        Config.StandMode = false
        MoveToSafe()
        SetIntangible(true)
        warn("Stand Mode Deactivated: Vanished to safe position.")
    elseif cmd == ".lmg" then
        warn("LMG command received. Buying and equipping LMG...")
        if BuyGunDaHood("lmg") then
            wait(1)
            if EquipGun("lmg") then
                Config.AutoReload = true
                warn("LMG equipped with auto-reload enabled.")
            end
        end
    elseif cmd == ".aug" then
        warn("AUG command received. Buying and equipping AUG...")
        if BuyGunDaHood("aug") then
            wait(1)
            if EquipGun("aug") then
                Config.AutoReload = true
                warn("AUG equipped with auto-reload enabled.")
            end
        end
    elseif cmd == ".shotty" then
        warn("Shotgun command received. Buying and equipping Shotgun...")
        if BuyGunDaHood("shotty") then
            wait(1)
            if EquipGun("shotty") then
                Config.AutoReload = true
                warn("Shotgun equipped with auto-reload enabled.")
            end
        end
    elseif cmd == ".ar" then
        warn("AR command received. Buying and equipping AR...")
        if BuyGunDaHood("ar") then
            wait(1)
            if EquipGun("ar") then
                Config.AutoReload = true
                warn("AR equipped with auto-reload enabled.")
            end
        end
    elseif cmd == ".db" then
        warn("Double Barrel command received. Buying and equipping Double Barrel...")
        if BuyGunDaHood("db") then
            wait(1)
            if EquipGun("db") then
                Config.AutoReload = true
                warn("Double Barrel equipped with auto-reload enabled.")
            end
        end
    elseif cmd == ".smg" then
        warn("SMG command received. Buying and equipping SMG...")
        if BuyGunDaHood("smg") then
            wait(1)
            if EquipGun("smg") then
                Config.AutoReload = true
                warn("SMG equipped with auto-reload enabled.")
            end
        end
    elseif cmd == ".rev" then
        warn("Revolver command received. Buying and equipping Revolver...")
        if BuyGunDaHood("rev") then
            wait(1)
            if EquipGun("rev") then
                Config.AutoReload = true
                warn("Revolver equipped with auto-reload enabled.")
            end
        end
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

local function ConnectOwnerChat(ownerPlayer)
    if ownerPlayer then
        ownerPlayer.Chatted:Connect(function(message)
            ExecuteCommand(message)
        end)
        warn("Chat listener connected for owner: " .. ownerPlayer.Name)
    end
end

local ownerPlayer = Services.Players:FindFirstChild(getgenv().Owner)
if ownerPlayer then
    ConnectOwnerChat(ownerPlayer)
else
    warn("Owner not found in game. Waiting for owner to join...")
end

Services.Players.PlayerAdded:Connect(function(player)
    if player.Name == getgenv().Owner then
        ConnectOwnerChat(player)
    end
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    wait(1)
    if Config.StandMode then
        SetIntangible(true)
    end
    if Config.CurrentGun then
        wait(2)
        EquipGun(Config.CurrentGun)
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

AddToggle("Kill Aura", function(v) Config.KillAura = v end)
AddSlider("Aura Range", 10, 100, 20, function(v) Config.AuraRange = v end)

Services.RunService.Heartbeat:Connect(function()
    if Config.StandMode then
        isOwnerTouching = false
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    local touchingParts = part:GetTouchingParts()
                    for _, touchPart in pairs(touchingParts) do
                        local player = GetPlayerFromPart(touchPart)
                        if player == Services.Players:FindFirstChild(getgenv().Owner) then
                            isOwnerTouching = true
                            break
                        end
                    end
                    if isOwnerTouching then break end
                end
            end
        end

        StandBehindOwner()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.Sit = false
        end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            local humanoid = LocalPlayer.Character.Humanoid
            if humanoid.Health < humanoid.MaxHealth then
                humanoid.Health = humanoid.MaxHealth
            end
        end
        local ownerPlayer = Services.Players:FindFirstChild(getgenv().Owner)
        if ownerPlayer and ownerPlayer.Character and ownerPlayer.Character:FindFirstChild("Humanoid") then
            local ownerHumanoid = ownerPlayer.Character.Humanoid
            local standHumanoid = LocalPlayer.Character.Humanoid
            if ownerHumanoid:GetState() == Enum.HumanoidStateType.Jumping and standHumanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
                standHumanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    else
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            local humanoid = LocalPlayer.Character.Humanoid
            if humanoid.Health <= 5 then
                warn("Health low, resetting...")
                humanoid.Health = 0
            end
        end
    end
    if Config.KillAura then
        local target = GetClosest()
        if target then
            -- Logic for attacking
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
warn("Gun Commands: .lmg, .aug, .shotty, .db, .smg, .rev, .ar")
warn("Da Hood optimized gun system loaded!")
warn("Chat returned to default state after execute.")
