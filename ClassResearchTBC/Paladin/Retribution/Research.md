# Retribution Paladin Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Retribution Paladin, Wowhead Retribution Paladin talents, Warcraft Tavern seals guide, Flux Paladin research, Sonah Ret, SlyRotate Paladin.

## Role

Melee support DPS with Sanctity Aura, Judgement support, Crusader Strike refresh behavior, and seal twisting. Personal DPS depends heavily on swing timing and seal management.

## Single Target

Priority without twist:
1. Maintain chosen DPS seal, usually Seal of Blood or Seal of the Martyr where available.
2. Judgement when it will not leave you seal-less at a bad time.
3. Crusader Strike on cooldown.
4. Hammer of Wrath below 20%.
5. Exorcism versus Undead/Demon if mana allows.
6. Consecration only with enough mana and if it will tick.
7. Maintain Vengeance stacks passively through crits.

## Seal Twisting

- Twist from Seal of Command or Righteousness into Seal of Blood/Martyr near swing impact to gain two seal effects on one swing.
- Flux notes a roughly 0.4s pre-swing timing model; use current client/server behavior as final truth.
- Use Seal of Command Rank 1 for mana saving if the proc behavior is verified.
- Judgement is off-GCD in TBC, but it consumes active seal and must be coordinated.
- Low mana fallback should drop twisting and preserve a simple seal/Judgement/Crusader Strike loop.

## Multi Target

- Consecration if mana allows and targets stay in it.
- Continue priority target seal/Judgement/Crusader Strike.
- Engineering sappers can be meaningful in burst AoE.

## PvP

- Burst through seal/Judgement, Crusader Strike, Avenging Wrath, Hammer of Justice, Repentance if talented.
- Blessing of Freedom/Sacrifice/Protection and Cleanse are often more important than PvE DPS priority.
- Avenging Wrath causes Forbearance; using it removes emergency bubble options for the Forbearance window.

## Consumables, Gear, Sets

- Strength/AP, hit, crit, expertise/weapon skill where relevant, spell damage has secondary value through Holy damage.
- Flask of Relentless Assault, Haste Potion, Super Sapper Charge, mana tools.
- Weapon speed matters for twisting; slow two-hander is typical.

## Automation Notes

- Requires swing timer, active seal state, Judgement CD, GCD, Crusader Strike CD, faction seal availability, mana, Forbearance, Avenging Wrath.
- Sonah has a practical seal-twist toggle; Flux has the best state-machine notes.

## S+ Completion Addendum

Role: **DPS**.

### Role Summary

Melee support DPS using seal/judgement cycles, Crusader Strike, Sanctity/raid buffs, and TBC seal-twisting where supported.

### Talent Builds and Variants

Crusader Strike, Sanctity Aura, Vengeance, Two-Handed Weapon Specialization, Improved Seal of the Crusader, Precision.

### Core Stats and Caps

Hit to cap, expertise where available, strength, crit, attack power, weapon damage/speed, intellect only for mana comfort.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Avenging Wrath | 31884 | Retribution | core |
| Consecration | 20116, 20922, 20923, 20924, 26573, 27173 | Holy | core |
| Crusader Strike | 35395 | Retribution | core |
| Exorcism | 879, 5614, 5615, 10312, 10313, 10314, 27138 | Holy | conditional |
| Hammer of Wrath | 24239, 24274, 24275, 27180 | Holy | conditional |
| Judgement | 20271 | Retribution | core |
| Seal of Blood | 31892, 31893 | Retribution | core |
| Seal of Command | 20375, 20915, 20918, 20919, 20920, 27170 | Retribution | core |
| Seal of the Martyr | 348700, 348701 | Retribution | core |

### Single-Target Priority

1. Maintain assigned judgement if raid strategy requires it.
2. Use Crusader Strike on cooldown to refresh judgements and deal damage.
3. Use Judgement on cooldown when mana and seal cycle allow.
4. Use Seal of Blood/Martyr where available for damage; Seal of Command is the twist partner/alternative depending faction/rules.
5. Use Consecration only when mana and threat allow.
6. Use Hammer of Wrath in execute range.

