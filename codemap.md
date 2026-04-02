# Repository Atlas: eax-tbc-classic-rotations

## Project Responsibility
Implements a multi-spec EAX rotation suite for WoW TBC Classic on the Sylvanas/NAG execution environment. The repository combines per-spec combat entrypoints, shared runtime managers, validation tooling, and adjacent reference/tooling trees.

## System Entry Points
- `README.md` — project overview and usage notes.
- `AGENTS.md` — handover, workflow rules, and current repo-specific guidance.
- `libraries/` — shared runtime used by most live EAX specs.
- `EAX*/main.lua` — per-spec on-update entrypoints and priority engines.
- `tools/` — API gating, benchmarking, and rotation validation utilities.
- `NAG/` — separate addon/tooling project kept in-repo for reference/integration work.

## Design
- **Spec-per-directory architecture**: each live rotation ships as its own `EAX<Class><Spec>/` module tree.
- **Shared-runtime pattern**: common decision support is centralized in `libraries/` instead of duplicated across specs.
- **Priority-engine execution**: specs primarily expose a hot-path `main.lua` loop backed by shared managers for combat context, smart casting, threat, interrupts, visuals, and resource gates.
- **Validation-first tooling**: `tools/` holds scripts for API surface control, benchmark thresholds, and rotation audits.

## Flow
1. A spec addon loads from `EAX<Class><Spec>/` and resolves its spell/menu/runtime state.
2. On each update tick, the spec builds or reads cached combat context from `libraries/`.
3. Shared managers evaluate interrupts, defensives, threat, UI telemetry, and resource gates.
4. The spec priority lane selects the next cast/action and dispatches via Sylvanas-compatible APIs.
5. Tooling in `tools/` is used offline to audit API usage, duplication, and throughput expectations.

## Directory Map
| Directory | Responsibility Summary | Detailed Map |
|-----------|------------------------|--------------|
| `libraries/` | Central shared runtime for combat context, managers, UI telemetry, gating, and reusable combat helpers consumed by many specs. | `libraries/codemap.md` |
| `tools/` | Repo maintenance and validation scripts for API gating, benchmark thresholds, duplicate audits, and rotation checks. | `tools/codemap.md` |
| `NAG/` | Separate addon/tooling codebase included for integration, reference, and environment-adjacent work. | `NAG/codemap.md` |
| `EAXDruidBalance/`, `EAXDruidRestoration/` | Druid live spec implementations for caster DPS and healing. | `EAXDruidBalance/codemap.md`, `EAXDruidRestoration/codemap.md` |
| `EAXHunterBeastMastery/`, `EAXHunterMarksmanship/`, `EAXHunterSurvival/` | Hunter live spec implementations covering pet-centric, ranged-shot, and trap/utility rotations. | `EAXHunterBeastMastery/codemap.md` |
| `EAXMageArcane/`, `EAXMageFire/`, `EAXMageFrost/` | Mage live spec implementations for burst, fire DPS, and frost control/DPS. | `EAXMageArcane/codemap.md` |
| `EAXPaladinHoly/`, `EAXPaladinProtection/`, `EAXPaladinRetribution/` | Paladin live spec implementations for healer, tank, and melee-DPS roles. | `EAXPaladinHoly/codemap.md` |
| `EAXPriestDiscipline/`, `EAXPriestHoly/`, `EAXPriestShadow/` | Priest live spec implementations for mitigation/healing and shadow DPS. | `EAXPriestShadow/codemap.md` |
| `EAXRogueAssassination/`, `EAXRogueCombat/`, `EAXRogueSubtlety/` | Rogue live spec implementations for poison/finisher, sustained melee, and stealth/control playstyles. | `EAXRogueAssassination/codemap.md` |
| `EAXShamanElemental/`, `EAXShamanEnhancement/`, `EAXShamanRestoration/` | Shaman live spec implementations for caster DPS, melee weave DPS, and healing/totem support. | `EAXShamanEnhancement/codemap.md` |
| `EAXWarlockAffliction/`, `EAXWarlockDemonology/`, `EAXWarlockDestruction/` | Warlock live spec implementations for DoT pressure, pet/buff play, and direct-damage burst. | `EAXWarlockDestruction/codemap.md` |
| `EAXWarriorArms/`, `EAXWarriorFury/`, `EAXWarriorProtection/` | Warrior live spec implementations for burst utility DPS, dual-wield DPS, and tanking. | `EAXWarriorFury/codemap.md` |

## Excluded / Non-Atlas Trees
- `docs/`, `.api/`, `sylvanas-dev-docs-llm/` — documentation/reference material excluded from cartography selection.
- `BRLite-main/`, `ni-main/`, `BadRotations-master/`, `archive_extracted/` — reference or historical trees, not part of the active live atlas.
- `EaxFishing_v2_0_1/` — excluded artifact/output tree.

## Navigation Notes
- Start with this file, then jump into `libraries/codemap.md` for shared runtime behavior.
- For rotation work, read the target spec folder's `codemap.md` and `main.lua` together.
- For API-surface or benchmarking work, start in `tools/codemap.md`.
