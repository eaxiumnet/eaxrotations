-- +--------------------------------------------------------------------------+
-- |  Eax Shaman Elemental  -  Menu  v2.0  -  menu.lua                        |
-- |                                                                          |
-- |  Using ps_theme for consistent EAX rotation UI                           |
-- +--------------------------------------------------------------------------+

local ps       = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")

local menu = {}

-- Tree nodes (Standard EAX Menu Structure)
local root_tree      = ps.tree_node()
local rotation_tree  = ps.tree_node()
local cooldowns_tree = ps.tree_node()
local totems_tree    = ps.tree_node()
local defensive_tree = ps.tree_node()
local buffs_tree     = ps.tree_node()
local utility_tree   = ps.tree_node()
local automation_tree = ps.tree_node()
local dashboard_tree = ps.tree_node()
local ooc_tree       = ps.tree_node()
local group_tree     = ps.tree_node()
local advanced_tree  = ps.tree_node()

-- Controls ------------------------------------------------------------------
menu.enabled                             = core.menu.checkbox(true, "eaxshamanelemental_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxshamanelemental_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxshamanelemental_mode")
menu.debug                               = core.menu.checkbox(false, "eaxshamanelemental_debug")
menu.shield_mode                         = core.menu.combobox(2, "eaxshamanelemental_shield_mode")
menu.use_healing_wave                    = core.menu.checkbox(true, "eaxshamanelemental_use_hw")
menu.healing_wave_hp                     = core.menu.slider_int(10, 60, 35, "eaxshamanelemental_hw_hp")
menu.use_ghost_wolf                      = core.menu.checkbox(true, "eaxshamanelemental_ghost_wolf")
menu.use_totemic_call                    = core.menu.checkbox(true, "eaxshamanelemental_totemic_call")
menu.use_dispels                         = core.menu.checkbox(false, "eaxshamanelemental_use_dispels")
menu.use_purge                           = core.menu.checkbox(false, "eaxshamanelemental_use_purge")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxshamanelemental_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxshamanelemental_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxshamanelemental_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxshamanelemental_racial_hp")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxshamanelemental_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxshamanelemental_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxshamanelemental_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxshamanelemental_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxshamanelemental_lev_mana_floor")

-- Rotation
menu.use_lightning_bolt                  = core.menu.checkbox(true, "eaxshamanelemental_use_lightning_bolt")
menu.use_chain_lightning                 = core.menu.checkbox(true, "eaxshamanelemental_use_chain_lightning")
menu.use_flame_shock                     = core.menu.checkbox(true, "eaxshamanelemental_use_flame_shock")
menu.use_earth_shock                     = core.menu.checkbox(true, "eaxshamanelemental_use_earth_shock")
menu.use_lava_burst                      = core.menu.checkbox(true, "eaxshamanelemental_use_lava_burst")
menu.use_frost_shock                     = core.menu.checkbox(true, "eaxshamanelemental_use_frost_shock")
menu.use_interrupt                       = core.menu.checkbox(true, "eaxshamanelemental_use_interrupt")

-- Cooldowns
menu.use_elemental_mastery               = core.menu.checkbox(true, "eaxshamanelemental_use_elemental_mastery")
menu.use_bloodlust                       = core.menu.checkbox(true, "eaxshamanelemental_use_bloodlust")
menu.use_heroism                         = core.menu.checkbox(true, "eaxshamanelemental_use_heroism")
menu.use_fire_elemental                  = core.menu.checkbox(true, "eaxshamanelemental_use_fire_elemental")
menu.use_astral_shift                    = core.menu.checkbox(true, "eaxshamanelemental_use_astral_shift")
menu.astral_shift_hp_pct                 = core.menu.slider_int(0, 100, 40, "eaxshamanelemental_astral_shift_hp_pct")

