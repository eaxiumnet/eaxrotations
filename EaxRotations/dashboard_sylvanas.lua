-- render/menu helper.

-- ============================================================================
-- EaxRotations Dashboard Module
-- Combat overlay using core.menu.window API
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local format = string.format
local floor = math.floor

-- Pre-allocated empty table for 'or {}' fallbacks (avoids GC pressure from repeated table creation)
local EMPTY_TABLE = {}

-- Static buffers for per-frame getter data (reused across frames to eliminate GC churn)
local _cd_buffer = { n = 0 }
local _buff_buffer = { n = 0 }
local _debuff_buffer = { n = 0 }
local _custom_buffer = { n = 0 }

local color = require("common/color")
local vec2 = require("common/geometry/vector_2")
local enums = require("common/enums")
local icons = require("common/utility/icons_helper")

local DASHBOARD_WINDOW_ID = "EaxRotationsDashboard"
local FRAME_WIDTH = 170
local FRAME_HEIGHT = 350
local ICON_SIZE = 20
local ICON_GAP = 3
local ICONS_PER_ROW = 6
local ICON_X = 10
local DASHBOARD_SETTINGS_FILE = "eaxrotations/dashboard.json"

local dashboard_window = nil
local dashboard_visible = false
local dashboard_content_height = 0
local last_dashboard_pos = nil

local MAX_HISTORY = 6
local MIN_HISTORY_LINES = 3
local MAX_HISTORY_LINES = 6

