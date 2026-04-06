-- +------------------------------------------------------------------+
-- |  Eax's Priest Shadow
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
menu.enabled                             = core.menu.checkbox(true, "eaxpriestshadow_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpriestshadow_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpriestshadow_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpriestshadow_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpriestshadow_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpriestshadow_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpriestshadow_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpriestshadow_racial_hp")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxpriestshadow_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpriestshadow_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpriestshadow_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpriestshadow_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpriestshadow_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpriestshadow_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpriestshadow_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpriestshadow_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpriestshadow_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpriestshadow_spirit_tap_wand")

-- Rotation
menu.use_shadow_word_pain                = core.menu.checkbox(true, "eaxpriestshadow_use_shadow_word_pain")
menu.use_vampiric_touch                  = core.menu.checkbox(true, "eaxpriestshadow_use_vampiric_touch")
menu.use_mind_flay                       = core.menu.checkbox(true, "eaxpriestshadow_use_mind_flay")
menu.use_mind_blast                      = core.menu.checkbox(true, "eaxpriestshadow_use_mind_blast")
menu.use_shadow_word_death               = core.menu.checkbox(true, "eaxpriestshadow_use_shadow_word_death")
menu.use_devouring_plague                = core.menu.checkbox(true, "eaxpriestshadow_use_devouring_plague")
menu.use_shadowfiend                     = core.menu.checkbox(true, "eaxpriestshadow_use_shadowfiend")
menu.use_vampiric_embrace                = core.menu.checkbox(true, "eaxpriestshadow_use_vampiric_embrace")
menu.keep_shadowform                     = core.menu.checkbox(true, "eaxpriestshadow_keep_shadowform")
menu.use_inner_fire                      = core.menu.checkbox(true, "eaxpriestshadow_use_inner_fire")
menu.use_power_word_fortitude            = core.menu.checkbox(true, "eaxpriestshadow_use_power_word_fortitude")
menu.use_power_word_shield               = core.menu.checkbox(true, "eaxpriestshadow_use_power_word_shield")
menu.power_word_shield_hp_pct            = core.menu.slider_int(0, 100, 40, "eaxpriestshadow_power_word_shield_hp_pct")
menu.use_renew                           = core.menu.checkbox(true, "eaxpriestshadow_use_renew")
menu.renew_hp_pct                        = core.menu.slider_int(0, 100, 50, "eaxpriestshadow_renew_hp_pct")
menu.use_flash_heal                      = core.menu.checkbox(true, "eaxpriestshadow_use_flash_heal")
menu.flash_heal_hp_pct                   = core.menu.slider_int(0, 100, 30, "eaxpriestshadow_flash_heal_hp_pct")
menu.use_dispel_magic                    = core.menu.checkbox(true, "eaxpriestshadow_use_dispel_magic")
menu.use_cure_disease                    = core.menu.checkbox(true, "eaxpriestshadow_use_cure_disease")
menu.use_psychic_scream                  = core.menu.checkbox(true, "eaxpriestshadow_use_psychic_scream")
menu.use_shackle_undead                  = core.menu.checkbox(true, "eaxpriestshadow_use_shackle_undead")
menu.use_resurrection                    = core.menu.checkbox(true, "eaxpriestshadow_use_resurrection")

-- Shadow Weaving
menu.use_shadow_weaving                  = core.menu.checkbox(true, "eaxpriestshadow_use_shadow_weaving")
menu.shadow_weaving_refresh_window       = core.menu.slider_int(1, 10, 3, "eaxpriestshadow_sw_refresh_window")

-- Flux-ported features
menu.use_starshards                      = core.menu.checkbox(false, "eaxpriestshadow_use_starshards")
menu.use_inner_focus                     = core.menu.checkbox(true, "eaxpriestshadow_use_inner_focus")
menu.low_mana_pws_pct                    = core.menu.slider_int(10, 80, 50, "eaxpriestshadow_low_mana_pws_pct")
menu.aoe_swp_count                       = core.menu.slider_int(2, 10, 2, "eaxpriestshadow_aoe_swp_count")
menu.aoe_vt_count                        = core.menu.slider_int(2, 10, 2, "eaxpriestshadow_aoe_vt_count")

mana_conservator.register_menu_items(menu, "eax_priest_shadow")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_shadow_word_pain", label = "SW:P" },
    { toggle = "use_vampiric_touch", label = "Vampiric Touch" },
    { toggle = "use_mind_flay", label = "Mind Flay" },
    { toggle = "use_mind_blast", label = "Mind Blast" },
}, {
    namespace = "eaxpriestshadow",
    log_prefix = "[Eax Priest Shadow] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpriestshadow")
    end

    root_tree:render("Eax's Priest Shadow", function()
        ps.render_controls(menu, "Eax's Priest Shadow")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("DoTs")
            menu.use_shadow_word_pain:render("SW:P", "Maintain")
            menu.use_vampiric_touch:render("Vampiric Touch", "Maintain")
            menu.use_devouring_plague:render("Devouring Plague", "Maintain")

            ps.header("Fillers")
            menu.use_mind_flay:render("Mind Flay", "Filler")
            menu.use_mind_blast:render("Mind Blast", "On CD")
            menu.use_shadow_word_death:render("SW:D", "Execute")

            ps.header("Cooldowns")
            menu.use_shadowfiend:render("Shadowfiend", "Mana/DPS")
            menu.use_vampiric_embrace:render("Vampiric Embrace", "Heal")

            ps.header("Shadow Weaving")
            menu.use_shadow_weaving:render("Maintain Stacks", "Auto-cast")
            menu.shadow_weaving_refresh_window:render("Refresh Window", "Seconds before drop")

            ps.header("Buffs")
            menu.keep_shadowform:render("Keep Shadowform", "Auto-cast")
            menu.use_inner_fire:render("Inner Fire", "Armor")
            menu.use_power_word_fortitude:render("PW:F", "Stamina")
        end)

        -- Self-Healing
        def_tree:render("Self-Healing", function()
            menu.use_power_word_shield:render("PW:Shield", "Shield")
            menu.power_word_shield_hp_pct:render("PW:S HP %", "Below")
            menu.use_renew:render("Renew", "HoT")
            menu.renew_hp_pct:render("Renew HP %", "Below")
            menu.use_flash_heal:render("Flash Heal", "Emergency")
            menu.flash_heal_hp_pct:render("Flash Heal HP %", "Below")
        end)

        -- Utility
        cd_tree:render("Utility", function()
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_dispel_magic:render("Dispel Magic", "Dispel")
            menu.use_cure_disease:render("Cure Disease", "Dispel")
            menu.use_psychic_scream:render("Psychic Scream", "Fear")
            menu.use_shackle_undead:render("Shackle Undead", "CC")
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
