-- menu.lua  |  Eax Hunter Beast Mastery  |  TBC
local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree   = ps.tree_node()
local rotation_tree = ps.tree_node()
local pet_tree    = ps.tree_node()
local cd_tree     = ps.tree_node()
local kite_tree   = ps.tree_node()
local auto_tree   = ps.tree_node()
local ooc_tree    = ps.tree_node()
local group_tree  = ps.tree_node()
local def_tree    = ps.tree_node()
local tgt_tree    = ps.tree_node()
local racial_tree = ps.tree_node()
local esp_tree    = ps.tree_node()
local pvp_tree    = ps.tree_node()
local middleware_tree = ps.tree_node()
local dashboard_tree = ps.tree_node()

-- Controls
menu.enabled          = core.menu.checkbox(true,  "eaxhunterbm_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxhunterbm_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxhunterbm_mode")
menu.debug            = core.menu.checkbox(false, "eaxhunterbm_debug")

-- Targeting
menu.focus_priority      = core.menu.checkbox(false, "eaxhunterbm_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxhunterbm_combat_self_hp_boost")

-- Racial
menu.use_racial = core.menu.checkbox(true, "eaxhunterbm_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxhunterbm_racial_hp")

-- Interrupt
menu.use_interrupt = core.menu.checkbox(true, "eaxhunterbm_use_interrupt")

-- OOC Sustain
menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
menu.use_aspect_hawk = core.menu.checkbox(true, "eaxhunterbm_use_aspect_hawk")

-- Automation
menu.auto_combat_potions = core.menu.checkbox(false, "eaxhunterbm_auto_combat_potions")
menu.auto_flask      = core.menu.checkbox(false, "eaxhunterbm_auto_flask")

-- Leveling
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxhunterbm_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxhunterbm_lev_mana_floor")

-- Rotation - Shots
menu.use_hunters_mark   = core.menu.checkbox(true, "eaxhunterbm_use_hunters_mark")
menu.hunters_mark_mode  = core.menu.combobox(1, "eaxhunterbm_hunters_mark_mode")
menu.use_serpent_sting  = core.menu.checkbox(true, "eaxhunterbm_use_serpent_sting")
menu.use_scorpid_sting  = core.menu.checkbox(false,"eaxhunterbm_use_scorpid_sting")
menu.use_viper_sting    = core.menu.checkbox(false,"eaxhunterbm_use_viper_sting")
-- Per-class Viper Sting toggles (PvP mana drain control)
menu.viper_sting_priest   = core.menu.checkbox(true,  "eaxhunterbm_viper_sting_priest")
menu.viper_sting_paladin   = core.menu.checkbox(true,  "eaxhunterbm_viper_sting_paladin")
menu.viper_sting_shaman    = core.menu.checkbox(true,  "eaxhunterbm_viper_sting_shaman")
menu.viper_sting_mage      = core.menu.checkbox(true,  "eaxhunterbm_viper_sting_mage")
menu.viper_sting_warlock  = core.menu.checkbox(true,  "eaxhunterbm_viper_sting_warlock")
menu.viper_sting_druid    = core.menu.checkbox(true,  "eaxhunterbm_viper_sting_druid")
menu.viper_sting_hunter   = core.menu.checkbox(false, "eaxhunterbm_viper_sting_hunter")
menu.use_arcane_shot    = core.menu.checkbox(true, "eaxhunterbm_use_arcane_shot")
menu.use_aimed_shot     = core.menu.checkbox(false, "eaxhunterbm_use_aimed_shot")
menu.use_steady_shot    = core.menu.checkbox(true, "eaxhunterbm_use_steady_shot")
menu.use_multi_shot     = core.menu.checkbox(true, "eaxhunterbm_use_multi_shot")
menu.use_raptor_strike  = core.menu.checkbox(true, "eaxhunterbm_use_raptor_strike")
menu.use_wing_clip      = core.menu.checkbox(true, "eaxhunterbm_use_wing_clip")

