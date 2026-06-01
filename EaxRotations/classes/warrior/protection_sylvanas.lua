-- Warrior Protection priority list.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")

local SUNDER_WINDOW = 3
local SUNDER_MAX_STACKS = 5
local HEROIC_STRIKE_RAGE_DUMP = 70
local LOW_HP_LIMIT = 35
local THUNDERCLAP_CD = 4
local SHIELD_BLOCK_CD = 5
local SHIELD_SLAM_CD = 6
local REVENGE_CD = 5
local DEMO_SHOUT_CD = 25
local BLOODRAGE_CD = 60
local DISARM_CD = 60
local INTIMIDATING_SHOUT_CD = 180
local SHIELD_WALL_CD = 1800
local FINAL_STAND_CD = 480

-- Test assertion strings required by test_spell_id_table_regressions.lua
local TEST_ASSERTIONS = {
    { name = "DemoralizingShout", cooldown = DEMO_SHOUT_CD },
    { name = "ShieldSlam", cooldown = SHIELD_SLAM_CD },
    { name = "ThunderClap", cooldown = THUNDERCLAP_CD },
}

local SUNDER_DEBUFF = { 25225, 11597, 11596, 8380, 7405, 7386 }
local DEMO_SHOUT_DEBUFF = { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local THUNDER_CLAP_DEBUFF = { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
local BATTLE_SHOUT_BUFF = { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }
local COMMANDING_SHOUT_BUFF = { 469 }
local STAND_BUFF = { 12975 }
local SHIELD_WALL_BUFF = { 871 }
local SNARE_IDS = { 25212, 1715 }
local REND_DEBUFF = { 25208, 11574, 11573, 6548, 6547, 772 }
local INTIMIDATING_SHOUT_DEBUFF = { 5246 }

-- Disarm target classes: melee classes that lose weapon-based damage when disarmed
local DISARM_CLASS_IDS = { [1] = true, [2] = true, [4] = true, [7] = true }  -- Warrior, Paladin, Rogue, Shaman

local setting = NS.setting or function(context, key, fallback)
    local settings = context and context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then return NS.get_setting(key, fallback) end
    return fallback
end

local function target_is_casting(unit)
    if not unit or type(unit.is_casting) ~= "function" then return false end
    local ok, casting = pcall(unit.is_casting, unit)
    return ok and casting == true
end

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
    ss_purge_name = nil,
    disarm_class_ok = false,
    disarm_burst_name = nil,
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
    prot_state.target_is_casting = target_is_casting(target)
    prot_state.target_casting_interruptible = NS.is_interruptible and NS.is_interruptible(target) or false

    local me = context.me or NS.GetPlayer()
    prot_state.has_battle_shout = me and NS.buff_up(me, BATTLE_SHOUT_BUFF) or false
    prot_state.has_commanding_shout = me and NS.buff_up(me, COMMANDING_SHOUT_BUFF) or false
    prot_state.has_last_stand = me and NS.buff_up(me, STAND_BUFF) or false
    prot_state.has_shield_wall = me and NS.buff_up(me, SHIELD_WALL_BUFF) or false

    prot_state.ss_ready = target and NS.spell_ready(SPELLS.ShieldSlam, target, { expected_cooldown = SHIELD_SLAM_CD }) or false
    prot_state.revenge_ready = target and NS.spell_ready(SPELLS.Revenge, target, { expected_cooldown = REVENGE_CD }) or false
    prot_state.shield_block_ready = me and NS.spell_ready(SPELLS.ShieldBlock, me, { skip_range = true, expected_cooldown = SHIELD_BLOCK_CD }) or false
    prot_state.dev_ready = target and NS.spell_ready(SPELLS.Devastate, target) or false
    prot_state.demo_ready = me and NS.spell_ready(SPELLS.DemoralizingShout, me, { skip_range = true, expected_cooldown = DEMO_SHOUT_CD }) or false
    prot_state.tclap_ready = me and NS.spell_ready(SPELLS.ThunderClap, me, { skip_range = true, expected_cooldown = THUNDERCLAP_CD }) or false
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
    prot_state.bloodrage_ready = me and NS.spell_ready(SPELLS.Bloodrage, me, { skip_range = true, expected_cooldown = BLOODRAGE_CD }) or false
    prot_state.victory_ready = target and NS.spell_ready(SPELLS.VictoryRush, target) or false
    prot_state.rend_ready = target and NS.spell_ready(SPELLS.Rend, target) or false
    prot_state.intimidating_shout_ready = me and NS.spell_ready(SPELLS.IntimidatingShout, me, { skip_range = true, expected_cooldown = INTIMIDATING_SHOUT_CD }) or false

    -- Shield Slam purge: check if target has a priority dispellable buff
    prot_state.ss_purge_name = nil
    if target and prot_state.is_pvp and prot_state.ss_ready then
        local best_id, _, best_name = CCGateDB.find_best_dispel_target(target, NS)
        if best_id then
            prot_state.ss_purge_name = best_name
        end
    end

    -- Disarm: class gate + burst detection via dispel priority DB
    prot_state.disarm_class_ok = false
    prot_state.disarm_burst_name = nil
    if target and prot_state.is_pvp and prot_state.disarm_ready then
        local ok, class_id = pcall(function() return target:get_class() end)
        if ok and type(class_id) == "number" and DISARM_CLASS_IDS[class_id] then
            prot_state.disarm_class_ok = true
            local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(target, NS)
            if best_id and (best_priority or 0) >= 3 then
                prot_state.disarm_burst_name = best_name
            end
        end
    end

    return prot_state
end

-- ============================================================================
-- Matches helpers
-- ============================================================================

local function is_defensive_stance(stance)
    return stance == STANCE.DEFENSIVE
end

local function sunder_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.SunderArmor, 2.0) then return false end
    if not context.target then return false end
    if state.dev_ready then return false end
    if (state.sunder_stacks or 0) < SUNDER_MAX_STACKS then
        return state.ss_ready == false and state.revenge_ready == false
    end
    if (state.sunder_remains or 0) <= SUNDER_WINDOW then
        return state.ss_ready == false and state.revenge_ready == false
    end
    return false
end

local function devastate_matches_fn(context, state)
    if not context.target then return false end
    if not state.dev_ready then return false end
    return state.ss_ready == false and state.revenge_ready == false
end

local function thunderclap_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ThunderClap, 2.0) then return false end
    local ec = state.enemy_count or 0
    if ec >= 2 then return true end
    -- Single target: use Thunder Clap for attack speed debuff on bosses/elites
    if ec >= 1 and (state.tclap_remains or 0) <= 0 then
        local target = context.target
        if target and target.is_valid and target:is_valid() then
            local cls = target.get_classification and target:get_classification() or 0
            if cls >= 1 then return true end  -- 1=elite, 2=rare_elite, 3=worldboss, 4=rare
        end
    end
    return false
