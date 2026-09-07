# #1 Rotation Engine — competitive gap & roadmap (2026-09-06)

Goal: make EaxRotations the rotation engine players and the Sylvanas platform
reach for first — on accuracy, coverage, proof, and trust. This doc is the
honest gap list against the benchmark set and the prioritized plan to close
it. It supersedes nothing; `s_plus_roadmap_2026-08-09.md` remains the
per-spec quality rubric (S+ = behaviorally proven, APL-pinned, guide-
complete, era-complete). This doc asks the wider question: what does *being
the best engine* require beyond per-spec correctness?

---

## 1. The competitive set (who "the best" is measured against)

EaxRotations runs inside Project Sylvanas as a **full-auto** scripted engine.
Two benchmark groups matter:

| Benchmark | What it is | What it proves / lacks |
|---|---|---|
| Other Sylvanas rotation scripts | Hand-authored full-auto rotations shared in the community | Priority lists, no public verification, no regression battery, no sim grounding |
| Hekili / HeroRotation (retail + classic) | Sim-driven rotation *assistants* (SimC/APL backends), cross-expansion data | Accuracy of suggestion is SimC-derived and admired — but they do not auto-cast and ship no executable correctness proof per spec |
| Synaptic et al. (retail, 2026) | Lightweight Hekili-style assistants | UX-driven; accuracy not sim-verified |
| wowsims / SimulationCraft | Offline simulators (not engines) | The *source of truth* for what a rotation should be |

**EaxRotations' unique position:** it is the only engine in this set that is
sim-grounded (wowsims APL pins), full-auto, AND carries an executable
correctness proof (563-suite battery, never-firing gates per era). That
combination — not any single feature — is the #1 claim. The roadmap below
protects and *surfaces* that claim.

---

## 2. Where we are today (measured, 2026-09-06)

- **Coverage:** TBC/Sylvanas 31 specs · WotLK 41 (incl. 9 leveling) · Vanilla
  40 · SoD 20 role rotations. Battery + never-gates green in all four eras.
- **Strategies:** 963 (TBC) + 430 (WotLK) on the scorecard; every spec has a
  behavioral fire/don't-fire suite through the real read path (era campaign).
- **Dead lanes:** 0 in every era. TBC classified-silent 16 (1 opt-in, 10
  correctly-silent, 5 mock-limitation); Vanilla baseline 12; WotLK/SoD strict
  at 0.
- **APL conformance:** 50/50 pinned (DPS/tank + WotLK priests). Pending by
  design: non-priest healers (no wowsims healer APLs), leveling (no sim
  dispatch), WotLK subtlety (no fixture).
- **Verification apparatus:** `docs/scorecard.md` (TBC + WotLK), 6 triage
  docs, `tools/apl_status.lua`, spell-index bridges per era, `verify_all`
  exit 0.

---

## 3. The honest gaps (each closes real distance to "#1")

*Gap analysis as written on 2026-09-06, before the P0–P3 passes below — see
§4 statuses for each item's live disposition.*

