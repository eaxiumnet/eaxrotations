-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Shaman Elemental
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
menu.enabled                             = core.menu.checkbox(true, "eaxshamanelemental_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxshamanelemental_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxshamanelemental_mode")
menu.debug                               = core.menu.checkbox(false, "eaxshamanelemental_debug")
menu.shield_mode                         = core.menu.combobox(2, "eaxshamanelemental_shield_mode")   -- 0=None,1=Lightning,2=Water,3=Auto
menu.use_healing_wave                    = core.menu.checkbox(true, "eaxshamanelemental_use_hw")
menu.healing_wave_hp                     = core.menu.slider_int(10, 60, 35, "eaxshamanelemental_hw_hp")
menu.use_ghost_wolf                      = core.menu.checkbox(true, "eaxshamanelemental_ghost_wolf")
menu.use_totemic_call                    = core.menu.checkbox(true, "eaxshamanelemental_totemic_call")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxshamanelemental_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxshamanelemental_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxshamanelemental_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxshamanelemental_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_repair                        = core.menu.checkbox(true, "eaxshamanelemental_auto_repair")
menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxshamanelemental_auto_sell_greys")
menu.auto_mount                         = core.menu.checkbox(true, "eaxshamanelemental_auto_mount")
menu.auto_dismount                      = core.menu.checkbox(true, "eaxshamanelemental_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxshamanelemental_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxshamanelemental_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxshamanelemental_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxshamanelemental_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxshamanelemental_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxshamanelemental_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxshamanelemental_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxshamanelemental_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxshamanelemental_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_cooldowns                        = core.menu.checkbox(true, "use_cooldowns")
menu.aoe_threshold                        = core.menu.slider_int(1, 6, 3, "aoe_threshold")
menu.mana_floor                           = core.menu.slider_int(5, 60, 25, "mana_floor")
menu.execute_hp                           = core.menu.slider_int(0, 75, 50, "execute_hp")
menu.use_flame_shock                      = core.menu.checkbox(true, "use_flame_shock")
menu.flame_shock_stop_hp                  = core.menu.slider_int(10, 60, 35, "flame_shock_stop_hp")
menu.chain_lightning_mana                 = core.menu.slider_int(20, 70, 45, "chain_lightning_mana")
menu.range_min                            = core.menu.slider_int(0, 30, 0, "range_min")
menu.range_max                            = core.menu.slider_int(25, 45, 32, "range_max")
menu.auto_totems                          = core.menu.checkbox(true, "auto_totems")
menu.auto_totem_wrath                     = core.menu.checkbox(true, "auto_totem_wrath")
menu.auto_totem_mana                      = core.menu.checkbox(true, "auto_totem_mana")
menu.totem_twist_interval                 = core.menu.slider_int(20, 60, 30, "totem_twist_interval")
menu.prepull_totems                       = core.menu.checkbox(true, "prepull_totems")

mana_conservator.register_menu_items(menu, "eax_shaman_elemental")

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
        ps.draw_space(_win, "eaxshamanelemental")
    end

    root_tree:render("  Eax's Shaman Elemental", function()

        ps.render_controls(menu, "Eax's Shaman Elemental")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_cooldowns:render("Use Burst Cooldowns", "Permit Elemental Mastery / Nature's Swiftness")
            menu.aoe_threshold:render("AoE Threshold", "Chain Lightning engages when enough enemies are clustered")
            menu.mana_floor:render("Mana Floor", "Prevent rotation when mana drops below this %")
            menu.execute_hp:render("Execute Cutoff", "Hold Flame Shock / Lightning Bolt during execute phase")
            menu.use_flame_shock:render("Use Flame Shock", "Maintain Flame Shock when stationary")
            menu.flame_shock_stop_hp:render("Flame Shock Stop HP", "Stop applying Flame Shock near execute")
            menu.chain_lightning_mana:render("Chain Lightning Mana", "Minimum mana % before AoE toggles")
            menu.range_min:render("Lightning Range Min", "Minimum target distance for Lightning Bolt")
            menu.range_max:render("Lightning Range Max", "Maximum target distance before spells fall back")
            menu.auto_totems:render("Auto Totems", "Twist Totem of Wrath + Mana Spring when toggled")
            menu.auto_totem_wrath:render("Totem of Wrath", "Keep the fire slot rolling")
            menu.auto_totem_mana:render("Mana Spring Totem", "Keep mana regen active")
            menu.totem_twist_interval:render("Totem Refresh (sec)", "Minimum seconds between auto twists")
            menu.prepull_totems:render("Pre-pull Totems", "Refresh totems before mounting a pull")
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
        })

        -- -- Targeting --------------------------------------------------------
        ps.render_targeting(menu, tgt_tree)

        -- -- Racial ------------------------------------------------------------
        ps.render_racial(menu, racial_tree)

        -- -- Out-of-combat -----------------------------------------------------
        menu.auto_repair:render("Auto Repair", "Automatically repair gear at vendors")
        menu.auto_sell_greys:render("Auto Sell Greys", "Automatically sell poor-quality items at vendors")
        menu.auto_mount:render("Auto Mount", "Automatically mount when traveling out of combat")
        menu.auto_dismount:render("Auto Dismount", "Automatically dismount when entering combat")
        menu.auto_combat_potions:render("Auto Combat Potions", "Use combat potions automatically when appropriate")
        menu.auto_ooc_food_drink:render("Auto OOC Food/Drink", "Use food and drink out of combat when needed")
        menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")
        ps.render_ooc(menu, ooc_tree, true)

        -- -- Display & HUD -----------------------------------------------------
        ps.render_esp(menu, esp_tree)

    end)
end

menu.use_earth_shock  = core.menu.checkbox(true, "eaxshamanele_earth_shock")
menu.use_frost_shock  = core.menu.checkbox(true, "eaxshamanele_frost_shock")
return menu
