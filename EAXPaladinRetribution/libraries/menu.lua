-- +------------------------------------------------------------------+
-- |  Eax's Paladin Retribution
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
    spec_name = "eaxpaladinretribution",
    class_name = "Paladin",
    role = "dps",
})

local settings_tree = {
    targeting = tgt_tree,
    racial = racial_tree,
    ooc = ooc_tree,
    display = esp_tree,
}

-- -- Shared plugin controls + shared fields ------------------------------------
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxpaladinretribution_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpaladinretribution_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpaladinretribution_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpaladinretribution_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpaladinretribution_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpaladinretribution_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpaladinretribution_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpaladinretribution_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- menu.auto_repair                        = core.menu.checkbox(true, "eaxpaladinretribution_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxpaladinretribution_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxpaladinretribution_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxpaladinretribution_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpaladinretribution_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpaladinretribution_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpaladinretribution_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpaladinretribution_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpaladinretribution_lev_mana_floor")
menu.use_hand_of_freedom                  = core.menu.checkbox(true, "eaxpaladinretribution_use_hof")
menu.use_hand_of_freedom_key              = core.menu.keybind(7, false, "eaxpaladinretribution_use_hof_key")
menu.hof_include_slows                    = core.menu.checkbox(false, "eaxpaladinretribution_hof_slows")
menu.use_cleanse                          = core.menu.checkbox(true, "eaxpaladinretribution_use_cleanse")
menu.use_aura                             = core.menu.checkbox(true, "eaxpaladinretribution_use_aura")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_judgement                        = core.menu.checkbox(true, "eaxpr_use_judgement")
menu.judgement_choice                     = core.menu.combobox(1, "eaxpr_judgement_choice")
menu.use_crusader_strike                  = core.menu.checkbox(true, "eaxpr_use_crusader_strike")
menu.use_consecration                     = core.menu.checkbox(true, "eaxpr_use_consecration")
menu.use_consecration_key                 = core.menu.keybind(7, false, "eaxpr_use_consecration_key")
menu.use_exorcism                         = core.menu.checkbox(true, "eaxpr_use_exorcism")
menu.use_exorcism_key                     = core.menu.keybind(7, false, "eaxpr_use_exorcism_key")
menu.use_divine_favor                     = core.menu.checkbox(true, "eaxpr_use_divine_favor")
menu.use_avenging_wrath                   = core.menu.checkbox(true, "eaxpr_use_avenging_wrath")
menu.use_seal_twist                       = core.menu.checkbox(true, "eaxpr_use_seal_twist")
menu.use_seal_twist_key                   = core.menu.keybind(7, false, "eaxpr_use_seal_twist_key")
menu.seal_twist_window                    = core.menu.slider_int(200, 1200, 450, "eaxpr_seal_twist_window")
menu.seal_twist_cooldown                  = core.menu.slider_int(800, 4000, 1600, "eaxpr_seal_twist_cooldown")
menu.allow_twist_dungeon                  = core.menu.checkbox(true, "eaxpr_twist_dungeon")
menu.allow_twist_raid                     = core.menu.checkbox(true, "eaxpr_twist_raid")

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
        ps.draw_space(_win, "eaxpaladinretribution")
    end

    root_tree:render("Eax's Paladin Retribution", function()

        settings.render_controls(menu, "Eax's Paladin Retribution")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_judgement:render("Judgement", "Maintain the chosen judgement debuff")
            menu.use_crusader_strike:render("Crusader Strike", "Cast on cooldown when the GCD is ready")
            menu.use_consecration:render("Consecration", "Drop Consecration when fighting in melee")
            menu.use_consecration_key:render("Consecration Hotkey", "Toggle Consecration on/off")
            menu.use_exorcism:render("Exorcism", "Use Exorcism against undead and demon targets")
            menu.use_exorcism_key:render("Exorcism Hotkey", "Toggle Exorcism on/off")
            menu.use_divine_favor:render("Divine Favor", "Use Divine Favor in burst windows")
            menu.use_avenging_wrath:render("Avenging Wrath", "Use Avenging Wrath when offensive cooldowns are allowed")
            menu.use_seal_twist:render("Enable Seal Twists", "Twist Seal of Command into Blood or Righteousness inside the next melee swing window")
            menu.use_seal_twist_key:render("Twist Hotkey", "Toggle Seal Twisting on/off")
            menu.seal_twist_window:render("Twist Window (ms)", "Only start a twist when the next swing is inside this many milliseconds")
            menu.seal_twist_cooldown:render("Twist Cooldown (ms)", "Minimum time between completed twists")
            menu.allow_twist_dungeon:render("Allow in Dungeon", "Permit twisting when dungeon mode is active")
            menu.allow_twist_raid:render("Allow in Raid", "Permit twisting when raid mode is active")
            menu.judgement_choice:render("Judgement Mode", { "Wisdom", "Crusader", "Light" })
            menu.use_hammer_of_wrath:render("Hammer of Wrath", "Use execute at low target HP")
            menu.use_hand_of_freedom_key:render("Freedom Hotkey", "Toggle Hand of Freedom on/off")
            menu.use_cleanse:render("Cleanse", "Lightly remove poison and disease from allies")
            menu.use_aura:render("Aura Upkeep", "Maintain Retribution Aura when not already active")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_divine_shield", label = "Divine Shield", tip = "Emergency immunity bubble", hp_key = "use_divine_shield_hp_pct", hp_label = "Divine Shield HP %" },
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

menu.use_hammer_of_wrath = core.menu.checkbox(true, "eaxpret_hammer_of_wrath")
menu.use_lay_on_hands   = core.menu.checkbox(true, "eaxpret_lay_on_hands")
menu.use_divine_shield = core.menu.checkbox(true, "eaxpret_divine_shield")
menu.use_divine_shield_hp_pct = core.menu.slider_int(0, 100, 20, "eaxpret_divine_shield_hp")
return menu
