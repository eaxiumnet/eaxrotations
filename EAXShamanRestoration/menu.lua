-- menu.lua
-- EAX Shaman Restoration | TBC menu + Control Panel

---@type color
local color = require("common/color")

local menu   = {}
local dev_id = "eax_shaman_restoration_"

local main_node  = core.menu.tree_node()
local heal_node  = core.menu.tree_node()
local cd_node    = core.menu.tree_node()
local totem_node = core.menu.tree_node()
local disp_node  = core.menu.tree_node()
local dps_node   = core.menu.tree_node()
local ooc_node   = core.menu.tree_node()
local pvp_node   = core.menu.tree_node()
local adv_node   = core.menu.tree_node()

-- ─── Root ────────────────────────────────────────────────────────────────────

menu.enabled    = core.menu.checkbox(true,  dev_id .. "enabled")
menu.toggle_key = core.menu.keybind(7, false, dev_id .. "toggle_key")
menu.mode       = core.menu.combobox(1,     dev_id .. "mode")
menu.debug      = core.menu.checkbox(false, dev_id .. "debug")

-- ─── Healing ─────────────────────────────────────────────────────────────────

menu.heal_tank_hp       = core.menu.slider_int(50, 99, 75, dev_id .. "heal_tank_hp")
menu.heal_party_hp      = core.menu.slider_int(50, 99, 78, dev_id .. "heal_party_hp")
menu.chain_heal_targets = core.menu.slider_int(2,  6,  3,  dev_id .. "chain_heal_targets")
menu.heal_emergency_hp  = core.menu.slider_int(20, 70, 40, dev_id .. "heal_emergency_hp")
menu.use_water_shield   = core.menu.checkbox(true,  dev_id .. "use_water_shield")

-- ─── Cooldowns ───────────────────────────────────────────────────────────────

menu.use_cooldowns         = core.menu.checkbox(true,  dev_id .. "use_cooldowns")
menu.cooldowns_key         = core.menu.keybind(7, false, dev_id .. "cooldowns_key")
menu.use_natures_swiftness = core.menu.checkbox(true,  dev_id .. "use_natures_swiftness")
menu.ns_emergency_hp       = core.menu.slider_int(10, 60, 30, dev_id .. "ns_emergency_hp")
menu.use_bloodlust         = core.menu.checkbox(true,  dev_id .. "use_bloodlust")
menu.bloodlust_hp          = core.menu.slider_int(10, 60, 35, dev_id .. "bloodlust_hp")
menu.bloodlust_on_pull     = core.menu.checkbox(false, dev_id .. "bloodlust_on_pull")

-- ─── Totems ──────────────────────────────────────────────────────────────────

menu.auto_totems               = core.menu.checkbox(true,  dev_id .. "auto_totems")
menu.auto_totem_mana_tide      = core.menu.checkbox(true,  dev_id .. "auto_totem_mana_tide")
menu.auto_totem_healing_stream = core.menu.checkbox(true,  dev_id .. "auto_totem_healing_stream")
menu.auto_totem_wrath          = core.menu.checkbox(true,  dev_id .. "auto_totem_wrath")
menu.auto_totem_wrath_of_air   = core.menu.checkbox(false, dev_id .. "auto_totem_wrath_of_air")
menu.prepull_totems            = core.menu.checkbox(true,  dev_id .. "prepull_totems")
menu.use_totemic_recall        = core.menu.checkbox(true,  dev_id .. "use_totemic_recall")

-- ─── Dispels ─────────────────────────────────────────────────────────────────

menu.use_dispels  = core.menu.checkbox(true,  dev_id .. "use_dispels")
menu.cleanse_key  = core.menu.keybind(7, false, dev_id .. "cleanse_key")

-- ─── DPS ─────────────────────────────────────────────────────────────────────

menu.enable_dps     = core.menu.checkbox(true,  dev_id .. "enable_dps")
menu.dps_key        = core.menu.keybind(7, false, dev_id .. "dps_key")
menu.use_dps_filler = core.menu.checkbox(true,  dev_id .. "use_dps_filler")
menu.use_interrupt  = core.menu.checkbox(true,  dev_id .. "use_interrupt")
menu.use_purge      = core.menu.checkbox(false, dev_id .. "use_purge")

-- ─── Out of Combat ───────────────────────────────────────────────────────────

