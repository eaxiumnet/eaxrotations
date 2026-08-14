-- test_combat_battery_regression.lua — pins the 3 lanes unblocked by the
-- ranked #3-5 battery upgrade (2026-08-07): wand_low_mana, ab_stack_conserve,
-- and battle_ready (map-aware buff_up for BladeFlurry).
-- WHAT:  behavioral_audit.lua now (a) adds a `wand_low_mana` scenario
--        (mana_pct 4 + hp 15 — warlock/affliction Wand fires only when mana
--        < 30 AND hp < LIFE_TAP_SAFETY_HP 35, i.e. Life Tap is unsafe),
--        (b) adds an `ab_stack_conserve` scenario (buffs_up + buff_remains_map
--        { [36032] = 4 } — the AB stack aura is a SELF BUFF, so mage/arcane
--        FrostboltConserve reads NS.buff_stacks/buff_remains (fires at phase
--        conserve + ab_stacks >= 3 + ab_remains > cast time)),
--        and (c) makes ns.buff_up map-aware via buff_remains_map and adds a
--        `battle_ready` scenario (SnD {6774, 5171} up, BF 13877 down, 3
--        enemies) so rogue/combat BladeFlurry's has_snd true + has_blade_flurry
--        false become independently observable. Previously buff_up was
--        all-or-nothing buffs_up: buffs_up=true marked BF already-up (self-
--        block) and buffs_up=false left SnD down.
--        Lanes pinned here (all previously never-firing):
--          warlock/affliction Wand            (wand_low_mana)
--          mage/arcane        FrostboltConserve (ab_stack_conserve)
--          rogue/combat       BladeFlurry      (battle_ready)
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any stops firing (state + matcher + negative + end-to-end).
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

