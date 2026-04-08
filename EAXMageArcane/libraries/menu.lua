-- +------------------------------------------------------------------+
-- |  Eax's Mage Arcane
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+
local mana_conservator = require("libraries/mana_conservator")

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree    = ps.tree_node()
local rotation_tree = ps.tree_node()
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
menu.enabled                             = core.menu.checkbox(true, "eaxmagearcane_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxmagearcane_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxmagearcane_mode")
menu.debug                               = core.menu.checkbox(false, "eaxmagearcane_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxmagearcane_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxmagearcane_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxmagearcane_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxmagearcane_racial_hp")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxmagearcane_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxmagearcane_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxmagearcane_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxmagearcane_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxmagearcane_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxmagearcane_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxmagearcane_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxmagearcane_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxmagearcane_spirit_tap_wand")

-- Rotation
menu.use_arcane_blast                    = core.menu.checkbox(true, "eaxmagearcane_use_arcane_blast")
menu.use_arcane_missiles                 = core.menu.checkbox(true, "eaxmagearcane_use_arcane_missiles")
menu.use_arcane_surge                    = core.menu.checkbox(true, "eaxmagearcane_use_arcane_surge")
menu.use_evocation                       = core.menu.checkbox(true, "eaxmagearcane_use_evocation")
menu.use_missile_barrage                 = core.menu.checkbox(true, "eaxmagearcane_use_missile_barrage")
menu.use_presence_of_mind                = core.menu.checkbox(true, "eaxmagearcane_use_presence_of_mind")
menu.use_arcane_power                    = core.menu.checkbox(true, "eaxmagearcane_use_arcane_power")
menu.use_ice_barrier                     = core.menu.checkbox(true, "eaxmagearcane_use_ice_barrier")
menu.ice_barrier_hp_pct                  = core.menu.slider_int(0, 100, 40, "eaxmagearcane_ice_barrier_hp_pct")
menu.use_mage_armor                      = core.menu.checkbox(true, "eaxmagearcane_use_mage_armor")
menu.use_arcane_intellect                = core.menu.checkbox(true, "eaxmagearcane_use_arcane_intellect")
menu.use_conjure_food                    = core.menu.checkbox(true, "eaxmagearcane_use_conjure_food")
menu.use_conjure_water                   = core.menu.checkbox(true, "eaxmagearcane_use_conjure_water")
menu.use_polymorph                       = core.menu.checkbox(true, "eaxmagearcane_use_polymorph")
menu.use_blink                           = core.menu.checkbox(true, "eaxmagearcane_use_blink")
menu.use_counterspell                    = core.menu.checkbox(true, "eaxmagearcane_use_counterspell")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxmagearcane_remove_curse")
menu.use_interrupt                       = core.menu.checkbox(true, "eaxmagearcane_use_interrupt")

