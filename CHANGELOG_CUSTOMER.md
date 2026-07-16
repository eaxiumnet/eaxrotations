# EaxRotations Changelog

## v2.7.9 — Classic Vanilla Re-check + Hunter Aimed Shot (July 16, 2026)

> **Release:** v2.7.9  
> **Game:** Classic Era / Vanilla (1.15) + TBC Classic (2.5.5)

### What you’ll notice

- **All 31 Classic Era combat specs re-checked** against wowsims classic APLs and Classic guides (Wowhead, Icy Veins, Warcraft Tavern).
- **Classic Hunters (BM + Survival)** now use **Aimed Shot** as the primary cast (as in Classic sims), not only Multi/Arcane.
- **Classic Destruction Warlocks** no longer burn soul shards on continuous Soul Fire mid-fight — Soul Fire is reserved for the execute window (with Shadowburn still preferred).

Reload for **v2.7.9**.

---

## v2.7.8 — Full TBC Spec Re-check + Destro Execute (July 16, 2026)

> **Release:** v2.7.8  
> **Game:** The Burning Crusade Classic (2.5.5) + Classic Era (1.15)

### What you’ll notice

- **All 29 TBC class specs re-checked** against pro/simulator sources (wowsims APLs, Wowhead, Icy Veins, Warcraft Tavern). Priorities and playstyle settings already matched guides for 28 specs.
- **Destruction Warlock execute fixed** — Shadowburn now correctly casts in the execute window instead of losing every GCD to Shadow Bolt while you stand still. You should see Shadowburn land on low-HP targets when you have a soul shard.

Reload for **v2.7.8**.

---

## v2.7.7 — Maul Spam + Swing Timer (July 16, 2026)

