# TASK — TBC Class Research Expansion

**Sisyphus reads this file first. Then delegates to parallel Hephaestus workers. Then runs ulw-loop until COMPLETION_TRACKER shows all 145 cells done.**

---

## What You Are Doing

The `ClassResearchTBC/` folder is an S+ research base for TBC Classic rotation plugins (Project Sylvanas). It has 29 specs, each with a `Research.md` baseline. Your job is to expand every spec with 5 new research angles and write the findings back to disk. You do not stop until all 145 output sections exist and the COMPLETION_TRACKER at the bottom of this file is fully checked.

---

## Sisyphus: Your Orchestration Plan

### Step 1 — Create log files if they don't exist

```
NEW_FINDINGS_LOG.md    ← root of ClassResearchTBC/
VERIFY_LIST.md         ← root of ClassResearchTBC/
COMPLETION_TRACKER.md  ← root of ClassResearchTBC/
```

Format for NEW_FINDINGS_LOG.md:
```markdown
# New Findings Log
| Spec | Angle | Finding | Source needed |
|---|---|---|---|
```

Format for VERIFY_LIST.md:
```markdown
# Verify List
| Spec | Angle | Claim | Source that would resolve it |
|---|---|---|---|
```

Format for COMPLETION_TRACKER.md:
```markdown
# Completion Tracker
| Spec | A1-Failures | A2-Bosses | A3-Cross | A4-Math | A5-Diff | Done |
|---|---|---|---|---|---|---|
| Druid Balance | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
... (all 29 specs)
```

### Step 2 — Delegate to parallel Hephaestus workers

Spawn background Hephaestus workers using the `deep` category (routes to GPT-5.4 xhigh). Each worker gets one spec cluster. Run all clusters in parallel.

**Cluster assignment — complexity-first order:**

| Worker | Specs | Why first |
|---|---|---|
| W1 | Paladin Retribution, Paladin Holy, Paladin Protection | Seal twisting, faction gates, Judgement system — highest external mechanic count |
| W2 | Shaman Enhancement, Shaman Restoration, Shaman Elemental | Totem twisting, weapon sync, Bloodlust ownership |
| W3 | Druid Feral DPS, Druid Bear Tank, Druid Balance, Druid Restoration | Powershifting state machine, form swap, HoT stacking |
| W4 | Hunter Beast Mastery, Hunter Marksmanship, Hunter Survival | Shot weaving, pet management, Expose Weakness |
| W5 | Warlock Affliction, Warlock Demonology, Warlock Destruction | DoT management, Life Tap math, debuff slot priority |
| W6 | Warrior Protection, Warrior Fury, Warrior Arms | Rage/threat, Slam timing, swing timer |
| W7 | Rogue Combat, Rogue Assassination, Rogue Subtlety | Energy pooling, combo math, poison DR |
| W8 | Priest Shadow, Priest Holy, Priest Discipline, Priest Smite | Vampiric Touch mana chain, downranking, Shadowform |
| W9 | Mage Arcane, Mage Fire, Mage Frost | Burn/conserve math, Ignite stacking, Shatter combo |

### Step 3 — Each Hephaestus worker instruction

Hephaestus receives this instruction per spec:

