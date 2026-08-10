-- test_combat_log_parser_regression.lua — pins the rolling combat-log buffer.
-- WHAT:  Exercises shared/combat_log_parser_sylvanas.lua's ring-buffer
--        semantics: head/tail bounds, prune eviction boundary (off-by-one at
--        exactly WINDOW_SECONDS), compact_if_needed compaction, nil guards,
--        empty/single/full states, timestamp ordering, per-unit/ability/
--        summary aggregation, and the subscriber hook. The module feeds
--        main.lua's damage meter and ttd_ema_tracker_sylvanas and previously
--        had ZERO test references — its prune/compact/head-tail arithmetic is
--        exactly the off-by-one class this repo guards elsewhere.
-- WHEN:  rotation suite execution.
-- WHY:   a future edit to prune/compact/get_last_n could silently drop or
--        duplicate events on the eviction boundary; this test fails if the
--        buffer arithmetic regresses.
-- SAFETY: Pure unit test. The module caches _G.core.time at load, so the test
--        installs a controllable mock clock BEFORE dofile and never touches
--        the real SDK (the module also loads cleanly with no core at all).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

-- Controllable mock clock. The parser caches _G.core.time at require time, so
-- installing core BEFORE dofile is the only way to drive now_seconds().
local now = 0.0
local registered_spell_callback = nil
_G.core = {
    time = function() return now end,
    spell_book = {
        get_spell_name = function(id) return "spell_" .. tostring(id) end,
    },
    register_on_spell_cast_callback = function(cb) registered_spell_callback = cb end,
}

local clp = dofile("EaxRotations/shared/combat_log_parser_sylvanas.lua")
assert_true(type(clp) == "table", "combat_log_parser must load under mock core")
assert_eq(registered_spell_callback, clp._handle_spell_cast,
    "module registers _handle_spell_cast with core when the hook exists")

-- Fresh buffer helpers -------------------------------------------------------
local function push(spell_id, cast_time, overrides)
    local data = { spell_id = spell_id, spell_cast_time = cast_time }
    if overrides then
        for k, v in pairs(overrides) do data[k] = v end
    end
    clp._handle_spell_cast(data)
end

local function names(events)
    local out = {}
    for i = 1, #events do out[i] = events[i].spell_id end
    return out
end

