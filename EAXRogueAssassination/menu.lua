-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Rogue Assassination
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
menu.enabled                             = core.menu.checkbox(true, "eaxrogueassassination_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxrogueassassination_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxrogueassassination_mode")
menu.debug                               = core.menu.checkbox(false, "eaxrogueassassination_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxrogueassassination_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxrogueassassination_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxrogueassassination_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxrogueassassination_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxrogueassassination_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxrogueassassination_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_mutilate                         = core.menu.checkbox(true, "eaxrogueassassination_use_mutilate")
menu.use_slice_and_dice                   = core.menu.checkbox(true, "eaxrogueassassination_use_slice_and_dice")
menu.use_envenom                          = core.menu.checkbox(true, "eaxrogueassassination_use_envenom")
menu.use_eviscerate                       = core.menu.checkbox(true, "eaxrogueassassination_use_eviscerate")
menu.use_rupture                          = core.menu.checkbox(false, "eaxrogueassassination_use_rupture")
menu.use_kick                             = core.menu.checkbox(true, "eaxrogueassassination_use_kick")
menu.use_cold_blood                       = core.menu.checkbox(true, "eaxrogueassassination_use_cold_blood")
menu.snd_refresh_seconds                  = core.menu.slider_int(1, 6, 3, "eaxrogueassassination_snd_refresh_seconds")
menu.envenom_combo_points                 = core.menu.slider_int(4, 5, 5, "eaxrogueassassination_envenom_combo_points")
menu.poison_stack_threshold               = core.menu.slider_int(1, 5, 4, "eaxrogueassassination_poison_stack_threshold")
menu.rupture_combo_points                 = core.menu.slider_int(3, 5, 4, "eaxrogueassassination_rupture_combo_points")
menu.use_evasion                          = core.menu.checkbox(true, "eaxrogueassassination_use_evasion")
menu.evasion_hp_pct                       = core.menu.slider_int(0, 100, 35, "eaxrogueassassination_evasion_hp_pct")

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
        ps.draw_space(_win, "eaxrogueassassination")
    end

    root_tree:render("  Eax's Rogue Assassination", function()

        ps.render_controls(menu, "Eax's Rogue Assassination")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_mutilate:render("Mutilate", "Primary combo-point builder")
            menu.use_slice_and_dice:render("Slice and Dice", "Maintain Slice and Dice before finishers")
            menu.use_envenom:render("Envenom", "Spend combo points when Deadly Poison is stacked")
            menu.use_eviscerate:render("Eviscerate", "Fallback finisher when poison stacks are low")
            menu.use_rupture:render("Rupture", "Optional sustained-damage finisher")
            menu.use_kick:render("Kick", "Interrupt enemy casts")
            menu.use_cold_blood:render("Cold Blood", "Use during dungeon and raid finishers")
            menu.snd_refresh_seconds:render("SnD Refresh", "Refresh Slice and Dice when remaining duration is below this many seconds")
            menu.envenom_combo_points:render("Envenom CP", "Minimum combo points before Envenom")
            menu.poison_stack_threshold:render("Deadly Poison Stacks", "Minimum poison stacks before Envenom")
            menu.rupture_combo_points:render("Rupture CP", "Minimum combo points before Rupture")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_evasion", label = "Evasion", tip = "Use Evasion as an emergency cooldown", hp_key = "evasion_hp_pct", hp_label = "Evasion Hp Percent" },
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
