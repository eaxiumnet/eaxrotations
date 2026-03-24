-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  EAX Druid Feral  ·  Class-Driven Menu  v2.0  ·  menu.lua              ║
-- ║                                                                          ║
-- ║  Replaces ps_theme with class_theme for full Druid Feral identity.      ║
-- ║  Nature orange palette · shapeshifter particle field · form-aware UI    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

local theme    = require("class_theme")
local identity = require("class_identity")

-- ── Init theme for Druid Feral ─────────────────────────────────────────────
-- class_id 11 = Druid, spec_id 26 = Druid Feral Cat (used as default)
-- The HUD switches spec_id dynamically based on current form.
theme.init(identity.CLASS_IDS.DRUID, identity.SPEC_IDS.DRUID_FERAL_CAT)

local menu = {}

-- ── Tree nodes (declared outside render, as per API requirements) ─────────────
local root_tree     = theme.tree_node()
local cat_tree      = theme.tree_node()
local bear_tree     = theme.tree_node()
local guardian_tree = theme.tree_node()
local shared_tree   = theme.tree_node()
local tgt_tree      = theme.tree_node()
local racial_tree   = theme.tree_node()
local ooc_tree      = theme.tree_node()
local esp_tree      = theme.tree_node()
local def_tree      = theme.tree_node()

-- ── Controls ──────────────────────────────────────────────────────────────────
menu.enabled         = core.menu.checkbox(true,  "eaxdruidferal_enabled")
menu.toggle_key      = core.menu.keybind(7, false, "eaxdruidferal_toggle_key")
menu.mode            = core.menu.combobox(1, "eaxdruidferal_mode")
menu.debug           = core.menu.checkbox(false, "eaxdruidferal_debug")

-- ── Targeting ──────────────────────────────────────────────────────────────────
menu.focus_priority        = core.menu.checkbox(false, "eaxdruidferal_focus_priority")
menu.combat_self_hp_boost  = core.menu.slider_int(0, 30, 10, "eaxdruidferal_combat_self_hp_boost")

-- ── Racial ────────────────────────────────────────────────────────────────────
menu.use_racial  = core.menu.checkbox(true, "eaxdruidferal_use_racial")
menu.racial_hp   = core.menu.slider_int(10, 80, 40, "eaxdruidferal_racial_hp")

-- ── OOC ───────────────────────────────────────────────────────────────────────
menu.ooc_drink        = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat          = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez          = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff   = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold  = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold    = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- ── Vendor / Travel ────────────────────────────────────────────────────────────
menu.auto_repair         = core.menu.checkbox(true,  "eaxdruidferal_auto_repair")
menu.auto_sell_greys     = core.menu.checkbox(true,  "eaxdruidferal_auto_sell_greys")
menu.auto_mount          = core.menu.checkbox(true,  "eaxdruidferal_auto_mount")
menu.auto_dismount       = core.menu.checkbox(true,  "eaxdruidferal_auto_dismount")
menu.auto_combat_potions = core.menu.checkbox(false, "eaxdruidferal_auto_combat_potions")
menu.auto_ooc_food_drink = core.menu.checkbox(true,  "eaxdruidferal_auto_ooc_food_drink")
menu.auto_flask          = core.menu.checkbox(false, "eaxdruidferal_auto_flask")

-- ── Leveling ──────────────────────────────────────────────────────────────────
menu.leveling_conserve_mana = core.menu.checkbox(true,  "eaxdruidferal_lev_conserve")
menu.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, "eaxdruidferal_lev_mana_floor")

-- ── ESP / HUD ─────────────────────────────────────────────────────────────────
menu.esp_show_hud    = core.menu.checkbox(true,  "eax_esp_show_hud")
menu.esp_show_target = core.menu.checkbox(true,  "eax_esp_show_target")
menu.esp_hud_x       = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
menu.esp_hud_y       = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")
menu.hud_scale       = core.menu.slider_float(0.8, 2.5, 1.0, "eax_esp_hud_scale")

-- ── Spec / Role ────────────────────────────────────────────────────────────────
menu.lane      = core.menu.combobox(1, "eaxdruidferal_lane")
menu.auto_form = core.menu.checkbox(true,  "eaxdruidferal_auto_form")
menu.shift_mana_floor = core.menu.slider_int(0, 50, 20, "eaxdruidferal_shift_mana_floor")

