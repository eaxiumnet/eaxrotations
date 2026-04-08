# EAX Menu Wiring Issues - Handover Document

**Session Date:** 2026-04-08  
**Original Task:** Verify menu wiring across all 27 EAX rotation plugins  
**Status:** Verification Complete, Fixes Pending  
**Handover For:** New session to implement fixes

---

## Executive Summary

Comprehensive verification of 27 EAX TBC rotation plugins revealed **menu wiring issues in 18 specs**. The original verification report overcounted issues (claimed 165+, actual ~60-80). This document provides corrected findings with exact locations and API-compliant fixes.

### Critical Finding
Many menu settings "don't do stuff when enabled/disabled" because:
1. Menu items are **accessed in code but never defined** in menu.lua
2. **Wrong names/prefixes** cause nil returns (e.g., `frost_use_icy_veins` vs `use_icy_veins`)
3. Some items defined but never wired to rotation logic (orphaned - acceptable)

---

## API Reference (from .api/menu.lua)

### Menu Item Types & Methods

```lua
-- checkbox
---@field get_state fun():boolean
---@field render fun(self:checkbox, label:string, tooltip:string|nil):nil

-- slider_int
---@field get fun():number
---@field render fun(self:slider_int, label:string, tooltip:string|nil):nil

-- combobox
---@field get fun():number  -- Returns 1-based index
---@field render fun(self:combobox, label:string, options:table, tooltip:string|nil):nil

-- keybind
---@field get_key_code fun():integer
---@field render fun(self:keybind, label:string, tooltip:string|nil, add_separator:boolean|nil):nil
```

### Nil-Guard Pattern (REQUIRED)
```lua
-- For checkboxes (use :get_state())
local enabled = (menu.enabled and menu.enabled:get_state()) or false

-- For sliders/comboboxes (use :get())
local threshold = (menu.threshold and menu.threshold:get()) or 50

-- For keybinds (use :get_key_code())
local key = (menu.toggle_key and menu.toggle_key:get_key_code()) or 0
```

---

## Detailed Issue Log

### Priority 0 (Critical - Will Crash or Always Return Default)

#### 1. EAXPaladinProtection - 8 Issues

**Location:** `EAXPaladinProtection/libraries/menu.lua` & `main.lua` & `middleware_manager.lua` & `dashboard.lua`

**Issues:**

**A. Missing Definitions (5 items)**

1. `menu.seal_choice`
   - **Accessed in:** `main.lua:106`
   - **Code:**
     ```lua
     local seal_choice = (menu.seal_choice and menu.seal_choice:get()) or 1
     ```
   - **Fix:** Add to menu.lua:
     ```lua
     menu.seal_choice = core.menu.combobox(1, "eaxpaladinprotection_seal_choice")
     ```

2. `menu.use_seal_of_wisdom_low_mana`
   - **Accessed in:** `main.lua:110`
   - **Code:**
     ```lua
     if menu.use_seal_of_wisdom_low_mana and menu.use_seal_of_wisdom_low_mana:get_state() then
     ```
   - **Fix:**
     ```lua
     menu.use_seal_of_wisdom_low_mana = core.menu.checkbox(false, "eaxpaladinprotection_use_seal_of_wisdom_low_mana")
     ```

3. `menu.seal_of_wisdom_mana_pct`
   - **Accessed in:** `main.lua:112`
   - **Code:**
     ```lua
     local threshold = ((menu.seal_of_wisdom_mana_pct and menu.seal_of_wisdom_mana_pct:get()) or 20) / 100
     ```
   - **Fix:**
     ```lua
     menu.seal_of_wisdom_mana_pct = core.menu.slider_int(5, 50, 20, "eaxpaladinprotection_seal_of_wisdom_mana_pct")
     ```

4. `menu.use_gift_of_the_naaru`
   - **Accessed in:** `middleware_manager.lua:49`
   - **Code:**
     ```lua
     local use_gift_of_the_naaru = (menu.use_gift_of_the_naaru and menu.use_gift_of_the_naaru:get_state()) or false
     ```
   - **Fix:**
     ```lua
     menu.use_gift_of_the_naaru = core.menu.checkbox(true, "eaxpaladinprotection_use_gift_of_the_naaru")
     ```

5. `menu.gift_of_the_naaru_hp_pct`
   - **Accessed in:** `middleware_manager.lua:81`
   - **Code:**
     ```lua
     local naaru_threshold = (menu.gift_of_the_naaru_hp_pct and menu.gift_of_the_naaru_hp_pct:get()) or 50
     ```
   - **Fix:**
     ```lua
     menu.gift_of_the_naaru_hp_pct = core.menu.slider_int(10, 80, 50, "eaxpaladinprotection_gift_of_the_naaru_hp_pct")
     ```

