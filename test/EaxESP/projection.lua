-- ============================================================================
-- EaxESP - World-to-Screen Projection Helpers
-- ----------------------------------------------------------------------------
-- What: Wraps core.graphics.w2s (which returns a single vec2 {x,y} per
--   api/core.lua:2243 / docs.graphics.md) and applies the FPS-
--   conscious culls every ESP candidate must clear before drawing.
-- When: Called once per visible candidate per frame from renderer.lua.
-- Why: Centralising the math lets us unit-test it. The renderer is a
--   pure consumer of project_box(left, top, w, h, ...).
-- Safety: Pure functions. w2s is pcall-safe by API contract; we still
--   pcall it as belt-and-braces. Returns nil (not raise).
-- NOTE: project_box uses screen-space aspect-ratio sizing (feet+head
--   projection for natural height, fallback MIN_BOX_H=24px for
--   overhead camera angles). Width is height × aspect — no angle-
--   dependent side-anchor projection. This fixes: (a) boxes
--   disappearing from overhead, (b) angle-dependent distortion,
--   (c) self-ESP being wider than character (old 1.5yd radius).
-- ============================================================================

local M = {}

-- Module-level state: only the screen size + padding change per frame.
-- Renderer/main stamps these via M.begin_frame() before each render pass.
local _sx, _sy   = 0, 0
local _pad    = 4
local _min_pix_dim  = 8
local _max_pix_dim  = 600

-- Optional vector_3 module — w2s may require a real vec3 userdata.
local _vec3
local function ensure_vec3()
 if _vec3 then return _vec3 end
 local ok, mod = pcall(require, "common/geometry/vector_3")
 if ok and mod and type(mod.new) == "function" then
  _vec3 = mod
 end
 return _vec3
end

local function to_vec3(t)
 local v3 = ensure_vec3()
 if not v3 or type(t) ~= "table" then return t end
 return v3.new(t.x or 0, t.y or 0, t.z or 0)
end

-- Scratch vec3 reused per candidate for head projection (Pattern 4).
local _scratch_head = { x = 0, y = 0, z = 0 }

local MIN_BOX_H = 24 -- fallback height (px) when camera is overhead
local MIN_ASPECT = 0.3
local MAX_ASPECT = 1.2
local ASPECT_CORRECTION = 0.9 -- screen-space Y is compressed vs X in WoW perspective


--- Initialise per-frame constants. Call once at start of each render pass.
---@param sx number screen width (px)
---@param sy number screen height (px)
---@param pad number off-screen padding (px)
---@param min_pix_dim? number
---@param max_pix_dim? number
function M.begin_frame(sx, sy, pad, min_pix_dim, max_pix_dim)
 _sx = sx or 1920
 _sy = sy or 1080
 _pad = pad or 4
 _min_pix_dim = min_pix_dim or 8
 _max_pix_dim = max_pix_dim or 600
 return true
end

--- Safe pcall wrapper around core.graphics.w2s.
--- Returns (sx, sy) as two numbers, or (nil, nil) if the position is
--- behind the camera / off-clip / w2s itself raised.
---@param w2s fun(p: vec3): vec2
---@param position vec3
---@return number|nil sx
---@return number|nil sy
local function safe_w2s(w2s, position)
 if type(w2s) ~= "function" or not position then return nil, nil end
 local pos = to_vec3(position)
 local ok, vec = pcall(w2s, pos)
 if not ok or (type(vec) ~= "table" and type(vec) ~= "userdata") then return nil, nil end
 local sx, sy = vec.x, vec.y
 if type(sx) ~= "number" or type(sy) ~= "number" then return nil, nil end
 return sx, sy
end

--- Compute pixel-space rectangle for a candidate whose feet are at `feet_pos`
--- with `unit_height` world-units of vertical extent and `unit_radius` yards
--- of horizontal half-width (default 1.5 — typical humanoid radii).
---
--- Returns (nil) when the candidate MUST NOT be drawn this frame:
--- - feet w2s returned nil (behind camera)
--- - either dimension smaller than _min_pix_dim (too far / too tiny)
--- - either dimension larger than _max_pix_dim (clipped / giant)
--- - box is entirely outside the screen rect minus _pad
---
--- Returns (left, top, box_w, box_h, feet_x, feet_y, head_x, head_y) on hit.
---@param w2s fun(p: vec3): vec2
---@param feet_pos vec3
---@param unit_height number
---@param unit_radius? number default 1.5 yards
---@return number|nil left
---@return number|nil top
---@return number|nil box_w
---@return number|nil box_h
---@return number|nil feet_x
---@return number|nil feet_y
---@return number|nil head_x
---@return number|nil head_y
function M.project_box(w2s, feet_pos, unit_height, unit_radius)
 local feet_x, feet_y = safe_w2s(w2s, feet_pos)
 if not feet_x then return nil end

 local h = (unit_height and unit_height > 0) and unit_height or 2.0
 local r = (unit_radius and unit_radius > 0) and unit_radius or 0.5

 _scratch_head.x = feet_pos.x
 _scratch_head.y = feet_pos.y
 _scratch_head.z = (feet_pos.z or 0) + h
 local head_x, head_y = safe_w2s(w2s, _scratch_head)

 local natural_h = (head_y and head_y) and math.abs(feet_y - head_y) or 0
 local box_h = math.max(natural_h, MIN_BOX_H)
 box_h = math.min(_max_pix_dim, box_h)

 local world_aspect = (r * 2) / h
 local aspect = world_aspect * ASPECT_CORRECTION
 if aspect < MIN_ASPECT then aspect = MIN_ASPECT end
 if aspect > MAX_ASPECT then aspect = MAX_ASPECT end
 local box_w = box_h * aspect
 box_w = math.min(_max_pix_dim, box_w)

 if box_w < _min_pix_dim or box_h < _min_pix_dim then return nil end

 local left = feet_x - box_w * 0.5
 local top = feet_y - box_h
 local right = left + box_w
 local bottom = top + box_h

 if right < _pad or bottom < _pad then return nil end
 if left > _sx - _pad or top > _sy - _pad then return nil end

 local hx = head_x or feet_x
 local hy = head_y or top

 return left, top, box_w, box_h, feet_x, feet_y, hx, hy
