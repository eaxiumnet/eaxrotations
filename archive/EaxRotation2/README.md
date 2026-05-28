# EaxRotation2 — IZI-First Simplified Engine (PoC)

This is a **proof-of-concept** parallel engine that uses the Project Sylvanas `izi_sdk` as the single source of truth for spell castability, targeting, buff/debuff checks, and combat logic.

## Why this exists

The original `EaxRotations/` engine (~72K lines, ~273 files, 29 specs) has runtime issues:
- **Debug spam**: `core_sylvanas.lua` `NS.spell_ready()` emits string-concatenated trace logs on every tick for every spell check, creating "spell is not ready yet" spam even when debug mode is off.
- **Silent failures**: Warlock, Mage, and Paladin specs sometimes do nothing in combat because their custom `matches()` functions have many manual gating checks (distance, debuff remains, etc.) that silently return `false` when APIs return unexpected values.

`EaxRotation2/` is a **clean-room experiment** to see if an IZI-first design eliminates these bugs.

## Architecture

```
EaxRotation2/
  init.lua                     -- Entrypoint: registers on_update, picks spec by class or manual override
  engine/
    dispatcher.lua             -- Minimal loop: player check, target check, call spec.tick()
  specs/
    warrior/arms.lua           -- ~80 lines, IZI priority with rage gating
    warrior/fury.lua           -- ~80 lines, IZI priority with rage gating
    warrior/protection.lua     -- ~90 lines, IZI priority with rage gating
    paladin/retribution.lua    -- ~100 lines, IZI priority with seal management
    paladin/holy.lua           -- ~105 lines, IZI priority with blessing/seal logic
    paladin/protection.lua     -- ~90 lines, IZI priority with HP gating
    hunter/beast_mastery.lua   -- ~80 lines, IZI priority with pet/aspect checks
    hunter/marksmanship.lua    -- ~85 lines, IZI priority with pet/aspect checks
    hunter/survival.lua        -- ~95 lines, IZI priority with trap/sting logic
    rogue/assassination.lua    -- ~65 lines, IZI priority with combo point checks
    rogue/combat.lua           -- ~60 lines, IZI priority with combo point checks
    rogue/subtlety.lua         -- ~75 lines, IZI priority with combo point checks
    priest/discipline.lua      -- ~65 lines, IZI priority with healing/damage triage
    priest/holy.lua            -- ~65 lines, IZI priority with healing/damage triage
    priest/shadow.lua          -- ~65 lines, IZI priority with DoT maintenance
    priest/smite.lua           -- ~60 lines, IZI priority with DoT maintenance
    shaman/elemental.lua       -- ~55 lines, IZI priority with shield management
    shaman/enhancement.lua     -- ~60 lines, IZI priority with shield/melee mix
    shaman/restoration.lua     -- ~65 lines, IZI priority with healing triage
    mage/frost.lua             -- ~90 lines, IZI priority with defensive gating
    mage/fire.lua              -- ~80 lines, IZI priority with armor/debuff logic
    mage/arcane.lua            -- ~85 lines, IZI priority with cooldown management
    warlock/affliction.lua     -- ~80 lines, IZI priority with DoT maintenance
    warlock/demonology.lua     -- ~75 lines, IZI priority with DoT maintenance
    warlock/destruction.lua    -- ~75 lines, IZI priority with DoT/execute logic
    druid/balance.lua          -- ~70 lines, IZI priority with form/armor logic
    druid/bear.lua             -- ~65 lines, IZI priority with form/threat logic
    druid/cat.lua              -- ~65 lines, IZI priority with form/DoT logic
    druid/resto.lua            -- ~75 lines, IZI priority with healing/damage triage
```

## How it differs from EaxRotations

| Aspect | EaxRotations | EaxRotation2 |
|--------|--------------|--------------|
| Spell readiness | Custom `NS.spell_ready()` (~80 lines) | `izi.spell(id):cast_safe()` |
| Buff/debuff checks | `NS.buff_up()`, `NS.debuff_remains()` | `me:buff_up()`, `target:debuff_remains()` |
| Cast execution | `NS.try_cast()` (IZI fallback to raw API) | Direct `spell:cast_safe()` |
| Debug output | Per-tick per-spell string concatenation | Rate-limited idle-reason aggregator |
| File size per spec | 200-800 lines | ~60 lines |
| Middleware | Class middleware + shared modules | None (spec handles everything) |
| Tests | 110 test suites | 1 regression test (IZI integration) + syntax-validated specs + init.lua registration |
| Spec count | 29 specs | 29 specs (100% coverage) |

## Key design decisions that prevent old bugs

1. **No per-tick string logging inside readiness checks**: Debug is entirely off unless explicitly enabled, and the dispatcher only prints an idle summary once every 2 seconds.
2. **Single source of truth for castability**: IZI's `cast_safe()` handles learned, usable, cooldown, GCD, range, and facing in one call. The spec does not manually check these — it only handles priority ordering, HP thresholds, and buff/debuff refresh timing.
3. **Minimal custom gating**: The spec is a priority list that uses HP/mana thresholds and debuff timing for rotation logic, but all castability validation is delegated to IZI.
4. **Hard guardrails around nil units**: The dispatcher checks `me:is_alive()`, `me:is_cc()` before calling the spec. The spec gets `me`, `target`, and `enemies` as validated objects.

## Usage (in-game)

Place `EaxRotation2/` inside your Sylvanas scripts directory alongside `EaxRotations/`. Load `EaxRotation2/init.lua` instead of `EaxRotations/main.lua` to use the new engine.

## Status

- **Phase 1 (EaxRotations refactor)**: `core_sylvanas.lua` updated — `NS.spell_ready()` is now quiet by default; `NS.spell_castable_via_izi()` added; `NS.action_matches()` uses IZI truth.
- **Phase 2 (EaxRotation2 PoC)**: 29 specs implemented — all classes covered.
- **Next steps**: Add middleware-equivalent helpers (interrupts, consumables, defensives, auto-potions, trinkets).
