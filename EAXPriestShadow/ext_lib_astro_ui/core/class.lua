-- ext_lib_astro_ui/class.lua
-- RotationSettingsUI class definition, constructor, and basic methods
-- NOTE: This is a legacy wrapper around core.menu. For new code,
-- use simple_ui directly: require("common/simple_ui")
-- See /rotation/source/aio/settings.lua for the recommended pattern.

local constants = require("ext_lib_astro_ui/core/constants")
local helpers = require("ext_lib_astro_ui/core/helpers")

---@type vec2
local vec2 = require("common/geometry/vector_2")

local LAYOUT = constants.LAYOUT
local THEMES = constants.THEMES
local THEME_NAMES = constants.THEME_NAMES
local THEME_INDEX = constants.THEME_INDEX
local menu_slider_int = helpers.menu_slider_int
local menu_checkbox = helpers.menu_checkbox
local menu_combobox = helpers.menu_combobox

-- ============================================================================
-- WIDGET CLASS
-- ============================================================================

---@class rotation_settings_ui
---@field id string
---@field title string
---@field window any
---@field sections table[]
---@field theme_name string
---@field colors table
---@field menu table
---@field _pos_x any
---@field _pos_y any
---@field _size_x any
---@field _size_y any
---@field _window_epoch integer
---@field _window_id string
local RotationSettingsUI = {}
RotationSettingsUI.__index = RotationSettingsUI

RotationSettingsUI._extension_tabs = {}
RotationSettingsUI._extension_epoch = 0
RotationSettingsUI._registered_windows = {}
RotationSettingsUI._launcher_window = nil

-- ============================================================================
-- MOUSE POSITION HELPER
-- ============================================================================

function RotationSettingsUI:_get_window_local_mouse_pos(space_hint)
    if not self.window then
        return nil
    end

    local ok_mouse, mouse_pos = pcall(function()
        return self.window:get_mouse_pos()
    end)
    if not ok_mouse or not mouse_pos then
        return nil
    end

    local ok_pos, window_pos = pcall(function()
        return self.window:get_position()
    end)

    local adjusted = nil
    if ok_pos and window_pos then
        adjusted = vec2.new(mouse_pos.x - window_pos.x, mouse_pos.y - window_pos.y)
    end

    if space_hint == "raw" then
        return mouse_pos, "raw"
    end
    if space_hint == "adjusted" and adjusted then
        return adjusted, "adjusted"
    end

    local ok_size, window_size = pcall(function()
        return self.window:get_size()
    end)

    local function is_inside_window(pos)
        if not ok_size or not window_size then
            return true
        end
        return pos.x >= 0 and pos.y >= 0 and pos.x <= window_size.x and pos.y <= window_size.y
    end

    local last = self._active_slider and self._active_slider.last_mouse_pos
    local best = nil
    local best_score = nil
    local best_space = nil

    local candidates = {
        { pos = mouse_pos, space = "raw" }
    }
    if adjusted then
        table.insert(candidates, { pos = adjusted, space = "adjusted" })
    end

    for _, candidate in ipairs(candidates) do
        local pos = candidate.pos
        local inside = is_inside_window(pos) and 0 or 1000000
        local delta = 0
        if last then
            local dx = pos.x - last.x
            local dy = pos.y - last.y
            delta = (dx * dx) + (dy * dy)
        end

        local score = inside + delta
        if best_score == nil or score < best_score then
            best_score = score
            best = pos
            best_space = candidate.space
        end
    end

    return best, best_space
end

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

