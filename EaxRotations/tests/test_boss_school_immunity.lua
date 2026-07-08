-- test_boss_school_immunity.lua — Audit item #4a: boss school-immunity DB + wiring.
-- WHAT:  verifies NS.get_target_school_immunities resolves NPC IDs, and that the
--        DBC-verified boss immunities (Curator=arcane, Al'ar=fire) return correctly.
-- WHEN:  run standalone or via run_rotation_tests.lua.
-- WHY:   get_target_school_immunities was dead code; now wired into evaluate_cast.
-- SAFETY: mocks the unit object (get_npc_id) so no live game state needed.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Build a minimal NS that exposes get_target_school_immunities.
-- This replicates the function logic from main_sylvanas.lua (since it reads the
-- BOSS_SCHOOL_IMMUNITIES local table). We test the data + resolution logic.
-- ============================================================================

-- DBC-verified SchoolImmuneMask data + phase-judgment entries (mirrors main_sylvanas.lua)
local BOSS_SCHOOL_IMMUNITIES = {
    [15691] = { arcane = true },  -- The Curator (Karazhan) — Mask=64 arcane
    [21216] = { nature = true },  -- Hydross (SSC) — phase judgment
    [19516] = { arcane = true },  -- Void Reaver (TK) — spell-reflect judgment
    [19514] = { fire = true },    -- Al'ar (TK) — Mask=4 fire (was mislabeled "not fire immune")
    [17767] = { frost = true },   -- Rage Winterchill (Hyjal) — undead-type judgment
}

local function get_target_school_immunities(target)
    if not target then return {} end
    local id = nil
    if type(target.get_npc_id) == "function" then id = target:get_npc_id() end
    if type(id) ~= "number" then id = target.id or target.entry or nil end
    if type(id) == "number" then return BOSS_SCHOOL_IMMUNITIES[id] or {} end
    return {}
end


-- ============================================================================
-- S1: The Curator (15691) → arcane immunity resolved
-- ============================================================================

print("--- S1: Curator (15691) resolves to arcane immunity ---")

local curator = { get_npc_id = function() return 15691 end }
local imm1 = get_target_school_immunities(curator)
assert_true(imm1.arcane == true, "S1: Curator should be arcane-immune")
assert_eq(imm1.fire, nil, "S1: Curator should NOT be fire-immune")
print("PASS S1: Curator arcane immunity")

-- ============================================================================
-- S2: Al'ar (19514) → fire immunity resolved (DBC-verified fix)
-- ============================================================================

print("--- S2: Al'ar (19514) resolves to fire immunity ---")

local alar = { get_npc_id = function() return 19514 end }
local imm2 = get_target_school_immunities(alar)
assert_true(imm2.fire == true, "S2: Al'ar should be fire-immune (DBC Mask=4)")
assert_eq(imm2.arcane, nil, "S2: Al'ar should NOT be arcane-immune")
print("PASS S2: Al'ar fire immunity (DBC fix)")

-- ============================================================================
-- S3: Non-boss NPC (12345) → empty immunities (no false positives)
-- ============================================================================

print("--- S3: Generic NPC returns empty immunity table ---")

local trash = { get_npc_id = function() return 12345 end }
local imm3 = get_target_school_immunities(trash)
assert_eq(next(imm3), nil, "S3: Non-boss should have no immunities")
print("PASS S3: No false-positive immunities")

-- ============================================================================
-- S4: nil target → safe empty table (no crash)
-- ============================================================================

print("--- S4: nil target returns empty table safely ---")

local ok4, imm4 = pcall(get_target_school_immunities, nil)
assert_true(ok4, "S4: get_target_school_immunities(nil) should not crash")
assert_eq(next(imm4), nil, "S4: nil target → empty immunities")
print("PASS S4: nil target safe")

-- ============================================================================
-- S5: target without get_npc_id → falls back to .id field
-- ============================================================================

print("--- S5: fallback to .id field when get_npc_id missing ---")

local hydross = { id = 21216 }
local imm5 = get_target_school_immunities(hydross)
assert_true(imm5.nature == true, "S5: Hydross via .id should be nature-immune")
print("PASS S5: .id fallback works")

-- ============================================================================
-- S6: NS.MovementAssist is registered as a table (audit item #2 wiring)
-- ============================================================================

print("--- S6: movement_assist registers NS.MovementAssist as a table ---")

-- Load the real module to verify it self-registers on the NS namespace.
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path
_G.EaxRotations = _G.EaxRotations or {}
local ma_ok, ma = pcall(require, "shared/movement_assist_sylvanas")
assert_true(ma_ok, "S6: movement_assist_sylvanas should load without error")
assert_true(type(ma) == "table", "S6: module should return a table")
assert_true(type(ma.face_for_spell) == "function", "S6: face_for_spell should be a function")
assert_true(type(ma.get_cast_time) == "function", "S6: get_cast_time should be a function")
-- The module must self-register on NS.MovementAssist (the audit fix).
assert_true(type(_G.EaxRotations.MovementAssist) == "table", "S6: NS.MovementAssist must be a table (registered)")
assert_true(_G.EaxRotations.MovementAssist == ma, "S6: NS.MovementAssist must be the same table the module returns")
print("PASS S6: NS.MovementAssist registered as table")

-- ============================================================================
-- S7: face_for_spell is a safe no-op when movement_handler unavailable
-- ============================================================================

print("--- S7: face_for_spell is a no-op without movement_handler ---")

local mock_target = { get_npc_id = function() return 1 end }
local ok7, r7 = pcall(ma.face_for_spell, ma, 5143, mock_target) -- 5143 = Arcane Missiles
assert_true(ok7, "S7: face_for_spell should not crash without movement_handler")
-- Returns false (no assist activated) since _movement_handler is nil in test env.
assert_eq(r7, false, "S7: face_for_spell should return false when assist unavailable")
print("PASS S7: no-op when movement_handler missing")

-- ============================================================================
-- All scenarios pass
-- ============================================================================

print("PASS test_boss_school_immunity (all 7 scenarios)")
