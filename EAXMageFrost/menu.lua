-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Mage Frost
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
menu.enabled                             = core.menu.checkbox(true, "eaxmagefrost_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxmagefrost_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxmagefrost_mode")
menu.debug                               = core.menu.checkbox(false, "eaxmagefrost_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxmagefrost_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxmagefrost_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxmagefrost_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxmagefrost_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxmagefrost_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxmagefrost_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxmagefrost_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxmagefrost_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxmagefrost_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxmagefrost_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- ── Class-specific elements ───────────────────────────────────────────────────
menu.use_frostbolt                        = core.menu.checkbox(true, "eax_mage_frost_use_frostbolt")
menu.use_ice_lance                        = core.menu.checkbox(true, "eax_mage_frost_use_ice_lance")
menu.use_fireball_proc                    = core.menu.checkbox(true, "eax_mage_frost_use_fireball_proc")
menu.ice_lance_execute_hp                 = core.menu.slider_int(5, 40, 20, "eax_mage_frost_ice_lance_execute_hp")
menu.use_icy_veins                        = core.menu.checkbox(true, "eax_mage_frost_use_icy_veins")
menu.use_water_elemental                  = core.menu.checkbox(true, "eax_mage_frost_use_water_elemental")
menu.use_trinkets                         = core.menu.checkbox(true, "eax_mage_frost_use_trinkets")
menu.use_ice_block                        = core.menu.checkbox(true, "eax_mage_frost_use_ice_block")
menu.ice_block_hp_pct                     = core.menu.slider_int(0, 100, 20, "eax_mage_frost_ice_block_hp_pct")

mana_conservator.register_menu_items(menu, "eax_mage_frost")

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
        ps.draw_space(_win, "eaxmagefrost")
    end

    root_tree:render("  Eax's Mage Frost", function()

        ps.render_controls(menu, "Eax's Mage Frost")

        -- ── Class-specific settings ───────────────────────────────────────────
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_frostbolt:render("Frostbolt", "Primary filler spell")
            menu.use_ice_lance:render("Ice Lance", "Use Ice Lance on frozen or execute-style targets")
            menu.use_fireball_proc:render("Fireball Proc", "Use Fireball when a Brain Freeze style proc buff is active")
            menu.ice_lance_execute_hp:render("Ice Lance Execute HP %", "Use Ice Lance when targets are low and frozen")
            menu.use_icy_veins:render("Icy Veins", "Use Icy Veins in combat")
            menu.use_water_elemental:render("Water Elemental", "Summon Water Elemental when available")
            menu.use_trinkets:render("Trinkets", "Use self-cast trinkets during burst windows")
        end)

        -- ── Defensive cooldowns ───────────────────────────────────────────────
        ps.render_defensive(menu, def_tree, {
        { key = "use_ice_block", label = "Ice Block", tip = "Use Ice Block as an emergency cooldown", hp_key = "ice_block_hp_pct", hp_label = "Ice Block Hp Percent" },
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
