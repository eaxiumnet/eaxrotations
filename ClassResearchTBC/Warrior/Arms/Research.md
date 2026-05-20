# Arms Warrior Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Arms Warrior, Wowhead Warrior DPS rotation/talents, Flux Warrior research, Sonah Arms/Fury core, SlyRotate Warrior.

## Role

Physical DPS support spec. Arms brings Mortal Strike and Blood Frenzy-style physical damage support in TBC builds, plus strong cleave with Sweeping Strikes. Slam weaving is the key skill mechanic.

## Single Target

Priority:
1. Maintain Sunder Armor if assigned and no better armor debuff plan exists.
2. Death Wish if talented/available in build and planned.
3. Mortal Strike on cooldown.
4. Whirlwind on cooldown.
5. Slam immediately after a melee swing when Improved Slam and timing allow.
6. Overpower when available and it will not delay MS/WW.
7. Execute below 20% as filler without starving MS/WW.
8. Heroic Strike only as rage dump when core abilities are safe.

## Slam Weaving

- Cast Slam immediately after the auto-attack lands.
- Do not Slam if Mortal Strike/Whirlwind will be delayed or movement is required.
- Needs swing timer, Slam cast time, latency buffer, and rage check.

## Multi Target

- Sweeping Strikes plus Whirlwind/Cleave is the signature cleave window.
- Cleave replaces Heroic Strike as rage dump.
- Maintain priority target debuffs.

## PvP

- Mortal Strike healing reduction, Hamstring, Intercept, Pummel, Spell Reflection, Disarm, Sweeping Strikes burst.
- Rage should be reserved for control and burst windows.

## Consumables, Gear, Sets

- Hit, expertise/weapon skill, strength/AP, crit, armor penetration where available.
- Flask of Relentless Assault, Haste Potion, Super Sapper Charge.
- Slow two-hander for Slam/MS builds.

## Automation Notes

- Track stance, rage, swing timer, Slam window, MS/WW CDs, Sunder stacks, Execute range, HS/Cleave queued state.
- Flux has detailed wowsims-like Slam timing; SlyRotate has a simple post-swing window.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Two-handed physical DPS/support using Mortal Strike, Slam timing, Deep Wounds, debuffs, and rage control.

### Talent Builds and Variants

Mortal Strike, Blood Frenzy, Impale, Deep Wounds, Two-Handed Weapon Specialization, Weapon Specialization.

### Core Stats and Caps

Hit to special cap, expertise where available, strength/attack power, crit, armor penetration where available, weapon damage.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Battle Shout | 2048, 5242, 6192, 6673, 11549, 11550, 11551, 25289 | Fury | conditional |
| Berserker Rage | 18499 | Fury | conditional |
| Execute | 5308, 20647, 20658, 20660, 20661, 20662, 25234, 25236 | Fury | core |
| Hamstring | 1715, 7372, 7373, 25212 | Arms | pvp |
| Heroic Strike | 78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 29707, 30324 | Arms | core |
| Mortal Strike | 12294, 21551, 21552, 21553, 25248, 30330 | Arms | core |
| Pummel | 6552, 6554 | Fury | conditional |
| Slam | 1464, 8820, 11604, 11605, 25241, 25242 | Fury | conditional |
| Sweeping Strikes | 12328, 12723, 26654 | Fury | conditional |
| Whirlwind | 1680 | Fury | core |

### Single-Target Priority

1. Maintain Battle Shout if assigned.
2. Use Mortal Strike on cooldown.
3. Use Slam only when swing timing supports it and movement will not cancel value.
4. Use Whirlwind when rage allows and it will not delay Mortal Strike.
5. Use Heroic Strike only as a rage dump.
6. Use Execute at low health while preserving assigned debuffs.

### Multi-Target and AoE Matrix

- 2 targets: Sweeping Strikes plus Whirlwind is high value.
- 3 targets: Whirlwind and Cleave when rage/threat safe.
- 4+ targets: Warrior AoE is threat-sensitive; use Whirlwind/Cleave but prioritize dangerous mobs.
- Short-lived adds: Mortal Strike/Execute priority add.
- CC packs: avoid Cleave/Whirlwind near controlled targets.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Death Wish/Recklessness if available by build/context; align with Bloodlust/Heroism and threat lead.

### Resource Management

Rage follows damage taken/dealt; do not Heroic Strike away rage needed for Mortal Strike/Whirlwind.

### Threat Management

Arms burst can pull during Sweeping/Recklessness; throttle and use defensive stance if needed.

### Utility, Interrupts, and Dispels

Battle/Commanding Shout, Sunder Armor if assigned, Pummel, Hamstring, Disarm, Intercept, fear break.

### PvP Playstyle