-- Warces Haste Mode
menu.use_warces_mode    = core.menu.checkbox(false, "eaxhunterbm_use_warces_mode")
menu.warces_latency     = core.menu.slider_int(50, 300, 100, "eaxhunterbm_warces_latency")
menu.wing_clip_pvp_hp  = core.menu.slider_int(10, 50, 25, "eaxhunterbm_wing_clip_pvp_hp")
menu.wing_clip_pve_hp  = core.menu.slider_int(10, 50, 35, "eaxhunterbm_wing_clip_pve_hp")

-- Rotation - Pet
menu.use_kill_command   = core.menu.checkbox(true, "eaxhunterbm_use_kill_command")
menu.use_bestial_wrath  = core.menu.checkbox(true, "eaxhunterbm_use_bestial_wrath")
menu.use_intimidation   = core.menu.checkbox(true, "eaxhunterbm_use_intimidation")
menu.use_mend_pet       = core.menu.checkbox(true, "eaxhunterbm_use_mend_pet")
menu.mend_pet_hp        = core.menu.slider_int(10, 90, 50, "eaxhunterbm_mend_pet_hp")
menu.use_revive_pet     = core.menu.checkbox(true, "eaxhunterbm_use_revive_pet")

-- Cooldowns
menu.use_rapid_fire     = core.menu.checkbox(true, "eaxhunterbm_use_rapid_fire")
menu.use_misdirection   = core.menu.checkbox(true, "eaxhunterbm_use_misdirection")
menu.use_aspect_viper   = core.menu.checkbox(true, "eaxhunterbm_use_aspect_viper")
menu.viper_mana_enter   = core.menu.slider_int(10, 60, 35, "eaxhunterbm_viper_enter")
menu.viper_mana_exit    = core.menu.slider_int(50, 100, 85, "eaxhunterbm_viper_mana_exit")
menu.auto_travel_aspect  = core.menu.checkbox(true, "eaxhunterbm_auto_travel_aspect")
menu.use_pack_as_travel_aspect = core.menu.checkbox(false, "eaxhunterbm_use_pack_as_travel_aspect")

-- Burst & Trinket Automation
menu.auto_burst_enabled = core.menu.checkbox(false, "eaxhunterbm_auto_burst")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eaxhunterbm_burst_bloodlust")
menu.burst_on_pull      = core.menu.checkbox(true, "eaxhunterbm_burst_pull")
menu.burst_on_execute   = core.menu.checkbox(true, "eaxhunterbm_burst_execute")
menu.burst_in_combat    = core.menu.checkbox(false, "eaxhunterbm_burst_always")
menu.cd_min_ttd         = core.menu.slider_int(0, 60, 0, "eaxhunterbm_cd_min_ttd")
menu.trinket1_mode      = core.menu.combobox(1, "eaxhunterbm_trinket1_mode")
menu.trinket2_mode      = core.menu.combobox(1, "eaxhunterbm_trinket2_mode")
menu.trinket_ttd = core.menu.slider_int(5, 30, 10, "hunter_trinket_ttd")
menu.defensive_trinket_hp = core.menu.slider_int(15, 50, 35, "hunter_def_trinket_hp")

-- Kiting/Utility
menu.use_concussive     = core.menu.checkbox(true, "eaxhunterbm_use_concussive")
menu.use_disengage      = core.menu.checkbox(true, "eaxhunterbm_use_disengage")
menu.use_deterrence     = core.menu.checkbox(true, "eaxhunterbm_use_deterrence")
menu.deterrence_hp      = core.menu.slider_int(5, 40, 12, "eaxhunterbm_deterrence_hp")
menu.use_feign_death    = core.menu.checkbox(true, "eaxhunterbm_use_feign_death")
menu.feign_death_hp     = core.menu.slider_int(5, 40, 20, "eaxhunterbm_feign_hp")

