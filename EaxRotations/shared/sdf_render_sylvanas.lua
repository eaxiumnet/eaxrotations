-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/sdf_render_sylvanas.lua"
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
-- ============================================================================
-- Shared Helper: SDF Rendering Bridge
-- Bridges core.graphics SDF shader APIs with pcall-safe wrappers.
-- Converts top_left/w+h convetion to p_min/p_max for SDF functions.
-- ============================================================================

local M = {}
local _G = _G
local vec2 = require("common/geometry/vector_2")

-- Cache SDF API refs at load
local _render_smooth_rect = core.graphics.render_smooth_rect
local _render_drop_shadow = core.graphics.render_drop_shadow
local _render_border_rect = core.graphics.render_border_rect
local _render_linear_gradient = core.graphics.render_linear_gradient
local _render_keybind_pill = core.graphics.render_keybind_pill
local _render_dropdown_field = core.graphics.render_dropdown_field
local _render_section_header = core.graphics.render_section_header
local _render_slider_track = core.graphics.render_slider_track
local _render_hover_pill = core.graphics.render_hover_pill

-- Legacy API refs (for fallback)
local _rect_2d_filled = core.graphics.rect_2d_filled
local _rect_2d = core.graphics.rect_2d
local _text_2d = core.graphics.text_2d

-- ============================================================================
-- pcp-buffered vec2 bridging helper (no allocation per call)
-- ============================================================================
local _pmin = vec2.new(0, 0)
local _pmax = vec2.new(0, 0)

--- Converts top_left + w + h to p_min/p_max in pre-allocated buffers.
--- Returns p_min, p_max (reused across calls - DO NOT store references).
---@param x number
---@param y number
---@param w number
---@param h number
---@return vec2 p_min
---@return vec2 p_max
local function top_left_to_pmin_pmax(x, y, w, h)
    _pmin.x = x
    _pmin.y = y
    _pmax.x = x + w
    _pmax.y = y + h
    return _pmin, _pmax
end

-- ============================================================================
-- SDF Render Functions (pcall-safe)
-- ============================================================================

--- Draws a smooth rounded rectangle via SDF shader.
--- Falls back to rect_2d_filled if SDF unavailable.
---@param top_left_x number
---@param top_left_y number
---@param w number
---@param h number
---@param fill_color table RGBA color
---@param rounding? number Default 4
---@param softness? number Default 1
function M.smooth_rect(top_left_x, top_left_y, w, h, fill_color, rounding, softness)
    if not _render_smooth_rect then
        -- Fallback: legacy rect_2d_filled
        if _rect_2d_filled then
            pcall(_rect_2d_filled, vec2.new(top_left_x, top_left_y), w, h, fill_color, rounding or 0)
        end
        return
    end
    local pmin, pmax = top_left_to_pmin_pmax(top_left_x, top_left_y, w, h)
    pcall(_render_smooth_rect, pmin, pmax, fill_color, rounding, softness)
end

--- Draws a drop shadow behind an element via SDF shader.
---@param element_x number Element top-left X
---@param element_y number Element top-left Y
---@param element_w number Element width
---@param element_h number Element height
---@param shadow_color table RGBA shadow color
---@param offset_x? number Horizontal offset (default 2)
---@param offset_y? number Vertical offset (default 2)
---@param rounding? number Default 6
---@param softness? number Default 8
---@param spread? number Default 0
function M.drop_shadow(element_x, element_y, element_w, element_h, shadow_color, offset_x, offset_y, rounding, softness, spread)
    if not _render_drop_shadow then return end
    local ox = offset_x or 2
    local oy = offset_y or 2
    -- Shadow quad: extends beyond element by (spread + softness) margin
    local margin = (spread or 0) + (softness or 8)
    local pmin = vec2.new(element_x - margin + ox, element_y - margin + oy)
    local pmax = vec2.new(element_x + element_w + margin + ox, element_y + element_h + margin + oy)
    pcall(_render_drop_shadow, pmin, pmax, shadow_color, ox, oy, element_w, element_h, rounding, softness, spread)
end

--- Draws a filled rectangle with a border via SDF shader.
---@param x number Top-left X
---@param y number Top-left Y
---@param w number Width
---@param h number Height
---@param fill_color table RGBA fill
---@param border_color table RGBA border
---@param rounding? number Default 4
---@param softness? number Default 1
---@param thickness? number Default 1
function M.border_rect(x, y, w, h, fill_color, border_color, rounding, softness, thickness)
    if not _render_border_rect then
        -- Fallback: two separate draw calls
        if _rect_2d_filled then
            pcall(_rect_2d_filled, vec2.new(x, y), w, h, fill_color, rounding or 0)
        end
        if _rect_2d then
            pcall(_rect_2d, vec2.new(x, y), w, h, border_color, thickness or 1, rounding or 0)
        end
        return
    end
    local pmin, pmax = top_left_to_pmin_pmax(x, y, w, h)
    pcall(_render_border_rect, pmin, pmax, fill_color, border_color, rounding, softness, thickness)
end

--- Draws a linear gradient rectangle via SDF shader.
---@param x number Top-left X
---@param y number Top-left Y
---@param w number Width
---@param h number Height
---@param color_a table Start color
---@param color_b table End color
---@param angle? number Radians (default 0 = left-to-right)
---@param rounding? number Default 0
---@param softness? number Default 0
function M.linear_gradient(x, y, w, h, color_a, color_b, angle, rounding, softness)
    if not _render_linear_gradient then
        -- Fallback: flat fill with color_a
        if _rect_2d_filled then
            pcall(_rect_2d_filled, vec2.new(x, y), w, h, color_a, rounding or 0)
        end
        return
    end
    local pmin, pmax = top_left_to_pmin_pmax(x, y, w, h)
    pcall(_render_linear_gradient, pmin, pmax, color_a, color_b, angle, rounding, softness)
