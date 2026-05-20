# Local Reference Implementations

These are local code/research references in this workspace. They are useful implementation signals, but they are not authoritative game-data sources. Verify exact TBC spell IDs, ranks, and talent behavior against Wowhead TBC pages before shipping rotation code.

## Flux

Location: `../flux`

Useful files:
- `../flux/docs/DRUID_RESEARCH.md`
- `../flux/docs/HUNTER_RESEARCH.md`
- `../flux/docs/MAGE_RESEARCH.md`
- `../flux/docs/PALADIN_RESEARCH.md`
- `../flux/docs/PRIEST_RESEARCH.md`
- `../flux/docs/ROGUE_RESEARCH.md`
- `../flux/docs/SHAMAN_RESEARCH.md`
- `../flux/docs/WARLOCK_RESEARCH.md`
- `../flux/docs/WARRIOR_RESEARCH.md`
- `../flux/docs/BURST_DEFENSIVE_RESEARCH.md`
- `../flux/rotation/source/aio/**`

Benefits:
- Deep TBC-focused spell ID tables, max-rank notes, debuff/buff IDs, and "does not exist in TBC" guardrails.
- Strategy registry design with middleware-first handling for defensives, dispels, buffs, burst, and consumables.
- Good state-machine notes for seal twisting, totem twisting, hunter shot weaving, Arms Slam timing, Feral powershifting, Warlock Life Tap, and Paladin Forbearance.
- Good suggested settings schema for advanced toggles.

Risks:
- Flux targets a different framework and uses Action/TellMeWhen concepts, so API calls cannot be copied directly into Sylvanas plugins.
- Some entries are marked `[VERIFY]`; keep those verification notes when transferring.
- Flux rotation runs every frame, while Project Sylvanas code must respect local throttling/caching patterns.

## Sonah

Location: `../Sonah`

Useful files:
- `../Sonah/Classes/**`
- `../Sonah/Core/TalentHelper*.lua`
- `../Sonah/Core/PvPSystem.lua`
- `../Sonah/Core/Utilities.lua`
- `../Sonah/UI/SwingTimer.lua`
- `../Sonah/Config/Config.lua`

Benefits:
- Broad per-class TBC rotation modules with PvE, PvP, and AoE branches.
- Practical feature toggles for powershift, steady-shot weaving, seal twisting, totem twisting, Life Tap, and Vampiric Touch refresh.
- Swing timer abstraction for main-hand, off-hand, and ranged timers.
- Talent-helper data that can inform spec detection and build naming.
- PvP system ideas: DR categories, enemy cooldown tracking, kill-target priority, CC-target priority.

Risks:
- Sonah is a WoW addon, not a Sylvanas plugin; direct API usage is not portable.
- Some comments include non-TBC references in a few places, so treat each mechanic as a clue and verify before using.
- UI/status logic may exaggerate "always keep DoTs up" where true optimal play depends on mana, target lifetime, debuff slots, or raid assignment.

## SlyRotate

Location: `../SlyRotate`

Useful files:
- `../SlyRotate/SlyRotate_Druid*.lua` or `../SlyRotate/SlyRotate_FeralDruid.lua`
- `../SlyRotate/SlyRotate_Hunter.lua`
- `../SlyRotate/SlyRotate_Mage.lua`
- `../SlyRotate/SlyRotate_Paladin.lua`
- `../SlyRotate/SlyRotate_Priest.lua`
- `../SlyRotate/SlyRotate_Rogue.lua`
- `../SlyRotate/SlyRotate_Shaman.lua`
- `../SlyRotate/SlyRotate_Warlock.lua`
- `../SlyRotate/SlyRotate_Warrior.lua`

Benefits:
- Compact and readable priority rows for each class/spec.
- Useful event-driven examples for tracking target debuffs, active seals, Vampiric Touch, Arcane Blast stacks, Improved Scorch, and warrior swing windows.
- Good reminders around TBC talent-tab ordering and delayed spec detection after addon load.
- Warrior module demonstrates a simple post-swing Slam window and sanity checks for swing duration.

Risks:
- It is a display helper, not a complete optimizer.
- Some spell references need TBC verification. Example: any Wrath-only ability names should not be brought into Project Sylvanas TBC logic.
- Uses retail addon APIs and saved variables, not Sylvanas APIs.

## Transfer Rules

- Transfer mechanic ideas and state requirements, not source code.
- Preserve source provenance in class/spec docs when a local reference influenced the note.
- Prefer Flux for detailed mechanics, Sonah for UI/toggle/PvP concepts, and SlyRotate for compact priority sanity checks.
- Before implementation, re-check exact spell IDs against `Sources.md` and local `api/`/`apidocs/`.

