# Frost Mage Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Frost Mage, Wowhead Mage database/talents, Flux Mage research, Sonah Frost, SlyRotate Mage.

## Role

Lower PvE ceiling than Fire/Arcane in many raid contexts, but strong control, survivability, leveling, farming, and PvP performance. PvE rotation is simple and stable.

## Single Target

Priority:
1. Use Icy Veins with trinkets/burn windows.
2. Summon Water Elemental when talented and target uptime is good.
3. Frostbolt filler.
4. Cold Snap to reset Icy Veins/Water Elemental/Ice Block when valuable.
5. Mana Gem/Evocation/potions as needed.

## Multi Target

- Blizzard for ranged stacked AoE and slows.
- Cone of Cold/Frost Nova/Arcane Explosion when safe.
- Maintain control; do not break CC unintentionally.

## PvP

- Frost Nova, Cone of Cold, Ice Barrier, Ice Block, Cold Snap, Water Elemental Freeze, Polymorph, Counterspell, Blink.
- Shatter combos and control windows matter more than PvE filler.

## Consumables, Gear, Sets

- Spell hit, frost spell damage, crit/haste, stamina for PvP.
- Flask of Pure Death or elixir setup; Destruction Potion for burst; mana tools.

## Automation Notes

- Track Icy Veins, Water Elemental, Cold Snap, Ice Barrier, Ice Block, Frostbolt cast state, movement and PvP control needs.
- Keep PvE logic intentionally simple; complexity belongs in PvP/control modules.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Control-oriented caster using Frostbolt consistency, Water Elemental burst, survivability, and strong AoE control.

### Talent Builds and Variants

Summon Water Elemental, Empowered Frostbolt, Ice Shards, Shatter, Cold Snap, Ice Barrier, Winter's Chill if assigned.

### Core Stats and Caps

Spell hit to cap, spell damage, spell crit, haste where available, stamina for PvP/survival.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Blizzard | 10, 6141, 8427, 10185, 10186, 10187, 27085, 42198, 42208, 42209, 42210, 42211, 42212, 42213 | Frost | core |
| Cold Snap | 11958 | Frost | conditional |
| Cone of Cold | 120, 8492, 10159, 10160, 10161, 27087 | Frost | conditional |
| Counterspell | 2139 | Arcane | core |
| Frost Nova | 122, 865, 6131, 10230, 27088 | Frost | pvp |
| Frostbolt | 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304, 27071, 27072, 38697 | Frost | core |
| Ice Block | 45438 | Frost | conditional |
| Ice Lance | 30455 | Frost | conditional |
| Polymorph | 118, 12824, 12825, 12826, 28271, 28272 | Arcane | core |
| Summon Water Elemental | 31687 | Frost | conditional |

### Single-Target Priority

1. Maintain Winter's Chill if assigned by raid comp.
2. Cast Frostbolt as the default filler.
3. Use Water Elemental during burn/uptime windows.
4. Use Ice Lance mainly when target is frozen, moving, or finishing.
5. Use Cold Snap to reset Water Elemental/Ice Block defensively or offensively by plan.
6. Avoid overusing low-value instant casts that reduce Frostbolt uptime.

### Multi-Target and AoE Matrix

- 2 targets: Frostbolt priority and control secondary.
- 3 targets: Blizzard if mobs are clumped and tank threat is stable.
- 4+ targets: Blizzard and Nova/Cone control by assignment.
- Short-lived adds: instant control and Frostbolt kill target.
- CC packs: Frost is often responsible for slows; avoid breaking hard CC.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Water Elemental with trinkets and burn windows; Cold Snap only when the reset will be used, not as a panic button with no follow-up.

### Resource Management

Frost is efficient; maintain damage uptime and reserve mana for control/defense in PvP or progression.

### Threat Management

Lower than Fire/Arcane but Blizzard AoE can pull; wait for tank pickup.

### Utility, Interrupts, and Dispels

Polymorph, slows, roots, Counterspell, Spellsteal, Remove Curse, Ice Block, Ice Barrier.

### PvP Playstyle

