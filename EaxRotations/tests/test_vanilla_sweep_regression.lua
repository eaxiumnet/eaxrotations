-- test_vanilla_sweep_regression.lua — pins the vanilla sweep close-out
-- (2026-08-11) + the wave 1.4 battery extension (2026-08-13).
-- WHAT:  (1) end-to-end never-count pins per spec (12 total across ALL 40
--        vanilla spec files — the 9 leveling_vanilla files joined the battery
--        manifest in wave 1.4, so the 31-spec era pin moved to 40); (2)
--        matcher-level fired/silent non-vacuity for each genuine defect fix:
--        restoration idle-DPS merge, assassination combo_points read,
--        demonology demon_armor_ready computation, warlock ShadowWard
--        get_class fallback (affliction + demonology — the demonology side now
--        reads state.shadow_ward_ready, so the fixture builds real state),
--        fury Overpower dodge fixture; (3) the wave-1.4 scenario shapes stay
--        present.
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   a future edit that re-deads a lane (drops a mock seed, reverts a
--        defect fix, removes a fixture scenario) must fail loudly instead of
--        silently growing the never count back toward the 79-lane baseline.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.
-- ORDER: run_all FIRST (guard_shared_virgin needs a virgin shared namespace;
--        run_all self-cleans package.loaded afterward), then load_spec-based
--        matcher assertions run clean.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
end

local function assert_eq(a, b, label)
    if a ~= b then
        error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

