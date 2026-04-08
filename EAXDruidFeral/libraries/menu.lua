-- +--------------------------------------------------------------------------+
-- |  Eax Druid Feral  -  Menu  v2.0  -  menu.lua                             |
-- |                                                                          |
-- |  Using ps_theme for consistent EAX rotation UI                          |
-- +--------------------------------------------------------------------------+

local ps       = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")

local menu = {}

-- Lane options for form selection
local LANE_OPTIONS = { "Auto", "Cat", "Bear" }

-- Form Management controls (referenced in render)
menu.lane = core.menu.combobox(1, "eaxdruidferal_lane")
menu.auto_form = core.menu.checkbox(true, "eaxdruidferal_auto_form")
menu.shift_mana_floor = core.menu.slider_int(10, 50, 25, "eaxdruidferal_shift_mana_floor")

-- -- Tree nodes (declared outside render, as per API requirements) -------------
local root_tree     = ps.tree_node()
local rotation_tree = ps.tree_node()
local cat_tree      = ps.tree_node()
local bear_tree     = ps.tree_node()
local guardian_tree = ps.tree_node()
local shared_tree   = ps.tree_node()
local auto_tree     = ps.tree_node()
local ooc_tree      = ps.tree_node()
local group_tree    = ps.tree_node()
local def_tree      = ps.tree_node()
local tgt_tree      = ps.tree_node()
local racial_tree   = ps.tree_node()
local esp_tree      = ps.tree_node()
local middleware_tree = ps.tree_node()
local dashboard_tree  = ps.tree_node()
local pvp_tree        = ps.tree_node()
local burst_tree      = ps.tree_node()

-- -- Controls ------------------------------------------------------------------
menu.enabled         = core.menu.checkbox(true,  "eaxdruidferal_enabled")
menu.toggle_key      = core.menu.keybind(7, false, "eaxdruidferal_toggle_key")
menu.mode            = core.menu.combobox(1, "eaxdruidferal_mode")
menu.debug           = core.menu.checkbox(false, "eaxdruidferal_debug")

-- -- Targeting ------------------------------------------------------------------
menu.focus_priority        = core.menu.checkbox(false, "eaxdruidferal_focus_priority")
menu.combat_self_hp_boost  = core.menu.slider_int(0, 30, 10, "eaxdruidferal_combat_self_hp_boost")

-- -- Racial --------------------------------------------------------------------
menu.use_racial  = core.menu.checkbox(true, "eaxdruidferal_use_racial")
menu.racial_hp   = core.menu.slider_int(10, 80, 40, "eaxdruidferal_racial_hp")

-- -- Interrupt -----------------------------------------------------------------
menu.use_interrupt = core.menu.checkbox(true, "eaxdruidferal_use_interrupt")

-- -- OOC -----------------------------------------------------------------------
menu.ooc_drink        = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat          = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez          = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff   = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold  = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold    = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- -- OOC Buffs -----------------------------------------------------------------
menu.use_mark_of_the_wild = core.menu.checkbox(true, "eaxdruidferal_use_motw")
menu.use_cat_form = core.menu.checkbox(true, "eaxdruidferal_use_cat_form")

-- -- Automation ----------------------------------------------------------------
-- menu.auto_combat_potions = core.menu.checkbox(false, "eaxdruidferal_auto_combat_potions")
menu.auto_ooc_food_drink = core.menu.checkbox(true, "eaxdruidferal_auto_ooc_food_drink")
menu.auto_flask          = core.menu.checkbox(false, "eaxdruidferal_auto_flask")

-- -- Leveling ------------------------------------------------------------------
menu.leveling_conserve_mana = core.menu.checkbox(true, "eaxdruidferal_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxdruidferal_lev_mana_floor")