**B. Wrong Names (3 items)**

6. `menu.dashboard_enabled` vs `menu.show_dashboard`
   - **Accessed in:** `dashboard.lua:565`
   - **Defined in:** `menu.lua:114` as `show_dashboard`
   - **Code:**
     ```lua
     if menu.dashboard_enabled then
     ```
   - **Fix:** Change in dashboard.lua OR rename in menu.lua to match:
     ```lua
     -- Option 1: Change dashboard.lua
     if menu.show_dashboard then
     
     -- Option 2: Change menu.lua
     menu.dashboard_enabled = core.menu.checkbox(true, "eaxpaladinprotection_dashboard_enabled")
     ```

7. `menu.dashboard_color_bg`
   - **Accessed in:** `dashboard.lua:600`
   - **Fix:**
     ```lua
     menu.dashboard_color_bg = core.menu.color_picker({10, 12, 18, 190}, "eaxpaladinprotection_dashboard_color_bg")
     ```

8. `menu.dashboard_color_border`
   - **Accessed in:** `dashboard.lua:607`
   - **Fix:**
     ```lua
     menu.dashboard_color_border = core.menu.color_picker({100, 80, 180, 180}, "eaxpaladinprotection_dashboard_color_border")
     ```

---

#### 2. EAXMageFrost - 6 Issues

**Location:** `EAXMageFrost/libraries/menu.lua` & `main.lua`

**Issues:**

**A. Wrong Prefixes (3 items - accessed with `frost_` prefix but defined without)**

1. `menu.frost_use_icy_veins` vs `menu.use_icy_veins`
   - **Accessed in:** `main.lua:113`
   - **Code:**
     ```lua
     if not (menu.frost_use_icy_veins and menu.frost_use_icy_veins:get()) then return false end
     ```
   - **Defined in:** `menu.lua:69,90` as `use_icy_veins` (also DUPLICATE!)
   - **Fix Options:**
     - Option 1: Change main.lua to use `menu.use_icy_veins`
     - Option 2: Change menu.lua to define `frost_use_icy_veins` instead

2. `menu.frost_use_water_elemental` vs `menu.use_water_elemental`
   - **Accessed in:** `main.lua:132`
   - **Defined in:** `menu.lua:89` as `use_water_elemental`
   - **Fix:** Change main.lua to use `menu.use_water_elemental`

3. `menu.frost_use_cold_snap` vs `menu.use_cold_snap`
   - **Accessed in:** `main.lua:150`
   - **Defined in:** `menu.lua:70,96` as `use_cold_snap` (also DUPLICATE!)
   - **Fix:** Change main.lua to use `menu.use_cold_snap`

**B. Missing Definitions (1 item)**

4. `menu.cd_min_ttd`
   - **Accessed in:** `main.lua:118,136,154,179`
   - **Code:**
     ```lua
     local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
     ```
   - **Fix:**
     ```lua
     menu.cd_min_ttd = core.menu.slider_int(0, 60, 0, "eaxmagefrost_cd_min_ttd")
     ```

**C. Duplicates (2 items - should be removed)**

5. `menu.use_icy_veins` - Defined twice (menu.lua:69 and 90)
6. `menu.use_cold_snap` - Defined twice (menu.lua:70 and 96)
   - **Fix:** Remove duplicate lines 90 and 96

---

### Priority 1 (High - Feature Not Working)

#### 3. EAXWarriorFury - 13 Issues

**Location:** `EAXWarriorFury/libraries/menu.lua` & `main.lua`

**Missing Menu Definitions (12 items):**

1. `menu.rampage_refresh_threshold` (main.lua:116)
2. `menu.cancelaura_hp_threshold` (main.lua:139)
3. `menu.cancel_pws` (main.lua:140)
4. `menu.cancel_bop` (main.lua:149)
5. `menu.pvp_cc_break_check` (main.lua:162)
6. `menu.use_bloodthirst` (main.lua:184) - **CRITICAL**: Core rotation spell!
7. `menu.execute_use_bt` (main.lua:185)
8. `menu.use_whirlwind` (main.lua:201) - **CRITICAL**: Core rotation spell!
9. `menu.execute_use_ww` (main.lua:203)
10. `menu.use_slam` (main.lua:226)
11. `menu.use_hamstring` (main.lua:241)
12. `menu.execute_use_hs` (main.lua:253)

**Wrong Name (1 item):**

