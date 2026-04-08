-- settings_framework.lua (simple_ui compatible)
-- Eax TBC Rotation Framework - Unified Settings Framework
-- Updated for simple_ui API compatibility
--
-- Provides consistent control panel organization across all specs.
-- Standardizes categories, defaults, and tooltips.

-- Usage:
--     local settings = require("libraries/settings_framework")
--
--     -- Initialize with spec info
--     settings.init({
--         spec_name = "DruidBalance",
--         class_name = "Druid",
--         role = "dps",  -- "dps", "healer", "tank"
--     })
--
--     -- Register standard control categories
--     settings.register_category("rotation", {
--         label = "Rotation",
--         description = "Main combat rotation settings",
--     })
--
--     -- The rest of the framework API remains for compatibility
--     -- but actual menu creation is now handled via simple_ui in menu.lua

local settings_framework = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
local CONFIG = {
    -- Category definitions with standard ordering
    categories = {
        {
            id = "controls",
            label = "Controls",
            description = "Enable/disable and basic controls",
            order = 1,
        },
        {
            id = "rotation",
            label = "Rotation",
            description = "Main combat rotation settings",
            order = 2,
        },
        {
            id = "defensive",
            label = "Defensive",
            description = "Self-preservation and defensive cooldowns",
            order = 3,
        },
        {
            id = "targeting",
            label = "Targeting",
            description = "Target selection and priority settings",
            order = 4,
        },
        {
            id = "aoe",
            label = "AoE & Multi-Target",
            description = "Area-of-effect and multi-target settings",
            order = 5,
        },
        {
            id = "cooldowns",
            label = "Cooldowns",
            description = "Offensive and defensive cooldown usage",
            order = 6,
        },
        {
            id = "racial",
            label = "Racial Abilities",
            description = "Racial ability usage",
            order = 7,
        },
        {
            id = "consumables",
            label = "Consumables",
            description = "Potions, food, and other consumables",
            order = 8,
        },
        {
            id = "ooc",
            label = "Out of Combat",
            description = "Non-combat automation settings",
            order = 9,
        },
        {
            id = "display",
            label = "Display & HUD",
            description = "Visual overlay and display settings",
            order = 10,
        },
    },

    -- Default values for common settings
    defaults = {
        enabled = true,
        mode = 1,  -- Auto
        toggle_key = 7,  -- NumPad7
        debug = false,

        -- Common toggles
        use_racial = true,
        racial_hp = 40,

        -- Common sliders
        drink_threshold = 80,
        eat_threshold = 80,

        -- Defensive defaults
        healthstone_hp = 35,
        health_potion_hp = 30,

        -- Display defaults
        esp_show_hud = true,
        esp_show_target = true,
        esp_hud_x = 20,
        esp_hud_y = 200,
    },

    -- Tooltip templates
    tooltips = {
        enabled = "Enable or disable the rotation",
        toggle_key = "Keybind to toggle the rotation on/off",
        mode = {
            auto = "Automatically detects party size",
            solo = "Solo/questing optimized rotation",
            dungeon = "Dungeon optimized rotation",
            raid = "Raid optimized rotation",
        },
        use_racial = "Automatically use your racial ability",
        racial_hp = "Use defensive racial below this health percentage",
    },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local state = {
    spec_name = nil,
    class_name = nil,
    role = nil,
    registered_categories = {},
    menu_items = {},
}

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

--- Initialize the settings framework
function settings_framework.init(options)
    options = options or {}
    state.spec_name = options.spec_name or "Unknown"
    state.class_name = options.class_name or "Unknown"
    state.role = options.role or "dps"
    state.registered_categories = {}
    state.menu_items = {}
end

--- Register per-spec major toggle hotkeys and install a lightweight update callback.
-- NOTE: This is kept for backward compatibility but keybinds are now handled via simple_ui
function settings_framework.setup_major_toggle_keybinds(menu, bindings, options)
    -- Compatibility stub - major toggles now handled via simple_ui in menu.lua
    -- This function exists to not break existing code that calls it
    if not menu then
        return
    end

    options = options or {}
    menu._major_toggle_log_prefix = options.log_prefix or menu._major_toggle_log_prefix
    menu._major_toggle_bindings = bindings or {}

    -- No longer registering callbacks - simple_ui handles its own state
end

--- Process registered major toggle hotkeys.
-- NOTE: Kept for compatibility but now a no-op since simple_ui handles this
function settings_framework.process_major_toggle_keybinds(menu)
    -- Compatibility stub - simple_ui components handle their own toggles
end

--- Register a custom category
function settings_framework.register_category(category_id, options)
    options = options or {}

    -- Find base category or create custom
    local category = {
        id = category_id,
        label = options.label or category_id,
        description = options.description or "",
        order = options.order or 99,
        items = {},
    }

    -- Check if base category exists
    for _, cat in ipairs(CONFIG.categories) do
        if cat.id == category_id then
            category = cat
            category.items = {}
            break
        end
    end

    state.registered_categories[category_id] = category
    return category
end

--- Register a menu item to a category
function settings_framework.register_item(category_id, item_id, item_type, options)
    options = options or {}

    if not state.registered_categories[category_id] then
        settings_framework.register_category(category_id)
    end

    local item = {
        id = item_id,
        type = item_type,  -- "checkbox", "slider", "combobox", "keybind"
        label = options.label or item_id,
        default = options.default or CONFIG.defaults[item_id] or false,
        min = options.min,
        max = options.max,
        step = options.step or 1,
        options = options.options,  -- For combobox
        tooltip = options.tooltip or CONFIG.tooltips[item_id] or "",
        category = category_id,
        hidden = options.hidden or false,
    }

    state.menu_items[item_id] = item
    table.insert(state.registered_categories[category_id].items, item)

    return item
end

--- Create standard menu controls for all specs
-- NOTE: This function is deprecated - use simple_ui directly in menu.lua
function settings_framework.create_standard_menu(core_menu)
    local menu = {}

    -- Controls category
    if core_menu and core_menu.checkbox then
        menu.enabled = core_menu.checkbox(CONFIG.defaults.enabled, state.spec_name .. "_enabled")
        menu.toggle_key = core_menu.keybind(CONFIG.defaults.toggle_key, false, state.spec_name .. "_toggle_key")
        menu.mode = core_menu.combobox(CONFIG.defaults.mode, state.spec_name .. "_mode")
        menu.debug = core_menu.checkbox(CONFIG.defaults.debug, state.spec_name .. "_debug")
    end

    -- Targeting
    if core_menu and core_menu.checkbox then
        menu.focus_priority = core_menu.checkbox(false, state.spec_name .. "_focus_priority")
        menu.combat_self_hp_boost = core_menu.slider_int(0, 30, 10, state.spec_name .. "_combat_self_hp_boost")

        -- Racial
        menu.use_racial = core_menu.checkbox(CONFIG.defaults.use_racial, state.spec_name .. "_use_racial")
        menu.racial_hp = core_menu.slider_int(10, 80, CONFIG.defaults.racial_hp, state.spec_name .. "_racial_hp")
    end

    return menu
end

--- Get standard mode options for combobox
function settings_framework.get_mode_options()
    return { "Auto", "Solo", "Dungeon", "Raid" }
end

--- Create standard tree nodes
-- NOTE: Deprecated - simple_ui uses treenode instead
function settings_framework.create_tree_nodes()
    -- Compatibility stub - returns empty table
    return {}
end

--- Render a standard category
-- NOTE: Deprecated - rendering is now handled by simple_ui
function settings_framework.render_category(menu, tree, category_id, render_fn)
    -- Compatibility stub - does nothing
end

--- Render standard controls section
-- NOTE: Deprecated - rendering is now handled by simple_ui
function settings_framework.render_controls(menu, title)
    -- Compatibility stub - does nothing
end

--- Render standard targeting section
-- NOTE: Deprecated - rendering is now handled by simple_ui
function settings_framework.render_targeting(menu, tree)
    -- Compatibility stub - does nothing
end

--- Render standard racial section
-- NOTE: Deprecated - rendering is now handled by simple_ui
function settings_framework.render_racial(menu, tree)
    -- Compatibility stub - does nothing
end

--- Render standard OOC section
-- NOTE: Deprecated - rendering is now handled by simple_ui
function settings_framework.render_ooc(menu, tree, options)
    -- Compatibility stub - does nothing
end

--- Render standard display section
-- NOTE: Deprecated - rendering is now handled by simple_ui
function settings_framework.render_display(menu, tree)
    -- Compatibility stub - does nothing
end

--- Get info about current spec
function settings_framework.get_spec_info()
    return {
        spec_name = state.spec_name,
        class_name = state.class_name,
        role = state.role,
    }
end

--- Check if role matches
function settings_framework.is_role(role)
    return state.role == role
end

return settings_framework
