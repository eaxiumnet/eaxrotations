-- What: Unit tests for bag fullness → force vendor trigger (D.build deliverable)
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify loot triggers flag at 80% fullness, coordinator NAV transitions,
--      vendor_manager aggressive sell, and flag cleared after vendor interaction
-- Exercises: loot_manager.auto_loot_all(), vendor_manager.should_sell_junk/sell_junk/handle_vendor,
--            coordinator.update() with _force_vendor_soon flag
-- API reference: mock_core inventory (get_num_bag_slots, get_items_in_bag), core.time

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- Ensure _G.EaxAutoQuester exists (modules create it, but guard for standalone runs)
_G.EaxAutoQuester = _G.EaxAutoQuester or {}

-- Helper: create a mock bag item with a given item_id
local function make_item(item_id)
    return {
        object = { get_item_id = function() return item_id end },
        slot_id = item_id,  -- unique per item_id for test determinism
    }
end

-- Helper: fill all bags to a given item count per bag
local function fill_bags(item_count, override_mock)
    local m = override_mock or mock
    m._bag_items = {}
    local item_counter = 1
    for bag_id = 0, 4 do
        m._bag_items[bag_id] = {}
        for i = 1, item_count do
            m._bag_items[bag_id][i] = make_item(1000 + item_counter)
            item_counter = item_counter + 1
        end
    end
end

-- ============================================================================
-- S1: bag ≥80% full after loot → _force_vendor_soon flag set
-- ============================================================================
do
    mock.reset()
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = nil
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })

    -- 5 bags × 16 slots = 80 total. 13 items/bag = 65/80 = 81.25%
    mock._bag_slots = { [0] = 16, [1] = 16, [2] = 16, [3] = 16, [4] = 16 }
    fill_bags(13)

    -- Lootable object within range
    local obj = mock.create_object({ pos = { x = 2, y = 0, z = 0 }, lootable = true, valid = true, unit = true })
    mock._objects = { obj }

    -- Bypass 0.5s throttle
    mock.set_time(1.0)

    local loot_manager = require("loot_manager_sylvanas")
    local result = loot_manager.auto_loot_all(5)
    assert(result == true, "S1: auto_loot_all should return true with lootable object")

    local flag = _G.EaxAutoQuester and _G.EaxAutoQuester._force_vendor_soon
    assert(flag == true, "S1 FAIL: _force_vendor_soon should be true when bag ≥80% full after loot. Got " .. tostring(flag))
    print("  S1 PASS: bag 80% full after loot → _force_vendor_soon = true")

    -- The trigger records WHY it asked for the visit. The coordinator reports this string
    -- verbatim (S7), and the other caller — the gathering reserve — sets it to its own cause
    -- (S6e); without it the coordinator could only ever blame the fullness threshold.
    local reason = _G.EaxAutoQuester._force_vendor_reason
    assert(reason == "bags 81% full (profile threshold 80%)",
        "S1c FAIL: the fullness trigger must record its own cause, got " .. tostring(reason))
    print("  S1c PASS: the fullness trigger records its reason (81% vs 80% threshold)")
end

-- ============================================================================
-- S1b: the live corpse-loot path reaches the same force-vendor owner
-- ============================================================================
do
    mock.reset()
    mock.install_inventory_helper()
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = nil
    mock._bag_slots = { [0] = 16, [1] = 16, [2] = 16, [3] = 16, [4] = 16 }
    fill_bags(13)

    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local corpse = mock.create_object({
        pos = { x = 2, y = 0, z = 0 }, name = "Fresh Corpse",
        unit = true, valid = true, dead = true, lootable = true,
    })
    mock._objects = { corpse }
    local corpse_loot = require("shared/corpse_loot")
    local utils = require("utils_sylvanas")
    local shared = { _loot_cooldown = 0 }
    local ctx = {
        me = player, now = 10.0, utils = utils, debug_log = function() end,
        object_scanner = { get_visible_objects = function() return mock._objects end },
    }

    assert(corpse_loot.try_loot_nearest_corpse(shared, ctx) == "IDLE",
        "S1b FAIL: the live corpse path must loot a nearby corpse")
    assert(_G.EaxAutoQuester._force_vendor_soon == true,
        "S1b FAIL: live corpse loot must reach the existing force-vendor state")
    local looted = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "loot_object" and call[2] == corpse then looted = true end
    end
    assert(looted, "S1b FAIL: the live corpse path did not issue the corpse loot request")
    print("  S1b PASS: live corpse loot raises the existing force-vendor state")
