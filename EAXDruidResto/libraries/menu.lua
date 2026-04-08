-- +------------------------------------------------------------------+
-- |  Eax's Druid Restoration
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}
local INNERVATE_TARGET_OPTIONS = { "Self only", "Lowest mana healer", "Focus target" }

-- Tree nodes
local root_tree    = ps.tree_node()
local rotation_tree = ps.tree_node()
local healing_tree = ps.tree_node()
local dps_tree     = ps.tree_node()
local cd_tree      = ps.tree_node()
local auto_tree    = ps.tree_node()
local ooc_tree     = ps.tree_node()
local group_tree   = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local esp_tree     = ps.tree_node()
local middleware_tree = ps.tree_node()  
local dashboard_tree  = ps.tree_node()  
local pvp_tree        = ps.tree_node()  

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxdruidrestoration_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxdruidrestoration_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxdruidrestoration_mode")
menu.debug                               = core.menu.checkbox(false, "eaxdruidrestoration_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxdruidrestoration_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxdruidrestoration_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxdruidrestoration_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxdruidrestoration_racial_hp")

-- Interrupt
menu.use_interrupt                       = core.menu.checkbox(true, "eaxdruidrestoration_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.ooc_heal_hp_pct                     = core.menu.slider_int(50, 100, 80, "eaxdruidresto_ooc_heal_hp_pct")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxdruidrestoration_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxdruidrestoration_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxdruidrestoration_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxdruidrestoration_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxdruidrestoration_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxdruidrestoration_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxdruidrestoration_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxdruidrestoration_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxdruidrestoration_spirit_tap_wand")

-- Healing
menu.use_rejuvenation                    = core.menu.checkbox(true, "eaxdruidrestoration_use_rejuvenation")
menu.use_regrowth                        = core.menu.checkbox(true, "eaxdruidrestoration_use_regrowth")
menu.use_healing_touch                   = core.menu.checkbox(true, "eaxdruidrestoration_use_healing_touch")
menu.healing_touch_rank                  = core.menu.slider_int(1, 12, 12, "eaxdruidrestoration_healing_touch_rank")
menu.healing_touch_tank_threshold        = core.menu.slider_int(10, 100, 40, "eaxdruidrestoration_healing_touch_tank_threshold")
menu.use_swiftmend                       = core.menu.checkbox(true, "eaxdruidrestoration_use_swiftmend")
menu.swiftmend_hp_pct                    = core.menu.slider_int(10, 100, 50, "eaxdruidresto_swiftmend_hp_pct")
menu.use_lifebloom                       = core.menu.checkbox(true, "eaxdruidrestoration_use_lifebloom")
menu.lifebloom_stacks                    = core.menu.slider_int(1, 3, 3, "eaxdruidresto_lifebloom_stacks")
menu.use_natures_swiftness               = core.menu.checkbox(true, "eaxdruidrestoration_use_natures_swiftness")
menu.emergency_hp                        = core.menu.slider_int(10, 100, 30, "eaxdruidrestoration_emergency_hp")
menu.use_tranquility                     = core.menu.checkbox(true, "eaxdruidrestoration_use_tranquility")
menu.use_tree_of_life                    = core.menu.checkbox(true, "eaxdruidrestoration_use_tree_of_life")
menu.use_innervate                       = core.menu.checkbox(true, "eaxdruidrestoration_use_innervate")
menu.innervate_mana_pct                  = core.menu.slider_int(10, 60, 30, "eaxdruidrestoration_innervate_mana_pct")
menu.innervate_target                    = core.menu.combobox(1, "eaxdruidresto_innervate_target")
menu.buff_friendlies                     = core.menu.checkbox(true, "eaxdruidresto_buff_friendlies")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxdruidrestoration_remove_curse")
menu.use_abolish_poison                  = core.menu.checkbox(true, "eaxdruidrestoration_abolish_poison")
menu.prioritize_tank                     = core.menu.checkbox(true, "eaxdruidrestoration_prioritize_tank")
menu.use_cyclone                         = core.menu.checkbox(true, "eaxdruidrestoration_use_cyclone")
menu.use_entangling_roots                = core.menu.checkbox(true, "eaxdruidrestoration_use_entangling_roots")
menu.use_natures_grasp                   = core.menu.checkbox(true, "eaxdruidrestoration_use_natures_grasp")
menu.use_travel_form                    = core.menu.checkbox(true, "eaxdruidrestoration_use_travel_form")
menu.use_mount_form                     = core.menu.checkbox(true, "eaxdruidrestoration_use_mount_form")

