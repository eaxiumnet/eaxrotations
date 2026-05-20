# Marksmanship Hunter Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Marksmanship Hunter, Wowhead Hunter DPS rotation, Flux Hunter research, Sonah MM, SlyRotate Hunter.

## Role

Ranged physical DPS with Trueshot Aura support and stronger direct shots. Less pet-centric than BM, more focused on shot cooldowns and Auto Shot timing.

## Single Target

Priority:
1. Maintain Trueshot Aura.
2. Hunter's Mark if assigned.
3. Rapid Fire/trinkets during burn windows.
4. Aimed Shot if talented and timing/mana allow.
5. Multi-Shot on cooldown if it does not clip Auto Shot or break CC.
6. Arcane Shot if timing and mana allow.
7. Steady Shot between Auto Shots.
8. Aspect of the Viper/Hawk swap by mana state.

## Multi Target

- Multi-Shot is the core cleave tool.
- Explosive Trap if safe and targets live long enough.
- Volley for larger stacked packs.
- Avoid breaking CC with Multi-Shot or traps.

## PvP

- Aimed Shot healing reduction, Scatter/Trap setups where talented, Viper Sting, Concussive Shot, Wing Clip, Deterrence/Feign/Freezing Trap control.
- Burst is about setting a CC window, not maximum PvE weave uptime.

## Consumables, Gear, Sets

- Hit cap, agility, attack power, crit, armor penetration where available.
- Flask of Relentless Assault, Haste Potion, agility/attack power food, best ammo and scope.
- Verify tier bonuses that affect shots or pet before coding priority changes.

## Automation Notes

- Same shot-timer safety requirements as BM.
- Track Aimed/Multi/Arcane cooldowns, mana, Auto Shot remaining, movement, CC risk, Trueshot Aura.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Ranged DPS emphasizing personal shot damage, Trueshot Aura support, Auto Shot discipline, and threat tools.

### Talent Builds and Variants

Trueshot Aura, Mortal Shots, Careful Aim, Barrage, Master Marksman, Silencing Shot when talented.

### Core Stats and Caps

Hit to cap, agility, attack power, crit, haste where available.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Aimed Shot | 19434, 20900, 20901, 20902, 20903, 20904, 27065 | Marksmanship | conditional |
| Arcane Shot | 3044, 14281, 14282, 14283, 14284, 14285, 14286, 14287, 27019 | Marksmanship | core |
| Auto Shot | 75 | Marksmanship | conditional |
| Feign Death | 5384 | Survival | core |
| Hunter's Mark | 1130, 14323, 14324, 14325 | Marksmanship | core |
| Misdirection | 34477 | Survival | core |
| Multi-Shot | 2643, 14288, 14289, 14290, 25294, 27021 | Marksmanship | core |
| Rapid Fire | 3045 | Marksmanship | conditional |
| Silencing Shot | 34490 | Marksmanship | conditional |
| Steady Shot | 34120 | Marksmanship | core |

### Single-Target Priority

1. Apply Hunter's Mark when assigned.
2. Preserve Auto Shot cadence above all filler decisions.
3. Use Steady Shot as the primary filler.
4. Use Multi-Shot when safe and not clipping.
5. Use Arcane Shot only if it fits the weapon-speed/mana plan.
6. Use Aimed Shot mainly for opener/PvP/healing reduction, not as a default PvE filler when it disrupts shots.

### Multi-Target and AoE Matrix

- 2 targets: Multi-Shot if no CC break risk.
- 3 targets: Multi-Shot on cooldown if mana/threat safe.
- 4+ targets: Volley for sustained clumped packs after tank threat.
- Short-lived adds: Misdirection and high-impact instant shots.
- CC packs: single-target only.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Rapid Fire and trinkets align with long boss uptime and Bloodlust/Heroism; readiness-style resets are not a TBC Hunter baseline mechanic.

### Resource Management

Do not spend mana on low-value Arcane/Aimed shots if it will force Viper during a burn window.

### Threat Management

Misdirection on pull/adds and Feign Death before reaching the tank.

### Utility, Interrupts, and Dispels

