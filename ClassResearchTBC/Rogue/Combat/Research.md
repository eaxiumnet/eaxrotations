# Combat Rogue Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Rogue, Wowhead Rogue database/talents, Flux Rogue research, Sonah Combat, SlyRotate Rogue.

## Role

Primary PvE Rogue raid build in TBC. Strong sustained single-target damage with Blade Flurry and Adrenaline Rush cooldown windows. Often the baseline for Rogue rotation plugins.

## Single Target

Priority:
1. Maintain Slice and Dice at high uptime.
2. Use Blade Flurry/Adrenaline Rush in planned burn windows, often early with trinkets.
3. Maintain Rupture on long-lived targets when bleed is allowed and armor/poison context supports it.
4. Sinister Strike as primary combo builder for swords/maces/fists.
5. Eviscerate when SnD is safe and Rupture is not needed/worth it.
6. Kick important casts; do not spend all energy before known interrupts.
7. Maintain weapon poisons.

## Armor Debuff Assignment

- Improved Expose Armor can be a raid assignment.
- Do not apply Expose Armor unless assigned; it can conflict with Warrior Sunder/Devastate plans.
- If assigned, maintain Expose Armor at the required combo point policy instead of normal finisher plan.

## Multi Target

- Blade Flurry is the main cleave tool.
- Sappers and bombs add burst AoE.
- Fan of Knives does not exist in TBC.

## PvP

- Combat PvP uses Kick, Gouge, Kidney Shot, Blind, Sprint, Evasion, Cloak, poisons, and cooldown burst.
- Save energy for Kick/control in caster matchups.

## Consumables, Gear, Sets

- Hit cap and expertise/weapon skill are important, then agility/AP/crit/haste.
- Slow main hand, fast off hand often supports poison/proc patterns depending on weapon setup.
- Flask of Relentless Assault, Haste Potion, Super Sapper Charge.

## Automation Notes

- Track SnD/Rupture/Expose Armor, energy, combo points, Blade Flurry/AR, target count, assigned armor debuff flag, Kick reserve energy.
- Sonah's Expose Armor and anti-caster logic are useful local references.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Primary PvE Rogue DPS build using Slice and Dice uptime, Sinister Strike, Rupture/Eviscerate, Adrenaline Rush, and Blade Flurry.

### Talent Builds and Variants

Adrenaline Rush, Blade Flurry, Combat Potency, Surprise Attacks, Weapon Specialization, Aggression.

### Core Stats and Caps

Hit, expertise where available, weapon skill, agility, attack power, haste, crit.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Adrenaline Rush | 13750 | Combat | conditional |
| Blade Flurry | 13877 | Combat | core |
| Eviscerate | 2098, 6760, 6761, 6762, 8623, 8624, 11299, 11300, 26865, 31016 | Assassination | core |
| Feint | 1966, 6768, 8637, 11303, 25302, 27448 | Combat | conditional |
| Kick | 1766, 1767, 1768, 1769, 38768 | Combat | core |
| Rupture | 1943, 8639, 8640, 11273, 11274, 11275, 26867 | Assassination | core |
| Sinister Strike | 1752, 1757, 1758, 1759, 1760, 8621, 11293, 11294, 26861, 26862 | Combat | core |
| Slice and Dice | 5171, 6774 | Assassination | core |
| Vanish | 1856, 1857, 26889 | Subtlety | core |

### Single-Target Priority

1. Open safely and establish Slice and Dice.
2. Keep Slice and Dice active at all times.
3. Use Sinister Strike as the builder.
4. Use Rupture when the target will live and bleed is allowed.
5. Use Eviscerate when Rupture will not tick or bleed is immune.
6. Use Expose Armor only if assigned and raid gain beats personal finisher loss.

### Multi-Target and AoE Matrix

- 2 targets: Blade Flurry is high value; use with cooldowns if both targets live.
- 3 targets: Blade Flurry still hits one extra target only; focus priority mobs.
- 4+ targets: no true Rogue AoE; control/interrupt dangerous mobs.
- Short-lived adds: swap only if priority add matters; keep SnD if returning to boss.
- CC packs: no cleave near sap/sheep/trap.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Stack Adrenaline Rush, Blade Flurry, trinkets, and Bloodlust/Heroism for cleave or boss burn; avoid energy capping during AR.

### Resource Management

Pool before SnD refreshes and cooldown windows; do not waste combo points.

### Threat Management

Combat burst can pull; Feint/Vanish around cooldown stacks.

### Utility, Interrupts, and Dispels

Kick, stuns, Blind, Sap, Gouge, Expose Armor, poisons, Distract, and evasion tanking in emergencies.

### PvP Playstyle

