-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-28
-- Change: Vanilla spell audit runner — standalone scanner for TBC contaminant IDs
-- =========================================================================
-- ============================================================================
-- What: Standalone runner that audits all vanilla spec files for TBC-era
--       spell/buff/debuff IDs. Run separately from the main rotation suite.
-- When: lua EaxRotations/tests/run_vanilla_audit_tests.lua
-- Why: Catches copy-paste contamination where TBC spell ranks leak
--      into Classic-era rotation files (e.g. Battle Shout rank 8 =
--      25289 in a vanilla file that should max at rank 7 = 2048).
-- Exit: 0 = all vanilla files clean; 1 = TBC contamination found.
-- Safety: Read-only text scan — no dofile(), no mock setup needed.
-- ============================================================================

-- --------------------------------------------------------------------------
-- Known TBC contaminant spell IDs that should NEVER appear in vanilla files.
-- Format: [id] = "description"
-- These were identified in the 2026-05-27 deep vanilla audit.
-- --------------------------------------------------------------------------
local TBC_IDS = {
    [25289] = "Battle Shout rank 8 (TBC; Classic max = 2048)",
    [27131] = "Mana Shield rank 7 (TBC; Classic max = 10223)",
    [27126] = "Icy Veins (TBC talent)",
    [27127] = "Icy Veins (TBC talent)",
    [27136] = "Holy Light rank 11 (TBC)",
    [27137] = "Holy Light rank 12 (TBC)",
    [27138] = "Holy Light rank 13 (TBC)",
    [27139] = "Holy Light rank 14 (TBC)",
    [27173] = "Consecration rank 6 (TBC)",
    [27179] = "Holy Shield rank 4 (TBC)",
    [30146] = "Summon Felguard (TBC 41pt Demo talent)",
    [31016] = "Eviscerate rank 12 (TBC; Classic max = 26865)",
    [31589] = "Slow (TBC Arcane talent)",
    [33206] = "Pain Suppression (TBC 41pt Disc talent)",
    [33831] = "Force of Nature (TBC 41pt Balance talent)",
    [33876] = "Mangle Cat rank 1 (TBC talent)",
    [33878] = "Mangle Bear rank 1 (TBC talent)",
    [33891] = "Tree of Life Form (TBC 41pt Resto talent)",
    [34914] = "Vampiric Touch rank 1 (TBC 41pt Shadow talent)",
    [34916] = "Vampiric Touch rank 2 (TBC)",
    [34917] = "Vampiric Touch rank 3 (TBC)",
    [35395] = "Crusader Strike (TBC 41pt Retribution talent)",
    [36554] = "Shadowstep (TBC Subtlety talent)",
}

-- --------------------------------------------------------------------------
-- Vanilla spec files to audit — excludes leveling, healing, middleware,
-- schema, class, clip, debug, caster, helper files.
-- These are the actual rotation strategy files.
-- --------------------------------------------------------------------------
local VANILLA_SPECS = {
    -- Druid (4)
    "classes/druid/balance_vanilla.lua",
    "classes/druid/bear_vanilla.lua",
    "classes/druid/cat_vanilla.lua",
    "classes/druid/resto_vanilla.lua",
    -- Hunter (3)
    "classes/hunter/beast_mastery_vanilla.lua",
    "classes/hunter/marksmanship_vanilla.lua",
    "classes/hunter/survival_vanilla.lua",
    -- Mage (3)
    "classes/mage/arcane_vanilla.lua",
    "classes/mage/fire_vanilla.lua",
    "classes/mage/frost_vanilla.lua",
    -- Paladin (3)
    "classes/paladin/holy_vanilla.lua",
    "classes/paladin/protection_vanilla.lua",
    "classes/paladin/retribution_vanilla.lua",
    -- Priest (3)
    "classes/priest/discipline_vanilla.lua",
    "classes/priest/holy_vanilla.lua",
    "classes/priest/shadow_vanilla.lua",
    -- Rogue (3)
    "classes/rogue/assassination_vanilla.lua",
    "classes/rogue/combat_vanilla.lua",
    "classes/rogue/subtlety_vanilla.lua",
    -- Shaman (3)
    "classes/shaman/elemental_vanilla.lua",
    "classes/shaman/enhancement_vanilla.lua",
    "classes/shaman/restoration_vanilla.lua",
    -- Warlock (3)
    "classes/warlock/affliction_vanilla.lua",
    "classes/warlock/demonology_vanilla.lua",
    "classes/warlock/destruction_vanilla.lua",
    -- Warrior (4)
    "classes/warrior/arms_vanilla.lua",
    "classes/warrior/fury_vanilla.lua",
    "classes/warrior/kebab_vanilla.lua",
    "classes/warrior/protection_vanilla.lua",
}

