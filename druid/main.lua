-- =============================================================================
-- DRUID MAIN ROTATION - SYLVANAS FRAMEWORK
-- Complete rewrite for Project Sylvanas with full menu system
-- Includes: Cat (Feral DPS), Bear (Tank), Balance (Moonkin), Resto (Healer)
-- Ported from Flux AIO with full strategy-based architecture
-- Version: 3.0.0
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local color = require("common/color")

-- ============================================================================
-- HOT-PATH API CACHING (EAX Pattern - cache at module load)
-- ============================================================================
local _core_time = core.time
local _core_game_time = core.game_time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

-- Load modules
local Constants = require("libraries/constants")
local Spells = require("libraries/spells")
local Utils = require("libraries/utils")
local Middleware = require("libraries/middleware")
local RotationEngine = require("libraries/rotation_engine")

-- Load spec rotations
local CatRotation = require("libraries/cat_rotation")
local BearRotation = require("libraries/bear_rotation")
local BalanceRotation = require("libraries/balance_rotation")
local RestoRotation = require("libraries/resto_rotation")

-- =============================================================================
-- MENU REGISTRATION
-- =============================================================================

local menu = {}

-- Main tree node
menu.main_node = core.menu.tree_node()

-- General Settings Node
menu.general_node = core.menu.tree_node()
menu.faerie_fire_targets = core.menu.combobox(1, "druid_faerie_fire_targets")
menu.use_barkskin = core.menu.checkbox(true, "druid_use_barkskin")
menu.barkskin_hp = core.menu.slider_int(15, 70, 40, "druid_barkskin_hp")
menu.use_healthstone = core.menu.checkbox(true, "druid_use_healthstone")
menu.healthstone_hp = core.menu.slider_int(15, 50, 30, "druid_healthstone_hp")
menu.use_healing_potion = core.menu.checkbox(true, "druid_use_healing_potion")
menu.healing_potion_hp = core.menu.slider_int(10, 40, 25, "druid_healing_potion_hp")
menu.use_mana_potion = core.menu.checkbox(true, "druid_use_mana_potion")
menu.mana_potion_mana = core.menu.slider_int(10, 50, 20, "druid_mana_potion_mana")
menu.use_racial = core.menu.checkbox(true, "druid_use_racial")
menu.use_innervate_self = core.menu.checkbox(true, "druid_use_innervate_self")
menu.innervate_mana = core.menu.slider_int(15, 50, 30, "druid_innervate_mana")
menu.rotation_toggle = core.menu.keybind(0, false, "druid_rotation_toggle")
menu.use_dark_rune = core.menu.checkbox(true, "druid_use_dark_rune")
menu.dark_rune_mana = core.menu.slider_int(10, 50, 30, "druid_dark_rune_mana")
menu.dark_rune_min_hp = core.menu.slider_int(20, 80, 40, "druid_dark_rune_min_hp")

-- Notification Settings
menu.show_notifications = core.menu.checkbox(true, "druid_show_notifications")
menu.notification_duration = core.menu.slider_float(0.5, 5.0, 1.5, "druid_notification_duration")

-- Cat (Feral DPS) Node
menu.cat_node = core.menu.tree_node()
menu.cat_maintain_rip = core.menu.checkbox(true, "druid_cat_maintain_rip")
menu.cat_rip_min_cp = core.menu.slider_int(4, 5, 4, "druid_cat_rip_min_cp")
menu.cat_rip_min_ttd = core.menu.slider_int(8, 30, 12, "druid_cat_rip_min_ttd")
menu.cat_maintain_rake = core.menu.checkbox(true, "druid_cat_maintain_rake")
menu.cat_rake_refresh = core.menu.slider_int(0, 3, 0, "druid_cat_rake_refresh")
menu.cat_fb_min_cp = core.menu.slider_int(1, 5, 5, "druid_cat_fb_min_cp")
menu.cat_fb_min_energy = core.menu.slider_int(25, 50, 35, "druid_cat_fb_min_energy")
menu.cat_fb_max_energy = core.menu.slider_int(30, 50, 39, "druid_cat_fb_max_energy")
menu.cat_fb_min_rip_duration = core.menu.slider_int(1, 8, 3, "druid_cat_fb_min_rip_duration")
menu.cat_bite_execute = core.menu.checkbox(true, "druid_cat_bite_execute")
menu.cat_bite_execute_hp = core.menu.slider_int(10, 35, 25, "druid_cat_bite_execute_hp")
menu.cat_bite_execute_ttd = core.menu.slider_int(3, 10, 6, "druid_cat_bite_execute_ttd")
menu.cat_auto_powershift = core.menu.checkbox(true, "druid_cat_auto_powershift")
menu.cat_powershift_min_mana = core.menu.slider_int(0, 90, 25, "druid_cat_powershift_min_mana")
menu.cat_use_mangle_builder = core.menu.checkbox(true, "druid_cat_use_mangle_builder")
menu.cat_tick_optimization = core.menu.checkbox(true, "druid_cat_tick_optimization")
menu.cat_use_bite_trick = core.menu.checkbox(true, "druid_cat_use_bite_trick")
menu.cat_use_rake_trick = core.menu.checkbox(true, "druid_cat_use_rake_trick")
menu.cat_use_tigers_fury = core.menu.checkbox(true, "druid_cat_use_tigers_fury")
menu.cat_tigers_fury_energy = core.menu.slider_int(20, 60, 40, "druid_cat_tigers_fury_energy")
menu.cat_rip_only_elites = core.menu.checkbox(false, "druid_cat_rip_only_elites")

