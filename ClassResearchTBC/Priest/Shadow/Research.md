# Shadow Priest Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Shadow Priest, Wowhead Shadow Priest resources, Flux Priest research, Sonah Shadow, SlyRotate Priest.

## Role

Support DPS that returns mana through Vampiric Touch and boosts magic/shadow damage through debuffs. Shadow is valued for raid utility as much as personal damage.

## Single Target

Priority:
1. Maintain Vampiric Touch.
2. Maintain Shadow Word: Pain.
3. Maintain Shadow Weaving/Misery passively through Shadow spells.
4. Mind Blast on cooldown if threat/mana allow.
5. Shadow Word: Death when safe and valuable.
6. Mind Flay filler; clip only at sensible tick points for higher-priority spells.
7. Shadowfiend for mana return in planned windows.

## Multi Target

- Spread Shadow Word: Pain/Vampiric Touch only if targets live long enough and mana supports it.
- Do not add non-TBC Shadow AoE filler.
- Focus priority target when debuff/mana support is the raid need.

## PvP

- DoT pressure, Silence if talented, Psychic Scream, Dispel Magic, Vampiric Embrace sustain, Shadowform mitigation.
- Watch self-damage from Shadow Word: Death.

## Consumables, Gear, Sets

- Spell hit to cap, shadow damage, spell power, haste/crit, mana sustain.
- Frozen Shadoweave and Spellstrike-style gear are major references.
- Flask of Pure Death, Destruction Potion, Super Mana Potion/Dark Rune.

## Automation Notes

- Track VT/SWP durations, Mind Blast CD, SW:D safety, Mind Flay channel/tick state, threat, mana, Shadowfiend timing.
- Sonah has `vtRefreshThreshold`; SlyRotate tracks VT/SWP; Flux has fuller shadow strategy.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Mana-support DPS using Vampiric Touch, Shadow Word: Pain, Mind Blast, Mind Flay, Shadow Weaving, and threat-aware DoT uptime.

### Talent Builds and Variants

Vampiric Touch, Shadow Weaving, Darkness, Shadowform, Misery, Mind Flay, Shadow Power, Silence in PvP.

### Core Stats and Caps

Spell hit to cap, shadow damage, spell crit/haste where useful, intellect/spirit for sustain.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Devouring Plague | 2944, 19276, 19277, 19278, 19279, 19280, 25467 | Shadow Magic | conditional |
| Dispel Magic | 527, 988 | Discipline | utility |
| Mind Blast | 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947, 25372, 25375 | Shadow Magic | core |
| Mind Flay | 15407, 17311, 17312, 17313, 17314, 18807, 25387 | Shadow Magic | core |
| Shadow Word: Death | 32379, 32996 | Shadow Magic | core |
| Shadow Word: Pain | 589, 594, 970, 992, 2767, 10892, 10893, 10894, 25367, 25368 | Shadow Magic | core |
| Shadowfiend | 34433 | Shadow Magic | conditional |
| Silence | 15487 | Shadow Magic | utility |
| Vampiric Embrace | 15286 | Shadow Magic | conditional |
| Vampiric Touch | 34914, 34916, 34917, 34919 | Shadow Magic | core |

### Single-Target Priority

1. Keep Vampiric Touch active for mana return.
2. Keep Shadow Word: Pain active if it will tick long enough.
3. Use Mind Blast on cooldown unless threat or mana plan says hold.
4. Use Shadow Word: Death only when self-damage is safe and timing is valuable.
5. Channel Mind Flay as filler without clipping ticks unnecessarily.
6. Use Shadowfiend before OOM and while it can stay on target.

### Multi-Target and AoE Matrix

- 2 targets: DoT second target only if it lives long and threat is safe.
- 3 targets: maintain VT/SWP on priority long-lived targets; do not invent non-TBC Shadow AoE filler.
- 4+ targets: no modern Shadow AoE; use multidot only by encounter plan.
- Short-lived adds: Mind Blast/SW:D priority targets.
- CC packs: DoT spread can break control through damage or threat; avoid unless assigned.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Shadowfiend with uptime and mana need; trinkets with VT/SWP/Mind Blast burn windows.

### Resource Management

Shadow is valued for group mana; keep VT uptime even if personal DPS filler changes.

### Threat Management

Shadow threat can be high from sustained DoTs and VE healing; use Fade and throttle Mind Blast/SW:D.

### Utility, Interrupts, and Dispels

Dispel, disease removal, Shackle Undead, Silence/Psychic Scream in PvP, Vampiric Embrace healing if allowed.

### PvP Playstyle

