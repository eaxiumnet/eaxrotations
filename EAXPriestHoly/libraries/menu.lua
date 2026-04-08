-- +------------------------------------------------------------------+
-- |  Eax's Priest Holy
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
local automation_tree = ps.tree_node()  -- FIX: Separate tree for Automation section
local ooc_tree     = ps.tree_node()
local group_tree   = ps.tree_node()
local def_tree     = ps.tree_node()
local advanced_tree = ps.tree_node()

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxpriestholy_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpriestholy_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpriestholy_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpriestholy_debug")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpriestholy_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpriestholy_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpriestholy_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpriestholy_racial_hp")

-- Interrupt
menu.use_interrupt                       = core.menu.checkbox(true, "eaxpriestholy_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpriestholy_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpriestholy_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpriestholy_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpriestholy_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpriestholy_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpriestholy_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpriestholy_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpriestholy_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpriestholy_spirit_tap_wand")


menu.use_greater_heal                    = core.menu.checkbox(true, "eaxpriestholy_use_greater_heal")
menu.greater_heal_hp_pct                = core.menu.slider_int(10, 100, 60, "eaxpriestholy_greater_heal_hp_pct")
menu.use_flash_heal                      = core.menu.checkbox(true, "eaxpriestholy_use_flash_heal")
menu.flash_heal_hp_pct                  = core.menu.slider_int(10, 100, 50, "eaxpriestholy_flash_heal_hp_pct")  
menu.holy_emergency_hp                   = core.menu.slider_int(5, 50, 30, "eaxpriestholy_emergency_hp")  
menu.use_renew                           = core.menu.checkbox(true, "eaxpriestholy_use_renew")
menu.renew_threshold                     = core.menu.slider_int(0, 100, 90, "eaxpriestholy_renew_threshold")  
menu.renew_refresh_seconds               = core.menu.slider_int(0, 10, 3, "eaxpriestholy_renew_refresh")
menu.holy_prepull_renew                  = core.menu.checkbox(true, "eaxpriestholy_prepull_renew")  
menu.use_holy_nova                       = core.menu.checkbox(true, "eaxpriestholy_use_holy_nova")
menu.use_circle_of_healing               = core.menu.checkbox(true, "eaxpriestholy_use_circle_of_healing")
menu.circle_of_healing_enabled           = core.menu.checkbox(true, "eaxpriestholy_coh_enabled")
menu.circle_of_healing_threshold         = core.menu.slider_int(0, 100, 80, "eaxpriestholy_coh_threshold")
menu.circle_of_healing_count             = core.menu.slider_int(2, 5, 3, "eaxpriestholy_coh_count")
menu.use_binding_heal                   = core.menu.checkbox(true, "eaxpriestholy_use_binding_heal")
menu.binding_heal_enabled                = core.menu.checkbox(true, "eaxpriestholy_binding_heal_enabled")
menu.binding_heal_self_threshold         = core.menu.slider_int(0, 100, 80, "eaxpriestholy_binding_heal_self_threshold")  
menu.binding_heal_target_threshold        = core.menu.slider_int(0, 100, 80, "eaxpriestholy_binding_heal_target_threshold")  
menu.use_prayer_of_mending               = core.menu.checkbox(true, "eaxpriestholy_use_prayer_of_mending")
menu.prayer_of_mending_hp_pct           = core.menu.slider_int(10, 100, 85, "eaxpriestholy_pom_hp_pct")
menu.prayer_of_mending_threshold        = menu.prayer_of_mending_hp_pct  -- Alias for compatibility
menu.prepull_pom                         = core.menu.checkbox(true, "eaxpriestholy_prepull_pom")
menu.holy_aoe_hp                         = core.menu.slider_int(50, 100, 80, "eaxpriestholy_aoe_hp")  
menu.holy_aoe_count                      = core.menu.slider_int(2, 5, 3, "eaxpriestholy_aoe_count")
menu.use_prayer_of_healing               = core.menu.checkbox(true, "eaxpriestholy_use_prayer_of_healing")
menu.prayer_of_healing_enabled          = core.menu.checkbox(true, "eaxpriestholy_poh_enabled")
menu.prayer_of_healing_threshold         = core.menu.slider_int(10, 100, 70, "eaxpriestholy_poh_threshold")
menu.prayer_of_healing_count             = core.menu.slider_int(2, 5, 3, "eaxpriestholy_poh_count")
menu.use_inner_focus                     = core.menu.checkbox(true, "eaxpriestholy_use_inner_focus")
menu.use_power_word_shield               = core.menu.checkbox(true, "eaxpriestholy_use_power_word_shield")
menu.holy_pws_hp                         = core.menu.slider_int(5, 50, 30, "eaxpriestholy_pws_hp")  
menu.use_dispels                         = core.menu.checkbox(true, "eaxpriestholy_use_dispels")
menu.use_cooldowns                       = core.menu.checkbox(true, "eaxpriestholy_use_cooldowns")
menu.use_lightwell                       = core.menu.checkbox(true, "eaxpriestholy_use_lightwell")
menu.lightwell_hp_pct                   = core.menu.slider_int(0, 100, 60, "eaxpriestholy_lightwell_hp_pct")
-- NOTE: Divine Hymn is WotLK spell, not TBC - removed
menu.use_inner_fire                      = core.menu.checkbox(true, "eaxpriestholy_use_inner_fire")
menu.use_power_word_fortitude            = core.menu.checkbox(true, "eaxpriestholy_use_power_word_fortitude")
menu.use_divine_spirit                   = core.menu.checkbox(true, "eaxpriestholy_use_divine_spirit")
menu.use_shadow_protection               = core.menu.checkbox(true, "eaxpriestholy_use_shadow_protection")
menu.use_fear_ward                       = core.menu.checkbox(true, "eaxpriestholy_use_fear_ward")
menu.use_dispel_magic                    = core.menu.checkbox(true, "eaxpriestholy_use_dispel_magic")
menu.use_cure_disease                    = core.menu.checkbox(true, "eaxpriestholy_use_cure_disease")
menu.use_abolish_disease                 = core.menu.checkbox(true, "eaxpriestholy_use_abolish_disease")
menu.use_psychic_scream                  = core.menu.checkbox(true, "eaxpriestholy_use_psychic_scream")
menu.use_shackle_undead                  = core.menu.checkbox(true, "eaxpriestholy_use_shackle_undead")
menu.use_resurrection                    = core.menu.checkbox(true, "eaxpriestholy_use_resurrection")
menu.use_smite                           = core.menu.checkbox(true, "eaxpriestholy_use_smite")
menu.use_holy_fire                       = core.menu.checkbox(true, "eaxpriestholy_use_holy_fire")
menu.use_shadow_word_pain                = core.menu.checkbox(true, "eaxpriestholy_use_shadow_word_pain")
menu.holy_flash_heal_hp                   = core.menu.slider_int(10, 100, 50, "eaxpriestholy_flash_heal_hp_threshold")
menu.holy_dps_when_idle                  = core.menu.checkbox(true, "eaxpriestholy_dps_when_idle")
menu.holy_dps_mana_floor                 = core.menu.slider_int(10, 100, 70, "eaxpriestholy_dps_mana_floor")


