-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Warrior Protection
-- ║  Space Theme v4.0  ·  Stars drawn inside the panel background
-- ╚══════════════════════════════════════════════════════════════════╝

local ps   = require("ps_theme")
local menu = {}

-- ── Tree nodes ────────────────────────────────────────────────────────────────
local root_tree    = ps.tree_node()
local main_tree    = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local ooc_tree     = ps.tree_node()
local esp_tree     = ps.tree_node()

-- ── Shared plugin controls + shared fields ────────────────────────────────────
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxwarriorprotection_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxwarriorprotection_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxwarriorprotection_mode")
menu.debug                               = core.menu.checkbox(false, "eaxwarriorprotection_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxwarriorprotection_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxwarriorprotection_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxwarriorprotection_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxwarriorprotection_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxwarriorprotection_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxwarriorprotection_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- ── Class-specific elements ───────────────────────────────────────────────────
menu.use_shield_slam                      = core.menu.checkbox(true, "simpleprot_use_shield_slam")
menu.use_revenge                          = core.menu.checkbox(true, "simpleprot_use_revenge")
menu.use_devastate                        = core.menu.checkbox(true, "simpleprot_use_devastate")
menu.use_heroic_strike                    = core.menu.checkbox(true, "simpleprot_use_heroic_strike")
menu.use_cleave                           = core.menu.checkbox(true, "simpleprot_use_cleave")
menu.use_execute                          = core.menu.checkbox(false, "simpleprot_use_execute")
menu.use_battle_shout                     = core.menu.checkbox(false, "simpleprot_use_battle_shout")
menu.use_commanding_shout                 = core.menu.checkbox(true, "simpleprot_use_commanding_shout")
menu.use_bloodrage                        = core.menu.checkbox(true, "simpleprot_use_bloodrage")
menu.show_notifications                   = core.menu.checkbox(false, "simpleprot_show_notifications")
menu.use_prepull_bloodrage                = core.menu.checkbox(true, "simpleprot_use_prepull_bloodrage")
menu.use_demo_shout                       = core.menu.checkbox(true, "simpleprot_use_demo_shout")
menu.use_thunder_clap                     = core.menu.checkbox(true, "simpleprot_use_thunder_clap")
menu.use_sunder_armor                     = core.menu.checkbox(false, "simpleprot_use_sunder_armor")
menu.sunder_max_stacks                    = core.menu.slider_int(1, 5, 5, "simpleprot_sunder_max_stacks")
menu.use_rend                             = core.menu.checkbox(false, "simpleprot_use_rend")
menu.use_hamstring                        = core.menu.checkbox(false, "simpleprot_use_hamstring")
menu.use_intercept                        = core.menu.checkbox(true, "simpleprot_use_intercept")
menu.intercept_min_range                  = core.menu.slider_int(8, 25, 10, "simpleprot_intercept_min_range")
menu.auto_peel                            = core.menu.checkbox(true, "simpleprot_auto_peel")
menu.use_taunt                            = core.menu.checkbox(true, "simpleprot_use_taunt")
menu.use_shield_bash                      = core.menu.checkbox(true, "simpleprot_use_shield_bash")
menu.use_concussion_blow                  = core.menu.checkbox(true, "simpleprot_use_concussion_blow")
menu.use_mocking_blow                     = core.menu.checkbox(true, "simpleprot_use_mocking_blow")
menu.use_challenging_shout                = core.menu.checkbox(false, "simpleprot_use_challenging_shout")
menu.use_peel_intercept                   = core.menu.checkbox(false, "simpleprot_use_peel_intercept")
menu.use_shield_block                     = core.menu.checkbox(true, "simpleprot_use_shield_block")
menu.use_last_stand                       = core.menu.checkbox(true, "simpleprot_use_last_stand")
menu.last_stand_hp_pct                    = core.menu.slider_int(10, 50, 20, "simpleprot_last_stand_hp_pct")
menu.use_shield_wall                      = core.menu.checkbox(true, "simpleprot_use_shield_wall")
menu.shield_wall_hp_pct                   = core.menu.slider_int(10, 50, 25, "simpleprot_shield_wall_hp_pct")
menu.use_spell_reflection                 = core.menu.checkbox(true, "simpleprot_use_spell_reflection")
menu.spell_reflection_progress_pct        = core.menu.slider_int(0, 90, 50, "simpleprot_spell_reflection_progress_pct")
menu.use_healthstone                      = core.menu.checkbox(false, "simpleprot_use_healthstone")
menu.healthstone_hp_pct                   = core.menu.slider_int(10, 50, 25, "simpleprot_healthstone_hp_pct")
menu.use_health_potion                    = core.menu.checkbox(true, "simpleprot_use_health_potion")
menu.health_potion_hp_pct                 = core.menu.slider_int(10, 50, 25, "simpleprot_health_potion_hp_pct")
menu.use_ironshield_potion                = core.menu.checkbox(true, "simpleprot_use_ironshield_potion")
menu.use_stoneform                        = core.menu.checkbox(true, "simpleprot_use_stoneform")
menu.stoneform_hp_pct                     = core.menu.slider_int(20, 80, 40, "simpleprot_stoneform_hp_pct")
menu.use_death_wish                       = core.menu.checkbox(true, "simpleprot_use_death_wish")
menu.use_recklessness                     = core.menu.checkbox(true, "simpleprot_use_recklessness")
menu.use_blood_fury                       = core.menu.checkbox(true, "simpleprot_use_blood_fury")
menu.use_berserking                       = core.menu.checkbox(true, "simpleprot_use_berserking")
menu.use_trinkets                         = core.menu.checkbox(true, "simpleprot_use_trinkets")
menu.use_war_stomp_interrupt              = core.menu.checkbox(true, "simpleprot_use_war_stomp_interrupt")
menu.intimidating_shout_key               = core.menu.keybind(7, false, "simpleprot_intimidating_shout_key")
menu.use_disarm                           = core.menu.checkbox(true, "simpleprot_use_disarm")
menu.use_berserker_rage                   = core.menu.checkbox(true, "simpleprot_use_berserker_rage")
menu.use_retaliation                      = core.menu.checkbox(false, "simpleprot_use_retaliation")
menu.heroic_strike_rage                   = core.menu.slider_int(20, 100, 50, "simpleprot_hs_rage")
menu.cleave_rage                          = core.menu.slider_int(20, 100, 45, "simpleprot_cleave_rage")
menu.heroic_strike_rage_cap               = core.menu.slider_int(60, 100, 90, "simpleprot_hs_rage_cap")
menu.aoe_enemy_count                      = core.menu.slider_int(2, 10, 3, "simpleprot_aoe_count")
menu.execute_min_rage                     = core.menu.slider_int(15, 80, 31, "simpleprot_execute_min_rage")

-- ════════════════════════════════════════════════════════════════════════════
-- RENDER  — called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ════════════════════════════════════════════════════════════════════════════

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxwarriorprotection")
    end

    root_tree:render("  Eax's Warrior Protection", function()

        ps.render_controls(menu, "Eax's Warrior Protection")

        -- ── Class-specific settings ───────────────────────────────────────────
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.use_shield_slam:render("Shield Slam", "Use Shield Slam on cooldown")
            menu.use_revenge:render("Revenge", "Use Revenge when proc is available")
            menu.use_devastate:render("Devastate", "Use Devastate as filler")
            menu.use_heroic_strike:render("Heroic Strike", "Queue Heroic Strike as threat dump")
            menu.use_cleave:render("Cleave", "Queue Cleave as AoE threat dump")
            menu.use_execute:render("Execute", "Use Execute below 20% HP")
            menu.use_battle_shout:render("Battle Shout", "Allow Battle Shout as the upkeep fallback when Commanding is disabled or unavailable")
            menu.use_commanding_shout:render("Commanding Shout", "Prefer Commanding Shout upkeep; if off, Battle Shout can be used when enabled")
            menu.use_bloodrage:render("Bloodrage", "Use Bloodrage when rage is low")
            menu.show_notifications:render("Notifications", "Show short on-screen flashes")
            menu.use_prepull_bloodrage:render("Pre-pull Bloodrage", "Use Bloodrage before combat")
            menu.use_demo_shout:render("Demo Shout", "Maintain Demoralizing Shout")
            menu.use_thunder_clap:render("Thunder Clap", "Use Thunder Clap for AoE threat")
            menu.use_sunder_armor:render("Sunder Armor", "Maintain Sunder Armor stacks")
            menu.sunder_max_stacks:render("Sunder Max Stacks", "Maximum Sunder Armor stacks")
            menu.use_rend:render("Rend", "Apply Rend to target")
            menu.use_hamstring:render("Hamstring", "Low-priority filler used only in solo mode")
            menu.use_intercept:render("Intercept", "Solo-only in-combat gap closer that temporarily swaps to Berserker Stance, Intercepts, then returns home")
            menu.intercept_min_range:render("Intercept Min Range", "Minimum range for Intercept")
            menu.auto_peel:render("Auto Peel", "Scan for off-target threats in dungeon and raid modes without changing your HUD target")
            menu.use_taunt:render("Taunt", "Dungeon/Raid automatic threat recovery when the current or recovery target is not on you")
            menu.use_shield_bash:render("Shield Bash", "Primary automatic interrupt on current and recovery targets")
            menu.use_concussion_blow:render("Concussion Blow", "Stun dangerous casters when Shield Bash cannot be used")
            menu.use_mocking_blow:render("Mocking Blow", "Dungeon/Raid fallback threat recovery tool when Taunt is unavailable")
            menu.use_challenging_shout:render("Challenging Shout", "Group-mode only rare AoE recovery tool for multi-mob threat losses")
            menu.use_peel_intercept:render("Peel Intercept", "Dungeon-only opt-in peel Intercept for healer or DPS rescue targets")
            menu.use_shield_block:render("Shield Block", "Solo uses Shield Block as emergency or elite mitigation; dungeon and raid use it proactively under real tank pressure")
            menu.use_spell_reflection:render("Spell Reflection", "Reflect incoming spell casts")
            menu.spell_reflection_progress_pct:render("Spell Reflection Cast %", "Wait until enemy cast is this % complete before reflecting (avoids wasting on cancelled casts)")
            menu.use_healthstone:render("Healthstone", "Use Healthstone at low HP")
            menu.healthstone_hp_pct:render("Healthstone HP %", "HP threshold for Healthstone")
            menu.use_health_potion:render("Health Potion", "Use a healing potion at low HP")
            menu.health_potion_hp_pct:render("Health Potion HP %", "HP threshold for Health Potion")
            menu.use_ironshield_potion:render("Ironshield Potion", "Solo uses Ironshield Potion only under heavy pressure or elite windows; dungeon and raid use it under tank pressure")
            menu.use_stoneform:render("Stoneform", "Use Stoneform in combat at low HP")
            menu.stoneform_hp_pct:render("Stoneform HP %", "HP threshold for Stoneform")
            menu.use_death_wish:render("Death Wish", "Use Death Wish during burst; suppressed automatically in dungeon and raid modes")
            menu.use_recklessness:render("Recklessness", "Use Recklessness during burst; suppressed automatically in dungeon and raid modes")
            menu.use_blood_fury:render("Blood Fury", "Use Blood Fury during safe burst windows")
            menu.use_berserking:render("Berserking", "Use Troll Berserking during safe burst windows")
            menu.use_trinkets:render("Trinkets", "Use ready self-cast trinkets during safe burst windows")
            menu.use_war_stomp_interrupt:render("War Stomp Interrupt", "Use War Stomp as interrupt")
            menu.intimidating_shout_key:render("Intimidating Shout Key", "Manual panic key")
            menu.use_disarm:render("Disarm", "Solo: disarm melee enemies for strong mitigation")
            menu.use_berserker_rage:render("Berserker Rage", "Use Berserker Rage to break fears and generate extra rage on crits")
            menu.use_retaliation:render("Retaliation", "Solo burst: Battle Stance cooldown that reflects melee attacks")
            menu.heroic_strike_rage:render("HS Min Rage", "Minimum rage to queue Heroic Strike")
            menu.cleave_rage:render("Cleave Min Rage", "Minimum rage to queue Cleave")
            menu.heroic_strike_rage_cap:render("HS Rage Cap Dump", "Force-queue Heroic Strike when rage exceeds this value regardless of swing window")
            menu.aoe_enemy_count:render("AoE Threshold", "Number of enemies for AoE mode")
            menu.execute_min_rage:render("Execute Min Rage", "Minimum rage to use Execute (rage above cost is consumed for bonus damage)")
        end)

        -- ── Defensive cooldowns ───────────────────────────────────────────────
        ps.render_defensive(menu, def_tree, {
        { key = "use_last_stand", label = "Last Stand", tip = "Use Last Stand as an emergency cooldown", hp_key = "last_stand_hp_pct", hp_label = "Last Stand Hp Percent" },
        { key = "use_shield_wall", label = "Shield Wall", tip = "Use Shield Wall as an emergency cooldown", hp_key = "shield_wall_hp_pct", hp_label = "Shield Wall Hp Percent" },
        })

        -- ── Targeting ────────────────────────────────────────────────────────
        ps.render_targeting(menu, tgt_tree)

        -- ── Racial ────────────────────────────────────────────────────────────
        ps.render_racial(menu, racial_tree)

        -- ── Out-of-combat ─────────────────────────────────────────────────────
        ps.render_ooc(menu, ooc_tree, false)

        -- ── Display & HUD ─────────────────────────────────────────────────────
        ps.render_esp(menu, esp_tree)

    end)
end

return menu