-- -- Cat Form ------------------------------------------------------------------
menu.use_prowl              = core.menu.checkbox(true, "eaxdruidferal_use_prowl")
menu.use_pounce             = core.menu.checkbox(true, "eaxdruidferal_use_pounce")
menu.use_ravage             = core.menu.checkbox(true, "eaxdruidferal_use_ravage")
menu.use_faerie_fire        = core.menu.checkbox(true, "eaxdruidferal_use_faerie_fire")
menu.use_likely_shred       = core.menu.checkbox(true, "eaxdruidferal_use_likely_shred")
menu.use_mangle_cat         = core.menu.checkbox(true, "eaxdruidferal_use_mangle_cat")
menu.use_rake               = core.menu.checkbox(true, "eaxdruidferal_use_rake")
menu.rake_refresh_seconds   = core.menu.slider_int(1, 10, 3, "eaxdruidferal_rake_refresh_seconds")
menu.use_shred              = core.menu.checkbox(true, "eaxdruidferal_use_shred")
menu.use_claw               = core.menu.checkbox(true, "eaxdruidferal_use_claw")
menu.use_rip                = core.menu.checkbox(true, "eaxdruidferal_use_rip")
menu.rip_combo_points       = core.menu.slider_int(1, 5, 4, "eaxdruidferal_rip_combo_points")
menu.rip_refresh_seconds    = core.menu.slider_int(1, 10, 3, "eaxdruidferal_rip_refresh_seconds")
menu.use_ferocious_bite     = core.menu.checkbox(true, "eaxdruidferal_use_ferocious_bite")
menu.bite_min_cp            = core.menu.slider_int(1, 5, 5, "eaxdruidferal_bite_min_cp")  
menu.bite_max_energy        = core.menu.slider_int(20, 60, 39, "eaxdruidferal_bite_max_energy")  
menu.use_bite_execute       = core.menu.checkbox(true, "eaxdruidferal_use_bite_execute")  
menu.use_bite_trick         = core.menu.checkbox(true, "eaxdruidferal_use_bite_trick")  
menu.bite_killshot_hp_pct   = core.menu.slider_int(5, 30, 15, "eaxdruidferal_bite_killshot_hp_pct")
menu.use_maim               = core.menu.checkbox(true, "eaxdruidferal_use_maim")


menu.cat_tick_optimization  = core.menu.checkbox(true, "eaxdruidferal_cat_tick_optimization")  -- Prefer Mangle over Shred when tick imminent
menu.use_rake_trick       = core.menu.checkbox(true, "eaxdruidferal_use_rake_trick")  
menu.use_wolfshead_shred_shift = core.menu.checkbox(true, "eaxdruidferal_use_wolfshead_shred_shift")  -- Wolfshead Shred Shift
menu.auto_powershift        = core.menu.checkbox(false, "eaxdruidferal_auto_powershift")  -- Auto powershift when energy low (BETA)
menu.powershift_min_mana    = core.menu.slider_int(10, 50, 20, "eaxdruidferal_powershift_min_mana")  -- Min mana % to powershift
menu.rip_only_elites        = core.menu.checkbox(false, "eaxdruidferal_rip_only_elites")  -- Only Rip elite/boss targets
menu.use_mangle_builder     = core.menu.checkbox(true, "eaxdruidferal_use_mangle_builder")  -- Use Mangle as CP builder
menu.enable_aoe             = core.menu.checkbox(true, "eaxdruidferal_enable_aoe")  -- Enable AoE rotation
menu.spread_rake            = core.menu.checkbox(false, "eaxdruidferal_spread_rake")  -- Spread Rake to nearby targets
menu.use_tigers_fury        = core.menu.checkbox(true, "eaxdruidferal_use_tigers_fury")
menu.tigers_fury_energy     = core.menu.slider_int(20, 60, 30, "eaxdruidferal_tigers_fury_energy")
menu.use_powershift         = core.menu.checkbox(false, "eaxdruidferal_use_powershift")

-- -- Bear Form -----------------------------------------------------------------
menu.use_mangle_bear        = core.menu.checkbox(true, "eaxdruidferal_use_mangle_bear")
menu.use_lacerate           = core.menu.checkbox(true, "eaxdruidferal_use_lacerate")
menu.use_demoralizing_roar  = core.menu.checkbox(true, "eaxdruidferal_use_demoralizing_roar")
menu.use_swipe              = core.menu.checkbox(true, "eaxdruidferal_use_swipe")
menu.swipe_enemy_count      = core.menu.slider_int(2, 8, 3, "eaxdruidferal_swipe_enemy_count")
menu.use_maul               = core.menu.checkbox(true, "eaxdruidferal_use_maul")
menu.maul_min_rage          = core.menu.slider_int(10, 50, 25, "eaxdruidferal_maul_min_rage")

