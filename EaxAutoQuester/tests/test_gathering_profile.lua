-- test_gathering_profile.lua — opt-in profession routes from the real character profile.
-- WHAT: drives IDLE through profile-backed herbalism, mining, skinning, and fishing node routes.
-- WHEN: run via the isolated EaxAutoQuester suite runner.
-- WHY: stored preferences must affect real behavior without ever detouring away from an active quest goal.
-- SAFETY: uses the mock client only; the documented profession surface is modeled locally and no
--           network, persistence, or live client call is assumed.
-- DECISION: node recognition is conservative client-name classification and is bounded to nearby non-unit objects.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local profile = require("character_profile_sylvanas")
local idle_state = require("quest_state/idle_state")
local pull_safety = require("shared/pull_safety")
local utils = require("utils_sylvanas")

local profile_menu = { _values = {} }
function profile_menu.get(key, fallback)
    local value = profile_menu._values[key]
    if value == nil then return fallback end
    return value
end
function profile_menu.set(key, value) profile_menu._values[key] = value end

local hero = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
hero.get_name = function() return "GatherProfileHero" end
hero.get_realm_name = function() return "TestRealm" end
assert(profile.activate_for(hero, profile_menu), "G0 FAIL: gathering profile did not activate")

local function set_professions(herbalism, mining, skinning, fishing)
    profile_menu.set("profile_gather_herbalism", herbalism)
    profile_menu.set("profile_gather_mining", mining)
    profile_menu.set("profile_gather_skinning", skinning)
    profile_menu.set("profile_gather_fishing", fishing)
    assert(profile.sync_active(profile_menu), "G0 FAIL: profile did not synchronize")
end

local function set_reserve(slots)
    profile_menu.set("profile_gather_min_free_slots", slots)
    assert(profile.sync_active(profile_menu), "G0 FAIL: profile did not synchronize")
end

local function new_shared()
    -- The proactive vendor request raises the shared force-vendor flag on the global quester
    -- table; clear it so one scenario's pending visit cannot satisfy the next scenario's
    -- idempotency check.
    local ns = rawget(_G, "EaxAutoQuester")
    if type(ns) == "table" then ns._force_vendor_soon = nil end
    return {
        _state = "IDLE",
        _interact_cooldown = 0,
        _last_cooldown_log = 0,
        _loot_cooldown = 0,
        _last_step_num = 0,
        _nav_retries = 0,
        _action_pause_timer = 0,
        _area_wait_timer = 0,
        _post_interact_timer = 0,
        _at_quest_object_timer = 0,
        _respawn_wait_until = 0,
        _gather_target = nil,
        _gather_target_profession = nil,
        _gather_scan_at = 0,
        _gather_cooldown = 0,
    }
end

local function build_context(objects, opts)
    opts = opts or {}
    local me = mock.create_player({ pos = opts.player_pos or { x = 0, y = 0, z = 0 } })
    local step = opts.step or { is_complete = true, goals = {}, step_num = 1 }
    return {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return step end,
            get_current_waypoint_world = function() return opts.waypoint end,
        },
        object_scanner = {
            get_visible_objects = function() return objects end,
        },
        nav = { is_navigating = function() return false end, stop = function() end },
        utils = utils,
        me = me,
        now = opts.now or 100.0,
        debug_log = function() end,
        log = function() end,
        safe = function(value, fallback)
            if value == nil then return fallback end
            return value
        end,
        detect_open_frame = function() return false end,
        frame_signalled = false,
    }
end

-- G1: each opted-in profession recognizes its conservative node vocabulary and starts NAV.
local cases = {
    { profession = "herbalism", herb = true, name = "Silverleaf" },
    { profession = "mining", mining = true, name = "Copper Vein" },
    { profession = "skinning", skinning = true, name = "Fresh Carcass" },
    { profession = "fishing", fishing = true, name = "Mackerel School" },
}
for i = 1, #cases do
    local case = cases[i]
    mock.reset()
    pull_safety.reset()
    set_professions(case.herb == true, case.mining == true, case.skinning == true, case.fishing == true)
    local node = mock.create_object({
        pos = { x = 20, y = 0, z = 0 },
        name = case.name,
        unit = false,
        valid = true,
        guid = "gather_" .. tostring(i),
    })
    local shared = new_shared()
    local ctx = build_context({ node }, { now = 100.0 })
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "NAV", "G1" .. i .. " FAIL: opted-in " .. case.profession .. " did not NAV")
    assert(shared._gather_target == node,
        "G1" .. i .. " FAIL: " .. case.profession .. " target was not retained")
    assert(shared._gather_target_profession == case.profession,
        "G1" .. i .. " FAIL: wrong profession recorded")
    assert(shared._nav_destination == node:get_position(),
        "G1" .. i .. " FAIL: navigation destination is not the node")
end

