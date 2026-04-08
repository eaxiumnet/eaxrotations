-- +------------------------------------------------------------------+
-- |  Eax's Warlock Demonology
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
local dashboard_tree = ps.tree_node()
local advanced_tree = ps.tree_node()

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxwarlockdemonology_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarlockdemonology_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarlockdemonology_mode")
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarlockdemonology_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarlockdemonology_combat_self_hp_boost")
menu.use_racial                          = core.menu.checkbox(true, "eaxwarlockdemonology_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarlockdemonology_racial_hp")
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_combat_potions                 = core.menu.checkbox(false, "eaxwarlockdemonology_auto_combat_potions")
menu.auto_ooc_food_drink                 = core.menu.checkbox(true, "eaxwarlockdemonology_auto_ooc_food_drink")
menu.auto_flask                          = core.menu.checkbox(false, "eaxwarlockdemonology_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarlockdemonology_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarlockdemonology_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxwarlockdemonology_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxwarlockdemonology_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxwarlockdemonology_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxwarlockdemonology_spirit_tap_wand")
-- Rotation
menu.use_shadow_bolt                     = core.menu.checkbox(true, "eaxwarlockdemonology_use_shadow_bolt")
menu.use_soul_fire                       = core.menu.checkbox(true, "eaxwarlockdemonology_use_soul_fire")
menu.use_corruption                      = core.menu.checkbox(true, "eaxwarlockdemonology_use_corruption")
menu.use_immolate                        = core.menu.checkbox(true, "eaxwarlockdemonology_use_immolate")
menu.use_curse_of_elements               = core.menu.checkbox(true, "eaxwarlockdemonology_use_curse_of_elements")
menu.use_curse_of_weakness               = core.menu.checkbox(true, "eaxwarlockdemonology_use_curse_of_weakness")
menu.use_curse_of_tongues                = core.menu.checkbox(true, "eaxwarlockdemonology_use_curse_of_tongues")
menu.use_curse_of_exhaustion             = core.menu.checkbox(true, "eaxwarlockdemonology_use_curse_of_exhaustion")
menu.use_fear                            = core.menu.checkbox(true, "eaxwarlockdemonology_use_fear")
menu.use_death_coil                      = core.menu.checkbox(true, "eaxwarlockdemonology_use_death_coil")
menu.use_howl_of_terror                  = core.menu.checkbox(true, "eaxwarlockdemonology_use_howl_of_terror")
menu.use_banish                          = core.menu.checkbox(true, "eaxwarlockdemonology_use_banish")
menu.use_enslave_demon                   = core.menu.checkbox(true, "eaxwarlockdemonology_use_enslave_demon")
menu.use_health_funnel                   = core.menu.checkbox(true, "eaxwarlockdemonology_use_health_funnel")
menu.use_life_tap                        = core.menu.checkbox(true, "eaxwarlockdemonology_use_life_tap")
menu.life_tap_mana_pct                   = core.menu.slider_int(10, 80, 40, "eaxwarlockdemonology_life_tap_mana_pct")
menu.use_drain_life                      = core.menu.checkbox(true, "eaxwarlockdemonology_use_drain_life")
menu.drain_life_hp_pct                   = core.menu.slider_int(0, 100, 40, "eaxwarlockdemonology_drain_life_hp_pct")
menu.use_soulstone                       = core.menu.checkbox(true, "eaxwarlockdemonology_use_soulstone")
menu.use_healthstone                     = core.menu.checkbox(true, "eaxwarlockdemonology_use_healthstone")
menu.healthstone_hp_pct                  = core.menu.slider_int(0, 100, 30, "eaxwarlockdemonology_healthstone_hp_pct")
menu.use_create_healthstone              = core.menu.checkbox(true, "eaxwarlockdemonology_use_create_healthstone")
menu.use_create_soulstone                = core.menu.checkbox(true, "eaxwarlockdemonology_use_create_soulstone")
menu.use_create_spellstone               = core.menu.checkbox(true, "eaxwarlockdemonology_use_create_spellstone")
menu.use_create_firestone                = core.menu.checkbox(true, "eaxwarlockdemonology_use_create_firestone")
menu.use_demon_armor                     = core.menu.checkbox(false, "eaxwarlockdemo_use_demon_armor")
menu.use_fel_armor                       = core.menu.checkbox(true, "eaxwarlockdemo_use_fel_armor")
menu.use_unending_breath                 = core.menu.checkbox(true, "eaxwarlockdemonology_use_unending_breath")
menu.use_detect_invisibility             = core.menu.checkbox(true, "eaxwarlockdemonology_use_detect_invisibility")
menu.use_eye_of_kilrogg                  = core.menu.checkbox(true, "eaxwarlockdemonology_use_eye_of_kilrogg")
menu.use_summon_pet                      = core.menu.checkbox(true, "eaxwarlockdemonology_use_summon_pet")
menu.use_soul_link                       = core.menu.checkbox(true, "eaxwarlockdemonology_use_soul_link")
menu.use_demonic_sacrifice               = core.menu.checkbox(true, "eaxwarlockdemonology_use_demonic_sacrifice")
menu.use_shadowburn                      = core.menu.checkbox(true, "eaxwarlockdemonology_use_shadowburn")
menu.use_searing_pain                    = core.menu.checkbox(true, "eaxwarlockdemonology_use_searing_pain")
menu.use_rain_of_fire                    = core.menu.checkbox(true, "eaxwarlockdemonology_use_rain_of_fire")
menu.use_hellfire                        = core.menu.checkbox(true, "eaxwarlockdemonology_use_hellfire")
menu.use_conflagrate                     = core.menu.checkbox(true, "eaxwarlockdemonology_use_conflagrate")
menu.use_incinerate                      = core.menu.checkbox(true, "eaxwarlockdemonology_use_incinerate")
menu.use_shadowfury                      = core.menu.checkbox(true, "eaxwarlockdemonology_use_shadowfury")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxwarlockdemonology_use_interrupt")
menu.maintain_soul_link                  = core.menu.checkbox(true, "eaxwarlockdemonology_maintain_soul_link")
menu.pet_check_interval                  = core.menu.slider_int(1, 30, 5, "eaxwarlockdemonology_pet_check_interval")
menu.use_curse_of_agony                = core.menu.checkbox(true, "eaxwarlockdemonology_use_curse_of_agony")
menu.pet_heal_hp_pct                   = core.menu.slider_int(10, 80, 40, "eaxwarlockdemonology_pet_heal_hp_pct")
menu.health_funnel_hp_pct              = core.menu.slider_int(10, 80, 50, "eaxwarlockdemonology_health_funnel_hp_pct")
menu.life_tap_hp_pct                   = core.menu.slider_int(10, 90, 60, "eaxwarlockdemonology_life_tap_hp_pct")
menu.preferred_pet                     = core.menu.combobox(6, "eaxwarlockdemonology_preferred_pet")

