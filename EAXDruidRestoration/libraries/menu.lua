-- +------------------------------------------------------------------+
-- |  Eax's Druid Restoration
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}
local INNERVATE_TARGET_OPTIONS = { "Self only", "Lowest mana healer", "Focus target" }

-- Tree nodes
local root_tree    = ps.tree_node()
local rotation_tree = ps.tree_node()
local healing_tree = ps.tree_node()
local dps_tree     = ps.tree_node()
local cd_tree      = ps.tree_node()
local auto_tree    = ps.tree_node()
local ooc_tree     = ps.tree_node()
local group_tree   = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local esp_tree     = ps.tree_node()

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxdruidrestoration_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxdruidrestoration_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxdruidrestoration_mode")
menu.debug                               = core.menu.checkbox(false, "eaxdruidrestoration_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxdruidrestoration_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxdruidrestoration_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxdruidrestoration_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxdruidrestoration_racial_hp")

-- Interrupt
menu.use_interrupt                       = core.menu.checkbox(true, "eaxdruidrestoration_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.ooc_heal_hp_pct                     = core.menu.slider_int(50, 100, 80, "eaxdruidresto_ooc_heal_hp_pct")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxdruidrestoration_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxdruidrestoration_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxdruidrestoration_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxdruidrestoration_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxdruidrestoration_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxdruidrestoration_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxdruidrestoration_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxdruidrestoration_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxdruidrestoration_spirit_tap_wand")

-- Healing
menu.use_rejuvenation                    = core.menu.checkbox(true, "eaxdruidrestoration_use_rejuvenation")
menu.use_regrowth                        = core.menu.checkbox(true, "eaxdruidrestoration_use_regrowth")
menu.use_healing_touch                   = core.menu.checkbox(true, "eaxdruidrestoration_use_healing_touch")
menu.use_swiftmend                       = core.menu.checkbox(true, "eaxdruidrestoration_use_swiftmend")
menu.swiftmend_hp_pct                    = core.menu.slider_int(10, 100, 50, "eaxdruidresto_swiftmend_hp_pct")
menu.use_lifebloom                       = core.menu.checkbox(true, "eaxdruidrestoration_use_lifebloom")
menu.lifebloom_stacks                    = core.menu.slider_int(1, 3, 3, "eaxdruidresto_lifebloom_stacks")
menu.use_natures_swiftness               = core.menu.checkbox(true, "eaxdruidrestoration_use_natures_swiftness")
menu.use_tranquility                     = core.menu.checkbox(true, "eaxdruidrestoration_use_tranquility")
menu.use_tree_of_life                    = core.menu.checkbox(true, "eaxdruidrestoration_use_tree_of_life")
menu.use_innervate                       = core.menu.checkbox(true, "eaxdruidrestoration_use_innervate")
menu.innervate_mana_pct                  = core.menu.slider_int(10, 60, 30, "eaxdruidrestoration_innervate_mana_pct")
menu.innervate_target                    = core.menu.combobox(1, "eaxdruidresto_innervate_target")
menu.buff_friendlies                     = core.menu.checkbox(true, "eaxdruidresto_buff_friendlies")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxdruidrestoration_remove_curse")
menu.use_abolish_poison                  = core.menu.checkbox(true, "eaxdruidrestoration_abolish_poison")
menu.use_cyclone                         = core.menu.checkbox(true, "eaxdruidrestoration_use_cyclone")
menu.use_entangling_roots                = core.menu.checkbox(true, "eaxdruidrestoration_use_entangling_roots")
menu.use_natures_grasp                   = core.menu.checkbox(true, "eaxdruidrestoration_use_natures_grasp")
menu.use_travel_form                    = core.menu.checkbox(true, "eaxdruidrestoration_use_travel_form")
menu.use_mount_form                     = core.menu.checkbox(true, "eaxdruidrestoration_use_mount_form")

-- DPS Fallback
menu.dps_fallback_enabled                = core.menu.checkbox(true, "eaxdruidrestoration_dps_fallback")
menu.dps_fallback_enabled                = core.menu.checkbox(false, "eaxdruidresto_dps_fallback_enabled")
menu.dps_use_faerie_fire                 = core.menu.checkbox(true, "eaxdruidrestoration_dps_use_faerie_fire")
menu.dps_use_faerie_fire                 = core.menu.checkbox(true, "eaxdruidresto_dps_use_faerie_fire")
menu.dps_use_moonfire                    = core.menu.checkbox(true, "eaxdruidrestoration_dps_use_moonfire")
menu.dps_use_moonfire                    = core.menu.checkbox(true, "eaxdruidresto_dps_use_moonfire")
menu.dps_use_insect_swarm                = core.menu.checkbox(true, "eaxdruidrestoration_dps_use_insect_swarm")
menu.dps_use_insect_swarm                = core.menu.checkbox(true, "eaxdruidresto_dps_use_insect_swarm")
menu.dps_use_wrath                       = core.menu.checkbox(true, "eaxdruidrestoration_dps_use_wrath")
menu.dps_use_wrath                       = core.menu.checkbox(true, "eaxdruidresto_dps_use_wrath")
menu.dps_use_starfire                    = core.menu.checkbox(true, "eaxdruidrestoration_dps_use_starfire")
menu.dps_starfire_over_wrath             = core.menu.checkbox(false, "eaxdruidrestoration_dps_starfire_over_wrath")
menu.use_hurricane                       = core.menu.checkbox(true, "eaxdruidrestoration_use_hurricane")
menu.hurricane_min_targets                = core.menu.slider_int(2, 8, 4, "eaxdruidrestoration_hurricane_min_targets")
menu.hurricane_mana_floor                 = core.menu.slider_int(10, 80, 40, "eaxdruidrestoration_hurricane_mana_floor")

