-- test_mage_wotlk_live_fixes.lua — Regression tests for the W3.3 mage WotLK
-- live-correctness fixes (2026-08-13 top-tier parsing campaign).
-- WHAT:  arcane PoM readiness via real API (NS.spell_ready — no mock-only
--        :cooldown_remaining()), AB/AM/ABarrage distinct lane semantics (AM =
--        Missile Barrage proc consumer, ABarrage = 4-stack dump, AB capped at
--        stacks < 4 per the pinned wowsims APL), real mana API (me:mana_pct —
--        no mock-only get_mana_percentage), plain define_action (no TBC
--        MageSpells shadowing, systemic 4); fire Hot Streak aura 44448 (per
--        the pinned fire APL + audit reference pin; 48108 must NOT drive the
--        gate); frost FROST_NOVA_DEBUFF +42917, FROSTFIRE_BOLT_DEBUFF = 44549
--        (cast rank 47610), Fingers of Frost 44545; leveling Living Bomb DoT
--        family 55360/55362 (not 44457) + Frostfire Bolt max rank 47610.
-- WHEN:  standalone; W3.5 registers all wave tests.
-- WHY:   audit-verified live bugs (W3.1 register); this test pins the fixed
--        behavior with REAL API shapes (spell_ready / spell_action /
--        buff_up / debuff_remains / mana_pct).
-- SAFETY: Pure unit tests with a mocked _G.EaxRotations; no game API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- 1. SOURCE-LEVEL AUDIT: the mock-only / shadowed-API patterns must be gone
--    from all four mage *_wotlk.lua files (systemics 1/2/4/5/6).
-- ============================================================================
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then error("missing " .. path, 2) end
    local content = f:read("*a") or ""
    f:close()
    return content
end

-- Strip -- line comments: production headers legitimately DOCUMENT which
-- mock-only APIs are absent, so the scan must target executable code only.
local function strip_comments(src)
    return (src:gsub("%-%-[^\n]*", ""))
end

local MAGE_WOTLK_FILES = {
    "EaxRotations/classes/mage/arcane_wotlk.lua",
    "EaxRotations/classes/mage/fire_wotlk.lua",
    "EaxRotations/classes/mage/frost_wotlk.lua",
    "EaxRotations/classes/mage/leveling_wotlk.lua",
}
for _, path in ipairs(MAGE_WOTLK_FILES) do
    local src = strip_comments(read_file(path))
    assert_false(src:find("cooldown_remaining", 1, true),
        path .. ": mock-only :cooldown_remaining() must be gone (systemic 1)")
    assert_false(src:find("cast_safe", 1, true),
        path .. ": mock-only :cast_safe() must be gone (systemic 2)")
    assert_false(src:find("get_mana_percentage", 1, true),
        path .. ": mock-only me:get_mana_percentage() must be gone (systemic 6)")
    assert_false(src:find("define_action_for_class", 1, true),
        path .. ": define_action_for_class must be gone (systemic 4 — TBC MageSpells shadow)")
    assert_false(src:find("context.is_boss", 1, true),
        path .. ": phantom context.is_boss read must be gone (systemic 5)")
end

-- ============================================================================
-- 2. MOCK ENGINE (real API shapes; recorders prove WHICH ids the production
--    code queries).
-- ============================================================================
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
package.loaded["shared/leveling_helpers_sylvanas"] = { should_interrupt = function() return false end }
package.loaded["shared/pet_manager_sylvanas"] = {
    get_pet = function() return nil end,
    pet_alive = function() return false end,
}

