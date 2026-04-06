-- ext_lib_astro_ui/render_new.lua
-- New components (spacer, label, toggle_list, radio_group, progress_bar,
-- icon_button, list_box, spinner, skeleton, panel, card, hstack)

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

-- ============================================================================
-- SPACER
-- ============================================================================

function RotationSettingsUI:_render_spacer(group, y_offset)
    return y_offset + (group.height or LAYOUT.section_spacing)
end

-- ============================================================================
-- LABEL
-- ============================================================================

function RotationSettingsUI:_render_label(group, y_offset)
    local text = group.text or ""
    if type(text) ~= "string" or #text == 0 then
        return y_offset
    end

    y_offset = y_offset + LAYOUT.section_padding_top

    if not self:_is_y_visible(y_offset, y_offset + LAYOUT.element_height) then
        return y_offset + LAYOUT.element_height + LAYOUT.section_padding_bottom
    end

    local font = group.font_id or enums.window_enums.font_id.FONT_SMALL
    local col = group.color or self.colors.text_primary
    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()

    local sz = self.window:get_text_size(text)
    local tx = x_start
    if group.align == "center" then
        tx = x_start + (content_width - sz.x) / 2
    elseif group.align == "right" then
        tx = x_start + content_width - sz.x
    end

    self.window:render_text(font, vec2.new(tx, y_offset), col, text)

    return y_offset + LAYOUT.element_height + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- TOGGLE LIST
-- ============================================================================

function RotationSettingsUI:_render_toggle_list(section, y_offset)
    local elements = section and section.elements or {}
    if #elements == 0 then
        return y_offset
    end

    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local toggle_w = 36
    local toggle_h = 18
    local knob_size = 14
    local knob_pad = 2
    local line_h = math.max(LAYOUT.element_height, toggle_h + 6)

    for _, item in ipairs(elements) do
        if not self:_is_entry_visible(item) then
            goto continue_toggle
        end

        local element = item.element
        local label = item.label or ""

        if not self:_is_y_visible(y_offset, y_offset + line_h) then
            y_offset = y_offset + line_h + LAYOUT.element_spacing
            goto continue_toggle
        end

        local is_on = false
        if element then
            local ok, state = pcall(function() return element:get_state() end)
            if ok then is_on = state end
        end

        local ty = y_offset + (line_h - toggle_h) / 2
        local pill_start = vec2.new(x_start, ty)
        local pill_end = vec2.new(x_start + toggle_w, ty + toggle_h)

        local pill_col = is_on and self.colors.primary_accent or self.colors.slider_bg
        self.window:render_rect_filled(pill_start, pill_end, pill_col, toggle_h / 2)
        self.window:render_rect(pill_start, pill_end, self.colors.section_border, toggle_h / 2, 1.0)

        local knob_x = is_on and (x_start + toggle_w - knob_size - knob_pad) or (x_start + knob_pad)
        local knob_start = vec2.new(knob_x, ty + knob_pad)
        local knob_end = vec2.new(knob_x + knob_size, ty + knob_pad + knob_size)
        self.window:render_rect_filled(knob_start, knob_end, self.colors.text_primary, knob_size / 2)

        self.window:is_mouse_hovering_rect_block_movement(pill_start, pill_end)

        if self.window:is_rect_clicked(pill_start, pill_end) or is_mouse_clicked_left(self.window) and self.window:is_mouse_hovering_rect(pill_start, pill_end) then
            self.window:block_input_capture()
            if element then
                pcall(function()
                    if element.set then
                        element:set(not is_on)
                    elseif element.set_state then
                        element:set_state(not is_on)
                    end
                end)
            end
        end

        if #label > 0 then
            local label_x = x_start + toggle_w + 8
            local label_y = y_offset + (line_h - (self.window:get_text_size(label).y or 12)) / 2
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(label_x, label_y), self.colors.text_primary, label)
        end

        -- Context menu support (right-click)
        if item.context_menu and self.window:is_mouse_button_clicked(1) and self.window:is_mouse_hovering_rect(pill_start, pill_end) then
            self:show_context_menu(item.context_menu)
        end

        y_offset = y_offset + line_h + LAYOUT.element_spacing
        ::continue_toggle::
    end

    return y_offset + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- RADIO GROUP
-- ============================================================================

