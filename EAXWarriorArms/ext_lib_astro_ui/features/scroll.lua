-- ext_lib_astro_ui/scroll.lua
-- Scroll management, side menu, and content layout helpers

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
local is_mouse_pressed_left = helpers.is_mouse_pressed_left
local get_wheel_delta = helpers.get_wheel_delta

-- ============================================================================
-- ENTRY VISIBILITY
-- ============================================================================

function RotationSettingsUI:_is_entry_visible(entry)
    if not entry or not entry.visible_when then
        return true
    end
    local ok, result = pcall(entry.visible_when)
    if not ok then
        return false
    end
    return result == true
end

-- ============================================================================
-- ACTIVE TAB / PAGE HELPERS
-- ============================================================================

function RotationSettingsUI:_get_active_tab_id()
    if self.active_tab_index < 1 or self.active_tab_index > #self.sections then
        return nil
    end
    local section = self.sections[self.active_tab_index]
    return section and section.id or nil
end

function RotationSettingsUI:_get_active_page_id(tab_id)
    if not tab_id then
        return nil
    end
    return self._side_menu_active_pages[tab_id]
end

function RotationSettingsUI:_set_active_page_id(tab_id, page_id)
    if not tab_id then
        return
    end
    self._side_menu_active_pages[tab_id] = page_id
end

function RotationSettingsUI:_get_active_scroll_key()
    local tab_id = self:_get_active_tab_id()
    if not tab_id then
        return nil
    end
    local section = self.sections[self.active_tab_index]
    local page_id = nil
    if section and section.side_menu then
        page_id = self:_get_active_page_id(tab_id)
        if page_id and #tostring(page_id) > 0 then
            return tab_id .. "::" .. tostring(page_id)
        end
    end
    return tab_id
end

-- ============================================================================
-- SCROLL OFFSETS
-- ============================================================================

function RotationSettingsUI:_get_tab_scroll_offset(tab_id)
    if not tab_id then
        return 0
    end
    return self._tab_scroll_offsets[tab_id] or 0
end

function RotationSettingsUI:_set_tab_scroll_offset(tab_id, value, max_value)
    if not tab_id then
        return
    end

    local clamped = math.max(0, value or 0)
    if max_value ~= nil then
        clamped = math.min(max_value, clamped)
    end

    self._tab_scroll_offsets[tab_id] = clamped
end

function RotationSettingsUI:_is_y_visible(y_top, y_bottom)
    local vp = self._scroll_viewport
    if not vp then
        return true
    end
    return y_bottom >= vp.top and y_top <= vp.bottom
end

-- ============================================================================
-- SCROLLBAR RENDERING
-- ============================================================================

