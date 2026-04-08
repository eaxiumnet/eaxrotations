-- +--------------------------------------------------------------------------+
-- |  Eax Druid Bear  -  Menu  -  menu.lua                                    |
-- |                                                                          |
-- |  Guardian/Feral Tank rotation using ps_theme for consistent EAX UI       |
-- +--------------------------------------------------------------------------+

local ps       = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")

local menu = {}

-- -- Tree nodes (declared outside render, as per API requirements) -------------
local root_tree     = ps.tree_node()
local rotation_tree = ps.tree_node()
local bear_tree     = ps.tree_node()
local guardian_tree = ps.tree_node()
local auto_tree     = ps.tree_node()
local ooc_tree      = ps.tree_node()
local group_tree    = ps.tree_node()
local def_tree      = ps.tree_node()
local tgt_tree      = ps.tree_node()
local racial_tree   = ps.tree_node()
local esp_tree      = ps.tree_node()
local middleware_tree = ps.tree_node()
local trinket_tree      = ps.tree_node()
local dashboard_tree    = ps.tree_node()
local pvp_tree        = ps.tree_node()

-- -- Controls ------------------------------------------------------------------
menu.enabled         = core.menu.checkbox(true,  "eaxdruidbear_enabled")
menu.toggle_key      = core.menu.keybind(7, false, "eaxdruidbear_toggle_key")
menu.mode            = core.menu.combobox(1, "eaxdruidbear_mode")
menu.debug           = core.menu.checkbox(false, "eaxdruidbear_debug")

-- -- Targeting ------------------------------------------------------------------
menu.focus_priority        = core.menu.checkbox(false, "eaxdruidbear_focus_priority")
menu.combat_self_hp_boost  = core.menu.slider_int(0, 30, 10, "eaxdruidbear_combat_self_hp_boost")

-- -- Racial --------------------------------------------------------------------
menu.use_racial  = core.menu.checkbox(true, "eaxdruidbear_use_racial")
menu.racial_hp   = core.menu.slider_int(10, 80, 40, "eaxdruidbear_racial_hp")

-- -- Interrupt -----------------------------------------------------------------
menu.use_interrupt = core.menu.checkbox(true, "eaxdruidbear_use_interrupt")

-- -- OOC -----------------------------------------------------------------------
menu.ooc_drink        = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat          = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez          = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff   = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold  = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold    = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- -- Automation ----------------------------------------------------------------
menu.auto_ooc_food_drink = core.menu.checkbox(true, "eaxdruidbear_auto_ooc_food_drink")
menu.auto_flask          = core.menu.checkbox(false, "eaxdruidbear_auto_flask")

-- -- Leveling ------------------------------------------------------------------
menu.leveling_conserve_mana = core.menu.checkbox(true, "eaxdruidbear_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxdruidbear_lev_mana_floor")

-- -- Bear Form -----------------------------------------------------------------
menu.use_mangle_bear        = core.menu.checkbox(true, "eaxdruidbear_use_mangle_bear")
menu.use_lacerate           = core.menu.checkbox(true, "eaxdruidbear_use_lacerate")
menu.use_demoralizing_roar  = core.menu.checkbox(true, "eaxdruidbear_use_demoralizing_roar")
menu.use_swipe              = core.menu.checkbox(true, "eaxdruidbear_use_swipe")
menu.swipe_enemy_count      = core.menu.slider_int(2, 8, 3, "eaxdruidbear_swipe_enemy_count")
menu.use_maul               = core.menu.checkbox(true, "eaxdruidbear_use_maul")
menu.maul_min_rage          = core.menu.slider_int(10, 50, 25, "eaxdruidbear_maul_min_rage")

