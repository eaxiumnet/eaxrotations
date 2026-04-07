
-- path_helper.api.lua
-- Type definitions for common/utility/path_helper.lua
-- Drop this file in your workspace root for IntelliSense support.
--
-- Example:
-- ---@type path_helper
-- local ph = require("common/utility/path_helper")
-- local path = ph.new({ passes = 2, decimate = 3.0 })
-- path: -> IntelliSense
--
-- Warning: Instance methods use ":", not "."
--   path:ensure(raw)   -- correct
--   path.ensure(raw)   -- wrong

---------------------------------------------------------------------------
-- Options table passed to path_helper.new()
---------------------------------------------------------------------------

---@class path_helper_opts
---@field passes?   integer  Number of Chaikin subdivision passes (default 4). More = smoother but heavier.
---@field decimate? number   Min distance (yards) between points before smoothing (default 5.0). Lower = more detail.
---@field spacing?  number   Circle spacing (yards) for 3D dot drawing (default 3.5).
---@field circle_r? number   Circle radius for 3D dot drawing (default 0.75).

---------------------------------------------------------------------------
-- Map bounds table expected by render_map()
---------------------------------------------------------------------------

---@class path_helper_map_bounds
---@field x1 number  Left edge in screen pixels
---@field y1 number  Top edge in screen pixels
---@field x2 number  Right edge in screen pixels
---@field y2 number  Bottom edge in screen pixels

---------------------------------------------------------------------------
-- Instance: independent bake context returned by path_helper.new()
---------------------------------------------------------------------------

---@class path_helper_instance
---@field ensure     fun(self: path_helper_instance, raw: vec3[], key?: any): nil             Rebuild baked geometry if key changed. Key defaults to #raw. Cheap no-op when key matches previous call.
---@field clear      fun(self: path_helper_instance): nil                                     Clear all baked data and reset change-detection key.
---@field has_data   fun(self: path_helper_instance): boolean                                 True if baked geometry exists and is ready to render.
---@field render_3d  fun(self: path_helper_instance, dest?: vec3): nil                        Draw 3D path lines + circles + optional destination marker. Call from on_render callback.
---@field render_map fun(self: path_helper_instance, bounds: path_helper_map_bounds, dest?: vec3): nil  Draw 2D path on map overlay + optional destination dot. Call from on_render_window callback.

---------------------------------------------------------------------------
-- Factory module: require("common/utility/path_helper")
---------------------------------------------------------------------------

---@class path_helper
---@field new fun(opts?: path_helper_opts): path_helper_instance  Create an independent path bake context with custom smoothing settings. Each instance has its own state so multiple plugins can use path_helper simultaneously without interference.
