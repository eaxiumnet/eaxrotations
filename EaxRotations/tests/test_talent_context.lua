-- Test: talent_build context field from core.game_ui.get_talent_info()
--
-- Scenarios:
--   a) Mock get_talent_info returns talent data → context.talent_build populated with tree sums
--   b) API unavailable (nil) → context.talent_build is nil (backward compatible)
--   c) Partial talent data (some trees have 0 points) → only non-zero trees counted

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_false(v, label)
    if v then error(label or "assert_false failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

-- Shared mock player/target (same shape as test_context_completeness.lua)
local now = 0
local target = { is_in_melee_range = function() return true end, is_player = function() return false end,
    get_level = function() return 72 end, get_effective_level = function() return 72 end, get_classification = function() return 1 end,
    time_to_die = function() return 60 end, get_time_to_death = function() return 60 end }
local player = {
    get_target = function() return target end,
    is_in_combat = function() return true end,
    is_alive = function() return true end, is_valid = function() return true end,
    get_level = function() return 70 end, get_effective_level = function() return 70 end,
    gcd_remains = function() return 0 end, get_power = function() return 80 end,
    is_moving = function() return false end, is_casting = function() return false end,
    is_channeling = function() return false end, get_distance = function() return 5 end,
    combo_points_current = function() return 3 end,
}

-- ────────────────────────────────────────────────────────────────────────────
-- Helper: create a mock get_talent_info from a tab→idx→rank lookup table
-- Returns the mock function + the expected tree totals.
-- ────────────────────────────────────────────────────────────────────────────
local function make_talent_mock(talent_data)
    return function(tab, idx, inspect)
        local tab_data = talent_data[tab]
        if not tab_data then return nil end
        local rank = tab_data[idx]
        if rank == nil then return nil end
        return {
            name = "Mock Talent",
            texture = 0,
            tier = math.floor(idx / 3),
            column = idx % 3,
            rank = rank,
            max_rank = 5,
            is_exceptional = false,
            available = true,
        }
    end
end

local function compute_expected(talent_data)
    local totals = { tree1 = 0, tree2 = 0, tree3 = 0 }
    for tab = 0, 2 do
        local tab_data = talent_data[tab]
        if tab_data then
            local sum = 0
            for _, rank in pairs(tab_data) do
                sum = sum + rank
            end
            totals["tree" .. tostring(tab + 1)] = sum
        end
    end
    return totals
end

-- ────────────────────────────────────────────────────────────────────────────
-- Boot helper: sets up _G.core, loads modules, dispatches, returns context
-- ────────────────────────────────────────────────────────────────────────────
local function build_context_with_talent_mock(get_talent_info_fn)
    -- Clean slate
    package.loaded.core_sylvanas = nil
    package.loaded.main_sylvanas = nil
    _G.EaxRotations = nil
    package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/??.lua;?.lua;" .. package.path

    _G.core = {
        time = function() return now / 1000 end,
        game_time = function() now = now + 200; return now end,
        get_instance_type = function() return "none" end,
        log = function() end, log_warning = function() end, log_error = function() end,
        game_ui = {
            get_talent_info = get_talent_info_fn,
        },
        object_manager = {
            get_local_player = function() return player end,
            get_visible_objects = function() return {} end,
            get_enemy_list = function() return {} end,
            get_focus_target = function() return nil end,
        },
        spell_book = {
            is_spell_learned = function() return true end,
            get_global_cooldown = function() return 0.5 end,
            get_spell_cooldown = function() return 0 end,
            get_spell_cooldown_information = function() return { enabled = false } end,
            get_spell_costs = function() return {} end,
            is_spell_in_range = function() return true end, cancel_form = function() end,
        },
        input = { cast_target_spell = function() return true end, stop_targeting = function() end },
        graphics = { add_notification = function() end, text_2d = function() end },
        menu = { checkbox = function() return {} end, slider_int = function() return {} end,
            combobox = function() return {} end, keybind = function() return {} end,
            tree_node = function() return {} end, header = function() return {} end, window = function() return {} end },
        read_data_file = function() return "{}" end, write_data_file = function() return true end,
        register_on_update_callback = function() end, register_on_render_menu_callback = function() end,
        register_on_render_control_panel_callback = function() end,
        register_on_spell_cast_callback = function() end, register_on_render_window_callback = function() end,
        string = function() end,  -- core.string for instance_type fallback
    }

    local core_mod = require("core_sylvanas")
    core_mod.core = _G.core
    core_mod.izi = {
        on_combat_start = function() end, on_combat_end = function() end,
        spell = function() return {} end, item = function() return {} end,
        ts = function() return {} end, enemies = function() return {} end,
        friends = function() return {} end, any_enemy = function() return false end,
        draw_spell_icon = function() end, draw_icon = function() end,
        draw_circle = function() end, draw_line = function() end,
    }

    local disp = dofile("EaxRotations/main_sylvanas.lua")
    disp.on_rotation_update()
    return core_mod.current_context or {}
end

-- ════════════════════════════════════════════════════════════════════════════
-- Scenario (a): Mock get_talent_info returning full talent data
-- ════════════════════════════════════════════════════════════════════════════
do
    -- Tab 0 (tree1): [5, 3, 5, 2, 2, 3, 3, 1, 3, 3, 1] = 31 points
    -- Tab 1 (tree2): [5, 5, 5, 2, 2, 2]              = 21 points
    -- Tab 2 (tree3): [3, 3, 3]                        = 9 points
    -- Total: 61 points (plausible for level 70)
    local TALENT_DATA_A = {
        [0] = { [0] = 5, [1] = 3, [2] = 5, [3] = 2, [4] = 2, [5] = 3, [6] = 3, [7] = 1, [8] = 3, [9] = 3, [10] = 1 },
        [1] = { [0] = 5, [1] = 5, [2] = 5, [3] = 2, [4] = 2, [5] = 2 },
        [2] = { [0] = 3, [1] = 3, [2] = 3 },
    }
    local expected = compute_expected(TALENT_DATA_A)

    local ctx = build_context_with_talent_mock(make_talent_mock(TALENT_DATA_A))

    assert_true(ctx.talent_build ~= nil, "Scenario A: talent_build should not be nil when API available")
    assert_eq(ctx.talent_build.tree1, expected.tree1, "Scenario A: tree1 =" .. tostring(expected.tree1))
    assert_eq(ctx.talent_build.tree2, expected.tree2, "Scenario A: tree2 =" .. tostring(expected.tree2))
    assert_eq(ctx.talent_build.tree3, expected.tree3, "Scenario A: tree3 =" .. tostring(expected.tree3))

    -- Verify total points = 61 (level 70 = 61 talent points)
    local total = ctx.talent_build.tree1 + ctx.talent_build.tree2 + ctx.talent_build.tree3
    assert_eq(total, 61, "Scenario A: total talent points should be 61")

    print("  [PASS] Scenario A: talent_build populated with correct tree totals")
end

-- ════════════════════════════════════════════════════════════════════════════
-- Scenario (b): API unavailable → context.talent_build is nil
-- ════════════════════════════════════════════════════════════════════════════
do
    local ctx = build_context_with_talent_mock(nil)

    assert_true(ctx.talent_build == nil, "Scenario B: talent_build should be nil when API unavailable")

    print("  [PASS] Scenario B: talent_build nil when API unavailable")
end

-- ════════════════════════════════════════════════════════════════════════════
-- Scenario (c): Partial talent data (some trees have 0 points)
-- ════════════════════════════════════════════════════════════════════════════
do
    -- Tab 0: deep 41-point build (e.g., deep Affliction)
    -- Tab 1: 0 points (empty tree)
    -- Tab 2: 0 points (empty tree)
    local TALENT_DATA_C = {
        [0] = { [0] = 5, [1] = 3, [2] = 5, [3] = 2, [4] = 2, [5] = 3, [6] = 3, [7] = 1, [8] = 3, [9] = 3, [10] = 1, [11] = 5, [12] = 3, [13] = 2 },
        [1] = {},  -- no talents in tree 2
        -- tree 3: no tab entry at all (key not present)
    }
    local expected = compute_expected(TALENT_DATA_C)

    local ctx = build_context_with_talent_mock(make_talent_mock(TALENT_DATA_C))

    assert_true(ctx.talent_build ~= nil, "Scenario C: talent_build should not be nil")
    assert_eq(ctx.talent_build.tree1, expected.tree1, "Scenario C: tree1 =" .. tostring(expected.tree1))
    assert_eq(ctx.talent_build.tree2, 0, "Scenario C: tree2 should be 0 (empty tree)")
    assert_eq(ctx.talent_build.tree3, 0, "Scenario C: tree3 should be 0 (missing tab)")

    print("  [PASS] Scenario C: partial talent data handled correctly")
end

-- ════════════════════════════════════════════════════════════════════════════
-- Summary
-- ════════════════════════════════════════════════════════════════════════════
print("PASS talent_context")
