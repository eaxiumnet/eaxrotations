# EAX Dashboard Enhancement - Flux Features Port

**Status:** Ready for Implementation  
**Priority:** High  
**Scope:** Add 6 key flux dashboard features to EAX  
**Estimated Effort:** 4-6 hours  

---

## 🎯 OBJECTIVE

Port the following features from flux's dashboard to EAX:
1. **Energy Tick Tracker** (Visual sweep + marker for energy users)
2. **Timer Bars** (GCD + Swing timer bars)
3. **Action History** (Last 6 actual casts via CLEU)
4. **Combo Point Pips** (5-square visual for rogues/feral)
5. **Threat Bar** (Color-coded threat percentage)
6. **Smart Section Collapsing** (Hide empty sections)

---

## 📋 CURRENT STATE vs TARGET

### Current EAX Dashboard
- Buff/debuff icons with row wrapping (6 per row)
- Only shows active auras (inactive hidden)
- Resource bar (rage/mana/energy)
- Cooldown tracking
- Custom lines support
- **10Hz update throttling**

### Target Features (from flux)
| Feature | flux Implementation | EAX Target |
|---------|---------------------|------------|
| Energy Tick | Visual sweep dot + marker | Add to resource bar |
| Timer Bars | GCD + Swing, frame-rate updates | Add below resource bar |
| Action History | CLEU ring buffer, 6 slots | Add below priority |
| Combo Points | 5 colored pips | Add for rogues/druids |
| Threat | Progress bar, color-coded | Add below target info |
| Smart Collapse | Sections hide when empty | Implement for all sections |

---

## 🔧 TECHNICAL APPROACH

### 1. ENERGY TICK TRACKER

**flux Logic:**
```lua
-- Detect energy tick by watching for +20 energy increase
-- Show sweep dot that crosses bar every 2 seconds
-- Show marker where next tick lands
```

**EAX Implementation:**
```lua
-- Add to dashboard.lua
local energy_tick_tracker = {
    last_energy = 0,
    last_tick_time = 0,
    confident = false,
}

-- In update_resources():
local current_energy = dashboard._cached_resources.current
local delta = current_energy - energy_tick_tracker.last_energy
if delta > 0 and delta <= 25 then
    energy_tick_tracker.last_tick_time = _core_time()
    energy_tick_tracker.confident = true
end
energy_tick_tracker.last_energy = current_energy

-- In render():
-- Draw sweep dot positioned by: (time_since_tick % 2) / 2
-- Draw marker at: (current_energy + 20) / max_energy position
```

**Files to Modify:**
- `libraries/dashboard.lua` - Add tracker state + render

---

### 2. TIMER BARS (GCD + SWING)

**flux Logic:**
- GCD bar: Shows remaining global cooldown
- Swing bar: Shows next auto-attack time
- Updates at **frame rate** for smooth animation
- Different colors: GCD = accent, Swing = orange

**EAX Implementation:**
```lua
-- Add timer bar state
local timer_bars = {
    gcd = { remaining = 0, total = 1.5 },
    swing = { remaining = 0, total = 2.0 }
}

-- In update() at 10Hz:
local gcd_start, gcd_duration = _get_gcd()
if gcd_start and gcd_duration then
    timer_bars.gcd.remaining = (gcd_start + gcd_duration) - _core_time()
    timer_bars.gcd.total = gcd_duration
end

-- In render() at frame rate:
-- Draw background bar
-- Draw fill based on remaining/total ratio
-- Update every frame for smooth animation
```

**API to Use:**
```lua
local _get_gcd = core.spell_book.get_global_cooldown
-- Returns: start_time, duration (or nil if no GCD)
```

**Files to Modify:**
- `libraries/dashboard.lua` - Add timer bars + frame-rate update

---

### 3. ACTION HISTORY (CLEU)

**flux Logic:**
- Registers for `COMBAT_LOG_EVENT_UNFILTERED`
- Tracks `SPELL_CAST_SUCCESS` from player
- Ring buffer of 6 most recent casts
- Fade effect: newest = 100% alpha, oldest = 30%

**EAX Implementation:**
```lua
-- Add to dashboard.lua
local action_history = {
    max = 6,
    buffer = {},
    count = 0
}

-- Register CLEU callback (once at init)
function dashboard.register_cleu()
    if core.register_on_spell_cast_callback then
        core.register_on_spell_cast_callback(function(data)
            -- data contains: spell_id, caster, target, spell_cast_time
            if data.caster and data.caster:is_valid() then
                local me = _get_local_player()
                if me and data.caster == me then
                    -- Push to ring buffer
                    for i = action_history.max, 2, -1 do
                        action_history.buffer[i] = action_history.buffer[i-1]
                    end
                    action_history.buffer[1] = {
                        spell_id = data.spell_id,
                        name = get_spell_name(data.spell_id),
                        icon = get_spell_icon(data.spell_id)
                    }
                    action_history.count = math.min(action_history.count + 1, action_history.max)
                end
            end
        end)
    end
end

-- In render():
for i = 1, action_history.max do
    if i <= action_history.count then
        local alpha = (i == 1) and 1.0 or (0.8 - (i-2)*0.12)
        draw_icon_with_alpha(action_history.buffer[i].icon, alpha)
    end
end
```

