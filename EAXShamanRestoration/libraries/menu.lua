-- +------------------------------------------------------------------+
-- |  Eax's Shaman Restoration
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+
local mana_conservator = require("libraries/mana_conservator")

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree    = ps.tree_node()
local rotation_tree = ps.tree_node()
local cd_tree      = ps.tree_node()
local auto_tree    = ps.tree_node()
local ooc_tree     = ps.tree_node()
local group_tree   = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local esp_tree     = ps.tree_node()

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxshamanrestoration_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxshamanrestoration_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxshamanrestoration_mode")
menu.debug                               = core.menu.checkbox(false, "eaxshamanrestoration_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxshamanrestoration_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxshamanrestoration_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxshamanrestoration_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxshamanrestoration_racial_hp")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxshamanrestoration_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxshamanrestoration_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxshamanrestoration_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxshamanrestoration_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxshamanrestoration_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxshamanrestoration_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxshamanrestoration_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxshamanrestoration_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxshamanrestoration_spirit_tap_wand")

-- Healing
menu.use_healing_wave                    = core.menu.checkbox(true, "eaxshamanrestoration_use_healing_wave")
menu.use_lesser_healing_wave             = core.menu.checkbox(true, "eaxshamanrestoration_use_lesser_healing_wave")
menu.use_earth_shield                    = core.menu.checkbox(true, "eaxshamanrestoration_use_earth_shield")
menu.use_chain_heal                      = core.menu.checkbox(true, "eaxshamanrestoration_use_chain_heal")
menu.use_riptide                         = core.menu.checkbox(true, "eaxshamanrestoration_use_riptide")
menu.use_mana_tide                       = core.menu.checkbox(true, "eaxshamanrestoration_use_mana_tide")
menu.use_bloodlust                       = core.menu.checkbox(true, "eaxshamanrestoration_use_bloodlust")
menu.use_heroism                         = core.menu.checkbox(true, "eaxshamanrestoration_use_heroism")
menu.use_earth_elemental                 = core.menu.checkbox(true, "eaxshamanrestoration_use_earth_elemental")
menu.use_searing_totem                   = core.menu.checkbox(true, "eaxshamanrestoration_use_searing_totem")
menu.use_magma_totem                     = core.menu.checkbox(true, "eaxshamanrestoration_use_magma_totem")
menu.use_fire_nova                       = core.menu.checkbox(true, "eaxshamanrestoration_use_fire_nova")
menu.use_totem_of_wrath                  = core.menu.checkbox(true, "eaxshamanrestoration_use_totem_of_wrath")
menu.auto_totem_wrath                   = core.menu.checkbox(true, "eaxshamanrestoration_auto_totem_wrath")
menu.use_wrath_of_air_totem             = core.menu.checkbox(true, "eaxshamanrestoration_use_wrath_of_air_totem")
menu.auto_totem_wrath_of_air            = core.menu.checkbox(true, "eaxshamanrestoration_auto_totem_wrath_of_air")
menu.use_flametongue_totem               = core.menu.checkbox(true, "eaxshamanrestoration_use_flametongue_totem")
menu.use_strength_of_earth_totem         = core.menu.checkbox(true, "eaxshamanrestoration_use_strength_of_earth_totem")
menu.use_stoneskin_totem                 = core.menu.checkbox(true, "eaxshamanrestoration_use_stoneskin_totem")
menu.use_grounding_totem                 = core.menu.checkbox(true, "eaxshamanrestoration_use_grounding_totem")
menu.use_tremor_totem                    = core.menu.checkbox(true, "eaxshamanrestoration_use_tremor_totem")
menu.use_mana_spring_totem               = core.menu.checkbox(true, "eaxshamanrestoration_use_mana_spring_totem")
menu.use_mana_tide_totem                 = core.menu.checkbox(true, "eaxshamanrestoration_use_mana_tide_totem")
menu.use_healing_stream_totem            = core.menu.checkbox(true, "eaxshamanrestoration_use_healing_stream_totem")
menu.use_windfury_totem                  = core.menu.checkbox(true, "eaxshamanrestoration_use_windfury_totem")
menu.use_grace_of_air_totem              = core.menu.checkbox(true, "eaxshamanrestoration_use_grace_of_air_totem")
menu.use_sentry_totem                    = core.menu.checkbox(true, "eaxshamanrestoration_use_sentry_totem")
menu.use_water_shield                    = core.menu.checkbox(true, "eaxshamanrestoration_use_water_shield")
menu.use_lightning_shield                = core.menu.checkbox(true, "eaxshamanrestoration_use_lightning_shield")
menu.use_earth_shield                    = core.menu.checkbox(true, "eaxshamanrestoration_use_earth_shield")
menu.use_water_breathing                 = core.menu.checkbox(true, "eaxshamanrestoration_use_water_breathing")
menu.use_water_walking                   = core.menu.checkbox(true, "eaxshamanrestoration_use_water_walking")
menu.use_ancestral_spirit                = core.menu.checkbox(true, "eaxshamanrestoration_use_ancestral_spirit")
menu.use_reincarnation                   = core.menu.checkbox(true, "eaxshamanrestoration_use_reincarnation")
menu.use_cure_poison                     = core.menu.checkbox(true, "eaxshamanrestoration_use_cure_poison")
menu.use_cure_disease                    = core.menu.checkbox(true, "eaxshamanrestoration_use_cure_disease")
menu.use_cleanse_spirit                  = core.menu.checkbox(true, "eaxshamanrestoration_use_cleanse_spirit")
menu.use_hex                             = core.menu.checkbox(true, "eaxshamanrestoration_use_hex")
menu.use_bind_elemental                  = core.menu.checkbox(true, "eaxshamanrestoration_use_bind_elemental")
menu.use_frost_shock                     = core.menu.checkbox(true, "eaxshamanrestoration_use_frost_shock")
menu.use_wind_shear                      = core.menu.checkbox(true, "eaxshamanrestoration_use_wind_shear")
menu.use_lightning_bolt                  = core.menu.checkbox(true, "eaxshamanrestoration_use_lightning_bolt")
menu.use_chain_lightning                 = core.menu.checkbox(true, "eaxshamanrestoration_use_chain_lightning")
menu.use_shamanistic_rage                = core.menu.checkbox(true, "eaxshamanrestoration_use_shamanistic_rage")
menu.use_maelstrom_weapon                = core.menu.checkbox(true, "eaxshamanrestoration_use_maelstrom_weapon")
menu.use_unleash_elements                = core.menu.checkbox(true, "eaxshamanrestoration_use_unleash_elements")
menu.use_thunderstorm                    = core.menu.checkbox(true, "eaxshamanrestoration_use_thunderstorm")
menu.use_astral_shift                    = core.menu.checkbox(true, "eaxshamanrestoration_use_astral_shift")
menu.astral_shift_hp_pct                 = core.menu.slider_int(0, 100, 40, "eaxshamanrestoration_astral_shift_hp_pct")
menu.use_earthgrab_totem                 = core.menu.checkbox(true, "eaxshamanrestoration_use_earthgrab_totem")
menu.use_stoneclaw_totem                 = core.menu.checkbox(true, "eaxshamanrestoration_use_stoneclaw_totem")
menu.use_stoneclaw_hp_pct                = core.menu.slider_int(0, 100, 40, "eaxshamanrestoration_stoneclaw_hp_pct")
menu.use_earthbind_totem                 = core.menu.checkbox(true, "eaxshamanrestoration_use_earthbind_totem")
menu.use_spiritwalkers_grace             = core.menu.checkbox(true, "eaxshamanrestoration_use_spiritwalkers_grace")
menu.use_totemic_recall                  = core.menu.checkbox(true, "eaxshamanrestoration_use_totemic_recall")
menu.use_unleash_elements                = core.menu.checkbox(true, "eaxshamanrestoration_use_unleash_elements")
menu.use_thunderstorm                    = core.menu.checkbox(true, "eaxshamanrestoration_use_thunderstorm")
menu.use_astral_shift                    = core.menu.checkbox(true, "eaxshamanrestoration_use_astral_shift")
menu.astral_shift_hp_pct                 = core.menu.slider_int(0, 100, 40, "eaxshamanrestoration_astral_shift_hp_pct")
menu.use_earthgrab_totem                 = core.menu.checkbox(true, "eaxshamanrestoration_use_earthgrab_totem")
menu.use_stoneclaw_totem                 = core.menu.checkbox(true, "eaxshamanrestoration_use_stoneclaw_totem")
menu.use_stoneclaw_hp_pct                = core.menu.slider_int(0, 100, 40, "eaxshamanrestoration_stoneclaw_hp_pct")
menu.use_earthbind_totem                 = core.menu.checkbox(true, "eaxshamanrestoration_use_earthbind_totem")
menu.use_spiritwalkers_grace             = core.menu.checkbox(true, "eaxshamanrestoration_use_spiritwalkers_grace")
menu.use_totemic_recall                  = core.menu.checkbox(true, "eaxshamanrestoration_use_totemic_recall")

