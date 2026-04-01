-- +--------------------------------------------------------------------------+
-- |  Eax Druid Feral  -  Class-Driven Menu  v2.0  -  menu.lua              |
-- |                                                                          |
-- |  Replaces ps_theme with class_theme for full Druid Feral identity.      |
-- |  Nature orange palette - shapeshifter particle field - form-aware UI    |
-- +--------------------------------------------------------------------------+

local theme    = require("libraries/class_theme")
local identity = require("libraries/class_identity")
local settings = require("libraries/settings_framework")

-- -- Init theme for Druid Feral ---------------------------------------------
-- class_id 11 = Druid, spec_id 26 = Druid Feral Cat (used as default)
-- The HUD switches spec_id dynamically based on current form.
theme.init(identity.CLASS_IDS.DRUID, identity.SPEC_IDS.DRUID_FERAL_CAT)

local menu = {}

-- -- Tree nodes (declared outside render, as per API requirements) -------------
local root_tree     = theme.tree_node()
local rotation_tree = theme.tree_node()
local cat_tree      = theme.tree_node()
local bear_tree     = theme.tree_node()
local guardian_tree = theme.tree_node()
local shared_tree   = theme.tree_node()
local auto_tree     = theme.tree_node()
local ooc_tree      = theme.tree_node()
local group_tree    = theme.tree_node()
local def_tree      = theme.tree_node()
local tgt_tree      = theme.tree_node()
local racial_tree   = theme.tree_node()
local esp_tree      = theme.tree_node()

-- -- Controls ------------------------------------------------------------------
menu.enabled         = core.menu.checkbox(true,  "eaxdruidferal_enabled")
menu.toggle_key      = core.menu.keybind(7, false, "eaxdruidferal_toggle_key")
menu.mode            = core.menu.combobox(1, "eaxdruidferal_mode")
menu.debug           = core.menu.checkbox(false, "eaxdruidferal_debug")

-- -- Targeting ------------------------------------------------------------------
menu.focus_priority        = core.menu.checkbox(false, "eaxdruidferal_focus_priority")
menu.combat_self_hp_boost  = core.menu.slider_int(0, 30, 10, "eaxdruidferal_combat_self_hp_boost")

-- -- Racial --------------------------------------------------------------------
menu.use_racial  = core.menu.checkbox(true, "eaxdruidferal_use_racial")
menu.racial_hp   = core.menu.slider_int(10, 80, 40, "eaxdruidferal_racial_hp")

-- -- OOC -----------------------------------------------------------------------
menu.ooc_drink        = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat          = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez          = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff   = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold  = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold    = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- -- Automation ----------------------------------------------------------------
-- menu.auto_combat_potions = core.menu.checkbox(false, "eaxdruidferal_auto_combat_potions")
menu.auto_ooc_food_drink = core.menu.checkbox(true, "eaxdruidferal_auto_ooc_food_drink")
menu.auto_flask          = core.menu.checkbox(false, "eaxdruidferal_auto_flask")

-- -- Leveling ------------------------------------------------------------------
menu.leveling_conserve_mana = core.menu.checkbox(true, "eaxdruidferal_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxdruidferal_lev_mana_floor")

-- -- Cat Form ------------------------------------------------------------------
menu.use_prowl              = core.menu.checkbox(true, "eaxdruidferal_use_prowl")
menu.use_pounce             = core.menu.checkbox(true, "eaxdruidferal_use_pounce")
menu.use_ravage             = core.menu.checkbox(true, "eaxdruidferal_use_ravage")
menu.use_faerie_fire        = core.menu.checkbox(true, "eaxdruidferal_use_faerie_fire")
menu.use_likely_shred       = core.menu.checkbox(true, "eaxdruidferal_use_likely_shred")
menu.use_mangle_cat         = core.menu.checkbox(true, "eaxdruidferal_use_mangle_cat")
menu.use_rake               = core.menu.checkbox(true, "eaxdruidferal_use_rake")
menu.rake_refresh_seconds   = core.menu.slider_int(1, 10, 3, "eaxdruidferal_rake_refresh_seconds")
menu.use_shred              = core.menu.checkbox(true, "eaxdruidferal_use_shred")
menu.use_claw               = core.menu.checkbox(true, "eaxdruidferal_use_claw")
menu.use_rip                = core.menu.checkbox(true, "eaxdruidferal_use_rip")
menu.rip_combo_points       = core.menu.slider_int(1, 5, 4, "eaxdruidferal_rip_combo_points")
menu.rip_refresh_seconds    = core.menu.slider_int(1, 10, 3, "eaxdruidferal_rip_refresh_seconds")
menu.use_ferocious_bite     = core.menu.checkbox(true, "eaxdruidferal_use_ferocious_bite")
menu.bite_killshot_hp_pct   = core.menu.slider_int(5, 30, 15, "eaxdruidferal_bite_killshot_hp_pct")
menu.use_maim               = core.menu.checkbox(true, "eaxdruidferal_use_maim")
menu.use_tigers_fury        = core.menu.checkbox(true, "eaxdruidferal_use_tigers_fury")
menu.tigers_fury_energy     = core.menu.slider_int(20, 60, 30, "eaxdruidferal_tigers_fury_energy")
menu.use_powershift         = core.menu.checkbox(true, "eaxdruidferal_use_powershift")

