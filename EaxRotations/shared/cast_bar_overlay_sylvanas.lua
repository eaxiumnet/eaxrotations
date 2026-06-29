-- cast_bar_overlay_sylvanas.lua -- in-game cast-bar overlay drawn over the engine's main HUD canvas.
-- WHAT:   in-game cast-bar overlay drawn over the engine's main HUD canvas.
-- WHEN:   called per-frame to refresh the cast-bar widget
-- WHY:    shows NEXT spell + ETA so user can verify rotation intent
-- SAFETY: draws to canvas only; no api on hot path
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.


-- ============================================================================
-- EaxRotations Cast-Bar Overlay Module
-- ============================================================================
-- What: Class-specific cast-bar overlay with haste-aware tick markers for
--       channeled spells (Mind Flay, Drain Life, Arcane Missiles, etc.)
-- When: Rendered inside the dashboard when the player is actively channeling.
-- Why:  Provides visual feedback for channeled spell timing, tick landing,
--       and optimal clip points (e.g., Mind Flay tick 2).
-- Safety: Pure computation + rendering; no spell casts or game-state mutations.
-- Decision:
--   - Integrated into dashboard rather than standalone window to reduce UI clutter.
--   - Haste derived from known buffs (Bloodlust, Heroism, PI, Icy Veins).
--   - Tick intervals are base values; adjusted by haste multiplier dynamically.
--   - Spell registry is centralized here rather than scattered across class files
--     because the data is UI-centric (duration/ticks) not rotation-logic.
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local floor = math.floor
local max = math.max
local min = math.min
local format = string.format
local ipairs = ipairs
local vec2 = require("common/geometry/vector_2")
local color = require("common/color")

local M = {}

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

local CAST_BAR_HEIGHT = 10
local TICK_MARKER_WIDTH = 2
local CLIP_MARKER_WIDTH = 3
local BAR_BG_ALPHA = 180
local BAR_FILL_ALPHA = 220
local TICK_ALPHA = 255
local TEXT_ALPHA = 220

