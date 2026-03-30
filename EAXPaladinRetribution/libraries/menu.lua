-- menu.lua | Eax Paladin Retribution | TBC
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
menu.enabled          = core.menu.checkbox(true,  "eaxpaladinretribution_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxpaladinretribution_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxpaladinretribution_mode")
menu.debug            = core.menu.checkbox(false, "eaxpaladinretribution_debug")

-- Targeting
menu.focus_priority      = core.menu.checkbox(false, "eaxpaladinretribution_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxpaladinretribution_combat_self_hp_boost")

-- Racial
menu.use_racial = core.menu.checkbox(true, "eaxpaladinretribution_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxpaladinretribution_racial_hp")

-- OOC
menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez         = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff  = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
menu.auto_flask      = core.menu.checkbox(false, "eaxpaladinretribution_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxpaladinretribution_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxpaladinretribution_lev_mana_floor")

-- Rotation
menu.use_crusader_strike = core.menu.checkbox(true, "eaxpaladinretribution_use_crusader_strike")
menu.use_judgement = core.menu.checkbox(true, "eaxpaladinretribution_use_judgement")
menu.use_hammer_of_wrath = core.menu.checkbox(true, "eaxpaladinretribution_use_hammer_of_wrath")
menu.use_exorcism = core.menu.checkbox(true, "eaxpaladinretribution_use_exorcism")
menu.use_consecration = core.menu.checkbox(true, "eaxpaladinretribution_use_consecration")
menu.use_divine_storm = core.menu.checkbox(true, "eaxpaladinretribution_use_divine_storm")

-- Settings
settings.setup_major_toggle_keybinds(menu, {
}, {
    namespace = "eaxpaladinretribution",
    log_prefix = "[Eax Paladin Ret]",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpaladinretribution")
    end

    root_tree:render("Eax's Paladin Retribution", function()
        ps.render_controls(menu, "Eax's Paladin Retribution")

        -- Rotation
        main_tree:render("Rotation", function()
            ps.header("Rotation")
            menu.use_crusader_strike:render("Crusader Strike", "")
            menu.use_judgement:render("Judgement", "")
            menu.use_hammer_of_wrath:render("Hammer of Wrath", "")
            menu.use_exorcism:render("Exorcism", "")
            menu.use_consecration:render("Consecration", "")
            menu.use_divine_storm:render("Divine Storm", "")

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
