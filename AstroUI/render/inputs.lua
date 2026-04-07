-- ext_lib_astro_ui/render_inputs.lua
-- Input widget renderers: slider, combo, key capture

local constants = require("AstroUI/core/constants")
local helpers = require("AstroUI/core/helpers")
local RotationSettingsUI = require("AstroUI/core/class")

---@type color
local color = require("api/common/color")
---@type vec2
local vec2 = require("api/common/geometry/vector_2")
---@type enums
local enums = require("api/common/enums")

local LAYOUT = constants.LAYOUT
local KEY_NAMES = constants.KEY_NAMES
local lighten_color = helpers.lighten_color
local safe_window_mouse_check = helpers.safe_window_mouse_check
local is_mouse_pressed_left = helpers.is_mouse_pressed_left
local is_mouse_clicked_left = helpers.is_mouse_clicked_left

function RotationSettingsUI:_get_slider_bounds(entry)
    if not entry then
        return 0, 100
    end

    local function parse_value(value)
        if value == nil then
            return nil
        end
        if type(value) == "number" then
            return value
        end
        if type(value) == "string" then
            local parsed = tonumber(value)
            if parsed then
                return parsed
            end
        end
        if type(value) == "table" then
            if value.min ~= nil then
                return parse_value(value.min)
            end
            if value.max ~= nil then
                return parse_value(value.max)
            end
        end
        return nil
    end

    local explicit_min = nil
    local explicit_max = nil
    if entry.bounds then
        explicit_min = parse_value(entry.bounds.min)
        explicit_max = parse_value(entry.bounds.max)
    end
    if explicit_min == nil and entry.min ~= nil then
        explicit_min = parse_value(entry.min)
    end
    if explicit_max == nil and entry.max ~= nil then
        explicit_max = parse_value(entry.max)
    end

    if explicit_min ~= nil or explicit_max ~= nil then
        local min_value = explicit_min or 0
        local max_value = explicit_max or min_value
        if max_value < min_value then
            max_value = min_value
        end
        return min_value, max_value
    end

    local element = entry.element
    if not element then
        return 0, 100
    end

    local function normalize_number(value, fallback)
        if type(value) == "number" then
            return value
        end
        if type(value) == "string" then
            local parsed = tonumber(value)
            if parsed then
                return parsed
            end
        end
        if type(value) == "table" then
            if value.min then
                return normalize_number(value.min, fallback)
            end
            if value.max then
                return normalize_number(value.max, fallback)
            end
        end
        return fallback
    end

    local ok_min, min_from_api = pcall(function()
        if element.get_min then
            return element:get_min()
        end
        return nil
    end)
    local ok_max, max_from_api = pcall(function()
        if element.get_max then
            return element:get_max()
        end
        return nil
    end)

    local min_value = ok_min and normalize_number(min_from_api, 0) or 0
    local max_value = ok_max and normalize_number(max_from_api, 100) or 100

    if type(min_value) ~= "number" then
        min_value = 0
    end
    if type(max_value) ~= "number" then
        max_value = min_value
    end

    if max_value < min_value then
        max_value = min_value
    end

    if ok_min and ok_max then
        return min_value, max_value
    end

    local ok_bounds, bounds = pcall(function()
        if element.get_widget_bounds then
            return element:get_widget_bounds()
        end
        return nil
    end)

    if ok_bounds and bounds then
        local normalized_min = normalize_number(bounds.min or bounds.min_value, 0)
        local normalized_max = normalize_number(bounds.max or bounds.max_value, 100)
        if type(normalized_min) ~= "number" then
            normalized_min = 0
        end
        if type(normalized_max) ~= "number" then
            normalized_max = normalized_min
        end
        if normalized_max < normalized_min then
            normalized_max = normalized_min
        end
        return normalized_min, normalized_max
    end

    return 0, 100
end

