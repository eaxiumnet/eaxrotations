-- Shaman Restoration group-healing playstyle.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.ShamanSpells or {}
local Healing = NS.ShamanHealing or require("classes/shaman/healing_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { shaman = {} } } end
local TBC_SHAMAN = (TBC.SPELLS and TBC.SPELLS.shaman) or {}

local WATER_SHIELD_SPELL = SPELLS.WaterShield or 33736
local LIGHTNING_SHIELD_SPELL = SPELLS.LightningShield or 25472

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local WATER_SHIELD_BUFF = TBC_SHAMAN.water_shield or { 33736, 24398, 23575 }
local LIGHTNING_SHIELD_BUFF = TBC_SHAMAN.lightning_shield or { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local EARTH_SHIELD_BUFF = { 32594, 32593, 974 }
local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local NATURES_SWIFTNESS_BUFF = { 16188 }
local HEALING_WAY_BUFF = { 29277, 29276, 29275 }

local function _ns_is_active(unit)
    local me = unit or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
    return me and NS.buff_up and NS.buff_up(me, NATURES_SWIFTNESS_BUFF) or false
end

local function _totem_ready(spell)
    local me = (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
    return spell and me and NS.spell_ready and NS.spell_ready(spell, me, { skip_range = true }) or false
end

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
    water_shield_ready = false,
    lightning_shield_ready = false,
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
    resto_state.has_water_shield = me and NS.buff_up and NS.buff_up(me, WATER_SHIELD_BUFF) or false
    resto_state.has_lightning_shield = me and NS.buff_up and NS.buff_up(me, LIGHTNING_SHIELD_BUFF) or false
    resto_state.water_shield_ready = me and NS.spell_ready(SPELLS.WaterShield, me, { skip_range = true }) or false
    resto_state.lightning_shield_ready = me and NS.spell_ready(SPELLS.LightningShield, me, { skip_range = true }) or false
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
    resto_state.mana_tide_ready = me and NS.spell_ready(SPELLS.ManaTideTotem, me, { skip_range = true }) or false
    resto_state.bloodlust_ready = me and NS.spell_ready(SPELLS.Bloodlust, me, { skip_range = true }) or false
    resto_state.natures_swiftness_ready = me and NS.spell_ready(SPELLS.NaturesSwiftness, me, { skip_range = true }) or false
    resto_state.earth_shock_ready = me and NS.spell_ready(SPELLS.EarthShock, me, { expected_cooldown = 6 }) or false
    resto_state.flame_shock_ready = me and NS.spell_ready(SPELLS.FlameShock, me, { expected_cooldown = 6 }) or false
    resto_state.lightning_bolt_ready = me and NS.spell_ready(SPELLS.LightningBolt, me, { expected_cooldown = 2.5 }) or false
    resto_state.chain_lightning_ready = me and NS.spell_ready(SPELLS.ChainLightning, me, { expected_cooldown = 6 }) or false
    resto_state.purge_ready = target and NS.spell_ready(SPELLS.Purge, target) or false
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
    local hw_target = resto_state.tank and resto_state.tank.unit
    resto_state.healing_way_stacks = hw_target and NS.buff_stacks and NS.buff_stacks(hw_target, HEALING_WAY_BUFF) or 0
    resto_state.healing_way_remains = hw_target and NS.buff_remains and NS.buff_remains(hw_target, HEALING_WAY_BUFF) or 0
    resto_state.chain_heal_target_count = Healing.count_below_hp and Healing.count_below_hp(80) or 1
    resto_state.tremor_totem_ready = me and NS.spell_ready(SPELLS.TremorTotem, me, { skip_range = true }) or false
    resto_state.grounding_totem_ready = me and NS.spell_ready(SPELLS.GroundingTotem, me, { skip_range = true }) or false
    resto_state.poison_cleansing_totem_ready = me and SPELLS.PoisonCleansingTotem and NS.spell_ready(SPELLS.PoisonCleansingTotem, me, { skip_range = true }) or false
    resto_state.disease_cleansing_totem_ready = me and SPELLS.DiseaseCleansingTotem and NS.spell_ready(SPELLS.DiseaseCleansingTotem, me, { skip_range = true }) or false
    -- Track lowest ally HP + estimated time-to-die for NS emergency gating
    if resto_state.lowest then
        resto_state.lowest_hp_pct = resto_state.lowest.effective_hp or 100
        resto_state.lowest_time_to_die = resto_state.lowest.time_to_die or 999
    else
        resto_state.lowest_hp_pct = 100
        resto_state.lowest_time_to_die = 999
    end
    -- Resolve cleanse target for dispel strategies (cached per frame)
    resto_state.cleanse_target = Healing.get_cleanse_target and Healing.get_cleanse_target() or nil

    return resto_state
end

local function cooldowns_enabled(context)
    return not context.settings or context.settings.use_cooldowns ~= false
end



-- ============================================================================
-- Match functions
-- ============================================================================
local function water_shield_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.WaterShield, 3.0) then return false end
    local shield_type = (context.settings and context.settings.restoration_shield_type) or "water"
    if shield_type ~= "water" then return false end
    -- Water Shield costs 0 mana and returns mana — allow even during conserve
    -- Only block during mana emergency (ManaEmergencyWand catches it first)
    if state.mana_emergency then return false end
    if not state.water_shield_ready then return false end
    -- Refresh if Water Shield is missing
    if not state.has_water_shield then
        return true
    end
    -- Refresh if Water Shield charges are depleted (0 charges remaining)
    if (state.water_shield_charges or 0) <= 0 then
        return true
    end
    return false
end

local function lightning_shield_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.LightningShield, 3.0) then return false end
    local shield_type = (context.settings and context.settings.restoration_shield_type) or "water"
    if shield_type ~= "lightning" then return false end
    if state.has_lightning_shield then return false end
    if not state.lightning_shield_ready then return false end
    if (state.enemy_count or 0) < 1 then return false end
    return true
end

local function earth_shield_tank_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.EarthShield, 3.0) then return false end
    if state.mana_emergency then return false end
    if not state.tank then return false end
    local target = state.tank.unit or NS.PLAYER_UNIT
    if not target then return false end
    if not state.earth_shield_ready then return false end
    -- Refresh when charges are low (configurable threshold, default ≤ 2)
    local charge_threshold = (context.settings and context.settings.restoration_earth_shield_charge_threshold) or EARTH_SHIELD_CHARGE_DEFAULT
    if NS.buff_up(target, EARTH_SHIELD_BUFF) then
        if (state.earth_shield_charges or 0) > charge_threshold then return false end
        -- Earth Shield is expiring soon and charges are low
        if (state.earth_shield_remains or 0) > 5 and (state.earth_shield_charges or 0) >= 1 then return false end
    end
    return true
