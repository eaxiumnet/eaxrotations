# Beast Mastery Hunter Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Beast Mastery Hunter, Wowhead Hunter DPS rotation, Flux Hunter research, Sonah BM, SlyRotate Hunter.

## Role

Top sustained ranged DPS with heavy pet contribution. BM gameplay is a shot-weaving rhythm around Auto Shot and Steady Shot, while keeping pet uptime and cooldowns aligned.

## Single Target

Priority:
1. Hunter's Mark if assigned and target lives long enough.
2. Keep pet attacking and in range.
3. Bestial Wrath during burst windows or on cooldown for long fights.
4. Kill Command when available after pet crit conditions.
5. Rapid Fire and trinkets in planned burn windows.
6. Steady Shot woven between Auto Shots without clipping.
7. Multi-Shot/Arcane Shot only when timing does not clip Auto Shot and mana allows.
8. Aspect of the Viper when mana requires recovery; swap back to Hawk when safe.

## Multi Target

- Multi-Shot when it will not break CC and will not clip Auto Shot badly.
- Explosive Trap when safe to move into melee range.
- Volley only for enough stacked targets and sufficient mana.
- Pet cleave abilities contribute passively where available.

## PvP

- Pet pressure, Bestial Wrath immunity window, Intimidation, traps, Scatter Shot if available from hybrid talents, Viper Sting, and kiting matter more than perfect PvE weaving.
- Maintain range; do not tunnel Steady Shot when movement/control is needed.

## Consumables, Gear, Sets

- Agility, attack power, hit to cap, crit, haste where valuable.
- Flask of Relentless Assault, Haste Potion, agility/attack power food, weapon scopes/ammo.
- Pet food/happiness and pet survival are throughput mechanics.

## Automation Notes

- Must have ranged swing timer and "safe cast Steady" check.
- Track Auto Shot time remaining, Steady cast time, Multi-Shot CD, Kill Command availability, pet state, mana thresholds, aspect state.
- Flux clip tracker is the strongest local reference; Sonah and SlyRotate provide simple aspect and shot priority defaults.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Pet-forward ranged DPS built around Auto Shot/Steady Shot timing, Kill Command, Bestial Wrath, and pet uptime.

### Talent Builds and Variants

Bestial Wrath, Serpent's Swiftness, Ferocious Inspiration, Animal Handler, Go for the Throat, Frenzy.

### Core Stats and Caps

Hit to cap, agility, attack power, crit, haste where available, intellect only as a mana comfort stat.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Arcane Shot | 3044, 14281, 14282, 14283, 14284, 14285, 14286, 14287, 27019 | Marksmanship | core |
| Auto Shot | 75 | Marksmanship | conditional |
| Bestial Wrath | 19574, 24395, 24396, 24397 | Beast Mastery | core |
| Feign Death | 5384 | Survival | core |
| Hunter's Mark | 1130, 14323, 14324, 14325 | Marksmanship | core |
| Kill Command | 34026 | Beast Mastery | core |
| Misdirection | 34477 | Survival | core |
| Multi-Shot | 2643, 14288, 14289, 14290, 25294, 27021 | Marksmanship | core |
| Serpent Sting | 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295, 27016 | Marksmanship | conditional |
| Steady Shot | 34120 | Marksmanship | core |

### Single-Target Priority

1. Apply Hunter's Mark when assigned.
2. Keep pet attacking and alive; pet uptime is DPS.
3. Use Steady Shot without clipping Auto Shot.
4. Use Kill Command after crit events when available.
5. Use Multi-Shot/Arcane Shot only when they do not clip Auto Shot and mana supports it.
6. Use Serpent Sting only if fight length, debuff slots, and mana make it worthwhile.

### Multi-Target and AoE Matrix

- 2 targets: Multi-Shot when it will not break CC and will not clip Auto Shot.
- 3 targets: Multi-Shot gains value; maintain pet on the kill target.
- 4+ targets: Volley only for sustained packs with stable tank threat.
- Short-lived adds: Misdirection tank, pet attack priority add, then Multi-Shot if safe.
- CC packs: disable cleave/multi rules near sheep/trap/sap.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Stack Bestial Wrath, trinkets, Rapid Fire, and Bloodlust/Heroism where possible without wasting pet uptime.

### Resource Management

Use Aspect of the Viper only if mana failure would occur; otherwise Hawk is the default damage aspect.

### Threat Management

Use Misdirection proactively and Feign Death before threat cap, not after pulling.

### Utility, Interrupts, and Dispels

Traps, Misdirection, Tranq Shot when required, pet offtank/distraction, Viper Sting in PvP, flare/scare beast utility.

### PvP Playstyle

