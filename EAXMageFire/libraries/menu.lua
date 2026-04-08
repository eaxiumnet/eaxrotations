-- +------------------------------------------------------------------+
-- |  Eax's Mage Fire
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
menu.enabled                             = core.menu.checkbox(true, "eaxmagefire_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxmagefire_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxmagefire_mode")
menu.debug                               = core.menu.checkbox(false, "eaxmagefire_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxmagefire_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxmagefire_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxmagefire_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxmagefire_racial_hp")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxmagefire_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxmagefire_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxmagefire_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxmagefire_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxmagefire_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxmagefire_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxmagefire_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxmagefire_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxmagefire_spirit_tap_wand")

-- Rotation
menu.use_pyroblast                       = core.menu.checkbox(true, "eaxmagefire_use_pyroblast")
menu.use_fireball                        = core.menu.checkbox(true, "eaxmagefire_use_fireball")
menu.use_scorch                          = core.menu.checkbox(true, "eaxmagefire_use_scorch")
menu.use_combustion                      = core.menu.checkbox(true, "eaxmagefire_use_combustion")
menu.use_ignite                          = core.menu.checkbox(true, "eaxmagefire_use_ignite")
menu.use_fire_blast                      = core.menu.checkbox(true, "eaxmagefire_use_fire_blast")
menu.use_presence_of_mind                = core.menu.checkbox(true, "eaxmagefire_use_presence_of_mind")
menu.use_arcane_power                    = core.menu.checkbox(true, "eaxmagefire_use_arcane_power")
menu.use_evocation                       = core.menu.checkbox(true, "eaxmagefire_use_evocation")
menu.use_mage_armor                      = core.menu.checkbox(true, "eaxmagefire_use_mage_armor")
menu.use_arcane_intellect                = core.menu.checkbox(true, "eaxmagefire_use_arcane_intellect")
menu.use_conjure_food                    = core.menu.checkbox(true, "eaxmagefire_use_conjure_food")
menu.use_conjure_water                   = core.menu.checkbox(true, "eaxmagefire_use_conjure_water")
menu.use_polymorph                       = core.menu.checkbox(true, "eaxmagefire_use_polymorph")
menu.use_blink                           = core.menu.checkbox(true, "eaxmagefire_use_blink")
menu.use_counterspell                    = core.menu.checkbox(true, "eaxmagefire_use_counterspell")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxmagefire_remove_curse")
menu.use_interrupt                       = core.menu.checkbox(true, "eaxmagefire_use_interrupt")

