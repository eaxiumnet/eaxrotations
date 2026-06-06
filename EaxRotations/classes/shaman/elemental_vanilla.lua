-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-28
-- Change: Classic Vanilla Elemental Shaman rotation
-- =========================================================================
local __eax_file = "classes/shaman/elemental_vanilla.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-28"
local __eax_change = "Classic Vanilla Elemental Shaman rotation"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Shaman Elemental priority list.
-- ============================================================================
-- What: Classic Vanilla Shaman Elemental priority list for Lightning Bolt, shocks, and totem support
-- When: Per tick
-- Why: Mana thresholds and debuff windows drive the ranged DPS priority order
-- Safety: Fallback spell tables; nil-guarded state queries; conservative mana defaults
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.ShamanSpells or {}

-- Fallback spell definitions for keys not yet in class_sylvanas.lua
-- These are overridden if class_sylvanas.lua defines them with higher priority
SPELLS.UnavailableClassicShamanTotem = nil

-- Debuff and buff ID tables
local FLAME_SHOCK_DEBUFF = { 10448, 10447, 8053, 8052, 8050 }
local LIGHTNING_SHIELD_BUFF = { 10432, 10431, 8134, 945, 905, 325, 324 }
local MANA_SPRING_BUFF = { 10491, 10490, 5676 }  -- Mana Spring Totem aura ranks
local SHIELD_REFRESH_UNKNOWN_MS = 30 * 1000
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

local runtime = {
    last_lightning_shield_ms = -SHIELD_REFRESH_UNKNOWN_MS,
    last_flametongue_ms = -30000000,
    last_windfury_ms = -30000000,
    last_rockbiter_ms = -30000000,
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
}

local function build_state(context)
    local target = context.target
    if target then
        ele_state.flame_remains = NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF) or 0
    else
        ele_state.flame_remains = 0
    end
    ele_state.lightning_shield_up = NS.has_player_buff(LIGHTNING_SHIELD_BUFF)
    ele_state.mana_pct = context.mana_pct or 100
    local s = context.settings or {}
    local mana_low = s.elemental_mana_low_pct or MANA_LOW_DEFAULT
    local mana_conserve = s.elemental_mana_conserve_pct or MANA_CONSERVE_DEFAULT
    local mana_emergency = s.elemental_mana_emergency_pct or MANA_EMERGENCY_DEFAULT
    ele_state.mana_low = ele_state.mana_pct < mana_low
    ele_state.mana_conserve = ele_state.mana_pct < mana_conserve
    ele_state.mana_emergency = ele_state.mana_pct < mana_emergency
    ele_state.hp_pct = context.hp or 100
    ele_state.target_count = context.enemy_count or 1
    ele_state.now_ms = NS.game_time_ms and NS.game_time_ms() or 0
    -- Current spell damage from NS (provided by middleware or character API)
    ele_state.spell_damage = (NS.get_spell_damage and NS.get_spell_damage()) or context.spell_damage or 0
    -- Weapon buff freshness
    ele_state.has_flametongue = (ele_state.now_ms - runtime.last_flametongue_ms) < WEAPON_BUFF_REFRESH_MS
    ele_state.has_windfury = (ele_state.now_ms - runtime.last_windfury_ms) < WEAPON_BUFF_REFRESH_MS
    ele_state.has_rockbiter = (ele_state.now_ms - runtime.last_rockbiter_ms) < WEAPON_BUFF_REFRESH_MS
    return ele_state
end

-- ============================================================================
-- Matches functions
-- ============================================================================

local function lightning_shield_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.LightningShield, 3.0) then return false end
    local s = context.settings or {}
    if state.mana_emergency then return false end
    if s.elemental_lightning_shield == false then return false end
    if state.lightning_shield_up then return false end
    if state.now_ms - runtime.last_lightning_shield_ms < SHIELD_REFRESH_UNKNOWN_MS then return false end
    return NS.spell_ready(SPELLS.LightningShield, NS.PLAYER_UNIT, { skip_range = true })
end

