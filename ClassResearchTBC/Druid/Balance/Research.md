# Balance Druid Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Balance Druid, Wowhead Balance Druid rotation/talents, Flux Druid research, Sonah Balance.

## Role

Ranged caster DPS and raid support. Balance is brought less for top personal DPS and more for Moonkin Form caster crit, Improved Faerie Fire physical-hit support, Innervate/Rebirth utility, and flexible off-healing/control.

## Single Target

Priority:
1. Maintain Faerie Fire if the raid benefits from armor reduction or Improved Faerie Fire.
2. Maintain Insect Swarm when mana and debuff value justify it.
3. Maintain Moonfire when mana allows and target lives long enough.
4. Use Force of Nature on long fights where pets will not cause pathing or threat problems.
5. Cast Starfire as primary filler.
6. Use Wrath as a movement/conserve/faster-cast fallback where appropriate.

Notes:
- Nature's Grace changes cast timing after crits, so refresh windows should avoid clipping current Starfire casts.
- Mana matters. Drop Moonfire/Insect Swarm before starving the Starfire core.
- Barkskin before Hurricane if incoming damage may break the channel.

## Multi Target

- Apply Faerie Fire to priority targets if physical DPS will focus them.
- Moonfire only a small number of targets if they live long enough and mana is healthy.
- Hurricane for stacked targets, ideally with Barkskin.
- Starfire priority target when AoE is weak, dangerous, or mana-prohibitive.

## PvP

- Balance wins through instant pressure, Cyclone, roots, shapeshift snare breaks, off-healing, and kiting.
- Preserve Barkskin for pressure or emergency casts.
- Use Cyclone defensively or to deny heals; use Entangling Roots/Nature's Grasp outdoors.

## Consumables, Gear, Sets

- Spell damage, spell hit to cap, spell crit, intellect, and MP5/spirit by mana needs.
- Tailoring sets and Spellstrike-style bonuses are major early caster gear references.
- Flask of Blinding Light or elixir setup depending on content; Super Mana Potion/Dark Rune for long fights.

## Automation Notes

- Track Faerie Fire, Moonfire, Insect Swarm, Nature's Grace, Force of Nature CD, Hurricane target count, mana tier.
- Add a mana-conserve mode that drops DoTs before dropping all DPS.
- Local Sonah refresh windows are useful, but code should adjust based on cast state and target time-to-die.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Caster support DPS built around Starfire/Wrath throughput, Moonkin Aura, Improved Faerie Fire utility, and mana-aware DoT usage.

### Talent Builds and Variants

Moonkin Form, Vengeance, Moonfury, Improved Faerie Fire, Lunar Guidance, Dreamstate, Balance of Power, Nature's Grace.

### Core Stats and Caps

Spell hit to cap, spell damage, spell crit, intellect, mp5/spirit as needed for fight length.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Barkskin | 22812 | Balance | conditional |
| Cyclone | 33786 | Balance | pvp |
| Entangling Roots | 339, 1062, 5195, 5196, 9852, 9853, 26989 | Balance | conditional |
| Faerie Fire | 770, 778, 9749, 9907, 26993 | Balance | core |
| Hurricane | 16914, 17401, 17402, 27012, 42230, 42231, 42232, 42233 | Balance | conditional |
| Innervate | 29166 | Balance | core |
| Insect Swarm | 5570, 24974, 24975, 24976, 24977, 27013 | Balance | conditional |
| Moonfire | 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835, 26987, 26988 | Balance | core |
| Starfire | 2912, 8949, 8950, 8951, 9875, 9876, 25298, 26986 | Balance | core |
| Wrath | 5176, 5177, 5178, 5179, 5180, 6780, 8905, 9912, 26984, 26985 | Balance | core |

### Single-Target Priority

1. Keep Improved Faerie Fire active when assigned and talented.
2. Use Insect Swarm when the debuff slot and mana budget justify it.
3. Use Moonfire for movement, short kill windows, or when a planned refresh will not starve Starfire casts.
4. Cast Starfire as the default raid filler; swap to Wrath only for short windows, pushback-sensitive moments, or if haste/timing makes it cleaner.
5. Use Innervate by assignment, not greedily, unless self-mana failure would end damage output.

### Multi-Target and AoE Matrix

- 2 targets: keep Faerie Fire assignment and Starfire the priority target; DoT only if both targets live long enough.
- 3 targets: Hurricane only when mobs are controlled by the tank and mana permits.
- 4+ targets: Hurricane becomes primary if threat is safe; otherwise focus skull and avoid breaking CC.
- Short-lived adds: Moonfire/Starfire priority targets instead of full DoT setup.
- CC packs: never Hurricane or Moonfire-spread near sheep/trap/sap targets.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Use Force of Nature if available on boss uptime windows; save Barkskin for predictable raid damage or PvP pressure; Innervate follows raid assignment.

### Resource Management

Cancel low-value Moonfire/Insect Swarm refreshes when mana is below the planned burn floor; prefer Starfire for damage per mana.

### Threat Management

Balance threat is bursty during trinket/crit windows; pause DoT refreshes and delay Hurricane if the tank has not established AoE threat.

### Utility, Interrupts, and Dispels

Remove Curse, Abolish Poison, roots/cyclone in PvP, battle resurrection if available in the game context, and emergency off-healing.

### PvP Playstyle

Use mobility, forms, Cyclone, roots, HoTs, and shapeshift snare breaks. Feral wins with control into burst; Restoration wins by pre-HoT and line-of-sight; Balance wins by burst windows and control.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Druid/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
- Conflict policy in `../../Source-Conflict-Register.md`.
- Local implementation notes in `../../LocalReferences.md`.

## Research Expansion Pass — 2026-05-18

