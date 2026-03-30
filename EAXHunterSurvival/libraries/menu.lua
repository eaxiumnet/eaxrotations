-- menu.lua  |  Eax Hunter Survival  |  TBC
local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- -- Tree nodes ----------------------------------------------------------------
local root_tree   = ps.tree_node()
local main_tree   = ps.tree_node()
local pet_tree    = ps.tree_node()
local def_tree    = ps.tree_node()
local tgt_tree    = ps.tree_node()
local racial_tree = ps.tree_node()
local ooc_tree    = ps.tree_node()

-- -- Controls ------------------------------------------------------------------
menu.enabled          = core.menu.checkbox(true,  "eaxhuntersv_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxhuntersv_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxhuntersv_mode")
menu.debug            = core.menu.checkbox(false, "eaxhuntersv_debug")

-- -- Targeting -----------------------------------------------------------------
menu.focus_priority      = core.menu.checkbox(false, "eaxhuntersv_focus_priority")
menu.combat_self_hp_boost = core.menu.slider_int(0, 30, 10, "eaxhuntersv_combat_self_hp_boost")

-- -- Racial --------------------------------------------------------------------
menu.use_racial = core.menu.checkbox(true, "eaxhuntersv_use_racial")
menu.racial_hp  = core.menu.slider_int(10, 80, 40, "eaxhuntersv_racial_hp")

-- -- OOC -----------------------------------------------------------------------
menu.ooc_drink       = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat         = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez         = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff  = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold   = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_flask                         = core.menu.checkbox(false, "eaxhuntersv_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxhuntersv_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxhuntersv_lev_mana_floor")

-- -- Rotation ------------------------------------------------------------------
menu.use_hunters_mark   = core.menu.checkbox(true, "eaxhuntersv_use_hunters_mark")
menu.use_serpent_sting  = core.menu.checkbox(true, "eaxhuntersv_use_serpent_sting")
menu.use_scorpid_sting  = core.menu.checkbox(false,"eaxhuntersv_use_scorpid_sting")
menu.use_viper_sting    = core.menu.checkbox(false,"eaxhuntersv_use_viper_sting")
menu.use_arcane_shot    = core.menu.checkbox(true, "eaxhuntersv_use_arcane_shot")
menu.use_aimed_shot     = core.menu.checkbox(false, "eaxhuntersv_use_aimed_shot")
menu.use_steady_shot    = core.menu.checkbox(true, "eaxhuntersv_use_steady_shot")
menu.use_multi_shot     = core.menu.checkbox(true, "eaxhuntersv_use_multi_shot")
menu.use_raptor_strike  = core.menu.checkbox(true, "eaxhuntersv_use_raptor_strike")
menu.use_wing_clip      = core.menu.checkbox(true, "eaxhuntersv_use_wing_clip")

-- Cooldowns
menu.use_rapid_fire     = core.menu.checkbox(true, "eaxhuntersv_use_rapid_fire")
menu.use_misdirection   = core.menu.checkbox(true, "eaxhuntersv_use_misdirection")
menu.use_aspect_viper   = core.menu.checkbox(true, "eaxhuntersv_use_aspect_viper")
menu.viper_mana_enter   = core.menu.slider_int(10, 60, 35, "eaxhuntersv_viper_enter")
menu.viper_mana_exit    = core.menu.slider_int(50, 100, 85, "eaxhuntersv_viper_mana_exit")
menu.auto_travel_aspect  = core.menu.checkbox(true, "eaxhuntersv_auto_travel_aspect")

-- -- Pet -----------------------------------------------------------------------
menu.use_kill_command   = core.menu.checkbox(true, "eaxhuntersv_use_kill_command")
menu.use_bestial_wrath  = core.menu.checkbox(true, "eaxhuntersv_use_bestial_wrath")
menu.use_intimidation   = core.menu.checkbox(true, "eaxhuntersv_use_intimidation")
menu.use_mend_pet       = core.menu.checkbox(true, "eaxhuntersv_use_mend_pet")
menu.mend_pet_hp        = core.menu.slider_int(10, 90, 50, "eaxhuntersv_mend_pet_hp")
menu.use_revive_pet     = core.menu.checkbox(true, "eaxhuntersv_use_revive_pet")

-- Kiting/Utility
menu.use_concussive     = core.menu.checkbox(true, "eaxhuntersv_use_concussive")
menu.use_disengage      = core.menu.checkbox(true, "eaxhuntersv_use_disengage")
menu.use_deterrence     = core.menu.checkbox(true, "eaxhuntersv_use_deterrence")
menu.deterrence_hp      = core.menu.slider_int(5, 40, 12, "eaxhuntersv_deterrence_hp")
menu.use_feign_death    = core.menu.checkbox(true, "eaxhuntersv_use_feign_death")
menu.feign_death_hp     = core.menu.slider_int(5, 40, 20, "eaxhuntersv_feign_hp")

