-- +------------------------------------------------------------------+
-- |  Eax's Warrior Fury
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree    = ps.tree_node()
local rotation_tree = ps.tree_node()
local shouts_tree  = ps.tree_node()
local debuffs_tree = ps.tree_node()
local cd_tree      = ps.tree_node()
local auto_tree    = ps.tree_node()
local ooc_tree     = ps.tree_node()
local group_tree   = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local esp_tree     = ps.tree_node()

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

-- Automation
-- menu.auto_repair                        = core.menu.checkbox(true, "eaxwarriorfury_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxwarriorfury_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxwarriorfury_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxwarriorfury_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarriorfury_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarriorfury_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarriorfury_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarriorfury_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarriorfury_lev_mana_floor")

-- Rotation - Abilities
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

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarriorfury")
    end

    root_tree:render("Eax's Warrior Fury", function()
        ps.render_controls(menu, "Eax's Warrior Fury")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_bloodrage:render("Bloodrage", "Low rage, safe HP")
            menu.use_rampage:render("Rampage", "Maintain buff")
            menu.use_heroic_strike:render("Heroic Strike", "High rage dump")
            menu.use_cleave:render("Cleave", "AoE dump")
            menu.use_battle_shout:render("Battle Shout", "AP buff")
            menu.use_execute:render("Execute", "Below 20% HP")
            menu.use_pummel:render("Pummel", "Interrupt")
            menu.use_berserker_rage:render("Berserker Rage", "On CD")
            menu.use_sunder_armor:render("Sunder Armor", "Stack")
            menu.use_hamstring_filler:render("Hamstring Filler", "GCD filler")
            menu.use_slam_weave:render("Slam Weave", "Between autos")
            menu.use_overpower:render("Overpower", "Dodge proc")
            menu.use_intercept:render("Intercept", "Gap closer")
            menu.use_charge_opener:render("Charge Opener", "Pre-combat")
            menu.use_prepull_bloodrage:render("Pre-pull Bloodrage", "Before combat")
            menu.use_execute_sniping:render("Execute Sniping", "AoE low HP")
            menu.use_commanding_shout:render("Commanding Shout", "HP buff")
            menu.show_notifications:render("Notifications", "On-screen")
            menu.use_demo_shout:render("Demo Shout", "Reduce AP")
            menu.use_rend:render("Rend", "Battle Stance only")
            menu.use_piercing_howl:render("Piercing Howl", "Slow packs")
            menu.use_thunder_clap_aoe:render("Thunder Clap AoE", "Sweeping window")
            menu.use_sweeping_strikes:render("Sweeping Strikes", "AoE")
            menu.track_procs:render("Track Procs", "Flurry/Enrage")
            menu.use_death_wish:render("Death Wish", "Burst")
            menu.use_recklessness:render("Recklessness", "Burst")
            menu.use_blood_fury:render("Blood Fury", "Burst")
            menu.use_berserking:render("Berserking", "Burst")
            menu.use_war_stomp_interrupt:render("War Stomp", "Interrupt fallback")
            menu.intimidating_shout_key:render("Intimidating Shout", "Panic key")
            menu.use_trinkets:render("Trinkets", "Burst window")
            menu.use_haste_potion:render("Haste Potion", "Consumable")
            menu.use_destruction_potion:render("Destruction Potion", "Consumable")
            menu.use_drums:render("Drums", "Battle/War")
            menu.use_healthstone:render("Healthstone", "Low HP")
            menu.use_health_potion:render("Health Potion", "Low HP")
            menu.use_stoneform:render("Stoneform", "Low HP")
            menu.heroic_strike_rage:render("HS Min Rage", "Queue above")
            menu.cleave_rage:render("Cleave Min Rage", "Queue above")
            menu.aoe_enemy_count:render("AoE Threshold", "Enemy count")
            menu.sunder_max_stacks:render("Sunder Max", "Stacks")
            menu.intercept_min_range:render("Intercept Min Range", "yd")
            menu.slam_safety_buffer_ms:render("Slam Buffer", "ms")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.health_potion_hp_pct:render("Health Potion HP %", "Below")
            menu.stoneform_hp_pct:render("Stoneform HP %", "Below")
        end)

        -- Shouts
        shouts_tree:render("Shouts", function()
            menu.use_battle_shout:render("Battle Shout", "AP buff")
            menu.use_commanding_shout:render("Commanding Shout", "HP buff")
            menu.use_demo_shout:render("Demo Shout", "Reduce AP")
        end)

        -- Debuffs
        debuffs_tree:render("Debuffs", function()
            menu.use_sunder_armor:render("Sunder Armor", "Stack")
            menu.sunder_max_stacks:render("Sunder Max", "Stacks")
            menu.use_piercing_howl:render("Piercing Howl", "Slow")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_cooldowns:render("Use Cooldowns", "Enable burst")
            menu.use_berserker_rage:render("Berserker Rage", "On CD")
            menu.use_death_wish:render("Death Wish", "Burst")
            menu.use_recklessness:render("Recklessness", "Burst")
            menu.use_sweeping_strikes:render("Sweeping Strikes", "AoE")
            menu.use_blood_fury:render("Blood Fury", "Racial")
            menu.use_berserking:render("Berserking", "Racial")
            menu.use_trinkets:render("Trinkets", "On-use")
            menu.use_haste_potion:render("Haste Potion", "Consumable")
            menu.use_destruction_potion:render("Destruction Potion", "Consumable")
            menu.use_drums:render("Drums", "Battle/War")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_healthstone:render("Healthstone", "Low HP")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.use_health_potion:render("Health Potion", "Low HP")
            menu.health_potion_hp_pct:render("Health Potion HP %", "Below")
            menu.use_stoneform:render("Stoneform", "Low HP")
            menu.stoneform_hp_pct:render("Stoneform HP %", "Below")
            menu.use_war_stomp_interrupt:render("War Stomp", "Interrupt fallback")
            menu.intimidating_shout_key:render("Intimidating Shout", "Panic key")
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

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end

return menu