---Creates a new rotation settings UI instance
---@param config table Configuration table {id, title, default_x, default_y, default_w, default_h, theme}
---@return rotation_settings_ui
function RotationSettingsUI.new(config)
    local self = setmetatable({}, RotationSettingsUI)

    self.id = config.id or "rotation_ui"
    self.title = config.title or "Rotation Settings"
    self.theme_name = config.theme or "astro"
    self.colors = THEMES[self.theme_name] or THEMES.astro
    self.sections = {}
    self._window_epoch = 0

    -- Tab state
    self.active_tab_index = 1

    -- Menu elements for persistence and control
    local default_theme_index = THEME_INDEX[self.theme_name] or 1
    self.menu = {
        enable = menu_checkbox(false, "rotation_ui_enable_" .. self.id),
        theme_selector = menu_combobox(default_theme_index, "rotation_ui_theme_" .. self.id),
        pos_x = menu_slider_int(0, 10000, config.default_x or 700, "rotation_ui_x_" .. self.id),
        pos_y = menu_slider_int(0, 10000, config.default_y or 200, "rotation_ui_y_" .. self.id),
        size_x = menu_slider_int(0, 10000, config.default_w or 450, "rotation_ui_w_" .. self.id),
        size_y = menu_slider_int(0, 10000, config.default_h or 600, "rotation_ui_h_" .. self.id),
        active_tab = menu_slider_int(0, 100, 1, "rotation_ui_tab_" .. self.id)
    }

    self._pos_x = self.menu.pos_x
    self._pos_y = self.menu.pos_y
    self._size_x = self.menu.size_x
    self._size_y = self.menu.size_y

    self._active_slider = nil
    self._active_key_capture = nil
    self._active_combo_dropdown = nil
    self._active_range_slider = nil
    self._extension_epoch = RotationSettingsUI._extension_epoch - 1
    self._window_close_requested = false
    self._tab_scroll_offsets = {}
    self._scrollbar_drag = nil
    self._scroll_viewport = nil
    self._side_menu_active_pages = {}
    self._content_x_start = LAYOUT.padding_side
    self._side_menu_reserved_left = 0
    self._scrollbar_reserved_right = 0
    self._prev_native_scroll_y = 0
    self._panel_height_cache = {}

    -- Data table sort state: keyed by table id -> { column_key, ascending }
    self._table_sort_state = {}

    -- Context menu state
    self._context_menu = nil

    -- Search config & state
    local search_config = config.search
    if search_config == true then
        search_config = { enabled = true }
    elseif type(search_config) ~= "table" then
        search_config = nil
    end
    self._search_config = search_config
    self._search_active = false
    self._search_query = ""
    self._search_input = nil

    return self
end

-- ============================================================================
-- THEME UPDATE
-- ============================================================================

function RotationSettingsUI:_update_theme()
    if not self.menu.theme_selector then
        return
    end

    local ok, theme_index = pcall(function()
        return self.menu.theme_selector:get()
    end)

    if ok and theme_index and THEME_NAMES[theme_index] then
        local new_theme_name = THEME_NAMES[theme_index]
        if new_theme_name ~= self.theme_name then
            self.theme_name = new_theme_name
            self.colors = THEMES[new_theme_name] or THEMES.astro
        end
    end
end

-- ============================================================================
-- SECTION REGISTRATION
-- ============================================================================

function RotationSettingsUI:register_section(section)
    if not section or not section.id or not section.type then
        return
    end

    table.insert(self.sections, section)
end

-- ============================================================================
-- CONTEXT MENU API
-- ============================================================================

function RotationSettingsUI:show_context_menu(items, x, y)
    if not items or #items == 0 then return end
    local mouse = self:_get_window_local_mouse_pos()
    self._context_menu = {
        items = items,
        x = x or (mouse and mouse.x or 0),
        y = y or (mouse and mouse.y or 0),
    }
end

-- ============================================================================
-- EXTENSION TAB SYNC (stub — overridden by tabs.lua)
-- ============================================================================

function RotationSettingsUI:_sync_extension_tabs()
    -- Stub: will be replaced by tabs.lua after TabBuilder is loaded
    self._extension_epoch = RotationSettingsUI._extension_epoch
end

function RotationSettingsUI:_ensure_extension_tabs()
    if self._extension_epoch ~= RotationSettingsUI._extension_epoch then
        self:_sync_extension_tabs()
    end
end

return RotationSettingsUI
