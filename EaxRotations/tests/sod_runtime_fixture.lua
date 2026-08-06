-- sod_runtime_fixture.lua -- Deterministic dispatcher context harness for SoD runtime tests.
-- WHAT:  boots core/dispatcher with a minimal Project Sylvanas API mock.
-- WHEN:  used by focused SoD runtime selection and nil-safety tests.
-- WHY:   exercises the real context builder without loading class rotations.
-- SAFETY: resets expansion modules and uses no external process or mutable runtime state.

local M = {}

local function player_fixture()
    return {
        get_target = function() return nil end,
        is_in_combat = function() return false end,
        is_alive = function() return true end,
        is_valid = function() return true end,
        get_level = function() return 60 end,
        get_effective_level = function() return 60 end,
        gcd_remains = function() return 0 end,
        get_power = function() return 0 end,
        is_moving = function() return false end,
        is_casting = function() return false end,
        is_channeling = function() return false end,
    }
end

function M.boot(version, settings, rune_provider)
    package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path
    package.loaded["core_sylvanas"] = nil
    package.loaded["main_sylvanas"] = nil
    _G.EaxRotations = nil

    local now = 0
    local player = player_fixture()
    _G.core = {
        time = function() return now / 1000 end,
        game_time = function() now = now + 200 return now end,
        get_game_version = function() return version end,
        get_instance_type = function() return "none" end,
        log = function() end,
        log_warning = function() end,
        log_error = function() end,
        object_manager = {
            get_local_player = function() return player end,
            get_visible_objects = function() return {} end,
            get_enemy_list = function() return {} end,
            get_focus_target = function() return nil end,
        },
        spell_book = {
            is_spell_learned = function() return false end,
            get_global_cooldown = function() return 1.5 end,
            get_spell_cooldown = function() return 0 end,
            get_spell_cooldown_information = function() return { enabled = false } end,
            get_spell_costs = function() return {} end,
            is_spell_in_range = function() return true end,
            cancel_form = function() end,
        },
        input = { cast_target_spell = function() return false end, stop_targeting = function() end },
        graphics = { add_notification = function() end, text_2d = function() end },
        menu = {
            checkbox = function() return {} end,
            slider_int = function() return {} end,
            combobox = function() return {} end,
            keybind = function() return {} end,
            tree_node = function() return {} end,
            header = function() return {} end,
            window = function() return {} end,
        },
        read_data_file = function() return "{}" end,
        write_data_file = function() return true end,
        register_on_update_callback = function() end,
        register_on_render_menu_callback = function() end,
        register_on_render_control_panel_callback = function() end,
        register_on_spell_cast_callback = function() end,
        register_on_render_window_callback = function() end,
    }

    local NS = require("core_sylvanas")
    NS.core = _G.core
    NS.settings = settings
    NS.get_sod_runes = rune_provider
    NS.izi = {
        on_combat_start = function() end,
        on_combat_end = function() end,
        spell = function() return {} end,
        item = function() return {} end,
        ts = function() return {} end,
        enemies = function() return {} end,
        friends = function() return {} end,
        any_enemy = function() return false end,
        draw_spell_icon = function() end,
        draw_icon = function() end,
        draw_circle = function() end,
        draw_line = function() end,
    }

    local dispatcher = require("main_sylvanas")
    local ok, result = pcall(dispatcher.on_rotation_update)
    return NS, NS.current_context, ok, result
end

