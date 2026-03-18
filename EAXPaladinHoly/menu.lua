-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Paladin Holy
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
menu.enabled                             = core.menu.checkbox(true, "eaxpaladinholy_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpaladinholy_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpaladinholy_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpaladinholy_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpaladinholy_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpaladinholy_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpaladinholy_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpaladinholy_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpaladinholy_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpaladinholy_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpaladinholy_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpaladinholy_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpaladinholy_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpaladinholy_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_holy_light                       = core.menu.checkbox(true, "use_holy_light")
menu.holy_light_hp_pct                    = core.menu.slider_int(20, 70, 40, "holy_light_hp_pct")
menu.use_flash_of_light                   = core.menu.checkbox(true, "use_flash_of_light")
menu.flash_of_light_hp_pct                = core.menu.slider_int(40, 95, 75, "flash_of_light_hp_pct")
menu.use_holy_shock                       = core.menu.checkbox(true, "use_holy_shock")
menu.holy_shock_hp_pct                    = core.menu.slider_int(5, 60, 30, "holy_shock_hp_pct")
menu.use_hand_of_freedom                  = core.menu.checkbox(true, "eaxpaladinholy_use_hof")
menu.hof_include_slows                    = core.menu.checkbox(false, "eaxpaladinholy_hof_slows")
menu.auto_blessings                       = core.menu.checkbox(true, "auto_blessings")
menu.use_predictive_healing               = core.menu.checkbox(true, "use_predictive_healing")
menu.overheal_protection                  = core.menu.checkbox(true, "overheal_protection")

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
        ps.draw_space(_win, "eaxpaladinholy")
    end

    root_tree:render("  Eax's Paladin Holy", function()

        ps.render_controls(menu, "Eax's Paladin Holy")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_holy_light:render("Holy Light", "Big heals for tanks and hard hits")
            menu.holy_light_hp_pct:render("Holy Light HP %", "Cast Holy Light when a target drops below this percent")
            menu.use_flash_of_light:render("Flash of Light", "Fast heals for raid/dungeon damage spikes")
            menu.flash_of_light_hp_pct:render("Flash HP %", "Use Flash when a target drops below this percent")
            menu.use_holy_shock:render("Holy Shock", "Instant burst heal when health is low")
            menu.holy_shock_hp_pct:render("Holy Shock HP %", "Threshold to consider Holy Shock")
            menu.use_hand_of_freedom:render("Hand of Freedom", "Cast Hand of Freedom on rooted/snared friendly units")
            menu.hof_include_slows:render("Freedom on Slows", "Also use Hand of Freedom on slowed (not just rooted) allies")
            menu.auto_blessings:render("Auto Blessings", "Keep Blessings of Light, Wisdom, and Might active on yourself")
            menu.use_predictive_healing:render("Predictive Healing", "Use incoming damage prediction to heal before damage lands")
            menu.overheal_protection:render("Overheal Protection", "Cancel slow heals when target is near full HP")
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
        ps.render_ooc(menu, ooc_tree, true)

        -- -- Display & HUD -----------------------------------------------------
        ps.render_esp(menu, esp_tree)

    end)
end

return menu