### Multi-Target and AoE Matrix

- 2 targets: normal priority with Consecration if both live and threat is safe.
- 3 targets: Consecration gains value; avoid breaking CC.
- 4+ targets: Consecration plus single-target priority skull, but mana becomes the limiter.
- Short-lived adds: Judgement/Crusader Strike priority add.
- CC packs: no Consecration near controlled mobs.

## S+ DPS Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Normal uptime | Follow single-target priority | Higher-priority condition appears |
| High threat | Stop burst/cleave and use threat drop if available | Tank lead safe |
| Movement | Use instant, DoT refresh, ranged, or utility actions | Stationary again |
| Priority add | Swap if add threatens wipe/objective/healer | Add dead or controlled |
| Low resource | Enter conserve priority | Resource floor restored or burn phase begins |

### Cooldown Usage

Use Avenging Wrath/trinkets with Bloodlust/Heroism and stable threat; delay if a seal twist window or judgement assignment would be disrupted.

### Resource Management

Seal twisting is timing-sensitive: apply the outgoing seal before swing resolution, then restore the primary seal. Track swing timer and latency.

### Threat Management

Righteous Fury must be off. Delay wings/trinkets if tank lead is weak.

### Utility, Interrupts, and Dispels

Blessings, Cleanse, auras, Hammer of Justice, Repentance if talented, BoP/Freedom/Sacrifice, emergency off-healing.

### PvP Playstyle

Use blessings, Cleanse, bubble, Freedom, BoP, auras, stun, and judgement pressure. Ret relies on burst and dispel support; Holy relies on efficient casting and defensive cooldowns.

### Consumables

- Flask or battle/guardian elixir by spec scaling.
- Best stat food for primary damage stat.
- Haste/destruction/mana potion by class and fight length.
- Drums if leatherworking and group plan uses them.
- Weapon oil/stone/poison/imbue only if it does not conflict with class mechanics.

### Gear and Set Pieces

