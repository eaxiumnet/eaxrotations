-- ============================================================================
-- Priest Smite DPS Rotation
-- Holy DPS with Shadow Weaving/Misery utility via SW:P
-- Holy Fire Weave optimization, Surge of Light procs
-- ============================================================================
-- Readability notes:
--   What: Smite-oriented Priest damage playstyle with light utility support.
--   When: selected as an offensive Priest playstyle instead of a healing lane.
--   Why: keeps Holy DPS behavior separate from Shadow and healer priorities.
--   Safety: damage actions pass shared spell, mana, target, and aura gates before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local _G = _G
local NS = _G.EaxRotations
if not NS then return end


local load_player = NS.GetPlayer()

local enums = require("common/enums")
if type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
if not load_player or load_player:get_class() ~= enums.class_id.PRIEST then return end

-- Cache player race at load for racial spell gating (Night Elf = 4, Undead = 5)
local _player_race = load_player:get_race_id() or 0
local _is_night_elf = _player_race == 4
local _is_undead = _player_race == 5

local SPELLS = NS.PriestSpells

local format = string.format

local PLAYER_UNIT = NS.PLAYER_UNIT

-- Debuff / Buff IDs
local SHADOW_WORD_PAIN_DEBUFF = 589
local DEVOURING_PLAGUE_DEBUFF = { 2944, 19276, 19277, 19278, 19279, 19280, 25467 }
local SURGE_OF_LIGHT_BUFF = 33151
local INNER_FOCUS_BUFF = 14751

-- Base cast times with Divine Fury talent: Smite 2.0s, Holy Fire 3.0s
local SMITE_CAST_BASE = 2.0
local HF_CAST_BASE = 3.0

-- Shared helpers from core_sylvanas.lua
local try_cast, spell_exists, spell_ready, debuff_remains, buff_up, health_pct, player_control_locked = NS.import_helpers(
    "try_cast", "spell_exists", "spell_ready", "debuff_remains", "buff_up", "health_pct",
    "player_control_locked"
)

-- ============================================================================
-- SMITE STATE (per-frame cache)
-- ============================================================================
local smite_state = {
    swp_active = false,
    swp_remaining = 0,
    surge_of_light = false,
    hf_ready = false,
    mb_ready = false,
    swd_ready = false,
    swd_safe = false,
    in_weave_window = false,
    dp_remaining = 0,
    has_inner_focus = false,
    inner_focus_ready = false,
    hp_pct = 100,
}

local function build_smite_state(context)
    local target = context.target
    local player = NS.GetPlayer()

    context.player_control_locked = player_control_locked()
    context.is_moving = context.is_moving or (player.is_moving and player:is_moving()) or false
    context.mana_pct = context.player_mana_pct or (player.mana_pct and player:mana_pct()) or 100
    context.hp = health_pct(NS.PLAYER_UNIT)

    local swp_dur = target and debuff_remains(target, SHADOW_WORD_PAIN_DEBUFF) or 0
    smite_state.swp_active = swp_dur > 0
    smite_state.swp_remaining = swp_dur
    smite_state.surge_of_light = buff_up(NS.PLAYER_UNIT, SURGE_OF_LIGHT_BUFF)
    smite_state.hf_ready = spell_exists(SPELLS.HolyFire) and spell_ready(SPELLS.HolyFire, target)
    smite_state.mb_ready = spell_exists(SPELLS.MindBlast) and spell_ready(SPELLS.MindBlast, target)
    smite_state.swd_ready = spell_exists(SPELLS.ShadowWordDeath) and spell_ready(SPELLS.ShadowWordDeath, target)
    smite_state.swd_safe = context.hp > (context.settings.smite_swd_hp or 40)
    smite_state.dp_remaining = target and debuff_remains(target, DEVOURING_PLAGUE_DEBUFF) or 0
    smite_state.has_inner_focus = buff_up(NS.PLAYER_UNIT, INNER_FOCUS_BUFF)
    smite_state.inner_focus_ready = spell_exists(SPELLS.InnerFocus) and spell_ready(SPELLS.InnerFocus, NS.PLAYER_UNIT)
    smite_state.hp_pct = context.hp

    -- Holy Fire Weave window: SW:P will fall off during HF cast but NOT during Smite cast
    smite_state.in_weave_window = smite_state.swp_active
        and swp_dur > SMITE_CAST_BASE
        and swp_dur < HF_CAST_BASE

    return smite_state
end

