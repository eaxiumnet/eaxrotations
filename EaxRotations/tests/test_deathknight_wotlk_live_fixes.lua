-- test_deathknight_wotlk_live_fixes.lua — Death Knight WotLK W3.3 live-fix regression tests.
-- WHAT:  pins the 2026-08-13 W3.3 register fixes: mock-only action:cooldown_remaining()
--        -> NS.cooldown_remains (frost UA/ERW readiness, leveling ERW readiness),
--        mock-only action:cast_safe() -> NS.try_cast (frost/blood/unholy presence
--        executes), phantom context.is_boss -> context.target_is_boss (unholy
--        SummonGargoyle), per-frame rune-state fan-out -> ONE get_rune_state()
--        call (frost) / 2s-TTL snapshot (unholy), blood DeathStrike disease-uptime
--        guard (frost_fever_remains > 3), long-CD gate args aligned with the
--        class-table cooldown fields (DRW 90 / UA 60 / ERW 300), ghoul pet
--        command lanes (Gnaw/Leap), leveling rank-list decontamination +
--        RuneManager.get_runic_power (no legacy me:get_runic_power read).
-- WHEN:  standalone: lua EaxRotations/tests/test_deathknight_wotlk_live_fixes.lua
--        (NOT registered in run_rotation_tests.lua — W3.5 registers wave files).
-- WHY:   every fix must fail loudly if a future edit regresses it. The action
--        tables are built in the REAL NS.spell_action shape (id/ids/IsReady/
--        IsInRange/Cast/GetSpellRank/GetSpellLevel/GetSpellPowerCost/IsExists —
--        core_sylvanas.lua:1410-1454) with NO cast_safe/cooldown_remaining
--        members, so a regression back to the mock-only calls fails here.
-- SAFETY: Pure unit tests with a mocked _G.EaxRotations + preload-mocked shared
--        managers; the REAL shared/spec_kit_sylvanas + shared/strategy_dsl_sylvanas
--        run the DSL match/execute paths (no hand-rolled condition evaluators).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- ---------------------------------------------------------------------------
-- Spies / state banks shared by the mocked NS below.
-- ---------------------------------------------------------------------------
local spies = {
    try_cast_calls = {},  -- { spell = <action>, label = <string> }
    long_cd_args = {},    -- gate seconds args passed to NS.should_use_long_cd
    rune_state_calls = 0, -- get_rune_state() invocation count
}
local cooldown_bank = {}  -- [spell_id] = seconds remaining (absent = ready)
local rune_bank = { blood = 2, frost = 2, unholy = 2, death = 0, ready = { blood = 2, frost = 2, unholy = 2, death = 0 } }
local rp_value = 50
local clock = 100.0
local pet_flag = false
local boss_flag = false      -- NS.unit_is_boss(target) result
local interrupt_target = false
local desired_presence = nil -- mutable; consumed by the presence_manager mock

-- Production-shape spell_action builder (core_sylvanas.lua:1410-1454 surface —
-- deliberately NO cast_safe / cooldown_remaining members).
local function spell_action(ids, name)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        ids = type(ids) == "table" and ids or { ids },
        name = name or tostring(id),
        IsExists = function(self) return true end,
        IsReady = function(self, target) return true end,
        IsInRange = function(self, target) return true end,
        Cast = function(self, target) return true end,
        GetSpellRank = function(self) return 1 end,
        GetSpellLevel = function(self) return 1 end,
        GetSpellPowerCost = function(self) return 0 end,
    }
end

