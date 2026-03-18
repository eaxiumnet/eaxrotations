-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Druid Feral
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
menu.enabled                             = core.menu.checkbox(true, "eaxdruidferal_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxdruidferal_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxdruidferal_mode")
menu.debug                               = core.menu.checkbox(false, "eaxdruidferal_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxdruidferal_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxdruidferal_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxdruidferal_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxdruidferal_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxdruidferal_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxdruidferal_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.lane                                 = core.menu.combobox(1, "eaxdruidferal_lane")
menu.use_root_escape                     = core.menu.checkbox(true, "eaxdruidferal_root_escape")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxdruidferal_remove_curse")
menu.auto_form                            = core.menu.checkbox(true, "eaxdruidferal_auto_form")
menu.use_faerie_fire                      = core.menu.checkbox(true, "eaxdruidferal_use_faerie_fire")
menu.use_mangle_cat                       = core.menu.checkbox(true, "eaxdruidferal_use_mangle_cat")
menu.use_rake                             = core.menu.checkbox(true, "eaxdruidferal_use_rake")
menu.use_shred                            = core.menu.checkbox(true, "eaxdruidferal_use_shred")
menu.use_rip                              = core.menu.checkbox(true, "eaxdruidferal_use_rip")
menu.use_ferocious_bite                   = core.menu.checkbox(true, "eaxdruidferal_use_ferocious_bite")
menu.use_tigers_fury                      = core.menu.checkbox(true, "eaxdruidferal_use_tigers_fury")
menu.rake_refresh_seconds                 = core.menu.slider_int(1, 5, 3, "eaxdruidferal_rake_refresh_seconds")
menu.rip_refresh_seconds                  = core.menu.slider_int(1, 5, 3, "eaxdruidferal_rip_refresh_seconds")
menu.rip_combo_points                     = core.menu.slider_int(3, 5, 5, "eaxdruidferal_rip_combo_points")
menu.bite_combo_points                    = core.menu.slider_int(3, 5, 5, "eaxdruidferal_bite_combo_points")
menu.bite_hp_pct                          = core.menu.slider_int(10, 40, 25, "eaxdruidferal_bite_hp_pct")
menu.tigers_fury_energy                   = core.menu.slider_int(10, 60, 30, "eaxdruidferal_tigers_fury_energy")
menu.use_mangle_bear                      = core.menu.checkbox(true, "eaxdruidferal_use_mangle_bear")
menu.use_maul                             = core.menu.checkbox(true, "eaxdruidferal_use_maul")
menu.use_swipe                            = core.menu.checkbox(true, "eaxdruidferal_use_swipe")
menu.auto_growl                           = core.menu.checkbox(true, "eaxdruidferal_auto_growl")
menu.use_frenzied_regeneration            = core.menu.checkbox(true, "eaxdruidferal_use_frenzied_regeneration")
menu.use_berserk                          = core.menu.checkbox(true, "eaxdruidferal_use_berserk")
menu.swipe_enemy_count                    = core.menu.slider_int(2, 6, 3, "eaxdruidferal_swipe_enemy_count")
menu.maul_min_rage                        = core.menu.slider_int(10, 80, 45, "eaxdruidferal_maul_min_rage")
menu.frenzied_regeneration_hp_pct         = core.menu.slider_int(10, 70, 40, "eaxdruidferal_frenzied_regeneration_hp_pct")

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
        ps.draw_space(_win, "eaxdruidferal")
    end

    root_tree:render("  Eax's Druid Feral", function()

        ps.render_controls(menu, "Eax's Druid Feral")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.auto_form:render("Auto Form", "Automatically shift into Cat or Bear for the active lane")
            menu.use_faerie_fire:render("Faerie Fire (Feral)", "Maintain Faerie Fire for both Cat and Bear lanes")
            menu.use_mangle_cat:render("Mangle (Cat)", "Maintain the shared Mangle debuff")
            menu.use_rake:render("Rake", "Maintain Rake bleed uptime")
            menu.use_shred:render("Shred", "Use Shred as the primary combo-point builder")
            menu.use_rip:render("Rip", "Spend combo points on Rip when ready")
            menu.use_ferocious_bite:render("Ferocious Bite", "Spend combo points on Ferocious Bite in execute windows")
            menu.use_tigers_fury:render("Tiger's Fury", "Recover energy for burst windows")
            menu.rake_refresh_seconds:render("Rake Refresh (sec)", "Refresh Rake below this remaining time")
            menu.rip_refresh_seconds:render("Rip Refresh (sec)", "Refresh Rip below this remaining time")
            menu.rip_combo_points:render("Rip Combo Points", "Minimum combo points before Rip")
            menu.bite_combo_points:render("Bite Combo Points", "Minimum combo points before Ferocious Bite")
            menu.bite_hp_pct:render("Bite HP %", "Execute threshold for Ferocious Bite")
            menu.tigers_fury_energy:render("Tiger's Fury Energy", "Use Tiger's Fury at or below this energy")
            menu.use_mangle_bear:render("Mangle (Bear)", "Maintain the shared Mangle debuff")
            menu.use_maul:render("Maul", "Queue Maul as a rage dump")
            menu.use_swipe:render("Swipe", "Use Swipe for pack threat")
            menu.auto_growl:render("Auto Growl", "Taunt when the current target is not on you")
            menu.use_berserk:render("Berserk", "Use Berserk for high-pressure threat windows")
            menu.swipe_enemy_count:render("Swipe Enemy Count", "Minimum enemies before Swipe becomes preferred")
            menu.maul_min_rage:render("Maul Min Rage", "Minimum rage before Maul is queued")
            menu.frenzied_regeneration_hp_pct:render("Frenzied Regen HP %", "Self-health threshold for Frenzied Regeneration")
            menu.lane:render("Lane", { "Auto Detect", "Force Cat", "Force Bear" })
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_frenzied_regeneration", label = "Frenzied Regeneration", tip = "Use Frenzied Regeneration as an emergency cooldown" },
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
