-- test_phase3_c_fixture_regression.lua — pins the 9 lanes unblocked by the
-- first batch of Phase 3 (c) mock-limitation fixtures (2026-08-09, non-DPS
-- triage ranked list).
-- WHAT:  behavioral_audit.lua gained five scenarios:
--          readiness_window { on_cd = { [3045] = 61 }, ttd = 60, target_ttd = 60 }
--          serpent_refresh  { debuff_remains_map = { [27016] = 2 }, ttd = 30, target_ttd = 30 }
--          clearcast_surge  { buff_remains_map = { [34753] = 1, [33151] = 1 } }
--          elem_shock_moving { is_moving = true, setting_overrides = { elemental_interrupt_reserve = false } }
--          elem_shock_pvp   { is_moving = true, is_pvp = true }
--        Lanes pinned here (all previously never-firing):
--          hunter Readiness x3 (beast_mastery DSL + marksmanship + survival)
--            — gates on rapid_fire_cd >= 60, which derives from
--            cooldown_remains(RapidFire 3045) — the bank-aware on_cd read.
--          hunter SerpentStingRefresh x2 (beast_mastery + survival)
--            — gates on the serpent debuff (id 27016, max rank) being up with
--            <= 3s remaining via debuff_up/debuff_remains on the PRIMARY
--            target (map-aware) + a ttd floor (survival:420 needs ttd >= 6).
--          priest holy ClearcastingGreaterHeal + SurgeOfLightSmite
--            — gate on per-buff state (HOLY_CONCENTRATION 34753 /
--            SURGE_OF_LIGHT 33151) via has_player_buff, which holy imports
--            through NS.import_helpers at require() time. The import helper
--            now FORWARDS to the map-aware ns.has_player_buff (buff_remains_map)
--            instead of a constant false — a battery-side fix that also lets
--            these lanes fire in the buffs_up family, which is correct (all
--            buffs up implies these buffs up).
--          shaman elemental EarthShockMoving + FrostShockMoving
--            — EarthShockMoving needs is_moving + the elemental_interrupt_reserve
--            setting FALSE (default true); FrostShockMoving needs is_moving +
--            is_pvp. The plain `moving` scenario leaves the reserve on / pvp off.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit (dropping a scenario, changing an override,
--        or regressing the import_helpers forwarding) could silently re-hide
--        these lanes; this test fails if any stops firing (state + matcher +
--        end-to-end never-list).
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local function find_strategy(strategies, name)
    for _, s in ipairs(strategies) do
        if s.name == name then return s end
    end
    return nil
end