-- ── Cat Form — Builders ───────────────────────────────────────────────────────
menu.use_faerie_fire  = core.menu.checkbox(true,  "eaxdruidferal_use_faerie_fire")
menu.use_mangle_cat   = core.menu.checkbox(true,  "eaxdruidferal_use_mangle_cat")
menu.use_rake         = core.menu.checkbox(true,  "eaxdruidferal_use_rake")
menu.rake_refresh_seconds = core.menu.slider_int(1, 5, 3, "eaxdruidferal_rake_refresh_seconds")
menu.use_shred        = core.menu.checkbox(true,  "eaxdruidferal_use_shred")
menu.use_claw         = core.menu.checkbox(true,  "eaxdruidferal_use_claw")

-- ── Cat Form — Finishers ──────────────────────────────────────────────────────
menu.use_rip            = core.menu.checkbox(true,  "eaxdruidferal_use_rip")
menu.rip_combo_points   = core.menu.slider_int(3, 5, 5, "eaxdruidferal_rip_combo_points")
menu.rip_refresh_seconds = core.menu.slider_int(1, 5, 3, "eaxdruidferal_rip_refresh_seconds")
menu.use_ferocious_bite = core.menu.checkbox(true,  "eaxdruidferal_use_ferocious_bite")
menu.bite_killshot_hp_pct = core.menu.slider_int(5, 60, 30, "eaxdruidferal_bite_killshot_hp_pct")
menu.use_maim           = core.menu.checkbox(false, "eaxdruidferal_use_maim")

-- ── Cat Form — Cooldowns ──────────────────────────────────────────────────────
menu.use_tigers_fury    = core.menu.checkbox(true,  "eaxdruidferal_use_tigers_fury")
menu.tigers_fury_energy = core.menu.slider_int(10, 60, 30, "eaxdruidferal_tigers_fury_energy")

-- ── Cat Form — Stealth Opener ─────────────────────────────────────────────────
menu.use_prowl   = core.menu.checkbox(true,  "eaxdruidferal_use_prowl")
menu.use_pounce  = core.menu.checkbox(true,  "eaxdruidferal_use_pounce")
menu.use_ravage  = core.menu.checkbox(true,  "eaxdruidferal_use_ravage")

-- ── Bear Form — Rotation ──────────────────────────────────────────────────────
menu.use_mangle_bear        = core.menu.checkbox(true,  "eaxdruidferal_use_mangle_bear")
menu.use_lacerate           = core.menu.checkbox(true,  "eaxdruidferal_use_lacerate")
menu.use_demoralizing_roar  = core.menu.checkbox(true,  "eaxdruidferal_use_demoralizing_roar")
menu.use_swipe              = core.menu.checkbox(true,  "eaxdruidferal_use_swipe")
menu.swipe_enemy_count      = core.menu.slider_int(2, 6, 3, "eaxdruidferal_swipe_enemy_count")
menu.use_maul               = core.menu.checkbox(true,  "eaxdruidferal_use_maul")
menu.maul_min_rage          = core.menu.slider_int(10, 80, 45, "eaxdruidferal_maul_min_rage")
menu.use_frenzied_regeneration = core.menu.checkbox(true, "eaxdruidferal_use_frenzied_regeneration")
menu.frenzied_regeneration_hp_pct = core.menu.slider_int(10, 70, 40, "eaxdruidferal_frenzied_regeneration_hp_pct")
menu.auto_growl             = core.menu.checkbox(true,  "eaxdruidferal_auto_growl")

-- ── Guardian / Tank ───────────────────────────────────────────────────────────
menu.use_survival_instincts       = core.menu.checkbox(true,  "eaxdruidferal_use_survival_instincts")
menu.survival_instincts_hp_pct    = core.menu.slider_int(10, 60, 35, "eaxdruidferal_survival_instincts_hp")
menu.use_enrage                   = core.menu.checkbox(true,  "eaxdruidferal_use_enrage")
menu.enrage_rage_threshold        = core.menu.slider_int(0, 40, 15, "eaxdruidferal_enrage_rage")
menu.use_challenging_roar         = core.menu.checkbox(true,  "eaxdruidferal_use_challenging_roar")
menu.challenging_roar_party_hp_pct = core.menu.slider_int(20, 90, 75, "eaxdruidferal_challenging_roar_party_hp")
menu.tank_cd_overlap              = core.menu.checkbox(false, "eaxdruidferal_tank_cd_overlap")
menu.guardian_swipe_enemy_count   = core.menu.slider_int(1, 4, 2, "eaxdruidferal_guardian_swipe_enemy_count")

