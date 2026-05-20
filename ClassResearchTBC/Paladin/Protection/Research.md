# Protection Paladin Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Protection Paladin, Wowhead Protection Paladin talents, Flux Paladin research, Sonah Protection, SlyRotate Paladin.

## Role

Best-in-class TBC AoE dungeon tank and strong raid utility tank. Threat comes from Holy damage, Consecration, Holy Shield blocks, Judgement, and Righteous Fury.

## Single Target Tanking

Priority:
1. Maintain Righteous Fury.
2. Maintain correct aura and blessing.
3. Maintain Holy Shield uptime.
4. Use Consecration when mana and threat needs allow.
5. Judge and re-seal according to plan, commonly Seal of Righteousness, Wisdom, or Vengeance by faction/build.
6. Exorcism/Holy Wrath only on Undead/Demon and if mana permits.
7. Avenger's Shield primarily on pull or ranged pickup; avoid awkward casts mid-tank unless safe.
8. Righteous Defense only when taunting mobs off allies.

## Multi Target Tanking

- Avenger's Shield pull, Consecration, Holy Shield, Retribution Aura, tab Judgement/seal hits.
- Seal/Judgement of Wisdom can sustain mana on large packs.
- Position mobs inside Consecration; avoid breaking CC.

## Defensive Play

- Holy Shield is rotational mitigation and threat.
- Divine Protection/Divine Shield/BoP/LoH all interact with Forbearance.
- Ironshield Potion and defensive trinkets for physical burst.

## PvP

- Prot PvP is niche: control, survivability, Avenger's Shield daze, Hammer of Justice, off-healing, utility blessings.
- Avoid treating raid tank rotation as PvP logic.

## Consumables, Gear, Sets

- Uncrushable/avoidance/block goals where relevant, stamina, spell damage for threat, defense.
- Flask of Fortification or elixirs, Ironshield Potion, stamina food.
- Tier bonuses affecting Holy Shield, Consecration, or Avenger's Shield must be verified.

## Automation Notes

- Track Righteous Fury, Holy Shield charges/remains, Consecration CD, mana, Forbearance, target count, taunt need, CC proximity.
- Flux has strong Prot mana fallback notes; SlyRotate confirms compact Holy Shield/Judgement/Consecration priority.

## S+ Completion Addendum

Role: **Tank**.

### Role Summary

AoE threat tank using Righteous Fury, Consecration, Holy Shield, seals/judgements, and block-based mitigation.

### Talent Builds and Variants

Holy Shield, Avenger's Shield, Ardent Defender, Combat Expertise, One-Handed Weapon Specialization, Improved Righteous Fury.

### Core Stats and Caps

Uncrushable/defense plan, stamina, spell damage for threat, block value/avoidance, armor, resist sets.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Avenger's Shield | 31935, 32699, 32700 | Protection | conditional |
| Blessing of Protection | 1022, 5599, 10278 | Protection | conditional |
| Consecration | 20116, 20922, 20923, 20924, 26573, 27173 | Holy | core |
| Holy Shield | 20925, 20927, 20928, 27179 | Protection | core |
| Judgement | 20271 | Retribution | core |
| Righteous Defense | 31789 | Protection | conditional |
| Righteous Fury | 25780, 25781 | Protection | core |
| Seal of Righteousness | 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 21084, 27155 | Holy | core |
| Seal of Vengeance | 31801 | Retribution | core |
| Seal of Wisdom | 20166, 20356, 20357, 27166 | Holy | core |

### Single-Target Priority

1. Ensure Righteous Fury is active.
2. Open with Avenger's Shield when safe for CC/pathing.
3. Keep Holy Shield active for mitigation and threat.
4. Keep Consecration down when mana/threat allow.
5. Judge and reseal according to threat/mana assignment.
6. Use Exorcism/Holy Wrath only on valid demon/undead targets.

### Multi-Target and AoE Matrix

- 2 targets: Consecration plus tab Judgement/seal swings.
- 3 targets: Avenger's Shield pull, Consecration, Holy Shield, tab target.
- 4+ targets: Consecration is primary threat; call for CC if mana or healer load is unstable.
- Caster packs: line-of-sight pull; Avenger's Shield can break CC if careless.
- CC packs: position Consecration away from controlled mobs.

