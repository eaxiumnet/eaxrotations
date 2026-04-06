-- +------------------------------------------------------------------+
-- |  Eax's Paladin Protection
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
    spec_name = "eaxpaladinprotection",
    class_name = "Paladin",
    role = "tank",
})

local settings_tree = {
    targeting = tgt_tree,
    racial = racial_tree,
    ooc = ooc_tree,
    display = esp_tree,
}

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxpaladinprotection_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpaladinprotection_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpaladinprotection_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpaladinprotection_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpaladinprotection_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpaladinprotection_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpaladinprotection_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpaladinprotection_racial_hp")

-- Interrupt
menu.use_interrupt                       = core.menu.checkbox(true, "eaxpaladinprotection_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpaladinprotection_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpaladinprotection_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpaladinprotection_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpaladinprotection_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpaladinprotection_lev_mana_floor")

-- Rotation
menu.use_holy_shield                     = core.menu.checkbox(true, "eaxpaladinprotection_use_holy_shield")
menu.use_shield_of_righteous             = core.menu.checkbox(true, "eaxpaladinprotection_use_shield_of_righteous")
menu.use_judgement                       = core.menu.checkbox(true, "eaxpaladinprotection_use_judgement")
menu.use_consecration                    = core.menu.checkbox(true, "eaxpaladinprotection_use_consecration")
menu.use_hammer_of_wrath                 = core.menu.checkbox(true, "eaxpaladinprotection_use_hammer_of_wrath")
menu.use_avengers_shield                 = core.menu.checkbox(true, "eaxpaladinprotection_use_avengers_shield")
menu.use_exorcism                        = core.menu.checkbox(true, "eaxpaladinprotection_use_exorcism")
menu.use_righteous_fury                  = core.menu.checkbox(true, "eaxpaladinprotection_use_righteous_fury")
menu.use_seal_of_righteousness           = core.menu.checkbox(true, "eaxpaladinprotection_use_seal_of_righteousness")
menu.use_seal_of_vengeance               = core.menu.checkbox(true, "eaxpaladinprotection_use_seal_of_vengeance")
menu.use_seal_of_command                 = core.menu.checkbox(true, "eaxpaladinprotection_use_seal_of_command")
menu.use_blessing_of_sanctuary           = core.menu.checkbox(true, "eaxpaladinprotection_use_blessing_of_sanctuary")
menu.use_blessing_of_kings               = core.menu.checkbox(true, "eaxpaladinprotection_use_blessing_of_kings")
menu.use_blessing_of_might               = core.menu.checkbox(true, "eaxpaladinprotection_use_blessing_of_might")
menu.use_blessing_of_wisdom              = core.menu.checkbox(true, "eaxpaladinprotection_use_blessing_of_wisdom")
menu.use_divine_shield                   = core.menu.checkbox(true, "eaxpaladinprotection_use_divine_shield")
menu.divine_shield_hp_pct                = core.menu.slider_int(0, 100, 20, "eaxpaladinprotection_divine_shield_hp_pct")
menu.use_lay_on_hands                    = core.menu.checkbox(true, "eaxpaladinprotection_use_lay_on_hands")
menu.lay_on_hands_hp_pct                 = core.menu.slider_int(5, 30, 15, "eaxpaladinprotection_lay_on_hands_hp_pct")
menu.use_divine_protection               = core.menu.checkbox(true, "eaxpaladinprotection_use_divine_protection")
menu.divine_protection_hp_pct            = core.menu.slider_int(0, 100, 30, "eaxpaladinprotection_divine_protection_hp_pct")
menu.use_blessing_of_protection          = core.menu.checkbox(true, "eaxpaladinprotection_use_blessing_of_protection")
menu.blessing_of_protection_hp_pct       = core.menu.slider_int(0, 100, 25, "eaxpaladinprotection_blessing_of_protection_hp_pct")
menu.use_redemption                      = core.menu.checkbox(true, "eaxpaladinprotection_use_redemption")
menu.use_cleansing                       = core.menu.checkbox(true, "eaxpaladinprotection_use_cleansing")
menu.use_turn_undead                     = core.menu.checkbox(true, "eaxpaladinprotection_use_turn_undead")
menu.use_holy_wrath                      = core.menu.checkbox(true, "eaxpaladinprotection_use_holy_wrath")
menu.show_notifications = core.menu.checkbox(true, "eaxpaladinprotection_show_notifications")
menu.consecration_enemy_count = core.menu.slider_int(1, 10, 3, "eaxpaladinprotection_consecration_enemy_count")
menu.consecration_radius = core.menu.slider_int(1, 30, 8, "eaxpaladinprotection_consecration_radius")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_holy_shield", label = "Holy Shield" },
    { toggle = "use_shield_of_righteous", label = "Shield of Righteous" },
    { toggle = "use_judgement", label = "Judgement" },
    { toggle = "use_consecration", label = "Consecration" },
}, {
    namespace = "eaxpaladinprotection",
    log_prefix = "[Eax Paladin Prot] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpaladinprotection")
    end

    root_tree:render("Eax's Paladin Protection", function()
        ps.render_controls(menu, "Eax's Paladin Prot")

        -- Rotation
        rotation_tree:render("Rotation", function()
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            ps.header("Abilities")
            menu.use_holy_shield:render("Holy Shield", "On CD")
            menu.use_shield_of_righteous:render("Shield of Righteous", "Filler")
            menu.use_judgement:render("Judgement", "On CD")
            menu.use_consecration:render("Consecration", "AoE")
            menu.use_hammer_of_wrath:render("Hammer of Wrath", "Execute")
            menu.use_avengers_shield:render("Avenger's Shield", "Pull")
            menu.use_exorcism:render("Exorcism", "Undead/Demon")
            menu.use_righteous_fury:render("Righteous Fury", "Threat")
            menu.use_seal_of_righteousness:render("Seal of Righteousness", "DPS")
            menu.use_seal_of_vengeance:render("Seal of Vengeance", "DoT")
            menu.use_seal_of_command:render("Seal of Command", "Proc")
            menu.use_cleansing:render("Cleansing", "Dispel")
            menu.use_turn_undead:render("Turn Undead", "CC")
            menu.use_holy_wrath:render("Holy Wrath", "AoE undead")
        end)

        -- Blessings
        cd_tree:render("Blessings", function()
            menu.use_blessing_of_sanctuary:render("BoS", "Damage reduction")
            menu.use_blessing_of_kings:render("BoK", "Stats buff")
            menu.use_blessing_of_might:render("BoM", "AP buff")
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
            menu.use_blessing_of_protection:render("BoP", "Physical immunity")
            menu.blessing_of_protection_hp_pct:render("BoP HP %", "Below")
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
    end)
end

return menu
