# Smite Priest Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Wowhead/Icy Veins Priest baseline pages, Flux Priest Smite research, local Priest modules. Smite is off-meta and needs extra verification.

## Role

Off-meta Holy/Discipline caster DPS. It can be fun and serviceable in permissive groups, but it generally does not replace Shadow Priest raid utility or pure caster DPS output.

## Single Target

Priority:
1. Maintain Holy Fire if target lives long enough.
2. Smite filler.
3. Shadow Word: Pain only if build/mana/debuff slots justify it.
4. Inner Focus before expensive or high-value cast.
5. Power Infusion if talented and assigned to self or another caster by policy.
6. Shadowfiend and mana tools for sustain.

## Multi Target

- Holy Nova is expensive and positional.
- Multi-target DPS is weak; focus priority target unless farming trivial mobs.

## PvP

- Smite burst can surprise targets with Power Infusion/Inner Focus, but Discipline-style healing/control usually has more value.
- Use Psychic Scream, Dispel Magic, shields, and heals defensively.

## Consumables, Gear, Sets

- Spell hit, holy/spell damage, intellect, crit, mana sustain.
- Flask of Blinding Light can apply to Holy damage; verify against exact consumable rules.
- Tailoring caster gear may help, but Shadow-specific Frozen Shadoweave does not buff Holy damage.

## Automation Notes

- Keep Smite as its own spec document and optional plugin behavior.
- Track Holy Fire DoT, Smite cast state, mana, Inner Focus, Power Infusion policy, target time-to-die.
- Flux is the strongest local reference for this branch.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Holy damage build using Holy Fire, Smite, Surge of Light/Holy talents, and priest utility while accepting lower meta DPS.

### Talent Builds and Variants

Searing Light, Spiritual Guidance, Surge of Light, Holy Specialization, Divine Fury, Power Infusion if hybrid Discipline/Holy.

### Core Stats and Caps

Spell hit to cap, spell damage, spell crit, intellect/spirit for sustain.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Abolish Disease | 552 | Holy | conditional |
| Dispel Magic | 527, 988 | Discipline | utility |
| Flash Heal | 2061, 9472, 9473, 9474, 10915, 10916, 10917, 25233, 25235 | Holy | core |
| Holy Fire | 14914, 15261, 15262, 15263, 15264, 15265, 15266, 15267, 25384 | Holy | conditional |
| Holy Nova | 15237, 15430, 15431, 23455, 23458, 23459, 25329, 25331, 27799, 27800, 27801, 27803, 27804, 27805 | Holy | conditional |
| Inner Focus | 14751 | Discipline | conditional |
| Power Infusion | 10060 | Discipline | conditional |
| Power Word: Shield | 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218 | Discipline | core |
| Shadow Word: Pain | 589, 594, 970, 992, 2767, 10892, 10893, 10894, 25367, 25368 | Shadow Magic | core |
| Smite | 585, 591, 598, 984, 1004, 6060, 10933, 10934, 25363, 25364 | Holy | conditional |

### Single-Target Priority

1. Open with Holy Fire if the DoT will tick.
2. Cast Smite as primary filler.
3. Use Shadow Word: Pain only if the damage/mana trade is positive and debuff slots allow.
4. Use Inner Focus/Power Infusion around burst casts if available.
5. Stop DPS to dispel or emergency heal when assigned.
6. Do not use Chakra or later Holy DPS mechanics.

### Multi-Target and AoE Matrix

- 2 targets: continue single-target priority unless both live long enough for SW:P.
- 3 targets: Holy Nova only if stacked and safe; damage is limited.
- 4+ targets: Holy Nova is mana-heavy and positioning-limited.
- Short-lived adds: Smite/Holy Fire priority targets.
- CC packs: Holy Nova can break nearby control.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Power Infusion/Inner Focus for burst or mana; trinkets with Holy Fire/Smite windows.

### Resource Management

Mana is the main limiter; downshift to healing/utility if DPS value is low.

### Threat Management

Holy damage plus off-healing can create mixed threat on adds; Fade proactively.

### Utility, Interrupts, and Dispels

