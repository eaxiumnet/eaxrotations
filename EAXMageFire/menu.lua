-- EAX Mage Fire | menu.lua

local menu = {}

local tree = core.menu.tree_node()
local rotation_tree = core.menu.tree_node()
local burst_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eax_mage_fire_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eax_mage_fire_toggle_key")
menu.debug = core.menu.checkbox(false, "eax_mage_fire_debug")
menu.mode = core.menu.combobox(1, "eax_mage_fire_mode")

menu.use_scorch = core.menu.checkbox(true, "eax_mage_fire_use_scorch")
menu.use_fireball = core.menu.checkbox(true, "eax_mage_fire_use_fireball")
menu.use_pyroblast = core.menu.checkbox(true, "eax_mage_fire_use_pyroblast")
menu.use_fire_blast_move = core.menu.checkbox(true, "eax_mage_fire_use_fire_blast_move")
menu.scorch_stack_target = core.menu.slider_int(1, 5, 5, "eax_mage_fire_scorch_stack_target")
menu.scorch_refresh_ms = core.menu.slider_int(500, 5000, 1500, "eax_mage_fire_scorch_refresh_ms")

menu.use_combustion = core.menu.checkbox(true, "eax_mage_fire_use_combustion")
menu.use_trinkets = core.menu.checkbox(true, "eax_mage_fire_use_trinkets")

function menu.render()
    tree:render("EAX Mage Fire", function()
        menu.enabled:render("Enabled", "Master enable/disable toggle")
        menu.toggle_key:render("Toggle Key", "Keybind to toggle enabled state")
        menu.debug:render("Debug Logging", "Print rotation decisions to console")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        rotation_tree:render("Rotation", function()
            menu.use_scorch:render("Scorch", "Maintain Fire Vulnerability stacks")
            menu.scorch_stack_target:render("Scorch Stack Target", "Desired Fire Vulnerability stack count")
            menu.scorch_refresh_ms:render("Scorch Refresh Window", "Refresh Scorch when the debuff is close to expiring")
            menu.use_fireball:render("Fireball", "Primary filler spell")
            menu.use_pyroblast:render("Pyroblast", "Use Pyroblast during burst-style proc windows when available")
            menu.use_fire_blast_move:render("Fire Blast While Moving", "Use Fire Blast as the moving fallback")
        end)

        burst_tree:render("Burst", function()
            menu.use_combustion:render("Combustion", "Use Combustion in combat")
            menu.use_trinkets:render("Trinkets", "Use self-cast trinkets alongside burst windows")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eax_mage_fire_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eax_mage_fire_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
