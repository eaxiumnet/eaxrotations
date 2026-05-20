# Elemental Shaman Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Elemental Shaman, Wowhead Shaman overview, Flux Shaman research, Sonah Elemental, SlyRotate Shaman.

## Role

Caster DPS and caster-party support through Totem of Wrath, Wrath of Air, Bloodlust/Heroism, and strong burst. Movement and mana are major constraints.

## Single Target

Priority:
1. Maintain appropriate totems: Totem of Wrath, Wrath of Air, Mana Spring, Strength/Stoneskin as assigned.
2. Elemental Mastery for guaranteed crit burst, paired with trinkets when planned.
3. Maintain Flame Shock if using shock weaving and target lives long enough.
4. Chain Lightning by selected mode: on cooldown for DPS, on clearcast/conserve for mana, or fixed Lightning Bolt ratio.
5. Earth Shock as filler only when not needed soon for interrupt and mana allows.
6. Lightning Bolt filler.

## Multi Target

- Chain Lightning gains value.
- Fire Nova Totem for burst AoE after fuse.
- Magma Totem for sustained stacked AoE.
- Earth Shock should be reserved for interrupt if needed.

## PvP

- Earth Shock interrupt, Grounding Totem, Tremor Totem, Purge, Frost Shock kiting, Elemental Mastery burst.
- Totem choice changes rapidly by matchup.

## Consumables, Gear, Sets

- Spell hit, spell damage, spell crit, haste, intellect/MP5.
- Flask of Blinding Light for nature damage, Destruction Potion, Super Mana Potion/Dark Rune.
- Totem slot relics and tier bonuses can affect LB/CL priority; verify.

## Automation Notes

- Track totem state, Flame Shock, shock shared cooldown, Chain Lightning CD, Elemental Focus/Clearcasting, Elemental Mastery, mana tier, interrupt reserve.
- Flux has the best rotation-mode breakdown; Sonah gives practical Flame Shock refresh and PvP utility cues.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Caster support DPS using Lightning Bolt, Chain Lightning, shocks, Totem of Wrath, Bloodlust/Heroism, and totem utility.

### Talent Builds and Variants

Totem of Wrath, Elemental Mastery, Lightning Mastery, Elemental Fury, Unrelenting Storm, Elemental Precision.

### Core Stats and Caps

Spell hit to cap, spell damage, spell crit, intellect/mp5 for sustain, haste where available.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Bloodlust | 2825 | Enhancement | core |
| Chain Lightning | 421, 930, 2860, 10605, 25439, 25442, 45297, 45298, 45299, 45300, 45301, 45302 | Elemental Combat | core |
| Earth Shock | 8042, 8044, 8045, 8046, 10412, 10413, 10414, 25454 | Elemental Combat | core |
| Elemental Mastery | 16166 | Elemental Combat | conditional |
| Flame Shock | 8050, 8052, 8053, 10447, 10448, 25457, 29228 | Elemental Combat | conditional |
| Heroism | 32182 | Enhancement | core |
| Lightning Bolt | 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208, 25448, 25449, 45284, 45286, 45287, 45288, 45289, 45290, 45291, 45292, 45293, 45294, 45295, 45296 | Elemental Combat | core |
| Purge | 370, 8012 | Elemental Combat | pvp |
| Totem of Wrath | 30706, 30708 | Elemental Combat | core |

### Single-Target Priority

1. Keep Totem of Wrath active unless another fire totem is assigned.
2. Cast Lightning Bolt as default filler.
3. Use Chain Lightning on cooldown only if mana/threat permit and it will not break CC.
4. Use Flame Shock/Earth Shock based on movement, debuff slots, and mana.
5. Use Elemental Mastery with Chain Lightning or Lightning Bolt by burst plan.
6. Use Bloodlust/Heroism by raid assignment.

### Multi-Target and AoE Matrix

- 2 targets: Chain Lightning gains value if no CC risk.
- 3 targets: Chain Lightning on cooldown if mana/threat safe.
- 4+ targets: Fire Nova/Magma totem only if positioning and threat are safe; otherwise Chain Lightning priority.
- Short-lived adds: Chain Lightning/Earth Shock priority add.
- CC packs: Chain Lightning can break control; disable it near CC.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Elemental Mastery, trinkets, and Bloodlust/Heroism align with burn phases.

### Resource Management

Elemental can go OOM using Chain Lightning/shocks aggressively; use mana potions and lower shock frequency if fight is long.

### Threat Management

Chain Lightning crits can spike; hold it on weak tank lead.

### Utility, Interrupts, and Dispels