function RotationSettingsUI:_render_scrollbar(tab_id, content_height, viewport_top, viewport_bottom)
    if not self.window or not tab_id then
        return
    end

    local viewport_height = viewport_bottom - viewport_top
    if viewport_height <= 0 then
        return
    end

    local max_scroll = math.max(0, (content_height or 0) - viewport_height)
    if max_scroll <= 0 then
        self._scrollbar_drag = nil
        self._scrollbar_reserved_right = 0
        self:_set_tab_scroll_offset(tab_id, 0)
        return
    end

    local window_size = self.window:get_size()
    local scrollbar_width = 10
    self._scrollbar_reserved_right = scrollbar_width + 6
    local x2 = window_size.x - LAYOUT.padding_side
    local x1 = x2 - scrollbar_width

    local track_start = vec2.new(x1, viewport_top)
    local track_end = vec2.new(x2, viewport_bottom)
    self.window:render_rect_filled(track_start, track_end, self.colors.slider_bg, 2.0)
    self.window:render_rect(track_start, track_end, self.colors.section_border, 2.0, 1.0)

    local handle_height = math.max(24, math.floor((viewport_height * viewport_height) / (content_height) + 0.5))
    handle_height = math.min(handle_height, viewport_height)

    local scroll = self:_get_tab_scroll_offset(tab_id)
    scroll = math.max(0, math.min(max_scroll, scroll))
    self:_set_tab_scroll_offset(tab_id, scroll, max_scroll)

    local handle_travel = viewport_height - handle_height
    local handle_y = viewport_top + (scroll / max_scroll) * handle_travel
    local handle_start = vec2.new(x1, handle_y)
    local handle_end = vec2.new(x2, handle_y + handle_height)

    local hovered = self.window:is_mouse_hovering_rect(handle_start, handle_end)
    self.window:is_mouse_hovering_rect_block_movement(track_start, track_end)

    local handle_col = hovered and lighten_color(self.colors.primary_accent, 10) or self.colors.primary_accent
    self.window:render_rect_filled(handle_start, handle_end, handle_col, 2.0)

    local mouse_pos = select(1, self:_get_window_local_mouse_pos())

    if not self._scrollbar_drag then
        if self.window:is_rect_clicked(handle_start, handle_end) and mouse_pos then
            self.window:block_input_capture()
            self._scrollbar_drag = {
                tab_id = tab_id,
                mouse_y = mouse_pos.y,
                scroll = scroll
            }
        elseif self.window:is_rect_clicked(track_start, track_end) and mouse_pos then
            self.window:block_input_capture()
            local click_y = mouse_pos.y
            local target = click_y - viewport_top - (handle_height / 2)
            local ratio = 0
            if handle_travel > 0 then
                ratio = math.max(0, math.min(1, target / handle_travel))
            end
            self:_set_tab_scroll_offset(tab_id, ratio * max_scroll, max_scroll)
        end
    end

    if self._scrollbar_drag and self._scrollbar_drag.tab_id == tab_id then
        if is_mouse_pressed_left(self.window) and mouse_pos then
            self.window:block_input_capture()
            local target = mouse_pos.y - viewport_top - (handle_height / 2)
            local ratio = 0
            if handle_travel > 0 then
                ratio = math.max(0, math.min(1, target / handle_travel))
            end
            self:_set_tab_scroll_offset(tab_id, ratio * max_scroll, max_scroll)
        else
            self._scrollbar_drag = nil
        end
    end
end

-- ============================================================================
-- SCROLL INPUT HANDLING (Mouse wheel + keyboard)
-- ============================================================================

function RotationSettingsUI:_handle_scroll_input(scroll_key, max_scroll, viewport_height)
    if not self.window or not scroll_key then return end

    local hovered = false
    pcall(function() hovered = self.window:is_window_hovered() end)
    if not hovered then return end

    if self._active_slider or self._active_key_capture or self._active_combo_dropdown then
        return
    end

    local scroll = self:_get_tab_scroll_offset(scroll_key)
    local step = LAYOUT.scroll_wheel_step
    local page = math.max(step, math.floor(viewport_height * LAYOUT.scroll_page_factor))
    local changed = false

    local wheel = get_wheel_delta(self.window)
    if wheel ~= 0 then
        scroll = scroll + wheel
        changed = true
    end

    if core.input.is_key_pressed(0x26) then scroll = scroll - step;      changed = true end
    if core.input.is_key_pressed(0x28) then scroll = scroll + step;      changed = true end
    if core.input.is_key_pressed(0x21) then scroll = scroll - page;      changed = true end
    if core.input.is_key_pressed(0x22) then scroll = scroll + page;      changed = true end
    if core.input.is_key_pressed(0x24) then scroll = 0;                  changed = true end
    if core.input.is_key_pressed(0x23) then scroll = max_scroll;         changed = true end

    if changed then
        self:_set_tab_scroll_offset(scroll_key, scroll, max_scroll)
    end
end

-- ============================================================================
-- SIDE MENU RENDERING
-- ============================================================================

