# Subtlety Rogue Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Rogue PvP, Wowhead Rogue database/talents, Flux Rogue research, Sonah Subtlety, SlyRotate Rogue.

## Role

PvP/control-focused Rogue build with opener strength, Hemorrhage, Preparation, and Shadowstep. PvE sustained DPS is generally behind Combat.

## Single Target PvE

Priority:
1. Maintain Slice and Dice.
2. Maintain Hemorrhage debuff if the build uses it and physical raid damage benefits.
3. Maintain Rupture on long-lived targets.
4. Hemorrhage as primary builder.
5. Eviscerate when maintenance finishers are safe.

## PvP

- Core gameplay is opener control: Sap, Cheap Shot, Garrote, Premeditation, Kidney Shot, Blind, Gouge, Vanish, Preparation, Shadowstep.
- Hemorrhage supports pressure and combo generation.
- Wound/Crippling/Mind-numbing poisons and Shiv are key.
- Cloak of Shadows is a major defensive/offensive reset tool.

## Multi Target

- Minimal sustained AoE.
- Use control and focus kill target.
- Sappers/bombs if engineering and allowed.

## Consumables, Gear, Sets

- PvP values resilience, stamina, agility, AP, hit to PvP cap, weapon damage.
- PvE off-meta uses physical DPS consumables.

## Automation Notes

- PvP automation should prioritize control opportunities, kick/peel, kill target state, DR, poison application, and burst windows.
- Sonah PvP system has useful concepts for DR and kill-target priority.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

PvP/control-oriented Rogue build using Hemorrhage, openers, Shadowstep if available, stuns, and positional burst.

### Talent Builds and Variants

Hemorrhage, Shadowstep, Preparation, Premeditation, Dirty Deeds, Serrated Blades.

### Core Stats and Caps

Agility, attack power, crit, resilience/stamina for PvP, hit for reliability.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Ambush | 8676, 8724, 8725, 11267, 11268, 11269, 27441 | Assassination | conditional |
| Backstab | 53, 2589, 2590, 2591, 8721, 11279, 11280, 11281, 25300, 26863 | Combat | conditional |
| Blind | 2094 | Subtlety | pvp |
| Cheap Shot | 1833 | Assassination | conditional |
| Hemorrhage | 16511, 17347, 17348, 26864 | Subtlety | core |
| Kidney Shot | 408, 8643 | Assassination | pvp |
| Premeditation | 14183 | Subtlety | conditional |
| Preparation | 14185 | Subtlety | conditional |
| Shadowstep | 36554 | Subtlety | conditional |
| Vanish | 1856, 1857, 26889 | Subtlety | core |

### Single-Target Priority

1. Open with the control opener required by the situation.
2. Maintain Slice and Dice only in longer PvE uptime windows.
3. Use Hemorrhage as efficient builder and raid debuff if assigned.
4. Use Rupture/Eviscerate based on duration and armor/bleed rules.
5. Use Backstab/Ambush for positional burst when energy and setup allow.
6. Preserve cooldowns for control chains in PvP.

### Multi-Target and AoE Matrix

- 2 targets: control one, kill one; damage split is usually wrong.
- 3 targets: Sap/Blind/Gouge/Kidney assignments matter more than cleave.
- 4+ targets: Rogue contributes interrupts/control, not AoE.
- Short-lived adds: stun or burst assigned add.
- CC packs: Subtlety should protect CC, not break it.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Preparation resets are planned around Vanish/Blind/Sprint/Evasion; do not overlap without need.

### Resource Management

Pool energy before openers and stun chains; never starve a planned Kidney Shot.

### Threat Management

Lower sustained PvE but high opener burst; Vanish if needed.

### Utility, Interrupts, and Dispels

Sap, Blind, Gouge, stuns, Kick, Shadowstep interrupts, poisons, peel/disarm-style PvP utility where available.

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
- Conflict policy in `../../Source-Conflict-Register.md`.
- Local implementation notes in `../../LocalReferences.md`.

## Research Expansion Pass — 2026-05-18

### Angle 1: Failure-Case State Table

