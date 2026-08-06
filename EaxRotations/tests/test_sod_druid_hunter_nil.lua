-- test_sod_druid_hunter_nil.lua -- Adversarial Druid and Hunter SoD gates.
-- WHAT: probes nil, malformed, stale, missing-rune, and legacy runtime inputs.
-- WHEN: Task 4 failure-path validation for all five native SoD modules.
-- WHY: ensures uncertain host state skips actions instead of enabling them or crashing.
-- SAFETY: isolated deterministic stubs with fail-closed assertions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

_G.EaxRotations = {
    is_sod = function() return true end,
    DruidSpells = {}, HunterSpells = {},
    rotation_registry = { register = function() end },
    spell_action = function(ids) return { _meta = { id = type(ids) == "table" and ids[1] or ids } } end,
    spell_ready = function() return true end,
    buff_up = function() return false end, buff_remains = function() return 0 end,
    debuff_up = function() return false end, debuff_remains = function() return 0 end,
    try_cast = function() return true end,
}

local paths = {
    "classes/druid/balance_sod", "classes/druid/feral_sod", "classes/druid/tank_sod",
    "classes/druid/restoration_sod", "classes/hunter/dps_hunter_sod",
}
local modules = {}
for i = 1, #paths do
    package.loaded[paths[i]] = nil
    modules[i] = assert(require(paths[i]))
end

local function strategy(module, name)
    for i = 1, #module.strategies do
        if module.strategies[i].name == name then return module.strategies[i] end
    end
    error("missing strategy: " .. name, 2)
end

local function no_match(module, context)
    local ok, state = pcall(module.build_state, context)
    assert_eq(ok, true, "nil-safe build_state")
    for i = 1, #module.strategies do
        local matched, value = pcall(module.strategies[i].matches, context, state)
        assert_eq(matched, true, "nil-safe matches " .. module.strategies[i].name)
        if value then return false end
    end
    return true
end

for i = 1, #modules do
    assert_eq(no_match(modules[i], nil), true, paths[i] .. " nil context skips")
    assert_eq(no_match(modules[i], { is_sod = false, target = {}, me = {} }), true,
        paths[i] .. " legacy context skips")
    assert_eq(no_match(modules[i], {
        is_sod = true, sod_phase = "phase 7", sod_runes = {}, target = {}, me = {},
    }), true, paths[i] .. " malformed phase skips")
end

local balance = modules[1]
local stale = {
    is_sod = true, sod_phase = 7, sod_runes = {}, target = {}, me = {},
    has_starsurge_aura = true,
}
local state = balance.build_state(stale)
state.has_starsurge_aura = false
assert_eq(balance.strategies[1].matches(stale, state), false,
    "stale positive state cannot bypass missing Starsurge rune")

local equipped = {
    [407995] = true, [414644] = true, [417157] = true,
    [409433] = true, [409593] = true,
}
local out_of_combat = {
    is_sod = true, sod_phase = 7, sod_runes = equipped, target = {}, me = {},
    in_combat = false, pet = {}, pet_alive = true, pet_hp_pct = 100,
}
assert_eq(no_match(modules[1], out_of_combat), true, "Balance skips out of combat")
assert_eq(no_match(modules[2], out_of_combat), true, "Feral skips out of combat")
assert_eq(no_match(modules[3], out_of_combat), true, "Tank skips out of combat")
assert_eq(no_match(modules[5], out_of_combat), true, "Hunter offense skips out of combat")

local wrong_form = {
    is_sod = true, sod_phase = 7, sod_runes = equipped, target = {}, me = {},
    in_combat = true, in_cat_form = false, in_bear_form = false,
}
assert_eq(strategy(modules[2], "Mangle").matches(wrong_form, modules[2].build_state(wrong_form)),
    false, "cat action requires Cat Form")
assert_eq(strategy(modules[3], "Lacerate").matches(wrong_form, modules[3].build_state(wrong_form)),
    false, "tank action requires Bear Form")
assert_eq(strategy(modules[5], "MendPet").matches(wrong_form, modules[5].build_state(wrong_form)),
    false, "pet heal requires a living pet")

print("PASS test_sod_druid_hunter_nil (nil/malformed/legacy/missing-rune fail closed)")
