-- test_warlock_live_fixes.lua -- Warlock live-correctness regression tests.
-- WHAT:  Pins the 2026-08 live-audit fixes across affliction/demonology/
--        destruction: SE-talent + mana gating, spread rank ladders, pre-pull
--        Shadow Bolt reachability, pet-cast Seduction, FelDomination CD gate,
--        OOC Healthstone parity, dead-metadata alignment, ManaGem order.
-- WHEN:  Standalone (not registered in any runner): lua EaxRotations/tests/test_warlock_live_fixes.lua
-- WHY:   Each assertion maps 1:1 to a verified live-correctness bug so a
--        future refactor cannot silently re-introduce it.
-- SAFETY: Pure unit tests with a mocked _G.EaxRotations + stubbed shared
--         modules; no game data, no banned APIs.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock NS + shared-module stubs
-- ============================================================================
local _now = 1000
local _se_known = true            -- NS.spell_exists gate for Shadow Embrace
local _spell_ready_override = nil -- nil => ready
local _has_item_result = true     -- NS.has_item gate (soul shards)
local _use_item_result = false    -- NS.use_item_by_id result
local _get_pet_result = nil       -- NS.GetPet result (destro FelDomination)
local _debuff_up_mode = "none"    -- "none" | "low_rank_only" (172)
local pet_cast_calls = {}

_G.EaxRotations = {
    CLASS_ID = { WARLOCK = 9 },
    PLAYER_UNIT = {},
    WarlockSpells = {
        Corruption = { ids = { 27216 }, name = "Corruption" },
        CurseOfAgony = { ids = { 27218 }, name = "CurseOfAgony" },
        CurseOfDoom = { ids = { 30910 }, name = "CurseOfDoom" },
        CurseElements = { ids = { 27228 }, name = "CurseElements" },
        CurseOfRecklessness = { ids = { 27226 }, name = "CurseOfRecklessness" },
        CurseOfWeakness = { ids = { 30909 }, name = "CurseOfWeakness" },
        Immolate = { ids = { 27215 }, name = "Immolate" },
        LifeTap = { ids = { 27222 }, name = "LifeTap" },
        ShadowBolt = { ids = { 27209 }, name = "ShadowBolt" },
        SiphonLife = { ids = { 30911 }, name = "SiphonLife" },
        SummonFelhunter = { ids = { 691 }, name = "SummonFelhunter" },
        UnstableAffliction = { ids = { 30405 }, name = "UnstableAffliction" },
        Soulshatter = { ids = { 29858 }, name = "Soulshatter" },
        DeathCoil = { ids = { 27223 }, name = "DeathCoil" },
        FelArmor = { ids = { 28189 }, name = "FelArmor" },
        FelDomination = { ids = { 18708 }, name = "FelDomination" },
        Incinerate = { ids = { 32231 }, name = "Incinerate" },
        Shadowburn = { ids = { 30546 }, name = "Shadowburn" },
        Shadowfury = { ids = { 30414 }, name = "Shadowfury" },
        Conflagrate = { ids = { 30912 }, name = "Conflagrate" },
        DrainSoul = { ids = { 27217 }, name = "DrainSoul" },
        Fear = { ids = { 6215 }, name = "Fear" },
        HowlofTerror = { ids = { 17928 }, name = "HowlofTerror" },
        Hellfire = { ids = { 27213 }, name = "Hellfire" },
        RainOfFire = { ids = { 27212 }, name = "RainOfFire" },
        Seduction = { ids = { 6358 }, name = "Seduction" },
        SoulFire = { ids = { 30545 }, name = "SoulFire" },
        SummonFelguard = { ids = { 30146 }, name = "SummonFelguard" },
        SummonImp = { ids = { 688 }, name = "SummonImp" },
        DarkPact = { ids = { 27265 }, name = "DarkPact" },
        HealthFunnel = { ids = { 27259 }, name = "HealthFunnel" },
        SeedOfCorruption = { ids = { 27243 }, name = "SeedOfCorruption" },
    },
    spell_action = function(ids, label) return { ids = ids, name = label or "spell" } end,
    log = function() end,
    log_warning = function() end,
    time_now = function() return _now end,
    rotation_registry = { register = function() end },
    GetPlayer = function()
        return {
            get_class = function() return 9 end,
            get_race_id = function() return 1 end,
            get_mana_percentage = function() return 100 end,
            get_health_percentage = function() return 100 end,
            is_moving = function() return false end,
            has_pet = function() return false end,
            get_pet = function() return nil end,
        }
    end,
    GetPet = function() return _get_pet_result end,
    unit_alive = function(unit) return unit ~= nil end,
    unit_health_pct = function(unit)
        if unit and unit.get_health_percentage then return unit:get_health_percentage() end
        return 100
    end,
    unit_mana_pct = function(unit) return 100 end,
    spell_exists = function(spell) return _se_known end,
    is_spell_learned = function(id) return true end,
    spell_ready = function(spell, target, opts)
        if _spell_ready_override ~= nil then return _spell_ready_override end
        return true
    end,
    get_spell_id = function(spell)
        if type(spell) == "table" and type(spell.ids) == "table" and spell.ids[1] then
            return spell.ids[1]
        end
        if type(spell) == "number" then return spell end
        return nil
    end,
    debuff_up = function(unit, ids)
        if _debuff_up_mode == "low_rank_only" then
            for _, id in ipairs(ids or {}) do
                if id == 172 then return true end
            end
            return false
        end
        return false
    end,
    debuff_remains = function() return 0 end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    has_player_buff = function() return false end,
    has_item = function(id) return _has_item_result end,
    use_item_by_id = function(id) return _use_item_result end,
    is_item_ready = function(id) return true end,
    should_refresh_dot = function(remains, window, ttd, duration)
        return (remains or 0) < (window or 1.5)
    end,
    try_cast = function() return true end,
    try_cast_position = function() return true end,
    cast_ground_aoe = nil, -- cleared per-test so the get_aoe_cast_position path runs
    get_aoe_cast_position = function() return nil end,
    aoe_target_meets = function() return true end,
    AOE_RADIUS = { TARGET_15 = 15, GROUND_8 = 8, SELF_10 = 10 },
}

