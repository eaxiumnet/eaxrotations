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
local main_tree    = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local ooc_tree     = ps.tree_node()
-- local esp_tree     = ps.tree_node()

-- -- Shared plugin controls + shared fields ------------------------------------
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxdruidbalance_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxdruidbalance_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxdruidbalance_mode")
menu.debug                               = core.menu.checkbox(false, "eaxdruidbalance_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxdruidbalance_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxdruidbalance_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxdruidbalance_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxdruidbalance_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- menu.auto_repair                        = core.menu.checkbox(true, "eaxdruidbalance_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxdruidbalance_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxdruidbalance_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxdruidbalance_auto_dismount")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxdruidbalance_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxdruidbalance_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxdruidbalance_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxdruidbalance_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxdruidbalance_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxdruidbalance_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxdruidbalance_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxdruidbalance_spirit_tap_wand")
-- ESP
-- menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
-- menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
-- menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
-- menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")
-- -- Class-specific elements ---------------------------------------------------
menu.use_root_escape                     = core.menu.checkbox(true, "eaxdruidbalance_root_escape")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxdruidbalance_remove_curse")
menu.force_moonkin                        = core.menu.checkbox(true, "eaxdruidbalance_force_moonkin")
menu.use_faerie_fire                      = core.menu.checkbox(true, "eaxdruidbalance_use_faerie_fire")
menu.use_moonfire                         = core.menu.checkbox(true, "eaxdruidbalance_use_moonfire")
menu.use_insect_swarm                     = core.menu.checkbox(true, "eaxdruidbalance_use_insect_swarm")
menu.dot_refresh_seconds                  = core.menu.slider_int(1, 5, 3, "eaxdruidbalance_dot_refresh_seconds")
menu.use_force_of_nature                  = core.menu.checkbox(true, "eaxdruidbalance_use_force_of_nature")
menu.use_hurricane                        = core.menu.checkbox(true, "eaxdruidbalance_use_hurricane")
menu.hurricane_min_targets                = core.menu.slider_int(2, 8, 4, "eaxdruidbalance_hurricane_min_targets")
menu.hurricane_mana_floor                 = core.menu.slider_int(10, 80, 40, "eaxdruidbalance_hurricane_mana_floor")
menu.use_innervate                        = core.menu.checkbox(true, "eaxdruidbalance_use_innervate")
menu.innervate_mana_pct                   = core.menu.slider_int(10, 60, 30, "eaxdruidbalance_innervate_mana_pct")
menu.use_tranquility                      = core.menu.checkbox(true, "eaxdruidbalance_use_tranquility")
menu.tranquility_hp_pct                   = core.menu.slider_int(20, 70, 35, "eaxdruidbalance_tranquility_hp_pct")
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
-- ----------------------------------------------------------------------------
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ----------------------------------------------------------------------------

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "EAXDruidBalance")
    end
    
    root_tree:render("Eax's Druid Balance", function()

        ps.render_controls(menu, "Eax's Druid Balance")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.force_moonkin:render("Force Moonkin Form", "Keep Moonkin Form active whenever possible")
            menu.use_faerie_fire:render("Faerie Fire", "Maintain Faerie Fire on the active target")
            menu.use_moonfire:render("Moonfire", "Maintain Moonfire on the active target")
            menu.use_insect_swarm:render("Insect Swarm", "Maintain Insect Swarm on the active target")
            menu.dot_refresh_seconds:render("Refresh Window (sec)", "Refresh Moonfire and Insect Swarm when remaining time is below this value")
            menu.use_force_of_nature:render("Force of Nature", "Use Force of Nature during established pressure windows")
            menu.use_innervate:render("Innervate", "Recover mana automatically when out of combat or in a dry lane")
            menu.innervate_mana_pct:render("Innervate Mana %", "Mana threshold for Innervate")
            menu.use_tranquility:render("Emergency Tranquility", "Allow Tranquility as a self-preservation emergency")
            menu.tranquility_hp_pct:render("Tranquility HP %", "Self-health threshold for emergency Tranquility")
            ps.header("AoE")
            menu.use_hurricane:render("Hurricane", "Channel Hurricane on packs above the target count")
            menu.hurricane_min_targets:render("Hurricane Min Targets", "Minimum enemies before Hurricane fires")
            menu.hurricane_mana_floor:render("Hurricane Mana Floor %", "Don't Hurricane below this mana %")
            menu.use_remove_curse:render("Remove Curse", "Dispel curses from self and party")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_barkskin", label = "Barkskin", tip = "Emergency damage reduction", hp_key = "use_barkskin_hp_pct", hp_label = "Barkskin HP %" },
        })

        -- -- Targeting --------------------------------------------------------
        ps.render_targeting(menu, tgt_tree)

        -- -- Racial ------------------------------------------------------------
        ps.render_racial(menu, racial_tree)

        -- -- Out-of-combat -----------------------------------------------------
--         menu.auto_repair:render("Auto Repair", "Automatically repair gear at vendors")
--         menu.auto_sell_greys:render("Auto Sell Greys", "Automatically sell poor-quality items at vendors")
--         menu.auto_mount:render("Auto Mount", "Automatically mount when traveling out of combat")
--         menu.auto_dismount:render("Auto Dismount", "Automatically dismount when entering combat")
        menu.auto_ooc_food_drink:render("Auto OOC Food/Drink", "Use food and drink out of combat when needed")
        menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")
        ps.render_ooc(menu, ooc_tree, true)

        -- -- Display & HUD -----------------------------------------------------
    -- ps.render_esp(menu, esp_tree) -- DISABLED
    end)
end

return menu
