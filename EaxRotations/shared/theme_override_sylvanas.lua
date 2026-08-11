-- theme_override_sylvanas.lua — Runtime menu theme recolor (purple → user-chosen accent).
-- WHAT:  finds the runtime common/menu/theme.lua palette table (T.p) via require()
--        and mutates purple/magenta entries in place to a user-configurable accent color,
--        recoloring the entire menu without editing read-only .api/ or loader assets.
-- WHEN:  called every render frame via register_on_render_callback (60fps).
-- WHY:   Project Sylvanas runtime v2 centralized theming into T.p and made everything
--        purple. Per-widget color fields on core.menu are IGNORED (themed centrally),
--        so the only way to recolor from a plugin is to mutate the shared palette table.
-- SAFETY: all require()/color calls are pcall'd; no on_update allocs; palette entries
--         are plain array-indexed tables {R,G,B,A} written via [1][2][3][4]. No banned APIs.

local M = {}

-- ===========================================================================
-- USER ACCENT COLOR (default: teal/cyan)
-- ===========================================================================
local _accent = { 80, 180, 160 }  -- default teal — overwritten by color picker
local _last_accent = { 0, 0, 0 }  -- for change detection

--- Set the accent color used for the theme. Called from main.lua each frame
--- with the color picker's current value.
function M.set_accent(r, g, b)
    _accent[1] = r or 80
    _accent[2] = g or 180
    _accent[3] = b or 160
end

-- ===========================================================================
-- DERIVE TARGET: maps an original purple color to the user's accent at
-- appropriate lightness. Uses the original's brightness to determine role:
--   HIGH (>0.7): text — mostly neutral white/gray with accent tint
--   MID (0.12-0.7): accent elements — user's color scaled by brightness
--   LOW (<0.12): backgrounds — near-black with minimal accent
-- ===========================================================================
local function derive_target(orig_r, orig_g, orig_b, ar, ag, ab)
    local luma = (orig_r + orig_g + orig_b) / 3  -- 0-255
    local t = luma / 255  -- 0-1 normalized brightness
    local accent_luma = (ar + ag + ab) / 3

    if t > 0.7 then
        -- TEXT ROLE: mostly white/gray, subtle accent tint for cohesion
        local white_t = (t - 0.7) / 0.3  -- 0→1 within this band
        local desaturate = 0.70 + white_t * 0.20  -- 0.70→0.90
        local target_luma = math.floor(luma * 0.95)
        local nr = math.floor(target_luma * desaturate + ar * (1 - desaturate))
        local ng = math.floor(target_luma * desaturate + ag * (1 - desaturate))
        local nb = math.floor(target_luma * desaturate + ab * (1 - desaturate))
        return math.min(255, nr), math.min(255, ng), math.min(255, nb)
    elseif t > 0.12 then
        -- ACCENT ROLE: user's color scaled to match original brightness
        local scale = luma / math.max(accent_luma, 1)
        local nr = math.min(255, math.floor(ar * scale))
        local ng = math.min(255, math.floor(ag * scale))
        local nb = math.min(255, math.floor(ab * scale))
        return nr, ng, nb
    else
        -- BACKGROUND ROLE: near-black with very faint accent warmth
        local tint = 0.12
        local nr = math.max(0, math.floor(luma * (1 - tint) + ar * tint * t * 3))
        local ng = math.max(0, math.floor(luma * (1 - tint) + ag * tint * t * 3))
        local nb = math.max(0, math.floor(luma * (1 - tint) + ab * tint * t * 3))
        return nr, ng, nb
    end
end

--- Dedicated danger recolor: hot-pink/magenta danger → proper warm red-orange.
--- Always the same regardless of accent choice.
local function transform_danger(r, g, b)
    return math.min(255, math.floor(r * 0.95)),
           math.min(255, math.floor(g * 1.1)),
           math.max(0, math.floor(b * 0.45))
end

-- ===========================================================================
-- Local helpers
-- ===========================================================================

-- Cache core.log at module load (Pattern 2: API Caching at Load).
local _core = _G.core
local _core_log = _core and type(_core.log) == "function" and _core.log or nil
local function log(msg)
    if _core_log then _core_log(msg) end
end

