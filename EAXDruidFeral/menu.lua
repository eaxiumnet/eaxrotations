-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Druid Feral
-- ║  Space Theme v4.0  ·  Stars drawn inside the panel background
-- ╚══════════════════════════════════════════════════════════════════╝

local ps   = require("ps_theme")
local menu = {}

-- -- Tree nodes ----------------------------------------------------------------
local root_tree    = ps.tree_node()
local main_tree    = ps.tree_node()
local cat_tree     = ps.tree_node()
local bear_tree    = ps.tree_node()
local guardian_tree = ps.tree_node()
local shared_tree  = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local ooc_tree     = ps.tree_node()
local esp_tree     = ps.tree_node()

-- -- Shared plugin controls + shared fields ------------------------------------
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxdruidferal_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxdruidferal_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxdruidferal_mode")
menu.debug                               = core.menu.checkbox(false, "eaxdruidferal_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxdruidferal_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxdruidferal_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxdruidferal_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxdruidferal_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxdruidferal_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxdruidferal_lev_mana_floor")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.lane                                 = core.menu.combobox(1, "eaxdruidferal_lane")

-- Guardian / Tank settings
menu.use_survival_instincts               = core.menu.checkbox(true,  "eaxdruidferal_use_survival_instincts")
menu.survival_instincts_hp_pct            = core.menu.slider_int(10, 60, 35, "eaxdruidferal_survival_instincts_hp")
menu.use_enrage                           = core.menu.checkbox(true,  "eaxdruidferal_use_enrage")
menu.enrage_rage_threshold                = core.menu.slider_int(0, 40, 15, "eaxdruidferal_enrage_rage")
menu.use_challenging_roar                 = core.menu.checkbox(true,  "eaxdruidferal_use_challenging_roar")
menu.challenging_roar_party_hp_pct        = core.menu.slider_int(20, 90, 75, "eaxdruidferal_challenging_roar_party_hp")
menu.tank_cd_overlap                      = core.menu.checkbox(false, "eaxdruidferal_tank_cd_overlap")

menu.use_root_escape                     = core.menu.checkbox(true, "eaxdruidferal_root_escape")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxdruidferal_remove_curse")
menu.use_powershift                      = core.menu.checkbox(false, "eaxdruidferal_use_powershift")
menu.auto_form                            = core.menu.checkbox(true, "eaxdruidferal_auto_form")
menu.shift_mana_floor                     = core.menu.slider_int(0, 50, 20, "eaxdruidferal_shift_mana_floor")
menu.use_faerie_fire                      = core.menu.checkbox(true, "eaxdruidferal_use_faerie_fire")
menu.use_mangle_cat                       = core.menu.checkbox(true, "eaxdruidferal_use_mangle_cat")
menu.use_rake                             = core.menu.checkbox(true, "eaxdruidferal_use_rake")
menu.use_shred                            = core.menu.checkbox(true, "eaxdruidferal_use_shred")
menu.use_rip                              = core.menu.checkbox(true, "eaxdruidferal_use_rip")
menu.use_ferocious_bite                   = core.menu.checkbox(true, "eaxdruidferal_use_ferocious_bite")
menu.use_tigers_fury                      = core.menu.checkbox(true, "eaxdruidferal_use_tigers_fury")
menu.rake_refresh_seconds                 = core.menu.slider_int(1, 5, 3, "eaxdruidferal_rake_refresh_seconds")
menu.rip_refresh_seconds                  = core.menu.slider_int(1, 5, 3, "eaxdruidferal_rip_refresh_seconds")
menu.rip_combo_points                     = core.menu.slider_int(3, 5, 5, "eaxdruidferal_rip_combo_points")
menu.bite_killshot_hp_pct                 = core.menu.slider_int(5, 60, 30, "eaxdruidferal_bite_killshot_hp_pct")
menu.tigers_fury_energy                   = core.menu.slider_int(10, 60, 30, "eaxdruidferal_tigers_fury_energy")
menu.use_prowl                            = core.menu.checkbox(true, "eaxdruidferal_use_prowl")
menu.use_pounce                           = core.menu.checkbox(true, "eaxdruidferal_use_pounce")
menu.use_ravage                           = core.menu.checkbox(true, "eaxdruidferal_use_ravage")
menu.use_feral_charge                     = core.menu.checkbox(true, "eaxdruidferal_use_feral_charge")
menu.use_bash                             = core.menu.checkbox(true, "eaxdruidferal_use_bash")
menu.use_travel_form                      = core.menu.checkbox(true, "eaxdruidferal_use_travel_form")
menu.use_abolish_poison                   = core.menu.checkbox(true, "eaxdruidferal_use_abolish_poison")
menu.use_natures_grasp                    = core.menu.checkbox(false, "eaxdruidferal_use_natures_grasp")
menu.use_barkskin                         = core.menu.checkbox(true, "eaxdruidferal_use_barkskin")
menu.use_innervate                        = core.menu.checkbox(true, "eaxdruidferal_use_innervate")
menu.innervate_mana_pct                   = core.menu.slider_int(10, 60, 30, "eaxdruidferal_innervate_mana_pct")
menu.barkskin_hp_pct                      = core.menu.slider_int(10, 60, 40, "eaxdruidferal_barkskin_hp_pct")
menu.use_mangle_bear                      = core.menu.checkbox(true, "eaxdruidferal_use_mangle_bear")
menu.use_lacerate                         = core.menu.checkbox(true, "eaxdruidferal_use_lacerate")
menu.use_demoralizing_roar                = core.menu.checkbox(true, "eaxdruidferal_use_demoralizing_roar")
menu.use_maul                             = core.menu.checkbox(true, "eaxdruidferal_use_maul")
menu.use_swipe                            = core.menu.checkbox(true, "eaxdruidferal_use_swipe")
menu.auto_growl                           = core.menu.checkbox(true, "eaxdruidferal_auto_growl")
menu.use_frenzied_regeneration            = core.menu.checkbox(true, "eaxdruidferal_use_frenzied_regeneration")
menu.use_berserk                          = core.menu.checkbox(true, "eaxdruidferal_use_berserk")
menu.use_maim                             = core.menu.checkbox(false, "eaxdruidferal_use_maim")
menu.use_claw                             = core.menu.checkbox(true, "eaxdruidferal_use_claw")
menu.swipe_enemy_count                    = core.menu.slider_int(2, 6, 3, "eaxdruidferal_swipe_enemy_count")
menu.guardian_swipe_enemy_count           = core.menu.slider_int(1, 4, 2, "eaxdruidferal_guardian_swipe_enemy_count")
menu.use_war_stomp                        = core.menu.checkbox(false, "eaxdruidferal_use_war_stomp")
menu.war_stomp_hp_pct                     = core.menu.slider_int(10, 60, 25, "eaxdruidferal_war_stomp_hp_pct")
menu.war_stomp_attackers                  = core.menu.slider_int(1, 5, 3, "eaxdruidferal_war_stomp_attackers")
menu.use_cyclone                          = core.menu.checkbox(false, "eaxdruidferal_use_cyclone")
menu.use_entangling_roots                 = core.menu.checkbox(false, "eaxdruidferal_use_entangling_roots")
menu.maul_min_rage                        = core.menu.slider_int(10, 80, 45, "eaxdruidferal_maul_min_rage")
menu.frenzied_regeneration_hp_pct         = core.menu.slider_int(10, 70, 40, "eaxdruidferal_frenzied_regeneration_hp_pct")
menu.use_ooc_self_heal                    = core.menu.checkbox(true, "eaxdruidferal_ooc_self_heal")
menu.ooc_self_heal_hp_pct                 = core.menu.slider_int(30, 90, 70, "eaxdruidferal_ooc_self_heal_hp_pct")

