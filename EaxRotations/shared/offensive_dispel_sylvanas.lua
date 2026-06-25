-- Offensive Dispel Database — PvP enemy buff priority tiers.

local M = {}

-- ============================================================================
-- Priority Tier Constants (higher = dispel first)
-- ============================================================================
M.PRIORITY_CRITICAL = 4   -- Immunities & fight-winning buffs (DS, IB, BoP, PS)
M.PRIORITY_HIGH     = 3   -- Major throughput buffs (Bloodlust, PI, Innervate, etc.)
M.PRIORITY_MEDIUM    = 2   -- Stat buffs (Fort, Mark, AI, MotW)
M.PRIORITY_LOW      = 1   -- Minor buffs (Thorns, Inner Fire, etc.)

-- ============================================================================
-- CRITICAL (Tier 4): Immunities & damage-negation buffs
-- ============================================================================
M.CRITICAL_DISPEL_BUFFS = {
    -- Divine Shield (Paladin bubble — immune to all damage)
    [642]  = { name = "Divine Shield",       priority = M.PRIORITY_CRITICAL },
    [1020] = { name = "Divine Shield",       priority = M.PRIORITY_CRITICAL },
    -- Ice Block (Mage — immune to all damage, can be Mass Dispelled)
    [27619] = { name = "Ice Block",          priority = M.PRIORITY_CRITICAL },
    -- Blessing of Protection (Physical immunity)
    [1022]  = { name = "Blessing of Protection", priority = M.PRIORITY_CRITICAL },
    [5599]  = { name = "Blessing of Protection", priority = M.PRIORITY_CRITICAL },
    [10278] = { name = "Blessing of Protection", priority = M.PRIORITY_CRITICAL },
    -- Pain Suppression (-40% damage taken)
    [33206] = { name = "Pain Suppression",    priority = M.PRIORITY_CRITICAL },
}

-- ============================================================================
-- HIGH (Tier 3): Major throughput / fight-swinging buffs
-- ============================================================================
M.HIGH_DISPEL_BUFFS = {
    -- Bloodlust / Heroism
    [2825]  = { name = "Bloodlust",           priority = M.PRIORITY_HIGH },
    [32182] = { name = "Heroism",             priority = M.PRIORITY_HIGH },
    -- Power Infusion (+20% haste)
    [10060] = { name = "Power Infusion",      priority = M.PRIORITY_HIGH },
    -- Innervate (5x mana regen)
    [29166] = { name = "Innervate",           priority = M.PRIORITY_HIGH },
    -- Recklessness (+100% crit, 20s)
    [1719]  = { name = "Recklessness",        priority = M.PRIORITY_HIGH },
    [13847] = { name = "Recklessness",        priority = M.PRIORITY_HIGH },
    -- Arcane Power (+30% damage)
    [12042] = { name = "Arcane Power",        priority = M.PRIORITY_HIGH },
    -- Bestial Wrath (hunter pet immune + 50% dmg)
    [19574] = { name = "Bestial Wrath",       priority = M.PRIORITY_HIGH },
    -- Icy Veins (+20% cast speed)
    [12472] = { name = "Icy Veins",           priority = M.PRIORITY_HIGH },
    -- Adrenaline Rush (+20% attack speed, rogue)
    [13750] = { name = "Adrenaline Rush",     priority = M.PRIORITY_HIGH },
    -- Death Wish (+20% damage, enrage)
    [12292] = { name = "Death Wish",          priority = M.PRIORITY_HIGH },
    -- Blade Flurry (rogue cleave)
    [13877] = { name = "Blade Flurry",        priority = M.PRIORITY_HIGH },
    -- Sweeping Strikes (warrior cleave)
    [12328] = { name = "Sweeping Strikes",    priority = M.PRIORITY_HIGH },
    -- Combat Readiness / Evasion
    [5277]  = { name = "Evasion",             priority = M.PRIORITY_HIGH },
    [26669] = { name = "Evasion",             priority = M.PRIORITY_HIGH },
    -- Barkskin (-20% dmg)
    [22812] = { name = "Barkskin",            priority = M.PRIORITY_HIGH },
    -- Fel Armor (warlock spell power + health generation buff — DBC verified: spell 28176 = Fel Armor Rank 1)
    [28176] = { name = "Fel Armor",            priority = M.PRIORITY_HIGH },
}

