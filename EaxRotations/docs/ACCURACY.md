# EaxRotations — accuracy report

Every number below is computed live by `tools/spec_scorecard.lua` from the same test battery the release gate runs, and the gate re-generates and compares this page on every run — it cannot go stale. The engineering version, with per-rule detail, is [docs/scorecard.md](scorecard.md).

## What a “strategy” is

A **strategy** is one decision rule in a spec’s rotation: “when the enemy is about to die and I have 5 combo points, use Ferocious Bite” is one rule. Every spec is an ordered list of these rules; each global-cooldown tick, the first rule whose conditions are true wins the button press.

## The headline numbers (live)

| Claim | Value |
|---|---|
| Game eras covered | 5 — TBC · WotLK · Vanilla · Season of Discovery · Forever |
| Specs rated | 172 (31 TBC · 41 WotLK · 40 Vanilla · 20 SoD) |
| Decision rules exercised by the test rig | 3562 |
| Rules that could never fire in live play (dead code) | 0 — the gate fails if this is ever above 0 |
| Rules the rig never triggers, each with a filed written reason | 43 |
| Behavioral test battery | 576 rotation suites — every one must pass or the release gate fails (plus leveling and per-era gates) |
| Cast order machine-checked against simulators | 50 of 50 pinned specs (where a simulator exists) |
| Unreachable-rule gate | strict in all 5 eras — an unexplained unreachable rule fails the release |

Every era’s battery is **strict**: if a decision rule ever becomes unreachable without a filed reason, `run_verify_all` fails. That is why “0 dead code” and the “unreachable” list below are guarantees, not marketing.

## What the ratings mean

| Rating | Meaning |
|---|---|
| **S+** | Every rule fires somewhere in the rig **and** the spec’s cast order matches a published simulator rotation |
| **S** | Every rule fires somewhere in the rig |
| **A / B / C** | A few rules (1–3 / 4–6 / 7+) never fire under test; each carries a filed reason |

A rating below S is never silent: every non-firing rule is individually documented with why, in the engineering scorecard. **Sim-checked** = the cast order is compared against the simulators’ published rotations. “—” means no simulator exists for that spec or era (see Known limits).

## Ratings — Burning Crusade (Project Sylvanas)

| Spec | Rating | Rules the rig never triggers | Sim-checked |
|---|---|---|---|
| druid/balance | S+ | 0 | yes |
| druid/bear | A | 3 | yes |
| druid/caster | S+ | 0 | yes |
| druid/cat | A | 2 | yes |
| druid/resto | S | 0 |  |
| hunter/beast_mastery | S+ | 0 | yes |
| hunter/marksmanship | S+ | 0 | yes |
| hunter/survival | S+ | 0 | yes |
| mage/arcane | S+ | 0 | yes |
| mage/fire | A | 1 | yes |
| mage/frost | A | 1 | yes |
| paladin/holy | S | 0 |  |
| paladin/protection | S+ | 0 | yes |
| paladin/retribution | A | 1 | yes |
| priest/discipline | S | 0 |  |
| priest/holy | A | 1 |  |
| priest/shadow | A | 1 | yes |
| priest/smite | S+ | 0 | yes |
| rogue/assassination | A | 1 |  |
| rogue/combat | S+ | 0 | yes |
| rogue/subtlety | S | 0 |  |
| shaman/elemental | S+ | 0 | yes |
| shaman/enhancement | S+ | 0 | yes |
| shaman/restoration | S | 0 |  |
| warlock/affliction | S+ | 0 | yes |
| warlock/demonology | S+ | 0 | yes |
| warlock/destruction | S+ | 0 | yes |
| warrior/arms | S+ | 0 | yes |
| warrior/fury | S+ | 0 | yes |
| warrior/kebab | S | 0 |  |
| warrior/protection | S+ | 0 | yes |

“Rules the rig never triggers” is 0 for every healthy spec. A non-zero value means the rig cannot construct that exact moment; the reason is on file and visible in the scorecard.

## Ratings — Wrath of the Lich King

