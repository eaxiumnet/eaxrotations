-- unit tests for arcane_sylvanas custom matches functions.

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
local buff_stacks_calls = {}
_G.EaxRotations = {
    MageSpells = {
        ArcaneBlast = 30451,
        ArcaneMissiles = 5143,
        FireBlast = 2136,
        Evocation = 12051,
        Counterspell = 2139,
        Polymorph = 118,
        FrostNova = 122,
        Slow = 31589,
        ManaGem = 27103,
        PresenceOfMind = 12043,
        ArcanePower = 12042,
        Fireball = 133,
        Frostbolt = 116,
    },
    PLAYER_UNIT = {},
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    spell_exists = function(spell)
        return spell ~= 30451
    end,
    gate_cooldown_boss_only = function() return true end,
    spell_ready = function()
        return true
    end,
    buff_stacks = function(me, buff_list)
        buff_stacks_calls[#buff_stacks_calls + 1] = { me = me, buff = buff_list }
        return me and me._ab_stacks or 0
    end,
    buff_remains = function(me, buff_list)
        return 0
    end,
    debuff_remains = function()
        return 0
    end,
    has_player_buff = function(buff_list)
        return false
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/mage/arcane_sylvanas.lua").strategies
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

local target = {}

local function me_at(distance)
    return {
        get_distance = function()
            return distance
        end,
    }
end

local function state(overrides)
    local s = {
        phase = "burn",
        ab_stacks = 0,
        ab_remains = 0,
        has_arcane_power = false,
        has_presence_of_mind = false,
        has_ice_barrier = false,
        has_mana_shield = false,
        mana_pct = 50,
        hp_pct = 100,
        in_combat = true,
        is_moving = false,
        target_casting = false,
        mana_gem_available = true,
        evocation_available = true,
        arcane_power_available = false,
        bloodlust_active = false,
    }
    if overrides then
        for k, v in pairs(overrides) do
            s[k] = v
        end
    end
    return s
end

-- ============================================================================
-- Arcane Blast: only when not moving and mana >= AB_STACK_DROP_THRESHOLD (8%)
-- ============================================================================

local ab = find_strategy("ArcaneBlast")

-- Moving -> should NOT match
action_calls = {}
assert_false(ab.matches({ target = target }, state({ is_moving = true, mana_pct = 50, ab_stacks = 0 })), "ArcaneBlast should not match when moving")
assert_eq(#action_calls, 0, "action_matches should not be called when moving")

-- Low mana -> should NOT match
action_calls = {}
assert_false(ab.matches({ target = target }, state({ is_moving = false, mana_pct = 5, ab_stacks = 2 })), "ArcaneBlast should not match when mana is critical")

-- Not moving, mana OK -> should match
action_calls = {}
assert_true(ab.matches({ target = target }, state({ is_moving = false, mana_pct = 50, ab_stacks = 2 })), "ArcaneBlast should match when not moving and mana OK")

-- ============================================================================
-- Arcane Missiles: Clearcasting consumer only (wowsims-aligned)
-- ============================================================================

local am = find_strategy("ArcaneMissiles")

-- Moving -> should NOT match (channel)
action_calls = {}
assert_false(am.matches({ target = target }, state({ is_moving = true, mana_pct = 50, ab_stacks = 0 })), "ArcaneMissiles should not match when moving")
assert_eq(#action_calls, 0, "action_matches should not be called when moving")

-- Clearcasting -> should match
action_calls = {}
assert_true(am.matches({ target = target }, state({ phase = "conserve", is_moving = false, mana_pct = 50, ab_stacks = 1, has_clearcasting = true })), "ArcaneMissiles should match with Clearcasting")

-- Conserve phase without Clearcasting -> should NOT match (Frostbolt fills)
action_calls = {}
assert_false(am.matches({ target = target }, state({ phase = "conserve", is_moving = false, mana_pct = 50, ab_stacks = 1 })), "ArcaneMissiles should not match as conserve filler without Clearcasting")

-- Burn phase with enough mana -> should NOT match
action_calls = {}
assert_false(am.matches({ target = target }, state({ phase = "burn", is_moving = false, mana_pct = 50, ab_stacks = 3 })), "ArcaneMissiles should not match during healthy burn")

-- ============================================================================
-- Fire Blast: instant filler when moving or AB stacks maxed
-- ============================================================================

local fb = find_strategy("FireBlast")

-- Should match
action_calls = {}
assert_true(fb.matches({ target = target }, state({ is_moving = true, mana_pct = 50, ab_stacks = 3 })), "FireBlast should match")

-- ============================================================================
-- PvP control: CC, peel, slow (Counterspell removed — handled by interrupt_manager)
-- ============================================================================

local polymorph = find_strategy("Polymorph")

action_calls = {}
assert_false(polymorph.matches({ is_pvp = false, cc_target = {} }, state()), "Polymorph should require PvP")
assert_eq(#action_calls, 0, "Polymorph should fail before action gate outside PvP")

action_calls = {}
assert_false(polymorph.matches({ is_pvp = true, is_moving = true, cc_target = {} }, state()), "Polymorph should not match while moving")
assert_eq(#action_calls, 0, "Polymorph should fail before action gate while moving")

action_calls = {}
assert_true(polymorph.matches({ is_pvp = true, is_moving = false, cc_target = {} }, state()), "Polymorph should match in PvP with cc_target")

local frost_nova = find_strategy("FrostNova")

action_calls = {}
assert_false(frost_nova.matches({ is_pvp = true, target = target, me = me_at(14) }, state()), "FrostNova should not match when target is far")
assert_eq(#action_calls, 0, "FrostNova should fail before action gate when far")

action_calls = {}
assert_true(frost_nova.matches({ is_pvp = true, target = target, me = me_at(8) }, state()), "FrostNova should match close PvP target")

local slow = find_strategy("Slow")

action_calls = {}
assert_false(slow.matches({ is_pvp = true, target = target, me = me_at(5) }, state()), "Slow should not match close target")
assert_eq(#action_calls, 0, "Slow should fail before action gate when close")

action_calls = {}
assert_true(slow.matches({ is_pvp = true, target = target, me = me_at(20) }, state()), "Slow should match ranged PvP target")

-- ============================================================================
-- Evocation: only in combat and mana below threshold
-- ============================================================================

local evo = find_strategy("Evocation")

-- Not in combat -> should NOT match
action_calls = {}
assert_false(evo.matches({}, state({ in_combat = false, mana_pct = 10 })), "Evocation should not match when OOC")

-- High mana -> should NOT match
action_calls = {}
assert_false(evo.matches({}, state({ in_combat = true, mana_pct = 50, phase = "burn" })), "Evocation should not match when mana is high")

-- Low mana, in combat -> should match
action_calls = {}
assert_true(evo.matches({}, state({ in_combat = true, mana_pct = 15 })), "Evocation should match when mana <= threshold and in combat")

-- Conserve recovery threshold -> should match
action_calls = {}
assert_true(evo.matches({}, state({ in_combat = true, mana_pct = 30, phase = "conserve" })), "Evocation should match conserve recovery threshold")

-- ============================================================================
-- Mana Gem: burn threshold or conserve recovery
-- ============================================================================

local mana_gem = find_strategy("ManaGem")

-- High mana (near full, gem wouldn't help) -> should NOT match
action_calls = {}
assert_false(mana_gem.matches({}, state({ phase = "burn", mana_pct = 95, max_mana = 10000, current_mana = 9500, mana_gem_available = true })), "ManaGem should not match when mana is near full")

-- Unavailable -> should NOT match
action_calls = {}
assert_false(mana_gem.matches({}, state({ phase = "burn", mana_pct = 50, mana_gem_available = false })), "ManaGem should not match when unavailable")

-- Wowsims-aligned: mana gap exceeds gem restore -> should match
action_calls = {}
assert_true(mana_gem.matches({}, state({ phase = "burn", mana_pct = 50, max_mana = 10000, current_mana = 5000, mana_gem_available = true })), "ManaGem should match when mana gap exceeds gem restore")

-- Old fallback: below mana_pct threshold -> should match
action_calls = {}
assert_true(mana_gem.matches({}, state({ phase = "burn", mana_pct = 50, mana_gem_available = true })), "ManaGem should match when burn mana is below threshold")

-- ============================================================================
-- Presence of Mind: burn/bloodlust cooldown
-- ============================================================================

local pom = find_strategy("PresenceOfMind")

-- No burst, not moving -> should NOT match
action_calls = {}
assert_false(pom.matches({}, state({ phase = "conserve", is_moving = false })), "PoM should not match outside burn/bloodlust")

-- Burn window, AP on CD -> should match
action_calls = {}
assert_true(pom.matches({}, state({ phase = "burn", is_moving = false, arcane_power_available = false })), "PoM should match during burn with AP on CD")

-- Burn window, AP available -> should NOT match
action_calls = {}
assert_false(pom.matches({}, state({ phase = "burn", is_moving = false, arcane_power_available = true })), "PoM should not match when AP is available")

-- Burn window, AP active -> should match
action_calls = {}
assert_true(pom.matches({}, state({ phase = "burn", is_moving = false, has_arcane_power = true })), "PoM should match when AP is already active")

-- Moving only still requires burn/bloodlust
action_calls = {}
assert_false(pom.matches({}, state({ phase = "conserve", is_moving = true })), "PoM should not match just because the player is moving")

-- ============================================================================
-- Arcane Power: burn/bloodlust cooldown with sufficient mana
-- ============================================================================

local ap = find_strategy("ArcanePower")

-- Low mana -> should NOT match
action_calls = {}
assert_false(ap.matches({}, state({ phase = "burn", mana_pct = 30, ab_stacks = 2 })), "ArcanePower should not match when mana < 35%")

-- Sufficient mana outside burn -> should NOT match
action_calls = {}
assert_false(ap.matches({}, state({ phase = "conserve", mana_pct = 50, ab_stacks = 0 })), "ArcanePower should not match outside burn")

-- Sufficient mana, stacks >= 2 in burn -> should match
action_calls = {}
assert_true(ap.matches({}, state({ phase = "burn", mana_pct = 50, ab_stacks = 2 })), "ArcanePower should match with >= 2 AB stacks during burn")

-- Sufficient mana in burn -> should match
action_calls = {}
assert_true(ap.matches({}, state({ phase = "burn", mana_pct = 50, ab_stacks = 0 })), "ArcanePower should match during burn")

-- ============================================================================
-- Leveling fallback: Arcane before Arcane Blast is learned
-- ============================================================================

local fireball = find_strategy("FireballLeveling")
local frostbolt = find_strategy("FrostboltLeveling")

action_calls = {}
assert_true(fireball.matches({ is_leveling = true }, state({ is_moving = false })), "FireballLeveling should match while leveling without Arcane Blast")

action_calls = {}
assert_false(frostbolt.matches({ is_leveling = true }, state({ is_moving = true })), "FrostboltLeveling should not match while moving")

print("PASS test_arcane_custom_matches")
