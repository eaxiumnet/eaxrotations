-- +------------------------------------------------------------------+
-- |  Eax's Warrior Fury
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")

local menu = {}

-- Tree nodes (Standard EAX Menu Structure)
local root_tree        = ps.tree_node()
local rotation_tree    = ps.tree_node()
local cooldowns_tree   = ps.tree_node()
local defensive_tree   = ps.tree_node()
local utility_tree     = ps.tree_node()
local buffs_tree       = ps.tree_node()
local middleware_tree  = ps.tree_node()
local pvp_tree         = ps.tree_node()
local automation_tree  = ps.tree_node()
local dashboard_tree   = ps.tree_node()
local ooc_tree         = ps.tree_node()
local advanced_tree    = ps.tree_node()  -- Targeting + Racial

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxwarriorfury_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarriorfury_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarriorfury_mode")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarriorfury_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarriorfury_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarriorfury_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarriorfury_racial_hp")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxwarriorfury_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarriorfury_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarriorfury_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarriorfury_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarriorfury_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarriorfury_lev_mana_floor")

-- Rotation - Abilities
menu.use_battle_shout                     = core.menu.checkbox(true, "eaxwarriorfury_use_battle_shout")
menu.use_cooldowns                        = core.menu.checkbox(true, "eaxwarriorfury_use_cooldowns")
menu.use_bloodrage                        = core.menu.checkbox(true, "eaxwarriorfury_use_bloodrage")
menu.use_rampage                          = core.menu.checkbox(true, "eaxwarriorfury_use_rampage")
menu.rampage_refresh_threshold           = core.menu.slider_int(0, 5, 3, "eaxwarriorfury_rampage_refresh_threshold")
menu.use_execute                          = core.menu.checkbox(true, "eaxwarriorfury_use_execute")
menu.use_heroic_strike                    = core.menu.checkbox(true, "eaxwarriorfury_use_heroic_strike")
menu.heroic_strike_rage                   = core.menu.slider_int(20, 100, 50, "eaxwarriorfury_hs_rage")
menu.execute_use_hs                       = core.menu.checkbox(false, "eaxwarriorfury_execute_use_hs")
menu.use_cleave                           = core.menu.checkbox(true, "eaxwarriorfury_use_cleave")
menu.use_pummel                           = core.menu.checkbox(true, "eaxwarriorfury_use_pummel")
menu.use_berserker_rage                   = core.menu.checkbox(true, "eaxwarriorfury_use_berserker_rage")
menu.use_sunder_armor                     = core.menu.checkbox(false, "eaxwarriorfury_use_sunder_armor")
menu.use_hamstring                        = core.menu.checkbox(true, "eaxwarriorfury_use_hamstring")
menu.use_hamstring_filler                 = core.menu.checkbox(false, "eaxwarriorfury_use_hamstring_filler")
menu.use_slam_weave                       = core.menu.checkbox(false, "eaxwarriorfury_use_slam_weave")
menu.use_slam                             = core.menu.checkbox(true, "eaxwarriorfury_use_slam")
menu.use_overpower                        = core.menu.checkbox(false, "eaxwarriorfury_use_overpower")
menu.use_intercept                        = core.menu.checkbox(true, "eaxwarriorfury_use_intercept")
menu.use_charge_opener                    = core.menu.checkbox(true, "eaxwarriorfury_use_charge_opener")
menu.use_prepull_bloodrage                = core.menu.checkbox(true, "eaxwarriorfury_use_prepull_bloodrage")
menu.use_bloodthirst                      = core.menu.checkbox(true, "eaxwarriorfury_use_bloodthirst")
menu.execute_use_bt                       = core.menu.checkbox(true, "eaxwarriorfury_execute_use_bt")
menu.use_whirlwind                        = core.menu.checkbox(true, "eaxwarriorfury_use_whirlwind")
menu.execute_use_ww                       = core.menu.checkbox(false, "eaxwarriorfury_execute_use_ww")
menu.use_execute_sniping                  = core.menu.checkbox(true, "eaxwarriorfury_use_execute_sniping")
menu.use_commanding_shout                 = core.menu.checkbox(false, "eaxwarriorfury_use_commanding_shout")
menu.show_notifications                   = core.menu.checkbox(false, "eaxwarriorfury_show_notifications")
menu.use_demo_shout                       = core.menu.checkbox(false, "eaxwarriorfury_use_demo_shout")
menu.use_rend                             = core.menu.checkbox(false, "eaxwarriorfury_use_rend")
menu.use_piercing_howl                    = core.menu.checkbox(false, "eaxwarriorfury_use_piercing_howl")
menu.use_thunder_clap_aoe                 = core.menu.checkbox(false, "eaxwarriorfury_use_thunder_clap_aoe")
menu.use_sweeping_strikes                 = core.menu.checkbox(true, "eaxwarriorfury_use_sweeping_strikes")
menu.track_procs                          = core.menu.checkbox(false, "eaxwarriorfury_track_procs")
menu.use_death_wish                       = core.menu.checkbox(true, "eaxwarriorfury_use_death_wish")
menu.use_recklessness                     = core.menu.checkbox(true, "eaxwarriorfury_use_recklessness")
menu.use_blood_fury                       = core.menu.checkbox(true, "eaxwarriorfury_use_blood_fury")
menu.use_berserking                       = core.menu.checkbox(true, "eaxwarriorfury_use_berserking")
menu.intimidating_shout_key               = core.menu.keybind(7, false, "eaxwarriorfury_intimidating_shout_key")
menu.use_trinkets                         = core.menu.checkbox(true, "eaxwarriorfury_use_trinkets")
menu.use_haste_potion                     = core.menu.checkbox(false, "eaxwarriorfury_use_haste_potion")
menu.use_destruction_potion               = core.menu.checkbox(false, "eaxwarriorfury_use_destruction_potion")
menu.use_drums                            = core.menu.checkbox(false, "eaxwarriorfury_use_drums")
menu.use_healthstone                      = core.menu.checkbox(false, "eaxwarriorfury_use_healthstone")
menu.use_health_potion                    = core.menu.checkbox(true, "eaxwarriorfury_use_health_potion")
menu.use_stoneform                        = core.menu.checkbox(true, "eaxwarriorfury_use_stoneform")
menu.cleave_rage                          = core.menu.slider_int(20, 100, 55, "eaxwarriorfury_cleave_rage")
menu.use_hs_trick                         = core.menu.checkbox(true, "eaxwarriorfury_use_hs_trick")
menu.pool_for_interrupt                   = core.menu.checkbox(true, "eaxwarriorfury_pool_for_interrupt")
menu.aoe_enemy_count                      = core.menu.slider_int(2, 10, 3, "eaxwarriorfury_aoe_count")
menu.ww_priority_count                    = core.menu.slider_int(2, 8, 4, "eaxwarriorfury_ww_priority_count")
menu.sunder_max_stacks                    = core.menu.slider_int(1, 5, 5, "eaxwarriorfury_sunder_max_stacks")
menu.intercept_min_range                  = core.menu.slider_int(8, 25, 10, "eaxwarriorfury_intercept_min_range")
menu.slam_safety_buffer_ms                = core.menu.slider_int(50, 300, 100, "eaxwarriorfury_slam_safety_buffer_ms")
menu.use_swing_desync                     = core.menu.checkbox(false, "eaxwarriorfury_use_swing_desync")
menu.swing_desync_threshold               = core.menu.slider_int(20, 80, 50, "eaxwarriorfury_swing_desync_threshold")
menu.use_hamstring_weave                  = core.menu.checkbox(true, "eaxwarriorfury_use_hamstring_weave")
menu.hamstring_weave_rage                 = core.menu.slider_int(30, 80, 50, "eaxwarriorfury_hamstring_weave_rage")
menu.healthstone_hp_pct                   = core.menu.slider_int(10, 50, 25, "eaxwarriorfury_healthstone_hp_pct")
menu.health_potion_hp_pct                 = core.menu.slider_int(10, 50, 20, "eaxwarriorfury_health_potion_hp_pct")
menu.stoneform_hp_pct                     = core.menu.slider_int(20, 80, 40, "eaxwarriorfury_stoneform_hp_pct")
menu.cancelaura_hp_threshold              = core.menu.slider_int(0, 100, 80, "eaxwarriorfury_cancelaura_hp_threshold")
menu.cancel_pws                           = core.menu.checkbox(true, "eaxwarriorfury_cancel_pws")
menu.cancel_bop                           = core.menu.checkbox(true, "eaxwarriorfury_cancel_bop")

