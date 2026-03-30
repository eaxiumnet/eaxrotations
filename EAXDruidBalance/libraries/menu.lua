-- menu.lua | Eax Druid Balance | TBC
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
menu.enabled          = core.menu.checkbox(true,  "eaxdruidbalance_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxdruidbalance_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxdruidbalance_mode")
menu.debug            = core.menu.checkbox(false, "eaxdruidbalance_debug")

-- Targeting
menu.focus_priority      = core.menu.checkbox(false, "eaxdruidbalance_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxdruidbalance_combat_self_hp_boost")

-- Racial
menu.use_racial = core.menu.checkbox(true, "eaxdruidbalance_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxdruidbalance_racial_hp")

-- OOC
menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez         = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff  = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
menu.auto_flask      = core.menu.checkbox(false, "eaxdruidbalance_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxdruidbalance_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxdruidbalance_lev_mana_floor")

-- Shifts
menu.use_travel_form = core.menu.checkbox(true, "eaxdruidbalance_use_travel_form")
menu.use_mount_form = core.menu.checkbox(true, "eaxdruidbalance_use_mount_form")

-- Rotation
menu.use_moonfire = core.menu.checkbox(true, "eaxdruidbalance_use_moonfire")
menu.use_insect_swarm = core.menu.checkbox(true, "eaxdruidbalance_use_insect_swarm")
menu.use_starfire = core.menu.checkbox(true, "eaxdruidbalance_use_starfire")
menu.use_wrath = core.menu.checkbox(true, "eaxdruidbalance_use_wrath")
menu.use_hurricane = core.menu.checkbox(true, "eaxdruidbalance_use_hurricane")

-- Settings
settings.setup_major_toggle_keybinds(menu, {
}, {
    namespace = "eaxdruidbalance",
    log_prefix = "[Eax Druid Balance]",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxdruidbalance")
    end

    root_tree:render("Eax's Druid Balance", function()
        ps.render_controls(menu, "Eax's Druid Balance")

        -- Rotation
        main_tree:render("Rotation", function()
            ps.header("Shifts")
            menu.use_travel_form:render("Travel Form", "")
            menu.use_mount_form:render("Mount Form", "")

            ps.header("Rotation")
            menu.use_moonfire:render("Moonfire", "")
            menu.use_insect_swarm:render("Insect Swarm", "")
            menu.use_starfire:render("Starfire", "")
            menu.use_wrath:render("Wrath", "")
            menu.use_hurricane:render("Hurricane", "")

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
