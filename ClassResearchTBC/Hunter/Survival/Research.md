# Survival Hunter Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Survival Hunter, Wowhead Hunter DPS rotation, Flux Hunter research, Sonah Survival, SlyRotate Hunter.

## Role

Ranged DPS with Expose Weakness raid utility and strong agility scaling. Survival often earns a raid spot by improving physical raid damage.

## Single Target

Priority:
1. Maintain Hunter's Mark if assigned.
2. Keep Expose Weakness uptime through crit-focused gearing and steady attacks.
3. Serpent Sting only if worth the mana/debuff slot for the fight.
4. Multi-Shot/Arcane Shot when safe for Auto Shot timing.
5. Steady Shot between Auto Shots.
6. Rapid Fire/trinkets in burn windows.
7. Aspect swap for mana.

## Advanced: Melee Weaving

- Survival can use melee weaving in some high-skill setups, moving into melee for Raptor Strike/other melee events between ranged shots.
- This requires range timing, swing timing, encounter movement safety, and should be an optional/manual mode.

## Multi Target

- Multi-Shot cleave.
- Explosive Trap if safe.
- Volley for larger stacked packs with mana available.
- Maintain priority target pressure over padding when Expose Weakness uptime is important.

## PvP

- Wyvern Sting, traps, kiting, Viper Sting, and defensive positioning define Survival.
- Use Counterattack/Mongoose Bite style tools only when forced into melee and verified for the target ruleset.

## Consumables, Gear, Sets

- Agility is especially valuable because Expose Weakness scales from agility/crit gameplay.
- Use physical DPS consumables, Haste Potion, best ammo/scope.

## Automation Notes

- Track Expose Weakness, Auto Shot timing, Steady windows, trap safety, mana/aspect, enemy range.
- Keep melee-weaving off by default unless the implementation has reliable movement and timing state.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Utility ranged DPS with Expose Weakness scaling, trap control, Auto/Steady discipline, and high agility value.

### Talent Builds and Variants

Expose Weakness, Survivalist, Lightning Reflexes, Master Tactician, Surefooted, Wyvern Sting in PvP/control builds.

### Core Stats and Caps

Hit to cap, agility for Expose Weakness, crit, attack power, haste where available.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Arcane Shot | 3044, 14281, 14282, 14283, 14284, 14285, 14286, 14287, 27019 | Marksmanship | core |
| Auto Shot | 75 | Marksmanship | conditional |
| Expose Weakness | 34500, 34501, 34502, 34503 | Survival | conditional |
| Feign Death | 5384 | Survival | core |
| Freezing Trap | 1499, 14310, 14311 | Survival | utility |
| Hunter's Mark | 1130, 14323, 14324, 14325 | Marksmanship | core |
| Misdirection | 34477 | Survival | core |
| Multi-Shot | 2643, 14288, 14289, 14290, 25294, 27021 | Marksmanship | core |
| Steady Shot | 34120 | Marksmanship | core |
| Wyvern Sting | 19386, 24131, 24132, 24133, 24134, 24135, 27068, 27069 | Survival | conditional |

### Single-Target Priority

1. Maintain Hunter's Mark assignment.
2. Keep pet attacking safely.
3. Use Steady Shot without clipping Auto Shot.
4. Use Multi-Shot/Arcane Shot only when timing and mana permit.
5. Maximize crit uptime to maintain Expose Weakness raid value.
6. Trap weave only if assigned and safe for positioning.

### Multi-Target and AoE Matrix

- 2 targets: Multi-Shot if no CC risk.
- 3 targets: Multi-Shot gains value and Expose Weakness remains raid support.
- 4+ targets: Volley only after stable threat.
- Short-lived adds: Misdirection tank and instant-shot priority adds.
- CC packs: Survival often owns trap control; do not cleave controlled mobs.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Rapid Fire/trinkets align with raid burn windows; do not sacrifice Expose Weakness uptime by mispositioning.

### Resource Management

Agility/crit value supports the raid; avoid mana waste that forces Viper during high-value Expose Weakness windows.

### Threat Management

Misdirection and Feign Death are mandatory around burst/add waves.

### Utility, Interrupts, and Dispels

