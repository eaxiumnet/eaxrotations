-- +------------------------------------------------------------------+
-- |  Eax's Rogue Subtlety
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
menu.enabled                             = core.menu.checkbox(true, "eaxroguesubtlety_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxroguesubtlety_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxroguesubtlety_mode")
menu.debug                               = core.menu.checkbox(false, "eaxroguesubtlety_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxroguesubtlety_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxroguesubtlety_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxroguesubtlety_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxroguesubtlety_racial_hp")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
-- menu.auto_repair                        = core.menu.checkbox(true, "eaxroguesubtlety_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxroguesubtlety_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxroguesubtlety_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxroguesubtlety_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxroguesubtlety_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxroguesubtlety_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxroguesubtlety_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxroguesubtlety_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxroguesubtlety_lev_mana_floor")

-- Rotation
menu.use_backstab                        = core.menu.checkbox(true, "eaxroguesubtlety_use_backstab")
menu.use_ambush                          = core.menu.checkbox(true, "eaxroguesubtlety_use_ambush")
menu.use_garrote                         = core.menu.checkbox(true, "eaxroguesubtlety_use_garrote")
menu.use_rupture                         = core.menu.checkbox(true, "eaxroguesubtlety_use_rupture")
menu.use_preparation                     = core.menu.checkbox(true, "eaxroguesubtlety_use_preparation")
menu.use_hemorrhage                      = core.menu.checkbox(true, "eaxroguesubtlety_use_hemorrhage")
menu.use_eviscerate                      = core.menu.checkbox(true, "eaxroguesubtlety_use_eviscerate")
menu.use_slice_and_dice                  = core.menu.checkbox(true, "eaxroguesubtlety_use_slice_and_dice")
menu.use_feint                           = core.menu.checkbox(true, "eaxroguesubtlety_use_feint")
menu.feint_energy_threshold              = core.menu.slider_int(20, 80, 40, "eaxroguesubtlety_feint_energy_threshold")
menu.use_evasion                         = core.menu.checkbox(true, "eaxroguesubtlety_use_evasion")
menu.evasion_hp_pct                      = core.menu.slider_int(0, 100, 40, "eaxroguesubtlety_evasion_hp_pct")
menu.use_cloak_of_shadows                = core.menu.checkbox(true, "eaxroguesubtlety_use_cloak_of_shadows")
menu.cloak_of_shadows_hp_pct             = core.menu.slider_int(0, 100, 30, "eaxroguesubtlety_cloak_of_shadows_hp_pct")
menu.use_vanish                          = core.menu.checkbox(true, "eaxroguesubtlety_use_vanish")
menu.vanish_hp_pct                       = core.menu.slider_int(0, 100, 20, "eaxroguesubtlety_vanish_hp_pct")
menu.use_distract                        = core.menu.checkbox(true, "eaxroguesubtlety_use_distract")
menu.use_sap                             = core.menu.checkbox(true, "eaxroguesubtlety_use_sap")
menu.use_gouge                           = core.menu.checkbox(true, "eaxroguesubtlety_use_gouge")
menu.use_kick                            = core.menu.checkbox(true, "eaxroguesubtlety_use_kick")
menu.use_blind                           = core.menu.checkbox(true, "eaxroguesubtlety_use_blind")
menu.use_sprint                          = core.menu.checkbox(true, "eaxroguesubtlety_use_sprint")
menu.use_shadowstep                      = core.menu.checkbox(true, "eaxroguesubtlety_use_shadowstep")
menu.use_cheap_shot                      = core.menu.checkbox(true, "eaxroguesubtlety_use_cheap_shot")
menu.use_kidney_shot                     = core.menu.checkbox(true, "eaxroguesubtlety_use_kidney_shot")
menu.use_expose_armor                    = core.menu.checkbox(true, "eaxroguesubtlety_use_expose_armor")
menu.use_deadly_poison                   = core.menu.checkbox(true, "eaxroguesubtlety_use_deadly_poison")
menu.use_instant_poison                  = core.menu.checkbox(true, "eaxroguesubtlety_use_instant_poison")
menu.use_wound_poison                    = core.menu.checkbox(true, "eaxroguesubtlety_use_wound_poison")
menu.use_crippling_poison                = core.menu.checkbox(true, "eaxroguesubtlety_use_crippling_poison")
menu.use_mind_numbing_poison             = core.menu.checkbox(true, "eaxroguesubtlety_use_mind_numbing_poison")
menu.use_stealth                         = core.menu.checkbox(true, "eaxroguesubtlety_use_stealth")
menu.use_premeditation                   = core.menu.checkbox(true, "eaxroguesubtlety_use_premeditation")
menu.use_cold_blood                      = core.menu.checkbox(true, "eaxroguesubtlety_use_cold_blood")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_backstab", label = "Backstab" },
    { toggle = "use_rupture", label = "Rupture" },
    { toggle = "use_eviscerate", label = "Eviscerate" },
}, {
    namespace = "eaxroguesubtlety",
    log_prefix = "[Eax Rogue Sub] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxroguesubtlety")
    end

    root_tree:render("Eax's Rogue Subtlety", function()
        ps.render_controls(menu, "Eax's Rogue Sub")

        -- Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Abilities")
            menu.use_backstab:render("Backstab", "Main filler")
            menu.use_ambush:render("Ambush", "Stealth opener")
            menu.use_garrote:render("Garrote", "Opener")
            menu.use_rupture:render("Rupture", "Maintain")
            menu.use_hemorrhage:render("Hemorrhage", "Debuff")
            menu.use_eviscerate:render("Eviscerate", "Finisher")
            menu.use_slice_and_dice:render("Slice and Dice", "Buff")
            menu.use_feint:render("Feint", "Threat")
            menu.feint_energy_threshold:render("Feint Energy", "Above")
        end)

        -- Cooldowns
        cd_tree:render("Cooldowns", function()
            menu.use_preparation:render("Preparation", "Reset CDs")
            menu.use_premeditation:render("Premeditation", "Combo points")
            menu.use_cold_blood:render("Cold Blood", "Guaranteed crit")
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
            menu.use_expose_armor:render("Expose Armor", "Debuff")
        end)

        -- Poisons
        auto_tree:render("Poisons", function()
            menu.use_deadly_poison:render("Deadly Poison", "DoT")
            menu.use_instant_poison:render("Instant Poison", "Proc")
            menu.use_wound_poison:render("Wound Poison", "Heal reduce")
            menu.use_crippling_poison:render("Crippling Poison", "Slow")
            menu.use_mind_numbing_poison:render("Mind-Numbing Poison", "Cast slow")
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
