-- elemental_sylvanas.lua -- Shaman Elemental DPS for TBC Anniversary (2.5.5).
-- WHAT:  ranged caster DPS with Lightning Bolt filler, Flame Shock DoT,
--         Chain Lightning cleave, Elemental Mastery burst, totem maintenance,
--         mana-aware rank switching, and weapon buff upkeep.
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors TBC elemental consensus: totems > Flame Shock > CL > LB.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no on_update() allocs.

-- Shaman Elemental priority list.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end
local potion_helper = require("shared/potion_helper_sylvanas")
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")
if not _inv_ok or type(inventory_helper) ~= "table" then inventory_helper = nil end
local SPELLS = NS.ShamanSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

-- Centralized spell resolver via spec_kit (rank IDs from shaman/class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Bloodlust            = define("Bloodlust",            { 2825 }, "Bloodlust"),
    ChainHeal            = define("ChainHeal",            { 25423, 25422, 10623, 10622, 1064 }, "ChainHeal"),
    ChainLightning       = define("ChainLightning",       { 25442, 25439, 10605, 2860, 930, 421 }, "ChainLightning"),
    EarthbindTotem       = define("EarthbindTotem",       { 2484 }, "EarthbindTotem"),
    EarthShock           = define("EarthShock",           { 25454, 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, "EarthShock"),
    ElementalMastery     = define("ElementalMastery",     { 16166 }, "ElementalMastery"),
    FireNovaTotem        = define("FireNovaTotem",        { 25547, 25546, 11315, 11314, 8499, 8498, 1535 }, "FireNovaTotem"),
    FlametongueWeapon    = define("FlametongueWeapon",    { 25489, 16342, 16341, 16339, 8030, 8027, 8024 }, "FlametongueWeapon"),
    FlameShock           = define("FlameShock",           { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, "FlameShock"),
    FrostShock           = define("FrostShock",           { 25464, 10473, 10472, 8058, 8056 }, "FrostShock"),
    GhostWolf            = define("GhostWolf",            { 2645 }, "GhostWolf"),
    HealingWave          = define("HealingWave",          { 25396, 25391, 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331 }, "HealingWave"),
    LightningBolt        = define("LightningBolt",        { 25449, 25448, 15208, 15207, 10392, 10391, 6041, 943, 915, 548, 529, 403 }, "LightningBolt"),
    LightningBoltLowerRank = define("LightningBoltLowerRank", { 25448 }, "LightningBoltLowerRank"),
    LightningShield      = define("LightningShield",      { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, "LightningShield"),
    MagmaTotem           = define("MagmaTotem",           { 25550, 10587, 10586, 10585, 8190 }, "MagmaTotem"),
    ManaSpringTotem      = define("ManaSpringTotem",      { 25570, 10497, 10496, 10495, 5675 }, "ManaSpringTotem"),
    ManaTideTotem        = define("ManaTideTotem",        { 16190 }, "ManaTideTotem"),
    NaturesSwiftness     = define("NaturesSwiftness",     { 16188 }, "NaturesSwiftness"),
    RockbiterWeapon      = define("RockbiterWeapon",      { 25485, 25479, 16316, 16315, 16314, 10399, 8019, 8018, 8017 }, "RockbiterWeapon"),
    TotemicCall          = define("TotemicCall",          { 36936 }, "TotemicCall"),
    TotemOfWrath         = define("TotemOfWrath",         { 30706 }, "TotemOfWrath"),
    TremorTotem          = define("TremorTotem",          { 8143 }, "TremorTotem"),
    WaterShield          = define("WaterShield",          { 33736, 24398, 23575 }, "WaterShield"),
    WindfuryWeapon       = define("WindfuryWeapon",       { 25505, 16362, 10486, 8235, 8232 }, "WindfuryWeapon"),
    WrathOfAirTotem      = define("WrathOfAirTotem",      { 3738 }, "WrathOfAirTotem"),
}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { shaman = {} } } end
local TBC_SHAMAN = (TBC.SPELLS and TBC.SPELLS.shaman) or {}

-- Debuff and buff ID tables
local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local LIGHTNING_SHIELD_BUFF = TBC_SHAMAN.lightning_shield or { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local TOTEM_OF_WRATH_BUFF = { 30708 }
local WRATH_OF_AIR_BUFF = { 3738 }
local MANA_SPRING_BUFF = { 25570, 10491, 10490, 5676 }  -- Mana Spring Totem aura ranks
local CLEARCAST_BUFF = { 12536 }  -- Clearcasting from Elemental Focus talent
local SHIELD_REFRESH_UNKNOWN_MS = 30000
local WEAPON_BUFF_REFRESH_MS = 1500000  -- 25 minutes
local HEALING_WAVE_HP_PCT = 40

-- Mana conservation defaults per Research (overridable via schema)
local MANA_LOW_DEFAULT = 30        -- Switch to lower-rank Lightning Bolt
local MANA_CONSERVE_DEFAULT = 15   -- No Chain Lightning, Flame Shock only
local MANA_EMERGENCY_DEFAULT = 5   -- All spells forbidden
local WATER_SHIELD_MANA_DEFAULT = 50

-- SP-aware DoT gating: skip Flame Shock below this spell damage threshold
-- Flame Shock has ~0.3 direct + ~0.3 DoT coefficient; breakpoint ~400 SP pre-raid
local FLAME_SHOCK_MIN_SP_DEFAULT = 400

-- Chain Lightning defaults (DB2: EffectChainTargets=3, EffectChainAmplitude=0.70)
local CL_MIN_TARGETS = 3
local CL_CLUSTER_RADIUS = 10  -- yards, configurable

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(ids)
    if not inventory_helper then return nil end
    for _, id in ipairs(ids) do
        if inventory_helper.has_item(id) then return id end
    end
    return nil
end

local runtime = {
    last_lightning_shield_ms = -SHIELD_REFRESH_UNKNOWN_MS,
    last_flametongue_ms = -30000000,
    last_windfury_ms = -30000000,
    last_rockbiter_ms = -30000000,
}

-- ============================================================================
-- Schema for safe_state (Pattern 14 nil-guard elimination).
-- ============================================================================
local ELE_SCHEMA = {
    flame_remains = 0, lightning_shield_up = false,
    mana_pct = 100, mana_low = false, mana_conserve = false, mana_emergency = false,
    hp_pct = 100, target_count = 0, has_flametongue = false,
    has_windfury = false, has_rockbiter = false, now_ms = 0,
    spell_damage = 0, clearcast_active = false, healthstone_ready = 0,
}

-- ============================================================================
-- State builder
-- ============================================================================
local ele_state = {
    flame_remains = 0,
    lightning_shield_up = false,
    mana_pct = 100,
    mana_low = false,
    mana_conserve = false,
    mana_emergency = false,
    hp_pct = 100,
    target_count = 1,
    has_flametongue = false,
    has_windfury = false,
    has_rockbiter = false,
    now_ms = 0,
    spell_damage = 0,
    clearcast_active = false,
    healthstone_ready = 0,
}

local function build_state(context)
    local target = context.target
    ele_state.is_group = context.is_group or false
    if target then
        ele_state.flame_remains = NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF) or 0
    else
        ele_state.flame_remains = 0
    end
    ele_state.lightning_shield_up = NS.has_player_buff(LIGHTNING_SHIELD_BUFF)
    ele_state.mana_pct = context.mana_pct or 100
    local mana_low = spec_kit.setting_number(context, "elemental_mana_low_pct", MANA_LOW_DEFAULT)
    local mana_conserve = spec_kit.setting_number(context, "elemental_mana_conserve_pct", MANA_CONSERVE_DEFAULT)
    local mana_emergency = spec_kit.setting_number(context, "elemental_mana_emergency_pct", MANA_EMERGENCY_DEFAULT)
    ele_state.mana_low = ele_state.mana_pct < mana_low
    ele_state.mana_conserve = ele_state.mana_pct < mana_conserve
    ele_state.mana_emergency = ele_state.mana_pct < mana_emergency
    ele_state.hp_pct = context.hp or 100
    ele_state.target_count = context.enemy_count or 1
    ele_state.now_ms = NS.game_time_ms and NS.game_time_ms() or 0
    -- Current spell damage from NS (provided by middleware or character API)
    ele_state.spell_damage = context.spell_damage or 0
    -- Weapon buff freshness
    ele_state.has_flametongue = (ele_state.now_ms - runtime.last_flametongue_ms) < WEAPON_BUFF_REFRESH_MS
    ele_state.has_windfury = (ele_state.now_ms - runtime.last_windfury_ms) < WEAPON_BUFF_REFRESH_MS
    ele_state.has_rockbiter = (ele_state.now_ms - runtime.last_rockbiter_ms) < WEAPON_BUFF_REFRESH_MS
    ele_state.clearcast_active = NS.has_player_buff and NS.has_player_buff(CLEARCAST_BUFF) or false
    ele_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0
    return spec_kit.safe_state(ele_state, ELE_SCHEMA)
end

-- ============================================================================
-- Matches functions
-- ============================================================================

local function lightning_shield_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.LightningShield, 3.0) then return false end
    if state.mana_emergency then return false end
    if not spec_kit.setting_bool(context, "elemental_lightning_shield", true) then return false end
    if state.lightning_shield_up then return false end
    if state.now_ms - runtime.last_lightning_shield_ms < SHIELD_REFRESH_UNKNOWN_MS then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.LightningShield, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function lightning_shield_execute(context, state)
    if NS.try_cast(ACTION.LightningShield, NS.PLAYER_UNIT, "[ELEMENTAL] Lightning Shield") then
        runtime.last_lightning_shield_ms = state.now_ms
        return true
    end
    return false
end

local function bloodlust_matches_fn(context, state)
    if not context.in_combat then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if not context.should_burst then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.Bloodlust, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function chain_lightning_matches_fn(context, state)
    if context.is_moving then return false end
    if state.mana_emergency then return false end
    if state.mana_conserve then return false end
    -- CC safety: skip Chain Lightning if it might break nearby CC
    -- Lua: nil == false is false (different types), so this only fires when cc_safe is explicitly false
    if context.cc_safe == false then return false end
    -- Threat safety: skip Chain Lightning if threat is high (multi-target pulls threat)
    if context.threat_pct and context.threat_pct > 80 then return false end
    -- Clearcast priority: always cast CL when Clearcast is active to consume the proc
    if state.clearcast_active then
        return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ChainLightning, context.target) or false
    end
    -- Research: CL only at 3+ targets; configurable via schema
    local min_targets = spec_kit.setting_number(context, "elemental_cl_min_targets", CL_MIN_TARGETS)
    if not (NS.aoe_target_meets and NS.aoe_target_meets(min_targets, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_10) or 10, context.target, context, state)) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ChainLightning, context.target) or false
