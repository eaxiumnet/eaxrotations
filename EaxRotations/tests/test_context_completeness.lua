-- Context completeness regression test.
-- Validates that build_context populates all required fields from SUPER_PROMPT spec.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_not_nil(v, label) if v == nil then error(label or "assert_not_nil failed", 2) end end

local now = 0
local target = { is_in_melee_range = function() return true end, is_player = function() return false end,
    get_level = function() return 72 end, get_effective_level = function() return 72 end, get_classification = function() return 1 end,
    time_to_die = function() return 60 end, get_time_to_death = function() return 60 end }
local player = {
    get_target = function() return target end,
    is_in_combat = function() return true end,
    is_alive = function() return true end, is_valid = function() return true end,
    get_level = function() return 64 end, get_effective_level = function() return 64 end,
    gcd_remains = function() return 0 end, get_power = function() return 80 end,
    is_moving = function() return false end, is_casting = function() return false end,
    is_channeling = function() return false end, get_distance = function() return 5 end,
    combo_points_current = function() return 3 end,
}

_G.core = {
    time = function() return now / 1000 end,
    game_time = function() now = now + 200; return now end,
    get_instance_type = function() return "party" end,
    log = function() end, log_warning = function() end, log_error = function() end,
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
}

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/??.lua;?.lua;" .. package.path
package.loaded.core_sylvanas = nil; package.loaded.main_sylvanas = nil; _G.EaxRotations = nil

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
assert_not_nil(disp, "dispatcher should load")
disp.on_rotation_update()

local ctx = core_mod.current_context or {}
assert_not_nil(ctx, "ctx")
assert_not_nil(ctx.me, "me")
assert_not_nil(ctx.hp, "hp")
assert_not_nil(ctx.player_hp, "player_hp")
assert_not_nil(ctx.player_mana, "player_mana")
assert_not_nil(ctx.gcd_remains, "gcd_remains")
assert_not_nil(ctx.on_gcd, "on_gcd")
assert_not_nil(ctx.rage, "rage")
assert_not_nil(ctx.player_rage, "player_rage")
assert_not_nil(ctx.energy, "energy")
assert_not_nil(ctx.player_energy, "player_energy")
assert_not_nil(ctx.target_range, "target_range")
assert_not_nil(ctx.is_pvp, "is_pvp")
assert_not_nil(ctx.force_burst, "force_burst")
assert_not_nil(ctx.force_defensive, "force_defensive")
assert_not_nil(ctx.force_gap, "force_gap")
assert_not_nil(ctx.has_breakable_cc_nearby, "has_breakable_cc_nearby")
assert_not_nil(ctx.target_is_player, "target_is_player")
assert_not_nil(ctx.target_is_boss, "target_is_boss")
assert_not_nil(ctx.player_level, "player_level")
assert_true(ctx.player_level == 64, "player_level should come from player API")
assert_true(ctx.is_leveling == true, "is_leveling should be true below 70")
assert_true(ctx.target_level == 72, "target_level should come from target API")
assert_true(ctx.target_level_delta == 8, "target_level_delta")
assert_true(ctx.target_classification == 1, "target_classification")
assert_true(ctx.instance_type == "party", "instance_type")
assert_true(ctx.is_dungeon == true, "is_dungeon")
assert_true(ctx.is_solo == false, "is_solo")

print("PASS context_completeness")
