-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Paladin Retribution
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
menu.enabled                             = core.menu.checkbox(true, "eaxpaladinretribution_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpaladinretribution_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpaladinretribution_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpaladinretribution_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpaladinretribution_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpaladinretribution_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpaladinretribution_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpaladinretribution_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpaladinretribution_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpaladinretribution_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- ── Class-specific elements ───────────────────────────────────────────────────
menu.use_judgement                        = core.menu.checkbox(true, "eaxpr_use_judgement")
menu.judgement_choice                     = core.menu.combobox(1, "eaxpr_judgement_choice")
menu.use_crusader_strike                  = core.menu.checkbox(true, "eaxpr_use_crusader_strike")
menu.use_seal_twist                       = core.menu.checkbox(true, "eaxpr_use_seal_twist")
menu.seal_twist_window                    = core.menu.slider_int(200, 1200, 450, "eaxpr_seal_twist_window")
menu.seal_twist_cooldown                  = core.menu.slider_int(800, 4000, 1600, "eaxpr_seal_twist_cooldown")
menu.allow_twist_dungeon                  = core.menu.checkbox(true, "eaxpr_twist_dungeon")
menu.allow_twist_raid                     = core.menu.checkbox(false, "eaxpr_twist_raid")

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
        ps.draw_space(_win, "eaxpaladinretribution")
    end

    root_tree:render("  Eax's Paladin Retribution", function()

        ps.render_controls(menu, "Eax's Paladin Retribution")

        -- ── Class-specific settings ───────────────────────────────────────────
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_judgement:render("Judgement", "Maintain the chosen judgement debuff")
            menu.use_crusader_strike:render("Crusader Strike", "Cast on cooldown when the GCD is ready")
            menu.use_seal_twist:render("Enable Seal Twists", "Rotate Command → Blood → Righteousness for seal-twisting uptime")
            menu.seal_twist_window:render("Twist Window (ms)", "Delay twists until at least this many ms before the next swing")
            menu.seal_twist_cooldown:render("Twist Cooldown (ms)", "Minimum time between completed twists")
            menu.allow_twist_dungeon:render("Allow in Dungeon", "Permit twisting when dungeon mode is active")
            menu.allow_twist_raid:render("Allow in Raid", "Optional twisting for raid mode (disabled by default)")
            menu.judgement_choice:render("Judgement Mode", { "Wisdom", "Crusader" })
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
