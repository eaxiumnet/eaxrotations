-- +--------------------------------------------------------------------------+
-- |  EAX Priest Smite  -  Menu  -  menu.lua                                  |
-- |                                                                          |
-- |  Holy DPS rotation using ps_theme for consistent EAX UI                  |
-- +--------------------------------------------------------------------------+

local ps       = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")

local menu = {}

-- -- Tree nodes (declared outside render, as per API requirements) -------------
local root_tree       = ps.tree_node()
local rotation_tree   = ps.tree_node()
local smite_tree      = ps.tree_node()
local healing_tree    = ps.tree_node()
local cooldowns_tree  = ps.tree_node()
local buffs_tree      = ps.tree_node()
local racial_tree     = ps.tree_node()
local ooc_tree        = ps.tree_node()
local tgt_tree        = ps.tree_node()
local middleware_tree = ps.tree_node()
local dashboard_tree  = ps.tree_node()

-- -- Controls ------------------------------------------------------------------
menu.enabled         = core.menu.checkbox(true,  "eaxpriestsmite_enabled")
menu.toggle_key      = core.menu.keybind(7, false, "eaxpriestsmite_toggle_key")
menu.mode            = core.menu.combobox(1, "eaxpriestsmite_mode")
menu.debug           = core.menu.checkbox(false, "eaxpriestsmite_debug")

-- -- Targeting ------------------------------------------------------------------
menu.focus_priority        = core.menu.checkbox(false, "eaxpriestsmite_focus_priority")

-- -- Racial --------------------------------------------------------------------
menu.use_racial  = core.menu.checkbox(true, "eaxpriestsmite_use_racial")
menu.racial_hp   = core.menu.slider_int(10, 80, 40, "eaxpriestsmite_racial_hp")

-- -- Interrupt -----------------------------------------------------------------
menu.use_interrupt = core.menu.checkbox(true, "eaxpriestsmite_use_interrupt")

-- -- OOC -----------------------------------------------------------------------
menu.ooc_drink        = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat          = core.menu.checkbox(true,  "eax_ooc_eat")
menu.drink_threshold  = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold    = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- -- DPS/Healing Balance -------------------------------------------------------
menu.dps_heal_balance    = core.menu.slider_int(0, 100, 80, "eaxpriestsmite_dps_heal_balance")
menu.self_heal_threshold   = core.menu.slider_int(10, 50, 30, "eaxpriestsmite_self_heal_threshold")

-- -- Smite Rotation ------------------------------------------------------------
menu.use_smite               = core.menu.checkbox(true, "eaxpriestsmite_use_smite")
menu.use_holy_fire           = core.menu.checkbox(true, "eaxpriestsmite_use_holy_fire")
menu.use_mind_blast          = core.menu.checkbox(false, "eaxpriestsmite_use_mind_blast")
menu.use_shadow_word_pain    = core.menu.checkbox(true, "eaxpriestsmite_use_shadow_word_pain")
menu.use_shadow_word_death   = core.menu.checkbox(true, "eaxpriestsmite_use_shadow_word_death")
menu.swd_hp_threshold        = core.menu.slider_int(10, 50, 40, "eaxpriestsmite_swd_hp_threshold")
menu.use_starshards          = core.menu.checkbox(true, "eaxpriestsmite_use_starshards")

-- -- Cooldowns -----------------------------------------------------------------
menu.use_inner_focus   = core.menu.checkbox(true, "eaxpriestsmite_use_inner_focus")
menu.use_power_infusion = core.menu.checkbox(true, "eaxpriestsmite_use_power_infusion")
menu.use_shadowfiend   = core.menu.checkbox(true, "eaxpriestsmite_use_shadowfiend")
menu.cd_min_ttd        = core.menu.slider_int(0, 60, 0, "eaxpriestsmite_cd_min_ttd")

