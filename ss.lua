--[[
DUAL-MODE BOOTSTRAP - Works in ALL executors
Supports: loadstring executors AND non-loadstring executors
Architecture: Stando/Moonstand compatible
FIXED: Pure LocalPlayer.Chatted, ZERO UI dependencies
]]

local DUAL_MODE_BOOT = {}
local SCRIPT_GUID = "SS_DUAL_MODE_" .. tostring(math.random(100000, 999999))
local EXECUTION_GUARD = getgenv()[SCRIPT_GUID]

if EXECUTION_GUARD then
    print("[BOOT] Script already running - aborting duplicate")
    return
end

getgenv()[SCRIPT_GUID] = true

local OWNER_NAME = "Mahdirml123i"
local LOADSTRING_SUPPORTED = false
local FALLBACK_MODE = false

local function DetectLoadstring()
    local hasLoadstring = false
    pcall(function()
        if typeof(loadstring) == "function" then
            hasLoadstring = true
        end
    end)
    return hasLoadstring
end

LOADSTRING_SUPPORTED = DetectLoadstring()

if LOADSTRING_SUPPORTED then
    print("[DUAL MODE] loadstring supported - normal execution")
else
    print("[DUAL MODE] loadstring NOT supported - fallback require mode")
    FALLBACK_MODE = true
end

