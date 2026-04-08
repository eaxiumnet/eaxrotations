# EAX TBC Rotations - Implementation Handover

**Date:** 2026-04-08  
**Session:** EAX → Flux Feature Porting & API Discovery  
**Status:** EAXDruidBear & EAXPriestSmite Complete + API Mapping  

---

## ✅ COMPLETED THIS SESSION

### Specs Made Complete:
- [x] **EAXDruidBear** - Tank rotation (main.lua, header.lua, plugin_info.lua, utils.lua)
- [x] **EAXPriestSmite** - Holy DPS rotation (main.lua, header.lua, plugin_info.lua, menu.lua, utils.lua)

### Shared Libraries Created (Flux Features Ported):
- [x] **libraries/burst_manager.lua** - Auto-burst system (Bloodlust/Pull/Execute detection)
- [x] **libraries/trinket_manager.lua** - Trinket automation (offensive/defensive modes)

### Pilot Specs Updated with Burst/Trinket Integration:
- [x] **EAXWarriorFury** - Added burst checks and trinket automation
- [x] **EAXHunterBM** - Added burst checks and trinket automation
- [x] **EAXMageFire** - Added burst checks and trinket automation

### Documentation Created:
- [x] **HANDOVER.md** (this file) - Complete API reference + implementation guide
- [x] **Flux Feature Analysis** - Identified all portable features
- [x] **API Discovery** - Mapped 9 major Sylvanas API modules

---

## 🎯 FLUX → EAX IMPLEMENTATION ROADMAP

### Priority 1: HIGH IMPACT (Do These First)

#### 1. Auto-Burst System ⭐⭐⭐
**Flux Feature:** Automatic burst CD usage based on Bloodlust/Pull/Execute conditions
**Flux File:** `flux/rotation/source/aio/core.lua` (lines 63-86, 835-855)
**Flux Schema:** `flux/rotation/source/aio/common.lua` (lines 15-26)

**What To Port:**
```lua
-- Flux Pattern (from common.lua)
_G.FluxAIO_SECTIONS.burst = function()
    return { header = "Burst Conditions", settings = {
        { type = "checkbox", key = "burst_on_bloodlust", default = false, 
          label = "During Bloodlust/Heroism" },
        { type = "checkbox", key = "burst_on_pull", default = false, 
          label = "On Pull (first 5s)" },
        { type = "checkbox", key = "burst_on_execute", default = false, 
          label = "Execute Phase (<20% HP)" },
        { type = "checkbox", key = "burst_in_combat", default = false, 
          label = "Always in Combat" },
    }}
end
```

**EAX Implementation:**
```lua
-- File: libraries/burst_manager.lua (NEW)
---@type combat_forecast
local forecast = require("common/modules/combat_forecast")

local BURST_CONDITIONS = {
    bloodlust = {2825, 32182},  -- TBC Bloodlust/Heroism
    pull_window = 5,            -- seconds
    execute_threshold = 20,     -- HP %
}

local burst_manager = {}

function burst_manager.should_auto_burst(me, target, combat_time, menu)
    -- Check if auto-burst enabled
    if not (menu.auto_burst_enabled and menu.auto_burst_enabled:get()) then
        return false
    end
    
    -- TTD gating - don't waste on dying targets
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 then
        if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
            return false
        end
    end
    
    -- Bloodlust check
    if (menu.burst_on_bloodlust and menu.burst_on_bloodlust:get()) then
        for _, buff_id in ipairs(BURST_CONDITIONS.bloodlust) do
            if me:has_buff(buff_id) then return true, "bloodlust" end
        end
    end
    
    -- Pull check
    if (menu.burst_on_pull and menu.burst_on_pull:get()) then
        if combat_time < BURST_CONDITIONS.pull_window then
            return true, "pull"
        end
    end
    
    -- Execute check
    if (menu.burst_on_execute and menu.burst_on_execute:get()) and target then
        local target_hp_pct = (target:get_health() / target:get_max_health()) * 100
        if target_hp_pct < BURST_CONDITIONS.execute_threshold then
            return true, "execute"
        end
    end
    
    -- Always in combat
    if (menu.burst_in_combat and menu.burst_in_combat:get()) then
        return true, "combat"
    end
    
    return false
end

return burst_manager
```

