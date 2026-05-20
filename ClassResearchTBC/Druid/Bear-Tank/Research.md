# Feral Druid Bear Tank Research

Sources: `../../Sources.md`, `../../LocalReferences.md`, Icy Veins Feral Tank, Wowhead Feral/Bear resources, Flux Druid research, Sonah Feral, SlyRotate Feral.

## Role

High armor, high health physical tank. Bear excels at sustained single-target threat and survivability, with limited but usable multi-target threat.

## Single Target Tanking

Priority:
1. Maintain Faerie Fire (Feral) when useful.
2. Keep Demoralizing Roar up if assigned.
3. Mangle (Bear) on cooldown for threat and bleed damage support.
4. Build/maintain Lacerate stacks on long-lived targets.
5. Swipe as filler when rage allows.
6. Queue Maul as rage dump without starving Mangle/Lacerate.
7. Growl only when taunt is needed; do not burn taunt as rotation.

## Multi Target Tanking

- Swipe hits limited nearby targets and is the main repeatable AoE threat tool.
- Tab-target Mangle/Lacerate/Faerie Fire on dangerous targets.
- Demoralizing Roar for mitigation/threat tagging, not a full AoE threat solution.
- Challenging Roar is an emergency AoE taunt, not a normal pull tool.

## Defensive Play

- Frenzied Regeneration when low and rage is available.
- Barkskin for predictable damage or emergency mitigation.
- Enrage for rage generation only when safe; it reduces armor.
- Feral Charge/Bash can interrupt or control.

## PvP

- Bear form is the defensive/control form.
- Use Feral Charge, Bash, Demoralizing Roar, Frenzied Regeneration, and shapeshift utility.
- Avoid breaking CC with Swipe.

## Consumables, Gear, Sets

- Survival: armor, stamina, defense/resilience needs, dodge, expertise/hit for threat where useful.
- Ironshield Potion for physical burst, stamina/armor consumables, Engineering items for utility.
- Tier bonuses may change Lacerate/Maul/Swipe valuation; verify before implementation.

## Automation Notes

- Track rage, Mangle CD, Lacerate stacks/remains, Demo Roar remains, target threat, incoming damage, nearby enemy count, CC proximity, taunt necessity.
- Use squared distance and early exits when scanning nearby mobs.

## S+ Completion Addendum

Role: **Tank**.

### Role Summary

High-armor tank relying on Mangle, Lacerate, Maul, Swipe, Demoralizing Roar, and form-based mitigation.

### Talent Builds and Variants

Mangle, Thick Hide, Survival of the Fittest, Natural Reaction, Leader of the Pack, Feral Instinct, Primal Fury.

### Core Stats and Caps

Defense/crit immunity plan, stamina, armor, agility/dodge, expertise/hit for threat, and resist sets by encounter.

### DB2-Verified Core Spell Table

| Spell name | DB2 spell IDs | Skill lines | Rotation use |
|---|---|---|---|
| Barkskin | 22812 | Balance | conditional |
| Challenging Roar | 5209 | Feral Combat | conditional |
| Demoralizing Roar | 99, 1735, 9490, 9747, 9898, 26998 | Feral Combat | conditional |
| Faerie Fire (Feral) | 16857, 17390, 17391, 17392, 27011 | Feral Combat | core |
| Frenzied Regeneration | 22842, 22845, 22895, 22896, 26999 | Feral Combat | conditional |
| Growl | 6795 | Feral Combat | conditional |
| Lacerate | 33745 | Feral Combat | core |
| Mangle | 33917 | Feral Combat | core |
| Maul | 6807, 6808, 6809, 8972, 9745, 9880, 9881, 26996 | Feral Combat | conditional |
| Swipe | 769, 779, 780, 9754, 9908, 26997 | Feral Combat | conditional |

### Single-Target Priority

1. Pull with Faerie Fire (Feral) or body pull when positioning matters.
2. Keep Demoralizing Roar active if no stronger attack power reduction is present.
3. Keep Mangle on cooldown.
4. Build and maintain Lacerate stacks.
5. Queue Maul when rage is above the survival floor.
6. Use Swipe only as filler on single target when rage is excessive and Maul/Mangle/Lacerate are covered.

