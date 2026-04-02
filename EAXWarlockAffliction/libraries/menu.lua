-- +------------------------------------------------------------------+
-- |  Eax's Warlock Affliction
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
menu.enabled                             = core.menu.checkbox(true, "eaxwarlockaffliction_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarlockaffliction_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarlockaffliction_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarlockaffliction_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarlockaffliction_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarlockaffliction_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarlockaffliction_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarlockaffliction_racial_hp")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarlockaffliction_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarlockaffliction_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarlockaffliction_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarlockaffliction_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarlockaffliction_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxwarlockaffliction_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxwarlockaffliction_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxwarlockaffliction_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxwarlockaffliction_spirit_tap_wand")

-- Rotation
menu.use_corruption                      = core.menu.checkbox(true, "eaxwarlockaffliction_use_corruption")
menu.use_immolate                        = core.menu.checkbox(true, "eaxwarlockaffliction_use_immolate")
menu.use_unstable_affliction             = core.menu.checkbox(true, "eaxwarlockaffliction_use_unstable_affliction")
menu.use_siphon_life                    = core.menu.checkbox(true, "eaxwarlockaffliction_use_siphon_life")
menu.use_drain_soul                      = core.menu.checkbox(true, "eaxwarlockaffliction_use_drain_soul")
menu.use_shadow_bolt                     = core.menu.checkbox(true, "eaxwarlockaffliction_use_shadow_bolt")
menu.use_isb_gated_siphon               = core.menu.checkbox(true, "eaxwarlockaffliction_use_isb_gated_siphon")
menu.isb_sl_min_stacks                 = core.menu.slider_int(1, 5, 3, "eaxwarlockaffliction_isb_sl_min_stacks")
menu.use_dark_pact                       = core.menu.checkbox(true, "eaxwarlockaffliction_use_dark_pact")
menu.use_shadow_fiend                    = core.menu.checkbox(true, "eaxwarlockaffliction_use_shadow_fiend")
menu.use_soul_harvest                    = core.menu.checkbox(true, "eaxwarlockaffliction_use_soul_harvest")
menu.use_curse_of_agony                  = core.menu.checkbox(true, "eaxwarlockaffliction_use_curse_of_agony")
menu.use_curse_of_elements               = core.menu.checkbox(true, "eaxwarlockaffliction_use_curse_of_elements")
menu.use_curse_of_weakness               = core.menu.checkbox(true, "eaxwarlockaffliction_use_curse_of_weakness")
menu.use_curse_of_tongues                = core.menu.checkbox(true, "eaxwarlockaffliction_use_curse_of_tongues")
menu.use_curse_of_exhaustion             = core.menu.checkbox(true, "eaxwarlockaffliction_use_curse_of_exhaustion")
menu.use_fear                            = core.menu.checkbox(true, "eaxwarlockaffliction_use_fear")
menu.use_death_coil                      = core.menu.checkbox(true, "eaxwarlockaffliction_use_death_coil")
menu.use_howl_of_terror                  = core.menu.checkbox(true, "eaxwarlockaffliction_use_howl_of_terror")
menu.use_banish                          = core.menu.checkbox(true, "eaxwarlockaffliction_use_banish")
menu.use_enslave_demon                   = core.menu.checkbox(true, "eaxwarlockaffliction_use_enslave_demon")
menu.use_health_funnel                   = core.menu.checkbox(true, "eaxwarlockaffliction_use_health_funnel")
menu.use_life_tap                        = core.menu.checkbox(true, "eaxwarlockaffliction_use_life_tap")
menu.life_tap_mana_pct                   = core.menu.slider_int(10, 80, 40, "eaxwarlockaffliction_life_tap_mana_pct")
menu.use_drain_life                      = core.menu.checkbox(true, "eaxwarlockaffliction_use_drain_life")
menu.drain_life_hp_pct                   = core.menu.slider_int(0, 100, 40, "eaxwarlockaffliction_drain_life_hp_pct")
menu.use_soulstone                       = core.menu.checkbox(true, "eaxwarlockaffliction_use_soulstone")
menu.use_healthstone                     = core.menu.checkbox(true, "eaxwarlockaffliction_use_healthstone")
menu.healthstone_hp_pct                  = core.menu.slider_int(0, 100, 30, "eaxwarlockaffliction_healthstone_hp_pct")
menu.use_create_healthstone              = core.menu.checkbox(true, "eaxwarlockaffliction_use_create_healthstone")
menu.use_create_soulstone                = core.menu.checkbox(true, "eaxwarlockaffliction_use_create_soulstone")
menu.use_create_spellstone               = core.menu.checkbox(true, "eaxwarlockaffliction_use_create_spellstone")
menu.use_create_firestone                = core.menu.checkbox(true, "eaxwarlockaffliction_use_create_firestone")
menu.use_demon_armor                     = core.menu.checkbox(true, "eaxwarlockaffliction_use_demon_armor")
menu.use_fel_armor                       = core.menu.checkbox(true, "eaxwarlockaffliction_use_fel_armor")
menu.use_unending_breath                 = core.menu.checkbox(true, "eaxwarlockaffliction_use_unending_breath")
menu.use_detect_invisibility             = core.menu.checkbox(true, "eaxwarlockaffliction_use_detect_invisibility")
menu.use_eye_of_kilrogg                  = core.menu.checkbox(true, "eaxwarlockaffliction_use_eye_of_kilrogg")
menu.use_summon_pet                      = core.menu.checkbox(true, "eaxwarlockaffliction_use_summon_pet")
menu.use_soul_link                       = core.menu.checkbox(true, "eaxwarlockaffliction_use_soul_link")
menu.use_demonic_sacrifice               = core.menu.checkbox(true, "eaxwarlockaffliction_use_demonic_sacrifice")
menu.use_shadowburn                      = core.menu.checkbox(true, "eaxwarlockaffliction_use_shadowburn")
menu.use_searing_pain                    = core.menu.checkbox(true, "eaxwarlockaffliction_use_searing_pain")
menu.use_rain_of_fire                    = core.menu.checkbox(true, "eaxwarlockaffliction_use_rain_of_fire")
menu.use_hellfire                        = core.menu.checkbox(true, "eaxwarlockaffliction_use_hellfire")
menu.use_soul_fire                       = core.menu.checkbox(true, "eaxwarlockaffliction_use_soul_fire")
menu.use_conflagrate                     = core.menu.checkbox(true, "eaxwarlockaffliction_use_conflagrate")
menu.use_incinerate                      = core.menu.checkbox(true, "eaxwarlockaffliction_use_incinerate")
menu.use_shadowfury                      = core.menu.checkbox(true, "eaxwarlockaffliction_use_shadowfury")
menu.use_cod_to_coa_fallback             = core.menu.checkbox(true, "eaxwarlockaffliction_use_cod_to_coa_fallback")
menu.cod_fallback_ttd                    = core.menu.slider_int(30, 90, 60, "eaxwarlockaffliction_cod_fallback_ttd")
menu.use_amplify_curse                   = core.menu.checkbox(true, "eaxwarlockaffliction_use_amplify_curse")
menu.amplify_before_cod                  = core.menu.checkbox(true, "eaxwarlockaffliction_amplify_before_cod")
menu.amplify_before_coa                  = core.menu.checkbox(true, "eaxwarlockaffliction_amplify_before_coa")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxwarlockaffliction_use_interrupt")