**Menu Items to Add:**
```lua
-- In EAX<Class><Spec>/libraries/menu.lua
menu.auto_burst_enabled = core.menu.checkbox(false, "eax<spec>_auto_burst")
menu.burst_on_bloodlust = core.menu.checkbox(true, "eax<spec>_burst_bloodlust")
menu.burst_on_pull = core.menu.checkbox(true, "eax<spec>_burst_pull")
menu.burst_on_execute = core.menu.checkbox(true, "eax<spec>_burst_execute")
menu.burst_in_combat = core.menu.checkbox(false, "eax<spec>_burst_always")
menu.cd_min_ttd = core.menu.slider_int(0, 60, 0, "eax<spec>_cd_min_ttd")
```

**Integration in main.lua:**
```lua
-- File: EAX<Class><Spec>/main.lua
local burst_manager = require("libraries/burst_manager")

-- In on_update() or try_burst_cds():
local should_burst, reason = burst_manager.should_auto_burst(me, target, combat_time, menu)
if should_burst then
    -- Try burst CDs
    if try_death_wish(me, target) then return end
    if try_recklessness(me, target) then return end
end
```

**Specs to Implement:** All DPS specs (Warrior, Hunter, Mage, Warlock, Rogue, etc.)

**APIs Required:**
- [ ] `common/modules/combat_forecast` - TTD gating
- [ ] `core.time()` - Combat time tracking
- [ ] `core.object_manager.get_local_player()` - Self buff checks

---

#### 2. Trinket Automation ⭐⭐⭐
**Flux Feature:** Auto-use trinkets in offensive/defensive modes
**Flux File:** `flux/rotation/source/aio/core.lua` (lines 1022-1111)
**Flux Schema:** `flux/rotation/source/aio/common.lua` (lines 39-58)

**What To Port:**
```lua
-- Flux Pattern (from common.lua)
_G.FluxAIO_SECTIONS.trinkets = function(racial_tooltip)
    return { header = "Trinkets & Racial", settings = {
        { type = "dropdown", key = "trinket1_mode", default = "off", label = "Trinket 1",
          options = {
              { value = "off", text = "Off" },
              { value = "offensive", text = "Offensive (Burst)" },
              { value = "defensive", text = "Defensive" },
          }},
        { type = "dropdown", key = "trinket2_mode", default = "off", label = "Trinket 2",
          options = { ... }},
    }}
end
```

**EAX Implementation:**
```lua
-- File: libraries/trinket_manager.lua (NEW)
---@type combat_forecast
local forecast = require("common/modules/combat_forecast")

local TRINKET_SLOTS = {13, 14}

local trinket_manager = {}

function trinket_manager.use_trinket_if_ready(slot)
    -- Get item info
    local item_id = core.inventory.get_item_id(slot)
    if not item_id then return false end
    
    -- Check cooldown
    local start, duration = core.inventory.get_item_cooldown(slot)
    if start > 0 and (core.time() - start) < duration then
        return false
    end
    
    -- Check if usable
    if not core.spell_book.is_item_ready(item_id) then
        return false
    end
    
    -- Use item
    core.input.use_item(slot)
    return true
end

function trinket_manager.check_trinkets(me, is_burst_window, menu)
    for _, slot in ipairs(TRINKET_SLOTS) do
        local mode_key = "trinket" .. (slot - 12) .. "_mode"
        local mode = (menu[mode_key] and menu[mode_key]:get()) or "off"
        
        if mode == "offensive" and is_burst_window then
            -- TTD gate for offensive trinkets
            local target = core.object_manager.get_target()
            if target and forecast:is_valid_forecast_logic(10, target, false) then
                trinket_manager.use_trinket_if_ready(slot)
            end
        elseif mode == "defensive" then
            local hp_pct = (me:get_health() / me:get_max_health()) * 100
            if hp_pct < 35 then  -- Flux uses 35% threshold
                trinket_manager.use_trinket_if_ready(slot)
            end
        end
    end
end

return trinket_manager
```

