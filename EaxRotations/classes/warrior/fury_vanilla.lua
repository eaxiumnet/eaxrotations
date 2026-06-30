-- fury_vanilla.lua — Warrior Fury for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  dual-wield/2H DPS (Bloodthirst, Whirlwind, Execute, Heroic Strike).
-- WHEN:  combat, when NS.is_vanilla() is true.
-- WHY:   top Vanilla PvE DPS spec; expansion-aware loader selects _vanilla suffix.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
local PLAYER_UNIT = NS.PLAYER_UNIT

-- Helper: resolve spell ID
local function spell(field, ids, label)
    if SPELLS[field] ~= nil then return SPELLS[field] end
    if NS.spell_action then return NS.spell_action(ids, label or field) end
    if type(ids) == "table" then return ids[1] end
    return ids
end

-- Spell actions (Classic subset ? no Bloodthirst/Rampage/VictoryRush/CommandingShout)
local ACTION = {
    BattleShout = SPELLS.BattleShout,
    BattleStance = SPELLS.BattleStance,
    BerserkerRage = SPELLS.BerserkerRage,
    BerserkerStance = SPELLS.BerserkerStance,
    Bloodrage = SPELLS.Bloodrage,
    Charge = SPELLS.Charge,
    Cleave = SPELLS.Cleave,
    DeathWish = SPELLS.DeathWish,
    DefensiveStance = SPELLS.DefensiveStance,
    DemoralizingShout = SPELLS.DemoralizingShout,
    Execute = SPELLS.Execute,
    Hamstring = SPELLS.Hamstring,
    HeroicStrike = SPELLS.HeroicStrike,
    Intercept = SPELLS.Intercept,
    Overpower = SPELLS.Overpower,
    Pummel = SPELLS.Pummel,
    Recklessness = SPELLS.Recklessness,
    Rend = SPELLS.Rend,
    Slam = SPELLS.Slam,
    SunderArmor = SPELLS.SunderArmor,
    SweepingStrikes = SPELLS.SweepingStrikes,
    ThunderClap = SPELLS.ThunderClap,
    Whirlwind = SPELLS.Whirlwind,
}

-- Buff/debuff ID tables (Classic rank sets)
local BATTLE_SHOUT_BUFF = CONSTANTS.BATTLE_SHOUT_IDS or { 11551, 11550, 11549, 6192, 5242, 6673 }
local BERSERKER_RAGE_BUFF = { 18499 }
local SWEEPING_STRIKES_BUFF = { 12292 }  -- Vanilla ID (TBC=12328; different ID per expansion)
local SUNDER_DEBUFF = { 11597, 11596, 8380, 7405, 7386 }
local REND_DEBUFF = { 11574, 11573, 6548, 6547, 772 }
local DEMO_SHOUT_DEBUFF = { 11556, 11555, 11554, 6190, 1160 }
local THUNDER_CLAP_DEBUFF = { 11581, 11580, 8205, 8204, 8198, 6343 }
local HAMSTRING_DEBUFF = { 7373, 7372, 1715 }

-- Constants
local EXECUTE_DEFAULT_RAGE = 25
local WHIRLWIND_RESERVE = 25
local CORE_POOL_WINDOW = 2.0
local SLAM_RAGE_COST = 15
local SLAM_CAST_TIME = 1.5  -- Classic Slam cast time
local SLAM_SAFETY = 0.2

-- State table (pre-allocated for hot-path reuse)
local fury_state = {
    rage = 0,
    hp = 100,
    target_hp = 100,
    in_melee_range = false,
    has_valid_enemy = false,
    bw_ready = false,
    berserker_rage_ready = false,
    bloodrage_ready = false,
    charge_ready = false,
    death_wish_ready = false,
    demo_ready = false,
    execute_ready = false,
    hamstring_ready = false,
    heroic_strike_ready = false,
    intercept_ready = false,
    overpower_ready = false,
    pummel_ready = false,
    recklessness_ready = false,
    rend_ready = false,
    slam_ready = false,
    sunder_ready = false,
    sweeping_strikes_ready = false,
    tclap_ready = false,
    whirlwind_ready = false,
    has_battle_shout = false,
    has_demo_shout = false,
    has_rend = false,
    has_sunder = false,
    has_tclap = false,
    has_hamstring = false,
    overpower_window = false,
    target_ttd = 15,
    target_count = 1,
}

local function spell_ready(spell, target, opts)
    if NS.spell_ready then return NS.spell_ready(spell, target, opts) or false end
    return false
end
local function action_ready(context, action)
    if NS.action_ready then return NS.action_ready(context, action) or false end
    return false
end
local function try_cast(spell, target, label, opts)
    if NS.try_cast then return NS.try_cast(spell, target, label, opts) or false end
    return false
end