## S+ Tanking Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Pull/open | Establish position and snap threat before DPS burst | Mobs faced safely and tank lead established |
| Boss swing/spike soon | Activate mitigation or hold resource for active defense | Spike passed |
| Add spawn | Use taunt/snap threat/CC call before returning to boss cycle | Adds controlled |
| DPS near threat | Prioritize snap-threat buttons and call throttle | Threat lead restored |
| Low resource | Stop dumps and preserve taunt/mitigation resource | Resource floor restored |

### Cooldown Usage

Use trinkets/nightmare seeds/healthstones for predictable crush or magic bursts; Divine Shield cancelaura only when intentionally dropping debuffs.

### Resource Management

Mana depends on incoming heals and Spiritual Attunement; avoid overgearing avoidance so hard that mana collapses on trash.

### Threat Management

Front-load Consecration/Holy Shield and spell-damage trinkets; throttle DPS until mobs are in Consecration.

### Utility, Interrupts, and Dispels

Blessings, Cleanse, Righteous Defense, taunt recovery, stuns, auras, BoP/Freedom/Sacrifice, Exorcism on demons/undead.

### PvP Playstyle

Use blessings, Cleanse, bubble, Freedom, BoP, auras, stun, and judgement pressure. Ret relies on burst and dispel support; Holy relies on efficient casting and defensive cooldowns.

### Consumables

- Fortification/survival flask or armor/stamina elixirs by encounter.
- Stamina food or threat food by farm/progression.
- Ironshield/health/mana potion depending class and damage profile.
- Resistance consumables when the encounter demands it.
- Weapon oil/stone/imbue only if compatible with threat model.

### Gear and Set Pieces