local function can_take_smite_action(context)
    if not context then return NS.match_fail("no_context") end
    if not context.has_valid_enemy_target then return NS.match_fail("no_valid_target") end
    if context.player_control_locked then return NS.match_fail("ctrl_locked") end
    if context.target_phys_immune then return NS.match_fail("phys_immune") end
    return true
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
local strategies = {
    -- [1] Shadow Word: Pain (maintain for Shadow Weaving + Misery)
    {
        name = "ShadowWordPain",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if state.swp_active then return false end
            if context.ttd > 0 and context.ttd < 6 then return false end
            return spell_exists(SPELLS.ShadowWordPain) and spell_ready(SPELLS.ShadowWordPain, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.ShadowWordPain, context.target, "[SMITE] SW:P")
        end,
    },

    -- [2] Starshards (Night Elf racial)
    {
        name = "Starshards",
        matches = function(context)
            if not _is_night_elf then return false end
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.settings.smite_use_starshards == false then return false end
            return spell_exists(SPELLS.Starshards) and spell_ready(SPELLS.Starshards, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.Starshards, context.target, "[SMITE] Starshards")
        end,
    },

    -- [3] Devouring Plague (Undead racial)
    {
        name = "DevouringPlague",
        matches = function(context, state)
            if not _is_undead then return false end
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.settings.smite_use_devouring_plague == false then return false end
            if context.ttd > 0 and context.ttd < 8 then return false end
            if state.dp_remaining > 3 then return false end
            return spell_exists(SPELLS.DevouringPlague) and spell_ready(SPELLS.DevouringPlague, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.DevouringPlague, context.target, "[SMITE] Devouring Plague")
        end,
    },

    -- [4] Mind Blast (optional, setting-gated)
    {
        name = "MindBlast",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.settings.smite_use_mb == false then return false end
            if context.is_moving then return false end
            return state.mb_ready
        end,
        execute = function(context)
            return try_cast(SPELLS.MindBlast, context.target, "[SMITE] Mind Blast")
        end,
    },

    -- [5] Shadow Word: Death (optional, HP-gated)
    {
        name = "ShadowWordDeath",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.settings.smite_use_swd == false then return false end
            if not state.swd_safe then return false end
            return state.swd_ready
        end,
        execute = function(context, state)
            return try_cast(SPELLS.ShadowWordDeath, context.target,
                format("[SMITE] SW:D HP: %.0f%%", context.hp or 0))
        end,
    },

    -- [6] Surge of Light Smite (instant free Smite proc)
    {
        name = "SurgeOfLightSmite",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            return state.surge_of_light
        end,
        execute = function(context)
            return try_cast(SPELLS.Smite, context.target, "[SMITE] Surge of Light Smite (instant)")
        end,
    },

    -- [7] Holy Fire Weave (HF off CD + in weave window)
    {
        name = "HolyFireWeave",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.settings.smite_holy_fire_weave == false then return false end
            if context.is_moving then return false end
            if not state.hf_ready then return false end
            return state.in_weave_window
        end,
        execute = function(context, state)
            return try_cast(SPELLS.HolyFire, context.target,
                format("[SMITE] HF Weave SW:P rem: %.1fs", state.swp_remaining))
        end,
    },

    -- [8] Holy Fire (off CD, normal priority outside weave window)
    {
        name = "HolyFire",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.is_moving then return false end
            -- If weave mode is on and we're in the weave window, skip (handled by HolyFireWeave above)
            if context.settings.smite_holy_fire_weave ~= false and state.in_weave_window then return false end
            return state.hf_ready
        end,
        execute = function(context)
            return try_cast(SPELLS.HolyFire, context.target, "[SMITE] Holy Fire")
        end,
    },

    -- [8.5] Inner Focus (off-GCD, pair with Holy Fire or Mind Blast)
    {
        name = "InnerFocus",
        is_gcd_gated = false,
        is_burst = true,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.settings.smite_use_inner_focus == false then return false end
            if state.has_inner_focus then return false end
            if not state.inner_focus_ready then return false end
            -- Pair with HF or MB for max value
            return state.hf_ready or state.mb_ready
        end,
        execute = function()
            return try_cast(SPELLS.InnerFocus, PLAYER_UNIT, "[SMITE] Inner Focus")
        end,
    },

    -- [9] Racial (off-GCD)    -- [11] Smite (filler)
    {
        name = "SmiteFiller",
        matches = function(context)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.is_moving then return false end
            return spell_exists(SPELLS.Smite) and spell_ready(SPELLS.Smite, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.Smite, context.target, "[SMITE] Smite")
        end,
    },
}

NS.rotation_registry:register("smite", strategies, {
    get_state = build_smite_state,
    format_context_log = function(context, state)
        return format(
            "swp=%.1f surge=%s hf=%s mb=%s swd=%s weave=%s dp=%.1f if=%s hp=%.0f mana=%.0f",
            state.swp_remaining or 0,
            tostring(state.surge_of_light),
            tostring(state.hf_ready),
            tostring(state.mb_ready),
            tostring(state.swd_ready),
            tostring(state.in_weave_window),
            state.dp_remaining or 0,
            tostring(state.has_inner_focus),
            state.hp_pct or 0,
            context.mana_pct or 0
        )
    end,
})

NS.log("Smite priest rotation registered (11 strategies)")
return strategies
