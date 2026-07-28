-- test_id_audit_report.lua — gates the multi-expansion spell ID audit artifact.
-- WHAT:  asserts buff_debuff_full_verification.json reports 0 fails + key ranks present.
-- WHEN:  run via run_rotation_tests.lua or standalone.
-- WHY:  keeps the full ID audit report honest (not a re-implementation of lookup).
-- SAFETY: pure file/json read; no network.

local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- Minimal JSON number/string field reader (report is flat enough for this).
local function json_number(s, key)
    local v = s:match('"' .. key .. '"%s*:%s*(%-?%d+%.?%d*)')
    return v and tonumber(v) or nil
end

local function json_array_empty(s, key)
    -- "fail_ids": []  or "fail_ids": [ ... ]
    local body = s:match('"' .. key .. '"%s*:%s*(%b[])')
    if not body then return false end
    return body:match("^%[%s*%]$") ~= nil
end

local function has_id_block(s, id)
    -- "26990": { ... "ok": true
    local pat = '"' .. tostring(id) .. '"%s*:%s*%b{}'
    local block = s:match(pat)
    return block ~= nil and block:find('"ok"%s*:%s*true') ~= nil
end

local function present_flag(s, id, exp)
    local pat = '"' .. tostring(id) .. '"%s*:%s*%b{}'
    local block = s:match(pat)
    if not block then return false end
    -- nested "present": { "classic": true, "tbc": true, "wotlk": ...
    local present = block:match('"present"%s*:%s*(%b{})')
    if not present then return false end
    return present:find('"' .. exp .. '"%s*:%s*true') ~= nil
end

local paths = {
    "EaxRotations/tools/buff_debuff_full_verification.json",
    "tools/buff_debuff_full_verification.json",
}
local report
for _, p in ipairs(paths) do
    report = read(p)
    if report then break end
end
assert(report, "missing buff_debuff_full_verification.json — run python build_tools/generate_buff_debuff_verification.py")

local unique = json_number(report, "unique_ids")
local ok = json_number(report, "ok")
local fail = json_number(report, "fail")
local classic = json_number(report, "online_classic")
local tbc = json_number(report, "online_tbc")
local wotlk = json_number(report, "online_wotlk")

assert(type(unique) == "number" and unique > 500, "unique_ids must be a large inventory")
assert(type(ok) == "number" and ok == unique, "ok must equal unique_ids")
assert(type(fail) == "number" and fail == 0, "fail must be 0")
assert(json_array_empty(report, "fail_ids"), "fail_ids must be empty array")
assert(type(classic) == "number" and classic > 0, "online_classic must be > 0")
assert(type(tbc) == "number" and tbc > 0, "online_tbc must be > 0")
assert(type(wotlk) == "number" and wotlk > 0, "online_wotlk must be > 0")

-- Coverage: inventory must include scalar define() IDs and multi-line aura maps
-- (proves extractor is not limited to define("X", {ranks}) / pre-comment IDs only).
assert(unique >= 2000, "inventory must include cast ladders (unique_ids >= 2000)")
assert(has_id_block(report, 46924), "Bladestorm 46924 (scalar define) must be inventoried OK")
assert(has_id_block(report, 20230), "Retaliation 20230 (scalar define) must be inventoried OK")
assert(has_id_block(report, 7814), "Lash of Pain 7814 (SUCC_LASH_IDS) must be inventoried OK")
assert(has_id_block(report, 27274), "Lash of Pain 27274 (SUCC_LASH_IDS max) must be inventoried OK")
-- Multi-line TRACKED_AURAS must not stop at first inline comment
assert(has_id_block(report, 3045), "Rapid Fire 3045 (TRACKED_AURAS) must be inventoried OK")
assert(has_id_block(report, 34471), "Beast Within 34471 (later TRACKED_AURAS entry) must be inventoried OK")
-- Unnamed ALL_CAPS ladders
assert(has_id_block(report, 55095), "Frost Fever 55095 must be inventoried OK")
assert(has_id_block(report, 55078), "Blood Plague 55078 must be inventoried OK")
assert(has_id_block(report, 44401), "Missile Barrage proc 44401 must be inventoried OK")
-- Invalid disease ranks must not appear after fix
assert(not has_id_block(report, 55096), "invalid Frost Fever 55096 must not be inventoried")
assert(not has_id_block(report, 55079), "invalid Blood Plague 55079 must not be inventoried")

-- Spot-check known ranks in the inventory (must be ok + expansion flags)
assert(has_id_block(report, 26990), "MotW TBC max 26990 must be inventoried OK")
assert(present_flag(report, 26990, "tbc"), "MotW 26990 must be present on tbc")
assert(has_id_block(report, 48469), "MotW WotLK max 48469 must be inventoried OK")
assert(present_flag(report, 48469, "wotlk"), "MotW 48469 must be present on wotlk")
assert(has_id_block(report, 1126), "MotW r1 1126 must be inventoried OK")
assert(present_flag(report, 1126, "classic") or present_flag(report, 1126, "tbc"),
    "MotW 1126 must be present on classic or tbc")
-- Debuff example
assert(has_id_block(report, 27226) or has_id_block(report, 704),
    "Curse of Recklessness rank must be inventoried")

print("PASS test_id_audit_report")