-- -- Traps ---------------------------------------------------------------------
menu.use_traps       = core.menu.checkbox(true, "eaxhuntersv_use_traps")
menu.trap_selection  = core.menu.combobox(1,    "eaxhuntersv_trap_selection")
menu.trap_interval   = core.menu.slider_float(1.0, 60.0, 30.0, "eaxhuntersv_trap_interval")

-- -- Window --------------------------------------------------------------------
settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_serpent_sting", label = "Serpent Sting" },
    { toggle = "use_steady_shot", label = "Steady Shot" },
    { toggle = "use_multi_shot", label = "Multi-Shot" },
    { toggle = "use_kill_command", label = "Kill Command" },
    { toggle = "use_traps", label = "Traps" },
}, {
    namespace = "eaxhuntersv",
    log_prefix = "[Eax Hunter SV] ",
})

local spec_name = "Hunter Survival"

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    root_tree:render("Eax's " .. spec_name, function()
        ps.render_controls(menu, spec_name)

        -- Rotation
        main_tree:render("Rotation", function()
            ps.header("Shots")
            menu.use_hunters_mark:render("Hunter's Mark",  "Apply Hunter's Mark for +AP")
            menu.use_serpent_sting:render("Serpent Sting", "Maintain Serpent Sting DoT")
            menu.use_arcane_shot:render("Arcane Shot",     "Instant filler")
            menu.use_steady_shot:render("Steady Shot",     "Filler")
            menu.use_multi_shot:render("Multi-Shot",       "AoE shot")
            menu.use_raptor_strike:render("Raptor Strike", "Melee fallback")
            menu.use_wing_clip:render("Wing Clip",         "Slow target")

            ps.header("Stings (Group)")
            menu.use_scorpid_sting:render("Scorpid Sting", "-5% hit in raids")
            menu.use_viper_sting:render("Viper Sting",     "Drain mana from casters")

            ps.header("Cooldowns")
            menu.use_rapid_fire:render("Rapid Fire",     "3-min burst CD")
            menu.use_misdirection:render("Misdirection",  "Threat transfer")

            ps.header("Aspects")
            menu.use_aspect_viper:render("Auto-Viper",   "Switch to Viper when low mana")
            menu.viper_mana_enter:render("Enter Viper %", "Switch below this %")
            menu.viper_mana_exit:render("Exit Viper %",  "Switch back above this %")
            menu.auto_travel_aspect:render("Auto Travel Aspect", "Use travel aspect OOC")

            ps.header("Traps")
            menu.use_traps:render("Use Traps",           "Drop trap in melee")
            menu.trap_selection:render("Trap Type",      {"Immolation", "Frost"})
            menu.trap_interval:render("Trap Interval",   "Seconds between traps")
        end)

        -- Pet
        pet_tree:render("Pet", function()
            menu.use_kill_command:render("Kill Command",   "Off-GCD pet attack")
            menu.use_bestial_wrath:render("Bestial Wrath", "2-min burst")
            menu.use_intimidation:render("Intimidation",   "Pet stun")
            menu.use_mend_pet:render("Mend Pet",         "Heal pet when low")
            menu.mend_pet_hp:render("Mend Pet HP %",     "Mend below this %")
            menu.use_revive_pet:render("Revive Pet",      "Auto revive OOC")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_concussive:render("Concussive Shot", "Slow target")
            menu.use_disengage:render("Disengage",       "Escape melee")
            menu.use_deterrence:render("Deterrence",     "Self-defense")
            menu.deterrence_hp:render("Deterrence HP %", "Trigger below %")
            menu.use_feign_death:render("Feign Death",   "Emergency fade")
            menu.feign_death_hp:render("Feign Death HP %", "Trigger below %")
        end)

        -- OOC
        ooc_tree:render("OOC", function()
            ps.header("Sustain")
            menu.ooc_drink:render("Auto-Drink", "Drink OOC")
            menu.drink_threshold:render("Drink Threshold %", "Start below %")
            menu.ooc_eat:render("Auto-Eat", "Eat OOC")
            menu.eat_threshold:render("Eat Threshold %", "Start below %")
            menu.auto_flask:render("Auto Flask", "Maintain flask buff")

            ps.header("Group")
            menu.ooc_rez:render("Auto-Resurrect", "Accept rez OOC")
            menu.ooc_group_buff:render("Group Buffs", "Buff party")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Efficient rotation")
            menu.leveling_mana_floor:render("Mana Floor %", "Conserve below %")
        end)

        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
    end)
end

return menu
