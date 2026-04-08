-- +------------------------------------------------------------------+
-- |  Eax's Paladin Retribution
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes (Standard EAX Menu Structure)
local root_tree      = ps.tree_node()
local rotation_tree  = ps.tree_node()
local cd_tree        = ps.tree_node()
local blessings_tree = ps.tree_node()
local auras_tree     = ps.tree_node()
local def_tree       = ps.tree_node()
local utility_tree   = ps.tree_node()
local pvp_tree       = ps.tree_node()
local auto_tree      = ps.tree_node()
local dashboard_tree = ps.tree_node()
local advanced_tree = ps.tree_node()

settings.init({
    spec_name = "eaxpaladinretribution",
    class_name = "Paladin",
    role = "dps",
})

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxpaladinretribution_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpaladinretribution_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpaladinretribution_mode")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpaladinretribution_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpaladinretribution_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpaladinretribution_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpaladinretribution_racial_hp")

-- Interrupt
menu.use_interrupt                       = core.menu.checkbox(true, "eaxpaladinretribution_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpaladinretribution_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpaladinretribution_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpaladinretribution_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpaladinretribution_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpaladinretribution_lev_mana_floor")

-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- Rotation
menu.use_crusader_strike                 = core.menu.checkbox(true, "eaxpaladinretribution_use_crusader_strike")
menu.use_judgement                       = core.menu.checkbox(true, "eaxpaladinretribution_use_judgement")
menu.use_hammer_of_wrath                 = core.menu.checkbox(true, "eaxpaladinretribution_use_hammer_of_wrath")
menu.use_exorcism                        = core.menu.checkbox(true, "eaxpaladinretribution_use_exorcism")
menu.use_consecration                    = core.menu.checkbox(true, "eaxpaladinretribution_use_consecration")
menu.use_seal_twist                      = core.menu.checkbox(false, "eaxpaladinret_use_seal_twist")
menu.allow_twist_dungeon                 = core.menu.checkbox(true, "eaxpaladinret_allow_twist_dungeon")
menu.allow_twist_raid                    = core.menu.checkbox(false, "eaxpaladinret_allow_twist_raid")
menu.seal_twist_window                   = core.menu.slider_int(100, 500, 250, "eaxpaladinret_seal_twist_window")
menu.seal_twist_cooldown                 = core.menu.slider_int(0, 10, 3, "eaxpaladinret_seal_twist_cooldown")
menu.use_seal_twist_key                  = core.menu.keybind(7, false, "eaxpaladinretribution_seal_twist_key")
menu.use_seal_of_command                 = core.menu.checkbox(true, "eaxpaladinretribution_use_seal_of_command")
menu.use_seal_of_vengeance               = core.menu.checkbox(true, "eaxpaladinretribution_use_seal_of_vengeance")
menu.use_seal_of_righteousness           = core.menu.checkbox(true, "eaxpaladinretribution_use_seal_of_righteousness")
menu.use_blessing_of_might               = core.menu.checkbox(true, "eaxpaladinretribution_use_blessing_of_might")
menu.use_blessing_of_kings               = core.menu.checkbox(true, "eaxpaladinretribution_use_blessing_of_kings")
menu.use_blessing_of_wisdom              = core.menu.checkbox(true, "eaxpaladinretribution_use_blessing_of_wisdom")
menu.use_righteous_fury                  = core.menu.checkbox(false, "eaxpaladinretribution_use_righteous_fury")
menu.use_devotion_aura                   = core.menu.checkbox(true, "eaxpaladinretribution_use_devotion_aura")
menu.use_sanctity_aura                   = core.menu.checkbox(true, "eaxpaladinret_use_sanctity_aura")

-- Judgement and Aura
menu.judgement_choice                    = core.menu.combobox(1, "eaxpaladinret_judgement_choice")
menu.use_aura                            = core.menu.checkbox(true, "eaxpaladinret_use_aura")
menu.use_divine_illumination             = core.menu.checkbox(true, "eaxpaladinretribution_use_divine_illumination")
menu.use_zealotry                        = core.menu.checkbox(true, "eaxpaladinretribution_use_zealotry")
menu.use_crusader_aura                   = core.menu.checkbox(true, "eaxpaladinretribution_use_crusader_aura")
menu.use_retribution_aura                = core.menu.checkbox(true, "eaxpaladinretribution_use_retribution_aura")

