# Contributing to EaxRotations

## Codebase Overview

EaxRotations is a TBC Classic rotation automation framework for Project Sylvanas. The codebase is ~223K lines of Lua across ~400 files.

### Directory Structure

```
EaxRotations/
├── header.lua # Plugin metadata, class detection
├── main.lua # Boot sequence, on_update entry point, UI sync
├── core_sylvanas.lua # NS namespace: try_cast, spell safety, auras, registry
├── main_sylvanas.lua # Dispatcher: build_context, playstyle selection, run_list
├── helpers_sylvanas.lua # Shared helper aliases
├── core/  # Extracted core domains (cooldowns, items, settings, units)
├── shared/  # 68 cross-cutting service modules
├── classes/ # 9 classes, each with spec files + support files
│ ├── warrior/
│ │ ├── fury_sylvanas.lua # Spec rotation (TBC)
│ │ ├── fury_vanilla.lua # Spec rotation (Classic)
│ │ ├── class_sylvanas.lua # Class bootstrap + middleware
│ │ ├── schema_sylvanas.lua # UI settings widgets
│ │ ├── leveling_sylvanas.lua # Leveling rotation
│ │ ├── middleware_sylvanas.lua # Class-specific middleware
│ │ └── shared_helpers_sylvanas.lua # Shared warrior helpers
│ └── ...
├── tests/  # 197 test files + test runner
└── docs/  # Documentation
```

### Architecture

1. **Boot**: `main.lua` loads core → shared modules → class bootstrap → schema
2. **Tick**: `on_update()` → `build_context()` → middleware → playstyle strategies → `try_cast()`
3. **Strategy Pattern**: Each spec registers strategies as `{name, matches_fn, execute_fn}` tuples
4. **Match/Execute**: `matches(context, state) → bool`, `execute(context) → bool`
5. **Safety Gates**: Every cast passes through player/target/spell/GCD/resource/stance/range checks

## How to Add a New Spec

1. Create `classes/<class>/<spec>_sylvanas.lua`
2. Define spell constants (`ACTION`, `SPELLS`, `STANCE`)
3. Build a `state` table with all needed fields (pre-allocate at module level)
4. Write `build_state(context)` to populate state from context
5. Write match functions: `local function xxx_matches(context, state) ... end`
6. Write execute functions or use `NS.try_cast` directly
7. Register strategies:
 ```lua
 NS.rotation_registry:register("spec_name", {
 playstyles = {
 spec_name = {
 { "StrategyName", matches_fn, execute_fn },
 ...
 }
 }
 })
 ```
8. Create `classes/<class>/<spec>_vanilla.lua` for Classic era support
9. Add tests in `tests/test_<spec>_custom_matches.lua`
10. Wire test into `tests/run_rotation_tests.lua`

## How to Run Tests

```bash
# Run all rotation tests
lua EaxRotations/tests/run_rotation_tests.lua

# Run all leveling tests
lua EaxRotations/tests/run_leveling_tests.lua

# Verbose mode
lua EaxRotations/tests/run_rotation_tests.lua -v

# Syntax check all files
find EaxRotations -name "*.lua" -exec luac -p {} \;
```

## Coding Conventions

### Namespace
- Always use `local NS = _G.EaxRotations` at the top of every file
- Do NOT use alternative aliases like `_G_E`

### Error Handling
- Wrap all native API calls in `pcall` or `NS.safe()`
- Use `NS.safe_field(unit, "method_name")` for unit method access
- Fail-closed for readiness checks (return `false`), fail-open for range checks (return `true`)

### State Management
- Pre-allocate state tables at module level: `local my_state = { field = default }`
- Mutate in place in `build_state()`—do NOT allocate new tables
- Reset target-dependent fields at the top of `build_state` before conditional checks

### Strategy Registration
- Use the standard `{name, matches, execute}` tuple format
- First successful match wins (priority order matters)
- Match functions should be pure (no side effects)

### Performance
- No per-frame table allocations in hot paths—use static buffers
- Cache `NS.GetPlayer()` per-frame if needed multiple times
- Use `NS.time_now()` for timestamps, not `os.time()`

### Shared Modules
- Use the `M.install(NS)` pattern for new shared modules
- Capture `safe`/`safe_field` at install time, not per-call
- Use `NS.get_player()` from `player_helpers_sylvanas`—do NOT reimplement
