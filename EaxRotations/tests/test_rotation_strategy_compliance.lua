-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_rotation_strategy_compliance.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function read_file(path)
    local f = assert(io.open(path, "rb"), "open failed: " .. path)
    local text = f:read("*a") or ""
    f:close()
    return text
end

local spec_files = {
    "EaxRotations/classes/druid/balance_sylvanas.lua",
    "EaxRotations/classes/druid/bear_sylvanas.lua",
    "EaxRotations/classes/druid/cat_sylvanas.lua",
    "EaxRotations/classes/druid/caster_sylvanas.lua",
    "EaxRotations/classes/druid/healing_sylvanas.lua",
    "EaxRotations/classes/druid/leveling_sylvanas.lua",
    "EaxRotations/classes/druid/resto_sylvanas.lua",
    "EaxRotations/classes/hunter/beast_mastery_sylvanas.lua",
    "EaxRotations/classes/hunter/marksmanship_sylvanas.lua",
    "EaxRotations/classes/hunter/survival_sylvanas.lua",
    "EaxRotations/classes/hunter/leveling_sylvanas.lua",
    "EaxRotations/classes/mage/arcane_sylvanas.lua",
    "EaxRotations/classes/mage/fire_sylvanas.lua",
    "EaxRotations/classes/mage/frost_sylvanas.lua",
    "EaxRotations/classes/mage/leveling_sylvanas.lua",
    "EaxRotations/classes/paladin/holy_sylvanas.lua",
    "EaxRotations/classes/paladin/protection_sylvanas.lua",
    "EaxRotations/classes/paladin/retribution_sylvanas.lua",
    "EaxRotations/classes/paladin/leveling_sylvanas.lua",
    "EaxRotations/classes/priest/discipline_sylvanas.lua",
    "EaxRotations/classes/priest/holy_sylvanas.lua",
    "EaxRotations/classes/priest/shadow_sylvanas.lua",
    "EaxRotations/classes/priest/smite_sylvanas.lua",
    "EaxRotations/classes/priest/leveling_sylvanas.lua",
    "EaxRotations/classes/rogue/assassination_sylvanas.lua",
    "EaxRotations/classes/rogue/combat_sylvanas.lua",
    "EaxRotations/classes/rogue/subtlety_sylvanas.lua",
    "EaxRotations/classes/rogue/leveling_sylvanas.lua",
    "EaxRotations/classes/shaman/elemental_sylvanas.lua",
    "EaxRotations/classes/shaman/enhancement_sylvanas.lua",
    "EaxRotations/classes/shaman/restoration_sylvanas.lua",
    "EaxRotations/classes/shaman/leveling_sylvanas.lua",
    "EaxRotations/classes/warlock/affliction_sylvanas.lua",
    "EaxRotations/classes/warlock/demonology_sylvanas.lua",
    "EaxRotations/classes/warlock/destruction_sylvanas.lua",
    "EaxRotations/classes/warlock/leveling_sylvanas.lua",
    "EaxRotations/classes/warrior/arms_sylvanas.lua",
    "EaxRotations/classes/warrior/fury_sylvanas.lua",
    "EaxRotations/classes/warrior/kebab_sylvanas.lua",
    "EaxRotations/classes/warrior/protection_sylvanas.lua",
    "EaxRotations/classes/warrior/leveling_sylvanas.lua",
}

local function add_issue(issues, path, rule, detail)
    issues[#issues + 1] = string.format("%s :: %s :: %s", path, rule, detail)
end

local issues = {}
for _, path in ipairs(spec_files) do
    local text = read_file(path)
    local has_registration = text:find("NS%.rotation_registry:register%(", 1) ~= nil
    if has_registration then
        local lines = {}
        for line in text:gmatch("[^\r\n]+") do
            lines[#lines + 1] = line
        end

        local seen_function = false
        for _, raw in ipairs(lines) do
            local code = raw:gsub("%-%-.*$", "")
            if code:match("^%s*(local%s+function|function%s+|local%s+[%w_]+%s*=%s*function)") then
                seen_function = true
            end
            if not seen_function and code:find("menu%.", 1) and code:find(":get%(", 1) then
                add_issue(issues, path, "load-time-menu-capture", raw)
            end
        end

        for _, raw in ipairs(lines) do
            local code = raw:gsub("%-%-.*$", "")
            -- ONLY flag truly dangerous raw cast paths
            if code:find("core%.input%.cast_target_spell", 1) then
                add_issue(issues, path, "forbidden-raw-cast-path", raw)
            end
            if code:find("spell_queue%.queue_spell", 1) then
                add_issue(issues, path, "forbidden-raw-cast-path", raw)
            end
        end
    end
end

if #issues > 0 then
    error("strategy compliance failed:\n- " .. table.concat(issues, "\n- "), 0)
end

print("PASS test_rotation_strategy_compliance")