-- DPS Fallback
menu.dps_fallback_enabled                = core.menu.checkbox(true, "eaxdruidrestoration_dps_fallback")
menu.dps_use_faerie_fire                 = core.menu.checkbox(true, "eaxdruidrestoration_dps_use_faerie_fire")
menu.dps_use_moonfire                    = core.menu.checkbox(true, "eaxdruidrestoration_dps_use_moonfire")
menu.dps_use_insect_swarm                = core.menu.checkbox(true, "eaxdruidrestoration_dps_use_insect_swarm")
menu.dps_use_wrath                       = core.menu.checkbox(true, "eaxdruidrestoration_dps_use_wrath")
menu.dps_use_starfire                    = core.menu.checkbox(true, "eaxdruidrestoration_dps_use_starfire")
menu.dps_starfire_over_wrath             = core.menu.checkbox(false, "eaxdruidrestoration_dps_starfire_over_wrath")
menu.use_hurricane                       = core.menu.checkbox(true, "eaxdruidrestoration_use_hurricane")
menu.hurricane_min_targets                = core.menu.slider_int(2, 8, 4, "eaxdruidrestoration_hurricane_min_targets")
menu.hurricane_mana_floor                 = core.menu.slider_int(10, 80, 40, "eaxdruidrestoration_hurricane_mana_floor")

-- Defensive
menu.use_barkskin                        = core.menu.checkbox(true, "eaxdruidrestoration_use_barkskin")
menu.barkskin_hp_pct                     = core.menu.slider_int(0, 100, 40, "eaxdruidrestoration_barkskin_hp_pct")
menu.use_thorns                          = core.menu.checkbox(true, "eaxdruidrestoration_use_thorns")
menu.use_motw                            = core.menu.checkbox(true, "eaxdruidrestoration_use_motw")
menu.use_rebirth                         = core.menu.checkbox(true, "eaxdruidrestoration_use_rebirth")

-- ============================================================================

-- ============================================================================

-- Healthstone (higher threshold for healer survival)
menu.use_healthstone                     = core.menu.checkbox(true, "eaxdruidresto_use_healthstone")
menu.healthstone_hp_pct                  = core.menu.slider_int(10, 60, 35, "eaxdruidresto_healthstone_hp_pct")

-- Healing Potion (higher threshold for healer)
menu.use_healing_potion                  = core.menu.checkbox(true, "eaxdruidresto_use_healing_potion")
menu.health_potion_hp_pct                = core.menu.slider_int(10, 70, 45, "eaxdruidresto_health_potion_hp_pct")

-- Unified Consumable Health Threshold (for form_consumables integration)
menu.consumable_health_threshold           = core.menu.slider_int(10, 50, 35, "eaxdruidresto_consumable_health_threshold")

-- Mana Potion (low threshold - conserve for heals)
menu.use_mana_potion                     = core.menu.checkbox(true, "eaxdruidresto_use_mana_potion")
menu.mana_potion_pct                     = core.menu.slider_int(5, 30, 10, "eaxdruidresto_mana_potion_pct")