### Multi-Target and AoE Matrix

- 2 targets: Mangle skull, Lacerate skull, Swipe between Mauls.
- 3 targets: Swipe becomes a core threat button; tab Mangle/Lacerate high-risk mobs.
- 4+ targets: pre-position, Swipe on cooldown, use Challenging Roar only as recovery, and call for misdirect/CC.
- Caster packs: line-of-sight pull and interrupt support are more valuable than early Swipe spam.
- CC packs: face mobs away and avoid Swipe near controlled targets if positioning is tight.

## S+ Tanking Decision Table

| Situation | Action | Stop condition |
|---|---|---|
| Pull/open | Establish position and snap threat before DPS burst | Mobs faced safely and tank lead established |
| Boss swing/spike soon | Activate mitigation or hold resource for active defense | Spike passed |
| Add spawn | Use taunt/snap threat/CC call before returning to boss cycle | Adds controlled |
| DPS near threat | Prioritize snap-threat buttons and call throttle | Threat lead restored |
| Low resource | Stop dumps and preserve taunt/mitigation resource | Resource floor restored |

### Cooldown Usage

Use Frenzied Regeneration for sustained damage when rage is available; Barkskin for predictable spikes; potions/stones follow healer stress, not personal panic.

### Resource Management

Maintain a rage floor for Maul, taunt recovery, and Frenzied Regeneration; avoid rage dumping before tank swaps or add pickups.

### Threat Management

Open with snap threat, then preserve rage for recovery. If DPS is near threat, prioritize Mangle/Maul over maintenance refreshes.

### Utility, Interrupts, and Dispels

Battle rez if not actively tanking, Innervate by assignment, emergency Feral Charge/Bash if talented, and decurse/poison only when safe to leave form.

### PvP Playstyle

Use mobility, forms, Cyclone, roots, HoTs, and shapeshift snare breaks. Feral wins with control into burst; Restoration wins by pre-HoT and line-of-sight; Balance wins by burst windows and control.

### Consumables

- Fortification/survival flask or armor/stamina elixirs by encounter.
- Stamina food or threat food by farm/progression.
- Ironshield/health/mana potion depending class and damage profile.
- Resistance consumables when the encounter demands it.
- Weapon oil/stone/imbue only if compatible with threat model.

### Gear and Set Pieces

Use `Druid/Gear-and-Sets.md` for DB2 item-set IDs, piece IDs, set-bonus spell IDs, and DB2 bonus descriptions. Treat a set bonus as rotation-changing only when it changes resource thresholds, cooldown timing, proc state, or defensive planning.

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

### Angle 1 — Failure-Case State Table

| Condition | Action | Stop condition |
|---|---|---|
| Threat lead drops or target swaps off tank | Re-open with Growl [6795] or Challenging Roar [5209] if assigned, then rebuild with Mangle (Bear) [33987] + Maul [26996] + Faerie Fire (Feral) [16857/17390/17391/17392/27011] | Threat lead restored and target locked back on tank |
| Rage starvation while Mangle (Bear) [33987] is due | Preserve 20 rage for Mangle (Bear) [33987], stop Maul [26996] and Swipe [26997], and defer Enrage [5229] until health is safe | Rage floor restored or Mangle window passed |
| Mangle (Bear) [33987] is expiring or missing | Refresh immediately before Maul [26996] or Swipe [26997] unless Growl [6795] / Challenging Roar [5209] is required first | Bleed-refresh debuff is back up |
| Form swap happens during taunt recovery | Abort non-taunt form swaps, re-enter Bear / Dire Bear Form [9634], then re-issue Growl [6795] only after stance settles | Back in Bear / Dire Bear Form [9634] with taunt ready |
| Barkskin [22812] is available during predictable burst | Pre-load Barkskin [22812] before spike damage, then continue normal threat priority under mitigation | Burst window ends or Barkskin [22812] expires |

### Angle 2 — Boss Modifier Table