-- -- Guardian ------------------------------------------------------------------
menu.use_frenzied_regeneration = core.menu.checkbox(true, "eaxdruidbear_use_frenzied_regeneration")
menu.frenzied_regeneration_hp_pct = core.menu.slider_int(10, 50, 25, "eaxdruidbear_frenzied_regeneration_hp_pct")
menu.auto_growl                = core.menu.checkbox(true, "eaxdruidbear_auto_growl")
menu.use_growl                 = core.menu.checkbox(true, "eaxdruidbear_use_growl")
menu.tank_cd_overlap           = core.menu.checkbox(false, "eaxdruidbear_tank_cd_overlap")
menu.use_enrage                = core.menu.checkbox(true, "eaxdruidbear_use_enrage")
menu.enrage_rage_threshold     = core.menu.slider_int(0, 40, 10, "eaxdruidbear_enrage_rage_threshold")
menu.use_challenging_roar      = core.menu.checkbox(true, "eaxdruidbear_use_challenging_roar")
menu.challenging_roar_party_hp_pct = core.menu.slider_int(10, 50, 25, "eaxdruidbear_challenging_roar_party_hp_pct")
menu.use_survival_instincts    = core.menu.checkbox(true, "eaxdruidbear_use_survival_instincts")

-- -- Shared / Utility ----------------------------------------------------------
menu.use_feral_charge       = core.menu.checkbox(true, "eaxdruidbear_use_feral_charge")
menu.use_travel_form        = core.menu.checkbox(true, "eaxdruidbear_use_travel_form")
menu.use_root_escape        = core.menu.checkbox(true, "eaxdruidbear_use_root_escape")
menu.use_bash               = core.menu.checkbox(true, "eaxdruidbear_use_bash")
menu.use_war_stomp          = core.menu.checkbox(true, "eaxdruidbear_use_war_stomp")
menu.war_stomp_hp_pct       = core.menu.slider_int(10, 50, 25, "eaxdruidbear_war_stomp_hp_pct")
menu.war_stomp_attackers    = core.menu.slider_int(2, 6, 3, "eaxdruidbear_war_stomp_attackers")

-- -- Defensive -----------------------------------------------------------------
menu.use_barkskin           = core.menu.checkbox(true, "eaxdruidbear_use_barkskin")
menu.barkskin_hp_pct        = core.menu.slider_int(10, 60, 30, "eaxdruidbear_barkskin_hp_pct")
menu.use_innervate          = core.menu.checkbox(true, "eaxdruidbear_use_innervate")
menu.innervate_mana_pct     = core.menu.slider_int(10, 60, 30, "eaxdruidbear_innervate_mana_pct")
menu.use_abolish_poison     = core.menu.checkbox(true, "eaxdruidbear_use_abolish_poison")
menu.use_remove_curse       = core.menu.checkbox(true, "eaxdruidbear_use_remove_curse")
menu.use_natures_grasp      = core.menu.checkbox(true, "eaxdruidbear_use_natures_grasp")
menu.use_thorns             = core.menu.checkbox(true, "eaxdruidbear_use_thorns")
menu.use_motw               = core.menu.checkbox(true, "eaxdruidbear_use_motw")
menu.use_bear_form          = core.menu.checkbox(true, "eaxdruidbear_use_bear_form")

-- -- Middleware -----------------------------------------------------------------
menu.use_healthstone        = core.menu.checkbox(true, "eaxdruidbear_use_healthstone")
menu.healthstone_hp_pct     = core.menu.slider_int(10, 50, 30, "eaxdruidbear_healthstone_hp_pct")
menu.use_healing_potion     = core.menu.checkbox(true, "eaxdruidbear_use_healing_potion")
menu.healing_potion_hp_pct  = core.menu.slider_int(10, 60, 40, "eaxdruidbear_healing_potion_hp_pct")

-- -- Form Consumables (ported from Flux) ---------------------------------------
menu.use_form_consumables = core.menu.checkbox(true, "eaxdruidbear_use_form_consumables")
menu.use_form_healthstone = core.menu.checkbox(true, "eaxdruidbear_form_healthstone")
menu.form_healthstone_hp_pct = core.menu.slider_int(10, 50, 30, "eaxdruidbear_hs_hp_pct")
menu.use_form_healing_potion = core.menu.checkbox(true, "eaxdruidbear_form_potion")
menu.form_healing_potion_hp_pct = core.menu.slider_int(10, 50, 25, "eaxdruidbear_potion_hp_pct")

-- Defensive trinket mode (3 = defensive)
menu.trinket1_mode = core.menu.combobox(3, "eaxdruidbear_trinket1_mode")
menu.trinket2_mode = core.menu.combobox(3, "eaxdruidbear_trinket2_mode")

