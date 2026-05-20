# Source Baseline Matrix

This document tracks how external and archived rotation sources should be used for EaxRotations.
It is a planning and verification artifact, not a license to copy code.

## Source Rules

- Keep EaxRotations original Project Sylvanas Lua.
- Use other projects only as behavioral references: note the mechanic, close the source, then implement through `NS.*` and Sylvanas APIs.
- Do not copy `.toc`, images, UI assets, macros, addon frames, comments, schema text, or implementation structure from other projects.
- Verify spell, aura, item, food, drink, potion, rune, flask, elixir, drum, scroll, and weapon-buff IDs against Wago DB2 data before adding them.
- Keep package contents limited to `.lua` and `.md`.
- Runtime behavior still needs in-game aura dumps when the failure depends on what Sylvanas exposes for the local player, target, pet, weapon enchants, or totems.

## Baseline Sources

| Source | Local Path | Best Use | Do Not Import |
|---|---|---|---|
| SlyRotate | `SlyRotate/` | Lightweight priority sanity checks, Shaman shock/totem behavior, Hunter aspect/sting behavior, Warrior swing/proc awareness | `.toc`, addon shell, WoW UI calls |
| Sonah | `Sonah/` | Rich per-spec recommendations, PvP utility, sticky spell behavior, talent/build detection, Hunter weaving, Warlock curse/DoT policy | `.toc`, `.tga`, UI frames, macros, wording |
| Flux | `flux/rotation/source/aio/` and `flux/docs/` | Deep runtime architecture, middleware, context model, tank threat, Shaman totems/interrupt scan, Warrior HS queueing, Hunter Viper/Misdirection/Readiness, Warlock Seed AoE | GGL/TMW/Action APIs, schema text, framework structure |
| Original EAX Archive | `archive_original_specs/` | Spell table comparison, old manager behavior, historical edge cases | Bad IDs, mismatched names, old direct API usage |
| Wago DB2 | Wago `SpellName` and `ItemSparse` CSV for build `2.5.4.42940` | ID validation for TBC spell and item data | Runtime behavior assumptions |
| WoWSims TBC | Online sim and GitHub source | DPS priority and sim-backed mechanics for supported specs | UI/generated code, non-Sylvanas engine code |
| Wowhead / Icy Veins | Online TBC class guides | Public guide-level priority and consumable sanity checks | Guide prose or modern/non-TBC mechanics |

## Current Static Status

| Area | Status | Evidence |
|---|---|---|
| File type rule | Pass | `rg --files EaxRotations -g "!*.lua" -g "!*.md"` returns no files |
| Wago ID audit | Pass | `docs/NON_RUNTIME_DELIVERY.md` records Wago build `2.5.4.42940` |
| Static behavior audit | Pass | `docs/STATIC_BEHAVIOR_AUDIT.md` reports zero findings |
| Archive spell diff | Needs triage, not bulk import | `docs/ARCHIVE_TRIAGE.md` separates real candidates from bad archive data |
| Runtime aura validation | Pending | Needs in-game `NS.dump_player_auras(...)` / `shared/aura_probe_sylvanas.lua` |

## Per-Spec Matrix

Legend:

- `Covered`: current EAX Lua already has the core mechanic family.
- `Verify`: code/static data exists, but live Sylvanas runtime needs validation.
- `Add`: confirmed missing behavior to implement after API/ID verification.

