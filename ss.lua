local SCRIPT_ID = "DAHOOD_STAND_" .. tostring(math.random(100000, 999999))
if getgenv()[SCRIPT_ID] then return end
getgenv()[SCRIPT_ID] = true

local DA_HOOD_PLACE_ID = 2627663541
if game.PlaceId ~= 2627663541 then
    print("[STAND] Not in Da Hood - aborting")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    print("[STAND] No LocalPlayer")
    return
end

local State = {
    IsSummoned = false,
    Target = nil,
    AutoKill = false,
    StandModel = nil,
    StandRoot = nil,
    FollowConnection = nil,
    AutoKillConnection = nil,
    LastAttackTime = 0,
    AttackSpeed = 0.05
}

local Config = {
    Locations = {
        bank = Vector3.new(-402, 21, -299),
        roof = Vector3.new(-454, 50, -284),
        club = Vector3.new(-265, 0, -411),
        casino = Vector3.new(-864, 21, -143),
        ufo = Vector3.new(72, 140, -680),
        mil = Vector3.new(-500, 21, -600),
        school = Vector3.new(-524, 21, 285),
        shop1 = Vector3.new(-600, 21, -300),
        shop2 = Vector3.new(-200, 21, -500),
        rev = Vector3.new(-300, 21, -400),
        db = Vector3.new(-100, 21, -100),
        pool = Vector3.new(-700, 21, -700),
        armor = Vector3.new(-607, 21, -258),
        subway = Vector3.new(-800, 21, -800),
        sewer = Vector3.new(-900, 21, -900),
        wheel = Vector3.new(-1000, 21, -1000),
        basketball = Vector3.new(-1100, 21, -1100),
        boxing = Vector3.new(-1200, 21, -1200),
        bull = Vector3.new(-1300, 21, -1300),
        safe1 = Vector3.new(-300, 21, -400)
    }
}

local RemoteManager = {
    Primary = nil,
    Found = false
}

local function SafeGetRoot(char)
    if not char or not char.Parent then return nil end
    local root = nil
    pcall(function()
        root = char:FindFirstChild("HumanoidRootPart")
    end)
    return root
end

local function GetPlayer(name)
    if not name or name == "" then return nil end
    name = name:lower()
    local result = nil
    pcall(function()
        for _, v in pairs(Players:GetPlayers()) do
            if v.Name:lower():find(name, 1, true) or v.DisplayName:lower():find(name, 1, true) then
                result = v
                break
            end
        end
    end)
    return result
end

local function IsPlayerValid(player)
    if not player or not player.Parent then return false end
    local char = nil
    pcall(function()
        char = player.Character
    end)
    if not char then return false end
    return SafeGetRoot(char) ~= nil
end

local function GetTargetHumanoid(player)
    if not IsPlayerValid(player) then return nil end
    local hum = nil
    pcall(function()
        hum = player.Character:FindFirstChildOfClass("Humanoid")
    end)
    return hum
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

