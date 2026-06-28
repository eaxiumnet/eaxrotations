-- fury_sylvanas -- warrior fury_sylvanas rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies for fury_sylvanas gameplay.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.
-- SAFETY: every state field read is nil-guarded via build_state() defaults; no on_update() allocs.

-- Warrior Fury priority list — parity v1.0.6+ parity (auto-charge, rampage stacks, sunder, rend, overpower, defensives)
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

-- Spell actions
local ACTION = {
    BattleShout = SPELLS.BattleShout,
    BattleStance = SPELLS.BattleStance,
    BerserkerRage = SPELLS.BerserkerRage,
    BerserkerStance = SPELLS.BerserkerStance,
    Bloodrage = SPELLS.Bloodrage,
    Bloodthirst = SPELLS.Bloodthirst,
    Charge = SPELLS.Charge,
    Cleave = SPELLS.Cleave,
    CommandingShout = SPELLS.CommandingShout,
    DeathWish = SPELLS.DeathWish,
    DefensiveStance = SPELLS.DefensiveStance,
    DemoralizingShout = SPELLS.DemoralizingShout,
    Execute = SPELLS.Execute,
    Hamstring = SPELLS.Hamstring,
    HeroicStrike = SPELLS.HeroicStrike,
    Intercept = SPELLS.Intercept,
    Overpower = SPELLS.Overpower,
    Pummel = SPELLS.Pummel,
    Rampage = SPELLS.Rampage,
    Recklessness = SPELLS.Recklessness,
    Rend = SPELLS.Rend,
    Slam = SPELLS.Slam,
    SunderArmor = SPELLS.SunderArmor,
    SweepingStrikes = SPELLS.SweepingStrikes,
    ThunderClap = SPELLS.ThunderClap,
    VictoryRush = SPELLS.VictoryRush,
    Whirlwind = SPELLS.Whirlwind,
}