-- Stub shared modules so requires under the mock NS are deterministic.
package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() return true end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
    try_cast = function(spell_id, target)
        pet_cast_calls[#pet_cast_calls + 1] = { spell_id = spell_id, target = target }
        return true
    end,
}
-- Fake enemy scan for spread tests: healthy-ish (engaged), no DoTs by default.
local fake_enemy = {
    is_valid = function() return true end,
    get_health_percentage = function() return 80 end,
    get_target = function() return nil end,
    is_damage_immune = function() return false end,
}
package.loaded["shared/ts_helper_sylvanas"] = {
    get_dps_targets = function(n) return { fake_enemy } end,
}

local orig_pcall = _G.pcall
_G.pcall = function(fn, path, ...)
    if type(path) == "string" then
        if path:find("izi_sdk") then return false, nil end
        if path:find("tbc_data_sylvanas") then return true, { ITEMS = { potions = {} } } end
    end
    return orig_pcall(fn, path, ...)
end
local orig_require = _G.require
_G.require = function(path)
    if type(path) == "string" then
        if path:find("izi_sdk") then return nil end
        if path:find("tbc_data_sylvanas") then return { ITEMS = { potions = {} } } end
    end
    return orig_require(path)
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name, 2)
end

-- ============================================================================
-- AFFLICTION
-- ============================================================================
local affl = dofile("EaxRotations/classes/warlock/affliction_sylvanas.lua")
assert_true(affl and affl.strategies, "affliction should load")

-- (2) NightfallProc must appear exactly once (duplicate DSL def removed).
local nightfall_count = 0
for _, s in ipairs(affl.strategies) do
    if s.name == "NightfallProc" then nightfall_count = nightfall_count + 1 end
end
assert_eq(nightfall_count, 1, "NightfallProc must appear exactly once (duplicate DSL def removed)")

-- (1) ShadowEmbraceMaintenance: talent-gated + low-mana guarded filler.
local se = find_strategy(affl.strategies, "ShadowEmbraceMaintenance")
_se_known = false
assert_false(se.matches({ has_valid_enemy_target = true }, { se_stacks = 0, mana_pct = 100, hp_pct = 100 }),
    "SE maintenance must NOT match when the Shadow Embrace talent is not known")
_se_known = true
assert_true(se.matches({ has_valid_enemy_target = true }, { se_stacks = 0, mana_pct = 100, hp_pct = 100 }),
    "SE maintenance should match with talent known, 0 stacks, full mana")
assert_false(se.matches({ has_valid_enemy_target = true }, { se_stacks = 5, mana_pct = 100, hp_pct = 100 }),
    "SE maintenance must not match at 5 stacks")
assert_false(se.matches({ has_valid_enemy_target = true }, { se_stacks = 0, mana_pct = 3, hp_pct = 20 }),
    "SE maintenance must not match at critical mana + low HP (filler mana guard)")