menu.pvp_mode                            = core.menu.checkbox(false, "eaxpriestholy_pvp_mode")
menu.pvp_use_psychic_scream              = core.menu.checkbox(true, "eaxpriestholy_pvp_psychic_scream")
menu.pvp_psychic_scream_threshold        = core.menu.slider_int(10, 100, 60, "eaxpriestholy_pvp_scream_threshold")
menu.pvp_use_silence                     = core.menu.checkbox(true, "eaxpriestholy_pvp_silence")
menu.pvp_use_shackle                     = core.menu.checkbox(true, "eaxpriestholy_pvp_shackle")
menu.pvp_shackle_threshold               = core.menu.slider_int(10, 100, 80, "eaxpriestholy_pvp_shackle_threshold")


menu.show_dashboard                   = core.menu.checkbox(true, "eaxpriestholy_dashboard_enabled")
menu.dashboard_x                         = core.menu.slider_int(0, 1000, 20, "eaxpriestholy_dashboard_x")
menu.dashboard_y                         = core.menu.slider_int(0, 1000, 200, "eaxpriestholy_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxpriestholy_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxpriestholy_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxpriestholy_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxpriestholy_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxpriestholy_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxpriestholy_enable_smart_collapse")
menu.dashboard_scale                     = core.menu.slider_float(0.5, 2.0, 1.0, "eaxpriestholy_dashboard_scale")