function RotationSettingsUI:_render_radio_group(section, y_offset)
    local element = section and section.element or nil
    local options = section and section.options or {}
    if #options == 0 then
        return y_offset
    end

    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local radio_r = 7
    local line_h = LAYOUT.element_height

    local current_index = 0
    if element then
        local ok, val = pcall(function() return element:get() end)
        if ok and val then current_index = val end
    end

    for idx, opt_label in ipairs(options) do
        if not self:_is_y_visible(y_offset, y_offset + line_h) then
            y_offset = y_offset + line_h + LAYOUT.element_spacing
            goto continue_radio
        end

        local cy = y_offset + line_h / 2
        local cx = x_start + radio_r + 2
        local center = vec2.new(cx, cy)
        local is_selected = (idx - 1) == current_index

        self.window:render_circle(center, radio_r, self.colors.section_border, 1.5)
        if is_selected then
            self.window:render_circle_filled(center, radio_r - 3, self.colors.primary_accent)
        end

        local label_str = tostring(opt_label or "")
        if #label_str > 0 then
            local label_x = cx + radio_r + 6
            local sz = self.window:get_text_size(label_str)
            local label_y = cy - (sz.y or 12) / 2
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(label_x, label_y), self.colors.text_primary, label_str)
        end

        local hit_start = vec2.new(x_start, y_offset)
        local hit_end = vec2.new(x_start + 200, y_offset + line_h)
        self.window:is_mouse_hovering_rect_block_movement(hit_start, hit_end)

        if self.window:is_rect_clicked(hit_start, hit_end) then
            self.window:block_input_capture()
            if element then
                pcall(function() element:set(idx - 1) end)
            end
        end

        y_offset = y_offset + line_h + LAYOUT.element_spacing
        ::continue_radio::
    end

    return y_offset + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- PROGRESS BAR
-- ============================================================================

function RotationSettingsUI:_render_progress_bar(section, y_offset)
    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local bar_h = LAYOUT.slider_bar_height
    local label = section.label or ""
    local suffix = section.suffix or "%"

    local value = 0
    if section.value_fn and type(section.value_fn) == "function" then
        local ok, v = pcall(section.value_fn)
        if ok and v then value = math.max(0, math.min(1, tonumber(v) or 0)) end
    end

    if not self:_is_y_visible(y_offset, y_offset + bar_h + LAYOUT.element_height) then
        return y_offset + bar_h + LAYOUT.element_height + LAYOUT.section_padding_bottom
    end

    if #label > 0 then
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start, y_offset), self.colors.text_secondary, label)
    end

    local display_val = tostring(math.floor(value * 100 + 0.5)) .. suffix
    local val_sz = self.window:get_text_size(display_val)
    self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start + content_width - val_sz.x, y_offset), self.colors.text_primary, display_val)

    y_offset = y_offset + LAYOUT.element_height

    local bar_start = vec2.new(x_start, y_offset)
    local bar_end = vec2.new(x_start + content_width, y_offset + bar_h)
    self.window:render_rect_filled(bar_start, bar_end, self.colors.slider_bg, 2.0)

    local fill_w = math.floor(content_width * value + 0.5)
    if fill_w > 0 then
        local fill_col = section.bar_color or self.colors.primary_accent
        self.window:render_rect_filled(bar_start, vec2.new(x_start + fill_w, y_offset + bar_h), fill_col, 2.0)
    end

    self.window:render_rect(bar_start, bar_end, self.colors.section_border, 2.0, 1.0)

    return y_offset + bar_h + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- ICON BUTTON
-- ============================================================================

function RotationSettingsUI:_render_icon_button(section, y_offset)
    local icon = section.icon or "?"
    local label = section.button_label or ""

    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local height = LAYOUT.slider_bar_height

    local icon_sz = self.window:get_text_size(icon)
    local label_sz = label ~= "" and self.window:get_text_size(label) or { x = 0, y = 0 }
    local total_text_w = icon_sz.x + (label ~= "" and (6 + label_sz.x) or 0)
    local width = section.width or math.min(math.max(total_text_w + 20, 40), content_width)

    local start = vec2.new(x_start, y_offset)
    local endp = vec2.new(x_start + width, y_offset + height)

    if not self:_is_y_visible(y_offset, y_offset + height + 6) then
        return y_offset + height + LAYOUT.section_padding_bottom
    end

    local hovered = self.window:is_mouse_hovering_rect(start, endp)
    self.window:is_mouse_hovering_rect_block_movement(start, endp)

    local bg = hovered and lighten_color(self.colors.slider_bg, 20) or self.colors.slider_bg
    self.window:render_rect_filled(start, endp, bg, 2.0)
    local border = hovered and self.colors.secondary_accent or self.colors.primary_accent
    self.window:render_rect(start, endp, border, 2.0, 1.0)

    local tx = start.x + (width - total_text_w) / 2
    local ty = start.y + (height - icon_sz.y) / 2
    self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(tx, ty), self.colors.primary_accent, icon)
    if label ~= "" then
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(tx + icon_sz.x + 6, ty), self.colors.text_primary, label)
    end

    if (hovered and is_mouse_clicked_left(self.window)) or self.window:is_rect_clicked(start, endp) then
        self.window:block_input_capture()
        if section.on_click and type(section.on_click) == "function" then
            pcall(section.on_click)
        end
    end

    return y_offset + height + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- LIST BOX
-- ============================================================================

