-- menu.lua | Eax Priest Discipline | TBC
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
menu.enabled          = core.menu.checkbox(true,  "eaxpriestdiscipline_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxpriestdiscipline_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxpriestdiscipline_mode")
menu.debug            = core.menu.checkbox(false, "eaxpriestdiscipline_debug")

-- Targeting
menu.focus_priority      = core.menu.checkbox(false, "eaxpriestdiscipline_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxpriestdiscipline_combat_self_hp_boost")

-- Racial
menu.use_racial = core.menu.checkbox(true, "eaxpriestdiscipline_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxpriestdiscipline_racial_hp")

-- OOC
menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez         = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff  = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
menu.auto_flask      = core.menu.checkbox(false, "eaxpriestdiscipline_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxpriestdiscipline_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxpriestdiscipline_lev_mana_floor")

-- Rotation
menu.use_greater_heal = core.menu.checkbox(true, "eaxpriestdiscipline_use_greater_heal")
menu.use_flash_heal = core.menu.checkbox(true, "eaxpriestdiscipline_use_flash_heal")
menu.use_power_word_shield = core.menu.checkbox(true, "eaxpriestdiscipline_use_power_word_shield")
menu.use_weakened_soul = core.menu.checkbox(true, "eaxpriestdiscipline_use_weakened_soul")
menu.use_penance = core.menu.checkbox(true, "eaxpriestdiscipline_use_penance")
menu.use_aegis = core.menu.checkbox(true, "eaxpriestdiscipline_use_aegis")

-- Settings
settings.setup_major_toggle_keybinds(menu, {
}, {
    namespace = "eaxpriestdiscipline",
    log_prefix = "[Eax Priest Disc]",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpriestdiscipline")
    end

    root_tree:render("Eax's Priest Discipline", function()
        ps.render_controls(menu, "Eax's Priest Discipline")

        -- Rotation
        main_tree:render("Rotation", function()
            ps.header("Rotation")
            menu.use_greater_heal:render("Greater Heal", "")
            menu.use_flash_heal:render("Flash Heal", "")
            menu.use_power_word_shield:render("PW:Shield", "")
            menu.use_weakened_soul:render("Weakened Soul", "")
            menu.use_penance:render("Penance", "")
            menu.use_aegis:render("Aegis", "")

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
