# ESP Renderer Icon Fix Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix ESP renderer to properly display spell icons with caching, and ensure multiple loaded specs don't interfere with each other.

**Architecture:** Create a shared icon cache module that all specs use. Pre-resolve spell icon names at startup and cache them. Each spec gets isolated state via a unique prefix/key.

**Tech Stack:** Lua, WoW addon API (core.graphics, core.spell_book)

---

## Current State Analysis

### Problem 1: Icons Not Showing
- `esp_renderer.lua` tries to load `icons_helper` but it's wrapped in pcall and may fail silently
- When it fails, falls back to colored box
- No caching - fetches icon on every render

### Problem 2: Multiple Specs Interference
- All specs share same global state variables (`next_spell_id`, `next_spell_name`, etc.)
- When 3 shaman specs loaded, they overwrite each other's HUD display

### Problem 3: No Icon Caching
- `draw_spell_icon()` fetches from Wowhead each time
- Should pre-resolve icon names once and reuse

---

## Solution Design

### 1. Create Shared Icon Cache Module
- New file: `common/eax_shared/icon_cache.lua`
- Pre-resolves spell icon names on first access
- Caches results in memory table
- Provides simple API: `get_icon_name(spell_id)` returns icon name string

### 2. Update esp_renderer.lua
- Use icon_cache instead of direct icons_helper calls
- Add spec identifier parameter to isolate state
- Use prefix-based state keys: `esp_next_spell_{spec_id}` instead of global `next_spell_id`

### 3. Update all 27 main.lua files
- Pass spec identifier to esp_renderer (e.g., "enhancement", "elemental", "restoration")
- This ensures each spec has isolated HUD state

---

## Files

### Create
- `common/eax_shared/icon_cache.lua` - New icon caching module

### Modify
- `EAXShamanEnhancement/esp_renderer.lua` - Use icon_cache, add spec isolation
- `EAXShamanElemental/esp_renderer.lua` - Same
- `EAXShamanRestoration/esp_renderer.lua` - Same
- (All 27 esp_renderer.lua files - but start with shaman as proof of concept)

### Update main.lua calls
- All specs that call `esp_renderer.on_cast()` need to pass spec identifier

---

## Chunk 1: Create Icon Cache Module

### Task 1: Create icon_cache.lua

**Files:**
- Create: `common/eax_shared/icon_cache.lua`

- [ ] **Step 1: Create the icon cache module**

```lua
-- icon_cache.lua
-- EAX Shared | Spell icon name caching
-- Pre-resolves spell icon names once and caches them

local icon_cache = {}

local _icons = nil
local _cache = {}  -- { spell_id -> icon_name }

local function load_icons()
    if _icons then return true end
    local ok, result = pcall(require, "common/utility/icons_helper")
    if ok and result then
        _icons = result
        return true
    end
    return false
end

function icon_cache.get_icon_name(spell_id)
    if not spell_id then return nil end
    
    -- Check memory cache first
    if _cache[spell_id] then
        return _cache[spell_id]
    end
    
    -- Try to resolve via icons_helper
    if load_icons() and _icons then
        local ok, name = pcall(_icons.get_spell_icon_name, _icons, spell_id)
        if ok and name then
            _cache[spell_id] = name
            return name
        end
    end
    
    return nil
end

function icon_cache.clear()
    _cache = {}
end

return icon_cache
```

- [ ] **Step 2: Test that module loads**

Run: Check if file parses correctly (Lua syntax check)

---

## Chunk 2: Update ESP Renderer for Shaman Specs

### Task 2: Modify EAXShamanEnhancement/esp_renderer.lua

**Files:**
- Modify: `EAXShamanEnhancement/esp_renderer.lua`

Changes needed:
1. Add spec_id parameter to module functions
2. Use prefix-based state keys: `state_prefix .. "next_spell_id"`
3. Use icon_cache instead of direct icons_helper

- [ ] **Step 1: Read current esp_renderer.lua structure**

- [ ] **Step 2: Add spec_id parameter and state isolation**

Replace the state section with:

```lua
-- State - use spec_id prefix to isolate between multiple loaded specs
local function make_state_key(spec_id, key)
    return "eax_" .. (spec_id or "default") .. "_" .. key
end

local state = {}  -- Will be initialized with spec_id
```

- [ ] **Step 3: Update set_next_action to use spec-specific keys**

```lua
function esp_renderer.set_next_action(spec_id, spell_id, spell_name, color_hint)
    local key_prefix = spec_id or "default"
    state[key_prefix] = state[key_prefix] or {}
    state[key_prefix].next_spell_id    = spell_id
    state[key_prefix].next_spell_name  = spell_name or ""
    state[key_prefix].next_spell_color = color_hint
    state[key_prefix].next_spell_set_at = core.time()
end
```

- [ ] **Step 4: Update on_cast to accept spec_id**

```lua
function esp_renderer.on_cast(spec_id, spell_id, name, col)
    esp_renderer.set_next_action(spec_id, spell_id, name, col)
end
```

- [ ] **Step 5: Update draw_hud to read from spec-specific state**

- [ ] **Step 6: Test with Enhancement spec loaded**

### Task 3: Modify EAXShamanElemental/esp_renderer.lua

**Files:**
- Modify: `EAXShamanElemental/esp_renderer.lua`

- [ ] **Apply same changes as Task 2**

### Task 4: Modify EAXShamanRestoration/esp_renderer.lua

**Files:**
- Modify: `EAXShamanRestoration/esp_renderer.lua`

- [ ] **Apply same changes as Task 2**

---

## Chunk 3: Update main.lua to Pass Spec Identifier

### Task 5: Update EAXShamanEnhancement/main.lua

**Files:**
- Modify: `EAXShamanEnhancement/main.lua`

- [ ] **Step 1: Find all esp_renderer.on_cast calls**

Expected lines around: 252, 315, 387

- [ ] **Step 2: Add spec identifier parameter**

```lua
-- Before:
esp_renderer.on_cast(nil, "Stormstrike", color.cyan(220))

-- After:
esp_renderer.on_cast("enhancement", nil, "Stormstrike", color.cyan(220))
```

- [ ] **Step 3: Verify all 3 calls updated**

### Task 6: Update EAXShamanElemental/main.lua

**Files:**
- Modify: `EAXShamanElemental/main.lua`

- [ ] **Find and update all esp_renderer.on_cast calls**

### Task 7: Update EAXShamanRestoration/main.lua

**Files:**
- Modify: `EAXShamanRestoration/main.lua`

- [ ] **Find and update all esp_renderer.on_cast calls**

---

## Chunk 4: Verification

### Task 8: Test with Multiple Shaman Specs

**Testing:**
- Load all 3 shaman specs
- Verify each shows its own spell in HUD without interference
- Verify icons display correctly (not fallback boxes)

- [ ] **Step 1: Run with Enhancement only**

- [ ] **Step 2: Run with all 3 shaman specs**

- [ ] **Step 3: Verify no console errors**

---

## Chunk 5: Roll Out to Other Classes (If Time Permits)

### Task 9: Apply Same Pattern to Other Classes

**Files:**
- Modify: All other 24 esp_renderer.lua files
- Modify: All other 24 main.lua files

- [ ] **Repeat Chunk 2-3 for each class**

This is repetitive but necessary for full isolation.

---

## Notes

- The icon_cache module should be created once in common/eax_shared/
- All specs can then require this shared module
- This ensures single point of icon caching across all specs
- State isolation prevents HUD flickering between specs
