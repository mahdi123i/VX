-- Safe environment initialization for loadstring execution
if not getgenv then
    getgenv = function() return _G end
end

-- Polyfill missing executor functions
if not setfpscap then
    setfpscap = function() end
end
if not setfflag then
    setfflag = function() end
end
if not replicatesignal then
    replicatesignal = function() end
end
if not fireclickdetector then
    fireclickdetector = function() end
end

local Owner = "Mahdirml123i"
local BlackScreen = false
local DisableRendering = false
local FPSCap = 60
local Guns = {"aug", "rifle"}
local EquipGunCount = 2
local DisabledGuns = {flintlock = true}
local SkipAmmoFor = {["[Flintlock]"] = true}
local AmmoPurchaseCount = 10
local ArmorThreshold = 80
local LowLagMode = true
local ArmorRecheckDelay = LowLagMode and 3 or 1.5
local perf = {
    loop = LowLagMode and 0.05 or 0,
    combat = LowLagMode and 0.03 or 0,
    void = LowLagMode and 0.2 or 0,
    teleport = LowLagMode and 0.05 or 0,
    target = LowLagMode and 0.1 or 0,
    summon = LowLagMode and 0.05 or 0,
    mask = LowLagMode and 0.1 or 0,
    equip = LowLagMode and 0.1 or 0,
    killall = LowLagMode and 0.2 or 0,
    hitbox = LowLagMode and 0.2 or 0,
    shoot = LowLagMode and 0.03 or 0,
}

local defaultPerf = {}
for k, v in pairs(perf) do
    defaultPerf[k] = v
end
local defaultConfig = {}
local defaultConfigCaptured = false
local stand2Active = false

local function standWait(base)
    if stand2Active then
        return math.min(base, 0.01)
    end
    return base
end

if not game:IsLoaded() then game.Loaded:Wait() end

local player = game.Players.LocalPlayer

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

local Bots = {}

Bots[LocalPlayer.Name] = LocalPlayer.Name

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local currentGunIndex = 1

local gunData = {
    rifle = {
        toolName = "[Rifle]",
        shopName = "[Rifle] - $1694"
    },
    aug = {
        toolName = "[AUG]",
        shopName = "[AUG] - $2131"
    },
    flintlock = {
        toolName = "[Flintlock]",
        shopName = "[Flintlock] - $1421"
    },
    lmg = {
        toolName = "[LMG]",
        shopName = "[LMG] - $4098"
    },
    db = {
        toolName = "[Double-Barrel SG]",
        shopName = "[Double-Barrel SG] - $1475"
    },
}

local RunService = game:GetService("RunService")

if DisableRendering then
    RunService:Set3dRenderingEnabled(false)
end

local Lighting = game:GetService("Lighting")

Lighting.GlobalShadows = false

for _, obj in pairs(workspace:GetDescendants()) do
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
        obj.Enabled = false
    end
end

workspace.StreamingEnabled = true

getgenv().enabled = false
getgenv().enabled1 = false
local auraspeed = 11
local auradistance = 4
local auraangle = math.random() * math.pi * 2
local standHomeName = Owner
local stand2Active = false
local stand2TargetName = nil
local stand2TargetUserId = nil
local stand2CurrentTarget = nil
local powerModeActive = false
local buyingArmorInProgress = false
local autoArmorEnabled = true
local autoFireArmorEnabled = false -- Don't auto-buy fire armor.
local lastArmorPurchase = 0

local lockedTarget = nil
local grabCheckEnabled = true
local koCheckEnabled = true
local buyingInProgress = false
local buyingGunInProgress = false
local buyingMaskInProgress = false
local buyingVehicleInProgress = false
local teleporting = false
local autodrop = false
local ragebottargets = {}
local currentTargetIndex = 1
local fakepositionconnection = nil

-- Global hard stop latch (set by .v). When true, combat/movement logic should not run.
local hardStop = false

-- Loop targeting support for .l / .lk
local shouldSwitch = false
local function isValidLoopTarget(plr)
    if not plr or not plr:IsDescendantOf(game) then
        return false
    end
    local char = plr.Character
    if not char then
        return false
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return false
    end
    local body = char:FindFirstChild("BodyEffects")
    if body then
        local sDeath = body:FindFirstChild("SDeath")
        if sDeath and sDeath.Value then
            return false
        end
    end
    return true
end
local automaskenabled = false
local trashtalkactive = false
local fpactive = false
local refreshingfakeposition = false
local didRefreshOnDeath = false
local autoSaveEnabled = false
local autoSavePosition = Vector3.new(-490.6, 93.412, -91.7)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer
local character = game.Players.LocalPlayer.Character
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService("Workspace")
local camera = workspace.CurrentCamera
local _, y, r = camera.CFrame:ToOrientation()

-- Avoid infinite yield warnings from missing objects in some games.
local function ensureChild(parent, className, name)
    local child = parent:FindFirstChild(name)
    if child then
        return child
    end
    local inst = Instance.new(className)
    inst.Name = name
    inst.Parent = parent
    return inst
end

ensureChild(ReplicatedStorage, "RemoteEvent", "FW_ShowEvent")

local function ensureLeaderstats(plr)
    if not plr:FindFirstChild("leaderstats") then
        local stats = Instance.new("Folder")
        stats.Name = "leaderstats"
        stats.Parent = plr
    end
end

for _, plr in ipairs(Players:GetPlayers()) do
    ensureLeaderstats(plr)
end

Players.PlayerAdded:Connect(ensureLeaderstats)

getgenv().whitelist = {}
getgenv().sentryprotected = {}
getgenv().sentrywhitelisted = {}
getgenv().protectedwhitelist = {}

getgenv().protectedwhitelist[Owner] = true

local basePosition = Vector3.new(87240, 29628, -482290)

local whitelistZone = Instance.new("Part")
whitelistZone.Name = "WhitelistBeacon"
whitelistZone.Anchored = true
whitelistZone.CanCollide = true
whitelistZone.Transparency = 1
whitelistZone.Size = Vector3.new(30, 10, 30)
whitelistZone.Position = basePosition
whitelistZone.Parent = workspace

local wallFront = Instance.new("Part")
wallFront.Name = "WhitelistBeacon_WallFront"
wallFront.Anchored = true
wallFront.CanCollide = true
wallFront.Transparency = 1
wallFront.Size = Vector3.new(32, 10, 1)
wallFront.Position = basePosition + Vector3.new(0, 5, 15.5)
wallFront.Parent = workspace

local wallBack = Instance.new("Part")
wallBack.Name = "WhitelistBeacon_WallBack"
wallBack.Anchored = true
wallBack.CanCollide = true
wallBack.Transparency = 1
wallBack.Size = Vector3.new(32, 10, 1)
wallBack.Position = basePosition + Vector3.new(0, 5, -15.5)
wallBack.Parent = workspace

local wallLeft = Instance.new("Part")
wallLeft.Name = "WhitelistBeacon_WallLeft"
wallLeft.Anchored = true
wallLeft.CanCollide = true
wallLeft.Transparency = 1
wallLeft.Size = Vector3.new(1, 10, 30)
wallLeft.Position = basePosition + Vector3.new(-15.5, 5, 0)
wallLeft.Parent = workspace

local wallRight = Instance.new("Part")
wallRight.Name = "WhitelistBeacon_WallRight"
wallRight.Anchored = true
wallRight.CanCollide = true
wallRight.Transparency = 1
wallRight.Size = Vector3.new(1, 10, 30)
wallRight.Position = basePosition + Vector3.new(15.5, 5, 0)
wallRight.Parent = workspace

local roof = Instance.new("Part")
roof.Name = "WhitelistBeacon_Roof"
roof.Anchored = true
roof.CanCollide = true
roof.Transparency = 1
roof.Size = Vector3.new(32, 1, 32)
roof.Position = basePosition + Vector3.new(0, 10.5, 0)
roof.Parent = workspace

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local zoneSize = Vector3.new(20, 10, 20)
local basePosition = whitelistZone.Position
local WHITELIST_RADIUS = 20

function getRandomPositionInZone()
    local halfSize = zoneSize / 2
    local randomX = basePosition.X + math.random() * zoneSize.X - halfSize.X
    local randomZ = basePosition.Z + math.random() * zoneSize.Z - halfSize.Z
    local fixedY = basePosition.Y + halfSize.Y + 3
    return Vector3.new(randomX, fixedY, randomZ)
end

function teleportPlayerRandomly()
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero

    local randomPos = getRandomPositionInZone()
    hrp.CFrame = CFrame.new(randomPos)

    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end

function isPlayerNearPosition(player, position, radius)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local distance = (hrp.Position - position).Magnitude
    return distance <= radius
end

function checkWhitelistNearPosition()
    for _, player in pairs(Players:GetPlayers()) do
        if isPlayerNearPosition(player, basePosition, WHITELIST_RADIUS) then
            if not getgenv().whitelist[player.Name] then
                getgenv().whitelist[player.Name] = true
            end
        end
    end
end

local function findPlayerByPartial(input)
    if not input then
        return nil
    end
    input = input:lower()
    for _, plr in ipairs(Players:GetPlayers()) do
        local name = plr.Name:lower()
        local display = plr.DisplayName:lower()
        if name:find(input, 1, true) or display:find(input, 1, true) then
            return plr
        end
    end
    return nil
end

local function trimInput(input)
    if not input then
        return nil
    end
    return input:gsub("^%s+", ""):gsub("%s+$", "")
end

local handleStand2Command
local disableStand2
local activatePowerMode
local deactivatePowerMode

-- Forward declarations - these will be properly defined later
activatePowerMode = function()
    -- Placeholder - will be overridden
end

deactivatePowerMode = function()
    -- Placeholder - will be overridden
end

local targetPlayer = nil
local lastOwnerPosition = nil
local shootRunning = true
local shotsPerTick = LowLagMode and 4 or 10
local followShotsPerTick = LowLagMode and 2 or 3
local followShotCooldown = LowLagMode and 0.05 or 0.01
local followGunSpacing = 0
local followGridCellSize = 6
local followGridRadius = LowLagMode and 200 or 250
local followMaxTargets = LowLagMode and 10 or 20
local followShootThroughWalls = true
local lastFollowShotAt = 0
local followFireInProgress = false
local shootInterval = perf.shoot
local lastShootAt = 0
local function getShootHandle(tool)
    if not tool or not tool:IsA("Tool") then return nil end
    if not tool:FindFirstChild("Ammo") then return nil end
    local handle = tool:FindFirstChild("Handle")
    if not handle or not handle.Parent then return nil end
    return handle
end
local function isGunTool(tool)
    return tool and tool:IsA("Tool") and tool:FindFirstChild("Ammo")
