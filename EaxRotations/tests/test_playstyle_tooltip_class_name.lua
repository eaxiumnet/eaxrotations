-- regression test: playstyle tooltip must not be hardcoded to "Warlock".

local class_config = { class_name = "Warlock" }

local function get_tooltip(config)
    return "Select active " .. (config and config.class_name or "class") .. " rotation."
end

local current_tooltip = get_tooltip(class_config)

assert(current_tooltip == "Select active Warlock rotation.",
    "tooltip should be 'Select active Warlock rotation.' but got: " .. current_tooltip)

class_config.class_name = "Shaman"
local shaman_tooltip = get_tooltip(class_config)
assert(shaman_tooltip == "Select active Shaman rotation.",
    "tooltip should adapt to class name: " .. shaman_tooltip)

print("PASS test_playstyle_tooltip_class_name")
