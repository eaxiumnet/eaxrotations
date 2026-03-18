-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Rotations  ·  Space Theme  ·  ps_theme.lua  v4.0        ║
-- ║                                                                  ║
-- ║  Stars, nebula and meteors drawn INSIDE the menu panel itself   ║
-- ║  via window:render_*  calls before imgui elements render.       ║
-- ║                                                                  ║
-- ║  DROP THIS FILE into every EAX* script folder (next to main.lua)║
-- ╚══════════════════════════════════════════════════════════════════╝

local ps = {}

-- -- Lazy-loaded deps ---------------------------------------------------------
local _vec2
local function v(x, y)
    if not _vec2 then _vec2 = require("common/geometry/vector_2") end
    return _vec2.new(x, y)
end

-- -- Color helper -------------------------------------------------------------
local _color_api
local function c(r, g, b, a)
    if not _color_api then _color_api = require("common/color") end
    return _color_api.new(r, g, b, a or 255)
end

-- -- Palette ------------------------------------------------------------------
ps.col = {
    panel        = c( 16, 11,  6, 252),
    panel_deep   = c( 10,  7,  3, 240),
    border_glow  = c(255,160, 50, 220),
    border_dim   = c( 80, 45, 10, 160),
    accent       = c(255,140, 30, 255),
    accent_mid   = c(180, 90, 20, 255),
    text_on      = c(255,180, 70, 255),
    text_off     = c(100, 65, 25, 255),
    transparent  = c(  0,   0,   0,   0),
}

local STAR_R, STAR_G, STAR_B = 255, 140, 30
local DUST_R, DUST_G, DUST_B = 200, 100, 20

-- -- Pre-seeded star field (stable positions, no flicker between frames) -------
-- We seed with a fixed value so every script gets identical star layout.
local STAR_COUNT  = 160
local DUST_COUNT  = 55
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
            rx    = r1(),
            ry    = r1(),
            rad   = rv < 0.55 and 0.7 or (rv < 0.8 and 1.2 or (rv < 0.93 and 1.7 or 2.3)),
            spd   = 0.3 + r1() * 2.8,
            phase = r1() * math.pi * 2,
            bright = r1() > 0.35,
        }
    end
    _dust = {}
    for i = 1, DUST_COUNT do
        _dust[i] = {
            rx  = r2(),
            ry  = r2(),
            rad = 0.5 + r2() * 1.8,
            a   = math.floor((0.06 + r2() * 0.20) * 255),
        }
    end
end

-- -- Meteor state (per-menu, keyed by window id) -------------------------------
local _meteor_pools = {}

local function _get_meteors(id)
    if not _meteor_pools[id] then
        _meteor_pools[id] = { list = {}, next_spawn = 0 }
    end
    return _meteor_pools[id]
end

local function _spawn_meteor(pool)
    local ang = -0.26 - math.random() * 0.28
    local spd = 250 + math.random() * 200
    table.insert(pool.list, {
        x   = math.random() * 0.9,
        y   = math.random() * 0.32,
        vx  = math.cos(ang) * spd,
        vy  = math.sin(ang) * spd,
        len = 70 + math.random() * 130,
        a   = 0,
        life     = 0,
        max_life = 1.1 + math.random() * 1.3,
        w   = 0.8 + math.random() * 1.2,
    })
end