-- G2: arrival uses the node, protects the cast/channel with the existing pause, and cools down.
do
    mock.reset()
    pull_safety.reset()
    set_professions(true, false, false, false)
    local node = mock.create_object({
        pos = { x = 4, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_near",
    })
    local shared = new_shared()
    local ctx = build_context({ node }, { now = 200.0 })
    assert(idle_state.run(shared, ctx) == "IDLE", "G2a FAIL: in-range node should be used immediately")
    local used = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "use_object" and call[2] == node then used = true end
    end
    assert(used, "G2b FAIL: in-range profession node was not used")
    assert(shared._gather_target == nil, "G2c FAIL: completed target remained active")
    assert(shared._post_interact_timer > ctx.now, "G2d FAIL: interaction pause was not armed")
    assert(shared._gather_cooldown > ctx.now, "G2e FAIL: gather cooldown was not armed")
    assert(shared._nav_destination == nil, "G2f FAIL: completed node destination remained")
end

-- G3: disabled professions and unknown object names never become gathering traffic.
for i = 1, 2 do
    mock.reset()
    pull_safety.reset()
    set_professions(false, true, false, false)
    local name = i == 1 and "Silverleaf" or "Quest Barrel"
    local node = mock.create_object({
        pos = { x = 10, y = 0, z = 0 }, name = name, unit = false, valid = true,
        guid = "gather_skip_" .. tostring(i),
    })
    local shared = new_shared()
    local next_state = idle_state.run(shared, build_context({ node }, { now = 300.0 }))
    assert(next_state == "WAITING",
        "G3" .. i .. " FAIL: disabled/unknown node must leave IDLE waiting")
    assert(shared._nav_destination == nil and shared._gather_target == nil,
        "G3" .. i .. " FAIL: disabled/unknown node published gathering state")
end

-- G4: an active quest goal outranks every enabled profession route.
do
    mock.reset()
    pull_safety.reset()
    set_professions(true, true, true, true)
    local node = mock.create_object({
        pos = { x = 4, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_quest_owned",
    })
    local step = {
        is_complete = false,
        step_num = 2,
        goals = { { type = "area", target = "A Different Quest Objective", npc_id = 0 } },
    }
    local shared = new_shared()
    local next_state = idle_state.run(shared, build_context({ node }, { step = step, now = 400.0 }))
    assert(next_state == "DO_ACTION",
        "G4a FAIL: active quest must dispatch DO_ACTION instead of gathering, got " .. tostring(next_state))
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "use_object",
            "G4b FAIL: profession route used a node while a quest goal was active")
    end
    assert(shared._gather_target == nil, "G4c FAIL: quest path acquired a gathering target")
end

-- G5: even with no goal, a guide waypoint outranks a nearby opted-in node.
do
    mock.reset()
    pull_safety.reset()
    set_professions(true, false, false, false)
    local node = mock.create_object({
        pos = { x = 4, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_waypoint_owned",
    })
    local waypoint = { x = 100, y = 0, z = 0 }
    local step = { is_complete = false, step_num = 3, goals = {} }
    local shared = new_shared()
    local next_state = idle_state.run(shared,
        build_context({ node }, { step = step, waypoint = waypoint, now = 450.0 }))
    assert(next_state == "NAV", "G5a FAIL: guide waypoint should still drive NAV")
    assert(shared._nav_destination == waypoint,
        "G5b FAIL: gathering route replaced the authoritative guide waypoint")
    assert(shared._gather_target == nil, "G5c FAIL: waypoint path acquired a gathering target")
end

-- G6: a node beyond the bounded 50yd scan remains untouched.
do
    mock.reset()
    pull_safety.reset()
    set_professions(true, false, false, false)
    local node = mock.create_object({
        pos = { x = 60, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_far",
    })
    local shared = new_shared()
    local next_state = idle_state.run(shared, build_context({ node }, { now = 500.0 }))
    assert(next_state == "WAITING", "G6a FAIL: out-of-range profession node must not NAV")
    assert(shared._nav_destination == nil, "G6b FAIL: out-of-range node published a destination")
end

-- G7: a new profile auto-detects a learned Herbalism and the real IDLE route needs no manual setup.
do
    mock.reset()
    pull_safety.reset()
    profile.reset()
    mock._professions = { prof1 = 51 }
    mock._profession_info[51] = { name = "Herbalism", skill_line_name = "Herbalism" }
    assert(profile.activate_for(hero, profile_menu), "G7a FAIL: detected profile did not activate")
    assert(profile_menu._values.profile_gather_herbalism == true,
        "G7b FAIL: detected Herbalism was not applied to the menu")
    assert(profile.gathering_enabled("herbalism"),
        "G7c FAIL: detected Herbalism was not the effective profile policy")

    local node = mock.create_object({
        pos = { x = 20, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_detected",
    })
    local shared = new_shared()
    local next_state = idle_state.run(shared, build_context({ node }, { now = 600.0 }))
    assert(next_state == "NAV", "G7d FAIL: detected profession did not drive the real NAV route")
    assert(shared._gather_target_profession == "herbalism",
        "G7e FAIL: detected profession was not recorded on the route")
    assert(mock._profession_calls.get_professions == 1
        and mock._profession_calls.get_profession_info == 1,
        "G7f FAIL: profession discovery did not stay one-shot for a new profile")
    assert(profile.activate_for(hero, profile_menu) == false, "G7g FAIL: same character was reactivated")
    assert(mock._profession_calls.get_professions == 1,
        "G7h FAIL: re-activation re-ran profession discovery")
    local lines = 0
    for _ in ipairs(mock._logs) do
        if string.find(mock._logs[#mock._logs], "prof1=Herbalism", 1, true) then lines = lines + 1 end
    end
    assert(lines == 1, "G7i FAIL: exactly one startup diagnostic line must name the detected profession")
    assert(mock.log_contains("EaxAutoQuester professions [GatherProfileHero - TestRealm]"),
        "G7j FAIL: the startup diagnostic line did not identify the character")
end

-- G8: an unusable profession result leaves the manual off default and never gathers.
do
    mock.reset()
    pull_safety.reset()
    profile.reset()
    mock._professions = nil -- a build that answers the documented call with no table
    assert(profile.activate_for(hero, profile_menu), "G8a FAIL: fallback profile did not activate")
    assert(profile_menu._values.profile_gather_herbalism == false,
        "G8b FAIL: an unusable profession result enabled a route")
    local node = mock.create_object({
        pos = { x = 4, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_no_profession_api",
    })
    local shared = new_shared()
    local next_state = idle_state.run(shared, build_context({ node }, { now = 700.0 }))
    assert(next_state == "WAITING", "G8c FAIL: a node was gathered without a detected profession")
    assert(shared._gather_target == nil and shared._nav_destination == nil,
        "G8d FAIL: fallback published gathering state")
    assert(mock.log_contains("API returned no table"),
        "G8e FAIL: the diagnostic did not report why detection was unavailable")
end

-- G9: below the free-slot reserve, even an in-range node is never used and no route is published.
do
    mock.reset()
    pull_safety.reset()
    set_professions(true, false, false, false)
    mock._helper_used = 14 -- 16-slot backpack => 2 free, below the reserve of 4
    local node = mock.create_object({
        pos = { x = 4, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_bags_low",
    })
    local shared = new_shared()
    local next_state = idle_state.run(shared, build_context({ node }, { now = 800.0 }))
    assert(next_state == "IDLE",
        "G9a FAIL: a low-bag gather must stay IDLE so the vendor route can fire, got " .. tostring(next_state))
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "use_object", "G9b FAIL: a node was used with no free bag slots to spare")
    end
    assert(shared._gather_target == nil and shared._nav_destination == nil,
        "G9c FAIL: a low-bag check published gathering state")
    assert(_G.EaxAutoQuester._force_vendor_soon == true,
        "G9d FAIL: a bag-blocked gather must request a vendor visit to free space")
end

-- G9e: a vendor visit that freed nothing is paced, not repeated on the next blocked tick.
do
    mock.reset()
    pull_safety.reset()
    set_professions(true, false, false, false)
    mock._helper_used = 14
    local node = mock.create_object({
        pos = { x = 4, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_bags_paced",
    })
    local shared = new_shared()
    assert(idle_state.run(shared, build_context({ node }, { now = 800.0 })) == "IDLE",
        "G9e1 FAIL: the first blocked tick must request a vendor visit")
    -- The vendor handled the visit and cleared the flag, but the bags are still short.
    _G.EaxAutoQuester._force_vendor_soon = nil
    local second = idle_state.run(shared, build_context({ node }, { now = 801.0 }))
    assert(second == "WAITING",
        "G9e2 FAIL: a second request inside the retry window must wait, not thrash the vendor, got " ..
        tostring(second))
    assert(_G.EaxAutoQuester._force_vendor_soon == nil,
        "G9e3 FAIL: the vendor request was repeated inside the retry window")
end

-- G10: exactly at the reserve (4 free) an in-range node is still used — the gate is strictly "< 4".
do
    mock.reset()
    pull_safety.reset()
    set_professions(true, false, false, false)
    mock._helper_used = 12 -- 16 - 12 = 4 free, at the reserve
    local node = mock.create_object({
        pos = { x = 4, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_bags_reserve",
    })
    local shared = new_shared()
    local ctx = build_context({ node }, { now = 900.0 })
    assert(idle_state.run(shared, ctx) == "IDLE",
        "G10a FAIL: a node at the reserve should be used immediately")
    local used = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "use_object" and call[2] == node then used = true end
    end
    assert(used, "G10b FAIL: a node at exactly the reserve was not used")
end

-- G11: a target already in progress is abandoned (and its NAV cleared) once bags drop below reserve.
do
    mock.reset()
    pull_safety.reset()
    set_professions(true, false, false, false)
    mock._helper_used = 0 -- 16 free: first NAV to a far node
    local node = mock.create_object({
        pos = { x = 20, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_bags_abandon",
    })
    local shared = new_shared()
    local first = idle_state.run(shared, build_context({ node }, { now = 1000.0 }))
    assert(first == "NAV" and shared._gather_target == node,
        "G11a FAIL: a far node should NAV and retain its target while bags have room")
    assert(shared._nav_destination ~= nil, "G11b FAIL: NAV destination was not published")

    mock._helper_used = 15 -- 1 free, below reserve: the in-progress gather must be dropped
    local second = idle_state.run(shared, build_context({ node }, { now = 1001.0 }))
    assert(second ~= "NAV", "G11c FAIL: a low-bag check kept navigating to the node")
    assert(shared._gather_target == nil, "G11d FAIL: the in-progress target was not abandoned")
    assert(shared._nav_destination == nil, "G11e FAIL: the abandoned node's NAV destination was not cleared")
end

-- G12: a name-less, non-English profession info still drives the real route through its skill line.
do
    mock.reset()
    pull_safety.reset()
    profile.reset()
    mock._professions = { prof1 = 61 }
    mock._profession_info[61] = { name = "", skill_line_name = "", skill_line = 186, skill_level = 300 }
    assert(profile.activate_for(hero, profile_menu), "G12a FAIL: skill-line-only profile did not activate")
    assert(profile.gathering_enabled("mining"),
        "G12b FAIL: a name-less skill line did not enable the mining route")
    local node = mock.create_object({
        pos = { x = 20, y = 0, z = 0 }, name = "Copper Vein", unit = false, valid = true,
        guid = "gather_skill_line_only",
    })
    local shared = new_shared()
    assert(idle_state.run(shared, build_context({ node }, { now = 1100.0 })) == "NAV",
        "G12c FAIL: the skill-line-detected profession did not drive NAV")
    assert(shared._gather_target_profession == "mining",
        "G12d FAIL: the wrong profession was recorded for the skill-line-only route")
    assert(mock.log_contains("prof1=Mining [skill 186]"),
        "G12e FAIL: the diagnostic did not fall back to the canonical label for the skill line")
end

-- G13: the route honors THIS character's reserve from the profile slider, not a fixed constant.
do
    mock.reset()
    pull_safety.reset()
    set_professions(true, false, false, false)
    set_reserve(8)
    local node = mock.create_object({
        pos = { x = 4, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_reserve_ok",
    })
    -- 16 free >= this character's reserve of 8: the route still gathers.
    local roomy = new_shared()
    assert(idle_state.run(roomy, build_context({ node }, { now = 1200.0 })) == "IDLE",
        "G13a FAIL: above this character's reserve the node must be used")
    local used = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "use_object" and call[2] == node then used = true end
    end
    assert(used, "G13b FAIL: the node was not used while above the reserve")

    -- 6 free < reserve 8: the route stops (and asks for a vendor), even though the DEFAULT
    -- reserve of 4 would have allowed it.
    mock._input_calls = {}
    mock._helper_used = 10
    local tight = new_shared()
    local blocked = idle_state.run(tight, build_context({ node }, { now = 1300.0 }))
    assert(blocked == "IDLE",
        "G13c FAIL: below this character's reserve the route must stop and go vendor, got " ..
        tostring(blocked))
    assert(_G.EaxAutoQuester._force_vendor_soon == true,
        "G13c2 FAIL: a reserve-blocked gather must request a vendor visit")
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "use_object", "G13d FAIL: a node was used below the chosen reserve")
    end
    assert(tight._gather_target == nil, "G13e FAIL: a blocked reserve published a gathering target")
end

-- G14: a reserve of 0 is the slider's off position — the bag gate does not block at all.
do
    mock.reset()
    pull_safety.reset()
    set_professions(true, false, false, false)
    set_reserve(0)
    mock._helper_used = 16 -- zero free slots
    local node = mock.create_object({
        pos = { x = 4, y = 0, z = 0 }, name = "Silverleaf", unit = false, valid = true,
        guid = "gather_reserve_off",
    })
    local shared = new_shared()
    assert(idle_state.run(shared, build_context({ node }, { now = 1400.0 })) == "IDLE",
        "G14a FAIL: with the reserve at 0 the bag gate must not block the route")
    local used = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "use_object" and call[2] == node then used = true end
    end
    assert(used, "G14b FAIL: a reserve of 0 must still allow the gather")
end

print("PASS test_gathering_profile")
os.exit(0)
