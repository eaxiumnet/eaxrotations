-- smite_sylvanas.lua — Priest Holy DPS for TBC Anniversary (2.5.5).
-- WHAT:  holy damage spec — Holy Fire > Surge-of-Light Smite > SW:P > Mind Blast,
--         with Power Infusion + Inner Focus burst, racials (Starshards, Devouring Plague),
--         and mana conservation tiers (downrank at <30%, wand-only at <5%).
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors TBC smite/holy dps consensus from Icy Veins/Wowhead: HF > SoL Smite > SW:P > MB, PI/IF burst, mana tiers.
-- SAFETY: Pattern 14 nil-guards via spec_kit.safe_state; no on_update() allocs;
--          broken-API guard on aura checks; threat-safety gate on shadow spells.
-- DECISION: Strategy DSL adopted for all 17 strategies with custom conditions
--            preserving shared helpers (can_take_smite_action, solo_like_context, etc.).
local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local load_player = NS.GetPlayer and NS.GetPlayer()
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")
if not _inv_ok or type(inventory_helper) ~= "table" then inventory_helper = nil end

local _ok_enums, enums = pcall(require, "common/enums")
if not _ok_enums or type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
if not load_player then return end
local ok_cls, cls_id = pcall(function() return load_player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.PRIEST then return end

local _player_race = load_player:get_race_id() or 0
local _is_night_elf = _player_race == 4
local _is_undead = _player_race == 5

local SPELLS = NS.PriestSpells

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local _base_define = spec_kit.define_action_for_class(SPELLS)
local function define(name, ids, label)
    local result = _base_define(name, ids, label)
    if result then return result end
    if NS.spell_action then return NS.spell_action(ids, label) end
    return { id = ids, name = name }
end
local ACTION = {
    DevouringPlague = define("DevouringPlague", {25467, 19280, 19279, 19278, 19277, 19276, 2944}, "DevouringPlague"),
    HolyFire        = define("HolyFire",        {25384, 15261, 15267, 15266, 15265, 15264, 15263, 15262, 14914}, "HolyFire"),
    HolyNova        = define("HolyNova",        {25331, 25329, 27805, 27804, 27803, 27801, 27800, 27799, 15431, 15430, 15237}, "HolyNova"),
    InnerFire       = define("InnerFire",       {25431, 10952, 10951, 1006, 602, 7128, 588}, "InnerFire"),
    InnerFocus      = define("InnerFocus",      {14751}, "InnerFocus"),
    MindBlast       = define("MindBlast",       {25375, 25372, 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092}, "MindBlast"),
    PowerInfusion   = define("PowerInfusion",   {10060}, "PowerInfusion"),
    PowerWordShield = define("PowerWordShield", {25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17}, "PowerWordShield"),
    PsychicScream   = define("PsychicScream",   {10890, 10888, 8124, 8122}, "PsychicScream"),
    Renew           = define("Renew",           {25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139}, "Renew"),
    ShadowWordPain  = define("ShadowWordPain",  {25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589}, "ShadowWordPain"),
    ShadowWordDeath = define("ShadowWordDeath", {32996, 32379}, "ShadowWordDeath"),
    Shadowfiend     = define("Shadowfiend",     {34433}, "Shadowfiend"),
    ShackleUndead   = define("ShackleUndead",   {10955, 9485, 9484}, "ShackleUndead"),
    Smite           = define("Smite",           {25364, 25363, 10934, 10933, 6060, 1004, 984, 598, 591, 585}, "Smite"),
    Starshards      = define("Starshards",      {25446, 19305, 19304, 19303, 19302, 19299, 19296, 10797}, "Starshards"),
}

local format = string.format
local PLAYER_UNIT = NS.PLAYER_UNIT

local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local DEVOURING_PLAGUE_DEBUFF = { 2944, 19276, 19277, 19278, 19279, 19280, 25467 }
local SURGE_OF_LIGHT_BUFF = 33151
local INNER_FOCUS_BUFF = 14751
local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local RENEW_BUFF = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local WEAKENED_SOUL_DEBUFF = { 6788 }

local SKIP_RANGE = { skip_range = true }
local PSYCHIC_SCREAM_OPTS = { skip_range = true, expected_cooldown = 30 }
local SHADOWFIEND_OPTS = { expected_cooldown = 300 }

local function target_creature_type(unit)
    if not unit then return nil end
    if type(NS.unit_creature_type) == "function" then return NS.unit_creature_type(unit) end
    if unit.get_creature_type then
        local ok, value = pcall(function() return unit:get_creature_type() end)
        if ok then return value end
    end
    return nil
end

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(ids)
    if not inventory_helper then return nil end
    for _, id in ipairs(ids) do
        if inventory_helper.has_item(id) then return id end
    end
    return nil
end

local try_cast, spell_exists, spell_ready, debuff_remains, buff_up, buff_remains, health_pct, player_control_locked = NS.import_helpers(
    "try_cast", "spell_exists", "spell_ready", "debuff_remains", "buff_up", "buff_remains", "health_pct",
    "player_control_locked"
)

-- ============================================================================
-- SMITE STATE (per-frame cache)
-- ============================================================================
local smite_state = {
    swp_active = false, swp_remaining = 0, surge_of_light = false,
    hf_ready = false, mb_ready = false, swd_ready = false, swd_safe = false,
    in_weave_window = false, dp_remaining = 0,
    has_inner_focus = false, has_inner_fire = false, inner_fire_remains = 0,
    has_renew = false, has_weakened_soul = false,
    inner_focus_ready = false, inner_fire_ready = false,
    power_word_shield_ready = false, renew_ready = false,
    hp_pct = 100, mana_pct = 100, mana_emergency = false, mana_low = false,
    threat_safe = true, enemy_count = 1, is_group = false, healthstone_ready = 0,
    shackle_undead_ready = false, target_creature_type = nil,
}

local SMITE_SCHEMA = {
    swp_active = false, swp_remaining = 0, surge_of_light = false,
    hf_ready = true, mb_ready = true, swd_ready = true, swd_safe = false,
    in_weave_window = false, dp_remaining = 0,
    has_inner_focus = false, has_inner_fire = false, inner_fire_remains = 0,
    has_renew = false, has_weakened_soul = false,
    inner_focus_ready = true, inner_fire_ready = true,
    power_word_shield_ready = true, renew_ready = true,
    hp_pct = 100, mana_pct = 100, mana_emergency = false, mana_low = false,
    threat_safe = true, enemy_count = 0, is_group = false, healthstone_ready = 0,
    shackle_undead_ready = false, target_creature_type = nil,
}

local function build_state(context)
    local target = context.target
    local player = NS.GetPlayer()

    context.player_control_locked = (type(player_control_locked) == "function" and player_control_locked()) or false
    context.is_moving = context.is_moving or (player.is_moving and player:is_moving()) or false
    context.mana_pct = context.mana_pct or context.player_mana_pct or (player.mana_pct and player:mana_pct()) or 100
    context.hp = health_pct(NS.PLAYER_UNIT)

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
    smite_state.hf_ready = spell_exists(ACTION.HolyFire) and spell_ready(ACTION.HolyFire, target)
    smite_state.mb_ready = spell_exists(ACTION.MindBlast) and spell_ready(ACTION.MindBlast, target)
    smite_state.swd_ready = spell_exists(ACTION.ShadowWordDeath) and spell_ready(ACTION.ShadowWordDeath, target)
    smite_state.swd_safe = context.hp > spec_kit.setting_number(context, "smite_swd_hp", 40)
    smite_state.inner_focus_ready = spell_exists(ACTION.InnerFocus) and spell_ready(ACTION.InnerFocus, NS.PLAYER_UNIT)
    smite_state.inner_fire_ready = spell_exists(ACTION.InnerFire) and spell_ready(ACTION.InnerFire, NS.PLAYER_UNIT, SKIP_RANGE)
    smite_state.power_word_shield_ready = spell_exists(ACTION.PowerWordShield) and spell_ready(ACTION.PowerWordShield, NS.PLAYER_UNIT, SKIP_RANGE)
    smite_state.renew_ready = spell_exists(ACTION.Renew) and spell_ready(ACTION.Renew, NS.PLAYER_UNIT, SKIP_RANGE)
    smite_state.shadowfiend_ready = spell_exists(ACTION.Shadowfiend) and spell_ready(ACTION.Shadowfiend, target, SHADOWFIEND_OPTS)
    smite_state.hp_pct = context.hp or 100
    smite_state.is_group = context.is_group or false
    smite_state.mana_pct = context.mana_pct or 100
    smite_state.enemy_count = context.enemy_count or context.enemies_count or 1
    smite_state.mana_low = smite_state.mana_pct < spec_kit.setting_number(context, "smite_mana_floor", 30)
    smite_state.mana_emergency = smite_state.mana_pct < spec_kit.setting_number(context, "smite_wand_floor", 5)
    smite_state.threat_safe = type(NS.is_threat_safe) == "function" and NS.is_threat_safe() or true
    smite_state.in_weave_window = smite_state.swp_active
        and (smite_state.swp_remaining or 0) > 2.0
        and (smite_state.swp_remaining or 0) < 3.0
    smite_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0
    smite_state.shackle_undead_ready = spell_exists(ACTION.ShackleUndead) and spell_ready(ACTION.ShackleUndead, player, { expected_cooldown = 1.5 }) or false
    smite_state.target_creature_type = target_creature_type(target)
    return spec_kit.safe_state(smite_state, SMITE_SCHEMA)
end

local function solo_like_context(context)
    return context.is_solo == true or context.is_leveling == true or context.is_pvp == true
end

local function group_is_stable(context)
    if not context then return false end
    -- Engine provides context.lowest_hp (party scan); lowest_ally_hp /
    -- lowest_group_hp were never written (read-side audit 2026-08).
    local lowest = (context.lowest_hp or 100)
    return lowest >= spec_kit.setting_number(context, "smite_group_safe_hp", 80)
end

local function can_take_smite_action(context)
    if not context then return false end
    if not context.has_valid_enemy_target then return false end
    if context.player_control_locked then return false end
    if (context.target_phys_immune or false) then return false end
    return true
end

-- ============================================================================
-- Declarative Strategy DSL definitions
-- ============================================================================
local DSL_DEFS = {
    {
        name = "InnerFire",
        conditions = {
            { type = "custom", fn = function(context, state)
                if context.player_control_locked then return false end
                if not state.inner_fire_ready then return false end
                if state.has_inner_fire and state.inner_fire_remains > 5 then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            local tag = state.has_inner_fire
                and format("[SMITE] Inner Fire refresh (%.0fs)", state.inner_fire_remains)
                or "[SMITE] Inner Fire"
            return try_cast(ACTION.InnerFire, PLAYER_UNIT, tag)
        end },
    },
    {
        name = "SoloPowerWordShield",
        conditions = {
            { type = "custom", fn = function(context, state)
                if context.player_control_locked then return false end
                if not solo_like_context(context) then return false end
                if state.has_weakened_soul then return false end
                if (state.hp_pct or 100) > spec_kit.setting_number(context, "smite_solo_pws_hp", 55) then return false end
                return true
            end },
            { type = "state", field = "power_word_shield_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context, state)
            return try_cast(ACTION.PowerWordShield, PLAYER_UNIT, format("[SMITE] Solo PW:S %.0f%%", state.hp_pct or 0))
        end },
    },
    {
        name = "SoloRenew",
        conditions = {
            { type = "custom", fn = function(context, state)
                if context.player_control_locked then return false end
                if not solo_like_context(context) then return false end
                if state.has_renew then return false end
                if (state.hp_pct or 100) > spec_kit.setting_number(context, "smite_solo_renew_hp", 72) then return false end
                return true
            end },
            { type = "state", field = "renew_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context, state)
            return try_cast(ACTION.Renew, PLAYER_UNIT, format("[SMITE] Solo Renew %.0f%%", state.hp_pct or 0))
        end },
    },
    {
        name = "SoloPsychicScream",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if context.player_control_locked then return false end
                if not solo_like_context(context) then return false end
                if context.is_pvp and (state.hp_pct or 100) <= spec_kit.setting_number(context, "smite_pvp_scream_hp", 65) then
                    return true
                end
                if (state.enemy_count or 0) >= spec_kit.setting_number(context, "smite_solo_scream_enemies", 2)
                    and (state.hp_pct or 100) <= spec_kit.setting_number(context, "smite_solo_scream_hp", 75) then
                    return true
                end
                return false
            end },
        },
        action = { type = "custom", fn = function()
            return try_cast(ACTION.PsychicScream, PLAYER_UNIT, "[SMITE] Psychic Scream peel")
        end },
    },
    {
        name = "Healthstone",
        conditions = {
            { type = "in_combat" },
            { type = "state", field = "hp_pct", op = "<=", value = 28 },
            { type = "state", field = "healthstone_ready", op = ">", value = 0 },
        },
        action = { type = "custom", fn = function(context)
            local id = first_ready_item(HEALTHSTONE_IDS)
            if id then NS.use_item_by_id(id, context.me) end
        end },
    },
    {
        name = "ShadowfiendMana",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not can_take_smite_action(context) then return false end
                if spec_kit.setting_bool(context, "smite_use_shadowfiend", true) == false then return false end
                if state.mana_pct > spec_kit.setting_number(context, "smite_shadowfiend_mana", 35) then return false end
                return true
            end },
            { type = "state", field = "shadowfiend_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context)
            return try_cast(ACTION.Shadowfiend, context.target, "[SMITE] Shadowfiend mana")
        end },
    },
    {
        name = "HolyFire",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not can_take_smite_action(context) then return false end
                if context.is_moving then return false end
                if state.mana_emergency then return false end
                if state.mana_low and not state.hf_ready then return false end
                return true
            end },
            { type = "state", field = "hf_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context, state)
            local tag = state.in_weave_window
                and format("[SMITE] HF Weave SW:P rem: %.1fs", state.swp_remaining)
                or "[SMITE] Holy Fire"
            return try_cast(ACTION.HolyFire, context.target, tag)
        end },
    },
    {
        name = "SurgeOfLightSmite",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not can_take_smite_action(context) then return false end
                if state.mana_emergency then return false end
                return true
            end },
            { type = "state", field = "surge_of_light", op = "truthy" },
        },
        action = { type = "custom", fn = function(context)
            return try_cast(ACTION.Smite, context.target, "[SMITE] Surge of Light Smite (instant)")
        end },
    },
    {
        name = "ShadowWordPain",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not can_take_smite_action(context) then return false end
                if state.mana_emergency then return false end
                if state.swp_active then return false end
                if state.mana_low and not group_is_stable(context) then return false end
                if context.ttd_known and context.ttd > 0 and context.ttd < 6 then return false end
                if not (spell_exists(ACTION.ShadowWordPain) and spell_ready(ACTION.ShadowWordPain, context.target)) then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context)
            return try_cast(ACTION.ShadowWordPain, context.target, "[SMITE] SW:P")
        end },
    },
    {
        name = "PowerInfusion",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not can_take_smite_action(context) then return false end
                if spec_kit.setting_bool(context, "smite_use_power_infusion", true) == false then return false end
                if state.mana_emergency then return false end
                if not state.hf_ready then return false end
                if not (spell_exists(ACTION.PowerInfusion) and spell_ready(ACTION.PowerInfusion, PLAYER_UNIT, SKIP_RANGE)) then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function()
            return try_cast(ACTION.PowerInfusion, PLAYER_UNIT, "[SMITE] Power Infusion + Holy Fire")
        end },
    },
    {
        name = "InnerFocus",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not can_take_smite_action(context) then return false end
                if spec_kit.setting_bool(context, "smite_use_inner_focus", true) == false then return false end
                if state.has_inner_focus then return false end
                if not state.inner_focus_ready then return false end
                return state.hf_ready
                    or (state.mb_ready and spec_kit.setting_bool(context, "smite_use_mb", true) ~= false)
                    or (spell_exists(ACTION.Smite) and spell_ready(ACTION.Smite, context.target))
            end },
        },
        action = { type = "custom", fn = function()
            return try_cast(ACTION.InnerFocus, PLAYER_UNIT, "[SMITE] Inner Focus")
        end },
    },
    {
        name = "Starshards",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not _is_night_elf then return false end
                if not context.in_combat then return false end
                if not can_take_smite_action(context) then return false end
                if state.mana_emergency then return false end
                if spec_kit.setting_bool(context, "smite_use_starshards", true) == false then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context)
            return try_cast(ACTION.Starshards, context.target, "[SMITE] Starshards")
        end },
    },
    {
        name = "DevouringPlague",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not _is_undead then return false end
                if not context.in_combat then return false end
                if not can_take_smite_action(context) then return false end
                if state.mana_emergency then return false end
                if spec_kit.setting_bool(context, "smite_use_devouring_plague", true) == false then return false end
                if context.ttd_known and context.ttd > 0 and context.ttd < 8 then return false end
                if state.dp_remaining > 3 then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context)
            return try_cast(ACTION.DevouringPlague, context.target, "[SMITE] Devouring Plague")
        end },
    },
    {
        name = "MindBlast",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not can_take_smite_action(context) then return false end
                if spec_kit.setting_bool(context, "smite_use_mb", true) == false then return false end
                if context.is_moving then return false end
                if state.mana_emergency then return false end
                if state.mana_low then return false end
                if spec_kit.setting_bool(context, "smite_threat_safe", true) ~= false and not state.threat_safe then return false end
                return true
            end },
            { type = "state", field = "mb_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context)
            return try_cast(ACTION.MindBlast, context.target, "[SMITE] Mind Blast")
        end },
    },
    {
        name = "ShadowWordDeath",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not can_take_smite_action(context) then return false end
                if spec_kit.setting_bool(context, "smite_use_swd", true) == false then return false end
                if state.mana_emergency then return false end
                if not state.swd_safe then return false end
                if spec_kit.setting_bool(context, "smite_threat_safe", true) ~= false and not state.threat_safe then return false end
                return true
            end },
            { type = "state", field = "swd_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context)
            return try_cast(ACTION.ShadowWordDeath, context.target,
                format("[SMITE] SW:D HP: %.0f%%", context.hp or 0))
        end },
    },
    {
        name = "HolyNova",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not can_take_smite_action(context) then return false end
                if context.is_moving then return false end
                if state.mana_emergency then return false end
                if state.mana_low then return false end
                if not (spell_exists(ACTION.HolyNova) and spell_ready(ACTION.HolyNova, PLAYER_UNIT, SKIP_RANGE)) then return false end
                if not (NS.aoe_self_meets and NS.aoe_self_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, state)) then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context)
            return try_cast(ACTION.HolyNova, context.target, "[SMITE] Holy Nova (3+)")
        end },
    },
    {
        name = "SmiteFiller",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not can_take_smite_action(context) then return false end
                if context.is_moving then return false end
                if state.mana_emergency then return false end
                if state.mana_low and state.mana_pct < spec_kit.setting_number(context, "smite_conserve_mana_floor", 15) then return false end
                if not (spell_exists(ACTION.Smite) and spell_ready(ACTION.Smite, context.target)) then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context)
            return try_cast(ACTION.Smite, context.target, "[SMITE] Smite")
        end },
    },
    {
        name = "ShackleUndead",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not spec_kit.setting_bool(context, "smite_auto_shackle", true) then return false end
                if not context.has_valid_enemy_target then return false end
                local ct = state.target_creature_type
                if not ct or (ct ~= 3 and ct ~= 6) then return false end
                if context.target and NS.debuff_up and NS.debuff_up(context.target, {9484, 9485, 10955}) then return false end
                return true
            end },
            { type = "state", field = "shackle_undead_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context)
            return try_cast(ACTION.ShackleUndead, context.target, "[SMITE] ShackleUndead")
        end },
    },
}

