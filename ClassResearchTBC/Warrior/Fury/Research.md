# Fury Warrior Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Fury Warrior, Wowhead Warrior DPS rotation/talents, Flux Warrior research, Sonah Fury, SlyRotate Warrior.

## Role

Dual-wield sustained physical DPS with high rage throughput. Fury revolves around Bloodthirst, Whirlwind, Rampage, and rage-dump management.

## Single Target

Priority:
1. Maintain Sunder Armor if assigned.
2. Maintain Battle Shout/Commanding Shout as assigned.
3. Maintain Rampage if talented and active conditions are met.
4. Bloodthirst on cooldown.
5. Whirlwind on cooldown.
6. Execute below 20% only as filler when it will not delay Bloodthirst/Whirlwind.
7. Overpower/Hamstring-style proc fishing only if build supports and it will not delay core abilities.
8. Heroic Strike as rage dump at high rage; avoid rage starvation.

## Multi Target

- Whirlwind becomes very high priority.
- Cleave replaces Heroic Strike as rage dump.
- Sweeping Strikes only if Arms hybrid; otherwise use Death Wish/Recklessness carefully.

## PvP

- Fury PvP is less standard than Arms but uses Intercept, Hamstring, Pummel, Death Wish, Berserker Rage, Execute pressure.
- Avoid pure PvE rage dumps when control is needed.

## Consumables, Gear, Sets

- Hit is very valuable for dual wield but distinguish special hit cap from white hit.
- Strength/AP, crit, expertise/weapon skill, haste.
- Flask of Relentless Assault, Haste Potion, Super Sapper Charge.

## Automation Notes

- Track rage thresholds dynamically: reserve rage for BT/WW, dump only above configured threshold.
- Track Rampage remains, Flurry, Death Wish/Recklessness, Execute range, HS/Cleave queued state.
- Flux has the best HS dual-wield miss-penalty note and rage threshold schema.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Dual-wield melee DPS using Bloodthirst, Whirlwind, Heroic Strike rage dump, Execute, and cooldown stacking.

### Talent Builds and Variants

Bloodthirst, Flurry, Rampage, Precision, Dual Wield Specialization, Improved Berserker Stance.

### Core Stats and Caps

Hit to special cap plus dual-wield value, expertise where available, strength/attack power, crit, armor penetration, haste.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Battle Shout | 2048, 5242, 6192, 6673, 11549, 11550, 11551, 25289 | Fury | conditional |
| Berserker Rage | 18499 | Fury | conditional |
| Bloodthirst | 23880, 23881, 23885, 23886, 23887, 23888, 23889, 23890, 23891, 23892, 23893, 23894, 25251, 25252, 25253, 30335, 30339, 30340 | Fury | core |
| Cleave | 845, 7369, 11608, 11609, 20569, 25231 | Fury | conditional |
| Death Wish | 12292 | Arms | conditional |
| Execute | 5308, 20647, 20658, 20660, 20661, 20662, 25234, 25236 | Fury | core |
| Heroic Strike | 78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 29707, 30324 | Arms | core |
| Pummel | 6552, 6554 | Fury | conditional |
| Recklessness | 1719 | Fury | conditional |
| Whirlwind | 1680 | Fury | core |

### Single-Target Priority

1. Maintain Battle Shout/Rampage if assigned and talented.
2. Use Bloodthirst on cooldown.
3. Use Whirlwind on cooldown when rage allows.
4. Queue Heroic Strike only above the rage threshold.
5. Use Execute in execute range without starving higher-priority rules if the implementation models them.
6. Use Berserker Rage for rage/fear utility by encounter.

### Multi-Target and AoE Matrix

- 2 targets: Whirlwind and Cleave gain value; maintain Bloodthirst.
- 3 targets: Cleave rage dump if threat safe.
- 4+ targets: Whirlwind/Cleave but no modern sustained AoE kit.
- Short-lived adds: swap if priority add matters; Execute if low.
- CC packs: disable Cleave near controlled targets.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Stack Death Wish, Recklessness, trinkets, and Bloodlust/Heroism with a strong tank lead.

### Resource Management

Heroic Strike is a rage dump, not a default; preserve rage for Bloodthirst/Whirlwind.

### Threat Management

Fury threat is high; throttle HS/Cleave and coordinate Salvation/Tranquil Air.

### Utility, Interrupts, and Dispels

Shouts, Sunder if assigned, interrupts, Hamstring, Disarm, fear break, emergency taunt/shield if needed.

### PvP Playstyle

Uptime and rage are everything. Hamstring, Intercept, Pummel, Disarm, stance utility, and healer coordination decide whether pressure sticks.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Warrior/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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

### Angle 1: Failure-Case State Table

