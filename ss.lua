local SCRIPT_ID = "DAHOOD_STAND_REAL_" .. tostring(math.random(100000, 999999))
if getgenv()[SCRIPT_ID] then return end
getgenv()[SCRIPT_ID] = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then return end

local State = {
    IsSummoned = false,
    StandModel = nil,
    StandRoot = nil,
    FollowConnection = nil,
    AnimationConnection = nil,
    MainEvent = nil,
    OriginalAnimations = {}
}

local function SafeGetRoot(char)
    if not char or not char.Parent then return nil end
    local root = nil
    pcall(function()
        root = char:FindFirstChild("HumanoidRootPart")
    end)
    return root
end

local function ModifyServerSettings()
    print("[SERVER] Modifying server settings...")
    
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            print("[SERVER] Player movement disabled")
        end
    end)
    
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        
        local humanoidRootPart = SafeGetRoot(char)
        if humanoidRootPart then
            humanoidRootPart.CanCollide = true
            print("[SERVER] Collision enabled")
        end
    end)
end

local function RestoreServerSettings()
    print("[SERVER] Restoring server settings...")
    
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
            print("[SERVER] Player movement restored")
        end
    end)
end

local function FreezePlayerAnimation()
    local char = LocalPlayer.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    pcall(function()
        for _, anim in pairs(humanoid:GetPlayingAnimationTracks()) do
            State.OriginalAnimations[anim] = true
            anim:Stop()
        end
    end)
    
    if State.AnimationConnection then
        pcall(function() State.AnimationConnection:Disconnect() end)
    end
    
    State.AnimationConnection = RunService.Heartbeat:Connect(function()
        if not State.IsSummoned then return end
        
        local char = LocalPlayer.Character
        if not char then return end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        
        pcall(function()
            for _, anim in pairs(humanoid:GetPlayingAnimationTracks()) do
                anim:Stop()
            end
        end)
    end)
end

local function UnfreezePlayerAnimation()
    if State.AnimationConnection then
        pcall(function() State.AnimationConnection:Disconnect() end)
        State.AnimationConnection = nil
    end
    
    State.OriginalAnimations = {}
end

local function FindMainEvent()
    pcall(function()
        local mainEvent = ReplicatedStorage:FindFirstChild("MainEvent")
        if mainEvent and (mainEvent:IsA("RemoteEvent") or mainEvent:IsA("RemoteFunction")) then
            if typeof(mainEvent.FireServer) == "function" then
                State.MainEvent = mainEvent
                print("[REMOTE] Found MainEvent")
                return
            end
        end
    end)
    
    if not State.MainEvent then
        local keywords = {"attack", "damage", "hit", "punch", "combat", "action", "event"}
        local function scan(parent, depth)
            if depth > 8 or State.MainEvent then return end
            pcall(function()
                for _, obj in pairs(parent:GetChildren()) do
                    if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and typeof(obj.FireServer) == "function" then
                        local name = obj.Name:lower()
                        for _, kw in ipairs(keywords) do
                            if name:find(kw) then
                                State.MainEvent = obj
                                print("[REMOTE] Found " .. obj.Name)
                                return
                            end
                        end
                    end
                    scan(obj, depth + 1)
                end
            end)
        end
        scan(ReplicatedStorage, 0)
    end
end

local function Notify(title, text)
    pcall(function()
        local starterGui = game:GetService("StarterGui")
        if starterGui and typeof(starterGui.SetCore) == "function" then
            starterGui:SetCore("SendNotification", {
                Title = tostring(title),
                Text = tostring(text),
                Duration = 5
            })
        end
    end)
end

local function ResetChatToDefault()
    print("[CHAT] Resetting chat to default...")
    
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            local chat = playerGui:FindFirstChild("Chat")
            if chat then
                chat.Enabled = false
                task.wait(0.2)
                chat.Enabled = true
                print("[CHAT] Chat UI reset")
            end
        end
    end)
    
    pcall(function()
        local starterGui = game:GetService("StarterGui")
        if starterGui then
            starterGui:SetCore("ChatMakeSystemMessage", {
                Text = "Chat reset to default",
                Color = Color3.fromRGB(0, 100, 255),
                Font = Enum.Font.GothamBold,
                TextSize = 18,
            })
            print("[CHAT] System message sent")
        end
    end)
end

