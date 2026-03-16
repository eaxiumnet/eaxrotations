-- menu.lua
-- Configuration panel for EAX Warlock Affliction.

local menu = {}
local tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eax_affliction_enabled")
menu.debug = core.menu.checkbox(false, "eax_affliction_debug")
menu.toggle_key = core.menu.keybind(7, false, "eax_affliction_toggle")
menu.mode = core.menu.combobox(1, "eax_affliction_mode")

menu.use_unstable_affliction = core.menu.checkbox(true, "eax_affliction_use_ua")
menu.use_corruption = core.menu.checkbox(true, "eax_affliction_use_corruption")
menu.use_siphon_life = core.menu.checkbox(true, "eax_affliction_use_siphon_life")
menu.use_curse = core.menu.checkbox(true, "eax_affliction_use_curse")
menu.prefer_doom = core.menu.checkbox(false, "eax_affliction_prefer_doom")
menu.use_shadow_bolt = core.menu.checkbox(true, "eax_affliction_use_shadow_bolt")
menu.use_drain_soul = core.menu.checkbox(true, "eax_affliction_use_drain_soul")
menu.use_life_tap = core.menu.checkbox(true, "eax_affliction_use_life_tap")
menu.life_tap_threshold = core.menu.slider_int(10, 70, 35, "eax_affliction_lifetap_pct")

function menu.render()
    tree:render("EAX Warlock Affliction", function()
        menu.enabled:render("Enabled", "Master toggle")
        menu.toggle_key:render("Toggle Key", "Quickly enable or disable")
        menu.debug:render("Debug", "Print rotation notes to console")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })

        menu.use_unstable_affliction:render("Unstable Affliction", "Maintain the primary DoT")
        menu.use_corruption:render("Corruption", "Keep Corruption on the current target")
        menu.use_siphon_life:render("Siphon Life", "Keep Siphon Life active")
        menu.use_curse:render("Curse", "Apply Agony or Doom")
        menu.prefer_doom:render("Prefer Doom", "Use Curse of Doom when both curses are available")
        menu.use_shadow_bolt:render("Shadow Bolt", "Use Shadow Bolt as the filler spell")
        menu.use_drain_soul:render("Drain Soul", "Execute with Drain Soul below 25% HP")
        menu.use_life_tap:render("Life Tap", "Life Tap for extra mana")
        menu.life_tap_threshold:render("Life Tap HP %", "Life Tap when health is above this percent")
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxwarlockaffliction_combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, "eaxwarlockaffliction_focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
