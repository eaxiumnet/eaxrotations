-- menu.lua
-- Control panel for EAX Warlock Demonology.

local menu = {}
local tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eax_demonology_enabled")
menu.debug = core.menu.checkbox(false, "eax_demonology_debug")
menu.toggle_key = core.menu.keybind(7, false, "eax_demonology_toggle")
menu.mode = core.menu.combobox(1, "eax_demonology_mode")

menu.ensure_felguard = core.menu.checkbox(true, "eax_demonology_ensure_felguard")
menu.maintain_soul_link = core.menu.checkbox(true, "eax_demonology_soul_link")
menu.use_soul_fire = core.menu.checkbox(true, "eax_demonology_use_soul_fire")
menu.use_shadow_bolt = core.menu.checkbox(true, "eax_demonology_use_shadow_bolt")
menu.use_shadowfury = core.menu.checkbox(true, "eax_demonology_use_shadowfury")
menu.use_life_tap = core.menu.checkbox(true, "eax_demonology_use_life_tap")
menu.life_tap_threshold = core.menu.slider_int(10, 80, 35, "eax_demonology_lifetap_pct")
menu.pet_check_interval = core.menu.slider_int(1, 10, 4, "eax_demonology_pet_check")

function menu.render()
    tree:render("EAX Warlock Demonology", function()
        menu.enabled:render("Enabled", "Master switch")
        menu.toggle_key:render("Toggle Key", "Enable/disable hotkey")
        menu.debug:render("Debug", "Print pet and rotation notes")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        menu.ensure_felguard:render("Ensure Felguard", "Recast Felguard on cooldown")
        menu.pet_check_interval:render("Pet Refresh Interval", "Seconds between felguard checks")
        menu.maintain_soul_link:render("Soul Link", "Keep Soul Link active when possible")
        menu.use_soul_fire:render("Soul Fire", "Cast Soul Fire when ready")
        menu.use_shadow_bolt:render("Shadow Bolt", "Fallback filler")
        menu.use_shadowfury:render("Shadowfury", "Crowd control when enemies crowd the target")
        menu.use_life_tap:render("Life Tap", "Regain mana under the configured health threshold")
        menu.life_tap_threshold:render("Life Tap HP %", "The minimum health percent required to Life Tap")
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxwarlockdemonology_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eaxwarlockdemonology_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
