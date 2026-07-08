-- test_quality_bar_compliance.lua -- quality compliance compliance check.
-- WHAT:  quality compliance compliance check
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Test: §4 Quality Bar Compliance Audit (Static Patterns Only)
-- ----------------------------------------------------------------------------
-- Verifies structural compliance across classes/* AND shared/* modules.
--
-- Rules:
--   R1: Pattern-15 header (WHAT/WHEN) — classes/ only
--   R2: No raw menu.get() outside function scope (load-time capture)
--   R3: No math.sqrt() for distance comparisons
--   R4: No forbidden raw cast paths (core.input.cast_target_spell,
--       spell_queue.queue_spell)
--   R5: No raw `_G.X` reads of WoW-client globals. Only `_G.EaxRotations`
--       allowed; `_G.Unit*`, `_G.Get*`, `_G.CreateFrame`, etc. forbidden
--       unless wrapped as `pcall(_G.X, ...)`.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function read_file(path)
    local f = assert(io.open(path, "rb"), "open failed: " .. path)
    local text = f:read("*a") or ""
    f:close()
    return text
end

local static_lists = {
    ["classes"] = {
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
    },
    ["shared"] = {
        "EaxRotations/shared/hunter_adaptive_sylvanas.lua",
    },
}

local spec_files = {}
for _, list in pairs(static_lists) do
    for _, path in ipairs(list) do
        spec_files[#spec_files + 1] = path
    end
end

local function add_issue(issues, path, rule, detail)
    issues[#issues + 1] = string.format("%s :: %s :: %s", path, rule, detail)
end

local issues = {}

for _, path in ipairs(spec_files) do
    local text = read_file(path)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end

    -- R1: Pattern-15 header (classes/ only; shared modules don't need WHAT/WHEN)
    if path:find("/classes/", 1, true) then
        local header_text = text:sub(1, 800)
        local has_pattern15 = header_text:find("WHAT:", 1, true) and header_text:find("WHEN:", 1, true)
        if not has_pattern15 then
            add_issue(issues, path, "missing-pattern15-header", "File header missing WHAT/WHEN pattern")
        end
    end

    -- R2: No raw menu.get() outside function scope (load-time capture)
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

    -- R3: No math.sqrt for distance comparisons
    for _, raw in ipairs(lines) do
        local code = raw:gsub("%-%-.*$", "")
        if code:find("math%.sqrt", 1, true) then
            add_issue(issues, path, "math-sqrt-distance", raw)
        end
    end

    -- R4: No forbidden raw cast paths (must use NS.try_cast or izi)
    for _, raw in ipairs(lines) do
        local code = raw:gsub("%-%-.*$", "")
        if code:find("core%.input%.cast_target_spell", 1) then
            add_issue(issues, path, "forbidden-raw-cast-path", raw)
        end
        if code:find("spell_queue%.queue_spell", 1) then
            add_issue(issues, path, "forbidden-raw-cast-path", raw)
        end
    end

    -- R5: No raw `_G.X` reads of WoW-client globals outside pcall().
    -- Allowed: `_G.EaxRotations`. Otherwise wrapped as `pcall(_G.X, ...)`.
    for _, raw in ipairs(lines) do
        local code = raw:gsub("%-%-.*$", "")
        if code:find("_G%.EaxRotations", 1) then
            code = code:gsub("_G%.EaxRotations[%w_%.]*", "")
        end
        if code:find("_G%.", 1, true) and not code:find("pcall%(_G%.", 1, true) then
            add_issue(issues, path, "raw-_G-wow-global", raw)
        end
    end
end

if #issues > 0 then
    error("§4 quality bar compliance failed:\n- " .. table.concat(issues, "\n- "), 0)
end

print("PASS test_quality_bar_compliance")

