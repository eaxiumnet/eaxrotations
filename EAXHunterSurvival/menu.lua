-- menu.lua  |  Eax Hunter Survival  |  TBC
local ps   = require("ps_theme")
local settings = require("settings_framework")
local menu = {}

-- -- Tree nodes ----------------------------------------------------------------
local root_tree   = ps.tree_node()
local main_tree   = ps.tree_node()
local pet_tree    = ps.tree_node()
local cd_tree     = ps.tree_node()
local kite_tree   = ps.tree_node()
local def_tree    = ps.tree_node()
local tgt_tree    = ps.tree_node()
local racial_tree = ps.tree_node()
local ooc_tree    = ps.tree_node()
local esp_tree    = ps.tree_node()

-- -- Controls ------------------------------------------------------------------
menu.enabled          = core.menu.checkbox(true,  "eaxhuntersv_enabled")
menu.toggle_key       = core.menu.keybind(7, false, "eaxhuntersv_toggle_key")
menu.mode             = core.menu.combobox(1, "eaxhuntersv_mode")
menu.debug            = core.menu.checkbox(false, "eaxhuntersv_debug")

-- -- Targeting -----------------------------------------------------------------
menu.focus_priority       = core.menu.checkbox(false, "eaxhuntersv_focus_priority")
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

menu.auto_repair                        = core.menu.checkbox(true, "eaxhuntersv_auto_repair")
menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxhuntersv_auto_sell_greys")
menu.auto_mount                         = core.menu.checkbox(true, "eaxhuntersv_auto_mount")
menu.auto_dismount                      = core.menu.checkbox(true, "eaxhuntersv_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxhuntersv_auto_combat_potions")
menu.auto_flask                         = core.menu.checkbox(false, "eaxhuntersv_auto_flask")
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxhuntersv_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxhuntersv_lev_mana_floor")

-- -- ESP -----------------------------------------------------------------------
menu.esp_show_hud    = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x       = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y       = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Rotation ------------------------------------------------------------------
menu.use_hunters_mark   = core.menu.checkbox(true, "eaxhuntersv_use_hunters_mark")
menu.use_serpent_sting  = core.menu.checkbox(true, "eaxhuntersv_use_serpent_sting")
menu.use_immolation_trap = core.menu.checkbox(true, "eaxhuntersv_use_immolation_trap")
menu.use_explosive_trap  = core.menu.checkbox(true, "eaxhuntersv_use_explosive_trap")
menu.use_arcane_shot    = core.menu.checkbox(true, "eaxhuntersv_use_arcane_shot")
menu.use_aimed_shot     = core.menu.checkbox(true, "eaxhuntersv_use_aimed_shot")
menu.use_steady_shot    = core.menu.checkbox(true, "eaxhuntersv_use_steady_shot")
menu.use_multi_shot     = core.menu.checkbox(true, "eaxhuntersv_use_multi_shot")
menu.use_raptor_strike  = core.menu.checkbox(true, "eaxhuntersv_use_raptor_strike")
menu.use_mongoose_bite  = core.menu.checkbox(true, "eaxhuntersv_use_mongoose_bite")
menu.use_wing_clip      = core.menu.checkbox(true, "eaxhuntersv_use_wing_clip")

-- -- Pet -----------------------------------------------------------------------
menu.use_kill_command = core.menu.checkbox(true, "eaxhuntersv_use_kill_command")
menu.use_mend_pet     = core.menu.checkbox(true, "eaxhuntersv_use_mend_pet")
menu.mend_pet_hp      = core.menu.slider_int(10, 90, 50, "eaxhuntersv_mend_pet_hp")
menu.use_revive_pet   = core.menu.checkbox(true, "eaxhuntersv_use_revive_pet")

-- -- Cooldowns -----------------------------------------------------------------
menu.use_rapid_fire   = core.menu.checkbox(true, "eaxhuntersv_use_rapid_fire")
menu.use_misdirection = core.menu.checkbox(true, "eaxhuntersv_use_misdirection")
menu.use_aspect_viper = core.menu.checkbox(true, "eaxhuntersv_use_aspect_viper")
menu.viper_mana_enter = core.menu.slider_int(10, 60, 35, "eaxhuntersv_viper_enter")
menu.viper_mana_exit  = core.menu.slider_int(50, 100, 85, "eaxhuntersv_viper_exit")
menu.auto_travel_aspect = core.menu.checkbox(true, "eaxhuntersv_auto_travel_aspect")
menu.use_pack_as_travel_aspect = core.menu.checkbox(false, "eaxhuntersv_use_pack_as_travel_aspect")

