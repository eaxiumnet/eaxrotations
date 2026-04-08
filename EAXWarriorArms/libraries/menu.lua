-- +------------------------------------------------------------------+
-- |  Eax's Warrior Arms
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
local cancelaura_tree = ps.tree_node()
local dashboard_tree = ps.tree_node()
local pvp_tree     = ps.tree_node()
local advanced_tree = ps.tree_node()

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxwarriorarms_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarriorarms_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarriorarms_mode")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarriorarms_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarriorarms_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarriorarms_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarriorarms_racial_hp")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxwarriorarms_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarriorarms_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarriorarms_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarriorarms_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarriorarms_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarriorarms_lev_mana_floor")

-- Rotation - Abilities
menu.use_mortal_strike                    = core.menu.checkbox(true, "eaxwarriorarms_use_mortal_strike")
menu.use_slam                             = core.menu.checkbox(true, "eaxwarriorarms_use_slam")
menu.use_whirlwind                        = core.menu.checkbox(true, "eaxwarriorarms_use_whirlwind")
menu.use_overpower                        = core.menu.checkbox(true, "eaxwarriorarms_use_overpower")
menu.use_rend                             = core.menu.checkbox(true, "eaxwarriorarms_use_rend")
menu.use_execute                          = core.menu.checkbox(true, "eaxwarriorarms_use_execute")
menu.slam_safety_buffer_ms                = core.menu.slider_int(50, 300, 120, "eaxwarriorarms_slam_safety_buffer_ms")
menu.execute_use_ms                       = core.menu.checkbox(false, "eaxwarriorarms_execute_use_ms")
menu.execute_use_ww                       = core.menu.checkbox(false, "eaxwarriorarms_execute_use_ww")
menu.execute_use_hs                       = core.menu.checkbox(false, "eaxwarriorarms_execute_use_hs")

-- Burst & Trinket Automation (ported from Flux)
menu.auto_burst_enabled = core.menu.checkbox(false, "eaxwarriorarms_auto_burst")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eaxwarriorarms_burst_bloodlust")
menu.burst_on_pull = core.menu.checkbox(true, "eaxwarriorarms_burst_pull")
menu.burst_on_execute = core.menu.checkbox(true, "eaxwarriorarms_burst_execute")
menu.burst_in_combat = core.menu.checkbox(false, "eaxwarriorarms_burst_always")
menu.cd_min_ttd = core.menu.slider_int(0, 60, 0, "eaxwarriorarms_cd_min_ttd")
menu.trinket1_mode = core.menu.combobox(1, "eaxwarriorarms_trinket1_mode")  -- 1=off, 2=offensive, 3=defensive
menu.trinket2_mode = core.menu.combobox(1, "eaxwarriorarms_trinket2_mode")

-- Swing Management
menu.use_swing_manager = core.menu.checkbox(true, "eaxwarriorarms_use_swing_manager")
menu.swing_queue_threshold = core.menu.slider_int(30, 100, 50, "eaxwarriorarms_swing_queue_threshold")
menu.swing_cleave_threshold = core.menu.slider_int(35, 100, 60, "eaxwarriorarms_swing_cleave_threshold")

-- Heroic Strike Toggle (Arms needs explicit toggle)
menu.use_heroic_strike = core.menu.checkbox(true, "eaxwarriorarms_use_heroic_strike")

-- Shouts
menu.use_battle_shout                     = core.menu.checkbox(true, "eaxwarriorarms_use_battle_shout")
menu.use_commanding_shout                 = core.menu.checkbox(false, "eaxwarriorarms_use_commanding_shout")
menu.use_demo_shout                       = core.menu.checkbox(true, "eaxwarriorarms_use_demo_shout")

-- Debuffs
menu.use_sunder_armor                     = core.menu.checkbox(true, "eaxwarriorarms_use_sunder_armor")
menu.sunder_max_stacks                    = core.menu.slider_int(1, 5, 5, "eaxwarriorarms_sunder_max_stacks")
menu.use_hamstring                        = core.menu.checkbox(true, "eaxwarriorarms_use_hamstring")
menu.use_thunder_clap                     = core.menu.checkbox(true, "eaxwarriorarms_use_thunder_clap")