end

local function natures_swiftness_matches(context, state)
    if state.mana_emergency then return false end
    if not state.lowest then return false end
    if (state.lowest.effective_hp or 100) > 30 then return false end
    if NS.buff_up and NS.buff_up(NS.PLAYER_UNIT, NATURES_SWIFTNESS_BUFF) then return false end
    local me = context.me or NS.GetPlayer()
    if not me or not NS.spell_ready(SPELLS.NaturesSwiftness, me, { skip_range = true }) then return false end
    if (state.lowest_time_to_die or 999) > 3 then return false end
    return true
end

local function mana_tide_totem_matches(context, state)
    if not cooldowns_enabled(context) then return false end
    if not state.in_combat then return false end
    local threshold = (context.settings and context.settings.restoration_mana_tide_pct) or 60
    -- Self mana must be below threshold
    if (state.mana_pct or 100) > threshold then return false end
    -- Also check group mana if available
    if Healing.group_mana_avg then
        local group_mana = Healing.group_mana_avg()
        if group_mana and group_mana > threshold then return false end
    end
    if Healing.all_members_above_hp and not Healing.all_members_above_hp(80) then return false end
    local me = context.me or NS.GetPlayer()
    if not me or not NS.spell_ready(SPELLS.ManaTideTotem, me, { skip_range = true }) then return false end
    return true
end

local function bloodlust_matches(context, state)
    if not cooldowns_enabled(context) then return false end
    if not state.in_combat then return false end
    if Healing.all_members_above_hp and not Healing.all_members_above_hp(85) then return false end
    local me = context.me or NS.GetPlayer()
    if not me or not NS.spell_ready(SPELLS.Bloodlust, me, { skip_range = true }) then return false end
    return true
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
    return true
end

local function flame_shock_matches(context, state)
    if not state.flame_shock_ready then return false end
    if (state.flame_shock_remains or 0) > 3 then return false end
    if state.mana_conserve then return false end
    if not solo_damage_enabled(context, state, 30) then return false end
    return true
end

local function lightning_bolt_matches(context, state)
    if not state.lightning_bolt_ready then return false end
    if context.is_moving then return false end
    if (state.enemy_count or 0) < 1 then return false end
    if state.mana_emergency then return false end
    if not solo_damage_enabled(context, state, 35) then return false end
    return true
end

