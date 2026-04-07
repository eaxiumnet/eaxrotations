-- ext_lib_astro_ui/render_color.lua
-- Color widgets (color picker with RGBA channel sliders)

local constants = require("ext_lib_astro_ui/core/constants")
local helpers = require("ext_lib_astro_ui/core/helpers")
local RotationSettingsUI = require("ext_lib_astro_ui/core/class")

---@type color
local color = require("api/common/color")
---@type vec2
local vec2 = require("api/common/geometry/vector_2")
---@type enums
local enums = require("api/common/enums")

local LAYOUT = constants.LAYOUT
local lighten_color = helpers.lighten_color
local clamp_255 = helpers.clamp_255

-- ============================================================================
-- COLOR HELPERS
-- ============================================================================

function RotationSettingsUI:_get_color_rgba(element)
    local ok_col, current = pcall(function()
        return element:get()
    end)
    if not ok_col or not current then
        return nil, nil, nil, nil, nil
    end

    local ok_rgba, r, g, b, a = pcall(function()
        if current.get then
            return current:get()
        end
        return nil
    end)

    if ok_rgba and r ~= nil then
        return clamp_255(r), clamp_255(g), clamp_255(b), clamp_255(a), current
    end

    return nil, nil, nil, nil, current
end

function RotationSettingsUI:_set_color_rgba(element, r, g, b, a)
    if not element then
        return
    end
    if not element.set then
        return
    end
    pcall(function()
        element:set(color.new(clamp_255(r), clamp_255(g), clamp_255(b), clamp_255(a)))
    end)
end

function RotationSettingsUI:_make_color_channel_adapter(element, channel)
    local ui = self
    local adapter = {}

    function adapter:get_min()
        return 0
    end

    function adapter:get_max()
        return 255
    end

    function adapter:get()
        local r, g, b, a = ui:_get_color_rgba(element)
        if channel == "r" then
            return r or 0
        elseif channel == "g" then
            return g or 0
        elseif channel == "b" then
            return b or 0
        elseif channel == "a" then
            return a or 255
        end
        return 0
    end

    function adapter:set(value)
        local r, g, b, a = ui:_get_color_rgba(element)
        r = r or 0
        g = g or 0
        b = b or 0
        a = a or 255

        local v = clamp_255(value)
        if channel == "r" then
            r = v
        elseif channel == "g" then
            g = v
        elseif channel == "b" then
            b = v
        elseif channel == "a" then
            a = v
        end

        ui:_set_color_rgba(element, r, g, b, a)
    end

    return adapter
end

-- ============================================================================
-- COLOR LIST RENDERING
-- ============================================================================

function RotationSettingsUI:_render_color_list(section, y_offset)
    if not section.elements or #section.elements == 0 then
        return y_offset
    end

    local content_width = self:_get_content_width()
    local x_start = self:_get_content_x_start()

    y_offset = y_offset + LAYOUT.section_padding_top

    local label_width = 180
    local value_box_width = math.min(160, content_width - label_width)

    for i, item in ipairs(section.elements) do
        if item and item.element and self:_is_entry_visible(item) then
            local element = item.element
            local label = item.label or ("Color " .. i)

            local _, _, _, _, current_color = self:_get_color_rgba(element)
            if not current_color then
                current_color = color.white(255)
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

                local swatch_pad = 3
                local swatch_start = vec2.new(box_start.x + swatch_pad, box_start.y + swatch_pad)
                local swatch_end = vec2.new(box_end.x - swatch_pad, box_end.y - swatch_pad)
                self.window:render_rect_filled(swatch_start, swatch_end, current_color, 1.5)

                if self.window:is_rect_clicked(box_start, box_end) then
                    if self._active_color_editor and self._active_color_editor.element == element then
                        self._active_color_editor = nil
                    else
                        self._active_color_editor = { element = element, label = label }
                    end
                end
            end

            y_offset = y_offset + LAYOUT.slider_bar_height + LAYOUT.element_spacing + 4

            if self._active_color_editor and self._active_color_editor.element == element then
                local r_adapter = self:_make_color_channel_adapter(element, "r")
                local g_adapter = self:_make_color_channel_adapter(element, "g")
                local b_adapter = self:_make_color_channel_adapter(element, "b")
                local a_adapter = self:_make_color_channel_adapter(element, "a")

                y_offset = self:_render_slider_list({
                    elements = {
                        { element = r_adapter, label = "Red", min = 0, max = 255 },
                        { element = g_adapter, label = "Green", min = 0, max = 255 },
                        { element = b_adapter, label = "Blue", min = 0, max = 255 },
                        { element = a_adapter, label = "Alpha", min = 0, max = 255 }
                    }
                }, y_offset)
            end
        end
    end

    return y_offset + LAYOUT.section_padding_bottom
end