end
local function getGunToolByKey(gunKey)
    local info = gunData[gunKey]
    if not info then
        return nil
    end
    local toolName = info.toolName
    local lp = game.Players.LocalPlayer
    local char = lp and lp.Character
    if char then
        local tool = char:FindFirstChild(toolName)
        if tool and tool:IsA("Tool") then
            return tool
        end
    end
    local backpack = lp and lp:FindFirstChild("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild(toolName)
        if tool and tool:IsA("Tool") then
            return tool
        end
    end
    return nil
end
local function collectGunTools()
    local tools = {}
    local seen = {}
    local lp = game.Players.LocalPlayer

    local function addTool(tool)
        if tool and not seen[tool] and getShootHandle(tool) then
            seen[tool] = true
            table.insert(tools, tool)
        end
    end

    local char = lp and lp.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            addTool(child)
        end
    end

    local backpack = lp and lp:FindFirstChild("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            addTool(child)
        end
    end

    return tools
end
local function isAliveCharacter(char)
    if not char then
        return false
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    local bodyEffects = char:FindFirstChild("BodyEffects")
    if bodyEffects then
        local koValue = bodyEffects:FindFirstChild("K.O")
        if koValue and koValue.Value then
            return false
        end
        local sDeathValue = bodyEffects:FindFirstChild("SDeath")
        if sDeathValue and sDeathValue.Value then
            return false
        end
    end
    return true
end
local function collectGridTargets(centerPos)
    local lp = game.Players.LocalPlayer
    local cells = {}
    if not centerPos or followGridCellSize <= 0 or followGridRadius <= 0 then
        return {}
    end
    for _, player in ipairs(game.Players:GetPlayers()) do
        local char = player.Character
        if player ~= lp and player ~= targetPlayer
            and not getgenv().whitelist[player.Name]
            and not getgenv().protectedwhitelist[player.Name]
            and char and char:FindFirstChild("Head")
            and not char:FindFirstChild("GRABBING_CONSTRAINT")
            and not char:FindFirstChild("ForceField")
            and isAliveCharacter(char) then
            local head = char.Head
            local offset = head.Position - centerPos
            if offset.Magnitude <= followGridRadius then
                local gx = math.floor(offset.X / followGridCellSize)
                local gz = math.floor(offset.Z / followGridCellSize)
                local key = gx .. ":" .. gz
                local cellCenter = Vector3.new(
                    centerPos.X + (gx + 0.5) * followGridCellSize,
                    head.Position.Y,
                    centerPos.Z + (gz + 0.5) * followGridCellSize
                )
                local score = (head.Position - cellCenter).Magnitude
                local entry = cells[key]
                if not entry or score < entry.score then
                    cells[key] = {gx = gx, gz = gz, player = player, score = score}
                end
            end
        end
    end
    local list = {}
    for _, entry in pairs(cells) do
        table.insert(list, entry)
    end
    table.sort(list, function(a, b)
        local da = math.abs(a.gx) + math.abs(a.gz)
        local db = math.abs(b.gx) + math.abs(b.gz)
        if da == db then
            if a.gz == b.gz then
                return a.gx < b.gx
            end
            return a.gz < b.gz
        end
        return da < db
    end)
    local targets = {}
    local limit = math.min(#list, followMaxTargets)
    for i = 1, limit do
        table.insert(targets, list[i].player)
    end
    return targets
end
local reloadCooldown = 0.4
local lastReloadAt = {}

local function captureDefaultConfig()
    if defaultConfigCaptured then
        return
    end
    defaultConfig = {
        LowLagMode = LowLagMode,
        auraspeed = auraspeed,
        auradistance = auradistance,
        shotsPerTick = shotsPerTick,
        followShotsPerTick = followShotsPerTick,
        followShotCooldown = followShotCooldown,
        followGridRadius = followGridRadius,
        followMaxTargets = followMaxTargets,
        reloadCooldown = reloadCooldown,
        hitboxsize = hitboxsize,
        FPSCap = FPSCap,
    }
    defaultConfigCaptured = true
end

local function isReloading()
    local lp = game.Players.LocalPlayer
    local char = lp and lp.Character
    local bodyEffects = char and char:FindFirstChild("BodyEffects")
    local reloadFlag = bodyEffects and bodyEffects:FindFirstChild("Reload")
    return reloadFlag and reloadFlag.Value
end

local function tryReloadTool(tool)
    local ammo = tool and tool:FindFirstChild("Ammo")
    if not ammo or ammo.Value > 0 then
        return false
    end
    if isReloading() then
        return true
    end
    local now = os.clock()
    if lastReloadAt[tool] and (now - lastReloadAt[tool]) < reloadCooldown then
        return true
    end
    lastReloadAt[tool] = now
    ReplicatedStorage.MainEvent:FireServer("Reload", tool)
    return true
end
local function fireToolAtTarget(tool, targetPart, shots)
    local lp = game.Players.LocalPlayer
    local char = lp and lp.Character
    if not (tool and char and targetPart) then
        return
    end
    local equippedNow = false
    if tool.Parent ~= char then
        tool.Parent = char
        equippedNow = true
    end
    if equippedNow then
        RunService.Heartbeat:Wait()
        if tool.Parent ~= char then
            return
        end
    end
    local handle = getShootHandle(tool)
    if not handle then
        return
    end
    shots = shots or 1
    if tryReloadTool(tool) then
        return
    end
    local origin = handle.Position
    if followShootThroughWalls and targetPart then
        local delta = targetPart.Position - origin
        if delta.Magnitude > 0 then
            origin = origin + delta.Unit * 0.1
        end
    end
    for _ = 1, shots do
        ReplicatedStorage.MainEvent:FireServer(
            "ShootGun",
            handle,
            origin,
            targetPart.Position,
            targetPart,
            Vector3.new(0, 0, 0)
        )
    end
end

local noclipActive = false
local noclipParts = {}

local function setNoclip(active)
    if noclipActive == active then
        return
    end
    noclipActive = active
    if not active then
        for part, wasCanCollide in pairs(noclipParts) do
            if part and part.Parent and part:IsA("BasePart") then
                part.CanCollide = wasCanCollide
            end
        end
        noclipParts = {}
    end
end

RunService.Stepped:Connect(function()
    if not noclipActive then
        return
    end
    local char = LocalPlayer.Character
    if not char then
        return
    end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if noclipParts[part] == nil then
                noclipParts[part] = part.CanCollide
            end
            part.CanCollide = false
        end
    end
end)

local function withNoclip(fn)
    setNoclip(true)
    local ok, err = pcall(fn)
    setNoclip(false)
    if not ok then
        warn(err)
    end
end

local function safeTeleportToShop(root, shopBase)
    if not root or not shopBase then
        return
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = CFrame.new(shopBase.Position + Vector3.new(0, 3, 0))
    task.wait(0.05)
    root.CFrame = CFrame.new(shopBase.Position + Vector3.new(0, -8, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end
local stomponly = false
getgenv().downonly = false
local bringonly = false
local takeonly = false
local opkill = false
local summonTarget = nil
local summonMode = "middle"

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local voiding = true

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Character = player.Character or player.CharacterAdded:Wait()
local hrp = Character:WaitForChild("HumanoidRootPart")

task.spawn(function()
    while true do
        if voiding and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) and not vehicleMode then
            hrp.CFrame = CFrame.new(
                math.random(-999999, 999999),
                math.random(0, 999999),
                math.random(-999999, 999999)
            )
        end
        task.wait(standWait(perf.void))
    end
end)

player.CharacterAdded:Connect(function(char)
    hrp = char:WaitForChild("HumanoidRootPart")
end)

Workspace.FallenPartsDestroyHeight = 0/0

local hasSentKOMessage = false

local TextChatService = game:GetService("TextChatService")
local textChannel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")

TextChatService.ChatWindowConfiguration.Enabled = true

function sendMessage(message)
    if textChannel and message then
        textChannel:SendAsync(message)
    end
end

local activationAnnounced = false
task.defer(function()
    if activationAnnounced then
        return
    end
    activationAnnounced = true
    sendMessage("V!N Activated")
end)

local sideOffset = 10

function startFollowingTarget(senderName)
    targetPlayer = game.Players:FindFirstChild(senderName)
    if not targetPlayer then return end
    standHomeName = senderName
    local ownerChar = targetPlayer.Character
    local ownerHRP = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")
    lastOwnerPosition = ownerHRP and ownerHRP.Position or nil
end

function reloadTool()
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character then
        return
    end
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            tryReloadTool(tool)
        end
    end
end

function handleLoopKillCommand(targetName, specificBot)
    targetName = targetName:lower()
    if specificBot then
        specificBot = specificBot:lower()
    end

    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    for botKey, botUsername in pairs(Bots) do
        if localPlayer.Name:lower() == botUsername:lower() then
            if specificBot and not botKey:lower():find(specificBot, 1, true) then
                return
            end
            reloadTool()
            lockedTarget = nil
            stomponly = false
            bringonly = false
            takeonly = false
            getgenv().downonly = false
            opkill = false
            voiding = false
            summonTarget = nil
            flingonly = false

            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                local targetPlayerName = targetPlayer.Name:lower()
                local targetDisplayName = targetPlayer.DisplayName:lower()

                if targetPlayerName:find(targetName, 1, true) or targetDisplayName:find(targetName, 1, true) then
                    lockedTarget = targetPlayer
                    return
                end
            end
        end
    end
end

function handleStompCommand(targetName, specificBot)
    targetName = targetName:lower()
    if specificBot then
        specificBot = specificBot:lower()
    end

    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    for botKey, botUsername in pairs(Bots) do
        if localPlayer.Name:lower() == botUsername:lower() then
            if specificBot and not botKey:lower():find(specificBot, 1, true) then
                return
            end
            reloadTool()
            lockedTarget = nil
            stomponly = true
            bringonly = false
            takeonly = false
            getgenv().downonly = false
            opkill = false
            voiding = false
            summonTarget = nil
            flingonly = false

            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                local targetPlayerName = targetPlayer.Name:lower()
                local targetDisplayName = targetPlayer.DisplayName:lower()

                if targetPlayerName:find(targetName, 1, true) or targetDisplayName:find(targetName, 1, true) then
                    lockedTarget = targetPlayer
                    return
                end
            end
        end
    end
end

function handleOPKillCommand(targetName, specificBot)
    targetName = targetName:lower()
    if specificBot then
        specificBot = specificBot:lower()
    end

    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    for botKey, botUsername in pairs(Bots) do
        if localPlayer.Name:lower() == botUsername:lower() then
            if specificBot and not botKey:lower():find(specificBot, 1, true) then
                return
            end
            reloadTool()
            lockedTarget = nil
            stomponly = false
            bringonly = false
            takeonly = false
            getgenv().downonly = false
            opkill = true
            voiding = false
            summonTarget = nil
            flingonly = false

            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                local targetPlayerName = targetPlayer.Name:lower()
                local targetDisplayName = targetPlayer.DisplayName:lower()

                if targetPlayerName:find(targetName, 1, true) or targetDisplayName:find(targetName, 1, true) then
                    lockedTarget = targetPlayer
                    return
                end
            end
        end
    end
end

function handleFlingCommand(targetName)
    targetName = targetName:lower()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    for botKey, botUsername in pairs(Bots) do
        if localPlayer.Name:lower() == botUsername:lower() then
            reloadTool()
            lockedTarget = nil
            stomponly = false
            bringonly = false
            takeonly = false
            getgenv().downonly = false
            opkill = false
            voiding = false
            summonTarget = nil
            flingonly = true

            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                local tName = targetPlayer.Name:lower()
                local tDisplay = targetPlayer.DisplayName:lower()
                if tName:find(targetName, 1, true) or tDisplay:find(targetName, 1, true) then
                    lockedTarget = targetPlayer
                    return
                end
            end
        end
    end
end

function handleBringCommand(targetName, specificBot, senderName)
    commandSender = senderName
    targetName = targetName:lower()
    if specificBot then
        specificBot = specificBot:lower()
    end

    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    for botKey, botUsername in pairs(Bots) do
        if localPlayer.Name:lower() == botUsername:lower() then
            if specificBot and not botKey:lower():find(specificBot, 1, true) then
                return
            end
            reloadTool()
            lockedTarget = nil
            stomponly = false
            bringonly = true
            takeonly = false
            getgenv().downonly = false
            opkill = false
            voiding = false
            summonTarget = nil
            flingonly = false

            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                local targetPlayerName = targetPlayer.Name:lower()
                local targetDisplayName = targetPlayer.DisplayName:lower()

                if targetPlayerName:find(targetName, 1, true) or targetDisplayName:find(targetName, 1, true) then
                    lockedTarget = targetPlayer
                    return
                end
            end
        end
    end
end

local savedTarget5 = nil

function handleTakeCommand(targetName, destinationName)
    targetName = targetName:lower()
    if destinationName then
        destinationName = destinationName:lower()
    end

    local targetPlayer = nil
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.Name:lower() == targetName then
            targetPlayer = player
            break
        end
    end

    local destinationPlayer = nil
    if destinationName then
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player.Name:lower() == destinationName then
                destinationPlayer = player
                savedTarget5 = destinationPlayer
                break
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local playerName = player.Name:lower()
        local playerDisplayName = player.DisplayName:lower()

        if playerName:find(targetName, 1, true) or playerDisplayName:find(targetName, 1, true) then
            targetPlayer = player
        end

        if playerName:find(destinationName, 1, true) or playerDisplayName:find(destinationName, 1, true) then
            destinationPlayer = player
        end

        if targetPlayer and destinationPlayer then
            break
        end
    end

    if targetPlayer and destinationPlayer then
        savedTarget5 = destinationPlayer

        lockedTarget = targetPlayer
        reloadTool()
        stomponly = false
        bringonly = false
        getgenv().downonly = false
        opkill = false
        voiding = false
        takeonly = true
        summonTarget = nil
        flingonly = false
    end
end

local gotoPlayer = nil
local gotoCFrame = nil
local gotoTarget = nil
local vehicleMode = false
local vehicleSeatCFrame = CFrame.new(-866.932, 21.179, -587.317) * CFrame.Angles(math.rad(178.53), math.rad(-70.483), math.rad(178.615))
local vehiclePickupPos = Vector3.new(-897.034, 18.355, -611.24)
local vehicleSeatName = "VehicleSeat"
local passengerSeatName = "Seat"
local vehicleName = "KOALA12345A3BIKE"
local vehicleShopName = "[FoodsCart] - $17"
local vehiclePurchaseEnabled = true
local lastVehiclePurchase = 0
local lastVehicleSearch = 0
local vehicleModel = nil

function handleGotoCommand(playerName, locationName)
    local Players = game:GetService("Players")
    local player = Players:FindFirstChild(playerName)
    if not player then return end

    locationName = locationName:lower()

    local locationCFrames = {
        rifle = CFrame.new(-265, 52, -220),
        armor = CFrame.new(-933, -25, 570),
        lmg = CFrame.new(-618, 23, -299),
        mil = CFrame.new(36, 50, -830),
        military = CFrame.new(36, 50, -830),
        rev = CFrame.new(-639, 21, -125),
        revolver = CFrame.new(-639, 21, -125),
        food = CFrame.new(-327, 23, -291),
        food2 = CFrame.new(305, 49, -622),
        roof = CFrame.new(-326, 80, -293),
        bank = CFrame.new(-467, 39, -284),
        school = CFrame.new(-587, 68, 330),
        rpg = CFrame.new(113, -27, -268),
        uphill = CFrame.new(503, 48, -591),
        downhill = CFrame.new(-563, 8, -716),
        gs = CFrame.new(415.067, 76.778, 1.685),
    }

    gotoCFrame = locationCFrames[locationName]
    gotoTarget = nil
    
    -- If not a location, try to find a player
    if not gotoCFrame then
        local targetPlayer = findPlayerByPartial(locationName)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            gotoTarget = targetPlayer
        else
            return
        end
    end

    gotoPlayer = player
    vehicleMode = true
    vehicleModel = nil
    lockedTarget = nil
    reloadTool()
    stomponly = false
    bringonly = false
    getgenv().downonly = false
    opkill = false
    voiding = false
    takeonly = false
    summonTarget = nil
    flingonly = false
end

local skyTarget = nil

function handleSkyCommand(username)
    local Players = game:GetService("Players")
    local target = Players:FindFirstChild(username)
    if not target then return end

    skyTarget = target
    lockedTarget = target

    reloadTool()
    stomponly = false
    bringonly = false
    getgenv().downonly = false
    opkill = false
    voiding = false
    takeonly = true
    summonTarget = nil
    flingonly = false
end

function handleDownCommand(targetName, specificBot)
    targetName = targetName:lower()
    if specificBot then
        specificBot = specificBot:lower()
    end

    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    for botKey, botUsername in pairs(Bots) do
        if localPlayer.Name:lower() == botUsername:lower() then
            if specificBot and not botKey:lower():find(specificBot, 1, true) then
                return
            end
            reloadTool()
            lockedTarget = nil
            stomponly = false
            bringonly = false
            takeonly = false
            getgenv().downonly = true
            opkill = false
            voiding = false
            summonTarget = nil
            flingonly = false

            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                local targetPlayerName = targetPlayer.Name:lower()
                local targetDisplayName = targetPlayer.DisplayName:lower()

                if targetPlayerName:find(targetName, 1, true) or targetDisplayName:find(targetName, 1, true) then
                    lockedTarget = targetPlayer
                    return
                end
            end
        end
    end
end

function handleFixCommand(specificBot)
    if specificBot then
        specificBot = specificBot:lower()
    end

    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return end

    for botKey, botUsername in pairs(Bots) do
        if localPlayer.Name:lower() == botUsername:lower() then
            if specificBot and not botKey:lower():find(specificBot, 1, true) then
                return
            end

            getgenv().enabled = false
            getgenv().enabled1 = false
            ragebottargets = {}
            lockedTarget = nil
            autodrop = false
            stand2Active = false
            stand2TargetName = nil
            stand2TargetUserId = nil
            stand2CurrentTarget = nil
            buyingInProgress = false
            buyingGunInProgress = false
            buyingMaskInProgress = false
            voiding = true
            summonTarget = nil
            flingonly = false
            killall = false
            game.Players.LocalPlayer.Character.Humanoid.Health = 0
        end
    end
end

local player = game.Players.LocalPlayer
local character = player.Character
local AnimationId = "rbxassetid://507766388"

local animations = {
    {"run", "RunAnim"},
    {"walk", "WalkAnim"},
    {"jump", "JumpAnim"},
    {"fall", "FallAnim"},
    {"climb", "ClimbAnim"}
}

player.CharacterAdded:Connect(function(character)
    local animateScript = character:WaitForChild("Animate")

    for _, pair in pairs(animations) do
        local parentName, animName = pair[1], pair[2]
        local parent = animateScript:FindFirstChild(parentName)
        if parent then
            local anim = parent:FindFirstChild(animName)
            if anim then
                anim.AnimationId = AnimationId
            end
        end
    end
end)

local EMOTES = {
    ["billy bounce"] = "rbxassetid://136095999219650",
    ["zero two dance v2"] = "rbxassetid://116714406076290",
    ["jabba switchway"] = "rbxassetid://82682811348660",
    ["beat"] = "rbxassetid://133394554631338"
}

local player = game.Players.LocalPlayer
local character = player.Character
local currentTrack = nil
local emoteLoopTask = nil

function playAnimation(animId)
    if not character then return end
    local humanoid = character:WaitForChild("Humanoid", 10)
    local animator = humanoid:WaitForChild("Animator", 10)

    if currentTrack then
        currentTrack:Stop()
        currentTrack = nil
    end

    local animation = Instance.new("Animation")
    animation.AnimationId = animId
    local track = animator:LoadAnimation(animation)
    track.Looped = true
    track.Priority = Enum.AnimationPriority.Action4
    track:Play()
    currentTrack = track
end

function startEmoteLoop()
    if emoteLoopTask then
        task.cancel(emoteLoopTask)
        emoteLoopTask = nil
    end

    emoteLoopTask = task.spawn(function()
        while character and character.Parent do
            local emoteIds = {}
            for _, animId in pairs(EMOTES) do
                table.insert(emoteIds, animId)
            end
            local chosenEmote = emoteIds[math.random(1, #emoteIds)]
            playAnimation(chosenEmote)
            task.wait(30)
        end
    end)
end

if character then
    startEmoteLoop()
end

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    if currentTrack then
        currentTrack:Stop()
        currentTrack = nil
    end
    startEmoteLoop()
end)

function handleTeleportCommand(targetName, specificBot)
    getgenv().enabled = false
    ragebottargets = {}
    lockedTarget = nil
    voiding = true
    summonTarget = Players:FindFirstChild(targetName)
end

function handleHideCommand(specificBot)
    -- .v should ALWAYS stop everything immediately, regardless of which combat command is active.
    -- We keep the `specificBot` argument for compatibility, but we intentionally ignore it.

    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return end

    -- HARD STOP LATCH: prevents loops from re-acquiring targets / resuming.
    hardStop = true

    -- HARD STOP: cancel all modes and send stand to void.
    getgenv().enabled = false
    getgenv().enabled1 = false

    -- cancel any combat/loop targets
    ragebottargets = {}
    shouldSwitch = false
    currentTargetIndex = 1

    -- clear all targeting + relock state
    lockedTarget = nil
    lockedTargetUserId = nil
    autoLocked = false
    sentrytarget = nil
    skyTarget = nil

    -- disable ALL mode flags
    stomponly = false
    bringonly = false
    takeonly = false
    getgenv().downonly = false
    opkill = false
    flingonly = false
    killall = false
    vehicleMode = false

    -- IMPORTANT: clear stored destinations / carry logic that can keep moving the stand
    savedTarget5 = nil
    gotoPlayer = nil
    gotoCFrame = nil
    gotoTarget = nil
    vehicleModel = nil

    -- stop movement tasks
    teleporting = false
    summonTarget = nil

    -- turn off stand2 if it was enabled
    stand2Active = false
    stand2TargetName = nil
    stand2TargetUserId = nil
    stand2CurrentTarget = nil

    -- force void/idle
    voiding = true

    -- best-effort: drop anything currently grabbed, then reload
    pcall(function()
        ReplicatedStorage.MainEvent:FireServer("Grabbing", false)
    end)
    reloadTool()
end

task.spawn(function()
    while true do
        if getgenv().enabled and targetPlayer and player.Character and targetPlayer.Character and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) then
            local playerHRP = player.Character:FindFirstChild("HumanoidRootPart")
            local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if playerHRP and targetHRP then
                playerHRP.Velocity = Vector3.zero
                playerHRP.RotVelocity = Vector3.zero
                playerHRP.AssemblyLinearVelocity = Vector3.zero
                playerHRP.AssemblyAngularVelocity = Vector3.zero
                auraangle = auraangle + auraspeed * RunService.RenderStepped:Wait()
                local x = math.cos(auraangle) * auradistance
                local z = math.sin(auraangle) * auradistance
                local newPos = targetHRP.Position + Vector3.new(x, 0, z)
                hrp.CFrame = CFrame.new(newPos, newPos * 2 - targetHRP.Position)
            end
        end
        task.wait(standWait(perf.loop))
    end
end)

local Players = game:GetService("Players")
local localPlayer = game.Players.LocalPlayer
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChildOfClass("Humanoid")

localPlayer.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
end)

function teleportToTarget(commandSender)
    local targetPlayer = game.Players:FindFirstChild(commandSender)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
        local myHRP = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myHRP then
            lockedTarget = nil
            voiding = false
            summonTarget = nil
            myHRP.Velocity = Vector3.zero
            myHRP.RotVelocity = Vector3.zero
            myHRP.AssemblyLinearVelocity = Vector3.zero
            myHRP.AssemblyAngularVelocity = Vector3.zero
            myHRP.CFrame = CFrame.new(
                targetPosition.X + -5,
                targetPosition.Y,
                targetPosition.Z
            )
            myHRP.Velocity = Vector3.zero
            myHRP.RotVelocity = Vector3.zero
            myHRP.AssemblyLinearVelocity = Vector3.zero
            myHRP.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

function teleportToPosition(targetPosition)
    local player = game.Players.LocalPlayer
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(targetPosition)
    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local TeleportService = game:GetService("TeleportService")

LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    character:WaitForChild("Humanoid")
end)

function equipTool(toolName)
    local tool = game.Players.LocalPlayer.Backpack:FindFirstChild(toolName)
    if not tool then
        tool = game.Players.LocalPlayer:FindFirstChild(toolName)
    end
    local character = game.Players.LocalPlayer.Character
    if tool and character then
        tool.Parent = character
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and tool.Parent ~= character then
            humanoid:EquipTool(tool)
        end
    end
end

local whitelistedUsers = {}
local activeListeners = {}

local TextChatService = game:GetService("TextChatService")

function isAuthorized(player)
    return player.Name == Owner or whitelistedUsers[player.Name]
end

function isProtected(player)
    return false
end

function removeOldListeners()
    for userId in pairs(activeListeners) do
        activeListeners[userId] = nil
    end
end

benxActive = false
TweenService = game:GetService("TweenService")

function startBenx(targetPlayer)
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    lockedTarget = nil
    voiding = false
    benxActive = true

    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

    task.spawn(function()
        while benxActive do
            local char = LocalPlayer.Character
            local targetChar = targetPlayer.Character

            if char and char:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                local targetHRP = targetChar.HumanoidRootPart

                local frontPos = targetHRP.CFrame * CFrame.new(0, 0, -1)
                local backPos = targetHRP.CFrame * CFrame.new(0, 0, -4)

                local tween1 = TweenService:Create(hrp, tweenInfo, {CFrame = frontPos})
                tween1:Play()
                tween1.Completed:Wait()

                local tween2 = TweenService:Create(hrp, tweenInfo, {CFrame = backPos})
                tween2:Play()
                tween2.Completed:Wait()
            end
            if not benxActive then break end
        end
    end)
end

function updateDisplayName(player)
    return
end

function setupDisplayNameListener(player)
    if player.Character then
        updateDisplayName(player)
    end

    player.CharacterAdded:Connect(function()
        task.wait(0.1)
        updateDisplayName(player)
    end)
end

function setupChatListener(player)
    if not isAuthorized(player) then return end

    activeListeners[player.UserId] = function(msg)
        local sender = msg.TextSource and msg.TextSource.UserId and Players:GetPlayerByUserId(msg.TextSource.UserId)
        if not sender or sender ~= player then return end

        local message = msg.Text or ""
        local msgLower = message:lower()

        if (isAuthorized(player)) then
            if msgLower == ".a on" then
                hardStop = false
                lockedTarget = nil
                voiding = false
                getgenv().enabled = true
                startFollowingTarget(player.Name)
                if stand2Active and standHomeName ~= player.Name then
                    standHomeName = player.Name
                end
            elseif msgLower == ".a off" then
                getgenv().enabled = false
                -- send stand back to void
                voiding = true
                teleporting = false
                lockedTarget = nil
                summonTarget = nil
                if disableStand2 then
                    disableStand2()
                end
            elseif msgLower:match("^%.stand2") then
                local rawInput = message:match("^%.stand2%s*;?%s*([^;]+)") or message:match("^%.stand2%s+(.+)$")
                rawInput = trimInput(rawInput)
                if rawInput and handleStand2Command then
                    handleStand2Command(rawInput)
                else
                    sendMessage("stand2 needs a target name.")
                end
            elseif msgLower == ".stand off" then
                if disableStand2 then
                    disableStand2()
                end
            elseif msgLower == ".sentry on" then
                hardStop = false
                lockedTarget = nil
                voiding = false
                getgenv().enabled1 = true
            elseif msgLower == ".sentry off" then
                getgenv().enabled1 = false
            elseif msgLower == ".bsentry on" then      
                for plrName, _ in pairs(Bots) do
                    getgenv().sentryprotected[plrName] = true
                end
            elseif msgLower == ".bsentry off" then      
                for plrName, _ in pairs(Bots) do
                    getgenv().sentryprotected[plrName] = false
                end
            elseif msgLower == ".repair" then
                handleFixCommand()
            elseif msgLower:match("^%.repair%s+([^%s]+)$") then
                local botName = msgLower:match("^%.repair%s+([^%s]+)$")
                handleFixCommand(botName)
            elseif msgLower == ".v" then
                handleHideCommand()
            elseif msgLower:match("^%.v%s+([^%s]+)$") then
                local botName = msgLower:match("^%.v%s+([^%s]+)$")
                handleHideCommand(botName)
            elseif msgLower == ".summon" then
                handleTeleportCommand(player.Name)
            elseif msgLower:match("^%.summon%s+([^%s]+)$") then
                local botName = msgLower:match("^%.summon%s+([^%s]+)$")
                handleTeleportCommand(player.Name, botName)
            elseif msgLower:match("^%.to%s+(.+)$") or msgLower:match("^%.tp%s+(.+)$") then
                if player.Name ~= Owner then return end
                hardStop = false
                local destination = msgLower:match("^%.to%s+(.+)$") or msgLower:match("^%.tp%s+(.+)$")
                destination = trimInput(destination)
                if destination and destination ~= "" then
                    -- Use Food Cart transport system
                    handleGotoCommand(Owner, destination)
                end
            elseif msgLower == ".s" then
                teleportToTarget(player.Name)
            elseif msgLower == ".search" then
                lockedTarget = nil
                voiding = false
                teleportPlayerRandomly()
                task.wait(1)
                checkWhitelistNearPosition()
                task.wait(1)
                voiding = true
            elseif msgLower == ".cashdrop on" then
                autodrop = true
            elseif msgLower == ".cashdrop off" then
                autodrop = false
            elseif msgLower == ".abuse on" then
                AbuseProtection = true
            elseif msgLower == ".abuse off" then
                AbuseProtection = false
            elseif msgLower == ".mask on" then
                automaskenabled = true
            elseif msgLower == ".mask off" then
                automaskenabled = false
            elseif EMOTES[msgLower] then
                playAnimation(EMOTES[msgLower])
            elseif msgLower == ".stop" then
                if currentTrack then
                    currentTrack:Stop()
                    currentTrack = nil
                end
                lastEmote = nil
            elseif msgLower == ".fp on" then
                setfflag("NextGenReplicatorEnabledWrite4", "true")
                task.wait(0.1)
                replicatesignal(game.Players.LocalPlayer.Kill)
            elseif msgLower == ".fp off" then
                setfflag("NextGenReplicatorEnabledWrite4", "false")
                task.wait(0.1)
                replicatesignal(game.Players.LocalPlayer.Kill)
            elseif msgLower == "power!" or msgLower == ".power!" then
                -- Only allow POWER MODE toggling when stand follow is OFF
                if getgenv().enabled then
                    sendMessage("Turn .a off to use POWER MODE.")
                else
                    if activatePowerMode then
                        activatePowerMode()
                    end
                end
            elseif msgLower == ".autosave on" or msgLower == "autosave!" then
                autoSaveEnabled = true
                sendMessage("Autosave enabled - will save owner when knocked")
            elseif msgLower == ".autosave off" then
                autoSaveEnabled = false
                sendMessage("Autosave disabled")
            elseif msgLower == ".leave" then
                game:Shutdown()
            elseif msgLower == ".rejoin" then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            elseif msgLower:match("^%.say%s+(.+)$") then
                local messageToSay = msgLower:match("^%.say%s+(.+)$")
                sendMessage(messageToSay)
            elseif msgLower:match("^%.awl%s+([^%s]+)$") then
                local input = msgLower:match("^%.awl%s+([^%s]+)$")
                local target = findPlayerByPartial(input)
                if target then
                    getgenv().whitelist[target.Name] = true
                    sendMessage("Whitelisted " .. target.Name)
                else
                    sendMessage("Could not find " .. input .. " to whitelist")
                end
            elseif msgLower:match("^%.unawl%s+([^%s]+)$") then
                local input = msgLower:match("^%.unawl%s+([^%s]+)$")
                local target = findPlayerByPartial(input)
                if target then
                    getgenv().whitelist[target.Name] = nil
                    sendMessage("Unwhitelisted " .. target.Name)
                else
                    sendMessage("Could not find " .. input .. " to unwhitelist")
                end
            elseif msgLower:match("^%.assist%s+([^%s]+)$") then
                local input = msgLower:match("^%.assist%s+([^%s]+)$")
                for _, plr in pairs(game:GetService("Players"):GetPlayers()) do
                    local name = plr.Name:lower()
                    local display = plr.DisplayName:lower()
                    if name:find(input, 1, true) or display:find(input, 1, true) then
                        getgenv().sentryprotected[plr.Name] = true
                        break
                    end
                end
            elseif msgLower:match("^%.unassist%s+(.+)$") then
                local input = msgLower:match("^%.unassist%s+(.+)$")
                for _, plr in pairs(game:GetService("Players"):GetPlayers()) do
                    local name = plr.Name:lower()
                    local display = plr.DisplayName:lower()
                    if name:find(input, 1, true) or display:find(input, 1, true) then
                        getgenv().sentryprotected[plr.Name] = nil
                        break
                    end
                end
            elseif msgLower:match("^%.l%s+([^%s]+)$") then
                hardStop = false
                -- Loopkill: single target (.l username)
                local inputName = msgLower:match("^%.l%s+([^%s]+)$")
                local target = findPlayerByPartial(inputName)
                if not target then return end
                if isProtected(target) then
                    sendMessage("Cannot target user " .. target.Name .. " because they are premium.")
                    return
                end

                -- Reset state and set single target
                reloadTool()
                lockedTarget = target

                -- .l should LOOP KILL (stomp after knock)
                stomponly = true
                bringonly = false
                takeonly = false
                getgenv().downonly = false
                opkill = false
                voiding = false
                summonTarget = nil

                ragebottargets = {target}
                shouldSwitch = false

                teleporting = true
                voiding = false

            -- POWER-MODE SAFE DIRECT COMBAT COMMANDS (no bot checks)
            elseif msgLower:match("^%.d%s+([^%s]+)$") then
                hardStop = false
                local inputName = msgLower:match("^%.d%s+([^%s]+)$")
                local target = findPlayerByPartial(inputName)
                if not target then return end
                if isProtected(target) then
                    sendMessage("Cannot target user " .. target.Name .. " because they are premium.")
                    return
                end
                reloadTool()
                lockedTarget = target
                teleporting = true
                voiding = false
                summonTarget = nil
                ragebottargets = {}
                shouldSwitch = false
                stomponly = false
                bringonly = false
                takeonly = false
                opkill = false
                flingonly = false
                killall = false
                getgenv().downonly = true

            elseif msgLower:match("^%.b%s+([^%s]+)$") then
                hardStop = false
                local inputName = msgLower:match("^%.b%s+([^%s]+)$")
                local target = findPlayerByPartial(inputName)
                if not target then return end
                if isProtected(target) then
                    sendMessage("Cannot target user " .. target.Name .. " because they are premium.")
                    return
                end
                commandSender = player.Name
                reloadTool()
                lockedTarget = target
                teleporting = true
                voiding = false
                summonTarget = nil
                ragebottargets = {}
                shouldSwitch = false
                stomponly = false
                bringonly = true
                takeonly = false
                opkill = false
                flingonly = false
                killall = false
                getgenv().downonly = false

            elseif msgLower:match("^%.s%s+([^%s]+)$") then
                hardStop = false
                local inputName = msgLower:match("^%.s%s+([^%s]+)$")
                local target = findPlayerByPartial(inputName)
                if not target then return end
                if isProtected(target) then
                    sendMessage("Cannot target user " .. target.Name .. " because they are premium.")
                    return
                end
                reloadTool()
                lockedTarget = target
                teleporting = true
                voiding = false
                summonTarget = nil
                ragebottargets = {}
                shouldSwitch = false
                stomponly = true
                bringonly = false
                takeonly = false
                opkill = false
                flingonly = false
                killall = false
                getgenv().downonly = false

            elseif msgLower:match("^%.sky%s+([^%s]+)$") then
                hardStop = false
                local inputName = msgLower:match("^%.sky%s+([^%s]+)$")
                local target = findPlayerByPartial(inputName)
                if not target then return end
                if isProtected(target) then
                    sendMessage("Cannot target user " .. target.Name .. " because they are premium.")
                    return
                end
                skyTarget = target
                reloadTool()
                lockedTarget = target
                teleporting = true
                voiding = false
                summonTarget = nil
                ragebottargets = {}
                shouldSwitch = false
                stomponly = false
                bringonly = false
                takeonly = true
                opkill = false
                flingonly = false
                killall = false
                getgenv().downonly = false
            elseif msgLower:match("^%.lk%s+([^%s]+)$") then
                hardStop = false
                -- Loopknock: single-argument form (.lk username)
                local inputName = msgLower:match("^%.lk%s+([^%s]+)$")
                local target = findPlayerByPartial(inputName)
                if not target then return end
                if isProtected(target) then
                    sendMessage("Cannot target user " .. target.Name .. " because they are premium.")
                    return
                end

                reloadTool()
                lockedTarget = target
                teleporting = true
                voiding = false
                summonTarget = nil

                -- modes
                stomponly = false
                bringonly = false
                takeonly = false
                getgenv().downonly = true
                opkill = false
                flingonly = false
                killall = false

                ragebottargets = {target}
                shouldSwitch = false

            elseif msgLower:match("^%.lk%s+([^%s]+)%s+([^%s]+)$") then
                hardStop = false
                -- Loopknock: legacy two-argument form (.lk username botName)
                local inputName = msgLower:match("^%.lk%s+([^%s]+)%s+([^%s]+)$")
                local target = findPlayerByPartial(inputName)
                if not target then return end
                if isProtected(target) then
                    sendMessage("Cannot target user " .. target.Name .. " because they are premium.")
                    return
                end

                reloadTool()
                lockedTarget = target
                teleporting = true
                voiding = false
                summonTarget = nil

                -- modes
                stomponly = false
                bringonly = false
                takeonly = false
                getgenv().downonly = true
                opkill = false
                flingonly = false
                killall = false

                ragebottargets = {target}
                shouldSwitch = false
            elseif msgLower:match("^%.right%s+([^%s]+)$") then
                local targetName = msgLower:match("^%.right%s+([^%s]+)$")
                
                local myName = LocalPlayer.Name:lower()
                local myDisplay = LocalPlayer.DisplayName:lower()

                if myName:find(targetName, 1, true) or myDisplay:find(targetName, 1, true) then
                    summonMode = "right"
                end

            elseif msgLower:match("^%.left%s+([^%s]+)$") then
                local targetName = msgLower:match("^%.left%s+([^%s]+)$")
                
                local myName = LocalPlayer.Name:lower()
                local myDisplay = LocalPlayer.DisplayName:lower()

                if myName:find(targetName, 1, true) or myDisplay:find(targetName, 1, true) then
                    summonMode = "left"
                end

            elseif msgLower:match("^%.middle%s+([^%s]+)$") then
                local targetName = msgLower:match("^%.middle%s+([^%s]+)$")
                
                local myName = LocalPlayer.Name:lower()
                local myDisplay = LocalPlayer.DisplayName:lower()

                if myName:find(targetName, 1, true) or myDisplay:find(targetName, 1, true) then
                    summonMode = "middle"
                end
            elseif msgLower:match("^%.fling%s+([^%s]+)$") then
                hardStop = false
                local inputName = msgLower:match("^%.fling%s+([^%s]+)$")
                local target = findPlayerByPartial(inputName)
                if not target then return end
                if isProtected(target) then
                    sendMessage("Cannot target user " .. target.Name .. " because they are premium.")
                    return
                end
                reloadTool()
                lockedTarget = target
                teleporting = true
                voiding = false
                summonTarget = nil
                stomponly = false
                bringonly = false
                takeonly = false
                getgenv().downonly = false
                opkill = false
                flingonly = true
                killall = false
            elseif msgLower:match("^%.akill%s+on$") then
                hardStop = false
                -- Kill all: enable killall loop and ensure we are not in another mode
                killall = true
                summonTarget = nil
                teleporting = true
                voiding = false
                stomponly = false
                bringonly = false
                takeonly = false
                getgenv().downonly = false
                opkill = false
                flingonly = false
            elseif msgLower:match("^%.akill%s+off$") then
                killall = false
                lockedTarget = nil
                teleporting = false
                voiding = true
            -- Removed duplicate legacy combat handlers below.
            -- The primary handlers earlier in this chain are the ones used.
            elseif msgLower:match("^%.wl%s+(.+)$") then
                if player.Name ~= Owner then return end
                local input = msgLower:match("^%.wl%s+(.+)$")
                for _, plr in pairs(game:GetService("Players"):GetPlayers()) do
                    local name = plr.Name:lower()
                    local display = plr.DisplayName:lower()
                    if name:find(input, 1, true) or display:find(input, 1, true) then
                        local newTarget = plr.Name
                        whitelistedUsers[newTarget] = true
                        local newPlayer = game.Players:FindFirstChild(newTarget)
                        if newPlayer then
                            setupChatListener(newPlayer)
                        end
                        break
                    end
                end
            elseif msgLower:match("^%.unwl%s+(.+)$") then
                if player.Name ~= Owner then return end
                local input = msgLower:match("^%.unwl%s+(.+)$")
                for _, plr in pairs(game:GetService("Players"):GetPlayers()) do
                    local name = plr.Name:lower()
                    local display = plr.DisplayName:lower()
                    if name:find(input, 1, true) or display:find(input, 1, true) then
                        whitelistedUsers[plr.Name] = nil
                        activeListeners[plr.UserId] = nil
                        break
                    end
                end
            end
        end
    end
end

TextChatService.OnIncomingMessage = function(msg)
    -- Global emergency stop: allow Owner to always force .v, even if listener state is broken.
    -- IMPORTANT: compare against UserId as well, because DisplayName/Name mismatches can happen.
    pcall(function()
        local sender = msg.TextSource and msg.TextSource.UserId and Players:GetPlayerByUserId(msg.TextSource.UserId)
        local text = tostring(msg.Text or "")
        local lower = text:lower()
        local isV = (lower == ".v") or lower:match("^%.v%s+")

        if isV then
            local ownerPlr = Players:FindFirstChild(Owner)
            local ownerId = ownerPlr and ownerPlr.UserId
            if (sender and sender.Name == Owner) or (ownerId and msg.TextSource and msg.TextSource.UserId == ownerId) then
                handleHideCommand()
            end
        end
    end)

    for _, handler in pairs(activeListeners) do
        handler(msg)
    end
end

for _, player in pairs(Players:GetPlayers()) do
    if isAuthorized(player) then
        whitelistedUsers[player.Name] = true
        setupChatListener(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if isAuthorized(player) then
        setupChatListener(player)
    end
end)

local Players = game:GetService("Players")
local LocalPlayer = game:GetService("Players").LocalPlayer
local lockedTargetUserId = nil
local autoLocked = false
local sentrytarget = nil

local function resetStandHome()
    if getgenv().enabled and standHomeName then
        startFollowingTarget(standHomeName)
    end
    teleporting = false
    voiding = false
end

handleStand2Command = function(rawInput)
    local target = findPlayerByPartial(rawInput)
    if not standHomeName then
        standHomeName = Owner
    end

    stand2Active = true
    stand2TargetName = rawInput
    stand2CurrentTarget = target
    stand2TargetUserId = target and target.UserId or nil
    lockedTarget = nil
    lockedTargetUserId = nil
    stomponly = false
    bringonly = false
    takeonly = false
    getgenv().downonly = false
    opkill = false
    flingonly = false
    killall = false
    summonTarget = nil
    shouldSwitch = false
    voiding = false
    teleporting = false
    getgenv().enabled = true
    startFollowingTarget(standHomeName)
    reloadTool()

    if target then
        lockedTarget = target
        lockedTargetUserId = target.UserId
        autoLocked = false
        voiding = false
        teleporting = true
        sendMessage("stand2 locked on " .. target.Name)
    else
        sendMessage("stand2 armed for " .. rawInput .. " (waiting)")
        resetStandHome()
    end
end

disableStand2 = function()
    if not stand2Active then
        return
    end
    local previousTarget = stand2CurrentTarget
    local previousId = stand2TargetUserId

    stand2Active = false
    stand2TargetName = nil
    stand2TargetUserId = nil
    stand2CurrentTarget = nil

    if lockedTarget and (lockedTarget == previousTarget or (previousId and lockedTarget.UserId == previousId)) then
        lockedTarget = nil
        lockedTargetUserId = nil
    end

    autoLocked = false
    resetStandHome()
    sendMessage("stand2 off")
end

task.spawn(function()
    while true do
        if hardStop then
            task.wait(standWait(perf.target))
            continue
        end
        -- If we are in a loop mode (.l / .lk) and current target is invalid/dead, keep re-acquiring
        if #ragebottargets > 0 then
            if not lockedTarget or not isValidLoopTarget(lockedTarget) then
                shouldSwitch = true
            end
        end

        if shouldSwitch and #ragebottargets > 0 then
            local attempts = 0
            local found = nil
            while attempts < #ragebottargets do
                currentTargetIndex = (currentTargetIndex % #ragebottargets) + 1
                local candidate = ragebottargets[currentTargetIndex]
                if isValidLoopTarget(candidate) then
                    found = candidate
                    break
                end
                attempts += 1
            end

            -- For .lk (single target), keep trying to re-find the same user by UserId/name if they respawn.
            if not found and #ragebottargets == 1 then
                local only = ragebottargets[1]
                local uid = only and only.UserId
                if uid then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.UserId == uid and isValidLoopTarget(p) then
                            ragebottargets[1] = p
                            found = p
                            break
                        end
                    end
                end
            end

            if found then
                lockedTarget = found
                lockedTargetUserId = found.UserId
                autoLocked = false
                teleporting = true
                voiding = false
            else
                -- Nobody valid right now; keep trying in future ticks
                lockedTarget = nil
                teleporting = false
                voiding = true
            end
            shouldSwitch = false
        end

        -- Existing auto-relock by UserId
        if not lockedTarget and lockedTargetUserId and not autoLocked then
            for _, player in ipairs(Players:GetPlayers()) do
                if player.UserId == lockedTargetUserId then
                    lockedTarget = player
                    autoLocked = true
                    break
                end
            end
        end

        if lockedTarget then
            local targetCharacter = lockedTarget.Character
            if targetCharacter then
                local bodyEffects = targetCharacter:FindFirstChild("BodyEffects")
                local isKO = bodyEffects and bodyEffects:FindFirstChild("K.O") and bodyEffects["K.O"].Value
                if isKO and trashtalkactive then
                    hasSentKOMessage = true
                else
                    hasSentKOMessage = false
                end
            end
            if not lockedTarget:IsDescendantOf(game) then
                lockedTargetUserId = lockedTarget.UserId
                lockedTarget = nil
                autoLocked = false
                if stand2Active then
                    resetStandHome()
                else
                    -- If we are looping, keep trying to reacquire; otherwise go idle
                    if #ragebottargets > 0 then
                        shouldSwitch = true
                    else
                        voiding = true
                    end
                end
            end
        end
        task.wait(standWait(perf.target))
    end
end)

task.spawn(function()
    while true do
        if stand2Active then
            local target = stand2CurrentTarget

            if not target or not target:IsDescendantOf(game) then
                local found = nil
                if stand2TargetUserId then
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.UserId == stand2TargetUserId then
                            found = plr
                            break
                        end
                    end
                end
                if not found and stand2TargetName then
                    found = findPlayerByPartial(stand2TargetName)
                end

                if found then
                    stand2CurrentTarget = found
                    lockedTarget = found
                    lockedTargetUserId = found.UserId
                    autoLocked = false
                    voiding = false
                    teleporting = true
                else
                    stand2CurrentTarget = nil
                    lockedTarget = nil
                    lockedTargetUserId = stand2TargetUserId
                    resetStandHome()
                end
            else
                if lockedTarget ~= target then
                    lockedTarget = target
                    lockedTargetUserId = target.UserId
                    autoLocked = false
                end
                local tChar = target.Character
                local tBody = tChar and tChar:FindFirstChild("BodyEffects")
                local tHumanoid = tChar and tChar:FindFirstChildOfClass("Humanoid")
                local sDeath = tBody and tBody:FindFirstChild("SDeath") and tBody["SDeath"].Value
                local dead = tHumanoid and tHumanoid.Health <= 0
                if sDeath or dead then
                    stand2CurrentTarget = nil
                    lockedTarget = nil
                    teleporting = false
                    resetStandHome()
                end
            end
        end
        task.wait(standWait(perf.target))
    end
end)

task.spawn(function()
    while true do
        if teleporting and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) then
            local targetCharacter

            if lockedTarget and lockedTarget.Character then
                targetCharacter = lockedTarget.Character
            elseif sentrytarget and sentrytarget.Character then
                targetCharacter = sentrytarget.Character
            end

            if targetCharacter and LocalPlayer.Character then
                local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart")
                local playerHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetHRP and playerHRP then
                    playerHRP.CFrame = CFrame.lookAt(
                        targetHRP.Position + Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20)),
                        targetHRP.Position
                    )
                end
            end
        end
        task.wait(standWait(perf.teleport))
    end
end)

