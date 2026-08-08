# Vanilla + TBC leveling rank sweep (2026-08-08)

**Scope:** replicate the WotLK `STALE_TOP` enforcement against the **vanilla**
(`*_vanilla.lua`) and **TBC** (`*_sylvanas.lua`) leveling files, using the era
class ladders + wowhead bridges as ground truth.

**Headline:** the "spec files were clean" premise was **wrong for vanilla**. The
leveling copies had 6 stale TBC tops — and once the audit's `TBC_IDS` was
extended with the full TBC rank block, **14 vanilla spec files** surfaced with the
same contamination (26 distinct TBC-era spell IDs total). TBC leveling files were
clean (only the platform-consistent `348700` Seal of the Martyr ID, which the TBC
spec files use identically).

---

## 1. Method

Ground truth is the **era-correct class ladders** in `classes/*/class_sylvanas.lua`
(TBC-era spell_action ladders, verified by the 41-file WotLK audit) plus the
wowhead bridges. A ladder like hunter `SerpentSting = {27016, 25295, 13555, ...}`
proves `25295` is a TBC rank (r9) sitting **above** the vanilla max `13555` — so
any `*_vanilla.lua` list carrying `25295` on top is stale-contaminated.

> Note: wowhead **Classic** page-existence is *not* a discriminator — the 1.15 Era
> client DB contains non-trainable ranks, so `25290/25295/25315` etc. resolve 200
> there while `27150` 404s. The era class ladders are authoritative; every flagged
> ID below is a TBC rank above the vanilla max in those ladders.

## 2. Leveling files — 6 stale TBC tops (fixed)

| File | Table | Dropped TBC ID | Vanilla max now on top |
|---|---|---|---|
| `hunter/leveling_vanilla.lua` | `ASPECT_HAWK_BUFF` | 25296 (Aspect of the Hawk r7) | 14322 |
| `hunter/leveling_vanilla.lua` | `SERPENT_STING_IDS` | 25295 (Serpent Sting r9) | 13555 |
| `paladin/leveling_vanilla.lua` | `BLESSING_MIGHT_BUFF` | 25291 (Blessing of Might r7) | 19838 |
| `paladin/leveling_vanilla.lua` | `BLESSING_WISDOM_BUFF` | 25290 (Blessing of Wisdom r5) | 19854 |
| `paladin/leveling_vanilla.lua` | `RETRIBUTION_AURA_BUFF` | 27150 (Retribution Aura r6) | 10301 |
| `priest/leveling_vanilla.lua` | `RENEW_BUFF` | 25315 (Renew r10) | 10929 |

## 3. Spec files — 14 files, 26 TBC IDs (fixed)