menu.use_healthstone                     = core.menu.checkbox(true, "eaxpriestholy_use_healthstone")
menu.healthstone_threshold               = core.menu.slider_int(10, 50, 30, "eaxpriestholy_healthstone_threshold")
menu.use_healing_potion                  = core.menu.checkbox(true, "eaxpriestholy_use_healing_potion")
menu.healing_potion_threshold            = core.menu.slider_int(10, 50, 25, "eaxpriestholy_healing_potion_threshold")
menu.use_mana_potion                     = core.menu.checkbox(true, "eaxpriestholy_use_mana_potion")
menu.mana_potion_threshold               = core.menu.slider_int(5, 50, 20, "eaxpriestholy_mana_potion_threshold")
menu.use_emergency_heal                  = core.menu.checkbox(true, "eaxpriestholy_use_emergency_heal")
menu.emergency_heal_threshold            = core.menu.slider_int(10, 60, 30, "eaxpriestholy_emergency_heal_threshold")
menu.use_defensive_racial                = core.menu.checkbox(true, "eaxpriestholy_use_defensive_racial")
menu.defensive_racial_threshold          = core.menu.slider_int(10, 60, 40, "eaxpriestholy_defensive_racial_threshold")

mana_conservator.register_menu_items(menu, "eax_priest_holy")

-- Mana Management
menu.use_mana_manager = core.menu.checkbox(true, "eaxpriestholy_use_mana_manager")
menu.shadowfiend_pct = core.menu.slider_int(5, 100, 50, "eaxpriestholy_shadowfiend_pct")
menu.mana_potion_pct = core.menu.slider_int(5, 100, 20, "eaxpriestholy_mana_potion_pct")
menu.dark_rune_pct = core.menu.slider_int(5, 100, 15, "eaxpriestholy_dark_rune_pct")

