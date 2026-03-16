-- menu.lua
-- EAX Paladin Holy | Menu Configuration
-- Menu elements and settings

---@type color
local color = require("common/color")

local menu = {}

local tree = core.menu.tree_node()
local dev_id = "eax_paladin_holy_"

menu.enabled = core.menu.checkbox(true, dev_id .. "enabled")
menu.toggle_key = core.menu.keybind(7, false, dev_id .. "toggle_key")
menu.mode = core.menu.combobox(1, dev_id .. "mode")
menu.debug = core.menu.checkbox(false, dev_id .. "debug")

menu.use_holy_light = core.menu.checkbox(true, dev_id .. "use_holy_light")
menu.holy_light_hp_pct = core.menu.slider_int(20, 70, 40, dev_id .. "holy_light_hp_pct")

menu.use_flash_of_light = core.menu.checkbox(true, dev_id .. "use_flash_of_light")
menu.flash_of_light_hp_pct = core.menu.slider_int(40, 95, 75, dev_id .. "flash_of_light_hp_pct")

menu.use_holy_shock = core.menu.checkbox(true, dev_id .. "use_holy_shock")
menu.holy_shock_hp_pct = core.menu.slider_int(5, 60, 30, dev_id .. "holy_shock_hp_pct")

menu.auto_blessings = core.menu.checkbox(true, dev_id .. "auto_blessings")

-- EAX Utils - Advanced Healing Features
menu.use_predictive_healing = core.menu.checkbox(true, dev_id .. "use_predictive_healing")
menu.overheal_protection = core.menu.checkbox(true, dev_id .. "overheal_protection")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, dev_id .. "combat_self_hp_boost")
menu.focus_priority = core.menu.checkbox(false, dev_id .. "focus_priority")

function menu.render()
    tree:render("EAX Paladin Holy", function()
        menu.enabled:render("Enabled", "Enable the addon and allow rotations to run")
        menu.toggle_key:render("Toggle Key", "Keybind to toggle the addon")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" }, "Override automatic mode detection")
        menu.debug:render("Debug Logging", "Log heuristic decisions to the console")

        if core.menu.header then
            core.menu.header():render("Healing", color.green(220))
        end
        menu.use_holy_light:render("Holy Light", "Big heals for tanks and hard hits")
        menu.holy_light_hp_pct:render("Holy Light HP %", "Cast Holy Light when a target drops below this percent")

        menu.use_flash_of_light:render("Flash of Light", "Fast heals for raid/dungeon damage spikes")
        menu.flash_of_light_hp_pct:render("Flash HP %", "Use Flash when a target drops below this percent")

        menu.use_holy_shock:render("Holy Shock", "Instant burst heal when health is low")
        menu.holy_shock_hp_pct:render("Holy Shock HP %", "Threshold to consider Holy Shock")

        if core.menu.header then
            core.menu.header():render("Blessings", color.green(200))
        end
        menu.auto_blessings:render("Auto Blessings", "Keep Blessings of Light, Wisdom, and Might active on yourself")
        
        if core.menu.header then
            core.menu.header():render("Advanced Healing", color.yellow(180))
        end
        menu.use_predictive_healing:render("Predictive Healing", "Use incoming damage prediction to heal before damage lands")
        menu.overheal_protection:render("Overheal Protection", "Cancel slow heals when target is near full HP")
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize healing your focus target")
    end)
end

function menu.log_debug(message)
    if menu.debug:get_state() then
        core.log("[EAX Paladin Holy] " .. message)
    end
end

return menu