| File | Table / action | TBC IDs dropped | Vanilla max kept |
|---|---|---|---|
| `hunter/beast_mastery_vanilla.lua` | `SERPENT_STING_IDS` / `ASPECT_HAWK_IDS` | 25295, 25296 | 13555 / 14322 |
| `hunter/marksmanship_vanilla.lua` | `SERPENT_STING_DEBUFF` / `ASPECT_HAWK_BUFF` | 25295, 25296 | 13555 / 14322 |
| `hunter/survival_vanilla.lua` | `SERPENT_STING_DEBUFF` / `ASPECT_HAWK_BUFF` | 25295, 25296 | 13555 / 14322 |
| `druid/caster_vanilla.lua` | `Starfire` / `HealingTouch` / `Rejuvenation` / `REJUV_BUFF` | 25298, 25297, 25299 | 9876 / 9889 / 9841 |
| `druid/resto_vanilla.lua` | `REJUVENATION_BUFF` | 25299 | 9841 |
| `paladin/holy_vanilla.lua` | `HolyLightRank11` + `HolyLightRank9` (**copy-paste bug: both were 25292**) | 25292 → 10329 | 10329 |
| `paladin/holy_vanilla.lua` | `GreaterBlessingOfLight` / `BUFF_BLESSING_LIGHT` | 25890 | 19979/19978/19977 |
| `paladin/holy_vanilla.lua` | `BUFF_BLESSING_WISDOM` | 25918, 25894, 25290 | 19854 |
| `paladin/holy_vanilla.lua` | `BUFF_BLESSING_KINGS` | 25898 | 20217 |
| `paladin/holy_vanilla.lua` | `PHYSICAL_FOCUS_DEBUFFS` | 25273, 25274 (Intercept Stun) | 26017, 12809 (Classic-legal) |
| `paladin/retribution_vanilla.lua` | `BLESSING_MIGHT_BUFF` | 25291, 25782 | 19838 |
| `priest/discipline_vanilla.lua` | `DIVINE_SPIRIT_BUFF` | 25312 | 14819 |
| `priest/discipline_vanilla.lua` | `GREATER_HEAL_MAX` | 25314 → 10965 | 10965 |
| `priest/discipline_vanilla.lua` | `POWER_WORD_FORTITUDE_BUFF` | 25389 | 10938 |
| `priest/discipline_vanilla.lua` | `RENEW_BUFF` | 25315 | 10929 |
| `priest/smite_vanilla.lua` | `RENEW_BUFF` | 25315 | 10929 |
| `warlock/affliction_vanilla.lua` | `CORRUPTION_DEBUFF` / `IMMOLATE_DEBUFF` | 25311, 25309 | 11672 / 11668 |
| `warlock/demonology_vanilla.lua` | `CORRUPTION_DEBUFF` / `IMMOLATE_DEBUFF` | 25311, 25309 | 11672 / 11668 |
| `rogue/subtlety_vanilla.lua` | `Feint` | 25302 | 11303 |
| `rogue/assassination_vanilla.lua` | `DEADLY_POISON_DEBUFF` | 25349, 25347 | 11356 block |
| `warrior/arms_vanilla.lua` | `HeroicStrike` | 25286 | 11567 |

**Not touched (verified Classic-legal or intentional):**
- `25771` Forbearance, `25780` Righteous Fury, `26573`/`20116` Consecration ranks,
  `26017` Vindication, `12809` Concussion Blow, `27819` Mana Detonation (KT),
  `29166` Innervate, `28271/28272` — all exist in Classic; several are already in
  the audit's `THRESHOLD_ALLOWLIST`.
- `{ 20554, 26297 }` Berserking dual-ID pair in `shaman/enhancement_vanilla.lua` —
  `20554` is Classic-legal and the same pair is used verbatim in the TBC
  `enhancement_sylvanas.lua`; intentional fallback, not a stale top.
- `348700` Seal of the Martyr in TBC `paladin/leveling_sylvanas.lua` — platform-
  consistent (identical in `class_sylvanas.lua` + `retribution_sylvanas.lua`).

## 4. Audit hardening

`tests/run_vanilla_audit_tests.lua`:
- `TBC_IDS` extended 96 → **121** entries (26 new: 25273, 25274, 25286, 25290,
  25291, 25292, 25295, 25296, 25297, 25298, 25299, 25302, 25309, 25311, 25312,
  25314, 25315, 25347, 25349, 25389, 25782, 25890, 25894, 25898, 25918, 27150),
  each with its vanilla max documented.
- Scan list extended from 31 spec files to **40 files** (all 9 `leveling_vanilla.lua`
  copies added), so a stale TBC top in a leveling copy can no longer silently return.

## 5. Verification

- `luac -p` clean on all 18 edited files.
- `run_vanilla_audit_tests.lua` → **40/40 clean** (was 7 FAIL after the first
  hardening pass, before the spec fixes).
- `run_vanilla_existence_audit.lua` → **40/40 clean**.
- `run_leveling_tests.lua` → **31/31**.
- `run_rotation_tests.lua` → **461/466** — same 5 pre-existing SOD/env gaps
  (`test_aoe_range_audit_contracts`, `test_sod_rotation_matrix`,
  `test_sod_source_audit`, `test_id_audit_report`,
  `test_sod_warlock_warrior_adversarial`), **zero new failures**.
- `test_vanilla_spell_ladders.lua` → **236/236**.

## 6. Bonus catch

