# Feral Druid DPS Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Feral DPS, Wowhead Feral DPS talents, Warcraft Tavern powershifting, Flux Druid research, Sonah Feral, SlyRotate Feral.

## Role

Melee DPS with strong utility and the ability to tank using mostly the same talent foundation. The defining TBC mechanic is energy management through powershifting.

## Single Target

Priority:
1. Maintain Faerie Fire (Feral) if no stronger armor debuff assignment conflicts.
2. Maintain Mangle debuff for bleed/Shred value.
3. Maintain Rip, preferably at high combo points and on targets that live long enough.
4. Maintain Rake if energy and target lifetime allow.
5. Use Clearcasting on Shred when behind; Mangle if not behind.
6. Shred as primary combo builder from behind.
7. Mangle as fallback builder when not behind or debuff is falling.
8. Ferocious Bite at 5 combo points when Rip is safe or target is dying.
9. Powershift when energy is low, mana is sufficient, and the shift is profitable.

## Powershifting

- Furor gives energy when entering Cat Form; Wolfshead Helm adds more energy.
- A safe implementation needs current energy, mana floor, Cat Form cost, GCD state, form state, Wolfshead detection or user toggle, and a throttle to prevent spam.
- Tiger's Fury in TBC is flat damage and only usable at zero energy. It is not the Wrath energy button.

## Multi Target

- Feral Cat AoE is weak in TBC.
- Tab-Rake and maintain Mangle on priority target.
- Do not add non-TBC Cat-form AoE; standard TBC Cat AoE is weak and mostly handled through target swapping or single-target priority.
- Often best answer is single-target kill priority plus utility.

## PvP

- Open from Prowl with Pounce/Ravage depending on goal.
- Cyclone, Bash, Maim, Feral Charge in Bear, roots, and shapeshifting are central.
- Preserve energy for control windows; do not blindly bleed targets that need to be CC'd.

## Consumables, Gear, Sets

- Wolfshead Helm is a mechanic item, not just a stat item.
- Physical DPS consumables: Flask of Relentless Assault or elixir setup, Haste Potion, Super Sapper Charge if Engineering, food based on hit/agility/strength needs.
- Watch late-tier set bonuses that can change powershift assumptions.

## Automation Notes

- Track Mangle, Rip, Rake, combo points, Clearcasting, energy tick timing, mana, Cat Form, behind-target state, and target time-to-die.
- Local Flux has the best powershift state model; Sonah has practical powershift toggle/status handling; SlyRotate is useful for a compact baseline.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Cat melee DPS centered on Mangle uptime, Shred positional damage, Rip finishers, clearcasting, and powershifting energy management.

### Talent Builds and Variants

Mangle, Leader of the Pack, Predatory Strikes, Shredding Attacks, Savage Fury, Natural Shapeshifter, Furor, Omen of Clarity.

### Core Stats and Caps

Hit/expertise where available, agility, strength, attack power, crit, armor penetration where available, and weapon DPS through feral attack power items.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Claw | 1082, 3029, 5201, 9849, 9850, 27000 | Feral Combat | conditional |
| Faerie Fire (Feral) | 16857, 17390, 17391, 17392, 27011 | Feral Combat | core |
| Ferocious Bite | 22568, 22827, 22828, 22829, 24248, 31018 | Feral Combat | conditional |
| Mangle | 33917 | Feral Combat | core |
| Prowl | 5215, 6783, 9913 | Feral Combat | conditional |
| Rake | 1822, 1823, 1824, 9904, 27003 | Feral Combat | conditional |
| Rip | 1079, 9492, 9493, 9752, 9894, 9896, 27008 | Feral Combat | conditional |
| Shred | 5221, 6800, 8992, 9829, 9830, 27001, 27002 | Feral Combat | core |
| Tiger's Fury | 5217, 6793, 9845, 9846 | Feral Combat | conditional |

### Single-Target Priority