-- -- Kiting --------------------------------------------------------------------
menu.use_concussive  = core.menu.checkbox(true, "eaxhuntersv_use_concussive")
menu.use_disengage   = core.menu.checkbox(true, "eaxhuntersv_use_disengage")
menu.use_deterrence  = core.menu.checkbox(true, "eaxhuntersv_use_deterrence")
menu.deterrence_hp   = core.menu.slider_int(5, 40, 12, "eaxhuntersv_deterrence_hp")
menu.use_scare_beast = core.menu.checkbox(false, "eaxhuntersv_use_scare_beast")
menu.use_flare       = core.menu.checkbox(false, "eaxhuntersv_use_flare")
menu.auto_stealth_flare = core.menu.checkbox(true, "eaxhuntersv_auto_stealth_flare")
menu.stealth_warning    = core.menu.checkbox(true, "eaxhuntersv_stealth_warning")
    menu.stealth_scan_radius = core.menu.slider_float(10.0, 60.0, 20.0, "eaxhuntersv_stealth_scan_radius")
    menu.stealth_prediction_s = core.menu.slider_float(0.00, 0.75, 0.20, "eaxhuntersv_stealth_prediction_s")
    menu.stealth_overlay_enabled = core.menu.checkbox(true, "eaxhuntersv_stealth_overlay_enabled")
    menu.stealth_overlay_direction = core.menu.checkbox(true, "eaxhuntersv_stealth_overlay_direction")
menu.sync_pet_autocast = core.menu.checkbox(true, "eaxhuntersv_sync_pet_autocast")
menu.disable_growl_in_group = core.menu.checkbox(true, "eaxhuntersv_disable_growl_in_group")
menu.use_wyvern_sting = core.menu.checkbox(false, "eaxhuntersv_use_wyvern_sting")
menu.use_feign_death = core.menu.checkbox(true, "eaxhuntersv_use_feign_death")
menu.feign_death_hp  = core.menu.slider_int(5, 40, 20, "eaxhuntersv_feign_hp")

-- -- Traps ---------------------------------------------------------------------
menu.use_traps      = core.menu.checkbox(true, "eaxhuntersv_use_traps")
menu.trap_selection = core.menu.combobox(1,    "eaxhuntersv_trap_selection")
menu.trap_interval  = core.menu.slider_float(1.0, 60.0, 30.0, "eaxhuntersv_trap_interval")

-- -- Window --------------------------------------------------------------------
settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_serpent_sting", label = "Serpent Sting" },
    { toggle = "use_aimed_shot", label = "Aimed Shot" },
    { toggle = "use_multi_shot", label = "Multi-Shot" },
    { toggle = "use_kill_command", label = "Kill Command" },
    { toggle = "use_traps", label = "Traps" },
}, {
    namespace = "eaxhuntersurvival",
    log_prefix = "[Eax Hunter Survival] ",
})

