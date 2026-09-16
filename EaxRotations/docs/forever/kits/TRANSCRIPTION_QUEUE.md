-- docs/forever/kits/TRANSCRIPTION_QUEUE.md -- kit transcription tracker.
-- WHAT:  one tracked checklist for the Icy Veins Forever class-overview
--        series (all 9 classes), so no kit is missed before launch
--        (2026-11-04) and each is DBC-verified during beta (09-17..10-21).
-- WHEN:  tick per kit as its transcription lands; final sweep before launch.
-- WHY:   the series is the only pre-beta source with per-spec kit depth
--        (Blizzard's official per-class dumps have so far covered paladin
--        only); every _forever spec file must trace to one of these docs.
-- SAFETY: no spell IDs anywhere in kits/ until the Forever DBC lands
--         (docs/forever/dbc_runbook.md).

# Forever kit transcription queue

Status legend: DONE = transcribed + committed · QUEUE = awaiting pass ·
VERIFY = transcribed, awaiting beta-DBC verification checklist run.

| Kit | Status | Doc |
|---|---|---|
| Paladin (official Deep Dive) | VERIFY | kits/paladin.md |
| Hunter | VERIFY | kits/hunter.md |
| Shaman | VERIFY | kits/shaman.md |
| Warrior | VERIFY | kits/warrior.md |
| Mage | VERIFY | kits/mage.md |
| Priest | VERIFY | kits/priest.md (NOTE: no Icy Veins priest overview exists yet — demo-derived Zockify source; refresh when IV lands) |
| Warlock | VERIFY | kits/warlock.md |
| Druid | QUEUE | kits/druid.md |
| Rogue | QUEUE | kits/rogue.md |
| Racial & talent framework | VERIFY | kits/racials-and-talents.md (refresh pass after all 9 classes: fold any per-class-page racial detail not yet recorded) |

Source series: Icy Veins Forever class overviews
(`https://www.icy-veins.com/wow-forever/<class>-class-overview`), updated
(EXCEPTION: the priest page does not exist on Icy Veins — priest.md is
transcribed from Zockify's demo-derived page; refresh when IV adds it)
2026-09-15 (spell + talent pass); Blizzard's official per-class dumps remain
paladin-only so far — if Blizzard publishes an official kit for a queued
class, it supersedes the series page and the doc's source line is updated.

## Per-kit pass (same shape every time)

- [ ] Read the full class-overview page (spell changes + all three specs +
      "what else could change" + changelog).
- [ ] Transcribe into `kits/<class>.md` in the paladin/hunter/shaman format:
      header comment (WHAT/WHEN/WHY/SAFETY) · sources line (author, date,
      community-reproduction caveat) · class-wide table (change → rotation
      impact) · per-spec sections (named talents/abilities + what each does
      to a rotation) · race table for that class's combos · "flagged as
      unconfirmed" section · spec-files-to-author (Phase 4) · beta-DBC
      verification checklist.
- [ ] ZERO numeric spell IDs (DBC gate). Contradictions between pages:
      flag in "unconfirmed", never resolve by guessing.
- [ ] Worktree on `feat/forever-era-2026-09-15`, one kit per commit,
      conventional `docs(era):` subject, gate must pass (19 checks).
- [ ] Tick this row when committed.

## Queue notes (rotation-code hot spots from the shaman pass)

- **Warrior**: stance/rage/execute family assumptions; watch for Blood
  Rage/zerker-stance reworks and any new rage normalization (our rage-gated
  lanes are Pattern-14-heavy).
- **Mage**: fire/frost lane families + evocation/wand economy; watch for
  new baseline spells (Ice Lance precedent) and cast-time changes.
- **Priest**: healing engine lanes (PW:S absorbs Pattern 12, FSR cycle);
  watch for the Spirit/FSR rules and any new baseline heal.
- **Warlock**: dot-refresh logic (immolate/corruption tables are WotLK-rank
  ID-bearing — the audit gates these), pet/shard economy.
- **Druid**: form-switch gating (cat/bear/moonkin/tree), Powershifting
  viability, any new form baseline.
- **Rogue**: combo-point builders/finishers, poison/economy lanes, Stealth
  opener assumptions.

## Launch gate (before 2026-11-04)

- [ ] All 9 rows DONE or VERIFY.
- [ ] Every VERIFY kit's DBC checklist run against the Forever bridge
      (dbc_runbook.md steps 2–6), each named ability resolved by name; any
      miss downgrades the claim, never silently drops it.
- [ ] racials-and-talents.md refresh pass complete.
- [x] Phase-4 build order written: `docs/forever/phase4_build_order.md`
      (wave 1 ranked from the transcribed kits; wave 3 re-ranks as the
      remaining kits land).