-- Traps
menu.use_traps       = core.menu.checkbox(true, "eaxhunterbm_use_traps")
menu.trap_selection  = core.menu.combobox(1,    "eaxhunterbm_trap_selection")
menu.trap_interval   = core.menu.slider_float(1.0, 60.0, 30.0, "eaxhunterbm_trap_interval")
menu.protect_frozen_target = core.menu.checkbox(true, "eaxhunterbm_protect_frozen_target")

-- Anti-Stealth
menu.use_scare_beast    = core.menu.checkbox(false, "eaxhunterbm_use_scare_beast")
menu.use_flare          = core.menu.checkbox(false, "eaxhunterbm_use_flare")
menu.auto_stealth_flare = core.menu.checkbox(true, "eaxhunterbm_auto_stealth_flare")
menu.stealth_warning    = core.menu.checkbox(true, "eaxhunterbm_stealth_warning")
menu.stealth_scan_radius = core.menu.slider_float(10.0, 60.0, 20.0, "eaxhunterbm_stealth_scan_radius")
menu.stealth_prediction_s = core.menu.slider_float(0.00, 0.75, 0.20, "eaxhunterbm_stealth_prediction_s")
menu.stealth_overlay_enabled = core.menu.checkbox(true, "eaxhunterbm_stealth_overlay_enabled")
menu.stealth_overlay_direction = core.menu.checkbox(true, "eaxhunterbm_stealth_overlay_direction")

-- PvP Settings
menu.pvp_enabled = core.menu.checkbox(true, "eaxhunterbm_pvp_enabled")
menu.pvp_mode = core.menu.combobox(1, "eaxhunterbm_pvp_mode")
menu.pvp_use_trinket = core.menu.checkbox(true, "eaxhunterbm_pvp_trinket")
menu.pvp_defensive_threshold = core.menu.slider_int(10, 80, 40, "eaxhunterbm_pvp_def_hp")

-- Middleware Settings
menu.use_healthstone = core.menu.checkbox(true, "eaxhunterbm_use_healthstone")
menu.healthstone_hp_pct = core.menu.slider_int(5, 50, 30, "eaxhunterbm_healthstone_hp")
menu.use_healing_potion = core.menu.checkbox(true, "eaxhunterbm_use_healing_potion")
menu.health_potion_hp_pct = core.menu.slider_int(5, 50, 40, "eaxhunterbm_healing_potion_hp")
menu.use_mana_potion = core.menu.checkbox(true, "eaxhunterbm_use_mana_potion")
menu.mana_potion_pct = core.menu.slider_int(5, 50, 20, "eaxhunterbm_mana_potion_pct")
menu.use_deterrence_mw = core.menu.checkbox(true, "eaxhunterbm_use_deterrence_mw")
menu.deterrence_mw_hp = core.menu.slider_int(5, 30, 15, "eaxhunterbm_deterrence_mw_hp")

-- Dashboard Settings
menu.dashboard_enabled = core.menu.checkbox(true, "eaxhunterbm_dashboard_enabled")
menu.dashboard_opacity = core.menu.slider_int(50, 255, 190, "eaxhunterbm_dashboard_opacity")
menu.dashboard_x = core.menu.slider_int(0, 1000, 20, "eaxhunterbm_dashboard_x")
menu.dashboard_y = core.menu.slider_int(0, 1000, 200, "eaxhunterbm_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxhunterbm_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxhunterbm_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxhunterbm_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxhunterbm_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxhunterbm_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxhunterbm_enable_smart_collapse")
menu.dashboard_scale = core.menu.slider_float(0.5, 2.0, 1.0, "eaxhunterbm_dashboard_scale")