function RotationSettingsUI:_apply_active_slider_from_mouse()
    if not self._active_slider or not self.window then
        return
    end

    local slider = self._active_slider
    if not slider.bar_width or slider.bar_width <= 0 or slider.min_value == slider.max_value then
        return
    end

    local mouse_space = slider.mouse_space or "adjusted"
    local mouse_pos = select(1, self:_get_window_local_mouse_pos(mouse_space))
    if not mouse_pos and mouse_space ~= "raw" then
        mouse_space = "raw"
        mouse_pos = select(1, self:_get_window_local_mouse_pos(mouse_space))
    end

    if not mouse_pos then
        return
    end

    slider.mouse_space = mouse_space
    slider.last_mouse_pos = vec2.new(mouse_pos.x, mouse_pos.y)

    local local_mouse_x = mouse_pos.x - slider.bar_x_start
    local clamped_x = math.max(0, math.min(slider.bar_width, local_mouse_x))
    local progress = clamped_x / slider.bar_width
    local new_value = slider.min_value + (slider.max_value - slider.min_value) * progress
    local rounded_value = math.floor(new_value + 0.5)
    local clamped_value = math.max(slider.min_value, math.min(slider.max_value, rounded_value))

    pcall(function()
        slider.element:set(clamped_value)
    end)
end

function RotationSettingsUI:_start_key_capture(element, label)
    if not element then
        return
    end

    if self.window then
        self.window:set_focus()
        self.window:block_input_capture()
    end

    self._active_key_capture = {
        element = element,
        label = label,
        wait_for_release = true
    }
end

function RotationSettingsUI:_process_key_capture_input()
    if not self._active_key_capture then
        return
    end

    if self._active_key_capture.wait_for_release then
        if not is_mouse_pressed_left(self.window) then
            self._active_key_capture.wait_for_release = false
        end
        return
    end

    if self.window then
        -- Allow binding mouse buttons except LMB/RMB.
        -- Map window button index -> Windows VK code.
        local mouse_vk_by_button_index = {
            [0] = 1, -- LMB
            [1] = 2, -- RMB
            [2] = 4, -- MMB
            [3] = 5, -- Mouse4 (XBUTTON1)
            [4] = 6  -- Mouse5 (XBUTTON2)
        }

        for button_index, vk_code in pairs(mouse_vk_by_button_index) do
            if button_index ~= 0 and button_index ~= 1 then
                if safe_window_mouse_check(self.window, "is_mouse_button_clicked", button_index) or core.input.is_key_pressed(vk_code) then
                    pcall(function()
                        if self._active_key_capture and self._active_key_capture.element and self._active_key_capture.element.set_key then
                            self._active_key_capture.element:set_key(vk_code)
                        end
                    end)
                    self._active_key_capture = nil
                    return
                end
            end
        end
    end

    for key_code = 1, 255 do
        if key_code == 1 or key_code == 2 then
            goto continue_key
        end
        if core.input.is_key_pressed(key_code) then
            if key_code == 27 then
                self._active_key_capture = nil
                return
            end

            pcall(function()
                if key_code == 8 or key_code == 46 then
                    if self._active_key_capture.element.set_key then
                        self._active_key_capture.element:set_key(999)
                    end
                elseif self._active_key_capture.element.set_key then
                    self._active_key_capture.element:set_key(key_code)
                end
            end)

            self._active_key_capture = nil
            return
        end

        ::continue_key::
    end
end

function RotationSettingsUI:_render_key_capture_prompt()
    if not self._active_key_capture or not self.window then
        return
    end

    local prompt_label = self._active_key_capture.label or "keybind"
    local prompt_text = string.format("Press a key for %s (Esc to cancel, Del to clear)", prompt_label)
    local window_size = self.window:get_size()
    local text_size = self.window:get_text_size(prompt_text)
    local prompt_pos = vec2.new(LAYOUT.padding_side, window_size.y - LAYOUT.padding_bottom - text_size.y - 4)
    self.window:render_text(enums.window_enums.font_id.FONT_SMALL, prompt_pos, self.colors.secondary_accent, prompt_text)
