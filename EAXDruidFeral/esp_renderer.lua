-- esp_renderer.lua  v5.0.0
-- Screen-space HUD rendered via core.register_on_render_callback
-- Draggable via mouse, minimize button, scale setting
-- ps_theme colour palette

local esp_renderer = {}

local _color_api, _vec2, _icons, _color
local function load_deps()
    if _color_api then return end
    _color_api = require("common/color")
    _vec2      = require("common/geometry/vector_2")
    _color     = require("color")
    local ok, r = pcall(require, "common/utility/icons_helper")
    if ok and r then _icons = r end
end

local function rgba(r,g,b,a)
    if not _color_api then _color_api = require("common/color") end
    return _color_api.new(r,g,b,a)
end
local function to_api(c)
    if not c then return rgba(255,255,255,255) end
    if type(c) == "table" and c.r ~= nil then
        return rgba(c.r, c.g or 255, c.b or 255, c.a or 255)
    end
    return c
end
local function v2(x,y)
    if not _vec2 then _vec2 = require("common/geometry/vector_2") end
    return _vec2.new(x,y)
end

-- ── State ─────────────────────────────────────────────────────────────────────
local _spec_name = "Druid Feral"
local _last = { spell_id=nil, spell_name="", spell_col=nil, target_name="", set_at=0 }
local DECAY_S = 3.0
local proc_list = {}
local _sp, _ut, _rt

-- ── Window state (persisted across frames) ────────────────────────────────────
local win = {
    x         = 20,
    y         = 200,
    w         = 230,
    minimized = false,
    -- drag state
    dragging  = false,
    drag_ox   = 0,
    drag_oy   = 0,
}

-- ── Colours (ps_theme palette) ────────────────────────────────────────────────
local C = {
    bg         = function() return rgba( 16,  9,  4, 240) end,
    bg_row     = function() return rgba( 22, 12,  5, 220) end,
    border     = function() return rgba(240, 140, 50, 160) end,
    title_bg   = function() return rgba( 10,  5,  2, 255) end,
    accent     = function() return rgba(220, 120, 30, 255) end,
    text_on    = function() return rgba(255, 160, 70, 255) end,
    text_dim   = function() return rgba(110,  60, 15, 220) end,
    text_white = function() return rgba(230, 220, 200, 255) end,
    green      = function() return rgba(100, 210,  90, 255) end,
    red        = function() return rgba(220,  70,  60, 255) end,
    gold       = function() return rgba(240, 185,  20, 255) end,
    pip_on     = function() return rgba(230, 150,  25, 255) end,
    pip_off    = function() return rgba( 50,  28,   5, 200) end,
}

local FBAR_COL = {
    cat    = function() return rgba(210, 130,  40, 255) end,
    bear   = function() return rgba( 80, 145, 210, 255) end,
    travel = function() return rgba( 70, 175,  85, 255) end,
    prowl  = function() return rgba(160, 100, 220, 255) end,
    caster = function() return rgba(140, 140, 160, 255) end,
}
local function form_col(form) return (FBAR_COL[form] or FBAR_COL.caster)() end

local FNAME = { cat="Cat", bear="Bear", travel="Travel", prowl="Stealth", caster="Caster" }
local RNAME = { cat="Energy", bear="Rage", travel="", prowl="Energy", caster="Mana" }

-- ── Layout constants ──────────────────────────────────────────────────────────
local TITLE_H = 20
local ROW_H   = 18
local PAD     = 8
local RAD     = 4
local FONT    = 12
local FONT_SM = 10

-- ── Drawing helpers ───────────────────────────────────────────────────────────
local function filled(x, y, w, h, col, rad)
    core.graphics.rect_2d_filled(v2(x,y), w, h, col, rad or 0)
end
local function outline(x, y, w, h, col, rad)
    core.graphics.rect_2d(v2(x,y), w, h, col, 1, rad or 0)
end
local function txt(str, x, y, sz, col)
    core.graphics.text_2d(str, v2(x,y), sz, col, false)
end
local function txt_w(str, sz)
    local ok, w = pcall(function()
        return core.graphics.get_text_width(str, sz)
    end)
    return ok and w or #str * (sz * 0.55)
end