-- Bear (Tank) Node
menu.bear_node = core.menu.tree_node()
menu.bear_no_taunt = core.menu.checkbox(false, "druid_bear_no_taunt")
menu.bear_use_growl = core.menu.checkbox(true, "druid_bear_use_growl")
menu.bear_use_challenging_roar = core.menu.checkbox(true, "druid_bear_use_challenging_roar")
menu.bear_croar_range = core.menu.slider_int(5, 20, 10, "druid_bear_croar_range")
menu.bear_croar_min_bosses = core.menu.slider_int(1, 3, 1, "druid_bear_croar_min_bosses")
menu.bear_croar_min_elites = core.menu.slider_int(1, 5, 3, "druid_bear_croar_min_elites")
menu.bear_maintain_lacerate = core.menu.checkbox(true, "druid_bear_maintain_lacerate")
menu.bear_lacerate_boss_only = core.menu.checkbox(false, "druid_bear_lacerate_boss_only")
menu.bear_maintain_demo_roar = core.menu.checkbox(true, "druid_bear_maintain_demo_roar")
menu.bear_demo_roar_range = core.menu.slider_int(5, 20, 10, "druid_bear_demo_roar_range")
menu.bear_demo_roar_min_bosses = core.menu.slider_int(1, 3, 1, "druid_bear_demo_roar_min_bosses")
menu.bear_demo_roar_min_elites = core.menu.slider_int(1, 5, 2, "druid_bear_demo_roar_min_elites")
menu.bear_demo_roar_min_trash = core.menu.slider_int(1, 10, 5, "druid_bear_demo_roar_min_trash")
menu.bear_use_frenzied_regen = core.menu.checkbox(true, "druid_bear_use_frenzied_regen")
menu.bear_emergency_heal_hp = core.menu.slider_int(15, 50, 30, "druid_bear_emergency_heal_hp")
menu.bear_use_enrage = core.menu.checkbox(true, "druid_bear_use_enrage")
menu.bear_enrage_rage_threshold = core.menu.slider_int(10, 40, 20, "druid_bear_enrage_rage_threshold")
menu.bear_maul_rage_threshold = core.menu.slider_int(15, 80, 25, "druid_bear_maul_rage_threshold")
menu.bear_mangle_rage_threshold = core.menu.slider_int(15, 40, 20, "druid_bear_mangle_rage_threshold")
menu.bear_swipe_rage_threshold = core.menu.slider_int(10, 40, 15, "druid_bear_swipe_rage_threshold")
menu.bear_swipe_min_targets = core.menu.slider_int(1, 4, 2, "druid_bear_swipe_min_targets")
menu.bear_swipe_cc_check = core.menu.checkbox(true, "druid_bear_swipe_cc_check")
menu.bear_enable_tab_targeting = core.menu.checkbox(true, "druid_bear_enable_tab_targeting")
menu.bear_tab_max_mobs = core.menu.slider_int(2, 8, 4, "druid_bear_tab_max_mobs")
menu.bear_tab_min_priority = core.menu.combobox(1, "druid_bear_tab_min_priority") -- all, elites, bosses

-- Balance (Moonkin) Node
menu.balance_node = core.menu.tree_node()
menu.bal_maintain_moonfire = core.menu.checkbox(true, "druid_bal_maintain_moonfire")
menu.bal_maintain_insect_swarm = core.menu.checkbox(true, "druid_bal_maintain_insect_swarm")
menu.bal_dot_refresh = core.menu.slider_int(0, 5, 0, "druid_bal_dot_refresh")
menu.bal_use_force_of_nature = core.menu.checkbox(true, "druid_bal_use_force_of_nature")
menu.bal_fon_min_ttd = core.menu.slider_int(5, 45, 15, "druid_bal_fon_min_ttd")
menu.bal_hurricane_min_targets = core.menu.slider_int(2, 5, 3, "druid_bal_hurricane_min_targets")
menu.bal_clearcast_starfire = core.menu.checkbox(true, "druid_bal_clearcast_starfire")
menu.bal_ng_wrath_priority = core.menu.checkbox(false, "druid_bal_ng_wrath_priority")
menu.bal_balance_use_innervate = core.menu.checkbox(true, "druid_bal_balance_use_innervate")
menu.bal_balance_innervate_mana = core.menu.slider_int(10, 50, 20, "druid_bal_balance_innervate_mana")
menu.bal_balance_tier1_mana = core.menu.slider_int(10, 50, 20, "druid_bal_balance_tier1_mana")
menu.bal_balance_tier2_mana = core.menu.slider_int(5, 30, 10, "druid_bal_balance_tier2_mana")

