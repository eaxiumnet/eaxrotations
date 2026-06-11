-- What: Plugin configuration UI for EaxAutoQuester
-- When: Rendered in-game via core.register_on_render_menu_callback (main.lua)
-- Why: Centralizes all user-facing settings — checkboxes, combobox, sliders, keybind
-- Safety: All menu widgets nil-guarded via get(key, fallback); widgets created once at load
-- Decision: Standalone menu (not EaxRotations schema), uses core.menu.* widget API

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _core_menu = core.menu

-- Static table for combobox option labels (Pattern 4 from AGENTS.md)
local _combo_labels = { n = 0 }
local _t = { n = 0 }

-- ============================================================================
-- Menu IDs — prefix: "eaxaq_<feature>_<subfeature>"
-- ============================================================================

local IDs = {
    tree            = "eaxaq_tree",
    enable          = "eaxaq_enable",
    auto_loot       = "eaxaq_auto_loot",
    auto_repair     = "eaxaq_auto_repair",
    auto_vendor     = "eaxaq_auto_vendor",
    auto_train      = "eaxaq_auto_train",
    debug           = "eaxaq_debug",
    auto_accept     = "eaxaq_auto_accept",
    auto_turnin     = "eaxaq_auto_turnin",
    vendor_threshold = "eaxaq_vendor_threshold",
    interact_range  = "eaxaq_interact_range",
    nav_tolerance   = "eaxaq_nav_tolerance",
    toggle_keybind  = "eaxaq_toggle_keybind",
}

-- ============================================================================
-- Combo Option Labels — pre-built once, reused on every render
-- ============================================================================

local VENDOR_OPTIONS = { "Grey", "White", "Green", "Blue" }

-- ============================================================================
-- Menu Widgets — created once at module load, cached for lifetime
-- ============================================================================

local M = {}

-- Tree node — top-level "EaxAutoQuester" container
M.tree = _core_menu.tree_node()

-- Checkboxes (default: enabled for core features)
M.enable          = _core_menu.checkbox(true, IDs.enable)
M.auto_loot       = _core_menu.checkbox(true, IDs.auto_loot)
M.auto_repair     = _core_menu.checkbox(true, IDs.auto_repair)
M.auto_vendor     = _core_menu.checkbox(true, IDs.auto_vendor)
M.auto_train      = _core_menu.checkbox(true, IDs.auto_train)
M.debug           = _core_menu.checkbox(false, IDs.debug)
M.auto_accept     = _core_menu.checkbox(true, IDs.auto_accept)
M.auto_turnin     = _core_menu.checkbox(true, IDs.auto_turnin)

-- Combobox — vendor sell threshold (1-indexed: 1=Grey, 2=White, 3=Green, 4=Blue)
M.vendor_threshold = _core_menu.combobox(1, IDs.vendor_threshold)

-- Sliders
M.interact_range  = _core_menu.slider_int(5, 50, 20, IDs.interact_range)
M.nav_tolerance   = _core_menu.slider_int(1, 10, 3, IDs.nav_tolerance)

-- Keybind — toggle plugin on/off (Ctrl+Shift+T = key 7, shift=true)
M.toggle_keybind  = _core_menu.keybind(7, true, IDs.toggle_keybind)

-- ============================================================================
-- Settings Accessor — nil-guarded read of any setting
-- ============================================================================

--- Read a setting value with fallback default.
--- @param key string Widget key/ID
--- @param fallback any Value returned if widget is nil
--- @return any
function M.get(key, fallback)
    if not key then return fallback end

    local widget = M[key]
    if not widget then return fallback end

    -- Checkbox: use get_state()
    if widget.get_state then
        local ok, val = pcall(function() return widget:get_state() end)
        if ok and val ~= nil then return val end
        return fallback
    end

    -- Slider / Combobox: use get()
    if widget.get then
        local ok, val = pcall(function() return widget:get() end)
        if ok and val ~= nil then return val end
        return fallback
    end

    return fallback
end

-- ============================================================================
-- Render
-- ============================================================================

--- Render the full EaxAutoQuester menu tree.
--- Called every frame by main.lua's on_render_menu callback.
function M.render()
    if not M.tree then return end

    -- Populate tree node label — clears children each frame
    _t.n = 0

    -- Begin tree
    local tree_ok = M.tree:render("EaxAutoQuester")
    if not tree_ok then return end

    -- Checkboxes — core features
    if M.enable then
        M.enable:render("Enable AutoQuester", "Master toggle — enables or disables the entire auto-questing system")
    end

    if M.auto_accept then
        M.auto_accept:render("Auto-accept Quests", "Automatically accept quests from NPCs when in range and dialog is open")
    end

    if M.auto_turnin then
        M.auto_turnin:render("Auto-turnin Quests", "Automatically turn in completed quests when interacting with quest NPCs")
    end

    if M.auto_loot then
        M.auto_loot:render("Auto-loot", "Automatically loot quest-relevant items from corpses and objects")
    end

    if M.auto_repair then
        M.auto_repair:render("Auto-repair", "Automatically repair equipment at vendors when durability is low")
    end

    if M.auto_vendor then
        M.auto_vendor:render("Auto-vendor", "Automatically sell grey and low-quality items at vendors")
    end

    if M.auto_train then
        M.auto_train:render("Auto-train", "Automatically train new spells and skills from class trainers")
    end

    if M.debug then
        M.debug:render("Debug Logging", "Enable verbose debug output to the Sylvanas log console")
    end

    -- Combobox — vendor threshold
    if M.vendor_threshold then
        -- Build labels list from pre-defined options on every render
        _combo_labels.n = 0
        for i = 1, #VENDOR_OPTIONS do
            _combo_labels.n = _combo_labels.n + 1
            _combo_labels[_combo_labels.n] = VENDOR_OPTIONS[i]
        end
        M.vendor_threshold:render(
            "Vendor Sell Threshold",
            _combo_labels,
            "Minimum quality to auto-vendor. Grey = junk only, Blue = up to rare quality"
        )
    end

    -- Sliders
    if M.interact_range then
        M.interact_range:render("Interaction Range", "Maximum distance (yards) to consider quest objects/NPCs as interactable")
    end

    if M.nav_tolerance then
        M.nav_tolerance:render("Nav Tolerance", "Distance (yards) from waypoint considered 'arrived' — lower = more precise")
    end

    -- Keybind
    if M.toggle_keybind then
        M.toggle_keybind:render("Toggle Plugin Keybind", "Keybind to enable/disable the auto-questing plugin on the fly")
    end
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.menu = M

return M
