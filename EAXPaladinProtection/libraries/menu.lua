-- +--------------------------------------------------------------------------+
-- |  Eax Paladin Protection  -  Menu  v2.0  -  menu.lua                    |
-- |                                                                          |
-- |  Using ps_theme for consistent EAX rotation UI                          |
-- +--------------------------------------------------------------------------+

local ps       = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")


local menu = {}

-- -- Tree nodes (Standard EAX Menu Structure) -----------------------------
local root_tree      = ps.tree_node()
local rotation_tree  = ps.tree_node()
local blessings_tree = ps.tree_node()
local defensive_tree = ps.tree_node()
local pvp_tree       = ps.tree_node()
local automation_tree = ps.tree_node()
local ooc_tree       = ps.tree_node()
local group_tree     = ps.tree_node()
local dashboard_tree = ps.tree_node()
local advanced_tree  = ps.tree_node()

settings.init({
    spec_name = "eaxpaladinprotection",
    class_name = "Paladin",
    role = "tank",
})

-- -- Controls ------------------------------------------------------------------
menu.enabled         = core.menu.checkbox(true,  "eaxpaladinprotection_enabled")
menu.toggle_key      = core.menu.keybind(7, false, "eaxpaladinprotection_toggle_key")
menu.mode            = core.menu.combobox(1, "eaxpaladinprotection_mode")

-- -- Targeting ------------------------------------------------------------------
menu.focus_priority        = core.menu.checkbox(false, "eaxpaladinprotection_focus_priority")
menu.combat_self_hp_boost  = core.menu.slider_int(0, 30, 10, "eaxpaladinprotection_combat_self_hp_boost")

-- -- Racial --------------------------------------------------------------------
menu.use_racial  = core.menu.checkbox(true, "eaxpaladinprotection_use_racial")
menu.racial_hp   = core.menu.slider_int(10, 80, 40, "eaxpaladinprotection_racial_hp")

-- -- Interrupt -----------------------------------------------------------------
menu.use_interrupt = core.menu.checkbox(true, "eaxpaladinprotection_use_interrupt")

