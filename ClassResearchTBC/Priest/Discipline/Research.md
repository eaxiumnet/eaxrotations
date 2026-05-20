# Discipline Priest Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Priest PvP/overview, Wowhead Priest healing overview/talents, Flux Priest research, Sonah Discipline, SlyRotate Priest.

## Role

Primarily a PvP healer/support spec in TBC, with PvE utility through Power Infusion and strong defensive tools. Deep Discipline is less common as a pure PvE throughput healer than Holy.

## Healing Model

Priority:
1. Dispel Magic and Cure Disease when high-value.
2. Power Word: Shield when Weakened Soul is absent and absorb value is high.
3. Prayer of Mending on cooldown when damage will bounce.
4. Flash Heal for quick spot healing.
5. Greater Heal/Heal when safe and efficient.
6. Binding Heal when both self and ally need healing.
7. Pain Suppression as major defensive external if talented.
8. Power Infusion on assigned caster/DPS or self by plan.

## PvP

- Discipline PvP is about positioning, dispels, Mana Burn, Psychic Scream, shields, Pain Suppression, Power Infusion, and efficient fake-casting.
- Avoid predictable casts into interrupts.
- Offensive dispels can be game-winning.

## Damage/Smite Overlap

- Discipline talents can support a Smite variant through Power Infusion and cast-speed/mana tools.
- Keep this distinct from healing logic.

## Consumables, Gear, Sets

- Bonus healing, resilience/stamina for PvP, intellect, spirit/MP5.
- Primal Mooncloth and healing gear for PvE; PvP gear for arena durability.
- Mana consumables are essential in long fights.

## Automation Notes

- Track Weakened Soul, Power Infusion target policy, Pain Suppression threshold, Prayer of Mending CD, dispel priority, enemy cast/kick risk.
- Sonah/SlyRotate have useful Weakened Soul and Discipline PvP clues; Flux has broader healing strategy context.

## S+ Completion Addendum

Role: **Healer**.

### Role Summary

Utility healer/PvP support with strong mitigation tools, efficient direct heals, Power Infusion, and dispel control.

### Talent Builds and Variants

Power Infusion, Pain Suppression, Meditation, Mental Agility, Improved Power Word: Shield, Divine Spirit.

### Core Stats and Caps

Healing power, intellect, spirit/mp5, spell crit, stamina/resilience for PvP.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Abolish Disease | 552 | Holy | conditional |
| Dispel Magic | 527, 988 | Discipline | utility |
| Flash Heal | 2061, 9472, 9473, 9474, 10915, 10916, 10917, 25233, 25235 | Holy | core |
| Greater Heal | 2060, 10963, 10964, 10965, 25210, 25213, 25314 | Holy | core |
| Pain Suppression | 33206, 44416 | Discipline | conditional |
| Power Infusion | 10060 | Discipline | conditional |
| Power Word: Shield | 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218 | Discipline | core |
| Prayer of Healing | 596, 996, 10960, 10961, 25308, 25316 | Holy | core |
| Prayer of Mending | 33076 | Holy | core |
| Renew | 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25221, 25222, 25315 | Holy | core |

### Single-Target Priority

1. Shield preemptively only when Weakened Soul timing and rage/mana concerns allow.
2. Use Flash Heal for fast triage.
3. Use Greater Heal ranks for planned tank damage.
4. Maintain Renew only when the target will take continued damage.
5. Use Pain Suppression for lethal spikes or PvP kill attempts.
6. Use Power Infusion by assignment for caster burst.

### Multi-Target and AoE Matrix

- 2 targets: Flash Heal/Renew triage.
- 3 targets: Prayer of Mending and Prayer of Healing if group damage aligns.
- 4+ targets: group-based Prayer of Healing only when enough targets in that group are injured.
- Dispel waves: Dispel Magic/Abolish Disease dangerous effects before topping.
- Shield spam is not a replacement for raid healing.

## S+ Healing Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Tank taking predictable damage | Use the planned efficient heal/rank before the swing or ability lands | Tank stable above danger threshold |
| Tank spike or lethal target | Use emergency instant/cooldown path | Lethal window resolved |
| Raid-wide damage | Use group/HoT/chain tools only when enough targets will benefit | Raid out of lethal range |
| Dangerous dispel | Dispel/cleanse before filler healing | Debuff removed or lower danger than HP loss |
| Low mana | Downrank, cancel overheals, use mana tools early | Mana plan recovered |

### Cooldown Usage

Pain Suppression for tank/burst saves; Power Infusion for assigned DPS or self-throughput; Inner Focus with expensive heals.

### Resource Management

Use downranked Greater Heal/Flash Heal and preserve mana for dispels and emergencies.

### Threat Management

Avoid pre-shielding pull targets if it harms rage generation; watch healing threat on add waves.

