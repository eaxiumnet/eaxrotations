# PROJECT SYLVANAS — EAX ROTATION MENU REWRITE
## Handover Prompt for Kimi (Complete Task Specification)

---

## CONTEXT & YOUR MISSION

You are working on **Project Sylvanas** — a World of Warcraft rotation bot framework written in Lua. The project contains 29 EAX rotation plugins (e.g. `EAXDruidFeral`, `EAXHunterBM`, `EAXWarriorArms`, etc.).

**The problem:** One or more of the 28 non-Feral rotations is crashing the game at startup or when the menu is opened. `EAXDruidFeral` is confirmed stable and must NEVER be modified.

**Your job:** Rewrite `libraries/menu.lua` for every EAX rotation EXCEPT `EAXDruidFeral`, making each one match the exact structural pattern of `EAXDruidFeral/libraries/menu.lua`. You must preserve every spec-specific control (spell toggles, thresholds, sliders) but fix all structural/API violations.

---

## THE STABLE REFERENCE: EAXDruidFeral PATTERN

This is the **only correct pattern**. Study it carefully. Every rewritten menu must follow this exactly.

### Structural rules (derived from `EAXDruidFeral/libraries/menu.lua`):

1. **Imports**: Only `require("libraries/ps_theme")` and `require("libraries/settings_framework")`. No other requires in menu.lua unless the original had spec-specific ones (e.g. `mana_conservator`).

2. **Tree nodes**: Declared as `local X_tree = ps.tree_node()` at the top. Use only what you need — no orphan tree nodes.

3. **Controls**: Declared as `menu.X = core.menu.checkbox(...)` / `core.menu.slider_int(...)` / `core.menu.keybind(...)` / `core.menu.combobox(...)`. These are IDENTICAL to what was there before — do NOT change field names or IDs.

4. **`_win` and `set_window`**: Every menu MUST have:
   ```lua
   local _win
   function menu.set_window(win)
       _win = win
   end
   ```

5. **`menu.render()`**: Must use this exact skeleton — NO `ps.render_controls()`, NO `ps.render_targeting()`, NO `ps.render_racial()`, NO `ps.subheader()`. All rendering is done **inline**:
   ```lua
   function menu.render()
       if _win and root_tree:is_open() then
           ps.draw_space(_win, "ROTATION_ID")
       end

       root_tree:render("Eax's CLASS SPEC", function()

           -- GENERAL (always first, always inline)
           ps.header("General")
           menu.enabled:render("Enabled", "Enable/disable rotation")
           menu.mode:render("Mode", {"Auto", "PvE", "PvP"}, "Rotation mode selection")
           menu.toggle_key:render("Toggle Key", "Keybind to enable/disable")

           -- SPEC-SPECIFIC TREES (one tree per logical group)
           rotation_tree:render("Rotation", function()
               -- spec spells here
           end)

           defensive_tree:render("Defensive", function()
               -- defensive abilities here
           end)

           utility_tree:render("Utility", function()
               -- utility abilities here
           end)

           buffs_tree:render("Buffs", function()
               -- OOC buffs here
           end)

           consumables_tree:render("Consumables", function()
               -- potions, food/drink, healthstone here
           end)

           pvp_tree:render("PvP", function()
               -- PvP settings here
           end)

           automation_tree:render("Automation", function()
               -- burst, trinkets, automation here
           end)

           dashboard_tree:render("Dashboard (Beta)", function()
               -- dashboard/HUD settings here
           end)

           advanced_tree:render("Advanced", function()
               -- targeting, racial, leveling here
               ps.header("Targeting")
               menu.focus_priority:render("Focus Priority", "Prioritize focus target")
               menu.combat_self_hp_boost:render("Self HP Boost", "HP threshold adjustment")
               ps.header("Racial")
               menu.use_racial:render("Use Racial", "Auto-use racial abilities")
               menu.racial_hp:render("Racial HP %", "Use below this HP")
               ps.header("Leveling")
               menu.leveling_conserve_mana:render("Conserve Mana", "Mana-efficient rotation")
               menu.leveling_mana_floor:render("Mana Floor %", "Conservation mode threshold")
           end)

       end)
   end
   ```

