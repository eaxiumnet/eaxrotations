-- day1_campaign_report.md — WoW Forever day-1 rotation campaign: final report.
-- WHAT:  The campaign's closing evidence sheet: scope delivered, final suite
--        counts, battery pins, the day-1-ready spec list, and every open
--        in-game probe.
-- WHEN:  written 2026-09-17 at campaign close-out (branch
--        feat/forever-era-2026-09-15, client 1.60.1.69893).
-- WHY:   The mission's REPORT BACK deliverable: one durable place carrying
--        the numbers the per-unit docs scatter across kits, the CHANGELOG
--        and the scorecard.
-- SAFETY: Read-only facts; every count below is reproducible with the
--        commands named beside it.

# Forever day-1 rotation campaign — final report

## Scope delivered

- **35 `_forever` files** (26 spec deltas + 9 leveling deltas) across
  **47 commits** on `feat/forever-era-2026-09-15`.
- **All 29 specs resolve a Forever rotation path**: deltas where the kit
  changed mechanics; the loader's `_forever -> _vanilla` fallback
  (`EaxRotations/shared/class_loader_sylvanas.lua`, the `is_forever` branch)
  for paladin protection/retribution, shaman restoration, druid caster and
  warrior kebab (coverage scan: every `*_vanilla.lua` checked for a sibling
  `*_forever.lua`).
- **Zero numeric spell-ID literals** in any `_forever` file (enforced by
  `run_forever_audit_tests.lua` in LIVE DBC mode); spells resolve through
  the bridge mirrors by name, nil = dormant.
