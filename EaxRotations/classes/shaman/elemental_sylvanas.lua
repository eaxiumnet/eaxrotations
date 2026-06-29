-- elemental_sylvanas -- shaman elemental_sylvanas rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies for elemental_sylvanas gameplay.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.
-- SAFETY: every state field read is nil-guarded via build_state() defaults; no on_update() allocs.

-- Shaman Elemental priority list.

local NS = _G.EaxRotations
if not NS then return nil end
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.ShamanSpells or {}
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
    clearcast_active = false,
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
    ele_state.spell_damage = context.spell_damage or 0
    -- Weapon buff freshness
    ele_state.has_flametongue = (ele_state.now_ms - runtime.last_flametongue_ms) < WEAPON_BUFF_REFRESH_MS
    ele_state.has_windfury = (ele_state.now_ms - runtime.last_windfury_ms) < WEAPON_BUFF_REFRESH_MS
    ele_state.has_rockbiter = (ele_state.now_ms - runtime.last_rockbiter_ms) < WEAPON_BUFF_REFRESH_MS
    ele_state.clearcast_active = NS.has_player_buff and NS.has_player_buff(CLEARCAST_BUFF) or false
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
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.LightningShield, NS.PLAYER_UNIT, { skip_range = true }) or false
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
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if not context.should_burst then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.Bloodlust, NS.PLAYER_UNIT, { skip_range = true }) or false
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
        return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.ChainLightning, context.target) or false
    end
    -- Research: CL only at 3+ targets; configurable via schema
    local s = context.settings or {}
    local min_targets = s.elemental_cl_min_targets or CL_MIN_TARGETS
    if (state.target_count or 0) < min_targets then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.ChainLightning, context.target) or false
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
    -- Uses SPELLS.LightningBoltLowerRank when learned and mana is low
    local lower_rank = SPELLS.LightningBoltLowerRank
    local lower_id = (type(lower_rank) == "table" and lower_rank.ids and lower_rank.ids[1]) or lower_rank
    local spell_id = (state.mana_low and lower_id and NS.is_spell_learned and NS.is_spell_learned(lower_id)) and lower_rank or SPELLS.LightningBolt
    return NS.spell_ready ~= nil and NS.spell_ready(spell_id, context.target) or false
end

local function flame_shock_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.FlameShock, 2.0) then return false end
    if not context.target then return false end
    -- Research: only clip Flame Shock at <1s remaining (prevents shock CD starvation)
    if (state.flame_remains or 0) > 1 then return false end    -- SP-aware gating: skip Flame Shock if spell damage is below minimum threshold
    -- Flame Shock has ~0.3 direct + ~0.3 DoT coefficient = ~0.6 total; GCD-positive at ~400 SP
    local s = context.settings or {}
    local min_sp = s.elemental_flame_shock_min_sp or FLAME_SHOCK_MIN_SP_DEFAULT
    if NS.should_refresh_dot and not NS.should_refresh_dot(state.flame_remains, 1.5, context.ttd, 12) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.FlameShock, context.target) or false
end

local function earth_shock_filler_matches_fn(context, state)
    if not context.is_moving then return false end
    -- Respect interrupt reserve: when ON, suppress Earth Shock filler to save for interrupts
    local s = context.settings or {}
    if s.elemental_interrupt_reserve ~= false then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.EarthShock, context.target) or false
end

local function frost_shock_matches_fn(context, state)
    if not context.is_moving then return false end
    if not context.is_pvp then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.FrostShock, context.target) or false
end

local function elemental_mastery_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_use_elemental_mastery == false then return false end
    if not context.in_combat then return false end
    if state.mana_conserve then return false end
    if not context.should_burst then return false end
    -- EM+CL hold: don't waste EM on Lightning Bolt when CL is the better nuke
    local min_targets = s.elemental_cl_min_targets or CL_MIN_TARGETS
    if (state.target_count or 0) >= min_targets then
        local cl_cd = NS.cooldown_remains and NS.cooldown_remains(SPELLS.ChainLightning) or 0
        if cl_cd > 1.5 then return false end
    end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.ElementalMastery, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function natures_swiftness_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_use_natures_swiftness == false then return false end
    if not context.in_combat then return false end
    if not context.should_burst then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.NaturesSwiftness, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function water_shield_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.WaterShield, 3.0) then return false end
    local s = context.settings or {}
    if state.mana_emergency then return false end
    local ws_mana = s.elemental_water_shield_mana or WATER_SHIELD_MANA_DEFAULT
    if (state.mana_pct or 100) > ws_mana then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.WaterShield, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function ghost_wolf_matches_fn(context, state)
    if context.in_combat then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.GhostWolf, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function tremor_totem_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.TremorTotem, 3.0) then return false end
    if not context.in_combat then return false end
    if state.mana_emergency then return false end
    if not (context.fear_nearby or false) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.TremorTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function earthbind_totem_matches_fn(context, state)
    if not context.is_pvp then return false end
    if state.mana_emergency then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.EarthbindTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function mana_tide_totem_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ManaTideTotem, 3.0) then return false end
    if state.mana_emergency then return false end
    if (state.mana_pct or 100) > 30 then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.ManaTideTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function chain_heal_matches_fn(context, state)
    if not (context.group_injured or false) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.ChainHeal, NS.PLAYER_UNIT, { skip_range = true }) or false
