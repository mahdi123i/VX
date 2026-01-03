local SCRIPT_ID = "DAHOOD_STAND_" .. tostring(math.random(100000, 999999))
if getgenv()[SCRIPT_ID] then return end
getgenv()[SCRIPT_ID] = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local State = {
Summoned = false,
Model = nil,
Root = nil,
FollowConnection = nil
}

local function GetRoot()
local char = LocalPlayer.Character
if not char then return nil end
return char:FindFirstChild("HumanoidRootPart")
end

local function CreateStand()
if State.Model then
pcall(function() State.Model:Destroy() end)
end

local model = Instance.new("Model")
model.Name = "Stand_" .. LocalPlayer.Name
model.Parent = workspace

local root = Instance.new("Part")
root.Name = "StandRoot"
root.Size = Vector3.new(2, 2, 1)
root.Transparency = 0.2
root.CanCollide = false
root.Anchored = true
root.Material = Enum.Material.ForceField
root.Color = Color3.fromRGB(0, 255, 255)
root.TopSurface = Enum.SurfaceType.Smooth
root.BottomSurface = Enum.SurfaceType.Smooth
root.Parent = model

model.PrimaryPart = root

State.Model = model
State.Root = root

if State.FollowConnection then
    pcall(function() State.FollowConnection:Disconnect() end)
end

local t = 0
local currentCF = root.CFrame

State.FollowConnection = RunService.Heartbeat:Connect(function(dt)
    if not State.Summoned or not State.Root or not State.Root.Parent then
        return
    end

    local playerRoot = GetRoot()
    if not playerRoot then return end

    t = t + dt
    local backOffset = -playerRoot.CFrame.LookVector * 3.5
    local bob = math.sin(t * 2) * 0.3
    local upOffset = Vector3.new(0, 2.5 + bob, 0)

    local targetPos = playerRoot.Position + backOffset + upOffset
    local targetCF = CFrame.new(targetPos, targetPos + playerRoot.CFrame.LookVector)

    currentCF = currentCF:Lerp(targetCF, math.clamp(dt * 8, 0, 1))
    State.Root.CFrame = currentCF
end)
end

local function Summon()
if State.Summoned then return end
State.Summoned = true
CreateStand()
end

local function ProcessCommand(msg)
if not msg or msg == "" then return end
msg = msg:match("^%s*(.-)%s*$") or msg
msg = msg:lower()
if msg == ".s" then
Summon()
end
end

pcall(function()
if LocalPlayer.Chatted then
LocalPlayer.Chatted:Connect(function(msg)
ProcessCommand(msg)
end)
end
end)

pcall(function()
if TextChatService and TextChatService.OnIncomingMessage then
TextChatService.OnIncomingMessage:Connect(function(message)
if message then
ProcessCommand(message.Text)
end
end)
end
end)

pcall(function()
LocalPlayer.CharacterAdded:Connect(function()
if State.FollowConnection then
pcall(function() State.FollowConnection:Disconnect() end)
State.FollowConnection = nil
end
if State.Model then
pcall(function() State.Model:Destroy() end)
State.Model = nil
State.Root = nil
end
State.Summoned = false
end)
end)

