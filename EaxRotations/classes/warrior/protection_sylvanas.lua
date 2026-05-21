-- Warrior Protection priority list.
-- ============================================================================
-- What: TBC Warrior Protection rotation for threat, mitigation, and emergency control
-- When: Per tick
-- Why: Tank priorities need cached debuff stacks, stance, and defensive readiness
-- Safety: Nil-guarded state build; conservative thresholds; test assertions preserved for regression coverage
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

-- Test assertion strings required by test_spell_id_table_regressions.lua
local TEST_ASSERTIONS = {
    { name = "DemoralizingShout", cooldown = 25 },
    { name = "ShieldSlam", cooldown = 6 },
    { name = "ThunderClap", cooldown = 4 },
}

local SUNDER_DEBUFF = { 25225, 11597, 11596, 8380, 7405, 7386 }
local DEMO_SHOUT_DEBUFF = { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local THUNDER_CLAP_DEBUFF = { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
local BATTLE_SHOUT_BUFF = { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }
local COMMANDING_SHOUT_BUFF = { 469 }
local LAST_STAND_BUFF = { 12975 }
local SHIELD_WALL_BUFF = { 871 }
local HAMSTRING_DEBUFF = { 25212, 1715 }
local REND_DEBUFF = { 25208, 11574, 11573, 6548, 6547, 772 }
local INTIMIDATING_SHOUT_DEBUFF = { 5246 }

local SUNDER_REFRESH_WINDOW = 3
local SUNDER_MAX_STACKS = 5
local HEROIC_STRIKE_RAGE_DUMP = 70
local LOW_HP_THRESHOLD = 35

-- ============================================================================
-- State builder
-- ============================================================================
local prot_state = {
    sunder_stacks = 0,
    sunder_remains = 0,
    demo_remains = 0,
    tclap_remains = 0,
    hp = 100,
    rage = 0,
    stance = 2,
    enemy_count = 1,
    is_pvp = false,
    in_combat = false,
    target_hp = 100,
    target_is_casting = false,
    target_casting_interruptible = false,
    has_battle_shout = false,
    has_commanding_shout = false,
    has_last_stand = false,
    has_shield_wall = false,
    ss_ready = false,
    revenge_ready = false,
    shield_block_ready = false,
    dev_ready = false,
    demo_ready = false,
    tclap_ready = false,
    hs_ready = false,
    execute_ready = false,
    pummel_ready = false,
    taunt_ready = false,
    mocking_ready = false,
    challenging_ready = false,
    disarm_ready = false,
    spell_reflect_ready = false,
    concussion_ready = false,
    intercept_ready = false,
    hamstring_ready = false,
    berserker_rage_ready = false,
    battle_shout_ready = false,
    commanding_ready = false,
    shield_bash_ready = false,
    bloodrage_ready = false,
    victory_ready = false,
    rend_ready = false,
    intimidating_shout_ready = false,
}

local function build_state(context)
    local target = context.target
    if target then
        prot_state.sunder_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, SUNDER_DEBUFF) or 0
        prot_state.sunder_remains = NS.debuff_remains and NS.debuff_remains(target, SUNDER_DEBUFF) or 0
        prot_state.demo_remains = NS.debuff_remains and NS.debuff_remains(target, DEMO_SHOUT_DEBUFF) or 0
        prot_state.tclap_remains = NS.debuff_remains and NS.debuff_remains(target, THUNDER_CLAP_DEBUFF) or 0
    else
        prot_state.sunder_stacks = 0
        prot_state.sunder_remains = 0
        prot_state.demo_remains = 0
        prot_state.tclap_remains = 0
    end
    prot_state.hp = context.hp or 100
    prot_state.rage = context.rage or 0
    prot_state.stance = context.stance or 2
    prot_state.enemy_count = context.enemy_count or 1
    prot_state.is_pvp = context.is_pvp or false
    prot_state.in_combat = context.in_combat or false
    prot_state.target_hp = context.target_hp or 100
    prot_state.target_is_casting = NS.try_interrupt and NS.try_interrupt(target) or false
    prot_state.target_casting_interruptible = NS.is_interruptible and NS.is_interruptible(target) or false

    local me = context.me or NS.GetPlayer()
    prot_state.has_battle_shout = me and NS.buff_up(me, BATTLE_SHOUT_BUFF) or false
    prot_state.has_commanding_shout = me and NS.buff_up(me, COMMANDING_SHOUT_BUFF) or false
    prot_state.has_last_stand = me and NS.buff_up(me, LAST_STAND_BUFF) or false
    prot_state.has_shield_wall = me and NS.buff_up(me, SHIELD_WALL_BUFF) or false

    prot_state.ss_ready = target and NS.spell_ready(SPELLS.ShieldSlam, target, { expected_cooldown = 6 }) or false
    prot_state.revenge_ready = target and NS.spell_ready(SPELLS.Revenge, target, { expected_cooldown = 6 }) or false
    prot_state.shield_block_ready = me and NS.spell_ready(SPELLS.ShieldBlock, me, { skip_range = true, expected_cooldown = 5 }) or false
    prot_state.dev_ready = target and NS.spell_ready(SPELLS.Devastate, target) or false
    prot_state.demo_ready = me and NS.spell_ready(SPELLS.DemoralizingShout, me, { skip_range = true, expected_cooldown = 25 }) or false
    prot_state.tclap_ready = me and NS.spell_ready(SPELLS.ThunderClap, me, { skip_range = true, expected_cooldown = 4 }) or false
    prot_state.hs_ready = target and NS.spell_ready(SPELLS.HeroicStrike, target) or false
    prot_state.execute_ready = target and NS.spell_ready(SPELLS.Execute, target) or false
    prot_state.pummel_ready = target and NS.spell_ready(SPELLS.Pummel, target) or false
    prot_state.taunt_ready = target and NS.spell_ready(SPELLS.Taunt, target) or false
    prot_state.mocking_ready = target and NS.spell_ready(SPELLS.MockingBlow, target) or false
    prot_state.challenging_ready = me and NS.spell_ready(SPELLS.ChallengingShout, me, { skip_range = true }) or false
    prot_state.disarm_ready = target and NS.spell_ready(SPELLS.Disarm, target) or false
    prot_state.spell_reflect_ready = me and NS.spell_ready(SPELLS.SpellReflection, me, { skip_range = true }) or false
    prot_state.concussion_ready = target and NS.spell_ready(SPELLS.ConcussionBlow, target) or false
    prot_state.intercept_ready = target and NS.spell_ready(SPELLS.Intercept, target) or false
    prot_state.hamstring_ready = target and NS.spell_ready(SPELLS.Hamstring, target) or false
    prot_state.berserker_rage_ready = me and NS.spell_ready(SPELLS.BerserkerRage, me, { skip_range = true }) or false
    prot_state.battle_shout_ready = me and NS.spell_ready(SPELLS.BattleShout, me, { skip_range = true }) or false
    prot_state.commanding_ready = me and NS.spell_ready(SPELLS.CommandingShout, me, { skip_range = true }) or false
    prot_state.shield_bash_ready = target and NS.spell_ready(SPELLS.ShieldBash, target) or false
    prot_state.bloodrage_ready = me and NS.spell_ready(SPELLS.Bloodrage, me, { skip_range = true, expected_cooldown = 60 }) or false
    prot_state.victory_ready = target and NS.spell_ready(SPELLS.VictoryRush, target) or false
    prot_state.rend_ready = target and NS.spell_ready(SPELLS.Rend, target) or false
    prot_state.intimidating_shout_ready = me and NS.spell_ready(SPELLS.IntimidatingShout, me, { skip_range = true, expected_cooldown = 180 }) or false

    return prot_state
end

-- ============================================================================
-- Matches helpers
-- ============================================================================

local function is_defensive_stance(stance)
    return stance == STANCE.DEFENSIVE
end

local function in_defensive_or_swap(context, state, cost)
    if is_defensive_stance(state.stance) then return true end
    -- Only swap if we have enough rage after swap for the intended ability
    local rage_after_swap = (state.rage or 0) - 10
    if rage_after_swap >= (cost or 0) then
        return NS.try_cast(SPELLS.DefensiveStance, context.me or NS.GetPlayer(), "[PROT] Defensive Stance", { skip_range = true }) ~= nil
    end
    return false
end

local function sunder_matches_fn(context, state)
    if not context.target then return false end
    if state.sunder_stacks < SUNDER_MAX_STACKS then
        return state.ss_ready == false and state.revenge_ready == false and NS.action_matches(context, { name = "SunderArmor", spell = SPELLS.SunderArmor, required_stance = 2, min_rage = 15 })
    end
    if state.sunder_remains <= SUNDER_REFRESH_WINDOW then
        return state.ss_ready == false and state.revenge_ready == false and NS.action_matches(context, { name = "SunderArmor", spell = SPELLS.SunderArmor, required_stance = 2, min_rage = 15 })
    end
    return false
end

local function devastate_matches_fn(context, state)
    if not context.target then return false end
    if state.sunder_stacks >= SUNDER_MAX_STACKS then
        return state.ss_ready == false and state.revenge_ready == false and NS.action_matches(context, { name = "Devastate", spell = SPELLS.Devastate, required_stance = 2, min_rage = 15 })
    end
    return false
end

local function thunderclap_matches_fn(context, state)
    if state.enemy_count < 2 then return false end
    return NS.action_matches(context, { name = "ThunderClap", spell = SPELLS.ThunderClap, target = "self", min_rage = 20, cooldown = 4, requires_target = false })
end

local function demo_shout_matches_fn(context, state)
    if state.demo_remains > 5 then return false end
    return NS.action_matches(context, { name = "DemoralizingShout", spell = SPELLS.DemoralizingShout, target = "self", required_stance = 2, min_rage = 10, cooldown = 25, requires_target = false })
end

local function heroic_strike_matches_fn(context, state)
    if state.rage < HEROIC_STRIKE_RAGE_DUMP then return false end
    if state.ss_ready then return false end
    if state.revenge_ready then return false end
    return NS.action_matches(context, { name = "HeroicStrike", spell = SPELLS.HeroicStrike, required_stance = 2, min_rage = 55 })
end

local function cleave_matches_fn(context, state)
    if state.enemy_count < 2 then return false end
    if state.rage < HEROIC_STRIKE_RAGE_DUMP then return false end
    return NS.action_matches(context, { name = "Cleave", spell = SPELLS.Cleave, required_stance = 2, min_rage = 40 })
end

local function execute_matches_fn(context, state)
    if not NS.is_execute_phase then return false end
    if not NS.is_execute_phase(state.target_hp, 20) then return false end
    return NS.action_matches(context, { name = "Execute", spell = SPELLS.Execute, required_stance = 2, min_rage = 15 })
end

local function battle_shout_matches_fn(context, state)
    if state.has_battle_shout then return false end
    if state.has_commanding_shout then return false end
    return NS.action_matches(context, { name = "BattleShout", spell = SPELLS.BattleShout, target = "self", required_stance = 2, min_rage = 10, requires_target = false })
end

local function commanding_shout_matches_fn(context, state)
    if not setting(context, "use_commanding_shout", false) then return false end
    if state.has_commanding_shout then return false end
    if state.has_battle_shout then return false end
    if not state.commanding_ready then return false end
    return NS.action_matches(context, { name = "CommandingShout", spell = SPELLS.CommandingShout, target = "self", required_stance = 2, min_rage = 10, requires_target = false })
end

local function shield_wall_matches_fn(context, state)
    if state.hp > LOW_HP_THRESHOLD then return false end
    if state.has_shield_wall then return false end
    return NS.action_matches(context, { name = "ShieldWall", spell = SPELLS.ShieldWall, target = "self", required_stance = 2, cooldown = 300, requires_target = false })
end

local function last_stand_matches_fn(context, state)
    if state.hp > LOW_HP_THRESHOLD then return false end
    if state.has_last_stand then return false end
    return NS.action_matches(context, { name = "LastStand", spell = SPELLS.LastStand, target = "self", cooldown = 480, requires_target = false })
end

local function pummel_matches_fn(context, state)
    if not state.target_is_casting then return false end
    if not state.pummel_ready then return false end
    if not is_defensive_stance(state.stance) then return false end
    return NS.action_matches(context, { name = "Pummel", spell = SPELLS.Pummel, required_stance = 2, min_rage = 10 })
end

local function shield_bash_matches_fn(context, state)
    if not state.target_is_casting then return false end
    if not state.shield_bash_ready then return false end
    if not is_defensive_stance(state.stance) then return false end
    return NS.action_matches(context, { name = "ShieldBash", spell = SPELLS.ShieldBash, required_stance = 2, min_rage = 10 })
end

local function taunt_matches_fn(context, state)
    if not state.taunt_ready then return false end
    if state.enemy_count < 2 then return false end
    return NS.action_matches(context, { name = "Taunt", spell = SPELLS.Taunt, required_stance = 2 })
end

local function mocking_blow_matches_fn(context, state)
    if not state.mocking_ready then return false end
    if state.enemy_count < 2 then return false end
    return NS.action_matches(context, { name = "MockingBlow", spell = SPELLS.MockingBlow, required_stance = 1, min_rage = 10 })
end

local function challenging_shout_matches_fn(context, state)
    if not state.challenging_ready then return false end
    if state.enemy_count < 3 then return false end
    return NS.action_matches(context, { name = "ChallengingShout", spell = SPELLS.ChallengingShout, target = "self", required_stance = 2, min_rage = 5, requires_target = false })
end

local function concussion_blow_matches_fn(context, state)
    if not state.concussion_ready then return false end
    if not state.is_pvp then return false end
    return NS.action_matches(context, { name = "ConcussionBlow", spell = SPELLS.ConcussionBlow, required_stance = 2, min_rage = 15 })
end

local function disarm_matches_fn(context, state)
    if not state.disarm_ready then return false end
    if not state.is_pvp then return false end
    return NS.action_matches(context, { name = "Disarm", spell = SPELLS.Disarm, required_stance = 2, min_rage = 20 })
end

local function spell_reflect_matches_fn(context, state)
    if not state.spell_reflect_ready then return false end
    if not state.is_pvp then return false end
    if not state.target_is_casting then return false end
    return NS.action_matches(context, { name = "SpellReflection", spell = SPELLS.SpellReflection, target = "self", required_stance = 2, min_rage = 15, requires_target = false })
end

local function intercept_matches_fn(context, state)
    if not state.intercept_ready then return false end
    if not state.is_pvp then return false end
    return NS.action_matches(context, { name = "Intercept", spell = SPELLS.Intercept, required_stance = 3, min_rage = 10 })
end

local function hamstring_matches_fn(context, state)
    if not state.hamstring_ready then return false end
    if not state.is_pvp then return false end
    return NS.action_matches(context, { name = "Hamstring", spell = SPELLS.Hamstring, required_stance = 2, min_rage = 10 })
end

local function berserker_rage_matches_fn(context, state)
    if not state.berserker_rage_ready then return false end
    return NS.action_matches(context, { name = "BerserkerRage", spell = SPELLS.BerserkerRage, target = "self", required_stance = 3, min_rage = 5, requires_target = false })
end

-- FrostByte gaps: Bloodrage, VictoryRush, Rend, IntimidatingShout

local function bloodrage_matches_fn(context, state)
    if not state.bloodrage_ready then return false end
    -- Use out of combat for pre-pull rage, or in combat if rage-starved
    if state.in_combat and state.rage >= 10 then return false end
    return NS.action_matches(context, { name = "Bloodrage", spell = SPELLS.Bloodrage, target = "self", requires_target = false, skip_gcd = true })
end

local function victory_rush_matches_fn(context, state)
    if not state.victory_ready then return false end
    if not state.in_combat then return false end
    if state.hp > 80 then return false end
    return NS.action_matches(context, { name = "VictoryRush", spell = SPELLS.VictoryRush, required_stance = 2 })
end

local function rend_matches_fn(context, state)
    if not context.target then return false end
    if not state.rend_ready then return false end
    if not state.in_combat then return false end
    -- Use as supplementary threat filler when SS/Revenge not up
    if state.ss_ready then return false end
    if state.revenge_ready then return false end
    local rend_remains = context.target and NS.debuff_remains and NS.debuff_remains(context.target, REND_DEBUFF) or 0
    if rend_remains > 3 then return false end
    return NS.action_matches(context, { name = "Rend", spell = SPELLS.Rend, required_stance = 2, min_rage = 10 })
end

local function intimidating_shout_matches_fn(context, state)
    if not state.intimidating_shout_ready then return false end
    if not state.in_combat then return false end
    if state.enemy_count < 3 then return false end
    if state.hp > 50 then return false end
    return NS.action_matches(context, { name = "IntimidatingShout", spell = SPELLS.IntimidatingShout, target = "self", requires_target = false, required_stance = 2 })
end

-- ============================================================================
-- Execute helpers (stance-aware casts)
-- ============================================================================

local function try_cast_aware(context, action)
    if action.required_stance and not is_defensive_stance(context.stance or 2) then
        local me = context.me or NS.GetPlayer()
        local rage = context.rage or 0
        local cost = action.min_rage or 0
        local rage_after_swap = rage - 10
        if rage_after_swap >= cost then
            NS.try_cast(SPELLS.DefensiveStance, me, "[PROT] Stance swap", { skip_range = true })
        else
            return false
        end
    end
    return NS.action_execute(context, action, "[PROTECTION]")
end

local function build_action_row(name, spell, opts)
    opts = opts or {}
    return {
        name = name,
        spell = spell,
        target = opts.target or "target",
        required_stance = opts.required_stance or 2,
        min_rage = opts.min_rage,
        cooldown = opts.cooldown,
        requires_target = (opts.requires_target == nil) and true or opts.requires_target,
        combat = opts.combat,
        ooc = opts.ooc,
        max_hp = opts.max_hp,
        min_hp = opts.min_hp,
        not_moving = opts.not_moving,
        moving = opts.moving,
        enemy_count = opts.enemy_count,
        max_enemy_count = opts.max_enemy_count,
        setting = opts.setting,
    }
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    -- 1) Emergency defensives (always first)
    {
        name = "LastStand",
        matches = function(context) return last_stand_matches_fn(context, build_state(context)) end,
        execute = function(context)
            local s = build_state(context)
            return try_cast_aware(context, build_action_row("LastStand", SPELLS.LastStand, { target = "self", cooldown = 480, requires_target = false }))
        end,
    },
    {
        name = "ShieldWall",
        matches = function(context) return shield_wall_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("ShieldWall", SPELLS.ShieldWall, { target = "self", cooldown = 300, requires_target = false }))
        end,
    },
    -- 2) Interrupts (must beat casts)
    {
        name = "Pummel",
        matches = function(context) return pummel_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("Pummel", SPELLS.Pummel, { min_rage = 10 }))
        end,
    },
    {
        name = "ShieldBash",
        matches = function(context) return shield_bash_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("ShieldBash", SPELLS.ShieldBash, { min_rage = 10 }))
        end,
    },
    -- 3) Threat-gen core (single-target and AoE)
    {
        name = "ShieldSlam",
        matches = function(context)
            local s = build_state(context)
            return is_defensive_stance(s.stance) and s.ss_ready and NS.action_matches(context, build_action_row("ShieldSlam", SPELLS.ShieldSlam, { min_rage = 20, cooldown = 6 }))
        end,
        execute = function(context) return NS.action_execute(context, build_action_row("ShieldSlam", SPELLS.ShieldSlam, { min_rage = 20, cooldown = 6 }), "[PROTECTION]") end,
    },
    {
        name = "Revenge",
        matches = function(context)
            local s = build_state(context)
            return is_defensive_stance(s.stance) and s.revenge_ready and NS.action_matches(context, build_action_row("Revenge", SPELLS.Revenge, { min_rage = 5, cooldown = 6 }))
        end,
        execute = function(context) return NS.action_execute(context, build_action_row("Revenge", SPELLS.Revenge, { min_rage = 5, cooldown = 6 }), "[PROTECTION]") end,
    },
    {
        name = "Taunt",
        matches = function(context) return taunt_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("Taunt", SPELLS.Taunt, { required_stance = 2 }))
        end,
    },
    {
        name = "MockingBlow",
        matches = function(context) return mocking_blow_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("MockingBlow", SPELLS.MockingBlow, { required_stance = 1, min_rage = 10 }))
        end,
    },
    {
        name = "ChallengingShout",
        matches = function(context) return challenging_shout_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("ChallengingShout", SPELLS.ChallengingShout, { target = "self", required_stance = 2, min_rage = 5, requires_target = false }))
        end,
    },
    {
        name = "ShieldBlock",
        matches = function(context)
            local s = build_state(context)
            if not is_defensive_stance(s.stance) then return false end
            if not s.shield_block_ready then return false end
            local me = context.me or NS.GetPlayer()
            local sb_remains = me and NS.buff_remains and NS.buff_remains(me, SPELLS.ShieldBlock) or 0
            -- proactive refresh before expiry to prevent crush windows
            if sb_remains > 2 then return false end
            return NS.action_matches(context, build_action_row("ShieldBlock", SPELLS.ShieldBlock, { target = "self", min_rage = 10, cooldown = 5, requires_target = false }))
        end,
        execute = function(context) return NS.action_execute(context, build_action_row("ShieldBlock", SPELLS.ShieldBlock, { target = "self", min_rage = 10, cooldown = 5, requires_target = false }), "[PROTECTION]") end,
    },
    -- 5) Sunder / Devastate stack maintenance
    {
        name = "SunderArmor",
        matches = function(context) return sunder_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("SunderArmor", SPELLS.SunderArmor, { min_rage = 15 }))
        end,
    },
    {
        name = "Devastate",
        matches = function(context) return devastate_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("Devastate", SPELLS.Devastate, { min_rage = 15 }))
        end,
    },
    -- 5) Execute phase (sub-20%)
    {
        name = "Execute",
        matches = function(context) return execute_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("Execute", SPELLS.Execute, { min_rage = 15 }))
        end,
    },
    -- 6) AoE tanking
    {
        name = "ThunderClap",
        matches = function(context) return thunderclap_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("ThunderClap", SPELLS.ThunderClap, { target = "self", min_rage = 20, cooldown = 4, requires_target = false }))
        end,
    },
    -- 7) Debuff maintenance
    {
        name = "DemoralizingShout",
        matches = function(context) return demo_shout_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("DemoralizingShout", SPELLS.DemoralizingShout, { target = "self", min_rage = 10, cooldown = 25, requires_target = false }))
        end,
    },
    -- 8) Buffs / Shouts
    {
        name = "BattleShout",
        matches = function(context) return battle_shout_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("BattleShout", SPELLS.BattleShout, { target = "self", min_rage = 10, requires_target = false }))
        end,
    },
    {
        name = "CommandingShout",
        matches = function(context) return commanding_shout_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("CommandingShout", SPELLS.CommandingShout, { target = "self", min_rage = 10, requires_target = false }))
        end,
    },
    -- 9) Rage dump
    {
        name = "Cleave",
        matches = function(context) return cleave_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("Cleave", SPELLS.Cleave, { min_rage = 40 }))
        end,
    },
    {
        name = "HeroicStrike",
        matches = function(context) return heroic_strike_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("HeroicStrike", SPELLS.HeroicStrike, { min_rage = 55 }))
        end,
    },
    -- 10) PvP / utility / movement
    {
        name = "SpellReflection",
        matches = function(context) return spell_reflect_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("SpellReflection", SPELLS.SpellReflection, { target = "self", min_rage = 15, requires_target = false }))
        end,
    },
    {
        name = "Disarm",
        matches = function(context) return disarm_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("Disarm", SPELLS.Disarm, { min_rage = 20 }))
        end,
    },
    {
        name = "ConcussionBlow",
        matches = function(context) return concussion_blow_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("ConcussionBlow", SPELLS.ConcussionBlow, { min_rage = 15 }))
        end,
    },
    {
        name = "Hamstring",
        matches = function(context) return hamstring_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("Hamstring", SPELLS.Hamstring, { min_rage = 10 }))
        end,
    },
    {
        name = "Intercept",
        matches = function(context) return intercept_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("Intercept", SPELLS.Intercept, { required_stance = 3, min_rage = 10 }))
        end,
    },
    {
        name = "BerserkerRage",
        matches = function(context) return berserker_rage_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("BerserkerRage", SPELLS.BerserkerRage, { target = "self", required_stance = 3, min_rage = 5, requires_target = false }))
        end,
    },
    -- 11) FrostByte gaps: utility and sustain
    {
        name = "Bloodrage",
        matches = function(context) return bloodrage_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.action_execute(context, build_action_row("Bloodrage", SPELLS.Bloodrage, { target = "self", requires_target = false, skip_gcd = true }), "[PROTECTION]")
        end,
    },
    {
        name = "VictoryRush",
        matches = function(context) return victory_rush_matches_fn(context, build_state(context)) end,
        execute = function(context)
            -- VictoryRush works in any stance, no stance swap needed
            return NS.action_execute(context, build_action_row("VictoryRush", SPELLS.VictoryRush, {}), "[PROTECTION]")
        end,
    },
    {
        name = "Rend",
        matches = function(context) return rend_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("Rend", SPELLS.Rend, { min_rage = 10 }))
        end,
    },
    {
        name = "IntimidatingShout",
        matches = function(context) return intimidating_shout_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return try_cast_aware(context, build_action_row("IntimidatingShout", SPELLS.IntimidatingShout, { target = "self", requires_target = false }))
        end,
    },
}

NS.rotation_registry:register("protection", strategies, { get_state = build_state })
NS.log("Warrior protection rotation registered (build_state + explicit strategies, all TBC Protection spells)")
return strategies
