-- docs/forever/beta_day1_probes.md -- consolidated beta-day probe list.
-- WHAT:  every claim across the nine kit docs flagged highest-priority or
--        flip-risk, consolidated into ONE execution-ordered checklist so
--        beta day 1 is a single pass, not nine doc crawls.
-- WHEN:  after dbc_runbook.md steps 0–3 land the live bridge (beta opens
--        2026-09-17); P1–P3 the same day, P4–P5 across the first days.
-- WHY:   wave 1–3 authoring is gated on these verdicts; a flip here
--        re-ranks the build order (docs/forever/phase4_build_order.md).
-- SAFETY: every probe resolves BY NAME through the bridge (zero-literal
--         rule); verdicts are recorded into the kit doc's checklist —
--         a failed claim downgrades a lane, never silently drops it.

# Beta day-1 probe checklist (consolidated from all 9 kits)

Precondition: runbook steps 0–3 done — beta client installed, DBC
extracted, bridge built, audit live (`--check-bridge` exit 0). Probes run
against the bridge and/or in-game on the beta client. Record each verdict
in the owning kit doc's verification checklist (checkbox + date), and
apply the listed build-order consequence.

## P0 — recon before any tooling (runbook first-day checklist)

- [ ] **Addon-policy recon**: new client integrity/error surfaces, error
      reporter behavior, what the built-in damage meter exposes
      (source: MMORPG.com interview; risk register in overview.md).
- [ ] **Version string**: capture `get_game_version()` output for
      `core_sylvanas.lua::_resolve_expansion_key()` (runbook step 5).
- [ ] **Client install drive**: confirm the real `_forever_` folder
      location vs DB2ToSqlite's appsettings `BaseDir: F:\World of Warcraft`.

### P0 verdict — 2026-09-17 (beta-day execution attempt)

- **Client NOT installed.** Battle.net registers no forever product
  (agent product.db + Battle.net.config: wow / wow_classic /
  wow_classic_era / wow_classic_anniversary / wow_anniversary only); no
  `_forever_` folder in the install root; zero product markers in
  WowClassic.exe 2.5.6.69795 (both "forever" strings are engine noise).
- **Surprise surface**: the anniversary client self-updated to
  **2.5.6.69795 on 2026-09-13** (beta eve; live realms still serve
  2.5.6.68184 per the 09-15 login log). Forever may arrive either as a
  new product/folder OR as an anniversary line update — the detection
  script watches both surfaces.
- **Tooling**: `EaxRotations/tools/check_forever_client.py` re-runs the full P0 scan +
  runbook prereq report; exit 0 = install detected, JSON via --json.
- Addon-policy recon: **pre-covered** by the MMORPG.com interview entry
  in overview.md (Project Sylvanas reads memory, not the addon API; the
  beta-day integrity-check watch still requires the client).
- Version string + install-drive items: **blocked on client** (no
  get_game_version() surface exists until the beta binary runs).
- Runbook prereqs all green (DB2ToSqlite backup, dotnet 9, TBC
  calibration DBC); steps 1-3 + probes P1/P2 remain client-gated.

### P0 verdict — 2026-09-17 (beta-day execution, beta found)

- **Client INSTALLED as `wow_classic_beta` 1.60.1.69893** (folder
  `_classic_beta_`; the anticipated `_forever_` folder does not exist).
  Identity confirmed by DBC signatures, not folder/product naming.