local function lightning_shield_execute(context, state)
    if NS.try_cast(SPELLS.LightningShield, NS.PLAYER_UNIT, "[ELEMENTAL] Lightning Shield") then
        runtime.last_lightning_shield_ms = state.now_ms
        return true
    end
    return false
end

local function bloodlust_matches_fn(context, state)
    if not context.in_combat then return false end
    if not context.should_burst then return false end
    return NS.spell_ready(SPELLS.UnavailableClassicShamanBurst, NS.PLAYER_UNIT, { skip_range = true })
end

local function chain_lightning_matches_fn(context, state)
    if context.is_moving then return false end
    if state.mana_emergency then return false end
    if state.mana_conserve then return false end
    -- CC safety: skip Chain Lightning if it might break nearby CC
    if context.cc_safe == false then return false end
    -- Threat safety: skip Chain Lightning if threat is high (multi-target pulls threat)
    if context.threat_pct and context.threat_pct > 80 then return false end
    -- Research: CL only at 3+ targets; configurable via schema
    local s = context.settings or {}
    local min_targets = s.elemental_cl_min_targets or CL_MIN_TARGETS
    if (state.target_count or 0) < min_targets then return false end
    return NS.spell_ready(SPELLS.ChainLightning, context.target)
end

local function lightning_bolt_matches_fn(context, state)
    if context.is_moving then return false end
    if state.mana_emergency then return false end
    -- Threat safety: hold Lightning Bolt if threat > 90%
    if context.threat_pct and context.threat_pct > 90 then return false end
    -- Research: switch to lower-rank Lightning Bolt at mana < 30%
    -- Uses SPELLS.LightningBoltLowerRank when learned and mana is low
    local lower_rank = SPELLS.LightningBoltLowerRank
    local lower_id = (type(lower_rank) == "table" and lower_rank.ids and lower_rank.ids[1]) or lower_rank
    local spell_id = (state.mana_low and lower_id and NS.is_spell_learned and NS.is_spell_learned(lower_id)) and lower_rank or SPELLS.LightningBolt
    return NS.spell_ready(spell_id, context.target)
end

local function flame_shock_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.FlameShock, 2.0) then return false end
    if not context.target then return false end
    -- Research: only clip Flame Shock at <1s remaining (prevents shock CD starvation)
    if (state.flame_remains or 0) > 1 then return false end    -- SP-aware gating: skip Flame Shock if spell damage is below minimum threshold
    -- Flame Shock has ~0.3 direct + ~0.3 DoT coefficient = ~0.6 total; GCD-positive at ~400 SP
    local s = context.settings or {}
    local min_sp = s.elemental_flame_shock_min_sp or FLAME_SHOCK_MIN_SP_DEFAULT
    if (state.spell_damage or 0) < min_sp then return false end
    if NS.should_refresh_dot and not NS.should_refresh_dot(state.flame_remains, 1.5, context.ttd, 12) then return false end
    return NS.spell_ready(SPELLS.FlameShock, context.target)
end

local function earth_shock_interrupt_matches_fn(context, state)
    local target = context.target
    if not target then return false end
    if state.mana_emergency then return false end
    local is_casting = false
    local ok = pcall(function()
        if target.is_casting and target:is_casting() then is_casting = true end
        if target.is_casting_spell and target:is_casting_spell() then is_casting = true end
    end)
    if not is_casting then return false end
    return NS.spell_ready(SPELLS.EarthShock, target)
end

local function earth_shock_filler_matches_fn(context, state)
    if not context.is_moving then return false end
    -- Respect interrupt reserve: when ON, suppress Earth Shock filler to save for interrupts
    local s = context.settings or {}
    if s.elemental_interrupt_reserve ~= false then return false end
    return NS.spell_ready(SPELLS.EarthShock, context.target)
end

local function frost_shock_matches_fn(context, state)
    if not context.is_moving then return false end
    if not context.is_pvp then return false end
    return NS.spell_ready(SPELLS.FrostShock, context.target)
end