-- Consumables
menu.use_healthstone                     = core.menu.checkbox(true, "eaxdruidresto_use_healthstone")
menu.healthstone_hp_pct                  = core.menu.slider_int(10, 50, 30, "eaxdruidresto_healthstone_hp_pct")
menu.use_healing_potion                  = core.menu.checkbox(true, "eaxdruidresto_use_healing_potion")
menu.healing_potion_hp_pct               = core.menu.slider_int(10, 50, 25, "eaxdruidresto_healing_potion_hp_pct")

-- Mana Manager (unified mana recovery chain)
menu.use_mana_manager                    = core.menu.checkbox(true, "eaxdruidresto_use_mana_manager")
menu.mana_potion_pct                     = core.menu.slider_int(5, 100, 20, "eaxdruidresto_mana_potion_pct")
menu.dark_rune_pct                       = core.menu.slider_int(5, 100, 15, "eaxdruidresto_dark_rune_pct")
menu.innervate_pct                       = core.menu.slider_int(5, 100, 30, "eaxdruidresto_innervate_pct")

-- War Stomp (Tauren racial)
menu.use_war_stomp                       = core.menu.checkbox(true, "eaxdruidresto_use_war_stomp")

-- ============================================================================

-- ============================================================================

menu.show_dashboard                      = core.menu.checkbox(true, "eaxdruidresto_show_dashboard")
menu.dashboard_opacity                     = core.menu.slider_int(50, 255, 190, "eaxdruidresto_dashboard_opacity")
menu.dashboard_scale                     = core.menu.slider_float(0.5, 2.0, 1.0, "eaxdruidresto_dashboard_scale")
menu.dashboard_show_cooldowns            = core.menu.checkbox(true, "eaxdruidresto_dashboard_show_cooldowns")
menu.dashboard_show_buffs                  = core.menu.checkbox(true, "eaxdruidresto_dashboard_show_buffs")
menu.dashboard_show_custom                 = core.menu.checkbox(true, "eaxdruidresto_dashboard_show_custom")
menu.dashboard_x                         = core.menu.slider_int(0, 2000, 20, "eaxdruidresto_dashboard_x")
menu.dashboard_y                         = core.menu.slider_int(0, 2000, 200, "eaxdruidresto_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxdruidrestoration_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxdruidrestoration_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxdruidrestoration_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxdruidrestoration_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxdruidrestoration_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxdruidrestoration_enable_smart_collapse")

-- ============================================================================

-- ============================================================================

menu.pvp_enabled                         = core.menu.checkbox(true, "eaxdruidresto_pvp_enabled")
menu.pvp_mode                            = core.menu.combobox(1, "eaxdruidresto_pvp_mode")
menu.pvp_use_trinket                     = core.menu.checkbox(true, "eaxdruidresto_pvp_trinket")
menu.pvp_defensive_threshold             = core.menu.slider_int(10, 80, 40, "eaxdruidresto_pvp_def_hp")
menu.pvp_entangling_roots                = core.menu.checkbox(true, "eaxdruidresto_pvp_entangling_roots")
menu.pvp_hibernate                       = core.menu.checkbox(true, "eaxdruidresto_pvp_hibernate")
menu.pvp_cyclone                         = core.menu.checkbox(true, "eaxdruidresto_pvp_cyclone")

-- ============================================================================

-- ============================================================================

-- Lifebloom Bloom Optimization
menu.lifebloom_allow_bloom               = core.menu.checkbox(false, "eaxdruidrestoration_lifebloom_allow_bloom")
menu.lifebloom_bloom_threshold           = core.menu.slider_float(0.5, 3.0, 1.5, "eaxdruidrestoration_lifebloom_bloom_threshold")

-- Overheal Protection (cancel casts if target will be healed by others)
menu.overheal_protection                 = core.menu.checkbox(true, "eaxdruidrestoration_overheal_protection")
menu.overheal_threshold                  = core.menu.slider_int(70, 95, 85, "eaxdruidrestoration_overheal_threshold")

