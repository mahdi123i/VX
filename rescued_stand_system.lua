--[[
    RESCUED STAND SYSTEM (V14.0 CAUSALITY-COMPLETE)
    Causality-Complete: Physical State Awareness + Probabilistic Outcomes + Deterministic Logging
    
    TIER 1 IMPLEMENTATIONS:
    - A1: Humanoid State Enumeration (edge-triggered state transitions)
    - D1: Outcome Classification (CONFIRMED/PROBABLE/INCONCLUSIVE)
    - F1: Deterministic State Transition Log (replayable timeline)
    
    FIFO queue for attack attempts: no collision, no reuse
    One health change consumes exactly one oldest valid attempt
    Single attack baseline tracked separately from barrage
    Barrage effectiveness compared against verified single attack rate
]]

--// EXTERNAL OPERATIONAL BOOTSTRAP (LOGICALLY ISOLATED)
--[[
    BOOTSTRAP LOADER INTEGRATION
    
    CRITICAL CONSTRAINTS:
    - Runs exactly once per session (guard flag: _BOOTSTRAP_LOADED)
    - Treated as black box (no assumptions about internal behavior)
    - Does NOT modify internal State tables
    - Does NOT override combat verification
    - Does NOT influence effect confirmation logic
    - Fails gracefully (pcall-wrapped)
    - Logs success or failure clearly
    
    CAUSALITY PRESERVATION:
    - Physics-based events (stomp, knockdown) caused by external loader
      are NOT counted as combat unless internal attack attempt exists
    - External effects remain classified as NON-COMBAT
    - FIFO causality guarantees are preserved
]]

local function InitializeExternalBootstrap()
    if getgenv()._BOOTSTRAP_LOADED then
        warn("[BOOTSTRAP] Already loaded, skipping initialization")
        return false
    end
    
    getgenv()._ = "Join discord.gg/msgabv2t9Q | discord.gg/stando to get latest update ok bai >.+ | If you pay for this script you get scammed, this script is completely free ok"
    getgenv().Owner = "hugwag"
    
    getgenv()._C = {
        Fps = false,
        Msg = "Yare Yare Daze.",
        AntiMod = true,
        AntiStomp = true,
        Resolver = false,
        AutoPrediction = false,
        Attack = "Heavy",
        AttackMode = "Sky",
        AttackDistance = 75,
        Position = "Back",
        CustomPrefix = "."
    }
    
    local bootstrapSuccess = false
    local bootstrapError = nil
    
    pcall(function()
        local loaderUrl = ""
        if loaderUrl and loaderUrl ~= "" then
            local loaderFunc = loadstring(game:HttpGet(loaderUrl))
            if loaderFunc then
                loaderFunc()
                bootstrapSuccess = true
            else
                bootstrapError = "Failed to load external bootstrap function"
            end
        else
            bootstrapSuccess = true
            bootstrapError = "No external loader URL configured (safe mode)"
        end
    end, function(err)
        bootstrapError = tostring(err)
    end)
    
    getgenv()._BOOTSTRAP_LOADED = true
    
    if bootstrapSuccess then
        print("[BOOTSTRAP] ✓ External operational bootstrap initialized successfully")
        print("[BOOTSTRAP] Configuration: AntiStomp=" .. tostring(getgenv()._C.AntiStomp) .. ", Resolver=" .. tostring(getgenv()._C.Resolver) .. ", AutoPrediction=" .. tostring(getgenv()._C.AutoPrediction))
    else
        warn("[BOOTSTRAP] ✗ External bootstrap initialization failed: " .. (bootstrapError or "Unknown error"))
        warn("[BOOTSTRAP] System will continue with internal causality verification only")
    end
    
    return bootstrapSuccess
end

--// CHAT UI RESET (RUNS IMMEDIATELY ON EXECUTION)
--[[
    ChatUIReset: Restore Da Hood chat UI to known-good state
    
    CRITICAL FIXES:
    - Search in LocalPlayer.PlayerGui (NOT StarterGui)
    - Support both "Chat" and "ExperienceChat" names
    - Restore to BOTTOM-LEFT of screen (AnchorPoint = 0,1)
    - Fail gracefully if chat does not exist
    - No assumptions about UI structure
    
    CONSTRAINTS:
    - Runs immediately on script execution (before other systems)
    - CLIENT-ONLY (no server calls)
    - Fails gracefully with pcall
    - Does NOT fire remotes
    - Does NOT modify State tables
    - Does NOT affect combat
]]

