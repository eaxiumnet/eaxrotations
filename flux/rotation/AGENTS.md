# rotation/ — Agent Context

**Build system + Lua source for WoW TBC rotation addon**

## STRUCTURE

```
source/aio/
├── core.lua, main.lua, settings.lua, ui.lua, dashboard.lua  # Shared
├── common.lua                                              # Constants
├── druid/, hunter/, mage/, paladin/, priest/, rogue/       # Class modules
├── shaman/, warlock/, warrior/                             # (9 classes total)
├── tmw-template.lua                                        # TMW profile template
build.js       # Module discovery + compilation
dev-watch.js   # File watcher + auto-sync
```

## BUILD SYSTEM

**Load Order** (ORDER_MAP in build.js):
1. common.lua (1) → schema.lua (2) → ui.lua (3) → core.lua (4)
2. class.lua (5) → healing.lua/settings.lua (6)
3. middleware.lua (7) → dashboard.lua (8) + class modules (7, alphabetical)
4. main.lua (9) — **ALWAYS LAST**

**File naming:** Lowercase single words only. Build fails on `_`, `-`, spaces.

**Output:** `output/TellMeWhen.lua` (distributable TMW profile)

## CLASS MODULE PATTERN

Each class directory contains:
- `schema.lua` — Settings schema for ProfileUI
- `class.lua` — `register_class()` with playstyles, dashboard config
- `middleware.lua` — Shared middleware (recovery CDs, buffs, dispels)
- `healing.lua` — Healing-specific logic (if applicable)
- Playstyle files: `{playstyle}.lua` — Strategy arrays

## CONVENTIONS

- Access settings via `context.settings.key` in matches/execute functions
- NEVER capture `A.GetToggle()` at module level — settings change at runtime
- Use `NS.rotation_registry:register()` for strategies
- Use `NS.rotation_registry:register_middleware()` for shared logic
- Tag burst CDs with `is_burst = true`, defensive with `is_defensive = true`

## COMMANDS

```bash
node build.js              # Build once
node build.js --sync       # Build + sync to SavedVariables
node build.js --all        # Build + sync
node dev-watch.js          # Watch .lua files, auto-rebuild + sync
```

## NOTES

- 200 local variable limit per function (Lua constraint)
- Frame-rate sensitive — rotation runs every frame
- `dev.ini` (gitignored) required for `--sync`:
  ```ini
  wow_saved_variables=C:\...\WTF\Account\...\SavedVariables
  ```
- Set `ROTATION_ROOT` env var to override project root
- Classes excluded via `package.json` `excludeClasses` array