Use `Paladin/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Holy Shield [27179] expiry | Block loss = spike damage | Re-cast immediately after expiry, before next swing | `holy_shield_remains`, `boss_swing_timer` | Wowhead |
| Consecration [27173] on CC pack | Breaks crowd control | Check `cc_nearby` before casting; hold if any CC active | `cc_active_nearby`, `consecration_ticking` | Icy Veins |
| Avenger's Shield [32699] pull miss | No initial threat on pack | Taunt primary target, use Hand of Reckoning [62124] backup | `avengers_shield_hit`, `target_threat` | Common |
| Mana floor < 20% | Cannot maintain Holy Shield + Consecration | Drop Consecration, keep Holy Shield only; Judge Wisdom | `mana_pct`, `consecration_ticking` | Wowhead |
| Forced movement (boss kiting) | Consecration placement lost | Pre-place Consecration on path; use instant threat (Judge, HS) | `movement_active`, `consecration_pos` | Icy Veins |
| Shield Block value < boss hit | Crush/crit taken | Pop Divine Protection [498] before predictable burst | `block_value`, `boss_damage_next` | Wowhead |
| PvP: Repentance [20066] on healer | Healer CC'd | Cleanse if possible; otherwise bubble and recover | `repentance_active`, `cleanse_cd` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Moroes | ADD-WAVE | Gouge = threat drop; save taunt for gouge end | `moroes_gouge_active` | Wowhead |
| Karazhan | Maiden | SILENCE | Repentance = silence window; pre-shield | `maiden_repentance_casting` | Icy Veins |
| Gruul | High King | TANK-SWAP | Council adds = multi-tank; assign targets | `add_count > 2` | Wowhead |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter + Growth = massive physical; cooldown rotation | `gruul_growth_stacks > 12` | Icy Veins |
| Magtheridon | Channelers | INTERRUPT | Shadow Bolt Volley [30510] must be interrupted | `channeler_casting_volley` | Wowhead |
| SSC | Hydross | TANK-SWAP | Resist set transition = tank swap required | `hydross_phase_transition` | Icy Veins |
| SSC | Leotheras | TANK-SWAP | Demon phase = threat wipe; rebuild threat | `leotheras_demon_phase` | Wowhead |
| Black Temple | Najentus | ADD-WAVE | Spine + shield adds; pick up adds | `najentus_spine_active` | Icy Veins |
| Black Temple | Gurtogg | SURVIVAL-MODIFIER | Fel Acid [40508] stacking = tank survival check | `fel_acid_stacks > 5` | Wowhead |
| Black Temple | Illidan | TANK-SWAP | 5-phase transitions; Demon Form = threat wipe | `illidan_phase == demon` | Icy Veins |
| Sunwell | M'uru | ADD-WAVE | Strict threat on adds + boss; no over-aggro | `add_threat_ratio > 0.9` | Wowhead |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop threat gen and move | `kiljaeden_darkness_casting` | Icy Veins |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Paladin Protection | Raid | Blessing of Sanctuary [27169] | 27169 | Damage reduction + rage/mana on block | Apply to all tanks | Wago DB2 |
| Paladin Protection | Raid | Judgement of Light [27163] | 27163 | Heal proc for melee | Judge after threat stable | Icy Veins |
| Paladin Protection | Raid | Judgement of Wisdom [27164] | 27164 | Mana return for attackers | Judge when raid mana < 60% | Wowhead |
| Paladin Protection | Healers | Salvation handoff | N/A | Hand of Salvation [1038] on over-aggro DPS | `target_threat_pct > 90` | Common |
| Warrior Protection | Paladin Protection | Sunder Armor [25225] | 25225 | Major armor debuff; Prot Paladin can skip if Warrior tank | `target_has_sunder` | Wowhead |
| Shaman Enhancement | Paladin Protection | Windfury Totem [25505] | 25505 | Threat generation boost; careful with aggro | `windfury_active` | Icy Veins |

### Angle 4: Resource Efficiency Tables

**Part A — Threat Efficiency**

| Spell [ID] | Base threat | SP coefficient | Mana cost | GCD | Threat/Mana | Threat/GCD | Notes |
|---|---|---|---|---|---|---|---|
| Holy Shield [27179] | 400 | 0.05 | 280 | 1.5 | 1.43 | 267 | Core mitigation + threat |
| Consecration [27173] | 800 | 0.12 | 660 | 1.5 | 1.21 | 533 | AoE threat |
| Avenger's Shield [32699] | 1000 | 0.15 | 620 | 1.5 | 1.61 | 667 | Ranged pull threat |
| Judgement [20271] | 500 | 0.10 | 180 | 1.5 | 2.78 | 333 | Instant, seal-dependent |
| Seal of Righteousness [27167] | 200 | 0.08 | 0 | 0 | ∞ | 0 | Passive threat |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Drop Consecration [27173], keep Holy Shield [27179] | Judge Wisdom [27164] | Potion only; do not use non-TBC Paladin mana-return mechanics | `mana_pct`, `judge_cd` |
| Mana < 15% | Holy Shield [27179] only | All other spells forbidden | Potion, wait for external mana | `mana_pct`, `potion_cd` |
| Block value < threshold | Crush risk | Divine Protection [498] | Trinket block value | `block_value`, `boss_damage_next` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Holy Shield uptime | Re-cast on expiry, never let drop | Often macro'd with other spells causing gaps | LIKELY BUG | Crush/crit spike | Separate HS re-cast priority | Wowhead |
| Consecration on CC | Check cc_nearby before cast | No CC awareness; breaks sheep/sap | LIKELY BUG | Wipe from broken CC | Add `cc_active` state check | Icy Veins |
| Avenger's Shield pull | Pull with AS, taunt backup | AS only, no taunt backup on miss | MISSING FEATURE | Add aggro on healer | Add `shield_miss → taunt` chain | Common |
| Seal choice | Righteousness for threat, Vengeance for damage | Often wrong seal for role | INTENTIONAL CHOICE | Suboptimal threat | Role-gate seal selection | Wowhead |
| Blessing assignment | Sanctuary on tanks, Kings on others | Often blanket Kings | MISSING FEATURE | Reduced tank mitigation | Add `target_role` check | S+ research |

**Prioritized fix backlog:**
1. Holy Shield uptime guarantee — survival critical
2. CC awareness on Consecration — wipe prevention
3. Blessing assignment by role — tank mitigation
4. Seal role-gating — threat optimization

[NEW FINDING] Paladin Protection Consecration must check cc_nearby before cast to prevent broken crowd control.
[TBC VETTED 2026-05-18] Paladin Protection mana recovery must stay limited to TBC-era Judgement/Seal of Wisdom, Blessing of Wisdom, consumables, Spiritual Attunement from actual healing taken, and encounter-supported sources; do not add Divine Plea or modern mana tools.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Paladin Protection research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