function RotationSettingsUI:_render_list_box(section, y_offset)
    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local box_h = section.height or 120
    local item_h = LAYOUT.element_height
    local label = section.label or ""

    local items = {}
    if section.items_fn and type(section.items_fn) == "function" then
        local ok, res = pcall(section.items_fn)
        if ok and type(res) == "table" then items = res end
    end

    local selected = 0
    if section.element then
        local ok, val = pcall(function() return section.element:get() end)
        if ok and val then selected = val end
    end

    if #label > 0 and self:_is_y_visible(y_offset, y_offset + LAYOUT.element_height) then
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start, y_offset), self.colors.text_secondary, label)
    end
    if #label > 0 then
        y_offset = y_offset + LAYOUT.element_height
    end

    local box_start = vec2.new(x_start, y_offset)
    local box_end = vec2.new(x_start + content_width, y_offset + box_h)

    if not self:_is_y_visible(y_offset, y_offset + box_h) then
        return y_offset + box_h + LAYOUT.section_padding_bottom
    end

    self.window:render_rect_filled(box_start, box_end, self.colors.section_bg, 2.0)
    self.window:render_rect(box_start, box_end, self.colors.section_border, 2.0, 1.0)
    self.window:is_mouse_hovering_rect_block_movement(box_start, box_end)

    local scroll_key = "__listbox_" .. tostring(section.label or "lb") .. "_" .. tostring(section)
    local list_scroll = self._tab_scroll_offsets[scroll_key] or 0
    local total_h = #items * item_h
    local max_lb_scroll = math.max(0, total_h - box_h)
    list_scroll = math.max(0, math.min(max_lb_scroll, list_scroll))

    for idx, item_text in ipairs(items) do
        local iy = y_offset + (idx - 1) * item_h - list_scroll
        if iy + item_h < y_offset or iy > y_offset + box_h then
            goto continue_lb
        end

        local row_start = vec2.new(x_start + 2, math.max(iy, y_offset))
        local row_end = vec2.new(x_start + content_width - 2, math.min(iy + item_h, y_offset + box_h))

        if (idx - 1) == selected then
            self.window:render_rect_filled(row_start, row_end, self.colors.primary_accent, 1.0)
        end

        if iy >= y_offset and iy + item_h <= y_offset + box_h then
            local txt = tostring(item_text or "")
            local txt_y = iy + (item_h - (self.window:get_text_size(txt).y or 12)) / 2
            local txt_col = (idx - 1) == selected and self.colors.text_primary or self.colors.text_secondary
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start + 8, txt_y), txt_col, txt)
        end

        if self.window:is_rect_clicked(vec2.new(x_start, math.max(iy, y_offset)), vec2.new(x_start + content_width, math.min(iy + item_h, y_offset + box_h))) then
            self.window:block_input_capture()
            if section.element then
                pcall(function() section.element:set(idx - 1) end)
            end
        end

        ::continue_lb::
    end

    self._tab_scroll_offsets[scroll_key] = list_scroll

    return y_offset + box_h + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- SPINNER
-- ============================================================================

function RotationSettingsUI:_render_spinner(section, y_offset)
    if section.active_fn and type(section.active_fn) == "function" then
        local ok, active = pcall(section.active_fn)
        if not ok or not active then
            return y_offset
        end
    end

    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local bar_h = 6
    local label = section.label or ""

    if not self:_is_y_visible(y_offset, y_offset + LAYOUT.element_height + bar_h) then
        return y_offset + LAYOUT.element_height + bar_h + LAYOUT.section_padding_bottom
    end

    if #label > 0 then
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start, y_offset), self.colors.text_secondary, label)
        y_offset = y_offset + LAYOUT.element_height
    end

    local bar_start = vec2.new(x_start, y_offset)
    local bar_end = vec2.new(x_start + content_width, y_offset + bar_h)
    self.window:render_rect_filled(bar_start, bar_end, self.colors.slider_bg, 3.0)

    local now = 0
    pcall(function() now = core.game_time() end)
    local cycle = (now % 2000) / 2000
    local seg_w = content_width * 0.3
    local pos = cycle * (content_width + seg_w) - seg_w
    local seg_x1 = math.max(x_start, x_start + pos)
    local seg_x2 = math.min(x_start + content_width, x_start + pos + seg_w)

    if seg_x2 > seg_x1 then
        self.window:render_rect_filled(vec2.new(seg_x1, y_offset), vec2.new(seg_x2, y_offset + bar_h), self.colors.primary_accent, 3.0)
    end

    return y_offset + bar_h + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- SKELETON
-- ============================================================================