-- --------------------------------------------------------------------------
-- TBC threshold: Any spell ID >= 27000 that is NOT in this allowlist
-- is treated as a TBC contaminant. Some Classic spells (like Eviscerate
-- rank 9 = 26865) fall below this threshold, but TBC ranks start at ~27000.
-- --------------------------------------------------------------------------
local TBC_THRESHOLD = 27000

-- Classic-era spell IDs >= 27000 that are NOT TBC contaminants.
-- Update this if new edge cases are discovered.
local THRESHOLD_ALLOWLIST = {
    -- Add known Classic spell IDs that happen to be >= 27000 here.
    -- Currently empty — no known Classic-era spells in this range.
}

local root = "EaxRotations"

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a") or ""
    f:close()
    return content
end

--- Check if a line is a comment-only line (stripping leading whitespace).
--- We skip these to avoid false positives from documentation mentioning spell IDs.
local function is_comment_line(line)
    return line:match("^%s*%-%-") ~= nil
end

--- Scan a file for TBC contaminant IDs. Returns a table of findings:
---   { found = true/false, hits = { {line=#, col=#, id=#, desc="..."}, ... } }
local function scan_file(filepath)
    local content = read_file(filepath)
    if not content then
        return { found = false, hits = {}, error = "could not read file" }
    end

    local hits = {}
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end

    for line_no, line in ipairs(lines) do
        if not is_comment_line(line) then
            -- Find all 5-digit numbers in the line
            for num_str in line:gmatch("(%d%d%d%d%d)") do
                local num = tonumber(num_str)
                if not num then
                    -- skip
                elseif TBC_IDS[num] then
                    hits[#hits + 1] = {
                        line = line_no,
                        col = line:find(num_str, 1, true),
                        id = num,
                        desc = TBC_IDS[num],
                        snippet = line:match("^%s*(.-)%s*$") or line,
                    }
                elseif num >= TBC_THRESHOLD and not THRESHOLD_ALLOWLIST[num] then
                    -- Catch any 5-digit number >= 27000 not in the known-ID table.
                    -- Guardrail against unknown TBC contaminations.
                    hits[#hits + 1] = {
                        line = line_no,
                        col = line:find(num_str, 1, true),
                        id = num,
                        desc = "UNKNOWN TBC ID >= " .. TBC_THRESHOLD .. " (not in allowlist)",
                        snippet = line:match("^%s*(.-)%s*$") or line,
                    }
                end
            end
        end
    end

    return { found = #hits > 0, hits = hits }
end

-- ============================================================================
-- Main audit
-- ============================================================================

local total = 0
local passed = 0
local failed = 0
local failures = {}

for _, file in ipairs(VANILLA_SPECS) do
    local path = root .. "/" .. file
    total = total + 1

    local result = scan_file(path)

    if result.error then
        failed = failed + 1
        failures[#failures + 1] = { file = file, error = result.error, hits = {} }
        print(string.format("  [ ERROR ] %-45s %s", file, result.error))
    elseif result.found then
        failed = failed + 1
        failures[#failures + 1] = { file = file, hits = result.hits }
        print(string.format("  [ FAIL ]  %-45s %d TBC ID(s)", file, #result.hits))
        for _, hit in ipairs(result.hits) do
            print(string.format("            line %4d: id %d — %s", hit.line, hit.id, hit.desc))
        end
    else
        passed = passed + 1
        print(string.format("  [ PASS ]  %-45s clean", file))
    end
end

-- ============================================================================
-- Results
-- ============================================================================

print("")
print("=============================================================================")
print("  VANILLA SPELL AUDIT RESULTS")
print("=============================================================================")
print(string.format("  Total:   %3d vanilla spec files", total))
print(string.format("  Clean:   %3d", passed))
print(string.format("  Tainted: %3d", failed))

if failed > 0 then
    print("")
    print("  TBC contaminant IDs found:")
    for _, f in ipairs(failures) do
        print("    " .. f.file)
        if f.error then
            print("      ERROR: " .. f.error)
        else
            for _, hit in ipairs(f.hits) do
                print(string.format("      line %d: id %d — %s", hit.line, hit.id, hit.desc))
            end
        end
    end
end

print("=============================================================================")

if failed > 0 then
    print("Vanilla spell audit FAILED: " .. tostring(failed) .. " spec file(s) have TBC contaminant spell IDs")
    os.exit(1)
end

print("All vanilla spec files clean — no TBC contamination.")
