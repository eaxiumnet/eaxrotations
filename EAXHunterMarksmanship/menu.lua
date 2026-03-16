local menu = {}
local color = require("common/color")
local dev_id = "eax_hunter_ms_"

local main_node = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, dev_id .. "enabled")
menu.toggle_key = core.menu.keybind(8, false, dev_id .. "toggle")
menu.mode = core.menu.combobox(1, dev_id .. "mode")
menu.debug = core.menu.checkbox(false, dev_id .. "debug")

menu.use_aimed_shot = core.menu.checkbox(true, dev_id .. "use_aimed_shot")
menu.use_multi_shot = core.menu.checkbox(true, dev_id .. "use_multi_shot")
menu.use_steady_weave = core.menu.checkbox(true, dev_id .. "use_steady_weave")
menu.multi_shot_limit = core.menu.slider_int(1, 5, 3, dev_id .. "multi_shot_limit")

function menu.render()
    main_node:render("EAX Hunter Marksmanship", function()
        menu.enabled:render("Enable")
        menu.toggle_key:render("Toggle Key")
        menu.mode:render("Mode", {"Auto", "Solo", "Dungeon", "Raid"}, "Auto picks the most likely environment; other values hard-lock the mode")
        menu.debug:render("Debug Logging")

        if core.menu.header then
            core.menu.header():render("Abilities", color.purple(200))
        end
        menu.use_aimed_shot:render("Use Aimed Shot", "Priority burst that benefits from free aim")
        menu.use_multi_shot:render("Use Multi-Shot", "Multi-target weave while the mode permits")
        menu.use_steady_weave:render("Steady Shot Weaving", "Always weave a steady shot between heavy casts")
        menu.multi_shot_limit:render("Multi-Shot Target Cap", "Avoid wasting multi-shot on too few enemies")
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, dev_id .. "combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, dev_id .. "focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

function menu.log_debug(message)
    if menu.debug:get_state() then
        core.log("[EAX Hunter Marksmanship] " .. tostring(message))
    end
end

return menu
