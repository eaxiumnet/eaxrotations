-- ext_lib_astro_ui/render_core.lua
-- Core widget renderers: dispatch, keybind grid, checkbox grid

local constants = require("ext_lib_astro_ui/core/constants")
local helpers = require("ext_lib_astro_ui/core/helpers")
local RotationSettingsUI = require("ext_lib_astro_ui/core/class")

---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")
---@type enums
local enums = require("common/enums")

local LAYOUT = constants.LAYOUT
local lighten_color = helpers.lighten_color
local is_mouse_clicked_left = helpers.is_mouse_clicked_left

function RotationSettingsUI:_render_keybind_grid(section, y_offset)
    if not section.elements or #section.elements == 0 then
        return y_offset
    end

    local content_width = self:_get_content_width()
    local x_start = self:_get_content_x_start()

    y_offset = y_offset + LAYOUT.section_padding_top

    for i, element in ipairs(section.elements) do
        if element then
            local row_top = y_offset
            local row_bottom = y_offset + LAYOUT.element_height
            local label = (section.labels and section.labels[i]) or ("Keybind " .. i)

            local ok_key, key_code = pcall(function()
                return element:get_key_code()
            end)
            if not ok_key then
                key_code = 999
            end

            local ok_state, is_enabled = pcall(function()
                if element.get_toggle_state then
                    return element:get_toggle_state()
                end
                if element.get_state then
                    return element:get_state()
                end
                return false
            end)
            if not ok_state or is_enabled == nil then
                is_enabled = false
            end

            local key_name = self:_get_key_name(key_code)

            -- Define rectangles
            local key_box_start = vec2.new(x_start, y_offset)
            local key_box_end = vec2.new(x_start + LAYOUT.keybind_badge_width, y_offset + LAYOUT.element_height - 2)

            local clear_action_width = LAYOUT.keybind_clear_width
            local clear_box_end = vec2.new(x_start + content_width, y_offset + LAYOUT.element_height - 2)
            local clear_box_start = vec2.new(clear_box_end.x - clear_action_width, y_offset)
            local status_box_end = vec2.new(clear_box_start.x, y_offset + LAYOUT.element_height - 2)
            local status_box_start = vec2.new(status_box_end.x - LAYOUT.keybind_status_width, y_offset)

            -- Hover states for visual feedback
            local is_key_hovered = self.window:is_mouse_hovering_rect(key_box_start, key_box_end)
            local is_status_hovered = self.window:is_mouse_hovering_rect(status_box_start, status_box_end)
            local is_clear_hovered = self.window:is_mouse_hovering_rect(clear_box_start, clear_box_end)

            -- Prevent window dragging while interacting with this row
            if self:_is_y_visible(row_top, row_bottom) then
                self.window:is_mouse_hovering_rect_block_movement(key_box_start, key_box_end)
                self.window:is_mouse_hovering_rect_block_movement(status_box_start, status_box_end)
                self.window:is_mouse_hovering_rect_block_movement(clear_box_start, clear_box_end)
            end

            -- Custom Rendering - Key badge (left)
            local is_capturing_keybind = self._active_key_capture and self._active_key_capture.element == element

            if self:_is_y_visible(row_top, row_bottom) then
                local key_bg_color = is_key_hovered and lighten_color(self.colors.keybind_bg, 30) or self.colors.keybind_bg
                if is_capturing_keybind then
                    key_bg_color = self.colors.keybind_active
                end
                self.window:render_rect_filled(key_box_start, key_box_end, key_bg_color, 2.0)
                self.window:render_rect(key_box_start, key_box_end, self.colors.keybind_border, 2.0, 1.0)

                local key_text_size = self.window:get_text_size(key_name)
                local key_text_x = x_start + (LAYOUT.keybind_badge_width - key_text_size.x) / 2
                local key_text_y = y_offset + (LAYOUT.element_height - 2 - key_text_size.y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(key_text_x, key_text_y),
                    self.colors.text_primary, key_name)

                if self.window:is_rect_clicked(key_box_start, key_box_end) then
                    self:_start_key_capture(element, label)
                end

                -- Label (middle)
                local label_x = x_start + LAYOUT.keybind_badge_width + 12
                local label_y = y_offset + (LAYOUT.element_height - 2 - self.window:get_text_size(label).y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(label_x, label_y),
                    self.colors.text_primary, label)

                -- Status badge (right)
                local status_text = is_enabled and "ON" or "OFF"
                local status_color = is_enabled and self.colors.keybind_active or self.colors.keybind_inactive
                local status_hover_color = is_status_hovered and lighten_color(status_color, 30) or status_color
                self.window:render_rect_filled(status_box_start, status_box_end, status_hover_color, 2.0)

                local status_text_size = self.window:get_text_size(status_text)
                local status_text_x = status_box_start.x + (LAYOUT.keybind_status_width - status_text_size.x) / 2
                local status_text_y = y_offset + (LAYOUT.element_height - 2 - status_text_size.y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(status_text_x, status_text_y),
                    color.white(255), status_text)

                -- Clear badge
                local clear_bg = is_clear_hovered and lighten_color(self.colors.slider_bg, 20) or self.colors.slider_bg
                self.window:render_rect_filled(clear_box_start, clear_box_end, clear_bg, 1.5)
                self.window:render_rect(clear_box_start, clear_box_end, self.colors.section_border, 1.5, 1.0)
                local clear_text = "Clear"
                local clear_text_size = self.window:get_text_size(clear_text)
                local clear_text_x = clear_box_start.x + (LAYOUT.keybind_clear_width - clear_text_size.x) / 2
                local clear_text_y = y_offset + (LAYOUT.element_height - 2 - clear_text_size.y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(clear_text_x, clear_text_y),
                    self.colors.text_secondary, clear_text)
                if self.window:is_rect_clicked(clear_box_start, clear_box_end) then
                    pcall(function()
                        if element.set_key then
                            element:set_key(999)
                        end
                    end)
                end

                -- INPUT HANDLING
                -- Click on Status Badge → Toggle Enable State
                if self.window:is_rect_clicked(status_box_start, status_box_end) then
                    pcall(function()
                        if element.set_toggle_state then
                            element:set_toggle_state(not is_enabled)
                        elseif element.set_state then
                            element:set_state(not is_enabled)
                        end
                    end)
                end
            end

            y_offset = y_offset + LAYOUT.element_height + LAYOUT.element_spacing
        end
    end

    return y_offset + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- CHECKBOX GRID RENDERING (Custom + Interactive)
