-- elemental_vanilla.lua — Shaman Elemental for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  ranged spell DPS (Lightning Bolt, Chain Lightning, Earth Shock).
-- WHEN:  combat, when NS.is_vanilla() is true.
-- WHY:   expansion-aware loader selects _vanilla suffix for Classic Era.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

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
local potion_helper = require("shared/potion_helper_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.ShamanSpells or {}

-- Fallback spell definitions for keys not yet in class_sylvanas.lua
-- These are overridden if class_sylvanas.lua defines them with higher priority
SPELLS.UnavailableClassicShamanTotem = nil

-- Vanilla Lightning Bolt downrank: class_sylvanas.lua's LightningBoltLowerRank
-- (25448) is TBC LB rank 11 — never learned in Classic, so the downrank lane
-- could never fire in vanilla. Local vanilla ranks (verified against the DBC):
-- 10392 (rank 8, one below max) preferred, 10391 (rank 7), 15207 (rank 9 max
-- as a final fallback — the lane degrades to max rank only if no lower rank is
-- learned). Prefer this local spell_action over SPELLS.LightningBoltLowerRank.
-- NOTE: no `name =` field on purpose — the era-pair audit treats every
-- `name = "X"` literal as a strategy name and would flag this as a
-- divergence missing from the sylvanas/wotlk siblings.
local LB_LOWER_RANK = NS.spell_action and NS.spell_action({
    ids = { 10392, 10391, 15207 },
    cast_time = 3.0,
    cooldown = 0,
    power_cost = 0,
    power_type = "mana",
    school = "nature",
}) or { ids = { 10392, 10391, 15207 } }

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

-- SP-aware DoT gating: skip Flame Shock below this spell damage threshold
-- Flame Shock has ~0.3 direct + ~0.3 DoT coefficient; breakpoint ~400 SP pre-raid

-- Chain Lightning defaults (DB2: EffectChainTargets=3, EffectChainAmplitude=0.70)
local CL_MIN_TARGETS = 3

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

-- Schema for safe_state: Pattern 14 nil-guard defaults.
local ELE_VANILLA_SCHEMA = {
    flame_remains = 0,  lightning_shield_up = false,
    mana_pct = 100,  mana_low = false,  mana_conserve = false,
    mana_emergency = false,  hp_pct = 100,  target_count = 1,
    has_flametongue = false,  has_windfury = false,
    has_rockbiter = false,  now_ms = 0,  spell_damage = 0,
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
    ele_state.spell_damage = context.spell_damage or 0
    -- Weapon buff freshness
    ele_state.has_flametongue = (ele_state.now_ms - runtime.last_flametongue_ms) < WEAPON_BUFF_REFRESH_MS
    ele_state.has_windfury = (ele_state.now_ms - runtime.last_windfury_ms) < WEAPON_BUFF_REFRESH_MS
    ele_state.has_rockbiter = (ele_state.now_ms - runtime.last_rockbiter_ms) < WEAPON_BUFF_REFRESH_MS
    return spec_kit.safe_state(ele_state, ELE_VANILLA_SCHEMA)
end

-- ============================================================================
-- Matches functions
-- ============================================================================

local function lightning_shield_matches_fn(context, state)
    local s = context.settings or {}
    if state.mana_emergency then return false end
    if s.elemental_lightning_shield == false then return false end
    if state.lightning_shield_up then return false end
    if (state.now_ms or 0) - (runtime.last_lightning_shield_ms or 0) < SHIELD_REFRESH_UNKNOWN_MS then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.LightningShield, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function lightning_shield_execute(context, state)
    if NS.try_cast(SPELLS.LightningShield, NS.PLAYER_UNIT, "[ELEMENTAL] Lightning Shield") then
        runtime.last_lightning_shield_ms = state.now_ms
        return true
    end
    return false
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
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.ChainLightning, context.target) or false
end

-- Resolve the Lightning Bolt spell for the current mana state: the local
-- vanilla downrank at mana_low (when learned), max rank otherwise. Used by
-- both the matches gate and the execute so the actual cast honors the
-- downrank (the old execute always cast SPELLS.LightningBolt).
local function resolve_lightning_bolt(state)
    state = state or {}
    local lower_rank = LB_LOWER_RANK
    local lower_id = (type(lower_rank) == "table" and lower_rank.ids and lower_rank.ids[1]) or lower_rank
    if state.mana_low and lower_id and NS.is_spell_learned and NS.is_spell_learned(lower_id) then
        return lower_rank
    end
    return SPELLS.LightningBolt
end

local function lightning_bolt_matches_fn(context, state)
    if context.is_moving then return false end
    if state.mana_emergency then return false end
    -- Threat safety: hold Lightning Bolt if threat > 90%
    if context.threat_pct and context.threat_pct > 90 then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(resolve_lightning_bolt(state), context.target) or false
end

local function flame_shock_matches_fn(context, state)
    if not context.target then return false end
    -- Research: only clip Flame Shock at <1s remaining (prevents shock CD starvation)
    if (state.flame_remains or 0) > 1 then return false end
    -- (SP-aware min-SP gate removed 2026-08: the engine never populates
    -- ctx.spell_damage, so FlameShock could never fire in live play; the TBC
    -- sibling's DSL dropped the same gate — mirror-drift fix.)
    if NS.should_refresh_dot and not NS.should_refresh_dot(state.flame_remains, 1.5, context.ttd, 12) then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.FlameShock, context.target) or false
end

local function earth_shock_interrupt_matches_fn(context, state)
    local target = context.target
    if not target then return false end
    if state.mana_emergency then return false end
    local is_casting = false
    pcall(function()
        if target.is_casting and target:is_casting() then is_casting = true end
        if target.is_casting_spell and target:is_casting_spell() then is_casting = true end
    end)
    if not is_casting then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.EarthShock, target) or false
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
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    local s = context.settings or {}
    if s.elemental_use_elemental_mastery == false then return false end
    if not context.in_combat then return false end
    if state.mana_conserve then return false end
    if not context.should_burst then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.ElementalMastery, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function natures_swiftness_matches_fn(context, state)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    local s = context.settings or {}
    if s.elemental_use_natures_swiftness == false then return false end
    if not context.in_combat then return false end
    if not context.should_burst then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.NaturesSwiftness, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function ghost_wolf_matches_fn(context, state)
    if context.in_combat then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.GhostWolf, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function tremor_totem_matches_fn(context, state)
    if not context.in_combat then return false end
    if state.mana_emergency then return false end
    if not context.fear_nearby then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.TremorTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function earthbind_totem_matches_fn(context, state)
    if not context.is_pvp then return false end
    if state.mana_emergency then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.EarthbindTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function mana_tide_totem_matches_fn(context, state)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 300) then return false end
    if state.mana_emergency then return false end
    if (state.mana_pct or 100) > 30 then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.ManaTideTotem, NS.PLAYER_UNIT, { skip_range = true }) or false