canrun = true
Players = game:GetService("Players")
LocalPlayer = Players.LocalPlayer
char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
humanoid = char:WaitForChild("Humanoid")
rootPart = char:WaitForChild("HumanoidRootPart")

task.spawn(function()
    while true do
        -- Main combat loop: should run for ALL offensive modes (.d/.lk use downonly, etc.)
        if lockedTarget and not bringonly and not takeonly and not opkill and not flingonly and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) then
            local character = lockedTarget.Character
            local myCharacter = LocalPlayer.Character
            if character and myCharacter then
                local bodyEffects = character:FindFirstChild("BodyEffects")
                local myBodyEffects = myCharacter:FindFirstChild("BodyEffects")
                local isKO = bodyEffects and bodyEffects:FindFirstChild("K.O") and bodyEffects["K.O"].Value
                local isSDeath = bodyEffects and bodyEffects:FindFirstChild("SDeath") and bodyEffects["SDeath"].Value
                local isNil = not character:FindFirstChild("UpperTorso") or not character:FindFirstChild("Head")
                local isGrabbed = character:FindFirstChild("GRABBING_CONSTRAINT")
                local hasForceField = character:FindFirstChildOfClass("ForceField")
                local isReloading = myBodyEffects and myBodyEffects:FindFirstChild("Reload") and myBodyEffects["Reload"].Value
                local myHasForceField = myCharacter:FindFirstChildOfClass("ForceField")
                if AbuseProtection and not myHasForceField and not isReloading and not refreshingfakeposition then
                    local humanoid = myCharacter:FindFirstChild("Humanoid")
                    if humanoid then
                        canrun = false
                        voiding = true
                        teleporting = false
                        task.wait(0.1)
                        humanoid.Health = 0
                        task.wait(0.1)
                        canrun = true
                    end
                end
                if (isSDeath or isNil) and not isReloading and canrun then
                    teleporting = false
                    voiding = true
                    reloadTool()
                    shouldSwitch = true
                    if not didRefreshOnDeath and fpactive then
                        didRefreshOnDeath = true
                        task.delay(0.2, function()
                            refreshingfakeposition = true
                            task.wait(3.65)
                            refreshingfakeposition = false
                        end)
                    end
                elseif isKO and not isSDeath and not isGrabbed and not isNil and not isReloading and canrun and not refreshingfakeposition then
                    voiding = false
                    teleporting = false
                    local upperTorso = character:FindFirstChild("UpperTorso")
                    if upperTorso and LocalPlayer.Character then
                        local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if humanoidRootPart then
                            humanoidRootPart.Velocity = Vector3.zero
                            humanoidRootPart.RotVelocity = Vector3.zero
                            humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                            humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
                            humanoidRootPart.CFrame = CFrame.new(upperTorso.Position + Vector3.new(0, 3.5, 0))
                            task.wait(0.1)
                        end
                    end
                elseif not isKO and not isSDeath and not hasForceField and not isGrabbed and not isNil and not isReloading and canrun and not refreshingfakeposition then
                    teleporting = true
                    voiding = false
                    didRefreshOnDeath = false
                elseif isReloading and not refreshingfakeposition then
                    teleporting = false
                    voiding = true
                elseif hasForceField and not isReloading and not refreshingfakeposition then
                    teleporting = false
                    voiding = true
                    reloadTool()
                end
            end
            -- Only stomp when explicitly in stomp mode.
            -- .lk (loopknock) should knock only, not stomp.
            if stomponly then
                ReplicatedStorage.MainEvent:FireServer("Stomp")
            end
        end
        task.wait(standWait(perf.combat))
    end