assert_true(se.matches({ has_valid_enemy_target = true }, { se_stacks = 0, mana_pct = 3, hp_pct = 80 }),
    "SE maintenance should match at critical mana when HP is safe (Life Tap available)")

-- (3) AmplifyCurse: still matches on long-lived targets after dead sub-check removal.
local amp = find_strategy(affl.strategies, "AmplifyCurse")
assert_true(amp.matches(
    { target = {}, ttd_known = true, ttd = 120, settings = { aff_use_amplify_curse = true } },
    { amplify_curse_ready = true, agony_remains = 0, doom_remains = 0 }),
    "AmplifyCurse should match on a long-lived target with a curse ready to apply")

-- (5) Spread strategies check the FULL rank ladder (low-rank debuff blocks spread).
local corr_spread = find_strategy(affl.strategies, "CorruptionSpread")
assert_true(corr_spread.matches({ has_valid_enemy_target = true }, { corruption_remains = 5 }),
    "CorruptionSpread should find a spread target when no rank of Corruption is present")
_now = 2000 -- force find_dot_target per-tick cache refresh
_debuff_up_mode = "low_rank_only"
assert_false(corr_spread.matches({ has_valid_enemy_target = true }, { corruption_remains = 5 }),
    "CorruptionSpread must NOT spread to a target already carrying a low-rank Corruption debuff")
_debuff_up_mode = "none"

-- (6) PreCombatPull: sits ABOVE the DoT lane so the pre-pull Shadow Bolt fires.
assert_eq(affl.strategies[1].name, "PreCombatPull",
    "PreCombatPull must sit at the top of the priority list (above the DoT lane)")
local pre = affl.strategies[1]
assert_true(pre.matches({ in_combat = false, has_valid_enemy_target = true }),
    "PreCombatPull should match OOC with a manual target")
assert_false(pre.matches({ in_combat = true, has_valid_enemy_target = true }),
    "PreCombatPull must not match in combat")

-- (8) SummonFelhunter works with a target selected (pre-pull summon).
local felh = find_strategy(affl.strategies, "SummonFelhunter")
assert_true(felh.matches({ in_combat = false, has_valid_enemy_target = true },
    { has_pet = false, has_demonic_sacrifice = false }),
    "SummonFelhunter must match OOC even with a target selected")
assert_false(felh.matches({ in_combat = true, has_valid_enemy_target = true },
    { has_pet = false, has_demonic_sacrifice = false }),
    "SummonFelhunter must not match in combat")
assert_false(felh.matches({ in_combat = false }, { has_pet = true, has_demonic_sacrifice = false }),
    "SummonFelhunter must not match when a pet is active")

-- (7) ManaPotion execute reports whether the item was actually used.
local mp = find_strategy(affl.strategies, "ManaPotion")
_use_item_result = false
assert_false(mp.execute(nil, { mana_potion_id = 33935 }),
    "ManaPotion execute must return false when the item was not used")
_use_item_result = true
assert_true(mp.execute(nil, { mana_potion_id = 33935 }),
    "ManaPotion execute must return true when the item was used")

-- (9) RainOfFire execute passes a NUMERIC spell id to get_aoe_cast_position.
local rof = find_strategy(affl.strategies, "RainOfFire")
local captured_pos_id = nil
_G.EaxRotations.cast_ground_aoe = nil
_G.EaxRotations.get_aoe_cast_position = function(spell_id, target, radius, max_range)
    captured_pos_id = spell_id
    return { x = 1, y = 2, z = 3 }, 1
end
assert_true(rof.execute({ target = {}, has_valid_enemy_target = true }) == true,
    "RainOfFire execute should succeed via the position path")
assert_eq(captured_pos_id, 27212,
    "RainOfFire must pass a numeric spell id (27212) to get_aoe_cast_position")

-- ============================================================================
-- DEMONOLOGY
-- ============================================================================
local demo = dofile("EaxRotations/classes/warlock/demonology_sylvanas.lua")
assert_true(demo and demo.strategies, "demonology should load")

-- (1) LifeTap must appear exactly once (duplicate strategy entry removed).
local lifetap_count = 0
for _, s in ipairs(demo.strategies) do
    if s.name == "LifeTap" then lifetap_count = lifetap_count + 1 end
end
assert_eq(lifetap_count, 1, "demonology LifeTap must appear exactly once (duplicate removed)")

