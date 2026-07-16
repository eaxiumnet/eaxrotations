-- arms_wotlk.lua — Warrior Arms rotation for Wrath of the Lich King (3.3.5a).
-- WHAT:  priority-list strategies for Arms warrior DPS: Rend maintenance, Mortal Strike,
--        Overpower (Taste for Blood), Execute, Bladestorm, Sweeping Strikes, Slam filler,
--        Hamstring PvP root, stance management, Shield Wall/Retaliation defensives.
-- WHEN:  combat with a valid enemy target; Battle Stance default, Berserker for Intercept/Pummel.
-- WHY:   mirrors SimulationCraft / wowsims WotLK Arms APL with 3.3.5a-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); all match functions return
--         explicit booleans; no on_update() allocations; cooldown reads guarded for raw-ID fallbacks.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

-- Centralized spell resolver via spec_kit (replaces per-spec spell() helper).
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    BattleStance      = define("BattleStance", 2457, "BattleStance"),
    BerserkerStance   = define("BerserkerStance", 2458, "BerserkerStance"),
    BattleShout       = define("BattleShout", { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    CommandingShout   = define("CommandingShout", { 469, 47439 }, "CommandingShout"),
    Charge            = define("Charge", { 11578, 6178, 100 }, "Charge"),
    Intercept         = define("Intercept", { 25275, 20617, 20616, 20252 }, "Intercept"),
    Rend              = define("Rend", { 47465, 25208, 11574, 11573, 6548, 6547, 772 }, "Rend"),
    MortalStrike      = define("MortalStrike", { 47486, 30330, 25248, 21553, 21552, 21551, 12294 }, "MortalStrike"),
    Overpower         = define("Overpower", { 11585, 11584, 7887, 7384 }, "Overpower"),
    Execute           = define("Execute", { 47498, 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    Bladestorm        = define("Bladestorm", 46924, "Bladestorm"),
    SweepingStrikes   = define("SweepingStrikes", 12328, "SweepingStrikes"),
    Slam              = define("Slam", { 47475, 25242, 25241, 11605, 11604, 8820, 1464 }, "Slam"),
    HeroicStrike      = define("HeroicStrike", { 47497, 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    ThunderClap       = define("ThunderClap", { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    DemoralizingShout = define("DemoralizingShout", { 47437, 25203, 25202, 11556, 11555, 11554, 6190, 1160 }, "DemoralizingShout"),
    Hamstring         = define("Hamstring", { 25212, 7373, 7372, 1715 }, "Hamstring"),
    Pummel            = define("Pummel", { 6554, 6552 }, "Pummel"),
    ShieldWall        = define("ShieldWall", { 871 }, "ShieldWall"),
    Retaliation       = define("Retaliation", 20230, "Retaliation"),
}

-- Debuff / buff ID tables (WotLK rank chains)
local REND_DEBUFF         = { 47465, 25208, 11574, 11573, 6548, 6547, 772 }
local BATTLE_SHOUT_BUFF   = { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local DEMO_SHOUT_DEBUFF   = { 47437, 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local THUNDER_CLAP_DEBUFF = { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
local HAMSTRING_DEBUFF    = { 25212, 7373, 7372, 1715 }
-- Taste for Blood proc aura (enables Overpower without a dodge). 60503 = rank 1 proc.
local TASTE_FOR_BLOOD_BUFF = { 60503, 56636 }

local REND_REFRESH_SECONDS = 5     -- refresh Rend when remaining < 5s
local EXECUTE_RAGE_MIN     = 10    -- Execute minimum rage cost
local SLAM_RAGE_MIN        = 15    -- Slam minimum rage
local HEROIC_RAGE_MIN      = 60    -- Heroic Strike rage dump threshold

-- -----------------------------------------------------------------------------
-- State table (raw; safe_state proxy applied in build_state)
-- -----------------------------------------------------------------------------
local arms_state = {
    rage = 0,
    hp = 100,
    target_hp = 100,
    stance = STANCE.BATTLE,
    enemy_count = 1,
    in_combat = false,
    is_moving = false,
    is_pvp = false,
    is_boss = false,
    target_distance = 0,
    target_casting = false,
    rend_remains = 0,
    ms_cd = 99,
    overpower_ready = false,
    overpower_cd = 99,
    execute_ready = false,
    bladestorm_ready = false,
    sweeping_ready = false,
    intercept_ready = false,
    pummel_ready = false,
    charge_ready = false,
    shieldwall_ready = false,
    retaliation_ready = false,
    battle_shout_up = false,
    demo_remains = 0,
    tclap_remains = 0,
    hamstring_remains = 0,
}

-- -----------------------------------------------------------------------------
-- Helpers (nil-guarded against missing NS APIs / raw-ID action fallbacks)
-- -----------------------------------------------------------------------------

-- Cooldown helper: returns remaining seconds, or `fallback` when the action is a
-- raw spell ID (no method) or the method is unavailable. Never errors.
local function cd_remaining(action, fallback)
    if action and type(action.cooldown_remaining) == "function" then
        local ok, val = pcall(action.cooldown_remaining, action)
        if ok and type(val) == "number" then return val end
    end
    return fallback or 99
end

local function is_boss(context)
    if NS and type(NS.gate_cooldown_boss_only) == "function" then
        return NS.gate_cooldown_boss_only() == true
    end
    return false
end

local function target_is_casting(target)
    if not target then return false end
    if type(target.is_casting) == "function" then
        local ok, val = pcall(target.is_casting, target)
        if ok and val then return true end
    end
    return false
end

local function target_is_interruptible(target)
    if NS and type(NS.is_interruptible) == "function" then
        return NS.is_interruptible(target) == true
    end
    return false
end

-- -----------------------------------------------------------------------------
-- build_state(context) — populate state from context + NS, return safe_state proxy
-- -----------------------------------------------------------------------------
local function build_state(context)
    local state = spec_kit.safe_state(arms_state)
    context = context or {}
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context.target

    -- Player resources
    state.rage = (me and type(me.get_rage) == "function" and me:get_rage()) or 0
    state.hp = (me and type(me.get_health_percentage) == "function" and me:get_health_percentage()) or 100
    state.stance = (me and type(me.get_stance) == "function" and me:get_stance()) or STANCE.BATTLE
    state.is_moving = (context.is_moving == true)

    -- Target state
    state.target_hp = (target and type(target.get_health_percentage) == "function" and target:get_health_percentage()) or 100
    state.target_distance = (context.target_distance or 0)
    state.target_casting = target_is_casting(target)

    -- Encounter context
    state.enemy_count = (context.enemy_count or 1)
    state.in_combat = (context.in_combat == true)
    state.is_pvp = (context.is_pvp == true) or spec_kit.setting_bool(context, "pvp_mode", false)
    state.is_boss = is_boss(context)

    -- Debuff tracking on target
    state.rend_remains = (target and NS.debuff_remains and NS.debuff_remains(target, REND_DEBUFF)) or 0
    state.demo_remains = (target and NS.debuff_remains and NS.debuff_remains(target, DEMO_SHOUT_DEBUFF)) or 0
    state.tclap_remains = (target and NS.debuff_remains and NS.debuff_remains(target, THUNDER_CLAP_DEBUFF)) or 0
    state.hamstring_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HAMSTRING_DEBUFF)) or 0

    -- Buff tracking on player
    state.battle_shout_up = (me and NS.buff_up and NS.buff_up(me, BATTLE_SHOUT_BUFF)) or false
    state.overpower_ready = (me and NS.buff_up and NS.buff_up(me, TASTE_FOR_BLOOD_BUFF)) or false

    -- Cooldown / availability tracking (guarded for raw-ID fallbacks)
    state.ms_cd = cd_remaining(ACTION.MortalStrike, 99)
    state.overpower_cd = cd_remaining(ACTION.Overpower, 99)
    state.execute_ready = ((state.target_hp or 100) < 20)
    state.bladestorm_ready = (cd_remaining(ACTION.Bladestorm, 99) <= 0)
    state.sweeping_ready = (cd_remaining(ACTION.SweepingStrikes, 99) <= 0)
    state.intercept_ready = (cd_remaining(ACTION.Intercept, 99) <= 0)
    state.pummel_ready = (cd_remaining(ACTION.Pummel, 99) <= 0)
    state.charge_ready = (cd_remaining(ACTION.Charge, 99) <= 0)
    state.shieldwall_ready = (cd_remaining(ACTION.ShieldWall, 99) <= 0)
    state.retaliation_ready = (cd_remaining(ACTION.Retaliation, 99) <= 0)

    return state
end

-- -----------------------------------------------------------------------------
-- Match functions (one per strategy). Each returns an explicit boolean.
-- -----------------------------------------------------------------------------

-- Shield Wall: defensive emergency when HP < 30%.
local function shield_wall_matches(context, state)
    if not state.in_combat then return false end
    if not state.shieldwall_ready then return false end
    if (state.hp or 100) >= 30 then return false end
    return true
end

-- Retaliation: boss offensive cooldown.
local function retaliation_matches(context, state)
    if not state.in_combat then return false end
    if not state.retaliation_ready then return false end
    if not state.is_boss then return false end
    if (state.rage or 0) < 10 then return false end
    return true
end

-- Battle Shout: maintain the buff when it is not up.
local function battle_shout_matches(context, state)
    if state.battle_shout_up then return false end
    return true
end

-- Charge: opener / gap closer when out of combat and target is in Charge range.
local function charge_matches(context, state)
    if state.in_combat then return false end
    if not state.charge_ready then return false end
    local dist = (state.target_distance or 0)
    if dist < 8 or dist > 25 then return false end
    return true
end

-- Berserker Stance: switch when we need Intercept (far target) or Pummel (target casting).
local function berserker_stance_matches(context, state)
    if not state.in_combat then return false end
    if (state.stance or STANCE.BATTLE) == STANCE.BERSERKER then return false end
    local dist = (state.target_distance or 0)
    local need_intercept = dist >= 8 and dist <= 25 and state.intercept_ready
    local need_pummel = state.target_casting and target_is_interruptible(context.target) and state.pummel_ready
    if need_intercept or need_pummel then return true end
    return false
end

-- Battle Stance: switch back to the default stance when Battle-only abilities are needed.
local function battle_stance_matches(context, state)
    if not state.in_combat then return false end
    if (state.stance or STANCE.BATTLE) == STANCE.BATTLE then return false end
    -- Return to Battle when Rend needs refreshing or Overpower is proc'd/available.
    if (state.rend_remains or 0) < REND_REFRESH_SECONDS then return true end
    if state.overpower_ready then return true end
    return false
end

-- Intercept: gap closer in Berserker Stance when target is far.
local function intercept_matches(context, state)
    if not state.in_combat then return false end
    if not state.intercept_ready then return false end
    local dist = (state.target_distance or 0)
    if dist < 8 or dist > 25 then return false end
    if (state.rage or 0) < 10 then return false end
    return true
end

-- Pummel: interrupt a casting target (requires Berserker Stance).
local function pummel_matches(context, state)
    if not state.in_combat then return false end
    if not state.target_casting then return false end
    if not target_is_interruptible(context.target) then return false end
    if not state.pummel_ready then return false end
    return true
end

-- Rend: maintain the bleed, refresh when remaining < 5s.
local function rend_matches(context, state)
    if not state.in_combat then return false end
    if (state.rage or 0) < 10 then return false end
    if (state.rend_remains or 0) >= REND_REFRESH_SECONDS then return false end
    return true
end

-- Mortal Strike: primary attack, on cooldown.
local function mortal_strike_matches(context, state)
    if not state.in_combat then return false end
    if (state.ms_cd or 99) > 0 then return false end
    if (state.rage or 0) < 30 then return false end
    return true
end

-- Overpower: when Taste for Blood procs or the ability is available.
local function overpower_matches(context, state)
    if not state.in_combat then return false end
    if (state.rage or 0) < 5 then return false end
    if state.overpower_ready then return true end
    if (state.overpower_cd or 99) <= 0 then return true end
    return false
end

-- Execute: when target is below 20% HP.
local function execute_matches(context, state)
    if not state.in_combat then return false end
    if not state.execute_ready then return false end
    if (state.rage or 0) < EXECUTE_RAGE_MIN then return false end
    return true
end

-- Sweeping Strikes: AoE setup when 2+ near primary target.
local function sweeping_strikes_matches(context, state)
    if not state.in_combat then return false end
    if not state.sweeping_ready then return false end
    if not (NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context and context.target, context, state)) then
        return false
    end
    if (state.rage or 0) < 30 then return false end
    return true
end

-- Bladestorm: on cooldown for boss fights or AoE (2+ in melee volume).
local function bladestorm_matches(context, state)
    if not state.in_combat then return false end
    if not state.bladestorm_ready then return false end
    if (state.rage or 0) < 25 then return false end
    local aoe = NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)
    if not (state.is_boss or aoe) then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 90) then return false end
    return true
end

-- Thunder Clap: 8yd self PBAoE attack-speed slow for AoE pulls.
local function thunder_clap_matches(context, state)
    if not state.in_combat then return false end
    if not (NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)) then
        return false
    end
    if (state.tclap_remains or 0) >= 3 then return false end
    if (state.rage or 0) < 20 then return false end
    return true
end

-- Demoralizing Shout: maintain the attack-power debuff.
local function demoralizing_shout_matches(context, state)
    if not state.in_combat then return false end
    if (state.demo_remains or 0) >= 3 then return false end
    if (state.rage or 0) < 10 then return false end
    return true
end

-- Hamstring: PvP root, maintain the snare in PvP mode.
local function hamstring_matches(context, state)
    if not state.in_combat then return false end
    if not state.is_pvp then return false end
    if (state.hamstring_remains or 0) >= 3 then return false end
    if (state.rage or 0) < 10 then return false end
    return true
end

-- Slam: rage dump / filler when nothing else is available and not moving.
local function slam_matches(context, state)
    if not state.in_combat then return false end
    if state.is_moving then return false end
    if (state.rage or 0) < SLAM_RAGE_MIN then return false end
    return true
end

-- Heroic Strike: high-rage dump (queued next swing) when rage is abundant.
local function heroic_strike_matches(context, state)
    if not state.in_combat then return false end
    if (state.rage or 0) < HEROIC_RAGE_MIN then return false end
    return true
end

-- -----------------------------------------------------------------------------
-- Strategy table (ordered priority list — first match wins each tick)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "ShieldWall",        matches = shield_wall_matches,        execute = function(ctx) return ACTION.ShieldWall and ACTION.ShieldWall:cast_safe() end },
    { name = "Retaliation",       matches = retaliation_matches,         execute = function(ctx) return ACTION.Retaliation and ACTION.Retaliation:cast_safe() end },
    { name = "BattleShout",       matches = battle_shout_matches,        execute = function(ctx) return ACTION.BattleShout and ACTION.BattleShout:cast_safe() end },
    { name = "Charge",            matches = charge_matches,              execute = function(ctx) return ACTION.Charge and ACTION.Charge:cast_safe(ctx.target) end },
    { name = "BerserkerStance",   matches = berserker_stance_matches,    execute = function(ctx) return ACTION.BerserkerStance and ACTION.BerserkerStance:cast_safe() end },
    { name = "BattleStance",      matches = battle_stance_matches,       execute = function(ctx) return ACTION.BattleStance and ACTION.BattleStance:cast_safe() end },
    { name = "Intercept",         matches = intercept_matches,           execute = function(ctx) return ACTION.Intercept and ACTION.Intercept:cast_safe(ctx.target) end },
    { name = "Pummel",            matches = pummel_matches,              execute = function(ctx) return ACTION.Pummel and ACTION.Pummel:cast_safe(ctx.target) end },
    { name = "Rend",              matches = rend_matches,                execute = function(ctx) return ACTION.Rend and ACTION.Rend:cast_safe(ctx.target) end },
    { name = "MortalStrike",      matches = mortal_strike_matches,       execute = function(ctx) return ACTION.MortalStrike and ACTION.MortalStrike:cast_safe(ctx.target) end },
    { name = "Overpower",         matches = overpower_matches,           execute = function(ctx) return ACTION.Overpower and ACTION.Overpower:cast_safe(ctx.target) end },
    { name = "Execute",           matches = execute_matches,             execute = function(ctx) return ACTION.Execute and ACTION.Execute:cast_safe(ctx.target) end },
    { name = "SweepingStrikes",   matches = sweeping_strikes_matches,    execute = function(ctx) return ACTION.SweepingStrikes and ACTION.SweepingStrikes:cast_safe() end },
    { name = "Bladestorm",        matches = bladestorm_matches,          execute = function(ctx) return ACTION.Bladestorm and ACTION.Bladestorm:cast_safe() end },
    { name = "ThunderClap",       matches = thunder_clap_matches,        execute = function(ctx) return ACTION.ThunderClap and ACTION.ThunderClap:cast_safe(ctx.target) end },
    { name = "DemoralizingShout", matches = demoralizing_shout_matches,  execute = function(ctx) return ACTION.DemoralizingShout and ACTION.DemoralizingShout:cast_safe(ctx.target) end },
    { name = "Hamstring",         matches = hamstring_matches,           execute = function(ctx) return ACTION.Hamstring and ACTION.Hamstring:cast_safe(ctx.target) end },
    { name = "Slam",              matches = slam_matches,                execute = function(ctx) return ACTION.Slam and ACTION.Slam:cast_safe(ctx.target) end },
    { name = "HeroicStrike",      matches = heroic_strike_matches,       execute = function(ctx) return ACTION.HeroicStrike and ACTION.HeroicStrike:cast_safe(ctx.target) end },
}

-- Register (guarded — nil-safe in unit tests)
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("arms", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warrior Arms WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