-- -- Burst & Trinkets ----------------------------------------------------------
menu.auto_burst_enabled = core.menu.checkbox(true, "eaxpriestsmite_auto_burst")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eaxpriestsmite_burst_bloodlust")
menu.burst_on_pull      = core.menu.checkbox(true, "eaxpriestsmite_burst_pull")
menu.burst_on_execute   = core.menu.checkbox(true, "eaxpriestsmite_burst_execute")
menu.burst_in_combat    = core.menu.checkbox(false, "eaxpriestsmite_burst_combat")
menu.trinket1_mode      = core.menu.combobox(1, "eaxpriestsmite_trinket1")
menu.trinket2_mode      = core.menu.combobox(1, "eaxpriestsmite_trinket2")

-- -- Healing (Hybrid Mode) ----------------------------------------------------
menu.use_flash_heal        = core.menu.checkbox(true, "eaxpriestsmite_use_flash_heal")
menu.use_renew             = core.menu.checkbox(true, "eaxpriestsmite_use_renew")
menu.use_power_word_shield = core.menu.checkbox(true, "eaxpriestsmite_use_power_word_shield")
menu.use_binding_heal      = core.menu.checkbox(true, "eaxpriestsmite_use_binding_heal")

-- -- Buffs ---------------------------------------------------------------------
menu.use_inner_fire  = core.menu.checkbox(true, "eaxpriestsmite_use_inner_fire")
menu.use_fear_ward   = core.menu.checkbox(true, "eaxpriestsmite_use_fear_ward")
menu.use_fortitude   = core.menu.checkbox(true, "eaxpriestsmite_use_fortitude")
menu.use_divine_spirit = core.menu.checkbox(true, "eaxpriestsmite_use_divine_spirit")
menu.use_shadow_protection = core.menu.checkbox(true, "eaxpriestsmite_use_shadow_protection")
menu.use_resurrection = core.menu.checkbox(true, "eaxpriestsmite_use_rez")

-- -- Middleware -----------------------------------------------------------------
menu.use_healthstone        = core.menu.checkbox(true, "eaxpriestsmite_use_healthstone")
menu.healthstone_hp_pct     = core.menu.slider_int(10, 50, 30, "eaxpriestsmite_healthstone_hp_pct")
menu.use_healing_potion     = core.menu.checkbox(true, "eaxpriestsmite_use_healing_potion")
menu.healing_potion_hp_pct  = core.menu.slider_int(10, 60, 40, "eaxpriestsmite_healing_potion_hp_pct")

-- -- Dashboard ------------------------------------------------------------------
menu.show_dashboard         = core.menu.checkbox(true, "eaxpriestsmite_show_dashboard")
menu.dashboard_opacity      = core.menu.slider_int(50, 255, 190, "eaxpriestsmite_dashboard_opacity")
menu.dashboard_scale        = core.menu.slider_float(0.5, 2.0, 1.0, "eaxpriestsmite_dashboard_scale")
menu.dashboard_x            = core.menu.slider_int(0, 2000, 20, "eaxpriestsmite_dashboard_x")
menu.dashboard_y            = core.menu.slider_int(0, 2000, 200, "eaxpriestsmite_dashboard_y")
menu.show_timer_bars = core.menu.checkbox(true, "eaxpriestsmite_show_timer_bars")
menu.show_action_history = core.menu.checkbox(true, "eaxpriestsmite_show_action_history")
menu.show_energy_tick = core.menu.checkbox(false, "eaxpriestsmite_show_energy_tick")
menu.show_combo_points = core.menu.checkbox(false, "eaxpriestsmite_show_combo_points")
menu.show_threat_bar = core.menu.checkbox(false, "eaxpriestsmite_show_threat_bar")
menu.enable_smart_collapse = core.menu.checkbox(true, "eaxpriestsmite_enable_smart_collapse")

-- -- Window --------------------------------------------------------------------
settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_smite", label = "Smite" },
    { toggle = "use_holy_fire", label = "Holy Fire" },
    { toggle = "use_inner_focus", label = "Inner Focus" },
    { toggle = "use_power_infusion", label = "Power Infusion" },
}, {
    namespace = "eaxpriestsmite",
    log_prefix = "[EAX Priest Smite] ",
})