-- ── Form detection ─────────────────────────────────────────────────────────────
local function get_form(me)
    if not (_sp and _ut) then return "caster", 0, 100 end
    if _ut.is_prowling(me, _sp.BUFF_PROWL)          then return "prowl",  _ut.get_energy(me), 100 end
    if _ut.has_buff(me, _sp.BUFF_CAT_FORM)        then return "cat",    _ut.get_energy(me), 100 end
    if _ut.has_buff(me, _sp.BUFF_BEAR_FORM) or
       _ut.has_buff(me, _sp.BUFF_DIRE_BEAR_FORM)  then return "bear",   _ut.get_rage(me),   100 end
    if _ut.has_buff(me, _sp.BUFF_TRAVEL_FORM)     then return "travel", 0,                  0   end
    local ok, mp = pcall(function()
        return math.floor(me:get_power(0) / me:get_max_power(0) * 100)
    end)
    return "caster", ok and mp or 0, 100
end

-- ── Input handling ────────────────────────────────────────────────────────────
-- Dragging is only allowed when the bot menu is open to avoid interfering
-- with the game camera (left click rotates camera in-game).
local VK_LBUTTON = 0x01
local _was_pressed = false

local function handle_input(title_h, menu)
    -- Only process clicks when the menu is open — prevents camera interference
    if not core.graphics.is_menu_open() then
        win.dragging = false
        _was_pressed = false
        return
    end

    local ok, cur = pcall(function() return core.get_cursor_position() end)
    if not ok or not cur then return end
    local mx, my = cur.x, cur.y

    local pressed   = core.input.is_key_pressed(VK_LBUTTON)
    local just_down = pressed and not _was_pressed
    local just_up   = not pressed and _was_pressed
    _was_pressed = pressed

    local btn_w  = title_h - 4
    local btn_x1 = win.x + win.w - btn_w - 2
    local btn_x2 = win.x + win.w - 2
    local btn_y1 = win.y + 2
    local btn_y2 = win.y + title_h - 2

    local in_title = mx >= win.x and mx <= win.x + win.w
                 and my >= win.y and my <= win.y + title_h
    local in_btn   = mx >= btn_x1 and mx <= btn_x2
                 and my >= btn_y1 and my <= btn_y2

    if just_down then
        if in_btn then
            win.minimized = not win.minimized
        elseif in_title then
            win.dragging = true
            win.drag_ox  = mx - win.x
            win.drag_oy  = my - win.y
        end
    end

    if just_up then
        win.dragging = false
        -- Save position back to menu sliders so it persists
        if menu.esp_hud_x then
            local ok1 = pcall(function() menu.esp_hud_x:set(math.floor(win.x)) end)
        end
        if menu.esp_hud_y then
            local ok2 = pcall(function() menu.esp_hud_y:set(math.floor(win.y)) end)
        end
    end

    if win.dragging and pressed then
        win.x = mx - win.drag_ox
        win.y = my - win.drag_oy
    end
end

