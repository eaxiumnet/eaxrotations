-- EAX Druid Balance | menu.lua
-- Menu elements are created once at require-time.

local menu = {}

local tree = core.menu.tree_node()
local dots_tree = core.menu.tree_node()
local cooldowns_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eaxdruidbalance_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eaxdruidbalance_toggle_key")
menu.debug = core.menu.checkbox(false, "eaxdruidbalance_debug")
menu.mode = core.menu.combobox(1, "eaxdruidbalance_mode")

menu.force_moonkin = core.menu.checkbox(true, "eaxdruidbalance_force_moonkin")
menu.use_faerie_fire = core.menu.checkbox(true, "eaxdruidbalance_use_faerie_fire")
menu.use_moonfire = core.menu.checkbox(true, "eaxdruidbalance_use_moonfire")
menu.use_insect_swarm = core.menu.checkbox(true, "eaxdruidbalance_use_insect_swarm")

menu.dot_refresh_seconds = core.menu.slider_int(1, 5, 3, "eaxdruidbalance_dot_refresh_seconds")
menu.use_force_of_nature = core.menu.checkbox(true, "eaxdruidbalance_use_force_of_nature")
menu.use_starfall = core.menu.checkbox(true, "eaxdruidbalance_use_starfall")
menu.starfall_aoe_targets = core.menu.slider_int(1, 6, 3, "eaxdruidbalance_starfall_aoe_targets")
menu.use_innervate = core.menu.checkbox(true, "eaxdruidbalance_use_innervate")
menu.innervate_mana_pct = core.menu.slider_int(10, 60, 30, "eaxdruidbalance_innervate_mana_pct")
menu.use_tranquility = core.menu.checkbox(false, "eaxdruidbalance_use_tranquility")
menu.tranquility_hp_pct = core.menu.slider_int(20, 70, 35, "eaxdruidbalance_tranquility_hp_pct")
menu.wrath_during_lunar = core.menu.checkbox(true, "eaxdruidbalance_wrath_during_lunar")

function menu.render()
    tree:render("EAX Druid Balance", function()
        menu.enabled:render("Enabled", "Master enable/disable toggle")
        menu.toggle_key:render("Toggle Key", "Keybind to toggle enabled state")
        menu.debug:render("Debug Logging", "Print rotation decisions to console")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" }, "Auto resolves from current group size")
        menu.force_moonkin:render("Force Moonkin Form", "Keep Moonkin Form active whenever possible")
        menu.use_faerie_fire:render("Faerie Fire", "Maintain Faerie Fire on the active target")
        menu.wrath_during_lunar:render("Wrath During Lunar", "Swap to Wrath while a Lunar Eclipse-style buff is active")

        dots_tree:render("DoTs", function()
            menu.use_moonfire:render("Moonfire", "Maintain Moonfire on the active target")
            menu.use_insect_swarm:render("Insect Swarm", "Maintain Insect Swarm on the active target")
            menu.dot_refresh_seconds:render("Refresh Window (sec)", "Refresh Moonfire and Insect Swarm when remaining time is below this value")
        end)

        cooldowns_tree:render("Cooldowns", function()
            menu.use_force_of_nature:render("Force of Nature", "Use Force of Nature during established pressure windows")
            menu.use_starfall:render("Starfall", "Use Starfall when the enemy count or raid pressure justifies it")
            menu.starfall_aoe_targets:render("Starfall AoE Count", "Minimum enemies in range before Starfall is allowed")
            menu.use_innervate:render("Innervate", "Recover mana automatically when out of combat or in a dry lane")
            menu.innervate_mana_pct:render("Innervate Mana %", "Mana threshold for Innervate")
            menu.use_tranquility:render("Emergency Tranquility", "Allow Tranquility as a self-preservation emergency")
            menu.tranquility_hp_pct:render("Tranquility HP %", "Self-health threshold for emergency Tranquility")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxdruidbalance_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eaxdruidbalance_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