-- -- Guardian ------------------------------------------------------------------
menu.use_frenzied_regeneration = core.menu.checkbox(true, "eaxdruidferal_use_frenzied_regeneration")
menu.frenzied_regeneration_hp_pct = core.menu.slider_int(10, 50, 25, "eaxdruidferal_frenzied_regeneration_hp_pct")
menu.auto_growl                = core.menu.checkbox(true, "eaxdruidferal_auto_growl")
menu.use_growl                 = core.menu.checkbox(true, "eaxdruidferal_use_growl")
menu.tank_cd_overlap           = core.menu.checkbox(false, "eaxdruidferal_tank_cd_overlap")
menu.use_enrage                = core.menu.checkbox(true, "eaxdruidferal_use_enrage")
menu.enrage_rage_threshold     = core.menu.slider_int(0, 40, 10, "eaxdruidferal_enrage_rage_threshold")
menu.use_challenging_roar      = core.menu.checkbox(true, "eaxdruidferal_use_challenging_roar")
menu.challenging_roar_party_hp_pct = core.menu.slider_int(10, 50, 25, "eaxdruidferal_challenging_roar_party_hp_pct")
menu.guardian_swipe_enemy_count = core.menu.slider_int(2, 8, 3, "eaxdruidferal_guardian_swipe_enemy_count")
menu.use_survival_instincts    = core.menu.checkbox(true, "eaxdruidferal_use_survival_instincts")

-- -- Shared / Utility ----------------------------------------------------------
menu.use_feral_charge       = core.menu.checkbox(true, "eaxdruidferal_use_feral_charge")
menu.use_travel_form        = core.menu.checkbox(true, "eaxdruidferal_use_travel_form")
menu.use_root_escape        = core.menu.checkbox(true, "eaxdruidferal_use_root_escape")
menu.use_bash               = core.menu.checkbox(true, "eaxdruidferal_use_bash")
menu.use_cyclone            = core.menu.checkbox(true, "eaxdruidferal_use_cyclone")
menu.use_entangling_roots   = core.menu.checkbox(true, "eaxdruidferal_use_entangling_roots")
menu.use_war_stomp          = core.menu.checkbox(true, "eaxdruidferal_use_war_stomp")
menu.war_stomp_hp_pct       = core.menu.slider_int(10, 50, 25, "eaxdruidferal_war_stomp_hp_pct")
menu.war_stomp_attackers    = core.menu.slider_int(2, 6, 3, "eaxdruidferal_war_stomp_attackers")

-- -- Defensive -----------------------------------------------------------------
menu.use_barkskin           = core.menu.checkbox(true, "eaxdruidferal_use_barkskin")
menu.barkskin_hp_pct        = core.menu.slider_int(10, 60, 30, "eaxdruidferal_barkskin_hp_pct")
menu.use_innervate          = core.menu.checkbox(true, "eaxdruidferal_use_innervate")
menu.innervate_mana_pct     = core.menu.slider_int(10, 60, 30, "eaxdruidferal_innervate_mana_pct")
menu.use_ooc_self_heal      = core.menu.checkbox(true, "eaxdruidferal_use_ooc_self_heal")
menu.ooc_self_heal_hp_pct   = core.menu.slider_int(20, 80, 50, "eaxdruidferal_ooc_self_heal_hp_pct")
menu.use_abolish_poison     = core.menu.checkbox(true, "eaxdruidferal_use_abolish_poison")
menu.use_remove_curse       = core.menu.checkbox(true, "eaxdruidferal_use_remove_curse")
menu.use_natures_grasp      = core.menu.checkbox(true, "eaxdruidferal_use_natures_grasp")
menu.use_thorns             = core.menu.checkbox(true, "eaxdruidferal_use_thorns")


