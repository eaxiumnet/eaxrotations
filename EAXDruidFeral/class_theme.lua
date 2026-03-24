-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  EAX Class Theme  v2.0  —  class_theme.lua                             ║
-- ║                                                                          ║
-- ║  Drop-in replacement for ps_theme.lua.                                  ║
-- ║  Now class- and spec-aware: palette, particles, and decorations adapt    ║
-- ║  automatically based on the player's detected class and spec.            ║
-- ║                                                                          ║
-- ║  Usage:                                                                  ║
-- ║    local theme = require("class_theme")                                  ║
-- ║    theme.init(class_id, spec_id)     -- call once at load               ║
-- ║    theme.apply(window)               -- call inside render callback      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

local theme = {}

-- ── Dependencies (lazy-loaded) ────────────────────────────────────────────────
local _vec2, _color_api, _identity
local function v(x, y)
    if not _vec2 then _vec2 = require("common/geometry/vector_2") end
    return _vec2.new(x, y)
end
local function c(r, g, b, a)
    if not _color_api then _color_api = require("common/color") end
    return _color_api.new(r, g, b, a or 255)
end
local function id()
    if not _identity then _identity = require("class_identity") end
    return _identity
end

-- ── Internal state ────────────────────────────────────────────────────────────
local _class_id  = nil
local _spec_id   = nil
local _palette   = nil
local _accent    = nil
local _visuals   = nil

-- ── Init ──────────────────────────────────────────────────────────────────────
-- Call once after loading, with the class and spec IDs.
function theme.init(class_id, spec_id)
    _class_id = class_id
    _spec_id  = spec_id
    local ident = id()
    _palette  = ident.get_class_palette(class_id)
    _accent   = ident.get_spec_accent(spec_id)
    _visuals  = ident.get_class_visuals(class_id)
end

-- ── Color accessors ───────────────────────────────────────────────────────────
-- Use these everywhere to get the current class-aware color.

function theme.col_panel()        return _palette and _palette.panel()       or c( 10, 10, 18, 252) end
function theme.col_panel_deep()   return _palette and _palette.panel_deep()  or c(  5,  5, 12, 245) end
function theme.col_border_glow()  return _palette and _palette.border_glow() or c(180,180,255, 200) end
function theme.col_border_dim()   return _palette and _palette.border_dim()  or c( 60, 60,110, 140) end
function theme.col_accent()       return _palette and _palette.accent()      or c(180,180,255, 255) end
function theme.col_accent_mid()   return _palette and _palette.accent_mid()  or c(130,130,220, 255) end
function theme.col_text_on()      return _palette and _palette.text_on()     or c(230,230,255, 255) end
function theme.col_text_off()     return _palette and _palette.text_off()    or c( 80, 80,120, 200) end
function theme.col_transparent()  return c(0, 0, 0, 0) end

-- Spec accent colors (fall back to class accent if no spec)
function theme.col_spec_primary()
    return (_accent and _accent.primary()) or theme.col_accent()
end
function theme.col_spec_secondary()
    return (_accent and _accent.secondary()) or theme.col_accent_mid()
end
function theme.col_spec_tertiary()
    return (_accent and _accent.tertiary()) or theme.col_border_dim()
end
function theme.col_resource()
    return (_accent and _accent.energy_col()) or c(80, 140, 255, 255)
end

-- ── Procedural particle field ─────────────────────────────────────────────────
-- Stars and dust seeded deterministically — no random flicker between frames.
local STAR_COUNT = 180
local DUST_COUNT = 65
local _stars, _dust

local function _seed_rng(s)
    return function()
        s = (s * 1664525 + 1013904223) % 4294967296
        return (s < 0 and s + 4294967296 or s) / 4294967296
    end
end

local function _build_field()
    if _stars then return end
    local r1 = _seed_rng(42)
    local r2 = _seed_rng(77)
    _stars = {}
    for i = 1, STAR_COUNT do
        local rv = r1()
        _stars[i] = {
            rx     = r1(),
            ry     = r1(),
            rad    = rv < 0.50 and 0.6 or (rv < 0.75 and 1.1 or (rv < 0.92 and 1.6 or 2.2)),
            spd    = 0.25 + r1() * 3.0,
            phase  = r1() * math.pi * 2,
            bright = r1() > 0.30,
        }
    end
    _dust = {}
    for i = 1, DUST_COUNT do
        _dust[i] = {
            rx  = r2(),
            ry  = r2(),
            rad = 0.5 + r2() * 2.0,
            a   = math.floor((0.04 + r2() * 0.18) * 255),
        }
    end