function RotationSettingsUI:_render_skeleton(section, y_offset)
    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local rows = section.rows or 3
    local row_h = section.row_height or LAYOUT.element_height
    local widths = { 1.0, 0.7, 0.9, 0.6, 0.85 }

    local now = 0
    pcall(function() now = core.game_time() end)
    local pulse = 0.4 + 0.3 * math.abs(math.sin((now or 0) / 800 * math.pi))

    for i = 1, rows do
        if self:_is_y_visible(y_offset, y_offset + row_h) then
            local w_factor = widths[((i - 1) % #widths) + 1]
            local w = math.floor(content_width * w_factor)
            local base = self.colors.slider_bg
            local br, bg, bb = base:get()
            local alpha = math.floor(255 * pulse)
            local skel_col = color.new(br or 60, bg or 60, bb or 70, alpha)
            self.window:render_rect_filled(vec2.new(x_start, y_offset), vec2.new(x_start + w, y_offset + row_h - 4), skel_col, 4.0)
        end

        y_offset = y_offset + row_h
    end

    return y_offset + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- PANEL
-- ============================================================================

function RotationSettingsUI:_render_panel(section, y_offset)
    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local pad = section.padding or 10
    local children = section.children or {}

    local bg_col = section.bg_color or self.colors.section_bg
    local border_col = section.border_color or self.colors.section_border

    -- Draw background FIRST using cached height from previous frame so children render on top
    local cache_key = "panel_" .. tostring(section)
    self._panel_height_cache = self._panel_height_cache or {}
    local cached_h = self._panel_height_cache[cache_key] or (pad * 2 + #children * LAYOUT.element_height)
    local panel_start = vec2.new(x_start, y_offset)
    local panel_end_est = vec2.new(x_start + content_width, y_offset + cached_h)

    if self:_is_y_visible(y_offset, y_offset + cached_h) then
        self.window:render_rect_filled(panel_start, panel_end_est, bg_col, 2.0)
        self.window:render_rect(panel_start, panel_end_est, border_col, 2.0, 1.0)
    end

    local saved_x = self._content_x_start
    local saved_left = self._side_menu_reserved_left
    self._content_x_start = x_start + pad
    self._side_menu_reserved_left = 0

    local inner_y = y_offset + pad
    if section.label and #section.label > 0 then
        if self:_is_y_visible(inner_y, inner_y + LAYOUT.element_height) then
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start + pad, inner_y), self.colors.primary_accent, section.label)
        end
        inner_y = inner_y + LAYOUT.element_height
    end

    for _, group in ipairs(children) do
        if self:_is_entry_visible(group) then
            if group.type == "checkbox_grid" then
                inner_y = self:_render_checkbox_grid(group, inner_y)
            elseif group.type == "slider_list" then
                inner_y = self:_render_slider_list(group, inner_y)
            elseif group.type == "combo_list" then
                inner_y = self:_render_combo_list(group, inner_y)
            elseif group.type == "text" then
                inner_y = self:_render_text_block(group, inner_y)
            elseif group.type == "separator" then
                inner_y = self:_render_separator(group, inner_y)
            elseif group.type == "button" then
                inner_y = self:_render_button(group, inner_y)
            elseif group.type == "spacer" then
                inner_y = self:_render_spacer(group, inner_y)
            elseif group.type == "label" then
                inner_y = self:_render_label(group, inner_y)
            elseif group.type == "toggle_list" then
                inner_y = self:_render_toggle_list(group, inner_y)
            elseif group.type == "radio_group" then
                inner_y = self:_render_radio_group(group, inner_y)
            elseif group.type == "progress_bar" then
                inner_y = self:_render_progress_bar(group, inner_y)
            elseif group.type == "icon_button" then
                inner_y = self:_render_icon_button(group, inner_y)
            elseif group.type == "range_slider_list" then
                inner_y = self:_render_range_slider_list(group, inner_y)
            elseif group.type == "data_table" then
                inner_y = self:_render_data_table(group, inner_y)
            elseif group.type == "context_trigger" then
                inner_y = self:_render_context_trigger(group, inner_y)
            elseif group.type == "list_box" then
                inner_y = self:_render_list_box(group, inner_y)
            elseif group.type == "spinner" then
                inner_y = self:_render_spinner(group, inner_y)
            elseif group.type == "skeleton" then
                inner_y = self:_render_skeleton(group, inner_y)
            elseif group.type == "panel" then
                inner_y = self:_render_panel(group, inner_y)
            elseif group.type == "card" then
                inner_y = self:_render_card(group, inner_y)
            elseif group.type == "hstack" then
                inner_y = self:_render_hstack(group, inner_y)
            end
        end
    end

    local panel_bottom = inner_y + pad

    self._content_x_start = saved_x
    self._side_menu_reserved_left = saved_left

    -- Cache actual height for next frame and re-draw border at correct dimensions
    self._panel_height_cache[cache_key] = panel_bottom - y_offset
    local panel_end = vec2.new(x_start + content_width, panel_bottom)
    if self:_is_y_visible(y_offset, panel_bottom) then
        self.window:render_rect(panel_start, panel_end, border_col, 2.0, 1.0)
    end

    return panel_bottom + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- CARD
-- ============================================================================

function RotationSettingsUI:_render_card(section, y_offset)
    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local pad = 12
    local children = section.children or {}
    local header_h = 0

    if section.label and #section.label > 0 then
        header_h = LAYOUT.element_height + 4
    end

    -- Use cached height from previous frame to draw background FIRST
    local cache_key = "card_" .. tostring(section) .. "_" .. tostring(section.label or "")
    local cached_h = self._panel_height_cache[cache_key] or (pad * 2 + header_h + #children * LAYOUT.element_height)
    local estimated_bottom = y_offset + cached_h

    local card_start = vec2.new(x_start, y_offset)
    local card_end_est = vec2.new(x_start + content_width, estimated_bottom)

    if self:_is_y_visible(y_offset, estimated_bottom) then
        local shadow_col = color.new(0, 0, 0, 40)
        self.window:render_rect_filled(vec2.new(x_start + 2, y_offset + 2), vec2.new(x_start + content_width + 2, estimated_bottom + 2), shadow_col, 6.0)
        self.window:render_rect_filled(card_start, card_end_est, self.colors.section_bg, 6.0)

        if section.label and #section.label > 0 then
            local header_bottom = y_offset + pad + header_h
            self.window:render_rect_filled(vec2.new(x_start, y_offset), vec2.new(x_start + content_width, header_bottom), lighten_color(self.colors.section_bg, 8), 6.0)
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start + pad, y_offset + pad), self.colors.primary_accent, section.label)
            self.window:render_line(vec2.new(x_start + pad, header_bottom), vec2.new(x_start + content_width - pad, header_bottom), self.colors.separator, 1.0)
        end
    end

    -- Now render children ON TOP of background
    local saved_x = self._content_x_start
    local saved_left = self._side_menu_reserved_left
    self._content_x_start = x_start + pad
    self._side_menu_reserved_left = 0

    local inner_y = y_offset + pad
    if header_h > 0 then
        inner_y = inner_y + header_h
    end

    for _, group in ipairs(children) do
        if self:_is_entry_visible(group) then
            if group.type == "checkbox_grid" then
                inner_y = self:_render_checkbox_grid(group, inner_y)
            elseif group.type == "slider_list" then
                inner_y = self:_render_slider_list(group, inner_y)
            elseif group.type == "combo_list" then
                inner_y = self:_render_combo_list(group, inner_y)
            elseif group.type == "text" then
                inner_y = self:_render_text_block(group, inner_y)
            elseif group.type == "separator" then
                inner_y = self:_render_separator(group, inner_y)
            elseif group.type == "button" then
                inner_y = self:_render_button(group, inner_y)
            elseif group.type == "spacer" then
                inner_y = self:_render_spacer(group, inner_y)
            elseif group.type == "label" then
                inner_y = self:_render_label(group, inner_y)
            elseif group.type == "toggle_list" then
                inner_y = self:_render_toggle_list(group, inner_y)
            elseif group.type == "radio_group" then
                inner_y = self:_render_radio_group(group, inner_y)
            elseif group.type == "progress_bar" then
                inner_y = self:_render_progress_bar(group, inner_y)
            elseif group.type == "icon_button" then
                inner_y = self:_render_icon_button(group, inner_y)
            elseif group.type == "range_slider_list" then
                inner_y = self:_render_range_slider_list(group, inner_y)
            elseif group.type == "data_table" then
                inner_y = self:_render_data_table(group, inner_y)
            elseif group.type == "context_trigger" then
                inner_y = self:_render_context_trigger(group, inner_y)
            elseif group.type == "list_box" then
                inner_y = self:_render_list_box(group, inner_y)
            elseif group.type == "spinner" then
                inner_y = self:_render_spinner(group, inner_y)
            elseif group.type == "skeleton" then
                inner_y = self:_render_skeleton(group, inner_y)
            elseif group.type == "panel" then
                inner_y = self:_render_panel(group, inner_y)
            elseif group.type == "card" then
                inner_y = self:_render_card(group, inner_y)
            elseif group.type == "hstack" then
                inner_y = self:_render_hstack(group, inner_y)
            end
        end
    end

    local card_bottom = inner_y + pad

    self._content_x_start = saved_x
    self._side_menu_reserved_left = saved_left

    -- Cache actual height for next frame and re-draw border at correct dimensions
    self._panel_height_cache[cache_key] = card_bottom - y_offset
    local card_end = vec2.new(x_start + content_width, card_bottom)
    if self:_is_y_visible(y_offset, card_bottom) then
        self.window:render_rect(card_start, card_end, self.colors.section_border, 6.0, 1.0)
    end

    return card_bottom + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- DATA TABLE
