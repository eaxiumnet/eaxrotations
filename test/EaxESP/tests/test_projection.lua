-- ============================================================================
-- EaxESP/tests/test_projection.lua
-- ----------------------------------------------------------------------------
-- What: Unit tests for EaxESP/projection.lua — the w2s wrapper that culls
--   behind-camera, off-screen, too-tiny, and too-huge candidates.
-- When: `lua EaxESP/tests/test_projection.lua`
-- Why: Projection math is the only GPU/runtime-adjacent pipeline in our
--   ESP. If it culls wrong, we leak ghost boxes; if it lets through
--   garbage, the renderer spams pcall in a loop.
-- Safety: Pure tests; no real core call. Builds its own in-memory w2s.
-- ============================================================================

local script_path = (debug.getinfo(1, "S").source:match("@(.*[/\\])") or "./")
if script_path:sub(-1) ~= "/" and script_path:sub(-1) ~= "\\" then
 script_path = script_path .. "/"
end
package.path = script_path .. "../?.lua;" .. script_path .. "../?/init.lua;"
     .. package.path

local projection = require("projection")

local results = { pass = 0, fail = 0, fails = {} }
local function check(name, cond, detail)
 if cond then
  results.pass = results.pass + 1
 else
  results.fail = results.fail + 1
  results.fails[#results.fails + 1] = tostring(name)
       .. (detail and (" — " .. detail) or "")
 end
end

-- ============================================================================
-- Synthetic w2s — matches the real Sylvanas signature: returns a single
-- vec2 {x, y} (or nil when out-of-clip). Tests asserted this contract.
-- ============================================================================

local function make_w2s(opts)
 opts = opts or {}
 local origin = opts.origin or { x = 0, y = 0, z = 0 }
 local facing = opts.facing or { x = 0, y = 1, z = 0 }
 local scale = opts.scale or 100
 return function(pos)
  local dx = pos.x - origin.x
  local dy = pos.y - origin.y
  local dz = pos.z - origin.z
  local depth = dx * facing.x + dy * facing.y + dz * facing.z
  if depth <= 0.5 then return nil end
  local horizontal = -dx * facing.y + dy * facing.x
  local vertical = -dz
  return {
   x = 960 + horizontal * scale / depth,
   y = 540 + vertical * scale / depth,
  }
 end
end

-- ----------------------------------------------------------------------------
-- 1. squared_dist is correct.
-- ----------------------------------------------------------------------------
do
 local d = projection.squared_dist(
  { x = 1, y = 2, z = 3 }, { x = 4, y = 6, z = 3 })
 local expected = (3 * 3) + (4 * 4) + (0 * 0)
 check("squared_dist basic", d == expected)
end

do
 local d = projection.squared_dist(nil, { x = 1, y = 2, z = 3 })
 check("squared_dist nil-safe", d == math.huge)
end

-- ----------------------------------------------------------------------------
-- 2. project_box: behind-camera (w2s returns nil) → left is nil.
-- ----------------------------------------------------------------------------
do
 local w2s = make_w2s({ facing = { x = 0, y = 1, z = 0 }, scale = 100 })
 projection.begin_frame(1920, 1080, 4, 8, 600)
 local feet = { x = 0, y = -2, z = 0 } -- behind camera
 local left = projection.project_box(w2s, feet, 2.0)
 check("behind-camera cull returns nil", left == nil)
end

-- ----------------------------------------------------------------------------
-- 3. project_box: in front returns geometry.
-- ----------------------------------------------------------------------------
do
 local w2s = make_w2s({ facing = { x = 0, y = 1, z = 0 }, scale = 100 })
 projection.begin_frame(1920, 1080, 4, 8, 600)
 local feet = { x = 1, y = 5, z = 0 }
 local left, top, w, h = projection.project_box(w2s, feet, 2.0)
 check("in-front returns geometry",
   left ~= nil and w > 0 and h > 0,
   string.format("left=%s w=%s h=%s",
      tostring(left), tostring(w), tostring(h)))
end

-- ----------------------------------------------------------------------------
-- 4. project_box: far-away candidate culled by min_dim.
-- ----------------------------------------------------------------------------
do
 local w2s = make_w2s({ facing = { x = 0, y = 1, z = 0 }, scale = 100 })
 projection.begin_frame(1920, 1080, 4, 16, 600) -- min_dim 16
 local feet = { x = 0.0001, y = 1000, z = 0 }
 local left, top, w, h = projection.project_box(w2s, feet, 0.5)
 if left ~= nil then
  check("far-cull respects min_dim (drawn box ≥ min)",
    w >= 16 and h >= 16,
    string.format("w=%s h=%s", tostring(w), tostring(h)))
 else
  check("far-cull discards tiny (returned nil)", true)
 end
end

-- ----------------------------------------------------------------------------
-- 5. project_box: ceiling-huge NPC dropped by max_dim.
-- ----------------------------------------------------------------------------
do
 local w2s = make_w2s({ facing = { x = 0, y = 1, z = 0 }, scale = 5000 })
 projection.begin_frame(1920, 1080, 4, 8, 600)
 local feet = { x = 0, y = 0.5, z = 0 }
 local left = projection.project_box(w2s, feet, 1000)
 check("huge box drops out", left == nil)
end

-- ----------------------------------------------------------------------------
-- 6. project_box: off-screen cull.
-- ----------------------------------------------------------------------------
do
 local w2s = make_w2s({ facing = { x = 0, y = 1, z = 0 }, scale = 50 })
 projection.begin_frame(1920, 1080, 4, 8, 600)
 local feet = { x = 100, y = 5, z = 0 }
 local left, top, w, h = projection.project_box(w2s, feet, 2.0)
 check("off-screen cull drops candidates",
   (left == nil) or (left + w < 4),
   string.format("left=%s w=%s right-edge=%s",
      tostring(left), tostring(w),
      tostring(left and (left + w) or "nil")))
end

-- ----------------------------------------------------------------------------
-- 7. begin_frame: idempotent, no errors on repeated call.
-- ----------------------------------------------------------------------------
do
 projection.begin_frame(800, 600, 2, 4, 200)
 check("begin_frame idempotent",
   projection.begin_frame(640, 480, 1, 1, 100) == true)
end

-- ----------------------------------------------------------------------------
-- 8. overhead camera: head.y == feet.y (camera directly above) → still draws
-- with MIN_BOX_H fallback, never returns nil on height alone.
-- ----------------------------------------------------------------------------
do
 local function overhead_w2s(pos)
  local depth = pos.y
  if depth <= 0.5 then return nil end
  return { x = 960 + (pos.x * 50 / depth), y = 540 }
 end
 projection.begin_frame(1920, 1080, 4, 8, 600)
 local left, top, w, h = projection.project_box(overhead_w2s, { x = 0, y = 10, z = 0 }, 2.0, 0.5)
 check("overhead camera draws with MIN_BOX_H fallback",
   left ~= nil and h >= 24,
   string.format("left=%s w=%s h=%s", tostring(left), tostring(w), tostring(h)))
end

-- ----------------------------------------------------------------------------
-- 9. self-player ESP width: with unit_radius=0.5, width is not wider than
-- character (w ≤ h for a humanoid).
-- ----------------------------------------------------------------------------
do
 local w2s = make_w2s({ facing = { x = 0, y = 1, z = 0 }, scale = 100 })
 projection.begin_frame(1920, 1080, 4, 8, 600)
 local left, top, w, h = projection.project_box(w2s, { x = 0, y = 5, z = 0 }, 2.0, 0.5)
 check("self-ESP width ≤ height",
   w ~= nil and w <= h,
   string.format("w=%s h=%s", tostring(w), tostring(h)))
end

-- ----------------------------------------------------------------------------
-- 10. safe_w2s handles malformed returns gracefully.
-- ----------------------------------------------------------------------------
do
 local bad_w2s = function(_) return 42 end -- not a table
 projection.begin_frame(1920, 1080, 4, 8, 600)
 local ok, left = pcall(projection.project_box, bad_w2s,
       { x = 1, y = 5, z = 0 }, 2.0)
 check("non-table w2s returns nil without raising",
   ok == true and left == nil,
   "ok=" .. tostring(ok) .. " left=" .. tostring(left))
end

-- ----------------------------------------------------------------------------
-- PR3: project_box_min_size floors to min_dim even for far/tiny natural.
-- ----------------------------------------------------------------------------
do
 local w2s = make_w2s({ facing = { x = 0, y = 1, z = 0 }, scale = 10 }) -- far scale makes tiny natural
 projection.begin_frame(1920, 1080, 4, 8, 600)
 local feet = { x = 0, y = 500, z = 0 }
 local left, top, w, h = projection.project_box_min_size(w2s, feet, 2.0, 0.5, 24)
 check("min_size floors far to >=24 (even if natural tiny)",
   left ~= nil and (w or 0) >= 24 and (h or 0) >= 24,
   string.format("left=%s w=%s h=%s", tostring(left), tostring(w), tostring(h)))
end

-- ----------------------------------------------------------------------------
-- PR3: project_box_from_sp uses pre w2s, floors, respects max.
-- ----------------------------------------------------------------------------
do
 projection.begin_frame(1920, 1080, 4, 8, 600)
 local feet_sp = { x = 960, y = 540 }
 local head_sp = { x = 960, y = 500 }
 local left, top, w, h = projection.project_box_from_sp(feet_sp, head_sp, 2.0, 0.5, 24)
 check("from_sp returns valid >=24 floor",
   left ~= nil and (w or 0) >= 24 and (h or 0) >= 24)
end

-- ----------------------------------------------------------------------------
-- PR3: min_size / from_sp still cull on offscreen / max even with floor.
-- ----------------------------------------------------------------------------
do
 projection.begin_frame(1920, 1080, 4, 8, 600)
 local off_sp = { x = 3000, y = 3000 }
 local left = projection.project_box_from_sp(off_sp, nil, 2.0, 0.5, 24)
 check("from_sp offscreen still culls", left == nil)
end

-- ============================================================================
-- Report
-- ============================================================================

io.write("\n[EaxESP tests/projection]\n")
io.write(string.format(" pass: %d\n fail: %d\n", results.pass, results.fail))
if results.fail > 0 then
 for _, name in ipairs(results.fails) do
  io.write(" FAIL: " .. name .. "\n")
 end
 os.exit(1)
end
io.write(" ALL GREEN\n")