local function make_ns()
    local ns = {
        is_wotlk = function() return true end,
        GetPlayer = function() return nil end,
        me = { get_health_percentage = function() return 100 end },
        rotation_registry = { register = function() end },
        log = function() end,
        log_warning = function() end,
        get_setting = function(key, default) return default end,
        buff_up = function() return false end,
        debuff_remains = function() return 0 end,
        aoe_target_meets = function() return false end,
        AOE_RADIUS = { TARGET_10 = 10, GROUND_10 = 10 },
        spell_action = spell_action,
        -- REAL cooldown read (bank-aware; accepts spell_action tables via .ids).
        cooldown_remains = function(spell)
            local id = type(spell) == "table" and spell.ids and spell.ids[1] or spell
            return cooldown_bank[id] or 0
        end,
        try_cast = function(spell, target, label)
            spies.try_cast_calls[#spies.try_cast_calls + 1] = { spell = spell, label = label }
            return true
        end,
        should_use_long_cd = function(context, seconds)
            spies.long_cd_args[#spies.long_cd_args + 1] = seconds
            return true
        end,
        time_now = function() return clock end,
        has_pet = function() return pet_flag end,
        unit_is_boss = function(target) return boss_flag end,
        DeathKnightSpells = {
            IcyTouch          = spell_action({ 49909, 45477, 49903, 49904 }, "IcyTouch"),
            PlagueStrike      = spell_action({ 49921, 49917, 49918, 49919, 49920 }, "PlagueStrike"),
            Obliterate        = spell_action({ 51425, 49020, 51423, 51424 }, "Obliterate"),
            HowlingBlast      = spell_action({ 51411, 49184, 51409, 51410 }, "HowlingBlast"),
            FrostStrike       = spell_action({ 55268, 49143, 51414 }, "FrostStrike"),
            BloodStrike       = spell_action({ 49930, 45902, 49926 }, "BloodStrike"),
            HornOfWinter      = spell_action({ 57623, 57330 }, "HornOfWinter"),
            UnbreakableArmor  = spell_action(51271, "UnbreakableArmor"),
            EmpowerRuneWeapon = spell_action(47568, "EmpowerRuneWeapon"),
            MindFreeze        = spell_action(47528, "MindFreeze"),
            FrostPresence     = spell_action(48263, "FrostPresence"),
            Pestilence        = spell_action(50842, "Pestilence"),
            HeartStrike       = spell_action({ 55262, 55050 }, "HeartStrike"),
            DeathStrike       = spell_action({ 49999, 49998, 45463, 49924 }, "DeathStrike"),
            DeathCoil         = spell_action({ 49895, 47541 }, "DeathCoil"),
            DancingRuneWeapon = spell_action(49028, "DancingRuneWeapon"),
            VampiricBlood     = spell_action(55233, "VampiricBlood"),
            IceboundFortitude = spell_action(48792, "IceboundFortitude"),
            BloodPresence     = spell_action(48266, "BloodPresence"),
            UnholyPresence    = spell_action(48265, "UnholyPresence"),
            ScourgeStrike     = spell_action({ 55271, 55090 }, "ScourgeStrike"),
            DeathAndDecay     = spell_action({ 49938, 43265 }, "DeathAndDecay"),
            SummonGargoyle    = spell_action(49206, "SummonGargoyle"),
            BoneShield        = spell_action(49222, "BoneShield"),
            RaiseDead         = spell_action(46584, "RaiseDead"),
            GhoulGnaw         = spell_action(47481, "GhoulGnaw"),
            GhoulLeap         = spell_action(47482, "GhoulLeap"),
        },
        DeathKnightConstants = {
            FROST_FEVER_DEBUFF  = { 55095 },
            BLOOD_PLAGUE_DEBUFF = { 55078 },
            HORN_OF_WINTER_BUFF = { 57330, 57623 },
        },
    }
    return ns
end

-- Shared-manager mocks (preload so the REAL spec files require() them hermetically).
package.preload["shared/aoe_hit_volume_sylvanas"] = function()
    return { install = function(ns) end }
end
package.preload["shared/rune_manager_sylvanas"] = function()
    return {
        get_rune_state = function()
            spies.rune_state_calls = spies.rune_state_calls + 1
            return { ready = rune_bank.ready }
        end,
        get_blood_runes_ready = function() return rune_bank.ready.blood end,
        get_frost_runes_ready = function() return rune_bank.ready.frost end,
        get_unholy_runes_ready = function() return rune_bank.ready.unholy end,
        get_death_runes_ready = function() return rune_bank.ready.death end,
        get_runic_power = function(unit) return rp_value end,
    }
end
package.preload["shared/presence_manager_sylvanas"] = function()
    local PRESENCE_IDS = { blood = 48266, frost = 48263, unholy = 48265 }
    return {
        presence_id = function(name) return PRESENCE_IDS[name] end,
        get_optimal_presence = function(context, state) return desired_presence end,
        should_switch_presence = function(context, state, name) return desired_presence == name end,
        current_presence = function() return nil end,
        current_presence_id = function() return nil end,
    }
end
package.preload["shared/interrupt_manager_sylvanas"] = function()
    return {
        register_interrupt_spell = function(class_key, name, spells) return nil end,
    }
end
package.preload["shared/leveling_helpers_sylvanas"] = function()
    return { should_interrupt = function(target) return interrupt_target end }
end
package.preload["shared/class_loader_sylvanas"] = function()
    return {
        create_loader = function() return function() end end,
        create_expansion_loader = function() return function() end end,
    }
end
-- REAL spec_kit + REAL strategy_dsl (loaded from disk, not mocked).
package.preload["shared/spec_kit_sylvanas"] = function()
    return dofile("EaxRotations/shared/spec_kit_sylvanas.lua")
end
package.preload["shared/strategy_dsl_sylvanas"] = function()
    return dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")
end

local function reset_spies()
    spies.try_cast_calls = {}
    spies.long_cd_args = {}
    spies.rune_state_calls = 0
    cooldown_bank = {}
    rune_bank = { blood = 2, frost = 2, unholy = 2, death = 0, ready = { blood = 2, frost = 2, unholy = 2, death = 0 } }
    rp_value = 50
    clock = 100.0
    pet_flag = false
    boss_flag = false
    interrupt_target = false
    desired_presence = nil
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name, 2)
end

-- ============================================================================
-- 1. frost: UA/ERW readiness reads NS.cooldown_remains (real shape), not
--    mock-only action:cooldown_remaining()
-- ============================================================================
reset_spies()
_G.EaxRotations = make_ns()
local frost = dofile("EaxRotations/classes/deathknight/frost_wotlk.lua")
assert_true(frost and frost.build_state, "frost_wotlk should load")

-- Production-shape guard: the mock actions must NOT carry the mock-only members
-- (the test is non-vacuous only if the shape matches the fix's premise).
assert_true(_G.EaxRotations.DeathKnightSpells.UnbreakableArmor.cast_safe == nil
    and _G.EaxRotations.DeathKnightSpells.UnbreakableArmor.cooldown_remaining == nil,
    "mock action shape must be the REAL spell_action shape (no cast_safe/cooldown_remaining)")

local fctx = { me = _G.EaxRotations.me, target = {}, in_combat = true, enemy_count = 1, settings = {} }
cooldown_bank[51271] = 0
cooldown_bank[47568] = 0
local fst = frost.build_state(fctx)
assert_true(fst.unbreakable_armor_ready == true, "frost UA ready must be true when NS.cooldown_remains(51271) <= 0")
assert_true(fst.empower_rune_weapon_ready == true, "frost ERW ready must be true when NS.cooldown_remains(47568) <= 0")
cooldown_bank[51271] = 30
cooldown_bank[47568] = 120
local fst_cd = frost.build_state(fctx)
assert_true(fst_cd.unbreakable_armor_ready == false, "frost UA ready must be false when on cooldown")
assert_true(fst_cd.empower_rune_weapon_ready == false, "frost ERW ready must be false when on cooldown")
print("PASS: frost UA/ERW readiness via NS.cooldown_remains (real action shape)")

-- ============================================================================
-- 2. frost: rune state is ONE get_rune_state() call sliced per type (the
--    48-pcall fan-out regression)
-- ============================================================================
spies.rune_state_calls = 0
rune_bank.ready = { blood = 1, frost = 1, unholy = 1, death = 1 }
local frs = frost.build_state(fctx)
assert_true(spies.rune_state_calls == 1,
    "frost build_state must call get_rune_state() exactly once (got " .. spies.rune_state_calls .. ")")
assert_true(frs.blood_runes_ready == 1 and frs.frost_runes_ready == 1
    and frs.unholy_runes_ready == 1 and frs.death_runes_ready == 1
    and frs.total_runes_ready == 4, "frost ready counts must slice from the single rune_state.ready map")
print("PASS: frost rune state single-call refactor (get_rune_state x1, sliced ready map)")

-- ============================================================================
-- 3. frost: UA/ERW lanes fire and pass the class-table-aligned gate args
--    (UA 60s, ERW 300s)
-- ============================================================================
spies.long_cd_args = {}
local ua = find_strategy(frost.strategies, "UnbreakableArmor")
assert_true(ua.matches(fctx, { in_combat = true, unbreakable_armor_up = false, unbreakable_armor_ready = true }),
    "frost UnbreakableArmor must match when ready + not up")
assert_true(spies.long_cd_args[#spies.long_cd_args] == 60,
    "frost UA long-CD gate must use 60 (3.3.5 UA CD), got " .. tostring(spies.long_cd_args[#spies.long_cd_args]))
assert_false(ua.matches(fctx, { in_combat = true, unbreakable_armor_up = true, unbreakable_armor_ready = true }),
    "frost UnbreakableArmor must NOT match while the buff is up")
local erw = find_strategy(frost.strategies, "EmpowerRuneWeapon")
assert_true(erw.matches(fctx, { in_combat = true, empower_rune_weapon_ready = true, total_runes_ready = 0 }),
    "frost EmpowerRuneWeapon must match with all runes spent")
assert_true(spies.long_cd_args[#spies.long_cd_args] == 300,
    "frost ERW long-CD gate must use 300 (5-min CD), got " .. tostring(spies.long_cd_args[#spies.long_cd_args]))
print("PASS: frost UA(60)/ERW(300) lanes fire with aligned gate args")

-- ============================================================================
-- 4. frost: FrostPresence execute casts via NS.try_cast (mock-only cast_safe
--    removed) — the lane actually applies Frost Presence
-- ============================================================================
reset_spies()
_G.EaxRotations = make_ns()
frost = dofile("EaxRotations/classes/deathknight/frost_wotlk.lua")
desired_presence = "frost"
local fp = find_strategy(frost.strategies, "FrostPresence")
assert_true(fp.matches(fctx, { frost_presence_up = false }),
    "frost FrostPresence must match when the presence manager desires frost")
assert_true(fp.execute(fctx, nil) == true,
    "frost FrostPresence execute must return true")
assert_true(#spies.try_cast_calls == 1 and spies.try_cast_calls[1].spell.id == 48263
    and spies.try_cast_calls[1].label == "FrostPresence",
    "frost FrostPresence execute must cast ACTION.FrostPresence (48263) via NS.try_cast")
desired_presence = nil
assert_false(fp.matches(fctx, { frost_presence_up = false }),
    "frost FrostPresence must NOT match when the manager desires another presence")
print("PASS: frost FrostPresence execute via NS.try_cast (48263)")

-- ============================================================================
-- 5. blood: DeathStrike disease-uptime guard (hp < 80 AND frost_fever_remains
--    > 3 — the frost-rune starvation fix)
-- ============================================================================
reset_spies()
_G.EaxRotations = make_ns()
local blood = dofile("EaxRotations/classes/deathknight/blood_wotlk.lua")
assert_true(blood and blood.build_state, "blood_wotlk should load")
local ds = find_strategy(blood.strategies, "DeathStrike")
assert_true(ds.matches({}, { hp = 70, frost_fever_remains = 5 }),
    "blood DeathStrike must match at hp 70 with Frost Fever up (>3s)")
assert_false(ds.matches({}, { hp = 70, frost_fever_remains = 2 }),
    "blood DeathStrike must NOT match at hp 70 with Frost Fever expiring (guard)")
assert_false(ds.matches({}, { hp = 90, frost_fever_remains = 5 }),
    "blood DeathStrike must NOT match at hp 90")
print("PASS: blood DeathStrike disease-uptime guard (hp<80 AND ff>3)")

-- ============================================================================
-- 6. blood: Presence execute casts the presence PresenceManager DESIRES via
--    NS.try_cast (not a hard-coded BloodPresence)
-- ============================================================================
desired_presence = "frost"
local bpres = find_strategy(blood.strategies, "Presence")
assert_true(bpres.matches({}, { presence = nil }),
    "blood Presence must match when the manager desires a switch")
spies.try_cast_calls = {}
assert_true(bpres.execute({ me = _G.EaxRotations.me }, {}) == true,
    "blood Presence execute must return true")
assert_true(#spies.try_cast_calls == 1 and spies.try_cast_calls[1].spell.id == 48263,
    "blood Presence must cast the DESIRED presence (frost 48263), got "
    .. tostring(spies.try_cast_calls[1] and spies.try_cast_calls[1].spell.id))
desired_presence = "unholy"
spies.try_cast_calls = {}
assert_true(bpres.execute({ me = _G.EaxRotations.me }, {}) == true
    and spies.try_cast_calls[1].spell.id == 48265,
    "blood Presence must cast unholy 48265 when the manager desires unholy")
desired_presence = "blood"
spies.try_cast_calls = {}
assert_true(bpres.execute({ me = _G.EaxRotations.me }, {}) == true
    and spies.try_cast_calls[1].spell.id == 48266,
    "blood Presence must cast blood 48266 when the manager desires blood")
desired_presence = nil
assert_false(bpres.matches({}, { presence = nil }),
    "blood Presence must NOT match when the manager has no desired presence")
print("PASS: blood Presence casts desired presence via NS.try_cast (blood/frost/unholy)")

-- ============================================================================
-- 7. blood: DancingRuneWeapon long-CD gate uses 90 (3.3.5 DRW CD)
-- ============================================================================
spies.long_cd_args = {}
local drw = find_strategy(blood.strategies, "DancingRuneWeapon")
assert_true(drw.matches({}, { in_combat = true, target_hp = 100, runic_power = 60 }),
    "blood DancingRuneWeapon must match on a boss-health target with 60 RP")
assert_true(spies.long_cd_args[#spies.long_cd_args] == 90,
    "blood DRW long-CD gate must use 90 (3.3.5 DRW CD), got " .. tostring(spies.long_cd_args[#spies.long_cd_args]))
print("PASS: blood DancingRuneWeapon gate arg 90")

-- ============================================================================
-- 8. unholy: state.is_boss reads the REAL dispatcher field
--    context.target_is_boss (phantom context.is_boss removed as the primary
--    source) — SummonGargoyle must be fireable
-- ============================================================================
reset_spies()
_G.EaxRotations = make_ns()
local unholy = dofile("EaxRotations/classes/deathknight/unholy_wotlk.lua")
assert_true(unholy and unholy.build_state, "unholy_wotlk should load")
local uctx = { me = _G.EaxRotations.me, target = {}, in_combat = true, enemy_count = 1, settings = {} }
assert_false(unholy.build_state(uctx).is_boss,
    "unholy is_boss must be false with no boss fields (was phantom-true before)")
uctx.target_is_boss = true
assert_true(unholy.build_state(uctx).is_boss,
    "unholy is_boss must be true via context.target_is_boss (real dispatcher field)")
uctx.target_is_boss = nil
boss_flag = true
assert_true(unholy.build_state(uctx).is_boss,
    "unholy is_boss must fall back to NS.unit_is_boss(target)")
boss_flag = false
assert_false(unholy.build_state(uctx).is_boss, "unholy is_boss must reset when no boss signal")
local garg = find_strategy(unholy.strategies, "SummonGargoyle")
assert_true(garg.matches({}, { is_boss = true, runic_power = 60 }),
    "unholy SummonGargoyle must match on a boss with 60+ RP")
assert_false(garg.matches({}, { is_boss = false, runic_power = 100 }),
    "unholy SummonGargoyle must NOT match on a non-boss")
print("PASS: unholy is_boss via context.target_is_boss + NS.unit_is_boss (Gargoyle fireable)")

-- ============================================================================
-- 9. unholy: rune snapshot — ONE get_rune_state() call within the 2s TTL,
--    refreshed after it (per-frame fan-out regression). Re-dofile for a
--    pristine module state: _rune_snapshot_time is module-local and section 8
--    already populated it at clock 100.
-- ============================================================================
spies.rune_state_calls = 0
clock = 100.0
unholy = dofile("EaxRotations/classes/deathknight/unholy_wotlk.lua")
local us1 = unholy.build_state(uctx)
assert_true(spies.rune_state_calls == 1, "unholy first build_state must snapshot runes once")
local us2 = unholy.build_state(uctx)
assert_true(spies.rune_state_calls == 1, "unholy build_state within 2s must reuse the TTL snapshot")
clock = 103.0
local us3 = unholy.build_state(uctx)
assert_true(spies.rune_state_calls == 2, "unholy build_state after 2s must refresh the snapshot")
assert_true(us1.rune_ready.blood == rune_bank.ready.blood and us3.rune_ready.blood == rune_bank.ready.blood,
    "unholy rune_ready must expose the snapshot's ready map")
print("PASS: unholy rune snapshot 2s-TTL (single get_rune_state per window)")

-- ============================================================================
-- 10. unholy: Presence execute casts the desired presence via NS.try_cast
--     (the old `if action and action.cast_safe` silently no-oped)
-- ============================================================================
desired_presence = "unholy"
local upres = find_strategy(unholy.strategies, "Presence")
assert_true(upres.matches({}, { presence = nil }),
    "unholy Presence must match when the manager desires a switch")
spies.try_cast_calls = {}
assert_true(upres.execute({ me = _G.EaxRotations.me }, {}) == true,
    "unholy Presence execute must return true")
assert_true(#spies.try_cast_calls == 1 and spies.try_cast_calls[1].spell.id == 48265,
    "unholy Presence must cast unholy 48265 via NS.try_cast, got "
    .. tostring(spies.try_cast_calls[1] and spies.try_cast_calls[1].spell.id))
desired_presence = nil
print("PASS: unholy Presence execute via NS.try_cast (48265)")

-- ============================================================================
-- 11. unholy: ghoul pet command lanes (GhoulGnaw interrupt / GhoulLeap gap
--     closer) fire on the REAL context fields and execute via NS.try_cast
-- ============================================================================
local gnaw = find_strategy(unholy.strategies, "GhoulGnaw")
local leap = find_strategy(unholy.strategies, "GhoulLeap")
assert_true(gnaw.matches({ target_casting = true }, { in_combat = true, pet_present = true }),
    "unholy GhoulGnaw must match on a casting target with a ghoul")
assert_false(gnaw.matches({ target_casting = false }, { in_combat = true, pet_present = true }),
    "unholy GhoulGnaw must NOT match when the target is not casting")
assert_false(gnaw.matches({ target_casting = true }, { in_combat = true, pet_present = false }),
    "unholy GhoulGnaw must NOT match without a ghoul")
assert_true(leap.matches({ target_distance = 15 }, { in_combat = true, pet_present = true }),
    "unholy GhoulLeap must match at target_distance 15 (gap close)")
assert_false(leap.matches({ target_distance = 5 }, { in_combat = true, pet_present = true }),
    "unholy GhoulLeap must NOT match in melee range")
spies.try_cast_calls = {}
assert_true(gnaw.execute({ target = {}, target_casting = true }, {}) == true,
    "unholy GhoulGnaw execute must return true (real DSL cast handler)")
assert_true(#spies.try_cast_calls == 1 and spies.try_cast_calls[1].spell.id == 47481,
    "unholy GhoulGnaw must cast 47481 via NS.try_cast")
spies.try_cast_calls = {}
assert_true(leap.execute({ target = {}, target_distance = 15 }, {}) == true
    and spies.try_cast_calls[1].spell.id == 47482,
    "unholy GhoulLeap must cast 47482 via NS.try_cast")
print("PASS: unholy GhoulGnaw/GhoulLeap lanes fire + cast via NS.try_cast")

-- ============================================================================
-- 12. leveling: ERW readiness via NS.cooldown_remains; runic power via
--     RuneManager.get_runic_power (legacy me:get_runic_power read removed);
--     rank lists decontaminated; RuneStrike removed; ERW gate 300
-- ============================================================================
reset_spies()
-- Leveling loads with an EMPTY class table so spec_kit falls back to the
-- file-local rank lists — the decontamination assertion needs to see them.
local lvl_ns = make_ns()
lvl_ns.DeathKnightSpells = {}
local recorded_lists = {}
lvl_ns.spell_action = function(ids, label)
    recorded_lists[#recorded_lists + 1] = { ids = ids, label = label }
    return spell_action(ids, label)
end
-- The leveling unit has NO get_runic_power method (production clients only
-- expose get_power(6); RuneManager wraps it) — the fix removed the legacy
-- synthetic fallback read.
lvl_ns.me = { get_health_percentage = function() return 100 end }
_G.EaxRotations = lvl_ns
local lv = dofile("EaxRotations/classes/deathknight/leveling_wotlk.lua")
assert_true(lv and lv.build_state, "leveling_wotlk should load")

local function find_recorded(label)
    for _, r in ipairs(recorded_lists) do
        if r.label == label then return r.ids end
    end
    return nil
end
local icy_ids = find_recorded("IcyTouch")
local hb_ids = find_recorded("HowlingBlast")
assert_true(icy_ids ~= nil, "leveling IcyTouch rank list must reach NS.spell_action")
for _, bad in ipairs({ 49802, 49905, 49906 }) do
    for _, id in ipairs(icy_ids) do
        assert_false(id == bad, "leveling IcyTouch rank list must not contain contaminated id " .. bad)
    end
end
assert_true(icy_ids[1] == 49909, "leveling IcyTouch must keep the pinned WotLK max rank 49909 first")
for _, bad in ipairs({ 51209, 51210, 51211, 51212 }) do
    for _, id in ipairs(hb_ids or {}) do
        assert_false(id == bad, "leveling HowlingBlast rank list must not contain contaminated id " .. bad)
    end
end
assert_true(hb_ids ~= nil and hb_ids[1] == 51411,
    "leveling HowlingBlast must keep the pinned WotLK max rank 51411 first")
print("PASS: leveling rank lists decontaminated (IcyTouch/HowlingBlast)")

rp_value = 100
cooldown_bank[47568] = 0
local lctx = { me = lvl_ns.me, target = {}, in_combat = true, enemy_count = 1, settings = {} }
local lst = lv.build_state(lctx)
assert_true(lst.runic_power == 100,
    "leveling runic_power must come from RuneManager.get_runic_power (got " .. tostring(lst.runic_power) .. ")")
assert_true(lst.empower_rune_weapon_ready == true,
    "leveling ERW ready must be true via NS.cooldown_remains(47568)")
cooldown_bank[47568] = 90
assert_false(lv.build_state(lctx).empower_rune_weapon_ready,
    "leveling ERW ready must be false when 47568 is on cooldown")
spies.long_cd_args = {}
local lv_erw = find_strategy(lv.strategies, "EmpowerRuneWeapon")
assert_true(lv_erw.matches(lctx, { in_combat = true, empower_rune_weapon_ready = true }),
    "leveling EmpowerRuneWeapon must match when ready")
assert_true(spies.long_cd_args[#spies.long_cd_args] == 300,
    "leveling ERW long-CD gate must use 300 (5-min CD), got " .. tostring(spies.long_cd_args[#spies.long_cd_args]))
for _, s in ipairs(lv.strategies) do
    assert_false(s.name == "RuneStrike", "leveling RuneStrike must be REMOVED (reactive in 3.3.5)")
end
print("PASS: leveling RuneManager runic power + ERW readiness via NS.cooldown_remains + gate 300 + RuneStrike removed")

-- ============================================================================
-- 13. class table: DRW 90 / UA 60 / ERW 300 cooldown fields — the gate args
--     the specs use must agree with the authoritative class table
-- ============================================================================
local cls_ns = {
    is_wotlk = function() return true end,
    GetPlayer = function() return nil end,
    spell_action = function(opts) return opts end,
    rotation_registry = { set_class_config = function() end, register = function() end },
}
_G.EaxRotations = cls_ns
dofile("EaxRotations/classes/deathknight/class_sylvanas.lua")
local cls = cls_ns.DeathKnightSpells
assert_true(cls ~= nil, "class_sylvanas must expose DeathKnightSpells")
assert_true(cls.DancingRuneWeapon.cooldown == 90,
    "class table DancingRuneWeapon cooldown must be 90 (3.3.5), got " .. tostring(cls.DancingRuneWeapon.cooldown))
assert_true(cls.UnbreakableArmor.cooldown == 60,
    "class table UnbreakableArmor cooldown must be 60 (3.3.5), got " .. tostring(cls.UnbreakableArmor.cooldown))
assert_true(cls.EmpowerRuneWeapon.cooldown == 300,
    "class table EmpowerRuneWeapon cooldown must be 300 (5-min), got " .. tostring(cls.EmpowerRuneWeapon.cooldown))
print("PASS: class table cooldowns aligned with gate args (DRW 90 / UA 60 / ERW 300)")

print("PASS test_deathknight_wotlk_live_fixes")