-- Caster / Resto Node
menu.caster_node = core.menu.tree_node()
menu.caster_use_motw = core.menu.checkbox(true, "druid_caster_use_motw")
menu.caster_use_thorns = core.menu.checkbox(true, "druid_caster_use_thorns")
menu.caster_use_ooc = core.menu.checkbox(true, "druid_caster_use_ooc")

-- Resto specific settings
menu.resto_prioritize_tank = core.menu.checkbox(true, "druid_resto_prioritize_tank")
menu.resto_emergency_hp = core.menu.slider_int(15, 45, 30, "druid_resto_emergency_hp")
menu.resto_swiftmend_hp = core.menu.slider_int(30, 70, 50, "druid_resto_swiftmend_hp")
menu.resto_standard_heal_hp = core.menu.slider_int(50, 95, 80, "druid_resto_standard_heal_hp")
menu.resto_proactive_hp = core.menu.slider_int(70, 99, 90, "druid_resto_proactive_hp")
menu.resto_lifebloom_refresh = core.menu.slider_int(1, 4, 2, "druid_resto_lifebloom_refresh")
menu.resto_mana_conserve = core.menu.slider_int(10, 60, 40, "druid_resto_mana_conserve")
menu.resto_auto_dispel_curse = core.menu.checkbox(true, "druid_resto_auto_dispel_curse")
menu.resto_auto_dispel_poison = core.menu.checkbox(true, "druid_resto_auto_dispel_poison")
menu.resto_ns_healing_touch = core.menu.checkbox(true, "druid_resto_ns_healing_touch")
menu.resto_use_rank_optimization = core.menu.checkbox(true, "druid_resto_use_rank_optimization")

-- =============================================================================
-- MENU RENDERING
-- =============================================================================