### Utility, Interrupts, and Dispels

Dispel, disease removal, Mass Dispel if available in target rules, Fear Ward where race/version supports, Psychic Scream, Mana Burn in PvP.

### PvP Playstyle

Dispel wins games. Use shields, fears, Mana Burn, defensive dispels, offensive dispels, and LoS. Shadow pressures with DoTs and silence; healers survive through triage and control.

### Consumables

- Healing power flask or healing/spirit/mp5 elixir pair.
- Healing or mp5 food by fight length.
- Mana potion/dark rune style mana restore by ruleset.
- Drums if assigned.
- Brilliant Mana Oil where weapon imbues do not replace it.

### Gear and Set Pieces

Use `Priest/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

### Encounter and Mob Modifiers

- Pre-position and pre-cast before predictable raid damage.
- Prioritize tanks, debuffed players, then raid topping.
- Dispel lethal effects before efficient healing.
- Conserve mana during low damage and spend aggressively during scripted spikes.
- Watch healing threat on add waves.

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
| Power Word: Shield [25218] on Weakened Soul target | Cannot shield | Track Weakened Soul [6788]; use Flash Heal [25235] instead | `target_has_weakened_soul` | Wowhead |
| Pain Suppression [33206] on wrong target | Wasted CD | Use only on tank or targeted player | `target_threat_pct`, `target_role` | Icy Veins |
| Inner Focus [14751] on low-cost spell | Wasted crit guarantee | Use on Greater Heal [25314] or Prayer of Healing [25308] | `inner_focus_active`, `spell_mana_cost` | Wowhead |
| Mana floor < 20% | Cannot sustain shield spam | Drop non-tank shields; do not use Rapture [47535] because it is absent from `wow_anniversary` DB2 | `mana_pct`, `rapture_cd` | Icy Veins |
| Penance [47540] DB2 absent | Wasted GCD | Do not use; spell not in TBC | `spell_known_penance` | Wago DB2 |
| Rapture [47535] DB2 absent | Wasted state tracking | Do not use; spell not in TBC | `spell_known_rapture` | Wago DB2 |
| PvP: Mass Dispel [32375] on cooldown | Cannot break bubble | Pre-cast before Paladin bubbles | `mass_dispel_cd`, `enemy_paladin_hp` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Moroes | ADD-WAVE | Gouge = healer threat; pre-shield tank | `moroes_gouge_active` | Wowhead |
| Karazhan | Maiden | SILENCE | Repentance = silence; pre-shield | `maiden_repentance_casting` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = raid-wide; cooldown rotation | `gruul_growth_stacks > 10` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant heals | `lurker_spout_active` | Icy Veins |
| Black Temple | Reliquary | SILENCE | Phase 2 silence; pre-shield required | `reliquary_phase == 2` | Wowhead |
| Black Temple | Gurtogg | SURVIVAL-MODIFIER | Fel Acid [40508] stacking = tank spike | `fel_acid_stacks > 5` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = no conserve; spam shields | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = spread; pre-shield | `felmyst_gas_nova_casting` | Wowhead |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Priest Discipline | Target | Power Word: Shield [25218] | 25218 | Absorb + prevents pushback | Maintain on tank/caster | Wago DB2 |
| Priest Discipline | Target | Pain Suppression [33206] | 33206 | -40% damage | Emergency CD | Icy Veins |
| Priest Discipline | Target | Power Infusion [10060] | 10060 | +20% haste | Give to burst DPS | Wowhead |
| Priest Discipline | Raid | Prayer of Fortitude [25392] | 25392 | +Stamina | Pre-pull | Wago DB2 |
| Mage Arcane | Priest Discipline | Arcane Intellect [27126] | 27126 | +Intellect | Pre-pull | Icy Veins |
| Paladin Blessing | Priest Discipline | Blessing of Wisdom [27142] | 27142 | +mana regen | When in same group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base heal/absorb | SP coefficient | Mana cost | GCD | HpM | HpS | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Power Word: Shield [25218] | 1100 absorb | 0.30 | 450 | 0 | 2.4 | 0 | Any | Absorb |
| Flash Heal [25235] | 800 | 0.43 | 315 | 1.5 | 2.5 | 533 | >3s | Primary heal |
| Greater Heal [25314] | 2500 | 0.86 | 750 | 2.5 | 3.3 | 1000 | >5s | Bomb heal |
| Prayer of Mending [33076] | 800 | 0.30 | 390 | 1.5 | 2.1 | 533 | >5s | Bounce heal |
| Power Infusion [10060] | +20% haste | N/A | 0 | 0 | +20% | +20% | Burst phase | 15s duration |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Flash Heal [25235] only; no Greater Heal | Use Potion and wand auto-attack; do not use Rapture [47535] because it is absent from `wow_anniversary` DB2 | Potion | `mana_pct`, `rapture_cd` |
| Mana < 15% | Shield [25218] only; no heals | All heals forbidden | Potion, wait for external mana | `mana_pct`, `potion_cd` |
| Mana < 5% | Auto-attack + wand only | All spells forbidden | Wait for external mana | `mana_pct` |

**Part D — Downrank Table**

| Spell | Rank | Spell ID | Mana cost | Avg heal | HpM | HpS | Use case | Mana % threshold |
|---|---|---|---|---|---|---|---|---|
| Greater Heal | 7 | 25314 | 750 | 2500 | 3.3 | 1000 | Tank spike | >30% |
| Greater Heal | 5 | 25312 | 600 | 1900 | 3.2 | 760 | Conserve | 15-30% |
| Flash Heal | 9 | 25235 | 315 | 800 | 2.5 | 533 | Primary heal | <15% |
| Flash Heal | 7 | 25233 | 255 | 650 | 2.5 | 433 | Conserve | Any |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Shield on Weakened Soul | Do not shield if Weakened Soul active | Often attempts shield anyway | LIKELY BUG | Wasted GCD and mana | Add `weakened_soul` check | Wowhead |
| Pain Suppression timing | Use on tank during burst | Often used on random target | INTENTIONAL CHOICE | Wasted CD | Add `tank_burst_predicted` gate | Icy Veins |
| Power Infusion target | Give to highest DPS | Often self-cast | INTENTIONAL CHOICE | Suboptimal raid DPS | Add `target_dps` picker | Wowhead |
| Penance attempt | Spell not in TBC | May attempt to cast | TBC GUARDRAIL VIOLATION | GCD waste | Remove from rotation | Wago DB2 |
| Rapture attempt | Spell not in TBC | May attempt to track | TBC GUARDRAIL VIOLATION | State complexity | Remove tracking | Wago DB2 |

**Prioritized fix backlog:**
1. Shield Weakened Soul check — GCD efficiency
2. Power Infusion target picker — raid DPS
3. Pain Suppression timing — tank survival
4. Penance removal — TBC compliance

[NEW FINDING] Priest Discipline Power Word: Shield [25218] must check Weakened Soul [6788] before casting to avoid GCD waste.
[DB2 VETTED 2026-05-18] Penance [47540] and Rapture [47535] are absent from `wow_anniversary` SpellName and class skillline DB2; do not implement them for TBC Discipline.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Priest Discipline research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
| Lethal ally window exists | Execute the emergency path from the spec's healing decision table | Ally stable or emergency cooldown committed |
| Assigned maintenance effect missing or at documented refresh threshold | Refresh the assigned maintenance effect from the DB2-verified spell table | Effect active and above threshold |
| Dangerous debuff outranks raw HP healing | Cleanse, dispel, or pre-place utility from the Utility section | Debuff removed or HP danger becomes higher priority |
| Multi-target damage meets the matrix threshold | Use the documented group-healing action and target-selection rule | Injured count falls below threshold or resource floor is reached |
| Predictable single-target damage is incoming | Pre-cast, downrank, cancel, or complete the documented single-target heal | Damage event resolved or overheal risk becomes unacceptable |
| Mana/resource floor is reached | Enter conserve rules and use mana tools from the Resource section | Resource recovers above floor or lethal target overrides conserve |
| PvP or encounter modifier is active | Apply the matching PvP/Encounter rule before filler healing | Modifier expires or higher-priority emergency appears |

### Role State Inputs

| State input | Required use | Guardrail |
|---|---|---|
| `assigned_heal_targets` | Select tank/focus/raid targets from explicit assignment or configured fallback | Do not hard-code one unit when the current Research.md allows assignment changes |
| `lowest_ally`, `incoming_damage`, `time_to_damage` | Choose emergency, predictive, or efficient healing paths | Do not cast a slow heal when the target will die before completion |
| `injured_allies`, `cluster_score`, `range_los_map` | Enter the multi-target healing matrix only when enough allies can benefit | Do not waste group heals on low-value or unreachable targets |
| `maintenance_auras`, `charges`, `remains` | Refresh shields, HoTs, forms, stances, and assigned buffs from this document | Do not refresh early unless the document gives an early-refresh rule |
| `cleanse_targets`, `dangerous_debuffs` | Run dispel/cleanse logic before filler healing when danger is high | Do not cleanse low-value effects ahead of lethal HP recovery |
| `mana_pct`, `regen_sources`, `cooldown_state` | Apply resource and cooldown sections before throughput spam | Do not spend below the resource floor unless the target is lethal |
| `movement_state`, `cc_state`, `threat_state` | Gate hard casts, utility, and optional damage | Do not add optional damage while healing, CC, or threat checks fail |

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
