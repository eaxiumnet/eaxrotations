-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Hunter Marksmanship
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
menu.enabled                             = core.menu.checkbox(true, "eaxhuntermarksmanship_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxhuntermarksmanship_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxhuntermarksmanship_mode")
menu.debug                               = core.menu.checkbox(false, "eaxhuntermarksmanship_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxhuntermarksmanship_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxhuntermarksmanship_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxhuntermarksmanship_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxhuntermarksmanship_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxhuntermarksmanship_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxhuntermarksmanship_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_aimed_shot                       = core.menu.checkbox(true, "use_aimed_shot")
menu.use_multi_shot                       = core.menu.checkbox(true, "use_multi_shot")
menu.use_steady_weave                     = core.menu.checkbox(true, "use_steady_weave")
menu.multi_shot_limit                     = core.menu.slider_int(1, 5, 3, "multi_shot_limit")
menu.use_mend_pet                         = core.menu.checkbox(true, "eax_hunter_mm_use_mend_pet")
menu.mend_pet_hp_pct                      = core.menu.slider_int(0, 100, 70, "eax_hunter_mm_mend_pet_hp_pct")

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
        ps.draw_space(_win, "eaxhuntermarksmanship")
    end

    root_tree:render("  Eax's Hunter Marksmanship", function()

        ps.render_controls(menu, "Eax's Hunter Marksmanship")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_aimed_shot:render("Use Aimed Shot", "Priority burst that benefits from free aim")
            menu.use_multi_shot:render("Use Multi-Shot", "Multi-target weave while the mode permits")
            menu.use_steady_weave:render("Steady Shot Weaving", "Always weave a steady shot between heavy casts")
            menu.multi_shot_limit:render("Multi-Shot Target Cap", "Avoid wasting multi-shot on too few enemies")
            menu.use_mend_pet:render("Mend Pet", "")
            menu.mend_pet_hp_pct:render("Mend Pet Hp Percent", "")
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
