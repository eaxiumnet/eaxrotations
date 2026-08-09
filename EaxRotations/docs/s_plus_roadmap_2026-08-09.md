# S+ Roadmap — all rotations (2026-08-09)

Goal: **every rotation in every era** reaches S+ — defined below — against the
authoritative rotation sources (wowsims APLs, SimC, pro guides), with the
behavioral battery proving it and CI enforcing it.

---

## 1. What S+ means (rubric, measured — not vibes)

| Metric | S (today) | S+ (target) |
|---|---|---|
| Dead lanes `(d)` | 0 (TBC era only) | **0 across ALL eras**, enforced by CI |
| Mock-limitation lanes `(c)` | 62 (TBC) | **0** — every strategy fires in the battery or is probe-verified live-firing |
| PvP/OOC lanes `(b)` | 38, *asserted* correctly-silent | **modeled** via a PvP scenario family, or probe-pinned correctly-silent |
| Era coverage | battery = **31 TBC specs only** | **vanilla + TBC + WotLK + leveling + SoD** in the battery |
| APL conformance | manual one-time cross-check (WotLK order verified, "no changes needed") | **automated per-spec test** pinning priority order + thresholds vs wowsims/SimC APL |
| Snapshot/cast-queue fidelity | unmodeled (cat Rip/Rake snapshot, fire hot streak, shadow clip) | **cast-queue + snapshot scenario families** |
| Pro-guide mechanics | spot-incorporated (changelog: "re-verified against wowsims APLs, SimC, Icy Veins, Warcraft Tavern") | **systematic per-spec pass** with thresholds/pooling/alignment pinned |
| Per-spec test suite | most specs have `_custom_matches`/`_dsl_priority`/`_strategies` | **100% of specs** + APL-conformance + leveling + PvP suites |

S+ = **behaviorally proven, APL-pinned, guide-complete, era-complete**.

---

## 2. Where we are (measured today)

- **Audits:** WotLK 43/43 clean, vanilla 40/40 clean, TBC (sylvanas) 61/61
  clean, `luac -p` 798/798. Rank ladders verified against wowhead 3.3.5 +
  wowsims + DBC, with STALE_TOP + every-ID enforcement.
- **Battery:** 31 TBC specs, **135 scenarios**, `Total: 31 | Load failures: 0`,
  never-firing **100** = **(b) 38 · (c) 62 · (a) 0 · (d) 0**. Rogue ×3 and
  warrior ×4 are at **0**; paladin ×3 and druid bear/cat at **8** each.
- **Tests:** ~469 rotation + 33 leveling suites registered; verify_all runs
  rotation + leveling + wotlk tests + 4 audits (+self-tests) + battery +
  clean-checkout probe in CI (green on GitHub Actions).
- **APL tooling exists but is dormant:** `tools/build_tools/analyze_wowsims_apl.lua`
  parses wowsims APL JSONs; `status_audit.md` references `shared/apl_parser.lua`
  ("unused by specs, infrastructure ready") but the file is **not on disk**.

## 3. What's actually lacking (the hard think)

1. **The battery only tests the TBC era.** `behavioral_audit.lua` loads the 31
   sylvanas-era specs (`ns.is_wotlk = false`); **none** of the 41 WotLK files
   (incl. DK) or 40 vanilla files are behaviorally exercised. The WotLK era —
   the most-played, with the hardest rotations (fire mage, affliction, unholy
   DK, cat) — is only *audited*, not *proven*. This is the single biggest gap
   and the whole meaning of "all of them."
