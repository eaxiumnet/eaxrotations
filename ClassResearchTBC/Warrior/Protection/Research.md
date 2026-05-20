# Protection Warrior Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Protection Warrior, Wowhead Warrior tank resources, Flux Warrior research, Sonah Protection Warrior, SlyRotate Warrior.

## Role

Primary shield tank with strong single-target threat, defensive cooldowns, stance utility, and encounter control. More reactive than Paladin tanking and stronger at controlled boss tanking.

## Single Target Tanking

Priority:
1. Defensive Stance and shield equipped for tank rotation.
2. Shield Block for crushing/block-sensitive windows and Revenge activation.
3. Shield Slam on cooldown.
4. Revenge when available.
5. Devastate/Sunder Armor to maintain armor debuff and filler threat; verify exact target ruleset.
6. Heroic Strike as rage dump when Shield Slam/Revenge/Shield Block are safe.
7. Demo Shout/Thunder Clap if assigned and worth the GCD/rage.
8. Taunt only when needed.

## Multi Target Tanking

- Thunder Clap, Demo Shout, tab Devastate/Sunder, Cleave, Revenge/Shield Slam priority targets.
- Challenging Shout is emergency AoE taunt, not normal rotation.
- Avoid breaking CC.

## Defensive Play

- Shield Wall, Last Stand, trinkets, potions by incoming damage.
- Spell Reflection for reflectable spells if supported and shield conditions are met.
- Berserker Rage for fear mechanics where stance swap is acceptable.

## PvP

- Prot PvP is utility/control-oriented: Shield Slam dispel, Concussion Blow, Intercept/Charge, Spell Reflection, Disarm.
- Damage rotation differs from boss tanking.

## Consumables, Gear, Sets

- Defense cap, stamina, armor, shield block value, avoidance, hit/expertise for threat.
- Flask of Fortification, Ironshield Potion, stamina food, resistance consumables by encounter.
- Tier bonuses affecting Shield Block, Revenge, Shield Slam, or Devastate need verification.

## Automation Notes

- Track rage, Shield Block remains/charges, Revenge availability, Shield Slam CD, Sunder stacks, threat, taunt need, defensive thresholds, spell reflect opportunities.
- Flux and SlyRotate both provide useful Shield Slam/Revenge/HS priority baselines.

## S+ Completion Addendum

Role: **Tank**.

### Role Summary

Shield tank using Shield Slam, Revenge, Devastate/Sunder, Shield Block, taunts, and stance-aware control.

### Talent Builds and Variants

Shield Slam, Devastate, One-Handed Weapon Specialization, Defiance, Anticipation, Last Stand, Improved Shield Block.

### Core Stats and Caps

Defense/crit immunity, crush avoidance plan, stamina, armor, block value, hit/expertise for threat, resist sets.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Demoralizing Shout | 1160, 6190, 11554, 11555, 11556, 25202, 25203 | Fury | conditional |
| Devastate | 20243, 30016, 30022 | Protection | core |
| Heroic Strike | 78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 29707, 30324 | Arms | core |
| Revenge | 6572, 6574, 7379, 11600, 11601, 25269, 25288, 30357 | Protection | core |
| Shield Block | 2565 | Protection | conditional |
| Shield Slam | 23922, 23923, 23924, 23925, 25258, 30356 | Protection | core |
| Shield Wall | 871 | Protection | utility |
| Sunder Armor | 7386, 7405, 8380, 11596, 11597, 25225 | Protection | conditional |
| Taunt | 355 | Protection | core |
| Thunder Clap | 6343, 8198, 8204, 8205, 11580, 11581, 25264 | Arms | conditional |

### Single-Target Priority

1. Open with Shield Slam or ranged pull by encounter.
2. Keep Shield Block active against crush-capable bosses.
3. Use Shield Slam on cooldown.
4. Use Revenge on cooldown.
5. Use Devastate/Sunder to maintain armor reduction and fill.
6. Queue Heroic Strike only with excess rage.

### Multi-Target and AoE Matrix

- 2 targets: tab Devastate/Sunder and Revenge/Shield Slam skull.
- 3 targets: Thunder Clap/Demoralizing Shout, tab target, Cleave if rage permits.
- 4+ targets: use Challenging Shout/recovery tools only when needed; call for CC/Misdirection.
- Caster packs: line-of-sight pull and Shield Bash/Pummel assignments.
- CC packs: face mobs away and avoid Cleave/Thunder Clap near CC if tight.

## S+ Tanking Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Pull/open | Establish position and snap threat before DPS burst | Mobs faced safely and tank lead established |
| Boss swing/spike soon | Activate mitigation or hold resource for active defense | Spike passed |
| Add spawn | Use taunt/snap threat/CC call before returning to boss cycle | Adds controlled |
| DPS near threat | Prioritize snap-threat buttons and call throttle | Threat lead restored |
| Low resource | Stop dumps and preserve taunt/mitigation resource | Resource floor restored |

