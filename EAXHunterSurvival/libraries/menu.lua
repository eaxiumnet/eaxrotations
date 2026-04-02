-- menu.lua | Eax Hunter Survival | TBC
local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

local root_tree   = ps.tree_node()
local rotation_tree = ps.tree_node()
local cd_tree     = ps.tree_node()
local kite_tree   = ps.tree_node()
local auto_tree   = ps.tree_node()
local ooc_tree    = ps.tree_node()
local group_tree  = ps.tree_node()
local def_tree    = ps.tree_node()
local tgt_tree    = ps.tree_node()
local racial_tree = ps.tree_node()
local esp_tree    = ps.tree_node()

menu.enabled          = core.menu.checkbox(true,  "eaxhuntersv_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxhuntersv_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxhuntersv_mode")
menu.debug            = core.menu.checkbox(false, "eaxhuntersv_debug")

menu.focus_priority      = core.menu.checkbox(false, "eaxhuntersv_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxhuntersv_combat_self_hp_boost")

menu.use_racial = core.menu.checkbox(true, "eaxhuntersv_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxhuntersv_racial_hp")

-- Interrupt
menu.use_interrupt = core.menu.checkbox(true, "eaxhuntersv_use_interrupt")

menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez         = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff  = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_combat_potions = core.menu.checkbox(false, "eaxhuntersv_auto_combat_potions")
menu.auto_flask      = core.menu.checkbox(false, "eaxhuntersv_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxhuntersv_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxhuntersv_lev_mana_floor")

menu.use_hunters_mark   = core.menu.checkbox(true, "eaxhuntersv_use_hunters_mark")
menu.use_serpent_sting  = core.menu.checkbox(true, "eaxhuntersv_use_serpent_sting")
menu.use_scorpid_sting  = core.menu.checkbox(false,"eaxhuntersv_use_scorpid_sting")
menu.use_viper_sting    = core.menu.checkbox(false,"eaxhuntersv_use_viper_sting")
menu.use_arcane_shot    = core.menu.checkbox(true, "eaxhuntersv_use_arcane_shot")
menu.use_aimed_shot     = core.menu.checkbox(false, "eaxhuntersv_use_aimed_shot")
menu.use_steady_shot    = core.menu.checkbox(true, "eaxhuntersv_use_steady_shot")
menu.use_multi_shot     = core.menu.checkbox(true, "eaxhuntersv_use_multi_shot")

menu.use_rapid_fire     = core.menu.checkbox(true, "eaxhuntersv_use_rapid_fire")
menu.use_misdirection   = core.menu.checkbox(true, "eaxhuntersv_use_misdirection")
menu.use_aspect_viper   = core.menu.checkbox(true, "eaxhuntersv_use_aspect_viper")
menu.viper_mana_enter   = core.menu.slider_int(10, 60, 35, "eaxhuntersv_viper_enter")
menu.viper_mana_exit    = core.menu.slider_int(50, 100, 85, "eaxhuntersv_viper_mana_exit")
menu.auto_travel_aspect  = core.menu.checkbox(true, "eaxhuntersv_auto_travel_aspect")

menu.use_concussive     = core.menu.checkbox(true, "eaxhuntersv_use_concussive")
menu.use_disengage      = core.menu.checkbox(true, "eaxhuntersv_use_disengage")
menu.use_deterrence     = core.menu.checkbox(true, "eaxhuntersv_use_deterrence")
menu.deterrence_hp      = core.menu.slider_int(5, 40, 12, "eaxhuntersv_deterrence_hp")
menu.use_feign_death    = core.menu.checkbox(true, "eaxhuntersv_use_feign_death")
menu.feign_death_hp     = core.menu.slider_int(5, 40, 20, "eaxhuntersv_feign_hp")

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_serpent_sting", label = "Serpent Sting" },
    { toggle = "use_steady_shot", label = "Steady Shot" },
}, {
    namespace = "eaxhuntersv",
    log_prefix = "[Eax Hunter SV] ",
})

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxhuntersv")
    end

    root_tree:render("Eax's Hunter Survival", function()
        ps.render_controls(menu, "Eax's Hunter SV")

        rotation_tree:render("Rotation", function()
            ps.header("Shots")
            menu.use_hunters_mark:render("Hunter's Mark", "+AP")
            menu.use_serpent_sting:render("Serpent Sting", "DoT")
            menu.use_arcane_shot:render("Arcane Shot", "Filler")
            menu.use_aimed_shot:render("Aimed Shot", "Cast")
            menu.use_steady_shot:render("Steady Shot", "Filler")
            menu.use_multi_shot:render("Multi-Shot", "AoE")

            ps.header("Stings (Group)")
            menu.use_scorpid_sting:render("Scorpid Sting", "-5% hit")
            menu.use_viper_sting:render("Viper Sting", "Drain")

            ps.header("Cooldowns")
            menu.use_rapid_fire:render("Rapid Fire", "Burst")
            menu.use_misdirection:render("Misdirection", "Threat")
            menu.use_aspect_viper:render("Auto-Viper", "Low mana")
            menu.viper_mana_enter:render("Enter Viper %", "Below")
            menu.viper_mana_exit:render("Exit Viper %", "Above")
            menu.auto_travel_aspect:render("Travel Aspect", "OOC")
        end)

        kite_tree:render("Defensive", function()
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
            menu.use_concussive:render("Concussive Shot", "Slow")
            menu.use_disengage:render("Disengage", "Escape")
            menu.use_deterrence:render("Deterrence", "Self-def")
            menu.deterrence_hp:render("Deterrence HP %", "Below")
            menu.use_feign_death:render("Feign Death", "Emergency")
            menu.feign_death_hp:render("Feign HP %", "Below")
        end)

        auto_tree:render("Automation", function()
            menu.auto_combat_potions:render("Combat Potions", "In combat")
            menu.auto_flask:render("Auto Flask", "Flask")
            menu.leveling_conserve_mana:render("Conserve Mana", "Leveling")
            menu.leveling_mana_floor:render("Mana %", "Below")
        end)

        ooc_tree:render("OOC Sustain", function()
            menu.ooc_drink:render("Auto-Drink", "Drink")
            menu.drink_threshold:render("Drink %", "Below")
            menu.ooc_eat:render("Auto-Eat", "Eat")
            menu.eat_threshold:render("Eat %", "Below")
        end)

        group_tree:render("Group", function()
            menu.ooc_rez:render("Auto-Rez", "Accept")
            menu.ooc_group_buff:render("Buffs", "Party")
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end

return menu
