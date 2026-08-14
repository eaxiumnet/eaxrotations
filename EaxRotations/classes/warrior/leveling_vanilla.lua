-- leveling_vanilla.lua — Warrior Leveling rotation for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  adaptive leveling (heroic strike, rend, overpower, charge).
-- WHEN:  any combat while leveling, when NS.is_vanilla() is true.
-- WHY:   handles sub-60 content and rage generation.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")

local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end

-- ============================================================================
-- Module table
-- ============================================================================
local warrior_leveling = {}

-- ============================================================================
-- Context guard
-- ============================================================================
local is_leveling_context = leveling.create_context_guard()

-- ============================================================================
-- Constants
-- ============================================================================
local SPELLS = NS.WarriorSpells or NS.SPELLS or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local BATTLE_SHOUT_BUFF = { 11551, 11550, 11549, 6192, 5242, 6673 }
local PVP_CC_RADIUS = 15

-- Disarm target classes: melee classes that lose weapon-based damage when disarmed
local DISARM_CLASS_IDS = CONSTANTS.DISARM_CLASS_IDS or { [1] = true, [2] = true, [4] = true, [7] = true }

-- AoE/cleave spell IDs for PvP CC gating (any rank learned = gate active)
local WARRIOR_AOE_IDS = { 845, 1680, 12292 }  -- Cleave, Whirlwind, Sweeping Strikes (Vanilla ID; TBC=12328)

-- ============================================================================
-- Strategy helpers
-- ============================================================================

local function spell_ready(spell_action)
    if not spell_action then return false end
    return NS.spell_ready and NS.spell_ready(spell_action) or false
end

