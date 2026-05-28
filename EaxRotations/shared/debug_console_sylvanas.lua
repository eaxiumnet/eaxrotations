-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/debug_console_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- compact on-screen debug console.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local color = require("common/color")
local vec2 = require("common/geometry/vector_2")
local sdf = require("shared/sdf_render_sylvanas")

local M = {}

local CONSOLE_ID = "EaxRotationsDebugConsole"
local CONSOLE_WIDTH = 380
local CONSOLE_PADDING = 8
local CONSOLE_MARGIN = 16
local CONSOLE_HEADER_HEIGHT = 20
local CONSOLE_ROW_HEIGHT = 18
local CONSOLE_ICON_SIZE = 16

local THEME = {
    bg = color.new(10, 10, 14, 230),
    border = color.new(48, 48, 62, 255),
    text = color.new(230, 230, 236, 255),
    muted = color.new(170, 170, 186, 255),
    green = color.new(70, 200, 110, 255),
    yellow = color.new(235, 200, 75, 255),
    red = color.new(230, 80, 80, 255),
}

local console_visible = true
local toggle_keybind = nil
local frame_dump_control = nil
local last_key_state = false
local last_cast = { spell_id = nil, spell_name = nil, time = 0, status = "error" }
local last_frame_dump_log = 0
local warned_missing_graphics = false
local warned_missing_izi = false

local function now()
    return NS.time_now and NS.time_now() or 0
end

local function status_color(status)
    if status == "cast succeeded" then return THEME.green end
    if status == "condition false" then return THEME.yellow end
    return THEME.red
end

local function keybind_state(control, default)
    if not control then return default end
    local ok, value = pcall(function() return control:get_toggle_state() end)
    if ok and type(value) == "boolean" then return value end
    ok, value = pcall(function() return control:get_state() end)
    if ok and type(value) == "boolean" then return value end
    return default
end

local function control_state(control, default)
    if not control then return default end
    local ok, value = pcall(function() return control:get_state() end)
    if ok and type(value) == "boolean" then return value end
    return default
end

local function ensure_toggle()
    if toggle_keybind then return toggle_keybind end
    if not (NS.core and NS.core.menu and type(NS.core.menu.keybind) == "function") then return nil end
    toggle_keybind = NS.core.menu.keybind(120, false, "eaxrotations_debug_console_toggle")
    return toggle_keybind
end

local function ensure_frame_dump_control()
    if frame_dump_control then return frame_dump_control end
    if not (NS.core and NS.core.menu and type(NS.core.menu.checkbox) == "function") then return nil end
    local default_enabled = NS.get_setting and NS.get_setting("debug_frame_dump", false) or false
    frame_dump_control = NS.core.menu.checkbox(default_enabled, "debug_frame_dump")
    return frame_dump_control
end

local function frame_dump_enabled()
    local control = ensure_frame_dump_control()
    return control_state(control, NS.get_setting and NS.get_setting("debug_frame_dump", false) or false)
end

local function format_pct(value)
    if type(value) == "number" then
        return string.format("%.0f%%", value)
    end
    return "n/a"
end

local function format_number(value)
    if type(value) == "number" then
        return tostring(math.floor(value + 0.5))
    end
    return "n/a"
end

local function log_frame_dump(context)
    if not frame_dump_enabled() then return end

    local current_time = now()
    if (current_time - last_frame_dump_log) < 0.5 then return end
    last_frame_dump_log = current_time

    local me = (context and context.me) or (NS.GetPlayer and NS.GetPlayer()) or nil
    local target = (context and context.target) or (NS.GetTarget and NS.GetTarget()) or nil
    local playstyle = (context and context.active_playstyle) or (NS.get_setting and NS.get_setting("active_playstyle", "unknown")) or "unknown"
    local strategy = NS.current_strategy or "none"
    local mana = (context and (context.player_mana_pct or context.mana_pct)) or (me and NS.mana_pct and NS.mana_pct(me)) or 0
    local energy = (context and context.energy) or (NS.power_current and NS.power_current(NS.POWER_ENERGY)) or 0
    local rage = (context and context.rage) or (NS.power_current and NS.power_current(NS.POWER_RAGE)) or 0
    local target_hp = (context and context.target_hp) or (target and NS.unit_health_pct and NS.unit_health_pct(target)) or 100
    local gcd_remains = (context and context.gcd_remains) or (NS.gcd_remains and NS.gcd_remains()) or 0
    local gcd_status = gcd_remains > 0 and (string.format("%.1fs", gcd_remains)) or "ready"

    NS.log(string.format(
        "[FrameDump] playstyle=%s strategy=%s mana=%s energy=%s rage=%s target_hp=%s gcd=%s",
        tostring(playstyle),
        tostring(strategy),
        format_pct(mana),
        format_number(energy),
        format_number(rage),
        format_pct(target_hp),
        gcd_status
    ))
end

local function sync_toggle()
    local control = ensure_toggle()
    if not control then return end
    local current = keybind_state(control, false)
    if current and not last_key_state then
        console_visible = not console_visible
    end
    last_key_state = current
end

local function get_debuff_summary(context)
    if type(context) ~= "table" then
        return "n/a"
    end

    local preferred = { "debuff_remains", "debuff_remaining", "target_debuff_remains", "dot_remains" }
    for i = 1, #preferred do
        local key = preferred[i]
        local value = context[key]
        if type(value) == "number" then
            return key .. "=" .. string.format("%.1f", value)
        end
    end

    for key, value in pairs(context) do
        if type(value) == "number" then
            local name = tostring(key)
            if name:find("_remains", 1, true) or name:find("_remaining", 1, true) then
                return name .. "=" .. string.format("%.1f", value)
            end
        end
    end

    return "n/a"
