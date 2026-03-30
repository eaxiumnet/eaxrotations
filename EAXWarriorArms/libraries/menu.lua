-- +------------------------------------------------------------------+
-- |  Eax's Warrior Arms
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
menu.enabled                             = core.menu.checkbox(true, "eaxwarriorarms_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarriorarms_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarriorarms_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarriorarms_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarriorarms_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarriorarms_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarriorarms_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarriorarms_racial_hp")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
-- menu.auto_repair                        = core.menu.checkbox(true, "eaxwarriorarms_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxwarriorarms_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxwarriorarms_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxwarriorarms_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarriorarms_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarriorarms_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarriorarms_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarriorarms_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarriorarms_lev_mana_floor")

-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- Rotation - Abilities
menu.use_mortal_strike                    = core.menu.checkbox(true, "eaxwarriorarms_use_mortal_strike")
menu.use_slam                             = core.menu.checkbox(true, "eaxwarriorarms_use_slam")
menu.use_whirlwind                        = core.menu.checkbox(true, "eaxwarriorarms_use_whirlwind")
menu.use_overpower                        = core.menu.checkbox(true, "eaxwarriorarms_use_overpower")
menu.use_rend                             = core.menu.checkbox(true, "eaxwarriorarms_use_rend")
menu.use_execute                          = core.menu.checkbox(true, "eaxwarriorarms_use_execute")
menu.slam_safety_buffer_ms                = core.menu.slider_int(50, 300, 120, "eaxwarriorarms_slam_safety_buffer_ms")

-- Shouts
menu.use_battle_shout                     = core.menu.checkbox(true, "eaxwarriorarms_use_battle_shout")
menu.use_commanding_shout                 = core.menu.checkbox(false, "eaxwarriorarms_use_commanding_shout")
menu.use_demo_shout                       = core.menu.checkbox(true, "eaxwarriorarms_use_demo_shout")

-- Debuffs
menu.use_sunder_armor                     = core.menu.checkbox(true, "eaxwarriorarms_use_sunder_armor")
menu.sunder_max_stacks                    = core.menu.slider_int(1, 5, 5, "eaxwarriorarms_sunder_max_stacks")
menu.use_hamstring                        = core.menu.checkbox(true, "eaxwarriorarms_use_hamstring")

-- Cooldowns
menu.use_cooldowns                        = core.menu.checkbox(true, "eaxwarriorarms_use_cooldowns")
menu.use_berserker_rage                   = core.menu.checkbox(true, "eaxwarriorarms_use_berserker_rage")
menu.use_death_wish                       = core.menu.checkbox(true, "eaxwarriorarms_use_death_wish")
menu.use_recklessness                     = core.menu.checkbox(true, "eaxwarriorarms_use_recklessness")
menu.use_sweeping_strikes                 = core.menu.checkbox(true, "eaxwarriorarms_use_sweeping_strikes")
menu.use_enraged_regen                    = core.menu.checkbox(true, "eaxwarriorarms_use_enraged_regen")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_mortal_strike", label = "Mortal Strike" },
    { toggle = "use_slam", label = "Slam" },
    { toggle = "use_whirlwind", label = "Whirlwind" },
    { toggle = "use_overpower", label = "Overpower" },
    { toggle = "use_execute", label = "Execute" },
}, {
    namespace = "eaxwarriorarms",
    log_prefix = "[Eax Warrior Arms] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarriorarms")
    end

    root_tree:render("Eax's Warrior Arms", function()
        ps.render_controls(menu, "Eax's Warrior Arms")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_mortal_strike:render("Mortal Strike", "On cooldown")
            menu.use_slam:render("Slam Weave", "Between auto attacks")
            menu.use_whirlwind:render("Whirlwind", "Berserker stance burst")
            menu.use_overpower:render("Overpower", "Dodge proc")
            menu.use_rend:render("Rend", "Blood Frenzy uptime")
            menu.use_execute:render("Execute", "Below 20% HP")
            menu.slam_safety_buffer_ms:render("Slam Buffer", "ms before swing")
        end)

        -- Shouts
        shouts_tree:render("Shouts", function()
            menu.use_battle_shout:render("Battle Shout", "AP buff")
            menu.use_commanding_shout:render("Commanding Shout", "HP buff")
            menu.use_demo_shout:render("Demoralizing Shout", "Reduce target AP")
        end)

        -- Debuffs
        debuffs_tree:render("Debuffs", function()
            menu.use_sunder_armor:render("Sunder Armor", "Stack in raids")
            menu.sunder_max_stacks:render("Sunder Max", "Max stacks")
            menu.use_hamstring:render("Hamstring", "Slow in solo")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_cooldowns:render("Use Cooldowns", "Enable burst CDs")
            menu.use_berserker_rage:render("Berserker Rage", "Rage generation")
            menu.use_death_wish:render("Death Wish", "DPS boost")
            menu.use_recklessness:render("Recklessness", "Armor penetration")
            menu.use_sweeping_strikes:render("Sweeping Strikes", "AoE damage")
            menu.use_enraged_regen:render("Enraged Regen", "Self-heal")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            -- (none configured for Arms)
        end)

        -- Automation
        auto_tree:render("Automation", function()
            menu.auto_combat_potions:render("Combat Potions", "In combat")
            menu.auto_ooc_food_drink:render("OOC Food/Drink", "Eat/drink OOC")
            menu.auto_flask:render("Auto Flask", "Flask buff")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling")
            menu.leveling_mana_floor:render("Mana %", "Below")
        end)

        -- OOC
        ooc_tree:render("OOC Sustain", function()
            menu.ooc_drink:render("Auto-Drink", "Drink OOC")
            menu.drink_threshold:render("Drink %", "Below")
            menu.ooc_eat:render("Auto-Eat", "Eat OOC")
            menu.eat_threshold:render("Eat %", "Below")
        end)

        -- Group
        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)

        -- Display
        esp_tree:render("Display", function()
            menu.esp_show_hud:render("Show HUD", "Status")
            menu.esp_show_target:render("Show Target", "Info")
            menu.esp_hud_x:render("HUD X", "")
            menu.esp_hud_y:render("HUD Y", "")
        end)
    end)
end

return menu