end

-- ============================================================================
-- SLIDER LIST RENDERING (Custom + Interactive)
-- ============================================================================

function RotationSettingsUI:_render_slider_list(section, y_offset)
    if not section.elements or #section.elements == 0 then
        return y_offset
    end

    local content_width = self:_get_content_width()
    local x_start = self:_get_content_x_start()

    y_offset = y_offset + LAYOUT.section_padding_top

    local label_width = 180
    local bar_width = content_width - label_width - 60

    for i, item in ipairs(section.elements) do
        if item and item.element and self:_is_entry_visible(item) then
            local element = item.element
            local label = item.label or ("Slider " .. i)
            local suffix = item.suffix or ""

            local ok_val, value = pcall(function()
                return element:get()
            end)
            if not ok_val or value == nil then
                value = 0
            end

            local min_value, max_value = self:_get_slider_bounds(item)
            if max_value < min_value then
                max_value = min_value
            end

            -- Define rectangles
            local bar_x_start = x_start + label_width
            local bar_start = vec2.new(bar_x_start, y_offset)
            local bar_end = vec2.new(bar_x_start + bar_width, y_offset + LAYOUT.slider_bar_height)
            local row_top = y_offset
            local row_bottom = y_offset + LAYOUT.slider_bar_height + 6

            local is_hovered = false
            if self:_is_y_visible(row_top, row_bottom) then
                -- Hover/Press state
                is_hovered = self.window:is_mouse_hovering_rect(bar_start, bar_end)
                self.window:is_mouse_hovering_rect_block_movement(bar_start, bar_end)

                -- Custom Rendering - Label
                local label_y = y_offset + (LAYOUT.slider_bar_height - self.window:get_text_size(label).y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start, label_y),
                    self.colors.text_primary, label)

                -- Progress bar background
                local bg_color = is_hovered and lighten_color(self.colors.slider_bg, 20) or self.colors.slider_bg
                self.window:render_rect_filled(bar_start, bar_end, bg_color, 1.5)

                -- Progress bar fill
                local fill_progress = max_value > min_value and ((value - min_value) / (max_value - min_value)) or 0
                local clamped_progress = math.max(0, math.min(1, fill_progress))
                local fill_width = bar_width * clamped_progress
                local fill_end = vec2.new(bar_x_start + fill_width, y_offset + LAYOUT.slider_bar_height)
                self.window:render_rect_filled(bar_start, fill_end, self.colors.slider_fill, 1.5)

                -- Progress bar border
                local is_active_slider = self._active_slider and self._active_slider.element == element
                local border_color = is_active_slider and self.colors.secondary_accent or self.colors.primary_accent
                self.window:render_rect(bar_start, bar_end, border_color, 1.5, 1.0)

                -- Value text
                local value_text = string.format("%d%s", value, suffix)
                local value_x = bar_x_start + bar_width + 10
                local value_y = y_offset + (LAYOUT.slider_bar_height - self.window:get_text_size(value_text).y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(value_x, value_y),
                    self.colors.text_secondary, value_text)

                -- INPUT HANDLING
                if is_hovered and is_mouse_clicked_left(self.window) then
                    self.window:block_input_capture()

                    local mouse_space = "adjusted"
                    local mouse_pos = select(1, self:_get_window_local_mouse_pos(mouse_space))
                    if not mouse_pos then
                        mouse_space = "raw"
                        mouse_pos = select(1, self:_get_window_local_mouse_pos(mouse_space))
                    end

                    if mouse_pos then
                        self._active_slider = {
                            element = element,
                            min_value = min_value,
                            max_value = max_value,
                            bar_x_start = bar_x_start,
                            bar_width = bar_width,
                            last_mouse_pos = vec2.new(mouse_pos.x, mouse_pos.y),
                            mouse_space = mouse_space
                        }
                        self:_apply_active_slider_from_mouse()
                    end
                end

                -- Context menu support (right-click)
                if item.context_menu and self.window:is_mouse_button_clicked(1) and is_hovered then
                    self:show_context_menu(item.context_menu)
                end
            end

            y_offset = y_offset + LAYOUT.slider_bar_height + LAYOUT.element_spacing + 4
        end
    end

    if self._active_slider then
        if is_mouse_pressed_left(self.window) then
            self.window:block_input_capture()
            self:_apply_active_slider_from_mouse()
        else
            self._active_slider = nil
        end
    end

    return y_offset + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- RANGE SLIDER LIST RENDERING (Dual-Handle)