end)

task.spawn(function()
    while true do
        if stomponly and not bringonly and not takeonly and not getgenv().downonly and not opkill and lockedTarget and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) then
            local character = lockedTarget.Character
            if character then
                local bodyEffects = character:FindFirstChild("BodyEffects")
                local isKO = bodyEffects and bodyEffects:FindFirstChild("K.O") and bodyEffects["K.O"].Value
                local isSDeath = bodyEffects and bodyEffects:FindFirstChild("SDeath") and bodyEffects["SDeath"].Value

                if isKO and not isSDeath then
                    teleporting = false
                    voiding = false
                    local upperTorso = character:FindFirstChild("UpperTorso")
                    if upperTorso and LocalPlayer.Character then
                        local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if humanoidRootPart then
                            humanoidRootPart.Velocity = Vector3.zero
                            humanoidRootPart.RotVelocity = Vector3.zero
                            humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                            humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
                            humanoidRootPart.CFrame = CFrame.new(upperTorso.Position + Vector3.new(0, 3.5, 0))
                            task.wait(0.1)
                        end
                    end
                elseif isSDeath then
                    lockedTarget = nil
                    teleporting = false
                    voiding = true
                    reloadTool()
                elseif not isKO and not isSDeath then
                    teleporting = true
                    voiding = false
                end
            end
            -- Only stomp when explicitly in stomp mode.
            -- .lk (loopknock) should knock only, not stomp.
            if stomponly then
                ReplicatedStorage.MainEvent:FireServer("Stomp")
            end
        end
        task.wait(standWait(perf.combat))
    end
