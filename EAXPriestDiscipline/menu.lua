-- EAX Priest Discipline | menu.lua
-- Menu definitions for mode selection and mitigation thresholds.

local menu = {}
local tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eax_priest_discipline_enabled")
menu.debug = core.menu.checkbox(false, "eax_priest_discipline_debug")
menu.mode = core.menu.combobox(1, "eax_priest_discipline_mode")

menu.shield_threshold = core.menu.slider_int(10, 90, 60, "eax_priest_discipline_shield_threshold")
menu.renew_threshold = core.menu.slider_int(10, 90, 75, "eax_priest_discipline_renew_threshold")
menu.renew_refresh_seconds = core.menu.slider_int(1, 5, 2, "eax_priest_discipline_renew_refresh_seconds")
menu.pain_suppression_threshold = core.menu.slider_int(5, 40, 25, "eax_priest_discipline_pain_suppression_threshold")

menu.power_infusion_enabled = core.menu.checkbox(true, "eax_priest_discipline_power_infusion")
menu.power_infusion_threshold = core.menu.slider_int(25, 75, 45, "eax_priest_discipline_power_infusion_threshold")

menu.prayer_of_mending = core.menu.checkbox(true, "eax_priest_discipline_prayer_of_mending")
menu.prayer_of_mending_threshold = core.menu.slider_int(20, 80, 55, "eax_priest_discipline_prayer_of_mending_threshold")

-- EAX Utils - Advanced Healing Features
menu.overheal_protection = core.menu.checkbox(true, "eax_priest_discipline_overheal_protection")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eax_priest_discipline_combat_self_hp_boost")
menu.focus_priority = core.menu.checkbox(false, "eax_priest_discipline_focus_priority")

function menu.render()
    tree:render("EAX Priest Discipline", function()
        menu.enabled:render("Enabled", "Toggle Discipline rotation")
        menu.debug:render("Debug Logging", "Print mode/target entries to core.log")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        menu.shield_threshold:render("Shield Threshold", "Shield allies when they drop below this percent")
        menu.renew_threshold:render("Renew Threshold", "Refresh Renew when allies fall below this percent")
        menu.renew_refresh_seconds:render("Renew Refresh Window", "Refresh Renew when the buff has this many seconds left")
        menu.pain_suppression_threshold:render("Pain Suppression", "Drop Pain Suppression on targets below this percent")

        menu.power_infusion_enabled:render("Power Infusion", "Enable automatic Power Infusion windows")
        menu.power_infusion_threshold:render("Power Infusion Trigger", "Use Power Infusion when an ally crosses this percent")

        menu.prayer_of_mending:render("Prayer of Mending", "Spread Prayer of Mending when Renew is already affecting the target")
        menu.prayer_of_mending_threshold:render("PoM Threshold", "Cast Prayer of Mending when an ally falls below this percent")
        
        menu.overheal_protection:render("Overheal Protection", "Cancel slow heals when target is near full HP")
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize healing your focus target")
    end)
end

return menu