end

-- ============================================================================
-- S2: bag 50% full → no flag
-- ============================================================================
do
    mock.reset()
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = nil
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })

    -- 5 bags × 16 slots = 80 total. 8 items/bag = 40/80 = 50%
    mock._bag_slots = { [0] = 16, [1] = 16, [2] = 16, [3] = 16, [4] = 16 }
    fill_bags(8)

    local obj = mock.create_object({ pos = { x = 2, y = 0, z = 0 }, lootable = true, valid = true, unit = true })
    mock._objects = { obj }

    mock.set_time(2.0)  -- different time to avoid throttle collision with S1

    local loot_manager = require("loot_manager_sylvanas")
    loot_manager.auto_loot_all(5)

    local flag = _G.EaxAutoQuester and _G.EaxAutoQuester._force_vendor_soon
    assert(flag == nil, "S2 FAIL: _force_vendor_soon should be nil when bag 50% full. Got " .. tostring(flag))
    print("  S2 PASS: bag 50% full → no flag")
end

-- S2b: the active character profile owns the bag-fullness threshold; 90% must not trip at 87%.
-- ============================================================================
do
    local profile = require("character_profile_sylvanas")
    profile.reset()
    local profile_menu = { _values = {} }
    function profile_menu.get(key, fallback)
        local value = profile_menu._values[key]
        if value == nil then return fallback end
        return value
    end
    function profile_menu.set(key, value) profile_menu._values[key] = value end

    mock.reset()
    local hero = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    hero.get_name = function() return "VendorProfileHero" end
    hero.get_realm_name = function() return "TestRealm" end
    assert(profile.activate_for(hero, profile_menu), "S2b FAIL: vendor profile did not activate")
    profile_menu.set("profile_vendor_bag_threshold", 90)
    assert(profile.sync_active(profile_menu), "S2b FAIL: vendor profile did not synchronize")

    mock._bag_slots = { [0] = 16, [1] = 16, [2] = 16, [3] = 16, [4] = 16 }
    fill_bags(14) -- 70/80 = 87%
    local loot_manager = require("loot_manager_sylvanas")
    _G.EaxAutoQuester._force_vendor_soon = nil
    assert(loot_manager.refresh_force_vendor_state() == false,
        "S2b FAIL: 87% must stay below a 90% character threshold")
    assert(_G.EaxAutoQuester._force_vendor_soon == nil,
        "S2b FAIL: below-threshold refresh raised the force-vendor flag")

    fill_bags(15) -- 75/80 = 93%
    assert(loot_manager.refresh_force_vendor_state() == true,
        "S2c FAIL: 93% must trip a 90% character threshold")
    assert(_G.EaxAutoQuester._force_vendor_soon == true,
        "S2d FAIL: threshold refresh did not raise the force-vendor flag")
    print("  S2b PASS: profile vendor threshold drives the shared force-vendor owner")
    profile.reset()
end

-- ============================================================================
-- S3: coordinator sees flag → transitions to NAV toward vendor
-- ============================================================================
do
    mock.reset()
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })

    -- Pre-load mock state handlers (all return current state to not interfere)
    local noop_handler = { run = function() return nil end }
    package.loaded["quest_state/idle_state"] = { run = function(shared, ctx) return "IDLE" end }
    package.loaded["quest_state/nav_state"] = noop_handler
    package.loaded["quest_state/interact_state"] = noop_handler
    package.loaded["quest_state/do_action_state"] = noop_handler
    package.loaded["quest_state/waiting_state"] = noop_handler
    package.loaded["quest_state/dead_state"] = noop_handler

    -- Pre-load mock npc_db with find_transport_npc.
    -- Key must match the name production requires (bare module name, as used by
    -- coordinator/idle_state/do_action_state); the old dotted key was never read,
    -- so the stub was dead and the coordinator fell through to the real npc_db.
    package.loaded["npc_db_sylvanas"] = {
        find_transport_npc = function(kind)
            if kind == "vendor" then
                return { x = 100, y = 200, z = 0 }
            end
            return nil
        end,
    }

    -- Set the force vendor flag
    _G.EaxAutoQuester._force_vendor_soon = true

    -- Load coordinator and run update
    local coordinator = require("quest_state/coordinator")
    coordinator.update()

    -- Verify state transition via test accessor
    local state, dest = coordinator._test_inspect()
    assert(state == "NAV", "S3 FAIL: coordinator should transition to NAV when flag set. Got state=" .. tostring(state))
    assert(dest ~= nil, "S3 FAIL: nav destination should be set. Got " .. tostring(dest))
    assert(dest.x == 100, "S3 FAIL: nav dest x should be vendor x=100. Got " .. tostring(dest and dest.x))
    print("  S3 PASS: coordinator sees flag → transitions to NAV toward vendor")
