-- Warrior leveling rotation.
-- Auto-activates in solo/leveling context or when playstyle = "leveling".
-- Uses shared leveling module for context guard and common helpers.

local NS = _G.EaxRotations
if not NS then return nil end

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
local BATTLE_SHOUT_BUFF = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }

-- ============================================================================
-- Strategy helpers
-- ============================================================================

local function spell_ready(spell_action)
    if not spell_action then return false end
    return NS.spell_ready and NS.spell_ready(spell_action) or false
end

local function try_cast(spell_action, target, label)
    if not spell_action then return false end
    local ok, result = pcall(NS.try_cast, spell_action, target, label or "")
    return ok and result == true
end

local function has_buff(buff_ids)
    if not buff_ids then return false end
    local me = NS.get_local_player and NS.get_local_player()
    if not me then return false end
    local ids = type(buff_ids) == "table" and buff_ids or { buff_ids }
    for _, id in ipairs(ids) do
        local ok, result = pcall(function() return me:has_buff(id) end)
        if ok and result then return true end
    end
    return false
end

-- ============================================================================
-- State builder
-- ============================================================================

function warrior_leveling.build_state(context)
    if not context then return nil end

    local state = {}

    -- Common state
    leveling.build_common_state(context, state)

    -- Warrior-specific spell readiness
    state.charge_ready = spell_ready(SPELLS.Charge)
    state.rend_ready = spell_ready(SPELLS.Rend)
    state.heroic_strike_ready = spell_ready(SPELLS.HeroicStrike)
    state.overpower_ready = spell_ready(SPELLS.Overpower)
    state.thunder_clap_ready = spell_ready(SPELLS.ThunderClap)
    state.demoralizing_shout_ready = spell_ready(SPELLS.DemoralizingShout)
    state.execute_ready = spell_ready(SPELLS.Execute)
    state.victory_rush_ready = spell_ready(SPELLS.VictoryRush)
    state.pummel_ready = spell_ready(SPELLS.Pummel)
    state.battle_shout_ready = spell_ready(SPELLS.BattleShout)
    state.bloodrage_ready = spell_ready(SPELLS.Bloodrage)
    state.berserker_rage_ready = spell_ready(SPELLS.BerserkerRage)
    state.cleave_ready = spell_ready(SPELLS.Cleave)
    state.whirlwind_ready = spell_ready(SPELLS.Whirlwind)
    state.sweeping_strikes_ready = spell_ready(SPELLS.SweepingStrikes)
    state.mortal_strike_ready = spell_ready(SPELLS.MortalStrike)
    state.bloodthirst_ready = spell_ready(SPELLS.Bloodthirst)
    state.sunder_armor_ready = spell_ready(SPELLS.SunderArmor)
    state.hamstring_ready = spell_ready(SPELLS.Hamstring)
    state.slam_ready = spell_ready(SPELLS.Slam)
    state.disarm_ready = spell_ready(SPELLS.Disarm)
    state.shield_bash_ready = spell_ready(SPELLS.ShieldBash)

    -- Buff checks
    state.has_battle_shout = has_buff(BATTLE_SHOUT_BUFF)

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
    local me = NS.get_local_player and NS.get_local_player()
    if not me then return false end
    local ok, rage = pcall(function() return me:get_power() end)
    if ok and rage and rage > 20 then return false end  -- Enough rage already
    return true
end

--- Pummel - interrupt
local pummel_matches = function(context, state)
    if not state then return false end
    if not state.use_interrupt then return false end
    if not state.pummel_ready then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    return ok and casting
end

--- Victory Rush - free heal/attack when available
local victory_rush_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.victory_rush_ready then return false end
    if not state.target then return false end
    return true
end

--- Execute - low HP finisher
local execute_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.execute_ready then return false end
    if not state.use_execute then return false end
    if not state.target then return false end
    local ok, hp = pcall(function() return state.target:get_health_percentage() end)
    if not ok or not hp then return false end
    if hp > state.exec_hp then return false end
    return true
end

--- Sweeping Strikes - AoE buff
local sweeping_strikes_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.sweeping_strikes_ready then return false end
    if state.enemies < 2 then return false end
    return true