-- ============================================================================

function RotationSettingsUI:_render_data_table(section, y_offset)
    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local columns = section.columns or {}
    if #columns == 0 then
        return y_offset
    end

    local row_h = section.row_height or LAYOUT.element_height
    local header_h = row_h
    local table_id = section.id or tostring(section)

    -- Label above table
    if section.label and #section.label > 0 then
        if self:_is_y_visible(y_offset, y_offset + LAYOUT.element_height) then
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x_start, y_offset),
                self.colors.text_secondary, section.label)
        end
        y_offset = y_offset + LAYOUT.element_height
    end

    -- Get rows
    local rows = section.rows or {}
    if section.rows_fn and type(section.rows_fn) == "function" then
        local ok, res = pcall(section.rows_fn)
        if ok and type(res) == "table" then rows = res end
    end

    -- Calculate column widths
    local total_explicit = 0
    local implicit_count = 0
    for _, col in ipairs(columns) do
        if col.width then
            total_explicit = total_explicit + col.width
        else
            implicit_count = implicit_count + 1
        end
    end
    local implicit_width = implicit_count > 0 and math.floor((content_width - total_explicit) / implicit_count) or 0
    local col_widths = {}
    for ci, col in ipairs(columns) do
        col_widths[ci] = col.width or math.max(40, implicit_width)
    end

    -- Sorting
    local sort_state = self._table_sort_state[table_id]
    local sorted_rows = rows
    if sort_state and sort_state.column_key and #rows > 1 then
        sorted_rows = {}
        for ri, row in ipairs(rows) do
            sorted_rows[ri] = row
        end
        local key = sort_state.column_key
        local asc = sort_state.ascending
        table.sort(sorted_rows, function(a, b)
            local va = a[key]
            local vb = b[key]
            if va == nil and vb == nil then return false end
            if va == nil then return asc end
            if vb == nil then return not asc end
            if type(va) == "number" and type(vb) == "number" then
                return asc and va < vb or (not asc and va > vb)
            end
            local sa = tostring(va)
            local sb = tostring(vb)
            return asc and sa < sb or (not asc and sa > sb)
        end)
    end

    -- Selected row index
    local selected = -1
    if section.element then
        local ok, val = pcall(function() return section.element:get() end)
        if ok and val then selected = val end
    end

    -- Internal scrolling
    local total_rows_h = #sorted_rows * row_h
    local max_height = section.max_height
    local use_internal_scroll = max_height and total_rows_h > max_height
    local visible_h = max_height or total_rows_h
    local scroll_key = "__table_" .. table_id
    local table_scroll = 0
    if use_internal_scroll then
        table_scroll = self._tab_scroll_offsets[scroll_key] or 0
        local max_scroll = math.max(0, total_rows_h - visible_h)
        table_scroll = math.max(0, math.min(max_scroll, table_scroll))
        self._tab_scroll_offsets[scroll_key] = table_scroll
    end

    local table_top_y = y_offset

    -- Render header row
    if self:_is_y_visible(y_offset, y_offset + header_h) then
        local hx = x_start
        for ci, col in ipairs(columns) do
            local w = col_widths[ci]
            local hdr_start = vec2.new(hx, y_offset)
            local hdr_end = vec2.new(hx + w, y_offset + header_h)

            local hdr_bg = lighten_color(self.colors.section_bg, 15)
            self.window:render_rect_filled(hdr_start, hdr_end, hdr_bg, 0)
            self.window:render_rect(hdr_start, hdr_end, self.colors.section_border, 0, 1.0)

            local col_label = col.label or col.key or ""
            local is_sortable = section.sortable or col.sortable
            local sort_indicator = ""
            if is_sortable and sort_state and sort_state.column_key == col.key then
                sort_indicator = sort_state.ascending and " ^" or " v"
            end
            local display_text = col_label .. sort_indicator
            local txt_sz = self.window:get_text_size(display_text)
            local txt_x = hx + 8
            local txt_y = y_offset + (header_h - txt_sz.y) / 2
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(txt_x, txt_y),
                self.colors.primary_accent, display_text)

            -- Sort click
            if is_sortable then
                self.window:is_mouse_hovering_rect_block_movement(hdr_start, hdr_end)
                if self.window:is_rect_clicked(hdr_start, hdr_end) then
                    self.window:block_input_capture()
                    if sort_state and sort_state.column_key == col.key then
                        self._table_sort_state[table_id] = { column_key = col.key, ascending = not sort_state.ascending }
                    else
                        self._table_sort_state[table_id] = { column_key = col.key, ascending = true }
                    end
                end
            end

            hx = hx + w
        end
    end
    y_offset = y_offset + header_h

    -- Render data rows
    local rows_area_top = y_offset
    for ri, row in ipairs(sorted_rows) do
        local ry = rows_area_top + (ri - 1) * row_h - table_scroll

        if use_internal_scroll then
            if ry + row_h < rows_area_top or ry > rows_area_top + visible_h then
                goto continue_table_row
            end
        end

        if not self:_is_y_visible(ry, ry + row_h) then
            goto continue_table_row
        end

        local row_start = vec2.new(x_start, math.max(ry, rows_area_top))
        local row_end_vec = vec2.new(x_start + content_width, math.min(ry + row_h, rows_area_top + visible_h))

        -- Background: stripe + selection + hover
        local is_selected = (ri - 1) == selected
        local row_hovered = self.window:is_mouse_hovering_rect(row_start, row_end_vec)
        self.window:is_mouse_hovering_rect_block_movement(row_start, row_end_vec)

        local row_bg = self.colors.section_bg
        if is_selected then
            row_bg = self.colors.primary_accent
        elseif section.stripe and ri % 2 == 0 then
            row_bg = lighten_color(self.colors.section_bg, 8)
        end
        if row_hovered and not is_selected then
            row_bg = lighten_color(row_bg, 12)
        end
        self.window:render_rect_filled(row_start, row_end_vec, row_bg, 0)

        -- Render cells
        if ry >= rows_area_top and ry + row_h <= rows_area_top + visible_h then
            local cx = x_start
            for ci, col in ipairs(columns) do
                local w = col_widths[ci]
                local cell_val = row[col.key]
                local cell_text = cell_val ~= nil and tostring(cell_val) or ""
                local txt_sz = self.window:get_text_size(cell_text)
                local txt_x = cx + 8
                local txt_y = ry + (row_h - txt_sz.y) / 2
                local txt_col = is_selected and (self.colors.tab_text_active or color.white(255)) or self.colors.text_secondary
                self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(txt_x, txt_y), txt_col, cell_text)
                cx = cx + w
            end
        end

        -- Row click
        if self.window:is_rect_clicked(row_start, row_end_vec) then
            self.window:block_input_capture()
            if section.element then
                pcall(function() section.element:set(ri - 1) end)
            end
            if section.on_row_click and type(section.on_row_click) == "function" then
                pcall(section.on_row_click, row, ri)
            end
        end

        ::continue_table_row::
    end

    -- Table border
    local table_bottom = rows_area_top + math.min(total_rows_h, visible_h)
    if self:_is_y_visible(table_top_y, table_bottom) then
        self.window:render_rect(vec2.new(x_start, table_top_y), vec2.new(x_start + content_width, table_bottom),
            self.colors.section_border, 0, 1.0)
    end

    -- Internal scroll via mouse wheel when hovered
    if use_internal_scroll then
        local table_area_start = vec2.new(x_start, rows_area_top)
        local table_area_end = vec2.new(x_start + content_width, rows_area_top + visible_h)
        if self.window:is_mouse_hovering_rect(table_area_start, table_area_end) then
            local wheel = helpers.get_wheel_delta(self.window)
            if wheel ~= 0 then
                local max_scroll = math.max(0, total_rows_h - visible_h)
                table_scroll = math.max(0, math.min(max_scroll, table_scroll + wheel))
                self._tab_scroll_offsets[scroll_key] = table_scroll
            end
        end
    end

    return rows_area_top + math.min(total_rows_h, visible_h) + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- CONTEXT TRIGGER
