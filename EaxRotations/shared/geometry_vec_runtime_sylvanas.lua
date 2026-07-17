-- geometry_vec_runtime_sylvanas.lua
-- WHAT: Minimal runtime vec2/vec3 matching Project Sylvanas common/geometry API methods
--       used by hit-volume/cone math when the engine stubs are type-only (unit tests).
-- WHEN: Required only if require("common/geometry/vector_*") lacks :new / methods.
-- WHY:  Production path prefers the real API; tests need executable methods on the same require path.
-- SAFETY: Pure math; no game I/O. Implements only methods we call (not full engine surface).

local M = {}

local function v2_new(x, y)
    local t = { x = x or 0, y = y or 0 }
    setmetatable(t, M._vec2_mt)
    return t
end

local function v3_new(x, y, z)
    local t = { x = x or 0, y = y or 0, z = z or 0 }
    setmetatable(t, M._vec3_mt)
    return t
end

M._vec2_mt = {
    __index = {
        clone = function(self) return v2_new(self.x, self.y) end,
        normalize = function(self)
            local len = math.sqrt((self.x or 0) ^ 2 + (self.y or 0) ^ 2)
            if len <= 0 then return v2_new(0, 0) end
            return v2_new(self.x / len, self.y / len)
        end,
        length = function(self)
            return math.sqrt((self.x or 0) ^ 2 + (self.y or 0) ^ 2)
        end,
        length_squared = function(self)
            return (self.x or 0) ^ 2 + (self.y or 0) ^ 2
        end,
        dot = function(self, v)
            if not v then return 0 end
            return (self.x or 0) * (v.x or 0) + (self.y or 0) * (v.y or 0)
        end,
        get_unit_vector = function(self) return self:normalize() end,
        dist_to = function(self, other)
            if not other then return 0 end
            local dx = (self.x or 0) - (other.x or 0)
            local dy = (self.y or 0) - (other.y or 0)
            return math.sqrt(dx * dx + dy * dy)
        end,
        squared_dist_to = function(self, other)
            if not other then return 0 end
            local dx = (self.x or 0) - (other.x or 0)
            local dy = (self.y or 0) - (other.y or 0)
            return dx * dx + dy * dy
        end,
        is_zero = function(self)
            return (self.x or 0) == 0 and (self.y or 0) == 0
        end,
        is_nan = function(self)
            return self.x ~= self.x or self.y ~= self.y
        end,
    },
    __add = function(a, b) return v2_new((a.x or 0) + (b.x or 0), (a.y or 0) + (b.y or 0)) end,
    __sub = function(a, b) return v2_new((a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)) end,
    __mul = function(a, b)
        if type(b) == "number" then return v2_new((a.x or 0) * b, (a.y or 0) * b) end
        return v2_new((a.x or 0) * (b.x or 0), (a.y or 0) * (b.y or 0))
    end,
    __div = function(a, b)
        if type(b) == "number" then return v2_new((a.x or 0) / b, (a.y or 0) / b) end
        return v2_new((a.x or 0) / (b.x or 1), (a.y or 0) / (b.y or 1))
    end,
    __eq = function(a, b) return a.x == b.x and a.y == b.y end,
}

