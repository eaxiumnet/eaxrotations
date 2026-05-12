-- Readability notes:
--   What: diagnostic helper.
--   When: runs when debug output is enabled.
--   Why: makes failures understandable for users and maintainers.
--   Safety: throttle repeated output and avoid work when debug is off.

-- Decision notes:
--   This support module keeps side effects explicit and routes runtime-sensitive work through NS helpers.
--   Comments emphasize intent and constraints so future edits preserve behavior without adding frame-costly checks.
--   When API data is missing, callers should skip unsafe work rather than guessing.
-- ============================================================================
-- EaxRotations Debug Log Frame
-- Visual debug output using core.menu.window API
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local format = string.format
local tinsert = table.insert
local tremove = table.remove
local tconcat = table.concat

local color = require("common/color")
local vec2 = require("common/geometry/vector_2")
local enums = require("common/enums")

local DEBUG_WINDOW_ID = "EaxRotationsDebugLog"
local WINDOW_WIDTH = 500
local WINDOW_HEIGHT = 350
local MIN_WIDTH = 300
local MIN_HEIGHT = 150
local DEBUG_SETTINGS_FILE = "eaxrotations/debuglog.json"

local debug_window = nil
local debug_visible = false
local debug_log_lines = {}
local MAX_LOG_LINES = 500
local MAX_VISIBLE_LINES = 20
local SCROLL_LINES = 5

local LOG_LEVEL = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4,
}

local current_log_level = LOG_LEVEL.DEBUG
local scroll_offset = 0
local auto_scroll = true

local is_resizing = false
local was_mouse_down = false
local resize_start_pos = nil
local resize_start_size = nil
local last_debug_pos = nil

local THEME = {
    bg = color.new(17, 17, 20, 245),
    border = color.new(44, 44, 52, 255),
    text = color.new(230, 230, 230, 255),
    text_dim = color.new(128, 128, 153, 255),
    text_warning = color.new(255, 204, 51, 255),
    text_error = color.new(255, 77, 77, 255),
    accent = color.new(108, 99, 255, 255),
    button_bg = color.new(30, 30, 40, 255),
    button_hover = color.new(45, 45, 60, 255),
    resize_grip = color.new(60, 60, 70, 255),
}

local function load_debug_position()
    local _, result = pcall(function()  -- success unused: only result needed
        local data = core.read_data_file(DEBUG_SETTINGS_FILE)
        if data and #data > 0 then
            local pos_x, pos_y = string.match(data, '"x":(%d+),"y":(%d+)')
            if pos_x and pos_y then
                return vec2.new(tonumber(pos_x), tonumber(pos_y))
            end
        end
        return nil
    end)
    return result
end

local function create_debug_window()
    if debug_window then return debug_window end

    local saved_pos = load_debug_position()

    debug_window = core.menu.window(DEBUG_WINDOW_ID)
    debug_window:set_initial_size(vec2.new(WINDOW_WIDTH, WINDOW_HEIGHT))

    if saved_pos then
        debug_window:set_initial_position(saved_pos)
    else
        debug_window:set_initial_position(vec2.new(300, 200))
    end

    debug_window:set_next_window_close_cross_pos_offset(vec2.new(-5, 5))
    debug_window:set_next_window_min_size(vec2.new(MIN_WIDTH, MIN_HEIGHT))

    return debug_window
end

local function save_debug_position()
    if not debug_window then return end

    local pos = debug_window:get_position()
    if pos then
        local data = '{"x":' .. tostring(math.floor(pos.x)) .. ',"y":' .. tostring(math.floor(pos.y)) .. '}'
        pcall(function()
            core.create_data_folder("eaxrotations")
            core.create_data_file(DEBUG_SETTINGS_FILE)
            core.write_data_file(DEBUG_SETTINGS_FILE, data)
        end)
    end
end

local function get_level_color(level)
    if level == LOG_LEVEL.WARNING then return THEME.text_warning end
    if level == LOG_LEVEL.ERROR then return THEME.text_error end
    return THEME.text
end

function NS.CreateDebugLogFrame()
    if not debug_window then
        debug_window = create_debug_window()
    end
    return debug_window
end

function NS.RefreshDebugLogFrame()
    if not debug_window or not debug_window:is_being_shown() then return end
end

--- Set debug log window visibility
-- @param visible boolean - True to show, false to hide
function NS.SetDebugLogVisible(visible)
    if not debug_window then
        if visible then
            debug_window = create_debug_window()
        else
            return
        end
    end
    debug_visible = visible
    debug_window:set_visibility(debug_visible)
end

--- Check if debug log window is currently visible
-- @return boolean
function NS.IsDebugLogVisible()
    return debug_visible
end

