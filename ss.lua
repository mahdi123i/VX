--[[
    SAFE LOADER FOR RESCUED STAND SYSTEM
    Use this loader to execute ss.lua safely
]]

-- Set owner name
getgenv().Owner = "Mahdirml123i"

-- Set configuration
getgenv()._C = {
    Fps = false,
    Msg = "Yare Yare Daze.",
    AntiMod = true,
    CrewID = 32570691,
    ChatCmds = true,
    AutoMask = true,
    AntiStomp = true,
    Smoothing = false,
    Hidescreen = false,
    LowGraphics = false,
    StandLeaveServerAfterOwnerLeft = false,
    TPMode = "Cart",
    GunMode = "Aug, Rifle",
    AuraRange = 250,
    FlyMode = "Glide",
    StandMode = "Star Platinum: The World",
    Position = "Back",
    CustomName = "Master",
    SummonPoses = "Pose3",
    CustomSummon = "Summon!",
    CustomPrefix = ".",
    MaskMode = "Riot",
    AutoSaveLocation = "DA_FURNITURE",
    Attack = "Heavy",
    AttackMode = "Sky",
    AttackDistance = 75,
    AttackPrediction = 0.34,
    AttackAutoPrediction = 0.23,
    Resolver = false,
    AutoPrediction = false,
    Sounds = true,
    CustomSong = 123456,
    SummonMusic = true,
    SummonMusicID = "Default"
}

-- Safe loader with proper error handling
local function SafeLoad()
    local URL = "https://raw.githubusercontent.com/mahdi123i/VX/main/ss.lua"
    
    -- Step 1: HttpGet with validation
    local success, source = pcall(function()
        return game:HttpGet(URL)
    end)
    
    if not success then
        warn("[LOADER] HttpGet failed: " .. tostring(source))
        return false
    end
    
    if typeof(source) ~= "string" then
        warn("[LOADER] HttpGet returned non-string: " .. typeof(source))
        return false
    end
    
    if #source < 100 then
        warn("[LOADER] HttpGet returned empty or too small source: " .. #source .. " bytes")
        return false
    end
    
    print("[LOADER] HttpGet successful: " .. #source .. " bytes")
    
    -- Step 2: sanitize source (GitHub may include code fences / BOM)
    do
        -- strip UTF-8 BOM
        source = source:gsub("^\239\187\191", "")

        -- strip common markdown code fences
        source = source:gsub("^%s*```[%w_]*%s*\n", "")
        source = source:gsub("\n%s*```%s*$", "")

        -- if file was pasted with duplicated fences, strip all remaining fence lines
        source = source:gsub("\n```[%w_]*\n", "\n")
        source = source:gsub("\n```\n", "\n")

        -- trim leading junk before first Lua comment/function (very defensive)
        local first = source:find("%-%-", 1, false) or source:find("local%s", 1) or source:find("function%s", 1)
        if first and first > 1 then
            source = source:sub(first)
        end
    end

    -- Step 3: loadstring with validation
    local fn, err = loadstring(source)
    
    if not fn then
        warn("[LOADER] loadstring failed: " .. tostring(err))
        return false
    end
    
    if typeof(fn) ~= "function" then
        warn("[LOADER] loadstring returned non-function: " .. typeof(fn))
        return false
    end
    
    print("[LOADER] loadstring successful")
    
    -- Step 3: Execute with pcall
    local execSuccess, execErr = pcall(fn)
    
    if not execSuccess then
        warn("[LOADER] Execution failed: " .. tostring(execErr))
        return false
    end
    
    print("[LOADER] Execution successful")
    return true
end

-- Execute
if SafeLoad() then
    print("[LOADER] Script loaded successfully")
else
    warn("[LOADER] Script failed to load")
end