-- Nature's Swiftness Options
menu.resto_ns_healing_touch              = core.menu.checkbox(true, "eaxdruidrestoration_resto_ns_healing_touch")
menu.resto_ns_regrowth                   = core.menu.checkbox(true, "eaxdruidrestoration_resto_ns_regrowth")

-- Proactive Rejuvenation Spread (blanketing)
menu.resto_proactive_hp                  = core.menu.slider_int(70, 95, 80, "eaxdruidrestoration_resto_proactive_hp")
menu.resto_max_rejuv_targets             = core.menu.slider_int(3, 10, 5, "eaxdruidrestoration_resto_max_rejuv_targets")

-- Emergency Triage Thresholds (exposed from healer_triage.lua)
menu.tank_emergency_hp                   = core.menu.slider_int(30, 80, 55, "eaxdruidrestoration_tank_emergency_hp")
menu.triage_hp_threshold                 = core.menu.slider_int(20, 60, 35, "eaxdruidrestoration_triage_hp_threshold")
menu.group_collapse_count                = core.menu.slider_int(2, 5, 3, "eaxdruidrestoration_group_collapse_count")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_rejuvenation", label = "Rejuvenation" },
    { toggle = "use_regrowth", label = "Regrowth" },
    { toggle = "use_healing_touch", label = "Healing Touch" },
    { toggle = "use_swiftmend", label = "Swiftmend" },
    { toggle = "use_lifebloom", label = "Lifebloom" },
    { toggle = "use_innervate", label = "Innervate" },
}, {
    namespace = "eaxdruidrestoration",
    log_prefix = "[Eax Druid Resto] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxdruidrestoration")
    end

    root_tree:render("Eax's Druid Restoration", function()
        ps.render_controls(menu, "Eax's Druid Resto")

        -- Healing
        healing_tree:render("Healing", function()
            ps.header("HoTs")
            menu.use_rejuvenation:render("Rejuvenation", "Maintain on targets")
            menu.use_regrowth:render("Regrowth", "Direct heal + HoT")
            menu.use_lifebloom:render("Lifebloom", "Stack to 3 on tank")
            menu.lifebloom_stacks:render("Lifebloom Stacks", "Target stack count")
            menu.use_swiftmend:render("Swiftmend", "Emergency heal")
            menu.swiftmend_hp_pct:render("Swiftmend HP %", "Use below")
            menu.use_healing_touch:render("Healing Touch", "Big slow heal")
            menu.healing_touch_rank:render("Healing Touch Rank", "Max rank to use (1-12)")
            menu.healing_touch_tank_threshold:render("Healing Touch Tank Threshold", "HP% to use on tanks")
            menu.use_natures_swiftness:render("Nature's Swiftness", "Instant cast")
            menu.emergency_hp:render("Emergency HP %", "Nature's Swiftness below")
            menu.use_tranquility:render("Tranquility", "AoE heal")
            menu.use_tree_of_life:render("Tree of Life", "Form")
            menu.use_innervate:render("Innervate", "Mana recovery")
            menu.innervate_mana_pct:render("Innervate Mana %", "Below")
            menu.innervate_target:render("Innervate Target", "Target mode")
            menu.prioritize_tank:render("Prioritize Tank", "Heal tank first")
        end)

        -- DPS Fallback
        dps_tree:render("DPS Fallback", function()
            menu.dps_fallback_enabled:render("DPS Fallback", "Enable solo DPS")
            menu.dps_use_faerie_fire:render("Faerie Fire", "Armor debuff")
            menu.dps_use_moonfire:render("Moonfire", "DoT")
            menu.dps_use_insect_swarm:render("Insect Swarm", "DoT")
            menu.dps_use_wrath:render("Wrath", "Filler")
            menu.dps_use_starfire:render("Starfire", "Cast")
            menu.dps_starfire_over_wrath:render("Prefer Starfire", "Starfire over Wrath")
            menu.use_hurricane:render("Hurricane", "AoE")
            menu.hurricane_min_targets:render("Min Targets", "Use above")
            menu.hurricane_mana_floor:render("Mana Floor %", "Don't use below")
        end)

        -- Utility
        rotation_tree:render("Utility", function()
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_remove_curse:render("Remove Curse", "Dispel")
            menu.use_abolish_poison:render("Abolish Poison", "Dispel")
            menu.use_cyclone:render("Cyclone", "CC")
            menu.use_entangling_roots:render("Entangling Roots", "Root")
            menu.use_natures_grasp:render("Nature's Grasp", "Root on hit")
            menu.use_travel_form:render("Travel Form", "OOC")
            menu.use_mount_form:render("Mount Form", "OOC")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_barkskin:render("Barkskin", "Damage reduction")
            menu.barkskin_hp_pct:render("Barkskin HP %", "Below")
            menu.use_thorns:render("Thorns", "Auto-apply Thorns when missing (OOC)")
            menu.use_motw:render("Mark of the Wild", "Auto-apply MOTW when missing (OOC)")
        end)

        
        middleware_tree:render("Middleware", function()
            ps.header("Consumables")
            menu.use_healthstone:render("Healthstone", "Use healthstone")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.use_healing_potion:render("Healing Potion", "Use potion")
            menu.healing_potion_hp_pct:render("Healing Potion HP %", "Below")
            ps.header("Recovery Items (Healer Thresholds)")
            menu.use_healthstone:render("Healthstone", "Use healthstone")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below (healer: 35%)")
            menu.use_healing_potion:render("Healing Potion", "Use potion")
            menu.health_potion_hp_pct:render("Healing Potion HP %", "Below (healer: 45%)")
            menu.use_mana_potion:render("Mana Potion", "Use mana potion")
            menu.mana_potion_pct:render("Mana Potion %", "Below (conserve for heals)")
            
            ps.header("Form Consumables")
            menu.consumable_health_threshold:render("Consumable HP Threshold", "Use healthstone/potion below this % (all forms)")
            
            ps.header("Racials")
            menu.use_war_stomp:render("War Stomp", "Tauren stun defensive")
        end)

        
        dashboard_tree:render("Dashboard", function()
            menu.show_dashboard:render("Show Dashboard", "Toggle dashboard visibility")
            menu.dashboard_opacity:render("Opacity", "Dashboard background opacity")
            menu.dashboard_scale:render("Scale", "Dashboard UI scale")
            menu.dashboard_show_cooldowns:render("Show Cooldowns", "Track Innervate, Barkskin, etc.")
            menu.dashboard_show_buffs:render("Show Buffs", "Track HoTs and buffs")
            menu.dashboard_show_custom:render("Show Custom Lines", "Mana %, HoT count, Rebirth CD")
            menu.dashboard_x:render("Position X", "Dashboard horizontal position")
            menu.dashboard_y:render("Position Y", "Dashboard vertical position")            
            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent spell casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
        end)

        
        pvp_tree:render("PvP", function()
            menu.pvp_enabled:render("Enable PvP", "Enable PvP rotation features")
            menu.pvp_mode:render("PvP Mode", {"Auto", "PvE Only", "PvP Only"}, "Select PvP detection mode")
            menu.pvp_use_trinket:render("Use PvP Trinket", "Auto-use PvP trinket when CC'd")
            menu.pvp_defensive_threshold:render("Defensive Threshold %", "Use defensives below this HP% in PvP")
            menu.pvp_entangling_roots:render("Entangling Roots", "Root enemy players")
            menu.pvp_hibernate:render("Hibernate", "CC beasts/dragonkin")
            menu.pvp_cyclone:render("Cyclone", "CC enemy players")
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
            menu.ooc_heal_hp_pct:render("OOC Heal HP %", "Heal allies below")
        end)

        -- Group
        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
            menu.buff_friendlies:render("Buff Friendlies", "OOC buff allies")
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end


return menu


