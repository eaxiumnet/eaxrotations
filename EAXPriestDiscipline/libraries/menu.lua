-- +------------------------------------------------------------------+
-- |  Eax's Priest Discipline
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
menu.enabled                             = core.menu.checkbox(true, "eaxpriestdiscipline_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpriestdiscipline_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpriestdiscipline_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpriestdiscipline_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpriestdiscipline_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpriestdiscipline_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpriestdiscipline_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpriestdiscipline_racial_hp")


menu.pvp_mode                            = core.menu.checkbox(false, "eaxpriestdiscipline_pvp_mode")
menu.pvp_use_psychic_scream              = core.menu.checkbox(true, "eaxpriestdiscipline_pvp_psychic_scream")
menu.pvp_psychic_scream_threshold        = core.menu.slider_int(10, 100, 60, "eaxpriestdiscipline_pvp_scream_threshold")
menu.pvp_use_silence                     = core.menu.checkbox(true, "eaxpriestdiscipline_pvp_silence")
menu.pvp_use_shackle                     = core.menu.checkbox(true, "eaxpriestdiscipline_pvp_shackle")
menu.pvp_shackle_threshold               = core.menu.slider_int(10, 100, 80, "eaxpriestdiscipline_pvp_shackle_threshold")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpriestdiscipline_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpriestdiscipline_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpriestdiscipline_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpriestdiscipline_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpriestdiscipline_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpriestdiscipline_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpriestdiscipline_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpriestdiscipline_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpriestdiscipline_spirit_tap_wand")


menu.use_greater_heal                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_greater_heal")
menu.greater_heal_hp_pct                = core.menu.slider_int(10, 100, 60, "eaxpriestdiscipline_greater_heal_hp_pct")
menu.use_flash_heal                      = core.menu.checkbox(true, "eaxpriestdiscipline_use_flash_heal")
menu.flash_heal_hp_pct                  = core.menu.slider_int(10, 100, 50, "eaxpriestdiscipline_flash_heal_hp_pct")  
menu.disc_emergency_hp                   = core.menu.slider_int(5, 50, 30, "eaxpriestdiscipline_emergency_hp")  
menu.use_power_word_shield               = core.menu.checkbox(true, "eaxpriestdiscipline_use_power_word_shield")
menu.shield_threshold                    = core.menu.slider_int(10, 100, 85, "eaxpriestdiscipline_shield_threshold")
menu.disc_shield_emergency_hp            = core.menu.slider_int(5, 50, 30, "eaxpriestdiscipline_shield_emergency_hp")  
menu.use_weakened_soul                   = core.menu.checkbox(true, "eaxpriestdiscipline_use_weakened_soul")
-- NOTE: Penance is WotLK spell (3.0.2), not TBC - removed
menu.use_renew                           = core.menu.checkbox(true, "eaxpriestdiscipline_use_renew")
menu.renew_threshold                     = core.menu.slider_int(0, 100, 90, "eaxpriestdiscipline_renew_threshold")  
menu.renew_refresh_seconds               = core.menu.slider_int(0, 10, 3, "eaxpriestdiscipline_renew_refresh")
menu.disc_prepull_renew                  = core.menu.checkbox(true, "eaxpriestdiscipline_prepull_renew")  
-- NOTE: Aegis/Divine Aegis are WotLK talents, not TBC - removed
menu.use_power_infusion                  = core.menu.checkbox(true, "eaxpriestdiscipline_use_power_infusion")
menu.power_infusion_enabled              = core.menu.checkbox(true, "eaxpriestdiscipline_power_infusion_enabled")
menu.power_infusion_threshold            = core.menu.slider_int(10, 100, 50, "eaxpriestdiscipline_power_infusion_threshold")
menu.use_pain_suppression                = core.menu.checkbox(true, "eaxpriestdiscipline_use_pain_suppression")
menu.pain_suppression_threshold          = core.menu.slider_int(10, 80, 40, "eaxpriestdiscipline_pain_suppression_threshold")
menu.use_binding_heal                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_binding_heal")
menu.binding_heal_self_threshold         = core.menu.slider_int(0, 100, 80, "eaxpriestdiscipline_binding_heal_self_threshold")  
menu.binding_heal_target_threshold       = core.menu.slider_int(0, 100, 80, "eaxpriestdiscipline_binding_heal_target_threshold")  
menu.use_prayer_of_mending               = core.menu.checkbox(true, "eaxpriestdiscipline_use_prayer_of_mending")
menu.use_prayer_of_healing               = core.menu.checkbox(true, "eaxpriestdiscipline_use_prayer_of_healing")
menu.prayer_of_mending_threshold         = core.menu.slider_int(10, 100, 85, "eaxpriestdiscipline_prayer_of_mending_threshold")
menu.prepull_pom                         = core.menu.checkbox(true, "eaxpriestdiscipline_prepull_pom")  
menu.disc_aoe_hp                         = core.menu.slider_int(50, 100, 80, "eaxpriestdiscipline_aoe_hp")  
menu.disc_aoe_count                      = core.menu.slider_int(2, 5, 3, "eaxpriestdiscipline_aoe_count")
menu.use_inner_fire                      = core.menu.checkbox(true, "eaxpriestdiscipline_use_inner_fire")
menu.use_power_word_fortitude            = core.menu.checkbox(true, "eaxpriestdiscipline_use_power_word_fortitude")
menu.use_divine_spirit                   = core.menu.checkbox(true, "eaxpriestdiscipline_use_divine_spirit")
menu.use_shadow_protection               = core.menu.checkbox(true, "eaxpriestdiscipline_use_shadow_protection")
menu.use_fear_ward                       = core.menu.checkbox(true, "eaxpriestdiscipline_use_fear_ward")
menu.use_dispel_magic                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_dispel_magic")
menu.use_cure_disease                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_cure_disease")
menu.use_abolish_disease                 = core.menu.checkbox(true, "eaxpriestdiscipline_use_abolish_disease")
menu.use_psychic_scream                  = core.menu.checkbox(true, "eaxpriestdiscipline_use_psychic_scream")
menu.use_shackle_undead                  = core.menu.checkbox(true, "eaxpriestdiscipline_use_shackle_undead")
menu.use_resurrection                    = core.menu.checkbox(true, "eaxpriestdiscipline_use_resurrection")
menu.use_smite                           = core.menu.checkbox(true, "eaxpriestdiscipline_use_smite")
menu.use_holy_fire                       = core.menu.checkbox(true, "eaxpriestdiscipline_use_holy_fire")
menu.use_shadow_word_pain                = core.menu.checkbox(true, "eaxpriestdiscipline_use_shadow_word_pain")
menu.use_mind_blast                      = core.menu.checkbox(true, "eaxpriestdiscipline_use_mind_blast")
menu.use_interrupt                        = core.menu.checkbox(true, "eaxpriestdiscipline_use_interrupt")