```
You are working on [CLASS] [SPEC] for TBC Classic (wow_anniversary, build 2.5.5.67511).

Read these files before writing anything:
- ClassResearchTBC/AGENTS.md                          (rules, source tiers, file map)
- ClassResearchTBC/[Class]/[Spec]/Research.md         (S+ baseline — do not duplicate what is here)
- ClassResearchTBC/[Class]/DB2-Spells.md              (spell IDs)
- ClassResearchTBC/[Class]/DB2-Rotation-Relevant-Effects.md
- ClassResearchTBC/Sources.md                         (all source URLs)
- ClassResearchTBC/Source-Conflict-Register.md        (conflict resolution policy)

Then produce all 5 angles below and APPEND them to [Class]/[Spec]/Research.md
under a new header: ## Research Expansion Pass — [DATE]

Also append every [NEW FINDING] row to ClassResearchTBC/NEW_FINDINGS_LOG.md.
Also append every [VERIFY] row to ClassResearchTBC/VERIFY_LIST.md.
Also mark your 5 angle cells as [x] in ClassResearchTBC/COMPLETION_TRACKER.md.

--- ANGLE 1: FAILURE-CASE STATE TABLE ---

Find every rotation-breaking event for this spec. Table columns:
Trigger event | Broken behavior | Recovery action | State inputs required | Source

Cover ALL applicable categories:
- Resource emergencies (energy/rage/mana floor, Life Tap/Shadowfiend/Evocation on cooldown, proc overcap)
- Proc collision (Sword Spec [15229] during finisher GCD, Windfury [25505] double-proc, Clearcast [16870] mid-GCD, Lightning Overload [30675] mid-cast, Arcane Blast [30451] stack drop during latency)
- Debuff/buff expiry races (Rip [1079/9492/9493/9752/9894/9896/27008] 0.5s before GCD frees, SnD [5171] at pool point, Mangle [33917] off while Rip active, VT [34914] mid-cast, Windfury Totem [8512] buff mid-swing, SoB [31892] off before swing)
- Cooldown conflict (BW [19574] + RF [3045] overlap, Combustion [11129] before Ignite [12654], AR [13750] at 3cp low energy, Bloodlust [2825] mid-Life Tap, Tiger's Fury [5217] at full energy)
- Target/encounter state (target dies mid-cast, priority add during committed finisher, phase transition wipes debuffs, immunity mid-tick, interrupt target switches)
- Swing timer disruption (Auto Shot clipped, Slam [1464] before reset, twist too early, off-hand during SS [17364] GCD, pet aggro during BW)
- Form/state machine (powershift below mana floor, powershift collides with Mangle refresh, Shadowform [15473] dropped)
- Threat emergencies (Feint/Vanish too late, Consecration [20116] breaks CC, AoE into CC pack, Misdirection [34477] target dies)
- PvP failure states (interrupt wrong school, Blind [2094] on DoT target, Vanish fails to AoE tick, Poly resisted, dispel wrong DR, trinket after CC)

After table: list new automation state variables not in existing Research.md.

--- ANGLE 2: BOSS MODIFIER TABLE ---

Table columns:
Instance | Boss | Modifier type | What changes | Detection condition | Source

Modifier types: MOVEMENT · ADD-WAVE · INTERRUPT · DISPEL-CLEANSE · RESIST-IMMUNE-PHASE · TANK-SWAP · BURST-WINDOW · DAMAGE-PHASE · CC-REQUIRED · TOTEM-AURA-PLACEMENT · SURVIVAL-MODIFIER · MANA-DRAIN

Cover every encounter in this required list. Write detection condition as a state check, not prose.
Flag [NEW FINDING] if not in existing encounter modifier section. Flag [VERIFY] if boss ability not sourced.

REQUIRED ENCOUNTERS:
Karazhan: Attumen, Moroes, Maiden, Opera (3 forms), Curator, Shade of Aran, Chess, Prince Malchezaar, Nightbane, Netherspite
Gruul: High King Maulgar (5-add council), Gruul (Shatter + Growth)
Magtheridon: Channelers (Shadow Bolt Volley [30510] interrupt), Magtheridon (Blast Nova interrupt, cube phase DPS pause)
SSC: Hydross (resist set transition), Lurker (Spout [37433] + Whirl [37494]), Leotheras (Whirlwind + demon phase), Fathom-Lord (4-add council), Morogrim (Murloc add waves), Lady Vashj (Phase 2 core rotation, Phase 3 burn)
TK: Al'ar (phoenix adds + dive), Void Reaver (Arcane Orb [34942]), Solarian (add + void zone), Kael'thas (add council + legendary + MC)
Hyjal: all wave encounters (infinite adds, boss burn phases)
Black Temple: Najentus (spine + shield), Supremus (kite phase), Akama (adds), Teron (ghost — affected player stops rotation), Gurtogg (Fel Acid [40508] stacking), Reliquary (Phase 2 silence for casters), Shahraz (Fatal Attraction [40869] spread), Council (4-add, dispel/interrupt per member), Illidan (5-phase transitions, Demon Form, Parasitic Shadowfiend [41917], Eye Beams)
Sunwell: Kalecgos (demon/dragon swap), Brutallus (enrage race — no conserve), Felmyst (Gas Nova [45855] — stop DPS spread), Eredar Twins (kill order changes targets), M'uru (add phase + strict threat), Kil'jaeden (Shield Orbs + Darkness [45657] — stop and move)
Heroic Dungeons: Shadow Labyrinth/Murmur (Sonic Boom [33903]), Shattered Halls/Kargath (Blade Dance disengage), Steamvault/Kalithresh (kill naga healers to stop Rage), Mechanar/Pathaleon (adds + AoE suppress), Arcatraz/Skyriss (MC phase), Black Morass (add waves + chrono beacons), Old Hillsbrad/Epoch Hunter (whirlwind kite melee)

Source URLs for encounters:
- Karazhan: https://www.wowhead.com/tbc/guide/karazhan-raid-overview-burning-crusade-classic
- SSC: https://www.wowhead.com/tbc/guide/serpentshrine-cavern-raid-overview-burning-crusade-classic
- TK: https://www.wowhead.com/tbc/guide/the-eye-tempest-keep-raid-overview-burning-crusade-classic
- Hyjal: https://www.wowhead.com/tbc/guide/the-battle-for-mount-hyjal-raid-overview-burning-crusade-classic
- Black Temple: https://www.wowhead.com/tbc/guide/black-temple-raid-overview-burning-crusade-classic
- Sunwell: https://www.wowhead.com/tbc/guide/sunwell-plateau-raid-overview-burning-crusade-classic
- Dungeons: https://www.wowhead.com/tbc/guides/dungeons
- Icy Veins dungeons: https://www.icy-veins.com/tbc-classic/dungeon-guides

--- ANGLE 3: CROSS-SPEC INTERACTIONS (only write the section that is UNIQUE to this spec) ---

Do not duplicate the shared matrix. Only write what is specific to this spec's role as a provider OR receiver.

Columns: Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source

Cover:
- Which buffs this spec provides that change other specs' rotation decisions
- Which buffs from other specs change THIS spec's rotation decisions
- This spec's role in Bloodlust timing — does Bloodlust haste change a breakpoint, tick, or cast window for this spec?
- This spec's debuff(s) in the 40-slot priority ranking — which of its debuffs are mandatory vs droppable
- If this spec is Paladin: Judgement assignment table
- If this spec is Shaman: totem range impact on specific melee specs in group
- If this spec is Shadow Priest: VT mana return math — at what VT uptime % does Warlock Life Tap frequency change?

--- ANGLE 4: RESOURCE EFFICIENCY TABLES ---

Part A — Spell efficiency table:
| Spell [ID] | Base dmg/heal | SP or AP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |

Spellpower breakpoints: 800 / 1000 / 1200 for casters. AP breakpoints: 1500 / 2000 / 2500 for melee.
Source base values from: https://wago.tools/db2/SpellPower/csv?branch=wow_anniversary and https://wago.tools/db2/SpellEffect/csv?branch=wow_anniversary
Flag any priority reversal at a specific breakpoint as [NEW FINDING].

Part B — Resource floor thresholds (only what applies to this spec):
| Resource | Floor condition | Conservation action | Recovery action | State inputs |

Cover what applies: mana % → conserve; energy → wait vs powershift; rage → HS dump threshold; combo points → finisher vs builder; Arcane Blast stacks → Missiles threshold; heal rank → mana % switch point.

Part C — Debuff uptime value (only for DoT specs):
| Debuff [ID] | Dmg 60s fight | Dmg 20s fight | Drop priority | Refresh early? | Notes |

Part D — Downrank table (only for healer specs):
| Spell | Rank | Spell ID | Mana cost | Avg heal | HpM | HpS | Use case | Mana % threshold |

Source: https://wago.tools/db2/SpellPower/csv?branch=wow_anniversary — [VERIFY] if not found.

--- ANGLE 5: IMPLEMENTATION DIVERGENCE TABLE ---

Read the local implementation files for this class before writing:
- ../flux/docs/[CLASS]_RESEARCH.md
- ../Sonah/Classes/[relevant files]
- ../SlyRotate/SlyRotate_[Class].lua

Table columns:
Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source

Divergence types:
- INTENTIONAL CHOICE — valid but suboptimal
- LIKELY BUG — contradicts game mechanics
- MISSING FEATURE — in research, not implemented
- TBC GUARDRAIL VIOLATION — non-TBC spell or mechanic in local code
- FRAMEWORK MISMATCH — correct for local framework, needs Sylvanas translation
- VERIFY — cannot classify without more source confirmation

For LIKELY BUG or GUARDRAIL VIOLATION: name the function/priority row, state correct behavior with DB2 IDs, write corrected condition.
For MISSING FEATURE: list state inputs required; reference the relevant timing doc:
  - Feral: ClassResearchTBC/Druid/Powershifting-Timing.md
  - Retribution: ClassResearchTBC/Paladin/Seal-Twisting-Timing.md
  - Enhancement: ClassResearchTBC/Shaman/Totem-Twisting-Timing.md
  - Hunter: ClassResearchTBC/Hunter/Shot-Timing.md
  - Arms: ClassResearchTBC/Warrior/Slam-Timing.md
  - Rogue: ClassResearchTBC/Rogue/Energy-Poison-Timing.md
  - Warlock: ClassResearchTBC/Warlock/Imp-Machine-Gun-Timing.md
  - Healers: ClassResearchTBC/Shared/Healing-Downrank-Timing.md

After table:
1. Prioritized fix backlog — what to fix first and why
2. Any local pattern better than research currently describes → [RESEARCH UPDATE NEEDED]
3. Transfer rules: adopt as-is vs needs Sylvanas API rewrite
```

