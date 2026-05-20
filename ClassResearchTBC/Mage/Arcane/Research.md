# Arcane Mage Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Arcane Mage, Wowhead Mage database/talents, Flux Mage research, Sonah Arcane, SlyRotate Mage.

## Role

Burst caster DPS with high mana volatility. Arcane turns mana into damage through Arcane Blast stacks and cooldown windows.

## Single Target

Priority:
1. Pre-buff Arcane Intellect/Brilliance, Mage Armor or Molten Armor based on mana/threat plan.
2. Use Arcane Power, Presence of Mind, trinkets in burn windows.
3. Build Arcane Blast stacks during burn.
4. Dump or conserve with Arcane Missiles/Frostbolt/Fireball depending on build and mana plan.
5. Evocation, Mana Gem, potion/rune before going OOM.
6. Manage threat aggressively; Arcane burst can pull.

## Multi Target

- Arcane Explosion for close stacked targets if safe.
- Flamestrike/Blizzard may be better depending on spec hybrid and target count.
- Mana cost and threat often limit Arcane AoE.

## PvP

- Burst through Presence of Mind/Arcane Power windows.
- Polymorph, Counterspell, Blink, Frost Nova, Ice Block, Spellsteal, and Mana Shield are central.
- Avoid long turret burns without control.

## Consumables, Gear, Sets

- Spell hit to cap, spell damage, intellect, spell crit/haste, mana sustain.
- Tailoring caster sets and Spellstrike are key references.
- Flask of Blinding Light, Destruction Potion, Super Mana Potion/Mana Gem.

## Automation Notes

- Track Arcane Blast stacks/remains, mana forecast, Evocation CD, Mana Gem, Arcane Power, Presence of Mind, threat, movement.
- SlyRotate mana forecast and Flux burn/conserve notes are useful.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Mana-conversion caster that alternates Arcane Blast burn stacks with conserve phases, using cooldowns for planned burst.

### Talent Builds and Variants

Arcane Power, Mind Mastery, Arcane Instability, Presence of Mind, Arcane Concentration, Spell Power.

### Core Stats and Caps

Spell hit to cap, spell damage, intellect, spell crit, spirit/mp5 for longevity, haste where available.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Arcane Blast | 30451 | Arcane | core |
| Arcane Missiles | 5143, 5144, 5145, 7269, 7270, 8416, 8417, 8418, 8419, 10211, 10212, 10273, 10274, 25345, 25346, 27075, 27076, 38699, 38700, 38703, 38704 | Arcane | conditional |
| Arcane Power | 12042 | Arcane | conditional |
| Counterspell | 2139 | Arcane | core |
| Evocation | 12051 | Arcane | core |
| Fireball | 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306, 27070, 38692 | Fire | core |
| Frostbolt | 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304, 27071, 27072, 38697 | Frost | core |
| Polymorph | 118, 12824, 12825, 12826, 28271, 28272 | Arcane | core |
| Presence of Mind | 12043 | Arcane | conditional |
| Spellsteal | 30449 | Arcane | pvp |

### Single-Target Priority

1. Enter burn with mana/cooldowns planned.
2. Cast Arcane Blast during burn stacks while mana and threat allow.
3. Drop to a conserve filler when Arcane Blast cost becomes unsustainable.
4. Use Arcane Missiles only when clearcasting/proc/timing makes it efficient.
5. Use Evocation early enough to complete the channel safely.
6. Use Presence of Mind for movement, burst, or assigned utility.

### Multi-Target and AoE Matrix

- 2 targets: focus priority; do not DoT-spread because Arcane has no real cleave cycle.
- 3 targets: Blizzard/Arcane Explosion only if tank control and range allow.
- 4+ targets: Blizzard for ranged AoE; Arcane Explosion only when safe in melee.
- Short-lived adds: instant Arcane Explosion/Cone-style tools if positioning allows.
- CC packs: Polymorph duties outrank AoE.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Stack Arcane Power, trinkets, Presence of Mind, and Bloodlust/Heroism for planned burn; avoid burning into threat cap.

### Resource Management

Arcane is mana-limited; choose burn/conserve state from remaining fight time, potion/gem/Evocation availability, and raid mana support.

### Threat Management

Arcane burst can exceed tank threat; use Invisibility only if present in target game version, otherwise throttle and use threat-reduction talents/items.

### Utility, Interrupts, and Dispels