Control first: Polymorph, Counterspell, novas, slows, Spellsteal, and Ice Block. Burst only when the target is controlled or interrupts are forced.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Mage/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Water Elemental [31687] placement in AoE | Pet dies instantly | Place at max range; move if boss AoE active | `pet_position`, `boss_aoe_active` | Wowhead |
| Frostbolt [38697] pushback during cast | Lost cast time | Use Burning Soul [11108] talent; pre-shield with Ice Barrier | `pushback_count`, `burning_soul_rank` | Icy Veins |
| Ice Barrier [33405] pre-expiry | Shield breaks mid-cast | Re-cast Ice Barrier before expiry; track absorb remaining | `ice_barrier_remains`, `absorb_remaining` | Wowhead |
| Shatter combo window miss | Lost crit opportunity | Track Frostbite [12494] proc; queue Frostbolt immediately | `frostbite_active`, `shatter_window` | Icy Veins |
| Brain Freeze [44549] DB2 absent | Spell unavailable | Do not use; continue Frostbolt spam | `spell_known_brain_freeze` | Wago DB2 |
| Mana floor < 20% | Cannot sustain Frostbolt spam | Switch to lower-rank Frostbolt [38696] | `mana_pct`, `frostbolt_rank` | Icy Veins |
| Cold Snap [12472] on cooldown | Wasted reset | Use only when major CDs (Barrier, Block) are on CD | `cold_snap_cd`, `barrier_cd`, `block_cd` | Wowhead |
| PvP: Counterspell on Frost school | Locked out of all spells | Pre-cast Ice Barrier; use Fire Blast [27070] | `counterspell_school`, `ice_barrier_active` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Shade of Aran | BURST-WINDOW | Arcane Explosion = stop cast, pre-shield | `aran_casting_explosion` | Icy Veins |
| Karazhan | Curator | MANA-DRAIN | Evocation phase = heavy AoE; pop CDs | `curator_evocation` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = stop cast, max range | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant spells | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = movement; Ice Lance [30455] preferred | `alar_phoenix_active` | Icy Veins |
| Black Temple | Reliquary | SILENCE | Phase 2 silence = pre-shield, stop cast | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Mage Frost | Raid | Arcane Brilliance [27127] | 27127 | +Intellect party buff | Pre-pull | Wago DB2 |
| Mage Frost | Target | Winter's Chill [28595] | 28595 | +10% frost crit debuff | Maintain 5-stack | Icy Veins |
| Mage Frost | Raid | Water Elemental [31687] | 31687 | Extra DPS pet | Summon on pull | Wowhead |
| Shaman Elemental | Mage Frost | Totem of Wrath [30706] | 30706 | +crit/spell hit | When in caster group | Icy Veins |
| Priest Shadow | Mage Frost | Vampiric Touch [34914] | 34914 | Longer Frostbolt sustain | VT uptime > 80% | Wowhead |
| Paladin Blessing | Mage Frost | Blessing of Kings [20217] | 20217 | +stats = more mana | When in same group | Icy Veins |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base dmg | SP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Frostbolt [38697] | 800 | 0.814 | 330 | 2.5 | 2.4 | 320 | >4s | Primary nuke |
| Ice Lance [30455] | 200 | 0.43 | 110 | 1.5 | 1.8 | 133 | Frozen target | Shatter combo |
| Blizzard [27085] | 500 | 0.14 | 1645 | 8.0 | 0.3 | 63 | 5+ targets | Channeled AoE |
| Cone of Cold [27087] | 400 | 0.21 | 390 | 1.5 | 1.0 | 267 | 3+ targets close | AoE |
| Ice Barrier [33405] | Absorb 1000 | 0.10 | 310 | 0 | 3.2 | 0 | Any | Survival |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Frostbolt [38696] downrank | Mana Emerald [22044] | Evocation [12051] | `mana_pct`, `emerald_cd` |
| Mana < 15% | Ice Lance [30455] only | All max-rank forbidden | Potion, wait for VT mana | `mana_pct`, `potion_cd` |
| Mana < 5% | Wand only | All spells forbidden | Wait for external mana | `mana_pct` |
| Shatter window | Frostbite [12494] active | Queue Frostbolt immediately | None — consume window | `frostbite_active` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Shatter combo timing | Queue Frostbolt immediately on Frostbite | Often delays, missing window | LIKELY BUG | Lost crit opportunity | Add `frostbite → immediate_frostbolt` | Icy Veins |
| Ice Barrier refresh | Re-cast before expiry, not after break | Often re-casts after breaking | LIKELY BUG | Shield downtime | Add `remains < 5` refresh | Wowhead |
| Water Elemental placement | Place at max range from boss | Often placed in melee range | LIKELY BUG | Pet death | Add `pet_max_range` check | Icy Veins |
| Brain Freeze attempt | Spell not in TBC | May attempt to cast | TBC GUARDRAIL VIOLATION | GCD waste | Remove from rotation | Wago DB2 |
| Winter's Chill maintenance | Maintain 5-stack on boss | Often let expire | MISSING FEATURE | Lost +10% crit for all frost | Add `winter_chill_stacks < 5` refresh | Wowhead |

**Prioritized fix backlog:**
1. Shatter combo timing — DPS critical
2. Ice Barrier refresh — survival
3. Winter's Chill maintenance — raid frost crit
4. Brain Freeze removal — TBC compliance

[NEW FINDING] Mage Frost should queue Frostbolt [38697] immediately upon Frostbite [12494] proc to maximize Shatter combo crit rate.
[DB2 VETTED 2026-05-18] Brain Freeze [44549] is absent from `wow_anniversary` SpellName and class skillline DB2; do not implement it for TBC Frost.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Mage Frost research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
