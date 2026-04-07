-- ext_lib_astro_ui/tabs.lua
-- Tab management, extension tabs, tab bar rendering

local constants = require("AstroUI/core/constants")
local helpers = require("AstroUI/core/helpers")
local RotationSettingsUI = require("AstroUI/core/class")
local tab_builder_module = require("AstroUI/builder/tab_builder")

---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")
---@type enums
local enums = require("common/enums")

local LAYOUT = constants.LAYOUT
local KEY_NAMES = constants.KEY_NAMES
local lighten_color = helpers.lighten_color
local TabBuilder = tab_builder_module.TabBuilder
local build_tab_section = tab_builder_module.build_tab_section

-- ============================================================================
-- TAB MANAGEMENT
-- ============================================================================

---@param tab table {id, label, visible_when?}
---@param build_fn fun(t:rotation_settings_ui_tab_builder)
function RotationSettingsUI:add_tab(tab, build_fn)
    if not tab or not tab.id or not tab.label then
        return
    end
    local section = {
        id = tab.id,
        label = tab.label,
        type = "tab",
        groups = {},
        visible_when = tab.visible_when
    }
    if build_fn and type(build_fn) == "function" then
        local builder = TabBuilder.new(self, section)
        pcall(build_fn, builder)
    end
    self:register_section(section)
end

function RotationSettingsUI._find_extension_index(id)
    for index, entry in ipairs(RotationSettingsUI._extension_tabs) do
        if entry.tab.id == id then
            return index
        end
    end
    return nil
end

function RotationSettingsUI.register_extension_tab(tab, build_fn)
    if not tab or not tab.id or not tab.label then
        return nil
    end
    local idx = RotationSettingsUI._find_extension_index(tab.id)
    if idx then
        RotationSettingsUI._extension_tabs[idx] = { tab = tab, build_fn = build_fn }
    else
        table.insert(RotationSettingsUI._extension_tabs, { tab = tab, build_fn = build_fn })
    end
    RotationSettingsUI._extension_epoch = RotationSettingsUI._extension_epoch + 1
    return function()
        RotationSettingsUI.unregister_extension_tab(tab.id)
    end
end

function RotationSettingsUI.unregister_extension_tab(tab_id)
    local idx = RotationSettingsUI._find_extension_index(tab_id)
    if not idx then
        return false
    end
    table.remove(RotationSettingsUI._extension_tabs, idx)
    RotationSettingsUI._extension_epoch = RotationSettingsUI._extension_epoch + 1
    return true
end

function RotationSettingsUI:set_tabs(tabs)
    self.sections = {}
    if not tabs then
        return
    end
    for _, tab in ipairs(tabs) do
        if tab then
            self:register_section(tab)
        end
    end
end

-- Override the stub from class.lua now that TabBuilder is available
function RotationSettingsUI:_sync_extension_tabs()
    for i = #self.sections, 1, -1 do
        if self.sections[i] and self.sections[i].__is_extension_tab == true then
            table.remove(self.sections, i)
        end
    end

    for _, entry in ipairs(RotationSettingsUI._extension_tabs) do
        local tab_info = entry.tab
        local tab_copy = {
            id = tab_info.id,
            label = tab_info.label,
            visible_when = tab_info.visible_when,
            __is_extension_tab = true
        }
        local section = build_tab_section(tab_copy, entry.build_fn, self)
        if section then
            table.insert(self.sections, section)
        end
    end

    self._extension_epoch = RotationSettingsUI._extension_epoch
end

-- ============================================================================
-- KEY NAME HELPER
-- ============================================================================

function RotationSettingsUI:_get_key_name(key_code)
    if KEY_NAMES[key_code] then
        return KEY_NAMES[key_code]
    end

    if key_code >= 48 and key_code <= 57 then
        return string.char(key_code)
    end

    if key_code >= 65 and key_code <= 90 then
        return string.char(key_code)
    end

    return "Key" .. key_code
end

-- ============================================================================
-- SECTION VISIBILITY
-- ============================================================================