-- ---------------------------------------------------------------------------
-- 1. Empty state
-- ---------------------------------------------------------------------------
assert_eq(#clp.get_last_n_events(10), 0, "empty buffer: no events")
assert_eq(#clp.get_last_n_events(-1), 0, "negative n returns empty")
assert_eq(#clp.get_last_n_events(0), 0, "zero n returns empty")
assert_eq(#clp.get_events_by_spell(1), 0, "empty buffer: no spell events")
assert_eq(#clp.get_events_by_target("anyone"), 0, "empty buffer: no target events")
assert_eq(clp.get_top_damage_abilities(30, "player").total_damage, 0, "empty buffer: zero top damage")
local s0 = clp.get_summary_for_window(30)
assert_eq(s0.total_events, 0, "empty buffer: zero summary events")
assert_eq(s0.dps, 0, "empty buffer: zero dps")

-- ---------------------------------------------------------------------------
-- 2. Push + newest-first ordering + window filter
-- ---------------------------------------------------------------------------
now = 200
for i = 1, 6 do push(100 + i, 150 + i) end  -- spell ids 101..106 at t=151..156
local last3 = clp.get_last_n_events(3)
assert_eq(#last3, 3, "get_last_n_events caps at n")
assert_eq(names(last3)[1], 106, "newest first")
assert_eq(names(last3)[2], 105, "second newest")
assert_eq(names(last3)[3], 104, "third newest")

-- Read window uses the WALL clock (now=200): cutoff = 200 - 60 = 140.
assert_eq(#clp.get_events_by_spell(101), 1, "spell filter finds in-window entry")
assert_eq(#clp.get_events_by_spell(999), 0, "spell filter misses unknown")

-- ---------------------------------------------------------------------------
-- 3. Prune boundary — the off-by-one at exactly WINDOW_SECONDS (60)
--    prune is driven by each pushed entry's OWN timestamp (cutoff = T - 60):
--    an entry exactly 60s old survives (>= cutoff); 60s + epsilon evicts it.
-- ---------------------------------------------------------------------------
now = 300
push(201, 300)                 -- single entry at t=300
push(202, 360)                 -- cutoff = 300: entry 201 (t=300) is exactly on the boundary
local after60 = clp.get_events_by_spell(201)
assert_eq(#after60, 1, "entry exactly 60s old survives the prune boundary (>= cutoff)")
push(203, 360.1)               -- cutoff = 300.1: entry 201 (t=300) is now 60.1s old
assert_eq(#clp.get_events_by_spell(201), 0, "entry 60.1s old is pruned (off-by-one boundary)")
assert_eq(#clp.get_events_by_spell(202), 1, "newer entry survives after eviction")
assert_eq(#clp.get_events_by_spell(203), 1, "latest entry present")

-- ---------------------------------------------------------------------------
-- 4. Nil guards: bad casts, missing fields, MISS/CRIT classification
-- ---------------------------------------------------------------------------
local before = #clp.get_last_n_events(50)
push(nil, 400)                       -- nil spell_id -> build_entry returns nil, not pushed
push("not-a-number", 400)            -- non-numeric spell_id -> nil, not pushed
assert_eq(#clp.get_last_n_events(50), before, "nil / non-numeric spell_id casts are dropped")

now = 500
push(301, 500, { amount = 0 })                 -- zero amount -> DAMAGE kind, amount 0
push(302, 500, { result = "MISS" })            -- MISS classification
push(303, 500, { is_crit = true, heal = 42 })  -- crit heal
local last = clp.get_last_n_events(3)
assert_eq(last[3].amount_kind, "DAMAGE", "zero-amount entry classifies DAMAGE")
assert_eq(last[3].amount, 0, "zero-amount entry amount 0")
assert_eq(last[2].event_type, "MISS", "result MISS classifies event_type MISS")
assert_eq(last[1].amount_kind, "HEAL", "heal field classifies HEAL")
assert_eq(last[1].event_type, "CRIT", "is_crit classifies CRIT")

-- Unit-ish objects for caster/target resolve via get_name.
local unit = { get_name = function() return "PlayerOne" end }
push(304, 500, { caster = unit, target = unit, amount = 25 })
local by_target = clp.get_events_by_target(unit)
assert_eq(#by_target, 1, "unit-object target resolves by token")
assert_eq(by_target[1].target_token, "playerone", "target token normalized lower")

-- ---------------------------------------------------------------------------
-- 5. Compaction: force head > 64 so compact_if_needed rebuilds the buffer,
--    then verify reads stay correct (no nil holes, no lost entries).
-- ---------------------------------------------------------------------------
-- Fresh timestamps far ahead of everything so far (t >= 1000) evicts the old
-- 3xx/2xx/1xx entries in one shot when the first t=1000 entry lands, giving a
-- big front gap. Then push 70 more entries 1s apart (t=1001..1070): the front
-- gap persists and head climbs past 64 on each subsequent prune only if
-- timestamps exceed oldest+60 — spaced 1s apart they don't, so head stays
-- small. Instead drive head large directly: push 70 entries at t=1000+i and
-- then one entry 60s ahead (t=1100) evicts all but the last.
now = 1000
push(500, 1000)  -- evicts everything older than 940
for i = 1, 70 do push(500 + i, 1000 + i) end  -- t=1001..1070, all < 60s apart
-- All 71 entries survive (newest 1070, oldest 1000: 70s span — oldest is
-- 70s older than t=1070 only at the LAST push; at that push cutoff=1010, so
-- entries at 1000..1009 were evicted). Live set is t=1010..1070.
local live = clp.get_events_by_spell(501)  -- spell 501 pushed at t=1001 -> evicted
assert_eq(#live, 0, "pre-60s-window entry evicted during the 70-entry run")
-- Newest 10 must be exactly 1061..1070.
local last10 = clp.get_last_n_events(10)
assert_eq(#last10, 10, "compact-adjacent buffer returns 10")
assert_eq(names(last10)[1], 570, "newest after eviction run")
-- Force head past 64: evict everything but one entry in a single push.
push(999, 1200)  -- cutoff=1140 evicts all t<1140 (everything above) -> head jumps
local one = clp.get_last_n_events(10)
assert_eq(#one, 1, "single survivor after mass eviction")
assert_eq(one[1].spell_id, 999, "survivor is the newest entry")
-- The push at t=1200 triggered compact_if_needed (head > 64); reads must be
-- clean and complete (no nil holes / duplicated survivors).
assert_eq(#clp.get_last_n_events(100), 1, "post-compact buffer has no phantom entries")

-- ---------------------------------------------------------------------------
-- 6. Aggregation: per-unit, summary, replay, top abilities
-- ---------------------------------------------------------------------------
now = 2000
local a = { get_name = function() return "Alpha" end }
local b = { get_name = function() return "Beta" end }
push(600, 2000, { caster = a, target = b, amount = 100 })       -- Alpha damage 100
push(601, 2000.5, { caster = a, target = b, amount = 50, is_crit = true })  -- Alpha crit 50
push(602, 2001, { caster = b, target = a, is_heal = true, heal = 30 })  -- Beta heal 30

local per_unit = clp.get_dps_hps_per_unit(30)
assert_eq(per_unit["alpha"].damage, 150, "per-unit damage sums")
assert_eq(per_unit["alpha"].healing, 0, "per-unit healing zero for damager")
assert_eq(per_unit["alpha"].crits, 1, "per-unit crit count")
assert_eq(per_unit["beta"].healing, 30, "per-unit healing sums")
assert_eq(per_unit["beta"].damage, 0, "per-unit damage zero for healer")
assert_eq(per_unit["alpha"].events, 2, "per-unit event count")

local sum = clp.get_summary_for_window(30)
assert_eq(sum.total_events, 3, "summary total events")
assert_eq(sum.total_damage, 150, "summary total damage")
assert_eq(sum.total_healing, 30, "summary total healing")
assert_eq(sum.damage_events, 1, "summary damage events (crit counts as crit, not damage)")
assert_eq(sum.crit_events, 1, "summary crit events")
assert_eq(sum.per_unit["alpha"].crits, 1, "summary per-unit crits")

local top = clp.get_top_damage_abilities(30, a)
assert_eq(top.total_damage, 150, "top abilities total damage")
assert_eq(#top.abilities, 2, "top abilities for the Alpha caster")
assert_eq(top.abilities[1].spell_id, 600, "top ability is the higher-damage spell (damage desc)")
assert_eq(top.abilities[1].damage, 100, "top ability damage")
assert_eq(top.abilities[2].spell_id, 601, "second ability is the crit")
local pct = top.abilities[1].damage_pct
assert_true(math.abs(pct - (100 / 150 * 100)) < 0.001, "top ability damage pct (100/150)")
-- No caster -> empty result.
local notop = clp.get_top_damage_abilities(30, nil)
assert_eq(notop.total_damage, 0, "top abilities without caster returns empty")
assert_eq(#notop.abilities, 0, "top abilities without caster has no abilities")

local replay = clp.get_replay(30)
assert_eq(replay.total_events, 3, "replay includes window events")
assert_eq(replay.events[1].spell_id, 600, "replay order oldest-first")
assert_eq(replay.events[3].spell_id, 602, "replay third event")

-- ---------------------------------------------------------------------------
-- 7. Subscriber hook: fires per push, erroring callbacks are isolated
-- ---------------------------------------------------------------------------
local received = {}
clp.subscribe(function(entry) received[#received + 1] = entry.spell_id end)
clp.subscribe(function() error("boom") end)  -- must not break pushes
push(700, 2100)
assert_eq(#received, 1, "subscriber receives pushed entries")
assert_eq(received[1], 700, "subscriber receives the pushed spell")
push(701, 2100)
assert_eq(#received, 2, "subscriber still fires after a throwing sibling callback")

-- ---------------------------------------------------------------------------
-- 8. Clock-ahead semantics: reads use the wall clock; events pushed with old
--    timestamps survive pruning but are invisible to reads while now is ahead.
-- ---------------------------------------------------------------------------
now = 5000
push(800, 5000)  -- current
push(801, 4900)  -- 100s in the past by wall clock but 10s old by event time
assert_eq(#clp.get_events_by_spell(801), 0, "wall-clock-ahead hides stale-timestamp events from reads")
assert_eq(#clp.get_events_by_spell(800), 1, "current event still readable")
now = 4960  -- cutoff = 4900: entry 801 (t=4900) is exactly on the read boundary
assert_eq(#clp.get_events_by_spell(801), 1, "event exactly on the read cutoff boundary is visible")

print("PASS test_combat_log_parser_regression")