-- Swing Management
menu.use_swing_manager = core.menu.checkbox(true, "eaxwarriorfury_use_swing_manager")
menu.swing_queue_threshold = core.menu.slider_int(30, 100, 50, "eaxwarriorfury_swing_queue_threshold")
menu.swing_cleave_threshold = core.menu.slider_int(35, 100, 60, "eaxwarriorfury_swing_cleave_threshold")
menu.swing_aware_delay = core.menu.checkbox(true, "eaxwarriorfury_swing_aware")

-- Burst & Trinket Automation
menu.auto_burst_enabled                   = core.menu.checkbox(false, "eaxwarriorfury_auto_burst")
menu.burst_on_bloodlust                   = core.menu.checkbox(true, "eaxwarriorfury_burst_bloodlust")
menu.burst_on_pull                        = core.menu.checkbox(true, "eaxwarriorfury_burst_pull")
menu.burst_on_execute                     = core.menu.checkbox(true, "eaxwarriorfury_burst_execute")
menu.burst_in_combat                      = core.menu.checkbox(false, "eaxwarriorfury_burst_always")
menu.cd_min_ttd                           = core.menu.slider_int(0, 60, 0, "eaxwarriorfury_cd_min_ttd")
menu.trinket1_mode                        = core.menu.combobox(1, "eaxwarriorfury_trinket1_mode")
menu.trinket2_mode                        = core.menu.combobox(1, "eaxwarriorfury_trinket2_mode")

