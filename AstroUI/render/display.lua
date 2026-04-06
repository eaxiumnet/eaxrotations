-- ext_lib_astro_ui/render_display.lua
-- Display widget renderers: runtime checkbox, text input, text block, separator, button

local constants = require("AstroUI/core/constants")
local helpers = require("AstroUI/core/helpers")
local RotationSettingsUI = require("AstroUI/core/class")

---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")
---@type enums
local enums = require("common/enums")

local LAYOUT = constants.LAYOUT
local lighten_color = helpers.lighten_color
local is_mouse_clicked_left = helpers.is_mouse_clicked_left

function RotationSettingsUI:_render_runtime_checkbox_list(section, y_offset)
    local elements = section and section.elements or nil
    if type(elements) == "function" then
        local ok, res = pcall(elements)
        elements = ok and res or nil
    end

    if not elements or type(elements) ~= "table" or #elements == 0 then
        return y_offset
    end

    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local checkbox_size = LAYOUT.checkbox_size
    local line_h = math.max(LAYOUT.element_height, checkbox_size + 6)

    for idx, entry in ipairs(elements) do
        if entry and self:_is_entry_visible(entry) then
            local label = entry.label or ("Option " .. idx)

            local row_top = y_offset
            local row_bottom = y_offset + line_h
            if self:_is_y_visible(row_top, row_bottom) then
                local box_start = vec2.new(x_start, y_offset + (line_h - checkbox_size) / 2)
                local box_end = vec2.new(x_start + checkbox_size, box_start.y + checkbox_size)

                local hovered = self.window:is_mouse_hovering_rect(box_start, vec2.new(x_start + content_width, row_bottom))
                self.window:is_mouse_hovering_rect_block_movement(box_start, vec2.new(x_start + content_width, row_bottom))

                local ok_get, is_checked = pcall(function()
                    if entry.get_state then
                        return entry.get_state() == true
                    end
                    return false
                end)
                if not ok_get then
                    is_checked = false
                end

                local bg = hovered and lighten_color(self.colors.slider_bg, 20) or self.colors.slider_bg
                self.window:render_rect_filled(box_start, box_end, bg, 2.0)
                local border = hovered and self.colors.secondary_accent or self.colors.checkbox_border
                self.window:render_rect(box_start, box_end, border, 2.0, 1.0)

                if is_checked then
                    local pad = 3
                    self.window:render_rect_filled(vec2.new(box_start.x + pad, box_start.y + pad),
                        vec2.new(box_end.x - pad, box_end.y - pad), self.colors.primary_accent, 1.5)
                end

                local text_x = box_end.x + 10
                local text_y = y_offset + (line_h - self.window:get_text_size(label).y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(text_x, text_y),
                    self.colors.text_primary, label)

                if hovered and is_mouse_clicked_left(self.window) then
                    self.window:block_input_capture()
                    if entry.set_state then
                        pcall(entry.set_state, not is_checked)
                    end
                end
            end

            y_offset = y_offset + line_h + LAYOUT.element_spacing
        end
    end

    return y_offset + LAYOUT.section_padding_bottom
end

function RotationSettingsUI:_render_text_input_list(section, y_offset)
    if not section.elements or #section.elements == 0 then
        return y_offset
    end

    local content_width = self:_get_content_width()
    local x_start = self:_get_content_x_start()

    y_offset = y_offset + LAYOUT.section_padding_top

    local label_width = 180
    local value_box_width = math.min(220, math.max(140, content_width - label_width))

    for i, item in ipairs(section.elements) do
        if item and item.element and self:_is_entry_visible(item) then
            local element = item.element
            local label = item.label or ("Input " .. i)
            local tooltip = item.tooltip or ""

            local row_top = y_offset
            local row_bottom = y_offset + LAYOUT.slider_bar_height + 6

            if self:_is_y_visible(row_top, row_bottom) then
                local label_y = y_offset + (LAYOUT.slider_bar_height - self.window:get_text_size(label).y) / 2
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start, label_y),
                    self.colors.text_primary, label)

                local input_offset = vec2.new(x_start + label_width, y_offset - 2)
                local ok_prev, prev_offset = pcall(function()
                    return self.window:get_current_context_dynamic_drawing_offset()
                end)

                local ok_set = pcall(function()
                    self.window:set_current_context_dynamic_drawing_offset(input_offset)
                end)

                if ok_set then
                    pcall(function()
                        if element.render_custom then
                            element:render_custom("##" .. tostring(label), tooltip, self.colors.slider_bg, self.colors.primary_accent,
                                self.colors.secondary_accent, self.colors.text_primary, value_box_width, 0)
                        elseif element.render then
                            element:render("##" .. tostring(label), tooltip)
                        end
                    end)
                end

                if ok_prev and prev_offset then
                    pcall(function()
                        self.window:set_current_context_dynamic_drawing_offset(prev_offset)
                    end)
                end
            end

            y_offset = y_offset + LAYOUT.slider_bar_height + LAYOUT.element_spacing + 4
        end
    end

    return y_offset + LAYOUT.section_padding_bottom
