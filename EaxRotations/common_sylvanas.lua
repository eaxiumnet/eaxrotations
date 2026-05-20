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
