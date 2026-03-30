-- +------------------------------------------------------------------+
-- |  Eax's Druid Balance
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+
local mana_conservator = require("libraries/mana_conservator")

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- -- Tree nodes ----------------------------------------------------------------
local root_tree    = ps.tree_node()
local rotation_tree = ps.tree_node()
local healing_tree = ps.tree_node()
local aoe_tree     = ps.tree_node()
local auto_tree    = ps.tree_node()
local ooc_tree     = ps.tree_node()
local group_tree   = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local esp_tree     = ps.tree_node()

-- -- Controls ------------------------------------------------------------------
menu.enabled                             = core.menu.checkbox(true, "eaxdruidbalance_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxdruidbalance_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxdruidbalance_mode")
menu.debug                               = core.menu.checkbox(false, "eaxdruidbalance_debug")

-- -- Targeting ----------------------------------------------------------------
menu.focus_priority                      = core.menu.checkbox(false, "eaxdruidbalance_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxdruidbalance_combat_self_hp_boost")

-- -- Racial --------------------------------------------------------------------
menu.use_racial                          = core.menu.checkbox(true, "eaxdruidbalance_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxdruidbalance_racial_hp")

-- -- OOC Sustain ----------------------------------------------------------------
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
menu.auto_flask                         = core.menu.checkbox(false, "eaxdruidbalance_auto_flask")

-- -- Group ---------------------------------------------------------------------
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")

-- -- Automation ----------------------------------------------------------------
-- menu.auto_repair                        = core.menu.checkbox(true, "eaxdruidbalance_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxdruidbalance_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxdruidbalance_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxdruidbalance_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxdruidbalance_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxdruidbalance_auto_ooc_food_drink")

-- -- Leveling ------------------------------------------------------------------
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxdruidbalance_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxdruidbalance_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxdruidbalance_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxdruidbalance_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxdruidbalance_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxdruidbalance_spirit_tap_wand")

-- -- ESP/HUD -------------------------------------------------------------------
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Rotation - DPS -------------------------------------------------------------
menu.force_moonkin                        = core.menu.checkbox(true, "eaxdruidbalance_force_moonkin")
menu.use_faerie_fire                      = core.menu.checkbox(true, "eaxdruidbalance_use_faerie_fire")
menu.use_moonfire                         = core.menu.checkbox(true, "eaxdruidbalance_use_moonfire")
menu.use_insect_swarm                     = core.menu.checkbox(true, "eaxdruidbalance_use_insect_swarm")
menu.dot_refresh_seconds                  = core.menu.slider_int(1, 5, 3, "eaxdruidbalance_dot_refresh_seconds")
menu.use_force_of_nature                  = core.menu.checkbox(true, "eaxdruidbalance_use_force_of_nature")

-- -- Rotation - Healing/Emergency ------------------------------------------------
menu.use_innervate                        = core.menu.checkbox(true, "eaxdruidbalance_use_innervate")
menu.innervate_mana_pct                   = core.menu.slider_int(10, 60, 30, "eaxdruidbalance_innervate_mana_pct")
menu.use_tranquility                      = core.menu.checkbox(true, "eaxdruidbalance_use_tranquility")
menu.tranquility_hp_pct                   = core.menu.slider_int(20, 70, 35, "eaxdruidbalance_tranquility_hp_pct")

-- -- Rotation - AoE -------------------------------------------------------------
menu.use_hurricane                        = core.menu.checkbox(true, "eaxdruidbalance_use_hurricane")
menu.hurricane_min_targets                = core.menu.slider_int(2, 8, 4, "eaxdruidbalance_hurricane_min_targets")
menu.hurricane_mana_floor                 = core.menu.slider_int(10, 80, 40, "eaxdruidbalance_hurricane_mana_floor")

-- -- Utility -------------------------------------------------------------------
menu.use_root_escape                     = core.menu.checkbox(true, "eaxdruidbalance_root_escape")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxdruidbalance_remove_curse")

-- -- Defensive -----------------------------------------------------------------
menu.use_barkskin                         = core.menu.checkbox(true, "eaxdruidbalance_use_barkskin")
menu.use_barkskin_hp_pct                  = core.menu.slider_int(0, 100, 40, "eaxdruidbalance_barkskin_hp_pct")

