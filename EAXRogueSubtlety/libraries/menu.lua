-- +------------------------------------------------------------------+
-- |  Eax's Rogue Subtlety
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
menu.enabled                             = core.menu.checkbox(true, "eaxroguesubtlety_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxroguesubtlety_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxroguesubtlety_mode")
menu.debug                               = core.menu.checkbox(false, "eaxroguesubtlety_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxroguesubtlety_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxroguesubtlety_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxroguesubtlety_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxroguesubtlety_racial_hp")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxroguesubtlety_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxroguesubtlety_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxroguesubtlety_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxroguesubtlety_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxroguesubtlety_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxroguesubtlety_lev_mana_floor")

-- Rotation
menu.use_backstab                        = core.menu.checkbox(true, "eaxroguesubtlety_use_backstab")
menu.use_ambush                          = core.menu.checkbox(true, "eaxroguesubtlety_use_ambush")
menu.use_garrote                         = core.menu.checkbox(true, "eaxroguesubtlety_use_garrote")
menu.use_rupture                         = core.menu.checkbox(true, "eaxroguesubtlety_use_rupture")
menu.use_preparation                     = core.menu.checkbox(true, "eaxroguesubtlety_use_preparation")
menu.use_hemorrhage                      = core.menu.checkbox(true, "eaxroguesubtlety_use_hemorrhage")
menu.use_eviscerate                      = core.menu.checkbox(true, "eaxroguesubtlety_use_eviscerate")
menu.use_slice_and_dice                  = core.menu.checkbox(true, "eaxroguesubtlety_use_slice_and_dice")
menu.use_feint                           = core.menu.checkbox(true, "eaxroguesubtlety_use_feint")
menu.feint_energy_threshold              = core.menu.slider_int(20, 80, 40, "eaxroguesubtlety_feint_energy_threshold")
menu.use_evasion                         = core.menu.checkbox(true, "eaxroguesubtlety_use_evasion")
menu.evasion_hp_pct                      = core.menu.slider_int(0, 100, 40, "eaxroguesubtlety_evasion_hp_pct")
menu.use_cloak_of_shadows                = core.menu.checkbox(true, "eaxroguesubtlety_use_cloak_of_shadows")
menu.cloak_of_shadows_hp_pct             = core.menu.slider_int(0, 100, 30, "eaxroguesubtlety_cloak_of_shadows_hp_pct")
menu.use_vanish                          = core.menu.checkbox(true, "eaxroguesubtlety_use_vanish")
menu.vanish_hp_pct                       = core.menu.slider_int(0, 100, 20, "eaxroguesubtlety_vanish_hp_pct")
menu.use_distract                        = core.menu.checkbox(true, "eaxroguesubtlety_use_distract")
menu.use_sap                             = core.menu.checkbox(true, "eaxroguesubtlety_use_sap")
menu.use_gouge                           = core.menu.checkbox(true, "eaxroguesubtlety_use_gouge")
menu.use_kick                            = core.menu.checkbox(true, "eaxroguesubtlety_use_kick")
menu.use_blind                           = core.menu.checkbox(true, "eaxroguesubtlety_use_blind")
menu.use_sprint                          = core.menu.checkbox(true, "eaxroguesubtlety_use_sprint")
menu.use_shadowstep                      = core.menu.checkbox(true, "eaxroguesubtlety_use_shadowstep")
menu.use_cheap_shot                      = core.menu.checkbox(true, "eaxroguesubtlety_use_cheap_shot")
menu.use_kidney_shot                     = core.menu.checkbox(true, "eaxroguesubtlety_use_kidney_shot")
menu.use_expose_armor                    = core.menu.checkbox(true, "eaxroguesubtlety_use_expose_armor")
menu.use_deadly_poison                   = core.menu.checkbox(true, "eaxroguesubtlety_use_deadly_poison")
menu.use_instant_poison                  = core.menu.checkbox(true, "eaxroguesubtlety_use_instant_poison")
menu.use_wound_poison                    = core.menu.checkbox(true, "eaxroguesubtlety_use_wound_poison")
menu.use_crippling_poison                = core.menu.checkbox(true, "eaxroguesubtlety_use_crippling_poison")
menu.use_mind_numbing_poison             = core.menu.checkbox(true, "eaxroguesubtlety_use_mind_numbing_poison")
menu.use_stealth                         = core.menu.checkbox(true, "eaxroguesubtlety_use_stealth")
menu.use_premeditation                   = core.menu.checkbox(true, "eaxroguesubtlety_use_premeditation")
menu.use_cold_blood                      = core.menu.checkbox(true, "eaxroguesubtlety_use_cold_blood")

-- Subtlety-specific
menu.main_hand_poison = core.menu.combobox(1, "eaxroguesub_main_hand_poison")
menu.off_hand_poison = core.menu.combobox(1, "eaxroguesub_off_hand_poison")
menu.snd_refresh_seconds = core.menu.slider_int(1, 10, 3, "eaxroguesub_snd_refresh")
menu.finisher_combo_points = core.menu.slider_int(3, 5, 4, "eaxroguesub_finisher_cp")
menu.cd_min_ttd = core.menu.slider_int(0, 60, 0, "eaxroguesubtlety_cd_min_ttd")

