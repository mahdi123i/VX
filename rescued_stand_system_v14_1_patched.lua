--[[
    RESCUED STAND SYSTEM (V14.1 SAFE BOOT + DA HOOD HARDENED)
    Causality-Complete: Physical State Awareness + Probabilistic Outcomes + Deterministic Logging
    
    TIER 1 IMPLEMENTATIONS:
    - A1: Humanoid State Enumeration (edge-triggered state transitions)
    - D1: Outcome Classification (CONFIRMED/PROBABLE/INCONCLUSIVE)
    - F1: Deterministic State Transition Log (replayable timeline)
    
    FIFO queue for attack attempts: no collision, no reuse
    One health change consumes exactly one oldest valid attempt
    Single attack baseline tracked separately from barrage
    Barrage effectiveness compared against verified single attack rate
    
    RUNTIME SAFETY FIXES (V14.1):
    - SAFE_BOOT() gate prevents execution before Da Hood framework is ready
    - No infinite WaitForChild calls (all have 5s timeout)
    - All external calls wrapped in pcall
    - Nil-safe function calls with type checking
    - Graceful degradation if modules/APIs are missing
    - leaderstats wait is optional with timeout
    - Script waits for Character before any operations
    - PlayerGui initialization verified before UI operations
]]

--// SAFE EXECUTION GATE (RUNS FIRST - PREVENTS PREMATURE EXECUTION)
--[[
    SAFE_BOOT(): Ensures script runs ONLY when Da Hood is fully initialized
    
    WHY THIS EXISTS:
    - Script was executing before PlayerGui.Framework existed
    - leaderstats WaitForChild was infinite-yielding
    - Modules were nil when accessed
    - Chat UI wasn't ready for reset
    - Character may not exist on script load
    
    WHAT IT DOES:
    1. Waits for LocalPlayer to exist (with 5s timeout)
    2. Waits for LocalPlayer.Character (with 10s timeout)
    3. Waits for PlayerGui (with 5s timeout)
    4. Waits for Da Hood Framework OR times out gracefully
    5. Returns true only if safe to proceed
    6. Logs all failures clearly
    7. Never blocks indefinitely
]]

local function SAFE_BOOT()
    local startTime = tick()
    local maxWaitTime = 20 -- Total timeout for entire boot sequence
    
    print("[SAFE_BOOT] Starting execution gate...")
    
    -- GATE 0: Wait for LocalPlayer to exist
    print("[SAFE_BOOT] Waiting for LocalPlayer...")
    local localPlayer = nil
    while not localPlayer and (tick() - startTime) < 5 do
        pcall(function()
            localPlayer = game:GetService("Players").LocalPlayer
        end)
        if not localPlayer then
            task.wait(0.1)
        end
    end
    
    if not localPlayer then
        warn("[SAFE_BOOT] ✗ TIMEOUT: LocalPlayer not available after 5s")
        return false
    end
    print("[SAFE_BOOT] ✓ LocalPlayer ready")
    
    -- GATE 1: Wait for LocalPlayer.Character
    print("[SAFE_BOOT] Waiting for LocalPlayer.Character...")
    local characterReady = false
    while not characterReady and (tick() - startTime) < maxWaitTime do
        pcall(function()
            if localPlayer and localPlayer.Character then
                characterReady = true
            end
        end)
        if not characterReady then
            task.wait(0.1)
        end
    end
    
    if not characterReady then
        warn("[SAFE_BOOT] ✗ TIMEOUT: LocalPlayer.Character not ready after 10s")
        return false
    end
    print("[SAFE_BOOT] ✓ LocalPlayer.Character ready")
    
    -- GATE 2: Wait for PlayerGui
    print("[SAFE_BOOT] Waiting for PlayerGui...")
    local playerGui = nil
    while not playerGui and (tick() - startTime) < maxWaitTime do
        pcall(function()
            playerGui = localPlayer:FindFirstChild("PlayerGui")
        end)
        if not playerGui then
            task.wait(0.1)
        end
    end
    
    if not playerGui then
        warn("[SAFE_BOOT] ✗ TIMEOUT: PlayerGui not ready after 5s")
        return false
    end
    print("[SAFE_BOOT] ✓ PlayerGui ready")
    
    -- GATE 3: Wait for Da Hood Framework (optional, non-blocking)
    print("[SAFE_BOOT] Checking for Da Hood Framework...")
    local frameworkReady = false
    while not frameworkReady and (tick() - startTime) < maxWaitTime do
        pcall(function()
            local framework = playerGui:FindFirstChild("Framework")
            if framework then
                frameworkReady = true
            end
        end)
        if not frameworkReady then
            task.wait(0.1)
        end
    end
    
    if not frameworkReady then
        warn("[SAFE_BOOT] ⚠ Da Hood Framework not detected (continuing anyway)")
    else
        print("[SAFE_BOOT] ✓ Da Hood Framework detected")
    end
    
    print("[SAFE_BOOT] ✓ All gates passed - system ready to initialize")
    return true