-- Cooldowns
menu.use_avenging_wrath                  = core.menu.checkbox(true, "eaxpaladinret_use_avenging_wrath")
menu.use_divine_favor                    = core.menu.checkbox(true, "eaxpaladinret_use_divine_favor")
menu.use_divine_shield                   = core.menu.checkbox(true, "eaxpaladinretribution_use_divine_shield")
menu.divine_shield_hp_pct                = core.menu.slider_int(0, 100, 20, "eaxpaladinretribution_divine_shield_hp_pct")
menu.use_lay_on_hands                    = core.menu.checkbox(true, "eaxpaladinretribution_use_lay_on_hands")
menu.lay_on_hands_hp_pct                 = core.menu.slider_int(5, 30, 15, "eaxpaladinretribution_lay_on_hands_hp_pct")
menu.use_divine_protection               = core.menu.checkbox(true, "eaxpaladinretribution_use_divine_protection")
menu.divine_protection_hp_pct            = core.menu.slider_int(0, 100, 30, "eaxpaladinretribution_divine_protection_hp_pct")
menu.cd_min_ttd                          = core.menu.slider_int(0, 60, 0, "eaxpaladinretribution_cd_min_ttd")
menu.use_redemption                      = core.menu.checkbox(true, "eaxpaladinretribution_use_redemption")
menu.use_cleansing                       = core.menu.checkbox(true, "eaxpaladinretribution_use_cleansing")
menu.use_turn_undead                     = core.menu.checkbox(true, "eaxpaladinretribution_use_turn_undead")
menu.use_holy_wrath                      = core.menu.checkbox(true, "eaxpaladinretribution_use_holy_wrath")

-- Burst Manager
menu.auto_burst_enabled                  = core.menu.checkbox(true, "eaxpaladinret_auto_burst_enabled")
menu.burst_on_bloodlust                  = core.menu.checkbox(true, "eaxpaladinret_burst_on_bloodlust")
menu.burst_on_pull                       = core.menu.checkbox(true, "eaxpaladinret_burst_on_pull")
menu.burst_on_execute                    = core.menu.checkbox(true, "eaxpaladinret_burst_on_execute")
menu.burst_in_combat                     = core.menu.checkbox(false, "eaxpaladinret_burst_in_combat")

-- Trinket Manager
menu.trinket1_mode                       = core.menu.combobox(1, "eaxpaladinret_trinket1_mode")
menu.trinket2_mode                       = core.menu.combobox(1, "eaxpaladinret_trinket2_mode")

-- Flux Swing Manager
menu.use_swing_manager                   = core.menu.checkbox(true, "eaxpaladinret_use_swing_manager")
menu.swing_queue_threshold               = core.menu.slider_int(30, 100, 50, "eaxpaladinret_swing_queue_threshold")

-- Hand of Freedom
menu.use_hand_of_freedom                 = core.menu.checkbox(true, "eaxpaladinret_use_hand_of_freedom")
menu.hof_include_slows                   = core.menu.checkbox(false, "eaxpaladinret_hof_include_slows")

-- PvP / Consumables
menu.use_healthstone                     = core.menu.checkbox(true, "eaxpaladinretribution_use_healthstone")
menu.healthstone_hp_pct                  = core.menu.slider_int(5, 50, 30, "eaxpaladinretribution_healthstone_hp_pct")
menu.use_health_potion                   = core.menu.checkbox(true, "eaxpaladinretribution_use_health_potion")
menu.health_potion_hp_pct                = core.menu.slider_int(5, 50, 40, "eaxpaladinretribution_health_potion_hp_pct")
menu.use_mana_potion                     = core.menu.checkbox(true, "eaxpaladinretribution_use_mana_potion")
menu.mana_potion_pct                     = core.menu.slider_int(5, 50, 15, "eaxpaladinretribution_mana_potion_pct")

-- PvP Racials
menu.use_berserking                      = core.menu.checkbox(true, "eaxpaladinretribution_use_berserking")
menu.use_stoneform                       = core.menu.checkbox(true, "eaxpaladinretribution_use_stoneform")
menu.stoneform_hp_pct                    = core.menu.slider_int(10, 80, 40, "eaxpaladinretribution_stoneform_hp_pct")

