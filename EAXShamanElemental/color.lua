-- color.lua
-- Color helper: plain table for logic/tinting, with preset constructors.
-- esp_renderer converts these to native API colors via to_api_color().

local color = {}

function color.new(r, g, b, a)
    return { r = r or 255, g = g or 255, b = b or 255, a = a or 255 }
end

-- Preset constructors (each takes optional alpha, returns {r,g,b,a} table)
function color.red(a)        return color.new(255,  50,  50, a or 255) end
function color.green(a)      return color.new( 50, 205,  50, a or 255) end
function color.blue(a)       return color.new( 50, 100, 255, a or 255) end
function color.white(a)      return color.new(255, 255, 255, a or 255) end
function color.black(a)      return color.new(  0,   0,   0, a or 255) end
function color.yellow(a)     return color.new(255, 220,   0, a or 255) end
function color.gold(a)       return color.new(255, 185,   0, a or 255) end
function color.orange(a)     return color.new(255, 140,   0, a or 255) end
function color.purple(a)     return color.new(160,  32, 240, a or 255) end
function color.pink(a)       return color.new(255, 105, 180, a or 255) end
function color.cyan(a)       return color.new(  0, 220, 220, a or 255) end
function color.gray(a)       return color.new(160, 160, 160, a or 255) end
function color.brown(a)      return color.new(139,  90,  43, a or 255) end
function color.silver(a)     return color.new(192, 192, 192, a or 255) end
function color.red_pale(a)   return color.new(255, 160, 160, a or 255) end
function color.green_pale(a) return color.new(144, 238, 144, a or 255) end
function color.blue_pale(a)  return color.new(173, 216, 230, a or 255) end
function color.cyan_pale(a)  return color.new(175, 238, 238, a or 255) end
function color.gray_pale(a)  return color.new(211, 211, 211, a or 255) end

return color