-- Burst & Trinket Automation
menu.auto_burst_enabled = core.menu.checkbox(false, "eaxshamanelemental_auto_burst")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eaxshamanelemental_burst_bloodlust")
menu.burst_on_pull = core.menu.checkbox(true, "eaxshamanelemental_burst_pull")
menu.burst_on_execute = core.menu.checkbox(true, "eaxshamanelemental_burst_execute")
menu.burst_in_combat = core.menu.checkbox(false, "eaxshamanelemental_burst_always")
menu.cd_min_ttd = core.menu.slider_int(0, 60, 0, "eaxshamanelemental_cd_min_ttd")
menu.trinket1_mode = core.menu.combobox(1, "eaxshamanelemental_trinket1_mode")
menu.trinket2_mode = core.menu.combobox(1, "eaxshamanelemental_trinket2_mode")

-- Totems - Fire
menu.use_searing_totem                   = core.menu.checkbox(true, "eaxshamanelemental_use_searing_totem")
menu.use_magma_totem                     = core.menu.checkbox(true, "eaxshamanelemental_use_magma_totem")
menu.use_fire_nova                       = core.menu.checkbox(true, "eaxshamanelemental_use_fire_nova")
menu.use_totem_of_wrath                  = core.menu.checkbox(true, "eaxshamanelemental_use_totem_of_wrath")
menu.auto_totem_wrath                   = core.menu.checkbox(true, "eaxshamanelemental_auto_totem_wrath")
menu.use_flametongue_totem               = core.menu.checkbox(true, "eaxshamanelemental_use_flametongue_totem")

-- Totems - Earth
menu.use_strength_of_earth_totem         = core.menu.checkbox(true, "eaxshamanelemental_use_strength_of_earth_totem")
menu.use_stoneskin_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_stoneskin_totem")
menu.use_grounding_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_grounding_totem")
menu.use_tremor_totem                    = core.menu.checkbox(true, "eaxshamanelemental_use_tremor_totem")
menu.use_earthgrab_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_earthgrab_totem")
menu.use_stoneclaw_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_stoneclaw_totem")
menu.use_stoneclaw_hp_pct                = core.menu.slider_int(0, 100, 40, "eaxshamanelemental_stoneclaw_hp_pct")
menu.use_earthbind_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_earthbind_totem")

-- Totems - Water
menu.use_mana_spring_totem               = core.menu.checkbox(true, "eaxshamanelemental_use_mana_spring_totem")
menu.use_mana_tide_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_mana_tide_totem")
menu.use_healing_stream_totem            = core.menu.checkbox(true, "eaxshamanelemental_use_healing_stream_totem")

-- Totems - Air
menu.use_windfury_totem                  = core.menu.checkbox(true, "eaxshamanelemental_use_windfury_totem")
menu.use_grace_of_air_totem              = core.menu.checkbox(true, "eaxshamanelemental_use_grace_of_air_totem")
menu.use_sentry_totem                    = core.menu.checkbox(true, "eaxshamanelemental_use_sentry_totem")

-- Totems - Recall
menu.use_totemic_recall                  = core.menu.checkbox(true, "eaxshamanelemental_use_totemic_recall")

-- Buffs - Shields
menu.use_water_shield                    = core.menu.checkbox(true, "eaxshamanelemental_use_water_shield")
menu.use_lightning_shield                = core.menu.checkbox(true, "eaxshamanelemental_use_lightning_shield")
menu.use_earth_shield                    = core.menu.checkbox(true, "eaxshamanelemental_use_earth_shield")

