# Restoration Druid Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Restoration Druid, Wowhead Restoration Druid talents, Flux Druid research, Sonah Restoration.

## Role

HoT-based healer with strong tank healing through Lifebloom rolling, Rejuvenation/Regrowth coverage, Swiftmend burst, Innervate, Rebirth, and strong PvP mobility/control.

## Healing Model

Priority:
1. Emergency: Nature's Swiftness plus Healing Touch, Swiftmend if HoT is present, or fast Regrowth/Healing Touch depending on risk.
2. Maintain Lifebloom stacks on assigned tank(s), usually rolling 3 stacks when assigned to tank sustain.
3. Keep Rejuvenation available on tanks or likely Swiftmend targets.
4. Use Regrowth for direct plus HoT coverage when target will keep taking damage.
5. Use Healing Touch downranks where efficient and safe.
6. Tranquility as emergency group healing only.
7. Remove Curse and Abolish Poison when dispel value beats healing.

## Multi Target Healing

- Spread Rejuvenation/Lifebloom based on incoming damage and mana.
- Swiftmend low targets with existing HoTs.
- Tranquility only when group damage and positioning justify the channel.

## PvP

- Lifebloom, Rejuvenation, Swiftmend, Cyclone, Bash, roots, travel form, and shapeshift snare breaking define the spec.
- Avoid hard-casting into interrupts unless protected by fake-cast/LoS logic.
- Cyclone can be more valuable than another heal.

## Consumables, Gear, Sets

- Bonus healing, spirit, MP5, intellect, and stamina for PvP.
- Primal Mooncloth/Windhawk-style crafted options depending on role and profession.
- Flask of Mighty Restoration or elixir setup; Super Mana Potion/Dark Rune; Brilliant Mana Oil.

## Automation Notes

- Track Lifebloom stacks/remains per assigned tank, Rejuvenation/Regrowth remains, Swiftmend eligibility, NS state, dispellable debuffs, mana tier, incoming damage.
- Sonah's Lifebloom stack setting is useful. Flux has downrank and state-tracking tables.

## S+ Completion Addendum

Role: **Healer**.

### Role Summary

HoT healer focused on Lifebloom efficiency, Rejuvenation/Regrowth coverage, Swiftmend/Nature's Swiftness saves, and Innervate planning.

### Talent Builds and Variants

Tree of Life, Swiftmend, Empowered Rejuvenation, Gift of Nature, Improved Rejuvenation, Nature's Swiftness, Subtlety.

### Core Stats and Caps

Healing power, spirit/mp5, intellect, haste where available, and enough stamina/resistance for encounter survival.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Abolish Poison | 2893 | Restoration | conditional |
| Healing Touch | 5185, 5186, 5187, 5188, 5189, 6778, 8903, 9758, 9888, 9889, 25297, 26978, 26979 | Restoration | conditional |
| Innervate | 29166 | Balance | core |
| Lifebloom | 33763 | Restoration | core |
| Nature's Swiftness | 17116 | Restoration | conditional |
| Regrowth | 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858, 26980 | Restoration | core |
| Rejuvenation | 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299, 26981, 26982 | Restoration | core |
| Remove Curse | 2782 | Restoration | utility |
| Swiftmend | 18562 | Restoration | core |
| Tranquility | 740, 8918, 9862, 9863, 26983 | Restoration | conditional |

### Single-Target Priority

1. Maintain Lifebloom stacks on assigned tanks.
2. Use Rejuvenation before predictable damage or to enable Swiftmend.
3. Use Regrowth for heavier rolling HoT coverage or Nature's Grace value.
4. Use downranked Healing Touch only where the build supports it and the cast will land.
5. Use Swiftmend/Nature's Swiftness for lethal spikes.

### Multi-Target and AoE Matrix

- 2 injured targets: Rejuvenation/Lifebloom depending on damage cadence.
- 3 targets: roll Lifebloom/Rejuvenation on assigned group if damage persists.
- 4+ targets: Tranquility only when threat/range are safe and other raid CDs are insufficient.
- Short damage pulses: pre-HoT rather than post-react.
- Dispel packs: Remove Curse/Abolish Poison outrank low-value HoT refreshes when the debuff is dangerous.

