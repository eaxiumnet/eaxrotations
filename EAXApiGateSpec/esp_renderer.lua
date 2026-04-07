-- +--------------------------------------------------------------------------+
-- |  Eax Class HUD  v2.0  -  esp_renderer.lua                              |
-- |                                                                          |
-- |  Drop-in replacement for all Eax esp_renderer.lua files.               |
-- |  Fully backwards-compatible with the v2.1 API surface:                  |
-- |    esp_renderer.init(spec_id, display_name)                             |
-- |    esp_renderer.on_cast(spell_id, name, col, target_name)               |
-- |    esp_renderer.add_proc(label, active_fn, active_col, inactive_col)    |
-- |    esp_renderer.update_visual_snapshot(snapshot)                        |
-- |    esp_renderer.on_render(menu)                                          |
-- |    esp_renderer.notify(uid, plugin_label, msg, dur, col)                |
-- |    esp_renderer.set_context(spells, utils, runtime)      [Druid ext]    |
-- |                                                                          |
-- |  NEW in v2.0:                                                            |
-- |   - Class-aware color palette (auto-detected or injected)               |
-- |   - Spec accent glow on proc pills and icon border                      |
-- |   - Druid form bar with energy/rage resource strip                      |
-- |   - Combo-point pips for energy specs (Druid Feral, Rogue)             |
-- |   - Aura strip with spec-tinted active borders                         |
-- |   - Shooting-star particle field on panel background                    |
-- |   - TBC corner bracket ornaments + diamond gem decorations             |
-- |   - Draggable window with minimize button                               |
-- +--------------------------------------------------------------------------+

local esp_renderer = {}

-- -- Lazy deps -----------------------------------------------------------------
local _color, _vec2, _icons, _color_api, _theme, _identity
local function load_deps()
    if _color_api then return end
    _color_api = require("common/color")
    _vec2      = require("common/geometry/vector_2")
    _color     = require("color")
    local ok_t, t = pcall(require, "class_theme")
    if ok_t then _theme = t end
    local ok_i, i = pcall(require, "class_identity")
    if ok_i then _identity = i end
    local ok_ic, ic = pcall(require, "common/utility/icons_helper")
    if ok_ic then _icons = ic end
end

local function rgba(r, g, b, a)
    if not _color_api then _color_api = require("common/color") end
    return _color_api.new(r, g, b, a)
end
local function v2(x, y)
    if not _vec2 then _vec2 = require("common/geometry/vector_2") end
    return _vec2.new(x, y)
end
local function to_api(c)
    if not c then return rgba(255, 255, 255, 255) end
    if type(c) == "table" and c.r ~= nil then
        return rgba(c.r or 255, c.g or 255, c.b or 255, c.a or 255)
    end
    return c
end
local function metric_str(v)
    if v == nil then return "--" end
    local n = tonumber(v)
    if not n then return tostring(v) end
    return tostring(math.floor(n + 0.5))
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function get_screen_size_safe()
    local ok, size = pcall(function()
        if core.graphics.get_screen_size then return core.graphics.get_screen_size() end
    end)
    if ok and size and size.x and size.y then return size.x, size.y end
    return 1920, 1080
end

-- -- State ----------------------------------------------------------------------
local _spec_id   = "eax"
local _spec_name = "Eax"
local _class_id  = nil

local _state = {
    spell_id    = nil,
    spell_name  = "",
    spell_col   = nil,
    target_name = "",
    set_at      = 0,
}
local _visual = {
    dps          = 0,
    hps          = 0,
    cooldown_s   = 0,
    ttd_s        = "--",
    tracked_auras = { n = 0 },
}
local proc_entries = {}
local DECAY_S = 3.0

-- Druid-specific context (set via set_context)
local _sp, _ut, _rt

-- -- Particle field (class-tinted, seeded deterministically) -------------------
local STAR_COUNT = 170
local DUST_COUNT = 60
local _stars, _dust
local _last_pt = 0

local function _seed_rng(s)
    return function()
        s = (s * 1664525 + 1013904223) % 4294967296
        return (s < 0 and s + 4294967296 or s) / 4294967296
    end
end
local function _build_particles()
    if _stars then return end
    local r1 = _seed_rng(42)
    local r2 = _seed_rng(77)
    _stars = {}
    for i = 1, STAR_COUNT do
        local rv = r1()
        _stars[i] = {
            rx    = r1(), ry    = r1(),
            rad   = rv < 0.50 and 0.6 or (rv < 0.75 and 1.1 or (rv < 0.92 and 1.6 or 2.2)),
            spd   = 0.25 + r1() * 3.0,
            phase = r1() * math.pi * 2,
            bright = r1() > 0.30,
        }
    end
    _dust = {}
    for i = 1, DUST_COUNT do
        _dust[i] = { rx = r2(), ry = r2(), rad = 0.5 + r2() * 2.0, a = math.floor((0.04 + r2() * 0.18) * 255) }
    end
end