> **Release zip:** [eaxrotations.zip](https://github.com/eaxiumnet/eaxrotations/releases/tag/v2.7.7)
> **Game:** The Burning Crusade Classic (2.5.5) + Classic Era (1.15)

### What you’ll notice

- **Maul no longer spams the cast log** — once Maul is queued on your next swing, the rotation waits for that swing instead of re-casting every frame.
- **Swing timer debug spam fixed** — the helper was using the wrong clock (huge ~70k second values). Timing data is sane again.

Reload for **v2.7.7**.

---

## v2.7.6 — Bear Tank Stability (July 16, 2026)

> **Release zip:** [eaxrotations.zip](https://github.com/eaxiumnet/eaxrotations/releases/tag/v2.7.6)
> **Game:** The Burning Crusade Classic (2.5.5) + Classic Era (1.15)
> **Focus:** Druid Bear cast targets and form stability

### What you’ll notice

- **Swipe hits mobs again** — Swipe was accidentally aimed at you (your character name in the cast log), which made it spam without landing. It now uses your enemy target like Maul and Bash.
- **No more Bear Form / Mark of the Wild thrash** — Out-of-combat buffs (Mark, Gift, Thorns) no longer fire while you are in bear form. Those spells cancel bear form in TBC and were causing a shift loop.
- **Smoother Maul timing data** — Bad swing-timer values from the game helper are ignored so the rotation does not lock up on garbage numbers.

Reload the plugin (or replace the folder from the release zip) to pick up **v2.7.6**.

---

## v2.7.5 — Bear Tank Low-Level Fixes (July 16, 2026)

> **Release zip:** [eaxrotations.zip](https://github.com/eaxiumnet/eaxrotations/releases/tag/v2.7.5)
> **Game:** The Burning Crusade Classic (2.5.5) + Classic Era (1.15)
> **Focus:** Druid Bear while leveling

### What you’ll notice

- **Earlier Maul** — Before you learn Mangle, the rotation no longer sits idle until ~50 rage. Maul starts earlier based on your level (around the mid-20s rage at level 17). Your Maul Rage slider still acts as a maximum with the full tank kit.
- **Swipe on small packs** — Two or more enemies can be Swiped even before Lacerate. No more waiting on stacks you cannot apply yet.
- **Smarter Demoralizing Roar** — Demo Roar should stop wasting rage/GCD on a single mob that is about to die. Multi-pull Demo is unchanged.

Reload the plugin (or replace the folder from the release zip) to pick up **v2.7.5**.

---

## v2.7.4 — Smarter Healing, Tanks, and Warrior Dumps (July 16, 2026)

> **Release zip:** [eaxrotations.zip](https://github.com/eaxiumnet/eaxrotations/releases/tag/v2.7.4)
> **Game:** The Burning Crusade Classic (2.5.5) + Classic Era (1.15)
> **Tested with:** Full rotation suite + shared module unit tests

---

### What you get in this release

Several advanced features that were already in the product had never been turned on at startup. This release connects them so they actually run in-game.

#### Healers
- **Smart stop-cast** now runs: if your target is topped mid-cast, the heal can cancel to save mana and GCD.
- Party **pet healing** can factor into triage when enabled.
- Health-prediction helpers are available for future predictive heal sizing.

#### Tanks
- **Snap threat** on combat start for Protection Warrior and Protection Paladin (high-threat opener).
- **Prot Warrior stance manager** can auto-pick Battle / Defensive / Berserker based on fight state and settings.

#### Warriors (Arms / Fury)
- Smarter **Heroic Strike / Cleave** rage dumps that avoid starving core abilities.

#### Melee and Hunters
- More accurate **swing timing** data at load (seal/twist diagnostics, hunter adaptive timing support).

#### Warlocks
- Shared dispel tooling is available for friendly **Devour Magic** group help.

---

## v2.5.2 — API Standardization & Code Quality (July 9, 2026)

> **Release zip:** [EaxRotations-v2.5.2.zip](https://github.com/eaxiumnet/eaxrotations/releases/tag/v2.5.2)
> **Game:** The Burning Crusade Classic (2.5.5) + Classic Era (1.15)
> **Tested with:** 249 rotation suites + 13 leveling suites (all passing)

---

### 🔧 Under the Hood: API Usage Standardization

We completed a full audit of every Lua file in EaxRotations to ensure consistent, safe API usage across the entire codebase.

**What was checked:**
- All 29 rotation specs + 9 leveling specs + 85 shared modules + 6 core files + 9 middleware files
- Banned APIs (`ffi.C`, `io.popen`, `os.execute`, `debug.*`) — none found in production
- Distance calculations — all use squared distance (no slow `math.sqrt`)
- Menu access — all properly nil-guarded (no bare `menu.x:get()` outside schema files)
- API caching — hot-path calls cached at module load (Pattern 2)

**What was fixed:**
- Added descriptive headers to 14 files (3 core files + 5 core modules + 4 class helper files + `header.lua`)
- Fixed 1 instance of uncached API access in Druid Cat form detection
- Extended compliance test to cover 103 shared/core/middleware files

**What this means for you:** more consistent behavior, easier maintenance, and fewer edge-case bugs.

---

## v2.5.1 — Healer Overheal Gate & Downrank Penalty (July 9, 2026)

> **Release zip:** [EaxRotations-v2.5.1.zip](https://github.com/eaxiumnet/eaxrotations/releases/tag/v2.5.1)
> **Game:** The Burning Crusade Classic (2.5.5) + Classic Era (1.15)
> **Tested with:** 249 rotation suites + 13 leveling suites (all passing)

---

### 🏥 Healer Improvements

#### Smarter Overheal Protection

The overheal gate now accounts for **downranked heals**. When you cast a lower-rank heal (e.g., Holy Light Rank 4 instead of Rank 11), the gate correctly estimates the smaller heal size and is less likely to block it unnecessarily.

**Specs affected:**
- **Holy Paladin** — Holy Light (R4/R7/R9/R11) and Flash of Light
- **Holy Priest** — Greater Heal and Flash Heal (tiered ranks)
- **Discipline Priest** — Greater Heal, Flash Heal, Binding Heal, Circle of Healing, Prayer of Healing
- **Restoration Shaman** — Healing Wave (tiered ranks)

**What this means for you:** fewer "heal was blocked when it shouldn't have been" moments, especially at low mana when you're casting downranked spells to conserve.

---

## v2.5.0 — Spec Standardization & Polish (July 8, 2026)

> **Release zip:** [EaxRotations-v2.5.0.zip](https://github.com/eaxiumnet/eaxrotations/releases/tag/v2.5.0)
> **Game:** The Burning Crusade Classic (2.5.5) + Classic Era (1.15)
> **Tested with:** 242 rotation suites + 13 leveling suites (all passing)

---

### 🏗️ Under the Hood: Complete Spec Standardization

Every one of the 29 class specializations has been rebuilt on a shared foundation that makes the rotation engine more reliable, easier to maintain, and safer across every spec. This is a massive internal refactoring — you won't see a single button change, but every spec is now more robust against edge cases (nil spell IDs, missing buff data, broken API responses on private servers).

**What this means for you:** fewer "the bot just stopped" moments, faster bug fixes in the future, and consistent behavior across all specs.

---

### ⚔️ Class & Spec Changes (since v2.3.11)

#### Druid
- **Bear:** Completely rebuilt as a pure bear-form tank rotation. No more accidental form-shifting mid-combat. Demoralizing Roar and Faerie Fire (Feral) debuffs maintained automatically. Swipe for AoE/cleave, Maul as rage dump. Frenzied Regen and Barkskin used defensively.
- **Cat:** Powershift energy threshold raised from 20 to 25 (closer to optimal play). New snapshot module prevents overwriting stronger Rip/Rake bleeds with weaker ones.
- **Balance:** Starfire is now the primary nuke (was Wrath). Wrath used only for mana conservation. Mana gem strategy added for longer fights.

#### Hunter
- **All specs:** Aspect of the Viper now kicks in at 5% mana (was 20%) and switches back to Hawk at 25% (was 30%) — aligned with simulation data. Aimed Shot opener fires at ≤0.5s before pull. Auto-shot timer prevents clipping on all three specs. Melee weaving (Raptor Strike + Wing Clip at melee range) available on all specs.
- **Beast Mastery:** Bestial Wrath now aligns with Bloodlust/Heroism/Drums power windows instead of firing on cooldown. Kill Command is off-GCD and top priority. Intimidation pet stun included. Rapid Fire and Readiness used intelligently.
- **Marksmanship:** Trueshot Aura maintained automatically. Silencing Shot included for interrupt support.
- **Survival:** Wyvern Sting, Explosive Trap, and Immolation Trap included. Concussive Shot for kiting, Misdirection support in pull windows.

#### Mage
- **Arcane:** Full burn/conserve rotation — Arcane Blast x3 into Frostbolt conserve phase. Presence of Mind used at the end of Arcane Power. Mana gem usage aligned with simulation data.
- **Fire:** Combustion aligned with Bloodlust/Drums/major cooldown windows. Scorch debuff maintained automatically.
- **Frost:** Frostbolt as primary filler with Shatter combos.

#### Paladin
- **Holy:** Triage-scored target selection picks the most urgent heal target. Downranked Holy Light (R4/R7/R9/R11) chosen automatically based on health deficit. Divine Favor + Holy Shock guaranteed-crit burst combo. Light's Grace chain maintained for haste uptime. Auto-blessing (Light/Wisdom/Kings), auto-aura (Concentration/Devotion/Resistance), and auto-cleanse. Seal-twist for Judgement of Wisdom/Light support on bosses.
- **Protection:** Holy Shield maintained at 100% uptime with charge tracking. Consecration downranked based on mana. Avenger's Shield used as both opener and combat ability. Seal of Wisdom auto-swap at low mana. Righteous Defense peels allies. Blessing of Sanctuary and Devotion Aura maintained OOC.
- **Retribution:** Post-swing Judgement prevents seal clipping. Seal twist diagnostics log twist quality. Seal of Blood/Command/Martyr supported with auto-detection. Avenging Wrath and engineering bombs included.

#### Priest
- **Holy:** Triage-scored healing with downranked Greater Heal/Flash Heal. Lightwell, Circle of Healing, and Guardian Spirit included. Friendly target support.
- **Discipline:** Power Word: Shield absorb tracking with smart refresh. Pain Suppression for tanks. Divine Spirit and Power Infusion support. Friendly target support.
- **Shadow:** Shadowfiend timing aligned with fight length. Starshards moved above Mind Flay in priority (was dead code!). Multi-DoT engine maintains Vampiric Touch and Shadow Word: Pain on multiple targets. Inner Focus + Mind Blast combo. Vampiric Embrace maintained on bosses.

#### Rogue
- **Combat:** Blade Flurry now requires Slice and Dice active before use. Adrenaline Rush gated at ≤40 energy. SnD maintenance at all combo point levels.
- **Assassination:** Mutilate requires daggers in both hands. Envenom used at 4+ combo points. Cold Blood + Envenom combo.
- **Subtlety:** Hemorrhage debuff maintained. Shadowstep + Ambush opener. Premeditation and Preparation for cooldown resets. Shiv for poison application.

#### Shaman
- **Elemental:** Lightning Bolt as primary nuke with Chain Lightning on cooldown. Clearcasting priority ensures Elemental Mastery + Chain Lightning combos. Totem of Wrath maintained. Lightning Shield throttle prevents recast spam.
- **Enhancement:** Totem twisting (Windfury/Grace of Air) on 10s cycle with mana floor. Auto weapon buffs by level (Rockbiter → Flametongue → Windfury). Intelligent shield switching (Lightning Shield >60% mana, Water Shield <40%). Shamanistic Rage aligned with power windows.
- **Restoration:** Earth Shield and Riptide maintained. Chain Heal smart-targeting. Triage-scored healing. Healing Way maintained on tanks.

#### Warlock
- **Affliction:** Drain Soul + Shadowburn execute at <25% HP. Immolate priority raised. Curse of Shadows/Agony/Doom applied appropriately. Life Tap managed for mana. Felhunter auto-summoned.
- **Demonology:** Demonic Sacrifice support. Felguard maintained. Soul Link for survivability. Metamorphosis support.
- **Destruction:** Shadowburn execute. Immolate → Conflagrate combo. Soul Fire with Decimation procs. Mana gem usage.

#### Warrior
- **Arms:** Mortal Strike on cooldown, Overpower on dodge procs (CLEU-backed detection), Execute below 20%. Hamstring for kiting. Sweeping Strikes for AoE. Healthstone support.
- **Fury:** Bloodthirst on cooldown, Whirlwind for AoE. Opt-in Overpower weaving via stance dance. Rampage maintained. Death Wish aligned with Bloodlust/Heroism. Healthstone support.
- **Protection:** Shield Slam and Revenge on cooldown. Devastate for Sunder Armor stacks. Thunder Clap and Demoralizing Shout maintained. Shield Block for mitigation. Last Stand and Shield Wall as emergency cooldowns.

---

### 🛠️ New Features & Systems (since v2.3.11)

- **Cooldown Planner:** Personal offensive cooldowns (Death Wish, Avenging Wrath, Combustion, Bestial Wrath, etc.) now align with Bloodlust/Heroism/Drums power windows instead of firing on internal cooldown. Conservative timeouts and TTD fallbacks prevent wasted cooldowns on dying targets.

- **Healthstone Automation:** All 29 specs automatically use Healthstones below 28% HP in combat. No configuration needed.

- **Combat Mode Override:** Force Single-Target, AoE, or Auto mode on any spec. When set to Auto, the rotation picks the right mode based on enemy count.

- **Snap Threat:** Protection Paladins and Warriors use an immediate high-threat opener (Avenger's Shield / Shield Slam) the moment combat starts.

- **Stop-Cast Engine:** Healers cancel overhealing casts mid-flight to save mana. Works on Holy Paladin, Holy Priest, Discipline Priest, Restoration Shaman, and Restoration Druid.

- **Pet Handling Overhaul:** Hunters, Warlocks, and Mages (Water Elemental) now have full pet automation — attacks, taunts, Growl, special abilities, and auto-heal (Mend Pet / Health Funnel). Pets switch between aggressive/defensive/passive based on combat state and HP.

- **Triage Scoring:** Healers use a scoring system that factors in health deficit, role (tank > healer > DPS), and distance to pick the best heal target — not just the lowest HP.

- **Swing Timer:** Melee specs now track auto-attack swings to avoid clipping. Parry-haste awareness for tank specs. Overpower procs detected from combat log events.

- **Engineering Bomb Support:** All specs can use engineering bombs (Sapper Charges, Grenades) aligned with AoE windows.

- **Fully Automated Dispel:** 5-class support (Paladin Cleanse, Priest Dispel Magic, Druid Remove Curse, Shaman Purge, Mage Remove Curse). Tank-gated with 3s throttle to prevent spam.

---

### 🎣 EaxFishing v2.5.1 (bundled)

- Debug logging now gated behind a master toggle — no more console spam
- Stealth suspicion level decays over time when no players are nearby (fixes bot freezing after a few minutes of player traffic)
- Suspicion fully resets when you toggle fishing off and back on
- Verbose status line (~1.5s interval) shows stealth multiplier, suspicion, encounters, and throttle — so you can see why the bot paused
- Bobber bite detection logged only on actual bites (no more spam)

---

### 🐛 Bug Fixes (since v2.3.11)

- Out-of-range spells no longer stall the rotation — they fall through to the next priority
- Party buffs and dispels correctly skip range checks so out-of-range allies don't block the rotation
- Pummel, Shadowfiend, and Feed Pet no longer incorrectly apply range restrictions
- Bear Druid no longer attempts cat-form or caster-form spells in combat
- Marksmanship Hunter no longer tries to cast Bestial Wrath (BM-only ability)
- Switching targets correctly resets Time-To-Death tracking
- Pets no longer pull neutral mobs or patrols unintentionally
- War Stomp (Tauren racial) now correctly gated behind range
- Seal twist diagnostics in Retribution Paladin fixed

---

### 📊 Quality Gates (v2.5.0)

| Gate | Result |
|------|--------|
| Rotation test suites | **242 / 242 passing** |
| Leveling test suites | **13 / 13 passing** |
| Spell database audit | **61 TBC + 31 Vanilla files clean** |
| All spell IDs verified | Against DBC client 2.5.5.68101 |

---

### 🔄 Previous Versions

- **v2.4.0** (July 5, 2026) — Wowsims APL alignment for all 15 DPS specs
- **v2.3.15** (July 5, 2026) — Cooldown Planner power-window alignment
- **v2.3.12** (July 4, 2026) — Healthstone automation + pet handling overhaul

---

*For technical release notes, see `RELEASE_NOTES_v2.4.0.md` and `RELEASE_NOTES_v2.3.12.md`.*
