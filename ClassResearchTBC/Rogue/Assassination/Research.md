# Assassination Rogue Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Rogue, Wowhead Rogue database/talents, Flux Rogue research, Sonah Assassination, SlyRotate Rogue.

## Role

Poison/crit/burst-oriented Rogue branch. In TBC PvE, Combat is usually stronger for sustained raid DPS, while Assassination contributes burst and poison-focused gameplay. Verify Mutilate availability and tuning for the exact TBC target before implementation.

## Single Target

Priority:
1. Maintain Slice and Dice.
2. Maintain Rupture on long-lived targets if bleed is not wasted.
3. Use appropriate builder: Mutilate if valid/talented and weapon requirements met; otherwise Backstab/Sinister Strike by weapon setup.
4. Use Cold Blood with high-value finisher or burst plan.
5. Eviscerate or Envenom only when poison stacks/rules make it worthwhile.
6. Maintain poisons on both weapons.

## Multi Target

- Rogue AoE is limited.
- Blade Flurry is Combat, not Assassination baseline.
- Use tab-target control/interrupts; focus priority target.
- Engineering sappers can be the main burst AoE contribution.

## PvP

- Cheap Shot/Kidney Shot, Blind, Gouge, Kick, Wound/Crippling/Mind-numbing poison, Vanish, Cloak of Shadows.
- Cold Blood burst can force defensive cooldowns.
- Shiv can apply utility poison quickly where available.

## Consumables, Gear, Sets

- Agility, hit, expertise, attack power, crit, weapon damage.
- Flask of Relentless Assault, Haste Potion, Thistle Tea if usable in target ruleset, poisons, sharpening/weightstone only when poison not required.
- Verify set bonuses before changing Slice/Rupture/Envenom logic.

## Automation Notes

- Track energy, combo points, SnD remains, Rupture remains, poison enchants/stacks, Cold Blood, target armor class, PvP control DR if available.
- Sonah has useful poison check and anti-caster chain logic.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Poison/dagger-focused DPS or PvP build using Mutilate, Slice and Dice, Rupture/Envenom/Eviscerate decisions, and control.

### Talent Builds and Variants

Mutilate, Vile Poisons, Improved Poisons, Seal Fate, Find Weakness, Cold Blood.

### Core Stats and Caps

Hit, expertise where available, agility, attack power, crit, haste, weapon skill considerations.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Backstab | 53, 2589, 2590, 2591, 8721, 11279, 11280, 11281, 25300, 26863 | Combat | conditional |
| Cold Blood | 14177 | Assassination | conditional |
| Envenom | 32645, 32684, 39967 | Assassination | conditional |
| Eviscerate | 2098, 6760, 6761, 6762, 8623, 8624, 11299, 11300, 26865, 31016 | Assassination | core |
| Kick | 1766, 1767, 1768, 1769, 38768 | Combat | core |
| Kidney Shot | 408, 8643 | Assassination | pvp |
| Mutilate | 1329, 34411, 34412, 34413 | Assassination | core |
| Rupture | 1943, 8639, 8640, 11273, 11274, 11275, 26867 | Assassination | core |
| Slice and Dice | 5171, 6774 | Assassination | core |
| Vanish | 1856, 1857, 26889 | Subtlety | core |

### Single-Target Priority

1. Open from stealth when possible.
2. Keep Slice and Dice active.
3. Use Mutilate as primary builder when dagger/poison requirements are met.
4. Use Rupture if the target will live and bleed is allowed.
5. Use Envenom only when poison stack/consumption and raid rules make it worthwhile.
6. Use Eviscerate for short-lived or bleed-immune targets.

### Multi-Target and AoE Matrix

- 2 targets: keep Slice and Dice and focus skull; Blade Flurry is Combat-only.
- 3 targets: tab Rupture is niche and usually not worth lost priority damage.
- 4+ targets: Rogue AoE is weak in TBC; single-target dangerous mobs.
- Short-lived adds: build/finish quickly with Eviscerate/Kidney if control needed.
- CC packs: Sap/Blind/Gouge duties outrank cleave.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Cold Blood with high-value finisher; Vanish for threat reset, opener reset, or PvP control.