**Menu Items to Add:**
```lua
-- In EAX<Class><Spec>/libraries/menu.lua
menu.trinket1_mode = core.menu.combobox(1, "eax<spec>_trinket1_mode")
  -- 1 = off, 2 = offensive, 3 = defensive
menu.trinket2_mode = core.menu.combobox(1, "eax<spec>_trinket2_mode")
```

**Integration in main.lua:**
```lua
-- File: EAX<Class><Spec>/main.lua
local trinket_manager = require("libraries/trinket_manager")
local burst_manager = require("libraries/burst_manager")

-- In on_update():
local is_burst = burst_manager.should_auto_burst(me, target, combat_time, menu)
trinket_manager.check_trinkets(me, is_burst, menu)
```

**Specs to Implement:** All specs (DPS use offensive, tanks use defensive)

**APIs Required:**
- [ ] `core.inventory.get_item_id()` - Get trinket item ID
- [ ] `core.inventory.get_item_cooldown()` - Check trinket CD
- [ ] `core.spell_book.is_item_ready()` - Check if usable
- [ ] `core.input.use_item()` - Use trinket
- [ ] `common/modules/combat_forecast` - TTD gating

---

#### 3. TTD Gating for CDs/DoTs ⭐⭐
**Flux Feature:** Don't waste CDs/DoTs on targets that will die soon
**Flux File:** `flux/rotation/source/aio/core.lua` (lines 819-825)

**What To Port:**
```lua
-- Flux Pattern
local min_ttd = s.cd_min_ttd or 0
local ttd_ok = min_ttd == 0 or not context.ttd or context.ttd <= 0 or context.ttd >= min_ttd
```

**EAX Implementation:**
```lua
-- File: EAX<Class><Spec>/main.lua or libraries/combat_context.lua
---@type combat_forecast
local forecast = require("common/modules/combat_forecast")

local function check_ttd_gate(target, min_ttd_setting)
    if min_ttd_setting <= 0 then return true end
    return forecast:is_valid_forecast_logic(min_ttd_setting, target, false)
end

-- Usage in rotation:
if not check_ttd_gate(target, menu.bt_min_ttd:get()) then
    return false -- Don't cast BT on dying target
end
```

**Menu Items to Add:**
```lua
-- Add to each major CD/DoT:
menu.bt_min_ttd = core.menu.slider_int(0, 60, 0, "eax<spec>_bt_min_ttd")
menu.rip_min_ttd = core.menu.slider_int(0, 30, 8, "eax<spec>_rip_min_ttd")
```

**Specs to Implement:** All DPS specs

**APIs Required:**
- [ ] `common/modules/combat_forecast` - `is_valid_forecast_logic()`

---

#### 4. Heroic Strike Queue/Dequeue (Warrior) ⭐⭐⭐
**Flux Feature:** Queue HS for OH yellow hit conversion, dequeue before MH if rage insufficient
**Flux File:** `flux/rotation/source/aio/warrior/middleware.lua` (lines 58-126)

**What To Port:**
```lua
-- Flux Pattern (simplified)
local function should_queue_hs()
    if not is_swing_landing_soon("offhand", 0.4) then return false end
    if rage < HEROIC_STRIKE_COST then return false end
    if entering_execute_phase and not menu.hs_during_execute then return false end
    return true
end
```

