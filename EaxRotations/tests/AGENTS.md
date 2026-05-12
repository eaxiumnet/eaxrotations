# Tests Subtree Guidance

## Purpose
Top-level `tests/` contains standalone Lua tests for production behaviour (18 files).

## Style
- Run as plain Lua scripts.
- Import real production modules where possible.
- Keep tests deterministic and lightweight.
- Prefer validating behaviour, thresholds, and regression guards over implementation trivia.

## Conventions
- Mirror real TBC semantics and current production logic exactly.
- When production logic changes, update tests in the same change.
- Keep fixtures and mocks minimal; do not reimplement the production system inside the test.

## Good Test Targets
- Expansion-correct spell gating
- Execute / DoT / clip thresholds
- Regression guards for spells outside the supported TBC scope
- Shared helper behaviour used by multiple classes

## Avoid
- Copy-pasting the full production algorithm into the test
- Hidden runtime dependencies on the live Sylvanas environment when the logic can be isolated
- Ambiguous assertions that do not explain the intended rotation rule