### Resource Management

Pool energy before finishers and Kidney Shot; avoid capping during movement.

### Threat Management

Use Feint/Vanish before pulling; watch poison/finisher spikes.

### Utility, Interrupts, and Dispels

Kick, stuns, Blind, Sap, Gouge, Expose Armor if assigned, poisons including Mind-numbing/Wound in PvP.

### PvP Playstyle

Open from stealth with a plan: sap one, lock one, blind/trinket punish, and reset with Vanish. Energy pooling and DR awareness matter more than raw button speed.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Rogue/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

### Encounter and Mob Modifiers

- Delay burst until tank threat is established.
- Switch to priority adds when they threaten healers, objectives, or encounter failure.
- Use interrupts/dispels even when it costs personal DPS if the mechanic is lethal.
- Avoid cleave/AoE near controlled mobs.
- Respect resist/immunity phases and swap school/target when required.

### Automation Rules

- Nil-guard every menu option that controls this spec's behavior.
- Cache hot-path Project Sylvanas API references at module load.
- Add `cc_safe`, `threat_safe`, `resource_floor`, and `movement` checks before optional damage.
- Treat local Flux/Sonah/SlyRotate findings as implementation references, not as game-data authority.
- Prefer DB2 spell IDs and talent gates over name-only logic.

### Source Notes

- Class DB2 spell index in `../DB2-Spells.md`.
- Class DB2 talent index in `../DB2-Talents.md`.
- Class gear/set index in `../Gear-and-Sets.md`.
- Shared mechanics in `../../Shared/Mechanics.md`.
- Shared consumables in `../../Shared/Consumables-and-Professions.md`.
- Shared gear/set policy in `../../Shared/Gear-and-Set-Pieces.md`.
- Shared PvP mechanics in `../../Shared/PvP-Mechanics.md`.
- Encounter modifiers in `../../Encounters/`.
- Master source list in `../../Sources.md`.
- Local implementation notes in `../../LocalReferences.md`.

## Research Expansion Pass — 2026-05-18

### Angle 1: Failure-Case State Table

