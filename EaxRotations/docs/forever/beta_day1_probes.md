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
apply the listed build-order consequence. Step-by-step in-game
execution for every open probe lives in **beta_smoke_checklist.md**
(the session runbook, blocks 0-5); this file stays the verdict ledger.

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

## Block 0/1 capture — instrumented 2026-09-19

The Block 0 items below (version surface, race detection, buff-points read,
reader-surface inventory) and the three P2 gate probes (furor energy-on-shift,
rage-from-damage, haste-vs-DoT ticks) no longer need a stopwatch and a notebook:
`shared/live_probe_sylvanas.lua` (`NS.LiveProbe`) captures them in-engine, and
because the client exposes no console, every capture is a MENU action. Both menu
implementations' Diagnostics sections expose the same operations -- Engine
Report, Snapshot Now, Arm Capture (all | forms | ticks | rage), Flush Capture,
Disarm Capture -- built from one published list (`NS.LiveProbe.menu_buttons()`)
so the legacy tree and the declarative page cannot drift, with output going to
the same console log as "Dump Learned Spells". Arm, do the in-game thing, flush,
read. The runbook in `beta_smoke_checklist.md` carries the exact button per item.
Their verdicts stay OPEN until a session produces the output; what changed is
that a verdict now costs three clicks and a paste.

## P1 — wave-1 name resolution (unlocks days 1–3 authoring)

Every wave-1 lane resolves by name or goes dormant. One pass (verdicts
2026-09-17, beta 1.60.1.69893 DBC unless noted):

- [x] Maelstrom Weapon — shaman enhancement (buff 408505 + talent 408498
      resolve; **stack cap CONFIRMED = 5** via SpellAuraOptions CumulativeAura
      on 408505 and the talent row's third effect base_points; proc mask
      81920 = melee hit, ProcChance 100 — the spend-at-5 gate is DBC-derived
      now, no in-game probe needed)