-- Buff/debuff ID tables
local BATTLE_SHOUT_BUFF = CONSTANTS.BATTLE_SHOUT_IDS or { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local COMMANDING_SHOUT_BUFF = CONSTANTS.COMMANDING_SHOUT_BUFF or { 469 }
local BERSERKER_RAGE_BUFF = { 18499 }
local SWEEPING_STRIKES_BUFF = { 12328 }
local VICTORY_RUSH_BUFF = { 34428 }
local RAMPAGE_BUFF = { 30033, 30032, 30030 }
local SUNDER_DEBUFF = CONSTANTS.SUNDER_DEBUFF or { 25225, 11597, 11596, 8380, 7405, 7386 }
local REND_DEBUFF = { 25208, 11574, 11573, 6548, 6547, 772 }
local DEMO_SHOUT_DEBUFF = CONSTANTS.DEMO_SHOUT_DEBUFF or { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local THUNDER_CLAP_DEBUFF = CONSTANTS.THUNDER_CLAP_DEBUFF or { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
local HAMSTRING_DEBUFF = { 25212, 7373, 7372, 1715 }

-- Healthstone and health potion item IDs (TBC, best to worst)
local HEALTHSTONE_IDS = { 22116, 22105, 22104, 22103, 22102, 22101 }
local HEALTH_POTION_IDS = { 22829, 28102, 13446, 13442, 3928, 1710 }

-- Constants
local EXECUTE_DEFAULT_RAGE = 25
local BLOODTHIRST_RESERVE = 30
local WHIRLWIND_RESERVE = 25
local CORE_POOL_WINDOW = 2.0
local SLAM_RAGE_COST = 15
local SLAM_CAST_TIME = 0.5
local SLAM_SAFETY = 0.2
local HEROIC_STRIKE_RAGE = 60
local CLEAVE_RAGE = 55
local STANCE_CAST_LOCKOUT = 2.0
local TACTICAL_MASTERY_CAP = 25
local last_stance_cast_at = 0

local function stance_lockout_active()
    return (NS.time_now and NS.time_now() or 0) < last_stance_cast_at + STANCE_CAST_LOCKOUT
end


-- Test assertion strings (preserved for regression tests)
-- Action fields referenced via build_action() in strategy specs

-- State table
local fury_state = {
    rage = 0,
    hp = 100,
    target_hp = 100,
    stance = STANCE.BERSERKER,
    enemy_count = 1,
    is_pvp = false,
    in_combat = false,
    is_moving = false,
    target_distance = 0,
    target_is_casting = false,
    target_casting_interruptible = false,
    ttd = 0,
    has_battle_shout = false,
    has_commanding_shout = false,
    has_berserker_rage = false,
    has_sweeping_strikes = false,
    has_rampage = false,
    rampage_stacks = 0,
    victory_rush_ready = false,
    sunder_stacks = 0,
    rend_remains = 0,
    hamstring_remains = 0,
    demo_remains = 0,
    tclap_remains = 0,
    bt_cd = 99,
    ww_cd = 99,
    bt_ready = false,
    ww_ready = false,
    execute_ready = false,
    slam_ready = false,
    sweeping_ready = false,
    heroic_ready = false,
    cleave_ready = false,
    pummel_ready = false,
    intercept_ready = false,
    charge_ready = false,
    hamstring_ready = false,
    overpower_ready = false,
    execute_phase = false,
    death_wish_ready = false,
    recklessness_ready = false,
    bloodrage_ready = false,
    victory_ready = false,
    sunder_ready = false,
    rend_ready = false,
    demo_ready = false,
    thunder_ready = false,
    -- Charge/Intercept protection
    charge_lock_until = 0,
    intercept_fired_at = 0,
    
    healthstone_ready = false,
    healthstone_id = nil,
    health_potion_ready = false,
    health_potion_id = nil,
}

-- Helper functions
local setting = NS.setting or function(context, key, fallback)
    local settings = context and context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then return NS.get_setting(key, fallback) end
    return fallback
end

local function bool_call(unit, method)
    if not unit or type(unit[method]) ~= "function" then return false end
    local ok, value = pcall(unit[method], unit)
    return ok and value == true
end

local function execute_phase(context, state)
    if NS.is_execute_phase then return NS.is_execute_phase(context.target_hp, 20) end
    if (state.target_hp or context.target_hp or 100) <= 20 then return true end
    -- TTD awareness: treat as execute phase if target is dying soon
    if (state.ttd or 0) > 0 and (state.ttd or 0) < 15 then return true end
    return false
end

local function preserved_rage_after_swap(rage)
    if NS.get_tactical_mastery_cap then return NS.get_tactical_mastery_cap() end
    local cap = TACTICAL_MASTERY_CAP or 25
    return (rage or 0) < cap and (rage or 0) or cap
end

local function stance_swap_safe(state, cost)
    local effective_cost = math.min(cost or 0, 15)
    if state.stance == nil then return true end
    return preserved_rage_after_swap(state.rage or 0) >= effective_cost
end

local function desired_stance(context)
    local preference = setting(context, "stance_preference", "auto")
    if preference == "battle" or preference == STANCE.BATTLE then return STANCE.BATTLE end
    if preference == "defensive" or preference == STANCE.DEFENSIVE then return STANCE.DEFENSIVE end
    if preference == "berserker" or preference == STANCE.BERSERKER then return STANCE.BERSERKER end
    return nil
end

local function action(context, row)
    if not context or not row then return false end
    if not row.spell then return true end
    local target = (row.target == "self" or row.requires_target == false) and (context.me or NS.GetPlayer()) or context.target
    if not target then return false end
        if row.min_rage and context.rage and context.rage < row.min_rage then return false end
    if row.required_stance and context.stance ~= row.required_stance then return false end
    local opts = {}
    if row.requires_target == false then opts.skip_range = true end
    if row.cooldown then opts.expected_cooldown = row.cooldown end
    return NS.spell_ready(row.spell, target, opts)
end

local function cast(context, row)
    if not context or not row then return false end
    if not row.spell then return false end
    local target = (row.target == "self" or row.requires_target == false) and (context.me or NS.GetPlayer()) or context.target
    if not target then return false end
    local opts = {}
    if row.requires_target == false then opts.skip_range = true end
    if row.cooldown then opts.expected_cooldown = row.cooldown end
    local ok = NS.try_cast(row.spell, target, "[FURY]", opts)
    if ok and row.kind == "form" then
        last_stance_cast_at = NS.time_now and NS.time_now() or 0
    end
    return ok
end

local function build_action(name, spell_value, opts)
    local row = opts or {}
    row.name = name
    row.spell = spell_value
    return row
end

-- ============================================================================
-- State builder
-- ============================================================================
local _last_build_state_time = -1
local function build_state(context)
    local state = fury_state
    local now = context.now
    if now and now == _last_build_state_time then return state end
    now = now or (NS.time_now and NS.time_now() or 0)
    if context.now then _last_build_state_time = now end
    state.now = now

    local is_group = context.is_group or false
    state.is_group = is_group
    local target = context.target
    local me = context.me or NS.GetPlayer()

    fury_state.rage = context.rage or 0
    fury_state.hp = context.hp or 100
    fury_state.target_hp = context.target_hp or 100
    fury_state.stance = context.stance or STANCE.BERSERKER
    fury_state.enemy_count = context.enemy_count or context.enemies_count or 1
    fury_state.is_pvp = context.is_pvp or (context.settings and context.settings.pvp_mode) or false
    fury_state.in_combat = context.in_combat or false
    fury_state.is_moving = context.is_moving or false
    fury_state.target_distance = context.target_distance or context.target_range or context.distance or 0
    fury_state.target_is_casting = context.target_is_casting or (target and bool_call(target, "is_casting")) or false
    fury_state.target_casting_interruptible = fury_state.target_is_casting and (NS.is_interruptible and NS.is_interruptible(target) or false)
    fury_state.ttd = context.ttd or 999

    -- Buffs
    fury_state.has_battle_shout = NS.buff_up(me, BATTLE_SHOUT_BUFF) or false
    fury_state.has_commanding_shout = NS.buff_up(me, COMMANDING_SHOUT_BUFF) or false
    fury_state.has_berserker_rage = NS.buff_up(me, BERSERKER_RAGE_BUFF) or false
    fury_state.has_sweeping_strikes = NS.buff_up(me, SWEEPING_STRIKES_BUFF) or false
    fury_state.has_rampage = NS.buff_up(me, RAMPAGE_BUFF) or false
    fury_state.rampage_stacks = NS.buff_stacks(me, RAMPAGE_BUFF) or 0
    fury_state.victory_rush_ready = NS.buff_up(me, VICTORY_RUSH_BUFF) or false

    -- Debuffs on target
    if target then
        fury_state.sunder_stacks = NS.debuff_stacks(target, SUNDER_DEBUFF) or 0
        fury_state.rend_remains = NS.debuff_remains(target, REND_DEBUFF) or 0
        fury_state.hamstring_remains = NS.debuff_remains(target, HAMSTRING_DEBUFF) or 0
        fury_state.demo_remains = NS.debuff_remains(target, DEMO_SHOUT_DEBUFF) or 0
        fury_state.tclap_remains = NS.debuff_remains(target, THUNDER_CLAP_DEBUFF) or 0
    end

    -- Spell readiness
    fury_state.bt_cd = NS.cooldown_remains(ACTION.Bloodthirst, 6) or 0
    fury_state.ww_cd = NS.cooldown_remains(ACTION.Whirlwind, 10) or 0
    fury_state.bt_ready = NS.spell_ready(ACTION.Bloodthirst, target, { expected_cooldown = 6 }) or false
    fury_state.ww_ready = NS.spell_ready(ACTION.Whirlwind, target, { expected_cooldown = 10 }) or false

    -- Stance fallback: engine may return 0 intermittently; trust buff detection
    if fury_state.stance == 0 and NS.has_form then
        if NS.has_form("berserker") then fury_state.stance = STANCE.BERSERKER
        elseif NS.has_form("battle") then fury_state.stance = STANCE.BATTLE
        elseif NS.has_form("defensive") then fury_state.stance = STANCE.DEFENSIVE
        end
    end
    fury_state.execute_ready = NS.spell_ready(ACTION.Execute, target) or false
    fury_state.slam_ready = NS.spell_ready(ACTION.Slam, target) or false
    fury_state.sweeping_ready = NS.spell_ready(ACTION.SweepingStrikes, me, { skip_range = true }) or false
    fury_state.heroic_ready = NS.spell_ready(ACTION.HeroicStrike, target) or false
    fury_state.cleave_ready = NS.spell_ready(ACTION.Cleave, target) or false
    fury_state.pummel_ready = NS.spell_ready(ACTION.Pummel, target) or false
    fury_state.intercept_ready = NS.spell_ready(ACTION.Intercept, target) or false
    fury_state.charge_ready = NS.spell_ready(ACTION.Charge, target) or false
    fury_state.hamstring_ready = NS.spell_ready(ACTION.Hamstring, target) or false
    fury_state.overpower_ready = NS.spell_ready(ACTION.Overpower, target) and fury_state.stance == STANCE.BATTLE
    fury_state.death_wish_ready = NS.spell_ready(ACTION.DeathWish, me, { skip_range = true }) or false
    fury_state.recklessness_ready = NS.spell_ready(ACTION.Recklessness, me, { skip_range = true }) or false
    fury_state.bloodrage_ready = NS.spell_ready(ACTION.Bloodrage, me, { skip_range = true }) or false
    fury_state.victory_ready = NS.spell_ready(ACTION.VictoryRush, target) or false
    fury_state.sunder_ready = NS.spell_ready(ACTION.SunderArmor, target) or false
    fury_state.rend_ready = NS.spell_ready(ACTION.Rend, target) or false
    fury_state.demo_ready = NS.spell_ready(ACTION.DemoralizingShout, me, { skip_range = true }) or false
    fury_state.thunder_ready = NS.spell_ready(ACTION.ThunderClap, me, { skip_range = true, expected_cooldown = 4 }) or false

    fury_state.execute_phase = execute_phase(context, fury_state)

    -- Healthstone: find first available healthstone in bags
    fury_state.healthstone_id = nil
    fury_state.healthstone_ready = false
    fury_state.health_potion_id = nil
    fury_state.health_potion_ready = false
    if NS.is_item_ready then
        for i = 1, #HEALTHSTONE_IDS do
            local id = HEALTHSTONE_IDS[i]
            if NS.is_item_ready(id) then
                fury_state.healthstone_id = id
                fury_state.healthstone_ready = true
                break
            end
        end
        if not fury_state.healthstone_ready then
            for i = 1, #HEALTH_POTION_IDS do
                local id = HEALTH_POTION_IDS[i]
                if NS.is_item_ready(id) then
                    fury_state.health_potion_id = id
                    fury_state.health_potion_ready = true
                    break
                end
            end
        end
    end

    -- Swing timer for Slam weave + HS trick
    fury_state.mh_until = (me and NS.swing_time_until and NS.swing_time_until(me)) or 999
    fury_state.mh_progress = (me and NS.swing_progress and NS.swing_progress(me)) or 0
    fury_state.oh_until = (me and NS.swing_time_until and NS.swing_time_until(me, 2)) or 999

    -- Sweeping Strikes cooldown
    fury_state.ss_cd = NS.cooldown_remains(ACTION.SweepingStrikes, 30) or 0

    -- Target casting state for interrupt reserve
    fury_state.target_casting_interruptible = fury_state.target_is_casting and (NS.is_interruptible and NS.is_interruptible(target) or false) or false

    -- Offhand check: swing timer returns >0 for OH slot → equipped
    local oh_swing = me and NS.swing_time_until and NS.swing_time_until(me, 2) or 0
    fury_state.has_offhand = oh_swing > 0

    return fury_state
end

-- ============================================================================
-- Stance
-- ============================================================================
local function berserker_stance_action()
    return build_action("BerserkerStance", ACTION.BerserkerStance, { target = "self", kind = "form", form = "berserker", requires_target = false })
end

local function battle_stance_action()
    return build_action("BattleStance", ACTION.BattleStance, { target = "self", kind = "form", form = "battle", requires_target = false })
end

-- ============================================================================
-- Match functions
-- ============================================================================

-- Charge: OOC with pull protection, respects toggle, stays in Battle Stance
local function charge_matches(context, state)
    local auto_charge = setting(context, "auto_charge", true)
    if not auto_charge then return false end
    if state.in_combat then return false end
    -- Charge Only OOC Mobs protection: skip if target is already in combat
    local ooc_only = setting(context, "charge_ooc_only", true)
    if ooc_only and context.target then
        local target_in_combat = bool_call(context.target, "is_in_combat") or false
        if target_in_combat then return false end
    end
    if (state.target_distance or 0) < 8 or (state.target_distance or 0) > 25 then return false end
    -- Openers only: stay in Battle Stance between fights
    if state.stance ~= STANCE.BATTLE and not stance_swap_safe(state, 0) then return false end
    return action(context, build_action("Charge", ACTION.Charge, { required_stance = STANCE.BATTLE, cooldown = 15 }))
end

-- Battle Shout / Commanding Shout
local function battle_shout_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.BattleShout, 3.0) then return false end
    if state.has_battle_shout or state.has_commanding_shout then return false end
    return action(context, build_action("BattleShout", ACTION.BattleShout, { target = "self", kind = "buff", buff = BATTLE_SHOUT_BUFF, requires_target = false, min_rage = 10 }))
end

-- Bloodrage: low rage generation
local function bloodrage_matches(context, state)
    if (state.rage or 0) >= 20 then return false end
    if not state.in_combat and (state.hp or 100) < 90 then return false end
    return action(context, build_action("Bloodrage", ACTION.Bloodrage, { target = "self", requires_target = false, skip_gcd = true, cooldown = 60 }))
end

-- Victory Rush: post-kill
local function victory_rush_matches(context, state)
    if not (context.me or NS.GetPlayer()) then return false end
    if not state.victory_rush_ready then return false end
    return action(context, build_action("VictoryRush", ACTION.VictoryRush, {}))
end

-- Healthstone / HealthPotion: auto-use consumable at low HP (healthstone preferred, potion fallback)
local function healthstone_matches(context, state)
    local hs_enabled = setting(context, "use_healthstones", true)
    if not hs_enabled then return false end
    local hs_hp = setting(context, "healthstone_hp", 35)
    if (state.hp or 100) > hs_hp then return false end
    -- Healthstone preferred, then health potion as fallback
    if state.healthstone_ready and state.healthstone_id then
        return true
    end
    if state.health_potion_ready and state.health_potion_id then
        return true
    end
    return false
end

-- Recklessness: big burst CD — use on cooldown in combat per Icy Veins
local function recklessness_matches(context, state)
    local cds_enabled = setting(context, "use_cooldowns", true)
    if not cds_enabled or not state.recklessness_ready then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) < 50 then return false end
    -- TTD gate: don't waste 30min CD if target is about to die
    if (state.ttd or 0) > 0 and (state.ttd or 0) < 10 then return false end
    return action(context, build_action("Recklessness", ACTION.Recklessness, { target = "self", required_stance = STANCE.BERSERKER, requires_target = false, cooldown = 1800 }))
end

-- Death Wish: burst CD
local function death_wish_matches(context, state)
    local cds_enabled = setting(context, "use_cooldowns", true)
    if not cds_enabled or not state.death_wish_ready then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if (state.hp or 100) < 45 then return false end
    -- TTD gate: don't waste burst CD if target is about to die
    if (state.ttd or 0) > 0 and (state.ttd or 0) < 10 then return false end
    if (state.target_hp or 100) < 20 and (state.rage or 0) < 25 then return false end
    return action(context, build_action("DeathWish", ACTION.DeathWish, { target = "self", requires_target = false, cooldown = 180 }))
end

-- Rampage: stack management — recast when stacks < min threshold or buff about to fall off
local function rampage_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Rampage, 3.0) then return false end
    if not state.in_combat then return false end
    if not state.has_rampage then
        -- No buff at all — apply it
        return action(context, build_action("Rampage", ACTION.Rampage, { target = "self", requires_target = false, min_rage = 30 }))
    end
    -- Stack maintenance: recast if stacks < configured minimum
    local min_stacks = setting(context, "rampage_min_stacks", 5)
    if (state.rampage_stacks or 0) < min_stacks then
        return action(context, build_action("Rampage", ACTION.Rampage, { target = "self", requires_target = false, min_rage = 30 }))
    end
    -- Refresh before expiry
    local rampage_remains = NS.buff_remains and NS.buff_remains(context.me or NS.GetPlayer(), RAMPAGE_BUFF) or 0
    if rampage_remains <= 3 then
        return action(context, build_action("Rampage", ACTION.Rampage, { target = "self", requires_target = false, min_rage = 30 }))
    end
    return false
