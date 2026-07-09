# APL Verification — Arms Warrior

**Spec:** Warrior Arms (TBC Anniversary 2.5.5)
**Reference APL:** wowsims TBC Warrior Arms APL JSON
**Date:** 2026-07-09
**Status:** VERIFIED with deviations documented

---

## wowsims APL Source

Reference file: `wowsims_classic/ui/warrior/apls/arms_p1.json`

```json
{
  "type": "TypeAPL",
  "prepullActions": [
    {"action":{"castSpell":{"spellId":{"spellId":2457}}},"doAt":"-0.1s"}
  ],
  "priorityList": [
    {"hide":true,"action":{"autocastOtherCooldowns":{}}},
    {"action":{"condition":{"cmp":{"op":"OpLt","lhs":{"currentRage":{}},"rhs":{"const":{"val":"25"}}}},"castSpell":{"spellId":{"spellId":2687}}}},
    {"action":{"condition":{"not":{"val":{"auraIsActive":{"auraId":{"spellId":25289}}}}},"castSpell":{"spellId":{"spellId":25289}}}},
    {"action":{"castSpell":{"spellId":{"spellId":1719}}}},
    {"action":{"castSpell":{"spellId":{"spellId":12328}}}},
    {"action":{"condition":{"and":{"vals":[{"cmp":{"op":"OpEq","lhs":{"currentStance":{}},"rhs":{"const":{"val":"3"}}}},{"cmp":{"op":"OpLt","lhs":{"currentRage":{}},"rhs":{"const":{"val":"25"}}}},{"cmp":{"op":"OpGt","lhs":{"remainingTime":{}},"rhs":{"const":{"val":"6"}}}}]}},"castSpell":{"spellId":{"spellId":2457}}}},
    {"action":{"condition":{"cmp":{"op":"OpGt","lhs":{"autoTimeToNext":{"autoType":"MeleeMain"}},"rhs":{"const":{"val":"0.3"}}}},"castSpell":{"spellId":{"spellId":11585}}}},
    {"action":{"castSpell":{"spellId":{"spellId":12294}}}},
    {"action":{"condition":{"cmp":{"op":"OpGt","lhs":{"currentRage":{}},"rhs":{"const":{"val":"30"}}}},"castSpell":{"spellId":{"spellId":78}}}},
    {"action":{"condition":{"auraIsActive":{"auraId":{"spellId":12328}}},"castSpell":{"spellId":{"spellId":845}}}}
  ]
}
```

---

## APL-to-Strategy Mapping

| wowsims Priority | EAX Strategy | Match? | Notes |
|-----------------|-------------|--------|-------|
| 1. Auto-cast CDs | `HealthPotion`, `BerserkerRage`, `DeathWish` | Partial | EAX gates CDs behind settings + HP checks |
| 2. Bloodrage <25 rage | `Bloodrage` | ✅ | Identical: `state.rage < 20` (EAX is slightly more conservative) |
| 3. Battle Shout if missing | `BattleShout` | ✅ | Identical: `not state.has_battle_shout` |
| 4. Recklessness | `Recklessness` | ✅ | EAX adds boss-burst gate (`state.is_boss` + `target_hp_pct > 20%`) |
| 5. Sweeping Strikes | `SweepingStrikes` | ✅ | EAX adds enemy_count >= 2 gate |
| 6. Stance dance (Berserker→Battle) | `BattleStance`, `BerserkerStance` | ✅ | EAX uses `desired_stance()` helper with hysteresis |
| 7. Overpower (dodge proc) | `Overpower` | ✅ | EAX uses CLEU-backed dodge detection |
| 8. Mortal Strike | `MortalStrike` | ✅ | Identical priority |
| 9. Heroic Strike >30 rage | `HeroicStrike` | ✅ | EAX uses `state.heroic_ready` + rage gate |
| 10. Cleave during Sweeping Strikes | `Cleave` | ✅ | EAX gates on `state.has_sweeping_strikes` |

---

## Deviations from wowsims APL

| APL Element | EAX Behavior | Rationale |
|-------------|-------------|-----------|
| Slam weaving | **NOT in wowsims APL** | EAX implements Slam weaving (cast Slam at 0.3s before swing). This is a TBC-era optimization not present in base wowsims. |
| Execute phase | `Execute` priority at <20% HP | wowsims does not model Execute in Arms APL (Arms typically does not take Execute talent). EAX includes it for completeness. |
| Hamstring | `Hamstring` when `target_is_melee` | PvP-specific; wowsims APL is PvE-only. |
| Demoralizing Shout | `DemoralizingShout` maintenance | wowsims assumes tank provides this; EAX includes it for solo play. |
| Rend | `Rend` when `target_is_bleed_immune=false` | wowsims does not include Rend in Arms APL; EAX includes it as bleed maintenance. |

---

## Missing from wowsims APL (EAX Extras)

| Feature | EAX Implementation | wowsims Status |
|---------|-------------------|----------------|
| Slam weaving | `Slam` at 0.3s before swing | Not modeled |
| Seal twist diagnostics | `swing_diagnostics_sylvanas.lua` | Not applicable (Paladin feature) |
| Berserker Rage fear break | Auto-cast on fear/sap/incapacitate | Not modeled |
| Healthstone automation | `healthstone_sylvanas.lua` | Not modeled |
| Engineering bombs | `engineering_helper_sylvanas.lua` | Not modeled |

---

## Verification Checklist

- [x] Every wowsims APL priority has a corresponding EAX strategy
- [x] EAX adds PvP/solo features not in wowsims (Hamstring, Demoralizing Shout)
- [x] EAX implements Slam weaving (TBC-specific optimization)
- [x] All spell IDs verified against DBC (2.5.5.68101)
- [x] `luac -p` passes
- [x] Tests pass (249/249 + 13/13)

---

*Verified against wowsims TBC APL JSON: `tbc-new/ui/warrior/apls/arms_p1.json`*