-- Defensive
menu.use_barkskin                        = core.menu.checkbox(true, "eaxdruidrestoration_use_barkskin")
menu.barkskin_hp_pct                     = core.menu.slider_int(0, 100, 40, "eaxdruidrestoration_barkskin_hp_pct")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_rejuvenation", label = "Rejuvenation" },
    { toggle = "use_regrowth", label = "Regrowth" },
    { toggle = "use_healing_touch", label = "Healing Touch" },
    { toggle = "use_swiftmend", label = "Swiftmend" },
    { toggle = "use_lifebloom", label = "Lifebloom" },
    { toggle = "use_innervate", label = "Innervate" },
}, {
    namespace = "eaxdruidrestoration",
    log_prefix = "[Eax Druid Resto] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxdruidrestoration")
    end

    root_tree:render("Eax's Druid Restoration", function()
        ps.render_controls(menu, "Eax's Druid Resto")

        -- Healing
        healing_tree:render("Healing", function()
            ps.header("HoTs")
            menu.use_rejuvenation:render("Rejuvenation", "Maintain on targets")
            menu.use_regrowth:render("Regrowth", "Direct heal + HoT")
            menu.use_lifebloom:render("Lifebloom", "Stack to 3 on tank")
            menu.lifebloom_stacks:render("Lifebloom Stacks", "Target stack count")
            menu.use_swiftmend:render("Swiftmend", "Emergency heal")
            menu.swiftmend_hp_pct:render("Swiftmend HP %", "Use below")
            menu.use_healing_touch:render("Healing Touch", "Big slow heal")
            menu.use_natures_swiftness:render("Nature's Swiftness", "Instant cast")
            menu.use_tranquility:render("Tranquility", "AoE heal")
            menu.use_tree_of_life:render("Tree of Life", "Form")
            menu.use_innervate:render("Innervate", "Mana recovery")
            menu.innervate_mana_pct:render("Innervate Mana %", "Below")
            menu.innervate_target:render("Innervate Target", "Target mode")
        end)

        -- DPS Fallback
        dps_tree:render("DPS Fallback", function()
            menu.dps_fallback_enabled:render("DPS Fallback", "Enable solo DPS")
            menu.dps_use_faerie_fire:render("Faerie Fire", "Armor debuff")
            menu.dps_use_moonfire:render("Moonfire", "DoT")
            menu.dps_use_insect_swarm:render("Insect Swarm", "DoT")
            menu.dps_use_wrath:render("Wrath", "Filler")
            menu.dps_use_starfire:render("Starfire", "Cast")
            menu.dps_starfire_over_wrath:render("Prefer Starfire", "Starfire over Wrath")
            menu.use_hurricane:render("Hurricane", "AoE")
            menu.hurricane_min_targets:render("Min Targets", "Use above")
            menu.hurricane_mana_floor:render("Mana Floor %", "Don't use below")
        end)

        -- Utility
        rotation_tree:render("Utility", function()
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_remove_curse:render("Remove Curse", "Dispel")
            menu.use_abolish_poison:render("Abolish Poison", "Dispel")
            menu.use_cyclone:render("Cyclone", "CC")
            menu.use_entangling_roots:render("Entangling Roots", "Root")
            menu.use_natures_grasp:render("Nature's Grasp", "Root on hit")
            menu.use_travel_form:render("Travel Form", "OOC")
            menu.use_mount_form:render("Mount Form", "OOC")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_barkskin:render("Barkskin", "Damage reduction")
            menu.barkskin_hp_pct:render("Barkskin HP %", "Below")
        end)

        -- Automation
        auto_tree:render("Automation", function()
            menu.auto_combat_potions:render("Combat Potions", "In combat")
            menu.auto_ooc_food_drink:render("OOC Food/Drink", "Eat/drink")
            menu.auto_flask:render("Auto Flask", "Flask")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling")
            menu.leveling_mana_floor:render("Mana %", "Below")
            menu.use_wand:render("Use Wand", "Low mana")
            menu.wand_mana_floor:render("Wand Mana %", "Below")
            menu.wand_at_hp:render("Wand Target HP %", "Below")
            menu.use_spirit_tap_wand:render("Spirit Tap Wand", "If talented")
        end)

        -- OOC
        ooc_tree:render("OOC Sustain", function()
            menu.ooc_drink:render("Auto-Drink", "Drink")
            menu.drink_threshold:render("Drink %", "Below")
            menu.ooc_eat:render("Auto-Eat", "Eat")
            menu.eat_threshold:render("Eat %", "Below")
            menu.ooc_heal_hp_pct:render("OOC Heal HP %", "Heal allies below")
        end)

        -- Group
        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
            menu.buff_friendlies:render("Buff Friendlies", "OOC buff allies")
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end

return menu