end

-- Overpower: proc detection (requires Battle Stance)
local function overpower_matches(context, state)
    if not state.overpower_ready then return false end
    return action(context, build_action("Overpower", ACTION.Overpower, { required_stance = STANCE.BATTLE, min_rage = 5 }))
end

-- SS rage reservation: hold rage when SS coming off CD in AoE
local SS_RESERVE_FLOOR = 60
local SS_POOL_WINDOW = 2.0

local function should_reserve_for_sweeping(context, state)
    if (context.enemy_count or 0) < 2 then return false end
    if state.has_sweeping_strikes then return false end
    local ss_cd = state.ss_cd or 99
    if ss_cd <= SS_POOL_WINDOW and (context.rage or 0) < SS_RESERVE_FLOOR then return true end
    return false
end

-- HS/Cleave starvation: don't queue if it would starve BT or WW
local function would_starve_core_fury(context, state, cost)
    cost = cost or 15
    local rage = context.rage or 0
    local bt_cd = state.bt_cd or 99
    if bt_cd >= 0 and bt_cd <= 1.5 then
        if (rage - cost) < BLOODTHIRST_RESERVE then return true end
    end
    local ww_cd = state.ww_cd or 99
    if ww_cd >= 0 and ww_cd <= 1.5 then
        if (rage - cost) < WHIRLWIND_RESERVE then return true end
    end
    -- Interrupt reserve
    if state.target_casting_interruptible and state.pummel_ready then
        if (rage - cost) < 10 then return true end
    end
    return false