-- ============================================================================
-- MEDIUM (Tier 2): Stat / resistance buffs worth stripping
-- ============================================================================
M.MEDIUM_DISPEL_BUFFS = {
    -- Power Word: Fortitude / Prayer of Fortitude
    [25389] = { name = "PW: Fortitude",       priority = M.PRIORITY_MEDIUM },
    [10938] = { name = "PW: Fortitude",       priority = M.PRIORITY_MEDIUM },
    [10937] = { name = "PW: Fortitude",       priority = M.PRIORITY_MEDIUM },
    [25392] = { name = "Prayer of Fortitude", priority = M.PRIORITY_MEDIUM },
    [21564] = { name = "Prayer of Fortitude", priority = M.PRIORITY_MEDIUM },
    [21562] = { name = "Prayer of Fortitude", priority = M.PRIORITY_MEDIUM },
    -- Mark of the Wild / Gift of the Wild
    [26991] = { name = "Mark of the Wild",    priority = M.PRIORITY_MEDIUM },
    [26990] = { name = "Mark of the Wild",    priority = M.PRIORITY_MEDIUM },
    [26989] = { name = "Mark of the Wild",    priority = M.PRIORITY_MEDIUM },
    [26988] = { name = "Gift of the Wild",    priority = M.PRIORITY_MEDIUM },
    [26987] = { name = "Gift of the Wild",    priority = M.PRIORITY_MEDIUM },
    -- Arcane Intellect / Arcane Brilliance
    [27126] = { name = "Arcane Intellect",    priority = M.PRIORITY_MEDIUM },
    [10157] = { name = "Arcane Intellect",    priority = M.PRIORITY_MEDIUM },
    -- Divine Spirit / Prayer of Spirit
    [25312] = { name = "Divine Spirit",       priority = M.PRIORITY_MEDIUM },
    [27841] = { name = "Divine Spirit",       priority = M.PRIORITY_MEDIUM },
    -- Shadow Protection / Prayer of Shadow Protection
    [25433] = { name = "Shadow Protection",   priority = M.PRIORITY_MEDIUM },
    -- Blessing of Kings
    [25898] = { name = "Blessing of Kings",   priority = M.PRIORITY_MEDIUM },
    [25899] = { name = "Blessing of Kings",   priority = M.PRIORITY_MEDIUM },
    -- Blessing of Might / Wisdom / Salvation / Light
    [27140] = { name = "Blessing of Might",   priority = M.PRIORITY_MEDIUM },
    [27143] = { name = "Blessing of Wisdom",  priority = M.PRIORITY_MEDIUM },
    [25895] = { name = "Blessing of Salvation", priority = M.PRIORITY_MEDIUM },
    [27145] = { name = "Blessing of Light",   priority = M.PRIORITY_MEDIUM },
    -- Mage Armor / Molten Armor / Ice Armor
    [27127] = { name = "Mage Armor",          priority = M.PRIORITY_MEDIUM },
    [27125] = { name = "Ice Armor",           priority = M.PRIORITY_MEDIUM },
    -- Demon Armor
    -- NOTE: 28176 is Fel Armor (Rank 1), DBC-verified — NOT Spellstone. An
    -- earlier comment here claimed a 28176 ID conflict between Fel Armor and
    -- Spellstone; that was incorrect (DBC description for 28176 is the Fel
    -- Armor aura). Fel Armor is tracked in HIGH_DISPEL_BUFFS above; Demon
    -- Armor (28189) is tracked here in MEDIUM.
    [28189] = { name = "Demon Armor",         priority = M.PRIORITY_MEDIUM },
    -- Aspect of the Hawk / Aspect of the Wild / Aspect of the Viper
    [27044] = { name = "Aspect of the Hawk",  priority = M.PRIORITY_MEDIUM },
    [27045] = { name = "Aspect of the Wild",  priority = M.PRIORITY_MEDIUM },
    [34074] = { name = "Aspect of the Viper", priority = M.PRIORITY_MEDIUM },
}

-- ============================================================================
-- LOW (Tier 1): Minor buffs — strip when nothing better is available
-- ============================================================================
M.LOW_DISPEL_BUFFS = {
    -- Inner Fire
    [25431] = { name = "Inner Fire",          priority = M.PRIORITY_LOW },
    [10952] = { name = "Inner Fire",          priority = M.PRIORITY_LOW },
    -- Thorns
    [26992] = { name = "Thorns",              priority = M.PRIORITY_LOW },
    [9910]  = { name = "Thorns",              priority = M.PRIORITY_LOW },
    -- Water Breathing / Underwater Breathing
    [7178]  = { name = "Water Breathing",     priority = M.PRIORITY_LOW },
    -- Amplify Magic / Dampen Magic
    [10169] = { name = "Amplify Magic",       priority = M.PRIORITY_LOW },
    [10170] = { name = "Dampen Magic",        priority = M.PRIORITY_LOW },
    -- Detect Invisibility / See Invisibility
    [132]   = { name = "Detect Invisibility", priority = M.PRIORITY_LOW },
    -- Unending Breath
    [5697]  = { name = "Unending Breath",     priority = M.PRIORITY_LOW },
    -- Water Walking
    [546]   = { name = "Water Walking",       priority = M.PRIORITY_LOW },
}

