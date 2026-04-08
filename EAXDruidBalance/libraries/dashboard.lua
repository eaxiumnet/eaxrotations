--[[
    Dashboard Module for Sylvanas
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
    
    Usage:
        local dashboard = require("libraries/dashboard")
        dashboard.init(class_config)
        dashboard.set_enabled(true)
        
        -- In menu setup:
        dashboard.add_menu_items(menu, tree_node)
]]

local dashboard = {
    config = nil,           -- Class dashboard config
    enabled = false,
    position = {x = 20, y = 200},
    scale = 1.0,
    -- UI element caches
    cd_icons = {},
    buff_icons = {},
    debuff_icons = {},
    -- Update throttling
    _last_update = 0,
    _update_interval = 0.1,  -- 10Hz
    -- Cached data
    _cached_player = nil,
    _cached_target = nil,
    _cached_resources = {},
    _cached_cooldowns = {},
    _cached_buffs = {},
    _cached_debuffs = {},
    -- Phase 1: Smart Collapsing
    _smart_collapse = false,
    _section_visibility = {
        cooldowns = false,
        buffs = false,
        debuffs = false,
        action_history = false,
        timer_bars = false,
        combo_points = false,
        threat = false,
    },
    -- Phase 2: Timer Bars
    _timer_bars = {
        gcd = { active = false, remaining = 0, total = 1.5 },
        swing = { active = false, remaining = 0, total = 2.0 },
    },
    _show_timer_bars = false,
    -- Phase 3: Action History (CLEU Integration)
    ACTION_HISTORY_SIZE = 6,
    _action_history = {},  -- Ring buffer
    _history_count = 0,
    -- Phase 4: Energy Tick Tracker
    ENERGY_TICK_INTERVAL = 2.0,
    _energy_tick = {
        last_energy = 0,
        last_tick_time = 0,
        confident = false,
        last_stance = -1,
        stance_change_at = 0,
    },
    -- Phase 5: Combo Point Pips
    MAX_COMBO_POINTS = 5,
    _combo_points = 0,
    _show_combo_points = false,
    -- Phase 6: Threat Bar
    _threat = {
        percent = 0,
        has_target = false,
    },
    _show_threat_bar = false,
}


local FRAME_WIDTH = 170
local FRAME_HEIGHT_BASE = 80
local ICON_SIZE = 20
local ICON_GAP = 4
local BAR_HEIGHT = 16
local UPDATE_INTERVAL = 0.1  -- 10Hz


local THEME = {
    bg = {10, 12, 18, 190},
    border = {100, 80, 180, 180},
    header = {80, 70, 140, 220},
    text = {255, 255, 255, 255},
    text_dim = {180, 180, 180, 255},
    -- Resource colors
    rage = {180, 60, 60, 255},
    energy = {255, 220, 0, 255},
    mana = {60, 100, 180, 255},
    focus = {255, 140, 60, 255},
    runic = {60, 180, 220, 255},
    -- Status colors
    health = {180, 60, 60, 255},
    threat_high = {255, 50, 50, 255},
    threat_med = {255, 170, 50, 255},
    threat_low = {50, 230, 50, 255},
    -- Cooldown states
    cd_ready = {60, 180, 60, 255},
    cd_coming = {255, 180, 60, 255},
    cd_long = {180, 60, 60, 255},
    -- Accent color for timer bars
    accent = {100, 180, 255, 255},
}

-- API caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
-- FIX: get_target is a method on game_object, not in object_manager
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cooldown = core.spell_book.get_spell_cooldown
-- FIX: Graphics APIs use vec2 points and color tables, not individual values
local _rect_2d_filled = core.graphics.rect_2d_filled
local _rect_2d = core.graphics.rect_2d
local _text_2d = core.graphics.text_2d
-- Import vec2 and color for graphics (correct Sylvanas paths)
local vec2 = require("common/geometry/vector_2")
local color = require("common/color")
local buff_manager = require("common/modules/buff_manager")

-- Class validation helper to prevent cross-spec rendering conflicts
local function is_player_class_match()
    if not dashboard.config or not dashboard.config.class_id then
        return true  -- If no class_id set, allow (backward compatibility)
    end
    local player = _get_local_player()
    if not player then
        return false
    end
    local player_class = player:get_class()
    return player_class == dashboard.config.class_id
end

-- IZI SDK integration (optional)
local izi = nil
local function get_izi()
    if not izi then
        local success, result = pcall(require, "common/izi_sdk")
        if success then
            izi = result
        end
    end
    return izi
end


local function resolve_list(cfg, playstyle)
    if not cfg then
        return {}
    end
    
    -- If it's already a flat array, return it
    if #cfg > 0 then
        -- Check if elements are tables with 'id' field (new format)
        if type(cfg[1]) == "table" and cfg[1].id then
            local result = {}
            for i = 1, #cfg do
                if cfg[i].id then
                    table.insert(result, cfg[i].id)
                end
            end
            return result
        end
        -- Elements are raw IDs (old format)
        return cfg
    end
    
    -- If it's a playstyle-keyed table, resolve by playstyle
    if playstyle and cfg[playstyle] then
        return cfg[playstyle]
    end
    
    -- Try common playstyle keys
    for _, key in ipairs({"auto", "pve", "pvp", "default"}) do
        if cfg[key] then
            return cfg[key]
        end
    end
    
    return {}