end

-- Bloodthirst: core Fury ability
local function bt_matches(context, state)
    -- WW priority: yield to Whirlwind when enough enemies nearby and WW is ready
    local ww_prio = setting(context, "fury_ww_prio_count", 2)
    if ww_prio > 0 and (state.enemy_count or 0) >= ww_prio and (context.rage or 0) >= 25 and state.ww_ready then
        return false
    end
    return action(context, build_action("Bloodthirst", ACTION.Bloodthirst, { required_stance = STANCE.BERSERKER, min_rage = 30, cooldown = 6 }))
end

-- Rend removed: not used in TBC Fury rotation per Icy Veins/Wowhead

-- Sunder Armor: stack armor reduction
local function sunder_armor_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.SunderArmor, 2.0) then return false end
    if (context.target_armor or 0) <= 0 then return false end
    if execute_phase(context, state) then return false end
    local sunder_mode = setting(context, "sunder_mode", "off")
    if sunder_mode == "off" then return false end
    local max_stacks = setting(context, "sunder_stacks", 3)
    if (state.sunder_stacks or 0) >= max_stacks then return false end
    -- Low priority mode: only cast if rage is high
    if sunder_mode == "low" and (state.rage or 0) < 60 then return false end
    return action(context, build_action("SunderArmor", ACTION.SunderArmor, { min_rage = 15, debuff = SUNDER_DEBUFF }))