- [x] Stormstrike (8s CD confirmed: RecoveryTime 8000) / Improved
      Stormstrike — **RESOLVED 2026-09-19, no lane change needed**: the
      dodge-parry proc is client-wired, not a talent-table entry. Row 1223031
      "Improved Stormstrike" carries proc mask 40 (= 8 dodge | 32 parry) at
      100% with three dummy effects (base 20); 1238931 is the class-less 15s
      +50% buff variant; 1214300 is the combined "Improved Stormstrike/Windfury
      Weapon" row. No DBC row links the proc to Stormstrike 17364 because the
      reset itself is native behavior. Our enhancement delta gates the lane on
      `NS.spell_ready(SPELLS.Stormstrike, target, ...)` — the live cooldown —
      so a reset simply makes the lane fire sooner; its "8s cadence" comment
      describes RecoveryTime, not an assumption the reset breaks.
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
      Wake of Fire — **RESOLVED 2026-09-19; the lane is no longer blocked**:
      there is no trigger link to find, and that is the mechanic, not a gap.
      11078 is the ABILITY row (class 3, level 1, proc mask 2 = on-kill, aura
      107 base −2000 misc 11 + dummy 50) — never on the player as an aura —
      and **1312934 is the 20s window row** ("Killing a non-trivial target
      increases the critical strike chance of your next Fire Blast cast within
      $1312934d by $m2%", aura 107 base +50 misc 7, proc mask 65536) applied
      natively on the kill. Same shape as Infusion of Light: the ability's own
      text is the only reference to its window id, so nothing in the DBC
      "wires" it. Consequence: a Forever fire lane can now gate
      `has_buff(by_buff["Wake of Fire"])` and prefer Fire Blast inside the
      window; the builder pins the window row in `BUFF_OVERRIDES` (the
      baseline would have handed the lane the ability row, against which a
      buff read is always 0), and the audit holds the by_buff pin. Authoring
      the lane is tracked in the post-launch hardening backlog. — mage
- [x] Arcane Blast buff 400573 + nuke 1239700@60 (**cap 4 CONFIRMED** via
      `CumulativeAura=4`, **8s CONFIRMED** via `SpellDuration 31`; effect
      split CORRECTED: op 0 +10% other spells, op 22 +10% AB damage
      multiplier, op 14 **+175% AB MANA COST** — the kit's "+175% AB damage"
      was the cost mod; nuke casts 15% of base mana) — mage arcane
- [x] Missile Barrage talent 400588 (roll 40 on AB via aura 42, others
      halved) + proc 400589 (**15s**, channel −50%, mana −100%, missile
      period −500ms) — mage
- [x] Holy Shock 10s CONFIRMED (CategoryRecoveryTime 10000 on every
      player-cast row) — **live-cast id RESOLVED 2026-09-19**: the castable
      ladder is 1311606 (Rank 1, level 30, 160 mana) / 20473 (Rank 2, 40, 225)
      / 20929 (Rank 3, 48, 275) / 20930 (Rank 4, 56, 325) — all class 10, all
      trainer-taught (SkillLineAbility acquire=0), all start_recovery 1500ms;
      the 259xx family is the internal damage/heal decomposition (no mana, no
      cooldown, acquire=3, classmask=2) and 444894 is the mana-costed
      level-56 row with no cooldown. The class-map ladder ends at 20930, which
      matches the client's own trainer ladder for a 60, so no lane change was
      needed. NOTE for leveling: the Forever rework adds the level-30 rank
      (1311606) — a 30–39 paladin knows only that row, which the TBC ladder
      does not carry.
      / Light's Vigil cast 1311595@60, buff 1310909, CategoryRecoveryTime 6000
      on EVERY rank (1310911/1311590/1311595 — re-probed 2026-09-17 via
      SpellCooldowns keyed by SpellID; the earlier "no cooldown row / 180s
      estimate" came from the RecoveryTime column only and is RETRACTED: it is
      a 6s rotational mark, not a burst CD)
      / Holy Strike 10333@60 max (kit "level 6" ↔ 679@6)
      / Infusion of Light — **live proc-id RESOLVED 2026-09-19, and it fixed
      a dead lane**: the live buff is **437063** (15s, effect 6 aura 107 base
      −1000 misc 10, proc mask 16384, aura text "Reduces the cast time of your
      next Holy Light spell by $m1 sec"), applied by ability 426065, which the
      rune 426180 "Engrave Belt - Infusion of Light" grants (426180 → 426179 →
      426065). The old TBC row **53672 is ORPHANED in this build** — no
      EffectTriggerSpell, no EffectBasePointsF link, no EffectMiscValue
      payload, no SpellCooldowns.AuraSpellID, no RequiresAuraSpellID, no
      Talent row, and the only text naming `$53672` is its own description.
      `holy_forever.lua` gated that row through the buff mirror, so
      `Forever_InfusionOfLightWeave` could never fire on the live client;
      `BUFF_OVERRIDES` in the builder now pins 437063 and
      `test_paladin_holy_forever` + the audit's by_buff role pin hold it.
      Evidence: `python tools/probe_forever_spell_rows.py --refs 53672`
      / `--id 437063` / `--refs 437063` — paladin

Consequence: all resolved → wave-1 authoring starts; any miss → its delta
waits, next-ranked delta moves up.

## P2 — the four GATE probes (unblock waves 2–3; run in-game day 1)

| # | Probe | Gates | Method | If flipped |
|---|---|---|---|---|
| 1 | **Furor energy-on-shift formula** (cat entry = f(elapsed time, energy on exit), never net gain) | druid cat (PROMOTED #5) + bear (#6) + leveling | **DBC-CONFIRMED 2026-09-17 (rework shipped)**: Furor 17056's client text is now "you will regain [X]% of the Energy you had when you were last in Cat Form, plus [Y] Energy for each second you spent not in Bear Form, Cat Form, or Dire Bear Form, up to a maximum of [Z] Energy" — a capped restore, not the classic flat +40, so a shift can never net energy. cat_forever REMOVED the vanilla Powershift lane on that basis. Remaining in-game check: the exact X/Y/Z (behind unresolved $ tokens) and the pre-shift-bar comparison | If powershifting still nets energy → cat keeps vanilla powershift lanes; cat_forever becomes additive instead of destructive; re-rank |
| 2 | **Warrior rage-from-damage formula** (TBC-formula expectation) | fury (#7) + arms (#13) + prot (#11) | **NOT client-resolvable (2026-09-17)**: rage math lives in no extracted table (the Gt* game tables are absent from this build), so the DBC cannot answer it. fury_forever shipped only the verdict-independent subset (the DBC-confirmed Recklessness CD-split lane; passives documented) and every baseline rage reserve stays conservative. In-game method stands: hit a training dummy at known AP, compare rage gain vs vanilla/TBC curves | If vanilla formula → fury/arms vanilla rage lanes survive; wave-2 slot frees up |
| 3 | **Rogue constant-regen energy** (vs tick-pulse) | ALL rogue deltas (#20/22/23) | **CONFIRMED 2026-09-18 (beta-verification pass)**: Icy Veins' per-spec PvE guides (Assassination/Combat/Subtlety) + the 2026-09-15 class overview state constant-regen energy; the guides now UPDATE consistently, treating the earlier BlizCon-demo caveat as resolved. Threshold lanes re-derive to DBC SpellPower costs: Mutilate 60 (all ranks), Venom 25+1CP, Eviscerate 35, Rupture/SnD/Expose/Kidney 25, Sinister Strike 45, Backstab/Ambush/Garrote 60/60/50, Hemorrhage 35 | If still tick-pulse → vanilla tick-sync logic stays; rogue deltas demote a notch |
| 4 | **Haste does NOT affect DoTs/drains/channels** (warlock, current demo build) | affliction (#10) + demo/destro stat lanes | Bridge periodic-effect read; in-game: haste buff active, count dot tick rate | If haste applies → affliction stat lanes change shape; Pandemic value rises |

## P3 — flip-risk claims (verify before their lanes are authored)

- [ ] **Touch of the Grave proc semantics** (Undead: per-DoT-tick? no ICD?)
      — warlock + rogue + mage racial lanes (warlock page calls it
      potentially "incredibly strong" if per-tick).
- [ ] **Demonic Pact persistence** (sacrifice buff survives summoning a
      DIFFERENT demon; re-summoning the sacrificed one cancels) — gates the
      entire demonology rotation (#17).
      **RESOLVED 2026-09-17 (demo day-1)**: the client text of 425464 carries
      the rule verbatim; the #17 partner lane implements it. In-game still
      worth confirming: a third demon (Voidwalker/Felhunter) may be summoned
      without cancelling a school aura.
- [ ] **Frostfire Bolt lower-resist school swap** (DBC dual-school effect
      proof required) — mage fire/frost school-choice lanes.
- [ ] **Aimed Shot / Multi-Shot shared cooldown** + **traps usable in
      combat** — hunter BM/MM/SV lane shapes (#8/9/12).
- [x] **Drain Hope vs Wrack** (2026-09-18, beta-verification pass):
      RESOLVED — the client has NO "Drain Hope" row (full-name scan, any
      class); the warlock kit's capstone exists under the name **Wrack**
      1316697@40 ("Tears the target apart from within... increasing the
      damage they take from your other Shadow damage over time effects"),
      and Improved Drains 403511 names it explicitly ("your Drain Life,
      Drain Soul, and Wrack spells"), confirming the same design slot. The
      #10 affliction delta maintains Wrack at the head of the dot block —
      the verdict stands as shipped on day 1; nothing further to lane.
- [ ] **Bane of Agony/Doom decoupled from the curse slot** (separate aura
      family) — all warlock dot/debuff lanes.
- [ ] **DoTs can critically strike** (era-wide: warlock + druid) —
      Pandemic / Predatory Instincts payoff lanes.
- [ ] **Blood Fury numbers** (cross-page contradiction: +10% AP vs +10%
      SP vs +25% legacy; duration 15s everywhere) — Orc on-use lanes in
      warrior/rogue/mage/warlock.
- [x] **Berserking form** (2026-09-18, racial sweep): RESOLVED in the DBC —
      the Troll-owned row is 20554 (+10% spellcasting/attack speed 10s,
      RecoveryTime 180000, SkillLineAbility RaceMask 128 = Troll, SpellLevel
      1); the TBC-era 26297 row is ABSENT from the Forever client, and the
      1286304 namesake is an orphan row (no description/level/CD). FIX:
      shared/racial_manager_sylvanas.lua now splits the id per era
      (is_forever -> 20554, else 26297); pinned in test_racial_manager.lua,
      proven by revert. In-game probe reduced to the buff's observed duration.
- [ ] **Berserk (druid): one spell, form-branched effects** (Bear: no
      Mangle CD + 3 targets; Cat: +100% CP-gen crit; fear immunity) —
      cat/bear burst windows.
- [x] **Swiftmend no longer consumes the HoT** (2026-09-17, resto day-1):
      RESOLVED as client-text evidence — 18562 has a 15s cooldown and no
      consumption clause / aura-removal effect row; the #16 lane ships as a
      non-consuming spot heal. In-game confirm the HoT aura SURVIVES a cast
      (kill the target's Rejuv timer mid-cast and re-read).
- [x] **Wild Growth party HoT + CD** (2026-09-17, resto day-1): RESOLVED —
      ladder 408120@40 / 1238214@50 / 1238215@60, CategoryRecoveryTime 6000,
      "Heals the target and their party for 98 over 7". The #16 lane declares
      the 6s cooldown.
- [ ] **Tree of Life 439745 form semantics** (shapeshift? duration? aura row?
      the +11% healing-received text has unresolved `$a1` radius) — resto
      form lane candidate; NOT laned in #16. Recorded 2026-09-17.
- [ ] **Rejuv/Swiftmend same-second GCD interaction** (GotE's 1s GCD vs the
      standard 1.5s floor) — the #16 blanket's throughput assumption.
- [ ] **Demonic Sacrifice as a 60 ability** (trainer/engraving source; the row
      18788 has no SpellClassOptions so the bridge cannot carry it) + the
      Decimation $m1/$m3/$m4 token values (cast reduction / HP threshold /
      bonus damage) — the #17 sacrifice cast stays manual until the source is
      known. Recorded 2026-09-17.
- [ ] **Demonic Brand pet-tank window** (Searing Pain threat reduction + the
      pet's next 2 attacks "generate high threat") — no threat API surface;
      world/solo lane, not automated in #17.
- [ ] **Bane of Havoc rules** (one Bane per warlock; does a Bane share the
      Curse slot on the same target?) + the mirror-damage attribution — the
      #18 cleave lane banes an off-target and aborts when one Bane is
      already placed. Recorded 2026-09-17. **Extended 2026-09-17 (warlock
      leveling)**: the #26 amp lane maintains Bane of Agony + Curse of the
      Elements simultaneously per the kit's family texts — if the in-game
      slot turns out shared, that lane churns and must be removed.
- [x] **Shadow and Flame windows** (2026-09-17, destro day-1): RESOLVED by
      the client text + effect dump — 426316 applies 1293816 ("Shadow",
      +10% shadow after Conflagrate) and 426311 ("Flame", +10% fire after
      Shadowburn); both rows are class-less and now pinned through the
      builder's CLASS_LESS_BUFF_NAMES. The max-rank no-consume claim is
      CORRECTED to Backdraft 427713 / S&F's 20% chance.
- [x] **Penance dual-mode + 12s cooldown** (2026-09-17, disc day-1): the
      cast row 1316995 carries both the damage and heal clauses (the
      internal channel rows win the raw @60 tie — pinned in MAXRANK_
      OVERRIDES), CategoryRecoveryTime 12000. In-game: confirm the tick
      count/interval and crit behavior.
- [x] **Divine Aegis shield id + PW:S interplay** (2026-09-17, disc day-1):
      the applied absorb row is 431624 (effect 6 aura 69, base 2), pinned in
      BUFF_OVERRIDES; the #19 shield lane counts both absorbs. In-game:
      whether Aegis and PW:S absorbs stack or replace one another.
- [x] **Soul Warding deltas** (2026-09-17, disc day-1): effect rows confirm
      −4000 ms / −15% mana; PW:S CategoryRecoveryTime 4000 → the talented
      loop is Weakened-Soul-limited. [PROBE: confirm the 4s CD is truly gone
      in-game — a category CD might not accept a full reduction.]
- [x] **Venom + Mutilate effect shapes** (2026-09-17, assassin day-1):
      RESOLVED by the effect dump — Venom 1310703 = +30% poison damage /
      +10% application chance; Mutilate = 2 CP + two weapon strikes + a 20%
      poisoned dummy. [PROBE: the Forever Mutilate text has no "must be
      behind" clause (the TBC row does) — confirm a front-facing cast lands;
      if the client enforces behind, add the TBC positional gate.]
- [x] **Rogue constant-regen energy** (P2 #3, CLOSED 2026-09-18):
      CONFIRMED constant regen via the updated Icy Veins per-spec guides +
      class overview. The #20 assassination Venom lane re-derived to the DBC
      SpellPower cost (25 energy + 1 combo point, rows 314521/314522) + a
      20-energy CP-buffer — the baseline pooling flag held the window at its
      own cost boundary. #22/#23 re-derivation follows as its own unit.
- [x] **Devouring Contagion spread + universal DP** (2026-09-17, shadow
      day-1): RESOLVED by the client text/effects — 1309950 = −50% DP mana
      + a 10y on-death jump; DP is rune-granted ("Gain the Devouring Plague
      ability" rows referencing the vanilla 19280 ladder) so every race
      reaches the baseline's lane. [PROBE: the jump target selection and
      whether the remaining duration carries.]
- [x] **Improved Mind Flay numbers** (2026-09-17, shadow day-1): 1225139
      reads +damage / +yards / slow; the baseline MindFlay lane has no range
      gate so the extension is passive. [PROBE: the exact +yards and slow %
      in-game; Early Demise 1310076 is a BaseLevel-0 bridge gap like Fingers
      of Frost — the #21 lane's window matches the talent condition
      regardless.]
- [x] **Thousand Cuts + Cutthroat shapes** (2026-09-17, subtlety day-1):
      RESOLVED by the client text — TC 1310721 discounts Hemorrhage/Backstab
      by 3/stack (applied row 1310723, pinned); Cutthroat 462708 procs a
      stealth-free Ambush (applied row 462707, pinned). [PROBE: the TC stack
      cap (kit: 5), the Cutthroat proc chance (m1%), and whether the proc's
      Ambush still needs behind/dagger.]
- [x] **Rogue battery lane-proof gap** (2026-09-18, beta-verification
      pass): the battery's class-map mock lacked Hemorrhage/Backstab, so the
      subtlety ThousandCuts lane and combat PuncturingWounds lane never
      actually loaded in any battery run — both scenarios were green while
      proving nothing. The mock now carries both class-map actions
      (Hemorrhage 17348/17347/16511, Backstab 11281..53 — vanilla ladders,
      not literals in spec code) and both lanes are proven firing
      (subtlety 29 strategies, combat 21, never-fires=0).
- [x] **Restless Blades + Puncturing Wounds** (2026-09-17, combat day-1):
      RESOLVED by the client text — RB 1241797 names the five tracked CDs
      (AR/BF/Evasion/Sprint/Vanish, $m1 sec per CP); PW 1224716 gives
      Backstab +crit and a CP-proc chance. [PROBE: the RB per-CP value and
      whether Rupture shaves; Hack and Slash 13960 is a class-less row
      (bridge gap, passive) and Blade Dance 400012 is rune-granted — both
      recorded in the kit checklist.]
- [x] **PoM + Binding Heal + Litany shapes** (2026-09-17, holy day-1):
      RESOLVED by the client text/effects — PoM 1240827@60 applies the aura
      1240849 (10s category CD, pinned in BUFF_OVERRIDES); Binding Heal
      1240774 heals target + caster; Litany 1317006 refunds mana on a
      different-spell heal. [PROBE: the PoM jump count/radius, the Litany
      refund %, and Binding Heal's threat reduction; Twilight Focus 14913
      is a passive.]
- [x] **Power in Light smite core** (2026-09-17, smite day-1): the Penance
      damage lane + the debuff-driven Holy Fire upkeep replace the
      cast-on-cooldown lane. [PROBE: whether the +15% applies per Penance
      tick and whether the HF debuff refresh window matches the DoT
      duration in-game.]
- [x] **Paladin Holy Strike ladder** (2026-09-17, paladin leveling day-1):
      679@6 / 678@12 / 1866@20 / 680@28 / 2495@36 / 5569@44 / 10332@52 /
      10333@60, trainer-taught under Retribution; the leveling lane casts a
      {maxrank, rank-1} ladder (levels 12-60). [PROBE: the exact 12s
      cooldown at the low ranks and the @6 rank id — the bridge mirrors
      carry one id per name, so a rank-ladder mirror is a close-out
      candidate.]
- [x] **Druid Omen clearcast for leveling** (2026-09-17, druid leveling
      day-1): Omen of Clarity 16864 resolves in all three bridge mirrors
      (the cat_vanilla precedent reads the same id as the clearcast buff);
      the leveling lane fires the expensive ability free. The form-energy
      half is a no-op (Furor capped; no powershift lane in the leveling
      file).
- [x] **Warrior Victory Rush** (2026-09-17, warrior leveling day-1): 402927
      (level 20, 30s CD) is rune-granted ("Engrave Gloves - Victory Rush")
      and the VICTORIOUS enabler 402975 resolves in all three mirrors; the
      leveling lane fires inside the kill window. [PROBE: confirm the rune's
      in-game source and the heal percentage; the rage-formula watch stays
      the standing P2 probe.]
- [x] **Conflagrate no longer consumes Immolate** (2026-09-17, destro day-1):
      CORRECTED — the max-rank Conflagrate 18932 still consumes; the
      unconditional no-consume is Backdraft 427713 (+ the 427714 haste buff),
      and Shadow and Flame 426316 carries a 20% chance. No lane needed (the
      baseline Conflagrate lane's gates are unaffected).
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

---

## Racial-rework sweep (2026-09-18, post-Deep-Dive / per-class overviews)

Blizzard's racial rework (2 active + 2 passive per race; weapon-skill racials
became crit) is live on beta. Every reworked/new active was queried against
the Forever DBC (wowsims_forever.db, 1.60.1.69893):

| Racial | Client verdict | Action |
|---|---|---|
| Orc Blood Fury | 20572 present, 180s CD, "AP and Spell Power by $s1%" — resolves the cross-page AP-vs-SP contradiction as **AP+SP** | racial_manager entry already 20572 — no change |
| Troll Berserking | **26297 absent; 20554 is the Troll row** (haste 10% 10s, 180s CD); 1286304 orphan | **FIXED** in racial_manager (era-split id); test + revert proof |
| Undead Will of the Forsaken | 7744 present, 120s CD (no-immunity rework is text-level) | entry already 7744 |
| Tauren War Stomp | 20549 present, 120s CD (the 448707/1222567 band are NPC/variant rows) | entry already 20549 |
| Human Perception | 20600 present, 180s CD | entry already 20600 |
| Dwarf Stoneform | 20594 present, 180s CD | entry already 20594 |
| Gnome Escape Artist | 20589 present, 120s CD | entry already 20589 |
| Night Elf Shadowmeld | 20580 present (CD 0; "usable in combat" rework is text-level) | entry already 20580 |
| **Arcane Torrent** | **ABSENT from the Forever client** (no SpellName row at all) | Blood Elf is not a Forever-playable race for any shipping spec file; the vanilla battery's (b) pin for warlock RacialArcaneTorrent already documents "no BE in vanilla" — Forever inherits the same pin (no lane ships) |
| Gnome Eureka! | 1259812..23 present, 120s CD | recorded as a burst-window candidate; no day-1 lane (race-gated actives need in-game race detection first, same gate as the priest racials) |
| Night Elf Elune's Light | 1259799 present, 180s CD (+10% crit 15s) | recorded as a burst-window candidate (same race-gate rule) |
| Skyborne actives (Walk on Air 1259416, Read Ley Line 1259705, Skysight 1259686) | all present | non-combat/regen utility — no rotation lane; recorded |
| Shatter Curse 1299026, Rapid Regeneration 1260270, Touch of the Grave 1260189..201, Will to Survive 1259718 | present | defensive/proc racials — outside rotation scope; recorded |

Race-gated active lanes (Eureka!, Elune's Light, the four priest race spells)
stay unlaned until in-game race detection is confirmed — the same rule the
priest kit recorded on 2026-09-18. Nothing in this sweep is guessed: every
row above was read from the beta DBC directly.

## Seal of Fury taunt pair (protection delta, 2026-09-18)

- DBC: Seal of Fury ladder 1311649@10 / 1311656@18 / 20163@25 / 20419@34 /
  20421@42 / 20422@50 / 20423@58; trigger rows point at the Judgement ids;
  absorb text confirmed ("grants an absorb shield equal to $m2%"). The
  Judgement 20271 row keeps RecoveryTime 10000 and the kit's
  "does not consume the Seal" behavior holds on Forever (seals 30s).
- LANED (day-1 completion): `forever_pal_prot_fury` /
  `forever_pal_prot_judgement_taunt` battery scenarios +
  `test_paladin_protection_forever.lua`. The taunt is the first prot taunt
  in any era of this engine.
- REDUCED PROBE (in-game): confirm the live Judgement taunt requires Seal
  of Fury specifically (the DBC trigger linkage suggests yes) and whether
  the absorb shield reads via buff points (Pattern 11) — if so, a future
  lane can gate re-cast on shield value remaining.
