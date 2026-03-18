-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Hunter Beast Mastery
-- ║  Space Theme v4.0  ·  Stars drawn inside the panel background
-- ╚══════════════════════════════════════════════════════════════════╝

local ps   = require("ps_theme")
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
menu.enabled                             = core.menu.checkbox(true, "eaxhunterbeastmastery_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxhunterbeastmastery_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxhunterbeastmastery_mode")
menu.debug                               = core.menu.checkbox(false, "eaxhunterbeastmastery_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxhunterbeastmastery_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxhunterbeastmastery_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxhunterbeastmastery_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxhunterbeastmastery_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxhunterbeastmastery_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxhunterbeastmastery_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_hunters_mark                     = core.menu.checkbox(true, "use_hunters_mark")
menu.use_serpent_sting                    = core.menu.checkbox(true, "use_serpent_sting")
menu.use_arcane_shot                      = core.menu.checkbox(true, "use_arcane_shot")
menu.use_aimed_shot                       = core.menu.checkbox(true, "use_aimed_shot")
menu.use_steady_shot                      = core.menu.checkbox(true, "use_steady_shot")
menu.use_multi_shot                       = core.menu.checkbox(true, "use_multi_shot")
menu.use_raptor_strike                    = core.menu.checkbox(true, "use_raptor_strike")
menu.use_kill_command                     = core.menu.checkbox(true, "use_kill_command")
menu.use_bestial_wrath                    = core.menu.checkbox(true, "use_bestial_wrath")
menu.use_mend_pet                         = core.menu.checkbox(true, "use_mend_pet")
menu.use_revive_pet                       = core.menu.checkbox(true, "use_revive_pet")
menu.mend_pet_hp                          = core.menu.slider_int(10, 80, 50, "mend_pet_hp")

-- ════════════════════════════════════════════════════════════════════════════
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ════════════════════════════════════════════════════════════════════════════

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxhunterbeastmastery")
    end

    root_tree:render("  Eax's Hunter Beast Mastery", function()

        ps.render_controls(menu, "Eax's Hunter Beast Mastery")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_hunters_mark:render("Hunters Mark", "Apply Hunters Mark for +AP")
            menu.use_serpent_sting:render("Serpent Sting", "Maintain Serpent Sting on target")
            menu.use_arcane_shot:render("Arcane Shot", "Use Arcane Shot (30yd)")
            menu.use_aimed_shot:render("Aimed Shot", "Use Aimed Shot (40yd)")
            menu.use_steady_shot:render("Steady Shot", "Use Steady Shot for focus generation")
            menu.use_multi_shot:render("Multi-Shot", "Use Multi-Shot (Dungeon/Raid)")
            menu.use_raptor_strike:render("Raptor Strike", "Use Raptor Strike in melee range")
            menu.use_kill_command:render("Kill Command", "Command pet to attack")
            menu.use_bestial_wrath:render("Bestial Wrath", "Use Bestial Wrath burst")
            menu.use_mend_pet:render("Mend Pet", "Mend pet when low health")
            menu.use_revive_pet:render("Revive Pet", "Auto revive pet if dead")
            menu.mend_pet_hp:render("Mend Pet HP %", "Mend pet below this HP%")
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
        ps.render_ooc(menu, ooc_tree, false)

        -- -- Display & HUD -----------------------------------------------------
        ps.render_esp(menu, esp_tree)

    end)
end

return menu
