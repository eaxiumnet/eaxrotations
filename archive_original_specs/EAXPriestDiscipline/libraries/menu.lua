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

-- Healing (Flux-inspired thresholds)
menu.use_greater_heal                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_greater_heal")
menu.greater_heal_hp_pct                = core.menu.slider_int(10, 100, 60, "eaxpriestdiscipline_greater_heal_hp_pct")
menu.use_flash_heal                      = core.menu.checkbox(true, "eaxpriestdiscipline_use_flash_heal")
menu.flash_heal_hp_pct                  = core.menu.slider_int(10, 100, 50, "eaxpriestdiscipline_flash_heal_hp_pct")  -- Flux: <50% emergency
menu.disc_emergency_hp                   = core.menu.slider_int(5, 50, 30, "eaxpriestdiscipline_emergency_hp")  -- Flux: <30% emergency heals
menu.use_power_word_shield               = core.menu.checkbox(true, "eaxpriestdiscipline_use_power_word_shield")
menu.shield_threshold                    = core.menu.slider_int(10, 100, 85, "eaxpriestdiscipline_shield_threshold")
menu.disc_shield_emergency_hp            = core.menu.slider_int(5, 50, 30, "eaxpriestdiscipline_shield_emergency_hp")  -- Flux: emergency PW:S
menu.use_weakened_soul                   = core.menu.checkbox(true, "eaxpriestdiscipline_use_weakened_soul")
-- NOTE: Penance is WotLK spell (3.0.2), not TBC - removed
menu.use_renew                           = core.menu.checkbox(true, "eaxpriestdiscipline_use_renew")
menu.renew_threshold                     = core.menu.slider_int(0, 100, 90, "eaxpriestdiscipline_renew_threshold")  -- Flux: 90%
menu.renew_refresh_seconds               = core.menu.slider_int(0, 10, 3, "eaxpriestdiscipline_renew_refresh")
menu.disc_prepull_renew                  = core.menu.checkbox(true, "eaxpriestdiscipline_prepull_renew")  -- Flux: pre-pull Renew on tank
-- NOTE: Aegis/Divine Aegis are WotLK talents, not TBC - removed
menu.use_power_infusion                  = core.menu.checkbox(true, "eaxpriestdiscipline_use_power_infusion")
menu.power_infusion_enabled              = core.menu.checkbox(true, "eaxpriestdiscipline_power_infusion_enabled")
menu.power_infusion_threshold            = core.menu.slider_int(10, 100, 50, "eaxpriestdiscipline_power_infusion_threshold")
menu.use_pain_suppression                = core.menu.checkbox(true, "eaxpriestdiscipline_use_pain_suppression")
menu.pain_suppression_threshold          = core.menu.slider_int(10, 80, 40, "eaxpriestdiscipline_pain_suppression_threshold")
menu.use_binding_heal                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_binding_heal")
menu.binding_heal_self_threshold         = core.menu.slider_int(0, 100, 80, "eaxpriestdiscipline_binding_heal_self_threshold")  -- Flux: 80%
menu.binding_heal_target_threshold       = core.menu.slider_int(0, 100, 80, "eaxpriestdiscipline_binding_heal_target_threshold")  -- Flux: 80%
menu.use_prayer_of_mending               = core.menu.checkbox(true, "eaxpriestdiscipline_use_prayer_of_mending")
menu.prayer_of_mending_threshold         = core.menu.slider_int(10, 100, 85, "eaxpriestdiscipline_prayer_of_mending_threshold")
menu.prepull_pom                         = core.menu.checkbox(true, "eaxpriestdiscipline_prepull_pom")  -- Flux: pre-pull PoM
menu.disc_aoe_hp                         = core.menu.slider_int(50, 100, 80, "eaxpriestdiscipline_aoe_hp")  -- Flux: group damage
menu.disc_aoe_count                      = core.menu.slider_int(2, 5, 3, "eaxpriestdiscipline_aoe_count")
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
menu.use_interrupt                        = core.menu.checkbox(true, "eaxpriestdiscipline_use_interrupt")

-- Utility toggles
menu.use_dispels                         = core.menu.checkbox(true, "eaxpriestdiscipline_use_dispels")
menu.use_inner_focus                     = core.menu.checkbox(true, "eaxpriestdiscipline_use_inner_focus")

mana_conservator.register_menu_items(menu, "eax_priest_discipline")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_greater_heal", label = "Greater Heal" },
    { toggle = "use_flash_heal", label = "Flash Heal" },
    { toggle = "use_power_word_shield", label = "PW:Shield" },
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
            menu.greater_heal_hp_pct:render("Greater Heal HP %", "Below")
            menu.use_flash_heal:render("Flash Heal", "Fast heal")
            menu.flash_heal_hp_pct:render("Flash Heal HP %", "Below")
            menu.disc_emergency_hp:render("Emergency HP %", "Flash Heal emergency threshold")
            menu.use_renew:render("Renew", "HoT")
            menu.renew_threshold:render("Renew HP %", "Below")
            menu.renew_refresh_seconds:render("Renew Refresh", "Seconds before expiry")
            menu.disc_prepull_renew:render("Pre-Pull Renew", "Cast Renew on tank before combat")
            menu.use_weakened_soul:render("Weakened Soul", "Track debuff")
            ps.header("Shields & Cooldowns")
            menu.use_power_word_shield:render("PW:Shield", "Shield")
            menu.shield_threshold:render("Shield Threshold", "HP% to cast")
            menu.disc_shield_emergency_hp:render("PW:S Emergency %", "Emergency shield threshold")
            -- NOTE: Penance/Aegis/Divine Aegis are WotLK, not TBC - removed
            menu.use_power_infusion:render("Power Infusion", "Haste buff")
            menu.use_pain_suppression:render("Pain Suppression", "Tank cooldown")
            menu.pain_suppression_threshold:render("Pain Suppression %", "Below")
            menu.use_inner_focus:render("Inner Focus", "Free spell")
            ps.header("Group Healing")
            menu.use_prayer_of_mending:render("Prayer of Mending", "Bounce heal")
            menu.prayer_of_mending_threshold:render("PoM Threshold", "HP% to cast")
            menu.prepull_pom:render("Pre-Pull PoM", "Cast PoM on tank before combat")
            menu.use_binding_heal:render("Binding Heal", "Self+Target heal")
            menu.binding_heal_self_threshold:render("Binding Self HP %", "Self below")
            menu.binding_heal_target_threshold:render("Binding Target HP %", "Target below")
            ps.header("AoE Healing")
            menu.disc_aoe_hp:render("AoE HP Threshold", "Group damage threshold")
            menu.disc_aoe_count:render("AoE Min Count", "Min injured for AoE")
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
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
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
