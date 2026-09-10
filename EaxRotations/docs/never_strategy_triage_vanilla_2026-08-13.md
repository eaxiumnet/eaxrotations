# NEVER-Strategy Triage — Vanilla Era Close-Out (2026-08-13)

Wave 1.4 of the Top-Tier Parsing Campaign: the behavioral battery now covers
**ALL 40 vanilla (Classic 1.15.x) spec files** — the 31 non-leveling specs
plus the 9 per-class `leveling_vanilla.lua` files, which previously ran only
via `run_leveling_tests.lua` and had zero behavioral coverage. The extension
surfaced **96 new never-firing leveling lanes** (109 total across the era);
this wave cleared every modelable lane and drove the era to its terminal
**13**, classified per the campaign taxonomy: **(a)=0, (b)=10, (c)=3, (d)=0**.

Companion docs: `never_strategy_triage_dps_2026-08-07.md` /
`never_strategy_triage_non_dps_2026-08-07.md` (original 304 → 100 triage),
`never_strategy_triage_tbc_2026-08-10.md` (TBC era, pinned at 16),
`never_strategy_triage_wotlk_2026-08-09.md` (WotLK era, pinned at 0).
The TBC (16) and WotLK (0) never counts were verified **lane-for-lane
unchanged** after every wave-1.4 change (diffed against the pre-wave TBC
never list: 16 identical lanes; WotLK 41 specs / 0 never / 0 load failures).

## How to reproduce

```bash
lua EaxRotations/tests/behavioral_audit.lua vanilla     # 40 specs, 13 never, 0 load failures
lua EaxRotations/tests/test_vanilla_sweep_regression.lua  # pins 13 + all cleared-to-zero + fixtures
lua EaxRotations/tests/run_verify_all.lua              # pins "behavioral battery (vanilla)": 40/40, never == 13
```

## Pre/post never counts per category

| Metric | Pre-wave (2026-08-11 sweep close) | Post-wave (2026-08-13) |
|---|---|---|
| Battery coverage | 31 / 40 specs | **40 / 40 specs** |
| Total never-firing lanes | 13 (31 specs) | **13** (40 specs — content reclassified) |
| (a) opt-in setting | 0 | **0** |
| (b) correctly-silent | 8 | **10** |
| (c) mock limitation | 5 | **3** |
| (d) dead | 0 | **0** |

The never total is coincidentally still 13, but the **content** moved:
AbolishDisease, CureDisease (priest/holy) and Ambush (rogue/subtlety)
cleared, and priest/leveling Fade was pinned (c) — see the Fade entry
below. This is a **legitimate behavior change** (battery coverage extension
+ harness modeling), not a test weakening: the spec count pin moved 31 →
40, the sweep regression test was **strengthened** (it now also pins the
40-spec coverage, the 9 leveling specs at zero, and the 8 new
fixture-scenario shapes), and every pin documents its per-lane
classification.

## Campaign mechanics (all battery-side; zero spec-file matcher edits)

The 9 fixer waves (Wave 1.3) had already changed firing behavior in the
spec files (hunter leveling `in_melee`, rogue Sap reachability, fury
BattleShout/Bloodrage, warlock ShadowWard gating, ...). The wave-1.4 work
in `behavioral_audit.lua` was purely harness:

1. **Manifest extension**: `M.SPEC_FILES_VANILLA` gained the 9
   `leveling` entries (alphabetized, mirroring the WotLK manifest);
   `check_manifest_drift` now includes `leveling_` for the vanilla era
   (same as WotLK) so a future leveling file without a manifest row
   fails loudly.
2. **`shared/leveling_sylvanas` require-time binding**: the 9 leveling
   files `require("shared/leveling_sylvanas")`, which captures
   `local NS = _G.EaxRotations` at load (leveling_sylvanas:21).
   `load_spec` now evicts it from `package.loaded` after every spec
   (same treatment as the six stubbed managers), so each leveling spec
   binds its own mock NS instead of the first one's stale state bank.