-- ============================================================================
-- STRATEGIES (name-only placeholders; substituted at runtime via DSL)
-- ============================================================================
local strategies = {
    { name = "InnerFire" },
    { name = "SoloPowerWordShield" },
    { name = "SoloRenew" },
    { name = "SoloPsychicScream" },
    { name = "Healthstone" },
    { name = "ShadowfiendMana" },
    { name = "HolyFire" },
    { name = "SurgeOfLightSmite" },
    { name = "ShadowWordPain" },
    { name = "PowerInfusion", is_gcd_gated = false, is_burst = true },
    { name = "InnerFocus", is_gcd_gated = false, is_burst = true },
    { name = "Starshards" },
    { name = "DevouringPlague" },
    { name = "MindBlast" },
    { name = "ShadowWordDeath" },
    { name = "HolyNova" },
    { name = "ShackleUndead" },
    { name = "SmiteFiller" },
}

-- Name-based substitution preserves the existing priority order
-- and copies extra fields (is_gcd_gated, is_burst, etc.) from placeholders
-- onto the compiled strategy so the engine can read them for burst/tick logic.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            local compiled = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            for k, v in pairs(strategies[i]) do
                if k ~= "name" then compiled[k] = v end
            end
            strategies[i] = compiled
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("smite", strategies, {
        get_state = build_state,
        format_context_log = function(context, state)
            return format(
                "swp=%.1f surge=%s hf=%s mb=%s swd=%s weave=%s dp=%.1f IF=%s ifRem=%.0f hp=%.0f mana=%.0f low=%s emerg=%s threat=%s",
                state.swp_remaining or 0, tostring(state.surge_of_light),
                tostring(state.hf_ready), tostring(state.mb_ready), tostring(state.swd_ready),
                tostring(state.in_weave_window), state.dp_remaining or 0,
                tostring(state.has_inner_focus), state.inner_fire_remains or 0,
                state.hp_pct or 0, context.mana_pct or 0,
                tostring(state.mana_low), tostring(state.mana_emergency), tostring(state.threat_safe)
            )
        end,
    })
end
if NS.log then NS.log("Smite priest rotation registered") end

return { strategies = strategies, build_state = build_state }