1. Open from stealth when possible, then apply Mangle.
2. Keep Mangle up before Shred and Rip.
3. Use Shred as the main combo builder from behind the target.
4. Use Rip at high combo points if it will run most of its duration.
5. Use Ferocious Bite only when Rip will not get value or the target is about to die.
6. Powershift when energy is low, mana is safe, and the next global is not needed for Rip/Mangle maintenance.

### Multi-Target and AoE Matrix

- 2 targets: maintain Mangle/Rip on the kill target; do not dilute combo points unless the off-target lives long.
- 3 targets: tab-Rake is usually weak; focus skull unless raid strategy calls for split damage.
- 4+ targets: TBC Cat has no dedicated Cat-form AoE; do not invent non-TBC AoE logic.
- Short-lived adds: Mangle/Shred or Ferocious Bite if combo points already exist.
- CC packs: avoid cleave assumptions; Cat damage is mostly single-target.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Use Tiger's Fury only when it will not delay higher-value energy spenders; use trinkets with Rip/Mangle/Shred uptime and Bloodlust/Heroism windows.

### Resource Management

Treat energy ticks and powershifting as first-class state; avoid shifting when mana would be needed for emergency Bear, decurse, or battle rez.

### Threat Management

Cat threat spikes through crit chains; pause Ferocious Bite and use Cower only if the tank cannot recover.

### Utility, Interrupts, and Dispels

Leader of the Pack, Faerie Fire (Feral), emergency Bear taunt if assigned, Bash/Feral Charge in PvP if talented, and Remove Curse/poison utility out of form.

### PvP Playstyle

Use mobility, forms, Cyclone, roots, HoTs, and shapeshift snare breaks. Feral wins with control into burst; Restoration wins by pre-HoT and line-of-sight; Balance wins by burst windows and control.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Druid/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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

### FAILURE-CASE STATE TABLE

| Trigger event | Broken behavior | Recovery action | State inputs required | Source |
|---|---|---|---|---|
| Energy dips below shift floor while Cat Form is up | Powershift fires too late and misses the next energy tick | Shift only when mana floor, GCD lock, and shift throttle all pass | Energy, mana, GCD, form state, shift cooldown, Wolfshead/Furor gate | Icy Veins powershifting guide; numeric floor configurable |
| Rip [1079/27008] is refreshed before the last useful tick | Clip loses bleed value and lowers finisher efficiency | Refresh only at high combo points and near natural expiry | Combo points, Rip remaining, target time-to-die, behind-target state | Icy Veins Rip full-duration rule |
| Slice and Dice [5171] timing is used as a generic melee refresh model | Feral over-pools or refreshes on the wrong clock | Use bleed clock and combo-point value, not rogue buff cadence | Combo points, bleed remaining, energy, raid-melee benchmark state | Cross-spec guardrail; do not copy Rogue timing |
| Energy pooling collapses before a finisher window | Shred/Mangle burns energy and blocks Rip [1079/27008] or Ferocious Bite [22568/31018] | Pool to a floor before builder spam if a finisher is imminent | Energy, combo points, Rip window, target life expectancy | Icy Veins Ferocious Bite energy-efficiency rule; numeric floor configurable |
| Mangle [33917] drops while bleed uptime matters | Shred and Rip lose priority value | Reapply Mangle before bleed spenders when debuff is missing or near expiry | Debuff remaining, combo points, target bleedability, raid debuff assignment | Icy Veins Mangle uptime rule |
| Clearcasting proc appears during low-energy burst planning | Proc is wasted on low-value filler | Reserve proc for Shred [5221/27002] or Rip [1079/27008] setup, not panic-spend | Clearcasting state, energy, behind-target state, finisher queue | Icy Veins Omen/Ferocious Bite guidance; proc ranking configurable |
| Target will die before Rip [1079/27008] completes | Finisher is over-invested and combo points are stranded | Switch to direct damage or Ferocious Bite [22568/31018] only if it lands value | Target time-to-die, Rip remaining, combo points, energy | Icy Veins Rip vs Ferocious Bite rule |
| Cat Form drops during a controlled transition | Energy state resets and the next reopen is delayed | Re-enter with the highest safe mana floor and immediate re-open plan | Form state, mana, encounter phase, combat lockdown | Icy Veins powershifting guide; encounter-specific gate |