function M.production_boot(version, settings, current_settings)
    package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path
    package.loaded["core_sylvanas"] = nil
    package.loaded["core/settings"] = nil
    package.loaded["shared/class_loader_sylvanas"] = nil
    _G.EaxRotations = type(current_settings) == "table" and { settings = current_settings } or nil

    local original_require = require
    local attempts = {}
    local observed = { initial_settings_empty = false, selected = nil, schema = nil }
    local player = player_fixture()
    player.get_class = function() return 4 end
    local persisted = type(settings) == "table" and settings or {}
    local active_settings = type(current_settings) == "table" and current_settings or {}
    local function widget(value)
        return {
            get = function() return value end,
            set = function(_, next_value) value = next_value end,
            get_state = function() return value end,
            get_toggle_state = function() return value end,
            get_key_code = function() return 999 end,
            render = function() end,
        }
    end

    _G.core = {
        time = function() return 0 end,
        game_time = function() return 0 end,
        get_game_version = function() return version end,
        get_exact_game_version = function() return version end,
        get_instance_type = function() return "none" end,
        log = function() end,
        log_warning = function() end,
        log_error = function() end,
        object_manager = {
            get_local_player = function() return player end,
            get_visible_objects = function() return {} end,
            get_enemy_list = function() return {} end,
            get_focus_target = function() return nil end,
        },
        spell_book = {
            is_spell_learned = function() return false end,
            get_global_cooldown = function() return 1.5 end,
            get_spell_cooldown = function() return 0 end,
            get_spell_cooldown_information = function() return { enabled = false } end,
            get_spell_costs = function() return {} end,
            is_spell_in_range = function() return true end,
            cancel_form = function() end,
        },
        input = { cast_target_spell = function() return false end, stop_targeting = function() end },
        graphics = { add_notification = function() end, text_2d = function() end },
        menu = {
            checkbox = function(default) return widget(default) end,
            slider_int = function(_, _, default) return widget(default) end,
            slider_float = function(_, _, default) return widget(default) end,
            combobox = function(default) return widget(default) end,
            keybind = function() return widget(true) end,
            tree_node = function() return widget(false) end,
            header = function() return widget(false) end,
            button = function() return widget(false) end,
            color_picker = function(default) return widget(default) end,
            window = function() return widget(false) end,
        },
        read_data_file = function() return "{}" end,
        write_data_file = function() return true end,
        register_on_update_callback = function() end,
        register_on_render_menu_callback = function() end,
        register_on_render_control_panel_callback = function() end,
        register_on_render_callback = function() end,
        register_on_spell_cast_callback = function() end,
        register_on_render_window_callback = function() end,
        register_on_combat_start_callback = function() end,
        register_on_combat_end_callback = function() end,
        register_on_game_event_callback = function() end,
    }

    require = function(path)
        if path == "header" then
            return { load = true, version = "test", player_class_name = "ROGUE", player_class_id = 4 }
        end
        if path == "common/izi_sdk" then return { log = function() end } end
        if path == "common/color" then
            local make_color = function() return { r = 255, g = 255, b = 255, a = 255 } end
            return { new = make_color, yellow = make_color, white = make_color, green = make_color, red = make_color }
        end
        if path == "shared/menu_theme_sylvanas" then return nil end
        if path == "common/modules/settings_manager" then
            return { get = function(_, key) return persisted[key] end, set = function() end }
        end
        if path == "common/enums" then
            return {
                power_type = { MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, COMBOPOINTS = 4 },
                class_id = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
                    SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 },
            }
        end
        if path == "core_sylvanas" or path == "core/settings" then return original_require(path) end
        if path == "main_sylvanas" then return {} end
        if path == "shared/class_loader_sylvanas" then return original_require(path) end
        if path == "classes/rogue/schema_sylvanas" then
            local schema = {}
            observed.schema = schema
            return schema
        end
        if path == "classes/rogue/class_sylvanas" then
            observed.initial_settings_empty = next(_G.EaxRotations.settings or {}) == nil
            local loader = original_require("shared/class_loader_sylvanas")
            local selected = loader.create_expansion_loader("rogue", "Rogue")("combat", true)
            observed.selected = selected
            return selected and { selected = selected } or nil
        end
        if path:match("^classes/rogue/combat_") then
            attempts[#attempts + 1] = path
            local configured_mode = active_settings.runtime_mode
            if configured_mode == nil then configured_mode = persisted.runtime_mode end
            local is_sod = type(configured_mode) == "string"
                and configured_mode:lower() == "sod"
            local expected = is_sod and "classes/rogue/combat_sod" or "classes/rogue/combat_vanilla"
            if path == expected then return { runtime = path:match("combat_(.+)") } end
            error("unexpected rotation path: " .. path, 0)
        end
        if path:match("^shared/") or path:match("^common/") then return {} end
        return original_require(path)
    end

    local ok, result = pcall(function()
        local main_path = "main.lua"
        local main_file = io.open(main_path, "rb")
        if main_file then
            main_file:close()
        else
            main_path = "EaxRotations/main.lua"
        end
        local chunk, load_error = loadfile(main_path)
        assert(chunk, load_error)
        return chunk()
    end)
    require = original_require
    return _G.EaxRotations, observed, attempts, ok, result
end

return M
