# Destruction Warlock Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Destruction Warlock, Wowhead Warlock database/talents, Flux Warlock research, Sonah Destruction, SlyRotate Warlock.

## Role

Direct-damage caster DPS. Common TBC raid variants include Shadow Bolt/Ruin style and fire Incinerate/Immolate style. Threat and Life Tap safety are major concerns.

## Single Target

Shadow build:
1. Assigned curse.
2. Shadow Bolt filler.
3. Maintain Improved Shadow Bolt debuff through crits passively.
4. Life Tap safely.

Fire build:
1. Assigned curse.
2. Maintain Immolate.
3. Incinerate filler.
4. Conflagrate only if talented/enabled and consuming Immolate is worth it.
5. Life Tap safely.

Cooldowns:
- Trinkets/racials/destruction potion in burn windows.
- Shadowfury is mostly PvP/AoE control if talented.

## Multi Target

- Seed of Corruption is usually the strongest AoE when packs live long enough.
- Shadowfury for burst/control if talented.
- Rain of Fire for stationary stacked AoE.
- Hellfire only with defensive awareness.

## PvP

- Burst through Shadow Bolt/Incinerate/Conflagrate/Shadowburn windows, plus Death Coil, Fear, Howl, Shadowfury.
- Maintain pet utility and avoid Life Tap when killable.

## Consumables, Gear, Sets

- Spell hit, spell power by school, crit/haste, stamina for PvP.
- Flask of Pure Death for shadow/fire? Verify exact school mapping; Destruction Potion is common burst.
- Tailoring caster sets matter.

## Automation Notes

- Track assigned curse, Immolate remains, Conflagrate CD and consume policy, Life Tap safety, threat, Seed target count.
- Flux explicitly warns that TBC Conflagrate consumes Immolate; preserve that gate.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Direct-damage Warlock DPS using Shadow Bolt or fire/Incinerate variants, curse assignment, Life Tap, and Seed AoE.

### Talent Builds and Variants

Ruin, Shadow and Flame, Backlash, Devastation, Emberstorm/Shadowburn/Conflagrate depending variant.

### Core Stats and Caps

Spell hit to cap, shadow/fire damage, spell crit, haste, stamina/intellect.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Conflagrate | 17962, 18930, 18931, 18932, 27266, 30912 | Destruction | conditional |
| Curse of Agony | 980, 1014, 6217, 11711, 11712, 11713, 27218 | Affliction | core |
| Curse of Doom | 603, 30910 | Affliction | core |
| Immolate | 348, 707, 1094, 2941, 11665, 11667, 11668, 25309, 27215 | Destruction | core |
| Incinerate | 29722, 32231 | Destruction | core |
| Life Tap | 1454, 1455, 1456, 11687, 11688, 11689, 27222 | Affliction | core |
| Seed of Corruption | 27243, 27285 | Affliction | core |
| Shadow Bolt | 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307, 27209 | Destruction | core |
| Soulshatter | 29858 | Demonology | conditional |

### Single-Target Priority

1. Apply assigned curse.
2. For shadow build, cast Shadow Bolt as the default filler.
3. For fire build, keep Immolate up and cast Incinerate filler.
4. Use Conflagrate only in a build that plans around it and does not waste Immolate value.
5. Life Tap during movement or low-value windows.
6. Use Shadowburn/instant tools only if shard and kill timing justify it.

### Multi-Target and AoE Matrix

- 2 targets: maintain primary rotation; DoT second if long-lived.
- 3 targets: Seed can be used if mobs are clumped and tank threat is stable.
- 4+ targets: Seed of Corruption is primary AoE but has high threat.
- Short-lived adds: Shadowburn/Conflagrate/Shadow Bolt priority add.
- CC packs: Seed is disabled near controlled mobs.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Trinkets with Shadow Bolt/Incinerate burn and Bloodlust/Heroism; avoid burst into threat cap.

### Resource Management

Life Tap early enough; align taps with movement and heal coverage.

### Threat Management

Destruction burst and Seed threat are high; Soulshatter/throttle before pulling.

### Utility, Interrupts, and Dispels

