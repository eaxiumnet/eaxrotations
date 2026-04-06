-- +------------------------------------------------------------------+
-- |  Eax's Mage Arcane
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

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxmagearcane_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxmagearcane_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxmagearcane_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxmagearcane_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxmagearcane_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxmagearcane_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxmagearcane_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxmagearcane_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxmagearcane_spirit_tap_wand")

-- Rotation
menu.use_arcane_blast                    = core.menu.checkbox(true, "eaxmagearcane_use_arcane_blast")
menu.use_arcane_missiles                 = core.menu.checkbox(true, "eaxmagearcane_use_arcane_missiles")
menu.use_arcane_surge                    = core.menu.checkbox(true, "eaxmagearcane_use_arcane_surge")
menu.use_evocation                       = core.menu.checkbox(true, "eaxmagearcane_use_evocation")
menu.use_missile_barrage                 = core.menu.checkbox(true, "eaxmagearcane_use_missile_barrage")
menu.use_presence_of_mind                = core.menu.checkbox(true, "eaxmagearcane_use_presence_of_mind")
menu.use_arcane_power                    = core.menu.checkbox(true, "eaxmagearcane_use_arcane_power")
menu.use_ice_barrier                     = core.menu.checkbox(true, "eaxmagearcane_use_ice_barrier")
menu.ice_barrier_hp_pct                  = core.menu.slider_int(0, 100, 40, "eaxmagearcane_ice_barrier_hp_pct")
menu.use_mage_armor                      = core.menu.checkbox(true, "eaxmagearcane_use_mage_armor")
menu.use_arcane_intellect                = core.menu.checkbox(true, "eaxmagearcane_use_arcane_intellect")
menu.use_conjure_food                    = core.menu.checkbox(true, "eaxmagearcane_use_conjure_food")
menu.use_conjure_water                   = core.menu.checkbox(true, "eaxmagearcane_use_conjure_water")
menu.use_polymorph                       = core.menu.checkbox(true, "eaxmagearcane_use_polymorph")
menu.use_blink                           = core.menu.checkbox(true, "eaxmagearcane_use_blink")
menu.use_counterspell                    = core.menu.checkbox(true, "eaxmagearcane_use_counterspell")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxmagearcane_remove_curse")
menu.use_interrupt                       = core.menu.checkbox(true, "eaxmagearcane_use_interrupt")
menu.use_mana_gem                       = core.menu.checkbox(true, "eaxmagearcane_use_mana_gem")
menu.mana_gem_pct                       = core.menu.slider_int(5, 80, 30, "eaxmagearcane_mana_gem_pct")
menu.use_remove_curse                   = core.menu.checkbox(true, "eaxmagearcane_remove_curse")
menu.use_arcane_explosion               = core.menu.checkbox(true, "eaxmagearcane_use_arcane_explosion")
menu.use_arcane_power                   = core.menu.checkbox(true, "eaxmagearcane_use_arcane_power")
menu.burn_mana_pct                      = core.menu.slider_int(20, 80, 50, "eaxmagearcane_burn_mana_pct")
menu.use_trinkets                       = core.menu.checkbox(true, "eaxmagearcane_use_trinkets")
menu.use_arcane_missiles                = core.menu.checkbox(true, "eaxmagearcane_use_arcane_missiles")
menu.arcane_blast_dump_stacks           = core.menu.slider_int(1, 4, 3, "eaxmagearcane_ab_dump_stacks")
menu.evocation_pct                      = core.menu.slider_int(10, 50, 25, "eaxmagearcane_evocation_pct")
menu.use_fire_blast_move                = core.menu.checkbox(true, "eaxmagearcane_use_fire_blast_move")
menu.use_ice_block                      = core.menu.checkbox(true, "eaxmagearcane_use_ice_block")
menu.ice_block_hp_pct                   = core.menu.slider_int(0, 100, 30, "eaxmagearcane_ice_block_hp_pct")
menu.use_frost_nova                     = core.menu.checkbox(true, "eaxmagearcane_use_frost_nova")
menu.use_presence_of_mind               = core.menu.checkbox(true, "eaxmagearcane_use_presence_of_mind")
menu.use_cone_of_cold                   = core.menu.checkbox(true, "eaxmagearcane_use_cone_of_cold")

mana_conservator.register_menu_items(menu, "eax_mage_arcane")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_arcane_blast", label = "Arcane Blast" },
    { toggle = "use_arcane_missiles", label = "Arcane Missiles" },
    { toggle = "use_evocation", label = "Evocation" },
    { toggle = "use_arcane_power", label = "Arcane Power" },
}, {
    namespace = "eaxmagearcane",
    log_prefix = "[Eax Mage Arcane] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxmagearcane")
    end

    root_tree:render("Eax's Mage Arcane", function()
        ps.render_controls(menu, "Eax's Mage Arcane")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Spells")
            menu.use_arcane_blast:render("Arcane Blast", "Main filler")
            menu.use_arcane_missiles:render("Arcane Missiles", "Proc filler")
            menu.use_arcane_surge:render("Arcane Surge", "Burst")
            menu.use_evocation:render("Evocation", "Mana recovery")
            menu.use_missile_barrage:render("Missile Barrage", "Proc")
            menu.use_mage_armor:render("Mage Armor", "Armor buff")
            menu.use_arcane_intellect:render("Arcane Intellect", "Int buff")
            menu.use_conjure_food:render("Conjure Food", "Create food")
            menu.use_conjure_water:render("Conjure Water", "Create water")
            menu.use_polymorph:render("Polymorph", "CC")
            menu.use_blink:render("Blink", "Escape")
            menu.use_counterspell:render("Counterspell", "Interrupt")
            menu.use_remove_curse:render("Remove Curse", "Dispel")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_presence_of_mind:render("Presence of Mind", "Instant cast")
            menu.use_arcane_power:render("Arcane Power", "DPS boost")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_ice_barrier:render("Ice Barrier", "Shield")
            menu.ice_barrier_hp_pct:render("Ice Barrier HP %", "Below")
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
