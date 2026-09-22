-- What: Unit tests for EaxAutoQuester/shared/corpse_loot.lua — which corpses are worth looting
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Autoloot is decided by two object probes that answer different questions, and the rule
--      that combines them was wrong in both directions: requiring is_dead() hides a corpse that
--      still holds loot (it can report false — recorded live), while ignoring emptiness walks the
--      bot back to a body it already emptied every two seconds for minutes.
-- Safety: pure module + mocks; no production state is touched.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local corpse_loot = require("shared/corpse_loot")
local utils = require("utils_sylvanas")

-- One context per scenario. `loot_calls` counts the loot requests, which is the observable the
-- emptied-corpse loop produced (the same corpse "looted" every 2s forever).
local function scene(objects, me_pos)
    mock.reset()
    mock.create_player({ pos = me_pos or { x = 0, y = 0, z = 0 } })
    mock._objects = objects
    local ctx = {
        me = mock._player,
        objects = objects,
        utils = utils,
        now = 100.0,
        debug_log = function() end,
        log = function() end,
        object_scanner = { get_visible_objects = function() return objects end },
    }
    local loot_calls = 0
    ctx.loot_calls = function() return loot_calls end
    local _set_target = core.input.set_target
    local _loot_object = core.input.loot_object
    core.input.loot_object = function(t) loot_calls = loot_calls + 1; return true end
    ctx._restore = function()
        core.input.set_target = _set_target
        core.input.loot_object = _loot_object
    end
    return ctx
end

local function shared()
    return { _loot_cooldown = 0, _nav_destination = nil }
end

-- =============================================================================
-- C1 — the corpse that reported is_dead() false: autoloot must still loot it.
-- A corpse that still holds loot can report is_dead() false (the Stonetusk Boar loop in
-- do_action_state.lua is the recorded instance), and requiring is_dead() therefore stops
-- autoloot outright — the report was "why does it no longer auto loot after kill?".
-- can_be_looted() == true is proof on its own.
-- =============================================================================
do
    local body = mock.create_object({ pos = { x = 2, y = 0, z = 0 }, name = "Stonetusk Boar",
        unit = true, valid = true, dead = false, lootable = true, guid = "c1" })
    local ctx = scene({ body })
    local s = shared()
    local result = corpse_loot.try_loot_nearest_corpse(s, ctx)
    assert(result == "IDLE", "C1 FAIL: a lootable corpse that reports is_dead() false must be looted (got "
        .. tostring(result) .. ")")
    assert(ctx.loot_calls() == 1, "C1 FAIL: the loot request must be issued (got "
        .. tostring(ctx.loot_calls()) .. ")")
    ctx._restore()
    print("  C1 PASS: is_dead() false + lootable → looted (the probe that lies does not hide the corpse)")
end

-- =============================================================================
-- C2 — the emptied corpse underfoot: NOT looted again, and not walked back to.
-- =============================================================================
do
    local husk = mock.create_object({ pos = { x = 1, y = 0, z = 0 }, name = "Stonevault Shaman",
        unit = true, valid = true, dead = true, lootable = false, guid = "c2" })
    local ctx = scene({ husk })
    local s = shared()
    local result = corpse_loot.try_loot_nearest_corpse(s, ctx)
    assert(result == nil, "C2 FAIL: an emptied corpse must not be looted again (got "
        .. tostring(result) .. ")")
    assert(ctx.loot_calls() == 0, "C2 FAIL: no loot request may be issued for it")
    assert(s._nav_destination == nil, "C2 FAIL: an emptied corpse must not become a destination")
    ctx._restore()
    print("  C2 PASS: emptied corpse (is_dead true, not lootable) → nothing")
end

-- =============================================================================
-- C3 — has_loot() outranks a negative loot probe: a corpse that still contains loot is worth
-- walking to even when can_be_looted() says no (out of reach, or a probe this build answers
-- pessimistically). This is the other half of the same report for a class that kills at range:
-- every corpse is several yards away, and the corpse is the one thing that must not be skipped.
-- =============================================================================
do
    local distant = mock.create_object({ pos = { x = 15, y = 0, z = 0 }, name = "Rock Elemental",
        unit = true, valid = true, dead = true, lootable = false, has_loot = true, guid = "c3" })
    local ctx = scene({ distant })
    local s = shared()
    local result = corpse_loot.try_loot_nearest_corpse(s, ctx, 400, "[autoloot]")
    assert(result == "NAV", "C3 FAIL: a corpse that still holds loot must be walked to (got "
        .. tostring(result) .. ")")
    assert(s._nav_destination ~= nil, "C3 FAIL: the corpse must be the destination")
    assert(math.abs((s._nav_destination.x or 0) - 15) < 1,
        "C3 FAIL: the destination must be the corpse at 15yd")
    ctx._restore()
    print("  C3 PASS: has_loot() true + not lootable-in-place → NAV to the corpse")