-- -- OOC -----------------------------------------------------------------------
menu.ooc_drink        = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat          = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez          = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff   = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold  = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold    = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- -- Automation ----------------------------------------------------------------
menu.auto_combat_potions = core.menu.checkbox(false, "eaxpaladinprotection_auto_combat_potions")
menu.auto_ooc_food_drink = core.menu.checkbox(true, "eaxpaladinprotection_auto_ooc_food_drink")
menu.auto_flask          = core.menu.checkbox(false, "eaxpaladinprotection_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true, "eaxpaladinprotection_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxpaladinprotection_lev_mana_floor")

-- -- Rotation ------------------------------------------------------------------
menu.use_holy_shield                     = core.menu.checkbox(true, "eaxpaladinprotection_use_holy_shield")
menu.prioritize_holy_shield              = core.menu.checkbox(true, "eaxpaladinprotection_prioritize_holy_shield")
menu.use_shield_of_righteous             = core.menu.checkbox(true, "eaxpaladinprotection_use_shield_of_righteous")
menu.use_judgement                       = core.menu.checkbox(true, "eaxpaladinprotection_use_judgement")
menu.use_consecration                    = core.menu.checkbox(true, "eaxpaladinprotection_use_consecration")
menu.use_hammer_of_wrath                 = core.menu.checkbox(true, "eaxpaladinprotection_use_hammer_of_wrath")
menu.use_avengers_shield                 = core.menu.checkbox(true, "eaxpaladinprotection_use_avengers_shield")
menu.use_exorcism                        = core.menu.checkbox(true, "eaxpaladinprotection_use_exorcism")
menu.use_righteous_fury                  = core.menu.checkbox(true, "eaxpaladinprotection_use_righteous_fury")
menu.use_seal_of_righteousness           = core.menu.checkbox(true, "eaxpaladinprotection_use_seal_of_righteousness")
menu.use_seal_of_vengeance               = core.menu.checkbox(true, "eaxpaladinprotection_use_seal_of_vengeance")
menu.use_seal_of_command                 = core.menu.checkbox(true, "eaxpaladinprotection_use_seal_of_command")
menu.seal_choice                         = core.menu.combobox(1, "eaxpaladinprotection_seal_choice")
menu.use_seal_of_wisdom_low_mana         = core.menu.checkbox(false, "eaxpaladinprotection_use_seal_of_wisdom_low_mana")
menu.seal_of_wisdom_mana_pct             = core.menu.slider_int(5, 50, 20, "eaxpaladinprotection_seal_of_wisdom_mana_pct")
menu.use_cleansing                       = core.menu.checkbox(true, "eaxpaladinprotection_use_cleansing")
menu.use_turn_undead                     = core.menu.checkbox(true, "eaxpaladinprotection_use_turn_undead")
menu.use_holy_wrath                      = core.menu.checkbox(true, "eaxpaladinprotection_use_holy_wrath")
menu.use_cleanse                         = core.menu.checkbox(true, "eaxpaladinprotection_use_cleanse")
menu.use_hammer_of_justice               = core.menu.checkbox(true, "eaxpaladinprotection_use_hammer_of_justice")
menu.use_auto_tab                        = core.menu.checkbox(true, "eaxpaladinprotection_use_auto_tab")
menu.no_taunt                            = core.menu.checkbox(false, "eaxpaladinprotection_no_taunt")
menu.use_righteous_defense               = core.menu.checkbox(true, "eaxpaladinprotection_use_righteous_defense")
menu.tab_max_mobs                        = core.menu.slider_int(2, 10, 4, "eaxpaladinprotection_tab_max_mobs")
menu.show_notifications                  = core.menu.checkbox(true, "eaxpaladinprotection_show_notifications")
menu.consecration_enemy_count            = core.menu.slider_int(1, 10, 3, "eaxpaladinprotection_consecration_enemy_count")
menu.consecration_radius                 = core.menu.slider_int(1, 30, 8, "eaxpaladinprotection_consecration_radius")

-- -- Blessings -----------------------------------------------------------------
menu.use_blessing_of_sanctuary           = core.menu.checkbox(true, "eaxpaladinprotection_use_blessing_of_sanctuary")
menu.use_blessing_of_kings               = core.menu.checkbox(true, "eaxpaladinprotection_use_blessing_of_kings")
menu.use_blessing_of_might               = core.menu.checkbox(true, "eaxpaladinprotection_use_blessing_of_might")
menu.use_blessing_of_wisdom              = core.menu.checkbox(true, "eaxpaladinprotection_use_blessing_of_wisdom")

-- -- Defensive -----------------------------------------------------------------
menu.use_divine_shield                   = core.menu.checkbox(true, "eaxpaladinprotection_use_divine_shield")
menu.divine_shield_hp_pct                = core.menu.slider_int(0, 100, 20, "eaxpaladinprotection_divine_shield_hp_pct")
menu.use_lay_on_hands                    = core.menu.checkbox(true, "eaxpaladinprotection_use_lay_on_hands")
menu.lay_on_hands_hp_pct                 = core.menu.slider_int(5, 30, 15, "eaxpaladinprotection_lay_on_hands_hp_pct")
menu.use_divine_protection               = core.menu.checkbox(true, "eaxpaladinprotection_use_divine_protection")
menu.divine_protection_hp_pct            = core.menu.slider_int(0, 100, 30, "eaxpaladinprotection_divine_protection_hp_pct")
menu.use_blessing_of_protection          = core.menu.checkbox(true, "eaxpaladinprotection_use_blessing_of_protection")
menu.blessing_of_protection_hp_pct       = core.menu.slider_int(0, 100, 25, "eaxpaladinprotection_blessing_of_protection_hp_pct")
menu.use_gift_of_the_naaru               = core.menu.checkbox(true, "eaxpaladinprotection_use_gift_of_the_naaru")
menu.gift_of_the_naaru_hp_pct            = core.menu.slider_int(10, 80, 50, "eaxpaladinprotection_gift_of_the_naaru_hp_pct")
menu.use_redemption                      = core.menu.checkbox(true, "eaxpaladinprotection_use_redemption")
menu.use_devotion_aura                   = core.menu.checkbox(true, "eaxpaladinprotection_use_devotion_aura")

-- -- Burst / Avenging Wrath ----------------------------------------------------
menu.use_avenging_wrath                  = core.menu.checkbox(true, "eaxpaladinprotection_use_avenging_wrath")
menu.auto_burst_enabled                  = core.menu.checkbox(false, "eaxpaladinprotection_auto_burst_enabled")
menu.burst_on_bloodlust                  = core.menu.checkbox(true, "eaxpaladinprotection_burst_on_bloodlust")
menu.burst_on_pull                       = core.menu.checkbox(true, "eaxpaladinprotection_burst_on_pull")
menu.burst_on_execute                    = core.menu.checkbox(false, "eaxpaladinprotection_burst_on_execute")
menu.burst_in_combat                     = core.menu.checkbox(false, "eaxpaladinprotection_burst_in_combat")
menu.cd_min_ttd                          = core.menu.slider_int(0, 60, 10, "eaxpaladinprotection_cd_min_ttd")

-- -- PvP / Consumables ---------------------------------------------------------
menu.use_healthstone                     = core.menu.checkbox(true, "eaxpaladinprotection_use_healthstone")
menu.healthstone_hp_pct                  = core.menu.slider_int(5, 50, 30, "eaxpaladinprotection_healthstone_hp_pct")
menu.use_health_potion                   = core.menu.checkbox(true, "eaxpaladinprotection_use_health_potion")
menu.health_potion_hp_pct                = core.menu.slider_int(5, 50, 40, "eaxpaladinprotection_health_potion_hp_pct")
menu.use_mana_potion                     = core.menu.checkbox(true, "eaxpaladinprotection_use_mana_potion")
menu.mana_potion_pct                     = core.menu.slider_int(5, 50, 15, "eaxpaladinprotection_mana_potion_pct")

-- -- PvP Racials --------------------------------------------------------------
menu.use_berserking                      = core.menu.checkbox(true, "eaxpaladinprotection_use_berserking")
menu.use_stoneform                       = core.menu.checkbox(true, "eaxpaladinprotection_use_stoneform")
menu.stoneform_hp_pct                    = core.menu.slider_int(10, 80, 40, "eaxpaladinprotection_stoneform_hp_pct")

-- -- Trinkets ------------------------------------------------------------------
menu.trinket1_mode = core.menu.combobox(3, "eaxpaladinprotection_trinket1_mode")
menu.trinket2_mode = core.menu.combobox(3, "eaxpaladinprotection_trinket2_mode")

-- -- Dashboard -----------------------------------------------------------------
menu.dashboard_enabled      = core.menu.checkbox(true, "eaxpaladinprot_dashboard_enabled")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxpaladinprot_dashboard_opacity")
menu.dashboard_x            = core.menu.slider_int(0, 1000, 20, "eaxpaladinprot_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 1000, 200, "eaxpaladinprot_dashboard_y")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxpaladinprot_dashboard_scale")

-- -- Window --------------------------------------------------------------------
settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_holy_shield", label = "Holy Shield" },
    { toggle = "prioritize_holy_shield", label = "Prioritize Holy Shield" },
    { toggle = "use_shield_of_righteous", label = "Shield of Righteous" },
    { toggle = "use_judgement", label = "Judgement" },
    { toggle = "use_consecration", label = "Consecration" },
}, {
    namespace = "eaxpaladinprotection",
    log_prefix = "[Eax Paladin Prot] ",
})

