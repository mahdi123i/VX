--[[
    سكربت Stand المتكامل لـ Da Hood
    الوظائف:
    1. إعادة ضبط واجهة الدردشة (Chat GUI) لضمان ظهورها.
    2. استدعاء Stand (نموذج بسيط) خلف اللاعب عند كتابة ".s" في الدردشة.
    3. إزالة الـ Stand عند كتابة ".s" مرة أخرى.
--]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local COMMAND = ".s"
local STAND_OFFSET = 5 -- المسافة التي سيظهر فيها الـ Stand خلف اللاعب

local activeStand = nil

-- ====================================================================
-- 1. وظيفة إعادة ضبط الدردشة (لحل مشكلة Da Hood)
-- ====================================================================

local function restoreChatGUI()
    -- إعادة تفعيل واجهة الدردشة الأساسية
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
    
    -- محاولة إعادة ضبط موضع الدردشة باستخدام TextChatService
    if TextChatService then
        TextChatService.ChatInputBarConfiguration.TargetTextChannel = TextChatService.TextChannels.RBXGeneral
    end
    
    -- يمكن إضافة المزيد من الأوامر هنا إذا كانت Da Hood تستخدم طريقة معينة لإخفاء الدردشة
    -- على سبيل المثال، إذا كانت تخفيها عبر LocalScript، فإن تشغيل هذا السكربت قد يتجاوز ذلك.
    print("Chat GUI should be restored.")
end

-- ====================================================================
-- 2. وظيفة إنشاء Stand (نموذج بسيط)
-- ====================================================================

local function createStandModel()
    local stand = Instance.new("Model")
    stand.Name = "SimpleStand"
    
    -- إنشاء الجزء الأساسي (الجذع)
    local corePart = Instance.new("Part")
    corePart.Name = "PrimaryPart"
    corePart.Size = Vector3.new(2, 5, 2)
    corePart.BrickColor = BrickColor.new("Really red") -- يمكنك تغيير اللون
    corePart.Material = Enum.Material.Neon -- لإعطائه مظهراً مميزاً
    corePart.Anchored = true -- مهم جداً: تثبيت الجزء
    corePart.CanCollide = false
    corePart.Parent = stand
    
    stand.PrimaryPart = corePart
    
    -- إضافة جزء علوي (رأس)
    local headPart = Instance.new("Part")
    headPart.Name = "Head"
    headPart.Size = Vector3.new(2, 2, 2)
    headPart.BrickColor = BrickColor.new("Bright blue")
    headPart.Material = Enum.Material.Neon
    headPart.Anchored = true
    headPart.CanCollide = false
    headPart.CFrame = corePart.CFrame * CFrame.new(0, 3.5, 0) -- وضعه فوق الجذع
    headPart.Parent = stand
    
    -- ربط الأجزاء ببعضها (للتأكد من أنها تتحرك كوحدة واحدة)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = corePart
    weld.Part1 = headPart
    weld.Parent = stand
    
    return stand
end

-- ====================================================================
-- 3. وظيفة استدعاء/إزالة الـ Stand
-- ====================================================================

local function toggleStand()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    if activeStand then
        -- إزالة الـ Stand
        activeStand:Destroy()
        activeStand = nil
        print("Stand removed.")
    else
        -- استدعاء الـ Stand
        local rootPart = character.HumanoidRootPart
        local stand = createStandModel()
        
        -- حساب الموضع (خلف اللاعب)
        -- نستخدم CFrame.lookVector * -STAND_OFFSET للحصول على الموضع الخلفي
        local backVector = rootPart.CFrame.lookVector * -STAND_OFFSET
        local newCFrame = rootPart.CFrame + backVector
        
        stand:SetPrimaryPartCFrame(newCFrame)
        stand.Parent = workspace
        activeStand = stand
        print("Stand summoned.")
    end
end

-- ====================================================================
-- 4. الاستماع لأحداث الدردشة (Chat Listener)
-- ====================================================================

-- بما أننا في LocalScript، لا يمكننا استخدام player.Chatted.
-- سنستخدم TextChatService.MessageReceived للدردشة الحديثة.

TextChatService.MessageReceived:Connect(function(message)
    -- التحقق من أن الرسالة من اللاعب المحلي
    if message.TextSource and message.TextSource.UserId == LocalPlayer.UserId then
        local trimmedMessage = string.lower(string.trim(message.Text))
        
        if trimmedMessage == COMMAND then
            toggleStand()
        end
    end
end)

-- ====================================================================
-- 5. التنفيذ الأولي
-- ====================================================================

-- تشغيل وظيفة استعادة الدردشة عند بدء السكربت
restoreChatGUI()

print("Stand Script Loaded. Type '.s' in chat to summon/remove your Stand.")
