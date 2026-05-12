# Changelog

## Unreleased

- Rebuilt `EaxRotations` as a single Project Sylvanas package.
- Added shared nil-safe runtime helpers for spell resolution, cast gating, aura checks, healing scans, threat drops, stance/form checks, and protected strategy dispatch.
- Added class modules for all supported classes and playstyles.
- Added rank fallback spell tables so lower-level characters can resolve learned ranks instead of hard-locking to max-rank spells.
- Added defensive middleware for threat-drop abilities that only runs with a nearby group member in combat.
- Added pet-aware hunter support for pet-targeted actions.
- Added healer logic that considers effective health with incoming heals and absorbs where the runtime exposes those values.
- Added regression tests and API lint tests for the rebuilt package.