end

local function resolve_value(cfg, playstyle, default)
    if cfg == nil then
        return default
    end
    
    -- Direct value
    if type(cfg) ~= "table" then
        return cfg
    end
    
    -- Playstyle-specific
    if playstyle and cfg[playstyle] ~= nil then
        return cfg[playstyle]
    end
    
    -- Try common keys
    for _, key in ipairs({"auto", "pve", "pvp", "default"}) do
        if cfg[key] ~= nil then
            return cfg[key]
        end
    end
    
    return default
end

-- Initialize with class config
function dashboard.init(class_config)
    dashboard.config = class_config or {}
    
    -- Phase 7: Read feature flags from class config
    dashboard._show_timer_bars = class_config.show_timer_bars or false
    dashboard._show_action_history = class_config.show_action_history or false
    dashboard._show_energy_tick = class_config.show_energy_tick or false
    dashboard._show_combo_points = class_config.show_combo_points or false
    dashboard._show_threat_bar = class_config.show_threat_bar or false
    dashboard._smart_collapse = class_config.enable_smart_collapse or false
    
    -- Pre-allocate icon caches based on config
    local cd_list = resolve_list(dashboard.config.cooldowns)
    dashboard.cd_icons = {}
    for i = 1, #cd_list do
        dashboard.cd_icons[i] = {
            spell_id = cd_list[i],
            ready = false,
            remaining = 0,
            charges = 0,
        }
    end
    
    -- Pre-allocate buff/debuff caches
    local buff_list = resolve_list(dashboard.config.buffs)
    dashboard.buff_icons = {}
    for i = 1, #buff_list do
        dashboard.buff_icons[i] = {
            spell_id = buff_list[i],
            active = false,
            remaining = 0,
            stacks = 0,
        }
    end
    
    local debuff_list = resolve_list(dashboard.config.debuffs)
    dashboard.debuff_icons = {}
    for i = 1, #debuff_list do
        dashboard.debuff_icons[i] = {
            spell_id = debuff_list[i],
            active = false,
            remaining = 0,
            stacks = 0,
        }
    end
    
    -- Initialize cached resources
    dashboard._cached_resources = {
        current = 0,
        max = 100,
        pct = 0,
        type = "mana",
    }
    
    dashboard._cached_cooldowns = {}
    dashboard._cached_buffs = {}
    dashboard._cached_debuffs = {}
    
    -- Phase 3: Initialize action history ring buffer
    for i = 1, dashboard.ACTION_HISTORY_SIZE do
        dashboard._action_history[i] = { spell_id = nil, cast_time = 0 }
    end
    dashboard._history_count = 0
end

-- Enable/disable
function dashboard.set_enabled(state)
    dashboard.enabled = state
end

-- Set position
function dashboard.set_position(x, y)
    dashboard.position.x = x or dashboard.position.x
    dashboard.position.y = y or dashboard.position.y
end

-- Set scale
function dashboard.set_scale(scale)
    dashboard.scale = scale or 1.0
end

-- Set opacity
function dashboard.set_opacity(opacity)
    dashboard.opacity = opacity or 190
end

-- Phase 1: Set smart collapsing enabled/disabled
function dashboard.set_smart_collapse(enabled)
    dashboard._smart_collapse = enabled
end

-- Phase 2: Set timer bars visibility
function dashboard.set_show_timer_bars(show)
    dashboard._show_timer_bars = show
end

-- Phase 5: Set combo points visibility
function dashboard.set_show_combo_points(show)
    dashboard._show_combo_points = show
end

-- Phase 6: Set threat bar visibility
function dashboard.set_show_threat_bar(show)
    dashboard._show_threat_bar = show
end

-- Get resource color based on type
local function get_resource_color(resource_type)
    if resource_type == "rage" then
        return THEME.rage
    elseif resource_type == "energy" then
        return THEME.energy
    elseif resource_type == "focus" then
        return THEME.focus
    elseif resource_type == "runic" then
        return THEME.runic
    else
        return THEME.mana
    end
end

-- Resource type to power ID mapping (WoW PowerType enum)
local RESOURCE_POWER_IDS = {
    mana = 0,
    rage = 1,
    focus = 2,
    energy = 3,
    runic = 6,
}

