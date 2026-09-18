# Post-Launch Hardening Backlog — First Week (Forever era)

-- WHAT:  prioritized hardening items for the first post-launch week, cut
--        from the four-dimension audit's open findings and the
--        launch-readiness gaps the DBC-diff work exposed.
-- WHEN:  Forever launch week (game live 2026-10-22); items ordered by
--        decision impact, not by class or file.
-- WHY:   the audit graded the campaign SPEC 8 / DESIGN 7 / CORRECTNESS 7 /
--        QUALITY 6 and named what would raise each dimension; the structural
--        refactor (single delta-template owner) and the protection
--        gate-combination proofs closed the top two. This doc is what
--        remains, with a "done looks like" per item so nothing ships on
--        assertion.
-- SAFETY: planning doc only — no runtime behavior; every item references
--        its gate (test/battery/tool) that proves completion.

*This backlog closes with the audit's original verdict so nothing is lost:
SPEC 8, DESIGN 7, CORRECTNESS 7, QUALITY 6; concision 6/10 (~25–30% of the
delta files deletable duplication — since resolved: −1,136 lines via
`spec_kit_forever_delta`, all 38 files migrated, zero copies left).*

## How to work this list

- One concern per commit; conventional subject; `-F` message file.
- Every item names its proof. An item without green proof is not done.
- P0 items block confident launch-week patching; P1 items protect the
  second week; P2 items are quality debt with a named trigger.

---

## P0 — must land in week 1

### 1. Spread dispatch-walk combination proofs to the remaining wrapped deltas
- **Audit finding**: correctness gap 4 — "the walk-based proof exists only in
  the protection suite; holy, retribution and restoration pin their wraps
  gate-by-gate, so wrap-lost regressions would pass gate checks and only the
  battery would notice."
- **Why P0**: the wrapped baseline-capture in
  `shared/spec_kit_forever_delta.lua` is now the single most load-bearing
  mechanism in the era; protection's Pin 8f (walk the unwrapped baseline list
  → the original matcher would fire) is the only proof the capture is
  load-bearing rather than decorative. One refactor of the owner module could
  break the other three wraps silently.
- **Scope**: `test_paladin_holy_forever.lua`, `test_paladin_retribution_forever.lua`,
  `test_druid_restoration_forever.lua` (or the actual wrapped suite set —
  grep `baseline.` capture uses; the protection Pin 8 block is the template).
- **Done looks like**: each wrapped delta's suite contains a quiet-frame walk
  over the *combined* list (nothing fires when it must not) plus an unwrapped
  walk that *does* fire the captured original matcher (proves the wrap is
  what holds silence). Rotation suite + both batteries green after.
- **Estimate**: one session.
- **DONE 2026-09-19** -- `6a72ecf3a` (retribution), `e5bec5f4f` (holy),
  `0177f8231` (resto). Scope correction found on execution: protection
  is the ONLY wrapped delta (the audit's 'wrapped deltas' premise was
  wrong), so the spread generalized to the three splice-only deltas as
  dispatch-walk combination proofs (slot ownership, tier handovers)
  plus degradation walks over each delta's real fallback branch
  (ret 6b/6c, holy 7b2/7c, resto 8b/8b2/8c); all three revert proofs
  re-verified. Protection's Pin 8 remains the wrapped-lane proof.

### 2. Run the smoke checklist's Block 0 engine-truth probes on the live client
- **Audit finding**: correctness gap 2 — "tuning thresholds are estimates,
  documented as beta-day probes; nothing can close them without live access."
- **Why P0**: every estimated threshold (Furor restore shape, rage-from-
  damage curve, haste-vs-DoT ticks, race-gated lanes) is a lane that may
  re-rank the moment real numbers exist. Block 0 (version string, race
  detection, buff-points surface) decides whether the race-gated backlog
  can ever ship.
- **Scope**: `docs/forever/beta_smoke_checklist.md` Blocks 0–1; verdicts land
  in `beta_day1_probes.md` + the per-class kits; any verdict that flips a
  claim re-runs the forever audit and the affected suites.