function RemoteManager:Scan()
    if self.Found then return end
    
    pcall(function()
        local mainEvent = ReplicatedStorage:FindFirstChild("MainEvent")
        if mainEvent and (mainEvent:IsA("RemoteEvent") or mainEvent:IsA("RemoteFunction")) then
            if typeof(mainEvent.FireServer) == "function" then
                self.Primary = mainEvent
                self.Found = true
                print("[REMOTE] Found MainEvent")
                return
            end
        end
        
        local keywords = {"attack", "damage", "hit", "punch", "combat", "action"}
        local function scan(parent, depth)
            if depth > 8 then return end
            pcall(function()
                for _, obj in pairs(parent:GetChildren()) do
                    if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and typeof(obj.FireServer) == "function" then
                        local name = obj.Name:lower()
                        for _, kw in ipairs(keywords) do
                            if name:find(kw) then
                                self.Primary = obj
                                self.Found = true
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
    end)
end

local function CreateStand()
    print("[STAND:CREATE] Starting stand creation")
    
    if State.StandModel then
        print("[STAND:CREATE] Destroying existing stand model")
        pcall(function() State.StandModel:Destroy() end)
    end
    
    local model = nil
    pcall(function()
        model = Instance.new("Model", workspace)
        model.Name = "Stand_" .. LocalPlayer.Name
        print("[STAND:CREATE] Model created: " .. model.Name)
    end)
    
    if not model then 
        print("[STAND:CREATE] FAILED - Could not create model")
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
        print("[STAND:CREATE] Root part created")
    end)
    
    if not root then 
        print("[STAND:CREATE] FAILED - Could not create root part")
        return 
    end
    
    pcall(function()
        local hum = Instance.new("Humanoid", model)
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        print("[STAND:CREATE] Humanoid created")
    end)
    
    pcall(function()
        local bp = Instance.new("BodyPosition", root)
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.P = 25000
        bp.D = 1200
        print("[STAND:CREATE] BodyPosition created")
    end)
    
    pcall(function()
        local bg = Instance.new("BodyGyro", root)
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 25000
        print("[STAND:CREATE] BodyGyro created")
    end)
    
    pcall(function()
        if typeof(root.SetNetworkOwner) == "function" then
            root:SetNetworkOwner(LocalPlayer)
            print("[STAND:CREATE] Network owner set")
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
    
    print("[STAND:CREATE] SUCCESS - Stand created and follow loop started")
end

local function DestroyStand()
    print("[STAND:DESTROY] Starting stand destruction")
    
    if State.FollowConnection then
        pcall(function() State.FollowConnection:Disconnect() end)
        State.FollowConnection = nil
        print("[STAND:DESTROY] Follow connection disconnected")
    end
    
    if State.StandModel then
        pcall(function() State.StandModel:Destroy() end)
        State.StandModel = nil
        State.StandRoot = nil
        print("[STAND:DESTROY] Stand model destroyed")
    end
    
    print("[STAND:DESTROY] SUCCESS - Stand destroyed")
end

local function Attack(target)
    if not RemoteManager.Primary or not IsPlayerValid(target) then return end
    
    local now = tick()
    if now - State.LastAttackTime < State.AttackSpeed then return end
    State.LastAttackTime = now
    
    local myChar = LocalPlayer.Character
    if not myChar then return end
    
    local myRoot = SafeGetRoot(myChar)
    local targetChar = target.Character
    if not targetChar then return end
    
    local targetRoot = SafeGetRoot(targetChar)
    if not myRoot or not targetRoot then return end
    
    pcall(function()
        RemoteManager.Primary:FireServer("Combat", "Punch", myChar, targetChar, targetRoot.Position)
    end)
end

local function HandleCommand(msg)
    if not msg or msg == "" then 
        print("[CMD:PARSE] Empty message, ignoring")
        return 
    end
    
    msg = msg:match("^%s*(.-)%s*$") or msg
    
    if msg:sub(1, 1) ~= "." then 
        print("[CMD:PARSE] No prefix, ignoring: " .. msg)
        return 
    end
    
    local cmd = msg:sub(2):lower()
    local args = {}
    for arg in cmd:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    if #args == 0 then 
        print("[CMD:PARSE] No args after prefix, ignoring")
        return 
    end
    
    local command = args[1]
    
    print("[CMD:DISPATCH] Command: " .. command .. " | Full message: " .. msg)
    
    if command == "s" or command == "summon" then
        print("[CMD:SUMMON] Summon command received")
        print("[CMD:SUMMON] Current state - IsSummoned: " .. tostring(State.IsSummoned))
        
        if not State.IsSummoned then
            print("[CMD:SUMMON] Executing summon...")
            State.IsSummoned = true
            State.Target = nil
            State.AutoKill = false
            print("[CMD:SUMMON] State updated - IsSummoned: true")
            
            CreateStand()
            
            Notify("STAND", "Summoned")
            print("[CMD:SUMMON] SUCCESS - Stand summoned, notification sent")
        else
            print("[CMD:SUMMON] IGNORED - Already summoned")
        end
    
    elseif command == "uns" or command == "unsummon" or command == "vanish" then
        print("[CMD:VANISH] Vanish command received")
        print("[CMD:VANISH] Current state - IsSummoned: " .. tostring(State.IsSummoned))
        
        if State.IsSummoned then
            print("[CMD:VANISH] Executing vanish...")
            State.IsSummoned = false
            State.AutoKill = false
            State.Target = nil
            print("[CMD:VANISH] State updated - IsSummoned: false")
            
            DestroyStand()
            
            Notify("STAND", "Vanished")
            print("[CMD:VANISH] SUCCESS - Stand vanished, notification sent")
        else
            print("[CMD:VANISH] IGNORED - Not summoned")
        end
    
    elseif command == "autokill" then
        print("[CMD:AUTOKILL] AutoKill command received")
        
        if not State.IsSummoned then
            Notify("ERROR", "Summon stand first")
            print("[CMD:AUTOKILL] REJECTED - Stand not summoned")
            return
        end
        
        local targetName = args[2]
        if not targetName then
            Notify("ERROR", "Usage: .autokill <player>")
            print("[CMD:AUTOKILL] REJECTED - No target name provided")
            return
        end
        
        local target = GetPlayer(targetName)
        if not target or not IsPlayerValid(target) then
            Notify("ERROR", "Player not found")
            print("[CMD:AUTOKILL] REJECTED - Target player invalid: " .. tostring(targetName))
            return
        end
        
        State.Target = target
        State.AutoKill = true
        Notify("AUTOKILL", "Targeting " .. target.Name)
        print("[CMD:AUTOKILL] SUCCESS - AutoKill enabled, Target: " .. target.Name)
    
    elseif command == "stop" or command == "unstop" then
        print("[CMD:STOP] Stop command received")
        State.AutoKill = false
        State.Target = nil
        Notify("SYSTEM", "Stopped")
        print("[CMD:STOP] SUCCESS - AutoKill disabled")
    
    elseif command == "bring" then
        print("[CMD:BRING] Bring command received")
        local targetName = args[2]
        if not targetName then
            Notify("ERROR", "Usage: .bring <player>")
            print("[CMD:BRING] REJECTED - No target name provided")
            return
        end
        
        local target = GetPlayer(targetName)
        if not target or not IsPlayerValid(target) then
            Notify("ERROR", "Player not found")
            print("[CMD:BRING] REJECTED - Target player invalid: " .. tostring(targetName))
            return
        end
        
        local targetRoot = SafeGetRoot(target.Character)
        local myRoot = SafeGetRoot(LocalPlayer.Character)
        
        if targetRoot and myRoot then
            pcall(function()
                targetRoot.CFrame = myRoot.CFrame
            end)
            Notify("BRING", "Brought " .. target.Name)
            print("[CMD:BRING] SUCCESS - Brought " .. target.Name)
        else
            print("[CMD:BRING] REJECTED - Root parts invalid")
        end
    
    elseif command == "to" or command == "tp" or command == "goto" then
        print("[CMD:TP] Teleport command received")
        local locName = args[2]
        if not locName or not Config.Locations[locName] then
            Notify("ERROR", "Location not found")
            print("[CMD:TP] REJECTED - Location invalid: " .. tostring(locName))
            return
        end
        
        local myRoot = SafeGetRoot(LocalPlayer.Character)
        if myRoot then
            pcall(function()
                myRoot.CFrame = CFrame.new(Config.Locations[locName])
            end)
            Notify("TP", "Teleported to " .. locName)
            print("[CMD:TP] SUCCESS - Teleported to " .. locName)
        else
            print("[CMD:TP] REJECTED - Player root invalid")
        end
    else
        print("[CMD:DISPATCH] Unknown command: " .. command)
    end
end

print("[BOOT] Initializing Da Hood Stand Script...")

RemoteManager:Scan()

print("[CHAT] Setting up chat hooks SYNCHRONOUSLY...")

pcall(function()
    local TextChatService = game:GetService("TextChatService")
    if TextChatService then
        print("[CHAT:TCS] TextChatService found - connecting OnIncomingMessage")
        TextChatService.OnIncomingMessage:Connect(function(message)
            if message and message.TextSource and message.TextSource.UserId == LocalPlayer.UserId then
                print("[CHAT:TCS] Message received: " .. tostring(message.Text))
                HandleCommand(message.Text)
            end
        end)
        print("[CHAT:TCS] TextChatService hook connected")
    else
        print("[CHAT:TCS] TextChatService not available")
    end
end)

pcall(function()
    if LocalPlayer then
        print("[CHAT:CHATTED] LocalPlayer found - connecting Chatted signal")
        LocalPlayer.Chatted:Connect(function(msg)
            print("[CHAT:CHATTED] Message received: " .. tostring(msg))
            HandleCommand(msg)
        end)
        print("[CHAT:CHATTED] LocalPlayer.Chatted hook connected")
    else
        print("[CHAT:CHATTED] LocalPlayer not available")
    end
end)

print("[CHAT] Chat hooks established")

if State.AutoKillConnection then
    pcall(function() State.AutoKillConnection:Disconnect() end)
end

State.AutoKillConnection = RunService.Heartbeat:Connect(function()
    if not State.AutoKill or not State.IsSummoned or not State.Target then return end
    
    if not IsPlayerValid(State.Target) then
        State.AutoKill = false
        State.Target = nil
        Notify("AUTOKILL", "Target lost")
        print("[AUTOKILL] Target lost")
        return
    end
    
    local targetRoot = SafeGetRoot(State.Target.Character)
    local myRoot = SafeGetRoot(LocalPlayer.Character)
    
    if not targetRoot or not myRoot then
        State.AutoKill = false
        State.Target = nil
        print("[AUTOKILL] Root parts invalid")
        return
    end
    
    local distance = (targetRoot.Position - myRoot.Position).Magnitude
    
    if distance > 500 then
        State.AutoKill = false
        State.Target = nil
        Notify("AUTOKILL", "Too far")
        print("[AUTOKILL] Target too far: " .. tostring(distance))
        return
    end
    
    if distance < 100 then
        pcall(function()
            if myRoot and myRoot.Parent then
                myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 0, 3)
            end
        end)
    end
    
    Attack(State.Target)
end)

pcall(function()
    if LocalPlayer then
        LocalPlayer.CharacterAdded:Connect(function()
            print("[CHARACTER] Respawn detected")
            task.wait(1)
            State.AutoKill = false
            State.Target = nil
            if State.IsSummoned then
                print("[CHARACTER] Recreating stand after respawn")
                CreateStand()
            end
        end)
        print("[CHARACTER] Respawn hook established")
    end
end)

print("[STAND] Ready - Type '.s' to summon")
Notify("STAND", "Loaded - Type '.s' to summon")
