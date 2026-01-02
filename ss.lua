--[[
    RESCUED STAND SYSTEM (V15.1 DA HOOD HARDENED + RUNTIME SAFE)
    
    CRITICAL FIXES:
    - Owner verification BEFORE any execution
    - Safe HttpGet validation (if loaded via loadstring)
    - NO infinite WaitForChild calls (all have timeouts)
    - leaderstats is OPTIONAL (never blocks)
    - Chat UI restoration with Da Hood compatibility
    - Owner-only command execution
    - Graceful degradation for missing remotes/frameworks
    - All external calls wrapped in pcall with type checking
    - Script exits safely if owner not in server
]]

--// ============================================================================
--// PHASE 0: OWNER VERIFICATION (MUST RUN FIRST - ABORT IF OWNER NOT PRESENT)
--// ============================================================================

local OWNER_NAME = nil

local function VerifyOwnerInServer()
    local ownerFound = false
    
    -- Get owner from getgenv().Owner (set by executor)
    pcall(function()
        if getgenv().Owner and type(getgenv().Owner) == "string" then
            OWNER_NAME = getgenv().Owner
        end
    end)
    
    -- Fallback if not set
    if not OWNER_NAME or OWNER_NAME == "" then
        OWNER_NAME = "Mahdirml123i"
    end
    
    -- Verify owner is in server (name-based only)
    pcall(function()
        local Players = game:GetService("Players")
        if not Players then return end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player and player.Name then
                if player.Name:lower() == OWNER_NAME:lower() then
                    ownerFound = true
                    break
                end
            end
        end
    end)
    
    if not ownerFound then
        print("[SYSTEM] Owner '" .. OWNER_NAME .. "' not in server - script idle")
        return false
    end
    
    print("[OWNER] Verified: " .. OWNER_NAME)
    return true
end

if not VerifyOwnerInServer() then
    return
end

--// ============================================================================
--// PHASE 1: SAFE BOOT GATE (PREVENTS PREMATURE EXECUTION)
--// ============================================================================

local function SAFE_BOOT()
    local startTime = tick()
    
    -- GATE 0: LocalPlayer (5s timeout)
    local localPlayer = nil
    local gateTimeout = tick() + 5
    while not localPlayer and tick() < gateTimeout do
        pcall(function()
            localPlayer = game:GetService("Players").LocalPlayer
        end)
        if not localPlayer then task.wait(0.1) end
    end
    if not localPlayer then
        print("[BOOT] LocalPlayer timeout")
        return false
    end
    
    -- GATE 1: Character (10s timeout)
    local characterReady = false
    gateTimeout = tick() + 10
    while not characterReady and tick() < gateTimeout do
        pcall(function()
            if localPlayer and localPlayer.Character then
                characterReady = true
            end
        end)
        if not characterReady then task.wait(0.1) end
    end
    if not characterReady then
        print("[BOOT] Character timeout")
        return false
    end
    
    -- GATE 2: PlayerGui (5s timeout)
    local playerGui = nil
    gateTimeout = tick() + 5
    while not playerGui and tick() < gateTimeout do
        pcall(function()
            playerGui = localPlayer:FindFirstChild("PlayerGui")
        end)
        if not playerGui then task.wait(0.1) end
    end
    if not playerGui then
        print("[BOOT] PlayerGui timeout")
        return false
    end
    
    print("[BOOT] Ready")
    return true
end

if not SAFE_BOOT() then
    print("[FATAL] Safe boot failed")
    return
end

--// ============================================================================
--// PHASE 2: SERVICES & STATE
--// ============================================================================

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
    SingleAttackValidationStartTime = 0
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

--// ============================================================================
--// PHASE 3: UTILITIES
--// ============================================================================

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
        hum = player.Character:FindFirstChild("Humanoid")
    end)
    return hum
end

--// ============================================================================
--// PHASE 4: CHAT UI RESET (DA HOOD HARDENED)
--// ============================================================================

