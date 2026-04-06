-- +------------------------------------------------------------------+
-- |  Eax's Warlock Destruction
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
menu.enabled                             = core.menu.checkbox(true, "eaxwarlockdestruction_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarlockdestruction_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarlockdestruction_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarlockdestruction_debug")
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarlockdestruction_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarlockdestruction_combat_self_hp_boost")
menu.use_racial                          = core.menu.checkbox(true, "eaxwarlockdestruction_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarlockdestruction_racial_hp")
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarlockdestruction_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarlockdestruction_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarlockdestruction_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarlockdestruction_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarlockdestruction_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxwarlockdestruction_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxwarlockdestruction_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxwarlockdestruction_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxwarlockdestruction_spirit_tap_wand")
-- Rotation
menu.use_immolate                        = core.menu.checkbox(true, "eaxwarlockdestruction_use_immolate")
menu.use_conflagrate                     = core.menu.checkbox(true, "eaxwarlockdestruction_use_conflagrate")
menu.use_incinerate                      = core.menu.checkbox(true, "eaxwarlockdestruction_use_incinerate")
menu.use_shadow_bolt                     = core.menu.checkbox(true, "eaxwarlockdestruction_use_shadow_bolt")
menu.use_soul_fire                       = core.menu.checkbox(true, "eaxwarlockdestruction_use_soul_fire")
menu.use_corruption                      = core.menu.checkbox(true, "eaxwarlockdestruction_use_corruption")
menu.use_curse_of_elements               = core.menu.checkbox(true, "eaxwarlockdestruction_use_curse_of_elements")
menu.use_curse_of_weakness               = core.menu.checkbox(true, "eaxwarlockdestruction_use_curse_of_weakness")
menu.use_curse_of_tongues                = core.menu.checkbox(true, "eaxwarlockdestruction_use_curse_of_tongues")
menu.use_curse_of_exhaustion             = core.menu.checkbox(true, "eaxwarlockdestruction_use_curse_of_exhaustion")
menu.use_fear                            = core.menu.checkbox(true, "eaxwarlockdestruction_use_fear")
menu.use_death_coil                      = core.menu.checkbox(true, "eaxwarlockdestruction_use_death_coil")
menu.use_howl_of_terror                  = core.menu.checkbox(true, "eaxwarlockdestruction_use_howl_of_terror")
menu.use_banish                          = core.menu.checkbox(true, "eaxwarlockdestruction_use_banish")
menu.use_enslave_demon                   = core.menu.checkbox(true, "eaxwarlockdestruction_use_enslave_demon")
menu.use_health_funnel                   = core.menu.checkbox(true, "eaxwarlockdestruction_use_health_funnel")
menu.use_life_tap                        = core.menu.checkbox(true, "eaxwarlockdestruction_use_life_tap")
menu.life_tap_mana_pct                   = core.menu.slider_int(10, 80, 40, "eaxwarlockdestruction_life_tap_mana_pct")
menu.use_drain_life                      = core.menu.checkbox(true, "eaxwarlockdestruction_use_drain_life")
menu.drain_life_hp_pct                   = core.menu.slider_int(0, 100, 40, "eaxwarlockdestruction_drain_life_hp_pct")
menu.use_soulstone                       = core.menu.checkbox(true, "eaxwarlockdestruction_use_soulstone")
menu.use_healthstone                     = core.menu.checkbox(true, "eaxwarlockdestruction_use_healthstone")
menu.healthstone_hp_pct                  = core.menu.slider_int(0, 100, 30, "eaxwarlockdestruction_healthstone_hp_pct")
menu.use_create_healthstone              = core.menu.checkbox(true, "eaxwarlockdestruction_use_create_healthstone")
menu.use_create_soulstone                = core.menu.checkbox(true, "eaxwarlockdestruction_use_create_soulstone")
menu.use_create_spellstone               = core.menu.checkbox(true, "eaxwarlockdestruction_use_create_spellstone")
menu.use_create_firestone                = core.menu.checkbox(true, "eaxwarlockdestruction_use_create_firestone")
menu.use_demon_armor                     = core.menu.checkbox(true, "eaxwarlockdestruction_use_demon_armor")
menu.use_fel_armor                       = core.menu.checkbox(true, "eaxwarlockdestruction_use_fel_armor")
menu.use_unending_breath                 = core.menu.checkbox(true, "eaxwarlockdestruction_use_unending_breath")
menu.use_detect_invisibility             = core.menu.checkbox(true, "eaxwarlockdestruction_use_detect_invisibility")
menu.use_eye_of_kilrogg                  = core.menu.checkbox(true, "eaxwarlockdestruction_use_eye_of_kilrogg")
menu.use_summon_pet                      = core.menu.checkbox(true, "eaxwarlockdestruction_use_summon_pet")
menu.use_soul_link                       = core.menu.checkbox(true, "eaxwarlockdestruction_use_soul_link")
menu.use_demonic_sacrifice               = core.menu.checkbox(true, "eaxwarlockdestruction_use_demonic_sacrifice")
menu.use_shadowburn                      = core.menu.checkbox(true, "eaxwarlockdestruction_use_shadowburn")
menu.use_searing_pain                    = core.menu.checkbox(true, "eaxwarlockdestruction_use_searing_pain")
menu.use_rain_of_fire                    = core.menu.checkbox(true, "eaxwarlockdestruction_use_rain_of_fire")
menu.use_hellfire                        = core.menu.checkbox(true, "eaxwarlockdestruction_use_hellfire")
menu.use_shadowfury                      = core.menu.checkbox(true, "eaxwarlockdestruction_use_shadowfury")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxwarlockdestruction_use_interrupt")
menu.profile                             = core.menu.combobox(1, "eaxwarlockdestruction_profile")
menu.curse_mode                          = core.menu.combobox(1, "eaxwarlockdestruction_curse_mode")
menu.life_tap_threshold                  = core.menu.slider_int(10, 80, 40, "eaxwarlockdestruction_life_tap_threshold")
menu.preferred_pet                       = core.menu.combobox(1, "eaxwarlockdestruction_preferred_pet")

