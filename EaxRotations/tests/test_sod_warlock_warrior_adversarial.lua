-- test_sod_warlock_warrior_adversarial.lua -- SoD malformed-input safety probes.
-- WHAT: probes nil, stale, misleading, and long-running role inputs.
-- WHEN: run after the source-priority role contract test.
-- WHY: prevents runtime selection and resource guards from failing open.
-- SAFETY: deterministic mocks only; no live API or external process state.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local registry = { register = function() end }
_G.EaxRotations = {
    is_sod = function() return true end,
    rotation_registry = registry,
    spell_action = function(ids) return { id = type(ids) == "table" and ids[1] or ids } end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
}

local function load_role(path)
    package.loaded[path] = nil
    -- Parens force a single return value: this Lua's require() returns the
    -- module table AND the resolved file path, and a function call in the
    -- last table-constructor slot spreads ALL return values — the stray path
    -- string silently grew `roles` to 5 entries and crashed the inner loop
    -- with "attempt to index a nil value" (slot 5 was a string).
    return (require(path))
end

local roles = {
    load_role("classes/warlock/dps_sod"),
    load_role("classes/warlock/tank_sod"),
    load_role("classes/warrior/dps_warrior_sod"),
    load_role("classes/warrior/tank_warrior_sod"),
}

for _, role in ipairs(roles) do
    for _, candidate in ipairs(role.strategies) do
        local ok, result = pcall(candidate.matches, nil, role.build_state(nil))
        assert_eq(ok, true, "nil context does not throw")
        assert_eq(result, false, "nil context fails closed")
        local stale = {
            is_sod = true, sod_phase = "phase-8", in_combat = true, target = {},
            stance = "defensive", rage = 100, mana_pct = 100, pet = {}, pet_alive = true,
            sod_runes = { [403789] = true, [403629] = true, [412758] = true,
                [402911] = true, [429765] = true, [440488] = true },
        }
        local stale_ok, stale_result = pcall(candidate.matches, stale, role.build_state(stale))
        assert_eq(stale_ok, true, "stale phase does not throw")
        assert_eq(stale_result, false, "stale phase fails closed")
    end
end

local dps = roles[1]
local incinerate = nil
for _, candidate in ipairs(dps.strategies) do
    if candidate.name == "Incinerate" then incinerate = candidate end
end
local misleading_rune = {
    is_sod = true, sod_phase = 8, in_combat = true, target = {},
    sod_runes = { [412758] = "equipped" },
}
assert_eq(incinerate.matches(misleading_rune, dps.build_state(misleading_rune)), false,
    "non-boolean rune claims fail closed")

local warrior_dps = roles[3]
local quick_strike = nil
for _, candidate in ipairs(warrior_dps.strategies) do
    if candidate.name == "QuickStrike" then quick_strike = candidate end
end
local misleading_warrior_rune = {
    is_sod = true, sod_phase = 8, in_combat = true, target = {}, stance = "berserker",
    rage = 80, sod_runes = { [429765] = "equipped" },
}
assert_eq(quick_strike.matches(misleading_warrior_rune,
    warrior_dps.build_state(misleading_warrior_rune)), false,
    "Warrior non-boolean rune claims fail closed")

for i = 1, 10000 do
    local context = {
        is_sod = true, sod_phase = 8, in_combat = true, target = {}, stance = (i % 2 == 0) and "defensive" or "berserker",
        rage = i % 101, mana_pct = i % 101, target_hp_pct = i % 101,
        pet = {}, pet_alive = i % 3 ~= 0, enemy_count = i % 6,
        sod_runes = { [403789] = true, [412758] = true, [429765] = true, [440488] = true },
    }
    for _, role in ipairs(roles) do role.build_state(context) end
end

print("PASS test_sod_warlock_warrior_adversarial (nil/stale/misleading/long probes)")
