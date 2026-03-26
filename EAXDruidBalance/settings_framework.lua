--[[
    settings_framework.lua
    
    Eax TBC Rotation Framework - Unified Settings Framework
    
    Provides consistent control panel organization across all specs.
    Standardizes categories, defaults, and tooltips.
    
    Usage:
        local settings = require("eax_shared/settings_framework")
        
        -- Initialize with spec info
        settings.init({
            spec_name = "DruidBalance",
            class_name = "Druid",
            role = "dps",  -- "dps", "healer", "tank"
        })
        
        -- Register standard control categories
        settings.register_category("rotation", {
            label = "Rotation",
            description = "Main combat rotation settings",
        })
        
        -- Get menu elements for a category
        local elements = settings.get_category_elements("rotation")
        
        -- Render settings panel
        settings.render_menu(menu, tree, options)
--]]

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

local function get_major_toggle_log_prefix(menu)
    if menu and menu._major_toggle_log_prefix then
        return menu._major_toggle_log_prefix
    end

    local class_name = state.class_name or "Unknown"
    local spec_name = state.spec_name or "unknown"
    return "[Eax " .. class_name .. " " .. spec_name .. "] "
end

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
function settings_framework.setup_major_toggle_keybinds(menu, bindings, options)
    if not menu then
        return
    end

    options = options or {}
    local namespace = options.namespace or state.spec_name or "eaxspec"
    menu._major_toggle_log_prefix = options.log_prefix or menu._major_toggle_log_prefix
    menu._major_toggle_bindings = {}
    menu._major_toggle_hotkey_states = menu._major_toggle_hotkey_states or {}

    for _, binding in ipairs(bindings or {}) do
        local toggle_field = binding.toggle
        local toggle = toggle_field and menu[toggle_field] or nil
        if toggle and type(toggle.get_state) == "function" and type(toggle.set) == "function" then
            local key_field = binding.key_field or (toggle_field .. "_key")
            if not menu[key_field] then
                local key_id = namespace .. "_" .. (binding.id or toggle_field) .. "_key"
                menu[key_field] = core.menu.keybind(CONFIG.defaults.toggle_key, false, key_id)
            end

            menu._major_toggle_bindings[#menu._major_toggle_bindings + 1] = {
                toggle_field = toggle_field,
                key_field = key_field,
                label = binding.label or toggle_field,
                hotkey_label = binding.hotkey_label or ((binding.label or toggle_field) .. " Hotkey"),
                tooltip = binding.tooltip or ("Toggle " .. (binding.label or toggle_field) .. " on/off"),
                runtime_managed = binding.runtime_managed == true,
            }
        end
    end

    if menu._major_toggle_callback_registered then
        return
    end

    menu._major_toggle_callback_registered = true
    core.register_on_update_callback(function()
        settings_framework.process_major_toggle_keybinds(menu)
    end)
end

--- Process registered major toggle hotkeys.
function settings_framework.process_major_toggle_keybinds(menu)
    if not menu or not menu._major_toggle_bindings then
        return
    end

    local debug_enabled = menu.debug and type(menu.debug.get_state) == "function" and menu.debug:get_state()
    for _, binding in ipairs(menu._major_toggle_bindings) do
        local keybind = menu[binding.key_field]
        local toggle = menu[binding.toggle_field]
        if keybind and toggle then
            local state_key = binding.key_field
            if keybind:get_key_code() == 7 then
                menu._major_toggle_hotkey_states[state_key] = false
            else
                local pressed = keybind:get_state()
                if (not binding.runtime_managed) and pressed and not menu._major_toggle_hotkey_states[state_key] then
                    local new_state = not toggle:get_state()
                    toggle:set(new_state)
                    if debug_enabled then
                        core.log(get_major_toggle_log_prefix(menu) .. binding.label .. " -> " .. tostring(new_state))
                    end
                end
                menu._major_toggle_hotkey_states[state_key] = pressed
            end
        end
    end
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
function settings_framework.create_standard_menu(core_menu)
    local menu = {}
    
    -- Controls category
    menu.enabled = core_menu.checkbox(CONFIG.defaults.enabled, state.spec_name .. "_enabled")
    menu.toggle_key = core_menu.keybind(CONFIG.defaults.toggle_key, false, state.spec_name .. "_toggle_key")
    menu.mode = core_menu.combobox(CONFIG.defaults.mode, state.spec_name .. "_mode")
    menu.debug = core_menu.checkbox(CONFIG.defaults.debug, state.spec_name .. "_debug")
    
    -- Targeting
    menu.focus_priority = core_menu.checkbox(false, state.spec_name .. "_focus_priority")
    menu.combat_self_hp_boost = core_menu.slider_int(0, 30, 10, state.spec_name .. "_combat_self_hp_boost")
    
    -- Racial
    menu.use_racial = core_menu.checkbox(CONFIG.defaults.use_racial, state.spec_name .. "_use_racial")
    menu.racial_hp = core_menu.slider_int(10, 80, CONFIG.defaults.racial_hp, state.spec_name .. "_racial_hp")
    
    -- OOC
    menu.ooc_drink = core_menu.checkbox(true, "eax_ooc_drink")
    menu.ooc_eat = core_menu.checkbox(true, "eax_ooc_eat")
    menu.ooc_rez = core_menu.checkbox(true, "eax_ooc_rez")
    menu.ooc_group_buff = core_menu.checkbox(true, "eax_ooc_group_buff")
    menu.drink_threshold = core_menu.slider_int(50, 100, CONFIG.defaults.drink_threshold, "eax_drink_threshold")
    menu.eat_threshold = core_menu.slider_int(50, 100, CONFIG.defaults.eat_threshold, "eax_eat_threshold")
    menu.auto_repair = core_menu.checkbox(true, state.spec_name .. "_auto_repair")
    menu.auto_sell_greys = core_menu.checkbox(true, state.spec_name .. "_auto_sell_greys")
    menu.auto_mount = core_menu.checkbox(true, state.spec_name .. "_auto_mount")
    menu.auto_dismount = core_menu.checkbox(true, state.spec_name .. "_auto_dismount")
    menu.auto_combat_potions = core_menu.checkbox(false, state.spec_name .. "_auto_combat_potions")
    menu.auto_ooc_food_drink = core_menu.checkbox(true, state.spec_name .. "_auto_ooc_food_drink")
    menu.auto_flask = core_menu.checkbox(false, state.spec_name .. "_auto_flask")
    
    -- Display
    menu.esp_show_hud = core_menu.checkbox(CONFIG.defaults.esp_show_hud, "eax_esp_show_hud")
    menu.esp_show_target = core_menu.checkbox(CONFIG.defaults.esp_show_target, "eax_esp_show_target")
    menu.esp_hud_x = core_menu.slider_int(0, 3840, CONFIG.defaults.esp_hud_x, "eax_esp_hud_x")
    menu.esp_hud_y = core_menu.slider_int(0, 2160, CONFIG.defaults.esp_hud_y, "eax_esp_hud_y")
    
    return menu
