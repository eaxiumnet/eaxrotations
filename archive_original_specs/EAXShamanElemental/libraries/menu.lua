-- +------------------------------------------------------------------+
-- |  Eax's Shaman Elemental
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
menu.enabled                             = core.menu.checkbox(true, "eaxshamanelemental_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxshamanelemental_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxshamanelemental_mode")
menu.debug                               = core.menu.checkbox(false, "eaxshamanelemental_debug")
menu.shield_mode                         = core.menu.combobox(2, "eaxshamanelemental_shield_mode")
menu.use_healing_wave                    = core.menu.checkbox(true, "eaxshamanelemental_use_hw")
menu.healing_wave_hp                     = core.menu.slider_int(10, 60, 35, "eaxshamanelemental_hw_hp")
menu.use_ghost_wolf                      = core.menu.checkbox(true, "eaxshamanelemental_ghost_wolf")
menu.use_totemic_call                    = core.menu.checkbox(true, "eaxshamanelemental_totemic_call")
menu.use_dispels                         = core.menu.checkbox(false, "eaxshamanelemental_use_dispels")
menu.use_purge                           = core.menu.checkbox(false, "eaxshamanelemental_use_purge")

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

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxshamanelemental_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxshamanelemental_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxshamanelemental_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxshamanelemental_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxshamanelemental_lev_mana_floor")

-- Rotation
menu.use_lightning_bolt                  = core.menu.checkbox(true, "eaxshamanelemental_use_lightning_bolt")
menu.use_chain_lightning                 = core.menu.checkbox(true, "eaxshamanelemental_use_chain_lightning")
menu.use_flame_shock                     = core.menu.checkbox(true, "eaxshamanelemental_use_flame_shock")
menu.use_earth_shock                     = core.menu.checkbox(true, "eaxshamanelemental_use_earth_shock")
menu.use_lava_burst                      = core.menu.checkbox(true, "eaxshamanelemental_use_lava_burst")
menu.use_elemental_mastery               = core.menu.checkbox(true, "eaxshamanelemental_use_elemental_mastery")
menu.use_bloodlust                       = core.menu.checkbox(true, "eaxshamanelemental_use_bloodlust")
menu.use_heroism                         = core.menu.checkbox(true, "eaxshamanelemental_use_heroism")
menu.use_fire_elemental                  = core.menu.checkbox(true, "eaxshamanelemental_use_fire_elemental")
menu.use_searing_totem                   = core.menu.checkbox(true, "eaxshamanelemental_use_searing_totem")
menu.use_magma_totem                     = core.menu.checkbox(true, "eaxshamanelemental_use_magma_totem")
menu.use_fire_nova                       = core.menu.checkbox(true, "eaxshamanelemental_use_fire_nova")
menu.use_totem_of_wrath                  = core.menu.checkbox(true, "eaxshamanelemental_use_totem_of_wrath")
menu.auto_totem_wrath                   = core.menu.checkbox(true, "eaxshamanelemental_auto_totem_wrath")
menu.use_flametongue_totem               = core.menu.checkbox(true, "eaxshamanelemental_use_flametongue_totem")
menu.use_strength_of_earth_totem         = core.menu.checkbox(true, "eaxshamanelemental_use_strength_of_earth_totem")
menu.use_stoneskin_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_stoneskin_totem")
menu.use_grounding_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_grounding_totem")
menu.use_tremor_totem                    = core.menu.checkbox(true, "eaxshamanelemental_use_tremor_totem")
menu.use_mana_spring_totem               = core.menu.checkbox(true, "eaxshamanelemental_use_mana_spring_totem")
menu.use_mana_tide_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_mana_tide_totem")
menu.use_healing_stream_totem            = core.menu.checkbox(true, "eaxshamanelemental_use_healing_stream_totem")
menu.use_windfury_totem                  = core.menu.checkbox(true, "eaxshamanelemental_use_windfury_totem")
menu.use_grace_of_air_totem              = core.menu.checkbox(true, "eaxshamanelemental_use_grace_of_air_totem")
menu.use_sentry_totem                    = core.menu.checkbox(true, "eaxshamanelemental_use_sentry_totem")
menu.use_water_shield                    = core.menu.checkbox(true, "eaxshamanelemental_use_water_shield")
menu.use_lightning_shield                = core.menu.checkbox(true, "eaxshamanelemental_use_lightning_shield")
menu.use_earth_shield                    = core.menu.checkbox(true, "eaxshamanelemental_use_earth_shield")
menu.use_water_breathing                 = core.menu.checkbox(true, "eaxshamanelemental_use_water_breathing")
menu.use_water_walking                   = core.menu.checkbox(true, "eaxshamanelemental_use_water_walking")
menu.use_ancestral_spirit                = core.menu.checkbox(true, "eaxshamanelemental_use_ancestral_spirit")
menu.use_reincarnation                   = core.menu.checkbox(true, "eaxshamanelemental_use_reincarnation")
menu.use_cure_poison                     = core.menu.checkbox(true, "eaxshamanelemental_use_cure_poison")
menu.use_cure_disease                    = core.menu.checkbox(true, "eaxshamanelemental_use_cure_disease")
menu.use_cleanse_spirit                  = core.menu.checkbox(true, "eaxshamanelemental_use_cleanse_spirit")
menu.use_hex                             = core.menu.checkbox(true, "eaxshamanelemental_use_hex")
menu.use_bind_elemental                  = core.menu.checkbox(true, "eaxshamanelemental_use_bind_elemental")
menu.use_frost_shock                     = core.menu.checkbox(true, "eaxshamanelemental_use_frost_shock")
menu.use_wind_shear                      = core.menu.checkbox(true, "eaxshamanelemental_use_wind_shear")
menu.use_stormstrike                     = core.menu.checkbox(true, "eaxshamanelemental_use_stormstrike")
menu.use_lava_lash                       = core.menu.checkbox(true, "eaxshamanelemental_use_lava_lash")
menu.use_shamanistic_rage                = core.menu.checkbox(true, "eaxshamanelemental_use_shamanistic_rage")
menu.use_feral_spirit                    = core.menu.checkbox(true, "eaxshamanelemental_use_feral_spirit")
menu.use_maelstrom_weapon                = core.menu.checkbox(true, "eaxshamanelemental_use_maelstrom_weapon")
menu.use_unleash_elements                = core.menu.checkbox(true, "eaxshamanelemental_use_unleash_elements")
menu.use_thunderstorm                    = core.menu.checkbox(true, "eaxshamanelemental_use_thunderstorm")
menu.use_astral_shift                    = core.menu.checkbox(true, "eaxshamanelemental_use_astral_shift")
menu.astral_shift_hp_pct                 = core.menu.slider_int(0, 100, 40, "eaxshamanelemental_astral_shift_hp_pct")
menu.use_earthgrab_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_earthgrab_totem")
menu.use_stoneclaw_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_stoneclaw_totem")
menu.use_stoneclaw_hp_pct                = core.menu.slider_int(0, 100, 40, "eaxshamanelemental_stoneclaw_hp_pct")
menu.use_earthbind_totem                 = core.menu.checkbox(true, "eaxshamanelemental_use_earthbind_totem")
menu.use_spiritwalkers_grace             = core.menu.checkbox(true, "eaxshamanelemental_use_spiritwalkers_grace")
menu.use_totemic_recall                  = core.menu.checkbox(true, "eaxshamanelemental_use_totemic_recall")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxshamanelemental_use_interrupt")