| Class | Playstyle | SlyRotate | Sonah | Flux / Sim | EAX Status | Next |
|---|---|---|---|---|---|---|
| Druid | Balance | N/A | DoT/nuke and PvP control reference | WoWSims Balance, Flux Balance | Covered | Verify Nature's Grace, Moonfire/Insect Swarm refresh, and movement fallback in live combat |
| Druid | Bear | N/A | Defensive/tank recommendation reference | Flux tanking handover, WoWSims Feral Tank | Covered | Verify multi-mob threat targeting, taunt priority, and defensive thresholds |
| Druid | Feral Cat | N/A | Cat priority and PvP control reference | WoWSims Feral, Flux cat/powershift concepts | Covered | Verify powershift, Rip/Rake refresh, Omen/Clearcasting, and positional Shred gates |
| Druid | Restoration | N/A | Healing triage reference | Flux resto and guide-level heal rules | Covered | Verify Lifebloom/Swiftmend/Tree behavior and cleanse/Innervate targeting |
| Druid | Leveling/Caster | Archive | General utility reference | Guide-level leveling sanity | Covered | Verify form-safe OOC buffs and low-level rank fallback |
| Hunter | Beast Mastery | Aspect/sting/simple priority | BM weave, pet, PvP, sticky spell | Flux Hunter, WoWSims Hunter | Covered | Verify Steady weave timing, Kill Command, Bestial Wrath, pet attack, Misdirection, and Viper logic |
| Hunter | Marksmanship | Aspect/sting/simple priority | MM Aimed/Multi/Steady/PvP | Flux Hunter, WoWSims Hunter | Covered | Verify Readiness is learned/talent gated and Misdirection focus targeting is correct |
| Hunter | Survival | Aspect/sting/trap priority | SV traps/Wyvern/PvP | Flux Hunter, WoWSims Hunter | Covered | Verify trap placement behavior, Viper Sting target rules, and melee emergency tools |
| Hunter | Leveling | Sly hunter aspect behavior | HunterCore pet/aspect behavior | Guide-level leveling sanity | Covered | Verify pet HP, aspect recast throttles, and low-level Steady Shot fallback |
| Mage | Arcane | Basic spell sanity | Arcane sticky/cooldown reference | WoWSims Mage, Flux Mage | Covered | Verify Arcane Blast stack/mana conserve, Clearcasting, mana gem, Evocation |
| Mage | Fire | Basic spell sanity | Fire priority reference | WoWSims Mage, Flux Mage | Covered | Verify Scorch maintenance, Ignite-friendly priority, Combustion, Dragon's Breath/Blast Wave gates |
| Mage | Frost | Basic spell sanity | Frost PvP/control reference | WoWSims Mage, Flux Mage | Covered | Verify Water Elemental, Shatter windows, Frostbite/Fingers-not-TBC guard, Ice Block safety |
| Mage | Leveling | Archive | General mage utility | Guide-level leveling sanity | Covered | Verify conjure/food/drink and rank fallback if enabled through shared data |
| Paladin | Holy | Basic spell sanity | Heal/PvP utility reference | Flux Paladin, guide-level healing | Covered | Verify FoL/HL/Holy Shock triage, Cleanse, BoP/BoF/Sacrifice targeting |
| Paladin | Protection | Basic spell sanity | Tank recommendation reference | WoWSims Prot Paladin, Flux Paladin | Covered | Verify Consecration/Holy Shield/Judgement threat loop, taunt equivalents, and mana gates |
| Paladin | Retribution | Basic spell sanity | Ret priority/PvP reference | WoWSims Ret, Flux Paladin | Covered | Verify seal/judgement cycle, seal twisting gates, Hammer of Wrath, Exorcism target checks |
| Paladin | Leveling | Archive | General utility reference | Guide-level leveling sanity | Covered | Verify seal/rank fallback and defensive blessing usage while solo |
| Priest | Discipline | Basic spell sanity | Disc shield/heal/PvP reference | Guide-level healing | Covered | Verify PWS, Prayer of Mending, dispels, Pain Suppression talent gating |
| Priest | Holy | Basic spell sanity | Holy heal/PvP reference | Guide-level healing | Covered | Verify downrank-style heal choices, Renew, Prayer of Healing, Spirit of Redemption handling |
| Priest | Shadow | Basic spell sanity | VT/DoT/PvP reference | WoWSims Shadow/Smite, Flux Priest | Covered | Verify VT/VE/SWP refresh, Mind Flay tick clipping, Shadowfiend, Silence gates |
| Priest | Smite | Archive | Smite reference | WoWSims Smite | Covered | Verify Holy Fire/SW:P/Smite sequence, mana recovery, and solo fallback |
| Priest | Leveling | Archive | General priest utility | Guide-level leveling sanity | Covered | Verify wand/DoT/shield priority at low levels |
| Rogue | Assassination | Basic spell sanity | Mutilate/Envenom/PvP reference | WoWSims Rogue, Flux Rogue | Covered | Verify poison state, Deadly Poison stacks, Envenom gating, Cold Blood |
| Rogue | Combat | Basic spell sanity | Combat cooldown/PvP reference | WoWSims Rogue, Flux Rogue | Covered | Verify SnD/Rupture/Expose policy, AR/BF timing, energy tick and poison checks |
| Rogue | Subtlety | Basic spell sanity | Shadowstep/Hemo/PvP reference | WoWSims Rogue, Flux Rogue | Covered | Verify Premeditation, Preparation, Hemo debuff, Shadowstep burst gates |
| Rogue | Leveling | Archive | General rogue utility | Guide-level leveling sanity | Covered | Verify stealth opener, Slice and Dice, Kick/Gouge/Evasion safety |
| Shaman | Elemental | Shock/totem priority | Elemental/PvP utility reference | WoWSims Elemental, Flux Shaman | Covered | Runtime aura dump: verify Lightning Shield, Flame Shock, totems, Elemental Mastery, Bloodlust |
| Shaman | Enhancement | Stormstrike/Flame Shock/Earth Shock/totem reference | Enhancement/PvP utility reference | WoWSims Enhancement, Flux Shaman | Covered | Runtime aura dump: verify Lightning Shield spam fix, Stormstrike debuff, Windfury weapon/totem, self-heal threshold |
| Shaman | Restoration | Totem/shield sanity | Resto healing reference | Flux Shaman restoration | Covered | Runtime aura dump: verify Earth Shield stacks, Water Shield, Mana Tide, purge/self-dispel |
| Shaman | Leveling | Sly shock/totem behavior | ShamanCore utility | Guide-level leveling sanity | Covered | Runtime aura dump: verify playstyle switch from Leveling to spec and low-level shield/imbue IDs |
| Warlock | Affliction | Basic spell sanity | UA/DoT/curse/PvP reference | WoWSims Warlock, Flux Warlock | Covered | Verify curse policy, Nightfall, Seed AoE, Drain Soul execute, Soulshatter |
| Warlock | Demonology | Basic spell sanity | Pet/Demonology reference | WoWSims Warlock, Flux Warlock | Covered | Verify pet presence, Fel Domination, Demonic Sacrifice, Soul Link-style defensive gates |
| Warlock | Destruction | Basic spell sanity | Destro priority reference | WoWSims Warlock, Flux Warlock | Covered | Verify Incinerate vs Shadow Bolt, Immolate, Shadowburn, Seed/Rain/Hellfire AoE policy |
| Warlock | Leveling | Archive | WarlockCore pet/DoT behavior | Guide-level leveling sanity | Covered | Verify pet summon, Health Funnel, Life Tap safety, low-level ranks |
| Warrior | Arms | Proc/swing sanity | Arms/PvP recommendation reference | WoWSims Warrior, Flux Warrior | Covered | Verify Slam weave, Overpower, stance dance, MS/WW rage thresholds |
| Warrior | Fury | BT/WW/HS/proc sanity | Fury priority reference | WoWSims Warrior, Flux Warrior | Covered | Verify HS/Cleave queue/dequeue, execute rage policy, Death Wish/Recklessness, Slam if enabled |
| Warrior | Kebab | Sly fury/proc sanity | Hybrid priority reference | Flux Warrior | Covered | Verify dual-wield HS trick, Devastate fallback, stance/rage starvation gates |
| Warrior | Protection | Prot priority sanity | Prot tank recommendation reference | WoWSims Prot Warrior, Flux tanking handover | Covered | Verify Shield Slam/Revenge/Devastate, taunt target selection, Spell Reflection, multi-mob threat |
| Warrior | Leveling | Archive | General warrior utility | Guide-level leveling sanity | Covered | Verify stance availability, Overpower proc, rage dump, defensive fallback |