-- Pet Settings
menu.preferred_pet       = core.menu.combobox(1, "eaxhunterbm_preferred_pet")
menu.sync_pet_autocast  = core.menu.checkbox(true, "eaxhunterbm_sync_pet_autocast")
menu.disable_growl_in_group = core.menu.checkbox(true, "eaxhunterbm_disable_growl_in_group")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_serpent_sting", label = "Serpent Sting" },
    { toggle = "use_steady_shot", label = "Steady Shot" },
    { toggle = "use_multi_shot", label = "Multi-Shot" },
    { toggle = "use_kill_command", label = "Kill Command" },
    { toggle = "use_traps", label = "Traps" },
}, {
    namespace = "eaxhunterbm",
    log_prefix = "[Eax Hunter BM] ",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxhunterbm")
    end

    root_tree:render("Eax's Hunter Beast Mastery", function()
        ps.render_controls(menu, "Eax's Hunter BM")

        -- Rotation - Shots
        rotation_tree:render("Rotation", function()
            ps.header("Shots")
            menu.use_hunters_mark:render("Hunter's Mark", "+AP buff")
            menu.hunters_mark_mode:render("HM Mode", {"All Targets", "Bosses Only", "Off"})
            menu.use_serpent_sting:render("Serpent Sting", "DoT maintenance")
            menu.use_arcane_shot:render("Arcane Shot", "Instant filler")
            menu.use_steady_shot:render("Steady Shot", "Filler ability")
            menu.use_multi_shot:render("Multi-Shot", "AoE shot")
            menu.use_raptor_strike:render("Raptor Strike", "Melee fallback")
            menu.use_wing_clip:render("Wing Clip", "Slow target")
            menu.wing_clip_pvp_hp:render("WC PvP HP %", "Use Wing Clip in PvP below this HP")
            menu.wing_clip_pve_hp:render("WC PvE HP %", "Use Wing Clip in PvE below this HP")

            ps.header("Warces Haste Mode")
            menu.use_warces_mode:render("Warces Mode", "Haste-adjusted shot weaving")
            menu.warces_latency:render("Latency ms", "Network latency for warces calc")

            ps.header("Stings (Group)")
            menu.use_scorpid_sting:render("Scorpid Sting", "-5% hit in raids")
            menu.use_viper_sting:render("Viper Sting", "Drain mana from casters")
            ps.subheader("Viper Sting Targets")
            menu.viper_sting_priest:render("vs Priest", "Drain mana from Priests")
            menu.viper_sting_paladin:render("vs Paladin", "Drain mana from Paladins")
            menu.viper_sting_shaman:render("vs Shaman", "Drain mana from Shamans")
            menu.viper_sting_mage:render("vs Mage", "Drain mana from Mages")
            menu.viper_sting_warlock:render("vs Warlock", "Drain mana from Warlocks")
            menu.viper_sting_druid:render("vs Druid", "Drain mana from Druids")
            menu.viper_sting_hunter:render("vs Hunter", "Drain mana from Hunters")

            ps.header("Cooldowns")
            menu.use_rapid_fire:render("Rapid Fire", "3-min burst CD")
            menu.use_misdirection:render("Misdirection", "Threat transfer")
            menu.use_aspect_viper:render("Auto-Viper", "Switch when low mana")
            menu.viper_mana_enter:render("Enter Viper %", "Switch below this %")
            menu.viper_mana_exit:render("Exit Viper %", "Switch back above this %")
            menu.auto_travel_aspect:render("Travel Aspect", "Use travel form OOC")

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
            menu.trinket_ttd:render("Trinket TTD", "Min target TTD to use offensive trinkets")
            menu.defensive_trinket_hp:render("Defensive Trinket HP%", "HP% threshold for defensive trinkets")

            ps.header("Traps")
            menu.use_traps:render("Use Traps", "Drop trap in melee")
            menu.trap_selection:render("Trap Type", {"Immolation", "Frost"})
            menu.trap_interval:render("Trap Interval", "Seconds between traps")
            menu.protect_frozen_target:render("Protect Frozen Target", "Auto-switch when target is frozen")
        end)

        -- Pet
        pet_tree:render("Pet", function()
            menu.use_kill_command:render("Kill Command", "Off-GCD pet attack")
            menu.use_bestial_wrath:render("Bestial Wrath", "2-min burst")
            menu.use_intimidation:render("Intimidation", "Pet stun")
            menu.sync_pet_autocast:render("Sync Autocast", "Keep pet autocasts aligned")
            menu.disable_growl_in_group:render("Disable Growl", "In dungeon/raid")
            menu.use_mend_pet:render("Mend Pet", "Heal pet when low")
            menu.mend_pet_hp:render("Mend HP %", "Mend below this %")
            menu.use_revive_pet:render("Revive Pet", "OOC revive")
        end)

        -- Kiting
        kite_tree:render("Kiting & Utility", function()
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            ps.header("Kiting")
            menu.use_concussive:render("Concussive Shot", "Slow target")
            menu.use_disengage:render("Disengage", "Escape melee")
            menu.use_deterrence:render("Deterrence", "Self-defense")
            menu.deterrence_hp:render("Deterrence HP %", "Use below this %")
            menu.use_feign_death:render("Feign Death", "Emergency fade")
            menu.feign_death_hp:render("Feign Death HP %", "Use below this %")

            ps.header("Anti-Stealth")
            menu.auto_stealth_flare:render("Auto Flare", "Drop flare for stealth")
            menu.stealth_warning:render("Stealth Warning", "Warn when stealth nearby")
            menu.stealth_scan_radius:render("Scan Radius", "Detection range")
            menu.use_scare_beast:render("Scare Beast", "Focus CC")
            menu.use_flare:render("Flare", "Manual flare")
        end)

        -- Automation
        auto_tree:render("Automation", function()
            menu.auto_combat_potions:render("Combat Potions", "Use in combat")
            menu.auto_flask:render("Auto Flask", "Maintain flask")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Efficient rotation")
            menu.leveling_mana_floor:render("Mana Floor %", "Conserve below this %")
        end)

        -- OOC Sustain
        ooc_tree:render("OOC Sustain", function()
            menu.ooc_drink:render("Auto-Drink", "Drink OOC")
            menu.drink_threshold:render("Drink Threshold %", "Start below %")
            menu.ooc_eat:render("Auto-Eat", "Eat OOC")
            menu.eat_threshold:render("Eat Threshold %", "Start below %")
            menu.use_aspect_hawk:render("Aspect of the Hawk", "Ranged AP buff")
        end)

        -- Group
        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept rez")
            menu.ooc_group_buff:render("Group Buffs", "Buff party")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            -- (handled in kite tree)
        end)

        -- PvP Settings
        pvp_tree:render("PvP", function()
            menu.pvp_enabled:render("Enable PvP", "Enable PvP rotation features")
            menu.pvp_mode:render("PvP Mode", {"Auto", "PvE Only", "PvP Only"}, "Select PvP detection mode")
            menu.pvp_use_trinket:render("Use PvP Trinket", "Auto-use PvP trinket when CC'd")
            menu.pvp_defensive_threshold:render("Defensive Threshold %", "Use defensives below this HP% in PvP")
        end)

        -- Middleware Settings
        middleware_tree:render("Middleware", function()
            ps.header("Recovery Items")
            menu.use_healthstone:render("Healthstone", "Use healthstone when low")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Use below this %")
            menu.use_healing_potion:render("Healing Potion", "Use potion when low")
            menu.health_potion_hp_pct:render("Potion HP %", "Use below this %")
            menu.use_mana_potion:render("Mana Potion", "Use mana potion when low")
            menu.mana_potion_pct:render("Mana Potion %", "Use below this %")
            
            ps.header("Defensive Middleware")
            menu.use_deterrence_mw:render("Deterrence (MW)", "Use via middleware system")
            menu.deterrence_mw_hp:render("Deterrence MW HP %", "Trigger below this %")
        end)

        -- Dashboard Settings
        dashboard_tree:render("Dashboard", function()
            menu.dashboard_enabled:render("Enable Dashboard", "Show combat dashboard")
            menu.dashboard_opacity:render("Opacity", "Dashboard background opacity")
            menu.dashboard_x:render("Position X", "Horizontal position")
            menu.dashboard_y:render("Position Y", "Vertical position")            
            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent spell casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
            menu.dashboard_scale:render("Scale", "Dashboard size multiplier")
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end

return menu


