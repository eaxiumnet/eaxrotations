-- TEMPORARY probe — acting goal shapes: where they settle, purity, cost, work.
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()
math.randomseed(7)
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.menu = { get = function() return nil end }

local STATE_HANDLER = {
    WAITING = "quest_state/waiting_state", IDLE = "quest_state/idle_state",
    INTERACT = "quest_state/interact_state", NAV = "quest_state/nav_state",
    DEAD = "quest_state/dead_state", DO_ACTION = "quest_state/do_action_state",
}
local STATE_FRESH = {
    "quest_state/coordinator", "quest_state/idle_state", "quest_state/nav_state",
    "quest_state/interact_state", "quest_state/do_action_state", "quest_state/waiting_state",
    "quest_state/dead_state", "navigation_sylvanas", "quest_interaction_sylvanas",
    "zygor_reader_sylvanas", "utils_sylvanas", "anti_detection_sylvanas",
    "waypoint_fixer_sylvanas", "flight_path_sylvanas", "mount_manager_sylvanas",
    "static_popup_sylvanas", "loot_manager_sylvanas", "combat_helper_sylvanas",
    "service_gossip_sylvanas", "goal_resolver_sylvanas", "object_scanner",
    "shared/corpse_loot", "menu_sylvanas",
}
local INPUT_STUBS = { "jump", "turn_left_start", "turn_left_stop", "turn_right_start",
    "turn_right_stop", "loot_item", "loot_object", "close_loot", "set_target",
    "interact_with_object", "use_object", "use_item", "move_to", "look_at", "look_at_3d" }
local DRAW_ENTRY_POINTS = { "draw_text", "draw_line", "draw_circle", "circle_3d", "line_3d", "circle_3d_filled" }
local COORDS_STUB = {
    map_to_world = function(_, map_id, pos) return { x = pos.x * 100, y = pos.y * 100, z = 0 } end,
    get_terrain_height = function() return 0 end,
}
local function make_mover()
    local m = {}
    function m:move_to_position(pos) self.target = pos return true end
    function m:stop() end
    function m:process() return false end
    function m:is_moving() return true end
    return m
end

local input_calls_seen = {}
local function drain_calls()
    local calls = mock._input_calls
    for i = 1, #calls do
        local name = tostring(calls[i][1])
        input_calls_seen[name] = (input_calls_seen[name] or 0) + 1
        calls[i] = nil
    end
end

local SHAPES = {
    {
        label = "use goal + crate",
        step = { num = 2, is_complete = false,
            goals = { { type = "use", text = "Supply Crate", is_complete = false } },
            waypoint = nil, waypoints = {} },
        objects = function()
            return { mock.create_object({ unit = false, name = "Supply Crate",
                pos = { x = 3, y = 0, z = 0 }, item_id = 555 }) }
        end,
    },
    {
        label = "kill goal + enemy",
        step = { num = 2, is_complete = false,
            goals = { { type = "kill", npc_id = 4242, is_complete = false } },
            waypoint = nil, waypoints = {} },
        objects = function()
            return { mock.create_object({ npc_id = 4242, unit = true, name = "Quest Mob",
                pos = { x = 2, y = 0, z = 0 }, attackable = true, enemy = true }) }
        end,
    },
}

local function run(shape, dt)
    for i = 1, #STATE_FRESH do package.loaded[STATE_FRESH[i]] = nil end
    package.loaded["common/utility/simple_movement"] = make_mover()
    package.loaded["common/utility/coords_helper"] = COORDS_STUB
    package.loaded["common/color"] = nil
    _G.SentinelNavClient = nil
    mock.reset()
    _G.EaxAutoQuester = {}
    for _, name in ipairs(INPUT_STUBS) do core.input[name] = function() end end
    for _, name in ipairs(DRAW_ENTRY_POINTS) do mock.graphics[name] = function() end end
    for k in pairs(input_calls_seen) do input_calls_seen[k] = nil end

    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local pinned_auras = {}
    player.get_buffs = function() return pinned_auras end
    player.get_auras = player.get_buffs
    player.get_debuffs = player.get_buffs
    mock._addon_loaded.zygor = true
    mock._zygor_step = shape.step
    mock._objects = shape.objects()
    mock.set_time(1.0)

    local coordinator = require("quest_state/coordinator")
    local counts = {}
    local entered = {}
    local seq = {}
    for state in pairs(STATE_HANDLER) do entered[state] = 0 end
    for state, module_name in pairs(STATE_HANDLER) do
        local handler = require(module_name)
        local real_run = handler.run
        handler.run = function(shared, ctx)
            entered[state] = entered[state] + 1
            local nxt = real_run(shared, ctx)
            seq[#seq + 1] = state .. "->" .. tostring(nxt)
            return nxt
        end
    end
    local function wrap(module_name, fn_name)
        local mod = require(module_name)
        local fn = mod[fn_name]
        if type(fn) ~= "function" then counts[module_name .. "." .. fn_name] = "MISSING" return end
        mod[fn_name] = function(...)
            counts[module_name .. "." .. fn_name] = (counts[module_name .. "." .. fn_name] or 0) + 1
            return fn(...)
        end
    end
    wrap("combat_helper_sylvanas", "is_current_target_valid")
    wrap("combat_helper_sylvanas", "target_and_tag_nearest")
    wrap("npc_manager_sylvanas", "find_nearest_npc")
    wrap("npc_manager_sylvanas", "get_nearest_enemy")
    wrap("zygor_reader_sylvanas", "get_current_step_info")
    wrap("goal_resolver_sylvanas", "resolve_goal")

    local function tick()
        mock.set_time(mock.get_time() + dt)
        drain_calls()
        coordinator.update()
    end

    for _ = 1, 6 do tick() end
    local settled = coordinator._test_inspect()
    for state in pairs(entered) do entered[state] = 0 end
    for k in pairs(counts) do counts[k] = 0 end
    seq = {}
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, 300 do tick() end
    local after = collectgarbage("count")
    collectgarbage("restart")
    local bytes = (after - before) * 1024 / 300

    local held = coordinator._test_inspect()
    local tally = {}
    for state, count in pairs(entered) do
        if count > 0 then tally[#tally + 1] = state .. "=" .. count end
    end
    table.sort(tally)
    local transitions = {}
    for i = 1, #seq do
        transitions[seq[i]] = (transitions[seq[i]] or 0) + 1
    end
    local tkeys = {}
    for k in pairs(transitions) do tkeys[#tkeys + 1] = k end
    table.sort(tkeys)
    print(string.format("%-18s dt=%-5.2f settled=%-10s held=%-10s n300=%8.2f  handlers: %s",
        shape.label, dt, settled, held, bytes, table.concat(tally, " ")))
    local parts = {}
    for i = 1, #tkeys do parts[#parts + 1] = tkeys[i] .. " x" .. transitions[tkeys[i]] end
    print("        transitions: " .. table.concat(parts, ", "))
    local ckeys = {}
    for k in pairs(counts) do ckeys[#ckeys + 1] = k end
    table.sort(ckeys)
    for i = 1, #ckeys do print(string.format("        %-48s %s", ckeys[i], tostring(counts[ckeys[i]]))) end
    local ikeys = {}
    for k in pairs(input_calls_seen) do ikeys[#ikeys + 1] = k end
    table.sort(ikeys)
    for i = 1, #ikeys do print(string.format("        input %-24s %s", ikeys[i], tostring(input_calls_seen[ikeys[i]]))) end
end

for s = 1, #SHAPES do
    run(SHAPES[s], 0.0)
    run(SHAPES[s], 0.5)
end