### Angle 1: Failure-Case Table
| Condition | Action | Stop condition |
|---|---|---|
| No valid hostile target | Hold all DPS; keep Moonkin Form [24858] only if already active | Valid target acquired |
| Moving | Use instant maintenance only: Moonfire [26988], Insect Swarm [27013], Faerie Fire [26993] | Stationary cast window opens |
| Pushback / channel risk | Cast Barkskin [22812] before Hurricane [27012] | Channel ends or damage is stable |
| Threat spike / tank not stable | Delay Force of Nature [33831] and Hurricane [27012]; use Starfire [26986] or Wrath [26984] | Tank lead is safe |
| Mana floor hit | Drop Moonfire [26988] / Insect Swarm [27013] refreshes; conserve with Wrath [26984] | Mana returns above conserve floor |
| Target TTD below DoT payoff | Skip Moonfire [26988] / Insect Swarm [27013]; burst with Starfire [26986] | Uptime extends beyond DoT duration |
| Faerie Fire already covered by Feral Faerie Fire [27011] | Skip caster Faerie Fire [26993] | Feral debuff falls off |

### Angle 2: Boss Modifier Table
| Condition | Action | Stop condition |
|---|---|---|
| Patchwerk / long uptime boss | Full maintenance: Faerie Fire [26993], Force of Nature [33831], Moonfire [26988], Insect Swarm [27013], Starfire [26986] filler | Boss enters movement/phase break |
| Forced movement boss | Prefer Moonfire [26988] / Insect Swarm [27013] / Faerie Fire [26993]; defer Starfire [26986] and Hurricane [27012] | Standstill window returns |
| Add-wave boss with 3+ stacked enemies | Pop Hurricane [27012] with Barkskin [22812] support; otherwise swap back to Starfire [26986] on priority target | Adds die or split |
| Pushback-heavy damage phase | Save Barkskin [22812] for Hurricane [27012] or skip channel entirely | Incoming damage stabilizes |
| Tank-swap / threat-reset boss | Hold Force of Nature [33831] and delayed DoTs until tank lead settles | New tank established |
| Mana-drain / marathon boss | Enter Wrath [26984] conserve after dropping Moonfire [26988] if needed; use Innervate [29166] only by assignment | Mana floor recovers |
| Immunity / phase transition | Stop DoT refresh and cooldown usage | Phase reopens |

### Angle 3: Cross-Spec Table
| Condition | Action | Stop condition |
|---|---|---|
| Feral Druid already maintains Faerie Fire (Feral) [27011] | Skip caster Faerie Fire [26993] | Feral debuff missing |
| Feral Druid covers Mangle (Cat) [33983] / Mangle (Bear) [33987] | Keep Balance globals on Starfire [26986] / Wrath [26984] instead of redundant bleed support | Bleed debuff falls off and no Feral can refresh |
| Restoration Druid is assigned mana support | Reserve Innervate [29166] for assignment, not self-greed | Assignment resolved or self mana critical |
| Rebirth coverage is needed | Hold Rebirth [20484/20739/20741/20742/20747/26994] for recovery, not rotation filler | Combat stabilizes |
| Another Balance Druid already provides Moonkin Form [24858] | Treat form as passive state, not a raid-maintenance task | Form active |
| Raid has enough caster sustain from support specs | Extend Starfire [26986] window before Wrath [26984] conserve | Mana floor drops or movement starts |
| CC / utility demand from druid team | Use Cyclone [33786] or Entangling Roots [339/1062/5195/5196/9852/9853/26989] only when that spec is not needed for healing uptime | Control need ends |

### Angle 4: Resource Efficiency Table
| Condition | Action | Stop condition |
|---|---|---|
| Around 800 SP verified | Favor Starfire [26986] filler; keep Moonfire [26988] / Insect Swarm [27013] only on long uptime; conserve by dropping one DoT before Wrath [26984] spam | TTD < 12s or mana below full-rotation floor |
| Around 1000 SP verified | Keep both DoTs on raid bosses; Starfire [26986] stays primary filler, Wrath [26984] only when mana floor is crossed or movement forces it | Mana falls into conserve band |
| Around 1200 SP verified | Full maintenance becomes efficient enough that Force of Nature [33831] + double-DoT + Starfire [26986] is the default; Hurricane [27012] becomes worth the GCD on 3+ targets if safe | Target shifts to short-lived add or heavy movement |

### Angle 5: Implementation Divergence Table
| Condition | Action | Stop condition |
|---|---|---|
| Flux reference baseline | Use order Faerie Fire [26993] → Force of Nature [33831] → Insect Swarm [27013] → Moonfire [26988] → Starfire [26986] → Wrath [26984]; mana tiers: >40 full, 20-40 conserve, <20 Wrath-only | Mana tier changes |
| Sonah reference baseline | Auto-enter Moonkin Form [24858]; Clearcasting turns into immediate Starfire [26986]; Faerie Fire [26993] is checked before DoTs; Moonfire [26988] is refreshed before Insect Swarm [27013] | Clearcasting expires or DoT refresh window closes |
| EaxRotations implementation | State builder tracks `moonfire_remains`, `insect_remains`, `ff_remains`, `natures_grace_active`; `balance_starfire_mana` gates Wrath [26984] fallback and skips caster Faerie Fire [26993] when `has_feral_druid` is true | Moving or mana below floor |
| SlyRotate_FeralDruid.lua | Use only as layout/UI reference for Feral rows; it does not implement Balance spell ordering | Balance-specific logic needed |
| `SlyRotate_Druid.lua` [REPO CONFIRMED ABSENT] | File is absent in repo; use `SlyRotate_FeralDruid.lua` instead for local druid UI pattern only | Path resolved on 2026-05-18 |

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Druid Balance research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
