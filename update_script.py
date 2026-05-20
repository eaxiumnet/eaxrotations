content = '''-- Shaman Restoration group-healing playstyle.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.ShamanSpells or {}
local Healing = NS.ShamanHealing or require("classes/shaman/healing_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { shaman = {} } } end
local TBC_SHAMAN = (TBC.SPELLS and TBC.SPELLS.shaman) or {}

-- Cache core.time for tracking
local _core_time = core.time

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
local _last_bloodlust_time = 0
local function _bloodlust_ready()
    return _core_time() - _last_bloodlust_time >= BLOODLUST_CD
end
local function _set_bloodlust()
    _last_bloodlust_time = _core_time()
end

-- Mana Tide tracking (5 min cooldown)
local MANA_TIDE_CD = 300
local _last_mana_tide_time = 0
local function _mana_tide_ready()
    return _core_time() - _last_mana_tide_time >= MANA_TIDE_CD
end
local function _set_mana_tide()
    _last_mana_tide_time = _core_time()
end

-- Nature's Swiftness tracking (3 min cooldown, consumed on next heal)
local NS_CD = 180
local _last_ns_time = -999
local function _ns_ready()
    return _core_time() - _last_ns_time >= NS_CD
end
local function _set_ns()
    _last_ns_time = _core_time()
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
    mana_pct = 100,
    hp_pct = 100,
    in_combat = false,
    enemy_count = 1,
    target_casting = false,
    flame_shock_remains = 0,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target
    local entries, count = Healing.scan_healing_targets()

    resto_state.lowest = NS.healing_get_lowest_hp(entries, count, 92)
    resto_state.tank = NS.healing_get_tank(entries, count) or resto_state.lowest
    resto_state.natures_swiftness_active = _shield_active(NATURES_SWIFTNESS_BUFF[1])  -- Fallback: use time-based if buff API broken
    resto_state.has_water_shield = _shield_active(WATER_SHIELD_SPELL)
    resto_state.has_lightning_shield = _shield_active(LIGHTNING_SHIELD_SPELL)
    resto_state.earth_shield_ready = me and NS.spell_ready(SPELLS.EarthShield, me, { skip_range = true }) or false
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
    resto_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    resto_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    resto_state.in_combat = context.in_combat or false
    resto_state.enemy_count = context.enemy_count or context.enemies_count or 1
    resto_state.target_casting = target and target.is_casting and target:is_casting() or false
    resto_state.flame_shock_remains = target and NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF) or 0

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
local NATURES_SWIFTNESS_ACTION = { name = "NaturesSwiftness", spell = SPELLS.NaturesSwiftness,