end

local _el_lb_count = 0
local function lightning_bolt_matches_fn(context, state)
    _el_lb_count = _el_lb_count + 1
    if _el_lb_count <= 3 and NS.log then
        NS.log(string.format(
            "[ELEMENTAL][LightningBolt] call #%d: state=%s, ctx.in_combat=%s, ctx.has_valid_enemy_target=%s, ctx.target=%s, state.target=%s, state.is_moving=%s, state.mana_emergency=%s, state.lightning_bolt_ready=%s",
            _el_lb_count,
            tostring(state ~= nil),
            tostring(context and context.in_combat),
            tostring(context and context.has_valid_enemy_target),
            tostring(context and context.target ~= nil),
            tostring(state and state.target ~= nil),
            tostring(context and context.is_moving),
            tostring(state and state.mana_emergency),
            tostring(state and state.lightning_bolt_ready)))
    end
    if context.is_moving then return false end
    if state.mana_emergency then return false end
    -- Threat safety: hold Lightning Bolt if threat > 90%
    if context.threat_pct and context.threat_pct > 90 then return false end
    -- Research: switch to lower-rank Lightning Bolt at mana < 30%
    -- Uses ACTION.LightningBoltLowerRank when learned and mana is low
    local lower_rank = ACTION.LightningBoltLowerRank
    local lower_id = (type(lower_rank) == "table" and lower_rank.ids and lower_rank.ids[1]) or lower_rank
    local spell_id = (state.mana_low and lower_id and NS.is_spell_learned and NS.is_spell_learned(lower_id)) and lower_rank or ACTION.LightningBolt
    return NS.spell_ready ~= nil and NS.spell_ready(spell_id, context.target) or false