-- State builder
local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target
    fury_state.rage = context.rage or 0
    fury_state.hp = context.hp or 100
    fury_state.target_hp = context.target_hp or 100
    fury_state.has_valid_enemy = context.has_valid_enemy_target or false
    fury_state.in_melee_range = context.in_melee_range or false
    fury_state.target_count = context.enemies_count or 1
    fury_state.target_ttd = (context.ttd or 15)
    if me then
        fury_state.has_battle_shout = NS.buff_up(me, BATTLE_SHOUT_BUFF) or false
    end
    if target then
        fury_state.has_demo_shout = NS.debuff_up(target, DEMO_SHOUT_DEBUFF) or false
        fury_state.has_rend = NS.debuff_up(target, REND_DEBUFF) or false
        fury_state.has_sunder = NS.debuff_up(target, SUNDER_DEBUFF) or false
        fury_state.has_tclap = NS.debuff_up(target, THUNDER_CLAP_DEBUFF) or false
        fury_state.has_hamstring = NS.debuff_up(target, HAMSTRING_DEBUFF) or false
        local dodge_fn = target.get_dodge_chance
        local ok_dodge, dodge_val = false, 0
        if dodge_fn then ok_dodge, dodge_val = pcall(dodge_fn, target) end
        if not ok_dodge then dodge_val = 0 end
        fury_state.overpower_window = dodge_val > 0
    end
    fury_state.bw_ready = spell_ready(ACTION.BerserkerRage, me, { skip_range = true })
    fury_state.bloodrage_ready = spell_ready(ACTION.Bloodrage, me, { skip_range = true })
    fury_state.charge_ready = target and spell_ready(ACTION.Charge, target)
    fury_state.death_wish_ready = spell_ready(ACTION.DeathWish, me, { skip_range = true })
    fury_state.demo_ready = spell_ready(ACTION.DemoralizingShout, me, { skip_range = true })
    fury_state.execute_ready = target and spell_ready(ACTION.Execute, target)
    fury_state.hamstring_ready = target and spell_ready(ACTION.Hamstring, target)
    fury_state.heroic_strike_ready = target and spell_ready(ACTION.HeroicStrike, target)
    fury_state.intercept_ready = target and spell_ready(ACTION.Intercept, target)
    fury_state.overpower_ready = target and spell_ready(ACTION.Overpower, target)
    fury_state.pummel_ready = target and spell_ready(ACTION.Pummel, target)
    fury_state.recklessness_ready = spell_ready(ACTION.Recklessness, me, { skip_range = true })
    fury_state.rend_ready = target and spell_ready(ACTION.Rend, target)
    fury_state.slam_ready = target and spell_ready(ACTION.Slam, target)
    fury_state.sunder_ready = target and spell_ready(ACTION.SunderArmor, target)
    fury_state.sweeping_strikes_ready = spell_ready(ACTION.SweepingStrikes, me, { skip_range = true })
    fury_state.tclap_ready = target and spell_ready(ACTION.ThunderClap, target)
    fury_state.whirlwind_ready = target and spell_ready(ACTION.Whirlwind, target)
    fury_state.cleave_ready = target and spell_ready(ACTION.Cleave, target)
    return fury_state
end

-- Classic Fury Strategy table
local strategies = {}

-- Auto-potions (context-based, O(1) gate)
table.insert(strategies, { name = "HealthPotion",
    matches = function(c)
        if not c.in_combat then return false end
        if c.settings and c.settings.use_auto_potions == false then return false end
        if not c.has_health_potion then return false end
        if (c.hp or 100) > 35 then return false end
        return true
    end,
    execute = function(c) return potion_helper.try_use_potion(c, potion_helper.HEALTH_POTION_IDS) end
})
table.insert(strategies, { name = "DamagePotion",
    matches = function(c)
        if not c.in_combat then return false end
        if c.settings and c.settings.use_auto_potions == false then return false end
        if not c.has_damage_potion then return false end
        if not c.should_burst then return false end
        return true
    end,
    execute = function(c) return potion_helper.try_use_potion(c, potion_helper.DAMAGE_POTION_IDS) end
})

-- 1. Defensive: Berserker Rage
if ACTION.BerserkerRage then
    table.insert(strategies, { name = "BerserkerRage",
        matches = function(c, s) return s.bw_ready end,
        execute = function() return try_cast(ACTION.BerserkerRage, PLAYER_UNIT, "[VANILLA FURY] Berserker Rage", { skip_range = true }) end
    })
end

-- 2. Mobility: Intercept
if ACTION.Intercept then
    table.insert(strategies, { name = "Intercept",
        matches = function(c, s) return s.intercept_ready and not s.in_melee_range end,
        execute = function(c) return try_cast(ACTION.Intercept, c.target, "[VANILLA FURY] Intercept") end
    })
end