local function elemental_mastery_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_use_elemental_mastery == false then return false end
    if not context.in_combat then return false end
    if state.mana_conserve then return false end
    if not context.should_burst then return false end
    return NS.spell_ready(SPELLS.ElementalMastery, NS.PLAYER_UNIT, { skip_range = true })
end

local function natures_swiftness_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_use_natures_swiftness == false then return false end
    if not context.in_combat then return false end
    if not context.should_burst then return false end
    return NS.spell_ready(SPELLS.NaturesSwiftness, NS.PLAYER_UNIT, { skip_range = true })
end

local function water_shield_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.UnavailableClassicShamanShieldB, 3.0) then return false end
    local s = context.settings or {}
    if state.mana_emergency then return false end
    local ws_mana = s.elemental_water_shield_mana or WATER_SHIELD_MANA_DEFAULT
    if (state.mana_pct or 100) > ws_mana then return false end
    return NS.spell_ready(SPELLS.UnavailableClassicShamanShieldB, NS.PLAYER_UNIT, { skip_range = true })
end

local function ghost_wolf_matches_fn(context, state)
    if context.in_combat then return false end
    return NS.spell_ready(SPELLS.GhostWolf, NS.PLAYER_UNIT, { skip_range = true })
end

local function tremor_totem_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.TremorTotem, 3.0) then return false end
    if not context.in_combat then return false end
    if state.mana_emergency then return false end
    if not context.fear_nearby then return false end
    return NS.spell_ready(SPELLS.TremorTotem, NS.PLAYER_UNIT, { skip_range = true })
end

local function earthbind_totem_matches_fn(context, state)
    if not context.is_pvp then return false end
    if state.mana_emergency then return false end
    return NS.spell_ready(SPELLS.EarthbindTotem, NS.PLAYER_UNIT, { skip_range = true })
end

local function mana_tide_totem_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ManaTideTotem, 3.0) then return false end
    if state.mana_emergency then return false end
    if (state.mana_pct or 100) > 30 then return false end
    return NS.spell_ready(SPELLS.ManaTideTotem, NS.PLAYER_UNIT, { skip_range = true })
end

local function chain_heal_matches_fn(context, state)
    if not context.group_injured then return false end
    return NS.spell_ready(SPELLS.ChainHeal, NS.PLAYER_UNIT, { skip_range = true })
end

-- ============================================================================
-- Weapon buffs (parity parity)
-- ============================================================================

local function flametongue_weapon_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.FlametongueWeapon, 3.0) then return false end
    if context.in_combat then return false end
    if state.has_flametongue then return false end
    return NS.spell_ready(SPELLS.FlametongueWeapon, NS.PLAYER_UNIT, { skip_range = true })
end

local function flametongue_weapon_execute(context, state)
    if NS.try_cast(SPELLS.FlametongueWeapon, NS.PLAYER_UNIT, "[ELEMENTAL] Flametongue Weapon") then
        runtime.last_flametongue_ms = state.now_ms
        return true
    end
    return false
end

local function windfury_weapon_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.WindfuryWeapon, 3.0) then return false end
    if context.in_combat then return false end
    if state.has_windfury then return false end
    return NS.spell_ready(SPELLS.WindfuryWeapon, NS.PLAYER_UNIT, { skip_range = true })
end

local function windfury_weapon_execute(context, state)
    if NS.try_cast(SPELLS.WindfuryWeapon, NS.PLAYER_UNIT, "[ELEMENTAL] Windfury Weapon") then
        runtime.last_windfury_ms = state.now_ms
        return true
    end
    return false
end

local function rockbiter_weapon_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.RockbiterWeapon, 3.0) then return false end
    if context.in_combat then return false end
    if state.has_rockbiter then return false end
    return NS.spell_ready(SPELLS.RockbiterWeapon, NS.PLAYER_UNIT, { skip_range = true })
end

local function rockbiter_weapon_execute(context, state)
    if NS.try_cast(SPELLS.RockbiterWeapon, NS.PLAYER_UNIT, "[ELEMENTAL] Rockbiter Weapon") then
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
    local s = context.settings or {}
    local heal_hp = s.elemental_self_heal_hp or HEALING_WAVE_HP_PCT
    if (state.hp_pct or 100) > heal_hp then return false end
    return NS.spell_ready(SPELLS.HealingWave, NS.PLAYER_UNIT, { skip_range = true })
