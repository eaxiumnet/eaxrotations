-- menu.lua | Eax Hunter Survival | TBC
local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes (Standard EAX Menu Structure)
local root_tree       = ps.tree_node()
local rotation_tree   = ps.tree_node()
local kite_tree       = ps.tree_node()
local auto_tree       = ps.tree_node()
local ooc_tree        = ps.tree_node()
local group_tree      = ps.tree_node()
local pvp_tree        = ps.tree_node()
local middleware_tree = ps.tree_node()
local dashboard_tree  = ps.tree_node()
local advanced_tree   = ps.tree_node()  -- NEW: Targeting + Racial

-- Menu field declarations (PRESERVED VERBATIM)
menu.enabled          = core.menu.checkbox(true,  "eaxhuntersv_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxhuntersv_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxhuntersv_mode")

menu.focus_priority      = core.menu.checkbox(false, "eaxhuntersv_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxhuntersv_combat_self_hp_boost")

menu.use_racial = core.menu.checkbox(true, "eaxhuntersv_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxhuntersv_racial_hp")

-- Interrupt
menu.use_interrupt = core.menu.checkbox(true, "eaxhuntersv_use_interrupt")

menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez         = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff  = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_combat_potions = core.menu.checkbox(false, "eaxhuntersv_auto_combat_potions")
menu.auto_flask      = core.menu.checkbox(false, "eaxhuntersv_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxhuntersv_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxhuntersv_lev_mana_floor")

menu.use_hunters_mark   = core.menu.checkbox(true, "eaxhuntersv_use_hunters_mark")
menu.hunters_mark_mode  = core.menu.combobox(1, "eaxhuntersv_hunters_mark_mode")
menu.use_serpent_sting  = core.menu.checkbox(true, "eaxhuntersv_use_serpent_sting")
menu.use_scorpid_sting  = core.menu.checkbox(false,"eaxhuntersv_use_scorpid_sting")
menu.use_viper_sting    = core.menu.checkbox(false,"eaxhuntersv_use_viper_sting")
menu.use_arcane_shot    = core.menu.checkbox(true, "eaxhuntersv_use_arcane_shot")
menu.use_aimed_shot     = core.menu.checkbox(false, "eaxhuntersv_use_aimed_shot")
menu.use_steady_shot    = core.menu.checkbox(true, "eaxhuntersv_use_steady_shot")
menu.use_multi_shot     = core.menu.checkbox(true, "eaxhuntersv_use_multi_shot")

menu.use_rapid_fire     = core.menu.checkbox(true, "eaxhuntersv_use_rapid_fire")
menu.use_kill_command   = core.menu.checkbox(true, "eaxhuntersv_use_kill_command")
menu.use_misdirection   = core.menu.checkbox(true, "eaxhuntersv_use_misdirection")
menu.use_aspect_viper   = core.menu.checkbox(true, "eaxhuntersv_use_aspect_viper")
menu.viper_mana_enter   = core.menu.slider_int(10, 60, 35, "eaxhuntersv_viper_enter")
menu.viper_mana_exit    = core.menu.slider_int(50, 100, 85, "eaxhuntersv_viper_mana_exit")
menu.auto_travel_aspect  = core.menu.checkbox(true, "eaxhuntersv_auto_travel_aspect")
menu.use_aspect_hawk = core.menu.checkbox(true, "eaxhuntersurvival_use_aspect_hawk")
menu.cd_min_ttd = core.menu.slider_int(0, 60, 0, "eaxhuntersv_cd_min_ttd")

-- Burst Manager Settings
menu.auto_burst_enabled = core.menu.checkbox(false, "eaxhuntersv_auto_burst_enabled")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eaxhuntersv_burst_on_bloodlust")
menu.burst_on_pull = core.menu.checkbox(true, "eaxhuntersv_burst_on_pull")
menu.burst_on_execute = core.menu.checkbox(false, "eaxhuntersv_burst_on_execute")
menu.burst_in_combat = core.menu.checkbox(false, "eaxhuntersv_burst_in_combat")

-- Trinket Manager Settings
menu.trinket1_mode = core.menu.combobox(1, "eaxhuntersv_trinket1_mode")
menu.trinket2_mode = core.menu.combobox(1, "eaxhuntersv_trinket2_mode")
menu.trinket_ttd = core.menu.slider_int(5, 30, 10, "hunter_trinket_ttd")
menu.defensive_trinket_hp = core.menu.slider_int(15, 50, 35, "hunter_def_trinket_hp")