local _win
function menu.set_window(win) _win = win end

-- -- RENDER --------------------------------------------------------------------
function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpriestsmite")
    end

    root_tree:render("EAX Priest Smite", function()

        ps.render_controls(menu, "EAX Priest Smite")

        -- Smite Rotation
        smite_tree:render("Smite Rotation", function()
            ps.header("Core Damage")
            menu.use_smite:render("Smite", "Primary holy damage spell")
            menu.use_holy_fire:render("Holy Fire", "DoT + burst damage")
            menu.use_shadow_word_pain:render("Shadow Word: Pain", "Maintain DoT on target")
            menu.use_shadow_word_death:render("Shadow Word: Death", "Execute damage")
            menu.swd_hp_threshold:render("SW:D HP Threshold", "Target HP% to use Shadow Word: Death")

            ps.header("Shadow Hybrid")
            menu.use_mind_blast:render("Mind Blast", "Shadow damage (hybrid mode)")
            menu.use_starshards:render("Starshards (Night Elf)", "Racial damage ability")
        end)

        -- Cooldowns
        cooldowns_tree:render("Cooldowns", function()
            ps.header("Offensive")
            menu.use_inner_focus:render("Inner Focus", "Free, instant cast")
            menu.use_power_infusion:render("Power Infusion", "Haste buff (self or ally)")
            menu.use_shadowfiend:render("Shadowfiend", "Mana regeneration pet")
            menu.cd_min_ttd:render("Min TTD for CDs", "Don't burst if target dies sooner (sec)")

            ps.header("Auto Burst")
            menu.auto_burst_enabled:render("Enable Auto Burst", "Automatically use burst cooldowns")
            menu.burst_on_bloodlust:render("Burst on Bloodlust", "Use CDs when Bloodlust/Heroism active")
            menu.burst_on_pull:render("Burst on Pull", "Use CDs in first 5 seconds of combat")
            menu.burst_on_execute:render("Burst on Execute", "Use CDs when target <20% HP")
            menu.burst_in_combat:render("Burst in Combat", "Use CDs anytime in combat")

            ps.header("Trinkets")
            menu.trinket1_mode:render("Trinket 1 Mode", "Off/Offensive/Defensive")
            menu.trinket2_mode:render("Trinket 2 Mode", "Off/Offensive/Defensive")
        end)

        -- Healing (Hybrid Mode)
        healing_tree:render("Healing (Hybrid)", function()
            ps.header("Self Healing")
            menu.dps_heal_balance:render("DPS/Heal Balance", "0=Full DPS, 100=Full Heal")
            menu.self_heal_threshold:render("Self Heal Threshold", "HP% to prioritize self-healing")

            ps.header("Healing Spells")
            menu.use_flash_heal:render("Flash Heal", "Quick single-target heal")
            menu.use_renew:render("Renew", "HoT for sustained healing")
            menu.use_power_word_shield:render("Power Word: Shield", "Absorption shield")
            menu.use_binding_heal:render("Binding Heal", "Heal self and target")
        end)

        -- Buffs
        buffs_tree:render("Buffs", function()
            ps.header("Self Buffs")
            menu.use_inner_fire:render("Inner Fire", "Armor and spell power buff")
            menu.use_fear_ward:render("Fear Ward", "Fear immunity buff")
            menu.use_shadow_protection:render("Shadow Protection", "Auto-apply Shadow Protection when missing")
        end)

        -- Middleware
        middleware_tree:render("Middleware / Consumables", function()
            ps.header("Healthstone")
            menu.use_healthstone:render("Use Healthstone", "Auto-use healthstone when HP low (off-GCD)")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Use healthstone below this HP")
            
            ps.header("Healing Potion")
            menu.use_healing_potion:render("Use Healing Potion", "Auto-use healing potion when HP low (off-GCD)")
            menu.healing_potion_hp_pct:render("Potion HP %", "Use potion below this HP")
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
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
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
        end)

    end)
end

return menu