menu.use_healthstone        = core.menu.checkbox(true, "eaxdruidferal_use_healthstone")
menu.healthstone_hp_pct     = core.menu.slider_int(10, 50, 30, "eaxdruidferal_healthstone_hp_pct")
menu.use_healing_potion     = core.menu.checkbox(true, "eaxdruidferal_use_healing_potion")
menu.healing_potion_hp_pct  = core.menu.slider_int(10, 60, 40, "eaxdruidferal_healing_potion_hp_pct")

-- Form Consumables (ported from Flux)
menu.use_form_consumables = core.menu.checkbox(true, "eaxdruidferal_use_form_consumables")
menu.use_form_healthstone = core.menu.checkbox(true, "eaxdruidferal_form_healthstone")
menu.form_healthstone_hp_pct = core.menu.slider_int(10, 50, 30, "eaxdruidferal_hs_hp_pct")
menu.use_form_healing_potion = core.menu.checkbox(true, "eaxdruidferal_form_potion")
menu.form_healing_potion_hp_pct = core.menu.slider_int(10, 50, 25, "eaxdruidferal_potion_hp_pct")


menu.show_dashboard         = core.menu.checkbox(true, "eaxdruidferal_show_dashboard")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxdruidferal_dashboard_opacity")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxdruidferal_dashboard_scale")
menu.dashboard_x            = core.menu.slider_int(0, 2000, 20, "eaxdruidferal_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 2000, 200, "eaxdruidferal_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxdruidferal_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxdruidferal_show_action_history")
menu.show_energy_tick = core.menu.checkbox(true, "eaxdruidferal_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(true, "eaxdruidferal_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxdruidferal_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxdruidferal_enable_smart_collapse")

-- -- PvP Settings ------------------------------------------------------------
menu.pvp_enabled            = core.menu.checkbox(true, "eaxdruidferal_pvp_enabled")
menu.pvp_mode               = core.menu.combobox(1, "eaxdruidferal_pvp_mode")
menu.pvp_use_trinket        = core.menu.checkbox(true, "eaxdruidferal_pvp_trinket")
menu.pvp_defensive_threshold = core.menu.slider_int(10, 80, 40, "eaxdruidferal_pvp_def_hp")
menu.pvp_entangling_roots   = core.menu.checkbox(true, "eaxdruidferal_pvp_entangling_roots")
menu.pvp_hibernate          = core.menu.checkbox(true, "eaxdruidferal_pvp_hibernate")

-- -- Burst / Trinket ---------------------------------------------------------
menu.auto_burst_enabled   = core.menu.checkbox(false, "eaxdruidferal_auto_burst")
menu.burst_on_bloodlust   = core.menu.checkbox(true, "eaxdruidferal_burst_bloodlust")
menu.burst_on_pull        = core.menu.checkbox(true, "eaxdruidferal_burst_pull")
menu.burst_on_execute     = core.menu.checkbox(true, "eaxdruidferal_burst_execute")
menu.burst_in_combat      = core.menu.checkbox(false, "eaxdruidferal_burst_combat")
menu.cd_min_ttd           = core.menu.slider_int(0, 60, 0, "eaxdruidferal_cd_min_ttd")
menu.trinket1_mode        = core.menu.combobox(1, "eaxdruidferal_trinket1_mode")
menu.trinket2_mode        = core.menu.combobox(1, "eaxdruidferal_trinket2_mode")
menu.trinket_ttd          = core.menu.slider_int(5, 30, 10, "eaxdruidferal_trinket_ttd")
menu.defensive_trinket_hp = core.menu.slider_int(15, 50, 35, "eaxdruidferal_def_trinket_hp")
menu.powershift_enabled   = core.menu.checkbox(true, "eaxdruidferal_powershift_enabled")

-- -- Window --------------------------------------------------------------------
settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_mangle_cat", label = "Mangle (Cat)" },
    { toggle = "use_shred", label = "Shred" },
    { toggle = "use_rip", label = "Rip" },
    { toggle = "use_mangle_bear", label = "Mangle (Bear)" },
    { toggle = "use_frenzied_regeneration", label = "Frenzied Regen" },
}, {
    namespace = "eaxdruidferal",
    log_prefix = "[Eax Feral] ",
})

local _win
function menu.set_window(win) _win = win end