local function CreateStand()
    print("[STAND] Creating stand...")
    
    if State.StandModel then
        pcall(function() State.StandModel:Destroy() end)
    end
    
    local model = nil
    pcall(function()
        model = Instance.new("Model", Workspace)
        model.Name = "Stand_" .. LocalPlayer.Name
    end)
    
    if not model then 
        print("[STAND] Failed to create model")
        return 
    end
    
    local root = nil
    pcall(function()
        root = Instance.new("Part", model)
        root.Name = "HumanoidRootPart"
        root.Size = Vector3.new(2, 2, 1)
        root.Transparency = 0.5
        root.CanCollide = false
        root.Material = Enum.Material.ForceField
        root.Color = Color3.fromRGB(0, 255, 255)
        root.TopSurface = Enum.SurfaceType.Smooth
        root.BottomSurface = Enum.SurfaceType.Smooth
    end)
    
    if not root then 
        print("[STAND] Failed to create root")
        return 
    end
    
    pcall(function()
        local hum = Instance.new("Humanoid", model)
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        hum.MaxHealth = 100
        hum.Health = 100
    end)
    
    pcall(function()
        local bp = Instance.new("BodyPosition", root)
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.P = 25000
        bp.D = 1200
    end)
    
    pcall(function()
        local bg = Instance.new("BodyGyro", root)
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 25000
    end)
    
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
            
            pcall(function()
                bp.Position = targetCF.Position
                bg.CFrame = targetCF
            end)
        end
    end)
    
    ModifyServerSettings()
    FreezePlayerAnimation()
    
    print("[STAND] Stand created and player frozen")
end

local function DestroyStand()
    print("[STAND] Destroying stand...")
    
    if State.FollowConnection then
        pcall(function() State.FollowConnection:Disconnect() end)
        State.FollowConnection = nil
    end
    
    if State.StandModel then
        pcall(function() State.StandModel:Destroy() end)
        State.StandModel = nil
        State.StandRoot = nil
    end
    
    RestoreServerSettings()
    UnfreezePlayerAnimation()
    
    print("[STAND] Stand destroyed")
end

local function ProcessCommand(msg)
    if not msg or msg == "" then return end
    
    msg = msg:match("^%s*(.-)%s*$") or msg
    msg = msg:lower()
    
    print("[CHAT] Received message: '" .. msg .. "'")
    
    if msg == ".s" or msg == ".summon" then
        print("[CMD] .s command detected!")
        if not State.IsSummoned then
            print("[CMD] Summoning stand...")
            State.IsSummoned = true
            CreateStand()
            Notify("STAND", "Summoned")
            print("[CMD] Stand summoned!")
        else
            print("[CMD] Stand already summoned")
        end
    elseif msg == ".uns" or msg == ".unsummon" or msg == ".vanish" then
        print("[CMD] Vanish command detected!")
        if State.IsSummoned then
            print("[CMD] Vanishing stand...")
            State.IsSummoned = false
            DestroyStand()
            Notify("STAND", "Vanished")
            print("[CMD] Stand vanished!")
        else
            print("[CMD] Stand not summoned")
        end
    end
end

print("[BOOT] Initializing Da Hood Stand Script...")

FindMainEvent()

print("[CHAT] Setting up chat hooks...")

local chatHooked = false

pcall(function()
    local TextChatService = game:GetService("TextChatService")
    if TextChatService and TextChatService.OnIncomingMessage then
        print("[CHAT] TextChatService found - connecting")
        TextChatService.OnIncomingMessage:Connect(function(message)
            print("[CHAT] TextChatService message: " .. tostring(message.Text))
            if message and message.TextSource and message.TextSource.UserId == LocalPlayer.UserId then
                ProcessCommand(message.Text)
            end
        end)
        chatHooked = true
        print("[CHAT] TextChatService hook connected")
    end
end)

pcall(function()
    if LocalPlayer and LocalPlayer.Chatted then
        print("[CHAT] LocalPlayer.Chatted found - connecting")
        LocalPlayer.Chatted:Connect(function(msg)
            print("[CHAT] LocalPlayer.Chatted message: " .. tostring(msg))
            ProcessCommand(msg)
        end)
        chatHooked = true
        print("[CHAT] LocalPlayer.Chatted hook connected")
    end
end)

if not chatHooked then
    print("[CHAT] WARNING: No chat hook connected!")
end

pcall(function()
    if LocalPlayer then
        LocalPlayer.CharacterAdded:Connect(function()
            print("[CHARACTER] Respawn detected")
            task.wait(1)
            if State.IsSummoned then
                print("[CHARACTER] Recreating stand after respawn")
                CreateStand()
            end
        end)
    end
end)

ResetChatToDefault()

print("[STAND] Ready - Type .s to summon")
Notify("STAND", "Loaded - Type .s to summon")
