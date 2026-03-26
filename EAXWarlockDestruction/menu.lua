-- +------------------------------------------------------------------+
-- |  Eax's Warlock Destruction
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
menu.enabled                             = core.menu.checkbox(true, "eaxwarlockdestruction_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarlockdestruction_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarlockdestruction_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarlockdestruction_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarlockdestruction_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarlockdestruction_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarlockdestruction_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarlockdestruction_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_repair                        = core.menu.checkbox(true, "eaxwarlockdestruction_auto_repair")
menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxwarlockdestruction_auto_sell_greys")
menu.auto_mount                         = core.menu.checkbox(true, "eaxwarlockdestruction_auto_mount")
menu.auto_dismount                      = core.menu.checkbox(true, "eaxwarlockdestruction_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxwarlockdestruction_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxwarlockdestruction_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxwarlockdestruction_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarlockdestruction_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarlockdestruction_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxwarlockdestruction_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxwarlockdestruction_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxwarlockdestruction_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxwarlockdestruction_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.profile                              = core.menu.combobox(1, "eax_destruction_profile")
menu.use_fel_armor                        = core.menu.checkbox(true, "eax_destruction_use_fel_armor")
menu.use_curse                            = core.menu.checkbox(true, "eax_destruction_use_curse")
menu.curse_mode                           = core.menu.combobox(1, "eax_destruction_curse_mode")
menu.use_immolate                         = core.menu.checkbox(true, "eax_destruction_use_immolate")
menu.use_conflagrate                      = core.menu.checkbox(true, "eax_destruction_use_conflagrate")
menu.use_shadowfury                       = core.menu.checkbox(true, "eax_destruction_use_shadowfury")
menu.use_shadow_bolt                      = core.menu.checkbox(true, "eax_destruction_use_shadow_bolt")
menu.use_incinerate                       = core.menu.checkbox(true, "eax_destruction_use_incinerate")
menu.use_shadow_burn                      = core.menu.checkbox(true, "eax_destruction_use_shadow_burn")
menu.use_soul_fire                        = core.menu.checkbox(true, "eax_destruction_use_soul_fire")
menu.use_drain_soul                       = core.menu.checkbox(true, "eax_destruction_use_drain_soul")
menu.use_seed_of_corruption               = core.menu.checkbox(true, "eax_destruction_use_seed_of_corruption")
menu.use_life_tap                         = core.menu.checkbox(true, "eax_destruction_use_life_tap")
menu.life_tap_threshold                   = core.menu.slider_int(10, 80, 40, "eax_destruction_lifetap_pct")
menu.preferred_pet                        = core.menu.combobox(1, "eax_destruction_preferred_pet")
menu.auto_shard_farm                      = core.menu.checkbox(true, "eax_destruction_auto_shard_farm")
menu.min_shards                           = core.menu.slider_int(0, 10, 3, "eax_destruction_min_shards")

mana_conservator.register_menu_items(menu, "eax_warlock_destruction")

-- ----------------------------------------------------------------------------
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ----------------------------------------------------------------------------

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_curse", label = "Curse" },
    { toggle = "use_immolate", label = "Immolate" },
    { toggle = "use_conflagrate", label = "Conflagrate" },
    { toggle = "use_incinerate", label = "Incinerate" },
    { toggle = "use_shadow_bolt", label = "Shadow Bolt" },
    { toggle = "use_shadow_burn", label = "Shadow Burn" },
    { toggle = "use_drain_soul", label = "Drain Soul" },
    { toggle = "use_shadowfury", label = "Shadowfury" },
}, {
    namespace = "eaxwarlockdestruction",
    log_prefix = "[Eax Warlock Destruction] ",
})

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxwarlockdestruction")
    end

    root_tree:render("Eax's Warlock Destruction", function()

        ps.render_controls(menu, "Eax's Warlock Destruction")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_fel_armor:render("Fel Armor", "Maintain Fel Armor when available")
            menu.use_curse:render("Curse", "Maintain the selected TBC curse on the target")
            menu.curse_mode:render("Curse Mode", { "Auto", "Elements", "Agony", "Doom", "Recklessness", "Tongues", "Weakness" })
            menu.use_immolate:render("Immolate", "Maintain Immolate on the target")
            menu.use_conflagrate:render("Conflagrate", "Use Conflagrate when ready")
            menu.use_shadowfury:render("Shadowfury", "Use Shadowfury on spellcasters")
            menu.use_shadow_bolt:render("Shadow Bolt", "Shadow primary for the Shadow profile")
            menu.use_incinerate:render("Incinerate", "Fire primary for the Fire profile")
            menu.use_shadow_burn:render("Shadow Burn", "Use Shadow Burn in execute range")
            menu.use_soul_fire:render("Soul Fire", "Use Soul Fire as a hard-cast nuke when appropriate")
            menu.use_drain_soul:render("Drain Soul", "Use Drain Soul as the execute channel")
            menu.use_seed_of_corruption:render("Seed of Corruption", "Use Seed of Corruption for AoE")
            menu.use_life_tap:render("Life Tap", "Regen mana when health permits")
            menu.life_tap_threshold:render("Life Tap HP %", "Minimum percent health to Life Tap")
            menu.profile:render("Profile", { "Auto", "Fire", "Shadow" })
            menu.preferred_pet:render("Pet Summon", { "Disabled", "Imp", "Voidwalker", "Succubus", "Felhunter", "Felguard" })
            menu.auto_shard_farm:render("Auto Shard Farm", "Use Drain Soul on low-HP targets when shards are low")
            menu.min_shards:render("Min Shards", "Keep at least this many Soul Shards")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_drain_life_def", label = "Drain Life", tip = "Emergency self-heal via Drain Life", hp_key = "use_drain_life_def_hp_pct", hp_label = "Drain Life HP %" },
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

menu.use_drain_life_def = core.menu.checkbox(true, "eaxdest_drain_life_def")
menu.use_drain_life_def_hp_pct = core.menu.slider_int(0, 100, 35, "eaxdest_drain_life_hp")
return menu