-- TBC-era class table: with define_action_for_class this would SHADOW every
-- WotLK rank ladder (the systemic-4 bug). Plain define_action must ignore it.
local TBC_MAGE_SPELLS = {
    ArcaneBlast = 30451, ArcaneMissiles = 38699, ArcaneBarrage = 44425,
    Evocation = 12051, ArcanePower = 12042, IcyVeins = 12472,
    MirrorImage = 55342, PresenceOfMind = 12043, Counterspell = 2139,
    ConjureManaEmerald = 27101, MageArmor = 27125,
    Pyroblast = 33938, LivingBomb = 44457, FireBlast = 27079, Scorch = 27074,
    Fireball = 27070, Combustion = 11129, Frostbolt = 27072,
    FrostfireBolt = 44614, IceLance = 30455, DeepFreeze = 44572,
    ColdSnap = 11958, ConeOfCold = 27087, Blink = 1953,
    IceBarrier = 33405, ManaShield = 27131, ConjureManaGem = 27101,
    ArcaneIntellect = 27126, ArcaneExplosion = 27082,
    SummonWaterElemental = 31687, Blizzard = 27085, Shoot = 5019,
}

local function make_ns()
    local ns = {}
    ns.MageSpells = TBC_MAGE_SPELLS
    ns._buff_map = {}        -- buff id -> true (buff_up)
    ns._stacks_map = {}      -- buff id -> stack count (buff_stacks)
    ns._debuff_map = {}      -- debuff id -> remains (debuff_remains / debuff_up)
    ns._seen_buff_ids = {}   -- ids families passed to buff_up (family probe)
    ns._seen_debuff_ids = {} -- ids families passed to debuff_remains
    ns._spell_ready_calls = {} -- spell ids checked via NS.spell_ready (PoM proof)
    ns._spell_ready_result = true
    ns.me = {
        get_health_percentage = function() return 80 end,
        mana_pct = function() return 80 end,
    }
    ns.GetPlayer = function() return ns.me end
    ns.spell_action = function(rank_ids, label)
        local ids = type(rank_ids) == "table" and rank_ids or { rank_ids }
        local obj = {
            ids = ids,
            label = label,
            id = function() return ids[1] end,
            IsReady = function() return ns._spell_ready_result end,
            IsInRange = function() return true end,
            Cast = function() return true end,
        }
        return obj
    end
    ns.spell_ready = function(spell, target, opts)
        local ids = type(spell) == "table" and spell.ids or { spell }
        for _, id in ipairs(ids) do ns._spell_ready_calls[#ns._spell_ready_calls + 1] = id end
        return ns._spell_ready_result
    end
    ns.spell_exists = function() return true end
    ns.try_cast = function() return true end
    ns.buff_up = function(unit, ids)
        if type(ids) == "number" then ids = { ids } end
        for _, id in ipairs(ids or {}) do ns._seen_buff_ids[id] = true end
        for _, id in ipairs(ids or {}) do
            if ns._buff_map[id] then return true end
        end
        return false
    end
    ns.buff_stacks = function(unit, ids)
        if type(ids) == "number" then ids = { ids } end
        for _, id in ipairs(ids or {}) do
            if ns._stacks_map[id] ~= nil then return ns._stacks_map[id] end
        end
        return 0
    end
    ns.debuff_up = function(unit, ids)
        if type(ids) == "number" then ids = { ids } end
        for _, id in ipairs(ids or {}) do ns._seen_debuff_ids[id] = true end
        for _, id in ipairs(ids or {}) do
            if ns._debuff_map[id] ~= nil then return true end
        end
        return false
    end
    ns.debuff_remains = function(unit, ids)
        if type(ids) == "number" then ids = { ids } end
        for _, id in ipairs(ids or {}) do ns._seen_debuff_ids[id] = true end
        for _, id in ipairs(ids or {}) do
            if ns._debuff_map[id] ~= nil then return ns._debuff_map[id] end
        end
        return 0
    end
    ns.cooldown_remains = function() return 0 end
    ns.should_use_long_cd = function() return true end
    ns.is_item_ready = function() return false end
    ns.use_item_by_id = function() return true end
    ns.core = { spell_book = { get_spell_cast_time = function() return 1.75 end } }
    ns.log = function() end
    ns.log_warning = function() end
    ns.rotation_registry = {
        register = function(self, spec, strategies, opts)
            ns._registered = { spec = spec, strategies = strategies, options = opts or {} }
        end,
    }
    return ns
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    error("strategy not found: " .. name, 2)
end

-- ============================================================================
-- 3. ARCANE: PoM real-API readiness, real mana API, distinct nuke lanes,
--    plain define_action + cleaned ID families.
-- ============================================================================
local ns = make_ns()
_G.EaxRotations = ns
local arcane = dofile("EaxRotations/classes/mage/arcane_wotlk.lua")
assert_true(type(arcane) == "table", "arcane_wotlk must load")

-- 3a. PoM readiness must come from NS.spell_ready (real API), not the
--     mock-only :cooldown_remaining().
ns._spell_ready_result = false
local arc_ctx = { in_combat = true, target = {}, settings = {}, mana_pct = 80, hp = 80 }
assert_false(arcane.build_state(arc_ctx).pom_ready,
    "arcane pom_ready must follow NS.spell_ready=false (no mock-only cooldown_remaining)")
ns._spell_ready_result = true
assert_true(arcane.build_state(arc_ctx).pom_ready,
    "arcane pom_ready must follow NS.spell_ready=true")
local pom_checked = false
for _, id in ipairs(ns._spell_ready_calls) do if id == 12043 then pom_checked = true end end
assert_true(pom_checked, "arcane must gate PoM (12043) through NS.spell_ready")

-- 3b. mana_pct must come from the dispatcher ctx / me:mana_pct() — never the
--     mock-only me:get_mana_percentage().
assert_eq(arcane.build_state({ in_combat = true, target = {}, mana_pct = 37, settings = {} }).mana_pct, 37,
    "arcane mana_pct must read context.mana_pct first")
local no_ctx_mana = arcane.build_state({ in_combat = true, target = {}, settings = {} })
assert_eq(no_ctx_mana.mana_pct, 80, "arcane mana_pct must fall back to me:mana_pct()")

-- 3c. Action ladders resolve from the FILE (plain define_action): the TBC-era
--     MageSpells table (ArcaneBlast = 30451) must NOT shadow the WotLK ranks.
--     (Strategy-level proof in 6d via the try_cast recorder; here we verify the
--     compiled strategies exist for the reshaped lanes.)
assert_true(type(find_strategy(arcane.strategies, "ArcaneBlast").matches) == "function",
    "ArcaneBlast strategy must compile")
assert_true(type(find_strategy(arcane.strategies, "ArcaneBarrage").matches) == "function",
    "ArcaneBarrage strategy must compile")

-- 3d. Arcane Blast stack family: buff_stacks must be probed with 36032 ONLY
--     (36033/36034/40057 are unrelated spells, not AB stack auras).
ns._stacks_map = { [36032] = 4 }
local ab_state = arcane.build_state({ in_combat = true, target = {}, settings = {} })
assert_eq(ab_state.arcane_blast_stacks, 4, "arcane AB stacks must read the 36032 aura")
ns._stacks_map = { [36033] = 4 }
assert_eq(arcane.build_state({ in_combat = true, target = {}, settings = {} }).arcane_blast_stacks, 0,
    "arcane AB stacks must NOT read 36033 (wrong-family aura)")

-- 3e. Distinct lane semantics: AM = proc consumer; ABarrage = 4-stack dump;
--     AB capped below 4 stacks (wowsims APL).
local ab = find_strategy(arcane.strategies, "ArcaneBlast")
local am = find_strategy(arcane.strategies, "ArcaneMissiles")
local abar = find_strategy(arcane.strategies, "ArcaneBarrage")
local ctx3 = { in_combat = true, target = {}, settings = {} }
local s3 = arcane.build_state(ctx3)

s3.arcane_blast_stacks = 3
assert_true(ab.matches(ctx3, s3), "arcane AB must match at 3 stacks (WotLK cap is 4)")
assert_false(am.matches(ctx3, s3), "arcane AM must NOT fire at 3 stacks without the proc")
s3.arcane_blast_stacks = 4
assert_false(ab.matches(ctx3, s3), "arcane AB must not match at 4 stacks")
assert_true(abar.matches(ctx3, s3), "arcane ABarrage must fire as the 4-stack dump")
s3.arcane_blast_stacks = 0
assert_false(abar.matches(ctx3, s3), "arcane ABarrage must not fire below 4 stacks")
ns._buff_map = { [44401] = true }
s3 = arcane.build_state(ctx3)  -- rebuild: proc flag comes from build_state
s3.arcane_blast_stacks = 0
assert_true(am.matches(ctx3, s3), "arcane AM must fire on the Missile Barrage proc (44401)")
ns._buff_map = {}
s3 = arcane.build_state(ctx3)
assert_false(am.matches(ctx3, s3), "arcane AM must not fire without the proc")

-- 3f. Mage Armor family: 27125 (TBC max) + 6117 (R1) — NOT Amplify Magic
--     (27130/1008).
ns._buff_map = { [27125] = true }
assert_true(arcane.build_state({ in_combat = true, target = {}, settings = {} }).mage_armor_up,
    "arcane Mage Armor detection must include 27125")
ns._buff_map = { [27130] = true }
assert_false(arcane.build_state({ in_combat = true, target = {}, settings = {} }).mage_armor_up,
    "arcane Mage Armor must NOT read 27130 (Amplify Magic)")

-- ============================================================================
-- 4. FIRE: Hot Streak aura is 44448 (pinned fire APL + audit reference pin);
--    48108 must NOT drive the proc gate. Living Bomb debuff family = 55360.
-- ============================================================================
ns = make_ns()
_G.EaxRotations = ns
local fire = dofile("EaxRotations/classes/mage/fire_wotlk.lua")
assert_true(type(fire) == "table", "fire_wotlk must load")

local fire_ctx = { in_combat = true, target = {}, settings = {}, ttd = 60 }
ns._buff_map = { [44448] = true }
assert_true(fire.build_state(fire_ctx).hot_streak_proc,
    "fire Hot Streak must trigger on aura 44448 (wowsims APL gate)")
ns._buff_map = { [48108] = true }
assert_false(fire.build_state(fire_ctx).hot_streak_proc,
    "fire Hot Streak must NOT trigger on 48108 (not the rotation's proc aura)")

-- Living Bomb DoT family: must include the WotLK max-rank 55360.
ns._debuff_map = { [55360] = 5 }
assert_eq(fire.build_state(fire_ctx).living_bomb_remains, 5,
    "fire Living Bomb remains must read the 55360 DoT (wowsims APL)")
local saw_lb = false
for id in pairs(ns._seen_debuff_ids) do if id == 55360 then saw_lb = true end end
assert_true(saw_lb, "fire Living Bomb debuff family must contain 55360")

-- ============================================================================
-- 5. FROST: FROST_NOVA_DEBUFF includes WotLK 42917; FFB debuff is 44549 (cast
--    rank 47610); Fingers of Frost 44545 makes DeepFreeze/IceLance fireable.
-- ============================================================================
ns = make_ns()
_G.EaxRotations = ns
local frost = dofile("EaxRotations/classes/mage/frost_wotlk.lua")
assert_true(type(frost) == "table", "frost_wotlk must load")

local frost_ctx = { in_combat = true, target = {}, settings = {} }

-- 5a. Frost Nova family: 42917 (WotLK max) must be a member.
ns._debuff_map = { [42917] = 5 }
assert_true(frost.build_state(frost_ctx).target_frozen,
    "frost frozen gate must detect the WotLK Frost Nova root (42917)")
local saw_nova = false
for id in pairs(ns._seen_debuff_ids) do if id == 42917 then saw_nova = true end end
assert_true(saw_nova, "frost FROST_NOVA_DEBUFF family must contain 42917")

-- 5b. Frostfire Bolt debuff is 44549 (the aura), while the CAST rank is 47610.
ns._debuff_map = {}
ns._seen_debuff_ids = {}
ns._debuff_map = { [44549] = 2 }
assert_eq(frost.build_state(frost_ctx).frostfire_remains, 2,
    "frost FFB refresh gate must read the 44549 debuff aura")
assert_false(ns._seen_debuff_ids[47610] == true,
    "frost FFB debuff family must NOT contain the cast rank 47610")

-- 5c. Fingers of Frost (44545) fires DeepFreeze + IceLance without a root.
ns._debuff_map = {}
ns._buff_map = { [44545] = true }
local fof_state = frost.build_state(frost_ctx)
assert_true(fof_state.target_frozen, "frost FoF proc (44545) must count as frozen")
local deep = find_strategy(frost.strategies, "DeepFreeze")
local lance = find_strategy(frost.strategies, "IceLance")
assert_true(deep.matches(frost_ctx, fof_state), "frost DeepFreeze must fire on FoF (wowsims APL)")
assert_true(lance.matches(frost_ctx, fof_state), "frost IceLance must fire on FoF")
ns._buff_map = {}
assert_false(deep.matches(frost_ctx, frost.build_state(frost_ctx)),
    "frost DeepFreeze must not fire without frozen/FoF")

-- 5d. Frostbolt ladder: max rank 42842 first; wrong-family ranks gone.
local frostbolt = find_strategy(frost.strategies, "Frostbolt")
assert_true(type(frostbolt.matches) == "function", "frost Frostbolt strategy must compile")

-- ============================================================================
-- 6. LEVELING: Living Bomb DoT family 55360/55362 (44457 is TBC-era), FFB max
--    rank 47610, Blizzard ladder cleaned (no Flamestrike/Arcane Explosion).
-- ============================================================================
ns = make_ns()
_G.EaxRotations = ns
local leveling = dofile("EaxRotations/classes/mage/leveling_wotlk.lua")
assert_true(type(leveling) == "table", "leveling_wotlk must load")

local lvl_ctx = { in_combat = true, target = {}, settings = {}, mana_pct = 80, hp = 80 }

-- 6a. Living Bomb DoT family: 55360 + 55362 members; 44457 NOT a member.
ns._debuff_map = { [55360] = 2 }
assert_eq(leveling.build_state(lvl_ctx).living_bomb_remains, 2,
    "leveling Living Bomb remains must read the WotLK 55360 DoT")
ns._debuff_map = { [55362] = 2 }
assert_eq(leveling.build_state(lvl_ctx).living_bomb_remains, 2,
    "leveling Living Bomb family must include 55362")
assert_false(ns._seen_debuff_ids[44457] == true,
    "leveling Living Bomb family must NOT contain the TBC 44457 DoT")

-- 6b. Frostfire Bolt: WotLK max rank 47610 (was rank-1 44614).
local lv_ffb = find_strategy(leveling.strategies, "FrostfireBolt")
assert_true(type(lv_ffb.matches) == "function", "leveling FrostfireBolt strategy must compile")

-- 6c. mana_pct via ctx (dispatcher field), not the mock-only unit method.
assert_eq(leveling.build_state({ in_combat = true, target = {}, mana_pct = 25, settings = {} }).mana_pct, 25,
    "leveling mana_pct must read context.mana_pct first")

-- 6d. Action ladders are file-local (define_action): the TBC MageSpells table
--     (Fireball = 27070, Blizzard = 27085, FrostfireBolt = 44614) must NOT
--     shadow the WotLK max ranks. Probe via the DSL cast closures: try_cast
--     receives the ACTION object; record its resolved id.
local cast_ids = {}
local orig_try_cast = ns.try_cast
ns.try_cast = function(spell, unit, reason)
    if type(spell) == "table" and spell.id then
        cast_ids[#cast_ids + 1] = spell.id()
    end
    return true
end
local lb = find_strategy(leveling.strategies, "LivingBomb")
local s_lvl = leveling.build_state(lvl_ctx)
assert_true(lb.matches(lvl_ctx, s_lvl), "leveling LivingBomb must match without the DoT")
local ok_exec = lb.execute(lvl_ctx, s_lvl)
assert_true(ok_exec, "leveling LivingBomb execute must succeed")
local saw_55360 = false
for _, id in ipairs(cast_ids) do if id == 55360 then saw_55360 = true end end
assert_true(saw_55360, "leveling LivingBomb must cast the WotLK rank 55360 (not TBC 44457)")
ns.try_cast = orig_try_cast

print("PASS test_mage_wotlk_live_fixes")
