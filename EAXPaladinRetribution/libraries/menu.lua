-- +------------------------------------------------------------------+
-- |  Eax's Paladin Retribution
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree    = ps.tree_node()
local rotation_tree = ps.tree_node()
local cd_tree      = ps.tree_node()
local auto_tree    = ps.tree_node()
local ooc_tree     = ps.tree_node()
local group_tree   = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
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

-- Automation
-- menu.auto_repair                        = core.menu.checkbox(true, "eaxpaladinretribution_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxpaladinretribution_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxpaladinretribution_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxpaladinretribution_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpaladinretribution_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpaladinretribution_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpaladinretribution_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpaladinretribution_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpaladinretribution_lev_mana_floor")

-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- Rotation
menu.use_crusader_strike                 = core.menu.checkbox(true, "eaxpaladinretribution_use_crusader_strike")
menu.use_judgement                       = core.menu.checkbox(true, "eaxpaladinretribution_use_judgement")
menu.use_hammer_of_wrath                 = core.menu.checkbox(true, "eaxpaladinretribution_use_hammer_of_wrath")
menu.use_exorcism                        = core.menu.checkbox(true, "eaxpaladinretribution_use_exorcism")
menu.use_consecration                    = core.menu.checkbox(true, "eaxpaladinretribution_use_consecration")
menu.use_divine_storm                    = core.menu.checkbox(true, "eaxpaladinretribution_use_divine_storm")
menu.use_blade_of_justice               = core.menu.checkbox(true, "eaxpaladinretribution_use_blade_of_justice")
menu.use_seal_of_command                 = core.menu.checkbox(true, "eaxpaladinretribution_use_seal_of_command")
menu.use_seal_of_vengeance               = core.menu.checkbox(true, "eaxpaladinretribution_use_seal_of_vengeance")
menu.use_seal_of_righteousness           = core.menu.checkbox(true, "eaxpaladinretribution_use_seal_of_righteousness")
menu.use_blessing_of_might               = core.menu.checkbox(true, "eaxpaladinretribution_use_blessing_of_might")
menu.use_blessing_of_kings               = core.menu.checkbox(true, "eaxpaladinretribution_use_blessing_of_kings")
menu.use_blessing_of_wisdom              = core.menu.checkbox(true, "eaxpaladinretribution_use_blessing_of_wisdom")
menu.use_divine_illumination             = core.menu.checkbox(true, "eaxpaladinretribution_use_divine_illumination")
menu.use_zealotry                        = core.menu.checkbox(true, "eaxpaladinretribution_use_zealotry")
menu.use_crusader_aura                   = core.menu.checkbox(true, "eaxpaladinretribution_use_crusader_aura")
menu.use_retribution_aura                = core.menu.checkbox(true, "eaxpaladinretribution_use_retribution_aura")
menu.use_divine_shield                   = core.menu.checkbox(true, "eaxpaladinretribution_use_divine_shield")
menu.divine_shield_hp_pct                = core.menu.slider_int(0, 100, 20, "eaxpaladinretribution_divine_shield_hp_pct")
menu.use_lay_on_hands                    = core.menu.checkbox(true, "eaxpaladinretribution_use_lay_on_hands")
menu.lay_on_hands_hp_pct                 = core.menu.slider_int(5, 30, 15, "eaxpaladinretribution_lay_on_hands_hp_pct")
menu.use_divine_protection               = core.menu.checkbox(true, "eaxpaladinretribution_use_divine_protection")
menu.divine_protection_hp_pct            = core.menu.slider_int(0, 100, 30, "eaxpaladinretribution_divine_protection_hp_pct")
menu.use_redemption                      = core.menu.checkbox(true, "eaxpaladinretribution_use_redemption")
menu.use_cleansing                       = core.menu.checkbox(true, "eaxpaladinretribution_use_cleansing")
menu.use_turn_undead                     = core.menu.checkbox(true, "eaxpaladinretribution_use_turn_undead")
menu.use_holy_wrath                      = core.menu.checkbox(true, "eaxpaladinretribution_use_holy_wrath")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_crusader_strike", label = "Crusader Strike" },
    { toggle = "use_judgement", label = "Judgement" },
    { toggle = "use_divine_storm", label = "Divine Storm" },
    { toggle = "use_consecration", label = "Consecration" },
}, {
    namespace = "eaxpaladinretribution",
    log_prefix = "[Eax Paladin Ret] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpaladinretribution")
    end

    root_tree:render("Eax's Paladin Retribution", function()
        ps.render_controls(menu, "Eax's Paladin Ret")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_crusader_strike:render("Crusader Strike", "On CD")
            menu.use_judgement:render("Judgement", "On CD")
            menu.use_hammer_of_wrath:render("Hammer of Wrath", "Execute")
            menu.use_exorcism:render("Exorcism", "Undead/Demon")
            menu.use_consecration:render("Consecration", "AoE")
            menu.use_divine_storm:render("Divine Storm", "AoE")
            menu.use_blade_of_justice:render("Blade of Justice", "Filler")
            menu.use_seal_of_command:render("Seal of Command", "Proc")
            menu.use_seal_of_vengeance:render("Seal of Vengeance", "DoT")
            menu.use_seal_of_righteousness:render("Seal of Righteousness", "DPS")
            menu.use_cleansing:render("Cleansing", "Dispel")
            menu.use_turn_undead:render("Turn Undead", "CC")
            menu.use_holy_wrath:render("Holy Wrath", "AoE undead")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_divine_illumination:render("Divine Illumination", "CD reduction")
            menu.use_zealotry:render("Zealotry", "Burst")
            menu.use_crusader_aura:render("Crusader Aura", "Speed")
            menu.use_retribution_aura:render("Retribution Aura", "Damage")
        end)

        -- Blessings
        def_tree:render("Blessings", function()
            menu.use_blessing_of_might:render("BoM", "AP buff")
            menu.use_blessing_of_kings:render("BoK", "Stats buff")
            menu.use_blessing_of_wisdom:render("BoW", "Mana regen")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_divine_shield:render("Divine Shield", "Immunity")
            menu.divine_shield_hp_pct:render("Divine Shield HP %", "Below")
            menu.use_lay_on_hands:render("Lay on Hands", "Emergency")
            menu.lay_on_hands_hp_pct:render("LoH HP %", "Below")
            menu.use_divine_protection:render("Divine Protection", "Damage reduction")
            menu.divine_protection_hp_pct:render("Divine Protection HP %", "Below")
        end)

        -- Automation
        auto_tree:render("Automation", function()
            menu.auto_combat_potions:render("Combat Potions", "In combat")
            menu.auto_ooc_food_drink:render("OOC Food/Drink", "Eat/drink")
            menu.auto_flask:render("Auto Flask", "Flask")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling")
            menu.leveling_mana_floor:render("Mana %", "Below")
        end)

        -- OOC
        ooc_tree:render("OOC Sustain", function()
            menu.ooc_drink:render("Auto-Drink", "Drink")
            menu.drink_threshold:render("Drink %", "Below")
            menu.ooc_eat:render("Auto-Eat", "Eat")
            menu.eat_threshold:render("Eat %", "Below")
        end)

        -- Group
        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
            menu.use_redemption:render("Redemption", "Resurrect")
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)

        -- Display
        esp_tree:render("Display", function()
            menu.esp_show_hud:render("Show HUD", "Status")
            menu.esp_show_target:render("Show Target", "Info")
            menu.esp_hud_x:render("HUD X", "")
            menu.esp_hud_y:render("HUD Y", "")
        end)
    end)
end

return menu
