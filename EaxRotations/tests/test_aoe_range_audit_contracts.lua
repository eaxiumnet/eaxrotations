-- test_aoe_range_audit_contracts.lua
-- WHAT: Manifest-backed structural scan for AoE hit-volume gates.
-- WHEN: Rotation suite / standalone.
-- WHY:  Every high-severity multi-target matcher across Vanilla/TBC/WotLK must
--       use aoe_self_meets / aoe_target_meets — one dirty expansion fails the suite.
-- SAFETY: Read-only file scans via aoe_high_severity_manifest.lua.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/tests/?.lua;./?.lua;"
    .. package.path

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local t = f:read("*a") or ""
    f:close()
    return t
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

-- 1) Global 40yd density remains for Auto-AoE
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

-- 2) Core / shared hit-volume helpers shipped
do
    local core = read_file("EaxRotations/core_sylvanas.lua")
    local shared = read_file("EaxRotations/shared/aoe_hit_volume_sylvanas.lua")
    all_ok = assert_true(core ~= nil, "core_sylvanas.lua readable") and all_ok
    all_ok = assert_true(shared ~= nil, "aoe_hit_volume_sylvanas.lua readable") and all_ok
    if core then
        -- Geometry gates are installed from shared (force vec2/vec3); core must load that module.
        all_ok = assert_true(core:find("aoe_hit_volume_sylvanas", 1, true) ~= nil, "core loads aoe_hit_volume") and all_ok
        all_ok = assert_true(core:find("AoeHV.install", 1, true) ~= nil or core:find(".install(NS)", 1, true) ~= nil,
            "core installs shared hit-volume helpers") and all_ok
        all_ok = assert_true(core:find("NS.AOE_RADIUS", 1, true) ~= nil, "AOE_RADIUS in core") and all_ok
        all_ok = assert_true(core:find("action.hit_radius", 1, true) ~= nil, "evaluate_cast hit_radius") and all_ok
        all_ok = assert_true(core:find("vector_2", 1, true) ~= nil or shared and shared:find("vector_2", 1, true),
            "hit-volume path references vector_2") and all_ok
    end
    if shared then
        all_ok = assert_true(shared:find("function M.aoe_self_meets", 1, true) ~= nil
            or shared:find("aoe_self_meets", 1, true) ~= nil, "shared aoe_self_meets") and all_ok
        all_ok = assert_true(shared:find("aoe_cone_meets", 1, true) ~= nil, "shared aoe_cone_meets") and all_ok
        all_ok = assert_true(shared:find("count_enemies_in_cone", 1, true) ~= nil, "shared count_enemies_in_cone") and all_ok
        all_ok = assert_true(shared:find("cast_ground_aoe", 1, true) ~= nil, "shared cast_ground_aoe") and all_ok
        all_ok = assert_true(shared:find("offset_in_facing_cone", 1, true) ~= nil, "shared offset_in_facing_cone") and all_ok
        all_ok = assert_true(shared:find("CONE_HALF_ANGLE", 1, true) ~= nil, "shared CONE_HALF_ANGLE") and all_ok
        all_ok = assert_true(shared:find("vector_2", 1, true) ~= nil, "shared uses vector_2") and all_ok
        all_ok = assert_true(shared:find("vector_3", 1, true) ~= nil, "shared uses vector_3") and all_ok
        all_ok = assert_true(shared:find("squared_dist_to_ignore_z", 1, true) ~= nil
            or shared:find("length_squared", 1, true) ~= nil, "shared uses vec distance methods") and all_ok
        all_ok = assert_true(shared:find("math.atan2", 1, true) == nil, "cone path avoids math.atan2") and all_ok
    end
    if core then
        all_ok = assert_true(core:find("hit_radius", 1, true) ~= nil, "core position_for/hit_radius ground place") and all_ok
    end
end

-- 3) Manifest-backed high-severity scan (all expansions)
do
    local scanner = nil
    local ok_load, mod = pcall(function()
        return dofile("EaxRotations/tests/scan_aoe_manifest.lua")
    end)
    if ok_load and type(mod) == "table" and mod.scan then
        scanner = mod
    else
        -- require path fallback
        package.loaded["scan_aoe_manifest"] = nil
        local ok2, mod2 = pcall(require, "scan_aoe_manifest")
        if ok2 and type(mod2) == "table" then scanner = mod2 end
    end
    all_ok = assert_true(scanner ~= nil and scanner.scan ~= nil, "scan_aoe_manifest loaded") and all_ok
    if scanner then
        local rows, dirty = scanner.scan()
        all_ok = assert_true(type(rows) == "table" and #rows > 0, "manifest produced rows") and all_ok
        if dirty and dirty > 0 then
            print(scanner.format_report(rows, dirty))
            all_ok = assert_true(false, "manifest dirty_count=" .. tostring(dirty) .. " (must be 0)") and all_ok
        else
            all_ok = assert_true(true, "manifest ALL_CLEAN rows=" .. tostring(#rows)) and all_ok
        end
    end
end

-- 4) Audit artifact
-- Tracked under EaxRotations/docs/ (the old plans/_archive/ path was never
-- git-tracked, so a clean checkout had no plan doc; docs/ is tracked).
do
    local src = read_file("EaxRotations/docs/aoe_range_audit_plan_2026-07-16.md")
    all_ok = assert_true(src ~= nil, "audit plan exists") and all_ok
    if src then
        all_ok = assert_true(src:find("Mismatch", 1, true) ~= nil or src:find("hit-volume", 1, true) ~= nil,
            "audit documents mismatches / hit-volume") and all_ok
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
