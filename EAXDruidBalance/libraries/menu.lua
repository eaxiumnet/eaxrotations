-- +------------------------------------------------------------------+
-- |  Eax's Druid Balance
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+
local mana_conservator = require("libraries/mana_conservator")

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree = ps.tree_node()
local rotation_tree = ps.tree_node()
local healing_tree = ps.tree_node()
local defensive_tree = ps.tree_node()
local utility_tree = ps.tree_node()
local buffs_tree = ps.tree_node()
local consumables_tree = ps.tree_node()
local pvp_tree = ps.tree_node()
local automation_tree = ps.tree_node()
local dashboard_tree = ps.tree_node()
local advanced_tree = ps.tree_node()

-- ALL menu declarations preserved VERBATIM from original file
-- -- Controls ------------------------------------------------------------------
menu.enabled                             = core.menu.checkbox(true, "eaxdruidbalance_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxdruidbalance_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxdruidbalance_mode")
menu.debug                               = core.menu.checkbox(false, "eaxdruidbalance_debug")

-- -- Targeting ----------------------------------------------------------------
menu.focus_priority                      = core.menu.checkbox(false, "eaxdruidbalance_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxdruidbalance_combat_self_hp_boost")

-- -- Racial --------------------------------------------------------------------
menu.use_racial                          = core.menu.checkbox(true, "eaxdruidbalance_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxdruidbalance_racial_hp")

-- -- OOC Buffs ----------------------------------------------------------------
menu.use_mark_of_the_wild = core.menu.checkbox(true, "eaxdruidbalance_use_motw")
menu.use_moonkin_form = core.menu.checkbox(true, "eaxdruidbalance_use_moonkin")
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
menu.auto_flask                         = core.menu.checkbox(false, "eaxdruidbalance_auto_flask")

-- -- Group ---------------------------------------------------------------------
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")

-- -- Automation ----------------------------------------------------------------
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxdruidbalance_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxdruidbalance_auto_ooc_food_drink")

-- -- Leveling ------------------------------------------------------------------
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxdruidbalance_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxdruidbalance_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxdruidbalance_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxdruidbalance_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxdruidbalance_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxdruidbalance_spirit_tap_wand")

-- -- Rotation - DPS -------------------------------------------------------------
menu.force_moonkin                        = core.menu.checkbox(true, "eaxdruidbalance_force_moonkin")
menu.use_faerie_fire                      = core.menu.checkbox(true, "eaxdruidbalance_use_faerie_fire")
menu.use_moonfire                         = core.menu.checkbox(true, "eaxdruidbalance_use_moonfire")
menu.use_insect_swarm                     = core.menu.checkbox(true, "eaxdruidbalance_use_insect_swarm")
menu.use_starfire                         = core.menu.checkbox(true, "eaxdruidbalance_use_starfire")
menu.use_wrath                            = core.menu.checkbox(true, "eaxdruidbalance_use_wrath")
menu.dot_refresh_seconds                  = core.menu.slider_int(1, 5, 3, "eaxdruidbalance_dot_refresh_seconds")
menu.use_force_of_nature                  = core.menu.checkbox(true, "eaxdruidbalance_use_force_of_nature")
menu.force_of_nature_min_ttd              = core.menu.slider_int(5, 30, 10, "eaxdruidbalance_fon_min_ttd")

-- -- Mana Tier System -------------------------------------------------------------
menu.bal_tier1_mana                       = core.menu.slider_int(10, 50, 20, "eaxdruidbalance_tier1_mana")
menu.bal_tier2_mana                       = core.menu.slider_int(5, 30, 10, "eaxdruidbalance_tier2_mana")

-- -- DoT Refresh & Nature's Grace --------------------------------------------------
menu.bal_dot_refresh                      = core.menu.slider_int(0, 5, 0, "eaxdruidbalance_dot_refresh")
menu.bal_ng_wrath                         = core.menu.checkbox(false, "eaxdruidbalance_ng_wrath")

-- -- Rotation - Healing/Emergency ------------------------------------------------
menu.use_innervate                        = core.menu.checkbox(true, "eaxdruidbalance_use_innervate")
menu.innervate_mana_pct                   = core.menu.slider_int(10, 60, 30, "eaxdruidbalance_innervate_mana_pct")
menu.use_tranquility                      = core.menu.checkbox(true, "eaxdruidbalance_use_tranquility")
menu.tranquility_hp_pct                   = core.menu.slider_int(20, 70, 35, "eaxdruidbalance_tranquility_hp_pct")

