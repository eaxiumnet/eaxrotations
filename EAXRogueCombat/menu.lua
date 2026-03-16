-- EAX Rogue Combat | menu.lua

local menu = {}

local tree = core.menu.tree_node()
local finishers_tree = core.menu.tree_node()
local cooldowns_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eaxroguecombat_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eaxroguecombat_toggle_key")
menu.mode = core.menu.combobox(1, "eaxroguecombat_mode")
menu.debug = core.menu.checkbox(false, "eaxroguecombat_debug")

menu.use_sinister_strike = core.menu.checkbox(true, "eaxroguecombat_use_sinister_strike")
menu.use_slice_and_dice = core.menu.checkbox(true, "eaxroguecombat_use_slice_and_dice")
menu.use_rupture = core.menu.checkbox(true, "eaxroguecombat_use_rupture")
menu.use_eviscerate = core.menu.checkbox(true, "eaxroguecombat_use_eviscerate")
menu.use_kick = core.menu.checkbox(true, "eaxroguecombat_use_kick")
menu.use_blade_flurry = core.menu.checkbox(true, "eaxroguecombat_use_blade_flurry")
menu.use_adrenaline_rush = core.menu.checkbox(true, "eaxroguecombat_use_adrenaline_rush")

menu.use_evasion = core.menu.checkbox(true, "eaxroguecombat_use_evasion")
menu.evasion_hp_pct = core.menu.slider_int(0, 100, 35, "eaxroguecombat_evasion_hp_pct")

menu.snd_refresh_seconds = core.menu.slider_int(1, 6, 3, "eaxroguecombat_snd_refresh_seconds")
menu.finish_combo_points = core.menu.slider_int(3, 5, 4, "eaxroguecombat_finish_combo_points")
menu.aoe_enemy_count = core.menu.slider_int(2, 5, 2, "eaxroguecombat_aoe_enemy_count")

function menu.render()
    tree:render("EAX Rogue Combat", function()
        menu.enabled:render("Enabled", "Master toggle")
        menu.toggle_key:render("Toggle Key", "Toggle the plugin on or off")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" }, "Auto uses party detection")
        menu.debug:render("Debug Logging", "Print rotation decisions")

        menu.use_sinister_strike:render("Sinister Strike", "Primary combo-point builder")
        menu.use_slice_and_dice:render("Slice and Dice", "Maintain Slice and Dice as the top finisher priority")
        menu.use_kick:render("Kick", "Interrupt enemy casts")

        finishers_tree:render("Finishers", function()
            menu.use_rupture:render("Rupture", "Use Rupture on sustained targets")
            menu.use_eviscerate:render("Eviscerate", "Fallback damage finisher")
            menu.snd_refresh_seconds:render("SnD Refresh", "Refresh Slice and Dice below this many seconds")
            menu.finish_combo_points:render("Finisher CP", "Minimum combo points before finishers")
        end)

        cooldowns_tree:render("Cooldowns", function()
            menu.use_blade_flurry:render("Blade Flurry", "Use for cleave and burst")
            menu.use_adrenaline_rush:render("Adrenaline Rush", "Use during dungeon and raid burst windows")
            menu.aoe_enemy_count:render("AoE Threshold", "Enemies needed before Blade Flurry is prioritized")
        end)
        
        local emergency_tree = core.menu.tree_node()
        emergency_tree:render("Emergency", function()
            menu.use_evasion:render("Use Evasion", "Use Evasion when health is low")
            menu.evasion_hp_pct:render("Evasion HP%", "Use Evasion below this health percent")
        end)
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxroguecombat_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eaxroguecombat_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
