-- +------------------------------------------------------------------+
-- |  Eax's Warrior Protection
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree    = ps.tree_node()
local rotation_tree = ps.tree_node()
local shouts_tree  = ps.tree_node()
local debuffs_tree = ps.tree_node()
local cd_tree      = ps.tree_node()
local auto_tree    = ps.tree_node()
local ooc_tree     = ps.tree_node()
local group_tree   = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local esp_tree     = ps.tree_node()
local dashboard_tree = ps.tree_node()
local pvp_tree     = ps.tree_node()

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxwarriorprotection_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarriorprotection_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarriorprotection_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarriorprotection_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarriorprotection_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarriorprotection_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarriorprotection_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarriorprotection_racial_hp")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxwarriorprotection_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarriorprotection_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarriorprotection_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarriorprotection_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarriorprotection_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarriorprotection_lev_mana_floor")

-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- Rotation - Abilities
menu.use_shield_slam                      = core.menu.checkbox(true, "eaxwarriorprotection_use_shield_slam")
menu.use_cooldowns                        = core.menu.checkbox(true, "eaxwarriorprotection_use_cooldowns")
menu.use_revenge                          = core.menu.checkbox(true, "eaxwarriorprotection_use_revenge")
menu.use_devastate                        = core.menu.checkbox(true, "eaxwarriorprotection_use_devastate")
menu.use_heroic_strike                    = core.menu.checkbox(true, "eaxwarriorprotection_use_heroic_strike")
menu.use_cleave                           = core.menu.checkbox(true, "eaxwarriorprotection_use_cleave")
menu.use_execute                          = core.menu.checkbox(false, "eaxwarriorprotection_use_execute")
menu.use_battle_shout                     = core.menu.checkbox(true, "eaxwarriorprotection_use_battle_shout")
menu.use_commanding_shout                 = core.menu.checkbox(false, "eaxwarriorprotection_use_commanding_shout")
menu.use_bloodrage                        = core.menu.checkbox(true, "eaxwarriorprotection_use_bloodrage")
menu.show_notifications                   = core.menu.checkbox(false, "eaxwarriorprotection_show_notifications")
menu.use_prepull_bloodrage                = core.menu.checkbox(true, "eaxwarriorprotection_use_prepull_bloodrage")
menu.use_demo_shout                       = core.menu.checkbox(true, "eaxwarriorprotection_use_demo_shout")
menu.use_thunder_clap                     = core.menu.checkbox(true, "eaxwarriorprotection_use_thunder_clap")
menu.use_sunder_armor                     = core.menu.checkbox(false, "eaxwarriorprotection_use_sunder_armor")
menu.sunder_max_stacks                    = core.menu.slider_int(1, 5, 5, "eaxwarriorprotection_sunder_max_stacks")
menu.use_rend                             = core.menu.checkbox(false, "eaxwarriorprotection_use_rend")
menu.use_hamstring                        = core.menu.checkbox(false, "eaxwarriorprotection_use_hamstring")
menu.use_intercept                        = core.menu.checkbox(true, "eaxwarriorprotection_use_intercept")
menu.intercept_min_range                  = core.menu.slider_int(8, 25, 10, "eaxwarriorprotection_intercept_min_range")
menu.auto_peel                            = core.menu.checkbox(true, "eaxwarriorprotection_auto_peel")
menu.use_taunt                            = core.menu.checkbox(true, "eaxwarriorprotection_use_taunt")
menu.use_shield_bash                      = core.menu.checkbox(true, "eaxwarriorprotection_use_shield_bash")
menu.use_concussion_blow                  = core.menu.checkbox(true, "eaxwarriorprotection_use_concussion_blow")
menu.use_concussion_blow_proactive        = core.menu.checkbox(false, "eaxwarriorprotection_use_concussion_blow_proactive")
menu.use_mocking_blow                     = core.menu.checkbox(true, "eaxwarriorprotection_use_mocking_blow")
menu.use_mocking_blow_dance               = core.menu.checkbox(true, "eaxwarriorprotection_use_mocking_blow_dance")
menu.use_challenging_shout                = core.menu.checkbox(true, "eaxwarriorprotection_use_challenging_shout")
menu.use_peel_intercept                   = core.menu.checkbox(false, "eaxwarriorprotection_use_peel_intercept")
menu.use_piercing_howl                    = core.menu.checkbox(false, "eaxwarriorprotection_use_piercing_howl")
menu.skip_sunder_with_expose              = core.menu.checkbox(true, "eaxwarriorprotection_skip_sunder_with_expose")
menu.taunt_trash                          = core.menu.checkbox(false, "eaxwarriorprotection_taunt_trash")
menu.cancel_pws                           = core.menu.checkbox(true, "eaxwarriorprotection_cancel_pws")
menu.cancel_bop                           = core.menu.checkbox(true, "eaxwarriorprotection_cancel_bop")
menu.use_intervene                        = core.menu.checkbox(false, "eaxwarriorprotection_use_intervene")
menu.use_disarm                           = core.menu.checkbox(true, "eaxwarriorprotection_use_disarm")
menu.use_charge                           = core.menu.checkbox(true, "eaxwarriorprotection_use_charge")
menu.use_rage_potion                      = core.menu.checkbox(false, "eaxwarriorprotection_use_rage_potion")
menu.rage_potion_rage_threshold           = core.menu.slider_int(0, 40, 20, "eaxwarriorprotection_rage_potion_rage_threshold")
menu.use_shield_block                     = core.menu.checkbox(true, "eaxwarriorprotection_use_shield_block")
menu.use_last_stand                       = core.menu.checkbox(true, "eaxwarriorprotection_use_last_stand")
menu.last_stand_hp_pct                    = core.menu.slider_int(10, 50, 20, "eaxwarriorprotection_last_stand_hp_pct")
menu.use_shield_wall                      = core.menu.checkbox(true, "eaxwarriorprotection_use_shield_wall")
menu.shield_wall_hp_pct                   = core.menu.slider_int(10, 50, 25, "eaxwarriorprotection_shield_wall_hp_pct")
menu.use_spell_reflection                 = core.menu.checkbox(true, "eaxwarriorprotection_use_spell_reflection")
menu.spell_reflection_progress_pct        = core.menu.slider_int(0, 90, 50, "eaxwarriorprotection_spell_reflection_progress_pct")
menu.use_healthstone                      = core.menu.checkbox(false, "eaxwarriorprotection_use_healthstone")
menu.healthstone_hp_pct                   = core.menu.slider_int(10, 50, 25, "eaxwarriorprotection_healthstone_hp_pct")
menu.use_health_potion                    = core.menu.checkbox(true, "eaxwarriorprotection_use_health_potion")
menu.health_potion_hp_pct                 = core.menu.slider_int(10, 50, 20, "eaxwarriorprotection_health_potion_hp_pct")
menu.use_stoneform                        = core.menu.checkbox(true, "eaxwarriorprotection_use_stoneform")
menu.stoneform_hp_pct                     = core.menu.slider_int(20, 80, 40, "eaxwarriorprotection_stoneform_hp_pct")
menu.use_trinkets                         = core.menu.checkbox(true, "eaxwarriorprotection_use_trinkets")
menu.use_haste_potion                     = core.menu.checkbox(false, "eaxwarriorprotection_use_haste_potion")
menu.use_destruction_potion               = core.menu.checkbox(false, "eaxwarriorprotection_use_destruction_potion")
menu.use_drums                            = core.menu.checkbox(false, "eaxwarriorprotection_use_drums")
menu.use_berserker_rage                   = core.menu.checkbox(true, "eaxwarriorprotection_use_berserker_rage")
menu.use_blood_fury                       = core.menu.checkbox(true, "eaxwarriorprotection_use_blood_fury")
menu.use_berserking                       = core.menu.checkbox(true, "eaxwarriorprotection_use_berserking")
menu.use_war_stomp_interrupt              = core.menu.checkbox(true, "eaxwarriorprotection_use_war_stomp_interrupt")
menu.use_intimidating_shout               = core.menu.checkbox(true, "eaxwarriorprotection_use_intimidating_shout")
menu.intimidating_shout_key               = core.menu.keybind(7, false, "eaxwarriorprotection_intimidating_shout_key")
menu.heroic_strike_rage                   = core.menu.slider_int(20, 100, 60, "eaxwarriorprotection_hs_rage")
menu.cleave_rage                          = core.menu.slider_int(20, 100, 55, "eaxwarriorprotection_cleave_rage")
menu.heroic_strike_rage_cap               = core.menu.slider_int(30, 100, 70, "eaxwarriorprotection_hs_rage_cap")
menu.aoe_enemy_count                      = core.menu.slider_int(2, 10, 3, "eaxwarriorprotection_aoe_count")
menu.shield_block_hp_pct                  = core.menu.slider_int(30, 80, 50, "eaxwarriorprotection_shield_block_hp_pct")
menu.challenging_boss_threshold           = core.menu.slider_int(1, 5, 1, "eaxwarriorprotection_challenging_boss_threshold")
menu.challenging_elite_threshold          = core.menu.slider_int(2, 8, 3, "eaxwarriorprotection_challenging_elite_threshold")
menu.challenging_trash_threshold           = core.menu.slider_int(3, 12, 5, "eaxwarriorprotection_challenging_trash_threshold")
menu.use_threat_equalization              = core.menu.checkbox(true, "eaxwarriorprotection_use_threat_equalization")
menu.threat_eq_threshold                  = core.menu.slider_int(5, 25, 10, "eaxwarriorprotection_threat_eq_threshold")