-- ── Shared Abilities ──────────────────────────────────────────────────────────
menu.use_feral_charge   = core.menu.checkbox(true,  "eaxdruidferal_use_feral_charge")
menu.use_bash           = core.menu.checkbox(true,  "eaxdruidferal_use_bash")
menu.use_powershift     = core.menu.checkbox(false, "eaxdruidferal_use_powershift")
menu.use_travel_form    = core.menu.checkbox(true,  "eaxdruidferal_use_travel_form")
menu.use_abolish_poison = core.menu.checkbox(true,  "eaxdruidferal_use_abolish_poison")
menu.use_remove_curse   = core.menu.checkbox(true,  "eaxdruidferal_remove_curse")
menu.use_natures_grasp  = core.menu.checkbox(false, "eaxdruidferal_use_natures_grasp")
menu.use_root_escape    = core.menu.checkbox(true,  "eaxdruidferal_root_escape")

-- ── Defensive ────────────────────────────────────────────────────────────────
menu.use_barkskin       = core.menu.checkbox(true,  "eaxdruidferal_use_barkskin")
menu.barkskin_hp_pct    = core.menu.slider_int(10, 60, 40, "eaxdruidferal_barkskin_hp_pct")
menu.use_innervate      = core.menu.checkbox(true,  "eaxdruidferal_use_innervate")
menu.innervate_mana_pct = core.menu.slider_int(10, 60, 20, "eaxdruidferal_innervate_mana_pct")
menu.use_ooc_self_heal      = core.menu.checkbox(true,  "eaxdruidferal_ooc_self_heal")
menu.ooc_self_heal_hp_pct   = core.menu.slider_int(30, 90, 50, "eaxdruidferal_ooc_self_heal_hp_pct")

-- ── CC ─────────────────────────────────────────────────────────────────────
menu.use_war_stomp       = core.menu.checkbox(false, "eaxdruidferal_use_war_stomp")
menu.war_stomp_hp_pct    = core.menu.slider_int(10, 60, 25, "eaxdruidferal_war_stomp_hp_pct")
menu.war_stomp_attackers = core.menu.slider_int(1, 5, 3, "eaxdruidferal_war_stomp_attackers")
menu.use_cyclone         = core.menu.checkbox(false, "eaxdruidferal_use_cyclone")
menu.use_entangling_roots = core.menu.checkbox(false, "eaxdruidferal_use_entangling_roots")

-- ── Window injection (called from main.lua) ───────────────────────────────────
local _win
function menu.set_window(w) _win = w end

