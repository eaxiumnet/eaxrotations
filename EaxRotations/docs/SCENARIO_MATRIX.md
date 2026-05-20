# EaxRotations Scenario Matrix

Ratings:
- Good: scenario has explicit gates and likely sane priority behavior.
- Partial: scenario works through generic resource/range/spell-rank gates, but lacks dedicated logic.
- Weak: scenario is mostly unsupported or role-mismatched.

This matrix covers the active `*_sylvanas.lua` playstyle files. It is based on code paths present in `classes/`, shared context fields from `main_sylvanas.lua`, and action gates in `core_sylvanas.lua`.

| Class | Spec | Leveling | Solo | Dungeon | Raid | PvP | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Druid | Balance | Good | Good | Good | Good | Good | AoE, cooldown, movement, PvP roots/Cyclone, full low-rank DoTs/nukes, and fixed shared execute paths. |
| Druid | Bear | Partial | Good | Good | Good | Partial | Strong tank/pack logic; leveling has no low-level talent profile. |
| Druid | Caster | Good | Good | Partial | Partial | Partial | Explicit leveling/solo lane; raid/PvP damage is blocked unless Caster is the selected playstyle. |
| Druid | Cat | Partial | Good | Good | Good | Partial | Strong single/AoE/utility; leveling still assumes mature feral kit. |
| Druid | Resto | Partial | Good | Good | Good | Good | Strong group healing/PvP triage; solo fallback now applies Moonfire/Insect Swarm/Wrath only when healing is stable. |
| Hunter | Beast Mastery | Good | Good | Good | Good | Partial | Pet, aspect, shot, AoE, cooldown, pre-Steady leveling, and pet-state paths exist. |
| Hunter | Marksmanship | Good | Good | Good | Good | Partial | Strong shot/cooldown rules; pre-Steady leveling now uses Arcane Shot/Sting before Steady is learned. |
| Hunter | Survival | Good | Good | Good | Good | Partial | Trap/AoE/shot rules plus explicit pre-Steady leveling and safer pet-state gates. |
| Mage | Arcane | Good | Good | Good | Good | Good | Low-level Fireball/Frostbolt fallback plus Counterspell, Polymorph, Frost Nova, and Slow control gates. |
| Mage | Fire | Good | Good | Good | Good | Partial | Strong direct/AoE/movement gates; PvP is basic. |
| Mage | Frost | Good | Good | Good | Good | Partial | Best mage solo/control shape; PvP is present but not arena-deep. |
| Paladin | Holy | Partial | Good | Good | Good | Good | Strong healer profile; solo fallback now seals, judges, shocks, and consecrates when healing is stable. |
| Paladin | Protection | Partial | Good | Good | Good | Partial | Tank/dungeon strong; raid and PvP are usable but less specialized. |
| Paladin | Retribution | Partial | Good | Good | Good | Good | Seal twist, PvP CC, cooldowns, AoE; leveling still mostly rank fallback. |
| Priest | Discipline | Partial | Good | Good | Good | Good | Strong support/healer; solo/leveling idle damage now auto-enables when healing is stable. |
| Priest | Holy | Partial | Good | Good | Good | Partial | Strong healing; solo/leveling idle damage now auto-enables with lower mana floors. |
| Priest | Shadow | Good | Good | Good | Good | Partial | Strong damage, mana, channel, execute logic; PvP is moderate. |
| Priest | Smite | Good | Good | Partial | Partial | Partial | Niche DPS with explicit Inner Fire, self PW:S/Renew, Psychic Scream peel, and Shadowfiend mana support. |
| Rogue | Assassination | Good | Good | Good | Good | Good | Strong poisons/openers/PvP plus pre-Mutilate Sinister Strike leveling builder and complete shared spell map. |
| Rogue | Combat | Partial | Good | Good | Good | Partial | Strong dungeon/raid basics; PvP less deep than Sub/Assassination. |
| Rogue | Subtlety | Partial | Good | Partial | Partial | Good | Strong PvP/control; raid/dungeon damage is less mature. |
| Shaman | Elemental | Partial | Good | Good | Good | Good | Strong caster logic; PvP utility spell map now covers Frost Shock, Purge, Tremor, Earthbind, and Grounding. |
| Shaman | Enhancement | Partial | Good | Good | Good | Good | Strong melee/totem/cooldown logic; PvP shock/purge/totem spells now resolve from class map. |
| Shaman | Restoration | Partial | Good | Good | Good | Good | Strong group healing; solo fallback now gates damage by stability/mana and PvP utility spells resolve. |
| Warlock | Affliction | Good | Good | Good | Good | Good | Strong DoT, sustain, TTD, pet/OOC fixes; shared PvP spell map now covers Fear, Tongues, Exhaustion, Spell Lock, and Death Coil. |
| Warlock | Demonology | Partial | Good | Good | Good | Good | Strong pet/survival path; PvP control spells now resolve from class map. |
| Warlock | Destruction | Partial | Good | Good | Good | Good | Strong nuke/cooldown/OOC target gating; PvP control spells now resolve from class map. |
| Warrior | Arms | Partial | Good | Good | Good | Good | Strong stance/PvP/AoE/execute logic; leveling still talent-assumptive. |
| Warrior | Fury | Partial | Good | Good | Good | Good | Strong BT/WW/execute; Pummel/Hamstring now resolve correct TBC IDs, leveling still mostly rank/talent fallback. |
| Warrior | Kebab | Partial | Good | Good | Partial | Partial | Specialized DW Arms build; general-use path now favors Mortal Strike and avoids single-target WW stance dancing without offhand/leveling context. |
| Warrior | Protection | Partial | Good | Good | Good | Good | Strong tank/PvP utility; leveling damage is partial. |

