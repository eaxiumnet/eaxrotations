# Affliction Warlock Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Affliction Warlock, Wowhead Warlock database/talents, Flux Warlock research, Sonah Affliction, SlyRotate Warlock.

## Role

DoT-focused caster DPS with curse utility, strong sustained pressure, and a Life Tap/Dark Pact mana engine. In raids, curse assignment often overrides personal DPS.

## Single Target

Priority:
1. Apply assigned curse: Elements, Shadow, Recklessness, Tongues, Doom, or Agony by raid plan.
2. Maintain Unstable Affliction if talented.
3. Maintain Corruption.
4. Maintain Siphon Life if talented and worth the GCD.
5. Maintain Immolate if build/mana/debuff slots justify it.
6. Shadow Bolt filler.
7. Life Tap/Dark Pact before going OOM, ideally during movement or low DPS opportunity.
8. Use trinkets/racials in burn windows.

## DoT Rules

- Do not refresh early unless the remaining time is inside a safe refresh window or the target will phase.
- Target lifetime and debuff slots matter.
- Shadow Embrace and Improved Shadow Bolt interactions should be tracked if relevant to group strategy.

## Multi Target

- Seed of Corruption is the main TBC Warlock AoE on packs that live long enough.
- Corruption/UA/Siphon Life spreading only if targets live long enough and mana allows.
- Rain of Fire for stationary stacked AoE; Hellfire is dangerous.

## PvP

- DoT pressure, Fear/Howl, Death Coil, Curse of Tongues/Exhaustion, Felhunter Spell Lock/Devour Magic.
- Preserve instant casts for movement/pressure; Life Tap safely.

## Consumables, Gear, Sets

- Spell hit, shadow damage/spell power, haste, crit, stamina for PvP.
- Frozen Shadoweave/Spellstrike-style gear can be major.
- Flask of Pure Death, Destruction Potion, Super Mana Potion is less important than Life Tap but still useful.

## Automation Notes

- Track all assigned DoTs/curses, target time-to-die, Life Tap safety, pet state, movement, debuff slot policy.
- Flux has the best curse and Life Tap helper patterns.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

DoT and support DPS using Curse assignment, Unstable Affliction, Corruption, Siphon Life, Shadow Bolt filler, and life/mana conversion.

### Talent Builds and Variants

Unstable Affliction, Shadow Mastery, Contagion, Empowered Corruption, Malediction, Suppression.

### Core Stats and Caps

Spell hit to cap, shadow damage, spell haste/crit, stamina/intellect for life tap buffer.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Corruption | 172, 6222, 6223, 7648, 11671, 11672, 25311, 27216 | Affliction | core |
| Curse of Agony | 980, 1014, 6217, 11711, 11712, 11713, 27218 | Affliction | core |
| Curse of Doom | 603, 30910 | Affliction | core |
| Drain Life | 689, 699, 709, 7651, 11699, 11700, 27219, 27220 | Affliction | conditional |
| Fear | 5782, 6213, 6215 | Affliction | utility |
| Life Tap | 1454, 1455, 1456, 11687, 11688, 11689, 27222 | Affliction | core |
| Shadow Bolt | 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307, 27209 | Destruction | core |
| Siphon Life | 18265, 18879, 18880, 18881, 27264, 30911 | Affliction | conditional |
| Unstable Affliction | 30108, 30404, 30405, 31117 | Affliction | core |

### Single-Target Priority

1. Apply assigned curse first.
2. Keep Unstable Affliction active if talented and it will tick.
3. Keep Corruption active.
4. Use Siphon Life/Curse of Agony if debuff slots and duration support them.
5. Use Shadow Bolt as filler.
6. Life Tap during movement or low-damage windows before mana failure.

### Multi-Target and AoE Matrix

- 2 targets: DoT second target if it lives long and debuff slots allow.
- 3 targets: multidot high-health targets; maintain assigned curse.
- 4+ targets: Seed of Corruption if available, safe, and tank threat is stable.
- Short-lived adds: Shadow Bolt/instant DoT only if ticks matter.
- CC packs: DoTs and Seed can break control; avoid near banish/fear/sheep.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Use trinkets with DoT refreshes and Shadow Bolt windows; pet cooldowns by demon choice.

### Resource Management

Life Tap is required; schedule taps around heal coverage and movement.

### Threat Management

DoTs plus Seed can overtake tanks; use Soulshatter if available in target rules and throttle Seed.

### Utility, Interrupts, and Dispels

Banish, Fear, Curse assignments, Healthstones, Soulstones, enslave demon, interrupts through pet where available.

### PvP Playstyle

