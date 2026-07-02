# EaxProfession

Clean, standalone crafting automation plugin for **Project Sylvanas** (WoW TBC Classic Anniversary 2.5.5).

Built on Silvi's 2026-07-01 profession API additions:
- `core.spell_book.get_professions` / `get_profession_info`
- `core.profession` (enum + `open_profession`)
- `core.trade_skill` (classic index-based + retail `C_TradeSkillUI`)
- `core.craft` (classic Craft UI for Enchanting)
- `core.skill` (classic Skill window)

## Design

- **Single API adapter** — `core/api_surface.lua` is the ONLY module touching `core.*`
- **API caching at load** — namespace references cached once, not per-call
- **pcall everything** — every API call pcall-wrapped with safe defaults
- **No external dependencies** — no EaxRotations/EAXFishing/EaxAutoQuester requires
- **Thorough comments** — every function has `---` doc comments

## Structure

```
EaxProfession/
├── main.lua                        — Entry point, on_update dispatch, menu
├── core/
│   └── api_surface.lua             — Single API adapter (ONLY module touching core.*)
├── data/
│   └── profession_constants.lua    — Skill line IDs, enum mappings, names
├── professions/
│   └── crafting_engine.lua         — Clean crafting engine
├── ui/
│   └── menu.lua                    — Menu widgets (nil-guarded accessors)
├── tests/
│   ├── mock_core.lua               — Mock for all profession APIs
│   ├── test_api_surface.lua        — 50+ API surface wrapper tests
│   ├── test_crafting_engine.lua    — 60+ crafting engine tests
│   ├── test_runner_lib.lua         — Standalone test runner library
│   └── run_tests.lua               — Test runner entry point
└── README.md
```

## Running Tests

```bash
lua EaxProfession/tests/run_tests.lua           # normal
lua EaxProfession/tests/run_tests.lua -v         # verbose
lua EaxProfession/tests/run_tests.lua -q         # quiet
```

## Supported Professions

| Profession | Skill ID | UI Type |
|-----------|----------|---------|
| Alchemy | 171 | TradeSkill |
| Blacksmithing | 164 | TradeSkill |
| Leatherworking | 165 | TradeSkill |
| Tailoring | 197 | TradeSkill |
| Engineering | 202 | TradeSkill |
| Enchanting | 333 | Craft |
| Cooking | 185 | TradeSkill |
| First Aid | 129 | TradeSkill |
| Jewelcrafting | 755 | TradeSkill |

Gathering professions (Herbalism, Mining, Skinning, Fishing) are excluded — they don't have crafting windows.