menu.ooc_self_heal       = core.menu.checkbox(true,  dev_id .. "ooc_self_heal")
menu.ooc_self_hp         = core.menu.slider_int(30, 90, 70, dev_id .. "ooc_self_hp")
menu.use_flametongue     = core.menu.checkbox(true,  dev_id .. "use_flametongue")
menu.use_auto_attack     = core.menu.checkbox(true,  dev_id .. "use_auto_attack")
menu.use_drink           = core.menu.checkbox(true,  dev_id .. "use_drink")
menu.drink_mana_pct      = core.menu.slider_int(20, 90, 60, dev_id .. "drink_mana_pct")
menu.use_mana_potion     = core.menu.checkbox(true,  dev_id .. "use_mana_potion")
menu.mana_potion_pct     = core.menu.slider_int(10, 50, 30, dev_id .. "mana_potion_pct")
menu.use_reincarnation   = core.menu.checkbox(true,  dev_id .. "use_reincarnation")

-- ─── PvP ─────────────────────────────────────────────────────────────────────

menu.pvp_mode          = core.menu.checkbox(false, dev_id .. "pvp_mode")
menu.pvp_use_grounding = core.menu.checkbox(true,  dev_id .. "pvp_use_grounding")
menu.pvp_use_tremor    = core.menu.checkbox(true,  dev_id .. "pvp_use_tremor")
menu.pvp_use_purge     = core.menu.checkbox(false, dev_id .. "pvp_use_purge")

-- ─── Advanced ────────────────────────────────────────────────────────────────

menu.tank_priority_weight = core.menu.slider_int(0,  25, 8,  dev_id .. "tank_priority_weight")
menu.mana_floor           = core.menu.slider_int(5,  60, 25, dev_id .. "mana_floor")
menu.overheal_protection  = core.menu.checkbox(true, dev_id .. "overheal_protection")
menu.combat_self_hp_boost = core.menu.slider_int(0,  30, 10, dev_id .. "combat_self_hp_boost")
menu.focus_priority       = core.menu.checkbox(false, dev_id .. "focus_priority")
menu.mana_tide_timing     = core.menu.checkbox(true,  dev_id .. "mana_tide_timing")
menu.mana_tide_mana_pct   = core.menu.slider_int(20, 80, 50, dev_id .. "mana_tide_mana_pct")

-- ─── Render ──────────────────────────────────────────────────────────────────

local MODE_OPTIONS = { "Auto", "Solo", "Dungeon", "Raid" }