| Trigger event | Broken behavior | Recovery action | State inputs required | Source |
|---|---|---|---|---|
| Mutilate [34413] on poison-immune target | Wasted energy | Check target poison immunity; use Sinister Strike instead | `target_poison_immune` | Wowhead |
| Envenom [32645] at 1-2 combo points | Suboptimal damage | Use only at 4-5 combo points | `combo_points` | Icy Veins |
| Slice and Dice [6774] expiry mid-combat | Lost haste buff | Re-cast SnD before expiry; track remaining time | `snd_remains`, `snd_duration` | Wowhead |
| Rupture [26867] on short-lived target | Wasted DoT ticks | Use only when TTD > 12s | `target_ttd` | Icy Veins |
| Deadly Poison [27282] stack drop | Lost poison damage | Re-apply before stack drops; track application time | `deadly_poison_stacks`, `poison_remains` | Wago DB2 |
| Energy cap > 100 | Lost energy regeneration | Use Mutilate or Envenom to dump | `energy`, `energy_cap` | Wowhead |
| PvP: Kidney Shot [8643] on DR target | Wasted GCD | Check DR before stun; use Cheap Shot instead | `kidney_dr` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Attumen | MOVEMENT | Mounted phase = movement; instant abilities | `attumen_mounted` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = max melee range; stop melee | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant abilities | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = target switching | `alar_phoenix_active` | Icy Veins |
| Black Temple | Supremus | KITE-PHASE | Volcano = move; ranged only | `supremus_volcano_active` | Wowhead |
| Black Temple | Shahraz | FATAL-ATTRACTION | Spread = stop melee | `fatal_attraction_active` | Icy Veins |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Wowhead |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = spread | `felmyst_gas_nova_casting` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Rogue Assassination | Target | Deadly Poison [27282] | 27282 | DoT poison | Maintain 5-stack | Wago DB2 |
| Rogue Assassination | Target | Wound Poison [22055] | 22055 | -healing debuff | When healing target | Icy Veins |
| Rogue Assassination | Target | Expose Armor [26866] | 26866 | -armor | When no Warrior tank | Wowhead |
| Warrior Arms | Rogue Assassination | Sunder Armor [25225] | 25225 | Major armor debuff; skip Expose if present | `target_has_sunder` | Icy Veins |
| Paladin Blessing | Rogue Assassination | Blessing of Might [25291] | 25291 | +AP | Apply to Rogue | Wowhead |
| Shaman Enhancement | Rogue Assassination | Windfury Totem [25505] | 25505 | +AP proc | When in melee group | Icy Veins |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base damage | AP coefficient | Energy cost | GCD | DPE | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Mutilate [34413] | 200 + 0.15 AP | 0.15 | 60 | 1.5 | 3.3 | 133 | >3s | Primary builder |
| Envenom [32645] | 400 + 0.20 AP | 0.20 | 35 | 1.5 | 11.4 | 267 | 4-5 CP | Finisher |
| Rupture [26867] | 800 + 0.05 AP | 0.05 | 25 | 1.0 | 32.0 | 800 | >12s | DoT finisher |
| Slice and Dice [6774] | +30% haste | N/A | 25 | 1.0 | +30% | +30% | Any | Buff maintenance |
| Deadly Poison [27282] | 150/stack | 0.05 | 0 | 0 | ∞ | 0 | Any | Passive poison |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Energy < 40 | No Mutilate; auto-attack only | Wait for energy tick | None — time-based | `energy`, `mutilate_cost` |
| Energy < 25 | No finisher; auto-attack only | Wait for energy tick | None — time-based | `energy`, `finisher_cost` |
| Combo points < 4 | No Envenom; use Rupture or SnD | Build CP with Mutilate | None — builder required | `combo_points` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Mutilate target check | Only on poisoned target | Often uses on unpoisoned target | LIKELY BUG | Lost damage bonus | Add `target_poisoned` check | Wowhead |
| Envenom combo point gate | Only at 4-5 CP | Often uses at 2-3 CP | LIKELY BUG | Suboptimal damage | Add `combo_points >= 4` gate | Icy Veins |
| Slice and Dice uptime | Maintain 100% uptime | Often let drop | LIKELY BUG | Lost haste | Add `snd_remains < 3` refresh | Wowhead |
| Rupture target lifetime | Only when TTD > 12s | Often uses on short-lived targets | LIKELY BUG | Wasted DoT ticks | Add `target_ttd > 12` gate | Icy Veins |
| Poison selection | Deadly for DPS, Wound for PvP | Often wrong poison for content | INTENTIONAL CHOICE | Suboptimal performance | Add `content_type` poison picker | Wowhead |

**Prioritized fix backlog:**
1. Slice and Dice uptime — haste critical
2. Envenom CP gate — damage optimization
3. Rupture target lifetime — DoT efficiency
4. Mutilate poison check — damage bonus

[NEW FINDING] Rogue Assassination must maintain Slice and Dice [6774] at 100% uptime; re-cast when < 3s remains.
[DB2/WOWHEAD VETTED 2026-05-18] Mutilate [34413] is an Assassination spell; Wowhead confirms 60 energy, both-weapon attack, +50% damage against poisoned targets, behind-target requirement, and 2 combo points. Keep poison and behind-target gates before casting.

- Local implementation notes in `../../LocalReferences.md`.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Rogue Assassination research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

### Source-Use Contract

