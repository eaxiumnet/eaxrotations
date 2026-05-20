# Holy Paladin Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Holy Paladin, Wowhead Holy Paladin resources, Flux Paladin research, Sonah Holy Paladin, SlyRotate Paladin.

## Role

Single-target tank healer with excellent mana efficiency, strong blessings, Cleanse utility, and emergency cooldowns. Holy Paladin lacks broad raid-healing tools compared with Priest/Shaman/Druid.

## Healing Model

Priority:
1. Cleanse poison/disease/magic when assigned and urgent.
2. Holy Shock for emergency instant healing if talented and mana allows.
3. Divine Favor before a critical Holy Light or Holy Shock.
4. Divine Illumination during heavy healing to reduce mana cost.
5. Flash of Light for efficient steady damage.
6. Holy Light for large tank damage and Light's Grace value.
7. Lay on Hands as last-resort emergency, respecting Forbearance and mana drain.
8. Maintain assigned blessing/aura.

## Damage/Utility While Healing

- Seal/Judgement of Wisdom or Light can be maintained when healing load allows and it is safe.
- Hammer of Justice can interrupt/stun if it will not disrupt encounter control.
- Blessing of Protection, Freedom, and Sacrifice are high-value utility, not rotation filler.

## PvP

- Holy Paladin PvP revolves around Cleanse, Blessing of Freedom/Sacrifice/Protection, Divine Shield, Hammer of Justice, fake casting, and durable single-target healing.
- Mana burn pressure and CC chains are major threats.

## Consumables, Gear, Sets

- Bonus healing, spell crit for Illumination, intellect, MP5, stamina for PvP.
- Flask of Mighty Restoration or elixir setup, Brilliant Mana Oil, Super Mana Potion/Dark Rune.
- Verify tier bonuses affecting Flash of Light, Holy Light, or Holy Shock before code changes.

## Automation Notes

- Track Forbearance before Divine Shield/Protection/LoH/Avenging Wrath interactions.
- Track Light's Grace, Divine Favor, Divine Illumination, target HP, incoming damage, cleanse priority, and assigned blessings.
- Flux has the best Forbearance notes; SlyRotate provides compact Holy CD rows.

## S+ Completion Addendum

Role: **Healer**.

### Role Summary

Efficient single-target healer using Flash of Light, Holy Light ranks, Illumination returns, blessings, and emergency cooldowns.

### Talent Builds and Variants

Holy Shock, Divine Illumination, Divine Favor, Illumination, Light's Grace, Holy Guidance, Spiritual Focus.

### Core Stats and Caps

Healing power, spell crit for Illumination, intellect, mp5, haste where available, stamina/resistance for survival.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Blessing of Protection | 1022, 5599, 10278 | Protection | conditional |
| Cleanse | 4987 | Holy | utility |
| Divine Favor | 20216 | Holy | conditional |
| Divine Illumination | 31842 | Holy | conditional |
| Flash of Light | 19750, 19939, 19940, 19941, 19942, 19943, 27137 | Holy | core |
| Holy Light | 635, 639, 647, 1026, 1042, 3472, 10328, 10329, 25292, 27135, 27136 | Holy | core |
| Holy Shock | 20473, 20929, 20930, 25902, 25903, 25911, 25912, 25913, 25914, 27174, 27175, 27176, 33072, 33073, 33074 | Holy | conditional |
| Judgement | 20271 | Retribution | core |
| Lay on Hands | 633, 2800, 10310, 27154 | Holy | conditional |
| Seal of Wisdom | 20166, 20356, 20357, 27166 | Holy | core |

### Single-Target Priority

1. Use Flash of Light for efficient maintenance.
2. Use Holy Light ranks for predictable tank damage.
3. Maintain Light's Grace with appropriate Holy Light cadence when heavy healing is expected.
4. Use Holy Shock for movement or emergency instant healing.
5. Use Divine Favor with Holy Shock/Holy Light for planned saves.
6. Use Lay on Hands only for lethal emergencies or assigned strategy.

### Multi-Target and AoE Matrix

- 2 injured targets: Flash of Light triage unless one target needs Holy Light.
- 3 targets: prioritize tanks and lethal debuffs; Paladin raid healing is limited.
- 4+ targets: spot heal critical targets; do not try to imitate Chain Heal/CoH coverage.
- Dispel waves: Cleanse dangerous magic/poison/disease before low-value heals.
- Do not add non-TBC healer transfer mechanics.

## S+ Healing Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Tank taking predictable damage | Use the planned efficient heal/rank before the swing or ability lands | Tank stable above danger threshold |
| Tank spike or lethal target | Use emergency instant/cooldown path | Lethal window resolved |
| Raid-wide damage | Use group/HoT/chain tools only when enough targets will benefit | Raid out of lethal range |
| Dangerous dispel | Dispel/cleanse before filler healing | Debuff removed or lower danger than HP loss |
| Low mana | Downrank, cancel overheals, use mana tools early | Mana plan recovered |

