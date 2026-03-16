-- menu.lua
-- EAX Shaman Enhancement | Menu tree

---@type color
local color = require("common/color")

local menu = {}
local dev_id = "eax_shaman_enhancement_"
local main_node = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, dev_id .. "enabled")
menu.toggle_key = core.menu.keybind(7, false, dev_id .. "toggle_key")
menu.mode = core.menu.combobox(1, dev_id .. "mode")
menu.debug = core.menu.checkbox(false, dev_id .. "debug")

menu.use_cooldowns = core.menu.checkbox(true, dev_id .. "use_cooldowns")
menu.use_chain_lightning_weave = core.menu.checkbox(true, dev_id .. "use_chain_lightning_weave")
menu.swing_clip_ms = core.menu.slider_int(80, 220, 160, dev_id .. "swing_clip_ms")
menu.shock_mode = core.menu.combobox(1, dev_id .. "shock_mode")
menu.shamanistic_rage_hp = core.menu.slider_int(0, 100, 40, dev_id .. "shamanistic_rage_hp")
menu.shamanistic_rage_mana = core.menu.slider_int(0, 100, 35, dev_id .. "shamanistic_rage_mana")
menu.dual_wield_focus = core.menu.checkbox(true, dev_id .. "dual_wield_focus")

menu.auto_totems = core.menu.checkbox(true, dev_id .. "auto_totems")
menu.auto_totem_wrath = core.menu.checkbox(true, dev_id .. "auto_totem_wrath")
menu.auto_totem_windfury = core.menu.checkbox(true, dev_id .. "auto_totem_windfury")
menu.prepull_totems = core.menu.checkbox(false, dev_id .. "prepull_totems")

-- EAX utils integration (must be at module scope, not inside render)
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, dev_id .. "combat_self_hp_boost")
menu.focus_priority = core.menu.checkbox(false, dev_id .. "focus_priority")

function menu.render()
    main_node:render("EAX Shaman Enhancement", function()
        menu.enabled:render("Enable", "Toggle the Enhancement rotation")
        menu.toggle_key:render("Toggle Key")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" },
            "Auto: Detect content\nSolo: Aggressive melee\nDungeon/Raid: Harder melee windows")
        menu.debug:render("Debug", "Verbose logging for developers")

        if core.menu.header then
            core.menu.header():render("Stormstrike Loop", color.orange(200))
        end
        menu.use_cooldowns:render("Use Cooldowns", "Stormstrike + Rage react to burst windows")
        menu.dual_wield_focus:render("Dual Wield Focus", "Prioritize dual-wield uptime and snapshots")
        menu.swing_clip_ms:render("Swing Clip (ms)", "Chain Lightning weaves happen when swing delay exceeds this window")
        menu.use_chain_lightning_weave:render("Chain Lightning Weave", "Allow Chain Lightning between auto-attacks")
        menu.shock_mode:render("Shock Mode", { "Earth", "Flame", "Frost" }, "Choose which Shock to maintain")
        menu.shamanistic_rage_hp:render("Rage HP Trigger", "Cast Shamanistic Rage below this health %")
        menu.shamanistic_rage_mana:render("Rage Mana Trigger", "Cast Rage below this mana %")

        if core.menu.header then
            core.menu.header():render("Totems", color.blue(200))
        end
        menu.auto_totems:render("Auto Totems", "Keep Totem of Wrath and Windfury active")
        menu.auto_totem_wrath:render("Totem of Wrath", "Drive the fire slot")
        menu.auto_totem_windfury:render("Windfury Totem", "Refresh Windfury for melee procs")
        menu.prepull_totems:render("Pre-pull Totems", "Cast totems before the fight starts")

        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

function menu.log_debug(message)
    if menu.debug:get_state() then
        core.log("[EAX Shaman Enhancement] " .. tostring(message))
    end
end

return menu