end)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local bringconnection = nil

task.spawn(function()
    while true do
        if hardStop then
            task.wait(standWait(perf.combat))
            continue
        end
        if bringonly and lockedTarget and lockedTarget.Character and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) then
            local character = lockedTarget.Character

            local bodyEffects = character and character:FindFirstChild("BodyEffects")

            local isKO = bodyEffects and bodyEffects:FindFirstChild("K.O") and bodyEffects["K.O"].Value
            local isSDeath = bodyEffects and bodyEffects:FindFirstChild("SDeath") and bodyEffects["SDeath"].Value

            local grabbed = false

            local character = lockedTarget.Character
            local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local upperTorso = character and character:FindFirstChild("UpperTorso")

            if bringconnection then
                bringconnection:Disconnect()
                bringconnection = nil
            end

            bringconnection = character.ChildAdded:Connect(function(child)
                if child.Name == "GRABBING_CONSTRAINT" then
                    grabbed = true
                    lockedTarget = nil
                    if bringconnection then bringconnection:Disconnect() bringconnection = nil end
                end
            end)

            if character:FindFirstChild("GRABBING_CONSTRAINT") then
                grabbed = true
                lockedTarget = nil
                if bringconnection then bringconnection:Disconnect() bringconnection = nil end
            end

            if not grabbed and isKO and humanoidRootPart and upperTorso then
                teleporting = false
                voiding = false

                humanoidRootPart.Velocity = Vector3.zero
                humanoidRootPart.RotVelocity = Vector3.zero
                humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
                humanoidRootPart.CFrame = CFrame.new(upperTorso.Position + Vector3.new(0, 3.5, 0))
                ReplicatedStorage.MainEvent:FireServer("Grabbing", false)
                task.wait(0.3)
            else
                teleporting = true
                voiding = false
            end

            if grabbed then
                lockedTarget = nil
                -- Navigate to destination if set
                if gotoCFrame then
                    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if myHRP then
                        myHRP.CFrame = gotoCFrame
                        task.wait(0.3)
                    end
                elseif gotoTarget and gotoTarget.Character then
                    local targetHRP = gotoTarget.Character:FindFirstChild("HumanoidRootPart")
                    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if targetHRP and myHRP then
                        myHRP.CFrame = CFrame.new(targetHRP.Position + Vector3.new(0, 3, 0))
                        task.wait(0.3)
                    end
                else
                    teleportToTarget(commandSender)
                    task.wait(0.3)
                end
                ReplicatedStorage.MainEvent:FireServer("Grabbing", false)
                task.wait(0.3)
                voiding = true
                reloadTool()
                -- Clear destination after delivery
                gotoCFrame = nil
                gotoTarget = nil
            end
        end
        task.wait(standWait(perf.combat))
    end
end)

local takeconnection = nil

task.spawn(function()
    while true do
        if hardStop then
            task.wait(standWait(perf.combat))
            continue
        end
        if takeonly and lockedTarget and lockedTarget.Character and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) then
            local character = lockedTarget.Character

            local bodyEffects = character and character:FindFirstChild("BodyEffects")

            local isKO = bodyEffects and bodyEffects:FindFirstChild("K.O") and bodyEffects["K.O"].Value
            local isSDeath = bodyEffects and bodyEffects:FindFirstChild("SDeath") and bodyEffects["SDeath"].Value

            local grabbed = false

            local character = lockedTarget.Character
            local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local upperTorso = character and character:FindFirstChild("UpperTorso")

            if takeconnection then
                takeconnection:Disconnect()
                takeconnection = nil
            end

            takeconnection = character.ChildAdded:Connect(function(child)
                if child.Name == "GRABBING_CONSTRAINT" then
                    grabbed = true
                    lockedTarget = nil
                    if takeconnection then takeconnection:Disconnect() takeconnection = nil end
                end
            end)

            if character:FindFirstChild("GRABBING_CONSTRAINT") then
                grabbed = true
                lockedTarget = nil
                if takeconnection then takeconnection:Disconnect() takeconnection = nil end
            end

            if not grabbed and isKO and humanoidRootPart and upperTorso then
                teleporting = false
                voiding = false

                humanoidRootPart.Velocity = Vector3.zero
                humanoidRootPart.RotVelocity = Vector3.zero
                humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
                humanoidRootPart.CFrame = CFrame.new(upperTorso.Position + Vector3.new(0, 3.5, 0))
                ReplicatedStorage.MainEvent:FireServer("Grabbing", false)
                task.wait(0.3)
            else
                teleporting = true
                voiding = false
            end

            if grabbed then
                local localChar = LocalPlayer.Character
                local hrp = localChar and localChar:FindFirstChild("HumanoidRootPart")

                if skyTarget and hrp then
                    lockedTarget = nil
                    hrp.CFrame = CFrame.new(0, -999999999, 0)
                    task.wait(0.3)
                    ReplicatedStorage.MainEvent:FireServer("Grabbing", false)
                    task.wait(0.3)
                    voiding = true
                    reloadTool()
                    skyTarget = nil
                end

                if gotoCFrame and gotoPlayer and hrp then
                    lockedTarget = nil
                    hrp.CFrame = gotoCFrame
                    task.wait(0.3)
                    ReplicatedStorage.MainEvent:FireServer("Grabbing", false)
                    task.wait(0.3)
                    voiding = true
                    reloadTool()
                    gotoPlayer = nil
                    gotoCFrame = nil
                    gotoTarget = nil
                    vehicleModel = nil
                end

                if savedTarget5 then
                    local dstChar = savedTarget5.Character
                    if dstChar and dstChar:FindFirstChild("HumanoidRootPart") and hrp then
                        lockedTarget = nil
                        local dstPos = dstChar.HumanoidRootPart.Position
                        teleportToPosition(dstPos)
                        task.wait(0.3)
                        ReplicatedStorage.MainEvent:FireServer("Grabbing", false)
                        task.wait(0.3)
                        voiding = true
                        reloadTool()
                    end
                    savedTarget5 = nil
                end
            end
        end
        task.wait(standWait(perf.combat))
    end
end)

task.spawn(function()
    while true do
        if getgenv().downonly and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) and not stomponly and not bringonly and not takeonly and not opkill and lockedTarget then
            local character = lockedTarget.Character
            if character then
                local bodyEffects = character:FindFirstChild("BodyEffects")
                local isKO = bodyEffects and bodyEffects:FindFirstChild("K.O") and bodyEffects["K.O"].Value
                local isSDeath = bodyEffects and bodyEffects:FindFirstChild("SDeath") and bodyEffects["SDeath"].Value

                if not isKO and not isSDeath then
                    teleporting = true
                    voiding = false
                elseif isKO or isSDeath then
                    -- For loopknock (.lk) we want to keep re-targeting the same player after they respawn.
                    -- Clearing lockedTarget here stops the loop after the first KO.
                    if #ragebottargets > 0 then
                        shouldSwitch = true
                    end
                    teleporting = false
                    voiding = true
                    reloadTool()
                end
            end
        end
        task.wait(standWait(perf.combat))
    end
end)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

task.spawn(function()
    while true do
        if opkill and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) and not stomponly and not bringonly and not takeonly and not getgenv().downonly and lockedTarget then
            local character = lockedTarget.Character
            if character then
                local bodyEffects = character:FindFirstChild("BodyEffects")
                local isKO = bodyEffects and bodyEffects:FindFirstChild("K.O") and bodyEffects["K.O"].Value
                local isSDeath = bodyEffects and bodyEffects:FindFirstChild("SDeath") and bodyEffects["SDeath"].Value
                local isGrabbed = character:FindFirstChild("GRABBING_CONSTRAINT")
                local hasForceField = character:FindFirstChildOfClass("ForceField")

                if not isKO and not isSDeath and not isGrabbed and not hasForceField then
                    teleporting = true
                    voiding = false
                elseif isKO or isSDeath or isGrabbed or hasForceField then
                    voiding = true
                    teleporting = false
                end
            end
        end
        task.wait(standWait(perf.combat))
    end
