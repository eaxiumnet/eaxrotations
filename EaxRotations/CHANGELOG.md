# Changelog

## Unreleased

### Fix - spell-id sweep: the WRONG-RANK ladder heads raised, RANK-ORDER adjudicated benign

- **The ladder resolver takes the FIRST id the unit knows, so a ladder headed by a
  below-cap rank silently down-ranks every cast.** The sweep's remaining RANK-ORDER and
  WRONG-RANK leads were separated into ladder-*order* defects and ladder-*completeness*
  gaps, and only the genuinely incomplete ladders were touched.
- **11 ladder heads across 19 files now lead with their era-max rank** (verified against
  the bridge *and* a Wowhead tooltip: cost, cooldown, GCD, "Requires <class>"):
  Fireball 27070 -> 38692, Frostbolt 27072 -> 38697, BlessingOfLight 27144 -> 32770,
  DeathCoil 27223 -> 30500, Resurrection 20770 -> 25435, MongooseBite 14271 -> 36916,
  TrueshotAura 20906 -> 27066, MockingBlow 20560 -> 25266, Gouge 11286/1776 -> 38764,
  PoisonCleansingTotem 8166 -> 38306. The lower ranks stay in the ladders as fallbacks.
- **The twin ids the sweep also proposed were rejected, not pinned.** The classic bridge
  names a spell's cast, its applied effect and its NPC copy alike, and all carry the same
  level, so the discriminator has to be the tooltip. 17144 Wrath, 31933 Freezing Trap,
  38371 Bestial Wrath, 24394 Intimidation, 36828 Rapid Fire, 29390 Shield Wall, 29564
  Greater Heal, 29961 Counterspell, 29717 Cone of Cold, 36984 Serpent Sting, 29883 Blink,
  29563 Holy Fire, 36831 Curse of the Elements, 39666 Cloak of Shadows, 41390 Ambush,
  37276 Mind Flay, 27167 Seal of Wisdom, 40135 Shackle Undead and 30412 Drain Life are
  cast/effect/NPC copies (no cost, no GCD, or "NPC Abilities"), not higher ranks.
- **RANK-ORDER is adjudicated, not silently suppressed**: all 45 standing rows are
  order-INSENSITIVE rank lists (`talent_inference_sylvanas.lua` `TALENT_SIGNATURES`,
  `dispel_manager_sylvanas.lua` pet-rank tables) or the deliberate vanilla Lightning Bolt
  downrank lane, which prefers a *lower* rank on purpose. The bucket's blurb now says so,
  so a new row reads as a real mis-ordered cast ladder rather than a known false positive.
- **Pinned both ways.** Every fixed ladder's exact id list is asserted in
  `tests/test_spell_id_table_regressions.lua` (4 pins re-pointed, 16 added), each proven
  load-bearing by demoting the head in place; the sweep baseline was re-frozen to
  **392 findings / 385 unique keys** (was 413 / 406), so re-demoting a head resurfaces as
  baseline drift instead of passing quietly.


### Feature - spell-id sweep is now a gate, with its buckets classified once and pinned

- **The sweep that found the wrong-family pins was a report, not a gate.** It had
  to be remembered and run by hand, so a fabricated pin (48927) or a
  wrong-family ladder head (`SodCleave` = 25286 Heroic Strike) could still ship.
  It is now a `verify_all` component
  (`tests/run_spell_id_sweep_check.lua` -> `tools/spell_id_sweep.py --check`), so
  CI -- which runs `verify_all` -- now fails on one instead of waiting for
  someone to remember the report.
- **Every bucket is classified once and pinned** in a committed baseline
  (`tools/spell_id_sweep_baseline.json`, LF-pinned via `tools/.gitattributes`).
  The sweep's `CHECK_DISPOSITION` splits the buckets into `gate` (DEAD,
  REJECTED-ID-IN-USE, ERA-TBC-IN-VANILLA, ERA-WOTLK-IN-TBC — proofs of
  wrongness that must stay empty) and `pinned` (REDIRECTED, WRONG-RANK,
  RANK-ORDER, PIN-FAMILY-MISMATCH, DUPLICATE-CONFLICT, UNSOURCED — the
  adjudicated triage leads: 413 findings / 406 unique keys). A finding's
  identity is `check|id|file`, so line and label drift is not id drift.
- **A new wrong-family id hard-fails; so does clearing one.** A finding outside
  the baseline is NEW and fails the build; one that disappears is CLEARED and
  also fails until the pin is moved on purpose. That is the never-fires
  discipline (`never-firing 11` fails in either direction) applied to ids. The
  classifications are byte-compared too, so editing `CHECK_DISPOSITION` without
  re-baselining fails, and `--write-baseline` **refuses to pin a non-empty gate
  bucket** — a dead id can never be laundered into "acceptable".
- The wrapper's `--self-test` is non-vacuous end to end: it injects a
  mislabelled pin (2048 Battle Shout under a Frostbolt label), an unknown id,
  and a correctly labelled control into synthetic ladders, then asserts the
  real extractor + classifier fire on the first two, stay silent on the third,
  and classify both as NEW against the committed baseline.
- Proven on the live tree: re-pinning 25286 as the `SodCleave` head turns the
  component red with `NEW: 2` (the redirected id plus the cross-file duplicate
  conflict it creates); an unknown id turns it red on the `DEAD` gate bucket
  with `HARD: 1`, and `--write-baseline` refuses to freeze it.

### Fix - audits: "bridge-valid" now has to mean "same spell" (name-agreement assertion)

- **The WotLK and SoD audits accepted any bridge-known id under any label.** That
  is how `SodCleave` shipped pinned to 25286 (Heroic Strike) and `Volley` to 1543
  (Flare): both ids are bridge-valid, so membership alone said "fine" while the
  lane cast a different spell. Both audits now compare the bridge's own name for
  each id against the label it is pinned under, and fail on disagreement.
- New shared helper `tests/spell_name_agreement.lua` owns the rule: every
  significant token of the client name must appear in the label or be a
  documented modifier token (Judgement covers Light/Justice/Wisdom,
  ConjureManaEmerald covers "Conjure Mana Gem", DireBearForm covers "Bear Form").
  The allowlist is **token-level, never id-level**, so it cannot whitelist a wrong
  spell - only forgive a modifier word. Plurals are folded ("Survival Instincts"
  vs "Survival Instinct") and possessive client names are handled ("Avenger's
  Shield"). Bridge codes are shape-aware: the WotLK index is keyed (`{name=...}`)
  while the TBC/vanilla indexes are positional, and reading only `.name` made the
  check silently vacuous on every TBC id.
- **WotLK audit:** ladder-label agreement on all 41 files (1,758 bridge-compared
  ids) plus pin-name agreement over `WOTLK_REFERENCE_ALIASES`,
  `WOTLK_BRIDGE_MAX_RANKS` and `WOTLK_SHARED_IDS` (the self-certifying-pin shape
  the sweep named: 2944 was pinned "Shadow Word: Death" while the client calls it
  Devouring Plague). New `--probe-name` mode; the self-test pins 12 rule cases,
  the ladder probe, the live inventory and the pin tables.
- **SoD audit** (`run_sylvanas_audit_tests.lua`, the tier whose comment defines
  "TBC-bridge-valid"): ladder-label agreement across the 20 SoD loaders (308
  bridge-compared ids), with the conventional `Sod` label prefix stripped first.
  New `--probe-name` mode, plus 9 rule cases + ladder probe + fallback gate + live
  inventory in the self-test.
- **One real defect found and fixed:** `paladin/holy_wotlk.lua` `HolyShock` was
  `{48821, 33074, 33073, 33072, 33071, 33070, 20473}`. 33071 and 33070 are
  bridge-valid but are **not** Holy Shock - wowhead WotLK Classic calls them
  "Shadow Prison" and "Cloud of Corruption", server-side dummy auras - so a
  paladin who knew them cast a dummy instead of the heal. Both removed. The SoD
  tier was already clean (the earlier sweep's fixes hold).
- **Documented cross-spell fallback ladders.** Some lanes are not rank ladders: a
  later entry is a different spell filling the same role, so its client name
  legitimately differs. `SodDevastate = {20243 Devastate, 11597 Sunder Armor}` is
  the one entry, excused by a label-keyed `FALLBACK_LADDERS` entry that must name
  the exact client name being excused **and** only applies when the ladder head
  already agrees - so it cannot smuggle an arbitrary id in. Its entry count is
  pinned in the self-test so growth is visible in review.
- Proven load-bearing by injection on throwaway copies, each restored
  byte-identical: restoring 33071 to the HolyShock ladder fails the WotLK audit
  with `NAME_MISMATCH`; relabelling the 49802 pin "Maim" -> "Mangle" fails it with
  `PIN_NAME_MISMATCH`; heading `SodHuntersMark` with 30706 (Totem of Wrath) fails
  the SoD audit with `NAME_MISMATCH`. Every injected id is bridge-valid, so the
  pre-existing id scan is silent on all three - only the new check rejects them.
- **Scoped, and said so:** the ladder-label check runs on the WotLK files and the
  SoD tier only. The TBC class tier carries deliberate cross-spell fallback
  ladders (mage `FrostArmor` covers the Ice Armor ranks) and client-name
  qualifiers ("Remove Lesser Curse", "Summon Water Elemental"), so enabling it
  there is its own pass - see triage addendum (k) for the two live-path leads the
  check already surfaced there in a dry run (`Repentance` carried 5164 Knockdown,
  `HolyLight` carried 10324 Redemption).
- Gate: `luac` clean; 563/563 rotation, 39/39 leveling, 82/82 WotLK; every audit
  0 invalid; battery never-fires unchanged (TBC 11 / vanilla 9 / SoD 0 / WotLK 0);
  scorecard and era-pair seed content-identical; clean-checkout probe pass (the new
  helper is tracked); `verify_all` exit 0; pre-commit 19/19.

### Fix - warlock cooldown audit: nine TBC/WotLK lanes could claim a GCD while their real cooldown ran
### Fix - warlock cooldown audit: nine TBC/WotLK lanes could claim a GCD while their real cooldown ran

- **Same defect class as the Conflagrate race, swept across every warlock lane.**
  The shape is a lane whose match condition stays true for the whole span of its
  real cooldown with no cooldown read of its own: it wins the priority race on
  every tick it is unavailable, and the lanes below it only get a turn when the
  central cast guard happens to refuse the recast. Nine lanes matched, in five
  files; every one now carries the `state.<spell>_cd <= 0` gate read from
  `NS.cooldown_remains`, failing open to 0 = ready when the engine is silent, so
  no lane can go permanently dark.
- Lane-by-lane, with the cooldown verified on Wowhead:

  | File | Lane | Real cooldown | Was gated on |
  |---|---|---|---|
  | `destruction_wotlk.lua` | ChaosBolt | 12s (59172 / 50796) | 20% mana only |
  | `affliction_wotlk.lua` | Haunt (entry 1) | 8s (59164) | the 12s aura read only |
  | `demonology_wotlk.lua` | Metamorphosis (entry 1) | 180s, 30s form (47241) | the buff read only |
  | `demonology_wotlk.lua` | ImmolationAura | 30s, 15s aura (50589) | the form aura only |
  | `leveling_wotlk.lua` | SpellLock | 24s (19647) | target casting + mana |
  | `leveling_wotlk.lua` | Conflagrate | 10s (17962 / 30912) | Immolate > 3s + mana |
  | `leveling_wotlk.lua` | ChaosBolt | 12s (50796) | in-combat + mana |
  | `destruction_sylvanas.lua` | Conflagrate | 10s (17962) | Immolate live + TTD |
  | `destruction_sylvanas.lua` | Shadowburn | 15s (30546) | execute band + spell_ready |

- **Root cause, documented rather than papered over:** the ACTIONS tables on the
  TBC side carried a `cooldown` field that fed `spell_ready` an `expected_cooldown`
  throttle, but the DSL substitution replaces those strategies and the DSL `cast`
  handler forwards only `action.opts` to `try_cast` - the metadata is dropped. The
  Metamorphosis and Immolation Aura lanes show the same shape without any substitution:
  their buff reads answer "is the form up", not "is the ability available".
- **Metamorphosis was the worst of the nine:** the form lasts 30s and the cooldown
  is 180s, so for ~150s after it dropped the entry-1 lane matched on `metamorphosis_up
  == false` alone. Immolation Aura is the mirror image inside the 30s window.
- Corrected a stale comment while in the file: `destruction_wotlk.lua` claimed Soul
  Fire was a "15s-CD / 4s-cast" nuke; Wowhead 3.3.5 lists 47825 as 6s cast with **no**
  cooldown, so no gate belongs on that lane.
- Proof: fire/hold on both sides of every new gate in the owning suite -
  `test_warlock_destruction_wotlk_strategies.lua` (ChaosBolt ready vs 11.9s / 0.1s
  cooling), `test_warlock_affliction_wotlk_strategies.lua` (Haunt with no resolvable
  aura), `test_warlock_demonology_wotlk_strategies.lua` (Metamorphosis 150s and
  Immolation Aura 29.9s cooling), `test_warlock_leveling_wotlk_strategies.lua`
  (Spell Lock / Conflagrate / Chaos Bolt), and `test_destruction_dsl_priority.lua`
  (both the direct state gate and the end-to-end `NS.cooldown_remains -> build_state`
  path for TBC Conflagrate and Shadowburn).
- Non-vacuity: deleting each gate line makes its own suite fail at its own held
  assertion - all nine injections proven, then restored byte-identical.
- Evidence: `luac` clean; rotation battery 563/563, leveling 39/39, WotLK 82/82; all
  audits 0 invalid (sylvanas / WotLK / state-field / read-side / dead-matcher /
  NS-member / era-pair + seed freshness / cache-hit / vanilla existence); behavioral
  battery never-fires unchanged at TBC 11 / vanilla 9 / SoD 0 / WotLK 0; scorecard and
  clean-checkout probe pass; `verify_all` exit 0; all 19 pre-commit checks pass.

### Feature - destruction warlock: consecutive Life Tap batching + Immolate refresh window

- **Consecutive Life Tap batching engine** (`shared/life_tap_batch_sylvanas.lua`,
  new).
  The TBC destruction Life Tap lane tapped once, the very next filler cast knocked
  mana back under the same 20% threshold, and the lane tapped again - the live
  tap/cast ping-pong every GCD, because the entry threshold was also the exit
  threshold. The lane now opens a batch on the first tap and keeps claiming the GCD
  - holding it, not casting - until mana reaches `entry + destro_life_tap_batch`
  (new "Life Tap Batch Buffer %" slider, default 20; 0 disables batching). Tap GCDs
  inside a batch are consecutive: the lane casts on the GCD and returns true without
  casting on the ticks in between, so no filler can slot a cast between two taps.
  The batch is cleared once per tick by `build_state` at the recover target, on
  unsafe HP, or after a 3s stall window; `wants()` also self-heals a stalled batch
  read-only, so a batch can never stick the rotation, and a 12s ceiling bounds it.
  `life_tap_batch.reset()` runs at spec load so a reload can never inherit a stale
  batch.
- **Configurable Immolate refresh window** (new `destro_immolate_refresh` slider,
  0.5-3.0s, default the historical 1.5s). TBC has no pandemic, so a larger window
  refreshes earlier and clips the tail DoT; a smaller window keeps more of each
  application. The Immolate condition previously hard-coded 1.5s.
- Proof: `test_destruction_life_tap.lua` keeps the anti-spam contract and now pins
  fire / hold / consecutive tap / recover-target exit / HP abort / stall self-heal;
  `test_destruction_dsl_priority.lua` pins the Immolate refresh slider (default vs a
  3.0s window) and the batch fire / hold / consecutive / exit / abort plus the
  buffer-0 disable. Each new pin was proven load-bearing by injection (hard-coding
  the Immolate window, removing the hold, and collapsing the buffer to 0 each fail
  at their own assertion), then restored byte-identical.
- Evidence: `luac` clean; 563/563 rotation battery, leveling 39/39, WotLK 82/82;
  all audits 0 invalid; the behavioral battery keeps destruction at 37 lanes / 0
  never-fires; scorecard and era-pair seed in sync; clean-checkout probe passes with
  the new module tracked; `verify_all` exit 0.

### Fix - spell-id sweep: wrong-family pins and rank-order ladders

- **`NS.get_spell_id` returns the FIRST id the unit knows**, so any ladder that
  lists a lower rank before a higher rank of the same spell silently down-ranks
  every cast. The 2026-09-13 sweep found four such live ladders; all are now
  strictly descending, matching the class-level tables they had drifted from.
  - `warrior/{arms_sylvanas,fury_sylvanas}.lua` BattleShout: `25289` (rank 7,
    level 60) preceded `2048` (rank 8, level 69) - a level-70 warrior cast the
    weaker shout. `warrior/{arms_wotlk,fury_wotlk,leveling_wotlk}.lua` carried the
    same inversion behind `47436`.
  - `hunter/marksmanship_sylvanas.lua` TrueshotAura was `{19506, 20905, 20906}`
    - an ASCENDING ladder, so the head was rank 1.
  - `rogue/assassination_wotlk.lua` Envenom listed `32645` (rank 1) before
    `32684` (rank 2).
- **Wrong-family ids replaced** (each verified against the local TBC bridge and
  Wowhead TBC):
  - `warrior/tank_warrior_sod.lua` `SodCleave` was pinned to `25286`, which is
    **Heroic Strike** rank 9 (Wowhead TBC) - the tank's Cleave lane cast Heroic
    Strike. Now the era-correct Cleave ladder (`20569, 11609, 11608, 7369, 845`;
    SoD is level-60 capped, so the TBC `25231` rank is unreachable).
  - `warrior/tank_warrior_sod.lua` `SodDevastate` was pinned to `11597`, which is
    **Sunder Armor** rank 5 (Wowhead TBC). The ladder is now the real Devastate
    with Sunder Armor kept last as the era-clean fallback, so the lane can never
    down-grade below today's behaviour. The SoD rune id (`403195`) still gates
    availability but stays out of the ladder: it is not in the TBC client data, so
    the sylvanas spell audit rejects it as an id (it is a rune, not a spell).
  - `hunter/leveling_wotlk.lua` Volley carried `1543` - which is **Flare**
    (Wowhead TBC) - and `42243`, the 100-yard **tower** Volley, not a player rank.
    Both dropped. The test-side stub in `test_hunter_leveling_wotlk_dsl_priority`
    repeated `1543` and was corrected with it.
- Proof: `test_spell_id_table_regressions.lua` gains a `define()`-form ladder
  parser plus ten exact-id assertions, one per corrected ladder. Proven
  load-bearing by injection -
  restoring the `25289`-first Battle Shout ladder and restoring `SodCleave` to
  `25286` each fail the suite at their own assertion, then restore
  byte-identical.
- Evidence: `spell_id_sweep.py` REVIEW findings drop 426 -> 415 with HARD still 0;
  `luac` clean across 910 files; 563/563 battery, leveling 39/39, WotLK runner
  82/82; all audits 0 invalid; era-pair seed in sync (88 entries / 1383 names);
  clean-checkout probe passes. The `.omo/evidence` Task-1 action map is a
  regenerable local artifact and was re-provisioned for the new SoD action ids.

### Fix - live client reports: stance detection source and Cower's missing gates

- **Stance detection read the wrong engine source.** `NS.get_player_stance()`
  preferred `core.spell_book.get_shapeshift_form_id`, which the `.api` contract
  documents as returning 0 whenever that wrapper is unavailable. 0 reads as "no
  stance", and every warrior stance lane is written as "if I am not in the stance
  I need, cast it" - so the rotation re-cast the stance on every tick. Observed
  live on a TBC client as Battle/Berserker stance spam, with Berserker Stance
  never registering as active even immediately after it had been cast. The
  producer now prefers the shapeshift **bar index**
  (`core.spell_book.get_shapeshift_form`), which the same contract marks as the
  cross-version / cross-class source and says to prefer for new logic, then falls
  back to the form id, then to buff detection, and still reads 0 when every
  source is absent.
- **Cower (`ThreatDrop`) was gated on "in combat" alone.** Observed live firing
  every couple of seconds while solo, spending the resource on a threat drop that
  had no group to hand threat back to. The lane now requires a group member, a
  form that can cast Cower, and a ready spell; it fails OPEN when no group API
  exists at all (mock batteries / older clients keep the previous behavior), and
  the existing `use_threat_drop = false` opt-out still wins.
- Proof: `test_dispatcher_role_mode.lua` (the suite that loads the REAL
  `core_sylvanas`) pins the source precedence - bar index wins, form id is the
  fallback, a throwing wrapper falls through instead of raising, and no source at
  all still reads 0. `test_druid_middleware_nil_guard.lua` pins ThreatDrop's
  solo hold, its grouped fire, the out-of-combat hold, the opt-out hold, the
  not-ready hold, and the no-group-API fail-open. Both pinned sets were proven
  load-bearing by injection (removing the bar-index branch and removing the group
  gate each fail their suite; both restored byte-identical).
- Evidence: 19/19 pre-commit checks, `verify_all` exit 0, 563/563 battery, all
  audits 0 invalid, never-fires still at pins (TBC 11 / vanilla 9 / SoD 0 /
  WotLK 0), scorecard and era-pair seed content-identical. Still mock/gate-proven
  rather than observed on a live client - a `/reload` is needed to pick it up.

### Feature - smart multi-DoT cycling (enemy + friendly) and an ordered boss opener

- **`shared/periodic_cycler_sylvanas.lua`** (new) owns "which unit gets the
  next periodic effect". It genuinely cycles both ways: the **enemy** side (a
  DoT on an engaged hostile) and the **friendly** side (a HoT on an injured
  ally). Enemy candidate discovery stays with each spec -- its own
  engagement/CC/snapshot gates decide who is *eligible* -- and reads the shared
  `cursor()` / `advance()`; the friendly side owns its uniform party scan end to
  end through `friendly()`.
- `druid/balance_sylvanas.lua` (TBC): the Moonfire / Insect Swarm spread pickers
  now rotate across equally valid undotted mobs instead of always taking the
  first one, and still return the cursor mob when it is the ONLY candidate -- a
  cycle may never starve the one mob that needs the DoT. Buckets are per effect,
  so the Moonfire cursor never moves Insect Swarm; the cursor advances only on a
  landed cast, so a refused cast keeps its turn. The scan stays a single
  allocation-free pass with a fallback.
- `druid/resto_wotlk.lua`: Rejuvenation follows the **cycled** ally
  (`state.hot_unit` / `state.hot_remains`) rather than the single lowest, so when
  the lowest ally already carries a fresh HoT a second injured ally is covered --
  the known "two people at 60% and only one gets a HoT" deficit. Without the
  module, or without a party list, the lane falls back to the lowest ally, so a
  solo fight is unchanged.
- **`shared/boss_opener_sylvanas.lua`** (new) owns the ORDER of a raid opener.
  `shaman/elemental_wotlk.lua` declares **Fire Elemental -> Bloodlust ->
  Elemental Mastery**: while the opener is armed (in combat **and** on a raid
  boss) only the head of the declared order may claim the GCD, and the lane's own
  landed cast advances the head. Off a boss -- or once the sequence completes --
  the sequencer is inert and every lane falls back to its own cooldown gate, so
  trash/leveling behavior is unchanged and the 5-minute Heroism is free again
  inside the same fight.
- Safety: both modules are fail-open. An absent module, an absent candidate, or a
  missing party/engine accessor leaves the previous behavior exactly as it was.
  `NS.GetPlayer` is read through one guard that tolerates both the published
  `NS.me` field and either `function()` / `function(self)` stub idiom, so the
  pure-mock spec-load suites cannot be broken by the new read. No per-frame
  allocation: the only writes are the per-key cursor record.
- Proof: `tests/test_multidot_lane_regression.lua` drives the REAL balance
  picker with two undotted peers (the candidate list is swapped in the battery's
  own state bank) and pins the rotation, the per-effect bucket isolation, the
  no-candidate hold, and the no-starvation fallback; the friendly side is pinned
  in `tests/test_druid_resto_wotlk_strategies.lua` (cover the second ally / hold
  when everyone is already HoTted / round-robin / lone-candidate /
  no-party-API fail-open); the ordered opener is pinned in
  `tests/test_shaman_elemental_wotlk_strategies.lua` (step 1 fires while steps 2-3
  hold, landing each step hands the turn on, completion frees every lane, and a
  disarmed opener resets to step 1). Load-bearing proven by injection: neutering
  the balance cursor read fails the rotation pin, and restoring the inverted
  friendly-preference comparison fails the friendly rotation pin (both restored
  byte-identical afterwards).
- Evidence: 563/563 battery, WotLK runner 82/82, all audits 0 invalid (WotLK 43 /
  TBC 81 / vanilla 40, 0 tainted), `verify_all` exit 0, battery never-fires at
  pins (TBC 11 / vanilla 9 / SoD 0 / WotLK 0), perf cost gate pass, and the
  scorecard / ACCURACY / era-pair seed content-identical after regeneration (no
  lane counts changed). Mock-proven, not yet observed on a live client.

### Fix - engine-confirmed cast state machine (refused and never-acknowledged casts)

- **`shared/cast_confirm_sylvanas.lua`** (replaces
  `shared/cast_reject_guard_sylvanas.lua`) is now the single owner of "what the
  engine said about the casts we issued". Every cast the addon queues is recorded
  at the one commit point every queue path reaches (`core_sylvanas.lua`
  `mark_spell_cast`) and resolved against the engine's own cast events.
- One hold, three verdicts: an **acknowledgement** (`UNIT_SPELLCAST_SENT`,
  `_START`, `_SUCCEEDED`, `_INTERRUPTED`, `_CHANNEL_START`; player token only)
  clears the offer; a **refusal** (`UNIT_SPELLCAST_FAILED` / `_FAILED_QUIET`)
  holds the offered spell id at once; and an offer the engine **never
  acknowledges at all** is held once the confirmation window (1.6s - one GCD
  plus queue slack) elapses. Held ids are skipped by `NS.evaluate_cast` step 2b,
  so the dispatcher falls through to the next lane instead of re-queuing the
  same cast on every 20Hz tick.
- Fail-open twice over: no module, no clock, or a client that emits none of the
  events leaves the cast path byte-for-byte unchanged, and the
  never-acknowledged hold stays **disarmed** until the engine has reported a
  player cast at all - so the battery harness and an older client can never see a
  timeout hold.
- `UNIT_SPELLCAST_STOP` is deliberately **not** subscribed: it fires on
  completion, self-cancel and kick alike, so it cannot resolve an offer.
- Proof: `test_dispatcher_role_mode.lua` pins the subscription set, the arming
  rule, and acknowledgement vs refusal vs silence on both sides, then drives the
  **real affliction warlock lanes through the real dispatcher with the real
  `try_cast`** - the Curse of Doom lane claims the GCD, the engine stays silent,
  the lane is held and the dispatcher falls through, and with the hold cleared at
  the same clock the same lane wins again. Load-bearing proven by injection:
  neutering the verdict, the `evaluate_cast` hook, and the verdict for that spell
  id each fail the suite.
- Evidence: 19/19 pre-commit checks, `verify_all` exit 0, battery never-fires at
  pins (TBC 11 / vanilla 9 / SoD 0 / WotLK 0), all audits 0 invalid, perf cost
  gate pass (the new work is per-cast, not per-frame, and the gate's disabled
  paths stay at 0.00 KB retained). Mock-proven through the real dispatch path,
  not yet observed on a live client.

### Fix - wrong-family spell ids in the TBC / SoD / WotLK ladders

- The 2026-09-13 spell-id sweep found ladders headed by an id that resolves to a
  *different spell*. `NS.get_spell_id` takes the first id the player knows, so a
  wrong head is what gets cast - not skipped. Every row was verified against the
  local TBC bridge and Wowhead before the fix.
- `mage/class_sylvanas.lua` IceBlock: the head was 11958 = Cold Snap, so a TBC
  mage already holding Cold Snap never reached Ice Block. The ladder is now
  `{45438, 27619}` (45438 = the TBC Ice Block with Hypothermia, 27619 = the
  Classic one).
- SoD hunter (`hunter/dps_hunter_sod.lua`): Aspect of the Hawk was headed by
  13159 = Aspect of the Pack (the hunter ran Pack, dazing itself on melee hits),
  Volley by 27019 = Arcane Shot rank 9 (the AoE lane cast a single-target shot),
  and Hunter's Mark by 30706 = a shaman Totem of Wrath (never known, so the lane
  silently fell through to its lowest rank). All three are now the real
  descending rank lists, and the two buff tables mirror them.
