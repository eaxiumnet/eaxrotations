# EAX Scripts Changelog

---

## [Unreleased] — 2026-03-30

### EAX Paladin Protection
- **Blessing spam fixed:** OOC blessing handling now has stronger Paladin-blessing detection, greater-blessing-aware name fallback, and anti-retry throttling to stop repeated self-buff spam.
- **Aura upkeep:** Added safe Devotion Aura upkeep that only auto-fills when no Paladin aura is already active, so it no longer overwrites intentional manual aura swaps.
- **Seal/Judgement cleanup:** Stabilized the TBC seal engine around Righteousness/Wisdom/Crusader, added durable-target judgement assignment, and improved reseal behavior after Judgement.
- **Prepull + filler upgrades:** Holy Shield can now preload safely before pull, Avenger's Shield remains a ranged opener, and Consecration has a conservative single-target filler path when mana is healthy.
- **Defensive sustain:** Added a narrow Seal of Light fallback for clear sustain windows without trying to force full NAG-style SoV/twist complexity into the release build.

### EAX Paladin Retribution
- **Real Judgement flow:** Retribution now sets up the correct seal before Judgement based on menu choice (`Wisdom` / `Crusader` / `Light`) instead of faking JoX casts through mismatched IDs.
- **Reseal cleanup:** Temporary judgement seals now return cleanly to the normal DPS baseline without fighting the baseline seal loop.
- **Aura upkeep:** Added safe Retribution Aura upkeep that respects existing manual aura choices instead of overwriting them.
- **Prepull setup:** Added a conservative out-of-combat `Seal of the Crusader` → `Judgement of the Crusader` opener path.
- **Reliability fixes:** Tightened Exorcism target validation and cleaned up blessing churn.

### EAX Paladin Holy
- **Runtime fixes:** Repaired forward-declaration/runtime hazards, corrected Holy Light top-rank ordering, and fixed poison dispel typing.
- **Healing support upgrades:** Added Divine Favor, conservative low-mana Seal of Wisdom sustain, and a Judgement refresh window instead of apply-once behavior.
- **Blessings and OOC behavior:** Improved blessing detection, reduced OOC blessing churn, and added non-destructive aura upkeep with Concentration → Devotion fallback.
- **Quality-of-life:** Improved out-of-combat group top-off behavior and stronger triage integration.

### Release note
- **Paladin is now a release-candidate class** for same-night customer delivery, with the biggest deferred gap being full Protection `Seal of Vengeance / Seal of Corruption` parity.

## [2.1.0] — 2026-03-19

### Global (all specs)
- **Combo points fix (Rogue/Druid):** `get_power()` was being called on the target mob (`cp_obj`) instead of the local player. All Rogue and Druid scripts now correctly call `me:get_power(enums.power_type.COMBOPOINTS_TBC)` on the player. This was the root cause of CPs always reading 0 on TBC private servers.
- **Target range cap:** `find_best_target()` now ignores hostile units beyond 30 yards in all specs. Units actively attacking you or party members still have no range cap. Prevents engaging enemies across the map.
- **Menu defaults:** Several abilities that were `false` by default are now enabled — Tranquility (Balance), Rupture (Rogue Assassination), Prepull Totems (Shaman Elemental/Enhancement), Bloodlust on pull, Wrath of Air totem, Purge (Shaman Restoration), Prefer Doom (Warlock Affliction), Seal Twisting in raids (Paladin Retribution).

### EAX Druid Feral
- **Combo points:** Confirmed working via `me:get_power(enums.power_type.COMBOPOINTS_TBC)` on the player. Cast-callback fallback retained. Previous implementations called `get_power()` on the target mob which always returns 0.
- **Form management:** Travel Form is now the default OOC form. Combat forms only engage when in combat. After Feral Charge (which requires Bear Form), the rotation waits until in melee range before shifting back to Cat.
- **`get_combo_points_target()` removed:** This API returns unreliable objects on this PS build. Target validation removed entirely — cast-callback handles CP resets on finisher use.
- **Mark of the Wild:** Fixed — `ooc_mark_of_the_wild_id` was declared in runtime but never resolved, so OOC buffing was silently broken. Now properly resolved and wired.
- **CC added:** `try_war_stomp` (2+ attackers or <35% HP), `try_cyclone` (target actively healing an enemy), `try_entangling_roots` (target kiting). All have smart auto-conditions and menu toggles.
- **New spells:** `CYCLONE`, `ENTANGLING_ROOTS`, `HIBERNATE`, `BUFF_MARK_OF_THE_WILD`, `BUFF_LEADER_OF_THE_PACK`, `DEBUFF_CYCLONE`, `DEBUFF_ENTANGLING_ROOTS` added to `spells.lua`.
- **`try_claw` forward declaration:** Fixed Lua error "attempt to call global `try_claw` (a nil value)" — function was defined after its call site.

### EAX Rogue Assassination
- **Combo points:** Same fix as above — `me:get_power(COMBOPOINTS_TBC)` on player.
- **Vanish:** Auto-triggers at <30% HP as an emergency escape.
- **Sprint:** Auto-triggers when target is out of melee range to close the gap.
- **Blind:** Auto-triggers at <35% HP as a defensive CC.
- **Rupture:** Now enabled by default.

### EAX Rogue Combat
- **Combo points:** Same fix as above.

### EAX Rogue Subtlety
- **Combo points:** Same fix as above.

### EAX Mage Fire
- **Molten Armor:** Auto-maintained as a self-buff when not active.
- **Blast Wave:** Added with toggle (default on).
- **Dragon's Breath:** Added with toggle (default on).

### EAX Mage Arcane
- **Arcane Intellect:** Auto-maintained as a self-buff.
- **Cone of Cold:** Added with toggle (default on).

### EAX Mage Frost
- **Ice Barrier:** Auto-casts when below 80% HP. Toggle (default on).
- **Cone of Cold:** Added with toggle (default on).

### EAX Paladin Retribution
- **Hammer of Wrath:** Auto-fires at <20% target HP (execute range).
- **Divine Plea:** Auto-fires at <30% mana.
- **Lay on Hands:** Auto-fires at <15% own HP (emergency).
- **Seal twisting:** Enabled by default in raids.

### EAX Priest Shadow
- **Inner Fire:** Auto-maintained as a self-buff.
- **Fade:** Auto-triggers at <50% HP to drop threat.
- **Psychic Scream:** Auto-triggers at <40% HP for defensive AoE fear.

### EAX Priest Discipline
- **Inner Fire:** Auto-maintained as a self-buff. Was defined in spells.lua but never resolved or used.

### EAX Shaman Elemental
- **Earth Shock:** Auto-used as an interrupt when target is casting/channelling.
- **Frost Shock:** Auto-used to slow moving melee attackers.
- **Prepull totems:** Enabled by default.

### EAX Shaman Enhancement
- **Prepull totems:** Enabled by default.

### EAX Shaman Restoration
- **Bloodlust on pull:** Enabled by default.
- **Wrath of Air totem:** Enabled by default.
- **Purge:** Enabled by default.

### EAX Warlock Affliction
- **Fel Armor:** Auto-maintained as a self-buff.
- **Curse of Elements:** Auto-applied to target (toggle, default on).
- **Death Coil:** Auto-fires at <40% own HP for defensive use.
- **Prefer Doom:** Enabled by default.

### EAX Druid Balance
- **Berserk:** Auto-fires on pull when in combat.
- **Typhoon:** Auto-fires at <50% HP as a defensive knockback.
- **Tranquility:** Enabled by default.

---

## [2.0.2] — Previous Release

Initial public release of all 21 EAX specs for Project Sylvanas TBC.
