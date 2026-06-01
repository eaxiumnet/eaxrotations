-- Priest leveling priority list
-- ============================================================================
-- Designed for solo/leveling play, from level 1 to 70
-- Handles unlearned spells gracefully via NS.spell_ready checks
-- Uses wand/Shoot as fallback when out of mana
-- Casters default to caster DPS; Shadowform + Mind Flay + VT unlock at higher levels

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PriestSpells or {}
local leveling = require("shared/leveling_sylvanas")

-- ============================================================================
-- Constants
-- ============================================================================
local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local POWER_WORD_FORTITUDE_BUFF = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }
local POWER_WORD_SHIELD_BUFF = { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }
local RENEW_BUFF = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local SHADOWFORM_BUFF = { 15473 }
local VAMPIRIC_TOUCH_DEBUFF = { 34917, 34916, 34914 }
local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local HOLY_FIRE_DOT_DEBUFF = { 25384, 15261, 15267, 15266, 15265, 15264, 15263, 15262, 14914 }
-- Mind Flay mana gate: don't channel if mana is critically low (wand instead)
local MF_MANA_GATE = 12
-- Vampiric Touch refresh window: reapply when debuff has <= this many seconds left
local VT_REFRESH_WINDOW = 3

-- ============================================================================
-- Helper functions
-- ============================================================================

local function spell_ready(spell)
    if not spell then return false end
    local ok, result = pcall(NS.spell_ready, spell)
    return ok and result
end

local function try_cast(spell, target, label)
    if not spell then return false end
    local ok, result = pcall(function()
        return NS.try_cast(spell, target, label)
    end)
    return ok and result
end