end

--- Whirlwind - AoE when surrounded
local whirlwind_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.whirlwind_ready then return false end
    if not state.target then return false end
    if state.enemies < 3 then return false end
    return true
end

--- Thunder Clap - AoE damage/slow
local thunder_clap_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.thunder_clap_ready then return false end
    if not state.use_thunder_clap then return false end
    if state.enemies < 2 then return false end
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

--- Mortal Strike / Bloodthirst - spec filler
local spec_filler_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if state.mortal_strike_ready then return true end
    if state.bloodthirst_ready then return true end
    return false
end

--- Overpower - when target dodges
local overpower_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.overpower_ready then return false end
    if not state.target then return false end
    return true
end

--- Heroic Strike - rage dump
local heroic_strike_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.heroic_strike_ready then return false end
    if not state.target then return false end
    local me = NS.get_local_player and NS.get_local_player()
    if not me then return false end
    local ok, rage = pcall(function() return me:get_power() end)
    if not ok or not rage then return false end
    if rage < 50 then return false end  -- Save rage for other abilities
    return true
end

--- Charge - open from distance
local charge_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
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
      execute = function(context) return try_cast(SPELLS.BattleShout, nil, "[LEVELING] Battle Shout") end },

    -- Interrupt: Pummel
    { name = "Pummel",
      matches = pummel_matches,
      execute = function(context) return try_cast(SPELLS.Pummel, context.target, "[LEVELING] Pummel") end },

    -- Opener: Charge
    { name = "Charge",
      matches = charge_matches,
      execute = function(context) return try_cast(SPELLS.Charge, context.target, "[LEVELING] Charge") end },

    -- Rage: Bloodrage
    { name = "Bloodrage",
      matches = bloodrage_matches,
      execute = function(context) return try_cast(SPELLS.Bloodrage, nil, "[LEVELING] Bloodrage") end },

    -- Heal: Victory Rush
    { name = "VictoryRush",
      matches = victory_rush_matches,
      execute = function(context) return try_cast(SPELLS.VictoryRush, context.target, "[LEVELING] Victory Rush") end },

    -- Execute
    { name = "Execute",
      matches = execute_matches,
      execute = function(context) return try_cast(SPELLS.Execute, context.target, "[LEVELING] Execute") end },

    -- AoE: Sweeping Strikes
    { name = "SweepingStrikes",
      matches = sweeping_strikes_matches,
      execute = function(context) return try_cast(SPELLS.SweepingStrikes, nil, "[LEVELING] Sweeping Strikes") end },

    -- AoE: Whirlwind
    { name = "Whirlwind",
      matches = whirlwind_matches,
      execute = function(context) return try_cast(SPELLS.Whirlwind, nil, "[LEVELING] Whirlwind") end },

    -- AoE: Thunder Clap
    { name = "ThunderClap",
      matches = thunder_clap_matches,
      execute = function(context) return try_cast(SPELLS.ThunderClap, nil, "[LEVELING] Thunder Clap") end },

    -- DoT: Rend
    { name = "Rend",
      matches = rend_matches,
      execute = function(context) return try_cast(SPELLS.Rend, context.target, "[LEVELING] Rend") end },

    -- Spec filler: Mortal Strike / Bloodthirst
    { name = "SpecFiller",
      matches = spec_filler_matches,
      execute = function(context)
          if spell_ready(SPELLS.MortalStrike) then
              return try_cast(SPELLS.MortalStrike, context.target, "[LEVELING] Mortal Strike")
          elseif spell_ready(SPELLS.Bloodthirst) then
              return try_cast(SPELLS.Bloodthirst, context.target, "[LEVELING] Bloodthirst")
          end
          return false
      end },

    -- Overpower
    { name = "Overpower",
      matches = overpower_matches,
      execute = function(context) return try_cast(SPELLS.Overpower, context.target, "[LEVELING] Overpower") end },

    -- Rage dump: Heroic Strike
    { name = "HeroicStrike",
      matches = heroic_strike_matches,
      execute = function(context) return try_cast(SPELLS.HeroicStrike, context.target, "[LEVELING] Heroic Strike") end },
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