end

-- ============================================================================
-- S4: vendor_manager sells aggressively when flag is set
-- ============================================================================
do
    mock.reset()
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })

    -- Setup menu: vendor_threshold = 1 (Grey only → quality ≤ 1 = grey + white)
    _G.EaxAutoQuester.menu = {
        get = function(key)
            if key == "vendor_threshold" then return 1 end
            return nil
        end,
    }

    -- Custom get_item_info: quality 2 = green (should NOT sell normally, SHOULD sell with flag)
    mock.quests.get_item_info = function(id)
        if id == 300 then
            return { quality = 2, sell_price = 10 }  -- green item
        end
        if id == 100 then
            return { quality = 0, sell_price = 1 }   -- grey item
        end
        return { quality = 0, sell_price = 1 }
    end

    local vendor_manager = require("vendor_manager_sylvanas")

    -- Without flag: green item (quality=2) should NOT be detected with threshold=1
    _G.EaxAutoQuester._force_vendor_soon = nil
    mock._bag_items = { [0] = { make_item(300) } }  -- green item
    local result_no_flag = vendor_manager.should_sell_junk()
    assert(result_no_flag == false,
        "S4a FAIL: without flag, green item should not trigger sell. Got " .. tostring(result_no_flag))
    print("  S4a PASS: without flag, green item NOT sold (quality 2 > threshold 1)")

    -- With flag: green item SHOULD be detected (effective threshold ≥ 3)
    _G.EaxAutoQuester._force_vendor_soon = true
    mock._bag_items = { [0] = { make_item(300) } }
    local result_with_flag = vendor_manager.should_sell_junk()
    assert(result_with_flag == true,
        "S4b FAIL: with flag, green item should trigger sell. Got " .. tostring(result_with_flag))
    print("  S4b PASS: with flag, green item detected (aggressive threshold)")

    -- Verify sell_junk actually sells the item
    mock._input_calls = {}
    local sold = vendor_manager.sell_junk()
    assert(sold >= 1, "S4c FAIL: sell_junk should sell at least 1 item with flag. Got sold=" .. tostring(sold))
    -- Verify the sale names the item through the documented (bag_id, bag_slot) pair. The raw
    -- core.inventory slot_id (300 here) must never reach use_container_item: "Passing a raw
    -- slot_id straight from get_items_in_bag targets the item NEXT to the one you meant"
    -- (.api/core.lua:1749-1750) — in a sale, someone else's item.
    local sell_calls = 0
    local sell_bag, sell_slot = nil, nil
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "use_container_item" then
            sell_calls = sell_calls + 1
            sell_bag, sell_slot = call[2], call[3]
        end
    end
    assert(sell_calls >= 1,
        "S4c FAIL: sell_junk should make use_container_item calls. Got " .. tostring(sell_calls))
    local pair = mock.build_bag_slots()[1]
    assert(sell_bag == pair.bag_id,
        "S4d FAIL: bag_id should come from inventory_helper; got " .. tostring(sell_bag))
    assert(sell_slot == pair.bag_slot,
        "S4e FAIL: bag_slot should come from inventory_helper (" .. tostring(pair.bag_slot) ..
        "), got " .. tostring(sell_slot))
    assert(sell_slot ~= make_item(300).slot_id,
        "S4f FAIL: the raw core.inventory slot_id must never be passed as the bag slot")
    print("  S4c PASS: sell_junk sells through the documented (bag_id, bag_slot) pair")