--- Read RGBA from a color-like value (color object, {r,g,b,a} table, or {r=..} table).
--- Returns r, g, b, a or nil if not a recognizable color.
local function read_rgba(col)
    if type(col) ~= "table" then return nil end
    -- Color object with :get() method (common/color class)
    if type(col.get) == "function" then
        local ok, r, g, b, a = pcall(col.get, col)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b, a or 255
        end
    end
    -- Raw table with .r/.g/.b/.a fields
    if type(col.r) == "number" and type(col.g) == "number" and type(col.b) == "number" then
        return col.r, col.g, col.b, col.a or 255
    end
    -- Array-style {r, g, b, a}
    if type(col[1]) == "number" and type(col[2]) == "number" and type(col[3]) == "number" then
        return col[1], col[2], col[3], col[4] or 255
    end
    return nil
end

--- Mutate a color value in place to the target RGBA. Writes to BOTH named fields
--- (.r/.g/.b/.a) AND array indices ([1]/[2]/[3]/[4]) to cover all storage formats.
--- Also tries :set() if available and table-entry replacement as last resort.
local function mutate_color(palette, key, col, r, g, b, a)
    if type(col) ~= "table" then return false end
    -- Strategy 1: :set() — in-place mutation (best for color objects with methods)
    if type(col.set) == "function" then
        pcall(col.set, col, r, g, b, a)
    end
    -- Strategy 2: overwrite BOTH named fields AND array indices (covers all formats)
    col.r, col.g, col.b, col.a = r, g, b, a
    col[1], col[2], col[3], col[4] = r, g, b, a
    -- Strategy 3: replace table entry with a new color object (last resort)
    local cok, color_mod = pcall(require, "common/color")
    if cok and color_mod and type(color_mod.new) == "function" then
        local n_ok, new_col = pcall(color_mod.new, color_mod, r, g, b, a)
        if n_ok and new_col then
            palette[key] = new_col
        end
    end
    return true
end

--- Detect if an RGBA color is purple/magenta-tinted.
--- Purple: R and B both exceed G (with tolerance), has visible hue.
local function is_purple(r, g, b)
    -- R and B must both dominate G (the hallmark of purple/magenta)
    if not (r > g + 5 and b > g + 5) then return false end
    -- Must have visible hue (not a near-gray with slight tint)
    if (r - g) < 8 and (b - g) < 8 then return false end
    -- Lowered near-black threshold to catch dark purple backgrounds.
    -- Old: 80 (missed bg_elev-like darks). New: 40.
    if r + g + b < 40 then return false end
    return true
end

--- Detect if a purple-ish color is specifically a "danger/warning" pink
--- (high R, moderate B, low G) — should become red, not neutral gray.
local function is_danger_pink(r, g, b)
    -- R is clearly the dominant channel, B is moderate, G is low
    return r > 180 and r > b and b > g + 20 and g < 100
end

-- ===========================================================================
-- Palette discovery — tries multiple require() paths to find T.p
-- ===========================================================================

local function find_palette()
    -- Strategy 1: require("common/menu/theme") — the documented location
    --   (api.lua:269 → "common/menu/theme.lua (palette T.p, ...)")
    local ok1, theme_mod = pcall(require, "common/menu/theme")
    if ok1 and type(theme_mod) == "table" then
        -- T.p might be at .p, .palette, or the module itself might be T
        local p = theme_mod.p or theme_mod.palette
        if type(p) == "table" then return p, "require(common/menu/theme).p" end
        -- Some implementations return T directly (T = { p = {...}, s = {...}, ... })
        if type(theme_mod.P) == "table" then return theme_mod.P, "require(common/menu/theme).P" end
    end

    -- Strategy 2: require("common/menu/api") — scan menu module for theme ref
    local ok2, menu_mod = pcall(require, "common/menu/api")
    if ok2 and type(menu_mod) == "table" then
        local t = menu_mod.theme or menu_mod._theme or menu_mod.T
        if type(t) == "table" then
            local p = t.p or t.palette or t.P
            if type(p) == "table" then return p, "require(common/menu/api).theme.p" end
        end
    end

    -- Strategy 3: _G.menu — the installed global menu module
    if type(_G.menu) == "table" then
        local t = _G.menu.theme or _G.menu._theme
        if type(t) == "table" then
            local p = t.p or t.palette or t.P
            if type(p) == "table" then return p, "_G.menu.theme.p" end
        end
    end

    -- Strategy 4: _G.T — some runtimes expose the theme table as a global
    if type(_G.T) == "table" then
        local p = _G.T.p or _G.T.palette or _G.T.P
        if type(p) == "table" then return p, "_G.T.p" end
    end

    return nil, nil
end

-- ===========================================================================
-- Scan + mutate — walks the palette table (1 level of nesting) and recolors
-- any purple entries via the transform function.
-- SIDE EFFECT: also appends to _cached_mutations so apply_continuous() can replay.
-- ===========================================================================

