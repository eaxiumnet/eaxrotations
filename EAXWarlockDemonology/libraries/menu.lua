-- menu.lua | Eax Warlock Demonology | TBC
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
menu.enabled          = core.menu.checkbox(true,  "eaxwarlockdemonology_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxwarlockdemonology_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxwarlockdemonology_mode")
menu.debug            = core.menu.checkbox(false, "eaxwarlockdemonology_debug")

-- Targeting
menu.focus_priority      = core.menu.checkbox(false, "eaxwarlockdemonology_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxwarlockdemonology_combat_self_hp_boost")

-- Racial
menu.use_racial = core.menu.checkbox(true, "eaxwarlockdemonology_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxwarlockdemonology_racial_hp")

-- OOC
menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez         = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff  = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
menu.auto_flask      = core.menu.checkbox(false, "eaxwarlockdemonology_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxwarlockdemonology_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxwarlockdemonology_lev_mana_floor")

-- Rotation
menu.use_shadow_bolt = core.menu.checkbox(true, "eaxwarlockdemonology_use_shadow_bolt")
menu.use_demon_soul = core.menu.checkbox(true, "eaxwarlockdemonology_use_demon_soul")
menu.use_metamorphosis = core.menu.checkbox(true, "eaxwarlockdemonology_use_metamorphosis")
menu.use_hand_of_guldan = core.menu.checkbox(true, "eaxwarlockdemonology_use_hand_of_guldan")
menu.use_soul_fire = core.menu.checkbox(true, "eaxwarlockdemonology_use_soul_fire")
menu.use_decimation = core.menu.checkbox(true, "eaxwarlockdemonology_use_decimation")

-- Settings
settings.setup_major_toggle_keybinds(menu, {
}, {
    namespace = "eaxwarlockdemonology",
    log_prefix = "[Eax Warlock Demo]",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarlockdemonology")
    end

    root_tree:render("Eax's Warlock Demonology", function()
        ps.render_controls(menu, "Eax's Warlock Demonology")

        -- Rotation
        main_tree:render("Rotation", function()
            ps.header("Rotation")
            menu.use_shadow_bolt:render("Shadow Bolt", "")
            menu.use_demon_soul:render("Demon Soul", "")
            menu.use_metamorphosis:render("Metamorphosis", "")
            menu.use_hand_of_guldan:render("HoG", "")
            menu.use_soul_fire:render("Soul Fire", "")
            menu.use_decimation:render("Decimation", "")

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