local _meteor_pool = { list = {}, next_spawn = 0 }
local function _mood_from_spec()
    local s = tostring(_spec_id or ""):lower()
    if s:find("druid") or s:find("feral") or s:find("rogue") then return "swift" end
    if s:find("warrior") or s:find("paladin") then return "heavy" end
    if s:find("mage") or s:find("priest") then return "arcane" end
    if s:find("warlock") or s:find("shadow") then return "void" end
    if s:find("shaman") or s:find("hunter") then return "storm" end
    return "default"
end
local function _spawn_meteor()
    local mood = _mood_from_spec()
    local presets = {
        swift   = { ang = -0.22, spread = 0.16, spd = 320, jitter = 0.55 },
        heavy   = { ang = -0.16, spread = 0.10, spd = 250, jitter = 0.30 },
        arcane  = { ang = -0.28, spread = 0.18, spd = 285, jitter = 0.40 },
        void    = { ang = -0.18, spread = 0.22, spd = 230, jitter = 0.65 },
        storm   = { ang = -0.24, spread = 0.20, spd = 300, jitter = 0.50 },
        default = { ang = -0.20, spread = 0.16, spd = 270, jitter = 0.42 },
    }
    local p = presets[mood] or presets.default
    local ang = p.ang - (math.random() * p.spread)
    local spd = p.spd + math.random() * 160
    table.insert(_meteor_pool.list, {
        x = math.random() * 0.9, y = math.random() * 0.25,
        vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
        life = 0.55 + math.random() * 0.75,
        age = 0, trail = {}, mood = mood, wobble = p.jitter,
    })
end
local function _update_meteors(dt, W, H)
    local now = core.time()
    if now >= _meteor_pool.next_spawn then
        _spawn_meteor()
        _meteor_pool.next_spawn = now + 1.4 + math.random() * 2.8
    end
    local i = 1
    while i <= #_meteor_pool.list do
        local m = _meteor_pool.list[i]
        m.age = m.age + dt
        local wob = math.sin((now + m.age) * 5.0) * m.wobble * 18
        m.vx = m.vx + wob * dt
        m.vy = m.vy + math.cos((now + m.age) * 4.0) * m.wobble * 7 * dt
        m.x  = m.x + m.vx * dt / W
        m.y  = m.y + m.vy * dt / H
        if (not m.trail[1]) or (m.age - (m.trail[1].t or 0) > 0.03) then
            table.insert(m.trail, 1, { x = m.x, y = m.y, t = m.age })
            if #m.trail > 8 then table.remove(m.trail) end
        end
        if m.age > m.life or m.x > 1.2 or m.y > 1.2 or m.x < -0.2 or m.y < -0.2 then
            table.remove(_meteor_pool.list, i)
        else
            i = i + 1
        end
    end
end

-- -- Color helpers (class-palette-aware) ---------------------------------------
-- These gracefully fall back to generic values if class_theme is absent.
local function C_bg()
    if _theme then return _theme.col_panel() end
    return rgba(10, 12, 18, 190)
end
local function C_bg_deep()
    if _theme then return _theme.col_panel_deep() end
    return rgba(5, 6, 12, 240)
end
local function C_border()
    if _theme then return _theme.col_border_glow() end
    return rgba(100, 80, 180, 180)
end
local function C_border_dim()
    if _theme then return _theme.col_border_dim() end
    return rgba(55, 45, 100, 120)
end
local function C_accent()
    if _theme then return _theme.col_accent() end
    return rgba(180, 160, 255, 255)
end
local function C_spec()
    if _theme then return _theme.col_spec_primary() end
    return rgba(210, 200, 255, 230)
end
local function C_resource()
    if _theme then return _theme.col_resource() end
    return rgba(80, 140, 255, 255)
end
local function C_text()      return rgba(225, 220, 210, 230) end
local function C_text_dim()  return rgba(120, 125, 145, 180) end
local function C_green()     return rgba(100, 220, 100, 255) end
local function C_red()       return rgba(220,  70,  60, 255) end
local function C_gold()      return rgba(240, 190,  20, 255) end

-- -- Layout constants ----------------------------------------------------------
local W         = 252   -- panel width
local PAD       = 8
local PAD_SM    = 4
local RAD       = 5
local FONT_SM   = 10
local FONT      = 12
local FONT_LG   = 13
local ICON_SZ   = 46    -- spell icon square
local PROC_H    = 16
local AURA_H    = 16
local AURA_SPC  = 4
local BAR_H     = 8
local PIP_W     = 14
local PIP_H     = 10
local PIP_GAP   = 3
local METRIC_H  = 15
local TITLE_H   = 20
local MIN_BTN   = 14

-- -- Druid form helpers --------------------------------------------------------
local FORM_COL = {
    cat    = function() return rgba(220, 140,  40, 255) end,
    bear   = function() return rgba( 80, 150, 215, 255) end,
    travel = function() return rgba( 70, 180,  90, 255) end,
    prowl  = function() return rgba(160, 105, 225, 255) end,
    caster = function() return rgba(140, 140, 160, 255) end,
}
local FORM_LABEL = { cat="Cat Form", bear="Bear Form", travel="Travel", prowl="Stealth", caster="Caster" }
local FORM_RES   = { cat="Energy", bear="Rage", travel="", prowl="Energy", caster="Mana" }

