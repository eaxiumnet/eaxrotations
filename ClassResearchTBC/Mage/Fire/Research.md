# Fire Mage Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Fire Mage, Wowhead Mage database/talents, Flux Mage research, Sonah Fire, SlyRotate Mage.

## Role

High-scaling caster DPS with raid support through Improved Scorch and strong cooldown burst. Threat and fire-immune targets are major constraints.

## Single Target

Priority:
1. Build and maintain 5 stacks of Improved Scorch if assigned.
2. Use Combustion in planned burn windows.
3. Fireball as main filler.
4. Fire Blast only when movement/filler is worth mana and threat.
5. Maintain mana with Mana Gem, Evocation, potion/rune.
6. Use Remove Lesser Curse as assigned.

## Multi Target

- Flamestrike for ground AoE if targets stay in place.
- Blast Wave/Cone of Cold if safe and talented/available.
- Arcane Explosion for close stacked targets.
- Blizzard for control or safer ranged AoE.

## PvP

- Burst with Fire Blast [2136, 2137, 2138, 8412, 8413, 10197, 10199, 27078, 27079], Presence of Mind [12043] if hybrid, Combustion [11129], and Dragon's Breath [31661, 33041, 33042, 33043] if talented; do not add Wrath+ Fire DoT mechanics.
- Polymorph, Counterspell, Blink, Frost Nova, Ice Block, Spellsteal define survival/control.

## Consumables, Gear, Sets

- Spell hit to cap, fire spell damage, crit, haste, intellect.
- Spellfire/Spellstrike-style gear is often important.
- Flask of Pure Death or elixir setup, Destruction Potion, mana tools.

## Automation Notes

- Track Improved Scorch stacks/remains, Combustion, mana, threat, Ignite/crit context only as passive.
- Sonah/SlyRotate both emphasize never dropping Scorch when assigned; add user toggle for assigned Scorch duty.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Crit-scaling caster built around Fireball, Scorch debuff support, Combustion windows, and Ignite value.

### Talent Builds and Variants

Ignite, Fire Power, Critical Mass, Combustion, Empowered Fireball, Molten Fury, Improved Scorch.

### Core Stats and Caps

Spell hit to cap, spell damage, spell crit, haste where available, intellect/spirit for sustain.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Blast Wave | 11113, 13018, 13019, 13020, 13021, 27133, 33933 | Fire | conditional |
| Combustion | 11129 | Fire | core |
| Counterspell | 2139 | Arcane | core |
| Dragon's Breath | 31661, 33041, 33042, 33043 | Fire | conditional |
| Fire Blast | 2136, 2137, 2138, 8412, 8413, 10197, 10199, 27078, 27079 | Fire | conditional |
| Fireball | 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306, 27070, 38692 | Fire | core |
| Flamestrike | 2120, 2121, 8422, 8423, 10215, 10216, 27086 | Fire | conditional |
| Polymorph | 118, 12824, 12825, 12826, 28271, 28272 | Arcane | core |
| Pyroblast | 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809, 27132, 33938 | Fire | conditional |
| Scorch | 2948, 8444, 8445, 8446, 10205, 10206, 10207, 27073, 27074 | Fire | core |

### Single-Target Priority

1. Maintain Improved Scorch if assigned and no other mage is covering it.
2. Cast Fireball as the default filler.
3. Use Fire Blast only for movement, finishers, or timing gaps.
4. Use Pyroblast as a pre-pull/opening cast if assigned and timing allows.
5. Use Combustion for stable uptime, not immediately before movement/immunity.
6. Respect Ignite threat during crit chains.

### Multi-Target and AoE Matrix

- 2 targets: Fireball priority target; Scorch only if debuff uptime matters.
- 3 targets: Flamestrike/Blast Wave if mobs are stable and CC is clear.
- 4+ targets: Flamestrike plus Blizzard-style control/AoE as assigned.
- Short-lived adds: Fire Blast/Scorch/Blast Wave depending on range.
- CC packs: avoid Blast Wave/Dragon's Breath splash near controlled targets.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Combustion with trinkets and Bloodlust/Heroism; avoid wasting it into fire immunity/resistance phases.

### Resource Management

Use mana gems/potions before OOM; Fire is less burst-mana intensive than Arcane but still must plan long fights.

### Threat Management

Ignite and Combustion burst require early threat checks; pause or use defensive threat tools before pulling.

### Utility, Interrupts, and Dispels