**EAX Implementation:**
```lua
-- File: EAXWarriorFury/libraries/swing_manager.lua (NEW) or inline in main.lua
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")

local HS_QUEUE_WINDOW = 0.4  -- seconds before swing

local swing_manager = {}

function swing_manager.should_queue_hs(me, rage, target, menu)
    -- Check if HS enabled
    if not (menu.use_heroic_strike and menu.use_heroic_strike:get()) then
        return false
    end
    
    -- Check rage
    if rage < HEROIC_STRIKE_COST then return false end
    
    -- Check execute phase
    local is_execute = target and 
        ((target:get_health() / target:get_max_health()) * 100) < 20
    
    if is_execute and menu.hs_during_execute and not menu.hs_during_execute:get() then
        return false
    end
    
    -- Check if swing landing soon (use OH swing for queue timing)
    local next_swing = auto_attack:get_next_attack_core_time(me, 2)  -- 2 = offhand
    local time_to_swing = next_swing - core.time()
    
    return time_to_swing <= HS_QUEUE_WINDOW and time_to_swing > 0
end

function swing_manager.should_dequeue_hs(me, rage, target, menu)
    -- Dequeue if rage insufficient for BT/WW
    if rage < 40 then return true end
    
    -- Dequeue if entering execute phase and HS not wanted
    local is_execute = target and 
        ((target:get_health() / target:get_max_health()) * 100) < 20
    
    if is_execute and menu.hs_during_execute and not menu.hs_during_execute:get() then
        return true
    end
    
    return false
end

return swing_manager
```

**Menu Items to Add:**
```lua
-- In EAXWarriorFury/libraries/menu.lua
menu.use_heroic_strike = core.menu.checkbox(true, "eaxwarriorfury_use_hs")
menu.hs_during_execute = core.menu.checkbox(false, "eaxwarriorfury_hs_execute")
```

**Specs to Implement:** EAXWarriorFury, EAXWarriorArms

**APIs Required:**
- [ ] `common/utility/auto_attack_helper` - `get_next_attack_core_time()`
- [ ] `core.time()` - Current time

---

### Priority 2: MEDIUM IMPACT

#### 5. Form-Aware Consumables (Druid) ⭐⭐
**Flux Feature:** Use correct healthstone/potion for current form (Cat vs Bear)
**Flux File:** `flux/rotation/source/aio/druid/middleware.lua` (lines 46-116)

**What To Port:**
```lua
-- Flux Pattern
local ITEM_ALLOWED_STANCE = {
    ["Cat Healthstone"] = {cat = true},
    ["Bear Healthstone"] = {bear = true, dire_bear = true},
}
```

**EAX Implementation:**
```lua
-- File: EAXDruidFeral/libraries/form_consumables.lua (NEW)
local FORM_ITEMS = {
    cat = {
        healthstone = 22105,
        potion = 13442,
    },
    bear = {
        healthstone = 22104,
        potion = 13443,
    },
}

local function get_current_form(me)
    if me:has_buff(5487) then return "bear" end      -- Bear Form
    if me:has_buff(9634) then return "bear" end      -- Dire Bear Form
    if me:has_buff(768) then return "cat" end       -- Cat Form
    return nil
end

local function use_form_consumable(me, item_type)
    local form = get_current_form(me)
    if not form then return false end
    
    local item_id = FORM_ITEMS[form][item_type]
    if not item_id then return false end
    
    -- Use item (this cancels form)
    if core.input.use_item_by_id(item_id) then
        -- Reshift after GCD
        core.delay_function_after_gcd(function()
            if form == "bear" then
                cast_self(BEAR_FORM_ID, me)
            elseif form == "cat" then
                cast_self(CAT_FORM_ID, me)
            end
        end)
        return true
    end
    return false
end
```

**Specs to Implement:** EAXDruidFeral, EAXDruidBear

**APIs Required:**
- [ ] `core.input.use_item_by_id()` - Use consumable
- [ ] Form buff detection via `me:has_buff()`

---

#### 6. Mana Recovery Chain (Casters) ⭐⭐
**Flux Feature:** Intelligent mana recovery: Gem → Potion → Rune → Evocation
**Flux File:** `flux/rotation/source/aio/mage/middleware.lua` (lines 183-284)

