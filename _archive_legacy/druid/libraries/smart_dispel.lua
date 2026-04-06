-- =============================================================================
-- SMART DISPEL WHITELIST FOR RESTO DRUID
-- Only dispels debuffs that actually matter (skips trivial debuffs)
-- Ported from Flux AIO AuraIsValid pattern
-- =============================================================================

-- =============================================================================
-- CURSE WHITELIST - Curses that actually need dispelling
-- Priority: Silence > Healing Reduction > Stat Drain > Damage
-- =============================================================================
local CURSE_WHITELIST = {
    -- HIGH PRIORITY: Silence effects (healers can't heal)
    [17472] = {name = "Greater curse of Tongues", priority = 10},
    [15470] = {name = "Curse of Tongues", priority = 10},
    
    -- HIGH PRIORITY: Healing reduction
    [16597] = {name = "Curse of the Elements", priority = 9},
    [14900] = {name = "Curse of the Elements", priority = 9},
    
    -- MEDIUM PRIORITY: Stat drains
    [15730] = {name = "Curse of Weakness", priority = 6},
    [11893] = {name = "Curse of Weakness", priority = 6},
    [18262] = {name = "Curse of Recklessness", priority = 5},
    [16231] = {name = "Curse of Recklessness", priority = 5},
    
    -- MEDIUM PRIORITY: Damage taken increase
    [12889] = {name = "Curse of the Firebrand", priority = 5},
    [12938] = {name = "Curse of Shalzaru", priority = 5},
    
    -- LOW PRIORITY: Minor stat reductions (skip if mana low)
    [8552] = {name = "Curse of Thule", priority = 3},
    [3234] = {name = "Touch of Thule", priority = 3},
    [3436] = {name = "Wandering Plague", priority = 2}, -- Actually a disease but sometimes miscategorized
}

-- =============================================================================
-- POISON WHITELIST - Poisons that actually need dispelling
-- Priority: CC/Stun > Healing Reduction > Dot > Stat Drain
-- =============================================================================
local POISON_WHITELIST = {
    -- HIGH PRIORITY: CC/Stun poisons
    [13218] = {name = "Wound Poison", priority = 10},  -- Healing reduction
    [13222] = {name = "Wound Poison II", priority = 10},
    [13223] = {name = "Wound Poison III", priority = 10},
    [13224] = {name = "Wound Poison IV", priority = 10},
    [21565] = {name = "Deadly Poison", priority = 9},  -- Strong DoT
    [21787] = {name = "Deadly Poison II", priority = 9},
    [21788] = {name = "Deadly Poison III", priority = 9},
    [21789] = {name = "Deadly Poison IV", priority = 9},
    [21790] = {name = "Deadly Poison V", priority = 9},
    [21791] = {name = "Deadly Poison VI", priority = 9},
    [21792] = {name = "Deadly Poison VII", priority = 9},
    
    -- MEDIUM PRIORITY: Movement/CC poisons
    [13298] = {name = "Poison Mushroom", priority = 6},
    [13299] = {name = "Poison Mushroom", priority = 6},
    [14532] = {name = "Slowing Poison", priority = 6},
    [6251] = {name = "Venom Shot", priority = 5},
    
    -- LOW PRIORITY: Minor DoT poisons (can skip if mana low)
    [11918] = {name = "Poison", priority = 3},  -- Generic poison
    [744] =   {name = "Poison", priority = 3},  -- Low level poison
}

-- =============================================================================
-- DISPEL VALIDATOR
-- Returns: should_dispel (bool), debuff_info (table)
-- =============================================================================
local function should_dispel_curse(unit, debuffs)
    if not debuffs then
        local ok, d = pcall(function() return unit:get_debuffs() end)
        if not ok then return false, nil end
        debuffs = d
    end
    
    local best_debuff = nil
    local best_priority = 0
    
    for _, aura in ipairs(debuffs) do
        if aura.type == 8 then  -- CURSE
            local whitelist_entry = CURSE_WHITELIST[aura.id]
            if whitelist_entry then
                if whitelist_entry.priority > best_priority then
                    best_priority = whitelist_entry.priority
                    best_debuff = aura
                end
            end
        end
    end
    
    return best_debuff ~= nil, best_debuff
end

local function should_dispel_poison(unit, debuffs)
    if not debuffs then
        local ok, d = pcall(function() return unit:get_debuffs() end)
        if not ok then return false, nil end
        debuffs = d
    end
    
    -- Check if Abolish Poison is already ticking (don't recast)
    local ok_abolish, has_abolish = pcall(function() return unit:buff_up(2893) end)
    if ok_abolish and has_abolish then
        return false, nil  -- Abolish is already handling it
    end
    
    local best_debuff = nil
    local best_priority = 0
    
    for _, aura in ipairs(debuffs) do
        if aura.type == 4 then  -- POISON
            local whitelist_entry = POISON_WHITELIST[aura.id]
            if whitelist_entry then
                if whitelist_entry.priority > best_priority then
                    best_priority = whitelist_entry.priority
                    best_debuff = aura
                end
            end
        end
    end
    
    return best_debuff ~= nil, best_debuff
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================
local SmartDispel = {
    -- Whitelists (can be extended by user)
    CURSE_WHITELIST = CURSE_WHITELIST,
    POISON_WHITELIST = POISON_WHITELIST,
    
    -- Main functions
    should_dispel_curse = should_dispel_curse,
    should_dispel_poison = should_dispel_poison,
    
    -- Combined check for convenience
    check_dispel_needed = function(unit, dispel_type)
        local ok, debuffs = pcall(function() return unit:get_debuffs() end)
        if not ok then return false, nil end
        
        if dispel_type == "Curse" then
            return should_dispel_curse(unit, debuffs)
        elseif dispel_type == "Poison" then
            return should_dispel_poison(unit, debuffs)
        end
        
        return false, nil
    end,
    
    -- Get priority of a debuff (for UI/debugging)
    get_debuff_priority = function(debuff_id, debuff_type)
        local whitelist
        if debuff_type == "Curse" then
            whitelist = CURSE_WHITELIST
        elseif debuff_type == "Poison" then
            whitelist = POISON_WHITELIST
        else
            return 0
        end
        
        local entry = whitelist[debuff_id]
        return entry and entry.priority or 0
    end,
}

return SmartDispel