-- Dashboard
menu.show_dashboard                       = core.menu.checkbox(true, "eaxwarriorprotection_show_dashboard")
menu.dashboard_opacity                    = core.menu.slider_int(50, 255, 190, "eaxwarriorprotection_dashboard_opacity")
menu.dashboard_scale                      = core.menu.slider_float(0.5, 2.0, 1.0, "eaxwarriorprotection_dashboard_scale")
menu.dashboard_x                        = core.menu.slider_int(0, 2000, 20, "eaxwarriorprotection_dashboard_x")
menu.dashboard_y                        = core.menu.slider_int(0, 2000, 200, "eaxwarriorprotection_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxwarriorprotection_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxwarriorprotection_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxwarriorprotection_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxwarriorprotection_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(true, "eaxwarriorprotection_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxwarriorprotection_enable_smart_collapse")

-- PvP Settings
menu.pvp_enabled                          = core.menu.checkbox(true, "eaxwarriorprotection_pvp_enabled")
menu.pvp_mode                             = core.menu.combobox(1, "eaxwarriorprotection_pvp_mode")
menu.pvp_spell_reflection                 = core.menu.checkbox(true, "eaxwarriorprotection_pvp_spell_reflection")
menu.pvp_disarm                           = core.menu.checkbox(true, "eaxwarriorprotection_pvp_disarm")
menu.pvp_concussion_blow                  = core.menu.checkbox(true, "eaxwarriorprotection_pvp_concussion_blow")
menu.pvp_intercept                        = core.menu.checkbox(true, "eaxwarriorprotection_pvp_intercept")
menu.pvp_intimidating_shout               = core.menu.checkbox(true, "eaxwarriorprotection_pvp_intimidating_shout")
menu.pvp_intimidating_shout_hp            = core.menu.slider_int(10, 50, 30, "eaxwarriorprotection_pvp_intimidating_shout_hp")
menu.pvp_trinket_defensive                = core.menu.checkbox(true, "eaxwarriorprotection_pvp_trinket_defensive")
menu.pvp_focus_healers                    = core.menu.checkbox(true, "eaxwarriorprotection_pvp_focus_healers")
menu.pvp_target_swapping                  = core.menu.checkbox(true, "eaxwarriorprotection_pvp_target_swapping")

-- Missing menu items (causing nil errors)
menu.cancelaura_hp_threshold              = core.menu.slider_int(10, 90, 50, "eaxwarriorprotection_cancelaura_hp_threshold")
menu.shield_block_threat_lead             = core.menu.slider_int(0, 100, 0, "eaxwarriorprotection_shield_block_threat_lead")
menu.pvp_cc_break_check                   = core.menu.checkbox(true, "eaxwarriorprotection_pvp_cc_break_check")
menu.tc_min_mobs                          = core.menu.slider_int(1, 10, 2, "eaxwarriorprotection_tc_min_mobs")
menu.tc_threat_lead                         = core.menu.slider_int(0, 100, 0, "eaxwarriorprotection_tc_threat_lead")
menu.demo_min_mobs                          = core.menu.slider_int(1, 10, 2, "eaxwarriorprotection_demo_min_mobs")
menu.demo_threat_lead                       = core.menu.slider_int(0, 100, 0, "eaxwarriorprotection_demo_threat_lead")
menu.hs_rage_threshold                      = core.menu.slider_int(20, 100, 60, "eaxwarriorprotection_hs_rage_threshold")
menu.use_swing_manager                    = core.menu.checkbox(true, "eaxwarriorprot_use_swing_manager")
menu.swing_queue_threshold                = core.menu.slider_int(30, 100, 50, "eaxwarriorprot_swing_queue_threshold")
menu.no_taunt                             = core.menu.checkbox(false, "eaxwarriorprotection_no_taunt")
menu.cshout_min_bosses                      = core.menu.slider_int(1, 5, 1, "eaxwarriorprotection_cshout_min_bosses")
menu.cshout_min_elites                      = core.menu.slider_int(2, 8, 3, "eaxwarriorprotection_cshout_min_elites")
menu.cshout_min_trash                       = core.menu.slider_int(3, 12, 5, "eaxwarriorprotection_cshout_min_trash")
menu.last_stand_hp                          = core.menu.slider_int(10, 50, 20, "eaxwarriorprotection_last_stand_hp")
menu.shield_wall_hp                         = core.menu.slider_int(10, 50, 25, "eaxwarriorprotection_shield_wall_hp")
menu.auto_defensive_after_charge          = core.menu.checkbox(true, "eaxwarriorprotection_auto_defensive_after_charge")
menu.execute_min_rage                     = core.menu.slider_int(5, 30, 15, "eaxwarriorprotection_execute_min_rage")
menu.use_ironshield_potion                = core.menu.checkbox(false, "eaxwarriorprotection_use_ironshield_potion")
menu.focus_priority = core.menu.checkbox(false, "eaxwarriorprotection_focus_priority")
menu.use_racial = core.menu.checkbox(true, "eaxwarriorprotection_use_racial")

-- Defensive trinket mode (3 = defensive)
menu.trinket1_mode = core.menu.combobox(3, "eaxwarriorprotection_trinket1_mode")
menu.trinket2_mode = core.menu.combobox(3, "eaxwarriorprotection_trinket2_mode")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_shield_slam", label = "Shield Slam" },
    { toggle = "use_revenge", label = "Revenge" },
    { toggle = "use_devastate", label = "Devastate" },
    { toggle = "use_taunt", label = "Taunt" },
    { toggle = "use_shield_block", label = "Shield Block" },
}, {
    namespace = "eaxwarriorprotection",
    log_prefix = "[Eax Warrior Prot] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarriorprotection")
    end

    root_tree:render("Eax's Warrior Protection", function()
        ps.render_controls(menu, "Eax's Warrior Prot")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_shield_slam:render("Shield Slam", "On CD")
            menu.use_revenge:render("Revenge", "Proc")
            menu.use_devastate:render("Devastate", "Filler")
            menu.use_heroic_strike:render("Heroic Strike", "High rage")
            menu.hs_rage_threshold:render("HS Rage Threshold", "Min rage")
            menu.use_cleave:render("Cleave", "AoE")
            menu.use_execute:render("Execute", "Below 20%")
            menu.execute_min_rage:render("Execute Min Rage", "Min rage to use")
            menu.use_bloodrage:render("Bloodrage", "Low rage")
            menu.use_prepull_bloodrage:render("Pre-pull Bloodrage", "Before combat")
            menu.show_notifications:render("Notifications", "On-screen")
            menu.use_charge:render("Charge", "Opener")
            menu.use_intercept:render("Intercept", "Gap closer")
            menu.intercept_min_range:render("Intercept Min Range", "yd")
            menu.auto_defensive_after_charge:render("Auto Defensive", "Return to Def after Charge")
            menu.auto_peel:render("Auto Peel", "Protect allies")
            menu.use_intervene:render("Intervene", "Protect")
            menu.use_rage_potion:render("Rage Potion", "Low rage")
            menu.rage_potion_rage_threshold:render("Rage Potion %", "Below")
        end)

        -- Shouts
        shouts_tree:render("Shouts", function()
            menu.use_battle_shout:render("Battle Shout", "AP buff")
            menu.use_commanding_shout:render("Commanding Shout", "HP buff")
            menu.use_demo_shout:render("Demo Shout", "Reduce AP")
            menu.demo_min_mobs:render("Demo Min Mobs", "Minimum enemies")
            menu.demo_threat_lead:render("Demo Threat Lead", "% required")
        end)

        -- Debuffs
        debuffs_tree:render("Debuffs", function()
            menu.use_thunder_clap:render("Thunder Clap", "Slow")
            menu.tc_min_mobs:render("TC Min Mobs", "Minimum enemies")
            menu.tc_threat_lead:render("TC Threat Lead", "% required")
            menu.use_sunder_armor:render("Sunder Armor", "Stack")
            menu.sunder_max_stacks:render("Sunder Max", "Stacks")
            menu.use_rend:render("Rend", "DoT")
            menu.use_hamstring:render("Hamstring", "Slow")
            menu.use_piercing_howl:render("Piercing Howl", "AoE slow")
            menu.skip_sunder_with_expose:render("Skip w/ Expose", "If Expose up")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_cooldowns:render("Use Cooldowns", "Enable burst")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.no_taunt:render("No Taunt Mode", "Disable all taunts")
            menu.use_taunt:render("Taunt", "Single target")
            menu.use_challenging_shout:render("Challenging Shout", "AoE taunt")
            menu.cshout_min_bosses:render("Challenging Min Bosses", "Count")
            menu.cshout_min_elites:render("Challenging Min Elites", "Count")
            menu.cshout_min_trash:render("Challenging Min Trash", "Count")
            menu.use_mocking_blow:render("Mocking Blow", "Taunt backup")
            menu.use_berserker_rage:render("Berserker Rage", "On CD")
            menu.use_blood_fury:render("Blood Fury", "Racial")
            menu.use_berserking:render("Berserking", "Racial")
            menu.use_trinkets:render("Trinkets", "On-use")
            menu.use_haste_potion:render("Haste Potion", "Consumable")
            menu.use_destruction_potion:render("Destruction Potion", "Consumable")
            menu.use_drums:render("Drums", "Battle/War")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_shield_block:render("Shield Block", "On CD")
            menu.shield_block_hp_pct:render("Shield Block HP %", "Below")
            menu.shield_block_threat_lead:render("Shield Block Threat", "% required")
            menu.use_last_stand:render("Last Stand", "Emergency")
            menu.last_stand_hp:render("Last Stand HP %", "Below")
            menu.use_shield_wall:render("Shield Wall", "Emergency")
            menu.shield_wall_hp:render("Shield Wall HP %", "Below")
            menu.use_spell_reflection:render("Spell Reflection", "Reflect spells")
            menu.spell_reflection_progress_pct:render("Spell Reflect %", "Cast progress")
            menu.use_healthstone:render("Healthstone", "Low HP")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.use_health_potion:render("Health Potion", "Low HP")
            menu.health_potion_hp_pct:render("Health Potion HP %", "Below")
            menu.use_ironshield_potion:render("Ironshield Potion", "+2500 armor")
            menu.use_stoneform:render("Stoneform", "Low HP")
            menu.stoneform_hp_pct:render("Stoneform HP %", "Below")
            menu.use_war_stomp_interrupt:render("War Stomp", "Interrupt fallback")
            menu.use_intimidating_shout:render("Intimidating Shout", "Enable panic key")
            menu.intimidating_shout_key:render("Intimidating Shout Key", "Panic key")
            menu.cancel_pws:render("Cancel PW:S", "Remove shield")
            menu.cancel_bop:render("Cancel BoP", "Remove protection")
            menu.cancelaura_hp_threshold:render("Cancelaura HP Threshold", "% to cancel")
        end)

        -- Dashboard
        dashboard_tree:render("Dashboard", function()
            menu.show_dashboard:render("Show Dashboard", "Enable in-game HUD")
            menu.dashboard_opacity:render("Opacity", "Background transparency")
            menu.dashboard_scale:render("Scale", "UI size multiplier")
            menu.dashboard_x:render("Position X", "Dashboard horizontal position")
            menu.dashboard_y:render("Position Y", "Dashboard vertical position")            
            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent spell casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")            menu.show_threat_bar:render("Threat Bar", "Show threat percentage")
        end)

        -- PvP
        pvp_tree:render("PvP", function()
            ps.header("General")
            menu.pvp_enabled:render("Enable PvP Mode", "PvP-specific logic")
            menu.pvp_mode:render("PvP Mode", "Auto/PvE/PvP")
            menu.pvp_cc_break_check:render("CC Break Check", "Skip AoE near CC")

            ps.header("Defensive")
            menu.pvp_spell_reflection:render("Spell Reflection", "Auto-reflect at cast %")
            menu.pvp_trinket_defensive:render("PvP Trinket", "Use for CC removal")

            ps.header("Control")
            menu.pvp_disarm:render("Auto Disarm", "Disarm enemy melee")
            menu.pvp_concussion_blow:render("Concussion Blow", "Use as CC on low HP")
            menu.pvp_intimidating_shout:render("Intimidating Shout", "Emergency peel")
            menu.pvp_intimidating_shout_hp:render("Shout HP Threshold", "Below %")

            ps.header("Mobility")
            menu.pvp_intercept:render("Intercept", "Gap close in PvP")

            ps.header("Targeting")
            menu.pvp_focus_healers:render("Focus Healers", "Prioritize in arena/BG")
            menu.pvp_target_swapping:render("Smart Target Swap", "Swap to low HP targets")
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
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end

return menu


