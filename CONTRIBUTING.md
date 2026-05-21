# Contributing to EaxRotations

## Getting Started

EaxRotations is a TBC Classic rotation framework for Project Sylvanas. Before contributing, please read the project README and architecture docs in `EaxRotations/docs/`.

## Project Structure

```
EaxRotations/
  core_sylvanas.lua          # Runtime API boundary — add NS.* helpers here
  main_sylvanas.lua          # Dispatcher — avoid class-specific logic
  classes/<class>/
    class_sylvanas.lua       # Spell tables, constants
    schema_sylvanas.lua      # UI settings
    middleware_sylvanas.lua  # Cross-spec defensive/interrupt logic
    <spec>_sylvanas.lua      # Playstyle strategy tables
  shared/                     # Cross-class helpers
  tests/                      # Regression tests
  tools/                      # Audit and validation scripts
```

## Code Style

- Cache API references at module load: `local _core_time = NS.time_now or function() return 0 end`
- Use `NS.*` helpers; avoid raw `core.*` calls in class files
- Nil-guard all settings reads: `(menu.x and menu.x:get()) or default`
- Keep strategies in priority order with clear `matches` / `execute` pairs
- Annotate TBC-specific magic numbers with game mechanic comments

## Testing

Run before submitting:

```powershell
# Syntax check all Lua files
Get-ChildItem -Path EaxRotations -Recurse -Filter *.lua | ForEach-Object { luac -p $_.FullName }

# Run all regression tests
Get-ChildItem EaxRotations\tests -Filter test_*.lua | ForEach-Object { lua $_.FullName }

# Run audits
lua EaxRotations/tools/audit_online_tbc_ids.lua
lua EaxRotations/tools/audit_static_behavior.lua
```

## Spell IDs

- TBC 2.4.3 ranks only
- Newest-to-oldest ordering in tables
- Cross-validate with `tools/audit_online_tbc_ids.lua`

## Readability

Add a file header explaining **What / When / Why / Safety** for new modules. See `EaxRotations/classes/warlock/affliction_sylvanas.lua` as a well-commented example.

## Questions?

Open an issue with class, playstyle, and relevant log lines.