end

-- Sweeping Strikes: AoE prep
local function sweeping_strikes_matches(context, state)
    local min_count = setting(context, "sweeping_strikes_count", 2)
    if (state.enemy_count or 0) < min_count then return false end
    if state.has_sweeping_strikes then return false end
    if state.stance ~= STANCE.BATTLE then return false end
    return action(context, build_action("SweepingStrikes", ACTION.SweepingStrikes, { target = "self", required_stance = STANCE.BATTLE, min_rage = 30, requires_target = false, enemy_count = min_count, cooldown = 30 }))
end

-- Whirlwind: filler + AoE — use with any extra rage per Icy Veins
local function whirlwind_matches(context, state)
    if not state.ww_ready then return false end
    if (state.enemy_count or 0) < 2 and (state.rage or 0) < 25 then return false end
    return action(context, build_action("Whirlwind", ACTION.Whirlwind, { required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10 }))
end

-- Execute: finish phase
local function execute_matches(context, state)
    if not execute_phase(context, state) then return false end
    local min_rage = setting(context, "execute_phase_rage", EXECUTE_DEFAULT_RAGE)
    if (state.rage or 0) < min_rage then return false end
    return action(context, build_action("Execute", ACTION.Execute, { required_stance = STANCE.BERSERKER, min_rage = 15 }))
end

