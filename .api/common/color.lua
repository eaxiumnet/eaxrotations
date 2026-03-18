
-- Example:
-- ---@type color
-- local c = require("common/color")
-- c: -> IntelliSense
-- Warning: Access with ":", not "."

---@class color
---Creates a new color instance.
---@field new fun(r: number, g: number, b: number, a?: number): color
---Clones the color instance.
---@field clone fun(self: color): color
---Blends the color instance with another color.
---@field blend fun(self: color, other: color, alpha: number): color
---Sets the color instance's values.
---@field set fun(self: color, r: number, g: number, b: number, a?: number): color
---Gets the color instance's values.
---@field get fun(self: color): (number, number, number, number)
---Clamps the color instance's values to the range [0, 255].
---@field clamp fun(self: color): color

---@class color
---Creates a red color.
---@field red fun(alpha?: number): color
---Creates a green color.
---@field green fun(alpha?: number): color
---Creates a blue color.
---@field blue fun(alpha?: number): color
---Creates a white color.
---@field white fun(alpha?: number): color
---Creates a black color.
---@field black fun(alpha?: number): color
---Creates a yellow color.
---@field yellow fun(alpha?: number): color
---Creates a pink color.
---@field pink fun(alpha?: number): color
---Creates a purple color.
---@field purple fun(alpha?: number): color
---Creates a gray color.
---@field gray fun(alpha?: number): color
---Creates a brown color.
---@field brown fun(alpha?: number): color
---Creates a gold color.
---@field gold fun(alpha?: number): color
---Creates a silver color.
---@field silver fun(alpha?: number): color
---Creates an orange color.
---@field orange fun(alpha?: number): color
---Creates a cyan color.
---@field cyan fun(alpha?: number): color
---Creates a pale red color.
---@field red_pale fun(alpha?: number): color
---Creates a pale green color.
---@field green_pale fun(alpha?: number): color
---Creates a pale blue color.
---@field blue_pale fun(alpha?: number): color
---Creates a pale cyan color.
---@field cyan_pale fun(alpha?: number): color
---Creates a pale gray color.
---@field gray_pale fun(alpha?: number): color

---@class color
---Converts HSV values to a color.
---@field hsv_to_rgb fun(h: number, s: number, v: number): color
---Gets a rainbow color based on the current time.
---@field get_rainbow_color fun(ratio: number): color

---@type color
local tbl
return tbl