-- Dashboard
menu.show_dashboard                       = core.menu.checkbox(true, "eaxwarriorfury_show_dashboard")
menu.dashboard_opacity                    = core.menu.slider_int(50, 255, 190, "eaxwarriorfury_dashboard_opacity")
menu.dashboard_scale                      = core.menu.slider_float(0.5, 2.0, 1.0, "eaxwarriorfury_dashboard_scale")
menu.dashboard_x                        = core.menu.slider_int(0, 2000, 20, "eaxwarriorfury_dashboard_x")
menu.dashboard_y                        = core.menu.slider_int(0, 2000, 200, "eaxwarriorfury_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxwarriorfury_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxwarriorfury_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxwarriorfury_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxwarriorfury_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxwarriorfury_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxwarriorfury_enable_smart_collapse")

-- PvP Settings
menu.pvp_enabled                          = core.menu.checkbox(true, "eaxwarriorfury_pvp_enabled")
menu.pvp_mode                             = core.menu.combobox(1, "eaxwarriorfury_pvp_mode")
menu.pvp_hamstring                        = core.menu.checkbox(true, "eaxwarriorfury_pvp_hamstring")
menu.pvp_piercing_howl                    = core.menu.checkbox(true, "eaxwarriorfury_pvp_piercing_howl")
menu.pvp_rend_stealth                     = core.menu.checkbox(true, "eaxwarriorfury_pvp_rend_stealth")
menu.pvp_overpower_evasion                = core.menu.checkbox(true, "eaxwarriorfury_pvp_overpower_evasion")
menu.pvp_disarm                           = core.menu.checkbox(true, "eaxwarriorfury_pvp_disarm")
menu.pvp_disarm_trigger                   = core.menu.combobox(1, "eaxwarriorfury_pvp_disarm_trigger")
menu.pvp_interrupt_cc_fallback            = core.menu.checkbox(true, "eaxwarriorfury_pvp_interrupt_cc_fallback")
menu.pvp_def_stance_range                 = core.menu.checkbox(true, "eaxwarriorfury_pvp_def_stance_range")
menu.pvp_trinket_defensive                = core.menu.checkbox(true, "eaxwarriorfury_pvp_trinket_defensive")
menu.pvp_burst_threshold                  = core.menu.slider_int(10, 100, 60, "eaxwarriorfury_pvp_burst_threshold")
menu.pvp_save_cooldowns                   = core.menu.checkbox(false, "eaxwarriorfury_pvp_save_cooldowns")
menu.pvp_focus_healers                    = core.menu.checkbox(true, "eaxwarriorfury_pvp_focus_healers")
menu.pvp_target_swapping                  = core.menu.checkbox(true, "eaxwarriorfury_pvp_target_swapping")
menu.pvp_auto_self_cast                   = core.menu.checkbox(true, "eaxwarriorfury_pvp_auto_self_cast")
menu.pvp_cc_break_check                   = core.menu.checkbox(true, "eaxwarriorfury_pvp_cc_break_check")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_rampage", label = "Rampage" },
    { toggle = "use_execute", label = "Execute" },
    { toggle = "use_slam_weave", label = "Slam Weave" },
    { toggle = "use_sweeping_strikes", label = "Sweeping Strikes" },
    { toggle = "use_death_wish", label = "Death Wish" },
}, {
    namespace = "eaxwarriorfury",
    log_prefix = "[Eax Warrior Fury] ",
})