menu.use_concussive     = core.menu.checkbox(true, "eaxhuntersv_use_concussive")
menu.use_disengage      = core.menu.checkbox(true, "eaxhuntersv_use_disengage")
menu.use_wing_clip      = core.menu.checkbox(true, "eaxhuntersv_use_wing_clip")
menu.wing_clip_pve_hp   = core.menu.slider_int(10, 80, 35, "eaxhuntersv_wing_clip_pve_hp")
menu.wing_clip_pvp_hp   = core.menu.slider_int(10, 80, 25, "eaxhuntersv_wing_clip_pvp_hp")
menu.use_deterrence     = core.menu.checkbox(true, "eaxhuntersv_use_deterrence")
menu.deterrence_hp      = core.menu.slider_int(5, 40, 12, "eaxhuntersv_deterrence_hp")
menu.use_feign_death    = core.menu.checkbox(true, "eaxhuntersv_use_feign_death")
menu.feign_death_hp     = core.menu.slider_int(5, 40, 20, "eaxhuntersv_feign_hp")

-- Traps
menu.use_traps       = core.menu.checkbox(true, "eaxhuntersv_use_traps")
menu.trap_interval   = core.menu.slider_float(1.0, 60.0, 30.0, "eaxhuntersv_trap_interval")
menu.trap_selection  = core.menu.combobox(1, "eaxhuntersv_trap_selection")
menu.use_immolation_trap = core.menu.checkbox(true, "eaxhuntersv_use_immolation_trap")
menu.use_explosive_trap = core.menu.checkbox(true, "eaxhuntersv_use_explosive_trap")
menu.use_wyvern_sting = core.menu.checkbox(false, "eaxhuntersv_use_wyvern_sting")
menu.use_mongoose_bite = core.menu.checkbox(true, "eaxhuntersv_use_mongoose_bite")
menu.use_counterattack = core.menu.checkbox(true, "eaxhuntersv_use_counterattack")
menu.pet_aggressive  = core.menu.checkbox(false, "eaxhuntersv_pet_aggressive")

-- Pet Settings (ADDED - were referenced but not declared)
menu.use_revive_pet  = core.menu.checkbox(true, "eaxhuntersv_use_revive_pet")
menu.use_mend_pet    = core.menu.checkbox(true, "eaxhuntersv_use_mend_pet")
menu.mend_pet_hp     = core.menu.slider_int(10, 80, 50, "eaxhuntersv_mend_pet_hp")

-- PvP Settings
menu.pvp_enabled = core.menu.checkbox(true, "eaxhuntersv_pvp_enabled")
menu.pvp_mode = core.menu.combobox(1, "eaxhuntersv_pvp_mode")
menu.pvp_use_trinket = core.menu.checkbox(true, "eaxhuntersv_pvp_trinket")
menu.pvp_defensive_threshold = core.menu.slider_int(10, 80, 40, "eaxhuntersv_pvp_def_hp")

-- Middleware Settings
menu.use_healthstone = core.menu.checkbox(true, "eaxhuntersv_use_healthstone")
menu.healthstone_hp_pct = core.menu.slider_int(5, 50, 30, "eaxhuntersv_healthstone_hp")
menu.use_healing_potion = core.menu.checkbox(true, "eaxhuntersv_use_healing_potion")
menu.health_potion_hp_pct = core.menu.slider_int(5, 50, 40, "eaxhuntersv_healing_potion_hp")
menu.use_mana_potion = core.menu.checkbox(true, "eaxhuntersv_use_mana_potion")
menu.mana_potion_pct = core.menu.slider_int(5, 50, 20, "eaxhuntersv_mana_potion_pct")
menu.use_deterrence_mw = core.menu.checkbox(true, "eaxhuntersv_use_deterrence_mw")
menu.deterrence_mw_hp = core.menu.slider_int(5, 30, 15, "eaxhuntersv_deterrence_mw_hp")

-- Dashboard Settings (Standardized)
menu.show_dashboard   = core.menu.checkbox(false, "eaxhuntersv_show_dashboard")  -- Default OFF (Beta)
menu.dashboard_opacity = core.menu.slider_int(50, 255, 190, "eaxhuntersv_dashboard_opacity")
menu.dashboard_scale  = core.menu.slider_float(0.5, 2.0, 1.0, "eaxhuntersv_dashboard_scale")
menu.dashboard_x      = core.menu.slider_int(0, 2000, 20, "eaxhuntersv_dashboard_x")
menu.dashboard_y      = core.menu.slider_int(0, 2000, 200, "eaxhuntersv_dashboard_y")
menu.show_timer_bars  = core.menu.checkbox(true, "eaxhuntersv_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxhuntersv_show_action_history")