-- ============================================================================

function RotationSettingsUI:_render_checkbox_grid(section, y_offset)
    if not section.elements or #section.elements == 0 then
        return y_offset
    end

    local content_width = self:_get_content_width()
    local x_start = self:_get_content_x_start()

    local columns = section.columns or 2
    local column_width = (content_width - ((columns - 1) * LAYOUT.column_spacing)) / columns

    y_offset = y_offset + LAYOUT.section_padding_top

    local row = 0
    local col = 0

    for i, item in ipairs(section.elements) do
        if item and item.element and self:_is_entry_visible(item) then
            local element = item.element
            local label = item.label or ("Option " .. i)

            local ok_state, is_checked = pcall(function()
                return element:get_state()
            end)
            if not ok_state then
                is_checked = false
            end

            local x_pos = x_start + (col * (column_width + LAYOUT.column_spacing))

            -- Checkbox rectangle
            local checkbox_start = vec2.new(x_pos, y_offset)
            local checkbox_end = vec2.new(x_pos + LAYOUT.checkbox_size, y_offset + LAYOUT.checkbox_size)
            local row_top = y_offset
            local row_bottom = y_offset + LAYOUT.element_height

            if self:_is_y_visible(row_top, row_bottom) then
                -- Hover state
                local is_hovered = self.window:is_mouse_hovering_rect(checkbox_start, checkbox_end)

                -- Custom Rendering
                local checkbox_color = is_checked and self.colors.checkbox_active or self.colors.checkbox_inactive
                if is_hovered then
                    checkbox_color = lighten_color(checkbox_color, 30)
                end

                self.window:render_rect_filled(checkbox_start, checkbox_end, checkbox_color, 1.0)
                self.window:render_rect(checkbox_start, checkbox_end, self.colors.checkbox_border, 1.0, 1.0)

                -- Checkmark if enabled
                if is_checked then
                    local check_padding = 3
                    local check_start = vec2.new(x_pos + check_padding, y_offset + check_padding)
                    local check_end = vec2.new(x_pos + LAYOUT.checkbox_size - check_padding, y_offset + LAYOUT.checkbox_size - check_padding)
                    self.window:render_rect_filled(check_start, check_end, color.white(255), 0.5)
                end

                -- Label
                local label_x = x_pos + LAYOUT.checkbox_size + 8
                local label_y = y_offset + (LAYOUT.checkbox_size - self.window:get_text_size(label).y) / 2
                local label_color = is_checked and self.colors.text_primary or self.colors.text_secondary
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(label_x, label_y),
                    label_color, label)

                -- INPUT HANDLING
                -- Click → Toggle
                local row_click_start = vec2.new(x_pos, y_offset)
                local row_click_end = vec2.new(x_pos + column_width, y_offset + LAYOUT.checkbox_size)
                self.window:is_mouse_hovering_rect_block_movement(row_click_start, row_click_end)
                if self.window:is_rect_clicked(row_click_start, row_click_end) then
                    pcall(function()
                        if element.set then
                            element:set(not is_checked)
                        elseif element.set_state then
                            element:set_state(not is_checked)
                        end
                    end)
                end

                -- Context menu support (right-click)
                if item.context_menu and self.window:is_mouse_button_clicked(1) and is_hovered then
                    self:show_context_menu(item.context_menu)
                end
            end

            col = col + 1
            if col >= columns then
                col = 0
                row = row + 1
                y_offset = y_offset + LAYOUT.element_height + LAYOUT.element_spacing
            end
        end
    end

    if col > 0 then
        y_offset = y_offset + LAYOUT.element_height + LAYOUT.element_spacing
    end

    return y_offset + LAYOUT.section_padding_bottom