local MAIN_SCRIPT_SOURCE = [[
local OWNER_NAME = "Mahdirml123i"

local function VerifyOwnerInServer()
    local ownerFound = false
    
    pcall(function()
        local Players = game:GetService("Players")
        if not Players then return end
        
        local LocalPlayer = Players.LocalPlayer
        if not LocalPlayer then return end
        
        if LocalPlayer.Name:lower() == OWNER_NAME:lower() then
            ownerFound = true
        end
    end)
    
    if not ownerFound then
        print("[SYSTEM] Owner '" .. OWNER_NAME .. "' not verified - script idle")
        return false
    end
    
    print("[OWNER] Verified: " .. OWNER_NAME)
    return true
end

if not VerifyOwnerInServer() then
    return
end

local function FAST_BOOT()
    local localPlayer = nil
    pcall(function()
        localPlayer = game:GetService("Players").LocalPlayer
    end)
    
    if not localPlayer then
        print("[BOOT] LocalPlayer not available")
        return false
    end
    
    print("[BOOT] Ready")
    return true
end

if not FAST_BOOT() then
    print("[FATAL] Fast boot failed")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local State = {
    IsSummoned = false,
    CurrentStand = "Star Platinum",
    FollowMode = "Back",
    AttackMode = "Combat",
    Target = nil,
    AutoKill = false,
    Resolver = true,
    BarrageActive = false,
    BarrageConnection = nil,
    Connections = {},
    StandModel = nil,
    StandRoot = nil,
    StandBP = nil,
    StandBG = nil,
    LastAttackTime = 0,
    LastBarrageTime = 0,
    FollowConnection = nil,
    ResolverConnection = nil,
    LastTargetLossNotify = 0,
    AutoKillStartTime = 0,
    ConsecutiveAttackFailures = 0,
    CombatDisabled = false,
    BarrageHitCount = 0,
    LastBarrageHitTime = 0,
    BarrageDisabled = false,
    TargetHealthHistory = {},
    LastHealthCheckTime = 0,
    NoEffectCounter = 0,
    BarrageEffectivenessNotified = false,
    LastAttackAttemptTime = 0,
    BarrageConfirmedEffects = 0,
    SingleAttackConfirmedEffects = 0,
    BarrageValidationStartTime = 0,
    SingleAttackValidationStartTime = 0,
    HasConfirmedSingleAttack = false
}

local Config = {
    Prefix = ".",
    FollowOffsets = {
        Back = CFrame.new(-2.5, 2.5, 3.5),
        Left = CFrame.new(-5, 2, 0),
        Right = CFrame.new(5, 2, 0),
        Under = CFrame.new(0, -8, 0),
        Alt = CFrame.new(0, 5, 5),
        Upright = CFrame.new(4, 7, 0),
        Upleft = CFrame.new(-4, 7, 0),
        Upcenter = CFrame.new(0, 10, 0)
    },
    AttackModes = {
        Combat = { range = 2.8, attackSpeed = 0.05, minRange = 1.0, maxRange = 4.0 },
        Knife = { range = 1.5, attackSpeed = 0.03, minRange = 0.5, maxRange = 2.5 },
        Whip = { range = 5.0, attackSpeed = 0.08, minRange = 2.0, maxRange = 7.0 },
        Pitch = { range = 3.5, attackSpeed = 0.06, minRange = 1.5, maxRange = 5.5 },
        Sign = { range = 4.0, attackSpeed = 0.07, minRange = 1.5, maxRange = 6.0 }
    },
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
    },
    AutoKillMaxTimeout = 30,
    AutoKillMaxDistance = 500,
    AttackFailureThreshold = 10,
    HealthCheckInterval = 0.3,
    NoEffectThreshold = 5,
    BarrageValidationWindow = 3.0,
    SingleAttackValidationWindow = 3.0,
    BarrageMinEffectivenessRatio = 1.2,
    CausalityWindow = 0.5
}

local function Notify(title, text)
    if not title or not text then return end
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
            local vName = v.Name
            local vDisplayName = v.DisplayName
            if vName and vDisplayName then
                if vName:lower():sub(1, #name) == name or vDisplayName:lower():sub(1, #name) == name then
                    result = v
                    break
                end
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
    local root = SafeGetRoot(char)
    return root ~= nil
end

local function ClampRange(range, minRange, maxRange)
    return math.max(minRange, math.min(range, maxRange))
end

local function GetTargetHumanoid(player)
    if not IsPlayerValid(player) then return nil end
    local hum = nil
    pcall(function()
        hum = player.Character:FindFirstChildOfClass("Humanoid")
    end)
    return hum
end

local ServerAssist = {
    CombatQueue = {},
    ConfirmedHits = {},
    LastConfirmedTime = 0,
    DynamicCooldown = 0.05,
    BaseCooldown = 0.05,
    FailureCount = 0,
    SuccessCount = 0,
    LastSuccessfulToken = "Punch",
    LastSuccessfulDistance = 2.8,
    ServerTickAlignment = 0,
    HitConfirmationThreshold = 0.1,
    AdaptiveMode = false,
    AdaptiveModeStartTime = 0,
    RemoteIntelligence = {
        ["Punch"] = { successes = 0, failures = 0, avgDistance = 2.8 },
        ["Heavy"] = { successes = 0, failures = 0, avgDistance = 2.8 }
    }
}

function ServerAssist:QueueAction(targetPlayer, actionToken, distance)
    if not targetPlayer or not IsPlayerValid(targetPlayer) then return false end
    
    table.insert(self.CombatQueue, {
        targetPlayer = targetPlayer,
        actionToken = actionToken,
        distance = distance,
        queueTime = tick(),
        retryCount = 0,
        maxRetries = 2,
        confirmed = false
    })
    
    return true
end

function ServerAssist:ProcessQueue()
    local now = tick()
    local processed = {}
    
    for i, action in ipairs(self.CombatQueue) do
        if not action.confirmed and (now - action.queueTime) < 1.0 then
            if (now - self.LastConfirmedTime) >= self.DynamicCooldown then
                local success = self:FireWithIntelligence(action)
                
                if success then
                    action.confirmed = true
                    self.SuccessCount = self.SuccessCount + 1
                    self.FailureCount = 0
                    self.LastConfirmedTime = now
                    self.LastSuccessfulToken = action.actionToken
                    self.LastSuccessfulDistance = action.distance
                    
                    self.RemoteIntelligence[action.actionToken].successes = 
                        self.RemoteIntelligence[action.actionToken].successes + 1
                    
                    table.insert(processed, i)
                else
                    action.retryCount = action.retryCount + 1
                    self.FailureCount = self.FailureCount + 1
                    
                    if action.retryCount >= action.maxRetries then
                        table.insert(processed, i)
                    end
                    
                    self.RemoteIntelligence[action.actionToken].failures = 
                        self.RemoteIntelligence[action.actionToken].failures + 1
                end
            end
        elseif (now - action.queueTime) >= 1.0 then
            table.insert(processed, i)
        end
    end
    
    for i = #processed, 1, -1 do
        table.remove(self.CombatQueue, processed[i])
    end
    
    self:UpdateAdaptiveCooldown()
end

function ServerAssist:FireWithIntelligence(action)
    if not RemoteManager.Primary then return false end
    if not IsPlayerValid(action.targetPlayer) then return false end
    
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    
    local myRoot = SafeGetRoot(myChar)
    local targetChar = action.targetPlayer.Character
    if not targetChar then return false end
    
    local targetRoot = SafeGetRoot(targetChar)
    if not myRoot or not targetRoot then return false end
    
    local preHitHealth = GetTargetHumanoid(action.targetPlayer)
    if not preHitHealth then return false end
    preHitHealth = preHitHealth.Health
    
    local success = pcall(function()
        if RemoteManager.Primary and typeof(RemoteManager.Primary.FireServer) == "function" then
            RemoteManager.Primary:FireServer(
                "Combat",
                action.actionToken,
                myChar,
                targetChar,
                targetRoot.Position
            )
        end
    end)
    
    if not success then return false end
    
    task.wait(0.02)
    
    local postHitHealth = GetTargetHumanoid(action.targetPlayer)
    if postHitHealth then
        postHitHealth = postHitHealth.Health
        local healthDelta = preHitHealth - postHitHealth
        
        if healthDelta > self.HitConfirmationThreshold then
            self.ConfirmedHits[action.targetPlayer.UserId] = {
                time = tick(),
                damage = healthDelta,
                token = action.actionToken
            }
            return true
        end
    end
    
    return false
end

function ServerAssist:UpdateAdaptiveCooldown()
    local totalAttempts = self.SuccessCount + self.FailureCount
    
    if totalAttempts > 0 then
        local successRate = self.SuccessCount / totalAttempts
        
        if successRate > 0.85 then
            self.DynamicCooldown = math.max(0.03, self.BaseCooldown - 0.02)
            self.AdaptiveMode = false
        elseif successRate < 0.5 then
            self.DynamicCooldown = self.BaseCooldown + 0.03
            
            if not self.AdaptiveMode then
                self.AdaptiveMode = true
                self.AdaptiveModeStartTime = tick()
            end
        else
            self.DynamicCooldown = self.BaseCooldown
            self.AdaptiveMode = false
        end
    end
end

function ServerAssist:GetBestActionToken(targetPlayer)
    if not IsPlayerValid(targetPlayer) then return "Punch" end
    
    local hum = GetTargetHumanoid(targetPlayer)
    if not hum then return "Punch" end
    
    local intel = self.RemoteIntelligence
    local punchSuccessRate = intel["Punch"].successes / math.max(1, intel["Punch"].successes + intel["Punch"].failures)
    local heavySuccessRate = intel["Heavy"].successes / math.max(1, intel["Heavy"].successes + intel["Heavy"].failures)
    
    if heavySuccessRate > punchSuccessRate and hum.Health <= 15 then
        return "Heavy"
    end
    
    return "Punch"
end

function ServerAssist:Reset()
    self.CombatQueue = {}
    self.ConfirmedHits = {}
    self.FailureCount = 0
    self.SuccessCount = 0
    self.AdaptiveMode = false
    self.DynamicCooldown = self.BaseCooldown
end

local EffectVerifier = {
    AttackQueues = {},
    LastEffectCheckTime = 0,
    EffectCheckInterval = Config.HealthCheckInterval
}

function EffectVerifier:GetOrCreateQueue(playerId)
    if not self.AttackQueues[playerId] then
        self.AttackQueues[playerId] = {}
    end
    return self.AttackQueues[playerId]
end

function EffectVerifier:RegisterAttackAttempt(player, isBarrage)
    if not IsPlayerValid(player) then return end
    
    local hum = GetTargetHumanoid(player)
    if not hum then return end
    
    local queue = self:GetOrCreateQueue(player.UserId)
    
    table.insert(queue, {
        attemptTime = tick(),
        preAttackHealth = hum.Health,
        isBarrage = isBarrage,
        consumed = false
    })
end

function EffectVerifier:CheckAndConsumeOldestEffect(player)
    if not IsPlayerValid(player) then return false end
    local hum = GetTargetHumanoid(player)
    if not hum then return false end
    
    local queue = self:GetOrCreateQueue(player.UserId)
    
    for i, attempt in ipairs(queue) do
        if attempt.consumed then
            goto continue
        end
        
        local currentTime = tick()
        local timeSinceAttempt = currentTime - attempt.attemptTime
        
        if timeSinceAttempt > Config.CausalityWindow then
            attempt.consumed = true
            goto continue
        end
        
        local healthDifference = attempt.preAttackHealth - hum.Health
        
        if healthDifference > 0 then
            attempt.consumed = true
            return true, attempt.isBarrage
        end
        
        ::continue::
    end
    
    return false, nil
end

function EffectVerifier:CleanupExpiredAttempts(player)
    local queue = self:GetOrCreateQueue(player.UserId)
    local currentTime = tick()
    
    local i = 1
    while i <= #queue do
        local attempt = queue[i]
        if attempt.consumed or (currentTime - attempt.attemptTime > Config.CausalityWindow) then
            table.remove(queue, i)
        else
            i = i + 1
        end
    end
end

function EffectVerifier:ResetTracking(player)
    if player then
        self.AttackQueues[player.UserId] = nil
    else
        self.AttackQueues = {}
    end
end

local RemoteManager = {
    Primary = nil,
    RemoteFound = false,
    ConsecutiveFailures = 0,
    LastFireTime = 0,
    FireCooldown = 0.01,
    LastStompTime = 0,
    StompCooldown = 2.0
}

function RemoteManager:Scan()
    if self.RemoteFound then return end
    
    pcall(function()
        local mainEvent = ReplicatedStorage:FindFirstChild("MainEvent")
        if mainEvent and (mainEvent:IsA("RemoteEvent") or mainEvent:IsA("RemoteFunction")) then
            if typeof(mainEvent.FireServer) == "function" then
                self.Primary = mainEvent
                self.RemoteFound = true
                print("[REMOTE] Found: MainEvent (Da Hood)")
                return
            end
        end
        
        local combatKeywords = {"attack", "damage", "hit", "punch", "knife", "stomp", "carry", "grab", "knock", "down", "combat", "action", "input", "fire", "event"}
        
        local function scanRecursive(parent, depth)
            if depth > 10 then return end
            
            pcall(function()
                for _, obj in pairs(parent:GetChildren()) do
                    if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and typeof(obj.FireServer) == "function" then
                        local lowerName = obj.Name:lower()
                        for _, keyword in ipairs(combatKeywords) do
                            if lowerName:find(keyword) then
                                self.Primary = obj
                                self.RemoteFound = true
                                print("[REMOTE] Found: " .. obj.Name)
                                return
                            end
                        end
                    end
                    scanRecursive(obj, depth + 1)
                end
            end)
        end
        
        scanRecursive(ReplicatedStorage, 0)
    end)
    
    if not self.RemoteFound then
        print("[REMOTE] Not found - combat disabled")
    end
end

local function DetermineActionToken(targetPlayer)
    if not targetPlayer or not IsPlayerValid(targetPlayer) then 
        return "Punch" 
    end
    
    local hum = GetTargetHumanoid(targetPlayer)
    if not hum then 
        return "Punch" 
    end
    
    if hum.Health <= 10 then
        return "Heavy"
    end
    
    return "Punch"
end

function RemoteManager:Fire(targetPlayer)
    if not self.Primary then
        self.ConsecutiveFailures = self.ConsecutiveFailures + 1
        return false
    end
    
    if not targetPlayer or not IsPlayerValid(targetPlayer) then
        return false
    end
    
    local now = tick()
    if now - self.LastFireTime < self.FireCooldown then
        return false
    end
    self.LastFireTime = now
    
    local success = pcall(function()
        if self.Primary and typeof(self.Primary.FireServer) == "function" then
            local myChar = LocalPlayer.Character
            if not myChar then return end
            
            local myRoot = SafeGetRoot(myChar)
            local targetChar = targetPlayer.Character
            if not targetChar then return end
            
            local targetRoot = SafeGetRoot(targetChar)
            
            if not myRoot or not targetRoot then return end
            
            local actionToken = DetermineActionToken(targetPlayer)
            
            self.Primary:FireServer(
                "Combat",
                actionToken,
                myChar,
                targetChar,
                targetRoot.Position
            )
        end
    end)
    
    if success then
        self.ConsecutiveFailures = 0
    else
        self.ConsecutiveFailures = self.ConsecutiveFailures + 1
    end
    
    return success
end

function RemoteManager:AttemptStomp(targetPlayer)
    if not self.Primary then return false end
    if not targetPlayer or not IsPlayerValid(targetPlayer) then return false end
    
    local now = tick()
    if now - self.LastStompTime < self.StompCooldown then
        return false
    end
    
    local hum = GetTargetHumanoid(targetPlayer)
    if not hum then return false end
    
    if hum.Health > 5 then return false end
    
    local targetChar = targetPlayer.Character
    if not targetChar then return false end
    
    local targetRoot = SafeGetRoot(targetChar)
    if not targetRoot then return false end
    
    local velocity = targetRoot.AssemblyLinearVelocity.Magnitude
    if velocity > 10 then return false end
    
    self.LastStompTime = now
    
    local success = pcall(function()
        if self.Primary and typeof(self.Primary.FireServer) == "function" then
            self.Primary:FireServer(
                "Stomp",
                targetChar
            )
        end
    end)
    
    return success
end

function RemoteManager:CheckFailureThreshold()
    if self.ConsecutiveFailures >= Config.AttackFailureThreshold then
        if not State.CombatDisabled then
            print("[REMOTE] Disabled after " .. Config.AttackFailureThreshold .. " failures")
            State.CombatDisabled = true
        end
        return true
    end
    return false
end

local StandBuilder = {}

function StandBuilder:ValidateFollowOffset(offset)
    local pos = offset.Position
    local magnitude = pos.Magnitude
    if magnitude > 20 then
        return CFrame.new(pos.Unit * 20)
    end
    return offset
end

function StandBuilder:Cleanup()
    if State.FollowConnection then
        pcall(function() State.FollowConnection:Disconnect() end)
        State.FollowConnection = nil
    end
    
    if State.StandModel then
        pcall(function() State.StandModel:Destroy() end)
    end
    
    for name, conn in pairs(State.Connections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    
    State.Connections = {}
    State.StandModel = nil
    State.StandRoot = nil
    State.StandBP = nil
    State.StandBG = nil
end

function StandBuilder:Create()
    self:Cleanup()
    
    local char = LocalPlayer.Character
    local root = SafeGetRoot(char)
    if not root then
        Notify("ERROR", "Cannot create Stand: No character root")
        return
    end

    local model = nil
    pcall(function()
        model = Instance.new("Model", workspace)
        model.Name = "RescuedStand_" .. LocalPlayer.Name
    end)
    
    if not model then
        Notify("ERROR", "Cannot create Stand model")
        return
    end
    
    State.StandModel = model

    local sRoot = nil
    pcall(function()
        sRoot = Instance.new("Part", model)
        sRoot.Name = "HumanoidRootPart"
        sRoot.Size = Vector3.new(2, 2, 1)
        sRoot.Transparency = 0.5
        sRoot.CanCollide = false
        sRoot.Material = Enum.Material.ForceField
        sRoot.Color = Color3.fromRGB(0, 255, 255)
    end)
    
    if not sRoot then
        Notify("ERROR", "Cannot create Stand root part")
        return
    end
    
    State.StandRoot = sRoot

    local hum = nil
    pcall(function()
        hum = Instance.new("Humanoid", model)
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end)

    local bp = nil
    pcall(function()
        bp = Instance.new("BodyPosition", sRoot)
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.P = 25000
        bp.D = 1200
    end)
    
    if not bp then
        Notify("ERROR", "Cannot create BodyPosition")
        return
    end
    
    State.StandBP = bp

    local bg = nil
    pcall(function()
        bg = Instance.new("BodyGyro", sRoot)
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 25000
    end)
    
    if not bg then
        Notify("ERROR", "Cannot create BodyGyro")
        return
    end
    
    State.StandBG = bg

    pcall(function()
        if sRoot and typeof(sRoot.SetNetworkOwner) == "function" then
            sRoot:SetNetworkOwner(LocalPlayer)
        end
    end)

    self:SetupFollowLoop()
end

function StandBuilder:SetupFollowLoop()
    if State.FollowConnection then
        pcall(function() State.FollowConnection:Disconnect() end)
    end
    
    State.FollowConnection = RunService.Heartbeat:Connect(function()
        if not State.IsSummoned or not State.StandRoot or not State.StandBP or not State.StandBG then
            return
        end
        
        local myChar = LocalPlayer.Character
        if not myChar then return end
        
        local myRoot = SafeGetRoot(myChar)
        if not myRoot then return end
        
        local offset = Config.FollowOffsets[State.FollowMode] or Config.FollowOffsets.Back
        offset = self:ValidateFollowOffset(offset)
        local targetCF = myRoot.CFrame * offset
        
        pcall(function()
            State.StandBP.Position = targetCF.Position
            State.StandBG.CFrame = targetCF
        end)
    end)
end

local Combat = {}

function Combat:GetAttackConfig()
    return Config.AttackModes[State.AttackMode] or Config.AttackModes.Combat
end

function Combat:ValidateRange(range)
    local config = self:GetAttackConfig()
    return ClampRange(range, config.minRange, config.maxRange)
end

function Combat:Attack(target, isBarrage)
    if State.CombatDisabled then return false end
    if not IsPlayerValid(target) then return false end
    if not State.IsSummoned then return false end
    
    local config = self:GetAttackConfig()
    if not config then return false end
    
    local now = tick()
    
    if now - State.LastAttackTime < config.attackSpeed then
        return false
    end
    State.LastAttackTime = now
    
    EffectVerifier:RegisterAttackAttempt(target, isBarrage)
    State.LastAttackAttemptTime = now
    
    local actionToken = ServerAssist:GetBestActionToken(target)
    local validatedRange = self:ValidateRange(config.range)
    
    ServerAssist:QueueAction(target, actionToken, validatedRange)
    
    if ServerAssist.SuccessCount > 0 then
        State.ConsecutiveAttackFailures = 0
    else
        State.ConsecutiveAttackFailures = State.ConsecutiveAttackFailures + 1
    end
    
    if State.ConsecutiveAttackFailures >= Config.AttackFailureThreshold then
        if not State.CombatDisabled then
            print("[REMOTE] Disabled after " .. Config.AttackFailureThreshold .. " failures")
            State.CombatDisabled = true
        end
    end
    
    return true
end

function Combat:Barrage()
    if State.CombatDisabled then return false end
    if State.BarrageDisabled then return false end
    if not State.Target or not IsPlayerValid(State.Target) then return false end
    if not State.IsSummoned then return false end
    if State.BarrageActive then return false end
    
    State.BarrageActive = true
    State.BarrageConfirmedEffects = 0
    State.BarrageValidationStartTime = tick()
    State.BarrageEffectivenessNotified = false
    
    if State.BarrageConnection then
        pcall(function() State.BarrageConnection:Disconnect() end)
    end
    
    local barrageStartTime = tick()
    
    State.BarrageConnection = RunService.Heartbeat:Connect(function()
        if not State.BarrageActive then
            if State.BarrageConnection then
                pcall(function() State.BarrageConnection:Disconnect() end)
                State.BarrageConnection = nil
            end
            return
        end
        
        if not State.Target or not IsPlayerValid(State.Target) or not State.IsSummoned then
            State.BarrageActive = false
            if State.BarrageConnection then
                pcall(function() State.BarrageConnection:Disconnect() end)
                State.BarrageConnection = nil
            end
            return
        end
        
        local elapsedTime = tick() - barrageStartTime
        
        if elapsedTime > Config.BarrageValidationWindow and not State.BarrageEffectivenessNotified then
            State.BarrageEffectivenessNotified = true
            
            if State.SingleAttackConfirmedEffects > 0 then
                local effectivenessRatio = State.BarrageConfirmedEffects / State.SingleAttackConfirmedEffects
                
                if effectivenessRatio < Config.BarrageMinEffectivenessRatio then
                    State.BarrageActive = false
                    State.BarrageDisabled = true
                    if State.BarrageConnection then
                        pcall(function() State.BarrageConnection:Disconnect() end)
                        State.BarrageConnection = nil
                    end
                    Notify("BARRAGE", "Disabled: no effectiveness gain")
                    return
                end
            end
        end
        
        local config = self:GetAttackConfig()
        local now = tick()
        if now - State.LastBarrageTime >= config.attackSpeed then
            State.LastBarrageTime = now
            self:Attack(State.Target, true)
        end
    end)
    
    return true
end

function Combat:StopBarrage()
    State.BarrageActive = false
    if State.BarrageConnection then
        pcall(function() State.BarrageConnection:Disconnect() end)
        State.BarrageConnection = nil
    end
end

local Router = {}

function Router:NormalizeMessage(msg)
    if not msg or msg == "" then return "" end
    msg = msg:match("^%s*(.-)%s*$") or msg
    return msg:lower()
end

function Router:ParseCommand(msg)
    if not msg or msg == "" then return nil, nil end
    
    local normalized = self:NormalizeMessage(msg)
    if not normalized or normalized == "" then return nil, nil end
    
    local prefix = Config.Prefix
    if normalized:sub(1, 1) ~= prefix then
        return nil, nil
    end
    
    local cmdPart = normalized:sub(2)
    local args = {}
    
    for arg in cmdPart:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    if #args == 0 then return nil, nil end
    
    local cmd = args[1]
    return cmd, args
end

function Router:Route(msg)
    if not msg or msg == "" then return end
    
    local cmd, args = self:ParseCommand(msg)
    
    if not cmd then
        return
    end
    
    if cmd == "s" or cmd == "summon" then
        if not State.IsSummoned then
            State.IsSummoned = true
            State.CombatDisabled = false
            State.BarrageDisabled = false
            State.ConsecutiveAttackFailures = 0
            State.NoEffectCounter = 0
            State.SingleAttackConfirmedEffects = 0
            State.BarrageConfirmedEffects = 0
            State.SingleAttackValidationStartTime = tick()
            State.HasConfirmedSingleAttack = false
            EffectVerifier:ResetTracking()
            StandBuilder:Create()
            Notify("SYSTEM", "Stand Summoned")
        end
    
    elseif cmd == "vanish" then
        if State.IsSummoned then
            State.IsSummoned = false
            Combat:StopBarrage()
            State.AutoKill = false
            State.Target = nil
            Notify("SYSTEM", "Stand Vanished")
        end
    
    elseif cmd == "combat" then
        State.AttackMode = "Combat"
        Notify("MODE", "Combat | Range: 2.8 | Speed: 0.05s")
    
    elseif cmd == "knife" then
        State.AttackMode = "Knife"
        Notify("MODE", "Knife | Range: 1.5 | Speed: 0.03s")
    
    elseif cmd == "whip" then
        State.AttackMode = "Whip"
        Notify("MODE", "Whip | Range: 5.0 | Speed: 0.08s")
    
    elseif cmd == "pitch" then
        State.AttackMode = "Pitch"
        Notify("MODE", "Pitch | Range: 3.5 | Speed: 0.06s")
    
    elseif cmd == "sign" then
        State.AttackMode = "Sign"
        Notify("MODE", "Sign | Range: 4.0 | Speed: 0.07s")
    
    elseif cmd == "barrage" or cmd == "ora" or cmd == "muda" then
        if State.CombatDisabled then
            Notify("ERROR", "Combat disabled")
        elseif State.BarrageDisabled then
            Notify("ERROR", "Barrage disabled")
        elseif not State.IsSummoned then
            Notify("ERROR", "Stand must be summoned")
        elseif State.Target and IsPlayerValid(State.Target) then
            if Combat:Barrage() then
                Notify("BARRAGE", "Started on " .. State.Target.Name)
            else
                Notify("ERROR", "Barrage already active")
            end
        else
            Notify("ERROR", "No valid target")
        end
    
    elseif cmd == "stop" or cmd == "unattack" then
        Combat:StopBarrage()
        State.AutoKill = false
        State.Target = nil
        Notify("SYSTEM", "Attack stopped")
    
    elseif cmd == "bring" then
        local targetName = args[2]
        if targetName then
            local p = GetPlayer(targetName)
            if p and IsPlayerValid(p) then
                local r = SafeGetRoot(p.Character)
                local myR = SafeGetRoot(LocalPlayer.Character)
                if r and myR then
                    r.CFrame = myR.CFrame
                    Notify("BRING", "Brought " .. p.Name)
                end
            else
                Notify("ERROR", "Player not found")
            end
        else
            Notify("ERROR", "Usage: .bring <player>")
        end
    
    elseif cmd == "autokill" then
        local targetName = args[2]
        if targetName then
            local p = GetPlayer(targetName)
            if State.CombatDisabled then
                Notify("ERROR", "Combat disabled")
            elseif not State.IsSummoned then
                Notify("ERROR", "Stand must be summoned")
            elseif p and IsPlayerValid(p) then
                State.Target = p
                State.AutoKill = true
                State.AutoKillStartTime = tick()
                EffectVerifier:ResetTracking(p)
                Notify("AUTOKILL", "Targeting: " .. p.Name)
            else
                Notify("ERROR", "Player not found")
            end
        else
            Notify("ERROR", "Usage: .autokill <player>")
        end
    
    elseif cmd == "smite" then
        local targetName = args[2]
        if targetName then
            local p = GetPlayer(targetName)
            if p and IsPlayerValid(p) then
                local r = SafeGetRoot(p.Character)
                if r then
                    local v = nil
                    pcall(function()
                        v = Instance.new("BodyVelocity", r)
                        v.Velocity = Vector3.new(0, 10000, 0)
                        v.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    end)
                    if v then
                        task.wait(0.15)
                        pcall(function() v:Destroy() end)
                        Notify("SMITE", "Smited " .. p.Name)
                    end
                end
            else
                Notify("ERROR", "Player not found")
            end
        else
            Notify("ERROR", "Usage: .smite <player>")
        end
    
    elseif cmd == "tp" or cmd == "to" or cmd == "goto" then
        local loc = args[2]
        if loc and Config.Locations[loc] then
            local myR = SafeGetRoot(LocalPlayer.Character)
            if myR then
                pcall(function()
                    myR.CFrame = CFrame.new(Config.Locations[loc])
                end)
                Notify("TELEPORT", "Teleported to " .. loc)
            end
        else
            Notify("ERROR", "Location not found")
        end
    
    else
        local followModes = {
            ["back"] = "Back",
            ["left"] = "Left",
            ["right"] = "Right",
            ["under"] = "Under",
            ["alt"] = "Alt",
            ["upright"] = "Upright",
            ["upleft"] = "Upleft",
            ["upcenter"] = "Upcenter"
        }
        
        if followModes[cmd] then
            State.FollowMode = followModes[cmd]
            Notify("FOLLOW", "Mode: " .. followModes[cmd])
        end
    end
end

RunService.Heartbeat:Connect(function()
    pcall(function()
        ServerAssist:ProcessQueue()
    end)
end)

RunService.Heartbeat:Connect(function()
    pcall(function()
        local now = tick()
        
        if now - EffectVerifier.LastEffectCheckTime >= EffectVerifier.EffectCheckInterval then
            EffectVerifier.LastEffectCheckTime = now
            
            if State.Target and IsPlayerValid(State.Target) and (State.AutoKill or State.BarrageActive) then
                local hasEffect, wasBarrage = EffectVerifier:CheckAndConsumeOldestEffect(State.Target)
                EffectVerifier:CleanupExpiredAttempts(State.Target)
                
                if hasEffect then
                    State.NoEffectCounter = 0
                    if wasBarrage then
                        State.BarrageConfirmedEffects = State.BarrageConfirmedEffects + 1
                    else
                        State.SingleAttackConfirmedEffects = State.SingleAttackConfirmedEffects + 1
                        State.HasConfirmedSingleAttack = true
                    end
                else
                    State.NoEffectCounter = State.NoEffectCounter + 1
                end
                
                if State.NoEffectCounter >= Config.NoEffectThreshold and not State.CombatDisabled then
                    if ServerAssist.AdaptiveMode then
                        print("[COMBAT] Adaptive mode: slowing down")
                    else
                        print("[COMBAT] Entering adaptive mode")
                        ServerAssist.AdaptiveMode = true
                        ServerAssist.AdaptiveModeStartTime = tick()
                    end
                end
            end
        end
    end)
end)

local lastResolverTime = tick()

if State.ResolverConnection then
    pcall(function() State.ResolverConnection:Disconnect() end)
end

State.ResolverConnection = RunService.Heartbeat:Connect(function()
    pcall(function()
        local currentTime = tick()
        local deltaTime = math.min(currentTime - lastResolverTime, 0.1)
        lastResolverTime = currentTime
        
        if State.AutoKill and State.IsSummoned then
            local now = tick()
            local engagementTime = now - State.AutoKillStartTime
            
            if engagementTime > Config.AutoKillMaxTimeout then
                State.AutoKill = false
                State.Target = nil
                Notify("AUTOKILL", "Timeout")
                return
            end
            
            if not IsPlayerValid(State.Target) then
                State.AutoKill = false
                State.Target = nil
                if now - State.LastTargetLossNotify > 2 then
                    Notify("AUTOKILL", "Target lost")
                    State.LastTargetLossNotify = now
                end
                return
            end
            
            local tRoot = SafeGetRoot(State.Target.Character)
            local myRoot = SafeGetRoot(LocalPlayer.Character)
            
            if not tRoot or not myRoot then
                State.AutoKill = false
                State.Target = nil
                return
            end
            
            local distance = (tRoot.Position - myRoot.Position).Magnitude
            
            if distance > Config.AutoKillMaxDistance then
                State.AutoKill = false
                State.Target = nil
                Notify("AUTOKILL", "Too far")
                return
            end
            
            local config = Combat:GetAttackConfig()
            if not config then return end
            
            local validatedRange = Combat:ValidateRange(config.range)
            
            local targetPos = tRoot.CFrame * CFrame.new(0, 0, validatedRange)
            
            if State.Resolver and tRoot.AssemblyLinearVelocity.Magnitude > 2 then
                local velocity = tRoot.AssemblyLinearVelocity
                
                local successRate = ServerAssist.SuccessCount / math.max(1, ServerAssist.SuccessCount + ServerAssist.FailureCount)
                local predictionFactor = math.min(deltaTime * (6 + successRate * 4), 0.25)
                
                local predictedOffset = velocity * predictionFactor
                
                local predictionMagnitude = predictedOffset.Magnitude
                if predictionMagnitude > 4 then
                    predictedOffset = predictedOffset.Unit * 4
                end
                
                targetPos = targetPos + predictedOffset
            end
            
            local distanceToTarget = (myRoot.Position - tRoot.Position).Magnitude
            if distanceToTarget < 100 then
                pcall(function()
                    if myRoot and myRoot.Parent then
                        myRoot.CFrame = targetPos
                    end
                end)
            end
            
            Combat:Attack(State.Target, false)
            
            if IsPlayerValid(State.Target) and ServerAssist.SuccessCount > 3 then
                RemoteManager:AttemptStomp(State.Target)
            end
        elseif State.AutoKill and not State.IsSummoned then
            State.AutoKill = false
            State.Target = nil
            ServerAssist:Reset()
        end
    end)
end)

State.IsSummoned = false
State.CombatDisabled = false
State.BarrageDisabled = false
State.ConsecutiveAttackFailures = 0
State.NoEffectCounter = 0
State.SingleAttackConfirmedEffects = 0
State.BarrageConfirmedEffects = 0
State.SingleAttackValidationStartTime = tick()
State.Target = nil
State.AutoKill = false
State.BarrageActive = false
State.HasConfirmedSingleAttack = false
EffectVerifier:ResetTracking()

print("[SYSTEM] Ready")

task.spawn(function()
    RemoteManager:Scan()
end)

if LocalPlayer then
    pcall(function()
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1.5)
            Combat:StopBarrage()
            State.AutoKill = false
            State.Target = nil
            State.ConsecutiveAttackFailures = 0
            State.NoEffectCounter = 0
            EffectVerifier:ResetTracking()
            ServerAssist:Reset()
            if State.IsSummoned then
                StandBuilder:Create()
            end
        end)
    end)
end

pcall(function()
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        if player == State.Target then
            State.AutoKill = false
            State.Target = nil
            Combat:StopBarrage()
            EffectVerifier:ResetTracking(player)
            ServerAssist:Reset()
            Notify("AUTOKILL", "Target left")
        end
    end)
end)