end

-- ── Shooting-star (transient effect) pool ────────────────────────────────────
local _meteor_pools = {}
local function _get_meteors(id_key)
    if not _meteor_pools[id_key] then
        _meteor_pools[id_key] = { list = {}, next_spawn = 0 }
    end
    return _meteor_pools[id_key]
end

local function _spawn_meteor(pool)
    local visuals = _visuals or {}
    local base_angle = (visuals.meteor_angle or -0.22) + ((math.random() - 0.5) * 2) * (visuals.angle_variance or 0.06)
    local speed = (visuals.speed or 240) + ((math.random() - 0.5) * 2) * (visuals.speed_variance or 70)
    local trail_segments = visuals.trail_segments or 4
    local ambient = visuals.ambient_intensity or 0.6
    table.insert(pool.list, {
        x   = math.random() * 0.85,
        y   = math.random() * 0.28,
        vx  = math.cos(base_angle) * speed,
        vy  = math.sin(base_angle) * speed,
        len = 70 + math.random() * 120 * (0.8 + ambient * 0.4),
        a   = 0,
        trail_segments = trail_segments,
        trail_style = visuals.trail_style or "ember",
        ambient_intensity = ambient,
        ember_rgb = visuals.ember_rgb,
        alive = true,
    })
end

local function _update_meteors(pool, dt, W, H)
    local now = core.time()
    if now >= pool.next_spawn then
        _spawn_meteor(pool)
        pool.next_spawn = now + 1.8 + math.random() * 3.5
    end
    local i = 1
    while i <= #pool.list do
        local m = pool.list[i]
        m.a  = math.min(m.a + dt * 520, 255)
        m.x  = m.x + m.vx * dt / W
        m.y  = m.y + m.vy * dt / H
        if m.x > 1.1 or m.y > 1.1 or m.x < -0.1 then
            table.remove(pool.list, i)
        else
            i = i + 1
        end
    end
end

-- ── Main particle draw (called from apply) ─────────────────────────────────
local _last_t = 0
local function _draw_particles(win, W, H, win_id)
    _build_field()
    local now  = core.time()
    local dt   = math.min(now - _last_t, 0.05)
    _last_t    = now

    -- Class star color
    local sr = _palette and _palette.star_r or 180
    local sg = _palette and _palette.star_g or 180
    local sb = _palette and _palette.star_b or 255
    local dr = _palette and _palette.dust_r or 80
    local dg = _palette and _palette.dust_g or 80
    local db = _palette and _palette.dust_b or 160

    -- Draw dust nebula
    for _, d in ipairs(_dust) do
        local alpha = math.min(d.a, 200)
        win:render_circle_filled(v(d.rx * W, d.ry * H), d.rad, c(dr, dg, db, alpha))
    end

    -- Draw twinkling stars
    for _, s in ipairs(_stars) do
        local pulse = 0.60 + 0.40 * math.sin(now * s.spd + s.phase)
        local base_a = s.bright and 220 or 120
        local a = math.floor(pulse * base_a)
        win:render_circle_filled(v(s.rx * W, s.ry * H), s.rad, c(sr, sg, sb, a))
    end

    -- Draw shooting stars
    local pool = _get_meteors(win_id)
    _update_meteors(pool, dt, W, H)
    for _, m in ipairs(pool.list) do
        local alpha = math.floor(m.a)
        if alpha > 0 then
            local tx = m.x * W
            local ty = m.y * H
            local len = m.len
            local vx = m.vx or 0
            local vy = m.vy or 0
            local mag = math.sqrt(vx * vx + vy * vy)
            local dx = (mag > 0 and vx / mag or math.cos(-0.22)) * len
            local dy = (mag > 0 and vy / mag or math.sin(-0.22)) * len
            local ember_r, ember_g, ember_b = sr, sg, sb
            if m.ember_rgb then ember_r, ember_g, ember_b = m.ember_rgb[1], m.ember_rgb[2], m.ember_rgb[3] end
            local segments = m.trail_segments or 4
            local style = m.trail_style or "ember"
            local ambient = m.ambient_intensity or 0.6
            local style_boost = (style == "radiant" and 1.15) or (style == "fel" and 1.05) or (style == "storm" and 1.10) or 1.0
            for seg = segments, 1, -1 do
                local t = seg / segments
                local fade = (1 - t)
                local seg_alpha = math.floor(alpha * (fade * fade) * (0.35 + ambient * 0.35))
                if seg_alpha > 0 then
                    local sx = tx - dx * t
                    local sy = ty - dy * t
                    local sw = (2.2 - t * 1.1) * style_boost
                    local blend = 0.25 + (1 - t) * 0.75
                    local tr = math.floor(ember_r * blend + 255 * (1 - blend))
                    local tg = math.floor(ember_g * blend + 255 * (1 - blend))
                    local tb = math.floor(ember_b * blend + 255 * (1 - blend))
                    win:render_line(v(tx, ty), v(sx, sy), c(tr, tg, tb, seg_alpha), sw)
                end
            end
            win:render_circle_filled(v(tx, ty), 3.0, c(255, 255, 255, math.min(alpha, 250)))
            win:render_circle_filled(v(tx, ty), 1.8, c(ember_r, ember_g, ember_b, math.min(alpha, 230)))
        end
    end