-- Slam: weave between swings (when Bloodthirst on CD)
local function slam_matches(context, state)
    if setting(context, "slam_weave_enabled", true) == false then return false end
    if state.is_moving then return false end
    if (state.rage or 0) < SLAM_RAGE_COST then return false end
    if (state.bt_cd or 99) <= 1.5 then return false end
    if (state.ww_cd or 99) <= 1.5 then return false end
    local rage_after_slam = (state.rage or 0) - SLAM_RAGE_COST
    if (state.bt_cd or 99) <= CORE_POOL_WINDOW and rage_after_slam < BLOODTHIRST_RESERVE then return false end
    if (state.ww_cd or 99) <= CORE_POOL_WINDOW and rage_after_slam < WHIRLWIND_RESERVE then return false end
    if (state.mh_until or 999) <= SLAM_CAST_TIME + SLAM_SAFETY then return false end
    if (state.mh_until or 999) > 1.5 then return false end
    return action(context, build_action("Slam", ACTION.Slam, { min_rage = SLAM_RAGE_COST, not_moving = true }))
end

-- Heroic Strike: off-GCD rage dump with HS trick + starvation + interrupt reserve
local function heroic_strike_matches(context, state)
    -- SS reservation
    if should_reserve_for_sweeping(context, state) then return false end
    -- Starvation + interrupt check
    if would_starve_core_fury(context, state, 15) then return false end
    -- HS Trick: proactively queue when OH swing is imminent (before rage threshold)
    -- Dequeue middleware handles safety
    local me = context.me or NS.GetPlayer()
    local settings = context.settings or {}
    if settings.hs_trick and me then
        local oh_remaining = (me and NS.swing_time_until and NS.swing_time_until(me, 2)) or 999
        local mh_remaining = (me and NS.swing_time_until and NS.swing_time_until(me)) or 999
        if oh_remaining > 0 and oh_remaining <= 0.4 then
            if mh_remaining > oh_remaining + 0.3 then
                return action(context, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = 15 }))
            end
        end
    end
    -- Normal HS threshold
    local hs_rage = setting(context, "heroic_strike_rage", HEROIC_STRIKE_RAGE)
    -- HS Trick lower threshold when dual-wielding (dequeue middleware handles safety)
    if settings.hs_trick and state.has_offhand then
        hs_rage = 30
    end
    if (state.rage or 0) < hs_rage then return false end
    return action(context, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = hs_rage }))
end

-- Cleave: AoE rage dump with starvation + SS reservation
local function cleave_matches(context, state)
    if should_reserve_for_sweeping(context, state) then return false end
    if (state.enemy_count or 0) < 2 then return false end
    local cleave_rage = setting(context, "cleave_rage", CLEAVE_RAGE)
    local rage = state.rage or 0
    if rage < cleave_rage then return false end
    if would_starve_core_fury(context, state, 15) then return false end
    return action(context, build_action("Cleave", ACTION.Cleave, { min_rage = cleave_rage, enemy_count = 2, is_aoe = true }))
end

-- Demoralizing Shout: enemy damage reduction
local function demo_shout_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.DemoralizingShout, 2.0) then return false end
    if (state.demo_remains or 0) > 5 then return false end
    if not state.is_pvp and (state.enemy_count or 0) < 2 and (state.hp or 100) > 70 then return false end
    return action(context, build_action("DemoralizingShout", ACTION.DemoralizingShout, { target = "self", min_rage = 10, requires_target = false, debuff = DEMO_SHOUT_DEBUFF, refresh = 5 }))
end

-- Thunder Clap removed: not used by Fury warrior (tank/Arms debuff)

-- Berserker Rage: fear break / enrage
local function berserker_rage_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.BerserkerRage, 3.0) then return false end
    if not state.in_combat then return false end
    if state.has_berserker_rage then return false end
    return action(context, build_action("BerserkerRage", ACTION.BerserkerRage, { target = "self", requires_target = false, cooldown = 30 }))
end

-- Hamstring: PvP snare + Sword Spec weave (high rage)
local function hamstring_matches(context, state)
    -- PvP snare
    if state.is_pvp then
        if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Hamstring, 2.0) then return false end
        if (state.hamstring_remains or 0) > 3 then return false end
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }))
    end
    -- Sword Spec weave: generate extra attacks when rage is high and BT/WW on CD
    if setting(context, "fury_use_hamstring", false) then
        local min_rage = setting(context, "fury_hamstring_rage", 50)
        if (state.rage or 0) >= min_rage then
            -- Only weave when core abilities are on CD
            if (state.bt_cd or 99) > 1.5 and (state.ww_cd or 99) > 1.5 and not state.execute_phase then
                return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10 }))
            end
        end
    end
    return false
end

-- Swing Desync: when dual-wielding with synced MH/OH swings, inject a Slam
-- to offset timers, smoothing rage gen and helping Flurry/WF benefit both hands.
local DESYNC_COOLDOWN = 10
local DESYNC_SYNC_THRESHOLD = 0.3
local DESYNC_SLAM_WINDOW = 1.6
local desync_last_attempt = 0