end

function RotationSettingsUI:_render_text_block(section, y_offset)
    local text = section and section.text or ""
    if type(text) == "function" then
        local ok, res = pcall(text)
        text = ok and res or ""
    end
    if type(text) ~= "string" or #text == 0 then
        return y_offset
    end

    local font_id = section.font_id or enums.window_enums.font_id.FONT_SMALL
    local col = section.color or self.colors.text_secondary

    y_offset = y_offset + LAYOUT.section_padding_top

    local x = self:_get_content_x_start()
    local line_h = self.window:get_text_size("Ag").y + 4

    for line in string.gmatch(text, "([^\n]*)\n?") do
        if line == nil then
            break
        end
        if self:_is_y_visible(y_offset, y_offset + line_h) then
            self.window:render_text(font_id, vec2.new(x, y_offset), col, line)
        end
        y_offset = y_offset + line_h
        if line == "" and y_offset > (self._max_y or 1e9) then
            break
        end
    end

    return y_offset + LAYOUT.section_padding_bottom
end

function RotationSettingsUI:_render_separator(section, y_offset)
    local height = tonumber(section and section.height) or 10
    local thickness = tonumber(section and section.thickness) or 1.0
    local col = (section and section.color) or self.colors.checkbox_border or self.colors.slider_bg

    local x = self:_get_content_x_start()
    local w = self:_get_content_width()
    local y = y_offset + math.floor(height / 2)

    if self:_is_y_visible(y_offset, y_offset + height) then
        self.window:render_rect_filled(vec2.new(x, y), vec2.new(x + w, y + thickness), col, 1.0)
    end

    return y_offset + height
end

function RotationSettingsUI:_render_button(section, y_offset)
    local label = section and section.button_label or ""
    if type(label) ~= "string" or #label == 0 then
        return y_offset
    end

    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local width = math.min(260, content_width)
    local height = LAYOUT.slider_bar_height

    local start = vec2.new(x_start, y_offset)
    local endp = vec2.new(x_start + width, y_offset + height)

    if self:_is_y_visible(y_offset, y_offset + height + 6) then
        local hovered = false
        do
            local mouse_pos = select(1, self:_get_window_local_mouse_pos("adjusted"))
            if mouse_pos then
                hovered = mouse_pos.x >= start.x and mouse_pos.x <= endp.x and mouse_pos.y >= start.y and mouse_pos.y <= endp.y
            else
                hovered = self.window:is_mouse_hovering_rect(start, endp)
            end
        end

        self.window:is_mouse_hovering_rect_block_movement(start, endp)

        local bg = hovered and lighten_color(self.colors.slider_bg, 20) or self.colors.slider_bg
        self.window:render_rect_filled(start, endp, bg, 2.0)
        local border = hovered and self.colors.secondary_accent or self.colors.primary_accent
        self.window:render_rect(start, endp, border, 2.0, 1.0)

        local sz = self.window:get_text_size(label)
        local tx = start.x + (width - sz.x) / 2
        local ty = start.y + (height - sz.y) / 2
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(tx, ty), self.colors.text_primary, label)

        local clicked = false
        if hovered and is_mouse_clicked_left(self.window) then
            clicked = true
        elseif self.window:is_rect_clicked(start, endp) then
            clicked = true
        end

        if clicked then
            self.window:block_input_capture()
            if section.on_click and type(section.on_click) == "function" then
                pcall(section.on_click)
            end
        end
    end

    return y_offset + height + LAYOUT.section_padding_bottom
end

return RotationSettingsUI
