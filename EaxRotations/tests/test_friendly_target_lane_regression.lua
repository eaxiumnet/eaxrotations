-- test_friendly_target_lane_regression.lua — pins the lanes unblocked by the
-- campaign ranked-(b) top fixture (2026-08-08):
--   priest/discipline, priest/holy, paladin/holy, druid/resto,
--   shaman/restoration  FriendlyTarget  (friendly_target scenario)
-- WHAT:  behavioral_audit.lua makes ns.get_friendly_target_entry scenario-aware
--        (core/units.lua:129 contract — { unit, hp_pct, effective_hp,
--        is_player } of the current target when friendly). Previously stubbed
--        to always return nil, so every healer spec's FriendlyTarget lane was
--        battery-dead. The friendly_target scenario sets
--        { friendly_target_hp = 60 } (below the 90% threshold; group healthy
--        so spot-heals don't steal the frame). The stub is keyed on
--        friendly_target_hp ALONE (a number is non-nil only when the scenario
--        sets it) — deliberately not a boolean, which would collide with
--        healing_sylvanas.lua:454 reading context.friendly_target as a UNIT.
--        It returns a friendly _friend(60, 30) entry only when the hp is set;
--        hostile/default targets never produce an entry.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these 5 lanes; this test
--        fails if FriendlyTarget stops firing in friendly_target or leaks into
--        another scenario.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

-- ============================================================================
-- End-to-end: FriendlyTarget must not be never-firing in ANY of the 5 healer
-- specs, and must fire ONLY in the friendly_target scenario in each.
-- ============================================================================
local SPECS = {
    { "priest", "discipline" },
    { "priest", "holy" },
    { "paladin", "holy" },
    { "druid", "resto" },
    { "shaman", "restoration" },
}
for _, spec in ipairs(SPECS) do
    local report = aud.run_spec(spec[1], spec[2])
    assert_true(report ~= nil, "battery run for " .. spec[1] .. "/" .. spec[2] .. " failed")
    assert_true(#report.dispatch_errors == 0,
        spec[1] .. "/" .. spec[2] .. " battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))

    local is_never = false
    for _, name in ipairs(report.never) do
        if name == "FriendlyTarget" then is_never = true end
    end
    assert_true(not is_never,
        "battery still reports " .. spec[1] .. "/" .. spec[2] .. " FriendlyTarget as never-firing")

    local fi = report.fires_in["FriendlyTarget"]
    assert_true(type(fi) == "table" and fi["friendly_target"] == true,
        spec[1] .. "/" .. spec[2] .. " FriendlyTarget must fire in the friendly_target scenario")
    -- Vanilla sweep (2026-08): the friendly_target_low scenario (added for the
    -- vanilla paladin/priest FriendlyTarget gates: can_help(lowest) +
    -- pushback) also satisfies the TBC matchers' friendly_target_hp < 90 gate,
    -- so 4 of the 5 specs legitimately fire in BOTH scenarios; discipline's
    -- matcher keeps it exclusive. The pins assert the exact current set.
    local count = 0
    for k in pairs(fi) do
        assert_true(k == "friendly_target" or k == "friendly_target_low",
            spec[1] .. "/" .. spec[2] .. " FriendlyTarget leaked into scenario " .. k)
        count = count + 1
    end
    local expected = (spec[1] == "priest" and spec[2] == "discipline") and 1 or 2
    assert_true(count == expected,
        spec[1] .. "/" .. spec[2] .. " FriendlyTarget fired in " .. count
        .. " scenarios, expected exactly " .. expected)
    print("PASS: end-to-end battery check (" .. spec[1] .. " FriendlyTarget exclusive to friendly_target)")
end

-- ============================================================================
-- Cross-scenario negatives: heal-heavy group scenarios must NOT produce a
-- friendly-target match (no friendly_target flag -> stub returns nil ->
-- friendly_target_ready false).
-- ============================================================================
local rp = aud.run_spec("priest", "holy")
for _, scn in ipairs({ "pushback", "group_emergency", "me_casting", "low_self", "friends_damaged" }) do
    assert_true(not rp.fires_in["FriendlyTarget"][scn],
        "holy FriendlyTarget must NOT fire in " .. scn)
end
print("PASS: cross-scenario negatives (flag-absent scenarios block)")

-- ============================================================================
-- Mechanism pins — the friendly_target context drives FriendlyTarget:
--   1. friendly_target flag -> ns.get_friendly_target_entry returns an entry.
--   2. friendly_target_hp 60 < the 90% threshold (any < 90 value would do).
--   3. Entry shape mirrors core/units.lua ({ unit, hp_pct, effective_hp }).
-- ============================================================================
local result, load_err, ns = aud.load_spec("priest", "discipline")
assert_true(result ~= nil, "load priest/discipline failed: " .. tostring(load_err))
local function scenario_by_name(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    return nil
end
local sc = scenario_by_name("friendly_target")
assert_true(sc ~= nil, "friendly_target scenario must exist in SCENARIOS")
assert_true(sc.overrides.friendly_target_hp == 60 and sc.overrides.friendly_target == nil,
    "friendly_target scenario must set friendly_target_hp 60 and NO friendly_target boolean")

-- Build the exact context the matcher sees (apply_battery_state first, then
-- build_state — the same object the battery dispatches against).
local ctx = aud.build_context_for("priest", sc)
aud.apply_battery_state(ns, ctx, "priest")
assert_true(ns._bstate("friendly_target_hp", nil) == 60,
    "state bank must carry friendly_target_hp=60 after apply_battery_state")

local entry = ns.get_friendly_target_entry(ctx)
assert_true(type(entry) == "table" and entry.unit and type(entry.unit) == "table",
    "get_friendly_target_entry must return { unit, ... } with the hp set")
assert_true(entry.hp_pct == 60 and entry.effective_hp == 60,
    "entry hp_pct/effective_hp must mirror friendly_target_hp (60)")
assert_true(entry.is_player == true, "entry must be flagged as a player unit")

-- Friendly-target hp ABSENT (default scenario) -> stub returns nil.
local ctx2 = aud.build_context_for("priest", aud.SCENARIOS[1])
aud.apply_battery_state(ns, ctx2, "priest") -- standard scenario has no friendly_target_hp override
local default_entry = ns.get_friendly_target_entry(ctx2)
assert_true(default_entry == nil,
    "get_friendly_target_entry must return nil when friendly_target_hp is unset")
print("PASS: mechanism pins (hp -> entry with hp 60; absent hp -> nil)")
