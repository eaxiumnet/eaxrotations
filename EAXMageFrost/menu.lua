-- EAX Mage Frost | menu.lua

local menu = {}

local tree = core.menu.tree_node()
local rotation_tree = core.menu.tree_node()
local burst_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eax_mage_frost_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eax_mage_frost_toggle_key")
menu.debug = core.menu.checkbox(false, "eax_mage_frost_debug")
menu.mode = core.menu.combobox(1, "eax_mage_frost_mode")

menu.use_frostbolt = core.menu.checkbox(true, "eax_mage_frost_use_frostbolt")
menu.use_ice_lance = core.menu.checkbox(true, "eax_mage_frost_use_ice_lance")
menu.use_fireball_proc = core.menu.checkbox(true, "eax_mage_frost_use_fireball_proc")
menu.ice_lance_execute_hp = core.menu.slider_int(5, 40, 20, "eax_mage_frost_ice_lance_execute_hp")

menu.use_icy_veins = core.menu.checkbox(true, "eax_mage_frost_use_icy_veins")
menu.use_water_elemental = core.menu.checkbox(true, "eax_mage_frost_use_water_elemental")
menu.use_trinkets = core.menu.checkbox(true, "eax_mage_frost_use_trinkets")

function menu.render()
    tree:render("EAX Mage Frost", function()
        menu.enabled:render("Enabled", "Master enable/disable toggle")
        menu.toggle_key:render("Toggle Key", "Keybind to toggle enabled state")
        menu.debug:render("Debug Logging", "Print rotation decisions to console")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        rotation_tree:render("Rotation", function()
            menu.use_frostbolt:render("Frostbolt", "Primary filler spell")
            menu.use_ice_lance:render("Ice Lance", "Use Ice Lance on frozen or execute-style targets")
            menu.ice_lance_execute_hp:render("Ice Lance Execute HP %", "Use Ice Lance when targets are low and frozen")
            menu.use_fireball_proc:render("Fireball Proc", "Use Fireball when a Brain Freeze style proc buff is active")
        end)

        burst_tree:render("Burst", function()
            menu.use_icy_veins:render("Icy Veins", "Use Icy Veins in combat")
            menu.use_water_elemental:render("Water Elemental", "Summon Water Elemental when available")
            menu.use_trinkets:render("Trinkets", "Use self-cast trinkets during burst windows")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eax_mage_frost_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eax_mage_frost_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