Win through range control, trap chains, pet pressure, Viper Sting, Scatter/Wyvern where talented, flare, and kiting. Do not let melee sit in dead-zone style pressure.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Hunter/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Bestial Wrath [19574] + Rapid Fire [3045] overlap | Wasted haste synergy | Stagger by 5s: BW first, RF at ~20s mark | `bw_remains`, `rf_cd` | Wowhead |
| Pet aggro on wrong target | Pet dies or pulls extra | Set pet to passive, retarget with /petattack | `pet_target`, `pet_aggro` | Common |
| Intimidation [19577] on immune target | Wasted stun CD | Check target stun-immune before casting | `target_stun_immune` | Wago DB2 |
| Mend Pet [27046] during burst | Wasted GCD | Queue Mend only when pet HP < 50% | `pet_hp_pct`, `mend_pet_cd` | Icy Veins |
| Kill Command [34026] on cooldown | Wasted focus | Track KC CD; queue only when off CD | `kc_cd`, `focus_available` | Wowhead |
| Feign Death [5384] resisted | Cannot drop threat | Use Shadowmeld [20580] if Night Elf; call for Salvation | `feign_resist`, `race` | Icy Veins |
| PvP: Scatter Shot [19503] on DR target | Wasted GCD | Check DR before scatter; use Concussive Shot instead | `scatter_dr` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Attumen | MOVEMENT | Mounted phase = pet follows, keep DPS | `attumen_mounted` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = max range; pet may die | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; save CDs | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = pet target switching | `alar_phoenix_active` | Icy Veins |
| Black Temple | Teron | CC-REQUIRED | Ghost = affected player stop DPS | `teron_ghost_active` | Wowhead |
| Black Temple | Shahraz | FATAL-ATTRACTION | Spread = stop melee; ranged only | `fatal_attraction_active` | Icy Veins |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs, no conserve | `brutallus_hp < 20` | Wowhead |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = spread; pet may die | `felmyst_gas_nova_casting` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Hunter Beast Mastery | Raid | Ferocious Inspiration [34460] | 34460 | +3% damage for party | Always active | Wago DB2 |
| Hunter Beast Mastery | Melee group | Trueshot Aura [31519] | 31519 | +100 AP for party | Always active | Icy Veins |
| Hunter Beast Mastery | Target | Expose Weakness [34500] | 34500 | +AP debuff on target | When Survival in raid | Wowhead |
| Paladin Blessing | Hunter Beast Mastery | Blessing of Might [25291] | 25291 | +AP for pet scaling | Apply to Hunter | Wago DB2 |
| Shaman Enhancement | Hunter Beast Mastery | Unleashed Rage [30804] | 30804 | +AP proc = more pet damage | When in melee group | Icy Veins |
| Warrior Enhancement | Hunter Beast Mastery | Battle Shout [25289] | 25289 | +AP for pet scaling | When in same group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base damage | AP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Steady Shot [34120] | 150 + 0.2 RAP | 0.20 | 110 | 1.5 | 1.4 | 100 | >3s | Primary filler |
| Kill Command [34026] | 75 + 0.15 RAP | 0.15 | 0 | 0 | ∞ | 0 | Any | Pet command |
| Arcane Shot [27019] | 273 | 0.15 | 230 | 1.5 | 1.2 | 182 | >3s | Instant shot |
| Multi-Shot [27021] | 205 | 0.15 | 230 | 1.5 | 0.9 | 137 | 3+ targets | AoE shot |
| Bestial Wrath [19574] | +50% pet damage | N/A | 0 | 0 | +50% | +50% | Burst phase | 18s duration |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 20% | Steady Shot [34120] only; no Arcane Shot | Viper Sting [27018] | Potion | `mana_pct`, `viper_sting_cd` |
| Mana < 10% | Auto-shot only | All special shots forbidden | Potion, wait for Aspect of Viper [34074] | `mana_pct`, `potion_cd` |
| Pet HP < 30% | Stop Kill Command [34026]; queue Mend Pet [27046] | Mend Pet [27046] | Pet potion if available | `pet_hp_pct`, `mend_pet_cd` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| BW + RF timing | Stagger by 5s for sustained haste | Often used together on pull | INTENTIONAL CHOICE | Suboptimal burst | Add `bw_remains` RF gate | Icy Veins |
| Pet target switching | Manual switch for priority adds | Often auto-attack on wrong target | MISSING FEATURE | Pet DPS loss | Add `priority_add` pet command | Wowhead |
| Kill Command queue | Queue KC only when off CD | Often double-queues causing waste | LIKELY BUG | Focus waste | Add `kc_cd == 0` check | Icy Veins |
| Mend Pet timing | Only when pet HP < 50% | Often queued on CD | LIKELY BUG | GCD waste | Add `pet_hp < 50` gate | Icy Veins |
| Aspect switching | Hawk [27044] for DPS, Viper [34074] for mana | Often stays in Hawk at low mana | LIKELY BUG | Mana starvation | Auto-switch to Viper at 20% | Wowhead |

**Prioritized fix backlog:**
1. BW + RF timing — DPS optimization
2. Aspect switching — mana sustain
3. Kill Command queue — focus efficiency
4. Pet target switching — encounter awareness

[NEW FINDING] Hunter Beast Mastery should stagger Bestial Wrath [19574] and Rapid Fire [3045] by ~5s for sustained haste overlap.
[DB2/WOWHEAD VETTED 2026-05-18] Aspect of the Viper [34074] is a level 64 Hunter spell in `wow_anniversary`; DB2 shows a 5s periodic mana effect and Wowhead describes mana returned every 5s from intellect/level with stronger return at low mana. Use it as a mana-recovery aspect gate, not as a modern on-hit restore.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Hunter Beast Mastery research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
