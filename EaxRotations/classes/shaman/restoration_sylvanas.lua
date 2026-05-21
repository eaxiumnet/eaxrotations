-- Shaman Restoration group-healing playstyle.
-- ============================================================================
-- What: TBC Shaman Restoration healing rotation with shields, mana tools, and totem upkeep
-- When: Per tick
-- Why: Healing triage depends on cached shield, cooldown, and totem state
-- Safety: Local timers are cached; NS/core helpers are nil-guarded; conservative defaults when APIs fail
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.ShamanSpells or {}
local Healing = NS.ShamanHealing or require("classes/shaman/healing_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { shaman = {} } } end
local TBC_SHAMAN = (TBC.SPELLS and TBC.SPELLS.shaman) or {}

-- Cache core.time for tracking
local _core_time = NS.time_now or (NS.core and NS.core.time) or (rawget(_G, "core") and _G.core.time) or function() return 0 end

-- ============================================================================
-- Self-managed buff/cooldown tracking
-- Bypasses broken NS.buff_up() (unit:has_buff/buff_up/get_buff_data all fail)
-- ============================================================================

-- Shield tracking (duration 10 min)
local SHIELD_DURATION = 600
local WATER_SHIELD_SPELL = SPELLS.WaterShield or 33736
local LIGHTNING_SHIELD_SPELL = SPELLS.LightningShield or 25472
local _last_shield_id = 0
local _last_shield_time = 0

local function _shield_active(spell_id)
    if _last_shield_id == 0 then return false end
    if _core_time() - _last_shield_time >= SHIELD_DURATION then
        _last_shield_id = 0
        return false
    end
    return _last_shield_id == spell_id
end

local function _set_shield(spell_id)
    _last_shield_id = spell_id
    _last_shield_time = _core_time()
end

-- Bloodlust tracking (10 min Sated debuff duration)
local BLOODLUST_CD = 600
local _last_bloodlust_time = -600  -- Ready immediately on fresh load
local function _bloodlust_ready()
    return _core_time() - _last_bloodlust_time >= BLOODLUST_CD
end
local function _set_bloodlust()
    _last_bloodlust_time = _core_time()
end

-- Mana Tide tracking (5 min cooldown)
local MANA_TIDE_CD = 300
local _last_mana_tide_time = -300  -- Ready immediately on fresh load
local function _mana_tide_ready()
    return _core_time() - _last_mana_tide_time >= MANA_TIDE_CD
end
local function _set_mana_tide()
    _last_mana_tide_time = _core_time()
end

-- Nature's Swiftness tracking (3 min cooldown, consumed on next heal)
local NS_CD = 180
local _ns_active_time = 0
local _last_ns_time = -999
local function _ns_is_active()
    return _core_time() - _ns_active_time < 3  -- 3 second window for NS to be consumed
end
local function _ns_ready()
    return _core_time() - _last_ns_time >= NS_CD
end
local function _set_ns()
    _last_ns_time = _core_time()
    _ns_active_time = _core_time()
end

-- Totem duration tracking (2 min for most totems)
local TOTEM_DURATION = 120
local _last_totem_times = {}
local function _totem_ready(spell_id)
    local last = _last_totem_times[spell_id]
    if not last then return true end
    if _core_time() - last >= TOTEM_DURATION then
        _last_totem_times[spell_id] = nil
        return true
    end
    return false
end
local function _set_totem(spell_id)
    _last_totem_times[spell_id] = _core_time()
end

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local WATER_SHIELD_BUFF = TBC_SHAMAN.water_shield or { 33736, 24398, 23575 }
local LIGHTNING_SHIELD_BUFF = TBC_SHAMAN.lightning_shield or { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local EARTH_SHIELD_BUFF = { 32594, 32593, 974 }
local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local NATURES_SWIFTNESS_BUFF = { 16188 }
local HEALING_WAY_BUFF = { 29277, 29276, 29275 }

-- Mana conservation tier defaults (configurable via schema)
local MANA_LOW_DEFAULT = 30
local MANA_CONSERVE_DEFAULT = 15
local MANA_EMERGENCY_DEFAULT = 5
-- Earth Shield charge refresh threshold
local EARTH_SHIELD_CHARGE_DEFAULT = 2

-- ============================================================================
-- State builder
-- ============================================================================
local resto_state = {
    lowest = nil,
    tank = nil,
    natures_swiftness_active = false,
    has_water_shield = false,
    has_lightning_shield = false,
    earth_shield_ready = false,
    earth_shield_charges = 0,
    earth_shield_remains = 0,
    water_shield_charges = 0,
    chain_heal_ready = false,
    healing_wave_ready = false,
    lesser_healing_wave_ready = false,
    mana_tide_ready = false,
    bloodlust_ready = false,
    natures_swiftness_ready = false,
    earth_shock_ready = false,
    flame_shock_ready = false,
    lightning_bolt_ready = false,
    chain_lightning_ready = false,
    purge_ready = false,
    cure_poison_ready = false,
    cure_disease_ready = false,
    mana_pct = 100,
    hp_pct = 100,
    mana_low = false,
    mana_conserve = false,
    mana_emergency = false,
    in_combat = false,
    enemy_count = 1,
    target_casting = false,
    flame_shock_remains = 0,
    healing_way_stacks = 0,
    healing_way_remains = 0,
    chain_heal_target_count = 0,
    tremor_totem_ready = false,
    grounding_totem_ready = false,
    poison_cleansing_totem_ready = false,
    disease_cleansing_totem_ready = false,
    cleanse_target = nil,
    lowest_hp_pct = 100,
    lowest_time_to_die = 999,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    if not me then return resto_state end
    -- Mounted bail: healer should not queue buffs/heals while mounted
    if me.is_mounted and me:is_mounted() then
        return resto_state
    end
    local target = context.target
    local entries, count = Healing.scan_healing_targets()

    resto_state.lowest = NS.healing_get_lowest_hp(entries, count, 92)
    resto_state.tank = NS.healing_get_tank(entries, count) or resto_state.lowest
    local s = context.settings or {}
    resto_state.natures_swiftness_active = _ns_is_active()
    resto_state.has_water_shield = _shield_active(WATER_SHIELD_SPELL)
    resto_state.has_lightning_shield = _shield_active(LIGHTNING_SHIELD_SPELL)
    resto_state.earth_shield_ready = me and NS.spell_ready(SPELLS.EarthShield, me, { skip_range = true }) or false
    -- Earth Shield charge/remains tracking (for tank)
    local es_target = resto_state.tank and resto_state.tank.unit
    if es_target then
        resto_state.earth_shield_charges = NS.buff_stacks and NS.buff_stacks(es_target, EARTH_SHIELD_BUFF) or 0
        resto_state.earth_shield_remains = NS.buff_remains and NS.buff_remains(es_target, EARTH_SHIELD_BUFF) or 0
    else
        resto_state.earth_shield_charges = 0
        resto_state.earth_shield_remains = 0
    end
    -- Water Shield charge tracking (self)
    resto_state.water_shield_charges = (me and NS.buff_stacks and NS.buff_stacks(me, WATER_SHIELD_BUFF)) or 0
    resto_state.chain_heal_ready = me and NS.spell_ready(SPELLS.ChainHeal, me, { skip_range = true }) or false
    resto_state.healing_wave_ready = me and NS.spell_ready(SPELLS.HealingWave, me, { skip_range = true }) or false
    resto_state.lesser_healing_wave_ready = me and NS.spell_ready(SPELLS.LesserHealingWave, me, { skip_range = true }) or false
    resto_state.mana_tide_ready = _mana_tide_ready() and (me and NS.spell_ready(SPELLS.ManaTideTotem, me, { skip_range = true }) or false)
    resto_state.bloodlust_ready = _bloodlust_ready() and (me and NS.spell_ready(SPELLS.Bloodlust, me, { skip_range = true }) or false)
    resto_state.natures_swiftness_ready = _ns_ready() and (me and NS.spell_ready(SPELLS.NaturesSwiftness, me, { skip_range = true }) or false)
    resto_state.earth_shock_ready = me and NS.spell_ready(SPELLS.EarthShock, me, { expected_cooldown = 6 }) or false
    resto_state.flame_shock_ready = me and NS.spell_ready(SPELLS.FlameShock, me, { expected_cooldown = 6 }) or false
    resto_state.lightning_bolt_ready = me and NS.spell_ready(SPELLS.LightningBolt, me, { expected_cooldown = 2.5 }) or false
    resto_state.chain_lightning_ready = me and NS.spell_ready(SPELLS.ChainLightning, me, { expected_cooldown = 6 }) or false
    resto_state.cure_poison_ready = me and SPELLS.CurePoison and NS.spell_ready(SPELLS.CurePoison, me, { skip_range = true }) or false
    resto_state.cure_disease_ready = me and SPELLS.CureDisease and NS.spell_ready(SPELLS.CureDisease, me, { skip_range = true }) or false
    resto_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    resto_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    -- Mana conservation tiers (configurable via schema)
    local mana_low_pct = s.restoration_mana_low_pct or MANA_LOW_DEFAULT
    local mana_conserve_pct = s.restoration_mana_conserve_pct or MANA_CONSERVE_DEFAULT
    local mana_emergency_pct = s.restoration_mana_emergency_pct or MANA_EMERGENCY_DEFAULT
    resto_state.mana_low = resto_state.mana_pct < mana_low_pct
    resto_state.mana_conserve = resto_state.mana_pct < mana_conserve_pct
    resto_state.mana_emergency = resto_state.mana_pct < mana_emergency_pct
    resto_state.in_combat = context.in_combat or false
    resto_state.enemy_count = context.enemy_count or context.enemies_count or 1
    resto_state.target_casting = target and target.is_casting and target:is_casting() or false
    resto_state.flame_shock_remains = target and NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF) or 0
    resto_state.healing_way_stacks = resto_state.tank and NS.buff_stacks and NS.buff_stacks(resto_state.tank.unit, HEALING_WAY_BUFF) or 0
    resto_state.healing_way_remains = resto_state.tank and NS.buff_remains and NS.buff_remains(resto_state.tank.unit, HEALING_WAY_BUFF) or 0
    resto_state.chain_heal_target_count = Healing.count_below_hp and Healing.count_below_hp(80) or 1
    resto_state.tremor_totem_ready = me and NS.spell_ready(SPELLS.TremorTotem, me, { skip_range = true }) or false
    resto_state.grounding_totem_ready = me and NS.spell_ready(SPELLS.GroundingTotem, me, { skip_range = true }) or false
    resto_state.poison_cleansing_totem_ready = me and SPELLS.PoisonCleansingTotem and NS.spell_ready(SPELLS.PoisonCleansingTotem, me, { skip_range = true }) or false
    resto_state.disease_cleansing_totem_ready = me and SPELLS.DiseaseCleansingTotem and NS.spell_ready(SPELLS.DiseaseCleansingTotem, me, { skip_range = true }) or false
    -- Track lowest ally HP + estimated time-to-die for NS emergency gating
    if resto_state.lowest then
        resto_state.lowest_hp_pct = resto_state.lowest.effective_hp or 100
        resto_state.lowest_time_to_die = (resto_state.lowest.incoming_dps or 0) > 0
            and (resto_state.lowest.effective_hp or 100) / (resto_state.lowest.incoming_dps or 1)
            or 999
    end
    -- Resolve cleanse target for dispel strategies (cached per frame)
    resto_state.cleanse_target = Healing.get_cleanse_target and Healing.get_cleanse_target() or nil

    return resto_state
end

local function cooldowns_enabled(context)
    return not context.settings or context.settings.use_cooldowns ~= false
end

-- ============================================================================
-- Action definitions
-- ============================================================================
local WATER_SHIELD_ACTION = { name = "WaterShield", spell = WATER_SHIELD_SPELL, target = "self", kind = "buff", buff = WATER_SHIELD_BUFF, requires_target = false }
local LIGHTNING_SHIELD_ACTION = { name = "LightningShield", spell = LIGHTNING_SHIELD_SPELL, target = "self", kind = "buff", buff = LIGHTNING_SHIELD_BUFF, requires_target = false }
local EARTH_SHIELD_ACTION = { name = "EarthShieldTank", spell = SPELLS.EarthShield, target = "self", kind = "buff", buff = EARTH_SHIELD_BUFF, requires_target = false }
local CHAIN_HEAL_ACTION = { name = "ChainHeal", spell = SPELLS.ChainHeal, target = "self", requires_target = false }
local HEALING_WAVE_ACTION = { name = "HealingWave", spell = SPELLS.HealingWave, target = "self", requires_target = false }
local LESSER_HEALING_WAVE_ACTION = { name = "LesserHealingWave", spell = SPELLS.LesserHealingWave, target = "self", requires_target = false }
local MANA_TIDE_ACTION = { name = "ManaTideTotem", spell = SPELLS.ManaTideTotem, target = "self", cooldown = 300, requires_target = false }
local BLOODLUST_ACTION = { name = "Bloodlust", spell = SPELLS.Bloodlust, target = "self", cooldown = 600, requires_target = false }
local NATURES_SWIFTNESS_ACTION = { name = "NaturesSwiftness", spell = SPELLS.NaturesSwiftness, target = "self", requires_target = false }
local EARTH_SHOCK_ACTION = { name = "EarthShock", spell = SPELLS.EarthShock, cooldown = 6 }
local FLAME_SHOCK_ACTION = { name = "FlameShock", spell = SPELLS.FlameShock, cooldown = 6 }
local LIGHTNING_BOLT_ACTION = { name = "LightningBolt", spell = SPELLS.LightningBolt, cooldown = 2.5, not_moving = true }
local CHAIN_LIGHTNING_ACTION = { name = "ChainLightning", spell = SPELLS.ChainLightning, cooldown = 6, not_moving = true }
local PURGE_ACTION = { name = "Purge", spell = SPELLS.Purge, target = "self", requires_target = false }
local TOTEM_STRENGTH_ACTION = { name = "StrengthOfEarthTotem", spell = SPELLS.StrengthOfEarthTotem, target = "self", requires_target = false }
local TOTEM_MANA_SPRING_ACTION = { name = "ManaSpringTotem", spell = SPELLS.ManaSpringTotem, target = "self", requires_target = false }
local TOTEM_GRACE_AIR_ACTION = { name = "GraceOfAirTotem", spell = SPELLS.GraceOfAirTotem, target = "self", requires_target = false }
local TOTEM_WINDFURY_ACTION = { name = "WindfuryTotem", spell = SPELLS.WindfuryTotem, target = "self", requires_target = false }
local TREMOR_TOTEM_ACTION = { name = "TremorTotem", spell = SPELLS.TremorTotem, target = "self", requires_target = false }
local GROUNDING_TOTEM_ACTION = { name = "GroundingTotem", spell = SPELLS.GroundingTotem, target = "self", requires_target = false }

-- ============================================================================
-- Match functions
-- ============================================================================
local function water_shield_matches(context, state)
    local shield_type = (context.settings and context.settings.restoration_shield_type) or "water"
    if shield_type ~= "water" then return false end
    -- Water Shield costs 0 mana and returns mana — allow even during conserve
    -- Only block during mana emergency (ManaEmergencyWand catches it first)
    if state.mana_emergency then return false end
    -- Refresh if Water Shield is missing
    if not state.has_water_shield then
        return NS.action_matches(context, WATER_SHIELD_ACTION)
    end
    -- Refresh if Water Shield charges are depleted (0 charges remaining)
    if state.water_shield_charges <= 0 then
        return NS.action_matches(context, WATER_SHIELD_ACTION)
    end
    return false
end

local function lightning_shield_matches(context, state)
    local shield_type = (context.settings and context.settings.restoration_shield_type) or "water"
    if shield_type ~= "lightning" then return false end
    if state.has_lightning_shield then return false end
    if state.enemy_count < 1 then return false end
    return NS.action_matches(context, LIGHTNING_SHIELD_ACTION)
end

local function earth_shield_tank_matches(context, state)
    if state.mana_emergency then return false end
    if not state.tank then return false end
    local target = state.tank.unit or NS.PLAYER_UNIT
    if not target then return false end
    if not state.earth_shield_ready then return false end
    -- Refresh when charges are low (configurable threshold, default ≤ 2)
    local charge_threshold = (context.settings and context.settings.restoration_earth_shield_charge_threshold) or EARTH_SHIELD_CHARGE_DEFAULT
    if NS.buff_up(target, EARTH_SHIELD_BUFF) then
        if state.earth_shield_charges > charge_threshold then return false end
        -- Earth Shield is expiring soon and charges are low
        if state.earth_shield_remains > 5 and state.earth_shield_charges >= 1 then return false end
    end
    return NS.action_matches(context, EARTH_SHIELD_ACTION)
end

local function natures_swiftness_matches(context, state)
    if state.mana_emergency then return false end
    if not state.lowest then return false end
    if (state.lowest.effective_hp or 100) > 30 then return false end
    if state.natures_swiftness_active then return false end
    if not state.natures_swiftness_ready then return false end
    -- Only activate NS if the ally will die before a normal cast completes (~3s for HW)
    if state.lowest_time_to_die > 3 then return false end
    return NS.action_matches(context, NATURES_SWIFTNESS_ACTION)
end

local function mana_tide_totem_matches(context, state)
    if not cooldowns_enabled(context) then return false end
    if not state.in_combat then return false end
    local threshold = (context.settings and context.settings.restoration_mana_tide_pct) or 60
    -- Self mana must be below threshold
    if state.mana_pct > threshold then return false end
    -- Also check group mana if available
    if Healing.group_mana_avg then
        local group_mana = Healing.group_mana_avg()
        if group_mana and group_mana > threshold then return false end
    end
    if Healing.all_members_above_hp and not Healing.all_members_above_hp(80) then return false end
    if not state.mana_tide_ready then return false end
    return NS.action_matches(context, MANA_TIDE_ACTION)
end

local function bloodlust_matches(context, state)
    if not cooldowns_enabled(context) then return false end
    if not state.in_combat then return false end
    if Healing.all_members_above_hp and not Healing.all_members_above_hp(85) then return false end
    if not state.bloodlust_ready then return false end
    return NS.action_matches(context, BLOODLUST_ACTION)
end

local function smart_heal_matches(context, state)
    if not state.lowest then return false end
    local heal = Healing.select_heal(context, state, state.lowest)
    context._shaman_heal = heal
    return heal and heal.spell and NS.spell_ready(heal.spell, state.lowest.unit)
end

local function solo_damage_enabled(context, state, mana_floor)
    if not context.has_valid_enemy_target then return false end
    local settings = context.settings or {}
    if not (context.is_solo == true or context.is_leveling == true or settings.restoration_dps_when_idle == true) then return false end
    if state.lowest and (state.lowest.effective_hp or 100) < (settings.restoration_idle_hp or 88) then return false end
    if (state.mana_pct or context.mana_pct or 100) < (mana_floor or settings.restoration_dps_mana_floor or 35) then return false end
    return true
end

local function earth_shock_matches(context, state)
    if not state.earth_shock_ready then return false end
    if not state.target_casting then return false end
    if state.mana_emergency then return false end
    -- Range check: Earth Shock is 20yd; validate target is in range
    local target = context.target
    if target and NS.unit_distance then
        local dist_sq = NS.unit_distance(context.me, target)
        if dist_sq and dist_sq > 400 then return false end  -- 20yd squared = 400
    end
    return NS.action_matches(context, EARTH_SHOCK_ACTION)
end

local function flame_shock_matches(context, state)
    if not state.flame_shock_ready then return false end
    if state.flame_shock_remains > 3 then return false end
    if state.mana_conserve then return false end
    if not solo_damage_enabled(context, state, 30) then return false end
    return NS.action_matches(context, FLAME_SHOCK_ACTION)
end

local function lightning_bolt_matches(context, state)
    if not state.lightning_bolt_ready then return false end
    if context.is_moving then return false end
    if state.enemy_count < 1 then return false end
    if state.mana_emergency then return false end
    if not solo_damage_enabled(context, state, 35) then return false end
    return NS.action_matches(context, LIGHTNING_BOLT_ACTION)
end

local function chain_lightning_matches(context, state)
    if not state.chain_lightning_ready then return false end
    if context.is_moving then return false end
    if state.enemy_count < 3 then return false end
    if state.mana_conserve or state.mana_emergency then return false end
    if not solo_damage_enabled(context, state, 45) then return false end
    return NS.action_matches(context, CHAIN_LIGHTNING_ACTION)
end

local function purge_matches(context, state)
    if not state.purge_ready then return false end
    return NS.action_matches(context, PURGE_ACTION)
end

local function tremor_totem_matches(context, state)
    if not state.tremor_totem_ready then return false end
    if not state.in_combat then return false end
    -- Only drop Tremor if feared/charmed/slept (detected via context flag)
    if not (context.fear_nearby == true) then return false end
    return NS.action_matches(context, TREMOR_TOTEM_ACTION)
end

local function grounding_totem_matches(context, state)
    if not state.grounding_totem_ready then return false end
    if not state.in_combat then return false end
    if state.enemy_count < 1 then return false end
    -- Drop Grounding when facing caster mobs (enemy casting or PvP)
    if not (context.is_pvp == true or context.target_casting == true) then return false end
    return NS.action_matches(context, GROUNDING_TOTEM_ACTION)
end

-- ============================================================================
-- Cure Poison / Cure Disease dispel strategies
-- ============================================================================
local CURE_POISON_ACTION = { name = "CurePoison", spell = SPELLS.CurePoison, target = "self", kind = "cleanse", requires_target = false }
local CURE_DISEASE_ACTION = { name = "CureDisease", spell = SPELLS.CureDisease, target = "self", kind = "cleanse", requires_target = false }
local POISON_CLEANSING_TOTEM_ACTION = { name = "PoisonCleansingTotem", spell = SPELLS.PoisonCleansingTotem, target = "self", requires_target = false }
local DISEASE_CLEANSING_TOTEM_ACTION = { name = "DiseaseCleansingTotem", spell = SPELLS.DiseaseCleansingTotem, target = "self", requires_target = false }

local function _get_cleanse_target(state)
    return state and state.cleanse_target
end

local function _cleanse_execute(context, state, action)
    local ct = _get_cleanse_target(state)
    local target = ct and ct.unit or NS.PLAYER_UNIT
    return NS.try_cast(action.spell, target, "[RESTO] " .. (action.name or "cleanse"))
end

local function cure_poison_matches(context, state)
    if not state.cure_poison_ready then return false end
    if state.mana_emergency then return false end
    local dispel_target = _get_cleanse_target(state)
    if not dispel_target then return false end
    if not dispel_target.has_poison then return false end
    if state.lowest and (state.lowest.effective_hp or 100) < 25 then return false end
    return true
end

local function cure_disease_matches(context, state)
    if not state.cure_disease_ready then return false end
    if state.mana_emergency then return false end
    local dispel_target = _get_cleanse_target(state)
    if not dispel_target then return false end
    if not dispel_target.has_disease then return false end
    if state.lowest and (state.lowest.effective_hp or 100) < 25 then return false end
    return true
end

local function poison_cleansing_totem_matches(context, state)
    if not state.poison_cleansing_totem_ready then return false end
    if state.mana_emergency then return false end
    local dispel_target = _get_cleanse_target(state)
    if not dispel_target then return false end
    if not dispel_target.has_poison then return false end
    return true
end

local function disease_cleansing_totem_matches(context, state)
    if not state.disease_cleansing_totem_ready then return false end
    if state.mana_emergency then return false end
    local dispel_target = _get_cleanse_target(state)
    if not dispel_target then return false end
    if not dispel_target.has_disease then return false end
    return true
end

local function totem_strength_matches(context, state)
    if context.settings and context.settings.restoration_manage_totems == false then return false end
    if _totem_ready(SPELLS.StrengthOfEarthTotem) and NS.action_matches(context, TOTEM_STRENGTH_ACTION) then
        return true
    end
    return false
end

local function totem_mana_spring_matches(context, state)
    if context.settings and context.settings.restoration_manage_totems == false then return false end
    if _totem_ready(SPELLS.ManaSpringTotem) and NS.action_matches(context, TOTEM_MANA_SPRING_ACTION) then
        return true
    end
    return false
end

local function totem_grace_air_matches(context, state)
    if context.settings and context.settings.restoration_manage_totems == false then return false end
    if _totem_ready(SPELLS.GraceOfAirTotem) and NS.action_matches(context, TOTEM_GRACE_AIR_ACTION) then
        return true
    end
    return false
end

local function totem_windfury_matches(context, state)
    if context.settings and context.settings.restoration_manage_totems == false then return false end
    if _totem_ready(SPELLS.WindfuryTotem) and NS.action_matches(context, TOTEM_WINDFURY_ACTION) then
        return true
    end
    return false
end

-- ============================================================================
-- Healing Way tracking: cast Healing Wave on tank to maintain stacks
-- ============================================================================
local function healing_way_matches(context, state)
    if not state.tank then return false end
    if state.healing_way_stacks >= 3 then return false end
    if state.healing_way_remains > 8 then return false end
    if not state.healing_wave_ready then return false end
    return NS.spell_ready(SPELLS.HealingWave, state.tank.unit, { skip_range = true })
end

local function healing_way_execute(context, state)
    if not state.tank then return false end
    return NS.try_cast(SPELLS.HealingWave, state.tank.unit, string.format("[RESTO] HealingWay (stack %d/3)", state.healing_way_stacks))
end

-- ============================================================================
-- Standalone Chain Heal: smart multi-target healing
-- ============================================================================
local function chain_heal_matches(context, state)
    if not state.lowest then return false end
    if not state.chain_heal_ready then return false end
    if state.chain_heal_target_count < 2 then return false end
    if (state.lowest.effective_hp or 100) > ((context.settings and context.settings.restoration_chain_heal_hp) or 65) then return false end
    return true
end

local function chain_heal_execute(context, state)
    if not state.lowest then return false end
    local target = state.lowest.unit or NS.PLAYER_UNIT
    return NS.try_cast(SPELLS.ChainHeal, target, string.format("[RESTO] ChainHeal %.0f%% (%d targets)", state.lowest.effective_hp or 0, state.chain_heal_target_count))
end

-- ============================================================================
-- Execute with self-managed tracking update
-- ============================================================================
local function _make_execute(action, label, extra_fn)
    return function(context, state)
        local result = NS.action_execute(context, action, label)
        if result and extra_fn then extra_fn() end
        return result
    end
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    -- Mana emergency: auto-attack only, all spells forbidden (Research: Mana < 5%)
    { name = "ManaEmergencyWand",
        matches = function(context, state)
            if not state.in_combat then return false end
            if not state.mana_emergency then return false end
            return true
        end,
        execute = function(context, state)
            local target = context.target
            if target and NS.start_attack then
                NS.start_attack()
            end
            return true  -- Claim priority, block all other strategies
        end
    },
    { name = "WaterShield", matches = water_shield_matches, execute = _make_execute(WATER_SHIELD_ACTION, "[RESTO]", function() _set_shield(WATER_SHIELD_SPELL) end) },
    { name = "LightningShield", matches = lightning_shield_matches, execute = _make_execute(LIGHTNING_SHIELD_ACTION, "[RESTO]", function() _set_shield(LIGHTNING_SHIELD_SPELL) end) },
    { name = "EarthShieldTank", matches = earth_shield_tank_matches, execute = function(context) return NS.action_execute(context, EARTH_SHIELD_ACTION, "[RESTO]") end },
    { name = "NaturesSwiftness", matches = natures_swiftness_matches, execute = _make_execute(NATURES_SWIFTNESS_ACTION, "[RESTO]", _set_ns) },
    { name = "ManaTideTotem", matches = mana_tide_totem_matches, execute = _make_execute(MANA_TIDE_ACTION, "[RESTO]", _set_mana_tide) },
    { name = "Bloodlust", matches = bloodlust_matches, execute = _make_execute(BLOODLUST_ACTION, "[RESTO]", _set_bloodlust) },
    { name = "HealingWay", matches = healing_way_matches, execute = healing_way_execute },
    { name = "ChainHeal", matches = chain_heal_matches, execute = chain_heal_execute },
	    { name = "SmartHeal", matches = smart_heal_matches, execute = function(context, state)
        local heal = context._shaman_heal or Healing.select_heal(context, state, state.lowest)
        if not heal or not heal.spell then return false end
        return NS.try_cast(heal.spell, state.lowest.unit, string.format("[RESTO] %s %.0f%%", heal.label, state.lowest.effective_hp or 0))
    end },
    { name = "EarthShock", matches = earth_shock_matches, execute = function(context) return NS.action_execute(context, EARTH_SHOCK_ACTION, "[RESTO]") end },
    { name = "FlameShock", matches = flame_shock_matches, execute = function(context) return NS.action_execute(context, FLAME_SHOCK_ACTION, "[RESTO]") end },
    { name = "ChainLightning", matches = chain_lightning_matches, execute = function(context) return NS.action_execute(context, CHAIN_LIGHTNING_ACTION, "[RESTO]") end },
    { name = "LightningBolt", matches = lightning_bolt_matches, execute = function(context) return NS.action_execute(context, LIGHTNING_BOLT_ACTION, "[RESTO]") end },
    { name = "Purge", matches = purge_matches, execute = function(context) return NS.action_execute(context, PURGE_ACTION, "[RESTO]") end },
    { name = "TremorTotem", matches = tremor_totem_matches, execute = function(context) return NS.action_execute(context, TREMOR_TOTEM_ACTION, "[RESTO]") end },
    { name = "GroundingTotem", matches = grounding_totem_matches, execute = function(context) return NS.action_execute(context, GROUNDING_TOTEM_ACTION, "[RESTO]") end },
    { name = "StrengthOfEarthTotem", matches = totem_strength_matches, execute = _make_execute(TOTEM_STRENGTH_ACTION, "[RESTO]", function() _set_totem(SPELLS.StrengthOfEarthTotem) end) },
    { name = "ManaSpringTotem", matches = totem_mana_spring_matches, execute = _make_execute(TOTEM_MANA_SPRING_ACTION, "[RESTO]", function() _set_totem(SPELLS.ManaSpringTotem) end) },
    { name = "GraceOfAirTotem", matches = totem_grace_air_matches, execute = _make_execute(TOTEM_GRACE_AIR_ACTION, "[RESTO]", function() _set_totem(SPELLS.GraceOfAirTotem) end) },
    { name = "WindfuryTotem", matches = totem_windfury_matches, execute = _make_execute(TOTEM_WINDFURY_ACTION, "[RESTO]", function() _set_totem(SPELLS.WindfuryTotem) end) },
    { name = "CurePoison", matches = cure_poison_matches, execute = function(context, state) return _cleanse_execute(context, state, CURE_POISON_ACTION) end },
    { name = "CureDisease", matches = cure_disease_matches, execute = function(context, state) return _cleanse_execute(context, state, CURE_DISEASE_ACTION) end },
    { name = "PoisonCleansingTotem", matches = poison_cleansing_totem_matches, execute = _make_execute(POISON_CLEANSING_TOTEM_ACTION, "[RESTO]") },
    { name = "DiseaseCleansingTotem", matches = disease_cleansing_totem_matches, execute = _make_execute(DISEASE_CLEANSING_TOTEM_ACTION, "[RESTO]") },
}

NS.rotation_registry:register("restoration", strategies, { get_state = build_state })
NS.log("Shaman restoration rotation registered (Tier A)")
return strategies