3. **Spell-table seeds**: the 9 leveling files read `SPELLS.X` with a
   nil-guarded local `spell_ready` (`if not spell_action then return
   false end`), so unseeded names were structurally dead. Seeded ~130
   entries across `DruidSpells`/`HunterSpells`/`MageSpells`/
   `PaladinSpells`/`PriestSpells`/`RogueSpells`/`ShamanSpells`/
   `WarlockSpells`/`WarriorSpells`, ladders mirroring
   `classes/<class>/class_sylvanas.lua` (TBC max-rank first — the
   established mock-seed convention). Only `ids[1]` is consulted by
   `cooldown_remains`, so no existing scenario keys moved. Sentinel
   gates verified: no TBC/vanilla lane gates on the absence of any
   seeded name (the `not SPELLS.X` gates found — balance Hurricane/
   Moonfire/InsectSwarm, paladin middleware DivineShield — all seed
   names that already existed or whose presence is additive).
4. **Bank-aware `spell_ready` forwarding**: `import_helpers("spell_ready")`
   now forwards to the latest `ns.spell_ready` (bank-aware via
   `cooldown_remains`) instead of returning a constant `true`. Only
   vanilla specs capture `spell_ready` this way (smite/kebab/holy
   vanilla — verified no TBC spec does), so the change is era-safe and
   can only shrink the never list. This made the asymmetric cure pair
   expressible: `friends_afflicted` no longer puts CureDisease (528) on
   cd (so the disease-cure lane fires in both eras), and
   `holy_cure_on_cd` drives the pre-emptive AbolishDisease branch
   (`not cure_disease_ready`) in both eras.
5. **Bank-aware `is_behind_target`**: `NS.is_behind_target` now reads the
   `is_behind` state-bank key with a **true default** (legacy posture
   preserved; cat specs read `context.is_behind` first, combat_vanilla
   keeps the true default). Unblocks druid leveling Claw's
   shred-preference gate.
6. **CCGateDB stub method**: `is_any_nearby_enemy_under_cc` (real surface:
   `shared/offensive_dispel_sylvanas:311`) added to the mock, bank-driven
   on `enemy_cc_nearby`. Unblocks warrior leveling PvPCCGate.
7. **8 fixture scenarios** (all era-shared; TBC never list diffed
   identical after the batch): `cat_lev_claw`, `lev_shock_earth`,
   `lev_shock_frost`, `priest_ve`, `pal_lev_seal`, `ambush_opener`,
   `pvp_cc_gate`, `ooc_afflicted`. NOTE: a ninth shape — a threat_pct
   >= 99 scenario to clear priest/leveling Fade — was trialed and REVERTED:
   any threat >= 99 scenario fires the TBC Soulshatter lanes in a second
   scenario, breaking their fires-ONLY-in-threat_high exclusivity pin
   (`test_threat_context_regression.lua`, an off-limits suite). Fade is
   pinned (c) below with the battery's threat channel capped at 95.

## Lanes cleared this wave (96 total: 94 leveling + AbolishDisease + Ambush)

Spell-table seeds alone cleared 74 of the 96 leveling lanes (druid 14,
hunter 17, mage 17, paladin 14, priest 17, rogue 20, shaman 16, warlock
17, warrior 22 minus the gates below). The remaining modelable lanes were
cleared by the fixture scenarios above:

