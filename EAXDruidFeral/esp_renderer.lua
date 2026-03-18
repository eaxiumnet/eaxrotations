-- esp_renderer.lua
-- In-world and on-screen visual overlay for EAX rotation plugins.
--
-- Features:
--   1. Next-action HUD  — 2D panel showing the next spell icon + name
--   2. Target ESP text  — "Next: <spell>" floating 3D text above the target
--   3. Proc bar         — coloured status bars for tracked buffs/procs
--   4. Notifications    — consistent notify_cast wrapper used by all specs
--   5. Spec isolation   — multiple loaded specs don't interfere
--
-- Wire into a spec's on_render callback:
--   local esp = require("esp_renderer")
--   esp.init("feral")  -- Call once with unique spec identifier
--   core.register_on_render_callback(function()
--       esp.on_render(menu, state)
--   end)
--
-- And after each cast decision, call:
--   esp.on_cast(spell_id, spell_name, color_hint)
--   esp.notify(unique_id, message, color, duration_s)
--
-- v1.6.0 - Added spec isolation and icon caching

local esp_renderer = {}

-- ─── Lazy imports (deferred until first render) ───────────────────────────────

local _color, _vec2, _icons, _color_api
local _icons_loaded = false
local _icons_load_error = nil

local function load_deps()
    if _color then return end
    _color = require("color")          -- local color helpers (for tinting/logic)
    _vec2  = require("common/geometry/vector_2")
    _color_api = require("common/color") -- API color for core.graphics calls
    
    -- Try to load icons_helper with better error reporting
    local ok, result = pcall(require, "common/utility/icons_helper")
    if ok and result then
        _icons = result
        _icons_loaded = true
    else
        _icons_load_error = result or "unknown error"
        core.log("[EAX ESP] icons_helper failed to load: " .. tostring(_icons_load_error))
    end
end

-- Convert a local-module color table {r,g,b,a} to an API color object.
-- If it's already an API color (userdata), pass through unchanged.
local function to_api_color(c)
    if not c then return _color_api.new(255, 255, 255, 255) end
    if type(c) == "table" then
        return _color_api.new(c.r or 255, c.g or 255, c.b or 255, c.a or 255)
    end
    return c  -- already userdata
end

-- ─── State (per-spec isolation) ────────────────────────────────────────────────

-- State table keyed by spec_id
local state_by_spec = {}

local function get_state()
    local spec_id = state_by_spec._current_spec or "default"
    if not state_by_spec[spec_id] then
        state_by_spec[spec_id] = {
            next_spell_id    = nil,
            next_spell_name  = "",
            next_spell_color = nil,
            next_target_name = "",
            next_spell_set_at = 0,
        }
    end
    return state_by_spec[spec_id]
end

local NEXT_SPELL_DECAY_S = 2.5   -- clear after this many seconds of no update

-- Proc tracking: { label, active_fn, active_color, inactive_color }
local proc_entries = {}

-- ─── HUD Layout constants ─────────────────────────────────────────────────────

local HUD_X          = 20
local HUD_Y          = 200
local HUD_W          = 220
local HUD_ICON_SIZE  = 44
local HUD_PAD        = 8
local HUD_TEXT_SIZE  = 13
local HUD_PROC_H     = 18
local HUD_CORNER_R   = 6

-- ─── Public: initialize with spec identifier ─────────────────────────────────

function esp_renderer.init(spec_id)
    state_by_spec._current_spec = spec_id or "default"
    state_by_spec[state_by_spec._current_spec] = {
        next_spell_id    = nil,
        next_spell_name  = "",
        next_spell_color = nil,
        next_target_name = "",
        next_spell_set_at = 0,
    }
end

-- ─── Public: set what spell is coming next ────────────────────────────────────

function esp_renderer.set_next_action(spell_id, spell_name, color_hint, target_name)
    local state = get_state()
    state.next_spell_id    = spell_id
    state.next_spell_name  = spell_name or ""
    state.next_spell_color = color_hint
    state.next_target_name = target_name or ""
    state.next_spell_set_at = core.time()
end

-- ─── Public: register a proc indicator ────────────────────────────────────────
-- active_fn: function() -> boolean

function esp_renderer.add_proc(label, active_fn, active_color, inactive_color)
    table.insert(proc_entries, {
        label         = label,
        active_fn     = active_fn,
        active_color  = active_color,
        inactive_color = inactive_color,
    })
