-- ext_lib_astro_ui/lifecycle.lua
-- Window management, main orchestrator, lifecycle hooks, and launcher

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

-- ============================================================================
-- WINDOW MANAGEMENT
-- ============================================================================

function RotationSettingsUI:_build_window()
    self._window_epoch = (self._window_epoch or 0) + 1
    self._window_id = string.format("%s##%d", self.title, self._window_epoch)
    self.window = core.menu.window(self._window_id)

    if self._pos_x and self._pos_y then
        self.window:set_initial_position(vec2.new(self._pos_x:get(), self._pos_y:get()))
    end
    if self._size_x and self._size_y then
        self.window:set_initial_size(vec2.new(self._size_x:get(), self._size_y:get()))
    end
end

function RotationSettingsUI:_sync_window_state()
    if not self.window then
        return
    end

    local ok_pos, pos = pcall(function()
        return self.window:get_position()
    end)
    if ok_pos and pos and self._pos_x and self._pos_y then
        local x = math.floor(pos.x + 0.5)
        local y = math.floor(pos.y + 0.5)
        if x ~= self._pos_x:get() then
            self._pos_x:set(x)
        end
        if y ~= self._pos_y:get() then
            self._pos_y:set(y)
        end
    end

    local ok_size, size = pcall(function()
        return self.window:get_size()
    end)
    if ok_size and size and self._size_x and self._size_y then
        local sx = math.floor(size.x + 0.5)
        local sy = math.floor(size.y + 0.5)
        if sx ~= self._size_x:get() then
            self._size_x:set(sx)
        end
        if sy ~= self._size_y:get() then
            self._size_y:set(sy)
        end
    end
end

function RotationSettingsUI:_is_enabled()
    if self.menu and self.menu.enable then
        return self.menu.enable:get_state()
    end
    return false
end

-- ============================================================================
-- MAIN SECTION RENDERING (Orchestrator)
-- ============================================================================

function RotationSettingsUI:_render_sections()
    -- Render tab bar
    local y_offset = self:_render_tab_bar()

    -- Add separator line below tabs
    local window_size = self.window:get_size()
    local separator_start = vec2.new(LAYOUT.padding_side, y_offset)
    local separator_end = vec2.new(window_size.x - LAYOUT.padding_side, y_offset + 2)
    self.window:render_rect_filled(separator_start, separator_end, self.colors.separator, 0)

    y_offset = y_offset + 2 + LAYOUT.tab_content_padding_top

    -- Search bar (rendered between tab separator and content)
    if self._search_active and self._search_config then
        y_offset = self:_render_search_bar(y_offset)
    end

    local viewport_top = y_offset
    local viewport_bottom = window_size.y - LAYOUT.padding_bottom
    -- Reserve space for preset footer when enabled
    if self._preset then
        viewport_bottom = viewport_bottom - LAYOUT.preset_footer_height
    end
    if self._active_key_capture then
        viewport_bottom = viewport_bottom - 18
    end
    if viewport_bottom < viewport_top then
        viewport_bottom = viewport_top
    end

    local section = nil
    if self.active_tab_index >= 1 and self.active_tab_index <= #self.sections then
        section = self.sections[self.active_tab_index]
    end

    -- Optional side-menu (sub categories) inside the active tab.
    local side_menu_width = 0
    if section and section.type == "tab" and section.side_menu then
        side_menu_width = self:_render_side_menu(section, viewport_top, viewport_bottom)
    end
    self:_set_content_layout(side_menu_width > 0 and side_menu_width or nil)

    -- Activate native scroll mechanics for bidirectional mouse wheel detection.
    -- Uses large virtual content (10000px) with scroll centered at 5000px so
    -- both up and down wheel input produces a measurable delta from center.
    -- Must be called BEFORE reading scroll to ensure bounds exist this frame.
    pcall(function()
        self.window:add_artificial_item_bounds(
            vec2.new(0, 0),
            vec2.new(1, 10000),
            "astro_ui_scroll"
        )
    end)

    local scroll_key = self:_get_active_scroll_key()
    local scroll = self:_get_tab_scroll_offset(scroll_key)
    self._scroll_viewport = { top = viewport_top, bottom = viewport_bottom }

    -- Render active tab content with vertical scroll offset
    local content_end_scrolled = self:_render_active_tab_content(y_offset - scroll)
    local content_end_unscrolled = content_end_scrolled + scroll
    local content_height = math.max(0, content_end_unscrolled - y_offset)

    -- Clamp scroll to valid bounds and render scrollbar if needed.
    local viewport_height = viewport_bottom - viewport_top
    local max_scroll = math.max(0, content_height - viewport_height)
    if scroll > max_scroll then
        scroll = max_scroll
        self:_set_tab_scroll_offset(scroll_key, scroll, max_scroll)
    end

    -- Handle mouse wheel + keyboard scroll input
    self:_handle_scroll_input(scroll_key, max_scroll, viewport_height)
    scroll = self:_get_tab_scroll_offset(scroll_key)

    self:_render_scrollbar(scroll_key, content_height, viewport_top, viewport_bottom)

    -- Overlay dropdowns last to avoid being covered by later groups.
    -- Keep viewport info until after overlays so we can clamp dropdowns to it.
    self:_render_combo_dropdown_overlay()
    self:_render_context_menu_overlay()
    self._scroll_viewport = nil

    -- Preset footer (always visible at bottom)
    if self._preset then
        self:_render_preset_footer()
        self:_render_preset_dropdown_overlay()
    end

    if self._active_key_capture then
        self.window:block_input_capture()
    end
    self:_process_key_capture_input()
    self:_render_key_capture_prompt()