local function swing_desync_matches(context, state)
    if not setting(context, "fury_swing_desync", false) then return false end
    if state.is_moving then return false end
    if not state.has_offhand then return false end
    -- Cooldown between desync attempts
    local now = NS.time_now and NS.time_now() or 0
    if (now - desync_last_attempt) < DESYNC_COOLDOWN then return false end
    -- Both hands must be actively swinging
    local me = context.me or NS.GetPlayer()
    if not me then return false end
    local mh_remaining = (me and NS.swing_time_until and NS.swing_time_until(me)) or 0
    local oh_remaining = (me and NS.swing_time_until and NS.swing_time_until(me, 2)) or 0
    if mh_remaining <= 0 or oh_remaining <= 0 then return false end
    -- Check if swings are synced (remaining times close together)
    if math.abs(mh_remaining - oh_remaining) > DESYNC_SYNC_THRESHOLD then return false end
    -- Need enough swing time for base Slam (1.5s) to land before next auto
    if mh_remaining < DESYNC_SLAM_WINDOW then return false end
    -- Don't starve BT/WW if they're coming off CD soon
    if (state.bt_cd or 99) <= 1.0 and (state.rage or 0) < (BLOODTHIRST_RESERVE + SLAM_RAGE_COST) then return false end
    if (state.ww_cd or 99) <= 1.0 and (state.rage or 0) < (WHIRLWIND_RESERVE + SLAM_RAGE_COST) then return false end
    local rage = state.rage or 0
    if rage < SLAM_RAGE_COST then return false end
    if rage >= 90 then return false end  -- don't Slam at rage cap, use filler
    return action(context, build_action("Slam", ACTION.Slam, { min_rage = SLAM_RAGE_COST, not_moving = true }))
end

-- Intercept: in-combat gap closer (respects auto_charge toggle — v2.2.0 fix)
local function intercept_matches(context, state)
    if not state.in_combat then return false end
    local auto_charge = setting(context, "auto_charge", true)
    if not auto_charge then return false end
    if (state.target_distance or 0) < 8 or (state.target_distance or 0) > 25 then return false end
    -- v2.1.7 / v2.1.8: Charge opener protection — don't Intercept if we just Charged
    if not (NS.spell_ready(ACTION.Intercept, context.target) or false) then return false end
    return action(context, build_action("Intercept", ACTION.Intercept, { required_stance = STANCE.BERSERKER, min_rage = 10, cooldown = 30 }))
end

-- Berserker Stance: preferred DPS stance
local function berserker_stance_matches(context, state)
    if state.stance == STANCE.BERSERKER then return false end
    if stance_lockout_active() then return false end
    if NS.has_form and NS.has_form("berserker") then return false end
    if desired_stance(context) == STANCE.BERSERKER then return action(context, berserker_stance_action()) end
    -- Execute requires Berserker Stance
    if state.execute_phase and (state.rage or 0) >= 15 and stance_swap_safe(state, 15) then
        return action(context, berserker_stance_action())
    end
    if state.bt_ready and stance_swap_safe(state, 30) then
        return action(context, berserker_stance_action())
    end
    if state.ww_ready and stance_swap_safe(state, 25) and ((state.enemy_count or 0) >= 2 or (state.rage or 0) >= 45) then
        return action(context, berserker_stance_action())
    end
    return false
end

-- Battle Stance: for Charge, Overpower, Thunder Clap
local function battle_stance_matches(context, state)
    if state.stance == STANCE.BATTLE then return false end
    if stance_lockout_active() then return false end
    if NS.has_form and NS.has_form("battle") then return false end
    if desired_stance(context) == STANCE.BATTLE then return action(context, battle_stance_action()) end
    if state.overpower_ready and stance_swap_safe(state, 5) then return action(context, battle_stance_action()) end
    local ss_count = setting(context, "sweeping_strikes_count", 2)
    if state.sweeping_ready and not state.has_sweeping_strikes and (state.enemy_count or 0) >= ss_count and stance_swap_safe(state, 30) then
        return action(context, battle_stance_action())
    end
    if not state.in_combat and state.charge_ready and stance_swap_safe(state, 0) then return action(context, battle_stance_action()) end
    return false
end