core.register_on_render_menu_callback(function()
    menu.main_node:render("Druid Rotations", function()
        -- General Settings
        menu.general_node:render("General", function()
            core.menu.header():render("Defensive Settings", color.green(200))
            menu.faerie_fire_targets:render("Faerie Fire Targets", {"All", "Elites+", "Bosses Only", "Off"}, "Which targets to maintain Faerie Fire on")
            menu.use_barkskin:render("Use Barkskin", "Enable automatic Barkskin usage when low HP")
            menu.barkskin_hp:render("Barkskin HP %", "HP threshold to cast Barkskin")
            
            core.menu.header():render("Consumables", color.green(200))
            menu.use_healthstone:render("Use Healthstone", "Automatically use Healthstone when low HP")
            menu.healthstone_hp:render("Healthstone HP %", "HP threshold to use Healthstone")
            menu.use_healing_potion:render("Use Healing Potion", "Automatically use Healing Potion when low HP")
            menu.healing_potion_hp:render("Healing Potion HP %", "HP threshold to use Healing Potion")
            menu.use_mana_potion:render("Use Mana Potion", "Automatically use Mana Potion when low mana")
            menu.mana_potion_mana:render("Mana Potion Mana %", "Mana threshold to use Mana Potion")
            menu.use_dark_rune:render("Use Dark Rune", "Automatically use Dark Rune/Demonic Rune for mana")
            menu.dark_rune_mana:render("Dark Rune Mana %", "Mana threshold to use Dark Rune")
            menu.dark_rune_min_hp:render("Dark Rune Min HP %", "Minimum HP required to safely use Dark Rune")

            core.menu.header():render("Utility", color.green(200))
            menu.use_racial:render("Use Racial Ability", "Enable automatic racial ability usage")
            menu.use_innervate_self:render("Innervate Self", "Automatically cast Innervate on self when low mana")
            menu.innervate_mana:render("Innervate Mana %", "Mana threshold to cast Innervate on self")
            
            core.menu.header():render("Rotation Control", color.green(200))
            menu.rotation_toggle:render("Rotation Toggle", "Keybind to enable/disable rotation")
            
            core.menu.header():render("UI & Notifications", color.green(200))
            menu.show_notifications:render("Show Notifications", "Display notifications for burst/defensive/gap actions")
            menu.notification_duration:render("Notification Duration (sec)", "How long notifications stay on screen")
        end)
        
        -- Cat (Feral DPS)
        menu.cat_node:render("Cat (Feral DPS)", function()
            core.menu.header():render("Finisher Settings", color.green(200))
            menu.cat_maintain_rip:render("Maintain Rip", "Use Rip as primary finisher")
            menu.cat_rip_min_cp:render("Rip Min Combo Points", "Minimum combo points to cast Rip")
            menu.cat_rip_min_ttd:render("Rip Min TTD (sec)", "Only Rip if target will live this long")
            menu.cat_rip_only_elites:render("Rip Elites/Bosses Only", "Skip Rip on normal mobs")
            menu.cat_fb_min_cp:render("Ferocious Bite Min CP", "Minimum combo points for Ferocious Bite")
            menu.cat_fb_min_energy:render("FB Min Energy", "Minimum energy for Ferocious Bite")
            menu.cat_fb_max_energy:render("FB Max Energy", "Maximum energy for Ferocious Bite (trick threshold)")
            menu.cat_fb_min_rip_duration:render("FB Min Rip Duration", "Only Bite if Rip has this much duration left")
            menu.cat_bite_execute:render("Bite Execute Mode", "Use Ferocious Bite in execute phase")
            menu.cat_bite_execute_hp:render("Bite Execute HP %", "Target HP % to switch to bite execute")
            menu.cat_bite_execute_ttd:render("Bite Execute TTD", "TTD threshold for bite execute")
            
            core.menu.header():render("DoT Settings", color.green(200))
            menu.cat_maintain_rake:render("Maintain Rake", "Keep Rake DoT on target")
            menu.cat_rake_refresh:render("Rake Refresh (sec)", "Refresh Rake when duration below this (0 = only when missing)")
            
            core.menu.header():render("Powershifting", color.green(200))
            menu.cat_auto_powershift:render("Auto Powershift", "Automatically powershift for energy")
            menu.cat_powershift_min_mana:render("Powershift Min Mana %", "Minimum mana % to allow powershift")
            menu.cat_tick_optimization:render("Tick Optimization", "Optimize builder choice around energy ticks")
            
            core.menu.header():render("Advanced", color.green(200))
            menu.cat_use_mangle_builder:render("Use Mangle Builder", "Use Mangle when behind target or energy low")
            menu.cat_use_bite_trick:render("Use Bite Trick", "Dump dead energy with FB 35-39 energy")
            menu.cat_use_rake_trick:render("Use Rake Trick", "Use Rake in dead zone when Mangle debuff active")
            menu.cat_use_tigers_fury:render("Use Tiger's Fury", "Enable Tiger's Fury usage")
            menu.cat_tigers_fury_energy:render("Tiger's Fury Energy Threshold", "Energy threshold to use Tiger's Fury")
        end)
        
        -- Bear (Tank)
        menu.bear_node:render("Bear (Feral Tank)", function()
            core.menu.header():render("Threat Settings", color.green(200))
            menu.bear_no_taunt:render("Disable Taunts / Off-Tank Mode", "Disable taunts when offtanking")
            menu.bear_use_growl:render("Auto Growl", "Automatically use Growl when losing aggro")
            menu.bear_use_challenging_roar:render("Auto Challenging Roar", "Use AoE taunt when multiple mobs loose")
            menu.bear_croar_range:render("Challenging Roar Range", "Range to check for loose mobs")
            menu.bear_croar_min_bosses:render("Challenging Roar Min Bosses", "Minimum loose bosses to trigger")
            menu.bear_croar_min_elites:render("Challenging Roar Min Elites", "Minimum loose elites to trigger")
            
            core.menu.header():render("Debuff Maintenance", color.green(200))
            menu.bear_maintain_lacerate:render("Maintain Lacerate", "Keep Lacerate stacked on target")
            menu.bear_lacerate_boss_only:render("Lacerate Boss Only", "Only maintain Lacerate on bosses")
            menu.bear_maintain_demo_roar:render("Maintain Demo Roar", "Keep Demoralizing Roar on enemies")
            menu.bear_demo_roar_range:render("Demo Roar Range", "Range to check for enemies")
            menu.bear_demo_roar_min_bosses:render("Demo Roar Min Bosses", "Minimum bosses to trigger")
            menu.bear_demo_roar_min_elites:render("Demo Roar Min Elites", "Minimum elites to trigger")
            menu.bear_demo_roar_min_trash:render("Demo Roar Min Trash", "Minimum trash mobs to trigger")
            
            core.menu.header():render("Defensive", color.green(200))
            menu.bear_use_frenzied_regen:render("Use Frenzied Regen", "Use Frenzied Regeneration when low HP")
            menu.bear_emergency_heal_hp:render("Emergency Heal HP %", "HP threshold for emergency heals")
            menu.bear_use_enrage:render("Use Enrage", "Use Enrage for free rage when safe")
            menu.bear_enrage_rage_threshold:render("Enrage Rage Threshold", "Rage threshold to use Enrage")
            
            core.menu.header():render("Rage Management", color.green(200))
            menu.bear_maul_rage_threshold:render("Maul Rage Threshold", "Minimum rage to queue Maul")
            menu.bear_mangle_rage_threshold:render("Mangle Rage Threshold", "Minimum rage to use Mangle")
            menu.bear_swipe_rage_threshold:render("Swipe Rage Threshold", "Minimum rage to use Swipe")
            menu.bear_swipe_min_targets:render("Swipe Min Targets", "Minimum enemies for Swipe AoE")
            menu.bear_swipe_cc_check:render("Swipe CC Safety", "Don't Swipe if breakable CC nearby")
            
            core.menu.header():render("Tab Targeting", color.green(200))
            menu.bear_enable_tab_targeting:render("Enable Tab Targeting", "Auto-switch targets for threat spread")
            menu.bear_tab_max_mobs:render("Max Mobs To Manage", "Maximum mobs to maintain threat on")
            menu.bear_tab_min_priority:render("Min Target Priority", {"All", "Elites+", "Bosses"}, "Minimum enemy priority to tab to")
        end)
        
        -- Balance (Moonkin)
        menu.balance_node:render("Balance (Moonkin)", function()
            core.menu.header():render("DoT Settings", color.green(200))
            menu.bal_maintain_moonfire:render("Maintain Moonfire", "Keep Moonfire DoT on target")
            menu.bal_maintain_insect_swarm:render("Maintain Insect Swarm", "Keep Insect Swarm DoT on target")
            menu.bal_dot_refresh:render("DoT Refresh Threshold (sec)", "Refresh DoTs when duration below this")
            
            core.menu.header():render("Cooldowns", color.green(200))
            menu.bal_use_force_of_nature:render("Use Force of Nature", "Summon treants on cooldown")
            menu.bal_fon_min_ttd:render("Treants Min TTD (sec)", "Only summon if target will live this long")
            
            core.menu.header():render("AoE & Rotation", color.green(200))
            menu.bal_hurricane_min_targets:render("Hurricane Min Targets", "Minimum enemies to cast Hurricane")
            menu.bal_clearcast_starfire:render("Clearcast Starfire", "Prioritize Starfire when Clearcasting")
            menu.bal_ng_wrath_priority:render("NG = Wrath Priority", "Cast Wrath during Nature's Grace proc")
            menu.bal_balance_use_innervate:render("Use Innervate", "Enable Innervate usage in Moonkin")
            menu.bal_balance_innervate_mana:render("Innervate Mana %", "Mana threshold for Innervate")
            
            core.menu.header():render("Mana Tiers", color.green(200))
            menu.bal_balance_tier1_mana:render("Tier 1 Mana %", "Full rotation above this mana %")
            menu.bal_balance_tier2_mana:render("Tier 2 Mana %", "Reduced DoTs above this mana %")
        end)
        
        -- Caster / Resto
        menu.caster_node:render("Caster / Resto", function()
            core.menu.header():render("Self Buffs", color.green(200))
            menu.caster_use_motw:render("Use Mark of the Wild", "Keep Mark of the Wild buff active")
            menu.caster_use_thorns:render("Use Thorns", "Keep Thorns buff active")
            menu.caster_use_ooc:render("Use Omen of Clarity", "Keep Omen of Clarity buff active")
            
            core.menu.header():render("Healing", color.green(200))
            menu.resto_prioritize_tank:render("Prioritize Tank", "Prioritize healing on tank role")
            menu.resto_emergency_hp:render("Emergency HP %", "HP threshold for emergency heals")
            menu.resto_swiftmend_hp:render("Swiftmend HP %", "HP threshold for Swiftmend usage")
            menu.resto_standard_heal_hp:render("Standard Heal HP %", "HP threshold for Regrowth healing")
            menu.resto_proactive_hp:render("Proactive HP %", "HP threshold for Rejuvenation spreading")
            menu.resto_lifebloom_refresh:render("Lifebloom Refresh (sec)", "Refresh Lifebloom when duration below this")
            menu.resto_mana_conserve:render("Mana Conserve %", "Only use expensive heals above this mana threshold")
            
            core.menu.header():render("Dispel", color.green(200))
            menu.resto_auto_dispel_curse:render("Auto Dispel Curse", "Remove curses from party members")
            menu.resto_auto_dispel_poison:render("Auto Dispel Poison", "Remove poisons from party members")
            
            core.menu.header():render("Advanced", color.green(200))
            menu.resto_ns_healing_touch:render("Use NS+Healing Touch", "Enable NS+HT emergency combo (leaves Tree)")
            menu.resto_use_rank_optimization:render("Smart Spell Ranks", "Automatically select optimal heal rank")
        end)
    end)
end)