local function has_buff(buff_ids)
    if not buff_ids then return false end
    local me = (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
    if not me then return false end
    local ids = type(buff_ids) == "table" and buff_ids or { buff_ids }
    if NS.buff_up then return NS.buff_up(me, ids) end
    return false
end

-- ============================================================================
-- State builder
-- ============================================================================

-- Schema for safe_state: Pattern 14 defaults for all numeric state fields.
-- Fields NOT listed here use spec_kit.SAFE_STATE_DEFAULTS (rage→0, hp→100, etc.).
local LEVELING_VANILLA_SCHEMA = {
    rage = 0,
    charge_ready = false,
    rend_ready = false,
    heroic_strike_ready = false,
    overpower_ready = false,
    thunder_clap_ready = false,
    demoralizing_shout_ready = false,
    execute_ready = false,
    shield_bash_ready = false,
    battle_shout_ready = false,
    bloodrage_ready = false,
    whirlwind_ready = false,
    sweeping_strikes_ready = false,
    mortal_strike_ready = false,
    hamstring_ready = false,
    disarm_ready = false,
    shield_wall_ready = false,
    intimidating_shout_ready = false,
    berserker_rage_ready = false,
    pummel_ready = false,
    bloodthirst_ready = false,
    shield_slam_ready = false,
    is_pvp = false,
    in_melee_range = false,
    disarm_class_ok = false,
    disarm_burst_name = nil,
    has_battle_shout = false,
    use_execute = true,
    use_rend = true,
    use_thunder_clap = true,
    exec_hp = 20,
    pvp_cc_gate = false,
}

function warrior_leveling.build_state(context)
    if not context then return nil end

    local state = {}

    -- Common state
    leveling.build_common_state(context, state)
    -- build_common_state copies hp/mana_pct/enemies but NOT rage (the warrior
    -- resource); without this, bloodthirst/shield_slam matches read state.rage
    -- as nil → `(nil or 0) < 30` → always return false (dead abilities).
    state.rage = context.rage or 0

    -- Warrior-specific spell readiness (Classic spells only)
    state.charge_ready = spell_ready(SPELLS.Charge)
    state.rend_ready = spell_ready(SPELLS.Rend)
    state.heroic_strike_ready = spell_ready(SPELLS.HeroicStrike)
    state.overpower_ready = spell_ready(SPELLS.Overpower)
    state.thunder_clap_ready = spell_ready(SPELLS.ThunderClap)
    state.demoralizing_shout_ready = spell_ready(SPELLS.DemoralizingShout)
    state.execute_ready = spell_ready(SPELLS.Execute)
    state.shield_bash_ready = spell_ready(SPELLS.ShieldBash)
    state.battle_shout_ready = spell_ready(SPELLS.BattleShout)
    state.bloodrage_ready = spell_ready(SPELLS.Bloodrage)
    state.whirlwind_ready = spell_ready(SPELLS.Whirlwind)
    state.sweeping_strikes_ready = spell_ready(SPELLS.SweepingStrikes)
    state.mortal_strike_ready = spell_ready(SPELLS.MortalStrike)
    state.hamstring_ready = spell_ready(SPELLS.Hamstring)
    state.disarm_ready = spell_ready(SPELLS.Disarm)
    state.shield_wall_ready = spell_ready(SPELLS.ShieldWall)
    state.intimidating_shout_ready = spell_ready(SPELLS.IntimidatingShout)
    state.berserker_rage_ready = spell_ready(SPELLS.BerserkerRage)
    state.pummel_ready = spell_ready(SPELLS.Pummel)
    state.bloodthirst_ready = spell_ready(SPELLS.Bloodthirst)
    state.shield_slam_ready = spell_ready(SPELLS.ShieldSlam)


    -- PvP state
    state.is_pvp = context.is_pvp or false
    state.in_melee_range = context.in_melee_range or false

    -- Disarm burst detection via offensive dispel priority DB
    state.disarm_class_ok = false
    state.disarm_burst_name = nil
    if state.target and state.is_pvp and state.disarm_ready then
        local ok, class_id = pcall(function() return state.target:get_class() end)
        if ok and type(class_id) == "number" and DISARM_CLASS_IDS[class_id] then
            state.disarm_class_ok = true
            local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(state.target, NS)
            if best_id and (best_priority or 0) >= 3 then
                state.disarm_burst_name = best_name
            end
        end
    end

    -- Buff checks
    state.has_battle_shout = has_buff(BATTLE_SHOUT_BUFF)

    -- PvP CC gate: computed ONCE per tick here (never halts the priority list —
    -- the AoE lanes below read this flag and suppress themselves instead).
    state.pvp_cc_gate = false
    if state.in_combat and spec_kit.setting_bool(context, "use_pvp_cc_gating", true) then
        local has_aoe = false
        for _, id in ipairs(WARRIOR_AOE_IDS) do
            if NS.is_spell_learned and NS.is_spell_learned(id) then
                has_aoe = true
                break
            end
        end
        if has_aoe then
            local ok_cc, active = pcall(CCGateDB.is_any_nearby_enemy_under_cc, NS, PVP_CC_RADIUS)
            state.pvp_cc_gate = ok_cc and active == true
        end
    end

    state.use_execute = spec_kit.setting_bool(context, "leveling_use_execute", true)
    state.use_rend = spec_kit.setting_bool(context, "leveling_use_rend", true)
    state.use_thunder_clap = spec_kit.setting_bool(context, "leveling_use_thunder_clap", true)
    state.exec_hp = spec_kit.setting_number(context, "leveling_exec_hp", 20)

    return spec_kit.safe_state(state, LEVELING_VANILLA_SCHEMA)
end

-- ============================================================================
-- Match functions
-- ============================================================================

--- Battle Shout - OOC buff
local battle_shout_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_battle_shout then return false end
    if not state.battle_shout_ready then return false end
    return true
end

--- Bloodrage - generate rage at combat start
local bloodrage_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.bloodrage_ready then return false end
    local me = (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
    if not me then return false end
    local ok, rage = pcall(function() return me:get_power(NS.POWER_RAGE or 1) end)
    if ok and rage and rage > 20 then return false end  -- Enough rage already
    return true
end

--- Shield Bash - interrupt (replaces Pummel in Classic)
local shield_bash_matches = function(context, state)
    if not state then return false end
    if not state.use_interrupt then return false end
    if not state.shield_bash_ready then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    return ok and casting
end

--- Pummel - berserker stance interrupt (for dual-wield/fury leveling)
local pummel_matches = function(context, state)
    if not state then return false end
    if not state.use_interrupt then return false end
    if not state.pummel_ready then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    return ok and casting
end

--- Bloodthirst - fury talent rage spender (instant attack, 6s CD)
local bloodthirst_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.bloodthirst_ready then return false end
    if not state.target then return false end
    if not state.in_melee_range then return false end
    if (state.rage or 0) < 30 then return false end
    return true
end

--- ShieldSlam - protection talent threat generator (instant, 6s CD)
local shield_slam_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.shield_slam_ready then return false end
    if not state.target then return false end
    if not state.in_melee_range then return false end
    if (state.rage or 0) < 20 then return false end
    return true
end

--- Execute - low HP finisher
local execute_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.execute_ready then return false end
    if not state.use_execute then return false end
    if (state.rage or 0) < 15 then return false end  -- Vanilla Execute costs 15 rage
    if not state.target then return false end
    local ok, hp = pcall(function() return state.target:get_health_percentage() end)
    if not ok or not hp then return false end
    if hp > (state.exec_hp or 20) then return false end
    return true
end

--- Sweeping Strikes - AoE buff (needs second target near primary)
local sweeping_strikes_matches = function(context, state)
    if not state then return false end
    if state.pvp_cc_gate then return false end
    if not state.in_combat then return false end
    if not state.sweeping_strikes_ready then return false end
    if has_buff({ 12292 }) then return false end  -- Vanilla SS buff already up
    if not (NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context and context.target, context, state)) then
        return false
    end
    return true
end

--- Whirlwind - 8yd self PBAoE when surrounded
local whirlwind_matches = function(context, state)
    if not state then return false end
    if state.pvp_cc_gate then return false end
    if not state.in_combat then return false end
    if not state.whirlwind_ready then return false end
    if not state.target then return false end
    if not (NS.aoe_self_meets and NS.aoe_self_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)) then
        return false
    end
    return true