function RotationSettingsUI:_is_section_visible(section)
    if section.visible_when and type(section.visible_when) == "function" then
        local ok, result = pcall(section.visible_when)
        if ok then
            return result == true
        end
        return false
    end
    return true
end

-- ============================================================================
-- TAB STATE MANAGEMENT
-- ============================================================================

function RotationSettingsUI:_sync_tab_state()
    if self.menu.active_tab then
        local saved_tab = self.menu.active_tab:get()
        if saved_tab >= 1 and saved_tab <= #self.sections then
            self.active_tab_index = saved_tab
        end
    end
end

-- ============================================================================
-- TAB BAR RENDERING
-- ============================================================================

function RotationSettingsUI:_render_tab_bar()
    local window_size = self.window:get_size()
    local right_reserved = LAYOUT.tab_bar_right_reserved
    if self._search_config and self._search_config.enabled ~= false then
        right_reserved = right_reserved + 24
    end
    local content_width = window_size.x - (2 * LAYOUT.padding_side) - right_reserved
    local x_start = LAYOUT.padding_side
    local y_start = LAYOUT.padding_top

    local visible_indices = {}
    for i, section in ipairs(self.sections) do
        if self:_is_section_visible(section) then
            table.insert(visible_indices, i)
        end
    end

    local visible_count = #visible_indices
    if visible_count == 0 then
        return y_start
    end

    local spacing = LAYOUT.tab_button_spacing

    local tabs_per_row = math.max(1, math.floor((content_width + spacing) / (LAYOUT.tab_button_min_width + spacing)))
    tabs_per_row = math.min(tabs_per_row, visible_count)

    local tab_width = math.floor((content_width - (tabs_per_row - 1) * spacing) / tabs_per_row)
    tab_width = math.min(LAYOUT.tab_button_max_width, math.max(LAYOUT.tab_button_min_width, tab_width))

    local current_x = x_start
    local current_y = y_start
    local col = 0

    for _, i in ipairs(visible_indices) do
        local section = self.sections[i]
        if section then
            if col >= tabs_per_row then
                col = 0
                current_x = x_start
                current_y = current_y + LAYOUT.tab_button_height + spacing
            end

            local is_active = (i == self.active_tab_index)

            local tab_start = vec2.new(current_x, current_y)
            local tab_end = vec2.new(current_x + tab_width, current_y + LAYOUT.tab_button_height)

            local is_hovered = self.window:is_mouse_hovering_rect(tab_start, tab_end)
            self.window:is_mouse_hovering_rect_block_movement(tab_start, tab_end)

            local bg_color, text_color, border_color
            if is_active then
                bg_color = self.colors.primary_accent
                text_color = self.colors.tab_text_active or color.white(255)
                border_color = self.colors.primary_accent
            elseif is_hovered then
                bg_color = lighten_color(self.colors.section_bg, 20)
                text_color = self.colors.text_primary
                border_color = self.colors.section_border
            else
                bg_color = self.colors.section_bg
                text_color = self.colors.text_secondary
                border_color = self.colors.section_border
            end

            self.window:render_rect_filled(tab_start, tab_end, bg_color, 2.0)
            self.window:render_rect(tab_start, tab_end, border_color, 2.0, 1.0)

            local label = section.label or ("Tab " .. i)
            local text_size = self.window:get_text_size(label)

            local max_text_width = tab_width - 10
            if text_size.x > max_text_width then
                local truncated_label = label
                while #truncated_label > 0 do
                    local test_label = truncated_label .. "..."
                    local test_size = self.window:get_text_size(test_label)
                    if test_size.x <= max_text_width then
                        label = test_label
                        text_size = test_size
                        break
                    end
                    truncated_label = string.sub(truncated_label, 1, -2)
                end
            end

            local text_x = current_x + (tab_width - text_size.x) / 2
            local text_y = current_y + (LAYOUT.tab_button_height - text_size.y) / 2
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL,
                vec2.new(text_x, text_y), text_color, label)

            if self.window:is_rect_clicked(tab_start, tab_end) then
                self.active_tab_index = i
                self._active_color_editor = nil
                if self.menu.active_tab then
                    self.menu.active_tab:set(i)
                end
            end

            current_x = current_x + tab_width + spacing
            col = col + 1
        end
    end

    -- Search icon (right side of tab bar, if search enabled)
    if self._search_config and self._search_config.enabled ~= false then
        local icon_size = 20
        local icon_x = window_size.x - LAYOUT.padding_side - right_reserved + LAYOUT.tab_bar_right_reserved + 2
        local icon_y = y_start + (LAYOUT.tab_button_height - icon_size) / 2
        local icon_start = vec2.new(icon_x, icon_y)
        local icon_end = vec2.new(icon_x + icon_size, icon_y + icon_size)

        local icon_hovered = self.window:is_mouse_hovering_rect(icon_start, icon_end)
        self.window:is_mouse_hovering_rect_block_movement(icon_start, icon_end)

        local icon_bg = self._search_active and self.colors.primary_accent
            or (icon_hovered and lighten_color(self.colors.section_bg, 20) or self.colors.section_bg)
        self.window:render_rect_filled(icon_start, icon_end, icon_bg, 3.0)
        self.window:render_rect(icon_start, icon_end, self.colors.section_border, 3.0, 1.0)

        local s_text = "S"
        local s_size = self.window:get_text_size(s_text)
        local s_col = self._search_active and color.white(255) or self.colors.text_secondary
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL,
            vec2.new(icon_x + (icon_size - s_size.x) / 2, icon_y + (icon_size - s_size.y) / 2),
            s_col, s_text)

        if self.window:is_rect_clicked(icon_start, icon_end) then
            self._search_active = not self._search_active
            if not self._search_active then
                self._search_query = ""
                if self._search_input then
                    pcall(function() self._search_input:set("") end)
                end
            end
        end
    end

    return current_y + LAYOUT.tab_button_height + LAYOUT.tab_bar_padding_top