Uptime and rage are everything. Hamstring, Intercept, Pummel, Disarm, stance utility, and healer coordination decide whether pressure sticks.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Warrior/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Mortal Strike [30330] on rage-starved target | Wasted rage | Use only when rage > 30; queue Sunder [25225] if low | `rage`, `mortal_strike_rage` | Wowhead |
| Overpower [7384] proc miss | Wasted reaction window | Track proc immediately; queue after next auto-attack | `overpower_proc_active`, `swing_timer` | Icy Veins |
| Slam [25242] before swing reset | Clipped auto-attack | Cast Slam only after auto-attack lands | `swing_timer`, `slam_cast_time` | Wowhead |
| Execute [25236] at >20% HP | Wasted rage | Use only when target HP <= 20% | `target_hp_pct` | Wago DB2 |
| Sweeping Strikes [12328] on single target | Wasted CD | Use only when 2+ targets within 5y | `target_count` | Icy Veins |
| Rage cap > 100 | Lost rage generation | Dump with Heroic Strike [29707] or Cleave [25231] | `rage`, `rage_cap` | Wowhead |
| PvP: Hamstring [25212] on immune target | Wasted GCD | Check target snare-immune; use Piercing Howl [12323] | `target_snare_immune` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Moroes | ADD-WAVE | Gouge = threat drop; save Overpower for gouge end | `moroes_gouge_active` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = max melee range; stop Slam | `gruul_shatter_timer` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant abilities | `lurker_spout_active` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = Sweeping Strikes value | `alar_phoenix_active` | Icy Veins |
| Black Temple | Supremus | KITE-PHASE | Volcano = move; ranged only | `supremus_volcano_active` | Wowhead |
| Black Temple | Shahraz | FATAL-ATTRACTION | Spread = stop melee; ranged Hamstring | `fatal_attraction_active` | Icy Veins |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = burn all CDs | `brutallus_hp < 20` | Wowhead |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = spread | `felmyst_gas_nova_casting` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Warrior Arms | Target | Mortal Strike [30330] | 30330 | -50% healing debuff | Maintain on boss | Wago DB2 |
| Warrior Arms | Target | Sunder Armor [25225] | 25225 | -armor debuff | Apply if no Prot Warrior | Icy Veins |
| Warrior Arms | Melee group | Battle Shout [25289] | 25289 | +AP for melee | Always active | Wowhead |
| Warrior Arms | Melee group | Commanding Shout [469] | 469 | +HP for raid | Maintain if assigned | Wowhead |
| Paladin Blessing | Warrior Arms | Blessing of Might [25291] | 25291 | +AP | Apply to Warrior | Icy Veins |
| Shaman Enhancement | Warrior Arms | Windfury Totem [25505] | 25505 | +AP proc | When in melee group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base damage | AP coefficient | Rage cost | GCD | DPR | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Mortal Strike [30330] | 110% weapon | 0 | 30 | 1.5 | 3.7 | 733 | >3s | Primary strike |
| Slam [25242] | 140% weapon | 0 | 15 | 1.5 | 9.3 | 933 | >3s | Swing reset |
| Overpower [7384] | 100% weapon | 0 | 5 | 1.5 | 20.0 | 667 | Dodge proc | Reaction strike |
| Execute [25236] | 925 + 21/AP | 0 | 15 | 1.5 | 61.7 | 617 | <=20% HP | Execute phase |
| Sweeping Strikes [12328] | +100% next 5 swings | N/A | 30 | 0 | +100% | +100% | 2+ targets | AoE burst |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Rage < 30 | No Mortal Strike; Sunder [25225] or auto-attack | Auto-attack + wait for rage | None — time-based | `rage`, `mortal_strike_rage` |
| Rage > 80 | Rage cap risk | Heroic Strike [29707] dump | None — dump excess | `rage`, `rage_cap` |
| Rage < 15 | No Slam; auto-attack only | Wait for next swing | None — time-based | `rage`, `slam_rage` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Slam timing | Cast after auto-attack, not before | Often clips auto-attack | LIKELY BUG | Lost auto damage | Add `swing_timer > cast_time` gate | Wowhead |
| Overpower reaction | Queue immediately on dodge | Often delayed >1s | LIKELY BUG | Lost proc window | Add `dodge → immediate_overpower` | Icy Veins |
| Execute threshold | Only at <= 20% HP | Often used at > 20% | LIKELY BUG | Rage waste | Add `target_hp <= 20` gate | Wowhead |
| Sweeping Strikes target count | Only with 2+ targets | Often used on single target | LIKELY BUG | Wasted CD | Add `target_count >= 2` check | Icy Veins |
| Commanding Shout [469] | Valid TBC | May attempt to cast if not learned | Use only if learned/assigned; otherwise Battle Shout [25289] | Wago DB2 |

**Prioritized fix backlog:**
1. Slam timing — DPS critical
2. Overpower reaction — proc efficiency
3. Execute threshold — rage efficiency
4. Commanding Shout [469] — valid TBC; maintain if assigned by raid lead

[NEW FINDING] Warrior Arms Slam [25242] must cast after auto-attack lands, not before, to prevent clipping.
[DB2/WOWHEAD VETTED 2026-05-18] Commanding Shout [469] is a valid level 68 Warrior spell in the local `wow_anniversary` DB2; DB2 effect base is 1079 and Wowhead/TBC databases describe a party max-health increase of about 1080 within 20 yards. Gate on learned spell and raid assignment.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Warrior Arms research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