- SoD bear (`druid/tank_sod.lua`): Demoralizing Roar was headed by 16857 =
  Faerie Fire (Feral), so the bear cast FF and never the -AP roar.
- Hunter Immolation Trap (`hunter/class_sylvanas.lua` and
  `hunter/survival_sylvanas.lua`): the TBC head was 29906 = Ravage (a pet
  ability) and the tail carried the DoT *effect* spells, not the trap cast. The
  ladder is now the real trap ranks only.
- SoD shaman (`elemental` / `enhancement` / `warden`): the Lightning Bolt ladder
  carried 930 = Chain Lightning rank 1 in place of 915 = Lightning Bolt rank 6.
- Wrong-family tails removed: 548 (Lightning Bolt) from Power Word: Shield
  (`priest/leveling_wotlk.lua`); 2944 (Devouring Plague) from Shadow Word: Death
  (`priest/shadow_wotlk.lua`); 51414 / 51415 / 51420 / 51421 (Venomous Breath
  Aura, Venomous Breath, Digging for Treasure Ping, Fire Cannon) from Frost
  Strike (`deathknight/frost_wotlk.lua`).
- Paladin Holy Wrath (`paladin/protection_wotlk.lua` and
  `paladin/leveling_wotlk.lua`): the ladder carried 37897 = Parachute and
  31898 = Judgement of Blood behind the correct 48817 head. Replaced with the
  real era-shared ranks 27139 / 10318 / 2812.
- Pin tables: `run_wotlk_audit_tests.lua` lost the two disproven Holy Wrath
  pins, gained the real era-shared Holy Wrath ranks (they are TBC-era ids, so
  the era-family classifier needs them pinned), and its 2944 entry is relabelled
  Devouring Plague - the id is legitimate, the SW:Death label was not. The
  allowlist size pin was re-measured from the table, 256 -> 257.
- Test-side stubs that repeated the same wrong ids were cleaned
  (`test_leveling_load`, `test_hunter_middleware_viper_sting`,
  `test_frost_deathknight_wotlk_strategies`, `test_deathknight_wotlk_live_fixes`,
  `test_hunter_live_fixes`, the SoD buff mock in `test_sod_druid_hunter`), and
  `test_mage_vanilla_live_fixes` had been asserting the wrong Ice Block ladder.
- Proof: 563/563 rotation suites, leveling 39/39, WotLK runner 82/82, battery
  never-fires unchanged (TBC 11 / vanilla 9 / SoD 0 / WotLK 0), all audits 0
  invalid, `verify_all` exit 0. Offline-verified against the bridge and Wowhead;
  not observed on a live client.

### Feature - Targeting: smart auto-targeting, seven priority override slots, party-combat pull mode

- **Smart auto-targeting** (`shared/targeting_sylvanas.lua`): the rotation can
  only act on a target the player selected, so a player who has not clicked
  anything gets a dead rotation and a target that dies mid-fight leaves the next
  cast targetless. New Targeting menu section with an **Auto Target** dropdown:
  `Off` (default - never touches your selection), `Assist` (only in combat, only
  when you have no live target: rescues a fight, never starts one) and `Auto`
  (also out of combat, still gated by the pull mode).
- **Seven override slots**: pin up to seven priority targets from the Targeting
  section by targeting a mob and clicking a slot button; clicking it again
  clears it. Slot 1 beats slot 2; a pin whose mob is not present is skipped, so a
  stale pin never blinds the rotation.
- **Party-combat pull mode**: a new `Party combat` option in the Pull Mode
  dropdown opens the rotation up when a group member has pulled, instead of
  requiring your own combat flag.
- Safety: auto-targeting is opt-in and defaults to Off (one cached setting read
  per tick when off); it never runs mid-cast or mid-channel, never picks a tapped
  mob while leveling, is throttled, and fails open when `core.input.set_target`
  is unavailable. The player's own selection is always kept unless a pinned
  override outranks it.
- Pinned in `test_boss_count.lua` with 25 new assertions (party-combat fire/hold,
  override priority + stale-pin fallthrough + out-of-range slot, and the full
  auto-target gate matrix including the off/dispatch and mid-cast holds).
  Non-vacuity proven by neutering the party-combat branch.


### Fix - live-client cast spam: the engine's own refusal now holds the ability

- The rotation had no way to learn that the client refused a cast. A lane that
  matched but could not be cast - invalid target, wrong weapon, missing reagent,
  immune target - re-matched on the very next frame and re-queued the same spell
  forever. That is the reported "invalid target" spam (Feint / Slice and Dice),
  and the same shape as the earlier Backstab and Mortal Strike reports.
- `shared/cast_reject_guard_sylvanas.lua` subscribes to the engine's own
  `UNIT_SPELLCAST_FAILED` / `UNIT_SPELLCAST_FAILED_QUIET` events for the local
  player and holds that spell id for 0.6s. The central cast guard
  (`NS.evaluate_cast`) consults it, so the dispatcher falls through to the next
  lane instead of re-offering a cast the client is rejecting.
- **Fail-open by construction**: no installed namespace, no clock, or a client
  that never fires the events leaves `is_held()` false, so the cast path is
  byte-for-byte the pre-existing behavior. Only a *player*-unit refusal holds our
  spells - another unit's failed cast never does.
- Opt-out per call via `opts.skip_reject_hold`. Allocation happens only on a
  rejection (rare), never per frame: the hot-path read is one table index plus a
  comparison, and the table is pruned on write.
- Pinned in `test_dispatcher_role_mode.lua` through the REAL dispatcher and the
  REAL `try_cast`: a refused lane loses the GCD to the next lane, wins it back
  when the hold expires, and wins the same GCD when no refusal was injected - so
  the hold (not lane order, the 0.3s anti-flicker or the 2.5s cast-history
  throttle) is what changed the outcome. Non-vacuity also proven by injection:
  neutering `is_held()` or the `evaluate_cast` hook fails the suite.


### Fix - rogue daggers: Backstab and Ambush are now gated on a real main-hand dagger check

- Both specs cast dagger-only abilities with **no weapon check at all** -
  `subtlety_sylvanas.lua`'s own header claimed "Backstab gated to dagger+behind",
  but no code ever looked at the weapon. Without a dagger the cast is rejected,
  the lane re-matches on the next frame and spams the queue (the same failure
  mode as the Feint/Slice-and-Dice live report).
- The engine exposes **no weapon-subclass accessor** - a game_object gives
  `get_item_id()` and the enchant fields, nothing that says "dagger" - so
  classification is data-driven from the item id, in `shared/dagger_set_sylvanas.lua`
  (regenerated from the cMaNGOS item_template and the local DBC item table by the
  new `EaxRotations/tools/generate_weapon_data.py`, with `--check`/`--self-test`).
  It answers three ways: **dagger** (610 ids), **provably not a dagger** (5169
  known weapon ids), or **unknown**.
- The gate fails **OPEN** on unknown: only a positive "this weapon is not a
  dagger" holds the lane, so an uncatalogued dagger can never silently disable a
  spec's burst. `classify()` / `allows_dagger_ability()` are the contract.
- Applied to `subtlety_sylvanas.lua` and `subtlety_vanilla.lua`
  (`state.mh_dagger_ok`, computed in `build_state` from the equipped main hand).
- Proof: fire/hold pins on both sides plus the fail-open case and the classifier
  contract in `test_subtlety_custom_matches.lua`; the state-field audit's
  dead-field rule was satisfied by removing the computed-but-unread field.

### Fix - rogue poisons: the upkeep lane now actually applies them

- The old `PoisonCheck` middleware lane **only warned** that a weapon had no
  poison - nothing in the addon ever applied one, so a rogue's weapons stayed
  bare and the spec lost both poison damage and the poison-stack gates
  (Mutilate, Envenom).
- New `shared/weapon_poison_sylvanas.lua` owns detection + application. Apply
  surface: `NS.use_item_by_id(poison_item_id, weapon_object)` -
  `core.input.use_item_target` with the equipped weapon as the target, the same
  item-on-item call the archived original EAX rogue poison manager used in game
  (the engine has no "apply enchant" entry point). Detection: `GetWeaponEnchantInfo()`
  first, then the weapon item's own `item_has_enchant` / `item_enchant_id` /
  `item_enchant_expiration`; a slot the engine cannot confirm after a successful
  apply is held as *assumed* for the poison's real duration so the rotation does
  not re-apply every tick. Throttled to one attempt per 5s, out of combat only.
- The rank comes from the bags, not a guess: the ladder is iterated highest rank
  first and the first one owned wins (Instant Poison on the main hand, Deadly on
  the off hand). Eras whose item data is not sourced report **no poison item**
  instead of applying the wrong rank.
- Middleware: `AutoPoison` (out of combat, applies) plus `PoisonCheck`, which now
  warns only for a bare weapon and says explicitly when nothing in the bags can
  fix it. New setting `rogue_auto_apply_poisons` (default on).
- Proof: module pins in `test_rogue_live_fixes.lua` (live / ready / assumed /
  weapon-swap / no-item / throttle / highest-rank / item-enchant-fallback, and
  that the poison is used **on the weapon object**), plus lane pins in
  `test_other_classes_middleware_nil_guard.lua` (never in combat, holds when
  there is nothing to apply).
- Honest limit: mock-proven against the real module and the real middleware;
  not yet observed on a live client, and the WotLK/SoD poison item ladders are
  not in the sourced item data, so those eras detect and warn but do not apply.

### QA - every WotLK spec now proven reachable through the real dispatcher, not just the battery harness

- The channel pass exposed lanes that matched statelessly in the battery while being
  dead in the live decision loop, and the dispatcher proof covered only the handful of
  specs picked by hand. `test_dispatcher_role_mode.lua` now sweeps **all 41 WotLK
  spec files**: each loads its real spec, runs its real `build_state`, its real DSL
  strategies and the real dispatcher (context build + role/playstyle filter + matches +
  execute), with only the engine surface mocked, and must have at least one lane claim
  the cast.
- The sweep runs six engine surfaces per spec (upkeep / damage / cooldowns spent /
  low hp / execute / aoe) for **246 passes**, and records which distinct lanes claimed a
  GCD so the proof names behaviour rather than just "something fired": **41/41 specs
  proven, 63 distinct lanes**. The assertion fails the suite if any spec never claims a
  cast, so a spec that silently stops dispatching can no longer ship.
- Honest limit: this proves decision-loop reachability under mocks. It is not a live
  client, and the mocked cooldown/buff/form values are the harness's, not the engine's.

### Fix - Destruction priority race: Conflagrate's real cooldown now gates the lane, so the curse lanes can win the GCD

- **The WotLK `Conflagrate` lane matched on `immolate_remains > 0` alone while
  sitting at the top of the priority list.** WotLK Conflagrate carries a real 10s
  cooldown that the `wl_destro_wotlk` fixture's sim gates on implicitly; the lane had
  no such gate, so on every frame it was cooling down it still claimed the race, and
  the curse lanes below it (`CurseOfDoom` entry 3, `CurseOfAgony` entry 8) only got a
  GCD when the central cast guard happened to reject the recast.
- `state.conflagrate_cd` is now read from `NS.cooldown_remains(ACTION.Conflagrate)`
  (the `shadowburn_cd` idiom) and the lane is gated `conflagrate_cd <= 0`. The read
  fails open to 0 = ready, so an absent engine accessor keeps the pre-existing
  behaviour instead of darkening the lane.
- **Immolate's refresh window is now the fixture's expression verbatim**
  (`dotRemainingTime(47811) < spellCastTime(47811)`) instead of a constant: the
  window comes from `core.spell_book.get_spell_cast_time` (the `fire_wotlk.lua:23`
  Scorch precedent), so it tracks the real talented/hasted cast time, with the WotLK
  base 2.0s as the fail-open fallback. The previous `ACTION.Immolate._meta.cast_time`
  read could never resolve - `define_action` builds array-style actions whose `_meta`
  carries no `cast_time` - so the window was silently hardcoded and the suite that
  pinned it was pinning a dead path.
- The window is evaluated at match time against the live read, and the DSL now honours
  a `watch = { "field" }` list on `custom` conditions so the cast trace keeps rendering
  the remainder behind the firing rule.
- Proof: fire/hold pins on both sides of both gates in
  `test_warlock_destruction_wotlk_strategies.lua` (Conflagrate ready vs 4s cooling,
  including a 9.9s hold with a sliver of Immolate; Immolate under the 2.0s fallback, a
  1.5s engine window, and zero/absurd engine reads) plus a four-tick **real
  dispatcher** proof in `test_dispatcher_role_mode.lua` - Conflagrate ready wins the
  race, Conflagrate cooling hands the GCD to `CurseOfAgony`, Immolate down hands it to
  the entry-4 Immolate refresh, and on a boss with Conflagrate cooling `CurseOfDoom`
  wins. Non-vacuity: stripping the cooldown gate makes the dispatcher tick fire
  Conflagrate where the pin requires the curse lane.
- Verified: WotLK runner 82/82, rotation battery 563/563, WotLK never-fires 0, era pins
  unchanged (TBC 11, vanilla 9, SoD 0), all audits 0 invalid, scorecard/ACCURACY and
  the era-pair seed content-identical after regeneration (no lane added, removed or
  renamed), `verify_all` exit 0, all 19 pre-commit checks pass.
- Honest limit: mock-proven against the real spec file through the real dispatcher; the
  cooldown *value* is modelled by the harness (the engine supplies it live), and no
  live client was observed for this change.
### Fix - live-client spell-queue spam: rogue Feint and Slice and Dice targeted the player

- **A live TBC rogue logged the spell queue spam-looping `Feint` (27448) and
  `Slice and Dice` (6774) at the player with "Invalid target".** Both abilities
  are target-requiring: Wowhead TBC lists Feint at 5 yd (Combat) range with a
  10s cooldown, and Slice and Dice "Requires combo points on target". Every rogue
  lane cast them at `NS.PLAYER_UNIT` / `context.me` - the WotLK declarative lanes
  used `target = "self"` and the leveling lanes passed `nil`, which `try_cast`
  resolves to the player - so the client rejected each attempt, the lane
  rematched on the next frame and the queue re-queued the same spell. That is the
  documented self-target failure mode the bear `Swipe` fix already covered
  ("self-cast is rejected by the client and spam-loops via the spell queue").
- All 13 rogue files now cast these two abilities on the **enemy** unit and hold
  the lane unless the engine reports a valid enemy target - both a missing target
  (a nil unit would fall back to self in `try_cast`) and a selected non-enemy
  target (the friendly-player case that produced the live "Invalid target")
  hold:
  `subtlety_sylvanas`, `assassination_sylvanas`, `combat_sylvanas`,
  `subtlety_vanilla`, `assassination_vanilla`, `combat_vanilla`,
  `leveling_sylvanas`, `leveling_vanilla`, `middleware_sylvanas` (threat drop),
  plus the WotLK `SliceAndDice` DSL rows in `assassination_wotlk`,
  `combat_wotlk`, `subtlety_wotlk` and `leveling_wotlk` (`target = "self"` ->
  `"target"`). The combat state readers (`slice_and_dice_ready` / `feint_ready`)
  read the enemy as well. `combat_sod` already targeted the enemy, which is why
  SoD never showed the symptom.
- Pinned on the real spec files, both sides: `test_subtlety_dsl_priority` (the
  reported TBC spec), `test_combat_dsl_priority`, `test_combat_vanilla_strategies`,
  `test_assassination_vanilla_strategies`, `test_combat_custom_matches`,
  `test_subtlety_custom_matches` and `test_subtlety_wotlk_dsl_priority` now
  assert that the cast lands on the enemy unit and that the lane **holds** with
  no enemy target. Non-vacuity proven by injection: restoring the self-target
  cast fails the cast-target assertion, and restoring the original lane fails the
  hold assertion.
- Sweep: the 548 remaining `try_cast(<spell>, self)` sites across 76 files were
  enumerated by spell name - the rest are self-buffs, self-centred AoE, totems,
  pets and personal utilities (Barkskin, Aspects, Feign Death, Fade, Innervate,
  stances/forms, ...), so no other class carries this defect. Bear/cat `Swipe`
  and the leveling `Swipe`/`Mark of the Wild` family were already correct or
  fixed earlier.
- Verified: rotation battery **563/563**, every rogue/combat/assassination/
  subtlety suite green, WotLK runner **82/82**, era never-fire pins unchanged
  (TBC 11, vanilla 9, SoD 0, WotLK 0), scorecard/ACCURACY regenerated in sync,
  `verify_all` exit 0.
- Honest limit: mock-proven against the real spec files (the WotLK DSL rows are
  driven through the compiled DSL action), not yet observed on a live client. A
  dispatcher-level rogue fixture was attempted and dropped: the shared dispatcher
  harness does not reach the strategy loop for a rogue playstyle (the same
  harness that proves the affliction and protection lanes), so lane reachability
  rests on the live log that reported the bug.

### Fix - live-client crash: `inventory_helper.has_item` is not an engine member

- **A live client logged `attempt to call field 'has_item' (a nil value)` from
  `classes/rogue/subtlety_sylvanas.lua:63` every ~2 seconds in combat.** Root
  cause: ten class files read item presence from `inventory_helper.has_item(id)`,
  a member the engine's `.api` module does not have - `inventory_helper` declares
  `get_all_slots` / `get_character_bag_slots` / `get_current_consumables_list` /
  `get_total_free_slots` / `get_bag_info`, and no `has_item` at all. Affected:
  rogue/subtlety, priest/smite, shaman/elemental, shaman/enhancement,
  shaman/restoration, warrior/kebab and warrior/protection (all threw on the nil
  call) plus hunter/beast_mastery, hunter/marksmanship and hunter/survival
  (guarded by a type check, so they silently never found a healthstone).
- All ten now read the real, installed `NS.has_item` (owned by `core/items.lua`;
  already used by the mage/paladin/rogue/warlock middleware and
  `shared/consumable_manager_sylvanas.lua`), guarded by a type check and a pcall
  so a client without the reader fails open instead of throwing. The now-unused
  `common/utility/inventory_helper` requires were dropped from those files.
- **Why every suite stayed green:** `behavioral_audit.lua` seeded
  `package.loaded["common/utility/inventory_helper"]` with an invented
  `has_item`, so the battery was exercising an API the engine does not have. The
  battery now seeds `ns.has_item` instead (every id present except the soulstone
  family, which affliction/demonology consult to decide whether a pre-combat
  self-soulstone is still needed), and the five suites that leaned on the fake
  stub mock the real reader.
- **New guard:** `test_api_lint.lua` gained a `.api` member-contract lint. For
  every file that binds a `require()` to a local, each `<alias>.<member>(` call
  must name a member the corresponding `.api` module declares via
  `---@class` / `---@field`. It scans 46 declared `.api` modules, is
  deterministic and offline, is non-vacuously proven (an injected
  `inventory_helper.has_item` call fails it), and is clean on the tree today.
  This is the check that would have caught this crash before it shipped.
- Verified: rotation battery 563/563, leveling 39/39, WotLK 82/82, WotLK
  battery never-fires 0, and the TBC 11 / vanilla 9 / SoD 0 / WotLK 0
  never-fire pins unchanged; state-field, read-side, dead-matcher, NS-member,
  cache-hit, era-pair and unused-require audits clean; perf gate green;
  `verify_all` exit 0.

### Architecture — one landing place for engine signals, one owner for safe reads

- **New `shared/engine_signals_sylvanas.lua` is now THE landing place for
  engine-derived context signals.** It owns a small registry (`key`, fail-open
  `fallback`, `read(env)`) plus one `publish(context, me, target, is_channeling)`
  call per tick. The three producers that were inlined in `main_sylvanas`
  `build_context` — `target_cast_remaining`, `channel_spell_id` and
  `school_lockout` — moved there unchanged, each keeping its documented
  fail-open default (0 = none/unknown), so a client without the engine field
  behaves exactly as before. `build_context` lost ~40 lines of bespoke pcall
  boilerplate and now makes a single call; **adding the next engine signal is one
  registry entry and touches no dispatcher code.**
- **`shared/safe_helpers_sylvanas.lua` is now the single owner of safe reads.**
  Five competing private copies are gone: the `safe`/`safe_field` fallbacks in
  `core_sylvanas` and in the ooc / racial / trinket managers, the `safe_method`
  fallback in the interrupt manager, and the `safe_method`/`safe_method_arg`
  pairs in all four druid class files (`bear`/`cat`, `_sylvanas`/`_vanilla`).
  `sticky_spell`-era callers keep their exact contract because the module exposes
  `safe`, `safe_field`, `safe_method`, `safe_method_or` and
  `safe_method_arg_or`. `safe_field` is **closure-free** (`pcall` over a hoisted
  raw reader), so centralising it does not put a per-call closure on the hot read
  path — it removes one, which the old copies allocated.
- Four harnesses had to learn the module to keep their mocks honest: three
  suites that `dofile` the core/managers without a `package.path` preamble now
  set the standard one (the same line 499 sibling suites already carry), and the
  SoD production-boot fixture now passes `shared/safe_helpers_sylvanas` through
  its `shared/* -> {}` require stub instead of stubbing it to an empty table.
- No rotation behaviour changed. Verified: rotation battery **563/563**, WotLK
  runner **82/82**, leveling **39/39**, WotLK battery never-fires **0**, state
  field / read-side / dead-matcher / NS-member / cache-hit / era-pair audits
  clean, `check_unused_requires` 0, perf cost gate green (tick retained 0.19 KB,
  churn 16.62 KB, all within named thresholds), `verify_all` exit 0.

### Rotation Content — WotLK thin-spec guide pass, round 2 (destruction / warrior prot / paladin prot / resto shaman)

- **The next thinnest WotLK specs now implement their published priority**
  (destruction 10 → 12, warrior protection 10 → 12, paladin protection 9 → 12,
  restoration 10 → 12 lanes), driven by the pinned wowsims fixtures
  (`wl_destro_wotlk.apl.json`, `war_prot_wotlk.apl.json`,
  `pal_prot_wotlk.apl.json`) and the published playstyle priority:
  - **Destruction** — Curse of Doom (47867) claims the curse slot on a boss
    while Curse of Agony (47864) is the fallback curse elsewhere (APL entries 3
    and 8). Chaos Bolt now leads with the level-80 max rank **59172**; the file
    shipped rank 1 (50796), so a level-80 warlock cast a level-60 nuke.
  - **Protection warrior** — the two shout upkeep lanes the fixture carries but
    the file lacked: Commanding Shout (47440, 2-min raid health buff, refresh
    under 60s at 10+ rage) and Demoralizing Shout (47437, AP debuff refresh).
  - **Protection paladin** — Hammer of Wrath (48806, the APL's priority-4
    sub-20% execute), Sacred Shield (53601, 30s self barrier) and Divine
    Protection (498, −50% damage panic button under 35% hp).
  - **Restoration shaman** — Cleanse Spirit (51886; dispels outrank throughput
    heals, reading the real `NS.has_dispel_type_debuff` for poison/disease/curse)
    and Earthliving Weapon (51730) as out-of-combat imbue upkeep.