-- Update resource data
local function update_resources(player)
    if not player then
        return
    end
    
    local resource_type = dashboard.config.resource_type or "mana"
    local power_id = RESOURCE_POWER_IDS[resource_type] or 0
    local current = player:get_power(power_id) or 0
    local max = player:get_max_power(power_id) or 100
    
    dashboard._cached_resources.current = current
    dashboard._cached_resources.max = max
    dashboard._cached_resources.pct = max > 0 and (current / max) or 0
    dashboard._cached_resources.type = resource_type
    
    -- Phase 4: Energy tick detection
    if dashboard._show_energy_tick and resource_type == "energy" then
        local now = _core_time()
        local tick = dashboard._energy_tick
        
        -- Detect stance changes using pcall for safety
        local current_stance = -1
        if player.get_shapeshift_form then
            local ok, stance = pcall(function() return player:get_shapeshift_form() end)
            if ok then current_stance = stance end
        end
        
        if current_stance ~= tick.last_stance then
            tick.last_stance = current_stance
            tick.stance_change_at = now
            tick.confident = false
        end
        
        -- Detect tick: increase of 1-25 energy, outside 1s grace period
        local delta = current - tick.last_energy
        local grace_over = (now - tick.stance_change_at) > 1.0
        if delta > 0 and delta <= 25 and grace_over then
            tick.last_tick_time = now
            tick.confident = true
        end
        tick.last_energy = current
    end
end

-- Update cooldown data
local function update_cooldowns()
    -- Safety check: ensure cd_icons is a table
    if type(dashboard.cd_icons) ~= "table" then
        dashboard.cd_icons = {}
        dashboard._section_visibility.cooldowns = false
        return
    end
    
    local has_visible = false
    for i, icon in ipairs(dashboard.cd_icons) do
        -- FIX: get_spell_cooldown returns NUMBER (remaining seconds), not a table
        local remaining = _get_spell_cooldown(icon.spell_id)
        if remaining then
            icon.remaining = tonumber(remaining) or 0
            icon.charges = 0  -- Sylvanas get_spell_cooldown doesn't return charges
            icon.ready = icon.remaining <= 0
        else
            icon.remaining = 0
            icon.charges = 0
            icon.ready = true
        end
        if icon.ready or icon.remaining > 0 then
            has_visible = true
        end
    end
    dashboard._section_visibility.cooldowns = has_visible
end

-- Update buff data
local function update_buffs(player)
    -- Validate player is a proper game object (not a number or nil)
    if not player or type(player) ~= "userdata" then
        dashboard._section_visibility.buffs = false
        return
    end
    
    -- Safety check: ensure buff_icons is a table
    if type(dashboard.buff_icons) ~= "table" then
        dashboard.buff_icons = {}
        dashboard._section_visibility.buffs = false
        return
    end
    
    local has_visible = false
    for i, icon in ipairs(dashboard.buff_icons) do
        -- pcall in case buff_manager fails
        local ok, buff_data = pcall(function()
            return buff_manager:get_buff_data(player, icon.spell_id)
        end)
        if ok and buff_data then
            icon.active = true
            icon.remaining = buff_data.remaining or 0
            icon.stacks = buff_data.stacks or 1
            has_visible = true
        else
            icon.active = false
            icon.remaining = 0
            icon.stacks = 0
        end
    end
    dashboard._section_visibility.buffs = has_visible
end

-- Update debuff data
local function update_debuffs(target)
    -- Safety check: ensure debuff_icons is a table
    if type(dashboard.debuff_icons) ~= "table" then
        dashboard.debuff_icons = {}
        dashboard._section_visibility.debuffs = false
        return
    end
    
    -- Validate target is a proper game object (not number/nil)
    if not target or type(target) ~= "userdata" then
        -- Clear all debuff icons when no valid target
        for i, icon in ipairs(dashboard.debuff_icons) do
            icon.active = false
            icon.remaining = 0
            icon.stacks = 0
        end
        dashboard._section_visibility.debuffs = false
        return
    end
    
    local has_visible = false
    for i, icon in ipairs(dashboard.debuff_icons) do
        -- pcall to protect against buff_manager errors
        local ok, debuff_data = pcall(function()
            return buff_manager:get_buff_data(target, icon.spell_id)
        end)
        if ok and debuff_data then
            icon.active = true
            icon.remaining = debuff_data.remaining or 0
            icon.stacks = debuff_data.stacks or 1
            has_visible = true
        else
            icon.active = false
            icon.remaining = 0
            icon.stacks = 0
        end
    end
    dashboard._section_visibility.debuffs = has_visible
end

-- Phase 2: Update timer bars (GCD + Swing)
local function update_timer_bars()
    if not dashboard._show_timer_bars then
        return
    end
    
    -- Update GCD
    local gcd_remaining = _get_gcd()
    if gcd_remaining and gcd_remaining > 0 then
        dashboard._timer_bars.gcd.active = true
        dashboard._timer_bars.gcd.remaining = gcd_remaining
    else
        dashboard._timer_bars.gcd.active = false
        dashboard._timer_bars.gcd.remaining = 0
    end
    
    -- Update Swing (placeholder - would need attack speed API)
    -- For now, just track if we have an active swing timer
    dashboard._timer_bars.swing.active = false
    dashboard._timer_bars.swing.remaining = 0
end

-- Phase 5: Update combo points
local function update_combo_points(player)
    if not dashboard._show_combo_points or not player then
        dashboard._section_visibility.combo_points = false
        return
    end
    local cp = 0
    if player.get_power then
        local ok, power = pcall(function() return player:get_power(4) end)  -- 4 = combo points
        if ok then cp = power end
    end
    dashboard._combo_points = cp
    dashboard._section_visibility.combo_points = cp > 0