`paladin/holy_vanilla.lua` `HolyLightRank11` **and** `HolyLightRank9` were both
defined as `spell_action({ 25292 })` with label `"HolyLightRank9"` — a copy-paste
bug AND a TBC rank. In Classic, `25292` is not learnable, so the vanilla smart-heal
emergency branch (hp ≤ EMERGENCY_HP / large deficit) would have attempted a
non-existent spell. Both now resolve to the vanilla max rank `10329`.

---

## 7. TBC mirror sweep (WotLK-era leaks into *_sylvanas.lua) — 2026-08-08

**Scope:** every `*_sylvanas.lua` TBC spec/leveling/class file + the shared
`class_sylvanas.lua` tables, scanned for WotLK-era (≥40000 / 6-digit) spell IDs.
Ground truth: wowhead TBC + the project TBC bridge.

### Confirmed leaks (fixed)

| ID | Spell | Where | Disposition |
|----|-------|-------|-------------|
| 50334 | Berserk (WotLK druid) | `druid/cat_sylvanas.lua` | **Removed** — whole lane (state fields, buff read, matcher, strategy) deleted; TBC 404, absent from 2.5.x client. |
| 61305 | Polymorph (Black Cat) | `priest/healing_sylvanas.lua` | **Removed** from dispel list |
| 61721 | Polymorph (Rabbit) | `priest/healing_sylvanas.lua` | **Removed** from dispel list |
| 61780 | Polymorph (Turkey) | `priest/healing_sylvanas.lua` | **Removed** from dispel list |

### Verified NOT leaks (kept)

- **348700 Seal of the Martyr** (paladin ×3) + **31892 Seal of Blood**: resolve on
  wowhead TBC — TBC-Classic client renumbers, platform-consistent. Kept.
- **45438 Ice Block** (mage ×4): resolves on wowhead TBC — valid TBC rank. Kept.
- **46561/46279-46481/41303** (Sunwell/BT raid spells): TBC raid content. Kept.
- **Death knight `class_sylvanas.lua`**: WotLK-only IDs but the table is gated
  behind `is_wotlk` — never loads on TBC. Kept.

### Audit hardening

`tests/run_sylvanas_audit_tests.lua`:
- New **`WOTLK_ONLY_IDS`** blocklist (50334, 61305, 61721, 61780) — the bridge is
  full-dataset (all eras), so bridge-membership alone could not discriminate; the
  blocklist fires as `[WOTLK_ONLY]` and can never silently return.
- **Extractor rewritten** to walk every balanced-brace group, catching the leak
  shapes the old pattern extractor missed: `local X = {...}` arrays and
  `define("X", {...})` second-arg tables (both used by the Berserk/polymorph leaks).
- The brace walk is **recursive**, so single-line nested tables like
  `magic = { spell = "DispelMagic", ids = { 988, 527 } }` are fully covered
  (verified with a nested probe: both blocklisted IDs inside nested `ids = {...}`
  groups are flagged). ID range is 1000-999999 so 6-digit IDs reach the
  WOTLK_ONLY/validity checks instead of being masked.

### Extractor regression caught & fixed

The balanced-brace walk initially over-collected **item tables**
(`HEALTHSTONE_IDS`, `MANA_GEM_ITEM_IDS`, `MANA_POTION_IDS`, `DARK_RUNE_IDS`,
`SOUL_SHARD_ITEM`, … — items used via item-click, never cast as spells), causing
~30 false FAILs. Fixed by excluding tables whose **assignment name** ends in
`_IDS`/`_ID`/`_ITEM`/`_ITEMS` **and** contains an item-family keyword
(ITEM/POTION/GEM/SHARD/FOOD/WATER/RUNE/HEALTHSTONE/SOUL). Spell tables that merely
contain a keyword (`MANA_GEM_CONJURE`, `SERPENT_STING_IDS`) are still audited.

### Bonus real find

Isolating the item noise exposed **30443 in `paladin/retribution_sylvanas.lua`
`COMMON_CLEANSE`** — the item index maps it to "Recipe: Transmute Primal Fire to
Earth"; wowhead TBC 404s it as a spell. It could never match a debuff aura, so it
was a dead cleanse entry. **Removed.**

### Verification