local function chain_lightning_matches(context, state)
    if not state.chain_lightning_ready then return false end
    if context.is_moving then return false end
    if (state.enemy_count or 0) < 3 then return false end
    if state.mana_conserve or state.mana_emergency then return false end
    if not solo_damage_enabled(context, state, 45) then return false end
    return true
end

local function purge_matches(context, state)
    if not state.purge_ready then return false end
    if not context.target then return false end
    if not (context.is_pvp == true or context.purge_target == true) then return false end
    return true
end

local function tremor_totem_matches(context, state)
    if not state.tremor_totem_ready then return false end
    if not state.in_combat then return false end
    -- Only drop Tremor if feared/charmed/slept (detected via context flag)
    if not (context.fear_nearby == true) then return false end
    return true
end

local function grounding_totem_matches(context, state)
    if not state.grounding_totem_ready then return false end
    if not state.in_combat then return false end
    if (state.enemy_count or 0) < 1 then return false end
    -- Drop Grounding when facing caster mobs (enemy casting or PvP)
    if not (context.is_pvp == true or context.target_casting == true) then return false end
    return true
end

-- ============================================================================
-- Cure Poison / Cure Disease dispel strategies
-- ============================================================================


local function _get_cleanse_target(state)
    return state and state.cleanse_target
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
    if _totem_ready(SPELLS.StrengthOfEarthTotem) then
        return true
    end
    return false
end

local function totem_mana_spring_matches(context, state)
    if context.settings and context.settings.restoration_manage_totems == false then return false end
    if _totem_ready(SPELLS.ManaSpringTotem) then
        return true
    end
    return false
end

local function totem_grace_air_matches(context, state)
    if context.settings and context.settings.restoration_manage_totems == false then return false end
    if _totem_ready(SPELLS.GraceOfAirTotem) then
        return true
    end
    return false
end

local function totem_windfury_matches(context, state)
    if context.settings and context.settings.restoration_manage_totems == false then return false end
    if _totem_ready(SPELLS.WindfuryTotem) then
        return true
    end
    return false
end

-- ============================================================================
-- Healing Way tracking: cast Healing Wave on tank to maintain stacks
-- ============================================================================
local function healing_way_matches(context, state)
    if not state.tank then return false end
    if (state.healing_way_stacks or 0) >= 3 then return false end
    if (state.healing_way_remains or 0) > 8 then return false end
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
    if not state.lowest or not state.lowest.unit then return false end
    if not state.chain_heal_ready then return false end
    if (state.chain_heal_target_count or 0) < 2 then return false end
    if (state.lowest.effective_hp or 100) > ((context.settings and context.settings.restoration_chain_heal_hp) or 65) then return false end
    -- Predictive overheal gate
    if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
        if NS.HealerDeficit.gate_spell_overheal("ChainHeal", state.lowest.unit, 2.5, context.settings) then return false end
    end
    return true
end

local function chain_heal_execute(context, state)
    if not state.lowest or not state.lowest.unit then return false end
    local target = state.lowest.unit or NS.PLAYER_UNIT
    return NS.try_cast(SPELLS.ChainHeal, target, string.format("[RESTO] ChainHeal %.0f%% (%d targets)", state.lowest.effective_hp or 0, state.chain_heal_target_count))
end

