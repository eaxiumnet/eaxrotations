-- +------------------------------------------------------------------+
-- |  Eax's Mage Arcane
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+
local mana_conservator = require("libraries/mana_conservator")

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- -- Tree nodes ----------------------------------------------------------------
local root_tree    = ps.tree_node()
local main_tree    = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local ooc_tree     = ps.tree_node()
-- local esp_tree     = ps.tree_node()

-- -- Shared plugin controls + shared fields ------------------------------------
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxmagearcane_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxmagearcane_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxmagearcane_mode")
menu.debug                               = core.menu.checkbox(false, "eaxmagearcane_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxmagearcane_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxmagearcane_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxmagearcane_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxmagearcane_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- menu.auto_repair                        = core.menu.checkbox(true, "eaxmagearcane_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxmagearcane_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxmagearcane_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxmagearcane_auto_dismount")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxmagearcane_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxmagearcane_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxmagearcane_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxmagearcane_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxmagearcane_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxmagearcane_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxmagearcane_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxmagearcane_spirit_tap_wand")
-- ESP
-- menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
-- menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
-- menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
-- menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")
-- -- Class-specific elements ---------------------------------------------------
menu.use_arcane_blast                     = core.menu.checkbox(true, "eax_mage_arcane_use_arcane_blast")
menu.use_arcane_missiles                  = core.menu.checkbox(true, "eax_mage_arcane_use_arcane_missiles")
menu.use_fire_blast_move                  = core.menu.checkbox(true, "eax_mage_arcane_use_fire_blast_move")
menu.use_remove_curse                     = core.menu.checkbox(true, "eax_mage_arcane_use_remove_curse")
menu.use_arcane_explosion                 = core.menu.checkbox(true, "eax_mage_arcane_use_arcane_explosion")
menu.arcane_blast_dump_stacks             = core.menu.slider_int(2, 4, 3, "eax_mage_arcane_dump_stacks")
menu.use_arcane_power                     = core.menu.checkbox(true, "eax_mage_arcane_use_arcane_power")
menu.use_trinkets                         = core.menu.checkbox(true, "eax_mage_arcane_use_trinkets")
menu.use_cooldowns                        = core.menu.checkbox(true, "eax_mage_arcane_use_cooldowns")
menu.burn_mana_pct                        = core.menu.slider_int(20, 100, 60, "eax_mage_arcane_burn_mana_pct")
menu.use_mana_gem                         = core.menu.checkbox(true, "eax_mage_arcane_use_mana_gem")
menu.use_evocation                        = core.menu.checkbox(true, "eax_mage_arcane_use_evocation")
menu.use_frost_nova                       = core.menu.checkbox(true, "eax_mage_arcane_use_frost_nova")
menu.use_presence_of_mind                 = core.menu.checkbox(true, "eax_mage_arcane_use_presence_of_mind")
menu.mana_gem_pct                         = core.menu.slider_int(10, 90, 45, "eax_mage_arcane_mana_gem_pct")
menu.evocation_pct                        = core.menu.slider_int(5, 60, 20, "eax_mage_arcane_evocation_pct")
menu.use_ice_block                        = core.menu.checkbox(true, "eax_mage_arcane_use_ice_block")
menu.ice_block_hp_pct                     = core.menu.slider_int(0, 100, 30, "eax_mage_arcane_ice_block_hp_pct")

mana_conservator.register_menu_items(menu, "eax_mage_arcane")

-- ----------------------------------------------------------------------------
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ----------------------------------------------------------------------------

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_arcane_blast", label = "Arcane Blast" },
    { toggle = "use_arcane_missiles", label = "Arcane Missiles" },
    { toggle = "use_arcane_power", label = "Arcane Power" },
    { toggle = "use_mana_gem", label = "Mana Gem" },
    { toggle = "use_evocation", label = "Evocation" },
}, {
    namespace = "eaxmagearcane",
    log_prefix = "[Eax Mage Arcane] ",
})

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "EAXMageArcane")
    end
    
    root_tree:render("Eax's Mage Arcane", function()

        ps.render_controls(menu, "Eax's Mage Arcane")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_arcane_blast:render("Arcane Blast", "Primary filler and stack builder")
            menu.use_arcane_missiles:render("Arcane Missiles", "Dump Arcane Blast stacks in sustain windows")
            menu.use_fire_blast_move:render("Fire Blast While Moving", "Use Fire Blast as the moving fallback")
            menu.use_remove_curse:render("Remove Curse", "Use Remove Curse on cursed allies during combat")
            menu.use_arcane_explosion:render("Arcane Explosion", "Use Arcane Explosion for close-range AoE")
            menu.arcane_blast_dump_stacks:render("Dump At AB Stacks", "Cast Arcane Missiles at or above this Arcane Blast stack count")
            menu.use_arcane_power:render("Arcane Power", "Use Arcane Power during burst windows")
            menu.use_trinkets:render("Trinkets", "Use self-cast trinkets during burst windows")
            menu.burn_mana_pct:render("Burn Mana %", "Minimum mana percent required to open Arcane Power burst")
            menu.use_mana_gem:render("Mana Gem", "Use Mana Gem when mana drops below the configured threshold")
            menu.use_evocation:render("Evocation", "Channel Evocation when mana is low")
            menu.mana_gem_pct:render("Mana Gem %", "Use Mana Gem below this mana percent")
            menu.evocation_pct:render("Evocation %", "Use Evocation below this mana percent")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_ice_block", label = "Ice Block", tip = "Use Ice Block as an emergency cooldown", hp_key = "ice_block_hp_pct", hp_label = "Ice Block Hp Percent" },
        })

        -- -- Targeting --------------------------------------------------------
        ps.render_targeting(menu, tgt_tree)

        -- -- Racial ------------------------------------------------------------
        ps.render_racial(menu, racial_tree)

        -- -- Out-of-combat -----------------------------------------------------
--         menu.auto_repair:render("Auto Repair", "Automatically repair gear at vendors")
--         menu.auto_sell_greys:render("Auto Sell Greys", "Automatically sell poor-quality items at vendors")
--         menu.auto_mount:render("Auto Mount", "Automatically mount when traveling out of combat")
--         menu.auto_dismount:render("Auto Dismount", "Automatically dismount when entering combat")
        menu.auto_ooc_food_drink:render("Auto OOC Food/Drink", "Use food and drink out of combat when needed")
        menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")
        ps.render_ooc(menu, ooc_tree, true)

        -- -- Display & HUD -----------------------------------------------------
    -- ps.render_esp(menu, esp_tree) -- DISABLED
    end)
end

menu.use_cone_of_cold = core.menu.checkbox(true, "eaxmagearcane_use_cone_of_cold")
return menu