-- ============================================================================

function RotationSettingsUI:_apply_active_range_slider_from_mouse()
    local rs = self._active_range_slider
    if not rs or not self.window then
        return
    end

    if not rs.bar_width or rs.bar_width <= 0 or rs.bounds_min == rs.bounds_max then
        return
    end

    local mouse_space = rs.mouse_space or "adjusted"
    local mouse_pos = select(1, self:_get_window_local_mouse_pos(mouse_space))
    if not mouse_pos and mouse_space ~= "raw" then
        mouse_space = "raw"
        mouse_pos = select(1, self:_get_window_local_mouse_pos(mouse_space))
    end

    if not mouse_pos then
        return
    end

    rs.mouse_space = mouse_space

    local local_mouse_x = mouse_pos.x - rs.bar_x_start
    local clamped_x = math.max(0, math.min(rs.bar_width, local_mouse_x))
    local progress = clamped_x / rs.bar_width
    local new_value = rs.bounds_min + (rs.bounds_max - rs.bounds_min) * progress
    local rounded_value = math.floor(new_value + 0.5)

    if rs.handle == "min" then
        local max_val = rs.bounds_max
        pcall(function() max_val = rs.max_element:get() end)
        rounded_value = math.max(rs.bounds_min, math.min(max_val, rounded_value))
        pcall(function() rs.min_element:set(rounded_value) end)
    else
        local min_val = rs.bounds_min
        pcall(function() min_val = rs.min_element:get() end)
        rounded_value = math.max(min_val, math.min(rs.bounds_max, rounded_value))
        pcall(function() rs.max_element:set(rounded_value) end)
    end
end