local function get_druid_form(me)
    if not (_sp and _ut) then return "caster", 0 end
    if _ut.is_prowling and _ut.is_prowling(me, _sp.BUFF_PROWL)     then return "prowl",  _ut.get_energy(me) end
    if _sp.BUFF_CAT_FORM and _ut.has_buff(me, _sp.BUFF_CAT_FORM)   then return "cat",    _ut.get_energy(me) end
    if _sp.BUFF_BEAR_FORM and (_ut.has_buff(me, _sp.BUFF_BEAR_FORM) or
       (_sp.BUFF_DIRE_BEAR_FORM and _ut.has_buff(me, _sp.BUFF_DIRE_BEAR_FORM)))
                                                                     then return "bear",   _ut.get_rage(me)   end
    if _sp.BUFF_TRAVEL_FORM and _ut.has_buff(me, _sp.BUFF_TRAVEL_FORM) then return "travel", 0 end
    local ok, mp = pcall(function()
        return math.floor(me:get_power(0) / me:get_max_power(0) * 100)
    end)
    return "caster", ok and mp or 0
end

-- -- Aura normalization (mirrors v2.1 contract) --------------------------------
local function normalize_aura(entry)
    if type(entry) ~= "table" then return nil end
    local label = entry.label or entry.name or entry.id
    if not label then return nil end
    return { label = tostring(label), active = (entry.active ~= false), color = entry.color }
end
local _aura_buf = { n = 0 }
local function resolve_auras(tracked)
    _aura_buf.n = 0
    if type(tracked) ~= "table" then return _aura_buf end
    local cnt = tracked.n or #tracked
    for i = 1, cnt do
        local a = normalize_aura(tracked[i])
        if a then
            _aura_buf.n = _aura_buf.n + 1
            _aura_buf[_aura_buf.n] = a
        end
        if _aura_buf.n >= 4 then break end
    end
    for i = _aura_buf.n + 1, 4 do _aura_buf[i] = nil end
    return _aura_buf
end

local function resolve_spec_id(spec_id, display_name)
    if not (_identity and _identity.SPEC_IDS) then return nil end
    local ids = _identity.SPEC_IDS
    local key = (tostring(spec_id or "") .. " " .. tostring(display_name or "")):lower()

    local function has(token)
        return key:find(token, 1, true) ~= nil
    end

    if has("hunter") or has(" bm") or key == "bm" or has(" mm") or key == "mm" or has(" sv") or key == "sv" then
        if has("beast") or has(" bm") or key == "bm" then return ids.HUNTER_BM end
        if has("mark") or has(" mm") or key == "mm" then return ids.HUNTER_MM end
        if has("surv") or has("survival") or has(" sv") or key == "sv" then return ids.HUNTER_SV end
    end

    if has("warlock") or has("destro") or has("affli") or has("demo") then
        if has("affli") or has("affliction") then return ids.WARLOCK_AFFLICTION end
        if has("demo") or has("demonology") then return ids.WARLOCK_DEMONOLOGY end
        if has("destro") or has("destruction") then return ids.WARLOCK_DESTRUCTION end
    end

    if has("druid") or has("balance") or has("feral") or has("resto") then
        if has("balance") then return ids.DRUID_BALANCE end
        if has("bear") then return ids.DRUID_FERAL_BEAR end
        if has("feral") or has("cat") then return ids.DRUID_FERAL_CAT end
        if has("resto") or has("restoration") then return ids.DRUID_RESTO end
    end

    if has("warrior") or has("wprot") or has("arms") or has("fury") then
        if has("arms") then return ids.WARRIOR_ARMS end
        if has("fury") then return ids.WARRIOR_FURY end
        if has("wprot") or has("warrior prot") then return ids.WARRIOR_PROT end
    end

    if has("paladin") or has("pholy") or has("pret") or has("pprot") then
        if has("pholy") or has("paladin holy") then return ids.PALADIN_HOLY end
        if has("pret") or has("paladin ret") or has("retribution") then return ids.PALADIN_RET end
        if has("pprot") or has("paladin prot") or has("paladin protection") then return ids.PALADIN_PROT end
    end

    if has("priest") or has("disc") or has("shadow") or has("pholy2") then
        if has("disc") or has("discipline") then return ids.PRIEST_DISCIPLINE end
        if has("shadow") then return ids.PRIEST_SHADOW end
        if has("pholy2") or has("priest holy") then return ids.PRIEST_HOLY end
    end

    if has("shaman") or has("sresto") or has("enh") or has("ele") then
        if has("sresto") or has("shaman resto") or has("shaman restoration") then return ids.SHAMAN_RESTO end
        if has("enh") or has("enhance") or has("enhancement") then return ids.SHAMAN_ENHANCE end
        if has("ele") or has("elemental") then return ids.SHAMAN_ELEMENTAL end
    end

    if has("rogue") or has("assa") or has("sub") or has("combat") then
        if has("assa") or has("assassination") then return ids.ROGUE_ASSASSINATION end
        if has("sub") or has("subtlety") then return ids.ROGUE_SUBTLETY end
        if has("combat") then return ids.ROGUE_COMBAT end
    end

    if has("mage") or has("arcane") or has("fire") or has("frost") then
        if has("arcane") then return ids.MAGE_ARCANE end
        if has("frost") then return ids.MAGE_FROST end
        if has("fire") then return ids.MAGE_FIRE end
    end

    return nil
