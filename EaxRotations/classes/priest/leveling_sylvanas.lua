-- leveling_sylvanas -- priest leveling_sylvanas rotation for TBC Anniversary (2.5.5).

-- WHAT:  priority-list strategies for leveling_sylvanas gameplay.

-- WHEN:  combat with valid enemy target (or healing context for healers).

-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.

-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no manual nil-guards; no on_update() allocs.



-- Priest leveling priority list

-- ============================================================================

-- Designed for solo/leveling play, from level 1 to 70

-- Handles unlearned spells gracefully via NS.spell_ready checks

-- Uses wand/Shoot as fallback when out of mana

-- Casters default to caster DPS; Shadowform + Mind Flay + VT unlock at higher levels



local NS = _G.EaxRotations

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

if not NS then return nil end

local SPELLS = NS.PriestSpells or {}

local leveling = require("shared/leveling_sylvanas")

local spec_kit = require("shared/spec_kit_sylvanas")



-- ============================================================================

-- Constants

-- ============================================================================

local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }

local _rbf_ok, RBF = pcall(require, "shared/ranked_buff_families_sylvanas")
-- PoF first (superior), then PW:F ranks (Vanilla∪TBC∪WotLK).
local POWER_WORD_FORTITUDE_BUFF = (_rbf_ok and RBF and RBF.detect("power_word_fortitude")) or { 25392, 21564, 21562, 39231, 25389, 10938, 10937, 2791, 1245, 1244, 1243 }

local POWER_WORD_SHIELD_BUFF = { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }

local RENEW_BUFF = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }

local SHADOWFORM_BUFF = { 15473 }

local VAMPIRIC_TOUCH_DEBUFF = { 34917, 34916, 34914 }

local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }

local VAMPIRIC_EMBRACE_BUFF = { 15286 }

local VAMPIRIC_EMBRACE_DEBUFF = { 15286 }

local INNER_FOCUS_BUFF = { 14751 }

-- Mind Flay mana gate: don't channel if mana is critically low (wand instead)

local MF_MANA_GATE = 12

-- Vampiric Touch refresh window: reapply when debuff has <= this many seconds left

local VT_REFRESH_WINDOW = 3

-- Shadowfiend default mana threshold (overridden by settings.shadowfiend_mana_threshold)

local SHADOWFIEND_MANA_DEFAULT = 30

-- Desperate Prayer default HP threshold (overridden by settings.leveling_desp_prayer_hp)

local DESPERATE_PRAYER_HP_DEFAULT = 35

-- VE resume window: re-cast Vampiric Embrace when target debuff is below this many seconds

local VE_RESUME_WINDOW = 5



-- ============================================================================

-- Helper functions

-- ============================================================================



local function spell_ready(spell)

    if not spell then return false end

    -- Pass player as target + skip_range=true so spell_helper_castable doesn't

    -- bail on nil target (core_sylvanas.lua:2521). We only need to know the

    -- spell is learned/available/off-cooldown, not whether it's in range.

    local player = NS.GetPlayer and NS.GetPlayer()

    local ok, result = pcall(NS.spell_ready, spell, player, { skip_range = true })

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

    if NS.buff_up then

        local ok, result = pcall(NS.buff_up, me, ids)

        if ok then return result end

    end

    return false

end



