-- +------------------------------------------------------------------+
-- |  Eax's Warrior Fury
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- -- Tree nodes ----------------------------------------------------------------
local root_tree    = ps.tree_node()
local main_tree    = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local ooc_tree     = ps.tree_node()
local esp_tree     = ps.tree_node()

-- -- Shared plugin controls + shared fields ------------------------------------
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxwarriorfury_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarriorfury_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarriorfury_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarriorfury_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarriorfury_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarriorfury_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarriorfury_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarriorfury_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- menu.auto_repair                        = core.menu.checkbox(true, "eaxwarriorfury_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxwarriorfury_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxwarriorfury_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxwarriorfury_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarriorfury_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarriorfury_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarriorfury_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarriorfury_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarriorfury_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_battle_shout                     = core.menu.checkbox(true, "simplefury_use_battle_shout")
menu.use_cooldowns                        = core.menu.checkbox(true, "simplefury_use_cooldowns")
menu.use_bloodrage                        = core.menu.checkbox(true, "simplefury_use_bloodrage")
menu.use_rampage                          = core.menu.checkbox(true, "simplefury_use_rampage")
menu.use_execute                          = core.menu.checkbox(true, "simplefury_use_execute")
menu.use_heroic_strike                    = core.menu.checkbox(true, "simplefury_use_heroic_strike")
menu.use_cleave                           = core.menu.checkbox(true, "simplefury_use_cleave")
menu.use_pummel                           = core.menu.checkbox(true, "simplefury_use_pummel")
menu.use_berserker_rage                   = core.menu.checkbox(true, "simplefury_use_berserker_rage")
menu.use_sunder_armor                     = core.menu.checkbox(false, "simplefury_use_sunder_armor")
menu.use_hamstring_filler                 = core.menu.checkbox(false, "simplefury_use_hamstring_filler")
menu.use_slam_weave                       = core.menu.checkbox(false, "simplefury_use_slam_weave")
menu.use_overpower                        = core.menu.checkbox(false, "simplefury_use_overpower")
menu.use_intercept                        = core.menu.checkbox(true, "simplefury_use_intercept")
menu.use_charge_opener                    = core.menu.checkbox(true, "simplefury_use_charge_opener")
menu.use_prepull_bloodrage                = core.menu.checkbox(true, "simplefury_use_prepull_bloodrage")
menu.use_execute_sniping                  = core.menu.checkbox(true, "simplefury_use_execute_sniping")
menu.use_commanding_shout                 = core.menu.checkbox(false, "simplefury_use_commanding_shout")
menu.show_notifications                   = core.menu.checkbox(false, "simplefury_show_notifications")
menu.use_demo_shout                       = core.menu.checkbox(false, "simplefury_use_demo_shout")
menu.use_rend                             = core.menu.checkbox(false, "simplefury_use_rend")
menu.use_piercing_howl                    = core.menu.checkbox(false, "simplefury_use_piercing_howl")
menu.use_thunder_clap_aoe                 = core.menu.checkbox(false, "simplefury_use_thunder_clap_aoe")
menu.use_sweeping_strikes                 = core.menu.checkbox(true, "simplefury_use_sweeping_strikes")
menu.track_procs                          = core.menu.checkbox(false, "simplefury_track_procs")
menu.use_death_wish                       = core.menu.checkbox(true, "simplefury_use_death_wish")
menu.use_recklessness                     = core.menu.checkbox(true, "simplefury_use_recklessness")
menu.use_blood_fury                       = core.menu.checkbox(true, "simplefury_use_blood_fury")
menu.use_berserking                       = core.menu.checkbox(true, "simplefury_use_berserking")
menu.use_war_stomp_interrupt              = core.menu.checkbox(true, "simplefury_use_war_stomp_interrupt")
menu.intimidating_shout_key               = core.menu.keybind(7, false, "simplefury_intimidating_shout_key")
menu.use_trinkets                         = core.menu.checkbox(true, "simplefury_use_trinkets")
menu.use_haste_potion                     = core.menu.checkbox(false, "simplefury_use_haste_potion")
menu.use_destruction_potion               = core.menu.checkbox(false, "simplefury_use_destruction_potion")
menu.use_drums                            = core.menu.checkbox(false, "simplefury_use_drums")
menu.use_healthstone                      = core.menu.checkbox(false, "simplefury_use_healthstone")
menu.use_health_potion                    = core.menu.checkbox(true, "simplefury_use_health_potion")
menu.use_stoneform                        = core.menu.checkbox(true, "simplefury_use_stoneform")
menu.heroic_strike_rage                   = core.menu.slider_int(20, 100, 60, "simplefury_hs_rage")
menu.cleave_rage                          = core.menu.slider_int(20, 100, 55, "simplefury_cleave_rage")
menu.aoe_enemy_count                      = core.menu.slider_int(2, 10, 3, "simplefury_aoe_count")
menu.sunder_max_stacks                    = core.menu.slider_int(1, 5, 5, "simplefury_sunder_max_stacks")
menu.intercept_min_range                  = core.menu.slider_int(8, 25, 10, "simplefury_intercept_min_range")
menu.slam_safety_buffer_ms                = core.menu.slider_int(50, 300, 100, "simplefury_slam_safety_buffer_ms")
menu.healthstone_hp_pct                   = core.menu.slider_int(10, 50, 25, "simplefury_healthstone_hp_pct")
menu.health_potion_hp_pct                 = core.menu.slider_int(10, 50, 20, "simplefury_health_potion_hp_pct")
menu.stoneform_hp_pct                     = core.menu.slider_int(20, 80, 40, "simplefury_stoneform_hp_pct")

-- ----------------------------------------------------------------------------
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ----------------------------------------------------------------------------

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_rampage", label = "Rampage" },
    { toggle = "use_execute", label = "Execute" },
    { toggle = "use_slam_weave", label = "Slam Weave" },
    { toggle = "use_sweeping_strikes", label = "Sweeping Strikes" },
    { toggle = "use_death_wish", label = "Death Wish" },
}, {
    namespace = "eaxwarriorfury",
    log_prefix = "[Eax Warrior Fury] ",
})

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxwarriorfury")
    end

    root_tree:render("Eax's Warrior Fury", function()

        ps.render_controls(menu, "Eax's Warrior Fury")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_bloodrage:render("Bloodrage", "Use Bloodrage when rage is low and HP is safe")
            menu.use_rampage:render("Rampage", "Maintain Rampage buff")
            menu.use_heroic_strike:render("Heroic Strike", "Queue Heroic Strike as a high-rage swing dump; do not starve Bloodthirst or Whirlwind for it")
            menu.use_cleave:render("Cleave", "Queue Cleave as an AoE swing dump")
            menu.use_battle_shout:render("Battle Shout", "Maintain Battle Shout buff")
            menu.use_execute:render("Execute", "Use Execute only during BT/WW downtime below 20%")
            menu.use_pummel:render("Pummel", "Interrupt enemy casts")
            menu.use_berserker_rage:render("Berserker Rage", "Use Berserker Rage on cooldown in Berserker Stance while in combat")
            menu.use_sunder_armor:render("Sunder Armor", "Maintain Sunder Armor stacks on the current target when needed")
            menu.use_hamstring_filler:render("Hamstring Filler", "Use Hamstring as a GCD filler when BT and WW are on cooldown")
            menu.use_slam_weave:render("Slam Weave", "Weave Slam between auto attacks when BT/WW are on cooldown")
            menu.use_overpower:render("Overpower (proc)", "Opportunistically stance dance to Battle Stance for Overpower when a dodge proc is available")
            menu.use_intercept:render("Intercept", "Use Intercept as a gap closer while already in Berserker Stance")
            menu.use_charge_opener:render("Charge Opener", "Open from Charge range before combat, then return to Berserker Stance")
            menu.use_prepull_bloodrage:render("Pre-pull Bloodrage", "Use Bloodrage before combat when targeting a hostile enemy")
            menu.use_execute_sniping:render("Execute (AoE low HP)", "In AoE, Execute the lowest-health melee target below 20%")
            menu.use_commanding_shout:render("Commanding Shout", "Use Commanding Shout instead of Battle Shout when you prefer the HP buff")
            menu.show_notifications:render("Notifications", "Show short on-screen flashes and the optional proc overlay")
            menu.use_demo_shout:render("Demo Shout", "Maintain Demoralizing Shout on the current target")
            menu.use_rend:render("Rend", "Opportunistically apply Rend only during existing Battle Stance windows")
            menu.use_piercing_howl:render("Piercing Howl", "Slow nearby packs after the core AoE lane when no target already has the debuff")
            menu.use_thunder_clap_aoe:render("Thunder Clap (AoE)", "Use Thunder Clap opportunistically during Sweeping Strikes Battle windows")
            menu.use_sweeping_strikes:render("Sweeping Strikes", "Use Sweeping Strikes in AoE and stance dance for it")
            menu.track_procs:render("Track Procs", "Track Flurry and Enrage uptime with a compact on-screen HUD and 10-second logs")
            menu.use_death_wish:render("Death Wish", "Use Death Wish during the burst window")
            menu.use_recklessness:render("Recklessness", "Use Recklessness during the burst window")
            menu.use_blood_fury:render("Blood Fury", "Use Blood Fury during the burst window")
            menu.use_berserking:render("Berserking", "Use Troll Berserking during the burst window")
            menu.use_war_stomp_interrupt:render("War Stomp Interrupt", "Use War Stomp as the melee interrupt fallback when Pummel is unavailable")
            menu.intimidating_shout_key:render("Intimidating Shout Key", "Manual-only panic key for Intimidating Shout")
            menu.use_trinkets:render("Trinkets", "Use self-cast on-use trinkets during the burst window")
            menu.use_haste_potion:render("Haste Potion", "Use Haste Potion when allowed by the consumable lane")
            menu.use_destruction_potion:render("Destruction Potion", "Use Destruction Potion when Haste Potion is unavailable or disabled")
            menu.use_drums:render("Drums", "Use Drums of Battle or Drums of War when available")
            menu.use_healthstone:render("Healthstone", "Use Healthstone at low HP")
            menu.use_health_potion:render("Health Potion", "Use a healing potion at low HP (Super > Major > Greater > etc.)")
            menu.use_stoneform:render("Stoneform", "Use Stoneform in combat at low HP if the racial is available")
            menu.heroic_strike_rage:render("HS Min Rage", "Minimum rage to queue Heroic Strike")
            menu.cleave_rage:render("Cleave Min Rage", "Minimum rage to queue Cleave")
            menu.aoe_enemy_count:render("AoE Threshold", "Number of nearby enemies to switch to AoE mode")
            menu.sunder_max_stacks:render("Sunder Max Stacks", "Maximum Sunder Armor stack count to maintain")
            menu.intercept_min_range:render("Intercept Min Range", "Only Intercept when the target is at least this far away")
            menu.slam_safety_buffer_ms:render("Slam Safety Buffer", "Extra milliseconds required before the next swing to avoid Slam clipping")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Use Healthstone when HP falls below this threshold")
            menu.health_potion_hp_pct:render("Health Potion HP %", "Use a healing potion when HP falls below this threshold")
            menu.stoneform_hp_pct:render("Stoneform HP %", "Use Stoneform when HP falls below this threshold")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        -- (none detected)
        })

        -- -- Targeting --------------------------------------------------------
        ps.render_targeting(menu, tgt_tree)

        -- -- Racial ------------------------------------------------------------
        ps.render_racial(menu, racial_tree)

        -- -- Out-of-combat -----------------------------------------------------
        menu.auto_repair:render("Auto Repair", "Automatically repair gear at vendors")
        menu.auto_sell_greys:render("Auto Sell Greys", "Automatically sell poor-quality items at vendors")
        menu.auto_mount:render("Auto Mount", "Automatically mount when traveling out of combat")
        menu.auto_dismount:render("Auto Dismount", "Automatically dismount when entering combat")
        menu.auto_combat_potions:render("Auto Combat Potions", "Use combat potions automatically when appropriate")
        menu.auto_ooc_food_drink:render("Auto OOC Food/Drink", "Use food and drink out of combat when needed")
        menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")
        ps.render_ooc(menu, ooc_tree, false)

        -- -- Display & HUD -----------------------------------------------------
        ps.render_esp(menu, esp_tree)

    end)
end

return menu