Banish, Fear, Curse assignments, Healthstones, Soulstones, pet utility, enslave demon.

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
| Conflagrate [17962] without Immolate [27215] | Wasted GCD and CD | Check Immolate active before Conflagrate | `immolate_active`, `conflagrate_cd` | Wowhead |
| Shadowburn [18871] on non-shadow-immune target | Wasted shard | Check target type before Shadowburn | `target_shadow_immune` | Icy Veins |
| Chaos Bolt [50796] DB2 absent | Wasted GCD | Do not use; spell not in TBC | `spell_known_chaos_bolt` | Wago DB2 |
| Rain of Fire [27212] on single target | Wasted mana | Use only when 4+ targets | `target_count` | Icy Veins |
| Backdraft [54274] DB2 absent | Wasted proc | Do not use; spell not in TBC | `spell_known_backdraft` | Wago DB2 |
| Mana floor < 20% | Cannot sustain Shadow Bolt spam | Life Tap [27222]; drop Immolate if needed | `mana_pct`, `life_tap_cd` | Icy Veins |
| PvP: Chaos Bolt attempt | Spell not in TBC | Use Shadow Bolt [27209] or Soul Fire [30551] | `spell_known_chaos_bolt` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Shade of Aran | BURST-WINDOW | Arcane Explosion = stop cast, pre-shield | `aran_casting_explosion` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = stop cast, max range | `gruul_shatter_timer` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant spells | `lurker_spout_active` | Icy Veins |
| TK | Al'ar | MOVEMENT | Phoenix adds = movement; Rain of Fire value | `alar_phoenix_active` | Wowhead |
| Black Temple | Reliquary | SILENCE | Phase 2 silence = pre-DoT, stop cast | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Warlock Destruction | Target | Curse of Elements [27228] | 27228 | +10% spell damage | Apply to boss | Wago DB2 |
| Warlock Destruction | Target | Curse of Doom [27228] | 27228 | Big DoT | On long-lived boss | Icy Veins |
| Warlock Destruction | Raid | Imp Fire Shield [2947] | 2947 | Minor fire resistance | Pre-pull | Wowhead |
| Priest Shadow | Warlock Destruction | Vampiric Touch [34914] | 34914 | Reduces Life Tap frequency | VT uptime > 80% | Icy Veins |
| Mage Fire | Warlock Destruction | Scorch [27074] | 27074 | Fire damage debuff; no direct interaction | N/A | Wowhead |
| Paladin Blessing | Warlock Destruction | Blessing of Salvation [1038] | 1038 | -30% threat | Apply to all Warlocks | Wago DB2 |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base dmg | SP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Shadow Bolt [27209] | 700 | 0.857 | 420 | 2.5 | 1.7 | 280 | >4s | Primary nuke |
| Incinerate [29722] | 550 | 0.714 | 340 | 2.5 | 1.6 | 220 | >4s | Fire filler |
| Conflagrate [17962] | 800 | 0.50 | 305 | 1.5 | 2.6 | 533 | >3s | Requires Immolate |
| Immolate [27215] | 600 | 0.20 | 445 | 1.5 | 1.3 | 400 | >15s | Conflagrate setup |
| Rain of Fire [27212] | 400/target | 0.17 | 2165 | 8.0 | 0.2 | 50 | 4+ targets | Channeled AoE |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Life Tap [27222] immediately | Drop Immolate [27215] if needed | Life Tap | `mana_pct`, `life_tap_cd` |
| Mana < 15% | Life Tap only; no nukes | All spells forbidden | Potion + Life Tap | `mana_pct`, `potion_cd` |
| HP < 30% | Stop Life Tap; use Drain Life [27217] | Self-heal priority | Healer support | `hp_pct`, `drain_life_cd` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Conflagrate prerequisite | Check Immolate active before Conflagrate | Often casts without Immolate | LIKELY BUG | Wasted GCD and CD | Add `immolate_active` check | Wowhead |
| Chaos Bolt attempt | Spell not in TBC | May attempt to cast | TBC GUARDRAIL VIOLATION | GCD waste | Remove from rotation | Wago DB2 |
| Rain of Fire target count | Only use when 4+ targets | Often used on 2-3 targets | LIKELY BUG | Mana waste | Add `target_count >= 4` check | Icy Veins |
| Backdraft attempt | Spell not in TBC | May attempt to track | TBC GUARDRAIL VIOLATION | State complexity | Remove tracking | Wago DB2 |
| Shadowburn usage | Only on shadow-immune or execute | Often used on normal targets | INTENTIONAL CHOICE | Shard waste | Add `target_shadow_immune` check | Wowhead |

**Prioritized fix backlog:**
1. Conflagrate prerequisite — DPS correctness
2. Chaos Bolt removal — TBC compliance
3. Rain of Fire target count — mana efficiency
4. Backdraft removal — TBC compliance

[NEW FINDING] Warlock Destruction Conflagrate [17962] must verify Immolate [27215] is active before casting.
[DB2 VETTED 2026-05-18] Chaos Bolt [50796] and Backdraft [54274] are absent from `wow_anniversary` SpellName and class skillline DB2; do not implement them for TBC Destruction.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Warlock Destruction research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
