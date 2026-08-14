-- test_warlock_wotlk_live_fixes.lua — Warlock WotLK wave-3.3 live fixes.
-- WHAT:  Match/build_state regression for the 2026-08-13 warlock WotLK fixes:
--        (1) WotLK max-rank debuff ids (Corruption 47813 / UA 47843 / CoA
--        47864 / Immolate 47811 / Haunt 59164) so DoT-remains reads are real
--        and Conflagrate's Immolate gate can pass (production never-lane);
--        (2) Life Tap sustain lanes in affliction/demonology/destruction,
--        appended AFTER the pinned APL order; (3) plain spec_kit.define_action
--        so the TBC-era NS.WarlockSpells table cannot shadow the WotLK ladders;
--        (4) engine context fields (context.mana_pct/hp/target_hp) drive state
--        instead of mock-only unit methods.
-- WHEN:  Registered in run_rotation_tests.lua (Wave 3.3 block).
-- WHY:   Pins the W3.1 audit fixes so they cannot regress.
-- SAFETY: Pure unit tests with a mocked NS (test_warlock_vanilla_live_fixes
--         convention); real spec_kit + strategy_dsl loaded (real API shapes);
--         no game data, no filesystem writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq failed") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

-- ---------------------------------------------------------------------------
-- Shared-module stubs (same convention as test_warlock_vanilla_live_fixes).
-- spec_kit / strategy_dsl are loaded REAL (pure helpers; NS resolved at call
-- time) so the assertions exercise the production resolution paths.
-- ---------------------------------------------------------------------------
package.loaded["shared/aoe_hit_volume_sylvanas"] = {
    install = function() end,
}
package.loaded["shared/leveling_helpers_sylvanas"] = {
    should_interrupt = function() return false end,
}
package.loaded["shared/pet_manager_sylvanas"] = {
    get_pet = function() return nil end,
    pet_alive = function() return false end,
    try_cast = function() return true end,
}

