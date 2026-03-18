-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Priest Holy
-- ║  Space Theme v4.0  ·  Stars drawn inside the panel background
-- ╚══════════════════════════════════════════════════════════════════╝
local mana_conservator = require("mana_conservator")

local ps   = require("ps_theme")
local menu = {}

-- ── Tree nodes ────────────────────────────────────────────────────────────────
local root_tree    = ps.tree_node()
local main_tree    = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local ooc_tree     = ps.tree_node()
local esp_tree     = ps.tree_node()

-- ── Shared plugin controls + shared fields ────────────────────────────────────
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxpriestholy_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpriestholy_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpriestholy_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpriestholy_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpriestholy_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpriestholy_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpriestholy_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpriestholy_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpriestholy_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpriestholy_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpriestholy_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpriestholy_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpriestholy_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpriestholy_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- ── Class-specific elements ───────────────────────────────────────────────────
menu.renew_threshold                      = core.menu.slider_int(10, 90, 75, "eax_priest_holy_renew_threshold")
menu.renew_refresh_seconds                = core.menu.slider_int(1, 5, 2, "eax_priest_holy_renew_refresh_seconds")
menu.greater_heal_threshold               = core.menu.slider_int(25, 70, 45, "eax_priest_holy_greater_heal_threshold")
menu.prayer_of_healing_enabled            = core.menu.checkbox(true, "eax_priest_holy_pohealing_enabled")
menu.prayer_of_healing_threshold          = core.menu.slider_int(30, 70, 55, "eax_priest_holy_prayer_of_healing_threshold")
menu.prayer_of_healing_count              = core.menu.slider_int(1, 5, 3, "eax_priest_holy_prayer_of_healing_count")
menu.auto_prayer_of_mending               = core.menu.checkbox(true, "eax_priest_holy_auto_pom")
menu.prayer_of_mending_threshold          = core.menu.slider_int(25, 65, 50, "eax_priest_holy_pom_threshold")
menu.overheal_protection                  = core.menu.checkbox(true, "eax_priest_holy_overheal_protection")

mana_conservator.register_menu_items(menu, "eax_priest_holy")

-- ════════════════════════════════════════════════════════════════════════════
-- RENDER  — called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ════════════════════════════════════════════════════════════════════════════

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxpriestholy")
    end

    root_tree:render("  Eax's Priest Holy", function()

        ps.render_controls(menu, "Eax's Priest Holy")

        -- ── Class-specific settings ───────────────────────────────────────────
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.renew_threshold:render("Renew Threshold", "Only refresh renew when health drops below this")
            menu.renew_refresh_seconds:render("Renew Refresh Window", "Seconds of Renew remaining before refreshing")
            menu.greater_heal_threshold:render("Greater Heal Threshold", "Emergency Greater Heals under this percent")
            menu.prayer_of_healing_enabled:render("Prayer of Healing", "Allow Prayer of Healing when multiple targets are hurt")
            menu.prayer_of_healing_threshold:render("PoH Threshold", "Health percent that counts targets toward PoH")
            menu.prayer_of_healing_count:render("PoH Count", "Minimum wounded allies to fire Prayer of Healing")
            menu.auto_prayer_of_mending:render("Auto Prayer of Mending", "Refresh PoM on wounded allies without clipping Renew")
            menu.prayer_of_mending_threshold:render("PoM Threshold", "Health percent that triggers PoM refresh")
            menu.overheal_protection:render("Overheal Protection", "Cancel slow heals when target is near full HP")
        end)

        -- ── Defensive cooldowns ───────────────────────────────────────────────
        ps.render_defensive(menu, def_tree, {
        -- (none detected)
        })

        -- ── Targeting ────────────────────────────────────────────────────────
        ps.render_targeting(menu, tgt_tree)

        -- ── Racial ────────────────────────────────────────────────────────────
        ps.render_racial(menu, racial_tree)

        -- ── Out-of-combat ─────────────────────────────────────────────────────
        ps.render_ooc(menu, ooc_tree, true)

        -- ── Display & HUD ─────────────────────────────────────────────────────
        ps.render_esp(menu, esp_tree)

    end)
end

return menu
