-- enhancement_sylvanas.lua — Shaman Enhancement rotation for TBC Anniversary (2.5.5).
-- WHAT:  melee priority rotation with per-slot weapon buffs, smart shield auto-swap,
--         totem twisting (Fire Nova cycle + WF/GoA), shock priority, Ghost Wolf OOC.
-- WHEN:  combat with valid enemy target (OOC: weapon buffs, shields, Ghost Wolf).
-- WHY:   mirrors wowsims/tbc enhancement APL + TBC community consensus.
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); registration guarded;
--          no on_update() allocs.
-- DECISION: kept 30 ACTION entries with rank IDs from shaman/class_sylvanas.lua;
--           totem buff IDs (LIGHTNING_SHIELD_BUFF, etc.) remain raw tables.

-- Enhancement rotation — parity feature port v2.0.
-- Features: per-slot weapon buffs, smart shield auto-swap, totem twisting
-- with Fire Nova cycle, shock priority, randomized interrupts, Ghost Wolf OOC

local NS = _G.EaxRotations
if not NS then return nil end
local _cleu = NS.SwingDiagnostics
if _cleu then
    _cleu.register_seals({17364, 30823, 25505, 16362, 8232, 25489, 16342, 8030, 25485, 25479, 16316, 10399, 8019, 8018, 8017, 25500, 16356, 10456, 8038, 8033})
end

local potion_helper = require("shared/potion_helper_sylvanas")
local _planner_ok, planner = pcall(require, "shared/cooldown_planner_sylvanas")
if not _planner_ok or type(planner) ~= "table" then planner = nil end
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")
if not _inv_ok or type(inventory_helper) ~= "table" then inventory_helper = nil end
local SPELLS = NS.ShamanSpells or {}