-- ---------------------------------------------------------------------------
-- NS mock. The debuff spy records every id table build_state queries and
-- returns `dot_map[id]` (first hit wins) so tests can present a max-rank
-- WotLK debuff (e.g. [47813] = 8) exactly like the live client.
--
-- NOTE: built field-by-field (not a table constructor) so the closures can
-- reference `ns` as an upvalue — inside a constructor literal `ns` would
-- resolve to the global (Lua scoping), i.e. nil.
-- ---------------------------------------------------------------------------
local function make_ns(overrides)
    local spell_ladders = {}  -- rank tables passed to NS.spell_action (spy)
    local ns = {}
    ns.WarlockSpells = {
        -- TBC-era class table (mirrors classes/warlock/class_sylvanas.lua
        -- values): a spec still on define_action_for_class would resolve
        -- these and lose the WotLK max-rank ladder head.
        Corruption = 27216, CurseOfAgony = 27218, Immolate = 27215,
        ShadowBolt = 27209, UnstableAffliction = 30405, LifeTap = 27222,
    }
    ns.PLAYER_UNIT = {}
    ns.spell_action = function(rank_ids, label)
        local ids = type(rank_ids) == "table" and rank_ids or { rank_ids }
        spell_ladders[#spell_ladders + 1] = { ids = ids, label = label }
        return { ids = ids, label = label }
    end
    ns.dot_map = {}
    ns.debuff_remains = function(unit, ids)
        local map = ns.dot_map
        for _, id in ipairs(ids or {}) do
            if map and map[id] ~= nil then return map[id] end
        end
        return 0
    end
    ns.buff_up = function() return false end
    ns.spell_ready = function() return true end
    ns.try_cast = function() return true end
    ns.should_refresh_dot = function(remains, window) return (remains or 0) <= (window or 1.5) end
    ns.should_use_long_cd = function() return true end
    ns.aoe_target_meets = function() return false end
    ns.time_now = function() return 0 end
    ns.GetPlayer = function() return {} end
    ns.log = function() end
    ns.rotation_registry = { register = function() end }
    ns.get_spell_ladders = function() return spell_ladders end
    if overrides then for k, v in pairs(overrides) do ns[k] = v end end
    return ns
end

-- Spec files return { strategies = ..., build_state = ... }; return the whole
-- module so callers can reach both the strategy list and build_state.
local function load_strategies(path, ns)
    _G.EaxRotations = ns
    return dofile(path)
end

local function find(mod, name)
    local strategies = mod.strategies
    for i = 1, #strategies do
        if strategies[i].name == name then return i, strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function ctx(overrides)
    local c = {
        me = {},
        target = {},
        has_valid_enemy_target = true,
        in_combat = true,
        mana_pct = 100,
        hp = 100,
        target_hp = 100,
        enemy_count = 1,
        settings = {},
    }
    if overrides then for k, v in pairs(overrides) do c[k] = v end end
    return c
end

-- DSL matches(context, state) evaluates state conditions against the state
-- table (produced by build_state from the context), exactly like the engine.
local function built(mod, overrides)
    local c = ctx(overrides)
    return c, mod.build_state(c)
end

-- ============================================================================
-- (1) WotLK max-rank debuff ids reach NS.debuff_remains via build_state
-- ============================================================================
do
    local ns = make_ns()
    local affl = load_strategies("EaxRotations/classes/warlock/affliction_wotlk.lua", ns)
    local _, st = built(affl, { target = {} })
    assert_eq(st.unstable_remains, 0, "affliction UA remains base read")
    ns.dot_map = { [47843] = 12, [47813] = 12, [47864] = 12, [59164] = 12 }
    local _, st_up = built(affl, { target = {} })
    assert_eq(st_up.unstable_remains, 12, "UA remains reads WotLK max-rank 47843")
    assert_eq(st_up.corruption_remains, 12, "Corruption remains reads WotLK max-rank 47813")
    assert_eq(st_up.agony_remains, 12, "Curse of Agony remains reads WotLK max-rank 47864")
    assert_eq(st_up.haunt_remains, 12, "Haunt remains reads WotLK max-rank 59164")
end

do
    local ns = make_ns()
    local demo = load_strategies("EaxRotations/classes/warlock/demonology_wotlk.lua", ns)
    ns.dot_map = { [47811] = 12, [47813] = 12 }
    local _, st = built(demo, { target = {} })
    assert_eq(st.immolate_remains, 12, "demonology Immolate remains reads 47811")
    assert_eq(st.corruption_remains, 12, "demonology Corruption remains reads 47813")
end

do
    local ns = make_ns()
    local destro = load_strategies("EaxRotations/classes/warlock/destruction_wotlk.lua", ns)
    ns.dot_map = { [47811] = 12 }
    local _, st = built(destro, { target = {} })
    assert_eq(st.immolate_remains, 12, "destruction Immolate remains reads 47811")
end

do
    local ns = make_ns()
    local leveling = load_strategies("EaxRotations/classes/warlock/leveling_wotlk.lua", ns)
    ns.dot_map = { [47843] = 12, [47864] = 12, [47813] = 12, [47811] = 12, [59164] = 12 }
    local _, st = built(leveling, { target = {} })
    assert_eq(st.unstable_remains, 12, "leveling UA remains reads 47843")
    assert_eq(st.curse_remains, 12, "leveling CoA remains reads 47864")
    assert_eq(st.corruption_remains, 12, "leveling Corruption remains reads 47813")
    assert_eq(st.immolate_remains, 12, "leveling Immolate remains reads 47811")
end

-- ============================================================================
-- (2) define_action resolves the WotLK ladders (SPELLS shadow eliminated)
-- ============================================================================
do
    local ns = make_ns()
    load_strategies("EaxRotations/classes/warlock/affliction_wotlk.lua", ns)
    local heads = {}
    for _, entry in ipairs(ns.get_spell_ladders()) do
        heads[entry.ids[1]] = entry.label
    end
    assert_eq(heads[47843], "UnstableAffliction", "UA ladder head is 47843 (not the SPELLS shadow)")
    assert_eq(heads[47813], "Corruption", "Corruption ladder head is 47813")
    assert_eq(heads[47864], "CurseOfAgony", "CoA ladder head is 47864")
    assert_eq(heads[59164], "Haunt", "Haunt ladder head is 59164")
    assert_eq(heads[57946], "LifeTap", "LifeTap ladder head is 57946 (WotLK max rank)")
end

-- ============================================================================
-- (3) Life Tap sustain lanes: present, ordered after the pinned APL order,
--     firing on engine context fields only
-- ============================================================================
do
    local ns = make_ns()
    local affl = load_strategies("EaxRotations/classes/warlock/affliction_wotlk.lua", ns)
    local lt_i, lt = find(affl, "LifeTap")
    local sb_i = find(affl, "ShadowBolt")
    assert_true(lt_i > sb_i, "affliction LifeTap appended after ShadowBolt (APL order intact)")
    assert_eq(lt_i, #affl.strategies, "affliction LifeTap is the tail strategy")
    local c1, s1 = built(affl, { mana_pct = 25, hp = 90 })
    assert_true(lt.matches(c1, s1), "affliction LifeTap fires at low mana with healthy HP")
    local c2, s2 = built(affl, { mana_pct = 100, hp = 90 })
    assert_false(lt.matches(c2, s2), "affliction LifeTap blocked at full mana")
    local c3, s3 = built(affl, { mana_pct = 25, hp = 30 })
    assert_false(lt.matches(c3, s3), "affliction LifeTap blocked at low HP (safety floor)")
end

do
    local ns = make_ns()
    local destro = load_strategies("EaxRotations/classes/warlock/destruction_wotlk.lua", ns)
    local lt_i, lt = find(destro, "LifeTap")
    assert_eq(lt_i, #destro.strategies, "destruction LifeTap is the tail strategy")
    local c1, s1 = built(destro, { mana_pct = 25, hp = 90 })
    assert_true(lt.matches(c1, s1), "destruction LifeTap fires at low mana with healthy HP")
    local c2, s2 = built(destro, { mana_pct = 100, hp = 90 })
    assert_false(lt.matches(c2, s2), "destruction LifeTap blocked at full mana")
    local c3, s3 = built(destro, { mana_pct = 25, hp = 30 })
    assert_false(lt.matches(c3, s3), "destruction LifeTap blocked at low HP")
end

do
    local ns = make_ns()
    local demo = load_strategies("EaxRotations/classes/warlock/demonology_wotlk.lua", ns)
    local lt_i, lt = find(demo, "LifeTap")
    assert_eq(lt_i, #demo.strategies, "demonology LifeTap is the tail strategy")
    local c1, s1 = built(demo, { mana_pct = 25, hp = 90 })
    assert_true(lt.matches(c1, s1), "demonology LifeTap fires at low mana with healthy HP")
    local c2, s2 = built(demo, { mana_pct = 100, hp = 90 })
    assert_false(lt.matches(c2, s2), "demonology LifeTap blocked at full mana")
    local c3, s3 = built(demo, { mana_pct = 25, hp = 40 })
    assert_false(lt.matches(c3, s3), "demonology LifeTap blocked at low HP")
end

do
    local ns = make_ns()
    local leveling = load_strategies("EaxRotations/classes/warlock/leveling_wotlk.lua", ns)
    local _, lt = find(leveling, "LifeTap")
    local c1, s1 = built(leveling, { mana_pct = 25, hp = 90 })
    assert_true(lt.matches(c1, s1), "leveling LifeTap fires at low mana with healthy HP")
end

-- ============================================================================
-- (4) Conflagrate fires through the real debuff path; DoT refresh lanes gate
--     off while the max-rank debuffs are up (no re-cast spam)
-- ============================================================================
do
    local ns = make_ns()
    local destro = load_strategies("EaxRotations/classes/warlock/destruction_wotlk.lua", ns)
    local _, conf = find(destro, "Conflagrate")
    local _, immo = find(destro, "Immolate")
    ns.dot_map = { [47811] = 12 }  -- Immolate (WotLK max rank) up at 12s
    local c1, s1 = built(destro, { mana_pct = 90 })
    assert_true(conf.matches(c1, s1),
        "Conflagrate fires while the 47811 Immolate debuff is up (was a production never-lane)")
    assert_false(immo.matches(c1, s1),
        "Immolate refresh blocked while the max-rank debuff is up (no re-cast spam)")
    ns.dot_map = {}
    local c2, s2 = built(destro, { mana_pct = 90 })
    assert_false(conf.matches(c2, s2), "Conflagrate blocked when Immolate is absent")
    assert_true(immo.matches(c2, s2), "Immolate fires when the debuff is expired")
end

do
    local ns = make_ns()
    local affl = load_strategies("EaxRotations/classes/warlock/affliction_wotlk.lua", ns)
    local _, corr = find(affl, "Corruption")
    local _, haunt = find(affl, "Haunt")
    ns.dot_map = { [47813] = 8, [59164] = 8 }
    local c1, s1 = built(affl, { mana_pct = 90 })
    assert_false(corr.matches(c1, s1), "affliction Corruption refresh blocked while 47813 is up")
    assert_false(haunt.matches(c1, s1), "affliction Haunt refresh blocked while 59164 is up")
    ns.dot_map = {}
    local c2, s2 = built(affl, { mana_pct = 90 })
    assert_true(corr.matches(c2, s2), "affliction Corruption fires when 47813 is expired")
    assert_true(haunt.matches(c2, s2), "affliction Haunt fires when 59164 is expired")
end

print("PASS test_warlock_wotlk_live_fixes")