## S+ Healing Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Tank taking predictable damage | Use the planned efficient heal/rank before the swing or ability lands | Tank stable above danger threshold |
| Tank spike or lethal target | Use emergency instant/cooldown path | Lethal window resolved |
| Raid-wide damage | Use group/HoT/chain tools only when enough targets will benefit | Raid out of lethal range |
| Dangerous dispel | Dispel/cleanse before filler healing | Debuff removed or lower danger than HP loss |
| Low mana | Downrank, cancel overheals, use mana tools early | Mana plan recovered |

### Cooldown Usage

Swiftmend for immediate saves, Nature's Swiftness plus Healing Touch for tank emergencies, Innervate assigned targets early enough to matter.

### Resource Management

Do not bloom every Lifebloom unless burst healing is required; rolling stacks usually win efficiency.

### Threat Management

Tree/HoT threat can pull fresh adds; delay blanket HoTs before scripted add waves unless tanks are ready.

### Utility, Interrupts, and Dispels

Decurse, poison removal, battle rez, Innervate, Cyclone/roots in PvP, and emergency Bear form survival.

### PvP Playstyle

Use mobility, forms, Cyclone, roots, HoTs, and shapeshift snare breaks. Feral wins with control into burst; Restoration wins by pre-HoT and line-of-sight; Balance wins by burst windows and control.

### Consumables

- Healing power flask or healing/spirit/mp5 elixir pair.
- Healing or mp5 food by fight length.
- Mana potion/dark rune style mana restore by ruleset.
- Drums if assigned.
- Brilliant Mana Oil where weapon imbues do not replace it.

### Gear and Set Pieces