local function HandleChat(msg)
    if msg and msg ~= "" then
        Router:Route(msg)
    end
end

pcall(function()
    local TextChatService = game:GetService("TextChatService")
    if TextChatService then
        TextChatService.OnIncomingMessage:Connect(function(message)
            if message.TextSource and message.TextSource.UserId == LocalPlayer.UserId then
                HandleChat(message.Text)
            end
        end)
    end
end)

pcall(function()
    if LocalPlayer then
        LocalPlayer.Chatted:Connect(function(msg)
            HandleChat(msg)
        end)
    end
end)
]]

local function ExecuteViaLoadstring()
    print("[DUAL MODE] Executing via loadstring...")
    local success, err = pcall(function()
        local chunk = loadstring(MAIN_SCRIPT_SOURCE)
        if chunk then
            chunk()
        end
    end)
    
    if not success then
        print("[ERROR] loadstring execution failed: " .. tostring(err))
        return false
    end
    
    return true
end

local function ExecuteViaModuleScript()
    print("[DUAL MODE] Executing via ModuleScript fallback...")
    
    local success, result = pcall(function()
        local tempModule = Instance.new("ModuleScript")
        tempModule.Source = MAIN_SCRIPT_SOURCE
        tempModule.Parent = game:GetService("ServerScriptService") or workspace
        
        local execSuccess, execErr = pcall(function()
            require(tempModule)
        end)
        
        task.wait(0.1)
        pcall(function()
            tempModule:Destroy()
        end)
        
        if not execSuccess then
            print("[ERROR] ModuleScript execution failed: " .. tostring(execErr))
            return false
        end
        
        return true
    end)
    
    if not success then
        print("[ERROR] ModuleScript fallback failed: " .. tostring(result))
        return false
    end
    
    return result
end

if LOADSTRING_SUPPORTED then
    if not ExecuteViaLoadstring() then
        print("[FALLBACK] loadstring failed, attempting ModuleScript...")
        ExecuteViaModuleScript()
    end
else
    ExecuteViaModuleScript()
end

print("[BOOT] Ready")