mana_conservator.register_menu_items(menu, "eax_shaman_restoration")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_healing_wave", label = "Healing Wave" },
    { toggle = "use_lesser_healing_wave", label = "Lesser Healing Wave" },
    { toggle = "use_chain_heal", label = "Chain Heal" },
}, {
    namespace = "eaxshamanrestoration",
    log_prefix = "[Eax Shaman Resto] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxshamanrestoration")
    end

    root_tree:render("Eax's Shaman Restoration", function()
        ps.render_controls(menu, "Eax's Shaman Resto")

        -- Healing
        rotation_tree:render("Healing", function()
            ps.header("Direct Heals")
            menu.use_healing_wave:render("Healing Wave", "Main heal")
            menu.use_lesser_healing_wave:render("Lesser Healing Wave", "Fast heal")
            menu.use_chain_heal:render("Chain Heal", "AoE heal")
            menu.use_earth_shield:render("Earth Shield", "Shield")
            menu.use_mana_tide:render("Mana Tide", "Mana regen")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_bloodlust:render("Bloodlust", "Haste")
            menu.use_heroism:render("Heroism", "Haste")
            menu.use_earth_elemental:render("Earth Elemental", "Pet")
        end)

        -- Totems
        def_tree:render("Totems", function()
            ps.header("Fire")
            menu.use_searing_totem:render("Searing Totem", "Single target")
            menu.use_magma_totem:render("Magma Totem", "AoE")
            menu.use_fire_nova:render("Fire Nova", "AoE")
            menu.use_totem_of_wrath:render("Totem of Wrath", "Crit")
            menu.use_flametongue_totem:render("Flametongue Totem", "Spell damage")

            ps.header("Earth")
            menu.use_strength_of_earth_totem:render("Strength of Earth", "Stats")
            menu.use_stoneskin_totem:render("Stoneskin Totem", "Armor")
            menu.use_earthgrab_totem:render("Earthgrab Totem", "Root")
            menu.use_stoneclaw_totem:render("Stoneclaw Totem", "Absorb")
            menu.use_stoneclaw_hp_pct:render("Stoneclaw HP %", "Below")
            menu.use_earthbind_totem:render("Earthbind Totem", "Slow")

            ps.header("Water")
            menu.use_mana_spring_totem:render("Mana Spring", "Mana regen")
            menu.use_mana_tide_totem:render("Mana Tide", "Mana regen")
            menu.use_healing_stream_totem:render("Healing Stream", "Heal")

            ps.header("Air")
            menu.use_windfury_totem:render("Windfury Totem", "Melee haste")
            menu.use_wrath_of_air_totem:render("Wrath of Air Totem", "Spell power")
            menu.auto_totem_wrath_of_air:render("Auto Wrath of Air", "Auto cast")
            menu.use_grace_of_air_totem:render("Grace of Air", "Agility")
            menu.use_grounding_totem:render("Grounding Totem", "Spell absorb")
            menu.use_tremor_totem:render("Tremor Totem", "Fear/sleep")
            menu.use_sentry_totem:render("Sentry Totem", "Vision")

            ps.header("Recall")
            menu.use_totemic_recall:render("Totemic Recall", "Recall totems")
        end)

        -- Shields
        auto_tree:render("Shields", function()
            menu.use_water_shield:render("Water Shield", "Mana")
            menu.use_lightning_shield:render("Lightning Shield", "DPS")
            menu.use_earth_shield:render("Earth Shield", "Heal")
        end)

        -- Utility
        auto_tree:render("Utility", function()
            menu.use_water_breathing:render("Water Breathing", "Buff")
            menu.use_water_walking:render("Water Walking", "Buff")
            menu.use_ancestral_spirit:render("Ancestral Spirit", "Resurrect")
            menu.use_reincarnation:render("Reincarnation", "Self-res")
            menu.use_cure_poison:render("Cure Poison", "Dispel")
            menu.use_cure_disease:render("Cure Disease", "Dispel")
            menu.use_cleanse_spirit:render("Cleanse Spirit", "Dispel")
            menu.use_hex:render("Hex", "CC")
            menu.use_bind_elemental:render("Bind Elemental", "CC")
            menu.use_frost_shock:render("Frost Shock", "Slow")
            menu.use_wind_shear:render("Wind Shear", "Interrupt")
            menu.use_lightning_bolt:render("Lightning Bolt", "Filler")
            menu.use_chain_lightning:render("Chain Lightning", "AoE")
            menu.use_shamanistic_rage:render("Shamanistic Rage", "Mana")
            menu.use_maelstrom_weapon:render("Maelstrom Weapon", "Proc")
            menu.use_unleash_elements:render("Unleash Elements", "Buff")
        end)

        -- Automation
        auto_tree:render("Automation", function()
            menu.auto_combat_potions:render("Combat Potions", "In combat")
            menu.auto_ooc_food_drink:render("OOC Food/Drink", "Eat/drink")
            menu.auto_flask:render("Auto Flask", "Flask")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling")
            menu.leveling_mana_floor:render("Mana %", "Below")
            menu.use_wand:render("Use Wand", "Low mana")
            menu.wand_mana_floor:render("Wand Mana %", "Below")
            menu.wand_at_hp:render("Wand Target HP %", "Below")
            menu.use_spirit_tap_wand:render("Spirit Tap Wand", "If talented")
        end)

        -- OOC
        ooc_tree:render("OOC Sustain", function()
            menu.ooc_drink:render("Auto-Drink", "Drink")
            menu.drink_threshold:render("Drink %", "Below")
            menu.ooc_eat:render("Auto-Eat", "Eat")
            menu.eat_threshold:render("Eat %", "Below")
        end)

        -- Group
        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end

return menu