mana_conservator.register_menu_items(menu, "eax_shaman_elemental")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_lightning_bolt", label = "Lightning Bolt" },
    { toggle = "use_chain_lightning", label = "Chain Lightning" },
    { toggle = "use_flame_shock", label = "Flame Shock" },
    { toggle = "use_earth_shock", label = "Earth Shock" },
}, {
    namespace = "eaxshamanelemental",
    log_prefix = "[Eax Shaman Ele] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxshamanelemental")
    end

    root_tree:render("Eax's Shaman Elemental", function()
        ps.render_controls(menu, "Eax's Shaman Ele")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Spells")
            menu.use_lightning_bolt:render("Lightning Bolt", "Main filler")
            menu.use_chain_lightning:render("Chain Lightning", "AoE")
            menu.use_flame_shock:render("Flame Shock", "DoT")
            menu.use_earth_shock:render("Earth Shock", "Instant")
            menu.use_lava_burst:render("Lava Burst", "Proc")
            menu.use_frost_shock:render("Frost Shock", "Slow")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_elemental_mastery:render("Elemental Mastery", "Instant cast")
            menu.use_bloodlust:render("Bloodlust", "Haste")
            menu.use_heroism:render("Heroism", "Haste")
            menu.use_fire_elemental:render("Fire Elemental", "Pet")
            menu.use_astral_shift:render("Astral Shift", "Damage reduction")
        end)

        -- Totems
        def_tree:render("Totems", function()
            ps.header("Fire")
            menu.use_searing_totem:render("Searing Totem", "Single target")
            menu.use_magma_totem:render("Magma Totem", "AoE")
            menu.use_fire_nova:render("Fire Nova", "AoE")
            menu.use_totem_of_wrath:render("Totem of Wrath", "Crit")
            menu.auto_totem_wrath:render("Auto Totem of Wrath", "Auto cast")
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
            menu.use_grace_of_air_totem:render("Grace of Air", "Agility")
            menu.use_grounding_totem:render("Grounding Totem", "Spell absorb")
            menu.use_tremor_totem:render("Tremor Totem", "Fear/sleep")
            menu.use_sentry_totem:render("Sentry Totem", "Vision")

            ps.header("Recall")
            menu.use_totemic_recall:render("Totemic Recall", "Recall totems")
            menu.use_totemic_call:render("Totemic Call", "Recall totems")
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
            menu.use_ghost_wolf:render("Ghost Wolf", "Travel")
            menu.use_purge:render("Purge", "Dispel buff")
            menu.use_dispels:render("Dispels", "Dispel")
        end)

        -- Self-Healing
        def_tree:render("Self-Healing", function()
            menu.use_healing_wave:render("Healing Wave", "Self-heal")
            menu.healing_wave_hp:render("Healing Wave HP %", "Below")
        end)

        -- Automation
        auto_tree:render("Automation", function()
            menu.auto_combat_potions:render("Combat Potions", "In combat")
            menu.auto_ooc_food_drink:render("OOC Food/Drink", "Eat/drink")
            menu.auto_flask:render("Auto Flask", "Flask")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling")
            menu.leveling_mana_floor:render("Mana %", "Below")
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