end

-- ============================================================================
-- SEARCH BAR
-- ============================================================================

function RotationSettingsUI:_render_search_bar(y_offset)
    local window_size = self.window:get_size()
    local x_start = LAYOUT.padding_side
    local bar_width = window_size.x - 2 * LAYOUT.padding_side
    local bar_height = 28

    -- Background
    local bar_start = vec2.new(x_start, y_offset)
    local bar_end = vec2.new(x_start + bar_width, y_offset + bar_height)
    self.window:render_rect_filled(bar_start, bar_end, self.colors.slider_bg, 3.0)
    self.window:render_rect(bar_start, bar_end, self.colors.section_border, 3.0, 1.0)

    -- Lazy-create text input element
    if not self._search_input then
        pcall(function()
            self._search_input = core.menu.text_input("astro_search_" .. self.id, false)
        end)
    end

    -- Render text input via render_custom (positioned with dynamic drawing offset)
    if self._search_input then
        local input_x = x_start + 8
        local input_y = y_offset + 4
        local input_w = bar_width - 40
        local input_h = bar_height - 8

        local input_offset = vec2.new(input_x, input_y)
        local ok_prev, prev_offset = pcall(function()
            return self.window:get_current_context_dynamic_drawing_offset()
        end)

        local ok_set = pcall(function()
            self.window:set_current_context_dynamic_drawing_offset(input_offset)
        end)

        if ok_set then
            pcall(function()
                self._search_input:render_custom(
                    "##astro_search",            -- label (## prefix hides it)
                    "",                          -- tooltip
                    self.colors.slider_bg,       -- frame background
                    self.colors.section_border,  -- border color
                    self.colors.primary_accent,  -- text selection highlight
                    self.colors.text_primary,    -- text color
                    input_w,                     -- width offset
                    0                            -- height offset
                )
            end)
        end

        if ok_prev and prev_offset then
            pcall(function()
                self.window:set_current_context_dynamic_drawing_offset(prev_offset)
            end)
        end

        -- Read query
        local ok, text = pcall(function() return self._search_input:get_text() end)
        if ok and type(text) == "string" then
            self._search_query = text
        end

        -- Placeholder text when empty
        if #self._search_query == 0 then
            local placeholder = (self._search_config and self._search_config.placeholder) or "Search..."
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL,
                vec2.new(input_x + 2, input_y + (input_h - self.window:get_text_size(placeholder).y) / 2),
                self.colors.text_secondary, placeholder)
        end

        -- Clear button (X) when query is not empty
        if #self._search_query > 0 then
            local clear_x = x_start + bar_width - 26
            local clear_y = y_offset + 4
            local clear_start = vec2.new(clear_x, clear_y)
            local clear_end = vec2.new(clear_x + 20, clear_y + bar_height - 8)
            local clear_hovered = self.window:is_mouse_hovering_rect(clear_start, clear_end)
            self.window:is_mouse_hovering_rect_block_movement(clear_start, clear_end)

            local clear_col = clear_hovered and self.colors.text_primary or self.colors.text_secondary
            local clear_text_size = self.window:get_text_size("X")
            self.window:render_text(enums.window_enums.font_id.FONT_SMALL,
                vec2.new(clear_x + (20 - clear_text_size.x) / 2, clear_y + (bar_height - 8 - clear_text_size.y) / 2),
                clear_col, "X")

            if self.window:is_rect_clicked(clear_start, clear_end) then
                pcall(function() self._search_input:set("") end)
                self._search_query = ""
            end
        end
    end

    -- Escape key closes search
    local esc_pressed = false
    pcall(function() esc_pressed = core.input.is_key_pressed(27) end)
    if esc_pressed then
        self._search_active = false
        self._search_query = ""
        if self._search_input then
            pcall(function() self._search_input:set("") end)
        end
    end

    return y_offset + bar_height + 4
end

-- ============================================================================
-- PUBLIC API - LIFECYCLE HOOKS
-- ============================================================================

