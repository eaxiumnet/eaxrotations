-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Druid Restoration
-- ║  Space Theme v4.0  ·  Stars drawn inside the panel background
-- ╚══════════════════════════════════════════════════════════════════╝

local ps   = require("ps_theme")
local menu = {}

-- -- Tree nodes ----------------------------------------------------------------
local root_tree    = ps.tree_node()
local main_tree    = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local ooc_tree     = ps.tree_node()
local esp_tree     = ps.tree_node()

-- -- Shared plugin controls + shared fields ------------------------------------
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxdruidrestoration_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxdruidrestoration_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxdruidrestoration_mode")
menu.debug                               = core.menu.checkbox(false, "eaxdruidrestoration_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxdruidrestoration_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxdruidrestoration_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxdruidrestoration_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxdruidrestoration_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxdruidrestoration_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxdruidrestoration_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxdruidrestoration_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxdruidrestoration_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxdruidrestoration_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxdruidrestoration_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.mana_saver                           = core.menu.checkbox(false, "eaxdruidrestoration_mana_saver")
menu.use_mark_of_the_wild                 = core.menu.checkbox(true, "eaxdruidrestoration_use_mark_of_the_wild")
menu.use_lifebloom                        = core.menu.checkbox(true, "eaxdruidrestoration_use_lifebloom")
menu.lifebloom_stacks                     = core.menu.slider_int(1, 3, 3, "eaxdruidrestoration_lifebloom_stacks")
menu.lifebloom_refresh_seconds            = core.menu.slider_int(1, 4, 2, "eaxdruidrestoration_lifebloom_refresh_seconds")
menu.use_rejuvenation                     = core.menu.checkbox(true, "eaxdruidrestoration_use_rejuvenation")
menu.rejuvenation_refresh_seconds         = core.menu.slider_int(1, 5, 3, "eaxdruidrestoration_rejuvenation_refresh_seconds")
menu.use_regrowth                         = core.menu.checkbox(true, "eaxdruidrestoration_use_regrowth")
menu.regrowth_refresh_seconds             = core.menu.slider_int(1, 5, 2, "eaxdruidrestoration_regrowth_refresh_seconds")
menu.use_swiftmend                        = core.menu.checkbox(true, "eaxdruidrestoration_use_swiftmend")
menu.swiftmend_hp_pct                     = core.menu.slider_int(20, 80, 60, "eaxdruidrestoration_swiftmend_hp_pct")
menu.use_wild_growth                      = core.menu.checkbox(true, "eaxdruidrestoration_use_wild_growth")
menu.wild_growth_targets                  = core.menu.slider_int(2, 6, 3, "eaxdruidrestoration_wild_growth_targets")
menu.wild_growth_mana_pct                 = core.menu.slider_int(20, 80, 40, "eaxdruidrestoration_wild_growth_mana_pct")
menu.use_remove_curse                    = core.menu.checkbox(true, "eaxdruidrestoration_remove_curse")
menu.use_innervate                        = core.menu.checkbox(true, "eaxdruidrestoration_use_innervate")
menu.innervate_mana_pct                   = core.menu.slider_int(10, 60, 35, "eaxdruidrestoration_innervate_mana_pct")
menu.use_tranquility                      = core.menu.checkbox(true, "eaxdruidrestoration_use_tranquility")
menu.tranquility_injured_count            = core.menu.slider_int(2, 8, 3, "eaxdruidrestoration_tranquility_injured_count")
menu.use_natures_swiftness                = core.menu.checkbox(true, "eaxdruidrestoration_use_natures_swiftness")
menu.emergency_hp_pct                     = core.menu.slider_int(10, 60, 35, "eaxdruidrestoration_emergency_hp_pct")
menu.overheal_protection                  = core.menu.checkbox(true, "eaxdruidrestoration_overheal_protection")
menu.use_healing_touch                    = core.menu.checkbox(true, "eaxdruidrestoration_use_healing_touch")
menu.healing_touch_hp_pct                 = core.menu.slider_int(10, 60, 35, "eaxdruidrestoration_healing_touch_hp_pct")

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
        -- Draw animated space background BEFORE imgui elements
        ps.draw_space(_win, "eaxdruidrestoration")
    end

    root_tree:render("  Eax's Druid Restoration", function()

        ps.render_controls(menu, "Eax's Druid Restoration")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.mana_saver:render("Mana Saver", "Delay expensive spells until mana is healthier")
            menu.use_mark_of_the_wild:render("Mark of the Wild", "Refresh Mark of the Wild on yourself out of combat")
            menu.use_lifebloom:render("Lifebloom", "Maintain Lifebloom stacks on the primary tank target")
            menu.lifebloom_stacks:render("Desired Stacks", "Target Lifebloom stack count")
            menu.lifebloom_refresh_seconds:render("Refresh Window (sec)", "Refresh Lifebloom below this remaining time")
            menu.use_rejuvenation:render("Rejuvenation", "Maintain Rejuvenation on the priority heal target")
            menu.rejuvenation_refresh_seconds:render("Rejuvenation Refresh (sec)", "Refresh Rejuvenation below this remaining time")
            menu.use_regrowth:render("Regrowth", "Use Regrowth for heavier sustained healing")
            menu.regrowth_refresh_seconds:render("Regrowth Refresh (sec)", "Refresh Regrowth below this remaining time")
            menu.use_swiftmend:render("Swiftmend", "Consume an active HoT for burst healing")
            menu.swiftmend_hp_pct:render("Swiftmend HP %", "Health threshold for Swiftmend")
            menu.use_wild_growth:render("Wild Growth", "Use Wild Growth for multi-target healing when available")
            menu.wild_growth_targets:render("Wild Growth Targets", "Minimum injured allies before Wild Growth")
            menu.wild_growth_mana_pct:render("Wild Growth Mana %", "Minimum mana to allow Wild Growth")
            menu.use_innervate:render("Innervate", "Recover mana automatically at the configured threshold")
            menu.innervate_mana_pct:render("Innervate Mana %", "Mana threshold for Innervate")
            menu.use_tranquility:render("Tranquility", "Use Tranquility during raid-wide injury windows")
            menu.tranquility_injured_count:render("Tranquility Injured Count", "Minimum injured allies before Tranquility")
            menu.use_natures_swiftness:render("Nature's Swiftness", "Prep Nature's Swiftness for Regrowth emergencies")
            menu.emergency_hp_pct:render("Emergency HP %", "Health threshold for Nature's Swiftness + Regrowth")
            menu.use_healing_touch:render("Healing Touch", "Direct heal fallback when target is critical and all HoTs are running")
            menu.healing_touch_hp_pct:render("Healing Touch HP %", "Only cast Healing Touch below this health threshold")
            menu.overheal_protection:render("Overheal Protection", "Cancel slow heals when target is near full HP")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_barkskin", label = "Barkskin", tip = "Emergency damage reduction", hp_key = "use_barkskin_hp_pct", hp_label = "Barkskin HP %" },
        })

        -- -- Targeting --------------------------------------------------------
        ps.render_targeting(menu, tgt_tree)

        -- -- Racial ------------------------------------------------------------
        ps.render_racial(menu, racial_tree)

        -- -- DPS Fallback (Solo) -----------------------------------------------
        local dps_tree = ps.tree_node()
        dps_tree:render("  DPS Fallback (Solo)", function()
            ps.header("Solo DPS – used when no healing is needed")
            menu.dps_fallback_enabled:render("Enable DPS Fallback",
                "When solo and no one needs healing, cast damage spells instead of standing idle")
            menu.dps_use_faerie_fire:render("Faerie Fire",
                "Apply Faerie Fire debuff on target (armor reduction)")
            menu.dps_use_insect_swarm:render("Insect Swarm",
                "Maintain Insect Swarm DoT on target")
            menu.dps_use_moonfire:render("Moonfire",
                "Maintain Moonfire DoT on target")
            menu.dps_use_starfire:render("Starfire",
                "Cast Starfire as filler (slow but high damage)")
            menu.dps_use_wrath:render("Wrath",
                "Cast Wrath as filler (fast caster nuke)")
            menu.dps_starfire_over_wrath:render("Prefer Starfire over Wrath",
                "When both are enabled, cast Starfire instead of Wrath as the filler nuke")
        end)

        -- -- Out-of-combat -----------------------------------------------------
        ps.render_ooc(menu, ooc_tree, true)

        -- -- Display & HUD -----------------------------------------------------
        ps.render_esp(menu, esp_tree)

    end)
end

menu.use_barkskin = core.menu.checkbox(true, "eaxrest_use_barkskin")
menu.use_barkskin_hp_pct = core.menu.slider_int(0, 100, 40, "eaxrest_barkskin_hp")

-- DPS Fallback (solo only - used when no healing is needed)
menu.dps_fallback_enabled     = core.menu.checkbox(true,  "eaxrest_dps_fallback_enabled")
menu.dps_use_faerie_fire      = core.menu.checkbox(true,  "eaxrest_dps_faerie_fire")
menu.dps_use_insect_swarm     = core.menu.checkbox(true,  "eaxrest_dps_insect_swarm")
menu.dps_use_moonfire         = core.menu.checkbox(true,  "eaxrest_dps_moonfire")
menu.dps_use_starfire         = core.menu.checkbox(true,  "eaxrest_dps_starfire")
menu.dps_use_wrath            = core.menu.checkbox(true,  "eaxrest_dps_wrath")
menu.dps_starfire_over_wrath  = core.menu.checkbox(false, "eaxrest_dps_starfire_over_wrath")

return menu