2. **APL conformance is a one-time manual check, not a gate.** The WotLK rank
   audit compared priority ORDER against wowsims APL JSONs ("no order changes
   needed") — a great sign, but nothing prevents a future refactor from
   silently reordering a rotation. There is no `test_*_apl_conformance` suite
   and no pinned APL fixture data committed to the repo. The parser tool is
   unregistered and untested; `apl_parser.lua` is a phantom.
3. **62 `(c)` mock-limitation lanes remain** — the ranked fixture list is
   already written in the non-DPS report (items 1–20 ≈ 30–32 lanes for ~20
   scenarios) but not applied. They hide real gates: `Readiness` ×3,
   serpent-sting refresh ×2, clearcasting/Surge, moving shocks ×2, bear
   Swipe/Enrage, cat MangleFiller/ClawFallback, HolyNovaAoE, ChainLightning,
   LightningShield, MoonkinForm, HurricaneAoE, BattleRez, TotemicCall, etc.
4. **The 38 `(b)` lanes are asserted, not modeled.** Every one has a concrete
   live trigger the battery can't express (enemy caster, `melee_on_you`,
   snare/root, fear, ally-target, boss flag, dead ally, succubus pet). S+
   means a PvP scenario family makes them *observable* (or probe-pins them
   correctly-silent with evidence, like `ManaGemConjure`).
5. **Snapshotting / cast-queue mechanics are unmodeled.** The highest-skill
   pro-guide mechanics — cat Rip/Rake snapshotting (RakeSnapshot, RipSnapshot,
   RipTrick, ShredTrick), fire hot-streak sequencing, shadow Mind Flay clip —
   have no cast-queue state in the battery. `is_behind` is hardwired true so
   even the MangleFiller lane is untestable.
6. **Healers/tanks are guide-framed, not guide-pinned.** Triage priority,
   overheal avoidance, tank bias, mana windows, defensive CD timing exist in
   the code (heal-scan stubs were added to the battery) but were never
   systematically checked against the healer framework (triage > HoT > mana;
   Rapture/PW:S disc, Beacon holy pally, Chain Heal clusters, Wild Growth).
7. **Leveling rotations: IDs fixed, behavior untested.** Rank sweeps were run
   (vanilla/TBC/WotLK) but the 33 leveling suites never run inside the battery,
   so rank-ladder fallback at level breakpoints is unproven behaviorally.
8. **SoD (20 rotations) is outside the rating entirely.** Separate pipeline,
   pinned to wowsims/sod. "All rotations" arguably includes them.
9. **No throughput signal.** We prove *correctness* (right spell, right order,
   fires when it should) but never *efficiency* (right filler, right pooling,
   right cooldown window). wowsims APL conformance is the proxy — that's why
   pinning APL order + thresholds is the load-bearing S+ requirement.

---

## 4. The plan — 10 phases

### Phase 0 — Scorecard generator (foundation, ~1 day) ✅ **APPLIED 2026-08-09**
- New `tools/spec_scorecard.lua`: runs the live battery (`behavioral_audit.run_all`),
  classifies every never-firing lane (a)/(b)/(c)/(d) against the pinned `LANE_CLASS`
  table, computes per-spec suite counts from the rotation-runner registry, and
  emits `docs/scorecard.md`. APL column shows `pending` until Phase 2.
- Live split now CI-enforced: **never=100 · (a) 14 · (b) 41 · (c) 45 · (d) 0**
  (supersedes the stale triage-doc paragraphs; the split differs from the old
  0/38/62 because reclassified opt-in + correctly-silent lanes are now counted
  honestly). Ratings: 10 S / 0 S+ (S+ requires an APL pass).
- Wired into `run_verify_all.lua` (15th component) + pre-commit hook (check 5/5);
  `--check` exits 2 on doc drift, 3 on unclassified/stale pins, 0 in sync.
- **Gate:** scorecard exists, CI-fails on scorecard drift, unclassified lanes, or
  stale pins.

### Phase 1 — Era-wide battery (the big lift, ~1–2 weeks)
- Extend `behavioral_audit.lua` to load **vanilla** and **wotlk** namespaces
  (era-parameterized build_ns; `is_wotlk` flag already exists at line 442).
- Era-aware mocks: rank-ladder resolution per era (bridges exist), spell sets,
  level defaults (60 / 70 / 80), talents available.
- Add DK specs (blood/frost/unholy) + WotLK healer specs to the roster.
- **Target:** same 0/0 (d)/(a) and a measurable (c)/(b) inventory per era —
  the first real "rate all rotations" data.