end

local function resolve_class_id(spec_id, display_name)
    if not (_identity and _identity.CLASS_IDS) then return nil end
    local ids = _identity.CLASS_IDS
    local key = (tostring(spec_id or "") .. " " .. tostring(display_name or "")):lower()

    if key:find("hunter", 1, true) or key == "bm" or key == "mm" or key == "sv" or key:find(" beast", 1, true) or key:find(" mark", 1, true) then
        return ids.HUNTER
    end
    if key:find("warlock", 1, true) or key:find("destro", 1, true) or key:find("affli", 1, true) or key:find("demo", 1, true) then
        return ids.WARLOCK
    end
    if key:find("druid", 1, true) or key:find("balance", 1, true) or key:find("feral", 1, true) or key:find("resto", 1, true) then
        return ids.DRUID
    end
    if key:find("warrior", 1, true) or key:find("arms", 1, true) or key:find("fury", 1, true) or key:find("wprot", 1, true) then
        return ids.WARRIOR
    end
    if key:find("paladin", 1, true) or key:find("pholy", 1, true) or key:find("pret", 1, true) or key:find("pprot", 1, true) then
        return ids.PALADIN
    end
    if key:find("priest", 1, true) or key:find("disc", 1, true) or key:find("pholy2", 1, true) or key:find("shadow", 1, true) then
        return ids.PRIEST
    end
    if key:find("shaman", 1, true) or key:find("sresto", 1, true) or key:find("enh", 1, true) or key:find("ele", 1, true) then
        return ids.SHAMAN
    end
    if key:find("rogue", 1, true) or key:find("assa", 1, true) or key:find("sub", 1, true) or key:find("combat", 1, true) then
        return ids.ROGUE
    end
    if key:find("mage", 1, true) or key:find("arcane", 1, true) or key:find("fire", 1, true) or key:find("frost", 1, true) then
        return ids.MAGE
    end

    return nil
end

-- -- Window drag state ---------------------------------------------------------
local win = { x = 20, y = 200, minimized = false, dragging = false, dox = 0, doy = 0 }
local _was_lmb = false

-- -- Public API ----------------------------------------------------------------

function esp_renderer.init(spec_id, display_name, class_id_hint)
    _spec_id   = spec_id   or "eax"
    _spec_name = display_name or spec_id or "Eax"
    _class_id  = class_id_hint
    load_deps()
    if not _class_id then
        _class_id = resolve_class_id(spec_id, display_name)
    end
    if _theme and _identity then
        local sid = resolve_spec_id(spec_id, display_name)
        if sid and _class_id then
            _theme.init(_class_id, sid)
        end
    end
end

function esp_renderer.on_cast(spell_id, name, col, target_name)
    _state.spell_id    = spell_id
    _state.spell_name  = name        or ""
    _state.spell_col   = col
    _state.target_name = target_name or ""
    _state.set_at      = core.time()
end
esp_renderer.set_next_action = esp_renderer.on_cast

function esp_renderer.update_visual_snapshot(snap)
    snap = snap or {}
    _visual.dps          = tonumber(snap.dps)        or 0
    _visual.hps          = tonumber(snap.hps)        or 0
    _visual.cooldown_s   = tonumber(snap.cooldown_s) or 0
    _visual.ttd_s        = snap.ttd_s == nil and "--" or snap.ttd_s
    _visual.tracked_auras = resolve_auras(snap.tracked_auras)
end
esp_renderer.set_visual_snapshot = esp_renderer.update_visual_snapshot

function esp_renderer.add_proc(label, active_fn, active_col, inactive_col, lane)
    table.insert(proc_entries, {
        label       = label,
        active_fn   = active_fn,
        active_col  = active_col,
        inactive_col = inactive_col,
        lane        = lane or "any",
    })
end

function esp_renderer.clear_procs()
    proc_entries = {}
end

function esp_renderer.set_context(spells, utils, runtime)
    _sp = spells
    _ut = utils
    _rt = runtime
end

function esp_renderer.notify(uid, plugin_label, msg, dur, col)
    load_deps()
    if core.graphics.is_notification_active and not core.graphics.is_notification_active(uid) then
        core.graphics.add_notification(uid, plugin_label or "Eax", msg, dur or 2.0,
            to_api(col or (_color and _color.gold(220)) or rgba(240, 190, 20, 220)))
    end
end

-- -- Internal draw helpers -----------------------------------------------------
local function filled(x, y, w, h, col, r)
    core.graphics.rect_2d_filled(v2(x, y), w, h, col, r or 0)
end
local function outlined(x, y, w, h, col, t, r)
    core.graphics.rect_2d(v2(x, y), w, h, col, t or 1, r or 0)
end
local function txt(str, x, y, sz, col)
    core.graphics.text_2d(str, v2(x, y), sz, col, false)
