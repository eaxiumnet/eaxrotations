-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Paladin Protection
-- ║  Space Theme v4.0  ·  Stars drawn inside the panel background
-- ╚══════════════════════════════════════════════════════════════════╝

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
menu.enabled                             = core.menu.checkbox(true, "eaxpaladinprotection_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpaladinprotection_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpaladinprotection_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpaladinprotection_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpaladinprotection_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpaladinprotection_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpaladinprotection_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpaladinprotection_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpaladinprotection_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpaladinprotection_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- ── Class-specific elements ───────────────────────────────────────────────────
menu.show_notifications                   = core.menu.checkbox(false, "eaxpaladinprot_notifications")
menu.use_righteous_fury                   = core.menu.checkbox(true, "eaxpaladinprot_use_righteous_fury")
menu.use_holy_shield                      = core.menu.checkbox(true, "eaxpaladinprot_use_holy_shield")
menu.use_consecration                     = core.menu.checkbox(true, "eaxpaladinprot_use_consecration")
menu.consecration_enemy_count             = core.menu.slider_int(2, 6, 3, "eaxpaladinprot_consecration_enemy_count")
menu.consecration_radius                  = core.menu.slider_int(6, 12, 8, "eaxpaladinprot_consecration_radius")
menu.use_avengers_shield                  = core.menu.checkbox(true, "eaxpaladinprot_use_avengers_shield")
menu.use_judgement                        = core.menu.checkbox(true, "eaxpaladinprot_use_judgement")

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
        ps.draw_space(_win, "eaxpaladinprotection")
    end

    root_tree:render("  Eax's Paladin Protection", function()

        ps.render_controls(menu, "Eax's Paladin Protection")

        -- ── Class-specific settings ───────────────────────────────────────────
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.show_notifications:render("Notifications", "Show short on-screen reminders")
            menu.use_righteous_fury:render("Righteous Fury", "Keep the threat buff active")
            menu.use_holy_shield:render("Holy Shield", "Maintain Holy Shield for mitigation and reflection")
            menu.use_consecration:render("Consecration", "Cast Consecration when enough enemies are nearby")
            menu.consecration_enemy_count:render("Consecration Count", "Minimum enemies within radius before Consecration")
            menu.consecration_radius:render("Consecration Radius", "Radius used when counting enemies for Consecration")
            menu.use_avengers_shield:render("Avenger's Shield", "Use Avenger's Shield when fighting from range")
            menu.use_judgement:render("Judgement", "Apply Judgement of the Crusader once per target when ready")
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
        ps.render_ooc(menu, ooc_tree, false)

        -- ── Display & HUD ─────────────────────────────────────────────────────
        ps.render_esp(menu, esp_tree)

    end)
end

return menu