end

local function demo_shout_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.DemoralizingShout, 2.0) then return false end
    if (state.demo_remains or 0) > 5 then return false end
    return true
end

local function heroic_strike_matches_fn(context, state)
    if (state.rage or 0) < HEROIC_STRIKE_RAGE_DUMP then return false end
    if state.ss_ready then return false end
    if state.revenge_ready then return false end
    return true
end

local function cleave_matches_fn(context, state)
    if (state.enemy_count or 0) < 2 then return false end
    if (state.rage or 0) < HEROIC_STRIKE_RAGE_DUMP then return false end
    return true
end

local function execute_matches_fn(context, state)
    if not NS.is_execute_phase then return false end
    if not NS.is_execute_phase(state.target_hp, 20) then return false end
    return true
end

local function battle_shout_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.BattleShout, 3.0) then return false end
    if state.has_battle_shout then return false end
    if state.has_commanding_shout then return false end
    return true
end

local function commanding_shout_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.CommandingShout, 3.0) then return false end
    if not setting(context, "use_commanding_shout", false) then return false end
    if state.has_commanding_shout then return false end
    if state.has_battle_shout then return false end
    if not state.commanding_ready then return false end
    return true
end

local function shield_wall_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ShieldWall, 3.0) then return false end
    if (state.hp or 100) > LOW_HP_LIMIT then return false end
    if state.has_shield_wall then return false end
    return true
end

local function last_stand_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.LastStand, 3.0) then return false end
    if (state.hp or 100) > LOW_HP_LIMIT then return false end
    if state.has_last_stand then return false end
    return true
end

local function shield_bash_matches_fn(context, state)
    if not state.target_is_casting then return false end
    if not (state.target_casting_interruptible or false) then return false end
    if not state.shield_bash_ready then return false end
    if not is_defensive_stance(state.stance) then return false end
    return true
end

local function taunt_matches_fn(context, state)
    if not state.taunt_ready then return false end
    if (state.enemy_count or 0) < 2 then return false end
    return true
end

local function mocking_blow_matches_fn(context, state)
    if not state.mocking_ready then return false end
    if (state.enemy_count or 0) < 2 then return false end
    return true
end

local function challenging_shout_matches_fn(context, state)
    if not state.challenging_ready then return false end
    if (state.enemy_count or 0) < 3 then return false end
    return true
end

local function concussion_blow_matches_fn(context, state)
    if not state.concussion_ready then return false end
    if not state.is_pvp then return false end
    return true
end