end

-- ============================================================================
-- S5: flag cleared after vendor interaction completes
-- ============================================================================
do
    mock.reset()
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })

    -- Setup vendor frame open
    mock._vendor_items = { { item_name = "Test Item", vendor_item_index = 1 } }
    mock._repair_cost = 0
    mock._gold = 1000
    mock._bag_items = {}

    _G.EaxAutoQuester._force_vendor_soon = true
    _G.EaxAutoQuester._force_vendor_reason = "gathering blocked: 1 free bag slot(s), reserve 4"

    local vendor_manager = require("vendor_manager_sylvanas")
    vendor_manager.handle_vendor()

    local flag_after = _G.EaxAutoQuester._force_vendor_soon
    assert(flag_after == nil,
        "S5 FAIL: _force_vendor_soon should be cleared after vendor interaction. Got " .. tostring(flag_after))
    -- The reason belongs to the flag. Clearing one without the other would make the NEXT
    -- request (S8c) report a cause that was already served.
    local reason_after = _G.EaxAutoQuester._force_vendor_reason
    assert(reason_after == nil,
        "S5b FAIL: the reason must be cleared with the flag, got " .. tostring(reason_after))
    print("  S5 PASS: flag and its reason both cleared after vendor interaction completes")
end

-- ============================================================================
-- S6: a bag-blocked gather routes to a vendor end to end.
-- S1-S3 prove the two halves separately (loot raises the flag; the coordinator walks to the
-- vendor when the flag is set while IDLE). This composes them through the REAL gathering block:
-- a character whose bags are below their gather reserve must raise the same flag, stay IDLE so
-- the coordinator's force-vendor route can fire, and end up NAVing to the vendor — without the
-- fullness threshold ever being reached.
-- ============================================================================
do
    mock.reset()
    mock.install_inventory_helper()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, hp = 10000, max_hp = 10000,
        mana = 10000, max_mana = 10000 })
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = nil

    -- The real profile, with Herbalism detected and the default 4-slot reserve.
    local profile = require("character_profile_sylvanas")
    local hero = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    hero.get_name = function() return "VendorHero" end
    hero.get_realm_name = function() return "TestRealm" end
    local profile_menu = { _values = {} }
    function profile_menu.get(k, fb) local v = profile_menu._values[k]; if v == nil then return fb end; return v end
    function profile_menu.set(k, v) profile_menu._values[k] = v end
    profile_menu._values.profile_gather_herbalism = true
    profile_menu._values.profile_gather_min_free_slots = 4
    assert(profile.activate_for(hero, profile_menu), "S6 FAIL: the profile did not activate")

    -- 16-slot backpack with 15 used => 1 free, below the reserve of 4, and nowhere near the
    -- 80% fullness threshold the normal vendor trigger uses.
    mock._helper_used = 15

    local node = mock.create_object({ pos = { x = 4, y = 0, z = 0 }, name = "Silverleaf",
        unit = false, valid = true, guid = "s6_herb" })
    -- S3 left a stub in package.loaded for idle_state; clear it so the REAL module runs the
    -- gathering block here (a stub that just returns "IDLE" would pass S6a without ever
    -- raising the flag).
    package.loaded["quest_state/idle_state"] = nil
    local idle_state = require("quest_state/idle_state")
    local shared = { _state = "IDLE", _interact_cooldown = 0, _loot_cooldown = 0,
        _last_cooldown_log = 0, _last_step_num = 1, _respawn_wait_until = 0 }
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function()
                return { is_complete = true, goals = {}, step_num = 1 }
            end,
            get_current_waypoint_world = function() return nil end,
            get_step_waypoints_world = function() return {} end,
        },
        object_scanner = { get_visible_objects = function() return { node } end },
        nav = { is_navigating = function() return false end, stop = function() end },
        utils = require("utils_sylvanas"),
        me = hero,
        now = 100.0,
        debug_log = function() end,
        log = function() end,
        safe = function(v, fb) if v == nil then return fb end; return v end,
        detect_open_frame = function() return false end,
    }

    local state = idle_state.run(shared, ctx)
    assert(state == "IDLE",
        "S6a FAIL: a bag-blocked gather must stay IDLE for the vendor route, got " .. tostring(state))
    assert(_G.EaxAutoQuester._force_vendor_soon == true,
        "S6b FAIL: a bag-blocked gather below the threshold must still request a vendor visit")

    -- Now hand the raised flag to the real coordinator and prove it walks to the vendor.
    package.loaded["quest_state/idle_state"] = { run = function() return "IDLE" end }
    local noop_handler = { run = function() return nil end }
    package.loaded["quest_state/nav_state"] = noop_handler
    package.loaded["quest_state/interact_state"] = noop_handler
    package.loaded["quest_state/do_action_state"] = noop_handler
    package.loaded["quest_state/waiting_state"] = noop_handler
    package.loaded["quest_state/dead_state"] = noop_handler
    package.loaded["npc_db_sylvanas"] = {
        find_transport_npc = function(kind)
            if kind == "vendor" then return { x = 100, y = 200, z = 0 } end
            return nil
        end,
    }
    package.loaded["quest_state/coordinator"] = nil
    -- Debug on, so the coordinator's own log line reaches core.log (utils.debug_log gates on
    -- this flag). ensure_menu caches its module on first use, so the stub must be installed
    -- before the coordinator is required, not after.
    package.loaded["menu_sylvanas"] = {
        get = function(key, fallback)
            if key == "debug" then return true end
            if key == "profile_vendor_bag_threshold" then return 80 end
            return fallback
        end,
    }
    local coordinator = require("quest_state/coordinator")
    coordinator.update()
    local coord_state, dest = coordinator._test_inspect()
    assert(coord_state == "NAV",
        "S6c FAIL: the coordinator must walk to a vendor on a proactive request, got " ..
        tostring(coord_state))
    assert(dest and dest.x == 100,
        "S6d FAIL: the vendor destination was not published (got " .. tostring(dest and dest.x) .. ")")

    -- The bug this pins: the gathering route is what asked for the visit, so THAT is what the
    -- log line must say. It used to print the 80% fullness threshold, which sent anyone reading
    -- the line to bags that were nearly empty.
    assert(mock.log_contains("force vendor — gathering blocked"),
        "S6e FAIL: the force-vendor line must name the gathering reserve, not the threshold; logs: " ..
        table.concat(mock._logs, " | "))
    assert(not mock.log_contains("force vendor — bags >="),
        "S6f FAIL: the force-vendor line fell back to the fullness threshold: " ..
        table.concat(mock._logs, " | "))
    print("  S6 PASS: a bag-blocked gather below the threshold routes to a vendor end to end,")
    print("         and the log line reports the gathering cause")