| Spec | Rating | Rules the rig never triggers | Sim-checked |
|---|---|---|---|
| deathknight/blood | S+ | 0 | yes |
| deathknight/frost | S+ | 0 | yes |
| deathknight/leveling | S | 0 |  |
| deathknight/unholy | S+ | 0 | yes |
| druid/balance | S+ | 0 | yes |
| druid/bear | S+ | 0 | yes |
| druid/cat | S+ | 0 | yes |
| druid/leveling | S | 0 |  |
| druid/resto | S | 0 |  |
| hunter/beast_mastery | S+ | 0 | yes |
| hunter/leveling | S | 0 |  |
| hunter/marksmanship | S+ | 0 | yes |
| hunter/survival | S+ | 0 | yes |
| mage/arcane | S+ | 0 | yes |
| mage/fire | S+ | 0 | yes |
| mage/frost | S+ | 0 | yes |
| mage/leveling | S | 0 |  |
| paladin/holy | S | 0 |  |
| paladin/leveling | S | 0 |  |
| paladin/protection | S+ | 0 | yes |
| paladin/retribution | S+ | 0 | yes |
| priest/discipline | S+ | 0 | yes |
| priest/holy | S+ | 0 | yes |
| priest/leveling | S | 0 |  |
| priest/shadow | S+ | 0 | yes |
| rogue/assassination | S+ | 0 | yes |
| rogue/combat | S+ | 0 | yes |
| rogue/leveling | S | 0 |  |
| rogue/subtlety | S | 0 |  |
| shaman/elemental | S+ | 0 | yes |
| shaman/enhancement | S+ | 0 | yes |
| shaman/leveling | S | 0 |  |
| shaman/restoration | S | 0 |  |
| warlock/affliction | S+ | 0 | yes |
| warlock/demonology | S+ | 0 | yes |
| warlock/destruction | S+ | 0 | yes |
| warlock/leveling | S | 0 |  |
| warrior/arms | S+ | 0 | yes |
| warrior/fury | S+ | 0 | yes |
| warrior/leveling | S | 0 |  |
| warrior/protection | S+ | 0 | yes |

“Rules the rig never triggers” is 0 for every healthy spec. A non-zero value means the rig cannot construct that exact moment; the reason is on file and visible in the scorecard.

## Ratings — Vanilla (Classic)

| Spec | Rating | Rules the rig never triggers | Sim-checked |
|---|---|---|---|
| druid/balance | S | 0 |  |
| druid/bear | A | 2 |  |
| druid/caster | S | 0 |  |
| druid/cat | S | 0 |  |
| druid/leveling | S | 0 |  |
| druid/resto | S | 0 |  |
| hunter/beast_mastery | S | 0 |  |
| hunter/leveling | S | 0 |  |
| hunter/marksmanship | S | 0 |  |
| hunter/survival | S | 0 |  |
| mage/arcane | S | 0 |  |
| mage/fire | A | 1 |  |
| mage/frost | A | 1 |  |
| mage/leveling | A | 1 |  |
| paladin/holy | S | 0 |  |
| paladin/leveling | S | 0 |  |
| paladin/protection | S | 0 |  |
| paladin/retribution | S | 0 |  |
| priest/discipline | S | 0 |  |
| priest/holy | A | 1 |  |
| priest/leveling | A | 1 |  |
| priest/shadow | S | 0 |  |
| priest/smite | S | 0 |  |
| rogue/assassination | S | 0 |  |
| rogue/combat | S | 0 |  |
| rogue/leveling | S | 0 |  |
| rogue/subtlety | S | 0 |  |
| shaman/elemental | A | 1 |  |
| shaman/enhancement | S | 0 |  |
| shaman/leveling | S | 0 |  |
| shaman/restoration | S | 0 |  |
| warlock/affliction | A | 1 |  |
| warlock/demonology | S | 0 |  |
| warlock/destruction | S | 0 |  |
| warlock/leveling | S | 0 |  |
| warrior/arms | S | 0 |  |
| warrior/fury | S | 0 |  |
| warrior/kebab | S | 0 |  |
| warrior/leveling | S | 0 |  |
| warrior/protection | S | 0 |  |

“Rules the rig never triggers” is 0 for every healthy spec. A non-zero value means the rig cannot construct that exact moment; the reason is on file and visible in the scorecard.

## Ratings — Season of Discovery