6. **`return menu`** — always last line.

---

## THE ps_theme.lua API (ONLY VALID FUNCTIONS)

These are the ONLY functions that exist in `ps_theme.lua`. **Any call to a function not in this list is a bug and must be removed.**

```
ps.tree_node()                          -- returns core.menu.tree_node()
ps.draw_space(win, id)                  -- draws space background, call at top of render
ps.header(label)                        -- renders a section header
ps.checkbox(id, default)                -- wraps core.menu.checkbox
ps.slider_int(mn, mx, def, id)          -- wraps core.menu.slider_int
ps.slider_float(mn, mx, def, id)        -- wraps core.menu.slider_float
ps.keybind(key, toggle, id)             -- wraps core.menu.keybind
ps.combobox(default, id)                -- wraps core.menu.combobox
ps.sep(win)                             -- separator
ps.render_controls(m, title)            -- DO NOT USE (forbidden pattern)
ps.render_targeting(m, tgt_tree)        -- DO NOT USE (forbidden pattern)
ps.render_racial(m, racial_tree)        -- DO NOT USE (forbidden pattern)
ps.render_ooc(m, ooc_tree, is_caster)   -- DO NOT USE (forbidden pattern)
ps.render_esp(m, esp_tree)              -- DO NOT USE (forbidden pattern)
ps.render_defensive(m, def_tree, defs)  -- DO NOT USE (forbidden pattern)
ps.MODE                                 -- table: {"Auto","Solo","Dungeon","Raid"}
```

**`ps.subheader` DOES NOT EXIST.** Any `ps.subheader(...)` call crashes. Replace with `ps.header(...)`.

---

## THE @api/ COMPLIANT MENU ELEMENT API

Only these `core.menu.*` constructors are valid:

```lua
core.menu.checkbox(default_bool, "unique_id_string")
core.menu.slider_int(min, max, default, "unique_id_string")
core.menu.slider_float(min, max, default, "unique_id_string")
core.menu.keybind(key_int, toggle_bool, "unique_id_string")
core.menu.combobox(default_index, "unique_id_string")
core.menu.tree_node()
core.menu.header()       -- used internally by ps.header()
```

Render calls:
```lua
menu.somecheckbox:render("Label", "Tooltip")
menu.somecombobox:render("Label", {option1, option2, ...}, "Tooltip")
menu.someslider:render("Label", "Tooltip")
menu.somekeybind:render("Label", "Tooltip")
tree_node:render("Label", function() ... end)
tree_node:is_open()      -- returns bool, used in draw_space guard
```

---

## KNOWN CRASH BUGS TO FIX

1. **`ps.subheader(...)` → replace with `ps.header(...)`** — affects `EAXHunterBM`
2. **`ps.render_controls(menu, title)` → expand inline** — affects ALL 28 rotations
3. **`ps.render_targeting(menu, tgt_tree)` → expand inline in Advanced tree** — affects ALL 28
4. **`ps.render_racial(menu, racial_tree)` → expand inline in Advanced tree** — affects ALL 28
5. **Orphaned tree nodes** — any `local X_tree = ps.tree_node()` that is declared but whose `:render()` is never called inside `root_tree:render(...)` should be removed from the declaration AND omitted from render. Project Sylvanas crashes on orphaned allocated tree nodes in certain versions.
6. **`def_tree:render("Defensive", function() end)` with empty body** — empty tree nodes are safe BUT if the tree was declared as extra (e.g. HunterBM had a `def_tree` only to put a comment in it), merge its content into the appropriate real tree.

---

## WHAT YOU MUST NOT CHANGE

- **`menu.FIELDNAME = core.menu.TYPE(...)` declarations** — keep ALL of them exactly. Do not rename fields, do not change IDs, do not change defaults.
- **`settings.setup_major_toggle_keybinds(...)` calls** — keep exactly as-is if present.
- **Spec-specific `require(...)` at top** — keep if present (e.g. `local mana_conservator = require("libraries/mana_conservator")`).
- **`EAXDruidFeral`** — NEVER touch this rotation.

