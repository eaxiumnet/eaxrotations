-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Rogue Combat
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
menu.enabled                             = core.menu.checkbox(true, "eaxroguecombat_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxroguecombat_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxroguecombat_mode")
menu.debug                               = core.menu.checkbox(false, "eaxroguecombat_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxroguecombat_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxroguecombat_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxroguecombat_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxroguecombat_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxroguecombat_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxroguecombat_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_sinister_strike                  = core.menu.checkbox(true, "eaxroguecombat_use_sinister_strike")
menu.use_slice_and_dice                   = core.menu.checkbox(true, "eaxroguecombat_use_slice_and_dice")
menu.use_rupture                          = core.menu.checkbox(true, "eaxroguecombat_use_rupture")
menu.use_eviscerate                       = core.menu.checkbox(true, "eaxroguecombat_use_eviscerate")
menu.use_kick                             = core.menu.checkbox(true, "eaxroguecombat_use_kick")
menu.use_blade_flurry                     = core.menu.checkbox(true, "eaxroguecombat_use_blade_flurry")
menu.use_adrenaline_rush                  = core.menu.checkbox(true, "eaxroguecombat_use_adrenaline_rush")
menu.use_evasion                          = core.menu.checkbox(true, "eaxroguecombat_use_evasion")
menu.evasion_hp_pct                       = core.menu.slider_int(0, 100, 35, "eaxroguecombat_evasion_hp_pct")
menu.snd_refresh_seconds                  = core.menu.slider_int(1, 6, 3, "eaxroguecombat_snd_refresh_seconds")
menu.finish_combo_points                  = core.menu.slider_int(3, 5, 4, "eaxroguecombat_finish_combo_points")
menu.aoe_enemy_count                      = core.menu.slider_int(2, 5, 2, "eaxroguecombat_aoe_enemy_count")

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
        ps.draw_space(_win, "eaxroguecombat")
    end

    root_tree:render("  Eax's Rogue Combat", function()

        ps.render_controls(menu, "Eax's Rogue Combat")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_sinister_strike:render("Sinister Strike", "Primary combo-point builder")
            menu.use_slice_and_dice:render("Slice and Dice", "Maintain Slice and Dice as the top finisher priority")
            menu.use_rupture:render("Rupture", "Use Rupture on sustained targets")
            menu.use_eviscerate:render("Eviscerate", "Fallback damage finisher")
            menu.use_kick:render("Kick", "Interrupt enemy casts")
            menu.use_blade_flurry:render("Blade Flurry", "Use for cleave and burst")
            menu.use_adrenaline_rush:render("Adrenaline Rush", "Use during dungeon and raid burst windows")
            menu.snd_refresh_seconds:render("SnD Refresh", "Refresh Slice and Dice below this many seconds")
            menu.finish_combo_points:render("Finisher CP", "Minimum combo points before finishers")
            menu.aoe_enemy_count:render("AoE Threshold", "Enemies needed before Blade Flurry is prioritized")
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

menu.use_cloak = core.menu.checkbox(true, "eaxroguecombat_use_cloak")
menu.use_cloak_hp_pct = core.menu.slider_int(0, 100, 60, "eaxroguecombat_cloak_hp")
return menu
