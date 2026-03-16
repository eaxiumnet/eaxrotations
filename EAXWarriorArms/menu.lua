-- EAX Warrior Arms | menu.lua
-- Menu definitions for the Arms rotation helper.

local menu = {}

local MODE_OPTIONS = { "Auto", "Solo", "Dungeon", "Raid" }
local tree = core.menu.tree_node()
local utility_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eaxwarriorarms_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eaxwarriorarms_toggle_key")
menu.debug = core.menu.checkbox(false, "eaxwarriorarms_debug")
menu.mode = core.menu.combobox(1, "eaxwarriorarms_mode")

menu.use_mortal_strike = core.menu.checkbox(true, "eaxwarriorarms_use_mortal_strike")
menu.use_slam = core.menu.checkbox(true, "eaxwarriorarms_use_slam")
menu.use_whirlwind = core.menu.checkbox(true, "eaxwarriorarms_use_whirlwind")
menu.use_overpower = core.menu.checkbox(true, "eaxwarriorarms_use_overpower")
menu.use_execute = core.menu.checkbox(true, "eaxwarriorarms_use_execute")
menu.slam_safety_buffer_ms = core.menu.slider_int(50, 300, 120, "eaxwarriorarms_slam_safety_buffer_ms")

menu.use_battle_shout = core.menu.checkbox(true, "eaxwarriorarms_use_battle_shout")
menu.use_commanding_shout = core.menu.checkbox(false, "eaxwarriorarms_use_commanding_shout")
menu.use_demo_shout = core.menu.checkbox(true, "eaxwarriorarms_use_demo_shout")
menu.use_sunder_armor = core.menu.checkbox(true, "eaxwarriorarms_use_sunder_armor")
menu.sunder_max_stacks = core.menu.slider_int(1, 5, 5, "eaxwarriorarms_sunder_max_stacks")
menu.use_hamstring = core.menu.checkbox(true, "eaxwarriorarms_use_hamstring")

function menu.render()
    tree:render("EAX Warrior Arms", function()
        menu.enabled:render("Enabled", "Master toggle for the plugin")
        menu.toggle_key:render("Toggle Key", "Keybind to instantly enable/disable the rotation")
        menu.debug:render("Debug Logging", "Log rotation decisions in the console")
        menu.mode:render("Mode", MODE_OPTIONS)

        menu.use_mortal_strike:render("Mortal Strike", "Use Mortal Strike on cooldown when enabled")
        menu.use_slam:render("Slam Weave", "Weave Slam between auto attacks when Mortal Strike is on cooldown")
        menu.slam_safety_buffer_ms:render("Slam Safety Buffer", "Extra milliseconds before the next swing to avoid clipping Slam")
        menu.use_whirlwind:render("Whirlwind", "Dance to Berserker stance for Whirlwind bursts")
        menu.use_overpower:render("Overpower", "Use Overpower when a dodge proc occurs")
        menu.use_execute:render("Execute", "Execute below 20% health")

        utility_tree:render("Utility", function()
            menu.use_battle_shout:render("Battle Shout", "Maintain Battle Shout support buff")
            menu.use_commanding_shout:render("Commanding Shout", "Replace Battle Shout with Commanding Shout when trained")
            menu.use_demo_shout:render("Demoralizing Shout", "Keep Demoralizing Shout on the target")
            menu.use_sunder_armor:render("Sunder Armor", "Maintain Sunder Armor stacks (Dungeon/Raid only)")
            menu.sunder_max_stacks:render("Sunder Max", "Maximum Sunder Armor stacks to maintain")
            menu.use_hamstring:render("Hamstring", "Use Hamstring as a Solo mode filler")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxwarriorarms_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eaxwarriorarms_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