Use `Druid/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Lifebloom [33763] bloom wasted on full-HP target | Lost mana efficiency | Track target HP before bloom; redirect or let bloom on tank | `target_hp_pct`, `lifebloom_stack_count` | Wowhead |
| Innervate [29166] on wrong target | Wasted mana return | Assign by role: self only if no better target; otherwise healer > caster | `innervate_target_role`, `target_mana_pct` | Icy Veins |
| Rebirth [20484/26994] on target with Forbearance | Cannot accept rez buff | Wait for Forbearance [25771] expiry; call for alternative | `target_has_forbearance` | Common |
| Clearcast [16870] mid-regrowth cast | Proc wasted | Queue next Regrowth [26980] if clearcast active; otherwise skip; do not use Nourish [50464] because it is absent from `wow_anniversary` DB2 | `clearcast_active`, `cast_remains` | Wago DB2 |
| Tree of Life [33891] dropped during combat | Lost aura + HoT scaling | Re-cast immediately; do not shift out for single-target heals | `form_active`, `combat_state` | Icy Veins |
| Mana floor < 20% | Cannot sustain HoT rotation | Drop Rejuvenation [26981] on non-tanks; keep Lifebloom [33763] on tank only | `mana_pct`, `target_role` | Wowhead |
| PvP: Cyclone [33786] on DR target | Wasted GCD | Check DR before cyclone; use Entangling Roots [26989] instead | `cyclone_dr` | Arena |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Moroes | ADD-WAVE | Gouge = tank threat drop; pre-shield tank | `moroes_gouge_active` | Wowhead |
| Karazhan | Maiden | SILENCE | Repentance = silence; pre-HoT all | `maiden_repentance_casting` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = raid-wide; cooldown rotation | `gruul_growth_stacks > 10` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant heals | `lurker_spout_active` | Icy Veins |
| SSC | Morogrim | ADD-WAVE | Murloc waves = AoE heal priority | `morogrim_add_wave` | Wowhead |
| Black Temple | Reliquary | SILENCE | Phase 2 silence; pre-HoT required | `reliquary_phase == 2` | Icy Veins |
| Black Temple | Gurtogg | SURVIVAL-MODIFIER | Fel Acid [40508] stacking = tank spike | `fel_acid_stacks > 5` | Wowhead |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected stop DPS | `has_parasitic` | Icy Veins |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = no conserve; spam heals | `brutallus_hp < 20` | Wowhead |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = spread; pre-shield | `felmyst_gas_nova_casting` | Icy Veins |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Wowhead |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Druid Restoration | Raid | Tree of Life [33891] | 33891 | +20% HoT healing | Always active in healing group | Wago DB2 |
| Druid Restoration | Target | Innervate [29166] | 29166 | Mana regen | Assign to mana-starved healer > caster | Icy Veins |
| Druid Restoration | Target | Rebirth [20484/26994] | 20484/26994 | Battle rez | Hold for tank/healer death | Wowhead |
| Druid Restoration | Raid | Mark of the Wild [26990] | 26990 | +stats | Apply to all pre-pull | Wago DB2 |
| Priest Shadow | Druid Restoration | Vampiric Touch [34914] | 34914 | Reduces Innervate frequency | VT uptime > 80% | Icy Veins |
| Paladin Holy | Druid Restoration | Blessing of Wisdom [27142] | 27142 | +mana regen | When in same group | Wowhead |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base heal | SP coefficient | Mana cost | GCD | HpM | HpS | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Lifebloom [33763] | 150/stack | 0.10 | 220 | 1.5 | 0.68 | 100 | >6s | Tank maintenance |
| Rejuvenation [26981] | 800 | 0.20 | 415 | 1.5 | 1.9 | 533 | >12s | Raid maintenance |
| Regrowth [26980] | 1800 | 0.50 | 675 | 2.0 | 2.7 | 900 | >6s | Burst heal |
| Swiftmend [18562] | 1000 | 0.80 | 0 | 0 | ∞ | N/A | Any | Consumes Rejuv/Regrow | Icy Veins |
| Tranquility [26983] | 400/target | 0.30 | 1200 | 8.0 | 0.33 | 50 | 5+ targets | Channeled AoE | Wowhead |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Lifebloom [33763] + Rejuvenation [26981] only | Innervate [29166] | Potion | `mana_pct`, `innervate_cd` |
| Mana < 15% | Lifebloom [33763] on tank only | All other spells forbidden | Potion, wait for VT mana | `mana_pct`, `potion_cd` |
| Mana < 5% | Swiftmend [18562] only if emergency | All other spells forbidden | Wait for external mana | `mana_pct` |

**Part D — Downrank Table**

| Spell | Rank | Spell ID | Mana cost | Avg heal | HpM | HpS | Use case | Mana % threshold |
|---|---|---|---|---|---|---|---|---|
| Regrowth | 12 | 26980 | 675 | 1800 | 2.7 | 900 | Burst raid heal | >30% |
| Regrowth | 10 | 26978 | 550 | 1400 | 2.5 | 700 | Conserve burst | 15-30% |
| Rejuvenation | 13 | 26981 | 415 | 800 | 1.9 | 533 | Raid maintenance | <15% |
| Lifebloom | 1 | 33763 | 220 | 150 | 0.68 | 100 | Tank only | Any |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Lifebloom stack management | Maintain 3-stack on tank; let bloom on safe HP | Often refreshes at <1s causing mana waste | LIKELY BUG | Mana inefficiency | Refresh at 2-3s remaining | Icy Veins |
| Innervate assignment | Give to healer > caster > self | Often self-cast | INTENTIONAL CHOICE | Suboptimal raid mana | Add `target_mana_pct` check | Wowhead |
| Swiftmend consumption | Consume Rejuvenation first (cheaper) | Often consumes Regrowth (expensive) | LIKELY BUG | Wasted Regrowth HoT | Add `rejuv_present` check first | Icy Veins |
| Tree of Life uptime | Stay in form always | Often shifts out for single-target heals | LIKELY BUG | Lost +20% HoT bonus | Gate form shift to emergency only | Wowhead |
| Tranquility usage | Only when 5+ targets injured | Often used on 2-3 targets | INTENTIONAL CHOICE | Mana inefficiency | Add `injured_count >= 5` check | Icy Veins |

**Prioritized fix backlog:**
1. Lifebloom refresh timing — mana efficiency critical
2. Swiftmend consumption order — HoT preservation
3. Tree of Life uptime — healing bonus
4. Innervate assignment — raid sustain

[NEW FINDING] Druid Restoration Lifebloom should refresh at 2-3s remaining, not <1s, to avoid mana waste from premature refreshes.
[DB2 VETTED 2026-05-18] Nourish [50464] is absent from `wow_anniversary` SpellName and class skillline DB2; do not implement it for TBC Restoration.

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Druid Restoration research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