-- Utility
menu.use_water_breathing                 = core.menu.checkbox(true, "eaxshamanelemental_use_water_breathing")
menu.use_water_walking                   = core.menu.checkbox(true, "eaxshamanelemental_use_water_walking")
menu.use_ancestral_spirit                = core.menu.checkbox(true, "eaxshamanelemental_use_ancestral_spirit")
menu.use_reincarnation                   = core.menu.checkbox(true, "eaxshamanelemental_use_reincarnation")
menu.use_cure_poison                     = core.menu.checkbox(true, "eaxshamanelemental_use_cure_poison")
menu.use_cure_disease                    = core.menu.checkbox(true, "eaxshamanelemental_use_cure_disease")
menu.use_cleanse_spirit                  = core.menu.checkbox(true, "eaxshamanelemental_use_cleanse_spirit")
menu.use_hex                             = core.menu.checkbox(true, "eaxshamanelemental_use_hex")
menu.use_bind_elemental                  = core.menu.checkbox(true, "eaxshamanelemental_use_bind_elemental")
menu.use_wind_shear                      = core.menu.checkbox(true, "eaxshamanelemental_use_wind_shear")
menu.use_thunderstorm                    = core.menu.checkbox(true, "eaxshamanelemental_use_thunderstorm")
menu.use_spiritwalkers_grace             = core.menu.checkbox(true, "eaxshamanelemental_use_spiritwalkers_grace")

-- Defensive - Consumables
menu.use_healthstone  = core.menu.checkbox(true, "eaxshamanelemental_use_healthstone")
menu.healthstone_hp_pct = core.menu.slider_int(10, 50, 30, "eaxshamanelemental_healthstone_hp_pct")
menu.use_healing_potion = core.menu.checkbox(true, "eaxshamanelemental_use_healing_potion")
menu.healing_potion_hp_pct = core.menu.slider_int(10, 50, 25, "eaxshamanelemental_healing_potion_hp_pct")

-- Mana Management
menu.use_mana_manager = core.menu.checkbox(true, "eaxshamanelemental_use_mana_manager")
menu.mana_potion_pct = core.menu.slider_int(5, 100, 20, "eaxshamanelemental_mana_potion_pct")
menu.dark_rune_pct = core.menu.slider_int(5, 100, 15, "eaxshamanelemental_dark_rune_pct")

-- Dashboard
menu.show_dashboard         = core.menu.checkbox(true, "eaxshamanelemental_show_dashboard")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxshamanelemental_dashboard_opacity")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxshamanelemental_dashboard_scale")
menu.dashboard_x            = core.menu.slider_int(0, 2000, 20, "eaxshamanelemental_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 2000, 200, "eaxshamanelemental_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxshamanelemental_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxshamanelemental_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxshamanelemental_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxshamanelemental_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxshamanelemental_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxshamanelemental_enable_smart_collapse")

-- Settings Framework
settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_lightning_bolt", label = "Lightning Bolt" },
    { toggle = "use_chain_lightning", label = "Chain Lightning" },
    { toggle = "use_flame_shock", label = "Flame Shock" },
    { toggle = "use_earth_shock", label = "Earth Shock" },
}, {
    namespace = "eaxshamanelemental",
    log_prefix = "[Eax Shaman Ele] ",
})

local _win
function menu.set_window(win) _win = win end