end

function esp_renderer.clear_procs()
    proc_entries = {}
end

-- ─── Public: notification wrapper ─────────────────────────────────────────────

function esp_renderer.notify(unique_id, plugin_label, message, dur_s, col)
    load_deps()
    if not core.graphics.is_notification_active(unique_id) then
        core.graphics.add_notification(
            unique_id,
            plugin_label or "EAX",
            message,
            dur_s or 1.0,
            to_api_color(col or _color.gold(220))
        )
    end
end

-- ─── Internal: draw the 2D HUD panel ─────────────────────────────────────────

local function draw_hud(menu)
    load_deps()
    if not menu.esp_show_hud or not menu.esp_show_hud:get_state() then return end

    local state = get_state()
    
    -- Decay check
    local age = core.time() - state.next_spell_set_at
    if age > NEXT_SPELL_DECAY_S then
        state.next_spell_id   = nil
        state.next_spell_name = ""
        state.next_target_name = ""
    end

    -- Calculate total HUD height
    local proc_count = #proc_entries
    local hud_h = HUD_PAD + HUD_ICON_SIZE + HUD_PAD
    if proc_count > 0 then
        hud_h = hud_h + proc_count * (HUD_PROC_H + 4) + HUD_PAD
    end

    local x = menu.esp_hud_x and menu.esp_hud_x:get() or HUD_X
    local y = menu.esp_hud_y and menu.esp_hud_y:get() or HUD_Y

    -- Background
    core.graphics.rect_2d_filled(
        _vec2.new(x, y), HUD_W, hud_h,
        _color_api.new(10, 12, 16, 170), HUD_CORNER_R
    )
    core.graphics.rect_2d(
        _vec2.new(x, y), HUD_W, hud_h,
        _color_api.new(60, 65, 75, 200), 1, HUD_CORNER_R
    )

    -- Spell icon
    local icon_x = x + HUD_PAD
    local icon_y = y + HUD_PAD
    
    local spell_name = state.next_spell_name or ""
    local show_melee = (spell_name == "Melee" or spell_name == "Auto Attack" or spell_name == "Basic Attack" or spell_name == "")
    local spell_id = state.next_spell_id
    
    -- Use Attack spell icon (6603) for basic attack
    if spell_id == 6603 and _icons then
        local ok = pcall(function()
            _icons:draw_spell_icon(
                6603,
                _vec2.new(icon_x, icon_y),
                HUD_ICON_SIZE, HUD_ICON_SIZE,
                to_api_color(_color.white(235)),
                false,
                { size = "large", persist_to_disk = true }
            )
        end)
        if not ok then
            core.graphics.rect_2d_filled(
                _vec2.new(icon_x, icon_y),
                HUD_ICON_SIZE, HUD_ICON_SIZE,
                _color_api.new(80, 70, 50, 200), 3
            )
        end
    elseif spell_id and _icons then
        local ok = pcall(function()
            _icons:draw_spell_icon(
                state.next_spell_id,
                _vec2.new(icon_x, icon_y),
                HUD_ICON_SIZE, HUD_ICON_SIZE,
                to_api_color(_color.white(235)),
                false,
                { size = "large", persist_to_disk = true }
            )
        end)
        if not ok then
            -- Fallback: coloured box
            core.graphics.rect_2d_filled(
                _vec2.new(icon_x, icon_y),
                HUD_ICON_SIZE, HUD_ICON_SIZE,
                _color_api.new(40, 50, 65, 200), 3
            )
        end
    elseif show_melee then
        -- Melee/Auto Attack: show sword icon placeholder
        core.graphics.rect_2d_filled(
            _vec2.new(icon_x, icon_y),
            HUD_ICON_SIZE, HUD_ICON_SIZE,
            _color_api.new(80, 70, 50, 200), 3
        )
    else
        -- Empty slot
        core.graphics.rect_2d(
            _vec2.new(icon_x, icon_y),
            HUD_ICON_SIZE, HUD_ICON_SIZE,
            _color_api.new(50, 55, 65, 140), 1, 3
        )
    end

    -- Spell name text
    local text_x = icon_x + HUD_ICON_SIZE + HUD_PAD
    local text_y = icon_y + (HUD_ICON_SIZE / 2) - (HUD_TEXT_SIZE / 2)
    local label  = (state.next_spell_name ~= "") and state.next_spell_name or "—"
    local col = to_api_color(state.next_spell_color or _color.gold(225))
    core.graphics.text_2d(
        label,
        _vec2.new(text_x, text_y),
        HUD_TEXT_SIZE,
        col,
        false
    )

    -- Target name (if any)
    local target_y = text_y + HUD_TEXT_SIZE + 2
    if state.next_target_name and state.next_target_name ~= "" then
        core.graphics.text_2d(
            "-> " .. state.next_target_name,
            _vec2.new(text_x, target_y),
            11,
            _color_api.new(140, 200, 140, 200),
            false
        )
        target_y = target_y + 14
    end

    -- Sub-label
    core.graphics.text_2d(
        "Next action",
        _vec2.new(text_x, target_y + 3),
        10,
        _color_api.new(160, 165, 175, 160),
        false
    )

    -- Proc bars
    if proc_count > 0 then
        local bar_y = icon_y + HUD_ICON_SIZE + HUD_PAD
        for i, proc in ipairs(proc_entries) do
            local is_active = false
            pcall(function() is_active = proc.active_fn() end)
            local bar_col = to_api_color(is_active
                and to_api_color(proc.active_color or _color.green(210))
                or  (proc.inactive_color or _color_api.new(55, 58, 68, 180)))

            -- Bar background
            core.graphics.rect_2d_filled(
                _vec2.new(x + HUD_PAD, bar_y),
                HUD_W - HUD_PAD * 2, HUD_PROC_H,
                _color_api.new(20, 22, 28, 160), 3
            )
            -- Bar fill (full when active)
            if is_active then
                core.graphics.rect_2d_filled(
                    _vec2.new(x + HUD_PAD, bar_y),
                    HUD_W - HUD_PAD * 2, HUD_PROC_H,
                    bar_col, 3
                )
            end
            -- Label
            core.graphics.text_2d(
                proc.label,
                _vec2.new(x + HUD_PAD + 4, bar_y + 3),
                10,
                is_active and to_api_color(_color.white(230)) or _color_api.new(140, 145, 155, 200),
                false
            )
            bar_y = bar_y + HUD_PROC_H + 4
        end
    end