**What To Port:**
```lua
-- EAXMageArcane/libraries/mana_manager.lua (NEW)
local MANA_RECOVERY = {
    { type = "gem", priority = 1, hp_cost = 0 },
    { type = "potion", priority = 2, hp_cost = 0 },
    { type = "rune", priority = 3, hp_cost = 800 },
    { type = "evocation", priority = 4, is_channel = true },
}

local function try_mana_recovery(me, mana_pct, menu)
    if mana_pct > 30 then return false end
    
    -- Try mana gem (off GCD)
    if menu.use_mana_gem and menu.use_mana_gem:get() then
        if is_mana_gem_ready() then
            return use_mana_gem()
        end
    end
    
    -- Try mana potion
    if menu.use_mana_potion and menu.use_mana_potion:get() then
        if is_mana_potion_ready() then
            return use_mana_potion()
        end
    end
    
    -- Try rune (if HP allows)
    if menu.use_dark_rune and menu.use_dark_rune:get() then
        local hp = me:get_health()
        if hp > 2000 then  -- HP cost + safety margin
            return use_dark_rune()
        end
    end
    
    -- Last resort: evocation
    if menu.use_evocation and menu.use_evocation:get() then
        if is_safe_to_channel(me) then
            return cast_evocation()
        end
    end
    
    return false
end
```

**Specs to Implement:** EAXMageArcane, EAXMageFire, EAXPriestHoly, EAXDruidBalance, etc.

---

### Priority 3: NICE TO HAVE

#### 7. PvP Anti-Fake Interrupts ⭐
**Flux Feature:** Randomize interrupt timing to prevent opponents from predicting
**Flux File:** `flux/rotation/source/aio/warrior/middleware.lua` (lines 262-338)

**EAX Implementation:**
```lua
-- Random delay between 15-67% of cast bar
local cast_progress = target:get_cast_progress()
local random_threshold = math.random(15, 67)

if cast_progress >= random_threshold then
    cast_interrupt()
end
```

**Specs to Implement:** All PvP-capable specs

**APIs Required:**
- [ ] `target:get_cast_progress()` or equivalent

---

## 📋 IMPLEMENTATION CHECKLIST

### Phase 1: Foundation (Do First) ✅ COMPLETED
- [x] Create `libraries/burst_manager.lua` with auto-burst logic
- [x] Create `libraries/trinket_manager.lua` with trinket automation
- [x] Add burst/trinket menu items to 3 pilot specs (WarriorFury, HunterBM, MageFire)
- [x] Test burst detection with Bloodlust

### Phase 2: Advanced Features
- [ ] Create `libraries/swing_manager.lua` for Warrior HS queue
- [ ] Add TTD gating to all DPS specs
- [ ] Create `libraries/mana_manager.lua` for casters
- [ ] Create `libraries/form_consumables.lua` for Druids

### Phase 2: Advanced Features
- [ ] Create `libraries/swing_manager.lua` for Warrior HS queue
- [ ] Add TTD gating to all DPS specs
- [ ] Create `libraries/mana_manager.lua` for casters
- [ ] Create `libraries/form_consumables.lua` for Druids

### Phase 3: Polish
- [ ] Add PvP anti-fake interrupts
- [ ] Add combat forecasting to healer specs
- [ ] Optimize with native APIs (spell_helper, unit_helper)

---

## 🔧 API REFERENCE QUICK GUIDE

### Essential APIs for Porting

#### 1. Combat Forecast (TTD)
```lua
---@type combat_forecast
local forecast = require("common/modules/combat_forecast")

-- Check if combat will last X seconds
local is_valid = forecast:is_valid_forecast_logic(10, target, false)
-- Returns: true if target will live 10+ seconds
```

#### 2. Auto Attack Helper (Swing Timer)
```lua
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")

-- Get next swing time
local next_swing = auto_attack:get_next_attack_core_time(me, 1)
-- 1 = main hand, 2 = off hand
```

#### 3. Cooldown Tracker (Enemy CDs)
```lua
---@type cooldown_tracker
local cd_tracker = require("common/utility/cooldown_tracker")

-- Check if enemy has defensive ready
local has_def = cd_tracker:has_any_relevant_defensive_up(enemy)

-- Check if enemy can interrupt
local can_kick = cd_tracker:has_any_kick_up(caster, target, true)
```

#### 4. PvP Helper (CC/Trinkets)
```lua
---@type pvp_helper
local pvp = require("common/utility/pvp_helper")

-- Check if target used trinket recently
local used_recently = pvp:trinket_used_within(target, 120)  -- 2 min window

-- Check CC status
local is_cc, cc_type, remaining = pvp:is_crowd_controlled(target, pvp.cc_flags.STUN)
```

