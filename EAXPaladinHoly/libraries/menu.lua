-- +------------------------------------------------------------------+
-- |  Eax's Paladin Holy
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree    = ps.tree_node()
local rotation_tree = ps.tree_node()
local healing_tree = ps.tree_node()
local cd_tree      = ps.tree_node()
local auto_tree    = ps.tree_node()
local ooc_tree     = ps.tree_node()
local group_tree   = ps.tree_node()
local def_tree     = ps.tree_node()
local dashboard_tree = ps.tree_node()
local advanced_tree = ps.tree_node()

settings.init({
    spec_name = "eaxpaladinholy",
    class_name = "Paladin",
    role = "healer",
})

-- Tree nodes defined at module load time (NOT inside render function)
local trinket_tree = ps.tree_node()
local pvp_tree = ps.tree_node()

-- Settings tree references (using existing tree nodes)
local settings_tree = {
    targeting = rotation_tree,
    racial = def_tree,
    ooc = ooc_tree,
    display = dashboard_tree,
}

-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxpaladinholy_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpaladinholy_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpaladinholy_mode")

-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpaladinholy_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpaladinholy_combat_self_hp_boost")

-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpaladinholy_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpaladinholy_racial_hp")

-- Interrupt
menu.use_interrupt                       = core.menu.checkbox(true, "eaxpaladinholy_use_interrupt")

-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- Automation
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxpaladinholy_auto_combat_potions")
menu.auto_mana_potion = menu.auto_combat_potions  -- Alias for compatibility
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpaladinholy_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpaladinholy_auto_flask")
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpaladinholy_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpaladinholy_lev_mana_floor")

-- Healing
menu.use_holy_light                      = core.menu.checkbox(true, "eaxpaladinholy_use_holy_light")
menu.holy_light_hp_pct                   = core.menu.slider_int(10, 100, 60, "eaxpaladinholy_holy_light_hp_pct")
menu.use_flash_of_light                  = core.menu.checkbox(true, "eaxpaladinholy_use_flash_of_light")
menu.flash_of_light_hp_pct               = core.menu.slider_int(10, 100, 80, "eaxpaladinholy_flash_of_light_hp_pct")
menu.use_holy_shock                      = core.menu.checkbox(true, "eaxpaladinholy_use_holy_shock")
menu.holy_shock_hp_pct                   = core.menu.slider_int(10, 100, 70, "eaxpaladinholy_holy_shock_hp_pct")
menu.use_divine_illumination             = core.menu.checkbox(true, "eaxpaladinholy_use_divine_illumination")
menu.use_cleanse                         = core.menu.checkbox(true, "eaxpaladinholy_use_cleanse")
menu.use_cleanse_party                   = core.menu.checkbox(true, "eaxpaladinholy_use_cleanse_party")
menu.use_lay_on_hands                    = core.menu.checkbox(true, "eaxpaladinholy_use_lay_on_hands")
menu.lay_on_hands_hp_pct                 = core.menu.slider_int(5, 50, 20, "eaxpaladinholy_lay_on_hands_hp_pct")
menu.use_divine_favor                    = core.menu.checkbox(true, "eaxpaladinholy_use_divine_favor")
menu.use_divine_shield                   = core.menu.checkbox(true, "eaxpaladinholy_use_divine_shield")
menu.divine_shield_hp_pct                = core.menu.slider_int(0, 100, 20, "eaxpaladinholy_divine_shield_hp_pct")
menu.use_divine_protection               = core.menu.checkbox(true, "eaxpaladinholy_use_divine_protection")
menu.divine_protection_hp_pct            = core.menu.slider_int(0, 100, 30, "eaxpaladinholy_divine_protection_hp_pct")
menu.use_blessing_of_light               = core.menu.checkbox(true, "eaxpaladinholy_use_blessing_of_light")
menu.use_blessing_of_wisdom              = core.menu.checkbox(true, "eaxpaladinholy_use_blessing_of_wisdom")
menu.use_blessing_of_might               = core.menu.checkbox(true, "eaxpaladinholy_use_blessing_of_might")
menu.use_blessing_of_kings               = core.menu.checkbox(true, "eaxpaladinholy_use_blessing_of_kings")
menu.use_righteous_fury                  = core.menu.checkbox(false, "eaxpaladinholy_use_righteous_fury")
menu.use_devotion_aura                   = core.menu.checkbox(true, "eaxpaladinholy_use_devotion_aura")
menu.use_seal_of_light                   = core.menu.checkbox(true, "eaxpaladinholy_use_seal_of_light")
menu.use_seal_of_wisdom                  = core.menu.checkbox(true, "eaxpaladinholy_use_seal_of_wisdom")
menu.use_seal_of_righteousness           = core.menu.checkbox(true, "eaxpaladinholy_use_seal_of_righteousness")
menu.use_judgement                       = core.menu.checkbox(true, "eaxpaladinholy_use_judgement")
menu.use_consecration                    = core.menu.checkbox(true, "eaxpaladinholy_use_consecration")
menu.use_exorcism                        = core.menu.checkbox(true, "eaxpaladinholy_use_exorcism")
menu.use_holy_wrath                      = core.menu.checkbox(true, "eaxpaladinholy_use_holy_wrath")
menu.use_turn_undead                     = core.menu.checkbox(true, "eaxpaladinholy_use_turn_undead")
menu.use_redemption                      = core.menu.checkbox(true, "eaxpaladinholy_use_redemption")
menu.seal_choice = core.menu.combobox(1, "eaxpaladinholy_seal_choice")
menu.use_avenging_wrath = core.menu.checkbox(true, "eaxpaladinholy_use_avenging_wrath")