end

-- ─── Internal: draw 3D ESP text above target ──────────────────────────────────

local function draw_target_esp(menu)
    load_deps()
    local state = get_state()
    
    if not menu.esp_show_target or not menu.esp_show_target:get_state() then return end
    if state.next_spell_name == "" then return end

    local age = core.time() - state.next_spell_set_at
    if age > NEXT_SPELL_DECAY_S then return end

    local me = core.object_manager.get_local_player()
    if not me then return end
    local target = me:get_target()
    if not target or not target:is_valid() or target:is_dead() then return end

    local pos = target:get_position()
    if not pos then return end

    -- Lift the text above the unit's head (+ 2.2 units up in Z)
    local text_pos_ok, text_pos = pcall(function()
        return { x = pos.x, y = pos.y, z = pos.z + 2.2 }
    end)
    if not text_pos_ok then return end

    -- Build a vec3 if the API requires it
    local ok, vec3 = pcall(require, "common/geometry/vector_3")
    local world_pos = ok and vec3.new(text_pos.x, text_pos.y, text_pos.z) or text_pos

    local label = "▶ " .. state.next_spell_name
    local col = to_api_color(state.next_spell_color or _color.gold(220))

    pcall(function()
        core.graphics.text_3d(label, world_pos, 12, col, true)
    end)
end

-- ─── Public: main render entry point ─────────────────────────────────────────

function esp_renderer.on_render(menu)
    local ok, err = pcall(function()
        draw_hud(menu)
        draw_target_esp(menu)
    end)
    if not ok then
        -- Silently swallow render errors to avoid cascading failures
        core.log("[EAX ESP] render error: " .. tostring(err))
    end
end

-- ─── Convenience: spec tells esp what it just decided to cast ─────────────────
-- Call this inside every try_* function that succeeds, before returning true.
-- Example at the cast site:
--   esp_renderer.on_cast(runtime.fireball_id, "Fireball", color.red(220), target_name)
--   return true

function esp_renderer.on_cast(spell_id, name, col, target_name)
    esp_renderer.set_next_action(spell_id, name, col, target_name)
end

return esp_renderer