Counterspell, Spellsteal, Remove Curse, Polymorph, slows/roots, portals/food outside rotation.

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
| Arcane Blast [30451] stack drop during latency | Lost stack damage | Rebuild stack immediately; use Arcane Missiles [38699] if movement | `ab_stack_count`, `latency_ms` | Wowhead |
| Clearcast [16870] mid-GCD | Proc wasted | Track clearcast buffer; consume on next Arcane Blast | `clearcast_active`, `gcd_remains` | Wago DB2 |
| Evocation [12051] interrupt | Lost mana recovery | Restart evocation; use Mana Emerald [22044] if interrupt persists | `evocation_channeled`, `mana_emerald_cd` | Icy Veins |
| Presence of Mind [12043] on cooldown spell | Wasted instant | Check spell CD before PoM; use on Arcane Blast only | `pom_active`, `spell_cd` | Wowhead |
| Mana floor < 20% | Cannot sustain AB spam | Switch to Arcane Missiles [38699] or Frostbolt [38697] | `mana_pct`, `ab_mana_cost` | Icy Veins |
| Arcane Power [12042] during heroism | Haste cap overlap | Delay AP until heroism ends | `heroism_active`, `ap_cd` | Wowhead |
| PvP: Counterspell on Arcane school | Locked out of all spells | Pre-cast Presence of Mind; use Ice Barrier [33405] | `counterspell_school`, `pom_cd` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Shade of Aran | BURST-WINDOW | Arcane Explosion = stop cast, pre-shield | `aran_casting_explosion` | Icy Veins |
| Karazhan | Curator | MANA-DRAIN | Evocation phase = heavy AoE; pop CDs | `curator_evocation` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = stop cast, max range | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; Arcane Missiles preferred | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = movement; instant spells | `alar_phoenix_active` | Icy Veins |
| Black Temple | Reliquary | SILENCE | Phase 2 silence = pre-shield, stop cast | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Mage Arcane | Raid | Arcane Intellect [27126] | 27126 | +Intellect | Apply to all casters | Wago DB2 |
| Mage Arcane | Caster group | Arcane Brilliance [27127] | 27127 | +Intellect party buff | Pre-pull | Icy Veins |
| Mage Arcane | Caster group | Focus Magic [54646] DB2 absent | N/A | N/A | N/A | Wago DB2 |
| Shaman Elemental | Mage Arcane | Totem of Wrath [30706] | 30706 | +crit/spell hit | When in caster group | Wowhead |
| Priest Shadow | Mage Arcane | Vampiric Touch [34914] | 34914 | Longer AB sustain | VT uptime > 80% | Icy Veins |
| Paladin Blessing | Mage Arcane | Blessing of Kings [20217] | 20217 | +stats = more mana | When in same group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base dmg | SP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Arcane Blast [30451] | 800 | 0.714 | 195 | 2.5 | 4.1 | 320 | >4s | Stack-dependent |
| Arcane Missiles [38699] | 1200 | 1.0 | 655 | 5.0 | 1.8 | 240 | >6s | Channeled |
| Arcane Explosion [30482] | 400 | 0.21 | 390 | 1.5 | 1.0 | 267 | 3+ targets | AoE |
| Presence of Mind [12043] | Instant AB | N/A | 0 | 0 | ∞ | ∞ | Any | Instant cast |
| Arcane Power [12042] | +30% damage | N/A | 0 | 0 | +30% | +30% | Burst phase | 15s duration |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Arcane Missiles [38699] only; no AB stacking | Mana Emerald [22044] | Evocation [12051] | `mana_pct`, `emerald_cd` |
| Mana < 15% | Frostbolt [38697] only (no AB mana) | All AB forbidden | Potion, wait for VT mana | `mana_pct`, `potion_cd` |
| Mana < 5% | Wand/auto-attack only | All spells forbidden | Wait for external mana | `mana_pct` |
| AB stack | Stack drop during movement | Rebuild from 0 or use Missiles | None — wait for standstill | `ab_stack_count` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| AB stack maintenance | Keep 3-stack; refresh with AB or Missiles | Often drops stack during movement | LIKELY BUG | DPS loss | Add `movement → Missiles` fallback | Wowhead |
| Clearcast consumption | Use on AB (highest mana cost) | Often burns on Missiles or Explosion | LIKELY BUG | Mana inefficiency | Add `clearcast → AB` priority | Icy Veins |
| Evocation timing | Use at 20% mana, not on cooldown | Often used at 40% or on CD | INTENTIONAL CHOICE | Suboptimal mana curve | Add `mana_pct <= 20` gate | Wowhead |
| Arcane Power timing | Use with trinkets + heroism | Often used without CDs | MISSING FEATURE | Suboptimal burst | Add `trinket_ready` condition | Icy Veins |
| Focus Magic attempt | Spell not in TBC | May attempt to cast | TBC GUARDRAIL VIOLATION | GCD waste | Remove from rotation | Wago DB2 |

**Prioritized fix backlog:**
1. AB stack maintenance during movement — DPS critical
2. Clearcast consumption priority — mana efficiency
3. Arcane Power coordination — burst optimization
4. Focus Magic removal — TBC compliance

[NEW FINDING] Mage Arcane should maintain 3-stack Arcane Blast [30451] and fallback to Arcane Missiles [38699] during movement to prevent stack drops.
[DB2 VETTED 2026-05-18] Focus Magic [54646] is absent from `wow_anniversary` SpellName and class skillline DB2; do not implement it for TBC Arcane.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Mage Arcane research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
