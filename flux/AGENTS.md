# Flux AIO — Agent Context

**Monorepo:** WoW TBC rotation addon + website + Discord bot + log analyzer

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Build rotation | `rotation/` |
| Run Discord bot | `discord-bot/` |
| Run website | `website/` |
| Log analysis | `log-analyzer/` |
| API docs | `docs/api/` |
| Class research | `docs/*_RESEARCH.md` |

## ENTRY POINTS

| Package | Entry | Command |
|---------|-------|---------|
| rotation | `rotation/build.js` | `npm run build -w rotation` |
| rotation (dev) | `rotation/dev-watch.js` | `npm run watch -w rotation` |
| discord-bot | `discord-bot/src/index.js` | `npm start -w discord-bot` |
| website | `website/src/pages/index.astro` | `npm run dev -w website` |
| log-analyzer | `log-analyzer/src/cli.js` | `npm run cli -w log-analyzer` |

## CONVENTIONS

**Lua (rotation):**
- 3-space indentation
- Lowercase single words only: `cat.lua`, `core.lua`
- No underscores/hyphens in filenames (enforced by build.js)
- Modules share `_G.FluxAIO` namespace
- Load order: ORDER_MAP in build.js

**JS/TS:**
- 2-space indentation
- LF line endings (`* text=auto eol=lf` in .gitattributes)
- ES modules (`"type": "module"` in package.json)

## ANTI-PATTERNS

- NEVER capture settings at load time — use `context.settings.key` in matches/execute
- NEVER change ORDER_MAP load order arbitrarily — `main.lua` always last
- NEVER use raw casting except for known broken spells (double-cast)
- NEVER create tables inline during combat — pre-allocate at load time

## COMMANDS

```bash
# Build rotation addon
cd rotation && npm run build

# Dev mode with auto-rebuild
cd rotation && npm run watch

# Run Discord bot
cd discord-bot && npm start

# Run website
cd website && npm run dev

# Run log analyzer CLI
cd log-analyzer && npm run cli discover --expansion tbc
```

## NOTES

- Root uses CommonJS (`require`), subpackages use ES modules (`import`)
- `rotation/dev.ini` (gitignored) controls SavedVariables sync paths
- `ROTATION_ROOT` env var overrides project root (used by discord-bot)
- WoW API refs: `TBC-main/`, `Addon Libraries/` (external, gitignored)