---

## COMPLETE LIST OF ROTATIONS TO REWRITE

```
EAXDruidBalance
EAXDruidBear
EAXDruidResto
EAXHunterBM
EAXHunterMM
EAXHunterSurvival
EAXMageArcane
EAXMageFire
EAXMageFrost
EAXPaladinHoly
EAXPaladinProtection
EAXPaladinRetribution
EAXPriestDiscipline
EAXPriestHoly
EAXPriestShadow
EAXPriestSmite
EAXRogueAssassination
EAXRogueCombat
EAXRogueSubtlety
EAXShamanElemental
EAXShamanEnhancement
EAXShamanRestoration
EAXWarlockAffliction
EAXWarlockDemonology
EAXWarlockDestruction
EAXWarriorArms
EAXWarriorFury
EAXWarriorProtection
```

For each one, output the complete rewritten `libraries/menu.lua` file.

---

## WORKED EXAMPLE: How to convert EAXDruidBalance

**BEFORE (broken):** `EAXDruidBalance/libraries/menu.lua` — render() uses `ps.render_controls()`, `ps.render_targeting()`, `ps.render_racial()`, has extra unused tree node variables.

**AFTER (correct):**

```lua
-- +--------------------------------------------------------------------------+
-- |  Eax's Druid Balance  -  Menu  v2.0  -  menu.lua                         |
-- |  Using ps_theme for consistent EAX rotation UI                           |
-- +--------------------------------------------------------------------------+

local mana_conservator = require("libraries/mana_conservator")
local ps       = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")

local menu = {}

-- -- Tree nodes ---------------------------------------------------------------
local root_tree        = ps.tree_node()
local rotation_tree    = ps.tree_node()
local healing_tree     = ps.tree_node()
local defensive_tree   = ps.tree_node()
local utility_tree     = ps.tree_node()
local buffs_tree       = ps.tree_node()
local consumables_tree = ps.tree_node()
local pvp_tree         = ps.tree_node()
local automation_tree  = ps.tree_node()
local dashboard_tree   = ps.tree_node()
local advanced_tree    = ps.tree_node()

-- -- Controls -----------------------------------------------------------------
menu.enabled       = core.menu.checkbox(true,  "eaxdruidbalance_enabled")
menu.toggle_key    = core.menu.keybind(7, false, "eaxdruidbalance_toggle_key")
menu.mode          = core.menu.combobox(1, "eaxdruidbalance_mode")
menu.debug         = core.menu.checkbox(false, "eaxdruidbalance_debug")

-- (... keep ALL original menu.X = core.menu.XXX declarations unchanged ...)

local _win
function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxdruidbalance")
    end

    root_tree:render("Eax's Druid Balance", function()

        -- 1. General
        ps.header("General")
        menu.enabled:render("Enabled", "Enable/disable rotation")
        menu.mode:render("Mode", {"Auto", "PvE", "PvP"}, "Rotation mode selection")
        menu.toggle_key:render("Toggle Key", "Keybind to enable/disable")

        -- 2. Rotation
        rotation_tree:render("Rotation", function()
            ps.header("Forms & Buffs")
            menu.force_moonkin:render("Force Moonkin Form", "Keep Moonkin Form active whenever possible")
            menu.use_faerie_fire:render("Faerie Fire", "Maintain Faerie Fire on target")
            ps.header("Single Target")
            menu.use_moonfire:render("Moonfire", "Maintain Moonfire on target")
            menu.use_insect_swarm:render("Insect Swarm", "Maintain Insect Swarm on target")
            menu.use_starfire:render("Starfire", "Use Starfire as primary nuke")
            menu.use_wrath:render("Wrath", "Use Wrath when moving or conserving mana")
            menu.dot_refresh_seconds:render("Refresh Window (sec)", "Refresh DoTs when below this time")
            menu.bal_dot_refresh:render("DoT Refresh (sec)", "Refresh DoTs at <= this seconds remaining")
            menu.use_force_of_nature:render("Force of Nature", "Use treants during burst")
            menu.force_of_nature_min_ttd:render("Treants Min TTD", "Only use treants if target lives this long (sec)")
            ps.header("Mana Tiers")
            menu.bal_tier1_mana:render("Tier 1 Mana %", "Full rotation above this mana %")
            menu.bal_tier2_mana:render("Tier 2 Mana %", "Partial conserve below this, emergency below Tier 3")
            ps.header("Nature's Grace")
            menu.bal_ng_wrath:render("NG = Wrath Priority", "When Nature's Grace procs, cast Wrath instead of Starfire")
            ps.header("AoE")
            menu.use_hurricane:render("Hurricane", "Channel Hurricane on packs")
            menu.hurricane_min_targets:render("Min Targets", "Use above this count")
            menu.hurricane_mana_floor:render("Mana Floor %", "Don't use below this %")
        end)

        -- 3. Healing & Emergency
        healing_tree:render("Healing & Emergency", function()
            menu.use_innervate:render("Innervate", "Auto-use for mana recovery")
            menu.innervate_mana_pct:render("Innervate Mana %", "Use below this mana %")
            menu.use_tranquility:render("Tranquility", "Emergency self-heal")
            menu.tranquility_hp_pct:render("Tranquility HP %", "Use below this HP %")
        end)

        -- 4. Defensive
        defensive_tree:render("Defensive", function()
            menu.use_barkskin:render("Barkskin", "Damage reduction")
            menu.barkskin_hp_pct:render("Barkskin HP %", "Use below this HP %")
            menu.use_thorns:render("Thorns", "Auto-apply Thorns when missing (OOC)")
            menu.use_motw:render("Mark of the Wild", "Auto-apply MOTW when missing (OOC)")
        end)

        -- 5. Utility
        utility_tree:render("Utility", function()
            menu.use_remove_curse:render("Remove Curse", "Dispel curses")
            menu.use_interrupt:render("Interrupt", "Auto-interrupt enemy casts")
        end)

        -- 6. Buffs
        buffs_tree:render("Buffs", function()
            ps.header("Self Buffs (OOC)")
            menu.use_mark_of_the_wild:render("Mark of the Wild", "Stats buff")
            menu.use_moonkin_form:render("Moonkin Form", "Caster form")
            ps.header("Group Support")
            menu.ooc_rez:render("Auto-Resurrect", "Accept resurrection OOC")
            menu.ooc_group_buff:render("Group Buffs", "Buff party members between pulls")
        end)

        -- 7. Consumables
        consumables_tree:render("Consumables", function()
            ps.header("Recovery Items")
            menu.use_healthstone:render("Healthstone", "Use healthstone when HP is low")
            menu.healthstone_hp_pct:render("Healthstone HP %", "Use below this HP %")
            menu.use_health_potion:render("Healing Potion", "Use healing potion when HP is low")
            menu.health_potion_hp_pct:render("Healing Potion HP %", "Use below this HP %")
            menu.use_mana_potion:render("Mana Potion", "Use mana potion when mana is low")
            menu.mana_potion_pct:render("Mana Potion %", "Use below this mana %")
            ps.header("Sustain (OOC)")
            menu.ooc_drink:render("Auto-Drink", "Drink to restore mana when out of combat")
            menu.drink_threshold:render("Drink Threshold %", "Start drinking below this mana")
            menu.ooc_eat:render("Auto-Eat", "Eat food to restore health when out of combat")
            menu.eat_threshold:render("Eat Threshold %", "Start eating below this HP")
            menu.auto_ooc_food_drink:render("Auto Food/Drink", "Use food and drink OOC when low")
            menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically")
        end)

        -- 8. PvP
        pvp_tree:render("PvP", function()
            ps.header("General")
            menu.pvp_enabled:render("Enable PvP", "Enable PvP rotation features")
            menu.pvp_mode:render("PvP Mode", {"Auto", "PvE Only", "PvP Only"}, "PvP detection mode")
            menu.pvp_use_trinket:render("Use PvP Trinket", "Auto-use PvP trinket when CC'd")
            menu.pvp_defensive_threshold:render("Defensive Threshold %", "Use defensives below this HP% in PvP")
            ps.header("Crowd Control")
            menu.pvp_entangling_roots:render("Entangling Roots", "Root enemy players")
            menu.pvp_hibernate:render("Hibernate", "Sleep beasts and dragonkins")
            menu.pvp_cyclone:render("Cyclone", "Cyclone enemy players")
        end)

        -- 9. Automation
        automation_tree:render("Automation", function()
            ps.header("Burst Cooldowns")
            menu.auto_burst_enabled:render("Auto Burst", "Enable automatic burst cooldowns")
            menu.burst_on_bloodlust:render("Burst on Bloodlust", "Use CDs during Bloodlust/Heroism")
            menu.burst_on_pull:render("Burst on Pull", "Use CDs at combat start")
            menu.burst_on_execute:render("Burst on Execute", "Use CDs during execute phase")
            menu.burst_in_combat:render("Burst Always", "Use CDs whenever available")
            menu.cd_min_ttd:render("Min TTD for CDs", "Don't burst if target dies sooner (sec)")
            ps.header("Trinkets")
            menu.trinket1_mode:render("Trinket 1 Mode", {"Auto", "Burst Only", "Off"}, "When to use trinket 1")
            menu.trinket2_mode:render("Trinket 2 Mode", {"Auto", "Burst Only", "Off"}, "When to use trinket 2")
            menu.trinket_ttd:render("Trinket TTD", "Min target TTD for trinket use (sec)")
            ps.header("Mana Management")
            menu.use_mana_manager:render("Use Mana Manager", "Auto-use innervate/potions/runes")
            menu.innervate_pct:render("Innervate Mana %", "Use Innervate below this %")
            menu.dark_rune_pct:render("Dark Rune %", "Use Dark Rune below this %")
        end)

        -- 10. Dashboard
        dashboard_tree:render("Dashboard (Beta)", function()
            ps.header("Display (Beta)")
            menu.show_dashboard:render("Show Dashboard", "Enable combat dashboard (Beta feature)")
            menu.dashboard_opacity:render("Opacity", "Background opacity")
            menu.dashboard_scale:render("Scale", "UI scale")
            menu.dashboard_x:render("Position X", "Horizontal position")
            menu.dashboard_y:render("Position Y", "Vertical position")
            ps.header("Features")
            menu.show_timer_bars:render("Timer Bars", "Show GCD and swing timers")
            menu.show_action_history:render("Action History", "Show recent casts")
            menu.enable_smart_collapse:render("Smart Collapse", "Hide empty sections")
        end)

        -- 11. Advanced
        advanced_tree:render("Advanced", function()
            ps.header("Targeting")
            menu.focus_priority:render("Focus Priority", "Prioritize focus target")
            menu.combat_self_hp_boost:render("Self HP Boost", "HP threshold adjustment")
            ps.header("Racial")
            menu.use_racial:render("Use Racial", "Auto-use racial abilities")
            menu.racial_hp:render("Racial HP %", "Use below this HP")
            ps.header("Leveling")
            menu.leveling_conserve_mana:render("Conserve Mana", "Mana-efficient rotation")
            menu.leveling_mana_floor:render("Mana Floor %", "Conservation mode threshold")
            ps.header("Wand")
            menu.use_wand:render("Use Wand", "Wand low-HP enemies to preserve mana")
            menu.wand_mana_floor:render("Wand Mana %", "Use below this %")
            menu.wand_at_hp:render("Wand Target HP %", "Only below this HP %")
        end)

    end)
end

return menu
```