Purge, interrupts with Earth Shock, Tremor/Grounding/Cleansing totems, Bloodlust/Heroism, off-healing.

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
| Lightning Overload [30675] mid-cast | Double-cast collision with queued spell | Finish current cast; queue next after GCD clears | `lightning_overload_proc`, `cast_in_progress` | Wowhead |
| Clearcast [16870] mid-GCD | Proc wasted on already-free spell | Track clearcast buffer; consume on next Lightning Bolt | `clearcast_active`, `gcd_remains` | Wago DB2 |
| Totem range > 30y | Melee out of Windfury range | Pre-position totems on pull; move totems if group shifts | `totem_distance`, `group_positions` | Icy Veins |
| Flame Shock [25457] expiry mid-cast | Lost DoT uptime | Refresh Flame Shock before expiry; never clip | `flame_shock_remains`, `cast_remains` | Wowhead |
| Earth Shock [25454] on immune target | Wasted GCD and shock CD | Check target school immunity before shock | `target_immune_school` | Wago DB2 |
| Mana floor < 20% | Cannot sustain Lightning Bolt [25449] spam | Switch to lower-rank Lightning Bolt; use Mana Tide [16190] | `mana_pct`, `mana_tide_cd` | Icy Veins |
| PvP: Grounding Totem [8177] on CD | No spell absorption | Pre-place Tremor Totem [8143] for CC; kite until Grounding back | `grounding_totem_cd`, `cc_incoming` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Shade of Aran | BURST-WINDOW | Arcane Explosion = stop cast, pre-shield | `aran_casting_explosion` | Icy Veins |
| Gruul | Gruul | MOVEMENT | Shatter = position; stop casting | `gruul_shatter_timer` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; save CDs | `lurker_spout_active` | Icy Veins |
| SSC | Leotheras | TANK-SWAP | Demon phase = threat wipe; hold burst | `leotheras_phase == demon` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = movement; instant shocks preferred | `alar_phoenix_active` | Icy Veins |
| TK | Void Reaver | ARCANE-ORB | Arcane Orb = move out; stop cast | `void_orb_nearby` | Wowhead |
| Black Temple | Reliquary | SILENCE | Phase 2 silence = pre-shield, stop cast | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected player stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Shaman Elemental | Raid | Totem of Wrath [30706] | 30706 | +3% crit/spell hit | Always active in caster group | Wago DB2 |
| Shaman Elemental | Caster group | Wrath of Air Totem [3738] | 3738 | +5% spell haste | When in caster group | Icy Veins |
| Shaman Elemental | Melee group | Windfury Totem [25505] | 25505 | +AP proc | When in melee group | Wowhead |
| Shaman Elemental | Raid | Bloodlust [2825] | 2825 | +30% haste for 40s | Coordinate with caster CDs | Icy Veins |
| Priest Shadow | Shaman Elemental | Vampiric Touch [34914] | 34914 | Longer sustain, less potion use | VT uptime > 80% | Wowhead |
| Mage Fire | Shaman Elemental | Ignite [12654] | 12654 | Debuff slot competition; Ignite > Flame Shock priority | Full debuff slots | Icy Veins |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base dmg | SP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Lightning Bolt [25449] | 600 | 0.794 | 330 | 2.0 | 1.8 | 300 | >4s | Primary nuke |
| Chain Lightning [25442] | 800 | 0.714 | 440 | 2.0 | 1.8 | 400 | >4s, 3+ targets | AoE nuke |
| Flame Shock [25457] | 500 | 0.10 | 500 | 1.5 | 1.0 | 333 | >12s | DoT maintenance |
| Earth Shock [25454] | 700 | 0.386 | 360 | 1.5 | 1.9 | 467 | >3s | Interrupt/shock |
| Bloodlust [2825] | +30% haste | N/A | 0 | 0 | +30% | +30% | Burst phase | 40s duration |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Switch to lower-rank Lightning Bolt [25448] | Mana Tide Totem [16190] | Potion | `mana_pct`, `mana_tide_cd` |
| Mana < 15% | Flame Shock [25457] only; no Chain Lightning | All other spells forbidden | Potion, wait for VT mana | `mana_pct`, `potion_cd` |
| Mana < 5% | Auto-attack only | All spells forbidden | Wait for external mana | `mana_pct` |

**Part C — Debuff Uptime Value**

| Debuff [ID] | Dmg 60s fight | Dmg 20s fight | Drop priority | Refresh early? | Notes |
|---|---|---|---|---|---|
| Flame Shock [25457] | ~800 | ~300 | Low | No, clip only if <1s | Maintains DoT slot |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Lightning Bolt rank | Use max rank unless mana < 30% | Always max rank | INTENTIONAL CHOICE | Mana inefficiency | Add `mana_pct` rank gate | Icy Veins |
| Flame Shock refresh | Refresh at < 1s remaining | Often refreshed early (>3s) | LIKELY BUG | Wasted GCDs | Add `remains < 1.0` check | Wowhead |
| Totem range | Pre-place totems at 20-25y from boss | Often placed at max range | MISSING FEATURE | Melee out of range | Add `group_position` check | Icy Veins |
| Chain Lightning targets | Only CL when 3+ targets within jump range | Often single-target CL | LIKELY BUG | Mana waste | Add `target_count >= 3` check | Wowhead |
| Bloodlust timing | Coordinate with trinkets/heroism | Often used on pull without CDs | INTENTIONAL CHOICE | Suboptimal burst | Add `trinket_ready` condition | Icy Veins |

**Prioritized fix backlog:**
1. Flame Shock refresh timing — GCD efficiency
2. Chain Lightning target count — mana efficiency
3. Totem range check — melee sustain
4. Bloodlust coordination — burst optimization

[NEW FINDING] Shaman Elemental Flame Shock should refresh only when < 1s remains, not earlier, to avoid GCD waste.
[DB2/WOWHEAD VETTED 2026-05-18] Chain Lightning [25442] is an Elemental Combat spell; DB2 confirms EffectChainTargets=3 and EffectChainAmplitude=0.70, and Wowhead confirms 3 total targets with each jump dealing 30% less damage. Exact jump radius is not exposed in local DB2, so keep any pre-cast cluster-radius heuristic configurable.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Shaman Elemental research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