end
local function txt_w(str, sz)
    local ok, wv = pcall(function() return core.graphics.get_text_width(str, sz) end)
    return ok and wv or #str * (sz * 0.55)
end
local function circle(cx, cy, r, col)
    core.graphics.circle_2d_filled(v2(cx, cy), r, col)
end
local function line(x1, y1, x2, y2, col, t)
    core.graphics.line_2d(v2(x1, y1), v2(x2, y2), col, t or 1)
end

-- -- Background particle field -------------------------------------------------
local function draw_particles(bx, by, bw, bh)
    _build_particles()
    local now = core.time()
    local dt  = math.min(now - _last_pt, 0.05)
    _last_pt  = now

    -- Class star/dust color
    local pal = (_theme and _identity and _class_id) and _identity.get_class_palette(_class_id) or nil
    local sr = pal and pal.star_r or 160
    local sg = pal and pal.star_g or 140
    local sb = pal and pal.star_b or 240
    local dr = pal and pal.dust_r or 60
    local dg = pal and pal.dust_g or 50
    local db = pal and pal.dust_b or 120

    -- Dust nebula
    for _, d in ipairs(_dust) do
        core.graphics.circle_2d_filled(v2(bx + d.rx * bw, by + d.ry * bh), d.rad, rgba(dr, dg, db, math.min(d.a, 180)))
    end
    -- Stars
    for _, s in ipairs(_stars) do
        local pulse = 0.55 + 0.45 * math.sin(now * s.spd + s.phase)
        local a = math.floor(pulse * (s.bright and 210 or 110))
        core.graphics.circle_2d_filled(v2(bx + s.rx * bw, by + s.ry * bh), s.rad, rgba(sr, sg, sb, a))
    end
    -- Meteors
    _update_meteors(dt, bw, bh)
    for _, m in ipairs(_meteor_pool.list) do
        local a = math.floor(math.max(0, 255 * (1 - (m.age / math.max(m.life, 0.01)))))
        if a > 0 then
            local tx, ty = bx + m.x * bw, by + m.y * bh
            circle(tx, ty, 3.8, rgba(255, 255, 255, math.min(160, a)))
            circle(tx, ty, 2.4, rgba(sr, sg, sb, math.min(255, a + 30)))
            local lastx, lasty = tx, ty
            for i = 1, #m.trail do
                local t = m.trail[i]
                local fade = math.max(18, a - i * 26)
                local px, py = bx + t.x * bw, by + t.y * bh
                line(lastx, lasty, px, py, rgba(sr, sg, sb, fade), 2.0 - i * 0.12)
                line(lastx, lasty, px, py, rgba(255, 255, 255, math.max(8, fade - 35)), 1.0 - i * 0.08)
                lastx, lasty = px, py
            end
        end
    end
end

-- -- Corner bracket ornaments (TBC stone-carved style) -------------------------
local function draw_ornaments(bx, by, bw, bh)
    local gc = C_border()
    local dc = C_border_dim()
    local ac = C_accent()
    local BL = 13
    local BT = 1.7
    -- Brackets
    line(bx+2,      by+2,       bx+2+BL,    by+2,       gc, BT)
    line(bx+2,      by+2,       bx+2,       by+2+BL,    gc, BT)
    line(bx+bw-2,   by+2,       bx+bw-2-BL, by+2,       gc, BT)
    line(bx+bw-2,   by+2,       bx+bw-2,    by+2+BL,    gc, BT)
    line(bx+2,      by+bh-2,    bx+2+BL,    by+bh-2,    gc, BT)
    line(bx+2,      by+bh-2,    bx+2,       by+bh-2-BL, gc, BT)
    line(bx+bw-2,   by+bh-2,    bx+bw-2-BL, by+bh-2,    gc, BT)
    line(bx+bw-2,   by+bh-2,    bx+bw-2,    by+bh-2-BL, gc, BT)
    -- Gem diamonds at corners
    local function gem(cx, cy, sz)
        core.graphics.triangle_2d_filled(v2(cx, cy - sz), v2(cx + sz, cy), v2(cx - sz, cy), dc)
        core.graphics.triangle_2d_filled(v2(cx, cy + sz), v2(cx + sz, cy), v2(cx - sz, cy), dc)
        circle(cx, cy, sz * 0.38, ac)
    end
    local G = 8
    gem(bx + G + 2,      by + G + 2,      G)
    gem(bx + bw - G - 2, by + G + 2,      G)
    gem(bx + G + 2,      by + bh - G - 2, G)
    gem(bx + bw - G - 2, by + bh - G - 2, G)
end

-- -- Metric row ----------------------------------------------------------------
local function draw_metric(bx, y, label, value)
    txt(label, bx, y, FONT_SM, C_text_dim())
    txt(metric_str(value), bx + 26, y, FONT_SM, C_text())
end

