-- EAX Rogue Assassination | menu.lua

local menu = {}

local tree = core.menu.tree_node()
local finishers_tree = core.menu.tree_node()
local cooldowns_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eaxrogueassassination_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eaxrogueassassination_toggle_key")
menu.mode = core.menu.combobox(1, "eaxrogueassassination_mode")
menu.debug = core.menu.checkbox(false, "eaxrogueassassination_debug")

menu.use_mutilate = core.menu.checkbox(true, "eaxrogueassassination_use_mutilate")
menu.use_slice_and_dice = core.menu.checkbox(true, "eaxrogueassassination_use_slice_and_dice")
menu.use_envenom = core.menu.checkbox(true, "eaxrogueassassination_use_envenom")
menu.use_eviscerate = core.menu.checkbox(true, "eaxrogueassassination_use_eviscerate")
menu.use_rupture = core.menu.checkbox(false, "eaxrogueassassination_use_rupture")
menu.use_kick = core.menu.checkbox(true, "eaxrogueassassination_use_kick")
menu.use_cold_blood = core.menu.checkbox(true, "eaxrogueassassination_use_cold_blood")

menu.snd_refresh_seconds = core.menu.slider_int(1, 6, 3, "eaxrogueassassination_snd_refresh_seconds")
menu.envenom_combo_points = core.menu.slider_int(4, 5, 5, "eaxrogueassassination_envenom_combo_points")
menu.poison_stack_threshold = core.menu.slider_int(1, 5, 4, "eaxrogueassassination_poison_stack_threshold")
menu.rupture_combo_points = core.menu.slider_int(3, 5, 4, "eaxrogueassassination_rupture_combo_points")

function menu.render()
    tree:render("EAX Rogue Assassination", function()
        menu.enabled:render("Enabled", "Master toggle")
        menu.toggle_key:render("Toggle Key", "Toggle the plugin on or off")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" }, "Auto uses party detection")
        menu.debug:render("Debug Logging", "Print rotation decisions")

        menu.use_mutilate:render("Mutilate", "Primary combo-point builder")
        menu.use_slice_and_dice:render("Slice and Dice", "Maintain Slice and Dice before finishers")
        menu.use_kick:render("Kick", "Interrupt enemy casts")

        finishers_tree:render("Finishers", function()
            menu.use_envenom:render("Envenom", "Spend combo points when Deadly Poison is stacked")
            menu.use_eviscerate:render("Eviscerate", "Fallback finisher when poison stacks are low")
            menu.use_rupture:render("Rupture", "Optional sustained-damage finisher")
            menu.envenom_combo_points:render("Envenom CP", "Minimum combo points before Envenom")
            menu.poison_stack_threshold:render("Deadly Poison Stacks", "Minimum poison stacks before Envenom")
            menu.rupture_combo_points:render("Rupture CP", "Minimum combo points before Rupture")
            menu.snd_refresh_seconds:render("SnD Refresh", "Refresh Slice and Dice when remaining duration is below this many seconds")
        end)

        cooldowns_tree:render("Cooldowns", function()
            menu.use_cold_blood:render("Cold Blood", "Use during dungeon and raid finishers")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxrogueassassination_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eaxrogueassassination_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