local _win
function menu.set_window(win) _win = win end

-- -- RENDER --------------------------------------------------------------------
function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpaladinprotection")
    end

    root_tree:render("Eax's Paladin Protection", function()

        -- 1. General - Visible immediately at top level
        ps.header("General")
        menu.enabled:render("Enabled", "Enable/disable rotation")
        menu.mode:render("Mode", {"Auto", "PvE", "PvP"}, "Rotation mode selection")
        menu.toggle_key:render("Toggle Key", "Keybind to enable/disable")

        -- 2. Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Core Abilities")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_holy_shield:render("Holy Shield", "Maintain Holy Shield buff")
            menu.prioritize_holy_shield:render("Prioritize Holy Shield", "Keep Holy Shield active at all times")
            menu.use_shield_of_righteous:render("Shield of Righteousness", "Main threat ability")
            menu.use_judgement:render("Judgement", "Use on cooldown")
            menu.use_consecration:render("Consecration", "AoE threat")
            menu.consecration_enemy_count:render("Consecration Enemy Count", "Minimum enemies to use Consecration")
            menu.consecration_radius:render("Consecration Radius", "Detection radius for enemies")
            menu.use_hammer_of_wrath:render("Hammer of Wrath", "Execute ability")
            menu.use_avengers_shield:render("Avenger's Shield", "Ranged pull ability")
            menu.use_exorcism:render("Exorcism", "Undead/Demon damage")
            menu.use_righteous_fury:render("Righteous Fury", "Maintain threat buff")

            ps.header("Seals")
            menu.use_seal_of_righteousness:render("Seal of Righteousness", "Single target DPS seal")
            menu.use_seal_of_vengeance:render("Seal of Vengeance", "DoT seal for longer fights")
            menu.use_seal_of_command:render("Seal of Command", "Proc-based seal")
            menu.seal_choice:render("Seal Choice", {"Auto", "Righteousness", "Vengeance", "Command"}, "Preferred seal")
            menu.use_seal_of_wisdom_low_mana:render("Seal of Wisdom (Low Mana)", "Switch to Wisdom seal when mana low")
            menu.seal_of_wisdom_mana_pct:render("SoW Mana %", "Switch to Wisdom below this mana")

            ps.header("Utility")
            menu.use_cleansing:render("Cleansing", "Dispel debuffs")
            menu.use_cleanse:render("Use Cleanse", "Dispel Magic/Poison/Disease debuffs")
            menu.use_hammer_of_justice:render("Hammer of Justice", "Stun on cooldown")
            menu.use_turn_undead:render("Turn Undead", "Fear undead enemies")
            menu.use_holy_wrath:render("Holy Wrath", "AoE undead damage")

            ps.header("Targeting")
            menu.use_auto_tab:render("Auto Tab Targeting", "Auto-switch targets when current dies")
            menu.tab_max_mobs:render("Tab Max Mobs", "Max mobs being tanked before stopping tab")
            menu.no_taunt:render("No Taunt Mode", "Disable all taunts (Righteous Defense)")
            menu.use_righteous_defense:render("Use Righteous Defense", "Enable taunt ability")
            menu.show_notifications:render("Show Notifications", "Display rotation notifications")
        end)

        -- 3. Blessings
        blessings_tree:render("Blessings", function()
            ps.header("Self Blessings")
            menu.use_blessing_of_sanctuary:render("Blessing of Sanctuary", "Damage reduction and mana return")
            menu.use_blessing_of_kings:render("Blessing of Kings", "Stats increase")
            menu.use_blessing_of_might:render("Blessing of Might", "Attack power buff")
            menu.use_blessing_of_wisdom:render("Blessing of Wisdom", "Mana regeneration")
        end)

        -- 4. Defensive
        defensive_tree:render("Defensive", function()
            ps.header("Major Cooldowns")
            menu.use_divine_shield:render("Divine Shield", "Complete immunity (bubble)")
            menu.divine_shield_hp_pct:render("Divine Shield HP %", "Use below this health")
            menu.use_lay_on_hands:render("Lay on Hands", "Emergency full heal")
            menu.lay_on_hands_hp_pct:render("LoH HP %", "Use below this health")
            menu.use_divine_protection:render("Divine Protection", "Physical immunity")
            menu.divine_protection_hp_pct:render("Divine Protection HP %", "Use below this health")
            menu.use_blessing_of_protection:render("Blessing of Protection", "Physical immunity on self")
            menu.blessing_of_protection_hp_pct:render("BoP HP %", "Use below this health")

            ps.header("Avenging Wrath (Burst)")
            menu.use_avenging_wrath:render("Avenging Wrath", "Enable burst cooldown")
            menu.auto_burst_enabled:render("Auto-Burst", "Automatically time Avenging Wrath")
            menu.burst_on_bloodlust:render("Burst on Bloodlust", "Use when Bloodlust/Heroism active")
            menu.burst_on_pull:render("Burst on Pull", "Use within first 5 seconds of combat")
            menu.burst_on_execute:render("Burst on Execute", "Use when target < 20% HP")
            menu.burst_in_combat:render("Burst in Combat", "Use anytime in combat")
            menu.cd_min_ttd:render("Min TTD (seconds)", "Don't burst if target dies sooner than this")

            ps.header("Racial & Aura")
            menu.use_gift_of_the_naaru:render("Gift of the Naaru (Draenei)", "Racial heal over time")
            menu.gift_of_the_naaru_hp_pct:render("Gift of the Naaru HP %", "Use below this health")
            menu.use_devotion_aura:render("Devotion Aura", "Maintain armor aura")
        end)

        -- 5. PvP / Consumables
        pvp_tree:render("PvP / Consumables", function()
            ps.header("Consumables")
            menu.use_healthstone:render("Healthstone", "Auto-use when HP low")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Use below this HP")
            menu.use_health_potion:render("Healing Potion", "Auto-use when HP low")
            menu.health_potion_hp_pct:render("Heal Potion HP %", "Use below this HP")
            menu.use_mana_potion:render("Mana Potion", "Auto-use when mana low")
            menu.mana_potion_pct:render("Mana Potion %", "Use below this mana")

            ps.header("Racials")
            menu.use_berserking:render("Berserking", "Troll haste racial")
            menu.use_stoneform:render("Stoneform", "Dwarf cleanse racial")
            menu.stoneform_hp_pct:render("Stoneform HP %", "Use below this HP")

            ps.header("Trinkets")
            menu.trinket1_mode:render("Trinket 1", {"Off", "Offensive", "Defensive"})
            menu.trinket2_mode:render("Trinket 2", {"Off", "Offensive", "Defensive"})
        end)

        -- 6. Automation
        automation_tree:render("Automation", function()
            ps.header("Combat")
            menu.auto_combat_potions:render("Combat Potions", "Auto-use potions in combat")

            ps.header("Out of Combat")
            menu.auto_ooc_food_drink:render("OOC Food/Drink", "Auto eat/drink when out of combat")
            menu.auto_flask:render("Auto Flask", "Maintain flask buff")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Mana-efficient rotation while leveling")
            menu.leveling_mana_floor:render("Mana Floor %", "Conservation mode threshold")
        end)

        -- 7. OOC Sustain
        ooc_tree:render("OOC Sustain", function()
            ps.header("Sustain")
            menu.ooc_drink:render("Auto-Drink", "Drink to restore mana when out of combat")
            menu.drink_threshold:render("Drink %", "Start drinking below this mana")
            menu.ooc_eat:render("Auto-Eat", "Eat food to restore health when out of combat")
            menu.eat_threshold:render("Eat %", "Start eating below this HP")
        end)

        -- 8. Group
        group_tree:render("Group", function()
            ps.header("Support")
            menu.ooc_rez:render("Auto-Rez", "Accept and cast resurrection when out of combat")
            menu.ooc_group_buff:render("Buffs", "Apply blessings to party members")
            menu.use_redemption:render("Redemption", "Resurrect dead party members")
        end)

        -- 9. Dashboard
        dashboard_tree:render("Dashboard", function()
            menu.dashboard_enabled:render("Enable Dashboard", "Show combat dashboard")
            menu.dashboard_opacity:render("Opacity", "Dashboard background opacity")
            menu.dashboard_x:render("Position X", "Horizontal position")
            menu.dashboard_y:render("Position Y", "Vertical position")
            menu.dashboard_scale:render("Scale", "Dashboard size multiplier")
        end)

        -- 10. Advanced (Targeting + Racial)
        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target")
            menu.combat_self_hp_boost:render("Self HP Boost", "HP threshold adjustment for targeting")

            ps.header("Racial")
            menu.use_racial:render("Use Racial", "Auto-use racial abilities")
            menu.racial_hp:render("Racial HP %", "Use below this HP")
        end)

    end)
end


return menu
