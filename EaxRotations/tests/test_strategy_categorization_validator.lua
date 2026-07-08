-- test_strategy_categorization_validator.lua — Audit item #4b.
-- WHAT:  Static-analysis validator that scans all spec + middleware files, extracts
--        strategy `name=` values, runs them through the REAL categorization logic,
--        and flags strategies at risk of miscategorization (the audit's concern that
--        "misspelled strategy names silently miscategorize defensive/CD sections").
-- WHEN:  run standalone or via run_rotation_tests.lua.
-- WHY:   strategy_category() relies on keyword-substring matching (no declarative
--        flag). A name that doesn't match any keyword silently defaults to "damage",
--        which means use_defensives/use_cooldowns toggles won't gate it correctly.
-- SAFETY: pure file-read static analysis; loads the real strategy_gating module.
local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/??.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

-- Load the REAL categorization engine so we validate against production logic.
local sg_ok, sg = pcall(require, "core/strategy_gating")
assert_true(sg_ok and type(sg) == "table", "cannot load core/strategy_gating")

-- ============================================================================
-- File collection: all spec + middleware files that declare strategies.
-- ============================================================================
local function read_file(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local text = f:read("*a") or ""; f:close(); return text
end

local SPEC_DIRS = {
    "EaxRotations/classes/druid", "EaxRotations/classes/hunter",
    "EaxRotations/classes/mage", "EaxRotations/classes/paladin",
    "EaxRotations/classes/priest", "EaxRotations/classes/rogue",
    "EaxRotations/classes/shaman", "EaxRotations/classes/warlock",
    "EaxRotations/classes/warrior",
}

local function collect_target_files()
    local out = {}
    for _, dir in ipairs(SPEC_DIRS) do
        local p = io.popen('cmd /c "dir /s /b "' .. dir .. '\\*.lua" 2>nul"')
        if p then
            for line in p:lines() do
                local norm = line:gsub("\\", "/")
                if norm:match("_sylvanas%.lua$") and not norm:match("/tests/")
                   -- Exclude class_sylvanas.lua: these define spell objects, not strategies.
                   and not norm:match("class_sylvanas%.lua$") then
                    out[#out + 1] = norm
                end
            end
            p:close()
        end
    end
    return out
end

-- Extract strategy name = "CamelCase" values WITH their declarative flags.
-- For each match, capture the next ~12 lines to detect is_burst=true / category="...".
-- Returns a list of { name=, is_burst=, category= } entries.
local function extract_strategy_entries(text)
    local entries = {}
    local pos = 1
    while true do
        local s, _, name = text:find('name%s*=%s*"([A-Z][%w_]*)"', pos)
        if not s then break end
        pos = s + 1  -- advance past this match for next iteration
        -- Capture the surrounding context (120 chars ahead) to detect declarative flags.
        local ctx = text:sub(s, s + 160)
        local is_burst = ctx:find("is_burst%s*=%s*true") ~= nil
        local cat = ctx:match('category%s*=%s*"(%w+)"')
        entries[#entries + 1] = { name = name, is_burst = is_burst, category = cat }
    end
    return entries
end

-- Heuristic keyword stems that SHOULD be in the categorization tables if present
-- in a strategy name. If a name contains one of these stems but the stem is NOT
-- in the corresponding keyword list, that's a miscategorization risk.
-- (These are the broad English spell-stems; the keyword tables use lowercase
--  no-space versions. We check the lowercased name against the keyword stems.)
local DEFENSIVE_STEMS = { "shieldblock", "shieldwall", "shieldbarrier", "stoneform", "dampenmagic", "laststand", "frenziedregen", "holyshield", "bonearmor", "soulstone", "soulburn", "anticipation" }
local COOLDOWN_STEMS  = { "avengingwrath", "combustion", "icyveins", "arcanepower", "rapidfire", "bestialwrath", "bloodfury", "berserking", "innervate", "shadowfiend", "innerfocus", "sweepingstrikes", "recklessness", "deathwish", "bladeflurry", "adrenalinerush", "bloodlust", "shamanisticrage", "powerinfusion", "trinket", "berserker" }
local HEALING_STEMS   = { "heal", "renew", "mending", "lifebloom", "rejuvenation", "regrowth", "powerwordshield", "prayerofhealing", "bindingheal", "holyshock", "layonhands", "earthshield", "circleofhealing", "flourish", "tranquility", "divineillumination" }
local UTILITY_STEMS   = { "interrupt", "kick", "pummel", "counterspell", "spelllock", "silence", "cleanse", "dispel", "purify", "cure", "fade", "feign", "vanish", "evasion", "sprint", "cower", "shatter", "counterspell" }

local function contains_any(value, needles)
    for i = 1, #needles do if value:find(needles[i], 1, true) then return true end end
    return false
end

-- Check whether a stem is already covered by the REAL keyword tables.
local function stem_covered(stem, keyword_table)
    return sg.contains_any(stem, keyword_table)
end

-- ============================================================================
-- Main validation: scan all files, classify each strategy name, flag risks.
-- ============================================================================
local files = collect_target_files()
assert_true(#files > 0, "should find spec/middleware files to analyze")

local risks = {}        -- confirmed miscategorization risks (FAIL the test)
local warnings = {}     -- informational (implicit damage default; may be intentional)
local total_names = 0

for _, path in ipairs(files) do
    local text = read_file(path)
    if text then
        local is_middleware = path:match("middleware_sylvanas%.lua$") ~= nil
        local list_name = is_middleware and "middleware" or nil
        local entries = extract_strategy_entries(text)
        for _, entry in ipairs(entries) do
            local name = entry.name
            -- Skip entries that already declare is_burst or category (no miscategorization risk).
            if not (entry.is_burst or entry.category) then
                total_names = total_names + 1
                local lname = name:lower():gsub("%s+", "")
                -- Simulate the REAL categorization (without caching; active=nil for static).
                local mock = { name = name }
                local cat = sg.strategy_category(mock, list_name, nil)
                -- R1: defensive stem in name but categorized as damage (missed by keywords)
                if cat == "damage" and contains_any(lname, DEFENSIVE_STEMS) then
                    risks[#risks + 1] = string.format("%s :: %s :: defensive stem but categorized 'damage' (add to DEFENSIVE_NAMES)", path, name)
                -- R2: cooldown stem in name but categorized as damage
                elseif cat == "damage" and contains_any(lname, COOLDOWN_STEMS) then
                    risks[#risks + 1] = string.format("%s :: %s :: cooldown stem but categorized 'damage' (add to COOLDOWN_NAMES or set is_burst=true)", path, name)
                -- R3: healing stem in name but categorized as damage
                elseif cat == "damage" and contains_any(lname, HEALING_STEMS) then
                    risks[#risks + 1] = string.format("%s :: %s :: healing stem but categorized 'damage' (add to HEALING_NAMES)", path, name)
                -- R4: utility stem in name but categorized as damage
                elseif cat == "damage" and contains_any(lname, UTILITY_STEMS) then
                    risks[#risks + 1] = string.format("%s :: %s :: utility stem but categorized 'damage' (add to UTILITY_NAMES)", path, name)
                end
            end
        end
    end
end

-- ============================================================================
-- Report
-- ============================================================================
if #risks > 0 then
    error("strategy categorization validator found " .. #risks .. " miscategorization risk(s):\n  - " ..
          table.concat(risks, "\n  - ") ..
          "\n\nFix: either add the stem to the corresponding *_NAMES table in core/strategy_gating.lua," ..
          " OR add an explicit `category = \"<correct>\"` field to the strategy entry.", 0)
end

print(string.format("PASS test_strategy_categorization_validator (%d strategies scanned across %d files, 0 miscategorization risks, %d informational warnings)",
      total_names, #files, #warnings))
