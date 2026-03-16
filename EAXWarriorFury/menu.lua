-- EAX Warrior Fury | menu.lua
-- All menu elements are created once at require-time.

local menu = {}

local tree = core.menu.tree_node()
local utility_tree = core.menu.tree_node()
local burst_tree = core.menu.tree_node()
local consumables_tree = core.menu.tree_node()
local defensive_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "simplefury_enabled")
menu.toggle_key = core.menu.keybind(7, false, "simplefury_toggle_key")
menu.debug = core.menu.checkbox(false, "simplefury_debug")
menu.mode = core.menu.combobox(1, "simplefury_mode")

menu.use_battle_shout = core.menu.checkbox(true, "simplefury_use_battle_shout")
menu.use_bloodrage = core.menu.checkbox(true, "simplefury_use_bloodrage")
menu.use_rampage = core.menu.checkbox(true, "simplefury_use_rampage")
menu.use_execute = core.menu.checkbox(true, "simplefury_use_execute")
menu.use_heroic_strike = core.menu.checkbox(true, "simplefury_use_heroic_strike")
menu.use_cleave = core.menu.checkbox(true, "simplefury_use_cleave")
menu.use_pummel = core.menu.checkbox(true, "simplefury_use_pummel")
menu.use_berserker_rage = core.menu.checkbox(true, "simplefury_use_berserker_rage")
menu.use_sunder_armor = core.menu.checkbox(false, "simplefury_use_sunder_armor")
menu.use_hamstring_filler = core.menu.checkbox(false, "simplefury_use_hamstring_filler")
menu.use_slam_weave = core.menu.checkbox(false, "simplefury_use_slam_weave")
menu.use_overpower = core.menu.checkbox(false, "simplefury_use_overpower")
menu.use_intercept = core.menu.checkbox(true, "simplefury_use_intercept")
menu.use_charge_opener = core.menu.checkbox(true, "simplefury_use_charge_opener")
menu.use_prepull_bloodrage = core.menu.checkbox(true, "simplefury_use_prepull_bloodrage")
menu.use_execute_sniping = core.menu.checkbox(true, "simplefury_use_execute_sniping")
menu.use_commanding_shout = core.menu.checkbox(false, "simplefury_use_commanding_shout")
menu.show_notifications = core.menu.checkbox(false, "simplefury_show_notifications")

menu.use_demo_shout = core.menu.checkbox(false, "simplefury_use_demo_shout")
menu.use_rend = core.menu.checkbox(false, "simplefury_use_rend")
menu.use_piercing_howl = core.menu.checkbox(false, "simplefury_use_piercing_howl")
menu.use_thunder_clap_aoe = core.menu.checkbox(false, "simplefury_use_thunder_clap_aoe")
menu.use_sweeping_strikes = core.menu.checkbox(true, "simplefury_use_sweeping_strikes")
menu.track_procs = core.menu.checkbox(false, "simplefury_track_procs")
menu.use_death_wish = core.menu.checkbox(true, "simplefury_use_death_wish")
menu.use_recklessness = core.menu.checkbox(true, "simplefury_use_recklessness")
menu.use_blood_fury = core.menu.checkbox(true, "simplefury_use_blood_fury")
menu.use_berserking = core.menu.checkbox(true, "simplefury_use_berserking")
menu.use_war_stomp_interrupt = core.menu.checkbox(true, "simplefury_use_war_stomp_interrupt")
menu.intimidating_shout_key = core.menu.keybind(7, false, "simplefury_intimidating_shout_key")
menu.use_trinkets = core.menu.checkbox(true, "simplefury_use_trinkets")

menu.use_haste_potion = core.menu.checkbox(false, "simplefury_use_haste_potion")
menu.use_destruction_potion = core.menu.checkbox(false, "simplefury_use_destruction_potion")
menu.use_drums = core.menu.checkbox(false, "simplefury_use_drums")

menu.use_healthstone = core.menu.checkbox(false, "simplefury_use_healthstone")
menu.use_health_potion = core.menu.checkbox(true, "simplefury_use_health_potion")
menu.use_stoneform = core.menu.checkbox(true, "simplefury_use_stoneform")

menu.heroic_strike_rage = core.menu.slider_int(20, 100, 60, "simplefury_hs_rage")
menu.cleave_rage = core.menu.slider_int(20, 100, 55, "simplefury_cleave_rage")
menu.aoe_enemy_count = core.menu.slider_int(2, 10, 3, "simplefury_aoe_count")
menu.sunder_max_stacks = core.menu.slider_int(1, 5, 5, "simplefury_sunder_max_stacks")
menu.intercept_min_range = core.menu.slider_int(8, 25, 10, "simplefury_intercept_min_range")
menu.slam_safety_buffer_ms = core.menu.slider_int(50, 300, 100, "simplefury_slam_safety_buffer_ms")
menu.healthstone_hp_pct = core.menu.slider_int(10, 50, 25, "simplefury_healthstone_hp_pct")
menu.health_potion_hp_pct = core.menu.slider_int(10, 50, 20, "simplefury_health_potion_hp_pct")
menu.stoneform_hp_pct = core.menu.slider_int(20, 80, 40, "simplefury_stoneform_hp_pct")

