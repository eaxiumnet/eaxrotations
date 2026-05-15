-- Priest leveling priority list
-- Designed for solo/leveling play, from level 1 to 70
-- Handles unlearned spells gracefully via NS.spell_ready checks
-- Uses wand/Shoot as fallback when out of mana

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PriestSpells or {}
local leveling = require("shared/leveling_sylvanas")

-- ============================================================================
-- Constants
-- ============================================================================
local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local POWER_WORD_FORTITUDE_BUFF = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }

-- ============================================================================
-- Helper functions
-- ============================================================================

local function spell_ready(spell)
    if not spell then return false end
    local ok, result = pcall(NS.spell_ready, spell)
    return ok and result
end

local function try_cast(spell)
    if not spell then return false end
    local ok, result = pcall(function()
        return NS.try_cast(spell)
    end)
    return ok and result
end

local function has_buff(buff_ids)
    if not buff_ids then return false end
    local me = NS.get_local_player()
    if not me then return false end
    local ids = type(buff_ids) == "table" and buff_ids or { buff_ids }
    for _, id in ipairs(ids) do
        local ok, result = pcall(function()
            return me:has_buff(id)
        end)
        if ok and result then return true end
    end
    return false
end

-- ============================================================================
-- State builder
-- ============================================================================

function build_state(context)
    if not context then return nil end

    local state = {}
    leveling.build_common_state(context, state)

    -- Spell readiness
    state.fortitude_ready = spell_ready(SPELLS.PowerWordFortitude)
    state.inner_fire_ready = spell_ready(SPELLS.InnerFire)
    state.shield_ready = spell_ready(SPELLS.PowerWordShield)
    state.renew_ready = spell_ready(SPELLS.Renew)
    state.greater_heal_ready = spell_ready(SPELLS.GreaterHeal)
    state.flash_heal_ready = spell_ready(SPELLS.FlashHeal)
    state.swp_ready = spell_ready(SPELLS.ShadowWordPain)
    state.smite_ready = spell_ready(SPELLS.Smite)
    state.holy_fire_ready = spell_ready(SPELLS.HolyFire)
    state.mind_blast_ready = spell_ready(SPELLS.MindBlast)
    state.swd_ready = spell_ready(SPELLS.ShadowWordDeath)
    state.holy_nova_ready = spell_ready(SPELLS.HolyNova)
    state.scream_ready = spell_ready(SPELLS.PsychicScream)
    state.shackle_ready = spell_ready(SPELLS.ShackleUndead)
    state.fade_ready = spell_ready(SPELLS.Fade)
    state.inner_focus_ready = spell_ready(SPELLS.InnerFocus)

    -- Buff/Debuff checks
    state.has_fortitude = has_buff(POWER_WORD_FORTITUDE_BUFF)
    state.has_inner_fire = has_buff(INNER_FIRE_BUFF)
    state.has_shield = has_buff(SPELLS.PowerWordShield and SPELLS.PowerWordShield[1])
    state.has_renew = has_buff(SPELLS.Renew and SPELLS.Renew[1])

    -- Configured thresholds
    state.heal_hp = (context.settings and context.settings.leveling_heal_hp) or 60
    state.wand_threshold = (context.settings and context.settings.leveling_wand_threshold) or 20

    -- Count nearby enemies
    state.enemies = (context.state and context.state.enemy_count) or 0
    state.hp = (context.state and context.state.hp_pct) or 100
    state.is_moving = (context.state and context.state.is_moving) or false

    -- Mana
    state.mana_pct = (context.state and context.state.mana_pct) or 100

    return state
end

-- ============================================================================
-- Match functions
-- ============================================================================

local function fortitude_matches(context, state)
    if not state then return false end
    if state.in_combat then return false end
    return state.fortitude_ready and not state.has_fortitude
end

local function inner_fire_matches(context, state)
    if not state then return false end
    if state.in_combat then return false end
    return state.inner_fire_ready and not state.has_inner_fire
end

local function shield_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    return state.shield_ready and not state.has_shield and state.hp < state.heal_hp
end