end

-- ============================================================================
-- S7: the fullness path reaches the same log line with its OWN reason.
-- S6 proves the gathering cause. This proves the other raiser is not overwritten by a hardcoded
-- threshold: an ordinary over-threshold loot must report the bags that tripped it.
-- ============================================================================
do
    mock.reset()
    mock.install_inventory_helper()
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = nil
    _G.EaxAutoQuester._force_vendor_reason = nil
    mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    -- No character profile in this block, so the documented 80% default is the threshold.
    require("character_profile_sylvanas").reset()

    mock._bag_slots = { [0] = 16, [1] = 16, [2] = 16, [3] = 16, [4] = 16 }
    fill_bags(13) -- 65/80 = 81%
    mock._helper_used = 65

    local obj = mock.create_object({ pos = { x = 2, y = 0, z = 0 }, lootable = true, valid = true, unit = true })
    mock._objects = { obj }
    -- The loot module is already loaded from S1 and keeps its 0.5s scan throttle, so this must
    -- be well past S1's t=1.0 rather than repeating it.
    mock.set_time(50.0)

    local loot_manager = require("loot_manager_sylvanas")
    assert(loot_manager.auto_loot_all(5) == true, "S7a FAIL: the lootable object was not looted")
    assert(_G.EaxAutoQuester._force_vendor_soon == true,
        "S7b FAIL: an over-threshold loot must still raise the force-vendor flag")

    package.loaded["quest_state/idle_state"] = { run = function() return "IDLE" end }
    local noop_handler = { run = function() return nil end }
    package.loaded["quest_state/nav_state"] = noop_handler
    package.loaded["quest_state/interact_state"] = noop_handler
    package.loaded["quest_state/do_action_state"] = noop_handler
    package.loaded["quest_state/waiting_state"] = noop_handler
    package.loaded["quest_state/dead_state"] = noop_handler
    package.loaded["npc_db_sylvanas"] = {
        find_transport_npc = function(kind)
            if kind == "vendor" then return { x = 100, y = 200, z = 0 } end
            return nil
        end,
    }
    package.loaded["menu_sylvanas"] = {
        get = function(key, fallback)
            if key == "debug" then return true end
            return fallback
        end,
    }
    package.loaded["quest_state/coordinator"] = nil
    require("quest_state/coordinator").update()

    assert(mock.log_contains("force vendor — bags 81% full (profile threshold 80%)"),
        "S7c FAIL: the over-threshold path must report the bags that tripped it; logs: " ..
        table.concat(mock._logs, " | "))
    assert(not mock.log_contains("gathering blocked"),
        "S7d FAIL: the loot path reported the gathering cause: " .. table.concat(mock._logs, " | "))
    print("  S7 PASS: the fullness path reports its own cause on the same log line")