end

--- Thunder Clap - 8yd self PBAoE damage/slow
local thunder_clap_matches = function(context, state)
    if not state then return false end
    if state.pvp_cc_gate then return false end
    if not state.in_combat then return false end
    if not state.thunder_clap_ready then return false end
    if not state.use_thunder_clap then return false end
    if not (NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)) then
        return false
    end
    return true
end

--- Rend - bleed DoT
local rend_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.rend_ready then return false end
    if not state.use_rend then return false end
    if not state.target then return false end
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.Rend) or 0 end)
    if ok and remains and remains > 4 then return false end
    return true
end

--- Mortal Strike - spec filler (Arms talent; Battle stance only in Vanilla)
local mortal_strike_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if context.stance and context.stance ~= 1 then return false end
    if state.mortal_strike_ready then return true end
    return false
end

--- Overpower - when target dodges
local overpower_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.overpower_ready then return false end
    if not state.target then return false end
    -- Overpower requires Battle Stance
    if context.stance and context.stance ~= 1 then return false end
    return true
end

--- Heroic Strike - rage dump
local heroic_strike_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.heroic_strike_ready then return false end
    if not state.target then return false end
    local me = (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
    if not me then return false end
    local ok, rage = pcall(function() return me:get_power(NS.POWER_RAGE or 1) end)
    if not ok or not rage then return false end
    if rage < 50 then return false end  -- Save rage for other abilities
    return true
end

--- Disarm - remove enemy melee weapon (PvP, requires Defensive Stance)
local disarm_matches = function(context, state)
    if not state then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(676)) then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.is_pvp then return false end
    if not spec_kit.setting_bool(context, "use_disarm", true) then return false end
    if not state.in_melee_range then return false end
    if not state.disarm_ready then return false end
    if not state.disarm_class_ok then return false end
    if spec_kit.setting_bool(context, "disarm_pvp_only", true) then
        local ok, is_player = pcall(function() return state.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    local trigger = spec_kit.setting(context, "disarm_trigger", "on_burst")
    if trigger == "on_burst" then
        if not state.disarm_burst_name then return false end
        context._disarm_burst_name = state.disarm_burst_name
    end
    return true
end

--- PvP CC Gate — skip AoE/cleave when nearby enemy is under breakable CC.
-- The gate is computed in build_state (state.pvp_cc_gate); this matcher only
-- reports it. The AoE lanes (SweepingStrikes/Whirlwind/ThunderClap) read the
-- flag and suppress THEMSELVES — the gate strategy must NOT return true from
-- execute (that would halt the whole priority list for the tick).
local pvp_cc_gate_matches = function(context, state)
    if not state then return false end
    return state.pvp_cc_gate == true
end

--- Hamstring - slow fleeing enemies or kite
local hamstring_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.hamstring_ready then return false end
    if not state.target then return false end
    local ok, hp = pcall(function() return state.target:get_health_percentage() end)
    if ok and hp and hp > 20 then return false end
    return true
end

--- Demoralizing Shout - reduce enemy attack power
local demo_shout_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.demoralizing_shout_ready then return false end
    if (state.enemies or 0) < 2 then return false end
    return true
end

--- Shield Wall - 50% damage reduction emergency
local shield_wall_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.shield_wall_ready then return false end
    if (state.hp or 100) > 20 then return false end
    return true
end

--- Intimidating Shout - AoE fear escape
local intimidating_shout_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.intimidating_shout_ready then return false end
    if (state.enemies or 0) < 3 then return false end
    if (state.hp or 100) > 30 then return false end
    return true
end

--- Charge - open from distance
local charge_matches = function(context, state)
    if not state then return false end
    -- Charge is OOC-only in Vanilla (the client blocks it in combat); the old
    -- `if not state.in_combat` gate was inverted, so Charge never fired as an opener.
    if state.in_combat then return false end
    if not state.charge_ready then return false end
    if not state.target then return false end
    local dist = NS.get_distance and NS.get_distance(state.target)
    if dist and dist < 8 then return false end
    if dist and dist > 25 then return false end
    return true
end
--- Berserker Rage - fear immunity + rage generation
local berserker_rage_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.berserker_rage_ready then return false end
    -- Fire on cooldown in combat for rage generation + fear immunity (was gated on enemies>=2,
    -- which skipped it against single targets — exactly when you need fear break / rage most).
    return true
end



-- ============================================================================
-- Strategies table
-- ============================================================================

local strategies = {
    -- OOC: Battle Shout
    { name = "BattleShout",
      matches = battle_shout_matches,
      execute = function(context) return NS.try_cast(SPELLS.BattleShout, nil, "[LEVELING] Battle Shout") end },

    -- Interrupt: Shield Bash (Classic interrupt, replaces Pummel)
    { name = "ShieldBash",
      matches = shield_bash_matches,
      execute = function(context) return NS.try_cast(SPELLS.ShieldBash, context.target, "[LEVELING] Shield Bash") end },

    -- Interrupt: Pummel (Berserker Stance, for fury/2H leveling)
    -- Interrupt: Pummel (Berserker Stance — dance if needed so the interrupt actually fires)
    { name = "Pummel",
      matches = pummel_matches,
      execute = function(context) if not context then return false end
          if context.stance ~= STANCE.BERSERKER then
              if NS.spell_ready and NS.spell_ready(SPELLS.BerserkerStance, context.me or NS.GetPlayer(), { skip_range = true }) then
                  return NS.try_cast(SPELLS.BerserkerStance, context.me or NS.GetPlayer(), "[LEVELING] Berserker Stance for Pummel", { skip_range = true })
              end
              return false
          end
          return NS.try_cast(SPELLS.Pummel, context.target, "[LEVELING] Pummel")
      end },

    -- Opener: Charge
    { name = "Charge",
      matches = charge_matches,
      execute = function(context) return NS.try_cast(SPELLS.Charge, context.target, "[LEVELING] Charge") end },
    -- Rage: Berserker Rage (fear immunity + rage generation)
    { name = "BerserkerRage",
      matches = berserker_rage_matches,
      execute = function(context) return NS.try_cast(SPELLS.BerserkerRage, nil, "[LEVELING] Berserker Rage") end },

    -- Rage: Bloodrage
    { name = "Bloodrage",
      matches = bloodrage_matches,
      execute = function(context) return NS.try_cast(SPELLS.Bloodrage, nil, "[LEVELING] Bloodrage") end },

    -- Defense: Shield Wall (50% damage reduction emergency)
    { name = "ShieldWall",
      matches = shield_wall_matches,
      execute = function(context) return NS.try_cast(SPELLS.ShieldWall, nil, "[LEVELING] Shield Wall") end },

    -- Execute
    -- Execute (Battle OR Berserker Stance — vanilla Execute works in both, so
    -- only dance when in Defensive; from Battle the swap would waste a GCD +
    -- 10-15 rage for nothing).
    { name = "Execute",
      matches = execute_matches,
      execute = function(context) if not context then return false end
          if context.stance ~= STANCE.BATTLE and context.stance ~= STANCE.BERSERKER then
              if NS.spell_ready and NS.spell_ready(SPELLS.BerserkerStance, context.me or NS.GetPlayer(), { skip_range = true }) then
                  return NS.try_cast(SPELLS.BerserkerStance, context.me or NS.GetPlayer(), "[LEVELING] Berserker Stance for Execute", { skip_range = true })
              end
              return false
          end
          return NS.try_cast(SPELLS.Execute, context.target, "[LEVELING] Execute")
      end },

    -- Bloodthirst (Fury talent, instant attack)
    { name = "Bloodthirst",
      matches = bloodthirst_matches,
      execute = function(context) return NS.try_cast(SPELLS.Bloodthirst, context.target, "[LEVELING] Bloodthirst") end },

    -- ShieldSlam (Protection talent, threat generator)
    { name = "ShieldSlam",
      matches = shield_slam_matches,
      execute = function(context) return NS.try_cast(SPELLS.ShieldSlam, context.target, "[LEVELING] Shield Slam") end },


    -- PvP CC Gate: suppress AoE lanes while breakable CC is nearby (the AoE
    -- strategies check state.pvp_cc_gate; this strategy must NOT return true
    -- from execute — that would halt the entire priority list for the tick).
    { name = "PvPCCGate",
      matches = pvp_cc_gate_matches,
      execute = function()
          return false
      end },

    -- CC: Intimidating Shout (AoE fear escape when overwhelmed)
    { name = "IntimidatingShout",
      matches = intimidating_shout_matches,
      execute = function(context) return NS.try_cast(SPELLS.IntimidatingShout, nil, "[LEVELING] Intimidating Shout") end },

    -- AoE: Sweeping Strikes
    { name = "SweepingStrikes",
      matches = sweeping_strikes_matches,
      execute = function(context) return NS.try_cast(SPELLS.SweepingStrikes, nil, "[LEVELING] Sweeping Strikes") end },

    -- AoE: Whirlwind
    { name = "Whirlwind",
      matches = whirlwind_matches,
      execute = function(context) return NS.try_cast(SPELLS.Whirlwind, nil, "[LEVELING] Whirlwind") end },

    -- AoE: Thunder Clap
    { name = "ThunderClap",
      matches = thunder_clap_matches,
      execute = function(context) return NS.try_cast(SPELLS.ThunderClap, nil, "[LEVELING] Thunder Clap") end },

    -- Debuff: Demoralizing Shout (reduce enemy attack power)
    { name = "DemoralizingShout",
      matches = demo_shout_matches,
      execute = function(context) return NS.try_cast(SPELLS.DemoralizingShout, nil, "[LEVELING] Demoralizing Shout") end },

    -- DoT: Rend
    { name = "Rend",
      matches = rend_matches,
      execute = function(context) return NS.try_cast(SPELLS.Rend, context.target, "[LEVELING] Rend") end },

    -- Utility: Hamstring (slow fleeing targets or kite)
    { name = "Hamstring",
      matches = hamstring_matches,
      execute = function(context) return NS.try_cast(SPELLS.Hamstring, context.target, "[LEVELING] Hamstring") end },

    -- Spec filler: Mortal Strike (Arms talent)
    { name = "MortalStrike",
      matches = mortal_strike_matches,
      execute = function(context) return NS.try_cast(SPELLS.MortalStrike, context.target, "[LEVELING] Mortal Strike") end },

    -- Overpower
    { name = "Overpower",
      matches = overpower_matches,
      execute = function(context)
          -- Overpower requires Battle Stance — stance dance if needed
          if context.stance and context.stance ~= 1 then
              if spell_ready(SPELLS.BattleStance) then
                  return NS.try_cast(SPELLS.BattleStance, nil, "[LEVELING] Battle Stance for Overpower")
              end
              return false
          end
          return NS.try_cast(SPELLS.Overpower, context.target, "[LEVELING] Overpower")
      end },

    -- PvP: Disarm (after Shield Bash, before Charge)
    { name = "Disarm",
      matches = disarm_matches,
      execute = function(context)
          if context.stance ~= STANCE.DEFENSIVE then
              if (context.rage or 0) > 25 then return false end
              if spell_ready(SPELLS.DefensiveStance) then
                  return NS.try_cast(SPELLS.DefensiveStance, nil, "[LEVELING] Defensive Stance for Disarm")
              end
              return false
          end
          local label = context._disarm_burst_name
              and ("[LEVELING] Disarm → " .. context._disarm_burst_name)
              or "[LEVELING] Disarm"
          return NS.try_cast(SPELLS.Disarm, context.target, label, { expected_cooldown = 60 })
      end },

    -- Rage dump: Heroic Strike
    { name = "HeroicStrike",
      matches = heroic_strike_matches,
      execute = function(context) return NS.try_cast(SPELLS.HeroicStrike, context.target, "[LEVELING] Heroic Strike") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = warrior_leveling.build_state })
end

-- ============================================================================
-- Rotation entry point
-- ============================================================================

function warrior_leveling.on_update(context)
    if not context then return false end
    if not is_leveling_context(context) then return false end

    local state = warrior_leveling.build_state(context)
    if not state then return false end

    -- Evaluate strategies in priority order
    for i = 1, #strategies do
        local strategy = strategies[i]
        local ok, should_execute = pcall(strategy.matches, context, state)
        if ok and should_execute then
            local ok2, result = pcall(strategy.execute, context)
            if ok2 and result then
                return true
            end
        end
    end

    return false
end

-- [Warrior] Leveling rotation loaded (Classic)
warrior_leveling.strategies = strategies

return warrior_leveling
