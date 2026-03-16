-- EAX Rogue Subtlety | menu.lua

local menu = {}

local tree = core.menu.tree_node()
local opener_tree = core.menu.tree_node()
local rotation_tree = core.menu.tree_node()
local cooldowns_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eaxroguesubtlety_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eaxroguesubtlety_toggle_key")
menu.mode = core.menu.combobox(1, "eaxroguesubtlety_mode")
menu.debug = core.menu.checkbox(false, "eaxroguesubtlety_debug")

menu.use_premeditation = core.menu.checkbox(true, "eaxroguesubtlety_use_premeditation")
menu.use_cheap_shot = core.menu.checkbox(true, "eaxroguesubtlety_use_cheap_shot")
menu.use_ambush = core.menu.checkbox(true, "eaxroguesubtlety_use_ambush")
menu.use_backstab = core.menu.checkbox(true, "eaxroguesubtlety_use_backstab")
menu.use_hemorrhage = core.menu.checkbox(true, "eaxroguesubtlety_use_hemorrhage")
menu.use_slice_and_dice = core.menu.checkbox(true, "eaxroguesubtlety_use_slice_and_dice")
menu.use_rupture = core.menu.checkbox(true, "eaxroguesubtlety_use_rupture")
menu.use_eviscerate = core.menu.checkbox(true, "eaxroguesubtlety_use_eviscerate")
menu.use_shadowstep = core.menu.checkbox(true, "eaxroguesubtlety_use_shadowstep")
menu.use_preparation = core.menu.checkbox(true, "eaxroguesubtlety_use_preparation")

menu.snd_refresh_seconds = core.menu.slider_int(1, 6, 3, "eaxroguesubtlety_snd_refresh_seconds")
menu.finisher_combo_points = core.menu.slider_int(3, 5, 4, "eaxroguesubtlety_finisher_combo_points")

function menu.render()
    tree:render("EAX Rogue Subtlety", function()
        menu.enabled:render("Enabled", "Master toggle")
        menu.toggle_key:render("Toggle Key", "Toggle the plugin on or off")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" }, "Auto uses party detection")
        menu.debug:render("Debug Logging", "Print rotation decisions")

        opener_tree:render("Stealth Openers", function()
            menu.use_premeditation:render("Premeditation", "Build combo points before the opener")
            menu.use_cheap_shot:render("Cheap Shot", "Preferred control opener in dungeon and raid")
            menu.use_ambush:render("Ambush", "Fallback stealth damage opener")
        end)

        rotation_tree:render("Combat Rotation", function()
            menu.use_backstab:render("Backstab", "Primary behind-target builder")
            menu.use_hemorrhage:render("Hemorrhage", "Fallback builder when Backstab is not ideal")
            menu.use_slice_and_dice:render("Slice and Dice", "Maintain Slice and Dice before burst finishers")
            menu.use_rupture:render("Rupture", "Sustained finisher")
            menu.use_eviscerate:render("Eviscerate", "Burst finisher")
            menu.snd_refresh_seconds:render("SnD Refresh", "Refresh Slice and Dice below this many seconds")
            menu.finisher_combo_points:render("Finisher CP", "Minimum combo points before finishers")
        end)

        cooldowns_tree:render("Burst Tools", function()
            menu.use_shadowstep:render("Shadowstep", "Close gaps for stealth-style burst windows")
            menu.use_preparation:render("Preparation", "Reset stealth tools in raid-style burst windows")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxroguesubtlety_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eaxroguesubtlety_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