-- ════════════════════════════════════════════════════════════════════════════
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ════════════════════════════════════════════════════════════════════════════

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxdruidferal")
    end

    root_tree:render("  Eax's Druid Feral", function()

        ps.render_controls(menu, "Eax's Druid Feral")

        -- ── Top-level controls (always visible, no sub-menu) ─────────────────
        menu.lane:render("Role", { "Auto Detect", "Cat DPS", "Bear DPS", "Guardian (Tank)" })
        menu.auto_form:render("Auto Form", "Automatically shift into the correct form for the selected role")
        menu.shift_mana_floor:render("Shift Mana Floor %", "Don't shift forms below this mana % — stay in current form instead")

        -- ── Cat Form (DPS) ────────────────────────────────────────────────────
        cat_tree:render("  Cat Form (DPS)", function()
            ps.header("Builders")
            menu.use_mangle_cat:render("Mangle (Cat)", "Maintain the shared Mangle / bleed-amp debuff")
            menu.use_rake:render("Rake", "Maintain Rake bleed uptime")
            menu.rake_refresh_seconds:render("Rake Refresh (sec)", "Refresh Rake below this remaining time")
            menu.use_shred:render("Shred", "Primary CP builder — requires being behind the target")
            menu.use_claw:render("Claw", "Builder fallback when Shred is unavailable")
            ps.header("Finishers")
            menu.use_rip:render("Rip", "Spend CPs on Rip bleed (prefer during Tiger's Fury / Berserk)")
            menu.rip_combo_points:render("Rip Combo Points", "Minimum CPs before Rip")
            menu.rip_refresh_seconds:render("Rip Refresh (sec)", "Refresh Rip below this remaining time")
            menu.use_ferocious_bite:render("Ferocious Bite", "CP finisher / killshot")
            menu.bite_killshot_hp_pct:render("Killshot HP %", "Fire at any CP below this HP — above it, only at 5 CPs")
            menu.use_maim:render("Maim (interrupt)", "Use at 5 CPs to interrupt — only when Bash is on CD")
            ps.header("Cooldowns")
            menu.use_tigers_fury:render("Tiger's Fury", "Energy recovery — fires during builder phase (CP < 4)")
            menu.tigers_fury_energy:render("Tiger's Fury Energy", "Fire Tiger's Fury at or below this energy")
            ps.header("Stealth")
            menu.use_prowl:render("Prowl", "Auto-enter stealth OOC in cat form")
            menu.use_pounce:render("Pounce", "Stealth opener — stun")
            menu.use_ravage:render("Ravage", "Stealth opener — high damage")
        end)

        -- ── Bear Form (DPS) ───────────────────────────────────────────────────
        bear_tree:render("  Bear Form (DPS)", function()
            menu.use_mangle_bear:render("Mangle (Bear)", "Maintain the shared Mangle debuff")
            menu.use_lacerate:render("Lacerate", "Build and maintain Lacerate stacks")
            menu.use_demoralizing_roar:render("Demoralizing Roar", "Reduce nearby enemy attack power")
            menu.use_swipe:render("Swipe", "AoE — use when multiple enemies are in range")
            menu.swipe_enemy_count:render("Swipe Enemy Count", "Minimum enemies before Swipe fires")
            menu.use_maul:render("Maul", "Queue Maul on next melee swing as rage dump")
            menu.maul_min_rage:render("Maul Min Rage", "Minimum rage before Maul is queued")
            menu.use_berserk:render("Berserk", "Burst CD — reduces Mangle CD to 1.5s")
            menu.auto_growl:render("Auto Growl", "Taunt when the primary target is not on you")
            menu.frenzied_regeneration_hp_pct:render("Frenzied Regen HP %", "Emergency self-heal threshold")
        end)

        -- ── Guardian / Tank ───────────────────────────────────────────────────
        guardian_tree:render("  Guardian / Tank", function()
            ps.header("Defensive Cooldowns")
            menu.use_survival_instincts:render("Survival Instincts", "Major tank CD — use below this HP %")
            menu.survival_instincts_hp_pct:render("Survival Instincts HP %", "Trigger threshold")
            menu.tank_cd_overlap:render("Allow CD Overlap", "Allow SI + Frenzied Regen simultaneously")
            ps.header("Rage")
            menu.use_enrage:render("Enrage", "Free rage generation when low — important for pull threat")
            menu.enrage_rage_threshold:render("Enrage Rage Threshold", "Fire Enrage below this rage value")
            ps.header("Multi-Target")
            menu.use_challenging_roar:render("Challenging Roar", "AoE taunt when a party member drops below the HP threshold")
            menu.challenging_roar_party_hp_pct:render("Challenging Roar Party HP %", "Trigger threshold")
            menu.guardian_swipe_enemy_count:render("Guardian Swipe Count", "Minimum enemies before Swipe fires in tank mode")
        end)

        -- ── Shared Abilities ──────────────────────────────────────────────────
        shared_tree:render("  Shared Abilities", function()
            menu.use_faerie_fire:render("Faerie Fire (Feral)", "Armor reduction — works in any form")
            menu.use_bash:render("Bash", "Bear stun — also used as interrupt")
            menu.use_feral_charge:render("Feral Charge", "Bear charge to close gaps")
            menu.use_barkskin:render("Barkskin", "Emergency damage reduction — any form")
            menu.barkskin_hp_pct:render("Barkskin HP %", "Use below this HP %")
            menu.use_war_stomp:render("War Stomp", "Tauren racial AoE stun")
            menu.war_stomp_hp_pct:render("War Stomp HP %", "HP trigger (0 = disable HP trigger)")
            menu.war_stomp_attackers:render("War Stomp Attackers", "Attacker count trigger")
            menu.use_cyclone:render("Cyclone", "Last-resort CC — caster form only, Bash must be on CD")
            menu.use_entangling_roots:render("Entangling Roots", "Root kiting targets")
            menu.use_abolish_poison:render("Abolish Poison", "Cleanse poison from self")
            menu.use_remove_curse:render("Remove Curse", "Dispel curses from self or party (caster form only)")
            menu.use_natures_grasp:render("Nature's Grasp", "Auto-root attackers in caster form")
            menu.use_travel_form:render("Travel Form", "Auto Travel Form OOC")
            menu.use_innervate:render("Innervate", "Self-cast OOC when low mana")
            menu.innervate_mana_pct:render("Innervate Mana %", "Trigger threshold")
            menu.use_ooc_self_heal:render("OOC Self-Heal", "Drop to caster form and Healing Touch when HP is low OOC")
            menu.ooc_self_heal_hp_pct:render("OOC Self-Heal HP %", "Heal below this HP % when out of combat")
            menu.use_powershift:render("Powershift", "Shift out and back into cat form to trigger energy regen (Wolfshead Helm / Natural Shapeshifter)")
        end)

        -- ── Standard sections ─────────────────────────────────────────────────
        ps.render_defensive(menu, def_tree, {
            { key = "use_frenzied_regeneration", label = "Frenzied Regeneration", tip = "Emergency self-heal in bear form" },
        })
        ps.render_targeting(menu, tgt_tree)
        ps.render_racial(menu, racial_tree)
        ps.render_ooc(menu, ooc_tree, false)
        ps.render_esp(menu, esp_tree)

    end)
end
return menu