### Step 4 — Cross-spec shared pass (Sisyphus runs this directly after all workers complete)

After all 9 workers finish, Sisyphus produces one shared file:
`ClassResearchTBC/Shared/Cross-Spec-Interaction-Matrix.md`

This covers:
- Full 40-debuff slot priority ranking across all specs
- Bloodlust timing matrix (all 29 specs, one row each)
- Judgement assignment table for all group compositions
- Totem range impact map
- VT mana return chain → Warlock Life Tap frequency table
- Three group composition decision tables (physical melee, caster, healer)
- TBC GUARDRAIL CHECK — every ability referenced across the full session, with earliest real expansion

### Step 5 — Final validation pass

Sisyphus reads COMPLETION_TRACKER.md. Any cell still `[ ]` → re-delegate that spec/angle to a fresh Hephaestus worker. Repeat until all 145 cells are `[x]`.

Then produce a summary in TASK.md under `## Session Summary`:
- Total [NEW FINDING] count
- Total [VERIFY] count (= open work items)
- Top 5 highest-risk divergences found in Angle 5
- TBC guardrail violations found (must be zero before shipping code)

---

## DB2 Live Query URLs

Use these to verify any claim during execution:

| Table | URL |
|---|---|
| Spell names | https://wago.tools/db2/SpellName/csv?branch=wow_anniversary |
| Spell power / mana costs | https://wago.tools/db2/SpellPower/csv?branch=wow_anniversary |
| Spell effects / damage | https://wago.tools/db2/SpellEffect/csv?branch=wow_anniversary |
| Spell cooldowns | https://wago.tools/db2/SpellCooldowns/csv?branch=wow_anniversary |
| Spell cast times | https://wago.tools/db2/SpellCastTimes/csv?branch=wow_anniversary |
| Spell durations | https://wago.tools/db2/SpellDuration/csv?branch=wow_anniversary |
| Spell aura options | https://wago.tools/db2/SpellAuraOptions/csv?branch=wow_anniversary |
| Spell misc | https://wago.tools/db2/SpellMisc/csv?branch=wow_anniversary |
| Spell shapeshift | https://wago.tools/db2/SpellShapeshift/csv?branch=wow_anniversary |
| Spell totems | https://wago.tools/db2/SpellTotems/csv?branch=wow_anniversary |
| Talents | https://wago.tools/db2/Talent/csv?branch=wow_anniversary |
| Skill line abilities | https://wago.tools/db2/SkillLineAbility/csv?branch=wow_anniversary |
| Item sets | https://wago.tools/db2/ItemSet/csv?branch=wow_anniversary |
| Item set spells | https://wago.tools/db2/ItemSetSpell/csv?branch=wow_anniversary |
| Wowhead TBC | https://www.wowhead.com/tbc/spells |
| TBCDB | https://www.tbcdb.com/?spells=0 |
| WoWSims TBC | https://wowsims.github.io/tbc/ |
| Icy Veins | https://www.icy-veins.com/tbc-classic/class-guides |
| Warcraft Tavern | https://www.warcrafttavern.com/tbc/guides/ |
| Paladin seals | https://www.warcrafttavern.com/tbc/guides/paladin-seals-judgements/ |
| Shaman totems | https://www.warcrafttavern.com/tbc/guides/shaman-totems/ |
| Feral powershifting | https://www.warcrafttavern.com/tbc/guides/feral-dps-powershifting-rotation-guide/ |
| Totem twisting | https://warcraft.wiki.gg/wiki/Totem_Twisting |
| Karazhan | https://www.wowhead.com/tbc/guide/karazhan-raid-overview-burning-crusade-classic |
| Black Temple | https://www.wowhead.com/tbc/guide/black-temple-raid-overview-burning-crusade-classic |
| Sunwell | https://www.wowhead.com/tbc/guide/sunwell-plateau-raid-overview-burning-crusade-classic |
| SSC | https://www.wowhead.com/tbc/guide/serpentshrine-cavern-raid-overview-burning-crusade-classic |
| TK | https://www.wowhead.com/tbc/guide/the-eye-tempest-keep-raid-overview-burning-crusade-classic |
| Hyjal | https://www.wowhead.com/tbc/guide/the-battle-for-mount-hyjal-raid-overview-burning-crusade-classic |

