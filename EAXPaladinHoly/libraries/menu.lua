-- +------------------------------------------------------------------+
-- |  Eax's Paladin Holy
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

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
local esp_tree     = ps.tree_node()

settings.init({
    spec_name = "eaxpaladinholy",
    class_name = "Paladin",
    role = "healer",
})

local settings_tree = {
    targeting = tgt_tree,
    racial = racial_tree,
    ooc = ooc_tree,
    display = esp_tree,
}

-- -- Shared plugin controls + shared fields ------------------------------------
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxpaladinholy_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpaladinholy_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpaladinholy_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpaladinholy_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpaladinholy_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpaladinholy_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpaladinholy_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpaladinholy_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_repair                        = core.menu.checkbox(true, "eaxpaladinholy_auto_repair")
menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxpaladinholy_auto_sell_greys")
menu.auto_mount                         = core.menu.checkbox(true, "eaxpaladinholy_auto_mount")
menu.auto_dismount                      = core.menu.checkbox(true, "eaxpaladinholy_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpaladinholy_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpaladinholy_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpaladinholy_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpaladinholy_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpaladinholy_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpaladinholy_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpaladinholy_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpaladinholy_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpaladinholy_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_holy_light                       = core.menu.checkbox(true, "use_holy_light")
menu.holy_light_hp_pct                    = core.menu.slider_int(20, 70, 40, "holy_light_hp_pct")
menu.use_flash_of_light                   = core.menu.checkbox(true, "use_flash_of_light")
menu.flash_of_light_hp_pct                = core.menu.slider_int(40, 95, 90, "flash_of_light_hp_pct")
menu.use_holy_shock                       = core.menu.checkbox(true, "use_holy_shock")
menu.holy_shock_hp_pct                    = core.menu.slider_int(5, 60, 50, "holy_shock_hp_pct")
menu.use_divine_illumination              = core.menu.checkbox(true, "eaxpaladinholy_use_divine_illumination")
menu.use_divine_favor                     = core.menu.checkbox(true, "eaxpaladinholy_use_divine_favor")
menu.use_avenging_wrath                   = core.menu.checkbox(true, "eaxpaladinholy_use_avenging_wrath")
menu.use_cleanse                          = core.menu.checkbox(true, "eaxpaladinholy_use_cleanse")
menu.use_cleanse_key                      = core.menu.keybind(7, false, "eaxpaladinholy_use_cleanse_key")
menu.maintain_judgement                   = core.menu.checkbox(true, "eaxpaladinholy_maintain_judgement")
menu.judgement_mode                       = core.menu.combobox(1, "eaxpaladinholy_judgement_mode")
menu.use_hand_of_freedom                  = core.menu.checkbox(true, "eaxpaladinholy_use_hof")
menu.use_hand_of_freedom_key              = core.menu.keybind(7, false, "eaxpaladinholy_use_hof_key")
menu.hof_include_slows                    = core.menu.checkbox(false, "eaxpaladinholy_hof_slows")
menu.auto_blessings                       = core.menu.checkbox(true, "auto_blessings")
menu.auto_blessings_key                   = core.menu.keybind(7, false, "eaxpaladinholy_auto_blessings_key")
menu.overheal_protection                  = core.menu.checkbox(true, "overheal_protection")
menu.use_aura                             = core.menu.checkbox(true, "eaxpaladinholy_use_aura")

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
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxpaladinholy")
    end

    root_tree:render("Eax's Paladin Holy", function()

        settings.render_controls(menu, "Eax's Paladin Holy")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_holy_light:render("Holy Light", "Big heals for tanks and hard hits")
            menu.holy_light_hp_pct:render("Holy Light HP %", "Cast Holy Light when a target drops below this percent")
            menu.use_flash_of_light:render("Flash of Light", "Fast heals for raid/dungeon damage spikes")
            menu.flash_of_light_hp_pct:render("Flash HP %", "Use Flash when a target drops below this percent")
            menu.use_holy_shock:render("Holy Shock", "Instant heal on cooldown for urgent targets")
            menu.holy_shock_hp_pct:render("Holy Shock HP %", "Threshold to consider Holy Shock")
            menu.use_divine_illumination:render("Divine Illumination", "Use the TBC mana-cost reduction cooldown before heavy healing")
            menu.use_divine_favor:render("Divine Favor", "Guarantee a critical Holy Light or Holy Shock for emergency healing moments")
            menu.use_avenging_wrath:render("Avenging Wrath", "Use healing throughput cooldown on pull pressure or group danger")
            menu.use_cleanse:render("Cleanse", "Remove known poison or disease debuffs with Cleanse or Purify")
            menu.use_cleanse_key:render("Cleanse Hotkey", "Toggle Cleanse on/off")
            menu.maintain_judgement:render("Maintain Judgement", "Safely keep Judgement of Wisdom or Light on your current enemy when healing pressure is low")
            menu.judgement_mode:render("Judgement Mode", { "Wisdom", "Light" })
            menu.use_hand_of_freedom:render("Hand of Freedom", "Cast Hand of Freedom on rooted/snared friendly units")
            menu.use_hand_of_freedom_key:render("Freedom Hotkey", "Toggle Hand of Freedom on/off")
            menu.hof_include_slows:render("Freedom on Slows", "Also use Hand of Freedom on slowed (not just rooted) allies")
            menu.auto_blessings:render("Auto Blessings", "Keep Blessing of Might on tanks and Blessing of Wisdom on mana users")
            menu.auto_blessings_key:render("Blessings Hotkey", "Toggle Auto Blessings on/off")
            menu.overheal_protection:render("Stopcast on Overheal Risk", "Cancel slow heals when the target is near full HP")
            menu.use_aura:render("Aura Upkeep", "Maintain Concentration Aura if available, otherwise Devotion Aura")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_divine_shield", label = "Divine Shield", tip = "Emergency immunity bubble", hp_key = "use_divine_shield_hp_pct", hp_label = "Divine Shield HP %" },
        { key = "use_lay_on_hands", label = "Lay on Hands", tip = "Emergency full heal on self", hp_key = "use_lay_on_hands_hp_pct", hp_label = "Lay on Hands HP %" },
        })
        -- -- Targeting --------------------------------------------------------
        settings.render_targeting(menu, settings_tree)

        -- -- Racial ------------------------------------------------------------
        settings.render_racial(menu, settings_tree)

        -- -- Out-of-combat -----------------------------------------------------
        settings.render_ooc(menu, settings_tree)

        -- -- Display & HUD -----------------------------------------------------
        settings.render_display(menu, settings_tree)

    end)
end

menu.use_divine_shield = core.menu.checkbox(true, "eaxpholy_divine_shield")
menu.use_divine_shield_hp_pct = core.menu.slider_int(0, 100, 20, "eaxpholy_divine_shield_hp")
menu.use_lay_on_hands = core.menu.checkbox(true, "eaxpholy_lay_on_hands")
menu.use_lay_on_hands_hp_pct = core.menu.slider_int(0, 100, 10, "eaxpholy_loh_hp")
return menu