-- ============================================================================

function RotationSettingsUI:_render_context_trigger(section, y_offset)
    y_offset = y_offset + LAYOUT.section_padding_top

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local label = section.label or "Right-click"
    local width = section.width or math.min(200, content_width)
    local height = section.height or LAYOUT.slider_bar_height

    local trigger_start = vec2.new(x_start, y_offset)
    local trigger_end = vec2.new(x_start + width, y_offset + height)

    if not self:_is_y_visible(y_offset, y_offset + height + 6) then
        return y_offset + height + LAYOUT.section_padding_bottom
    end

    local hovered = self.window:is_mouse_hovering_rect(trigger_start, trigger_end)
    self.window:is_mouse_hovering_rect_block_movement(trigger_start, trigger_end)

    local bg = hovered and lighten_color(self.colors.slider_bg, 20) or self.colors.slider_bg
    self.window:render_rect_filled(trigger_start, trigger_end, bg, 2.0)
    local border = hovered and self.colors.secondary_accent or self.colors.section_border
    self.window:render_rect(trigger_start, trigger_end, border, 2.0, 1.0)

    local sz = self.window:get_text_size(label)
    local tx = trigger_start.x + (width - sz.x) / 2
    local ty = trigger_start.y + (height - sz.y) / 2
    self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(tx, ty), self.colors.text_secondary, label)

    -- Right-click to open context menu
    if hovered and self.window:is_mouse_button_clicked(1) then
        self:show_context_menu(section.items)
    end

    return y_offset + height + LAYOUT.section_padding_bottom
