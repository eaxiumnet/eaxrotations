# Contributing to EaxRotations

Thank you for your interest in contributing to EaxRotations. This document provides guidelines for contributing to the project.

## Reporting Bugs

When reporting bugs, please include:

- **Class and spec** - Which rotation were you using?
- **Target type** - Boss, trash, player, etc.
- **Settings** - Any non-default settings you changed
- **Environment** - Solo, dungeon, raid, or PvP
- **Log output** - Relevant `[EaxRotations]` log lines
- **Expected behavior** - What should have happened
- **Actual behavior** - What actually happened

## Submitting Changes

1. Fork the repository
2. Create a feature branch from `master`
3. Make your changes
4. Run the test suite to verify nothing is broken
5. Submit a pull request with a clear description

### Before Submitting

All contributions must pass:

```bash
# Syntax check
find EaxRotations -name "*.lua" -exec luac -p {} \;

# Rotation test suite
lua EaxRotations/tests/run_rotation_tests.lua

# Leveling test suite
lua EaxRotations/tests/run_leveling_tests.lua

# Vanilla TBC spell ID audit
lua EaxRotations/tests/run_vanilla_audit_tests.lua
```

## Code Style

### File Structure

Each spec file should follow this structure:

```lua
-- Readability notes: What, When, Why, Safety
local NS = _G.EaxRotations
if not NS then return nil end

-- Constants
-- State table
-- Helper functions
-- Strategy definitions
-- Registration
```

### Key Conventions

- Use `NS.*` helpers for API access instead of raw Sylvanas API calls
- Nil-guard all state field comparisons: `(state.field or 0) < threshold`
- Use squared distance checks, not `math.sqrt`
- Cache API references at module load, not per-frame
- Reuse static tables with `{ n = 0 }` pattern
- All menu references must be nil-guarded: `(menu.x and menu.x:get()) or default`

### What Not to Add

- **No Cataclysm spells** - TBC Classic Anniversary only
- **No external API calls** - Project Sylvanas API only
- **No banned APIs** - No `ffi.C`, `io.popen`, `os.execute`, `debug.*`
- **No platform-specific code** - Must work on all supported platforms

## Testing

### Writing Tests

Tests are plain Lua files in `EaxRotations/tests/`. Each test file should:

- Mock NS.* dependencies when running outside the game client
- Test one specific behavior or regression
- Use descriptive test names
- Return 0 on success, non-zero on failure

### Running Tests

```bash
# Individual test
lua EaxRotations/tests/test_fury_custom_matches.lua

# All rotation tests
lua EaxRotations/tests/run_rotation_tests.lua

# All leveling tests
lua EaxRotations/tests/run_leveling_tests.lua
```

## Release Builds

Release artifacts are zips containing **.lua and .md only**, built from the
tracked tree at `HEAD` (never working-tree debris) by the tracked script:

```bash
# build ./eaxrotations.zip in the repo root (default output)
python tools/create_release_zip.py

# or write elsewhere, from any working directory
python tools/create_release_zip.py /tmp/eaxrotations.zip
```

What it does (verified by the script itself on every run):

- `git archive HEAD -- EaxRotations/` → stage zip (tracked files only; no
  `.git`, no build debris)
- Strips the `EaxRotations/` prefix and filters to `.lua` / `.md`
- Verifies the result: fails if any non-lua/md file (e.g. a stray `.txt`)
  made it in
- Pins entry timestamps so the zip is **byte-reproducible** (same HEAD ⇒
  identical md5)

Zips are **gitignored artifacts** (root `/*` ignore covers `*.zip`) — never
commit one. Rebuild on demand for releases; there is no Makefile target.

## Project Structure

- `classes/<class>/` - Per-class rotation modules
- `shared/` - Reusable combat modules
- `tests/` - Regression test suite
- `core_sylvanas.lua` - Runtime boundary and NS.* helpers
- `main_sylvanas.lua` - Update dispatcher

## Questions?

Open an issue on GitHub if you have questions about contributing.