-- -- Rotation - AoE -------------------------------------------------------------
menu.use_hurricane                        = core.menu.checkbox(true, "eaxdruidbalance_use_hurricane")
menu.hurricane_min_targets                = core.menu.slider_int(2, 8, 4, "eaxdruidbalance_hurricane_min_targets")
menu.hurricane_mana_floor                 = core.menu.slider_int(10, 80, 40, "eaxdruidbalance_hurricane_mana_floor")

-- -- Utility -------------------------------------------------------------------
menu.use_root_escape                     = core.menu.checkbox(true, "eaxdruidbalance_root_escape")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxdruidbalance_remove_curse")
menu.use_interrupt                       = core.menu.checkbox(true, "eaxdruidbalance_use_interrupt")

-- -- Defensive -----------------------------------------------------------------
menu.use_barkskin                         = core.menu.checkbox(true, "eaxdruidbalance_use_barkskin")
menu.barkskin_hp_pct                      = core.menu.slider_int(0, 100, 30, "eaxdruidbalance_barkskin_hp_pct")
menu.use_thorns                           = core.menu.checkbox(true, "eaxdruidbalance_use_thorns")
menu.use_motw                             = core.menu.checkbox(true, "eaxdruidbalance_use_motw")

-- -- Middleware ----------------------------------------------------------------
menu.use_healthstone                      = core.menu.checkbox(true, "eaxdruidbalance_use_healthstone")
menu.healthstone_hp_pct                   = core.menu.slider_int(10, 50, 30, "eaxdruidbalance_healthstone_hp_pct")
menu.use_healing_potion                   = core.menu.checkbox(true, "eaxdruidbalance_use_healing_potion")
menu.consumable_health_threshold          = core.menu.slider_int(10, 50, 35, "eaxdruidbalance_consumable_threshold")
menu.health_potion_hp_pct                 = core.menu.slider_int(10, 60, 40, "eaxdruidbalance_health_potion_hp_pct")
menu.use_mana_potion                      = core.menu.checkbox(true, "eaxdruidbalance_use_mana_potion")
menu.mana_potion_pct                      = core.menu.slider_int(5, 30, 15, "eaxdruidbalance_mana_potion_pct")
menu.use_war_stomp                        = core.menu.checkbox(true, "eaxdruidbalance_use_war_stomp")

-- -- Mana Management -----------------------------------------------------------
menu.use_mana_manager = core.menu.checkbox(true, "eaxdruidbalance_use_mana_manager")
menu.innervate_pct = core.menu.slider_int(5, 100, 30, "eaxdruidbalance_innervate_pct")
menu.mana_potion_pct = core.menu.slider_int(5, 100, 20, "eaxdruidbalance_mana_potion_pct")
menu.dark_rune_pct = core.menu.slider_int(5, 100, 15, "eaxdruidbalance_dark_rune_pct")

-- -- Burst & Trinket Automation ------------------------------------------------
menu.auto_burst_enabled = core.menu.checkbox(false, "eaxdruidbalance_auto_burst")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eaxdruidbalance_burst_bloodlust")
menu.burst_on_pull = core.menu.checkbox(true, "eaxdruidbalance_burst_pull")
menu.burst_on_execute = core.menu.checkbox(true, "eaxdruidbalance_burst_execute")
menu.burst_in_combat = core.menu.checkbox(false, "eaxdruidbalance_burst_always")
menu.cd_min_ttd = core.menu.slider_int(0, 60, 0, "eaxdruidbalance_cd_min_ttd")
menu.trinket1_mode = core.menu.combobox(1, "eaxdruidbalance_trinket1_mode")
menu.trinket2_mode = core.menu.combobox(1, "eaxdruidbalance_trinket2_mode")

-- -- Flux Energy & Swing Settings -----------------------------------------------
menu.use_energy_tick = core.menu.checkbox(true, "eaxdruidbalance_use_energy_tick")
menu.use_swing_delay = core.menu.checkbox(true, "eaxdruidbalance_use_swing_delay")
menu.trinket_ttd = core.menu.slider_int(5, 30, 10, "eaxdruidbalance_trinket_ttd")

-- -- Dashboard -----------------------------------------------------------------
menu.show_dashboard                    = core.menu.checkbox(true, "eaxdruidbalance_dashboard_enabled")
menu.dashboard_opacity                    = core.menu.slider_int(50, 255, 190, "eaxdruidbalance_dashboard_opacity")
menu.dashboard_scale                      = core.menu.slider_float(0.5, 2.0, 1.0, "eaxdruidbalance_dashboard_scale")
menu.dashboard_x                          = core.menu.slider_int(0, 2000, 20, "eaxdruidbalance_dashboard_x")
menu.dashboard_y                          = core.menu.slider_int(0, 2000, 200, "eaxdruidbalance_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxdruidbalance_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxdruidbalance_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxdruidbalance_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxdruidbalance_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxdruidbalance_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxdruidbalance_enable_smart_collapse")