local function scenario_named(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

-- Per-spec expected never counts AFTER the sweep (58 → 13) and the wave 1.4
-- reclassification (13 → 13 with changed CONTENT, 2026-08-13: AbolishDisease
-- + Ambush cleared; priest/leveling Fade pinned — the Fade lane gates on
-- threat_pct >= 99 while the battery's threat channel is capped at 95 by the
-- Soulshatter fires-ONLY-in-threat_high exclusivity contract). Each remaining
-- lane is classified in docs/never_strategy_triage_vanilla_2026-08-13.md.
local EXPECTED_NEVER = {
    { "druid", "bear", 2 },              -- FaerieFirePull, PrePullEnrage (OOC pre-pull)
    { "mage", "fire", 1 },               -- ManaGemConjure (OOC conjure, gem always available)
    { "mage", "frost", 1 },              -- ManaGemConjure (OOC conjure, gem always available)
    { "mage", "leveling", 1 },           -- ConjureManaGem (OOC conjure, gem always available)
    { "priest", "holy", 2 },             -- EncounterReactions (era gate), MountedProtection (mounted OOC)
    { "priest", "leveling", 1 },         -- Fade (threat_pct >= 99, battery threat channel capped at 95)
    { "shaman", "elemental", 2 },        -- MagmaTotem, WrathOfAirTotem (inert/TBC-only)
    { "shaman", "enhancement", 2 },      -- FireNovaReplacement, GraceOfAirTotemTwist (module-local state)
    { "warlock", "affliction", 1 },      -- RacialArcaneTorrent (blood elf)
}

-- ============================================================================
-- (1) End-to-end: the vanilla battery must report exactly 13 never-firing
-- lanes across ALL 40 vanilla specs (31 non-leveling + 9 leveling, wave 1.4),
-- and every spec that the sweep + wave 1.4 cleared must be at 0.
-- ============================================================================
local agg = aud.run_all("vanilla")
local total_never = 0
local by_spec = {}
for _, rep in ipairs(agg.reports or {}) do
    local key = (rep.class or "?") .. "/" .. (rep.spec or "?")
    by_spec[key] = #(rep.never or {})
    total_never = total_never + #(rep.never or {})
end
assert_eq(total_never, 13, "vanilla battery must report exactly 13 never-firing lanes, got " .. total_never)
print("PASS: vanilla battery total never-fires = 13 (reclassified content, 40-spec battery)")

-- The battery manifest must cover all 40 vanilla spec files (wave 1.4
-- extension: 31 non-leveling + 9 leveling_vanilla).
local spec_count = 0
for _, rep in ipairs(agg.reports or {}) do spec_count = spec_count + 1 end
assert_eq(spec_count, 40, "vanilla battery must cover 40 specs, got " .. spec_count)
print("PASS: vanilla battery covers all 40 vanilla spec files (incl. 9 leveling)")

-- Specs fully cleared by the sweep + wave 1.4 (harness seeds, defect fixes,
-- scenario fixtures) must be at 0.
local CLEARED_TO_ZERO = {
    "druid/balance", "druid/cat", "druid/leveling", "druid/resto",
    "hunter/beast_mastery", "hunter/leveling", "hunter/marksmanship", "hunter/survival",
    "mage/arcane",
    "paladin/leveling",
    "priest/discipline", "priest/shadow", "priest/smite",
    "rogue/assassination", "rogue/combat", "rogue/leveling", "rogue/subtlety",
    "shaman/leveling", "shaman/restoration",
    "warlock/demonology", "warlock/destruction", "warlock/leveling",
    "warrior/arms", "warrior/fury", "warrior/kebab", "warrior/leveling", "warrior/protection",
}
for _, key in ipairs(CLEARED_TO_ZERO) do
    assert_eq(by_spec[key], 0, "spec " .. key .. " must have 0 never-firing lanes after the sweep (got "
        .. tostring(by_spec[key]) .. ")")
end
print("PASS: all sweep-cleared specs report 0 never-firing lanes")

for _, e in ipairs(EXPECTED_NEVER) do
    local key = e[1] .. "/" .. e[2]
    assert_eq(by_spec[key], e[3], "spec " .. key .. " must keep " .. e[3]
        .. " pinned never-firing lane(s), got " .. tostring(by_spec[key]))
end
print("PASS: all 13 kept pins are exactly as classified")

-- ============================================================================
-- (2) Defect-fix non-vacuity (matcher level, mirroring the cat-sweep
-- fired/silent proof style).
-- ============================================================================

-- (2a) restoration idle-DPS merge: the 4 idle-DPS strategies must be part of
-- the REGISTERED strategies table (previously exposed only as numeric
-- indices — dead in the live rotation).
local resto_mod, _, resto_ns = aud.load_spec("shaman", "restoration", "vanilla")
assert_true(resto_mod ~= nil, "shaman/restoration vanilla load failed")
local resto_strategies = (type(resto_mod) == "table") and (resto_mod.strategies or resto_mod) or {}
local resto_names = {}
for _, s in ipairs(resto_strategies) do
    if type(s) == "table" and s.name then resto_names[s.name] = true end
end
for _, lane in ipairs({ "EarthShock", "FlameShock", "ChainLightning", "LightningBolt" }) do
    assert_true(resto_names[lane] == true,
        "restoration vanilla must register idle-DPS strategy " .. lane .. " (live-rotation merge)")
end
print("PASS: restoration idle-DPS strategies (EarthShock/FlameShock/ChainLightning/LightningBolt) merged into the registered table")

-- (2b) assassination combo_points read: finishers read state.combo; the
-- engine exposes ctx.combo_points (main_sylvanas.lua:856). Pin all three
-- channels (combo_points wins, combo legacy fallback, 0 default).
local assa_mod, _, assa_ns = aud.load_spec("rogue", "assassination", "vanilla")
assert_true(assa_mod ~= nil, "rogue/assassination vanilla load failed")
-- Plain-style vanilla files return bare strategies and register get_state via
-- the registry mock; recover it exactly like run_spec does.
local function get_state_for(mod, ns)
    if type(mod) == "table" and type(mod.build_state) == "function" then return mod.build_state end
    if ns and ns._registry and ns._registry.options
        and type(ns._registry.options.get_state) == "function" then
        return ns._registry.options.get_state
    end
    if ns and ns._registry and ns._registry.options
        and type(ns._registry.options.context_builder) == "function" then
        return ns._registry.options.context_builder
    end
    return nil
end
local assa_build = get_state_for(assa_mod, assa_ns)
assert_true(assa_build ~= nil, "assassination build_state not recoverable")
local function state_for(scenario)
    local ctx = aud.build_context_for("rogue", scenario)
    aud.apply_battery_state(assa_ns, ctx, "rogue")
    local ok, st = pcall(assa_build, ctx)
    assert_true(ok, "assassination build_state crashed: " .. tostring(st))
    return ctx, st
end
local sc_cp = { name = "assa_cp", overrides = { combo_points = 4 } }
local _, st_cp = state_for(sc_cp)
assert_eq(st_cp.combo, 4, "state.combo must read ctx.combo_points (engine channel)")
-- Legacy channel: `combo` is not a whitelisted override key, so drive it by
-- mutating the built ctx directly (simulating an engine that only provides
-- context.combo). The fix reads combo_points or combo or 0.
local function state_for_mutated(scenario, mutate)
    local ctx = aud.build_context_for("rogue", scenario)
    mutate(ctx)
    aud.apply_battery_state(assa_ns, ctx, "rogue")
    local ok, st = pcall(assa_mod.build_state, ctx)
    assert_true(ok, "assassination build_state crashed (mutated): " .. tostring(st))
    return st
end
local st_legacy = state_for_mutated(sc_cp, function(ctx) ctx.combo_points = nil; ctx.combo = 3 end)
assert_eq(st_legacy.combo, 3, "state.combo must fall back to ctx.combo (legacy channel)")
local st_none = state_for_mutated(sc_cp, function(ctx) ctx.combo_points = nil; ctx.combo = nil end)
assert_eq(st_none.combo, 0, "state.combo must default to 0 when neither channel is set")
print("PASS: assassination combo reads combo_points -> combo -> 0")

-- (2c) demonology demon_armor_ready: previously never computed (matcher read
-- at :638 was the only reference) — the DemonArmorBuff strategy could never
-- fire in live play. Now computed like shadow_ward_ready; OOC matcher fires
-- when the armor buff is down, stays silent in combat.
local demo_mod, _, demo_ns = aud.load_spec("warlock", "demonology", "vanilla")
assert_true(demo_mod ~= nil, "warlock/demonology vanilla load failed")
local demo_strategies = (type(demo_mod) == "table") and (demo_mod.strategies or demo_mod) or {}
local demo_build = get_state_for(demo_mod, demo_ns)
assert_true(demo_build ~= nil, "demonology build_state not recoverable")
local function demo_state_for(scenario)
    local ctx = aud.build_context_for("warlock", scenario)
    aud.apply_battery_state(demo_ns, ctx, "warlock")
    local ok, st = pcall(demo_build, ctx)
    assert_true(ok, "demonology build_state crashed: " .. tostring(st))
    return ctx, st
end
local sc_ooc = { name = "demo_ooc", overrides = { in_combat = false } }
local ctx_ooc, st_ooc = demo_state_for(sc_ooc)
assert_eq(st_ooc.demon_armor_ready, true, "demon_armor_ready must be computed (spell ready in mock)")
local dam = nil
for _, s in ipairs(demo_strategies) do
    if type(s) == "table" and s.name == "DemonArmorBuff" then dam = s end
end
assert_true(dam ~= nil, "demonology must have a DemonArmorBuff strategy")
local mok, m = pcall(dam.matches, ctx_ooc, st_ooc)
assert_true(mok, "DemonArmorBuff matcher crashed: " .. tostring(m))
assert_true(m == true, "DemonArmorBuff must fire OOC with the armor buff down")
local sc_combat = { name = "demo_combat", overrides = { in_combat = true } }
local ctx_c, st_c = demo_state_for(sc_combat)
local mok2, m2 = pcall(dam.matches, ctx_c, st_c)
assert_true(mok2, "DemonArmorBuff matcher crashed (combat): " .. tostring(m2))
assert_true(m2 ~= true, "DemonArmorBuff must be silent in combat (OOC-gated)")
print("PASS: demonology demon_armor_ready computed; DemonArmorBuff fires OOC, silent in combat")

-- (2d) warlock ShadowWard get_class fallback (affliction + demonology): the
-- engine never sets context.enemy_shadow_caster, so the matcher must fall
-- back to target:get_class() (priest 5 / warlock 9). PvP + priest target ->
-- fires; PvP + warrior target -> silent; non-PvP -> silent. The wave-1.3
-- fixer reconciled demonology to the shared contract: its matcher now reads
-- state.shadow_ward_ready (demonology_vanilla:730-747) instead of calling
-- NS.spell_ready directly like affliction, so the fixture builds REAL state
-- via the recovered build_state (the old bare matches(ctx) call passed nil
-- state and silently false'd the demo side — the fixture must exercise the
-- new state-driven contract, not a weaker one).
local affl_mod, _, affl_ns = aud.load_spec("warlock", "affliction", "vanilla")
assert_true(affl_mod ~= nil, "warlock/affliction vanilla load failed")
local affl_strategies = (type(affl_mod) == "table") and (affl_mod.strategies or affl_mod) or {}
local function sw_matches(mod, ns, target_class, is_pvp)
    local sc = { name = "sw_probe", overrides = { is_pvp = is_pvp, target_class = target_class } }
    local ctx = aud.build_context_for("warlock", sc)
    aud.apply_battery_state(ns, ctx, "warlock")
    -- Recover the real state builder (plain-style vanilla files register it
    -- via the registry mock) so the demonology matcher's
    -- state.shadow_ward_ready read is exercised, not bypassed.
    local build = get_state_for(mod, ns)
    local state
    if build then
        local ok_st, st = pcall(build, ctx)
        assert_true(ok_st, "ShadowWard build_state crashed: " .. tostring(st))
        state = st
    end
    for _, s in ipairs(mod.strategies or mod) do
        if type(s) == "table" and s.name == "ShadowWard" then
            local ok, m = pcall(s.matches, ctx, state)
            assert_true(ok, "ShadowWard matcher crashed: " .. tostring(m))
            return m
        end
    end
    error("ShadowWard strategy missing", 2)
end
assert_eq(sw_matches(affl_mod, affl_ns, 5, true), true,
    "affliction ShadowWard must fire in PvP vs a priest target (get_class fallback)")
assert_eq(sw_matches(affl_mod, affl_ns, 1, true), false,
    "affliction ShadowWard must stay silent vs a non-shadow-caster class")
assert_eq(sw_matches(affl_mod, affl_ns, 5, false), false,
    "affliction ShadowWard must stay silent outside PvP")
assert_eq(sw_matches(demo_mod, demo_ns, 5, true), true,
    "demonology ShadowWard must fire in PvP vs a priest target (state.shadow_ward_ready contract)")
assert_eq(sw_matches(demo_mod, demo_ns, 1, true), false,
    "demonology ShadowWard must stay silent vs a non-shadow-caster class")
assert_eq(sw_matches(demo_mod, demo_ns, 5, false), false,
    "demonology ShadowWard must stay silent outside PvP (PvP gate)")
print("PASS: ShadowWard get_class fallback + PvP gate (priest fires, warrior silent, non-PvP silent) in affliction + demonology")

-- (2e) fury Overpower dodge fixture: the dodge_proc scenario drives
-- target:get_dodge_chance() > 0, so state.overpower_window is true and the
-- real strategy fires; without the fixture the window stays false.
local fury_mod, _, fury_ns = aud.load_spec("warrior", "fury", "vanilla")
assert_true(fury_mod ~= nil, "warrior/fury vanilla load failed")
local fury_strategies = (type(fury_mod) == "table") and (fury_mod.strategies or fury_mod) or {}
local fury_build = get_state_for(fury_mod, fury_ns)
assert_true(fury_build ~= nil, "fury build_state not recoverable")
local function fury_state_for(scenario)
    local ctx = aud.build_context_for("warrior", scenario)
    aud.apply_battery_state(fury_ns, ctx, "warrior")
    local ok, st = pcall(fury_build, ctx)
    assert_true(ok, "fury build_state crashed: " .. tostring(st))
    return ctx, st
end
local sc_dodge = scenario_named("dodge_proc")
assert_true(sc_dodge.overrides and sc_dodge.overrides.target_dodge_chance ~= nil,
    "dodge_proc scenario must exist with target_dodge_chance (drives Overpower's get_dodge_chance pcall)")
local ctx_d, st_d = fury_state_for(sc_dodge)
assert_eq(st_d.overpower_window, true, "dodge_proc must yield overpower_window = true")
local op = nil
for _, s in ipairs(fury_strategies) do
    if type(s) == "table" and s.name == "Overpower" then op = s end
end
assert_true(op ~= nil, "fury vanilla must have an Overpower strategy")
local mok3, m3 = pcall(op.matches, ctx_d, st_d)
assert_true(mok3, "Overpower matcher crashed (dodge): " .. tostring(m3))
assert_true(m3 == true, "Overpower must fire inside a dodge window")
local sc_nododge = { name = "fury_nododge", overrides = { in_combat = true, rage = 40 } }
local ctx_nd, st_nd = fury_state_for(sc_nododge)
assert_eq(st_nd.overpower_window, false, "no dodge fixture -> overpower_window false (default 0)")
local mok4, m4 = pcall(op.matches, ctx_nd, st_nd)
assert_true(mok4, "Overpower matcher crashed (no dodge): " .. tostring(m4))
assert_true(m4 ~= true, "Overpower must be silent when no dodge proc is present")
print("PASS: fury Overpower fires via dodge_proc fixture, silent without it")

-- (2f) balance + elemental FlameShock: the min-SP gates gated on
-- ctx.spell_damage the engine never populates; dropped to mirror the TBC
-- siblings. End-to-end (1) already proves both specs are at 0 never-fires;
-- additionally prove the FlameShock matcher fires in a combat scenario.
local elem_mod, _, elem_ns = aud.load_spec("shaman", "elemental", "vanilla")
assert_true(elem_mod ~= nil, "shaman/elemental vanilla load failed")
local elem_strategies = (type(elem_mod) == "table") and (elem_mod.strategies or elem_mod) or {}
local elem_build = get_state_for(elem_mod, elem_ns)
assert_true(elem_build ~= nil, "elemental build_state not recoverable")
local sc_fs = { name = "elem_fs", overrides = { in_combat = true, target_hp = 100 } }
local ctx_fs = aud.build_context_for("shaman", sc_fs)
aud.apply_battery_state(elem_ns, ctx_fs, "shaman")
local ok_fs, st_fs = pcall(elem_build, ctx_fs)
assert_true(ok_fs, "elemental build_state crashed: " .. tostring(st_fs))
local fs = nil
for _, s in ipairs(elem_strategies) do
    if type(s) == "table" and s.name == "FlameShock" then fs = s end
end
assert_true(fs ~= nil, "elemental vanilla must have a FlameShock strategy")
local mok5, m5 = pcall(fs.matches, ctx_fs, st_fs)
assert_true(mok5, "FlameShock matcher crashed: " .. tostring(m5))
assert_true(m5 == true, "elemental FlameShock must fire (min-SP gate removed)")
print("PASS: elemental FlameShock fires in combat (min-SP gate gone)")

-- ============================================================================
-- (3) Harness-shape pins: the fixture scenarios that make the swept lanes
-- observable must stay present (a future edit that drops them re-deads the
-- lanes silently).
-- ============================================================================
assert_true(scenario_named("dodge_proc") ~= nil, "dodge_proc scenario must exist")
local cure = scenario_named("holy_cure_on_cd")
assert_true(cure.overrides and cure.overrides.on_cd and cure.overrides.on_cd[528] ~= nil,
    "holy_cure_on_cd scenario must exist with on_cd { [528] = CureDisease }")
print("PASS: dodge_proc + holy_cure_on_cd fixture scenarios present")

-- Wave 1.4 fixture-shape pins (2026-08-13): each scenario that cleared a
-- wave-1.4 lane must stay present, or the lane silently re-deads.
local WAVE14_SHAPES = {
    cat_lev_claw = function(s)
        return s.overrides and s.overrides.is_behind == false
            and s.overrides.debuff_remains_map and s.overrides.debuff_remains_map[9904] ~= nil
    end,
    ambush_opener = function(s)
        return s.overrides and s.overrides.setting_overrides
            and s.overrides.setting_overrides.opener_preference == "ambush"
            and s.overrides.buff_remains_map and s.overrides.buff_remains_map[1784] ~= nil
    end,
    pal_lev_seal = function(s)
        return s.overrides and s.overrides.buff_remains_map
            and s.overrides.buff_remains_map[20375] ~= nil
            and s.overrides.target_hp == 15 and s.overrides.target_creature_type == 6
    end,
    priest_ve = function(s)
        return s.overrides and s.overrides.buff_remains_map
            and s.overrides.buff_remains_map[15473] ~= nil
    end,
    lev_shock_earth = function(s)
        return s.overrides and s.overrides.setting_overrides
            and s.overrides.setting_overrides.leveling_default_shock == "earth"
    end,
    lev_shock_frost = function(s)
        return s.overrides and s.overrides.setting_overrides
            and s.overrides.setting_overrides.leveling_default_shock == "frost"
    end,
    pvp_cc_gate = function(s)
        return s.overrides and s.overrides.enemy_cc_nearby == true
    end,
    ooc_afflicted = function(s)
        return s.overrides and s.overrides.in_combat == false
            and s.overrides.friends_afflicted == true
    end,
}
for name, check in pairs(WAVE14_SHAPES) do
    assert_true(check(scenario_named(name)),
        "wave-1.4 fixture scenario " .. name .. " must exist with its shape (a future edit that drops it re-deads the lane it cleared)")
end
print("PASS: wave-1.4 fixture scenarios (cat_lev_claw/ambush_opener/pal_lev_seal/priest_ve/lev_shock_earth/lev_shock_frost/pvp_cc_gate/ooc_afflicted) present")

print("PASS: vanilla sweep regression (13 pins, 40-spec battery, 6 defect fixes, 10 fixture shapes)")