function menu.render()
    tree:render("EAX Warrior Fury", function()
        menu.enabled:render("Enabled", "Master enable/disable toggle")
        menu.toggle_key:render("Toggle Key", "Keybind to toggle enabled state")
        menu.debug:render("Debug Logging", "Print rotation decisions to console")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        menu.use_battle_shout:render("Battle Shout", "Maintain Battle Shout buff")
        menu.use_bloodrage:render("Bloodrage", "Use Bloodrage when rage is low and HP is safe")
        menu.use_rampage:render("Rampage", "Maintain Rampage buff")
        menu.use_execute:render("Execute", "Use Execute only during BT/WW downtime below 20%")
        menu.use_heroic_strike:render("Heroic Strike", "Queue Heroic Strike as a single-target swing dump")
        menu.use_cleave:render("Cleave", "Queue Cleave as an AoE swing dump")
        menu.use_pummel:render("Pummel", "Interrupt enemy casts")
        menu.use_berserker_rage:render("Berserker Rage",
            "Use Berserker Rage on cooldown in Berserker Stance while in combat")
        menu.use_charge_opener:render("Charge Opener",
            "Open from Charge range before combat, then return to Berserker Stance")
        menu.use_prepull_bloodrage:render("Pre-pull Bloodrage",
            "Use Bloodrage before combat when targeting a hostile enemy")
        menu.use_commanding_shout:render("Commanding Shout",
            "Use Commanding Shout instead of Battle Shout when you prefer the HP buff")
        menu.show_notifications:render("Notifications", "Show short on-screen flashes and the optional proc overlay")

        utility_tree:render("Utility", function()
            menu.use_demo_shout:render("Demo Shout", "Maintain Demoralizing Shout on the current target")
            menu.use_sunder_armor:render("Sunder Armor", "Maintain Sunder Armor stacks on the current target when needed")
            menu.sunder_max_stacks:render("Sunder Max Stacks", "Maximum Sunder Armor stack count to maintain")
            menu.use_rend:render("Rend", "Apply Rend only during existing Battle Stance windows")
            menu.use_hamstring_filler:render("Hamstring Filler",
                "Use Hamstring as a GCD filler when BT and WW are on cooldown")
            menu.use_slam_weave:render("Slam Weave", "Weave Slam between auto attacks when BT/WW are on cooldown")
            menu.slam_safety_buffer_ms:render("Slam Safety Buffer",
                "Extra milliseconds required before the next swing to avoid Slam clipping")
            menu.use_overpower:render("Overpower Dance",
                "Stance dance to Battle Stance for Overpower when a dodge proc is available")
            menu.use_piercing_howl:render("Piercing Howl",
                "Slow nearby packs after the core AoE lane when no target already has the debuff")
            menu.use_thunder_clap_aoe:render("Thunder Clap (AoE)",
                "Use Thunder Clap opportunistically during Sweeping Strikes Battle windows")
            menu.use_intercept:render("Intercept", "Use Intercept as a gap closer while already in Berserker Stance")
            menu.intercept_min_range:render("Intercept Min Range",
                "Only Intercept when the target is at least this far away")
            menu.use_sweeping_strikes:render("Sweeping Strikes", "Use Sweeping Strikes in AoE and stance dance for it")
            menu.use_execute_sniping:render("Execute Sniping", "In AoE, Execute the lowest-health melee target below 20%")
            menu.track_procs:render("Track Procs",
                "Track Flurry and Enrage uptime with a compact on-screen HUD and 10-second logs")
        end)

        burst_tree:render("Burst", function()
            menu.use_death_wish:render("Death Wish", "Use Death Wish during the burst window")
            menu.use_recklessness:render("Recklessness", "Use Recklessness during the burst window")
            menu.use_blood_fury:render("Blood Fury", "Use Blood Fury during the burst window")
            menu.use_berserking:render("Berserking", "Use Troll Berserking during the burst window")
            menu.use_war_stomp_interrupt:render("War Stomp Interrupt",
                "Use War Stomp as the melee interrupt fallback when Pummel is unavailable")
            menu.intimidating_shout_key:render("Intimidating Shout Key", "Manual-only panic key for Intimidating Shout")
            menu.use_trinkets:render("Trinkets", "Use self-cast on-use trinkets during the burst window")
        end)

        consumables_tree:render("Consumables", function()
            menu.use_haste_potion:render("Haste Potion", "Use Haste Potion when allowed by the consumable lane")
            menu.use_destruction_potion:render("Destruction Potion",
                "Use Destruction Potion when Haste Potion is unavailable or disabled")
            menu.use_drums:render("Drums", "Use Drums of Battle or Drums of War when available")
        end)

        defensive_tree:render("Defensive", function()
            menu.use_healthstone:render("Healthstone", "Use Healthstone at low HP")
            menu.healthstone_hp_pct:render("Healthstone HP %",
                "Use Healthstone when HP falls below this threshold")
            menu.use_health_potion:render("Health Potion",
                "Use a healing potion at low HP (Super > Major > Greater > etc.)")
            menu.health_potion_hp_pct:render("Health Potion HP %",
                "Use a healing potion when HP falls below this threshold")
            menu.use_stoneform:render("Stoneform", "Use Stoneform in combat at low HP if the racial is available")
            menu.stoneform_hp_pct:render("Stoneform HP %", "Use Stoneform when HP falls below this threshold")
        end)

        menu.heroic_strike_rage:render("HS Min Rage", "Minimum rage to queue Heroic Strike")
        menu.cleave_rage:render("Cleave Min Rage", "Minimum rage to queue Cleave")
        menu.aoe_enemy_count:render("AoE Threshold", "Number of nearby enemies to switch to AoE mode")
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "simplefury_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "simplefury_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