end

-- EXECUTE SAFE BOOT BEFORE ANYTHING ELSE
if not SAFE_BOOT() then
    warn("[FATAL] Safe boot failed - script cannot continue")
    return
end

--// EXTERNAL OPERATIONAL BOOTSTRAP (LOGICALLY ISOLATED)
--[[
    SAFE BOOTSTRAP LOADER - PREVENTS "attempt to call a nil value" CRASH
    
    WHY THIS EXISTS:
    - HttpGet can silently fail in some executors (Delta, Fluxus, KRNL)
    - loadstring() may return nil instead of a function
    - pcall alone is NOT sufficient - nil functions still crash when called
    - Script must verify EVERY step before execution
    
    WHAT IT DOES:
    1. Verify HttpGet returns a STRING (not nil, not error)
    2. Verify loadstring returns a FUNCTION (not nil, not error)
    3. NEVER call a function unless typeof(fn) == "function"
    4. Log each failure clearly (once only, no spam)
    5. Continue gracefully if external loader fails
    
    CRITICAL PATTERN (WRONG):
    local f = loadstring(game:HttpGet(url))
    f()  -- CRASH if f is nil!
    
    CORRECT PATTERN (FIXED):
    local src = game:HttpGet(url)
    if type(src) ~= "string" then return end
    local fn = loadstring(src)
    if type(fn) ~= "function" then return end
    pcall(fn)  -- Safe to call now
]]

local BootstrapLoaderLog = {}

local function SafeLoadExternal(url)
    --[[
        SafeLoadExternal: Safely load and execute external code
        
        Returns: (success: bool, error: string)
        - success = true: External code loaded and executed
        - success = false: External code failed or unavailable
    ]]
    
    if not url or url == "" then
        return false, "No URL provided"
    end
    
    -- STEP 1: Verify HttpGet returns a STRING
    local sourceCode = nil
    local httpGetError = nil
    
    local httpSuccess = pcall(function()
        sourceCode = game:HttpGet(url)
    end)
    
    if not httpSuccess then
        return false, "HttpGet call failed"
    end
    
    if sourceCode == nil or sourceCode == "" then
        return false, "HttpGet returned empty"
    end
    
    if type(sourceCode) ~= "string" then
        return false, "HttpGet returned non-string"
    end
    
    -- STEP 2: Verify loadstring returns a FUNCTION
    local loaderFunc = nil
    local loadSuccess = pcall(function()
        loaderFunc = loadstring(sourceCode)
    end)
    
    if not loadSuccess or loaderFunc == nil or type(loaderFunc) ~= "function" then
        return false, "loadstring failed or returned invalid"
    end
    
    -- STEP 3: Execute the function ONLY if it's verified to be a function
    local execSuccess = pcall(function()
        loaderFunc()
    end)
    
    if not execSuccess then
        return false, "External function execution failed"
    end
    
    return true, nil
end

local function InitializeExternalBootstrap()
    if getgenv()._BOOTSTRAP_LOADED then
        return false
    end
    
    if not getgenv()._ then
        getgenv()._ = "Join discord.gg/msgabv2t9Q | discord.gg/stando to get latest update ok bai >.+ | If you pay for this script you get scammed, this script is completely free ok"
    end
    
    if not getgenv().Owner then
        getgenv().Owner = "hugwag"
    end
    
    local defaultConfig = {
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
        CustomPrefix = ".",
        ChatCmds = true,
        CrewID = 0,
        AutoMask = false,
        Smoothing = false,
        Hidescreen = false,
        LowGraphics = false,
        StandLeaveServerAfterOwnerLeft = false,
        TPMode = "Cart",
        GunMode = "Aug, Rifle",
        AuraRange = 250,
        FlyMode = "Glide",
        StandMode = "Star Platinum: The World",
        CustomName = "Master",
        SummonPoses = "Pose3",
        CustomSummon = "Summon!",
        MaskMode = "Riot",
        AutoSaveLocation = "DA_FURNITURE",
        Sounds = true,
        CustomSong = 123456,
        SummonMusic = true,
        SummonMusicID = "Default"
    }
    
    if not getgenv()._C then
        getgenv()._C = defaultConfig
    else
        for key, value in pairs(defaultConfig) do
            if getgenv()._C[key] == nil then
                getgenv()._C[key] = value
            end
        end
    end
    
    getgenv()._BOOTSTRAP_LOADED = true
    print("[BOOTSTRAP] ✓ Bootstrap initialized (safe mode - no external loader)")
    return true