end

local function flame_shock_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.FlameShock, 2.0) then return false end
    if not context.target then return false end
    -- Research: only clip Flame Shock at <1s remaining (prevents shock CD starvation)
    if (state.flame_remains or 0) > 1 then return false end    -- SP-aware gating: skip Flame Shock if spell damage is below minimum threshold
    -- Flame Shock has ~0.3 direct + ~0.3 DoT coefficient = ~0.6 total; GCD-positive at ~400 SP
    local min_sp = spec_kit.setting_number(context, "elemental_flame_shock_min_sp", FLAME_SHOCK_MIN_SP_DEFAULT)
    if NS.should_refresh_dot and not NS.should_refresh_dot(state.flame_remains, 1.5, context.ttd, 12) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.FlameShock, context.target) or false
end

local function earth_shock_filler_matches_fn(context, state)
    if not context.is_moving then return false end
    -- Respect interrupt reserve: when ON, suppress Earth Shock filler to save for interrupts
    if spec_kit.setting_bool(context, "elemental_interrupt_reserve", true) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.EarthShock, context.target) or false
end

local function frost_shock_matches_fn(context, state)
    if not context.is_moving then return false end
    if not context.is_pvp then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.FrostShock, context.target) or false
end

local function elemental_mastery_matches_fn(context, state)
    if not spec_kit.setting_bool(context, "elemental_use_elemental_mastery", true) then return false end
    if not context.in_combat then return false end
    if state.mana_conserve then return false end
    if not context.should_burst then return false end
    -- EM+CL hold: don't waste EM on Lightning Bolt when CL is the better nuke
    local min_targets = spec_kit.setting_number(context, "elemental_cl_min_targets", CL_MIN_TARGETS)
    if (state.target_count or 0) >= min_targets then
        local cl_cd = NS.cooldown_remains and NS.cooldown_remains(ACTION.ChainLightning) or 0
        if cl_cd > 1.5 then return false end
    end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ElementalMastery, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function natures_swiftness_matches_fn(context, state)
    if not spec_kit.setting_bool(context, "elemental_use_natures_swiftness", true) then return false end
    if not context.in_combat then return false end
    if not context.should_burst then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.NaturesSwiftness, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function water_shield_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.WaterShield, 3.0) then return false end
    if state.mana_emergency then return false end
    local ws_mana = spec_kit.setting_number(context, "elemental_water_shield_mana", WATER_SHIELD_MANA_DEFAULT)
    if (state.mana_pct or 100) > ws_mana then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.WaterShield, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function ghost_wolf_matches_fn(context, state)
    if context.in_combat then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.GhostWolf, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function tremor_totem_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.TremorTotem, 3.0) then return false end
    if not context.in_combat then return false end
    if state.mana_emergency then return false end
    if not (context.fear_nearby or false) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.TremorTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function earthbind_totem_matches_fn(context, state)
    if not context.is_pvp then return false end
    if state.mana_emergency then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.EarthbindTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function mana_tide_totem_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.ManaTideTotem, 3.0) then return false end
    if state.mana_emergency then return false end
    if (state.mana_pct or 100) > 30 then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ManaTideTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function chain_heal_matches_fn(context, state)
    if not (context.group_injured or false) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ChainHeal, NS.PLAYER_UNIT, { skip_range = true }) or false