Counterspell, Spellsteal, Remove Curse, Polymorph, slows/roots, Dragon's Breath control if talented.

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
| Combustion [11129] before Ignite [12654] on target | Wasted crit stack | Ensure Ignite is active before using Combustion | `ignite_active`, `combustion_charges` | Wowhead |
| Scorch [27074] debuff drop | Lost +15% fire damage | Re-apply Scorch immediately; maintain 5-stack | `scorch_debuff_stacks`, `scorch_remains` | Icy Veins |
| Fireball [38697] pushback during cast | Lost cast time | Use Burning Soul [11108] talent; pre-shield with Ice Barrier | `pushback_count`, `burning_soul_rank` | Wowhead |
| Pyroblast [33938] on short-lived target | Wasted long cast | Use Fireball instead if TTD < 5s | `target_ttd`, `pyroblast_cast_time` | Icy Veins |
| Ignite [12654] munching (new ignite overwrites old) | Lost ignite damage | Track ignite tick; delay big crits until after tick | `ignite_tick_timer`, `next_crit_damage` | Wowhead |
| Mana floor < 20% | Cannot sustain Fireball spam | Switch to Scorch [27074] spam (cheaper) | `mana_pct`, `scorch_mana_cost` | Icy Veins |
| Dragon's Breath [31661] on immune target | Wasted GCD and CD | Check target disorient-immune before casting | `target_disorient_immune` | Wago DB2 |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Shade of Aran | BURST-WINDOW | Arcane Explosion = stop cast, pre-shield | `aran_casting_explosion` | Icy Veins |
| Karazhan | Curator | MANA-DRAIN | Evocation phase = heavy AoE; pop CDs | `curator_evocation` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = stop cast, max range | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; Scorch preferred | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = movement; instant spells | `alar_phoenix_active` | Icy Veins |
| Black Temple | Reliquary | SILENCE | Phase 2 silence = pre-shield, stop cast | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Mage Fire | Raid | Arcane Brilliance [27127] | 27127 | +Intellect party buff | Pre-pull | Wago DB2 |
| Mage Fire | Target | Ignite [12654] | 12654 | DoT debuff | Maintain with crits | Icy Veins |
| Mage Fire | Target | Scorch [27074] | 27074 | +15% fire damage debuff | Maintain 5-stack | Wowhead |
| Shaman Elemental | Mage Fire | Totem of Wrath [30706] | 30706 | +crit/spell hit | When in caster group | Wowhead |
| Priest Shadow | Mage Fire | Vampiric Touch [34914] | 34914 | Longer Fireball sustain | VT uptime > 80% | Icy Veins |
| Warlock Destruction | Mage Fire | Improved Shadow Bolt [17800] | 17800 | Debuff slot competition | Full debuff slots | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base dmg | SP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Fireball [38697] | 1200 | 1.0 | 465 | 3.0 | 2.6 | 400 | >5s | Primary nuke |
| Scorch [27074] | 300 | 0.42 | 180 | 1.5 | 1.7 | 200 | >3s | Debuff maintenance |
| Pyroblast [33938] | 1500 | 1.15 | 500 | 6.0 | 3.0 | 250 | >7s | Long cast bomb |
| Blast Wave [33043] | 600 | 0.19 | 410 | 1.5 | 1.5 | 400 | 3+ targets | AoE |
| Combustion [11129] | +crit per charge | N/A | 0 | 0 | +crit | +crit | Burst phase | 20 charges |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Scorch [27074] spam only; no Fireball | Mana Emerald [22044] | Evocation [12051] | `mana_pct`, `emerald_cd` |
| Mana < 15% | Scorch [27073] downrank | All max-rank forbidden | Potion, wait for VT mana | `mana_pct`, `potion_cd` |
| Mana < 5% | Wand only | All spells forbidden | Wait for external mana | `mana_pct` |

**Part C — Debuff Uptime Value**

| Debuff [ID] | Dmg 60s fight | Dmg 20s fight | Drop priority | Refresh early? | Notes |
|---|---|---|---|---|---|
| Ignite [12654] | ~1200 | ~400 | High | No, let tick | Core fire mechanic |
| Scorch [27074] | N/A (buff) | N/A | Critical | Refresh at < 3s | +15% fire damage |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Ignite munching prevention | Track ignite tick; delay big crits | Often overwrites ignite with big crits | LIKELY BUG | Lost ignite damage | Add `ignite_tick_timer` check | Wowhead |
| Scorch debuff maintenance | Maintain 5-stack at all times | Often drops to 2-3 stacks | LIKELY BUG | Lost +15% fire damage | Add `scorch_stacks < 5` refresh | Icy Veins |
| Combustion timing | Use after Ignite is active | Often used without Ignite | LIKELY BUG | Wasted crit stacks | Add `ignite_active` check | Wowhead |
| Fireball vs Scorch threshold | Fireball if mana > 30%, else Scorch | Often Fireball at 15% mana | LIKELY BUG | Mana starvation | Add `mana_pct > 30` gate | Icy Veins |
| Living Bomb attempt | Spell not in TBC | May attempt to cast | TBC GUARDRAIL VIOLATION | GCD waste | Remove from rotation | Wago DB2 |

**Prioritized fix backlog:**
1. Ignite munching prevention — DPS critical
2. Scorch debuff maintenance — +15% damage
3. Combustion timing — crit stack efficiency
4. Living Bomb removal — TBC compliance

[NEW FINDING] Mage Fire Ignite [12654] munching can be mitigated by tracking ignite tick timer and delaying large crits until after the tick.
[DB2 VETTED 2026-05-18] Living Bomb [44457] exists in SpellName but has no Mage class skillline entry in the local `wow_anniversary` DB2; do not implement it as a TBC Mage rotation spell.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Mage Fire research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
