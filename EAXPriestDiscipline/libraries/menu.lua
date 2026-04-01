-- +------------------------------------------------------------------+
-- |  Eax's Priest Discipline
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+
local mana_conservator = require("libraries/mana_conservator")

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

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpriestdiscipline_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpriestdiscipline_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpriestdiscipline_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpriestdiscipline_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpriestdiscipline_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpriestdiscipline_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpriestdiscipline_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpriestdiscipline_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpriestdiscipline_spirit_tap_wand")

-- Healing
menu.use_greater_heal                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_greater_heal")
menu.use_flash_heal                      = core.menu.checkbox(true, "eaxpriestdiscipline_use_flash_heal")
menu.use_power_word_shield               = core.menu.checkbox(true, "eaxpriestdiscipline_use_power_word_shield")
menu.use_weakened_soul                   = core.menu.checkbox(true, "eaxpriestdiscipline_use_weakened_soul")
menu.use_penance                         = core.menu.checkbox(true, "eaxpriestdiscipline_use_penance")
menu.use_aegis                           = core.menu.checkbox(true, "eaxpriestdiscipline_use_aegis")
menu.use_power_infusion                  = core.menu.checkbox(true, "eaxpriestdiscipline_use_power_infusion")
menu.use_divine_aegis                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_divine_aegis")
menu.use_inner_fire                      = core.menu.checkbox(true, "eaxpriestdiscipline_use_inner_fire")
menu.use_power_word_fortitude            = core.menu.checkbox(true, "eaxpriestdiscipline_use_power_word_fortitude")
menu.use_dispel_magic                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_dispel_magic")
menu.use_cure_disease                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_cure_disease")
menu.use_abolish_disease                 = core.menu.checkbox(true, "eaxpriestdiscipline_use_abolish_disease")
menu.use_psychic_scream                  = core.menu.checkbox(true, "eaxpriestdiscipline_use_psychic_scream")
menu.use_shackle_undead                  = core.menu.checkbox(true, "eaxpriestdiscipline_use_shackle_undead")
menu.use_resurrection                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_resurrection")
menu.use_smite                           = core.menu.checkbox(true, "eaxpriestdiscipline_use_smite")
menu.use_holy_fire                       = core.menu.checkbox(true, "eaxpriestdiscipline_use_holy_fire")
menu.use_shadow_word_pain                = core.menu.checkbox(true, "eaxpriestdiscipline_use_shadow_word_pain")
menu.use_mind_blast                      = core.menu.checkbox(true, "eaxpriestdiscipline_use_mind_blast")

mana_conservator.register_menu_items(menu, "eax_priest_discipline")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_greater_heal", label = "Greater Heal" },
    { toggle = "use_flash_heal", label = "Flash Heal" },
    { toggle = "use_power_word_shield", label = "PW:Shield" },
    { toggle = "use_penance", label = "Penance" },
}, {
    namespace = "eaxpriestdiscipline",
    log_prefix = "[Eax Priest Disc] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpriestdiscipline")
    end

    root_tree:render("Eax's Priest Discipline", function()
        ps.render_controls(menu, "Eax's Priest Disc")

        -- Healing
        rotation_tree:render("Healing", function()
            ps.header("Direct Heals")
            menu.use_greater_heal:render("Greater Heal", "Main heal")
            menu.use_flash_heal:render("Flash Heal", "Fast heal")
            menu.use_power_word_shield:render("PW:Shield", "Shield")
            menu.use_weakened_soul:render("Weakened Soul", "Track debuff")
            menu.use_penance:render("Penance", "Instant heal")
            menu.use_aegis:render("Aegis", "Shield proc")
            menu.use_power_infusion:render("Power Infusion", "Haste buff")
            menu.use_divine_aegis:render("Divine Aegis", "Shield proc")
        end)

        -- Buffs
        cd_tree:render("Buffs", function()
            menu.use_inner_fire:render("Inner Fire", "Armor")
            menu.use_power_word_fortitude:render("PW:F", "Stamina")
        end)

        -- Utility
        def_tree:render("Utility", function()
            menu.use_dispel_magic:render("Dispel Magic", "Dispel")
            menu.use_cure_disease:render("Cure Disease", "Dispel")
            menu.use_abolish_disease:render("Abolish Disease", "Dispel")
            menu.use_psychic_scream:render("Psychic Scream", "Fear")
            menu.use_shackle_undead:render("Shackle Undead", "CC")
        end)

        -- DPS Fallback
        auto_tree:render("DPS Fallback", function()
            menu.use_smite:render("Smite", "Filler")
            menu.use_holy_fire:render("Holy Fire", "Cast")
            menu.use_shadow_word_pain:render("SW:P", "DoT")
            menu.use_mind_blast:render("Mind Blast", "Instant")
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
        end)

        -- Group
        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
            menu.use_resurrection:render("Resurrection", "Resurrect")
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end

return menu
