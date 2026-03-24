-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Warlock Demonology
-- ║  Space Theme v4.0  ·  Stars drawn inside the panel background
-- ╚══════════════════════════════════════════════════════════════════╝
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
menu.enabled                             = core.menu.checkbox(true, "eaxwarlockdemonology_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarlockdemonology_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarlockdemonology_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarlockdemonology_debug")
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarlockdemonology_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarlockdemonology_combat_self_hp_boost")
menu.use_racial                          = core.menu.checkbox(true, "eaxwarlockdemonology_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarlockdemonology_racial_hp")
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_repair                         = core.menu.checkbox(true, "eaxwarlockdemonology_auto_repair")
menu.auto_sell_greys                     = core.menu.checkbox(true, "eaxwarlockdemonology_auto_sell_greys")
menu.auto_mount                          = core.menu.checkbox(true, "eaxwarlockdemonology_auto_mount")
menu.auto_dismount                       = core.menu.checkbox(true, "eaxwarlockdemonology_auto_dismount")
menu.auto_combat_potions                 = core.menu.checkbox(false, "eaxwarlockdemonology_auto_combat_potions")
menu.auto_ooc_food_drink                 = core.menu.checkbox(true, "eaxwarlockdemonology_auto_ooc_food_drink")
menu.auto_flask                          = core.menu.checkbox(false, "eaxwarlockdemonology_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarlockdemonology_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarlockdemonology_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxwarlockdemonology_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxwarlockdemonology_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxwarlockdemonology_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxwarlockdemonology_spirit_tap_wand")
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.preferred_pet                       = core.menu.combobox(1, "eax_demonology_preferred_pet")
menu.maintain_soul_link                  = core.menu.checkbox(true, "eax_demonology_soul_link")
menu.use_fel_armor                       = core.menu.checkbox(true, "eax_demonology_use_fel_armor")
menu.use_curse                           = core.menu.checkbox(true, "eax_demonology_use_curse")
menu.curse_mode                          = core.menu.combobox(1, "eax_demonology_curse_mode")
menu.use_immolate                        = core.menu.checkbox(true, "eax_demonology_use_immolate")
menu.use_corruption                      = core.menu.checkbox(true, "eax_demonology_use_corruption")
menu.use_unstable_affliction             = core.menu.checkbox(false, "eax_demonology_use_unstable_affliction")
menu.use_soul_fire                       = core.menu.checkbox(true, "eax_demonology_use_soul_fire")
menu.use_shadow_bolt                     = core.menu.checkbox(true, "eax_demonology_use_shadow_bolt")
menu.use_shadow_burn                     = core.menu.checkbox(true, "eax_demonology_use_shadow_burn")
menu.use_drain_soul                      = core.menu.checkbox(true, "eax_demonology_use_drain_soul")
menu.use_shadowfury                      = core.menu.checkbox(true, "eax_demonology_use_shadowfury")
menu.use_life_tap                        = core.menu.checkbox(true, "eax_demonology_use_life_tap")
menu.life_tap_threshold                  = core.menu.slider_int(10, 80, 35, "eax_demonology_lifetap_pct")
menu.pet_check_interval                  = core.menu.slider_int(1, 10, 4, "eax_demonology_pet_check")
menu.use_banish                          = core.menu.checkbox(true, "eax_wrl_dem_use_banish")

mana_conservator.register_menu_items(menu, "eax_warlock_demonology")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_curse", label = "Curse" },
    { toggle = "use_immolate", label = "Immolate" },
    { toggle = "use_corruption", label = "Corruption" },
    { toggle = "use_shadow_bolt", label = "Shadow Bolt" },
    { toggle = "use_shadowfury", label = "Shadowfury" },
}, {
    namespace = "eaxwarlockdemonology",
    log_prefix = "[EAX Warlock Demonology] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarlockdemonology")
    end

    root_tree:render("  Eax's Warlock Demonology", function()
        ps.render_controls(menu, "Eax's Warlock Demonology")

        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.preferred_pet:render("Pet Summon", { "Disabled", "Imp", "Voidwalker", "Succubus", "Felhunter", "Felguard" })
            menu.maintain_soul_link:render("Soul Link", "Keep Soul Link active when possible")
            menu.use_fel_armor:render("Fel Armor", "Maintain Fel Armor outside and inside combat")
            menu.use_curse:render("Curse", "Maintain the selected TBC curse on your target")
            menu.curse_mode:render("Curse Mode", { "Agony", "Elements", "Weakness", "Tongues" })
            menu.use_immolate:render("Immolate", "Maintain Immolate on the target")
            menu.use_corruption:render("Corruption", "Maintain Corruption on the target")
            menu.use_unstable_affliction:render("Unstable Affliction", "Use UA only if the spell is actually available")
            menu.use_soul_fire:render("Soul Fire", "Cast Soul Fire as a high-damage nuke when ready")
            menu.use_shadow_bolt:render("Shadow Bolt", "Use Shadow Bolt as the primary filler")
            menu.use_shadow_burn:render("Shadowburn", "Fire Shadowburn during execute range")
            menu.use_drain_soul:render("Drain Soul", "Channel Drain Soul below 25% target HP")
            menu.use_shadowfury:render("Shadowfury", "Use Shadowfury for interrupts or clustered enemies")
            menu.use_life_tap:render("Life Tap", "Regain mana when health permits")
            menu.life_tap_threshold:render("Life Tap HP %", "Minimum health percent required to Life Tap")
            menu.pet_check_interval:render("Pet Refresh Interval", "Seconds between pet checks")
            menu.use_banish:render("Banish", "Crowd control demons and elementals when appropriate")
        end)

        ps.render_defensive(menu, def_tree, {
        { key = "use_drain_life_def", label = "Drain Life", tip = "Emergency self-heal via Drain Life", hp_key = "use_drain_life_def_hp_pct", hp_label = "Drain Life HP %" },
        })

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)

        menu.auto_repair:render("Auto Repair", "Automatically repair gear at vendors")
        menu.auto_sell_greys:render("Auto Sell Greys", "Automatically sell poor-quality items at vendors")
        menu.auto_mount:render("Auto Mount", "Automatically mount when traveling out of combat")
        menu.auto_dismount:render("Auto Dismount", "Automatically dismount when entering combat")
        menu.auto_combat_potions:render("Auto Combat Potions", "Use combat potions automatically when appropriate")
        menu.auto_ooc_food_drink:render("Auto OOC Food/Drink", "Use food and drink out of combat when needed")
        menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")
        ps.render_ooc(menu, ooc_tree, true)
        ps.render_esp(menu, esp_tree)
    end)
end

menu.use_drain_life_def = core.menu.checkbox(true, "eaxdemo_drain_life_def")
menu.use_drain_life_def_hp_pct = core.menu.slider_int(0, 100, 35, "eaxdemo_drain_life_hp")

return menu