| Class/Spec | Lane | How cleared | Rationale |
|---|---|---|---|
| druid/leveling | Claw | `cat_lev_claw` (form 3 + energy 60 + not behind + Rake remains 10) | shred/rake preference gates were constant-true mock state |
| mage/leveling | (all but ConjureManaGem) | spell seeds | nil `SPELLS.X` guard |
| paladin/leveling | Cleanse | `ooc_afflicted` (OOC + self affliction) | OOC self-cure shape was inexpressible |
| paladin/leveling | Exorcism | `pal_lev_seal` (seal up + undead target) | live-seal gate needs ANY_SEAL_BUFF up |
| paladin/leveling | HammerOfWrath | `pal_lev_seal` (seal up + target_hp 15) | live-seal + execute-range gate |
| priest/leveling | VampiricEmbrace | `priest_ve` (shadowform buff up) | has_buff is map-only; needed a shadowform-up shape |
| rogue/leveling | (all 20) | spell seeds + existing stealth/openers/energy scenarios | nil `SPELLS.X` guard |
| shaman/leveling | EarthShock | `lev_shock_earth` (leveling_default_shock = "earth") | opt-in setting fixture |
| shaman/leveling | FrostShock | `lev_shock_frost` (leveling_default_shock = "frost") | opt-in setting fixture |
| warrior/leveling | (all but PvPCCGate) | spell seeds + existing stance/rage scenarios | nil `SPELLS.X` guard |
| warrior/leveling | PvPCCGate | `pvp_cc_gate` (PvP + CC'd enemy nearby) | CCGateDB under-CC scan is live-game state |
| priest/holy | AbolishDisease | bank-aware spell_ready + `holy_cure_on_cd` | pre-emptive cure branch now observable |
| priest/holy | CureDisease | `friends_afflicted` no longer puts 528 on cd | disease-cure lane re-observable (TBC + vanilla) |
| rogue/subtlety | Ambush | `ambush_opener` (opener_preference = "ambush") | the SETTING path is expressible; only the auto-resolve is battery-dead |

## Final 13 never-lanes — per-lane classification (2026-08-13)

**(b) correctly-silent (10):**

| Spec | Lane | Evidence |
|---|---|---|
| druid/bear | FaerieFirePull | OOC pre-pull (`ooc = true`, bear form + OOC + target). TBC pins the same family (FaerieFirePull/FeralChargePull/PrePullEnrage = b); any modeling scenario would fire the TBC siblings, breaking the era count contract. Correctly silent. |
| druid/bear | PrePullEnrage | OOC pre-pull rage-pool lane (bear + OOC + rage < pool). Same era-shared constraint as above. |
| mage/fire | ManaGemConjure | OOC conjure; the mock's `is_item_ready` always reports a gem available, so the lane is suppressed. Modeling "no gem" would clear the TBC (b) pins (LANE_NOTES: "correctly suppressed in the mock (gem always available)"). Same family both eras. |
| mage/frost | ManaGemConjure | Same as fire. |
| mage/leveling | ConjureManaGem | Same gem-availability suppression (CONJURE_MANA_GEM_SPELLS ready + `mana_gem_available` always true in the mock). |
| priest/holy | EncounterReactions | Era gate: matcher requires `NS.is_tbc()` truthy (holy_vanilla:359-361) — Karazhan is TBC-only. Impossible in Classic by design; not modelable (is_tbc() false is the correct era answer). |
| priest/holy | MountedProtection | Mounted-OOC safety net (`me:is_mounted()`). A modeling scenario would fire the TBC sibling pin (MountedProtection = b in LANE_CLASS), breaking the era count contract. Correctly silent. |
| shaman/elemental | MagmaTotem | **CLEARED 2026-08-14** — enabled. All four ranks (8190/10585/10586/10587, rank IV = level 56) are Classic-era; the "max rank is TBC-only" disable (elemental_vanilla:461-462) was factually wrong — 25552 (rank V) is the TBC-only one and the class-table ladder resolves the highest learned rank. Vanilla never 13 → 12. |
| shaman/elemental | WrathOfAirTotem | TBC-only spell; inert marker at elemental_vanilla:452. Impossible-by-design. |
| warlock/affliction | RacialArcaneTorrent | Blood Elf racial — no blood elves in vanilla; ArcaneTorrent pinned nil (affliction_vanilla:83). Impossible-by-design. |

**(c) mock limitation (3):**

| Spec | Lane | Evidence |
|---|---|---|
| shaman/enhancement | FireNovaReplacement | gates on module-local `totem_state.fire_nova_active` (enhancement_vanilla:135 family), populated only by the spec's own totem-drop lifecycle during a real rotation update. Genuinely unpinnable via fixtures; fires live in-game. TBC sibling pinned (c) identically. |
| shaman/enhancement | GraceOfAirTotemTwist | gates on module-local `totem_state.next_air ~= "grace"` (enhancement_vanilla:481); `next_air` starts "windfury" and flips only inside the twist executes (731/739). The battery evaluates matches statelessly per scenario and cannot run the windfury→grace cycle. Fires live in-game. |
| priest/leveling | Fade | gates on `context.threat_pct >= 99` ("drawn aggro", leveling_vanilla:209-215). The battery's threat channel is capped at 95: the TBC Soulshatter lanes are pinned fires-ONLY-in-threat_high (test_threat_context_regression.lua — an off-limits suite), so any threat >= 99 scenario fires Soulshatter in a second scenario and breaks that exclusivity contract. Fires live at drawn aggro; unpinnable without weakening an existing pin. |

**(d) dead: 0.** No dead lanes were found in the vanilla era — every lane
either fires in the 40-spec battery or is classified (b)/(c) above. No
Wave 1.5 code-follow-up is required for the (d) bucket; the three (c)
lanes are battery-unpinnable by nature (module-local state x2) or by an
existing exclusivity pin (Fade) and are documented as non-actionable.

## Pin moves (with evidence)

| Pin | Before | After | Evidence |
|---|---|---|---|
| `run_verify_all.lua` vanilla battery specs | 31 | **40** | Battery manifest extended to all 40 vanilla files (9 leveling joined); `behavioral_audit.lua vanilla` prints "Total: 40 \| Load failures: 0". |
| `run_verify_all.lua` vanilla never-firing | 13 (31 specs) | **13** (40 specs, content reclassified) | Same run: 13 NEVER lines; sweep test pins 13 with the new per-spec keys (priest/holy 3→2, subtlety pin removed, priest/leveling 1 added); TBC 16 and WotLK 0 verified unchanged. |
| `test_vanilla_sweep_regression.lua` pins | 13 lanes / 31 specs | **13 lanes / 40 specs** | EXPECTED_NEVER re-keyed + 40-spec coverage assert + 9 leveling specs at 0 + 8 fixture-shape pins added. |
| `test_vanilla_sweep_regression.lua` (2d) ShadowWard fixture | bare `matches(ctx)` | builds real state via recovered `build_state` + adds demo non-PvP-silent assertion | The Wave 1.3 fixer reconciled demonology to `state.shadow_ward_ready` (demonology_vanilla:730-747); the old fixture passed nil state and silently false'd the demo side. Strengthened to the new state-driven contract — never weakened. |

The scorecard (`tools/spec_scorecard.lua`) covers TBC + WotLK only; its
totals are unchanged (TBC never=16 a=1 b=10 c=5 d=0, WotLK never=0) and
`lua tools/spec_scorecard.lua --check` stays in sync (regenerated
2026-08-13 — see the commit).

## Leftover red (pre-existing, Wave 1.3 uncommitted state — not this wave)

All wave-1.4 components are green, but two verify_all components and two
rotation-suite suites were ALREADY red on entry (uncommitted Wave 1.3 fixer
work, which this wave must not revert and cannot register — `era_pair_seed.lua`
and `run_*.lua` registration are outside this wave's file ownership):

1. **`run_rotation_tests.lua` — 501/503.** `test_manifest_completeness.lua`
   and `test_spec_layout_compliance.lua` fail on "unregistered test files:
   test_<class>_vanilla_live_fixes.lua (9)" — the 9 Wave-1.3 live-fix
   suites were created by the fixer waves and never added to the rotation
   runner's `tests = { ... }` table. Registration lives in the off-limits
   runner. Evidence: the failure names exactly the 9 Wave-1.3 files; this
   wave created no test files.
2. **`run_verify_all.lua` "era-pair seed freshness" — DRIFT.** The committed
   `era_pair_seed.lua` still lists `warrior/fury` missing_in "vanilla"
   names `{ "BattleShout", "Bloodrage", ... }`, but the Wave-1.3 fury
   fixer ADDED BattleShout + Bloodrage strategies to `fury_vanilla.lua`
   (they now have vanilla mirrors), so a fresh regeneration drops them
   from the missing list. `era_pair_seed.lua` is off-limits to this wave;
   the seed needs regeneration + commit together with the fury fixer's
   spec change (Wave 1.5 / integration follow-up).
3. **`run_verify_all.lua` "rotation suite"** — same root cause as (1).

Wave-1.4-owned pins all pass inside verify_all: behavioral battery
(TBC 31/16, WotLK 41/0, vanilla 40/13), all audits, spec scorecard
(TBC never=16 a=1 b=10 c=5 d=0 | WotLK never=0).

---

# Addendum 2026-09-06 — Vanilla parity: BM sting comment + Binding Heal era-gate pin

## Item 3 verdict — holy_vanilla "Binding Heal (32546)" placeholder is REAL era-gated handling, not dead text

The lane `UnavailableClassicPriestHealA` in `classes/priest/holy_vanilla.lua` is
deliberately inert BY DESIGN and the comment is accurate. Evidence traced end to
end:

- The priest class table (`priest/class_sylvanas.lua:461`) declares
  `UnavailableClassicPriestHealA = nil` — the key cannot resolve in the Classic
  client (Binding Heal is TBC-only; the real 32546 lives under
  `SPELLS.BindingHeal` for the `holy_sylvanas` sibling).
- The lane's gate is `spell_exists(SPELLS.UnavailableClassicPriestHealA) and
  spell_ready(…)`. The real chain is nil-safe: `NS.spell_exists` ->
  `NS.is_spell_learned` -> `NS.get_spell_id` -> "no ids => nil" -> `false`
  (`core_sylvanas.lua:1620/1677/1687`), so the lane evaluates cleanly and never
  fires — it cannot crash and cannot leak the TBC spell into Classic.
- New regression pin `test_priest_holy_vanilla_binding_heal_gate.lua` drives the
  REAL `holy_vanilla.lua`: with every rotation condition green (in combat, low
  self HP, lowest non-player ally present, opt-out setting off) the lane stays
  inert because the nil-keyed spell cannot exist. The pin also proves the gate
  is the only blocker by rewiring the key to the real `BindingHeal` (32546) in
  the mock — the lane then matches, i.e. a future edit that "fixes" the
  placeholder into the TBC spell turns the pin red.
- No code or comment change was needed; the placeholder's comment now has
  behavioral proof behind it.

## Item 2 (vanilla side) — BM sting comment corrected

`beast_mastery_vanilla.lua` carried the same half-true "Scorpid/Viper via
middleware" comment as the TBC file; corrected to state that Viper Sting is
owned by the class middleware (registered class-wide by the shared hunter class
module) and Scorpid Sting is Survival-utility only, with the BM `sting_mode` UI
exposing serpent|none. The middleware ViperSting lane itself is pinned by the
new `test_hunter_middleware_viper_sting.lua` suite (registered in the rotation
battery).

## Parity scan result (vanilla + SOD): no spec has genuinely zero coverage

Scanned every `*_vanilla.lua` and `*_sod.lua` spec file for a suite that loads
it (dofile/require on the real file) AND asserts behavior (.matches /
find_strategy / first_match / assert_execute / build_state). All 40 vanilla and
20 SOD specs have at least one such suite (vanilla via the targeted live-fix /
custom-matches / friendly-target suite set; SOD via the class-group rotation and
adversarial suites that require the real `*_sod` roles). No new per-spec suites
were warranted by the scan — the only genuinely unpinned handling paths found
were the middleware ViperSting lane and the Binding Heal era-gate, both now
pinned above.

```bash
lua EaxRotations/tests/behavioral_audit.lua vanilla   # 40 specs, never baseline 12 unchanged (priest holy 2 classified)
lua EaxRotations/tests/behavioral_audit.lua sod       # 20 specs, never 0
lua EaxRotations/tests/run_rotation_tests.lua         # 563 suites / 0 failed
```


---

## Addendum 2026-09-06 � pinned at 12; scorecard now covers all four eras

- The MagmaTotem clearing recorded above (2026-08-14, v2.24.2) is live: the
  vanilla era now pins at **12 never-firing lanes** (verify_all battery expects
  12; the scorecard's VANILLA_LANE_CLASS pins the same 12). The pre-clear
  "13" figures in this doc's header/commands are historical (Wave-1.4 close).
- `tools/spec_scorecard.lua` (P0, #1 roadmap) now rates **all four eras** �
  TBC/Sylvanas, WotLK, Vanilla, and SoD � so this doc's earlier note that the
  scorecard "covers TBC + WotLK only" is superseded. Vanilla rows carry the
  12-lane split (b) 9 + (c) 3 with per-lane evidence above; see
  `docs/scorecard.md` (regenerated 2026-09-06, `--check` in sync).


---

## Addendum 2026-09-06 (P0-3, #1 roadmap) — vanilla 12 → 11: MountedProtection modeled

Supersedes this doc's earlier 2026-09-06 addendum figure of 12. The
`ooc_mounted` scenario (in_combat=false + me:is_mounted ctx-banked) proves
priest/holy **MountedProtection** fires on a mounted OOC state — it was (b)
only because the mock lacked is_mounted (holy_vanilla mounted_protection
mirror reads me:is_mounted as its sole gate). New never split: **11 = (b) 8 ·
(c) 3 · (d) 0** (verify_all battery pin + sweep-regression EXPECTED_NEVER
updated; scorecard regenerated). Remaining (c) lanes re-verified unpinnable
under the stateless scenario model with code evidence: FireNovaReplacement +
GraceOfAirTotemTwist (module-local totem_state, enhancement_vanilla:44-48 +
703-713), Fade (threat_pct >= 99 vs the Soulshatter fires-ONLY-in-threat_high
exclusivity contract). EncounterReactions stays (b): NS.is_tbc() gate — no
Karazhan in Classic by design.


---

## Addendum 2026-09-06 (execute-capture, enh totem family) — vanilla 11 → 9

Supersedes this doc's 2026-09-06 addendum figure of 11. The execute-capture
harness (behavioral_audit.run_spec, era-guarded vanilla) runs the real
totem-drop executes against the mock NS so the module-local state the two
lanes gate on is seeded exactly as live, then re-evaluates on the post-cast
frame:

- `enh_grace_air_totem_twist_capture_vanilla` — seed: the REAL
  **WindfuryTotemTwist** execute (next_air: windfury → grace); reap:
  **GraceOfAirTotemTwist fires** (next_air == "grace", GoA buff down),
  exclusively in this scenario. Runs before the fire-nova capture so the
  seeded next_air is consumed (reap-and-consume: the fired GoA execute flips
  next_air back) before the fire scenario's phase-1.
- `enh_fire_nova_replacement_capture_vanilla` — seed: the REAL **FireTotem**
  execute with `enhancement_fire_totem = "fire_nova"` (fire_nova_active =
  true); reap: **FireNovaReplacement fires** (flame shock DOWN — the vanilla
  gate's direction — magma ready), exclusively in this scenario.

**FireNovaReplacement + GraceOfAirTotemTwist (vanilla): (c) → PROVEN.**
New never split: **9 = (b) 8 · (c) 1 · (d) 0** (verify_all battery pin +
sweep-regression EXPECTED_NEVER updated; scorecard regenerated).
shaman/enhancement vanilla clears to **0 never → S**. The remaining (c) is
priest/leveling Fade (threat_pct >= 99; the battery threat channel stays
capped at 95 by the Soulshatter fires-ONLY-in-threat_high exclusivity
contract) — noted, deliberately not forced. Cross-era contract re-verified:
tbc 11, wotlk 0, sod 0.

## Addendum 2026-09-09 — vanilla guide sweep: mage/arcane gains its missing AoE lane

Sweep of all 40 vanilla scorecard rows: every thin-looking row was inspected
against its published priority. warrior/kebab 13 vs its TBC sibling 16 is
legitimate era-slimming (Commanding Shout does not exist in vanilla;
Pummel/Healthstone handling differs per the TBC addendum), NOT a gap. The one
genuine guide gap found: mage/arcane_vanilla carried the full AP/Frost hybrid
(burn/conserve phases, PoM+AP sync, Clearcasting consumption) but had NO AoE
lane at all.

- Added ArcaneExplosion (ladder id 1449, present in every mock spell table —
  no bridge change needed): fire_vanilla's own idiom, aoe_self_meets 3+ /
  SELF_10, stationary-only so movement still falls through to FireBlast.
  Slotted after FireBlast, before Frostbolt, so the single-target nuke stays
  the default filler and the AoE lane wins only inside real AoE windows.
- Battery: mage/arcane 14 -> 15, never-fires=0; no other vanilla spec moved
  (vanilla never stays pinned at 9, all pre-triaged).
- Pinned in test_arcane_vanilla_strategies.lua: fail-closed without the AoE
  volume module, moving-hold (FireBlast owns moving), 3-enemy fire, volume
  hold, and the ordering contract. Suite count unchanged (563).
- Era-pair seed regenerated (1344 names; vanilla arcane +1 lane vs the TBC
  mirror is the intentional divergence, 0 unallowlisted). Scorecard row now
  mage/arcane | 15 | 0.