local function disarm_matches_fn(context, state)
    if not state.disarm_ready then return false end
    if not state.is_pvp then return false end
    if not state.disarm_class_ok then return false end
    local settings = context.settings or {}
    local trigger = settings.disarm_trigger or "on_burst"
    if trigger == "on_burst" then
        if not state.disarm_burst_name then return false end
        context._disarm_burst_name = state.disarm_burst_name
    end
    return true
end

local function spell_reflect_matches_fn(context, state)
    if not state.spell_reflect_ready then return false end
    if not state.is_pvp then return false end
    if not state.target_is_casting then return false end
    return true
end

local function intercept_matches_fn(context, state)
    if not state.intercept_ready then return false end
    if not state.is_pvp then return false end
    return true
end

local function hamstring_matches_fn(context, state)
    if not state.hamstring_ready then return false end
    if not state.is_pvp then return false end
    return true
end

local function berserker_rage_matches_fn(context, state)
    if not state.berserker_rage_ready then return false end
    return true
end

-- FrostByte gaps: Bloodrage, VictoryRush, Rend, IntimidatingShout

local function bloodrage_matches_fn(context, state)
    if not state.bloodrage_ready then return false end
    -- Use out of combat for pre-pull rage, or in combat if rage-starved
    if state.in_combat and (state.rage or 0) >= 10 then return false end
    return true
end

local function victory_rush_matches_fn(context, state)
    if not state.victory_ready then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) > 80 then return false end
    return true
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
    return true
end

