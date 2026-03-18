-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Hunter Survival
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
menu.enabled                             = core.menu.checkbox(true, "eaxhuntersurvival_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxhuntersurvival_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxhuntersurvival_mode")
menu.debug                               = core.menu.checkbox(false, "eaxhuntersurvival_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxhuntersurvival_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxhuntersurvival_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxhuntersurvival_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxhuntersurvival_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxhuntersurvival_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxhuntersurvival_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_hunters_mark                     = core.menu.checkbox(true, "use_hunters_mark")
menu.use_serpent_sting                    = core.menu.checkbox(true, "use_serpent_sting")
menu.use_explosive_shot                   = core.menu.checkbox(true, "use_explosive_shot")
menu.use_arcane_shot                      = core.menu.checkbox(true, "use_arcane_shot")
menu.use_steady_shot                      = core.menu.checkbox(true, "use_steady_shot")
menu.use_multi_shot                       = core.menu.checkbox(true, "use_multi_shot")
menu.use_raptor_strike                    = core.menu.checkbox(true, "use_raptor_strike")
menu.use_wing_clip                        = core.menu.checkbox(true, "use_wing_clip")
menu.use_traps                            = core.menu.checkbox(true, "use_traps")
menu.trap_selection                       = core.menu.combobox(1, "trap_selection")
menu.trap_interval                        = core.menu.slider_float(1.0, 10.0, 4.0, "trap_interval")
menu.use_wyvern                           = core.menu.checkbox(true, "use_wyvern")
menu.use_expose                           = core.menu.checkbox(true, "use_expose")
menu.use_mend_pet                         = core.menu.checkbox(true, "use_mend_pet")
menu.mend_pet_hp_pct                      = core.menu.slider_int(0, 100, 70, "mend_pet_hp_pct")

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
        ps.draw_space(_win, "eaxhuntersurvival")
    end

    root_tree:render("  Eax's Hunter Survival", function()

        ps.render_controls(menu, "Eax's Hunter Survival")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_hunters_mark:render("Hunters Mark", "Apply Hunters Mark for +AP")
            menu.use_serpent_sting:render("Serpent Sting", "Maintain Serpent Sting on target")
            menu.use_explosive_shot:render("Explosive Shot", "Use Explosive Shot (20yd)")
            menu.use_arcane_shot:render("Arcane Shot", "Use Arcane Shot (30yd)")
            menu.use_steady_shot:render("Steady Shot", "Use Steady Shot for focus generation")
            menu.use_multi_shot:render("Multi-Shot", "Use Multi-Shot (Dungeon/Raid)")
            menu.use_raptor_strike:render("Raptor Strike", "Use Raptor Strike in melee range")
            menu.use_wing_clip:render("Wing Clip", "Use Wing Clip to slow (melee)")
            menu.use_traps:render("Use Traps", "Attempt to drop the selected trap on cooldown")
            menu.trap_interval:render("Trap Interval", "Seconds between trap attempts")
            menu.use_wyvern:render("Use Wyvern Sting", "Apply Wyvern Sting before heavy bursts")
            menu.use_expose:render("Use Expose Weakness", "Maintain the debuff on the primary target")
            menu.use_mend_pet:render("Use Mend Pet", "Use Mend Pet when pet health is low")
            menu.mend_pet_hp_pct:render("Mend Pet HP%", "Use Mend Pet below this health percent")
            menu.trap_selection:render("Trap Type", {"Explosive", "Freezing", "Snake", "Wyvern"})
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
