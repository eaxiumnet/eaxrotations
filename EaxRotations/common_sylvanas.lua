-- Readability notes:
--   What: runtime module.
--   When: loaded by bootstrap or tests when required.
--   Why: keeps related behavior in one auditable file.
--   Safety: use NS helpers, guard nil values, and avoid hot-path allocations.
--   Performance: schema rows are plain data, so menu construction stays one-time and cheap.

-- Decision notes:
--   This support module keeps side effects explicit and routes runtime-sensitive work through NS helpers.
--   Comments emphasize intent and constraints so future edits preserve behavior without adding frame-costly checks.
--   When API data is missing, callers should skip unsafe work rather than guessing.
-- Shared schema helpers for EaxRotations.
-- Keep this file Sylvanas-native and independent from any external rotation UI.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local function checkbox(key, default, label, tooltip)
    -- A schema entry is just data. main.lua owns widget creation, so class
    -- schema files remain readable and do not duplicate render-time code.
    return {
        type = "checkbox",
        key = key,
        default = default,
        label = label,
        tooltip = tooltip,
    }
end

local function option(value, text)
    return { value = value, text = text }
end

local function dropdown(key, default, label, tooltip, choices)
    -- Dropdown options store stable values separately from labels. This makes
    -- saved settings resilient to text changes in public-facing menu labels.
    return {
        type = "dropdown",
        key = key,
        default = default,
        label = label,
        tooltip = tooltip,
        options = choices,
    }
end

local function section(header, settings, description)
    local out = { header = header, settings = settings }
    if description then out.description = description end
    return out
end

local trinket_modes = {
    option("off", "Off"),
    option("offensive", "Offensive"),
    option("defensive", "Defensive"),
}

NS.log("Common schema helpers loaded")