### BOSS MODIFIER TABLE

| Encounter | Modifier | Rotation impact | State inputs required | Source |
|---|---|---|---|---|
| Attumen the Huntsman | Mount swap and melee downtime windows | Delay burst until stable uptime returns | Encounter phase, target swap, melee range, energy | Encounters matrix / local boss modifier pass |
| Moroes | Add control, garrote pressure, frequent target swaps | Pool energy before swaps; do not dump into the wrong target | Add count, target assignment, bleed remaining | Encounters matrix / local boss modifier pass |
| Curator | Burn/add cycle with forced kill windows | Hold finisher value for burn phase; avoid overcapping during evocation | Evocation timing, add timer, combo points, energy | Encounters matrix / local boss modifier pass |
| Nightbane | Air phase disengage and re-engage timing | Stop overcommitting energy before lift-off; re-open fast on landing | Phase flag, range, form state, mana | Encounters matrix / local boss modifier pass |
| Prince Malchezaar | Infernal movement, axe pressure, positional disruption | Preserve enough energy for immediate rebuild after movement | Boss phase, fire zone, target angle, energy | Encounters matrix / local boss modifier pass |
| Gruul the Dragonkiller | Growth stacks shorten safe uptime and punish late reposition | Shift earlier before forced movement; keep Rip [1079/27008] only when safe | Growth stacks, melee uptime, Rip remaining, energy | Encounters matrix / local boss modifier pass |
| Magtheridon | Cube duty and hard stop windows | Stop damage early enough to interact with mechanics | Cube timing, cast lock, target TTD, energy floor | Encounters matrix / local boss modifier pass |
| Hydross the Unstable | Phase swap resets threat/positioning | Re-evaluate debuff and target priority at every swap | Phase state, target resist phase, debuff timers | Encounters matrix / local boss modifier pass |
| Lurker Below | Dive/transition downtime with return burst | Pool for the return window instead of burning through dive | Dive timer, melee range, energy, combo points | Encounters matrix / local boss modifier pass |
| Void Reaver | Movement from orbital pressure and spacing loss | Maintain safer energy floor for relocation | Orb pressure, range, movement state, target uptime | Encounters matrix / local boss modifier pass |
| Kael'thas Sunstrider | Multi-add control and scripted swaps | Save combo points for the next high-value add or boss reopen | Add timer, weapon/add state, target priority | Encounters matrix / local boss modifier pass |
| Lady Vashj | Heavy target swapping and forced movement | Do not over-bleed low-value targets before swap points | Add phase, target swap, energy, combo points | Encounters matrix / local boss modifier pass |

### CROSS-SPEC INTERACTIONS

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Feral Druid DPS | Rogue Combat / Assassination | Bleed amplifier | Mangle [33917], Rip [1079/27008], Rupture [1943] | Keep Mangle priority high when rogue bleed value is expected | Boss can bleed and rogue bleed uptime matters | DB2/Icy Veins Mangle bleed-value rule |
| Feral Druid DPS | Warrior Arms | Physical bleed amplifier | Mangle [33917], Rend [772/6546/6547/6548/11572/11573] | Do not let filler delay Mangle on a Rend-based damage window | Warrior bleed assigned and boss bleeds | DB2/Icy Veins Mangle bleed-value rule |
| Feral Druid DPS | Feral Druid Bear Tank | Debuff handoff / shared maintenance | Faerie Fire (Feral) [16857/27011], Mangle [33917] | Track whether this spec or tank is responsible for maintaining the armor-debuff layer | Shared druid assignment exists | Local assignment heuristic |
| Feral Druid DPS | Hunter Marksmanship | Armor debuff support | Faerie Fire (Feral) [16857/27011], Aimed Shot [19434/20900/20901/20902/20903/20904/27065] | Armor debuff uptime can be treated as a precondition to clean physical burst | Hunter burst window active | Wago DB2 rank correction |
| Feral Druid DPS | Priest Shadow | Kill-speed / uptime synergy | Rip [1079/27008], Mind Blast [8102/8103/8104/8105/8106/10890] | Feral should avoid wasting movement windows that line up with caster burn | Burst phase active | Cross-spec burn-window heuristic |
| Feral Druid DPS | Feral Druid Restoration | Mana economy support | Innervate [29166], Rebirth [20484] | Powershift planning must reserve mana for emergency utility | Mana reserve below safety floor | Icy Veins utility support note |
| Feral Druid DPS | Rogue Subtlety | Open-window timing benchmark | Slice and Dice [5171], Rip [1079/27008] | SnD [5171] is a timing benchmark only; do not copy its refresh clock into Feral bleed logic | Shared melee burst planning | Cross-spec guardrail |

