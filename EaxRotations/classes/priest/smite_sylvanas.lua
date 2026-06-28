-- smite_sylvanas.lua -- Priest Holy DPS for TBC Anniversary (2.5.5).
-- WHAT:  holy damage spec (Holy Fire, Smite, Surge of Light, Power Infusion).
-- WHEN:  combat, with valid enemy target.
-- WHY:   niche TBC build: Holy Fire > Surge-of-Light Smite > SW:P > Mind Blast.
-- SAFETY: all state fields nil-guarded via build_state() defaults; no on_update() allocs.
local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local load_player = NS.GetPlayer and NS.GetPlayer()

local _ok_enums, enums = pcall(require, "common/enums")
if not _ok_enums or type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
if not load_player then return end
local ok_cls, cls_id = pcall(function() return load_player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.PRIEST then return end

-- Cache player race at load for racial spell gating (Night Elf = 4, Undead = 5)
local _player_race = load_player:get_race_id() or 0
local _is_night_elf = _player_race == 4
local _is_undead = _player_race == 5

local SPELLS = NS.PriestSpells

local format = string.format

local PLAYER_UNIT = NS.PLAYER_UNIT

-- Debuff / Buff IDs
local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local DEVOURING_PLAGUE_DEBUFF = { 2944, 19276, 19277, 19278, 19279, 19280, 25467 }
local SURGE_OF_LIGHT_BUFF = 33151
local INNER_FOCUS_BUFF = 14751
local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local RENEW_BUFF = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local WEAKENED_SOUL_DEBUFF = { 6788 }

-- Base cast times with Divine Fury talent: Smite 2.0s, Holy Fire 3.0s
local SMITE_CAST_BASE = 2.0
local HF_CAST_BASE = 3.0
local EMPTY_SETTINGS = {}
local SKIP_RANGE = { skip_range = true }
local PSYCHIC_SCREAM_OPTS = { skip_range = true, expected_cooldown = 30 }
local SHADOWFIEND_OPTS = { expected_cooldown = 300 }

-- Shared helpers from core_sylvanas.lua
local try_cast, spell_exists, spell_ready, debuff_remains, buff_up, buff_remains, health_pct, player_control_locked = NS.import_helpers(
    "try_cast", "spell_exists", "spell_ready", "debuff_remains", "buff_up", "buff_remains", "health_pct",
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
    has_inner_fire = false,
    inner_fire_remains = 0,
    has_renew = false,
    has_weakened_soul = false,
    inner_focus_ready = false,
    inner_fire_ready = false,
    power_word_shield_ready = false,
    renew_ready = false,
    psychic_scream_ready = false,
    shadowfiend_ready = false,
    hp_pct = 100,
    mana_pct = 100,
    mana_emergency = false,
    mana_low = false,
    threat_safe = true,
    enemy_count = 1,
}

local function build_smite_state(context)
    context.settings = context.settings or EMPTY_SETTINGS
    local target = context.target
    local player = NS.GetPlayer()

    context.player_control_locked = player_control_locked()
    context.is_moving = context.is_moving or (player.is_moving and player:is_moving()) or false
    context.mana_pct = context.mana_pct or context.player_mana_pct or (player.mana_pct and player:mana_pct()) or 100
    context.hp = health_pct(NS.PLAYER_UNIT)

    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(14752, 3.0) or false
    if not skip_aura then
        local swp_dur = target and debuff_remains(target, SHADOW_WORD_PAIN_DEBUFF) or 0
        smite_state.swp_active = swp_dur > 0
        smite_state.swp_remaining = swp_dur
        smite_state.surge_of_light = buff_up(NS.PLAYER_UNIT, SURGE_OF_LIGHT_BUFF)
        smite_state.dp_remaining = target and debuff_remains(target, DEVOURING_PLAGUE_DEBUFF) or 0
        smite_state.has_inner_focus = buff_up(NS.PLAYER_UNIT, INNER_FOCUS_BUFF)
        smite_state.has_inner_fire = buff_up(NS.PLAYER_UNIT, INNER_FIRE_BUFF)
        smite_state.inner_fire_remains = 0
        if smite_state.has_inner_fire and type(buff_remains) == "function" then
            local r = buff_remains(NS.PLAYER_UNIT, INNER_FIRE_BUFF)
            smite_state.inner_fire_remains = (r ~= nil and r >= 0) and r or 999
        end
        smite_state.has_renew = buff_up(NS.PLAYER_UNIT, RENEW_BUFF)
        smite_state.has_weakened_soul = NS.debuff_up and NS.debuff_up(NS.PLAYER_UNIT, WEAKENED_SOUL_DEBUFF) or false
    end
    smite_state.hf_ready = spell_exists(SPELLS.HolyFire) and spell_ready(SPELLS.HolyFire, target)
    smite_state.mb_ready = spell_exists(SPELLS.MindBlast) and spell_ready(SPELLS.MindBlast, target)
    smite_state.swd_ready = spell_exists(SPELLS.ShadowWordDeath) and spell_ready(SPELLS.ShadowWordDeath, target)
    smite_state.swd_safe = context.hp > (context.settings.smite_swd_hp or 40)
    smite_state.inner_focus_ready = spell_exists(SPELLS.InnerFocus) and spell_ready(SPELLS.InnerFocus, NS.PLAYER_UNIT)
    smite_state.inner_fire_ready = spell_exists(SPELLS.InnerFire) and spell_ready(SPELLS.InnerFire, NS.PLAYER_UNIT, SKIP_RANGE)
    smite_state.power_word_shield_ready = spell_exists(SPELLS.PowerWordShield) and spell_ready(SPELLS.PowerWordShield, NS.PLAYER_UNIT, SKIP_RANGE)
    smite_state.renew_ready = spell_exists(SPELLS.Renew) and spell_ready(SPELLS.Renew, NS.PLAYER_UNIT, SKIP_RANGE)
    smite_state.psychic_scream_ready = spell_exists(SPELLS.PsychicScream) and spell_ready(SPELLS.PsychicScream, NS.PLAYER_UNIT, PSYCHIC_SCREAM_OPTS)
    smite_state.shadowfiend_ready = spell_exists(SPELLS.Shadowfiend) and spell_ready(SPELLS.Shadowfiend, target, SHADOWFIEND_OPTS)
    smite_state.hp_pct = context.hp or 100
    smite_state.is_group = context.is_group or false
    smite_state.mana_pct = context.mana_pct or 100
    smite_state.enemy_count = context.enemy_count or context.enemies_count or 1

    -- Mana conservation tiers (Research: <30% downrank, <15% HF only, <5% wand only)
    smite_state.mana_low = smite_state.mana_pct < (context.settings.smite_mana_floor or 30)
    smite_state.mana_emergency = smite_state.mana_pct < (context.settings.smite_wand_floor or 5)

    -- Threat safety (NS.is_threat_safe when available)
    smite_state.threat_safe = type(NS.is_threat_safe) == "function" and NS.is_threat_safe() or true

    -- Holy Fire Weave window: SW:P will fall off during HF cast but NOT during Smite cast
    smite_state.in_weave_window = smite_state.swp_active
        and swp_dur > SMITE_CAST_BASE
        and swp_dur < HF_CAST_BASE

    return smite_state
end

local function solo_like_context(context)
    return context.is_solo == true or context.is_leveling == true or context.is_pvp == true
end

local function group_is_stable(context)
    if not context then return false end
    local lowest = (context.lowest_ally_hp or context.lowest_group_hp or 100)
    return lowest >= ((context.settings or EMPTY_SETTINGS).smite_group_safe_hp or 80)
end

local function can_take_smite_action(context)
    if not context then return false end
    context.settings = context.settings or EMPTY_SETTINGS
    if not context.has_valid_enemy_target then return false end
    if context.player_control_locked then return false end
    if (context.target_phys_immune or false) then return false end
    return true
end

-- ============================================================================
-- STRATEGIES
-- Note: Priority order per Research.md — Holy Fire on CD first, then Surge of Light,
-- then DoTs, then racials, then optional shadow spells, then Smite filler.
-- Mana conservation: <30% gates optional spells, <5% wand-only.
-- ============================================================================
local strategies = {
    -- [0.1] Inner Fire maintenance (always, all modes).
    -- Research: "Must maintain Inner Fire [25431] uptime; re-cast when < 5s remains."
    {
        name = "InnerFire",
        matches = function(context, state)
            if context.player_control_locked then return false end
            if not state.inner_fire_ready then return false end
            -- Always maintain; refresh when < 5s remains
            if state.has_inner_fire and state.inner_fire_remains > 5 then return false end
            return true
        end,
        execute = function(context, state)
            local tag = state.has_inner_fire
                and format("[SMITE] Inner Fire refresh (%.0fs)", state.inner_fire_remains)
                or "[SMITE] Inner Fire"
            return try_cast(SPELLS.InnerFire, PLAYER_UNIT, tag)
        end,
    },

    -- [0.2] Solo/leveling/PvP self shield before hard-casting damage.
    {
        name = "SoloPowerWordShield",
        matches = function(context, state)
            if context.player_control_locked then return false end
            if not solo_like_context(context) then return false end
            if state.has_weakened_soul then return false end
            local settings = context.settings or EMPTY_SETTINGS
            if (state.hp_pct or 100) > (settings.smite_solo_pws_hp or 55) then return false end
            return state.power_word_shield_ready
        end,
        execute = function(context, state)
            return try_cast(SPELLS.PowerWordShield, PLAYER_UNIT, format("[SMITE] Solo PW:S %.0f%%", state.hp_pct or 0))
        end,
    },

    -- [0.3] Renew keeps low-pressure solo/PvP damage from stalling.
    {
        name = "SoloRenew",
        matches = function(context, state)
            if context.player_control_locked then return false end
            if not solo_like_context(context) then return false end
            if state.has_renew then return false end
            local settings = context.settings or EMPTY_SETTINGS
            if (state.hp_pct or 100) > (settings.smite_solo_renew_hp or 72) then return false end
            return state.renew_ready
        end,
        execute = function(context, state)
            return try_cast(SPELLS.Renew, PLAYER_UNIT, format("[SMITE] Solo Renew %.0f%%", state.hp_pct or 0))
        end,
    },

    -- [0.4] Panic peel for PvP and multi-mob leveling pulls.
    {
        name = "SoloPsychicScream",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if not solo_like_context(context) then return false end
            local settings = context.settings or EMPTY_SETTINGS
            if context.is_pvp and (state.hp_pct or 100) <= (settings.smite_pvp_scream_hp or 65) then
                return state.psychic_scream_ready
            end
            if (state.enemy_count or 0) >= (settings.smite_solo_scream_enemies or 2) and (state.hp_pct or 100) <= (settings.smite_solo_scream_hp or 75) then
                return state.psychic_scream_ready
            end
            return false
        end,
        execute = function()
            return try_cast(SPELLS.PsychicScream, PLAYER_UNIT, "[SMITE] Psychic Scream peel")
        end,
    },

    -- [0.5] Mana recovery for long solo/PvP fights.
    {
        name = "ShadowfiendMana",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.settings.smite_use_shadowfiend == false then return false end
            if state.mana_pct > (context.settings.smite_shadowfiend_mana or 35) then return false end
            return state.shadowfiend_ready
        end,
        execute = function(context)
            return try_cast(SPELLS.Shadowfiend, context.target, "[SMITE] Shadowfiend mana")
        end,
    },

    -- [1] Holy Fire (on cooldown — HIGHEST DPS priority).
    -- Research: "Open with Holy Fire if the DoT will tick. Use on cooldown."
    {
        name = "HolyFire",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.is_moving then return false end
            -- Mana gate: only HF is allowed below 15% (but wand-only at 5%)
            if state.mana_emergency then return false end
            if state.mana_low and not state.hf_ready then return false end
            return state.hf_ready
        end,
        execute = function(context, state)
            local tag = state.in_weave_window
                and format("[SMITE] HF Weave SW:P rem: %.1fs", state.swp_remaining)
                or "[SMITE] Holy Fire"
            return try_cast(SPELLS.HolyFire, context.target, tag)
        end,
    },

    -- [2] Surge of Light Smite (instant free Smite proc — ALWAYS cast).
    {
        name = "SurgeOfLightSmite",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if state.mana_emergency then return false end
            return state.surge_of_light
        end,
        execute = function(context)
            return try_cast(SPELLS.Smite, context.target, "[SMITE] Surge of Light Smite (instant)")
        end,
    },

    -- [3] Shadow Word: Pain (maintain, mana-gated).
    -- Research: "Only if damage/mana trade positive and debuff slots allow."
    {
        name = "ShadowWordPain",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if state.mana_emergency then return false end
            if state.swp_active then return false end
            if state.mana_low and not group_is_stable(context) then return false end
            if context.ttd_known and context.ttd > 0 and context.ttd < 6 then return false end
            return spell_exists(SPELLS.ShadowWordPain) and spell_ready(SPELLS.ShadowWordPain, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.ShadowWordPain, context.target, "[SMITE] SW:P")
        end,
    },

    -- [3.5] Power Infusion (pre-cast before Holy Fire for burst; 3 min CD).
    -- Research: "Power Infusion if talented and assigned to self."
    {
        name = "PowerInfusion",
        is_gcd_gated = false,
        is_burst = true,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.settings.smite_use_power_infusion == false then return false end
            if state.mana_emergency then return false end
            -- Only use when Holy Fire is ready (max burst value)
            if not state.hf_ready then return false end
            return spell_exists(SPELLS.PowerInfusion) and spell_ready(SPELLS.PowerInfusion, PLAYER_UNIT, SKIP_RANGE)
        end,
        execute = function()
            return try_cast(SPELLS.PowerInfusion, PLAYER_UNIT, "[SMITE] Power Infusion + Holy Fire")
        end,
    },

    -- [4] Inner Focus (off-GCD, pair with Holy Fire or Smite for max value).
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
            -- Pair with HF, then MB (if enabled), then Smite as last resort
            return state.hf_ready
                or (state.mb_ready and context.settings.smite_use_mb ~= false)
                or (spell_exists(SPELLS.Smite) and spell_ready(SPELLS.Smite, context.target))
        end,
        execute = function()
            return try_cast(SPELLS.InnerFocus, PLAYER_UNIT, "[SMITE] Inner Focus")
        end,
    },

    -- [5] Starshards (Night Elf racial)
    {
        name = "Starshards",
        matches = function(context, state)
            if not _is_night_elf then return false end
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if state.mana_emergency then return false end
            if context.settings.smite_use_starshards == false then return false end
            return spell_exists(SPELLS.Starshards) and spell_ready(SPELLS.Starshards, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.Starshards, context.target, "[SMITE] Starshards")
        end,
    },

    -- [6] Devouring Plague (Undead racial)
    {
        name = "DevouringPlague",
        matches = function(context, state)
            if not _is_undead then return false end
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if state.mana_emergency then return false end
            if context.settings.smite_use_devouring_plague == false then return false end
            if context.ttd_known and context.ttd > 0 and context.ttd < 8 then return false end
            if state.dp_remaining > 3 then return false end
            return spell_exists(SPELLS.DevouringPlague) and spell_ready(SPELLS.DevouringPlague, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.DevouringPlague, context.target, "[SMITE] Devouring Plague")
        end,
    },

    -- [7] Mind Blast (optional, setting-gated, threat-gated, mana-gated).
    {
        name = "MindBlast",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.settings.smite_use_mb == false then return false end
            if context.is_moving then return false end
            if state.mana_emergency then return false end
            if state.mana_low then return false end
            -- Threat safety: skip optional shadow spells if tank threat unsafe
            if context.settings.smite_threat_safe ~= false and not state.threat_safe then return false end
            return state.mb_ready
        end,
        execute = function(context)
            return try_cast(SPELLS.MindBlast, context.target, "[SMITE] Mind Blast")
        end,
    },

    -- [8] Shadow Word: Death (optional, HP-gated, threat-gated, mana-gated).
    {
        name = "ShadowWordDeath",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.settings.smite_use_swd == false then return false end
            if state.mana_emergency then return false end
            if not state.swd_safe then return false end
            -- Threat safety: skip optional shadow spells if tank threat unsafe
            if context.settings.smite_threat_safe ~= false and not state.threat_safe then return false end
            return state.swd_ready
        end,
        execute = function(context)
            return try_cast(SPELLS.ShadowWordDeath, context.target,
                format("[SMITE] SW:D HP: %.0f%%", context.hp or 0))
        end,
    },

    -- [8.5] Holy Nova AoE (3+ clustered targets, mana-heavy)
    {
        name = "HolyNova",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.is_moving then return false end
            if state.mana_emergency then return false end
            if state.mana_low then return false end
            return (state.enemy_count or 0) >= 3 and spell_exists(SPELLS.HolyNova) and spell_ready(SPELLS.HolyNova, PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context)
            return try_cast(SPELLS.HolyNova, context.target, "[SMITE] Holy Nova (3+)")
        end,
    },

    -- [9] Smite filler (mana-gated below 15%, suppressed below 5%).
    {
        name = "SmiteFiller",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not can_take_smite_action(context) then return false end
            if context.is_moving then return false end
            if state.mana_emergency then return false end
            -- Mana low (<30%): only Smite + HF; skip Smite below 15%
            if state.mana_low and state.mana_pct < (context.settings.smite_conserve_mana_floor or 15) then return false end
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
            "swp=%.1f surge=%s hf=%s mb=%s swd=%s weave=%s dp=%.1f IF=%s ifRem=%.0f hp=%.0f mana=%.0f low=%s emerg=%s threat=%s",
            state.swp_remaining or 0,
            tostring(state.surge_of_light),
            tostring(state.hf_ready),
            tostring(state.mb_ready),
            tostring(state.swd_ready),
            tostring(state.in_weave_window),
            state.dp_remaining or 0,
            tostring(state.has_inner_focus),
            state.inner_fire_remains or 0,
            state.hp_pct or 0,
            context.mana_pct or 0,
            tostring(state.mana_low),
            tostring(state.mana_emergency),
            tostring(state.threat_safe)
        )
    end,
})

NS.log("Smite priest rotation registered (solo/leveling/PvP support)")
return strategies