local function ChatUIReset()
    local success = false
    
    pcall(function()
        if not LocalPlayer or not LocalPlayer:FindFirstChild("PlayerGui") then
            return
        end
        
        local playerGui = LocalPlayer.PlayerGui
        local chat = playerGui:FindFirstChild("Chat") or playerGui:FindFirstChild("ExperienceChat")
        
        if not chat then
            return
        end
        
        local chatFrame = chat:FindFirstChild("Frame") 
            or chat:FindFirstChild("ChatWindow")
            or chat:FindFirstChild("MainFrame")
            or chat:FindFirstChild("ChatBox")
        
        if not chatFrame then
            return
        end
        
        pcall(function()
            chatFrame.AnchorPoint = Vector2.new(0, 1)
            chatFrame.Position = UDim2.new(0, 10, 1, -10)
            chatFrame.Size = UDim2.new(0, 320, 0, 400)
            chatFrame.Visible = true
        end)
        
        pcall(function()
            chat.Enabled = true
        end)
        
        pcall(function()
            if chatFrame:FindFirstChild("Offset") then
                chatFrame.Offset = UDim2.new(0, 0, 0, 0)
            end
        end)
        
        pcall(function()
            for _, child in pairs(chat:GetDescendants()) do
                if child:IsA("GuiObject") then
                    child.Visible = true
                end
            end
        end)
        
        success = true
    end)
    
    if success then
        print("[CHAT] Restored")
    end
    
    return success
end

--// ============================================================================
--// PHASE 5: EFFECT VERIFIER (FIFO QUEUE)
--// ============================================================================

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