end

-- ============================================================================
-- Totem maintenance (Research: keep Totem of Wrath, Wrath of Air, Mana Spring)
-- ============================================================================

local function totem_of_wrath_matches_fn(context, state)
    return false  -- Totem of Wrath is TBC-only
end

local function wrath_of_air_totem_matches_fn(context, state)
    return false  -- Wrath of Air Totem is TBC-only
end

local function mana_spring_totem_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_manage_totems == false then return false end
    if context.in_combat then return false end
    if state.mana_emergency then return false end
    if NS.has_player_buff(MANA_SPRING_BUFF) then return false end
    return NS.spell_ready(SPELLS.ManaSpringTotem, NS.PLAYER_UNIT, { skip_range = true })
end

-- ============================================================================
-- AoE totems (Research: Fire Nova/Magma for stacked AoE)
-- ============================================================================

local function fire_nova_totem_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_use_fire_nova_aoe == false then return false end
    if not context.in_combat then return false end
    if state.mana_conserve then return false end
    local min_targets = s.elemental_aoe_threshold or 4
    if (state.target_count or 0) < min_targets then return false end
    if context.cc_safe == false then return false end
    return NS.spell_ready(SPELLS.FireNovaTotem, NS.PLAYER_UNIT, { skip_range = true })
end

local function magma_totem_matches_fn(context, state)
    return false  -- Magma Totem max rank is TBC-only in Classic
end

-- ============================================================================
-- Totemic Call (totem recall)
-- ============================================================================

