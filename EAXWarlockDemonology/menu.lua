-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Warlock Demonology
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
menu.enabled                             = core.menu.checkbox(true, "eaxwarlockdemonology_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarlockdemonology_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarlockdemonology_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarlockdemonology_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarlockdemonology_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarlockdemonology_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarlockdemonology_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarlockdemonology_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarlockdemonology_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarlockdemonology_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxwarlockdemonology_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxwarlockdemonology_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxwarlockdemonology_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxwarlockdemonology_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.ensure_felguard                      = core.menu.checkbox(true, "eax_demonology_ensure_felguard")
menu.maintain_soul_link                   = core.menu.checkbox(true, "eax_demonology_soul_link")
menu.use_soul_fire                        = core.menu.checkbox(true, "eax_demonology_use_soul_fire")
menu.use_shadow_bolt                      = core.menu.checkbox(true, "eax_demonology_use_shadow_bolt")
menu.use_shadowfury                       = core.menu.checkbox(true, "eax_demonology_use_shadowfury")
menu.use_life_tap                         = core.menu.checkbox(true, "eax_demonology_use_life_tap")
menu.life_tap_threshold                   = core.menu.slider_int(10, 80, 35, "eax_demonology_lifetap_pct")
menu.pet_check_interval                   = core.menu.slider_int(1, 10, 4, "eax_demonology_pet_check")
menu.use_banish                           = core.menu.checkbox(true, "eax_wrl_dem_use_banish")

mana_conservator.register_menu_items(menu, "eax_warlock_demonology")

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
        ps.draw_space(_win, "eaxwarlockdemonology")
    end

    root_tree:render("  Eax's Warlock Demonology", function()

        ps.render_controls(menu, "Eax's Warlock Demonology")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.ensure_felguard:render("Ensure Felguard", "Recast Felguard on cooldown")
            menu.maintain_soul_link:render("Soul Link", "Keep Soul Link active when possible")
            menu.use_soul_fire:render("Soul Fire", "Cast Soul Fire when ready")
            menu.use_shadow_bolt:render("Shadow Bolt", "Fallback filler")
            menu.use_shadowfury:render("Shadowfury", "Crowd control when enemies crowd the target")
            menu.use_life_tap:render("Life Tap", "Regain mana under the configured health threshold")
            menu.life_tap_threshold:render("Life Tap HP %", "The minimum health percent required to Life Tap")
            menu.pet_check_interval:render("Pet Refresh Interval", "Seconds between felguard checks")
            menu.use_banish:render("Banish", "")
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