local _win
function menu.set_window(win) _win = win end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxhuntersv")
    end
    root_tree:render("Eax's Hunter Survival", function()

        ps.render_controls(menu, "Eax's Hunter SV")

        -- -- Rotation settings ---------------------------------------------
        main_tree:render("Rotation Settings", function()
            ps.header("Core Shots")
            menu.use_hunters_mark:render("Hunter's Mark",    "Open with Hunter's Mark and keep the debuff on kill targets.")
            menu.use_serpent_sting:render("Serpent Sting",   "Maintain Serpent Sting as the core single-target DoT.")
            menu.use_steady_shot:render("Steady Shot",       "Primary ranged filler between higher-priority TBC shots.")
            menu.use_aimed_shot:render("Aimed Shot",         "Heavy stationary cast used after mark and sting upkeep.")
            menu.use_arcane_shot:render("Arcane Shot",       "Instant ranged dump used when auto-shot timing is safe.")
            menu.use_multi_shot:render("Multi-Shot",         "AoE dump for dungeon and raid packs when cleave is safe.")
            menu.use_raptor_strike:render("Raptor Strike",   "Melee fallback when trapped in close range.")
            menu.use_mongoose_bite:render("Mongoose Bite",   "Situational melee tool before Raptor Strike when available.")
            menu.use_wing_clip:render("Wing Clip",           "Melee slow used to re-open range for shots and traps.")
        end)

        -- -- Pet ----------------------------------------------------------
        pet_tree:render("Pet Settings", function()
            ps.header("Pet Abilities")
            menu.use_kill_command:render("Kill Command",  "Send Kill Command off-GCD after pet melee attack.")
            ps.header("Pet Autocast")
            menu.sync_pet_autocast:render("Sync Pet Autocast", "Keep pet autocasts aligned conservatively.")
            menu.disable_growl_in_group:render("Disable Growl in Group", "Turn off Growl in dungeon/raid content.")
            ps.header("Pet Health")
            menu.use_mend_pet:render("Mend Pet",         "Channel Mend Pet when pet health is low.")
            menu.mend_pet_hp:render("Mend Pet HP %",     "Mend pet below this health percent.")
            menu.use_revive_pet:render("Pet Recovery",      "Recover your pet out of combat with revive or call pet as needed.")
        end)

        -- -- Cooldowns ----------------------------------------------------
        cd_tree:render("Cooldowns & Aspects", function()
            ps.header("Offensive")
            menu.use_rapid_fire:render("Rapid Fire",      "3-min CD. Used on CD while in combat.")
            menu.use_misdirection:render("Misdirection",  "Dungeon/Raid opener on focus only. Conservative pre-pull threat transfer.")
            ps.header("Aspect of the Viper")
            menu.use_aspect_viper:render("Auto-Viper",    "Switch to Aspect of the Viper when mana is low.")
            menu.viper_mana_enter:render("Enter Viper %", "Switch to Viper below this mana percent.")
            menu.viper_mana_exit:render("Exit Viper %",   "Switch back to Hawk above this mana percent.")
            ps.header("Travel Aspect")
            menu.auto_travel_aspect:render("Auto Travel Aspect", "Cheetah is the default travel aspect when moving OOC.")
            menu.use_pack_as_travel_aspect:render("Use Pack in Group", "Optional Pack only for dungeon/raid travel.")
        end)

        -- -- Kiting & Traps ------------------------------------------------
        kite_tree:render("Kiting & Traps", function()
            ps.header("Kiting")
            menu.use_concussive:render("Concussive Shot", "Slow target when they enter melee range.")
            menu.use_disengage:render("Disengage",        "Escape melee range. Used when target is <= 8 yd.")
            menu.use_deterrence:render("Deterrence",     "Emergency self-defensive cooldown when low HP.")
            menu.deterrence_hp:render("Deterrence HP %", "Trigger Deterrence below this health percent.")
            menu.use_feign_death:render("Feign Death",    "Emergency FD when health is critically low.")
            menu.feign_death_hp:render("Feign Death HP %","Trigger Feign Death below this health percent.")
            ps.header("Traps")
            menu.use_traps:render("Use Traps",             "Drop a trap when the target closes into trap range.")
            menu.use_immolation_trap:render("Immolation Trap", "Preferred sustained damage trap for TBC Survival.")
            menu.use_explosive_trap:render("Explosive Trap",   "Secondary AoE trap option when burst cleave is needed.")
            menu.trap_selection:render("Trap Type",        {"Immolation (Primary DoT)", "Explosive (AoE Burst)", "Freezing (CC)"})
            menu.trap_interval:render("Trap Interval",    "Minimum seconds between trap attempts.")
            ps.header("Utility / CC")
            menu.use_scare_beast:render("Scare Beast",      "Optional focus-based beast CC.")
            menu.use_wyvern_sting:render("Wyvern Sting",     "Optional focus-based Survival CC.")
            menu.use_flare:render("Flare",               "Manual or focus-based flare utility for known stealth locations.")
            ps.header("Anti-Stealth")
            menu.auto_stealth_flare:render("Auto Anti-Stealth Flare", "Auto-drop Flare when stealth is suspected nearby.")
            menu.stealth_warning:render("Stealth Warning", "Warn when stealth is likely within range.")
            menu.stealth_scan_radius:render("Stealth Radius", "Scan radius used for stealth checks.")
            menu.stealth_prediction_s:render("Stealth Prediction", "Prediction window applied to stealth detection.")
            menu.stealth_overlay_enabled:render("Stealth Overlay", "Show a world-space uncertainty ring at the suspected stealth position.")
            menu.stealth_overlay_direction:render("Stealth Direction", "Show a short direction tick when movement prediction is available.")
        end)

        ps.render_defensive(menu, def_tree, {})
        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
        ooc_tree:render("Out of Combat", function()
            ps.header("Sustain")
            menu.ooc_drink:render("Auto-Drink", "Drink to restore mana when out of combat")
            menu.drink_threshold:render("Drink Threshold %", "Start drinking below this mana percent")
            menu.ooc_eat:render("Auto-Eat", "Eat food to restore health when out of combat")
            menu.eat_threshold:render("Eat Threshold %", "Start eating below this health percent")

            ps.header("Group")
            menu.ooc_rez:render("Auto-Resurrect", "Accept and cast resurrection when out of combat")
            menu.ooc_group_buff:render("Group Buffs", "Apply class buffs to party members between pulls")

            ps.header("Automation")
            menu.auto_repair:render("Auto Repair", "Automatically repair gear at vendors")
            menu.auto_sell_greys:render("Auto Sell Greys", "Automatically sell poor-quality items at vendors")
            menu.auto_mount:render("Auto Mount", "Automatically mount when traveling out of combat")
            menu.auto_dismount:render("Auto Dismount", "Automatically dismount when entering combat")
            menu.auto_combat_potions:render("Auto Combat Potions", "Use combat potions automatically when appropriate")
            menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")

            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Use a more mana-efficient leveling rotation")
            menu.leveling_mana_floor:render("Mana Floor %", "Switch to conservation mode below this mana percent")
        end)
        ps.render_esp(menu, esp_tree)
    end)
end

return menu
