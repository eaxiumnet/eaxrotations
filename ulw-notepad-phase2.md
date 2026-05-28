# Ultrawork Notepad — Phase 2: Classic WoW Rotation Support
Started: 2026-05-28T03.02.05

## Plan
1. Infrastructure: expansion-aware spell gating in class tables
2. Template: create first Classic spec (warrior fury) as pattern
3. Batch: high-priority classes (warrior, mage, rogue, warlock)
4. Remaining classes delegated to parallel agents

## Scenarios (contract)
1. Classic Fury Warrior rotation uses Bloodthirst, Whirlwind, no Devastate/VictoryRush/Rampage
2. Classic Fire Mage rotation uses Fireball, Scorch, no IceLance/ArcaneBlast/DragonsBreath
3. Classic Combat Rogue rotation uses SinisterStrike, Eviscerate, no Mutilate/Shadowstep/Cloak
4. TBC specs unchanged — rotation tests still pass
5. Expansion detection routes to correct spec file at load time

## Now
Step 1: Explore existing spec patterns to design Classic equivalents.

## Todo
- [] Add expansion gating to all class_sylvanas.lua spell tables
- [] Create Classic fury rotation file
- [] Create Classic fire rotation file
- [] Create Classic combat rotation file
- [] Create Classic affliction rotation file
- [] Add load-time expansion routing
- [] Add Classic regression tests
- [] Verify all TBC tests still pass

## Findings
- NS.is_vanilla() and NS.get_expansion_max_level() exist in core now
- No expansion routing in main.lua or class_loader_sylvanas.lua yet
- 40 playstyles across 9 classes
- TBC-only spells found by audit: 50+ across all classes

## Learnings
- Phase 1 MVP proved expansion detection works
- Need to gate spell tables, not just rotation priorities
- Classic rotations differ significantly in talents/abilities