### Cooldown Usage

Divine Illumination for expensive Holy Light periods; Divine Favor for guaranteed crit save; Blessing of Protection for physical threat or bleed-free saves only.

### Resource Management

Downrank Holy Light and Flash of Light; judge/seal Wisdom only if safe and assigned.

### Threat Management

Healing threat matters on add waves; use Blessing of Protection on non-tank physical pulls and bubble carefully.

### Utility, Interrupts, and Dispels

Blessings, Cleanse, auras, Divine Shield, Blessing of Protection/Freedom/Sacrifice, stun, and judgements.

### PvP Playstyle

Use blessings, Cleanse, bubble, Freedom, BoP, auras, stun, and judgement pressure. Ret relies on burst and dispel support; Holy relies on efficient casting and defensive cooldowns.

### Consumables

- Healing power flask or healing/spirit/mp5 elixir pair.
- Healing or mp5 food by fight length.
- Mana potion/dark rune style mana restore by ruleset.
- Drums if assigned.
- Brilliant Mana Oil where weapon imbues do not replace it.

### Gear and Set Pieces

Use `Paladin/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Mana floor < 20% | Cannot sustain Flash of Light [27137] spam | Cast Divine Illumination [31842] → Judgement of Wisdom [27164] → mana potion | `mana_pct`, `divine_illumination_cd`, `judge_wisdom_uptime` | Icy Veins |
| Illumination proc during GCD | Missed mana refund from crit heal | Track proc queue; do not queue next heal until proc consumed | `illumination_proc_active`, `gcd_remains` | Wowhead |
| Blessing of Light [27144] expiry mid-cast | Reduced Holy Light [27136] throughput | Re-apply Blessing of Light [27144] before cast completes if tank target | `target_has_blessing_of_light`, `cast_remains` | Wago DB2 |
| Avenging Wrath [31884] + Divine Illumination [31842] overlap | Wasted CD synergy window | Stagger by 10s: Avenging Wrath first, then Divine Illumination at ~15s mark | `avenging_wrath_remains`, `divine_illumination_cd` | Icy Veins |
| Target dies mid-Holy Light [27136] cast | Wasted cast time and mana | Cancel cast, retarget lowest HP ally, queue Flash of Light [27137] | `target_is_alive`, `lowest_hp_ally` | Common |
| Healing threat > tank threat on add wave | Healer pull aggro | Stop casting, bubble if needed, call for Misdirection [34477] or taunt | `healer_threat_pct`, `tank_threat_lead` | Wowhead |
| PvP: Counterspell on Holy school | Locked out of all heals | Pre-cast Divine Favor [20216] before commit; use Cleanse [4987] if locked on utility | `counterspell_school`, `divine_favor_cd` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Maiden | SILENCE | Cannot cast during Repentance; pre-HoT | `boss_casting_repentance` | Wowhead |
| Karazhan | Shade of Aran | BURST-WINDOW | Arcane Explosion requires pre-shield + burst heal | `boss_arane_blast_charging` | Icy Veins |
| Karazhan | Curator | MANA-DRAIN | Evocation phase = heavy AoE; pop CDs | `curator_evocation_active` | Wowhead |
| Karazhan | Prince | MOVEMENT | Infernals force movement; instant heals preferred | `infernal_nearby_distance` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = raid-wide damage spike; cooldown rotation | `gruul_growth_stacks > 10` | Wowhead |
| Magtheridon | Magtheridon | BURST-WINDOW | Blast Nova = raid-wide burst; top off before cast | `blast_nova_casting` | Icy Veins |
| SSC | Lurker | MOVEMENT | Spout forces reposition; maintain range | `lurker_spout_active` | Wowhead |
| Black Temple | Reliquary | SILENCE | Phase 2 silence for casters; pre-HoT required | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Council | DISPEL-CLEANSE | Multiple debuffs; prioritize cleanse over heals | `council_debuff_count > 2` | Wowhead |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] on infected player | `has_parasitic_shadowfiend` | Icy Veins |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = no conserve; burn all mana into heals | `brutallus_hp_pct < 20` | Wowhead |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = stop and spread; pre-shield | `felmyst_gas_nova_casting` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Paladin Holy | Raid | Blessing of Light [27144] | 27144 | +Heal to direct heals on target | Apply to tank always | Wago DB2 |
| Paladin Holy | Raid | Blessing of Wisdom [27142] | 27142 | Mana regen for casters | Apply to all mana users | Wago DB2 |
| Paladin Holy | All healers | Judgement of Light [27163] | 27163 | Proc heal on melee attackers | Judge after tank threat established | Icy Veins |
| Paladin Holy | All mana users | Judgement of Wisdom [27164] | 27164 | Mana return on attacks | Judge when raid mana < 60% | Icy Veins |
| Paladin Holy | Warlock | Innervate replacement | N/A | Paladin cannot Innervate; assign Druid/Shaman | N/A | N/A |
| Shaman Restoration | Paladin Holy | Mana Tide Totem | 16190 | Reduces Paladin potion frequency | When `mana_pct < 30%` | Icy Veins |
| Priest Shadow | Paladin Holy | Vampiric Touch [34914] | 34914 | Paladin can Flash-spam longer | When VT uptime > 80% | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base heal | SP coefficient | Mana cost | GCD | HpM | HpS | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Flash of Light [27137] | ~800 | 1.5 | 180 | 1.5 | 4.4 | 533 | >3s | Primary spam heal |
| Holy Light [27136] | 2196-2446 | 2.5 | 840 | 2.5 | 3.0 | 1000 | >5s | Tank bomb heal |
| Holy Shock [33072] | ~900 | 1.5 | 325 | 1.5 | 2.8 | 600 | >3s | Instant, on GCD |
| Divine Favor [20216] | Crit guarantee | N/A | 0 | 0 | ∞ | N/A | Any | Only when crit needed |
| Avenging Wrath [31884] | +20% all heals | N/A | 0 | 0 | +20% | +20% | Burst phase | 20s duration |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Flash of Light [27137] only, skip Holy Light [27136] | Divine Illumination [31842] | Judgement of Wisdom [27164] + potion | `mana_pct`, `divine_illumination_cd` |
| Mana < 15% | Stop all non-tank heals | Lay on Hands [27154] | Potion + wait for VT mana | `mana_pct`, `lay_on_hands_cd` |
| Mana < 5% | Emergency Lay on Hands [27154] only | All other spells forbidden | Wait for external mana (Innervate, Mana Tide) | `mana_pct`, `external_mana_cd` |

**Part D — Downrank Table**

| Spell | Rank | Spell ID | Mana cost | Avg heal | HpM | HpS | Use case | Mana % threshold |
|---|---|---|---|---|---|---|---|---|
| Holy Light | 11 | 27136 | 840 | 2196-2446 | 2.5 | 1000 | Tank spike | >40% |
| Holy Light | 9 | 25292 | 660 | 2000 | 3.0 | 800 | Moderate tank damage | 20-40% |
| Flash of Light | 7 | 27137 | 180 | 800 | 4.4 | 533 | Primary raid heal | >15% |
| Flash of Light | 6 | 25297 | 150 | 650 | 4.3 | 433 | Conserve | <15% |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Blessing priority | BoL [27144] on tank, BoW [27142] on casters | Often hardcoded to BoW on all | LIKELY BUG | Tank survivability reduced | Check `target_role == tank` for BoL | S+ research |
| Divine Illumination timing | Use at 30% mana, not on cooldown | Often macro'd with Avenging Wrath opener | INTENTIONAL CHOICE | Wasted mana efficiency | Separate triggers: AW at burst, DI at 30% | Icy Veins |
| Judgement assignment | Holy judges Light [27163], Ret judges Wisdom [27164] | Often overlaps or misses | MISSING FEATURE | Raid mana/heal throughput lost | Add `judge_assignment` state | Wowhead |
| Flash vs Holy Light threshold | Flash primary, HL only on tank spike | HL spam when tank > 90% HP | LIKELY BUG | Mana inefficiency | Gate HL to `tank_hp < 70%` or `incoming_burst_predicted` | WoWSims |
| Cleanse automation | Auto-cleanse on priority debuffs | Manual only or no cleanse logic | MISSING FEATURE | Raid wipe from dispellable debuffs | Add `debuff_priority` queue | Icy Veins |

**Prioritized fix backlog:**
1. Cleanse automation — highest wipe prevention value
2. Blessing assignment logic — tank survival critical
3. Flash vs HL threshold — mana efficiency
4. Judgement assignment — raid sustain

**Transfer rules:**
- BoL/BoW assignment → needs Sylvanas API `target_role` check
- Cleanse priority → can adopt as-is with buff_manager
- DI timing → needs mana prediction module
- Flash/HL threshold → direct main.lua logic change

[NEW FINDING] Paladin Holy Blessing assignment should role-gate BoL vs BoW based on target role, not blanket apply.
[DB2/WOWHEAD VETTED 2026-05-18] Holy Light [27136] rank 11 has DB2 EffectBasePoints 2195, EffectDieSides 251, coefficient 0.714, and mana cost 840; Wowhead lists 2196-2446 healing. Do not hard-code 2500 as its base heal.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Paladin Holy research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