- `luac -p` clean on all edited files.
- `run_sylvanas_audit_tests.lua` → **61/61 clean** (after the extractor fix;
  previously ~30 FAILs of pure item noise + the 1 real 30443 hit).
- WOTLK_ONLY probe: injected `{ 50334 }`/`{ 61305 }` into a scanned file →
  both flagged `[WOTLK_ONLY]`, probe reverted.
- `run_rotation_tests.lua` → **461/466** (same 5 pre-existing SOD/env gaps).
- `run_leveling_tests.lua` → **31/31**.
- Cat suite re-verified 31/31 after Berserk lane removal.

---

## 8. Bridge level-column cross-check (2026-08-08)

Cross-checked every fixed vanilla table top against the vanilla bridge's
**level column** (`wowhead_data_bridge_spell_index_vanilla_sylvanas.lua`) to
confirm each kept top is the highest Classic-learnable rank for its family.

### Verdict: 18/18 fixed families confirmed, zero kept tops wrong

Every kept top's bridge learn level is **<= 60** (reachable in Classic) and
matches the documented Classic max for that family. No fixed table needed a
further top correction. Kept tops re-verified per family (level column):

- Aspect of the Hawk 14322 (58) · Serpent Sting 13555 (58)
- Blessing of Might 19838 (52) · Blessing of Wisdom 19854 (54)
- Retribution Aura 10301 (56) · Renew 10929 (56) · Greater Heal 10965 (58)
- Holy Light 10329 (54) · Starfire 9876 (58) · Healing Touch 9889 (56)
- Divine Spirit 14819 (50) · Rejuvenation 9841 (58) · Feint 11303 (52)
- Immolate 11668 (60) · Corruption 11672 (54) · Deadly Poison 11356 (54)
- Power Word: Fortitude 10938 (60) · Heroic Strike 11567 (56)

**One corrected annotation (no code change needed):** the `TBC_IDS` entry for
`25289` claimed "Classic max = 2048" — wrong on both counts: per the warrior
TBC ladder 25289 is **rank 7** (lvl 60), not rank 8, and the true Classic max
is **11551** (rank 6, lvl 52; verified on wowhead Classic, AP 193), while
**2048 is TBC-only** (wowhead Classic 404s it; wowhead TBC shows AP 306).
Comment fixed to `Battle Shout rank 7 (TBC; Classic max = 11551)`.

### Blind spot found and closed: 73 sub-27000 TBC-era ladder IDs

The 27000 threshold rule only catches unknown TBC-era IDs **>= 27000**. The
cross-check surfaced **73 TBC-era ladder ranks below 27000** (bridge learn
level > 60 — impossible in Classic, max level 60) that were invisible to the
audit: 2048 Battle Shout, 3411 Intervene, 25210/25213 Greater Heal,
25221/25222 Renew, 25234/25236 Execute, 25258 Shield Slam, 25269 Revenge,
25372/25375 Mind Blast, 25422/25423 Chain Heal, 26861/26862 Sinister Strike,
26863 Backstab, 26865 Eviscerate, 26884 Garrote, 26978/26979 Healing Touch,
26996 Maul, 26997 Swipe, 26984/26985 Wrath, 26986 Starfire, and 47 more
(priest/shaman/druid/warrior/rogue ladder tops).

- **Verified**: all 73 appear in a TBC class ladder AND have bridge level > 60;
  wowhead spot-checks confirmed TBC-only (25210, 2048, 3411 404 on Classic).
- **Verified**: none of the 73 appear in any live `*_vanilla.lua` file, so
  pinning them is purely additive — no false positives.
- **Fix**: all 73 added to `TBC_IDS` (123 -> 196 entries); new
  `NEW_TBC_IDS_73` list; self-test now asserts all **99 pinned** IDs fire
  (26 sweep + 73 cross-check). `--self-test` PASS, `--probe-stale-top` exit 1
  (expected), full audit **40/40 clean**, mutation test (removing 25210)
  caught by the size assertion.

### Note on 3411 Intervene

3411 Intervene appeared in the gap list with bridge level 70. Intervene was
added in **TBC** (WoW 2.0), not Classic — confirmed wowhead Classic 404s
`spell=3411`. It is correctly pinned as TBC-era.
