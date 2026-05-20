# Druid Balance Implementation Checklist

Last updated: 2026-05-19
Target files:
- C:\newbot\scripts\EaxRotations\classes\druid\balance_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\schema_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\caster_sylvanas.lua

## Compared Research Requirements

| Requirement from Research.md | Current EaxRotations state | Decision | Evidence |
|---|---|---|---|
| Maintain Faerie Fire when raid benefits / Improved Faerie Fire | Present | Present | balance_sylvanas.lua:253-268, ff_remains <= 5, has_feral_druid skip |
| Maintain Insect Swarm when mana/debuff value justify | Partial | Implemented | Hard-coded 2s threshold; replaced with should_refresh_dot + TTD gate, added setting toggle |
| Maintain Moonfire when mana allows and target lives long enough | Partial | Implemented | Hard-coded 2s threshold; replaced with should_refresh_dot + TTD gate |
| Force of Nature on long fights where pets won't cause problems | Partial | Implemented | No TTD gate or setting toggle; added min 12s TTD gate and `balance_use_force_of_nature` setting |
| Starfire as primary filler; Wrath as movement/conserve fallback | Partial | Implemented | Wrath fallback existed but filler choice was weak; improved with clearer conserve gate and Nature's Grace priority |
| Innervate by assignment, not greedily | Partial | Blocked | Assignment-aware Innervate requires runtime party/raid API; kept as self-cast with `innervate_target` context gate noted as blocked |
| Rebirth coverage needed — hold for recovery | Partial | Implemented | Wired to `NS.find_dead_party_ally` for real dead-party detection; gated on player-is-dead + tank-alive (tank_alive == false blocks cast) |
| Mana conserve mode drops DoTs before dropping all DPS | Present | Present | balance_sylvanas.lua:105-119, mana_floor gates Starfire vs Wrath; DoT strategies already have mana thresholds |
| Hurricane AoE with Barkskin support | Present | Present | balance_sylvanas.lua:227-251, min 3 targets, Barkskin gate when HP low |
| Movement fallback: instant/DoT/ranged/utility | Partial | Implemented | DoT refresh during movement existed; added target validity gate so movement-only doesn't fire without target |
| Target validity / immune / out-of-range / unsafe gate | Missing | Implemented | No explicit target validity gate at top of rotation; added `has_valid_enemy_target` check in DoT/nuke strategies |
| [VERIFY] SP breakpoints at 800/1000/1200 | Not hard-coded | Keep configurable | No hard-coded breakpoints; mana_floor slider already allows player tuning. SP breakpoints need sim/log confirmation before becoming defaults. |
| No Eclipse, Starfall, Typhoon, Wild Growth, Berserk, Savage Roar | Not present in Balance | N/A | Confirmed absent from Balance files; Berserk reference exists only in cat_sylvanas.lua (Feral spec, out of scope) |
| Nature's Grace changes cast timing | Partial | Implemented | `natures_grace_active` tracked; now preferentially casts Starfire when active |
| TTD gating on DoTs and cooldowns | Missing | Implemented | Added `target_ttd` to state builder; applied to Moonfire (12s), Insect Swarm (12s), Force of Nature (12s) |
| DB2-verified spell IDs | Present | Present | All IDs cross-checked against DB2-Spells.md |
| Remove Curse spell ID [2782] | Present with error | Fixed | class_sylvanas.lua had wrong secondary ID 20739 (Rebirth); corrected to 2782 only |
| Nature's Grasp spell IDs | Present with error | Fixed | balance_sylvanas.lua used 27010 (nonexistent); corrected to 27009 (TBC max rank) per DB2 |

## Changes Made