Fear/DoT/pet control and drain pressure. Protect pet, use curses by matchup, Banish/enslave demons, and do not overextend while dots do the work.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Warlock/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| DoT refresh too early (>3s remaining) | Wasted GCD and mana | Refresh only when < 1.5s remains | `dot_remains`, `dot_duration` | Wowhead |
| Life Tap [27222] during heavy damage | Wasted GCD, risk of death | Life Tap only when `incoming_dps == 0` or shielded | `incoming_dps`, `life_tap_hp_floor` | Icy Veins |
| Shadow Embrace [32388] stack drop | Lost +5% shadow damage | Rebuild stack immediately; prioritize UA/CoA | `shadow_embrace_stacks` | Wowhead |
| Seed of Corruption [27243] on single target | Wasted AoE spell | Use only when 3+ targets clustered | `target_count` | Icy Veins |
| Nightfall [18094] proc mid-cast | Wasted instant Shadow Bolt | Track proc; queue after current cast | `nightfall_active`, `cast_in_progress` | Wago DB2 |
| Mana floor < 20% | Cannot sustain DoT rotation | Life Tap [27222] immediately; drop lowest-priority DoT | `mana_pct`, `life_tap_cd` | Icy Veins |
| PvP: Fear [6215] on DR target | Wasted GCD | Check DR before fear; use Death Coil [27223] instead | `fear_dr` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Shade of Aran | BURST-WINDOW | Arcane Explosion = stop cast, pre-shield | `aran_casting_explosion` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = stop cast, max range | `gruul_shatter_timer` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant DoTs | `lurker_spout_active` | Icy Veins |
| TK | Al'ar | MOVEMENT | Phoenix adds = movement; Seed of Corruption value | `alar_phoenix_active` | Wowhead |
| Black Temple | Reliquary | SILENCE | Phase 2 silence = pre-DoT, stop cast | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Warlock Affliction | Raid | Curse of Elements [27228] | 27228 | +10% spell damage | Apply to all bosses | Wago DB2 |
| Warlock Affliction | Target | Unstable Affliction [30405] | 30405 | DoT + silence on dispel | Maintain on PvP targets | Icy Veins/Wago DB2 |
| Warlock Affliction | Target | Siphon Life [30911] | 30911 | Self-heal DoT | Maintain for survivability | Wowhead |
| Priest Shadow | Warlock Affliction | Vampiric Touch [34914] | 34914 | Reduces Life Tap frequency | VT uptime > 80% | Icy Veins |
| Mage Fire | Warlock Affliction | Scorch [27074] | 27074 | Fire damage debuff; no direct interaction | N/A | Wowhead |
| Paladin Blessing | Warlock Affliction | Blessing of Salvation [1038] | 1038 | -30% threat | Apply to all Warlocks | Wago DB2 |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base dmg | SP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Unstable Affliction [30405] | 1050 over 18s | 1.2 total | 400 | 1.5 | 2.6 | 700 | >18s | Primary DoT |
| Corruption [27216] | 900 | 1.2 | 370 | 1.5 | 2.4 | 600 | >18s | Secondary DoT |
| Curse of Agony [27218] | 1800 | 1.2 | 265 | 1.5 | 6.8 | 1200 | >24s | Curse slot |
| Shadow Bolt [27209] | 700 | 0.857 | 420 | 2.5 | 1.7 | 280 | >4s | Nightfall proc |
| Seed of Corruption [27243] | 800 | 1.0 | 822 | 2.0 | 1.0 | 400 | 3+ targets | AoE |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Life Tap [27222] immediately | Drop lowest-priority DoT (CoA > Siphon) | Life Tap | `mana_pct`, `life_tap_cd` |
| Mana < 15% | Life Tap only; no DoT refreshes | All DoTs forbidden | Potion + Life Tap | `mana_pct`, `potion_cd` |
| HP < 30% | Stop Life Tap; use Drain Life [27217] | Self-heal priority | Healer support | `hp_pct`, `drain_life_cd` |

**Part C — Debuff Uptime Value**

| Debuff [ID] | Dmg 60s fight | Dmg 20s fight | Drop priority | Refresh early? | Notes |
|---|---|---|---|---|---|
| Unstable Affliction [30405] | ~2500 | ~900 | High | No, clip <1.5s | Primary DoT |
| Corruption [27216] | ~2200 | ~800 | High | No, clip <1.5s | Secondary DoT |
| Curse of Agony [27218] | ~3500 | ~1200 | Medium | No, clip <1.5s | Curse slot |
| Siphon Life [30911] | ~1800 | ~600 | Low | No, clip <1.5s | Self-heal DoT |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| DoT refresh timing | Refresh at < 1.5s remaining | Often refreshed at >3s | LIKELY BUG | Wasted GCDs and mana | Add `remains < 1.5` check | Wowhead |
| Life Tap timing | Tap when mana < 30% and HP safe | Often taps at 50% mana or low HP | LIKELY BUG | Mana inefficiency or death | Add `mana < 30` + `hp > 50` gates | Icy Veins |
| Seed of Corruption target count | Only use when 3+ targets | Often used on single target | LIKELY BUG | Mana waste | Add `target_count >= 3` check | Wowhead |
| Curse assignment | Elements on boss, Agony on secondary | Often wrong curse for encounter | INTENTIONAL CHOICE | Suboptimal raid damage | Add `target_priority` curse picker | Icy Veins |
| Nightfall consumption | Use immediately on proc | Often delayed or missed | LIKELY BUG | Lost instant Shadow Bolts | Add `nightfall → immediate_SB` | Wowhead |

**Prioritized fix backlog:**
1. DoT refresh timing — GCD efficiency critical
2. Life Tap safety gates — survival
3. Nightfall consumption — DPS
4. Seed target count — mana efficiency

[NEW FINDING] Warlock Affliction DoTs should refresh only when < 1.5s remains to avoid clipping and mana waste.
[DB2/WOWHEAD VETTED 2026-05-18] Unstable Affliction max rank is [30405]; the previously used ID resolves to Shadowfury in Warlock DB2. UA [30405] deals 1050 over 18s with 0.20 SP coefficient per 3s tick, for 1.20 total coefficient over full duration.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Warlock Affliction research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