local function has_buff(buff_ids)
    if not buff_ids then return false end
    local me = nil
    local ok, result = pcall(function()
        return (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
    end)
    if ok then me = result end
    if not me then return false end
    local ids = type(buff_ids) == "table" and buff_ids or { buff_ids }
    if NS.buff_up then return NS.buff_up(me, ids) end
    return false
end

local function target_creature_type(context, state)
    local ctype = context and context.state and context.state.target_creature_type
    if ctype ~= nil then return ctype end
    local target = (state and state.target) or (context and context.target)
    if target and target.get_creature_type then
        local ok, value = pcall(function() return target:get_creature_type() end)
        if ok then return value end
    end
    return nil
end

local function is_undead_type(ctype)
    return ctype == 6 or ctype == "undead"
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

    -- Shadow spells (level-gated: unlearned → spell_ready returns false)
    state.shadowform_ready = spell_ready(SPELLS.Shadowform)
    state.vt_ready = spell_ready(SPELLS.VampiricTouch)
    state.mf_ready = spell_ready(SPELLS.MindFlay)

    -- Buff/Debuff checks
    state.has_fortitude = has_buff(POWER_WORD_FORTITUDE_BUFF)
    state.has_inner_fire = has_buff(INNER_FIRE_BUFF)
    state.has_shadowform = has_buff(SHADOWFORM_BUFF)
    state.has_shield = has_buff(POWER_WORD_SHIELD_BUFF)
    state.has_renew = has_buff(RENEW_BUFF)
    state.target_creature_type = target_creature_type(context, state)

    -- Vampiric Touch debuff tracking on target
    state.vt_remaining = 0
    if state.target then
        local ok, r = pcall(function() return NS.debuff_remains(state.target, VAMPIRIC_TOUCH_DEBUFF) end)
        if ok then state.vt_remaining = r or 0 end
    end

    -- Channeling state (prevent Mind Flay during another channel)
    state.is_channeling = (context.is_channeling or context.is_casting) or false

    -- Configured thresholds
    state.heal_hp = (context.settings and context.settings.leveling_heal_hp) or 60
    state.wand_threshold = (context.settings and context.settings.leveling_wand_threshold) or 20

    -- Count nearby enemies
    state.enemies = context.enemies_count or 0
    state.hp = context.hp or 100
    state.is_moving = context.is_moving or false

    -- Mana
    state.mana_pct = context.mana_pct or 100

    -- Shadowform toggle setting (default: true = auto-enter Shadowform when available)
    state.use_shadowform = (context.settings and context.settings.leveling_use_shadowform) ~= false

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
    if not state.in_combat then return false end
    if state.has_shield then return false end
    return state.shield_ready and (state.hp or 100) < state.heal_hp
end

local function renew_matches(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if state.has_renew then return false end
    return state.renew_ready and (state.hp or 100) < state.heal_hp
end

local function flash_heal_matches(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    -- Flash Heal when HP is moderate (Greater Heal is for critical HP)
    if (state.hp or 100) >= 50 then return false end
    if (state.hp or 100) < 30 then return false end  -- Use Greater Heal for critical HP
    return state.flash_heal_ready
end

local function heal_matches(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if state.is_moving then return false end
    return state.greater_heal_ready and (state.hp or 100) < state.heal_hp
end

local function inner_focus_matches(context, state)
    if not state then return false end
    if not state.inner_focus_ready then return false end
    -- Use Inner Focus before big heals or mind blast for free cast + crit
    if not state.in_combat then return false end
    if (state.hp or 100) > 50 then return false end  -- Save for when healing is needed
    return true
end

local function scream_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    return state.scream_ready and (state.enemies or 0) >= 3
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
    return is_undead_type(target_creature_type(context, state))
end

local function swp_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.swp_ready then return false end

    -- Refresh if not on target or running out
    local remains = 0
    local ok, r = pcall(function() return NS.debuff_remains(state.target, SHADOW_WORD_PAIN_DEBUFF) end)
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
    local ok, r = pcall(function() return NS.debuff_remains(state.target, HOLY_FIRE_DOT_DEBUFF) end)
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
    return (state.hp or 100) > 60
end

local function holy_nova_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.holy_nova_ready then return false end
    if state.is_moving then return false end
    return (state.enemies or 0) >= 3
end

local function smite_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.smite_ready then return false end
    if state.is_moving then return false end
    return (state.mana_pct or 100) >= state.wand_threshold
end

local function shadowform_matches(context, state)
    if not state then return false end
    if not state.shadowform_ready then return false end
    if not state.use_shadowform then return false end
    return not state.has_shadowform
end

local function vampiric_touch_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.vt_ready then return false end
    if state.is_channeling then return false end
    -- Refresh if debuff is expiring within the refresh window
    return state.vt_remaining <= VT_REFRESH_WINDOW
end

local function mind_flay_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.mf_ready then return false end
    if state.is_moving then return false end
    if state.is_channeling then return false end
    -- Mana gate: don't channel Mind Flay below MF_MANA_GATE % (wand instead)
    return (state.mana_pct or 100) >= MF_MANA_GATE
end

local function wand_matches_fn(context, state)
    if not state then return false end
    if not state.target then return false end
    return (state.mana_pct or 100) < state.wand_threshold
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    {
        name = "PowerWordFortitude",
        matches = fortitude_matches,
        execute = function() return try_cast(SPELLS.PowerWordFortitude, nil, "[LEVELING] Fortitude") end,
    },
    {
        name = "InnerFire",
        matches = inner_fire_matches,
        execute = function() return try_cast(SPELLS.InnerFire, nil, "[LEVELING] Inner Fire") end,
    },
    {
        name = "Shadowform",
        matches = shadowform_matches,
        execute = function() return try_cast(SPELLS.Shadowform, nil, "[LEVELING] Shadowform") end,
    },
    {
        name = "PowerWordShield",
        matches = shield_matches,
        execute = function() return try_cast(SPELLS.PowerWordShield, nil, "[LEVELING] PW:S") end,
    },
    {
        name = "Renew",
        matches = renew_matches,
        execute = function() return try_cast(SPELLS.Renew, nil, "[LEVELING] Renew") end,
    },
    {
        name = "FlashHeal",
        matches = flash_heal_matches,
        execute = function() return try_cast(SPELLS.FlashHeal, nil, "[LEVELING] Flash Heal") end,
    },
    {
        name = "InnerFocus",
        matches = inner_focus_matches,
        execute = function() return try_cast(SPELLS.InnerFocus, nil, "[LEVELING] Inner Focus") end,
    },
    {
        name = "GreaterHeal",
        matches = heal_matches,
        execute = function() return try_cast(SPELLS.GreaterHeal, nil, "[LEVELING] Greater Heal") end,
    },
    {
        name = "PsychicScream",
        matches = scream_matches,
        execute = function() return try_cast(SPELLS.PsychicScream, nil, "[LEVELING] Scream") end,
    },
    {
        name = "Fade",
        matches = fade_matches,
        execute = function() return try_cast(SPELLS.Fade, nil, "[LEVELING] Fade") end,
    },
    {
        name = "ShackleUndead",
        matches = shackle_matches,
        execute = function(context)
            if not context then return false end
            return try_cast(SPELLS.ShackleUndead, context.target, "[LEVELING] Shackle")
        end,
    },
    {
        name = "ShadowWordPain",
        matches = swp_matches,
        execute = function(context)
            if not context then return false end
            return try_cast(SPELLS.ShadowWordPain, context.target, "[LEVELING] SW:Pain")
        end,
    },
    {
        name = "VampiricTouch",
        matches = vampiric_touch_matches,
        execute = function(context)
            if not context then return false end
            return try_cast(SPELLS.VampiricTouch, context.target, "[LEVELING] Vampiric Touch")
        end,
    },
    {
        name = "ShadowWordDeath",
        matches = swd_matches,
        execute = function(context)
            if not context then return false end
            return try_cast(SPELLS.ShadowWordDeath, context.target, "[LEVELING] SW:Death")
        end,
    },
    {
        name = "HolyFire",
        matches = holy_fire_matches,
        execute = function(context)
            if not context then return false end
            return try_cast(SPELLS.HolyFire, context.target, "[LEVELING] Holy Fire")
        end,
    },
    {
        name = "MindBlast",
        matches = mind_blast_matches,
        execute = function(context)
            if not context then return false end
            return try_cast(SPELLS.MindBlast, context.target, "[LEVELING] Mind Blast")
        end,
    },
    {
        name = "MindFlay",
        matches = mind_flay_matches,
        execute = function(context)
            if not context then return false end
            return try_cast(SPELLS.MindFlay, context.target, "[LEVELING] Mind Flay")
        end,
    },
    {
        name = "HolyNova",
        matches = holy_nova_matches,
        execute = function() return try_cast(SPELLS.HolyNova, nil, "[LEVELING] Holy Nova") end,
    },
    {
        name = "Smite",
        matches = smite_matches,
        execute = function(context)
            if not context then return false end
            return try_cast(SPELLS.Smite, context.target, "[LEVELING] Smite")
        end,
    },
    {
        name = "Wand",
        matches = wand_matches_fn,
        execute = function(context)
            if not context then return false end
            return leveling.execute_wand(context)
        end,
    },
}

-- ============================================================================
-- Registration
-- ============================================================================

NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
NS.log("[Priest] Leveling rotation registered")
return strategies
