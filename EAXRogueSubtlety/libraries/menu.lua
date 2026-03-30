-- +------------------------------------------------------------------+
-- |  Eax's Rogue Subtlety
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

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
local POISON_OPTIONS = { "Disabled", "Instant", "Deadly", "Wound", "Crippling", "Mind-Numbing" }

-- -- Shared plugin controls + shared fields ------------------------------------
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxroguesubtlety_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxroguesubtlety_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxroguesubtlety_mode")
menu.debug                               = core.menu.checkbox(false, "eaxroguesubtlety_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxroguesubtlety_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxroguesubtlety_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxroguesubtlety_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxroguesubtlety_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- menu.auto_repair                        = core.menu.checkbox(true, "eaxroguesubtlety_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxroguesubtlety_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxroguesubtlety_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxroguesubtlety_auto_dismount")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxroguesubtlety_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxroguesubtlety_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxroguesubtlety_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxroguesubtlety_lev_mana_floor")
-- ESP
-- menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
-- menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
-- menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
-- menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")
-- -- Class-specific elements ---------------------------------------------------
menu.use_premeditation                    = core.menu.checkbox(true, "eaxroguesubtlety_use_premeditation")
menu.use_cheap_shot                       = core.menu.checkbox(true, "eaxroguesubtlety_use_cheap_shot")
menu.use_ambush                           = core.menu.checkbox(true, "eaxroguesubtlety_use_ambush")
menu.use_expose_armor                     = core.menu.checkbox(false, "eaxroguesubtlety_use_expose_armor")
menu.use_backstab                         = core.menu.checkbox(true, "eaxroguesubtlety_use_backstab")
menu.use_hemorrhage                       = core.menu.checkbox(true, "eaxroguesubtlety_use_hemorrhage")
menu.use_slice_and_dice                   = core.menu.checkbox(true, "eaxroguesubtlety_use_slice_and_dice")
menu.use_rupture                          = core.menu.checkbox(true, "eaxroguesubtlety_use_rupture")
menu.use_eviscerate                       = core.menu.checkbox(true, "eaxroguesubtlety_use_eviscerate")
menu.use_shadowstep                       = core.menu.checkbox(true, "eaxroguesubtlety_use_shadowstep")
menu.use_preparation                      = core.menu.checkbox(true, "eaxroguesubtlety_use_preparation")
menu.use_cooldowns                        = core.menu.checkbox(true, "eaxroguesubtlety_use_cooldowns")
menu.use_feint                            = core.menu.checkbox(true, "eaxroguesubtlety_use_feint")
menu.snd_refresh_seconds                  = core.menu.slider_int(1, 6, 3, "eaxroguesubtlety_snd_refresh_seconds")
menu.finisher_combo_points                = core.menu.slider_int(3, 5, 4, "eaxroguesubtlety_finisher_combo_points")
menu.main_hand_poison                     = core.menu.combobox(2, "eaxroguesubtlety_main_hand_poison")
menu.off_hand_poison                      = core.menu.combobox(3, "eaxroguesubtlety_off_hand_poison")

-- ----------------------------------------------------------------------------
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ----------------------------------------------------------------------------

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_cheap_shot", label = "Cheap Shot" },
    { toggle = "use_backstab", label = "Backstab" },
    { toggle = "use_hemorrhage", label = "Hemorrhage" },
    { toggle = "use_shadowstep", label = "Shadowstep" },
    { toggle = "use_preparation", label = "Preparation" },
}, {
    namespace = "eaxroguesubtlety",
    log_prefix = "[Eax Rogue Subtlety] ",
})

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxroguesubtlety")
    end

    root_tree:render("Eax's Rogue Subtlety", function()

        ps.render_controls(menu, "Eax's Rogue Subtlety")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_premeditation:render("Premeditation", "Build combo points before the opener")
            menu.use_cheap_shot:render("Cheap Shot", "Preferred control opener in dungeon and raid")
            menu.use_ambush:render("Ambush", "Solo stealth damage opener")
            menu.use_expose_armor:render("Expose Armor", "Group assignment: apply armor reduction when requested")
            menu.use_backstab:render("Backstab", "Primary behind-target builder")
            menu.use_hemorrhage:render("Hemorrhage", "Fallback builder when Backstab is not ideal")
            menu.use_slice_and_dice:render("Slice and Dice", "Maintain Slice and Dice before burst finishers")
            menu.use_rupture:render("Rupture", "Sustained finisher")
            menu.use_eviscerate:render("Eviscerate", "Burst finisher")
            menu.use_shadowstep:render("Shadowstep", "Close gaps for stealth-style burst windows")
            menu.use_preparation:render("Preparation", "Reset stealth tools in raid-style burst windows")
            menu.snd_refresh_seconds:render("SnD Refresh", "Refresh Slice and Dice below this many seconds")
            menu.finisher_combo_points:render("Finisher CP", "Minimum combo points before finishers")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_evasion", label = "Evasion", tip = "Emergency dodge cooldown", hp_key = "use_evasion_hp_pct", hp_label = "Evasion HP %" },
        { key = "use_cloak", label = "Cloak of Shadows", tip = "Dispel magic debuffs and gain immunity", hp_key = "use_cloak_hp_pct", hp_label = "Cloak of Shadows HP %" },
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
        menu.main_hand_poison:render("Main Hand Poison", POISON_OPTIONS)
        menu.off_hand_poison:render("Off Hand Poison", POISON_OPTIONS)
        menu.auto_combat_potions:render("Auto Combat Potions", "Use combat potions automatically when appropriate")
        menu.auto_ooc_food_drink:render("Auto OOC Food/Drink", "Use food and drink out of combat when needed")
        menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")
        ps.render_ooc(menu, ooc_tree, false)

        -- -- Display & HUD -----------------------------------------------------
    -- ps.render_esp(menu, esp_tree) -- DISABLED
    end)
end

menu.use_evasion = core.menu.checkbox(true, "eaxroguesubtlety_use_evasion")
menu.use_evasion_hp_pct = core.menu.slider_int(0, 100, 35, "eaxroguesubtlety_evas_hp")
menu.use_cloak = core.menu.checkbox(true, "eaxroguesubtlety_use_cloak")
menu.use_cloak_hp_pct = core.menu.slider_int(0, 100, 60, "eaxroguesubtlety_cloak_hp")
menu.auto_apply_poisons = core.menu.checkbox(true, "eaxroguesubtlety_auto_apply_poisons")
return menu