- **Done looks like**: Block 0/1 ledger entries flipped OPEN→resolved (or
  BLOCKED-not-guessed with the blocker named); probes doc + kits updated;
  no threshold left claiming a value the client never showed.
- **Estimate**: one login session + one close-out commit.
- **IN PROGRESS 2026-09-19 — probes built, verdicts pending access.** The engine
  carries `shared/live_probe_sylvanas.lua` (`NS.LiveProbe`): `report()`
  (version/expansion surfaces, race, the capability matrix, aura `points[1]`),
  `sample(tag)` (form/energy/rage/mana/hp/combo/AP/haste) and an armed CLEU ring
  (`arm{forms,spells,raw_events}` → `flush()`) that records form-shift energy,
  incoming-damage rage and DoT tick intervals with caller-supplied ids.
  `test_live_probe_sylvanas.lua` proves the present/absent surface split,
  nil-safety with no player, event classification, the tick-interval
  computation, the 64-slot bound with its dropped counter, and that nothing
  registers before `arm()`. Remaining: run the checklist's `RUN:` lines, paste
  the output into the ledger, flip the verdicts — any flip re-runs the forever
  audit plus the affected suites.

### 3. Wire the DBC diff into CI with committed fixture DBs
- **Audit finding**: structural note from the DBC-diff pass — the harness
  runs only where a local client extraction exists.
- **Why P0**: launch week is exactly when Blizzard pushes hotfix builds; a
  re-rank that lands mid-week must be caught by CI, not by whoever happens
  to run the diff locally.
- **Scope**: commit two small synthetic DBs (or fixture builders) the CI job
  can regenerate; add a verify_all component (or a CI step) that runs
  `forever_dbc_diff.py --old <fixture-old> --new <fixture-new> --exit-on-action`
  with seeded findings and expects exit 1 (detection proof), plus the
  `--self-test`.
- **Done looks like**: verify_all 45 components green including the new
  fixture-diff gate; the gate fails a PR that regresses the diff engine.