13. `menu.hs_rage_threshold` should be `menu.heroic_strike_rage`
    - **Accessed in:** main.lua:259
    - **Defined in:** menu.lua as `heroic_strike_rage`

**Note:** Many accesses lack nil guards but follow the pattern from AGENTS.md

---

### Priority 2 (Medium - UI/Feature Gaps)

#### 4. EAXDruidFeral - 5 Issues

**Missing (2 items):**
- `menu.pvp_entangling_roots` (main.lua)
- `menu.pvp_hibernate` (main.lua)

**Wrong Names (3 items):**
- `menu.use_prowl_opener` vs `menu.use_prowl`
- `menu.use_mangle` vs `menu.use_mangle_cat`
- `menu.pvp_cyclone` naming mismatch

---

## Quick Reference: Fix Patterns

### Pattern 1: Add Missing Menu Item
```lua
-- In libraries/menu.lua, add appropriate section:

-- For checkbox toggles
menu.use_feature_name = core.menu.checkbox(true, "eaxspecname_use_feature_name")

-- For percentage sliders (0-100)
menu.feature_threshold = core.menu.slider_int(0, 100, 50, "eaxspecname_feature_threshold")

-- For comboboxes (1-based index)
menu.feature_mode = core.menu.combobox(1, "eaxspecname_feature_mode")

-- For keybinds
menu.feature_key = core.menu.keybind(7, false, "eaxspecname_feature_key")

-- For color pickers (RGBA table)
menu.feature_color = core.menu.color_picker({r, g, b, a}, "eaxspecname_feature_color")
```

### Pattern 2: Fix Wrong Name in Code
```lua
-- In main.lua or other files, change:
-- WRONG:
if menu.wrong_name and menu.wrong_name:get_state() then

-- CORRECT:
if menu.correct_name and menu.correct_name:get_state() then
```

### Pattern 3: Fix Wrong Prefix
```lua
-- WRONG (in main.lua):
menu.frost_use_icy_veins:get()

-- CORRECT:
menu.use_icy_veins:get()
```

---

## Specs by Priority

### Priority 0 (Fix Immediately - Crash/Malfunction)
- EAXPaladinProtection (8 issues)
- EAXMageFrost (6 issues)
- EAXWarriorFury (13 issues)
- EAXMageArcane (12 missing)
- EAXMageFire (8 missing + 5 wrong names)

### Priority 1 (Fix Soon - Feature Not Working)
- EAXDruidBalance (6 missing)
- EAXDruidFeral (5 issues)
- EAXDruidResto (5 missing)
- EAXHunterMM (11 missing)
- EAXHunterSurvival (10 missing)
- EAXPaladinHoly (13 missing + wrong names)
- EAXPaladinRetribution (4 missing)
- EAXPaladinProtection (already listed in P0)
- EAXShamanRestoration (15 missing + wrong names + wrong accessors)
- EAXWarlockAffliction (1 missing)
- EAXWarlockDemonology (5 missing)
- EAXWarlockDestruction (3 missing)
- EAXWarriorArms (6 missing)
- EAXWarriorProtection (14 missing)

### Priority 2 (Clean - No Critical Issues)
- EAXDruidBear (clean)
- EAXHunterBM (clean)
- EAXPriestDiscipline (clean)
- EAXPriestHoly (clean)
- EAXPriestShadow (clean)
- EAXPriestSmite (clean)
- EAXRogueAssassination (clean)
- EAXRogueCombat (clean)
- EAXRogueSubtlety (clean)
- EAXShamanElemental (clean)
- EAXShamanEnhancement (clean)

---

## Next Steps

1. **Review this document** with user to confirm fix approach
2. **Option A:** Fix all 18 specs in parallel (estimated 12-16 hours)
3. **Option B:** Pilot fix Mage specs only (3 specs, 2-3 hours)
4. **Option C:** Fix only P0 specs (5 specs, 4-6 hours)

Each fix requires:
1. Read menu.lua to find insertion point
2. Add missing definitions OR fix wrong names
3. Remove duplicates if any
4. Run `luac -p` to validate syntax
5. Run `lsp_diagnostics` to verify no errors

---

## Files Modified in This Session

- `C:\newbot\scripts\MENU_WIRING_VERIFICATION_REPORT.md` - Created (comprehensive report)

## Related Documentation

- `AGENTS.md` - Project conventions and patterns
- `.api/menu.lua` - API reference for menu item types
- `codemap.md` - Architecture overview

---

**End of Handover Document**

*For questions or to continue work, reference the original verification task and this handover document.*