-- ============================================================================
-- Consolidated lookup table (built once at load)
-- ============================================================================
M.ALL_DISPEL_TARGETS = {}
do
    local function merge(t)
        for id, info in pairs(t) do
            M.ALL_DISPEL_TARGETS[id] = info
        end
    end
    merge(M.CRITICAL_DISPEL_BUFFS)
    merge(M.HIGH_DISPEL_BUFFS)
    merge(M.MEDIUM_DISPEL_BUFFS)
    merge(M.LOW_DISPEL_BUFFS)
end

-- ============================================================================
-- API
-- ============================================================================

--- Check if a spell ID is a known priority dispel target.
---@param buff_id number The buff spell ID to check.
---@return boolean is_target True if this buff is worth dispelling.
function M.is_dispel_target(buff_id)
    return M.ALL_DISPEL_TARGETS[buff_id] ~= nil
end

--- Get the priority tier of a buff for dispel targeting.
---@param buff_id number The buff spell ID.
---@return number priority 4=Critical, 3=High, 2=Medium, 1=Low, 0=Not a target.
function M.get_dispel_priority(buff_id)
    local info = M.ALL_DISPEL_TARGETS[buff_id]
    return info and info.priority or 0
end

--- Get the human-readable name of a dispel target buff.
---@param buff_id number The buff spell ID.
---@return string|nil name Buff name, or nil if not a dispel target.
function M.get_dispel_name(buff_id)
    local info = M.ALL_DISPEL_TARGETS[buff_id]
    return info and info.name or nil
end

--- Scan a unit for the highest-priority dispellable buff.
--- Returns the buff ID and its priority, or nil/nil.
---@param unit game_object The unit to scan.
---@param ns table The NS namespace (for buff_up / buff_remains).
---@return number|nil best_id, number|nil best_priority, string|nil best_name
function M.find_best_dispel_target(unit, ns)
    if not unit or not ns or not ns.buff_up then return nil, nil, nil end
    local best_id, best_priority, best_name = nil, 0, nil
    for id, info in pairs(M.ALL_DISPEL_TARGETS) do
        if info.priority > best_priority then
            if ns.buff_up(unit, id) then
                best_id, best_priority, best_name = id, info.priority, info.name
                if best_priority >= M.PRIORITY_CRITICAL then
                    break  -- Critical buff found; stop scanning (bubble/block always wins)
                end
            end
        end
    end
    return best_id, best_priority, best_name
end

--- Check if Mass Dispel should be used on a specific target.
--- Mass Dispel can purge magic buffs that normal Dispel Magic cannot (Divine Shield, Ice Block).
---@param unit game_object The unit to check.
---@param ns table The NS namespace.
---@return boolean should_mass_dispel, string|nil buff_name
function M.should_mass_dispel(unit, ns)
    if not unit or not ns or not ns.buff_up then return false, nil end
    -- Check only Critical tier — Mass Dispel is expensive (36% base mana)
    for id, info in pairs(M.CRITICAL_DISPEL_BUFFS) do
        if ns.buff_up(unit, id) then
            return true, info.name
        end
    end
    return false, nil
end

-- ============================================================================
-- Enemy healer class IDs for Mana Burn targeting
-- ============================================================================
M.HEALER_CLASS_IDS = {
    [2]  = true,  -- Paladin
    [5]  = true,  -- Priest
    [7]  = true,  -- Shaman
    [11] = true,  -- Druid
}

--- Check if a unit is a healer class (for Mana Burn targeting).
---@param unit game_object
---@return boolean is_healer
function M.is_healer_class(unit)
    if not unit then return false end
    local get_class = unit.get_class
    if type(get_class) ~= "function" then return false end
    local ok, class_id = pcall(get_class, unit)
    return ok and M.HEALER_CLASS_IDS[class_id] == true
end

-- ============================================================================
-- Breakable CC debuff IDs for SW:D CC break detection
-- ============================================================================

-- CC types that can be broken by taking damage (SW:D self-damage breaks these)
M.BREAKABLE_CC_DEBUFFS = {
    -- Polymorph variants
    [118]   = { name = "Polymorph",          priority = 9 },
    [12824] = { name = "Polymorph",          priority = 9 },
    [12825] = { name = "Polymorph",          priority = 9 },
    [12826] = { name = "Polymorph",          priority = 9 },
    [28271] = { name = "Polymorph (Turtle)", priority = 9 },
    [28272] = { name = "Polymorph (Pig)",    priority = 9 },
    -- Sap
    [6770]  = { name = "Sap",                priority = 9 },
    [2070]  = { name = "Sap",                priority = 9 },
    [11297] = { name = "Sap",                priority = 9 },
    -- Gouge
    [1776]  = { name = "Gouge",              priority = 8 },
    -- Blind
    [2094]  = { name = "Blind",              priority = 8 },
    -- Freezing Trap
    [3355]  = { name = "Freezing Trap",      priority = 8 },
    [14308] = { name = "Freezing Trap",      priority = 8 },
    [14309] = { name = "Freezing Trap",      priority = 8 },
    -- Repentance
    [20066] = { name = "Repentance",         priority = 7 },
    -- Scatter Shot
    [19503] = { name = "Scatter Shot",       priority = 6 },
    -- Wyvern Sting
    [19386] = { name = "Wyvern Sting",       priority = 7 },
}