- **Install drive**: `C:\Program Files (x86)\World of Warcraft` (the
  `F:\` drive in DB2ToSqlite's appsettings was stale — extraction used a
  custom settings file with the real drive + `Product: wow_classic_beta`).
- **Version string**: `.build.info` reports `wow_classic_beta =
  1.60.1.69893`. The live `get_game_version()` output still needs a beta
  login (runbook step 5 stays open); no client process was touched —
  extraction is CASC file reads only.
- **Addon-policy recon**: unchanged posture — file reads only, no process
  attach, no login performed.

## P1 — wave-1 name resolution (unlocks days 1–3 authoring)

Every wave-1 lane resolves by name or goes dormant. One pass (verdicts
2026-09-17, beta 1.60.1.69893 DBC unless noted):

- [x] Maelstrom Weapon — shaman enhancement (buff 408505 + talent 408498
      resolve; **stack cap CONFIRMED = 5** via SpellAuraOptions CumulativeAura
      on 408505 and the talent row's third effect base_points; proc mask
      81920 = melee hit, ProcChance 100 — the spend-at-5 gate is DBC-derived
      now, no in-game probe needed)
- [x] Stormstrike (8s CD confirmed: RecoveryTime 8000) / Improved
      Stormstrike (dodge-parry reset OPEN — talent-side, wave 2)
- [x] Fire Nova — shaman (ROLE FIX 2026-09-17: the player cast is the
      trainer-taught 408341-408345 family — 520 mana, 1.5s GCD,
      **CategoryRecoveryTime 6000**, "detonates your Fire Totem"; the classic
      8349/11307 rows are totem-internal damage rows with no mana/cast/GCD;
      the bridge's MAXRANK_OVERRIDES now pins Fire Nova to 408345)
- [x] Totemic Projection 437009 (60s CD) / Totemic Recall 36936 /
      Call of the Elements 66842 — shaman
- [x] Lava Burst 408490/1238300 (+20% FS bonus in EffectBasePoints; rendered
      tooltip reads 21% — the bonus flag is a dummy effect, talents raise the
      printed number) — shaman elemental
- [x] Elemental Mastery — **name-table quirk, not a removal**: talent row
      16166 still sits in the client's Elemental tree (tier 6, column 1,
      prereq 565 = Elemental Fury 5-point), but the client has NO SpellName
      row for it, so the spell is absent from `by_name.json` and from the
      bridge mirrors. The baseline elemental lane casts it from the class map
      (`NS.ShamanSpells.ElementalMastery`, id 16166, 180s CD) and needs no
      delta. [PROBE (in-game): confirm the talent grants the ability at 31
      points and the class-map lane fires on beta day.]
- [x] Hot Streak 400625 (Forever stacking proc; **RESOLVED 2026-09-17**:
  `CumulativeAura=3` confirms the kit's 3-stack number, `SpellDuration 8` =
  15s, aura = casting-time spellmod op 10 at −25/stack; the legacy 48108
  "2 in a row" row is the pre-Forever mechanic, `CumulativeAura=1`) — mage
  fire
- [x] Pyroblast 11366 / Fire Blast 2136 (class-map casts, unchanged) /
      Wake of Fire buff 11078 + window 1312934 (full mechanic text
      confirmed; trigger wiring OPEN — lane stays absent) — mage
- [x] Arcane Blast buff 400573 + nuke 1239700@60 (**cap 4 CONFIRMED** via
      `CumulativeAura=4`, **8s CONFIRMED** via `SpellDuration 31`; effect
      split CORRECTED: op 0 +10% other spells, op 22 +10% AB damage
      multiplier, op 14 **+175% AB MANA COST** — the kit's "+175% AB damage"
      was the cost mod; nuke casts 15% of base mana) — mage arcane
- [x] Missile Barrage talent 400588 (roll 40 on AB via aura 42, others
      halved) + proc 400589 (**15s**, channel −50%, mana −100%, missile
      period −500ms) — mage
- [x] Holy Shock 10s CONFIRMED (CategoryRecoveryTime 10000 on 20473 AND
      1311606; live-cast id OPEN) / Light's Vigil cast 1311595@60, buff
      1310909, CategoryRecoveryTime 6000 on EVERY rank (1310911/1311590/
      1311595 — re-probed 2026-09-17 via SpellCooldowns keyed by SpellID; the
      earlier "no cooldown row / 180s estimate" came from the RecoveryTime
      column only and is RETRACTED: it is a 6s rotational mark, not a burst
      CD) / Holy Strike 10333@60 max (kit "level 6" ↔ 679@6) / Infusion of
      Light buff 53672 (talent/learn row 426065; live proc-id confirmation
      OPEN) — paladin

Consequence: all resolved → wave-1 authoring starts; any miss → its delta
waits, next-ranked delta moves up.

## P2 — the four GATE probes (unblock waves 2–3; run in-game day 1)

| # | Probe | Gates | Method | If flipped |
|---|---|---|---|---|
| 1 | **Furor energy-on-shift formula** (cat entry = f(elapsed time, energy on exit), never net gain) | druid cat (PROMOTED #5) + bear (#6) + leveling | **DBC-CONFIRMED 2026-09-17 (rework shipped)**: Furor 17056's client text is now "you will regain [X]% of the Energy you had when you were last in Cat Form, plus [Y] Energy for each second you spent not in Bear Form, Cat Form, or Dire Bear Form, up to a maximum of [Z] Energy" — a capped restore, not the classic flat +40, so a shift can never net energy. cat_forever REMOVED the vanilla Powershift lane on that basis. Remaining in-game check: the exact X/Y/Z (behind unresolved $ tokens) and the pre-shift-bar comparison | If powershifting still nets energy → cat keeps vanilla powershift lanes; cat_forever becomes additive instead of destructive; re-rank |
| 2 | **Warrior rage-from-damage formula** (TBC-formula expectation) | fury (#7) + arms (#13) + prot (#11) | Bridge + in-game: hit a training dummy at known AP, compare rage gain vs vanilla/TBC formula curves | If vanilla formula → fury/arms vanilla rage lanes survive; wave-2 slot frees up |
| 3 | **Rogue constant-regen energy** (vs tick-pulse) | ALL rogue deltas (#20/22/23) | In-game: watch energy bar smoothness at rest; two samples 1s apart | If still tick-pulse → vanilla tick-sync logic stays; rogue deltas demote a notch |
| 4 | **Haste does NOT affect DoTs/drains/channels** (warlock, current demo build) | affliction (#10) + demo/destro stat lanes | Bridge periodic-effect read; in-game: haste buff active, count dot tick rate | If haste applies → affliction stat lanes change shape; Pandemic value rises |

## P3 — flip-risk claims (verify before their lanes are authored)

- [ ] **Touch of the Grave proc semantics** (Undead: per-DoT-tick? no ICD?)
      — warlock + rogue + mage racial lanes (warlock page calls it
      potentially "incredibly strong" if per-tick).
- [ ] **Demonic Pact persistence** (sacrifice buff survives summoning a
      DIFFERENT demon; re-summoning the sacrificed one cancels) — gates the
      entire demonology rotation (#17).
- [ ] **Frostfire Bolt lower-resist school swap** (DBC dual-school effect
      proof required) — mage fire/frost school-choice lanes.
- [ ] **Aimed Shot / Multi-Shot shared cooldown** + **traps usable in
      combat** — hunter BM/MM/SV lane shapes (#8/9/12).
- [ ] **Bane of Agony/Doom decoupled from the curse slot** (separate aura
      family) — all warlock dot/debuff lanes.
- [ ] **DoTs can critically strike** (era-wide: warlock + druid) —
      Pandemic / Predatory Instincts payoff lanes.
- [ ] **Blood Fury numbers** (cross-page contradiction: +10% AP vs +10%
      SP vs +25% legacy; duration 15s everywhere) — Orc on-use lanes in
      warrior/rogue/mage/warlock.
- [ ] **Berserking form** (static +10% attack/cast speed 10s? 3-min CD?
      page wording varies) — Troll lanes.
- [ ] **Berserk (druid): one spell, form-branched effects** (Bear: no
      Mangle CD + 3 targets; Cat: +100% CP-gen crit; fear immunity) —
      cat/bear burst windows.
- [ ] **Swiftmend no longer consumes the HoT** (still requires one) —
      resto spot-heal lane (#16).
- [ ] **Conflagrate no longer consumes Immolate at max Shadow and Flame**
      — destruction rotation (#18).
- [ ] **Restless Blades CD-discount shape** (2s per CP spent; exact CD
      list) — combat CD-recycling lane (#23).

## P4 — full per-kit checklist runs (first days, wave order)

Run each kit doc's verification checklist in build-order sequence, ticking
items as verdicts land: shaman → mage → druid (cat/bear/balance/resto) →
warrior → hunter → warlock → priest → rogue. Priest items carry the
source-tier caveat (Zockify demo page; refresh when an Icy Veins priest
overview appears). Paladin's delta lanes un-dormancy check rides the P1
pass (holy_forever bridge lookups go live).

## P5 — era-wide confirmations (background, first days)

- [ ] Baseline raid buffs (Kings / Divine Spirit / Improved MotW) — talent
      inference can drop those probes (`talent_inference_sylvanas`).
- [ ] Buff cap removed — totem/buff accounting simplification.
- [ ] Merged spell hit/crit + merged melee hit/crit — stat-read lanes.
- [ ] ⅓ healing→spell-damage conversion — healer solo lanes.
- [ ] World buffs in raids (expected nerf/removal) — meta expectations only.
- [ ] Built-in damage meter + cooldown manager — validates CD-tracking lane
      shapes; observe what data surfaces expose to external readers.
- [ ] Skyborne druid form list (unpublished) — form-lane watch item.
- [ ] Talent DB2 shape on the beta client — 16-point gold-medal mapping
      (racials-and-talents.md follow-up).

## Convention

Every probe verdict lands in the owning kit doc (checkbox + date + one-line
verdict). A flipped claim updates the kit's rotation-impact rows the same
day. The build order re-ranks only when a gate probe (P2) or a P3 flip
changes a wave's relative ranking — apply the decision table in
phase4_build_order.md (probe verdict → re-rank): a lookup, not a research
pass.
