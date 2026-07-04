# EAX Pet Handling — Complete Reference

> **Last Updated:** 2026-07-04
> **Applies To:** TBC Classic Anniversary (2.5.5.x client)
> **File:** `EaxRotations/shared/pet_manager_sylvanas.lua`
> **Dispatcher:** `EaxRotations/main_sylvanas.lua`

---

## 1. Which Classes Have Pets?

| Class | Pet | How Summoned | Auto-Attacks | Auto-Casts Abilities |
|-------|-----|-------------|--------------|---------------------|
| **Hunter** (all specs) | Tamed beast | Call Pet (883) | ✅ Yes | ✅ Yes (pet_manager) |
| **Warlock** (Demonology) | Felguard/Imp/VW/Succubus/Felhunter | Summon spells | ✅ Yes | ✅ Yes (pet_manager) |
| **Mage** (Frost) | Water Elemental | Summon Water Elemental (31687) | ✅ Yes | ✅ Yes (pet_manager) |
| **Priest** (Shadow) | Shadowfiend | Shadowfiend spell | ❌ No | ❌ No (not a controllable pet) |
| **Shaman** (Enhancement) | Spirit Wolves | Feral Spirit (Wrath) | N/A | N/A (not in TBC) |

**Key insight:** In TBC Classic Anniversary (2.5.5.x), the Water Elemental was **backported from Wrath** — it is a REAL Frost Mage talent (31687) with Waterbolt (31707) and Freeze (33395). Verified against DBC + lexxer.org + wowhead.com/tbc.

---

## 2. What Pet Abilities Are Handled?

### Hunter Pet Abilities (pet_manager)

| Ability | Spell IDs | Cooldown | Type | Notes |
|---------|-----------|----------|------|-------|
| **Growl** (taunt) | 2649, 14268-14271, 14925 | 5s | Threat | Scanned via `NS.spell_id_is_known()` |
| **Claw** | 2981, 14261-14265 | 2s | Damage | Highest known rank |
| **Bite** | 17253-17257, 27050 | 2s | Damage | Fallback if no Claw |
| **Gore** | 35290-35291 | 2s | Damage | Boar family |
| **Lightning Breath** | 25011-25016 | 2s | Damage | Wind serpent family |
| **Poison Spit** | 24640 | 2s | Damage | Serpent family |
| **Howl** (Furious) | 24597-24600 | 6s | Buff | Screech family |
| **Screech** | 24604 | 6s | Debuff | Bat family |
| **Thunderstomp** | 26090, 26093 | 6s | AoE | Gorilla family |
| **Dash** | 23099 | 6s | Speed | Cat/wolf family |
| **Dive** | 23145 | 6s | Speed | Bird of prey |

**NOT handled (spec-level):**
- **Intimidation** (19577) — BM talent stun. Cast by HUNTER, pet's next melee stuns. Lives in `beast_mastery_sylvanas.lua` spec rotation, NOT pet_manager.
- **Kill Command** (34026) — Hunter spell, not pet ability.
- **Bestial Wrath** (19574) — Hunter spell, not pet ability.

### Warlock Pet Abilities (pet_manager)

| Ability | Spell IDs | Cooldown | Pet | Notes |
|---------|-----------|----------|-----|-------|
| **Firebolt** | 3110, 7799-7802, 11762-11763, 27267 | 2s | Imp | Primary ability |
| **Cleave** | 30213 | 2s | Felguard | Primary ability |
| **Lash of Pain** | 7814, 11778-11781 | 2s | Succubus | Primary ability |
| **Suffering** (taunt) | 17735, 11774-11775 | 2s | Voidwalker | Primary ability |
| **Bite** | 54053, 54049-54052 | 2s | Felhunter | Primary ability |
| **Intercept** | 30198, 30197, 30196 | 15s | Felguard | Gap closer (>8 yards) |

**NOT handled (spec/middleware-level):**
- **Spell Lock** (19647) — Felhunter interrupt. Lives in `interrupt_manager_sylvanas.lua` + warlock middleware.
- **Devour Magic** (19505) — Felhunter dispel. Lives in warlock `middleware_sylvanas.lua`.
- **Seduction** (6358) — Succubus CC. Not auto-cast (requires target selection).
- **Sacrifice** (7812) — Voidwalker defensive. Not auto-cast (sacrifices pet).
- **Consume Shadows** (17767) — Voidwalker self-heal. Not auto-cast (OOC only).