end

-- ============================================================================
-- CONTEXT MENU OVERLAY
-- ============================================================================

function RotationSettingsUI:_render_context_menu_overlay()
    local cm = self._context_menu
    if not cm or not self.window then
        return
    end

    local items = cm.items or {}
    if #items == 0 then
        self._context_menu = nil
        return
    end

    -- Calculate menu dimensions
    local item_h = LAYOUT.element_height
    local separator_h = 8
    local padding = 6
    local min_width = 140

    local max_text_w = 0
    local total_h = padding * 2
    for _, item in ipairs(items) do
        if item.separator then
            total_h = total_h + separator_h
        else
            local label = item.label or ""
            local sz = self.window:get_text_size(label)
            if sz.x > max_text_w then max_text_w = sz.x end
            total_h = total_h + item_h
        end
    end
    local menu_width = math.max(min_width, max_text_w + 32)

    -- Position and clamp to window bounds
    local menu_x = cm.x or 0
    local menu_y = cm.y or 0
    local win_size = self.window:get_size()

    if menu_x + menu_width > win_size.x - LAYOUT.padding_side then
        menu_x = win_size.x - LAYOUT.padding_side - menu_width
    end
    if menu_x < LAYOUT.padding_side then
        menu_x = LAYOUT.padding_side
    end
    if menu_y + total_h > win_size.y - LAYOUT.padding_bottom then
        menu_y = win_size.y - LAYOUT.padding_bottom - total_h
    end
    if menu_y < 0 then
        menu_y = 0
    end

    local menu_start = vec2.new(menu_x, menu_y)
    local menu_end = vec2.new(menu_x + menu_width, menu_y + total_h)

    -- Background
    self.window:render_rect_filled(menu_start, menu_end, self.colors.section_bg, 3.0)
    self.window:render_rect(menu_start, menu_end, self.colors.section_border, 3.0, 1.0)

    -- Hover/click on menu area
    local menu_hovered = self.window:is_mouse_hovering_rect(menu_start, menu_end)
    self.window:is_mouse_hovering_rect_block_movement(menu_start, menu_end)

    -- Close on click outside
    if is_mouse_clicked_left(self.window) and not menu_hovered then
        self._context_menu = nil
        return
    end

    -- Render items
    local iy = menu_y + padding
    for _, item in ipairs(items) do
        if item.separator then
            local sep_y = iy + separator_h / 2
            self.window:render_line(
                vec2.new(menu_x + 8, sep_y),
                vec2.new(menu_x + menu_width - 8, sep_y),
                self.colors.separator, 1.0)
            iy = iy + separator_h
        else
            local item_start = vec2.new(menu_x + 2, iy)
            local item_end_vec = vec2.new(menu_x + menu_width - 2, iy + item_h)

            local item_hovered = self.window:is_mouse_hovering_rect(item_start, item_end_vec)

            if item_hovered and not item.disabled then
                self.window:render_rect_filled(item_start, item_end_vec, lighten_color(self.colors.section_bg, 25), 2.0)
            end

            local label = item.label or ""
            local txt_col = item.disabled and self.colors.text_disabled or self.colors.text_primary
            local txt_sz = self.window:get_text_size(label)
            local txt_y = iy + (item_h - txt_sz.y) / 2
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL,
                vec2.new(menu_x + 12, txt_y), txt_col, label)

            if item_hovered and not item.disabled and is_mouse_clicked_left(self.window) then
                self.window:block_input_capture()
                if item.on_click and type(item.on_click) == "function" then
                    pcall(item.on_click)
                end
                self._context_menu = nil
                return
            end

            iy = iy + item_h
        end
    end

    -- Block all other input while menu is open
    self.window:block_input_capture()