-- 3. Burst: Death Wish
if ACTION.DeathWish then
    table.insert(strategies, { name = "DeathWish",
        matches = function(c, s) return s.death_wish_ready and s.has_valid_enemy end,
        execute = function() return try_cast(ACTION.DeathWish, PLAYER_UNIT, "[VANILLA FURY] Death Wish", { skip_range = true }) end
    })
end

-- 4. Execute phase (target below 20%)
if ACTION.Execute then
    table.insert(strategies, { name = "Execute",
        matches = function(c, s)
            return s.execute_ready and (s.target_hp or 100) <= 20 and (s.rage or 0) >= EXECUTE_DEFAULT_RAGE
        end,
        execute = function(c) return try_cast(ACTION.Execute, c.target, "[VANILLA FURY] Execute") end
    })
end

-- 5. Sweeping Strikes cooldown
if ACTION.SweepingStrikes then
    table.insert(strategies, { name = "SweepingStrikes",
        matches = function(c, s) return s.sweeping_strikes_ready and (s.target_count or 0) >= 2 end,
        execute = function() return try_cast(ACTION.SweepingStrikes, PLAYER_UNIT, "[VANILLA FURY] Sweeping Strikes", { skip_range = true }) end
    })
end

-- 6. Overpower after dodge/parry
if ACTION.Overpower then
    table.insert(strategies, { name = "Overpower",
        matches = function(c, s) return s.overpower_ready and s.overpower_window end,
        execute = function(c) return try_cast(ACTION.Overpower, c.target, "[VANILLA FURY] Overpower") end
    })
end

-- 7. Whirlwind (main cooldown, no Bloodthirst in Classic)
if ACTION.Whirlwind then
    table.insert(strategies, { name = "Whirlwind",
        matches = function(c, s)
            return s.whirlwind_ready and (s.rage or 0) >= WHIRLWIND_RESERVE
        end,
        execute = function(c) return try_cast(ACTION.Whirlwind, c.target, "[VANILLA FURY] Whirlwind") end
    })
end

-- 8. Rend maintenance
if ACTION.Rend then
    table.insert(strategies, { name = "Rend",
        matches = function(c, s)
            return s.rend_ready and not s.has_rend and (s.target_ttd or 0) > 12
        end,
        execute = function(c) return try_cast(ACTION.Rend, c.target, "[VANILLA FURY] Rend") end
    })
end

-- 9. Demoralizing Shout
if ACTION.DemoralizingShout then
    table.insert(strategies, { name = "DemoralizingShout",
        matches = function(c, s) return s.demo_ready and not s.has_demo_shout end,
        execute = function(c) return try_cast(ACTION.DemoralizingShout, c.me, "[VANILLA FURY] Demo Shout", { skip_range = true }) end
    })
end

-- 10. Sunder Armor
if ACTION.SunderArmor then
    table.insert(strategies, { name = "SunderArmor",
        matches = function(c, s) return s.sunder_ready and not s.has_sunder and (c.target_armor or 0) > 0 end,
        execute = function(c) return try_cast(ACTION.SunderArmor, c.target, "[VANILLA FURY] Sunder") end
    })
end

-- 11. Hamstring (snare)
if ACTION.Hamstring then
    table.insert(strategies, { name = "Hamstring",
        matches = function(c, s) return s.hamstring_ready and not s.has_hamstring end,
        execute = function(c) return try_cast(ACTION.Hamstring, c.target, "[VANILLA FURY] Hamstring") end
    })
end

-- 12. Slam filler (Classic 1.5s cast)
if ACTION.Slam then
    table.insert(strategies, { name = "Slam",
        matches = function(c, s)
            return s.slam_ready and (s.rage or 0) >= SLAM_RAGE_COST
        end,
        execute = function(c) return try_cast(ACTION.Slam, c.target, "[VANILLA FURY] Slam") end
    })
end

-- 13. Heroic Strike (rage dump)
if ACTION.HeroicStrike then
    table.insert(strategies, { name = "HeroicStrike",
        matches = function(c, s)
            return s.heroic_strike_ready and (s.rage or 0) >= 60
        end,
        execute = function(c) return try_cast(ACTION.HeroicStrike, c.target, "[VANILLA FURY] Heroic Strike") end
    })
end

-- 14. Cleave (multi-target rage dump)
if ACTION.Cleave then
    table.insert(strategies, { name = "Cleave",
        matches = function(c, s)
            return (s.target_count or 0) >= 2 and s.cleave_ready and (s.rage or 0) >= 40
        end,
        execute = function(c) return try_cast(ACTION.Cleave, c.target, "[VANILLA FURY] Cleave") end
    })
end

NS.rotation_registry:register("fury", strategies, { get_state = build_state })
-- [VANILLA] Warrior Fury rotation registered
return strategies