-- RENDER --------------------------------------------------------------------
function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxshamanelemental")
    end

    root_tree:render("Eax's Shaman Elemental", function()

        -- 1. General - Visible immediately at top level
        ps.header("General")
        menu.enabled:render("Enabled", "Enable/disable rotation")
        menu.mode:render("Mode", {"Auto", "PvE", "PvP"}, "Rotation mode selection")
        menu.toggle_key:render("Toggle Key", "Keybind to enable/disable")
        menu.debug:render("Debug", "Enable debug output")

        -- 2. Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Spells")
            menu.use_lightning_bolt:render("Lightning Bolt", "Main filler spell")
            menu.use_chain_lightning:render("Chain Lightning", "AoE spell")
            menu.use_flame_shock:render("Flame Shock", "DoT maintenance")
            menu.use_earth_shock:render("Earth Shock", "Instant damage")
            menu.use_lava_burst:render("Lava Burst", "Proc-based burst")
            menu.use_frost_shock:render("Frost Shock", "Slow effect")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
        end)

        -- 3. Cooldowns
        cooldowns_tree:render("Cooldowns", function()
            ps.header("Major Cooldowns")
            menu.use_elemental_mastery:render("Elemental Mastery", "Instant cast burst")
            menu.use_bloodlust:render("Bloodlust", "Haste buff (Horde)")
            menu.use_heroism:render("Heroism", "Haste buff (Alliance)")
            menu.use_fire_elemental:render("Fire Elemental", "Summon pet")
            menu.use_astral_shift:render("Astral Shift", "Damage reduction")
            menu.astral_shift_hp_pct:render("Astral Shift HP %", "Use below this health")

            ps.header("Burst & Trinkets")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst detection")
            menu.burst_on_bloodlust:render("On Bloodlust", "Burst when Bloodlust/Heroism active")
            menu.burst_on_pull:render("On Pull", "Burst in first 5 seconds")
            menu.burst_on_execute:render("On Execute", "Burst below 20% HP")
            menu.burst_in_combat:render("Always in Combat", "Burst whenever available")
            menu.cd_min_ttd:render("Min TTD for CDs", "Don't burst if target dies sooner (sec)")
            menu.trinket1_mode:render("Trinket 1", {"Off", "Offensive", "Defensive"})
            menu.trinket2_mode:render("Trinket 2", {"Off", "Offensive", "Defensive"})
        end)

        -- 4. Totems
        totems_tree:render("Totems", function()
            ps.header("Fire Totems")
            menu.use_searing_totem:render("Searing Totem", "Single target damage")
            menu.use_magma_totem:render("Magma Totem", "AoE damage")
            menu.use_fire_nova:render("Fire Nova", "AoE burst")
            menu.use_totem_of_wrath:render("Totem of Wrath", "Spell crit buff")
            menu.auto_totem_wrath:render("Auto Totem of Wrath", "Auto-cast when missing")
            menu.use_flametongue_totem:render("Flametongue Totem", "Spell damage buff")

            ps.header("Earth Totems")
            menu.use_strength_of_earth_totem:render("Strength of Earth", "Stats buff")
            menu.use_stoneskin_totem:render("Stoneskin Totem", "Armor buff")
            menu.use_grounding_totem:render("Grounding Totem", "Spell absorb")
            menu.use_tremor_totem:render("Tremor Totem", "Fear/sleep/charm break")
            menu.use_earthgrab_totem:render("Earthgrab Totem", "Root enemies")
            menu.use_stoneclaw_totem:render("Stoneclaw Totem", "Damage absorb")
            menu.use_stoneclaw_hp_pct:render("Stoneclaw HP %", "Use below this health")
            menu.use_earthbind_totem:render("Earthbind Totem", "Slow enemies")

            ps.header("Water Totems")
            menu.use_mana_spring_totem:render("Mana Spring", "Mana regeneration")
            menu.use_mana_tide_totem:render("Mana Tide", "Mana restoration")
            menu.use_healing_stream_totem:render("Healing Stream", "Passive healing")

            ps.header("Air Totems")
            menu.use_windfury_totem:render("Windfury Totem", "Melee haste")
            menu.use_grace_of_air_totem:render("Grace of Air", "Agility buff")
            menu.use_sentry_totem:render("Sentry Totem", "Vision/Scout")

            ps.header("Totem Recall")
            menu.use_totemic_recall:render("Totemic Recall", "Recall all totems")
            menu.use_totemic_call:render("Totemic Call", "Alternative recall")
        end)

        -- 5. Defensive
        defensive_tree:render("Defensive", function()
            ps.header("Self-Healing")
            menu.use_healing_wave:render("Healing Wave", "Self-heal when low")
            menu.healing_wave_hp:render("Healing Wave HP %", "Use below this health")

            ps.header("Defensive Abilities")
            menu.use_thunderstorm:render("Thunderstorm", "Knockback + mana restore")
            menu.use_earthbind_totem:render("Earthbind Totem", "Kiting tool")

            ps.header("Emergency Consumables")
            menu.use_healthstone:render("Healthstone", "Auto-use when HP low")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Use below this HP")
            menu.use_healing_potion:render("Healing Potion", "Auto-use when HP low")
            menu.healing_potion_hp_pct:render("Potion HP %", "Use below this HP")
        end)

        -- 6. Buffs
        buffs_tree:render("Buffs", function()
            ps.header("Shields")
            menu.use_water_shield:render("Water Shield", "Mana regeneration")
            menu.use_lightning_shield:render("Lightning Shield", "Damage reflection")
            menu.use_earth_shield:render("Earth Shield", "Healing procs")
            menu.shield_mode:render("Shield Mode", {"Auto", "Water", "Lightning", "Earth"}, "Preferred shield type")
        end)

        -- 7. Utility
        utility_tree:render("Utility", function()
            ps.header("Movement")
            menu.use_ghost_wolf:render("Ghost Wolf", "Travel form")
            menu.use_water_walking:render("Water Walking", "Water travel")
            menu.use_spiritwalkers_grace:render("Spiritwalker's Grace", "Cast while moving")

            ps.header("Dispels & Purge")
            menu.use_dispels:render("Auto-Dispel", "Remove poisons/diseases")
            menu.use_purge:render("Purge", "Remove enemy buffs")
            menu.use_cure_poison:render("Cure Poison", "Poison dispel")
            menu.use_cure_disease:render("Cure Disease", "Disease dispel")
            menu.use_cleanse_spirit:render("Cleanse Spirit", "Curse dispel")

            ps.header("Crowd Control")
            menu.use_hex:render("Hex", "Transform enemy")
            menu.use_bind_elemental:render("Bind Elemental", "CC elementals")
            menu.use_wind_shear:render("Wind Shear", "Ranged interrupt")

            ps.header("Other")
            menu.use_water_breathing:render("Water Breathing", "Underwater breathing")
            menu.use_ancestral_spirit:render("Ancestral Spirit", "Resurrect others")
            menu.use_reincarnation:render("Reincarnation", "Self-resurrection")
        end)

        -- 8. Automation
        automation_tree:render("Automation", function()
            ps.header("Combat Automation")
            menu.auto_combat_potions:render("Combat Potions", "Auto-use in combat")
            menu.auto_flask:render("Auto Flask", "Maintain flask buff")

            ps.header("Mana Management")
            menu.use_mana_manager:render("Mana Manager", "Auto-use mana consumables")
            menu.mana_potion_pct:render("Mana Potion %", "Use below this mana")
            menu.dark_rune_pct:render("Dark Rune %", "Use below this mana")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Efficient rotation")
            menu.leveling_mana_floor:render("Mana Floor %", "Conservation threshold")
        end)

        -- 9. OOC Sustain
        ooc_tree:render("OOC Sustain", function()
            ps.header("Out of Combat")
            menu.ooc_drink:render("Auto-Drink", "Drink to restore mana")
            menu.drink_threshold:render("Drink Threshold %", "Start drinking below this mana")
            menu.ooc_eat:render("Auto-Eat", "Eat to restore health")
            menu.eat_threshold:render("Eat Threshold %", "Start eating below this HP")
            menu.auto_ooc_food_drink:render("Auto Food/Drink", "Automatic consumption")
        end)

        -- 10. Group
        group_tree:render("Group", function()
            ps.header("Group Support")
            menu.ooc_rez:render("Auto-Rez", "Accept and cast resurrection")
            menu.ooc_group_buff:render("Group Buffs", "Apply buffs to party")
        end)

        -- 11. Dashboard
        dashboard_tree:render("Dashboard", function()
            ps.header("Display")
            menu.show_dashboard:render("Show Dashboard", "Enable combat dashboard")
            menu.dashboard_opacity:render("Opacity", "Background opacity")
            menu.dashboard_scale:render("Scale", "UI scale")
            menu.dashboard_x:render("Position X", "Horizontal position")
            menu.dashboard_y:render("Position Y", "Vertical position")

            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and cast timers")
            menu.show_action_history:render("Action History", "Show recent spell casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
            menu.show_energy_tick:render("Energy Tick", "Show energy tick tracker")
            menu.show_combo_points:render("Combo Points", "Show combo point pips")
            menu.show_threat_bar:render("Threat Bar", "Show threat meter")
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