- **Gate:** battery runs 3 eras, load failures = 0.

### Phase 2 — APL conformance harness (~1 week)
- ✅ **APPLIED (2026-08-09, pilot)** — see `tests/test_apl_conformance.lua`,
  `shared/apl_parser.lua`, `tools/evidence/apl/SOURCES.md`.
- Commit pinned wowsims APL JSONs (per era/spec, pinned commit) + generated
  "expected priority order" tables as evidence fixtures (self-provisioning via
  `analyze_wowsims_apl.lua`, mirroring the SOD generator pattern).
- Resurrect `shared/apl_parser.lua` (or move `analyze_wowsims_apl.lua` into
  `shared/`), make it a tested module, delete the phantom entry in
  `status_audit.md`.
- New `test_apl_conformance_*.lua`: for each spec, assert (a) strategy ORDER
  matches the APL priority list; (b) key gates (refresh thresholds, execute
  %, cd windows) match. Register in run_rotation_tests + verify_all.
- **Gate:** any strategy reorder or threshold drift fails CI.
- **Pilot outcome (3 specs):** fire, affliction, feral cat now conformance-
  tested against wowsims/wotlk @ 563e4a08. Two order deltas found + fixed:
  affliction Corruption refresh moved above UA (APL items 16-17) and cat
  FerociousBite/MangleCat moved above Rake (Go doRotation dispatch).
- **Remaining (Phase 2 scope):** extend to the other 35 WotLK specs + the
  TBC sylvanas specs + gate/threshold fidelity (refresh %, execute %, cd
  windows) — the order-only check is the first layer.

### Phase 3 — Close the 62 `(c)` lanes (~1 week, list already written)
- Apply the non-DPS report's ranked fixture list (items 1–20: Readiness ×3,
  prot opt-in pins ×4, ret cleanse ×3, serpent ×2, per-buff heal ×2, moving
  shocks ×2, bear Swipe/Enrage, cat MangleFiller/ClawFallback, HolyNovaAoE,
  ChainLightning, MoonkinForm, HurricaneAoE, BattleRez, TotemicCall, etc.)
- Pin each cleared lane family in a regression suite (33 exist; add ~10).
- **Target:** TBC-era (c) 62 → ~30; then a second triage for the stragglers.

### Phase 4 — PvP scenario family (models the 38 `(b)` lanes, ~3–4 days)
- Scenario overrides: `enemy_caster`, `melee_on_you`, `cc_target`
  (`target_class` humanoid), `self_rooted_snared`, `fear_cc` (TremorTotem ×3),
  `ally_target` (BoP/BoF/RighteousDefense/Cleanse/Purify), `boss`
  (JoL/JoW Boss, HammerOfWrathSolo), `dead_ally` (BattleRez), `pet_succubus`
  (Seduction), `mounted` (MountedProtection).
- Reuse the proven mechanisms: `setting_overrides`, `buff_remains_map`,
  `target_class`, `friend_class`, `is_group`, `is_pvp`.
- **Target:** (b) 38 → <10, each remaining lane probe-pinned correctly-silent.

### Phase 5 — Snapshot / cast-queue fidelity (~1 week)
- Battery cast-queue state: `queued_spell`, swing band (exists), snapshot
  window (`snapshot_expires`, buff_remains_map already unit-aware).
- cat: `is_behind` toggle → MangleFiller/ShredFiller; snapshot lanes
  RakeSnapshot/RipSnapshot/RipTrick/ShredTrick (settings + buff window).
- fire: hot-streak sequencing (Pyroblast-on-proc, Scorch refresh window).
- shadow: SW:P snapshot (shadow weaving), Mind Flay clip window.
- **Gate:** pro-guide snapshot mechanics are scenario-observable per spec.

### Phase 6 — Leveling behavioral coverage (~3–4 days)
- Battery scenarios for the 9/9/10 leveling files: level breakpoints per
  rank-ladder (learned/unlearned via `not_learned` map, exists), mana/health
  constraints, weapon/downranking behavior.
- Cross-era leveling check: same ability at 20/40/60/70/80 resolves the
  correct rank.