**API to Use:**
```lua
-- Option 1: Use Sylvanas spell cast callback
core.register_on_spell_cast_callback(callback)

-- Option 2: Use IZI SDK event callbacks (if available)
local izi = require("common/izi_sdk")
izi.on_spell_success(callback)
```

**Files to Modify:**
- `libraries/dashboard.lua` - Add CLEU registration + history render

---

### 4. COMBO POINT PIPS

**flux Logic:**
- 5 small squares below resource bar
- Fills red when you have that many points
- Shows for Rogue + Feral Cat only

**EAX Implementation:**
```lua
-- Add to dashboard_config.lua per spec:
show_combo_points = true  -- for rogues/feral

-- Add to dashboard.lua render():
if dashboard.config.show_combo_points then
    local me = dashboard._cached_player
    local cp = 0
    if me and me.get_combo_points then
        cp = me:get_combo_points()
    end
    
    for i = 1, 5 do
        local color = (i <= cp) and {0.9, 0.15, 0.15} or {0.15, 0.15, 0.15}
        draw_small_square(color)
    end
end
```

**API to Use:**
```lua
-- From izi_sdk or unit methods
local me = core.object_manager.get_local_player()
if me and me.get_combo_points then
    local cp = me:get_combo_points()
end
```

**Files to Modify:**
- `libraries/dashboard_config.lua` - Add `show_combo_points` flag
- `libraries/dashboard.lua` - Add pips render

---

### 5. THREAT BAR

**flux Logic:**
- Shows threat percentage vs target
- Green (<80%) → Orange (80-100%) → Red (100%+)
- Only shows when you have a target

**EAX Implementation:**
```lua
-- Add to dashboard.lua update():
if dashboard._cached_target and dashboard._cached_target:is_valid() then
    -- Use Sylvanas threat API
    local threat_pct = 0
    if dashboard._cached_target.get_threat_percentage then
        threat_pct = dashboard._cached_target:get_threat_percentage(me)
    end
    dashboard._cached_threat = threat_pct
end

-- In render():
if dashboard._cached_threat and dashboard._cached_threat > 0 then
    local color = (threat_pct >= 100) and THEME.threat_red
        or (threat_pct >= 80) and THEME.threat_orange
        or THEME.threat_green
    draw_progress_bar(dashboard._cached_threat / 130, color)
end
```

**API to Use:**
```lua
-- Check if Sylvanas has threat API
-- If not available, skip this feature or use aggro detection
```

**Files to Modify:**
- `libraries/dashboard.lua` - Add threat tracking + render

---

### 6. SMART SECTION COLLAPSING

**flux Logic:**
- Cooldowns section: Always show if configured
- Buffs section: Always show if configured  
- Debuffs section: **Hide when no target AND all debuffs are target-based**
- Recent casts section: **Hide when no history**
- Frame auto-resizes to content

**EAX Implementation:**
```lua
-- In dashboard.lua render():

-- Check if we should show debuffs
local show_debuffs = debuff_count > 0
if show_debuffs and not dashboard._cached_target then
    local all_target_based = true
    for _, debuff in ipairs(dashboard.config.debuffs) do
        if not debuff.target then
            all_target_based = false
            break
        end
    end
    if all_target_based then
        show_debuffs = false
    end
end

-- Calculate dynamic height
local total_height = calculate_height_based_on_visible_sections()
dashboard:set_height(total_height)
```

**Files to Modify:**
- `libraries/dashboard.lua` - Add section visibility logic + dynamic height

---

## 🎨 VISUAL SPECIFICATIONS

### Timer Bars Layout
```
[Resource Bar]
[GCD Bar      ]  <-- Below resource, 8px height, accent color
[Swing Bar    ]  <-- Below GCD, 8px height, orange color
```

### Combo Point Pips Layout
```
[Resource Bar]
[● ● ● ● ●]      <-- 5 small squares, 8px each, red when filled
```

### Action History Layout
```
[Cooldown Icons]
Recent: [icon][icon][icon][icon][icon][icon]  <-- 6 icons, fading alpha
```

### Threat Bar Layout
```
[Target Info]
[Threat Bar     ]  <-- Below target, 8px height, color-coded
```

---

## 📁 FILE STRUCTURE CHANGES

### Modified Files:

**1. libraries/dashboard.lua (29 specs + shared)**
- Add energy tick tracker state
- Add action history ring buffer
- Add CLEU registration
- Add timer bar state + frame-rate update
- Add combo point pips render
- Add threat tracking
- Add smart section collapsing
- Add dynamic height calculation

**2. libraries/dashboard_config.lua (29 specs)**
- Add `show_combo_points` flag (for rogues/druids)
- Add `secondary_resource` config (for druids with mana+energy)
- Add `show_threat` flag (for tanks)

**3. menu.lua (29 specs)**
- Add toggles for new features:
  - "Show Energy Tick"
  - "Show GCD Bar"
  - "Show Swing Timer"
  - "Show Action History"
  - "Show Combo Points"
  - "Show Threat Bar"

