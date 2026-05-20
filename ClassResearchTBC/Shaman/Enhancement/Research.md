# Enhancement Shaman Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Enhancement Shaman, Wowhead Enhancement rotation, Warcraft Wiki Totem Twisting, Flux Shaman research, Sonah Enhancement, SlyRotate Shaman.

## Role

Melee DPS and melee-party support through Windfury Totem, Unleashed Rage, Bloodlust/Heroism, shocks, and totem twisting. Enhancement is brought for group output, not just personal DPS.

## Single Target

Priority:
1. Maintain weapon imbues, typically Windfury Weapon main hand and Flametongue/Frostbrand off hand depending on PvE/PvP plan.
2. Maintain assigned totems.
3. Shamanistic Rage when mana is low or defensive value is needed.
4. Stormstrike on cooldown.
5. Flame Shock if weaving and DoT is down.
6. Earth Shock or Frost Shock as primary shock by mode, respecting shared shock cooldown and interrupt needs.
7. Continue melee uptime; do not overcast low-value spells that cost swing uptime/mana.

## Totem Twisting

- Drop Windfury Totem to apply the weapon buff, then swap to Grace of Air while Windfury buff persists.
- Common safe interval is around 9 seconds, but exact behavior should be verified in-game.
- Skip twisting when mana is low, group does not benefit, or movement will force replacement anyway.

## Multi Target

- Fire Nova Totem and Magma Totem are main AoE tools.
- Chain Lightning is not Enhancement core but may be used in caster-heavy hybrid situations if mana allows.
- Continue Stormstrike/shocks on priority target.

## PvP

- Earth Shock interrupt, Frost Shock snare, Grounding/Tremor/Earthbind totems, Purge, Shamanistic Rage, off-heals.
- Weapon imbues may shift toward Frostbrand/control.

## Consumables, Gear, Sets

- Hit/expertise, AP, crit, haste, strength/agility, weapon speed/sync considerations.
- Flask of Relentless Assault, Haste Potion, Super Sapper Charge, mana tools.

## Automation Notes

- Track main/offhand imbues, totem state, Windfury buff estimate, Stormstrike debuff/charges, shared shock CD, mana, Shamanistic Rage, melee range.
- Flux and Sonah together provide the strongest totem-twist state model.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Melee support DPS using Stormstrike, shocks, Windfury/Flametongue decisions, totem twisting, Bloodlust/Heroism, and weapon sync awareness.

### Talent Builds and Variants

Dual Wield, Stormstrike, Unleashed Rage, Flurry, Weapon Mastery, Mental Quickness, Shamanistic Rage.

### Core Stats and Caps

Hit to special cap, expertise where available, strength/agility/attack power, crit, haste, weapon speed and skill.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Bloodlust | 2825 | Enhancement | core |
| Earth Shock | 8042, 8044, 8045, 8046, 10412, 10413, 10414, 25454 | Elemental Combat | core |
| Flame Shock | 8050, 8052, 8053, 10447, 10448, 25457, 29228 | Elemental Combat | conditional |
| Flametongue Weapon | 8024, 8027, 8030, 16339, 16341, 16342, 25489 | Enhancement | conditional |
| Grace of Air Totem | 8835, 10627, 25359 | Enhancement | core |
| Heroism | 32182 | Enhancement | core |
| Stormstrike | 17364, 32175, 32176 | Enhancement | core |
| Strength of Earth Totem | 8075, 8160, 8161, 10442, 25361, 25528 | Enhancement | core |
| Windfury Totem | 8512, 10613, 10614, 25585, 25587 | Enhancement | core |
| Windfury Weapon | 8232, 8235, 10486, 16362, 25505 | Enhancement | conditional |

### Single-Target Priority

1. Maintain correct weapon imbues; Windfury main-hand is core in most physical setups.
2. Keep Strength of Earth/Grace/Windfury totem assignment active.
3. Use Stormstrike on cooldown.
4. Use Earth Shock as primary shock when threat/mana safe; Flame Shock only if it will tick and not conflict with priority.
5. Twist Windfury/Grace only if assigned and swing timing supports it.
6. Use Shamanistic Rage for mana and defensive value.

### Multi-Target and AoE Matrix

- 2 targets: Fire Nova/Magma totem if safe; Stormstrike priority target.
- 3 targets: Magma/Fire Nova gain value but threat is dangerous.
- 4+ targets: totem AoE only after tank control.
- Short-lived adds: shock/Stormstrike priority add.
- CC packs: Magma/Fire Nova can break control; do not automate near CC.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Bloodlust/Heroism by raid assignment; Shamanistic Rage before mana collapse; trinkets with Stormstrike/WF uptime.

### Resource Management

Track mana and weapon swing timers; twisting that clips or starves shocks is a loss.

### Threat Management

Windfury burst can pull; use threat totems/Tranquil Air if assigned and delay shocks during weak tank lead.

### Utility, Interrupts, and Dispels

Purge, Earth Shock interrupts, Tremor/Grounding/Cleansing totems, off-heals, Bloodlust/Heroism.

### PvP Playstyle