-- Burst and Trinket settings
menu.auto_burst_enabled = core.menu.checkbox(false, "eaxroguesubtlety_auto_burst")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eaxroguesubtlety_burst_bloodlust")
menu.burst_on_pull = core.menu.checkbox(true, "eaxroguesubtlety_burst_pull")
menu.burst_on_execute = core.menu.checkbox(false, "eaxroguesubtlety_burst_execute")
menu.burst_in_combat = core.menu.checkbox(false, "eaxroguesubtlety_burst_combat")
menu.trinket1_mode = core.menu.combobox(1, "eaxroguesubtlety_trinket1_mode")
menu.trinket2_mode = core.menu.combobox(1, "eaxroguesubtlety_trinket2_mode")

-- Flux Energy & Swing Settings
menu.use_energy_tick = core.menu.checkbox(true, "eaxroguesubtlety_use_energy_tick")
menu.use_swing_delay = core.menu.checkbox(true, "eaxroguesubtlety_use_swing_delay")
menu.trinket_ttd = core.menu.slider_int(5, 30, 10, "eaxroguesubtlety_trinket_ttd")

-- Consumables
menu.use_healthstone  = core.menu.checkbox(true, "eaxroguesubtlety_use_healthstone")
menu.healthstone_hp_pct = core.menu.slider_int(10, 50, 30, "eaxroguesubtlety_healthstone_hp_pct")
menu.use_healing_potion = core.menu.checkbox(true, "eaxroguesubtlety_use_healing_potion")
menu.healing_potion_hp_pct = core.menu.slider_int(10, 50, 25, "eaxroguesubtlety_healing_potion_hp_pct")

-- Dashboard menu items
menu.show_dashboard         = core.menu.checkbox(true, "eaxroguesubtlety_show_dashboard")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxroguesubtlety_dashboard_opacity")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxroguesubtlety_dashboard_scale")
menu.dashboard_x            = core.menu.slider_int(0, 2000, 20, "eaxroguesubtlety_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 2000, 200, "eaxroguesubtlety_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxroguesubtlety_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxroguesubtlety_show_action_history")
menu.show_energy_tick = core.menu.checkbox(true, "eaxroguesubtlety_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(true, "eaxroguesubtlety_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxroguesubtlety_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxroguesubtlety_enable_smart_collapse")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_backstab", label = "Backstab" },
    { toggle = "use_rupture", label = "Rupture" },
    { toggle = "use_eviscerate", label = "Eviscerate" },
}, {
    namespace = "eaxroguesubtlety",
    log_prefix = "[Eax Rogue Sub] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxroguesubtlety")
    end

    root_tree:render("Eax's Rogue Subtlety", function()
        -- General section (inlined from ps.render_controls)
        ps.header("General")
        menu.enabled:render("Enabled", "Enable rotation")
        menu.toggle_key:render("Toggle Key", "Quick enable/disable")
        menu.mode:render("Mode", "Auto/PvE/PvP")
        menu.debug:render("Debug", "Show debug info")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_backstab:render("Backstab", "Main filler")
            menu.use_ambush:render("Ambush", "Stealth opener")
            menu.use_garrote:render("Garrote", "Opener")
            menu.use_rupture:render("Rupture", "Maintain")
            menu.use_hemorrhage:render("Hemorrhage", "Debuff")
            menu.use_eviscerate:render("Eviscerate", "Finisher")
            menu.use_slice_and_dice:render("Slice and Dice", "Buff")
            menu.use_feint:render("Feint", "Threat")
            menu.feint_energy_threshold:render("Feint Energy", "Above")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_preparation:render("Preparation", "Reset CDs")
            menu.use_premeditation:render("Premeditation", "Combo points")
            menu.use_cold_blood:render("Cold Blood", "Guaranteed crit")
            menu.cd_min_ttd:render("Min TTD for CDs", "Seconds (0 = disabled)")
            ps.header("Auto Burst")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst")
            menu.burst_on_bloodlust:render("Burst on Bloodlust", "Use CDs during bloodlust")
            menu.burst_on_pull:render("Burst on Pull", "Use CDs at combat start")
            menu.burst_on_execute:render("Burst on Execute", "Use CDs below 20% HP")
            menu.burst_in_combat:render("Burst in Combat", "Use CDs anytime in combat")
            ps.header("Trinkets")
            menu.trinket1_mode:render("Trinket 1", "Mode: Off/Offensive/Defensive")
            menu.trinket2_mode:render("Trinket 2", "Mode: Off/Offensive/Defensive")
            
            ps.header("Flux Settings")
            menu.use_energy_tick:render("Use Energy Tick", "Delay actions for energy tick optimization")
            menu.use_swing_delay:render("Use Swing Delay", "Delay actions before swing lands")
            menu.trinket_ttd:render("Trinket TTD", "Min target time-to-death for trinket use (sec)")
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

        -- Advanced section (Targeting + Racial + Leveling)
        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target")
            menu.combat_self_hp_boost:render("Self HP Boost", "HP% threshold for self-preservation")
            
            ps.header("Racial")
            menu.use_racial:render("Use Racial", "Use racial abilities")
            menu.racial_hp:render("Racial HP %", "HP threshold for defensive racials")
            
            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Resources", "Save resources while leveling")
            menu.leveling_mana_floor:render("Resource Floor %", "Minimum resource % to conserve")
        end)
    end)
end


return menu


