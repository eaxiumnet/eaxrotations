-- EAX Paladin Retribution | menu.lua

local menu = {}

local menu_tree = core.menu.tree_node()
local seal_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eaxpr_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eaxpr_toggle_key")
menu.debug = core.menu.checkbox(false, "eaxpr_debug")
menu.mode = core.menu.combobox(1, "eaxpr_mode")

-- Abilities
menu.use_judgement = core.menu.checkbox(true, "eaxpr_use_judgement")
menu.judgement_choice = core.menu.combobox(1, "eaxpr_judgement_choice")
menu.use_crusader_strike = core.menu.checkbox(true, "eaxpr_use_crusader_strike")

-- Seal twisting controls
menu.use_seal_twist = core.menu.checkbox(true, "eaxpr_use_seal_twist")
menu.seal_twist_window = core.menu.slider_int(200, 1200, 450, "eaxpr_seal_twist_window")
menu.seal_twist_cooldown = core.menu.slider_int(800, 4000, 1600, "eaxpr_seal_twist_cooldown")
menu.allow_twist_dungeon = core.menu.checkbox(true, "eaxpr_twist_dungeon")
menu.allow_twist_raid = core.menu.checkbox(false, "eaxpr_twist_raid")

function menu.render()
    menu_tree:render("EAX Paladin Retribution", function()
        menu.enabled:render("Enabled", "Master toggle for the retri rotation")
        menu.toggle_key:render("Toggle Key", "Quick key to enable/disable the addon")
        menu.debug:render("Debug Logging", "Show rotation decisions in the console")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        menu.use_judgement:render("Judgement", "Maintain the chosen judgement debuff")
        menu.judgement_choice:render("Judgement Mode", { "Wisdom", "Crusader" })
        menu.use_crusader_strike:render("Crusader Strike", "Cast on cooldown when the GCD is ready")

        seal_tree:render("Seal Twisting", function()
            menu.use_seal_twist:render("Enable Seal Twists", "Rotate Command → Blood → Righteousness for seal-twisting uptime")
            menu.seal_twist_window:render("Twist Window (ms)", "Delay twists until at least this many ms before the next swing")
            menu.seal_twist_cooldown:render("Twist Cooldown (ms)", "Minimum time between completed twists")
            menu.allow_twist_dungeon:render("Allow in Dungeon", "Permit twisting when dungeon mode is active")
            menu.allow_twist_raid:render("Allow in Raid", "Optional twisting for raid mode (disabled by default)")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxpr_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eaxpr_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