Full Priest dispel toolkit, emergency heals, shields, Shackle Undead, Psychic Scream.

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
| Smite [25363] cast pushback | Lost cast time | Use Burning Soul [11108] talent; pre-shield | `pushback_count`, `burning_soul_rank` | Wowhead |
| Holy Fire [25384] on fire-immune target | Wasted GCD and CD | Check target fire immunity before casting | `target_fire_immune` | Icy Veins |
| Penance [47540] DB2 absent | Wasted GCD | Do not use; spell not in TBC | `spell_known_penance` | Wago DB2 |
| Mana floor < 20% | Cannot sustain Smite spam | Switch to lower-rank Smite [25362] | `mana_pct`, `smite_rank` | Icy Veins |
| Holy Nova [25331] on single target | Wasted mana | Use only when 3+ targets within 10y | `target_count` | Wowhead |
| Inner Fire [25431] expiry | Lost +spell damage | Re-cast before expiry; track charges | `inner_fire_charges`, `inner_fire_remains` | Icy Veins |
| PvP: Holy Fire [25384] on moving target | Missed cast | Lead target or use instant Smite instead | `target_moving` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Shade of Aran | BURST-WINDOW | Arcane Explosion = stop cast, pre-shield | `aran_casting_explosion` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = stop cast, max range | `gruul_shatter_timer` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant spells | `lurker_spout_active` | Icy Veins |
| TK | Al'ar | MOVEMENT | Phoenix adds = movement; Holy Nova value | `alar_phoenix_active` | Wowhead |
| Black Temple | Reliquary | SILENCE | Phase 2 silence; pre-shield, stop cast | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Priest Smite | Raid | Prayer of Fortitude [25392] | 25392 | +Stamina | Pre-pull | Wago DB2 |
| Priest Smite | Target | Holy Fire [25384] | 25384 | Fire DoT debuff | Maintain on boss | Icy Veins |
| Priest Smite | Target | Shadow Word: Pain [25368] | 25368 | Shadow DoT | Maintain on boss (if no Shadow Priest) | Wowhead |
| Mage Fire | Priest Smite | Scorch [27074] | 27074 | Fire damage debuff; no direct interaction | N/A | Wowhead |
| Paladin Blessing | Priest Smite | Blessing of Wisdom [27142] | 27142 | +mana regen | When in same group | Icy Veins |
| Shaman Elemental | Priest Smite | Totem of Wrath [30706] | 30706 | +crit/spell hit | When in caster group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base dmg | SP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Smite [25363] | 600 | 0.714 | 340 | 2.5 | 1.8 | 240 | >4s | Primary nuke |
| Holy Fire [25384] | 700 | 0.57 | 295 | 2.0 | 2.4 | 350 | >4s | Fire DoT setup |
| Holy Nova [25331] | 400 | 0.20 | 620 | 1.5 | 0.6 | 267 | 3+ targets | AoE |
| Penance [47540] DB2 absent | N/A | N/A | N/A | N/A | N/A | N/A | N/A | WotLK-only mechanic for this project |
| Inner Fire [25431] | +120 spell dmg | N/A | 0 | 0 | +dmg | +dmg | Always | Self buff |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Smite [25362] downrank | Mana potion | Potion | `mana_pct`, `potion_cd` |
| Mana < 15% | Holy Fire [25383] only | All max-rank forbidden | Potion, wait for external mana | `mana_pct`, `potion_cd` |
| Mana < 5% | Wand only | All spells forbidden | Wait for external mana | `mana_pct` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Holy Fire timing | Use on cooldown | Often delayed for Smite spam | INTENTIONAL CHOICE | Suboptimal DPS | Add `holy_fire_cd == 0` priority | Icy Veins |
| Holy Nova target count | Only when 3+ targets | Often used on single target | LIKELY BUG | Mana waste | Add `target_count >= 3` check | Wowhead |
| Penance attempt | Spell not in TBC | May attempt to cast | TBC GUARDRAIL VIOLATION | GCD waste | Remove from rotation | Wago DB2 |
| Inner Fire uptime | Keep active always | Often let expire | MISSING FEATURE | Lost spell damage | Add `remains < 5` refresh | Icy Veins |
| Smite pushback | Use Burning Soul talent | Often takes full pushback | LIKELY BUG | Lost cast time | Verify Burning Soul talent rank | Wowhead |

**Prioritized fix backlog:**
1. Penance removal — TBC compliance
2. Inner Fire uptime — spell damage
3. Holy Nova target count — mana efficiency
4. Holy Fire priority — DPS optimization

[NEW FINDING] Priest Smite must maintain Inner Fire [25431] uptime; re-cast when < 5s remains to avoid spell damage loss.
[DB2 VETTED 2026-05-18] Penance [47540] is absent from `wow_anniversary` SpellName and class skillline DB2; do not implement it for TBC Smite.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Priest Smite research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