-- ============================================================================
-- Strategies
-- ============================================================================
local STRATEGY_SPECS = {
    -- Auto-potions (context-based, O(1) gate)
    { "HealthPotion", function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end, build_action("HealthPotion", nil, { target = "self", requires_target = false }), function(context)
          return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS)
      end },
    { "DamagePotion", function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_damage_potion then return false end
          if not context.should_burst then return false end
          return true
      end, build_action("DamagePotion", nil, { target = "self", requires_target = false }), function(context)
          return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS)
      end },
    -- Utility / Survival (highest priority)
    { "Healthstone", healthstone_matches, build_action("Healthstone", nil, { target = "self", requires_target = false }), function(context)
        local s = build_state(context or {})
        if s.healthstone_ready and s.healthstone_id and NS.use_item_by_id then
            return NS.use_item_by_id(s.healthstone_id, context.me or context.target)
        end
        if s.health_potion_ready and s.health_potion_id and NS.use_item_by_id then
            return NS.use_item_by_id(s.health_potion_id, context.me or context.target)
        end
        return false
    end },
    -- PvP / Interrupt
    { "Intercept", intercept_matches, build_action("Intercept", ACTION.Intercept, { required_stance = STANCE.BERSERKER, min_rage = 10 }) },
    { "Hamstring", hamstring_matches, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }) },
    -- Stance
    { "BerserkerStance", berserker_stance_matches, berserker_stance_action() },
    { "BattleStance", battle_stance_matches, battle_stance_action() },
    -- Buffs
    { "BattleShout", battle_shout_matches, build_action("BattleShout", ACTION.BattleShout, { target = "self", kind = "buff", buff = BATTLE_SHOUT_BUFF, requires_target = false }) },
    { "BerserkerRage", berserker_rage_matches, build_action("BerserkerRage", ACTION.BerserkerRage, { target = "self", requires_target = false, cooldown = 30 }) },
    { "Bloodrage", bloodrage_matches, build_action("Bloodrage", ACTION.Bloodrage, { target = "self", requires_target = false, skip_gcd = true }) },
    { "VictoryRush", victory_rush_matches, build_action("VictoryRush", ACTION.VictoryRush, {}) },
    -- Charge opener (OOC)
    { "Charge", charge_matches, build_action("Charge", ACTION.Charge, { required_stance = STANCE.BATTLE, cooldown = 15 }) },
    -- Cooldowns
    { "Recklessness", recklessness_matches, build_action("Recklessness", ACTION.Recklessness, { target = "self", required_stance = STANCE.BERSERKER, requires_target = false }) },
    { "DeathWish", death_wish_matches, build_action("DeathWish", ACTION.DeathWish, { target = "self", requires_target = false }) },
    -- AoE
    { "SweepingStrikes", sweeping_strikes_matches, build_action("SweepingStrikes", ACTION.SweepingStrikes, { target = "self", required_stance = STANCE.BATTLE, min_rage = 30, requires_target = false }) },
    -- Core rotation (APL order: BT → WW → Rampage → Execute → Slam)
    { "Bloodthirst", bt_matches, build_action("Bloodthirst", ACTION.Bloodthirst, { required_stance = STANCE.BERSERKER, min_rage = 30, cooldown = 6 }) },
    { "Whirlwind", whirlwind_matches, build_action("Whirlwind", ACTION.Whirlwind, { required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10 }) },
    { "Rampage", rampage_matches, build_action("Rampage", ACTION.Rampage, { target = "self", requires_target = false, min_rage = 30 }) },
    { "Execute", execute_matches, build_action("Execute", ACTION.Execute, { required_stance = STANCE.BERSERKER, min_rage = 15 }) },
    { "Slam", slam_matches, build_action("Slam", ACTION.Slam, { min_rage = SLAM_RAGE_COST, not_moving = true }) },
    { "SwingDesync", swing_desync_matches, build_action("SwingDesync", ACTION.Slam, { min_rage = SLAM_RAGE_COST, not_moving = true }) },
    -- Overpower REMOVED from Fury: Arms-only in TBC
    { "SunderArmor", sunder_armor_matches, build_action("SunderArmor", ACTION.SunderArmor, { min_rage = 15, debuff = SUNDER_DEBUFF }) },
    { "DemoralizingShout", demo_shout_matches, build_action("DemoralizingShout", ACTION.DemoralizingShout, { target = "self", min_rage = 10, requires_target = false }) },
    -- Rage dumps
    { "Cleave", cleave_matches, build_action("Cleave", ACTION.Cleave, { min_rage = CLEAVE_RAGE, enemy_count = 2, is_aoe = true }) },
    { "HeroicStrike", heroic_strike_matches, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = HEROIC_STRIKE_RAGE }) },
}

local strategies = {}
local _build = build_state

for i = 1, #STRATEGY_SPECS do
    local spec = STRATEGY_SPECS[i]
    local name = spec[1]
    local matches = spec[2]
    local row = spec[3]

    local custom_execute = spec[4]
    strategies[#strategies + 1] = {
        name = name,
        spell = row.spell,
        required_stance = row.required_stance,
        min_rage = row.min_rage,
        cooldown = row.cooldown,
        matches = function(context)
            local state = _build(context or {})
            return matches(context or {}, state)
        end,
        execute = custom_execute or function(context)
            return cast(context or {}, row)
        end,
    }
end

NS.rotation_registry:register("fury", strategies, { get_state = build_state })

-- Unified dispatcher registration (coexists with legacy for migration)
if NS.register_strategy then  -- both unified APIs available
    NS.register_state_builder("fury", build_state)
    for i = 1, #STRATEGY_SPECS do
        local spec = STRATEGY_SPECS[i]
        local unified_matches_fn = spec[2]
        local unified_row = spec[3]
        local unified_custom_execute = spec[4]
        NS.register_strategy({
            name = "Fury:" .. spec[1],
            playstyle = "fury",
            priority = #STRATEGY_SPECS - i + 1,
            matches = function(context, state)
                return unified_matches_fn(context, state)
            end,
            execute = unified_custom_execute or function(context, state)
                return cast(context, unified_row)
            end,
        })
    end
end

NS.log("Warrior fury rotation registered (parity v1.0.6+ parity) — legacy + unified")
return strategies
