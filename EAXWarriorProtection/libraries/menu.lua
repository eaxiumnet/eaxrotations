-- +------------------------------------------------------------------+
-- |  Eax's Warrior Protection
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
menu.enabled                             = core.menu.checkbox(true, "eaxwarriorprotection_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarriorprotection_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarriorprotection_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarriorprotection_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarriorprotection_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarriorprotection_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarriorprotection_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarriorprotection_racial_hp")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxwarriorprotection_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarriorprotection_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarriorprotection_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarriorprotection_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarriorprotection_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarriorprotection_lev_mana_floor")

-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- Rotation - Abilities
menu.use_shield_slam                      = core.menu.checkbox(true, "simpleprot_use_shield_slam")
menu.use_cooldowns                        = core.menu.checkbox(true, "eaxwarriorprotection_use_cooldowns")
menu.use_revenge                          = core.menu.checkbox(true, "simpleprot_use_revenge")
menu.use_devastate                        = core.menu.checkbox(true, "simpleprot_use_devastate")
menu.use_heroic_strike                    = core.menu.checkbox(true, "simpleprot_use_heroic_strike")
menu.use_cleave                           = core.menu.checkbox(true, "simpleprot_use_cleave")
menu.use_execute                          = core.menu.checkbox(false, "simpleprot_use_execute")
menu.use_battle_shout                     = core.menu.checkbox(false, "simpleprot_use_battle_shout")
menu.use_commanding_shout                 = core.menu.checkbox(true, "simpleprot_use_commanding_shout")
menu.use_bloodrage                        = core.menu.checkbox(true, "simpleprot_use_bloodrage")
menu.show_notifications                   = core.menu.checkbox(false, "simpleprot_show_notifications")
menu.use_prepull_bloodrage                = core.menu.checkbox(true, "simpleprot_use_prepull_bloodrage")
menu.use_demo_shout                       = core.menu.checkbox(true, "simpleprot_use_demo_shout")
menu.use_thunder_clap                     = core.menu.checkbox(true, "simpleprot_use_thunder_clap")
menu.use_sunder_armor                     = core.menu.checkbox(false, "simpleprot_use_sunder_armor")
menu.sunder_max_stacks                    = core.menu.slider_int(1, 5, 5, "simpleprot_sunder_max_stacks")
menu.use_rend                             = core.menu.checkbox(false, "simpleprot_use_rend")
menu.use_hamstring                        = core.menu.checkbox(false, "simpleprot_use_hamstring")
menu.use_intercept                        = core.menu.checkbox(true, "simpleprot_use_intercept")
menu.intercept_min_range                  = core.menu.slider_int(8, 25, 10, "simpleprot_intercept_min_range")
menu.auto_peel                            = core.menu.checkbox(true, "simpleprot_auto_peel")
menu.use_taunt                            = core.menu.checkbox(true, "simpleprot_use_taunt")
menu.use_shield_bash                      = core.menu.checkbox(true, "simpleprot_use_shield_bash")
menu.use_concussion_blow                  = core.menu.checkbox(true, "simpleprot_use_concussion_blow")
menu.use_concussion_blow_proactive        = core.menu.checkbox(false, "simpleprot_use_concussion_blow_proactive")
menu.use_mocking_blow                     = core.menu.checkbox(true, "simpleprot_use_mocking_blow")
menu.use_mocking_blow_dance               = core.menu.checkbox(true, "eaxwarriorprotection_use_mocking_blow_dance")
menu.use_challenging_shout                = core.menu.checkbox(true, "simpleprot_use_challenging_shout")
menu.use_peel_intercept                   = core.menu.checkbox(false, "simpleprot_use_peel_intercept")
menu.use_piercing_howl                    = core.menu.checkbox(false, "simpleprot_use_piercing_howl")
menu.skip_sunder_with_expose              = core.menu.checkbox(true, "simpleprot_skip_sunder_with_expose")
menu.taunt_trash                          = core.menu.checkbox(false, "simpleprot_taunt_trash")
menu.cancel_pws                           = core.menu.checkbox(true, "simpleprot_cancel_pws")
menu.cancel_bop                           = core.menu.checkbox(true, "simpleprot_cancel_bop")
menu.use_intervene                        = core.menu.checkbox(false, "simpleprot_use_intervene")
menu.use_charge                           = core.menu.checkbox(true, "simpleprot_use_charge")
menu.use_rage_potion                      = core.menu.checkbox(false, "simpleprot_use_rage_potion")
menu.rage_potion_rage_threshold           = core.menu.slider_int(0, 40, 20, "simpleprot_rage_potion_rage_threshold")
menu.use_shield_block                     = core.menu.checkbox(true, "simpleprot_use_shield_block")
menu.use_last_stand                       = core.menu.checkbox(true, "simpleprot_use_last_stand")
menu.last_stand_hp_pct                    = core.menu.slider_int(10, 50, 20, "simpleprot_last_stand_hp_pct")
menu.use_shield_wall                      = core.menu.checkbox(true, "simpleprot_use_shield_wall")
menu.shield_wall_hp_pct                   = core.menu.slider_int(10, 50, 25, "simpleprot_shield_wall_hp_pct")
menu.use_spell_reflection                 = core.menu.checkbox(true, "simpleprot_use_spell_reflection")
menu.spell_reflection_progress_pct        = core.menu.slider_int(0, 90, 50, "simpleprot_spell_reflection_progress_pct")
menu.use_healthstone                      = core.menu.checkbox(false, "simpleprot_use_healthstone")
menu.healthstone_hp_pct                   = core.menu.slider_int(10, 50, 25, "simpleprot_healthstone_hp_pct")
menu.use_health_potion                    = core.menu.checkbox(true, "simpleprot_use_health_potion")
menu.health_potion_hp_pct                 = core.menu.slider_int(10, 50, 20, "simpleprot_health_potion_hp_pct")
menu.use_stoneform                        = core.menu.checkbox(true, "simpleprot_use_stoneform")
menu.stoneform_hp_pct                     = core.menu.slider_int(20, 80, 40, "simpleprot_stoneform_hp_pct")
menu.use_trinkets                         = core.menu.checkbox(true, "simpleprot_use_trinkets")
menu.use_haste_potion                     = core.menu.checkbox(false, "simpleprot_use_haste_potion")
menu.use_destruction_potion               = core.menu.checkbox(false, "simpleprot_use_destruction_potion")
menu.use_drums                            = core.menu.checkbox(false, "simpleprot_use_drums")
menu.use_berserker_rage                   = core.menu.checkbox(true, "simpleprot_use_berserker_rage")
menu.use_blood_fury                       = core.menu.checkbox(true, "simpleprot_use_blood_fury")
menu.use_berserking                       = core.menu.checkbox(true, "simpleprot_use_berserking")
menu.use_war_stomp_interrupt              = core.menu.checkbox(true, "simpleprot_use_war_stomp_interrupt")
menu.intimidating_shout_key               = core.menu.keybind(7, false, "simpleprot_intimidating_shout_key")
menu.heroic_strike_rage                   = core.menu.slider_int(20, 100, 60, "simpleprot_hs_rage")
menu.cleave_rage                          = core.menu.slider_int(20, 100, 55, "simpleprot_cleave_rage")
menu.aoe_enemy_count                      = core.menu.slider_int(2, 10, 3, "simpleprot_aoe_count")
menu.shield_block_hp_pct                  = core.menu.slider_int(30, 80, 50, "simpleprot_shield_block_hp_pct")
menu.challenging_boss_threshold           = core.menu.slider_int(1, 5, 1, "simpleprot_challenging_boss_threshold")
menu.challenging_elite_threshold          = core.menu.slider_int(2, 8, 3, "simpleprot_challenging_elite_threshold")
menu.challenging_trash_threshold           = core.menu.slider_int(3, 12, 5, "simpleprot_challenging_trash_threshold")
menu.use_threat_equalization              = core.menu.checkbox(true, "simpleprot_use_threat_equalization")
menu.threat_eq_threshold                  = core.menu.slider_int(5, 25, 10, "simpleprot_threat_eq_threshold")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_shield_slam", label = "Shield Slam" },
    { toggle = "use_revenge", label = "Revenge" },
    { toggle = "use_devastate", label = "Devastate" },
    { toggle = "use_taunt", label = "Taunt" },
    { toggle = "use_shield_block", label = "Shield Block" },
}, {
    namespace = "eaxwarriorprotection",
    log_prefix = "[Eax Warrior Prot] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarriorprotection")
    end

    root_tree:render("Eax's Warrior Protection", function()
        ps.render_controls(menu, "Eax's Warrior Prot")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_shield_slam:render("Shield Slam", "On CD")
            menu.use_revenge:render("Revenge", "Proc")
            menu.use_devastate:render("Devastate", "Filler")
            menu.use_heroic_strike:render("Heroic Strike", "High rage")
            menu.use_cleave:render("Cleave", "AoE")
            menu.use_execute:render("Execute", "Below 20%")
            menu.use_bloodrage:render("Bloodrage", "Low rage")
            menu.use_prepull_bloodrage:render("Pre-pull Bloodrage", "Before combat")
            menu.show_notifications:render("Notifications", "On-screen")
            menu.use_charge:render("Charge", "Opener")
            menu.use_intercept:render("Intercept", "Gap closer")
            menu.intercept_min_range:render("Intercept Min Range", "yd")
            menu.auto_peel:render("Auto Peel", "Protect allies")
            menu.use_intervene:render("Intervene", "Protect")
            menu.use_rage_potion:render("Rage Potion", "Low rage")
            menu.rage_potion_rage_threshold:render("Rage Potion %", "Below")
        end)

        -- Shouts
        shouts_tree:render("Shouts", function()
            menu.use_battle_shout:render("Battle Shout", "AP buff")
            menu.use_commanding_shout:render("Commanding Shout", "HP buff")
            menu.use_demo_shout:render("Demo Shout", "Reduce AP")
        end)

        -- Debuffs
        debuffs_tree:render("Debuffs", function()
            menu.use_thunder_clap:render("Thunder Clap", "Slow")
            menu.use_sunder_armor:render("Sunder Armor", "Stack")
            menu.sunder_max_stacks:render("Sunder Max", "Stacks")
            menu.use_rend:render("Rend", "DoT")
            menu.use_hamstring:render("Hamstring", "Slow")
            menu.use_piercing_howl:render("Piercing Howl", "AoE slow")
            menu.skip_sunder_with_expose:render("Skip w/ Expose", "If Expose up")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_cooldowns:render("Use Cooldowns", "Enable burst")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_berserker_rage:render("Berserker Rage", "On CD")
            menu.use_blood_fury:render("Blood Fury", "Racial")
            menu.use_berserking:render("Berserking", "Racial")
            menu.use_trinkets:render("Trinkets", "On-use")
            menu.use_haste_potion:render("Haste Potion", "Consumable")
            menu.use_destruction_potion:render("Destruction Potion", "Consumable")
            menu.use_drums:render("Drums", "Battle/War")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_shield_block:render("Shield Block", "On CD")
            menu.shield_block_hp_pct:render("Shield Block HP %", "Below")
            menu.use_last_stand:render("Last Stand", "Emergency")
            menu.last_stand_hp_pct:render("Last Stand HP %", "Below")
            menu.use_shield_wall:render("Shield Wall", "Emergency")
            menu.shield_wall_hp_pct:render("Shield Wall HP %", "Below")
            menu.use_spell_reflection:reflect("Spell Reflection", "Reflect spells")
            menu.spell_reflection_progress_pct:render("Spell Reflect %", "Cast progress")
            menu.use_healthstone:render("Healthstone", "Low HP")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.use_health_potion:render("Health Potion", "Low HP")
            menu.health_potion_hp_pct:render("Health Potion HP %", "Below")
            menu.use_stoneform:render("Stoneform", "Low HP")
            menu.stoneform_hp_pct:render("Stoneform HP %", "Below")
            menu.use_war_stomp_interrupt:render("War Stomp", "Interrupt fallback")
            menu.intimidating_shout_key:render("Intimidating Shout", "Panic key")
            menu.cancel_pws:render("Cancel PW:S", "Remove shield")
            menu.cancel_bop:render("Cancel BoP", "Remove protection")
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