local function build_scenario(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

local function make_state(spec_mod, ns, class_key, scenario_name)
    local ctx = aud.build_context_for(class_key, build_scenario(scenario_name))
    aud.apply_battery_state(ns, ctx, class_key)
    if spec_mod.build_state then
        local ok, st = pcall(spec_mod.build_state, ctx)
        assert_true(ok, class_key .. "/" .. scenario_name .. " build_state crashed: " .. tostring(st))
        if type(st) == "table" then return ctx, st end
    end
    return ctx, ctx
end

local function assert_lane_matches(spec_mod, ns, class_key, lane, scenario, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m == true, label)
    return ctx, state
end

-- ============================================================================
-- hunter Readiness x3 — all gate rapid_fire_cd >= 60 (RapidFire 3045 on cd)
-- ============================================================================
local function assert_readiness(spec_key)
    local mod, err, ns = aud.load_spec("hunter", spec_key)
    assert_true(mod ~= nil, "hunter/" .. spec_key .. " load failed: " .. tostring(err))
    _G.EaxRotations = ns
    local ctx, state = assert_lane_matches(mod, ns, "hunter", "Readiness", "readiness_window",
        "hunter/" .. spec_key .. " Readiness must match in readiness_window")
    assert_true((state.rapid_fire_cd or 0) >= 60,
        "hunter/" .. spec_key .. " state.rapid_fire_cd must be >= 60, got " .. tostring(state.rapid_fire_cd))
    assert_true(ctx.ttd == 60 or (ctx.ttd or 0) >= 20,
        "hunter/" .. spec_key .. " Readiness needs a healthy ttd")
end
assert_readiness("beast_mastery")
assert_readiness("marksmanship")
assert_readiness("survival")
print("PASS: hunter Readiness x3 regression (readiness_window rapid_fire_cd >= 60)")

-- ============================================================================
-- hunter SerpentStingRefresh x2 — serpent debuff up with <= 3s remaining
-- ============================================================================
local function assert_serpent_refresh(spec_key)
    local mod, err, ns = aud.load_spec("hunter", spec_key)
    assert_true(mod ~= nil, "hunter/" .. spec_key .. " load failed: " .. tostring(err))
    _G.EaxRotations = ns
    local ctx, state = assert_lane_matches(mod, ns, "hunter", "SerpentStingRefresh", "serpent_refresh",
        "hunter/" .. spec_key .. " SerpentStingRefresh must match in serpent_refresh")
    assert_true(state.has_serpent_sting == true,
        "hunter/" .. spec_key .. " state.has_serpent_sting must be true (debuff map on primary)")
    local rem = ns.debuff_remains and ns.debuff_remains(ctx.target, { 27016 }) or nil
    assert_true(type(rem) == "number" and rem <= 3,
        "hunter/" .. spec_key .. " serpent remains must be <= 3, got " .. tostring(rem))
end
assert_serpent_refresh("beast_mastery")
assert_serpent_refresh("survival")
print("PASS: hunter SerpentStingRefresh x2 regression (serpent_refresh debuff map)")

-- ============================================================================
-- priest holy ClearcastingGreaterHeal + SurgeOfLightSmite — per-buff state
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("priest", "holy")
assert_true(holy ~= nil, "priest/holy load failed: " .. tostring(holy_err))
_G.EaxRotations = holy_ns

local hctx, hstate = assert_lane_matches(holy, holy_ns, "priest", "ClearcastingGreaterHeal",
    "clearcast_surge", "holy ClearcastingGreaterHeal must match in clearcast_surge")
assert_true(hstate.clearcasting == true,
    "holy state.clearcasting must be true (Holy Concentration 34753 map)")
assert_lane_matches(holy, holy_ns, "priest", "SurgeOfLightSmite", "clearcast_surge",
    "holy SurgeOfLightSmite must match in clearcast_surge")
assert_true(hstate.surge_of_light == true,
    "holy state.surge_of_light must be true (Surge of Light 33151 map)")
assert_true((hstate.lowest_hp or 100) < 95 and (hstate.lowest_hp or 0) >= 50,
    "holy per-buff lanes need lowest_hp in [50, 95), got " .. tostring(hstate.lowest_hp))
print("PASS: priest holy ClearcastingGreaterHeal + SurgeOfLightSmite regression")

-- ============================================================================
-- shaman elemental EarthShockMoving + FrostShockMoving — moving shocks
-- ============================================================================
local elem, elem_err, elem_ns = aud.load_spec("shaman", "elemental")
assert_true(elem ~= nil, "shaman/elemental load failed: " .. tostring(elem_err))
_G.EaxRotations = elem_ns

local ectx = assert_lane_matches(elem, elem_ns, "shaman", "EarthShockMoving",
    "elem_shock_moving", "elemental EarthShockMoving must match in elem_shock_moving")
assert_true(ectx.is_moving == true,
    "elemental EarthShockMoving needs is_moving")
local fctx = assert_lane_matches(elem, elem_ns, "shaman", "FrostShockMoving", "elem_shock_pvp",
    "elemental FrostShockMoving must match in elem_shock_pvp")
assert_true(fctx.is_pvp == true,
    "elemental FrostShockMoving needs is_pvp")
-- Prove the interrupt-reserve OFF was what unlocked EarthShockMoving: with
-- the default (reserve ON) the same moving context must NOT match.
local dctx, dstate = make_state(elem, elem_ns, "shaman", "moving")
local ds = find_strategy(elem.strategies, "EarthShockMoving")
local ok_d, dm = pcall(ds.matches, dctx, dstate)
assert_true(ok_d and dm == false,
    "elemental EarthShockMoving must stay silent in plain `moving` (interrupt reserve ON)")
print("PASS: shaman elemental moving shocks x2 regression")

-- ============================================================================
-- End-to-end: the battery must report none of the 9 lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("hunter", "beast_mastery", "Readiness")
assert_lane_fires("hunter", "beast_mastery", "SerpentStingRefresh")
assert_lane_fires("hunter", "marksmanship", "Readiness")
assert_lane_fires("hunter", "survival", "Readiness")
assert_lane_fires("hunter", "survival", "SerpentStingRefresh")
assert_lane_fires("priest", "holy", "ClearcastingGreaterHeal")
assert_lane_fires("priest", "holy", "SurgeOfLightSmite")
assert_lane_fires("shaman", "elemental", "EarthShockMoving")
assert_lane_fires("shaman", "elemental", "FrostShockMoving")
print("PASS: battery reports none of the 9 Phase-3 lanes as never-firing")
