-- test_aoe_range_audit_contracts.lua
-- WHAT: Structural contracts for AoE hit-volume fixes (post-fix).
-- WHEN: Rotation test suite / standalone.
-- WHY:  Pin 40yd global density for Auto-AoE, hit-volume helpers in core,
--       and high-severity self-PBAoE gates using aoe_self_meets (not 40yd-only).
-- SAFETY: Read-only file scans + requires no combat.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a") or ""
    f:close()
    return text
end

local function assert_true(v, msg)
    if not v then
        print("FAIL " .. tostring(msg))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local all_ok = true

-- 1) Global 40yd density remains for Auto-AoE / context.enemy_count
do
    local src = read_file("EaxRotations/main_sylvanas.lua")
    all_ok = assert_true(src ~= nil, "main_sylvanas.lua readable") and all_ok
    if src then
        local hits = 0
        for _ in src:gmatch("get_targets%(40%)") do hits = hits + 1 end
        for _ in src:gmatch("get_enemy_list_around%([^%)]-40") do hits = hits + 1 end
        for _ in src:gmatch("GetEnemiesInRange%(40%)") do hits = hits + 1 end
        all_ok = assert_true(hits >= 2, "throttled_enemies has >=2 explicit 40yd scans") and all_ok
        all_ok = assert_true(src:find("enemy_count", 1, true) ~= nil, "context.enemy_count still wired") and all_ok
    end
end

-- 2) Core hit-volume helpers shipped
do
    local src = read_file("EaxRotations/core_sylvanas.lua")
    all_ok = assert_true(src ~= nil, "core_sylvanas.lua readable") and all_ok
    if src then
        all_ok = assert_true(src:find("function NS.aoe_self_meets", 1, true) ~= nil, "NS.aoe_self_meets defined") and all_ok
        all_ok = assert_true(src:find("function NS.aoe_target_meets", 1, true) ~= nil, "NS.aoe_target_meets defined") and all_ok
        all_ok = assert_true(src:find("function NS.count_enemies_around_me", 1, true) ~= nil, "count_enemies_around_me defined") and all_ok
        all_ok = assert_true(src:find("function NS.count_enemies_around_unit", 1, true) ~= nil, "count_enemies_around_unit defined") and all_ok
        all_ok = assert_true(src:find("NS.AOE_RADIUS", 1, true) ~= nil, "AOE_RADIUS constants") and all_ok
        all_ok = assert_true(src:find("max_range or 35", 1, true) ~= nil, "get_aoe_cast_position max_range 35") and all_ok
        all_ok = assert_true(src:find("radius or 8", 1, true) ~= nil, "get_aoe_cast_position radius 8") and all_ok
        all_ok = assert_true(src:find("action.hit_radius", 1, true) ~= nil, "evaluate_cast respects hit_radius") and all_ok
    end
end

-- 3) High-severity self-PBAoE uses aoe_self_meets (fixed behavior)
do
    local cases = {
        { file = "EaxRotations/classes/mage/fire_sylvanas.lua", needle = "arcane_explosion_matches", helper = "aoe_self_meets" },
        { file = "EaxRotations/classes/mage/frost_sylvanas.lua", needle = "arcane_explosion_matches", helper = "aoe_self_meets" },
        { file = "EaxRotations/classes/mage/fire_vanilla.lua", needle = "arcane_explosion", helper = "aoe_self_meets" },
        { file = "EaxRotations/classes/warlock/demonology_sylvanas.lua", needle = "hellfire_matches", helper = "aoe_self_meets" },
        { file = "EaxRotations/classes/priest/shadow_sylvanas.lua", needle = "holy_nova_aoe_matches", helper = "aoe_self_meets" },
        { file = "EaxRotations/classes/rogue/leveling_wotlk.lua", needle = "fan_of_knives", helper = "aoe_self_meets" },
        { file = "EaxRotations/classes/deathknight/leveling_wotlk.lua", needle = "blood_boil", helper = "aoe_self_meets" },
    }
    for i = 1, #cases do
        local c = cases[i]
        local src = read_file(c.file)
        all_ok = assert_true(src ~= nil, c.file .. " readable") and all_ok
        if src then
            local start = src:find(c.needle, 1, true)
            all_ok = assert_true(start ~= nil, c.file .. " has " .. c.needle) and all_ok
            if start then
                local window = src:sub(start, start + 700)
                all_ok = assert_true(window:find(c.helper, 1, true) ~= nil,
                    c.file .. " " .. c.needle .. " uses " .. c.helper) and all_ok
            end
        end
    end
end

-- 4) Target-centered samples
do
    local cases = {
        { file = "EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", needle = "multi_shot_matches", helper = "aoe_target_meets" },
        { file = "EaxRotations/classes/warlock/affliction_sylvanas.lua", needle = "SeedOfCorruption", helper = "aoe_target_meets" },
        { file = "EaxRotations/classes/deathknight/frost_wotlk.lua", needle = "howling_blast_matches", helper = "aoe_target_meets" },
    }
    for i = 1, #cases do
        local c = cases[i]
        local src = read_file(c.file)
        all_ok = assert_true(src ~= nil, c.file .. " readable") and all_ok
        if src then
            all_ok = assert_true(src:find(c.helper, 1, true) ~= nil,
                c.file .. " uses " .. c.helper) and all_ok
        end
    end
end

-- 5) Audit artifact updated for fix
do
    local src = read_file("plans/aoe-range-audit-2026-07-16.md")
    all_ok = assert_true(src ~= nil, "audit plan exists") and all_ok
    if src then
        all_ok = assert_true(src:find("Mismatch", 1, true) ~= nil, "audit has Mismatch section") and all_ok
        all_ok = assert_true(src:find("40 yards", 1, true) ~= nil or src:find("40yd", 1, true) ~= nil,
            "audit documents 40yd global scan") and all_ok
    end
end

if all_ok then
    print("OK aoe_range_audit_contracts")
else
    print("FAIL aoe_range_audit_contracts")
    os.exit(1)
end