### Mage Pet Abilities (pet_manager)

| Ability | Spell ID | Cooldown | Notes |
|---------|----------|----------|-------|
| **Waterbolt** | 31707 | 3s | Auto-cast by default; we cast manually as fallback |
| **Freeze** | 33395 | 25s | AoE root (8yd radius). Skips if target already rooted. |

---

## 3. Engagement Safety

All pets use `_engaged_with_player(context)` — same contract as Shadow Priest DoTs:

```lua
-- Pet only attacks if target is engaged (has targeted player or taken damage)
if not _engaged_with_player(context) then return end
```

This prevents pets from pulling patrols when the player tab-targets an unengaged mob.

---

## 4. How to Add a New Pet Ability

### Step 1: Add spell IDs to pet_manager

```lua
-- In the spell ID tables section
local NEW_ABILITY = { 12345, 12346 }  -- highest rank first
```

### Step 2: Add to the appropriate scan function

```lua
-- In _scan_hunter_spells(), _scan_warlock_spells(), or _scan_mage_spells()
for i = #NEW_ABILITY, 1, -1 do
    if NS.spell_id_is_known(NEW_ABILITY[i]) then
        st.new_ability_id = NEW_ABILITY[i]
        break
    end
end
```

### Step 3: Add state fields to `_get_state()`

```lua
new_ability_id = nil,
last_new_ability = 0,
```

### Step 4: Add cast logic in `on_update()`

```lua
if st.new_ability_id and now - st.last_new_ability > COOLDOWN then
    if M.try_cast(st.new_ability_id, target) then
        st.last_new_ability = now
        return
    end
end
```

### Step 5: Verify in DBC

```bash
# Check spell exists in client DB
grep "\[12345\]" wowheadScrape/dbc_extract/lua/spell_db.lua
# Or query lexxer
# https://lexxer.org/api/v1/spells/12345?game=tbc
```

### Step 6: Run tests

```bash
luac -p EaxRotations/shared/pet_manager_sylvanas.lua
lua EaxRotations/tests/run_rotation_tests.lua
```

---

## 5. Common Pitfalls

| Pitfall | Why | Fix |
|---------|-----|-----|
| Pet pulls patrols | No engagement check | Add `_engaged_with_player()` gate |
| Pet attack spams every frame | No throttle on `pet_attack()` | Throttle to 1s (`now - last > 1`) |
| Warlock pet never attacks | Dispatcher is hunter-only | Extend to `warlock` class key |
| Mage pet never attacks | Forgot mage in dispatcher | Extend to `mage` class key |
| Ability not casting | Spell ID not in DBC | Verify against `wowsims.db` or lexxer |
| Felhunter interrupt not firing | Interrupt is spec-level, not pet_manager | Check `interrupt_manager_sylvanas.lua` |
| Intimidation not firing | It's a hunter talent, not pet ability | Check `beast_mastery_sylvanas.lua` |

---

## 6. Verification Commands

```bash
# Check which spells exist in DBC
grep "\[31687\]" wowheadScrape/dbc_extract/lua/spell_db.lua   # Summon Water Elemental
grep "\[31707\]" wowheadScrape/dbc_extract/lua/spell_db.lua   # Waterbolt
grep "\[33395\]" wowheadScrape/dbc_extract/lua/spell_db.lua   # Freeze
grep "\[19577\]" wowheadScrape/dbc_extract/lua/spell_db.lua   # Intimidation
grep "\[30198\]" wowheadScrape/dbc_extract/lua/spell_db.lua   # Felguard Intercept

# Check pet_manager calls in dispatcher
grep "pet_manager" EaxRotations/main_sylvanas.lua

# Check which classes trigger pet_manager
grep "class_key.*hunter\|class_key.*warlock\|class_key.*mage" EaxRotations/main_sylvanas.lua
```

---

## 7. History

| Date | Change | Commit |
|------|--------|--------|
| 2026-07-04 | Complete pet_manager rewrite: engagement safety, warlock support, mage support | `55498f55` |
| 2026-07-04 | Add Felguard Intercept + BM Intimidation | `54e36653` |

---

*This document is the single source of truth for pet handling in EAX. Update it when adding new pet abilities or changing pet behavior.*