### RESOURCE EFFICIENCY

| AP breakpoint | Energy floor thresholds | Action | Stop condition | Source |
|---|---|---|---|---|
| 1500 AP | 25 energy minimum before spend | Favor safe Rip [1079/27008] setup over filler spam | Finisher window opens or Clearcasting appears | TBC Feral heuristic [VERIFY] |
| 1500 AP | 30 energy before powershift reset | Shift only when the next builder would otherwise stall | Mana floor and shift throttle both pass | TBC Feral heuristic [VERIFY] |
| 2000 AP | 30 energy minimum before spend | Pool slightly harder for Shred [5221/27002] into Rip value | Combo points cap or target TTD drops | TBC Feral heuristic [VERIFY] |
| 2000 AP | 35 energy before Bite [22568/31018] | Spend only when Rip value is already protected | Rip safe and target not dying too fast | TBC Feral heuristic [VERIFY] |
| 2500 AP | 35 energy minimum before spend | Bias toward finisher protection over filler | High-value bleed window or movement phase ends | TBC Feral heuristic [VERIFY] |
| 2500 AP | 40 energy before powershift | Preserve enough post-shift energy to rebuild quickly | Mana, form, and GCD all safe | TBC Feral heuristic [VERIFY] |
| Any AP | 20 energy emergency floor | Stop nonessential builders and preserve the next GCD for finishers | Finisher not yet ready or movement imminent | TBC Feral heuristic [VERIFY] |

### IMPLEMENTATION DIVERGENCE

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Powershifting | Needs mana floor, shift throttle, form check, and shift-value gate | Likely uses a simple low-energy trigger | Missing state gate | Spam shift or mana starvation | Add explicit shift-state machine inputs | Icy Veins powershifting guide / local audit |
| Rip [1079/27008] timing | Refresh on high-value windows only | Likely uses a timer-first refresh rule | Premature refresh | Clipped bleed ticks | Gate on combo points, TTD, and remaining duration | Icy Veins Rip full-duration rule / local audit |
| Mangle [33917] priority | Keep debuff up before bleed spenders | Likely treats Mangle as a normal fallback builder | Priority inversion | Lower Rip/Shred value | Promote Mangle to debuff-maintenance tier | Icy Veins Mangle uptime rule / local audit |
| Energy pooling | Pool before finisher windows and movement | Likely spends at a fixed low threshold | Under-pooling | No Rip/Bite window | Tie floor to AP breakpoint and target life | Icy Veins Ferocious Bite energy-efficiency rule / local audit |
| Slice and Dice [5171] benchmark | Rogue timing is only an analogy, not a feral clock | Likely has no explicit cross-spec guard | Model mismatch | Wrong refresh heuristic | Keep feral bleed clock separate from rogue buff clock | Cross-spec guardrail / local audit |
| Clearcasting use | Spend on the highest-value attack that fits the window | Likely burns the proc on any available button | Proc misallocation | Lost damage per proc | Reserve proc for Shred [5221/27002] or finisher setup | Icy Veins Omen/Ferocious Bite guidance / local audit |

| Spec | Tracker |
|---|---|
| Druid Feral DPS | [x] |

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Druid Feral DPS research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
