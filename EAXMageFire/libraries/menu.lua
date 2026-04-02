-- +------------------------------------------------------------------+
-- |  Eax's Mage Fire
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
menu.enabled                             = core.menu.checkbox(true, "eaxmagefire_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxmagefire_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxmagefire_mode")
menu.debug                               = core.menu.checkbox(false, "eaxmagefire_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxmagefire_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxmagefire_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxmagefire_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxmagefire_racial_hp")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxmagefire_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxmagefire_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxmagefire_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxmagefire_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxmagefire_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxmagefire_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxmagefire_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxmagefire_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxmagefire_spirit_tap_wand")

-- Rotation
menu.use_pyroblast                       = core.menu.checkbox(true, "eaxmagefire_use_pyroblast")
menu.use_fireball                        = core.menu.checkbox(true, "eaxmagefire_use_fireball")
menu.use_scorch                          = core.menu.checkbox(true, "eaxmagefire_use_scorch")
menu.use_combustion                      = core.menu.checkbox(true, "eaxmagefire_use_combustion")
menu.use_ignite                          = core.menu.checkbox(true, "eaxmagefire_use_ignite")
menu.use_fire_blast                      = core.menu.checkbox(true, "eaxmagefire_use_fire_blast")
menu.use_presence_of_mind                = core.menu.checkbox(true, "eaxmagefire_use_presence_of_mind")
menu.use_arcane_power                    = core.menu.checkbox(true, "eaxmagefire_use_arcane_power")
menu.use_evocation                       = core.menu.checkbox(true, "eaxmagefire_use_evocation")
menu.use_mage_armor                      = core.menu.checkbox(true, "eaxmagefire_use_mage_armor")
menu.use_arcane_intellect                = core.menu.checkbox(true, "eaxmagefire_use_arcane_intellect")
menu.use_conjure_food                    = core.menu.checkbox(true, "eaxmagefire_use_conjure_food")
menu.use_conjure_water                   = core.menu.checkbox(true, "eaxmagefire_use_conjure_water")
menu.use_polymorph                       = core.menu.checkbox(true, "eaxmagefire_use_polymorph")
menu.use_blink                           = core.menu.checkbox(true, "eaxmagefire_use_blink")
menu.use_counterspell                    = core.menu.checkbox(true, "eaxmagefire_use_counterspell")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxmagefire_remove_curse")
menu.use_ice_barrier                     = core.menu.checkbox(true, "eaxmagefire_use_ice_barrier")
menu.ice_barrier_hp_pct                  = core.menu.slider_int(0, 100, 40, "eaxmagefire_ice_barrier_hp_pct")

-- Defensive (additional)
menu.use_ice_block                         = core.menu.checkbox(true, "eaxmagefire_use_ice_block")
menu.ice_block_hp_pct                      = core.menu.slider_int(0, 100, 30, "eaxmagefire_ice_block_hp_pct")

-- AoE
menu.use_flamestrike                       = core.menu.checkbox(true, "eaxmagefire_use_flamestrike")
menu.flamestrike_enemy_count               = core.menu.slider_int(2, 10, 3, "eaxmagefire_flamestrike_enemy_count")
menu.use_blast_wave                        = core.menu.checkbox(true, "eaxmagefire_use_blast_wave")
menu.use_dragons_breath                    = core.menu.checkbox(true, "eaxmagefire_use_dragons_breath")

-- Utility
menu.use_frost_nova                        = core.menu.checkbox(true, "eaxmagefire_use_frost_nova")
menu.use_fire_blast_move                   = core.menu.checkbox(true, "eaxmagefire_use_fire_blast_move")
menu.use_trinkets                          = core.menu.checkbox(true, "eaxmagefire_use_trinkets")

-- Scorch
menu.scorch_stack_target                   = core.menu.slider_int(1, 5, 5, "eaxmagefire_scorch_stack_target")
menu.scorch_refresh_ms                     = core.menu.slider_int(1000, 5000, 3000, "eaxmagefire_scorch_refresh_ms")

mana_conservator.register_menu_items(menu, "eax_mage_fire")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_fireball", label = "Fireball" },
    { toggle = "use_scorch", label = "Scorch" },
    { toggle = "use_fire_blast", label = "Fire Blast" },
    { toggle = "use_evocation", label = "Evocation" },
}, {
    namespace = "eaxmagefire",
    log_prefix = "[Eax Mage Fire] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxmagefire")
    end

    root_tree:render("Eax's Mage Fire", function()
        ps.render_controls(menu, "Eax's Mage Fire")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Spells")
            menu.use_pyroblast:render("Pyroblast", "Opener/proc")
            menu.use_fireball:render("Fireball", "Main filler")
            menu.use_scorch:render("Scorch", "Debuff")
            menu.use_combustion:render("Combustion", "Burst")
            menu.use_ignite:render("Ignite", "Proc")
            menu.use_fire_blast:render("Fire Blast", "Instant")
            menu.use_mage_armor:render("Mage Armor", "Armor buff")
            menu.use_arcane_intellect:render("Arcane Intellect", "Int buff")
            menu.use_conjure_food:render("Conjure Food", "Create food")
            menu.use_conjure_water:render("Conjure Water", "Create water")
            menu.use_polymorph:render("Polymorph", "CC")
            menu.use_blink:render("Blink", "Escape")
            menu.use_counterspell:render("Counterspell", "Interrupt")
            menu.use_remove_curse:render("Remove Curse", "Dispel")
            ps.header("Scorch")
            menu.scorch_stack_target:render("Scorch Stack Target", "Stacks to maintain")
            menu.scorch_refresh_ms:render("Scorch Refresh MS", "Refresh window")
            ps.header("Utility")
            menu.use_frost_nova:render("Frost Nova", "Root melee")
            menu.use_fire_blast_move:render("Fire Blast (Moving)", "Instant while moving")
            menu.use_trinkets:render("Use Trinkets", "Auto-use trinkets")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_presence_of_mind:render("Presence of Mind", "Instant cast")
            menu.use_arcane_power:render("Arcane Power", "DPS boost")
            menu.use_evocation:render("Evocation", "Mana recovery")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_ice_barrier:render("Ice Barrier", "Shield")
            menu.ice_barrier_hp_pct:render("Ice Barrier HP %", "Below")
            menu.use_ice_block:render("Ice Block", "Emergency immunity")
            menu.ice_block_hp_pct:render("Ice Block HP %", "Below")
        end)

        -- AoE
        cd_tree:render("AoE", function()
            menu.use_flamestrike:render("Flamestrike", "Ground AoE")
            menu.flamestrike_enemy_count:render("Flamestrike Min Enemies", "Count")
            menu.use_blast_wave:render("Blast Wave", "Instant AoE")
            menu.use_dragons_breath:render("Dragon's Breath", "Cone AoE")
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