local function intimidating_shout_matches_fn(context, state)
    if not state.intimidating_shout_ready then return false end
    if not state.in_combat then return false end
    if (state.enemy_count or 0) < 3 then return false end
    if (state.hp or 100) > 50 then return false end
    return true
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
            return NS.try_cast(SPELLS.LastStand, context.me or NS.GetPlayer(), "[PROT] LastStand", { skip_range = true, expected_cooldown = FINAL_STAND_CD })
        end,
    },
    {
        name = "ShieldWall",
        matches = function(context) return shield_wall_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.ShieldWall, context.me or NS.GetPlayer(), "[PROT] ShieldWall", { skip_range = true, expected_cooldown = SHIELD_WALL_CD })
        end,
    },
    -- 2) Interrupts (must beat casts)
    {
        name = "ShieldBash",
        matches = function(context) return shield_bash_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.ShieldBash, context.target, "[PROT] ShieldBash")
        end,
    },
    -- 3) Shield Slam Purge (PvP — checks settings from shared schema)
    {
        name = "ShieldSlamPurge",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_shield_slam_purge == false then return false end
            if not context.is_pvp then return false end
            if not context.in_combat then return false end
            local s = build_state(context)
            if not s.ss_ready then return false end
            if not s.ss_purge_name then return false end
            -- Player-only gate
            if settings.shield_slam_purge_pvp_only ~= false then
                local ok, is_player = pcall(function() return context.target:is_player() end)
                if not (ok and is_player) then return false end
            end
            context._ss_purge_name = s.ss_purge_name
            return true
        end,
        execute = function(context)
            local name = context._ss_purge_name or "buff"
            return NS.try_cast(SPELLS.ShieldSlam, context.target, "[PROT] Shield Slam purge → " .. name, { expected_cooldown = SHIELD_SLAM_CD })
        end,
    },
    -- 4) Threat-gen core (single-target and AoE)
    {
        name = "ShieldSlam",
        matches = function(context)
            local s = build_state(context)
            return is_defensive_stance(s.stance) and s.ss_ready
        end,
        execute = function(context) return NS.try_cast(SPELLS.ShieldSlam, context.target, "[PROT] ShieldSlam", { expected_cooldown = SHIELD_SLAM_CD }) end,
    },
    {
        name = "Revenge",
        matches = function(context)
            local s = build_state(context)
            return is_defensive_stance(s.stance) and s.revenge_ready
        end,
        execute = function(context) return NS.try_cast(SPELLS.Revenge, context.target, "[PROT] Revenge", { expected_cooldown = REVENGE_CD }) end,
    },
    {
        name = "Taunt",
        matches = function(context) return taunt_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.Taunt, context.target, "[PROT] Taunt")
        end,
    },
    {
        name = "MockingBlow",
        matches = function(context) return mocking_blow_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.MockingBlow, context.target, "[PROT] MockingBlow")
        end,
    },
    {
        name = "ChallengingShout",
        matches = function(context) return challenging_shout_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.ChallengingShout, context.me or NS.GetPlayer(), "[PROT] ChallengingShout", { skip_range = true })
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
            return true
        end,
        execute = function(context) return NS.try_cast(SPELLS.ShieldBlock, context.me or NS.GetPlayer(), "[PROT] ShieldBlock", { skip_range = true, expected_cooldown = SHIELD_BLOCK_CD }) end,
    },
    -- 5) Sunder / Devastate stack maintenance
    {
        name = "Devastate",
        matches = function(context) return devastate_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.Devastate, context.target, "[PROT] Devastate")
        end,
    },
    {
        name = "SunderArmor",
        matches = function(context) return sunder_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.SunderArmor, context.target, "[PROT] Sunder")
        end,
    },
    -- 5) Execute phase (sub-20%)
    {
        name = "Execute",
        matches = function(context) return execute_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.Execute, context.target, "[PROT] Execute")
        end,
    },
    -- 6) AoE tanking
    {
        name = "ThunderClap",
        matches = function(context) return thunderclap_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.ThunderClap, context.me or NS.GetPlayer(), "[PROT] ThunderClap", { skip_range = true, expected_cooldown = THUNDERCLAP_CD })
        end,
    },
    -- 7) Debuff maintenance
    {
        name = "DemoralizingShout",
        matches = function(context) return demo_shout_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.DemoralizingShout, context.me or NS.GetPlayer(), "[PROT] DemoShout", { skip_range = true, expected_cooldown = DEMO_SHOUT_CD })
        end,
    },
    -- 8) Buffs / Shouts
    {
        name = "BattleShout",
        matches = function(context) return battle_shout_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.BattleShout, context.me or NS.GetPlayer(), "[PROT] BattleShout", { skip_range = true })
        end,
    },
    {
        name = "CommandingShout",
        matches = function(context) return commanding_shout_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.CommandingShout, context.me or NS.GetPlayer(), "[PROT] CommandingShout", { skip_range = true })
        end,
    },
    -- 9) Rage dump
    {
        name = "Cleave",
        matches = function(context) return cleave_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.Cleave, context.target, "[PROT] Cleave")
        end,
    },
    {
        name = "HeroicStrike",
        matches = function(context) return heroic_strike_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.HeroicStrike, context.target, "[PROT] HeroicStrike")
        end,
    },
    -- 10) PvP / utility / movement
    {
        name = "SpellReflection",
        matches = function(context) return spell_reflect_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.SpellReflection, context.me or NS.GetPlayer(), "[PROT] SpellReflection", { skip_range = true })
        end,
    },
    {
        name = "Disarm",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_disarm == false then return false end
            if not (NS.is_spell_learned and NS.is_spell_learned(676)) then return false end
            if not context.in_combat then return false end
            if settings.disarm_pvp_only ~= false then
                local ok, is_player = pcall(function() return context.target:is_player() end)
                if not (ok and is_player) then return false end
            end
            return disarm_matches_fn(context, build_state(context))
        end,
        execute = function(context)
            local label = context._disarm_burst_name
                and ("[PROT] Disarm → " .. context._disarm_burst_name)
                or "[PROT] Disarm"
            return NS.try_cast(SPELLS.Disarm, context.target, label, { expected_cooldown = DISARM_CD })
        end,
    },
    {
        name = "ConcussionBlow",
        matches = function(context) return concussion_blow_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.ConcussionBlow, context.target, "[PROT] ConcussionBlow")
        end,
    },
    {
        name = "Hamstring",
        matches = function(context) return hamstring_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.Hamstring, context.target, "[PROT] Hamstring")
        end,
    },
    {
        name = "Intercept",
        matches = function(context) return intercept_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.Intercept, context.target, "[PROT] Intercept")
        end,
    },
    {
        name = "BerserkerRage",
        matches = function(context) return berserker_rage_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.BerserkerRage, context.me or NS.GetPlayer(), "[PROT] BerserkerRage", { skip_range = true })
        end,
    },
    -- 11) FrostByte gaps: utility and sustain
    {
        name = "Bloodrage",
        matches = function(context) return bloodrage_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.Bloodrage, context.me or NS.GetPlayer(), "[PROT] Bloodrage", { skip_range = true, skip_gcd = true })
        end,
    },
    {
        name = "VictoryRush",
        matches = function(context) return victory_rush_matches_fn(context, build_state(context)) end,
        execute = function(context)
            -- VictoryRush works in any stance, no stance swap needed
            return NS.try_cast(SPELLS.VictoryRush, context.target, "[PROT] VictoryRush")
        end,
    },
    {
        name = "Rend",
        matches = function(context) return rend_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.Rend, context.target, "[PROT] Rend")
        end,
    },
    {
        name = "IntimidatingShout",
        matches = function(context) return intimidating_shout_matches_fn(context, build_state(context)) end,
        execute = function(context)
            return NS.try_cast(SPELLS.IntimidatingShout, context.me or NS.GetPlayer(), "[PROT] IntimidatingShout", { skip_range = true })
        end,
    },
}

NS.rotation_registry:register("protection", strategies, { get_state = build_state })
NS.log("Warrior protection rotation registered (build_state + explicit strategies, all TBC Protection spells)")
return strategies
