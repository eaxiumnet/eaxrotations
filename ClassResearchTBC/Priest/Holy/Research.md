# Holy Priest Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Holy Priest, Wowhead Priest healing overview/talents, Flux Priest research, Sonah Holy, SlyRotate Priest.

## Role

Flexible PvE healer with strong single-target tools and excellent AoE healing through Circle of Healing if talented. Brings broad healing coverage and dispels.

## Healing Model

Priority:
1. Emergency: Guardian Spirit is not TBC; do not implement it. Use correct TBC tools: Power Word: Shield, Flash Heal, Binding Heal, Inner Focus, trinkets, healthstone/potion where self.
2. Prayer of Mending on likely damage targets.
3. Circle of Healing for injured groups if talented.
4. Flash Heal for urgent spot healing.
5. Greater Heal/Heal downranks for efficient planned healing.
6. Renew when target will take continued damage and mana allows.
7. Prayer of Healing for group damage when hard-cast is safe.
8. Dispel Magic/Cure Disease by assignment.

## Multi Target Healing

- Circle of Healing is the defining TBC Holy raid-healing talent.
- Prayer of Healing is group-limited and requires cast time.
- Prayer of Mending should be kept moving through predictable damage.

## PvP

- Holy is less dominant than Discipline but can heal with strong throughput.
- Positioning, Psychic Scream, dispels, and avoiding interrupts remain central.

## Consumables, Gear, Sets

- Bonus healing, spirit, MP5, intellect, stamina where needed.
- Primal Mooncloth early, healing enchants/oils, Super Mana Potion/Dark Rune.
- Check tier bonuses affecting Renew, Greater Heal, Prayer of Healing, Circle of Healing.

## Automation Notes

- Build real healer triage rather than a fixed rotation.
- Track Prayer of Mending CD, Circle of Healing availability, party health clusters, cast safety, dispel priority, mana tier.
- SlyRotate mentions Guardian Spirit, which is not TBC; keep that as a guardrail example, not an implementation target.

## S+ Completion Addendum

Role: **Healer**.

### Role Summary

Flexible raid/tank healer using downranked Greater Heal, Flash Heal triage, Renew, Prayer of Healing, Circle of Healing if talented, and Guardian Spirit is not TBC.

### Talent Builds and Variants

Circle of Healing, Spiritual Healing, Holy Concentration, Empowered Healing, Improved Renew, Surge of Light.

### Core Stats and Caps

Healing power, spirit/mp5, intellect, spell crit, haste where available.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Abolish Disease | 552 | Holy | conditional |
| Circle of Healing | 34861, 34863, 34864, 34865, 34866 | Holy | conditional |
| Dispel Magic | 527, 988 | Discipline | utility |
| Flash Heal | 2061, 9472, 9473, 9474, 10915, 10916, 10917, 25233, 25235 | Holy | core |
| Greater Heal | 2060, 10963, 10964, 10965, 25210, 25213, 25314 | Holy | core |
| Inner Focus | 14751 | Discipline | conditional |
| Lightwell | 724, 27870, 27871, 28275 | Holy | conditional |
| Prayer of Healing | 596, 996, 10960, 10961, 25308, 25316 | Holy | core |
| Prayer of Mending | 33076 | Holy | core |
| Renew | 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25221, 25222, 25315 | Holy | core |

### Single-Target Priority

1. Use Greater Heal ranks for predictable tank damage.
2. Use Flash Heal for fast triage.
3. Keep Renew on targets with continuing damage.
4. Use Prayer of Mending on cooldown when it will bounce.
5. Use Inner Focus on expensive heals.
6. Do not add Guardian Spirit; it is not TBC.

### Multi-Target and AoE Matrix

- 2 targets: Flash Heal/Renew.
- 3 targets: Circle of Healing if talented and enough targets are injured.
- 4+ targets: Prayer of Healing by group or Circle of Healing by cluster.
- Short damage pulses: pre-cast Prayer of Healing if timing is predictable.
- Dispel waves: prioritize dangerous magic/disease.

## S+ Healing Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Tank taking predictable damage | Use the planned efficient heal/rank before the swing or ability lands | Tank stable above danger threshold |
| Tank spike or lethal target | Use emergency instant/cooldown path | Lethal window resolved |
| Raid-wide damage | Use group/HoT/chain tools only when enough targets will benefit | Raid out of lethal range |
| Dangerous dispel | Dispel/cleanse before filler healing | Debuff removed or lower danger than HP loss |
| Low mana | Downrank, cancel overheals, use mana tools early | Mana plan recovered |

### Cooldown Usage

Inner Focus for mana/crit value; Lightwell only if raid behavior supports it; Divine Hymn is not TBC.

### Resource Management

Downrank aggressively; cancel casts when damage does not land.

### Threat Management

Raid heals on add waves can pull; fade early if adds spawn.

### Utility, Interrupts, and Dispels