mana_conservator.register_menu_items(menu, "eax_warlock_destruction")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_immolate", label = "Immolate" },
    { toggle = "use_conflagrate", label = "Conflagrate" },
    { toggle = "use_incinerate", label = "Incinerate" },
}, {
    namespace = "eaxwarlockdestruction",
    log_prefix = "[Eax Warlock Destro] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarlockdestruction")
    end

    root_tree:render("Eax's Warlock Destruction", function()
        ps.render_controls(menu, "Eax's Warlock Destro")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Fillers")
            menu.use_incinerate:render("Incinerate", "Main filler")
            menu.use_shadow_bolt:render("Shadow Bolt", "Filler")
            menu.use_soul_fire:render("Soul Fire", "Proc")
            menu.use_conflagrate:render("Conflagrate", "Instant")
            menu.use_immolate:render("Immolate", "Maintain")
            menu.use_corruption:render("Corruption", "Maintain")
            menu.use_curse_of_elements:render("CoE", "Debuff")
            menu.use_curse_of_weakness:render("CoW", "Debuff")
            menu.use_curse_of_tongues:render("CoT", "Cast slow")
            menu.use_curse_of_exhaustion:render("CoEx", "Slow")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_shadowburn:render("Shadowburn", "Instant")
            menu.use_searing_pain:render("Searing Pain", "Fast")
            menu.use_shadowfury:render("Shadowfury", "AoE stun")
            menu.use_death_coil:render("Death Coil", "Heal/fear")
            menu.use_howl_of_terror:render("Howl of Terror", "AoE fear")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
        end)

        -- Pet
        def_tree:render("Pet", function()
            menu.use_summon_pet:render("Summon Pet", "Summon")
            menu.use_soul_link:render("Soul Link", "Damage share")
            menu.use_demonic_sacrifice:render("Demonic Sacrifice", "Sacrifice")
            menu.use_health_funnel:render("Health Funnel", "Heal pet")
        end)

        -- Utility
        auto_tree:render("Utility", function()
            menu.use_fear:render("Fear", "CC")
            menu.use_banish:render("Banish", "CC")
            menu.use_enslave_demon:render("Enslave Demon", "CC")
            menu.use_life_tap:render("Life Tap", "Mana")
            menu.life_tap_mana_pct:render("Life Tap Mana %", "Below")
            menu.use_drain_life:render("Drain Life", "Heal")
            menu.drain_life_hp_pct:render("Drain Life HP %", "Below")
            menu.use_unending_breath:render("Unending Breath", "Buff")
            menu.use_detect_invisibility:render("Detect Invisibility", "Buff")
            menu.use_eye_of_kilrogg:render("Eye of Kilrogg", "Scout")
        end)

        -- Stones
        auto_tree:render("Stones", function()
            menu.use_soulstone:render("Soulstone", "Self-res")
            menu.use_healthstone:render("Healthstone", "Heal")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.use_create_healthstone:render("Create Healthstone", "Create")
            menu.use_create_soulstone:render("Create Soulstone", "Create")
            menu.use_create_spellstone:render("Create Spellstone", "Create")
            menu.use_create_firestone:render("Create Firestone", "Create")
        end)

        -- Armor
        auto_tree:render("Armor", function()
            menu.use_demon_armor:render("Demon Armor", "Armor")
            menu.use_fel_armor:render("Fel Armor", "Spell damage")
        end)

        -- AoE
        auto_tree:render("AoE", function()
            menu.use_rain_of_fire:render("Rain of Fire", "AoE")
            menu.use_hellfire:render("Hellfire", "AoE self-damage")
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
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end

return menu