function RotationSettingsUI:_render_range_slider_list(section, y_offset)
    if not section.elements or #section.elements == 0 then
        return y_offset
    end

    local content_width = self:_get_content_width()
    local x_start = self:_get_content_x_start()

    y_offset = y_offset + LAYOUT.section_padding_top

    local label_width = 180
    local bar_width = content_width - label_width - 80

    for i, item in ipairs(section.elements) do
        if item and item.min_element and item.max_element and self:_is_entry_visible(item) then
            local min_element = item.min_element
            local max_element = item.max_element
            local label = item.label or ("Range " .. i)
            local suffix = item.suffix or ""

            local ok_min_val, min_val = pcall(function() return min_element:get() end)
            if not ok_min_val or min_val == nil then min_val = 0 end
            local ok_max_val, max_val = pcall(function() return max_element:get() end)
            if not ok_max_val or max_val == nil then max_val = 100 end

            local bounds_min, bounds_max = self:_get_slider_bounds(item)
            if bounds_max < bounds_min then bounds_max = bounds_min end

            local bar_x_start = x_start + label_width
            local bar_start = vec2.new(bar_x_start, y_offset)
            local bar_end = vec2.new(bar_x_start + bar_width, y_offset + LAYOUT.slider_bar_height)
            local row_top = y_offset
            local row_bottom = y_offset + LAYOUT.slider_bar_height + 6

            local is_hovered = false
            if self:_is_y_visible(row_top, row_bottom) then
                is_hovered = self.window:is_mouse_hovering_rect(bar_start, bar_end)
                self.window:is_mouse_hovering_rect_block_movement(bar_start, bar_end)

                -- Label
                local label_y = y_offset + (LAYOUT.slider_bar_height - self.window:get_text_size(label).y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start, label_y),
                    self.colors.text_primary, label)

                -- Bar background
                local bg_color = is_hovered and lighten_color(self.colors.slider_bg, 20) or self.colors.slider_bg
                self.window:render_rect_filled(bar_start, bar_end, bg_color, 1.5)

                -- Fill between min and max handles
                local range = bounds_max - bounds_min
                local min_progress = range > 0 and ((min_val - bounds_min) / range) or 0
                local max_progress = range > 0 and ((max_val - bounds_min) / range) or 0
                min_progress = math.max(0, math.min(1, min_progress))
                max_progress = math.max(0, math.min(1, max_progress))

                local fill_start_x = bar_x_start + bar_width * min_progress
                local fill_end_x = bar_x_start + bar_width * max_progress
                if fill_end_x > fill_start_x then
                    self.window:render_rect_filled(
                        vec2.new(fill_start_x, y_offset),
                        vec2.new(fill_end_x, y_offset + LAYOUT.slider_bar_height),
                        self.colors.slider_fill, 1.5)
                end

                -- Handle markers (4px wide rects at handle positions)
                local handle_w = 4
                local handle_h = LAYOUT.slider_bar_height
                local min_handle_x = bar_x_start + bar_width * min_progress - handle_w / 2
                local max_handle_x = bar_x_start + bar_width * max_progress - handle_w / 2

                local is_active_min = self._active_range_slider and self._active_range_slider.handle == "min"
                    and self._active_range_slider.min_element == min_element
                local is_active_max = self._active_range_slider and self._active_range_slider.handle == "max"
                    and self._active_range_slider.max_element == max_element

                local min_handle_col = is_active_min and self.colors.secondary_accent or self.colors.primary_accent
                local max_handle_col = is_active_max and self.colors.secondary_accent or self.colors.primary_accent

                self.window:render_rect_filled(
                    vec2.new(min_handle_x, y_offset),
                    vec2.new(min_handle_x + handle_w, y_offset + handle_h),
                    min_handle_col, 1.0)
                self.window:render_rect_filled(
                    vec2.new(max_handle_x, y_offset),
                    vec2.new(max_handle_x + handle_w, y_offset + handle_h),
                    max_handle_col, 1.0)

                -- Border
                local is_active = self._active_range_slider
                    and self._active_range_slider.min_element == min_element
                local border_color = is_active and self.colors.secondary_accent or self.colors.primary_accent
                self.window:render_rect(bar_start, bar_end, border_color, 1.5, 1.0)

                -- Value text
                local value_text = string.format("%d - %d%s", min_val, max_val, suffix)
                local value_x = bar_x_start + bar_width + 10
                local value_y = y_offset + (LAYOUT.slider_bar_height - self.window:get_text_size(value_text).y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(value_x, value_y),
                    self.colors.text_secondary, value_text)

                -- Click handling: find nearest handle
                if is_hovered and is_mouse_clicked_left(self.window) then
                    self.window:block_input_capture()

                    local mouse_space = "adjusted"
                    local mouse_pos = select(1, self:_get_window_local_mouse_pos(mouse_space))
                    if not mouse_pos then
                        mouse_space = "raw"
                        mouse_pos = select(1, self:_get_window_local_mouse_pos(mouse_space))
                    end

                    if mouse_pos then
                        local mouse_x = mouse_pos.x
                        local dist_to_min = math.abs(mouse_x - (min_handle_x + handle_w / 2))
                        local dist_to_max = math.abs(mouse_x - (max_handle_x + handle_w / 2))
                        local handle = dist_to_min <= dist_to_max and "min" or "max"

                        self._active_range_slider = {
                            min_element = min_element,
                            max_element = max_element,
                            handle = handle,
                            bounds_min = bounds_min,
                            bounds_max = bounds_max,
                            bar_x_start = bar_x_start,
                            bar_width = bar_width,
                            mouse_space = mouse_space
                        }
                        self:_apply_active_range_slider_from_mouse()
                    end
                end

                -- Context menu support
                if item.context_menu and self.window:is_mouse_button_clicked(1) and is_hovered then
                    self:show_context_menu(item.context_menu)
                end
            end

            y_offset = y_offset + LAYOUT.slider_bar_height + LAYOUT.element_spacing + 4
        end
    end

    -- Handle active drag
    if self._active_range_slider then
        if is_mouse_pressed_left(self.window) then
            self.window:block_input_capture()
            self:_apply_active_range_slider_from_mouse()
        else
            self._active_range_slider = nil
        end
    end

    return y_offset + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- COMBO LIST RENDERING