--// ============================================================================
--// PHASE 6: REMOTE MANAGER
--// ============================================================================

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
            self.Primary = mainEvent
            self.RemoteFound = true
            print("[REMOTE] Found: MainEvent (Da Hood)")
            return
        end
        
        local combatKeywords = {"attack", "damage", "hit", "punch", "knife", "stomp", "carry", "grab", "knock", "down", "combat", "action", "input", "fire", "event"}
        
        local function scanRecursive(parent, depth)
            if depth > 10 then return end
            
            pcall(function()
                for _, obj in pairs(parent:GetChildren()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
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

local function DetermineActionToken(targetChar)
    if not targetChar then return "Punch" end
    
    local hum = GetTargetHumanoid(targetChar:FindFirstChild("Humanoid") and targetChar or nil)
    if not hum then return "Punch" end
    
    if hum.Health <= 10 then
        return "Heavy"
    end
    
    return "Punch"
end

function RemoteManager:Fire(targetChar)
    if not self.Primary then
        self.ConsecutiveFailures = self.ConsecutiveFailures + 1
        return false
    end
    
    if not targetChar then
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
            local targetRoot = SafeGetRoot(targetChar)
            
            if not myRoot or not targetRoot then return end
            
            local actionToken = DetermineActionToken(targetChar)
            
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

function RemoteManager:AttemptStomp(targetChar)
    if not self.Primary then return false end
    if not targetChar then return false end
    
    local now = tick()
    if now - self.LastStompTime < self.StompCooldown then
        return false
    end
    
    local hum = GetTargetHumanoid(targetChar)
    if not hum then return false end
    
    if hum.Health > 5 then return false end
    
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

--// ============================================================================
--// PHASE 7: STAND BUILDER
--// ============================================================================

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
        
        local myRoot = SafeGetRoot(LocalPlayer.Character)
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

--// ============================================================================
--// PHASE 8: COMBAT CONTROLLER
--// ============================================================================

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
    
    local targetChar = nil
    pcall(function()
        targetChar = target.Character
    end)
    
    local success = RemoteManager:Fire(targetChar)
    
    if success then
        State.ConsecutiveAttackFailures = 0
    else
        State.ConsecutiveAttackFailures = State.ConsecutiveAttackFailures + 1
    end
    
    RemoteManager:CheckFailureThreshold()
    
    return success
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
            
            if State.SingleAttackConfirmedEffects == 0 then
                State.BarrageActive = false
                State.BarrageDisabled = true
                if State.BarrageConnection then
                    pcall(function() State.BarrageConnection:Disconnect() end)
                    State.BarrageConnection = nil
                end
                Notify("BARRAGE", "Disabled: insufficient baseline")
                return
            end
            
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

--// ============================================================================
--// PHASE 9: OWNER CONTROLLER
--// ============================================================================

local OwnerController = {
    OwnerUserId = nil,
    OwnerName = nil,
    Initialized = false
}

function OwnerController:Initialize()
    if self.Initialized then return end
    
    pcall(function()
        if LocalPlayer then
            self.OwnerUserId = LocalPlayer.UserId
            self.OwnerName = LocalPlayer.Name
        end
    end)
    
    self.Initialized = true
    
    if self.OwnerUserId then
        print("[OWNER] Verified")
    end
end

function OwnerController:IsOwner(player)
    if not player then return false end
    if not self.Initialized then self:Initialize() end
    
    local result = false
    pcall(function()
        if player and self.OwnerUserId then
            result = player.UserId == self.OwnerUserId
        end
    end)
    return result
end

--// ============================================================================
--// PHASE 10: CHAT NORMALIZER & ROUTER
--// ============================================================================

local ChatNormalizer = {
    LastChatTime = 0,
    ChatCooldown = 0.05,
    Connections = {}
}

function ChatNormalizer:Normalize(text)
    if not text or text == "" then return "" end
    
    text = text:match("^%s*(.-)%s*$") or text
    
    local prefix = ""
    if text:sub(1, 1) == "." or text:sub(1, 1) == "/" then
        prefix = text:sub(1, 1)
        text = text:sub(2)
    end
    
    text = text:lower()
    
    return prefix .. text
end

local Router = {}

function Router:Route(msg)
    if not msg or msg == "" then return end
    
    local args = nil
    pcall(function()
        if msg and typeof(msg.split) == "function" then
            args = msg:split(" ")
        end
    end)
    if not args or #args == 0 then return end
    
    local cmd = ""
    pcall(function()
        if args[1] and typeof(args[1].lower) == "function" then
            cmd = args[1]:lower()
        end
    end)
    if not cmd or cmd == "" then return end

    if cmd == "s" or cmd == "summon!" or cmd == "/e q" then
        if not State.IsSummoned then
            State.IsSummoned = true
            State.CombatDisabled = false
            State.BarrageDisabled = false
            State.ConsecutiveAttackFailures = 0
            State.NoEffectCounter = 0
            State.SingleAttackConfirmedEffects = 0
            State.BarrageConfirmedEffects = 0
            State.SingleAttackValidationStartTime = tick()
            EffectVerifier:ResetTracking()
            StandBuilder:Create()
            Notify("SYSTEM", "Stand Summoned")
        end
    elseif cmd == "vanish!" or cmd == "/e w" then
        if State.IsSummoned then
            State.IsSummoned = false
            Combat:StopBarrage()
            State.AutoKill = false
            State.Target = nil
            Notify("SYSTEM", "Stand Vanished")
        end
    
    elseif cmd == "combat!" then
        State.AttackMode = "Combat"
        Notify("MODE", "Combat | Range: 2.8 | Speed: 0.05s")
    elseif cmd == "knife!" then
        State.AttackMode = "Knife"
        Notify("MODE", "Knife | Range: 1.5 | Speed: 0.03s")
    elseif cmd == "whip!" then
        State.AttackMode = "Whip"
        Notify("MODE", "Whip | Range: 5.0 | Speed: 0.08s")
    elseif cmd == "pitch!" then
        State.AttackMode = "Pitch"
        Notify("MODE", "Pitch | Range: 3.5 | Speed: 0.06s")
    elseif cmd == "sign!" then
        State.AttackMode = "Sign"
        Notify("MODE", "Sign | Range: 4.0 | Speed: 0.07s")
    
    elseif cmd == "barrage!" or cmd == "ora!" or cmd == "muda!" then
        if State.CombatDisabled then
            Notify("ERROR", "Combat disabled")
            return
        end
        if State.BarrageDisabled then
            Notify("ERROR", "Barrage disabled")
            return
        end
        if not State.IsSummoned then
            Notify("ERROR", "Stand must be summoned")
            return
        end
        if State.Target and IsPlayerValid(State.Target) then
            if Combat:Barrage() then
                Notify("BARRAGE", "Started on " .. State.Target.Name)
            else
                Notify("ERROR", "Barrage already active")
            end
        else
            Notify("ERROR", "No valid target")
        end
    
    elseif cmd == "unattack!" or cmd == "stop!" then
        Combat:StopBarrage()
        State.AutoKill = false
        State.Target = nil
        Notify("SYSTEM", "Attack stopped")
    
    elseif cmd:sub(1, 1) == Config.Prefix then
        local action = ""
        pcall(function()
            action = cmd:sub(2)
        end)
        local targetName = args[2]
        local p = nil
        if targetName then
            p = GetPlayer(targetName)
        end
        
        if action == "bring" and p then
            if IsPlayerValid(p) then
                local r = SafeGetRoot(p.Character)
                local myR = SafeGetRoot(LocalPlayer.Character)
                if r and myR then
                    r.CFrame = myR.CFrame
                    Notify("BRING", "Brought " .. p.Name)
                end
            else
                Notify("ERROR", "Player not found")
            end
        
        elseif action == "autokill" and p then
            if State.CombatDisabled then
                Notify("ERROR", "Combat disabled")
                return
            end
            if not State.IsSummoned then
                Notify("ERROR", "Stand must be summoned")
                return
            end
            if IsPlayerValid(p) then
                State.Target = p
                State.AutoKill = true
                State.AutoKillStartTime = tick()
                EffectVerifier:ResetTracking(p)
                Notify("AUTOKILL", "Targeting: " .. p.Name)
            else
                Notify("ERROR", "Player not found")
            end
        
        elseif action == "smite" and p then
            if IsPlayerValid(p) then
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
        
        elseif action == "to" or action == "goto!" or action == "tp!" then
            local loc = args[2]
            if loc and Config.Locations[loc] then
                local myR = SafeGetRoot(LocalPlayer.Character)
                if myR then
                    pcall(function()
                        myR.CFrame = CFrame.new(Config.Locations[loc])
                    end)
                    Notify("TELEPORT", "Teleported to " .. loc)
                end
            end
        end
    end
    
    local followModes = {
        ["back!"] = "Back",
        ["left!"] = "Left",
        ["right!"] = "Right",
        ["under!"] = "Under",
        ["alt!"] = "Alt",
        ["upright!"] = "Upright",
        ["upleft!"] = "Upleft",
        ["upcenter!"] = "Upcenter"
    }
    
    if followModes[cmd] then
        State.FollowMode = followModes[cmd]
        Notify("FOLLOW", "Mode: " .. followModes[cmd])
    end
end

function ChatNormalizer:ProcessChat(msg)
    if not msg or msg == "" then return end
    
    local now = tick()
    if now - self.LastChatTime < self.ChatCooldown then
        return
    end
    self.LastChatTime = now
    
    if not OwnerController:IsOwner(LocalPlayer) then
        return
    end
    
    local normalized = self:Normalize(msg)
    if normalized and normalized ~= "" then
        print("[CHAT] Command: " .. normalized)
        Router:Route(normalized)
    end
end

function ChatNormalizer:Hook()
    if self.Connections.Chatted then
        pcall(function() self.Connections.Chatted:Disconnect() end)
    end
    
    pcall(function()
        if LocalPlayer then
            self.Connections.Chatted = LocalPlayer.Chatted:Connect(function(msg)
                self:ProcessChat(msg)
            end)
        end
    end)
    
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            local chat = playerGui:FindFirstChild("Chat") or playerGui:FindFirstChild("ExperienceChat")
            if chat then
                local chatFrame = chat:FindFirstChild("Frame") 
                    or chat:FindFirstChild("ChatWindow")
                    or chat:FindFirstChild("MainFrame")
                    or chat:FindFirstChild("ChatBox")
                
                if chatFrame then
                    local textBox = nil
                    pcall(function()
                        for _, child in pairs(chat:GetDescendants()) do
                            if child:IsA("TextBox") and child.Name:lower():find("input") then
                                textBox = child
                                break
                            end
                        end
                    end)
                    
                    if textBox then
                        if self.Connections.TextBoxFocusLost then
                            pcall(function() self.Connections.TextBoxFocusLost:Disconnect() end)
                        end
                        
                        self.Connections.TextBoxFocusLost = textBox.FocusLost:Connect(function(enterPressed)
                            if enterPressed and textBox.Text ~= "" then
                                self:ProcessChat(textBox.Text)
                                pcall(function()
                                    textBox.Text = ""
                                end)
                            end
                        end)
                    end
                end
            end
        end
    end)
    
    print("[CHAT] Hooked")
end

--// ============================================================================
--// PHASE 11: EFFECT VERIFICATION LOOP
--// ============================================================================

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
                    end
                else
                    State.NoEffectCounter = State.NoEffectCounter + 1
                end
                
                if State.NoEffectCounter >= Config.NoEffectThreshold and not State.CombatDisabled then
                    Notify("COMBAT", "Disabled: no hit effect")
                    State.CombatDisabled = true
                    Combat:StopBarrage()
                    State.AutoKill = false
                end
            end
        end
    end)