end

--- Get standard mode options for combobox
function settings_framework.get_mode_options()
    return { "Auto", "Solo", "Dungeon", "Raid" }
end

--- Create standard tree nodes
function settings_framework.create_tree_nodes()
    local tree = {}
    
    for _, cat in ipairs(CONFIG.categories) do
        tree[cat.id] = core.menu.tree_node()
    end
    
    return tree
end

--- Render a standard category
function settings_framework.render_category(menu, tree, category_id, render_fn)
    local category = state.registered_categories[category_id] or CONFIG.categories[category_id]
    if not category then return end
    
    tree[category_id]:render("  " .. category.label, function()
        if category.description and category.description ~= "" then
            -- Could add a header or separator here
        end
        
        if render_fn then
            render_fn()
        end
    end)
end

--- Render standard controls section
function settings_framework.render_controls(menu, title)
    core.menu.header("  Controls")
    menu.enabled:render("Enabled", CONFIG.tooltips.enabled)
    menu.toggle_key:render("Toggle Key", CONFIG.tooltips.toggle_key)
    menu.mode:render("Mode", settings_framework.get_mode_options(), CONFIG.tooltips.mode.auto)
    menu.debug:render("Debug Logging", "Print rotation decisions to the console")
    if menu._major_toggle_bindings and #menu._major_toggle_bindings > 0 then
        core.menu.header("  Major Ability Hotkeys")
        for _, binding in ipairs(menu._major_toggle_bindings) do
            menu[binding.key_field]:render("  " .. binding.hotkey_label, binding.tooltip)
        end
    end
end

--- Render standard targeting section
function settings_framework.render_targeting(menu, tree)
    tree.targeting:render("  Targeting", function()
        core.menu.header("Priority")
        menu.focus_priority:render("Focus Target Priority", "Prioritize your focus target over the current target")
        menu.combat_self_hp_boost:render("Self-Heal Bonus %", "Extra health threshold added to self-heal triggers")
    end)
end

--- Render standard racial section
function settings_framework.render_racial(menu, tree)
    tree.racial:render("  Racial Abilities", function()
        core.menu.header("Racial Ability")
        menu.use_racial:render("Use Racial", CONFIG.tooltips.use_racial)
        menu.racial_hp:render("Racial HP %", CONFIG.tooltips.racial_hp)
    end)
end

--- Render standard OOC section
function settings_framework.render_ooc(menu, tree, options)
    options = options or {}
    tree.ooc:render("  Out of Combat", function()
        core.menu.header("Sustain")
        menu.ooc_drink:render("Auto-Drink", "Drink to restore mana when out of combat")
        menu.drink_threshold:render("Drink Threshold %", "Start drinking below this mana percent")
        menu.ooc_eat:render("Auto-Eat", "Eat food to restore health when out of combat")
        menu.eat_threshold:render("Eat Threshold %", "Start eating below this health percent")
        
        core.menu.header("Group")
        menu.ooc_rez:render("Auto-Resurrect", "Accept and cast resurrection when out of combat")
        menu.ooc_group_buff:render("Group Buffs", "Apply class buffs to party members between pulls")
        
        core.menu.header("Automation")
        menu.auto_repair:render("Auto Repair", "Automatically repair gear at vendors")
        menu.auto_sell_greys:render("Auto Sell Greys", "Automatically sell poor-quality items")
        menu.auto_mount:render("Auto Mount", "Automatically mount when traveling out of combat")
        menu.auto_dismount:render("Auto Dismount", "Automatically dismount when entering combat")
        menu.auto_combat_potions:render("Auto Combat Potions", "Use combat potions automatically")
        menu.auto_ooc_food_drink:render("Auto OOC Food/Drink", "Use food and drink out of combat when needed")
        menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically")
    end)
end

--- Render standard display section
function settings_framework.render_display(menu, tree)
    tree.display:render("  Display & HUD", function()
        core.menu.header("Overlay")
        menu.esp_show_hud:render("Show HUD", "Render the in-game rotation status overlay")
        menu.esp_show_target:render("Show Target Info", "Display target information on the HUD")
        
        core.menu.header("Position")
        menu.esp_hud_x:render("HUD Position X", "Horizontal screen position of the HUD panel")
        menu.esp_hud_y:render("HUD Position Y", "Vertical screen position of the HUD panel")
    end)
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