-- Burst / Avenging Wrath configuration
menu.auto_burst_enabled                  = core.menu.checkbox(false, "eaxpaladinholy_auto_burst_enabled")
menu.burst_on_bloodlust                  = core.menu.checkbox(true, "eaxpaladinholy_burst_on_bloodlust")
menu.burst_on_pull                       = core.menu.checkbox(true, "eaxpaladinholy_burst_on_pull")
menu.burst_on_execute                    = core.menu.checkbox(false, "eaxpaladinholy_burst_on_execute")
menu.burst_in_combat                     = core.menu.checkbox(false, "eaxpaladinholy_burst_in_combat")
menu.cd_min_ttd                          = core.menu.slider_int(0, 60, 10, "eaxpaladinholy_cd_min_ttd")

menu.divine_illumination_pct = menu.divine_illumination_mana_pct  -- Alias for compatibility

-- Missing toggles (12 total)
-- Judgement Maintenance (1)
menu.maintain_judgement                  = core.menu.checkbox(true, "eaxpaladinholy_maintain_judgement")

-- Auto Blessings (1)
menu.auto_blessings                      = core.menu.checkbox(true, "eaxpaladinholy_auto_blessings")

-- Cooldowns (2) - divine_illumination already defined above
menu.divine_illumination_mana_pct        = core.menu.slider_int(10, 80, 50, "eaxpaladinholy_divine_illumination_mana_pct")

-- Target Selection (1)
menu.heal_target_priority                = core.menu.combobox(1, "eaxpaladinholy_heal_target_priority")

-- HP Thresholds (5) - bop_hp_pct is new
menu.bop_hp_pct                          = core.menu.slider_int(5, 50, 30, "eaxpaladinholy_bop_hp_pct")

-- Utility (2)
menu.use_bop_on_tank                     = core.menu.checkbox(false, "eaxpaladinholy_use_bop_on_tank")
menu.use_cleanse_key = core.menu.keybind(7, false, "eaxpaladinholy_cleanse_key")
menu.use_hand_of_freedom_key = core.menu.keybind(7, false, "eaxpaladinholy_hand_of_freedom_key")
menu.overheal_protection = core.menu.checkbox(false, "eaxpaladinholy_overheal_protection")

-- Trinket mode definitions (moved here from below)
menu.trinket1_mode                       = core.menu.combobox(1, "eaxpaladinholy_trinket1_mode")
menu.trinket2_mode                       = core.menu.combobox(1, "eaxpaladinholy_trinket2_mode")

-- PvP / Consumables
menu.use_healthstone        = core.menu.checkbox(true, "eaxpaladinholy_use_healthstone")
menu.healthstone_hp_pct     = core.menu.slider_int(5, 50, 30, "eaxpaladinholy_healthstone_hp_pct")
menu.use_health_potion      = core.menu.checkbox(true, "eaxpaladinholy_use_health_potion")
menu.health_potion_hp_pct   = core.menu.slider_int(5, 50, 40, "eaxpaladinholy_health_potion_hp_pct")
menu.use_mana_potion        = core.menu.checkbox(true, "eaxpaladinholy_use_mana_potion")
menu.mana_potion_pct        = core.menu.slider_int(5, 50, 15, "eaxpaladinholy_mana_potion_pct")

-- Dashboard menu items
menu.dashboard_enabled      = core.menu.checkbox(true, "eaxpaladinholy_dashboard_enabled")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxpaladinholy_dashboard_opacity")
menu.dashboard_x            = core.menu.slider_int(0, 1000, 20, "eaxpaladinholy_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 1000, 200, "eaxpaladinholy_dashboard_y")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxpaladinholy_dashboard_scale")

-- PvP Racials
menu.use_berserking                      = core.menu.checkbox(true, "eaxpaladinholy_use_berserking")
menu.use_stoneform                       = core.menu.checkbox(true, "eaxpaladinholy_use_stoneform")
menu.stoneform_hp_pct                    = core.menu.slider_int(10, 80, 40, "eaxpaladinholy_stoneform_hp_pct")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_holy_light", label = "Holy Light" },
    { toggle = "use_flash_of_light", label = "Flash of Light" },
    { toggle = "use_holy_shock", label = "Holy Shock" },
    { toggle = "use_divine_illumination", label = "Divine Illumination" },
}, {
    namespace = "eaxpaladinholy",
    log_prefix = "[Eax Paladin Holy] ",
})