end

--- project_box_min_size: like project_box but forces returned dims >= min_dim
--- (for screen-space visibility guarantee floor). Still respects _max_pix_dim
--- and off-screen culls. box_min_dim (_min_pix_dim) is the hard cull from begin_frame.
--- min_box_screen_dim (passed here) is the vis floor.
---@return number|nil left, top, w, h, feet_x, feet_y, head_x, head_y
function M.project_box_min_size(w2s, feet_pos, unit_height, unit_radius, min_dim)
 local left, top, bw, bh, fx, fy, hx, hy = M.project_box(w2s, feet_pos, unit_height, unit_radius)
 if not left then return nil end
 local md = (type(min_dim) == "number" and min_dim > 0) and min_dim or MIN_BOX_H
 bw = math.max(bw, md)
 bh = math.max(bh, md)
 -- re-center from feet
 left = fx - bw * 0.5
 top = fy - bh
 if bw > _max_pix_dim or bh > _max_pix_dim then return nil end
 -- re-apply offscreen cull with new size
 local right = left + bw
 local bottom = top + bh
 if right < _pad or bottom < _pad then return nil end
 if left > _sx - _pad or top > _sy - _pad then return nil end
 return left, top, bw, bh, fx, fy, hx or fx, hy or top
end

--- project_box_from_sp: use precomputed screen feet/head to avoid duplicate w2s.
--- Applies MIN_BOX_H fallback + min_dim floor + aspect + max cull + offscreen.
--- For use when renderer already has feet_sp.
---@return number|nil left, top, w, h, feet_x, feet_y, head_x, head_y
function M.project_box_from_sp(feet_sp, head_sp, unit_height, unit_radius, min_dim)
 if not feet_sp or type(feet_sp.x) ~= "number" or type(feet_sp.y) ~= "number" then return nil end
 local fx, fy = feet_sp.x, feet_sp.y
 local h = (unit_height and unit_height > 0) and unit_height or 2.0
 local r = (unit_radius and unit_radius > 0) and unit_radius or 0.5
 local natural_h = (head_sp and type(head_sp.y) == "number") and math.abs(fy - head_sp.y) or 0
 local box_h = math.max(natural_h, MIN_BOX_H)
 local world_aspect = (r * 2) / h
 local aspect = world_aspect * ASPECT_CORRECTION
 if aspect < MIN_ASPECT then aspect = MIN_ASPECT end
 if aspect > MAX_ASPECT then aspect = MAX_ASPECT end
 local box_w = box_h * aspect
 local md = (type(min_dim) == "number" and min_dim > 0) and min_dim or MIN_BOX_H
 box_w = math.max(box_w, md)
 box_h = math.max(box_h, md)
 box_w = math.min(_max_pix_dim, box_w)
 box_h = math.min(_max_pix_dim, box_h)
 if box_w < _min_pix_dim or box_h < _min_pix_dim then return nil end
 local left = fx - box_w * 0.5
 local top = fy - box_h
 local right = left + box_w
 local bottom = top + box_h
 if right < _pad or bottom < _pad then return nil end
 if left > _sx - _pad or top > _sy - _pad then return nil end
 local hx = (head_sp and head_sp.x) or fx
 local hy = (head_sp and head_sp.y) or top
 return left, top, box_w, box_h, fx, fy, hx, hy
end

--- Squared distance between two vec3-like positions.
--- Returns a number; callers compare against pre-squared cap.
---@param a vec3|nil
---@param b vec3|nil
function M.squared_dist(a, b)
 if not a or not b then return math.huge end
 local dx = (a.x or 0) - (b.x or 0)
 local dy = (a.y or 0) - (b.y or 0)
 local dz = (a.z or 0) - (b.z or 0)
 return dx * dx + dy * dy + dz * dz
end

return M