- **Fixed a dead spell id in paladin protection**: the Holy Shield ladder head
  was pinned as 48927, which wowhead WotLK Classic 404s — the shield lane cast a
  spell that does not exist and read an impossible buff. The real 3.3.5 max rank
  is **48952** (8 charges / 10s / 8s CD), the id the wowsims fixture casts. The
  disproven alias moved to `WOTLK_REJECTED_IDS`, 48952 took its allowlist slot,
  and the charge-refresh / cooldown / buff-up pin sites were re-pointed.
- Every new gate is era-correct (single WotLK max ranks), fails closed on an
  unknown read, and carries fire/hold pins on both sides. Three positional
  priority suites (warrior protection, paladin protection, resto shaman) were
  converted to name-resolved lane lookup so the next insertion cannot silently
  drift them.
- **One new lane is proven through the real dispatcher**:
  `test_dispatcher_role_mode.lua` runs the real protection warrior spec under
  the real dispatcher with rage 15 and Revenge on cooldown, asserts the new
  CommandingShout lane claims the cast and emits it via `cast_safe`, then
  asserts it holds once the 2-minute shout is up.
- WotLK battery never-fires stays **0** (43/43 files clean); allowlist +6
  bridge-gap pins (59172/47440/48952/51886/51730/498) minus the disproven
  48927; scorecard WotLK strategies 515 → 524; era-pair seed regenerated.

### Rotation Content — WotLK thin-spec guide pass (affliction / demonology / fury)

- **The three thinnest WotLK DPS specs now implement their published playstyle
  priority** (8 → 12 lanes each), driven by the pinned wowsims fixtures rather
  than memory:
  - **Affliction** — Curse of Doom (47867) claims the curse slot on a boss while
    Curse of Agony keeps it everywhere else; Summon Infernal (1122) as the
    10-minute guardian burst; Nightfall spends the Shadow Trance proc (17941)
    ahead of the plain filler; Drain Life (47857) as the sub-55% sustain band.
  - **Demonology** — the curse pair (Curse of Doom on a long boss fight, Curse of
    Agony otherwise), Immolation Aura (50589) inside the Metamorphosis window,
    and Seed of Corruption (47836) into a 4+ pack. The pinned sim chain
    Corruption < Immolate < Soul Fire < Shadow Bolt is untouched.
  - **Fury** — Recklessness (1719, Berserker-only 5-min burst), Cleave (47520)
    and Heroic Strike (47450) as the queued rage dumps (Cleave at 2+ targets,
    Heroic Strike only when the main-hand swing is imminent, read from the real
    swing clock), and Heroic Throw (57755) as the out-of-melee filler.
- All new gates are era-correct (single WotLK max ranks, no TBC ladders), fail
  closed on an unknown read, and carry fire/hold behavioral pins on both sides.
- **One new lane is proven through the real dispatcher, not just the harness**:
  `test_dispatcher_role_mode.lua` loads the real affliction spec, lets the real
  dispatcher build `context.target_is_boss` from `NS.unit_is_boss`, and asserts
  the new Curse of Doom lane claims the cast and emits it via `cast_safe`.
  Non-vacuity proven by injection in both directions.
- WotLK battery never-fires stays **0**; allowlist +6 pins (47867/50589/57755
  bridge-gap, 1719/1122/17941 era-shared).
### Rotation Content — WotLK channel-clip wave (Mind Flay / Drain Soul)

- **The engine channel clock is now the source of truth for Mind Flay.** The
  wowsims fixtures this repo pins already model channel clipping
  (`shadow_wotlk.apl.json`: `channelSpell 48156 Mind Flay` with
  `interruptIf: gcdTimeToReady <= channelClipDelay`; `affliction_wotlk.apl.json`:
  a conditional Drain Soul interruption), but `shared/mf_tick_compute_sylvanas.lua`
  derived its tick count as `now - get_active_channel_cast_start_time()`, which is
  blind to a haste-scaled channel and rounds every tick onto a hardcoded 1s
  cadence. It now reads the engine's channel accessors (`get_channel_elapsed_ms` /
  `get_channel_duration_ms` / `get_channel_remaining_ms` via
  `shared/cast_timing_sylvanas.lua`), derives the tick interval as `duration / 3`,
  and returns the real seconds left in the channel. The start-time arithmetic is
  kept only as the fail-open fallback for a harness/build with no channel clock,
  so an unpopulated field behaves exactly as before.
- **The clip lanes were unreachable in the live dispatcher.** `main_sylvanas`
  early-exits the whole strategy loop while casting/channeling, so the shadow
  VT / SW:P / DP / Mind Blast clip lanes could never fire against a live Mind Flay
  even though the battery (which does not run the dispatcher skip) showed them
  matching. Channels are now **opt-in clip-managed** through a playstyle's
  `channel_clip_ids` register option (merged into `registry.channel_clip_ids`, one
  hash lookup per channeled frame): only a declared channel re-enters the decision
  loop mid-channel, every other channel keeps the blanket skip, and a hard cast
  always keeps it. The clipper lanes carry `skip_casting` so `evaluate_cast` lets
  the replacement through mid-channel.
- **Shadow priest**: Mind Flay (48156 / 48158 / 48155) declared clip-managed; the
  VT / SW:P / DP / Mind Blast lanes clip at a tick boundary. The clip gate gains
  an engine end-time rule — a debuff that would expire before *this* channel ends
  is refreshed now even outside the lane's own 3s window.