-- -- Bear Form -----------------------------------------------------------------
menu.use_mangle_bear        = core.menu.checkbox(true, "eaxdruidferal_use_mangle_bear")
menu.use_lacerate           = core.menu.checkbox(true, "eaxdruidferal_use_lacerate")
menu.use_demoralizing_roar  = core.menu.checkbox(true, "eaxdruidferal_use_demoralizing_roar")
menu.use_swipe              = core.menu.checkbox(true, "eaxdruidferal_use_swipe")
menu.swipe_enemy_count      = core.menu.slider_int(2, 8, 3, "eaxdruidferal_swipe_enemy_count")
menu.use_maul               = core.menu.checkbox(true, "eaxdruidferal_use_maul")
menu.maul_min_rage          = core.menu.slider_int(10, 50, 25, "eaxdruidferal_maul_min_rage")

-- -- Guardian ------------------------------------------------------------------
menu.use_frenzied_regeneration = core.menu.checkbox(true, "eaxdruidferal_use_frenzied_regeneration")
menu.frenzied_regeneration_hp_pct = core.menu.slider_int(10, 50, 25, "eaxdruidferal_frenzied_regeneration_hp_pct")
menu.auto_growl                = core.menu.checkbox(true, "eaxdruidferal_auto_growl")
menu.tank_cd_overlap           = core.menu.checkbox(false, "eaxdruidferal_tank_cd_overlap")
menu.use_enrage                = core.menu.checkbox(true, "eaxdruidferal_use_enrage")
menu.enrage_rage_threshold     = core.menu.slider_int(0, 40, 10, "eaxdruidferal_enrage_rage_threshold")
menu.use_challenging_roar      = core.menu.checkbox(true, "eaxdruidferal_use_challenging_roar")
menu.challenging_roar_party_hp_pct = core.menu.slider_int(10, 50, 25, "eaxdruidferal_challenging_roar_party_hp_pct")
menu.guardian_swipe_enemy_count = core.menu.slider_int(2, 8, 3, "eaxdruidferal_guardian_swipe_enemy_count")

-- -- Shared / Utility ----------------------------------------------------------
menu.use_feral_charge       = core.menu.checkbox(true, "eaxdruidferal_use_feral_charge")
menu.use_travel_form        = core.menu.checkbox(true, "eaxdruidferal_use_travel_form")
menu.use_root_escape        = core.menu.checkbox(true, "eaxdruidferal_use_root_escape")
menu.use_bash               = core.menu.checkbox(true, "eaxdruidferal_use_bash")
menu.use_cyclone            = core.menu.checkbox(true, "eaxdruidferal_use_cyclone")
menu.use_entangling_roots   = core.menu.checkbox(true, "eaxdruidferal_use_entangling_roots")
menu.use_war_stomp          = core.menu.checkbox(true, "eaxdruidferal_use_war_stomp")
menu.war_stomp_hp_pct       = core.menu.slider_int(10, 50, 25, "eaxdruidferal_war_stomp_hp_pct")
menu.war_stomp_attackers    = core.menu.slider_int(2, 6, 3, "eaxdruidferal_war_stomp_attackers")

-- -- Defensive -----------------------------------------------------------------
menu.use_barkskin           = core.menu.checkbox(true, "eaxdruidferal_use_barkskin")
menu.barkskin_hp_pct        = core.menu.slider_int(10, 60, 30, "eaxdruidferal_barkskin_hp_pct")
menu.use_innervate          = core.menu.checkbox(true, "eaxdruidferal_use_innervate")
menu.innervate_mana_pct     = core.menu.slider_int(10, 60, 30, "eaxdruidferal_innervate_mana_pct")
menu.use_ooc_self_heal      = core.menu.checkbox(true, "eaxdruidferal_use_ooc_self_heal")
menu.ooc_self_heal_hp_pct   = core.menu.slider_int(20, 80, 50, "eaxdruidferal_ooc_self_heal_hp_pct")
menu.use_abolish_poison     = core.menu.checkbox(true, "eaxdruidferal_use_abolish_poison")
menu.use_remove_curse       = core.menu.checkbox(true, "eaxdruidferal_use_remove_curse")
menu.use_natures_grasp      = core.menu.checkbox(true, "eaxdruidferal_use_natures_grasp")

