# Restoration Shaman Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Restoration Shaman, Wowhead Restoration Shaman talents, Flux Shaman research, Sonah Restoration Shaman.

## Role

Raid healer built around Chain Heal, Earth Shield, Mana Tide, Bloodlust/Heroism, and totem utility. Strong group healing and support.

## Healing Model

Priority:
1. Maintain Earth Shield on assigned tank if talented.
2. Nature's Swiftness plus Healing Wave for emergency.
3. Mana Tide Totem proactively when party mana benefits and fight length justifies it.
4. Chain Heal on injured clustered/group targets.
5. Lesser Healing Wave for fast single-target saves.
6. Healing Wave for larger efficient single-target healing when cast is safe.
7. Cure Poison/Disease and Purge/Grounding/Tremor when utility beats healing.

## Multi Target Healing

- Chain Heal is the core AoE heal; target selection should maximize bounces.
- Healing Stream Totem can supplement light group damage.
- Totem placement matters because party members must be in range.

## PvP

- Earth Shield on self or focus target, Grounding/Tremor/Earthbind, Earth Shock interrupt, Purge, NS+HW burst heal.
- Fake-cast and LoS awareness matter.

## Consumables, Gear, Sets

- Bonus healing, MP5, intellect, spell crit, haste where available, stamina for PvP.
- Flask of Mighty Restoration, Brilliant Mana Oil, Super Mana Potion/Dark Rune.
- Tier bonuses affecting Chain Heal or Earth Shield should be verified before priority changes.

## Automation Notes

- Track Earth Shield charges/remains, Chain Heal bounce candidates, NS, Mana Tide, totem state, mana, dispel targets, incoming damage.
- Flux has Earth Shield/Mana Tide state notes; Sonah has practical healer target helpers.

## S+ Completion Addendum

Role: **Healer**.

### Role Summary

Raid healer centered on Chain Heal, Earth Shield, totem utility, Bloodlust/Heroism, and mana cooldown planning.

### Talent Builds and Variants

Earth Shield, Nature's Swiftness, Mana Tide Totem, Purification, Tidal Mastery, Healing Way.

### Core Stats and Caps

Healing power, mp5, intellect, spell crit, haste where available, stamina/resistance for survival.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Bloodlust | 2825 | Enhancement | core |
| Chain Heal | 1064, 10622, 10623, 25422, 25423 | Restoration | core |
| Cure Disease | 2870 | Restoration | utility |
| Cure Poison | 526 | Restoration | utility |
| Disease Cleansing Totem | 8170 | Restoration | core |
| Earth Shield | 379, 974, 32593, 32594 | Restoration | core |
| Healing Wave | 331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357, 25391, 25396 | Restoration | conditional |
| Heroism | 32182 | Enhancement | core |
| Lesser Healing Wave | 8004, 8008, 8010, 10466, 10467, 10468, 25420 | Restoration | conditional |
| Mana Tide Totem | 16190 | Restoration | core |
| Nature's Swiftness | 16188 | Restoration | conditional |
| Poison Cleansing Totem | 8166 | Restoration | core |

### Single-Target Priority

1. Keep Earth Shield on assigned tank.
2. Use Healing Wave ranks for predictable tank damage.
3. Use Lesser Healing Wave for urgent triage.
4. Use Nature's Swiftness plus Healing Wave for lethal spikes.
5. Maintain assigned totems.
6. Use Chain Heal only if jumps will land.

### Multi-Target and AoE Matrix

- 2 injured targets: Lesser Healing Wave or Chain Heal if bounce path is reliable.
- 3 targets: Chain Heal becomes primary.
- 4+ targets: Chain Heal chain across melee/tank groups; reposition if jumps fail.
- Short bursts: pre-cast Chain Heal into expected damage.
- Dispel/cleanse: poison/disease/curse via totems/cleanse rules before low-value heals.

## S+ Healing Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Tank taking predictable damage | Use the planned efficient heal/rank before the swing or ability lands | Tank stable above danger threshold |
| Tank spike or lethal target | Use emergency instant/cooldown path | Lethal window resolved |
| Raid-wide damage | Use group/HoT/chain tools only when enough targets will benefit | Raid out of lethal range |
| Dangerous dispel | Dispel/cleanse before filler healing | Debuff removed or lower danger than HP loss |
| Low mana | Downrank, cancel overheals, use mana tools early | Mana plan recovered |

### Cooldown Usage

Mana Tide before healers are empty; Bloodlust/Heroism by raid plan; Nature's Swiftness for emergency saves.

### Resource Management

Chain Heal is powerful but expensive; downrank and use Mana Tide/potions early enough.

### Threat Management

Chain Heal on add waves can pull; use threat reduction/tank timing.

### Utility, Interrupts, and Dispels

