local menu = {}
local color = require("common/color")
local dev_id = "eax_hunter_surv_"

local main_node = core.menu.tree_node()
local abilities_node = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, dev_id .. "enabled")
menu.toggle_key = core.menu.keybind(9, false, dev_id .. "toggle")
menu.mode = core.menu.combobox(1, dev_id .. "mode")
menu.debug = core.menu.checkbox(false, dev_id .. "debug")

menu.use_hunters_mark = core.menu.checkbox(true, dev_id .. "use_hunters_mark")
menu.use_serpent_sting = core.menu.checkbox(true, dev_id .. "use_serpent_sting")
menu.use_explosive_shot = core.menu.checkbox(true, dev_id .. "use_explosive_shot")
menu.use_arcane_shot = core.menu.checkbox(true, dev_id .. "use_arcane_shot")
menu.use_steady_shot = core.menu.checkbox(true, dev_id .. "use_steady_shot")
menu.use_multi_shot = core.menu.checkbox(true, dev_id .. "use_multi_shot")
menu.use_raptor_strike = core.menu.checkbox(true, dev_id .. "use_raptor_strike")
menu.use_wing_clip = core.menu.checkbox(true, dev_id .. "use_wing_clip")

menu.use_traps = core.menu.checkbox(true, dev_id .. "use_traps")
menu.trap_selection = core.menu.combobox(1, dev_id .. "trap_selection")
menu.trap_interval = core.menu.slider_float(1.0, 10.0, 4.0, dev_id .. "trap_interval")
menu.use_wyvern = core.menu.checkbox(true, dev_id .. "use_wyvern")
menu.use_expose = core.menu.checkbox(true, dev_id .. "use_expose")

menu.use_mend_pet = core.menu.checkbox(true, dev_id .. "use_mend_pet")
menu.mend_pet_hp_pct = core.menu.slider_int(0, 100, 70, dev_id .. "mend_pet_hp_pct")

function menu.render()
    main_node:render("EAX Hunter Survival", function()
        menu.enabled:render("Enable")
        menu.toggle_key:render("Toggle Key")
        menu.mode:render("Mode", {"Auto", "Solo", "Dungeon", "Raid"}, "Auto detects party size")
        menu.debug:render("Debug Logging")

        abilities_node:render("Abilities", function()
            if core.menu.header then
                core.menu.header():render("Ranged", color.green(200))
            end
            menu.use_hunters_mark:render("Hunters Mark", "Apply Hunters Mark for +AP")
            menu.use_serpent_sting:render("Serpent Sting", "Maintain Serpent Sting on target")
            menu.use_explosive_shot:render("Explosive Shot", "Use Explosive Shot (20yd)")
            menu.use_arcane_shot:render("Arcane Shot", "Use Arcane Shot (30yd)")
            menu.use_steady_shot:render("Steady Shot", "Use Steady Shot for focus generation")
            menu.use_multi_shot:render("Multi-Shot", "Use Multi-Shot (Dungeon/Raid)")
            
            if core.menu.header then
                core.menu.header():render("Melee", color.red(200))
            end
            menu.use_raptor_strike:render("Raptor Strike", "Use Raptor Strike in melee range")
            menu.use_wing_clip:render("Wing Clip", "Use Wing Clip to slow (melee)")
            
            if core.menu.header then
                core.menu.header():render("Traps", color.orange(200))
            end
            menu.use_traps:render("Use Traps", "Attempt to drop the selected trap on cooldown")
            menu.trap_selection:render("Trap Type", {"Explosive", "Freezing", "Snake", "Wyvern"}, "Choose the trap to drop when the interval expires")
            menu.trap_interval:render("Trap Interval", "Seconds between trap attempts")
            menu.use_wyvern:render("Use Wyvern Sting", "Apply Wyvern Sting before heavy bursts")
            menu.use_expose:render("Use Expose Weakness", "Maintain the debuff on the primary target")
        end)
        
        local emergency_tree = core.menu.tree_node()
        emergency_tree:render("Emergency", function()
            menu.use_mend_pet:render("Use Mend Pet", "Use Mend Pet when pet health is low")
            menu.mend_pet_hp_pct:render("Mend Pet HP%", "Use Mend Pet below this health percent")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, dev_id .. "combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, dev_id .. "focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

function menu.log_debug(message)
    if menu.debug:get_state() then
        core.log("[EAX Hunter Survival] " .. tostring(message))
    end
end

return menu