-- -- Dashboard ------------------------------------------------------------------
menu.show_dashboard         = core.menu.checkbox(true, "eaxdruidbear_show_dashboard")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxdruidbear_dashboard_opacity")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxdruidbear_dashboard_scale")
menu.dashboard_x            = core.menu.slider_int(0, 2000, 20, "eaxdruidbear_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 2000, 200, "eaxdruidbear_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxdruidbear_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxdruidbear_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxdruidbear_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxdruidbear_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(true, "eaxdruidbear_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxdruidbear_enable_smart_collapse")

-- -- PvP Settings ------------------------------------------------------------
menu.pvp_enabled            = core.menu.checkbox(true, "eaxdruidbear_pvp_enabled")
menu.pvp_mode               = core.menu.combobox(1, "eaxdruidbear_pvp_mode")
menu.pvp_use_trinket        = core.menu.checkbox(true, "eaxdruidbear_pvp_trinket")
menu.pvp_defensive_threshold = core.menu.slider_int(10, 80, 40, "eaxdruidbear_pvp_def_hp")

-- -- Window --------------------------------------------------------------------
settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_mangle_bear", label = "Mangle (Bear)" },
    { toggle = "use_lacerate", label = "Lacerate" },
    { toggle = "use_frenzied_regeneration", label = "Frenzied Regen" },
    { toggle = "use_survival_instincts", label = "Survival Instincts" },
}, {
    namespace = "eaxdruidbear",
    log_prefix = "[Eax Bear] ",
})

local _win
function menu.set_window(win) _win = win end