local function renew_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    return state.renew_ready and not state.has_renew and state.hp < state.heal_hp
end

local function heal_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if state.is_moving then return false end
    return state.greater_heal_ready and state.hp < state.heal_hp
end

local function scream_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    return state.scream_ready and state.enemies >= 3
end

local function fade_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.fade_ready then return false end
    if not context.state then return false end
    return (context.state.threat_status or 0) >= 3
end

local function shackle_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.shackle_ready then return false end

    -- Only use on undead targets
    if not context.state or not context.state.target_creature_type then return false end
    return context.state.target_creature_type == "undead"
end

local function swp_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.swp_ready then return false end

    -- Refresh if not on target or running out
    local remains = 0
    local ok, r = pcall(function() return NS.debuff_remains(state.target, SPELLS.ShadowWordPain and SPELLS.ShadowWordPain[1]) end)
    if ok then remains = r or 0 end
    return remains < 4
end

local function holy_fire_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.holy_fire_ready then return false end
    if state.is_moving then return false end

    -- Use on cooldown if not already active
    local remains = 0
    local ok, r = pcall(function() return NS.debuff_remains(state.target, SPELLS.HolyFire and SPELLS.HolyFire[1]) end)
    if ok then remains = r or 0 end
    return remains < 4
end

local function mind_blast_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    return state.mind_blast_ready
end

local function swd_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.swd_ready then return false end
    return state.hp < 35
end

local function holy_nova_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.holy_nova_ready then return false end
    if state.is_moving then return false end
    return state.enemies >= 3
end

local function smite_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.smite_ready then return false end
    if state.is_moving then return false end
    return state.mana_pct >= state.wand_threshold
end

local function wand_matches_fn(context, state)
    if not state then return false end
    if not state.target then return false end
    return state.mana_pct < state.wand_threshold
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    {
        name = "PowerWordFortitude",
        matches = fortitude_matches,
        execute = function() return try_cast(SPELLS.PowerWordFortitude) end,
    },
    {
        name = "InnerFire",
        matches = inner_fire_matches,
        execute = function() return try_cast(SPELLS.InnerFire) end,
    },
    {
        name = "PowerWordShield",
        matches = shield_matches,
        execute = function() return try_cast(SPELLS.PowerWordShield) end,
    },
    {
        name = "Renew",
        matches = renew_matches,
        execute = function() return try_cast(SPELLS.Renew) end,
    },
    {
        name = "GreaterHeal",
        matches = heal_matches,
        execute = function() return try_cast(SPELLS.GreaterHeal) end,
    },
    {
        name = "PsychicScream",
        matches = scream_matches,
        execute = function() return try_cast(SPELLS.PsychicScream) end,
    },
    {
        name = "Fade",
        matches = fade_matches,
        execute = function() return try_cast(SPELLS.Fade) end,
    },
    {
        name = "ShackleUndead",
        matches = shackle_matches,
        execute = function() return try_cast(SPELLS.ShackleUndead) end,
    },
    {
        name = "ShadowWordPain",
        matches = swp_matches,
        execute = function() return try_cast(SPELLS.ShadowWordPain) end,
    },
    {
        name = "ShadowWordDeath",
        matches = swd_matches,
        execute = function() return try_cast(SPELLS.ShadowWordDeath) end,
    },
    {
        name = "HolyFire",
        matches = holy_fire_matches,
        execute = function() return try_cast(SPELLS.HolyFire) end,
    },
    {
        name = "MindBlast",
        matches = mind_blast_matches,
        execute = function() return try_cast(SPELLS.MindBlast) end,
    },
    {
        name = "HolyNova",
        matches = holy_nova_matches,
        execute = function() return try_cast(SPELLS.HolyNova) end,
    },
    {
        name = "Smite",
        matches = smite_matches,
        execute = function() return try_cast(SPELLS.Smite) end,
    },
    {
        name = "Wand",
        matches = wand_matches_fn,
        execute = function(context) return leveling.execute_wand(context) end,
    },
}

-- ============================================================================
-- Registration
-- ============================================================================

NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
NS.log("[Priest] Leveling rotation registered")
return strategies
