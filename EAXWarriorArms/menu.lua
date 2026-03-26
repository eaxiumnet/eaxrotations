-- +------------------------------------------------------------------+
-- |  Eax's Warrior Arms
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("ps_theme")
local settings = require("settings_framework")
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

menu.auto_repair                        = core.menu.checkbox(true, "eaxwarriorarms_auto_repair")
menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxwarriorarms_auto_sell_greys")
menu.auto_mount                         = core.menu.checkbox(true, "eaxwarriorarms_auto_mount")
menu.auto_dismount                      = core.menu.checkbox(true, "eaxwarriorarms_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarriorarms_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarriorarms_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarriorarms_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarriorarms_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarriorarms_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_mortal_strike                    = core.menu.checkbox(true, "eaxwarriorarms_use_mortal_strike")
menu.use_slam                             = core.menu.checkbox(true, "eaxwarriorarms_use_slam")
menu.use_whirlwind                        = core.menu.checkbox(true, "eaxwarriorarms_use_whirlwind")
menu.use_overpower                        = core.menu.checkbox(true, "eaxwarriorarms_use_overpower")
menu.use_execute                          = core.menu.checkbox(true, "eaxwarriorarms_use_execute")
menu.use_cooldowns                        = core.menu.checkbox(true, "eaxwarriorarms_use_cooldowns")
menu.use_berserker_rage                   = core.menu.checkbox(true, "eaxwarriorarms_use_berserker_rage")
menu.use_death_wish                       = core.menu.checkbox(true, "eaxwarriorarms_use_death_wish")
menu.use_recklessness                     = core.menu.checkbox(true, "eaxwarriorarms_use_recklessness")
menu.use_sweeping_strikes                 = core.menu.checkbox(true, "eaxwarriorarms_use_sweeping_strikes")
menu.use_enraged_regen                    = core.menu.checkbox(true, "eaxwarriorarms_use_enraged_regen")
menu.slam_safety_buffer_ms                = core.menu.slider_int(50, 300, 120, "eaxwarriorarms_slam_safety_buffer_ms")
menu.use_battle_shout                     = core.menu.checkbox(true, "eaxwarriorarms_use_battle_shout")
menu.use_commanding_shout                 = core.menu.checkbox(false, "eaxwarriorarms_use_commanding_shout")
menu.use_demo_shout                       = core.menu.checkbox(true, "eaxwarriorarms_use_demo_shout")
menu.use_sunder_armor                     = core.menu.checkbox(true, "eaxwarriorarms_use_sunder_armor")
menu.sunder_max_stacks                    = core.menu.slider_int(1, 5, 5, "eaxwarriorarms_sunder_max_stacks")
menu.use_hamstring                        = core.menu.checkbox(true, "eaxwarriorarms_use_hamstring")

-- ----------------------------------------------------------------------------
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ----------------------------------------------------------------------------

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

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxwarriorarms")
    end

    root_tree:render("Eax's Warrior Arms", function()

        ps.render_controls(menu, "Eax's Warrior Arms")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_mortal_strike:render("Mortal Strike", "Use Mortal Strike on cooldown when enabled")
            menu.use_slam:render("Slam Weave", "Weave Slam between auto attacks when Mortal Strike is on cooldown")
            menu.use_whirlwind:render("Whirlwind", "Dance to Berserker stance for Whirlwind bursts")
            menu.use_overpower:render("Overpower", "Use Overpower when a dodge proc occurs")
            menu.use_execute:render("Execute", "Execute below 20% health")
            menu.slam_safety_buffer_ms:render("Slam Safety Buffer", "Extra milliseconds before the next swing to avoid clipping Slam")
            menu.use_battle_shout:render("Battle Shout", "Maintain Battle Shout support buff")
            menu.use_commanding_shout:render("Commanding Shout", "Replace Battle Shout with Commanding Shout when trained")
            menu.use_demo_shout:render("Demoralizing Shout", "Keep Demoralizing Shout on the target")
            menu.use_sunder_armor:render("Sunder Armor", "Maintain Sunder Armor stacks (Dungeon/Raid only)")
            menu.sunder_max_stacks:render("Sunder Max", "Maximum Sunder Armor stacks to maintain")
            menu.use_hamstring:render("Hamstring", "Use Hamstring as a Solo mode filler")
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