-- Dashboard
menu.show_dashboard         = core.menu.checkbox(true, "eaxmagearcane_show_dashboard")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxmagearcane_dashboard_opacity")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxmagearcane_dashboard_scale")
menu.dashboard_x            = core.menu.slider_int(0, 2000, 20, "eaxmagearcane_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 2000, 200, "eaxmagearcane_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxmagearcane_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxmagearcane_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxmagearcane_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxmagearcane_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxmagearcane_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxmagearcane_enable_smart_collapse")
menu.use_mana_gem                       = core.menu.checkbox(true, "eaxmagearcane_use_mana_gem")
menu.mana_gem_pct                       = core.menu.slider_int(5, 80, 30, "eaxmagearcane_mana_gem_pct")
menu.use_remove_curse                   = core.menu.checkbox(true, "eaxmagearcane_remove_curse")
menu.use_arcane_explosion               = core.menu.checkbox(true, "eaxmagearcane_use_arcane_explosion")
menu.use_arcane_power                   = core.menu.checkbox(true, "eaxmagearcane_use_arcane_power")
menu.burn_mana_pct                      = core.menu.slider_int(20, 80, 50, "eaxmagearcane_burn_mana_pct")
menu.use_trinkets                       = core.menu.checkbox(true, "eaxmagearcane_use_trinkets")
menu.use_arcane_missiles                = core.menu.checkbox(true, "eaxmagearcane_use_arcane_missiles")
menu.arcane_blast_dump_stacks           = core.menu.slider_int(1, 4, 3, "eaxmagearcane_ab_dump_stacks")
menu.evocation_pct                      = core.menu.slider_int(10, 50, 25, "eaxmagearcane_evocation_pct")
menu.use_fire_blast_move                = core.menu.checkbox(true, "eaxmagearcane_use_fire_blast_move")
menu.use_ice_block                      = core.menu.checkbox(true, "eaxmagearcane_use_ice_block")
menu.ice_block_hp_pct                   = core.menu.slider_int(0, 100, 30, "eaxmagearcane_ice_block_hp_pct")
menu.use_frost_nova                     = core.menu.checkbox(true, "eaxmagearcane_use_frost_nova")
menu.use_presence_of_mind               = core.menu.checkbox(true, "eaxmagearcane_use_presence_of_mind")
menu.use_cone_of_cold                   = core.menu.checkbox(true, "eaxmagearcane_use_cone_of_cold")

-- NEW: Arcane Phase Management (2 items)
menu.arcane_start_conserve_pct          = core.menu.slider_int(10, 50, 35, "eaxmagearcane_start_conserve_pct")
menu.arcane_stop_conserve_pct           = core.menu.slider_int(40, 90, 60, "eaxmagearcane_stop_conserve_pct")

-- NEW: Cooldown Settings (2 items)
menu.use_icy_veins                      = core.menu.checkbox(true, "eaxmagearcane_use_icy_veins")
menu.use_cold_snap                      = core.menu.checkbox(true, "eaxmagearcane_use_cold_snap")
menu.cd_min_ttd                         = core.menu.slider_int(0, 60, 0, "eaxmagearcane_cd_min_ttd")

-- NEW: AoE Settings (1 item)
menu.aoe_threshold                      = core.menu.slider_int(0, 10, 0, "eaxmagearcane_aoe_threshold")

-- NEW: Movement Spells (4 items)
menu.arcane_move_fire_blast             = core.menu.checkbox(true, "eaxmagearcane_move_fire_blast")
menu.arcane_move_ice_lance              = core.menu.checkbox(true, "eaxmagearcane_move_ice_lance")
menu.arcane_move_cone_of_cold           = core.menu.checkbox(true, "eaxmagearcane_move_cone_of_cold")
menu.arcane_move_arcane_explosion       = core.menu.checkbox(true, "eaxmagearcane_move_arcane_explosion")

-- NEW: Arcane Rotation Settings (2 items)
menu.arcane_blasts_between_fillers      = core.menu.slider_int(1, 5, 3, "eaxmagearcane_ab_between_fillers")
menu.arcane_filler                      = core.menu.combobox(1, "eaxmagearcane_filler")

-- PvP Settings
menu.pvp_enabled                        = core.menu.checkbox(true, "eaxmagearcane_pvp_enabled")
menu.pvp_mode                           = core.menu.combobox(1, "eaxmagearcane_pvp_mode")
menu.pvp_use_trinket                    = core.menu.checkbox(true, "eaxmagearcane_pvp_trinket")
menu.pvp_defensive_threshold            = core.menu.slider_int(10, 80, 40, "eaxmagearcane_pvp_def_hp")

-- NEW: Mana Management (5 items)
menu.use_mana_manager = core.menu.checkbox(true, "eaxmagearcane_use_mana_manager")
menu.mana_gem_pct = core.menu.slider_int(5, 100, 30, "eaxmagearcane_mana_gem_pct")
menu.mana_potion_pct = core.menu.slider_int(5, 100, 20, "eaxmagearcane_mana_potion_pct")
menu.dark_rune_pct = core.menu.slider_int(5, 100, 15, "eaxmagearcane_dark_rune_pct")
menu.evocation_pct = core.menu.slider_int(5, 100, 25, "eaxmagearcane_evocation_pct")

-- NEW: Burst & Trinket Automation (7 items)
menu.auto_burst_enabled = core.menu.checkbox(false, "eaxmagearcane_auto_burst")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eaxmagearcane_burst_bloodlust")
menu.burst_on_pull = core.menu.checkbox(true, "eaxmagearcane_burst_pull")
menu.burst_on_execute = core.menu.checkbox(true, "eaxmagearcane_burst_execute")
menu.burst_in_combat = core.menu.checkbox(false, "eaxmagearcane_burst_always")
menu.trinket1_mode = core.menu.combobox(1, "eaxmagearcane_trinket1_mode")
menu.trinket2_mode = core.menu.combobox(1, "eaxmagearcane_trinket2_mode")

-- NEW: Force Commands (Flux integration)
menu.force_burst = core.menu.keybind(0, false, "eaxmagearcane_force_burst")
menu.force_aoe = core.menu.keybind(0, false, "eaxmagearcane_force_aoe")
menu.force_defensive = core.menu.keybind(0, false, "eaxmagearcane_force_defensive")

mana_conservator.register_menu_items(menu, "eax_mage_arcane")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_arcane_blast", label = "Arcane Blast" },
    { toggle = "use_arcane_missiles", label = "Arcane Missiles" },
    { toggle = "use_evocation", label = "Evocation" },
    { toggle = "use_arcane_power", label = "Arcane Power" },
}, {
    namespace = "eaxmagearcane",
    log_prefix = "[Eax Mage Arcane] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxmagearcane")
    end

    root_tree:render("Eax's Mage Arcane", function()
        ps.render_controls(menu, "Eax's Mage Arcane")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Spells")
            menu.use_arcane_blast:render("Arcane Blast", "Main filler")
            menu.use_arcane_missiles:render("Arcane Missiles", "Proc filler")
            menu.use_arcane_surge:render("Arcane Surge", "Burst")
            menu.use_evocation:render("Evocation", "Mana recovery")
            menu.use_missile_barrage:render("Missile Barrage", "Proc")
            menu.use_mage_armor:render("Mage Armor", "Armor buff")
            menu.use_arcane_intellect:render("Arcane Intellect", "Int buff")
            menu.use_conjure_food:render("Conjure Food", "Create food")
            menu.use_conjure_water:render("Conjure Water", "Create water")
            menu.use_polymorph:render("Polymorph", "CC")
            menu.use_blink:render("Blink", "Escape")
            menu.use_counterspell:render("Counterspell", "Interrupt")
            menu.use_remove_curse:render("Remove Curse", "Dispel")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            ps.header("Arcane Phase")
            menu.arcane_start_conserve_pct:render("Start Conserve %", "Mana % to enter conserve")
            menu.arcane_stop_conserve_pct:render("Stop Conserve %", "Mana % to exit conserve")
            menu.burn_mana_pct:render("Burn Min Mana %", "Min mana for burn phase")
            menu.arcane_blasts_between_fillers:render("AB Stacks Before Filler", "Max AB casts in conserve")
            menu.arcane_blast_dump_stacks:render("AB Dump Stacks", "Stacks to dump with missiles")
            menu.arcane_filler:render("Filler Spell", {"Frostbolt", "Fireball", "Arcane Missiles", "Scorch"}, "Filler during conserve")
            ps.header("AoE")
            menu.aoe_threshold:render("AoE Threshold", "Min enemies for Arcane Explosion (0 = off)")
            menu.use_arcane_explosion:render("Arcane Explosion", "AoE spell")
            ps.header("Movement")
            menu.arcane_move_fire_blast:render("Fire Blast", "Use while moving")
            menu.arcane_move_ice_lance:render("Ice Lance", "Use while moving")
            menu.arcane_move_cone_of_cold:render("Cone of Cold", "Use while moving")
            menu.arcane_move_arcane_explosion:render("Arcane Explosion", "Use while moving (melee range)")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_presence_of_mind:render("Presence of Mind", "Instant cast")
            menu.use_arcane_power:render("Arcane Power", "DPS boost")
            menu.use_icy_veins:render("Icy Veins", "Haste buff")
            menu.use_cold_snap:render("Cold Snap", "Reset Icy Veins CD")
            menu.cd_min_ttd:render("Min TTD for CDs", "Seconds (0 = ignore)")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_ice_barrier:render("Ice Barrier", "Shield")
            menu.ice_barrier_hp_pct:render("Ice Barrier HP %", "Below")
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
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
        end)
ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end

return menu