end

-- ============================================================================
-- ACTIVE TAB CONTENT RENDERING
-- ============================================================================

function RotationSettingsUI:_render_active_tab_content(y_offset)
    if self.active_tab_index < 1 or self.active_tab_index > #self.sections then
        return y_offset
    end

    local section = self.sections[self.active_tab_index]
    if not section or not self:_is_section_visible(section) then
        return y_offset
    end

    if section.type == "keybind_grid" then
        return self:_render_keybind_grid(section, y_offset)
    elseif section.type == "checkbox_grid" then
        return self:_render_checkbox_grid(section, y_offset)
    elseif section.type == "slider_list" then
        return self:_render_slider_list(section, y_offset)
    elseif section.type == "combo_list" then
        return self:_render_combo_list(section, y_offset)
    elseif section.type == "color_list" then
        return self:_render_color_list(section, y_offset)
    elseif section.type == "tab" then
        return self:_render_tab_groups(section, y_offset)
    end

    return y_offset
end

-- ============================================================================
-- SECTION HEADER RENDERING
-- ============================================================================

function RotationSettingsUI:_render_section_header(section, y_offset)
    if not section.label then
        return
    end

    local window_size = self.window:get_size()
    local x_start = LAYOUT.padding_side
    local x_end = window_size.x - LAYOUT.padding_side

    local section_bg_start = vec2.new(x_start, y_offset)
    local section_bg_end = vec2.new(x_end, y_offset + LAYOUT.section_header_height)
    self.window:render_rect_filled(section_bg_start, section_bg_end, self.colors.section_bg, 2.0)
    self.window:render_rect(section_bg_start, section_bg_end, self.colors.section_border, 2.0, 1.0)

    local text_size = self.window:get_text_size(section.label)
    local text_x = x_start + ((x_end - x_start) - text_size.x) / 2
    local text_y = y_offset + (LAYOUT.section_header_height - text_size.y) / 2
    self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(text_x, text_y),
        self.colors.secondary_accent, section.label)
end