-- -- RENDER --------------------------------------------------------------------
function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxdruidbear")
    end

    root_tree:render("Eax's Druid Bear", function()

        ps.render_controls(menu, "Eax's Druid Bear")

        -- Bear Form
        bear_tree:render("Bear Form", function()
            ps.header("Threat")
            menu.use_mangle_bear:render("Mangle (Bear)", "Main threat ability")
            menu.use_lacerate:render("Lacerate", "Maintain Lacerate stacks")
            menu.use_demoralizing_roar:render("Demoralizing Roar", "Attack power reduction")
            menu.use_swipe:render("Swipe", "AoE threat")
            menu.swipe_enemy_count:render("Swipe Enemy Count", "Use Swipe above this enemy count")
            menu.use_maul:render("Maul", "Rage dump")
            menu.maul_min_rage:render("Maul Min Rage", "Minimum rage to use Maul")
        end)

        -- Guardian
        guardian_tree:render("Guardian", function()
            ps.header("Defensive")
            menu.use_frenzied_regeneration:render("Frenzied Regen", "Self-heal cooldown")
            menu.frenzied_regeneration_hp_pct:render("Frenzied Regen HP %", "Use below this health percent")
            menu.auto_growl:render("Auto Growl", "Auto-taunt when losing threat")
            menu.use_growl:render("Use Growl", "Enable Growl usage")
            menu.tank_cd_overlap:render("Allow CD Overlap", "Allow defensive cooldowns to overlap")
            menu.use_enrage:render("Enrage", "Rage generation cooldown")
            menu.enrage_rage_threshold:render("Enrage Rage Threshold", "Use Enrage below this rage")
            menu.use_challenging_roar:render("Challenging Roar", "AoE taunt")
            menu.challenging_roar_party_hp_pct:render("Challenging Roar Party HP %", "Use when party members below this HP")
            menu.use_survival_instincts:render("Survival Instincts", "Max health increase")
        end)

        -- Shared / Utility
        rotation_tree:render("Utility", function()
            ps.header("Mobility")
            menu.use_feral_charge:render("Feral Charge", "Gap closer")
            menu.use_travel_form:render("Travel Form OOC", "Use Travel Form when out of combat")
            menu.use_root_escape:render("Root Escape", "Shift to break roots")

            ps.header("CC")
            menu.use_bash:render("Bash", "Bear stun")
            menu.use_war_stomp:render("War Stomp (Tauren)", "Racial stun")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.war_stomp_hp_pct:render("War Stomp HP %", "Use below this HP")
            menu.war_stomp_attackers:render("War Stomp Attacker Count", "Use above this attacker count")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_barkskin:render("Barkskin", "Damage reduction cooldown")
            menu.barkskin_hp_pct:render("Barkskin HP %", "Use below this health percent")
            menu.use_innervate:render("Innervate", "Mana recovery")
            menu.innervate_mana_pct:render("Innervate Mana %", "Use below this mana percent")
            menu.use_abolish_poison:render("Abolish Poison", "Dispel poison")
            menu.use_remove_curse:render("Remove Curse", "Dispel curse")
            menu.use_natures_grasp:render("Nature's Grasp", "Root on melee hit")
            menu.use_thorns:render("Thorns", "Auto-apply Thorns when missing (OOC)")
            menu.use_motw:render("Mark of the Wild", "Auto-apply MOTW when missing (OOC)")
        end)

        -- Middleware
        middleware_tree:render("Middleware / Consumables", function()
            ps.header("Healthstone")
            menu.use_healthstone:render("Use Healthstone", "Auto-use healthstone when HP low (off-GCD)")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Use healthstone below this HP")
            
            ps.header("Healing Potion")
            menu.use_healing_potion:render("Use Healing Potion", "Auto-use healing potion when HP low (off-GCD)")
            menu.healing_potion_hp_pct:render("Potion HP %", "Use potion below this HP")

            ps.header("Form Consumables")
            menu.use_form_consumables:render("Use Form Consumables", "Auto-use consumables in Bear form")
            menu.use_form_healthstone:render("Use Healthstone", "Use healthstone when low HP")
            menu.form_healthstone_hp_pct:render("Healthstone HP%", "HP threshold")
            menu.use_form_healing_potion:render("Use Healing Potion", "Use potion when low HP")
            menu.form_healing_potion_hp_pct:render("Potion HP%", "HP threshold")
        end)

        -- Trinkets
        trinket_tree:render("Trinkets", function()
            ps.header("Trinket Modes")
            menu.trinket1_mode:render("Trinket 1 Mode", {"Off", "Offensive", "Defensive"}, "Mode for top trinket slot")
            menu.trinket2_mode:render("Trinket 2 Mode", {"Off", "Offensive", "Defensive"}, "Mode for bottom trinket slot")
        end)

        -- Dashboard
        dashboard_tree:render("Dashboard", function()
            ps.header("Display")
            menu.show_dashboard:render("Show Dashboard", "Enable combat dashboard")
            menu.dashboard_opacity:render("Opacity", "Dashboard background opacity")
            menu.dashboard_scale:render("Scale", "Dashboard UI scale")
            menu.dashboard_x:render("Position X", "Dashboard horizontal position")
            menu.dashboard_y:render("Position Y", "Dashboard vertical position")            
            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent spell casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")            menu.show_threat_bar:render("Threat Bar", "Show threat percentage")
        end)

        -- PvP Settings
        pvp_tree:render("PvP", function()
            menu.pvp_enabled:render("Enable PvP", "Enable PvP rotation features")
            menu.pvp_mode:render("PvP Mode", {"Auto", "PvE Only", "PvP Only"}, "Select PvP detection mode")
            menu.pvp_use_trinket:render("Use PvP Trinket", "Auto-use PvP trinket when CC'd")
            menu.pvp_defensive_threshold:render("Defensive Threshold %", "Use defensives below this HP% in PvP")
        end)

        -- Targeting
        ps.render_targeting(menu, tgt_tree)

        -- Racial
        ps.render_racial(menu, racial_tree)

        -- Out-of-combat
        ooc_tree:render("Out of Combat", function()
            ps.header("Sustain")
            menu.ooc_drink:render("Auto-Drink", "Drink to restore mana when out of combat")
            menu.drink_threshold:render("Drink Threshold %", "Start drinking below this mana percent")
            menu.ooc_eat:render("Auto-Eat", "Eat food to restore health when out of combat")
            menu.eat_threshold:render("Eat Threshold %", "Start eating below this health percent")

            ps.header("Group")
            menu.ooc_rez:render("Auto-Resurrect", "Accept and cast resurrection when out of combat")
            menu.ooc_group_buff:render("Group Buffs", "Apply class buffs to party members between pulls")

            ps.header("Automation")
            menu.auto_ooc_food_drink:render("Auto OOC Food / Drink", "Use food and drink out of combat when health or mana is low")
            menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Use a more mana-efficient leveling rotation")
            menu.leveling_mana_floor:render("Mana Floor %", "Switch to conservation mode below this mana percent")
        end)

    end)
end

return menu