Open from stealth with a plan: sap one, lock one, blind/trinket punish, and reset with Vanish. Energy pooling and DR awareness matter more than raw button speed.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Rogue/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Sinister Strike [26862] on energy-starved target | Wasted energy | Use only when energy > 40; queue auto-attack if low | `energy`, `ss_cost` | Wowhead |
| Eviscerate [26867] at 1-2 combo points | Suboptimal damage | Use only at 4-5 combo points | `combo_points` | Icy Veins |
| Slice and Dice [6774] expiry mid-combat | Lost haste buff | Re-cast SnD before expiry; track remaining time | `snd_remains`, `snd_duration` | Wowhead |
| Blade Flurry [13877] on single target | Wasted CD | Use only when 2+ targets within 5y | `target_count` | Icy Veins |
| Adrenaline Rush [13750] during heroism | Energy cap risk | Delay AR until heroism ends | `heroism_active`, `ar_cd` | Wowhead |
| Rupture [26867] on short-lived target | Wasted DoT ticks | Use only when TTD > 12s | `target_ttd` | Icy Veins |
| PvP: Gouge [38764] on bleed target | Wasted GCD | Check target bleed debuffs before gouge | `target_has_bleed` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Attumen | MOVEMENT | Mounted phase = movement; instant abilities | `attumen_mounted` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = max melee range; stop Blade Flurry | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant abilities | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = Blade Flurry value | `alar_phoenix_active` | Icy Veins |
| Black Temple | Supremus | KITE-PHASE | Volcano = move; ranged only | `supremus_volcano_active` | Wowhead |
| Black Temple | Shahraz | FATAL-ATTRACTION | Spread = stop melee | `fatal_attraction_active` | Icy Veins |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Wowhead |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = spread | `felmyst_gas_nova_casting` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Rogue Combat | Target | Expose Armor [26866] | 26866 | -armor debuff | When no Warrior tank | Wago DB2 |
| Rogue Combat | Target | Wound Poison [22055] | 22055 | -healing debuff | When healing target | Icy Veins |
| Rogue Combat | Target | Deadly Poison [27282] | 27282 | DoT poison | Maintain 5-stack | Wowhead |
| Warrior Arms | Rogue Combat | Sunder Armor [25225] | 25225 | Major armor debuff; skip Expose if present | `target_has_sunder` | Icy Veins |
| Paladin Blessing | Rogue Combat | Blessing of Might [25291] | 25291 | +AP | Apply to Rogue | Wowhead |
| Shaman Enhancement | Rogue Combat | Windfury Totem [25505] | 25505 | +AP proc | When in melee group | Icy Veins |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base damage | AP coefficient | Energy cost | GCD | DPE | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Sinister Strike [26862] | 98 + 0.15 AP | 0.15 | 45 | 1.5 | 2.2 | 98 | >3s | Primary builder |
| Eviscerate [26867] | 500 + 0.15 AP | 0.15 | 35 | 1.0 | 14.3 | 500 | 4-5 CP | Finisher |
| Rupture [26867] | 800 + 0.05 AP | 0.05 | 25 | 1.0 | 32.0 | 800 | >12s | DoT finisher |
| Slice and Dice [6774] | +30% haste | N/A | 25 | 1.0 | +30% | +30% | Any | Buff maintenance |
| Blade Flurry [13877] | +20% attack speed | N/A | 25 | 0 | +20% | +20% | 2+ targets | AoE burst |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Energy < 45 | No Sinister Strike; auto-attack only | Wait for energy tick | None — time-based | `energy`, `ss_cost` |
| Energy < 25 | No finisher; auto-attack only | Wait for energy tick | None — time-based | `energy`, `finisher_cost` |
| Combo points < 4 | No Eviscerate; use Rupture or SnD | Build CP with Sinister Strike | None — builder required | `combo_points` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Blade Flurry target count | Only when 2+ targets | Often used on single target | LIKELY BUG | Wasted CD | Add `target_count >= 2` check | Wowhead |
| Adrenaline Rush timing | Use during burst phases | Often used on cooldown | INTENTIONAL CHOICE | Suboptimal burst | Add `burst_phase_active` check | Icy Veins |
| Slice and Dice uptime | Maintain 100% uptime | Often let drop | LIKELY BUG | Lost haste | Add `snd_remains < 3` refresh | Wowhead |
| Rupture target lifetime | Only when TTD > 12s | Often uses on short-lived targets | LIKELY BUG | Wasted DoT ticks | Add `target_ttd > 12` gate | Icy Veins |
| Eviscerate combo point gate | Only at 4-5 CP | Often uses at 2-3 CP | LIKELY BUG | Suboptimal damage | Add `combo_points >= 4` gate | Wowhead |

**Prioritized fix backlog:**
1. Slice and Dice uptime — haste critical
2. Blade Flurry target count — CD efficiency
3. Eviscerate CP gate — damage optimization
4. Rupture target lifetime — DoT efficiency

[NEW FINDING] Rogue Combat must maintain Slice and Dice [6774] at 100% uptime; re-cast when < 3s remains.
[DB2/WOWHEAD VETTED 2026-05-18] Blade Flurry [13877] is a Combat spell; DB2 aura base 19 and Wowhead both confirm +20% melee attack speed, additional nearby target, 15s duration, and 2m cooldown.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Rogue Combat research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