-- Mana Management (Warlock uses Life Tap)
menu.use_mana_manager = core.menu.checkbox(true, "eaxwarlockdemonology_use_mana_manager")
menu.life_tap_pct = core.menu.slider_int(5, 100, 50, "eaxwarlockdemonology_life_tap_pct")
menu.life_tap_min_hp = core.menu.slider_int(10, 100, 40, "eaxwarlockdemonology_life_tap_min_hp")
menu.mana_potion_pct = core.menu.slider_int(5, 100, 20, "eaxwarlockdemonology_mana_potion_pct")
menu.dark_rune_pct = core.menu.slider_int(5, 100, 15, "eaxwarlockdemonology_dark_rune_pct")

-- Burst & Trinket Automation
menu.auto_burst_enabled = core.menu.checkbox(false, "eaxwarlockdemonology_auto_burst")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eaxwarlockdemonology_burst_bloodlust")
menu.burst_on_pull = core.menu.checkbox(true, "eaxwarlockdemonology_burst_pull")
menu.burst_on_execute = core.menu.checkbox(true, "eaxwarlockdemonology_burst_execute")
menu.burst_in_combat = core.menu.checkbox(false, "eaxwarlockdemonology_burst_always")
menu.cd_min_ttd = core.menu.slider_int(0, 60, 0, "eaxwarlockdemonology_cd_min_ttd")
menu.trinket1_mode = core.menu.combobox(1, "eaxwarlockdemonology_trinket1_mode")
menu.trinket2_mode = core.menu.combobox(1, "eaxwarlockdemonology_trinket2_mode")