end

-- Phase 6: Update threat data
local function update_threat(target)
    if not dashboard._show_threat_bar then
        dashboard._section_visibility.threat = false
        return
    end
    if not target then
        dashboard._threat.has_target = false
        dashboard._threat.percent = 0
        dashboard._section_visibility.threat = false
        return
    end
    local me = _get_local_player()
    if not me then
        dashboard._section_visibility.threat = false
        return
    end
    local threat_pct = 0
    if target.get_threat_situation then
        local ok, situation = pcall(function() return target:get_threat_situation(me) end)
        if ok and situation then
            threat_pct = situation.threat_percent or 0
        end
    end
    dashboard._threat.percent = threat_pct
    dashboard._threat.has_target = true
    dashboard._section_visibility.threat = threat_pct > 0
end

-- Phase 3: Spell cast handler for action history
local function on_spell_cast(event_data)
    if not event_data or not event_data.spell_id then return end
    
    -- Shift history (ring buffer)
    for i = dashboard.ACTION_HISTORY_SIZE, 2, -1 do
        dashboard._action_history[i] = dashboard._action_history[i-1]
    end
    dashboard._action_history[1] = { spell_id = event_data.spell_id, cast_time = _core_time() }
    dashboard._history_count = math.min(dashboard._history_count + 1, dashboard.ACTION_HISTORY_SIZE)
    dashboard._section_visibility.action_history = dashboard._history_count > 0
end

-- Main update function (called from render callback)
function dashboard.update()
    -- Skip if disabled
    if not dashboard.enabled then
        return
    end
    
    -- Throttle updates to 10Hz
    local now = _core_time()
    if now - dashboard._last_update < UPDATE_INTERVAL then
        return
    end
    dashboard._last_update = now
    
    -- Get player and target
    dashboard._cached_player = _get_local_player()
    -- FIX: get_target is a method on the player object
    if dashboard._cached_player and dashboard._cached_player.get_target then
        dashboard._cached_target = dashboard._cached_player:get_target()
    else
        dashboard._cached_target = nil
    end
    
    -- Update data
    update_resources(dashboard._cached_player)
    update_cooldowns()
    update_buffs(dashboard._cached_player)
    update_debuffs(dashboard._cached_target)
    update_timer_bars()
    update_combo_points(dashboard._cached_player)
    update_threat(dashboard._cached_target)
end

-- Draw a bar with background and fill
local function draw_bar(x, y, width, height, pct, fill_color, bg_color)
    local bg = bg_color or THEME.bg
    
    -- Background (using correct Sylvanas API: vec2 point, color object)
    _rect_2d_filled(vec2.new(x, y), width, height, color.new(bg[1], bg[2], bg[3], bg[4]), 0)
    
    -- Fill
    local fill_width = width * pct
    if fill_width > 0 then
        _rect_2d_filled(vec2.new(x, y), fill_width, height, color.new(fill_color[1], fill_color[2], fill_color[3], fill_color[4]), 0)
    end
    
    -- Border
    _rect_2d(vec2.new(x, y), width, height, color.new(THEME.border[1], THEME.border[2], THEME.border[3], THEME.border[4]), 1, 0)
end

-- Phase 2: Draw a timer bar (GCD/Swing)
local function draw_timer_bar(x, y, width, height, pct, fill_color, label, value_text, bg_color)
    local bg = bg_color or THEME.bg
    
    -- Background
    _rect_2d_filled(vec2.new(x, y), width, height, color.new(bg[1], bg[2], bg[3], bg[4]), 0)
    
    -- Fill based on pct
    local fill_width = width * math.max(0, math.min(1, pct))
    if fill_width > 0 then
        _rect_2d_filled(vec2.new(x, y), fill_width, height, color.new(fill_color[1], fill_color[2], fill_color[3], fill_color[4]), 0)
    end
    
    -- Label text
    if label then
        _text_2d(label, vec2.new(x + 2, y + 1), 8, color.new(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3], 200), false, 0)
    end
    
    -- Value text (optional)
    if value_text then
        local text_width = #value_text * 6  -- Approximate width
        _text_2d(value_text, vec2.new(x + width - text_width - 4, y + 1), 8, color.new(THEME.text[1], THEME.text[2], THEME.text[3], 200), false, 0)
    end
    
    -- Border
    _rect_2d(vec2.new(x, y), width, height, color.new(THEME.border[1], THEME.border[2], THEME.border[3], 180), 1, 0)
end

-- Phase 5: Draw a combo point pip
local function draw_combo_pip(x, y, size, active, scale)
    local fill_color = active and {200, 50, 50, 255} or {40, 40, 40, 200}
    local border_color = active and {150, 40, 40, 255} or {60, 60, 60, 255}
    _rect_2d_filled(vec2.new(x, y), size, size, color.new(fill_color[1], fill_color[2], fill_color[3], fill_color[4]), 0)
    _rect_2d(vec2.new(x, y), size, size, color.new(border_color[1], border_color[2], border_color[3], border_color[4]), 1, 0)
end