-- CC spell casts that can be pre-empted with SW:D
M.PREEMPTIVE_CC_CASTS = {
    [118]   = "Polymorph",     [12824] = "Polymorph",     [12825] = "Polymorph",
    [12826] = "Polymorph",     [28271] = "Polymorph",     [28272] = "Polymorph",
    [5782]  = "Fear",          [6213]  = "Fear",          [6215]  = "HowlOfTerror",
    [5484]  = "HowlOfTerror",  [17928] = "HowlOfTerror",
    [33786] = "Cyclone",       [2637]  = "Hibernate",     [18657] = "Hibernate",
    [18658] = "Hibernate",
    [3355]  = "FreezingTrap",  [14308] = "FreezingTrap",  [14309] = "FreezingTrap",
    [20066] = "Repentance",
}

--- Check if a player is under a damage-breakable CC debuff.
---@param unit game_object The player unit.
---@param ns table The NS namespace.
---@return boolean is_ccd, string|nil cc_name
function M.is_breakable_cc_active(unit, ns)
    if not unit or not ns or not ns.debuff_up then return false, nil end
    for id, info in pairs(M.BREAKABLE_CC_DEBUFFS) do
        if ns.debuff_up(unit, id) then
            return true, info.name
        end
    end
    return false, nil
end

--- Check if any enemy within range is under a damage-breakable CC debuff.
--- Used for PvP CC gating — skip AoE/cleave when a nearby enemy is CC'd.
---@param ns table The NS namespace (needs GetEnemiesInRange + debuff_up).
---@param range number? Scan range in yards (default 15).
---@return boolean is_nearby_ccd, string|nil cc_name
function M.is_any_nearby_enemy_under_cc(ns, range)
    range = range or 15
    if not ns or not ns.GetEnemiesInRange then return false, nil end
    local enemies = ns.GetEnemiesInRange(range)
    if not enemies then return false, nil end
    local scanned = 0
    local MAX_SCAN = 50
    for _, enemy in ipairs(enemies) do
        scanned = scanned + 1
        if scanned > MAX_SCAN then break end
        if enemy then
            local is_ccd, cc_name = M.is_breakable_cc_active(enemy, ns)
            if is_ccd then return true, cc_name end
        end
    end
    return false, nil
end

--- Check if an enemy is casting a spell that CC's the player — for SW:D pre-emptive break.
---@param enemy game_object The enemy unit to check.
---@return boolean is_casting_cc, string|nil cc_spell_name
function M.is_casting_preemptive_cc(enemy)
    if not enemy then return false, nil end
    if not NS or not NS.safe_field then return false, nil end

    -- Try documented base API: get_active_spell_id
    local get_active_spell = NS.safe_field(enemy, "get_active_spell_id")
    if get_active_spell then
        local ok, spell_id = pcall(get_active_spell, enemy)
        if ok and type(spell_id) == "number" and spell_id > 0 then
            local name = M.PREEMPTIVE_CC_CASTS[spell_id]
            if name then return true, name end
        end
    end

    -- Try IZI SDK combined helper: get_active_cast_or_channel_id
    local get_active_cast_channel = NS.safe_field(enemy, "get_active_cast_or_channel_id")
    if get_active_cast_channel then
        local ok, spell_id = pcall(get_active_cast_channel, enemy)
        if ok and type(spell_id) == "number" and spell_id > 0 then
            local name = M.PREEMPTIVE_CC_CASTS[spell_id]
            if name then return true, name end
        end
    end

    -- Fallback: undocumented get_casting_spell_id that some builds still provide
    local get_casting_spell_id = NS.safe_field(enemy, "get_casting_spell_id")
    if type(get_casting_spell_id) ~= "function" then return false, nil end
    local ok, spell_id = pcall(get_casting_spell_id, enemy)
    if not ok or type(spell_id) ~= "number" then return false, nil end
    local name = M.PREEMPTIVE_CC_CASTS[spell_id]
    return name ~= nil, name
end

-- Register with NS namespace for cross-module access
local NS = _G.EaxRotations
if NS then
    NS.OffensiveDispelDB = M
end

return M