M._vec3_mt = {
    __index = {
        clone = function(self) return v3_new(self.x, self.y, self.z) end,
        normalize = function(self)
            local len = math.sqrt((self.x or 0) ^ 2 + (self.y or 0) ^ 2 + (self.z or 0) ^ 2)
            if len <= 0 then return v3_new(0, 0, 0) end
            return v3_new(self.x / len, self.y / len, self.z / len)
        end,
        length = function(self)
            return math.sqrt((self.x or 0) ^ 2 + (self.y or 0) ^ 2 + (self.z or 0) ^ 2)
        end,
        length_squared = function(self)
            return (self.x or 0) ^ 2 + (self.y or 0) ^ 2 + (self.z or 0) ^ 2
        end,
        dot = function(self, v)
            if not v then return 0 end
            return (self.x or 0) * (v.x or 0) + (self.y or 0) * (v.y or 0) + (self.z or 0) * (v.z or 0)
        end,
        get_unit_vector = function(self) return self:normalize() end,
        dist_to = function(self, other)
            if not other then return 0 end
            local dx = (self.x or 0) - (other.x or 0)
            local dy = (self.y or 0) - (other.y or 0)
            local dz = (self.z or 0) - (other.z or 0)
            return math.sqrt(dx * dx + dy * dy + dz * dz)
        end,
        squared_dist_to = function(self, other)
            if not other then return 0 end
            local dx = (self.x or 0) - (other.x or 0)
            local dy = (self.y or 0) - (other.y or 0)
            local dz = (self.z or 0) - (other.z or 0)
            return dx * dx + dy * dy + dz * dz
        end,
        dist_to_ignore_z = function(self, other)
            if not other then return 0 end
            local dx = (self.x or 0) - (other.x or 0)
            local dy = (self.y or 0) - (other.y or 0)
            return math.sqrt(dx * dx + dy * dy)
        end,
        squared_dist_to_ignore_z = function(self, other)
            if not other then return 0 end
            local dx = (self.x or 0) - (other.x or 0)
            local dy = (self.y or 0) - (other.y or 0)
            return dx * dx + dy * dy
        end,
        project_2d = function(self) return v3_new(self.x, self.y, 0) end,
        rotate_3d_radians = function(self, angle_radians)
            -- Rotate around Z (yaw), same as horizontal facing math.
            local c = math.cos(angle_radians)
            local s = math.sin(angle_radians)
            local x, y = self.x or 0, self.y or 0
            return v3_new(x * c - y * s, x * s + y * c, self.z or 0)
        end,
        is_zero = function(self)
            return (self.x or 0) == 0 and (self.y or 0) == 0 and (self.z or 0) == 0
        end,
        is_nan = function(self)
            return self.x ~= self.x or self.y ~= self.y or self.z ~= self.z
        end,
        get_angle = function(self, target, origin)
            -- Angle at origin between self and target (horizontal), radians.
            if not target or not origin then return 0 end
            local a = v3_new((self.x or 0) - (origin.x or 0), (self.y or 0) - (origin.y or 0), 0)
            local b = v3_new((target.x or 0) - (origin.x or 0), (target.y or 0) - (origin.y or 0), 0)
            local la = a:length()
            local lb = b:length()
            if la <= 0 or lb <= 0 then return 0 end
            local c = a:dot(b) / (la * lb)
            if c > 1 then c = 1 elseif c < -1 then c = -1 end
            return math.acos(c)
        end,
    },
    __add = function(a, b)
        return v3_new((a.x or 0) + (b.x or 0), (a.y or 0) + (b.y or 0), (a.z or 0) + (b.z or 0))
    end,
    __sub = function(a, b)
        return v3_new((a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0))
    end,
    __mul = function(a, b)
        if type(b) == "number" then
            return v3_new((a.x or 0) * b, (a.y or 0) * b, (a.z or 0) * b)
        end
        return v3_new((a.x or 0) * (b.x or 0), (a.y or 0) * (b.y or 0), (a.z or 0) * (b.z or 0))
    end,
    __div = function(a, b)
        if type(b) == "number" then
            return v3_new((a.x or 0) / b, (a.y or 0) / b, (a.z or 0) / b)
        end
        return v3_new((a.x or 0) / (b.x or 1), (a.y or 0) / (b.y or 1), (a.z or 0) / (b.z or 1))
    end,
    __eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
}

-- Module tables with :new (called as vec3.new(x,y,z) per API docs — field, not method-on-instance)
M.vec2 = {
    new = v2_new,
    dot_product = function(v1, v2)
        if not v1 or not v2 then return 0 end
        return (v1.x or 0) * (v2.x or 0) + (v1.y or 0) * (v2.y or 0)
    end,
}

M.vec3 = {
    new = v3_new,
    dot_product = function(v1, v2)
        if not v1 or not v2 then return 0 end
        return (v1.x or 0) * (v2.x or 0) + (v1.y or 0) * (v2.y or 0) + (v1.z or 0) * (v2.z or 0)
    end,
}

--- Ensure package.loaded has executable vector modules (engine stubs may be type-only).
function M.ensure_package_loaded()
    local function usable(mod)
        return type(mod) == "table" and type(mod.new) == "function"
    end
    local v2 = package.loaded["common/geometry/vector_2"]
    if not usable(v2) then
        local ok, real = pcall(require, "common/geometry/vector_2")
        if ok and usable(real) then
            package.loaded["common/geometry/vector_2"] = real
        else
            package.loaded["common/geometry/vector_2"] = M.vec2
        end
    end
    local v3 = package.loaded["common/geometry/vector_3"]
    if not usable(v3) then
        local ok, real = pcall(require, "common/geometry/vector_3")
        if ok and usable(real) then
            package.loaded["common/geometry/vector_3"] = real
        else
            package.loaded["common/geometry/vector_3"] = M.vec3
        end
    end
    return package.loaded["common/geometry/vector_2"], package.loaded["common/geometry/vector_3"]
end

return M