function RotationSettingsUI:_render_side_menu(section, viewport_top, viewport_bottom)
    if not self.window or not section or not section.side_menu then
        return 0
    end

    local items = section.side_menu.items
    if not items or #items == 0 then
        return 0
    end

    local width = section.side_menu.width or LAYOUT.side_menu_width
    if width <= 0 then
        return 0
    end

    local tab_id = section.id
    local visible_items = {}
    for _, item in ipairs(items) do
        if item then
            local show = true
            if item.visible_when and type(item.visible_when) == "function" then
                local ok, result = pcall(item.visible_when)
                show = ok and result == true
            end
            if show then
                table.insert(visible_items, item)
            end
        end
    end

    if #visible_items == 0 then
        return 0
    end

    local current_page = self:_get_active_page_id(tab_id)
    local current_valid = false
    for _, item in ipairs(visible_items) do
        if not item.header and item.id ~= nil and tostring(item.id) == tostring(current_page) then
            current_valid = true
            break
        end
    end

    if not current_valid then
        for _, item in ipairs(visible_items) do
            if not item.header and item.id ~= nil then
                self:_set_active_page_id(tab_id, item.id)
                current_page = item.id
                break
            end
        end
    end

    local x1 = LAYOUT.padding_side
    local x2 = x1 + width
    local panel_start = vec2.new(x1, viewport_top)
    local panel_end = vec2.new(x2, viewport_bottom)

    self.window:render_rect_filled(panel_start, panel_end, self.colors.section_bg, 2.0)
    self.window:render_rect(panel_start, panel_end, self.colors.section_border, 2.0, 1.0)
    self.window:is_mouse_hovering_rect_block_movement(panel_start, panel_end)

    local y = viewport_top + LAYOUT.side_menu_padding
    if section.side_menu.label and #tostring(section.side_menu.label) > 0 then
        local label = tostring(section.side_menu.label)
        local label_h = self.window:get_text_size(label).y
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(x1 + LAYOUT.side_menu_padding, y),
            self.colors.secondary_accent, label)
        y = y + label_h + LAYOUT.side_menu_item_spacing + 4
        local sep_y = y
        self.window:render_rect_filled(vec2.new(x1 + LAYOUT.side_menu_padding, sep_y),
            vec2.new(x2 - LAYOUT.side_menu_padding, sep_y + 1), self.colors.separator, 0)
        y = y + 6
    end

    local item_x1 = x1 + LAYOUT.side_menu_padding
    local item_x2 = x2 - LAYOUT.side_menu_padding
    local item_w = item_x2 - item_x1

    for _, item in ipairs(visible_items) do
        local label = item.label and tostring(item.label) or ""
        if item.header then
            local header_h = self.window:get_text_size(label).y
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(item_x1, y),
                self.colors.primary_accent, label)
            y = y + header_h + LAYOUT.side_menu_item_spacing
        else
            local item_start = vec2.new(item_x1, y)
            local item_end = vec2.new(item_x1 + item_w, y + LAYOUT.side_menu_item_height)
            local hovered = self.window:is_mouse_hovering_rect(item_start, item_end)
            self.window:is_mouse_hovering_rect_block_movement(item_start, item_end)

            local is_active = current_page ~= nil and item.id ~= nil and tostring(item.id) == tostring(current_page)
            local bg = self.colors.section_bg
            local border = self.colors.section_border
            local text_col = self.colors.text_secondary

            if is_active then
                bg = self.colors.primary_accent
                border = self.colors.primary_accent
                text_col = self.colors.tab_text_active or color.white(255)
            elseif hovered then
                bg = lighten_color(self.colors.section_bg, 20)
                text_col = self.colors.text_primary
            end

            self.window:render_rect_filled(item_start, item_end, bg, 2.0)
            self.window:render_rect(item_start, item_end, border, 2.0, 1.0)

            local text_size = self.window:get_text_size(label)
            local text_y = y + (LAYOUT.side_menu_item_height - text_size.y) / 2
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(item_x1 + 8, text_y),
                text_col, label)

            if self.window:is_rect_clicked(item_start, item_end) and item.id ~= nil then
                self:_set_active_page_id(tab_id, item.id)
                current_page = item.id
            end

            y = y + LAYOUT.side_menu_item_height + LAYOUT.side_menu_item_spacing
        end
    end

    return width
end

-- ============================================================================
-- CONTENT LAYOUT HELPERS
-- ============================================================================

function RotationSettingsUI:_get_content_width()
    if not self.window then
        return 0
    end
    local window_size = self.window:get_size()
    local reserved = self._scrollbar_reserved_right or 0
    local left_reserved = self._side_menu_reserved_left or 0
    local w = window_size.x - (2 * LAYOUT.padding_side) - reserved - left_reserved
    return math.max(0, w)
end

function RotationSettingsUI:_get_content_x_start()
    return self._content_x_start or LAYOUT.padding_side
end

function RotationSettingsUI:_set_content_layout(side_menu_width)
    local width = 0
    local x_start = LAYOUT.padding_side
    local left_reserved = 0

    if side_menu_width and side_menu_width > 0 then
        left_reserved = side_menu_width + LAYOUT.side_menu_gap
        x_start = LAYOUT.padding_side + left_reserved
    end

    self._side_menu_reserved_left = left_reserved
    self._content_x_start = x_start
    width = self:_get_content_width()
    return x_start, width
end