-- ============================================================================
-- Strategies
-- ============================================================================
local healing_strategies = {
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
    { name = "WaterShield", matches = water_shield_matches, execute = function() return NS.try_cast(WATER_SHIELD_SPELL, NS.PLAYER_UNIT, "[RESTO] WaterShield") end },
    { name = "LightningShield", matches = lightning_shield_matches, execute = function() return NS.try_cast(LIGHTNING_SHIELD_SPELL, NS.PLAYER_UNIT, "[RESTO] LightningShield") end },
    { name = "EarthShieldTank", matches = earth_shield_tank_matches, execute = function() return NS.try_cast(SPELLS.EarthShield, NS.PLAYER_UNIT, "[RESTO] EarthShieldTank") end },
    { name = "NaturesSwiftness", matches = natures_swiftness_matches, execute = function()
        return NS.try_cast(SPELLS.NaturesSwiftness, NS.PLAYER_UNIT, "[RESTO] NaturesSwiftness")
    end },
    { name = "ManaTideTotem", matches = mana_tide_totem_matches, execute = function()
        return NS.try_cast(SPELLS.ManaTideTotem, NS.PLAYER_UNIT, "[RESTO] ManaTideTotem", { expected_cooldown = 300 })
    end },
    { name = "Bloodlust", matches = bloodlust_matches, execute = function()
        return NS.try_cast(SPELLS.Bloodlust, NS.PLAYER_UNIT, "[RESTO] Bloodlust", { expected_cooldown = 600 })
    end },
    { name = "HealingWay", matches = healing_way_matches, execute = healing_way_execute },
    { name = "ChainHeal", matches = chain_heal_matches, execute = chain_heal_execute },
    { name = "SmartHeal", matches = smart_heal_matches, execute = function(context, state)
        local heal = context._shaman_heal or Healing.select_heal(context, state, state.lowest)
        if not heal or not heal.spell then return false end
        if not state.lowest or not state.lowest.unit then return false end
        return NS.try_cast(heal.spell, state.lowest.unit, string.format("[RESTO] %s %.0f%%", heal.label, state.lowest.effective_hp or 0))
    end },
    { name = "Purge", matches = purge_matches, execute = function(context) return NS.try_cast(SPELLS.Purge, context.target, "[RESTO] Purge") end },
    { name = "TremorTotem", matches = tremor_totem_matches, execute = function() return NS.try_cast(SPELLS.TremorTotem, NS.PLAYER_UNIT, "[RESTO] TremorTotem") end },
    { name = "GroundingTotem", matches = grounding_totem_matches, execute = function() return NS.try_cast(SPELLS.GroundingTotem, NS.PLAYER_UNIT, "[RESTO] GroundingTotem") end },
    { name = "StrengthOfEarthTotem", matches = totem_strength_matches, execute = function() return NS.try_cast(SPELLS.StrengthOfEarthTotem, NS.PLAYER_UNIT, "[RESTO] StrengthOfEarthTotem") end },
    { name = "ManaSpringTotem", matches = totem_mana_spring_matches, execute = function() return NS.try_cast(SPELLS.ManaSpringTotem, NS.PLAYER_UNIT, "[RESTO] ManaSpringTotem") end },
    { name = "GraceOfAirTotem", matches = totem_grace_air_matches, execute = function() return NS.try_cast(SPELLS.GraceOfAirTotem, NS.PLAYER_UNIT, "[RESTO] GraceOfAirTotem") end },
    { name = "WindfuryTotem", matches = totem_windfury_matches, execute = function() return NS.try_cast(SPELLS.WindfuryTotem, NS.PLAYER_UNIT, "[RESTO] WindfuryTotem") end },
    { name = "CurePoison", matches = cure_poison_matches, execute = function(context, state) local ct = state and state.cleanse_target; local target = ct and ct.unit or NS.PLAYER_UNIT; return NS.try_cast(SPELLS.CurePoison, target, "[RESTO] CurePoison") end },
    { name = "CureDisease", matches = cure_disease_matches, execute = function(context, state) local ct = state and state.cleanse_target; local target = ct and ct.unit or NS.PLAYER_UNIT; return NS.try_cast(SPELLS.CureDisease, target, "[RESTO] CureDisease") end },
    { name = "PoisonCleansingTotem", matches = poison_cleansing_totem_matches, execute = function() return NS.try_cast(SPELLS.PoisonCleansingTotem, NS.PLAYER_UNIT, "[RESTO] PoisonCleansingTotem") end },
    { name = "DiseaseCleansingTotem", matches = disease_cleansing_totem_matches, execute = function() return NS.try_cast(SPELLS.DiseaseCleansingTotem, NS.PLAYER_UNIT, "[RESTO] DiseaseCleansingTotem") end },
}

local idle_dps_strategies = {
    { name = "EarthShock", matches = earth_shock_matches, execute = function(context) return NS.try_cast(SPELLS.EarthShock, context.target, "[RESTO] EarthShock", { expected_cooldown = 6 }) end },
    { name = "FlameShock", matches = flame_shock_matches, execute = function(context) return NS.try_cast(SPELLS.FlameShock, context.target, "[RESTO] FlameShock", { expected_cooldown = 6 }) end },
    { name = "ChainLightning", matches = chain_lightning_matches, execute = function(context) return NS.try_cast(SPELLS.ChainLightning, context.target, "[RESTO] ChainLightning", { expected_cooldown = 6 }) end },
    { name = "LightningBolt", matches = lightning_bolt_matches, execute = function(context) return NS.try_cast(SPELLS.LightningBolt, context.target, "[RESTO] LightningBolt", { expected_cooldown = 2.5 }) end },
}

NS.rotation_registry:register("restoration", healing_strategies, { get_state = build_state })
NS.log("Shaman restoration rotation registered (Tier A)")
local restoration_module = {
    strategies = healing_strategies,
    healing_strategies = healing_strategies,
    idle_dps_strategies = idle_dps_strategies,
}

for index, strategy in ipairs(idle_dps_strategies) do
    restoration_module[index] = strategy
end

return restoration_module
