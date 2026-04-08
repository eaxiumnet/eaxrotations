-- menu.lua | Eax Hunter Marksmanship | TBC
local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree   = ps.tree_node()
local rotation_tree = ps.tree_node()
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
menu.enabled          = core.menu.checkbox(true,  "eaxhuntermm_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxhuntermm_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxhuntermm_mode")
menu.debug            = core.menu.checkbox(false, "eaxhuntermm_debug")

-- Targeting
menu.focus_priority      = core.menu.checkbox(false, "eaxhuntermm_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxhuntermm_combat_self_hp_boost")

-- Racial
menu.use_racial = core.menu.checkbox(true, "eaxhuntermm_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxhuntermm_racial_hp")

-- Interrupt
menu.use_interrupt = core.menu.checkbox(true, "eaxhuntermm_use_interrupt")

-- OOC
menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez         = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff  = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
menu.use_aspect_hawk = core.menu.checkbox(true, "eaxhuntermm_use_aspect_hawk")

-- Automation
menu.auto_combat_potions = core.menu.checkbox(false, "eaxhuntermm_auto_combat_potions")
menu.auto_flask      = core.menu.checkbox(false, "eaxhuntermm_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxhuntermm_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxhuntermm_lev_mana_floor")

-- ESP
menu.esp_show_hud    = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x      = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y      = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- Rotation
menu.use_hunters_mark   = core.menu.checkbox(true, "eaxhuntermm_use_hunters_mark")
menu.hunters_mark_mode  = core.menu.combobox(1, "eaxhuntermm_hunters_mark_mode")
menu.use_serpent_sting  = core.menu.checkbox(true, "eaxhuntermm_use_serpent_sting")
menu.use_scorpid_sting  = core.menu.checkbox(false,"eaxhuntermm_use_scorpid_sting")
menu.use_viper_sting    = core.menu.checkbox(false,"eaxhuntermm_use_viper_sting")
menu.use_arcane_shot    = core.menu.checkbox(true, "eaxhuntermm_use_arcane_shot")
menu.use_aimed_shot     = core.menu.checkbox(false, "eaxhuntermm_use_aimed_shot")
menu.use_steady_shot    = core.menu.checkbox(true, "eaxhuntermm_use_steady_shot")
menu.use_multi_shot     = core.menu.checkbox(true, "eaxhuntermm_use_multi_shot")
menu.use_kill_command   = core.menu.checkbox(true, "eaxhuntermm_use_kill_command")
menu.use_raptor_strike  = core.menu.checkbox(true, "eaxhuntermm_use_raptor_strike")
menu.use_wing_clip      = core.menu.checkbox(true, "eaxhuntermm_use_wing_clip")
menu.wing_clip_pvp_hp   = core.menu.slider_int(5, 50, 25, "eaxhuntermm_wing_clip_pvp_hp")
menu.wing_clip_pve_hp   = core.menu.slider_int(5, 50, 35, "eaxhuntermm_wing_clip_pve_hp")

-- Cooldowns
menu.use_rapid_fire     = core.menu.checkbox(true, "eaxhuntermm_use_rapid_fire")
menu.use_readiness      = core.menu.checkbox(true, "eaxhuntermm_use_readiness")
menu.readiness_rapid_fire = core.menu.checkbox(true, "eaxhuntermm_readiness_rapid_fire")
menu.cd_min_ttd         = core.menu.slider_int(0, 60, 0, "eaxhuntermm_cd_min_ttd")

-- Burst Manager Settings
menu.auto_burst_enabled = core.menu.checkbox(false, "eaxhuntermm_auto_burst_enabled")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eaxhuntermm_burst_on_bloodlust")
menu.burst_on_pull      = core.menu.checkbox(true, "eaxhuntermm_burst_on_pull")
menu.burst_on_execute   = core.menu.checkbox(false, "eaxhuntermm_burst_on_execute")
menu.burst_in_combat    = core.menu.checkbox(false, "eaxhuntermm_burst_in_combat")