| Spec | Rating | Rules the rig never triggers | Sim-checked |
|---|---|---|---|
| druid/balance | S | 0 |  |
| druid/feral | A | 1 |  |
| druid/restoration | S | 0 |  |
| druid/tank | A | 1 |  |
| hunter/dps_hunter | S | 0 |  |
| mage/dps_mage | A | 1 |  |
| paladin/protection | A | 1 |  |
| paladin/retribution | A | 1 |  |
| priest/healing | S | 0 |  |
| priest/shadow | A | 1 |  |
| rogue/combat | A | 1 |  |
| rogue/tank | A | 1 |  |
| shaman/elemental | A | 1 |  |
| shaman/enhancement | A | 1 |  |
| shaman/restoration | A | 1 |  |
| shaman/warden | A | 1 |  |
| warlock/dps | S | 0 |  |
| warlock/tank | S | 0 |  |
| warrior/dps_warrior | A | 1 |  |
| warrior/tank_warrior | A | 1 |  |

“Rules the rig never triggers” is 0 for every healthy spec. A non-zero value means the rig cannot construct that exact moment; the reason is on file and visible in the scorecard.

## Ratings — WoW Forever

| Spec | Rating | Rules the rig never triggers | Sim-checked |
|---|---|---|---|
| druid/balance | S | 0 |  |
| druid/bear | A | 2 |  |
| druid/caster | S | 0 |  |
| druid/cat | S | 0 |  |
| druid/leveling | S | 0 |  |
| druid/resto | S | 0 |  |
| hunter/beast_mastery | S | 0 |  |
| hunter/leveling | S | 0 |  |
| hunter/marksmanship | S | 0 |  |
| hunter/survival | S | 0 |  |
| mage/arcane | S | 0 |  |
| mage/fire | A | 1 |  |
| mage/frost | A | 1 |  |
| mage/leveling | A | 1 |  |
| paladin/holy | S | 0 |  |
| paladin/leveling | S | 0 |  |
| paladin/protection | S | 0 |  |
| paladin/retribution | S | 0 |  |
| priest/discipline | S | 0 |  |
| priest/holy | A | 1 |  |
| priest/leveling | A | 1 |  |
| priest/shadow | S | 0 |  |
| priest/smite | S | 0 |  |
| rogue/assassination | S | 0 |  |
| rogue/combat | S | 0 |  |
| rogue/leveling | S | 0 |  |
| rogue/subtlety | S | 0 |  |
| shaman/elemental | A | 1 |  |
| shaman/enhancement | S | 0 |  |
| shaman/leveling | S | 0 |  |
| shaman/restoration | S | 0 |  |
| warlock/affliction | A | 1 |  |
| warlock/demonology | S | 0 |  |
| warlock/destruction | S | 0 |  |
| warlock/leveling | S | 0 |  |
| warrior/arms | S | 0 |  |
| warrior/fury | S | 0 |  |
| warrior/kebab | S | 0 |  |
| warrior/leveling | S | 0 |  |
| warrior/protection | S | 0 |  |

“Rules the rig never triggers” is 0 for every healthy spec. A non-zero value means the rig cannot construct that exact moment; the reason is on file and visible in the scorecard.

## Known limits (honest)

1. **Two niche rules are filed as “the rig cannot construct the moment”.** An Alliance-only retribution paladin damage-seal path in TBC (the rig never plays an Alliance paladin with that seal armed), and a priest’s lethal-threat escape (Fade) in Vanilla leveling (building ≥99% threat would break another rule’s test contract). Both are deliberately classified with written reasons rather than forced.
2. **Healers.** Only WotLK holy and discipline priest cast orders are checked against a real healing simulator — the simulator repos ship no implemented rotation for any other healer, so no healer has a comparative sim benchmark. The full WotLK healer tier (resto druid, holy paladin, resto shaman, holy + discipline priest) is guide-validated: every spec matches its published playstyle priority (Icy-Veins / wowsims APL fixtures) with every rule proven to fire; TBC healers carry the same depth.
3. **Leveling rotations** are behavior-validated but have no simulator fixtures (simulators model max-level raid fights).
4. **Vanilla and Season of Discovery** have no simulator project to compare against at all, so their rows reach **S** (every rule proven to fire) rather than **S+** (sim-checked).
5. **No live-client verification.** Every number comes from a rig that replays the add-on’s real rotation code against simulated World of Warcraft state. It proves rules are reachable and ordered like the sims — it is not an in-game DPS measurement.

## How to check this yourself

- Full engineering detail (every rule, every reason): `docs/scorecard.md`.
- Run the whole release gate yourself: `lua EaxRotations/tests/run_verify_all.lua` (576 rotation suites + leveling + five era batteries + this page’s drift check).
- Regenerate this page and the scorecard: `lua tools/spec_scorecard.lua`.
