-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Priest Discipline
-- ║  Space Theme v4.0  ·  Stars drawn inside the panel background
-- ╚══════════════════════════════════════════════════════════════════╝
local mana_conservator = require("mana_conservator")

local ps   = require("ps_theme")
local menu = {}

-- -- Tree nodes ----------------------------------------------------------------
local root_tree    = ps.tree_node()
local main_tree    = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local ooc_tree     = ps.tree_node()
local esp_tree     = ps.tree_node()

-- -- Shared plugin controls + shared fields ------------------------------------
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxpriestdiscipline_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpriestdiscipline_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpriestdiscipline_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpriestdiscipline_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpriestdiscipline_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpriestdiscipline_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpriestdiscipline_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpriestdiscipline_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpriestdiscipline_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpriestdiscipline_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpriestdiscipline_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpriestdiscipline_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpriestdiscipline_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpriestdiscipline_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.shield_threshold                     = core.menu.slider_int(10, 90, 60, "eax_priest_discipline_shield_threshold")
menu.renew_threshold                      = core.menu.slider_int(10, 90, 75, "eax_priest_discipline_renew_threshold")
menu.renew_refresh_seconds                = core.menu.slider_int(1, 5, 2, "eax_priest_discipline_renew_refresh_seconds")
menu.pain_suppression_threshold           = core.menu.slider_int(5, 40, 25, "eax_priest_discipline_pain_suppression_threshold")
menu.power_infusion_enabled               = core.menu.checkbox(true, "eax_priest_discipline_power_infusion")
menu.power_infusion_threshold             = core.menu.slider_int(25, 75, 45, "eax_priest_discipline_power_infusion_threshold")
menu.prayer_of_mending                    = core.menu.checkbox(true, "eax_priest_discipline_prayer_of_mending")
menu.prayer_of_mending_threshold          = core.menu.slider_int(20, 80, 55, "eax_priest_discipline_prayer_of_mending_threshold")
menu.overheal_protection                  = core.menu.checkbox(true, "eax_priest_discipline_overheal_protection")

mana_conservator.register_menu_items(menu, "eax_priest_discipline")

-- ════════════════════════════════════════════════════════════════════════════
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ════════════════════════════════════════════════════════════════════════════

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxpriestdiscipline")
    end

    root_tree:render("  Eax's Priest Discipline", function()

        ps.render_controls(menu, "Eax's Priest Discipline")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.shield_threshold:render("Shield Threshold", "Shield allies when they drop below this percent")
            menu.renew_threshold:render("Renew Threshold", "Refresh Renew when allies fall below this percent")
            menu.renew_refresh_seconds:render("Renew Refresh Window", "Refresh Renew when the buff has this many seconds left")
            menu.pain_suppression_threshold:render("Pain Suppression", "Drop Pain Suppression on targets below this percent")
            menu.power_infusion_enabled:render("Power Infusion", "Enable automatic Power Infusion windows")
            menu.power_infusion_threshold:render("Power Infusion Trigger", "Use Power Infusion when an ally crosses this percent")
            menu.prayer_of_mending:render("Prayer of Mending", "Spread Prayer of Mending when Renew is already affecting the target")
            menu.prayer_of_mending_threshold:render("PoM Threshold", "Cast Prayer of Mending when an ally falls below this percent")
            menu.overheal_protection:render("Overheal Protection", "Cancel slow heals when target is near full HP")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_pain_suppression", label = "Pain Suppression", tip = "Emergency 40% damage reduction on self", hp_key = "use_pain_suppression_hp_pct", hp_label = "Pain Suppression HP %" },
        { key = "use_power_word_shield_self", label = "PW: Shield (Self)", tip = "Maintain Power Word Shield on self", hp_key = "use_power_word_shield_self_hp_pct", hp_label = "PW: Shield (Self) HP %" },
        })

        -- -- Targeting --------------------------------------------------------
        ps.render_targeting(menu, tgt_tree)

        -- -- Racial ------------------------------------------------------------
        ps.render_racial(menu, racial_tree)

        -- -- Out-of-combat -----------------------------------------------------
        ps.render_ooc(menu, ooc_tree, true)

        -- -- Display & HUD -----------------------------------------------------
        ps.render_esp(menu, esp_tree)

    end)
end

menu.use_pain_suppression = core.menu.checkbox(true, "eaxpdisc_pain_suppression")
menu.use_pain_suppression_hp_pct = core.menu.slider_int(0, 100, 30, "eaxpdisc_pain_supp_hp")
menu.use_power_word_shield_self = core.menu.checkbox(true, "eaxpdisc_pw_shield_self")
menu.use_power_word_shield_self_hp_pct = core.menu.slider_int(0, 100, 80, "eaxpdisc_pw_shield_hp")
return menu