---

## STEP-BY-STEP PROCESS FOR EACH ROTATION

For each rotation in the list:

1. **Read the existing `libraries/menu.lua`** in full.
2. **Copy all `menu.X = core.menu.TYPE(...)` declarations verbatim** — nothing changes here.
3. **Keep any `settings.setup_major_toggle_keybinds(...)` call verbatim.**
4. **Keep any spec-specific `require(...)` at the top.**
5. **Rewrite ONLY the tree node declarations and `menu.render()` function** using the Feral pattern.
6. **Map existing tree contents to the standard sections:**
   - Controls (enabled, mode, toggle_key) → inline at top of `root_tree:render()`
   - Rotation/spec abilities → `rotation_tree`
   - Defensive cooldowns → `defensive_tree`
   - Utility/CC/mobility → `utility_tree`
   - OOC buffs/group buffs → `buffs_tree`
   - Potions, food, drink, healthstone → `consumables_tree`
   - PvP settings → `pvp_tree`
   - Burst, trinkets, automation → `automation_tree`
   - Dashboard/HUD → `dashboard_tree`
   - Targeting, racial, leveling → `advanced_tree` (inline, no delegation)
7. **Remove** all calls to `ps.render_controls`, `ps.render_targeting`, `ps.render_racial`, `ps.render_ooc`, `ps.render_esp`, `ps.render_defensive`, `ps.subheader`.
8. **Replace `ps.subheader(X)` with `ps.header(X)`.**
9. **Remove orphaned tree nodes** — if you don't use a tree in render, don't declare it.
10. **Ensure `_win` and `set_window(win)` are present.**
11. **Ensure `return menu` is the last line.**