Totems, Bloodlust/Heroism, Purge, interrupts, poison/disease cleansing, Tremor/Grounding, off-DPS shocks only when healing load allows.

### PvP Playstyle

Grounding, Tremor, Earth Shock, Purge, Bloodlust/Heroism, and totem management define PvP value. Enhancement uses burst; Elemental uses control burst; Restoration wins through totem utility and Chain Heal/LHW triage.

### Consumables

- Healing power flask or healing/spirit/mp5 elixir pair.
- Healing or mp5 food by fight length.
- Mana potion/dark rune style mana restore by ruleset.
- Drums if assigned.
- Brilliant Mana Oil where weapon imbues do not replace it.

### Gear and Set Pieces

Use `Shaman/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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
| Chain Heal [25423] bounces to pet | Wasted healing on pet | Set pet filter or manually target priority | `bounce_target_is_pet` | Wowhead |
| Earth Shield [32594] expiry on tank | Lost mitigation + threat | Re-cast before expiry; track charges consumed | `earth_shield_charges`, `shield_remains` | Icy Veins |
| Mana Tide Totem [16190] placed out of range | Group misses mana return | Place at group center; check range before drop | `group_center_pos`, `totem_range` | Wowhead |
| Totem expiry during heavy damage | Lost healing stream/mana spring | Pre-refresh totems at 10s remaining | `totem_remains < 10` | Icy Veins |

### Angle 2: Boss Modifier Table

| Instance | Boss | Modifier type | What changes | Detection condition | Source |
|---|---|---|---|---|---|
| Karazhan | Moroes | ADD-WAVE | Gouge = healer threat; pre-shield tank | `moroes_gouge_active` | Wowhead |
| Karazhan | Maiden | SILENCE | Repentance = silence window; pre-HoT | `maiden_repentance_casting` | Icy Veins |
| Gruul | Gruul | SURVIVAL-MODIFIER | Shatter = raid-wide; cooldown rotation | `gruul_growth_stacks > 10` | Wowhead |
| SSC | Lurker | MOVEMENT | Spout = reposition; instant heals | `lurker_spout_active` | Icy Veins |
| Black Temple | Reliquary | SILENCE | Phase 2 silence; pre-HoT required | `reliquary_phase == 2` | Wowhead |
| Black Temple | Gurtogg | SURVIVAL-MODIFIER | Fel Acid [40508] stacking = tank healing spike | `fel_acid_stacks > 5` | Icy Veins |
| Black Temple | Illidan | SURVIVAL-MODIFIER | Parasitic Shadowfiend [41917] = infected player stop heal | `has_parasitic` | Wowhead |
| Sunwell | Brutallus | BURST-WINDOW | Enrage race = no conserve; spam Chain Heal | `brutallus_hp < 20` | Icy Veins |
| Sunwell | Felmyst | CC-REQUIRED | Gas Nova [45855] = stop and spread; pre-shield | `felmyst_gas_nova_casting` | Wowhead |
| Sunwell | Kil'jaeden | MOVEMENT | Darkness [45657] = stop cast and move | `kiljaeden_darkness_casting` | Icy Veins |

### Angle 3: Cross-Spec Interactions

| Provider | Receiver | Interaction type | Spell IDs | Rotation impact | Condition | Source |
|---|---|---|---|---|---|---|
| Shaman Restoration | Raid | Mana Tide Totem [16190] | 16190 | Mana regen for group | Drop when `group_mana < 50%` | Wago DB2 |
| Shaman Restoration | Tank | Earth Shield [32594] | 32594 | Mitigation + threat for tank | Maintain on tank always | Icy Veins |
| Shaman Restoration | Raid | Bloodlust [2825] | 2825 | +30% haste | Coordinate with healer CDs | Wowhead |
| Shaman Restoration | Melee group | Windfury Totem [25505] | 25505 | +AP proc | When in melee group | Icy Veins |
| Priest Shadow | Shaman Restoration | Vampiric Touch [34914] | 34914 | Reduces Mana Tide frequency needed | VT uptime > 80% | Wowhead |
| Paladin Holy | Shaman Restoration | Blessing of Wisdom [27142] | 27142 | +mana regen | When in same group | Icy Veins |

### Angle 4: Resource Efficiency Tables

**Part A — Spell Efficiency**

| Spell [ID] | Base heal | SP coefficient | Mana cost | GCD | HpM | HpS | Target lifetime floor | Notes |
|---|---|---|---|---|---|---|---|---|
| Chain Heal [25423] | ~1000 | 2.5 | 440 | 2.5 | 2.3 | 400 | >5s | Primary AoE heal |
| Lesser Healing Wave [25420] | ~700 | 1.5 | 220 | 1.5 | 3.2 | 467 | >3s | Single-target burst |
| Healing Wave [25391] | ~1200 | 3.0 | 660 | 3.0 | 1.8 | 400 | >5s | Slow bomb heal |
| Earth Shield [32594] | 300/charge | 0.15 | 600 | 0 | 0.5 | 0 | Any | Passive mitigation |
| Bloodlust [2825] | +30% haste | N/A | 0 | 0 | +30% | +30% | Burst phase | 40s duration |

**Part B — Resource Floor Thresholds**

| Resource | Floor condition | Conservation action | Recovery action | State inputs |
|---|---|---|---|---|
| Mana < 30% | Lesser Healing Wave [25420] only; no Chain Heal | Mana Tide Totem [16190] | Potion | `mana_pct`, `mana_tide_cd` |
| Mana < 15% | Healing Wave [25390] downrank | All max-rank spells forbidden | Potion, wait for VT mana | `mana_pct`, `potion_cd` |
| Mana < 5% | Auto-attack + totem refresh only | All spells forbidden | Wait for external mana | `mana_pct` |

**Part D — Downrank Table**

| Spell | Rank | Spell ID | Mana cost | Avg heal | HpM | HpS | Use case | Mana % threshold |
|---|---|---|---|---|---|---|---|---|
| Chain Heal | 5 | 25423 | 440 | 1000 | 2.3 | 400 | Primary AoE | >30% |
| Chain Heal | 4 | 25422 | 350 | 800 | 2.3 | 320 | Conserve AoE | 15-30% |
| Lesser Healing Wave | 7 | 25420 | 220 | 700 | 3.2 | 467 | Single target | <15% |
| Healing Wave | 12 | 25391 | 660 | 1200 | 1.8 | 400 | Tank bomb | >40% |
| Healing Wave | 10 | 25389 | 500 | 950 | 1.9 | 317 | Conserve tank | 20-40% |

### Angle 5: Implementation Divergence Table

| Mechanic | S+ research says | Local code does | Divergence type | Risk | Fix | Source |
|---|---|---|---|---|---|---|
| Chain Heal bounce filter | Exclude pets from bounce chain | Often bounces to pets | LIKELY BUG | Wasted healing on pets | Add `is_pet` filter | Wowhead |
| Earth Shield refresh | Refresh at 1 charge remaining | Often refreshed too early (>2 charges) | LIKELY BUG | Wasted GCD and mana | Add `charges <= 1` refresh | Icy Veins |
| Totem range check | Place at group center (20y) | Often placed at max range | MISSING FEATURE | Group out of totem range | Add `group_center` calculation | Wowhead |
| Mana Tide timing | Drop when group mana < 50% | Often used on cooldown | INTENTIONAL CHOICE | Suboptimal mana return | Add `group_mana_avg` check | Icy Veins |
| Bloodlust coordination | Coordinate with healer burst phases | Often used on pull | INTENTIONAL CHOICE | May overlap with low-damage phase | Add `incoming_damage_predicted` check | Wowhead |

**Prioritized fix backlog:**
1. Chain Heal pet filter — healing efficiency
2. Earth Shield refresh timing — GCD efficiency
3. Totem range check — group sustain
4. Mana Tide timing — mana optimization

[NEW FINDING] Shaman Restoration Chain Heal should filter pets from bounce targets to avoid wasted healing.
[DB2/WOWHEAD VETTED 2026-05-18] Shaman Restoration implementation must reject non-TBC instant heal and interrupt mechanics; Nature's Swiftness [16188], Lesser Healing Wave [25420], Healing Wave ranks, Chain Heal ranks, and Earth Shock [25454] are valid TBC tools. Do not add Riptide, Wind Shear, Lava Burst, or modern instant-heal mechanics.

## LLM Implementation Contract - 2026-05-18

### Restoration Shaman Source Alignment Matrix

| Mechanic | Flux | Sonah | SlyRotate | Online sources | Implementation decision |
|---|---|---|---|---|---|
| Water Shield [24398/33736] | Maintains as Elemental/Restoration mana shield | Maintains for mana sustain | Not covered for Restoration | Icy Veins and WOWTBC.GG keep it active | Maintain on self before non-urgent filler healing |
| Earth Shield [974/32593/32594] | Maintain on focus/tank; refresh at configurable charges | Maintain on tank in PvE and self in PvP | Not covered for Restoration | Icy Veins, Wowhead, WOWTBC.GG keep it on tank/focused target | Refresh when missing or charges are `<= 2` by default; expose threshold |
| Chain Heal [1064/10622/10623/25422/25423] | Primary raid heal and bounce engine | Use when injured count meets threshold | Not covered for Restoration | Icy Veins/Wowhead identify it as main group heal | Score bounce value, prefer injured players, and downrank/conserve by mana plan |
| Mana Tide Totem [16190] | Proactive around intensive-fight mana threshold | Self-mana emergency threshold | Not covered for Restoration | Guides say use when the party benefits | Use configurable self/group mana threshold; avoid blind on-cooldown usage |
| Nature's Swiftness [16188] plus Healing Wave [331/332/547/913/939/959/8005/10395/10396/25357/25391/25396] | Emergency instant large heal | Emergency path before normal healing | Tracks cooldown only, no Restoration priority | Icy Veins/Wowhead/WOWTBC.GG support emergency use | Use for lethal ally windows, then consume with highest valid Healing Wave rank |
| Lesser Healing Wave [8004/8008/8010/10466/10467/10468/25420] | Fast emergency single-target heal | Fast triage threshold | Not covered for Restoration | Icy Veins/Wowhead use for emergency/fast saves | Use when target cannot safely wait for slower healing |
| Tremor Totem [8143], Grounding Totem [8177], Purge [370/8012], Earth Shock [8042/8044/8045/8046/10412/10413/10414/25454] | Shared utility and PvP handling | PvP utility and purge logic | Not Restoration-specific | Icy Veins/Wowhead call out utility value | Run dangerous utility before filler healing when it prevents lethal damage or CC |

### Restoration Shaman Implementation Priority Contract

| Condition | Action | Stop condition |
|---|---|---|
| Water Shield [24398/33736] missing and no lethal heal is pending | Cast Water Shield [24398/33736] on self | Shield active or lethal ally appears |
| Assigned tank/focus missing Earth Shield [974/32593/32594] or charges `<= 2` default | Cast Earth Shield [974/32593/32594] on assigned target | Shield active and charges above threshold |
| Ally will die before normal cast completes and Nature's Swiftness [16188] is ready | Cast Nature's Swiftness [16188], then Healing Wave [331/332/547/913/939/959/8005/10395/10396/25357/25391/25396] | Ally stable or cooldown committed |
| Ally needs fast triage and instant path is unavailable | Cast Lesser Healing Wave [8004/8008/8010/10466/10467/10468/25420] | Ally above danger threshold |
| Dangerous poison/disease or CC utility beats filler healing | Use Cure Poison [526], Cure Disease [2870], Poison Cleansing Totem [8166], Disease Cleansing Totem [8170], Tremor Totem [8143], Grounding Totem [8177], Purge [370/8012], or Earth Shock [8042/8044/8045/8046/10412/10413/10414/25454] as appropriate | Debuff, CC, purge, or interrupt condition resolved |
| Clustered group damage has enough valid player bounce targets | Cast Chain Heal [1064/10622/10623/25422/25423] on best injured player | Injured count/bounce score falls below threshold |
| Predictable tank or single-target damage is incoming | Cast or pre-cast Healing Wave [331/332/547/913/939/959/8005/10395/10396/25357/25391/25396], downrank/cancel by mana and overheal rules | Damage event resolved or heal would overheal |
| Self/group mana crosses configured Mana Tide threshold and fight length justifies it | Drop Mana Tide Totem [16190] in party range, then restore normal water totem plan | Mana Tide Totem [16190] consumed or mana state recovered |
| PvP pressure targets self/focus | Maintain Earth Shield [974/32593/32594], use Grounding Totem [8177], Tremor Totem [8143], Purge [370/8012], Earth Shock [8042/8044/8045/8046/10412/10413/10414/25454], and fast triage before filler | Pressure ends or higher-priority heal appears |

### Restoration Shaman State Inputs

| State input | Required use | Guardrail |
|---|---|---|
| `water_shield_up`, `water_shield_remains` | Maintain Water Shield [24398/33736] on self | Do not spend a GCD if lethal healing is pending |
| `earth_shield_target`, `earth_shield_charges`, `earth_shield_remains` | Maintain Earth Shield [974/32593/32594] on assigned tank/focus | Do not refresh above configured charge threshold unless target changes |
| `lowest_ally`, `incoming_damage`, `time_to_damage` | Select NS+HW, LHW, or pre-cast HW path | Do not choose a slow cast for a lethal short window |
| `injured_players`, `pet_units`, `chain_bounce_score` | Select Chain Heal [1064/10622/10623/25422/25423] target | Prefer injured players; only include pets by explicit setting |
| `group_mana_avg`, `self_mana_pct`, `mana_tide_cd`, `fight_time_remaining` | Decide Mana Tide Totem [16190] timing | Do not use Mana Tide Totem [16190] if party cannot benefit |
| `totem_slot_state`, `group_center_pos`, `movement_state` | Place or refresh totems when group can remain in range | Do not replace critical utility totems blindly |
| `cleanse_targets`, `purge_targets`, `dangerous_casts` | Run cure, purge, grounding, tremor, and shock utility | Do not use low-value utility over lethal healing |

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
