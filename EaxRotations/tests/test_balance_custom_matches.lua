-- unit tests for balance_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local action_calls = {}
local spell_ready_calls = {}
_G.EaxRotations = {
    DruidSpells = {
        Barkskin = "Barkskin",
        FaerieFire = "FaerieFire",
        FaerieFireFeral = "FaerieFireFeral",
        ForceOfNature = "ForceOfNature",
        Hurricane = "Hurricane",
        InsectSwarm = "InsectSwarm",
        Moonfire = "Moonfire",
        MoonkinForm = "MoonkinForm",
        Starfire = "Starfire",
        Wrath = "Wrath",
    },
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    action_execute = function(ctx, act, prefix)
        if act and act.spell and _G.EaxRotations and _G.EaxRotations.try_cast then
            _G.EaxRotations.try_cast(act.spell, (ctx and ctx.target) or "player", prefix)
        end
        return true
    end,
    spell_ready = function(spell, target, opts)
        spell_ready_calls[#spell_ready_calls + 1] = { spell = spell, target = target, opts = opts }
        return true
    end,
    same_unit = function(a, b) return a == b end,
    GetPlayer = function() return "self" end,
    debuff_remains = function(target, debuff_list)
        return target and target._debuff_remains or 0
    end,
    player_buff_remains = function(buff_list)
        return 0
    end,
    has_player_buff = function(buff_list)
        return false
    end,
    buff_up = function(unit, ids) return false end,
    broken_api_throttled = nil,
    PLAYER_UNIT = "player",
    should_refresh_dot = function(remains, refresh, ttd, duration)
        if remains < refresh then
            if ttd and ttd > duration * 0.5 then return true end
            if not ttd then return true end
        end
        return false
    end,
    spell_action = function(ids, name)
        return { name = name, ids = ids }
    end,
    try_cast = function(spell, target, reason, opts)
        action_calls[#action_calls + 1] = { fn = "try_cast", spell = spell, target = target, reason = reason }
        return true
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local module = dofile("EaxRotations/classes/druid/balance_sylvanas.lua")
local strategies = module.strategies or module
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Insect Swarm: only refresh via should_refresh_dot
-- ============================================================================

local insect_swarm = find_strategy("InsectSwarmDoT")

-- Debuff fresh -> should NOT match
action_calls = {}
local ctx_is_fresh = {
    target = { _debuff_remains = 10 },
    has_valid_enemy_target = true,
    ttd = 60,
}
assert_false(insect_swarm.matches(ctx_is_fresh, { insect_remains = 10 }), "InsectSwarm should not match when debuff is fresh")
assert_eq(#action_calls, 0, "action_matches should not be called when debuff fresh")

-- Debuff expiring -> should match
action_calls = {}
local ctx_is_refresh = {
    target = { _debuff_remains = 1 },
    has_valid_enemy_target = true,
    ttd = 60,
}
assert_true(insect_swarm.matches(ctx_is_refresh, { insect_remains = 1, spell_damage = 800 }), "InsectSwarm should match when debuff needs refresh")

-- No target -> should return false
assert_false(insect_swarm.matches({}, {}), "InsectSwarm should not match when target is nil")

-- ============================================================================
-- Moonfire: only refresh via should_refresh_dot
-- ============================================================================

local moonfire = find_strategy("MoonfireDoT")

-- Debuff fresh -> should NOT match
action_calls = {}
local ctx_mf_fresh = {
    target = { _debuff_remains = 10 },
    has_valid_enemy_target = true,
    ttd = 60,
}
assert_false(moonfire.matches(ctx_mf_fresh, { moonfire_remains = 10 }), "Moonfire should not match when debuff is fresh")
assert_eq(#action_calls, 0, "action_matches should not be called when debuff fresh")

-- Debuff expiring -> should match
action_calls = {}
local ctx_mf_refresh = {
    target = { _debuff_remains = 1 },
    has_valid_enemy_target = true,
    ttd = 60,
}
assert_true(moonfire.matches(ctx_mf_refresh, { moonfire_remains = 1, spell_damage = 800 }), "Moonfire should match when debuff needs refresh")

-- ============================================================================
-- Faerie Fire: only when debuff absent/expiring (> 4 sec) and spell ready
-- ============================================================================

local faerie_fire = find_strategy("FaerieFireDebuff")

-- Debuff fresh -> should NOT match
action_calls = {}
local ctx_ff_fresh = {
    target = { _debuff_remains = 10 },
    has_valid_enemy_target = true,
    target_armor = 5000,
}
assert_false(faerie_fire.matches(ctx_ff_fresh, { ff_remains = 10 }), "FaerieFire should not match when debuff > 4 sec")
assert_eq(#action_calls, 0, "action_matches should not be called when debuff fresh")

-- Debuff low -> should match
action_calls = {}
local ctx_ff_low = {
    target = { _debuff_remains = 1 },
    has_valid_enemy_target = true,
    target_armor = 5000,
}
assert_true(faerie_fire.matches(ctx_ff_low, { ff_remains = 1 }), "FaerieFire should match when debuff <= 4 sec")
assert_eq(spell_ready_calls[#spell_ready_calls].spell, "FaerieFire", "Balance should use caster Faerie Fire, not Feral Faerie Fire")

-- No target -> should return false
assert_false(faerie_fire.matches({}, {}), "FaerieFire should not match when target is nil")

-- ============================================================================
-- Innervate: only in combat and mana <= 30%
-- ============================================================================

local innervate = find_strategy("InnervateSelf")

-- High mana -> should NOT match
action_calls = {}
local ctx_inn_high = {
    in_combat = true,
    mana_pct = 50,
}
assert_false(innervate.matches(ctx_inn_high, { innervate_ready = true }), "Innervate should not match when mana > 30%")
assert_eq(#action_calls, 0, "action_matches should not be called when mana high")

-- Low mana, in combat -> should match
action_calls = {}
spell_ready_calls = {}
local ctx_inn_low = {
    in_combat = true,
    mana_pct = 20,
}
assert_true(innervate.matches(ctx_inn_low, { innervate_ready = true, innervate_target = "self" }), "Innervate should match when mana <= 30% and in combat")

-- Out of combat -> should NOT match
action_calls = {}
assert_false(innervate.matches(ctx_inn_ooc, { innervate_ready = true, innervate_target = "self" }), "Innervate should not match when OOC")

-- Out of combat -> should NOT match for non-self target
action_calls = {}
assert_false(innervate.matches(ctx_inn_ooc, { innervate_ready = true, innervate_target = "other" }), "Innervate should not match when OOC and target is another player")

-- ============================================================================
-- Starfire: only when not moving and mana >= 15%
-- ============================================================================

local starfire = find_strategy("StarfirePrimary")

-- Moving -> should NOT match
action_calls = {}
local ctx_sf_move = {
    is_moving = true,
    mana_pct = 50,
    target = {},
    has_valid_enemy_target = true,
}
assert_false(starfire.matches(ctx_sf_move, {}), "Starfire should not match when moving")
assert_eq(#action_calls, 0, "action_matches should not be called when moving")

-- Low mana -> should NOT match
action_calls = {}
local ctx_sf_low = {
    is_moving = false,
    mana_pct = 10,
    target = {},
    has_valid_enemy_target = true,
}
assert_false(starfire.matches(ctx_sf_low, {}), "Starfire should not match when mana < 15%")
assert_eq(#action_calls, 0, "action_matches should not be called when mana low")

-- Not moving, mana OK -> should match
action_calls = {}
local ctx_sf_ok = {
    is_moving = false,
    mana_pct = 50,
    target = {},
    has_valid_enemy_target = true,
}
assert_true(starfire.matches(ctx_sf_ok, {}), "Starfire should match when not moving and mana >= 15%")

action_calls = {}
assert_true(starfire.execute(ctx_sf_ok, {}), "Starfire execute should call try_cast")
assert_eq(#action_calls, 1, "Starfire execute should call try_cast once")
assert_eq(action_calls[1].spell, "Starfire", "Starfire execute should pass the Starfire spell")

-- ============================================================================
-- Wrath: only when not moving
-- ============================================================================

local wrath = find_strategy("WrathFiller")

-- Moving -> should NOT match
action_calls = {}
local ctx_wr_move = {
    is_moving = true,
    target = {},
    has_valid_enemy_target = true,
}
assert_false(wrath.matches(ctx_wr_move, {}), "Wrath should not match when moving")
assert_eq(#action_calls, 0, "action_matches should not be called when moving")

-- Not moving -> should match
action_calls = {}
local ctx_wr_ok = {
    is_moving = false,
    target = {},
    has_valid_enemy_target = true,
}
assert_true(wrath.matches(ctx_wr_ok, {}), "Wrath should match when not moving")

action_calls = {}
assert_true(wrath.execute(ctx_wr_ok, {}), "Wrath execute should call try_cast")
assert_eq(#action_calls, 1, "Wrath execute should call try_cast once")
assert_eq(action_calls[1].spell, "Wrath", "Wrath execute should pass the Wrath spell")

-- ============================================================================
-- Hurricane: only when not moving and 3+ enemies
-- ============================================================================

local hurricane = find_strategy("HurricaneAoE")

-- Moving -> should NOT match
action_calls = {}
local ctx_hur_move = {
    is_moving = true,
    enemy_count = 5,
    target = {},
}
assert_false(hurricane.matches(ctx_hur_move, {}), "Hurricane should not match when moving")
assert_eq(#action_calls, 0, "action_matches should not be called when moving")

-- Too few enemies -> should NOT match
action_calls = {}
local ctx_hur_few = {
    is_moving = false,
    enemy_count = 2,
    target = {},
}
assert_false(hurricane.matches(ctx_hur_few, {}), "Hurricane should not match with < 3 enemies")
assert_eq(#action_calls, 0, "action_matches should not be called with < 3 enemies")

-- 3+ enemies, not moving, Barkskin active -> should match
action_calls = {}
local ctx_hur_ok = {
    is_moving = false,
    enemy_count = 4,
    target = {},
}
assert_true(hurricane.matches(ctx_hur_ok, { barkskin_active = true }), "Hurricane should match with >= 3 enemies, not moving, and Barkskin active")

-- ============================================================================
-- Force of Nature: only in combat and should_burst
-- ============================================================================

local fon = find_strategy("ForceOfNature")

-- Not in combat -> should NOT match
action_calls = {}
local ctx_fon_ooc = {
    in_combat = false,
    should_burst = true,
}
assert_false(fon.matches(ctx_fon_ooc, {}), "ForceOfNature should not match when OOC")

-- In combat but no burst -> should NOT match
action_calls = {}
local ctx_fon_no_burst = {
    in_combat = true,
    should_burst = false,
}
assert_false(fon.matches(ctx_fon_no_burst, {}), "ForceOfNature should not match when not bursting")

-- In combat and burst -> should match
action_calls = {}
spell_ready_calls = {}
local ctx_fon_burst = {
    in_combat = true,
    should_burst = true,
}
assert_true(fon.matches(ctx_fon_burst, {}), "ForceOfNature should match when in combat and bursting")

-- ============================================================================
-- Barkskin: only when HP <= 55
-- ============================================================================

local barkskin = find_strategy("BarkskinDefense")

-- High HP -> should NOT match
action_calls = {}
local ctx_bs_high = {
    hp = 70,
}
assert_false(barkskin.matches(ctx_bs_high, {}), "Barkskin should not match when HP > 55")

-- Low HP -> should match
action_calls = {}
local ctx_bs_low = {
    hp = 40,
}
assert_true(barkskin.matches(ctx_bs_low, {}), "Barkskin should match when HP <= 40 (default threshold)")

-- ============================================================================
-- Thorns: only OOC and buff not recently applied
-- ============================================================================

local thorns = find_strategy("ThornsBuff")

-- In combat -> should NOT match
action_calls = {}
local ctx_thorns_combat = {
    in_combat = true,
}
assert_false(thorns.matches(ctx_thorns_combat, { thorns_remains = 0 }), "Thorns should not match in combat")

print("PASS test_balance_custom_matches")
