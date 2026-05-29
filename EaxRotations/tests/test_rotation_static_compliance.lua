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
        for line in text:gmatch("[^\r\n]+") do
            local code = line:gsub("%-%-.*$", "")

            -- ONLY flag raw API time() minus comparisons (manual throttle gating)
            if (code:find("core%.time%(%s*%)") or code:find("GetTime%(%s*%)"))
                and (code:find("<", 1, true) or code:find(">", 1, true) or code:find("-", 1, true)) then
                add_issue(issues, path, "forbidden-raw-time-gating", line)
            end

            -- Only flag min_interval used as a gate threshold
            if code:find("min_interval", 1, true)
                and (code:find("<", 1, true) or code:find(">", 1, true) or code:find("return false", 1, true)) then
                add_issue(issues, path, "forbidden-min-interval-gate", line)
            end
        end
    end
end

if #issues > 0 then
    error("static compliance failed:\n- " .. table.concat(issues, "\n- "), 0)
end

print("PASS test_rotation_static_compliance")