-- Phase 6: Draw threat bar
local function draw_threat_bar(x, y, width, height, threat_pct)
    local threat_color = THEME.threat_low
    if threat_pct >= 100 then
        threat_color = THEME.threat_high
    elseif threat_pct >= 80 then
        threat_color = THEME.threat_med
    end
    
    -- Background
    _rect_2d_filled(vec2.new(x, y), width, height, color.new(30, 30, 30, 200), 0)
    
    -- Fill
    local fill_pct = math.max(0, math.min(1, threat_pct / 100))
    local fill_width = width * fill_pct
    if fill_width > 0 then
        _rect_2d_filled(vec2.new(x, y), fill_width, height, color.new(threat_color[1], threat_color[2], threat_color[3], threat_color[4]), 0)
    end
    
    -- Label
    _text_2d("Threat:", vec2.new(x + 2, y + 1), 8, color.new(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3], 200), false, 0)
    
    -- Percentage text
    local pct_text = string.format("%.0f%%", threat_pct)
    local text_width = #pct_text * 6
    _text_2d(pct_text, vec2.new(x + width - text_width - 4, y + 1), 8, color.new(THEME.text[1], THEME.text[2], THEME.text[3], 200), false, 0)
    
    -- Border
    _rect_2d(vec2.new(x, y), width, height, color.new(THEME.border[1], THEME.border[2], THEME.border[3], 180), 1, 0)
end

-- Draw a spell icon
local function draw_spell_icon(x, y, size, spell_id, ready, remaining, izi_sdk)
    if izi_sdk and izi_sdk.draw_spell_icon then
        -- Use IZI SDK for icon rendering (correct signature: spell_id, position, width, height)
        izi_sdk.draw_spell_icon(spell_id, vec2.new(x, y), size, size)
    else
        -- Fallback: draw colored square (correct Sylvanas API)
        local icon_color = ready and THEME.cd_ready or THEME.cd_long
        _rect_2d_filled(vec2.new(x, y), size, size, color.new(icon_color[1], icon_color[2], icon_color[3], 200), 0)
    end
    
    -- Draw cooldown text if not ready
    if not ready and remaining > 0 then
        local text = string.format("%.1f", remaining)
        local text_pos = vec2.new(x + 2, y + size - 10)
        _text_2d(text, text_pos, 10, color.new(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4]), false, 0)
    end
    
    -- Border
    local border_color = ready and THEME.cd_ready or THEME.cd_long
    _rect_2d(vec2.new(x, y), size, size, color.new(border_color[1], border_color[2], border_color[3], border_color[4]), 1, 0)
end

-- Phase 3: Draw history icon with fade
local function draw_history_icon(x, y, size, spell_id, alpha, izi_sdk)
    if not spell_id then return end
    
    if izi_sdk and izi_sdk.draw_spell_icon then
        local tint = color.new(255, 255, 255, math.floor(alpha * 255))
        izi_sdk.draw_spell_icon(spell_id, vec2.new(x, y), size, size, tint)
    else
        local icon_color = {100, 180, 255, math.floor(alpha * 255)}
        _rect_2d_filled(vec2.new(x, y), size, size, color.new(icon_color[1], icon_color[2], icon_color[3], icon_color[4]), 0)
    end
    
    -- Border with matching alpha
    _rect_2d(vec2.new(x, y), size, size, color.new(THEME.border[1], THEME.border[2], THEME.border[3], math.floor(alpha * 180)), 1, 0)
end

-- Draw buff/debuff icon
local function draw_aura_icon(x, y, size, spell_id, active, remaining, stacks, izi_sdk)
    local alpha = active and 255 or 100
    
    if izi_sdk and izi_sdk.draw_spell_icon then
        -- Use IZI SDK (correct signature with vec2 position and optional tint color)
        local tint = color.new(255, 255, 255, alpha)
        izi_sdk.draw_spell_icon(spell_id, vec2.new(x, y), size, size, tint)
    else
        -- Fallback (correct Sylvanas API)
        local aura_color = active and THEME.cd_ready or THEME.text_dim
        _rect_2d_filled(vec2.new(x, y), size, size, color.new(aura_color[1], aura_color[2], aura_color[3], alpha), 0)
    end
    
    -- Draw stacks if > 1
    if active and stacks > 1 then
        local text = tostring(stacks)
        _text_2d(text, vec2.new(x + 2, y + 2), 10, color.new(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4]), false, 0)
    end
    
    -- Draw remaining time if active
    if active and remaining > 0 and remaining < 10 then
        local text = string.format("%.0f", remaining)
        _text_2d(text, vec2.new(x + 2, y + size - 10), 9, color.new(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4]), false, 0)
    end
end

-- Phase 4: Render energy tick sweep animation (called every frame)
local function render_energy_tick_sweep(x, y, width, height, scale)
    if not dashboard._show_energy_tick then return end
    if dashboard._cached_resources.type ~= "energy" then return end
    
    local tick = dashboard._energy_tick
    if not tick.confident then return end
    
    local now = _core_time()
    local time_since_tick = now - tick.last_tick_time
    local progress = time_since_tick / dashboard.ENERGY_TICK_INTERVAL
    
    if progress > 1 then return end
    
    -- Draw sweep dot moving across the resource bar
    local sweep_x = x + (width * progress)
    local dot_size = 4 * scale
    local dot_y = y + (height / 2) - (dot_size / 2)
    
    -- White sweep dot
    _rect_2d_filled(vec2.new(sweep_x, dot_y), dot_size, dot_size, color.new(255, 255, 255, 200), 0)
