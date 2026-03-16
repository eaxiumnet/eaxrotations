-- EAX Priest Holy | menu.lua
-- Menu options for targeting Renew stacks, Greater Heal, and Prayer of Healing.

local menu = {}
local tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eax_priest_holy_enabled")
menu.debug = core.menu.checkbox(false, "eax_priest_holy_debug")
menu.mode = core.menu.combobox(1, "eax_priest_holy_mode")

menu.renew_threshold = core.menu.slider_int(10, 90, 75, "eax_priest_holy_renew_threshold")
menu.renew_refresh_seconds = core.menu.slider_int(1, 5, 2, "eax_priest_holy_renew_refresh_seconds")
menu.greater_heal_threshold = core.menu.slider_int(25, 70, 45, "eax_priest_holy_greater_heal_threshold")

menu.prayer_of_healing_enabled = core.menu.checkbox(true, "eax_priest_holy_pohealing_enabled")
menu.prayer_of_healing_threshold = core.menu.slider_int(30, 70, 55, "eax_priest_holy_prayer_of_healing_threshold")
menu.prayer_of_healing_count = core.menu.slider_int(1, 5, 3, "eax_priest_holy_prayer_of_healing_count")

menu.auto_prayer_of_mending = core.menu.checkbox(true, "eax_priest_holy_auto_pom")
menu.prayer_of_mending_threshold = core.menu.slider_int(25, 65, 50, "eax_priest_holy_pom_threshold")

-- EAX Utils - Advanced Healing Features
menu.overheal_protection = core.menu.checkbox(true, "eax_priest_holy_overheal_protection")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eax_priest_holy_combat_self_hp_boost")
menu.focus_priority = core.menu.checkbox(false, "eax_priest_holy_focus_priority")

function menu.render()
    tree:render("EAX Priest Holy", function()
        menu.enabled:render("Enabled", "Toggle Holy automation")
        menu.debug:render("Debug Logging", "Log mode/targets to core.log")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        menu.renew_threshold:render("Renew Threshold", "Only refresh renew when health drops below this")
        menu.renew_refresh_seconds:render("Renew Refresh Window", "Seconds of Renew remaining before refreshing")
        menu.greater_heal_threshold:render("Greater Heal Threshold", "Emergency Greater Heals under this percent")

        menu.prayer_of_healing_enabled:render("Prayer of Healing", "Allow Prayer of Healing when multiple targets are hurt")
        menu.prayer_of_healing_threshold:render("PoH Threshold", "Health percent that counts targets toward PoH")
        menu.prayer_of_healing_count:render("PoH Count", "Minimum wounded allies to fire Prayer of Healing")

        menu.auto_prayer_of_mending:render("Auto Prayer of Mending", "Refresh PoM on wounded allies without clipping Renew")
        menu.prayer_of_mending_threshold:render("PoM Threshold", "Health percent that triggers PoM refresh")
        
        menu.overheal_protection:render("Overheal Protection", "Cancel slow heals when target is near full HP")
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize healing your focus target")
    end)
end

return menu
