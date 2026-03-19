-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Shaman Enhancement
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
menu.enabled                             = core.menu.checkbox(true, "eaxshamanenhancement_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxshamanenhancement_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxshamanenhancement_mode")
menu.debug                               = core.menu.checkbox(false, "eaxshamanenhancement_debug")
menu.shield_mode                         = core.menu.combobox(3, "eaxshamanenhancement_shield_mode")  -- 0=None,1=Lightning,2=Water,3=Auto
menu.use_healing_wave                    = core.menu.checkbox(true, "eaxshamanenhancement_use_hw")
menu.healing_wave_hp                     = core.menu.slider_int(10, 60, 40, "eaxshamanenhancement_hw_hp")
menu.use_lesser_healing_wave             = core.menu.checkbox(true, "eaxshamanenhancement_use_lhw")
menu.use_ghost_wolf                      = core.menu.checkbox(true, "eaxshamanenhancement_ghost_wolf")
menu.use_lb_pull                         = core.menu.checkbox(true, "eaxshamanenhancement_lb_pull")
menu.lb_pull_range                       = core.menu.slider_int(15, 40, 25, "eaxshamanenhancement_lb_pull_range")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxshamanenhancement_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxshamanenhancement_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxshamanenhancement_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxshamanenhancement_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxshamanenhancement_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxshamanenhancement_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_cooldowns                        = core.menu.checkbox(true, "use_cooldowns")
menu.use_chain_lightning_weave            = core.menu.checkbox(true, "use_chain_lightning_weave")
menu.swing_clip_ms                        = core.menu.slider_int(80, 220, 160, "swing_clip_ms")
menu.shock_mode                           = core.menu.combobox(1, "shock_mode")
menu.shamanistic_rage_hp                  = core.menu.slider_int(0, 100, 40, "shamanistic_rage_hp")
menu.shamanistic_rage_mana                = core.menu.slider_int(0, 100, 35, "shamanistic_rage_mana")
menu.dual_wield_focus                     = core.menu.checkbox(true, "dual_wield_focus")
menu.auto_totems                          = core.menu.checkbox(true, "auto_totems")
menu.auto_totem_wrath                     = core.menu.checkbox(true, "auto_totem_wrath")
menu.auto_totem_windfury                  = core.menu.checkbox(true, "auto_totem_windfury")
menu.prepull_totems                       = core.menu.checkbox(true, "prepull_totems")

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
        ps.draw_space(_win, "eaxshamanenhancement")
    end

    root_tree:render("  Eax's Shaman Enhancement", function()

        ps.render_controls(menu, "Eax's Shaman Enhancement")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_cooldowns:render("Use Cooldowns", "Stormstrike + Rage react to burst windows")
            menu.use_chain_lightning_weave:render("Chain Lightning Weave", "Allow Chain Lightning between auto-attacks")
            menu.swing_clip_ms:render("Swing Clip (ms)", "Chain Lightning weaves happen when swing delay exceeds this window")
            menu.shamanistic_rage_hp:render("Rage HP Trigger", "Cast Shamanistic Rage below this health %")
            menu.shamanistic_rage_mana:render("Rage Mana Trigger", "Cast Rage below this mana %")
            menu.dual_wield_focus:render("Dual Wield Focus", "Prioritize dual-wield uptime and snapshots")
            menu.auto_totems:render("Auto Totems", "Keep Totem of Wrath and Windfury active")
            menu.auto_totem_wrath:render("Totem of Wrath", "Drive the fire slot")
            menu.auto_totem_windfury:render("Windfury Totem", "Refresh Windfury for melee procs")
            menu.prepull_totems:render("Pre-pull Totems", "Cast totems before the fight starts")
            menu.shock_mode:render("Shock Mode", { "Earth", "Flame", "Frost" })
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
            {
                key      = "use_healing_wave",
                label    = "Emergency Healing Wave",
                tip      = "Cast Healing Wave when HP drops below threshold",
                hp_key   = "healing_wave_hp",
                hp_label = "Self-Heal HP %",
            },
            {
                key      = "use_cooldowns",
                label    = "Shamanistic Rage",
                tip      = "Use Shamanistic Rage when HP or mana is low (controlled by Use Cooldowns toggle)",
            },
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
