# wowsims APL fixtures — provenance manifest

Pinned reference APL JSONs used by `shared/apl_parser.lua`,
`tools/apl_status.lua` (the conformance manifest that auto-fills the
scorecard's APL_STATUS column), and `tests/test_apl_conformance.lua`
(Phase 2 APL conformance). Adding a conformant spec = one pinned fixture
here + one entry in `tools/apl_status.lua`'s `M.ENTRIES`.

| Local fixture | Upstream source | Commit |
|---|---|---|
| `fire_wotlk.apl.json` | `wowsims/wotlk` `ui/mage/apls/fire.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `affliction_wotlk.apl.json` | `wowsims/wotlk` `ui/warlock/apls/affliction.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `feralcat_wotlk.apl.json` | `wowsims/wotlk` `ui/feral_druid/apls/default.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `arcane_wotlk.apl.json` | `wowsims/wotlk` `ui/mage/apls/arcane.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `frost_wotlk.apl.json` | `wowsims/wotlk` `ui/mage/apls/frost.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `combat_wotlk.apl.json` | `wowsims/wotlk` `ui/rogue/apls/combat.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `mutilate_wotlk.apl.json` | `wowsims/wotlk` `ui/rogue/apls/mutilate.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `elemental_wotlk.apl.json` | `wowsims/wotlk` `ui/elemental_shaman/apls/advanced.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `shadow_wotlk.apl.json` | `wowsims/wotlk` `ui/priest/apls/shadow.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |

- **Repo:** github.com/wowsims/wotlk, branch `master`.
- **Commit:** `563e4a08cb15729f1fdcbcf68e6d68224553bfef` (2025-12-22).
- **Fetched:** 2026-08-09 via the GitHub raw endpoint.
- **Format:** wowsims `TypeAPL` JSON (`priorityList` of actions).
- **Update policy:** re-fetch only on an intentional conformance re-baseline;
  update this table + the commit ref in `shared/apl_parser.lua` together.

## Why feralcat is special

`ui/feral_druid/apls/default.apl.json` delegates the rotation to the Go
`catOptimalRotationAction` black box — the JSON carries only prepull actions and
one `catOptimalRotationAction` node, no steady-state spell list. The reference
order for feral cat is therefore pinned **from the Go source** at the same
commit, `sim/druid/feral/rotation.go` → `doRotation()` dispatch order:

```
FaerieFireFeral  (ffNow)
SavageRoar       (roarNow)
Rip              (ripNow)
FerociousBite    (biteNow)
MangleCat        (mangleNow)
Rake             (rakeNow)
Shred            (filler)
```

(`Berserk` is a CD handled outside the loop; `Ravage` is a stealth opener only.)

The pin lives in `tests/test_apl_conformance.lua` with the Go dispatch-order
comment; the JSON fixture is still tracked so the loader path stays uniform.

## TBC era — pinned from Go dispatch (no TypeAPL JSON exists)

**wowsims/tbc has no TypeAPL JSON fixtures.** That format postdates the TBC
repo; rotations are imperative Go dispatch files (pre-TypeAPL era). TBC
conformance therefore pins `reference_names` lists extracted from the sim's
check-order at **wowsims/tbc `master`** (fetched 2026-08-09).

`check_name_order` only enforces the *relative order of names present in both
lists*, so the pins deliberately include only the sim's dispatch chain and
ignore: the warlock curse `switch` (mutually exclusive — one curse at a time),
Starshards (racial, `UseStarshards` opt-in), seed/AoE branches, and our own
extra strategies (potions/defensives/moving variants).

| Manifest key | Go source (wowsims/tbc `master`) | Reference order |
|---|---|---|
| `tbc/shadow` | `sim/priest/shadow_rotation.go` `tryUseGCD` | VampiricTouch → ShadowWordPain → DevouringPlague → MindBlast → MindFlay |
| `tbc/affliction` | `sim/warlock_rotations.go` `tryUseGCD` (after curse switch) | UnstableAffliction → Corruption → SiphonLife → Immolate → ShadowBolt |
| `tbc/combat` | `sim/rogue_rotation.go` `doPlan*` family | SliceAndDice → Eviscerate → SinisterStrike |
| `tbc/elemental` | `sim/shaman_elemental_rotation.go` (LB/CL-only sim) | ChainLightning → LightningBolt |
| `tbc/fire` | `sim/mage_rotations.go` `doFireRotation` | Scorch (5-stack) → Fireball |
| `tbc/frost` | `sim/mage_rotations.go` `doFrostRotation` | Frostbolt |
| `tbc/balance` | `sim/druid_balance_rotation.go` `actRotation` | FaerieFire → InsectSwarm → Moonfire → Starfire |
| `tbc/cat` | `sim/druid_feral_rotation.go` `doRotation` | FaerieFire → Rip → Mangle → FerociousBite → Shred |
| `tbc/beast_mastery` | `sim/hunter_rotation.go` `tryUsePrioGCD`/`lazyRotation` | SerpentSting → MultiShot → ArcaneShot → SteadyShot |
| `tbc/marksmanship` | `sim/hunter_rotation.go` (same dispatch) | SerpentSting → MultiShot → ArcaneShot → SteadyShot |
| `tbc/survival` | `sim/hunter_rotation.go` (same dispatch) | SerpentSting → MultiShot → ArcaneShot → SteadyShot |
| `tbc/arcane` | `sim/mage_rotations.go` `doArcaneRotation` | ArcaneBlast → Frostbolt(conserve) → ArcaneMissiles |
| `tbc/retribution` | `sim/paladin_retribution_rotation.go` `mainRotation` | Judge(Crusader) → ApplySeal → CrusaderStrike → SealOfBlood |
| `tbc/smite` | `sim/priest_smite_rotation.go` `tryUseGCD` | ShadowWordPain → Starshards → DevPlague → MindBlast → Smite |
| `tbc/enhancement` | `sim/shaman_enhancement_rotation.go` (schedule) | Stormstrike → FlameShock → EarthShock → FrostShock |
| `tbc/demonology` | `sim/warlock_rotations.go` `tryUseGCD` | Corruption → SiphonLife → Immolate → ShadowBolt |
| `tbc/destruction` | `sim/warlock_rotations.go` (Incinerate branch) | Corruption → Immolate → Incinerate |
| `tbc/arms` | `sim/warrior_dps_rotation.go` `normalRotation` | Execute → MortalStrike → Whirlwind → Overpower |
| `tbc/fury` | `sim/warrior_dps_rotation.go` `normalRotation` | Execute → Bloodthirst → Whirlwind → Overpower |
| `tbc/bear` | `sim/druid_tank_rotation.go` `doRotation` | FaerieFire → DemoralizingRoar → Mangle → Lacerate |
| `tbc/paladin/protection` | `sim/paladin_protection_rotation.go` `OnGCDReady` | HolyShield → Consecration → Judgement → Seal → Exorcism |
| `tbc/warrior/protection` | `sim/warrior/protection/rotation.go` `doRotation` | ShieldSlam → Revenge → Devastate → SunderArmor |
| `tbc/caster` | `sim/druid/balance/rotation.go` `doRotation` (damage-chain subset) | FaerieFire → Moonfire → Wrath |

Notes:
- **Bear**: Swipe is AoE/AP-gated and Maul is queued on-next-swing (both
  non-GCD branches), so they are excluded from the pin; FF-before-DemoRoar
  matches the Go dispatch's check order (previously reversed in our file).
- **Prot paladin**: the seal is applied on the Judgement branch of the Go
  dispatch; Avenger's Shield is a 30s CD outside the GCD chain and excluded.
- **Prot warrior**: pinned against the DEDICATED `sim/warrior/protection/rotation.go`
  (`doRotation`: ShieldSlam → Bloodthirst → MortalStrike → Revenge → Shout →
  ThunderClap → DemoShout → Devastate → SunderArmor). Revenge IS modeled (the
  earlier batch-3 note claiming otherwise was wrong — that pin cited the DPS
  dispatch file). Bloodthirst/MortalStrike are arms/fury talents absent from the
  prot rotation; Shout (Battle Shout) is a buff-maintenance lane our rotation
  places far below the sim's mid-chain check — excluded with that honest reason.
  The pin includes ThunderClap + DemoralizingShout: the dispatch checks ThunderClap
  BEFORE DemoShout, and our ACTIONS table was reversed (DemoShout first); it was
  reordered to match the sim as a pure order move (2026-08-09) so both are
  pinnable and the pin stays provably live.
- **Assassination / subtlety**: the wowsims/tbc tree has exactly ONE rogue
  rotation — `sim/rogue/rotation.go` — which is **combat-only**: its `Builder`
  is fixed to SinisterStrike (no Mutilate/Backstab/Envenom anywhere in the Go
  rotation or `sim/rogue/` tree) — no defensible dispatch exists, `pending`.
- **Caster**: NO `sim/druid/caster*` preset exists in the wowsims/tbc tree (only
  balance/feral/tank). The caster pin uses the damage-chain subset shared with
  the balance moonkin dispatch (FaerieFire → Moonfire → Wrath); Hurricane /
  InsectSwarm / Starfire raid branches and defensives are excluded.
- **Kebab** (custom DW-arms variant): no `sim/warrior/*` preset models a
  dual-wield arms build (tree has only dps + protection) — no defensible
  dispatch, `pending`.
- **Healers** (druid/resto, paladin/holy, priest/holy + discipline, shaman/
  restoration): the wowsims/tbc tree contains NO healer rotation directories —
  only balance/feral/tank, protection/retribution, shadow/smite, elemental/
  enhancement, dps — so they remain `pending` by absence of evidence.
- **FireBlast** is an *opt-in* weave (`WeaveFireBlast` defaults to `false` in
  `ui/mage/inputs.ts`), so it is deliberately NOT in the `tbc/fire` pin — our
  rotation keeps FireBlast as a movement/instant lane below Fireball, matching
  the default sim.
- **Elemental**: the TBC sim rotation is LB/CL-only (no FlameShock upkeep);
  FlameShock and the moving/totem strategies are our extras and ignored.
- **Healers** (holy/disc/resto/healing) have **no wowsims rotation at all** —
  they legitimately remain `pending` in the scorecard.
- Adding a TBC spec = add a `reference_names` entry to `tools/apl_status.lua`
  (`M.ENTRIES`) + a row here; no JSON fetch required.

## WotLK battery triage provenance (2026-08-09)

The WotLK never-firing inventory (149 lanes) was cleared to **0** in the Phase-1
triage — the result lives in `tests/behavioral_audit.lua`, not here. What changed
and why:

- **Resource/cooldown accessors** — `me:get_rage()/get_energy()/get_combo_points()/
  get_runic_power()` and `action:cooldown_remaining()` were absent from the battery
  unit/spell mocks; WotLK specs read them directly (`NS.me or NS.GetPlayer()`),
  so every resource-gated lane read 0/99. Added bank-driven accessors.
- **DK shared-manager stubs** — `rune_manager`, `presence_manager`,
  `interrupt_manager` were stubbed before `ns` was in scope (dead closures);
  rewired after `build_ns`, bank-driven. Cleared runic-power gates
  (DancingRuneWeapon/DeathCoil), EmpowerRuneWeapon (depleted-rune bank),
  Presence/FrostPresence (optimal_presence bank), MindFreeze ×3
  (target_is_casting-aware interrupt).
- **Scenario banks** — 17 new scenarios: `dk_runic/dk_boss/dk_disease/
  dk_runes_depleted/dk_presence`, `lvl_feral/lvl_bear/lvl_cat_form/lvl_bear_form`,
  `resto_swiftmend`, `surv_lockload`, `fire_scorch`, `ooc_low_mana`,
  `lvl_shadowform`, `shaman_ready`, `enh_procs`, `resto_triage`.
- **Note:** the DK leveling/unholy files install the real `aoe_hit_volume`
  (overrides the battery's always-true `aoe_target_meets`), so AoE-gated lanes
  need `enemy_count` in their scenario, not just a stub.
- All fixes were **battery-fixture only** — zero spec-file matcher/order edits
  (no (d) dead lanes existed; the discipline holds).
- Scorecard era "wotlk" flipped from LENIENT to STRICT (no untriaged backlog).
