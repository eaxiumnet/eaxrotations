-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Priest Shadow
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
menu.enabled                             = core.menu.checkbox(true, "eaxpriestshadow_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpriestshadow_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpriestshadow_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpriestshadow_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpriestshadow_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpriestshadow_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpriestshadow_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpriestshadow_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpriestshadow_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpriestshadow_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpriestshadow_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpriestshadow_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpriestshadow_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpriestshadow_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.dot_refresh_window                   = core.menu.slider_int(1, 5, 3, "eax_priest_shadow_dot_window")
menu.mind_blast_burst                     = core.menu.checkbox(true, "eax_priest_shadow_mb_burst")
menu.mind_blast_burst_window              = core.menu.slider_float(0.5, 3, 1.4, "eax_priest_shadow_mb_burst_window")
menu.shadowfiend_enabled                  = core.menu.checkbox(true, "eax_priest_shadow_shadowfiend")
menu.shadowfiend_cooldown_seconds         = core.menu.slider_int(12, 30, 18, "eax_priest_shadow_shadowfiend_cd")
menu.keep_shadowform                      = core.menu.checkbox(true, "eax_priest_shadow_shadowform")
menu.use_flash_heal                       = core.menu.checkbox(true, "eax_priest_shadow_use_flash_heal")
menu.flash_heal_hp_pct                    = core.menu.slider_int(0, 100, 30, "eax_priest_shadow_flash_heal_hp_pct")

mana_conservator.register_menu_items(menu, "eax_priest_shadow")

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
        ps.draw_space(_win, "eaxpriestshadow")
    end

    root_tree:render("  Eax's Priest Shadow", function()

        ps.render_controls(menu, "Eax's Priest Shadow")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.dot_refresh_window:render("DoT Refresh Window", "Refresh Vampiric Touch / Shadow Word: Pain when only this many seconds remain")
            menu.mind_blast_burst:render("Burst Mind Blast", "Allow Mind Blast even when the DoTs are nearing expiry")
            menu.mind_blast_burst_window:render("Burst Window", "Force Mind Blast if one DoT has this many seconds or less remaining")
            menu.shadowfiend_enabled:render("Shadowfiend", "Summon Shadowfiend on cooldown for mana return")
            menu.shadowfiend_cooldown_seconds:render("Shadowfiend Cooldown", "Seconds between forced Shadowfiend summons")
            menu.keep_shadowform:render("Keep Shadowform", "Maintain Shadowform when available")
            menu.use_flash_heal:render("Flash Heal", "")
            menu.flash_heal_hp_pct:render("Flash Heal Hp Percent", "")
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