-- Dashboard
menu.show_dashboard         = core.menu.checkbox(true, "eaxmagefire_show_dashboard")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxmagefire_dashboard_opacity")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxmagefire_dashboard_scale")
menu.dashboard_x            = core.menu.slider_int(0, 2000, 20, "eaxmagefire_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 2000, 200, "eaxmagefire_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxmagefire_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxmagefire_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxmagefire_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxmagefire_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxmagefire_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxmagefire_enable_smart_collapse")
menu.use_ice_barrier                     = core.menu.checkbox(true, "eaxmagefire_use_ice_barrier")
menu.ice_barrier_hp_pct                  = core.menu.slider_int(0, 100, 40, "eaxmagefire_ice_barrier_hp_pct")

-- Defensive (additional)
menu.use_ice_block                         = core.menu.checkbox(true, "eaxmagefire_use_ice_block")
menu.ice_block_hp_pct                      = core.menu.slider_int(0, 100, 30, "eaxmagefire_ice_block_hp_pct")

-- AoE
menu.use_flamestrike                       = core.menu.checkbox(true, "eaxmagefire_use_flamestrike")
menu.flamestrike_enemy_count               = core.menu.slider_int(2, 10, 3, "eaxmagefire_flamestrike_enemy_count")
menu.use_blast_wave                        = core.menu.checkbox(true, "eaxmagefire_use_blast_wave")
menu.use_dragons_breath                    = core.menu.checkbox(true, "eaxmagefire_use_dragons_breath")

-- Utility
menu.use_frost_nova                        = core.menu.checkbox(true, "eaxmagefire_use_frost_nova")
menu.use_fire_blast_move                   = core.menu.checkbox(true, "eaxmagefire_use_fire_blast_move")
menu.use_trinkets                          = core.menu.checkbox(true, "eaxmagefire_use_trinkets")

-- Scorch
menu.fire_maintain_scorch                = core.menu.checkbox(true, "eaxmagefire_fire_maintain_scorch")
menu.fire_scorch_refresh                 = core.menu.slider_int(1, 10, 6, "eaxmagefire_fire_scorch_refresh")

-- Cooldowns TTD
menu.cd_min_ttd                          = core.menu.slider_int(0, 60, 0, "eaxmagefire_cd_min_ttd")

-- Combustion HP threshold
menu.fire_combustion_below_hp            = core.menu.slider_int(0, 100, 0, "eaxmagefire_fire_combustion_below_hp")

-- Icy Veins
menu.use_icy_veins                       = core.menu.checkbox(true, "eaxmagefire_use_icy_veins")

-- Burst & Trinket Automation
menu.auto_burst_enabled                  = core.menu.checkbox(false, "eaxmagefire_auto_burst")
menu.burst_on_bloodlust                  = core.menu.checkbox(true, "eaxmagefire_burst_bloodlust")
menu.burst_on_pull                       = core.menu.checkbox(true, "eaxmagefire_burst_pull")
menu.burst_on_execute                    = core.menu.checkbox(true, "eaxmagefire_burst_execute")
menu.burst_in_combat                     = core.menu.checkbox(false, "eaxmagefire_burst_always")
menu.trinket1_mode                       = core.menu.combobox(1, "eaxmagefire_trinket1_mode")
menu.trinket2_mode                       = core.menu.combobox(1, "eaxmagefire_trinket2_mode")

-- Force Commands (Flux integration)
menu.force_burst = core.menu.keybind(0, false, "eaxmagefire_force_burst")
menu.force_aoe = core.menu.keybind(0, false, "eaxmagefire_force_aoe")
menu.force_defensive = core.menu.keybind(0, false, "eaxmagefire_force_defensive")

-- AoE Threshold
menu.fire_aoe_threshold                  = core.menu.slider_int(2, 10, 3, "eaxmagefire_fire_aoe_threshold")

-- Mana Gem
menu.use_mana_gem                        = core.menu.checkbox(true, "eaxmagefire_use_mana_gem")
menu.mana_gem_pct                        = core.menu.slider_int(5, 100, 30, "eaxmagefire_mana_gem_pct")

-- Evocation Threshold
menu.evocation_pct                       = core.menu.slider_int(5, 100, 25, "eaxmagefire_evocation_pct")

-- PvP Settings
menu.pvp_enabled                           = core.menu.checkbox(true, "eaxmagefire_pvp_enabled")
menu.pvp_mode                              = core.menu.combobox(1, "eaxmagefire_pvp_mode")
menu.pvp_use_trinket                       = core.menu.checkbox(true, "eaxmagefire_pvp_trinket")
menu.pvp_defensive_threshold               = core.menu.slider_int(10, 80, 40, "eaxmagefire_pvp_def_hp")

mana_conservator.register_menu_items(menu, "eax_mage_fire")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_fireball", label = "Fireball" },
    { toggle = "use_scorch", label = "Scorch" },
    { toggle = "use_fire_blast", label = "Fire Blast" },
    { toggle = "use_evocation", label = "Evocation" },
}, {
    namespace = "eaxmagefire",
    log_prefix = "[Eax Mage Fire] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxmagefire")
    end

    root_tree:render("Eax's Mage Fire", function()
        ps.render_controls(menu, "Eax's Mage Fire")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Spells")
            menu.use_pyroblast:render("Pyroblast", "Opener/proc")
            menu.use_fireball:render("Fireball", "Main filler")
            menu.use_scorch:render("Scorch", "Debuff")
            menu.use_combustion:render("Combustion", "Burst")
            menu.use_ignite:render("Ignite", "Proc")
            menu.use_fire_blast:render("Fire Blast", "Instant")
            menu.use_mage_armor:render("Mage Armor", "Armor buff")
            menu.use_arcane_intellect:render("Arcane Intellect", "Int buff")
            menu.use_conjure_food:render("Conjure Food", "Create food")
            menu.use_conjure_water:render("Conjure Water", "Create water")
            menu.use_polymorph:render("Polymorph", "CC")
            menu.use_blink:render("Blink", "Escape")
            menu.use_counterspell:render("Counterspell", "Interrupt")
            menu.use_remove_curse:render("Remove Curse", "Dispel")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
        -- Scorch
            ps.header("Scorch")
            menu.fire_maintain_scorch:render("Maintain Scorch", "Keep 5 stacks up")
            menu.fire_scorch_refresh:render("Scorch Refresh (s)", "Refresh window in seconds")
            menu.scorch_stack_target:render("Scorch Stack Target", "Stacks to maintain")
            menu.scorch_refresh_ms:render("Scorch Refresh MS", "Refresh window")
            ps.header("Utility")
            menu.use_frost_nova:render("Frost Nova", "Root melee")
            menu.use_fire_blast_move:render("Fire Blast (Moving)", "Instant while moving")
            menu.use_trinkets:render("Use Trinkets", "Auto-use trinkets")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            ps.header("Cooldowns")
            menu.use_presence_of_mind:render("Presence of Mind", "Instant cast")
            menu.use_arcane_power:render("Arcane Power", "DPS boost")
            menu.use_icy_veins:render("Icy Veins", "Haste boost")
            ps.header("Mana")
            menu.use_evocation:render("Evocation", "Mana recovery")
            menu.evocation_pct:render("Evocation Mana %", "Use below this %")
            menu.use_mana_gem:render("Use Mana Gem", "Auto-use mana gems")
            menu.mana_gem_pct:render("Mana Gem %", "Use below this %")
            ps.header("CD Settings")
            menu.cd_min_ttd:render("Min TTD for CDs (s)", "Don't use CDs if target dies sooner")
            menu.fire_combustion_below_hp:render("Combustion Below HP %", "Only use when target HP% below this (0=always)")
            ps.header("Burst Automation")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst CD usage")
            menu.burst_on_bloodlust:render("On Bloodlust", "Use CDs during Bloodlust/Heroism")
            menu.burst_on_pull:render("On Pull", "Use CDs in first 5s of combat")
            menu.burst_on_execute:render("On Execute", "Use CDs below 20% target HP")
            menu.burst_in_combat:render("Always in Combat", "Use CDs whenever in combat")
            ps.header("Trinket Automation")
            menu.trinket1_mode:render("Trinket 1", {"Off", "Offensive (Burst)", "Defensive"})
            menu.trinket2_mode:render("Trinket 2", {"Off", "Offensive (Burst)", "Defensive"})
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_ice_barrier:render("Ice Barrier", "Shield")
            menu.ice_barrier_hp_pct:render("Ice Barrier HP %", "Below")
            menu.use_ice_block:render("Ice Block", "Emergency immunity")
            menu.ice_block_hp_pct:render("Ice Block HP %", "Below")
        end)

        -- AoE
        cd_tree:render("AoE", function()
            menu.fire_aoe_threshold:render("AoE Enemy Threshold", "Min enemies for AoE abilities")
            menu.use_flamestrike:render("Flamestrike", "Ground AoE")
            menu.flamestrike_enemy_count:render("Flamestrike Min Enemies", "Count")
            menu.use_blast_wave:render("Blast Wave", "Instant AoE")
            menu.use_dragons_breath:render("Dragon's Breath", "Cone AoE")
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

