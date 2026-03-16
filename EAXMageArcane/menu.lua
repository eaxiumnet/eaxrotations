-- EAX Mage Arcane | menu.lua

local menu = {}

local tree = core.menu.tree_node()
local rotation_tree = core.menu.tree_node()
local burst_tree = core.menu.tree_node()
local mana_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eax_mage_arcane_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eax_mage_arcane_toggle_key")
menu.debug = core.menu.checkbox(false, "eax_mage_arcane_debug")
menu.mode = core.menu.combobox(1, "eax_mage_arcane_mode")

menu.use_arcane_blast = core.menu.checkbox(true, "eax_mage_arcane_use_arcane_blast")
menu.use_arcane_missiles = core.menu.checkbox(true, "eax_mage_arcane_use_arcane_missiles")
menu.use_fire_blast_move = core.menu.checkbox(true, "eax_mage_arcane_use_fire_blast_move")
menu.arcane_blast_dump_stacks = core.menu.slider_int(2, 4, 3, "eax_mage_arcane_dump_stacks")

menu.use_arcane_power = core.menu.checkbox(true, "eax_mage_arcane_use_arcane_power")
menu.use_trinkets = core.menu.checkbox(true, "eax_mage_arcane_use_trinkets")
menu.burn_mana_pct = core.menu.slider_int(20, 100, 60, "eax_mage_arcane_burn_mana_pct")

menu.use_mana_gem = core.menu.checkbox(true, "eax_mage_arcane_use_mana_gem")
menu.use_evocation = core.menu.checkbox(true, "eax_mage_arcane_use_evocation")
menu.mana_gem_pct = core.menu.slider_int(10, 90, 45, "eax_mage_arcane_mana_gem_pct")
menu.evocation_pct = core.menu.slider_int(5, 60, 20, "eax_mage_arcane_evocation_pct")

function menu.render()
    tree:render("EAX Mage Arcane", function()
        menu.enabled:render("Enabled", "Master enable/disable toggle")
        menu.toggle_key:render("Toggle Key", "Keybind to toggle enabled state")
        menu.debug:render("Debug Logging", "Print rotation decisions to console")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        rotation_tree:render("Rotation", function()
            menu.use_arcane_blast:render("Arcane Blast", "Primary filler and stack builder")
            menu.use_arcane_missiles:render("Arcane Missiles", "Dump Arcane Blast stacks in sustain windows")
            menu.use_fire_blast_move:render("Fire Blast While Moving", "Use Fire Blast as the moving fallback")
            menu.arcane_blast_dump_stacks:render("Dump At AB Stacks", "Cast Arcane Missiles at or above this Arcane Blast stack count")
        end)

        burst_tree:render("Burst", function()
            menu.use_arcane_power:render("Arcane Power", "Use Arcane Power during burst windows")
            menu.use_trinkets:render("Trinkets", "Use self-cast trinkets during burst windows")
            menu.burn_mana_pct:render("Burn Mana %", "Minimum mana percent required to open Arcane Power burst")
        end)

        mana_tree:render("Mana", function()
            menu.use_mana_gem:render("Mana Gem", "Use Mana Gem when mana drops below the configured threshold")
            menu.mana_gem_pct:render("Mana Gem %", "Use Mana Gem below this mana percent")
            menu.use_evocation:render("Evocation", "Channel Evocation when mana is low")
            menu.evocation_pct:render("Evocation %", "Use Evocation below this mana percent")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eax_mage_arcane_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eax_mage_arcane_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
