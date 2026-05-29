-- ============================================================================
-- Shared Helper: Idle Suggestion
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Last suggestion cache
local last_suggestion = {
    text = "",
    timestamp = 0,
    priority = 0,
}

local UPDATE_INTERVAL = 0.5  -- Update every 500ms

local function now()
    return NS and NS.time_now and NS.time_now() or 0
end

-- Priority order (higher = more important)
local PRIORITIES = {
    COMBAT_MISSING_BUFF = 100,
    COMBAT_MAINTAIN_DEBUFF = 90,
    COMBAT_USE_COOLDOWN = 85,
    COMBAT_FILLER_SPELL = 70,
    OOC_MISSING_BUFF = 60,
    OOC_CONSUMABLE = 50,
    OOC_WEAPON_BUFF = 40,
    OOC_SUMMON_PET = 30,
    NOTHING = 0,
}

-- Get suggestion based on context
function M.get_suggestion(context)
    if not context then return { text = "", priority = 0 } end
    
    local suggestion = { text = "", priority = PRIORITIES.NOTHING }
    local player_class = NS and NS.PLAYER_CLASS
    
    -- Combat suggestions
    if context.in_combat then
        if context.should_burst then
            suggestion.text = "Use offensive cooldowns!"
            suggestion.priority = PRIORITIES.COMBAT_USE_COOLDOWN
        end
        
        if suggestion.priority == PRIORITIES.NOTHING then
            if context.gcd_remains and context.gcd_remains == 0 then
                if not context.is_casting and not context.is_channeling then
                    suggestion.text = "Cast next spell in priority"
                    suggestion.priority = PRIORITIES.COMBAT_FILLER_SPELL
                end
            end
        end
    else
        -- Out of combat suggestions
        if suggestion.priority == PRIORITIES.NOTHING then
            if player_class == "shaman" or player_class == "rogue" then
                suggestion.text = "Check weapon buffs"
                suggestion.priority = PRIORITIES.OOC_WEAPON_BUFF
            end
        end
        
        if suggestion.priority == PRIORITIES.NOTHING then
            if player_class == "hunter" or player_class == "warlock" then
                if NS and NS.GetPet then
                    local pet = NS.GetPet()
                    if not pet then
                        suggestion.text = "Summon pet"
                        suggestion.priority = PRIORITIES.OOC_SUMMON_PET
                    end
                end
            end
        end
    end
    
    return suggestion
end

-- Update suggestion (throttled)
function M.update(context)
    local t = now()
    if (t - last_suggestion.timestamp) < UPDATE_INTERVAL then
        return last_suggestion.text
    end
    
    local suggestion = M.get_suggestion(context)
    
    last_suggestion.text = suggestion.text
    last_suggestion.priority = suggestion.priority
    last_suggestion.timestamp = t
    
    return suggestion.text
end

-- Get current suggestion
function M.get_current()
    return last_suggestion.text
end

if NS then
    NS.IdleSuggestion = M
end

return M