-- -- Aura strip ----------------------------------------------------------------
local function draw_aura_strip(bx, y, auras)
    local cnt = auras.n or 0
    if cnt == 0 then return 0 end
    local panel_w = win.w or W
    local slot_w = math.floor((panel_w - PAD * 2 - AURA_SPC * (4 - 1)) / 4)
    for i = 1, cnt do
        local au = auras[i]
        local ax  = bx + (i - 1) * (slot_w + AURA_SPC)
        local active = au.active ~= false
        local bg  = active and rgba(30, 50, 65, 170)  or rgba(22, 25, 35, 155)
        local bdc = active and (au.color and to_api(au.color) or C_spec()) or C_border_dim()
        local tc  = active and C_text() or C_text_dim()
        filled(ax, y, slot_w, AURA_H, bg, 3)
        outlined(ax, y, slot_w, AURA_H, bdc, active and 1.2 or 0.8, 3)
        txt(au.label, ax + 4, y + 3, FONT_SM, tc)
    end
    return AURA_H + PAD_SM
end

-- -- Proc strip ----------------------------------------------------------------
local function draw_proc_strip(bx, y, current_lane, current_form)
    local panel_w = win.w or W
    local visible = {}
    for _, p in ipairs(proc_entries) do
        if p.lane == "any" or p.lane == current_lane or p.lane == current_form then
            local ok, active = pcall(p.active_fn)
            table.insert(visible, { label = p.label, active = (ok and active) or false, col = p.active_col })
        end
    end
    if #visible == 0 then return 0 end

    -- Group label
    txt("PROCS", bx, y, FONT_SM, C_text_dim())
    y = y + 12

    local pill_w = math.floor((panel_w - PAD * 2 - PAD_SM * (#visible - 1)) / #visible)
    for i, pr in ipairs(visible) do
        local px = bx + (i - 1) * (pill_w + PAD_SM)
        local ph = PROC_H
        local bg = pr.active and to_api(pr.col) or rgba(18, 20, 28, 155)
        filled(px, y, pill_w, ph, bg, ph / 2)
        outlined(px, y, pill_w, ph, pr.active and to_api(pr.col) or C_border_dim(), pr.active and 1.2 or 0.7, ph / 2)
        if pr.active then
            -- outer glow
            local gc = to_api(pr.col)
            outlined(px - 1, y - 1, pill_w + 2, ph + 2, rgba(gc.r, gc.g, gc.b, 80), 1.5, ph / 2 + 1)
        end
        local lw = txt_w(pr.label, FONT_SM)
        txt(pr.label, px + (pill_w - lw) / 2, y + 3, FONT_SM,
            pr.active and rgba(255, 255, 255, 240) or C_text_dim())
    end
    return 12 + ph + PAD_SM
end

-- -- Full HUD draw -------------------------------------------------------------
local function ensure_class_theme()
    if _class_id then return end
    _class_id = resolve_class_id(_spec_id, _spec_name)
    if _class_id and _theme then
        local sid = resolve_spec_id(_spec_id, _spec_name)
        if sid then _theme.init(_class_id, sid) end
    end
end

local function resolve_player_state()
    local current_form, res_val = "caster", 0
    local current_lane = (_rt and _rt.current_lane) or "any"
    local cp, show_cp = 0, false
    local me

    do
        local ok_m, p = pcall(function() return core.object_manager.get_local_player() end)
        if ok_m then me = p end
    end

    if me and _class_id == 11 then
        current_form, res_val = get_druid_form(me)
    elseif me then
        local ok_mp, mp = pcall(function()
            return math.floor(me:get_power(0) / me:get_max_power(0) * 100)
        end)
        if ok_mp then res_val = mp end
    end

    if _class_id == 11 and (current_form == "cat" or current_form == "prowl") then
        show_cp = true
        if _rt then cp = _rt.combo_points or 0 end
        if cp == 0 and me then
            local ok_cp, v_cp = pcall(function()
                local enu = require("common/enums")
                return me:get_power(enu.power_type.COMBOPOINTS_TBC)
            end)
            if ok_cp and v_cp then cp = v_cp end
        end
    elseif _class_id == 4 and me then
        show_cp = true
        local ok_cp, v_cp = pcall(function()
            local enu = require("common/enums")
            return me:get_power(enu.power_type.COMBOPOINTS_TBC)
        end)
        if ok_cp and v_cp then cp = v_cp end
    end

    return current_form, res_val, current_lane, cp, show_cp
end

local function count_visible_procs(current_lane, current_form)
    local count = 0
    for _, p in ipairs(proc_entries) do
        if p.lane == "any" or p.lane == current_lane or p.lane == current_form then
            count = count + 1
        end
    end
    return count
end

local function compute_hud_height(aura_cnt, proc_visible_cnt, show_cp)
    local height =
        TITLE_H + PAD +
        (_class_id == 11 and 14 or 0) +
        BAR_H + 2 + PAD_SM +
        (show_cp and (PIP_H + PAD_SM) or 0) +
        ICON_SZ + PAD +
        METRIC_H * 2 + PAD_SM +
        (aura_cnt > 0 and (AURA_H + PAD_SM) or 0) +
        (proc_visible_cnt > 0 and (12 + PROC_H + PAD_SM + PAD_SM) or 0) +
        METRIC_H + PAD

    if win.minimized then height = TITLE_H + 4 end
    return height
end

local function resolve_hud_position(menu, width, height)
    local bx = win.x
    local by = win.y
    local screen_w, screen_h = get_screen_size_safe()
    local max_x = math.max(0, screen_w - width)
    local max_y = math.max(0, screen_h - height)

    if not win.dragging then
        if menu.esp_hud_x and menu.esp_hud_x.get then bx = menu.esp_hud_x:get() end
        if menu.esp_hud_y and menu.esp_hud_y.get then by = menu.esp_hud_y:get() end
        win.x, win.y = bx, by
    end

    win.x = clamp(win.x, 0, max_x)
    win.y = clamp(win.y, 0, max_y)
    bx, by = win.x, win.y

    local mx, my
    do
        local ok_m2, pos = pcall(function() return core.get_cursor_position() end)
        if ok_m2 and pos then mx, my = pos.x, pos.y end
    end

    if mx and my then
        local in_title = mx >= bx and mx <= bx + width and my >= by and my <= by + TITLE_H
        local lmb = core.input.is_key_pressed(0x01)
        local just_down = lmb and not _was_lmb
        local just_up = (not lmb) and _was_lmb
        _was_lmb = lmb

        if win.dragging then
            win.x = clamp(mx - win.dox, 0, math.max(0, screen_w - width))
            win.y = clamp(my - win.doy, 0, math.max(0, screen_h - height))
            bx, by = win.x, win.y
            if just_up then
                win.dragging = false
                if menu.esp_hud_x and menu.esp_hud_x.set then pcall(function() menu.esp_hud_x:set(math.floor(win.x)) end) end
                if menu.esp_hud_y and menu.esp_hud_y.set then pcall(function() menu.esp_hud_y:set(math.floor(win.y)) end) end
            end
        elseif in_title and just_down then
            local min_x = bx + width - MIN_BTN - PAD
            if mx < min_x then
                win.dragging = true
                win.dox = mx - bx
                win.doy = my - by
            end
        end

        local mb_x, mb_y = bx + width - MIN_BTN - PAD, by + (TITLE_H - MIN_BTN) / 2
        if just_down and mx >= mb_x and mx <= mb_x + MIN_BTN and my >= mb_y and my <= mb_y + MIN_BTN then
            win.minimized = not win.minimized
        end
    else
        _was_lmb = false
    end

    return win.x, win.y
end

local function render_hud_panel(bx, by, width, height, current_form, res_val, current_lane, cp, show_cp)
    filled(bx, by, width, height, C_bg(), RAD)
    draw_particles(bx, by, width, height)
    outlined(bx, by, width, height, C_border(), 1.2, RAD)
    outlined(bx + 2, by + 2, width - 4, height - 4, C_border_dim(), 0.7, RAD - 1)
    draw_ornaments(bx, by, width, height)

    filled(bx, by, width, TITLE_H, C_bg_deep(), RAD)
    line(bx, by + TITLE_H, bx + width, by + TITLE_H, C_accent(), 1.2)
    txt(_spec_name, bx + PAD, by + 5, FONT_LG, C_spec())

    local enabled = _rt == nil or (_rt.enabled ~= false)
    circle(bx + width - MIN_BTN - 14, by + TITLE_H / 2, 4, enabled and C_green() or C_red())

    local mb_x, mb_y = bx + width - MIN_BTN - PAD, by + (TITLE_H - MIN_BTN) / 2
    outlined(mb_x, mb_y, MIN_BTN, MIN_BTN, C_accent(), 1.0, 2)
    txt(win.minimized and "+" or "-", mb_x + 3, mb_y + 1, FONT_SM, C_accent())

    if win.minimized then return end

    local cy = by + TITLE_H + PAD

    if _class_id == 11 then
        local fcol = (FORM_COL[current_form] or FORM_COL.caster)()
        filled(bx + PAD, cy, width - PAD * 2, 12, C_bg_deep(), 2)
        filled(bx + PAD + 1, cy + 1, width - PAD * 2 - 2, 10, fcol, 2)
        outlined(bx + PAD, cy, width - PAD * 2, 12, C_border_dim(), 0.8, 2)
        txt(FORM_LABEL[current_form] or "Unknown", bx + PAD + 6, cy + 1, FONT_SM, rgba(255, 255, 255, 220))
        cy = cy + 14
    end

    local rcol = (current_form == "bear") and rgba(220, 80, 60, 255) or
                 (current_form == "caster") and rgba(80, 140, 255, 255) or
                 C_resource()
    local fill_w = math.max(0, math.min(res_val, 100))
    filled(bx + PAD, cy, width - PAD * 2, BAR_H + 2, C_bg_deep(), 2)
    filled(bx + PAD + 1, cy + 1, (width - PAD * 2 - 2) * fill_w / 100, BAR_H, rcol, 1)
    outlined(bx + PAD, cy, width - PAD * 2, BAR_H + 2, C_border_dim(), 0.7, 2)
    local res_str = (FORM_RES[current_form] or "Resource") .. " " .. fill_w .. "%"
    txt(res_str, bx + width - PAD - txt_w(res_str, FONT_SM) - 2, cy - 1, FONT_SM, C_text_dim())
    cy = cy + BAR_H + 2 + PAD_SM

    if show_cp then
        local pip_total = 5 * (PIP_W + PIP_GAP) - PIP_GAP
        local px0 = bx + (width - pip_total) / 2
        for i = 1, 5 do
            local px = px0 + (i - 1) * (PIP_W + PIP_GAP)
            local col = (i <= cp) and C_spec() or rgba(30, 18, 5, 185)
            filled(px, cy, PIP_W, PIP_H, col, 2)
            outlined(px, cy, PIP_W, PIP_H, C_border_dim(), 0.7, 2)
        end
        txt("CP " .. cp .. "/5", bx + PAD, cy + 1, FONT_SM, C_text_dim())
        cy = cy + PIP_H + PAD_SM
    end

    local icon_x, icon_y = bx + PAD, cy
    filled(icon_x, icon_y, ICON_SZ, ICON_SZ, C_bg_deep(), 4)
    if _state.spell_id and _icons then
        pcall(function()
            _icons:draw_spell_icon(_state.spell_id, v2(icon_x, icon_y), ICON_SZ, ICON_SZ,
                to_api(C_text()), false, { size = "large", persist_to_disk = true })
        end)
    else
        outlined(icon_x, icon_y, ICON_SZ, ICON_SZ, C_border_dim(), 1, 4)
    end
    outlined(icon_x, icon_y, ICON_SZ, ICON_SZ, C_spec(), 1.2, 4)

    local tx = icon_x + ICON_SZ + PAD
    local spell_lbl = (_state.spell_name ~= "") and _state.spell_name or "Waiting..."
    local spell_col = to_api(_state.spell_col or C_gold())
    txt(spell_lbl, tx, icon_y + 6, FONT, spell_col)
    if _state.target_name ~= "" then
        txt("on " .. _state.target_name, tx, icon_y + FONT + 8, FONT_SM, C_green())
    end
    txt("Next Action", tx, icon_y + ICON_SZ - FONT_SM - 2, FONT_SM, C_text_dim())
    cy = cy + ICON_SZ + PAD

    draw_metric(bx + PAD,      cy, "DPS", _visual.dps)
    draw_metric(bx + PAD + 90, cy, "HPS", _visual.hps)
    draw_metric(bx + PAD,      cy + METRIC_H, "CD",  _visual.cooldown_s)
    draw_metric(bx + PAD + 90, cy + METRIC_H, "TTD", _visual.ttd_s)
    cy = cy + METRIC_H * 2 + PAD_SM

    cy = cy + draw_aura_strip(bx + PAD, cy, _visual.tracked_auras)
    cy = cy + draw_proc_strip(bx + PAD, cy, current_lane, current_form)
end

local function draw_hud(menu)
    load_deps()
    if menu.esp_show_hud and not menu.esp_show_hud:get_state() then return end

    if (core.time() - _state.set_at) > DECAY_S then
        _state.spell_name  = ""
        _state.target_name = ""
        _state.spell_id    = nil
    end

    local scale = (menu.hud_scale and menu.hud_scale.get and menu.hud_scale:get()) or 1.0
    scale = tonumber(scale) or 1.0
    if scale <= 0 then scale = 1.0 end

    win.w = math.floor(252 * scale)
    ensure_class_theme()

    local current_form, res_val, current_lane, cp, show_cp = resolve_player_state()
    local aura_cnt = _visual.tracked_auras and (_visual.tracked_auras.n or 0) or 0
    local proc_visible_cnt = count_visible_procs(current_lane, current_form)
    local width = win.w
    local height = compute_hud_height(aura_cnt, proc_visible_cnt, show_cp)
    local bx, by = resolve_hud_position(menu, width, height)

    render_hud_panel(bx, by, width, height, current_form, res_val, current_lane, cp, show_cp)
end

-- -- 3D floating cast label above target ---------------------------------------
local function draw_target_esp(menu)
    if menu.esp_show_target and not menu.esp_show_target:get_state() then return end
    if _state.spell_name == "" then return end
    if (core.time() - _state.set_at) > DECAY_S then return end
    local me
    do
        local ok, p = pcall(function() return core.object_manager.get_local_player() end)
        if not ok or not p then return end
        me = p
    end
    local target
    do
        local ok, t = pcall(function() return me:get_target() end)
        if not ok or not t then return end
        target = t
    end
    do
        local ok1, valid = pcall(function() return target:is_valid() end)
        local ok2, dead  = pcall(function() return target:is_dead() end)
        if not ok1 or not valid or (ok2 and dead) then return end
    end
    local pos
    do
        local ok, p = pcall(function() return target:get_position() end)
        if not ok or not p then return end
        pos = p
    end
    local ok3, vec3 = pcall(require, "common/geometry/vector_3")
    local wpos = ok3 and vec3.new(pos.x, pos.y, pos.z + 2.2) or { x = pos.x, y = pos.y, z = pos.z + 2.2 }
    local label = "[ " .. _state.spell_name .. " ]"
    pcall(function()
        core.graphics.text_3d(label, wpos, 12, to_api(_state.spell_col or C_spec()), true)
    end)
end

-- -- on_render (called from main.lua each frame) -------------------------------
function esp_renderer.on_render(menu)
    return
end

return esp_renderer