-- (5) SoulFire: soul-shard gate (mirrors destruction's has_item gate).
local sf = find_strategy(demo.strategies, "SoulFire")
_has_item_result = false
assert_false(sf.matches({ target = {} }, { soul_fire_ready = true, target_hp_pct = 20 }),
    "SoulFire must not match without a soul shard in bags")
_has_item_result = true
assert_true(sf.matches({ target = {} }, { soul_fire_ready = true, target_hp_pct = 20 }),
    "SoulFire should match with a soul shard in bags")
assert_false(sf.matches({ target = {} }, { soul_fire_ready = true, target_hp_pct = 80 }),
    "SoulFire must not match above the execute threshold")

-- (3) Seduction is cast by the PET, not the player (6358 is the Succubus's spell).
local sed = find_strategy(demo.strategies, "Seduction")
pet_cast_calls = {}
assert_true(sed.execute({ target = "enemy1" }) == true,
    "Seduction execute should return the pet-cast result")
assert_eq(#pet_cast_calls, 1, "Seduction execute must call pet_manager.try_cast")
assert_eq(pet_cast_calls[1].spell_id, 6358, "Seduction must pet-cast spell 6358")
assert_eq(pet_cast_calls[1].target, "enemy1", "Seduction pet cast must target the enemy")

-- (6) build_state safe defaults: target/has_soul_link present via the schema.
local demo_state = demo.build_state({ now = 5000, target = "t", me = nil, in_combat = false })
assert_eq(demo_state.target, "t", "demonology state should expose target")
assert_false(demo_state.has_soul_link, "demonology state should default has_soul_link to false")

-- ============================================================================
-- DESTRUCTION
-- ============================================================================
local destro = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
assert_true(destro and destro.strategies, "destruction should load")

-- (1) FelDomination: OOC + no-pet gate protects the 15-minute cooldown.
local fd = find_strategy(destro.strategies, "FelDomination")
_get_pet_result = nil
assert_true(fd.matches({ in_combat = false }, {}),
    "FelDomination should match OOC with no pet")
assert_false(fd.matches({ in_combat = true }, {}),
    "FelDomination must not match in combat")
_get_pet_result = { is_alive = function() return true end }
assert_false(fd.matches({ in_combat = false }, {}),
    "FelDomination must not burn the 15-min CD with a live pet OOC")
_get_pet_result = nil

-- (3) DeathCoil: readiness check added (was HP-only).
local dc = find_strategy(destro.strategies, "DeathCoil")
_spell_ready_override = true
assert_true(dc.matches({ target = {} }, { hp = 30 }),
    "DeathCoil should match at low HP when ready")
_spell_ready_override = false
assert_false(dc.matches({ target = {} }, { hp = 30 }),
    "DeathCoil must not match when the spell is not ready")
_spell_ready_override = nil
assert_false(dc.matches({ target = {} }, { hp = 80 }),
    "DeathCoil must not match at high HP")

-- (2) Immolate DSL restores the not_moving gate (metadata dropped by substitution).
local imm = find_strategy(destro.strategies, "Immolate")
assert_false(imm.matches({ is_moving = true }, { immolate_remains = 0 }),
    "Immolate must not fire while moving (not_moving metadata restored)")
assert_true(imm.matches({ is_moving = false }, { immolate_remains = 0 }),
    "Immolate should fire when stationary and Immolate is expired")

-- (7) Healthstone usable OOC (require_in_combat = false parity with other specs).
local hs = find_strategy(destro.strategies, "Healthstone")
assert_true(hs.matches(
    { in_combat = false, hp = 25, is_casting = false,
      settings = { use_auto_consumables = true, use_healthstones = true, healthstone_hp = 40 } },
    { healthstone_ready = true, healthstone_id = 22105 }),
    "destruction Healthstone must be usable out of combat (require_in_combat = false parity)")

-- (6) ManaGem sits between DarkPact (5) and DrainLife (6) — comment/index agree.
local mg_index, darkpact_index, drain_index = nil, nil, nil
for i, s in ipairs(destro.strategies) do
    if s.name == "ManaGem" then mg_index = i end
    if s.name == "DarkPact" then darkpact_index = i end
    if s.name == "DrainLife" then drain_index = i end
end
assert_true(mg_index ~= nil and darkpact_index ~= nil and drain_index ~= nil,
    "ManaGem / DarkPact / DrainLife must all exist in destruction")
assert_true(darkpact_index < mg_index and mg_index < drain_index,
    "ManaGem must sit between DarkPact and DrainLife (after DarkPact=5, before DrainLife=6)")

-- (5) Immolate pandemic constant removed: the DSL relies on should_refresh_dot's
-- 1.5s window only (no dead 3.5s pre-check). Verified above via is_moving + expiry.

_G.require = orig_require
_G.pcall = orig_pcall

print("PASS test_warlock_live_fixes")