-- =============================================================================
-- CONTEXT BUILDER
-- =============================================================================

local function build_context()
    local me = izi.me()
    if not me or not me:is_valid() then return nil end
    
    -- Check rotation toggle
    if not menu.rotation_toggle:get_toggle_state() then return nil end
    
    local target = izi.target()
    local stance = Utils.get_stance()
    local in_combat = me:time_in_combat() > 0
    
    -- Build settings table
    local settings = {
        -- General
        maintain_faerie_fire = (menu.faerie_fire_targets and menu.faerie_fire_targets:get()) or 1,
        use_barkskin = (menu.use_barkskin and menu.use_barkskin:get_state()) or true,
        barkskin_hp = (menu.barkskin_hp and menu.barkskin_hp:get()) or 40,
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or true,
        healthstone_hp = (menu.healthstone_hp and menu.healthstone_hp:get()) or 30,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get_state()) or true,
        healing_potion_hp = (menu.healing_potion_hp and menu.healing_potion_hp:get()) or 25,
        use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get_state()) or true,
        mana_potion_mana = (menu.mana_potion_mana and menu.mana_potion_mana:get()) or 20,
        use_racial = (menu.use_racial and menu.use_racial:get_state()) or true,
        use_innervate_self = (menu.use_innervate_self and menu.use_innervate_self:get_state()) or true,
        innervate_mana = (menu.innervate_mana and menu.innervate_mana:get()) or 30,
        use_dark_rune = (menu.use_dark_rune and menu.use_dark_rune:get_state()) or true,
        dark_rune_mana = (menu.dark_rune_mana and menu.dark_rune_mana:get()) or 30,
        dark_rune_min_hp = (menu.dark_rune_min_hp and menu.dark_rune_min_hp:get()) or 40,
        
        -- Cat
        maintain_rip = (menu.cat_maintain_rip and menu.cat_maintain_rip:get_state()) or true,
        rip_min_cp = (menu.cat_rip_min_cp and menu.cat_rip_min_cp:get()) or 4,
        rip_min_ttd = (menu.cat_rip_min_ttd and menu.cat_rip_min_ttd:get()) or 12,
        rip_only_elites = (menu.cat_rip_only_elites and menu.cat_rip_only_elites:get_state()) or false,
        rip_refresh = 3,
        maintain_rake = (menu.cat_maintain_rake and menu.cat_maintain_rake:get_state()) or true,
        rake_refresh = (menu.cat_rake_refresh and menu.cat_rake_refresh:get()) or 0,
        fb_min_cp = (menu.cat_fb_min_cp and menu.cat_fb_min_cp:get()) or 5,
        fb_min_energy = (menu.cat_fb_min_energy and menu.cat_fb_min_energy:get()) or 35,
        fb_max_energy = (menu.cat_fb_max_energy and menu.cat_fb_max_energy:get()) or 39,
        fb_min_rip_duration = (menu.cat_fb_min_rip_duration and menu.cat_fb_min_rip_duration:get()) or 3,
        use_bite_execute = (menu.cat_bite_execute and menu.cat_bite_execute:get_state()) or true,
        bite_execute_hp = (menu.cat_bite_execute_hp and menu.cat_bite_execute_hp:get()) or 25,
        bite_execute_ttd = (menu.cat_bite_execute_ttd and menu.cat_bite_execute_ttd:get()) or 6,
        auto_powershift = (menu.cat_auto_powershift and menu.cat_auto_powershift:get_state()) or true,
        powershift_min_mana = (menu.cat_powershift_min_mana and menu.cat_powershift_min_mana:get()) or 25,
        use_mangle_builder = (menu.cat_use_mangle_builder and menu.cat_use_mangle_builder:get_state()) or true,
        cat_tick_optimization = (menu.cat_tick_optimization and menu.cat_tick_optimization:get_state()) or true,
        use_bite_trick = (menu.cat_use_bite_trick and menu.cat_use_bite_trick:get_state()) or true,
        use_rake_trick = (menu.cat_use_rake_trick and menu.cat_use_rake_trick:get_state()) or true,
        use_tigers_fury = (menu.cat_use_tigers_fury and menu.cat_use_tigers_fury:get_state()) or true,
        tigers_fury_energy = (menu.cat_tigers_fury_energy and menu.cat_tigers_fury_energy:get()) or 40,
        
        -- Bear
        bear_no_taunt = (menu.bear_no_taunt and menu.bear_no_taunt:get_state()) or false,
        use_growl = (menu.bear_use_growl and menu.bear_use_growl:get_state()) or true,
        use_challenging_roar = (menu.bear_use_challenging_roar and menu.bear_use_challenging_roar:get_state()) or true,
        croar_range = (menu.bear_croar_range and menu.bear_croar_range:get()) or 10,
        croar_min_bosses = (menu.bear_croar_min_bosses and menu.bear_croar_min_bosses:get()) or 1,
        croar_min_elites = (menu.bear_croar_min_elites and menu.bear_croar_min_elites:get()) or 3,
        maintain_lacerate = (menu.bear_maintain_lacerate and menu.bear_maintain_lacerate:get_state()) or true,
        lacerate_boss_only = (menu.bear_lacerate_boss_only and menu.bear_lacerate_boss_only:get_state()) or false,
        maintain_demo_roar = (menu.bear_maintain_demo_roar and menu.bear_maintain_demo_roar:get_state()) or true,
        demo_roar_range = (menu.bear_demo_roar_range and menu.bear_demo_roar_range:get()) or 10,
        demo_roar_min_bosses = (menu.bear_demo_roar_min_bosses and menu.bear_demo_roar_min_bosses:get()) or 1,
        demo_roar_min_elites = (menu.bear_demo_roar_min_elites and menu.bear_demo_roar_min_elites:get()) or 2,
        demo_roar_min_trash = (menu.bear_demo_roar_min_trash and menu.bear_demo_roar_min_trash:get()) or 5,
        use_frenzied_regen = (menu.bear_use_frenzied_regen and menu.bear_use_frenzied_regen:get_state()) or true,
        emergency_heal_hp = (menu.bear_emergency_heal_hp and menu.bear_emergency_heal_hp:get()) or 30,
        use_enrage = (menu.bear_use_enrage and menu.bear_use_enrage:get_state()) or true,
        enrage_rage_threshold = (menu.bear_enrage_rage_threshold and menu.bear_enrage_rage_threshold:get()) or 20,
        maul_rage_threshold = (menu.bear_maul_rage_threshold and menu.bear_maul_rage_threshold:get()) or 25,
        mangle_rage_threshold = (menu.bear_mangle_rage_threshold and menu.bear_mangle_rage_threshold:get()) or 20,
        swipe_rage_threshold = (menu.bear_swipe_rage_threshold and menu.bear_swipe_rage_threshold:get()) or 15,
        swipe_min_targets = (menu.bear_swipe_min_targets and menu.bear_swipe_min_targets:get()) or 2,
        swipe_cc_check = (menu.bear_swipe_cc_check and menu.bear_swipe_cc_check:get_state()) or true,
        enable_tab_targeting = (menu.bear_enable_tab_targeting and menu.bear_enable_tab_targeting:get_state()) or true,
        tab_max_mobs = (menu.bear_tab_max_mobs and menu.bear_tab_max_mobs:get()) or 4,
        tab_min_priority = (menu.bear_tab_min_priority and menu.bear_tab_min_priority:get()) or 1,
        
        -- Balance
        maintain_moonfire = (menu.bal_maintain_moonfire and menu.bal_maintain_moonfire:get_state()) or true,
        maintain_insect_swarm = (menu.bal_maintain_insect_swarm and menu.bal_maintain_insect_swarm:get_state()) or true,
        balance_dot_refresh = (menu.bal_dot_refresh and menu.bal_dot_refresh:get()) or 0,
        use_force_of_nature = (menu.bal_use_force_of_nature and menu.bal_use_force_of_nature:get_state()) or true,
        force_of_nature_min_ttd = (menu.bal_fon_min_ttd and menu.bal_fon_min_ttd:get()) or 15,
        hurricane_min_targets = (menu.bal_hurricane_min_targets and menu.bal_hurricane_min_targets:get()) or 3,
        clearcast_starfire = (menu.bal_clearcast_starfire and menu.bal_clearcast_starfire:get_state()) or true,
        ng_wrath_priority = (menu.bal_ng_wrath_priority and menu.bal_ng_wrath_priority:get_state()) or false,
        balance_use_innervate = (menu.bal_balance_use_innervate and menu.bal_balance_use_innervate:get_state()) or true,
        balance_innervate_mana = (menu.bal_balance_innervate_mana and menu.bal_balance_innervate_mana:get()) or 20,
        balance_tier1_mana = (menu.bal_balance_tier1_mana and menu.bal_balance_tier1_mana:get()) or 20,
        balance_tier2_mana = (menu.bal_balance_tier2_mana and menu.bal_balance_tier2_mana:get()) or 10,
        
        -- Caster/Resto
        use_motw = (menu.caster_use_motw and menu.caster_use_motw:get_state()) or true,
        use_thorns = (menu.caster_use_thorns and menu.caster_use_thorns:get_state()) or true,
        use_ooc = (menu.caster_use_ooc and menu.caster_use_ooc:get_state()) or true,
        resto_prioritize_tank = (menu.resto_prioritize_tank and menu.resto_prioritize_tank:get_state()) or true,
        resto_emergency_hp = (menu.resto_emergency_hp and menu.resto_emergency_hp:get()) or 30,
        resto_swiftmend_hp = (menu.resto_swiftmend_hp and menu.resto_swiftmend_hp:get()) or 50,
        resto_standard_heal_hp = (menu.resto_standard_heal_hp and menu.resto_standard_heal_hp:get()) or 80,
        resto_proactive_hp = (menu.resto_proactive_hp and menu.resto_proactive_hp:get()) or 90,
        resto_lifebloom_refresh = (menu.resto_lifebloom_refresh and menu.resto_lifebloom_refresh:get()) or 2,
        resto_mana_conserve = (menu.resto_mana_conserve and menu.resto_mana_conserve:get()) or 40,
        resto_auto_dispel_curse = (menu.resto_auto_dispel_curse and menu.resto_auto_dispel_curse:get_state()) or true,
        resto_auto_dispel_poison = (menu.resto_auto_dispel_poison and menu.resto_auto_dispel_poison:get_state()) or true,
        resto_ns_healing_touch = (menu.resto_ns_healing_touch and menu.resto_ns_healing_touch:get_state()) or true,
        resto_use_rank_optimization = (menu.resto_use_rank_optimization and menu.resto_use_rank_optimization:get_state()) or true,
        
        -- UI & Notifications
        show_notifications = (menu.show_notifications and menu.show_notifications:get_state()) or true,
        notification_duration = (menu.notification_duration and menu.notification_duration:get()) or 1.5,
    }
    
    -- Determine power type based on stance
    local energy, rage, mana_pct, mana, cp
    
    -- Always get mana (needed for powershifting even in forms)
    mana_pct = me:mana_pct()
    mana = me:mana_current()
    
    if stance == Constants.STANCE.CAT then
        energy = me:power_current()
        cp = me:combo_points_current()
    elseif stance == Constants.STANCE.BEAR then
        rage = me:power_current()
    end
    
    -- Build context table
    local ctx = {
        me = me,
        target = target,
        stance = stance,
        in_combat = in_combat,
        combat_time = me:time_in_combat(),
        hp = me:get_health_percentage(),
        gcd_remains = me:gcd_remains(),
        is_stealthed = me:buff_up(5215) or me:buff_up(6783),
        has_clearcasting = me:buff_up(Constants.BUFF_ID.CLEARCASTING),
        is_behind = target and target:is_valid() and Utils.is_behind_target(me, target) or false,
        enemy_count = #izi.enemies(10),
        ttd = target and target:time_to_die() or 999,
        target_phys_immune = target and Utils.has_phys_immunity(target) or false,
        is_boss = target and (target:is_dummy() or target:get_classification() == 3) or false,
        settings = settings,
        -- Power
        energy = energy,
        rage = rage,
        mana_pct = mana_pct,
        mana = mana,
        cp = cp,
        spec = "Unknown",
    }
    
    return ctx