end

-- ── Border & gem decoration ──────────────────────────────────────────────────
local function _draw_border(win, W, H)
    local gcol = theme.col_border_glow()
    local dcol = theme.col_border_dim()
    local acol = theme.col_accent()

    -- Main border rect
    win:render_rect(v(1, 1), v(W - 1, H - 1), gcol, 4, 1.5)
    -- Inner subtle border
    win:render_rect(v(4, 4), v(W - 4, H - 4), dcol, 3, 0.8)

    -- Corner bracket ornaments (TBC stone-carved style)
    local BL = 14  -- bracket length
    local BT = 1.8 -- bracket thickness

    -- top-left
    win:render_line(v(2, 2),      v(2 + BL, 2),      gcol, BT)
    win:render_line(v(2, 2),      v(2, 2 + BL),      gcol, BT)
    -- top-right
    win:render_line(v(W - 2, 2),  v(W - 2 - BL, 2),  gcol, BT)
    win:render_line(v(W - 2, 2),  v(W - 2, 2 + BL),  gcol, BT)
    -- bottom-left
    win:render_line(v(2, H - 2),  v(2 + BL, H - 2),  gcol, BT)
    win:render_line(v(2, H - 2),  v(2, H - 2 - BL),  gcol, BT)
    -- bottom-right
    win:render_line(v(W - 2, H-2),v(W-2-BL, H-2),    gcol, BT)
    win:render_line(v(W - 2, H-2),v(W-2, H-2-BL),    gcol, BT)

    -- Corner diamond gems
    local function gem(cx, cy, sz)
        win:render_triangle_filled(v(cx, cy - sz), v(cx + sz, cy), v(cx - sz, cy), dcol)
        win:render_triangle_filled(v(cx, cy + sz), v(cx + sz, cy), v(cx - sz, cy), dcol)
        win:render_circle_filled(v(cx, cy), sz * 0.40, acol)
    end
    local G = 9
    gem(G + 2,     G + 2,     G)
    gem(W - G - 2, G + 2,     G)
    gem(G + 2,     H - G - 2, G)
    gem(W - G - 2, H - G - 2, G)
end

-- ── Header strip ─────────────────────────────────────────────────────────────
-- Draws a gradient banner across the top of the window.
local function _draw_header_strip(win, W, class_label, spec_label)
    local H_strip = 26
    local acol = theme.col_accent()
    local dcol = theme.col_panel_deep()

    -- Background strip
    win:render_rect_filled(v(2, 2), v(W - 2, H_strip), dcol, 3)
    -- Bottom accent line of header
    win:render_line(v(2, H_strip), v(W - 2, H_strip), acol, 1.2)

    -- Class/spec label — left aligned
    if class_label then
        win:render_text(1, v(10, 6), acol, class_label:upper())
    end

    -- Spec accent glyph — right aligned
    if spec_label then
        local sc = theme.col_spec_primary()
        win:render_text(0, v(W - 70, 9), sc, spec_label)
    end