-- Utility toggles
menu.use_dispels                         = core.menu.checkbox(true, "eaxpriestdiscipline_use_dispels")
menu.use_inner_focus                     = core.menu.checkbox(true, "eaxpriestdiscipline_use_inner_focus")


menu.show_dashboard                   = core.menu.checkbox(true, "eaxpriestdiscipline_dashboard_enabled")
menu.dashboard_opacity                   = core.menu.slider_int(50, 255, 190, "eaxpriestdiscipline_dashboard_opacity")
menu.dashboard_x                         = core.menu.slider_int(0, 2000, 20, "eaxpriestdiscipline_dashboard_x")
menu.dashboard_y                         = core.menu.slider_int(0, 2000, 200, "eaxpriestdiscipline_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxpriestdiscipline_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxpriestdiscipline_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxpriestdiscipline_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxpriestdiscipline_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxpriestdiscipline_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxpriestdiscipline_enable_smart_collapse")
menu.dashboard_scale                     = core.menu.slider_float(0.5, 2.0, 1.0, "eaxpriestdiscipline_dashboard_scale")


menu.use_healthstone                     = core.menu.checkbox(true, "eaxpriestdiscipline_use_healthstone")
menu.healthstone_threshold               = core.menu.slider_int(10, 50, 30, "eaxpriestdiscipline_healthstone_threshold")
menu.use_healing_potion                  = core.menu.checkbox(true, "eaxpriestdiscipline_use_healing_potion")
menu.healing_potion_threshold            = core.menu.slider_int(10, 50, 25, "eaxpriestdiscipline_healing_potion_threshold")
menu.use_mana_potion                     = core.menu.checkbox(true, "eaxpriestdiscipline_use_mana_potion")
menu.mana_potion_threshold               = core.menu.slider_int(5, 50, 20, "eaxpriestdiscipline_mana_potion_threshold")
menu.use_emergency_heal                  = core.menu.checkbox(true, "eaxpriestdiscipline_use_emergency_heal")
menu.emergency_heal_threshold            = core.menu.slider_int(10, 60, 30, "eaxpriestdiscipline_emergency_heal_threshold")
menu.use_defensive_racial                = core.menu.checkbox(true, "eaxpriestdiscipline_use_defensive_racial")
menu.defensive_racial_threshold          = core.menu.slider_int(10, 60, 40, "eaxpriestdiscipline_defensive_racial_threshold")