- **Gate:** every leveling file runs in the battery, 0 load failures.

### Phase 7 — Healer/tank guide conformance (~1 week)
- Healer: pin triage priority (tank>raid), HoT refresh policy, mana windows
  (Rapture/PW:S, Beacon+FoL, Chain Heal cluster targeting, Wild Growth smart
  heal), defensive CD timing (Pain Suppression, Divine Sacrifice, Tranq) per
  the icy-veins/wowhead/Skill Capped framework (already web-researched).
- Tank: threat priority, CD cycling, taunt/positioning lanes.
- **Gate:** healer/tank strategy order matches guide priority, pinned.

### Phase 8 — SoD into the rating (~2–3 days)
- Add SoD as an era in the scorecard (20 rotations, wowsims/sod APL refs).
- Decide scope explicitly: include in battery or document as out-of-scope —
  but the scorecard must state it, not silently omit.

### Phase 9 — Per-spec pro-guide detail pass (~1–2 weeks, continuous)
- For every spec: verify against wowsims APL (order) **and** pro guides
  (Icy Veins / Wowhead / Warcraft Tavern / wowapls patterns) for:
  - refresh thresholds (dot/buff ≤ Xs),
  - snapshot/pooling rules (energy/rage/mana gates),
  - cooldown alignment (burst windows, trinket sync),
  - movement handling (instant casts, wand fallback),
  - execute phases.
- Sources priority (repo convention): **wowsims APL > SimC/wowapls >
  Icy Veins/Wowhead/Warcraft Tavern > contested guide opinion**.
- Fix order/gate mismatches found (each fix + regression test).

### Phase 10 — CI + enforcement (ongoing, ~2 days to wire)
- verify_all additions: battery per-era matrix, APL-conformance suites,
  scorecard drift check, leveling battery, SoD scorecard row.
- Hard gates: `(d) == 0` and `(a) == 0` for every era; `(c)+(b)` per spec
  capped and monotone-decreasing; any regression re-fails.
- Update README/PVP badges via `tools/update_badges.lua` (already syncs PVP).

---

## 5. Sources

| Source | Use |
|---|---|
| wowsims/wotlk · wowsims/tbc · wowsims/classic · wowsims/sod | **Primary APL** (priority order + thresholds); pinned commits |
| SimulationCraft (wotlk/tbc/classic) | Cross-check APL order + procs |
| wowapls patterns | Rotations with procs/conditions (fire hot streak, feral snapshot) |
| Icy Veins (classic/tbc/wotlk) | Thresholds, pooling, cooldown windows, healer triage |
| Wowhead guides | Rank ladders (already bridge-verified), gear/stat nuance |
| Warcraft Tavern | TBC-era priority + totem twisting / curse assignment |
| Skill Capped (PvP) | Interrupt/CC/dispel priorities, burst windows, defensives |
| wowsims Go sim source (`sim/<class>/*.go`) | Cast-rank ground truth (already used in rank audits) |

Existing assets to reuse: `tools/build_tools/analyze_wowsims_apl.lua`,
`wowheadScrape/dbc_extract/wowsims.db`, the 3 spell-index bridges, the
settings-fixture + `buff_remains_map` + `target_class` battery mechanisms,
and the 33 battery regression suites.

---

## 6. Sequencing note

Phases 0–2 unlock the **measurement** (scorecard + era battery + APL gate);
Phases 3–5 close the **known TBC-era debt** (the 100 lanes + snapshot gaps);
Phases 6–9 extend to **leveling, healers/tanks, SoD, and per-spec depth**;
Phase 10 makes it all **unbreakable in CI**. Recommended order: 0 → 1 → 2 →
3 → 4 → 5 → 6 → 7 → 8 → 9 → 10, but 0+1+2 can land as one milestone since
they are all measurement.

**Rough total: 5–7 weeks of focused work** (battery era-extension and the
per-spec guide pass dominate). Phases 0, 2, 10 are the highest-leverage
*durability* wins — they turn "we checked once" into "CI enforces forever".