-- Forward-declared; lives in the CONTINUOUS section below (no longer needed by scan_and_mutate).
local _cached_mutations  -- legacy reference kept for reset()

-- Forward-declared continuous-mode state (defined in CONTINUOUS section below).
-- Declared here so apply_once() can reference build_target_cache.
local _cached_targets
local build_target_cache

local function scan_and_mutate(tbl, prefix, depth)
    if type(tbl) ~= "table" then return 0, 0 end
    if depth > 1 then return 0, 0 end  -- max 1 level of nesting

    local changed, total = 0, 0
    for k, v in pairs(tbl) do
        local label = prefix .. tostring(k)

        if type(v) == "table" then
            local r, g, b, a = read_rgba(v)
            if r then
                -- It's a color entry
                total = total + 1
                if is_purple(r, g, b) then
                    local nr, ng, nb
                    if is_danger_pink(r, g, b) then
                        nr, ng, nb = transform_danger(r, g, b)
                    else
                        nr, ng, nb = derive_target(r, g, b, _accent[1], _accent[2], _accent[3])
                    end
                    if mutate_color(tbl, k, v, nr, ng, nb, a) then
                        changed = changed + 1
                        log("[EaxRotations:ThemeOverride]   " .. label
                            .. ": RGB(" .. r .. "," .. g .. "," .. b .. ") → RGB("
                            .. nr .. "," .. ng .. "," .. nb .. ")")
                    end
                end
            elseif depth == 0 then
                -- Subtable that's not a color — recurse one level (e.g. accent = { hover=col, ... })
                local sc, st = scan_and_mutate(v, label .. ".", depth + 1)
                changed = changed + sc
                total = total + st
            end
        end
    end
    return changed, total
end

-- ===========================================================================
-- Public API
-- ===========================================================================



-- Singleton guards for one-shot apply (legacy; kept for initial load-time log).
local _applied = false
local _no_purples = false
local _retry_count = 0
local MAX_RETRIES = 120  -- ~2 seconds at 60fps; after this, stop probing.

function M.apply_once()
    if _applied or _no_purples then return _applied end
    if _retry_count >= MAX_RETRIES then return false end
    _retry_count = _retry_count + 1

    local palette, source = find_palette()
    if not palette then
        return false
    end

    -- BUILD THE TARGET CACHE FIRST while colors are still virgin purple.
    if not _cached_targets or #_cached_targets == 0 then
        build_target_cache()
    end

    local changed, total = scan_and_mutate(palette, "", 0)
    if changed > 0 then
        _applied = true
        log("[EaxRotations:ThemeOverride] Applied: " .. changed .. "/" .. total
            .. " colors recolored (via " .. tostring(source) .. ")")
        return true
    else
        _no_purples = true
        log("[EaxRotations:ThemeOverride] Palette found but no purple colors (" .. tostring(source)
            .. "); stopping retry.")
        return false
    end
end

-- ===========================================================================
-- CONTINUOUS (per-frame) re-application.
-- PS 2.010+ rebuilds palette colors from its backing store each frame, possibly
-- creating entirely new color objects. Caching object references doesn't help.
-- Instead we cache KEY PATHS + TARGET VALUES, re-find the palette each frame,
-- and REPLACE table entries with freshly constructed color objects.
-- ===========================================================================

-- Each entry: { path = {key1} or {key1, key2}, r=, g=, b=, a= }
_cached_targets = nil
local _continuous_retry = 0
local _color_mod = nil  -- cached require("common/color")