| Source tier | What to trust | What not to copy | Implementation requirement |
|---|---|---|---|
| DB2/Wago and class DB2 indexes | Spell IDs, ranks, talent gates, cooldown/cast-time fields | Rotation priority or player behavior assumptions | Resolve spells from IDs/rank lists before runtime use |
| Online TBC guides in `Sources.md` | Priority shape, role duties, cooldown/resource heuristics | Retail, Wrath, or private-server-only mechanics | Keep guide-derived thresholds configurable when sources disagree |
| Local Flux reference | State names, settings ideas, middleware ordering, edge cases | Framework APIs, every-frame cadence, unverified comments | Transfer concepts only after matching them to Project Sylvanas APIs |
| Local Sonah reference | Practical toggles, PvP hints, target helper ideas | Addon APIs, localization assumptions, non-TBC comments | Treat as implementation signal, then verify against DB2/Tier 2 sources |
| Local SlyRotate reference | Compact priority sanity checks where the class/spec is covered | Missing spec coverage as evidence against a mechanic | Use only as a secondary check, never as sole authority |
| Current Research.md | Merged spec contract and source-backed decisions | Unresolved `[VERIFY]` rows as shippable behavior | Implement only rows that are TBC-valid and source-backed |

### Implementation Priority Contract

| Condition | Action | Stop condition |
|---|---|---|
| Target is invalid, immune, out of range, or unsafe | Acquire or hold a valid target according to Utility and Encounter rules | Target becomes valid and safe |
| Mandatory debuff, buff, stance, pet, form, or weapon state is missing | Apply the documented maintenance action from the DB2 table | Maintenance state is active or combat priority overrides it |
| Execute/burst window is active | Run the documented execute or cooldown priority with TTD/resource gates | Burst window ends, target dies, or resource floor is reached |
| Single-target combat is active | Run Single-Target Priority in order, using documented refresh thresholds | Higher-priority condition appears or action is queued |
| Multi-target threshold is met | Run Multi-Target/AoE Matrix with CC, threat, and resource gates | Enemy count drops below threshold or AoE becomes unsafe |
| Resource floor is reached | Enter conserve/recovery behavior from Resource Management | Resource recovers above floor or execute/emergency override applies |
| Utility, interrupt, purge, dispel, or PvP condition is dangerous | Execute the documented utility action before filler DPS | Utility condition resolved or unsafe to act |

### Role State Inputs

| State input | Required use | Guardrail |
|---|---|---|
| `target`, `target_ttd`, `target_count` | Select single-target, execute, cleave, or AoE priority from this document | Do not apply long setup to targets below the documented lifetime floor |
| `resource_pct`, `resource_income`, `resource_floor` | Enter burn, conserve, or recovery priorities | Do not spend below the floor unless the document marks an exception |
| `cooldown_state`, `trinket_state`, `burst_window` | Align cooldowns with the Cooldown Usage section | Do not use long cooldowns into low-TTD or downtime windows |
| `buff_state`, `debuff_state`, `stack_state` | Maintain only effects listed in the DB2 spell table and priorities | Do not refresh early unless the refresh threshold is documented |
| `movement_state`, `range_los_map`, `swing_or_cast_state` | Pick instant, casted, or swing-gated actions | Do not clip swing/cast/tick mechanics unless the document says to do so |
| `threat_state`, `cc_safe`, `pvp_state` | Gate optional burst, AoE, and utility | Do not break CC or overtake tank threat with filler actions |

### Codegen Acceptance Checks

| Condition | Action | Stop condition |
|---|---|---|
| Spell is not present in the DB2-verified table or class DB2 indexes | Block implementation and mark `[VERIFY]` instead of inventing behavior | Spell is verified or removed |
| Local reference uses non-Sylvanas APIs | Translate the behavior to Project Sylvanas APIs from `api/` and `apidocs/` | No external addon/framework API remains |
| Menu-controlled behavior is generated | Nil-guard every menu access and provide a conservative default | All menu reads are guarded |
| Hot-path callback calls game APIs repeatedly | Cache API function references at module load and throttle expensive scans | Callback uses cached references and documented throttles |
| Target scanning is needed | Cap scans, reuse static tables, and short-circuit on high-confidence result | Scan is bounded and allocation-safe |
| Optional DPS, AoE, or utility can break CC/threat/resource rules | Gate it behind `cc_safe`, `threat_safe`, and `resource_floor` checks | Optional action is skipped or safe |
| A non-TBC mechanic appears in a source or generated plan | Reject it and use the TBC-era alternative documented in this research set | No forbidden mechanic is introduced |
| Implementation changes priority behavior | Add or update focused regression coverage for the changed gate | Test or validation note exists |