end)

task.spawn(function()
    while true do
        if flingonly and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) and not stomponly and not bringonly and not takeonly and not getgenv().downonly and lockedTarget then
            local char = Player.Character
            local targetHRP = lockedTarget.Character and lockedTarget.Character:FindFirstChild("HumanoidRootPart")

            if char and char:FindFirstChild("HumanoidRootPart") and targetHRP then
                teleporting = true
                voiding = false

                char.HumanoidRootPart.CFrame = CFrame.new(
                    targetHRP.Position + Vector3.new(0, 0, math.random(-30, 30))
                )
            end
        end
        task.wait(standWait(perf.combat))
    end
end)

task.spawn(function()
    while true do
        if hardStop then
            task.wait(standWait(perf.killall))
            continue
        end
        if killall and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) then

            local switchTarget = false
            if lockedTarget and lockedTarget.Character then
                local character = lockedTarget.Character
                local bodyEffects = character:FindFirstChild("BodyEffects")
                local isSDeath = bodyEffects and bodyEffects:FindFirstChild("SDeath") and bodyEffects["SDeath"].Value
                if isSDeath then
                    switchTarget = true
                end
            else
                switchTarget = true
            end

            if switchTarget then
                local candidates = {}
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Name ~= Owner
                       and player ~= Players.LocalPlayer
                       and player.Character 
                       and player.Character:FindFirstChild("BodyEffects") 
                       and player.Character.BodyEffects:FindFirstChild("SDeath") 
                       and not player.Character.BodyEffects["SDeath"].Value
                       and not player.Character:FindFirstChild("GRABBING_CONSTRAINT") then
                        table.insert(candidates, player)
                    end
                end

                if #candidates > 0 then
                    lockedTarget = candidates[math.random(1, #candidates)]
                end
            end
        end
        task.wait(standWait(perf.killall))
    end
end)

RunService.Heartbeat:Connect(function()
    if hardStop then
        return
    end
    local targetCharacter
    local target

    if lockedTarget and lockedTarget.Character then
        targetCharacter = lockedTarget.Character
        target = lockedTarget
    elseif sentrytarget and sentrytarget.Character then
        targetCharacter = sentrytarget.Character
        target = sentrytarget
    end

    if not targetCharacter or not targetCharacter:FindFirstChild("HumanoidRootPart") then return end
    if target == LocalPlayer then
        lockedTarget = nil
        voiding = true
        return
    end

    local targetPart = targetCharacter:FindFirstChild("Head")
    local isGrabbed = targetCharacter:FindFirstChild("GRABBING_CONSTRAINT")
    local hrp = targetCharacter:FindFirstChild("HumanoidRootPart")

    -- IMPORTANT: do NOT shoot KO targets for loop modes (.lk/.l) to save ammo.
    -- But still allow shooting KO targets for one-shot stomp mode (.s) if needed.
    if not hrp or not targetPart or not targetPart.Parent then return end
    if isGrabbed then return end
    if (flingonly and target) then return end

    local bodyEffects = targetCharacter:FindFirstChild("BodyEffects")
    local koValue = bodyEffects and bodyEffects:FindFirstChild("K.O")
    local isKO = koValue and koValue.Value

    -- Save ammo: don't shoot while target is knocked in loopkill/loopknock.
    -- (We still teleport above them; stomping is handled elsewhere when stomponly=true)
    if isKO and (#ragebottargets > 0) then
        return
    end

    local playerChar = game.Players.LocalPlayer.Character
    if not playerChar then return end

    if shootInterval > 0 then
        local now = os.clock()
        if (now - lastShootAt) < shootInterval then
            return
        end
        lastShootAt = now
    end

    for _, tool in ipairs(playerChar:GetChildren()) do
        local handle = getShootHandle(tool)
        if handle then
            if tryReloadTool(tool) then
                continue
            end
            for _ = 1, shotsPerTick do
                ReplicatedStorage.MainEvent:FireServer(
                    "ShootGun",
                    handle,
                    handle.Position,
                    targetPart.Position,
                    targetPart,
                    Vector3.new(0, 0, 0)
                )
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not getgenv().enabled then
        return
    end

    local lp = game.Players.LocalPlayer
    local char = lp and lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end

    local koValue = char:FindFirstChild("BodyEffects") and char.BodyEffects:FindFirstChild("K.O")
    if not koValue or not koValue.Value then
        if followFireInProgress then
            return
        end
        local now = os.clock()
        if (now - lastFollowShotAt) < followShotCooldown then
            return
        end
        local centerPos = nil

        if targetPlayer and targetPlayer.Character then
            local ownerHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if ownerHRP then
                centerPos = ownerHRP.Position
                lastOwnerPosition = centerPos
            end
        end
        if not centerPos then
            centerPos = lastOwnerPosition or hrp.Position
        end
        if not centerPos then
            return
        end

        local targets = collectGridTargets(centerPos)
        if #targets == 0 then
            return
        end

        local toolsToFire = {}
        local seen = {}
        for _, gunKey in ipairs(Guns) do
            local tool = getGunToolByKey(gunKey)
            if tool and not seen[tool] then
                seen[tool] = true
                table.insert(toolsToFire, tool)
            end
        end
        if #toolsToFire == 0 then
            toolsToFire = collectGunTools()
        end
        if #toolsToFire == 0 then
            return
        end

        followFireInProgress = true
        lastFollowShotAt = now
        task.spawn(function()
            local ok, err = pcall(function()
                for _, targetPlayer in ipairs(targets) do
                    local targetChar = targetPlayer.Character
                    local targetPart = targetChar and targetChar:FindFirstChild("Head")
                    if targetPart and isAliveCharacter(targetChar) then
                        for _, tool in ipairs(toolsToFire) do
                            fireToolAtTarget(tool, targetPart, followShotsPerTick)
                            if followGunSpacing > 0 then
                                task.wait(followGunSpacing)
                            end
                        end
                    end
                end
            end)
            followFireInProgress = false
            if not ok then
                warn(err)
            end
        end)
    end
end)

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local humanoid = Character:FindFirstChildOfClass("Humanoid")
local root = Character:FindFirstChild("HumanoidRootPart")

Player.CharacterAdded:Connect(function(char)
    Character = char
    humanoid = char:WaitForChild("Humanoid")
    root = char:WaitForChild("HumanoidRootPart")
end)

function getEquippedGuns()
    local guns = {}
    local char = Player.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(guns, tool)
            end
        end
    end
    return guns
end

function getAmmoCount(gunName)
    local inventory = Player.DataFolder.Inventory
    local ammo = inventory:FindFirstChild(gunName)
    if ammo then
        return tonumber(ammo.Value)
    end
    return nil
end

function hasGun(toolName)
    local player = Player
    if not player then return false end
    
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and item.Name == toolName then
                return true
            end
        end
    end
    
    local character = player.Character
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") and item.Name == toolName then
                return true
            end
        end
    end
    
    return false
end

function getNextItemToBuy()
    local char = Player.Character
    if not char then return nil end

    for i = 1, #Guns do
        local gunKey = Guns[i]
        if DisabledGuns[gunKey] then
            continue
        end
        local gunInfo = gunData[gunKey]
        if gunInfo and not hasGun(gunInfo.toolName) then
            return "gun"
        end
    end

    if automaskenabled and not (char:FindFirstChild("[Mask]") or char:FindFirstChild("In-gameMask")) then
        return "mask"
    end

    return nil
end

local fired = false

game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
    fired = false
end)

local nativeFireClickDetector = fireclickdetector

local function resolveClickDetector(object)
    if typeof(object) ~= "Instance" then return nil end
    if object:IsA("ClickDetector") then
        return object
    end
    return object:FindFirstChildWhichIsA("ClickDetector", true)
end

local function manualFireClickDetector(clickDetector)
    if not fired then
        fired = true
        game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.E, false, game)
    end

    local localChar = game:GetService("Players").LocalPlayer.Character
    if localChar and localChar:FindFirstChildOfClass("Tool") then
        local humanoid = localChar:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:UnequipTools()
        end
    end

    local old_cd_parent = clickDetector.Parent

    local stub_part = Instance.new("Part")
    stub_part.Transparency = 1
    stub_part.Size = Vector3.new(30, 30, 30)
    stub_part.Anchored = true
    stub_part.CanCollide = false
    stub_part.Parent = workspace

    clickDetector.Parent = stub_part
    clickDetector.MaxActivationDistance = math.huge

    local connection = game:GetService("RunService").Heartbeat:Connect(function()
        stub_part.CFrame = workspace.Camera.CFrame * CFrame.new(0, 0, -20) * CFrame.new(workspace.Camera.CFrame.LookVector)
        game:GetService("VirtualUser"):ClickButton1(Vector2.new(20, 20), workspace:FindFirstChildOfClass("Camera").CFrame)
    end)

    clickDetector.MouseClick:Once(function()
        connection:Disconnect()
        clickDetector.Parent = old_cd_parent
        stub_part:Destroy()
    end)

    task.delay(3, function()
        connection:Disconnect()
        clickDetector.Parent = old_cd_parent
        stub_part:Destroy()
    end)
end

local function tryNativeClick(clickDetector)
    if not nativeFireClickDetector then
        return false
    end
    local ok = pcall(nativeFireClickDetector, clickDetector)
    return ok
end

getgenv().fireclickdetector = function(object)
    local clickDetector = resolveClickDetector(object)
    if not clickDetector then return end

    if tryNativeClick(clickDetector) then
        return
    end

    manualFireClickDetector(clickDetector)
end

local function getShopBasePart(item, clickDetector)
    if clickDetector and clickDetector.Parent and clickDetector.Parent:IsA("BasePart") then
        return clickDetector.Parent
    end
    if not item then
        return nil
    end
    local head = item:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head
    end
    return item:FindFirstChildWhichIsA("BasePart", true)
end

local function findShopItem(shopFolder, fullName, opts)
    if not shopFolder or not fullName then
        return nil
    end
    local exact = shopFolder:FindFirstChild(fullName)
    if exact then
        return exact
    end
    local bracket = fullName:match("%[(.-)%]")
    if not bracket then
        return nil
    end
    local wantAmmo = opts and opts.ammo
    for _, child in ipairs(shopFolder:GetChildren()) do
        if child.Name:find(bracket, 1, true) then
            if wantAmmo ~= nil then
                local isAmmo = child.Name:find("Ammo", 1, true) ~= nil
                if wantAmmo and not isAmmo then
                    continue
                end
                if (not wantAmmo) and isAmmo then
                    continue
                end
            end
            return child
        end
    end
    return nil
end

local armorItems = {
    standard = {
        name = "[High-Medium Armor] - $2589",
        position = Vector3.new(-934.025, -28.15, 570.55),
    },
    fire = {
        name = "[Fire Armor] - $4501",
        position = Vector3.new(-934.028, -4.872, 151.994),
    }
}

local function getArmorValue()
    local char = Player.Character
    local bodyEffects = char and char:FindFirstChild("BodyEffects")
    local armor = bodyEffects and bodyEffects:FindFirstChild("Armor")
    if armor and typeof(armor.Value) == "number" then
        return armor.Value
    end
    return 0
end

local function hasFireArmor()
    local char = Player.Character
    local bodyEffects = char and char:FindFirstChild("BodyEffects")
    if not bodyEffects then
        return false
    end
    local fields = {"FireResist", "FireProtection", "FireArmor", "FireProof"}
    for _, fieldName in ipairs(fields) do
        local field = bodyEffects:FindFirstChild(fieldName)
        if field then
            if typeof(field.Value) == "boolean" and field.Value then
                return true
            end
            if typeof(field.Value) == "number" and field.Value > 0 then
                return true
            end
        end
    end
    local charFire = char:FindFirstChild("FireArmor") or char:FindFirstChild("FireProtection")
    if charFire then
        return true
    end
    return false
end

local function purchaseArmor(itemInfo)
    if not itemInfo then
        return false
    end
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and humanoid and humanoid.Health > 0) then
        return false
    end
    if buyingGunInProgress or buyingInProgress or buyingMaskInProgress or buyingArmorInProgress then
        return false
    end

    local now = os.clock()
    if now - lastArmorPurchase < 1 then
        return false
    end

    local shopFolder = workspace:FindFirstChild("Ignored") and workspace.Ignored:FindFirstChild("Shop")
    local armorItem = shopFolder and findShopItem(shopFolder, itemInfo.name, {ammo = false})
    local clickDetector = armorItem and armorItem:FindFirstChildWhichIsA("ClickDetector", true)
    local shopBase = getShopBasePart(armorItem, clickDetector)
    if not clickDetector or not shopBase then
        return false
    end

    local prevBuying = buyingInProgress
    buyingArmorInProgress = true
    buyingInProgress = true

    local success = false
    withNoclip(function()
        for _ = 1, 4 do
            if humanoid then
                humanoid:UnequipTools()
            end
            safeTeleportToShop(root, shopBase)
            getgenv().fireclickdetector(clickDetector)
            task.wait(0.25)
            if getArmorValue() >= ArmorThreshold then
                success = true
                break
            end
        end
    end)

    buyingInProgress = prevBuying
    buyingArmorInProgress = false
    if success then
        lastArmorPurchase = os.clock()
    end
    return success
end

local function buyAmmoForGun(gunName, times)
    if not gunName or SkipAmmoFor[gunName] or not AmmoMap then
        return
    end
    if not hasGun(gunName) then
        return
    end
    local ammoItemName = AmmoMap[gunName]
    if not ammoItemName then
        return
    end
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and humanoid and humanoid.Health > 0) then
        return
    end

    local shopFolder = workspace:FindFirstChild("Ignored") and workspace.Ignored:FindFirstChild("Shop")
    local ammoItem = findShopItem(shopFolder, ammoItemName, {ammo = true})
    if not ammoItem then
        return
    end

    local clickDetector = ammoItem:FindFirstChildWhichIsA("ClickDetector", true)
    local shopPart = getShopBasePart(ammoItem, clickDetector)
    if not (clickDetector and shopPart) then
        return
    end

    local prevBuying = buyingInProgress
    buyingInProgress = true
    local buyCount = times or AmmoPurchaseCount
    withNoclip(function()
        for _ = 1, buyCount do
            if humanoid then
                humanoid:UnequipTools()
            end
            safeTeleportToShop(root, shopPart)
            getgenv().fireclickdetector(clickDetector)
            task.wait(0.1)
        end
    end)
    buyingInProgress = prevBuying
    reloadTool()
end