-- Dashboard menu items
menu.dashboard_enabled      = core.menu.checkbox(true, "eaxpaladinret_dashboard_enabled")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxpaladinret_dashboard_opacity")
menu.dashboard_x            = core.menu.slider_int(0, 1000, 20, "eaxpaladinret_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 1000, 200, "eaxpaladinret_dashboard_y")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxpaladinret_dashboard_scale")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_crusader_strike", label = "Crusader Strike" },
    { toggle = "use_judgement", label = "Judgement" },
    { toggle = "use_consecration", label = "Consecration" },
}, {
    namespace = "eaxpaladinretribution",
    log_prefix = "[Eax Paladin Ret] ",
})

local _win
function menu.set_window(win) _win = win end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpaladinretribution")
    end

    root_tree:render("Eax's Paladin Retribution", function()
        -- 1. General - Visible immediately at top level
        ps.header("General")
        menu.enabled:render("Enabled", "Enable/disable rotation")
        menu.mode:render("Mode", {"Auto", "PvE", "PvP"}, "Rotation mode selection")
        menu.toggle_key:render("Toggle Key", "Keybind to enable/disable")

        -- 2. Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Core Abilities")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_crusader_strike:render("Crusader Strike", "On CD")
            menu.use_judgement:render("Judgement", "On CD")
            menu.judgement_choice:render("Judgement Choice", {"Wisdom", "Light", "Justice"}, "Seal to judge")
            menu.use_hammer_of_wrath:render("Hammer of Wrath", "Execute")
            menu.use_exorcism:render("Exorcism", "Undead/Demon")
            menu.use_consecration:render("Consecration", "AoE")

            ps.header("Seal Twisting")
            menu.use_seal_twist:render("Seal Twist", "Dual seal")
            menu.allow_twist_dungeon:render("Twist in Dungeon", "Allow")
            menu.allow_twist_raid:render("Twist in Raid", "Allow")
            menu.seal_twist_window:render("Twist Window (ms)", "Timing")
            menu.seal_twist_cooldown:render("Twist Cooldown (s)", "Seconds")
            menu.use_seal_twist_key:render("Seal Twist Key", "Keybind for manual twist")

            ps.header("Seals")
            menu.use_seal_of_command:render("Seal of Command", "Proc")
            menu.use_seal_of_vengeance:render("Seal of Vengeance", "DoT")
            menu.use_seal_of_righteousness:render("Seal of Righteousness", "DPS")

            ps.header("Utility")
            menu.use_aura:render("Auto Aura", "Maintain aura")
            menu.use_cleansing:render("Cleansing", "Dispel")
            menu.use_turn_undead:render("Turn Undead", "CC")
            menu.use_holy_wrath:render("Holy Wrath", "AoE undead")
        end)

        -- 3. Cooldowns
        cd_tree:render("Cooldowns", function()
            ps.header("Major Cooldowns")
            menu.use_divine_illumination:render("Divine Illumination", "CD reduction")
            menu.use_avenging_wrath:render("Avenging Wrath", "Damage boost")
            menu.use_divine_favor:render("Divine Favor", "Guaranteed crit")
            menu.use_zealotry:render("Zealotry", "Holy Power generation")
            menu.cd_min_ttd:render("Min TTD for CDs", "Don't burst if target dies sooner (sec)")

            ps.header("Auto Burst")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst logic")
            menu.burst_on_bloodlust:render("On Bloodlust", "Burst when bloodlust active")
            menu.burst_on_pull:render("On Pull", "Burst in first 5 seconds")
            menu.burst_on_execute:render("On Execute", "Burst below 20% HP")
            menu.burst_in_combat:render("In Combat", "Burst whenever in combat")

            ps.header("Trinkets")
            menu.trinket1_mode:render("Trinket 1", {"Off", "Offensive", "Defensive"})
            menu.trinket2_mode:render("Trinket 2", {"Off", "Offensive", "Defensive"})

            ps.header("Swing Management")
            menu.use_swing_manager:render("Use Swing Manager", "Queue abilities optimally")
            menu.swing_queue_threshold:render("Queue Threshold", "Rage to queue next swing")
        end)

        -- 4. Blessings
        blessings_tree:render("Blessings", function()
            ps.header("Self Blessings")
            menu.use_blessing_of_might:render("Blessing of Might", "AP buff")
            menu.use_blessing_of_kings:render("Blessing of Kings", "Stats buff")
            menu.use_blessing_of_wisdom:render("Blessing of Wisdom", "Mana regen")
        end)

        -- 5. Auras
        auras_tree:render("Auras", function()
            ps.header("Combat Auras")
            menu.use_sanctity_aura:render("Sanctity Aura", "Holy damage buff")
            menu.use_retribution_aura:render("Retribution Aura", "Reflect damage")
            menu.use_devotion_aura:render("Devotion Aura", "Armor buff")
            menu.use_crusader_aura:render("Crusader Aura", "Mount speed")
            menu.use_righteous_fury:render("Righteous Fury", "Threat buff")
        end)

        -- 6. Defensive
        def_tree:render("Defensive", function()
            ps.header("Emergency Cooldowns")
            menu.use_divine_shield:render("Divine Shield", "Immunity")
            menu.divine_shield_hp_pct:render("Divine Shield HP %", "Below")
            menu.use_lay_on_hands:render("Lay on Hands", "Emergency heal")
            menu.lay_on_hands_hp_pct:render("LoH HP %", "Below")
            menu.use_divine_protection:render("Divine Protection", "Damage reduction")
            menu.divine_protection_hp_pct:render("Divine Protection HP %", "Below")
        end)

        -- 7. Utility
        utility_tree:render("Utility", function()
            ps.header("Hand of Freedom")
            menu.use_hand_of_freedom:render("Hand of Freedom", "Remove roots/snares")
            menu.hof_include_slows:render("Include Slows", "Slow effects")

            ps.header("Other")
            menu.use_redemption:render("Redemption", "Resurrect")
        end)

        -- 8. PvP / Consumables
        pvp_tree:render("PvP / Consumables", function()
            ps.header("Consumables")
            menu.use_healthstone:render("Healthstone", "Auto-use")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Below")
            menu.use_health_potion:render("Healing Potion", "Auto-use")
            menu.health_potion_hp_pct:render("Heal Potion HP %", "Below")
            menu.use_mana_potion:render("Mana Potion", "Auto-use")
            menu.mana_potion_pct:render("Mana Potion %", "Below")

            ps.header("Racials")
            menu.use_berserking:render("Berserking", "Troll haste")
            menu.use_stoneform:render("Stoneform", "Dwarf cleanse")
            menu.stoneform_hp_pct:render("Stoneform HP %", "Below")
        end)

        -- 9. Automation
        auto_tree:render("Automation", function()
            ps.header("Auto Items")
            menu.auto_combat_potions:render("Combat Potions", "In combat")
            menu.auto_ooc_food_drink:render("OOC Food/Drink", "Eat/drink")
            menu.auto_flask:render("Auto Flask", "Flask")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling")
            menu.leveling_mana_floor:render("Mana %", "Below")

            ps.header("OOC Sustain")
            menu.ooc_drink:render("Auto-Drink", "Drink")
            menu.drink_threshold:render("Drink %", "Below")
            menu.ooc_eat:render("Auto-Eat", "Eat")
            menu.eat_threshold:render("Eat %", "Below")

            ps.header("Group Support")
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
        end)

        -- 10. Dashboard
        dashboard_tree:render("Dashboard", function()
            menu.dashboard_enabled:render("Enable Dashboard", "Show combat dashboard")
            menu.dashboard_opacity:render("Opacity", "Dashboard background opacity")
            menu.dashboard_x:render("Position X", "Horizontal position")
            menu.dashboard_y:render("Position Y", "Vertical position")
            menu.dashboard_scale:render("Scale", "Dashboard size multiplier")
        end)

        -- 11. Advanced (Targeting and Racial)
        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target")
            menu.combat_self_hp_boost:render("Self HP Boost", "HP threshold adjustment")

            ps.header("Racial")
            menu.use_racial:render("Use Racial", "Auto-use racial abilities")
            menu.racial_hp:render("Racial HP %", "Use below this HP")
        end)
    end)
end

return menu
