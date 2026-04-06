-- +------------------------------------------------------------------+
-- |  Eax's Mage Frost
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

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxmagefrost_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxmagefrost_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxmagefrost_auto_flask")
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

-- Rotation
menu.use_frostbolt                       = core.menu.checkbox(true, "eaxmagefrost_use_frostbolt")
menu.use_ice_lance                       = core.menu.checkbox(true, "eaxmagefrost_use_ice_lance")
menu.use_frostfire_bolt                  = core.menu.checkbox(true, "eaxmagefrost_use_frostfire_bolt")
menu.use_deep_freeze                     = core.menu.checkbox(true, "eaxmagefrost_use_deep_freeze")
menu.use_blizzard                        = core.menu.checkbox(true, "eaxmagefrost_use_blizzard")
menu.use_icy_veins                       = core.menu.checkbox(true, "eaxmagefrost_use_icy_veins")
menu.use_cold_snap                       = core.menu.checkbox(true, "eaxmagefrost_use_cold_snap")
menu.use_evocation                       = core.menu.checkbox(true, "eaxmagefrost_use_evocation")
menu.use_mage_armor                      = core.menu.checkbox(true, "eaxmagefrost_use_mage_armor")
menu.use_arcane_intellect                = core.menu.checkbox(true, "eaxmagefrost_use_arcane_intellect")
menu.use_conjure_food                    = core.menu.checkbox(true, "eaxmagefrost_use_conjure_food")
menu.use_conjure_water                   = core.menu.checkbox(true, "eaxmagefrost_use_conjure_water")
menu.use_polymorph                       = core.menu.checkbox(true, "eaxmagefrost_use_polymorph")
menu.use_blink                           = core.menu.checkbox(true, "eaxmagefrost_use_blink")
menu.use_counterspell                    = core.menu.checkbox(true, "eaxmagefrost_use_counterspell")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxmagefrost_remove_curse")
menu.use_interrupt                       = core.menu.checkbox(true, "eaxmagefrost_use_interrupt")
menu.use_ice_barrier                     = core.menu.checkbox(true, "eaxmagefrost_use_ice_barrier")
menu.ice_barrier_hp_pct                  = core.menu.slider_int(0, 100, 40, "eaxmagefrost_ice_barrier_hp_pct")
menu.use_ice_block                       = core.menu.checkbox(true, "eaxmagefrost_use_ice_block")
menu.ice_block_hp_pct                    = core.menu.slider_int(0, 100, 20, "eaxmagefrost_ice_block_hp_pct")
menu.use_frost_nova                      = core.menu.checkbox(true, "eaxmagefrost_use_frost_nova")
menu.use_cone_of_cold                    = core.menu.checkbox(true, "eaxmagefrost_use_cone_of_cold")
menu.use_winters_chill                   = core.menu.checkbox(true, "eaxmagefrost_use_winters_chill")
menu.winters_chill_refresh               = core.menu.slider_int(1, 5, 3, "eaxmagefrost_winters_chill_refresh")
menu.use_water_elemental                  = core.menu.checkbox(true, "eaxmagefrost_use_water_elemental")
menu.use_icy_veins                       = core.menu.checkbox(true, "eaxmagefrost_use_icy_veins")
menu.use_trinkets                        = core.menu.checkbox(true, "eaxmagefrost_use_trinkets")
menu.use_ice_lance                       = core.menu.checkbox(true, "eaxmagefrost_use_ice_lance")
menu.use_frostbolt                       = core.menu.checkbox(true, "eaxmagefrost_use_frostbolt")
menu.use_presence_of_mind                = core.menu.checkbox(true, "eaxmagefrost_use_presence_of_mind")
menu.use_ice_barrier                     = core.menu.checkbox(true, "eaxmagefrost_use_ice_barrier")
menu.use_cold_snap                       = core.menu.checkbox(true, "eaxmagefrost_use_cold_snap")

mana_conservator.register_menu_items(menu, "eax_mage_frost")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_frostbolt", label = "Frostbolt" },
    { toggle = "use_ice_lance", label = "Ice Lance" },
    { toggle = "use_blizzard", label = "Blizzard" },
    { toggle = "use_evocation", label = "Evocation" },
}, {
    namespace = "eaxmagefrost",
    log_prefix = "[Eax Mage Frost] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxmagefrost")
    end

    root_tree:render("Eax's Mage Frost", function()
        ps.render_controls(menu, "Eax's Mage Frost")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Spells")
            menu.use_frostbolt:render("Frostbolt", "Main filler")
            menu.use_ice_lance:render("Ice Lance", "Instant")
            menu.use_blizzard:render("Blizzard", "AoE")
            menu.use_mage_armor:render("Mage Armor", "Armor buff")
            menu.use_arcane_intellect:render("Arcane Intellect", "Int buff")
            menu.use_conjure_food:render("Conjure Food", "Create food")
            menu.use_conjure_water:render("Conjure Water", "Create water")
            menu.use_polymorph:render("Polymorph", "CC")
            menu.use_blink:render("Blink", "Escape")
            menu.use_counterspell:render("Counterspell", "Interrupt")
            menu.use_remove_curse:render("Remove Curse", "Dispel")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_frost_nova:render("Frost Nova", "Root")
            menu.use_cone_of_cold:render("Cone of Cold", "Slow")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_icy_veins:render("Icy Veins", "Haste")
            menu.use_cold_snap:render("Cold Snap", "Reset CDs")
            menu.use_evocation:render("Evocation", "Mana recovery")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_ice_barrier:render("Ice Barrier", "Shield")
            menu.ice_barrier_hp_pct:render("Ice Barrier HP %", "Below")
            menu.use_ice_block:render("Ice Block", "Immunity")
            menu.ice_block_hp_pct:render("Ice Block HP %", "Below")
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