function menu.render()
    main_node:render("EAX Shaman Restoration [TBC]", function()

        menu.enabled:render("Enable")
        menu.toggle_key:render("Toggle Key")
        menu.mode:render("Mode", MODE_OPTIONS,
            "Auto: detect from party size\nSolo: DPS+heals\nDungeon/Raid: pure healing")
        menu.debug:render("Debug", "Print cast decisions to console")

        heal_node:render("Healing", function()
            core.menu.header():render("Thresholds", color.green(180))
            menu.heal_tank_hp:render("Tank heal HP%",
                "Cast Healing Wave when tank effective HP falls below this")
            menu.heal_party_hp:render("Party heal HP%",
                "Chain Heal fires when enough party members are below this")
            menu.chain_heal_targets:render("Chain Heal min targets",
                "Minimum injured members before Chain Heal fires")
            menu.heal_emergency_hp:render("Emergency HP%",
                "Skip dispels/totems for any member below this — heal first")
            menu.use_water_shield:render("Water Shield",
                "Keep Water Shield active for mana regen (never overwrites Earth Shield)")
        end)

        cd_node:render("Cooldowns", function()
            menu.use_cooldowns:render("Enable Cooldowns",
                "Master toggle for all cooldown abilities")
            menu.cooldowns_key:render("Cooldowns Hotkey")
            core.menu.separator():render()
            menu.use_natures_swiftness:render("Nature's Swiftness",
                "Off-GCD NS + instant Healing Wave when tank is critically low")
            menu.ns_emergency_hp:render("  NS threshold HP%",
                "Only use NS when tank effective HP is at or below this")
            core.menu.separator():render()
            menu.use_bloodlust:render("Bloodlust / Heroism",
                "Auto-cast Bloodlust or Heroism")
            menu.bloodlust_hp:render("  Lust at boss HP%",
                "Use Bloodlust when boss HP is at or below this (execute phase)")
            menu.bloodlust_on_pull:render("  Lust on pull",
                "Also use Bloodlust at the start of combat (ignores HP threshold)")
        end)

        totem_node:render("Totems", function()
            menu.auto_totems:render("Auto Totems", "Automatically place and refresh totems")
            menu.auto_totem_mana_tide:render("  Mana Tide Totem",
                "Use proactively when mana drops below the configured threshold")
            menu.auto_totem_healing_stream:render("  Healing Stream Totem",
                "Passive AoE healing — keep active in combat")
            menu.auto_totem_wrath:render("  Totem of Wrath",
                "+3%% spell crit for the party — TBC's best healing throughput totem")
            menu.auto_totem_wrath_of_air:render("  Wrath of Air Totem",
                "5%% spell haste aura — enable if your spec has it")
            menu.prepull_totems:render("  Pre-pull totems",
                "Place Healing Stream + Totem of Wrath before combat when enemies are nearby")
            menu.use_totemic_recall:render("Totemic Recall",
                "Recall totems out of combat to recover a portion of their mana cost")
        end)

        disp_node:render("Dispels", function()
            menu.use_dispels:render("Cure Poison + Cure Disease",
                "Auto-dispel Poison and Disease from party members.\n"
                .. "Targets the most injured dispellable member first.")
            menu.cleanse_key:render("Dispel Hotkey",
                "Hotkey to toggle dispels on/off from Control Panel")
        end)

        dps_node:render("DPS Filler", function()
            menu.enable_dps:render("Enable DPS Filler",
                "Cast offensive spells when party is stable and mana permits")
            menu.dps_key:render("DPS Hotkey")
            menu.use_dps_filler:render("Lightning Bolt / Chain Lightning",
                "Fill GCDs with LB (single) or CL (3+ enemies)")
            menu.use_interrupt:render("Earth Shock interrupt",
                "Interrupt dangerous casts with Earth Shock")
            menu.use_purge:render("Purge enemy buffs",
                "Strip one magic buff from hostile target")
        end)

        ooc_node:render("Out of Combat / Leveling", function()
            core.menu.header():render("Self Maintenance", color.cyan(170))
            menu.ooc_self_heal:render("OOC Self-heal",
                "Cast Lesser Healing Wave on self when out of combat and injured")
            menu.ooc_self_hp:render("  Heal below HP%")
            menu.use_flametongue:render("Flametongue Weapon",
                "Keep Flametongue Weapon active on mainhand (spell power buff)")
            menu.use_auto_attack:render("Auto Attack",
                "Start melee auto-attacks when in combat with a target in range")

            core.menu.header():render("Mana Recovery", color.blue(170))
            menu.use_drink:render("Auto Drink",
                "Drink water out of combat when mana is below the threshold")
            menu.drink_mana_pct:render("  Drink below mana%",
                "Start drinking when mana drops to or below this value")
            menu.use_mana_potion:render("Mana Potion",
                "Use Super Mana Potion / Major Mana Potion in combat when mana is low")
            menu.mana_potion_pct:render("  Potion below mana%",
                "Use mana potion when in-combat mana drops to or below this value")

            core.menu.header():render("Survival", color.orange(170))
            menu.use_reincarnation:render("Reincarnation (Ankh)",
                "Auto self-rez with Ankh when dead and the cooldown is ready")
        end)

        pvp_node:render("PvP", function()
            menu.pvp_mode:render("PvP Mode",
                "Enables Grounding Totem, Tremor Totem, and Purge")
            menu.pvp_use_grounding:render("  Grounding Totem",
                "Place on cooldown to absorb targeted spells")
            menu.pvp_use_tremor:render("  Tremor Totem",
                "Place when a party member has fear, charm, or sleep")
            menu.pvp_use_purge:render("  Purge",
                "Strip 1 magic buff from your target")
        end)

        adv_node:render("Advanced", function()
            core.menu.header():render("Heal Engine", color.white(140))
            menu.tank_priority_weight:render("Tank priority weight%",
                "Effective-HP penalty applied to tanks so they sort above DPS.\n8 is a good default.")
            menu.mana_floor:render("Mana floor%",
                "Suppress Chain Heal and DPS filler below this mana level")
            menu.overheal_protection:render("Overheal Protection",
                "Cancel active Healing Wave if the target will be near-full when it lands")
            menu.combat_self_hp_boost:render("Combat self HP boost%",
                "Extra self-heal threshold while in combat (0-30%)")
            menu.focus_priority:render("Focus target priority",
                "Heal focus target first — use for manual tank assignment")
            core.menu.header():render("Mana Management", color.cyan(170))
            menu.mana_tide_timing:render("Proactive Mana Tide",
                "Use Mana Tide when mana drops below the threshold")
            menu.mana_tide_mana_pct:render("  Mana Tide at mana%")
        end)

    end)
end

function menu.log_debug(message)
    if menu.debug:get_state() then
        core.log("[EAX Shaman Restoration] " .. tostring(message))
    end
end

return menu
