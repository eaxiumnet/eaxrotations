# WotLK rank audit (2026-08-08)

**Scope:** every `*_wotlk.lua` rotation + leveling file audited against authoritative
WotLK 3.3.5 spell IDs — wowhead WotLK Classic pages, the wowsims/wotlk APL JSONs
(`ui/<spec>/apls/*.json`), and the wowsims Go sim source (`sim/<class>/*.go`).
Classic vanilla + TBC sweeps were also run for cross-era contamination.

**Result:** 2 classes fully clean (hunter, shaman), 2 clean after fixes (mage, paladin),
and a systemic stale-ladder problem fixed across **22 files / ~40 defines**.

---

## 1. Bug family A — wrong spell ID at the top of a ladder (real live bugs)

`get_spell_id` returns the **first *known*** ID in a define ladder. A wrong ID at the
front is a live mis-cast for any player who happens to know that ID, and a dead lane
for everyone else.

| File | Define | Wrong ID (= what it actually is) | Correct |
|---|---|---|---|
| `paladin/retribution_wotlk.lua` | HammerOfWrath | **48807** = Runic Healing Injector (Engineering consumable!) | **48806** Hammer of Wrath (wowsims `hammer_of_wrath.go` casts 48806) |
| `paladin/leveling_wotlk.lua` | HammerOfWrath | **48807** = Runic Healing Injector | **48806** |
| `warrior/arms_wotlk.lua` | Execute | **47498** = **Devastate** | **47471** Execute max |
| `warrior/fury_wotlk.lua` | Execute | **47498** = Devastate | **47471** |
| `warrior/leveling_wotlk.lua` | Execute | **47498** = Devastate | **47471** |
| `warrior/arms_wotlk.lua` | HeroicStrike | **47497** = Devastate (rank 2) | **47450** Heroic Strike max |
| `warrior/protection_wotlk.lua` | HeroicStrike | **47497** = Devastate (rank 2) | **47450** |
| `warrior/leveling_wotlk.lua` | HeroicStrike | **47497** = Devastate (rank 2) | **47450** |
| `mage/frost_wotlk.lua` | ColdSnap | **12472** = **Icy Veins** (so Cold Snap never fired; Icy Veins reset worked instead) | **11958** Cold Snap |
| `deathknight/leveling_wotlk.lua` | PlagueStrike | **49922** = Wave Crash (NPC frost knockback) | **49921** Plague Strike max |
| `deathknight/leveling_wotlk.lua` | HeartStrike | **55263** = Harpy Dive (NPC spell) | **55262** Heart Strike max (restored missing 55258 rank) |

Note the DK *spec* ladders were already correct (49921 / 55262); only the leveling
copies carried the NPC IDs. Warrior was mis-labeled "clean" by earlier checks because
the stale Devastate IDs were also present in the leveling twin (both-wrong).

## 2. Bug family B — ladders stopped at TBC-era max ranks

The WotLK spec files were templated from TBC and their `define()` ladders top out at
TBC max ranks (e.g. Corruption 27216 instead of 47813). On live WotLK, training
**replaces** old ranks, so `get_spell_id` resolved these to nil → dead filler lanes at
max level. Fix = prepend the verified 3.3.5 max rank (project pattern, already used by
leveling Rupture: "WotLK max rank 48672 prepended").

### Spec files (prepended WotLK max)
- **warlock/affliction**: Corruption +47813, ShadowBolt +47809, CurseOfAgony +47864, DrainSoul +47855, Haunt +59164, UnstableAffliction +47843
- **warlock/demonology**: Corruption +47813, ShadowBolt +47809, Immolate +47811, SoulFire +47825
- **warlock/destruction**: Immolate +47811, Incinerate +47838, SoulFire +47825
- **mage/frost**: Frostbolt +42842, IceLance +42914
- **priest/shadow**: ShadowWordPain +48125, MindBlast +48127, MindFlay +48156, DevouringPlague +48300, VampiricTouch +48160
- **priest/discipline**: PowerWordShield +48066, Renew +48068
- **priest/holy**: Renew +48068, FlashHeal +48071
- **rogue/assassination**: Rupture +48672, Mutilate +48666, Envenom +57993
- **rogue/combat**: SinisterStrike +48638, Eviscerate +48668
- **rogue/subtlety**: Ambush +48691, Backstab +48657, Eviscerate +48668
- **druid/balance**: Wrath +48461, Starfire +48465, Moonfire +48463, InsectSwarm +48468
- **druid/cat**: Rip +49800, Shred +48572, Rake +48574, FerociousBite +48576, MangleCat +48566
- **druid/bear**: MangleBear +48564, Lacerate +48568
- **druid/resto**: Rejuvenation +48441, Regrowth +48443, Lifebloom +48451