| Change | Files touched | Test/validation |
|---|---|---|
| Replaced hard-coded DoT refresh thresholds with NS.should_refresh_dot + TTD gate | balance_sylvanas.lua | test_balance_custom_matches.lua |
| Added `target_ttd` to state builder (from context.ttd) | balance_sylvanas.lua | test_balance_custom_matches.lua |
| Added `has_valid_enemy_target` gate to DoT, Faerie Fire, and nuke strategies | balance_sylvanas.lua | test_balance_custom_matches.lua |
| **FIXED: Reordered strategies — Faerie Fire/DoTs now run BEFORE Starfire/Wrath filler** | balance_sylvanas.lua | test_balance_custom_matches.lua |
| **FIXED: Target validity gate no longer short-circuited by `or context.target`** | balance_sylvanas.lua | test_balance_custom_matches.lua |
| Added `balance_use_force_of_nature` setting toggle + 12s TTD gate | balance_sylvanas.lua, schema_sylvanas.lua | test_balance_custom_matches.lua |
| Added `balance_use_insect_swarm` setting toggle | balance_sylvanas.lua, schema_sylvanas.lua | test_balance_custom_matches.lua |
| **FIXED: Rebirth wired to `NS.find_dead_party_ally` using raw `NS.GetPartyMembers` (includes dead units)** | core_sylvanas.lua, balance_sylvanas.lua | luac -p |
| **FIXED: Rebirth gated on player-is-dead + tank_alive == false (safe, not permissive)** | balance_sylvanas.lua | test_balance_custom_matches.lua |
| **FIXED: Mana state reads `context.mana_pct` first, not just `context.mana`** | balance_sylvanas.lua | test_balance_custom_matches.lua |
| **FIXED: Innervate reverted to safe self-cast (assignment-aware blocked due to no runtime API)** | balance_sylvanas.lua | test_balance_custom_matches.lua |
| Improved Starfire vs Wrath choice: clearer conserve floor and Nature's Grace priority | balance_sylvanas.lua | test_balance_custom_matches.lua |
| Fixed Nature's Grasp max rank ID 27009 | balance_sylvanas.lua | luac -p |
| Fixed RemoveCurse secondary ID to 2782 only | class_sylvanas.lua | luac -p |
| Added `balance_use_force_of_nature` and `balance_use_insect_swarm` settings | schema_sylvanas.lua | luac -p |
| **Updated tests to match fixed code** | test_balance_custom_matches.lua, test_balance_faerie_fire.lua, test_balance_war_stomp.lua | All PASSED |

## API Validation

| API/function used | Local source checked | Notes |
|---|---|---|
| NS.should_refresh_dot | shared/dot_refresh.lua | Pure function, APL formula confirmed |
| NS.action_matches / NS.action_execute | core_sylvanas.lua (implied) | Existing production pattern |
| NS.spell_ready / NS.try_cast | core_sylvanas.lua (implied) | Existing production pattern |
| context.ttd | main_sylvanas.lua:237 | Confirmed available in combat context |
| context.has_valid_enemy_target | main_sylvanas.lua (implied) | Standard context field |
| NS.find_dead_party_ally | shared/find_dead_party_ally_sylvanas.lua | Confirmed pure helper exists and is tested |

## Changes Made (2026-05-21 — Blocker Resolution Pass)

| Change | Files touched | Test/validation |
|---|---|---|
| Added `HEALER_CLASS_IDS` table (Paladin/2, Priest/5, Shaman/7, Druid/11) for Innervate priority | balance_sylvanas.lua | luac -p PASS |
| Added `innervate_target` to `balance_state` and smart target selection in `build_state()` | balance_sylvanas.lua | luac -p PASS |
| Split old `InnervateSelf` into `InnervateHealer` (prefer low-mana healer) + `InnervateSelf` (self fallback) | balance_sylvanas.lua | luac -p PASS |
| Innervate scanning gated behind `context.in_combat`, `context.is_group`, `NS.GetPartyMembers` | balance_sylvanas.lua | N/A — no overhead in solo |
| `find_smart_innervate_target`: uses pcall-safe `unit:get_class()`, `NS.mana_pct()`, `NS.same_unit()` | balance_sylvanas.lua | Safe against nil units |
| Documented Hurricane Barkskin already-implemented status (PreHurricaneBarkskin + HurricaneAoE) | 001_Druid_Balance.md | Verified in code 2026-05-19 |

## Remaining Work

| Item | Why not done | Required evidence |
|---|---|---|
| SP breakpoint auto-switching (800/1000/1200) | [VERIFY] rows need sim/log confirmation; thresholds kept configurable via `balance_starfire_mana` slider | wowsims/tbc + combat logs |
| ~~Innervate assignment-aware casting~~ | **Partially resolved 2026-05-21**: smart healer scanning implemented. Full assignment-awareness (raid lead assignment detection) still needs runtime API. | live raid test for full assignment detection |
| ~~Hurricane Barkskin automation~~ | **Resolved 2026-05-21**: already implemented via PreHurricaneBarkskin + HurricaneAoE two-tick pattern | N/A — already implemented |

