-- test_ranked_buff_no_downgrade.lua — Contract: never cast a worse self-buff rank/family.
-- WHAT:  unit matrix for buff_would_downgrade + static OOC ladder ordering.
-- WHEN:  rotation test suite.
-- WHY:  MotW/GotW, AI/AB, Fort/PoF loops must not regress.
-- SAFETY: pure unit tests; no game API.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

local function assert_true(v, msg)
    if not v then error(msg or "assert_true failed", 2) end
end
local function assert_false(v, msg)
    if v then error(msg or "assert_false failed", 2) end
end

-- Mirror of NS.buff_would_downgrade (best-first ladder, active_pos < cast_pos).
local function would_downgrade(active_pos, cast_pos)
    if not active_pos then return false end
    if not cast_pos then return true end
    return active_pos < cast_pos
end

local function pos_of(list, id)
    for i = 1, #list do
        if list[i] == id then return i end
    end
    return nil
end

-- ================================================================
-- 1. Family ladders (best-first)
-- ================================================================

-- Super-set ladders (must match ranked_buff_families_sylvanas.lua detect order).
local MOTW = { 48470, 26991, 21850, 21849, 48469, 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }
local AI = { 43002, 27127, 23028, 42995, 27126, 10157, 10156, 1461, 1460, 1459 }
local FORT = { 48162, 25392, 21564, 21562, 39231, 48161, 25389, 10938, 10937, 2791, 1245, 1244, 1243 }
local THORNS = { 53307, 26992, 9910, 9756, 8914, 1075, 782, 467 }
local WARLOCK_ARMOR = { 47893, 28189, 28176, 47889, 27260, 11735, 11734, 11733, 1086, 706, 687, 696 }
local SHAMAN_SHIELD = { 57960, 33736, 24398, 23575, 49280, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }

local function assert_superior_blocks(family, superior_id, inferior_cast_id, label)
    local a = pos_of(family, superior_id)
    local c = pos_of(family, inferior_cast_id)
    assert_true(a ~= nil, label .. ": superior id missing from family")
    assert_true(c ~= nil, label .. ": cast id missing from family")
    assert_true(a < c, label .. ": superior must be ordered before cast rank")
    assert_true(would_downgrade(a, c), label .. ": must treat inferior cast as downgrade")
end

assert_superior_blocks(MOTW, 26991, 5232, "GotW vs low MotW")
assert_superior_blocks(MOTW, 9885, 5232, "high MotW vs low MotW")
assert_superior_blocks(AI, 27127, 1459, "AB vs low AI")
assert_superior_blocks(AI, 23028, 27126, "AB r1 vs AI max")
assert_superior_blocks(FORT, 25392, 1243, "PoF vs low Fort")
assert_superior_blocks(FORT, 21564, 25389, "PoF r2 vs PW:F max")
assert_superior_blocks(THORNS, 26992, 467, "high Thorns vs low")
assert_superior_blocks(WARLOCK_ARMOR, 28189, 687, "Fel vs Demon low")
assert_superior_blocks(SHAMAN_SHIELD, 33736, 324, "Water Shield vs LS r1")
print("PASS ranked_buff_family_order")

-- Upgrade allowed (inferior active, superior cast)
assert_false(would_downgrade(pos_of(MOTW, 5232), pos_of(MOTW, 9885)), "MotW upgrade allowed")
assert_false(would_downgrade(pos_of(AI, 1459), pos_of(AI, 27126)), "AI upgrade allowed")
assert_false(would_downgrade(nil, pos_of(FORT, 25389)), "no buff is not downgrade")
assert_false(would_downgrade(pos_of(AI, 27126), pos_of(AI, 27126)), "same rank not downgrade")
print("PASS ranked_buff_upgrade_and_same")

-- ================================================================
-- 2. Static: OOC manager source ladders are best-first
-- ================================================================

local function read(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

local rbf = read("EaxRotations/shared/ranked_buff_families_sylvanas.lua")
assert_true(rbf:find("43002", 1, true) and rbf:find("AI_DETECT", 1, true),
    "SoT AI detect must include WotLK AB 43002")
assert_true(rbf:find("48162", 1, true) and rbf:find("FORT_DETECT", 1, true),
    "SoT Fort detect must include WotLK PoF 48162")
assert_true(rbf:find("48470", 1, true) and rbf:find("MOTW_DETECT", 1, true),
    "SoT MotW detect must include WotLK GotW 48470")
assert_true(rbf:find("48469", 1, true) and rbf:find("MOTW_CAST", 1, true),
    "SoT MotW cast must include WotLK 48469")

local ooc = read("EaxRotations/shared/ooc_manager_sylvanas.lua")
assert_true(ooc:find("ranked_buff_families_sylvanas", 1, true),
    "OOC manager must require ranked_buff_families SoT")
assert_true(ooc:find("buff_would_downgrade", 1, true),
    "OOC try_self_buffs must call buff_would_downgrade")
print("PASS ranked_buff_ooc_static")

-- ================================================================
-- 3. Static: middleware self-buffs call buff_would_downgrade
-- ================================================================

local middlewares = {
    { path = "EaxRotations/classes/warrior/middleware_sylvanas.lua", needle = "SelfBuff", must = "buff_would_downgrade" },
    { path = "EaxRotations/classes/mage/middleware_sylvanas.lua", needle = "ARCANE_INTELLECT_BUFFS", must = "buff_would_downgrade" },
    { path = "EaxRotations/classes/priest/middleware_sylvanas.lua", needle = "PowerWordFortitude", must = "buff_would_downgrade" },
    { path = "EaxRotations/classes/shaman/middleware_sylvanas.lua", needle = "LightningShield", must = "buff_would_downgrade" },
    { path = "EaxRotations/classes/warlock/middleware_sylvanas.lua", needle = "Warlock_DemonArmor", must = "buff_would_downgrade" },
    { path = "EaxRotations/classes/druid/middleware_sylvanas.lua", needle = "MarkOfTheWild", must = "buff_would_downgrade" },
}

for _, m in ipairs(middlewares) do
    local src = read(m.path)
    assert_true(src:find(m.needle, 1, true), m.path .. " missing " .. m.needle)
    assert_true(src:find(m.must, 1, true), m.path .. " must call " .. m.must)
end
print("PASS ranked_buff_middleware_static")

-- ================================================================
-- 4. Core exports should_apply_ranked_buff when core loads
-- ================================================================

local core_src = read("EaxRotations/core_sylvanas.lua")
assert_true(core_src:find("function NS.buff_would_downgrade", 1, true), "core must define buff_would_downgrade")
assert_true(core_src:find("function NS.should_apply_ranked_buff", 1, true), "core must define should_apply_ranked_buff")
assert_true(core_src:find('action.kind == "buff"', 1, true)
    and core_src:find("buff_would_downgrade", 1, true),
    "action_ready buff path must use buff_would_downgrade")
print("PASS ranked_buff_core_static")

print("PASS test_ranked_buff_no_downgrade")