local function target_creature_type(context, state)

    -- context.target_creature_type no longer exists; query target directly.

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

    state.mind_blast_ready = spell_ready(SPELLS.MindBlast)

    state.desperate_prayer_ready = spell_ready(SPELLS.DesperatePrayer)

    state.swd_ready = spell_ready(SPELLS.ShadowWordDeath)

    state.holy_nova_ready = spell_ready(SPELLS.HolyNova)

    state.scream_ready = spell_ready(SPELLS.PsychicScream)

    state.shackle_ready = spell_ready(SPELLS.ShackleUndead)

    state.fade_ready = spell_ready(SPELLS.Fade)

    state.symbol_of_hope_ready = spell_ready(SPELLS.SymbolOfHope)

    state.inner_focus_ready = spell_ready(SPELLS.InnerFocus)



    -- Shadow spells (level-gated: unlearned → spell_ready returns false)

    state.shadowform_ready = spell_ready(SPELLS.Shadowform)

    state.vt_ready = spell_ready(SPELLS.VampiricTouch)

    state.mf_ready = spell_ready(SPELLS.MindFlay)

    state.shadowfiend_ready = spell_ready(SPELLS.Shadowfiend)

    state.vampiric_embrace_ready = spell_ready(SPELLS.VampiricEmbrace)



    -- Buff/Debuff checks

    state.has_fortitude = has_buff(POWER_WORD_FORTITUDE_BUFF)

    state.has_inner_fire = has_buff(INNER_FIRE_BUFF)

    state.has_shadowform = has_buff(SHADOWFORM_BUFF)

    state.has_shield = has_buff(POWER_WORD_SHIELD_BUFF)

    state.has_renew = has_buff(RENEW_BUFF)




    -- Vampiric Touch debuff tracking on target

    state.vt_remaining = 0

    if state.target then

        local ok, r = pcall(function() return NS.debuff_remains(state.target, VAMPIRIC_TOUCH_DEBUFF) end)

        if ok then state.vt_remaining = r or 0 end

    end



    -- Target HP tracking (for SW:D execute gate)

    state.target_hp_pct = 100

    if state.target then

        local ok, pct = pcall(function() return state.target:get_health_percentage() end)

        if ok and type(pct) == "number" then state.target_hp_pct = pct end

    end



    -- Vampiric Embrace self-buff tracking + target debuff tracking

    state.has_vampiric_embrace = has_buff(VAMPIRIC_EMBRACE_BUFF)

    state.ve_remaining = 0

    if state.target then

        local ok, r = pcall(function() return NS.debuff_remains(state.target, VAMPIRIC_EMBRACE_DEBUFF) end)

        if ok then state.ve_remaining = r or 0 end

    end



    -- Inner Focus buff tracking

    state.has_inner_focus = has_buff(INNER_FOCUS_BUFF)



    -- Channeling state (prevent Mind Flay during another channel)

    state.is_channeling = (context.is_channeling or context.is_casting) or false



    -- Configured thresholds

    state.heal_hp = spec_kit.setting_number(context, "leveling_heal_hp", 60)

    state.wand_threshold = spec_kit.setting_number(context, "leveling_wand_threshold", 30)



    -- Count nearby enemies

    state.enemies = context.enemies_count or 0

    state.hp = context.hp or 100

    state.is_moving = context.is_moving or false



    -- Mana

    state.mana_pct = context.mana_pct or 100



    -- Shadowform toggle setting (default: true = auto-enter Shadowform when available)

    state.use_shadowform = spec_kit.setting_bool(context, "leveling_use_shadowform", true)



    -- Shadowfiend settings (schema_sylvanas.lua lines 31-32)

    state.use_shadowfiend = spec_kit.setting_bool(context, "use_shadowfiend", true)

    state.shadowfiend_mana_threshold = spec_kit.setting_number(context, "shadowfiend_mana_threshold", SHADOWFIEND_MANA_DEFAULT)



    -- Desperate Prayer settings (schema_sylvanas.lua lines 103-104)

    state.use_desperate_prayer = spec_kit.setting_bool(context, "leveling_use_desperate_prayer", true)

    state.desp_prayer_hp = spec_kit.setting_number(context, "leveling_desp_prayer_hp", DESPERATE_PRAYER_HP_DEFAULT)
    state.auto_inner_fire = spec_kit.setting_bool(context, "auto_inner_fire", true)
    state.auto_fortitude = spec_kit.setting_bool(context, "auto_fortitude", true)



    return spec_kit.safe_state(state)

end



-- ============================================================================

-- Match functions

-- ============================================================================



local function fortitude_matches(context, state)

    if not state then return false end
    if not state.auto_fortitude then return false end

    if state.in_combat then return false end

    return state.fortitude_ready and not state.has_fortitude

end



local function inner_fire_matches(context, state)

    if not state then return false end
    if not state.auto_inner_fire then return false end

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



local function inner_focus_heal_matches(context, state)

    if not state then return false end

    if not state.inner_focus_ready then return false end

    if not state.in_combat then return false end

    if state.has_inner_focus then return false end

    -- Use before big heals when self HP is low

    if (state.hp or 100) > 50 then return false end

    return state.greater_heal_ready or state.flash_heal_ready

end



local function inner_focus_mind_blast_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.inner_focus_ready then return false end

    if not state.in_combat then return false end

    if state.has_inner_focus then return false end

    if not state.mind_blast_ready then return false end

    -- Don't burn IF if mana is too low for MB to fire

    if (state.mana_pct or 100) < state.wand_threshold then return false end

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

    -- context.threat_pct is 0-100; >= 99 = drawn aggro (threat zone 3, with float safety margin)

    return (context.threat_pct or 0) >= 99

end



local function shackle_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.shackle_ready then return false end

    if state.target and NS.debuff_up and NS.debuff_up(state.target, {9484, 9485, 10955}) then return false end



    -- Only use on undead targets

    return is_undead_type(target_creature_type(context, state))

