# NEVER-Strategy Triage — Non-DPS / Healer Specs (2026-08-07)

Second triage report. Classification of the original **184 never-firing
strategies** across the 18 non-DPS specs (priest ×4, paladin ×3, shaman ×3,
druid ×5, hunter ×3), produced from the behavioral battery (133 scenarios,
31 specs). Battery upgrades have since cleared 91 of them (85 via battery
upgrades — 79 (c), 4 (a), 2 (b) reclassified as opt-in toggles; the 6 (d)
lanes fixed in code) — current non-DPS
never-firing: **87** (all-spec 304 → 100).
"Never" means the strategy's `matches()` returned `true` in **zero**
scenarios — either gated behind an opt-in setting, only reachable in a
live-game situation the battery cannot model, or a genuine dead lane caused
by a missing `build_state` assignment.

Companion to `never_strategy_triage_dps_2026-08-07.md` (the 13 DPS specs,
117 strategies, all five (d) lanes already fixed). Counts verified against
a live battery run on 2026-08-07.

## Classification legend

| Tag | Meaning | Action |
|-----|---------|--------|
| **(a) opt-in setting** | Disabled by default (`setting` default `false`/`"none"`/`0`, or a dedicated toggle). Works in live play once enabled. | none (maybe surface in UI) |
| **(b) PvP / stealth / OOC / situational** | Only reachable in a live situation the battery has no scenario for: threat, snare, enemy caster, target classification (undead/demon/boss), OOC buffing, ally/party state, racial. Correctly silent vs a normal PvE target. | none |
| **(c) battery limitation** | The mock/scenarios can't express the state: heal-scan/prediction modules unmocked, `NS.PLAYER_UNIT` empty stub, affliction flags, multi-target DoT spread, `spell_ready` always true, `is_behind` hardwired, empty `enemies` list. Works in live play. | battery upgrade (list below) |
| **(d) likely dead lane** | `build_state` never assigns a field the match reads, or the match is hardcoded `false`, so the lane can never fire **in live play either**. | fix the spec |

**Category counts (current, live battery 2026-08-08):** (a) 0 · (b) 35 · (c) 58 · (d) 0 (of 93) —
all (a) opt-ins and all 6 (d) lanes are now CLEARED; the final all-spec
chain 304 → **100** = DPS 13 + non-DPS 87
(original 184 = (a) 10 · (b) 36 · (c) 132 · (d) 6).

Per-class: priest 13 · paladin 25 · druid 29 · shaman 16 · hunter 10.