-- FIXED GUN BUYING LOOP (NOW ACTIVATED)
task.spawn(function()
    while true do
        task.wait(0.2)
        
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        
        if char and root and humanoid and humanoid.Health > 0 and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) then
            for i = 1, #Guns do
                local gunKey = Guns[i]
                if DisabledGuns[gunKey] then
                    continue
                end
                local gunInfo = gunData[gunKey]
                
                if gunInfo then
                    local toolName = gunInfo.toolName
                    
                    if not hasGun(toolName) then
                        buyingGunInProgress = true
                        
                        local shopName = gunInfo.shopName
                        local shopFolder = workspace:FindFirstChild("Ignored") and workspace.Ignored:FindFirstChild("Shop")
                        local shopPart = findShopItem(shopFolder, shopName, {ammo = false})
                        
                        if shopPart then
                            local clickDetector = shopPart:FindFirstChildWhichIsA("ClickDetector", true)
                            local shopBase = getShopBasePart(shopPart, clickDetector)
                            
                            if clickDetector and shopBase then
                                withNoclip(function()
                                    safeTeleportToShop(root, shopBase)
                                    task.wait(0.05)
                                    
                                    local buyAttempts = 0
                                    while not hasGun(toolName) and buyAttempts < 10 do
                                        if humanoid then
                                            humanoid:UnequipTools()
                                        end
                                        
                                        safeTeleportToShop(root, shopBase)
                                        getgenv().fireclickdetector(clickDetector)
                                        task.wait(0.1)
                                        buyAttempts = buyAttempts + 1
                                    end
                                end)
                                
                                if hasGun(toolName) then
                                    task.wait(0.05)
                                    equipTool(toolName)
                                    buyAmmoForGun(toolName, AmmoPurchaseCount)
                                end
                            end
                        end
                        
                        buyingGunInProgress = false
                        task.wait(0.5)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        local char = Player.Character
        if char and automaskenabled and not buyingMaskInProgress and not buyingGunInProgress and not buyingInProgress then
            pcall(function()
                local humanoid = char:FindFirstChildOfClass("Humanoid")

                if Player.Backpack:FindFirstChild("[Mask]") or char:FindFirstChild("[Mask]") or char:FindFirstChild("In-gameMask") then 
                    buyingMaskInProgress = false 
                    return 
                end

                local ShopFolder = workspace:WaitForChild("Ignored"):WaitForChild("Shop")

                local maskItem = ShopFolder:FindFirstChild(
                    (math.random(1, 2) == 1 and "[Skull Mask] - $66" or "[Riot Mask] - $66")
                )
                if not maskItem then return end

                local clickDetector = maskItem:FindFirstChildWhichIsA("ClickDetector", true)
                if not clickDetector then return end

                buyingMaskInProgress = true
                local char = Player.Character
                local root = char:FindFirstChild("HumanoidRootPart")
                local shopBase = getShopBasePart(maskItem, clickDetector)
                if not shopBase then return end

                withNoclip(function()
                    while automaskenabled and char and not (Player.Backpack:FindFirstChild("[Mask]") or char:FindFirstChild("[Mask]")) do
                        local char = Player.Character
                        local root = char:FindFirstChild("HumanoidRootPart")
                        if root then
                            safeTeleportToShop(root, shopBase)
                        end
                        getgenv().fireclickdetector(clickDetector)
                        task.wait(0.1)
                        if not automaskenabled or not char or (Player.Backpack:FindFirstChild("[Mask]") or char:FindFirstChild("[Mask]")) then break end
                    end
                end)

                task.spawn(function()
                    while automaskenabled and char do
                        local char = Player.Character
                        local maskTool = Player.Backpack:FindFirstChild("[Mask]") or char:FindFirstChild("[Mask]")
                        if maskTool then
                            for _, tool in ipairs(char:GetChildren()) do
                                if tool:IsA("Tool") and tool.Name ~= "[Mask]" then
                                    tool.Parent = Player.Backpack
                                end
                            end
                            maskTool.Parent = char
                            maskTool:Activate()
                        end
                        if char:FindFirstChild("In-gameMask") then
                            local equippedMask = char:FindFirstChild("[Mask]")
                            if equippedMask then
                                equippedMask.Parent = Player.Backpack
                            end
                            buyingMaskInProgress = false
                            break
                        end
                        if not automaskenabled or not char then break end
                        task.wait(standWait(perf.mask))
                    end
                end)
            end)
        end
        task.wait(standWait(perf.mask))
    end
end)

task.spawn(function()
    while true do
        task.wait(ArmorRecheckDelay)
        local char = Player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local bodyEffects = char and char:FindFirstChild("BodyEffects")
        if not autoArmorEnabled or not (char and humanoid and humanoid.Health > 0 and bodyEffects) then
            continue
        end
        if buyingGunInProgress or buyingInProgress or buyingMaskInProgress or buyingArmorInProgress then
            continue
        end

        local armorValue = getArmorValue()
        local hasFire = hasFireArmor()

        if armorValue < ArmorThreshold then
            purchaseArmor(armorItems.standard)
            armorValue = getArmorValue()
        end

        if autoFireArmorEnabled and not hasFireArmor() then
            purchaseArmor(armorItems.fire)
        end
    end
end)

AmmoMap = {
    ["[Rifle]"]      = "5 [Rifle Ammo] - $273",
    ["[AUG]"]        = "90 [AUG Ammo] - $87",
    ["[Flintlock]"]  = "6 [Flintlock Ammo] - $163",
    ["[LMG]"]        = "200 [LMG Ammo] - $328",
    ["[Double-Barrel SG]"] = "18 [Double-Barrel SG Ammo] - $55"
}

-- FIXED AMMO BUYING LOOP
task.spawn(function()
    while true do
        task.wait(3) -- Check ammo every 3 seconds
        
        local char = Player.Character
        if not char then continue end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not (humanoid and root and humanoid.Health > 0) then
            continue
        end
        if buyingGunInProgress or buyingInProgress or buyingMaskInProgress then
            continue
        end
        if getNextItemToBuy() == "gun" then
            continue
        end

        -- Check reserve ammo for configured guns only.
        for _, gunKey in ipairs(Guns) do
            if DisabledGuns[gunKey] then
                continue
            end
            local gunInfo = gunData[gunKey]
            if gunInfo then
                local gunName = gunInfo.toolName
                if not SkipAmmoFor[gunName] then
                    if not hasGun(gunName) then
                        continue
                    end
                    local ammoCount = getAmmoCount(gunName)
                    if ammoCount and ammoCount <= 0 then
                        buyAmmoForGun(gunName, AmmoPurchaseCount)
                    end
                end
            end
        end
    end
end)

local humanoid = Character:FindFirstChild("Humanoid")
local bodyEffects = Character and Character:FindFirstChild("BodyEffects")
local koValue = bodyEffects and bodyEffects:FindFirstChild("K.O")

local lastDamagerName = ""
getgenv().lastHealths = {}

task.spawn(function()
    while true do
        if hardStop then
            task.wait(standWait(perf.equip))
            continue
        end
        if Character then
            for _, tool in ipairs(Character:GetChildren()) do
                if tool:IsA("Tool") then
                    tryReloadTool(tool)
                end
            end
        end
        if not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) then
            local backpack = localPlayer:FindFirstChild("Backpack")
            if backpack and humanoid and humanoid.Health > 0 and Character then
                local equippedCount = 0
                local equippedNames = {}

                for _, tool in ipairs(Character:GetChildren()) do
                    if isGunTool(tool) then
                        equippedCount += 1
                        equippedNames[tool.Name] = true
                    end
                end

                if equippedCount < EquipGunCount then
                    for _, gunKey in ipairs(Guns) do
                        if DisabledGuns[gunKey] then
                            continue
                        end
                        local gunInfo = gunData[gunKey]
                        if gunInfo then
                            local gunName = gunInfo.toolName
                            if not equippedNames[gunName] then
                                local gun = backpack:FindFirstChild(gunName)
                                if gun then
                                    gun.Parent = Character
                                    equippedCount += 1
                                    equippedNames[gunName] = true
                                    if equippedCount >= EquipGunCount then
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if autodrop then
            ReplicatedStorage.MainEvent:FireServer("DropMoney", "15000")
        end
        -- Do NOT auto-kill the stand when KO; it breaks combat commands by constantly resetting the character.
        -- Only force death when autosave is disabled (legacy behavior).
        if humanoid and koValue and koValue.Value == true then
            if not autoSaveEnabled then
                humanoid.Health = 0
            end
        end
        if shouldSwitch and #ragebottargets > 0 then
            local attempts = 0
            while attempts < #ragebottargets do
                currentTargetIndex = (currentTargetIndex % #ragebottargets) + 1
                local candidate = ragebottargets[currentTargetIndex]
                if candidate and candidate.Character then
                    local bodyEffects = candidate.Character:FindFirstChild("BodyEffects")
                    local isDeath = bodyEffects and bodyEffects:FindFirstChild("SDeath") and bodyEffects["SDeath"].Value
                    if not isDeath then
                        lockedTarget = candidate
                        shouldSwitch = false
                        break
                    end
                end
                attempts += 1
            end
        end
        task.wait(standWait(perf.equip))
    end
end)

task.spawn(function()
    while task.wait(0.2) do
        if getgenv().enabled1 and not lockedTarget then
            local playersToCheck = {Owner}
            for pname, _ in pairs(getgenv().sentryprotected) do
                table.insert(playersToCheck, pname)
            end

            for _, pname in ipairs(playersToCheck) do
                local player = Players:FindFirstChild(pname)
                if player and player.Character then
                    local char = player.Character
                    local bodyEffects = char:FindFirstChild("BodyEffects")
                    local lastDamager = bodyEffects and bodyEffects:FindFirstChild("LastDamager")
                    local humanoid = char:FindFirstChildOfClass("Humanoid")

                    if bodyEffects and lastDamager and humanoid then
                        local healthNow = humanoid.Health
                        if getgenv().lastHealths[pname] == nil then
                            getgenv().lastHealths[pname] = healthNow
                        end

                        if healthNow + 0.05 < getgenv().lastHealths[pname] then
                            getgenv().lastHealths[pname] = healthNow
                            task.wait(0.1)

                            local recheck = char:FindFirstChild("BodyEffects"):FindFirstChild("LastDamager")
                            local attackerName = recheck and tostring(recheck.Value)

                            if attackerName ~= "" then
                                local attacker = Players:FindFirstChild(attackerName)
                                if attacker then
                                    sentrytarget = attacker
                                    teleporting = true
                                    voiding = false
                                end
                            end
                        else
                            getgenv().lastHealths[pname] = healthNow
                        end

                        if sentrytarget and sentrytarget.Character then
                            local atkChar = sentrytarget.Character
                            local atkBE = atkChar:FindFirstChild("BodyEffects")
                            local isKO = atkBE and atkBE:FindFirstChild("K.O") and atkBE["K.O"].Value

                            if isKO then
                                sentrytarget = nil
                                teleporting = false
                                voiding = true
                                reloadTool()
                            end
                        end
                    end
                else
                    getgenv().lastHealths[pname] = nil
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(standWait(perf.summon)) do
        if summonTarget and summonTarget.Character and not (buyingInProgress or buyingGunInProgress or buyingMaskInProgress) then
            
            local lp = Players.LocalPlayer
            if not lp.Character then continue end

            local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
            local thrp = summonTarget.Character:FindFirstChild("HumanoidRootPart")

            if hrp and thrp then
                hrp.Velocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero

                local offset
                if summonMode == "middle" then
                    offset = CFrame.new(0, 3, 4)
                elseif summonMode == "right" then
                    offset = CFrame.new(3, 3, 0)
                elseif summonMode == "left" then
                    offset = CFrame.new(-3, 3, 0)
                else
                    offset = CFrame.new(0, 3, 4)
                end

                hrp.CFrame = thrp.CFrame * offset

                hrp.Velocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end
end)

-- Autosave (bring owner to safe position when knocked)
task.spawn(function()
    local lastSaveAt = 0
    local savingActive = false

    local function canSaveNow()
        return (os.clock() - lastSaveAt) > 0.35
    end

    local function findOwnerPart(ownerChar)
        return ownerChar and (ownerChar:FindFirstChild("UpperTorso") or ownerChar:FindFirstChild("HumanoidRootPart") or ownerChar:FindFirstChild("Torso"))
    end

    while task.wait(0.06) do
        if not autoSaveEnabled or savingActive then
            continue
        end
        if buyingInProgress or buyingGunInProgress or buyingMaskInProgress or buyingArmorInProgress then
            continue
        end
        if vehicleMode then
            continue
        end

        local ownerPlr = Players:FindFirstChild(Owner)
        local ownerChar = ownerPlr and ownerPlr.Character
        local ownerBE = ownerChar and ownerChar:FindFirstChild("BodyEffects")
        local ownerKO = ownerBE and ownerBE:FindFirstChild("K.O")
        if not (ownerKO and ownerKO.Value == true) then
            continue
        end

        -- If owner is already at/near the save spot, do nothing (prevents spam)
        local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")
        if ownerRoot and (ownerRoot.Position - autoSavePosition).Magnitude < 16 then
            continue
        end

        if not canSaveNow() then
            continue
        end

        local lp = Players.LocalPlayer
        local myChar = lp and lp.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        local ownerPart = findOwnerPart(ownerChar)
        if not (myHRP and myHum and myHum.Health > 0 and ownerPart) then
            continue
        end

        lastSaveAt = os.clock()
        savingActive = true

        -- pause other behaviors
        lockedTarget = nil
        teleporting = false
        voiding = false
        summonTarget = nil
        stomponly = false
        bringonly = false
        takeonly = false
        getgenv().downonly = false
        opkill = false
        flingonly = false

        local function dropSequence()
            myHRP.CFrame = CFrame.new(autoSavePosition + Vector3.new(0, 3, 0))
            task.wait(0.07)
            ReplicatedStorage.MainEvent:FireServer("Grabbing", false)
            task.wait(0.08)
            myHRP.CFrame = CFrame.new(autoSavePosition + Vector3.new(0, 6, -10))
        end

        withNoclip(function()
            -- Attempt grab a few times (Da Hood can be inconsistent)
            for _ = 1, 4 do
                if not (ownerKO and ownerKO.Value == true) then
                    break
                end

                ownerPart = findOwnerPart(ownerChar)
                if not ownerPart then
                    break
                end

                myHRP.CFrame = CFrame.new(ownerPart.Position + Vector3.new(0, 3.5, 0))
                task.wait(0.04)
                ReplicatedStorage.MainEvent:FireServer("Grabbing", false)
                task.wait(0.12)

                -- if grab succeeded, Da Hood adds GRABBING_CONSTRAINT to victim
                if ownerChar and ownerChar:FindFirstChild("GRABBING_CONSTRAINT") then
                    break
                end
            end

            -- Whether grab succeeded or not, force a drop at save spot.
            dropSequence()

            -- Extra drop pulses to release in case it's stuck grabbing
            for _ = 1, 3 do
                task.wait(0.06)
                ReplicatedStorage.MainEvent:FireServer("Grabbing", false)
            end
        end)

        teleporting = false
        voiding = true

        -- Cooldown window to stop re-trigger spam while KO remains true
        task.delay(1.25, function()
            savingActive = false
        end)
    end
end)