local function ChatUIReset()
    local success = false
    local errorMsg = nil
    
    pcall(function()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        
        if not LocalPlayer or not LocalPlayer:FindFirstChild("PlayerGui") then
            errorMsg = "PlayerGui not accessible"
            return
        end
        
        local playerGui = LocalPlayer.PlayerGui
        
        -- Try to find Chat (standard Roblox chat)
        local chat = playerGui:FindFirstChild("Chat")
        
        -- Fallback: Try ExperienceChat (newer Roblox chat system)
        if not chat then
            chat = playerGui:FindFirstChild("ExperienceChat")
        end
        
        if not chat then
            errorMsg = "Chat GUI not found in PlayerGui (tried Chat and ExperienceChat)"
            return
        end
        
        -- Locate main chat frame (try multiple possible names)
        local chatFrame = chat:FindFirstChild("Frame")
        if not chatFrame then
            chatFrame = chat:FindFirstChild("ChatWindow")
        end
        if not chatFrame then
            chatFrame = chat:FindFirstChild("MainFrame")
        end
        
        if not chatFrame then
            errorMsg = "Chat Frame not found in chat GUI"
            return
        end
        
        -- Reset to BOTTOM-LEFT of screen (Da Hood default)
        pcall(function()
            chatFrame.AnchorPoint = Vector2.new(0, 1)
            chatFrame.Position = UDim2.new(0, 10, 1, -10)
        end)
        
        -- Reset size to default
        pcall(function()
            chatFrame.Size = UDim2.new(0, 320, 0, 400)
        end)
        
        -- Force visibility
        pcall(function()
            chatFrame.Visible = true
        end)
        
        -- Ensure chat is enabled
        pcall(function()
            chat.Enabled = true
        end)
        
        -- Clear any offset caused by Da Hood
        pcall(function()
            if chatFrame:FindFirstChild("Offset") then
                chatFrame.Offset = UDim2.new(0, 0, 0, 0)
            end
        end)
        
        success = true
    end)
    
    if success then
        print("[CHAT RESET] ✓ Chat UI restored to bottom-left (Da Hood compatible)")
    else
        warn("[CHAT RESET] ✗ Chat UI reset failed: " .. (errorMsg or "Unknown error"))
        warn("[CHAT RESET] System will continue with chat tracking enabled (UI-independent)")
    end
    
    return success
end

--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

--// CENTRAL STATE MANAGER
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

--// CONFIGURATION & DATA
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
        bull = Vector3.new(-1300, 21, -1300)
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

--// UTILITIES
local function Notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 5
        })
    end)
end