end

-- Render function (called every frame)
function dashboard.render()
    if not dashboard.enabled then
        return
    end
    
    local izi_sdk = get_izi()
    local x = dashboard.position.x
    local y = dashboard.position.y
    local scale = dashboard.scale
    local width = FRAME_WIDTH * scale
    
    -- Begin window (moveable by default)
    if core.graphics and core.graphics.begin_window then
        local window_flags = 0  -- No NO_MOVE flag = moveable by default
        core.graphics.begin_window("Combat Dashboard", vec2.new(x, y), vec2.new(width, height), window_flags)
    end
    
    -- Calculate dynamic height based on content
    local height = FRAME_HEIGHT_BASE * scale
    local cd_count = #dashboard.cd_icons
    local buff_count = #dashboard.buff_icons
    local debuff_count = #dashboard.debuff_icons
    
    -- Add height for cooldown row
    if cd_count > 0 then
        local cd_rows = math.ceil(cd_count / 6)
        height = height + (ICON_SIZE + ICON_GAP) * cd_rows * scale
    end
    
    -- Add height for buff/debuff rows
    if buff_count > 0 then
        height = height + (ICON_SIZE + ICON_GAP * 2) * scale
    end
    if debuff_count > 0 then
        height = height + (ICON_SIZE + ICON_GAP * 2) * scale
    end
    
    -- Phase 2: Add height for timer bars
    if dashboard._show_timer_bars then
        local timer_bar_height = 10 * scale
        if dashboard._timer_bars.gcd.active then
            height = height + timer_bar_height + ICON_GAP * scale
        end
        if dashboard._timer_bars.swing.active then
            height = height + timer_bar_height + ICON_GAP * scale
        end
    end
    
    -- Phase 3: Add height for action history
    if dashboard._show_action_history and dashboard._history_count > 0 then
        height = height + (ICON_SIZE + ICON_GAP * 2) * scale
    end
    
    -- Phase 5: Add height for combo points if visible
    if dashboard._section_visibility.combo_points then
        height = height + (ICON_SIZE + ICON_GAP * 2) * scale
    end
    
    -- Phase 6: Add height for threat bar if visible
    if dashboard._section_visibility.threat then
        height = height + (BAR_HEIGHT + ICON_GAP * 2) * scale
    end
    
    -- Draw panel background (correct Sylvanas API)
    _rect_2d_filled(vec2.new(x, y), width, height, color.new(THEME.bg[1], THEME.bg[2], THEME.bg[3], THEME.bg[4]), 0)
    
    -- Draw header
    local header_height = 20 * scale
    _rect_2d_filled(vec2.new(x, y), width, header_height, color.new(THEME.header[1], THEME.header[2], THEME.header[3], THEME.header[4]), 0)
    
    local class_name = dashboard.config.class_name or "Dashboard"
    _text_2d(class_name, vec2.new(x + 5 * scale, y + 4 * scale), 12 * scale, color.new(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4]), false, 0)
    
    local current_y = y + header_height + ICON_GAP * scale
    
    -- Draw resource bar
    local resource_pct = dashboard._cached_resources.pct or 0
    local resource_color = get_resource_color(dashboard._cached_resources.type)
    local bar_width = width - 10 * scale
    local bar_x = x + 5 * scale
    draw_bar(bar_x, current_y, bar_width, BAR_HEIGHT * scale, resource_pct, resource_color, {30, 30, 30, 200})
    
    -- Phase 4: Draw energy tick marker on resource bar
    if dashboard._show_energy_tick and dashboard._cached_resources.type == "energy" and dashboard._energy_tick.confident then
        local tick = dashboard._energy_tick
        local now = _core_time()
        local time_until_tick = dashboard.ENERGY_TICK_INTERVAL - (now - tick.last_tick_time)
        if time_until_tick > 0 then
            local tick_pct = time_until_tick / dashboard.ENERGY_TICK_INTERVAL
            local tick_x = bar_x + (bar_width * tick_pct)
            -- Draw vertical white line at predicted tick position
            _rect_2d_filled(vec2.new(tick_x, current_y), 2, BAR_HEIGHT * scale, color.new(255, 255, 255, 180), 0)
        end
    end
    
    -- Resource text
    local resource_text = string.format("%d / %d", dashboard._cached_resources.current, dashboard._cached_resources.max)
    _text_2d(resource_text, vec2.new(x + 8 * scale, current_y + 2 * scale), 10 * scale, color.new(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4]), false, 0)
    
    current_y = current_y + (BAR_HEIGHT + ICON_GAP * 2) * scale
    
    -- Phase 4: Render energy tick sweep animation
    render_energy_tick_sweep(bar_x, current_y - (BAR_HEIGHT + ICON_GAP * 2) * scale, bar_width, BAR_HEIGHT * scale, scale)
    
    -- Phase 2: Draw timer bars (GCD + Swing)
    if dashboard._show_timer_bars then
        local timer_bar_height = 10 * scale
        local timer_bar_width = width - 10 * scale
        
        -- GCD Bar
        if dashboard._timer_bars.gcd.active then
            local gcd_pct = dashboard._timer_bars.gcd.remaining / dashboard._timer_bars.gcd.total
            draw_timer_bar(x + 5 * scale, current_y, timer_bar_width, timer_bar_height, 
                1 - gcd_pct, THEME.accent, "GCD", 
                string.format("%.1f", dashboard._timer_bars.gcd.remaining),
                {30, 30, 30, 200})
            current_y = current_y + timer_bar_height + ICON_GAP * scale
        end
        
        -- Swing Bar (if active)
        if dashboard._timer_bars.swing.active then
            local swing_pct = dashboard._timer_bars.swing.remaining / dashboard._timer_bars.swing.total
            draw_timer_bar(x + 5 * scale, current_y, timer_bar_width, timer_bar_height,
                1 - swing_pct, THEME.energy, "Swing",
                string.format("%.1f", dashboard._timer_bars.swing.remaining),
                {30, 30, 30, 200})
            current_y = current_y + timer_bar_height + ICON_GAP * scale
        end
    end
    
    -- Draw cooldown icons
    if cd_count > 0 then
        local icons_per_row = 6
        local icon_size = ICON_SIZE * scale
        local gap = ICON_GAP * scale
        
        for i, icon in ipairs(dashboard.cd_icons) do
            local col = (i - 1) % icons_per_row
            local row = math.floor((i - 1) / icons_per_row)
            local icon_x = x + 5 * scale + col * (icon_size + gap)
            local icon_y = current_y + row * (icon_size + gap)
            
            draw_spell_icon(icon_x, icon_y, icon_size, icon.spell_id, icon.ready, icon.remaining, izi_sdk)
        end
        
        local cd_rows = math.ceil(cd_count / icons_per_row)
        current_y = current_y + cd_rows * (icon_size + gap) + gap
    end
    
    -- Phase 3: Draw action history
    if dashboard._show_action_history and dashboard._history_count > 0 then
        local icon_size = ICON_SIZE * scale
        local gap = ICON_GAP * scale
        
        _text_2d("History:", vec2.new(x + 5 * scale, current_y), 10 * scale, color.new(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3], THEME.text_dim[4]), false, 0)
        current_y = current_y + 12 * scale
        
        -- Fade values: 1.0, 0.88, 0.76, 0.64, 0.52, 0.40
        local fade_values = {1.0, 0.88, 0.76, 0.64, 0.52, 0.40}
        
        for i = 1, dashboard._history_count do
            local entry = dashboard._action_history[i]
            if entry and entry.spell_id then
                local icon_x = x + 5 * scale + (i - 1) * (icon_size + gap)
                local alpha = fade_values[i] or 0.40
                draw_history_icon(icon_x, current_y, icon_size, entry.spell_id, alpha, izi_sdk)
            end
        end
        
        current_y = current_y + icon_size + gap * 2
    end
    
    -- Draw buff icons
    if buff_count > 0 then
        local icon_size = ICON_SIZE * scale
        local gap = ICON_GAP * scale
        
        _text_2d("Buffs:", vec2.new(x + 5 * scale, current_y), 10 * scale, color.new(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3], THEME.text_dim[4]), false, 0)
        current_y = current_y + 12 * scale
        
        for i, icon in ipairs(dashboard.buff_icons) do
            local icon_x = x + 5 * scale + (i - 1) * (icon_size + gap)
            draw_aura_icon(icon_x, current_y, icon_size, icon.spell_id, icon.active, icon.remaining, icon.stacks, izi_sdk)
        end
        
        current_y = current_y + icon_size + gap * 2
    end
    
    -- Draw debuff icons
    if debuff_count > 0 then
        local icon_size = ICON_SIZE * scale
        local gap = ICON_GAP * scale
        
        _text_2d("Debuffs:", vec2.new(x + 5 * scale, current_y), 10 * scale, color.new(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3], THEME.text_dim[4]), false, 0)
        current_y = current_y + 12 * scale
        
        for i, icon in ipairs(dashboard.debuff_icons) do
            local icon_x = x + 5 * scale + (i - 1) * (icon_size + gap)
            draw_aura_icon(icon_x, current_y, icon_size, icon.spell_id, icon.active, icon.remaining, icon.stacks, izi_sdk)
        end
        
        current_y = current_y + icon_size + gap
    end
    
    -- Phase 5: Draw combo point pips
    if dashboard._section_visibility.combo_points then
        local pip_size = 12 * scale
        local gap = ICON_GAP * scale
        local total_width = dashboard.MAX_COMBO_POINTS * (pip_size + gap) - gap
        local start_x = x + (width - total_width) / 2
        
        _text_2d("CP:", vec2.new(x + 5 * scale, current_y), 10 * scale, color.new(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3], THEME.text_dim[4]), false, 0)
        current_y = current_y + 12 * scale
        
        for i = 1, dashboard.MAX_COMBO_POINTS do
            local pip_x = start_x + (i - 1) * (pip_size + gap)
            local active = i <= dashboard._combo_points
            draw_combo_pip(pip_x, current_y, pip_size, active, scale)
        end
        
        current_y = current_y + pip_size + gap
    end
    
    -- Phase 6: Draw threat bar
    if dashboard._section_visibility.threat then
        local threat_width = width - 10 * scale
        draw_threat_bar(x + 5 * scale, current_y, threat_width, BAR_HEIGHT * scale, dashboard._threat.percent)
        current_y = current_y + BAR_HEIGHT * scale + ICON_GAP * scale
    end
    
    -- End window
    if core.graphics and core.graphics.end_window then
        core.graphics.end_window()
    end
    
    -- Draw border around entire panel (correct Sylvanas API)
    _rect_2d(vec2.new(x, y), width, height, color.new(THEME.border[1], THEME.border[2], THEME.border[3], THEME.border[4]), 1, 0)