### Cooldown Usage

Shield Wall/Last Stand for planned spikes; trinkets before crushing/magic windows; potions/stones based on healer load.

### Resource Management

Maintain rage for Shield Block and taunt recovery; do not dump HS before burst phases.

### Threat Management

Shield Slam/Revenge are snap threat; Devastate/Sunder for sustained; taunt swaps require threat lead awareness.

### Utility, Interrupts, and Dispels

Shouts, interrupts, Disarm, Concussion Blow, Spell Reflection if available in target rules, stance dancing, emergency mobility.

### PvP Playstyle

Uptime and rage are everything. Hamstring, Intercept, Pummel, Disarm, stance utility, and healer coordination decide whether pressure sticks.

### Consumables

- Fortification/survival flask or armor/stamina elixirs by encounter.
- Stamina food or threat food by farm/progression.
- Ironshield/health/mana potion depending class and damage profile.
- Resistance consumables when the encounter demands it.
- Weapon oil/stone/imbue only if compatible with threat model.

### Gear and Set Pieces

Use `Warrior/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

### Encounter and Mob Modifiers

- Plan pull path, line of sight, first global, and taunt recovery before combat.
- Face cleaves/breaths away from raid.
- Maintain mitigation debuffs and active defenses during boss swing windows.
- Use cooldowns before predictable spikes, not after lethal damage lands.
- Call for CC/Misdirection when packs exceed stable AoE threat.

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
| Shield Slam [30356] on cooldown | Wasted GCD | Track SS cooldown; queue Revenge [25269] if SS > 1.5s | `ss_cd`, `gcd_remains` | Wowhead |
| Shield Block [2565] expiry | Crush/crit risk | Re-cast before expiry; track charges | `shield_block_charges`, `shield_block_remains` | Icy Veins |
| Revenge [25269] proc miss | Wasted reaction window | Track proc; queue immediately after dodge/block/parry | `revenge_proc_active` | Wowhead |
| Sunder Armor [25225] stack drop | Lost armor debuff | Rebuild stack immediately; prioritize over Devastate [30016] | `sunder_stacks` | Icy Veins |
| Rage cap > 100 | Lost rage generation | Dump with Heroic Strike [29707] or Cleave [25231] | `rage`, `rage_cap` | Wowhead |
| Taunt [355] resist | Lost threat on target | Use Challenging Shout [1161] backup; call for MD [34477] | `taunt_resist`, `challenging_shout_cd` | Common |
| PvP: Shield Bash [29704] on wrong school | Wrong lockout | Check target casting school first | `target_casting_school` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Moroes | ADD-WAVE | Gouge = threat drop; save taunt for gouge end | `moroes_gouge_active` | Wowhead |
| Karazhan | Maiden | SILENCE | Repentance = silence; pre-shield | `maiden_repentance_casting` | Icy Veins |
| Gruul | High King | TANK-SWAP | Council adds = multi-tank; assign targets | `add_count > 2` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter + Growth = massive physical; cooldown rotation | `gruul_growth_stacks > 12` | Icy Veins |
| SSC | Hydross | TANK-SWAP | Resist set transition = tank swap required | `hydross_phase_transition` | Wowhead |
| SSC | Leotheras | TANK-SWAP | Demon phase = threat wipe; rebuild threat | `leotheras_demon_phase` | Icy Veins |
| Black Temple | Najentus | ADD-WAVE | Spine + shield adds; pick up adds | `najentus_spine_active` | Icy Veins |
| Black Temple | Gurtogg | SURVIVAL-MODIFIER | Fel Acid [40508] stacking = tank survival check | `fel_acid_stacks > 5` | Wowhead |
| Black Temple | Illidan | TANK-SWAP | 5-phase transitions; Demon Form = threat wipe | `illidan_phase == demon` | Icy Veins |
| Sunwell | M'uru | ADD-WAVE | Strict threat on adds + boss; no over-aggro | `add_threat_ratio > 0.9` | Wowhead |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop threat gen and move | `kiljaeden_darkness_casting` | Icy Veins |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Warrior Protection | Target | Sunder Armor [25225] | 25225 | Major armor debuff | Maintain 5-stack | Wago DB2 |
| Warrior Protection | Target | Thunder Clap [25264] | 25264 | -AP + slow debuff | Maintain on boss | Icy Veins |
| Warrior Protection | Target | Demoralizing Shout [25203] | 25203 | -AP debuff | Maintain on boss | Wowhead |
| Warrior Protection | Raid | Commanding Shout [469] | 469 | +HP for raid | Maintain if assigned | Wowhead |
| Paladin Blessing | Warrior Protection | Blessing of Kings [20217] | 20217 | +stats = more HP/threat | Apply to tank | Icy Veins |
| Shaman Enhancement | Warrior Protection | Windfury Totem [25505] | 25505 | +AP proc = more threat | When in melee group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Threat Efficiency**

| Spell [ID] | Base threat | AP coefficient | Rage cost | GCD | Threat/Rage | Threat/GCD | Notes |
|---|---|---|---|---|---|---|---|
| Shield Slam [30356] | 800 | 0.10 | 20 | 1.5 | 40.0 | 533 | Core threat |
| Revenge [25269] | 600 | 0.10 | 5 | 1.5 | 120.0 | 400 | Proc-dependent |
| Sunder Armor [25225] | 500 | 0 | 15 | 1.5 | 33.3 | 333 | Debuff + threat |
| Devastate [30016] | 400 | 0.05 | 15 | 1.5 | 26.7 | 267 | Sunder replacement |
| Heroic Strike [29707] | 300 | 0 | 15 | 0 | 20.0 | 0 | Rage dump |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Rage < 20 | No Shield Slam; Sunder [25225] only | Wait for rage | None — time-based | `rage`, `ss_rage` |
| Rage > 80 | Rage cap risk | Heroic Strike [29707] dump | None — dump excess | `rage`, `rage_cap` |
| Shield Block charges 0 | Crush risk | Re-cast Shield Block [2565] | None — maintain uptime | `shield_block_charges` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Shield Slam priority | SS is #1 on CD | Often delays SS for Revenge | LIKELY BUG | Threat loss | Add `ss_cd == 0` priority | Wowhead |
| Shield Block uptime | Maintain 100% uptime | Often let drop during heavy damage | LIKELY BUG | Crush/crit risk | Add `remains < 2` refresh | Icy Veins |
| Sunder stack maintenance | Maintain 5-stack always | Often let drop to 2-3 | LIKELY BUG | Lost armor debuff | Add `sunder_stacks < 5` refresh | Wowhead |
| Revenge reaction | Queue immediately on proc | Often delayed >1s | LIKELY BUG | Lost proc window | Add `revenge_proc → immediate` | Icy Veins |
| Commanding Shout [469] | Valid TBC | May attempt to cast if not learned | Use only if learned/assigned; otherwise Battle Shout [25289] | Wago DB2 |

**Prioritized fix backlog:**
1. Shield Block uptime — survival critical
2. Shield Slam priority — threat generation
3. Sunder stack maintenance — raid armor debuff
4. Commanding Shout [469] — valid TBC; maintain if assigned by raid lead

[NEW FINDING] Warrior Protection Shield Block [2565] must maintain 100% uptime; re-cast when < 2s remains to prevent crush vulnerability.
[DB2/WOWHEAD VETTED 2026-05-18] Commanding Shout [469] is a valid level 68 Warrior spell in the local `wow_anniversary` DB2; DB2 effect base is 1079 and Wowhead/TBC databases describe a party max-health increase of about 1080 within 20 yards. Gate on learned spell and raid assignment.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Warrior Protection research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
| Boss/add threat is not secure | Use the highest-priority threat action from the single-target or AoE table | Threat is stable or a survival emergency appears |
| Lethal tank damage is predicted | Use defensive or mitigation action from the tank decision table | Damage window ends or defensive is active |
| Loose enemy targets an ally | Taunt, stun, reposition, or pickup using documented utility | Enemy is controlled, taunted, or returned to tank target |
| Multi-target pack is active | Use documented AoE threat only while CC and resource gates pass | Pack count drops, CC risk appears, or resource floor is reached |
| Resource floor is reached | Follow the resource management section before filler threat | Resource recovers or survival/threat emergency overrides |
| Encounter/PvP modifier is active | Apply modifier-specific positioning, interrupt, or defensive logic | Modifier expires or higher-priority survival action appears |

### Role State Inputs

| State input | Required use | Guardrail |
|---|---|---|
| `primary_target`, `target_count`, `add_spawn_state` | Choose single-target, cleave, or pickup threat actions | Do not use AoE threat when it breaks CC or wastes resource below the floor |
| `threat_table`, `focus_target`, `loose_enemy` | Taunt, swap, or stabilize threat according to the tank table | Do not taunt immune targets without a fallback action |
| `incoming_damage`, `mitigation_state`, `defensive_cds` | Trigger defensives and active mitigation from the survival table | Do not overlap major defensives unless lethal damage is predicted |
| `resource_pct`, `resource_income`, `gcd_state` | Gate threat and survival abilities by the resource table | Do not spend resource on filler when mitigation or taunt is required |
| `position_state`, `range_los_map`, `movement_state` | Keep mobs positioned for raid safety and uptime | Do not chase optional targets when boss positioning is unsafe |
| `utility_interrupt_targets`, `dangerous_casts` | Run interrupts, dispels, and encounter utility before filler threat | Do not interrupt low-value casts when a dangerous cast is imminent |

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