-- ── RENDER ────────────────────────────────────────────────────────────────────
function menu.render()
    -- Apply class theme background decorations when tree is open
    if _win and root_tree:is_open() then
        pcall(function() theme.apply(_win, "eaxdruidferal") end)
    end

    root_tree:render("  ❧ EAX Druid Feral", function()

        -- ── Identity banner ─────────────────────────────────────────────────
        do
            local h1 = core.menu.header()
            h1:render("  ╔══ DRUID — Feral Shapeshifter ══╗", theme.col_spec_primary())
            local h2 = core.menu.header()
            h2:render("  ❧ One with Nature", theme.col_accent())
        end

        -- ── Controls ────────────────────────────────────────────────────────
        theme.header("◈ Controls")
        menu.enabled:render("Enabled",
            "Master on/off — bind a key here to toggle mid-fight")
        menu.toggle_key:render("Toggle Key")
        menu.mode:render("Mode", theme.MODE,
            "Auto detects party vs solo context")
        menu.debug:render("Debug Logging")

        -- ── Role Lane ───────────────────────────────────────────────────────
        theme.header("◈ Role")
        menu.lane:render("Active Lane",
            { "Auto Detect", "Cat (DPS)", "Bear (DPS)", "Guardian (Tank)" },
            "Force a specific form lane or let the rotation decide")
        menu.auto_form:render("Auto Form",
            "Automatically shift into the correct form for the selected lane")
        menu.shift_mana_floor:render("Shift Mana Floor %",
            "Don't shift forms below this mana %")

        -- ── Cat Form (DPS) ──────────────────────────────────────────────────
        cat_tree:render("  ◈ Cat Form · DPS", function()

            theme.spec_header("Stealth Opener")
            menu.use_prowl:render("Prowl",
                "Auto-enter stealth OOC in cat form")
            menu.use_pounce:render("Pounce",
                "Stealth opener — stuns the target")
            menu.use_ravage:render("Ravage",
                "Stealth opener — massive burst damage from stealth")

            theme.spec_header("Builders")
            menu.use_faerie_fire:render("Faerie Fire (Feral)",
                "Armor reduction — apply on every target pull")
            menu.use_mangle_cat:render("Mangle (Cat)",
                "Maintain the shared Mangle / bleed-amplification debuff")
            menu.use_rake:render("Rake",
                "Maintain Rake bleed — critical for sustained DPS")
            menu.rake_refresh_seconds:render("Rake Refresh (sec)",
                "Refresh Rake when this many seconds remain")
            menu.use_shred:render("Shred",
                "Primary CP builder — requires being behind the target")
            menu.use_claw:render("Claw",
                "Builder fallback when Shred position is not available")

            theme.spec_header("Finishers")
            menu.use_rip:render("Rip",
                "CP finisher bleed — priority over Ferocious Bite")
            menu.rip_combo_points:render("Rip Combo Points",
                "Minimum CPs before casting Rip")
            menu.rip_refresh_seconds:render("Rip Refresh (sec)",
                "Refresh Rip when this many seconds remain")
            menu.use_ferocious_bite:render("Ferocious Bite",
                "CP spender / execute — fires in killshot window or at 5 CPs")
            menu.bite_killshot_hp_pct:render("Killshot HP %",
                "Fire Bite at any CP count when target HP is below this %")
            menu.use_maim:render("Maim (interrupt)",
                "5-CP interrupt — only when Bash is on cooldown")

            theme.spec_header("Cooldowns")
            menu.use_tigers_fury:render("Tiger's Fury",
                "Energy recovery — fires during builder phase when energy is low")
            menu.tigers_fury_energy:render("Tiger's Fury Energy",
                "Fire Tiger's Fury at or below this energy value")
            menu.use_powershift:render("Powershift (Wolfshead)",
                "Energy reset — requires Wolfshead Helm or Natural Shapeshifter talent")

        end)

        -- ── Bear Form (DPS) ─────────────────────────────────────────────────
        bear_tree:render("  ◈ Bear Form · DPS", function()

            theme.spec_header("Rotation")
            menu.use_mangle_bear:render("Mangle (Bear)",
                "Maintain the shared Mangle debuff — highest priority")
            menu.use_lacerate:render("Lacerate",
                "Build and maintain Lacerate stacks — primary rage dump")
            menu.use_demoralizing_roar:render("Demoralizing Roar",
                "Reduce nearby enemy attack power — maintain uptime")
            menu.use_swipe:render("Swipe",
                "AoE rotation when multiple enemies are in range")
            menu.swipe_enemy_count:render("Swipe Enemy Count",
                "Minimum enemies before Swipe replaces single-target rotation")
            menu.use_maul:render("Maul",
                "Queue Maul on next melee swing as rage overflow dump")
            menu.maul_min_rage:render("Maul Min Rage",
                "Minimum rage before Maul is queued")

            theme.spec_header("Defensive")
            menu.use_frenzied_regeneration:render("Frenzied Regen",
                "Emergency self-heal — auto-shifts to bear if needed")
            menu.frenzied_regeneration_hp_pct:render("Frenzied Regen HP %",
                "Trigger threshold — lower = more conservative")

            theme.spec_header("Threat")
            menu.auto_growl:render("Auto Growl",
                "Taunt when the primary target is attacking someone else")

        end)

        -- ── Guardian / Tank ─────────────────────────────────────────────────
        guardian_tree:render("  ◈ Guardian · Tank", function()

            theme.spec_header("Defensive Cooldowns")
            menu.use_survival_instincts:render("Survival Instincts",
                "Major tank survival CD — use automatically below HP threshold")
            menu.survival_instincts_hp_pct:render("Survival Instincts HP %",
                "Trigger threshold")
            menu.tank_cd_overlap:render("Allow CD Overlap",
                "Allow Survival Instincts and Frenzied Regen simultaneously")

            theme.spec_header("Rage Generation")
            menu.use_enrage:render("Enrage",
                "Free rage generation when low — important for opening threat")
            menu.enrage_rage_threshold:render("Enrage Rage Threshold",
                "Use Enrage when current rage is at or below this value")

            theme.spec_header("Multi-Target")
            menu.use_challenging_roar:render("Challenging Roar",
                "AoE taunt when a party member drops below the HP threshold")
            menu.challenging_roar_party_hp_pct:render("Challenging Roar Party HP %",
                "Trigger threshold — any party member below this fires the taunt")
            menu.guardian_swipe_enemy_count:render("Guardian Swipe Count",
                "Minimum enemies before Swipe fires in tank mode")

        end)

        -- ── Shared Abilities ────────────────────────────────────────────────
        shared_tree:render("  ◈ Shared Abilities", function()

            theme.spec_header("Movement & Gap Close")
            menu.use_feral_charge:render("Feral Charge / Dash",
                "Bear charge or cat dash to close gaps instantly")
            menu.use_travel_form:render("Travel Form OOC",
                "Automatically shift to Travel Form when out of combat")
            menu.use_root_escape:render("Root Escape",
                "Drop form to break immobilize effects automatically")

            theme.spec_header("Crowd Control")
            menu.use_bash:render("Bash",
                "Bear stun — primary interrupt; fires before Maim")
            menu.use_cyclone:render("Cyclone",
                "Last-resort CC — shifts to caster form, requires Bash on CD")
            menu.use_entangling_roots:render("Entangling Roots",
                "Auto-root kiting targets in caster form")
            menu.use_war_stomp:render("War Stomp (Tauren)",
                "AoE stun — fires when multiple attackers surround you or HP drops low")
            menu.war_stomp_hp_pct:render("War Stomp HP %",
                "HP trigger threshold (set 0 to disable HP trigger)")
            menu.war_stomp_attackers:render("War Stomp Attacker Count",
                "Attacker count trigger — fires when this many hit you simultaneously")

            theme.spec_header("Defensive")
            menu.use_barkskin:render("Barkskin",
                "Emergency damage reduction — usable in ANY form, off GCD")
            menu.barkskin_hp_pct:render("Barkskin HP %",
                "Trigger below this HP %")

            theme.spec_header("Out-of-Combat")
            menu.use_innervate:render("Innervate",
                "Self-cast when mana is low out of combat")
            menu.innervate_mana_pct:render("Innervate Mana %",
                "Trigger threshold")
            menu.use_ooc_self_heal:render("OOC Self-Heal",
                "Cast Healing Touch when HP is low out of combat")
            menu.ooc_self_heal_hp_pct:render("OOC Self-Heal HP %",
                "Heal below this HP % when out of combat")
            menu.use_abolish_poison:render("Abolish Poison",
                "Cleanse poison from self automatically")
            menu.use_remove_curse:render("Remove Curse",
                "Dispel curses from self or nearby party members")
            menu.use_natures_grasp:render("Nature's Grasp",
                "Automatically root melee attackers in caster form")

        end)

        -- ── Targeting ─────────────────────────────────────────────────────
        theme.render_targeting(menu, tgt_tree)

        -- ── Racial ────────────────────────────────────────────────────────
        theme.render_racial(menu, racial_tree)

        -- ── Vendor / Travel ───────────────────────────────────────────────
        theme.header("◈ Automation")
        menu.auto_repair:render("Auto Repair",
            "Automatically repair gear at vendors")
        menu.auto_sell_greys:render("Auto Sell Greys",
            "Automatically sell poor-quality items at vendors")
        menu.auto_mount:render("Auto Mount",
            "Automatically mount when traveling out of combat")
        menu.auto_dismount:render("Auto Dismount",
            "Automatically dismount when entering combat")
        menu.auto_combat_potions:render("Auto Combat Potions",
            "Use combat potions automatically at the right moment")
        menu.auto_ooc_food_drink:render("Auto OOC Food / Drink",
            "Eat and drink out of combat when health or mana is low")
        menu.auto_flask:render("Auto Flask",
            "Maintain flask buff automatically when enabled")

        -- ── OOC ───────────────────────────────────────────────────────────
        theme.render_ooc(menu, ooc_tree, false)

        -- ── Display & HUD ─────────────────────────────────────────────────
        theme.render_esp(menu, esp_tree)

    end)
end

return menu