end

-- ============================================================================
-- Weapon buffs (parity parity)
-- ============================================================================

local function flametongue_weapon_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.FlametongueWeapon, 3.0) then return false end
    if context.in_combat then return false end
    if state.has_flametongue then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.FlametongueWeapon, NS.PLAYER_UNIT, { skip_range = true }) or false
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
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.WindfuryWeapon, NS.PLAYER_UNIT, { skip_range = true }) or false
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
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.RockbiterWeapon, NS.PLAYER_UNIT, { skip_range = true }) or false
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
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.HealingWave, NS.PLAYER_UNIT, { skip_range = true }) or false
end

-- ============================================================================
-- Totem maintenance (Research: keep Totem of Wrath, Wrath of Air, Mana Spring)
-- ============================================================================

local function totem_of_wrath_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_manage_totems == false then return false end
    if s.elemental_use_totem_of_wrath == false then return false end
    if state.mana_emergency then return false end
    if NS.has_player_buff(TOTEM_OF_WRATH_BUFF) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.TotemOfWrath, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function wrath_of_air_totem_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_manage_totems == false then return false end
    if state.mana_emergency then return false end
    if NS.has_player_buff(WRATH_OF_AIR_BUFF) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.WrathOfAirTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function mana_spring_totem_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_manage_totems == false then return false end
    if state.mana_emergency then return false end
    if NS.has_player_buff(MANA_SPRING_BUFF) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.ManaSpringTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
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
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.FireNovaTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function magma_totem_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_use_magma_aoe == false then return false end
    if not context.in_combat then return false end
    if state.mana_conserve then return false end
    local min_targets = s.elemental_aoe_threshold or 4
    if (state.target_count or 0) < min_targets then return false end
    if context.cc_safe == false then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.MagmaTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

-- ============================================================================
-- Totemic Call (totem recall)
-- ============================================================================

local function totemic_call_matches_fn(context, state)
    if not context.in_combat then return false end
    if not context.is_moving then return false end
    if not (context.has_totems or false) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.TotemicCall, NS.PLAYER_UNIT, { skip_range = true }) or false
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_mana_potion then return false end
          if (context.mana_pct or 100) > 20 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
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
    { name = "WaterShield",
      matches = water_shield_matches_fn,
      execute = function() return NS.try_cast(SPELLS.WaterShield, NS.PLAYER_UNIT, "[ELEMENTAL] Water Shield") end },
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
    -- Bloodlust burst (test assertion string)
    { name = "Bloodlust", spell = SPELLS.Bloodlust, target = "self", combat = true, setting = "use_cooldowns", cooldown = 600, min_mana = 25, requires_target = false,
      matches = bloodlust_matches_fn,
      execute = function() return NS.try_cast(SPELLS.Bloodlust, NS.PLAYER_UNIT, "[ELEMENTAL] Bloodlust") end },
    -- Chain Lightning (test assertion string: cooldown = 6)
    { name = "ChainLightning", spell = SPELLS.ChainLightning, not_moving = true, cooldown = 6,
      matches = chain_lightning_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.ChainLightning, context.target, "[ELEMENTAL] Chain Lightning") end },
    -- Flame Shock DoT maintenance (before filler to keep it up)
    { name = "FlameShock",
      matches = flame_shock_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.FlameShock, context.target, "[ELEMENTAL] Flame Shock") end },
    -- Lightning Bolt main nuke
    { name = "LightningBolt",
      matches = lightning_bolt_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.LightningBolt, context.target, "[ELEMENTAL] Lightning Bolt") end },
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
    { name = "TotemOfWrath",
      matches = totem_of_wrath_matches_fn,
      execute = function() return NS.try_cast(SPELLS.TotemOfWrath, NS.PLAYER_UNIT, "[ELEMENTAL] Totem of Wrath") end },
    { name = "WrathOfAirTotem",
      matches = wrath_of_air_totem_matches_fn,
      execute = function() return NS.try_cast(SPELLS.WrathOfAirTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Wrath of Air Totem") end },
    { name = "ManaSpringTotem",
      matches = mana_spring_totem_matches_fn,
      execute = function() return NS.try_cast(SPELLS.ManaSpringTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Mana Spring Totem") end },
    -- AoE totems (Research: Fire Nova/Magma for stacked AoE)
    { name = "FireNovaTotem",
      matches = fire_nova_totem_matches_fn,
      execute = function() return NS.try_cast(SPELLS.FireNovaTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Fire Nova Totem AoE") end },
    { name = "MagmaTotem",
      matches = magma_totem_matches_fn,
      execute = function() return NS.try_cast(SPELLS.MagmaTotem, NS.PLAYER_UNIT, "[ELEMENTAL] Magma Totem AoE") end },
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