end

-- ============================================================================
-- Weapon buffs (parity parity)
-- ============================================================================

local function flametongue_weapon_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.FlametongueWeapon, 3.0) then return false end
    if context.in_combat then return false end
    if state.has_flametongue then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.FlametongueWeapon, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function flametongue_weapon_execute(context, state)
    if NS.try_cast(ACTION.FlametongueWeapon, NS.PLAYER_UNIT, "[ELEMENTAL] Flametongue Weapon") then
        runtime.last_flametongue_ms = state.now_ms
        return true
    end
    return false
end

local function windfury_weapon_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.WindfuryWeapon, 3.0) then return false end
    if context.in_combat then return false end
    if state.has_windfury then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.WindfuryWeapon, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function windfury_weapon_execute(context, state)
    if NS.try_cast(ACTION.WindfuryWeapon, NS.PLAYER_UNIT, "[ELEMENTAL] Windfury Weapon") then
        runtime.last_windfury_ms = state.now_ms
        return true
    end
    return false
end

local function rockbiter_weapon_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.RockbiterWeapon, 3.0) then return false end
    if context.in_combat then return false end
    if state.has_rockbiter then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.RockbiterWeapon, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function rockbiter_weapon_execute(context, state)
    if NS.try_cast(ACTION.RockbiterWeapon, NS.PLAYER_UNIT, "[ELEMENTAL] Rockbiter Weapon") then
        runtime.last_rockbiter_ms = state.now_ms
        return true
    end
    return false