end

-- Register render callback (call once after loading)
function dashboard.register_render_callback()
    if core and core.register_on_render_callback then
        core.register_on_render_callback(function()
            -- Guard: Only render if player class matches this dashboard's config
            if not is_player_class_match() then
                return
            end
            if dashboard.enabled then
                dashboard.update()  -- 10Hz throttled
                dashboard.render()
            end
        end)
    end
    
    -- Phase 3: Register spell cast callback
    if core and core.register_on_spell_cast_callback then
        core.register_on_spell_cast_callback(on_spell_cast)
    end
end

-- Menu integration function
function dashboard.add_menu_items(menu, tree_node)
    if not menu or not tree_node then
        return
    end
    
    -- Dashboard toggle
    if menu.dashboard_enabled then
        tree_node:add_checkbox(
            (menu.dashboard_enabled.label and menu.dashboard_enabled.label:get()) or "Enable Dashboard",
            menu.dashboard_enabled:get_value()
        )
    end
    
    -- Position X slider
    if menu.dashboard_x then
        tree_node:add_slider(
            (menu.dashboard_x.label and menu.dashboard_x.label:get()) or "Position X",
            menu.dashboard_x:get_value(),
            0, 1000, 1
        )
    end
    
    -- Position Y slider
    if menu.dashboard_y then
        tree_node:add_slider(
            (menu.dashboard_y.label and menu.dashboard_y.label:get()) or "Position Y",
            menu.dashboard_y:get_value(),
            0, 1000, 1
        )
    end
    
    -- Scale slider
    if menu.dashboard_scale then
        tree_node:add_slider(
            (menu.dashboard_scale.label and menu.dashboard_scale.label:get()) or "Scale",
            menu.dashboard_scale:get_value(),
            0.5, 2.0, 0.1
        )
    end
    
    -- Theme color pickers (if available)
    if menu.dashboard_color_bg then
        tree_node:add_color_picker(
            (menu.dashboard_color_bg.label and menu.dashboard_color_bg.label:get()) or "Background Color",
            menu.dashboard_color_bg:get_value()
        )
    end
    
    if menu.dashboard_color_border then
        tree_node:add_color_picker(
            (menu.dashboard_color_border.label and menu.dashboard_color_border.label:get()) or "Border Color",
            menu.dashboard_color_border:get_value()
        )
    end
    
    -- Phase 7: Dashboard feature toggles
    if menu.show_timer_bars then
        tree_node:add_checkbox(
            (menu.show_timer_bars.label and menu.show_timer_bars.label:get()) or "Show Timer Bars",
            menu.show_timer_bars:get_value()
        )
    end
    
    if menu.show_action_history then
        tree_node:add_checkbox(
            (menu.show_action_history.label and menu.show_action_history.label:get()) or "Show Action History",
            menu.show_action_history:get_value()
        )
    end
    
    if menu.enable_smart_collapse then
        tree_node:add_checkbox(
            (menu.enable_smart_collapse.label and menu.enable_smart_collapse.label:get()) or "Smart Collapse",
            menu.enable_smart_collapse:get_value()
        )
    end
    
    -- Class-specific toggles (conditional)
    if menu.show_energy_tick then
        tree_node:add_checkbox(
            (menu.show_energy_tick.label and menu.show_energy_tick.label:get()) or "Show Energy Tick",
            menu.show_energy_tick:get_value()
        )
    end
    
    if menu.show_combo_points then
        tree_node:add_checkbox(
            (menu.show_combo_points.label and menu.show_combo_points.label:get()) or "Show Combo Points",
            menu.show_combo_points:get_value()
        )
    end
    
    if menu.show_threat_bar then
        tree_node:add_checkbox(
            (menu.show_threat_bar.label and menu.show_threat_bar.label:get()) or "Show Threat Bar",
            menu.show_threat_bar:get_value()
        )
    end
end

-- Auto-register on load (optional, can be disabled)
-- dashboard.register_render_callback()

return dashboard