-- [#swing] Estimated main-hand swing period in seconds (class-agnostic fallback).
-- Per-class code overrides this via NS.swing_period if available.
local ESTIMATED_SWING_PERIOD = 3.0
local SWING_BAR_HEIGHT = 8
local THREAT_BAR_HEIGHT = 6
local BURST_INDICATOR_SIZE = 20
local DOT_LABEL_HEIGHT = 12

local THEME = {
    bg = color.new(8, 8, 12, 255),
    border = color.new(30, 30, 38, 255),
    accent = color.new(108, 99, 255, 255),
    text = color.new(220, 220, 228, 255),
    text_dim = color.new(148, 148, 168, 255),
    threat_green = color.new(51, 230, 51, 255),
    threat_orange = color.new(255, 171, 51, 255),
    threat_red = color.new(255, 51, 51, 255),
    resource_hp = color.new(51, 204, 51, 255),
    resource_mana = color.new(51, 102, 230, 255),
    resource_energy = color.new(255, 220, 0, 255),
    resource_rage = color.new(230, 38, 38, 255),
}

local RESOURCE_COLORS = {
    mana = THEME.resource_mana,
    energy = THEME.resource_energy,
    rage = THEME.resource_rage,
}

local CLASS_HEX = {
    Druid = "ff7d0a", Hunter = "abd473", Mage = "69ccf0", Paladin = "f58cba",
    Priest = "ffffff", Rogue = "fff569", Shaman = "0070dd", Warlock = "9482c9",
    Warrior = "c79c6e",
}

local CLASS_RGB = {
    Druid = color.new(255, 125, 10),
    Hunter = color.new(171, 212, 69),
    Mage = color.new(105, 204, 240),
    Paladin = color.new(245, 140, 186),
    Priest = color.new(255, 255, 255),
    Rogue = color.new(255, 245, 105),
    Shaman = color.new(0, 112, 221),
    Warlock = color.new(148, 130, 201),
    Warrior = color.new(199, 156, 110),
}

-- [#15] Pre-allocated render colors — created once at module level, not inside render loops.
-- Previously these were color.new(...) calls inside update_dashboard(), creating GC churn every frame.
local RENDER_COLORS = {
    bar_bg = color.new(0, 0, 0, 150),
    energy_tick = color.new(255, 255, 255, 180),
    energy_sweep = color.new(255, 255, 255, 200),
    secondary_bar_bg = color.new(0, 0, 0, 100),
    tooltip_bg = color.new(20, 20, 30, 240),
    tooltip_border = color.new(100, 100, 120, 255),
    pip_filled = color.new(179, 115, 38, 255),
    pip_filled_border = color.new(217, 179, 51, 255),
    pip_empty = color.new(0, 0, 0, 150),
    pip_empty_border = color.new(60, 60, 70, 255),
    swing_bar = color.new(255, 125, 10),
    cd_border_off = color.new(30, 30, 38, 255),
    cd_border_ready = color.new(77, 166, 77, 255),
    cd_border_on = color.new(179, 115, 38, 255),
    buff_border = color.new(217, 179, 51, 255),
    buff_border_expiring = color.new(217, 38, 38, 255),
    debuff_border = color.new(179, 115, 38, 255),
    debuff_border_expiring = color.new(217, 38, 38, 255),
    icon_white = color.new(255, 255, 255, 255),
    burst_active = color.new(0, 255, 0, 180),
    -- [#enhancement] Pre-allocated colors for new dashboard elements
    burst_green = color.new(0, 255, 0, 180),
    threat_low = color.new(51, 230, 51, 255),
    threat_medium = color.new(255, 220, 0, 255),
    threat_high = color.new(255, 51, 51, 255),
    dot_expiring = color.new(255, 51, 51, 255),
}

local ENERGY_TICK_INTERVAL = 2.0

local last_action = { name = nil, source = nil }
local action_history = {}
local history_count = 0
local player_guid = nil

local energy_tick_tracker = {
    last_energy = 0,
    last_tick_time = 0,
    confident = false,
    last_stance = -1,
    stance_change_at = 0,
}

local dashboard_config = {
    cooldowns = {},
    buffs = {},
    debuffs = {},
    custom_lines = {},
}

local function safe_object_call(object, method, fallback, ...)
    if not object or not object[method] then return fallback end
    local ok, result = pcall(object[method], object, ...)
    if ok then return result end
    return fallback
end

local function safe_guid(object)
    return safe_object_call(object, "get_guid", nil)
end

local function ensure_player_guid()
    if not player_guid then
        local me = NS.GetPlayer and NS.GetPlayer()
        player_guid = safe_guid(me)
    end
    return player_guid
end

local function handle_spell_cast(data)
    if not data or not data.spell_id then return end

    local caster = data.caster
    if not caster then return end

    -- Wrap in pcall to catch "Invalid game object!" errors that escape
    -- safe_object_call's internal pcall during callback execution.
    local ok, err = pcall(function()
        local current_guid = ensure_player_guid()
        if not current_guid then return end

        local caster_guid = safe_guid(caster)
        if caster_guid and caster_guid == current_guid then
            local spell_name = data.spell_name or tostring(data.spell_id)
            NS.set_action_history(spell_name, data.spell_id)
        end
    end)
end

for i = 1, MAX_HISTORY do
    action_history[i] = { name = nil, texture = nil, spell_id = nil }
end

local function format_timer(seconds)
    if seconds >= 1e9 then return "" end
    if seconds > 60 then
        return format("%dm", floor(seconds / 60))
    end
    return format("%d", floor(seconds))
end

local function render_tooltip_at_mouse(text)
    local mouse_pos = dashboard_window:get_mouse_pos()
    if not mouse_pos then return end

    local win_size = dashboard_window:get_size()
    local win_pos = dashboard_window:get_position()

    local tooltip_x = mouse_pos.x + 15
    local tooltip_y = mouse_pos.y + 15

    if tooltip_x + 200 > win_pos.x + win_size.x then
        tooltip_x = mouse_pos.x - 200
    end
    if tooltip_y + 50 > win_pos.y + win_size.y then
        tooltip_y = mouse_pos.y - 50
    end

    local bg_min = vec2.new(tooltip_x, tooltip_y)
    local bg_max = vec2.new(tooltip_x + 200, tooltip_y + 30)
    dashboard_window:render_rect_filled(bg_min, bg_max, RENDER_COLORS.tooltip_bg, 2)
    dashboard_window:render_rect(bg_min, bg_max, RENDER_COLORS.tooltip_border, 1)

    dashboard_window:add_menu_element_pos_offset(vec2.new(tooltip_x + 5, tooltip_y + 8))
    dashboard_window:add_text_on_dynamic_pos(THEME.text, text)
    dashboard_window:draw_next_dynamic_widget_on_new_line()
end

local function check_icon_hover(icon_index, spell_id, spell_name, icon_x, icon_y)
    local mouse_pos = dashboard_window:get_mouse_pos()
    if not mouse_pos then return false end

    local win_pos = dashboard_window:get_position()
    if not win_pos then return false end

    local screen_x = win_pos.x + 8 + icon_x
    local screen_y = win_pos.y + icon_y

    local rel_x = mouse_pos.x
    local rel_y = mouse_pos.y

    if rel_x >= screen_x and rel_x <= screen_x + ICON_SIZE and
       rel_y >= screen_y and rel_y <= screen_y + ICON_SIZE then
        local text = spell_name
        if spell_id then
            text = text .. " (ID: " .. tostring(spell_id) .. ")"
        end
        render_tooltip_at_mouse(text)
        return true
    end
    return false
end

local function load_dashboard_position()
    local _, result = pcall(function()  -- success unused: only result needed
        local data = core.read_data_file(DASHBOARD_SETTINGS_FILE)
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

local function create_dashboard_window()
    if dashboard_window then return dashboard_window end

    local saved_pos = load_dashboard_position()

    dashboard_window = core.menu.window(DASHBOARD_WINDOW_ID)
    dashboard_window:set_initial_size(vec2.new(FRAME_WIDTH, FRAME_HEIGHT))

    if saved_pos then
        dashboard_window:set_initial_position(saved_pos)
    else
        dashboard_window:set_initial_position(vec2.new(50, 200))
    end

    dashboard_window:set_next_window_close_cross_pos_offset(vec2.new(-5, 5))

    return dashboard_window
end

local function save_dashboard_position()
    if not dashboard_window then return end

    local pos = dashboard_window:get_position()
    if pos then
        local data = '{"x":' .. tostring(floor(pos.x)) .. ',"y":' .. tostring(floor(pos.y)) .. '}'
        pcall(function()
            core.create_data_folder("eaxrotations")
            core.create_data_file(DASHBOARD_SETTINGS_FILE)
            core.write_data_file(DASHBOARD_SETTINGS_FILE, data)
        end)
    end
end

function NS.set_last_action(name, source, spell_id)
    -- Sticky spell anti-flicker: resolve spell_id from action_history if not provided,
    -- then check if the new suggestion should override the current sticky display.
    local resolved_spell_id = spell_id
    if not resolved_spell_id and name then
        -- Look up spell_id from history if name matches (recent actions may have stored it).
        for i = 1, history_count do
            local entry = action_history[i]
            if entry and entry.name == name then
                resolved_spell_id = entry.spell_id
                break
            end
        end
    end
    if NS.sticky_spell_should_override then
        -- Burst/defensive sources get priority 1 to override quickly; others stay at 0.
        local priority = 0
        if source and (source:find("burst") or source:find("offensive") or source:find("defensive")) then priority = 1 end
        local override = NS.sticky_spell_should_override(resolved_spell_id, name, priority)
        if not override then return end  -- Keep current sticky suggestion
    end
    last_action.name = name
    last_action.source = source
    last_action.spell_id = resolved_spell_id

    if name and history_count < MAX_HISTORY then
        history_count = history_count + 1
        for i = history_count, 2, -1 do
            action_history[i] = action_history[i - 1]
        end
        action_history[1] = { name = name, texture = nil, spell_id = resolved_spell_id }
    end
end

function NS.set_action_history(spell_name, spell_id)
    if spell_name and history_count < MAX_HISTORY then
        history_count = history_count + 1
        for i = history_count, 2, -1 do
            action_history[i] = action_history[i - 1]
        end
        action_history[1] = { name = spell_name, texture = nil, spell_id = spell_id }
    end
end

local function get_player_resources()
    local me = NS.GetPlayer()
    if not me then
        return { hp_pct = 100, max_hp = 100, mana_pct = 100, energy = 0, energy_max = 100, rage = 0, stance = 0 }
    end

    local hp_pct = NS.unit_health_pct and NS.unit_health_pct(me) or safe_object_call(me, "get_health_percentage", 100)
    local max_hp = safe_object_call(me, "get_max_health", 100)
    local mana_pct = NS.mana_pct and NS.mana_pct(me) or safe_object_call(me, "get_mana_percentage", 100)
    local energy = NS.power_current and NS.power_current(NS.POWER_ENERGY) or 0
    local energy_max = safe_object_call(me, "get_max_power", 100, NS.POWER_ENERGY)
    local rage = NS.power_current and NS.power_current(NS.POWER_RAGE) or 0
    local stance = 0  -- No generic IZI stance accessor; class context owns stance-sensitive decisions.

    return {
        hp_pct = hp_pct,
        max_hp = max_hp,
        mana_pct = mana_pct,
        energy = energy,
        energy_max = energy_max,
        rage = rage,
        stance = stance,
    }
end

local function get_target_info()
    local context = NS.GetCurrentContext and NS.GetCurrentContext()
    if not context then
        return { name = nil, hp = 0, ttd = 0, in_range = false, min_range = 0, max_range = 0, threat = 0, threat_situation = 0 }
    end

    local target = context.target
    local target_name = safe_object_call(target, "get_name", nil)
    local target_hp = safe_object_call(target, "get_health_percentage", 0)
    local ttd = safe_object_call(target, "time_to_die", 0)

    local in_range = false
    local max_range = 0

    -- Prefer IZI distance helpers documented in common/izi_sdk.lua.
    if target and target.distance then
        local dist = safe_object_call(target, "distance", nil)
        in_range = dist and dist < 40
        max_range = dist or 0
    end

    local threat = 0
    local threat_situation = 0  -- 0=none, 1=low, 2=medium, 3=tank/high
    local me = NS.GetPlayer and NS.GetPlayer() or nil
    if target and me then
        if target.get_threat_situation then
            local raw = safe_object_call(target, "get_threat_situation", 0, me)
            threat_situation = (type(raw) == "number" and raw) or 0
        end
        if target.get_threat_percentage then
            local raw_pct = safe_object_call(target, "get_threat_percentage", 0, me)
            threat = (type(raw_pct) == "number" and raw_pct) or 0
        elseif type(threat_situation) == "number" and threat_situation > 0 then
            threat = (threat_situation / 3) * 100
        end
    end

    return {
        name = target_name,
        hp = target_hp,
        ttd = ttd,
        in_range = in_range,
        max_range = max_range,
        threat = threat,
        threat_situation = threat_situation,
    }
end

local function get_combo_points()
    local me = NS.GetPlayer()
    if not me then return 0 end
    return safe_object_call(me, "combo_points_current", 0)
end

local function get_gcd_info()
    local izi = NS.izi
    local me = nil

    if izi and izi.me then
        me = izi.me()
    end

    local gcd = 1.5
    local gcd_rem = 0

    if me then
        gcd = safe_object_call(me, "gcd", 1.5) or 1.5
        gcd_rem = safe_object_call(me, "gcd_remains", 0) or 0
    else
        gcd = NS.get_global_cooldown() or 1.5
    end

    return { total = gcd, remaining = gcd_rem }
end

local function get_swing_timer()
    local me = NS.GetPlayer()
    if not me then return nil end
    local remains = NS.get_time_until_swing and NS.get_time_until_swing()
    if remains and remains > 0 then return remains end
    return nil  -- nil when unknown or no swing pending
end

local function get_active_playstyle()
    local class_config = NS.rotation_registry and NS.rotation_registry.class_config
    if class_config and class_config.dashboard and class_config.dashboard.get_active_playstyle then
        local context = NS.GetCurrentContext and NS.GetCurrentContext()
        return class_config.dashboard.get_active_playstyle(context)
    end
    return "combat"
end

local function get_cooldowns()
    local me = NS.GetPlayer()
    if not me then return EMPTY_TABLE end

    for i = 1, _cd_buffer.n do _cd_buffer[i] = nil end
    _cd_buffer.n = 0

    local cd_config = dashboard_config.cooldowns

    for i, cd in ipairs(cd_config) do
        local remaining = 0
        if NS.cooldown_remains then remaining = NS.cooldown_remains(cd.id) or 0 end
        _cd_buffer.n = _cd_buffer.n + 1
        _cd_buffer[_cd_buffer.n] = { id = cd.id, remaining = remaining, name = cd.name or "CD" }
    end

    return _cd_buffer
end

local function get_buffs()
    local me = NS.GetPlayer()
    if not me then return EMPTY_TABLE end

    for i = 1, _buff_buffer.n do _buff_buffer[i] = nil end
    _buff_buffer.n = 0

    local buff_config = dashboard_config.buffs

    for i, buff in ipairs(buff_config) do
        local duration = 0
        duration = NS.buff_remains and NS.buff_remains(me, buff.id) or 0
        _buff_buffer.n = _buff_buffer.n + 1
        _buff_buffer[_buff_buffer.n] = { id = buff.id, duration = duration }
    end

    return _buff_buffer
end

local function get_debuffs()
    local context = NS.GetCurrentContext and NS.GetCurrentContext()
    if not context or not context.target then return EMPTY_TABLE end

    for i = 1, _debuff_buffer.n do _debuff_buffer[i] = nil end
    _debuff_buffer.n = 0

    local target = context.target
    local debuff_config = dashboard_config.debuffs

    for i, debuff in ipairs(debuff_config) do
        local duration = 0
        duration = NS.debuff_remains and NS.debuff_remains(target, debuff.id) or 0
        _debuff_buffer.n = _debuff_buffer.n + 1
        _debuff_buffer[_debuff_buffer.n] = { id = debuff.id, duration = duration, name = debuff.name or "DoT" }
    end

    return _debuff_buffer
end

local function get_custom_lines()
    local custom_config = dashboard_config.custom_lines
    if not custom_config then return EMPTY_TABLE end

    for i = 1, _custom_buffer.n do _custom_buffer[i] = nil end
    _custom_buffer.n = 0

    for i, line in ipairs(custom_config) do
        if type(line) == "function" then
            local result = line()
            if result then
                _custom_buffer.n = _custom_buffer.n + 1
                _custom_buffer[_custom_buffer.n] = result
            end
        elseif type(line) == "string" then
            _custom_buffer.n = _custom_buffer.n + 1
            _custom_buffer[_custom_buffer.n] = line
        end
    end

    return _custom_buffer
end

local function get_sweep_dot_position()
    if not energy_tick_tracker.confident then return -1 end

    local current_time = NS.time_now and NS.time_now() or 0
    local elapsed = current_time - energy_tick_tracker.last_tick_time
    local frac = (elapsed % ENERGY_TICK_INTERVAL) / ENERGY_TICK_INTERVAL
    return frac
end

local function calculate_content_height(res, target, cooldowns, buffs, debuffs, custom_lines, hist_count, cp, class_name, gcd_info, swing_timer, context)
    local height = 0

    height = height + 30

    height = height + 12 + 12

    height = height + 12 + 12

    if class_name == "Rogue" or class_name == "Druid" then
        height = height + 12
    end

    height = height + 12

    local has_gcd = gcd_info and gcd_info.total > 0 and gcd_info.remaining > 0
    local has_swing = swing_timer and swing_timer > 0
    if has_gcd then height = height + 12 end
    if has_swing then height = height + 12 end

    height = height + 12

    height = height + 12

    local history_lines = math.max(MIN_HISTORY_LINES, math.min(hist_count, MAX_HISTORY_LINES))
    height = height + (history_lines * 12)

    height = height + 12

    if #cooldowns > 0 then height = height + 24 end
    if #buffs > 0 then height = height + 24 end
    if #debuffs > 0 and target.name then height = height + 24 end

    -- [#enhancement] DoT tracker rows: header + one row per active DoT with remaining time
    if #debuffs > 0 and target.name then
        local dot_rows = 0
        for i = 1, #debuffs do
            if debuffs[i].duration > 0 then dot_rows = dot_rows + 1 end
        end
        if dot_rows > 0 then
            height = height + 12 + (dot_rows * DOT_LABEL_HEIGHT)
        end
    end

    if #custom_lines > 0 then
        height = height + 12 + (#custom_lines * 12)
    end

    height = height + 12

    if target.name then
        height = height + 12
        if target.ttd > 0 or (target.max_range and target.max_range < 1000) then
            height = height + 12
        end
        if target.threat and type(target.threat) == "number" and target.threat > 0 then
            height = height + 24
        end
    end

    return height + 40
end

local function update_dashboard(context)
    if not dashboard_window or not dashboard_window:is_being_shown() then return end

    local me = NS.GetPlayer()
    if not me then return end

    ensure_player_guid()

    local class_name = safe_object_call(me, "get_class", "Warrior")
    local class_hex = CLASS_HEX[class_name] or "6c63ff"

    local res = get_player_resources()
    local target = get_target_info()
    local cp = get_combo_points()
    local gcd_info = get_gcd_info()
    local swing_timer = get_swing_timer()
    local cooldowns = get_cooldowns()
    local buffs = get_buffs()
    local debuffs = get_debuffs()
    local custom_lines = get_custom_lines()

    local active_ps = get_active_playstyle()

    local calculated_height = calculate_content_height(res, target, cooldowns, buffs, debuffs, custom_lines, history_count, cp, class_name, gcd_info, swing_timer, context)

    if dashboard_content_height ~= calculated_height then
        dashboard_content_height = calculated_height
        dashboard_window:set_initial_size(vec2.new(FRAME_WIDTH, calculated_height))
    end

    local bar_max = FRAME_WIDTH - 18

    local function add_text(text, text_color)
        text_color = text_color or THEME.text
        dashboard_window:add_text_on_dynamic_pos(text_color, text)
        dashboard_window:draw_next_dynamic_widget_on_new_line()
    end

    local function add_sep()
        dashboard_window:add_separator(-FRAME_WIDTH + 20, 0, 0, 0, THEME.border)
        dashboard_window:draw_next_dynamic_widget_on_new_line()
    end

    local function render_bar(width, height, bar_color)
        if width < 1 then width = 1 end
        bar_color = bar_color or RENDER_COLORS.bar_bg
        local bar_min = vec2.new(0, 0)
        local bar_max_vec = vec2.new(width, height)
        dashboard_window:render_rect_filled(bar_min, bar_max_vec, RENDER_COLORS.bar_bg, 0)
        dashboard_window:render_rect(bar_min, bar_max_vec, bar_color, 1)
    end

    local accent_hex = "6c63ff"
    local ps_display = active_ps:sub(1, 1):upper() .. active_ps:sub(2)
    local title_text = format("|cff%s%s \xC2\xB6 |cff%s%s",
        class_hex, class_name, accent_hex, ps_display)
    add_text(title_text, THEME.text)

    local class_stripe_color = CLASS_RGB[class_name] or CLASS_RGB.Warrior
    local stripe_min = vec2.new(0, 0)
    local stripe_max = vec2.new(2, FRAME_HEIGHT)
    dashboard_window:render_rect_filled(stripe_min, stripe_max, class_stripe_color, 0)

    -- [#enhancement] Burst Window Indicator: green square at top-right when should_burst is true
    if context and context.should_burst then
        local burst_min = vec2.new(FRAME_WIDTH - BURST_INDICATOR_SIZE - 8, 4)
        local burst_max = vec2.new(FRAME_WIDTH - 8, BURST_INDICATOR_SIZE + 4)
        dashboard_window:render_rect_filled(burst_min, burst_max, RENDER_COLORS.burst_green, 0)
        dashboard_window:render_rect(burst_min, burst_max, RENDER_COLORS.icon_white, 1)
        add_text("BURST", RENDER_COLORS.burst_green)
    end

    add_sep()

    local bar_height = 12

    local hp_fill_pct = res.hp_pct / 100
    local hp_bar_width = bar_max * hp_fill_pct
    render_bar(hp_bar_width, bar_height, THEME.resource_hp)
    dashboard_window:draw_next_dynamic_widget_on_new_line()
    add_text(format("HP: %.0f%%", res.hp_pct), THEME.text)

    local resource_type  -- assigned in all branches below (initial nil unused)
    local resource_value   -- assigned in all branches below (initial 0 unused)
    local resource_max = 100

    if class_name == "Rogue" or class_name == "Druid" then
        resource_type = "energy"
        resource_value = res.energy
        resource_max = res.energy_max
    elseif class_name == "Warrior" then
        resource_type = "rage"
        resource_value = res.rage
    else
        resource_type = "mana"
        resource_value = res.mana_pct
    end

    local res_color = RESOURCE_COLORS[resource_type] or RESOURCE_COLORS.mana
    local res_fill_pct = resource_type == "mana" and resource_value / 100 or resource_value / resource_max
    local res_bar_width = bar_max * res_fill_pct

    render_bar(res_bar_width, bar_height, res_color)
    dashboard_window:draw_next_dynamic_widget_on_new_line()

    if resource_type == "energy" then
        local label = format("Energy: %d", resource_value)
        add_text(label, THEME.text)

        if resource_value < resource_max and energy_tick_tracker.confident then
            local next_tick = resource_value + 20
            if next_tick > resource_max then next_tick = resource_max end
            local tick_x = (bar_max - 1) * (next_tick / resource_max)
            local tick_min = vec2.new(tick_x, 0)
            local tick_max = vec2.new(tick_x + 1, bar_height)
            dashboard_window:render_rect(tick_min, tick_max, RENDER_COLORS.energy_tick, 1)

            local sweep_frac = get_sweep_dot_position()
            if sweep_frac >= 0 then
                local sweep_x = (bar_max - 2) * sweep_frac + 1
                local sweep_min = vec2.new(sweep_x, 0)
                local sweep_max = vec2.new(sweep_x + 2, bar_height)
                dashboard_window:render_rect_filled(sweep_min, sweep_max, RENDER_COLORS.energy_sweep, 0)
            end
        end
    elseif resource_type == "rage" then
        add_text(format("Rage: %d", resource_value), THEME.text)
    else
        add_text(format("Mana: %.0f%%", resource_value), THEME.text)

        if res.energy and res.energy_max and res.energy > 0 then
            local secondary_fill_pct = res.energy / res.energy_max
            local secondary_bar_width = bar_max * secondary_fill_pct
            if secondary_bar_width > 1 then
                local sec_bar_min = vec2.new(0, -2)
                local sec_bar_max_vec = vec2.new(secondary_bar_width, bar_height - 2)
                dashboard_window:render_rect_filled(sec_bar_min, sec_bar_max_vec, RENDER_COLORS.secondary_bar_bg, 0)
                dashboard_window:render_rect(sec_bar_min, sec_bar_max_vec, THEME.resource_energy, 1)
                dashboard_window:draw_next_dynamic_widget_on_new_line()
                add_text(format("Energy: %d", res.energy), THEME.text_dim)
            end
        end
    end

    if class_name == "Rogue" or class_name == "Druid" then
        local pip_size = 8
        local pip_gap = 3
        local max_pips = 5

        add_text("CP", THEME.text_dim)

        for i = 1, max_pips do
            local pip_x = (i - 1) * (pip_size + pip_gap)
            local pip_min = vec2.new(pip_x, 0)
            local pip_max = vec2.new(pip_x + pip_size, pip_size)

            if i <= cp then
                dashboard_window:render_rect_filled(pip_min, pip_max, RENDER_COLORS.pip_filled, 0)
                dashboard_window:render_rect(pip_min, pip_max, RENDER_COLORS.pip_filled_border, 1)
            else
                dashboard_window:render_rect_filled(pip_min, pip_max, RENDER_COLORS.pip_empty, 0)
                dashboard_window:render_rect(pip_min, pip_max, RENDER_COLORS.pip_empty_border, 1)
            end
        end
        dashboard_window:draw_next_dynamic_widget_on_new_line()
    end

    add_sep()

    local timer_bar_height = 8

    local gcd_pct = gcd_info.total > 0 and gcd_info.remaining > 0 and (gcd_info.remaining / gcd_info.total) or 0
    if gcd_pct > 1 then gcd_pct = 1 end
    if gcd_pct > 0 then
        local gcd_bar_width = bar_max * gcd_pct
        render_bar(gcd_bar_width, timer_bar_height, THEME.accent)
        dashboard_window:draw_next_dynamic_widget_on_new_line()
        add_text(format("GCD: %.1f", gcd_info.remaining), THEME.text_dim)
    end

    if swing_timer then
        -- [#swing] Swing timer bar: fill shows elapsed progress (1 - remains/period).
        -- swing_timer is seconds until next swing; bar fills from left as swing approaches.
        local swing_period = (NS.swing_period and NS.swing_period()) or ESTIMATED_SWING_PERIOD
        local swing_fill = math.max(0, 1 - (swing_timer / swing_period))
        if swing_fill > 1 then swing_fill = 1 end
        local swing_bar_width = bar_max * swing_fill
        render_bar(swing_bar_width, SWING_BAR_HEIGHT, THEME.accent)
        dashboard_window:draw_next_dynamic_widget_on_new_line()
        add_text(format("Swing: %.1f", swing_timer), THEME.text_dim)
    end

    add_sep()

    -- Burst Window Indicator
    if context and context.should_burst then
        local burst_min = vec2.new(0, 0)
        local burst_max = vec2.new(BURST_INDICATOR_SIZE, BURST_INDICATOR_SIZE)
        dashboard_window:render_rect_filled(burst_min, burst_max, RENDER_COLORS.burst_active, 0)
        dashboard_window:draw_next_dynamic_widget_on_new_line()
        add_text("BURST", RENDER_COLORS.burst_active)
        add_sep()
    end

    local la = last_action
    if la and la.name then
        local priority_text = format("|cff%sPriority  > %s", accent_hex, la.name)
        add_text(priority_text, THEME.text)
    else
        local priority_text = format("|cff%sPriority  Idle", accent_hex)
        add_text(priority_text, THEME.text_dim)
    end

    add_sep()

    add_text("Recent", THEME.text_dim)

    local win_pos = dashboard_window:get_position()
    local _ = FRAME_WIDTH - 16  -- win_w unused: icon positioning uses win_pos directly
    local icon_y = -80

    for i = 1, math.min(history_count, MAX_HISTORY) do
        local entry = action_history[i]
        if entry.spell_id then
            local col = (i - 1) % ICONS_PER_ROW
            local row = math.floor((i - 1) / ICONS_PER_ROW)
            local icon_x = ICON_X + col * (ICON_SIZE + ICON_GAP)
            local screen_y_pos = icon_y - row * (ICON_SIZE + ICON_GAP)

            icons:draw_spell_icon(
                entry.spell_id,
                vec2.new(win_pos.x + 8 + icon_x, win_pos.y + screen_y_pos),
                ICON_SIZE,
                ICON_SIZE,
                RENDER_COLORS.icon_white,
                false,
                { size = "medium", persist_to_disk = true }
            )

            check_icon_hover(i, entry.spell_id, entry.name, icon_x, screen_y_pos)
        end
    end

    icon_y = icon_y - (math.ceil(MAX_HISTORY / ICONS_PER_ROW) * (ICON_SIZE + ICON_GAP)) - 10

    if #cooldowns > 0 then
        add_text("Cooldowns", THEME.text_dim)

        for i, cd in ipairs(cooldowns) do
            local col = (i - 1) % ICONS_PER_ROW
            local row = math.floor((i - 1) / ICONS_PER_ROW)
            local icon_x = ICON_X + col * (ICON_SIZE + ICON_GAP)
            local screen_y_pos = icon_y - row * (ICON_SIZE + ICON_GAP)

            local border_color = RENDER_COLORS.cd_border_off
            if cd.remaining <= 0 then
                border_color = RENDER_COLORS.cd_border_ready
            elseif cd.remaining > 0 then
                border_color = RENDER_COLORS.cd_border_on
            end

            icons:draw_spell_icon(
                cd.id,
                vec2.new(win_pos.x + 8 + icon_x, win_pos.y + screen_y_pos),
                ICON_SIZE,
                ICON_SIZE,
                border_color,
                false,
                { size = "medium", persist_to_disk = true }
            )

            check_icon_hover(100 + i, cd.id, cd.name or "Cooldown", icon_x, screen_y_pos)
        end

        local cd_rows = math.ceil(#cooldowns / ICONS_PER_ROW)
        icon_y = icon_y - (cd_rows * (ICON_SIZE + ICON_GAP)) - 5
    end

    if #buffs > 0 then
        add_text("Buffs", THEME.text_dim)

        for i, buff in ipairs(buffs) do
            local col = (i - 1) % ICONS_PER_ROW
            local row = math.floor((i - 1) / ICONS_PER_ROW)
            local icon_x = ICON_X + col * (ICON_SIZE + ICON_GAP)
            local screen_y_pos = icon_y - row * (ICON_SIZE + ICON_GAP)

            local border_color = RENDER_COLORS.buff_border
            if buff.duration > 0 and buff.duration < 3 then
                border_color = RENDER_COLORS.buff_border_expiring
            end

            icons:draw_spell_icon(
                buff.id,
                vec2.new(win_pos.x + 8 + icon_x, win_pos.y + screen_y_pos),
                ICON_SIZE,
                ICON_SIZE,
                border_color,
                false,
                { size = "medium", persist_to_disk = true }
            )

            check_icon_hover(200 + i, buff.id, "Buff", icon_x, screen_y_pos)
        end

        local buff_rows = math.ceil(#buffs / ICONS_PER_ROW)
        icon_y = icon_y - (buff_rows * (ICON_SIZE + ICON_GAP)) - 5
    end

    if #debuffs > 0 and target.name then
        add_text("Debuffs", THEME.text_dim)

        for i, debuff in ipairs(debuffs) do
            local col = (i - 1) % ICONS_PER_ROW
            local row = math.floor((i - 1) / ICONS_PER_ROW)
            local icon_x = ICON_X + col * (ICON_SIZE + ICON_GAP)
            local screen_y_pos = icon_y - row * (ICON_SIZE + ICON_GAP)

            local border_color = RENDER_COLORS.debuff_border
            if debuff.duration > 0 and debuff.duration < 3 then
                border_color = RENDER_COLORS.debuff_border_expiring
            end

            icons:draw_spell_icon(
                debuff.id,
                vec2.new(win_pos.x + 8 + icon_x, win_pos.y + screen_y_pos),
                ICON_SIZE,
                ICON_SIZE,
                border_color,
                false,
                { size = "medium", persist_to_disk = true }
            )

            check_icon_hover(300 + i, debuff.id, "Debuff", icon_x, screen_y_pos)
        end

        -- [#enhancement] Active DoT Tracker: show remaining duration text for each active DoT
        local in_combat = context and context.in_combat
        local has_valid_enemy = target and target.name and target.hp > 0
        if in_combat and has_valid_enemy then
            local active_dot_count = 0
            for i = 1, #debuffs do
                if debuffs[i].duration > 0 then
                    active_dot_count = active_dot_count + 1
                end
            end
            if active_dot_count > 0 then
                add_text("DoTs", THEME.text_dim)
                for i = 1, #debuffs do
                    local deb = debuffs[i]
                    if deb.duration > 0 then
                        local dot_color = THEME.text
                        if deb.duration < 3 then
                            dot_color = RENDER_COLORS.dot_expiring
                        end
                        add_text(format("%s: %.1fs", deb.name, deb.duration), dot_color)
                    end
                end
            end
        end
    end

    if #custom_lines > 0 then
        add_sep()
        for i, line in ipairs(custom_lines) do
            if line then
                add_text(tostring(line), THEME.text)
            end
        end
    end

    add_sep()

    if target.name then
        local target_text = format("|cff%sTarget  %s", accent_hex, target.name)
        add_text(target_text, THEME.text)

        local stats_text = ""
        if target.ttd > 0 then
            stats_text = format("TTD: %s", format_timer(target.ttd))
        end
        if target.max_range and target.max_range < 1000 then
            if stats_text ~= "" then stats_text = stats_text .. "  " end
            stats_text = stats_text .. format("%.0fyd", target.max_range)
        end
        if stats_text ~= "" then
            add_text(stats_text, THEME.text_dim)
        end

        -- [#enhancement] Threat Bar: uses threat_situation for coloring, combat-gated
        local in_combat = context and context.in_combat
        if in_combat and target.threat and type(target.threat) == "number" and target.threat > 0 then
            local threat_pct = target.threat
            threat_pct = (type(threat_pct) == "number" and threat_pct) or 0
            local threat_capped = threat_pct > 130 and 130 or threat_pct
            local threat_bar_width = bar_max * (threat_capped / 130)

            local threat_color = RENDER_COLORS.threat_low
            local threat_sit = (type(target.threat_situation) == "number" and target.threat_situation) or 0
            if threat_sit >= 3 then
                threat_color = RENDER_COLORS.threat_high
            elseif threat_sit >= 2 then
                threat_color = RENDER_COLORS.threat_medium
            end

            render_bar(threat_bar_width, THREAT_BAR_HEIGHT, threat_color)
            dashboard_window:draw_next_dynamic_widget_on_new_line()
            add_text(format("Threat: %.0f%%", threat_pct), THEME.text_dim)
        end
    else
        local target_text = format("|cff%sTarget  N/A", accent_hex)
        add_text(target_text, THEME.text_dim)
    end

    local current_time = NS.time_now and NS.time_now() or 0
    if res.stance ~= energy_tick_tracker.last_stance then
        energy_tick_tracker.last_stance = res.stance
        energy_tick_tracker.stance_change_at = current_time
        energy_tick_tracker.confident = false
    end

    local delta_e = res.energy - energy_tick_tracker.last_energy
    if delta_e > 0 and delta_e <= 25 and (current_time - energy_tick_tracker.stance_change_at) > 1.0 then
        energy_tick_tracker.last_tick_time = current_time
        energy_tick_tracker.confident = true
    end
    energy_tick_tracker.last_energy = res.energy
end

local function render_dashboard()
    if not dashboard_visible or not dashboard_window then return end

    local pos = dashboard_window:get_position()
    if pos and last_dashboard_pos then
        if pos.x ~= last_dashboard_pos.x or pos.y ~= last_dashboard_pos.y then
            save_dashboard_position()
        end
    end
    if pos then
        last_dashboard_pos = vec2.new(pos.x, pos.y)
    end

    dashboard_window:begin(
        enums.window_enums.window_resizing_flags.RESIZE_BOTH_AXIS,
        true,
        THEME.bg,
        THEME.border,
        enums.window_enums.window_cross_visuals.BLUE_THEME,
        enums.window_enums.window_behaviour_flags.ALWAYS_AUTO_RESIZE,
        function()
            local ok = pcall(function()
                update_dashboard(NS.GetCurrentContext and NS.GetCurrentContext() or nil)
            end)
            if not ok then
                -- Dashboard render error suppressed (pcall caught it).
                -- Core issue: Sylvanas API returns tables for get_threat_situation/get_threat_percentage.
                -- Fixed on disk (type guards), but if old code loaded, pcall prevents crash flood.
            end
        end
    )
end

function NS.toggle_dashboard()
    if not dashboard_window then
        dashboard_window = create_dashboard_window()
    end

    dashboard_visible = not dashboard_visible
    dashboard_window:set_visibility(dashboard_visible)

    if dashboard_visible then
        NS.log("Dashboard enabled")
    else
        NS.log("Dashboard disabled")
    end

    return dashboard_visible
end

function NS.SetDashboardConfig(config)
    if config.cooldowns then dashboard_config.cooldowns = config.cooldowns end
    if config.buffs then dashboard_config.buffs = config.buffs end
    if config.debuffs then dashboard_config.debuffs = config.debuffs end
    if config.custom_lines then dashboard_config.custom_lines = config.custom_lines end
end

NS.UpdateDashboard = function(context)
    -- Force a render (bypasses the visibility check for manual refresh)
    render_dashboard()
end

core.register_on_render_window_callback(function()
    if dashboard_visible and dashboard_window then
        render_dashboard()
    end
end)

core.register_on_spell_cast_callback(handle_spell_cast)

NS.log("Dashboard module loaded (full parity)")
return {
    toggle = NS.toggle_dashboard,
    update = NS.UpdateDashboard,
    set_config = NS.SetDashboardConfig,
    show = function()
        if not dashboard_window then dashboard_window = create_dashboard_window() end
        dashboard_visible = true
        dashboard_window:set_visibility(true)
    end,
    hide = function()
        if dashboard_window then dashboard_window:set_visibility(false) end
        dashboard_visible = false
    end,
    is_visible = function() return dashboard_visible end,
}