function NS.AddDebugLogLine(message, level)
    level = level or LOG_LEVEL.DEBUG
    if level < current_log_level then return end

    local now = NS.time_now and NS.time_now() or 0
    local line = format("[%.1f] %s", now, tostring(message))
    local line_color = get_level_color(level)

    tinsert(debug_log_lines, { text = line, color = line_color })
    while #debug_log_lines > MAX_LOG_LINES do
        tremove(debug_log_lines, 1)
    end

    if auto_scroll then
        scroll_offset = math.max(0, #debug_log_lines - MAX_VISIBLE_LINES)
    else
        local max_offset = math.max(0, #debug_log_lines - MAX_VISIBLE_LINES)
        if scroll_offset > max_offset then
            scroll_offset = max_offset
        end
    end

    if debug_visible and debug_window then
        debug_window:set_visibility(true)
    end
end

function NS.write_debug_log_line(message)
    NS.AddDebugLogLine(message, LOG_LEVEL.DEBUG)
end

function NS.ClearDebugLog()
    for i = #debug_log_lines, 1, -1 do
        debug_log_lines[i] = nil
    end
    scroll_offset = 0
    auto_scroll = true
end

function NS.GetDebugLog()
    local lines = {}
    for i, v in ipairs(debug_log_lines) do
        tinsert(lines, v.text)
    end
    return lines
end

function NS.SetDebugLogLevel(level)
    current_log_level = level
end

function NS.GetDebugLogAsString()
    local lines = {}
    for i, v in ipairs(debug_log_lines) do
        tinsert(lines, v.text)
    end
    return tconcat(lines, "\n")
end

function NS.ScrollDebugLogUp()
    local max_offset = math.max(0, #debug_log_lines - MAX_VISIBLE_LINES)
    if scroll_offset < max_offset then
        scroll_offset = scroll_offset + SCROLL_LINES
        if scroll_offset > max_offset then
            scroll_offset = max_offset
        end
        auto_scroll = false
    end
end

function NS.ScrollDebugLogDown()
    if scroll_offset > 0 then
        scroll_offset = scroll_offset - SCROLL_LINES
        if scroll_offset < 0 then scroll_offset = 0 end
    end
end

function NS.ScrollDebugLogTop()
    scroll_offset = 0
    auto_scroll = false
end

function NS.ScrollDebugLogBottom()
    scroll_offset = math.max(0, #debug_log_lines - MAX_VISIBLE_LINES)
    auto_scroll = true
end

local function render_buttons(win_w, win_h)
    local btn_y = -30
    local btn_width = 50
    local btn_height = 20
    local btn_spacing = 5
    local start_x = win_w - 180

    local copy_rect_min = vec2.new(start_x, btn_y)
    local copy_rect_max = vec2.new(start_x + btn_width, btn_y + btn_height)
    local copy_hover = debug_window:is_mouse_hovering_rect(copy_rect_min, copy_rect_max)
    local copy_color = copy_hover and THEME.button_hover or THEME.button_bg

    debug_window:render_rect_filled(copy_rect_min, copy_rect_max, copy_color, 2)
    debug_window:add_menu_element_pos_offset(vec2.new(start_x + 5, btn_y + 5))
    debug_window:add_text_on_dynamic_pos(THEME.text, "Copy")
    debug_window:draw_next_dynamic_widget_on_new_line()

    local clear_x = start_x + btn_width + btn_spacing
    local clear_rect_min = vec2.new(clear_x, btn_y)
    local clear_rect_max = vec2.new(clear_x + btn_width, btn_y + btn_height)
    local clear_hover = debug_window:is_mouse_hovering_rect(clear_rect_min, clear_rect_max)
    local clear_color = clear_hover and THEME.button_hover or THEME.button_bg

    debug_window:render_rect_filled(clear_rect_min, clear_rect_max, clear_color, 2)
    debug_window:add_menu_element_pos_offset(vec2.new(clear_x + 5, btn_y + 5))
    debug_window:add_text_on_dynamic_pos(THEME.text, "Clear")
    debug_window:draw_next_dynamic_widget_on_new_line()

    local scroll_x = clear_x + btn_width + btn_spacing
    local up_rect_min = vec2.new(scroll_x, btn_y)
    local up_rect_max = vec2.new(scroll_x + 20, btn_y + btn_height)
    local up_hover = debug_window:is_mouse_hovering_rect(up_rect_min, up_rect_max)
    local up_color = up_hover and THEME.button_hover or THEME.button_bg
    debug_window:render_rect_filled(up_rect_min, up_rect_max, up_color, 2)
    debug_window:add_menu_element_pos_offset(vec2.new(scroll_x + 5, btn_y + 5))
    debug_window:add_text_on_dynamic_pos(THEME.text_dim, "^")
    debug_window:draw_next_dynamic_widget_on_new_line()

    local down_x = scroll_x + 22
    local down_rect_min = vec2.new(down_x, btn_y)
    local down_rect_max = vec2.new(down_x + 20, btn_y + btn_height)
    local down_hover = debug_window:is_mouse_hovering_rect(down_rect_min, down_rect_max)
    local down_color = down_hover and THEME.button_hover or THEME.button_bg
    debug_window:render_rect_filled(down_rect_min, down_rect_max, down_color, 2)
    debug_window:add_menu_element_pos_offset(vec2.new(down_x + 5, btn_y + 5))
    debug_window:add_text_on_dynamic_pos(THEME.text_dim, "v")
    debug_window:draw_next_dynamic_widget_on_new_line()

    local grip_size = 12
    local grip_rect_min = vec2.new(win_w - grip_size, win_h - grip_size)
    local grip_rect_max = vec2.new(win_w, win_h)
    local grip_hover = debug_window:is_mouse_hovering_rect(grip_rect_min, grip_rect_max)
    local grip_color = grip_hover and THEME.accent or THEME.resize_grip

    debug_window:render_rect_filled(grip_rect_min, grip_rect_max, grip_color, 0)

    for i = 1, 3 do
        local line_x = win_w - (i * 3)
        local line_start = vec2.new(line_x, win_h - grip_size + 1)
        local line_end = vec2.new(line_x, win_h - 1)
        if line_x > win_w - grip_size - 2 then
            debug_window:render_line(line_start, line_end, color.new(0, 0, 0, 100), 1)
        end
    end
end

local function handle_button_clicks(win_w, win_h)
    local btn_y = -30
    local btn_height = 20
    local start_x = win_w - 180
    local btn_width = 50
    local btn_spacing = 5

    local copy_rect_min = vec2.new(start_x, btn_y)
    local copy_rect_max = vec2.new(start_x + btn_width, btn_y + btn_height)
    if debug_window:is_rect_clicked(copy_rect_min, copy_rect_max) then
        local log_text = NS.GetDebugLogAsString()
        NS.log("=== Debug Log ===")
        local chunks = {}
        local chunk_size = 2000
        for i = 1, #log_text, chunk_size do
            tinsert(chunks, log_text:sub(i, i + chunk_size - 1))
        end
        for _, chunk in ipairs(chunks) do
            NS.log(chunk)
        end
        NS.log("=== End ===")
    end

    local clear_x = start_x + btn_width + btn_spacing
    local clear_rect_min = vec2.new(clear_x, btn_y)
    local clear_rect_max = vec2.new(clear_x + btn_width, btn_y + btn_height)
    if debug_window:is_rect_clicked(clear_rect_min, clear_rect_max) then
        NS.ClearDebugLog()
    end

    local scroll_x = clear_x + btn_width + btn_spacing
    local up_rect_min = vec2.new(scroll_x, btn_y)
    local up_rect_max = vec2.new(scroll_x + 20, btn_y + btn_height)
    if debug_window:is_rect_clicked(up_rect_min, up_rect_max) then
        NS.ScrollDebugLogUp()
    end

    local down_x = scroll_x + 22
    local down_rect_min = vec2.new(down_x, btn_y)
    local down_rect_max = vec2.new(down_x + 20, btn_y + btn_height)
    if debug_window:is_rect_clicked(down_rect_min, down_rect_max) then
        NS.ScrollDebugLogDown()
    end

    local grip_size = 12
    local grip_rect_min = vec2.new(win_w - grip_size, win_h - grip_size)
    local grip_rect_max = vec2.new(win_w, win_h)
    if debug_window:is_rect_clicked(grip_rect_min, grip_rect_max) then
        is_resizing = true
        resize_start_pos = core.game_ui.get_wow_cursor_position and core.game_ui.get_wow_cursor_position()
        resize_start_size = debug_window:get_size()
    end
end

local function handle_mouse_wheel()
    local wheel_delta = core.get_mouse_wheel_delta and core.get_mouse_wheel_delta() or 0
    if wheel_delta ~= 0 then
        if wheel_delta > 0 then
            NS.ScrollDebugLogUp()
        else
            NS.ScrollDebugLogDown()
        end
    end
end

local function handle_resize()
    local current_mouse_down = core.input and core.input.is_key_pressed and core.input.is_key_pressed(0x01) or false
    if was_mouse_down and not current_mouse_down and is_resizing then
        is_resizing = false
        resize_start_pos = nil
        resize_start_size = nil
    end
    was_mouse_down = current_mouse_down

    if is_resizing and resize_start_pos and resize_start_size then
        local current_pos = core.game_ui.get_wow_cursor_position and core.game_ui.get_wow_cursor_position()
        if current_pos then
            local start_w = resize_start_size.x
            local start_h = resize_start_size.y
            local delta_x = current_pos.x - resize_start_pos.x
            local delta_y = resize_start_pos.y - current_pos.y

            local new_w = start_w + delta_x
            local new_h = start_h + delta_y

            if new_w < MIN_WIDTH then new_w = MIN_WIDTH end
            if new_h < MIN_HEIGHT then new_h = MIN_HEIGHT end

            debug_window:set_initial_size(vec2.new(new_w, new_h))
        end
    end

    local mouse_pos = debug_window:get_mouse_pos()
    if not mouse_pos then
        is_resizing = false
        resize_start_pos = nil
        resize_start_size = nil
        return
    end

    local win_size = debug_window:get_size()
    local win_w = win_size.x
    local win_h = win_size.y

    local in_grip = mouse_pos.x >= win_w - 12 and mouse_pos.y >= win_h - 12
    if not in_grip then
        is_resizing = false
        resize_start_pos = nil
        resize_start_size = nil
    end
end

local function render_debug_log()
    if not debug_window or not debug_window:is_being_shown() then return end

    local pos = debug_window:get_position()
    if pos and last_debug_pos then
        if pos.x ~= last_debug_pos.x or pos.y ~= last_debug_pos.y then
            save_debug_position()
        end
    end
    if pos then
        last_debug_pos = vec2.new(pos.x, pos.y)
    end

    handle_mouse_wheel()
    handle_resize()

    local window_size = debug_window:get_size()
    local win_w = window_size.x
    local win_h = window_size.y

    handle_button_clicks(win_w, win_h)

    local y_offset = vec2.new(10, -55)
    debug_window:add_menu_element_pos_offset(y_offset)

    debug_window:add_text_on_dynamic_pos(THEME.text, "Debug Log")
    debug_window:draw_next_dynamic_widget_on_new_line()

    debug_window:add_separator(-win_w + 20, 0, 0, 0, THEME.border)
    debug_window:draw_next_dynamic_widget_on_new_line()

    local content_height = win_h - 90
    local line_height = 12
    local actual_visible = math.min(MAX_VISIBLE_LINES, math.floor(content_height / line_height))
    if actual_visible < 1 then actual_visible = 1 end

    local start_idx = scroll_offset + 1
    local end_idx = math.min(start_idx + actual_visible - 1, #debug_log_lines)

    for i = start_idx, end_idx do
        local line = debug_log_lines[i]
        if line then
            debug_window:add_text_on_dynamic_pos(line.color or THEME.text, line.text)
            debug_window:draw_next_dynamic_widget_on_new_line()
        end
    end

    for i = end_idx + 1, start_idx + actual_visible - 1 do
        debug_window:add_text_on_dynamic_pos(THEME.text_dim, " ")
        debug_window:draw_next_dynamic_widget_on_new_line()
    end

    debug_window:add_separator(-win_w + 20, 0, 0, 0, THEME.border)
    debug_window:draw_next_dynamic_widget_on_new_line()

    local total_lines = #debug_log_lines
    local max_offset = math.max(0, total_lines - actual_visible)
    local scroll_info = format("Lines: %d | Scroll: %d/%d | Auto: %s",
        total_lines, scroll_offset, max_offset, auto_scroll and "ON" or "OFF")
    debug_window:add_text_on_dynamic_pos(THEME.text_dim, scroll_info)
    debug_window:draw_next_dynamic_widget_on_new_line()

    debug_window:add_text_on_dynamic_pos(THEME.text_dim, "Use menu to toggle debug log")
    debug_window:draw_next_dynamic_widget_on_new_line()

    render_buttons(win_w, win_h)
end

core.register_on_render_window_callback(function()
    if debug_visible and debug_window then
        debug_window:begin(
            enums.window_enums.window_resizing_flags.RESIZE_BOTH_AXIS,
            true,
            THEME.bg,
            THEME.border,
            enums.window_enums.window_cross_visuals.BLUE_THEME,
            enums.window_enums.window_behaviour_flags.ALWAYS_AUTO_RESIZE,
            function()
                render_debug_log()
            end
        )
    end
end)

NS.log("Debug log frame loaded (full parity)")
return {
    create = NS.CreateDebugLogFrame,
    refresh = NS.RefreshDebugLogFrame,
    toggle = function()
        if not debug_window then debug_window = create_debug_window() end
        debug_visible = not debug_visible
        debug_window:set_visibility(debug_visible)
    end,
    set_visible = NS.SetDebugLogVisible,
    is_visible = NS.IsDebugLogVisible,
    clear = NS.ClearDebugLog,
    set_level = NS.SetDebugLogLevel,
    scroll_up = NS.ScrollDebugLogUp,
    scroll_down = NS.ScrollDebugLogDown,
    scroll_top = NS.ScrollDebugLogTop,
    scroll_bottom = NS.ScrollDebugLogBottom,
}