### Leveling files (same fixes; these also carry their own stale tops)
- **mage**: IceLance 30455→42914, FireBlast 27079→42873, Pyroblast 33938→42891, ConeOfCold 27087→42931, LivingBomb 44457→55360
- **warlock**: CurseOfAgony 27218→47864, DrainLife 27220→47857, DrainSoul 27217→47855, Haunt 48181→59164, Incinerate 32231→47838, SoulFire 30545→47825, UnstableAffliction 30405→47843
- **priest**: MindBlast 25375→48127, MindFlay 25387→48156, Smite 25364→48123, FlashHeal 25235→48071
- **rogue**: SinisterStrike 26862→48638, Eviscerate 26865→48668, Ambush 27441→48691
- **druid**: Claw 27000→48570, Rake 27003→48574, Shred 27002→48572, Rip 27008→49800, FerociousBite 24248→48576, MangleCat 33983→48566, MangleBear 33987→48564, Lacerate 33745→48568, InsectSwarm 27013→48468, Regrowth 26980→48443

**Audit hardening:** all 36 new max-rank IDs are absent from the wowhead-derived bridge,
so they were pinned in `tests/run_wotlk_audit_tests.lua` `WOTLK_REFERENCE_ALIASES`
(48 → 84 entries, self-test count bumped) — the audit now *requires* the correct ranks.

## 3. APL cross-check (single-target + multitarget)

Strategy priority ORDER was compared against wowsims APL JSONs for every major spec;
**no order changes were needed** — the existing rotation structure already mirrors the
sim APLs. Notable confirmations:

- **Ret paladin** (retribution.apl.json): Crusader Strike → Divine Storm → Exorcism (on Art of War) → Consecration; HoW execute ≤20%. Matches. Consecration 48819 already correct.
- **Mage fire**: Scorch refresh → Pyroblast on Hot Streak → Living Bomb → Fire Blast → Scorch → Fireball. Matches. Arcane: AB to 4-stack → Missiles-on-Barrage → Evocation ≤25% → AB filler. Matches.
- **Mage frost**: Frostbolt 42842 confirmed as the sim cast rank (was 27072 live).
- **Frost DK**: Obliterate 51425 → Frost Strike 55268 → Howling Blast 51411 → Plague Strike 49921 → Blood Boil → Death Coil 49895. All ladder ranks already correct in spec files.
- **Affliction**: Corruption 47813 / SB 47809 / CoA 47864 / UA 47843 / Haunt 59164 all confirmed from the APL.
- **Combat rogue**: Sinister Strike 48638, Eviscerate 48668, Rupture 48672 confirmed.
- **Shadow priest**: SW:P 48125, Mind Blast 48127, Mind Flay 48156, VT 48160, DP 48300 confirmed.
- **Balance druid**: Wrath 48461, Starfire 48465, Moonfire 48463, Insect Swarm 48468 confirmed.
- **Feral cat** (sim/druid/rip.go, mangle.go): Rip 49800, Mangle Cat 48566 / Bear 48564, Shred 48572, Rake 48574, Ferocious Bite 48576, Claw 48570 confirmed.

## 4. Verified-clean / not touched

- **Hunter** (all 3 specs + leveling): already at WotLK max ranks (Serpent Sting 49001, Steady Shot 49052, etc.).
- **Shaman** (all 3 + leveling): all WotLK-era already.
- **Deathknight** spec files: ladders already contain the correct max ranks.
- **Mage fire/arcane** spec files: already at WotLK max ranks (42833/42859/42873/42891/42897/42846/44425).
- **Warrior** arms/fury/prot ladders now correct after the Execute/HeroicStrike swap.
- **Vanilla + TBC sweeps:** no cross-era contamination found (only 4 legitimate high-ID defines).

## 5. Deferred-ladder close-out (follow-up pass)

All deferred ladders were verified and fixed the same day:

| File | Define | Old top | New max (source) |
|---|---|---|---|
| `priest/holy_wotlk.lua` | GreaterHeal | 25213 | **48063** (sim/priest/greater_heal.go; 48072 disproven = Prayer of Healing) |
| `druid/bear_wotlk.lua` | Maul | 26996 | **48480** (wowhead spell=48480 + sim/druid/maul.go) |
| `druid/bear_wotlk.lua` | SwipeBear | 26997 | **48562** (wowhead spell=48562 + sim/druid/swipe.go) |
| `druid/cat_wotlk.lua` | Ravage | 27005 | **48579** (wowhead spell=48579) |
| `druid/leveling_wotlk.lua` | HealingTouch | 26979 | **48378** (wowhead spell=48378) |
| `druid/leveling_wotlk.lua` | SwipeBear | 26997 | **48562** |
| `warlock/leveling_wotlk.lua` | LifeTap | 27222 | **57946** (wowhead spell=57946) |

All 6 new IDs pinned in `WOTLK_REFERENCE_ALIASES` (84 → 90 entries; self-test count bumped).
**Remaining:** `paladin/leveling_wotlk.lua` SealOfRighteousness 21084 — no WotLK max rank confirmed (27159 404's; the spec files use Seal of Vengeance/Command, so this only affects the leveling lane; left as-is).

## 6. Verification

- `luac -p` — 26/26 changed files OK.
- `run_wotlk_audit_tests.lua` — **41/41 clean**, self-test PASS (allowlist 84).
- `run_rotation_tests.lua` — **461/466** (5 failures = pre-existing SOD/env data-file gaps, unchanged).
- `run_leveling_tests.lua` — **31/31 PASS**.

**Net effect:** max-level WotLK players now cast the correct 3.3.5 top ranks (was:
lower-rank casts on classic emulators, nil/dead lanes on rank-replacing emulators),
and Cold Snap / Execute / Heroic Strike / Hammer of Wrath no longer resolve to
wrong-family spells.

## 7. Rank-top enforcement (structural guardrail, same day)

`run_wotlk_audit_tests.lua` now also **enforces that every multi-ID define ladder's
top-of-list ID is a pinned WotLK max rank** — so a stale TBC-era top can never
silently return. While wiring this in, three latent defects were found and fixed:

1. **Dead Pattern 1 (pre-existing bug):** `line:find("define%s*(", pos, true)` used
   the `true` plain-literal flag, so the `%s*` pattern was treated as literal text
   and **never matched real code**. All define-table ID validation and rank-top
   capture ran through Pattern 2 (pure-numeric tables) alone. This also meant
   **single-ID defines** (`define("KillShot", 61006, ...)`) were never validated.
2. **Argument walk:** rewritten to track paren + brace depth and count top-level
   commas, so arg 2 (the ID table) is captured intact for 2- and 3-arg defines.
3. **9 unpinned ladder tops:** the campaign's prepended max ranks were never added
   to the pinned sets — the self-test caught `is_max_rank(47813) == false`. All 9
   are bridge-resident (Frostbolt 42842, Pyroblast 42891, Shadow Bolt 47809,
   Immolate 47811, Corruption 47813, PW:Shield 48066, SW:P 48125, Rupture 48672,
   Haunt 59164) and are now pinned in `WOTLK_BRIDGE_MAX_RANKS` (85 → 94).
4. **15 single-ID defines surfaced** (previously invisible): hunter Kill Shot 61006,
   Explosive Shot 60053 + 60052, shaman Bloodlust 2825, Elemental Mastery 16166,
   Lava Burst 60043, Thunderstorm 59159, Call of the Elements 66842, Fire Nova
   61657, Mana Tide Totem 16190, Chain Heal 55459, Lesser Healing Wave 49276 — all
   verified on wowhead WotLK Classic and pinned in `WOTLK_REFERENCE_ALIASES`
   (92 → 104). These are **real 3.3.5 IDs the wowhead bridge omits** — the audit
   now requires them to be explicitly allowlisted instead of silently accepting
   single-rank spells.

New self-tests cover: `is_max_rank` membership (pinned vs. stale TBC rank), a clean
max-first ladder (0 hits), a stale-first ladder (1 STALE_TOP hit), plus a
`--probe-stale-top` mode for CI sanity checks.

**Verified after enforcement:** `run_wotlk_audit_tests.lua` **41/41 clean**,
self-test PASS (aliases 104 + bridge max ranks 94 = 198 pinned), `--probe-stale-top`
flags id 27072 as expected, rotation **461/466** (same 5 pre-existing gaps), leveling
**31/31**. Cross-checked independently in Python: **zero unpinned ladder tops** remain
across all 41 WotLK files, and the Lua walk was proven to capture tops on real
define-line shapes (Corruption 47813, Frostbolt 42842, KillShot 61006, HolyShock 48821).