Dispel wins games. Use shields, fears, Mana Burn, defensive dispels, offensive dispels, and LoS. Shadow pressures with DoTs and silence; healers survive through triage and control.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Priest/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Vampiric Touch [34914] expiry mid-cast | Lost mana return for raid | Re-cast immediately; never let VT drop | `vt_remains`, `vt_uptime` | Wowhead |
| Mind Blast [25311] threat spike | Pull aggro from tank | Use only when tank threat lead > 20%; queue SW:P instead | `tank_threat_lead`, `mb_threat` | Icy Veins |
| Shadowform [15473] dropped | Lost +15% shadow damage | Re-cast immediately; do not heal in Shadowform | `shadowform_active`, `heal_needed` | Wowhead |
| Silence [15487] on immune target | Wasted GCD | Check target silence-immune before casting | `target_silence_immune` | Wago DB2 |
| Dispersion [47585] DB2 absent | Wasted GCD | Do not use; spell not in TBC | `spell_known_dispersion` | Wago DB2 |
| Mana floor < 20% | Cannot sustain VT + SW:P | Life Tap not available; use wand | `mana_pct`, `vt_mana_cost` | Icy Veins |
| PvP: Psychic Scream [8122] on DR target | Wasted GCD | Check DR before fear; use Silence instead | `fear_dr` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Shade of Aran | BURST-WINDOW | Arcane Explosion = stop cast, pre-shield | `aran_casting_explosion` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = stop cast, max range | `gruul_shatter_timer` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant DoTs | `lurker_spout_active` | Icy Veins |
| TK | Al'ar | MOVEMENT | Phoenix adds = VT on adds | `alar_phoenix_active` | Wowhead |
| Black Temple | Reliquary | SILENCE | Phase 2 silence; pre-VT required | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Priest Shadow | Raid | Vampiric Touch [34914] | 34914 | Mana return for all DPS | Maintain on boss | Wago DB2 |
| Priest Shadow | Raid | Shadow Weaving [15258] | 15258 | +10% shadow damage | Maintain 5-stack | Icy Veins |
| Priest Shadow | Target | Mind Flay [18807] | 18807 | Slow + damage | When movement not needed | Wowhead |
| Priest Shadow | Raid | Prayer of Fortitude [25392] | 25392 | +Stamina | Pre-pull | Wago DB2 |
| Warlock Affliction | Priest Shadow | Shadow Embrace [32388] | 32388 | No direct interaction | N/A | Wowhead |
| Paladin Blessing | Priest Shadow | Blessing of Salvation [1038] | 1038 | -30% threat | Apply to Priest | Icy Veins |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base dmg | SP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Vampiric Touch [34914] | 700 | 1.0 | 425 | 1.5 | 1.6 | 467 | >15s | Mana return |
| Shadow Word: Pain [25368] | 1236 | 1.1 | 575 | 1.5 | 2.1 | 824 | >18s | Primary DoT |
| Mind Blast [25311] | 708 | 0.43 | 450 | 1.5 | 1.6 | 472 | >3s | Burst nuke |
| Mind Flay [18807] | 528 | 0.57 | 205 | 3.0 | 2.6 | 176 | >4s | Channeled |
| Shadowform [15473] | +15% shadow | N/A | 0 | 0 | +15% | +15% | Always | Form buff |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Shadow Word: Pain [25368] + wand only | Drop Mind Blast [25311] | Potion | `mana_pct`, `potion_cd` |
| Mana < 15% | Wand only | All spells forbidden | Potion, wait for VT mana return | `mana_pct`, `potion_cd` |
| Mana < 5% | Auto-attack only | All spells forbidden | Wait for external mana | `mana_pct` |
| VT uptime | VT drops | Re-cast immediately | None — maintain uptime | `vt_remains` |

**Part C — Debuff Uptime Value**

| Debuff [ID] | Dmg 60s fight | Dmg 20s fight | Drop priority | Refresh early? | Notes |
|---|---|---|---|---|---|
| Vampiric Touch [34914] | ~2100 | ~700 | Critical | No, clip <1.5s | Mana return |
| Shadow Word: Pain [25368] | ~3700 | ~1200 | High | No, clip <1.5s | Primary DoT |
| Shadow Weaving [15258] | N/A (buff) | N/A | High | Maintain 5-stack | +10% shadow |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| VT uptime | Maintain 100% uptime | Often let drop for Mind Blast | LIKELY BUG | Lost raid mana | Add `vt_remains < 3` refresh | Wowhead |
| Shadow Weaving maintenance | Maintain 5-stack | Often let drop to 2-3 | LIKELY BUG | Lost +10% shadow | Add `weaving_stacks < 5` refresh | Icy Veins |
| Mind Blast threat | Track tank threat lead | Often pulls aggro | LIKELY BUG | Death | Add `tank_threat_lead > 20%` gate | Wowhead |
| Dispersion attempt | Spell not in TBC | May attempt to cast | TBC GUARDRAIL VIOLATION | GCD waste | Remove from rotation | Wago DB2 |
| Shadowform healing | Never heal in Shadowform | Often shifts out to heal | INTENTIONAL CHOICE | Lost DPS time | Add `healer_present` check | Icy Veins |

**Prioritized fix backlog:**
1. VT uptime — raid mana critical
2. Shadow Weaving maintenance — shadow damage
3. Mind Blast threat — survival
4. Dispersion removal — TBC compliance

[NEW FINDING] Priest Shadow Vampiric Touch [34914] must maintain 100% uptime; never let drop for other spells.
[DB2 VETTED 2026-05-18] Dispersion [47585] is absent from `wow_anniversary` SpellName and class skillline DB2; do not implement it for TBC Shadow.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Priest Shadow research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