## Implementation Queue

1. Runtime aura probes for Shaman first.
   - Dump local player auras while switching Leveling, Elemental, Enhancement, and Restoration.
   - Compare live aura IDs for Lightning Shield, Water Shield, Earth Shield, weapon imbues, Bloodlust, Shamanistic Rage, and totem states against `shared/tbc_data_sylvanas.lua`.
   - Fix only IDs or Sylvanas aura-access wrappers that fail live validation.

2. Runtime behavior probes for Hunter.
   - Validate Aspect of the Hawk/Viper detection, Viper Sting debuff detection, Misdirection target selection, Kill Command availability, and Steady Shot timing.
   - Confirm Readiness and Bestial Wrath only fire when learned.

3. Tanking and threat validation.
   - Compare current Warrior/Druid/Paladin tank behavior against the Flux tanking handover.
   - Prioritize taunt target selection, manual target grace, multi-mob threat equalization, healer-targeted taunt, and smart defensive triggers.

4. Sim-backed DPS priority pass.
   - Use WoWSims-supported specs to confirm high-impact priority ordering and resource thresholds.
   - Reconcile only behavioral differences that are TBC-correct and practical in live Sylvanas runtime.

5. Consumable and item refresh.
   - Re-run Wago `ItemSparse` checks for food, drink, potions, flasks, elixirs, scrolls, weapon buffs, oils, sharpening stones, drums, runes, healthstones, and conjured items before every release that changes item IDs.

6. Add regression coverage for each accepted source-backed change.
   - Spell/aura ID additions: table regression test.
   - Runtime gate changes: focused Lua test around `matches`.
   - API wrapper changes: fallback test with missing/partial Sylvanas API functions.

## Not Portable

- Sonah action-bar glow and frame UI. Use EAX dashboard/notifications instead.
- Sonah macro generation. Sylvanas should not create WoW macros.
- Flux GGL/TMW/Action framework calls. Translate behavior into existing EAX strategy/middleware patterns.
- SlyRotate addon shell, `.toc`, and frame wiring.
- Any spell or aura not present in TBC Wago data unless a live Sylvanas dump proves it is the exposed runtime aura for a TBC mechanic.