local function getVehicleRootPart(vehicle)
    if not vehicle then
        return nil
    end
    return vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart", true)
end

local function findVehicleModel()
    if vehicleModel and vehicleModel.Parent then
        return vehicleModel
    end
    local now = os.clock()
    if now - lastVehicleSearch < 0.75 then
        return vehicleModel
    end
    lastVehicleSearch = now

    local closest = nil
    local closestDist = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == vehicleName then
            local root = getVehicleRootPart(obj)
            if root then
                local dist = (root.Position - vehicleSeatCFrame.Position).Magnitude
                if not closestDist or dist < closestDist then
                    closest = obj
                    closestDist = dist
                end
            else
                closest = obj
            end
        end
    end

    vehicleModel = closest
    return vehicleModel
end

local function getVehicleSeats(vehicle)
    if not vehicle then
        return nil, nil
    end
    local driverSeat = vehicle:FindFirstChild(vehicleSeatName, true)
    local passengerSeat = nil
    for _, seat in ipairs(vehicle:GetDescendants()) do
        if seat:IsA("Seat") and seat.Name == passengerSeatName then
            passengerSeat = seat
            break
        end
    end
    if passengerSeat == driverSeat then
        passengerSeat = nil
    end
    return driverSeat, passengerSeat
end

local function moveAssembly(part, targetCFrame)
    if not (part and targetCFrame) then
        return
    end
    part.AssemblyLinearVelocity = Vector3.zero
    part.AssemblyAngularVelocity = Vector3.zero
    part.CFrame = targetCFrame
end

local function moveVehicleRootToSeat(rootPart, seatPart, desiredSeatCFrame)
    if not (rootPart and seatPart and desiredSeatCFrame) then
        return
    end
    local seatOffset = rootPart.CFrame:ToObjectSpace(seatPart.CFrame)
    local targetRoot = desiredSeatCFrame * seatOffset:Inverse()
    moveAssembly(rootPart, targetRoot)
end

local function getVehicleDestinationCFrame()
    if gotoTarget then
        local targetChar = gotoTarget.Character
        local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        if targetHRP then
            return CFrame.new(targetHRP.Position)
        end
        return nil
    end
    return gotoCFrame
end

local function tryPurchaseVehicle()
    if not vehiclePurchaseEnabled then
        return false
    end
    if buyingVehicleInProgress then
        return false
    end
    if buyingGunInProgress or buyingMaskInProgress or buyingArmorInProgress then
        return false
    end
    local now = os.clock()
    if now - lastVehiclePurchase < 1 then
        return false
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and humanoid and humanoid.Health > 0) then
        return false
    end

    local shopFolder = workspace:FindFirstChild("Ignored") and workspace.Ignored:FindFirstChild("Shop")
    local cartItem = shopFolder and findShopItem(shopFolder, vehicleShopName, {ammo = false})
    local clickDetector = cartItem and cartItem:FindFirstChildWhichIsA("ClickDetector", true)
    local shopBase = getShopBasePart(cartItem, clickDetector)
    if not clickDetector or not shopBase then
        return false
    end

    local prevBuying = buyingInProgress
    buyingVehicleInProgress = true
    buyingInProgress = true

    withNoclip(function()
        safeTeleportToShop(root, shopBase)
        local fireClick = getgenv().fireclickdetector or fireclickdetector
        if fireClick then
            fireClick(clickDetector)
        end
        task.wait(0.2)
    end)

    buyingInProgress = prevBuying
    buyingVehicleInProgress = false
    lastVehiclePurchase = os.clock()
    return true
end

-- Vehicle Mode Handler - Stand drives cart via HRP movement
local vehicleVelocityCleared = false

task.spawn(function()
    while task.wait(0) do
        if vehicleMode and gotoPlayer and (gotoCFrame or gotoTarget) then
            local char = LocalPlayer and LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local ownerChar = gotoPlayer and gotoPlayer.Character
            local oHrp = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")
            
            if not (hrp and hum and oHrp) then continue end
            
            local dest = getVehicleDestinationCFrame()
            if not dest then continue end
            
            local veh = findVehicleModel()
            if not veh then
                vehicleVelocityCleared = false
                if (hrp.Position - vehiclePickupPos).Magnitude > 4 then
                    hrp.CFrame = CFrame.new(vehiclePickupPos + Vector3.new(0, 3, 0))
                else
                    tryPurchaseVehicle()
                end
                continue
            end
            
            -- Unanchor wheels so cart can fly
            local wheelNames = {LBWheel=1, LTWheel=1, RBWheel=1, RTWheel=1, L_Rotator=1, R_Rotator=1}
            for _, part in ipairs(veh:GetDescendants()) do
                if part:IsA("BasePart") and wheelNames[part.Name] then
                    part.Anchored = false
                    part.CanCollide = false
                end
            end
            
            local dSeat, pSeat = getVehicleSeats(veh)
            local vRoot = getVehicleRootPart(veh) or dSeat or hrp
            
            -- Step 1: Sit in driver seat if not seated
            if dSeat and hum.SeatPart ~= dSeat then
                vehicleVelocityCleared = false
                if not dSeat.Occupant or dSeat.Occupant == hum then
                    vRoot.CFrame = vehicleSeatCFrame
                    vRoot.AssemblyLinearVelocity = Vector3.zero
                    vRoot.AssemblyAngularVelocity = Vector3.zero
                    pcall(function() dSeat:Sit(hum) end)
                end
                continue
            end
            
            -- Clear velocities once after seating
            if not vehicleVelocityCleared then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                vRoot.AssemblyLinearVelocity = Vector3.zero
                vRoot.AssemblyAngularVelocity = Vector3.zero
                vehicleVelocityCleared = true
            end
            
            -- Check if owner is seated in passenger seat
            local oHum = ownerChar:FindFirstChildOfClass("Humanoid")
            local ownerSeated = pSeat and oHum and pSeat.Occupant == oHum
            
            -- MOVE THE STAND's HRP (cart follows via VehicleSeat physics)
            if not ownerSeated then
                -- Follow owner: position Stand behind and above owner
                local targetPos = oHrp.CFrame * CFrame.new(0, 2, 5)
                hrp.CFrame = targetPos
            else
                -- Owner seated: fly Stand to destination
                if (hrp.Position - dest.Position).Magnitude > 3 then
                    hrp.CFrame = dest
                else
                    -- Arrived at destination
                    vehicleMode = false
                    gotoPlayer = nil
                    gotoCFrame = nil
                    gotoTarget = nil
                    vehicleModel = nil
                    vehicleVelocityCleared = false
                    voiding = true
                end
            end
        else
            vehicleVelocityCleared = false
        end
    end
end)

local hitboxsize = LowLagMode and 12 or 30
local lastHitboxUpdate = 0

deactivatePowerMode = function()
    if not powerModeActive then
        return
    end

    -- Always restore full defaults.
    if not defaultConfigCaptured then
        captureDefaultConfig()
    end

    -- Restore perf timings
    LowLagMode = defaultConfig.LowLagMode
    for k, v in pairs(defaultPerf) do
        perf[k] = v
    end

    -- Restore movement/shoot defaults
    auraspeed = defaultConfig.auraspeed
    auradistance = defaultConfig.auradistance
    shotsPerTick = defaultConfig.shotsPerTick
    followShotsPerTick = defaultConfig.followShotsPerTick
    followShotCooldown = defaultConfig.followShotCooldown
    followGridRadius = defaultConfig.followGridRadius
    followMaxTargets = defaultConfig.followMaxTargets
    reloadCooldown = defaultConfig.reloadCooldown
    hitboxsize = defaultConfig.hitboxsize
    FPSCap = defaultConfig.FPSCap

    shootInterval = perf.shoot
    pcall(function()
        setfpscap(FPSCap)
    end)

    powerModeActive = false

    -- Reset any combat/loop state that can hijack follow/smoothness after POWER MODE.
    ragebottargets = {}
    shouldSwitch = false
    lockedTarget = nil
    lockedTargetUserId = nil
    teleporting = false

    -- If owner follow is enabled, rebind and keep stand out of void.
    if getgenv().enabled and standHomeName then
        startFollowingTarget(standHomeName)
        voiding = false
    end

    sendMessage("POWER MODE disabled.")
end

activatePowerMode = function()
    if powerModeActive then
        deactivatePowerMode()
        return
    end
    captureDefaultConfig()
    powerModeActive = true

    -- POWER MODE: BALANCED AGGRESSIVE - Maximum power without lag
    LowLagMode = false
    
    -- OPTIMIZED LOOP TIMINGS (fast but stable - prevents lag spikes)
    perf.loop = 0.015
    perf.combat = 0.015
    perf.void = 0.05
    perf.teleport = 0.015
    perf.target = 0.03
    perf.summon = 0.03
    perf.mask = 0.05
    perf.equip = 0.03
    perf.killall = 0.05
    perf.hitbox = 0.05
    perf.shoot = 0.01

    -- AGGRESSIVE MOVEMENT SPEED
    auraspeed = 35
    auradistance = 5

    -- HIGH FIREPOWER (balanced for stability - prevents network congestion)
    shotsPerTick = 12
    followShotsPerTick = 8
    followShotCooldown = 0.02

    -- LARGE SCAN RADIUS + MANY TARGETS
    followGridRadius = 300
    followMaxTargets = 20

    -- FAST RELOAD
    reloadCooldown = 0.25

    -- LARGE HITBOX
    hitboxsize = 35

    -- HIGH FPS CAP (reasonable limit)
    FPSCap = 120
    shootInterval = perf.shoot

    auraangle = math.random() * math.pi * 2
    pcall(function()
        setfpscap(FPSCap)
    end)

    if getgenv().enabled and standHomeName then
        startFollowingTarget(standHomeName)
    end
    sendMessage(" POWER MODE ACTIVATED - Balanced Performance ⚡")
end

local Players = cloneref(game:GetService("Players"))
local Client = Players.LocalPlayer

RunService.RenderStepped:Connect(function ()
    if perf.hitbox > 0 then
        local now = os.clock()
        if (now - lastHitboxUpdate) < perf.hitbox then
            return
        end
        lastHitboxUpdate = now
    end
    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= Client then
            local character = Player.Character
            if character then
                local HRP = character:FindFirstChild("HumanoidRootPart")
                if HRP then
                    HRP.Size = Vector3.new(hitboxsize, hitboxsize, hitboxsize)
                    HRP.CanCollide = false
                end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not (flingonly and lockedTarget) then return end

    Player.Character.HumanoidRootPart.Velocity = Vector3.new(99999999, 99999999, 99999999)
    RunService.RenderStepped:Wait()
    Player.Character.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
end)

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    humanoid = Character:WaitForChild("Humanoid")
    bodyEffects = Character:WaitForChild("BodyEffects")
    koValue = bodyEffects:WaitForChild("K.O")
end)

local Workspace = game:GetService("Workspace")

for _, v in ipairs(Workspace:GetDescendants()) do
    if v:IsA("Seat") then
        v:Destroy()
    end
end

Workspace.DescendantAdded:Connect(function(descendant)
    task.defer(function()
        if descendant:IsA("Seat") then
            descendant:Destroy()
        end
    end)
end)

local antiConnections = {}

function stripAnimations(character)
    if character:GetAttribute("AntiServerLaggerHandled") then return end
    character:SetAttribute("AntiServerLaggerHandled", true)

    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        animator:Destroy()
    end

    local animate = character:FindFirstChild("Animate")
    if animate then
        animate.Disabled = true
    end

    humanoid.AutoRotate = false
end

function onPlayer(player)
    if player == LocalPlayer then return end

    if player.Character then
        stripAnimations(player.Character)
    end

    local charConn = player.CharacterAdded:Connect(stripAnimations)
    table.insert(antiConnections, charConn)
end

function EnableAntiServerLagger()
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayer(player)
    end

    antiConnections.playerAdded = Players.PlayerAdded:Connect(onPlayer)
end

EnableAntiServerLagger()

if BlackScreen then
    pcall(function()
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local cam = workspace.CurrentCamera

        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = CFrame.new(99999, 99999, 99999)

        player.CharacterAdded:Connect(function()
            task.wait(1)
            cam.CameraType = Enum.CameraType.Scriptable
            cam.CFrame = CFrame.new(99999, 99999, 99999)
        end)

        workspace.Terrain:Clear()

        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("ParticleEmitter") or obj:IsA("Light") then
                obj:Destroy()
            end
            if obj:IsA("BasePart") then
                obj.Transparency = 1
                obj.CastShadow = false
                obj.Material = Enum.Material.SmoothPlastic
                if obj:FindFirstChild("SurfaceAppearance") then
                    obj.SurfaceAppearance:Destroy()
                end
            end
        end

        local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
        gui.Name = "FPS_BLACKOUT"
        gui.Parent = game.CoreGui
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local frame = Instance.new("Frame", gui)
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.Position = UDim2.new(-0.5, 0, -0.5, 0)
        frame.Size = UDim2.new(2, 0, 2, 0)
        frame.ZIndex = 9999
    end)
end

setfpscap(FPSCap)

pcall(function()
    settings().Rendering.QualityLevel = "Level01"
    UserSettings():GetService("UserGameSettings").MasterVolume = 0
end)
pcall(function()
    local lasers = workspace:FindFirstChild("MAP") and workspace.MAP:FindFirstChild("Indestructible") and workspace.MAP.Indestructible:FindFirstChild("Lasers")
    if lasers then
        lasers:Destroy()
    end
end)
pcall(function()
    pcall(function()
        for _, descendant in ipairs(workspace:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Material = Enum.Material.Plastic
                descendant.Color = Color3.fromRGB(0, 0, 0)
                descendant.Reflectance = 0
                descendant.CastShadow = false
            end
        end

        workspace.DescendantAdded:Connect(function(part)
            if part:IsA("BasePart") then
                part.Material = Enum.Material.Plastic
                part.Color = Color3.fromRGB(0, 0, 0)
                part.Reflectance = 0
                part.CastShadow = false
            end
        end)
    end)

    pcall(function()
        local VirtualUser = game:GetService("VirtualUser")
        game:GetService("Players").LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end)