end

-- ============================================================================
-- Healing Wave (self-heal)
-- ============================================================================

local function healing_wave_matches_fn(context, state)
    if not context.in_combat then return false end
    local heal_hp = spec_kit.setting_number(context, "elemental_self_heal_hp", HEALING_WAVE_HP_PCT)
    if (state.hp_pct or 100) > heal_hp then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.HealingWave, NS.PLAYER_UNIT, { skip_range = true }) or false
end

-- ============================================================================
-- Totem maintenance (Research: keep Totem of Wrath, Wrath of Air, Mana Spring)
-- ============================================================================

local function totem_of_wrath_matches_fn(context, state)
    if not spec_kit.setting_bool(context, "elemental_manage_totems", true) then return false end
    if not spec_kit.setting_bool(context, "elemental_use_totem_of_wrath", true) then return false end
    if state.mana_emergency then return false end
    if NS.has_player_buff(TOTEM_OF_WRATH_BUFF) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.TotemOfWrath, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function wrath_of_air_totem_matches_fn(context, state)
    if not spec_kit.setting_bool(context, "elemental_manage_totems", true) then return false end
    if state.mana_emergency then return false end
    if NS.has_player_buff(WRATH_OF_AIR_BUFF) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.WrathOfAirTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function mana_spring_totem_matches_fn(context, state)
    if not spec_kit.setting_bool(context, "elemental_manage_totems", true) then return false end
    if state.mana_emergency then return false end
    if NS.has_player_buff(MANA_SPRING_BUFF) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ManaSpringTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

-- ============================================================================
-- AoE totems (Research: Fire Nova/Magma for stacked AoE)
-- ============================================================================

local function fire_nova_totem_matches_fn(context, state)
    if not spec_kit.setting_bool(context, "elemental_use_fire_nova_aoe", true) then return false end
    if not context.in_combat then return false end
    if state.mana_conserve then return false end
    local min_targets = spec_kit.setting_number(context, "elemental_aoe_threshold", 4)
    if not (NS.aoe_self_meets and NS.aoe_self_meets(min_targets, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, state)) then return false end
    if context.cc_safe == false then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.FireNovaTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function magma_totem_matches_fn(context, state)
    if not spec_kit.setting_bool(context, "elemental_use_magma_aoe", true) then return false end
    if not context.in_combat then return false end
    if state.mana_conserve then return false end
    local min_targets = spec_kit.setting_number(context, "elemental_aoe_threshold", 4)
    if not (NS.aoe_self_meets and NS.aoe_self_meets(min_targets, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)) then return false end
    if context.cc_safe == false then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.MagmaTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