Dispel, disease removal, Fear Ward where supported, Psychic Scream, shackle undead, Power Word: Shield in emergencies.

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
| Circle of Healing [34861] already covered by group heals | Wasted GCD | Use Prayer of Healing [25308] on injured cluster if no Circle of Healing talented; otherwise Circle of Healing [34861] as primary group heal | `spell_known_circle_of_healing`, `injured_group_count` | Wowhead |
| Guardian Spirit [47788] DB2 absent | Wasted CD | Do not use; spell not in TBC | `spell_known_guardian_spirit` | Wago DB2 |
| Lightwell [724] un-clicked or unused | Wasted preparation GCD | Pre-place if raid lead requests; otherwise skip unless raid knows to use it | `lightwell_charges`, `raid_uses_lightwell` | Wowhead |
| Mana floor < 20% | Cannot sustain CoH spam | Drop to Flash Heal [25235] + Renew [25222] | `mana_pct`, `renew_active` | Icy Veins |
| Desperate Prayer [19236] on cooldown | Lost self-heal | Track CD; use only when HP < 30% | `desperate_prayer_cd`, `hp_pct` | Wowhead |
| Spirit of Redemption [20711] during combat | Healer dies = 15s ghost heal | Continue healing during ghost; call for brez | `spirit_of_redemption_active` | Icy Veins |
| PvP: Chastise [44041] on DR target | Wasted GCD | Check DR before Chastise; use Fear Ward instead | `chastise_dr` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Moroes | ADD-WAVE | Gouge = healer threat; pre-heal tank | `moroes_gouge_active` | Wowhead |
| Karazhan | Maiden | SILENCE | Repentance = silence; pre-shield | `maiden_repentance_casting` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = raid-wide; cooldown rotation | `gruul_growth_stacks > 10` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant heals | `lurker_spout_active` | Icy Veins |
| Black Temple | Reliquary | SILENCE | Phase 2 silence; pre-HoT required | `reliquary_phase == 2` | Wowhead |
| Black Temple | Gurtogg | SURVIVAL-MODIFIER | Fel Acid [40508] stacking = tank spike | `fel_acid_stacks > 5` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = no conserve; spam heals | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = spread; pre-shield | `felmyst_gas_nova_casting` | Wowhead |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Priest Holy | Raid | Prayer of Healing [25308] | 25308 | AoE heal | When 3+ injured | Wago DB2 |
| Priest Holy | Target | Greater Heal [25314] | 25314 | Big single-target heal | Tank spike | Icy Veins |
| Priest Holy | Target | Renew [25222] | 25222 | HoT maintenance | Non-tank injured | Wowhead |
| Priest Holy | Raid | Prayer of Fortitude [25392] | 25392 | +Stamina | Pre-pull | Wago DB2 |
| Mage Arcane | Priest Holy | Arcane Intellect [27126] | 27126 | +Intellect | Pre-pull | Icy Veins |
| Paladin Blessing | Priest Holy | Blessing of Wisdom [27142] | 27142 | +mana regen | When in same group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base heal | SP coefficient | Mana cost | GCD | HpM | HpS | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Greater Heal [25314] | 2500 | 0.86 | 750 | 2.5 | 3.3 | 1000 | >5s | Tank bomb |
| Flash Heal [25235] | 800 | 0.43 | 315 | 1.5 | 2.5 | 533 | >3s | Primary heal |
| Renew [25222] | 800 | 0.20 | 410 | 1.5 | 2.0 | 533 | >15s | HoT maintenance |
| Prayer of Healing [25308] | 1200 | 0.50 | 900 | 3.0 | 1.3 | 400 | 3+ injured | AoE heal |
| Desperate Prayer [19236] | 1500 | 0.50 | 0 | 0 | ∞ | ∞ | Self emergency | Instant |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Flash Heal [25235] + Renew [25222] only | Drop Greater Heal [25314] | Potion | `mana_pct`, `potion_cd` |
| Mana < 15% | Renew [25222] only | All direct heals forbidden | Potion, wait for external mana | `mana_pct`, `potion_cd` |
| Mana < 5% | Desperate Prayer [19236] only if self | All other spells forbidden | Wait for external mana | `mana_pct` |

**Part D — Downrank Table**

| Spell | Rank | Spell ID | Mana cost | Avg heal | HpM | HpS | Use case | Mana % threshold |
|---|---|---|---|---|---|---|---|---|
| Greater Heal | 7 | 25314 | 750 | 2500 | 3.3 | 1000 | Tank spike | >30% |
| Greater Heal | 5 | 25312 | 600 | 1900 | 3.2 | 760 | Conserve | 15-30% |
| Flash Heal | 9 | 25235 | 315 | 800 | 2.5 | 533 | Primary heal | <15% |
| Renew | 12 | 25222 | 410 | 800 | 2.0 | 533 | HoT maintenance | Any |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Circle of Healing [34861] attempt without talent | Wasted GCD | Use only when Circle of Healing [34861] is learned and 3+ injured targets are in range | `spell_known_circle_of_healing`, `injured_count` | Wago DB2 |
| Guardian Spirit [47788] attempt | Spell not in TBC | Do not attempt to cast; spell not in TBC | `spell_known_guardian_spirit` | Wago DB2 |
| Lightwell [724] not pre-placed | Wasted setup GCD | Pre-place if raid lead requests; otherwise use direct healing | `lightwell_charges`, `raid_uses_lightwell` | Wago DB2 |
| Renew refresh timing | Refresh at < 3s remaining | Often refreshed early (>5s) | LIKELY BUG | Wasted HoT ticks | Add `remains < 3` check | Wowhead |
| Prayer of Healing target count | Only when 3+ injured | Often used on 1-2 targets | LIKELY BUG | Mana waste | Add `injured_count >= 3` check | Icy Veins |

**Prioritized fix backlog:**
1. Guardian Spirit [47788] removal — TBC guardrail only
2. Renew refresh timing — mana efficiency
3. Circle of Healing talent check — avoid untalented cast attempts
4. Lightwell usage coordination — raid lead assignment

[NEW FINDING] Priest Holy must not attempt to cast Guardian Spirit [47788] as it is a WotLK spell not present in TBC. Circle of Healing [34861] and Lightwell [724] are valid TBC spells.
[DB2 VETTED 2026-05-18] Guardian Spirit [47788] is absent from `wow_anniversary` SpellName and class skillline DB2. Circle of Healing [34861] and Lightwell [724] remain valid TBC spells.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Priest Holy research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