--- Build the target cache by scanning the palette once.
build_target_cache = function()
    local palette, source = find_palette()
    if not palette then return false end

    _cached_targets = {}

    local function cache_entries(tbl, parent_key, depth)
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                local r, g, b, a = read_rgba(v)
                if r then
                    if is_purple(r, g, b) then
                        local nr, ng, nb
                        if is_danger_pink(r, g, b) then
                            nr, ng, nb = transform_danger(r, g, b)
                        else
                            nr, ng, nb = derive_target(r, g, b, _accent[1], _accent[2], _accent[3])
                        end
                        local path = parent_key and {parent_key, k} or {k}
                        -- Store ORIGINAL purple values so we can re-derive on accent change
                        _cached_targets[#_cached_targets + 1] = {
                            path = path, r = nr, g = ng, b = nb, a = a or 255,
                            orig_r = r, orig_g = g, orig_b = b,
                            is_danger = is_danger_pink(r, g, b)
                        }
                    end
                elseif depth == 0 then
                    cache_entries(v, k, depth + 1)
                end
            end
        end
    end
    cache_entries(palette, nil, 0)

    -- Cache the color module for creating fresh objects
    local ok, cm = pcall(require, "common/color")
    if ok and cm then _color_mod = cm end

    if #_cached_targets > 0 then
        log("[EaxRotations:ThemeOverride] Continuous: cached "
            .. #_cached_targets .. " target entries (via " .. tostring(source) .. ")")
        return true
    end
    return false
end

--- Replay: re-find palette, replace entries with fresh color objects.
local function replay_targets()
    local palette = find_palette()
    if not palette then return end

    for i = 1, #_cached_targets do
        local entry = _cached_targets[i]
        local path = entry.path
        local target_tbl, target_key

        if #path == 1 then
            target_tbl = palette
            target_key = path[1]
        else
            -- Nested: path[1] is the subtable key, path[2] is the color key
            local sub = palette[path[1]]
            if type(sub) == "table" then
                target_tbl = sub
                target_key = path[2]
            end
        end

        if target_tbl and target_key then
            -- Mutate the EXISTING palette entry IN PLACE. Do NOT replace the
            -- reference (target_tbl[key] = new_obj) — PS caches C++ pointers
            -- to the original table objects and won't see replacements.
            local existing = target_tbl[target_key]
            if type(existing) == "table" then
                existing[1], existing[2], existing[3], existing[4] = entry.r, entry.g, entry.b, entry.a
                existing.r, existing.g, existing.b, existing.a = entry.r, entry.g, entry.b, entry.a
                if type(existing.set) == "function" then
                    pcall(existing.set, existing, entry.r, entry.g, entry.b, entry.a)
                end
            end
        end
    end
end

--- Re-derive cached target values when the accent color changes.
--- Only recalculates r/g/b for non-danger entries (danger is always red-orange).
local function rederive_targets()
    local ar, ag, ab = _accent[1], _accent[2], _accent[3]
    for i = 1, #_cached_targets do
        local entry = _cached_targets[i]
        if not entry.is_danger then
            entry.r, entry.g, entry.b = derive_target(
                entry.orig_r, entry.orig_g, entry.orig_b, ar, ag, ab)
        end
    end
    _last_accent[1], _last_accent[2], _last_accent[3] = ar, ag, ab
end

--- apply_continuous: call every frame from on_render callback.
--- If accent changed since last frame, re-derives all targets.
--- Then replays cached writes to the palette.
function M.apply_continuous()
    if _cached_targets and #_cached_targets > 0 then
        -- Check if accent color changed (user moved color picker)
        if _accent[1] ~= _last_accent[1] or _accent[2] ~= _last_accent[2]
           or _accent[3] ~= _last_accent[3] then
            rederive_targets()
        end
        replay_targets()
        return true
    end
    -- Not cached yet — try to build (palette might not be ready yet)
    if _continuous_retry > MAX_RETRIES then return false end
    _continuous_retry = _continuous_retry + 1
    return build_target_cache()
end

--- Reset all state (for testing or re-applying after a theme change).
function M.reset()
    _applied = false
    _no_purples = false
    _retry_count = 0
    _cached_targets = nil
    _color_mod = nil
    _continuous_retry = 0
end

--- Restore the original purple palette values. Call AFTER rendering to undo
--- the scoped mutation so other plugins see the untouched palette.
function M.restore_palette()
    if not _cached_targets or #_cached_targets == 0 then return end
    local palette = find_palette()
    if not palette then return end

    for i = 1, #_cached_targets do
        local entry = _cached_targets[i]
        local path = entry.path
        local target_tbl, target_key

        if #path == 1 then
            target_tbl = palette
            target_key = path[1]
        else
            local sub = palette[path[1]]
            if type(sub) == "table" then
                target_tbl = sub
                target_key = path[2]
            end
        end

        if target_tbl and target_key then
            local existing = target_tbl[target_key]
            if type(existing) == "table" then
                existing[1], existing[2], existing[3] = entry.orig_r, entry.orig_g, entry.orig_b
                existing[4] = entry.a
                existing.r, existing.g, existing.b, existing.a = entry.orig_r, entry.orig_g, entry.orig_b, entry.a
                if type(existing.set) == "function" then
                    pcall(existing.set, existing, entry.orig_r, entry.orig_g, entry.orig_b, entry.a)
                end
            end
        end
    end
end

return M