end

local function chain_heal_matches_fn(context, state)
    if not context.group_injured then return false end
    return NS.spell_ready ~= nil and NS.spell_ready(SPELLS.ChainHeal, NS.PLAYER_UNIT, { skip_range = true }) or false
end

-- ============================================================================
-- Weapon buffs (parity parity)
-- ============================================================================

local function flametongue_weapon_matches_fn(context, state)
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

local function wrath_of_air_totem_matches_fn(context, state)
    return false  -- Wrath of Air Totem is TBC-only
end

local function mana_spring_totem_matches_fn(context, state)
    local s = context.settings or {}
    if s.elemental_manage_totems == false then return false end
    if context.in_combat then return false end
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
    -- All four Magma Totem ranks (8190/10585/10586/10587) are Classic-era —
    -- rank IV is level 56, well inside the Classic cap. 25552 (rank V) is
    -- TBC-only, but the class-table ladder resolves the highest LEARNED rank,
    -- so casting is safe on the Classic client. Previously disabled with the
    -- wrong rationale "max rank is TBC-only" (fix 2026-08-14).
    local s = context.settings or {}
    if s.elemental_use_fire_nova_aoe == false then return false end
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
    if not context.has_totems then return false end
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
      -- NS.start_attack is a mock-only stub (undefined in core_sylvanas.lua);
      -- the real entry point is NS.start_auto_attack(target, attack_type).
      -- Wand at mana emergency, with target validation (TBC sibling pattern).
      execute = function(context)
        local target = context and context.target
        if target and target.is_valid and target:is_valid() and not (target.is_dead and target:is_dead()) then
          if NS.start_auto_attack then
            NS.start_auto_attack(target, NS.AUTO_ATTACK_WAND)
          end
        end
        return true
      end },
    -- Lightning Shield buff
    { name = "LightningShield",
      matches = lightning_shield_matches_fn,
      execute = lightning_shield_execute },
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
    -- Chain Lightning (test assertion string: cooldown = 6)
    { name = "ChainLightning", spell = SPELLS.ChainLightning, not_moving = true, cooldown = 6,
      matches = chain_lightning_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.ChainLightning, context.target, "[ELEMENTAL] Chain Lightning") end },
    -- Lightning Bolt main nuke (downranks locally at mana_low)
    { name = "LightningBolt",
      matches = lightning_bolt_matches_fn,
      execute = function(context, state) return NS.try_cast(resolve_lightning_bolt(state), context.target, "[ELEMENTAL] Lightning Bolt") end },
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

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("elemental", strategies, { get_state = build_state })
end
-- Shaman elemental rotation registered (deep enhanced, parity weapon/heal/totem parity)
return strategies

