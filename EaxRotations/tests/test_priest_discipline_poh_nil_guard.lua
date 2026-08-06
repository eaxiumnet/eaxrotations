-- test_priest_discipline_poh_nil_guard.lua — regression for the PrayerOfHealing /
-- InnerFocus nil-vs-number crash found by the behavioral battery audit (2026-08-06).
-- WHAT:  matchers must not crash when party_injured_count / subgroup_damaged_count /
--        group_damaged_count are nil (build_state early-return path); they must
--        silently gate (count defaults to 0) per Pattern 14.
-- WHEN:  rotation suite execution.
-- WHY:   behavioral_audit.lua surfaced "attempt to compare nil with number" at
--        discipline_sylvanas.lua:458 in every scenario (PrayerOfHealing).
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local result, err = aud.load_spec("priest", "discipline")
assert_true(result ~= nil, "discipline load failed: " .. tostring(err))

local function find_strategy(name)
    for _, s in ipairs(result.strategies) do
        if s.name == name then return s end
    end
    return nil
end

local prayer = find_strategy("PrayerOfHealing")
local inner = find_strategy("InnerFocus")
assert_true(prayer ~= nil, "PrayerOfHealing strategy missing")
assert_true(inner ~= nil, "InnerFocus strategy missing")

local ctx = {
    me = {},
    target = {},
    in_combat = true,
    is_moving = false,
    mana_pct = 90,
    has_valid_enemy_target = true,
    settings = {},
}

-- Reproduce: state where the group-damage counts are ABSENT (early-return build
-- path). Before the fix, `nil < 4` crashed the matcher.
local state_no_counts = {
    mana_pct = 90,
    prayer_of_healing_ready = true,
    inner_focus_ready = true,
    has_inner_focus = false,
    tank = { unit = {}, effective_hp = 100 },
    lowest = { unit = {}, effective_hp = 60 },
}

local ok_poh, m_poh = pcall(prayer.matches, ctx, state_no_counts)
assert_true(ok_poh, "PrayerOfHealing matcher must not crash on missing count fields (nil-vs-number)")
assert_true(m_poh == false, "PrayerOfHealing must gate out when no injured count is known (default 0 < 4)")

local ok_if, m_if = pcall(inner.matches, ctx, state_no_counts)
assert_true(ok_if, "InnerFocus matcher must not crash on missing group_damaged_count (nil-vs-number)")

-- Sanity: when counts ARE present and sufficient, the matchers proceed to the
-- next gate instead of early-gating on count.
local state_with_counts = {
    mana_pct = 90,
    prayer_of_healing_ready = true,
    party_injured_count = 4,
    lowest = { unit = {}, effective_hp = 60 },
}
local ok2, m2 = pcall(prayer.matches, ctx, state_with_counts)
assert_true(ok2, "PrayerOfHealing matcher crashed with counts present")
assert_true(m2 == true, "PrayerOfHealing should proceed when count >= 4 and heal ready")

print("PASS: discipline PrayerOfHealing/InnerFocus nil-count guard regression (2 matchers)")
