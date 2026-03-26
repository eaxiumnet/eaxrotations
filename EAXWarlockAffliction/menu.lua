-- +------------------------------------------------------------------+
-- |  Eax's Warlock Affliction
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+
local mana_conservator = require("mana_conservator")

local ps   = require("ps_theme")
local settings = require("settings_framework")
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
menu.enabled                             = core.menu.checkbox(true, "eaxwarlockaffliction_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarlockaffliction_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarlockaffliction_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarlockaffliction_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarlockaffliction_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarlockaffliction_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarlockaffliction_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarlockaffliction_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_repair                        = core.menu.checkbox(true, "eaxwarlockaffliction_auto_repair")
menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxwarlockaffliction_auto_sell_greys")
menu.auto_mount                         = core.menu.checkbox(true, "eaxwarlockaffliction_auto_mount")
menu.auto_dismount                      = core.menu.checkbox(true, "eaxwarlockaffliction_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarlockaffliction_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarlockaffliction_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarlockaffliction_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarlockaffliction_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarlockaffliction_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxwarlockaffliction_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxwarlockaffliction_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxwarlockaffliction_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxwarlockaffliction_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.use_unstable_affliction              = core.menu.checkbox(true, "eax_affliction_use_ua")
menu.use_corruption                       = core.menu.checkbox(true, "eax_affliction_use_corruption")
menu.use_siphon_life                      = core.menu.checkbox(true, "eax_affliction_use_siphon_life")
menu.use_curse                            = core.menu.checkbox(true, "eax_affliction_use_curse")
menu.prefer_doom                          = core.menu.checkbox(true, "eax_affliction_prefer_doom")
menu.use_shadow_bolt                      = core.menu.checkbox(true, "eax_affliction_use_shadow_bolt")
menu.use_drain_soul                       = core.menu.checkbox(true, "eax_affliction_use_drain_soul")
menu.use_seed_of_corruption               = core.menu.checkbox(true, "eax_affliction_use_seed_of_corruption")
menu.use_howl_of_terror                   = core.menu.checkbox(true, "eax_affliction_use_howl_of_terror")
menu.preferred_pet                        = core.menu.combobox(1, "eax_affliction_preferred_pet")
menu.auto_shard_farm                      = core.menu.checkbox(true, "eax_affliction_auto_shard_farm")
menu.min_shards                           = core.menu.slider_int(0, 10, 3, "eax_affliction_min_shards")
menu.use_cooldowns                        = core.menu.checkbox(true, "eax_affliction_use_cooldowns")
menu.use_life_tap                         = core.menu.checkbox(true, "eax_affliction_use_life_tap")
menu.life_tap_threshold                   = core.menu.slider_int(10, 70, 35, "eax_affliction_lifetap_pct")

mana_conservator.register_menu_items(menu, "eax_warlock_affliction")

-- ----------------------------------------------------------------------------
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ----------------------------------------------------------------------------

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_unstable_affliction", label = "Unstable Affliction" },
    { toggle = "use_corruption", label = "Corruption" },
    { toggle = "use_curse", label = "Curse" },
    { toggle = "use_drain_soul", label = "Drain Soul" },
    { toggle = "use_life_tap", label = "Life Tap" },
}, {
    namespace = "eaxwarlockaffliction",
    log_prefix = "[Eax Warlock Affliction] ",
})

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxwarlockaffliction")
    end

    root_tree:render("Eax's Warlock Affliction", function()

        ps.render_controls(menu, "Eax's Warlock Affliction")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_unstable_affliction:render("Unstable Affliction", "Maintain the primary DoT")
            menu.use_corruption:render("Corruption", "Keep Corruption on the current target")
            menu.use_siphon_life:render("Siphon Life", "Keep Siphon Life active")
            menu.use_curse:render("Curse", "Apply Agony or Doom")
            menu.prefer_doom:render("Prefer Doom", "Use Curse of Doom when both curses are available")
            menu.use_shadow_bolt:render("Shadow Bolt", "Use Shadow Bolt as the filler spell")
            menu.use_drain_soul:render("Drain Soul", "Execute with Drain Soul below 25% HP")
            menu.use_life_tap:render("Life Tap", "Life Tap for extra mana")
            menu.life_tap_threshold:render("Life Tap HP %", "Life Tap when health is above this percent")
            menu.preferred_pet:render("Pet Summon", { "Disabled", "Imp", "Voidwalker", "Succubus", "Felhunter", "Felguard" })
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_drain_life_def", label = "Drain Life", tip = "Emergency self-heal via Drain Life", hp_key = "use_drain_life_def_hp_pct", hp_label = "Drain Life HP %" },
        { key = "use_soulstone", label = "Soulstone", tip = "Pre-apply Soulstone before combat for self-rez" },
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

menu.use_curse_of_elements = core.menu.checkbox(true, "eaxaff_curse_of_elements")
menu.use_death_coil       = core.menu.checkbox(true, "eaxaff_death_coil")
menu.use_drain_life_def = core.menu.checkbox(true, "eaxaff_drain_life_def")
menu.use_drain_life_def_hp_pct = core.menu.slider_int(0, 100, 35, "eaxaff_drain_life_hp")
menu.use_soulstone = core.menu.checkbox(true, "eaxaff_soulstone")
return menu
