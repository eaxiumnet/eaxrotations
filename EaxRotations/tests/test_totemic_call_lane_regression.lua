-- test_totemic_call_lane_regression.lua — pins the lane unblocked by the
-- campaign follow-up (2026-08-08):
--   shaman/enhancement  TotemicCall  (totem_far scenario)
-- WHAT:  investigation of the shaman totem-recall scan (enh:1225-1277)
--        established the REAL get_position contract: ONE vec3 TABLE {x,y,z}
--        (with [1]/[2] index aliases) — verified vs shared/auto_loot
--        (p.x,p.y,p.z), shared/targeting (pos.x,pos.y,pos.z) and EaxESP
--        (base.x or base[1]). So the matcher's table-form my_pos.x reads are
--        CORRECT — NOT a truncation bug. The truncation-family bug was the
--        OTHER direction: prot's party scan + Intervene matcher captured
--        multi-values (dy/ay = nil against a table API) and were dead in live
--        play; both now read the table fields (protection:426-448, 767-780).
--        behavioral_audit.lua: (a) me/friend mocks return a vec3 table,
--        (b) ns.core gains a scenario-aware time()/get_totem_info()/
--        get_visible_objects() (enh caches NS.core at load time), (c) the
--        visible-enemies builder appends a far totem mock (get_owner +
--        get_position vec3 (30,30) = 1800 sq > 400 yd-sq gate) when the
--        totem_far override is set, (d) enemy mocks gain get_owner() -> nil
--        (the scan calls obj:get_owner() unconditionally), and (e) the
--        totem_far scenario ({ totem_active, totem_far, visible_enemies }).
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide this lane or regress
--        the vec3 contract; this test fails on either.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