-- Clip Tracker Settings
menu.clip_tracker_enabled = core.menu.checkbox(false, "eaxhuntersv_clip_tracker_enabled")
menu.clip_tracker_print_summary = core.menu.checkbox(true, "eaxhuntersv_clip_print_summary")
menu.clip_threshold_green = core.menu.slider_int(50, 200, 125, "eaxhuntersv_clip_threshold_1")
menu.clip_threshold_yellow = core.menu.slider_int(150, 400, 250, "eaxhuntersv_clip_threshold_2")
menu.clip_threshold_orange = core.menu.slider_int(300, 750, 500, "eaxhuntersv_clip_threshold_3")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_serpent_sting", label = "Serpent Sting" },
    { toggle = "use_steady_shot", label = "Steady Shot" },
}, {
    namespace = "eaxhuntersv",
    log_prefix = "[Eax Hunter SV] ",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxhuntersv")
    end

    root_tree:render("Eax's Hunter Survival", function()
        -- 1. General (inline)
        ps.header("General")
        menu.enabled:render("Enabled", "Enable/disable rotation")
        menu.mode:render("Mode", {"Auto", "PvE", "PvP"}, "Rotation mode selection")
        menu.toggle_key:render("Toggle Key", "Keybind to enable/disable")

        -- 2. Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Shots")
            menu.use_hunters_mark:render("Hunter's Mark", "+AP")
            menu.hunters_mark_mode:render("Mark Mode", {"Auto", "Boss Only", "Disabled"}, "When to apply Hunter's Mark")
            menu.use_serpent_sting:render("Serpent Sting", "DoT")
            menu.use_arcane_shot:render("Arcane Shot", "Filler")
            menu.use_aimed_shot:render("Aimed Shot", "Cast")
            menu.use_steady_shot:render("Steady Shot", "Filler")
            menu.use_multi_shot:render("Multi-Shot", "AoE")

            ps.header("Stings (Group)")
            menu.use_scorpid_sting:render("Scorpid Sting", "-5% hit")
            menu.use_viper_sting:render("Viper Sting", "Drain")

            ps.header("Cooldowns")
            menu.use_rapid_fire:render("Rapid Fire", "Burst")
            menu.use_kill_command:render("Kill Command", "Pet burst")
            menu.use_misdirection:render("Misdirection", "Threat")
            menu.use_aspect_viper:render("Auto-Viper", "Low mana")
            menu.viper_mana_enter:render("Enter Viper %", "Below")
            menu.viper_mana_exit:render("Exit Viper %", "Above")
            menu.auto_travel_aspect:render("Travel Aspect", "OOC")
            menu.cd_min_ttd:render("Min TTD for CDs", "Only use burst CDs if target TTD >= seconds (0 = disabled)")

            ps.header("Burst Manager")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst CD usage")
            menu.burst_on_bloodlust:render("Burst on Bloodlust", "Use CDs when Bloodlust/Heroism active")
            menu.burst_on_pull:render("Burst on Pull", "Use CDs within first 5s of combat")
            menu.burst_on_execute:render("Burst on Execute", "Use CDs when target <20% HP")
            menu.burst_in_combat:render("Burst in Combat", "Use CDs anytime in combat")

            ps.header("Trinket Manager")
            menu.trinket1_mode:render("Trinket 1 Mode", {"Off", "Offensive", "Defensive"}, "Top trinket slot behavior")
            menu.trinket2_mode:render("Trinket 2 Mode", {"Off", "Offensive", "Defensive"}, "Bottom trinket slot behavior")
            menu.trinket_ttd:render("Trinket TTD", "Min target TTD to use offensive trinkets")
            menu.defensive_trinket_hp:render("Defensive Trinket HP%", "HP% threshold for defensive trinkets")

            ps.header("Traps")
            menu.use_traps:render("Use Traps", "Enable trap usage")
            menu.trap_interval:render("Trap Interval", "Seconds between trap attempts")
            menu.trap_selection:render("Trap Selection", {"Immolation", "Explosive", "Freezing", "Frost"}, "Which trap to use")
            menu.use_immolation_trap:render("Immolation Trap", "Fire damage trap")
            menu.use_explosive_trap:render("Explosive Trap", "AoE fire trap")
            menu.use_wyvern_sting:render("Wyvern Sting", "Sleep effect (Survival talent)")

            ps.header("Survival Melee")
            menu.use_mongoose_bite:render("Mongoose Bite", "Melee")
            menu.use_counterattack:render("Counterattack", "Melee proc")
        end)

        -- 3. Defensive (kite_tree)
        kite_tree:render("Defensive", function()
            ps.header("Kiting & Escape")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_concussive:render("Concussive Shot", "Slow")
            menu.use_disengage:render("Disengage", "Escape")
            menu.use_wing_clip:render("Wing Clip", "Melee slow")
            menu.wing_clip_pve_hp:render("Wing Clip PvE HP%", "Below")
            menu.wing_clip_pvp_hp:render("Wing Clip PvP HP%", "Below")
            menu.use_deterrence:render("Deterrence", "Self-def")
            menu.deterrence_hp:render("Deterrence HP %", "Below")
            menu.use_feign_death:render("Feign Death", "Emergency")
            menu.feign_death_hp:render("Feign HP %", "Below")
        end)

        -- 4. Automation
        auto_tree:render("Automation", function()
            ps.header("Consumables")
            menu.auto_combat_potions:render("Combat Potions", "In combat")
            menu.auto_flask:render("Auto Flask", "Flask")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling")
            menu.leveling_mana_floor:render("Mana %", "Below")
        end)

        -- 5. OOC Sustain
        ooc_tree:render("OOC Sustain", function()
            ps.header("Food & Drink")
            menu.ooc_drink:render("Auto-Drink", "Drink")
            menu.drink_threshold:render("Drink %", "Below")
            menu.ooc_eat:render("Auto-Eat", "Eat")
            menu.eat_threshold:render("Eat %", "Below")
            menu.use_aspect_hawk:render("Aspect of the Hawk", "Ranged AP buff")
        end)

        -- 6. Group
        group_tree:render("Group", function()
            ps.header("Group Support")
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
        end)

        -- 7. Pet (inline tree)
        local pet_tree = ps.tree_node()
        pet_tree:render("Pet", function()
            ps.header("Pet Management")
            menu.use_revive_pet:render("Revive Pet", "Auto-revive")
            menu.use_mend_pet:render("Mend Pet", "Heal pet")
            menu.mend_pet_hp:render("Mend Pet HP%", "Below")
            menu.pet_aggressive:render("Aggressive Pet", "Pet attacks automatically")
        end)

        -- 8. PvP
        pvp_tree:render("PvP", function()
            ps.header("General")
            menu.pvp_enabled:render("Enable PvP", "Enable PvP rotation features")
            menu.pvp_mode:render("PvP Mode", {"Auto", "PvE Only", "PvP Only"}, "Select PvP detection mode")
            menu.pvp_use_trinket:render("Use PvP Trinket", "Auto-use PvP trinket when CC'd")
            menu.pvp_defensive_threshold:render("Defensive Threshold %", "Use defensives below this HP% in PvP")
        end)

        -- 9. Middleware
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

        -- 10. Dashboard (with Targeting and Racial inline)
        dashboard_tree:render("Dashboard (Beta)", function()
            ps.header("Display (Beta)")
            menu.show_dashboard:render("Show Dashboard", "Enable dashboard (Beta feature)")
            menu.dashboard_opacity:render("Opacity", "Dashboard background opacity")
            menu.dashboard_scale:render("Scale", "Dashboard size multiplier")
            menu.dashboard_x:render("Position X", "Horizontal position")
            menu.dashboard_y:render("Position Y", "Vertical position")
            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent spell casts")

            ps.header("Clip Tracker")
            menu.clip_tracker_enabled:render("Enable Clip Tracker", "Track auto-shot clipping")
            menu.clip_tracker_print_summary:render("Print Summary", "Show combat summary")
            ps.header("Severity Thresholds (ms)")
            menu.clip_threshold_green:render("Green/Yellow", "Green to yellow threshold")
            menu.clip_threshold_yellow:render("Yellow/Orange", "Yellow to orange threshold")
            menu.clip_threshold_orange:render("Orange/Red", "Orange to red threshold")
        end)

        -- 11. Advanced (Targeting + Racial)
        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target over target")
            menu.combat_self_hp_boost:render("Self HP Boost", "HP threshold adjustment for self-preservation")

            ps.header("Racial")
            menu.use_racial:render("Use Racial", "Auto-use racial abilities when beneficial")
            menu.racial_hp:render("Racial HP %", "Use racial abilities below this HP%")
        end)
    end)
end

return menu