Use `Paladin/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Seal of Blood [31892/31893] / Seal of the Martyr [348700/348701] off before swing | Lost seal damage | Re-cast seal immediately; do not cast other GCDs | `seal_remains`, `swing_timer` | Wowhead |
| Seal twist too early | Lost twist damage window | Wait for swing timer > 0.2s before twist | `swing_timer`, `seal_active` | Warcraft Tavern |
| Judgement on wrong seal | Wrong debuff applied | Check seal active before judging; re-cast correct seal | `active_seal_id` | Icy Veins |
| Avenging Wrath [31884] during Forbearance [25771] | Cannot bubble after AW | Track Forbearance; delay AW if survival needed | `forbearance_remains`, `aw_cd` | Common |
| Crusader Strike [35395] on cooldown | Wasted GCD | Track CS cooldown; queue filler if CS > 1.5s | `cs_cd`, `gcd_remains` | Wowhead |
| Exorcism [27138] on non-undead | Wasted mana | Check target type before casting | `target_is_undead` | Wago DB2 |
| PvP: Divine Shield [642] during DoT | DoT ticks bubble-lock | Cleanse DoTs before bubbling; use Hand of Sacrifice [6940] | `dot_count`, `bubble_cd` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Attumen | MOVEMENT | Mounted phase = movement; instant spells | `attumen_mounted` | Wowhead |
| Karazhan | Curator | MANA-DRAIN | Evocation = burn phase; pop all CDs | `curator_evocation` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = position-based; stay max melee range | `gruul_shatter_timer` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; stop CS during Spout | `lurker_spout_active` | Icy Veins |
| SSC | Leotheras | TANK-SWAP | Demon phase = threat wipe; hold CDs | `leotheras_phase == demon` | Wowhead |
| TK | Al'ar | MOVEMENT | Phoenix adds = movement; seal twist harder | `alar_phoenix_active` | Icy Veins |
| TK | Void Reaver | ARCANE-ORB | Arcane Orb [34942] = move out; stop melee | `void_orb_nearby` | Wowhead |
| Black Temple | Supremus | KITE-PHASE | Volcano = move; save CDs for boss phase | `supremus_volcano_active` | Icy Veins |
| Black Temple | Shahraz | FATAL-ATTRACTION | Spread = stop melee, ranged Judge only | `fatal_attraction_active` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = no conserve, burn all CDs | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Eredar Twins | TARGET-SWITCH | Kill order changes = retarget priority | `twin_target_priority` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Paladin Retribution | Raid | Judgement of Wisdom [27164] | 27164 | Mana return for all attackers | Judge after tank threat stable | Icy Veins |
| Paladin Retribution | Raid | Judgement of Light [27163] | 27163 | Heal proc for melee | When healers are mana-starved | Wowhead |
| Paladin Retribution | Melee group | Sanctity Aura [31869] | 31869 | +10% Holy damage | Always active in melee group | Wago DB2 |
| Paladin Retribution | Melee group | Improved Blessing of Might [25291] | 25291 | +AP for melee | Apply to all physical DPS | Wago DB2 |
| Shaman Enhancement | Paladin Retribution | Windfury Totem [25505] | 25505 | +AP proc = more seal damage | When in melee group | Icy Veins |
| Warrior Arms | Paladin Retribution | Battle Shout [25289] | 25289 | +AP for seal scaling | When in same group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base damage | AP coefficient | Mana cost | GCD | DPM | DPG | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Crusader Strike [35395] | 110% weapon | 0 | 236 | 1.5 | 4.7 | 733 | >3s | Primary strike |
| Judgement of Blood [31892] | 27% weapon | 0 | 168 | 1.5 | 3.6 | 540 | >3s | Seal judgement |
| Seal of Blood [31892] | 35% weapon | 0 | 0 | 0 | ∞ | 0 | Any | Passive seal |
| Exorcism [27138] | 800 | 0.15 | 325 | 1.5 | 2.5 | 533 | >3s | Undead/demon only |
| Avenging Wrath [31884] | +20% all damage | N/A | 0 | 0 | +20% | +20% | Burst phase | 20s duration |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 20% | Seal twist only, no Exorcism | Judge Wisdom [27164] | Potion | `mana_pct`, `judge_cd` |
| Mana < 10% | Seal only, no Judgement | All GCDs forbidden except seal refresh | Potion, wait for VT mana | `mana_pct`, `potion_cd` |
| Swing timer < 0.3s | Twist window closing | Hold twist, refresh next swing | None — wait for next swing | `swing_timer` |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Seal twisting | Twist SoB → SoC → SoB on every swing | Often twists at wrong timing (too early/late) | LIKELY BUG | Lost seal procs | Add swing timer check >0.2s | Warcraft Tavern |
| Crusader Strike priority | CS is #1 filler on CD | Often delays CS for Judgement | LIKELY BUG | DPS loss | Prioritize CS > Judgement | Wowhead |
| Faction seal gating | SoB [31892/31893] Horde, SoM [348700/348701] Alliance | Often hardcoded to one seal | LIKELY BUG | Wrong seal for faction | Add `player_faction` check | Wago DB2 |
| Exorcism usage | Only on undead/demon targets | Casts on all targets | LIKELY BUG | Mana waste, no damage | Add `target_type` check | Wago DB2 |
| Avenging Wrath timing | Use at burst phases, not on pull | Often used on pull with heroism | INTENTIONAL CHOICE | May overlap with heroism | Stagger AW from heroism | Icy Veins |

**Prioritized fix backlog:**
1. Faction seal gating — correctness critical
2. Seal twist timing — DPS impact
3. Crusader Strike priority — DPS impact
4. Exorcism target check — mana efficiency

[NEW FINDING] Paladin Retribution must faction-gate Seal of Blood [31892/31893] (Horde) vs Seal of the Martyr [348700/348701] (Alliance) in the local `wow_anniversary` DB2 snapshot.
[DB2/WOWHEAD VETTED 2026-05-18] The prior Seal of the Martyr ID used in this file is absent from local TBC DB2 and belongs to WotLK; use Seal of the Martyr [348700] for the Alliance TBC cast spell and track linked [348701] where the runtime exposes it.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Paladin Retribution research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