-- Cancelaura
menu.cancel_pws                        = core.menu.checkbox(true, "eaxwarriorarms_cancel_pws")
menu.cancel_bop                        = core.menu.checkbox(true, "eaxwarriorarms_cancel_bop")
menu.cancelaura_hp_threshold           = core.menu.slider_int(10, 50, 25, "eaxwarriorarms_cancelaura_hp_threshold")

-- Cooldowns
menu.use_cooldowns                        = core.menu.checkbox(true, "eaxwarriorarms_use_cooldowns")
menu.use_berserker_rage                   = core.menu.checkbox(true, "eaxwarriorarms_use_berserker_rage")
menu.use_death_wish                       = core.menu.checkbox(true, "eaxwarriorarms_use_death_wish")
menu.use_recklessness                     = core.menu.checkbox(true, "eaxwarriorarms_use_recklessness")
menu.use_sweeping_strikes                 = core.menu.checkbox(true, "eaxwarriorarms_use_sweeping_strikes")
menu.use_enraged_regen                    = core.menu.checkbox(true, "eaxwarriorarms_use_enraged_regen")
menu.use_blood_fury                       = core.menu.checkbox(true, "eaxwarriorarms_use_blood_fury")
menu.use_berserking                       = core.menu.checkbox(true, "eaxwarriorarms_use_berserking")
menu.use_stoneform                        = core.menu.checkbox(true, "eaxwarriorarms_use_stoneform")
menu.hs_rage_threshold                    = core.menu.slider_int(10, 100, 60, "eaxwarriorarms_hs_rage_threshold")
menu.hs_trick                             = core.menu.checkbox(false, "eaxwarriorarms_hs_trick")

-- Defensive / Consumables
menu.use_healthstone                      = core.menu.checkbox(false, "eaxwarriorarms_use_healthstone")
menu.healthstone_hp_pct                   = core.menu.slider_int(10, 50, 30, "eaxwarriorarms_healthstone_hp_pct")
menu.use_health_potion                    = core.menu.checkbox(true, "eaxwarriorarms_use_health_potion")
menu.health_potion_hp_pct                 = core.menu.slider_int(10, 50, 40, "eaxwarriorarms_health_potion_hp_pct")
menu.stoneform_hp_pct                     = core.menu.slider_int(20, 80, 40, "eaxwarriorarms_stoneform_hp_pct")

-- Dashboard
menu.show_dashboard                       = core.menu.checkbox(true, "eaxwarriorarms_show_dashboard")
menu.dashboard_opacity                    = core.menu.slider_int(50, 255, 190, "eaxwarriorarms_dashboard_opacity")
menu.dashboard_scale                      = core.menu.slider_float(0.5, 2.0, 1.0, "eaxwarriorarms_dashboard_scale")
menu.dashboard_x                        = core.menu.slider_int(0, 2000, 20, "eaxwarriorarms_dashboard_x")
menu.dashboard_y                        = core.menu.slider_int(0, 2000, 200, "eaxwarriorarms_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxwarriorarms_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxwarriorarms_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxwarriorarms_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxwarriorarms_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxwarriorarms_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxwarriorarms_enable_smart_collapse")

-- PvP Settings
menu.pvp_enabled                          = core.menu.checkbox(true, "eaxwarriorarms_pvp_enabled")
menu.pvp_mode                             = core.menu.combobox(1, "eaxwarriorarms_pvp_mode")
menu.pvp_cc_break_check                   = core.menu.checkbox(true, "eaxwarriorarms_pvp_cc_break_check")
menu.pvp_hamstring                        = core.menu.checkbox(true, "eaxwarriorarms_pvp_hamstring")
menu.pvp_piercing_howl                    = core.menu.checkbox(true, "eaxwarriorarms_pvp_piercing_howl")
menu.pvp_rend_stealth                     = core.menu.checkbox(true, "eaxwarriorarms_pvp_rend_stealth")
menu.pvp_overpower_evasion                = core.menu.checkbox(true, "eaxwarriorarms_pvp_overpower_evasion")
menu.pvp_disarm                           = core.menu.checkbox(true, "eaxwarriorarms_pvp_disarm")
menu.pvp_disarm_trigger                   = core.menu.combobox(1, "eaxwarriorarms_pvp_disarm_trigger")
menu.pvp_interrupt_cc_fallback            = core.menu.checkbox(true, "eaxwarriorarms_pvp_interrupt_cc_fallback")
menu.pvp_def_stance_range                 = core.menu.checkbox(true, "eaxwarriorarms_pvp_def_stance_range")
menu.pvp_trinket_defensive                = core.menu.checkbox(true, "eaxwarriorarms_pvp_trinket_defensive")
menu.pvp_burst_threshold                  = core.menu.slider_int(10, 100, 60, "eaxwarriorarms_pvp_burst_threshold")
menu.pvp_save_cooldowns                   = core.menu.checkbox(false, "eaxwarriorarms_pvp_save_cooldowns")
menu.pvp_focus_healers                    = core.menu.checkbox(true, "eaxwarriorarms_pvp_focus_healers")
menu.pvp_target_swapping                  = core.menu.checkbox(true, "eaxwarriorarms_pvp_target_swapping")
menu.pvp_auto_self_cast                   = core.menu.checkbox(true, "eaxwarriorarms_pvp_auto_self_cast")