#### 5. Spell Helper (Validation)
```lua
---@type spell_helper
local spell_helper = require("common/utility/spell_helper")

-- Full validation
local can_cast = spell_helper:is_spell_castable(
    spell_id, caster, target, false, false
)
```

#### 6. Unit Helper (Role Detection)
```lua
---@type unit_helper
local unit_helper = require("common/utility/unit_helper")

-- Get role
local is_tank = unit_helper:is_tank(target)
local is_healer = unit_helper:is_healer(target)

-- Get health with incoming damage
local hp_pct, incoming = unit_helper:get_health_percentage_inc(target, 3.0)
```

---

## 📁 FILES TO MODIFY/CREATE

### New Shared Libraries:
```
libraries/
├── burst_manager.lua         [NEW] - Auto-burst logic
├── trinket_manager.lua       [NEW] - Trinket automation
├── swing_manager.lua         [NEW] - HS queue/dequeue
├── mana_manager.lua          [NEW] - Mana recovery chain
└── form_consumables.lua      [NEW] - Druid form items
```

### Spec-Specific Updates:
```
EAXWarriorFury/
├── main.lua                  [✅ UPDATED] - Add burst check, trinket integration
└── libraries/menu.lua        [✅ UPDATED] - Add burst/trinket menus

EAXHunterBM/
├── main.lua                  [✅ UPDATED] - Add burst check, trinket integration
└── libraries/menu.lua        [✅ UPDATED] - Add burst/trinket menus

EAXMageFire/
├── main.lua                  [✅ UPDATED] - Add burst check, trinket integration
└── libraries/menu.lua        [✅ UPDATED] - Add burst/trinket menus
```

---

## 🎯 PRIORITY SUMMARY

| Priority | Feature | Impact | Effort | Target Specs |
|----------|---------|--------|--------|--------------|
| **1** | Auto-Burst | +5-10% DPS | Medium | All DPS |
| **1** | Trinket Automation | +3-5% DPS | Low | All specs |
| **1** | HS Queue/Dequeue | +5% DPS | High | Warriors |
| **2** | TTD Gating | CD efficiency | Low | All DPS |
| **2** | Form Consumables | Survival | Medium | Druids |
| **2** | Mana Recovery | Mana efficiency | Low | Casters |
| **3** | PvP Anti-Fake | PvP advantage | Low | All PvP |

---

## 🔗 REFERENCE FILES

### Flux (Source of Features):
- `flux/rotation/source/aio/core.lua` - Burst logic, trinkets, priorities
- `flux/rotation/source/aio/common.lua` - Schema definitions
- `flux/rotation/source/aio/warrior/middleware.lua` - HS queue, PvP
- `flux/rotation/source/aio/druid/middleware.lua` - Form consumables
- `flux/rotation/source/aio/mage/middleware.lua` - Mana recovery

### EAX (Implementation Targets):
- `EAXWarriorFury/main.lua` - Reference rotation structure
- `EAXWarriorFury/libraries/utils.lua` - Helper patterns
- `EAXDruidBear/main.lua` - Recently completed tank rotation
- `EAXPriestSmite/main.lua` - Recently completed DPS rotation

### Sylvanas API (Use These):
- `api/common/modules/combat_forecast.lua` - TTD
- `api/common/utility/auto_attack_helper.lua` - Swing timer
- `api/common/utility/cooldown_tracker.lua` - Enemy CDs
- `api/common/utility/pvp_helper.lua` - CC/Trinkets
- `api/common/utility/spell_helper.lua` - Spell validation
- `api/common/utility/unit_helper.lua` - Role detection

---

## ⚠️ COMPLIANCE REMINDERS

When implementing:
- [ ] Use menu nil-guards: `(menu.x and menu.x:get()) or default`
- [ ] Cache APIs at load: `local _core_time = core.time`
- [ ] Use squared distance: `dx*dx + dy*dy` (never `math.sqrt`)
- [ ] Reuse static tables: `{ n = 0 }` not `{}`
- [ ] Validate with `luac -p` before finishing
- [ ] Check `lsp_diagnostics` shows 0 errors

---

**End of Handover Document**