mana_conservator.register_menu_items(menu, "eax_warlock_affliction")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_corruption", label = "Corruption" },
    { toggle = "use_unstable_affliction", label = "UA" },
    { toggle = "use_drain_soul", label = "Drain Soul" },
    { toggle = "use_shadow_bolt", label = "Shadow Bolt" },
}, {
    namespace = "eaxwarlockaffliction",
    log_prefix = "[Eax Warlock Aff] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarlockaffliction")
    end

    root_tree:render("Eax's Warlock Affliction", function()
        ps.render_controls(menu, "Eax's Warlock Aff")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("DoTs")
            menu.use_corruption:render("Corruption", "Maintain")
            menu.use_unstable_affliction:render("UA", "Maintain")
            menu.use_siphon_life:render("Siphon Life", "Maintain (ISB-gated)")
            menu.use_curse_of_agony:render("CoA", "Maintain")
            menu.use_curse_of_elements:render("CoE", "Debuff")
            menu.use_curse_of_weakness:render("CoW", "Debuff")
            menu.use_curse_of_tongues:render("CoT", "Cast slow")
            menu.use_curse_of_exhaustion:render("CoEx", "Slow")

            ps.header("ISB-Gated Siphon Life")
            menu.use_isb_gated_siphon:render("ISB-Gated SL", "Cast SL only when ISB active")
            menu.isb_sl_min_stacks:render("ISB Min Stacks", "Min ISB stacks to cast SL")

            ps.header("CoD Fallback")
            menu.use_cod_to_coa_fallback:render("CoD→CoA Fallback", "Use CoA if TTD < threshold")
            menu.cod_fallback_ttd:render("CoD Fallback TTD", "seconds")

            ps.header("Amplify Curse")
            menu.use_amplify_curse:render("Use Amplify Curse", "Enable pre-cast")
            menu.amplify_before_cod:render("Amplify before CoD", "Cast before Curse of Doom")
            menu.amplify_before_coa:render("Amplify before CoA", "Cast before Curse of Agony")

            ps.header("Interrupt")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")

            ps.header("Fillers")
            menu.use_shadow_bolt:render("Shadow Bolt", "Main filler")
            menu.use_drain_soul:render("Drain Soul", "Execute")
            menu.use_immolate:render("Immolate", "DoT")
            menu.use_searing_pain:render("Searing Pain", "Fast")
            menu.use_shadowburn:render("Shadowburn", "Instant")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_dark_pact:render("Dark Pact", "Mana")
            menu.use_shadow_fiend:render("Shadow Fiend", "Mana/DPS")
            menu.use_soul_harvest:render("Soul Harvest", "Shards")
            menu.use_death_coil:render("Death Coil", "Heal/fear")
            menu.use_howl_of_terror:render("Howl of Terror", "AoE fear")
            menu.use_shadowfury:render("Shadowfury", "AoE stun")
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