-- ============================================================================

function RotationSettingsUI:_render_combo_list(section, y_offset)
    if not section.elements or #section.elements == 0 then
        return y_offset
    end

    local content_width = self:_get_content_width()
    local x_start = self:_get_content_x_start()

    y_offset = y_offset + LAYOUT.section_padding_top

    local label_width = 180
    local value_box_width = 160

    local open_dropdown = self._active_combo_dropdown

    for i, item in ipairs(section.elements) do
        if item and item.element and self:_is_entry_visible(item) then
            local element = item.element
            local label = item.label or ("Option " .. i)
            local suffix = item.suffix or ""
            local use_dropdown = item.dropdown == true
            local dropdown_max_visible = tonumber(item.dropdown_max_visible) or 5
            if dropdown_max_visible < 1 then
                dropdown_max_visible = 1
            end

            local ok_val, current_index = pcall(function()
                return element:get()
            end)
            if not ok_val or current_index == nil then
                current_index = 1
            end

            local options = item.options or {}
            local option_text = options[current_index] or tostring(current_index)
            if #suffix > 0 then
                option_text = option_text .. suffix
            end

            local box_start = vec2.new(x_start + label_width, y_offset)
            local box_end = vec2.new(x_start + label_width + value_box_width, y_offset + LAYOUT.slider_bar_height)
            local row_top = y_offset
            local row_bottom = y_offset + LAYOUT.slider_bar_height + 6

            if self:_is_y_visible(row_top, row_bottom) then
                local is_hovered = self.window:is_mouse_hovering_rect(box_start, box_end)
                self.window:is_mouse_hovering_rect_block_movement(box_start, box_end)

                local label_y = y_offset + (LAYOUT.slider_bar_height - self.window:get_text_size(label).y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start, label_y),
                    self.colors.text_primary, label)

                local bg_color = is_hovered and lighten_color(self.colors.slider_bg, 20) or self.colors.slider_bg
                self.window:render_rect_filled(box_start, box_end, bg_color, 1.5)
                local border_color = is_hovered and self.colors.secondary_accent or self.colors.primary_accent
                self.window:render_rect(box_start, box_end, border_color, 1.5, 1.0)

                local value_text_size = self.window:get_text_size(option_text)
                local value_x = box_start.x + (value_box_width - value_text_size.x) / 2
                local value_y = y_offset + (LAYOUT.slider_bar_height - value_text_size.y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(value_x, value_y),
                    self.colors.text_secondary, option_text)

                if self.window:is_rect_clicked(box_start, box_end) then
                    if #options > 0 then
                        if use_dropdown then
                            local el_key = tostring(element)
                            if open_dropdown and open_dropdown.element_key == el_key then
                                self._active_combo_dropdown = nil
                                open_dropdown = nil
                            else
                                local start_index = current_index - math.floor(dropdown_max_visible / 2)
                                if start_index < 1 then
                                    start_index = 1
                                end
                                self._active_combo_dropdown = {
                                    element = element,
                                    element_key = el_key,
                                    options = options,
                                    box_start = box_start,
                                    box_end = box_end,
                                    current_index = current_index,
                                    scroll_index = start_index,
                                    max_visible = dropdown_max_visible,
                                    label = label,
                                    suffix = suffix
                                }
                                open_dropdown = self._active_combo_dropdown
                            end
                        else
                            local next_index = ((current_index - 1 + 1) % #options) + 1
                            pcall(function()
                                if element.set then
                                    element:set(next_index)
                                end
                            end)
                        end
                    end
                end

                -- Context menu support (right-click)
                if item.context_menu and self.window:is_mouse_button_clicked(1) and is_hovered then
                    self:show_context_menu(item.context_menu)
                end
            end

            y_offset = y_offset + LAYOUT.slider_bar_height + LAYOUT.element_spacing + 4
        end
    end

    return y_offset + LAYOUT.section_padding_bottom
end

function RotationSettingsUI:_render_combo_dropdown_overlay()
    local dd = self._active_combo_dropdown
    if not dd or not self.window then
        return
    end

    local options = dd.options or {}
    if #options == 0 or not dd.box_start or not dd.box_end then
        self._active_combo_dropdown = nil
        return
    end

    local box_start = dd.box_start
    local box_end = dd.box_end
    local list_padding = 2
    local option_h = LAYOUT.element_height
    local total = #options

    local max_visible = tonumber(dd.max_visible) or 5
    if max_visible < 1 then
        max_visible = 1
    end
    local visible_count = math.min(total, max_visible)

    local win_size = self.window:get_size()
    local viewport = self._scroll_viewport
    local viewport_top = (viewport and viewport.top) or 0
    local viewport_bottom = (viewport and viewport.bottom) or win_size.y
    if viewport_bottom < viewport_top then
        viewport_bottom = viewport_top
    end

    local desired_h = visible_count * option_h
    local space_below = viewport_bottom - (box_end.y + list_padding)
    local space_above = (box_start.y - list_padding) - viewport_top

    local open_up = false
    if space_below >= desired_h then
        open_up = false
    elseif space_above >= desired_h then
        open_up = true
    else
        open_up = space_above > space_below
        local available = math.max(0, open_up and space_above or space_below)
        local fit = math.floor(available / option_h)
        if fit < 1 then
            fit = 1
        end
        visible_count = math.min(total, fit)
        desired_h = visible_count * option_h
    end

    local list_start = nil
    local list_end = nil
    if open_up then
        list_end = vec2.new(box_end.x, box_start.y - list_padding)
        list_start = vec2.new(box_start.x, list_end.y - desired_h)
    else
        list_start = vec2.new(box_start.x, box_end.y + list_padding)
        list_end = vec2.new(box_end.x, list_start.y + desired_h)
    end

    -- Clamp to viewport as a last resort (keeps the dropdown visible even when the row is near edges).
    if list_start.y < viewport_top then
        local dy = viewport_top - list_start.y
        list_start = vec2.new(list_start.x, list_start.y + dy)
        list_end = vec2.new(list_end.x, list_end.y + dy)
    end
    if list_end.y > viewport_bottom then
        local dy = list_end.y - viewport_bottom
        list_start = vec2.new(list_start.x, list_start.y - dy)
        list_end = vec2.new(list_end.x, list_end.y - dy)
    end

    -- Hover/click detection
    local list_hovered = self.window:is_mouse_hovering_rect(list_start, list_end)
    local box_hovered = self.window:is_mouse_hovering_rect(box_start, box_end)
    self.window:is_mouse_hovering_rect_block_movement(list_start, list_end)
    self.window:is_mouse_hovering_rect_block_movement(box_start, box_end)

    -- Close when clicking outside.
    if is_mouse_clicked_left(self.window) and not list_hovered and not box_hovered then
        self._active_combo_dropdown = nil
        return
    end

    local scroll_index = tonumber(dd.scroll_index) or 1
    if scroll_index < 1 then
        scroll_index = 1
    end
    if scroll_index > total then
        scroll_index = total
    end
    local max_scroll_index = math.max(1, total - visible_count + 1)
    if scroll_index > max_scroll_index then
        scroll_index = max_scroll_index
    end
    dd.scroll_index = scroll_index

    local is_scrollable = total > visible_count
    local control_w = is_scrollable and 18 or 0
    local control_x = list_end.x - control_w

    -- Draw dropdown
    self.window:render_rect_filled(list_start, list_end, self.colors.slider_bg, 1.5)
    self.window:render_rect(list_start, list_end, self.colors.primary_accent, 1.5, 1.0)

    if is_scrollable then
        local sep_start = vec2.new(control_x, list_start.y)
        local sep_end = vec2.new(control_x + 1, list_end.y)
        self.window:render_rect_filled(sep_start, sep_end, self.colors.separator, 0)
    end

    for row = 1, visible_count do
        local idx = scroll_index + (row - 1)
        local text = options[idx]

        local row_start = vec2.new(list_start.x, list_start.y + ((row - 1) * option_h))
        local row_end = vec2.new(control_x > list_start.x and control_x or list_end.x, row_start.y + option_h)

        local hovered = self.window:is_mouse_hovering_rect(row_start, row_end)
        local bg = hovered and lighten_color(self.colors.slider_bg, 25) or self.colors.slider_bg
        if idx == dd.current_index then
            bg = lighten_color(self.colors.slider_bg, 35)
        end
        self.window:render_rect_filled(row_start, vec2.new(list_end.x, row_end.y), bg, 0)

        local label = tostring(text or idx) .. (dd.suffix or "")
        local sz = self.window:get_text_size(label)
        local tx = row_start.x + 8
        local ty = row_start.y + (option_h - sz.y) / 2
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(tx, ty), self.colors.text_secondary, label)

        if self.window:is_rect_clicked(row_start, row_end) then
            pcall(function()
                if dd.element and dd.element.set then
                    dd.element:set(idx)
                end
            end)
            self._active_combo_dropdown = nil
            return
        end
    end

    if is_scrollable and control_w > 0 then
        local up_start = vec2.new(control_x, list_start.y)
        local up_end = vec2.new(list_end.x, list_start.y + option_h)
        local down_start = vec2.new(control_x, list_end.y - option_h)
        local down_end = vec2.new(list_end.x, list_end.y)

        local up_disabled = scroll_index <= 1
        local down_disabled = scroll_index >= max_scroll_index

        local up_bg = up_disabled and self.colors.slider_bg or lighten_color(self.colors.slider_bg, 15)
        local down_bg = down_disabled and self.colors.slider_bg or lighten_color(self.colors.slider_bg, 15)
        self.window:render_rect_filled(up_start, up_end, up_bg, 0)
        self.window:render_rect_filled(down_start, down_end, down_bg, 0)

        local up_label = "▲"
        local down_label = "▼"
        local up_sz = self.window:get_text_size(up_label)
        local down_sz = self.window:get_text_size(down_label)
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL,
            vec2.new(up_start.x + (control_w - up_sz.x) / 2, up_start.y + (option_h - up_sz.y) / 2),
            up_disabled and self.colors.text_disabled or self.colors.text_secondary,
            up_label)
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL,
            vec2.new(down_start.x + (control_w - down_sz.x) / 2, down_start.y + (option_h - down_sz.y) / 2),
            down_disabled and self.colors.text_disabled or self.colors.text_secondary,
            down_label)

        if (not up_disabled) and self.window:is_rect_clicked(up_start, up_end) then
            dd.scroll_index = math.max(1, scroll_index - 1)
        end
        if (not down_disabled) and self.window:is_rect_clicked(down_start, down_end) then
            dd.scroll_index = math.min(max_scroll_index, scroll_index + 1)
        end
    end

    -- Prevent underlying interactions while dropdown is open.
    self.window:block_input_capture()
end