-- spec_kit migration #21
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Bloodlust           = define("Bloodlust",           { 2825 }, "Bloodlust"),
    ChainHeal            = define("ChainHeal",            { 25423, 25422, 10623, 10622, 1064 }, "ChainHeal"),
    ChainLightning       = define("ChainLightning",       { 25442, 25439, 10605, 2860, 930, 421 }, "ChainLightning"),
    EarthShock           = define("EarthShock",           { 25454, 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, "EarthShock"),
    FireNovaTotem        = define("FireNovaTotem",        { 25547, 25546, 11315, 11314, 8499, 8498, 1535 }, "FireNovaTotem"),
    FlametongueWeapon    = define("FlametongueWeapon",    { 25489, 16342, 16341, 16339, 8030, 8027, 8024 }, "FlametongueWeapon"),
    FlameShock           = define("FlameShock",           { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, "FlameShock"),
    FrostShock            = define("FrostShock",            { 25464, 10473, 10472, 8058, 8056 }, "FrostShock"),
    FrostbrandWeapon     = define("FrostbrandWeapon",     { 25500, 16356, 16355, 10456, 8038, 8033 }, "FrostbrandWeapon"),
    GiftOfTheNaaru       = define("GiftOfTheNaaru",       { 28880 }, "GiftOfTheNaaru"),
    GraceOfAirTotem      = define("GraceOfAirTotem",      { 25359, 10627, 8835 }, "GraceOfAirTotem"),
    GroundingTotem       = define("GroundingTotem",       { 8177 }, "GroundingTotem"),
    HealingStreamTotem   = define("HealingStreamTotem",   { 25567, 10463, 10462, 6377, 6375, 5394 }, "HealingStreamTotem"),
    LesserHealingWave    = define("LesserHealingWave",    { 25420, 10468, 10467, 10466, 8010, 8008, 8004 }, "LesserHealingWave"),
    LightningBolt        = define("LightningBolt",        { 25449, 25448, 15208, 15207, 10392, 10391, 6041, 943, 915, 548, 529, 403 }, "LightningBolt"),
    LightningShield      = define("LightningShield",      { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, "LightningShield"),
    MagmaTotem           = define("MagmaTotem",           { 25552, 10587, 10586, 10585, 8190 }, "MagmaTotem"),
    ManaSpringTotem      = define("ManaSpringTotem",      { 25570, 10497, 10496, 10495, 5675 }, "ManaSpringTotem"),
    ManaTideTotem        = define("ManaTideTotem",        { 16190 }, "ManaTideTotem"),
    NaturesSwiftness     = define("NaturesSwiftness",     { 16188 }, "Nature's Swiftness"),
    Purge                = define("Purge",                { 8012, 370 }, "Purge"),
    RockbiterWeapon      = define("RockbiterWeapon",      { 25485, 25479, 16316, 16315, 16314, 10399, 8019, 8018, 8017 }, "RockbiterWeapon"),
    SearingTotem         = define("SearingTotem",         { 25533, 10438, 10437, 6365, 6364, 6363, 3599 }, "SearingTotem"),
    ShamanisticRage      = define("ShamanisticRage",      { 30823 }, "ShamanisticRage"),
    Stormstrike          = define("Stormstrike",          { 17364 }, "Stormstrike"),
    StrengthOfEarthTotem = define("StrengthOfEarthTotem", { 25528, 25361, 10442, 8161, 8160, 8075 }, "StrengthOfEarthTotem"),
    StoneskinTotem       = define("StoneskinTotem",       { 25509, 25508, 10408, 10407, 10406, 8155, 8154, 8071 }, "StoneskinTotem"),
    TotemicCall          = define("TotemicCall",          { 36936 }, "TotemicCall"),
    WaterShield           = define("WaterShield",           { 33736, 24398, 23575 }, "WaterShield"),
    WindfuryTotem        = define("WindfuryTotem",        { 25587, 25585, 10614, 10613, 8512 }, "WindfuryTotem"),
    WindfuryWeapon       = define("WindfuryWeapon",       { 25505, 16362, 10486, 8235, 8232 }, "WindfuryWeapon"),
}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { shaman = {} } } end
local TBC_SHAMAN = (TBC.SPELLS and TBC.SPELLS.shaman) or {}

local _core = NS and NS.core
local _get_totem_info = _core and _core.spell_book and _core.spell_book.get_totem_info
local _get_visible_objects = _core and _core.object_manager and _core.object_manager.get_visible_objects

-- Totem scan throttle (per-frame API safety)
local _totem_scan_last = 0
local _totem_scan_interval = 1.0
local _totem_scan_result = false

-- Auto-attack helpers: all provided by core_sylvanas.lua (auto_attack_helper bridge).
-- Use NS.is_auto_attacking() and NS.start_auto_attack() instead of direct module require.

-- ============================================================================
-- Constants
-- ============================================================================
local TOTEMIC_CALL_SPELL = { 36936 }
local TOTEM_CALL_DISTANCE = 20           -- yards
local TOTEM_CALL_MAGMA_DISTANCE = 8      -- yards (tighter for Magma)

local LIGHTNING_SHIELD_BUFF = TBC_SHAMAN.lightning_shield or { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local WATER_SHIELD_BUFF = TBC_SHAMAN.water_shield or { 33736, 24398 }
local SHIELD_REFRESH_UNKNOWN_MS = 30000
local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local WINDFURY_WEAPON_SPELLS = { 25505, 16362, 10486, 8235, 8232 }
local FLAMETONGUE_WEAPON_SPELLS = { 25489, 16342, 16341, 16339, 8030, 8027, 8024 }
local ROCKBITER_WEAPON_SPELLS = { 25485, 25479, 16316, 16315, 16314, 10399, 8019, 8018, 8017 }
local FROSTBRAND_WEAPON_SPELLS = { 25500, 16356, 16355, 10456, 8038, 8033 }
local FIRE_RESIST_TOTEM = { 25563, 10538, 10537, 10534, 8181 }
local FROST_RESIST_TOTEM = { 25560, 10542, 8185, 8184, 8182 }
local NATURE_RESIST_TOTEM = { 25574, 10548 }
local GHOST_WOLF_SPELL = { 2645 }
local TREMOR_TOTEM_SPELL = { 8143 }
local SHAMANISTIC_RAGE_BUFF = { 30823 }
local BLOODLUST_BUFF_ID = { 2825 }

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(ids)
    if not inventory_helper then return nil end
    for _, id in ipairs(ids) do
        if inventory_helper.has_item(id) then return id end
    end
    return nil
end

-- ============================================================================
-- Totem state
-- ============================================================================
local totem_state = {
    -- Twisting
    next_air = "windfury",
    twist_phase = "windfury",  -- current active phase ("windfury" or "grace")
    air_totem_remains = 0,
    -- Earth
    -- Water
    -- Fire
    fire_totem_type = "none",
    fire_nova_active = false,
    last_fire_nova_ms = 0,
    -- Shield
    -- Weapon buffs
}

-- ============================================================================
-- State schema (nil-guard defaults for spec_kit.safe_state)
-- ============================================================================
local ENH_SCHEMA = {
    -- Resources
    mana_pct = 100,  hp_pct = 100,  mana_low = false,  mana_emergency = false,
    -- Combat
    in_combat = false,  enemy_count = 1,  is_moving = false,  is_group = false,
    -- Buffs
    has_lightning_shield = false,  has_water_shield = false,
    has_windfury_weapon = false,  has_flametongue_weapon = false,
    has_rockbiter_weapon = false,  has_frostbrand_weapon = false,
    has_shamanistic_rage = false,  has_bloodlust = false,  has_ghost_wolf = false,
    bloodlust_active = false,  major_cd_active = false,  major_cd_window = false,
    -- OH imbues
    oh_has_windfury_weapon = false,  oh_has_flametongue_weapon = false,
    oh_has_rockbiter_weapon = false,  oh_has_frostbrand_weapon = false,
    -- Target
    target_is_casting = false,  target_cast_pct = 0,
    target_can_interrupt = false,  target_is_interruptible = false,
    target_has_flame_shock = false,  flame_shock_remains = 0,
    -- Spell readiness
    lightning_shield_ready = false,  lightning_shield_charges = 0,
    water_shield_ready = false,  stormstrike_ready = false,
    flame_shock_ready = false,  earth_shock_ready = false,  frost_shock_ready = false,
    chain_lightning_ready = false,  lightning_bolt_ready = false,
    windfury_totem_ready = false,  grace_of_air_totem_ready = false,
    strength_of_earth_totem_ready = false,  stoneskin_totem_ready = false,
    mana_spring_totem_ready = false,  healing_stream_totem_ready = false,
    searing_totem_ready = false,  magma_totem_ready = false,
    fire_nova_totem_ready = false,  mana_tide_totem_ready = false,
    shamanistic_rage_ready = false,  natures_swiftness_ready = false,
    lesser_healing_wave_ready = false,  chain_heal_ready = false,
    tremor_totem_ready = false,  grounding_totem_ready = false,
    ghost_wolf_ready = false,  bloodlust_ready = false,
    totemic_call_ready = false,  gift_of_the_naaru_ready = false,
    shadow_totem_ready = false,
    -- Settings
    aoe_threshold = 3,  self_heal_hp = 40,  chain_heal_hp = 35,
    kick_min_pct = 40,  kick_max_pct = 80,
    ghost_wolf_ooc = true,  manage_totems = true,  totem_twisting = true,
    water_shield_mana = 60,  lightning_shield_mana = 80,
    sr_melee_only = false,  hold_shocks_focus = false,
    fs_multi_target = false,  gift_of_the_naaru_enabled = false,
    auto_attack = false,  auto_totemic_call = false,
    -- Items
    healthstone_ready = 0,
}

-- ============================================================================
-- State builder
-- ============================================================================
local enh_state = {
    now_ms = 0,
    -- Buffs
    has_lightning_shield = false,
    has_water_shield = false,
    has_windfury_weapon = false,
    has_flametongue_weapon = false,
    has_rockbiter_weapon = false,
    has_frostbrand_weapon = false,
    has_shamanistic_rage = false,
    has_bloodlust = false,
    has_ghost_wolf = false,
    -- OH weapon imbue (distinct from MH fields)
    oh_has_windfury_weapon = false,
    oh_has_flametongue_weapon = false,
    oh_has_rockbiter_weapon = false,
    oh_has_frostbrand_weapon = false,
    mh_enchant_id = nil,
    oh_enchant_id = nil,
    -- Resources
    mana_pct = 100,
    hp_pct = 100,
    mana_low = false,
    mana_emergency = false,
    in_combat = false,
    enemy_count = 1,
    is_moving = false,
    target_is_casting = false,
    target_cast_pct = 0,
    -- Spell readiness
    lightning_shield_ready = false,
    lightning_shield_charges = 0,
    water_shield_ready = false,
    stormstrike_ready = false,
    flame_shock_ready = false,
    earth_shock_ready = false,
    frost_shock_ready = false,
    chain_lightning_ready = false,
    lightning_bolt_ready = false,
    windfury_totem_ready = false,
    grace_of_air_totem_ready = false,
    strength_of_earth_totem_ready = false,
    stoneskin_totem_ready = false,
    mana_spring_totem_ready = false,
    healing_stream_totem_ready = false,
    searing_totem_ready = false,
    magma_totem_ready = false,
    fire_nova_totem_ready = false,
    mana_tide_totem_ready = false,
    shamanistic_rage_ready = false,
    natures_swiftness_ready = false,
    lesser_healing_wave_ready = false,
    chain_heal_ready = false,
    tremor_totem_ready = false,
    grounding_totem_ready = false,
    ghost_wolf_ready = false,
    bloodlust_ready = false,
    -- Target debuffs
    target_has_flame_shock = false,
    flame_shock_remains = 0,
    target_is_interruptible = false,
    target_can_interrupt = false,
    -- Settings cache
    combat_mode = "auto",
    earth_shock_mode = "interrupts",
    shield_type = "auto",
    aoe_threshold = 3,
    self_heal_hp = 40,
    chain_heal_hp = 35,
    kick_min_pct = 40,
    kick_max_pct = 80,
    ghost_wolf_ooc = true,
    water_shield_mana = 60,
    lightning_shield_mana = 80,
    manage_totems = true,
    totem_twisting = true,
    auto_mh_buff = nil,
    auto_oh_buff = nil,
    auto_shield_type = nil,
    player_level = 70,
    -- Totemic call
    totemic_call_ready = false,
    gift_of_the_naaru_ready = false,
    healthstone_ready = 0,
}

local runtime = {
    last_lightning_shield_ms = -SHIELD_REFRESH_UNKNOWN_MS,
}

-- Level-aware weapon imbue picker (Windfury 30 / Flametongue 10 / Rockbiter 1).
-- Used by auto settings and as a silent-fail fallback when the configured
-- default (windfury) is not yet learned.
local function best_weapon_buff_for_level(level)
    level = level or 70
    if level >= 30 then
        if NS.is_spell_learned and NS.is_spell_learned(ACTION.WindfuryWeapon or 8232) then return "windfury" end
    end
    if level >= 10 then
        if NS.is_spell_learned and NS.is_spell_learned(ACTION.FlametongueWeapon or 8024) then return "flametongue" end
    end
    if NS.is_spell_learned and NS.is_spell_learned(ACTION.RockbiterWeapon or 8017) then return "rockbiter" end
    return "rockbiter"  -- ultimate fallback (available at level 1)
end

local function resolve_weapon_buff(choice, auto_choice, level)
    local resolved = (choice == "auto") and auto_choice or choice
    local spell_map = {
        windfury = ACTION.WindfuryWeapon,
        flametongue = ACTION.FlametongueWeapon,
        rockbiter = ACTION.RockbiterWeapon,
        frostbrand = ACTION.FrostbrandWeapon,
    }
    local spell = spell_map[resolved]
    if spell and NS.is_spell_learned and not NS.is_spell_learned(spell) then
        return best_weapon_buff_for_level(level or 70)
    end
    return resolved
end

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

    -- -- Settings cache (via spec_kit)
    enh_state.combat_mode = spec_kit.setting(context, "enhancement_combat_mode", "auto")
    enh_state.earth_shock_mode = spec_kit.setting(context, "enhancement_earth_shock_mode", "interrupts")
    enh_state.shield_type = spec_kit.setting(context, "enhancement_shield_type", "auto")
    enh_state.aoe_threshold = spec_kit.setting_number(context, "enhancement_aoe_threshold", 3)
    enh_state.self_heal_hp = spec_kit.setting_number(context, "enhancement_self_heal_hp", 40)
    enh_state.chain_heal_hp = spec_kit.setting_number(context, "enhancement_chain_heal_hp", 35)
    enh_state.kick_min_pct = spec_kit.setting_number(context, "enhancement_interrupt_kick_min", 40)
    enh_state.kick_max_pct = spec_kit.setting_number(context, "enhancement_interrupt_kick_max", 80)
    enh_state.ghost_wolf_ooc = spec_kit.setting_bool(context, "enhancement_ghost_wolf_ooc", true)
    enh_state.water_shield_mana = spec_kit.setting_number(context, "enhancement_water_shield_mana", 60)
    enh_state.lightning_shield_mana = spec_kit.setting_number(context, "enhancement_lightning_shield_mana", 80)
    enh_state.manage_totems = spec_kit.setting_bool(context, "enhancement_manage_totems", true)
    enh_state.totem_twisting = spec_kit.setting_bool(context, "enhancement_totem_twisting", true)
    enh_state.interrupt_mode = spec_kit.setting(context, "enhancement_interrupt_mode", "target")
    enh_state.totem_range = spec_kit.setting_number(context, "enhancement_totem_range", 30)
    enh_state.fs_multi_target = spec_kit.setting_bool(context, "enhancement_fs_multi_target", true)
    enh_state.hold_shocks_focus = spec_kit.setting_bool(context, "enhancement_hold_shocks_focus", false)
    enh_state.sr_melee_only = spec_kit.setting_bool(context, "enhancement_sr_melee_only", true)
    enh_state.auto_attack = spec_kit.setting_bool(context, "enhancement_auto_attack", true)
    enh_state.auto_totemic_call = spec_kit.setting_bool(context, "enhancement_auto_totemic_call", true)
    enh_state.gift_of_the_naaru_enabled = spec_kit.setting_bool(context, "enhancement_cd_gift_of_the_naaru", true)

    -- -- Resource state
    enh_state.is_group = context.is_group or false
    enh_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    enh_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    enh_state.now_ms = NS.game_time_ms()
    enh_state.mana_low = enh_state.mana_pct < spec_kit.setting_number(context, "enhancement_mana_low_pct", 20)
    enh_state.mana_emergency = enh_state.mana_pct < spec_kit.setting_number(context, "enhancement_mana_emergency_pct", 10)
    enh_state.in_combat = context.in_combat or false
    enh_state.enemy_count = context.enemy_count or context.enemies_count or 1
    enh_state.is_moving = me and me:is_moving() or false

    -- -- Determine combat mode from auto
    if enh_state.combat_mode == "auto" then
        local auto_aoe = enh_state.enemy_count >= enh_state.aoe_threshold
        enh_state.effective_mode = auto_aoe and "aoe" or "single"
    else
        enh_state.effective_mode = enh_state.combat_mode
    end

    -- -- Player level for auto weapon buff selection
    local player = me or NS.GetPlayer()
    enh_state.player_level = (player and player.get_level and pcall(player.get_level, player) and ({pcall(player.get_level, player)})[2]) or 70
    if type(enh_state.player_level) ~= "number" then enh_state.player_level = 70 end

    -- -- Auto weapon buffs by level (best_weapon_buff_for_level is module-scoped)
    local mh_choice = spec_kit.setting(context, "enhancement_main_hand_ench", "windfury")
    local oh_choice = spec_kit.setting(context, "enhancement_off_hand_ench", "flametongue")
    enh_state.auto_mh_buff = (mh_choice == "auto") and best_weapon_buff_for_level(enh_state.player_level) or mh_choice
    enh_state.auto_oh_buff = (oh_choice == "auto") and best_weapon_buff_for_level(enh_state.player_level) or oh_choice

    -- -- Auto shield type based on mana
    if enh_state.shield_type == "auto" then
        if (enh_state.mana_pct or 100) > 60 then
            enh_state.auto_shield_type = "lightning"
        elseif (enh_state.mana_pct or 100) < 40 then
            enh_state.auto_shield_type = "water"
        else
            -- hysteresis band: keep current shield
            if enh_state.has_lightning_shield then
                enh_state.auto_shield_type = "lightning"
            elseif enh_state.has_water_shield then
                enh_state.auto_shield_type = "water"
            else
                enh_state.auto_shield_type = "lightning"
            end
        end
    else
        enh_state.auto_shield_type = enh_state.shield_type
    end

    -- Water Shield is level 62+; never leave low-level shamans without a shield.
    if enh_state.auto_shield_type == "water" then
        local ws_known = NS.is_spell_learned and NS.is_spell_learned(ACTION.WaterShield)
        if not ws_known then
            enh_state.auto_shield_type = "lightning"
        end
    end

    -- -- Buff detection
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local LIGHTNING_SHIELD_ID = (type(LIGHTNING_SHIELD_BUFF) == "table" and LIGHTNING_SHIELD_BUFF[1]) or 25472
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(LIGHTNING_SHIELD_ID, 3.0) or false
    if not skip_aura then
        enh_state.has_lightning_shield = me and NS.buff_up(me, LIGHTNING_SHIELD_BUFF) or false
        enh_state.lightning_shield_charges = (me and enh_state.has_lightning_shield and type(me.get_buff_stacks) == "function" and me:get_buff_stacks(LIGHTNING_SHIELD_BUFF)) or 0
        enh_state.has_water_shield = me and NS.buff_up(me, WATER_SHIELD_BUFF) or false
        enh_state.has_shamanistic_rage = me and NS.buff_up(me, SHAMANISTIC_RAGE_BUFF) or false
        enh_state.has_bloodlust = me and NS.buff_up(me, BLOODLUST_BUFF_ID) or false
        enh_state.has_ghost_wolf = me and NS.buff_up(me, GHOST_WOLF_SPELL) or false
    end

    -- -- Weapon buff detection via WeaponImbueManager + exact enchant IDs.
    local imbue = NS.WeaponImbueManager
    local mh_has = imbue and type(imbue.mainhand_has_imbue) == "function" and imbue.mainhand_has_imbue()
    local oh_has = imbue and type(imbue.offhand_has_imbue) == "function" and imbue.offhand_has_imbue()
    local mh_info = imbue and type(imbue.get_mainhand_enchant_info) == "function" and imbue.get_mainhand_enchant_info() or nil
    local oh_info = imbue and type(imbue.get_offhand_enchant_info) == "function" and imbue.get_offhand_enchant_info() or nil

    local function match_enchant(info, spell_list)
        if not info or not info.enchant_id or type(spell_list) ~= "table" then return false end
        for i = 1, #spell_list do
            if info.enchant_id == spell_list[i] then return true end
        end
        return false
    end

    if mh_has then
        enh_state.has_windfury_weapon = match_enchant(mh_info, WINDFURY_WEAPON_SPELLS)
        enh_state.has_flametongue_weapon = match_enchant(mh_info, FLAMETONGUE_WEAPON_SPELLS)
        enh_state.has_rockbiter_weapon = match_enchant(mh_info, ROCKBITER_WEAPON_SPELLS)
        enh_state.has_frostbrand_weapon = match_enchant(mh_info, FROSTBRAND_WEAPON_SPELLS)
        enh_state.mh_enchant_id = mh_info and mh_info.enchant_id or nil
    else
        enh_state.has_windfury_weapon = false
        enh_state.has_flametongue_weapon = false
        enh_state.has_rockbiter_weapon = false
        enh_state.has_frostbrand_weapon = false
        enh_state.mh_enchant_id = nil
    end

    if oh_has then
        enh_state.oh_has_flametongue_weapon = match_enchant(oh_info, FLAMETONGUE_WEAPON_SPELLS)
        enh_state.oh_has_windfury_weapon = match_enchant(oh_info, WINDFURY_WEAPON_SPELLS)
        enh_state.oh_has_rockbiter_weapon = match_enchant(oh_info, ROCKBITER_WEAPON_SPELLS)
        enh_state.oh_has_frostbrand_weapon = match_enchant(oh_info, FROSTBRAND_WEAPON_SPELLS)
        enh_state.oh_enchant_id = oh_info and oh_info.enchant_id or nil
    else
        enh_state.oh_has_flametongue_weapon = false
        enh_state.oh_has_windfury_weapon = false
        enh_state.oh_has_rockbiter_weapon = false
        enh_state.oh_has_frostbrand_weapon = false
        enh_state.oh_enchant_id = nil
    end

    -- -- Target state
    enh_state.target_has_flame_shock = target and NS.debuff_up(target, FLAME_SHOCK_DEBUFF) or false
    enh_state.flame_shock_remains = target and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF) or 0
    if target and target.is_casting then
        local ok_casting, casting = pcall(function() return target:is_casting() end)
        enh_state.target_is_casting = ok_casting and casting or false
        local ok, pct = pcall(function() return target:get_cast_pct() end)
        enh_state.target_cast_pct = ok and pct or 0
        local is_interruptible = NS.is_interruptible and NS.is_interruptible(target) or false
        enh_state.target_can_interrupt = enh_state.target_is_casting and is_interruptible
    else
        enh_state.target_is_casting = false
        enh_state.target_cast_pct = 0
        enh_state.target_can_interrupt = false
    end

    -- -- Spell readiness
    enh_state.lightning_shield_ready = me and NS.spell_ready(ACTION.LightningShield, me, { skip_range = true }) or false
    enh_state.water_shield_ready = me and NS.spell_ready(ACTION.WaterShield, me, { skip_range = true }) or false
    enh_state.stormstrike_ready = target and NS.spell_ready(ACTION.Stormstrike, target, { expected_cooldown = 10 }) or false
    enh_state.flame_shock_ready = target and NS.spell_ready(ACTION.FlameShock, target, { expected_cooldown = 6 }) or false
    enh_state.earth_shock_ready = target and NS.spell_ready(ACTION.EarthShock, target, { expected_cooldown = 6 }) or false
    enh_state.frost_shock_ready = target and NS.spell_ready(ACTION.FrostShock, target, { expected_cooldown = 6 }) or false
    enh_state.chain_lightning_ready = target and NS.spell_ready(ACTION.ChainLightning, target, { expected_cooldown = 6 }) or false
    enh_state.lightning_bolt_ready = target and NS.spell_ready(ACTION.LightningBolt, target, { expected_cooldown = 2.5 }) or false
    enh_state.windfury_totem_ready = me and NS.spell_ready(ACTION.WindfuryTotem, me, { skip_range = true }) or false
    enh_state.grace_of_air_totem_ready = me and NS.spell_ready(ACTION.GraceOfAirTotem, me, { skip_range = true }) or false
    enh_state.strength_of_earth_totem_ready = me and NS.spell_ready(ACTION.StrengthOfEarthTotem, me, { skip_range = true }) or false
    enh_state.stoneskin_totem_ready = me and NS.spell_ready(ACTION.StoneskinTotem, me, { skip_range = true }) or false
    enh_state.mana_spring_totem_ready = me and NS.spell_ready(ACTION.ManaSpringTotem, me, { skip_range = true }) or false
    enh_state.healing_stream_totem_ready = me and NS.spell_ready(ACTION.HealingStreamTotem, me, { skip_range = true }) or false
    enh_state.searing_totem_ready = me and NS.spell_ready(ACTION.SearingTotem, me, { skip_range = true }) or false
    enh_state.magma_totem_ready = me and NS.spell_ready(ACTION.MagmaTotem, me, { skip_range = true }) or false
    enh_state.fire_nova_totem_ready = me and NS.spell_ready(ACTION.FireNovaTotem, me, { skip_range = true }) or false
    enh_state.mana_tide_totem_ready = me and NS.spell_ready(ACTION.ManaTideTotem, me, { skip_range = true, expected_cooldown = 300 }) or false
    enh_state.shamanistic_rage_ready = me and NS.spell_ready(ACTION.ShamanisticRage, me, { skip_range = true, expected_cooldown = 120 }) or false
    enh_state.natures_swiftness_ready = me and NS.spell_ready(ACTION.NaturesSwiftness, me, { skip_range = true, expected_cooldown = 180 }) or false
    enh_state.lesser_healing_wave_ready = me and NS.spell_ready(ACTION.LesserHealingWave, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    enh_state.chain_heal_ready = me and NS.spell_ready(ACTION.ChainHeal, me, { skip_range = true }) or false
    enh_state.shadow_totem_ready = false
    enh_state.tremor_totem_ready = me and NS.spell_ready(TREMOR_TOTEM_SPELL, me, { skip_range = true }) or false
    enh_state.grounding_totem_ready = me and NS.spell_ready(ACTION.GroundingTotem, me, { skip_range = true }) or false
    enh_state.ghost_wolf_ready = me and NS.spell_ready(GHOST_WOLF_SPELL, me, { skip_range = true }) or false
    enh_state.bloodlust_ready = me and NS.spell_ready(ACTION.Bloodlust, me, { skip_range = true, expected_cooldown = 600 }) or false
    enh_state.totemic_call_ready = me and NS.spell_ready(ACTION.TotemicCall, me, { skip_range = true, expected_cooldown = 120 }) or false
    enh_state.gift_of_the_naaru_ready = me and NS.spell_ready(ACTION.GiftOfTheNaaru, me, { skip_range = true, expected_cooldown = 120 }) or false

    -- -- Totem phase tracking for twisting (check air slot = 4)
    local air_info = NS.get_totem_info and NS.get_totem_info(4)
    if air_info and air_info.have_totem then
        local air_remains = (air_info.duration or 0) - ((NS.game_time_ms and NS.game_time_ms() or 0) / 1000 - (air_info.start_time or 0))
        if air_remains < 0 then air_remains = 0 end
        totem_state.air_totem_remains = air_remains
        -- Determine current phase from active totem spell_id
        local sid = air_info.spell_id or 0
        local is_wf = false
        local is_grace = false
        for i = 1, #(WINDFURY_WEAPON_SPELLS or {}) do
            if sid == WINDFURY_WEAPON_SPELLS[i] then is_wf = true; break end
        end
        -- Windfury Totem spell IDs differ from weapon imbues; check against totem spell list
        local WF_TOTEM_SPELLS = { 8512, 10607, 10611, 25585, 25587 }
        local GOA_TOTEM_SPELLS = { 8835, 10626, 10627, 25359 }
        for i = 1, #WF_TOTEM_SPELLS do if sid == WF_TOTEM_SPELLS[i] then is_wf = true; break end end
        for i = 1, #GOA_TOTEM_SPELLS do if sid == GOA_TOTEM_SPELLS[i] then is_grace = true; break end end
        if is_wf then totem_state.twist_phase = "windfury"
        elseif is_grace then totem_state.twist_phase = "grace"
        end
    else
        totem_state.air_totem_remains = 0
    end

    -- Prefer CLEU-backed swing timer; fallback to native prediction
    local cleu_remains = (_cleu and _cleu.get_swing_remains and _cleu.get_swing_remains()) or nil
    enh_state.swing_remains = cleu_remains or (NS.get_time_until_swing and NS.get_time_until_swing()) or 0
    enh_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0

    -- Major power-window awareness for cooldown alignment
    enh_state.bloodlust_active = me and NS.buff_up and NS.buff_up(me, BLOODLUST_BUFF_ID) or false
    enh_state.major_cd_active = planner and planner.is_major_offensive_cd_active(context) or false
    enh_state.major_cd_window = enh_state.bloodlust_active or enh_state.major_cd_active

    return spec_kit.safe_state(enh_state, ENH_SCHEMA)
end

-- ============================================================================
-- Helpers
-- ============================================================================
local function can_manage_totems(ctx)
    return enh_state.manage_totems or enh_state.totem_twisting
end

local function totem_active(slot)
    local info = _get_totem_info and _get_totem_info(slot) or nil
    return info and info.have_totem == true
end

local function can_drop_totem(ctx, spell, slot, buff_ids)
    if not can_manage_totems(ctx) then return false end
    if enh_state.mana_low then return false end
    if slot and totem_active(slot) then return false end
    if buff_ids and NS.buff_up and NS.buff_up(NS.PLAYER_UNIT, buff_ids) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(spell, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function cooldowns_enabled(context)
    return spec_kit.setting_bool(context, "use_cooldowns", true)
end

-- v1.2.1: racial match functions
local function blood_fury_matches(ctx)
    if not spec_kit.setting_bool(ctx, "enhancement_cd_blood_fury", true) then return false end
    local me = ctx.me or NS.GetPlayer()
    if not me then return false end
    if not NS.spell_ready({ 33697, 20572 }, me, { skip_range = true }) then return false end
    return true
end

local function berserking_matches(ctx)
    if not spec_kit.setting_bool(ctx, "enhancement_cd_berserking", true) then return false end
    local me = ctx.me or NS.GetPlayer()
    if not me then return false end
    if not NS.spell_ready({ 20554, 26297 }, me, { skip_range = true }) then return false end
    return true
end

-- Tremor Totem (fear/charm/sleep break)
local function tremor_totem_matches(ctx)
    if not enh_state.tremor_totem_ready then return false end
    if not enh_state.in_combat then return false end
    if not ctx.fear_nearby then return false end
    return true
end

-- Grounding Totem (spell absorb for caster mobs / PvP)
local function grounding_totem_matches(ctx)
    if not enh_state.grounding_totem_ready then return false end
    if not enh_state.in_combat then return false end
    if not (ctx.is_pvp == true or enh_state.target_is_casting) then return false end
    return true
end

local function should_interrupt_target(ctx)
    if enh_state.earth_shock_mode ~= "interrupts" then return false end
    if not enh_state.earth_shock_ready then return false end
    -- v1.2.4: Interrupt Mode — Target Only vs Any in Range
    local mode = enh_state.interrupt_mode or "target"
    if mode == "target" then
        -- Target Only: check current target's cast
        if not enh_state.target_can_interrupt then return false end
        local cast_pct = enh_state.target_cast_pct
        local min_pct = enh_state.kick_min_pct
        local max_pct = enh_state.kick_max_pct
        if min_pct >= max_pct then min_pct = max_pct - 10 end
        return cast_pct >= min_pct and cast_pct <= max_pct
    else
        -- Any in Range: accept if any nearby enemy is casting
        -- (detected via combat context; return true to let action_matches handle range)
        return true
    end
end

-- ============================================================================
-- Totem match functions
-- ============================================================================
local function earth_totem_matches(ctx, desired)
    if not can_manage_totems(ctx) then return false end
    if not desired or desired == "none" then return false end
    if desired == "strength" then
        if not enh_state.strength_of_earth_totem_ready then return false end
        return can_drop_totem(ctx, ACTION.StrengthOfEarthTotem, 2, ACTION.StrengthOfEarthTotem)
    elseif desired == "stoneskin" then
        if not enh_state.stoneskin_totem_ready then return false end
        return can_drop_totem(ctx, ACTION.StoneskinTotem, 2, ACTION.StoneskinTotem)
    end
    return false
end

local function water_totem_matches(ctx, desired)
    if not can_manage_totems(ctx) then return false end
    if not desired or desired == "none" then return false end
    if desired == "mana_spring" then
        if not enh_state.mana_spring_totem_ready then return false end
        return can_drop_totem(ctx, ACTION.ManaSpringTotem, 3, ACTION.ManaSpringTotem)
    elseif desired == "healing_stream" then
        if not enh_state.healing_stream_totem_ready then return false end
        return can_drop_totem(ctx, ACTION.HealingStreamTotem, 3, ACTION.HealingStreamTotem)
    end
    return false
end

local function fire_totem_matches(ctx, desired)
    if not can_manage_totems(ctx) then return false end
    if not desired or desired == "none" then return false end

    if desired == "searing" then
        if not enh_state.searing_totem_ready then return false end
        return can_drop_totem(ctx, ACTION.SearingTotem, 1, ACTION.SearingTotem)
    elseif desired == "magma" then
        if not enh_state.magma_totem_ready then return false end
        return can_drop_totem(ctx, ACTION.MagmaTotem, 1, ACTION.MagmaTotem)
    elseif desired == "fire_nova" then
        if not enh_state.fire_nova_totem_ready then return false end
        return can_drop_totem(ctx, ACTION.FireNovaTotem, 1, ACTION.FireNovaTotem)
    elseif desired == "fire_weaving" then
        -- Fire Weaving (Artistry): Prioritize Fire Nova if ready, otherwise Magma
        if enh_state.fire_nova_totem_ready then
            return can_drop_totem(ctx, ACTION.FireNovaTotem, 1, ACTION.FireNovaTotem)
        end
        -- If Nova was dropped recently (within 4s), it's still arming/active. 
        -- Don't replace it yet.
        local ms_since_nova = enh_state.now_ms - (totem_state.last_fire_nova_ms or 0)
        if ms_since_nova < 4000 then return false end
        
        -- Nova is either on CD or already exploded. Use Magma as filler.
        if enh_state.magma_totem_ready then
            return can_drop_totem(ctx, ACTION.MagmaTotem, 1, ACTION.MagmaTotem)
        end
    end
    return false
end

-- Fire Nova replacement: after 4s, drop Magma to replace expired Fire Nova
local function fire_nova_replacement_matches(ctx)
    if not can_manage_totems(ctx) then return false end
    if not totem_state.fire_nova_active then return false end
    if not enh_state.magma_totem_ready then return false end
    
    -- [ARTISTRY] Improved replacement logic:
    -- If we are in "fire_weaving" mode, replacement is handled by the primary fire_totem_resolve.
    if spec_kit.setting(ctx, "enhancement_fire_totem", "searing") == "fire_weaving" then return false end
    
    if ctx.target and NS.debuff_up and NS.debuff_up(ctx.target, FLAME_SHOCK_DEBUFF) then
        return can_drop_totem(ctx, ACTION.MagmaTotem, 1, ACTION.MagmaTotem)
    end
    return false
end

local function windfury_maintain_matches(ctx)
    if not can_manage_totems(ctx) then return false end
    if not enh_state.windfury_totem_ready then return false end
    return can_drop_totem(ctx, ACTION.WindfuryTotem, 4, ACTION.WindfuryTotem)
end

local function windfury_twist_matches(ctx)
    if not enh_state.totem_twisting then return false end
    if not enh_state.in_combat then return false end
    if enh_state.mana_low then return false end
    local mana_floor = spec_kit.setting_number(ctx, "enhancement_twist_mana_threshold", 40)
    if (enh_state.mana_pct or 0) < mana_floor then return false end
    if not enh_state.windfury_totem_ready then return false end
    if totem_state.next_air ~= "windfury" then return false end
    -- Enhanced: only drop when current air totem is expiring (< 3s) or none active
    if (totem_state.air_totem_remains or 0) > 3 then return false end
    return not (NS.buff_up and NS.buff_up(NS.PLAYER_UNIT, ACTION.WindfuryTotem))
end

local function grace_air_twist_matches(ctx)
    if not enh_state.totem_twisting then return false end
    if not enh_state.in_combat then return false end
    if enh_state.mana_low then return false end
    local mana_floor = spec_kit.setting_number(ctx, "enhancement_twist_mana_threshold", 40)
    if (enh_state.mana_pct or 0) < mana_floor then return false end
    if not enh_state.grace_of_air_totem_ready then return false end
    if totem_state.next_air ~= "grace" then return false end
    -- Enhanced: only drop when current air totem is expiring (< 3s) or none active
    if (totem_state.air_totem_remains or 0) > 3 then return false end
    return not (NS.buff_up and NS.buff_up(NS.PLAYER_UNIT, ACTION.GraceOfAirTotem))
end

-- ============================================================================
-- Shield match functions
-- ============================================================================
local function lightning_shield_matches(ctx)
    local shield = enh_state.auto_shield_type or enh_state.shield_type or "auto"
    if shield == "water" then return false end
    if enh_state.has_lightning_shield and (enh_state.lightning_shield_charges or 0) > 1 then return false end
    if enh_state.now_ms - runtime.last_lightning_shield_ms < SHIELD_REFRESH_UNKNOWN_MS then return false end
    if not enh_state.lightning_shield_ready then return false end
    if NS.buff_remains and NS.buff_remains(NS.PLAYER_UNIT, LIGHTNING_SHIELD_BUFF) > 2 then return false end
    -- Auto mode: only maintain Lightning Shield when mana is above threshold
    if shield == "auto" and (enh_state.mana_pct or 0) < (enh_state.lightning_shield_mana or 0) then return false end
    return true
end

local function lightning_shield_execute(ctx)
    if NS.try_cast(ACTION.LightningShield, NS.PLAYER_UNIT, "[ENHANCEMENT] Lightning Shield", { skip_range = true }) then
        runtime.last_lightning_shield_ms = enh_state.now_ms
        return true
    end
    return false
end

local function water_shield_matches(ctx)
    local shield = enh_state.auto_shield_type or enh_state.shield_type or "auto"
    if shield == "lightning" then return false end
    if enh_state.has_water_shield then return false end
    if not enh_state.water_shield_ready then return false end
    if NS.buff_remains and NS.buff_remains(NS.PLAYER_UNIT, WATER_SHIELD_BUFF) > 2 then return false end
    -- Auto mode: switch to Water Shield when mana is low
    if shield == "auto" and (enh_state.mana_pct or 100) >= (enh_state.water_shield_mana or 100) then return false end
    return true
end

local function water_shield_execute(ctx)
    return NS.try_cast(ACTION.WaterShield, NS.PLAYER_UNIT, "[ENHANCEMENT] Water Shield", { skip_range = true }) or false
end

-- ============================================================================
-- Weapon buff match functions (per-slot)
-- ============================================================================
local function mh_weapon_matches(ctx)
    local choice = spec_kit.setting(ctx, "enhancement_main_hand_ench", "windfury")
    if choice == "none" then return false end
    if enh_state.in_combat then return false end
    -- Resolve "auto"/unlearned defaults (e.g. windfury below 30) to a learned imbue
    local resolved = resolve_weapon_buff(choice, enh_state.auto_mh_buff, enh_state.player_level)
    -- Check WeaponImbueManager-based state: if the desired imbue is detected, skip
    local has_imbue = false
    if resolved == "windfury" then has_imbue = enh_state.has_windfury_weapon
    elseif resolved == "flametongue" then has_imbue = enh_state.has_flametongue_weapon
    elseif resolved == "rockbiter" then has_imbue = enh_state.has_rockbiter_weapon
    elseif resolved == "frostbrand" then has_imbue = enh_state.has_frostbrand_weapon
    end
    if has_imbue then return false end
    return true
end

local function oh_weapon_matches(ctx)
    local choice = spec_kit.setting(ctx, "enhancement_off_hand_ench", "flametongue")
    if choice == "none" then return false end
    if enh_state.in_combat then return false end
    -- Resolve "auto"/unlearned defaults to a learned imbue
    local resolved = resolve_weapon_buff(choice, enh_state.auto_oh_buff, enh_state.player_level)
    -- Check WeaponImbueManager-based state: if the desired imbue is detected, skip
    local has_imbue = false
    if resolved == "windfury" then has_imbue = enh_state.oh_has_windfury_weapon
    elseif resolved == "flametongue" then has_imbue = enh_state.oh_has_flametongue_weapon
    elseif resolved == "rockbiter" then has_imbue = enh_state.oh_has_rockbiter_weapon
    elseif resolved == "frostbrand" then has_imbue = enh_state.oh_has_frostbrand_weapon
    end
    if has_imbue then return false end
    return true
end

-- ============================================================================
-- Spell match functions
-- ============================================================================
local function shamanistic_rage_matches(ctx)
    if not enh_state.in_combat then return false end
    if enh_state.has_shamanistic_rage then return false end
    if not enh_state.shamanistic_rage_ready then return false end
    -- v1.2.1: per-CD toggle
    if not spec_kit.setting_bool(ctx, "enhancement_cd_shamanistic_rage", true) then return false end
    if not NS.gate_cooldown_boss_only(ctx) then return false end
    -- TTD gate: don't waste 2min CD on a dying target
    if ctx.ttd_known and ctx.ttd < 8 then return false end
    -- Offensive use: SR converts AP to mana, so fire it during major power windows
    -- (Bloodlust/Heroism, Drums, other major offensive CDs) for sustained output.
    local offensive_use = enh_state.major_cd_window or false
    -- Defensive use: also allow when mana is low or HP is low, but avoid wasting
    -- the cooldown when both are comfortable.
    local defensive_use = (enh_state.mana_pct or 100) <= 40 or (enh_state.hp_pct or 100) <= 40
    if not offensive_use and not defensive_use then return false end
    -- v1.2.4: SR melee range check — only fire if target within 8 yd
    if enh_state.sr_melee_only then
        local target = ctx.target
        if not target then return false end
        local dist = target.get_distance and target:get_distance(NS.PLAYER_UNIT or ctx.me)
        if dist and dist > 8 then return false end
    end
    return true
end

local function bloodlust_matches(ctx)
    if not cooldowns_enabled(ctx) then return false end
    if not spec_kit.setting_bool(ctx, "enhancement_cd_bloodlust", true) then return false end
    if not enh_state.in_combat then return false end
    if enh_state.has_bloodlust then return false end
    if not enh_state.bloodlust_ready then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(ctx, 600) then return false end
    if not NS.gate_cooldown_boss_only(ctx) then return false end
    return true
end

local function mana_tide_totem_matches(ctx)
    if not cooldowns_enabled(ctx) then return false end
    if not spec_kit.setting_bool(ctx, "enhancement_cd_mana_tide", true) then return false end
    if not enh_state.mana_tide_totem_ready then return false end
    if (enh_state.mana_pct or 100) > 60 then return false end
    return true
end

local function natures_swiftness_matches(ctx)
    if not cooldowns_enabled(ctx) then return false end
    if not enh_state.in_combat then return false end
    if not enh_state.natures_swiftness_ready then return false end
    return true
end

--- Primary offensive matches
local function stormstrike_matches(ctx)
    if not enh_state.stormstrike_ready then return false end
    -- Research: Mana < 10%: all spells forbidden (auto-attack only)
    if enh_state.mana_emergency then return false end
    -- Research: Mana < 20%: Stormstrike still allowed, shocks gated separately
    return true
end

local function flame_shock_matches(ctx)
    if not enh_state.flame_shock_ready then return false end
    -- Hold shocks OOC when Shamanistic Focus proc is desired (mana efficiency)
    if enh_state.hold_shocks_focus and not enh_state.in_combat then return false end
    -- Skip shock spending at mana floor — auto-attack conservation (Research: Mana < 20%)
    if enh_state.mana_low then return false end
    -- TTD gate: prefer instant Earth Shock when target is dying (< 6s), skip Flame Shock DoT
    if ctx.ttd_known and ctx.ttd < 6 then return false end
    -- Multi-target FS in AoE: when enabled, apply to any enemy without the DoT
    if enh_state.fs_multi_target and enh_state.effective_mode == "aoe" and enh_state.target_has_flame_shock then
        -- Current target already has FS — skip if there are other targets available (they'll get dotted on tab)
        return false
    end
    -- Refresh when <3s remaining or not active
    if enh_state.target_has_flame_shock and (enh_state.flame_shock_remains or 0) > 3 then return false end
    return true
end

local function earth_shock_matches(ctx)
    -- Interrupt mode
    if enh_state.earth_shock_mode == "interrupts" then
        if not should_interrupt_target(ctx) then return false end
        -- Validate range: Earth Shock has 20yd range; skip if target is out of range
        local target = ctx.target
        if not target then return false end
        local dist = target.get_distance and target:get_distance(NS.PLAYER_UNIT or ctx.me)
        if dist and dist > 20 then return false end
        return NS.spell_ready ~= nil and NS.spell_ready(ACTION.EarthShock, target, { expected_cooldown = 6 }) or false
    end
    -- DPS mode: only cast if Flame Shock DoT is active on target (parity v2.0.1)
    if enh_state.earth_shock_mode == "dps" then
        if not enh_state.earth_shock_ready then return false end
        -- Hold shocks OOC when Shamanistic Focus proc is desired
        if enh_state.hold_shocks_focus and not enh_state.in_combat then return false end
        if enh_state.mana_low then return false end
        -- TTD gate: prefer Earth Shock (instant) when target is dying (< 6s), even without Flame Shock
        local ttd = ctx.ttd
        if ctx.ttd_known and ttd and ttd < 6 then return true end
        -- Endgame: only ES while FS DoT is up. Low-level: FS is level 10 — allow ES alone.
        if not enh_state.target_has_flame_shock then
            local fs_known = NS.is_spell_learned and NS.is_spell_learned(ACTION.FlameShock)
            if fs_known then return false end
        end
        return true
    end
    return false
end

local function frost_shock_matches(ctx)
    if not enh_state.frost_shock_ready then return false end
    -- Hold shocks OOC when Shamanistic Focus proc is desired
    if enh_state.hold_shocks_focus and not enh_state.in_combat then return false end
    if enh_state.mana_low then return false end
    return true
end

local function chain_lightning_matches(ctx)
    if not enh_state.chain_lightning_ready then return false end
    -- AoE mode: CL if enough enemies
    if enh_state.effective_mode == "single" and (enh_state.enemy_count or 0) < 2 then return false end
    return true
end

local function lightning_bolt_matches(ctx)
    if not enh_state.lightning_bolt_ready then return false end
    -- v1.1.5: OOC ranged pulls only — once in combat, commit to melee rotation
    if enh_state.in_combat then return false end
    return true
end

--- Self-heal matches
local function lesser_healing_wave_matches(ctx)
    if not enh_state.lesser_healing_wave_ready then return false end
    if (enh_state.hp_pct or 100) > enh_state.self_heal_hp then return false end
    return true
end

local function chain_heal_matches(ctx)
    if not enh_state.chain_heal_ready then return false end
    if (enh_state.hp_pct or 100) > enh_state.chain_heal_hp then return false end
    return true
end

--- Gift of the Naaru (v1.1.1: Draenei racial heal)
local function gift_of_the_naaru_matches(ctx)
    if not enh_state.gift_of_the_naaru_enabled then return false end
    if not enh_state.gift_of_the_naaru_ready then return false end
    if (enh_state.hp_pct or 100) > enh_state.self_heal_hp then return false end
    return true
end

local function gift_of_the_naaru_execute(ctx)
    return NS.try_cast(ACTION.GiftOfTheNaaru, NS.PLAYER_UNIT, "[ENHANCEMENT] Gift of the Naaru")
end

--- Ghost Wolf OOC
local function ghost_wolf_matches(ctx)
    -- v1.2.1: respect global OOC Buffs toggle
    if not spec_kit.setting_bool(ctx, "use_ooc_buffs", true) then return false end
    if not enh_state.ghost_wolf_ooc then return false end
    if enh_state.in_combat then return false end
    if enh_state.has_ghost_wolf then return false end
    if not enh_state.ghost_wolf_ready then return false end
    if ctx.is_mounted then return false end
    -- Don't shift if we have a target in range
    local target = ctx.target
    local dist = target and target:is_valid() and target:get_distance()
    if dist and dist <= 30 then return false end
    return true
end

-- ============================================================================
-- Totem executes
-- ============================================================================
local function totem_try_cast(spell, label, state_field, state_val)
    return NS.try_cast(spell, NS.PLAYER_UNIT, label, { skip_range = true }) or false
end

local function earth_totem_execute()
    local s = enh_state.earth_totem_desired or "strength"
    if s == "strength" then
        return totem_try_cast(ACTION.StrengthOfEarthTotem, "[ENHANCEMENT] Strength of Earth Totem")
    elseif s == "stoneskin" then
        return totem_try_cast(ACTION.StoneskinTotem, "[ENHANCEMENT] Stoneskin Totem")
    end
    return false
end

local function water_totem_execute()
    local s = enh_state.water_totem_desired or "mana_spring"
    if s == "mana_spring" then
        return totem_try_cast(ACTION.ManaSpringTotem, "[ENHANCEMENT] Mana Spring Totem")
    elseif s == "healing_stream" then
        return totem_try_cast(ACTION.HealingStreamTotem, "[ENHANCEMENT] Healing Stream Totem")
    end
    return false
end

local function fire_totem_execute()
    local s = enh_state.fire_totem_desired or "searing"
    if s == "searing" then
        if totem_try_cast(ACTION.SearingTotem, "[ENHANCEMENT] Searing Totem") then
            totem_state.fire_nova_active = false
            totem_state.fire_totem_type = "searing"
            return true
        end
    elseif s == "magma" then
        if totem_try_cast(ACTION.MagmaTotem, "[ENHANCEMENT] Magma Totem") then
            totem_state.fire_nova_active = false
            totem_state.fire_totem_type = "magma"
            return true
        end
    elseif s == "fire_nova" or s == "fire_weaving" then
        if totem_try_cast(ACTION.FireNovaTotem, "[ENHANCEMENT] Fire Nova Totem") then
            totem_state.fire_nova_active = true
            totem_state.last_fire_nova_ms = enh_state.now_ms
            totem_state.fire_totem_type = "fire_nova"
            return true
        end
    end
    return false
end

local function fire_nova_replacement_execute()
    if totem_try_cast(ACTION.MagmaTotem, "[ENHANCEMENT] Fire Nova -> Magma replacement") then
        totem_state.fire_nova_active = false
        totem_state.fire_totem_type = "magma"
        return true
    end
    return false
end

local function windfury_twist_execute()
    if NS.try_cast(ACTION.WindfuryTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Windfury Totem twist") then
        totem_state.next_air = "grace"
        return true
    end
    return false
end

local function grace_air_twist_execute()
    if NS.try_cast(ACTION.GraceOfAirTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Grace of Air Totem twist") then
        totem_state.next_air = "windfury"
        return true
    end
    return false
end

local function windfury_maintain_execute()
    return NS.try_cast(ACTION.WindfuryTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Windfury Totem", { skip_range = true }) or false
end

local function earth_totem_resolve(ctx)
    local desired = spec_kit.setting(ctx, "enhancement_earth_totem", "strength")
    if earth_totem_matches(ctx, desired) then
        enh_state.earth_totem_desired = desired
        local result = earth_totem_execute()
        return result
    end
    return false
end

local function water_totem_resolve(ctx)
    local desired = spec_kit.setting(ctx, "enhancement_water_totem", "mana_spring")
    if water_totem_matches(ctx, desired) then
        enh_state.water_totem_desired = desired
        local result = water_totem_execute()
        return result
    end
    return false
end

local function fire_totem_resolve(ctx)
    local desired = spec_kit.setting(ctx, "enhancement_fire_totem", "searing")

    -- Check Fire Nova replacement first
    if fire_nova_replacement_matches(ctx) then
        local result = fire_nova_replacement_execute()
        return result
    end

    if fire_totem_matches(ctx, desired) then
        enh_state.fire_totem_desired = desired
        local result = fire_totem_execute()
        return result
    end
    return false
end

-- ============================================================================
-- Weapon buff executes
-- ============================================================================
local function mh_weapon_execute(ctx)
    local choice = spec_kit.setting(ctx, "enhancement_main_hand_ench", "windfury")
    local resolved = resolve_weapon_buff(choice, enh_state.auto_mh_buff, enh_state.player_level)
    local spell_list
    if resolved == "windfury" then spell_list = WINDFURY_WEAPON_SPELLS
    elseif resolved == "flametongue" then spell_list = FLAMETONGUE_WEAPON_SPELLS
    elseif resolved == "rockbiter" then spell_list = ROCKBITER_WEAPON_SPELLS
    elseif resolved == "frostbrand" then spell_list = FROSTBRAND_WEAPON_SPELLS
    else return false end

    return NS.try_cast(spell_list, NS.PLAYER_UNIT, "[ENHANCEMENT] MH " .. resolved) or false
end

local function oh_weapon_execute(ctx)
    local choice = spec_kit.setting(ctx, "enhancement_off_hand_ench", "flametongue")
    local resolved = resolve_weapon_buff(choice, enh_state.auto_oh_buff, enh_state.player_level)
    local spell_list
    if resolved == "windfury" then spell_list = WINDFURY_WEAPON_SPELLS
    elseif resolved == "flametongue" then spell_list = FLAMETONGUE_WEAPON_SPELLS
    elseif resolved == "rockbiter" then spell_list = ROCKBITER_WEAPON_SPELLS
    elseif resolved == "frostbrand" then spell_list = FROSTBRAND_WEAPON_SPELLS
    else return false end

    return NS.try_cast(spell_list, NS.PLAYER_UNIT, "[ENHANCEMENT] OH " .. resolved) or false
end

-- ============================================================================
-- Ghost Wolf execute
-- ============================================================================
local function ghost_wolf_execute()
    return NS.try_cast(GHOST_WOLF_SPELL, NS.PLAYER_UNIT, "[ENHANCEMENT] Ghost Wolf")
end

-- ============================================================================
-- ============================================================================
-- Auto-attack matches
-- ============================================================================

---@param ctx table
---@return boolean
local function auto_attack_matches(ctx)
    if not spec_kit.setting_bool(ctx, "enhancement_auto_attack", true) then return false end
    if not ctx.in_combat then return false end
    local target = ctx.target
    if not target or not target:is_valid() or target:is_dead() then return false end
    if NS.is_auto_attacking and NS.is_auto_attacking(ctx.me) then return false end
    return true
end

local function auto_attack_execute(ctx)
    local target = ctx.target
    if not target then return false end
    return NS.start_auto_attack(target)
end

-- ============================================================================
-- Totemic Call matches (object scanning)
-- ============================================================================

---@param ctx table
---@return boolean
local function totemic_call_matches(ctx)
    if not spec_kit.setting_bool(ctx, "enhancement_auto_totemic_call", true) then return false end
    if not enh_state.totemic_call_ready then return false end

    local me = ctx.me
    if not me then return false end
    local my_pos = me:get_position()
    if not my_pos then return false end

    -- Fast check: any totem slot active?
    local has_totem = false
    for slot = 1, 4 do
        local info = _get_totem_info(slot)
        if info and info.have_totem then
            has_totem = true
            break
        end
    end
    if not has_totem then return false end

    -- Scan visible objects for distant totems (throttled + pcall + bounded)
    -- Filter by get_owner(): only summoned creatures (totems, not players/NPCs) have owners
    -- Lua proxy references can't be compared with ==, so we just check existence (nil-safe)
    local now = (_core and _core.time and _core.time()) or 0
    if now - _totem_scan_last < _totem_scan_interval then
        return _totem_scan_result
    end
    _totem_scan_last = now

    local ok, objects = pcall(_get_visible_objects)
    if not ok or type(objects) ~= "table" then
        _totem_scan_result = false
        return false
    end

    local threshold_sq = TOTEM_CALL_DISTANCE * TOTEM_CALL_DISTANCE  -- 400 (20 yards)
    local max_scan = math.min(#objects, 50)

    for i = 1, max_scan do
        local obj = objects[i]
        if obj and obj:is_valid() then
            -- Skip objects without an owner (players, NPCs, critters)
            local owner = obj:get_owner()
            if owner then
                local obj_pos = obj:get_position()
                if obj_pos then
                    local dx = obj_pos.x - my_pos.x
                    local dy = obj_pos.y - my_pos.y
                    if dx*dx + dy*dy > threshold_sq then
                        _totem_scan_result = true
                        return true  -- Totem too far, recall
                    end
                end
            end
        end
    end

    _totem_scan_result = false
    return false
end

local function totemic_call_execute(ctx)
    return NS.try_cast(ACTION.TotemicCall, NS.PLAYER_UNIT, "[ENHANCEMENT] Totemic Call")
end

-- ============================================================================
-- Declarative strategy DSL definitions (6 strategies)
-- ============================================================================
local DSL_DEFS = {
    {
        name = "ShamanisticRage",
        conditions = {
            { type = "in_combat" },
            { type = "buff", unit = "self", ids = SHAMANISTIC_RAGE_BUFF, invert = true },
            { type = "state", field = "shamanistic_rage_ready", op = "truthy" },
            { type = "setting", key = "enhancement_cd_shamanistic_rage", op = "==", value = true },
            { type = "custom", fn = function(context, state)
                if not NS.gate_cooldown_boss_only(context) then return false end
                if context.ttd_known and context.ttd < 8 then return false end
                local offensive_use = state.major_cd_window or false
                local defensive_use = (state.mana_pct or 100) <= 40 or (state.hp_pct or 100) <= 40
                if not offensive_use and not defensive_use then return false end
                if state.sr_melee_only then
                    local target = context.target
                    if not target then return false end
                    local dist = target.get_distance and target:get_distance(NS.PLAYER_UNIT or context.me)
                    if dist and dist > 8 then return false end
                end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.ShamanisticRage, target = "self", label = "[ENHANCEMENT] Shamanistic Rage", opts = { skip_range = true } },
    },
    {
        name = "Bloodlust",
        conditions = {
            { type = "setting", key = "use_cooldowns", op = "==", value = true, default = true },
            { type = "setting", key = "enhancement_cd_bloodlust", op = "==", value = true, default = true },
            { type = "in_combat" },
            { type = "buff", unit = "self", ids = BLOODLUST_BUFF_ID, invert = true },
            { type = "state", field = "bloodlust_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 600) then return false end
                if not NS.gate_cooldown_boss_only(context) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Bloodlust, target = "self", label = "[ENHANCEMENT] Bloodlust", opts = { skip_range = true } },
    },
    {
        name = "ManaTideTotem",
        conditions = {
            { type = "setting", key = "use_cooldowns", op = "==", value = true, default = true },
            { type = "setting", key = "enhancement_cd_mana_tide", op = "==", value = true, default = true },
            { type = "state", field = "mana_tide_totem_ready", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<=", value = 60 },
        },
        action = { type = "cast", spell = ACTION.ManaTideTotem, target = "self", label = "[ENHANCEMENT] Mana Tide Totem", opts = { skip_range = true } },
    },
    {
        name = "Stormstrike",
        conditions = {
            { type = "state", field = "stormstrike_ready", op = "truthy" },
            { type = "state", field = "mana_emergency", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.Stormstrike, target = "target", label = "[ENHANCEMENT] Stormstrike" },
    },
    {
        name = "FlameShock",
        conditions = {
            { type = "state", field = "flame_shock_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if state.hold_shocks_focus and not state.in_combat then return false end
                return true
            end },
            { type = "state", field = "mana_low", op = "falsy" },
            { type = "custom", fn = function(context, state)
                if context.ttd_known and context.ttd < 6 then return false end
                return true
            end },
            { type = "custom", fn = function(context, state)
                if state.fs_multi_target and state.effective_mode == "aoe" and state.target_has_flame_shock then return false end
                if state.target_has_flame_shock and (state.flame_shock_remains or 0) > 3 then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.FlameShock, target = "target", label = "[ENHANCEMENT] Flame Shock" },
    },
    {
        name = "FrostShock",
        conditions = {
            { type = "state", field = "frost_shock_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if state.hold_shocks_focus and not state.in_combat then return false end
                return true
            end },
            { type = "state", field = "mana_low", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.FrostShock, target = "target", label = "[ENHANCEMENT] Frost Shock" },
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
    -- 0. Mana emergency: auto-attack only, all spells forbidden (Research: Mana < 10%)
    { name = "ManaEmergencyWand",
      matches = function(ctx)
          if not enh_state.in_combat then return false end
          if not enh_state.mana_emergency then return false end
          return true
      end,
      execute = function(ctx)
          local target = ctx.target
          if target and target:is_valid() and not target:is_dead() then
              if not (NS.is_auto_attacking and NS.is_auto_attacking(ctx.me)) then
                  NS.start_auto_attack(target)
              end
          end
          return true
      end
    },

    -- 1. Auto-attack (enforce on combat start)
    { name = "AutoAttack", matches = auto_attack_matches, execute = auto_attack_execute },

    -- 2. Ghost Wolf OOC
    { name = "GhostWolf", matches = ghost_wolf_matches, execute = ghost_wolf_execute },

    -- 3. Totems (priority: Totemic Call -> Fire Nova -> Earth -> Water -> Fire -> Air)
    { name = "TotemicCall", matches = totemic_call_matches, execute = totemic_call_execute },
    { name = "FireNovaReplacement", matches = fire_nova_replacement_matches, execute = fire_nova_replacement_execute },
    { name = "EarthTotem",      matches = function(ctx) return earth_totem_matches(ctx, spec_kit.setting(ctx, "enhancement_earth_totem", "strength")) end, execute = function(ctx) return earth_totem_resolve(ctx) end },
    { name = "WaterTotem", matches = function(ctx) return water_totem_matches(ctx, spec_kit.setting(ctx, "enhancement_water_totem", "mana_spring")) end, execute = function(ctx) return water_totem_resolve(ctx) end },
    { name = "FireTotem", matches = function(ctx) return fire_totem_matches(ctx, spec_kit.setting(ctx, "enhancement_fire_totem", "searing")) end, execute = function(ctx) return fire_totem_resolve(ctx) end },

    -- 4. Air totem (twisting or maintain)
    { name = "WindfuryTotemTwist", matches = windfury_twist_matches, execute = windfury_twist_execute },
    { name = "GraceOfAirTotemTwist", matches = grace_air_twist_matches, execute = grace_air_twist_execute },
    { name = "WindfuryTotemMaintain", matches = windfury_maintain_matches, execute = windfury_maintain_execute },

    -- 5. Weapon buffs (OOC, per-slot)
    { name = "MHWeaponBuff", matches = mh_weapon_matches, execute = mh_weapon_execute },
    { name = "OHWeaponBuff", matches = oh_weapon_matches, execute = oh_weapon_execute },

    -- 6. Shields (smart auto-swap)
    { name = "WaterShield", matches = water_shield_matches, execute = water_shield_execute },
    { name = "LightningShield", matches = lightning_shield_matches, execute = lightning_shield_execute },

    -- 7. Cooldowns
    { name = "ShamanisticRage" },  -- DSL-substituted at runtime
    { name = "Bloodlust" },  -- DSL-substituted at runtime
    { name = "ManaTideTotem" },  -- DSL-substituted at runtime
    { name = "NaturesSwiftness", matches = natures_swiftness_matches, execute = function(ctx) return NS.try_cast(ACTION.NaturesSwiftness, NS.PLAYER_UNIT, "[ENHANCEMENT] Nature's Swiftness", { skip_range = true }) end },

    -- 7b. Utility totems (fear break, spell absorb)
    { name = "TremorTotem", matches = tremor_totem_matches, execute = function(ctx) return NS.try_cast(TREMOR_TOTEM_SPELL, NS.PLAYER_UNIT, "[ENHANCEMENT] Tremor Totem") end },
    { name = "GroundingTotem", matches = grounding_totem_matches, execute = function(ctx) return NS.try_cast(ACTION.GroundingTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Grounding Totem") end },
    { name = "Purge", matches = function(ctx, s) return s.in_combat and s.target and NS.purge_should_cast and NS.purge_should_cast(s.target) end, execute = function(ctx, s) return NS.try_cast(ACTION.Purge, s.target, "[ENHANCEMENT] Purge") end },

    -- v1.2.1: racials
    { name = "BloodFury", matches = blood_fury_matches, execute = function(ctx) return NS.try_cast({ 33697, 20572 }, NS.PLAYER_UNIT, "[ENHANCEMENT] Blood Fury", { skip_range = true }) end },
    { name = "Berserking", matches = berserking_matches, execute = function(ctx) return NS.try_cast({ 20554, 26297 }, NS.PLAYER_UNIT, "[ENHANCEMENT] Berserking", { skip_range = true }) end },

    -- 8. Self-heal
    { name = "GiftOfTheNaaru", matches = gift_of_the_naaru_matches, execute = gift_of_the_naaru_execute },
    { name = "LesserHealingWave", matches = lesser_healing_wave_matches, execute = function(ctx) return NS.try_cast(ACTION.LesserHealingWave, NS.PLAYER_UNIT, "[ENHANCEMENT] Lesser Healing Wave", { skip_range = true }) end },
    { name = "ChainHeal", matches = chain_heal_matches, execute = function(ctx) return NS.try_cast(ACTION.ChainHeal, NS.PLAYER_UNIT, "[ENHANCEMENT] Chain Heal", { skip_range = true }) end },

    -- 9. Offensive priority (parity v2.0.1: Flame Shock first, Earth Shock only while FS active)
    { name = "Stormstrike" },  -- DSL-substituted at runtime
    { name = "FlameShock" },  -- DSL-substituted at runtime
    { name = "EarthShock", matches = earth_shock_matches, execute = function(ctx) return NS.try_cast(ACTION.EarthShock, ctx.target, "[ENHANCEMENT] Earth Shock") end },
    { name = "FrostShock" },  -- DSL-substituted at runtime

    -- 10. AoE / filler
    { name = "ChainLightning", matches = chain_lightning_matches, execute = function(ctx) return NS.try_cast(ACTION.ChainLightning, ctx.target, "[ENHANCEMENT] Chain Lightning") end },
    { name = "LightningBolt", matches = lightning_bolt_matches, execute = function(ctx) return NS.try_cast(ACTION.LightningBolt, ctx.target, "[ENHANCEMENT] Lightning Bolt") end },
}

-- Replace imperative match functions with DSL-compiled equivalents.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("enhancement", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman enhancement rotation registered") end
-- Shaman enhancement rotation registered (parity v2.0 port, spec_kit #21)
return { strategies = strategies, build_state = build_state }