| Condition | Action | Stop condition |
|---|---|---|
| Karazhan | Mixed undead / demon / caster utility; CC, interrupts, tank spikes, movement, beam / phase handling | Dungeon-specific phase or add cycle is stable |
| Gruul's Lair | Council control / tank assignments; shatter movement; growth-based tank pressure; threat discipline | Growth cycle or swap point is handled |
| Magtheridon's Lair | Channeler add control; interrupt rotations; cube / click assignments; tank cooldowns and raid burst windows | Channeler wave and cube duty are stable |
| Serpentshrine Cavern | Resistance / tank swaps; add waves; water / movement; demon phase control; multi-add tanking; final-phase objective handling | Boss swap or add wave is controlled |
| The Eye / Tempest Keep | Air / ground movement; threat resets; arcane / caster pressure; legendary weapon / add phase handling; interrupts | Phase transition or reset is handled |
| Hyjal Summit | Wave-based trash; AoE threat; decurse / fear / doom mechanics; boss transitions; anti-fear and survival checks | Wave ends and next spawn timer is clear |
| Black Temple | Tank spikes; target swaps; ghost / vehicle-style duty; council interrupts; shadow resistance planning; demon phase control | Encounter phase shifts into stable cycle |
| Zul'Aman | Timed-run routing; animal boss mechanics; add waves; interrupts / dispels; multi-mob council-style control | Bear tank duty is back on the main target |
| Sunwell Plateau | High raid damage; strict dispels; tank busters; portal / split-realm duty; add burn; survival cooldown chains | Burst cycle or split duty is resolved |
| Doom Lord Kazzak | World-boss threat; shadow damage; anti-heal / drain checks; tight kill discipline | Threat and anti-drain pressure are stable |
| Doomwalker | World-boss threat; earthquake / chain-lightning raid spread; tank positioning | Positioning and spread are stable |
| Hellfire Ramparts | Early Outland melee / caster packs; patrol awareness; basic heroic spike damage | Pack is controlled and safe to move |
| The Blood Furnace | Dense fel-orc packs; caster control; poison / slime-style pressure; boss add / control checks | Add control and caster pressure are contained |
| The Shattered Halls | Large melee packs; gauntlet pressure; stun / cleave risk; AoE threat stress test | Gauntlet or pack control is established |
| The Slave Pens | Naga / broken packs; poison / nature pressure; healer attention to tank spikes | Tank spike cycle settles |
| The Underbog | Nature / poison themes; pet / add control; ground effects and caster positioning | Ground effects and adds are stable |
| The Steamvault | Caster interrupts; add control; purge / cleanse value; boss empowerment awareness | Empowerment or interrupt cycle is handled |
| Mana-Tombs | Ethereal caster packs; mana pressure; reflect / shield-style boss checks; add portals | Portal and shield checks are stable |
| Auchenai Crypts | Undead utility; caster disruption; healing pushback / positioning; summoned add control | Summon / caster disruption is handled |
| Sethekk Halls | Caster packs; polymorph / fear / control risk; LoS pulls; bird / add control | LoS and control anchors are stable |
| Shadow Labyrinth | Fear / charm / caster-heavy dungeon; strong interrupt / dispels; movement and sonic burst awareness | Fear / charm window passes |
| Old Hillsbrad Foothills | Escort pacing; add waves; mounted / chase sections; objective protection | Escort segment is clear |
| The Black Morass | Portal waves; add pickup; boss timers; mana pacing across continuous combat | Portal wave is secure |
| The Mechanar | Mechanic / caster packs; polarity / bomb-style movement; add control | Movement mechanic is resolved |
| The Botanica | Botanical / nature packs; add waves; interrupts; poison / nature resistance checks | Add wave and interrupt cycle is stable |
| The Arcatraz | Dangerous caster / demon packs; stuns / interrupts; heavy heroic tank damage; multi-phase final boss | Caster threat and boss phase are stable |
| Magisters' Terrace | High-density caster / control dungeon; PvP-like Delrissa fight; purge / interrupt / CC priority | Control assignments are satisfied |

### Angle 3 — Cross-Spec Interactions