end

-- =============================================================================
-- ROTATION REGISTRATION
-- =============================================================================

-- Register all rotations
local function register_rotations()
    CatRotation.register()
    BearRotation.register()
    BalanceRotation.register()
    RestoRotation.register()
    core.log("[Druid] All rotations registered (Cat, Bear, Balance, Resto)")
end

-- Call registration
register_rotations()

-- =============================================================================
-- UPDATE CALLBACK
-- =============================================================================

core.register_on_update_callback(function()
    -- Build context
    local ctx = build_context()
    if not ctx then return end
    
    -- Invalidate state cache for new frame
    RotationEngine.invalidate_cache()
    
    -- Execute middleware first (consumables, buffs, etc.)
    if Middleware.execute(ctx) then return end
    
    -- Determine active playstyle based on stance
    local playstyle = RotationEngine.get_active_playstyle(ctx)
    if not playstyle then return end
    
    ctx.spec = playstyle:gsub("^%l", string.upper)  -- Capitalize for logging
    
    -- Execute rotation for active playstyle
    RotationEngine.execute_playstyle(playstyle, ctx)
end)

-- =============================================================================
-- NOTIFICATION HELPERS (Using Sylvanas native API)
-- =============================================================================

--- Show notification for burst/defensive/gap actions
-- Uses core.graphics.add_notification (Sylvanas native API)
function show_rotation_notification(action_type, duration)
    local ctx = build_context()
    if not ctx or not ctx.settings.show_notifications then return end
    
    duration = duration or ctx.settings.notification_duration or 1.5
    
    local header = "[Druid " .. (ctx.spec or "Rotation") .. "]"
    local message = ""
    local color_val = color.white(255)
    
    if action_type == "burst" then
        message = "BURST DAMAGE"
        color_val = color.orange(230)
    elseif action_type == "defensive" then
        message = "DEFENSIVE CD"
        color_val = color.cyan(230)
    elseif action_type == "gap" then
        message = "GAP CLOSER"
        color_val = color.purple(230)
    elseif action_type == "heal" then
        message = "EMERGENCY HEAL"
        color_val = color.green(230)
    end
    
    -- Use Sylvanas native notification API
    -- id, header, message, duration_s, color, x_offset, y_offset
    core.graphics.add_notification(
        "druid_" .. action_type .. "_notif",  -- unique ID
        header,
        message,
        duration,
        color_val
    )