- **Estimate**: one session.
- **DONE 2026-09-19** -- fixture pair committed at
  `EaxRotations/tests/fixtures/forever_dbc/` (32 KB each, regenerated by
  `--write-fixtures`), the harness gained `--check-fixtures` (the real
  end-to-end path including the lane-impact scan over the live
  classes/*/*_forever.lua call sites) and `run_forever_dbc_diff_tests.lua`
  gates both modes as a verify_all component (45 total); the CI job runs the
  same two invocations as a named step, so a
  missing-interpreter local skip stays visible while CI is fail-closed.
  Load-bearing proof: an identical fixture pair fails the gate (exit 1).

---

## P1 — week 1 if capacity allows, week 2 otherwise

### 4. DBC↔docs claim diff (kit drift gate)
- **Audit finding**: quality gap — the kit docs assert cooldowns/levels that
  only the DBC can verify; today that check is manual (`--check-bridge`
  spot-checks seed IDs only).
- **Scope**: extend `forever_dbc_diff.py` (or a sibling tool) to read the
  cooldown/level/school claims embedded in `docs/forever/kits/*.md` and the
  probes ledger and flag any that no longer match the current DBC surface.
- **Done looks like**: a `--check-docs` mode exits 0 on the current tree;
  deliberately flipping one kit claim makes it exit 1 (detection proof).
- **Estimate**: one session.

### 5. Mock-fidelity: make the battery's `spell_ready` gate-honest
- **Audit finding**: correctness gap 3 (partially mitigated by the protection
  combo lane) — "the mock returns true unconditionally, so gate combinations
  are only partially exercised; the battery `on_cd` bank covers the seeded
  scenarios only."
- **Scope**: extend the battery mock so `spell_ready` honors the `on_cd`
  bank *generally* (not per-scenario wiring), then re-verify the strict
  never-pins per era stay at tbc 11 / wotlk 0 / vanilla 9 / sod 0 /
  forever 9 — a general mock can flip lanes in or out of 'never'.
- **Done looks like**: no scenario carries bespoke on_cd plumbing;
  scorecard pins unchanged after the generalization; batteries green.
- **Estimate**: one session, high blast radius — schedule with a clean tree.

### 6. Close the seal-ownership seam (design debt, accepted cost)
- **Audit finding**: design gap 4 — "two-owner seam on 'which seal is
  active' (delta probe tables vs baseline buff tables), accepted under the
  era-frozen-baseline rule."
- **Why not P0**: the seam is pinned (protection Pins 1–8 encode it); it is
  a maintainability cost, not a correctness risk.
- **Scope**: a `shared/` helper that owns "current seal" reads with a
  Forever-aware table, consumed by both the baseline-era path and the
  delta; only if a maintainer accepts touching the era-frozen baseline's
  read path (the constraint that created the seam).
- **Done looks like**: one owner for seal-state reads; all paladin suites +
  batteries green with unchanged pins; the constraint decision recorded in
  the PR.
- **Estimate**: one session + a design decision.

---

### 7. Author the mage-fire Wake of Fire window lane

- **What**: the 2026-09-19 probe pass unblocked this lane — 1312934 is the 20s
  window the ability applies on a kill (+50% crit on the next Fire Blast) and
  `BUFF_OVERRIDES` now pins it, so a lane can gate
  `has_buff(by_buff["Wake of Fire"])` and prefer Fire Blast inside the window
  instead of inheriting the 11078 ability row (a buff read against which is
  always 0).
- **Why**: it is the one Forever mage mechanism the kit documents that the
  rotation does not act on; the payoff lands on kill chains (dungeon packs, add
  waves).
- **Done looks like**: a `fire_forever.lua` lane above the baseline Fire Blast
  lane, a unit pin for the window-up/window-down split, and a battery scenario
  that makes it fire (a lane that never fires would break the strict forever
  never-pin).
- **Estimate**: half a session.

---

## P2 — explicit debt, triggered not scheduled

### 8. Rank-ladder mirror extension
- **Backlog item (mission list)**: extend `spell_maxrank_by_name_forever`
  to expose per-rank ladders where a lane needs a non-max rank (downrank
  fits, leveling catches).
- **Trigger**: any lane that needs a rank the mirror can't resolve — the
  lane is dormant until then (Pattern-17 doctrine holds; no guessed IDs).
- **Done looks like**: builder emits the ladder table; audit self-test pins
  its presence; consuming lanes un-dormant with unit proof.

### 9. Class-less-cast bridge mechanism (Demonic Sacrifice class of gaps)
- **Backlog item (mission list)**: a bridge mechanism for cast-lane rows the
  class filter cannot see (today only buff-role rows get the
  `CLASS_LESS_BUFF_NAMES` treatment).
- **Trigger**: the first cast lane that must resolve a class-less row.
- **Done looks like**: builder-side allowlist + audit admission, mirroring
  the existing class-less buff precedent.

### 10. Blade Dance 400012 lane
- **Backlog item (mission list)**: parked pending DBC confirmation that the
  row is the player cast, not an internal damage row (the Fire Nova
  precedent: internal rows win raw lowest-id ties).
- **Trigger**: beta access; the DBC diff will flag the row's movements
  meanwhile.

---

## Week-1 day map (one-concern-per-day shape)

| Day | Item | Proof gate |
|-----|------|-----------|
| 1 | #1 walk-proof spread | 3 suites, rotation + batteries |
| 2 | #2 Block 0/1 live session | probes ledger + kits flipped |
| 3 | #2 close-out: threshold re-ranks from real numbers | forever audit + affected suites |
| 4 | #3 CI fixture diff | verify_all 45 components |
| 5 | #4 docs-claim diff (or #5 if a mock-fidelity bug surfaced) | detection-proof + pins unchanged |

*Slack rule: if the live client is unavailable on days 2–3, swap in #5 and
#6 and pull #2 forward to the first login.*