end

-- ============================================================================
-- S8: a flag raised with no recorded reason still logs something true.
-- The reason is owned by the raisers, but the flag is public: a third party (or an older
-- session) can set it with no reason. The coordinator then falls back to the character
-- threshold, and the number it prints must come from the menu rather than a literal 80.
-- ============================================================================
do
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}

    local noop_handler = { run = function() return nil end }
    package.loaded["quest_state/idle_state"] = { run = function() return "IDLE" end }
    package.loaded["quest_state/nav_state"] = noop_handler
    package.loaded["quest_state/interact_state"] = noop_handler
    package.loaded["quest_state/do_action_state"] = noop_handler
    package.loaded["quest_state/waiting_state"] = noop_handler
    package.loaded["quest_state/dead_state"] = noop_handler
    package.loaded["npc_db_sylvanas"] = {
        find_transport_npc = function(kind)
            if kind == "vendor" then return { x = 100, y = 200, z = 0 } end
            return nil
        end,
    }
    package.loaded["menu_sylvanas"] = {
        get = function(key, fallback)
            if key == "debug" then return true end
            -- A non-default threshold, so a hardcoded 80 in the fallback would be visible.
            if key == "profile_vendor_bag_threshold" then return 65 end
            return fallback
        end,
    }

    -- S8a: no reason at all.
    _G.EaxAutoQuester._force_vendor_soon = true
    _G.EaxAutoQuester._force_vendor_reason = nil
    package.loaded["quest_state/coordinator"] = nil
    require("quest_state/coordinator").update()
    assert(mock.log_contains("force vendor — bags >= 65% full"),
        "S8a FAIL: a reasonless flag must fall back to the character threshold; logs: " ..
        table.concat(mock._logs, " | "))

    -- S8b: an empty reason is not a reason — it must take the same fallback, not print a bare dash.
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = true
    _G.EaxAutoQuester._force_vendor_reason = ""
    package.loaded["quest_state/coordinator"] = nil
    require("quest_state/coordinator").update()
    assert(mock.log_contains("force vendor — bags >= 65% full"),
        "S8b FAIL: an empty reason must take the threshold fallback; logs: " ..
        table.concat(mock._logs, " | "))

    -- S8c: a reason that is not a string (a number from a careless caller) also falls back
    -- rather than blowing up in the middle of the tick.
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = true
    _G.EaxAutoQuester._force_vendor_reason = 42
    package.loaded["quest_state/coordinator"] = nil
    require("quest_state/coordinator").update()
    assert(mock.log_contains("force vendor — bags >= 65% full"),
        "S8c FAIL: a non-string reason must take the threshold fallback; logs: " ..
        table.concat(mock._logs, " | "))
    print("  S8 PASS: a missing, empty, or malformed reason falls back to the menu threshold")
end

print("PASS test_vendor_bag_trigger")
os.exit(0)