-- Trinket Automation
menu.trinket1_mode = core.menu.combobox(1, "eaxpriestholy_trinket1_mode")
menu.trinket2_mode = core.menu.combobox(1, "eaxpriestholy_trinket2_mode")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_greater_heal", label = "Greater Heal" },
    { toggle = "use_flash_heal", label = "Flash Heal" },
    { toggle = "use_renew", label = "Renew" },
    { toggle = "use_prayer_of_mending", label = "Prayer of Mending" },
}, {
    namespace = "eaxpriestholy",
    log_prefix = "[Eax Priest Holy] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpriestholy")
    end

    root_tree:render("Eax's Priest Holy", function()
        -- General
        ps.header("General")
        menu.enabled:render("Enabled", "Enable rotation")
        menu.toggle_key:render("Toggle Key", "Quick enable/disable")
        menu.mode:render("Mode", "Auto/PvE/PvP")
        menu.debug:render("Debug", "Show debug info")

        -- Healing
        rotation_tree:render("Healing", function()
            ps.header("Direct Heals")
            menu.use_greater_heal:render("Greater Heal", "Main heal")
            menu.greater_heal_hp_pct:render("Greater Heal HP %", "Below")
            menu.use_flash_heal:render("Flash Heal", "Fast heal")
            menu.flash_heal_hp_pct:render("Flash Heal HP %", "Below")
            menu.holy_flash_heal_hp:render("Flash Heal Threshold", "For rotation logic")
            menu.holy_emergency_hp:render("Emergency HP %", "Flash Heal emergency threshold")
            menu.use_renew:render("Renew", "HoT")
            menu.renew_threshold:render("Renew HP %", "Below")
            menu.renew_refresh_seconds:render("Renew Refresh", "Seconds before expiry")
            menu.holy_prepull_renew:render("Pre-Pull Renew", "Cast Renew on tank before combat")
            menu.use_holy_nova:render("Holy Nova", "AoE heal")
            menu.use_circle_of_healing:render("Circle of Healing", "Instant AoE")
            menu.circle_of_healing_enabled:render("CoH Enabled", "Use Circle of Healing")
            menu.circle_of_healing_threshold:render("CoH HP %", "Below")
            menu.circle_of_healing_count:render("CoH Min Targets", "Use above")
            menu.use_binding_heal:render("Binding Heal", "Self + target")
            menu.binding_heal_enabled:render("Binding Heal Enabled", "Use binding heal")
            menu.binding_heal_self_threshold:render("Binding Self HP %", "Self below")
            menu.binding_heal_target_threshold:render("Binding Target HP %", "Target below")
            menu.use_prayer_of_mending:render("Prayer of Mending", "Bouncing heal")
            menu.prayer_of_mending_hp_pct:render("PoM HP %", "Below")
            menu.prepull_pom:render("Pre-Pull PoM", "Cast PoM on tank before combat")
            menu.use_lightwell:render("Lightwell", "Click heal")
            menu.lightwell_hp_pct:render("Lightwell HP %", "Below")
            -- NOTE: Divine Hymn is WotLK spell, not TBC - removed from rotation
            ps.header("AoE Healing")
            menu.holy_aoe_hp:render("AoE HP Threshold", "Group damage threshold")
            menu.holy_aoe_count:render("AoE Min Count", "Min injured for AoE")
            menu.use_prayer_of_healing:render("Prayer of Healing", "Channeled AoE")
            menu.prayer_of_healing_enabled:render("PoH Enabled", "Use Prayer of Healing")
            menu.prayer_of_healing_threshold:render("PoH HP %", "Below")
            menu.prayer_of_healing_count:render("PoH Min Targets", "Use above")
            ps.header("Shields & Cooldowns")
            menu.use_inner_focus:render("Inner Focus", "Free spell")
            menu.use_power_word_shield:render("PW:Shield", "Emergency shield")
            menu.holy_pws_hp:render("PW:S Emergency %", "Shield emergency threshold")
            ps.header("Trinkets")
            menu.trinket1_mode:render("Trinket 1 Mode", "Off/Offensive/Defensive")
            menu.trinket2_mode:render("Trinket 2 Mode", "Off/Offensive/Defensive")
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
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_dispel_magic:render("Dispel Magic", "Dispel")
            menu.use_cure_disease:render("Cure Disease", "Dispel")
            menu.use_abolish_disease:render("Abolish Disease", "Dispel")
            menu.use_psychic_scream:render("Psychic Scream", "Fear")
            menu.use_shackle_undead:render("Shackle Undead", "CC")
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

        
        def_tree:render("Dashboard & ", function()
            ps.header("Dashboard")
            menu.show_dashboard:render("Enable Dashboard", "Show combat HUD")
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
            menu.holy_dps_when_idle:render("DPS When Idle", "Cast damage spells when no healing needed")
            menu.holy_dps_mana_floor:render("DPS Mana Floor %", "Only DPS when mana above this")
            menu.use_smite:render("Smite", "Filler")
            menu.use_holy_fire:render("Holy Fire", "Cast")
            menu.use_shadow_word_pain:render("SW:P", "DoT")
        end)

        -- Automation (FIX: use separate pre-created tree node)
        automation_tree:render("Automation", function()
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

        -- Advanced (Targeting + Racial + Leveling)
        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target")
            menu.combat_self_hp_boost:render("Self HP Boost", "Self-heal priority boost")
            ps.header("Racial")
            menu.use_racial:render("Use Racial", "Use racial abilities")
            menu.racial_hp:render("Racial HP %", "Health threshold for racial")
            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling mode")
            menu.leveling_mana_floor:render("Mana Floor %", "Minimum mana %")
        end)
    end)
end


return menu


