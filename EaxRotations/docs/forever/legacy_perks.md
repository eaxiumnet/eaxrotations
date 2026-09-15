# WoW Forever Legacy System — Perk Reference (pre-beta)

-- legacy_perks.md — WoW Forever Legacy perk tree reference (pre-beta research corpus).
-- WHAT:  all 21 Legacy perks from classicwowforever.com/legacy (beta-captured tooltips),
--        with the three rotation-relevant ones flagged for engineering follow-up.
-- WHEN:  pre-beta (2026-09-17); re-verify every effect on the beta DBC (dbc_runbook.md).
-- WHY:   three perks change runtime behavior our code paths own (reagent gating,
--        bandage debuff cadence, long-buff refresh timing); the rest are economy/XP QoL.
-- SAFETY: research only — nothing here is wired into runtime; all ranks beyond rank 1
--         are UNVERIFIED estimates (source site's own caveat), so no numeric logic
--         may be built from them before DBC confirmation.

> Source: classicwowforever.com/legacy (DesMephisto pre-release photos, Xaryu's recorded
> build, r/classicwow tooltip collage). Captured 2026-09-15. Every "Next rank" effect on
> that site is marked unverified beyond rank 1 — treat all numbers as provisional until
> the beta DBC (dbc_runbook.md step 1-2) and live tooltips confirm them.

## System shape

- **16 Legacy Points** total; account-wide; earn by completing class/profession/world
  **challenge milestones**; **spending has a separate cap** (site wording — likely
  earn-caps vs spend-caps are independent; unconfirmed).
- 21 perks in a tree: Adventure column starts open; other columns require a point in a
  **starting perk**, and connected perks require the perk to their left (unlock rules
  inferred by the source site, not datamined — unconfirmed).
- Perks are **account benefits** (not character talents): no per-character respec cost,
  and presumably shared across every character on the account.

## ROTATION-RELEVANT PERKS (engineering watch list)

### 1. Reagent Economy (0/1) — Adventure column
Tier 1 Camping features cost no reagents; **class abilities also no longer need
vendor-purchasable reagents**.
- **Runtime impact: HIGH.** Our central cast guard
  (`core_sylvanas.lua` try_cast / cast-guard chain) performs a reagent check that can
  false-refuse casts on a Forever client when the player has this perk (e.g. Rogue
  blinding powder, shapeshift reagents, Mage teleport/portal runes, Shaman rebuff
  reagents, Paladin symbols).
- **Action (beta):** confirm whether the client still reports reagent requirements for
  perk holders; if so, add a Legacy-perk-aware bypass to the cast guard's reagent lane;
  if the client self-handles, no change needed. Log the outcome in this file.

### 2. Field Medicine (0/2) — Adventure column
Shortens **Recently Bandaged** by 5s after using a bandage. Ineffective in dungeons,
raids and battlegrounds.
- **Runtime impact: MEDIUM (OOC module).** `shared/consumable_manager_sylvanas.lua`
  (`M.use_bandage`) gates bandage use; if any Forever OOC path assumes the classic 60s
  Recently Bandaged debuff, the 55s effective window changes cadence. World/outdoor
  rotation contexts only (perk is disabled in instanced content).
- **Action (beta):** capture the real debuff duration with/without the perk; update the
  Forever bandage constants only if our code reads/mirrors the duration.

### 3. Permanence (0/2) — Adventure column
Camp benefits last 50% longer; **also extends eligible long-duration class buffs for
your party or raid**.
- **Runtime impact: MEDIUM (refresh timing).** Long-buff refresh lanes (e.g. blessing,
  MotW/GotW, Fortitude, arcane brilliance, totem-adjacent long buffs) compare
  `buff_remains(id)` against refresh thresholds. If Permanence extends buff durations
  server-side, remains values are automatically longer and thresholds stay correct —
  but if it renders client-side duration differently on the Forever client, a stale
  threshold could double-refresh or let buffs drop.
- **Action (beta):** record `buff_remains()` for a known 10-min buff with/without the
  perk on the beta client; document which buff IDs count as "eligible"; adjust refresh
  thresholds in Forever paths only if measured values diverge from classic.

## Full perk list (21)

| Perk | Max rank | Rank-1 effect (captured) | Rotational? |
|---|---|---|---|
| Adventure | — | Starting perk (tree unlock) | no |
| Well Rested | 5 | Rested XP builds 4% faster, cap +4% | no |
| Talented | 5 | Class talent points from level 9 (total still capped 51) | no* |
| Thrill of Adventure | 5 | Killing blow on non-trivial enemy: 1% max HP+Mana /10s (world only) | no |
| Field Guide | 3 | Camping feature cooldowns −8% | no |
| Frequent Flier | 1 | Flight paths −50% cost, +20% speed | no |
| Field Medicine | 2 | Recently Bandaged −5s (world only) | **YES** |
| High Alert | 2 | Detect stealth as if 1 level higher (not in BGs) | no |
| Diplomat | 5 | Reputation gains +2% | no |
| Permanence | 2 | Camp benefits +50%; extends eligible long class buffs (party/raid) | **YES** |
| Reagent Economy | 1 | No reagents for Tier 1 Camping + **class abilities reagent-free** | **YES** |
| Gourmand | 3 | Food benefits last 33% longer | no |
| For Great Honor | 5 | Honor Points +2% | no |
| The Quick and the Dead | 2 | +5% speed while dead; after resurrection helpful casts cost nothing for 1 min or until combat | maybe† |
| Reinforce | 5 | 8% less durability loss on death | no |
| Bartering | 2 | Vendor items −5% gold | no |
| Working Overtime | 5 | +4% tradeskill skill-up chance | no |
| Dedicated Study | 1 | +1 to lowest tradeskill (23h cd); essence at cap | no |
| Bountiful Harvest | 5 | +20% Scarce materials from gathering | no |
| Performance Bonus | 3 | 5% chance double Merchant's Favor from crate turn-ins | no |
| Luremaster | 2 | With lure: 25% chance extra fish | no |
| Master Chef | 5 | 10% chance extra cooking result | no |

\* Talented shifts talent-point *schedule* (level 9+), not the 51-point budget — no
rotation impact, but leveling specs' talent-dependent gates should be re-verified at
level 9-10 on beta (a level-9 character may have 1 point where classic had 0).

† The Quick and the Dead's free-cast window (post-resurrection, 1 min or until combat)
could interact with our cast guard's resource checks in resurrection-recovery scenarios;
low priority, watch on beta.

## Leveling-relevant note (Talented)

`Talented` moves first talent point from level 10 to level 9. Leveling rotations with
talent-gated strategies should behave identically at 10+, but beta-testing a level-9
character should confirm no spec crashes or mis-gates when `context.player_level` is 9
with a nonzero talent count — add to the beta checklist in dbc_runbook.md.

## Verification checklist (add to beta day)

1. DBC: locate Legacy perk spell IDs (passive auras) — add to the Forever bridge and
   `run_forever_audit_tests.lua` scope once identified.
2. Reagent Economy: does the client still expose reagent requirements to the API when
   the perk is owned? (Decides cast-guard change or no-op.)
3. Field Medicine: real Recently Bandaged duration world/outdoor with perk.
4. Permanence: buff_remains deltas for eligible long buffs with perk.
5. Talented: level-9 boot of every leveling rotation (nil-gate smoke test).