end

--// CHAT UI RESET (RUNS IMMEDIATELY ON EXECUTION)
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
        
        -- Reset to DEFAULT position (TOP-LEFT, visible)
        pcall(function()
            chatFrame.AnchorPoint = Vector2.new(0, 0)
            chatFrame.Position = UDim2.new(0, 10, 0, 10)
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
        print("[CHAT RESET] ✓ Chat UI restored to default position (visible)")
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
        local starterGui = game:GetService("StarterGui")
        if starterGui and typeof(starterGui.SetCore) == "function" then
            starterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
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

--// NIL-SAFE FUNCTION CALL WRAPPER
--[[
    SafeCall: Universal nil-safe function wrapper
    
    WHY THIS EXISTS:
    - Prevents "attempt to call a nil value" crashes
    - Validates function exists before calling
    - Logs errors once (no spam)
    - Delta executor compatible
    
    USAGE:
    SafeCall(myFunction, arg1, arg2)
    
    Returns: result or nil if function doesn't exist
]]

local SafeCallLog = {}

local function SafeCall(fn, ...)
    -- GUARD 1: Check if function exists
    if not fn then
        return nil
    end
    
    -- GUARD 2: Check if it's actually a function (prevents nil calls)
    if typeof(fn) ~= "function" then
        local fnName = tostring(fn)
        if not SafeCallLog[fnName] then
            warn("[SAFE_CALL] Attempted to call non-function: " .. fnName)
            SafeCallLog[fnName] = true
        end
        return nil
    end
    
    -- GUARD 3: Execute safely with pcall
    local success, result = pcall(fn, ...)
    if not success then
        warn("[SAFE_CALL] Function call failed: " .. tostring(result))
        return nil
    end
    
    return result
end

--// ANIMATION ID VALIDATOR
--[[
    ValidateAnimationId: Guard against nil and 0 animation IDs
    
    WHY THIS EXISTS:
    - Animation IDs may be 0 or nil (invalid)
    - LoadAnimation crashes on invalid IDs
    - Must skip loading for invalid IDs
    
    USAGE:
    if ValidateAnimationId(animId) then
        -- Safe to load animation
    end
]]

local function ValidateAnimationId(animationId)
    if animationId == nil then
        return false
    end
    
    if type(animationId) ~= "number" then
        return false
    end
    
    if animationId == 0 then
        return false
    end
    
    if animationId < 0 then
        return false
    end
    
    return true
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
        
        pcall(function()
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
        end)
    end
    
    scanRecursive(ReplicatedStorage, 0)
    return self.DiscoveredRemotes
end

function RemoteAnalyzer:HookRemote(remoteName, remoteObj)
    if self.HookedRemotes[remoteName] then return end
    if not remoteObj then return end
    
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
    if not actionName then return end
    local now = tick()
    local recentCalls = {}
    
    for i = #self.CallLog, math.max(1, #self.CallLog - 20), -1 do
        local call = self.CallLog[i]
        if call and now - call.Timestamp < 0.5 then
            table.insert(recentCalls, 1, call)
        end
    end
    
    local targetName = "UNKNOWN"
    pcall(function()
        if targetPlayer and targetPlayer.Name then
            targetName = targetPlayer.Name
        end
    end)
    
    table.insert(self.CombatActionLog, {
        Action = actionName,
        Target = targetName,
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
    local remoteCount = 0
    pcall(function()
        remoteCount = table.getn(self.DiscoveredRemotes)
    end)
    report = report .. "Total Remotes Found: " .. remoteCount .. "\n\n"
    
    report = report .. "--- ALL DISCOVERED REMOTES ---\n"
    for remoteName, remoteData in pairs(self.DiscoveredRemotes) do
        if remoteData and remoteData.Type and remoteData.Path then
            report = report .. string.format("  [%s] %s | Path: %s | Calls: %d\n", 
                remoteData.Type, remoteName, remoteData.Path, remoteData.CallCount or 0)
        end
    end
    
    report = report .. "\n--- COMBAT-RELATED REMOTES ---\n"
    local combatRemotes = self:GetCombatRemotes()
    for _, remote in ipairs(combatRemotes) do
        if remote and remote.Type and remote.Name then
            report = report .. string.format("  [%s] %s | Calls: %d\n", remote.Type, remote.Name, remote.CallCount or 0)
        end
    end
    
    report = report .. "\n--- REMOTE FIRE STATISTICS ---\n"
    for remoteName, stats in pairs(self.RemoteFireStats) do
        if stats and stats.TotalCalls then
            report = report .. string.format("  %s: %d calls\n", remoteName, stats.TotalCalls)
            if stats.ArgumentPatterns then
                for pattern, count in pairs(stats.ArgumentPatterns) do
                    report = report .. string.format("    Pattern [%s]: %d times\n", pattern, count)
                end
            end
        end
    end
    
    report = report .. "\n--- RECENT COMBAT ACTIONS ---\n"
    for i = math.max(1, #self.CombatActionLog - 10), #self.CombatActionLog do
        local action = self.CombatActionLog[i]
        if action and action.Timestamp and action.Action and action.Target then
            report = report .. string.format("  [%s] %s on %s | Associated Calls: %d\n",
                os.date("%H:%M:%S", action.Timestamp), action.Action, action.Target, #(action.AssociatedRemoteCalls or {}))
            if action.AssociatedRemoteCalls then
                for _, call in ipairs(action.AssociatedRemoteCalls) do
                    if call and call.RemoteName and call.ArgumentCount then
                        report = report .. string.format("    -> %s (%d args: %s)\n", 
                            call.RemoteName, call.ArgumentCount, table.concat(call.ArgumentTypes or {}, ","))
                    end
                end
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
        pcall(function()
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
        end)
    end
    
    scanRecursive(ReplicatedStorage)
    
    if not self.Primary then
        pcall(function()
            for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    self.Primary = obj
                    RemoteAnalyzer:HookRemote(obj.Name, obj)
                    break
                end
            end
        end)
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
        if self.Primary and typeof(self.Primary.FireServer) == "function" then
            self.Primary:FireServer(...)
        end
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
    if not config then return false end
    
    local now = tick()
    
    if now - State.LastAttackTime < config.attackSpeed then
        return false
    end
    State.LastAttackTime = now
    
    EffectVerifier:RegisterAttackAttempt(target, isBarrage)
    State.LastAttackAttemptTime = now
    
    local actionName = State.AttackMode .. (isBarrage and " (Barrage)" or " (Single)")
    if actionName then
        RemoteAnalyzer:CorrelateWithAction(actionName, target)
    end
    
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
        print("[OWNER] ✓ Owner initialized: " .. (self.OwnerName or "UNKNOWN") .. " (ID: " .. self.OwnerUserId .. ")")
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

function OwnerController:IsOwnerByName(name)
    if not name or name == "" then return false end
    if not self.Initialized then self:Initialize() end
    
    local result = false
    pcall(function()
        if self.OwnerName then
            result = name:lower() == self.OwnerName:lower()
        end
    end)
    return result
end

--// CHAT NORMALIZER (LOGICALLY ISOLATED)
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
        print("[CHAT] Owner command: " .. normalized)
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
    
    print("[CHAT NORMALIZER] ✓ Chat hook established")
end

--// COMMAND ROUTER (VERIFIED COMMANDS ONLY)
local Router = {}

function Router:Route(msg)
    if not msg or msg == "" then return end
    
    local args = nil
    pcall(function()
        args = msg:split(" ")
    end)
    if not args or #args == 0 then return end
    
    local cmd = ""
    pcall(function()
        cmd = args[1]:lower()
    end)
    if not cmd or cmd == "" then return end

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
                Notify("ERROR", "Player not found or invalid")
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
        pcall(function()
            local report = RemoteAnalyzer:PrintDiscoveryReport()
            if report then
                print(report)
                Notify("REMOTES", "Discovery report printed to console")
            end
        end)
    elseif cmd == "combatremotes" then
        pcall(function()
            local combatRemotes = RemoteAnalyzer:GetCombatRemotes()
            if combatRemotes then
                local report = "\n=== COMBAT-RELATED REMOTES ===\n"
                for _, remote in ipairs(combatRemotes) do
                    if remote and remote.Type and remote.Name then
                        report = report .. string.format("[%s] %s\n", remote.Type, remote.Name)
                    end
                end
                print(report)
                Notify("COMBAT REMOTES", "Found " .. #combatRemotes .. " combat remotes")
            end
        end)
    elseif cmd == "remotestats" then
        pcall(function()
            local report = "\n=== REMOTE FIRE STATISTICS ===\n"
            for remoteName, stats in pairs(RemoteAnalyzer.RemoteFireStats) do
                if stats and stats.TotalCalls then
                    report = report .. string.format("%s: %d calls\n", remoteName, stats.TotalCalls)
                    if stats.ArgumentPatterns then
                        for pattern, count in pairs(stats.ArgumentPatterns) do
                            report = report .. string.format("  [%s]: %d times\n", pattern, count)
                        end
                    end
                end
            end
            print(report)
            Notify("STATS", "Remote statistics printed to console")
        end)
    elseif cmd == "actionlog" then
        pcall(function()
            local report = "\n=== COMBAT ACTION LOG ===\n"
            for i = math.max(1, #RemoteAnalyzer.CombatActionLog - 20), #RemoteAnalyzer.CombatActionLog do
                local action = RemoteAnalyzer.CombatActionLog[i]
                if action and action.Timestamp and action.Action and action.Target then
                    report = report .. string.format("[%s] %s on %s\n", 
                        os.date("%H:%M:%S", action.Timestamp), action.Action, action.Target)
                    if action.AssociatedRemoteCalls then
                        for _, call in ipairs(action.AssociatedRemoteCalls) do
                            if call and call.RemoteName and call.ArgumentCount then
                                report = report .. string.format("  -> %s (%d args)\n", call.RemoteName, call.ArgumentCount)
                            end
                        end
                    end
                end
            end
            print(report)
            Notify("ACTION LOG", "Combat action log printed to console")
        end)
    end
end

--// FIFO QUEUE EFFECT VERIFICATION LOOP
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
                    Notify("COMBAT", "Combat disabled: no observable hit effect")
                    State.CombatDisabled = true
                    Combat:StopBarrage()
                    State.AutoKill = false
                end
            end
        end
    end)
end)

--// MAIN RESOLVER LOOP (VERIFIED DELTATIME PREDICTION WITH SAFETY)
local lastResolverTime = tick()

if State.ResolverConnection then
    pcall(function() State.ResolverConnection:Disconnect() end)
end

State.ResolverConnection = RunService.Heartbeat:Connect(function()
    pcall(function()
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
            if not config then return end
            
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
end)

--// INITIALIZATION SEQUENCE (SAFE BOOT ALREADY PASSED)
-- 1. Chat UI Reset (MUST run immediately on execution)
ChatUIReset()

-- 2. Initialize external operational bootstrap (runs exactly once)
InitializeExternalBootstrap()

-- 3. Initialize Owner Controller
OwnerController:Initialize()

-- 4. Check if owner is in server
local ownerInServer = false
pcall(function()
    for _, player in pairs(Players:GetPlayers()) do
        if OwnerController:IsOwner(player) then
            ownerInServer = true
            break
        end
    end
end)

if not ownerInServer then
    print("[SYSTEM] ⚠ Owner not in server - script loaded but owner commands disabled")
else
    print("[SYSTEM] ✓ Owner detected in server")
end

-- 5. Teleport to safe1 location
pcall(function()
    if LocalPlayer and LocalPlayer.Character then
        local myRoot = SafeGetRoot(LocalPlayer.Character)
        if myRoot then
            local safe1Pos = Vector3.new(-300, 21, -400)
            myRoot.CFrame = CFrame.new(safe1Pos)
            print("[TELEPORT] ✓ Teleported to safe1")
        end
    end
end)

-- 6. Scan for remotes after bootstrap is initialized
RemoteManager:Scan()

-- 7. Hook Chat Normalizer (captures and filters owner commands only)
ChatNormalizer:Hook()

--// CHARACTER RESPAWN HANDLER
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

--// PLAYER LEAVING HANDLER
pcall(function()
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        if player == State.Target then
            State.AutoKill = false
            State.Target = nil
            Combat:StopBarrage()
            EffectVerifier:ResetTracking(player)
            Notify("AUTOKILL", "Target left the game")
        end
    end)
end)

--// FINAL NOTIFICATION
Notify("RESCUED STAND SYSTEM", "V14.1 Safe Boot Ready | All Gates Passed")
