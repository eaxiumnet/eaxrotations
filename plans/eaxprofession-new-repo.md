# Implementation Plan: EaxProfession — Clean Standalone Crafting Plugin

**Created:** 2026-07-01
**API Surface:** `.api/core.lua` lines 5327–5917 (Silvi profession additions)
**Docs References:** `.api/core.lua` EmmyLua annotations

## Overview

Create a new, clean, standalone repo `EaxProfession/` (singular) for Project Sylvanas TBC Classic.
Focused on the new Silvi profession APIs: `core.profession`, `core.trade_skill`, `core.craft`,
`core.skill`, `core.spell_book.get_professions/get_profession_info`.

**Key differences from old `EaxProfessions/`:**
- Standalone — no EaxRotations/EAXFishing/EaxAutoQuester dependencies
- ~5 files instead of 80+
- Clean API caching at load (no per-frame lookups)
- Thorough comments on every function
- Full test coverage with standalone mock_core

## Architecture

```
EaxProfession/
├── main.lua                        — Entry point, on_update/on_render, menu setup
├── core/
│   └── api_surface.lua             — Single API adapter (ONLY module touching core.*)
├── data/
│   └── profession_constants.lua    — Skill line IDs, enum mappings, names
├── professions/
│   └── crafting_engine.lua         — Clean crafting engine
├── ui/
│   └── menu.lua                    — Menu widgets
├── tests/
│   ├── mock_core.lua               — Clean mock for all profession APIs
│   ├── test_api_surface.lua        — API surface wrapper tests
│   ├── test_crafting_engine.lua    — Crafting engine tests
│   ├── test_runner_lib.lua         — Test runner library (standalone)
│   └── run_tests.lua               — Test runner entry point
└── README.md
```

## Design Principles

1. **Single API adapter** — `core/api_surface.lua` is the ONLY module that touches `core.*`
2. **API caching at load** — Cache namespace references at module load, not per-call
3. **pcall everything** — Every API call pcall-wrapped with safe defaults
4. **Static tables** — No per-frame allocations
5. **Thorough comments** — Every function has `---` doc comments
6. **No external dependencies** — No EaxRotations/EAXFishing/EaxAutoQuester requires
7. **Readable headers** — Every file: WHAT/WHEN/WHY/SAFETY header

## Task List

### Phase 1: Data Layer
- [ ] Task 1: `data/profession_constants.lua`
  - Skill line IDs, skill names, craft-vs-tradeskill flags, enum mapping

### Phase 2: Core API Adapter
- [ ] Task 2: `core/api_surface.lua`
  - Cache core.profession/trade_skill/craft/skill/spell_book at load
  - All profession/trade_skill/craft/skill wrappers with pcall + safe defaults

### Phase 3: Crafting Engine
- [ ] Task 3: `professions/crafting_engine.lua`
  - Skill rank checking, open profession, scan recipes, check reagents
  - Craft by name/index, craft all, mass production, statistics

### Phase 4: UI + Entry Point
- [ ] Task 4: `ui/menu.lua` + `main.lua`
  - Menu widgets, on_update dispatch

### Phase 5: Tests
- [ ] Task 5: `tests/mock_core.lua` + test files + runner
  - Full mock, 50+ assertions, standalone test runner

### Phase 6: Validation
- [ ] `luac -p` on all files
- [ ] `lua EaxProfession/tests/run_tests.lua` — all tests pass
