-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Druid Balance
-- ║  Space Theme v4.0  ·  Stars drawn inside the panel background
-- ╚══════════════════════════════════════════════════════════════════╝
local mana_conservator = require("mana_conservator")

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
menu.enabled                             = core.menu.checkbox(true, "eaxdruidbalance_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxdruidbalance_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxdruidbalance_mode")
menu.debug                               = core.menu.checkbox(false, "eaxdruidbalance_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxdruidbalance_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxdruidbalance_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxdruidbalance_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxdruidbalance_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxdruidbalance_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxdruidbalance_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxdruidbalance_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxdruidbalance_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxdruidbalance_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxdruidbalance_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_root_escape                     = core.menu.checkbox(true, "eaxdruidbalance_root_escape")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxdruidbalance_remove_curse")
menu.force_moonkin                        = core.menu.checkbox(true, "eaxdruidbalance_force_moonkin")
menu.use_faerie_fire                      = core.menu.checkbox(true, "eaxdruidbalance_use_faerie_fire")
menu.use_moonfire                         = core.menu.checkbox(true, "eaxdruidbalance_use_moonfire")
menu.use_insect_swarm                     = core.menu.checkbox(true, "eaxdruidbalance_use_insect_swarm")
menu.dot_refresh_seconds                  = core.menu.slider_int(1, 5, 3, "eaxdruidbalance_dot_refresh_seconds")
menu.use_force_of_nature                  = core.menu.checkbox(true, "eaxdruidbalance_use_force_of_nature")
menu.use_starfall                         = core.menu.checkbox(true, "eaxdruidbalance_use_starfall")
menu.starfall_aoe_targets                 = core.menu.slider_int(1, 6, 3, "eaxdruidbalance_starfall_aoe_targets")
menu.use_innervate                        = core.menu.checkbox(true, "eaxdruidbalance_use_innervate")
menu.innervate_mana_pct                   = core.menu.slider_int(10, 60, 30, "eaxdruidbalance_innervate_mana_pct")
menu.use_tranquility                      = core.menu.checkbox(true, "eaxdruidbalance_use_tranquility")
menu.tranquility_hp_pct                   = core.menu.slider_int(20, 70, 35, "eaxdruidbalance_tranquility_hp_pct")
menu.wrath_during_lunar                   = core.menu.checkbox(true, "eaxdruidbalance_wrath_during_lunar")

mana_conservator.register_menu_items(menu, "eax_druid_balance")

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
        ps.draw_space(_win, "eaxdruidbalance")
    end

    root_tree:render("  Eax's Druid Balance", function()

        ps.render_controls(menu, "Eax's Druid Balance")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.force_moonkin:render("Force Moonkin Form", "Keep Moonkin Form active whenever possible")
            menu.use_faerie_fire:render("Faerie Fire", "Maintain Faerie Fire on the active target")
            menu.use_moonfire:render("Moonfire", "Maintain Moonfire on the active target")
            menu.use_insect_swarm:render("Insect Swarm", "Maintain Insect Swarm on the active target")
            menu.dot_refresh_seconds:render("Refresh Window (sec)", "Refresh Moonfire and Insect Swarm when remaining time is below this value")
            menu.use_force_of_nature:render("Force of Nature", "Use Force of Nature during established pressure windows")
            menu.use_starfall:render("Starfall", "Use Starfall when the enemy count or raid pressure justifies it")
            menu.starfall_aoe_targets:render("Starfall AoE Count", "Minimum enemies in range before Starfall is allowed")
            menu.use_innervate:render("Innervate", "Recover mana automatically when out of combat or in a dry lane")
            menu.innervate_mana_pct:render("Innervate Mana %", "Mana threshold for Innervate")
            menu.use_tranquility:render("Emergency Tranquility", "Allow Tranquility as a self-preservation emergency")
            menu.tranquility_hp_pct:render("Tranquility HP %", "Self-health threshold for emergency Tranquility")
            menu.wrath_during_lunar:render("Wrath During Lunar", "Swap to Wrath while a Lunar Eclipse-style buff is active")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_barkskin", label = "Barkskin", tip = "Emergency damage reduction", hp_key = "use_barkskin_hp_pct", hp_label = "Barkskin HP %" },
        { key = "use_survival_instincts", label = "Survival Instincts", tip = "Emergency 25% max HP boost", hp_key = "use_survival_instincts_hp_pct", hp_label = "Survival Instincts HP %" },
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

menu.use_berserk  = core.menu.checkbox(true, "eaxbal_berserk")
menu.use_typhoon = core.menu.checkbox(true, "eaxbal_typhoon")
menu.use_barkskin = core.menu.checkbox(true, "eaxbal_use_barkskin")
menu.use_barkskin_hp_pct = core.menu.slider_int(0, 100, 40, "eaxbal_barkskin_hp")
menu.use_survival_instincts = core.menu.checkbox(true, "eaxbal_survival_instincts")
menu.use_survival_instincts_hp_pct = core.menu.slider_int(0, 100, 30, "eaxbal_survinst_hp")
return menu