end

-- ── Public apply function ─────────────────────────────────────────────────────
-- Call this INSIDE the window:render callback, before your menu elements.
--
-- IMPORTANT: We intentionally use hardcoded canvas dimensions (matching the
-- original ps_theme.draw_space pattern) rather than win:get_size().
-- Calling win:get_size() before the window is fully registered by the engine
-- spams "[Visuals Window] Get Window Size with ID: ... Does NOT Exist" errors
-- every frame until the menu is first opened.  The original ps_theme avoided
-- this entirely by using fixed 460×580 dimensions + get_max_scroll_y() as an
-- optional height extension.  We follow the same safe pattern here.

local CANVAS_W = 460
local CANVAS_H_BASE = 580

function theme.apply(win, win_id)
    return
end

-- ── Section header (rendered in-menu) ─────────────────────────────────────────
function theme.header(label)
    local h = core.menu.header()
    h:render("  " .. label, theme.col_accent())
end

-- ── Spec-colored section header ───────────────────────────────────────────────
function theme.spec_header(label)
    local h = core.menu.header()
    h:render("  " .. label, theme.col_spec_primary())
end

-- ── Separator ────────────────────────────────────────────────────────────────
function theme.sep(win)
    local col = theme.col_border_dim()
    win:add_separator(6, 6, 3, 0, col)
end

-- ── Resource bar (energy/rage/mana) drawn on a custom window ─────────────────
-- pos: vec2 top-left corner, w/h: dimensions, value: 0-100
function theme.draw_resource_bar(win, px, py, pw, ph, value, label)
    local fill = math.max(0, math.min(value or 0, 100))
    local bg   = theme.col_panel_deep()
    local fg   = theme.col_resource()
    local bd   = theme.col_border_dim()
    local tx   = theme.col_text_on()

    win:render_rect_filled(v(px, py), v(px + pw, py + ph), bg, 3)
    win:render_rect_filled(v(px + 1, py + 1), v(px + 1 + (pw - 2) * fill / 100, py + ph - 1), fg, 2)
    win:render_rect(v(px, py), v(px + pw, py + ph), bd, 3, 1)

    if label then
        win:render_text(0, v(px + 4, py + 2), tx, label)
    end
end

-- ── Combo-point pip bar ───────────────────────────────────────────────────────
-- count: 0-5 filled pips
function theme.draw_combo_pips(win, px, py, count)
    local pip_w = 14
    local pip_h = 10
    local pip_gap = 3
    local max_cp = 5
    local pip_on  = theme.col_spec_primary()
    local pip_off = c(30, 18, 5, 180)

    for i = 1, max_cp do
        local x = px + (i - 1) * (pip_w + pip_gap)
        local col = (i <= (count or 0)) and pip_on or pip_off
        win:render_rect_filled(v(x, py), v(x + pip_w, py + pip_h), col, 2)
        win:render_rect(v(x, py), v(x + pip_w, py + pip_h), theme.col_border_dim(), 2, 0.8)
    end
end

-- ── Ability group badge ───────────────────────────────────────────────────────
-- Draws a labeled group badge (e.g. "Builders" / "Finishers") with spec tint.
function theme.draw_group_badge(win, px, py, pw, label, role)
    local role_cols = {
        opener   = theme.col_spec_secondary,
        builder  = theme.col_spec_primary,
        finisher = function() return c(255, 80, 60, 220) end,
        cooldown = function() return c(255, 160, 40, 220) end,
        utility  = function() return c(140, 200, 140, 220) end,
    }
    local get_col = role_cols[role] or theme.col_spec_primary
    local col = get_col()
    local bg  = theme.col_panel_deep()

    win:render_rect_filled(v(px, py), v(px + pw, py + 16), bg, 3)
    win:render_line(v(px, py + 14), v(px + pw, py + 14), col, 1.0)
    win:render_text(0, v(px + 6, py + 2), col, label)
end