-- -- Main draw call - call this at the TOP of every window callback ------------
-- win  : the window object passed by core.register_on_render_menu_callback
-- id   : any unique string (use script prefix) for meteor state isolation
function ps.draw_space(win, id)
    _build_field()

    local W = 460
    if W < 10 then return end

    -- Ensure _vec2 is loaded (lazy-loaded by outer v() helper).
    if not _vec2 then _vec2 = require("common/geometry/vector_2") end

    -- Section start in document space.
    local oy = 0
    local ok_off, off = pcall(function() return win:get_current_context_dynamic_drawing_offset() end)
    if ok_off and off and off.y then oy = off.y end

    -- Current scroll position.
    local scroll_y = 0
    local ok_sc, sc = pcall(function() return win:get_scroll() end)
    if ok_sc and sc and sc.y then scroll_y = sc.y end

    -- Total content height = visible area + max scrollable distance.
    -- This expands automatically as subtrees open.
    local H = 580
    local ok_ms, ms = pcall(function() return win:get_max_scroll_y() end)
    if ok_ms and ms and ms > 0 then H = 580 + ms end

    -- Background draws at screen-fixed position: document offset minus scroll.
    local oy_screen = oy - scroll_y

    -- Shadow v() locally to bake in the screen-fixed Y offset.
    local function v(x, y) return _vec2.new(x, y + oy_screen) end

    local t = core.time()

    -- -- Panel base fill ------------------------------------------------------
    win:render_rect_filled(v(0, 0), v(W, H), ps.col.panel, 0)


    -- -- Dust particles -------------------------------------------------------
    for _, d in ipairs(_dust) do
        win:render_circle_filled(
            v(d.rx * W, d.ry * H), d.rad,
            c(DUST_R, DUST_G, DUST_B, d.a))
    end

    -- -- Stars (twinkling) -----------------------------------------------------
    for _, s in ipairs(_stars) do
        local tw  = 0.3 + 0.7 * math.abs(math.sin(t * s.spd + s.phase))
        local al  = s.bright and (0.4 + 0.6 * tw) or (0.08 + 0.38 * tw)
        local alb = math.floor(al * 255)
        win:render_circle_filled(
            v(s.rx * W, s.ry * H),
            s.rad * (0.7 + 0.3 * tw),
            c(STAR_R, STAR_G, STAR_B, alb))

        -- cross-flare on the biggest bright stars
        if s.bright and s.rad > 1.6 and tw > 0.88 then
            local fl = c(STAR_R, STAR_G, STAR_B, math.floor(alb * 0.28))
            local fx, fy = s.rx * W, s.ry * H
            local fr = s.rad * 3.5
            win:render_line(v(fx - fr, fy), v(fx + fr, fy), fl, 0.5)
            win:render_line(v(fx, fy - fr), v(fx, fy + fr), fl, 0.5)
        end
    end

    -- -- Meteors ---------------------------------------------------------------
    local pool = _get_meteors(id)
    local dt   = math.min(t - (pool.last_t or t), 0.05)
    pool.last_t = t

    -- Spawn logic
    if t >= pool.next_spawn and #pool.list < 4 then
        _spawn_meteor(pool)
        pool.next_spawn = t + 0.8 + math.random() * 2.5
    end

    local dead = {}
    for i, m in ipairs(pool.list) do
        m.life = m.life + dt
        m.x    = m.x + m.vx * dt / W
        m.y    = m.y + m.vy * dt / H

        -- alpha envelope: fade in 0.1s, hold, fade out
        if m.life < 0.1 then
            m.a = m.life / 0.1
        else
            m.a = math.max(0, 1 - (m.life - 0.1) / (m.max_life - 0.1))
        end

        if m.life >= m.max_life or m.x > 1.15 or m.y > 1.1 then
            dead[#dead + 1] = i
        else
            -- Tail: draw 3 segments with decreasing alpha to fake a gradient
            local ang = math.atan2(m.vy, m.vx)
            local mx, my = m.x * W, m.y * H
            local tx = mx - math.cos(ang) * m.len
            local ty = my - math.sin(ang) * m.len
            local mx2 = mx - math.cos(ang) * m.len * 0.45
            local my2 = my - math.sin(ang) * m.len * 0.45

            win:render_line(v(tx,  ty),  v(mx2, my2),
                c(DUST_R, DUST_G, DUST_B, math.floor(m.a * 60)),  m.w * 0.7)
            win:render_line(v(mx2, my2), v(mx,  my),
                c(STAR_R, STAR_G, STAR_B, math.floor(m.a * 180)), m.w)

            -- Head glow dot + soft halo
            win:render_circle_filled(
                v(mx, my), 5.5,
                c(STAR_R, STAR_G, STAR_B, math.floor(m.a * 70)))
            win:render_circle_filled(
                v(mx, my), 2.6,
                c(240, 235, 255, math.floor(m.a * 255)))
        end
    end
    for i = #dead, 1, -1 do table.remove(pool.list, dead[i]) end

    -- -- Titlebar glow line (drawn over everything, under imgui content) -------
    win:render_line(v(0, 22), v(W, 22),
        c(110, 64, 201, 80), 1.0)
    win:render_rect_filled(v(0, 22), v(W, 24),
        c(110, 64, 201, 35), 0)

    -- -- Corner bracket lines --------------------------------------------------
    local BL  = 18
    local gcol = ps.col.border_glow
    -- top-left
    win:render_line(v(2, 2),       v(2 + BL, 2),       gcol, 1.2)
    win:render_line(v(2, 2),       v(2, 2 + BL),        gcol, 1.2)
    -- top-right
    win:render_line(v(W - 2, 2),   v(W - 2 - BL, 2),   gcol, 1.2)
    win:render_line(v(W - 2, 2),   v(W - 2, 2 + BL),   gcol, 1.2)
    -- bottom-left
    win:render_line(v(2, H - 2),   v(2 + BL, H - 2),   gcol, 1.2)
    win:render_line(v(2, H - 2),   v(2, H - 2 - BL),   gcol, 1.2)
    -- bottom-right
    win:render_line(v(W - 2, H - 2), v(W - 2 - BL, H - 2), gcol, 1.2)
    win:render_line(v(W - 2, H - 2), v(W - 2, H - 2 - BL), gcol, 1.2)

    -- corner diamond gems
    local function gem(cx, cy, sz2)
        win:render_triangle_filled(
            v(cx, cy - sz2), v(cx + sz2, cy), v(cx - sz2, cy),
            ps.col.border_dim)
        win:render_triangle_filled(
            v(cx, cy + sz2), v(cx + sz2, cy), v(cx - sz2, cy),
            ps.col.border_dim)
        win:render_circle_filled(v(cx, cy), sz2 * 0.35, ps.col.accent)
    end
    local G = 9
    gem(G + 2,     G + 2,     G)
    gem(W - G - 2, G + 2,     G)
    gem(G + 2,     H - G - 2, G)
    gem(W - G - 2, H - G - 2, G)
end

-- -- Section header (purple label rendered via core.menu.header) ---------------
function ps.header(label)
    local h = core.menu.header()
    h:render("  " .. label, ps.col.accent)
end

-- -- Purple separator via window add_separator ---------------------------------
function ps.sep(win)
    win:add_separator(6, 6, 3, 0, c(110, 64, 201, 110))
end

-- -- Element constructors ------------------------------------------------------
function ps.checkbox(id, default)
    return core.menu.checkbox(default, id)
end
function ps.slider_int(mn, mx, def, id)
    return core.menu.slider_int(mn, mx, def, id)
end
function ps.slider_float(mn, mx, def, id)
    return core.menu.slider_float(mn, mx, def, id)
end
function ps.keybind(key, toggle, id)
    return core.menu.keybind(key, toggle, id)
end
function ps.combobox(default, id)
    return core.menu.combobox(default, id)
end
function ps.tree_node()
    return core.menu.tree_node()
end

-- -- Standard mode options -----------------------------------------------------
ps.MODE = { "Auto", "Solo", "Dungeon", "Raid" }

-- -- Common render helpers -----------------------------------------------------

function ps.render_controls(m, title)
    ps.header("Controls")
    m.enabled:render("Enabled",
        "Master on/off toggle for " .. title)
    m.toggle_key:render("Toggle Key",
        "Keybind to enable or disable the rotation")
    m.mode:render("Mode", ps.MODE,
        "Auto detects party context automatically")
    m.debug:render("Debug Logging",
        "Print rotation decisions to the console")
end

function ps.render_targeting(m, tgt_tree)
    tgt_tree:render("  Eax's Targeting", function()
        ps.header("Priority")
        m.focus_priority:render("Focus Target Priority",
            "Prioritise your focus target over the current target")
        m.combat_self_hp_boost:render("Self-Heal Bonus %",
            "Extra health threshold added to self-heal triggers")
    end)
end

function ps.render_racial(m, racial_tree)
    racial_tree:render("  Eax's Racial", function()
        ps.header("Racial Ability")
        m.use_racial:render("Use Racial",
            "Automatically use your racial ability at the right moment")
        m.racial_hp:render("Racial HP %",
            "Use defensive racial below this health percent")
    end)
end

function ps.render_ooc(m, ooc_tree, is_caster)
    ooc_tree:render("  Eax's Out-of-Combat", function()
        ps.header("Sustain")
        m.ooc_drink:render("Auto-Drink",
            "Drink to restore mana when out of combat")
        m.drink_threshold:render("Drink Threshold %",
            "Start drinking below this mana percent")
        m.ooc_eat:render("Auto-Eat",
            "Eat food to restore health when out of combat")
        m.eat_threshold:render("Eat Threshold %",
            "Start eating below this health percent")
        ps.header("Group")
        m.ooc_rez:render("Auto-Resurrect",
            "Accept and cast resurrection when out of combat")
        m.ooc_group_buff:render("Group Buffs",
            "Apply class buffs to party members between pulls")
        if is_caster then
            ps.header("Mana Conservation")
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
        -- Shaman-specific OOC options (shields, ghost wolf, healing)
        if m.shield_mode then
            ps.header("Shields & Utility")
            m.shield_mode:render("Shield Mode",
                { "None", "Lightning Shield", "Water Shield", "Auto (Water 60+)" },
                "Maintain selected shield between pulls")
        end
        if m.use_ghost_wolf then
            m.use_ghost_wolf:render("Ghost Wolf OOC",
                "Automatically shift to Ghost Wolf when out of combat for faster travel")
        end
        if m.use_totemic_call then
            m.use_totemic_call:render("Totemic Call",
                "Recall totems for 25% mana refund when OOC and mana is low")
        end
        if m.use_healing_wave then
            ps.header("Self-Healing")
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
            ps.header("Combat Opener")
            m.use_lb_pull:render("Lightning Bolt Pull",
                "Open with Lightning Bolt on targets beyond melee range")
            if m.lb_pull_range then
                m.lb_pull_range:render("LB Pull Range (yards)",
                    "Minimum distance before using LB to engage")
            end
        end
    end)
end

function ps.render_esp(m, esp_tree)
    esp_tree:render("  Eax's Display & HUD", function()
        ps.header("Overlay")
        m.esp_show_hud:render("Show HUD",
            "Render the in-game rotation status overlay")
        m.esp_show_target:render("Show Target Info",
            "Display target information on the HUD")
        ps.header("Position")
        m.esp_hud_x:render("HUD Position X",
            "Horizontal screen position of the HUD panel")
        m.esp_hud_y:render("HUD Position Y",
            "Vertical screen position of the HUD panel")
    end)
end

function ps.render_defensive(m, def_tree, defenses)
    def_tree:render("  Eax's Defensive", function()
        ps.header("Emergency Cooldowns")
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
            ps.header("(none configured)")
        end
    end)
end

return ps
