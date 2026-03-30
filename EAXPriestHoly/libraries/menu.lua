-- +------------------------------------------------------------------+
-- |  Eax's Priest Holy
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
menu.enabled                             = core.menu.checkbox(true, "eaxpriestholy_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpriestholy_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpriestholy_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpriestholy_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpriestholy_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpriestholy_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpriestholy_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpriestholy_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- menu.auto_repair                        = core.menu.checkbox(true, "eaxpriestholy_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxpriestholy_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxpriestholy_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxpriestholy_auto_dismount")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpriestholy_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpriestholy_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpriestholy_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpriestholy_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpriestholy_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpriestholy_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpriestholy_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpriestholy_spirit_tap_wand")
-- ESP
-- menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
-- menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
-- menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
-- menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")
-- -- Class-specific elements ---------------------------------------------------
menu.renew_threshold                      = core.menu.slider_int(10, 90, 85, "eax_priest_holy_renew_threshold")
menu.renew_refresh_seconds                = core.menu.slider_int(1, 5, 2, "eax_priest_holy_renew_refresh_seconds")
menu.flash_heal_threshold                 = core.menu.slider_int(10, 60, 30, "eax_priest_holy_flash_heal_threshold")
menu.greater_heal_threshold               = core.menu.slider_int(25, 70, 50, "eax_priest_holy_greater_heal_threshold")
menu.binding_heal_enabled                 = core.menu.checkbox(true, "eax_priest_holy_binding_heal_enabled")
menu.binding_heal_target_threshold        = core.menu.slider_int(20, 80, 50, "eax_priest_holy_binding_heal_target_threshold")
menu.binding_heal_self_threshold          = core.menu.slider_int(30, 95, 80, "eax_priest_holy_binding_heal_self_threshold")
menu.prayer_of_healing_enabled            = core.menu.checkbox(true, "eax_priest_holy_pohealing_enabled")
menu.prayer_of_healing_threshold          = core.menu.slider_int(30, 85, 75, "eax_priest_holy_prayer_of_healing_threshold")
menu.prayer_of_healing_count              = core.menu.slider_int(1, 5, 3, "eax_priest_holy_prayer_of_healing_count")
menu.circle_of_healing_enabled            = core.menu.checkbox(true, "eax_priest_holy_coh_enabled")
menu.circle_of_healing_threshold          = core.menu.slider_int(30, 90, 80, "eax_priest_holy_circle_of_healing_threshold")
menu.circle_of_healing_count              = core.menu.slider_int(1, 5, 3, "eax_priest_holy_circle_of_healing_count")
menu.use_cooldowns                        = core.menu.checkbox(true, "eax_priest_holy_use_cooldowns")
menu.use_inner_focus                      = core.menu.checkbox(true, "eax_priest_holy_use_inner_focus")
menu.auto_prayer_of_mending               = core.menu.checkbox(true, "eax_priest_holy_auto_pom")
menu.prayer_of_mending_threshold          = core.menu.slider_int(25, 90, 80, "eax_priest_holy_pom_threshold")
menu.overheal_protection                  = core.menu.checkbox(true, "eax_priest_holy_overheal_protection")
menu.use_dispels                          = core.menu.checkbox(true, "eax_priest_holy_use_dispels")

mana_conservator.register_menu_items(menu, "eax_priest_holy")

-- ----------------------------------------------------------------------------
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ----------------------------------------------------------------------------

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "prayer_of_healing_enabled", label = "Prayer of Healing" },
    { toggle = "auto_prayer_of_mending", label = "Prayer of Mending" },
    { toggle = "circle_of_healing_enabled", label = "Circle of Healing" },
    { toggle = "overheal_protection", label = "Overheal Protection" },
    { toggle = "use_desperate_prayer", label = "Desperate Prayer" },
}, {
    namespace = "eaxpriestholy",
    log_prefix = "[Eax Priest Holy] ",
})

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    
    root_tree:render("Eax's Priest Holy", function()

        ps.render_controls(menu, "Eax's Priest Holy")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.renew_threshold:render("Renew Threshold", "Only refresh renew when health drops below this")
            menu.renew_refresh_seconds:render("Renew Refresh Window", "Seconds of Renew remaining before refreshing")
            menu.flash_heal_threshold:render("Flash Heal Threshold", "Emergency Flash Heal threshold for critical targets")
            menu.greater_heal_threshold:render("Greater Heal Threshold", "Use Greater Heal for sustained healing below this percent")
            menu.binding_heal_enabled:render("Binding Heal", "Use Binding Heal when both you and an ally need healing")
            menu.binding_heal_target_threshold:render("Binding Target HP", "Use Binding Heal when an ally falls below this percent")
            menu.binding_heal_self_threshold:render("Binding Self HP", "Use Binding Heal when your own health is below this percent")
            menu.prayer_of_healing_enabled:render("Prayer of Healing", "Allow Prayer of Healing when multiple targets are hurt")
            menu.prayer_of_healing_threshold:render("PoH Threshold", "Health percent that counts targets toward Prayer of Healing")
            menu.prayer_of_healing_count:render("PoH Count", "Minimum wounded allies to fire Prayer of Healing")
            menu.circle_of_healing_enabled:render("Circle of Healing", "Allow Circle of Healing when multiple targets are hurt")
            menu.circle_of_healing_threshold:render("CoH Threshold", "Health percent that counts targets toward Circle of Healing")
            menu.circle_of_healing_count:render("CoH Count", "Minimum wounded allies to fire Circle of Healing")
            menu.use_inner_focus:render("Inner Focus", "Use Inner Focus before expensive direct or party heals")
            menu.auto_prayer_of_mending:render("Auto Prayer of Mending", "Keep Prayer of Mending rolling on injured allies")
            menu.prayer_of_mending_threshold:render("PoM Threshold", "Health percent that triggers Prayer of Mending refresh")
            menu.overheal_protection:render("Stopcast on Overheal Risk", "Cancel slow heals when the target is near full HP")
            menu.use_dispels:render("Combat Dispels", "Allow Dispel Magic and disease cleanses on the current heal target")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_desperate_prayer", label = "Desperate Prayer", tip = "Emergency instant self-heal", hp_key = "use_desperate_prayer_hp_pct", hp_label = "Desperate Prayer HP %" },
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

menu.use_desperate_prayer = core.menu.checkbox(true, "eaxpholy_desperate_prayer")
menu.use_desperate_prayer_hp_pct = core.menu.slider_int(0, 100, 40, "eaxpholy_desp_prayer_hp")
return menu
