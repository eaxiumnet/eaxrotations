-- EAX PaladinProtection | menu.lua

local menu = {}
local tree = core.menu.tree_node()
local rotation_tree = core.menu.tree_node()
local defense_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eaxpaladinprot_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eaxpaladinprot_toggle_key")
menu.debug = core.menu.checkbox(false, "eaxpaladinprot_debug")
menu.mode = core.menu.combobox(1, "eaxpaladinprot_mode")
menu.show_notifications = core.menu.checkbox(false, "eaxpaladinprot_notifications")

menu.use_righteous_fury = core.menu.checkbox(true, "eaxpaladinprot_use_righteous_fury")
menu.use_holy_shield = core.menu.checkbox(true, "eaxpaladinprot_use_holy_shield")
menu.use_consecration = core.menu.checkbox(true, "eaxpaladinprot_use_consecration")
menu.consecration_enemy_count = core.menu.slider_int(2, 6, 3, "eaxpaladinprot_consecration_enemy_count")
menu.consecration_radius = core.menu.slider_int(6, 12, 8, "eaxpaladinprot_consecration_radius")
menu.use_avengers_shield = core.menu.checkbox(true, "eaxpaladinprot_use_avengers_shield")
menu.use_judgement = core.menu.checkbox(true, "eaxpaladinprot_use_judgement")

function menu.render()
    tree:render("EAX Paladin Protection", function()
        menu.enabled:render("Enabled", "Master toggle for the protection paladin rotation")
        menu.toggle_key:render("Toggle Key", "Keybind that flips the master toggle")
        menu.debug:render("Debug Logging", "Log decisions to the console")
        menu.show_notifications:render("Notifications", "Show short on-screen reminders")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        rotation_tree:render("Rotation", function()
            menu.use_righteous_fury:render("Righteous Fury", "Keep the threat buff active")
            menu.use_consecration:render("Consecration", "Cast Consecration when enough enemies are nearby")
            menu.consecration_enemy_count:render("Consecration Count", "Minimum enemies within radius before Consecration")
            menu.consecration_radius:render("Consecration Radius", "Radius used when counting enemies for Consecration")
            menu.use_avengers_shield:render("Avenger's Shield", "Use Avenger's Shield when fighting from range")
            menu.use_judgement:render("Judgement", "Apply Judgement of the Crusader once per target when ready")
        end)

        defense_tree:render("Defense", function()
            menu.use_holy_shield:render("Holy Shield", "Maintain Holy Shield for mitigation and reflection")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxpaladinprot_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eaxpaladinprot_focus_priority")
        
        if core.menu.header then
            core.menu.header():render("Advanced", color.yellow(180))
        end
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