- **Bridge mechanisms added this campaign** (each with a permanent audit
  self-test pin): `CLASS_LESS_BUFF_NAMES` (Shadow and Flame's window auras),
  and new `BUFF_OVERRIDES` / `MAXRANK_OVERRIDES` / `MIRROR_NAME_OVERRIDES`
  entries — Decimation 440873, Divine Aegis 431624, Prayer of Mending
  1240849, Thousand Cuts 1310723, Cutthroat 462707, Penance 1316995,
  Fire Nova 408345, Berserk 417141.

## Final suite counts

| Runner | Count | Command |
|---|---|---|
| Rotation suites | **597 / 597 passing** | `lua EaxRotations/tests/run_rotation_tests.lua --quiet` |
| Leveling suites | **48 / 48 passing** | `lua EaxRotations/tests/run_leveling_tests.lua --quiet` |
| WotLK suites | **82** | `lua EaxRotations/tests/run_wotlk_tests.lua --quiet` |
| Forever spell audit | **35 files, 0 invalid** (LIVE DBC) | `lua EaxRotations/tests/run_forever_audit_tests.lua` |
| Forever battery | Load failures 0, strict | `lua EaxRotations/tests/behavioral_audit.lua forever` |
| Pre-commit gate | **19 / 19 passed** | `tools/pre-commit` (runs on commit) |
| verify_all | **44 components green (exit 0)** | `lua EaxRotations/tests/run_verify_all.lua` |
| Scorecard | in sync | `lua tools/spec_scorecard.lua --check` |
| Doc counts + badges | in sync | `lua tools/doc_suite_count_check.lua`, `lua tools/update_badges.lua --check` |

## Battery pins (strict per era)

TBC 11 · WotLK 0 · Vanilla 9 · SoD 14 · **Forever 9** — the forever
never-inventory (lane-for-lane identical to vanilla's, pinned in
`tools/spec_scorecard.lua FOREVER_LANE_CLASS`):

druid bear FaerieFirePull + PrePullEnrage · mage fire/frost ManaGemConjure ·
mage leveling ConjureManaGem · priest holy EncounterReactions · priest
leveling Fade · shaman elemental WrathOfAirTotem · warlock affliction
RacialArcaneTorrent.

Every new Forever lane fires in at least one forever scenario (Pattern-17
doctrine); no unpinned never-lane exists in any era.

## Day-1-ready specs

All 29 specs + all 9 leveling deltas. Deltas: paladin holy · shaman
enhancement/elemental · mage fire/arcane/frost · druid cat/bear/balance/
resto · warrior fury/protection/arms · hunter survival/beast mastery/
marksmanship · warlock affliction/demonology/destruction · priest
discipline/holy/shadow/smite · rogue assassination/subtlety/combat ·
leveling for all nine classes.

## Open in-game probes (every assumption still needing a check)

- **Rogue constant-regen energy (P2 #3) — CLOSED 2026-09-18** by the
  beta-verification pass: the Icy Veins rogue guides + class overview
  confirm constant-regen, and the thresholds were re-derived from DBC
  SpellPower facts (Venom 25e+1CP, Hemorrhage 35e − 3/stack, Mutilate 60e,
  Eviscerate 35e). The spec deltas now gate on real costs + explicit
  reserves instead of the tick-pulse pooling fiction; the leveling
  builder's real-cost gate was already complete. Re-open only if an
  in-game parse contradicts constant regen.
- **Bane-vs-Curse slot mechanics** — the warlock leveling amp lane
  (Bane of Agony + Curse of the Elements) churns if the slots turn out
  shared; remove the lane if so. Bane of Havoc's 1-target enforcement too.
- **Demonic Pact** — a third demon (Voidwalker) may be summoned without
  cancelling a school aura (the text implies yes).
- **Shadow and Flame window durations + Decimation token values**
  ($m1/$m3/$m4) and whether the Decimation proc survives leaving execute
  range.
- **Prayer of Mending** — in-game jump count (kit: 5) and jump radius;
  Litany of Light's refund %; Binding Heal's threat reduction.
- **Penance** — tick count/interval and per-tick crit; whether the +15%
  Power in Light applies per tick.
- **Soul Warding** — the 4s PW:S category CD truly reaching zero.
- **Improved Ghost Wolf** — the "usable everywhere" scope in-game.
- **Forever Mutilate** — confirm a front-facing cast lands (the client text
  has no behind clause, unlike the TBC row).
- **Tree of Life 439745** — form semantics (shapeshift? duration? aura row?).
- **Eclipse** — the charge→haste value and consumption behaviour.
- **BaseLevel-0 bridge gaps** (recorded, not laned): Fingers of Frost,
  Early Demise, Aspect of the Beast, Bloodthrill; Hack and Slash's
  class-less row; Demonic Sacrifice's class-less cast row (sacrifice stays
  manual).
- **Per-weapon passives** (Hack and Slash 13960) — in-game values.
- **Paladin** — Holy Strike's exact low-rank cooldown and the @6 rank id;
  unlearned-rank readiness behaviour.
- **Blade Dance 400012** (rune-granted) — post-campaign backlog candidate.
- **Static-data caveat**: no hotfix cache for build 69893 yet (data is
  build-stamped 69800); numbers may shift at launch, and ~24 icons plus
  some sparse item rows stay placeholder until Blizzard pushes hotfixes.

---

## Beta-verification pass — day 2 (2026-09-18)

Executed against live-beta guidance (Icy Veins per-spec guides, 2026-09-15/16
refresh) with every numeric claim cross-checked against the beta DBC
(1.60.1.69893) before any lane moved:

| Unit | Outcome | Proof |
|------|---------|-------|
| Rogue assassination | Venom window re-derived to the DBC cost (25e + 1CP, rows 314521/314522) + 20e CP-buffer; the old pooled gate blocked at Venom's own cost boundary | unit pins load-bearing by revert; 40-energy battery scenario discriminates old vs new |
| Rogue combat + subtlety | Thousand Cuts gates on DBC effective cost (Hemorrhage 35 − 3/stack) + 10e reserve (fires 30e @ 5 stacks); combat RB Eviscerate-35 gate DBC-verified, unchanged | unit pins by revert; 30e/5-stack TC scenario |
| Rogue leveling | Mutilate 60e real-cost gate confirmed as the complete energy model under constant regen | unit pins |
| Priest | Icy Veins Priest overview is live (Rainy, 2026-09-16): Power Infusion "requires Penance" is a talent prerequisite (cast row 10060 unchanged); Improved Healing −14% family now covers Penance + PoM (passive); the four race-gated priest spells (Contingency Plan/Gnome, Divine Grace/Human, Chastise/Dwarf, Dark Sacrifice/Undead) resolve in the bridge — recorded as leveling lane candidates pending in-game race detection | DBC + bridge resolution log in the priest kit |
| Warlock | Drain Hope vs Wrack closed: no client Drain Hope row; capstone ships as Wrack (1316697); shipped affliction lanes already maintain Wrack by name | DBC name scan + kit record |
| Battery integrity | Pattern-17 gap closed: the class-map mock lacked Hemorrhage/Backstab, so the subtlety ThousandCuts and combat PuncturingWounds lanes had never loaded in any battery run; mock fixed, lanes register and fire | battery now shows subtlety 29 / combat 21 strategies, never-lists empty |

End state: rotation 598/598 · leveling 48/48 · WotLK 82/82 · forever audit
35 files / 0 invalid · battery strict (forever never=9) · scorecard, badges,
doc counts in sync · verify_all exit 0 (44 components).
