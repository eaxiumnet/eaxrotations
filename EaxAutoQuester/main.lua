-- What: Entry point for EaxAutoQuester
-- When: Loaded by Project Sylvanas on plugin start
-- Why: Bootstraps auto-questing — pre-tick, render, menu callbacks
-- Safety: lazy-loads submodules; menu checkbox + keybind control enable

local _core_time = core.time
local _core_log = core.log
local _get_local_player = core.object_manager.get_local_player

local NS = {}
_G.EaxAutoQuester = NS

-- Plugin state
local state = {
    enabled = false,
    paused = false,
    initialized = false,
    version = "1.0.0",
    warning_msg = nil,
    warning_timer = 0,
}
local _utils = nil
local _menu = nil
local _quest_state = nil
local _t = { n = 0 }

-- ============================================================================
-- Module Initialization
-- ============================================================================
local function init_modules()
    if state.initialized then return true end
    _t.n = 0
    local ok

    ok, _utils = pcall(require, "utils_sylvanas")
    if ok then _t.n = _t.n + 1; _t[_t.n] = "utils" else _utils = nil end

    ok, _menu = pcall(require, "menu_sylvanas")
    if ok then _t.n = _t.n + 1; _t[_t.n] = "menu" else _menu = nil end

    ok, _quest_state = pcall(require, "quest_state_sylvanas")
    if ok then _t.n = _t.n + 1; _t[_t.n] = "quest_state" else _quest_state = nil end

    state.initialized = true
    state.enabled = false
    _core_log("EaxAutoQuester v" .. tostring(state.version) .. " initialized — modules: " .. table.concat(_t, ", ", 1, _t.n))
    return true
end

--- Show a warning on screen for N seconds.
local function set_warning(msg, duration)
    state.warning_msg = msg
    state.warning_timer = _core_time() + (duration or 5.0)
end

local _prev_enabled = nil  -- track transitions for hard stop

--- Read menu checkbox for enabled state, handle keybind toggle.
--- When disabled, immediately stop all navigation.
local function check_enabled()
    if not _menu then return end

    -- Read the enable checkbox
    local cb = _menu.get and _menu.get("enable", false)
    if cb ~= nil then state.enabled = cb end

    -- Read keybind toggle: if keybind is pressed, toggle checkbox state
    if _menu.toggle_keybind then
        local ok, toggle = pcall(function() return _menu.toggle_keybind:get_toggle_state() end)
        if ok then
            local prev = _menu._last_kb_toggle
            if prev ~= nil and toggle ~= prev then
                state.enabled = toggle
                if _menu.enable and _menu.enable.set then
                    pcall(function() _menu.enable:set(toggle) end)
                end
            end
            _menu._last_kb_toggle = toggle
        end
    end

    -- Handle control button clicks
    if _menu then
        if _menu.btn_start and _menu.btn_start:is_clicked() then
            state.enabled = true
            state.paused = false
            if _menu.enable then pcall(function() _menu.enable:set(true) end) end
        end
        if _menu.btn_stop and _menu.btn_stop:is_clicked() then
            state.enabled = false
            state.paused = false
            if _menu.enable then pcall(function() _menu.enable:set(false) end) end
            if _quest_state and _quest_state.stop_navigation then
                _quest_state.stop_navigation()
            end
        end
        if _menu.btn_pause and _menu.btn_pause:is_clicked() then
            state.paused = true
            if _quest_state and _quest_state.stop_navigation then
                _quest_state.stop_navigation()
            end
        end
        if _menu.btn_resume and _menu.btn_resume:is_clicked() then
            state.paused = false
        end
    end

    -- Hard stop: if transitioning from enabled to disabled, kill all navigation
    if _prev_enabled == true and not state.enabled then
        if _quest_state and _quest_state.stop_navigation then
            _quest_state.stop_navigation()
        end
    end
    _prev_enabled = state.enabled
end

--- Render warning overlay — always shows when warning is active.
local function render_warnings()
    if not state.warning_msg then return end
    if _core_time() > state.warning_timer then
        state.warning_msg = nil
        return
    end

    local c_ok, color = pcall(require, "common/color")
    if not c_ok then return end

    local lines = {}
    lines[#lines + 1] = "!!! EaxAutoQuester !!!"
    lines[#lines + 1] = tostring(state.warning_msg)
    lines[#lines + 1] = "Manual input may be required"

    local text = table.concat(lines, "\n")
    local screen = core.graphics.get_screen_size()
    if screen then
        local cx = screen.x * 0.5
        pcall(core.graphics.draw_text, cx - 100, screen.y * 0.4, text)
    end
end

-- ============================================================================
-- Public: called by quest_state to report status
-- ============================================================================
function NS.set_warning(msg, duration)
    set_warning(msg, duration)
end

function NS.get_state()
    return state
end

-- ============================================================================
-- Callbacks
-- ============================================================================
local function on_pre_tick()
    if not _menu then init_modules() end
    check_enabled()
    if not state.enabled then return end
    if state.paused then return end
    if not _quest_state then return end
    _quest_state.update()
end

local function on_render()
    render_warnings()
    if not state.enabled then return end
    if not _quest_state then return end
    _quest_state.render_debug()
end

local function on_render_menu()
    if not _menu then init_modules() end
    if _menu then _menu.render() end
end

core.register_on_pre_tick_callback(on_pre_tick)
core.register_on_render_callback(on_render)
core.register_on_render_menu_callback(on_render_menu)

function NS.init_modules() return init_modules() end
function NS.get_utils() return _utils end
function NS.get_menu() return _menu end
function NS.get_quest_state() return _quest_state end

return NS