end

-- ============================================================================
-- HSTACK
-- ============================================================================

function RotationSettingsUI:_render_hstack(section, y_offset)
    y_offset = y_offset + LAYOUT.section_padding_top

    local children = section.children or {}
    if #children == 0 then
        return y_offset
    end

    local x_start = self:_get_content_x_start()
    local content_width = self:_get_content_width()
    local spacing = section.spacing or LAYOUT.column_spacing
    local n = #children
    local child_w = math.floor((content_width - (n - 1) * spacing) / n)
    local max_h = 0

    local saved_x = self._content_x_start
    local saved_left = self._side_menu_reserved_left

    for idx, group in ipairs(children) do
        if self:_is_entry_visible(group) then
            local cx = x_start + (idx - 1) * (child_w + spacing)
            self._content_x_start = cx
            self._side_menu_reserved_left = 0

            local child_end = y_offset
            if group.type == "button" then
                child_end = self:_render_button(group, y_offset)
            elseif group.type == "icon_button" then
                child_end = self:_render_icon_button(group, y_offset)
            elseif group.type == "text" then
                child_end = self:_render_text_block(group, y_offset)
            elseif group.type == "label" then
                child_end = self:_render_label(group, y_offset)
            elseif group.type == "spacer" then
                child_end = self:_render_spacer(group, y_offset)
            elseif group.type == "progress_bar" then
                child_end = self:_render_progress_bar(group, y_offset)
            elseif group.type == "checkbox_grid" then
                child_end = self:_render_checkbox_grid(group, y_offset)
            elseif group.type == "slider_list" then
                child_end = self:_render_slider_list(group, y_offset)
            elseif group.type == "range_slider_list" then
                child_end = self:_render_range_slider_list(group, y_offset)
            elseif group.type == "data_table" then
                child_end = self:_render_data_table(group, y_offset)
            elseif group.type == "context_trigger" then
                child_end = self:_render_context_trigger(group, y_offset)
            elseif group.type == "combo_list" then
                child_end = self:_render_combo_list(group, y_offset)
            elseif group.type == "toggle_list" then
                child_end = self:_render_toggle_list(group, y_offset)
            elseif group.type == "radio_group" then
                child_end = self:_render_radio_group(group, y_offset)
            elseif group.type == "separator" then
                child_end = self:_render_separator(group, y_offset)
            end

            local h = child_end - y_offset
            if h > max_h then max_h = h end
        end
    end

    self._content_x_start = saved_x
    self._side_menu_reserved_left = saved_left

    return y_offset + max_h
end
