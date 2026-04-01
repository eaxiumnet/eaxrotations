-- +------------------------------------------------------------------+
-- |  Eax's Rogue Assassination
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}
local POISON_OPTIONS = { "Disabled", "Instant", "Deadly", "Wound", "Crippling", "Mind-Numbing" }

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
menu.enabled                             = core.menu.checkbox(true, "eaxrogueassassination_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxrogueassassination_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxrogueassassination_mode")
menu.debug                               = core.menu.checkbox(false, "eaxrogueassassination_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxrogueassassination_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxrogueassassination_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxrogueassassination_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxrogueassassination_racial_hp")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxrogueassassination_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxrogueassassination_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxrogueassassination_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxrogueassassination_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxrogueassassination_lev_mana_floor")

-- Rotation
menu.use_mutilate                        = core.menu.checkbox(true, "eaxrogueassassination_use_mutilate")
menu.use_garrote                         = core.menu.checkbox(true, "eaxrogueassassination_use_garrote")
menu.use_rupture                         = core.menu.checkbox(true, "eaxrogueassassination_use_rupture")
menu.use_envenom                         = core.menu.checkbox(true, "eaxrogueassassination_use_envenom")
menu.use_expose_armor                    = core.menu.checkbox(true, "eaxrogueassassination_use_expose_armor")
menu.use_deadly_poison                   = core.menu.checkbox(true, "eaxrogueassassination_use_deadly_poison")
menu.use_cold_blood                      = core.menu.checkbox(true, "eaxrogueassassination_use_cold_blood")
menu.use_preparation                     = core.menu.checkbox(true, "eaxrogueassassination_use_preparation")
menu.use_stealth                         = core.menu.checkbox(true, "eaxrogueassassination_use_stealth")
menu.use_cheap_shot                      = core.menu.checkbox(true, "eaxrogueassassination_use_cheap_shot")
menu.use_kidney_shot                     = core.menu.checkbox(true, "eaxrogueassassination_use_kidney_shot")
menu.use_eviscerate                      = core.menu.checkbox(true, "eaxrogueassassination_use_eviscerate")
menu.use_slice_and_dice                  = core.menu.checkbox(true, "eaxrogueassassination_use_slice_and_dice")
menu.use_feint                           = core.menu.checkbox(true, "eaxrogueassassination_use_feint")
menu.feint_energy_threshold              = core.menu.slider_int(20, 80, 40, "eaxrogueassassination_feint_energy_threshold")
menu.use_evasion                         = core.menu.checkbox(true, "eaxrogueassassination_use_evasion")
menu.evasion_hp_pct                      = core.menu.slider_int(0, 100, 40, "eaxrogueassassination_evasion_hp_pct")
menu.use_cloak_of_shadows                = core.menu.checkbox(true, "eaxrogueassassination_use_cloak_of_shadows")
menu.cloak_of_shadows_hp_pct             = core.menu.slider_int(0, 100, 30, "eaxrogueassassination_cloak_of_shadows_hp_pct")
menu.use_vanish                          = core.menu.checkbox(true, "eaxrogueassassination_use_vanish")
menu.vanish_hp_pct                       = core.menu.slider_int(0, 100, 20, "eaxrogueassassination_vanish_hp_pct")
menu.use_blade_flurry                    = core.menu.checkbox(true, "eaxrogueassassination_use_blade_flurry")
menu.use_adrenaline_rush                 = core.menu.checkbox(true, "eaxrogueassassination_use_adrenaline_rush")
menu.use_distract                        = core.menu.checkbox(true, "eaxrogueassassination_use_distract")
menu.use_sap                             = core.menu.checkbox(true, "eaxrogueassassination_use_sap")
menu.use_gouge                           = core.menu.checkbox(true, "eaxrogueassassination_use_gouge")
menu.use_kick                            = core.menu.checkbox(true, "eaxrogueassassination_use_kick")
menu.use_blind                           = core.menu.checkbox(true, "eaxrogueassassination_use_blind")
menu.use_sprint                          = core.menu.checkbox(true, "eaxrogueassassination_use_sprint")
menu.use_shadowstep                      = core.menu.checkbox(true, "eaxrogueassassination_use_shadowstep")
menu.use_backstab                        = core.menu.checkbox(true, "eaxrogueassassination_use_backstab")
menu.use_sinister_strike                 = core.menu.checkbox(true, "eaxrogueassassination_use_sinister_strike")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_mutilate", label = "Mutilate" },
    { toggle = "use_rupture", label = "Rupture" },
    { toggle = "use_envenom", label = "Envenom" },
}, {
    namespace = "eaxrogueassassination",
    log_prefix = "[Eax Rogue Assass] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxrogueassassination")
    end

    root_tree:render("Eax's Rogue Assassination", function()
        ps.render_controls(menu, "Eax's Rogue Assass")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_mutilate:render("Mutilate", "Main filler")
            menu.use_garrote:render("Garrote", "Opener")
            menu.use_rupture:render("Rupture", "Maintain")
            menu.use_envenom:render("Envenom", "Finisher")
            menu.use_expose_armor:render("Expose Armor", "Debuff")
            menu.use_deadly_poison:render("Deadly Poison", "Poison")
            menu.use_eviscerate:render("Eviscerate", "Finisher")
            menu.use_slice_and_dice:render("Slice and Dice", "Buff")
            menu.use_feint:render("Feint", "Threat")
            menu.feint_energy_threshold:render("Feint Energy", "Above")
            menu.use_fan_of_knives:render("Fan of Knives", "AoE")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_cold_blood:render("Cold Blood", "Guaranteed crit")
            menu.use_preparation:render("Preparation", "Reset CDs")
            menu.use_blade_flurry:render("Blade Flurry", "AoE")
            menu.use_adrenaline_rush:render("Adrenaline Rush", "Energy")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_evasion:render("Evasion", "Dodge")
            menu.evasion_hp_pct:render("Evasion HP %", "Below")
            menu.use_cloak_of_shadows:render("Cloak of Shadows", "Magic immune")
            menu.cloak_of_shadows_hp_pct:render("Cloak HP %", "Below")
            menu.use_vanish:render("Vanish", "Escape")
            menu.vanish_hp_pct:render("Vanish HP %", "Below")
        end)

        -- Utility
        auto_tree:render("Utility", function()
            menu.use_stealth:render("Stealth", "Stealth")
            menu.use_cheap_shot:render("Cheap Shot", "Stun")
            menu.use_kidney_shot:render("Kidney Shot", "Stun")
            menu.use_distract:render("Distract", "Distraction")
            menu.use_sap:render("Sap", "CC")
            menu.use_gouge:render("Gouge", "CC")
            menu.use_kick:render("Kick", "Interrupt")
            menu.use_blind:render("Blind", "CC")
            menu.use_sprint:render("Sprint", "Speed")
            menu.use_shadowstep:render("Shadowstep", "Teleport")
            menu.use_backstab:render("Backstab", "Behind")
            menu.use_sinister_strike:render("Sinister Strike", "Filler")
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