local _win
function menu.set_window(win) _win = win end

-- RENDER
function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarriorfury")
    end

    root_tree:render("Eax's Warrior Fury", function()

        -- 1. General - Visible immediately at top level
        ps.header("General")
        menu.enabled:render("Enabled", "Enable/disable rotation")
        menu.mode:render("Mode", {"Auto", "PvE", "PvP"}, "Rotation mode selection")
        menu.toggle_key:render("Toggle Key", "Keybind to enable/disable")

        -- 2. Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Core Abilities")
            menu.use_bloodthirst:render("Bloodthirst", "Core Fury attack")
            menu.use_whirlwind:render("Whirlwind", "AoE/single target")
            menu.use_execute:render("Execute", "Below 20% HP")
            menu.execute_use_bt:render("BT During Execute", "Use Bloodthirst below 20%")
            menu.execute_use_ww:render("WW During Execute", "Use Whirlwind below 20%")
            menu.use_heroic_strike:render("Heroic Strike", "High rage dump")
            menu.use_cleave:render("Cleave", "AoE dump")
            menu.heroic_strike_rage:render("HS Min Rage", "Queue above (default: 50)")
            menu.cleave_rage:render("Cleave Min Rage", "Queue above")
            menu.execute_use_hs:render("HS During Execute", "Use Heroic Strike below 20%")
            menu.use_hs_trick:render("HS Trick", "Queue early on OH swing")

            ps.header("Slam & Weaving")
            menu.use_slam:render("Slam", "Slam weaving")
            menu.use_slam_weave:render("Slam Weave", "Between autos")
            menu.slam_safety_buffer_ms:render("Slam Buffer", "ms")

            ps.header("Rage Management")
            menu.use_bloodrage:render("Bloodrage", "Low rage, safe HP")
            menu.use_berserker_rage:render("Berserker Rage", "On CD")
            menu.use_prepull_bloodrage:render("Pre-pull Bloodrage", "Before combat")
            menu.pool_for_interrupt:render("Pool for Interrupt", "Hold rage for Pummel")

            ps.header("Buffs & Maintenance")
            menu.use_rampage:render("Rampage", "Maintain buff")
            menu.rampage_refresh_threshold:render("Rampage Refresh", "Seconds before expiry")
            menu.use_battle_shout:render("Battle Shout", "AP buff")
            menu.use_commanding_shout:render("Commanding Shout", "HP buff")
            menu.use_demo_shout:render("Demo Shout", "Reduce AP")

            ps.header("Utility & Movement")
            menu.use_pummel:render("Pummel", "Interrupt")
            menu.use_hamstring:render("Hamstring", "Rage dump / PvP")
            menu.use_hamstring_filler:render("Hamstring Filler", "GCD filler")
            menu.use_hamstring_weave:render("Hamstring Weave", "Movement filler")
            menu.hamstring_weave_rage:render("HS Weave Rage", "Above")
            menu.use_intercept:render("Intercept", "Gap closer")
            menu.intercept_min_range:render("Intercept Min Range", "yd")
            menu.use_charge_opener:render("Charge Opener", "Pre-combat")
            menu.use_overpower:render("Overpower", "Dodge proc")
            menu.use_rend:render("Rend", "Battle Stance only")
            menu.use_thunder_clap_aoe:render("Thunder Clap AoE", "Sweeping window")
            menu.use_piercing_howl:render("Piercing Howl", "Slow")

            ps.header("Debuffs")
            menu.use_sunder_armor:render("Sunder Armor", "Stack")
            menu.sunder_max_stacks:render("Sunder Max", "Stacks")

            ps.header("Advanced")
            menu.use_execute_sniping:render("Execute Sniping", "AoE low HP")
            menu.show_notifications:render("Notifications", "On-screen")
            menu.track_procs:render("Track Procs", "Flurry/Enrage")
            menu.aoe_enemy_count:render("AoE Threshold", "Enemy count")
            menu.ww_priority_count:render("WW Priority Count", "Enemies needed for WW > BT")
            menu.use_swing_desync:render("Swing Desync", "Offset MH/OH timers")
            menu.swing_desync_threshold:render("Desync Threshold", "Rage %")
        end)

        -- 3. Cooldowns
        cooldowns_tree:render("Cooldowns", function()
            ps.header("Major Cooldowns")
            menu.use_cooldowns:render("Use Cooldowns", "Enable burst")
            menu.use_death_wish:render("Death Wish", "Burst")
            menu.use_recklessness:render("Recklessness", "Burst")
            menu.use_sweeping_strikes:render("Sweeping Strikes", "AoE")

            ps.header("Racials")
            menu.use_blood_fury:render("Blood Fury", "Orc racial")
            menu.use_berserking:render("Berserking", "Troll racial")

            ps.header("Consumables")
            menu.use_trinkets:render("Trinkets", "On-use")
            menu.use_haste_potion:render("Haste Potion", "Consumable")
            menu.use_destruction_potion:render("Destruction Potion", "Consumable")
            menu.use_drums:render("Drums", "Battle/War")

            ps.header("Burst Automation")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst CD usage")
            menu.burst_on_bloodlust:render("On Bloodlust", "Use CDs during Bloodlust/Heroism")
            menu.burst_on_pull:render("On Pull", "Use CDs in first 5s of combat")
            menu.burst_on_execute:render("On Execute", "Use CDs below 20% target HP")
            menu.burst_in_combat:render("Always in Combat", "Use CDs whenever in combat")
            menu.cd_min_ttd:render("Min TTD (s)", "Don't use CDs if target dies sooner")

            ps.header("Trinket Automation")
            menu.trinket1_mode:render("Trinket 1", {"Off", "Offensive (Burst)", "Defensive"})
            menu.trinket2_mode:render("Trinket 2", {"Off", "Offensive (Burst)", "Defensive"})
        end)

        -- 4. Defensive
        defensive_tree:render("Defensive", function()
            ps.header("Consumables")
            menu.use_healthstone:render("Healthstone", "Low HP")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.use_health_potion:render("Health Potion", "Low HP")
            menu.health_potion_hp_pct:render("Health Potion HP %", "Below")

            ps.header("Racial Defensives")
            menu.use_stoneform:render("Stoneform", "Low HP (Dwarf)")
            menu.stoneform_hp_pct:render("Stoneform HP %", "Below")

            ps.header("Cancelaura")
            menu.cancelaura_hp_threshold:render("Cancelaura HP %", "Cancel buffs above HP%")
            menu.cancel_pws:render("Cancel PW:S", "Remove shield for rage")
            menu.cancel_bop:render("Cancel BoP", "Remove BoP for attacks")

            ps.header("Emergency")
            menu.intimidating_shout_key:render("Intimidating Shout", "Panic key")
        end)

        -- 5. Utility
        utility_tree:render("Utility", function()
            ps.header("Swing Management")
            menu.use_swing_manager:render("Use Swing Manager", "Queue Heroic Strike/Cleave optimally before swing")
            menu.swing_aware_delay:render("Swing-Aware Delay", "Wait for swing landing before expensive abilities")
            menu.swing_queue_threshold:render("HS Queue Threshold", "Rage threshold to queue Heroic Strike")
            menu.swing_cleave_threshold:render("Cleave Queue Threshold", "Rage threshold to queue Cleave (2+ enemies)")

            ps.header("Interrupt")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
        end)

        -- 6. Buffs
        buffs_tree:render("Buffs", function()
            ps.header("Shouts")
            menu.use_battle_shout:render("Battle Shout", "AP buff")
            menu.use_commanding_shout:render("Commanding Shout", "HP buff")
            menu.use_demo_shout:render("Demo Shout", "Reduce AP")
        end)

        -- 7. Middleware (Consumables)
        middleware_tree:render("Middleware", function()
            ps.header("Emergency Items")
            menu.use_healthstone:render("Healthstone", "Auto-use when HP low (off-GCD)")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Use below this HP")
            menu.use_health_potion:render("Health Potion", "Auto-use when HP low (off-GCD)")
            menu.health_potion_hp_pct:render("Potion HP %", "Use below this HP")
        end)

        -- 8. PvP
        pvp_tree:render("PvP", function()
            ps.header("General")
            menu.pvp_enabled:render("Enable PvP Mode", "PvP-specific logic")
            menu.pvp_mode:render("PvP Mode", {"Auto", "PvE Only", "PvP Only"})

            ps.header("Offensive")
            menu.pvp_hamstring:render("Maintain Hamstring", "Keep on enemy players")
            menu.pvp_piercing_howl:render("Piercing Howl", "AoE snare when 2+ enemies")
            menu.pvp_rend_stealth:render("Rend Anti-Stealth", "Apply to Rogues/Druids")
            menu.pvp_overpower_evasion:render("Overpower vs Evasion", "Prioritize on dodge")

            ps.header("CC & Control")
            menu.pvp_disarm:render("Auto Disarm", "Disarm enemy melee")
            menu.pvp_disarm_trigger:render("Disarm Trigger", {"On CD", "On Burst"})
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
            menu.pvp_cc_break_check:render("CC Break Check", "Avoid breaking CC with AoE")
        end)

        -- 9. Automation
        automation_tree:render("Automation", function()
            ps.header("Combat")
            menu.auto_combat_potions:render("Combat Potions", "In combat")

            ps.header("Out of Combat")
            menu.auto_ooc_food_drink:render("OOC Food/Drink", "Eat/drink")
            menu.auto_flask:render("Auto Flask", "Flask")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling")
            menu.leveling_mana_floor:render("Mana %", "Below")
        end)

        -- 10. Dashboard
        dashboard_tree:render("Dashboard", function()
            ps.header("Display")
            menu.show_dashboard:render("Show Dashboard", "Enable in-game HUD")
            menu.dashboard_opacity:render("Opacity", "Background transparency")
            menu.dashboard_scale:render("Scale", "UI size multiplier")
            menu.dashboard_x:render("Position X", "Dashboard horizontal position")
            menu.dashboard_y:render("Position Y", "Dashboard vertical position")

            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent spell casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
            menu.show_energy_tick:render("Energy Tick", "Show energy tick tracker")
            menu.show_combo_points:render("Combo Points", "Show combo point pips")
            menu.show_threat_bar:render("Threat Bar", "Show threat meter")
        end)

        -- 11. OOC Sustain
        ooc_tree:render("OOC Sustain", function()
            ps.header("Sustain")
            menu.ooc_drink:render("Auto-Drink", "Drink")
            menu.drink_threshold:render("Drink %", "Below")
            menu.ooc_eat:render("Auto-Eat", "Eat")
            menu.eat_threshold:render("Eat %", "Below")

            ps.header("Group Support")
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
        end)

        -- 12. Advanced (Targeting + Racial)
        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target")
            menu.combat_self_hp_boost:render("Self HP Boost", "HP threshold adjustment")

            ps.header("Racial")
            menu.use_racial:render("Use Racial", "Auto-use racial abilities")
            menu.racial_hp:render("Racial HP %", "Use below this HP")
        end)

    end)
end

return menu