---

## COMPLETION_TRACKER (Sisyphus maintains this)

| Spec | A1-Failures | A2-Bosses | A3-Cross | A4-Math | A5-Diff | Done |
|---|---|---|---|---|---|---|
| Druid Balance | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Druid Feral DPS | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Druid Bear Tank | [x] | [x] | [x] | [x] | [x] | [x] |
| Druid Restoration | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Hunter Beast Mastery | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Hunter Marksmanship | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Hunter Survival | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Mage Arcane | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Mage Fire | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Mage Frost | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Paladin Holy | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Paladin Protection | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Paladin Retribution | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Priest Discipline | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Priest Holy | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Priest Shadow | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Priest Smite | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Rogue Assassination | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Rogue Combat | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Rogue Subtlety | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Shaman Elemental | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Shaman Enhancement | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Shaman Restoration | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Warlock Affliction | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Warlock Demonology | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Warlock Destruction | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Warrior Arms | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Warrior Fury | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Warrior Protection | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |

**Target: all 145 angle cells [x] before session closes.**

---

## How to Launch This

Drop `AGENTS.md` and `TASK.md` into the root of `ClassResearchTBC/`. Then in your omo terminal:

```
/ulw-loop
```

Sisyphus reads TASK.md, spawns parallel Hephaestus workers via the `deep` category (GPT-5.4 xhigh), and loops until COMPLETION_TRACKER is fully checked. You do not need to do anything else.

