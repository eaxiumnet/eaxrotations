-- +------------------------------------------------------------------+
-- |  Eax's Rogue Combat
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}
local POISON_OPTIONS = { "Disabled", "Instant", "Deadly", "Wound", "Crippling", "Mind-Numbing" }

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
menu.enabled                             = core.menu.checkbox(true, "eaxroguecombat_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxroguecombat_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxroguecombat_mode")
menu.debug                               = core.menu.checkbox(false, "eaxroguecombat_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxroguecombat_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxroguecombat_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxroguecombat_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxroguecombat_racial_hp")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxroguecombat_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxroguecombat_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxroguecombat_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxroguecombat_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxroguecombat_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxroguecombat_lev_mana_floor")

-- Rotation
menu.use_sinister_strike                 = core.menu.checkbox(true, "eaxroguecombat_use_sinister_strike")
menu.use_rupture                         = core.menu.checkbox(true, "eaxroguecombat_use_rupture")
menu.use_eviscerate                      = core.menu.checkbox(true, "eaxroguecombat_use_eviscerate")
menu.use_blade_flurry                    = core.menu.checkbox(true, "eaxroguecombat_use_blade_flurry")
menu.use_adrenaline_rush                 = core.menu.checkbox(true, "eaxroguecombat_use_adrenaline_rush")
menu.use_slice_and_dice                  = core.menu.checkbox(true, "eaxroguecombat_use_slice_and_dice")
menu.use_feint                           = core.menu.checkbox(true, "eaxroguecombat_use_feint")

