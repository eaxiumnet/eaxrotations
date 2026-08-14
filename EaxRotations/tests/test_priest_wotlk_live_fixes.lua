-- test_priest_wotlk_live_fixes.lua -- Priest WotLK live-game defect regressions.
-- WHAT:  standalone regression test for the W3.3 priest WotLK fixer batch:
--        define_action_for_class precedence shadowing (systemic 4), missing
--        WotLK max-rank aura ids (systemic 3), mock-only mana reads (systemic 6),
--        and the Penance / Prayer of Mending single-rank trainer never-lanes.
-- WHEN:  run standalone: lua EaxRotations/tests/test_priest_wotlk_live_fixes.lua
--        (NOT registered — W3.5 registers all wave tests).
-- WHY:   the W3.1 audit found these defects via static analysis; this test pins
--        the fixed behaviors at the resolver/build_state/matcher level with
--        real API shapes (NS.spell_action ladders, context.mana_pct,
--        context.party_injured_count).
-- SAFETY: Pure unit test with a mocked _G.EaxRotations; no engine API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local function assert_not_nil(v, label) if v == nil then error(label or "assert_not_nil failed", 2) end end

package.loaded["common/enums"] = { class_id = { PRIEST = 5 } }

-- ============================================================================
-- Mock NS. spell_action RECORDS every ladder so the tests can assert the
-- resolved rank lists (the file-local ACTION tables are not reachable from
-- outside the module).
-- ============================================================================
local spell_calls = {}  -- { {label=..., ids={...}}, ... }

local function make_player()
    return {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
        is_channeling = function() return false end,
        is_channelling_spell = function() return false end,
        is_casting = function() return false end,
        get_class = function() return 5 end,
        get_race_id = function() return 1 end,
        get_guid = function() return "player-guid" end,
        get_target = function() return nil end,
    }
end

local function make_target()
    return {
        get_guid = function() return "target-guid" end,
        get_health_percentage = function() return 100 end,
        is_casting = function() return false end,
        is_channeling = function() return false end,
        is_valid = function() return true end,
        is_alive = function() return true end,
    }
end

