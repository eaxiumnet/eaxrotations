-- EAX Druid Restoration | menu.lua
-- Menu elements are created once at require-time.

local menu = {}

local tree = core.menu.tree_node()
local lifebloom_tree = core.menu.tree_node()
local hot_tree = core.menu.tree_node()
local cooldown_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eaxdruidrestoration_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eaxdruidrestoration_toggle_key")
menu.debug = core.menu.checkbox(false, "eaxdruidrestoration_debug")
menu.mode = core.menu.combobox(1, "eaxdruidrestoration_mode")
menu.mana_saver = core.menu.checkbox(false, "eaxdruidrestoration_mana_saver")
menu.use_mark_of_the_wild = core.menu.checkbox(true, "eaxdruidrestoration_use_mark_of_the_wild")

menu.use_lifebloom = core.menu.checkbox(true, "eaxdruidrestoration_use_lifebloom")
menu.lifebloom_stacks = core.menu.slider_int(1, 3, 3, "eaxdruidrestoration_lifebloom_stacks")
menu.lifebloom_refresh_seconds = core.menu.slider_int(1, 4, 2, "eaxdruidrestoration_lifebloom_refresh_seconds")

menu.use_rejuvenation = core.menu.checkbox(true, "eaxdruidrestoration_use_rejuvenation")
menu.rejuvenation_refresh_seconds = core.menu.slider_int(1, 5, 3, "eaxdruidrestoration_rejuvenation_refresh_seconds")
menu.use_regrowth = core.menu.checkbox(true, "eaxdruidrestoration_use_regrowth")
menu.regrowth_refresh_seconds = core.menu.slider_int(1, 5, 2, "eaxdruidrestoration_regrowth_refresh_seconds")
menu.use_swiftmend = core.menu.checkbox(true, "eaxdruidrestoration_use_swiftmend")
menu.swiftmend_hp_pct = core.menu.slider_int(20, 80, 60, "eaxdruidrestoration_swiftmend_hp_pct")
menu.use_wild_growth = core.menu.checkbox(true, "eaxdruidrestoration_use_wild_growth")
menu.wild_growth_targets = core.menu.slider_int(2, 6, 3, "eaxdruidrestoration_wild_growth_targets")
menu.wild_growth_mana_pct = core.menu.slider_int(20, 80, 40, "eaxdruidrestoration_wild_growth_mana_pct")

menu.use_innervate = core.menu.checkbox(true, "eaxdruidrestoration_use_innervate")
menu.innervate_mana_pct = core.menu.slider_int(10, 60, 35, "eaxdruidrestoration_innervate_mana_pct")
menu.use_tranquility = core.menu.checkbox(true, "eaxdruidrestoration_use_tranquility")
menu.tranquility_injured_count = core.menu.slider_int(2, 8, 3, "eaxdruidrestoration_tranquility_injured_count")
menu.use_natures_swiftness = core.menu.checkbox(true, "eaxdruidrestoration_use_natures_swiftness")
menu.emergency_hp_pct = core.menu.slider_int(10, 60, 35, "eaxdruidrestoration_emergency_hp_pct")

-- EAX Utils - Advanced Healing Features
menu.overheal_protection = core.menu.checkbox(true, "eaxdruidrestoration_overheal_protection")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxdruidrestoration_combat_self_hp_boost")
menu.focus_priority = core.menu.checkbox(false, "eaxdruidrestoration_focus_priority")

function menu.render()
    tree:render("EAX Druid Restoration", function()
        menu.enabled:render("Enabled", "Master enable/disable toggle")
        menu.toggle_key:render("Toggle Key", "Keybind to toggle enabled state")
        menu.debug:render("Debug Logging", "Print healing and target selection decisions to console")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" }, "Auto resolves from current group size")
        menu.mana_saver:render("Mana Saver", "Delay expensive spells until mana is healthier")
        menu.use_mark_of_the_wild:render("Mark of the Wild", "Refresh Mark of the Wild on yourself out of combat")

        lifebloom_tree:render("Lifebloom", function()
            menu.use_lifebloom:render("Lifebloom", "Maintain Lifebloom stacks on the primary tank target")
            menu.lifebloom_stacks:render("Desired Stacks", "Target Lifebloom stack count")
            menu.lifebloom_refresh_seconds:render("Refresh Window (sec)", "Refresh Lifebloom below this remaining time")
        end)

        hot_tree:render("HoTs", function()
            menu.use_rejuvenation:render("Rejuvenation", "Maintain Rejuvenation on the priority heal target")
            menu.rejuvenation_refresh_seconds:render("Rejuvenation Refresh (sec)", "Refresh Rejuvenation below this remaining time")
            menu.use_regrowth:render("Regrowth", "Use Regrowth for heavier sustained healing")
            menu.regrowth_refresh_seconds:render("Regrowth Refresh (sec)", "Refresh Regrowth below this remaining time")
            menu.use_swiftmend:render("Swiftmend", "Consume an active HoT for burst healing")
            menu.swiftmend_hp_pct:render("Swiftmend HP %", "Health threshold for Swiftmend")
            menu.use_wild_growth:render("Wild Growth", "Use Wild Growth for multi-target healing when available")
            menu.wild_growth_targets:render("Wild Growth Targets", "Minimum injured allies before Wild Growth")
            menu.wild_growth_mana_pct:render("Wild Growth Mana %", "Minimum mana to allow Wild Growth")
        end)

        cooldown_tree:render("Cooldowns", function()
            menu.use_innervate:render("Innervate", "Recover mana automatically at the configured threshold")
            menu.innervate_mana_pct:render("Innervate Mana %", "Mana threshold for Innervate")
            menu.use_tranquility:render("Tranquility", "Use Tranquility during raid-wide injury windows")
            menu.tranquility_injured_count:render("Tranquility Injured Count", "Minimum injured allies before Tranquility")
            menu.use_natures_swiftness:render("Nature's Swiftness", "Prep Nature's Swiftness for Regrowth emergencies")
            menu.emergency_hp_pct:render("Emergency HP %", "Health threshold for Nature's Swiftness + Regrowth")
            
            menu.overheal_protection:render("Overheal Protection", "Cancel slow heals when target is near full HP")
            menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
            menu.focus_priority:render("Focus Target Priority", "Prioritize healing your focus target")
        end)
    end)
end

return menu