---

## IMPORTANT NOTES

- **IDs are persistent settings keys.** Never change `"eaxrotationname_field_name"` strings. Changing them would wipe user settings.
- **Do not add new menu fields** that don't already exist in the original file.
- **Do not remove menu fields** that already exist in the original file, even if they seem unused in render — they may be read by `main.lua`.
- **Some rotations have unique extras** (e.g. EAXHunterBM has clip tracker, swing timer settings; EAXPaladinHoly/Protection have `consumables_manager` and `racial_manager` extras; EAXMage* have `flux_constants`). Keep all `menu.X = ...` declarations and include them in the appropriate render tree sections.
- **`menu.debug`** — if declared, render it in the General section: `menu.debug:render("Debug Logging", "Print rotation decisions to console")`
- **EAXPriestSmite** has NO `EAX_Unified` folder — that's intentional, don't add one.
- **Warrior rotations** (`EAXWarriorArms`, `EAXWarriorFury`, `EAXWarriorProtection`) have a custom `dashboard.lua` that differs from others — don't touch it, just fix `menu.lua`.

---

## OUTPUT FORMAT

For each rotation, output:

```
=== REWRITTEN: EAXRotationName/libraries/menu.lua ===
[complete file content here]
```

Process them in this order:
1. EAXDruidBalance
2. EAXDruidBear
3. EAXDruidResto
4. EAXHunterBM  ← CRITICAL: has `ps.subheader` crash bug
5. EAXHunterMM
6. EAXHunterSurvival
7. EAXMageArcane
8. EAXMageFire
9. EAXMageFrost
10. EAXPaladinHoly
11. EAXPaladinProtection
12. EAXPaladinRetribution
13. EAXPriestDiscipline
14. EAXPriestHoly
15. EAXPriestShadow
16. EAXPriestSmite
17. EAXRogueAssassination
18. EAXRogueCombat
19. EAXRogueSubtlety
20. EAXShamanElemental
21. EAXShamanEnhancement
22. EAXShamanRestoration
23. EAXWarlockAffliction
24. EAXWarlockDemonology
25. EAXWarlockDestruction
26. EAXWarriorArms
27. EAXWarriorFury
28. EAXWarriorProtection

---

## VERIFICATION CHECKLIST (apply to each output)

Before finalizing each rewritten file, verify:

- [ ] No call to `ps.render_controls()`
- [ ] No call to `ps.render_targeting()`
- [ ] No call to `ps.render_racial()`
- [ ] No call to `ps.render_ooc()`
- [ ] No call to `ps.render_esp()`
- [ ] No call to `ps.render_defensive()`
- [ ] No call to `ps.subheader()`
- [ ] All `menu.X = core.menu.*` declarations from original are present
- [ ] `local _win` declared
- [ ] `function menu.set_window(win)` present
- [ ] `ps.draw_space(_win, "rotationid")` called at top of `menu.render()` inside guard
- [ ] Every declared tree node has exactly one `:render(...)` call inside `root_tree:render(...)`
- [ ] No tree node declared but never rendered (orphans)
- [ ] `return menu` is last line
- [ ] File starts with a comment header identifying the rotation