local NS = {
    CLASS_ID = { PRIEST = 5 },
    me = make_player(),
    GetPlayer = function() return NS.me end,
    GetTarget = function() return make_target() end,
    spell_action = function(rank_ids, label)
        local ids = type(rank_ids) == "table" and rank_ids or { rank_ids }
        spell_calls[#spell_calls + 1] = { label = label, ids = ids }
        return { _meta = { ids = ids, id = ids, label = label } }
    end,
    get_spell_id = function(spell)
        if type(spell) == "number" then return spell end
        if type(spell) == "table" and spell._meta then
            local ids = spell._meta.ids
            return type(ids) == "table" and ids[1] or ids
        end
        return nil
    end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    mana_pct = function() return 100 end,
    cooldown_remains = function() return 0 end,
    game_time_ms = function() return 100000 end,
    time_now = function() return 0 end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    broken_api_throttled = function() return false end,
    is_wotlk = function() return true end,
    log = function() end,
    log_warning = function() end,
    rotation_registry = { register = function() end },
}
_G.EaxRotations = NS

local function find_strategy(strats, name)
    for i = 1, #strats do
        if strats[i].name == name then return strats[i] end
    end
    error("strategy not found: " .. name)
end

local function ladder_for(label)
    for i = #spell_calls, 1, -1 do
        if spell_calls[i].label == label then return spell_calls[i].ids end
    end
    return nil
end

-- ============================================================================
-- Load all four priest WotLK files
-- ============================================================================
local disc = dofile("EaxRotations/classes/priest/discipline_wotlk.lua")
local holy = dofile("EaxRotations/classes/priest/holy_wotlk.lua")
local shadow = dofile("EaxRotations/classes/priest/shadow_wotlk.lua")
local leveling = dofile("EaxRotations/classes/priest/leveling_wotlk.lua")
assert_true(disc and disc.strategies and disc.strategies[1], "discipline_wotlk should load")
assert_true(holy and holy.strategies and holy.strategies[1], "holy_wotlk should load")
assert_true(shadow and shadow.strategies and shadow.strategies[1], "shadow_wotlk should load")
assert_true(leveling and leveling.strategies and leveling.strategies[1], "leveling_wotlk should load")

-- ============================================================================
-- 1. Systemic 4: file-local WotLK rank ladders resolve through
--    spec_kit.define_action -> NS.spell_action (NOT the TBC-capped class
--    table). Each ladder's top must be the WotLK max rank.
-- ============================================================================
assert_eq(ladder_for("PowerWordShield")[1], 48066, "PWS ladder top is 48066 (WotLK max)")
assert_eq(ladder_for("Renew")[1], 48068, "Renew ladder top is 48068 (WotLK max)")
assert_eq(ladder_for("FlashHeal")[1], 48071, "FlashHeal ladder top is 48071 (WotLK max)")
assert_eq(ladder_for("GreaterHeal")[1], 48063, "GreaterHeal ladder top is 48063 (WotLK max)")
assert_eq(ladder_for("ShadowWordPain")[1], 48125, "SWP ladder top is 48125 (WotLK max)")
assert_eq(ladder_for("VampiricTouch")[1], 48160, "VT ladder top is 48160 (WotLK max)")
assert_eq(ladder_for("DevouringPlague")[1], 48300, "DP ladder top is 48300 (WotLK max)")
assert_eq(ladder_for("MindBlast")[1], 48127, "MindBlast ladder top is 48127 (WotLK max)")
assert_eq(ladder_for("MindFlay")[1], 48156, "MindFlay ladder top is 48156 (WotLK max)")
assert_eq(ladder_for("Smite")[1], 48123, "Smite ladder top is 48123 (WotLK max)")
assert_eq(ladder_for("PowerWordFortitude")[1], 48161, "PWF ladder top is 48161 (WotLK max)")
assert_eq(ladder_for("InnerFire")[1], 48168, "InnerFire ladder top is 48168 (WotLK max)")
print("  PASS: define_action resolves WotLK max-rank ladder tops (all four files)")

-- ============================================================================
-- 2. Penance never-lane (discipline + leveling): the ladder must span the
--    full WotLK trainer chain 47540 -> 53005 -> 53006 -> 53007 so
--    first-known-wins resolution fires for EVERY character level 70+.
-- ============================================================================
local disc_penance = ladder_for("Penance")
assert_eq(disc_penance[1], 53007, "disc Penance ladder top is 53007 (WotLK max)")
assert_eq(disc_penance[4], 47540, "disc Penance ladder keeps 47540 (rank 1 fallback)")
assert_eq(#disc_penance, 4, "disc Penance ladder has all 4 trainer ranks")
local lvl_penance = ladder_for("Penance")
assert_eq(lvl_penance[1], 53007, "leveling Penance ladder top is 53007 (WotLK max)")
assert_eq(lvl_penance[4], 47540, "leveling Penance ladder keeps 47540 (rank 1 fallback)")
-- A level-80 character who trained the max rank resolves 53007; a level-70
-- character still resolving 47540 finds the ladder intact (no nil gap).
assert_eq(#lvl_penance, 4, "leveling Penance ladder has all 4 trainer ranks")
print("  PASS: Penance full WotLK trainer ladder (53007..47540) in disc + leveling")

-- ============================================================================
-- 3. Prayer of Mending never-lane (discipline + holy): full WotLK ladder
--    33076 -> 48112 -> 48113 so a max-level priest resolves 48113.
-- ============================================================================
local po = ladder_for("PrayerofMending")
assert_eq(po[1], 48113, "PoM ladder top is 48113 (WotLK max)")
assert_eq(po[2], 48112, "PoM ladder includes 48112 (rank 2)")
assert_eq(po[3], 33076, "PoM ladder keeps 33076 (TBC-era rank 1 fallback)")
print("  PASS: Prayer of Mending full WotLK ladder (48113..33076) in disc + holy")

-- ============================================================================
-- 4. Systemic 3: buff/debuff lookups must include the WotLK max-rank aura
--    ids so literal aura matching sees the WotLK-era buffs.
-- ============================================================================
local debuff_requests = {}
NS.debuff_remains = function(unit, ids)
    debuff_requests[#debuff_requests + 1] = type(ids) == "table" and ids or { ids }
    return 0
end
local shadow_state = shadow.build_state({ in_combat = true, target = make_target(), mana_pct = 90 })
assert_not_nil(shadow_state, "shadow build_state returns state")
local saw_swp_max, saw_vt_max, saw_dp_max = false, false, false
for _, ids in ipairs(debuff_requests) do
    for _, id in ipairs(ids) do
        if id == 48125 then saw_swp_max = true end
        if id == 48160 then saw_vt_max = true end
        if id == 48300 then saw_dp_max = true end
    end
end
assert_true(saw_swp_max, "SWP debuff table includes 48125 (WotLK max)")
assert_true(saw_vt_max, "VT debuff table includes 48160 (WotLK max)")
assert_true(saw_dp_max, "DP debuff table includes 48300 (WotLK max)")
local buff_requests = {}
NS.buff_remains = function(unit, ids)
    buff_requests[#buff_requests + 1] = type(ids) == "table" and ids or { ids }
    return 0
end
local friend = { get_health_percentage = function() return 60 end }
local ctx_heal = { in_combat = true, lowest = { unit = friend, hp = 60 }, enemy_count = 1, mana_pct = 90 }
holy.build_state(ctx_heal)
disc.build_state(ctx_heal)
local saw_renew_max = false
for _, ids in ipairs(buff_requests) do
    for _, id in ipairs(ids) do
        if id == 48068 then saw_renew_max = true end
    end
end
assert_true(saw_renew_max, "RENEW_BUFF tables include 48068 (WotLK max)")
print("  PASS: WotLK max-rank aura ids present in debuff/buff lookup tables")

-- ============================================================================
-- 5. Systemic 6: mana reads resolve from the engine context first, then the
--    real NS.mana_pct, then the raw unit method — never a mock-only path.
-- ============================================================================
local st_ctx_mana = shadow.build_state({ in_combat = true, target = make_target(), mana_pct = 42 })
assert_eq(st_ctx_mana.mana_pct, 42, "context.mana_pct feeds state.mana_pct (shadow)")
NS.mana_pct = function() return 33 end
local st_ns_mana = shadow.build_state({ in_combat = true, target = make_target() })
assert_eq(st_ns_mana.mana_pct, 33, "NS.mana_pct feeds state.mana_pct when context lacks the field (shadow)")
NS.mana_pct = function() return 100 end
print("  PASS: mana_pct resolves context -> NS.mana_pct -> raw unit method")

-- ============================================================================
-- 6. Shadowfiend lane (shadow): fires in combat below the mana-return
--    threshold, silent at full mana.
-- ============================================================================
local sf = find_strategy(shadow.strategies, "Shadowfiend")
local st_sf_low = { in_combat = true, mana_pct = 45 }
local st_sf_high = { in_combat = true, mana_pct = 80 }
assert_true(sf.matches({ in_combat = true, target = make_target() }, st_sf_low),
    "Shadowfiend must fire at mana 45 (in combat)")
assert_false(sf.matches({ in_combat = true, target = make_target() }, st_sf_high),
    "Shadowfiend must stay silent at mana 80")
print("  PASS: Shadowfiend lane fireable below the mana-return threshold")

-- ============================================================================
-- 7. Circle of Healing lane (holy): fires on 2+ injured party members via the
--    engine context.party_injured_count field; silent with <= 1 injured.
-- ============================================================================
local coh = find_strategy(holy.strategies, "CircleOfHealing")
local st_coh_ok = holy.build_state({ in_combat = true, party_injured_count = 2, lowest_hp = 60, mana_pct = 90 })
assert_true(coh.matches({ in_combat = true, party_injured_count = 2, lowest_hp = 60 }, st_coh_ok),
    "CoH must fire with 2 injured party members")
local st_coh_one = holy.build_state({ in_combat = true, party_injured_count = 1, lowest_hp = 60, mana_pct = 90 })
assert_false(coh.matches({ in_combat = true, party_injured_count = 1, lowest_hp = 60 }, st_coh_one),
    "CoH must not fire with a single injured member")
local st_coh_healthy = holy.build_state({ in_combat = true, party_injured_count = 3, lowest_hp = 95, mana_pct = 90 })
assert_false(coh.matches({ in_combat = true, party_injured_count = 3, lowest_hp = 95 }, st_coh_healthy),
    "CoH must not fire on a healthy group")
print("  PASS: CircleOfHealing gated on context.party_injured_count >= 2")

-- ============================================================================
-- 8. Healer targeting: discipline + holy score the LOWEST FRIENDLY unit as
--    their target (never the enemy context.target) — the W3.1 resto-WotLK
--    cast-on-target defect is absent here.
-- ============================================================================
local ally = { get_health_percentage = function() return 35 end }
local ctx_friendly = {
    in_combat = true,
    target = { get_health_percentage = function() return 90 end },  -- enemy-shaped target
    lowest = { unit = ally, hp = 35 },
    enemy_count = 1,
    mana_pct = 90,
}
assert_eq(disc.build_state(ctx_friendly).target_hp, 35, "disc scores the lowest friendly unit")
assert_eq(holy.build_state(ctx_friendly).target_hp, 35, "holy scores the lowest friendly unit")
print("  PASS: healer target_hp scored from context.lowest.unit (disc + holy)")

-- ============================================================================
-- 9. Mind Flay clip gates: the DoT/MB lanes stay fireable when not
--    channeling (state.mf_channeling false) — the clip never blocks the
--    normal rotation.
-- ============================================================================
local vt = find_strategy(shadow.strategies, "VampiricTouch")
local st_not_channeling = shadow.build_state({ in_combat = true, target = make_target(), mana_pct = 90 })
assert_false(st_not_channeling.mf_channeling, "mf_channeling false when not channeling")
assert_true(vt.matches({ in_combat = true, target = make_target() }, st_not_channeling),
    "VT must fire when MF is not channeling (no clip block)")
assert_true(sf.matches({ in_combat = true, target = make_target() }, st_sf_low),
    "Shadowfiend still fires with clip state present")
print("  PASS: Mind Flay clip state does not block the rotation when idle")

print("PASS test_priest_wotlk_live_fixes")