-- ── Main draw ─────────────────────────────────────────────────────────────────
local function draw(menu)
    load_deps()

    local me = core.object_manager.get_local_player()
    if not me then return end

    local scale   = menu.hud_scale and menu.hud_scale:get() or 1.0
    win.w         = math.floor(230 * scale)
    local row_h   = math.floor(ROW_H   * scale)
    local title_h = math.floor(TITLE_H * scale)
    local pad     = math.floor(PAD     * scale)
    local fs      = math.floor(FONT    * scale)
    local fs_sm   = math.floor(FONT_SM * scale)

    -- Sync position from menu sliders (so sliders always work as fallback)
    if not win.dragging then
        win.x = menu.esp_hud_x and menu.esp_hud_x:get() or win.x
        win.y = menu.esp_hud_y and menu.esp_hud_y:get() or win.y
    end

    handle_input(title_h, menu)

    local x, y, w = win.x, win.y, win.w

    -- ── Total height ──────────────────────────────────────────────────────────
    local decayed  = (core.time() - _last.set_at) > DECAY_S
    local form, res, res_max = get_form(me)
    local cp       = _rt and _rt.combo_points or 0
    local hp       = math.floor(me:get_health_percentage())
    local fc       = form_col(form)
    local is_cat   = form == "cat" or form == "prowl"
    local is_bear  = form == "bear"

    -- Filter procs for current role
    local visible_procs = {}
    for _, p in ipairs(proc_list) do
        if not p.role or p.role == "any"
        or (p.role == "cat"  and is_cat)
        or (p.role == "bear" and is_bear) then
            table.insert(visible_procs, p)
        end
    end

    local content_h = 0
    if not win.minimized then
        content_h = content_h + row_h          -- form / spec
        content_h = content_h + row_h          -- action
        content_h = content_h + row_h          -- HP
        if res_max > 0 then
            content_h = content_h + row_h + 4  -- resource bar
        end
        if is_cat then
            content_h = content_h + row_h      -- CP pips
        end
        if #visible_procs > 0 then
            content_h = content_h + 4          -- small gap
            content_h = content_h + #visible_procs * (row_h - 2)
        end
        content_h = content_h + pad
    end
    local total_h = title_h + content_h

    -- ── Background ────────────────────────────────────────────────────────────
    filled(x, y, w, total_h, C.bg(), RAD)

    -- ── Title bar ─────────────────────────────────────────────────────────────
    filled(x, y, w, title_h, C.title_bg(), RAD)
    -- Amber glow line under title
    filled(x, y + title_h - 1, w, 1, C.accent(), 0)
    -- Border
    outline(x, y, w, total_h, C.border(), RAD)

    -- Title text: "Druid Feral"
    local title_str = "  " .. _spec_name
    txt(title_str, x + pad, y + math.floor((title_h - fs) / 2), fs, C.accent())

    -- Minimize button [ – ] or [ + ]
    local btn_sz  = title_h - 4
    local btn_x   = x + w - btn_sz - 2
    local btn_y   = y + 2
    filled(btn_x, btn_y, btn_sz, btn_sz, C.bg_row(), 2)
    outline(btn_x, btn_y, btn_sz, btn_sz, C.text_dim(), 2)
    local btn_lbl = win.minimized and "+" or "-"
    txt(btn_lbl,
        btn_x + math.floor((btn_sz - txt_w(btn_lbl, fs_sm)) / 2),
        btn_y + math.floor((btn_sz - fs_sm) / 2),
        fs_sm, C.text_on())

    if win.minimized then return end

    -- ── Content rows ──────────────────────────────────────────────────────────
    local ry = y + title_h + 2

    -- Form + spec line
    local fname = (FNAME[form] or form) .. "  -  " .. (RNAME[form] or "")
    txt("  " .. fname, x + pad, ry + math.floor((row_h - fs) / 2), fs, fc)
    ry = ry + row_h

    -- Last action
    local action = (not decayed and _last.spell_name ~= "") and _last.spell_name or "---"
    local ac = decayed and C.text_dim() or (to_api(_last.spell_col) or C.text_on())
    txt("  " .. action, x + pad, ry + math.floor((row_h - fs) / 2), fs, ac)
    -- Target name right-aligned
    if not decayed and _last.target_name ~= "" then
        local tgt = _last.target_name .. "  "
        local tw  = txt_w(tgt, fs_sm)
        txt(tgt, x + w - tw, ry + math.floor((row_h - fs_sm) / 2) + 1, fs_sm, C.text_dim())
    end
    ry = ry + row_h

    -- HP row
    local hp_col = hp > 30 and C.green() or C.red()
    local hp_str = string.format("  HP   %d%%", hp)
    txt(hp_str, x + pad, ry + math.floor((row_h - fs) / 2), fs, hp_col)
    -- HP mini-bar
    local bar_x  = x + pad + txt_w(hp_str, fs) + 4
    local bar_w  = w - (bar_x - x) - pad
    local bar_y  = ry + math.floor((row_h - 5) / 2)
    filled(bar_x, bar_y, bar_w, 5, C.bg_row(), 2)
    filled(bar_x, bar_y, math.floor(bar_w * hp / 100), 5, hp_col, 2)
    outline(bar_x, bar_y, bar_w, 5, C.text_dim(), 2)
    ry = ry + row_h

    -- Resource bar
    if res_max > 0 then
        local rl  = RNAME[form] or ""
        local pct = res_max > 0 and (res / res_max) or 0
        local rc  = fc
        local rs  = string.format("  %s   %d", rl, math.floor(res))
        txt(rs, x + pad, ry + math.floor((row_h - fs) / 2), fs, rc)
        local rb_x  = x + pad + txt_w(rs, fs) + 4
        local rb_w  = w - (rb_x - x) - pad
        local rb_y  = ry + math.floor((row_h - 5) / 2)
        filled(rb_x, rb_y, rb_w, 5, C.bg_row(), 2)
        filled(rb_x, rb_y, math.floor(rb_w * pct), 5, rc, 2)
        outline(rb_x, rb_y, rb_w, 5, C.text_dim(), 2)
        ry = ry + row_h + 4
    end

    -- Combo point pips (cat only)
    if is_cat then
        txt("  CP", x + pad, ry + math.floor((row_h - fs) / 2), fs, C.text_dim())
        local pip_start = x + pad + txt_w("  CP", fs) + 6
        local pip_w     = math.floor((w - (pip_start - x) - pad) / 5) - 2
        local pip_h     = row_h - 6
        local pip_y     = ry + 3
        for i = 1, 5 do
            local pc = i <= cp and C.pip_on() or C.pip_off()
            filled(pip_start + (i-1)*(pip_w+2), pip_y, pip_w, pip_h, pc, 2)
            outline(pip_start + (i-1)*(pip_w+2), pip_y, pip_w, pip_h, C.text_dim(), 2)
        end
        ry = ry + row_h
    end

    -- Proc rows
    if #visible_procs > 0 then
        ry = ry + 4
        local proc_row_h = row_h - 2
        for _, p in ipairs(visible_procs) do
            local active = false
            pcall(function() active = p.active_fn() end)
            local pc  = active and (to_api(p.active_col) or C.accent()) or C.text_dim()
            local dot = active and "* " or "- "
            txt("  " .. dot .. "  " .. p.label,
                x + pad, ry + math.floor((proc_row_h - fs_sm) / 2), fs_sm, pc)
            ry = ry + proc_row_h
        end
    end