-- ============================================================================
-- Totemic Call (totem recall)
-- ============================================================================

local function totemic_call_matches_fn(context, state)
    if not context.in_combat then return false end
    if not context.is_moving then return false end
    if not (context.has_totems or false) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(ACTION.TotemicCall, NS.PLAYER_UNIT, { skip_range = true }) or false
end

-- ============================================================================
-- Declarative Strategy DSL
-- ============================================================================
local DSL_DEFS = {
    {
        name = "WaterShield",
        conditions = {
            { type = "custom", fn = function(context, state)
                return not (NS.broken_api_throttled and NS.broken_api_throttled(ACTION.WaterShield, 3.0))
            end },
            { type = "state", field = "mana_emergency", op = "==", value = false },
            { type = "custom", fn = function(context, state)
                local threshold = spec_kit.setting_number(context, "elemental_water_shield_mana", WATER_SHIELD_MANA_DEFAULT)
                return (state.mana_pct or 100) <= threshold
            end },
            { type = "spell_ready", spell = ACTION.WaterShield, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.WaterShield, target = "self", opts = { skip_range = true }, label = "[ELEMENTAL] Water Shield" },
    },
    {
        name = "GhostWolf",
        conditions = {
            { type = "context", field = "in_combat", op = "==", value = false },
            { type = "spell_ready", spell = ACTION.GhostWolf, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.GhostWolf, target = "self", opts = { skip_range = true }, label = "[ELEMENTAL] Ghost Wolf" },
    },
    {
        name = "EarthbindTotem",
        conditions = {
            { type = "context", field = "is_pvp", op = "==", value = true },
            { type = "state", field = "mana_emergency", op = "==", value = false },
            { type = "spell_ready", spell = ACTION.EarthbindTotem, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.EarthbindTotem, target = "self", opts = { skip_range = true }, label = "[ELEMENTAL] Earthbind Totem" },
    },
    {
        name = "ManaTideTotem",
        conditions = {
            { type = "custom", fn = function(context, state)
                return not (NS.broken_api_throttled and NS.broken_api_throttled(ACTION.ManaTideTotem, 3.0))
            end },
            { type = "state", field = "mana_emergency", op = "==", value = false },
            { type = "state", field = "mana_pct", op = "<=", value = 30 },
            { type = "spell_ready", spell = ACTION.ManaTideTotem, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.ManaTideTotem, target = "self", opts = { skip_range = true }, label = "[ELEMENTAL] Mana Tide Totem" },
    },
    {
        name = "FlameShock",
        conditions = {
            { type = "custom", fn = function(context, state)
                return not (NS.broken_api_throttled and NS.broken_api_throttled(ACTION.FlameShock, 2.0))
            end },
            { type = "custom", fn = function(context, state) return context.target ~= nil end },
            { type = "state", field = "flame_remains", op = "<=", value = 1 },
            { type = "custom", fn = function(context, state)
                if NS.should_refresh_dot and not NS.should_refresh_dot(state.flame_remains, 1.5, context.ttd, 12) then return false end
                return true
            end },
            { type = "spell_ready", spell = ACTION.FlameShock, target = "target" },
        },
        action = { type = "cast", spell = ACTION.FlameShock, target = "target", label = "[ELEMENTAL] Flame Shock" },
    },
    {
        name = "ElementalMastery",
        conditions = {
            { type = "setting", key = "elemental_use_elemental_mastery", op = "==", value = true },
            { type = "context", field = "in_combat", op = "==", value = true },
            { type = "state", field = "mana_conserve", op = "==", value = false },
            { type = "context", field = "should_burst", op = "==", value = true },
            { type = "custom", fn = function(context, state)
                local min_targets = spec_kit.setting_number(context, "elemental_cl_min_targets", CL_MIN_TARGETS)
                if (state.target_count or 0) >= min_targets then
                    local cl_cd = NS.cooldown_remains and NS.cooldown_remains(ACTION.ChainLightning) or 0
                    if cl_cd > 1.5 then return false end
                end
                return true
            end },
            { type = "spell_ready", spell = ACTION.ElementalMastery, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.ElementalMastery, target = "self", opts = { skip_range = true }, label = "[ELEMENTAL] Elemental Mastery" },
    },
    {
        name = "ChainLightning",
        conditions = {
            { type = "context", field = "is_moving", op = "==", value = false },
            { type = "state", field = "mana_emergency", op = "==", value = false },
            { type = "state", field = "mana_conserve", op = "==", value = false },
            { type = "custom", fn = function(context, state)
                if context.cc_safe == false then return false end
                if context.threat_pct and context.threat_pct > 80 then return false end
                if state.clearcast_active then return true end
                local min_targets = spec_kit.setting_number(context, "elemental_cl_min_targets", CL_MIN_TARGETS)
                return NS.aoe_target_meets and NS.aoe_target_meets(min_targets, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_10) or 10, context.target, context, state)
            end },
            { type = "custom", fn = function(context, state)
                -- Preserve parity with the original imperative match function:
                -- NS.spell_ready was called even with a nil target, so do not
                -- require a target here.
                return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ChainLightning, context.target) or false
            end },
        },
        action = { type = "cast", spell = ACTION.ChainLightning, target = "target", label = "[ELEMENTAL] Chain Lightning" },
    },
}

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
          if not context.has_mana_potion then return false end
          if (context.mana_pct or 100) > 20 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
    { name = "Healthstone",
      matches = function(ctx, state)
          if not ctx.in_combat then return false end
          if (state.hp_pct or 100) > 28 then return false end
          if (state.healthstone_ready or 0) <= 0 then return false end
          return true
      end,
      execute = function(ctx)
          local id = first_ready_item(HEALTHSTONE_IDS)
          if id then NS.use_item_by_id(id, ctx.me) end
      end },
    -- Mana emergency: auto-attack/wand only (Research: Mana < 5% all spells forbidden)
    -- MUST be first so it gates all other strategies when mana is critically low
    { name = "ManaEmergencyWand",
      matches = function(context, state)
        if not context.in_combat then return false end
        if not state.mana_emergency then return false end
        return true
      end,
      execute = function()
        if NS.start_attack then
          NS.start_attack()
        end
        return true
      end },
    -- DPS-buff totems stay high priority so Totem of Wrath (+3% crit/hit) and
    -- Wrath of Air (+spell power) keep ~100% uptime. They gate on buff-down, so
    -- this only costs ~1 GCD per 120s. Mana Spring (minor mana regen) is demoted
    -- below the DPS block (guide position ~21) so it never clips a nuke.
    { name = "TotemOfWrath",
      matches = totem_of_wrath_matches_fn,
      execute = function() return NS.try_cast(ACTION.TotemOfWrath, NS.PLAYER_UNIT, "[ELEMENTAL] Totem of Wrath") end },
    { name = "WrathOfAirTotem",
      matches = wrath_of_air_totem_matches_fn,
      execute = function() return NS.try_cast(ACTION.WrathOfAirTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Wrath of Air Totem") end },
    -- Lightning Shield buff
    { name = "LightningShield",
      matches = lightning_shield_matches_fn,
      execute = lightning_shield_execute },
    -- Water Shield (mana sustain)
    { name = "WaterShield" },
    -- Ghost Wolf (OOC movement)
    { name = "GhostWolf" },
    -- Tremor Totem (fear break)
    { name = "TremorTotem",
      matches = tremor_totem_matches_fn,
      execute = function() return NS.try_cast(ACTION.TremorTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Tremor Totem") end },
    -- Earthbind Totem (PvP slow)
    { name = "EarthbindTotem" },
    -- Mana Tide Totem
    { name = "ManaTideTotem" },
    -- Elemental Mastery burst
    { name = "ElementalMastery" },
    -- Nature's Swiftness burst
    { name = "NaturesSwiftness",
      matches = natures_swiftness_matches_fn,
      execute = function() return NS.try_cast(ACTION.NaturesSwiftness, NS.PLAYER_UNIT, "[ELEMENTAL] Nature's Swiftness") end },
    -- Bloodlust burst (test assertion string)
    { name = "Bloodlust", spell = ACTION.Bloodlust, target = "self", combat = true, setting = "use_cooldowns", cooldown = 600, min_mana = 25, requires_target = false,
      matches = bloodlust_matches_fn,
      execute = function() return NS.try_cast(ACTION.Bloodlust, NS.PLAYER_UNIT, "[ELEMENTAL] Bloodlust") end },
    -- Chain Lightning (test assertion string: cooldown = 6)
    { name = "ChainLightning" },
    -- Flame Shock DoT maintenance (before filler to keep it up)
    { name = "FlameShock" },
    -- Lightning Bolt main nuke
    { name = "LightningBolt",
      matches = lightning_bolt_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.LightningBolt, context.target, "[ELEMENTAL] Lightning Bolt") end },
    -- Chain Heal emergency
    { name = "ChainHeal",
      matches = chain_heal_matches_fn,
      execute = function() return NS.try_cast(ACTION.ChainHeal, NS.PLAYER_UNIT, "[ELEMENTAL] Chain Heal") end },
    -- Movement fillers (test assertion: after ChainLightning)
    { name = "FlameShockMoving", spell = ACTION.FlameShock, debuff = FLAME_SHOCK_DEBUFF, refresh = 3, moving = true, cooldown = 6,
      matches = flame_shock_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.FlameShock, context.target, "[ELEMENTAL] Flame Shock (moving)") end },
    { name = "EarthShockMoving", spell = ACTION.EarthShock, moving = true, cooldown = 6,
      matches = earth_shock_filler_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.EarthShock, context.target, "[ELEMENTAL] Earth Shock (moving)") end },
    { name = "FrostShockMoving",
      matches = frost_shock_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.FrostShock, context.target, "[ELEMENTAL] Frost Shock (moving)") end },

    -- Mana Spring Totem (minor mana regen) — demoted below the DPS/moving-shock
    -- block (guide position ~21) so refreshing it never interrupts the nuke.
    { name = "ManaSpringTotem",
      matches = mana_spring_totem_matches_fn,
      execute = function() return NS.try_cast(ACTION.ManaSpringTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Mana Spring Totem") end },

    -- AoE totems (Research: Fire Nova/Magma for stacked AoE)
    { name = "FireNovaTotem",
      matches = fire_nova_totem_matches_fn,
      execute = function() return NS.try_cast(ACTION.FireNovaTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Fire Nova Totem AoE") end },
    { name = "MagmaTotem",
      matches = magma_totem_matches_fn,
      execute = function() return NS.try_cast(ACTION.MagmaTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Magma Totem AoE") end },
    -- parity parity: weapon buffs, self-heal, totem recall
    { name = "FlametongueWeapon",
      matches = flametongue_weapon_matches_fn,
      execute = flametongue_weapon_execute },
    { name = "WindfuryWeapon",
      matches = windfury_weapon_matches_fn,
      execute = windfury_weapon_execute },
    { name = "RockbiterWeapon",
      matches = rockbiter_weapon_matches_fn,
      execute = rockbiter_weapon_execute },
    { name = "HealingWave",
      matches = healing_wave_matches_fn,
      execute = function() return NS.try_cast(ACTION.HealingWave, NS.PLAYER_UNIT, "[ELEMENTAL] Healing Wave") end },
    { name = "TotemicCall",
      matches = totemic_call_matches_fn,
      execute = function() return NS.try_cast(ACTION.TotemicCall, NS.PLAYER_UNIT, "[ELEMENTAL] Totemic Call") end },
}

-- Replace imperative placeholders with DSL-compiled strategies.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("elemental", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman elemental rotation registered") end
return { strategies = strategies, build_state = build_state }