end



local function desperate_prayer_matches(context, state)

    if not state then return false end

    if not state.desperate_prayer_ready then return false end

    if not state.use_desperate_prayer then return false end

    if not state.in_combat then return false end

    -- Panic-button self heal: fire only when HP is critical (threshold from settings)

    return (state.hp or 100) < (state.desp_prayer_hp or DESPERATE_PRAYER_HP_DEFAULT)

end



local function swp_matches(context, state)

    if not state then return false end

    if not state.in_combat then return false end

    if not state.target then return false end

    if not state.swp_ready then return false end

    -- Mana gate: don't cast SW:P below wand threshold (wand instead)

    if (state.mana_pct or 100) < state.wand_threshold then return false end



    -- Refresh if not on target or running out

    local remains = 0

    local ok, r = pcall(function() return NS.debuff_remains(state.target, SHADOW_WORD_PAIN_DEBUFF) end)

    if ok then remains = r or 0 end

    return remains < 4

end



local function mind_blast_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.mind_blast_ready then return false end

    -- Mana gate: drop MB below wand threshold (matches Shadow spec shadow_mb_mana_floor pattern)

    if (state.mana_pct or 100) < state.wand_threshold then return false end

    return true

end



local function swd_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.swd_ready then return false end

    if (state.hp or 100) <= 60 then return false end

    return (state.target_hp_pct or 100) <= 25

end



local function holy_nova_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.holy_nova_ready then return false end

    if state.is_moving then return false end

    if state.has_shadowform then return false end

    -- Holy Nova: 10yd self PBAoE — not global enemies density
    return NS.aoe_self_meets and NS.aoe_self_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, state)

end



local function smite_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.smite_ready then return false end

    if state.is_moving then return false end

    if state.has_shadowform then return false end

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

    -- Mana gate: don't reapply VT below wand threshold (wand instead)

    if (state.mana_pct or 100) < state.wand_threshold then return false end

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



local function vampiric_embrace_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.vampiric_embrace_ready then return false end

    -- Cast if self-buff missing OR target debuff is expiring within resume window

    if not state.has_vampiric_embrace then return true end

    return state.ve_remaining <= VE_RESUME_WINDOW

end



local function shadowfiend_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.shadowfiend_ready then return false end

    if not state.use_shadowfiend then return false end

    if state.is_channeling then return false end

    -- Mana gate: summon Shadowfiend when below configured threshold (default 30%)

    return (state.mana_pct or 100) <= state.shadowfiend_mana_threshold

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

        name = "InnerFocusHeal",

        matches = inner_focus_heal_matches,

        execute = function() return try_cast(SPELLS.InnerFocus, nil, "[LEVELING] Inner Focus (heal)") end,

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

        name = "DesperatePrayer",

        matches = desperate_prayer_matches,

        execute = function() return try_cast(SPELLS.DesperatePrayer, nil, "[LEVELING] Desperate Prayer") end,

    },

    {

        name = "VampiricEmbrace",

        matches = vampiric_embrace_matches,

        execute = function(context)

            if not context then return false end

            return try_cast(SPELLS.VampiricEmbrace, context.target, "[LEVELING] Vampiric Embrace")

        end,

    },

    {

        name = "Shadowfiend",

        matches = shadowfiend_matches,

        execute = function(context)

            if not context then return false end

            return try_cast(SPELLS.Shadowfiend, context.target, "[LEVELING] Shadowfiend")

        end,

    },

    {

        name = "InnerFocusMindBlast",

        matches = inner_focus_mind_blast_matches,

        execute = function() return try_cast(SPELLS.InnerFocus, nil, "[LEVELING] Inner Focus (MB)") end,

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

            local ok, result = pcall(leveling.execute_wand, context)

            return ok and (result == true) or false

        end,

    },

    {

        name = "SymbolOfHope",

        matches = function(context, state)

            if not state then return false end

            if not state.symbol_of_hope_ready then return false end

            local group_aware = spec_kit.setting_bool(context, "priest_group_aware_utility", true)
            if group_aware and not context.is_group then return false end

            if not spec_kit.setting_bool(context, "use_symbol_of_hope", true) then return false end

            if state.in_combat and (state.mana_pct or 100) < 20 then return false end

            return true

        end,

        execute = function()

            return try_cast(SPELLS.SymbolOfHope, nil, "[LEVELING] Symbol of Hope")

        end,

    },

}



-- ============================================================================

-- Registration

-- ============================================================================



if NS.rotation_registry and NS.rotation_registry.register then

    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })

end

-- [Priest] Leveling rotation registered

return { strategies = strategies, build_state = build_state }