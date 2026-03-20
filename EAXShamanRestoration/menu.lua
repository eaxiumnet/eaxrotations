-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Eax's Shaman Restoration
-- ║  Space Theme v4.0  ·  Stars drawn inside the panel background
-- ╚══════════════════════════════════════════════════════════════════╝
local mana_conservator = require("mana_conservator")

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
menu.enabled                             = core.menu.checkbox(true, "eaxshamanrestoration_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxshamanrestoration_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxshamanrestoration_mode")
menu.debug                               = core.menu.checkbox(false, "eaxshamanrestoration_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxshamanrestoration_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxshamanrestoration_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxshamanrestoration_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxshamanrestoration_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

menu.auto_repair                        = core.menu.checkbox(true, "eaxshamanrestoration_auto_repair")
menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxshamanrestoration_auto_sell_greys")
menu.auto_mount                         = core.menu.checkbox(true, "eaxshamanrestoration_auto_mount")
menu.auto_dismount                      = core.menu.checkbox(true, "eaxshamanrestoration_auto_dismount")
menu.auto_combat_potions                = core.menu.checkbox(false, "eaxshamanrestoration_auto_combat_potions")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxshamanrestoration_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxshamanrestoration_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxshamanrestoration_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxshamanrestoration_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxshamanrestoration_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxshamanrestoration_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxshamanrestoration_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxshamanrestoration_spirit_tap_wand")
-- ESP
menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")

-- -- Class-specific elements ---------------------------------------------------
menu.heal_tank_hp                         = core.menu.slider_int(50, 99, 75, "heal_tank_hp")
menu.heal_party_hp                        = core.menu.slider_int(50, 99, 78, "heal_party_hp")
menu.chain_heal_targets                   = core.menu.slider_int(2, 6, 3, "chain_heal_targets")
menu.heal_emergency_hp                    = core.menu.slider_int(20, 70, 40, "heal_emergency_hp")
menu.use_water_shield                     = core.menu.checkbox(true, "use_water_shield")
menu.use_cooldowns                        = core.menu.checkbox(true, "use_cooldowns")
menu.cooldowns_key                        = core.menu.keybind(7, false, "cooldowns_key")
menu.use_natures_swiftness                = core.menu.checkbox(true, "use_natures_swiftness")
menu.ns_emergency_hp                      = core.menu.slider_int(10, 60, 30, "ns_emergency_hp")
menu.use_bloodlust                        = core.menu.checkbox(true, "use_bloodlust")
menu.bloodlust_hp                         = core.menu.slider_int(10, 60, 35, "bloodlust_hp")
menu.bloodlust_on_pull                    = core.menu.checkbox(true, "bloodlust_on_pull")
menu.auto_totems                          = core.menu.checkbox(true, "auto_totems")
menu.auto_totem_mana_tide                 = core.menu.checkbox(true, "auto_totem_mana_tide")
menu.auto_totem_healing_stream            = core.menu.checkbox(true, "auto_totem_healing_stream")
menu.auto_totem_wrath                     = core.menu.checkbox(true, "auto_totem_wrath")
menu.auto_totem_wrath_of_air              = core.menu.checkbox(true, "auto_totem_wrath_of_air")
menu.prepull_totems                       = core.menu.checkbox(true, "prepull_totems")
menu.use_totemic_recall                   = core.menu.checkbox(true, "use_totemic_recall")
menu.use_dispels                          = core.menu.checkbox(true, "use_dispels")
menu.cleanse_key                          = core.menu.keybind(7, false, "cleanse_key")
menu.enable_dps                           = core.menu.checkbox(true, "enable_dps")
menu.dps_key                              = core.menu.keybind(7, false, "dps_key")
menu.use_dps_filler                       = core.menu.checkbox(true, "use_dps_filler")
menu.use_interrupt                        = core.menu.checkbox(true, "use_interrupt")
menu.use_purge                            = core.menu.checkbox(true, "use_purge")
menu.ooc_self_heal                        = core.menu.checkbox(true, "ooc_self_heal")
menu.ooc_self_hp                          = core.menu.slider_int(30, 90, 70, "ooc_self_hp")
menu.use_flametongue                      = core.menu.checkbox(true, "use_flametongue")
menu.use_auto_attack                      = core.menu.checkbox(true, "use_auto_attack")
menu.use_drink                            = core.menu.checkbox(true, "use_drink")
menu.drink_mana_pct                       = core.menu.slider_int(20, 90, 60, "drink_mana_pct")
menu.use_mana_potion                      = core.menu.checkbox(true, "use_mana_potion")
menu.mana_potion_pct                      = core.menu.slider_int(10, 50, 30, "mana_potion_pct")
menu.use_reincarnation                    = core.menu.checkbox(true, "use_reincarnation")
menu.pvp_mode                             = core.menu.checkbox(false, "pvp_mode")
menu.pvp_use_grounding                    = core.menu.checkbox(true, "pvp_use_grounding")
menu.pvp_use_tremor                       = core.menu.checkbox(true, "pvp_use_tremor")
menu.pvp_use_purge                        = core.menu.checkbox(false, "pvp_use_purge")
menu.tank_priority_weight                 = core.menu.slider_int(0, 25, 8, "tank_priority_weight")
menu.mana_floor                           = core.menu.slider_int(5, 60, 25, "mana_floor")
menu.overheal_protection                  = core.menu.checkbox(true, "overheal_protection")
menu.mana_tide_timing                     = core.menu.checkbox(true, "mana_tide_timing")
menu.mana_tide_mana_pct                   = core.menu.slider_int(20, 80, 50, "mana_tide_mana_pct")

mana_conservator.register_menu_items(menu, "eax_shaman_restoration")

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
        ps.draw_space(_win, "eaxshamanrestoration")
    end

    root_tree:render("  Eax's Shaman Restoration", function()

        ps.render_controls(menu, "Eax's Shaman Restoration")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("  Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.heal_tank_hp:render("Tank heal HP%", "Cast Healing Wave when tank effective HP falls below this")
            menu.heal_party_hp:render("Party heal HP%", "Chain Heal fires when enough party members are below this")
            menu.chain_heal_targets:render("Chain Heal min targets", "Minimum injured members before Chain Heal fires")
            menu.heal_emergency_hp:render("Emergency HP%", "Skip dispels/totems for any member below this - heal first")
            menu.use_water_shield:render("Water Shield", "Keep Water Shield active for mana regen (never overwrites Earth Shield)")
            menu.use_cooldowns:render("Enable Cooldowns", "Master toggle for all cooldown abilities")
            menu.cooldowns_key:render("Cooldowns Hotkey", "")
            menu.use_natures_swiftness:render("Nature's Swiftness", "Off-GCD NS + instant Healing Wave when tank is critically low")
            menu.ns_emergency_hp:render("  NS threshold HP%", "Only use NS when tank effective HP is at or below this")
            menu.use_bloodlust:render("Bloodlust / Heroism", "Auto-cast Bloodlust or Heroism")
            menu.bloodlust_hp:render("  Lust at boss HP%", "Use Bloodlust when boss HP is at or below this (execute phase)")
            menu.bloodlust_on_pull:render("  Lust on pull", "Also use Bloodlust at the start of combat (ignores HP threshold)")
            menu.auto_totems:render("Auto Totems", "Automatically place and refresh totems")
            menu.auto_totem_mana_tide:render("  Mana Tide Totem", "Use proactively when mana drops below the configured threshold")
            menu.auto_totem_healing_stream:render("  Healing Stream Totem", "Passive AoE healing - keep active in combat")
            menu.auto_totem_wrath:render("  Totem of Wrath", "+3%% spell crit for the party - TBC's best healing throughput totem")
            menu.auto_totem_wrath_of_air:render("  Wrath of Air Totem", "5%% spell haste aura - enable if your spec has it")
            menu.prepull_totems:render("  Pre-pull totems", "Place Healing Stream + Totem of Wrath before combat when enemies are nearby")
            menu.use_totemic_recall:render("Totemic Recall", "Recall totems out of combat to recover a portion of their mana cost")
            menu.use_dispels:render("Cure Poison + Cure Disease", "Auto-dispel Poison and Disease from party members.\n")
            menu.cleanse_key:render("Dispel Hotkey", "Hotkey to toggle dispels on/off from Control Panel")
            menu.enable_dps:render("Enable DPS Filler", "Cast offensive spells when party is stable and mana permits")
            menu.dps_key:render("DPS Hotkey", "")
            menu.use_dps_filler:render("Lightning Bolt / Chain Lightning", "Fill GCDs with LB (single) or CL (3+ enemies)")
            menu.use_interrupt:render("Earth Shock interrupt", "Interrupt dangerous casts with Earth Shock")
            menu.use_purge:render("Purge enemy buffs", "Strip one magic buff from hostile target")
            menu.ooc_self_heal:render("OOC Self-heal", "Cast Lesser Healing Wave on self when out of combat and injured")
            menu.ooc_self_hp:render("  Heal below HP%", "")
            menu.use_flametongue:render("Flametongue Weapon", "Keep Flametongue Weapon active on mainhand (spell power buff)")
            menu.use_auto_attack:render("Auto Attack", "Start melee auto-attacks when in combat with a target in range")
            menu.use_drink:render("Auto Drink", "Drink water out of combat when mana is below the threshold")
            menu.drink_mana_pct:render("  Drink below mana%", "Start drinking when mana drops to or below this value")
            menu.use_mana_potion:render("Mana Potion", "Use Super Mana Potion / Major Mana Potion in combat when mana is low")
            menu.mana_potion_pct:render("  Potion below mana%", "Use mana potion when in-combat mana drops to or below this value")
            menu.use_reincarnation:render("Reincarnation (Ankh)", "Auto self-rez with Ankh when dead and the cooldown is ready")
            menu.pvp_mode:render("PvP Mode", "Enables Grounding Totem, Tremor Totem, and Purge")
            menu.pvp_use_grounding:render("  Grounding Totem", "Place on cooldown to absorb targeted spells")
            menu.pvp_use_tremor:render("  Tremor Totem", "Place when a party member has fear, charm, or sleep")
            menu.pvp_use_purge:render("  Purge", "Strip 1 magic buff from your target")
            menu.tank_priority_weight:render("Tank priority weight%", "Effective-HP penalty applied to tanks so they sort above DPS.\n8 is a good default.")
            menu.mana_floor:render("Mana floor%", "Suppress Chain Heal and DPS filler below this mana level")
            menu.overheal_protection:render("Overheal Protection", "Cancel active Healing Wave if the target will be near-full when it lands")
            menu.mana_tide_timing:render("Proactive Mana Tide", "Use Mana Tide when mana drops below the threshold")
            menu.mana_tide_mana_pct:render("  Mana Tide at mana%", "")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_shamanistic_rage", label = "Shamanistic Rage", tip = "Emergency mana regen and damage reduction", hp_key = "use_shamanistic_rage_hp_pct", hp_label = "Shamanistic Rage HP %" },
        })

        -- -- Targeting --------------------------------------------------------
        ps.render_targeting(menu, tgt_tree)

        -- -- Racial ------------------------------------------------------------
        ps.render_racial(menu, racial_tree)

        -- -- Out-of-combat -----------------------------------------------------
        menu.auto_repair:render("Auto Repair", "Automatically repair gear at vendors")
        menu.auto_sell_greys:render("Auto Sell Greys", "Automatically sell poor-quality items at vendors")
        menu.auto_mount:render("Auto Mount", "Automatically mount when traveling out of combat")
        menu.auto_dismount:render("Auto Dismount", "Automatically dismount when entering combat")
        menu.auto_combat_potions:render("Auto Combat Potions", "Use combat potions automatically when appropriate")
        menu.auto_ooc_food_drink:render("Auto OOC Food/Drink", "Use food and drink out of combat when needed")
        menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")
        ps.render_ooc(menu, ooc_tree, true)

        -- -- Display & HUD -----------------------------------------------------
        ps.render_esp(menu, esp_tree)

    end)
end

menu.use_shamanistic_rage = core.menu.checkbox(true, "eaxshamrest_sham_rage")
menu.use_shamanistic_rage_hp_pct = core.menu.slider_int(0, 100, 30, "eaxshamrest_sham_hp")
return menu