Grounding, Tremor, Earth Shock, Purge, Bloodlust/Heroism, and totem management define PvP value. Enhancement uses burst; Elemental uses control burst; Restoration wins through totem utility and Chain Heal/LHW triage.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Shaman/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Totem twist too early | Lost Windfury [25505] proc window | Wait for main-hand swing timer > 0.2s before twist | `mh_swing_timer`, `totem_active` | Warcraft Tavern |
| Weapon sync lost | Off-hand hits before main-hand | Re-sync by stopping auto-attack briefly or swapping weapons | `oh_swing_timer`, `mh_swing_timer` | Icy Veins |
| Stormstrike [17364] on cooldown | Wasted GCD | Track SS cooldown; queue filler if >1.5s | `ss_cd`, `gcd_remains` | Wowhead |
| Shamanistic Rage [30823] during low threat | Wasted threat reduction | Use only when threat > 90% or during burst | `threat_pct`, `rage_cd` | Icy Veins |
| Mana floor < 20% | Cannot maintain shocks | Drop shocks, auto-attack only; use Mana Tide [16190] | `mana_pct`, `mana_tide_cd` | Wowhead |
| Lightning Shield [25472] expiry | Lost passive damage | Re-cast before expiry; track charges | `shield_charges`, `shield_remains` | Wago DB2 |
| PvP: Frost Shock [25464] on DR target | Wasted GCD, no slow | Check DR before casting; use Earthbind [2484] instead | `frost_shock_dr` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Attumen | MOVEMENT | Mounted phase = movement; instant shocks | `attumen_mounted` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = max melee range; stop totem twist | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; stop melee | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = movement; save CDs | `alar_phoenix_active` | Icy Veins |
| TK | Void Reaver | ARCANE-ORB | Arcane Orb = move out; stop melee | `void_orb_nearby` | Wowhead |
| Black Temple | Supremus | KITE-PHASE | Volcano = move; ranged shocks only | `supremus_volcano_active` | Icy Veins |
| Black Temple | Shahraz | FATAL-ATTRACTION | Spread = stop melee; Judge from range | `fatal_attraction_active` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs, no conserve | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = stop and spread | `felmyst_gas_nova_casting` | Wowhead |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop and move | `kiljaeden_darkness_casting` | Icy Veins |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Shaman Enhancement | Melee group | Windfury Totem [25505] | 25505 | +AP proc = major DPS boost | Always active in melee group | Wago DB2 |
| Shaman Enhancement | Melee group | Grace of Air Totem [10627] | 10627 | +Agility = crit/AP | When no Windfury needed | Icy Veins |
| Shaman Enhancement | Melee group | Strength of Earth Totem [25528] | 25528 | +Strength = AP | Always active in melee group | Wowhead |
| Shaman Enhancement | Raid | Bloodlust [2825] | 2825 | +30% haste | Coordinate with melee CDs | Icy Veins |
| Paladin Retribution | Shaman Enhancement | Sanctity Aura [31869] | 31869 | +10% Holy damage for shocks | When in same group | Wowhead |
| Warrior Enhancement | Shaman Enhancement | Battle Shout [25289] | 25289 | +AP for Windfury scaling | When in same group | Icy Veins |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base damage | AP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Stormstrike [17364] | 2x weapon | 0 | 198 | 1.5 | 3.5 | 533 | >3s | Core strike |
| Windfury Attack [25505] | +AP proc | 0 | 0 | 0 | ∞ | 0 | Any | Totem-dependent |
| Earth Shock [25454] | 700 | 0.386 | 360 | 1.5 | 1.9 | 467 | >3s | Shock/filler |
| Lightning Shield [25472] | 300 | 0.10 | 0 | 0 | ∞ | 0 | Any | Passive damage |
| Bloodlust [2825] | +30% haste | N/A | 0 | 0 | +30% | +30% | Burst phase | 40s duration |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 20% | Stormstrike [17364] only; no shocks | Auto-attack + SS | Mana Tide Totem [16190] | `mana_pct`, `mana_tide_cd` |
| Mana < 10% | Auto-attack only | All spells forbidden | Potion, wait for external mana | `mana_pct`, `potion_cd` |
| Swing timer < 0.3s | Totem twist window closing | Hold twist, refresh next swing | None — wait for next swing | `mh_swing_timer` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Totem twist timing | Twist Windfury → Grace → Windfury on swing | Often twists at wrong timing | LIKELY BUG | Lost Windfury procs | Add swing timer >0.2s check | Warcraft Tavern |
| Weapon sync | Off-hand should sync with main-hand | Often unsynced after totem twist | LIKELY BUG | Reduced Windfury uptime | Add sync check after twist | Icy Veins |
| Stormstrike priority | SS is #1 on CD | Often delays SS for shock | LIKELY BUG | DPS loss | Prioritize SS > shock | Wowhead |
| Shock selection | Earth for single-target, Frost for slow | Often wrong shock for encounter | INTENTIONAL CHOICE | Suboptimal DPS | Add encounter-aware shock picker | Icy Veins |
| Lightning Shield uptime | Keep active with 3 charges | Often let expire | MISSING FEATURE | Lost passive damage | Add `shield_charges <= 1` refresh | Wowhead |

**Prioritized fix backlog:**
1. Totem twist timing — DPS critical
2. Weapon sync — Windfury uptime
3. Stormstrike priority — DPS impact
4. Lightning Shield uptime — passive damage

[NEW FINDING] Shaman Enhancement totem twist should gate on main-hand swing timer > 0.2s to avoid losing Windfury procs.
[DB2/WOWHEAD VETTED 2026-05-18] Grace of Air Totem [10627] is valid TBC rank 2 at level 56; max TBC rank is [25359] at level 60. Implement rank resolution over [8835/10627/25359], not a single hard-coded [10627].

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Shaman Enhancement research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