-- ── Proc indicator (for ESP HUD) ──────────────────────────────────────────────
-- Draws a glowing labeled pill for an active proc.
function theme.draw_proc_pill(win, px, py, pw, ph, label, col_active, is_active)
    local bg_col  = is_active and col_active or theme.col_panel_deep()
    local bd_col  = is_active and col_active or theme.col_border_dim()
    local tx_col  = is_active and c(255, 255, 255, 240) or theme.col_text_off()

    win:render_rect_filled(v(px, py), v(px + pw, py + ph), bg_col, ph / 2)
    win:render_rect(v(px, py), v(px + pw, py + ph), bd_col, ph / 2, 1.0)
    win:render_text(0, v(px + 6, py + 3), tx_col, label)
end

-- ── Form indicator bar ────────────────────────────────────────────────────────
-- Draws a small colored form indicator row specific to Druid (extensible).
function theme.draw_form_bar(win, px, py, pw, ph, form_name, form_col)
    local bg = theme.col_panel_deep()
    win:render_rect_filled(v(px, py), v(px + pw, py + ph), bg, 3)
    win:render_rect_filled(v(px + 2, py + 2), v(px + pw - 2, py + ph - 2), form_col, 2)
    win:render_rect(v(px, py), v(px + pw, py + ph), theme.col_border_dim(), 3, 0.8)
    win:render_text(0, v(px + 6, py + 3), c(255, 255, 255, 220), form_name)
end

-- ── Standard menu element constructors ───────────────────────────────────────
function theme.checkbox(id, default)    return core.menu.checkbox(default, id)    end
function theme.slider_int(mn, mx, def, id) return core.menu.slider_int(mn, mx, def, id) end
function theme.slider_float(mn, mx, def, id) return core.menu.slider_float(mn, mx, def, id) end
function theme.keybind(key, toggle, id) return core.menu.keybind(key, toggle, id) end
function theme.combobox(default, id)    return core.menu.combobox(default, id)    end
function theme.tree_node()              return core.menu.tree_node()              end

-- ── Common mode options ───────────────────────────────────────────────────────
theme.MODE = { "Auto", "Solo", "Dungeon", "Raid" }

-- ── Standard Controls section ─────────────────────────────────────────────────
function theme.render_controls(m, title)
    theme.header("◈ Controls")
    m.enabled:render("Enabled",
        "Master on/off toggle — set a keybind here to toggle with a hotkey")
    m.mode:render("Mode", theme.MODE,
        "Auto detects party context automatically")
    m.debug:render("Debug Logging",
        "Print rotation decisions to the console")
end

-- ── Targeting section ─────────────────────────────────────────────────────────
function theme.render_targeting(m, tgt_tree)
    tgt_tree:render("  ◈ Targeting", function()
        theme.header("Priority")
        m.focus_priority:render("Focus Target Priority",
            "Prioritise your focus target over the current target")
        m.combat_self_hp_boost:render("Self-Heal Bonus %",
            "Extra health threshold added to self-heal triggers")
    end)
end

-- ── Racial section ────────────────────────────────────────────────────────────
function theme.render_racial(m, racial_tree)
    racial_tree:render("  ◈ Racial", function()
        theme.header("Racial Ability")
        m.use_racial:render("Use Racial",
            "Automatically use your racial ability at the right moment")
        m.racial_hp:render("Racial HP %",
            "Use defensive racial below this health percent")
    end)
end

