-- menu_theme_sylvanas.lua — EAX Rotation menu theming, categorization & playstyle visibility.
-- WHAT:  class/playstyle/category colors, role + capability maps, playstyle-section scoping,
--        section-header formatting, and a ported "space/meteor" decorative draw for custom windows.
-- WHEN:  required by main.lua at menu init + render time; pure data + pure functions, no on_update allocs.
-- WHY:   gives the menu a consistent visual identity, colors per active playstyle, and lets sections
--        hide themselves when their playstyle is not active — without editing every class schema.
-- SAFETY: all color access is pcall/nil-guarded; the meteor draw is pcalled by the caller and never
--         touches the main-menu render path (custom-window only). No banned APIs. No per-frame table alloc.
-- DECISION: curated PLAYSTYLE_SECTIONS map avoids false-positive substring matching (e.g. "Optional
--           Shadow Spells" under Smite would wrongly match the "shadow" playstyle under aggressive matching).

local MenuTheme = {}

-- ---------------------------------------------------------------------------
-- Color module (lazy + guarded). require("common/color") exposes c.yellow(),
-- c.new(r,g,b,a), etc. If unavailable we degrade to a no-op table so the menu
-- still renders with plain (uncolored) headers.
-- ---------------------------------------------------------------------------
local _color
do
    local ok, c = pcall(require, "common/color")
    if ok and type(c) == "table" and type(c.new) == "function" then
        _color = c
    end
end

local function C(r, g, b, a)
    if _color and _color.new then
        local ok, col = pcall(_color.new, _color, r, g, b, a or 230)
        if ok and col then return col end
    end
    return nil -- caller falls back to a default (uncolored) header
end

-- ---------------------------------------------------------------------------
-- Signature colors per class (used by the title header accent).
-- ---------------------------------------------------------------------------
local CLASS_COLOR = {
    druid   = C(255, 175,  60),  -- orange
    hunter  = C(170, 210,  90),  -- olive green
    mage    = C(120, 185, 255),  -- arcane blue
    paladin = C(245, 200, 110),  -- gold
    priest  = C(255, 255, 255),  -- white
    rogue   = C(255, 190,  90),  -- tan
    shaman  = C( 60, 200, 200),  -- teal
    warlock = C(180, 110, 230),  -- purple
    warrior = C(200, 105,  90),  -- bronze-red
}

-- ---------------------------------------------------------------------------
-- Signature colors per playstyle key (per class). Falls back to class color.
-- ---------------------------------------------------------------------------
local PLAYSTYLE_COLOR = {
    -- Druid
    druid  = { leveling = C(170,150,120), balance = C(120,200,200), bear = C(170,120, 60),
              cat = C(150,210, 90), caster = C(110,160,220), resto = C( 90,210,120), },
    -- Hunter
    hunter = { leveling = C(170,150,120), beast_mastery = C(150,200, 90), marksmanship = C(230,210,110), survival = C(180,130, 70), },
    -- Mage
    mage   = { leveling = C(170,150,120), arcane = C(180,130,230), fire = C(230,110, 60), frost = C(110,200,235), },
    -- Paladin
    paladin= { leveling = C(170,150,120), holy = C(245,220,120), protection = C(120,160,220), retribution = C(220, 90, 80), },
    -- Priest
    priest = { leveling = C(170,150,120), discipline = C(150,150,240), holy = C(255,240,170), shadow = C(160,110,220), smite = C(230,150, 90), },
    -- Rogue
    rogue  = { leveling = C(170,150,120), assassination = C(160,120,220), combat = C(230,170, 80), subtlety = C(110,140,220), },
    -- Shaman
    shaman = { leveling = C(170,150,120), enhancement = C(220,120, 70), elemental = C( 90,150,235), restoration = C( 90,210,120), },
    -- Warlock
    warlock= { leveling = C(170,150,120), affliction = C(150,120,220), demonology = C( 90,190,180), destruction = C(230,110, 60), },
    -- Warrior
    warrior= { leveling = C(170,150,120), arms = C(220,110, 80), fury = C(210, 80, 70), kebab = C(230,180,110), protection = C(120,160,220), },
}

--- Signature color for the currently active playstyle (falls back to class color).
function MenuTheme.playstyle_color(class_key, playstyle)
    local by_ps = class_key and PLAYSTYLE_COLOR[class_key]
    if by_ps and playstyle and by_ps[playstyle] then return by_ps[playstyle] end
    if class_key and CLASS_COLOR[class_key] then return CLASS_COLOR[class_key] end
    return C(220, 220, 220) -- neutral fallback
end

--- Signature color for a class key.
function MenuTheme.class_color(class_key)
    if class_key and CLASS_COLOR[class_key] then return CLASS_COLOR[class_key] end
    return C(220, 220, 220)
end

-- ---------------------------------------------------------------------------
-- Role + capability per playstyle (drives Control Panel filtering).
--   healer → show Healing toggle, hide Threat Drop / Interrupts
--   tank   → show Threat Drop, hide Healing
--   dps    → show Threat Drop + Interrupts, hide Healing
--   hybrid → show everything (safest: leveling priest/druid/paladin/shaman/warrior)
-- ---------------------------------------------------------------------------
local PLAYSTYLE_ROLE = {
    druid   = { leveling = "hybrid", balance = "dps", bear = "tank", cat = "dps", caster = "dps", resto = "healer" },
    hunter  = { leveling = "dps",    beast_mastery = "dps", marksmanship = "dps", survival = "dps" },
    mage    = { leveling = "dps",    arcane = "dps", fire = "dps", frost = "dps" },
    paladin = { leveling = "hybrid", holy = "healer", protection = "tank", retribution = "dps" },
    priest  = { leveling = "hybrid", discipline = "healer", holy = "healer", shadow = "dps", smite = "dps" },
    rogue   = { leveling = "dps",    assassination = "dps", combat = "dps", subtlety = "dps" },
    shaman  = { leveling = "hybrid", enhancement = "dps", elemental = "dps", restoration = "healer" },
    warlock = { leveling = "dps",    affliction = "dps", demonology = "dps", destruction = "dps" },
    warrior = { leveling = "hybrid", arms = "dps", fury = "dps", kebab = "dps", protection = "tank" },
}

--- Returns the role string ("healer"|"tank"|"dps"|"hybrid") for a playstyle. Defaults to "dps".
function MenuTheme.role_for_playstyle(class_key, playstyle)
    local t = class_key and PLAYSTYLE_ROLE[class_key]
    if t and playstyle and t[playstyle] then return t[playstyle] end
    return "dps"
end

-- Which Control Panel toggles are relevant for a role.
local ROLE_CAPABILITIES = {
    healer = { healing = true,  damage = true, cooldowns = true, aoe = true, interrupts = false, utility = true, threat_drop = false },
    tank   = { healing = false, damage = true, cooldowns = true, aoe = true, interrupts = true,  utility = true, threat_drop = true  },
    dps    = { healing = false, damage = true, cooldowns = true, aoe = true, interrupts = true,  utility = true, threat_drop = true  },
    hybrid = { healing = true,  damage = true, cooldowns = true, aoe = true, interrupts = true,  utility = true, threat_drop = true  },
}

--- capability table for a role. Each entry is bool "should this toggle be visible on the Control Panel".
function MenuTheme.capabilities(role)
    return (ROLE_CAPABILITIES[role] or ROLE_CAPABILITIES.hybrid) or ROLE_CAPABILITIES.hybrid
end

-- ---------------------------------------------------------------------------
-- Category color — derives a header color from the section header keywords.
-- Used so all "Defensives", "Cooldowns", "Utility"... sections share a palette.
-- ---------------------------------------------------------------------------
local function lower(s) return type(s) == "string" and s:lower() or "" end

function MenuTheme.category_color(header)
    local h = lower(header)
    -- order matters: most-specific keywords first
    if h:find("consumable", 1, true) or h:find("potion", 1, true) or h:find("flask", 1, true)
       or h:find("drum", 1, true) or h:find("healthstone", 1, true) or h:find("elixir", 1, true)
       or h:find("mana management", 1, true) or h:find("mana recovery", 1, true) then
        return C(230, 195, 90), "consumable"                                   -- gold
    end
    if h:find("interrupt", 1, true) or h:find("pummel", 1, true) or h:find("kick", 1, true)
       or h:find("silence", 1, true) then
        return C(230, 100, 100), "interrupt"                                    -- red
    end
    if h:find("threat", 1, true) or h:find("taunt", 1, true) then
        return C(200, 130,  90), "threat"                                       -- bronze
    end
    if h:find("defensive", 1, true) or h:find("survival", 1, true)
       or h:find("self healing", 1, true) or h:find("self survival", 1, true)
       or h:find("emergency", 1, true) then
        return C(235, 150,  60), "defensive"                                   -- orange
    end
    if h:find("cooldown", 1, true) or h:find("burst", 1, true) or h:find("burn", 1, true)
       or h:find("trinket", 1, true) then
        return C(180, 120, 230), "cooldown"                                    -- purple
    end
    if h:find("smart casting", 1, true) or h:find("healing threshold", 1, true)
       or h:find("shield target", 1, true) or h:find("aoe healing", 1, true)
       or h:find("healing priority", 1, true) then
        return C( 90, 210, 120), "smart"                                        -- green
    end
    if h:find("pvp", 1, true) or h:find("arena", 1, true) then
        return C(220,  80,  80), "pvp"                                          -- bright red
    end
    if h:find("leveling", 1, true) then
        return C(170, 150, 120), "leveling"                                     -- tan
    end
    if h:find("combat", 1, true) or h:find("rotation", 1, true)
       or h:find("core", 1, true) or h:find("seal", 1, true) then
        return nil, "rotation"                                                  -- nil => caller uses playstyle color
    end
    if h:find("utility", 1, true) or h:find("buff", 1, true) or h:find("curse", 1, true)
       or h:find("aspect", 1, true) or h:find("totem", 1, true) or h:find("aura", 1, true)
       or h:find("warrior weapon", 1, true) or h:find("pet", 1, true)
       or h:find("stone", 1, true) or h:find("weapon buff", 1, true) then
        return C( 90, 190, 220), "utility"                                      -- cyan
    end
    if h:find("mana", 1, true) then
        return C( 90, 150, 235), "mana"                                         -- blue
    end
    return C(210, 210, 210), "default"                                          -- light gray
end

-- ---------------------------------------------------------------------------
-- Section-header label formatting. Decorates the text with subtle ASCII
-- brackets so section groups are visually distinct even without pixel drawing.
-- ---------------------------------------------------------------------------
function MenuTheme.format_section_header(label)
    if type(label) ~= "string" or label == "" then return label or "" end
    if label:sub(1, 2) == "—" or label:sub(1, 1) == " " then return label end -- already decorated
    return "» " .. label
end

-- ---------------------------------------------------------------------------
-- Playstyle-section scope.
-- Tabs whose name matches a playstyle (normlised) are scoped to that playstyle.
-- Sections under shared tabs ("General"/"Consumables") may declare an explicit
-- `playstyles` array in the schema; otherwise the curated map below is used.
--
-- Curated map shape:  PLAYSTYLE_SECTIONS[class_key][header] = { "bear", ... }
--   A section with a nil/absent entry is ALWAYS shown.
-- ---------------------------------------------------------------------------
MenuTheme.PLAYSTYLE_SECTIONS = {
    druid = {
        ["Bear Tank"]                    = { "bear" },
        ["Cat (Feral DPS)"]              = { "cat" },
        ["Balance"]                      = { "balance" },
        ["Restoration"]                 = { "resto" },
        ["Restoration — Mana Conservation"] = { "resto" },
        ["Restoration — Solo DPS"]       = { "resto" },
        ["Smart Casting"]               = { "resto" },  -- druid: only resto is a healer spec
    },
    paladin = {
        ["Holy Healing"] = { "holy" },
        ["Holy Utility"] = { "holy" },
        ["Smart Casting"] = { "holy" },
    },
    priest = {
        -- spec-specific sections live under their own tabs; nothing curated here.
        ["Smart Casting"] = { "discipline", "holy" },
    },
    rogue = {
        ["Subtlety"] = { "subtlety" },
    },
    warrior = {
        ["Tactician (Arms)"] = { "arms" },
    },
}

-- Class pattern rules: a function(header_lower) -> {playstyle...} | nil.
-- Used for the shaman "Enhancement – ..." section family (many, prefix-based).
MenuTheme.CLASS_SECTION_RULES = {
    shaman = function(h)
        -- "Enhancement – X" sections belong to the enhancement playstyle only.
        if h:find("enhancement", 1, true) then return { "enhancement" } end
        return nil
    end,
}

--- Normalize a display string to match a playstyle key: lowercased, spaces→underscores.
local function normalize_name(s)
    s = lower(s)
    s = s:gsub("%s+", "_")
    s = s:gsub("[%(%)%-]", "_")
    s = s:gsub("_+", "_")
    s = s:gsub("^_", ""):gsub("_$", "")
    return s
end

--- Given a list of playstyle keys (current class) build a fast lookup.
--- Returns:  keys_set -> map for membership test;  norm_to_key for name matching.
function MenuTheme.build_playstyle_lookup(playstyle_keys, playstyle_display)
    local key_set = {}
    local norm_to_key = {}
    for i, key in ipairs(playstyle_keys or {}) do
        key_set[key] = true
        norm_to_key[normalize_name(key)] = key
        local disp = playstyle_display and playstyle_display[i]
        if disp then norm_to_key[normalize_name(disp)] = key end
    end
    return key_set, norm_to_key
end

--- Resolve the playstyle scope for a TAB by its name.
--- Returns a playstyle-key string (e.g. "bear") or nil (tab is shared/always shown).
function MenuTheme.tab_playscope(tab_name, norm_to_key)
    local n = normalize_name(tab_name)
    if n == "" then return nil end
    return norm_to_key[n]
end

--- Resolve the playstyle scope for a SECTION header (explicit schema field,
--- curated map, or class pattern rule). Returns {keys...} or nil (always shown).
function MenuTheme.section_playscope(class_key, header, explicit, key_set, class_rules)
    -- 1. explicit schema declaration wins
    if type(explicit) == "table" and #explicit > 0 then
        local out = {}
        for _, p in ipairs(explicit) do
            if not key_set or key_set[p] then out[#out + 1] = p end
        end
        if #out > 0 then return out end
    end
    -- 2. curated map
    local cur = class_key and MenuTheme.PLAYSTYLE_SECTIONS[class_key]
    if cur and cur[header] then
        local out, seen = {}, {}
        for _, p in ipairs(cur[header]) do
            if not seen[p] and (not key_set or key_set[p]) then
                seen[p] = true; out[#out + 1] = p
            end
        end
        if #out > 0 then return out end
    end
    -- 3. class pattern rule (e.g. shaman enhancement-* )
    if class_rules then
        local r = class_rules(lower(header))
        if r and #r > 0 then return r end
    end
    return nil
end

--- True if the section/tab scope admits the currently active playstyle.
--- scope == nil           → always shown
--- scope == {playstyles}  → shown iff active is in scope
function MenuTheme.scope_admits(scope, active)
    if not scope or #scope == 0 then return true end
    if not active then return true end -- unknown playstyle → show (safe default)
    for _, p in ipairs(scope) do
        if p == active then return true end
    end
    return false
end

-- ===========================================================================
--  PORTED "SPACE / METEOR" DECORATIVE DRAW  (for optional Custom UI window)
--  Ported from OldProjects/*/libraries/ps_theme.lua (EAX Space Theme v4.0).
--  Call from inside a register_on_render_window_callback + window:begin() block.
--  All drawing wrapped by the caller in pcall; this module never touches the
--  main-menu render path.
-- ===========================================================================
do
    local _vec2
    local function v(x, y)
        if not _vec2 then _vec2 = require("common/geometry/vector_2") end
        return _vec2.new(x, y)
    end

    local STAR_R, STAR_G, STAR_B = 220, 120, 30
    local DUST_R, DUST_G, DUST_B = 200,  80, 10

    local STAR_COUNT, DUST_COUNT = 160, 55
    local _stars, _dust

    local function _seed_rng(s)
        return function()
            s = (s * 1664525 + 1013904223) % 4294967296
            return (s < 0 and s + 4294967296 or s) / 4294967296
        end
    end

    local function _build_field()
        if _stars then return end
        local r1, r2 = _seed_rng(42), _seed_rng(77)
        _stars = {}
        for i = 1, STAR_COUNT do
            local rv = r1()
            _stars[i] = { rx = r1(), ry = r1(),
                rad = rv < 0.55 and 0.7 or (rv < 0.8 and 1.2 or (rv < 0.93 and 1.7 or 2.3)),
                spd = 0.3 + r1() * 2.8, phase = r1() * 6.2831853, bright = r1() > 0.35 }
        end
        _dust = {}
        for i = 1, DUST_COUNT do
            _dust[i] = { rx = r2(), ry = r2(), rad = 0.5 + r2() * 1.8, a = math.floor((0.06 + r2() * 0.20) * 255) }
        end
    end

    local _meteor_pools = {}
    local function _get_meteors(id)
        if not _meteor_pools[id] then _meteor_pools[id] = { list = {}, next_spawn = 0 } end
        return _meteor_pools[id]
    end

    local function _spawn_meteor(pool)
        local ang = -0.26 - math.random() * 0.28
        local spd = 250 + math.random() * 200
        pool.list[#pool.list + 1] = {
            x = math.random() * 0.9, y = math.random() * 0.32,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            len = 70 + math.random() * 130, a = 0, life = 0,
            max_life = 1.1 + math.random() * 1.3, w = 0.8 + math.random() * 1.2,
        }
    end

    local function _c(r, g, b, a)
        return C(r, g, b, a)
    end

    --- Draw the space theme into a Custom UI window `win`. Call inside window:begin().
    --- @param win window the window object from core.menu.window(id)
    --- @param id string unique pool id
    --- @param opt table optional { width=460, accent=color }
    function MenuTheme.draw_space(win, id, opt)
        if not win then return end
        opt = opt or {}
        local W = opt.width or 460
        if W < 10 then return end
        _build_field()

        local H = 580
        local ok_ms, ms = pcall(function() return win.get_max_scroll_y and win:get_max_scroll_y() end)
        if ok_ms and type(ms) == "number" and ms > 0 then H = 580 + ms end

        local t = (core and core.time and core.time()) or 0

        local panel = _c(16, 9, 4, 252)
        if panel then pcall(win.render_rect_filled, win, v(0, 0), v(W, H), panel, 0) end

        for _, d in ipairs(_dust) do
            local dc = _c(DUST_R, DUST_G, DUST_B, d.a)
            if dc then pcall(win.render_circle_filled, win, v(d.rx * W, d.ry * H), d.rad, dc) end
        end

        for _, s in ipairs(_stars) do
            local tw = 0.3 + 0.7 * math.abs(math.sin(t * s.spd + s.phase))
            local al = s.bright and (0.4 + 0.6 * tw) or (0.08 + 0.38 * tw)
            local sc = _c(STAR_R, STAR_G, STAR_B, math.floor(al * 255))
            if sc then
                pcall(win.render_circle_filled, win, v(s.rx * W, s.ry * H), s.rad * (0.7 + 0.3 * tw), sc)
                if s.bright and s.rad > 1.6 and tw > 0.88 then
                    local fl = _c(STAR_R, STAR_G, STAR_B, math.floor(al * 255 * 0.28))
                    if fl then
                        local fx, fy, fr = s.rx * W, s.ry * H, s.rad * 3.5
                        pcall(win.render_line, win, v(fx - fr, fy), v(fx + fr, fy), fl, 0.5)
                        pcall(win.render_line, win, v(fx, fy - fr), v(fx, fy + fr), fl, 0.5)
                    end
                end
            end
        end

        local pool = _get_meteors(id)
        local dt = math.min(t - (pool.last_t or t), 0.05)
        pool.last_t = t
        if t >= pool.next_spawn and #pool.list < 4 then
            _spawn_meteor(pool)
            pool.next_spawn = t + 0.8 + math.random() * 2.5
        end
        local dead = {}
        for i, m in ipairs(pool.list) do
            m.life = m.life + dt
            m.x = m.x + m.vx * dt / W
            m.y = m.y + m.vy * dt / H
            if m.life < 0.1 then m.a = m.life / 0.1
            else m.a = math.max(0, 1 - (m.life - 0.1) / (m.max_life - 0.1)) end
            if m.life >= m.max_life or m.x > 1.15 or m.y > 1.1 then
                dead[#dead + 1] = i
            else
                local ang = math.atan2(m.vy, m.vx)
                local mx, my = m.x * W, m.y * H
                local tx = mx - math.cos(ang) * m.len
                local ty = my - math.sin(ang) * m.len
                local mx2 = mx - math.cos(ang) * m.len * 0.45
                local my2 = my - math.sin(ang) * m.len * 0.45
                local c1 = _c(DUST_R, DUST_G, DUST_B, math.floor(m.a * 60))
                if c1 then pcall(win.render_line, win, v(tx, ty), v(mx2, my2), c1, m.w * 0.7) end
                local c2 = _c(STAR_R, STAR_G, STAR_B, math.floor(m.a * 180))
                if c2 then pcall(win.render_line, win, v(mx2, my2), v(mx, my), c2, m.w) end
                local gl = _c(STAR_R, STAR_G, STAR_B, math.floor(m.a * 70))
                if gl then pcall(win.render_circle_filled, win, v(mx, my), 5.5, gl) end
                local hg = _c(240, 235, 255, math.floor(m.a * 255))
                if hg then pcall(win.render_circle_filled, win, v(mx, my), 2.6, hg) end
            end
        end
        for i = #dead, 1, -1 do table.remove(pool.list, dead[i]) end

        -- corner brackets + gems accent
        local accent = opt.accent or _c(240, 140, 50, 220)
        if accent then
            local BL = 18
            local function L(a, b) pcall(win.render_line, win, a, b, accent, 1.2) end
            L(v(2, 2), v(2 + BL, 2));           L(v(2, 2), v(2, 2 + BL))
            L(v(W - 2, 2), v(W - 2 - BL, 2));   L(v(W - 2, 2), v(W - 2, 2 + BL))
            L(v(2, H - 2), v(2 + BL, H - 2));   L(v(2, H - 2), v(2, H - 2 - BL))
            L(v(W - 2, H - 2), v(W - 2 - BL, H - 2)); L(v(W - 2, H - 2), v(W - 2, H - 2 - BL))
        end
    end
end

return MenuTheme