| Trigger event | Broken behavior | Recovery action | State inputs required | Source |
|---|---|---|---|---|
| Bloodthirst [30335] on cooldown | Wasted GCD | Track BT cooldown; queue Whirlwind [25234] if BT > 1.5s | `bt_cd`, `gcd_remains` | Wowhead |
| Whirlwind [25234] on single target | Suboptimal rage use | Use only when 2+ targets within 8y | `target_count`, `ww_radius` | Icy Veins |
| Rampage [29801/30030/30033] stack drop | Lost +AP buff | Rebuild stack immediately; prioritize over filler | `rampage_stacks` | Wowhead |
| Flurry [12319] proc miss | Lost haste buff | Track proc; consume on next Bloodthirst | `flurry_proc_active` | Icy Veins |
| Execute [25236] at >20% HP | Wasted rage | Use only when target HP <= 20% | `target_hp_pct` | Wago DB2 |
| Rage cap > 100 | Lost rage generation | Dump with Heroic Strike [29707] or Cleave [25231] | `rage`, `rage_cap` | Wowhead |
| PvP: Death Wish [12292] during CC | Cannot break CC | Use Berserker Rage [18499] before Death Wish | `cc_active`, `berserker_rage_cd` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Moroes | ADD-WAVE | Gouge = threat drop; save Whirlwind for adds | `moroes_gouge_active` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = max melee range; stop Whirlwind | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant abilities | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = Whirlwind value | `alar_phoenix_active` | Icy Veins |
| Black Temple | Supremus | KITE-PHASE | Volcano = move; ranged only | `supremus_volcano_active` | Wowhead |
| Black Temple | Shahraz | FATAL-ATTRACTION | Spread = stop melee | `fatal_attraction_active` | Icy Veins |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Wowhead |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = spread | `felmyst_gas_nova_casting` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Warrior Fury | Melee group | Battle Shout [25289] | 25289 | +AP for melee | Always active | Wago DB2 |
| Warrior Fury | Target | Sunder Armor [25225] | 25225 | -armor debuff | Apply if no Prot Warrior | Icy Veins |
| Warrior Fury | Target | Demoralizing Shout [25203] | 25203 | -AP debuff | Maintain on boss | Wowhead |
| Paladin Blessing | Warrior Fury | Blessing of Might [25291] | 25291 | +AP | Apply to Warrior | Icy Veins |
| Shaman Enhancement | Warrior Fury | Windfury Totem [25505] | 25505 | +AP proc | When in melee group | Wowhead |
| Paladin Retribution | Warrior Fury | Sanctity Aura [31869] | 31869 | +10% Holy damage | When in same group | Icy Veins |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base damage | AP coefficient | Rage cost | GCD | DPR | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Bloodthirst [30335] | AP*0.45 | 0.45 | 30 | 1.5 | 3.0 | 600 | >3s | Primary strike |
| Whirlwind [25234] | 2x weapon | 0 | 25 | 1.5 | 2.0 | 533 | 2+ targets | AoE |
| Rampage [30033] | +50 AP/stack at level 70 | N/A | 20 rage | 0 | +50 | +50 | Any | Buff maintenance |
| Execute [25236] | 925 + 21/AP | 0 | 15 | 1.5 | 61.7 | 617 | <=20% HP | Execute phase |
| Heroic Strike [29707] | 208 + weapon | 0 | 15 | 0 | 13.9 | 0 | Any | Rage dump |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Rage < 30 | No Bloodthirst; auto-attack only | Wait for rage | None — time-based | `rage`, `bt_rage` |
| Rage > 80 | Rage cap risk | Heroic Strike [29707] dump | None — dump excess | `rage`, `rage_cap` |
| Rage < 20 | No Rampage; auto-attack only | Wait for rage | None — time-based | `rage`, `rampage_rage` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Bloodthirst priority | BT is #1 on CD | Often delays BT for Whirlwind | LIKELY BUG | DPS loss | Add `bt_cd == 0` priority | Wowhead |
| Whirlwind target count | Only when 2+ targets within 8y | Often used on single target | LIKELY BUG | Rage waste | Add `target_count >= 2` check | Icy Veins |
| Rampage uptime | Maintain 5-stack always | Often let drop | LIKELY BUG | Lost +AP | Add `rampage_stacks < 5` refresh | Wowhead |
| Flurry consumption | Use proc on BT, not filler | Often wastes on Heroic Strike | LIKELY BUG | Lost haste on core ability | Add `flurry → BT` priority | Icy Veins |
| Execute threshold | Only at <= 20% HP | Often used at > 20% | LIKELY BUG | Rage waste | Add `target_hp <= 20` gate | Wowhead |

**Prioritized fix backlog:**
1. Bloodthirst priority — DPS critical
2. Rampage uptime — AP maintenance
3. Whirlwind target count — rage efficiency
4. Flurry consumption — haste optimization

[NEW FINDING] Warrior Fury should prioritize Bloodthirst [30335] over Whirlwind [25234] even on cooldown, and maintain max-rank Rampage [30033] 5-stack at all times.
[DB2/WOWHEAD VETTED 2026-05-18] Rampage cast ranks are [29801/30030/30033]; Wowhead confirms [30033] is the level 70 rank with +50 AP initially and +50 AP per stack, up to 5 stacks for 30s after a crit.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Warrior Fury research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
