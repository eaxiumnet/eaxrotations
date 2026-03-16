-- EAX Druid Feral | menu.lua
-- Menu elements are created once at require-time.

local spells = require("spells")

local menu = {}

local tree = core.menu.tree_node()
local shared_tree = core.menu.tree_node()
local cat_tree = core.menu.tree_node()
local bear_tree = core.menu.tree_node()

menu.enabled = core.menu.checkbox(true, "eaxdruidferal_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eaxdruidferal_toggle_key")
menu.debug = core.menu.checkbox(false, "eaxdruidferal_debug")
menu.mode = core.menu.combobox(1, "eaxdruidferal_mode")
menu.lane = core.menu.combobox(1, "eaxdruidferal_lane")
menu.auto_form = core.menu.checkbox(true, "eaxdruidferal_auto_form")
menu.use_faerie_fire = core.menu.checkbox(true, "eaxdruidferal_use_faerie_fire")

menu.use_mangle_cat = core.menu.checkbox(true, "eaxdruidferal_use_mangle_cat")
menu.use_rake = core.menu.checkbox(true, "eaxdruidferal_use_rake")
menu.use_shred = core.menu.checkbox(true, "eaxdruidferal_use_shred")
menu.use_rip = core.menu.checkbox(true, "eaxdruidferal_use_rip")
menu.use_ferocious_bite = core.menu.checkbox(true, "eaxdruidferal_use_ferocious_bite")
menu.use_tigers_fury = core.menu.checkbox(true, "eaxdruidferal_use_tigers_fury")
menu.rake_refresh_seconds = core.menu.slider_int(1, 5, 3, "eaxdruidferal_rake_refresh_seconds")
menu.rip_refresh_seconds = core.menu.slider_int(1, 5, 3, "eaxdruidferal_rip_refresh_seconds")
menu.rip_combo_points = core.menu.slider_int(3, 5, 5, "eaxdruidferal_rip_combo_points")
menu.bite_combo_points = core.menu.slider_int(3, 5, 5, "eaxdruidferal_bite_combo_points")
menu.bite_hp_pct = core.menu.slider_int(10, 40, 25, "eaxdruidferal_bite_hp_pct")
menu.tigers_fury_energy = core.menu.slider_int(10, 60, 30, "eaxdruidferal_tigers_fury_energy")

menu.use_mangle_bear = core.menu.checkbox(true, "eaxdruidferal_use_mangle_bear")
menu.use_maul = core.menu.checkbox(true, "eaxdruidferal_use_maul")
menu.use_swipe = core.menu.checkbox(true, "eaxdruidferal_use_swipe")
menu.auto_growl = core.menu.checkbox(true, "eaxdruidferal_auto_growl")
menu.use_frenzied_regeneration = core.menu.checkbox(true, "eaxdruidferal_use_frenzied_regeneration")
menu.use_berserk = core.menu.checkbox(true, "eaxdruidferal_use_berserk")
menu.swipe_enemy_count = core.menu.slider_int(2, 6, 3, "eaxdruidferal_swipe_enemy_count")
menu.maul_min_rage = core.menu.slider_int(10, 80, 45, "eaxdruidferal_maul_min_rage")
menu.frenzied_regeneration_hp_pct = core.menu.slider_int(10, 70, 40, "eaxdruidferal_frenzied_regeneration_hp_pct")

menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxdruidferal_combat_self_hp_boost")
menu.focus_priority = core.menu.checkbox(false, "eaxdruidferal_focus_priority")

local function active_lane()
    local lane_idx = menu.lane:get()
    if lane_idx == 2 then return "cat" end
    if lane_idx == 3 then return "bear" end

    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then
        return "cat"
    end

    local cat_data = me:get_buff_data(spells.BUFF_CAT_FORM)
    if cat_data and cat_data.is_active then
        return "cat"
    end

    local bear_data = me:get_buff_data(spells.BUFF_BEAR_FORM)
    if bear_data and bear_data.is_active then
        return "bear"
    end

    return "cat"
end

function menu.render()
    local lane = active_lane()

    tree:render("EAX Druid Feral", function()
        menu.enabled:render("Enabled", "Master enable/disable toggle")
        menu.toggle_key:render("Toggle Key", "Keybind to toggle enabled state")
        menu.debug:render("Debug Logging", "Print lane and rotation decisions to console")
        menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" }, "Auto resolves from current group size")
        menu.lane:render("Lane", { "Auto Detect", "Force Cat", "Force Bear" }, "Auto uses current form first, then falls back to the last practical lane")
        menu.auto_form:render("Auto Form", "Automatically shift into Cat or Bear for the active lane")

        shared_tree:render("Shared", function()
            menu.use_faerie_fire:render("Faerie Fire (Feral)", "Maintain Faerie Fire for both Cat and Bear lanes")
        end)

        if lane == "cat" then
            cat_tree:render("Cat DPS", function()
                menu.use_mangle_cat:render("Mangle (Cat)", "Maintain the shared Mangle debuff")
                menu.use_rake:render("Rake", "Maintain Rake bleed uptime")
                menu.use_shred:render("Shred", "Use Shred as the primary combo-point builder")
                menu.use_rip:render("Rip", "Spend combo points on Rip when ready")
                menu.use_ferocious_bite:render("Ferocious Bite", "Spend combo points on Ferocious Bite in execute windows")
                menu.use_tigers_fury:render("Tiger's Fury", "Recover energy for burst windows")
                menu.rake_refresh_seconds:render("Rake Refresh (sec)", "Refresh Rake below this remaining time")
                menu.rip_refresh_seconds:render("Rip Refresh (sec)", "Refresh Rip below this remaining time")
                menu.rip_combo_points:render("Rip Combo Points", "Minimum combo points before Rip")
                menu.bite_combo_points:render("Bite Combo Points", "Minimum combo points before Ferocious Bite")
                menu.bite_hp_pct:render("Bite HP %", "Execute threshold for Ferocious Bite")
                menu.tigers_fury_energy:render("Tiger's Fury Energy", "Use Tiger's Fury at or below this energy")
            end)
        else
            bear_tree:render("Bear Tank", function()
                menu.use_mangle_bear:render("Mangle (Bear)", "Maintain the shared Mangle debuff")
                menu.use_maul:render("Maul", "Queue Maul as a rage dump")
                menu.use_swipe:render("Swipe", "Use Swipe for pack threat")
                menu.auto_growl:render("Auto Growl", "Taunt when the current target is not on you")
                menu.use_frenzied_regeneration:render("Frenzied Regeneration", "Emergency self-heal in bear lane")
                menu.use_berserk:render("Berserk", "Use Berserk for high-pressure threat windows")
                menu.swipe_enemy_count:render("Swipe Enemy Count", "Minimum enemies before Swipe becomes preferred")
                menu.maul_min_rage:render("Maul Min Rage", "Minimum rage before Maul is queued")
                menu.frenzied_regeneration_hp_pct:render("Frenzied Regen HP %", "Self-health threshold for Frenzied Regeneration")
            end)
        end
        
        menu.combat_self_hp_boost:render("Combat Self HP Boost %", "Additional self-heal threshold when in combat")
        menu.focus_priority:render("Focus Target Priority", "Prioritize targeting your focus target")
    end)
end

return menu