**Post-upgrade status (2026-08-07):** all healer battery upgrades and the
(d) fixes are applied (all-spec never-firing 304 → 254 → 249 → 224 → 219 → 218 → 217 → 216 → 215 → 213 → 207 → 194 → **183** → **180** → **176** → **173** → **161** → **152** → **151** → **145** → **144** → **140** → **133** → **130** → **125** → **118** → **112** → **111** → **110** → **109** → **108** → **106** → **105** → **100**
after the per-class `on_cd` scenarios, the heal-scan/affliction stubs, the
`pushback` scenario + `state.entries` wiring, the seal-state scenarios, the
`FsrManager` stub + `fsr_pause` scenario, the settings-modeling fixture
(ranked #7: ctx.settings merge, context.enemies, truthy dispatch), the
multi-DoT spread model (ranked #1), the DPS-ranked #3/#4/#5 scenarios
(`wand_low_mana`, `ab_stack_conserve`, `battle_ready` + map-aware
`ns.buff_up` — cleared DPS `Wand`/`FrostboltConserve`/`BladeFlurry`), and the
arcane burn-phase model (ranked #2: bank `get_max_power` 15000 +
`burn_ready`/`burn_coldsnap` — cleared DPS `ArcanePower`/`PresenceOfMind`/
`IcyVeins`/`ColdSnapIVReset`), and the
multi-target DoT model (ranked #1: TSHelper stub + unit-aware debuff map);
non-DPS 184 → 100):
1. `NS.PLAYER_UNIT.get_health_percentage → ctx.hp` + `mana_critical`
   scenario (`mana_pct = 4`; the wand gates are strict `< 5`) — **11 lanes**
   (holy `Healthstone`/`DesperatePrayer`/`BindingHeal`/`ManaBelow5Wand`,
   smite `Healthstone`/`SoloPowerWordShield`, `ManaEmergencyWand` ×3,
   `AspectOfTheViper` ×2).
2. `undead_target` scenario (`target_creature_type = 6` + enemy_count 2) —
   **9 lanes**: `ShackleUndead` ×4, `TurnEvil` ×2, prot `Exorcism` +
   `HolyWrath`, ret `Ret_HolyWrath_AoE`. (Undead is creature-type 6, not
   classification 3 — 3 is DEMON; the specs read `get_creature_type`.)
3. **Heal-scan + affliction stubs (2026-08-07)** — the per-class Healing
   modules now expose a state-bank-driven `scan_healing_targets` (entries
   from the scenario's `friends_hp`, tank = entry[2], player self-entry),
   real `NS.healing_*` rankers, and per-debuff-type `afflicted` flags
   (poison/disease/curse/magic). New scenarios `group_light`, `group_critical`,
   `group_aoe`, `group_healthy`, `group_emergency`, `tank_low`,
   `mana_tide_window` — **25 lanes** (17 heal-scan + 8 affliction): holy
   `CircleOfHealing`/`Lightwell`/`RenewTank`/`AbolishDisease`/`CureDisease`/
   `DispelMagic`, disc `BindingHeal`/`GreaterHeal`/`PrayerOfHealing`/
   `EmergencyPowerWordShield`, paladin `PurifySelf`/
   `DivineFavorHolyShockCombo`, druid `SwiftmendEmergency`/
   `TranquilityEmergency`/`NaturesSwiftness`/`NaturesSwiftnessHealingTouch`/
   `LeaveTreeForDirectHeal`, shaman `ChainHeal`/`SmartHeal`/`Bloodlust`/
   `NaturesSwiftness`/`CureDisease`/`CurePoison`/`DiseaseCleansingTotem`/
   `PoisonCleansingTotem`. (3 stub-regressions — disc `PainSuppression`/
   `PowerWordShieldTank`, shaman `ManaTideTotem` — restored via `tank_low` /
   `mana_tide_window`; net 0.)
4. **All 3 (d) dead lanes fixed** (`holy_state.mana_pct`,
   `resto_state.healthstone_ready`, MM `BestialWrath` via `spell_exists`),
   pinned by `test_healer_dead_lane_regression.lua`.

---

## (d) — LIKELY DEAD LANES (6: 3 original + 3 reclassified) — ✅ ALL FIXED (2026-08-07)

Same bug class as the mage/hunter fixes: the match reads a state field
`build_state` never populates, so it evaluates against the schema default
forever. Two were live-play dead; the third was hardcoded dead code. All
three are fixed, verified by `test_healer_dead_lane_regression.lua`, and
no longer appear in the battery never-lists (257 → 254 all-spec).

Three more lanes were reclassified (c)→(d) in the PreHeal/Preemptive turn
(2026-08-07): `PreemptiveHeal.match` reads `state.entries`/`state.count`,
which disc/holy/resto `build_state` never stored (druid/resto +
paladin/holy already do) — so the prediction lanes were dead in live play
too, not just battery-hidden. Fixed by storing `state.entries`/`state.count`
from the heal scan in all three specs; pinned by
`tests/test_preemptive_lane_regression.lua`.

| Spec | Strategy | Root cause | Evidence | Live-dead? |
|------|----------|-----------|----------|------------|
| priest/holy | `ManaPotion` | `state.mana_pct` **never assigned** in `holy_sylvanas.lua` build_state | probe: `ctx.mana_pct=10` (low_mana) but `state.mana_pct=100` (schema default wins); gate `state.mana_pct or context.mana_pct` → 100 → `100 < 20` false. Siblings (smite:169, discipline:333) assign it | ✅ **FIXED** — `holy_state.mana_pct` assigned (mirrors discipline) |
| druid/resto | `Healthstone` | `state.healthstone_ready` **never assigned** in `resto_sylvanas.lua` build_state | gate `(state.healthstone_ready or 0) > 0`; schema has no default → stays `nil` → never true. `first_ready_item(HEALTHSTONE_IDS)` exists (used in execute) but never wired into state. Probe: low_self → `healthstone_ready=nil` while `ctx.hp=15` reads fine | ✅ **FIXED** — `resto_state.healthstone_ready` assigned via `first_ready_item` |
| hunter/marksmanship | `BestialWrath` | `bestial_wrath_matches` hardcoded `return false` (line 480) | not DSL-substituted (absent from MM DSL_DEFS); execute still casts on pet. Bestial Wrath is a BM-tree talent, so a stub is semi-intentional — but hardcoding `false` instead of `spell_exists(ACTION.BestialWrath)` kills the lane even for mixed builds | ✅ **FIXED** — now gates on `NS.spell_exists(ACTION.BestialWrath)` |

**Applied fixes** (mirror the mage fix + sibling specs; pinned by
`tests/test_healer_dead_lane_regression.lua`, registered in
`run_rotation_tests.lua`):

```lua
-- priest/holy_sylvanas.lua build_state (with the other resource reads):
holy_state.mana_pct = context.mana_pct or (player and NS.unit_mana_pct and NS.unit_mana_pct(player)) or 100

-- druid/resto_sylvanas.lua build_state (near resto_state.mana_pct):
resto_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)

-- hunter/marksmanship_sylvanas.lua (replace hardcoded false):
local function bestial_wrath_matches(context, s)
    if not (NS.spell_exists and NS.spell_exists(ACTION.BestialWrath)) then return false end
    return true
end
```

---

## Per-spec classification

### priest (13) — discipline 0 · holy 4 · shadow 3 · smite 4

**discipline (3):** heal-scan + `group_*` scenarios cleared the triage heals.
| Strategy | Tag | Why |
|----------|-----|-----|
| ~~BindingHeal, GreaterHeal, PrayerOfHealing~~ ✅ CLEARED | (c→fired) | heal-scan stub + `group_critical`/`group_light`/`group_aoe` (lowest hp bands 30/62/40) |
| ~~EmergencyPowerWordShield~~ ✅ CLEARED | (c→fired) | `group_critical` (lowest 30 ≤ 35, tank 45 ≠ lowest) |
| ~~PainSuppression, PowerWordShieldTank~~ ✅ CLEARED | (c→fired) | `tank_low` scenario (tank = entry[2] at 30) |
| ~~PreHeal~~ ✅ CLEARED | (c→fired) | `pushback` scenario — enemy casting → `_check_pushback` true + tank 72 in [60,95] |
| ~~PreemptiveGreaterHeal~~ ✅ FIXED | (d→fixed) | `state.entries`/`count` now stored in disc build_state (was never assigned — dead in live play too) |
| ~~FSRPause~~ ✅ CLEARED | (c→fired) | `fsr_pause` scenario + scenario-driven `FsrManager` stub (ranked #6, 2026-08-07) |
| ~~FriendlyTarget~~ ✅ CLEARED | (b→fired) | `friendly_target` scenario — `ns.get_friendly_target_entry` is now scenario-aware (friendly unit at 60%, below the 90 threshold) |
| ~~ShackleUndead~~ ✅ CLEARED | (c→fired) | `undead_target` scenario (creature type 6) |
| ~~Fade~~ ✅ CLEARED | (b→fired) | `threat_high` scenario (ranked #12) — threat_pct 95 >= fade threshold 80 |

**holy (4):** (d) fixed; 6 more lanes cleared by the heal-scan/affliction
stubs; 1 (ShackleUndead) by `undead_target`; 2 (PreHeal/Preemptive) below;
1 (FriendlyTarget) by the `friendly_target` scenario.
| Strategy | Tag | Why |
|----------|-----|-----|
| ~~ManaPotion~~ ✅ FIXED | (d→fixed) | `holy_state.mana_pct` now assigned (mirrors discipline) |
| ~~Healthstone, DesperatePrayer~~ ✅ CLEARED | (c→fired) | PLAYER_UNIT stub now returns `ctx.hp` → both fire in `low_self` |
| ~~ManaBelow5Wand~~ ✅ CLEARED | (c→fired) | `mana_critical` scenario sets `mana_pct = 4` (< 5 gate) |
| ~~AbolishDisease, CureDisease, DispelMagic~~ ✅ CLEARED | (c→fired) | per-debuff `afflicted` flags in `friends_afflicted` (has_disease / has_dangerous_dispel) |
| ~~CircleOfHealing, RenewTank, Lightwell~~ ✅ CLEARED | (c→fired) | heal-scan stub (group_damaged_count / tank entry / injured group) |
| ~~MassDispel~~ ✅ CLEARED | (c→fired) | `context.party_members` now populated from the heal-scan friends in `friends_afflicted`, so the dangerous-magic scan finds a target (ranked #3, 2026-08-07) |
| ~~PreHeal~~ ✅ CLEARED | (c→fired) | `pushback` scenario — enemy casting → `_check_pushback` true + tank 72 in [60,95] |
| ~~PreemptiveGreaterHeal~~ ✅ FIXED | (d→fixed) | `state.entries`/`count` now stored in holy build_state (was never assigned — dead in live play too) |
| ClearcastingGreaterHeal, SurgeOfLightSmite | (c) | needs clearcasting / Surge buff (buffs_up is all-or-nothing) |
| ~~FSRPause~~ ✅ CLEARED | (c→fired) | `fsr_pause` scenario — `player_mana_pct=30` (holy's context.mana_pct has no unit fallback) + PoM buff id 33076 in the map blocks PrayerOfMending@5 (ranked #6) |
| ~~FriendlyTarget~~ ✅ CLEARED | (b→fired) | `friendly_target` scenario — `ns.get_friendly_target_entry` is now scenario-aware (friendly unit at 60%, below the 90 threshold) |
| ~~ShackleUndead~~ ✅ CLEARED | (c→fired) | `undead_target` scenario (creature type 6) |
| EncounterReactions | (b) | Karazhan boss encounter IDs |
| ~~Fade~~ ✅ CLEARED | (b→fired) | `threat_high` scenario (ranked #12) |
| MountedProtection | (b) | mounted state never set |

**shadow (4):**
| Strategy | Tag | Why |
|----------|-----|-----|
| ~~MultiDotSWP, MultiDotVT, SWPSpread, VTSpread~~ ✅ CLEARED | (a) opt-in + (c→fixed) | **APPLIED (ranked #1)** — `TSHelper.get_dps_targets` stub (bank-backed → `ctx.enemies`) + unit-aware `debuff_up`/`debuff_remains`; `shadow_multidot` (`shadow_multidot_mode = 2`, 2 enemies) / `shadow_cleave` (`shadow_combat_mode = "cleave"`, 3 enemies) via the settings fixture. SWPSpread/VTSpread ALSO fire in `target_melee` — shadow's `combat_mode` auto-detects cleave at 3+ enemies (realistic, not a leak) |
| HolyNovaAoE | (c) | AoE + undead/CC gating |
| DispelMagic | (c) | affliction flags not set |
| ~~ShackleUndead~~ ✅ CLEARED | (c→fired) | `undead_target` scenario (creature type 6) |
| ~~Fade~~ ✅ CLEARED | (b→fired) | `threat_high` scenario (ranked #12) |
| SWDCCBreak | (b) | breaks fear CC — needs fear state |

**smite (5):** 2 lanes cleared by the PLAYER_UNIT hp fix, 1 (ShackleUndead)
by `undead_target`.
| Strategy | Tag | Why |
|----------|-----|-----|
| SoloRenew | (c) | heal-scan/self-hp combo still unreachable (Healthstone + SoloPowerWordShield ✅ CLEARED — PLAYER_UNIT hp fix) |
| InnerFocus | (c) | needs Inner Focus buff state + CD |
| ~~ShackleUndead~~ ✅ CLEARED | (c→fired) | `undead_target` scenario (creature type 6) |
| DevouringPlague | (b) | `_is_undead` race/creature check — no undead target |
| Starshards | (b) | `_is_night_elf` racial |
| SoloPsychicScream | (c) | needs fear-worthy CC state |

### paladin (25) — holy 8 · protection 8 · retribution 9

**holy (9):** all (c)/(b) — heal-scan + buff-chain state.
| Strategy | Tag | Why |
|----------|-----|-----|
| ~~PurifySelf~~ ✅ CLEARED | (c→fired) | player self-entry carries `has_poison/has_disease` in `friends_afflicted` |
| ~~DivineFavorHolyShockCombo~~ ✅ CLEARED | (c→fired) | `group_emergency` (`buffs_up` + injured group) — buff-combo reachable |
| ConsecrationSoloAoE, JudgementSoloRighteousness, HammerOfWrathSolo, LayOnHandsLastResort | (c) | seal-state/CD-combo/AoE gating not reachable |
| JudgementOfLightBoss, JudgementOfWisdomBoss | (c) | `BOSS_HP_FLOOR`/boss flag — battery target is a normal mob |
| ~~LightGraceBuild~~ ✅ CLEARED | (c→fired) | heal-scan entry `deficit` was hardcoded 0 — now computed `max(0, 100 - effective_hp)` (deficit fix, 2026-08-07) |
| ~~LightGraceChain~~ ✅ CLEARED | (c→fired) | per-buff `lights_grace` scenario — `buff_remains_map` { [31834] = 1.5 } drives `NS.buff_remains` (ranked #2, 2026-08-07) |
| ~~FSRPause~~ ✅ CLEARED | (c→fired) | `fsr_pause` scenario — buffs_up suppresses AuraManagement; `holy_refresh_enabled`/`holy_blessing_light` false block the blessing refresh lanes (120s boundary reads “expiring”) (ranked #6) |
| ~~FriendlyTarget~~ ✅ CLEARED | (b→fired) | `friendly_target` scenario — `ns.get_friendly_target_entry` is now scenario-aware (friendly unit at 60%, below the 90 threshold) |
| BlessingOfFreedomSnare | (b) | snare-CC escape |
| BlessingOfProtectionFocusedAlly | (b) | focused-ally protection |

**protection (8):**
| Strategy | Tag | Why |
|----------|-----|-----|
| AvengerShield, SealOfCommandAoE, Judgement | (c) | seal/judgement state + AoE gating |
| AvengingWrath, HammerOfWrath, LayOnHands | (c) | CD/execute/low-HP combos not expressed together |
| ~~Exorcism, HolyWrath, TurnEvil~~ ✅ CLEARED | (b→fired) | `undead_target` scenario (creature type 6; enemy_count 2 for HolyWrath) |
| BlessingOfProtectionAlly | (b) | ally-targeted |
| RighteousDefense | (b) | ally threat-transfer |

**retribution (9):** seal-twist lanes cleared by the seal-state scenarios;
the rest (b)/(c) seal-state; TurnEvil + Ret_HolyWrath_AoE cleared by
`undead_target`; the settings fixture (ranked #7) then cleared the 6 opt-in
lanes below (`blessings`/`seal_command_*` scenarios + `use_exorcism`).
| Strategy | Tag | Why |
|----------|-----|-----|
| ~~SealTwistBlood, SealTwistPrepCommand~~ ✅ CLEARED | (c)→fixed | `seal_twist_blood`/`seal_twist_prep` scenarios: `setting_overrides = { seal_twisting_enabled = true }` (now scenario-aware `get_any_setting` stub → `can_twist`), seal buffs (Command 27170 / Blood 31892), swing bands (0.4 ≤ 0.45 / 0.9 in (0.45, 1.2]), Judgement on CD (20271, 2.0s) for prep |
| Ret_BlessingFreedom_Ally/Self | (b) | snare-CC escape |
| ~~Ret_BlessingKings_Party/Self~~ ✅ CLEARED | (a→fired) | `blessings` scenario — `blessing_of_kings_self`/`_party` opt-ins (default false) via the ctx.settings fixture; the party lane's find_ally falls back to self in the battery (no party scan) (ranked #7) |
| Ret_HammerWrath_FleeingPvP | (b) | fleeing-PvP gated |
| ~~Ret_HolyWrath_AoE, TurnEvil, Exorcism~~ ✅ CLEARED | (b→fired) | `undead_target` scenario + `use_exorcism` opt-in via the settings fixture (ranked #7) |
| Consecration, Ret_Consecration_ManaDump | (c) | needs `enemy_count ≥ 2` + mana combo |
| ~~Ret_SealCommand_Primary, Ret_JudgeSecondary_CommandCleave, Ret_HotC_Opener_Judge~~ ✅ CLEARED | (c→fired) | `seal_command_apply` (`seal_preference="command"` via the fixture + Crusader seal map 27158, combat_time 3) and `seal_command_active` (Command seal 27170 + `context.enemies` fixture for secondary_target) (ranked #7) |
| ~~Ret_JudgementWisdom_LowMana~~ ✅ CLEARED | (c→fired) | incidental — `fsr_pause` scenario's mana 30 + buffs_up satisfy the mana ≤ 45 wisdom-seal combo (ranked #6) |
| Ret_Cleanse_Ally/Self, Ret_Purify_SelfFallback | (c) | self/ally affliction flags not set |
| ~~HitCapPriority~~ ✅ CLEARED (2026-08-08) | (c→fired) | `hit_cap_deficit` scenario — `hit_rating` 50 vs the 142 cap, shared matcher with the DPS copies (pinned) |

### shaman (16) — elemental 6 · enhancement 7 · restoration 3

**elemental (6):**
| Strategy | Tag | Why |
|----------|-----|-----|
| ElementalMastery | (c) | needs `setting == true` + `should_burst` + `mana_conserve==false` combo |
| ~~ManaEmergencyWand~~ ✅ CLEARED | (c→fired) | `mana_critical` scenario (`mana_pct = 4 < 5`) |
| ChainHeal | (c) | `context.group_injured` never set |
| EarthShockMoving, FrostShockMoving | (c) | needs moving + shock state |
| TotemicCall | (c) | totem-count state unmocked |
| TremorTotem | (b) | fear-CC — correctly silent |

**enhancement (7):**
| Strategy | Tag | Why |
|----------|-----|-----|
| GraceOfAirTotemTwist | (a) | opt-in totem-twist toggle |
| AutoAttack | (c) | battery mock `is_auto_attacking → true` — correctly reports already attacking |
| EarthShock | (c) | needs interrupt-mode target casting or Flame Shock DoT state |
| FireNovaReplacement | (c) | fire-totem state unmocked |
| ShamanisticRage | (c) | needs CD window + low mana/hp combo |
| ~~ManaEmergencyWand~~ ✅ CLEARED | (c→fired) | `mana_critical` scenario (`mana_pct = 4 < 10`) |
| ~~TotemicCall~~ ✅ **CLEARED (2026-08-08)** | (c→fired) | `totem_far` scenario — `ns.core` gains scenario-aware `time()`/`get_totem_info`/`get_visible_objects` (enh caches `NS.core` at load); totem_active feeds the has_totem gate and a far totem mock (vec3 30,30 = 1800 sq > 400) fires the recall. The table-form `my_pos.x` reads were CORRECT (get_position returns a vec3 table — verified vs auto_loot/targeting/EaxESP); the multi-value bug was prot's, fixed in the same pass |
| TremorTotem | (b) | fear-CC |

**restoration (5):** heal-scan stub + affliction flags cleared 8 lanes.
| Strategy | Tag | Why |
|----------|-----|-----|
| ~~ChainHeal, SmartHeal~~ ✅ CLEARED | (c→fired) | heal-scan stub (cluster/count + `select_heal`) in `group_light` |
| ~~Bloodlust, ManaTideTotem~~ ✅ CLEARED | (c→fired) | `group_emergency` (CD window) / `mana_tide_window` (healthy + low mana) |
| ~~NaturesSwiftness~~ ✅ CLEARED | (c→fired) | short-TTD target in `group_critical` (hp ≤ 30 → ttd 3) |
| ~~CureDisease, CurePoison, DiseaseCleansingTotem, PoisonCleansingTotem~~ ✅ CLEARED | (c→fired) | per-debuff `afflicted` flags → cleanse target |
| ~~PreemptiveChainHeal~~ ✅ FIXED | (d→fixed) | `state.entries`/`count` now stored in resto build_state (was never assigned — dead in live play too) |
| ChainLightning | (c) | DPS lane gated on group state |
| LightningShield | (c) | shield-buff state unmocked |
| ~~ManaEmergencyWand~~ ✅ CLEARED | (c→fired) | `mana_critical` scenario (`mana_pct = 4 < 5`) |
| ~~FSRPause~~ ✅ CLEARED | (c→fired) | `fsr_pause` scenario — ManaTide (16190) + Bloodlust (2825) on CD; `buff_stacks` added so WaterShield charges read 1 (no 0-charge refresh) (ranked #6) |
| ~~FriendlyTarget~~ ✅ CLEARED | (b→fired) | `friendly_target` scenario — `ns.get_friendly_target_entry` is now scenario-aware (friendly unit at 60%, below the 90 threshold) |
| TremorTotem | (b) | fear-CC |

### druid (29) — balance 6 · bear 8 · cat 9 · caster 0 · resto 6

**balance (6):**
| Strategy | Tag | Why |
|----------|-----|-----|
| MoonkinForm | (c) | form-switch state unmocked |
| HurricaneAoE | (c) | AoE helper + enemy count |
| ~~InsectSwarmSpread, MoonfireSpread~~ ✅ CLEARED | (c→fired) | **APPLIED (ranked #1)** — same TSHelper stub + `multidot` scenario (`balance_multidot_enabled` opt-in via the settings fixture; `NS.DruidSpells` seeded with the Moonfire/InsectSwarm rank ids) |
| RebirthBattleRez | (c) | needs dead ally |
| ~~RemoveCurse~~ ✅ CLEARED | (a→fired) | `auto_dispel` scenario — `balance_auto_dispel` opt-in (default false); reads `ctx.settings` DIRECTLY — the fixture merge mechanism (ranked #7) |
| PvP_Cyclone, PvP_EntanglingRoots, PvP_NaturesGrasp | (b) | PvP CC |

**bear (8):**
| Strategy | Tag | Why |
|----------|-----|-----|
| ChallengingRoar | (a) | dedicated `use_challenging_roar` toggle (default OFF) |
| Barkskin | (c) | needs low-HP + in-combat + non-bear state |
| EnrageCombat | (c) | rage + CD state combo |
| Swipe, SwipeAoE | (c) | `NS.aoe_target_meets` nil for druid — real AoE module doesn't install; also `spell_exists` always true |
| FaerieFirePull, FeralChargePull, PrePullEnrage | (b) | OOC pull openers |
| Growl | (b) | taunt — target already on the player (correctly silent) |

**cat (9):**
| Strategy | Tag | Why |
|----------|-----|-----|
| RipTrick, ShredTrick | (a) | opt-in `cat_use_rip_trick` / `cat_use_shred_trick` (default false) |
| MangleFiller | (c) | battery target hardwired `is_behind=true` → Shred always pre-empts |
| ClawFallback | (c) | `spell_exists(Mangle)` always true → unlearned-spell fallback never needed |
| RakeSnapshot, RipSnapshot | (c) | snapshot mechanics (stealth/CP windows) unmocked |
| ~~RemoveCurse~~ ✅ CLEARED | (a→fired) | `auto_dispel` scenario — `cat_auto_dispel` opt-in via the fixture (ranked #7); the DSL variant stays form-gated |
| Dash | (b) | OOC movement |
| TrackHumanoids | (b) | OOC tracking |
| TravelForm | (b) | OOC travel |

**resto (7):** (d) fixed (Healthstone); 5 lanes cleared by the heal-scan stub.
| Strategy | Tag | Why |
|----------|-----|-----|
| ~~Healthstone~~ ✅ FIXED | (d→fixed) | `resto_state.healthstone_ready` now assigned via `first_ready_item` |
| ~~SwiftmendEmergency, NaturesSwiftnessHealingTouch, NaturesSwiftness~~ ✅ CLEARED | (c→fired) | heal-scan stub + `group_emergency` (HoT buffs + hp ≤ 50/30) / `group_critical` (no buff, ttd 3) |
| ~~TranquilityEmergency~~ ✅ CLEARED | (c→fired) | `group_emergency` (3 targets ≤ 25) |
| ~~LeaveTreeForDirectHeal~~ ✅ CLEARED | (c→fired) | heal-scan entries + should_dance_caster path in `group_critical` |
| ~~FSRPause~~ ✅ CLEARED | (c→fired) | `fsr_pause` scenario — Rebirth (26994) + Innervate (29166) on CD. NOTE: RebirthBattleRez carpet-bombs every in-combat scenario (fires ~65) — the battery has no dead-ally model, and the real DSL matcher has NO dead-ally check (in_combat + group + spell_ready only), so it is a live-play (d) dead-lane candidate, not just a mock gap; a follow-up should classify and fix it (ranked #6) |
| ~~FriendlyTarget~~ ✅ CLEARED | (b→fired) | `friendly_target` scenario — `ns.get_friendly_target_entry` is now scenario-aware (friendly unit at 60%, below the 90 threshold) |
| ~~InnervateHealer~~ ✅ CLEARED | (c→fired) | friend mocks gain `get_class` via the `friend_class` scenario override + `ns.safe_field` fixed to (obj, key) semantics (ranked #4, 2026-08-07) |
| LifebloomLetBloom | (c) | Lifebloom expire state |
| TravelFormReposition | (c) | movement + form state |
| BearFormFocusedByMelee | (b) | melee-pressure self-defensive |
| CycloneEnemyHealer | (b) | PvP enemy-healer CC |
| EntanglingRootsMelee, NaturesGraspMelee | (b) | melee-snare escapes |

### hunter (10) — beast_mastery 6 · marksmanship 2 · survival 2

**beast_mastery (6):**
| Strategy | Tag | Why |
|----------|-----|-----|
| ~~AdaptiveRotation~~ ✅ CLEARED | (a→fired) | `hunter_toggles` scenario — `use_adaptive_rotation` opt-in via the fixture (ranked #7) |
| FeignDeath, Misdirection | (b) | threat management — correctly silent |
| ~~ExplosiveTrap, Volley~~ ✅ CLEARED | (a→fired) | `hunter_toggles` scenario — `use_explosive_trap`/`use_volley` opt-ins + 4 enemies for the AoE gates (ranked #7) |
| ~~HitCapPriority~~ ✅ CLEARED (2026-08-08) | (c→fired) | `hit_cap_deficit` scenario — `hit_rating` 50 vs the 142 cap, shared matcher with the DPS copies (pinned) |
| Readiness | (c) | needs `rapid_fire_cd >= 60` — mock cooldowns report 0 |
| SerpentStingRefresh | (c) | needs `has_serpent_sting` debuff + remains ≤ 3 |
| Trinket | (c) | `NS.TrinketManager` unmocked (returns no equipped trinkets) |

**marksmanship (2):** (d) fixed (BestialWrath); AdaptiveRotation cleared (ranked #7).
| Strategy | Tag | Why |
|----------|-----|-----|
| ~~AdaptiveRotation~~ ✅ CLEARED | (a→fired) | `hunter_toggles` scenario — `use_adaptive_rotation` opt-in; matcher returns `c.target` (truthy — battery dispatch now counts truthy returns, ranked #7) |
| ~~BestialWrath~~ ✅ FIXED | (d→fixed) | now gates on `NS.spell_exists(ACTION.BestialWrath)` |
| InCombatAimedShot | (c) | leveling/aimed-shot state unmocked |
| Readiness | (c) | `rapid_fire_cd >= 60` not reachable |
| ~~AspectOfTheViper~~ ✅ CLEARED | (c→fired) | `mana_critical` scenario (low mana → Viper switch) |

**survival (2):** AdaptiveRotation cleared (ranked #7).
| Strategy | Tag | Why |
|----------|-----|-----|
| ~~AdaptiveRotation~~ ✅ CLEARED | (a→fired) | `hunter_toggles` scenario — `use_adaptive_rotation` opt-in; truthy matcher return (ranked #7) |
| Readiness | (c) | `rapid_fire_cd >= 60` not reachable |
| SerpentStingRefresh | (c) | needs serpent debuff + remains ≤ 3 |
| ~~AspectOfTheViper~~ ✅ CLEARED | (c→fired) | `mana_critical` scenario (low mana → Viper switch) |

---

## Notable (c) battery gaps specific to healers

1. ~~**`NS.PLAYER_UNIT = {}` empty-stub clobber**~~ **APPLIED 2026-08-07** —
   `PLAYER_UNIT` now carries `get_health_percentage` (and `get_health`)
   reading the state bank → `ctx.hp`. holy `Healthstone`/`DesperatePrayer`/
   `BindingHeal` + smite `Healthstone`/`SoloPowerWordShield` fire (5 lanes;
   `SoloRenew` still gated on other state).
2. ~~**Heal-scan + prediction modules unmocked**~~ **APPLIED 2026-08-07** —
   the per-class `Healing` modules now expose a state-bank-driven
   `scan_healing_targets` (entries from `friends_hp`, tank = entry[2], player
   self-entry), real `NS.healing_*` rankers, `select_heal`/`get_cleanse_target`/
   `all_members_above_hp`, and group scenarios. ~15 `*Heal` lanes cleared
   (holy CoH/Lightwell/RenewTank, disc BH/GH/PoH/EmergencyPWS, druid
   Swiftmend/Tranq/NS/LeaveTree, shaman ChainHeal/SmartHeal/Bloodlust/
   ManaTide/NaturesSwiftness). `PreHeal`/`Preemptive*` then cleared via the
   `pushback` scenario (`GetEnemiesInRange` stub → `_check_pushback` true,
   tank 72 in [60,95]) + `state.entries`/`count` now stored in disc/holy/resto
   build_state (a live-play (d) fix — those specs never assigned it, so
   `PreemptiveHeal.match` could not fire in-game either). `FSRPause` ×5 then
   cleared via the scenario-driven `FsrManager` stub + `fsr_pause` scenario.
3. ~~**Affliction flags**~~ **APPLIED 2026-08-07** — per-debuff-type
   `afflicted` table (poison/disease/curse/magic) drives entry flags +
   `Healing.has_disease/has_poison/has_curse/has_magic/`
   `has_dangerous_dispel`; `friends_afflicted` scenario now carries all four
   types. holy `CureDisease`/`AbolishDisease`/`DispelMagic`, shaman
   `CureDisease`/`CurePoison`/`DiseaseCleansingTotem`/`PoisonCleansingTotem`,
   paladin `PurifySelf` clear. `MassDispel` then cleared via the
   `party_members` wiring (ranked #3). (`RemoveCurse` cleared via the
   `auto_dispel` opt-in fixture, ranked #7.)
4. ~~**`mana_critical` scenario missing**~~ **APPLIED 2026-08-07** — new
   `mana_critical` scenario sets `mana_pct = 4` (strict `< 5` gates; a 5
   would not trip elemental/restoration/holy). `ManaEmergencyWand` ×3 + holy
   `ManaBelow5Wand` fire, plus hunter `AspectOfTheViper` ×2.
5. ~~**Creature-type scenarios missing**~~ **APPLIED 2026-08-07** — new
   `undead_target` scenario (`target_creature_type = 6`, enemy_count 2).
   `ShackleUndead` ×4, `TurnEvil` ×2, prot `Exorcism` + `HolyWrath`, ret
   `Ret_HolyWrath_AoE` fire (9 lanes). Correction: the earlier note said
   "classification = 3 (undead)", but the specs read `get_creature_type`
   and undead is **6** (3 is DEMON). retribution `Exorcism` is opt-in
   (`use_exorcism` default false) and later cleared via that opt-in in this
   scenario (ranked #7). `JudgementOfLightBoss`/`JudgementOfWisdomBoss`
   still need a boss flag (separate item).
6. ~~**Multi-target DoT spread**~~ **APPLIED 2026-08-07** — the `enemies`
   list is empty; fixed with the `TSHelper.get_dps_targets` stub
   (bank-backed → `ctx.enemies`) + unit-aware `debuff_up`/`debuff_remains`
   + `multidot`/`shadow_multidot`/`shadow_cleave` scenarios → shadow
   `MultiDot*`/`*Spread` ×4 + balance `*Spread` ×2 cleared (see Status #8).
7. **`is_behind` hardwired true** — cat `MangleFiller` always pre-empted by
   Shred.
8. **`spell_ready` always true** — kills leveling fallbacks
   (`ClawFallback`, `InCombatAimedShot`) and `Readiness` (needs
   `rapid_fire_cd >= 60`).
9. **`buffs_up` all-or-nothing** — `ClearcastingGreaterHeal`,
   `SurgeOfLightSmite`, `LightGrace*`, seal-state lanes need per-buff flags.
10. **`NS.TrinketManager` unmocked** — hunter `Trinket` lane.

## Highest-ROI battery upgrades

1. ✅ **APPLIED** — `NS.PLAYER_UNIT` gains `get_health_percentage` → `ctx.hp`.
   Cleared holy `Healthstone`/`DesperatePrayer`/`BindingHeal` + smite
   `Healthstone`/`SoloPowerWordShield` (5 lanes; `SoloRenew` still gated).
2. ✅ **APPLIED** — `mana_critical` scenario (`mana_pct = 4`, strict `< 5`).
   Cleared `ManaEmergencyWand` ×3 + holy `ManaBelow5Wand` + hunter
   `AspectOfTheViper` ×2.
3. ✅ **APPLIED** — state-bank heal-scan stub (`scan_healing_targets` from
   `friends_hp`, tank = entry[2], player self-entry, real `NS.healing_*`
   rankers, `select_heal`/`all_members_above_hp`) + `group_*`/`tank_low`/
   `mana_tide_window`/`group_emergency` scenarios. Cleared 17 heal-scan lanes:
   holy CoH/Lightwell/RenewTank, disc BH/GH/PoH/EmergencyPWS, paladin
   DivineFavorHolyShockCombo, druid Swiftmend/Tranq/NS/NSHealingTouch/
   LeaveTree, shaman ChainHeal/SmartHeal/Bloodlust/NaturesSwiftness (+8
   affliction lanes, item 5 = 25 total; the 3 stub-regressions disc
   PainSuppression/PWSTank + shaman ManaTideTotem were restored via
   `tank_low`/`mana_tide_window`, net 0).
4. ✅ **APPLIED** — `undead_target` scenario (`target_creature_type = 6`,
   enemy_count 2). Cleared `ShackleUndead` ×4, `TurnEvil` ×2, prot
   `Exorcism` + `HolyWrath`, ret `Ret_HolyWrath_AoE` (9 lanes).
5. ✅ **APPLIED** — per-debuff-type `afflicted` flags (poison/disease/curse/
   magic) → entry flags + `Healing.has_disease/has_poison/has_curse`/
   `has_dangerous_dispel`; `friends_afflicted` carries all four types. Cleared
   holy CureDisease/AbolishDisease/DispelMagic, shaman CureDisease/CurePoison/
   both cleansing totems, paladin PurifySelf (8 lanes).
6. `is_behind` scenario toggle → cat filler lanes.

## Focused follow-up triage — healer (c)/(b) next-up (2026-08-07)

Re-verified every named lane from the open lists against the live battery
(100 non-DPS never-firing, 103 scenarios). Corrections first: **`PreHeal` /
`Preemptive*` are no longer never-firing** — all 5 were cleared in the prior
turn (`state.entries`/`count` stored in disc/holy/resto build_state + the
`pushback` scenario). `FSRPause` ×5 (disc, holy, shaman/resto, druid/resto,
paladin/holy) is now **CLEARED** by the `FsrManager` stub + `fsr_pause`
scenario (ranked #6).

### Deserve a battery scenario (ranked in Status below)

| Lane | Specs | Blocker (probe-verified) | Class |
|------|-------|--------------------------|-------|
| ~~`LightGraceBuild`~~ ✅ CLEARED / ~~`LightGraceChain`~~ ✅ CLEARED | paladin/holy | deficit fix (`deficit = max(0, 100 - effective_hp)`, was hardcoded 0) + per-buff `lights_grace` scenario (`buff_remains_map` { [31834] = 1.5 } → `NS.buff_remains`); Build and Chain both clear | (c)→fixed |
| ~~`MassDispel`~~ ✅ CLEARED | priest/holy | `context.party_members` now built from the heal-scan friends in `friends_afflicted` (was empty, `party=0`), so the dangerous-magic scan finds a target; disc's variant has no scan and already fires | (c)→fixed |
| ~~`InnervateHealer`~~ ✅ CLEARED | druid/resto | `friend_class = 11` override gives the group-scenario friends `get_class`, and `ns.safe_field` now has real (obj, key) semantics (was returning the whole unit); `innervate_target` picks the low-mana healer ally in `mana_tide_window` | (c)→fixed |
| ~~`SealTwistBlood`/`SealTwistPrepCommand`~~ ✅ CLEARED | paladin/ret | `seal_twist_blood` (Command up, swing 0.4) + `seal_twist_prep` (Blood up, Judgement CD 2.0s, swing 0.9) scenarios drive `can_twist` via `setting_overrides` and the seal buffs via `buff_remains_map`; each lane fires ONLY in its own scenario | (c)→fixed |
| ~~`FSRPause`~~ ✅ CLEARED | ×5 healer specs | scenario-driven `FsrManager` stub (fsr_inside / regen delta 20 / pause_ok; buffs_up blocks shields+auras; PoM map; on_cd ManaTide/Innervate/Rebirth/Bloodlust) — each fires ONLY in `fsr_pause` | (c)→fixed |

### Correctly silent (no scenario worth building)

| Lane | Specs | Reason |
|------|-------|--------|
| ~~`RemoveCurse`~~ ✅ CLEARED | druid/balance, cat | `auto_dispel` scenario — `balance_auto_dispel`/`cat_auto_dispel` opt-ins via the ctx.settings fixture (ranked #7) |
| ~~`Ret_SealCommand_Primary`~~ ✅ CLEARED | paladin/ret | `seal_command_apply` scenario — `seal_preference="command"` via the fixture (ranked #7) |
| ~~`Fade`~~ ✅ CLEARED | priest ×3 (disc, holy, shadow) | **APPLIED (ranked #12)** — `threat_high` scenario (`threat_pct 95` ≥ fade threshold 80); same threat-drop family as Soulshatter |
| ~~`FriendlyTarget`~~ ✅ CLEARED | disc, holy, druid/resto, shaman/resto | `friendly_target` scenario — scenario-aware `ns.get_friendly_target_entry` (ranked-(b) top fixture, 2026-08-08) |
| `MountedProtection`, `EncounterReactions` | priest/holy | OOC-mounted / Karazhan boss IDs — (b) |
| PvP / snare / ally / CC lanes (`PvP_*` ×n, `BlessingOfFreedomSnare`, `BlessingOfProtection*Ally`, `Ret_Cleanse_Ally`, `Ret_BlessingFreedom_*`, `TremorTotem`, `CycloneEnemyHealer`, `EntanglingRootsMelee`, `NaturesGraspMelee`, `BearFormFocusedByMelee`, `Ret_HammerWrath_FleeingPvP`) | various | threat/snare/ally-target/CC/PvP state correctly unmodeled — (b) |
| `DevouringPlague`, `Starshards`, `SoloPsychicScream` | priest/smite | undead-race / night-elf racial / fear-CC state — (b) |

## Status

All planned upgrades + (d) fixes are applied. Non-DPS never-firing is
down to **87** (all-spec **100** — the DPS defensive-casting upgrade,
2026-08-08, cleared 6 DPS lanes; the pvp-combo upgrade then cleared
druid/cat `Dash` — the `pvp_gap_close` scenario supplies the is_pvp +
range-in-(5,25] band its DSL gate needs; the opt-in fixture scenarios then
cleared 5 DPS lanes; the stat/weapon mocks then cleared hunter/BM +
paladin/retri `HitCapPriority` — shared 142-cap matcher, hit_cap_deficit
scenario; the opt-in close-out then cleared the final 6 (a) lanes —
arms/fury `SunderArmor`, `CommandingShout` ×2, combat/subtlety
`ExposeArmor` — via the `arms_sunder`/`fury_sunder`/`commanding_shout`/
`expose_armor` scenarios; the elite_low_self combo scenario then cleared
prot `IntimidatingShout`; the pvp_disarm scenario + `target:get_class()` mock cleared prot `Disarm`; the `group_ally_low` scenario + a real matcher fix (the and-form `x, y = f and f()` truncation that deaded prot `Intervene` even on the real API) cleared prot `Intervene`; the WarriorSpells `Devastate` id seed + `sunder_fallback` on_cd scenario then cleared the final DPS lane prot `SunderArmor`; the `shadow_caster` scenario (is_pvp + `target_class` 9 + hp 50, reusing the `pvp_disarm` `get_class` mechanism) then cleared warlock `ShadowWard` ×2; the `totem_far` battery path then cleared shaman/enh `TotemicCall` — all-spec to **105**). **Contract finding (2026-08-08):** the follow-up probe RESOLVED the TotemicCall lead in the REVERSE direction — `get_position` returns ONE vec3 table `{x,y,z}` (verified vs shared/auto_loot `p.x`, shared/targeting `pos.x`, EaxESP `base.x or base[1]`, test/EaxProfessions object_scanner), so shaman's table-form `my_pos.x` reads were **CORRECT**. The truncation-family bug was the OTHER side: prot's party scan + Intervene matcher captured multi-values (`dy/ay = nil` against a table API) and were dead in live play; both now read the table fields (protection:426-448, 767-780), the battery me/friend mocks return the vec3 table (with [1]/[2] aliases), and `ns.core` gained scenario-aware `time()`/`get_totem_info`/`get_visible_objects` + a `get_owner` on visible enemy mocks so the enh recall scan is fully observable. Ranked next-up list
(from the focused triage above; items 1-8 APPLIED):

1. ~~**Fix the heal-scan `deficit` bug**~~ **APPLIED 2026-08-07** — entry
   builder now computes `deficit = max(0, 100 - effective_hp)` (mirrors the
   real modules' `max_hp - current_hp` at the battery's percentage scale).
   `LightGraceBuild` cleared (219 → 218, 0 regressions, no other deficit-gated
   lanes surfaced). Pinned by `tests/test_deficit_lane_regression.lua`.
2. ~~**Per-buff state scenario**~~ **APPLIED 2026-08-07** — new
   `buff_remains_map` override ({ [buff_id] = seconds }) drives
   `NS.buff_remains`/`NS.has_player_buff` before the buffs_up fallback, plus
   the `lights_grace` scenario (id 31834 at 1.5s). `LightGraceChain` cleared
   (218 → 217, 0 regressions; all other specs byte-identical). Pinned by
   `tests/test_lights_grace_lane_regression.lua`. The same mechanism covers
   `ClearcastingGreaterHeal`/`SurgeOfLightSmite` (clearcasting/Surge buff),
   `InnerFocus`, `LifebloomLetBloom`.
3. ~~**`party_members` wiring**~~ **APPLIED 2026-08-07** —
   `context.party_members` is built from the heal-scan friend units in the
   afflicted scenario; `MassDispel` cleared (217 → 216, 0 regressions; paladin
   ally-scan lanes untouched). Pinned by
   `tests/test_party_members_lane_regression.lua`.
4. ~~**Friend class-id scan**~~ **APPLIED 2026-08-07** — `friend_class = 11`
   override adds `get_class` to the group-scenario friends, and `ns.safe_field`
   was fixed to real (obj, key) semantics (the old (value, default) shape made
   `unit_class_id` pcall the whole unit — always nil). `InnervateHealer`
   cleared (216 → 215, 0 regressions; `InnervateSelf` stays observable in
   low_mana/mana_critical). Pinned by
   `tests/test_friend_class_scan_lane_regression.lua`.
5. ~~**Seal-state scenario**~~ **APPLIED 2026-08-07** — new
   `setting_overrides` override ({ [setting_key] = value }) drives the
   `get_any_setting` stub (unconfigured keys keep returning nil, so
   `can_twist` stays false outside the scenarios), plus the
   `seal_twist_blood` (Command 27170, swing 0.4) and `seal_twist_prep`
   (Blood 31892, swing 0.9, Judgement 20271 on CD 2.0s) scenarios.
   `SealTwistBlood` + `SealTwistPrepCommand` cleared (215 → 213, 0
   regressions; each fires ONLY in its own scenario). Pinned by
   `tests/test_seal_twist_lane_regression.lua`.
6. ~~**`FsrManager` stub**~~ **APPLIED 2026-08-07** — preload a
   scenario-driven stub for `shared/fsr_manager_sylvanas` (state-bank-backed
   in `build_ns`, restored after spec load) + the `fsr_pause` scenario
   (mana 30 / healthy group / buffs_up / PoM map 33076 / setting_overrides
   `holy_refresh_enabled`+`holy_blessing_light` false / on_cd ManaTide 16190,
   Innervate 29166, Rebirth 26994, Bloodlust 2825). `FSRPause` ×5 cleared
   (213 → 207, 0 regressions; each fires ONLY in `fsr_pause`) + retri
   `Ret_JudgementWisdom_LowMana` (incidental). Also fixed `ns.get_setting`
   (scenario-aware — setting_overrides now flow through spec_kit.setting)
   and added `ns.buff_stacks`. Pinned by
   `tests/test_fsr_lane_regression.lua`.
7. ~~**Settings modeling**~~ **APPLIED 2026-08-07** — `setting_overrides` now
   **merges into `ctx.settings`** in `build_context_for`, one fixture that
   covers all three setting channels (direct `ctx.settings[key]` reads,
   `spec_kit.setting`, DSL `{type="setting"}` conditions — each falls back
   to `context.settings` first). New scenarios: `auto_dispel`
   (`balance_auto_dispel`/`cat_auto_dispel`), `blessings`
   (`blessing_of_kings_self`/`_party`), `seal_command_apply`
   (`seal_preference="command"`, Crusader seal 27158, combat_time 3),
   `seal_command_active` (Command seal 27170 + the `context.enemies`
   fixture for `secondary_target`), `hunter_toggles`
   (`use_adaptive_rotation`/`use_volley`/`use_explosive_trap`, 4 enemies),
   plus `use_exorcism` added to `undead_target`. Supporting fixture fixes:
   `context.enemies` populated for 2+ enemy scenarios, `seal_command_apply`
   sets `combat_time = 3` (HotC's `< 8` gate; the global default stays 30),
   and the dispatch now counts **truthy**
   matcher returns (MM/surv `AdaptiveRotation` return `c.target` — a
   mock-fidelity fix; the real engine already treats truthy as a hit). **13
   lanes cleared (207 → 194, 0 regressions, 0 dispatch errors)**:
   AdaptiveRotation ×3, Exorcism, ExplosiveTrap, RemoveCurse ×2,
   BlessingKings ×2, `Ret_HotC_Opener_Judge`,
   `Ret_JudgeSecondary_CommandCleave`, `Ret_SealCommand_Primary`, Volley —
   each fires ONLY in its intended scenario (probe-verified). Pinned by
   `tests/test_settings_fixture_lane_regression.lua`.
8. ~~**Multi-target DoT spread model**~~ **APPLIED 2026-08-07** — preload a
   `shared/ts_helper_sylvanas` stub whose `get_dps_targets` returns the
   scenario's enemy list (`ctx.enemies`, populated for 2+ enemy scenarios),
   plus unit-aware `debuff_up`/`debuff_remains` (`debuff_remains_map` marks
   the primary dotted, peers clean — the old `buffs_up` shortcut dotted
   EVERY target and deadlocked the spread matchers). New scenarios:
   `multidot` (2 enemies, ttd 30 → auto-agony, `balance_multidot_enabled`),
   `shadow_multidot` (`shadow_multidot_mode = 2`), `shadow_cleave`
   (`shadow_combat_mode = "cleave"`, 3 enemies). Also seeded
   `NS.DruidSpells` (Moonfire/InsectSwarm rank ids — the balance spreads
   gate on the spell tables existing). **6 non-DPS lanes cleared (194 → 183,
   0 regressions)**: shadow `MultiDotSWP`/`MultiDotVT`/`SWPSpread`/
   `VTSpread` ×4 + balance `InsectSwarmSpread`/`MoonfireSpread` ×2.
   SWPSpread/VTSpread also fire in any 3-enemy scenario (shadow auto-detects
   cleave — realistic, not a leak). Pinned by
   `tests/test_multidot_lane_regression.lua`. (The DPS-report ranked
   #3/#4/#5 scenarios — `wand_low_mana`, `ab_stack_conserve`,
   `battle_ready` + map-aware `ns.buff_up` — were applied in the same pass;
   they clear DPS-only lanes and pin the all-spec total at **180**, 0
   regressions, via `tests/test_combat_battery_regression.lua`.)

---

## Campaign summary (2026-08-08)

Final state of the triage-to-clear campaign (behavioral battery, 31 specs, **135 scenarios**, 0 load failures).

- **Never-firing chain:** 304 → **100** (DPS 13 + non-DPS 87). Every category-(d) dead lane found and FIXED — including the prot `Intervene` truncation bug, reclassified (b)→(d) live during the sweep. Zero (a) opt-in and zero (d) lanes remain.
- **Current classification of the 100:** **(b) 38 · (c) 62 · (a) 0 · (d) 0.** (b) = PvP/stealth/OOC/situational — correctly silent vs the PvE-shaped scenario set; (c) = mock limitations that work in live play; none are dead code.

**Per-spec buckets (never-firing / of which (b)):**

| Spec | Never | (b) | Spec | Never | (b) |
|---|---|---|---|---|---|
| druid balance | 6 | 3 | paladin holy | 8 | 2 |
| druid bear | 8 | 4 | paladin protection | 8 | 2 |
| druid caster | 0 | — | paladin retribution | 8 | 3 |
| druid cat | 8 | 2 | priest discipline | 0 | — |
| druid resto | 6 | 4 | priest holy | 4 | 2 |
| hunter beast_mastery | 5 | 2 | priest shadow | 3 | 1 |
| hunter marksmanship | 2 | 0 | priest smite | 4 | 2 |
| hunter survival | 2 | 0 | shaman elemental | 6 | 1 |
| mage arcane | 2 | 2 | shaman enhancement | 6 | 1 |
| mage fire | 2 | 2 | shaman restoration | 3 | 1 |
| mage frost | 5 | 2 | warlock affliction | 3 | 3 |
| rogue ×3 | 0 | — | warlock demonology | 1 | 1 |
| warrior ×4 | 0 | — | warlock destruction | 0 | — |

**Validation:** 466 rotation suites / 461 pass (5 pre-existing env/data-file gaps); 33 battery regression suites pin the unblocked lane families.

**Ranked remaining-(b) lanes** (all correctly silent vs the scenario set; ranked by cost-to-clear):

1. ~~warlock `ShadowWard` ×2~~ ✅ **APPLIED 2026-08-08** — the `shadow_caster` scenario (is_pvp + `target_class` 9 + hp 50) reuses the `pvp_disarm` `get_class` mechanism; pinned by `tests/test_shadowward_lane_regression.lua`.
2. ~~`FriendlyTarget` ×5~~ ✅ **APPLIED 2026-08-08** — the `friendly_target` scenario (`friendly_target_hp` 60, keyed on the hp alone — deliberately no boolean, which would collide with `healing_sylvanas.lua:454` reading `context.friendly_target` as a unit) makes `ns.get_friendly_target_entry` scenario-aware (real contract: `core/units.lua:129` — `{ unit, hp_pct, effective_hp, is_player }`); cleared disc + holy priest, holy paladin, resto druid + shaman. Pinned by `tests/test_friendly_target_lane_regression.lua`. (The report's ×4 count predates the paladin/holy row; all 5 lanes cleared.)
3. mage `Blink` ×2 (arcane, frost) — a `self_rooted_snared` state key.
4. mage `Polymorph` ×2 (arcane, fire) — a `cc_target`/humanoid `target_class = 6` scenario.
5. warlock `Seduction` (demo) — `pet_type_succubus` + `is_pvp` (partial: `destro_pet_succubus` exists).
6. affliction `PvP_CurseExhaustion`/`PvP_CurseTongues`/`CC_HowlOfTerror` — `is_pvp` + `melee_on_you` + `enemy_caster` combo (one scenario, 3 lanes).
7. druid PvP/melee-snare family (`PvP_Cyclone`/`PvP_EntanglingRoots`/`PvP_NaturesGrasp`, `EntanglingRootsMelee`/`NaturesGraspMelee`, `BearFormFocusedByMelee`, `CycloneEnemyHealer`) — PvP/snare CC state.
8. paladin snare/ally family (`BlessingOfFreedomSnare`, `BlessingOfProtectionFocusedAlly`, `BlessingOfProtectionAlly`, `RighteousDefense`, `Ret_BlessingFreedom` ×2, `Ret_HammerWrath_FleeingPvP`) — snare/ally-target state.
9. shaman `TremorTotem` ×3 — fear-CC state.
10. priest situational (`MountedProtection`, `EncounterReactions`, `SWDCCBreak`, `DevouringPlague`, `Starshards`) — mounted/boss-ID/fear/undead-race/night-elf racial.
11. druid OOC pulls/taunts/travel (`FaerieFirePull`, `FeralChargePull`, `PrePullEnrage`, `Growl`, `TrackHumanoids`, `TravelForm`) + hunter BM `FeignDeath`/`Misdirection` — OOC/threat state.
12. mage `ManaGemConjure` ×2 — correctly suppressed (gem always available); **do not re-triage**.

**Stale-content corrections (2026-08-08):** the older "Category counts (current)" paragraphs in both reports (and the embedded per-class counts) were intermediate snapshots and are superseded here; the DPS focused-triage rows for `Feint`/`FeintAoE`/`Blind` (cleared via `threat_high`/`defensive_casting`) and the non-DPS per-spec `FriendlyTarget` (c) tags (unified to (b) — requires manual party-frame selection) were stale and are corrected above.

---

## Focused follow-up triage — remaining (c) mock-limitation lanes (2026-08-08)

Scope: the 39 open `(c)` rows (≈54 lanes) left in the non-DPS report; the DPS report has **0** open `(c)` rows (all 5 cleared/reclassified). Every lane below was probed to its exact matcher gate (via `behavioral_audit.lua` stubs + spec build_state). Split into (A) **reclassifications that need no fixture**, (B) **ranked battery fixtures by lanes-per-scenario**, (C) **needs-probe / low-value**.

### (A) Reclassifications — not battery mock-gaps (≈9 lanes leave (c))

| Lanes | Verdict | Probe evidence |
|---|---|---|
| prot `AvengerShield`, `Judgement`, `SealOfCommandAoE`, `HammerOfWrath` ×4 | **(a) opt-in settings** | matchers gate on `spec_kit.setting_bool(context, "prot_avenger_shield", false)` / `"prot_judgement"` (protection:862, 891), `"prot_seal_of_command"` (protection:969), DSL `"prot_hammer_of_wrath"` default **false** (protection:1372) |
| ret `Consecration`, `Ret_Consecration_ManaDump` ×2 | **(a) opt-in** | `"use_consecration"` default false (retribution:798) + `retri_consecration_targets` ≥ 3 |
| bear `Barkskin` | **(a) opt-in** | `s.use_barkskin` dedicated toggle, default OFF (bear:596) |
| shadow `DispelMagic` | **correctly disabled** | matcher hardcodes `return false` — "Disabled: middleware PartyDispelMagic already handles self + party dispel" (shadow:1039-1046). Not a mock gap |
| enh `AutoAttack` | **correctly silent** | battery `is_auto_attacking → true` — already attacking, so the lane never needs to fire. Not a gap |

Net: these 9 rows drop the (c) inventory without code changes (2 rows do need settings-fixture pins if we want them observable — see (B) #2).

### (B) Ranked next-up fixtures (by lanes-per-scenario)

1. **Hunter `Readiness` ×3** (BM DSL + MM + survival) — **3 lanes / 1 scenario.**
   Probe: MM/survival `readiness_matches` = `use_readiness` (default true) + in_combat + `readiness_ready` + **`rapid_fire_cd >= 60`** (marksmanship:489-499, survival:489-496); BM DSL identical (beast_mastery:1174-1184). `rapid_fire_cd` derives from `cooldown_remains(RapidFire 3045)` — already bank-aware via `on_cd`.
   Fixture: `{ name = "readiness_window", overrides = { on_cd = { [3045] = 61 }, ttd = 60, target_ttd = 60 } }` → all three MATCH. (MM also needs `ttd >= 20`, satisfied.)
2. **Prot opt-in pins ×4** (AvengerShield/Judgement/SealOfCommandAoE/HammerOfWrath) — **4 lanes / 2 scenarios.**
   Fixture: `setting_overrides = { prot_avenger_shield = true, prot_judgement = true, prot_seal_of_command = true, prot_hammer_of_wrath = true }` + `enemy_count = 3` (SealOfCommandAoE ≥ 3, protection:971) + `hp = 15` (HammerOfWrath execute ≤ 20, protection:1375). Single scenario may suffice; split if AoE gates fight execute gates.
3. **Ret cleanse/purify ×3** (`Ret_Cleanse_Self`, `Ret_Purify_SelfFallback`, `Ret_Cleanse_Ally`) — **3 lanes / 1 scenario.**
   Probe: matchers gate `has_player_debuff(COMMON_CLEANSE)` (retribution:595-603) — battery only models `friends_afflicted`, never a **self** debuff flag.
   Fixture: new known key `self_afflicted = true` (+ friends_afflicted for the Ally variant) → 3 lanes clear.
4. **Hunter `SerpentStingRefresh` ×2** (MM + survival) — **2 lanes / 1 scenario.**
   Probe: `serpent_sting_refresh_matches` = in_combat + `has_serpent_sting` + `debuff_remains(SERPENT_STING_DEBUFF) <= 3` + ttd ≥ 6 (survival:411-419).
   Fixture: `debuff_remains_map = { [serpent_id] = 2 }` + `ttd = 30` (unit-aware map already exists from the multidot work).
5. **Holy `ClearcastingGreaterHeal` + smite `SurgeOfLightSmite` ×2** — **2 lanes / 1 scenario.**
   Probe: both gate on per-buff state (`has_clearcasting` / Surge-of-Light buff) — `buffs_up` all-or-nothing can't express "one buff up".
   Fixture: `buff_remains_map = { [clearcast_id] = 1, [surge_id] = 1 }` (per-buff mechanism already built for lights_grace) → 2 lanes.
6. **Elem `EarthShockMoving` + `FrostShockMoving` ×2** — **2 lanes / 1-2 scenarios.**
   Probe: EarthShockMoving gates `is_moving` + **`elemental_interrupt_reserve` setting (default TRUE)** (elemental:247-252); FrostShockMoving gates `is_moving` + `is_pvp` (elemental:254-257).
   Fixture: `{ is_moving = true, setting_overrides = { elemental_interrupt_reserve = false } }` (EarthShockMoving) + `{ is_moving = true, is_pvp = true }` (FrostShockMoving).
7. **Bear `Swipe`/`SwipeAoE` ×2** — **2 lanes / 1 scenario (probe-flagged).**
   Probe: `swipe_cleave_matches` = aoe_target_meets (stub true) + **`spell_exists(Lacerate) and lacerate_stacks < 3 and target_ttd > 8 → false`** (bear:736-741) + `rage_allows_filler`. Battery `target_ttd` default 60 blocks; needs `{ target_ttd = 5, enemy_count = 4 }` + `debuff_stacks = 3` (lacerate stacks) if the stack read routes through the battery `get_debuff_stacks` — **needs one wiring probe before committing**.
8. **MM `InCombatAimedShot`** — **1 lane / 1 trivial scenario.**
   Probe: gates `combat_time <= 0.5` + `aimed_shot_ready` + no serpent + `can_cast_before_auto` (guarded: HunterClipTracker lacks `ms_until_auto` → true). Battery default `combat_time = 30` blocks.
   Fixture: `{ combat_time = 0.2, target_hp = 100, buff_remains_map = { [14114] = 0 } }` (SerpentSting debuff down) → clears.
9. **Elem `ChainHeal`** — **1 lane / 1 scenario.**
   Probe: gates `context.group_injured` (elemental:313) — never set.
   Fixture: known key `group_injured = true` + `friends_hp = { 30, 100, 100 }` → clears. (Mirrors the heal-scan wiring; check no other group-gated lane leaks.)
10. **Resto `ChainLightning`** — **1 lane / 1 scenario (probe-flagged).**
    Probe: `solo_damage_enabled` needs `is_solo` (default true) + `enemy_count >= 3` + `mana >= 45` + lowest healthy (restoration:490-496, 528-535). Default ctx has enemy_count 1 → never reaches.
    Fixture: `{ enemy_count = 4, is_solo = true, mana_pct = 100 }` → likely clears; verify `lowest` from heal-scan stays healthy.
11. **Shadow `HolyNovaAoE`** — **1 lane / 1 scenario.**
    Probe: needs `combat_mode == "aoe"` — auto-detect requires `enemy_count >= 5` (shadow:507-513); battery `aoe` scenario only sets 4.
    Fixture: `{ name = "shadow_aoe", overrides = { enemy_count = 5, enemies_count = 5, stance = 1 } }` → clears (aoe_self_meets stub true).
12. **Enh `EarthShock` (interrupt mode)** — **1 lane / 1 scenario.**
    Probe: `should_interrupt_target` needs `target_can_interrupt` + `target_cast_pct` within `[kick_min_pct, kick_max_pct]` (enhancement:606-618) — battery only mocks `target_is_casting`.
    Fixture: add `target_cast_pct = 50` mock + extend `defensive_casting` → clears.
13. **Enh `ShamanisticRage`** — **1 lane / 1 scenario.**
    Probe: gates `has_shamanistic_rage` (buff — battery `buffs_up` makes it up) + `enhancement_cd_shamanistic_rage` (true) + ttd ≥ 8 + major-CD window (enhancement:869-879).
    Fixture: `{ buff_remains_map = { [30823] = 0 }, should_burst = true, ttd = 60 }` (SR id 30823) → clears.
14. **Bear `EnrageCombat`** — **1 lane / 1 scenario.**
    Probe: needs `rage <= RAGE_LOW (15)` (bear:808) + mangle/lacerate spend path (bear:810-811); battery rage default 70 blocks.
    Fixture: `{ rage = 10, form = 1 }` → clears (verify no other rage-gated lane leaks).
15. **Balance `MoonkinForm`** — **1 lane / 1 scenario.**
    Probe: DSL gates `context.settings.balance_moonkin_auto` + **not in_combat** + spell_ready (balance:689-696).
    Fixture: `{ in_combat = false, setting_overrides = { balance_moonkin_auto = true } }` → clears.
16. **Balance `HurricaneAoE`** — **1 lane / 1 scenario.**
    Probe: gates aoe_target_meets (stub true) + **`NS.spell_ready(Barkskin) and not barkskin_active → false`** (balance:416-423) — battery spell_ready always true + barkskin inactive → blocked.
    Fixture: `{ enemy_count = 4, barkskin_active = true }` (new known key) → clears.
17. **Resto `RebirthBattleRez`** — **1 lane / 1 scenario.**
    Probe: `find_dead_party_ally` stub hardcodes nil (behavioral_audit:510) — matcher needs a dead ally unit.
    Fixture: scenario-aware `find_dead_party_ally` under a `dead_ally = true` override → clears.
18. **Resto `LightningShield`** — **1 lane / 1 scenario.**
    Probe: `restoration_shield_type` default "water" → low-level fallback path to Lightning Shield (restoration:404-414); battery level 70 keeps water shield up.
    Fixture: `{ level = 20, player_level = 20, buff_remains_map = {} }` (no water shield) → clears.
19. **Elem `TotemicCall`** — **1 lane / 1 scenario.**
    Probe: gates `context.has_totems` (elemental:431) — never set; the enh variant cleared via `totem_far` earlier.
    Fixture: known key `has_totems = true` + `is_moving = true` → clears.
20. **Cat `MangleFiller` / `ClawFallback`** — **2 lanes / 1-2 scenarios.**
    Probe: MangleFiller blocked by battery `is_behind=true` → Shred preempts (cat:1268); ClawFallback blocked by `spell_exists(MangleCat)` always true (cat:1265).
    Fixture: `{ is_behind = false }` known key (MangleFiller) + `not_learned = { [mangle_cat_id] = true }` (ClawFallback — not_learned mechanism already exists for Devastate).

**Cumulative estimate:** items 1-20 ≈ **30-32 lanes** for ~20 scenarios (best ratio: Readiness 3:1, prot pins 4:2, ret cleanse 3:1, serpent 2:1, per-buff heal 2:1, moving shocks 2:1).

### (C) Needs-probe / low-value (keep (c) for now)

| Lanes | Blocker to probe |
|---|---|
| Holy `ConsecrationSoloAoE`/`JudgementSoloRighteousness`/`HammerOfWrathSolo`/`LayOnHandsLastResort` | seal-state + CD + AoE combo — likely 4 separate gates; low yield |
| Holy `JudgementOfLightBoss`/`JudgementOfWisdomBoss` | `BOSS_HP_FLOOR` (20) + `target_has_jol` + `has_seal_light` (holy:1088-1097) — debuff-map inversion needed; probe whether `debuff_remains_map` without JoL clears |
| Smite `InnerFocus`, `SoloRenew`, `SoloPsychicScream` | InnerFocus = buff+CD DSL combo; SoloRenew = `is_solo` + hp ≤ 72 + no renew (smite:239-249, `is_solo` default true → likely 1 flag away); SoloPsychicScream = solo_like + (is_pvp && hp ≤ 65) OR (enemy ≥ 2 && hp ≤ 75) (smite:256-267) — 1-2 flags each |
| Bear `RakeSnapshot`/`RipSnapshot` (cat) | snapshot mechanics (stealth/CP windows) — mock can't express; leave silent |
| Resto `LifebloomLetBloom`, `TravelFormReposition` | `lifebloom_bloom` expire state; movement+form combo — low yield |
| Enh `FireNovaReplacement` | totem-state (`fire_nova_active`, `magma_totem_ready`, flame-shock debuff, enhancement:687-697) — shares totem fixture with #19 |
| Hunter `Trinket` | `NS.TrinketManager` unmocked (returns no equipped trinkets) — 1 lane, needs manager stub |
| Resto `ChainLightning` wiring | see (B) #10 — verify `solo_damage_enabled` + heal-scan `lowest` |

---

**Impact if (B) #1-20 land:** (c) ≈ 62 → ~30; total never-firing ≈ 100 → ~68, dominated by genuinely situational (b) lanes + snapshot/state lanes that live code (not the battery) can't express. No category-(d) dead lanes were found in this pass — every probed gate is a real mock/state gap, not a bug.