end

function RotationSettingsUI:_render_tab_groups(section, y_offset)
    if not section.groups or #section.groups == 0 then
        return y_offset
    end

    local active_page_id = nil
    if section.side_menu and section.id then
        active_page_id = self:_get_active_page_id(section.id)
    end

    -- Search filter
    local search_query = nil
    if self._search_active and self._search_query and #self._search_query >= ((self._search_config and self._search_config.min_query_length) or 2) then
        search_query = string.lower(self._search_query)
    end

    for _, group in ipairs(section.groups) do
        if not self:_is_entry_visible(group) then
            goto continue_group
        end

        if active_page_id and group.page and tostring(group.page) ~= tostring(active_page_id) then
            goto continue_group
        end

        -- Search filtering
        if search_query then
            local matches = false
            if group.label and string.find(string.lower(group.label), search_query, 1, true) then
                matches = true
            end
            if not matches and group.elements then
                for _, el in ipairs(group.elements) do
                    if el.label and string.find(string.lower(el.label), search_query, 1, true) then
                        matches = true
                        break
                    end
                end
            end
            if not matches and group.button_label and string.find(string.lower(group.button_label), search_query, 1, true) then
                matches = true
            end
            if not matches and group.text and type(group.text) == "string" and string.find(string.lower(group.text), search_query, 1, true) then
                matches = true
            end
            if not matches then
                goto continue_group
            end
        end

        if group.label then
            local label_h = self.window:get_text_size(group.label).y + 6
            if self:_is_y_visible(y_offset, y_offset + label_h) then
                local label_pos = vec2.new(self:_get_content_x_start(), y_offset)
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, label_pos,
                    self.colors.primary_accent, group.label)
            end
            y_offset = y_offset + label_h
        end

        if group.type == "checkbox_grid" then
            y_offset = self:_render_checkbox_grid(group, y_offset)
        elseif group.type == "runtime_checkbox_list" then
            y_offset = self:_render_runtime_checkbox_list(group, y_offset)
        elseif group.type == "slider_list" then
            y_offset = self:_render_slider_list(group, y_offset)
        elseif group.type == "combo_list" then
            y_offset = self:_render_combo_list(group, y_offset)
        elseif group.type == "text_input_list" then
            y_offset = self:_render_text_input_list(group, y_offset)
        elseif group.type == "color_list" then
            y_offset = self:_render_color_list(group, y_offset)
        elseif group.type == "keybind_grid" then
            y_offset = self:_render_keybind_grid(group, y_offset)
        elseif group.type == "text" then
            y_offset = self:_render_text_block(group, y_offset)
        elseif group.type == "separator" then
            y_offset = self:_render_separator(group, y_offset)
        elseif group.type == "button" then
            y_offset = self:_render_button(group, y_offset)
        elseif group.type == "spacer" then
            y_offset = self:_render_spacer(group, y_offset)
        elseif group.type == "label" then
            y_offset = self:_render_label(group, y_offset)
        elseif group.type == "toggle_list" then
            y_offset = self:_render_toggle_list(group, y_offset)
        elseif group.type == "radio_group" then
            y_offset = self:_render_radio_group(group, y_offset)
        elseif group.type == "progress_bar" then
            y_offset = self:_render_progress_bar(group, y_offset)
        elseif group.type == "icon_button" then
            y_offset = self:_render_icon_button(group, y_offset)
        elseif group.type == "list_box" then
            y_offset = self:_render_list_box(group, y_offset)
        elseif group.type == "spinner" then
            y_offset = self:_render_spinner(group, y_offset)
        elseif group.type == "skeleton" then
            y_offset = self:_render_skeleton(group, y_offset)
        elseif group.type == "panel" then
            y_offset = self:_render_panel(group, y_offset)
        elseif group.type == "card" then
            y_offset = self:_render_card(group, y_offset)
        elseif group.type == "hstack" then
            y_offset = self:_render_hstack(group, y_offset)
        elseif group.type == "range_slider_list" then
            y_offset = self:_render_range_slider_list(group, y_offset)
        elseif group.type == "data_table" then
            y_offset = self:_render_data_table(group, y_offset)
        elseif group.type == "context_trigger" then
            y_offset = self:_render_context_trigger(group, y_offset)
        end

        ::continue_group::
    end

    return y_offset
end

return RotationSettingsUI