-- -- PvP Settings --------------------------------------------------------------
menu.pvp_enabled                          = core.menu.checkbox(true, "eaxdruidbalance_pvp_enabled")
menu.pvp_mode                             = core.menu.combobox(1, "eaxdruidbalance_pvp_mode")
menu.pvp_use_trinket                      = core.menu.checkbox(true, "eaxdruidbalance_pvp_trinket")
menu.pvp_defensive_threshold              = core.menu.slider_int(10, 80, 40, "eaxdruidbalance_pvp_def_hp")
menu.pvp_entangling_roots                 = core.menu.checkbox(true, "eaxdruidbalance_pvp_entangling_roots")
menu.pvp_hibernate                        = core.menu.checkbox(true, "eaxdruidbalance_pvp_hibernate")
menu.pvp_cyclone                          = core.menu.checkbox(true, "eaxdruidbalance_pvp_cyclone")

mana_conservator.register_menu_items(menu, "eax_druid_balance")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_moonfire", label = "Moonfire" },
    { toggle = "use_insect_swarm", label = "Insect Swarm" },
    { toggle = "use_force_of_nature", label = "Force of Nature" },
    { toggle = "use_hurricane", label = "Hurricane" },
    { toggle = "use_innervate", label = "Innervate" },
}, {
    namespace = "eaxdruidbalance",
    log_prefix = "[Eax Druid Balance] ",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxdruidbalance")
    end
    
    root_tree:render("Eax's Druid Balance", function()
        -- GENERAL (inline - was ps.render_controls)
        ps.header("General")
        menu.enabled:render("Enabled", "Enable/disable rotation")
        menu.mode:render("Mode", {"Auto", "PvE", "PvP"}, "Rotation mode")
        menu.toggle_key:render("Toggle Key", "Keybind to enable/disable")
        
        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Forms & Buffs")
            menu.force_moonkin:render("Force Moonkin Form", "Keep Moonkin Form active")
            menu.use_faerie_fire:render("Faerie Fire", "Maintain Faerie Fire on target")
            ps.header("Single Target")
            menu.use_moonfire:render("Moonfire", "Maintain Moonfire")
            menu.use_insect_swarm:render("Insect Swarm", "Maintain Insect Swarm")
            menu.use_starfire:render("Starfire", "Use as primary nuke")
            menu.use_wrath:render("Wrath", "Use when moving")
            menu.dot_refresh_seconds:render("Refresh Window (sec)", "Refresh DoTs when below")
            menu.bal_dot_refresh:render("DoT Refresh (sec)", "Refresh at <= seconds")
            menu.use_force_of_nature:render("Force of Nature", "Use treants during burst")
            menu.force_of_nature_min_ttd:render("Treants Min TTD", "Only if target lives this long")
            ps.header("Mana Tiers")
            menu.bal_tier1_mana:render("Tier 1 Mana %", "Full rotation above this")
            menu.bal_tier2_mana:render("Tier 2 Mana %", "Partial conserve below")
            ps.header("Nature's Grace")
            menu.bal_ng_wrath:render("NG = Wrath Priority", "When NG procs, cast Wrath")
            ps.header("AoE")
            menu.use_hurricane:render("Hurricane", "Channel on packs")
            menu.hurricane_min_targets:render("Min Targets", "Use above this")
            menu.hurricane_mana_floor:render("Mana Floor %", "Don't use below")
        end)
        
        -- Healing & Emergency
        healing_tree:render("Healing & Emergency", function()
            menu.use_innervate:render("Innervate", "Auto-use for mana")
            menu.innervate_mana_pct:render("Innervate Mana %", "Use below")
            menu.use_tranquility:render("Tranquility", "Emergency self-heal")
            menu.tranquility_hp_pct:render("Tranquility HP %", "Use below")
        end)
        
        -- Defensive
        defensive_tree:render("Defensive", function()
            menu.use_barkskin:render("Barkskin", "Damage reduction")
            menu.barkskin_hp_pct:render("Barkskin HP %", "Use below")
            menu.use_thorns:render("Thorns", "Auto-apply when missing (OOC)")
            menu.use_motw:render("Mark of the Wild", "Auto-apply when missing (OOC)")
        end)
        
        -- Utility
        utility_tree:render("Utility", function()
            menu.use_remove_curse:render("Remove Curse", "Dispel curses")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt casts")
        end)
        
        -- Buffs
        buffs_tree:render("Buffs", function()
            ps.header("Self Buffs (OOC)")
            menu.use_mark_of_the_wild:render("Mark of the Wild", "Stats buff")
            menu.use_moonkin_form:render("Moonkin Form", "Caster form")
            ps.header("Group Support")
            menu.ooc_rez:render("Auto-Resurrect", "Accept res OOC")
            menu.ooc_group_buff:render("Group Buffs", "Buff party between pulls")
        end)
        
        -- Consumables
        consumables_tree:render("Consumables", function()
            ps.header("Recovery Items")
            menu.use_healthstone:render("Healthstone", "Use when HP low")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Use below")
            menu.use_healing_potion:render("Healing Potion", "Use when HP low")
            menu.health_potion_hp_pct:render("Healing Potion HP %", "Use below")
            menu.use_mana_potion:render("Mana Potion", "Use when mana low")
            menu.mana_potion_pct:render("Mana Potion %", "Use below")
            ps.header("Sustain (OOC)")
            menu.ooc_drink:render("Auto-Drink", "Drink to restore mana")
            menu.drink_threshold:render("Drink Threshold %", "Start below")
            menu.ooc_eat:render("Auto-Eat", "Eat to restore health")
            menu.eat_threshold:render("Eat Threshold %", "Start below")
            menu.auto_ooc_food_drink:render("Auto Food/Drink", "Use OOC when low")
            menu.auto_flask:render("Auto Flask", "Maintain flask buff")
        end)
        
        -- PvP
        pvp_tree:render("PvP", function()
            ps.header("General")
            menu.pvp_enabled:render("Enable PvP", "Enable PvP features")
            menu.pvp_mode:render("PvP Mode", {"Auto", "PvE Only", "PvP Only"}, "Mode")
            menu.pvp_use_trinket:render("Use PvP Trinket", "Auto-use when CC'd")
            menu.pvp_defensive_threshold:render("Defensive Threshold %", "Use defensives below")
            ps.header("Crowd Control")
            menu.pvp_entangling_roots:render("Entangling Roots", "Root enemy players")
            menu.pvp_hibernate:render("Hibernate", "Sleep beasts")
            menu.pvp_cyclone:render("Cyclone", "Cyclone enemy players")
        end)
        
        -- Automation
        automation_tree:render("Automation", function()
            ps.header("Burst Cooldowns")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst")
            menu.burst_on_bloodlust:render("Burst on Bloodlust", "Use CDs during lust")
            menu.burst_on_pull:render("Burst on Pull", "Use at combat start")
            menu.burst_on_execute:render("Burst on Execute", "Use during execute")
            menu.burst_in_combat:render("Burst Always", "Use whenever available")
            menu.cd_min_ttd:render("Min TTD for CDs", "Don't burst if target dies sooner")
            ps.header("Trinkets")
            menu.trinket1_mode:render("Trinket 1 Mode", {"Auto", "Burst Only", "Off"}, "When to use")
            menu.trinket2_mode:render("Trinket 2 Mode", {"Auto", "Burst Only", "Off"}, "When to use")
            menu.trinket_ttd:render("Trinket TTD", "Min target TTD for use")
            ps.header("Mana Management")
            menu.use_mana_manager:render("Use Mana Manager", "Auto-use innervate/potions")
            menu.innervate_pct:render("Innervate Mana %", "Use below")
            menu.dark_rune_pct:render("Dark Rune %", "Use below")
        end)
        
        -- Dashboard
        dashboard_tree:render("Dashboard (Beta)", function()
            ps.header("Display")
            menu.show_dashboard:render("Show Dashboard", "Enable combat dashboard")
            menu.dashboard_opacity:render("Opacity", "Background opacity")
            menu.dashboard_scale:render("Scale", "UI scale")
            menu.dashboard_x:render("Position X", "Horizontal position")
            menu.dashboard_y:render("Position Y", "Vertical position")
            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
        end)
        
        -- Advanced (Targeting + Racial + Leveling)
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
            ps.header("Wand")
            menu.use_wand:render("Use Wand", "Wand low-HP enemies")
            menu.wand_mana_floor:render("Wand Mana %", "Use below")
            menu.wand_at_hp:render("Wand Target HP %", "Only below")
        end)
    end)
end

return menu