mana_conservator.register_menu_items(menu, "eax_druid_balance")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_moonfire", label = "Moonfire" },
    { toggle = "use_insect_swarm", label = "Insect Swarm" },
    { toggle = "use_force_of_nature", label = "Force of Nature" },
    { toggle = "use_hurricane", label = "Hurricane" },
    { toggle = "use_innervate", label = "Innervate" },
}, {
    namespace = "eaxdruidbalance",
    log_prefix = "[Eax Druid Balance] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxdruidbalance")
    end

    root_tree:render("Eax's Druid Balance", function()

        ps.render_controls(menu, "Eax's Druid Balance")

        -- -- Rotation - DPS ----------------------------------------------------
        rotation_tree:render("Rotation (DPS)", function()
            ps.header("Forms & Buffs")
            menu.force_moonkin:render("Force Moonkin Form", "Keep Moonkin Form active whenever possible")
            menu.use_faerie_fire:render("Faerie Fire", "Maintain Faerie Fire on target")

            ps.header("Single Target")
            menu.use_moonfire:render("Moonfire", "Maintain Moonfire on target")
            menu.use_insect_swarm:render("Insect Swarm", "Maintain Insect Swarm on target")
            menu.dot_refresh_seconds:render("Refresh Window (sec)", "Refresh DoTs when below this time")
            menu.use_force_of_nature:render("Force of Nature", "Use treants during burst")
        end)

        -- -- Rotation - Healing/Emergency ------------------------------------
        healing_tree:render("Healing & Emergency", function()
            menu.use_innervate:render("Innervate", "Auto-use for mana recovery")
            menu.innervate_mana_pct:render("Innervate Mana %", "Use below this mana %")
            menu.use_tranquility:render("Tranquility", "Emergency self-heal")
            menu.tranquility_hp_pct:render("Tranquility HP %", "Use below this HP %")
        end)

        -- -- Rotation - AoE ----------------------------------------------------
        aoe_tree:render("AoE", function()
            menu.use_hurricane:render("Hurricane", "Channel Hurricane on packs")
            menu.hurricane_min_targets:render("Min Targets", "Use above this count")
            menu.hurricane_mana_floor:render("Mana Floor %", "Don't use below this %")
            menu.use_remove_curse:render("Remove Curse", "Dispel curses")
        end)

        -- -- Automation --------------------------------------------------------
        auto_tree:render("Automation", function()
--            menu.auto_repair:render("Auto Repair", "Repair at vendors")
--            menu.auto_sell_greys:render("Auto Sell Greys", "Sell grey items")
--            menu.auto_mount:render("Auto Mount", "Mount when OOC")
--            menu.auto_dismount:render("Auto Dismount", "Dismount in combat")
            menu.auto_combat_potions:render("Combat Potions", "Use in combat")
            menu.auto_ooc_food_drink:render("OOC Food/Drink", "Eat/drink OOC")
            menu.auto_flask:render("Auto Flask", "Maintain flask buff")
        end)

        -- -- OOC Sustain -------------------------------------------------------
        ooc_tree:render("OOC Sustain", function()
            menu.ooc_drink:render("Auto-Drink", "Drink when OOC")
            menu.drink_threshold:render("Drink Threshold %", "Start below this %")
            menu.ooc_eat:render("Auto-Eat", "Eat when OOC")
            menu.eat_threshold:render("Eat Threshold %", "Start below this %")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Efficient rotation")
            menu.leveling_mana_floor:render("Mana Floor %", "Conserve below this %")
            menu.use_wand:render("Use Wand", "Wand when low mana")
            menu.wand_mana_floor:render("Wand Mana %", "Use below this %")
            menu.wand_at_hp:render("Wand Target HP %", "Only below this HP %")
        end)

        -- -- Group -------------------------------------------------------------
        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept resurrection")
            menu.ooc_group_buff:render("Group Buffs", "Buff party members")
        end)

        -- -- Defensive ---------------------------------------------------------
        def_tree:render("Defensive", function()
            menu.use_barkskin:render("Barkskin", "Damage reduction")
            menu.use_barkskin_hp_pct:render("Barkskin HP %", "Use below this HP %")
        end)

        -- -- Targeting --------------------------------------------------------
        ps.render_targeting(menu, tgt_tree)

        -- -- Racial ------------------------------------------------------------
        ps.render_racial(menu, racial_tree)

        -- -- Display/HUD -------------------------------------------------------
        esp_tree:render("Display", function()
            menu.esp_show_hud:render("Show HUD", "Display rotation status")
            menu.esp_show_target:render("Show Target", "Display target info")
            menu.esp_hud_x:render("HUD X", "Horizontal position")
            menu.esp_hud_y:render("HUD Y", "Vertical position")
        end)

    end)
end

return menu