-- Trinket Manager Settings
menu.trinket1_mode      = core.menu.combobox(1, "eaxhuntermm_trinket1_mode")
menu.trinket2_mode      = core.menu.combobox(1, "eaxhuntermm_trinket2_mode")
menu.trinket_ttd = core.menu.slider_int(5, 30, 10, "hunter_trinket_ttd")
menu.defensive_trinket_hp = core.menu.slider_int(15, 50, 35, "hunter_def_trinket_hp")
menu.use_misdirection   = core.menu.checkbox(true, "eaxhuntermm_use_misdirection")
menu.use_revive_pet     = core.menu.checkbox(true, "eaxhuntermm_use_revive_pet")
menu.use_mend_pet       = core.menu.checkbox(true, "eaxhuntermm_use_mend_pet")
menu.mend_pet_hp        = core.menu.slider_int(10, 100, 50, "eaxhuntermm_mend_pet_hp")
menu.use_aspect_viper   = core.menu.checkbox(true, "eaxhuntermm_use_aspect_viper")
menu.viper_mana_enter   = core.menu.slider_int(10, 60, 35, "eaxhuntermm_viper_enter")
menu.viper_mana_exit    = core.menu.slider_int(50, 100, 85, "eaxhuntermm_viper_mana_exit")
menu.auto_travel_aspect  = core.menu.checkbox(true, "eaxhuntermm_auto_travel_aspect")

-- Cooldown buffs
menu.use_trueshot_aura = core.menu.checkbox(true, "eaxhuntermm_use_trueshot_aura")

-- Traps
menu.use_traps       = core.menu.checkbox(true, "eaxhuntermm_use_traps")
menu.trap_interval   = core.menu.slider_float(1.0, 60.0, 30.0, "eaxhuntermm_trap_interval")
menu.trap_selection  = core.menu.combobox(1, "eaxhuntermm_trap_selection")

-- Defensive
menu.use_concussive     = core.menu.checkbox(true, "eaxhuntermm_use_concussive")
menu.use_disengage      = core.menu.checkbox(true, "eaxhuntermm_use_disengage")
menu.use_deterrence     = core.menu.checkbox(true, "eaxhuntermm_use_deterrence")
menu.deterrence_hp      = core.menu.slider_int(5, 40, 12, "eaxhuntermm_deterrence_hp")
menu.use_feign_death    = core.menu.checkbox(true, "eaxhuntermm_use_feign_death")
menu.feign_death_hp     = core.menu.slider_int(5, 40, 20, "eaxhuntermm_feign_hp")

-- PvP Settings
menu.pvp_enabled = core.menu.checkbox(true, "eaxhuntermm_pvp_enabled")
menu.pvp_mode = core.menu.combobox(1, "eaxhuntermm_pvp_mode")
menu.pvp_use_trinket = core.menu.checkbox(true, "eaxhuntermm_pvp_trinket")
menu.pvp_defensive_threshold = core.menu.slider_int(10, 80, 40, "eaxhuntermm_pvp_def_hp")

-- Middleware Settings
menu.use_healthstone = core.menu.checkbox(true, "eaxhuntermm_use_healthstone")
menu.healthstone_hp_pct = core.menu.slider_int(5, 50, 30, "eaxhuntermm_healthstone_hp")
menu.use_healing_potion = core.menu.checkbox(true, "eaxhuntermm_use_healing_potion")
menu.health_potion_hp_pct = core.menu.slider_int(5, 50, 40, "eaxhuntermm_healing_potion_hp")
menu.use_mana_potion = core.menu.checkbox(true, "eaxhuntermm_use_mana_potion")
menu.mana_potion_pct = core.menu.slider_int(5, 50, 20, "eaxhuntermm_mana_potion_pct")
menu.use_deterrence_mw = core.menu.checkbox(true, "eaxhuntermm_use_deterrence_mw")
menu.deterrence_mw_hp = core.menu.slider_int(5, 30, 15, "eaxhuntermm_deterrence_mw_hp")

