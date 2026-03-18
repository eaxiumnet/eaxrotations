-- esp_renderer.lua
-- In-world and on-screen visual overlay for EAX rotation plugins.
-- Shows next spell HUD, 3D target text, and proc bars.
-- v2.0.0 - Clean ASCII-only output, improved layout

local esp_renderer = {}

-- Lazy imports
local _color, _vec2, _icons, _color_api
local function load_deps()
    if _color then return end
    _color    = require("color")
    _vec2     = require("common/geometry/vector_2")
    _color_api = require("common/color")
    local ok, result = pcall(require, "common/utility/icons_helper")
    if ok and result then _icons = result end
end

local function to_api(c)
    if not c then return _color_api.new(255,255,255,255) end
    if type(c) == "table" then
        return _color_api.new(c.r or 255, c.g or 255, c.b or 255, c.a or 255)
    end
    return c
end

-- Per-spec state
local _spec_id   = "eax"
local _spec_name = "EAX"
local _state = {
    spell_id   = nil,
    spell_name = "",
    spell_col  = nil,
    target_name = "",
    set_at     = 0,
}

local DECAY_S = 3.0
local proc_entries = {}

-- Layout
local HUD_W       = 230
local HUD_ICON    = 46
local HUD_PAD     = 8
local HUD_TEXT    = 13
local HUD_SMALL   = 10
local HUD_PROC_H  = 16
local HUD_RADIUS  = 5

function esp_renderer.init(spec_id, display_name)
    _spec_id   = spec_id or "eax"
    _spec_name = display_name or spec_id or "EAX"
end

function esp_renderer.on_cast(spell_id, name, col, target_name)
    _state.spell_id    = spell_id
    _state.spell_name  = name or ""
    _state.spell_col   = col
    _state.target_name = target_name or ""
    _state.set_at      = core.time()
end

function esp_renderer.add_proc(label, active_fn, active_col, inactive_col)
    table.insert(proc_entries, {
        label       = label,
        active_fn   = active_fn,
        active_col  = active_col,
        inactive_col = inactive_col,
    })
end

function esp_renderer.clear_procs() proc_entries = {} end

function esp_renderer.notify(uid, plugin_label, msg, dur, col)
    load_deps()
    if not core.graphics.is_notification_active(uid) then
        core.graphics.add_notification(uid, plugin_label or "EAX",
            msg, dur or 2.0, to_api(col or _color.gold(220)))
    end
end