-- ============================================================================
-- End-to-end: enh TotemicCall must not be never-firing and must fire ONLY in
-- totem_far.
-- ============================================================================
local report = aud.run_spec("shaman", "enhancement")
assert_true(report ~= nil, "battery run for shaman/enhancement failed")
assert_true(#report.dispatch_errors == 0,
    "shaman/enhancement battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))

local is_never = false
for _, name in ipairs(report.never) do
    if name == "TotemicCall" then is_never = true end
end
assert_true(not is_never, "battery still reports shaman/enhancement TotemicCall as never-firing")

local fi = report.fires_in["TotemicCall"]
assert_true(type(fi) == "table" and fi["totem_far"] == true,
    "shaman/enhancement TotemicCall must fire in the totem_far scenario")
local count = 0
for _ in pairs(fi) do count = count + 1 end
assert_true(count == 1,
    "shaman/enhancement TotemicCall must fire ONLY in totem_far, got " .. count .. " scenarios")
print("PASS: end-to-end battery check (TotemicCall exclusive to totem_far)")

-- ============================================================================
-- vec3 contract pins: the me mock returns ONE table with x/y (+ [1]/[2]).
-- ============================================================================
local result, load_err, ns = aud.load_spec("shaman", "enhancement")
assert_true(result ~= nil, "load shaman/enhancement failed: " .. tostring(load_err))
local function scenario_by_name(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
end
local function strategy_by_name(strats, name)
    for _, s in ipairs(strats) do
        if s.name == name then return s end
    end
end

local scen = scenario_by_name("totem_far")
assert_true(scen ~= nil, "totem_far scenario missing")
local ctx = aud.build_context_for("shaman", scen)
aud.apply_battery_state(ns, ctx, "shaman")
assert_true(ctx.totem_active == true, "ctx.totem_active must be true in totem_far")
assert_true(ctx.totem_far == true, "ctx.totem_far must be true in totem_far")

-- vec3 contract: get_position returns one table with x/y fields.
local me_pos = ctx.me.get_position and ctx.me:get_position()
assert_true(type(me_pos) == "table" and me_pos.x == 0 and me_pos.y == 0,
    "me:get_position() must return a vec3 table {x,y} (contract fix)")

-- Mechanism: get_totem_info stub reads the bank -> have_totem; visible scan
-- includes a distant totem object.
local info = ns.core.spell_book.get_totem_info(1)
assert_true(info ~= nil and info.have_totem == true,
    "get_totem_info must report have_totem when totem_active is set")
local objs = ns.core.object_manager.get_visible_objects()
assert_true(type(objs) == "table" and #objs >= 2,
    "visible scan must include the totem object alongside the enemy mocks")
local far_totem
for _, o in ipairs(objs) do
    if o.get_owner and o.get_owner() ~= nil then far_totem = o end
end
assert_true(far_totem ~= nil, "visible scan must contain a totem object with an owner")
local tpos = far_totem.get_position and far_totem:get_position()
assert_true(tpos ~= nil and tpos.x == 30 and tpos.y == 30,
    "totem mock must sit at vec3 (30, 30) — beyond the 20 yd recall gate")

local strat = strategy_by_name(result.strategies or result, "TotemicCall")
assert_true(strat ~= nil, "enhancement TotemicCall strategy not found")
-- The matcher reads module-level enh_state.totemic_call_ready (populated by
-- build_state) and a module-level scan-result cache; run build_state first so
-- both reflect this scenario.
local st = result.build_state(ctx)
assert_true(st.totemic_call_ready == true, "totemic_call_ready must be true (spell_ready stub)")
local ok_m, m = pcall(strat.matches, ctx, st)
assert_true(ok_m and m, "shaman/enhancement TotemicCall must match in totem_far context")
print("PASS: mechanism pins (totem_active + far totem object + vec3 contract -> match)")

-- ============================================================================
-- Sharp negatives: totem present but NO far object -> no recall; no totem at
-- all -> has_totem gate blocks.
-- ============================================================================
-- (a) totem_active without totem_far: visible list = enemy mocks only.
local ctxA = aud.build_context_for("shaman", {
    name = "totem_near", overrides = { totem_active = true, visible_enemies = true },
})
aud.apply_battery_state(ns, ctxA, "shaman")
local stA = result.build_state(ctxA)
local okA, mA = pcall(strat.matches, ctxA, stA)
assert_true(okA and not mA, "TotemicCall must NOT match with a totem but no far object")

-- (b) no totem at all (standard): has_totem gate blocks before the scan.
local ctxB = aud.build_context_for("shaman", scenario_by_name("standard"))
aud.apply_battery_state(ns, ctxB, "shaman")
local stB = result.build_state(ctxB)
local okB, mB = pcall(strat.matches, ctxB, stB)
assert_true(okB and not mB, "TotemicCall must NOT match without any totem active")
print("PASS: sharp negatives (no far object / no totem both block)")

-- ============================================================================
-- Cross-spec consistency: prot Intervene still fires under the vec3 contract,
-- and elemental's TotemicCall (a DIFFERENT matcher: moving + has_totems) fires
-- ONLY in its own elem_totemic_call scenario — never in enh's totem_far
-- (elemental was cleared by the (c) batch-2 campaign, 2026-08-09).
-- ============================================================================
local rp = aud.run_spec("warrior", "protection")
assert_true(rp.fires_in["Intervene"] and rp.fires_in["Intervene"]["group_ally_low"],
    "prot Intervene must still fire in group_ally_low under the vec3 contract")
local re = aud.run_spec("shaman", "elemental")
local elem_tc = re.fires_in["TotemicCall"]
assert_true(type(elem_tc) == "table" and elem_tc["elem_totemic_call"] == true,
    "elemental TotemicCall must fire in its own elem_totemic_call scenario (batch-2 clear)")
assert_true(elem_tc["totem_far"] == nil,
    "elemental TotemicCall must NOT fire in enh's totem_far scenario (different matcher)")
local ec = 0
for _ in pairs(elem_tc) do ec = ec + 1 end
assert_true(ec == 1,
    "elemental TotemicCall must fire ONLY in elem_totemic_call, got " .. ec .. " scenarios")
print("PASS: cross-spec consistency (Intervene intact; elemental TotemicCall exclusive to elem_totemic_call)")

print("ALL PASS: test_totemic_call_lane_regression")