-- Dashboard
menu.show_dashboard         = core.menu.checkbox(true, "eaxroguecombat_show_dashboard")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxroguecombat_dashboard_opacity")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxroguecombat_dashboard_scale")
menu.dashboard_x            = core.menu.slider_int(0, 2000, 20, "eaxroguecombat_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 2000, 200, "eaxroguecombat_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxroguecombat_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxroguecombat_show_action_history")
menu.show_energy_tick = core.menu.checkbox(true, "eaxroguecombat_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(true, "eaxroguecombat_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxroguecombat_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxroguecombat_enable_smart_collapse")
menu.feint_energy_threshold              = core.menu.slider_int(20, 80, 40, "eaxroguecombat_feint_energy_threshold")
menu.use_evasion                         = core.menu.checkbox(true, "eaxroguecombat_use_evasion")
menu.evasion_hp_pct                      = core.menu.slider_int(0, 100, 40, "eaxroguecombat_evasion_hp_pct")
menu.use_cloak_of_shadows                = core.menu.checkbox(true, "eaxroguecombat_use_cloak_of_shadows")
menu.cloak_of_shadows_hp_pct             = core.menu.slider_int(0, 100, 30, "eaxroguecombat_cloak_of_shadows_hp_pct")
menu.use_vanish                          = core.menu.checkbox(true, "eaxroguecombat_use_vanish")
menu.vanish_hp_pct                       = core.menu.slider_int(0, 100, 20, "eaxroguecombat_vanish_hp_pct")
menu.use_distract                        = core.menu.checkbox(true, "eaxroguecombat_use_distract")
menu.use_sap                             = core.menu.checkbox(true, "eaxroguecombat_use_sap")
menu.use_gouge                           = core.menu.checkbox(true, "eaxroguecombat_use_gouge")
menu.use_kick                            = core.menu.checkbox(true, "eaxroguecombat_use_kick")
menu.use_blind                           = core.menu.checkbox(true, "eaxroguecombat_use_blind")
menu.use_sprint                          = core.menu.checkbox(true, "eaxroguecombat_use_sprint")
menu.use_shadowstep                      = core.menu.checkbox(true, "eaxroguecombat_use_shadowstep")
menu.use_ambush                          = core.menu.checkbox(true, "eaxroguecombat_use_ambush")
menu.use_backstab                        = core.menu.checkbox(true, "eaxroguecombat_use_backstab")
menu.use_hemorrhage                      = core.menu.checkbox(true, "eaxroguecombat_use_hemorrhage")
menu.use_garrote                         = core.menu.checkbox(true, "eaxroguecombat_use_garrote")
menu.use_expose_armor                    = core.menu.checkbox(true, "eaxroguecombat_use_expose_armor")
menu.use_deadly_poison                   = core.menu.checkbox(true, "eaxroguecombat_use_deadly_poison")
menu.use_instant_poison                  = core.menu.checkbox(true, "eaxroguecombat_use_instant_poison")
menu.use_wound_poison                    = core.menu.checkbox(true, "eaxroguecombat_use_wound_poison")
menu.use_crippling_poison                = core.menu.checkbox(true, "eaxroguecombat_use_crippling_poison")
menu.use_mind_numbing_poison             = core.menu.checkbox(true, "eaxroguecombat_use_mind_numbing_poison")
menu.use_stealth                         = core.menu.checkbox(true, "eaxroguecombat_use_stealth")
menu.use_preparation                     = core.menu.checkbox(true, "eaxroguecombat_use_preparation")
menu.use_cold_blood                      = core.menu.checkbox(true, "eaxroguecombat_use_cold_blood")
menu.use_cheap_shot                      = core.menu.checkbox(true, "eaxroguecombat_use_cheap_shot")
menu.use_kidney_shot                     = core.menu.checkbox(true, "eaxroguecombat_use_kidney_shot")

-- Combat-specific
menu.snd_refresh_seconds = core.menu.slider_int(1, 10, 3, "eaxroguecom_snd_refresh")
menu.main_hand_poison = core.menu.combobox(1, "eaxroguecom_main_hand_poison")
menu.off_hand_poison = core.menu.combobox(1, "eaxroguecom_off_hand_poison")
menu.finish_combo_points = core.menu.slider_int(3, 5, 4, "eaxroguecom_finish_cp")
menu.use_predictive_snd = core.menu.checkbox(true, "eaxroguecom_use_predictive_snd")
menu.snd_predictive_buffer_seconds = core.menu.slider_int(1, 5, 2, "eaxroguecom_snd_buffer")
menu.cd_min_ttd = core.menu.slider_int(0, 60, 0, "eaxroguecombat_cd_min_ttd")

-- Burst Manager
menu.auto_burst_enabled                  = core.menu.checkbox(false, "eaxroguecombat_auto_burst_enabled")
menu.burst_on_bloodlust                  = core.menu.checkbox(true, "eaxroguecombat_burst_on_bloodlust")
menu.burst_on_pull                       = core.menu.checkbox(true, "eaxroguecombat_burst_on_pull")
menu.burst_on_execute                    = core.menu.checkbox(false, "eaxroguecombat_burst_on_execute")
menu.burst_in_combat                     = core.menu.checkbox(false, "eaxroguecombat_burst_in_combat")

-- Trinket Manager
menu.trinket1_mode                       = core.menu.combobox(1, "eaxroguecombat_trinket1_mode")
menu.trinket2_mode                       = core.menu.combobox(1, "eaxroguecombat_trinket2_mode")
menu.trinket_offensive_ttd               = core.menu.slider_int(0, 30, 10, "eaxroguecombat_trinket_offensive_ttd")
menu.trinket_defensive_hp                = core.menu.slider_int(0, 100, 35, "eaxroguecombat_trinket_defensive_hp")

-- Phase 1 Flux Features
menu.use_energy_tick                     = core.menu.checkbox(true, "eaxroguecombat_use_energy_tick")
menu.use_swing_delay                     = core.menu.checkbox(true, "eaxroguecombat_use_swing_delay")

-- Consumables
menu.use_healthstone  = core.menu.checkbox(true, "eaxroguecombat_use_healthstone")
menu.healthstone_hp_pct = core.menu.slider_int(10, 50, 30, "eaxroguecombat_healthstone_hp_pct")
menu.use_healing_potion = core.menu.checkbox(true, "eaxroguecombat_use_healing_potion")
menu.healing_potion_hp_pct = core.menu.slider_int(10, 50, 25, "eaxroguecombat_healing_potion_hp_pct")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_sinister_strike", label = "Sinister Strike" },
    { toggle = "use_rupture", label = "Rupture" },
    { toggle = "use_eviscerate", label = "Eviscerate" },
    { toggle = "use_blade_flurry", label = "Blade Flurry" },
}, {
    namespace = "eaxroguecombat",
    log_prefix = "[Eax Rogue Combat] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxroguecombat")
    end

    root_tree:render("Eax's Rogue Combat", function()
        ps.header("General")
        menu.enabled:render("Enabled", "Enable/disable rotation")
        menu.mode:render("Mode", {"Auto", "PvE", "PvP"}, "Rotation mode selection")
        menu.toggle_key:render("Toggle Key", "Keybind to enable/disable")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_sinister_strike:render("Sinister Strike", "Main filler")
            menu.use_rupture:render("Rupture", "Maintain")
            menu.use_eviscerate:render("Eviscerate", "Finisher")
            menu.use_slice_and_dice:render("Slice and Dice", "Buff")
            menu.use_feint:render("Feint", "Threat")
            menu.feint_energy_threshold:render("Feint Energy", "Above")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_blade_flurry:render("Blade Flurry", "AoE")
            menu.use_adrenaline_rush:render("Adrenaline Rush", "Energy")
            menu.cd_min_ttd:render("Min TTD for CDs", "Seconds (0 = disabled)")
            
            ps.header("Burst Manager")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst")
            menu.burst_on_bloodlust:render("Burst on Bloodlust", "Use CDs during lust")
            menu.burst_on_pull:render("Burst on Pull", "Use CDs in first 5s")
            menu.burst_on_execute:render("Burst on Execute", "Use CDs below 20% HP")
            menu.burst_in_combat:render("Burst in Combat", "Always use CDs in combat")
            
            ps.header("Trinkets")
            menu.trinket1_mode:render("Trinket 1", "1=Off, 2=Offensive, 3=Defensive")
            menu.trinket2_mode:render("Trinket 2", "1=Off, 2=Offensive, 3=Defensive")
            menu.trinket_offensive_ttd:render("Offensive TTD", "Min TTD to use (seconds)")
            menu.trinket_defensive_hp:render("Defensive HP %", "Below this HP %")
            
            ps.header("Flux Features")
            menu.use_energy_tick:render("Energy Tick Awareness", "Delay actions for tick")
            menu.use_swing_delay:render("Swing Delay", "Avoid clipping auto-attacks")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_evasion:render("Evasion", "Dodge")
            menu.evasion_hp_pct:render("Evasion HP %", "Below")
            menu.use_cloak_of_shadows:render("Cloak of Shadows", "Magic immune")
            menu.cloak_of_shadows_hp_pct:render("Cloak HP %", "Below")
            menu.use_vanish:render("Vanish", "Escape")
            menu.vanish_hp_pct:render("Vanish HP %", "Below")
            ps.header("Consumables")
            menu.use_healthstone:render("Healthstone", "Use healthstone")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.use_healing_potion:render("Healing Potion", "Use healing potion")
            menu.healing_potion_hp_pct:render("Potion HP %", "Below")
        end)

        -- Utility
        auto_tree:render("Utility", function()
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_stealth:render("Stealth", "Stealth")
            menu.use_cheap_shot:render("Cheap Shot", "Stun")
            menu.use_kidney_shot:render("Kidney Shot", "Stun")
            menu.use_distract:render("Distract", "Distraction")
            menu.use_sap:render("Sap", "CC")
            menu.use_gouge:render("Gouge", "CC")
            menu.use_kick:render("Kick", "Interrupt")
            menu.use_blind:render("Blind", "CC")
            menu.use_sprint:render("Sprint", "Speed")
            menu.use_shadowstep:render("Shadowstep", "Teleport")
            menu.use_ambush:render("Ambush", "Stealth opener")
            menu.use_backstab:render("Backstab", "Behind")
            menu.use_hemorrhage:render("Hemorrhage", "Debuff")
            menu.use_garrote:render("Garrote", "Opener")
            menu.use_expose_armor:render("Expose Armor", "Debuff")
        end)

        -- Poisons
        auto_tree:render("Poisons", function()
            menu.use_deadly_poison:render("Deadly Poison", "DoT")
            menu.use_instant_poison:render("Instant Poison", "Proc")
            menu.use_wound_poison:render("Wound Poison", "Heal reduce")
            menu.use_crippling_poison:render("Crippling Poison", "Slow")
            menu.use_mind_numbing_poison:render("Mind-Numbing Poison", "Cast slow")
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
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")            menu.show_energy_tick:render("Energy Tick", "Show energy tick tracker")            menu.show_combo_points:render("Combo Points", "Show combo point pips")
        end)

        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target")
            menu.combat_self_hp_boost:render("Self HP Boost", "HP threshold adjustment")
            
            ps.header("Racial")
            menu.use_racial:render("Use Racial", "Auto-use racial abilities")
            menu.racial_hp:render("Racial HP %", "Use below this HP")
            
            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Mana-efficient rotation")
            menu.leveling_mana_floor:render("Mana Floor %", "Conservation threshold")
        end)
    end)
end


return menu


