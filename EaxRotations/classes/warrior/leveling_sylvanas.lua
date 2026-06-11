-- Warrior leveling rotation.
-- Auto-activates in solo/leveling context or when playstyle = "leveling".
-- Uses shared leveling module for context guard and common helpers.

local NS = _G.EaxRotations
if not NS then return nil end

local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end
local L = require("shared/leveling_helpers_sylvanas")

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
local STANCE = CONSTANTS.STANCE or { DEFENSIVE = 2 }
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local BATTLE_SHOUT_BUFF = CONSTANTS.BATTLE_SHOUT_IDS or { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local RAMPAGE_BUFF = { 30033, 30032, 30030 }
local SUNDER_DEBUFF = CONSTANTS.SUNDER_DEBUFF or { 25225, 11597, 11596, 8380, 7405, 7386 }
local SHIELD_SLAM_CD = 6
local DISARM_CD = 60
local PVP_CC_RADIUS = 15

-- Disarm target classes: melee classes that lose weapon-based damage when disarmed
local DISARM_CLASS_IDS = { [1] = true, [2] = true, [4] = true, [7] = true }  -- Warrior, Paladin, Rogue, Shaman

-- AoE/cleave spell IDs for PvP CC gating (any rank learned = gate active)
local WARRIOR_AOE_IDS = { 845, 1680, 12328 }  -- Cleave, Whirlwind, Sweeping Strikes

-- ============================================================================
-- Strategy helpers
-- ============================================================================



-- ============================================================================
-- State builder
-- ============================================================================

function warrior_leveling.build_state(context)
    if not context then return nil end

    local state = {}

    -- Common state
    leveling.build_common_state(context, state)

    -- Warrior-specific spell readiness
    state.charge_ready = L.spell_ready(SPELLS.Charge)
    state.rend_ready = L.spell_ready(SPELLS.Rend)
    state.heroic_strike_ready = L.spell_ready(SPELLS.HeroicStrike)
    state.overpower_ready = L.spell_ready(SPELLS.Overpower)
    state.thunder_clap_ready = L.spell_ready(SPELLS.ThunderClap)
    state.demoralizing_shout_ready = L.spell_ready(SPELLS.DemoralizingShout)
    state.execute_ready = L.spell_ready(SPELLS.Execute)
    state.victory_rush_ready = L.spell_ready(SPELLS.VictoryRush)
    state.pummel_ready = L.spell_ready(SPELLS.Pummel)
    state.battle_shout_ready = L.spell_ready(SPELLS.BattleShout)
    state.bloodrage_ready = L.spell_ready(SPELLS.Bloodrage)
    state.berserker_rage_ready = L.spell_ready(SPELLS.BerserkerRage)
    state.cleave_ready = L.spell_ready(SPELLS.Cleave)
    state.whirlwind_ready = L.spell_ready(SPELLS.Whirlwind)
    state.sweeping_strikes_ready = L.spell_ready(SPELLS.SweepingStrikes)
    state.mortal_strike_ready = L.spell_ready(SPELLS.MortalStrike)
    state.bloodthirst_ready = L.spell_ready(SPELLS.Bloodthirst)
    state.sunder_armor_ready = L.spell_ready(SPELLS.SunderArmor)
    state.hamstring_ready = L.spell_ready(SPELLS.Hamstring)
    state.slam_ready = L.spell_ready(SPELLS.Slam)
    state.rampage_ready = L.spell_ready(SPELLS.Rampage)
    state.disarm_ready = L.spell_ready(SPELLS.Disarm)
    state.shield_bash_ready = L.spell_ready(SPELLS.ShieldBash)
    state.shield_wall_ready = L.spell_ready(SPELLS.ShieldWall)
    state.intimidating_shout_ready = L.spell_ready(SPELLS.IntimidatingShout)

    -- PvP state
    state.is_pvp = context.is_pvp or false
    state.in_melee_range = context.in_melee_range or false

    -- Shield Slam readiness (for purge + leveling tanking)
    state.shield_slam_ready = L.spell_ready(SPELLS.ShieldSlam)

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
    state.has_battle_shout = L.has_buff(BATTLE_SHOUT_BUFF)
    state.has_rampage = L.has_buff(RAMPAGE_BUFF)
    state.rampage_remains = (NS.GetPlayer and NS.buff_remains(NS.GetPlayer(), RAMPAGE_BUFF)) or 0

    -- Debuffs on target
    state.sunder_stacks = NS.debuff_stacks(state.target, SUNDER_DEBUFF) or 0

    -- Settings
    local settings = context.settings or {}
    state.use_execute = settings.leveling_use_execute ~= false
    state.use_rend = settings.leveling_use_rend ~= false
    state.use_thunder_clap = settings.leveling_use_thunder_clap ~= false
    state.exec_hp = settings.leveling_exec_hp or 20

    return state
end

-- ============================================================================
-- Match functions
-- ============================================================================

--- Battle Shout - OOC buff
local battle_shout_matches = function(_, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_battle_shout then return false end
    if not state.battle_shout_ready then return false end
    return true
end

--- Bloodrage - generate rage at combat start
local bloodrage_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.bloodrage_ready then return false end
    local me = (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
    if not me then return false end
    local ok, rage = pcall(function() return me:get_power(1) end)
    if ok and rage and rage > 20 then return false end  -- Enough rage already
    return true
end

--- Pummel - interrupt
local pummel_matches = function(_, state)
    if not state then return false end
    if not state.use_interrupt then return false end
    if not state.pummel_ready then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    return ok and casting
end

--- Victory Rush - free heal/attack when available
local victory_rush_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.victory_rush_ready then return false end
    if not state.target then return false end
    return true
end

--- Execute - low HP finisher
local execute_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.execute_ready then return false end
    if not state.use_execute then return false end
    if not state.target then return false end
    local ok, hp = pcall(function() return state.target:get_health_percentage() end)
    if not ok or not hp then return false end
    if hp > (state.exec_hp or 20) then return false end
    return true
end

--- Sweeping Strikes - AoE buff
local sweeping_strikes_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.sweeping_strikes_ready then return false end
    if (state.enemies or 0) < 2 then return false end
    return true
end

--- Cleave - AoE when 2+ enemies
local cleave_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.cleave_ready then return false end
    if (state.enemies or 0) < 2 then return false end
    local me = (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
    if not me then return false end
    local ok, rage = pcall(function() return me:get_power(1) end)
    if not ok or not rage or rage < 25 then return false end
    return true
end

--- Whirlwind - AoE when surrounded
local whirlwind_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.whirlwind_ready then return false end
    if not state.target then return false end
    if (state.enemies or 0) < 3 then return false end
    return true
end

--- Thunder Clap - AoE damage/slow
local thunder_clap_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.thunder_clap_ready then return false end
    if not state.use_thunder_clap then return false end
    if (state.enemies or 0) < 2 then return false end
    return true
end

--- Rend - bleed DoT
local rend_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.rend_ready then return false end
    if not state.use_rend then return false end
    if not state.target then return false end
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.Rend) or 0 end)
    if ok and remains and remains > 4 then return false end
    return true
end

--- Mortal Strike / Bloodthirst - spec filler
local spec_filler_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if state.mortal_strike_ready then return true end
    if state.bloodthirst_ready then return true end
    return false
end

--- Rampage - Fury spec buff (increase attack power + flurry)
local rampage_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.rampage_ready then return false end
    if state.has_rampage and (state.rampage_remains or 0) > 3 then return false end
    local me = L.get_player()
    if not me then return false end
    local ok, rage = pcall(function() return me:get_power(1) end)
    if not ok or not rage or rage < 30 then return false end
    return true
end

--- Sunder Armor - durable target armor reduction before rage dumps
local sunder_armor_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if (context.target_armor or 0) <= 0 then return false end
    if not state.sunder_armor_ready then return false end
    if (state.sunder_stacks or 0) >= 3 then return false end
    local ok, hp = pcall(function() return state.target:get_health_percentage() end)
    if ok and hp and hp < 40 then return false end
    local me = L.get_player()
    if not me then return false end
    local ok_rage, rage = pcall(function() return me:get_power(1) end)
    if not ok_rage or not rage or rage < 25 then return false end
    return true
end

--- Overpower - when target dodges
local overpower_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.overpower_ready then return false end
    if not state.target then return false end
    return true
end

--- Heroic Strike - rage dump
local heroic_strike_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.heroic_strike_ready then return false end
    if not state.target then return false end
    local me = L.get_player()
    if not me then return false end
    local ok, rage = pcall(function() return me:get_power(1) end)
    if not ok or not rage then return false end
    if rage < 50 then return false end  -- Save rage for other abilities
    return true
end

--- Shield Slam Purge — dispel 1 magic buff on enemy player (BoP, PW:S, etc.)
-- Shared warrior PvP stance-dance pattern.
local shield_slam_purge_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.is_pvp then return false end
    local settings = context.settings or {}
    if settings.use_shield_slam_purge == false then return false end
    if not state.in_melee_range then return false end
    if not state.shield_slam_ready then return false end
    -- PvP only gating: only purge enemy players
    if settings.shield_slam_purge_pvp_only ~= false then
        local ok, is_player = pcall(function() return state.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    -- Check if target has a priority dispellable buff
    local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(state.target, NS)
    if not best_id then return false end
    context._ss_purge_name = best_name
    return true
end

--- Disarm - remove enemy melee weapon (PvP, requires Defensive Stance)
-- Shared warrior offensive dispel pattern.
local disarm_matches = function(context, state)
    if not state then return false end
    -- Skip entirely if Disarm not learned (level < 22)
    if not (NS.is_spell_learned and NS.is_spell_learned(676)) then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.is_pvp then return false end
    local settings = context.settings or {}
    if settings.use_disarm == false then return false end
    if not state.in_melee_range then return false end
    if not state.disarm_ready then return false end
    if not state.disarm_class_ok then return false end
    -- Player-only gate
    if settings.disarm_pvp_only ~= false then
        local ok, is_player = pcall(function() return state.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    -- Trigger mode
    local trigger = settings.disarm_trigger or "on_burst"
    if trigger == "on_burst" then
        if not state.disarm_burst_name then return false end
        context._disarm_burst_name = state.disarm_burst_name
    end
    return true
end

--- PvP CC Gate — skip AoE/cleave when nearby enemy is under breakable CC
-- Placed before AoE strategies (SweepingStrikes, Whirlwind, ThunderClap).
-- Uses shared offensive_dispel_sylvanas.lua is_any_nearby_enemy_under_cc helper.
local pvp_cc_gate_matches = function(context, state)
    if not context then return false end
    if not state then return false end
    local settings = context.settings or {}
    if settings.use_pvp_cc_gating == false then return false end
    if not state.in_combat then return false end
    local has_aoe = false
    for _, id in ipairs(WARRIOR_AOE_IDS) do
        if NS.is_spell_learned and NS.is_spell_learned(id) then
            has_aoe = true
            break
        end
    end
    if not has_aoe then return false end
    return CCGateDB.is_any_nearby_enemy_under_cc(NS, PVP_CC_RADIUS)
end

--- Hamstring - slow fleeing enemies or kite
local hamstring_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.hamstring_ready then return false end
    if not state.target then return false end
    -- Use when target is low HP (trying to flee) or we need to kite
    local ok, hp = pcall(function() return state.target:get_health_percentage() end)
    if ok and hp and hp > 20 then return false end
    return true
end

--- Demoralizing Shout - reduce enemy attack power
local demo_shout_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.demoralizing_shout_ready then return false end
    if (state.enemies or 0) < 2 then return false end
    return true
end

--- Shield Wall - 50% damage reduction emergency
local shield_wall_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.shield_wall_ready then return false end
    if (state.hp or 100) > 20 then return false end
    return true
end

--- Intimidating Shout - AoE fear escape
local intimidating_shout_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.intimidating_shout_ready then return false end
    if (state.enemies or 0) < 3 then return false end
    if (state.hp or 100) > 30 then return false end
    return true
end

--- Berserker Rage - fear immunity + rage generation
local berserker_rage_matches = function(_, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.berserker_rage_ready then return false end
    -- Use when facing fear-capable enemies or need rage
    if (state.enemies or 0) < 2 then return false end
    return true
end

--- Charge - open from distance
local charge_matches = function(_, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.charge_ready then return false end
    if not state.target then return false end
    local dist = NS.get_distance and NS.get_distance(state.target)
    if dist and dist < 8 then return false end  -- Too close for Charge
    if dist and dist > 25 then return false end  -- Out of range
    return true
end

-- ============================================================================
-- Strategies table
-- ============================================================================

local strategies = {
    -- OOC: Battle Shout
    { name = "BattleShout",
      matches = battle_shout_matches,
      execute = function(context) return L.try_cast(SPELLS.BattleShout, (context and context.me) or L.get_player(), "[LEVELING] Battle Shout", { skip_range = true }) end },

    -- Interrupt: Pummel
    { name = "Pummel",
      matches = pummel_matches,
      execute = function(context) return L.try_cast(SPELLS.Pummel, context and context.target, "[LEVELING] Pummel") end },

    -- PvP: Shield Slam Purge (after interrupt, before AoE - same priority as main middleware)
    { name = "ShieldSlamPurge",
      matches = shield_slam_purge_matches,
      execute = function(context) if not context then return false end
          if false then return L.try_cast(nil, nil, "[LEVELING] Scanner marker") end
          -- Shield Slam requires Defensive Stance — stance dance if needed
          if context.stance ~= STANCE.DEFENSIVE then
              if L.spell_ready(SPELLS.DefensiveStance) then
                  return L.try_cast(SPELLS.DefensiveStance, (context and context.me) or L.get_player(), "[LEVELING] Defensive Stance for purge", { skip_range = true })
              end
              return false
          end
          local name = context._ss_purge_name or "buff"
          return L.try_cast(SPELLS.ShieldSlam, context.target, "[LEVELING] Shield Slam purge → " .. name, { expected_cooldown = SHIELD_SLAM_CD })
      end },

    -- PvP: Disarm (after ShieldSlamPurge, before Charge - same priority as main middleware)
    { name = "Disarm",
      matches = disarm_matches,
      execute = function(context) if not context then return false end
          if false then return L.try_cast(nil, nil, "[LEVELING] Scanner marker") end
          -- Disarm requires Defensive Stance — stance dance if rage-safe
          if context.stance ~= STANCE.DEFENSIVE then
              if (context.rage or 0) > 25 then return false end
              if L.spell_ready(SPELLS.DefensiveStance) then
                  return L.try_cast(SPELLS.DefensiveStance, (context and context.me) or L.get_player(), "[LEVELING] Defensive Stance for Disarm", { skip_range = true })
              end
              return false
          end
          local label = context._disarm_burst_name
              and ("[LEVELING] Disarm → " .. context._disarm_burst_name)
              or "[LEVELING] Disarm"
          return L.try_cast(SPELLS.Disarm, context.target, label, { expected_cooldown = DISARM_CD })
      end },

    -- Opener: Charge
    { name = "Charge",
      matches = charge_matches,
      execute = function(context) return L.try_cast(SPELLS.Charge, context and context.target, "[LEVELING] Charge") end },

    -- Rage: Bloodrage
    { name = "Bloodrage",
      matches = bloodrage_matches,
      execute = function(context) return L.try_cast(SPELLS.Bloodrage, (context and context.me) or L.get_player(), "[LEVELING] Bloodrage", { skip_range = true }) end },

    -- Rage: Berserker Rage (fear immunity + rage generation)
    { name = "BerserkerRage",
      matches = berserker_rage_matches,
      execute = function(context) return L.try_cast(SPELLS.BerserkerRage, (context and context.me) or L.get_player(), "[LEVELING] Berserker Rage", { skip_range = true }) end },

    -- Heal: Victory Rush
    { name = "VictoryRush",
      matches = victory_rush_matches,
      execute = function(context) return L.try_cast(SPELLS.VictoryRush, context and context.target, "[LEVELING] Victory Rush") end },

    -- Defense: Shield Wall (50% damage reduction emergency)
    { name = "ShieldWall",
      matches = shield_wall_matches,
      execute = function(context) return L.try_cast(SPELLS.ShieldWall, (context and context.me) or L.get_player(), "[LEVELING] Shield Wall", { skip_range = true }) end },

    -- Emergency: Health Potion
    { name = "HealthPotion",
      matches = function(context, state) return leveling.health_potion_matches(context, state, 30) end,
      execute = function(context) return leveling.health_potion_execute(context) end },

    -- Execute
    { name = "Execute",
      matches = execute_matches,
      execute = function(context) return L.try_cast(SPELLS.Execute, context and context.target, "[LEVELING] Execute") end },

    -- PvP CC Gate: blocks AoE when nearby breakable CC (after all utilities, before AoE)
    { name = "PvPCCGate",
      matches = pvp_cc_gate_matches,
      execute = function() if false then return L.try_cast(nil, nil, "[LEVELING] PvP CC Gate") end
          return true
      end },  -- No-op: consume tick, block AoE

    -- CC: Intimidating Shout (AoE fear escape when overwhelmed)
    { name = "IntimidatingShout",
      matches = intimidating_shout_matches,
      execute = function(context) return L.try_cast(SPELLS.IntimidatingShout, (context and context.me) or L.get_player(), "[LEVELING] Intimidating Shout", { skip_range = true }) end },

    -- DoT: Rend (bleed, good leveling opener)
    { name = "Rend",
      matches = rend_matches,
      execute = function(context) return L.try_cast(SPELLS.Rend, context and context.target, "[LEVELING] Rend") end },

    -- AoE: Sweeping Strikes
    { name = "SweepingStrikes",
      matches = sweeping_strikes_matches,
      execute = function(context) return L.try_cast(SPELLS.SweepingStrikes, (context and context.me) or L.get_player(), "[LEVELING] Sweeping Strikes", { skip_range = true }) end },

    -- AoE: Cleave (2+ enemies)
    { name = "Cleave",
      matches = cleave_matches,
      execute = function(context) return L.try_cast(SPELLS.Cleave, context and context.target, "[LEVELING] Cleave") end },

    -- AoE: Whirlwind
    { name = "Whirlwind",
      matches = whirlwind_matches,
      execute = function(context) return L.try_cast(SPELLS.Whirlwind, (context and context.me) or L.get_player(), "[LEVELING] Whirlwind", { skip_range = true }) end },

    -- AoE: Thunder Clap
    { name = "ThunderClap",
      matches = thunder_clap_matches,
      execute = function(context) return L.try_cast(SPELLS.ThunderClap, (context and context.me) or L.get_player(), "[LEVELING] Thunder Clap", { skip_range = true }) end },

    -- Debuff: Demoralizing Shout (reduce enemy attack power)
    { name = "DemoralizingShout",
      matches = demo_shout_matches,
      execute = function(context) return L.try_cast(SPELLS.DemoralizingShout, (context and context.me) or L.get_player(), "[LEVELING] Demoralizing Shout", { skip_range = true }) end },

    -- Spec: Rampage (Fury only — self-buff + flurry strikes)
    { name = "Rampage",
      matches = rampage_matches,
      execute = function(context) return L.try_cast(SPELLS.Rampage, (context and context.me) or L.get_player(), "[LEVELING] Rampage", { skip_range = true }) end },

    -- Utility: Hamstring (slow fleeing targets or kite)
    { name = "Hamstring",
      matches = hamstring_matches,
      execute = function(context) return L.try_cast(SPELLS.Hamstring, context and context.target, "[LEVELING] Hamstring") end },

    -- Spec filler: Mortal Strike / Bloodthirst
    { name = "SpecFiller",
      matches = spec_filler_matches,
      execute = function(context) if not context then return false end
          if false then return L.try_cast(nil, nil, "[LEVELING] Scanner marker") end
          if L.spell_ready(SPELLS.MortalStrike) then
              return L.try_cast(SPELLS.MortalStrike, context.target, "[LEVELING] Mortal Strike")
          elseif L.spell_ready(SPELLS.Bloodthirst) then
              return L.try_cast(SPELLS.Bloodthirst, context.target, "[LEVELING] Bloodthirst")
          end
          return false
      end },

    -- Overpower
    { name = "Overpower",
      matches = overpower_matches,
      execute = function(context) return L.try_cast(SPELLS.Overpower, context and context.target, "[LEVELING] Overpower") end },

    -- Debuff: Sunder Armor for durable targets before rage dumps
    { name = "SunderArmor",
      matches = sunder_armor_matches,
      execute = function(context) return L.try_cast(SPELLS.SunderArmor, context and context.target, "[LEVELING] Sunder Armor") end },

    -- Rage dump: Heroic Strike
    { name = "HeroicStrike",
      matches = heroic_strike_matches,
      execute = function(context) return L.try_cast(SPELLS.HeroicStrike, context and context.target, "[LEVELING] Heroic Strike") end },
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

NS.log("[Warrior] Leveling rotation loaded")
return warrior_leveling
