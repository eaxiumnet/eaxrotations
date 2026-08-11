-- test_fury_vanilla_pummel.lua — Vanilla fury Pummel interrupt regression test.
-- WHAT:  Verifies the Pummel interrupt strategy is first in the vanilla fury
--        list, fires only when in combat AND the target is casting AND Pummel
--        is ready, and is silent otherwise.
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   the interrupt-coverage sweep found fury_vanilla computed pummel_ready
--        (fury_vanilla.lua:206) with no strategy consuming it — vanilla fury
--        could never interrupt despite Pummel being baseline. This pins the
--        fix (strategy first, match gates) so it cannot silently regress.
-- SAFETY: standalone — mocks NS, spec_kit, potion_helper, aoe_hit_volume; no
--         game API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local pass_count, test_count = 0, 0

local function assert_true(v, label)
    test_count = test_count + 1
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
    pass_count = pass_count + 1
end

local function assert_false(v, label)
    test_count = test_count + 1
    if v then error("FAIL: " .. (label or "assert_false"), 2) end
    pass_count = pass_count + 1
end

local function assert_eq(a, b, label)
    test_count = test_count + 1
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
    pass_count = pass_count + 1
end

-- -----------------------------------------------------------------------------
-- Mock NS so fury_vanilla.lua loads without the engine.
-- -----------------------------------------------------------------------------
local casts = {}
local mock_spell_ready = true
local registry_opts = {}

_G.EaxRotations = {
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    WarriorSpells = {
        Pummel = { id = 6554, name = "Pummel" },
    },
    PLAYER_UNIT = {
        get_health_percentage = function() return 100 end,
    },
    log = function() end,
    log_warning = function() end,
    GetPlayer = function() return {
        get_health_percentage = function() return 100 end,
    } end,
    spell_action = function(ids, label)
        local id = type(ids) == "table" and ids[1] or ids
        return { id = id, name = label or tostring(id) }
    end,
    spell_ready = function() return mock_spell_ready end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    try_cast = function(spell, target, label) casts[#casts + 1] = label; return true end,
    rotation_registry = { register = function(self, name, strategies, options) registry_opts = options or {} end },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

local fury = dofile("EaxRotations/classes/warrior/fury_vanilla.lua")
assert_true(type(fury) == "table", "fury_vanilla should return the strategies table")
local build_state = registry_opts.get_state
assert_true(type(build_state) == "function", "fury_vanilla should register build_state as get_state")

print("=== test_fury_vanilla_pummel ===")

-- Pummel must be FIRST in the list (interrupt priority, outside the filler order).
assert_eq(fury[1].name, "Pummel", "Pummel must be the first fury_vanilla strategy")

local function casting_target(is_casting)
    return { is_casting = function() return is_casting end }
end

-- Fires when in combat + target casting + Pummel ready (non-vacuity).
local ctx = { in_combat = true, target = casting_target(true) }
local state = build_state(ctx)
assert_true(state.target_casting, "build_state should derive target_casting from target:is_casting()")
assert_true(state.pummel_ready, "pummel_ready should be true when spell_ready is mocked true")
assert_true(fury[1].matches(ctx, state), "Pummel should match when in combat and target is casting")
local ok = fury[1].execute(ctx)
assert_true(ok, "Pummel execute should cast")
assert_true(#casts >= 1 and tostring(casts[1]):find("Pummel", 1, true) ~= nil, "execute should cast Pummel")

-- Silent when the target is NOT casting.
local ctx_not_casting = { in_combat = true, target = casting_target(false) }
state = build_state(ctx_not_casting)
assert_false(state.target_casting, "target_casting should be false when target is not casting")
assert_false(fury[1].matches(ctx_not_casting, state), "Pummel should not match when target is not casting")

-- Silent when out of combat, even with a casting target.
local ctx_ooc = { in_combat = false, target = casting_target(true) }
state = build_state(ctx_ooc)
assert_false(fury[1].matches(ctx_ooc, state), "Pummel should not match out of combat")

-- Silent when Pummel is on cooldown (pummel_ready false).
mock_spell_ready = false
local ctx_ready = { in_combat = true, target = casting_target(true) }
state = build_state(ctx_ready)
assert_false(state.pummel_ready, "pummel_ready should be false when spell_ready returns false")
assert_false(fury[1].matches(ctx_ready, state), "Pummel should not match when on cooldown")
mock_spell_ready = true

print(string.format("PASS test_fury_vanilla_pummel (%d/%d assertions passed)", pass_count, test_count))