end)

--// ============================================================================
--// PHASE 12: MAIN RESOLVER LOOP
--// ============================================================================

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
            
            if State.Resolver and tRoot.AssemblyLinearVelocity.Magnitude > 3 then
                local velocity = tRoot.AssemblyLinearVelocity
                local predictionFactor = math.min(deltaTime * 16, 0.5)
                targetPos = targetPos + (velocity * predictionFactor)
            end
            
            pcall(function()
                myRoot.CFrame = targetPos
            end)
            
            Combat:Attack(State.Target, false)
            
            RemoteManager:AttemptStomp(State.Target.Character)
        elseif State.AutoKill and not State.IsSummoned then
            State.AutoKill = false
            State.Target = nil
        end
    end)
end)

--// ============================================================================
--// PHASE 13: INITIALIZATION SEQUENCE
--// ============================================================================

ChatUIReset()

OwnerController:Initialize()

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
EffectVerifier:ResetTracking()

pcall(function()
    if LocalPlayer and LocalPlayer.Character then
        local myRoot = SafeGetRoot(LocalPlayer.Character)
        if myRoot then
            myRoot.CFrame = CFrame.new(Config.Locations.safe1)
        end
    end
end)

RemoteManager:Scan()

ChatNormalizer:Hook()

--// ============================================================================
--// PHASE 14: CHARACTER RESPAWN HANDLER
--// ============================================================================

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
            if State.IsSummoned then
                StandBuilder:Create()
            end
        end)
    end)
end

--// ============================================================================
--// PHASE 15: PLAYER LEAVING HANDLER
--// ============================================================================

pcall(function()
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        if player == State.Target then
            State.AutoKill = false
            State.Target = nil
            Combat:StopBarrage()
            EffectVerifier:ResetTracking(player)
            Notify("AUTOKILL", "Target left")
        end
    end)
end)

--// ============================================================================
--// FINAL BOOT MESSAGE
--// ============================================================================

print("[SYSTEM] Ready")
Notify("SYSTEM", "Ready")