end

-- =============================================================================
-- C4 — has_loot() false: nothing left in it, so neither loot nor walk, even though is_dead()
-- is true and the probe-less rule would have gone back to it.
-- =============================================================================
do
    local husk = mock.create_object({ pos = { x = 15, y = 0, z = 0 }, name = "Rock Elemental",
        unit = true, valid = true, dead = true, lootable = true, has_loot = false, guid = "c4" })
    local ctx = scene({ husk })
    local s = shared()
    local result = corpse_loot.try_loot_nearest_corpse(s, ctx, 400, "[autoloot]")
    assert(result == nil, "C4 FAIL: a corpse with nothing in it must be left alone (got "
        .. tostring(result) .. ")")
    assert(ctx.loot_calls() == 0, "C4 FAIL: no loot request for an empty corpse")
    ctx._restore()
    print("  C4 PASS: has_loot() false → neither looted nor walked to")
end

-- =============================================================================
-- C5 — a build with neither loot probe: the old dead-only rule still loots, so a missing method
-- can never silently disable autoloot.
-- =============================================================================
do
    local body = mock.create_object({ pos = { x = 2, y = 0, z = 0 }, name = "Stonetusk Boar",
        unit = true, valid = true, dead = true, guid = "c5" })
    body.can_be_looted = nil      -- this build does not expose the probe
    body.has_loot = nil
    local ctx = scene({ body })
    local s = shared()
    -- The scan is driven through the module; with the probes gone it must fall back to is_dead().
    local ok, result = pcall(corpse_loot.try_loot_nearest_corpse, s, ctx)
    assert(ok, "C5 FAIL: the scan must survive a build without either probe: " .. tostring(result))
    assert(result == "IDLE", "C5 FAIL: with no loot probes a dead unit must still be looted, got "
        .. tostring(result))
    assert(ctx.loot_calls() == 1, "C5 FAIL: the loot request must be issued")
    ctx._restore()
    print("  C5 PASS: no loot probe on this build → dead unit still looted")
end

-- =============================================================================
-- C6 — loot window open: the module stands down (the caller handles the window), so a window
-- that is up cannot be double-looted or driven by a second code path.
-- =============================================================================
do
    local body = mock.create_object({ pos = { x = 1, y = 0, z = 0 }, name = "Stonetusk Boar",
        unit = true, valid = true, dead = true, lootable = true, guid = "c6" })
    local ctx = scene({ body })
    local s = shared()
    local _count = core.game_ui.get_loot_item_count
    core.game_ui.get_loot_item_count = function() return 2 end
    local result = corpse_loot.try_loot_nearest_corpse(s, ctx)
    core.game_ui.get_loot_item_count = _count
    assert(result == nil, "C6 FAIL: with the loot window open the module must stand down (got "
        .. tostring(result) .. ")")
    assert(ctx.loot_calls() == 0, "C6 FAIL: no second loot request while the window is open")
    ctx._restore()
    print("  C6 PASS: loot window open → module stands down")
end

-- =============================================================================
-- C7 — the nearest lootable corpse wins, and the loot cooldown gates the 2s re-loot.
-- =============================================================================
do
    local near = mock.create_object({ pos = { x = 2, y = 0, z = 0 }, name = "Near",
        unit = true, valid = true, dead = true, lootable = true, guid = "c7n" })
    local far = mock.create_object({ pos = { x = 4, y = 0, z = 0 }, name = "Far",
        unit = true, valid = true, dead = true, lootable = true, guid = "c7f" })
    local ctx = scene({ far, near })
    local s = shared()
    assert(corpse_loot.try_loot_nearest_corpse(s, ctx) == "IDLE", "C7a FAIL: scene error")
    assert(ctx.loot_calls() == 1, "C7a FAIL: one loot request")
    assert(s._loot_cooldown == 102.0, "C7a FAIL: looting must arm the cooldown (got "
        .. tostring(s._loot_cooldown) .. ")")
    -- Inside the cooldown: nothing, even though both corpses are still lootable.
    local again = corpse_loot.try_loot_nearest_corpse(s, ctx)
    assert(again == nil, "C7b FAIL: the loot cooldown must gate the next scan (got "
        .. tostring(again) .. ")")
    assert(ctx.loot_calls() == 1, "C7b FAIL: no second loot request inside the cooldown")
    ctx._restore()
    print("  C7 PASS: nearest corpse looted, then the 2s cooldown gates the scan")
end

print("PASS test_corpse_loot")
os.exit(0)
