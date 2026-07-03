## EAX Rotations v2.3.8 — Boss Detection + Dead State Field Fixes

### Bug Fixes

- **Mage — Fire**: Clearcasting proc (Arcane Concentration) is now consumed by Fireball. `build_state` never assigned `has_clearcasting`, so the matcher always returned false — the proc sat unused.
- **Warrior — Arms**: Death Wish now auto-fires on boss targets above 20% HP. `state.is_boss` and `state.target_hp_pct` were never populated (and absent from ARMS_SCHEMA), so the boss-burst branch was dead code.
- **Druid — Bear**: Nature's Grasp now auto-casts in PvP when the druid is rooted or snared. `state.is_rooted` and `state.is_snared` were never assigned, so the PvP peel matcher always fell through to `return false`.
- **Warlock — Demonology**: Pet Defensive/Passive/Aggressive state matchers now read a properly populated `state.in_combat`. Previously `state.in_combat` was never set, so the `or state.in_combat` half of the guard was a stale dead reference (functionally worked via `context.in_combat` fallback, but incorrect).

### API Compliance

- **is_boss detection (all specs)**: Rewired to use the accurate `unit_helper:is_boss()` via `NS.unit_is_boss()`, instead of the raw `target:is_boss()` which the Sylvanas docs explicitly warn is inaccurate ("only certain bosses like world bosses have this flag enabled"). Affected: Arms Death Wish gate, Fire Combustion long-CD gate, Destruction Demonic Sacrifice gate, Bear boss-bypass Maul logic, and the shared `combat_forecast_gate`.
- **is_tank detection (all healers)**: `core_sylvanas:is_tank_unit` now prefers the accurate `unit_helper:is_tank()` via `NS.unit_is_tank()`, falling back to the previous raw `unit:is_tank()` + `get_group_role() == 0` chain. This improves tank identification for triage scoring and Rejuvenation tank-priority across all 5 healer specs.

### v2.3.7 Healer Dispel Throttle (included in this build)

- **All 4 healer specs** (Discipline Priest, Holy Paladin, Restoration Druid, Restoration Shaman): dispel/cleanse abilities now throttle to 3-second intervals. Prevents rapid-fire casts when debuff detection returns stale or false-positive data, saving mana and GCDs.

### What to Expect

- **Fire mages**: Clearcasting procs are now properly consumed on Fireball for higher burst.
- **Arms warriors**: Death Wish fires automatically on dungeon/raid bosses above 20% HP as a burst opener.
- **Bear druids**: Nature's Grasp peels melee/root in PvP when you're CC'd.
- **All healers**: More accurate tank detection means Rejuvenation and triage scoring correctly prioritize the tank. Dispel spam is eliminated.
- **All specs**: Boss detection is now accurate — no more missed burst CDs on dungeon/raid bosses the raw Blizzard flag didn't mark.

---
*Verified: 219 rotation tests + 13 leveling tests pass. All spell IDs verified against WoW 2.5.5.68101 client DBC.*