Trap control, Wyvern Sting, Entrapment/Surefooted utility, Viper Sting, Tranq Shot, flare, and kiting.

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
| Explosive Trap [27025] placement miss | Lost AoE damage | Pre-position on predicted path; check target movement | `trap_placement_pos`, `target_movement` | Wowhead |
| Black Arrow ID collision: [19434] is Aimed Shot, not Survival Black Arrow | Wasted GCD or wrong spell | Do not use Black Arrow in Survival rotation; Serpent Sting [27016] remains the TBC DoT | `spell_known_black_arrow`, `spell_id_resolved` | Wago DB2 |
| Wyvern Sting [27068] on DoT target | DoT breaks sleep | Check target debuffs before Wyvern; use on clean target | `target_has_dot` | Icy Veins |
| Expose Weakness [34500] uptime < 50% | Lost raid AP | Maintain with high crit rate; use Readiness [23989] if needed | `expose_weakness_uptime`, `readiness_cd` | Wowhead |
| Trap Launcher [77769] DB2 absent | Spell unavailable | Use manual trap placement instead | `spell_known_trap_launcher` | Wago DB2 |
| Feign Death [5384] resisted | Cannot drop threat | Shadowmeld [20580] if Night Elf; call for Salvation | `feign_resist`, `race` | Icy Veins |
| PvP: Wyvern Sting on DR target | Wasted GCD | Check DR before Wyvern; use Scatter Shot instead | `wyvern_dr` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Attumen | MOVEMENT | Mounted phase = trap placement harder | `attumen_mounted` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = max range; trap placement safe | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; save CDs | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = trap on adds | `alar_phoenix_active` | Icy Veins |
| Black Temple | Teron | CC-REQUIRED | Ghost = affected player stop DPS | `teron_ghost_active` | Wowhead |
| Black Temple | Shahraz | FATAL-ATTRACTION | Spread = stop melee; ranged traps | `fatal_attraction_active` | Icy Veins |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Wowhead |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = spread | `felmyst_gas_nova_casting` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Hunter Survival | Raid | Expose Weakness [34500] | 34500 | +AP debuff on target | Maintain with high crit | Wago DB2 |
| Hunter Survival | Target | Hunter's Mark [14325] | 14325 | +110 RAP for all attackers | Maintain on boss | Icy Veins |
| Hunter Survival | Raid | Trueshot Aura [31519] | 31519 | +100 AP for party | Always active | Wowhead |
| Paladin Blessing | Hunter Survival | Blessing of Might [25291] | 25291 | +AP | Apply to Hunter | Wago DB2 |
| Shaman Enhancement | Hunter Survival | Unleashed Rage [30804] | 30804 | +AP proc | When in melee group | Icy Veins |
| Warrior Enhancement | Hunter Survival | Battle Shout [25289] | 25289 | +AP | When in same group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base damage | AP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Steady Shot [34120] | 150 + 0.2 RAP | 0.20 | 110 | 1.5 | 1.4 | 100 | >3s | Primary filler |
| Do not use Explosive Shot [53209] (DB2 absent) | N/A | N/A | N/A | N/A | N/A | N/A | N/A | WotLK-only mechanic for this project — skip |
| Serpent Sting [27016] | 660 | 0.10 | 275 | 1.5 | 2.4 | 440 | >15s | DoT maintenance |
| Wyvern Sting [27068] | 300 | 0.05 | 200 | 1.5 | 1.5 | 200 | >12s | CC + DoT |
| Readiness [23989] | Reset CDs | N/A | 0 | 0 | ∞ | ∞ | Burst phase | Resets all CDs |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 20% | Steady Shot [34120] only; no Serpent Sting | Viper Sting [27018] | Potion | `mana_pct`, `viper_sting_cd` |
| Mana < 10% | Auto-shot only | All special shots forbidden | Potion, Aspect of Viper [34074] | `mana_pct`, `potion_cd` |
| Expose Weakness uptime < 50% | Low crit or poor uptime | Readiness [23989] to reset | Focus on crit gear | `expose_weakness_uptime` |

**Part C — Debuff Uptime Value**

| Debuff [ID] | Dmg 60s fight | Dmg 20s fight | Drop priority | Refresh early? | Notes |
|---|---|---|---|---|---|
| Serpent Sting [27016] | ~800 | ~300 | Medium | No, clip only <1.5s | Primary DoT |
| Expose Weakness [34500] | N/A (buff) | N/A | High | Refresh on expiry | Raid AP buff |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Expose Weakness uptime | Maintain > 80% with high crit | Often < 50% uptime | LIKELY BUG | Lost raid AP | Add crit threshold check | Wowhead |
| Wyvern Sting target | Use on clean target (no DoT) | Often breaks own Serpent Sting | LIKELY BUG | Lost DoT damage | Add `target_has_dot` check | Icy Veins |
| Trap placement | Pre-place on predicted path | Often reactive placement | MISSING FEATURE | Missed trap procs | Add `target_path` prediction | Wowhead |
| Readiness usage | Use to reset Expose Weakness or burst CDs | Often used on minor CDs | INTENTIONAL CHOICE | Suboptimal burst | Add `major_cd_ready` check | Icy Veins |
| Black Arrow attempt | Spell not in TBC | May attempt to cast | TBC GUARDRAIL VIOLATION | GCD waste | Remove from rotation | Wago DB2 |

**Prioritized fix backlog:**
1. Expose Weakness uptime — raid DPS critical
2. Wyvern Sting DoT check — personal DPS
3. Trap placement prediction — encounter awareness
4. Black Arrow removal — TBC compliance

[NEW FINDING] Hunter Survival Expose Weakness [34500] must maintain > 80% uptime; use Readiness [23989] if uptime drops.
[DB2 VETTED 2026-05-18] Black Arrow exists in the local DB2 only as Hunter Marksmanship [3674/14296], while [19434] is Aimed Shot; Explosive Shot [53209] and Trap Launcher [77769] are absent from `wow_anniversary` SpellName/class skillline DB2. Do not implement them for Survival.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Hunter Survival research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