local _win

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpaladinholy")
    end

    root_tree:render("Eax's Paladin Holy", function()
        -- General
        ps.header("General")
        menu.enabled:render("Enabled", "Enable rotation")
        menu.toggle_key:render("Toggle Key", "Rotation on/off")
        menu.mode:render("Mode", "Auto/PvE/PvP")

        -- Healing
        healing_tree:render("Healing", function()
            ps.header("Target Priority")
            menu.heal_target_priority:render("Heal Target Priority", "Selection")
            ps.header("Direct Heals")
            menu.use_holy_light:render("Holy Light", "Main heal")
            menu.holy_light_hp_pct:render("Holy Light HP %", "Below")
            menu.use_flash_of_light:render("Flash of Light", "Fast heal")
            menu.flash_of_light_hp_pct:render("FoL HP %", "Below")
            menu.use_holy_shock:render("Holy Shock", "Instant heal")
            menu.holy_shock_hp_pct:render("Holy Shock HP %", "Below")
            menu.use_divine_illumination:render("Divine Illumination", "CD reduction")
            menu.divine_illumination_mana_pct:render("Divine Illumination Mana %", "Below")
            menu.use_cleanse:render("Cleansing", "Dispel")
            menu.use_cleanse_party:render("Cleanse Party", "Dispel party members")
            menu.use_lay_on_hands:render("Lay on Hands", "Emergency")
            menu.lay_on_hands_hp_pct:render("LoH HP %", "Below")
            menu.use_divine_favor:render("Divine Favor", "Guaranteed crit")
            ps.header("Avenging Wrath (Burst)")
            menu.use_avenging_wrath:render("Avenging Wrath", "Enable burst cooldown")
            menu.auto_burst_enabled:render("Auto-Burst", "Automatically time Avenging Wrath")
            menu.burst_on_bloodlust:render("Burst on Bloodlust", "Use when Bloodlust/Heroism active")
            menu.burst_on_pull:render("Burst on Pull", "Use within first 5 seconds of combat")
            menu.burst_on_execute:render("Burst on Execute", "Use when target < 20% HP")
            menu.burst_in_combat:render("Burst in Combat", "Use anytime in combat")
            menu.cd_min_ttd:render("Min TTD (seconds)", "Don't burst if target dies sooner than this")
        end)

        -- DPS Fallback
        rotation_tree:render("DPS Fallback", function()
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_seal_of_light:render("Seal of Light", "Heal on hit")
            menu.use_seal_of_wisdom:render("Seal of Wisdom", "Mana on hit")
            menu.use_seal_of_righteousness:render("Seal of Righteousness", "DPS")
            menu.use_judgement:render("Judgement", "On CD")
            menu.maintain_judgement:render("Maintain Judgement", "Keep active")
            menu.use_consecration:render("Consecration", "AoE")
            menu.use_exorcism:render("Exorcism", "Undead/Demon")
            menu.use_holy_wrath:render("Holy Wrath", "AoE undead")
            menu.use_turn_undead:render("Turn Undead", "CC")
        end)

        -- Blessings
        cd_tree:render("Blessings", function()
            menu.auto_blessings:render("Auto Blessings", "Auto-cast")
            ps.header("Blessing Selection")
            menu.use_blessing_of_light:render("BoL", "Heal boost")
            menu.use_blessing_of_wisdom:render("BoW", "Mana regen")
            menu.use_blessing_of_might:render("BoM", "AP buff")
            menu.use_blessing_of_kings:render("BoK", "Stats buff")
            ps.header("Auras & Threat")
            menu.use_devotion_aura:render("Devotion Aura", "Armor aura")
            menu.use_righteous_fury:render("Righteous Fury", "Threat (healer: off)")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_divine_protection:render("Divine Protection", "-50% physical")
            menu.divine_protection_hp_pct:render("Divine Protection HP %", "Below")
            menu.use_divine_shield:render("Divine Shield", "Immunity")
            menu.divine_shield_hp_pct:render("Divine Shield HP %", "Below")
            ps.header("Blessing of Protection")
            menu.use_bop_on_tank:render("BoP on Tank", "Allow tank BoP")
            menu.bop_hp_pct:render("BoP HP %", "Below")
        end)

        -- Dashboard
        dashboard_tree:render("Dashboard", function()
            menu.dashboard_enabled:render("Enable Dashboard", "Show combat dashboard")
            menu.dashboard_opacity:render("Opacity", "Dashboard background opacity")
            menu.dashboard_x:render("Position X", "Horizontal position")
            menu.dashboard_y:render("Position Y", "Vertical position")
            menu.dashboard_scale:render("Scale", "Dashboard size multiplier")
        end)

        -- Advanced (Targeting, Racial, Leveling)
        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target")
            menu.combat_self_hp_boost:render("Self HP Boost", "Self-heal HP threshold")
            ps.header("Racial Abilities")
            menu.use_racial:render("Use Racial", "Enable racial abilities")
            menu.racial_hp:render("Racial HP %", "HP threshold for racials")
            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling mode")
            menu.leveling_mana_floor:render("Mana Floor %", "Minimum mana %")
        end)
    end)
end


return menu