-- -- Form Management -----------------------------------------------------------
menu.lane       = core.menu.combobox(1, "eaxdruidferal_lane")
menu.auto_form  = core.menu.checkbox(true, "eaxdruidferal_auto_form")
menu.shift_mana_floor = core.menu.slider_int(10, 50, 20, "eaxdruidferal_shift_mana_floor")

-- -- Window --------------------------------------------------------------------
settings.setup_major_toggle_keybinds(menu, {
    { toggle = "use_mangle_cat", label = "Mangle (Cat)" },
    { toggle = "use_shred", label = "Shred" },
    { toggle = "use_rip", label = "Rip" },
    { toggle = "use_mangle_bear", label = "Mangle (Bear)" },
    { toggle = "use_frenzied_regeneration", label = "Frenzied Regen" },
}, {
    namespace = "eaxdruidferal",
    log_prefix = "[Eax Feral] ",
})

local _win
function menu.set_window(win) _win = win end

-- -- RENDER --------------------------------------------------------------------
function menu.render()
    -- Apply class theme background decorations when tree is open
    if _win and root_tree:is_open() then
        pcall(function() theme.apply(_win, "eaxdruidferal") end)
    end

    root_tree:render("Eax's Druid Feral", function()

        -- Identity banner
        do
            local h1 = core.menu.header()
            h1:render("DRUID - Feral Shapeshifter", theme.col_spec_primary())
            local h2 = core.menu.header()
            h2:render("One with Nature", theme.col_accent())
        end

        -- Controls
        theme.header("Controls")
        menu.enabled:render("Enabled", "Master enable/disable")
        menu.toggle_key:render("Toggle Key", "Keybind to toggle rotation")
        menu.mode:render("Mode", theme.MODE)
        menu.debug:render("Debug Logging", "Verbose debug output")

        -- Form Management
        rotation_tree:render("Form Management", function()
            theme.header("Shapeshifting")
            menu.lane:render("Active Lane", theme.LANE)
            menu.auto_form:render("Auto Form", "Automatically switch forms based on combat situation")
            menu.shift_mana_floor:render("Shift Mana Floor %", "Don't shift below this mana percent")
        end)

        -- Cat Form
        cat_tree:render("Cat Form", function()
            theme.header("Stealth")
            menu.use_prowl:render("Prowl", "Enter stealth when safe")
            menu.use_pounce:render("Pounce", "Stealth opener stun")
            menu.use_ravage:render("Ravage", "Stealth opener damage")

            theme.header("Builder")
            menu.use_faerie_fire:render("Faerie Fire (Feral)", "Armor reduction debuff")
            menu.use_likely_shred:render("Likely Shred", "Use Shred when behind target")
            menu.use_mangle_cat:render("Mangle (Cat)", "Maintain Mangle debuff")
            menu.use_rake:render("Rake", "Maintain Rake DoT")
            menu.rake_refresh_seconds:render("Rake Refresh (sec)", "Refresh Rake when remaining time is below this value")
            menu.use_shred:render("Shred", "Main damage when behind")
            menu.use_claw:render("Claw", "Combo point builder when Shred unavailable")

            theme.header("Finisher")
            menu.use_rip:render("Rip", "Maintain Rip DoT")
            menu.rip_combo_points:render("Rip Combo Points", "Minimum combo points for Rip")
            menu.rip_refresh_seconds:render("Rip Refresh (sec)", "Refresh Rip when remaining time is below this value")
            menu.use_ferocious_bite:render("Ferocious Bite", "Execute finisher")
            menu.bite_killshot_hp_pct:render("Killshot HP %", "Use Ferocious Bite below this target HP percent")
            menu.use_maim:render("Maim (interrupt)", "Use Maim as interrupt finisher")

            theme.header("Energy")
            menu.use_tigers_fury:render("Tiger's Fury", "Energy cooldown")
            menu.tigers_fury_energy:render("Tiger's Fury Energy", "Use Tiger's Fury below this energy")
            menu.use_powershift:render("Powershift (Wolfshead)", "Powershift for energy with Wolfshead Helm")
        end)

        -- Bear Form
        bear_tree:render("Bear Form", function()
            theme.header("Threat")
            menu.use_mangle_bear:render("Mangle (Bear)", "Main threat ability")
            menu.use_lacerate:render("Lacerate", "Maintain Lacerate stacks")
            menu.use_demoralizing_roar:render("Demoralizing Roar", "Attack power reduction")
            menu.use_swipe:render("Swipe", "AoE threat")
            menu.swipe_enemy_count:render("Swipe Enemy Count", "Use Swipe above this enemy count")
            menu.use_maul:render("Maul", "Rage dump")
            menu.maul_min_rage:render("Maul Min Rage", "Minimum rage to use Maul")
        end)

        -- Guardian
        guardian_tree:render("Guardian", function()
            theme.header("Defensive")
            menu.use_frenzied_regeneration:render("Frenzied Regen", "Self-heal cooldown")
            menu.frenzied_regeneration_hp_pct:render("Frenzied Regen HP %", "Use below this health percent")
            menu.auto_growl:render("Auto Growl", "Auto-taunt when losing threat")
            menu.tank_cd_overlap:render("Allow CD Overlap", "Allow defensive cooldowns to overlap")
            menu.use_enrage:render("Enrage", "Rage generation cooldown")
            menu.enrage_rage_threshold:render("Enrage Rage Threshold", "Use Enrage below this rage")
            menu.use_challenging_roar:render("Challenging Roar", "AoE taunt")
            menu.challenging_roar_party_hp_pct:render("Challenging Roar Party HP %", "Use when party members below this HP")
            menu.guardian_swipe_enemy_count:render("Guardian Swipe Count", "Swipe threshold in Guardian mode")
        end)

        -- Shared / Utility
        shared_tree:render("Shared / Utility", function()
            theme.header("Mobility")
            menu.use_feral_charge:render("Feral Charge / Dash", "Gap closer / escape")
            menu.use_travel_form:render("Travel Form OOC", "Use Travel Form when out of combat")
            menu.use_root_escape:render("Root Escape", "Shift to break roots")

            theme.header("CC")
            menu.use_bash:render("Bash", "Bear stun")
            menu.use_cyclone:render("Cyclone", "CC")
            menu.use_entangling_roots:render("Entangling Roots", "Root")
            menu.use_war_stomp:render("War Stomp (Tauren)", "Racial stun")
            menu.war_stomp_hp_pct:render("War Stomp HP %", "Use below this HP")
            menu.war_stomp_attackers:render("War Stomp Attacker Count", "Use above this attacker count")
        end)

        -- Defensive
        def_tree:render("Defensive", function()
            menu.use_barkskin:render("Barkskin", "Damage reduction cooldown")
            menu.barkskin_hp_pct:render("Barkskin HP %", "Use below this health percent")
            menu.use_innervate:render("Innervate", "Mana recovery")
            menu.innervate_mana_pct:render("Innervate Mana %", "Use below this mana percent")
            menu.use_ooc_self_heal:render("OOC Self-Heal", "Heal out of combat")
            menu.ooc_self_heal_hp_pct:render("OOC Self-Heal HP %", "Heal below this HP")
            menu.use_abolish_poison:render("Abolish Poison", "Dispel poison")
            menu.use_remove_curse:render("Remove Curse", "Dispel curse")
            menu.use_natures_grasp:render("Nature's Grasp", "Root on melee hit")
        end)

        -- Targeting
        theme.render_targeting(menu, tgt_tree)

        -- Racial
        theme.render_racial(menu, racial_tree)

        -- Out-of-combat
        ooc_tree:render("Out of Combat", function()
            theme.header("Sustain")
            menu.ooc_drink:render("Auto-Drink", "Drink to restore mana when out of combat")
            menu.drink_threshold:render("Drink Threshold %", "Start drinking below this mana percent")
            menu.ooc_eat:render("Auto-Eat", "Eat food to restore health when out of combat")
            menu.eat_threshold:render("Eat Threshold %", "Start eating below this health percent")

            theme.header("Group")
            menu.ooc_rez:render("Auto-Resurrect", "Accept and cast resurrection when out of combat")
            menu.ooc_group_buff:render("Group Buffs", "Apply class buffs to party members between pulls")

            theme.header("Automation")
            menu.auto_ooc_food_drink:render("Auto OOC Food / Drink", "Use food and drink out of combat when health or mana is low")
            menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")

            theme.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Use a more mana-efficient leveling rotation")
            menu.leveling_mana_floor:render("Mana Floor %", "Switch to conservation mode below this mana percent")
        end)

    end)
end

return menu