### G1 — Rating asymmetry: two eras are proven but not scored
The scorecard rates TBC and WotLK per spec. **Vanilla (40 specs) and SoD (20
roles) are gated but have no per-spec strategy/APL rating**, so "all four
eras, every spec rated" is not yet a true statement. WotLK healers and all
leveling rotations are APL-`pending` without a defined non-sim rating tier.
*Fix:* extend `tools/spec_scorecard.lua` to Vanilla + SoD (S+ roadmap Phase
8), and define the honest healer/leveling tier ("behaviorally proven; no sim
exists") so no row reads as unfinished.

### G2 — Residual never-buckets that keep some specs off S+
TBC still holds 16 classified lanes and druid/cat rates B: snapshot
mechanics (RakeSnapshot/RipSnapshot), PvP/ally/OOC triggers, and seal-martyr
role gates are *asserted* silent, not *modeled* (S+ roadmap Phases 3–5,
partially applied). Vanilla's 12 classified lanes have the same status.
*Fix:* the PvP + snapshot + ally-target scenario families. This is the last
correctness debt between "great" and "provably complete."

### G3 — Healer credibility
Priests (WotLK holy/disc) are sim-pinned; every other healer spec is
behaviorally pinned but has no sim or guide-conformance verdict. Healers are
what most players *notice* first (smart triage feels magical or broken).
*Fix:* guide-conformance pass per healer (triage > HoT > mana; Rapture/PW:S,
Beacon, Chain Heal clusters, WG smart heal) pinned like the WotLK
friendly-unit suites, plus an explicit "no sim exists" tier in the scorecard.

### G4 — The proof is invisible to players
The correctness apparatus (563 suites, APL pins, never-firing gates) lives in
internal docs. A player choosing an engine cannot see it. `status_audit.md`
is stale-by-generation (banner added, rows still wrong); README claims drift
(spec badge "29+9" vs 31 scorecarded TBC specs); `parse_specs/` covers only 9
TBC files. *Fix:* an auto-generated player-facing accuracy page per spec
(APL verdict + fixture + battery pins + rating), README reconciled, and a
"why does it cast X" surface.

### G5 — No measured performance story
One middleware sweep cut per-frame NS calls (v2.23.0), but there is no
frame-budget gate. A #1 engine must be *light* — players notice stutter more
than any feature. *Fix:* per-class per-frame cost measurement + a CI budget
gate with headroom.

### G6 — Adoption surface is developer-first
In-game UX improved (permashow panel, diagnostics, declarative menu) but the
out-of-game story is thin: the player-facing changelog
(`CHANGELOG_CUSTOMER.md`) died at v2.18.1, release notes are engineering-
dense, and per-spec "what does this rotation do and what does it need from
me" guides don't exist. *Fix:* player release notes per version, per-spec
guide pages, install/era pages.

---

## 4. Roadmap (prioritized by distance-to-#1 per unit effort)

**Status (recording pass 2026-09-06):** P0 ✅ APPLIED · P1 ✅ APPLIED · P3 ✅
APPLIED · P2 ⏸ OPEN by design (rationale below) · P4 adoption surface
(non-code, not started). Post-P0 residue: exactly two classified lanes remain,
each with one-line code evidence — **Fade** and **Ret_SealMartyr_Primary**
(see the P0 exit line).

### P0 — Finish the correctness story (~1 week)
The claim "every era, every spec rated and proven" must be literally true.
1. **Scorecard all eras** — ✅ **APPLIED 2026-09-06.** `tools/spec_scorecard.lua`
   now rates all four eras (TBC/Sylvanas 31 · WotLK 41 · Vanilla 40 · SoD 20 =
   132 scored specs): Vanilla totals 917 strategies / 12 never (b)9+(c)3,
   SoD 158 strategies / 0 never, both STRICT (unclassified/stale pins and
   (d)>0 hard-fail), drift-gated by `--check` in verify_all. Vanilla pins are
   the live 12 (MagmaTotem clear of v2.24.2 honored); triage-doc addendum
   records it.
2. **Healer/leveling tier** — ✅ rubric note now documents that Vanilla + SoD
   rows read `pending` by design (no wowsims APL fixtures exist for those
   eras); WotLK/TBC pending rows were already documented. The tier wording is
   in the scorecard's era-coverage paragraph.
3. **PvP + snapshot scenario families** — PARTIAL, **APPLIED 2026-09-06**. Two
   new era-shared scenarios model previously inexpressible real states and
   proved three lanes fire through the real files: `ooc_mounted` cleared
   priest/holy MountedProtection (TBC + Vanilla; the mock gained a
   ctx-banked `me:is_mounted`), `sap_setup` (OOC + stealth_up + PvP target —
   the missing in_combat=false split of pvp_stealth_opener) cleared rogue/
   subtlety Sap. **TBC 16 → 14 (a1 b9 c4)**, **Vanilla 12 → 11 (b8 c3)**,
   subtlety TBC → S (its only never lane cleared); WotLK/SoD untouched at 0.
   Pins, verify_all battery expectations, and the vanilla sweep regression
   were regenerated; era-pair/exclusivity suites updated where a lane
   legitimately gained a scenario (assassination PvP_CheapShotOpen now also
   fires in sap_setup). The remaining classified lanes were re-verified
   against the real code this pass: **snapshot (cat Rake/Rip) and totem
   (enh FireNovaReplacement / GraceOfAirTotemTwist) lanes are unpinnable
   under the stateless scenario model** — their gates read module-local state
   written only by real-cast executes (cat_sylvanas record_bleed_snapshot;
   enhancement totem_state lifecycle) — and Fade conflicts with the
   Soulshatter threat-exclusivity contract. druid/cat rating **B → A** via the execute-capture harness.
   **Execute-capture harness — APPLIED 2026-09-06 (second phase).**
   behavioral_audit.run_spec now supports scenario `capture` plans: the seed
   lane's REAL execute runs against the mock NS (try_cast always true →
   module-local state records exactly as live), then the reap transform
   applies the post-cast frame and the reap lanes must fire. Era-guarded
   (sylvanas) + spec-scoped (missing seed lane = silent skip). Two scenarios
   (`cat_rip_snapshot_capture` / `cat_rake_snapshot_capture`) cast the real
   Rip/Rake at AP 1000, then re-evaluate at AP 4000 with the bleed applied:
   **RakeSnapshot + RipSnapshot (c) → PROVEN**, firing exclusively through
   their capture scenarios. TBC **14 → 12 (a1 b9 c2 d0)**; druid/cat never 4
   → 2 (the residual two are (b) OOC/utility correctly-silent,
   TrackHumanoids/TravelForm). Cross-era contract re-verified: wotlk 0,
   vanilla 11, sod 0.
   **Enh totem-state family — APPLIED 2026-09-06 (third phase).** Same
   harness, era copies: `enh_fire_nova_replacement_capture_tbc` seeds
   fire_nova_active via the real FireTotem execute (flame shock up reap) →
   **FireNovaReplacement PROVEN (TBC)**; `enh_grace_air_twist_capture_vanilla`
   seeds next_air via the real WindfuryTotemTwist execute →
   **GraceOfAirTotemTwist PROVEN (vanilla)**; `enh_fire_nova_replacement_
   capture_vanilla` → **FireNovaReplacement PROVEN (vanilla)**. Each fires
   exclusively in its capture scenario. The harness gained reap-and-consume
   (a fired reap lane's own execute runs, mirroring the dispatcher) so seeded
   module state clears exactly as the engine's next cast would. TBC **11
   (a1 b9 c1 d0)**; vanilla **9 (b8 c1 d0)**; shaman/enhancement → **S+ TBC /
   S vanilla**. Cross-era re-verified: wotlk 0, sod 0.
   *Exit:* scorecard shows 0 untriaged in every era; all specs ≥ S — still
   OPEN on exactly two classified lanes, each with one-line code evidence in
   the era triage addenda: **Fade** (priest/leveling vanilla — fires only at
   threat ≥ 99, which the Soulshatter threat-exclusivity contract caps) and
   **Ret_SealMartyr_Primary** (TBC retribution — the seal-martyr damage path
   is faction/era seal selection; no faction-loaded race exists in the
   battery). Honest residue, not an open gap.

### P1 — Make the proof public (~3–4 days)
The moat must be visible to a player in 60 seconds.
1. **Accuracy page generator** — extend `spec_scorecard.lua` to also emit a
   player-facing per-spec card (APL verdict, fixture, suite count, rating,
   era) as `docs/ACCURACY.md` + README section.
2. **README reconciliation** — spec counts, era table, links to the accuracy
   page; retire the stale `status_audit.md` rows behind the banner with a
   pointer.
3. **In-game "why" trace** — Diagnostics: last decision per strategy (which
   gate held/fired) — no competitor has this.
   *Exit:* a skeptical player can verify any spec's accuracy claim in one page.

**P1 — ✅ APPLIED 2026-09-06.** (1) **Accuracy page**: `tools/spec_scorecard.lua`
now also emits `docs/ACCURACY.md` — a plain-language player page (what a
"strategy" is; 4 eras · 132 specs (31/41/40/20) · 2,468 decision rules
exercised · 0 dead · 20 rules the rig never triggers, each with a filed reason
· 563-suite battery · 50/50 sim-checked where fixtures exist · strict
never-gates in all 4 eras · honest known limits incl. Fade/Ret_SealMartyr
one-liners, non-sim healer/leveling tiers, and a no-live-client-measurement
statement). The `--check` gate regenerates AND drift-compares both docs, so
the page cannot rot. (2) **README reconciled to live counts**: spec badge →
"132 rated (4 eras)"; four-era framing; suite counts 563 rotation + 39
leveling = 602 via `tools/update_badges.lua`; APL 50/50 computed live;
ACCURACY.md linked; stale claims (29+9, 556/524/32, 34/34) deleted. (3)
**In-game "why" trace**: Diagnostics → "Trace Casts" records the last 32
executed rotation casts — the rule that fired + the live state its DSL
conditions read (state/context watch fields attached at compile time) — shown
as a Last-Casts readout with Print/Clear on both menu hosts. Zero hot-path
cost when off (forced-GC delta 0.0 KB over 5,000 calls); pinned by extending
test_swing_diagnostics (module surface, zero-alloc, ring bound/order) and
test_dispatcher_role_mode (real dispatcher records rule + live state on
ticks; nothing when off); battery stays 563.

### P2 — Healer guide conformance (~1 week)
Per-healer pass (holy pally, resto druid/shaman, disc, holy) pinning triage,
HoT refresh, mana windows, and defensive timing via the existing
friendly-unit battery model; scorecard rows flip to a documented
"guide-pinned" verdict. *Exit:* every healer has a behavioral suite with
triage assertions and a non-sim verdict row.

**P2 — ⏸ OPEN by design (2026-09-06).** No authoritative healer-sim source
exists to be conformant to (wowsims has no healer APLs — the same reason
healer rows carry a documented non-sim tier), healer triage intent is already
pinned behaviorally by the era suites (friendly-unit triage/bias/HoT models
from the WotLK priest/resto passes), and hand-transcribing community healer
guides risks encoding wrong rotations as "pins." Reconsider only if a named,
auditable source set (per-healer guide + version) is adopted; until then the
scorecard's honest tier ("behaviorally proven; no sim exists") already covers
these rows.

### P3 — Performance gate (~2 days)
Measure per-frame cost per class (NS calls, table churn) in the battery or a
probe; add a budget gate to `verify_all` with 2× headroom; publish the number
on the accuracy page. *Exit:* CI fails on a per-class cost regression.

**P3 — ✅ APPLIED 2026-09-06.** `tools/perf_cost_gate.lua` (sanctioned,
re-runnable) measures retained allocation under the capturing mock via the
forced-GC batch standard (collect → batch → collect) across: the real
`main_sylvanas` dispatcher tick (trace off + on), CastTrace.record (off/on),
the Diagnostics Last-Casts readout (idle/live), and real ControlPanel
reconcile (idle). Measured deltas (retained KB/batch): trace-off record 0.00
· readout idle 0.00 · CP reconcile idle 0.00 · tick off 0.12 (≤ 1.0 KB
GC-accounting bound, the swing-pin tolerance) · trace-on marginal 0.00 ·
trace-on record 0.00 (32-ring bound) · readout live 0.00. The tool surfaced
one real violation and it was fixed: the idle readout allocated an empty
table every frame → shared-empty return, now 0.00. Wired into `verify_all` as
the "perf cost gate" component with named thresholds — a per-tick retained
regression hard-fails.

**P3 audit close-out (2026-09-06, second pass):** the gate now ALSO measures
**churn** — per-frame temporaries the retained delta cannot see — via the
GC-stop technique (`collectgarbage("stop")` for the measured batch → count
growth → restart + full collect), with per-path churn bounds documented at
the top of the tool and both deltas printed per path. The real **legacy CP
per-frame render callback** is now a gate workload (the audit's "largest real
per-frame allocation"): `render_legacy_rows` was restructured to cache the
row array and rebuild only on mode/role/key-code/schema change, and the
audit-required measurement exposed + fixed a genuine per-frame closure — a
`pcall` closure per quick-toggle per frame (~240 B/frame on a 3-toggle
panel) now reads key codes directly on the hot path, dropping the workload's
churn from ~4.7 MB to 0.19 KB per 20k frames while the CP suites stay green.
The Diagnostics Last-Casts readout path is gated through the real CastTrace
surface; the full `main.lua` menu render tree is not bootable under the mock
(the readout replica is the honest bound for that subtree). Measured per path
(retained/churn KB per batch): trace-off record 0.00/0.20 · readout idle
0.00/0.12 · CP reconcile idle 0.00/0.06 · CP legacy render 0.00/0.19 · tick
off 0.19/47.0 · trace-on marginal 0.00/0.36 · trace-on record 0.00/0.31 ·
readout live 0.00/1.44.

**Per-class cost sweep — ⏸ OPEN.** The gate runs one synthetic engine tick
(mage-like DSL rotation) plus the CP/render workloads, NOT a per-class sweep
of every spec file, so the original P3 exit criterion ("CI fails on a
per-class cost regression") is not yet met. The core gate (retained + churn,
real render paths, named thresholds, verify_all component) is APPLIED and
hard-failing; the per-class sweep is the remaining item before P3 fully
closes.

### P4 — Adoption surface (~1 week, can overlap)
Player-facing release notes per version (resurrect a customer changelog from
the v2.25.0 entry), per-spec guide pages generated from `parse_specs`
(expanded past the 9 TBC files), install/era pages, and a "what's new" hook
in the in-game menu. *Exit:* a new player can install, pick a spec, and know
what it does without reading code.

**P4 — adoption surface (non-code, not started).** Player release notes,
per-spec guide pages, install/era pages, and in-game "what's new"; no engine
work. Depends on a release cadence and docs-ownership decision rather than a
code deliverable.

---

## 5. What NOT to do (guards)

- No telemetry/analytics (private-server cheat context — a trust killer).
- No accuracy-lowering "always press the shiny button" features; the brand is
  sim-correct full-auto, so every feature must keep APL conformance green.
- No roadmap item ships without its pin: feature + regression suite + scorecard
  row, or it does not exist (repo convention).

---

## 6. Sources / reading

- `docs/scorecard.md` — per-spec live metrics (the authoritative index).
- `docs/s_plus_roadmap_2026-08-09.md` — per-spec S+ rubric + phase status.
- `docs/never_strategy_triage_*.md` (6) — why each non-firing lane is silent.
- `docs/parse_specs/tbc/` — the 9 documented guide divergences (expand in P4).
- wowsims/wotlk @ 563e4a08 (`tools/evidence/apl/SOURCES.md`) — APL provenance.
- Platform docs: docs.project-sylvanas.net/dev/ — engine surface + conventions.