| Condition | Action | Stop condition |
|---|---|---|
| Feral Faerie Fire coverage is missing | Apply Faerie Fire (Feral) [16857/17390/17391/17392/27011] before caster Faerie Fire [770/778/9749/9907/26993] so the tank-side armor shred is owned by the Bear package | Feral debuff is active and stable |
| Another Druid already owns the Feral armor debuff | Skip duplicate Faerie Fire (Feral) [16857/17390/17391/17392/27011] and use caster Faerie Fire [770/778/9749/9907/26993] only if the raid still needs a caster-side armor shred | Debuff ownership is clear |
| Assigned healer is mana-starved and tank is not in immediate burst danger | Reserve Innervate [29166] for the healer assignment instead of selfish recovery | Healer mana returns above recovery floor |
| Inner-raid utility assignment changes mid-fight | Re-evaluate Innervate [29166] ownership against healer priority before using it on self or another Druid role | Assignment is refreshed |

### Angle 4 — Resource Efficiency

| Condition | Action | Stop condition |
|---|---|---|
| Part A: Mangle (Bear) [33987] is available | Treat Mangle (Bear) [33987] as the highest threat-per-rage spend and reserve 20 rage for it before any dump | Mangle cast or queued |
| Part A: Maul [26996] is affordable without starving Mangle (Bear) [33987] | Queue Maul [26996] only as the rage dump after Mangle reserve is protected | Rage floor would be broken |
| Part A: Lacerate [33745] is on a long-lived target | Maintain and refresh Lacerate [33745] before expiry to preserve sustained threat efficiency | 5 stacks and safe refresh timer are in place |
| Part A: Swipe [26997] is considered on single target | Skip Swipe [26997] unless rage is excessive or 3+ targets justify the threat spread | Mangle / Lacerate / survival floor are covered |
| Part A: Demoralizing Roar [26998] is already up | Leave Demoralizing Roar [26998] as mitigation coverage, not as a rage sink for threat | AP debuff remains active |
| Part B: rage is below 20 | Hold Maul [26996] and Swipe [26997], keep rage for Mangle (Bear) [33987] and emergency Growl [6795] | Rage reaches the Mangle floor |
| Part B: rage is 20-39 | Spend only on Mangle (Bear) [33987] and Lacerate [33745]; avoid Maul [26996] unless the queue is already locked | Rage rises above dump floor |
| Part B: rage is 40+ | Allow Maul [26996] queueing and Swipe [26997] only when Mangle [33987] is not being sacrificed | Rage floor falls below dump threshold |
| Part B: rage is low and HP is safe | Use Enrage [5229] to rebuild rage only when armor loss is acceptable | Rage recovery is underway |

### Angle 5 — Implementation Divergence

| Condition | Action | Stop condition |
|---|---|---|
| Flux `DRUID_RESEARCH.md` bear model | Mirror the explicit bear state inputs: `maul_queued`, `maul_confirmed`, `lacerate_stacks`, `lacerate_duration`, and nearby enemy counts for Swipe / Demo Roar decisions | State machine inputs are mapped 1:1 |
| Sonah `DruidCore.lua` | Treat localized spell names and `UnitBuff` form detection as the name-resolution layer, not as the source of TBC spell IDs | ID table is authoritative |
| SlyRotate `SlyRotate_FeralDruid.lua` | Use the display priorities as UX signal: Mangle (Bear) [33987] > Lacerate [33745] > Maul [26996] > Demoralizing Roar [26998] > Bash [8983] > Frenzied Regeneration [26999] | Bear row ordering is preserved |
| SlyRotate Bear thresholds | Keep the explicit thresholds as implementation hints: Mangle [33987] at 20 rage, Maul [26996] at 40 rage, Swipe [26997] at 15 rage, Enrage [5229] below 20 rage with HP safety | Thresholds are translated into code guards |
| `SlyRotate_Druid.lua` is absent | Do not assume a unified Druid file exists; derive Bear Tank divergence only from `SlyRotate_FeralDruid.lua` and local Druid core helpers | File mapping is resolved |

## LLM Implementation Contract - 2026-05-18

This contract converts the existing Druid Bear Tank research into code-generation constraints. It does not replace the DB2 spell table, role priority tables, or encounter modifiers above; it tells an implementation LLM how to consume them safely.

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