end

-- ── Public API ─────────────────────────────────────────────────────────────────
function esp_renderer.init(_, display_name)
    _spec_name = display_name or "Druid Feral"
end

function esp_renderer.on_cast(spell_id, name, col, target_name)
    _last.spell_id    = spell_id
    _last.spell_name  = name or ""
    _last.spell_col   = col
    _last.target_name = target_name or ""
    _last.set_at      = core.time()
end

function esp_renderer.add_proc(label, active_fn, active_col, _, role)
    table.insert(proc_list, { label=label, active_fn=active_fn,
                               active_col=active_col, role=role })
end

function esp_renderer.clear_procs() proc_list = {} end

function esp_renderer.notify(uid, plugin_label, msg, dur, col)
    load_deps()
    if not core.graphics.is_notification_active(uid) then
        core.graphics.add_notification(uid, plugin_label or "EAX",
            msg, dur or 2.0, to_api(col or _color.gold(220)))
    end
end

function esp_renderer.set_context(sp, ut, rt) _sp=sp; _ut=ut; _rt=rt end

function esp_renderer.on_render(menu)
    local ok, err = pcall(function()
        if not (menu.esp_show_hud and menu.esp_show_hud:get_state()) then return end
        draw(menu)

        -- 3D world label
        if menu.esp_show_target and menu.esp_show_target:get_state() then
            if _last.spell_name ~= "" and (core.time() - _last.set_at) <= DECAY_S then
                load_deps()
                local me = core.object_manager.get_local_player()
                if me then
                    local target = me:get_target()
                    if target and target:is_valid() and not target:is_dead() then
                        local pos = target:get_position()
                        if pos then
                            local ok3, vec3 = pcall(require, "common/geometry/vector_3")
                            local wpos = ok3 and vec3.new(pos.x,pos.y,pos.z+2.2)
                                              or {x=pos.x,y=pos.y,z=pos.z+2.2}
                            core.graphics.text_3d("[ ".._last.spell_name.." ]", wpos,
                                12, to_api(_last.spell_col or _color.gold(200)), true)
                        end
                    end
                end
            end
        end
    end)
    if not ok then core.log("[EAX HUD] error: " .. tostring(err)) end
end

-- No longer needed but kept for safety
function esp_renderer.on_render_hud(menu) end

esp_renderer.set_next_action = esp_renderer.on_cast
return esp_renderer
