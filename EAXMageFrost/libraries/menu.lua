-- menu.lua | Eax Mage Frost | TBC
local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes
local root_tree   = ps.tree_node()
local main_tree   = ps.tree_node()
local def_tree    = ps.tree_node()
local tgt_tree    = ps.tree_node()
local racial_tree = ps.tree_node()
local ooc_tree    = ps.tree_node()

-- Controls
menu.enabled          = core.menu.checkbox(true,  "eaxmagefrost_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxmagefrost_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxmagefrost_mode")
menu.debug            = core.menu.checkbox(false, "eaxmagefrost_debug")

-- Targeting
menu.focus_priority      = core.menu.checkbox(false, "eaxmagefrost_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxmagefrost_combat_self_hp_boost")

-- Racial
menu.use_racial = core.menu.checkbox(true, "eaxmagefrost_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxmagefrost_racial_hp")

-- OOC
menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez         = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff  = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
menu.auto_flask      = core.menu.checkbox(false, "eaxmagefrost_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxmagefrost_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxmagefrost_lev_mana_floor")

-- Rotation
menu.use_frostbolt = core.menu.checkbox(true, "eaxmagefrost_use_frostbolt")
menu.use_ice_lance = core.menu.checkbox(true, "eaxmagefrost_use_ice_lance")
menu.use_frostfire_bolt = core.menu.checkbox(true, "eaxmagefrost_use_frostfire_bolt")
menu.use_deep_freeze = core.menu.checkbox(true, "eaxmagefrost_use_deep_freeze")
menu.use_icy_veins = core.menu.checkbox(true, "eaxmagefrost_use_icy_veins")
menu.use_blizzard = core.menu.checkbox(true, "eaxmagefrost_use_blizzard")

-- Settings
settings.setup_major_toggle_keybinds(menu, {
}, {
    namespace = "eaxmagefrost",
    log_prefix = "[Eax Mage Frost]",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxmagefrost")
    end

    root_tree:render("Eax's Mage Frost", function()
        ps.render_controls(menu, "Eax's Mage Frost")

        -- Rotation
        main_tree:render("Rotation", function()
            ps.header("Rotation")
            menu.use_frostbolt:render("Frostbolt", "")
            menu.use_ice_lance:render("Ice Lance", "")
            menu.use_frostfire_bolt:render("Frostfire Bolt", "")
            menu.use_deep_freeze:render("Deep Freeze", "")
            menu.use_icy_veins:render("Icy Veins", "")
            menu.use_blizzard:render("Blizzard", "")

        end)

        -- Defensive
        def_tree:render("Defensive", function()
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)

        -- OOC
        ooc_tree:render("OOC", function()
            ps.header("Sustain")
            menu.ooc_drink:render("Auto-Drink", "Drink OOC")
            menu.ooc_eat:render("Auto-Eat", "Eat OOC")
            menu.auto_flask:render("Auto Flask", "Flask buff")

            ps.header("Group")
            menu.ooc_rez:render("Auto-Rez", "Accept rez")
            menu.ooc_group_buff:render("Buffs", "Party buffs")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve", "Mana efficient")
            menu.leveling_mana_floor:render("Mana %", "Below %")
        end)
    end)
end

return menu