-- ---------------------------------------------------------------------------
-- Channeled Spell Registry (TBC / Classic)
--   key: spell name for lookup
--   ids: all rank spell IDs (highest rank first for get_spell_id resolution)
--   base_duration: base channel duration in seconds
--   tick_interval: base time between ticks in seconds
--   ticks: number of ticks over the full channel
--   clip_tick: tick number after which it is safe to clip (nil = don't clip)
--   class: owning class name (for optional filtering)
-- ---------------------------------------------------------------------------
M.CHANNEL_SPELLS = {
    -- Priest
    MindFlay = {
        ids = {25387, 18807, 17314, 17313, 17312, 17311, 15407},
        base_duration = 3.0,
        tick_interval = 1.0,
        ticks = 3,
        clip_tick = 2,
        class = "Priest",
    },
    -- Warlock
    DrainLife = {
        ids = {27220, 27219, 11700, 11699, 7651, 709, 699, 689},
        base_duration = 5.0,
        tick_interval = 1.0,
        ticks = 5,
        clip_tick = nil,
        class = "Warlock",
    },
    DrainSoul = {
        ids = {27217, 11675, 8289, 8288, 1120},
        base_duration = 15.0,
        tick_interval = 3.0,
        ticks = 5,
        clip_tick = nil,
        class = "Warlock",
    },
    RainOfFire = {
        ids = {27213, 11678, 11677, 5740},
        base_duration = 8.0,
        tick_interval = 2.0,
        ticks = 4,
        clip_tick = nil,
        class = "Warlock",
    },
    Hellfire = {
        ids = {27214, 27213, 11684, 11683, 1949},
        base_duration = 8.0,
        tick_interval = 2.0,
        ticks = 4,
        clip_tick = nil,
        class = "Warlock",
    },
    -- Mage
    ArcaneMissiles = {
        ids = {25345, 10274, 10273, 8417, 8416, 5145, 5144, 5143},
        base_duration = 5.0,
        tick_interval = 1.0,
        ticks = 5,
        clip_tick = nil,
        class = "Mage",
    },
    Blizzard = {
        ids = {27085, 10187, 10186, 10185, 8427, 6141, 10},
        base_duration = 8.0,
        tick_interval = 1.0,
        ticks = 8,
        clip_tick = nil,
        class = "Mage",
    },
    Evocation = {
        ids = {12051},
        base_duration = 8.0,
        tick_interval = 2.0,
        ticks = 4,
        clip_tick = nil,
        class = "Mage",
    },
    -- Druid
    Hurricane = {
        ids = {27012, 17402, 17401, 16914},
        base_duration = 10.0,
        tick_interval = 1.0,
        ticks = 10,
        clip_tick = nil,
        class = "Druid",
    },
    Tranquility = {
        ids = {26983, 9863, 9862, 8918, 740},
        base_duration = 8.0,
        tick_interval = 2.0,
        ticks = 4,
        clip_tick = nil,
        class = "Druid",
    },
    -- Hunter
    Volley = {
        ids = {27022, 14295, 14294, 1510},
        base_duration = 6.0,
        tick_interval = 1.0,
        ticks = 6,
        clip_tick = nil,
        class = "Hunter",
    },
}

-- Build a fast ID -> spell info lookup table
local _id_to_spell = {}
for key, info in pairs(M.CHANNEL_SPELLS) do
    if info.ids then
        for _, id in ipairs(info.ids) do
            _id_to_spell[id] = info
        end
    end
end

-- ---------------------------------------------------------------------------
-- Haste Detection
-- ---------------------------------------------------------------------------

-- Known flat-percentage haste buffs in TBC Classic.
-- Gear haste rating is NOT detected here (no API); buff-based is sufficient
-- for the visual overlay. Minor gear haste deviations are acceptable.
local HASTE_BUFFS = {
    { ids = {2825, 32182},  name = "Bloodlust/Heroism", pct = 30 },  -- 30%
    { ids = {10060},         name = "Power Infusion",   pct = 20 },  -- 20%
    { ids = {12472},         name = "Icy Veins",        pct = 20 },  -- 20%
}

---@return number haste_multiplier  e.g. 1.3 for 30% haste
function M.get_haste_multiplier(unit)
    if not unit then return 1.0 end
    local total_pct = 0
    for _, buff in ipairs(HASTE_BUFFS) do
        if NS.buff_up and NS.buff_up(unit, buff.ids) then
            total_pct = total_pct + buff.pct
        end
    end
    -- Buff haste is additive with itself, then multiplicative on cast speed.
    -- 30% haste = cast takes 1/1.3 of base time.
    return max(1.0, 1.0 + (total_pct / 100.0))
end

-- ---------------------------------------------------------------------------
-- Channel State Detection
-- ---------------------------------------------------------------------------

---@return table|nil spell_info
---@return number start_time_ms
---@return number elapsed_s
function M.get_channel_state(me)
    if not me then return nil, 0, 0 end

    local is_channeling = false
    local channel_spell_id = 0
    local channel_start_ms = 0

    -- Prefer is_channeling / get_active_channel_spell_id APIs
    local ok1, val1 = pcall(function() return me.is_channeling and me:is_channeling() end)
    if ok1 and val1 == true then
        is_channeling = true
    else
        local ok2, val2 = pcall(function() return me.is_channelling_spell and me:is_channelling_spell() end)
        if ok2 and val2 == true then
            is_channeling = true
        end
    end

    if not is_channeling then
        -- Some builds only expose is_channeling_or_casting
        local ok3, val3 = pcall(function() return me.is_channeling_or_casting and me:is_channeling_or_casting() end)
        if not (ok3 and val3 == true) then
            return nil, 0, 0
        end
    end

    -- Resolve active spell ID
    local ok4, val4 = pcall(function() return me.get_active_channel_spell_id and me:get_active_channel_spell_id() end)
    if ok4 and type(val4) == "number" and val4 > 0 then
        channel_spell_id = val4
    else
        local ok5, val5 = pcall(function() return me.get_active_spell_id and me:get_active_spell_id() end)
        if ok5 and type(val5) == "number" and val5 > 0 then
            channel_spell_id = val5
        end
    end

    local spell_info = _id_to_spell[channel_spell_id]
    if not spell_info then
        return nil, 0, 0
    end

    -- Resolve channel start time
    local ok6, val6 = pcall(function() return me.get_active_channel_cast_start_time and me:get_active_channel_cast_start_time() end)
    if ok6 and type(val6) == "number" and val6 > 0 then
        channel_start_ms = val6
    else
        local ok7, val7 = pcall(function() return me.get_active_spell_cast_start_time and me:get_active_spell_cast_start_time() end)
        if ok7 and type(val7) == "number" and val7 > 0 then
            channel_start_ms = val7
        end
    end

    local game_time_ms = (NS.game_time_ms and NS.game_time_ms()) or (NS.time_now and NS.time_now() * 1000) or 0
    if channel_start_ms <= 0 or game_time_ms <= 0 then
        -- Cannot compute elapsed; assume just started
        return spell_info, 0, 0
    end

    local elapsed_s = (game_time_ms - channel_start_ms) / 1000.0
    return spell_info, channel_start_ms, elapsed_s
end

-- ---------------------------------------------------------------------------
-- Render Helpers
-- ---------------------------------------------------------------------------

local RENDER_COLORS = {
    bar_bg        = { r = 20,  g = 20,  b = 30,  a = BAR_BG_ALPHA },
    bar_fill      = { r = 108, g = 99,  b = 255, a = BAR_FILL_ALPHA },
    bar_fill_clip = { r = 255, g = 180, b = 0,   a = BAR_FILL_ALPHA },
    tick          = { r = 255, g = 255, b = 255, a = TICK_ALPHA },
    tick_clip     = { r = 0,   g = 255, b = 100, a = TICK_ALPHA },
    text          = { r = 220, g = 220, b = 228, a = TEXT_ALPHA },
    text_dim      = { r = 148, g = 148, b = 168, a = TEXT_ALPHA },
}

-- Convert raw table to color.new if available, else pass through
local function make_color(tbl)
    if color and color.new then
        return color.new(tbl.r, tbl.g, tbl.b, tbl.a)
    end
    -- Fallback for unit tests / environments without color module
    return tbl
end

local _color_cache = {}
for k, v in pairs(RENDER_COLORS) do
    _color_cache[k] = make_color(v)
end

-- ---------------------------------------------------------------------------
-- Main Render Function
-- ---------------------------------------------------------------------------

--- Render the cast-bar overlay inside the given dashboard_window.
-- @param dashboard_window   core.menu.window object (has render_rect, render_rect_filled, add_text_on_dynamic_pos, etc.)
-- @param bar_max_width      maximum width of the bar in pixels (e.g. FRAME_WIDTH - 18)
-- @param context            optional rotation context (for in_combat gating)
-- @return boolean           true if something was rendered
function M.render(dashboard_window, bar_max_width, context)
    if not dashboard_window or not bar_max_width then return false end

    local me = NS.GetPlayer and NS.GetPlayer()
    if not me then return false end

    local spell_info, _, elapsed_s = M.get_channel_state(me)
    if not spell_info then return false end

    local haste_multiplier = M.get_haste_multiplier(me)
    local adjusted_duration = spell_info.base_duration / haste_multiplier
    local adjusted_interval = spell_info.tick_interval / haste_multiplier

    -- Cap elapsed to duration (API jitter can overshoot)
    elapsed_s = min(elapsed_s, adjusted_duration)

    local progress_pct = (elapsed_s / adjusted_duration)
    if progress_pct > 1 then progress_pct = 1 end
    if progress_pct < 0 then progress_pct = 0 end

    local fill_width = bar_max_width * progress_pct
    local bar_height = CAST_BAR_HEIGHT

    -- Determine fill color (turn green-ish when past clip point)
    local ticks_landed = floor(elapsed_s / adjusted_interval)
    local past_clip = spell_info.clip_tick and ticks_landed >= spell_info.clip_tick
    local fill_color = past_clip and _color_cache.bar_fill_clip or _color_cache.bar_fill

    -- Background bar
    local bg_min = vec2.new(0, 0)
    local bg_max = vec2.new(bar_max_width, bar_height)
    dashboard_window:render_rect_filled(bg_min, bg_max, _color_cache.bar_bg, 0)
    dashboard_window:render_rect(bg_min, bg_max, _color_cache.text_dim, 1)

    -- Fill bar
    if fill_width > 0 then
        local fill_min = vec2.new(0, 0)
        local fill_max = vec2.new(fill_width, bar_height)
        dashboard_window:render_rect_filled(fill_min, fill_max, fill_color, 0)
    end

    -- Tick markers
    for t = 1, spell_info.ticks - 1 do
        local tick_x = bar_max_width * ((t * adjusted_interval) / adjusted_duration)
        if tick_x > 0 and tick_x < bar_max_width then
            local is_clip_tick = spell_info.clip_tick and t == spell_info.clip_tick
            local tick_color = is_clip_tick and _color_cache.tick_clip or _color_cache.tick
            local tick_min = vec2.new(tick_x, 0)
            local tick_max = vec2.new(tick_x + TICK_MARKER_WIDTH, bar_height)
            dashboard_window:render_rect_filled(tick_min, tick_max, tick_color, 0)
        end
    end

    dashboard_window:draw_next_dynamic_widget_on_new_line()

    -- Label text
    local label
    local next_tick_s = 0
    if ticks_landed < spell_info.ticks then
        local next_tick_at = (ticks_landed + 1) * adjusted_interval
        next_tick_s = max(0, next_tick_at - elapsed_s)
    end
    if next_tick_s > 0 then
        label = spell_info.class .. "  Tick " .. (ticks_landed + 1) .. "/" .. spell_info.ticks ..
                "  (" .. format("%.1fs", next_tick_s) .. ")"
    else
        label = spell_info.class .. "  Complete"
    end

    dashboard_window:add_text_on_dynamic_pos(_color_cache.text, label)
    dashboard_window:draw_next_dynamic_widget_on_new_line()

    return true
end

-- ---------------------------------------------------------------------------
-- NS Integration
-- ---------------------------------------------------------------------------

if NS then
    NS.CastBarOverlay = M
end

return M
