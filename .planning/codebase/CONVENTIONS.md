# CONVENTIONS - Code Style & Patterns

## Lua Style Guide

### Indentation
- 4 spaces (not tabs)
- Consistent throughout all files

### Line Length
- No strict limit, but prefer lines < 120 chars
- Break long function calls with newlines

### Naming Conventions
```lua
-- Variables: snake_case
local my_variable = 1
local target_hp_pct = 0.5

-- Functions: snake_case
local function get_spell_id(rank_table)
    ...
end

-- Constants: SCREAMING_SNAKE_CASE
local EXECUTE_HP_THRESHOLD = 0.20
local MODE_REFRESH_INTERVAL_S = 5

-- Tables: PascalCase for exported modules
local interrupt_manager = {}

-- Spec runtime: lowercase keys
runtime = {
    mortal_strike_id = nil,
    cached_mode = "solo",
}
```

## Code Patterns

### Early Return Pattern
```lua
local function try_cast_spell(target)
    if not target then return false end
    if not spell_id then return false end
    if me:is_dead() then return false end
    -- actual logic
end
```

### Priority Lanes
```lua
local function on_update()
    if try_defensive(me) then return end
    if try_utility(me, target) then return end
    if try_rotation(me, target) then return end
end
```

### Throttling
```lua
if not utils.throttle("spell_name", 5.0) then return false end
```

### Spell Resolution
```lua
-- Rank tables ordered highest-to-lowest
spells.MORTAL_STRIKE = { 30330, 25248, 21553, ... }

-- Resolution iterates forwards (was fixed from backwards iteration)
function utils.resolve_spell_id(rank_table)
    for i = 1, #rank_table do
        if core.spell_book.is_spell_learned(rank_table[i]) then
            return rank_table[i]
        end
    end
    return nil
end
```

### Queue-based Casting
```lua
-- Spell queues prevent GCD overlap
function utils.cast_target(spell_id, target)
    if not can_issue_queue_request(...) then return false end
    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end
```

### Caching
```lua
local function refresh_mode_cache()
    local now = core.time()
    if (now - runtime.mode_cache_refreshed_at) < MODE_REFRESH_INTERVAL_S then
        return
    end
    runtime.cached_mode = detect_mode()
end
```

## Error Handling

### pcall Usage
```lua
-- Wrapping potentially undefined API calls
local ok, result = pcall(function()
    return obj:get_something()
end)
if ok and result then
    -- use result
end
```

### Safe GUID Comparison
```lua
local function safe_guid(u)
    local ok, g = pcall(function() return u:get_guid() end)
    return (ok and g ~= nil) and tostring(g) or nil
end
```

## Module Pattern

Each file returns a table:
```lua
local my_module = {}

function my_module.public_function(arg)
    ...
end

return my_module
```

## Comment Style

- Minimal comments (per AGENTS.md convention)
- Explanatory comments only for complex logic
- Section headers with `═══` characters
```lua
-- ═══ Offensive abilities ═══
spells.MORTAL_STRIKE = { ... }
```

## UI/Menu Pattern

Using `ps_theme` helper:
```lua
main_tree:render("  Rotation Settings", function()
    menu.use_mortal_strike:render("Mortal Strike", "Description")
    menu.use_execute:render("Execute", "Description below 20%")
end)
```

## File Header Pattern

```lua
-- EAX Warrior Arms | main.lua
-- Minimal Arms rotation helper that prioritizes Overpower, Mortal Strike...
```