-- Consumables
menu.use_healthstone                     = core.menu.checkbox(true, "eaxpriestdiscipline_use_healthstone")
menu.healthstone_hp_pct                  = core.menu.slider_int(10, 50, 30, "eaxpriestdiscipline_healthstone_hp_pct")
menu.use_healing_potion                  = core.menu.checkbox(true, "eaxpriestdiscipline_use_healing_potion")
menu.healing_potion_hp_pct               = core.menu.slider_int(10, 50, 25, "eaxpriestdiscipline_healing_potion_hp_pct")

-- Mana Management
menu.use_mana_manager = core.menu.checkbox(true, "eaxpriestdiscipline_use_mana_manager")
menu.shadowfiend_pct = core.menu.slider_int(5, 100, 50, "eaxpriestdiscipline_shadowfiend_pct")
menu.mana_potion_pct = core.menu.slider_int(5, 100, 20, "eaxpriestdiscipline_mana_potion_pct")
menu.dark_rune_pct = core.menu.slider_int(5, 100, 15, "eaxpriestdiscipline_dark_rune_pct")

mana_conservator.register_menu_items(menu, "eax_priest_discipline")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_greater_heal", label = "Greater Heal" },
    { toggle = "use_flash_heal", label = "Flash Heal" },
    { toggle = "use_power_word_shield", label = "PW:Shield" },
}, {
    namespace = "eaxpriestdiscipline",
    log_prefix = "[Eax Priest Disc] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpriestdiscipline")
    end

    root_tree:render("Eax's Priest Discipline", function()
        ps.render_controls(menu, "Eax's Priest Disc")

        -- Healing
        rotation_tree:render("Healing", function()
            ps.header("Direct Heals")
            menu.use_greater_heal:render("Greater Heal", "Main heal")
            menu.greater_heal_hp_pct:render("Greater Heal HP %", "Below")
            menu.use_flash_heal:render("Flash Heal", "Fast heal")
            menu.flash_heal_hp_pct:render("Flash Heal HP %", "Below")
            menu.disc_emergency_hp:render("Emergency HP %", "Flash Heal emergency threshold")
            menu.use_renew:render("Renew", "HoT")
            menu.renew_threshold:render("Renew HP %", "Below")
            menu.renew_refresh_seconds:render("Renew Refresh", "Seconds before expiry")
            menu.disc_prepull_renew:render("Pre-Pull Renew", "Cast Renew on tank before combat")
            menu.use_weakened_soul:render("Weakened Soul", "Track debuff")
            ps.header("Shields & Cooldowns")
            menu.use_power_word_shield:render("PW:Shield", "Shield")
            menu.shield_threshold:render("Shield Threshold", "HP% to cast")
            menu.disc_shield_emergency_hp:render("PW:S Emergency %", "Emergency shield threshold")
            -- NOTE: Penance/Aegis/Divine Aegis are WotLK, not TBC - removed
            menu.use_power_infusion:render("Power Infusion", "Haste buff")
            menu.use_pain_suppression:render("Pain Suppression", "Tank cooldown")
            menu.pain_suppression_threshold:render("Pain Suppression %", "Below")
            menu.use_inner_focus:render("Inner Focus", "Free spell")
            ps.header("Group Healing")
            menu.use_prayer_of_mending:render("Prayer of Mending", "Bounce heal")
            menu.prayer_of_mending_threshold:render("PoM Threshold", "HP% to cast")
            menu.prepull_pom:render("Pre-Pull PoM", "Cast PoM on tank before combat")
            menu.use_binding_heal:render("Binding Heal", "Self+Target heal")
            menu.binding_heal_self_threshold:render("Binding Self HP %", "Self below")
            menu.binding_heal_target_threshold:render("Binding Target HP %", "Target below")
            ps.header("AoE Healing")
            menu.disc_aoe_hp:render("AoE HP Threshold", "Group damage threshold")
            menu.disc_aoe_count:render("AoE Min Count", "Min injured for AoE")
        end)

        -- Buffs
        cd_tree:render("Buffs", function()
            menu.use_inner_fire:render("Inner Fire", "Armor")
            menu.use_power_word_fortitude:render("PW:F", "Stamina")
            menu.use_divine_spirit:render("Divine Spirit", "Spirit buff")
            menu.use_shadow_protection:render("Shadow Protection", "Auto-apply Shadow Protection when missing")
            menu.use_fear_ward:render("Fear Ward", "Pre-combat fear immunity")
        end)

        -- Utility
        def_tree:render("Utility", function()
            menu.use_dispel_magic:render("Dispel Magic", "Dispel")
            menu.use_cure_disease:render("Cure Disease", "Dispel")
            menu.use_abolish_disease:render("Abolish Disease", "Dispel")
            menu.use_psychic_scream:render("Psychic Scream", "Fear")
            menu.use_shackle_undead:render("Shackle Undead", "CC")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
        end)

        
        def_tree:render("PvP Settings", function()
            menu.pvp_mode:render("Enable PvP Mode", "Use PvP abilities against players")
            ps.header("Crowd Control")
            menu.pvp_use_psychic_scream:render("Psychic Scream", "AoE fear when enemies close")
            menu.pvp_psychic_scream_threshold:render("Scream HP%", "Health threshold to use scream")
            menu.pvp_use_silence:render("Silence", "Silence enemy casters")
            menu.pvp_use_shackle:render("Shackle Undead", "CC undead targets")
            menu.pvp_shackle_threshold:render("Shackle HP%", "Target HP threshold")
        end)

        
        def_tree:render("Dashboard & Consumables", function()
            ps.header("Consumables")
            menu.use_healthstone:render("Healthstone", "Use healthstone")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.use_healing_potion:render("Healing Potion", "Use potion")
            menu.healing_potion_hp_pct:render("Healing Potion HP %", "Below")
            ps.header("Dashboard")
            menu.show_dashboard:render("Enable Dashboard", "Show combat HUD")
            menu.dashboard_opacity:render("Opacity", "Dashboard background opacity")
            menu.dashboard_x:render("Position X", "Horizontal position")
            menu.dashboard_y:render("Position Y", "Vertical position")            
            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent spell casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
            menu.dashboard_scale:render("Scale", "Dashboard size multiplier")
            ps.header("Middleware (Auto-Items)")
            menu.use_healthstone:render("Use Healthstone", "Auto-use healthstones")
            menu.healthstone_threshold:render("Healthstone HP%", "Health threshold")
            menu.use_healing_potion:render("Use Healing Potion", "Auto-use healing potions")
            menu.healing_potion_threshold:render("Healing Potion HP%", "Health threshold")
            menu.use_mana_potion:render("Use Mana Potion", "Auto-use mana potions")
            menu.mana_potion_threshold:render("Mana Potion MP%", "Mana threshold")
            ps.header("Emergency & Racials")
            menu.use_emergency_heal:render("Emergency Flash Heal", "Self-cast when critical")
            menu.emergency_heal_threshold:render("Emergency Heal HP%", "Critical health threshold")
            menu.use_defensive_racial:render("Defensive Racial", "Use Stoneform/etc")
            menu.defensive_racial_threshold:render("Racial HP%", "Health threshold for racial")
        end)

        -- DPS Fallback
        auto_tree:render("DPS Fallback", function()
            menu.use_smite:render("Smite", "Filler")
            menu.use_holy_fire:render("Holy Fire", "Cast")
            menu.use_shadow_word_pain:render("SW:P", "DoT")
            menu.use_mind_blast:render("Mind Blast", "Instant")
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
            menu.use_resurrection:render("Resurrection", "Resurrect")
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end


return menu