-- Draw HUD
local function draw_hud(menu)
    load_deps()
    if not menu.esp_show_hud or not menu.esp_show_hud:get_state() then return end

    -- Decay
    if (core.time() - _state.set_at) > DECAY_S then
        _state.spell_name  = ""
        _state.target_name = ""
        _state.spell_id    = nil
    end

    local x = menu.esp_hud_x and menu.esp_hud_x:get() or 20
    local y = menu.esp_hud_y and menu.esp_hud_y:get() or 200

    local proc_count = #proc_entries
    local hud_h = HUD_PAD                              -- top pad
                + HUD_SMALL + 4                        -- spec name bar
                + HUD_ICON  + HUD_PAD                  -- icon row
                + HUD_PAD                              -- bottom pad
    if proc_count > 0 then
        hud_h = hud_h + proc_count * (HUD_PROC_H + 3) + HUD_PAD
    end

    -- Main background
    core.graphics.rect_2d_filled(
        _vec2.new(x, y), HUD_W, hud_h,
        _color_api.new(8, 10, 14, 185), HUD_RADIUS)

    -- Top accent strip (spec colour)
    core.graphics.rect_2d_filled(
        _vec2.new(x, y), HUD_W, HUD_SMALL + 4,
        _color_api.new(55, 35, 110, 200), HUD_RADIUS)

    -- Outer border
    core.graphics.rect_2d(
        _vec2.new(x, y), HUD_W, hud_h,
        _color_api.new(80, 60, 160, 180), 1, HUD_RADIUS)

    -- Spec name label
    core.graphics.text_2d(
        _spec_name,
        _vec2.new(x + HUD_PAD, y + 3),
        HUD_SMALL,
        _color_api.new(210, 200, 255, 230),
        false)

    local row_y = y + HUD_SMALL + 6

    -- Icon area
    local icon_x = x + HUD_PAD
    local icon_y = row_y + HUD_PAD

    if _state.spell_id and _icons then
        local ok = pcall(function()
            _icons:draw_spell_icon(
                _state.spell_id,
                _vec2.new(icon_x, icon_y),
                HUD_ICON, HUD_ICON,
                to_api(_color.white(240)),
                false,
                { size = "large", persist_to_disk = true })
        end)
        if not ok then
            core.graphics.rect_2d_filled(
                _vec2.new(icon_x, icon_y), HUD_ICON, HUD_ICON,
                _color_api.new(40, 45, 60, 200), 4)
        end
    else
        -- Empty icon slot
        core.graphics.rect_2d_filled(
            _vec2.new(icon_x, icon_y), HUD_ICON, HUD_ICON,
            _color_api.new(25, 28, 38, 180), 4)
        core.graphics.rect_2d(
            _vec2.new(icon_x, icon_y), HUD_ICON, HUD_ICON,
            _color_api.new(60, 65, 80, 140), 1, 4)
    end

    -- Icon border
    core.graphics.rect_2d(
        _vec2.new(icon_x, icon_y), HUD_ICON, HUD_ICON,
        _color_api.new(100, 80, 180, 160), 1, 4)

    -- Text area (right of icon)
    local tx = icon_x + HUD_ICON + HUD_PAD
    local text_area_w = HUD_W - HUD_ICON - HUD_PAD * 3

    -- Spell name
    local spell_label = (_state.spell_name ~= "") and _state.spell_name or "Waiting..."
    local spell_col = to_api(_state.spell_col or _color.gold(230))
    core.graphics.text_2d(
        spell_label,
        _vec2.new(tx, icon_y + 6),
        HUD_TEXT,
        spell_col,
        false)

    -- Target name
    if _state.target_name ~= "" then
        core.graphics.text_2d(
            "on " .. _state.target_name,
            _vec2.new(tx, icon_y + HUD_TEXT + 10),
            HUD_SMALL,
            _color_api.new(150, 210, 150, 200),
            false)
    end

    -- "Next Action" hint label
    core.graphics.text_2d(
        "Next Action",
        _vec2.new(tx, icon_y + HUD_ICON - HUD_SMALL - 2),
        HUD_SMALL,
        _color_api.new(120, 125, 145, 160),
        false)

    -- Proc bars
    if proc_count > 0 then
        local bar_y = icon_y + HUD_ICON + HUD_PAD
        for _, proc in ipairs(proc_entries) do
            local active = false
            pcall(function() active = proc.active_fn() end)

            local fill_col = active
                and to_api(proc.active_col or _color.green(200))
                or  _color_api.new(30, 33, 42, 160)

            -- Background
            core.graphics.rect_2d_filled(
                _vec2.new(x + HUD_PAD, bar_y),
                HUD_W - HUD_PAD * 2, HUD_PROC_H,
                _color_api.new(18, 20, 28, 160), 3)

            -- Fill
            if active then
                core.graphics.rect_2d_filled(
                    _vec2.new(x + HUD_PAD, bar_y),
                    HUD_W - HUD_PAD * 2, HUD_PROC_H,
                    fill_col, 3)
            end

            -- Border
            core.graphics.rect_2d(
                _vec2.new(x + HUD_PAD, bar_y),
                HUD_W - HUD_PAD * 2, HUD_PROC_H,
                _color_api.new(70, 75, 95, 120), 1, 3)

            -- Label
            core.graphics.text_2d(
                proc.label,
                _vec2.new(x + HUD_PAD + 5, bar_y + 3),
                HUD_SMALL,
                active and to_api(_color.white(235))
                        or _color_api.new(130, 135, 150, 180),
                false)

            bar_y = bar_y + HUD_PROC_H + 3
        end
    end
end

-- 3D floating text above target
local function draw_target_esp(menu)
    load_deps()
    if not menu.esp_show_target or not menu.esp_show_target:get_state() then return end
    if _state.spell_name == "" then return end
    if (core.time() - _state.set_at) > DECAY_S then return end

    local me = core.object_manager.get_local_player()
    if not me then return end
    local target = me:get_target()
    if not target or not target:is_valid() or target:is_dead() then return end

    local pos = target:get_position()
    if not pos then return end

    local ok3, vec3 = pcall(require, "common/geometry/vector_3")
    local wpos = ok3 and vec3.new(pos.x, pos.y, pos.z + 2.2) or
                 { x = pos.x, y = pos.y, z = pos.z + 2.2 }

    -- Clean ASCII prefix instead of unicode arrow
    local label = "[ " .. _state.spell_name .. " ]"
    local col   = to_api(_state.spell_col or _color.gold(220))

    pcall(function()
        core.graphics.text_3d(label, wpos, 12, col, true)
    end)
end

function esp_renderer.on_render(menu)
    local ok, err = pcall(function()
        draw_hud(menu)
        draw_target_esp(menu)
    end)
    if not ok then
        core.log("[EAX ESP] render error: " .. tostring(err))
    end
end

-- Legacy alias
esp_renderer.set_next_action = esp_renderer.on_cast
esp_renderer.notify          = esp_renderer.notify

return esp_renderer