-- Dashboard menu items
menu.show_dashboard         = core.menu.checkbox(true, "eaxwarlockdemonology_show_dashboard")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxwarlockdemonology_dashboard_opacity")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxwarlockdemonology_dashboard_scale")
menu.dashboard_x            = core.menu.slider_int(0, 2000, 20, "eaxwarlockdemonology_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 2000, 200, "eaxwarlockdemonology_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxwarlockdemonology_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxwarlockdemonology_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxwarlockdemonology_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxwarlockdemonology_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxwarlockdemonology_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxwarlockdemonology_enable_smart_collapse")

mana_conservator.register_menu_items(menu, "eax_warlock_demonology")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_shadow_bolt", label = "Shadow Bolt" },
}, {
    namespace = "eaxwarlockdemonology",
    log_prefix = "[Eax Warlock Demo] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarlockdemonology")
    end

    root_tree:render("Eax's Warlock Demonology", function()
        -- General (inline, was ps.render_controls)
        ps.header("General")
        menu.enabled:render("Enabled", "Enable rotation")
        menu.toggle_key:render("Toggle Key", "Quick enable/disable")
        menu.mode:render("Mode", "1=Auto, 2=PVE, 3=PVP")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Fillers")
            menu.use_shadow_bolt:render("Shadow Bolt", "Main filler")
            menu.use_soul_fire:render("Soul Fire", "Proc")

            ps.header("DoTs")
            menu.use_corruption:render("Corruption", "Maintain")
            menu.use_immolate:render("Immolate", "Maintain")
            menu.use_curse_of_elements:render("CoE", "Debuff")
            menu.use_curse_of_weakness:render("CoW", "Debuff")
            menu.use_curse_of_tongues:render("CoT", "Cast slow")
            menu.use_curse_of_exhaustion:render("CoEx", "Slow")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
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
            menu.use_fel_armor:render("Fel Armor", "Shadow damage + healing")
            menu.use_demon_armor:render("Demon Armor", "Physical protection")
        end)

        -- AoE
        auto_tree:render("AoE", function()
            menu.use_rain_of_fire:render("Rain of Fire", "AoE")
            menu.use_hellfire:render("Hellfire", "AoE self-damage")
            menu.use_shadowburn:render("Shadowburn", "Instant")
            menu.use_searing_pain:render("Searing Pain", "Fast")
            menu.use_conflagrate:render("Conflagrate", "Instant")
            menu.use_incinerate:render("Incinerate", "Cast")
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

        -- Dashboard
        dashboard_tree:render("Dashboard", function()
            ps.header("Display")
            menu.show_dashboard:render("Show Dashboard", "Enable combat dashboard")
            menu.dashboard_opacity:render("Opacity", "Dashboard background opacity")
            menu.dashboard_scale:render("Scale", "Dashboard UI scale")
            menu.dashboard_x:render("Position X", "Dashboard horizontal position")
            menu.dashboard_y:render("Position Y", "Dashboard vertical position")            
            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent spell casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
        end)

        -- Advanced (Targeting + Racial + Leveling)
        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target")

            ps.header("Racial")
            menu.use_racial:render("Use Racial", "Use racial abilities")
            menu.racial_hp:render("Racial HP %", "HP threshold for racial")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling mode")
            menu.leveling_mana_floor:render("Mana Floor %", "Minimum mana %")
        end)
    end)
end


return menu