-- Dashboard Settings
menu.dashboard_enabled = core.menu.checkbox(true, "eaxhuntermm_dashboard_enabled")
menu.dashboard_opacity = core.menu.slider_int(50, 255, 190, "eaxhuntermm_dashboard_opacity")
menu.dashboard_x = core.menu.slider_int(0, 1000, 20, "eaxhuntermm_dashboard_x")
menu.dashboard_y = core.menu.slider_int(0, 1000, 200, "eaxhuntermm_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxhuntermm_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxhuntermm_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxhuntermm_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxhuntermm_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxhuntermm_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxhuntermm_enable_smart_collapse")
menu.dashboard_scale = core.menu.slider_float(0.5, 2.0, 1.0, "eaxhuntermm_dashboard_scale")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_serpent_sting", label = "Serpent Sting" },
    { toggle = "use_steady_shot", label = "Steady Shot" },
    { toggle = "use_multi_shot", label = "Multi-Shot" },
}, {
    namespace = "eaxhuntermm",
    log_prefix = "[Eax Hunter MM] ",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxhuntermm")
    end

    root_tree:render("Eax's Hunter Marksmanship", function()
        ps.render_controls(menu, "Eax's Hunter MM")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Shots")
            menu.use_hunters_mark:render("Hunter's Mark", "+AP")
            menu.hunters_mark_mode:render("Mark Mode", {"Auto", "Boss Only", "Disabled"}, "When to apply Hunter's Mark")
            menu.use_serpent_sting:render("Serpent Sting", "DoT")
            menu.use_arcane_shot:render("Arcane Shot", "Filler")
            menu.use_aimed_shot:render("Aimed Shot", "Cast")
            menu.use_steady_shot:render("Steady Shot", "Filler")
            menu.use_multi_shot:render("Multi-Shot", "AoE")
            menu.use_kill_command:render("Kill Command", "Pet burst")

            ps.header("Melee")
            menu.use_raptor_strike:render("Raptor Strike", "Melee")
            menu.use_wing_clip:render("Wing Clip", "Slow melee")
            menu.wing_clip_pvp_hp:render("Wing Clip PvP HP%", "Target HP% threshold in PvP")
            menu.wing_clip_pve_hp:render("Wing Clip PvE HP%", "Target HP% threshold in PvE")

            ps.header("Stings (Group)")
            menu.use_scorpid_sting:render("Scorpid Sting", "-5% hit")
            menu.use_viper_sting:render("Viper Sting", "Drain mana")

            ps.header("Cooldowns")
            menu.use_rapid_fire:render("Rapid Fire", "Burst")
            menu.use_readiness:render("Readiness", "Reset cooldowns")
            menu.readiness_rapid_fire:render("Readiness for Rapid Fire", "Use Readiness to reset Rapid Fire")
            menu.cd_min_ttd:render("Min TTD for CDs", "Only use burst CDs if target TTD >= seconds (0 = disabled)")
            
            ps.header("Burst Manager")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst detection")
            menu.burst_on_bloodlust:render("Burst on Bloodlust", "Use CDs when Bloodlust/Heroism active")
            menu.burst_on_pull:render("Burst on Pull", "Use CDs within 5s of combat start")
            menu.burst_on_execute:render("Burst on Execute", "Use CDs when target < 20% HP")
            menu.burst_in_combat:render("Burst in Combat", "Use CDs whenever in combat")
            
            ps.header("Trinket Manager")
            menu.trinket1_mode:render("Trinket 1 Mode", {"Off", "Offensive", "Defensive"}, "Top trinket slot behavior")
            menu.trinket2_mode:render("Trinket 2 Mode", {"Off", "Offensive", "Defensive"}, "Bottom trinket slot behavior")
            menu.trinket_ttd:render("Trinket TTD", "Min target TTD to use offensive trinkets")
            menu.defensive_trinket_hp:render("Defensive Trinket HP%", "HP% threshold for defensive trinkets")
            menu.use_misdirection:render("Misdirection", "Threat")
            menu.use_aspect_viper:render("Auto-Viper", "Low mana")
            menu.viper_mana_enter:render("Enter Viper %", "Below %")
            menu.viper_mana_exit:render("Exit Viper %", "Above %")
            menu.auto_travel_aspect:render("Travel Aspect", "OOC")
        end)

        -- Defensive
        kite_tree:render("Defensive", function()
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_concussive:render("Concussive Shot", "Slow")
            menu.use_disengage:render("Disengage", "Escape")
            menu.use_deterrence:render("Deterrence", "Self-def")
            menu.deterrence_hp:render("Deterrence HP %", "Below %")
            menu.use_feign_death:render("Feign Death", "Emergency")
            menu.feign_death_hp:render("Feign HP %", "Below %")
            ps.header("Pet")
            menu.use_revive_pet:render("Revive/Call Pet", "Auto revive/call pet")
            menu.use_mend_pet:render("Mend Pet", "Heal pet")
            menu.mend_pet_hp:render("Mend Pet HP %", "Below %")
        end)

        -- Automation
        auto_tree:render("Automation", function()
            menu.auto_combat_potions:render("Combat Potions", "In combat")
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
            menu.use_aspect_hawk:render("Aspect of the Hawk", "Ranged AP buff")
        end)

        -- Group
        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
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


