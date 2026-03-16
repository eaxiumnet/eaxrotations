-- menu.lua
-- EAX Shaman Elemental | Menu tree

---@type color
local color = require("common/color")

local menu = {}
local dev_id = "eax_shaman_elemental_"
local main_node = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, dev_id .. "enabled")
menu.toggle_key = core.menu.keybind(7, false, dev_id .. "toggle_key")
menu.mode = core.menu.combobox(1, dev_id .. "mode")
menu.debug = core.menu.checkbox(false, dev_id .. "debug")

-- Rotation controls
menu.use_cooldowns = core.menu.checkbox(true, dev_id .. "use_cooldowns")
menu.aoe_threshold = core.menu.slider_int(1, 6, 3, dev_id .. "aoe_threshold")
menu.mana_floor = core.menu.slider_int(5, 60, 25, dev_id .. "mana_floor")
menu.execute_hp = core.menu.slider_int(0, 75, 50, dev_id .. "execute_hp")
menu.use_flame_shock = core.menu.checkbox(true, dev_id .. "use_flame_shock")
menu.flame_shock_stop_hp = core.menu.slider_int(10, 60, 35, dev_id .. "flame_shock_stop_hp")
menu.chain_lightning_mana = core.menu.slider_int(20, 70, 45, dev_id .. "chain_lightning_mana")
menu.range_min = core.menu.slider_int(5, 30, 22, dev_id .. "range_min")
menu.range_max = core.menu.slider_int(25, 45, 32, dev_id .. "range_max")

menu.auto_totems = core.menu.checkbox(true, dev_id .. "auto_totems")
menu.auto_totem_wrath = core.menu.checkbox(true, dev_id .. "auto_totem_wrath")
menu.auto_totem_mana = core.menu.checkbox(true, dev_id .. "auto_totem_mana")
menu.totem_twist_interval = core.menu.slider_int(20, 60, 30, dev_id .. "totem_twist_interval")
menu.prepull_totems = core.menu.checkbox(false, dev_id .. "prepull_totems")

function menu.render()
    main_node:render("EAX Shaman Elemental", function()
        menu.enabled:render("Enable", "Toggle the Elemental rotation")
        menu.toggle_key:render("Toggle Key")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })
        menu.debug:render("Debug Logging", "Log verbose messages for troubleshooting")

        if core.menu.header then
            core.menu.header():render("Rotation", color.green(180))
        end
        menu.use_cooldowns:render("Use Burst Cooldowns", "Permit Elemental Mastery / Nature's Swiftness")
        menu.aoe_threshold:render("AoE Threshold", "Chain Lightning engages when enough enemies are clustered")
        menu.chain_lightning_mana:render("Chain Lightning Mana", "Minimum mana % before AoE toggles")
        menu.mana_floor:render("Mana Floor", "Prevent rotation when mana drops below this %")
        menu.execute_hp:render("Execute Cutoff", "Hold Flame Shock / Lightning Bolt during execute phase")
        menu.range_min:render("Lightning Range Min", "Minimum target distance for Lightning Bolt")
        menu.range_max:render("Lightning Range Max", "Maximum target distance before spells fall back")
        menu.use_flame_shock:render("Use Flame Shock", "Maintain Flame Shock when stationary")
        menu.flame_shock_stop_hp:render("Flame Shock Stop HP", "Stop applying Flame Shock near execute")

        if core.menu.header then
            core.menu.header():render("Totems", color.blue(200))
        end
        menu.auto_totems:render("Auto Totems", "Twist Totem of Wrath + Mana Spring when toggled")
        menu.auto_totem_wrath:render("Totem of Wrath", "Keep the fire slot rolling")
        menu.auto_totem_mana:render("Mana Spring Totem", "Keep mana regen active")
        menu.totem_twist_interval:render("Totem Refresh (sec)", "Minimum seconds between auto twists")
        menu.prepull_totems:render("Pre-pull Totems", "Refresh totems before mounting a pull")
        
        menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, dev_id .. "combat_self_hp_boost")
        menu.focus_priority = core.menu.checkbox(false, dev_id .. "focus_priority")
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

function menu.log_debug(message)
    if menu.debug:get_state() then
        core.log("[EAX Shaman Elemental] " .. message)
    end
end

return menu