| Trigger event | Broken behavior | Recovery action | State inputs required | Source |
|---|---|---|---|---|
| Hemorrhage [26864] on bleed-immune target | Wasted energy | Check target bleed immunity; use Sinister Strike instead | `target_bleed_immune` | Wowhead |
| Premeditation [14183] on non-stealth target | Wasted CD | Use only while stealthed | `stealth_active` | Icy Veins |
| Shadowstep [36554] on rooted target | Wasted CD | Check target root status; use Vanish if rooted | `target_rooted`, `vanish_cd` | Wowhead |
| Preparation [14185] on cooldown | Wasted reset | Use only when major CDs (Vanish, Sprint, Evasion) are on CD | `vanish_cd`, `sprint_cd`, `evasion_cd` | Icy Veins |
| Ghostly Strike [14278] on cooldown | Wasted GCD | Track CD; use only when off CD | `ghostly_strike_cd` | Wowhead |
| Energy cap > 100 | Lost energy regeneration | Use Hemorrhage or Backstab to dump | `energy`, `energy_cap` | Wowhead |
| PvP: Sap [6770] on DR target | Wasted GCD | Check DR before sap; use Blind instead | `sap_dr` | Arena |

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
| Rogue Subtlety | Target | Hemorrhage [26864] | 26864 | +physical damage debuff | Maintain on boss | Wago DB2 |
| Rogue Subtlety | Target | Expose Armor [26866] | 26866 | -armor debuff | When no Warrior tank | Icy Veins |
| Rogue Subtlety | Target | Wound Poison [22055] | 22055 | -healing debuff | When healing target | Wowhead |
| Warrior Arms | Rogue Subtlety | Sunder Armor [25225] | 25225 | Major armor debuff; skip Expose if present | `target_has_sunder` | Icy Veins |
| Paladin Blessing | Rogue Subtlety | Blessing of Might [25291] | 25291 | +AP | Apply to Rogue | Wowhead |
| Shaman Enhancement | Rogue Subtlety | Windfury Totem [25505] | 25505 | +AP proc | When in melee group | Icy Veins |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base damage | AP coefficient | Energy cost | GCD | DPE | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Hemorrhage [26864] | 110 + 0.15 AP | 0.15 | 35 | 1.5 | 3.1 | 73 | >3s | Primary builder |
| Backstab [26863] | 150 + 0.20 AP | 0.20 | 60 | 1.5 | 2.5 | 100 | Behind target | Stealth position |
| Eviscerate [26867] | 500 + 0.15 AP | 0.15 | 35 | 1.0 | 14.3 | 500 | 4-5 CP | Finisher |
| Slice and Dice [6774] | +30% haste | N/A | 25 | 1.0 | +30% | +30% | Any | Buff maintenance |
| Ghostly Strike [14278] | 150 + 0.10 AP | 0.10 | 40 | 1.5 | 3.8 | 100 | >3s | Evasion bonus |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Energy < 40 | No Hemorrhage; auto-attack only | Wait for energy tick | None — time-based | `energy`, `hemo_cost` |
| Energy < 25 | No finisher; auto-attack only | Wait for energy tick | None — time-based | `energy`, `finisher_cost` |
| Combo points < 4 | No Eviscerate; use Rupture or SnD | Build CP with Hemorrhage | None — builder required | `combo_points` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Hemorrhage debuff maintenance | Maintain on boss | Often let drop | LIKELY BUG | Lost physical damage buff | Add `hemo_debuff_remains < 3` refresh | Wowhead |
| Premeditation usage | Use while stealthed before opener | Often used out of stealth | LIKELY BUG | Wasted CP generation | Add `stealth_active` check | Icy Veins |
| Slice and Dice uptime | Maintain 100% uptime | Often let drop | LIKELY BUG | Lost haste | Add `snd_remains < 3` refresh | Wowhead |
| Backstab positioning | Only from behind | Often uses from front | LIKELY BUG | Wasted energy | Add `behind_target` check | Wowhead |
| Shadowstep usage | Use for gap closing | Often wasted on close targets | INTENTIONAL CHOICE | Suboptimal mobility | Add `target_distance > 10` check | Icy Veins |

**Prioritized fix backlog:**
1. Hemorrhage debuff maintenance — physical damage buff
2. Slice and Dice uptime — haste critical
3. Premeditation stealth check — CP generation
4. Backstab positioning — energy efficiency

[NEW FINDING] Rogue Subtlety must maintain Hemorrhage [26864] debuff on boss; re-apply when < 3s remains.
[DB2/WOWHEAD VETTED 2026-05-18] Hemorrhage [26864] is a Subtlety spell; DB2 and Wowhead confirm 35 energy, 15s debuff, 10 charges, and +42 physical damage taken at max rank. Maintain only on bleed/physical-vulnerable targets where uptime has value.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Rogue Subtlety research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
