-- +------------------------------------------------------------------+
-- |  Eax's Shaman Enhancement
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

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
menu.enabled                             = core.menu.checkbox(true, "eaxshamanenhancement_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxshamanenhancement_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxshamanenhancement_mode")
menu.debug                               = core.menu.checkbox(false, "eaxshamanenhancement_debug")
menu.shield_mode                         = core.menu.combobox(3, "eaxshamanenhancement_shield_mode")
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
menu.use_interrupt                        = core.menu.checkbox(true, "eaxshamanenhancement_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxshamanenhancement_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxshamanenhancement_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxshamanenhancement_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxshamanenhancement_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxshamanenhancement_lev_mana_floor")

-- Rotation
menu.use_stormstrike                     = core.menu.checkbox(true, "eaxshamanenhancement_use_stormstrike")
menu.use_earth_shock                     = core.menu.checkbox(true, "eaxshamanenhancement_use_earth_shock")
menu.use_flame_shock                     = core.menu.checkbox(true, "eaxshamanenhancement_use_flame_shock")
menu.use_bloodlust                       = core.menu.checkbox(true, "eaxshamanenhancement_use_bloodlust")
menu.use_heroism                         = core.menu.checkbox(true, "eaxshamanenhancement_use_heroism")
menu.use_searing_totem                   = core.menu.checkbox(true, "eaxshamanenhancement_use_searing_totem")
menu.use_magma_totem                     = core.menu.checkbox(true, "eaxshamanenhancement_use_magma_totem")
menu.use_fire_nova_twist                 = core.menu.checkbox(true, "eaxshamanenhancement_use_fire_nova_twist")
menu.use_strength_of_earth_totem         = core.menu.checkbox(true, "eaxshamanenhancement_use_strength_of_earth_totem")
menu.use_stoneskin_totem                 = core.menu.checkbox(true, "eaxshamanenhancement_use_stoneskin_totem")
menu.use_stoneclaw_totem                 = core.menu.checkbox(true, "eaxshamanenhancement_use_stoneclaw_totem")
menu.use_grounding_totem                 = core.menu.checkbox(true, "eaxshamanenhancement_use_grounding_totem")
menu.use_tremor_totem                    = core.menu.checkbox(true, "eaxshamanenhancement_use_tremor_totem")
menu.use_mana_spring_totem               = core.menu.checkbox(true, "eaxshamanenhancement_use_mana_spring_totem")
menu.use_mana_tide_totem                 = core.menu.checkbox(true, "eaxshamanenhancement_use_mana_tide_totem")
menu.use_healing_stream_totem            = core.menu.checkbox(true, "eaxshamanenhancement_use_healing_stream_totem")
menu.use_windfury_totem                  = core.menu.checkbox(true, "eaxshamanenhancement_use_windfury_totem")
menu.use_grace_of_air_totem              = core.menu.checkbox(true, "eaxshamanenhancement_use_grace_of_air_totem")
menu.use_sentry_totem                    = core.menu.checkbox(true, "eaxshamanenhancement_use_sentry_totem")
menu.use_lightning_shield                = core.menu.checkbox(true, "eaxshamanenhancement_use_lightning_shield")
menu.use_water_breathing                 = core.menu.checkbox(true, "eaxshamanenhancement_use_water_breathing")
menu.use_water_walking                   = core.menu.checkbox(true, "eaxshamanenhancement_use_water_walking")
menu.use_ancestral_spirit                = core.menu.checkbox(true, "eaxshamanenhancement_use_ancestral_spirit")
menu.use_cure_poison                     = core.menu.checkbox(true, "eaxshamanenhancement_use_cure_poison")
menu.use_cure_disease                    = core.menu.checkbox(true, "eaxshamanenhancement_use_cure_disease")
menu.use_frost_shock                     = core.menu.checkbox(true, "eaxshamanenhancement_use_frost_shock")
menu.use_lightning_bolt                  = core.menu.checkbox(true, "eaxshamanenhancement_use_lightning_bolt")
menu.use_chain_lightning                 = core.menu.checkbox(true, "eaxshamanenhancement_use_chain_lightning")
menu.use_shamanistic_rage                = core.menu.checkbox(true, "eaxshamanenhancement_use_shamanistic_rage")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_stormstrike", label = "Stormstrike" },
    { toggle = "use_earth_shock", label = "Earth Shock" },
    { toggle = "use_flame_shock", label = "Flame Shock" },
}, {
    namespace = "eaxshamanenhancement",
    log_prefix = "[Eax Shaman Enh] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxshamanenhancement")
    end

    root_tree:render("Eax's Shaman Enhancement", function()
        ps.render_controls(menu, "Eax's Shaman Enh")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_stormstrike:render("Stormstrike", "On CD")
            menu.use_earth_shock:render("Earth Shock", "Instant")
            menu.use_flame_shock:render("Flame Shock", "DoT")
            menu.use_frost_shock:render("Frost Shock", "Slow")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_bloodlust:render("Bloodlust", "Haste")
            menu.use_heroism:render("Heroism", "Haste")
            menu.use_shamanistic_rage:render("Shamanistic Rage", "Mana")
        end)

        -- Totems
        def_tree:render("Totems", function()
            ps.header("Fire")
            menu.use_searing_totem:render("Searing Totem", "Single target")
            menu.use_magma_totem:render("Magma Totem", "AoE")
            menu.use_fire_nova_twist:render("Fire Nova Totem", "AoE twist")

            ps.header("Earth")
            menu.use_strength_of_earth_totem:render("Strength of Earth", "Stats")
            menu.use_stoneskin_totem:render("Stoneskin Totem", "Armor")
            menu.use_stoneclaw_totem:render("Stoneclaw Totem", "Absorb")
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

        end)

        -- Shields
        auto_tree:render("Shields", function()
            menu.use_lightning_shield:render("Lightning Shield", "DPS")
        end)

        -- Utility
        auto_tree:render("Utility", function()
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_water_breathing:render("Water Breathing", "Buff")
            menu.use_water_walking:render("Water Walking", "Buff")
            menu.use_ancestral_spirit:render("Ancestral Spirit", "Resurrect")
            menu.use_cure_poison:render("Cure Poison", "Dispel")
            menu.use_cure_disease:render("Cure Disease", "Dispel")
            menu.use_ghost_wolf:render("Ghost Wolf", "Travel")
            menu.use_lb_pull:render("LB Pull", "Pull with LB")
            menu.lb_pull_range:render("LB Pull Range", "yd")
        end)

        -- Self-Healing
        def_tree:render("Self-Healing", function()
            menu.use_healing_wave:render("Healing Wave", "Self-heal")
            menu.healing_wave_hp:render("Healing Wave HP %", "Below")
            menu.use_lesser_healing_wave:render("Lesser Healing Wave", "Fast heal")
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