---

## Session Summary — 2026-05-18

**Completion Status:** All 145 angle cells `[x]` across 29 specs.

**Total [NEW FINDING] count:** 38 (see `NEW_FINDINGS_LOG.md`)

**Total [VERIFY] count after DB2 vetting:** 8 unresolved verification categories remain in `VERIFY_LIST.md`; hard spell-ID guardrails were resolved on 2026-05-18 against local `wow_anniversary` DB2.

**Highest-Risk Divergences After DB2 Vetting:**
1. **Paladin Retribution:** the prior Seal of the Martyr ID was not present in TBC DB2; use Seal of the Martyr [348700/348701] for Alliance in this target.
2. **Warlock Affliction:** Unstable Affliction must use max rank [30405]; the previously used ID resolves to Shadowfury.
3. **Hunter Survival:** [19434] is Aimed Shot, not Survival Black Arrow; Explosive Shot [53209] and Trap Launcher [77769] are DB2 absent.
4. **Priest/Mage/Warlock modern mechanics:** Penance/Rapture/Guardian Spirit/Dispersion, Focus Magic/Brain Freeze/Living Bomb, and Demonic Empowerment/Metamorphosis/Demon Soul/Chaos Bolt/Backdraft are guardrails only and must not be implemented.
5. **Druid Balance/Feral thresholds:** remaining SP/AP and energy-floor breakpoints still need sim/log confirmation before becoming hard-coded thresholds.

**TBC Guardrail Status:** hard spell-ID guardrails were DB2-vetted on 2026-05-18. Remaining `[VERIFY]` rows are sim/log/runtime-validation items, not unresolved spell existence checks.

**Files Modified/Created:**
- All 29 spec `Research.md` files expanded with 5-angle tables
- `COMPLETION_TRACKER.md` — all 145 cells `[x]`
- `NEW_FINDINGS_LOG.md` — 38 new findings
- `VERIFY_LIST.md` — 8 unresolved verification categories after the 2026-05-18 DB2 vetting pass
- `Shared/Cross-Spec-Interaction-Matrix.md` — new shared file with debuff priority, Bloodlust matrix, Judgement table, totem range map, VT chain, group compositions, and TBC guardrail check

**Remaining Work:**
- Resolve the 8 remaining verification categories against sims, logs, or Sylvanas runtime tests.
- Ensure local code does not implement the DB2-vetted guardrail removals before shipping.
- Cross-reference encounter modifiers against `Encounters/All-Raids-Deep-Matrix.md` and `All-Dungeons-Deep-Matrix.md`
