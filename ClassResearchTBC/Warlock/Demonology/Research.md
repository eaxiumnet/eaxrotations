# Demonology Warlock Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Demonology Warlock, Wowhead Warlock database/talents, Flux Warlock research, Sonah Demonology, SlyRotate Warlock.

## Role

Warlock branch focused on pet durability/damage and survivability. TBC Demonology can be Felguard-oriented or Demonic Sacrifice/Ruin style depending on build and phase.

## Single Target

Felguard-style priority:
1. Keep Felguard alive and attacking.
2. Assigned curse.
3. Corruption/Immolate if worth the GCD.
4. Shadow Bolt filler.
5. Life Tap safely.
6. Use pet cooldowns/utility manually or by opt-in rules.

Sacrifice-style priority:
1. Maintain Demonic Sacrifice buff from assigned pet.
2. Assigned curse.
3. Shadow Bolt filler or fire filler depending on sacrifice/build.
4. Life Tap safely.

## Multi Target

- Seed of Corruption is primary AoE.
- Rain of Fire for stacked stationary targets.
- Pet cleave/targeting can add value but should not break CC.

## PvP

- Demonology PvP values durability, Soul Link if talented, Felguard pressure, Fear/Death Coil, and pet utility.
- Pet survival and target swaps matter.

## Consumables, Gear, Sets

- Spell hit, spell power, stamina, pet-scaling considerations, crit/haste.
- Flask of Pure Death or Blinding Light depending on spell school build; Destruction Potion; healthstone.

## Automation Notes

- Track pet existence/health/range, sacrifice buff, assigned curse, DoTs, Life Tap safety, Soul Link, target CC risk.
- Flux has clear pet-choice-per-spec notes; Sonah/SlyRotate provide compact pet-management priorities.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Pet-centric Warlock DPS built around Felguard/demon uptime, Shadow Bolt filler, curse assignment, and survivability.

### Talent Builds and Variants

Summon Felguard, Demonic Knowledge, Master Demonologist, Demonic Aegis, Fel Stamina, Soul Link in PvP/survival builds.

### Core Stats and Caps

Spell hit to cap, spell damage, stamina/intellect, spell crit/haste, pet scaling considerations.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Corruption | 172, 6222, 6223, 7648, 11671, 11672, 25311, 27216 | Affliction | core |
| Curse of Agony | 980, 1014, 6217, 11711, 11712, 11713, 27218 | Affliction | core |
| Curse of Doom | 603, 30910 | Affliction | core |
| Demonic Knowledge | 35691, 35692, 35693 | Demonology | conditional |
| Fel Domination | 18708 | Demonology | conditional |
| Health Funnel | 755, 3698, 3699, 3700, 11693, 11694, 11695, 27259 | Demonology | conditional |
| Life Tap | 1454, 1455, 1456, 11687, 11688, 11689, 27222 | Affliction | core |
| Shadow Bolt | 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307, 27209 | Destruction | core |
| Soulshatter | 29858 | Demonology | conditional |
| Summon Felguard | 30146 | Demonology | core |

### Single-Target Priority

1. Keep assigned curse active.
2. Keep pet attacking and alive.
3. Use Corruption only if it will tick and debuff slots allow.
4. Cast Shadow Bolt as filler.
5. Life Tap before mana collapse.
6. Health Funnel or reposition pet if pet death would cost more than a cast.

### Multi-Target and AoE Matrix

- 2 targets: pet on priority target; DoT second only if it lives.
- 3 targets: multidot carefully; pet cleave if Felguard can safely stand in.
- 4+ targets: Seed if talented/available and threat stable; otherwise Shadow Bolt priority.
- Short-lived adds: send pet and Shadow Bolt/shadowburn-style tools if available.
- CC packs: pet cleave and DoTs can break control.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Pet cooldowns and trinkets with boss uptime; preserve Felguard during cleave/magic bursts.

### Resource Management

Life Tap plus pet health management; avoid tapping into lethal raid damage.

### Threat Management

Pet threat and player threat both matter; Soulshatter/throttle during Seed or trinket windows.

### Utility, Interrupts, and Dispels

