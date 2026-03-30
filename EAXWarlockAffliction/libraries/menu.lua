-- menu.lua | Eax Warlock Affliction | TBC
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
menu.enabled          = core.menu.checkbox(true,  "eaxwarlockaffliction_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxwarlockaffliction_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxwarlockaffliction_mode")
menu.debug            = core.menu.checkbox(false, "eaxwarlockaffliction_debug")

-- Targeting
menu.focus_priority      = core.menu.checkbox(false, "eaxwarlockaffliction_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxwarlockaffliction_combat_self_hp_boost")

-- Racial
menu.use_racial = core.menu.checkbox(true, "eaxwarlockaffliction_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxwarlockaffliction_racial_hp")

-- OOC
menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez         = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff  = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
menu.auto_flask      = core.menu.checkbox(false, "eaxwarlockaffliction_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxwarlockaffliction_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxwarlockaffliction_lev_mana_floor")

-- Rotation
menu.use_corruption = core.menu.checkbox(true, "eaxwarlockaffliction_use_corruption")
menu.use_immolate = core.menu.checkbox(true, "eaxwarlockaffliction_use_immolate")
menu.use_unstable_affliction = core.menu.checkbox(true, "eaxwarlockaffliction_use_unstable_affliction")
menu.use_drain_soul = core.menu.checkbox(true, "eaxwarlockaffliction_use_drain_soul")
menu.use_shadow_bolt = core.menu.checkbox(true, "eaxwarlockaffliction_use_shadow_bolt")
menu.use_haunt = core.menu.checkbox(true, "eaxwarlockaffliction_use_haunt")

-- Settings
settings.setup_major_toggle_keybinds(menu, {
}, {
    namespace = "eaxwarlockaffliction",
    log_prefix = "[Eax Warlock Aff]",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxwarlockaffliction")
    end

    root_tree:render("Eax's Warlock Affliction", function()
        ps.render_controls(menu, "Eax's Warlock Affliction")

        -- Rotation
        main_tree:render("Rotation", function()
            ps.header("Rotation")
            menu.use_corruption:render("Corruption", "")
            menu.use_immolate:render("Immolate", "")
            menu.use_unstable_affliction:render("UA", "")
            menu.use_drain_soul:render("Drain Soul", "")
            menu.use_shadow_bolt:render("Shadow Bolt", "")
            menu.use_haunt:render("Haunt", "")

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