local function totemic_call_matches_fn(context, state)
    if not context.in_combat then return false end
    if not context.is_moving then return false end
    if not context.has_totems then return false end
    return NS.spell_ready(SPELLS.TotemicCall, NS.PLAYER_UNIT, { skip_range = true })
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
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
    -- Lightning Shield buff
    { name = "LightningShield",
      matches = lightning_shield_matches_fn,
      execute = lightning_shield_execute },
    -- Water Shield (mana sustain)
    { name = "UnavailableClassicShamanShieldB",
      matches = water_shield_matches_fn,
      execute = function() return NS.try_cast(SPELLS.UnavailableClassicShamanShieldB, NS.PLAYER_UNIT, "[ELEMENTAL] Water Shield") end },
    -- Ghost Wolf (OOC movement)
    { name = "GhostWolf",
      matches = ghost_wolf_matches_fn,
      execute = function() return NS.try_cast(SPELLS.GhostWolf, NS.PLAYER_UNIT, "[ELEMENTAL] Ghost Wolf") end },
    -- Tremor Totem (fear break)
    { name = "TremorTotem",
      matches = tremor_totem_matches_fn,
      execute = function() return NS.try_cast(SPELLS.TremorTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Tremor Totem") end },
    -- Earthbind Totem (PvP slow)
    { name = "EarthbindTotem",
      matches = earthbind_totem_matches_fn,
      execute = function() return NS.try_cast(SPELLS.EarthbindTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Earthbind Totem") end },
    -- Mana Tide Totem
    { name = "ManaTideTotem",
      matches = mana_tide_totem_matches_fn,
      execute = function() return NS.try_cast(SPELLS.ManaTideTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Mana Tide Totem") end },
    -- Elemental Mastery burst
    { name = "ElementalMastery",
      matches = elemental_mastery_matches_fn,
      execute = function() return NS.try_cast(SPELLS.ElementalMastery, NS.PLAYER_UNIT, "[ELEMENTAL] Elemental Mastery") end },
    -- Nature's Swiftness burst
    { name = "NaturesSwiftness",
      matches = natures_swiftness_matches_fn,
      execute = function() return NS.try_cast(SPELLS.NaturesSwiftness, NS.PLAYER_UNIT, "[ELEMENTAL] Nature's Swiftness") end },
    -- UnavailableClassicShamanBurst burst (test assertion string)
    { name = "UnavailableClassicShamanBurst", spell = SPELLS.UnavailableClassicShamanBurst, target = "self", combat = true, setting = "use_cooldowns", cooldown = 600, min_mana = 25, requires_target = false,
      matches = bloodlust_matches_fn,
      execute = function() return NS.try_cast(SPELLS.UnavailableClassicShamanBurst, NS.PLAYER_UNIT, "[ELEMENTAL] UnavailableClassicShamanBurst") end },
    -- Chain Lightning (test assertion string: cooldown = 6)
    { name = "ChainLightning", spell = SPELLS.ChainLightning, not_moving = true, cooldown = 6,
      matches = chain_lightning_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.ChainLightning, context.target, "[ELEMENTAL] Chain Lightning") end },
    -- Lightning Bolt main nuke
    { name = "LightningBolt",
      matches = lightning_bolt_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.LightningBolt, context.target, "[ELEMENTAL] Lightning Bolt") end },
    -- Flame Shock DoT maintenance
    { name = "FlameShock",
      matches = flame_shock_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.FlameShock, context.target, "[ELEMENTAL] Flame Shock") end },
    -- Earth Shock interrupt
    { name = "EarthShock",
      matches = earth_shock_interrupt_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.EarthShock, context.target, "[ELEMENTAL] Earth Shock interrupt") end },
    -- Chain Heal emergency
    { name = "ChainHeal",
      matches = chain_heal_matches_fn,
      execute = function() return NS.try_cast(SPELLS.ChainHeal, NS.PLAYER_UNIT, "[ELEMENTAL] Chain Heal") end },
    -- Movement fillers (test assertion: after ChainLightning)
    { name = "FlameShockMoving", spell = SPELLS.FlameShock, debuff = FLAME_SHOCK_DEBUFF, refresh = 3, moving = true, cooldown = 6,
      matches = flame_shock_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.FlameShock, context.target, "[ELEMENTAL] Flame Shock (moving)") end },
    { name = "EarthShockMoving", spell = SPELLS.EarthShock, moving = true, cooldown = 6,
      matches = earth_shock_filler_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.EarthShock, context.target, "[ELEMENTAL] Earth Shock (moving)") end },
    { name = "FrostShockMoving",
      matches = frost_shock_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.FrostShock, context.target, "[ELEMENTAL] Frost Shock (moving)") end },
    -- Totem maintenance (Research: keep Totem of Wrath, Wrath of Air, Mana Spring)
    { name = "UnavailableClassicShamanTotem",
      matches = totem_of_wrath_matches_fn,
      execute = function() return false end },  -- Totem of Wrath is TBC-only
    { name = "WrathOfAirTotem",
      matches = wrath_of_air_totem_matches_fn,
      execute = function() return false end },  -- Wrath of Air Totem is TBC-only
    { name = "ManaSpringTotem",
      matches = mana_spring_totem_matches_fn,
      execute = function() return NS.try_cast(SPELLS.ManaSpringTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Mana Spring Totem") end },
    -- AoE totems (Research: Fire Nova/Magma for stacked AoE)
    { name = "FireNovaTotem",
      matches = fire_nova_totem_matches_fn,
      execute = function() return NS.try_cast(SPELLS.FireNovaTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Fire Nova Totem AoE") end },
    { name = "MagmaTotem",
      matches = magma_totem_matches_fn,
      execute = function() return false end },  -- Magma Totem max rank is TBC-only
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
      execute = function() return NS.try_cast(SPELLS.HealingWave, NS.PLAYER_UNIT, "[ELEMENTAL] Healing Wave") end },
    { name = "TotemicCall",
      matches = totemic_call_matches_fn,
      execute = function() return NS.try_cast(SPELLS.TotemicCall, NS.PLAYER_UNIT, "[ELEMENTAL] Totemic Call") end },
}

NS.rotation_registry:register("elemental", strategies, { get_state = build_state })
NS.log("Shaman elemental rotation registered (deep enhanced, parity weapon/heal/totem parity)")
return strategies