---

## 🔌 SUPPORTED APIs (from api/common/)

### Required Modules:
```lua
-- For buff/debuff tracking
local buff_manager = require("common/modules/buff_manager")

-- For spell info
local izi = require("common/izi_sdk")

-- For spell queue introspection (optional)
local spell_queue = require("common/modules/spell_queue")
```

### Game Object Methods:
```lua
-- Buff/Debuff data (from izi_sdk patching)
unit:get_buff_data(spell_id)
unit:has_buff(spell_id)
unit:buff_remains(spell_id)
unit:get_debuff_data(spell_id)
unit:has_debuff(spell_id)
unit:debuff_remains(spell_id)

-- Resource queries
unit:get_power(power_type)
unit:get_max_power(power_type)

-- Combo points (if available)
unit:get_combo_points()

-- Threat (if available)
unit:get_threat_percentage(target)
```

### Core Callbacks:
```lua
-- Spell cast tracking
core.register_on_spell_cast_callback(callback)

-- Combat log (if available)
core.register_on_combat_log_callback(callback)
```

---

## ⚠️ CHALLENGES & SOLUTIONS

### Challenge 1: Frame-Rate Updates
**Problem:** Timer bars need smooth animation at 60fps, but dashboard updates at 10Hz.

**Solution:** Split updates:
- Data updates at 10Hz (throttled)
- Animation updates at frame rate (in render callback)
- Store animation state in dashboard table

### Challenge 2: CLEU/Event Registration
**Problem:** Need to track actual spell casts, not just recommendations.

**Solution:** Use `core.register_on_spell_cast_callback` - registers once at init and persists.

### Challenge 3: Energy Tick Detection
**Problem:** Need to detect 2s energy ticks reliably.

**Solution:**
- Watch for +20 energy increase (or less if near cap)
- Validate: delta > 0 AND delta <= 25
- Ignore ticks after stance changes (1s grace period)
- Mark tracker as "confident" after detecting first tick

### Challenge 4: Threat API Availability
**Problem:** Threat API may not be available in all Sylvanas versions.

**Solution:** Feature-gate with pcall:
```lua
local ok, threat = pcall(function()
    return target:get_threat_percentage(me)
end)
if ok then
    -- Show threat bar
end
```

---

## 🧪 TESTING CHECKLIST

### Energy Tick Tracker:
- [ ] Create Rogue/Feral druid
- [ ] Watch energy bar - sweep dot should appear
- [ ] Verify marker shows where +20 will land
- [ ] Test stance change - should reset tracker
- [ ] Verify confident flag after first tick detected

### Timer Bars:
- [ ] Cast any spell - GCD bar should fill
- [ ] Use auto-attack - Swing bar should track
- [ ] Verify smooth animation (not choppy)
- [ ] Test with haste buffs - GCD should shorten

### Action History:
- [ ] Cast 6 different spells
- [ ] Verify all 6 appear in history
- [ ] Check fade effect (oldest should be dimmer)
- [ ] Verify spell icons are correct
- [ ] Test with trinkets/items

### Combo Points:
- [ ] Create Rogue
- [ ] Build 5 combo points
- [ ] Verify all 5 pips fill red
- [ ] Spend points - verify pips clear
- [ ] Test with Feral Cat form

### Threat Bar:
- [ ] Target an enemy
- [ ] Deal damage - threat should increase
- [ ] Verify color changes: Green → Orange → Red
- [ ] Test at 130%+ threat (should cap display)
- [ ] Verify hides when no target

### Smart Collapsing:
- [ ] Clear target - debuffs should hide
- [ ] Add self-buff to config - section should stay
- [ ] Clear action history - recent section should hide
- [ ] Verify frame resizes correctly

---

## 🚀 IMPLEMENTATION ORDER

**Phase 1: Core Features (2-3 hours)**
1. Timer Bars (GCD + Swing)
2. Smart Section Collapsing
3. Action History

**Phase 2: Class-Specific (1-2 hours)**
4. Energy Tick Tracker
5. Combo Point Pips
6. Threat Bar

**Phase 3: Polish (1 hour)**
7. Menu toggles for all features
8. Testing across all 27 specs
9. Performance validation

---

## 📚 REFERENCE

### flux Dashboard Source:
`C:\newbot\scripts\flux\rotation\source\aio\dashboard.lua`

### API Documentation:
`C:\newbot\scripts\api\common\izi_sdk.lua`
`C:\newbot\scripts\api\common\modules\buff_manager.lua`

### Current EAX Dashboard:
`C:\newbot\scripts\EAXWarriorFury\libraries\dashboard.lua`
`C:\newbot\scripts\EAXWarriorFury\libraries\dashboard_config.lua`

---

## ✅ COMPLETION CRITERIA

- [ ] All 6 features implemented
- [ ] Menu toggles work for each feature
- [ ] 29 specs updated with correct config flags
- [ ] All files pass `luac -p`
- [ ] No Lua errors in-game
- [ ] Visual layout matches specifications
- [ ] Performance: <1ms per frame impact

---

**Next Step:** Begin Phase 1 implementation with Timer Bars and Smart Section Collapsing.
