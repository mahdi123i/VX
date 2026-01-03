local SCRIPT_ID = "DAHOOD_STAND_" .. tostring(math.random(100000, 999999))
if getgenv()[SCRIPT_ID] then return end
getgenv()[SCRIPT_ID] = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then return end

local State = {
    IsSummoned = false,
    StandModel = nil,
    StandRoot = nil,
    FollowConnection = nil,
    AnimationConnection = nil,
    PlayerFrozen = false
}

local function SafeGetRoot(char)
    if not char or not char.Parent then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function FreezePlayer()
    if State.PlayerFrozen then return end
    State.PlayerFrozen = true
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end
    
    if State.AnimationConnection then
        pcall(function() State.AnimationConnection:Disconnect() end)
    end
    
    State.AnimationConnection = RunService.Heartbeat:Connect(function()
        if not State.PlayerFrozen then return end
        
        local char = LocalPlayer.Character
        if not char then return end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
        end
        
        pcall(function()
            for _, anim in pairs(humanoid:GetPlayingAnimationTracks()) do
                anim:Stop()
            end
        end)
    end)
end

local function UnfreezePlayer()
    if not State.PlayerFrozen then return end
    State.PlayerFrozen = false
    
    if State.AnimationConnection then
        pcall(function() State.AnimationConnection:Disconnect() end)
        State.AnimationConnection = nil
    end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end
end

local function CreateStand()
    if State.StandModel then
        pcall(function() State.StandModel:Destroy() end)
    end
    
    local model = Instance.new("Model")
    model.Name = "Stand_" .. LocalPlayer.Name
    model.Parent = workspace
    
    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2, 2, 1)
    root.Transparency = 0.5
    root.CanCollide = false
    root.Material = Enum.Material.ForceField
    root.Color = Color3.fromRGB(0, 255, 255)
    root.TopSurface = Enum.SurfaceType.Smooth
    root.BottomSurface = Enum.SurfaceType.Smooth
    root.Parent = model
    
    local hum = Instance.new("Humanoid")
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    hum.MaxHealth = 100
    hum.Health = 100
    hum.Parent = model
    
    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.P = 25000
    bp.D = 1200
    bp.Parent = root
    
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 25000
    bg.Parent = root
    
    pcall(function()
        if typeof(root.SetNetworkOwner) == "function" then
            root:SetNetworkOwner(LocalPlayer)
        end
    end)
    
    State.StandModel = model
    State.StandRoot = root
    
    if State.FollowConnection then
        pcall(function() State.FollowConnection:Disconnect() end)
    end
    
    State.FollowConnection = RunService.Heartbeat:Connect(function()
        if not State.IsSummoned or not State.StandRoot or not State.StandRoot.Parent then
            return
        end
        
        local myChar = LocalPlayer.Character
        if not myChar then return end
        
        local myRoot = SafeGetRoot(myChar)
        if not myRoot then return end
        
        local bp = State.StandRoot:FindFirstChild("BodyPosition")
        local bg = State.StandRoot:FindFirstChild("BodyGyro")
        
        if bp and bg then
            local offset = CFrame.new(-2.5, 2.5, 3.5)
            local targetCF = myRoot.CFrame * offset
            
            bp.Position = targetCF.Position
            bg.CFrame = targetCF
        end
    end)
end

local function DestroyStand()
    if State.FollowConnection then
        pcall(function() State.FollowConnection:Disconnect() end)
        State.FollowConnection = nil
    end
    
    if State.StandModel then
        pcall(function() State.StandModel:Destroy() end)
        State.StandModel = nil
        State.StandRoot = nil
    end
end

local function ProcessCommand(msg)
    if not msg or msg == "" then return end
    
    msg = msg:match("^%s*(.-)%s*$") or msg
    msg = msg:lower()
    
    if msg == ".s" or msg == ".summon" then
        if not State.IsSummoned then
            State.IsSummoned = true
            CreateStand()
            print("[STAND] Summoned!")
        end
    elseif msg == ".uns" or msg == ".unsummon" or msg == ".vanish" then
        if State.IsSummoned then
            State.IsSummoned = false
            DestroyStand()
            print("[STAND] Vanished!")
        end
    end
end

print("[BOOT] Initializing...")

FreezePlayer()

print("[BOOT] Player frozen on startup")

pcall(function()
    if LocalPlayer and LocalPlayer.Chatted then
        LocalPlayer.Chatted:Connect(function(msg)
            ProcessCommand(msg)
        end)
    end
end)

pcall(function()
    local TextChatService = game:GetService("TextChatService")
    if TextChatService and TextChatService.OnIncomingMessage then
        TextChatService.OnIncomingMessage:Connect(function(message)
            if message and message.TextSource and message.TextSource.UserId == LocalPlayer.UserId then
                ProcessCommand(message.Text)
            end
        end)
    end
end)

pcall(function()
    if LocalPlayer then
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            FreezePlayer()
            if State.IsSummoned then
                CreateStand()
            end
        end)
    end
end)

print("[SYSTEM] Ready - Type .s to summon")
