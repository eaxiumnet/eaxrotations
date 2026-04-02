-- +------------------------------------------------------------------+
-- |  Eax's Paladin Holy
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree    = ps.tree_node()
local rotation_tree = ps.tree_node()
local healing_tree = ps.tree_node()
local cd_tree      = ps.tree_node()
local auto_tree    = ps.tree_node()
local ooc_tree     = ps.tree_node()
local group_tree   = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
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

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpaladinholy_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpaladinholy_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpaladinholy_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpaladinholy_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpaladinholy_lev_mana_floor")

-- Healing
menu.use_holy_light                      = core.menu.checkbox(true, "eaxpaladinholy_use_holy_light")
menu.holy_light_hp_pct                   = core.menu.slider_int(0, 100, 60, "eaxpaladinholy_holy_light_hp_pct")
menu.use_flash_of_light                  = core.menu.checkbox(true, "eaxpaladinholy_use_flash_of_light")
menu.flash_of_light_hp_pct               = core.menu.slider_int(0, 100, 75, "eaxpaladinholy_flash_of_light_hp_pct")
menu.use_holy_shock                      = core.menu.checkbox(true, "eaxpaladinholy_use_holy_shock")
menu.holy_shock_hp_pct                   = core.menu.slider_int(0, 100, 50, "eaxpaladinholy_holy_shock_hp_pct")
menu.use_divine_illumination             = core.menu.checkbox(true, "eaxpaladinholy_use_divine_illumination")
menu.use_beacon                          = core.menu.checkbox(true, "eaxpaladinholy_use_beacon")
menu.use_cleanse                         = core.menu.checkbox(true, "eaxpaladinholy_use_cleanse")
menu.use_lay_on_hands                    = core.menu.checkbox(true, "eaxpaladinholy_use_lay_on_hands")
menu.lay_on_hands_hp_pct                 = core.menu.slider_int(5, 30, 15, "eaxpaladinholy_lay_on_hands_hp_pct")
menu.use_divine_favor                    = core.menu.checkbox(true, "eaxpaladinholy_use_divine_favor")
menu.use_divine_shield                   = core.menu.checkbox(true, "eaxpaladinholy_use_divine_shield")
menu.divine_shield_hp_pct                = core.menu.slider_int(0, 100, 20, "eaxpaladinholy_divine_shield_hp_pct")
menu.use_blessing_of_light               = core.menu.checkbox(true, "eaxpaladinholy_use_blessing_of_light")
menu.use_blessing_of_wisdom              = core.menu.checkbox(true, "eaxpaladinholy_use_blessing_of_wisdom")
menu.use_blessing_of_might               = core.menu.checkbox(true, "eaxpaladinholy_use_blessing_of_might")
menu.use_blessing_of_kings               = core.menu.checkbox(true, "eaxpaladinholy_use_blessing_of_kings")
menu.use_seal_of_light                   = core.menu.checkbox(true, "eaxpaladinholy_use_seal_of_light")
menu.use_seal_of_wisdom                  = core.menu.checkbox(true, "eaxpaladinholy_use_seal_of_wisdom")
menu.use_seal_of_righteousness           = core.menu.checkbox(true, "eaxpaladinholy_use_seal_of_righteousness")
menu.use_judgement                       = core.menu.checkbox(true, "eaxpaladinholy_use_judgement")
menu.use_consecration                    = core.menu.checkbox(true, "eaxpaladinholy_use_consecration")
menu.use_exorcism                        = core.menu.checkbox(true, "eaxpaladinholy_use_exorcism")
menu.use_holy_wrath                      = core.menu.checkbox(true, "eaxpaladinholy_use_holy_wrath")
menu.use_turn_undead                     = core.menu.checkbox(true, "eaxpaladinholy_use_turn_undead")
menu.use_redemption                      = core.menu.checkbox(true, "eaxpaladinholy_use_redemption")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_holy_light", label = "Holy Light" },
    { toggle = "use_flash_of_light", label = "Flash of Light" },
    { toggle = "use_holy_shock", label = "Holy Shock" },
    { toggle = "use_divine_illumination", label = "Divine Illumination" },
}, {
    namespace = "eaxpaladinholy",
    log_prefix = "[Eax Paladin Holy] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpaladinholy")
    end

    root_tree:render("Eax's Paladin Holy", function()
        ps.render_controls(menu, "Eax's Paladin Holy")

        -- Healing
        healing_tree:render("Healing", function()
            ps.header("Direct Heals")
            menu.use_holy_light:render("Holy Light", "Main heal")
            menu.holy_light_hp_pct:render("Holy Light HP %", "Below")
            menu.use_flash_of_light:render("Flash of Light", "Fast heal")
            menu.flash_of_light_hp_pct:render("FoL HP %", "Below")
            menu.use_holy_shock:render("Holy Shock", "Instant heal")
            menu.holy_shock_hp_pct:render("Holy Shock HP %", "Below")
            menu.use_divine_illumination:render("Divine Illumination", "CD reduction")
            menu.use_cleanse:render("Cleansing", "Dispel")
            menu.use_lay_on_hands:render("Lay on Hands", "Emergency")
            menu.lay_on_hands_hp_pct:render("LoH HP %", "Below")
            menu.use_divine_favor:render("Divine Favor", "Guaranteed crit")
        end)

        -- DPS Fallback
        rotation_tree:render("DPS Fallback", function()
            menu.use_seal_of_light:render("Seal of Light", "Heal on hit")
            menu.use_seal_of_wisdom:render("Seal of Wisdom", "Mana on hit")
            menu.use_seal_of_righteousness:render("Seal of Righteousness", "DPS")
            menu.use_judgement:render("Judgement", "On CD")
            menu.use_consecration:render("Consecration", "AoE")
            menu.use_exorcism:render("Exorcism", "Undead/Demon")
            menu.use_holy_wrath:render("Holy Wrath", "AoE undead")
            menu.use_turn_undead:render("Turn Undead", "CC")
        end)

        -- Blessings
        cd_tree:render("Blessings", function()
            menu.use_blessing_of_light:render("BoL", "Heal boost")
            menu.use_blessing_of_wisdom:render("BoW", "Mana regen")
            menu.use_blessing_of_might:render("BoM", "AP buff")
            menu.use_blessing_of_kings:render("BoK", "Stats buff")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_divine_shield:render("Divine Shield", "Immunity")
            menu.divine_shield_hp_pct:render("Divine Shield HP %", "Below")
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