-- PvP
menu.use_pvp_defensive_stance             = core.menu.checkbox(true, "eaxwarriorarms_use_pvp_defensive_stance")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_mortal_strike", label = "Mortal Strike" },
    { toggle = "use_slam", label = "Slam" },
    { toggle = "use_whirlwind", label = "Whirlwind" },
    { toggle = "use_overpower", label = "Overpower" },
    { toggle = "use_execute", label = "Execute" },
}, {
    namespace = "eaxwarriorarms",
    log_prefix = "[Eax Warrior Arms] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarriorarms")
    end

    root_tree:render("Eax's Warrior Arms", function()
        -- General
        ps.header("General")
        menu.enabled:render("Enabled", "Enable rotation")
        menu.toggle_key:render("Toggle Key", "Quick enable/disable")
        menu.mode:render("Mode", "Auto / PvE / PvP")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_mortal_strike:render("Mortal Strike", "On cooldown")
            menu.use_slam:render("Slam Weave", "Between auto attacks")
            menu.use_whirlwind:render("Whirlwind", "Berserker stance burst")
            menu.use_overpower:render("Overpower", "Dodge proc")
            menu.use_rend:render("Rend", "Blood Frenzy uptime")
            menu.use_execute:render("Execute", "Below 20% HP")
            menu.slam_safety_buffer_ms:render("Slam Buffer", "ms before swing")
            ps.header("Burst & Cooldown Automation")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst CD usage")
            menu.burst_on_bloodlust:render("On Bloodlust", "Use CDs during Bloodlust/Heroism")
            menu.burst_on_pull:render("On Pull", "Use CDs in first 5s of combat")
            menu.burst_on_execute:render("On Execute", "Use CDs below 20% target HP")
            menu.burst_in_combat:render("Always in Combat", "Use CDs whenever in combat")
            menu.cd_min_ttd:render("Min TTD for CDs (s)", "Don't waste CDs on dying targets")
            ps.header("Trinket Automation")
            menu.trinket1_mode:render("Trinket 1 Mode", {"Off", "Offensive", "Defensive"})
            menu.trinket2_mode:render("Trinket 2 Mode", {"Off", "Offensive", "Defensive"})
            ps.header("Swing Management")
            menu.use_swing_manager:render("Use Swing Manager", "Queue HS/Cleave optimally")
            menu.swing_queue_threshold:render("HS Queue Threshold", "Rage to queue Heroic Strike")
            menu.swing_cleave_threshold:render("Cleave Queue Threshold", "Rage to queue Cleave")
            menu.use_heroic_strike:render("Use Heroic Strike", "Enable HS in rotation")
        end)

        -- Shouts
        shouts_tree:render("Shouts", function()
            menu.use_battle_shout:render("Battle Shout", "AP buff")
            menu.use_commanding_shout:render("Commanding Shout", "HP buff")
            menu.use_demo_shout:render("Demoralizing Shout", "Reduce target AP")
        end)

        -- Debuffs
        debuffs_tree:render("Debuffs", function()
            menu.use_sunder_armor:render("Sunder Armor", "Stack in raids")
            menu.sunder_max_stacks:render("Sunder Max", "Max stacks")
            menu.use_hamstring:render("Hamstring", "Slow in solo")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_cooldowns:render("Use Cooldowns", "Enable burst CDs")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_berserker_rage:render("Berserker Rage", "Rage generation")
            menu.use_death_wish:render("Death Wish", "DPS boost")
            menu.use_recklessness:render("Recklessness", "Armor penetration")
            menu.use_sweeping_strikes:render("Sweeping Strikes", "AoE damage")
            menu.use_enraged_regen:render("Enraged Regen", "Self-heal")
            menu.use_blood_fury:render("Blood Fury", "Racial")
            menu.use_berserking:render("Berserking", "Racial")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_healthstone:render("Healthstone", "Low HP")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.use_health_potion:render("Health Potion", "Low HP")
            menu.health_potion_hp_pct:render("Health Potion HP %", "Below")
            menu.use_stoneform:render("Stoneform", "Low HP")
            menu.stoneform_hp_pct:render("Stoneform HP %", "Below")
            menu.use_pvp_defensive_stance:render("PvP Defensive Stance", "Defensive stance at range when Intercept on CD")
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
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
        end)

        -- PvP
        pvp_tree:render("PvP", function()
            ps.header("General")
            menu.pvp_enabled:render("Enable PvP Mode", "PvP-specific logic")
            menu.pvp_mode:render("PvP Mode", "Auto/PvE/PvP")

            ps.header("Offensive")
            menu.pvp_hamstring:render("Maintain Hamstring", "Keep on enemy players")
            menu.pvp_piercing_howl:render("Piercing Howl", "AoE snare when 2+ enemies")
            menu.pvp_rend_stealth:render("Rend Anti-Stealth", "Apply to Rogues/Druids")
            menu.pvp_overpower_evasion:render("Overpower vs Evasion", "Prioritize on dodge")

            ps.header("CC & Control")
            menu.pvp_disarm:render("Auto Disarm", "Disarm enemy melee")
            menu.pvp_disarm_trigger:render("Disarm Trigger", "On CD or On Burst")
            menu.pvp_interrupt_cc_fallback:render("CC Interrupt Fallback", "Backup when kick on CD")

            ps.header("Defensive")
            menu.pvp_def_stance_range:render("Def Stance at Range", "Switch when out of melee")
            menu.pvp_trinket_defensive:render("PvP Trinket", "Use for CC removal")

            ps.header("Burst & Targeting")
            menu.pvp_burst_threshold:render("Burst Threshold", "Target HP% for CDs")
            menu.pvp_save_cooldowns:render("Save CDs vs Healers", "Don't waste on healed targets")
            menu.pvp_focus_healers:render("Focus Healers", "Prioritize in arena/BG")
            menu.pvp_target_swapping:render("Smart Target Swap", "Swap to low HP targets")
            menu.pvp_auto_self_cast:render("Auto Self-Cast", "Cast on self when no friendly target")
        end)

        -- Cancelaura
        cancelaura_tree:render("Cancelaura", function()
            menu.cancel_pws:render("Cancel PW:S", "Remove when rage low")
            menu.cancel_bop:render("Cancel BoP", "Remove when HP safe")
            menu.cancelaura_hp_threshold:render("HP Threshold", "Min HP% to cancel")
        end)

        -- Automation
        auto_tree:render("Automation", function()
            menu.auto_combat_potions:render("Combat Potions", "In combat")
            menu.auto_ooc_food_drink:render("OOC Food/Drink", "Eat/drink OOC")
            menu.auto_flask:render("Auto Flask", "Flask buff")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling")
            menu.leveling_mana_floor:render("Mana %", "Below")
        end)

        -- OOC
        ooc_tree:render("OOC Sustain", function()
            menu.ooc_drink:render("Auto-Drink", "Drink OOC")
            menu.drink_threshold:render("Drink %", "Below")
            menu.ooc_eat:render("Auto-Eat", "Eat OOC")
            menu.eat_threshold:render("Eat %", "Below")
        end)

        -- Group
        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
        end)

        -- Advanced (Targeting, Racial, Leveling)
        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target")
            menu.combat_self_hp_boost:render("Self HP Boost", "HP% threshold for self-heal priority")

            ps.header("Racial")
            menu.use_racial:render("Use Racial", "Enable racial abilities")
            menu.racial_hp:render("Racial HP %", "HP% to use defensive racials")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Resources", "Save resources while leveling")
            menu.leveling_mana_floor:render("Resource Floor %", "Minimum resource % to conserve")
        end)
    end)
end


return menu