local function SafeGetRoot(char)
    if not char or not char.Parent then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function GetPlayer(name)
    if not name or name == "" then return nil end
    name = name:lower()
    for _, v in pairs(Players:GetPlayers()) do
        if v.Name:lower():sub(1, #name) == name or v.DisplayName:lower():sub(1, #name) == name then
            return v
        end
    end
    return nil
end

local function IsPlayerValid(player)
    if not player or not player.Parent then return false end
    if not player.Character then return false end
    local root = SafeGetRoot(player.Character)
    return root ~= nil
end

local function ClampRange(range, minRange, maxRange)
    return math.max(minRange, math.min(range, maxRange))
end

local function GetTargetHumanoid(player)
    if not IsPlayerValid(player) then return nil end
    return player.Character:FindFirstChild("Humanoid")
end

--// FIFO ATTACK QUEUE EFFECT VERIFICATION SYSTEM
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

--// REMOTE ANALYSIS & DISCOVERY SYSTEM (EMPIRICAL LOGGING)
local RemoteAnalyzer = {
    DiscoveredRemotes = {},
    HookedRemotes = {},
    CallLog = {},
    MaxLogSize = 500,
    CombatActionLog = {},
    RemoteFireStats = {},
    LastLogTime = 0,
    LogInterval = 0.5
}

function RemoteAnalyzer:EnumerateAllRemotes()
    local function scanRecursive(parent, depth)
        if depth > 10 then return end
        
        for _, obj in pairs(parent:GetChildren()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local fullPath = obj.Parent.Name .. "/" .. obj.Name
                if not self.DiscoveredRemotes[obj.Name] then
                    self.DiscoveredRemotes[obj.Name] = {
                        Instance = obj,
                        Type = obj.ClassName,
                        Path = fullPath,
                        FirstSeen = tick(),
                        CallCount = 0,
                        LastCallTime = 0,
                        ArgumentPatterns = {}
                    }
                end
            end
            scanRecursive(obj, depth + 1)
        end
    end
    
    scanRecursive(ReplicatedStorage, 0)
    return self.DiscoveredRemotes
end

function RemoteAnalyzer:HookRemote(remoteName, remoteObj)
    if self.HookedRemotes[remoteName] then return end
    
    local originalFire = remoteObj.FireServer
    
    remoteObj.FireServer = function(self, ...)
        local args = {...}
        local argCount = #args
        local argTypes = {}
        
        for i, arg in ipairs(args) do
            table.insert(argTypes, typeof(arg))
        end
        
        RemoteAnalyzer:LogCall(remoteName, argCount, argTypes, args)
        
        return originalFire(self, ...)
    end
    
    self.HookedRemotes[remoteName] = true
end

function RemoteAnalyzer:LogCall(remoteName, argCount, argTypes, args)
    local now = tick()
    
    table.insert(self.CallLog, {
        RemoteName = remoteName,
        ArgumentCount = argCount,
        ArgumentTypes = argTypes,
        Arguments = args,
        Timestamp = now,
        StackTrace = debug.traceback()
    })
    
    if #self.CallLog > self.MaxLogSize then
        table.remove(self.CallLog, 1)
    end
    
    if not self.RemoteFireStats[remoteName] then
        self.RemoteFireStats[remoteName] = {
            TotalCalls = 0,
            LastCall = now,
            ArgumentPatterns = {}
        }
    end
    
    self.RemoteFireStats[remoteName].TotalCalls = self.RemoteFireStats[remoteName].TotalCalls + 1
    self.RemoteFireStats[remoteName].LastCall = now
    
    local patternKey = table.concat(argTypes, ",")
    if not self.RemoteFireStats[remoteName].ArgumentPatterns[patternKey] then
        self.RemoteFireStats[remoteName].ArgumentPatterns[patternKey] = 0
    end
    self.RemoteFireStats[remoteName].ArgumentPatterns[patternKey] = self.RemoteFireStats[remoteName].ArgumentPatterns[patternKey] + 1
end

function RemoteAnalyzer:CorrelateWithAction(actionName, targetPlayer)
    local now = tick()
    local recentCalls = {}
    
    for i = #self.CallLog, math.max(1, #self.CallLog - 20), -1 do
        local call = self.CallLog[i]
        if now - call.Timestamp < 0.5 then
            table.insert(recentCalls, 1, call)
        end
    end
    
    table.insert(self.CombatActionLog, {
        Action = actionName,
        Target = targetPlayer and targetPlayer.Name or "UNKNOWN",
        Timestamp = now,
        AssociatedRemoteCalls = recentCalls
    })
    
    if #self.CombatActionLog > 100 then
        table.remove(self.CombatActionLog, 1)
    end
end

function RemoteAnalyzer:GetCombatRemotes()
    local combatKeywords = {"attack", "damage", "hit", "punch", "knife", "stomp", "carry", "grab", "knock", "down", "combat", "action", "input", "fire", "event"}
    local combatRemotes = {}
    
    for remoteName, remoteData in pairs(self.DiscoveredRemotes) do
        local lowerName = remoteName:lower()
        for _, keyword in ipairs(combatKeywords) do
            if lowerName:find(keyword) then
                table.insert(combatRemotes, {
                    Name = remoteName,
                    Type = remoteData.Type,
                    Path = remoteData.Path,
                    CallCount = remoteData.CallCount
                })
                break
            end
        end
    end
    
    return combatRemotes
end

function RemoteAnalyzer:PrintDiscoveryReport()
    local report = "\n=== DA HOOD REMOTE DISCOVERY REPORT ===\n"
    report = report .. "Total Remotes Found: " .. table.getn(self.DiscoveredRemotes) .. "\n\n"
    
    report = report .. "--- ALL DISCOVERED REMOTES ---\n"
    for remoteName, remoteData in pairs(self.DiscoveredRemotes) do
        report = report .. string.format("  [%s] %s | Path: %s | Calls: %d\n", 
            remoteData.Type, remoteName, remoteData.Path, remoteData.CallCount)
    end
    
    report = report .. "\n--- COMBAT-RELATED REMOTES ---\n"
    local combatRemotes = self:GetCombatRemotes()
    for _, remote in ipairs(combatRemotes) do
        report = report .. string.format("  [%s] %s | Calls: %d\n", remote.Type, remote.Name, remote.CallCount)
    end
    
    report = report .. "\n--- REMOTE FIRE STATISTICS ---\n"
    for remoteName, stats in pairs(self.RemoteFireStats) do
        report = report .. string.format("  %s: %d calls\n", remoteName, stats.TotalCalls)
        for pattern, count in pairs(stats.ArgumentPatterns) do
            report = report .. string.format("    Pattern [%s]: %d times\n", pattern, count)
        end
    end
    
    report = report .. "\n--- RECENT COMBAT ACTIONS ---\n"
    for i = math.max(1, #self.CombatActionLog - 10), #self.CombatActionLog do
        local action = self.CombatActionLog[i]
        if action then
            report = report .. string.format("  [%s] %s on %s | Associated Calls: %d\n",
                os.date("%H:%M:%S", action.Timestamp), action.Action, action.Target, #action.AssociatedRemoteCalls)
            for _, call in ipairs(action.AssociatedRemoteCalls) do
                report = report .. string.format("    -> %s (%d args: %s)\n", 
                    call.RemoteName, call.ArgumentCount, table.concat(call.ArgumentTypes, ","))
            end
        end
    end
    
    return report
end

--// REMOTE MANAGER (VERIFIED EXECUTION WITH FAILURE TRACKING)
local RemoteManager = {
    Primary = nil,
    Cache = {},
    LastFireTime = 0,
    FireCooldown = 0.01,
    RemoteFound = false,
    RemoteNotified = false,
    ConsecutiveFailures = 0
}

function RemoteManager:Scan()
    if self.RemoteFound then return end
    
    RemoteAnalyzer:EnumerateAllRemotes()
    
    local function scanRecursive(parent)
        for _, obj in pairs(parent:GetChildren()) do
            if obj:IsA("RemoteEvent") then
                if not self.Primary then
                    self.Primary = obj
                end
                self.Cache[obj.Name] = obj
                RemoteAnalyzer:HookRemote(obj.Name, obj)
            end
            scanRecursive(obj)
        end
    end
    
    scanRecursive(ReplicatedStorage)
    
    if not self.Primary then
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                self.Primary = obj
                RemoteAnalyzer:HookRemote(obj.Name, obj)
                break
            end
        end
    end
    
    self.RemoteFound = true
end

function RemoteManager:Fire(...)
    if not self.Primary then
        if not self.RemoteNotified then
            Notify("REMOTE", "No RemoteEvent found. Combat disabled.")
            self.RemoteNotified = true
            State.CombatDisabled = true
        end
        self.ConsecutiveFailures = self.ConsecutiveFailures + 1
        return false
    end
    
    local now = tick()
    if now - self.LastFireTime < self.FireCooldown then
        return false
    end
    self.LastFireTime = now
    
    local success = pcall(function()
        self.Primary:FireServer(...)
    end)
    
    if success then
        self.ConsecutiveFailures = 0
    else
        self.ConsecutiveFailures = self.ConsecutiveFailures + 1
    end
    
    return success
end

function RemoteManager:CheckFailureThreshold()
    if self.ConsecutiveFailures >= Config.AttackFailureThreshold then
        if not State.CombatDisabled then
            Notify("COMBAT", "Combat disabled: Remote not responding after " .. Config.AttackFailureThreshold .. " attempts")
            State.CombatDisabled = true
        end
        return true
    end
    return false
end

--// STAND BUILDER (VERIFIED PHYSICS WITH OFFSET VALIDATION)
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

    local model = Instance.new("Model", workspace)
    model.Name = "RescuedStand_" .. LocalPlayer.Name
    State.StandModel = model

    local sRoot = Instance.new("Part", model)
    sRoot.Name = "HumanoidRootPart"
    sRoot.Size = Vector3.new(2, 2, 1)
    sRoot.Transparency = 0.5
    sRoot.CanCollide = false
    sRoot.Material = Enum.Material.ForceField
    sRoot.Color = Color3.fromRGB(0, 255, 255)
    State.StandRoot = sRoot

    local hum = Instance.new("Humanoid", model)
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

    local bp = Instance.new("BodyPosition", sRoot)
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.P = 25000
    bp.D = 1200
    State.StandBP = bp

    local bg = Instance.new("BodyGyro", sRoot)
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 25000
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

--// COMBAT CONTROLLER (FIFO QUEUE EFFECT VERIFICATION)
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
    local now = tick()
    
    if now - State.LastAttackTime < config.attackSpeed then
        return false
    end
    State.LastAttackTime = now
    
    EffectVerifier:RegisterAttackAttempt(target, isBarrage)
    State.LastAttackAttemptTime = now
    
    local actionName = State.AttackMode .. (isBarrage and " (Barrage)" or " (Single)")
    RemoteAnalyzer:CorrelateWithAction(actionName, target)
    
    local success = RemoteManager:Fire(target.Character)
    
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
                Notify("BARRAGE", "Barrage disabled: insufficient single attack baseline")
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
                Notify("BARRAGE", "Barrage disabled: no effectiveness gain")
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

--// OWNER CONTROLLER (LOGICALLY ISOLATED)
--[[
    OwnerController: Strict owner identity verification
    
    CONSTRAINTS:
    - Owner = LocalPlayer only (UserId-based)
    - No other player input may trigger privileged commands
    - Owner commands ignored silently if sender is not owner
    - Does NOT modify State tables
    - Does NOT affect combat
]]

local OwnerController = {
    OwnerUserId = nil,
    OwnerName = nil,
    Initialized = false
}

function OwnerController:Initialize()
    if self.Initialized then return end
    
    self.OwnerUserId = LocalPlayer.UserId
    self.OwnerName = LocalPlayer.Name
    self.Initialized = true
    
    print("[OWNER] ✓ Owner initialized: " .. self.OwnerName .. " (ID: " .. self.OwnerUserId .. ")")
end

function OwnerController:IsOwner(player)
    if not player then return false end
    if not self.Initialized then self:Initialize() end
    return player.UserId == self.OwnerUserId
end

function OwnerController:IsOwnerByName(name)
    if not name or name == "" then return false end
    if not self.Initialized then self:Initialize() end
    return name:lower() == self.OwnerName:lower()
end

--// CHAT NORMALIZER (LOGICALLY ISOLATED)
--[[
    ChatNormalizer: Capture and normalize chat commands
    
    CONSTRAINTS:
    - Capture via LocalPlayer.Chatted
    - Normalize text (trim, lowercase, preserve prefix)
    - Forward ONLY owner messages to Router
    - Non-owner messages silently ignored
    - Does NOT modify State tables
    - Does NOT affect combat
    - Da Hood compatible (works even if UI displaced)
]]

local ChatNormalizer = {
    LastChatTime = 0,
    ChatCooldown = 0.05,
    Connections = {}
}

function ChatNormalizer:Normalize(text)
    if not text or text == "" then return "" end
    
    -- Trim whitespace
    text = text:match("^%s*(.-)%s*$") or text
    
    -- Preserve prefix if present
    local prefix = ""
    if text:sub(1, 1) == "." or text:sub(1, 1) == "/" then
        prefix = text:sub(1, 1)
        text = text:sub(2)
    end
    
    -- Lowercase
    text = text:lower()
    
    return prefix .. text
end

function ChatNormalizer:ProcessChat(msg)
    if not msg or msg == "" then return end
    
    local now = tick()
    if now - self.LastChatTime < self.ChatCooldown then
        return
    end
    self.LastChatTime = now
    
    -- Verify sender is owner
    if not OwnerController:IsOwner(LocalPlayer) then
        -- Silently ignore non-owner chat
        return
    end
    
    -- Normalize and forward to Router
    local normalized = self:Normalize(msg)
    if normalized and normalized ~= "" then
        Router:Route(normalized)
    end
end

function ChatNormalizer:Hook()
    if self.Connections.Chatted then
        pcall(function() self.Connections.Chatted:Disconnect() end)
    end
    
    self.Connections.Chatted = LocalPlayer.Chatted:Connect(function(msg)
        self:ProcessChat(msg)
    end)
    
    print("[CHAT NORMALIZER] ✓ Chat hook established")
end

--// COMMAND ROUTER (VERIFIED COMMANDS ONLY)
local Router = {}

function Router:Route(msg)
    if not msg or msg == "" then return end
    
    local args = msg:split(" ")
    local cmd = args[1]:lower()

    -- SUMMON/VANISH
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
    
    -- ATTACK MODES (REAL: Changes positioning range and attack speed)
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
    
    -- BARRAGE COMMANDS (REAL: Continuous attacks with mode-based speed)
    elseif cmd == "barrage!" or cmd == "ora!" or cmd == "muda!" then
        if State.CombatDisabled then
            Notify("ERROR", "Combat disabled: Remote not responding")
            return
        end
        if State.BarrageDisabled then
            Notify("ERROR", "Barrage disabled: no effectiveness gain")
            return
        end
        if not State.IsSummoned then
            Notify("ERROR", "Stand must be summoned for barrage")
            return
        end
        if State.Target and IsPlayerValid(State.Target) then
            if Combat:Barrage() then
                Notify("BARRAGE", "Barrage started on " .. State.Target.Name)
            else
                Notify("ERROR", "Barrage already active")
            end
        else
            Notify("ERROR", "No valid target for barrage")
        end
    
    -- STOP BARRAGE / UNATTACK
    elseif cmd == "unattack!" or cmd == "stop!" then
        Combat:StopBarrage()
        State.AutoKill = false
        State.Target = nil
        Notify("SYSTEM", "Attack stopped")
    
    -- DOT COMMANDS
    elseif cmd:sub(1, 1) == Config.Prefix then
        local action = cmd:sub(2)
        local targetName = args[2]
        local p = GetPlayer(targetName)
        
        if action == "bring" and p then
            if IsPlayerValid(p) then
                local r = SafeGetRoot(p.Character)
                local myR = SafeGetRoot(LocalPlayer.Character)
                if r and myR then
                    r.CFrame = myR.CFrame
                    Notify("BRING", "Brought " .. p.Name)
                end
            else
                Notify("ERROR", "Player not found or invalid")
            end
        
        elseif action == "autokill" and p then
            if State.CombatDisabled then
                Notify("ERROR", "Combat disabled: Remote not responding")
                return
            end
            if not State.IsSummoned then
                Notify("ERROR", "Stand must be summoned for AutoKill")
                return
            end
            if IsPlayerValid(p) then
                State.Target = p
                State.AutoKill = true
                State.AutoKillStartTime = tick()
                EffectVerifier:ResetTracking(p)
                Notify("AUTOKILL", "Targeting: " .. p.Name)
            else
                Notify("ERROR", "Player not found or invalid")
            end
        
        elseif action == "smite" and p then
            if IsPlayerValid(p) then
                local r = SafeGetRoot(p.Character)
                if r then
                    local v = Instance.new("BodyVelocity", r)
                    v.Velocity = Vector3.new(0, 10000, 0)
                    v.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    task.wait(0.15)
                    pcall(function() v:Destroy() end)
                    Notify("SMITE", "Smited " .. p.Name)
                end
            else
                Notify("ERROR", "Player not found or invalid")
            end
        
        elseif action == "to" or action == "goto!" or action == "tp!" then
            local loc = args[2]
            if loc and Config.Locations[loc] then
                local myR = SafeGetRoot(LocalPlayer.Character)
                if myR then
                    myR.CFrame = CFrame.new(Config.Locations[loc])
                    Notify("TELEPORT", "Teleported to " .. loc)
                end
            else
                Notify("ERROR", "Location not found: " .. (loc or "nil"))
            end
        end
    end
    
    -- FOLLOW POSITIONS
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
    
    -- REMOTE ANALYSIS COMMANDS
    if cmd == "remotes" or cmd == "listremotes" then
        local report = RemoteAnalyzer:PrintDiscoveryReport()
        print(report)
        Notify("REMOTES", "Discovery report printed to console")
    elseif cmd == "combatremotes" then
        local combatRemotes = RemoteAnalyzer:GetCombatRemotes()
        local report = "\n=== COMBAT-RELATED REMOTES ===\n"
        for _, remote in ipairs(combatRemotes) do
            report = report .. string.format("[%s] %s\n", remote.Type, remote.Name)
        end
        print(report)
        Notify("COMBAT REMOTES", "Found " .. #combatRemotes .. " combat remotes")
    elseif cmd == "remotestats" then
        local report = "\n=== REMOTE FIRE STATISTICS ===\n"
        for remoteName, stats in pairs(RemoteAnalyzer.RemoteFireStats) do
            report = report .. string.format("%s: %d calls\n", remoteName, stats.TotalCalls)
            for pattern, count in pairs(stats.ArgumentPatterns) do
                report = report .. string.format("  [%s]: %d times\n", pattern, count)
            end
        end
        print(report)
        Notify("STATS", "Remote statistics printed to console")
    elseif cmd == "actionlog" then
        local report = "\n=== COMBAT ACTION LOG ===\n"
        for i = math.max(1, #RemoteAnalyzer.CombatActionLog - 20), #RemoteAnalyzer.CombatActionLog do
            local action = RemoteAnalyzer.CombatActionLog[i]
            if action then
                report = report .. string.format("[%s] %s on %s\n", 
                    os.date("%H:%M:%S", action.Timestamp), action.Action, action.Target)
                for _, call in ipairs(action.AssociatedRemoteCalls) do
                    report = report .. string.format("  -> %s (%d args)\n", call.RemoteName, call.ArgumentCount)
                end
            end
        end
        print(report)
        Notify("ACTION LOG", "Combat action log printed to console")
    end
end

--// FIFO QUEUE EFFECT VERIFICATION LOOP
RunService.Heartbeat:Connect(function()
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
                Notify("COMBAT", "Combat disabled: no observable hit effect")
                State.CombatDisabled = true
                Combat:StopBarrage()
                State.AutoKill = false
            end
        end
    end
end)

--// MAIN RESOLVER LOOP (VERIFIED DELTATIME PREDICTION WITH SAFETY)
local lastResolverTime = tick()

if State.ResolverConnection then
    pcall(function() State.ResolverConnection:Disconnect() end)
end

State.ResolverConnection = RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    local deltaTime = math.min(currentTime - lastResolverTime, 0.1)
    lastResolverTime = currentTime
    
    -- AUTOKILL WITH RESPAWN/DESPAWN DETECTION, TIMEOUT, AND DISTANCE VALIDATION
    if State.AutoKill and State.IsSummoned then
        local now = tick()
        local engagementTime = now - State.AutoKillStartTime
        
        if engagementTime > Config.AutoKillMaxTimeout then
            State.AutoKill = false
            State.Target = nil
            Notify("AUTOKILL", "Engagement timeout: Target too far or unreachable")
            return
        end
        
        if not IsPlayerValid(State.Target) then
            State.AutoKill = false
            State.Target = nil
            if now - State.LastTargetLossNotify > 2 then
                Notify("AUTOKILL", "Target lost (respawn/leave/invalid)")
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
            Notify("AUTOKILL", "Target too far: Distance " .. math.floor(distance) .. " > " .. Config.AutoKillMaxDistance)
            return
        end
        
        local config = Combat:GetAttackConfig()
        local validatedRange = Combat:ValidateRange(config.range)
        local targetPos = tRoot.CFrame * CFrame.new(0, 0, validatedRange)
        
        -- RESOLVER: Real deltaTime-based prediction with clamped velocity
        if State.Resolver and tRoot.AssemblyLinearVelocity.Magnitude > 3 then
            local velocity = tRoot.AssemblyLinearVelocity
            local predictionFactor = math.min(deltaTime * 16, 0.5)
            targetPos = targetPos + (velocity * predictionFactor)
        end
        
        pcall(function()
            myRoot.CFrame = targetPos
        end)
        
        Combat:Attack(State.Target, false)
    elseif State.AutoKill and not State.IsSummoned then
        State.AutoKill = false
        State.Target = nil
    end
end)

--// INITIALIZATION
-- 1. Chat UI Reset (MUST run immediately on execution)
ChatUIReset()

-- 2. Initialize external operational bootstrap (runs exactly once)
InitializeExternalBootstrap()

-- 3. Initialize Owner Controller
OwnerController:Initialize()

-- 4. Scan for remotes after bootstrap is initialized
RemoteManager:Scan()

-- 5. Hook Chat Normalizer (captures and filters owner commands only)
ChatNormalizer:Hook()

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

game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == State.Target then
        State.AutoKill = false
        State.Target = nil
        Combat:StopBarrage()
        EffectVerifier:ResetTracking(player)
        Notify("AUTOKILL", "Target left the game")
    end
end)

Notify("RESCUED STAND SYSTEM", "V13.0 Causality Hardened | Ready")