## Weakest First

Patched in this pass:
- Shared dispatcher now exposes `player_level`, `target_level`, `target_level_delta`, `target_classification`, `instance_type`, `is_leveling`, `is_solo`, `is_group`, `is_dungeon`, `is_raid`, `is_arena`, and `is_battleground`.
- Shared action gate now supports `min_level` and `max_level`.
- Mage Arcane now has low-level Fireball/Frostbolt fallback before Arcane Blast is learned.
- Hunter BM/MM/Survival aspect upkeep no longer depends on Call Pet readiness.
- Smite Priest now has solo/leveling/PvP self-protection, peel, and Shadowfiend mana support.
- Discipline/Holy Priest, Resto Druid, Holy Paladin, and Restoration Shaman now have explicit solo damage fallback gates that stay behind healing stability and mana checks.
- Hunter BM/MM/Survival now resolve live pets from `NS.GetPet()`, gate pet-only abilities on live pets, keep Call/Revive pet out of combat, and add pre-Steady leveling rows.
- Warrior Kebab now has a general-use decision path for leveling/no-offhand contexts that prioritizes Mortal Strike and raises Heroic Strike rage dumping.
- Druid Caster is now labeled as a leveling/solo lane and blocks raid/PvP use unless the selected playstyle is explicitly Caster.
- Shared core now exposes lowercase pet helper aliases used by hunter/warlock middleware and resolves `cc_target` actions directly instead of falling back to the current target.
- Mage Arcane now has explicit PvP control gates for Counterspell, Polymorph, Frost Nova, and Slow.
- Shaman class spell map now exposes PvP/utility spells already referenced by rotations and middleware: Frost Shock, Purge, Tremor Totem, Earthbind Totem, Grounding Totem, and Fire Nova Totem.
- Warlock class spell map now fixes Curse of Agony naming, fixes Death Coil rank IDs, and exposes shared PvP/control spells: Fear, Curse of Tongues, Curse of Exhaustion, and Spell Lock.
- Balance Druid shared action executes now pass `context, action`, Balance uses caster Faerie Fire, and Druid class ranks now cover Feral Charge, Maul, Rake, and Rip.
- Rogue shared spell map now exposes the TBC control/defensive/spec spells used by Assassination, Combat, and Subtlety; Assassination now has a pre-Mutilate Sinister Strike leveling builder.
- Warrior shared spell map now fixes Pummel to the TBC interrupt ID and expands Hamstring, Slam, and Rend support.

Next weak targets:
- Remaining Partial rows are mostly leveling profiles that still assume mature talent kits or specialized endgame builds.
- Healer leveling profiles are improved but still not dedicated DPS specs; keep damage conservative unless users explicitly choose damage-focused playstyles.
- Warrior Kebab remains a specialized DW Arms variant; general-use path is safer, not a full Arms replacement.
- S+ still needs live runtime telemetry in Project Sylvanas: cast success, stuck casts, target switches, PvP control DR/overlap, and pet/totem state under real combat.