---Called in rotation's on_menu_render() to show toggle button
function RotationSettingsUI:on_menu_render()
    if not self.menu or not self.menu.enable then
        return
    end

    -- Simple checkbox in classic menu to toggle custom window
    if self.menu.enable:get_state() then
        -- Window is enabled, could add a button here if needed
    end
end

---Called in rotation's on_render() to render the custom window
function RotationSettingsUI:on_render()
    -- Check if window close was requested in previous frame
    if self._window_close_requested then
        -- Skip rendering this frame to allow checkbox state to sync
        self._window_close_requested = false
        return
    end

    if not self:_is_enabled() then
        return
    end

    self:_ensure_extension_tabs()

    -- Update theme based on selector
    self:_update_theme()

    if not self.window then
        self:_build_window()
    end

    -- Sync tab state from saved value
    self:_sync_tab_state()

    -- Register window render callback
    local function render_window_content()
        self:_render_sections()
    end

    local window_is_open = self.window:begin(
        enums.window_enums.window_resizing_flags.RESIZE_BOTH_AXIS,
        true,
        self.colors.background,
        self.colors.border,
        enums.window_enums.window_cross_visuals.DEFAULT,
        enums.window_enums.window_behaviour_flags.NO_SCROLLBAR,
        render_window_content
    )

    self:_sync_window_state()

    -- CRITICAL: Check window state AFTER sync to handle X button close
    -- If user clicked X button to close, disable the checkbox (like F1 toggle)
    -- This allows F1 to re-open the window later
    if not window_is_open then
        -- Destroy window object so it gets rebuilt on next open
        self.window = nil

        -- Set flag to skip next frame (allows checkbox to sync)
        self._window_close_requested = true

        -- Disable the checkbox
        if self.menu and self.menu.enable then
            pcall(function()
                if self.menu.enable.set then
                    self.menu.enable:set(false)
                elseif self.menu.enable.set_state then
                    self.menu.enable:set_state(false)
                end
            end)
        end
    end
end

-- ============================================================================
-- LAUNCHER (Window Registry + F1 Toggle Panel)
-- ============================================================================

function RotationSettingsUI.register_window(ui_instance)
    if not ui_instance then return end
    for _, w in ipairs(RotationSettingsUI._registered_windows) do
        if w == ui_instance then return end
    end
    table.insert(RotationSettingsUI._registered_windows, ui_instance)
end

function RotationSettingsUI.unregister_window(ui_instance)
    if not ui_instance then return end
    for i, w in ipairs(RotationSettingsUI._registered_windows) do
        if w == ui_instance then
            table.remove(RotationSettingsUI._registered_windows, i)
            return
        end
    end
end

function RotationSettingsUI.render_launcher()
    local windows = RotationSettingsUI._registered_windows
    if #windows == 0 then return end

    if not RotationSettingsUI._launcher_window then
        RotationSettingsUI._launcher_window = core.menu.window("Astro UI Launcher##launcher")
        RotationSettingsUI._launcher_window:set_initial_size(vec2.new(220, 40 + #windows * 28))
        RotationSettingsUI._launcher_window:set_initial_position(vec2.new(10, 10))
    end

    local lw = RotationSettingsUI._launcher_window

    lw:begin(
        enums.window_enums.window_resizing_flags.NO_RESIZE,
        true,
        color.new(20, 20, 25, 240),
        color.new(60, 60, 80, 200),
        enums.window_enums.window_cross_visuals.DEFAULT,
        function()
            local y = 6
            local w_size = lw:get_size()

            for _, ui in ipairs(windows) do
                local title = ui.title or "Window"
                local enabled = false
                if ui.menu and ui.menu.enable then
                    pcall(function() enabled = ui.menu.enable:get_state() end)
                end

                local row_start = vec2.new(8, y)
                local row_end = vec2.new(w_size.x - 8, y + 22)
                local hovered = lw:is_mouse_hovering_rect(row_start, row_end)
                lw:is_mouse_hovering_rect_block_movement(row_start, row_end)

                if hovered then
                    lw:render_rect_filled(row_start, row_end, color.new(255, 255, 255, 15), 3.0)
                end

                local dot_col = enabled and color.new(80, 200, 120, 255) or color.new(120, 120, 120, 255)
                lw:render_circle_filled(vec2.new(18, y + 11), 4, dot_col)

                local text_col = enabled and color.new(220, 220, 220, 255) or color.new(140, 140, 140, 255)
                lw:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(28, y + 3), text_col, title)

                if lw:is_rect_clicked(row_start, row_end) or (hovered and lw:is_mouse_button_clicked(0)) then
                    lw:block_input_capture()
                    pcall(function()
                        if ui.menu and ui.menu.enable then
                            if ui.menu.enable.set then
                                ui.menu.enable:set(not enabled)
                            elseif ui.menu.enable.set_state then
                                ui.menu.enable:set_state(not enabled)
                            end
                        end
                    end)
                end

                y = y + 28
            end
        end
    )
end
