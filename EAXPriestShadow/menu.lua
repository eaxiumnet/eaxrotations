-- EAX Priest Shadow | menu.lua
-- Mode selection, DoT windows, and burst tuning for Shadow damage.

local menu = {}
local tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eax_priest_shadow_enabled")
menu.debug = core.menu.checkbox(false, "eax_priest_shadow_debug")
menu.mode = core.menu.combobox(1, "eax_priest_shadow_mode")

menu.dot_refresh_window = core.menu.slider_int(1, 5, 3, "eax_priest_shadow_dot_window")
menu.mind_blast_burst = core.menu.checkbox(true, "eax_priest_shadow_mb_burst")
menu.mind_blast_burst_window = core.menu.slider_float(0.5, 3, 1.4, "eax_priest_shadow_mb_burst_window")

menu.shadowfiend_enabled = core.menu.checkbox(true, "eax_priest_shadow_shadowfiend")
menu.shadowfiend_cooldown_seconds = core.menu.slider_int(12, 30, 18, "eax_priest_shadow_shadowfiend_cd")
menu.keep_shadowform = core.menu.checkbox(true, "eax_priest_shadow_shadowform")

function menu.render()
    tree:render("EAX Priest Shadow", function()
        menu.enabled:render("Enabled", "Enable Shadow Priest rotation")
        menu.debug:render("Debug Logging", "Log mode/resolution details")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        menu.dot_refresh_window:render("DoT Refresh Window", "Refresh Vampiric Touch / Shadow Word: Pain when only this many seconds remain")
        menu.mind_blast_burst:render("Burst Mind Blast", "Allow Mind Blast even when the DoTs are nearing expiry")
        menu.mind_blast_burst_window:render("Burst Window", "Force Mind Blast if one DoT has this many seconds or less remaining")

        menu.shadowfiend_enabled:render("Shadowfiend", "Summon Shadowfiend on cooldown for mana return")
        menu.shadowfiend_cooldown_seconds:render("Shadowfiend Cooldown", "Seconds between forced Shadowfiend summons")
        menu.keep_shadowform:render("Keep Shadowform", "Maintain Shadowform when available")
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eax_priest_shadow_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eax_priest_shadow_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