-- -- RENDER --------------------------------------------------------------------
function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxdruidferal")
    end

    root_tree:render("Eax's Druid Feral", function()

        ps.render_controls(menu, "Eax's Druid Feral")

        -- Form Management
        rotation_tree:render("Form Management", function()
            ps.header("Shapeshifting")
            menu.lane:render("Active Lane", LANE_OPTIONS)
            menu.auto_form:render("Auto Form", "Automatically switch forms based on combat situation")
            menu.shift_mana_floor:render("Shift Mana Floor %", "Don't shift below this mana percent")
        end)

        -- Cat Form
        cat_tree:render("Cat Form", function()
            ps.header("Stealth")
            menu.use_prowl:render("Prowl", "Enter stealth when safe")
            menu.use_pounce:render("Pounce", "Stealth opener stun")
            menu.use_ravage:render("Ravage", "Stealth opener damage")

            ps.header("Builder")
            menu.use_faerie_fire:render("Faerie Fire (Feral)", "Armor reduction debuff")
            menu.use_likely_shred:render("Likely Shred", "Use Shred when behind target")
            menu.use_mangle_cat:render("Mangle (Cat)", "Maintain Mangle debuff")
            menu.use_rake:render("Rake", "Maintain Rake DoT")
            menu.rake_refresh_seconds:render("Rake Refresh (sec)", "Refresh Rake when remaining time is below this value")
            menu.use_shred:render("Shred", "Main damage when behind")
            menu.use_claw:render("Claw", "Combo point builder when Shred unavailable")

            ps.header("Finisher")
            menu.use_rip:render("Rip", "Maintain Rip DoT")
            menu.rip_combo_points:render("Rip Combo Points", "Minimum combo points for Rip")
            menu.rip_refresh_seconds:render("Rip Refresh (sec)", "Refresh Rip when remaining time is below this value")
            menu.use_ferocious_bite:render("Ferocious Bite", "Execute finisher")
            menu.bite_min_cp:render("Bite Min CP", "Minimum CP for Ferocious Bite ")
            menu.bite_max_energy:render("Bite Max Energy", "Don't FB above this energy to avoid waste")
            menu.use_bite_execute:render("Bite Execute Mode", "Use FB as execute on low HP/short TTD")
            menu.use_bite_trick:render("Bite Trick", "Low-energy FB dump in dead zone ")
            menu.bite_killshot_hp_pct:render("Killshot HP %", "Use Ferocious Bite below this target HP percent")
            menu.use_maim:render("Maim (interrupt)", "Use Maim as interrupt finisher")

            ps.header("Energy")
            menu.use_tigers_fury:render("Tiger's Fury", "Energy cooldown")
            menu.tigers_fury_energy:render("Tiger's Fury Energy", "Use Tiger's Fury below this energy")
            menu.cd_min_ttd:render("Min TTD for CDs", "Don't burst if target dies sooner (sec)")
            menu.use_powershift:render("Powershift (Wolfshead) [BETA]", "Powershift for energy with Wolfshead Helm - BETA feature")
            
            ps.header("Advanced (v1.9)")
            menu.cat_tick_optimization:render("Tick Optimization", "Prefer Mangle over Shred when tick imminent")
            menu.use_rake_trick:render("Rake Trick", "Use Rake Trick conditions")
            menu.use_wolfshead_shred_shift:render("Wolfshead Shred Shift", "Smart shift when Shred needed but energy low")
            menu.auto_powershift:render("Auto Powershift [BETA]", "Automatically powershift when energy is critically low - BETA feature")
            menu.powershift_min_mana:render("Powershift Min Mana %", "Don't powershift below this mana percent")
            menu.rip_only_elites:render("Rip Elites Only", "Only use Rip on elite or boss targets")
            menu.use_mangle_builder:render("Mangle Builder", "Use Mangle as combo point builder")
            menu.enable_aoe:render("Enable AoE", "Enable AoE rotation when multiple targets present")
            menu.spread_rake:render("Spread Rake", "Spread Rake DoT to nearby targets")
        end)

        -- Bear Form
        bear_tree:render("Bear Form", function()
            ps.header("Threat")
            menu.use_mangle_bear:render("Mangle (Bear)", "Main threat ability")
            menu.use_lacerate:render("Lacerate", "Maintain Lacerate stacks")
            menu.use_demoralizing_roar:render("Demoralizing Roar", "Attack power reduction")
            menu.use_swipe:render("Swipe", "AoE threat")
            menu.swipe_enemy_count:render("Swipe Enemy Count", "Use Swipe above this enemy count")
            menu.use_maul:render("Maul", "Rage dump")
            menu.maul_min_rage:render("Maul Min Rage", "Minimum rage to use Maul")
        end)

        -- Guardian
        guardian_tree:render("Guardian", function()
            ps.header("Defensive")
            menu.use_frenzied_regeneration:render("Frenzied Regen", "Self-heal cooldown")
            menu.frenzied_regeneration_hp_pct:render("Frenzied Regen HP %", "Use below this health percent")
            menu.auto_growl:render("Auto Growl", "Auto-taunt when losing threat")
            menu.tank_cd_overlap:render("Allow CD Overlap", "Allow defensive cooldowns to overlap")
            menu.use_enrage:render("Enrage", "Rage generation cooldown")
            menu.enrage_rage_threshold:render("Enrage Rage Threshold", "Use Enrage below this rage")
            menu.use_challenging_roar:render("Challenging Roar", "AoE taunt")
            menu.challenging_roar_party_hp_pct:render("Challenging Roar Party HP %", "Use when party members below this HP")
            menu.guardian_swipe_enemy_count:render("Guardian Swipe Count", "Swipe threshold in Guardian mode")
        end)

        -- Shared / Utility
        shared_tree:render("Shared / Utility", function()
            ps.header("Mobility")
            menu.use_feral_charge:render("Feral Charge / Dash", "Gap closer / escape")
            menu.use_travel_form:render("Travel Form OOC", "Use Travel Form when out of combat")
            menu.use_root_escape:render("Root Escape", "Shift to break roots")

            ps.header("CC")
            menu.use_bash:render("Bash", "Bear stun")
            menu.use_cyclone:render("Cyclone", "CC")
            menu.use_entangling_roots:render("Entangling Roots", "Root")
            menu.use_war_stomp:render("War Stomp (Tauren)", "Racial stun")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.war_stomp_hp_pct:render("War Stomp HP %", "Use below this HP")
            menu.war_stomp_attackers:render("War Stomp Attacker Count", "Use above this attacker count")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_barkskin:render("Barkskin", "Damage reduction cooldown")
            menu.barkskin_hp_pct:render("Barkskin HP %", "Use below this health percent")
            menu.use_innervate:render("Innervate", "Mana recovery")
            menu.innervate_mana_pct:render("Innervate Mana %", "Use below this mana percent")
            menu.use_ooc_self_heal:render("OOC Self-Heal", "Heal out of combat")
            menu.ooc_self_heal_hp_pct:render("OOC Self-Heal HP %", "Heal below this HP")
            menu.use_abolish_poison:render("Abolish Poison", "Dispel poison")
            menu.use_remove_curse:render("Remove Curse", "Dispel curse")
            menu.use_natures_grasp:render("Nature's Grasp", "Root on melee hit")
            menu.use_thorns:render("Thorns", "Auto-apply Thorns when missing (OOC)")
        end)

        
        middleware_tree:render("Middleware / Consumables", function()
            ps.header("Healthstone")
            menu.use_healthstone:render("Use Healthstone", "Auto-use healthstone when HP low (off-GCD)")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Use healthstone below this HP")
            
            ps.header("Healing Potion")
            menu.use_healing_potion:render("Use Healing Potion", "Auto-use healing potion when HP low (off-GCD)")
            menu.healing_potion_hp_pct:render("Potion HP %", "Use potion below this HP")

            ps.header("Form Consumables")
            menu.use_form_consumables:render("Use Form Consumables", "Auto-use consumables based on current form")
            menu.use_form_healthstone:render("Use Healthstone", "Use healthstone when low HP")
            menu.form_healthstone_hp_pct:render("Healthstone HP%", "HP threshold for healthstone")
            menu.use_form_healing_potion:render("Use Healing Potion", "Use potion when low HP")
            menu.form_healing_potion_hp_pct:render("Potion HP%", "HP threshold for potion")
        end)

        
        dashboard_tree:render("Dashboard", function()
            ps.header("Display")
            menu.show_dashboard:render("Show Dashboard", "Enable  combat dashboard")
            menu.dashboard_opacity:render("Opacity", "Dashboard background opacity")
            menu.dashboard_scale:render("Scale", "Dashboard UI scale")
            menu.dashboard_x:render("Position X", "Dashboard horizontal position")
            menu.dashboard_y:render("Position Y", "Dashboard vertical position")            
            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent spell casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
            menu.show_energy_tick:render("Energy Tick", "Show energy tick tracker")
            menu.show_combo_points:render("Combo Points", "Show combo point pips")
        end)

        -- Burst / Trinket Settings
        burst_tree:render("Burst / Trinket", function()
            ps.header("Burst Automation")
            menu.auto_burst_enabled:render("Auto Burst", "Automatically use burst cooldowns based on conditions")
            menu.burst_on_bloodlust:render("Burst on Bloodlust", "Use CDs when Bloodlust/Heroism is active")
            menu.burst_on_pull:render("Burst on Pull", "Use CDs at start of combat (first 5 sec)")
            menu.burst_on_execute:render("Burst on Execute", "Use CDs when target is below 20% HP")
            menu.burst_in_combat:render("Burst in Combat", "Use CDs whenever available in combat")
            menu.cd_min_ttd:render("Min TTD for CDs", "Don't burst if target dies sooner (seconds)")
            
            ps.header("Trinket Automation")
            menu.trinket1_mode:render("Trinket 1 Mode", {"Off", "Offensive", "Defensive"}, "Automation mode for top trinket slot")
            menu.trinket2_mode:render("Trinket 2 Mode", {"Off", "Offensive", "Defensive"}, "Automation mode for bottom trinket slot")
            menu.trinket_ttd:render("Offensive TTD Threshold", "Don't use offensive trinkets if target dies sooner (seconds)")
            menu.defensive_trinket_hp:render("Defensive HP Threshold", "Use defensive trinkets below this HP percent")
            
            ps.header("Powershift")
            menu.powershift_enabled:render("Enable Powershift", "Enable powershift automation with Flux library")
        end)

        -- PvP Settings
        pvp_tree:render("PvP", function()
            ps.header("General")
            menu.pvp_enabled:render("Enable PvP", "Enable PvP rotation features")
            menu.pvp_mode:render("PvP Mode", {"Auto", "PvE Only", "PvP Only"}, "Select PvP detection mode")
            menu.pvp_use_trinket:render("Use PvP Trinket", "Auto-use PvP trinket when CC'd")
            menu.pvp_defensive_threshold:render("Defensive Threshold %", "Use defensives below this HP% in PvP")
            
            ps.header("Crowd Control")
            menu.pvp_entangling_roots:render("Entangling Roots", "Root melee attackers in PvP")
            menu.pvp_hibernate:render("Hibernate", "Hibernate druids/shamans in beast forms")
        end)

        -- Targeting
        ps.render_targeting(menu, tgt_tree)

        -- Racial
        ps.render_racial(menu, racial_tree)

        -- Out-of-combat
        ooc_tree:render("Out of Combat", function()
            ps.header("Sustain")
            menu.ooc_drink:render("Auto-Drink", "Drink to restore mana when out of combat")
            menu.drink_threshold:render("Drink Threshold %", "Start drinking below this mana percent")
            menu.ooc_eat:render("Auto-Eat", "Eat food to restore health when out of combat")
            menu.eat_threshold:render("Eat Threshold %", "Start eating below this health percent")

            ps.header("Group")
            menu.ooc_rez:render("Auto-Resurrect", "Accept and cast resurrection when out of combat")
            menu.ooc_group_buff:render("Group Buffs", "Apply class buffs to party members between pulls")

            ps.header("Automation")
            menu.auto_ooc_food_drink:render("Auto OOC Food / Drink", "Use food and drink out of combat when health or mana is low")
            menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Use a more mana-efficient leveling rotation")
            menu.leveling_mana_floor:render("Mana Floor %", "Switch to conservation mode below this mana percent")
        end)

    end)
end

return menu