end

local function draw_row(top_left, width, label, value, row_status, spell_id)
    local row_color = status_color(row_status)
    -- Use SDF smooth rect for row background
    sdf.smooth_rect(top_left.x, top_left.y, width, CONSOLE_ROW_HEIGHT, color.new(14, 14, 18, 220), 3, 1)
    -- Status indicator bar (left accent)
    sdf.smooth_rect(top_left.x, top_left.y, 4, CONSOLE_ROW_HEIGHT, row_color, 2, 1)

    local text_x = top_left.x + CONSOLE_PADDING
    if spell_id and NS.izi and type(NS.izi.draw_spell_icon) == "function" then
        NS.izi.draw_spell_icon(spell_id, vec2.new(text_x, top_left.y + 1), CONSOLE_ICON_SIZE, CONSOLE_ICON_SIZE, row_color, false)
        text_x = text_x + CONSOLE_ICON_SIZE + 6
    elseif spell_id and not warned_missing_izi then
        NS.log("[DebugConsole] izi.draw_spell_icon unavailable")
        warned_missing_izi = true
    end

    sdf.text(label .. ": " .. tostring(value), text_x, top_left.y + 3, 11, row_color)
end

local function update_last_cast(spell_id, data)
    if not spell_id then return end

    local me = NS.GetPlayer and NS.GetPlayer() or nil
    local caster = data and data.caster or nil
    if caster and me and NS.same_unit and not NS.same_unit(caster, me) then
        return
    end

    last_cast.spell_id = spell_id
    last_cast.spell_name = (data and data.spell_name) or (NS.get_spell_name and NS.get_spell_name(spell_id)) or tostring(spell_id)
    last_cast.time = now()
    last_cast.status = "cast succeeded"
end

local function render_console()
    sync_toggle()
    local context = NS.GetCurrentContext and NS.GetCurrentContext() or nil
    log_frame_dump(context)
    if not console_visible then return end

    local gfx = NS.core and NS.core.graphics
    if not gfx then
        if not warned_missing_graphics then
            NS.log("[DebugConsole] core.graphics unavailable")
            warned_missing_graphics = true
        end
        return
    end

    local screen = gfx.get_screen_size and gfx.get_screen_size() or nil
    if not screen then return end

    local playstyle = (context and context.active_playstyle) or (NS.get_setting and NS.get_setting("active_playstyle", "unknown")) or "unknown"
    local strategy = NS.current_strategy or "none"
    local strategy_status = NS.current_strategy_status or (strategy ~= "none" and "condition false" or "error")
    local state_color = status_color(strategy_status)

    local combo_points = (context and context.combo_points) or 0
    local energy = (context and context.energy) or (NS.power_current and NS.power_current(NS.POWER_ENERGY)) or 0
    local debuff_summary = get_debuff_summary(context)
    local last_spell = last_cast.spell_name or "none"
    local elapsed = last_cast.time > 0 and (now() - last_cast.time) or 0
    local last_cast_summary = last_cast.spell_id and (last_spell .. " @ " .. string.format("%.1fs", elapsed)) or "no cast recorded"

    local left = CONSOLE_MARGIN
    local top = screen.y - CONSOLE_MARGIN - (CONSOLE_HEADER_HEIGHT + (CONSOLE_ROW_HEIGHT * 4))
    local bg_height = CONSOLE_HEADER_HEIGHT + (CONSOLE_ROW_HEIGHT * 4)

    -- Drop shadow behind console
    sdf.drop_shadow(left - 4, top - 4, CONSOLE_WIDTH + 8, bg_height + 8, { 0, 0, 0, 100 }, 3, 3, 8, 12, 2)
    -- SDF border rect for console background with border
    sdf.border_rect(left, top, CONSOLE_WIDTH, bg_height, THEME.bg, THEME.border, 4, 1, 1)
    sdf.text("Debug Console  [F9]", left + CONSOLE_PADDING, top + 4, 12, THEME.text)

    draw_row(vec2.new(left, top + CONSOLE_HEADER_HEIGHT), CONSOLE_WIDTH, "Playstyle", playstyle, state_color)
    draw_row(vec2.new(left, top + CONSOLE_HEADER_HEIGHT + CONSOLE_ROW_HEIGHT), CONSOLE_WIDTH, "Strategy", strategy, strategy_status)
    draw_row(vec2.new(left, top + CONSOLE_HEADER_HEIGHT + (CONSOLE_ROW_HEIGHT * 2)), CONSOLE_WIDTH, "State", "CP " .. tostring(combo_points) .. " | Energy " .. tostring(energy) .. " | " .. debuff_summary, state_color)
    draw_row(vec2.new(left, top + CONSOLE_HEADER_HEIGHT + (CONSOLE_ROW_HEIGHT * 3)), CONSOLE_WIDTH, "Last Cast", last_cast_summary, last_cast.status or strategy_status, last_cast.spell_id)
end

function M.show()
    console_visible = true
end

function M.hide()
    console_visible = false
end

function M.toggle()
    console_visible = not console_visible
    return console_visible
end

function M.is_visible()
    return console_visible
end

function M.init()
    if not (NS.core and type(NS.core.register_on_render_callback) == "function") then
        NS.log("[DebugConsole] render callback API unavailable")
        return false
    end

    ensure_frame_dump_control()

    if NS.register_on_spell_cast then
        NS.register_on_spell_cast(function(spell_id, target, data)
            update_last_cast(spell_id, data)
        end)
    else
        NS.log("[DebugConsole] spell cast callback API unavailable")
    end

    NS.core.register_on_render_callback(render_console)
    NS.DebugConsole = M
    NS.log("Debug console module loaded")
    return true
end

M.init()

return M