-- ── OOC section ───────────────────────────────────────────────────────────────
function theme.render_ooc(m, ooc_tree, is_caster)
    ooc_tree:render("  ◈ Out-of-Combat", function()
        theme.header("Sustain")
        m.ooc_drink:render("Auto-Drink",
            "Drink to restore mana when out of combat")
        m.drink_threshold:render("Drink Threshold %",
            "Start drinking below this mana percent")
        m.ooc_eat:render("Auto-Eat",
            "Eat food to restore health when out of combat")
        m.eat_threshold:render("Eat Threshold %",
            "Start eating below this health percent")
        theme.header("Group")
        m.ooc_rez:render("Auto-Resurrect",
            "Accept and cast resurrection when out of combat")
        m.ooc_group_buff:render("Group Buffs",
            "Apply class buffs to party members between pulls")
        if is_caster then
            theme.header("Mana Conservation")
            if m.use_wand then
                m.use_wand:render("Use Wand",
                    "Wand low-health enemies to preserve mana")
                m.wand_mana_floor:render("Wand Mana Floor %",
                    "Start wanding below this mana percent")
                m.wand_at_hp:render("Wand Target HP %",
                    "Only wand when enemy HP is below this percent")
            end
            if m.use_spirit_tap_wand then
                m.use_spirit_tap_wand:render("Spirit Tap Wand",
                    "Prefer wand kills for the Spirit Tap proc")
            end
            m.leveling_conserve_mana:render("Conserve Mana",
                "Use mana-efficient rotation while leveling")
            m.leveling_mana_floor:render("Mana Floor %",
                "Switch to conservation mode below this percent")
        end
        if m.shield_mode then
            theme.header("Shields & Utility")
            m.shield_mode:render("Shield Mode",
                { "None", "Lightning Shield", "Water Shield", "Auto (Water 60+)" },
                "Maintain selected shield between pulls")
        end
        if m.use_ghost_wolf then
            m.use_ghost_wolf:render("Ghost Wolf OOC",
                "Automatically shift to Ghost Wolf when out of combat")
        end
        if m.use_totemic_call then
            m.use_totemic_call:render("Totemic Call",
                "Recall totems for 25% mana refund when OOC and mana is low")
        end
        if m.use_healing_wave then
            theme.header("Self-Healing")
            m.use_healing_wave:render("Self-Heal (Healing Wave)",
                "Cast Healing Wave when HP drops below threshold")
            if m.healing_wave_hp then
                m.healing_wave_hp:render("Self-Heal HP %",
                    "HP% threshold to trigger emergency Healing Wave")
            end
        end
        if m.use_lesser_healing_wave then
            m.use_lesser_healing_wave:render("Prefer Lesser HW",
                "Use faster/cheaper Lesser Healing Wave when available")
        end
        if m.use_lb_pull then
            theme.header("Combat Opener")
            m.use_lb_pull:render("Lightning Bolt Pull",
                "Open with Lightning Bolt on targets beyond melee range")
            if m.lb_pull_range then
                m.lb_pull_range:render("LB Pull Range (yards)",
                    "Minimum distance before using LB to engage")
            end
        end
    end)
end

-- ── Display & HUD section ────────────────────────────────────────────────────
function theme.render_esp(m, esp_tree)
    return
end

-- ── Defensive section ─────────────────────────────────────────────────────────
function theme.render_defensive(m, def_tree, defenses)
    def_tree:render("  ◈ Defensive Cooldowns", function()
        theme.header("Emergency Cooldowns")
        if defenses and #defenses > 0 then
            for _, d in ipairs(defenses) do
                if m[d.key] then
                    m[d.key]:render(d.label, d.tip or "")
                end
                if d.hp_key and m[d.hp_key] then
                    m[d.hp_key]:render(
                        d.hp_label or (d.label .. " HP %"),
                        "Trigger below this health percent")
                end
            end
        else
            theme.header("(none configured)")
        end
    end)
end

-- ── Backward-compatibility shim ───────────────────────────────────────────────
-- Allows code written for ps_theme to work without modification.
-- Just alias the public surface.
local ps_compat = {}
ps_compat.col = setmetatable({}, {
    __index = function(_, k)
        local map = {
            panel       = theme.col_panel,
            panel_deep  = theme.col_panel_deep,
            border_glow = theme.col_border_glow,
            border_dim  = theme.col_border_dim,
            accent      = theme.col_accent,
            accent_mid  = theme.col_accent_mid,
            text_on     = theme.col_text_on,
            text_off    = theme.col_text_off,
            transparent = theme.col_transparent,
        }
        if map[k] then return map[k]() end
        return c(255, 0, 255, 255) -- magenta = unresolved
    end
})
ps_compat.header         = theme.header
ps_compat.sep            = theme.sep
ps_compat.checkbox       = theme.checkbox
ps_compat.slider_int     = theme.slider_int
ps_compat.slider_float   = theme.slider_float
ps_compat.keybind        = theme.keybind
ps_compat.combobox       = theme.combobox
ps_compat.tree_node      = theme.tree_node
ps_compat.MODE           = theme.MODE
ps_compat.render_controls   = theme.render_controls
ps_compat.render_targeting  = theme.render_targeting
ps_compat.render_racial     = theme.render_racial
ps_compat.render_ooc        = theme.render_ooc
ps_compat.render_esp        = theme.render_esp
ps_compat.render_defensive  = theme.render_defensive

theme.ps_compat = ps_compat

return theme