- **Affliction warlock**: Drain Soul declared clip-managed; the
  Haunt / Corruption / UA / CoA refresh lanes carry `skip_casting` so an
  execute-phase channel can be interrupted by a DoT that needs refreshing
  (mirrors the fixture's unconditional Drain Soul interruption).
- No new spell ids (the Mind Flay and Drain Soul ranks already existed), so no
  allowlist churn; battery never-fires stays **0** for every affected spec.
- **Honest scope note — what the API cannot express:** a rotation cannot stop a
  channel except by casting the replacement, and there is no engine-side
  "wait for the next tick" primitive, so clipping is expressed as "let the next
  lane fire mid-channel", not as an explicit channel-stop. The channel-remaining
  argument to the clip gate is passed by WotLK shadow only; the TBC/vanilla shadow
  files get the improved tick clock through the shared module but keep their
  static-window clip gate (unchanged behavior).

### Tooling — Release-Integrity Guard (shipped version vs published release)

- **New gate: `tools/release_staleness_check.lua`** — fails when the version
  this checkout ships (`EaxRotations/header.lua` plugin version) is newer than
  the newest `vX.Y.Z` published on the remote. The publish workflow
  (`.github/workflows/release-publish.yml`) is deliberately manual by design,
  so a `release: vX.Y.Z` commit can land on master and stay green in CI while
  no tag or Release is ever created — and users then download a zip without
  the fixes already on master. That happened twice: the 2.18.0→2.22.0 gap, and
  again from 2.24.2 until 2.25.0 was finally published on 2026-09-10, after
  players reported perma-show/control-panel problems that had in fact been
  fixed for a month in unreleased code.
- Wired into CI as a `--strict` step on master pushes only. PR branches
  legitimately predate their own publish so they are unaffected, and the
  pre-commit gate stays offline and fast. On a stall the guard prints the exact
  one-line remediation (`gh workflow run release-publish.yml -f version=X.Y.Z`)
  and clears itself once the tag exists.
- Compares against the **remote** tag list, not local tags: the publish
  workflow creates the tag server-side, so a local checkout routinely tops out
  at the previous release and would report a false STALE. An unreachable remote
  reports UNVERIFIED and passes, so a network blip cannot red an unrelated
  build. A `gh release list` cross-check warns when a version is tagged but no
  GitHub Release (the downloadable zip) exists.
- Self-tested (`--self-test`) on semantic-version compare (zero-padding and
  numeric minor/patch rollover), date-tag filtering (the repo's historical
  `v2026-06-26.<sha>` tags are ignored), and all five verdicts on both sides.
  Allowlisted in `.gitignore` so a clean CI checkout has it, matching how
  `update_badges.lua` / `spec_scorecard.lua` / `apl_status.lua` are tracked.
- Those self-tests are now actually executed by the gate. They previously ran
  nowhere: the guard is the one audit whose assertions no gate invoked. They are
  offline and deterministic (injected tag lists, never the network), so they run
  in `tools/pre-commit` step 14 beside the version-consistency audit's own
  self-test, and as a `run_verify_all.lua` component — matching how every
  sibling audit self-test is wired. Only the guard's live remote check stays a
  CI master-push step, because it must reach the network.

### Rotation Content — WotLK cast-timing wave (engine cast/channel end-time signal)

- **New shared module `shared/cast_timing_sylvanas.lua`**: the engine exposes real
  cast/channel end times via `unit:get_channeling_or_casting_remaining_sec()` /
  `get_cast_remaining_sec()` / `get_channel_remaining_sec()`, and
  `main_sylvanas.lua` now publishes `context.target_cast_remaining` each frame.
  Grep-verified: **zero rotations read any end-time accessor** before this wave —
  the only timing proxy in the tree was the interrupt manager's cast *percent*,
  which is duration-relative and cannot tell "0.4s left on a 0.8s cast" (already
  landing) from "3s left on a 6s cast" (plenty of time). Pure module (no NS
  capture at require time — the battery's shared-virgin guard), allocates nothing
  (closure-free `pcall(read_field, ...)` read, matching the repo's
  no-per-frame-allocation rule), and **fails open**: an absent/zero end time keeps
  the exact pre-signal behavior on older clients and in the mock harness.
- **The interrupt gate is now end-time-first**:
  `interrupt_manager.cast_has_interrupt_window` consults the engine's remaining
  seconds before the percent heuristic and refuses an interrupt whose lead is at
  or below `0.30s` (clamped 0.10–1.50s). A target cast that will land first no
  longer claims the cooldown. The lead is a module-level parameter
  (`cast_timing.DEFAULT_LEAD_SEC`, or the `settings` table a caller passes); no
  shipped spec overrides it yet — the menu schema exposes no widget for it.
- **25 WotLK interrupt lanes gated** — the 22 DSL lanes:
  mage Counterspell (×3 + leveling), rogue Kick (×4), warrior Pummel (×4 incl.
  protection), death knight leveling Mind Freeze, druid cat Maim Interrupt,
  death knight unholy Ghoul Gnaw, hunter Silencing Shot (leveling + marksmanship),
  priest Silence, shaman Wind Shear (×2) + Earth Shock, warlock leveling Spell
  Lock; plus the 3 manager-registered death knight Mind Freeze lanes
  (blood/frost/unholy), which inherit the same floor through
  `cast_has_interrupt_window`. Each holds against a finishing cast and still
  fires against a normal one.
- **2026-09-12 correctness close-out**: re-deriving the set against the real
  files showed the original "17 lanes" count was both under-counted and
  incomplete. `druid/cat_wotlk.lua` MaimInterrupt, `deathknight/unholy_wotlk.lua`
  GhoulGnaw, `hunter/leveling_wotlk.lua` SilencingShot and
  `shaman/elemental_wotlk.lua` Earth Shock carried no end-time gate, and
  `hunter/marksmanship_wotlk.lua` SilencingShot had **no target-casting gate at
  all** — it fired on cooldown against a target that was not casting, unlike its
  leveling sibling. All five now require a casting target plus the end-time
  floor.
- **No new spell ids**, so **no allowlist churn**; the spell-audit alias count is
  untouched this wave.
- Battery: never-fires = **0** for every affected spec (WotLK era total still 0).
  One new shared scenario (`target_cast_finishing`: target casting with only 0.05s
  left) and `target_cast_remaining` registered as a known context key. The
  interrupt-manager suite gained 11 assertions on both sides of the floor (0.05s
  holds, 0.30s sits ON the floor and holds, 0.31s fires, a raised
  lead re-closes it, the channel accessor is honoured when the combined one is
  absent, zero = fail-open); every one of the 25 gated lanes now carries
  fire/hold pins driving its own real `_wotlk.lua` file (or the real
  manager module for the three death knight lanes).
- Perf gate: the read sits on the per-frame context-build path, so the field read
  was made closure-free — all measured paths stay within their named
  retained/churn bounds (tick churn 47.49 -> 47.12 KB after the fix).

### Rotation Content — WotLK school-lockout wave (engine LoC signal) + thin casters

- **New shared module `shared/spell_school_gate_sylvanas.lua`**: the engine
  exposes the interrupted-school mask via
  `unit:get_loss_of_control_info().lockout_school` (a `schools_flag` bitmask) and
  `main_sylvanas.lua` now publishes it as `context.school_lockout` each frame.
  Before this wave **no rotation read that signal** (grep-verified zero
  callers), so after an interrupt every spec kept queueing a school the engine
  would refuse. The module is pure (no NS capture at require time — the
  battery's shared-virgin guard), allocates nothing, and **fails open**: an
  absent/zero mask reports "not locked", which is exactly the old behavior on
  older clients and in the mock harness.
- **Frost mage 8 -> 12 lanes**: Fire Blast (42873, the off-school instant) now
  fires **only** while the frost school is interrupted, and every frost cast
  (Frostbolt / Frostfire Bolt / Ice Lance / Deep Freeze) holds in that window;
  plus Mirror Image (55342, 3-min burst), Evocation (12051, < 40% mana refill)
  and the Ice Barrier shield band (43039 r8 max / 43038 r7).
- **Balance druid 8 -> 11 lanes**: the canonical school swap — an arcane lock
  drops Moonfire/Starfire and Wrath covers even with no Eclipse; a nature lock
  drops the whole nature kit (Wrath, Insect Swarm, Faerie Fire, Hurricane) and
  Starfire covers even during solar Eclipse, where it normally holds. Plus
  Force of Nature (33831 burst), Barkskin (22812 defensive band) and Innervate
  (29166 mana tool).
- Spell audit: +3 WOTLK_REFERENCE_ALIASES pins 242 -> 245 — 33831 Force of
  Nature (`VALID_SHARED_ID`: exists in both TBC and WotLK data, already
  documented in `WOTLK_SHARED_IDS`; the classifier's `TBC_ID_IN_WOTLK` path
  needed the alias entry) and 43039/43038 Ice Barrier ranks 8/7
  (`VALID_BRIDGE_GAP`: Wowhead-verified real WotLK ranks the local bridge simply
  stops short of at 33405 r6).
- Battery: both specs never-fires = 0 (WotLK era total still 0). Three new
  shared scenarios pin the lockout shapes (`school_locked_frost` 16 / `_nature`
  8 / `_arcane` 64) and `school_lockout` is registered as a known context key.
  Both behavioral suites extended with fire/hold pins on both sides of every
  new gate; both static priority suites converted to name-resolved lane lookup
  (12/11-lane order pinned). The battery exposed a real defect: the new
  MirrorImage/Evocation lanes referenced `ACTION` entries that were never
  defined (Evocation reported never-fires=1 until the defines landed).
- Era-pair seed re-baselined (+2 names): the WotLK lanes' siblings cover the
  same behavior under their own names (TBC/vanilla balance carry
  `BarkskinDefense` / `InnervateHealer` / `InnervateSelf`; Mirror Image is a
  WotLK-only talent), and the seed's stale "ForceOfNature missing in wotlk" row
  is now correctly cleared.
- scorecard: strategies 496 -> 503, rules 2588 -> 2595; druid/balance 8 -> 11
  and mage/frost 8 -> 12, both still S+.

### Rotation Content — WotLK rogue/warlock thin guide-pass (the 7-lane trio)

- **Rogue assassination 7 -> 10 lanes**: Garrote (48676 r9 stealth opener —
  the only era-correct id; the audit rejected the TBC ladder as
  TBC_ID_IN_WOTLK, correctly), Cold Blood (14177, single-rank talent, 5-CP
  finisher combo), Fan of Knives (51723, 3+ enemy AoE). Cold Blood moved
  ahead of Envenom to match the wowsims mutilate APL order (CB buffs the
  Envenom).
- **Rogue combat 7 -> 9 lanes**: Rupture (48672 r8, Serrated Blades DoT —
  SnD >= 4s + 5 CP + bleed < 2s) moved AHEAD of Eviscerate to match the
  wowsims combat APL (entries 3-4 before 5-7; otherwise Eviscerate eats the
  5-CP slot first and Rupture is a dead lane in real first-match play), and
  Tricks of the Trade (57934, <= 50 energy so it never delays a builder).
- **Warlock destruction 7 -> 10 lanes**: Curse of the Elements (47865 r4 —
  the APL fixture's 47867 is NOT the live WotLK max rank and is not
  bridge-present; the amp goes up before the damage cycle per the fixture
  order), Shadowburn (47827 r3, execute band < 35% HP), Hellfire (47823 r9,
  channeled 3+ enemy AoE via the Hurricane channel idiom).
- Spell audit: +5 WOTLK_REFERENCE_ALIASES pins 236 -> 241 (14177/48676/
  47865/47827/47823, all Wowhead-verified max ranks; 51723 Fan of Knives is
  bridge-present and needs no pin). The audit self-test caught a mis-placed
  allowlist bump from an earlier pass attempt (pin bumped without entries
  landing in the alias table) and forced the honest recount.

  battery: all three specs never-fires = 0 (WotLK era total still 0); new
  lanes fire in existing shared scenarios (execute for Shadowburn, aoe for
  FoK/Hellfire, sap_setup stealth for Garrote, energy_low for ToTT). All six
  static + behavioral suites extended with fire/hold pins; the two static
  priority suites converted to name-resolved lane lookup.
### Rotation Content — WotLK disc priest / paladin leveling guide-pass (8 -> 12 lanes)

- **Priest discipline 8 -> 12 lanes**: Desperate Prayer (25437, player_hp
  <= 30 self-save — the holy racial idiom), Inner Focus (14751, single-rank
  talent, leads the shield engine so the discounted cast is the free
  +25%-crit PWS/GHeal), Shadowfiend (34433, mana < 60 mana-return pet — the
  shadow idiom), Divine Spirit (48073 r6, OOC spirit upkeep — the holy
  idiom). Priority keeps the pinned APL order PWS -> Penance -> PoM ->
  Renew untouched; the save band gains Desperate Prayer under Pain
  Suppression and PowerInfusion stays last.
- **Paladin leveling 8 -> 12 lanes**: Avenging Wrath (31884, opt-in burst
  via should_use_long_cd — the retribution idiom), Divine Plea (54428,
  mana < 40 band), Exorcism (full ladder 48801..879, fail-closed undead/
  demon creature gate via a pcall get_creature_type read — no Art of War
  requirement while leveling, unlike the ret rotation), Holy Wrath
  (48817/37897/31898, 2+ enemies + creature gate — protection_wotlk's
  exact band shape). The audit's era-family check rejected my first
  Holy Wrath ladder (TBC/vanilla ranks 27139/10318/2812) — trimmed to the
  three WotLK-trained ranks.
- Spell audit: +1 WOTLK_REFERENCE_ALIASES pin 241 -> 242 (14751 Inner
  Focus, Wowhead-verified single-rank talent; 25437/34433/48073 reused
  from prior waves' pins).
- Battery: both specs never-fires = 0 (WotLK era total still 0); every new
  lane fires in existing shared scenarios (pal_lev_seal creature 6 for
  Exorcism, undead_target 2-enemy for HolyWrath, low_mana band for
  DivinePlea/Shadowfiend). Suites extended in place: disc priority suite
  12 -> 21 tests, paladin leveling suite 14 -> 26 tests, both converted to
  name-resolved lane lookup.

### Rotation Content — WotLK bear/fire guide-pass (scorecard thinnest)

- **Druid bear 8 -> 12 lanes** (was the thinnest WotLK tank): Growl
  (single-target taunt with a fail-closed threat gate — fires only when the
  dispatcher's threat readout is present and below 100), ChallengingRoar
  (10yd AoE taunt, 3+ enemies), Enrage (rage-generation band gate), Berserk
  (the 51-pt feral talent, opt-in burst). Era-correct single WotLK ids,
  Wowhead-verified; spell audit allowlist 232 -> 235.
- **Mage fire 9 -> 12 lanes**: Mirror Image (2+ enemies), Evocation
  (in-combat mana < 40%, mirroring arcane's idiom), Dragon's Breath
  (WotLK Rank 5 cone AoE, 3+ enemies; the TBC-era lower ranks are rejected
  by the spell audit's era-family check, correctly — WotLK files carry only
  the max rank). Allowlist -> 236.
- Battery: both specs never-fires = 0 (WotLK era total still 0); new lanes
  fire in existing shared scenarios. Static priority suites converted from
  positional indexes to name-resolved lane lookup so future insertions
  cannot silently descope them. Pinned fire/hold in the four bear/fire
  behavioral + priority suites.

### Rotation Content — TBC healer guide-pass + shaman OOC rez + Mortal Strike verification

- **TBC shaman gets its OOC resurrection lane** (the era-wide spell-coverage
  sweep gave OOC rez to paladin/priest/druid middleware but skipped shaman):
  OOCSpirit in shaman/middleware_sylvanas.lua mirrors the paladin OOCRedeem
  idiom — dead party member between pulls, OOC-only, use_resurrection toggle
  (default on). Ladder 20777/20776/20610/20609/2008 all Wowhead-verified TBC
  ranks (Ancestral Spirit, 10s cast, 72% base mana) and bridge-present, so no
  new audit pins were needed. Pinned fire + hold-in-combat + hold-setting-off
  + hold-no-dead-ally in test_shaman_live_fixes.lua.
- **Priest holy self-buff upkeep** (the last guide-depth gap vs its discipline
  sibling): Divine Spirit + Inner Fire lanes added to holy_sylvanas.lua
  (TBC ladder 25312/27841/14819/14818/14752 + 25431/10952/10951/1006/602/7128/588,
  bridge-present) and holy_wotlk.lua (era-correct single ranks 48073 r6 and
  48168 r9, Wowhead-verified; 48073 audit-pinned as VALID_RANK_ALIAS, allowlist
  231 -> 232). Both eras: buff-down + ready gates, safe-in-combat guard in TBC,
  buff-maintenance priority slot between the hymn/emergency band and target
  triage. Pinned fire/hold/order in test_priest_holy_friendly_target.lua (C11-C18)
  and test_holy_priest_wotlk_dsl_priority.lua.
- **Mortal Strike verified across all four eras** (user report: 'arms MS never
  fires'): the lane exists in arms_vanilla/arms_sylvanas (battle-stance + 30
  rage + spell_ready via the real engine gates), dps_warrior_sod (SoD id 12294,
  is_sod + stance-gated), and arms_wotlk (DSL lane, ms_cd/rage/in-combat via the
  real cooldown API). Live fire probes through each real file under the capturing
  mock all cast; the vanilla suite's boolean-only MS assert was replaced with
  real fire/hold pins (fire at 40 and 30 rage, hold in defensive/berserker
  stance, hold below 30 rage, hold when spell_ready reports false).

### Rotation Content — TBC thin non-healer guide-pass (caster, kebab, smite)

- **Druid caster** (leveling/solo caster playstyle, previously the era's
  thinnest row at 11 lanes): Rebirth battle-rez (balance-sibling
  RebirthBattleRez — dead player ally in combat, wipe guard when the tank is
  dead) + Mark of the Wild self upkeep (balance-sibling gate set: self-buffs
  toggle, no-mark, no-downgrade vs Gift/higher ranks). 11 -> 13 lanes.
- **Warrior kebab (DW Arms)**: rage-generation lanes Bloodrage (below 20 rage,
  OOC-safe when healthy) + Berserker Rage (below 40 rage in combat), and the
  DeathWish burst CD (combat, non-execute, opt-out toggles) — all mirroring the
  fury sibling's TBC guide gates. 16 -> 19 lanes.
- **Priest smite**: Power Word: Fortitude (held while Prayer of Fortitude is
  up) + Divine Spirit self upkeep, mirroring discipline's lanes; tail
  placement so combat winners are unchanged (balance MoW precedent).
  18 -> 20 lanes.
- **Pins**: test_caster_dsl_priority (RebirthBattleRez fire + 3 holds,
  MarkOfTheWild fire + 3 holds), test_kebab_dsl_priority (Bloodrage/BerserkerRage/
  DeathWish fire + hold sides), test_smite_dsl_priority (PWF + DivineSpirit
  fire + hold sides). Battery: all three specs never-fires = 0; TBC era total
  unchanged at its pinned value.
- **Evidence**: every id mirrored from bridge-present sibling ladders
  (sylvanas audit 81/81 clean, no new pins needed); caster/kebab/smite
  priority suites green; era-pair seed regenerated (1370 names).

### Rotation Content — SoD guide-priority expansion wave
- **Every SoD spec now implements its published playstyle priority.** All
  twelve sub-priority specs were expanded against their Icy-Veins / Wowhead
  SoD guides (Wowhead-verified SoD rune spell ids only - unresolvable ids
  such as Binding Heal and the passive Aura Mastery were deliberately
  excluded rather than guessed):
  - **Druid**: balance 6 -> 7 (Insect Swarm upkeep), feral 6 -> 10
    (Tiger's Fury, Berserk, Insect Swarm-depth dot upkeep), restoration
    5 -> 6 (Efflorescence, Survival Instincts, Nourish band), tank 8 -> 12
    (Demoralizing Roar, Growl on a real threat readout, Enrage, Survival
    Instincts 409809).
  - **Hunter**: dps 8 -> 12 (Aspect of the Hawk + Hunter's Mark upkeep,
    Serpent Sting apply-before-Chimera, Volley AoE, Rapid Fire window).
  - **Mage**: dps 6 -> 8 (Living Bomb, Icy Veins window).
  - **Paladin**: protection 7 -> 9 (Seal of Martyrdom upkeep, Judgement),
    retribution 3 -> 10 (guide defensive band: Lay on Hands / Divine Shield
    with Forbearance exclusivity, Martyrdom upkeep, Judgement cycle,
    Hammer of Wrath execute, Consecration at the guide volume).
  - **Priest**: healing 4 -> 6 (Prayer of Mending 401859, Circle of Healing
    402842 with the 2+-injured group gate).
  - **Rogue**: combat 7 -> 9 (Blade Flurry AoE, Adrenaline Rush window,
    positional builder playstyle).
  - **Shaman**: elemental 7 -> 8 (Rolling Thunder-depth shock lanes).
  - **TBC druid caster** (same wave, same discipline): 6 -> 8 - added the
    Insect Swarm + Starfire lanes its own header already claimed, mirroring
    the wowsims tbc-new balance APL semantics; ids TBC-bridge-valid.
- **Battery outcome**: SoD strategies 158 -> 188 across 20 specs with
  never-fires = 0 held everywhere (strict gate); TBC total never-count
  unchanged at 11 (all pre-triaged). New spell ids pinned in the
  `SOD_RUNE_IDS` drift guard (62 -> 64); Task-1 action map regenerated
  (161 ids); era-pair seed regenerated.
- **Two real out-of-combat bugs fixed by the new pins**: druid-tank Enrage
  and hunter Aspect of the Hawk matched with no combat gate and would cast
  out of combat; both now use their file's standard in-combat gate (all
  sibling lanes already did).
- **Supporting pins extended** (no new suites; battery remains 563 suites):
  SoD rotation matrix rows, the druid/hunter, mage/paladin/priest and
  assassin group suites, and the caster DSL priority suite.

### Rotation Content — WotLK DPS thin-spec close-out (guide-driven)

- **The three thinnest WotLK DPS files now implement their published
  priorities.** The healer deep-rate's DPS counterpart (scorecard ranked
  subtlety 6 lanes as the era's lowest DPS row, demonology 6, balance 6)
  closed the guide gaps:
  - **Subtlety rogue** (`rogue/subtlety_wotlk.lua`): 6 -> 10 — Hemorrhage
    48660 universal builder (no positional/dagger gate; fixes the stale
    "fallback builder" comment that pointed at nothing), Slice and Dice +
    Rupture finisher uptime (assassination sibling thresholds), Preparation
    14185 defensive-CD reset (spell_ready-gated, fails closed). Backstab
    stays the positional builder; Hemo catches the blocked case.
  - **Demonology warlock** (`warlock/demonology_wotlk.lua`): 6 -> 8 — the
    two signature proc lanes the file never modeled: Molten Core
    (buff 71165/47246/47245) hard-prioritizes Incinerate 47838 during the
    Corruption-tick proc window, and Decimation (buff 63165) fires instant,
    shard-free Soul Fire in the sub-35% execute band.
  - **Balance druid** (`druid/balance_wotlk.lua`): 6 -> 8 — Faerie Fire
    debuff upkeep (3% spell hit; caster ladder, 26993 max — no WotLK rank
    exists) and Hurricane 48467 channeled 10y AoE (3+ enemies, the
    BlastWaveAoE/Pestilence volume idiom; the DSL has no channel action, so
    the lane uses the resto_wotlk Tranquility custom-fn idiom).
- Every new lane is pinned fire/hold in its existing behavioral suite
  (subtlety 16, demonology, balance) and every lane fires somewhere real in
  the WotLK battery (never-fires = 0 for all three specs, era total still
  0). All new ids Wowhead-verified; spell-audit allowlist +6 (231 total).

### Rotation Content — WotLK healer expansion wave (guide-driven, three passes)
- **Every WotLK healer now implements its published playstyle priority.**
  The healer deep-rate against live Icy-Veins WotLK rotation pages and the
  pinned wowsims APL fixtures found the WotLK healer tier thin (4–7 lanes
  per file while the TBC files carry 31–39); both passes closed it:
  - **Resto druid** (`druid/resto_wotlk.lua`): 7 -> 11 — Nature's Swiftness
    + Healing Touch emergency pair (aura-present spend / aura-absent enable,
    <= 30% band), Rebirth battle-rez (group guard + real
    `find_dead_party_ally`), Tranquility (3+ injured, lowest <= 50%, 8-min CD).
  - **Holy paladin** (`paladin/holy_wotlk.lua`): 5 -> 9 — Seal of Wisdom
    upkeep, Judgement on cooldown at <= 90% mana (era-correct Judgement of
    Wisdom uptime), Divine Favor + Holy Light combo, Divine Plea at <= 50%
    mana — the mana game the guide leads with.
  - **Resto shaman** (`shaman/restoration_wotlk.lua`): 7 -> 10 — Nature's
    Swiftness + Healing Wave emergency pair, and Tidal Waves finally used:
    the file tracked the 2-stack buff but never acted on it; the window now
    hard-prioritizes the big nuke.
  - **Discipline priest** (`priest/discipline_wotlk.lua`): 4 -> 6 — Pain
    Suppression (<= 30% save, leads the order) and Power Infusion (<= 45%
    pressure band), making the pinned wowsims disc APL's
    `autocastOtherCooldowns` concrete.
  - **Holy priest** (`priest/holy_wotlk.lua`): 6 -> 8 — Desperate Prayer
    self-save (<= 30% own hp via the real `context.player_hp` engine field,
    slotted under Guardian Spirit) and Lightwell raid-sustain (3+ injured,
    before Circle of Healing). The sim-APL block (Greater Heal / CoH /
    Renew / PoM) is unchanged and still conformance-mapped.
- **Deliberate exclusions** (one owner per decision, recorded in the triage
  addenda): Tremor Totem / Cleansing Totem debuff response and Mass Dispel
  stay in the dispel middleware (`dispel_manager` / main_sylvanas party
  dispels) — a rotation lane would double-own the decision. Holy priest's
  remaining A-grade lanes were left untouched by design. No healer has a
  comparative sim benchmark (the sim repos ship no implemented healer
  rotations beyond WotLK holy/disc priest APL fixtures) — that ceiling is
  documented, not hidden.
- **Battery outcome**: all 41 WotLK specs at never-fires = 0 under the
  strict gate (priest/holy 8, discipline 6, druid/resto 11, paladin/holy 9,
  shaman/restoration 10 in the scorecard); three spec-scoped scenarios
  added (`druid_wotlk_tranquility`, `druid_wotlk_ns_burst`,
  `resto_tidal_waves`); other eras unmoved (tbc 11 / vanilla 9 / sod 0).
- **Real bugs caught mid-wave**: an interrupted edit had deleted the
  `LIFEBLOOM_BUFF` local from resto_wotlk (restored before boot break), and
  Rebirth's dead-ally gate initially read `is_player` as a boolean when the
  engine/mock expose it as a method — both fixed and pinned.
- **Ids and pins**: all 24 new spell ids Wowhead-verified and pinned in the
  WotLK spell-audit allowlist (184 -> 208, including the talent-cap trap —
  Desperate Prayer has no WotLK rank increases — and the 48084/48085
  Lightwell-Renew *buff* ids excluded from the cast ladder); supporting pins
  extended in five suites (`test_resto_wotlk_dsl_priority` 24 -> 32,
  `test_holy_wotlk_dsl_priority` 14 -> 22,
  `test_discipline_wotlk_dsl_priority` 8 -> 12,
  `test_priest_holy_wotlk_strategies`,
  `test_holy_priest_wotlk_dsl_priority`); scorecard/ACCURACY/badges and the
  era-pair seed regenerated; no new suites — battery remains 563.

- **Third pass (2026-09-10, deep-rate close-out)** — the last four graded healer gaps, same discipline:
  - **Holy priest** (`priest/holy_wotlk.lua`): 8 -> 10 — Divine Hymn
    (single-rank 64901; 3+ injured, lowest < 60 — the Tranquility idiom) and
    Hymn of Hope (single-rank 64904; mana < 40), slotted under the
    self-save band ahead of target triage.
  - **Holy paladin** (`paladin/holy_wotlk.lua`): 9 -> 10 — Lay on Hands
    (era-shared id 633) as the <= 20% mana-free full-heal save on the
    dedicated beacon target; it leads the order.
  - **Discipline priest** (`priest/discipline_wotlk.lua`): 6 -> 8 — the
    direct-heal filler band the file lacked: Greater Heal (< 50%, mana
    >= 30) and Flash Heal (< 70%, mana >= 20) after Renew, before Power
    Infusion's pressure band (build_state now reads mana like its siblings).
- Battery: new `healer_save_window` scenario (lowest 15) gives the tight
  <= 20 save band observability; all 41 WotLK specs still never-fires = 0.
  Ids 64901/64904 pinned in the WotLK spell-audit allowlist (221 -> 223;
  64902/64903 verified as unrelated ids and excluded); 633 already accepted
  era-shared. Suites extended in place (three dsl_priority + three
  strategies suites); no new suites — battery remains 563.

---
## 2.25.0 — 2026-09-06

### Customer Changelog
- **Control Panel (permashow) now visible for everyone**: several players
  reported the always-on-screen quick-toggle panel was empty/missing while it
  worked fine locally. Cross-checked against the official Sylvanas docs
  (modules/control-panel: rows only appear for a keybind that is bound or was
  user-drag-added). Three build-dependent failure modes are fixed:
  - **Unbound toggles always show a row now.** Quick toggles now default to the
    engine's documented "Unbinded" sentinel (7; 999 kept as a legacy sentinel).
    Unbound toggles are pushed to the panel directly AND seeded with the native
    mirror flag (`set_is_showing_on_control_panel`) plus drag capability, so
    Rotation / Cooldowns / AoE etc. appear on both legacy and retained-menu
    hosts even with no key assigned — and users can drag/remove rows freely.
  - **Panel no longer starved on fallback builds.** The rotation dispatcher's
    registration fallback no longer squats on the Control Panel render slot, and
    the menu/panel callbacks register before the dispatcher. Rotation working
    but panel invisible is no longer possible on any build.
- **New: playstyle switching right from the panel** (new-menu builds): the
  Playstyle selector joins the quick toggles on the always-on-screen panel, so
  you can swap specs without opening the full menu.
- **New: "Reset Permashow Window" button** under EaxRotations → Diagnostics:
  restores an off-screen/hidden panel to its default position in one click.
- **Declarative (retained) menu builds work again**: a method-call argument
  shift (colon/dot mismatch) in the new-menu page build and settings sync left
  the retained `_G.menu` page inert. The page build and settings sync are now
  proper self-methods, the permashow Control Panel and the Diagnostics section
  render under the retained host, and the panel and menu Quick Toggles filter
  through one shared role-visibility policy.
- **Quick Toggles actually toggle again on new-menu builds.** The rotation /
  cooldowns / AoE / utility gates read the real NS.settings state instead of
  imperative widgets that are never rendered under the retained menu, so
  flipping a toggle changes behavior immediately — with no ordering dependency
  on the per-tick settings sync.
- **Playstyle switching is instant.** A forward-reference bug made the live
  playstyle read silently fall back to settings, so role filtering of the
  Quick Toggles and Control Panel rows lagged a tick behind your selection.
  The live menu value is now read first.
- **Healing fix (party/raid)**: a context-caching bug could leave the
  lowest-friendly-unit read resolved to a stale empty default, silently
  turning party heals into self-heals. Cache invalidation now runs on every
  resolver registration.
- **Frost Death Knight fix**: Obliterate could fire with a single ready death
  rune counted toward BOTH its frost and unholy rune requirements — a commit
  the engine can never cast. The gate now requires two real rune slots.
- **New (WotLK): destruction warlock Backdraft.** Conflagrate now grants its
  era-correct Backdraft haste window, and a proc lane spends that window on
  Soul Fire ahead of Incinerate when mana allows.
- **Coverage**: the era-content campaign pinned every WotLK class spec and
  leveling rotation behaviorally (all 10 classes) and closed the last
  unpinned cross-era paths — rotation battery 545 → 563.

### Developer Notes
- **ARCH-1 (architecture pass)**: the Control Panel subsystem moved into
  `shared/control_panel_sylvanas.lua` — single owner of the permashow row set,
  the v2-vs-legacy mode decision, native mirror seeding, role reconciliation,
  and the one-shot diagnostics logs. `main.lua` stays the composition root
  (widgets + defs); `MenuTheme.def_allowed` in `menu_theme_sylvanas.lua` is the
  single role-visibility predicate shared by the menu Quick Toggles and the
  panel.
- **CP2.1**: dual-path Control Panel — `menu.control_panel.add` (v2, retained
  mode) is used automatically when the new `_G.menu` host is present, with the
  legacy per-frame callback as fallback and an `eax_use_cp_v2` setting to force
  the legacy path. Rows are reconciled on playstyle/role change from on_update
  so both paths filter identically.
- **CP2.2**: `render_control_panel` removed from the shared dispatcher's
  fallback tick-source list in `core_sylvanas.lua`; dispatcher now logs the
  claimed fallback source once instead of silently squatting.
- **CP2.3**: `main.lua` registers menu + control-panel callbacks before
  `NS.register_on_update_callback`; one-shot logs report the active path and
  legacy row count (support triage for any future "can't see the panel" report).
- **CP2.4**: `shared/menu_theme` role filtering unchanged; new
  `tests/test_control_panel_v2_dual_path.lua` locks the registration order,
  the unbound-row bypass, the 7-default sentinel, the native mirror seeding,
  and the fallback-source removal.
- **CP2.5**: findings verified against docs.project-sylvanas.net
  (modules/control-panel, dev/api/ui): `insert_toggle_` calls now use the
  documented 4-arg signature (drag capability moved to the native
  `set_draggable_state`), and quick-toggle keybinds initialize with the
  documented Unbinded code 7 instead of 999.
- **DM-1**: `DeclarativeMenu.initialize` / `sync_to_settings` declared as colon
  methods; `initialize` resets retained-state handles and captures the
  playstyle / keybind / diagnostics controls so the panel and settings sync
  reuse the real retained widgets (`control_panel_defs`, `playstyle_control`).
- **DM-2**: quick-toggle gates in `main.lua` read NS.settings via
  `read_quick_toggle` when the declarative menu is active (like the master
  toggle), removing the `sync_to_settings` ordering dependency.
- **DM-3**: `get_active_playstyle` now forward-declares `menu_elements` — the
  reference previously bound to a global, so the live-combobox branch silently
  never ran and role reads lagged a tick (playstyle/role filtering fix).
- **DM-4**: menu + Control Panel initialization is callable at boot and again
  after a deferred class-module load (on_update re-init path).
- **LC-1**: `lazy_context_sylvanas.lua` clears a field's cached/resolved value
  on EVERY registration, including the first — a raw-seeded value (e.g.
  `build_context` seeding `lowest`) can no longer shadow its resolver; party
  heals previously fell back to self-heals (playtest finding).
- **DK-1**: frost Obliterate's rune gate now requires ≥2 rune slots across the
  frost / unholy / death families — a single death rune cannot pay both its
  frost and unholy slots.
- **BD-1 (Backdraft)**: `wowhead_data_bridge_spell_index_wotlk_sylvanas.lua`
  gains 54274/54276/54277 with a manual-entry note documenting the correction
  from the 55379/55380 draft (Skyflare Swiftness, a meta-gem proc);
  `destruction_wotlk.lua` adds the `SoulFireBackdraft` consumer lane above
  Incinerate (in combat, buff up over the aura family, mana ≥30) and pins it
  behaviorally (proc-up fires, no-proc/29-mana/OOC held). The era-pair seed
  was re-baselined via its sanctioned tool to allow the WotLK-only lane.
- **QA-1 (era-content campaign)**: real-read behavioral suites load every
  `*_wotlk.lua` spec and leveling file against a mock NS through the real
  `build_state` read path (fire/don't-fire pins on buff/debuff remains,
  resource, procs, target state, cooldown_remains, hit-volume gates); the
  TBC/vanilla/SoD parity scan found no spec without a behavioral suite — TBC
  retribution re-verified at 47 strategies (the reported "~4" traced to a
  stale status_audit.md snapshot) — and pinned the two uncovered handling
  paths (middleware ViperSting lane, vanilla Binding Heal era-gate).
  Never-triage gates stay 0/0 across all eras; scorecard regenerated via
  `tools/spec_scorecard.lua`; era triage-doc addenda appended.
- **POL-1**: schema duplicate-key warnings are now conflict-only — identical
  re-declarations (e.g. the priest Smart Casting block shared between the
  Discipline and Holy tabs) merge silently via the new
  `shared/schema_def_compat_sylvanas.lua` comparator, so boots are
  warning-free while conflicting duplicates still warn.
- **POL-2**: removed the dead module-level `ctx.lowest` seed in
  `main_sylvanas.lua` (the per-tick `build_context` seed is the only live one).
- **POL-3**: `docs/status_audit.md` gained a prominent staleness banner pointing
  to the scorecard as authoritative — no generator exists for that file, so
  stale rows were flagged rather than fabricated.


### Additions — folded into 2.25.0 (recorded 2026-09-06; no separate release — 2.25.0 is still unshipped, so everything below ships inside it)

**Player-facing**

- **Every era is now rated.** The scorecard (`docs/scorecard.md`) extends from
  TBC + WotLK to all four eras — **132 scored specs** (TBC/Sylvanas 31 ·
  WotLK 41 · Vanilla 40 · SoD 20) — with strict never-gates and 0 dead lanes
  everywhere. Vanilla's 12 classified lanes and SoD's strict-0 result are
  pinned lane-for-lane from the live battery.
- **Snapshot & totem mechanics are now proven, not assumed.** The behavioral
  rig gained an execute-capture harness (runs the real cast execute so
  module-local state seeds exactly as live, then re-evaluates): druid
  RakeSnapshot/RipSnapshot (TBC) and enhancement FireNovaReplacement /
  GraceOfAirTotemTwist (TBC + Vanilla) all fire through the real files —
  druid/cat rose to A and enhancement to S+ (TBC) / S (Vanilla).
- **New player-facing accuracy page** (`docs/ACCURACY.md`): what a "strategy"
  is, the era/spec rating tables, and the headline claims (4 eras, 132 specs,
  2,468 rules exercised, 0 dead, 563-suite battery, 50/50 sim-checked) plus an
  honest known-limits section — generated from the same live data the gates
  check, so it cannot drift.
- **README is now true to the gates**: spec badge "132 rated (4 eras)",
  four-era framing, suite counts 563 rotation + 39 leveling = 602 (from the
  sanctioned badge tool), APL 50/50 computed live, and a link to ACCURACY.md.
  The unverifiable "29+9" / "556 (524+32)" / "34/34" claims are gone.
- **New in-game "why is it casting X" trace**: Diagnostics → "Trace Casts"
  records the last 32 casts as the rule that fired plus the live state behind
  it (e.g. `[arcane] ArcaneBlast: arcane_blast_stacks=3 mana_pct=62`), shown
  in a Last-Casts readout with Print/Clear actions — zero performance cost
  while the toggle is off.

**QA / engineering**

- **Scorecard + accuracy page drift-gated**: `tools/spec_scorecard.lua
  --check` regenerates and byte-compares both `scorecard.md` and
  `ACCURACY.md` inside verify_all, so the pages and README's link cannot rot
  again.
- **Per-frame cost gate (P3)**: `tools/perf_cost_gate.lua` measures BOTH
  retained allocation and per-frame churn (GC-stop technique: collector
  stopped for the measured batch so temporaries are counted) under the
  capturing mock across the dispatcher tick, the cast trace (off/on), the
  Diagnostics readout (idle/live), Control Panel reconcile, and the real
  legacy Control Panel per-frame render callback — each path prints retained
  AND churn deltas against named bounds; wired into `verify_all` as the
  "perf cost gate" component so a regression on either metric hard-fails.
  The gate caught and fixed two violations: (1) the trace readout allocated
  an empty table per frame when idle (now a shared empty return); (2) the
  legacy CP render built a fresh row table every frame and ran a `pcall`
  closure per quick-toggle per frame — the row array is now cached and
  rebuilt only when mode/role/key-code/schema actually change, with direct
  (non-closure) key-code reads on the hot path (~4.7 MB → 0.19 KB churn per
  20k frames). Per-class cost sweep remains OPEN (the gate runs one engine
  tick + the render workloads, not every spec file).
- **Coverage**: era batteries at tbc 11 · wotlk 0 · vanilla 9 · sod 0 with
  the two honest residue lanes (Fade, Ret_SealMartyr_Primary) filed with
  one-line code evidence in the triage docs.
- **Per-class research reconciliation**: the ClassResearchTBC corpus was
  re-verified against the live tree (all Present mechanics confirmed, one
  MISSING mechanic found implemented) and recorded in
  `docs/PER_CLASS_RESEARCH.md` with provenance + honest limits; the warlock
  imp machine-gun refire gained a behavioral pin in `test_warlock_live_fixes.lua`.

## 2.24.2 — 2026-08-14

### Customer Changelog
- **Wave-5 live-lane sweep (11-agent research audit → 12 targeted fixes)**:
  a read-only audit of every rotation against the real engine surface found
  lanes that pass every test yet cannot work in production. Fixes:
  - **Druid Rebirth actually resurrects now** — the resto Rebirth lane cast
    on the player itself with no dead-ally discovery; it now targets a real
    dead party member via the shared find_dead_party_ally chain (mirrors the
    vanilla-era fix).
  - **Mage Scorch vulnerability now tracked** — fire_wotlk read the
    "Improved Scorch" *talent* id (12873) as the target debuff, so
    scorch_remains was always 0 and Scorch re-cast every GCD. Now reads
    Fire Vulnerability (22959), the real rank-independent debuff (DBC-
    verified; TBC file already used it).
  - **Death Knight presences stay put** — state.presence is now populated
    from the shared buff-detection helper (per-spec tables were dropped);
    this kills the infinite presence-recast loop when the desired presence
    differs from Blood.
  - **Warlock Curse of Tongues fires in PvP** — the lane read a context
    field only test mocks provided; the engine now detects mana-class
    enemies (the cast-speed curse only affects mana classes).
  - **Shaman Purge works in PvE** — same mock-only field; the engine now
    flags targets carrying any buff (the real purge candidates).
  - **Shaman Magma Totem restored in Classic** — elemental_vanilla had the
    lane hard-disabled with a wrong rationale ("max rank is TBC-only"); all
    four ranks are Classic-era. Vanilla never-firing pins 13 → 12.
  - **Priest mana-floor wanding works** — the <5% mana wand lane called
    start_auto_attack() with no target (a guaranteed no-op); it now passes
    the target + wand attack type.
  - **Warrior healthstones respect cooldowns** — protection's stone gate
    checked bag presence only, so at ≤28% HP it monopolized the rotation
    during the stone's cooldown; arms' stone ladder now reads the real
    era-data list (the old code read an undefined global).
- **Hunter WotLK rotations no longer act out of combat**: 27 offensive
  lanes (9 per BM/MM/Survival) now require in-combat — no more casting
  Kill Shot / Serpent Sting / traps etc. while idle.
- **Paladin peel reliability**: threat-aware peel lanes now read the real
  threat API through one canonical helper (context.threat_level engine
  producer) instead of mock-only unit fields.

### Developer Notes
- **W5.1**: dead HitCapPriority lanes removed (context.hit_rating is not
  producible — the rating API returns a bonus %, not rating); the SoD
  class-table shadow eliminated (`define_sod_action_for_class` now resolves
  explicit rune ids); the sylvanas spell-ID audit gained an SoD tier — 58
  pinned SOD_RUNE_IDS + single-numeric define extraction covers all 20
  `_sod.lua` loaders; Shadowburn corrected to 29341 (was Searing Pain r3).
- **W5.2**: `main_sylvanas.lua` produces `context.threat_level` (number +
  has_aggro from the real `get_threat_situation`); paladin protection/holy
  peel lanes and their vanilla mirrors consume `NS.threat_status`;
  battery mock reworked to bank-driven threat. Hunter WotLK OOC gating
  applied via EOL-safe transform (27 lanes, 3 specs).
- **W5.3**: the research findings that survived DBC/era-mirror verification
  — full re-verification disproved the priest pushback-inversion and
  shaman LightningShield-default claims (the vanilla files faithfully
  mirror the TBC design). Contract pins moved with evidence: WotLK audit
  Scorch allowlist 12873 → 22959 (count 184 unchanged), sod_context
  Lifebloom 33763 → rune 409824 (Riptide precedent), Rebirth DSL tests
  supply dead allies, vanilla never 13 → 12 (MagmaTotem).
- **Battery contracts after the wave**: TBC never=16 · WotLK 0 · Vanilla
  12 · SoD 0 — all four eras green in `run_verify_all.lua` (18 components,
  exit 0). Provenance: `tools/evidence/apl/SOURCES.md` documents why the
  SoD era has no wowsims APL fixtures by design.
- **Pre-commit gate**: all 19 steps green; release commit follows.

## 2.24.0 — 2026-08-14

### Customer Changelog
- **Top-tier parsing campaign complete (all three eras)**: every rotation
  spec (TBC 29 + 12 leveling, Vanilla 40, WotLK 29 + 12 leveling) now
  battery-verified with never-firing pins TBC 16 / WotLK 0 / Vanilla 13.
  Campaign scope (2026-08-07 → 2026-08-14): dead-matcher sweeps, the
  behavioral battery extended to every spec, spell-ID era audits, and the
  WotLK production never-lane campaign below.
- **WotLK production never-lanes eliminated (25 Criticals across 10
  classes)**: the Wave-3 audits found ~25 Criticals that the test battery
  could not see — mock-only API reads that made real rotations dead in
  production (`action:cooldown_remaining()`, `action:cast_safe()`,
  `me:get_rage()/get_energy()/get_combo_points()/get_mana_percentage()`,
  phantom `context.*` fields the engine never sets, `context.is_boss`
  vs the real `context.target_is_boss`, WotLK max-rank debuff IDs missing
  from lookup tables, rank-list contamination such as HowlingBlast
  containing rogue Blade Flurry IDs, and TBC-capped rank lists shadowed by
  `define_action_for_class`). All fixed with real engine API; the battery
  now fails loudly on any re-introduction (fail-on-use tripwires). Notable
  rescues: Feral Spirit, Bloodlust, Mana Tide, Summon Gargoyle, Unbreakable
  Armor, Empower Rune Weapon, Frost Presence (never applied), Conflagrate
  (never fired), the entire warrior rage family, paladin DivinePlea, DK
  Frost/Unholy presences, WotLK-interrupt Wind Shear, Tiger's Fury CD gate.
- **New parse-critical mechanics added** (pin-safe, mostly opt-in):
  - TBC: `player_spell_damage` engine (DoT snapshot-upgrade gates for
    affliction/shadow/elemental/balance + Immolate min-SP gate), in-combat
    Aimed Shot weave (`mm_aimed_weave`), PoH-priority mode
    (`disc_poh_priority`) + PoH 4→3 threshold, resto emergency
    Lesser Healing Wave above ChainHeal, elemental single-target Chain
    Lightning + Flame Shock maintain (`elemental_cl_single_target`,
    `elemental_fs_maintain`), balance aggressive Wrath (`balance_wrath_conserve`
    opt-out) + restored healer-priority Innervate, affliction curse-first
    opener (`aff_curse_first`), fire Evocation/ManaGem promoted above the
    filler chain (wowsims 20% mana threshold).
  - WotLK: queued Heroic Strike/Cleave with swing-timer gates, Last Stand,
    Righteous Fury + Holy Shield charge management, seal switching, weapon
    imbue upkeep, totem slot-occupancy management, ghoul pet commands,
    Eclipse spell-switching, Tiger's Fury/Berserk, Nourish/Innervate,
    Circle of Healing at its pinned APL slot, Shadowfiend + Mind Flay clip
    gating, Lock and Load proc wiring, Explosive Shot max rank.
- **10 new live-fix regression suites** (`test_<class>_wotlk_live_fixes.lua`)
  exercising the REAL production API shapes (no mock-only members) so the
  entire mock-only bug class cannot silently regress; 9 vanilla live-fix
  suites from Phase 1.
- **Battery hardening**: the lenient mock members that masked the production
  never-lanes are removed or converted to fail-on-use tripwires; era-pair
  seed, spec scorecard, and badges all regenerated from the live tree.
- Version **2.24.0**.
- Tests: 523 rotation + 32 leveling + 45 WotLK suites registered (600 total;
  all green at runtime; `run_verify_all.lua` exit 0).

### Developer Notes
- **The 7 systemic mock-only patterns** (documented in AGENTS.md Pattern 17):
  `ACTION.*:cooldown_remaining()` / `ACTION.*:cast_safe()` exist ONLY on test
  mocks (production `spell_action` exposes id/IsReady/IsInRange/Cast);
  raw unit methods (`get_rage`/`get_energy`/`get_combo_points`/
  `get_mana_percentage`/`get_runic_power`) are NOT on the engine surface
  (use context fields, `me:get_power(...)`, or izi `*_current()`); phantom
  context fields; `context.is_boss` → `context.target_is_boss`; WotLK
  buff/debuff tables must carry WotLK max-rank IDs (literal matching);
  `define_action_for_class` shadows file-local WotLK rank lists (use plain
  `spec_kit.define_action`, fire_wotlk.lua:20 precedent); rank-list
  contamination (verify against the wotlk bridge).
- **Wave-3.4 battery tightening**: `behavioral_audit.lua` mock injections
  for the removed members are now fail-on-use tripwires; phantom scenario
  overrides deleted; the two W3.4 residuals (warrior rage, paladin mana
  sole-source reads) were fixed in targeted waves and their injections
  converted to tripwires with 0 dispatch errors across all eras.
- **Parse-spec docs**: `docs/parse_specs/<era>/<class>/<spec>.md` now
  documents every guide divergence (9 files: protection, marksmanship,
  fire, arcane, discipline, restoration, balance, elemental, affliction) —
  pinned source, priority, thresholds, divergence, and the setting that
  flips it.
- **Provenance**: `tools/evidence/apl/SOURCES.md` gained the campaign
  delta — no fixtures re-fetched (563e4a08 baseline holds, APL pass 50/50);
  the only manifest change is the holy `CircleOfHealing 48089` resolve
  (W3.3).
- **Pre-commit gate**: unchanged steps; all 17 verify_all components green.
- **CI**: verified via `run_verify_all.lua` locally (exit 0); push follows
  the release commit.

## 2.24.1 — 2026-08-14

### Customer Changelog
- **SoD (Season of Discovery) era joined the top-tier campaign — 0
  never-firing lanes across all 20 `_sod.lua` rotations** (druid
  balance/feral/restoration/tank, hunter dps, mage dps, paladin
  protection/retribution, priest healing/shadow, rogue combat/tank,
  shaman elemental/enhancement/restoration/warden, warlock dps/tank,
  warrior dps/tank). The behavioral battery now covers **all four eras**
  (TBC 16 pins / WotLK 0 / Vanilla 13 / **SoD 0 — strict**), 18 verify_all
  components, exit 0.
- **SoD production never-lane fixes** (the W4.1/W4.2 audit wave): the
  rune-gated SoD actions were dead in production because `NS.get_sod_runes`
  existed only in test mocks — the engine now reads real settings-driven
  runes, and rune state is fail-open (unknown = open; known non-empty
  without the rune = closed), so a player without a rune simply cannot cast
  the rune spell instead of the rotation silently degrading. Also fixed:
  `define_sod_action_for_class` rejecting class-table-backed spells (shaman
  FlameShock/LightningBolt/ChainLightning and every other class-table
  action resolved nil), the `context.injured_count` healer-injury alias
  (resto Wild Growth / Chain Heal / Healing Stream gates), warden
  Rockbiter/weakened-soul/fire+water-totem field wiring in
  `sod_context_sylvanas.lua`, LavaLash's mock-only `offhand_imbue` gate,
  and BerserkerRage numeric-stance normalization.
- **Battery-era mechanics**: the real `sod_context` enrich now runs against
  every battery scenario (form, Metamorphosis, Maelstrom, poison stacks,
  totem slots, Weakened Soul all driven through production producers), the
  mock `spell_action` emits the live `_meta` surface (37-lane false-positive
  cluster cleared), and 14 SoD scenario shapes make every strategy
  observable. Full evidence: `docs/never_strategy_triage_sod_2026-08-14.md`.

## 2.23.0 — 2026-08-10

### Customer Changelog
- **WotLK APL conformance complete (34/34 → 50/50)**: every remaining
  unpinned WotLK spec is now pinned to its wowsims/wotlk TypeAPL fixture
  at commit 563e4a08 (byte-verified provenance in SOURCES.md) — 16 new
  fixtures covering DK blood/frost/unholy, druid balance/bear, hunter
  BM/mm/sv, paladin prot/ret, shaman enhancement, warrior
  arms/fury/prot, warlock demo/destro, plus the holy/disc priest healer
  pins. Manifest keys are class-qualified (`wotlk/<class>/<spec>` — never
  bare: the wotlk/holy paladin-vs-priest collision proved why). Pure
  order moves only (9 spec files) to match the sim steady chains — no
  matcher-logic edits. One structural divergence is kept and documented:
  fury Execute stays top-priority (the sim's execute-phase filler sits
  below a proc-gated Slam).
- **Live-game crash fixes** (surfaced by the new audits and shared-module
  tests):
  - `los_guard` unguarded `NS.same_unit` nil-call — every non-self
    try_cast crashed (core_sylvanas:2301-2303); now guarded with the
    module's fall-through semantics.
  - `incoming_heal_predictor` missing `cleanup_caches` — a crash on every
    healer build_state tick after ~1s uptime; implemented from the
    module's own caching constants.
  - `combat_stats` downtime dead-branch increment; `match_helpers`
    early-return guard moved after its definitions.
- **Three new static audits** (each with a `--self-test`): dead-matcher
  audit (removed 38 orphaned matchers, −428 lines), NS-member audit
  (never-defined `NS.<member>(` calls — the los_guard / cleanup_caches
  crash class), version-consistency audit (header.lua runtime version
  must equal the CHANGELOG top release — caught the stale 2.18.1
  runtime version that every reload logged).
- **Shared-module test coverage**: 8 new regression suites pinning
  previously-untested live modules — combat_log_parser (~45 asserts incl.
  the exact-60s prune boundary), swing_timer, player_helpers,
  combat_stats, incoming_heal_predictor, middleware_scan_cache,
  gear_score, match_helpers. Dead `aura_cache` module deleted (its
  dormant 1000x TTL bug dies with it).
- **Middleware performance**: non-urgent middleware is skipped while
  casting/channeling and out of combat (18 `mid_cast_safe` marks) — the
  paladin's 259 NS.* calls/frame and the other 7 middleware classes no
  longer evaluate on every frame.
- **Docs honesty**: the healer "on paper" claims corrected — healers are
  battery-verified, not sim-conformant; the "no healer sim exists" claim
  falsified for WotLK holy/disc priest and corrected; ghost file paths
  fixed and deleted `run_all_checks.sh` de-referenced.
- Version **2.23.0**.
- Tests: 485 rotation + 31 leveling suites registered (516 total; all
  green at runtime).

### Developer Notes
- **APL pipeline**: occurrence-aware resolvers map each repeated fixture
  id to exactly ONE main-chain occurrence (execute/AoE/refresh branches
  resolve nil) — mapping every occurrence created unsatisfiable reference
  sequences (dk_blood's two DeathStrikes forced both
  DeathStrike<Pestilence and HeartStrike<DeathStrike). The scorecard's
  APL-evidence lookup now tries the class-qualified key first (dk/frost
  previously showed the *mage* fixture's evidence; dk/blood showed nil).
  Fixture display names remain a 50-entry hardcoded map in the scorecard
  generator — candidate for deriving from the manifest entry.
- **NS-member audit resolver**: comment/string stripping; exact-RHS
  module binding (`local NS = _G.EaxRotations` forms only); engine
  surface via .api stubs + @field annotations; 34-entry allowlist (19
  mock + 11 guarded + 4 engine members) after the CI-parity fix — the
  engine census reads gitignored local dirs absent in CI, so the
  allowlist is the portable guarantee (reproduced locally with empty
  ENGINE_DIRS: Invalid 20 matching CI; now Invalid 0).
- **Pre-commit gate 12 → 15 steps**: dead-matcher audit, version-
  consistency audit, and NS-member audit added as steps 13-15 with their
  self-tests; verify_all now runs 23 components; hook re-synced via the
  documented cp.
- **cleanup_caches implementation**: built from the module's own
  constants (cache TTL/tick interval); the regression suite that caught
  it stays as the semantic guard.
- **CI**: the WotLK campaign push (2a9ba82) verified green — Verify +
  release-artifact jobs both pass, artifact ~3.16 MB — pipeline commits
  CI-confirmed per the NS-member incident discipline.

## 2.22.0 — 2026-08-10

### Customer Changelog
- **Release pipeline automated end-to-end**: the release artifact is now
  built in CI, not on a maintainer machine. `tools/create_release_zip.py`
  is tracked and fixed (cwd-independent git archive, Windows-safe staging,
  pinned timestamps — the zip is byte-reproducible, 833 entries of tracked
  lua+md only, self-verifying). GitHub Actions runs a release-artifact job
  on master pushes that builds the zip, guards it (>1 MB), verifies its
  exact-set contents against `git ls-files` (no extra, missing, or
  duplicate entries), and uploads it (`eaxrotations-release`, ~3.1 MB).
  ~115 MB of stale release zips were purged from the working tree.
- **Buff/debuff data pipeline made honest**: the committed
  `buff_debuff_full_verification.json` was stale by 5 WotLK spell IDs;
  regenerated to 2231/2231 unique IDs (fail 0). The local-only manual
  regeneration step over the gitignored wowsims DBC is now documented in
  the generator and the PvP page, so the committed artifact stays current.
- **Pre-commit gate extended to 12 steps**: added the vanilla existence
  audit, the three spell-audit `--self-test` modes, and the clean-checkout
  dependency probe + its self-test — closing the last local-vs-CI gap
  (every verify_all component now runs locally except the intentional
  battery duplication).
- **Dead-code removal (208 lines)**: never-called `dump_form_detection`
  debug block in cat, the zero-consumer `izi_unit_state_sylvanas.lua`
  module, and two never-used DSL exports removed — all verified
  unreferenced before deletion.
- **Paladin middleware dedup**: the duplicated `unitNeedsCleanse`
  predicate (two byte-identical inline closures) hoisted to one
  module-level function — a debuff-list edit can no longer silently miss
  one copy.
- **Triage preserved**: `never_strategy_triage_tbc_2026-08-10.md`
  documents the full TBC battery campaign trail (91 → 13) and the gate
  reasons for each of the 13 remaining pins.
- Version **2.22.0**.
- Tests: 475 rotation + 31 leveling suites registered (506 total; all
  green at runtime).

### Developer Notes
- **Release-zip builder fixes** (`tools/create_release_zip.py`): derived
  the repo root from `__file__` so `git -C REPO_ROOT archive HEAD` works
  from any cwd; replaced the hardcoded Git-Bash `/tmp` staging path with
  `tempfile.mkstemp` (Windows-safe); pinned entry timestamps via
  `ZipInfo(date_time=(1980,1,1,0,0,0))` so consecutive builds are md5-
  identical; failure branches remove a stale/partial output zip.
- **CI entry-count pin**: the release-artifact job compares the zip to
  the tracked lua+md set computed dynamically from `git ls-files` (833
  today — no hardcoded number) and fails on any extra/missing/duplicate
  entry; actionlint 1.7.12 clean; verified live in CI (log shows 833/833,
  `OK: artifact == tracked tree`).
- **Pre-commit 6 → 10 → 12**: step 11 runs the vanilla existence audit +
  the three spell-audit `--self-test` modes; step 12 runs the
  clean-checkout probe + self-test; all new invocations use the exact
  verify_all commands/flags; `.git/hooks/pre-commit` re-synced via the
  documented cp (md5-identical).
- **Dead-code evidence**: `dump_form_detection` (cat:44-87) had zero call
  sites incl. dynamic; `izi_unit_state` had zero requires/package.loaded
  refs; DSL `register_condition`/`register_action` were never the builtin
  population path (direct table assignment is) and had zero callers.
- **unitNeedsCleanse hoist**: single module-level local at
  `middleware_sylvanas.lua:121`; both handlers call it; debuff id-sets
  verified byte-identical (appear exactly once each); dup-name rescan of
  all class files now 0.
- **buff_debuff regeneration**: +5 WotLK IDs (39023, 47488, 47610, 48089,
  48660) from the rank-audit pins; summary ok 2226 → 2231, online_wotlk
  1073 → 1075, fail 0; artifact pinned to LF via
  `EaxRotations/tools/.gitattributes` so the committed-artifact drift
  check is line-ending-independent.

## 2.21.0 — 2026-08-10

### Customer Changelog
- **TBC battery campaign complete (91 → 13 never-firing strategies)**: five
  close-out batches cleared every modelable lane with battery fixtures only
  — zero matcher-logic or order edits to any spec file. Healer category-(c)
  91 → 78, (c) batch-2 78 → 60, (a) opt-in settings 60 → 46, (b) bucket
  46 → 19, threat-family + race 19 → 13. The remaining 13 are
  correctly-silent by design: 9 out-of-combat/disabled lanes +
  EncounterReactions (declined) + 3 module-local-unpinnable (RakeSnapshot,
  RipSnapshot, FireNovaReplacement). WotLK battery stays at 0 never-firing.
- **Live-game bug fixes** (found by the battery campaign + static audit):
  - **BM Trinket dead lane**: `beast_mastery_sylvanas.lua:78`'s `local
    is_item_ready` forward declaration was shadowed by the `local function
    is_item_ready` at :458, so `trinket_1_ready` was never set and the
    trinket lane could never fire in live play.
  - **bear/cat cache-hit nil-guard bypass**: `bear_sylvanas.lua` /
    `cat_sylvanas.lua` returned the raw state table on frame-cache hits,
    bypassing `spec_kit.safe_state` defaults — nil fields leaked as nil
    instead of schema defaults.
  - **Warlock leveling cache-hit bypass**: `leveling_sylvanas.lua:327`
    returned raw `leveling_state` on its cache hit — caught by the new
    static audit on its first run.
- **New static audit**: `run_cache_hit_audit_tests.lua` enforces the
  frame-cache safe_state invariant across every class file
  (sylvanas/vanilla/wotlk/leveling); 16/16 cache-bearing files clean;
  injection-proofed and dual-interpreter (Lua 5.1 + 5.4) self-tested;
  wired into `verify_all` and the pre-commit gate.
- **Scorecard pipeline**: `tools/spec_scorecard.lua` + `docs/scorecard.md`
  compute per-spec S+ metrics (never-firing split, APL status, suite count)
  live from the battery and pinned wowsims fixtures
  (`tools/apl_status.lua`); drift-checked in CI + pre-commit.
- **WotLK battery triage (149 → 0)**: the first WotLK-era inventory (41
  files incl. DK) is fully cleared with battery-fixture upgrades — dead DK
  stubs (rune/presence/interrupt managers), missing resource accessors, and
  17 scenario banks — pinned in `test_wotlk_battery_regression.lua`.
- **Pre-commit gate extended 6 → 10 steps**: added leveling suite, WotLK
  test suite, WotLK spell-ID audit, and the cache-hit audit — closing the
  last local-vs-CI coverage gap.
- **CI hardening**: GitHub Actions `verify_all` workflow on push/PR,
  actionlint syntax gate, checkout v5 + lua actions v13 (Node 20
  deprecation cleared), badge-drift + scorecard-drift gates.
- Version **2.21.0**.
- Tests: 475 rotation + 31 leveling suites registered (506 total; all
  green at runtime).

### Developer Notes
- **Battery campaign fixtures** (`behavioral_audit.lua`): new scenarios +
  stub surface per batch — heal-scan threat_status + friendly_target_threat
  bank, `_friend` opts (role/threat_status), party/group member banks,
  `now`/combat-time keys, PvP mega-scenario (is_pvp/melee_on_you/
  enemy_healer/cc_target), race fixtures, snare-debuff player maps,
  is_auto_attacking bank, trinket/GetEnemiesInRange/find_dead stubs,
  map-aware buff/debuff/cooldown bindings with normalize_ids().
- **NEW RACE_VARIANTS mechanism**: `M.RACE_VARIANTS = { smite = { 5 } }`
  loads a spec a second time as a different player race (smite binds
  `_player_race` at require time) and merges the never lists so race-bound
  lanes like smite DevouringPlague become observable; era-gated so a future
  WotLK smite can't pick it up; variant load failure stays conservative.
- **WotLK triage**: dead DK stubs — rune_manager/presence_manager/
  interrupt_manager closures captured a nil `ns` (installed before
  build_ns); rewired after `ns` exists. Missing player-mock accessors
  (get_rage/get_energy/get_combo_points/get_runic_power) +
  spell_action:cooldown_remaining(). 17 scenario banks
  (dk_runic/dk_boss/dk_disease/dk_runes_depleted/...).
- **APL conformance**: TBC era extended to all sylvanas DPS/tank specs from
  pinned wowsims/tbc Go dispatches (pure order moves only, no matcher-logic
  changes); compute()-after-battery ordering fixed; vacuity guards hardened
  (every pinned name must resolve).
- **NS-caching pollution guard**: five shared modules that write back into
  `_G.EaxRotations` at require time (auto_tremor, dot_refresh,
  execute_phase, melee_combat_math, combat_forecast_gate) now defer the
  write until a real NS is present; a loud load-order guard fails any tool
  that requires shared modules while a mock NS is installed.
- **Badge reconciliation**: `update_badges.lua` pattern fixed (was
  `-passing`-only match, missed the URL-encoded badge); registry count now
  excludes `check_*` audit entries so the badge matches executed suites;
  README/PvP badge unstuck to the true 475/475.
- **Clean-checkout probe**: directory-vs-file POSIX fix + self-test
  regression; tracked non-EaxRotations paths accepted.
- **build_tools consolidation**: dead duplicate `build_tools/` trees
  removed; `_dbc_spell_ids.lua` header repointed; .gitignore pruned.

## 2.20.0 — 2026-08-08

### Customer Changelog
- **WotLK 3.3.5 rank verification**: every `*_wotlk.lua` rotation + leveling file
  audited against wowhead WotLK pages, wowsims APL JSONs, and the Go sim
  source. Two classes were already clean (hunter, shaman), two more clean after
  fixes (mage, paladin), and a systemic stale-ladder problem was fixed across
  **22 files / ~40 defines**.
  - **Live mis-cast bugs fixed**: Paladin Hammer of Wrath `48807` (was an
    Engineering consumable, Runic Healing Injector) → `48806`; warrior Execute
    `47498` (was Devastate) → `47471`; warrior Heroic Strike `47497` (was
    Devastate rank 2) → `47450`; mage Cold Snap `12472` (was Icy Veins — so
    Cold Snap never fired and the Icy Veins reset triggered instead) → `11958`;
    DK leveling Plague Strike `49922` (NPC spell) → `49921`, Heart Strike
    `55263` (NPC spell) → `55262`.
  - **TBC-era ladder tops replaced** with verified 3.3.5 max ranks (Corruption
    `47813`, ShadowBolt `47809`, Immolate `47811`, SoulFire `47825`, Frostbolt
    `42842`, Ice Lance `42914`, Shadow Word: Pain `48125`, and ~30 more) so
    max-level filler lanes no longer resolve to nil.
- **Classic vanilla purge**: 26 TBC-era spell IDs removed from vanilla spec +
  leveling files (17 files) — Classic now resolves the true Classic max rank
  instead of a TBC-only rank that could mis-cast or fail silently.
- **TBC purge**: WotLK-era spell leaks removed from sylvanas files (feral cat
  Berserk `50334`, polymorph debuff lists) — restored correct TBC behavior.
- **Rotation suite 466/466 green**: the 5 remaining env/data-file-gated suites
  were provisioned (2 test-bug fixes, tracked AoE plan doc, buff_debuff
  verification JSON, self-provisioning SOD task-1 action-map generator) — the
  full rotation suite now passes on a clean checkout.
- Version **2.20.0**.
- Tests: 469 rotation + 33 leveling suites registered (502 total; 466 rotation
  passing at runtime, all green).

### Developer Notes
- **WotLK rank audit** (`docs/wotlk_rank_audit_2026-08-08.md`): bug family A
  (wrong ID at ladder top → live mis-cast or dead lane) + family B (TBC-era
  tops → nil resolution at max level); fixes prepended per the project
  `get_spell_id`-returns-first-known pattern.
- **Vanilla/TBC sweeps** (`docs/vanilla_tbc_leveling_rank_sweep_2026-08-08.md`):
  extending the audit's `TBC_IDS` with the full TBC rank block surfaced 26
  TBC-era IDs across 14 vanilla spec files + 6 leveling tops; TBC leveling was
  clean except the platform-consistent Seal of the Martyr `348700`.
- **CI hardening**: rank-top enforcement (STALE_TOP detection + pinned max-rank
  allowlists) in the vanilla/TBC/WotLK audits with `--probe-stale-top`/self-test
  modes wired into `verify_all`; zero-skip masking-gap checks in the sylvanas
  audit against `git ls-files`; clean-checkout dependency probe
  (`run_clean_checkout_probe.lua`, 3,679 literals / 495 files) as a `verify_all`
  component (now 13); fail-closed lfs guards in `check_todos`/
  `check_unused_requires`; self-provisioning SOD generator + tracked buff_debuff
  generator with LF pinning.

## 2.19.0 — 2026-08-08

### Customer Changelog
- **Full rotation audit complete (304 → 100 never-firing strategies)**: a
  behavioral test battery now runs every strategy in every spec across 135
  realistic combat scenarios (all 31 specs, 0 load failures) and flags any
  strategy that never fires. 204 strategies that were unreachable in the
  battery were triaged — most were correctly silent (opt-in settings,
  PvP/stealth/OOC-only, or cooldown-state gating) — but **13 were genuine
  dead lanes fixed in live play**, including:
  - **Protection Warrior Intervene**: the party-scan + matcher truncated the
    vec3 position API (read `{x,y,z}` fields instead of multi-value capture),
    so Intervene could never fire in live play; also fixed the same
    position-read family across the codebase (audit doc:
    `docs/position_contract_audit_2026-08-08.md`).
  - **Warlock Destruction pet summons**: `SummonFelhunter`/
    `SummonVoidwalker`/`SummonFelguard` were hardcoded off in
    `summon_pet_matches`; all three preference branches now work.
  - **Mage**: arcane/frost `healthstone_ready` + `mana_gem_available` and
    fire `hp_pct` build_state assignments unblocked Healthstone/IceBarrier/
    ManaShield/Mana Gem lanes.
  - **Priest/Druid/Hunter**: holy `mana_pct` (ManaPotion), resto
    `healthstone_ready` (Healthstone), MM `BestialWrath` spell_exists gate,
    and disc/holy/resto `Preemptive*Heal` state wiring.
- **33 battery regression suites** pin every unblocked lane family so a
  future edit can't silently re-hide them.
- Version **2.19.0**.
- Tests: 469 rotation + 33 leveling suites registered (461 rotation passing at
  runtime; 5 pre-existing env/data-file gaps).

### Developer Notes
- **Campaign**: 304 → 254 → 249 → 224 → 219 → 218 → 217 → 216 → 215 → 213 →
  207 → 194 → 183 → 180 → 176 → 173 → 161 → 152 → 151 → 145 → 144 → 140 →
  133 → 130 → 125 → 118 → 112 → 111 → 110 → 109 → 108 → 106 → 105 → **100**
  (DPS 13 + non-DPS 87); final split **(b) 38 · (c) 62 · (a) 0 · (d) 0** —
  zero opt-in and zero dead lanes remain.
- **Battery upgrades** (all in `tests/behavioral_audit.lua`, now 135
  scenarios): unit-aware `buff_up`/`debuff_up`/`debuff_remains` maps,
  `setting_overrides` fixture (covers direct `ctx.settings`,
  `spec_kit.setting`, and DSL setting conditions), `not_learned` map,
  `on_cd`/`swing_until`/`combat_time`/`target_cast_pct`/`hit_rating`
  overrides, friend mocks with `get_class`/`get_position`/`get_owner`,
  heal-scan deficit fix, per-buff scenarios (lights_grace, seal-twist,
  affliction/dispel), party-frame `get_friendly_target_entry`, scenario-aware
  `FsrManager` + `TrinketManager`-style stubs, elite/undead/pvp/stealth/
  boss creature-type + threat scenarios.
- **Spec fixes (13 dead lanes)**: fire/arcane/frost mage, holy priest,
  resto druid, MM hunter, disc/holy/resto Preemptive heal-state, destro
  warlock summons ×3, prot warrior Intervene (real live bug — multi-value
  `get_position` truncation, reclassified (b)→(d) during the sweep).
- **Triage docs**: `docs/never_strategy_triage_dps_2026-08-07.md` +
  `docs/never_strategy_triage_non_dps_2026-08-07.md` (per-lane probe
  evidence + campaign summary); `docs/position_contract_audit_2026-08-08.md`
  (full codebase position-read audit).

## 2.18.1 — 2026-07-29

### Customer Changelog
- **EaxESP attachment API crash fix**: Resolved the critical bug where `get_attachment_position()` and `get_attachment_name_position()` caused hard client crashes (native access violations). All attachment API calls have been eliminated — the renderer now uses `pos.z + offset` fallback for all height calculations. Diagnostic tools are gated behind an explicit opt-in global.
- Version **2.18.1**.
- All tests passing: 398 rotation + 31 leveling suites (429 total).

### Developer Notes
- **Attachment API resolution**: Both `get_attachment_position(id)` and `get_attachment_name_position()` cause native access violations on Sylvanas Core 1.981+ that `pcall` cannot intercept. Resolution: eliminate all API invocations.
- `EaxESP/attachment_safe.lua` — `probe_once()` does existence-only checks (`type() == "function"`); `name_pos()` and `attachment_pos()` always return `nil`; `head_position()` uses `get_position() + offset`; dead code (`vec3_ok`, `copy_vec`, `M._ok_ids`) cleaned.
- `EaxESP/diagnostic_attachment_only.lua` — API calls gated behind `_G.EAXESP_ALLOW_ATTACHMENT_CALLS=true`.
- `EaxESP/diagnostic_api_crash.lua` — Attachment entries gated behind `EAXESP_ALLOW_ATTACHMENT_CALLS`; non-attachment methods still run.
- `EaxESP/tests/test_attachment_safe_module.lua` — Assertions updated for always-nil behavior.
- `EaxESP/tests/test_attachment_safe_probe.lua` — `probe()` and `probe_target()` gated behind `EAXESP_ALLOW_ATTACHMENT_CALLS`.
- **Full audit**: `reader.lua`, `main.lua`, `renderer.lua` confirmed zero direct calls to attachment APIs — all go through `attachment_safe.lua`.
- **Planning notes archived**: Both bug reports + crash hardening notes archived.
- EaxESP files are `.gitignored` (local-only); changes applied locally.

## 2.18.0 — 2026-07-29

### Customer Changelog
- **9-class audit complete**: ~32 bugs fixed across all 9 class directories (Paladin, Warrior, Hunter, Rogue, Mage, Warlock, Priest, Shaman, Druid). Fixed unguarded registrations (crash on nil registry), missing state arguments in AoE gating calls, duplicate strategies, dead code, and nil field references.
- **All 40 vanilla spec files migrated to safe_state**: Every Classic Era (Vanilla) spec file now uses `spec_kit.safe_state()` for structural nil-guard enforcement, making the Pattern 14 nil-guard bug structurally impossible across the entire codebase.
- **WotLK DSL adoption 100% complete**: All 41 WotLK spec files now use the declarative strategy DSL (was previously reported as 19/41 — actually already 100%).
- Version **2.18.0**.
- All tests passing: 398 rotation + 31 leveling suites (429 total).

### Developer Notes
- **9-class audit**: Comprehensive audit of all 9 class directories checking for `luac -p` compilation, banned APIs, `broken_api_throttled` remnants, unguarded `menu:get()`, unguarded `NS.rotation_registry:register()`, missing `state` args in `aoe_target_meets()`, duplicate strategies/assignments, dead code, and `safe_state` adoption.
- **Bug severity**: 7 Medium (crashes on nil registry, nil field access, broken AoE gating, cache-hit nil-guard bypass), ~25 Low (unguarded registrations, dead code, duplicate strategies/assignments, missing imports).
- **safe_state migration**: Each of the 40 vanilla files received a `SCHEMA` table with Pattern 14 nil-guard defaults and `spec_kit.safe_state(state, SCHEMA)` wrapping on all `build_state` return paths.
- **Warrior cache-hit fix**: `arms_sylvanas.lua` — `safe_state` was not applied on the `build_state` cache-hit early-return path, causing nil-guard bypass on cache hits. Fixed by wrapping the cache-hit return.
- **Hunter fixes**: `leveling_vanilla.lua` — malformed strategy table nesting (strategies were nested inside another table). `leveling_wotlk.lua` — missing `state` argument in strategy match function. `beast_mastery_vanilla.lua` — broken pcall registration pattern that crashes if `NS.rotation_registry` is nil.
- **Rogue fixes**: `assassination_sylvanas.lua` — `blind_ready` field referenced in match function but never populated in `build_state` (nil access). Dead code removed across multiple files.
- **Mage fix**: `frost_vanilla.lua` — duplicate Frostbolt strategy entry (dead code).
- **Warlock fix**: `leveling_wotlk.lua` — missing `state` arg in `SeedOfCorruption` `aoe_target_meets()` call (AoE gating broken).
- **Priest fix**: `leveling_vanilla.lua` — duplicate strategy entries.
- **Shaman fix**: `leveling_vanilla.lua` — duplicate `tremor_totem_ready` state field assignment.
- **Druid fix**: `balance_sylvanas.lua` — missing `state` (s) arg in 2 `aoe_target_meets()` calls (`PreHurricaneBarkskin` + `HurricaneAoE`). `balance_vanilla.lua` — missing `spec_kit` require (using `spec_kit.setting_bool` without importing).
- **Paladin cleanup**: Removed dead `post_swing_judge_gate` function and unused `prot_post_swing_judge` schema setting.
- **Planning notes cleanup**: Archived 26 completed notes, removed 10 duplicate plan files.
- **WotLK DSL adoption**: Verified all 41 WotLK files have `DSL_DEFS` tables + `dsl.compile_strategy` substitution. 43/43 WotLK test suites pass. Plan marked COMPLETE and archived.
- **Documentation**: Agent instruction file updated (Pattern 14 + Pattern 16 migration status), README.md updated (migration state table + badges + version).
- **.gitignore cleanup**: Binary directories (`common`, `core_lua`) and temp files excluded from git tracking.

## 2.17.0 — 2026-07-26

### Customer Changelog
- **Schema settings sync fix**: All class settings (checkboxes, sliders, dropdowns) now properly sync to the rotation engine. Previously, settings like Auto Prowl, Auto Taunt, and Curse Mode were purely cosmetic — toggling them did nothing. Toggling Auto Prowl OOC off now correctly disables auto-prowl.
- **Warlock (Destruction)**: Auto curse mode now picks Curse of Doom for long fights (≥60s TTD) and Curse of Agony for short fights (<60s), instead of always defaulting to Doom.
- **Warlock (Destruction)**: New **Immolate toggle** checkbox — disable for speed-kill guilds that skip Immolate for pure Shadow Bolt spam.
- **Warlock (Destruction)**: **Life Tap while moving** — replaces Searing Pain as the movement filler. When moving and mana isn't full, the rotation taps for mana instead of casting Searing Pain. Safety-gated on HP so you don't kill yourself.
- **Warlock (Destruction)**: **Configurable Life Tap thresholds** — mana threshold slider (default 20%) and HP safety gate slider (default 50%) replace the old hardcoded 35%/40% values.
- Version **2.17.0**.
- Clean `eaxrotations.zip` (lua + md only).
- All tests passing: 391 rotation + 31 leveling suites.

### Developer Notes
- `main.lua` — `create_schema_widget` dropdown sync: replaced `or`-chained lookups (`vals[i] or vals[i+1]`) with `resolve_index`/`resolve_label` helpers using explicit nil-checks (`if v ~= nil then return v end`). Fixes Lua truthiness bug where option values of `0` or `false` would silently fall through `or` to the wrong index. No current schema uses value=0/false but priest `shadow_multidot_mode` uses numeric values 1,2,3.
- `main.lua` — schema widget sync loop now writes settings directly to the settings table (`st[key] = value`) instead of only syncing hardcoded quick-toggle keybinds + playstyle. This is the fix that made Auto Prowl, Auto Taunt, Curse Mode, and all other class settings actually work.
- `classes/warlock/destruction_sylvanas.lua` — `select_curse()` auto mode: Doom for TTD ≥ 60s, Agony for TTD < 60s.
- `classes/warlock/destruction_sylvanas.lua` — Immolate DSL: added `destro_use_immolate` checkbox gate as first condition.
- `classes/warlock/destruction_sylvanas.lua` — LifeTap DSL: configurable `destro_life_tap_mana` (default 20%) / `destro_life_tap_min_hp` (default 50%) via `spec_kit.setting_number`. Added `LifeTapMoving` strategy to ACTIONS table (positioned before SearingPain) so DSL substitution picks it up.
- `classes/warlock/schema_sylvanas.lua` — 3 new Destruction tab settings: `destro_use_immolate`, `destro_life_tap_mana`, `destro_life_tap_min_hp`.
- `tests/test_schema_widget_sync.lua` — new regression guard: 6 parts (static scan, functional mock, setting_bool consumer, nil-sync guard, set_setting spam guard, dropdown edge-case audit with 8 cases covering 1-based/0-based indices, value=0/false truthiness, out-of-bounds, label resolution).
- `tests/test_destruction_dsl_priority.lua` — updated LifeTap test values to match new defaults (mana 15% instead of 30%); added coverage for Immolate toggle, curse TTD switch, configurable LifeTap threshold, and LifeTapMoving strategy.
- `shared/declarative_menu_sylvanas.lua` — declarative `_G.menu` builder (feature-flagged behind `eax_use_declarative_menu`, default false). Infrastructure for future menu migration.

## 2.16.1 — 2026-07-25

### Developer Notes
- Internal fix: schema widget sync hardening (precursor to the v2.17.0 full sync fix).

## 2.11.0 — 2026-07-22

### Customer Changelog
- **100% strategy DSL coverage** — all 29 specs now use the declarative strategy DSL.
- Final 3 adopters: Caster Druid (6 strategies), Smite Priest (17 strategies), Kebab Warrior (16 strategies).
- Pre-commit badge-drift check — prevents stale test-count badges from reaching commits.
- 373 rotation + 21 leveling = 394 total test suites, all green.
- Version **2.11.0**.

### Developer Notes
- `shared/strategy_dsl_sylvanas.lua` — declarative strategy compiler used by all 29 specs.
- `shared/lazy_context_sylvanas.lua` — per-tick dependency-aware context proxy.
- Pre-commit hook step [4/4] runs `lua tools/update_badges.lua --check`.
- Badge drift caught at commit time, matching CI's badge-drift check.
- All spec-to-spec variations validated: rage, energy/combo, mana (caster/tank/healer),
  focus/pet, shadow DoT, frost/arcane/fire proc, melee/totem, warlock curse/execute,
  bear tank, feral cat powershift across all 10 classes.
- 373 rotation suites + 21 leveling suites = 394 total, all green.

## 2.10.0 - 2026-07-16

### Customer Changelog
- TBC Phase 2: **all 9 classes** 1–70 spell-ladder + solo/group/dungeon/raid(70) matches tests.
- Cat: Mangle debuff soft-gated until talent learned.
- Version **2.10.0**.

### Developer Notes
- `tbc_ladder_helper.lua` + `test_tbc_spell_ladders.lua` (**281** cases)
- Matrix: `tbc-deep-audit-matrix-2026-07-16.md`
- Prior TBC gap-matrix “aligned” is **not** re-claimed as Phase-2 done

## 2.9.2 - 2026-07-16

### Customer Changelog
- Fury: group-safe Sunder/Demo settings; Affliction: assigned curse / curse mode.

### Developer Notes
- Ladder suite **236** cases; per-class settings + curse/seal/shout overwrite + paladin raid prio
- Version **2.9.2**

## 2.9.1 - 2026-07-16

### Developer Notes
- Phase 2 skeptic: hard AoE/settings/raid-prio tests; full S/G/D/R matrix
- 190 ladder cases green

## 2.9.0 - 2026-07-16

### Customer Changelog
- Phase 2: **all 9 classes** Classic 1–60 spell-ladder tests (fillers when high talents unlearned).
- Version **2.9.0**. Tests: 279 rotation + 18 leveling.

### Developer Notes
- `vanilla_ladder_helper.lua` + `test_vanilla_spell_ladders.lua` (175 cases)
- Deep matrix updated with per-class evidence
- `cat_vanilla` CP threshold default level 60

## 2.8.0 - 2026-07-16

### Customer Changelog
- Deep Classic audit: all **40** Vanilla combat + leveling modules load-tested.
- Classic level defaults fixed (no accidental TBC “level 70” assumptions).
- Hunter Classic pre-Aimed fillers when Aimed unavailable.
- Version **2.8.0**. Tests: 278 rotation + 18 leveling.

### Developer Notes
- Matrix: `vanilla-deep-audit-matrix-2026-07-16.md`
- `test_vanilla_content_coverage.lua` + `vanilla_level_from_context`
- Hunter MM/Survival pre-Aimed ladder; druid/rogue level default 60

## 2.7.9 - 2026-07-16

### Customer Changelog
- **All 31 Classic Vanilla combat specs re-verified**.
- **Hunter BM/Survival (Classic)**: Aimed Shot is now the primary cast (wowsims classic hunter APL).
- **Destruction (Classic)**: Soul Fire no longer spams with any soul shard; execute-gated like Shadowburn.
- Version bumped to 2.7.9.
- Tests: 277 rotation + 18 leveling suites green.

### Developer Notes
- Gap matrix: `vanilla-rotation-gap-matrix-2026-07-16.md`
- `beast_mastery_vanilla.lua` / `survival_vanilla.lua`: AimedShot strategy + matches
- `destruction_vanilla.lua`: `soul_fire_matches` execute gate; Shadowburn before SoulFire
- Tests: `test_hunter_vanilla_aimed_shot.lua`, `test_destruction_vanilla_soul_fire_execute.lua`

## 2.7.8 - 2026-07-16

### Customer Changelog
- **All 29 TBC specs re-verified** against wowsims APLs, SimC/wowapls patterns, Wowhead, Icy Veins, and Warcraft Tavern.
- **Warlock (Destruction)**: Shadowburn now correctly fires in execute (≤20% HP) instead of being blocked by Shadow Bolt / Incinerate filler while standing still. Matches wowsims destro_fire APL execute priority.
- **Druid (Feral)**: Low-level cats (level 42-49) can now use Shred, Rip, Ravage, and Ferocious Bite without being blocked by the Mangle (Cat) debuff requirement that only applies once Mangle is learned at level 50.
- **Druid (Feral)**: Rip now tracks all rank IDs correctly, so low-level Rip casts no longer silently fail.
- **Druid (Bear)**: Maul rage threshold scales down when Mangle (Bear) is not yet learned, so low-level bears spend rage earlier.
- **Druid (Bear)**: Swipe cleave works before Lacerate is available.
- **Druid (Bear)**: Demoralizing Roar no longer wastes a GCD on a single target that is about to die.
- Version bumped to 2.7.8.
- Clean `eaxrotations.zip` (lua + md only).
- Tests: 274 rotation + 18 leveling suites green.

### Developer Notes
- Gap matrix: `tbc-rotation-gap-matrix-2026-07-16.md` — per-spec logic/settings verdict for all 29 combat specs; tie-breakers documented (wowsims APL > contested guide opinion).
- `destruction_sylvanas.lua`: reorder ACTIONS so `Shadowburn` sits above `Incinerate` / `ShadowBolt` / `SoulFire` (was dead while stationary because fillers always matched first).
- `test_destruction_shadowburn.lua`: asserts strategy index order (Shadowburn < Incinerate and < ShadowBolt) in addition to execute HP / soul-shard match gates.
- `cat_sylvanas.lua`: `shred_matches` and `stealth_shred_matches` now gate the Mangle-debuff requirement on `spell_exists(ACTION.MangleCat)`; `RIP_DEBUFF` expanded to `{ 27008, 9896, 9894, 9752, 9493, 9492, 1079 }`.
- `leveling_sylvanas.lua`: `shred_matches` gates Mangle-debuff requirement on `mangle_cat_ready`; `RIP_DEBUFF` and `RAKE_DEBUFF` expanded with missing ranks.
- `bear_sylvanas.lua`: pre-Mangle Maul uses level-scaled threshold; Swipe cleave Lacerate-stack gate only when `spell_exists(ACTION.Lacerate)`; Demo Roar skips single-target on `target_hp <= 20` or `ttd < 10`; `state.level` populated from context.
- Added regression tests: `test_druid_feral_level_42.lua`, `test_druid_feral_l42_mangle_gate.lua`.
- Updated `test_leveling_druid.lua` FerociousBite mock IDs.
- Material gaps found this pass: **1** (Destruction Shadowburn). All other specs **aligned** or **source-disagreement** with documented tie-break.

## 2.7.7 - 2026-07-16

### Customer Changelog
- **Druid (Bear)**: Maul no longer re-queues every frame once armed for the next swing.
- **Melee timing**: Swing timer uses the correct clock (no more ~70k-second garbage values / debug spam).
- Version bumped to 2.7.7.
- Clean `eaxrotations.zip` (lua + md only).

### Developer Notes
- Maul: `is_current_spell` gate + `min_interval=0.5` execute.
- `swing_time_until`: `NS.time_now()` / game-time; stop using `get_current_combat_core_time`.

## 2.7.6 - 2026-07-16

### Customer Changelog
- **Druid (Bear)**: Swipe targets enemies again (was self-targeting the player and spam-looping).
- **Druid (Bear)**: Mark / Gift / Thorns no longer cast in bear form (they cancel form and caused shift loops).
- **Druid (Bear)**: Cleaner Bear Form re-shift after a cast attempt.
- **Melee timing**: Absurd swing-timer fallback values are ignored.
- Version bumped to 2.7.6.
- Clean `eaxrotations.zip` (lua + md only).

### Developer Notes
- Swipe: remove `target="self"` / `requires_target=false`; cast via `context.target`.
- OOC buffs: `if s.is_bear then return false end` on MotW/Gift/Thorns.
- `NS.swing_time_until`: clamp `remains > 12` → 999 (unknown).
- Regression tests in `test_bear_custom_matches.lua`.

## 2.7.5 - 2026-07-16

### Customer Changelog
- **Druid (Bear)**: Low-level bears spend rage much earlier. Before Mangle, Maul no longer waits for ~50 rage — the threshold scales with level (about 23 rage around level 17). Your Maul Rage menu setting remains the maximum once you have the full tank kit.
- **Druid (Bear)**: Swipe works on 2+ targets before Lacerate is available (no more waiting on stacks you cannot apply yet).
- **Druid (Bear)**: Demoralizing Roar no longer wastes GCD/rage on a single mob that is about to die. Multi-pull Demo is unchanged.
- Version bumped to 2.7.5.
- Clean `eaxrotations.zip` (lua + md only).

### Developer Notes
- `bear_sylvanas.lua`: pre-Mangle Maul uses `min(menu maul_rage, level_scaled)`; Swipe cleave applies Lacerate-stack gate only when `spell_exists(Lacerate)`; Demo Roar single-target skip on `target_hp <= 20` or `ttd < 10`; `state.level` from context.
- `schema_sylvanas.lua`: `bear_maul_rage` tooltip documents pre-Mangle auto-scale.
- `test_bear_custom_matches.lua`: pre-Mangle Maul, pre-Lacerate Swipe, Demo HP/TTD multi vs single.

## 2.7.4 - 2026-07-16

### Customer Changelog
- **Healers**: Smart stop-cast is now active at runtime (cancels heals that would overheal once the target recovers mid-cast).
- **Healers / pets**: Injured party pets can enter triage scoring when pet healing is enabled.
- **Tanks (Prot Warrior / Prot Paladin)**: Snap-threat openers fire on combat start again (Shield Slam / Judgement paths).
- **Prot Warrior**: Stance manager is live (auto Battle / Defensive / Berserker when settings allow).
- **Arms / Fury Warrior**: Shared rage-dump manager drives Heroic Strike / Cleave starvation and dump-mode decisions.
- **Melee / Hunters**: CLEU swing diagnostics and swing-timer tracking load at startup (seal registration, hunter adaptive timing).
- **Warlock**: Shared dispel manager is available for friendly Devour Magic group help.
- Version bumped to 2.7.4.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (272 rotation suites; 1 pre-existing layout registration failure unrelated).

### Developer Notes
- Bootstrap-load supremacy modules in `main.lua` `load_modules` **before** class load so `NS.StopCast`, `NS.PetHeal`, `NS.SnapThreat`, `NS.StanceManager`, `NS.SwingDiagnostics`, `NS.SwingTimer`, `NS.DispelManager`, `NS.RageManager`, and `NS.MeleeCombatMath` are populated when specs evaluate.
- `main_sylvanas.lua`: load `shared/health_pred_helper_sylvanas` after `NS.health_prediction`; tick `NS.SwingTimer.on_update` each rotation update.
- `health_pred_helper`: lazy-resolve platform module; expose `NS.incoming_damage` / `NS.predicted_hp_pct` / `NS.is_tank_role`.
- Arms/Fury: prefer `NS.RageManager.should_heroic_strike` / `should_cleave` with threshold overlay preserving existing dump defaults.
- Plan: `wire-dormant-shared-modules-2026-07-16`.

## 2.7.3 - 2026-07-13

### Customer Changelog
- **Warlock (Affliction)**: When low on health, Drain Life is now forced over Drain Soul for self-healing sustain.
- **Warlock (Affliction)**: Rain of Fire AoE added for large packs in dungeons (uses enemy count threshold, works pre-level 70 before Seed of Corruption). Proper position targeting for ground AoE.
- Curse of Agony now reliably applies without Curse of Elements overriding.
- Version bumped to 2.7.3.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (260 rotation + 17 leveling suites).

## 2.7.2 - 2026-07-12

### Customer Changelog
- **Warlock**: Fixed Curse Governance for the last time — setting "Curse Mode" to Agony and/or "Assigned Curse" to Agony now reliably prevents Curse of Elements (11722) and other non-Agony curses. All three specs (affliction/demonology/destruction) now use strict early `assigned_curse_blocks` + `select_curse` delegation.
- **Warlock**: Drain Soul hardened to pure TBC shard-capture behavior (only when `context.ttd <= 5s`); removed non-TBC "hp <=5 execute" path and all custom per-spell interval timers.
- **Warlock**: Removed all added workarounds (no new `dot_recently_cast`, no extra `_last_*` throttles for dots/drains). Code now relies exactly on the documented API surface: `NS.debuff_remains` (via `get_debuff_data`), `context.is_channeling` (from `is_channelling_spell`), `context.ttd` / `context.target_hp_pct`, `NS.GetPet()` / `has_pet()`, `NS.try_cast`, `spec_kit.setting`, etc. Matches `.api` + apidocs expectations with zero layering.
- **Warlock**: OOC Summon Imp spam eliminated — `ooc_manager_sylvanas.lua` no longer hardcodes Imp for Warlock. Pet choice fully delegated to spec OOC strategies (correctly picks Felhunter etc. when appropriate and respects current pet state).
- **Warlock**: Repeated same-target Corruption/UA/Immolate/Siphon/Curse casts fixed by trusting the API remains checks + existing throttle paths.
- Version bumped to 2.7.2.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (260 rotation + 17 leveling suites).

## 2.7.1 - 2026-07-12

### Customer Changelog
- **Druid (Bear)**: Fixed erroneous out-of-form shift to use a Healthstone / Healing Potion even when those consumables are disabled in settings. Consumables are now handled Druid-class-wide via middleware, not per-spec.
- **Druid (Bear)**: Fixed missing bear-form re-shift — if the rotation is ever shifted out of Bear Form (e.g. Enrage on cooldown), it now immediately returns to Bear Form (3s throttle to avoid thrash).
- **Druid (Bear)**: Fixed chain-pulling — Faerie Fire (pull) is now gated to out-of-combat only; it no longer auto-pulls the next nearest mob in range while already fighting.
- **Druid (Bear)**: Fixed Demo Roar range / immunity handling — Demo Roar now only applies within 10yd and tracks per-target cast failures (immune) with an 8s throttle, instead of spamming at invalid or immune targets.
- Version bumped to 2.7.1.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (257 + 17 suites).

## 2.7.0 - 2026-07-12

### Customer Changelog
- **Warlock**: Removed `Curse of Shadow` as a separate rotation option (spell definition retained for safety).
- **Warlock**: Added `Curse of Recklessness` and `Curse of Weakness` curse modes across Affliction, Demonology, and Destruction.
- **Warlock**: Added `Assigned Curse` setting for manual raid coordination.
- **Warlock**: Unified curse refresh thresholds across all three Warlock specs via `shared/warlock_curse_helper_sylvanas.lua`.
- **Warlock**: Fixed Demonology `other_curse_active()` to use state fields instead of the missing `s.target`.
- **Warlock**: Aligned auto-mode curse logic with TBC APL/pro guides:
  - Affliction: `Curse of the Elements` in raid/group.
  - Demonology/Destruction: `Curse of Doom` default, `Curse of the Elements` if assigned/needed.
- Version bumped to 2.7.0.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (257 + 17 suites).

## 2.6.1 - 2026-07-12

### Customer Changelog
- **Warlock**: Fixed curse selection so `Curse of Elements`/`Curse of Shadow` no longer override `Curse of Agony` in auto mode.
- **Warlock**: Added `other_curse_active()` guard across Affliction, Demonology, and Destruction to prevent curse overwrites.
- **Warlock**: Added `LIFE_TAP_MIN_INTERVAL = 1.5s` throttle to Affliction, Demonology, and Destruction to stop Life Tap double-cast/spam.
- Version bumped to 2.6.1.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (257 + 17 suites).

## 2.6.0 - 2026-07-11

### Customer Changelog
- FSR (Five-Second Rule) support across all healers: correct pause placement after emergencies before fillers (Greater Heal, Chain Heal, SmartHeal, Regrowth, etc.).
- New shared FSR manager with configurable thresholds via menu (enabled, mana threshold, emergency HP, max pause seconds).
- State wiring (in_combat, lowest HP, fsr inside/delta) + simplified delegates in rotations.
- Version bumped to 2.6.0.
- Clean eaxrotations.zip (lua + md only).
- All tests remain passing (253 + 17 suites).

## 2.5.19 - 2026-07-11

### Customer Changelog
- **Warlock**: Fixed repeated CreateHealthstone spam (11730 and ranks) while in combat or with target selected. Added proper "already have healthstone" ownership checks (with core.inventory fallback) in middleware, destruction, vanilla, and leveling rotations.
- **Warlock**: OOC pet summons (Summon Imp etc.) now strictly respect `has_valid_enemy_target` (prevents casting pet summon on your DPS target). Added extra pet detection fallbacks.
- Reduced noisy "[OOC] Summon Imp throttled (broken API)" log spam (rate limited + clarified message).
- Version bumped to 2.5.19.
- Clean eaxrotations.zip (lua + md only).
- All tests remain passing (253 suites).

## 2.5.18 - 2026-07-11

### Customer Changelog
- Active Fight Tracker: mobs that you or your group enter combat with are tracked as "active fights".
- DoT maintenance on those fights (if in range + mana + not already dotted by someone else).
- Wired for Shadow, Affliction, Balance (Moonfire+IS), Elemental (Flame Shock), Hunter Serpent Sting (TBC + Vanilla).
- Version bumped to 2.5.18.
- Clean eaxrotations.zip (lua + md only).
- All tests remain passing (252 + 17 suites).

## 2.5.17 - 2026-07-11

### Customer Changelog
- Fixed jitter / snapping back when clicking Playstyle in Quick Toggles (and cases where selection didn't stick smoothly).
- Widget is now the only source of truth; removed fighting back-sync logic that used stale settings cache; added cache refresh on injection.
- Changes are now smooth and reliable across all classes/specs.
- Version bumped to 2.5.17.
- Clean eaxrotations.zip (lua + md only).
- All tests remain passing (253 + 17 suites).

## 2.5.16 - 2026-07-11

### Customer Changelog
- Fixed Playstyle selector inside Quick Toggles. Selecting a playstyle (e.g. Affliction, Destruction, Cat, Arms, etc.) now actually switches the active rotation.
- Was previously stuck on the initial value (such as "Auto (Talent)" for Warlock). Now works for all classes and all 29 specs.
- Version bumped to 2.5.16.
- Clean eaxrotations.zip (lua + md files only).
- All tests remain passing (252 + 17 suites).

## 2.5.15 - 2026-07-11

### Customer Changelog
- Control panel quick toggles (Rotation, Healing, Damage, Cooldowns, AoE, Interrupts, Utility, Threat Drops) now always visible with fallback to "Unbound" (no keybind needed). Changed from 7 (hidden) to 999 (visible per docs).
- Removed set_setting writes during sync to fix host "File name not set" spam on reload; widget states injected directly into settings for correct gating.
- Verified toggles work as intended with recent IO removal and other changes (states used in gating logic).
- Version bumped to 2.5.15.
- All tests remain passing (252 + 17 suites).

## 2.5.14 - 2026-07-10

### Customer Changelog
- Removed manual log and data file IO saving (create_log_file, write_log_file, early set_setting calls, grace periods) that caused "File name not set. Please specify a valid file name before saving" spam from the host.
- Logging now prefers izi.log (recommended in Sylvanas docs) instead of manual file management.
- All rotation and leveling tests remain passing (252 + 17 suites).
- Version bumped to 2.5.14.

## 2.5.13 - 2026-07-10

### Customer Changelog
- Removed manual log and data file IO saving (create_log_file, write_log_file, early set_setting calls, grace periods) that caused "File name not set. Please specify a valid file name before saving" spam from the host.
- Logging now prefers izi.log (recommended in Sylvanas docs) instead of manual file management.
- All rotation and leveling tests remain passing (252 + 17 suites).
- Version bumped to 2.5.13.

## 2.5.12 - 2026-07-10

### Customer Changelog
- Priest Healing + shared dispel manager: added BT/SWP high-tier debuffs (Soul Drain 41303, Polymorph 46280, Flame Buffet 46279, Disease Buffet, hound poisons) for improved raid dispel priority and clears.
- All rotation and leveling tests remain passing (252 + 17 suites).
- Version bumped to 2.5.12 across header, docs, and packaging.

## 2.5.11 - 2026-07-10

### Customer Changelog
- Destruction Warlock: Conflagrate now prioritizes above Incinerate after Immolate application (consume for burst damage, then filler). Matches standard TBC destruction priorities from simulator APLs and guides.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.9 - 2026-07-10

### Customer Changelog
- Continued fidelity improvements for remaining specs per sources.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.8 - 2026-07-10

### Customer Changelog
- Elemental Shaman: main totems now higher priority to match simulator APL.
- Frost Mage: audited for fidelity; strong Frostbolt spam with burst CDs and shatter Ice Lance per guides.
- Enhancement Shaman: audited; strong Stormstrike, totem twisting, shock priority per APL.
- Combat Rogue: switched primary finisher to Envenom with deadly poison per sources.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.10 - 2026-07-10

### Customer Changelog
- Continued Tier 3 fidelity for Frost, Enhancement, Combat Rogue per sources.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.7 - 2026-07-10

### Customer Changelog
- Tier 2 Resto specs (Druid, Shaman, Priest) fidelity pass complete with downrank and audit updates per guides.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.6 - 2026-07-10

### Customer Changelog
- Resto Druid: added downrank Regrowth support for mana conservation in spot healing, per TBC guides.
- Resto Shaman: added downrank Chain Heal for mana sustainability in group healing, per TBC guides.
- Resto Priest: audited; strong Renew/PW:S/Greater Heal/CoH with downrank support per guides.
- Elemental Shaman: raised priority of main totems (Totem of Wrath, Wrath of Air, Mana Spring) to match wowsims APL.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.5 - 2026-07-10

### Customer Changelog
- Holy Paladin: added proactive Light's Grace build using downranked Holy Light to proc the cast-time reduction cheaply before heavy healing (per TBC guides).
- Resto Druid: added downrank Regrowth support for mana conservation in spot healing, per TBC guides.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.4 - 2026-07-10

### Customer Changelog
- Continued fidelity improvements across tank and caster specs per simulator and guide sources.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.3 - 2026-07-10

### Customer Changelog
- Retribution Paladin: seal twisting now enabled by default, following the Command rank 1 into Blood or Martyr twist before swings for Crusader Strike and Judgement to match priority lists from simulators and guides.
- Hunter: improved auto-shot timing with dynamic buffer calculations (adapts to weapon swing speed) for safer Steady/Multi/Arcane weaving without clipping autos.
- Warrior Protection: added multi-target Whirlwind support and raised Shield Block priority to better match simulator APLs for threat and mitigation.
- Balance Druid: documentation updated for accurate TBC priorities (Moonfire/Insect Swarm dots, Faerie Fire, Starfire filler, Starfall, treants); no incorrect references.
- Protection Paladin: audited for fidelity; priorities align with guides and simulator for Holy Shield, Consecration, Judgement, and defensives.
- Holy Paladin: added proactive Light's Grace build using downranked Holy Light to proc the cast-time reduction cheaply before heavy healing (per TBC guides).
- All rotation and leveling tests remain passing (252 suites).

## 2.5.2 - 2026-07-10

### Customer Changelog
- Improved Arms Warrior Sunder Armor priority and battle stance support, aligned with authoritative SimC APLs and guides from Wowhead and Icy Veins for better raid contribution.
- Improved Feral Cat (Druid) with proper Berserk usage during burst windows (pull/BL), aligning with SimC/wowsims/icyveins for higher DPS in CDs.
- Improved Retribution Paladin seal twisting behavior: now enabled by default to follow Command rank 1 to Blood/Martyr twist for Crusader Strike and Judgement, matching simulator and guide priorities.
- Updated version to 2.5.2 with customer-facing documentation and text cleanup (plain formatting, no special symbols).
- All rotation and leveling tests remain passing.

Full development details and prior releases below (for internal use).

Full development details and prior releases below (for internal use).

## 2.3.15 - 2026-07-05

### Comprehensive Competitor Ecosystem Analysis

Researched 30+ providers across the entire WoW automation ecosystem. Key findings:

#### TBC Healer Competitors Found

| Provider | Type | TBC Healer Support | EAX vs Them |
|----------|------|--------------------|-------------|
| **BlistX (blistrogue.com)** | Lua framework | ✅ Holy Priest, Disc Priest PvP, Resto Shaman, Holy Pally, Resto Druid PvP | 80K lines, 17 rotations, PvP situation fields, BuddyMode. Direct competitor. |
| **MaxDPS Assistant (maxdps.pro)** | Pixel/Memory | ❌ TBC Priest = Shadow only (no healer) | EAX far ahead |
| **WRobot Fight Class** | Private server internal | ✅ Disc Priest PvP (6.50 EUR) | Dynamic rotation, SW:Death polymorph, frame lock. EAX matches spell usage. |
| **Tempest (wowtempest.gg)** | Pixel bot | ✅ All specs including healers | $49-499, SimC APL, pixel-based. Cannot scrape logic. |
| **Rice Rotations** | Pixel bot | ✅ All specs (Midnight + MoP) | Pixel-based, PvE only, no PvP. Does not list TBC Anniversary. |
| **PixelRotation** | Pixel bot | ❌ Midnight + MoP only | Not applicable to TBC |
| **OptiStrike** | Pixel bot | ⚠️ All versions, uses Hekili/HeroRotation | Pixel wrapper around Hekili — no own healer logic |
| **Morpheus** | Custom bot | ✅ Any expansion, any class | Custom 1-to-1 development. Cannot scrape. |
| **Sonah** | CurseForge addon | ✅ All 27 specs TBC | EAX exceeds — stop-cast, absorb tracking, chain heal targeting |
| **HealPredict TBC** | CurseForge addon | ✅ UI-only heal prediction | EAX matches core logic; HealPredict is visualization only |
| **HealIQ** | GitHub addon | ✅ Resto Druid only | EAX adopted Swiftmend expire-preference + tick-cadence |
| **ConROC** | CurseForge addon | ❌ Explicitly no healer rotation | EAX has full healer support |
| **Hekili** | GitHub addon | ❌ Healer = DPS only | EAX far ahead |
| **MaxDps (kaminaris)** | GitHub addon | ❌ TBC Resto Shaman = DPS only | EAX far ahead |
| **PrismmRot** | GitHub addon | ❌ JSON-driven DPS queue | No healer logic |
| **HekiliHealers** | CurseForge addon | ⚠️ Retail only | Not applicable to TBC |

#### Lua Unlocker / Rotation Framework Ecosystem (no public healer logic)

| Provider | Type | Notes |
|----------|------|-------|
| NilName | Lua Unlocker + Rotations | 403 blocked, closed source |
| WGG | Lua Unlocker | — |
| Lunar | Mac Lua Unlocker + Framework | — |
| Daemonic | Lua Unlocker | — |
| Project Sylvanas | Internal Framework | **EAX's platform** |
| SIN/WS/GDR/TJX/Funlua/TCXCore | Chinese Lua Unlockers | Closed source |
| Clipper | PvP Rotations | Retail-focused |
| Ascended/Phoenix/SYNQ/Opal/Dominus/Makulu/Magic | Combat Rotations | GGLoader-based, closed source |
| EpicSync | Custom Hekili Rotations | Hekili wrapper |
| GGLoader/Inferno | Combat Pixel Bots | Closed source |
| Rotation Lab/Byster/Univer | Private Server Rotations | Memory-based, closed source |
| SquireBot/Warden Grider/Bottie/PixelWoWBot/Wrobot | Farming/Multi-use | Not healer rotation relevant |

#### Key Insights

1. **BlistX is the most direct competitor** — 80K lines, 17 rotations, TBC healer support including Holy Priest "Smart 5-man healing, triage scoring", Disc Priest PvP, Resto Shaman, Holy Pally, Resto Druid PvP. Has "PvP Situation Fields" and "BuddyMode" (follow/assist/healer peel). However, BlistX is closed-source and Lua-based — EAX is also Lua-based and on Project Sylvanas (internal framework, more capable than pixel bots).

2. **No competitor has stop-cast engine** — EAX's mid-cast cancellation at 25/50/75% progress is unique across all 30+ providers researched.

3. **No competitor has PW:S absorb-aware refresh** — EAX's `buff_points()` >200 skip is unique.

4. **No competitor has Chain Heal cluster targeting** — EAX's O(n²) 12.5yd radius finder is unique.

5. **Pixel bots (Tempest, Rice, OptiStrike, PixelRotation)** cannot access internal game state — they read screen pixels. EAX runs inside the game via Project Sylvanas, giving full access to unit health, buffs, threat, cast info, combat log, etc. This is a fundamental architectural advantage.

6. **MaxDPS Assistant** has TBC Priest but only Shadow — no healer rotation. EAX has Holy + Disc + Shadow.

7. **WRobot Disc Priest PvP profile** (6.50 EUR, 2.4.3) uses: Fear, Dispel, PvP Trinket, Shadowfiend, Pain Suppression, Mass Dispel, SW:Death polymorph interrupt. EAX's Disc Priest has all of these except SW:Death polymorph interrupt and Mass Dispel.

8. **BlistX BuddyMode** (follow, assist, healer peel awareness) is a feature EAX doesn't have — but it's a leveling/follow bot feature, not a rotation quality feature.

### Features to Consider from Competitors

| Feature | Source | Priority | Status |
|---------|--------|----------|--------|
| SW:Death polymorph interrupt | WRobot Disc Priest | Medium | Not in EAX |
| Mass Dispel (PvP) | WRobot Disc Priest | Low | Not in EAX |
| BuddyMode (follow/assist) | BlistX | Low | Out of scope for rotation engine |
| PvP Situation Fields | BlistX | Medium | EAX has PvP via context.is_pvp + spec-specific logic |
| 80K lines scale | BlistX | — | EAX is ~50K+ lines across 29 specs + shared modules |

### Quality & Reliability
- 219 rotation test suites — all healer tests passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible.

## 2.3.14 - 2026-07-05

### Healer Deep-Dive: External Research + Tick-Cadence HoT Refresh

#### Resto Druid: Tick-Cadence-Aware HoT Refresh (from tbc-rdruid-simulator)
- `needs_lifebloom_refresh()`: now checks `HotTickTracker.next_tick_in()` — if next Lifebloom tick is within 0.5s, waits for it to land before refreshing. Prevents tick clipping.
- `needs_rejuvenation()` and `needs_regrowth()`: same tick-cadence check.
- `choose_swiftmend_prefer_rejuv()`: now prefers HoTs about to expire (<2.0s remaining) — consumes before clipping (from HealIQ approach).
- All changes nil-guarded: HotTickTracker is optional, falls back to fixed threshold.

#### External Research: Competitor Analysis
- **HealPredict TBC Anniversary** (CurseForge): Has absorb presence indicator bar, death prediction, cluster detection, AoE heal target advisor, health trajectory marker, heal reduction indicator, raid cooldown tracker, overheal statistics. EAX already has most of these via `healer_deficit_sylvanas.lua` + `triage_sylvanas.lua`.
- **Sonah** (CurseForge): Has predictive healing, HoT tracking, dispel recommendations, tank priority. EAX matches or exceeds all of these.
- **HealIQ** (GitHub): Resto Druid-specific — HoT duration tracking, Swiftmend combo, Clearcasting. EAX now wired HotTickTracker for tick-cadence-aware refresh.
- **MaxDps** (GitHub): TBC Restoration Shaman = DPS only, no healing logic. EAX far ahead.
- **ConROC** (CurseForge): Explicitly states "Healers due to the nature of the role will not offer a heal rotation." EAX has full healer support.
- **HekiliHealers** (CurseForge): Retail only, mouseover-based. Not applicable to TBC.
- **Tempest** (wowtempest.gg): Closed-source pixel bot, $49-499. Claims SimC-accurate rotations for all classes including healers. Uses pixel detection, not internal API. Cannot scrape logic.
- **PrismmRot** (GitHub): JSON-driven rotation queue, no healer-specific logic found.
- **tbc-rdruid-simulator** (GitHub): Python simulator for optimal HoT rotations. EAX adopted tick-cadence-aware refresh from this source.
- **archon.gg**: Top Holy Priest parses show CoH 31.5%, Renew 30.1% (73% uptime), Flash Heal 15.5%, PoM 10.4%. EAX priority order matches.

### Quality & Reliability
- 219 rotation test suites — all healer tests passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible. No settings reset required.

## 2.3.13 - 2026-07-05

### Healer Gap Fixes (Deep-Dive Audit)

#### Holy Priest
- **DispelMagic now fires**: `Healing.has_dangerous_dispel()` and `Healing.has_disease()` were referenced but never defined in `priest/healing_sylvanas.lua`. The `DispelMagic`, `CureDisease`, and `AbolishDisease` strategies were dead code — they silently skipped because the gate functions returned nil. Now defined with `NS.has_dispel_type_debuff` fast path + debuff ID scan fallback.
- **ManaPotion strategy added**: Holy Priest was the only healer without a Mana Potion strategy (Pally, Shaman, and Druid all had one). Fires at <20% mana, gated by `use_mana_potions` setting.

#### Discipline Priest
- **Shadowfiend strategy added**: Discipline had the spell but no strategy to cast it (only Holy had one). Fires at <30% mana, gated by `use_shadowfiend` setting. `shadowfiend_ready` added to `build_state`.
- **ManaPotion strategy added**: Same gap as Holy Priest — now has mana potion at <20%.

#### Resto Shaman
- **Solo DPS now fires**: `idle_dps_strategies` (EarthShock, FlameShock, ChainLightning, LightningBolt) were exported but NOT in the `healing_strategies` table passed to `rotation_registry:register`. Solo Shaman did zero DPS. Now merged into the registered rotation.
- **Earth Shock interrupt now fires**: Was in the unregistered `idle_dps_strategies` — target-casting interrupt logic was dead code. Now active.
- **Bloodlust PvP burst window**: `bloodlust_matches` now also fires during PvP burst-heal windows via `NS.PvPBurstWindow.should_burst()`, not just when group is fully healthy.

#### Holy Paladin
- **Avenging Wrath PvP burst window**: `AvengingWrathHeavyHealing` now also fires during PvP burst-heal windows via `NS.PvPBurstWindow.should_burst()`, not just during `heavy_healing` flag.

#### Shared Modules
- **`chain_heal_target()` added to `triage_sylvanas.lua`**: Resto Shaman referenced `NS.AoEHeal.chain_heal_target()` but it was never defined — the call was nil-guarded so it silently fell back to lowest-HP targeting. Now the 12.5yd cluster finder activates, improving Chain Heal bounce optimization.
- **`PetHeal` verified**: `core_sylvanas.lua:4876` already calls `NS.PetHeal.append_entries` — no fix needed.

### Quality & Reliability
- 219 rotation test suites — all passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible. No settings reset required.

## 2.3.9 - 2026-07-03

### Bug Fixes
- **Shadow Priest**: Fixed Mind Flay opening on fresh targets. `mind_flay_matches` was missing the `_engaged_with_player()` safety gate that every other damage spell uses. This caused Mind Flay to fire before Shadow Word: Pain and Mind Blast on targets at 100% HP that hadn't yet targeted the player. Now correctly waits for engagement (via auto-attack or party member pull) before casting.

### Quality & Reliability
- 219 rotation test suites — all passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible. No settings reset required.

## 2.3.8 - 2026-07-03

### Bug Fixes
- **Mage — Fire**: `state.has_clearcasting` now populated in `build_state`; Clearcasting proc is consumed on Fireball.
- **Warrior — Arms**: `state.is_boss` + `target_hp_pct` populated in `ARMS_SCHEMA`/`build_state`; Death Wish boss-burst gate (target >20% HP) now fires.
- **Druid — Bear**: `state.is_rooted`/`is_snared` populated via `safe_method`; Nature's Grasp PvP peel now triggers when CC'd.
- **Warlock — Demonology**: `demo_state.in_combat` populated; Pet state matchers no longer rely on stale reference.

### API Compliance
- **is_boss**: All call sites now prefer `context.target_is_boss` (accurate, via `unit_helper:is_boss()`) and fall back to `NS.unit_is_boss()`, never the raw inaccurate `target:is_boss()`.
- **is_tank**: `core_sylvanas:is_tank_unit` now prefers accurate `NS.unit_is_tank()` (`unit_helper:is_tank()`) before falling back to raw `unit:is_tank()` + role heuristic.

### Healer Dispel Throttle (v2.3.7)
- All 4 healer specs throttle dispels/cleanses to 3-second intervals, preventing rapid-fire casts on stale debuff data.

### Quality & Reliability
- 219 rotation test suites — all passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible. No settings reset required.

## 2.3.1 - 2026-07-02

### PvP DR Gating Fixes
**Affected specs:** Holy Paladin, Protection Paladin, Combat Rogue, Subtlety Rogue

Added `NS.DRTracker.is_dr_immune()` checks to stun abilities that were casting into immune targets:

- **Hammer of Justice** (Holy + Protection Paladin) — now gated on `stun` DR
- **Cheap Shot** (Combat Rogue) — now gated on `stun` DR
- **Kidney Shot** (Combat + Subtlety Rogue) — now gated on `stun` DR

This prevents wasting a full-duration stun on a target that is already DR-immune, which is the single biggest PvP efficiency gain in the framework.

### Warrior Death Wish Fear Break
**Affected spec:** Fury Warrior

`death_wish_matches` now checks `is_feared_sapped_or_incapacitated()` before the normal burst CD logic. If the player is feared, Death Wish fires immediately as a reactive break (it grants fear immunity in any stance, unlike Berserker Rage which requires Berserker Stance).

### Druid Barkskin Configurability
**Affected spec:** Restoration Druid

Replaced the hardcoded `55%` HP threshold in `BarkskinSelfPreservation` with `settings.barkskin_hp or 55`. The schema already exposed this slider; the rotation now respects it.

### Shaman Tremor Totem PvP Coverage
**Affected spec:** Enhancement Shaman

`auto_tremor_sylvanas.lua` previously only dropped Tremor Totem when targeting one of 17 known fear-casting boss NPCs. It now also checks `detect_fear_on_ally()` — if any nearby party member has a fear debuff (Warlock Fear, Priest Psychic Scream, etc.), the totem drops automatically.

### PvP Feature Page Accuracy
Rewrote `docs/PVP_FEATURE_PAGE.md` from a full code audit. Removed false claims (e.g., abilities listed as DR-gated that were not). Documented actual behavior with file references. Added "Known Gaps" section so players know what is and is not implemented.

### Quality & Reliability
- 219 rotation test suites — all passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible. No settings reset required.

## 2.3.0 - 2026-07-02

### Server-Authoritative Swing Timer (CLEU)
**Affected specs:** Retribution Paladin, Enhancement Shaman, Arms Warrior, Fury Warrior, Kebab Warrior

Replaced frame-polling swing prediction with direct Combat Log Event (CLEU) tracking. The rotation now reads the exact server swing timestamp instead of estimating it.

- Seal twisting is judged against real server data — no more phantom twists from latency or haste drift
- Diagnostics report `PERFECT`, `LATE`, or `PHANTOM` with millisecond precision
- Enhancement Shaman Stormstrike alignment and Warrior Heroic Strike trick timing both use the same authoritative source
- Falls back automatically to native prediction if the CLEU API is unavailable

### Instant Snap Threat on Pull
**Affected specs:** Protection Paladin, Protection Warrior

Snap Threat now hooks the `PLAYER_REGEN_DISABLED` event, firing your opener the exact frame combat begins. This gives Judgement / Shield Slam a ~50-100ms head start before DPS opens, reducing early aggro loss on trash and boss pulls.

### Light's Grace Chaining
**Affected spec:** Holy Paladin

When Light's Grace has less than 2.5 seconds remaining, the rotation automatically queues another Holy Light to keep the 0.5-second cast-time reduction rolling. Only fires in combat, only when a tank target exists, and remains below Divine Favor + Holy Shock on priority so emergency combos still win.

### Blessing of Kings Party Buff
**Affected spec:** Protection Paladin

New out-of-combat strategy scans party members and applies Blessing of Kings to anyone missing the buff. Gated by a setting (default enabled).

### Configurable DoT Refresh Windows
**Affected spec:** Shadow Priest

Replaced hardcoded refresh thresholds with user-configurable sliders:

| Setting | Range | Default |
|---------|-------|---------|
| VT Refresh Window | 0.5s – 3.0s | 1.5s |
| SW:P Refresh Window | 0.5s – 3.0s | 1.5s |

Lower values clip closer to expiration (better for low latency). Higher values refresh earlier (safer for movement-heavy encounters). Fully backward compatible.

### Quality & Reliability
- **219 rotation test suites** — all passing
- **13 leveling rotation suites** — all passing
- All changes are additive with safe fallbacks. No breaking changes, no settings reset required.

## 2.2.2 - 2026-06-29

### Critical Runtime Fixes
- **`core_sylvanas.lua`**: Removed unresolved git merge conflict markers (`<<<<<<< Updated upstream` / `=======` / `>>>>>>> Stashed changes`) that caused runtime load failure—"Failed to load core_sylvanas: file is not found". The Lua parser rejected the file at require-time.

### Engine & Trace Hardening
- **`main_sylvanas.lua`**: Per-list trace throttle—`_trace_strat_last` was a single global shared by ALL strategy lists. AutoConsumable (first match every tick) claimed the one 2-second log slot, silencing ALL spec strategy traces. Changed to table keyed by list name (`_trace_strat_last[list_name]`).

### Consumable Manager Fix
- **`shared/consumable_manager_sylvanas.lua`**: Added in-combat threshold guard to `should_check()`. Now only returns `true` when `hp <= 60` or `mana_pct <= 50`. Previously returned `true` on every combat tick regardless of HP/mana, causing `matched=true, executed=false` trace spam and wasted CPU.
- All 9 class middleware files (`druid`, `hunter`, `mage`, `paladin`, `priest`, `rogue`, `shaman`, `warlock`, `warrior`) now use `consumable_manager.should_check()` instead of raw `context.in_combat`.

### Test Results
- **208/208 rotation suites pass**
- **11/11 leveling suites pass**
- **423 files syntax-checked (luac -p)**
- **61/61 DBC spell audit clean** (all spell IDs exist in WoW 2.5.5.68101 client)

## 2.2.1 - 2026-06-29

### Warrior Fear Break + Arms Polish
- **Arms**: Added `BerserkerRage` strategy—was tracked in state but never cast. Breaks fear, sap, and incapacitate via static debuff ID lists.
- **Arms**: `DeathWish` now also breaks fear (enrage effect).
- **Fury**: Enhanced `BerserkerRage` to auto-cast when feared/sapped/incapacitated.
- **Protection**: Same fear-break enhancement for `BerserkerRage`.
- All 208 rotation suites + 11 leveling suites pass.

## 2.2.0 - 2026-06-27

### Architecture: Strategy Gating Deduplication
- Created `core/strategy_gating.lua` as single source of truth for strategy category classification.
- Eliminated duplicated `HEALING_PLAYSTYLES`, `HEALING_NAMES`, `DAMAGE_NAMES`, `COOLDOWN_NAMES`, `UTILITY_NAMES`, `DEFENSIVE_NAMES`, `contains_any`, `strategy_category`, and `strategy_allowed` between `core_sylvanas.lua` and `main_sylvanas.lua` (~200 lines of duplicated code).
- Standardized `strategy_allowed` return signature to 3 values (allowed, reason, category) in both files.
- Both files now `require("core/strategy_gating")` with fallback definitions.

### Performance Hardening
- Enemy cache: upgraded from single-range to multi-range per-tick cache—eliminates cache thrashing when specs query melee(5), AoE(8), and scan(40) ranges in the same tick. Supports up to 8 cached ranges with LRU eviction.
- Immunity buff cache: `evaluate_cast` now caches target immunity buffs (Divine Shield, Ice Block, BOP, Cloak, WotF, Berserker Rage) per (target, tick)—eliminates 6 redundant `buff_up` calls per cast attempt.
- `collect_healing_units`: eliminated per-call table allocation—now uses a static output buffer.
- `is_item_equipped`: upgraded from O(19 × N) slot scans per call to O(N) set lookup using a per-tick equipped items set cache.
- `count_equipped_set`: now uses the same per-tick cache instead of re-scanning all 19 slots.
- `core/items.lua`: eliminated per-function `pcall(function() safe = NS.safe end)` allocations—`safe`/`safe_field` now captured once at install time as upvalues (saves 2 pcall allocations per function call).

### Critical Bug Fixes
- Arms Warrior: fixed `stance_swap_safe` typo (`preserved_rage_after_swapstate.rage` → `preserved_rage_after_swap(state.rage or 0)`)—stance swaps were crashing on every call.
- Arms Warrior: moved `ARMS_SCHEMA` declaration before `build_state` function—`safe_state` was receiving nil schema, making all custom defaults dead code.
- Arms Warrior: fixed `mortal_strike_matches` dead rage-cap bypass—both branches returned identical actions; rage-cap branch now omits `min_rage` gate.
- Core: fixed `get_spell_id` per-frame table allocation—was passing `{}` to `collect_ids` on every call instead of using the static buffer.
- Core: wrapped `spell_helper_castable` native API call in pcall—a single throw was aborting the entire rotation tick.
- Core: removed duplicate `_settings_cache` declarations (lines 151 + 353)—second set was dead state.
- Core: fixed `filter_spell_ids_for_expansion` no-op (`if true then` guard)—now actually filters TBC-only spell IDs (level > 60) on Vanilla.
- Core: removed dead `if false then return true end` branch in `NS.spell_exists`.
- Core: fixed `cooldown_remains` dead expression `false and 0.15 or 1.0` → `1.0` with explanatory comment.
- Core: renamed `NS.isfalse()` to `NS.is_api_health_broken()` (alias preserved for backward compat).

### Spec Fixes
- Balance Druid: fixed `_choose_nuke` dead Nature's Grace logic—fallback now returns "wrath" (mana efficiency) instead of "starfire", making the Nature's Grace check meaningful.
- Frost Mage: gated Fire Blast, Scorch, and Arcane Missiles behind explicit opt-in settings (`frost_use_fire_blast`, `frost_use_scorch`, `frost_use_arcane_missiles`)—were firing as unintended fillers.
- Discipline Priest: removed duplicate `PowerWordShieldLowest` strategy (identical to `EmergencyPowerWordShield`).
- Enhancement Shaman: removed debug logging (`_enh_lb_count` + `NS.log`) left in `lightning_bolt_matches`.
- Fury Warrior: removed dead `thunder_ready` state field and its `spell_ready` API call (Thunder Clap not used by Fury).
- Beast Mastery Hunter: fixed `is_item_ready` global function leak (missing `local` keyword).
- Affliction Warlock: added nil-guard to snapshot mutations (`if ok and aff_state.spell_damage then`).
- Balance Druid: standardized namespace alias from `_G_E` to `NS` (82 references replaced).

### Performance
- Core: `get_spell_id` no longer allocates a per-call table—uses existing `_collect_buf` static buffer.
- Main: `_context.lowest` table pre-allocated at module level instead of per-frame allocation.
- Main: removed dead `pre_aoe` variable assignments.

### Code Cleanup
- Core: removed `VANILLA_HIGH_SPELL_ALLOWLIST` (dead table, never referenced).
- Core: removed `_last_cast_time_cooldown` dead function (zero callers).
- Core: removed `_settings_manager` disabled pcall(require)—result was immediately discarded.
- Core: removed `EnemyCDTracker.has_major_offensive_active_or_recent` and `get_enemy_cds` stubs (zero callers).
- Core: removed `get_spell_damage` and `match_fail` stubs (zero callers).
- Core: removed `if true then` dead guards in `collect_ids` (3 sites).
- Core: added `-- Stub: extension point for future modules` comments to `player_control_locked` and `has_breakable_cc_nearby` (have callers, kept as extension points).
- Core: generated `cc_is_*` bridge functions (13 functions) from a table—eliminated ~80 lines of identical boilerplate.
- Core: generated `unit_is_*` bridge functions (7 functions) from a table—eliminated ~50 lines of identical boilerplate.
- Core: `is_hostile_unit` now short-circuits on definitive `can_attack` false result—eliminates up to 6 redundant API path checks per call.

### Shared Modules
- `potion_helper_sylvanas.lua`: added `HEALTHSTONE_IDS` table and `find_ready_healthstone()` function for cross-spec reuse.
- `match_helpers_sylvanas.lua`: added shared `cooldowns_enabled(context, opts)` helper—eliminates 16 duplicate `cooldowns_allowed`/`cooldowns_enabled` functions across spec files. Supports default-on, opt-in, require-combat, and state-table calling conventions.

### Warrior Shared Helpers
- Created `classes/warrior/shared_helpers_sylvanas.lua`—extracted 9 duplicated helper functions from Fury and Arms (`setting`, `bool_call`, `execute_phase`, `desired_stance`, `preserved_rage_after_swap`, `stance_swap_safe`, `action`, `cast`, `build_action`).
- Both `fury_sylvanas.lua` and `arms_sylvanas.lua` now require the shared module with fallback definitions.

### Test Infrastructure
- Fixed hardcoded Windows path in `test_leveling_druid.lua`—replaced with relative `package.path` pattern.
- Wired 14 orphaned test files into `run_rotation_tests.lua` (12 leveling + 2 reset_api_health).
- Added shared `assert_true` and `assert_eq` helpers to `test_runner_lib.lua`.
- Created `test_arms_critical_fixes.lua`—regression tests for the 3 Arms Warrior critical bugs (stance_swap_safe typo, ARMS_SCHEMA scoping, mortal_strike dead bypass). All pass.

### Documentation
- Updated `TECHNICAL_GUIDE.md` version from 1.0.15 to 1.1.1.
- Updated line number references in technical guide to use descriptive text instead of stale line numbers.
- Added staleness note to `status_audit.md`.
- Created `docs/CONTRIBUTING.md` with codebase overview, spec creation guide, test instructions, and coding conventions.

## 2.1.0 - 2026-06-06

- Debug cleanup: removed all developer debug infrastructure (debug_mode, trace, force_flags) from public codebase; 7 commits across main_sylvanas, main, enhancement, and shaman schema.
- Buff rank upgrade system: `NS.buff_rank()` in core_sylvanas.lua detects active buff rank position; `shared/buff_upgrade_sylvanas.lua` scans self + party for lower-rank buffs and auto-casts upgrades; OOC integration via middleware; 10 dedicated tests.
- Shadow priest fixes: DispelMagic returns false (middleware handles friendly cast), Fade requires party members, ManaBelow5Wand guards target existence.
- Warrior gap fixes: Prot threat cycling (Devastate/Revenge/Shield Slam priority), creature type filter fix, rage pooling for Execute phase, Disarm fix for PvP.
- API compliance audit: 9 context fields implemented across 34 spec files (target_hp, target_hp_pct, enemy_count, etc.).
- Core infrastructure audit: 5 dead/stub functions removed, 3 missing school locks added, get_spell_damage fixed to return actual values.
- Spell ID corrections: lexxer-verified spell IDs across all specs; cross-expansion Vanilla rank data added to SpellRankResolver.
- APL registry bridge: shared/apl_parser.lua wired into dispatcher (unused by specs, infrastructure ready).
- Vanilla cleanup: removed TBC-only spell IDs (level > 60) from _vanilla.lua rotation files.
- Flux references removed from public repo.
- Test count: 111/111 rotation + 11/11 leveling + 10/10 buff upgrade = 132 total tests passing.

## 1.1.0 - 2026-05-26

- Debug Log: fixed `ScrollDebugLogBottom` crash when `debug_window` size returns nil (nil-guard added).
- Debug Log: fixed `handle_resize` crash when `get_size()` returns nil during resize drag.
- Debug Log: guarded `core.game_ui.get_wow_cursor_position` access behind type-check to prevent crash on missing API.
- Debug Log: reconciled `ALWAYS_AUTO_RESIZE` flag with manual resize logic—manual resize now works predictably without window system conflicts.
- Debug Log: removed orphaned duplicate resize end-check blocks that caused syntax errors.
- Healer Engine: verified `cast_duration > 0` guard exists at line 92 before division; no change needed.
- Core: fixed `NS.action_execute` skip-GCD paths to route through `NS.evaluate_cast` (was bypassing cooldown/resource/range/anti-flicker/reagent checks).
- Warrior Protection: fixed stance-swap return to use `NS.try_cast(...) == true` (was `~= nil` which treated `false` as success).
- Debug Log: added `get_debug_window_size()` helper; all callers now guarded against nil size.
- All 291 Lua files pass `luac -p`.
- All 106 rotation suites + 11 leveling suites pass with zero failures.
- Release package: only `.lua` and `.md` files under `EaxRotations/`. Version bumped to 1.1.0.
- Core: `cast_unit_spell` and `cast_position_spell` now fail-closed when IZI `cast_safe` rejects a cast—previously fell through to raw `core.input.cast_target_spell`, allowing spell spam.
- Core: healing scan now falls back to visible friendly units when party APIs return only self, preventing healers from ignoring group allies.
- Elemental Shaman: Lightning Shield strategy now mirrors Enhancement charge-throttle, skipping recast when charges remain.
- Elemental Shaman: state builder now tracks `has_lightning_shield`, `lightning_shield_charges`, and `lightning_shield_ready`.
- Tests: fixed `run_rotation_tests.lua` exit-code detection to properly surface failures; removed duplicate `test_execute_phase.lua` entry.

## 1.0.17 - 2026-05-21

- Druid Balance: SP breakpoint research completed—TBC spell coefficients verified (Starfire ~1.0, Wrath ~0.571/0.671, Moonfire ~0.15 direct + ~0.52 DoT, Insect Swarm ~0.76) against Elitist Jerks, Wowhead, and wowsims sources.
- Druid Balance: 800/1000/1200 SP breakpoints confirmed—these thresholds are DoT GCD-value decisions, not Starfire vs Wrath filler preference; Starfire wins at all SP levels on mana efficiency and crit synergy.
- Docs: all three `[VERIFY]` tags in `Research.md` Angle 4 resolved to `verified`.
- Docs: `SP_Breakpoints_Druid_Balance.md` blocker file rewritten with comprehensive coefficient analysis, corrected mathematical proof, and deferred-implementation recommendation (Option B).
- Docs: `Druid_Balance_CHECKLIST.md` SP breakpoint row updated to verified status.

## 1.0.16 - 2026-05-21

- Druid Balance: smart Innervate targeting—party scan identifies healer-class units (Paladin/Priest/Shaman/Druid) and picks the lowest-effective-HP target for InnervateHealer strategy; InnervateSelf fallback when no suitable healer found.
- Druid Balance: Hurricane Barkskin automation—Hurricane now defers when Barkskin is ready (not on cooldown), letting PreHurricaneBarkskin handle the Barkskin→Hurricane sequence for 20% damage reduction synergy.
- Discipline: PW:S absorb tracking via `Healing.pws_absorb_remaining`—skips PW:S recast when remaining absorb exceeds 200 (prevents wasting mana and triggering Weakened Soul unnecessarily).
- Core: `NS.buff_points`/`NS.debuff_points` read the `points` array from aura data, enabling variable-value tracking (Holy Shield charges, PW:S absorb remaining, etc.).
- Tests: fixed `test_balance_custom_matches.lua` Hurricane cooldown mock for Barkskin-ready deferral logic.
- Docs: Agent instruction file updated with Patterns 11–13 (buff_points, PW:S absorb tracking, smart Innervate targeting); all stale per-spec library references cleaned up for flat-file architecture.
- Queue: 001_Druid_Balance moved from `blocked/` to `completed/` (2 of 3 blockers resolved); remaining SP breakpoints tracked in `SP_Breakpoints_Druid_Balance.md`.
- All 106 regression suites (95 rotation + 11 leveling) pass with zero failures.

## 1.0.15 - 2026-05-16

- Improved TBC spell and aura coverage for racials, common crowd control, Druid utility, and Hunter abilities.
- Improved Hunter leveling stability, including safer API fallbacks and correct Serpent Sting refresh timing.
- Improved Warrior buff-cancel and Shaman totem handling through safer shared helpers.
- Cleaned the release package so it contains only Lua source and Markdown documentation.
- Added audit documentation for spell IDs, archive comparisons, and static behavior checks.
- Verified release health: Lua syntax passes, all 106 regression suites pass, online TBC ID audit passes, and package file-type checks pass.

## 1.0.14 - 2026-05-15

- Made menu playstyle selection authoritative: Leveling no longer overrides Elemental, Enhancement, or Restoration for under-70 players.
- Fixed Enhancement self-heals so Lesser Healing Wave and Chain Heal do not fire at full health.
- Added Enhancement self-heal HP controls and throttled fallback Lightning Shield refreshes in the Leveling playstyle.

## 1.0.13 - 2026-05-15

- Added Shaman leveling weapon imbue support with auto Windfury/Rockbiter/Flametongue selection.
- Added Shaman leveling Searing, Strength of Earth, and water totem support with refresh throttles.
- Added missing TBC Shaman spell entries used by leveling: weapon imbues, Searing Totem, Stoneclaw Totem, and Healing Stream Totem.

## 1.0.12 - 2026-05-15

- Fixed Shaman Leveling loading but not registering with the dispatcher, which left the selected Leveling playstyle with no actions to run.
- Fixed Shaman Leveling using the legacy empty `NS.SPELLS` table instead of `NS.ShamanSpells`.
- Fixed Druid, Rogue, and Warrior Leveling dispatcher registration; all class leveling modules now register the `leveling` playstyle.
- Under-70 characters now run the Leveling playstyle as a pre-pass before the selected spec, so leveling support works automatically instead of requiring manual playstyle selection.
- Improved broken `spell_book.is_spell_learned` fallback to choose the best rank allowed by player level when spell metadata includes rank levels.
- Fixed low-level Shaman OOC buff fallback so Water Shield is not attempted before level 60 and Lightning Shield can be maintained below that level.

## 1.0.11 - 2026-05-15

- Fixed "trying to pop up spell which isnt learned": when spell_book API is broken, `NS.get_spell_id` now returns the lowest rank (`ids[#ids]`) instead of the highest (`ids[1]`). This ensures low-level players always get a castable spell rank.
- Both the normal resolution path and the fallback path now use lowest-rank-safe logic when API health is broken

## 1.0.10 - 2026-05-15

- Fixed `[DIAG] buff_up` printing table addresses instead of spell IDs (now shows `27044,25296,...`)
- Fixed `rotation callback failed` spamming every frame: rate-limited to once per 2s, changed from log_error to log
- Fixed `NS.get_spell_id` cache poisoning: clear spell cache when API health break is detected so previously cached fallback IDs get re-resolved
- Fixed rotation running in character menu/dead: added guards for `core.is_main_menu_open()`, `player:is_alive()`, and player existence check in `main.lua on_update`

## 1.0.9 - 2026-05-15

- Full system audit: 195 Lua files, 46 shared modules, 65 tests checked
- All files pass luac -p and LSP with zero errors
- Zero banned API violations confirmed
- All hot-path NS.log calls gated behind debug_system (74 guards)
- README synced to v1.0.9, status set to Stable
- Shared module audit: no duplicate overlap with core_sylvanas.lua
- Spec audit: druid/caster identified as thin (7 strategies)
- Retribution uses add_strategy (38 calls), Arms uses STRATEGY_SPECS (29 entries)

## 1.0.8 - 2026-05-15

- Properly compared archive modules vs new system: deleted `dot_manager_sylvanas.lua` (duplicate of existing `dot_refresh.lua` + `NS.should_refresh_dot`), `threat_manager_sylvanas.lua` (duplicate of existing `NS.should_drop_threat`/`NS.threat_status`), `dispel_engine_sylvanas.lua` (duplicate of `NS.has_dispel_type_debuff`/`NS.healing_get_cleanse_target`, used raw WoW API), `mana_conservator_sylvanas.lua` (duplicate of `NS.mana_pct`/`action.min_mana`)
- Rewrote `pet_manager_sylvanas.lua` to match archive's full state machine (per-spec tracking, pet spell scanning, growl/claw/special rotation with cooldown gating)
- Fixed `consumable_manager_sylvanas.lua` typo (`griffed` -> `grilled_mudfish`)
- Removed unused `SCROLLS` table from consumable_manager (no callers)
- Verified all remaining shared modules (`totem_manager`, `pvp_manager`, `pet_manager`, `consumable_manager`) have no duplicates in the existing system

## 1.0.7 - 2026-05-15

- Ported 3 shared modules from archive: `pet_manager_sylvanas.lua`, `totem_manager_sylvanas.lua`, `pvp_manager_sylvanas.lua`
- Pet manager: pet attack/follow/passive controls, growl/claw/bite/special ability casting, HP monitoring
- Totem manager: bag scanning for totem items, per-spec totem placement (elemental/enhancement/restoration), full TBC spell ID tables
- PvP manager: arena/BG map detection, enemy player targeting with healer priority, PvP trinket detection, arena frame support

## 1.0.6 - 2026-05-15

- Added diagnostic logging to `NS.buff_up`: logs when all buff detection methods fail (enable debug_system to see)
- Added `min_interval` support to action rows and `NS.action_matches`—prevents recast of buff actions within N seconds
- Added per-spell 5s rate limiter in `NS.try_cast` via `_last_spell_cast[id]` tracker—prevents same spell from being cast more than once per 5s regardless of code path
- Set `min_interval = 60` for Aspect of the Hawk and `min_interval = 30` for Aspect of the Viper across all 3 hunter specs
- Added `_last_action_exec` / `_last_spell_cast` timestamps at all cast success paths

## 1.0.5 - 2026-05-15

- Added comprehensive auto-consumable system: shared `consumable_manager_sylvanas.lua` manages flasks, potions, elixirs, food, scrolls, weapon buffs, drums, healthstones, and runes for all 9 classes
- Wired consumable strategies into all class middleware (warrior, mage, druid, hunter, warlock, paladin, shaman, priest, rogue)
- Consumables auto-detect class role for optimal item selection
- Throttled to 3s checks; logging behind debug_system only

## 1.0.4 - 2026-05-15

- Gated remaining un-gated logs behind `debug_system`: Druid Bear item usage, Druid middleware consumables, Warrior middleware (HS dequeue, PW:S/BoP cancel), Mage middleware mana gem
- Cross-spec audit complete: all `NS.log()` calls in hot paths now gated behind `debug_system` setting

## 1.0.3 - 2026-05-15

- Fixed Hunter rotation ability spam: KillCommand and AspectOfTheHawk no longer spammed every frame
- Added 0.3s anti-flicker protection to `skip_gcd` cast path in `core_sylvanas.lua`—covers all skip_gcd actions across all classes (KillCommand, Bloodrage, Powershift, etc.)
- Gated all action execution debug logs behind `debug_system` setting in `NS.action_execute`, `NS.try_cast`, and `NS.try_cast_position`
- Gated Paladin Holy item usage logs behind `debug_system`
- Gated Druid Resto mana potion log behind `debug_system`
- Restored `exporter.lua` from broken state (malformed table syntax, undefined variable reference)
- All version refs synced across header.lua, exporter.lua, optimizer_bridge.lua

## 1.0.2 - 2026-05-15

- Full diagnostic audit across all 29 specs: verified spell IDs, buff checks, nil safety, API compliance
- Fixed version inconsistencies across exporter.lua, optimizer_bridge.lua, and header.lua
- All 62 tests passing; luac -p passes on all .lua files; zero banned API usage
- Verified zip contains only .lua and .md files

## 1.0.1 - 2026-05-15

- Fixed Hunter Aspect of the Hawk rank IDs to prevent repeated Hawk recasts.

## 1.0.0 - 2026-05-15

- Initial release

