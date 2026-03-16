-- menu.lua
-- EAX Hunter Beast Mastery | Full menu options

local menu = {}
local color = require("common/color")
local dev_id = "eax_hunter_bm_"

local main_node = core.menu.tree_node()
local abilities_node = core.menu.tree_node()
local pet_node = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, dev_id .. "enabled")
menu.toggle_key = core.menu.keybind(7, false, dev_id .. "toggle")
menu.mode = core.menu.combobox(1, dev_id .. "mode")
menu.debug = core.menu.checkbox(false, dev_id .. "debug")

menu.use_hunters_mark = core.menu.checkbox(true, dev_id .. "use_hunters_mark")
menu.use_serpent_sting = core.menu.checkbox(true, dev_id .. "use_serpent_sting")
menu.use_arcane_shot = core.menu.checkbox(true, dev_id .. "use_arcane_shot")
menu.use_aimed_shot = core.menu.checkbox(true, dev_id .. "use_aimed_shot")
menu.use_steady_shot = core.menu.checkbox(true, dev_id .. "use_steady_shot")
menu.use_multi_shot = core.menu.checkbox(true, dev_id .. "use_multi_shot")
menu.use_raptor_strike = core.menu.checkbox(true, dev_id .. "use_raptor_strike")
menu.use_kill_command = core.menu.checkbox(true, dev_id .. "use_kill_command")
menu.use_bestial_wrath = core.menu.checkbox(true, dev_id .. "use_bestial_wrath")

menu.use_mend_pet = core.menu.checkbox(true, dev_id .. "use_mend_pet")
menu.use_revive_pet = core.menu.checkbox(true, dev_id .. "use_revive_pet")
menu.mend_pet_hp = core.menu.slider_int(10, 80, 50, dev_id .. "mend_pet_hp")

function menu.render()
    main_node:render("EAX Hunter Beast Mastery", function()
        menu.enabled:render("Enable", "Toggle addon on/off")
        menu.toggle_key:render("Toggle Key")
        menu.mode:render("Mode", {"Auto", "Solo", "Dungeon", "Raid"}, "Auto detects party size; other options lock the rotation")
        menu.debug:render("Debug Logging", "Log rotation decisions")

        abilities_node:render("Abilities", function()
            if core.menu.header then
                core.menu.header():render("Ranged", color.green(200))
            end
            menu.use_hunters_mark:render("Hunters Mark", "Apply Hunters Mark for +AP")
            menu.use_serpent_sting:render("Serpent Sting", "Maintain Serpent Sting on target")
            menu.use_arcane_shot:render("Arcane Shot", "Use Arcane Shot (30yd)")
            menu.use_aimed_shot:render("Aimed Shot", "Use Aimed Shot (40yd)")
            menu.use_steady_shot:render("Steady Shot", "Use Steady Shot for focus generation")
            menu.use_multi_shot:render("Multi-Shot", "Use Multi-Shot (Dungeon/Raid)")
            
            if core.menu.header then
                core.menu.header():render("Melee", color.red(200))
            end
            menu.use_raptor_strike:render("Raptor Strike", "Use Raptor Strike in melee range")
            
            if core.menu.header then
                core.menu.header():render("Pet", color.blue(200))
            end
            menu.use_kill_command:render("Kill Command", "Command pet to attack")
            menu.use_bestial_wrath:render("Bestial Wrath", "Use Bestial Wrath burst")
        end)

        pet_node:render("Pet Management", function()
            menu.use_mend_pet:render("Mend Pet", "Mend pet when low health")
            menu.mend_pet_hp:render("Mend Pet HP %", "Mend pet below this HP%")
            menu.use_revive_pet:render("Revive Pet", "Auto revive pet if dead")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, dev_id .. "combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, dev_id .. "focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

function menu.log_debug(message)
    if menu.debug:get_state() then
        core.log("[EAX Hunter Beast Mastery] " .. tostring(message))
    end
end

return menu