end

-- =============================================================================
-- CONTROL PANEL INTEGRATION
-- =============================================================================

-- Enable toggle for control panel
menu.cp_enable_toggle = core.menu.keybind(7, false, "druid_cp_enable_toggle")

local control_panel_utility = require("common/utility/control_panel_helper")

core.register_on_render_control_panel_callback(function()
    local elements = {}
    
    -- Enable/Disable toggle - simplified without key name
    control_panel_utility:insert_toggle_(elements, "Druid Rotation", menu.rotation_toggle)
    
    return elements
end)

core.register_on_update_callback(function()
    -- Update control panel utility for drag & drop
    control_panel_utility:on_update(menu)
end, 0)  -- Priority 0 (first)

-- =============================================================================
-- RENDER CALLBACK (HUD)
-- =============================================================================

local STANCE_NAMES = { 
    [0] = "Humanoid", 
    [1] = "Bear", 
    [3] = "Cat", 
    [4] = "Travel", 
    [5] = "Moonkin/Tree" 
}

core.register_on_render_callback(function()
    local me = izi.me()
    if not me or not me:is_valid() then return end
    
    -- Simple status text (graphics disabled per Sylvanas limitations)
    local stance = Utils.get_stance()
    local stance_name = STANCE_NAMES[stance] or "Unknown"
    local enabled = menu.rotation_toggle:get_toggle_state()
    
    -- Log status on change (instead of graphics)
    -- This is a placeholder for future HUD implementation
end)

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

core.log("Druid Rotations v3.0.0 loaded - Cat/Bear/Balance/Resto (Flux AIO Port)")
core.log("[Druid] Framework: Sylvanas IZI SDK | Pattern: Strategy Registry")