local function build_scenario(class_key, name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

local function make_state(spec_mod, ns, class_key, scenario_name)
    local ctx = aud.build_context_for(class_key, build_scenario(class_key, scenario_name))
    aud.apply_battery_state(ns, ctx, class_key)
    if spec_mod.build_state then
        local ok, st = pcall(spec_mod.build_state, ctx)
        assert_true(ok, class_key .. "/" .. scenario_name .. " build_state crashed: " .. tostring(st))
        if type(st) == "table" then return ctx, st end
    end
    return ctx, ctx
end

local function assert_lane_matches(spec_mod, ns, class_key, scenario_name, lane, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m, label)
    return ctx, state
end

local function assert_never(spec_mod, ns, class_key, scenario_name, lane, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed in negative: " .. tostring(m))
    assert_true(m ~= true, label)
end

-- ============================================================================
-- Warlock/affliction Wand (wand_low_mana): mana < 30 AND hp < 35 (Life Tap
-- unsafe) — state.mana_pct / state.hp_pct must come from the scenario bank.
-- ============================================================================
local affl, affl_err, affl_ns = aud.load_spec("warlock", "affliction")
assert_true(affl ~= nil, "warlock/affliction load failed: " .. tostring(affl_err))
_G.EaxRotations = affl_ns

local w_ctx, w_state = assert_lane_matches(affl, affl_ns, "warlock", "wand_low_mana", "Wand",
    "warlock/affl Wand must match in wand_low_mana (mana 4 < 30, hp 15 < 35)")
assert_true((w_state.mana_pct or 100) == 4,
    "warlock/affl: wand_low_mana must set state.mana_pct=4, got " .. tostring(w_state.mana_pct))
assert_true((w_state.hp_pct or 100) == 15,
    "warlock/affl: wand_low_mana must set state.hp_pct=15, got " .. tostring(w_state.hp_pct))
-- Life-Tap safety: at full hp the spec prefers Life Tap -> Shadow Bolt, so
-- Wand must stay silent there.
assert_never(affl, affl_ns, "warlock", "standard", "Wand",
    "warlock/affl Wand must NOT match in standard (hp 100 -> Life Tap preferred)")
assert_never(affl, affl_ns, "warlock", "low_mana", "Wand",
    "warlock/affl Wand must NOT match in low_mana (hp 100 -> Life Tap preferred)")
print("PASS: warlock/affliction Wand (wand_low_mana, mana+hp mechanism)")

-- ============================================================================
-- Mage/arcane FrostboltConserve (ab_stack_conserve): phase conserve +
-- ab_stacks >= 3 + ab_remains > cast time (~1.0). The scenario must drive
-- ab_stacks via the SELF-BUFF side — buff_remains_map { [36032] = 4 } feeds
-- both NS.buff_stacks (4) and NS.buff_remains (4); other scenarios keep
-- ab_stacks 0 (or the buffs_up fallback 1) so the lane stays silent.
-- ============================================================================
local arc, arc_err, arc_ns = aud.load_spec("mage", "arcane")
assert_true(arc ~= nil, "mage/arcane load failed: " .. tostring(arc_err))
_G.EaxRotations = arc_ns

local a_ctx, a_state = assert_lane_matches(arc, arc_ns, "mage", "ab_stack_conserve", "FrostboltConserve",
    "mage/arcane FrostboltConserve must match in ab_stack_conserve (ab_stacks 4, conserve phase)")
assert_true((a_state.ab_stacks or 0) >= 3,
    "mage/arcane: ab_stack_conserve must drive ab_stacks >= 3, got " .. tostring(a_state.ab_stacks))
assert_true(a_state.phase == "conserve",
    "mage/arcane: ab_stack_conserve must stay in conserve phase, got " .. tostring(a_state.phase))
assert_true((a_state.ab_remains or 0) > 1.0,
    "mage/arcane: ab_stack_conserve must keep ab_remains > cast_time, got " .. tostring(a_state.ab_remains))
assert_true(arc_ns.buff_stacks(arc_ns.PLAYER_UNIT, { 36032, 36033, 36034 }) == 4,
    "mage/arcane: battery buff_stacks must return 4 for the AB self-buff aura ids")
-- Id-scoping guard: the AB-stack map must NOT leak to other specs' buff ids
-- (poison stacks stay readable only with their own aura ids — the buffs_up
-- fallback yields 1, never the scenario's 4).
assert_true(arc_ns.buff_stacks(arc_ns.PLAYER_UNIT, { 27187 }) ~= 4,
    "mage/arcane: AB-stack scenario must not leak stacks to poison ids (27187)")
assert_never(arc, arc_ns, "mage", "standard", "FrostboltConserve",
    "mage/arcane FrostboltConserve must NOT match in standard (ab_stacks 0)")
assert_never(arc, arc_ns, "mage", "burst", "FrostboltConserve",
    "mage/arcane FrostboltConserve must NOT match in burst (buffs_up but no AB stacks)")
print("PASS: mage/arcane FrostboltConserve (ab_stack_conserve, AB-stack mechanism)")

-- ============================================================================
-- Rogue/combat BladeFlurry (battle_ready): map-aware buff_up — SnD {6774,
-- 5171} up via buff_remains_map, BF 13877 down, 3 enemies >= min_targets.
-- ============================================================================
local com, com_err, com_ns = aud.load_spec("rogue", "combat")
assert_true(com ~= nil, "rogue/combat load failed: " .. tostring(com_err))
_G.EaxRotations = com_ns

local b_ctx, b_state = assert_lane_matches(com, com_ns, "rogue", "battle_ready", "BladeFlurry",
    "rogue/combat BladeFlurry must match in battle_ready (SnD up, BF down, 3 enemies)")
assert_true(b_state.has_snd == true,
    "rogue/combat: battle_ready must set has_snd=true via buff_remains_map, got " .. tostring(b_state.has_snd))
assert_true(b_state.has_blade_flurry == false,
    "rogue/combat: battle_ready must keep has_blade_flurry=false (BF 13877 not in map), got " .. tostring(b_state.has_blade_flurry))
-- Map-aware buff_up mechanism pins.
assert_true(com_ns.buff_up(com_ns.PLAYER_UNIT, { 6774 }) == true,
    "rogue/combat: map-aware buff_up must report SnD 6774 up in battle_ready")
assert_true(com_ns.buff_up(com_ns.PLAYER_UNIT, { 5171 }) == true,
    "rogue/combat: map-aware buff_up must report SnD 5171 up in battle_ready")
assert_true(com_ns.buff_up(com_ns.PLAYER_UNIT, { 13877 }) == false,
    "rogue/combat: map-aware buff_up must report BF 13877 DOWN (map-miss, no buffs_up fallback in battle_ready)")
-- buffs_up fallback preserved: in a buffs_up scenario buff_up returns true for
-- ids not in any map (byte-identical to pre-map behavior).
assert_true(com_ns.buff_up(com_ns.PLAYER_UNIT, { 99999 }) == false,
    "rogue/combat: buff_up must be false for unmapped ids outside buffs_up scenarios")
-- Deadlock guard: in a plain buffs_up scenario both SnD and BF are "up" ->
-- BladeFlurry self-blocks (has_blade_flurry true). In a plain enemies scenario
-- SnD is down. Both must stay silent.
local deadlock = { name = "custom_bf_buffs_up", overrides = { buffs_up = true, enemy_count = 3, enemies_count = 3 } }
local d_ctx = aud.build_context_for("rogue", deadlock)
aud.apply_battery_state(com_ns, d_ctx, "rogue")
local d_state = com.build_state(d_ctx)
local bs = find_strategy(com.strategies, "BladeFlurry")
local ok_d, m_d = pcall(bs.matches, d_ctx, d_state)
assert_true(ok_d and m_d ~= true,
    "rogue/combat BladeFlurry must stay silent under buffs_up deadlock (BF self-block)")
assert_never(com, com_ns, "rogue", "aoe", "BladeFlurry",
    "rogue/combat BladeFlurry must NOT match in aoe (SnD down -> no attack-speed buff)")
assert_never(com, com_ns, "rogue", "burst", "BladeFlurry",
    "rogue/combat BladeFlurry must NOT match in burst (buffs_up marks BF already-up)")
print("PASS: rogue/combat BladeFlurry (battle_ready, map-aware buff_up)")

-- ============================================================================
-- End-to-end: the battery must report each cleared lane as firing — and only
-- in its intended scenario (all three are single-scenario exclusive).
-- ============================================================================
local end_to_end = {
    { "warlock", "affliction", { "Wand" },              "wand_low_mana",   true },
    { "mage",    "arcane",     { "FrostboltConserve" }, "ab_stack_conserve", true },
    { "rogue",   "combat",     { "BladeFlurry" },       "battle_ready",    true },
}
local done = {}
for _, kv in ipairs(end_to_end) do
    local class_key, spec_key, lanes, want, exclusive = kv[1], kv[2], kv[3], kv[4], kv[5]
    local key = class_key .. "/" .. spec_key
    if not done[key] then
        local report = aud.run_spec(class_key, spec_key)
        assert_true(report ~= nil, "battery run for " .. key .. " failed")
        assert_true(#report.dispatch_errors == 0,
            key .. " battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))
        done[key] = report
    end
    local report = done[key]
    for _, lane in ipairs(lanes) do
        local is_never = false
        for _, name in ipairs(report.never) do
            if name == lane then is_never = true end
        end
        assert_true(not is_never, "battery still reports " .. key .. " " .. lane .. " as never-firing")
        local fi = report.fires_in[lane]
        assert_true(type(fi) == "table" and fi[want] == true,
            key .. " " .. lane .. " must fire in the " .. want .. " scenario")
        if exclusive then
            local count = 0
            for _ in pairs(fi) do count = count + 1 end
            assert_true(count == 1,
                key .. " " .. lane .. " must fire ONLY in " .. want .. ", got " .. count .. " scenarios")
        end
    end
end
print("PASS: end-to-end battery check (3 lanes, scenario exclusivity)")
print("ALL PASS: ranked #3-5 combat battery regression")