Banish, Fear, Curse assignments, Healthstones, Soulstones, pet stun/intercept, enslave demon.

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
| Felguard [30146] dies during combat | Lost major DPS pet | Re-summon immediately; pre-cast before risky phases | `felguard_alive`, `summon_cd` | Wowhead |
| Demonic Empowerment [47193] DB2 absent | Wasted GCD | Do not use; spell not in TBC | `spell_known_demonic_empowerment` | Wago DB2 |
| Soul Fire [30551] cast interruption | Lost big nuke | Cancel cast, queue Shadow Bolt [27209] instead | `cast_interrupted`, `soul_fire_cast_time` | Icy Veins |
| Metamorphosis [47241] DB2 absent | Wasted cooldown | Do not use; spell not in TBC | `spell_known_metamorphosis` | Wago DB2 |
| Demon Soul [77801] DB2 absent | Wasted GCD | Do not use; spell not in TBC | `spell_known_demon_soul` | Wago DB2 |
| Mana floor < 20% | Cannot sustain Shadow Bolt spam | Life Tap [27222]; drop Immolate [27215] | `mana_pct`, `life_tap_cd` | Icy Veins |
| PvP: Banish [18647] on player | Diminishing returns fast | Use Fear [6215] or Death Coil [27223] instead | `banish_dr` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Shade of Aran | BURST-WINDOW | Arcane Explosion = stop cast, pre-shield | `aran_casting_explosion` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = stop cast, max range | `gruul_shatter_timer` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant spells | `lurker_spout_active` | Icy Veins |
| TK | Al'ar | MOVEMENT | Phoenix adds = movement; Felguard on adds | `alar_phoenix_active` | Wowhead |
| Black Temple | Reliquary | SILENCE | Phase 2 silence = pre-DoT, stop cast | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Warlock Demonology | Raid | Demonic Pact [47236] DB2 absent | N/A | N/A | N/A | Wago DB2 |
| Warlock Demonology | Raid | Fel Intelligence [54424] DB2 absent | N/A | N/A | N/A | Wago DB2 |
| Warlock Demonology | Target | Curse of Elements [27228] | 27228 | +10% spell damage | Apply to boss | Icy Veins |
| Warlock Demonology | Target | Curse of Recklessness [27226] | 27226 | +AP, -armor | When no CoE needed | Wowhead |
| Priest Shadow | Warlock Demonology | Vampiric Touch [34914] | 34914 | Reduces Life Tap frequency | VT uptime > 80% | Icy Veins |
| Paladin Blessing | Warlock Demonology | Blessing of Salvation [1038] | 1038 | -30% threat | Apply to all Warlocks | Wago DB2 |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base dmg | SP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Shadow Bolt [27209] | 700 | 0.857 | 420 | 2.5 | 1.7 | 280 | >4s | Primary nuke |
| Soul Fire [30551] | 1200 | 1.15 | 650 | 6.0 | 1.8 | 200 | >7s | Big nuke |
| Immolate [27215] | 600 | 0.20 | 445 | 1.5 | 1.3 | 400 | >15s | DoT maintenance |
| Incinerate [29722] | 550 | 0.714 | 340 | 2.5 | 1.6 | 220 | >4s | Fire filler |
| Life Tap [27222] | 0 | 0 | 0 | 1.5 | ∞ | 0 | Any | Mana conversion |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Life Tap [27222] immediately | Drop Immolate [27215] if needed | Life Tap | `mana_pct`, `life_tap_cd` |
| Mana < 15% | Life Tap only; no nukes | All spells forbidden | Potion + Life Tap | `mana_pct`, `potion_cd` |
| HP < 30% | Stop Life Tap; use Drain Life [27217] | Self-heal priority | Healer support | `hp_pct`, `drain_life_cd` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Felguard uptime | Keep Felguard alive always | Often lets die without resummon | LIKELY BUG | Major DPS loss | Add `felguard_alive` check | Wowhead |
| Demonic Empowerment attempt | Spell not in TBC | May attempt to cast | TBC GUARDRAIL VIOLATION | GCD waste | Remove from rotation | Wago DB2 |
| Metamorphosis attempt | Spell not in TBC | May attempt to cast | TBC GUARDRAIL VIOLATION | GCD waste | Remove from rotation | Wago DB2 |
| Soul Fire timing | Use only when TTD > 7s | Often casts on short-lived targets | LIKELY BUG | Wasted cast time | Add `target_ttd > 7` gate | Icy Veins |
| Incinerate vs Shadow Bolt | SB primary, Incinerate only if fire spec | Often wrong nuke for spec | INTENTIONAL CHOICE | Suboptimal DPS | Add `spec_check` nuke picker | Wowhead |

**Prioritized fix backlog:**
1. Felguard uptime — DPS critical
2. Demonic Empowerment removal — TBC compliance
3. Metamorphosis removal — TBC compliance
4. Soul Fire target lifetime — cast efficiency

[NEW FINDING] Warlock Demonology must ensure Felguard [30146] uptime; resummon immediately on death.
[DB2 VETTED 2026-05-18] Demonic Empowerment [47193], Metamorphosis [47241], Demon Soul [77801], Demonic Pact [47236], and Fel Intelligence [54424] are absent from `wow_anniversary` SpellName and class skillline DB2; do not implement them for TBC Demonology.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Warlock Demonology research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
