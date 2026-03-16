-- menu.lua
-- Configuration for EAX Warlock Destruction.

local menu = {}
local tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eax_destruction_enabled")
menu.debug = core.menu.checkbox(false, "eax_destruction_debug")
menu.toggle_key = core.menu.keybind(7, false, "eax_destruction_toggle")
menu.mode = core.menu.combobox(1, "eax_destruction_mode")
menu.profile = core.menu.combobox(1, "eax_destruction_profile")

menu.use_immolate = core.menu.checkbox(true, "eax_destruction_use_immolate")
menu.use_conflagrate = core.menu.checkbox(true, "eax_destruction_use_conflagrate")
menu.use_shadowfury = core.menu.checkbox(true, "eax_destruction_use_shadowfury")
menu.use_shadow_bolt = core.menu.checkbox(true, "eax_destruction_use_shadow_bolt")
menu.use_incinerate = core.menu.checkbox(true, "eax_destruction_use_incinerate")
menu.use_life_tap = core.menu.checkbox(true, "eax_destruction_use_life_tap")
menu.life_tap_threshold = core.menu.slider_int(10, 80, 40, "eax_destruction_lifetap_pct")

function menu.render()
    tree:render("EAX Warlock Destruction", function()
        menu.enabled:render("Enabled", "Master switch")
        menu.toggle_key:render("Toggle Key", "Enable/disable hotkey")
        menu.debug:render("Debug", "Print rotation decisions")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })
        menu.profile:render("Profile", { "Auto", "Fire", "Shadow" })

        menu.use_immolate:render("Immolate", "Maintain Immolate on the target")
        menu.use_conflagrate:render("Conflagrate", "Use Conflagrate when ready")
        menu.use_shadowfury:render("Shadowfury", "Use Shadowfury on spellcasters")
        menu.use_shadow_bolt:render("Shadow Bolt", "Shadow primary for the Shadow profile")
        menu.use_incinerate:render("Incinerate", "Fire primary for the Fire profile")
        menu.use_life_tap:render("Life Tap", "Regen mana when health permits")
        menu.life_tap_threshold:render("Life Tap HP %", "Minimum percent health to Life Tap")
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxwarlockdestruction_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eaxwarlockdestruction_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