Trueshot Aura, traps, Tranq Shot, Silencing Shot in PvP, Viper Sting, flare, and kiting.

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
| Auto Shot clipped by Steady Shot [34120] | Lost auto-shot damage | Time steady shot between auto shots; use swing timer | `auto_shot_timer`, `steady_cast_time` | Wowhead |
| Aimed Shot [27065] cast interruption | Lost cast time and mana | Cancel cast, retarget, queue instant | `cast_interrupted`, `target_alive` | Common |
| Serpent Sting [27016] refreshed early | Wasted DoT ticks | Refresh only when < 1.5s remains | `serpent_sting_remains` | Icy Veins |
| Rapid Fire [3045] during heroism | Haste cap exceeded | Delay RF until heroism ends | `heroism_active`, `rf_cd` | Wowhead |
| Scatter Shot [19503] on immune target | Wasted GCD | Check target stun-immune before casting | `target_stun_immune` | Wago DB2 |
| Feign Death [5384] resisted | Cannot drop threat | Shadowmeld [20580] if Night Elf; call for Salvation | `feign_resist`, `race` | Icy Veins |
| PvP: Silencing Shot [34490] on wrong school | Wrong lockout | Check target casting school first | `target_casting_school` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Attumen | MOVEMENT | Mounted phase = save Aimed Shot for standstill | `attumen_mounted` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = max range; save CDs | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant shots only | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = target switching; multi-shot value | `alar_phoenix_active` | Icy Veins |
| TK | Void Reaver | ARCANE-ORB | Arcane Orb = move out; stop Aimed Shot | `void_orb_nearby` | Wowhead |
| Black Temple | Teron | CC-REQUIRED | Ghost = affected player stop DPS | `teron_ghost_active` | Icy Veins |
| Black Temple | Shahraz | FATAL-ATTRACTION | Spread = stop melee; ranged only | `fatal_attraction_active` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = spread | `felmyst_gas_nova_casting` | Wowhead |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Icy Veins |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Hunter Marksmanship | Raid | Trueshot Aura [31519] | 31519 | +100 AP for party | Always active | Wago DB2 |
| Hunter Marksmanship | Target | Hunter's Mark [14325] | 14325 | +110 RAP for all attackers | Maintain on boss | Icy Veins |
| Hunter Marksmanship | Target | Silencing Shot [34490] | 34490 | Interrupt + silence | When target casting | Wowhead |
| Hunter Survival | Hunter Marksmanship | Expose Weakness [34500] | 34500 | +AP debuff | When Survival in raid | Wago DB2 |
| Paladin Blessing | Hunter Marksmanship | Blessing of Might [25291] | 25291 | +AP | Apply to Hunter | Icy Veins |
| Shaman Enhancement | Hunter Marksmanship | Unleashed Rage [30804] | 30804 | +AP proc | When in melee group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base damage | AP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Steady Shot [34120] | 150 + 0.2 RAP | 0.20 | 110 | 1.5 | 1.4 | 100 | >3s | Primary filler |
| Aimed Shot [27065] | 870 | 0.20 | 370 | 2.5 | 2.4 | 348 | >5s | Heavy shot |
| Arcane Shot [27019] | 273 | 0.15 | 230 | 1.5 | 1.2 | 182 | >3s | Instant shot |
| Multi-Shot [27021] | 205 | 0.15 | 230 | 1.5 | 0.9 | 137 | 3+ targets | AoE shot |
| Rapid Fire [3045] | +40% haste | N/A | 0 | 0 | +40% | +40% | Burst phase | 15s duration |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 20% | Steady Shot [34120] only; no Aimed Shot | Viper Sting [27018] | Potion | `mana_pct`, `viper_sting_cd` |
| Mana < 10% | Auto-shot only | All special shots forbidden | Potion, Aspect of Viper [34074] | `mana_pct`, `potion_cd` |
| Swing timer < 0.5s | Steady Shot clip risk | Hold steady, wait for auto | None — wait for auto | `auto_shot_timer` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Auto Shot clipping | Time steady between auto shots | Often clips auto with steady | LIKELY BUG | Lost auto damage | Add `auto_timer > cast_time` gate | Wowhead |
| Aimed Shot priority | Use on CD unless mana < 20% | Often skipped for steady spam | INTENTIONAL CHOICE | Suboptimal DPS | Add `mana_pct > 20` AS gate | Icy Veins |
| Serpent Sting refresh | Refresh at < 1.5s | Often refreshed early (>3s) | LIKELY BUG | Wasted DoT ticks | Add `remains < 1.5` check | Wowhead |
| Hunter's Mark uptime | Maintain on boss always | Often let expire | MISSING FEATURE | Lost raid AP | Add `mark_remains < 5` refresh | Icy Veins |
| Silencing Shot usage | Use on casting targets only | Often used on CD | LIKELY BUG | Wasted GCD | Add `target_is_casting` check | Wowhead |

**Prioritized fix backlog:**
1. Auto Shot clipping prevention — DPS critical
2. Hunter's Mark uptime — raid AP
3. Serpent Sting refresh timing — DoT efficiency
4. Silencing Shot target check — GCD efficiency

[NEW FINDING] Hunter Marksmanship Auto Shot must not be clipped by Steady Shot; gate on swing timer.
[DB2/WOWHEAD VETTED 2026-05-18] Silencing Shot [34490] is a Marksmanship spell with a 20s DB2 cooldown and 3s Wowhead silence duration; use only when the target is casting and not silence-immune.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Hunter Marksmanship research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