end

--- Draws a hover pill with animated streaks via SDF shader.
---@param x number
---@param y number
---@param w number
---@param h number
---@param base_color table
---@param streak_color table
---@param time_val number Animation time
---@param rounding? number Default 6
---@param softness? number Default 1
---@param density? number Default 1
---@param speed? number Default 1
function M.hover_pill(x, y, w, h, base_color, streak_color, time_val, rounding, softness, density, speed)
    if not _render_hover_pill then
        if _rect_2d_filled then
            pcall(_rect_2d_filled, vec2.new(x, y), w, h, base_color, rounding or 6)
        end
        return
    end
    local pmin, pmax = top_left_to_pmin_pmax(x, y, w, h)
    pcall(_render_hover_pill, pmin, pmax, base_color, streak_color, rounding, softness, density, time_val, speed)
end

--- Draws a keybind pill widget via SDF shader.
---@param x number
---@param y number
---@param w number
---@param h number
---@param base_color table
---@param elevation_color table
---@param accent_color table
---@param hover number 0-1
---@param listening number 0-1
---@param time_val number
---@param rounding? number Default 6
---@param speed? number Default 1
function M.keybind_pill(x, y, w, h, base_color, elevation_color, accent_color, hover, listening, time_val, rounding, speed)
    if not _render_keybind_pill then
        if _rect_2d_filled then
            pcall(_rect_2d_filled, vec2.new(x, y), w, h, base_color, rounding or 6)
        end
        return
    end
    local pmin, pmax = top_left_to_pmin_pmax(x, y, w, h)
    pcall(_render_keybind_pill, pmin, pmax, base_color, elevation_color, accent_color, rounding, hover, listening, time_val, speed)
end

--- Draws a dropdown field widget via SDF shader.
---@param x number
---@param y number
---@param w number
---@param h number
---@param base_color table
---@param elevation_color table
---@param accent_color table
---@param hover number 0-1
---@param open number 0-1
---@param time_val number
---@param rounding? number Default 4
---@param speed? number Default 1
function M.dropdown_field(x, y, w, h, base_color, elevation_color, accent_color, hover, open, time_val, rounding, speed)
    if not _render_dropdown_field then
        if _rect_2d_filled then
            pcall(_rect_2d_filled, vec2.new(x, y), w, h, base_color, rounding or 4)
        end
        return
    end
    local pmin, pmax = top_left_to_pmin_pmax(x, y, w, h)
    pcall(_render_dropdown_field, pmin, pmax, base_color, elevation_color, accent_color, rounding, hover, open, time_val, speed)
end

--- Draws a section header widget via SDF shader.
---@param x number
---@param y number
---@param w number
---@param h number
---@param primary_color table
---@param secondary_color table
---@param accent_color table
---@param head_split number 0-1
---@param hover number 0-1
---@param open number 0-1
---@param time_val number
---@param rounding? number Default 4
---@param speed? number Default 1
function M.section_header(x, y, w, h, primary_color, secondary_color, accent_color, head_split, hover, open, time_val, rounding, speed)
    if not _render_section_header then
        if _rect_2d_filled then
            pcall(_rect_2d_filled, vec2.new(x, y), w, h, primary_color, rounding or 4)
        end
        return
    end
    local pmin, pmax = top_left_to_pmin_pmax(x, y, w, h)
    pcall(_render_section_header, pmin, pmax, primary_color, secondary_color, accent_color, head_split, rounding, hover, open, time_val, speed)
end

--- Draws a slider track widget via SDF shader.
---@param x number
---@param y number
---@param w number
---@param h number
---@param fill_lo table Low-end fill color
---@param fill_hi table High-end fill color
---@param rail_color table Rail color
---@param fill_t number Fill progress 0-1
---@param hover number 0-1
---@param time_val number
---@param rounding? number Default 3
---@param speed? number Default 1
function M.slider_track(x, y, w, h, fill_lo, fill_hi, rail_color, fill_t, hover, time_val, rounding, speed)
    if not _render_slider_track then
        -- Fallback: draw filled portion + outline
        if _rect_2d_filled then
            local fill_w = w * fill_t
            if fill_w > 0 then
                pcall(_rect_2d_filled, vec2.new(x, y), fill_w, h, fill_lo, rounding or 0)
            end
            pcall(_rect_2d, vec2.new(x, y), w, h, rail_color, 1, rounding or 3)
        end
        return
    end
    local pmin, pmax = top_left_to_pmin_pmax(x, y, w, h)
    pcall(_render_slider_track, pmin, pmax, fill_lo, fill_hi, rail_color, fill_t, rounding, hover, time_val, speed)
end

-- ============================================================================
-- Utility: draw text with pcall safety
-- ============================================================================

--- Draws text via core.graphics.text_2d with pcall safety.
---@param text string
---@param x number
---@param y number
---@param font_size number
---@param color table RGBA
---@param centered? boolean
---@param font_id? integer
function M.text(text, x, y, font_size, color, centered, font_id)
    if not _text_2d then return end
    pcall(_text_2d, text, vec2.new(x, y), font_size, color, centered, font_id)
end

-- ============================================================================
-- Export
-- ============================================================================

return M
