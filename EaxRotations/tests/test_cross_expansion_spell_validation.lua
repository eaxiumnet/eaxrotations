-- test_cross_expansion_spell_validation.lua -- cross-expansion spell resolution validation suite.
-- WHAT:  cross-expansion spell resolution validation suite
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Cross-Expansion Spell ID Validation
-- ============================================================================
-- Catches three categories of cross-expansion spell ID issues:
--   1. Swapped spells: same spell at same level has different IDs per expansion
--   2. ID reuse conflicts: a TBC spell's ID means something different in Vanilla
--   3. Vanilla rotation leaks: _vanilla.lua files containing dangerous IDs
--      that could cause silent mis-casts
--
-- Sources: lexxer.org API (TBC + Vanilla), spell_id_table_sylvanas.lua
-- ============================================================================

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_false(v, label)
    if v then error(label or "assert_false failed", 2) end
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function contains(data, text)
    return data and data:find(text, 1, true) ~= nil
end

local function file_exists(path)
    local f = io.open(path, "rb")
    if not f then return false end
    f:close()
    return true
end

-- Glob for all *_vanilla.lua files under EaxRotations/classes/
-- Portable: tries lfs first, then os.execute with platform-aware fallback.
local KNOWN_VANILLA_FILES = {
    "EaxRotations/classes/druid/balance_vanilla.lua",
    "EaxRotations/classes/druid/bear_vanilla.lua",
    "EaxRotations/classes/druid/caster_vanilla.lua",
    "EaxRotations/classes/druid/cat_vanilla.lua",
    "EaxRotations/classes/druid/leveling_vanilla.lua",
    "EaxRotations/classes/druid/resto_vanilla.lua",
    "EaxRotations/classes/hunter/beast_mastery_vanilla.lua",
    "EaxRotations/classes/hunter/leveling_vanilla.lua",
    "EaxRotations/classes/hunter/marksmanship_vanilla.lua",
    "EaxRotations/classes/hunter/survival_vanilla.lua",
    "EaxRotations/classes/mage/arcane_vanilla.lua",
    "EaxRotations/classes/mage/fire_vanilla.lua",
    "EaxRotations/classes/mage/frost_vanilla.lua",
    "EaxRotations/classes/mage/leveling_vanilla.lua",
    "EaxRotations/classes/paladin/holy_vanilla.lua",
    "EaxRotations/classes/paladin/leveling_vanilla.lua",
    "EaxRotations/classes/paladin/protection_vanilla.lua",
    "EaxRotations/classes/paladin/retribution_vanilla.lua",
    "EaxRotations/classes/priest/discipline_vanilla.lua",
    "EaxRotations/classes/priest/holy_vanilla.lua",
    "EaxRotations/classes/priest/leveling_vanilla.lua",
    "EaxRotations/classes/priest/shadow_vanilla.lua",
    "EaxRotations/classes/priest/smite_vanilla.lua",
    "EaxRotations/classes/rogue/assassination_vanilla.lua",
    "EaxRotations/classes/rogue/combat_vanilla.lua",
    "EaxRotations/classes/rogue/leveling_vanilla.lua",
    "EaxRotations/classes/rogue/subtlety_vanilla.lua",
    "EaxRotations/classes/shaman/elemental_vanilla.lua",
    "EaxRotations/classes/shaman/enhancement_vanilla.lua",
    "EaxRotations/classes/shaman/leveling_vanilla.lua",
    "EaxRotations/classes/shaman/restoration_vanilla.lua",
    "EaxRotations/classes/warlock/affliction_vanilla.lua",
    "EaxRotations/classes/warlock/demonology_vanilla.lua",
    "EaxRotations/classes/warlock/destruction_vanilla.lua",
    "EaxRotations/classes/warlock/leveling_vanilla.lua",
    "EaxRotations/classes/warrior/arms_vanilla.lua",
    "EaxRotations/classes/warrior/fury_vanilla.lua",
    "EaxRotations/classes/warrior/kebab_vanilla.lua",
    "EaxRotations/classes/warrior/leveling_vanilla.lua",
    "EaxRotations/classes/warrior/protection_vanilla.lua",
}

local function find_vanilla_files()
    -- Try lfs (LuaFileSystem) first for dynamic discovery
    local ok, lfs = pcall(require, "lfs")
    if ok and lfs then
        local files = {}
        local function walk(dir)
            for entry in lfs.dir(dir) do
                if entry ~= "." and entry ~= ".." then
                    local p = dir .. "/" .. entry
                    local mode = lfs.attributes(p, "mode")
                    if mode == "directory" then
                        walk(p)
                    elseif mode == "file" and entry:match("_vanilla%.lua$") then
                        files[#files + 1] = p
                    end
                end
            end
        end
        local ok2 = pcall(walk, "EaxRotations/classes")
        if ok2 and #files > 0 then return files end
    end
    -- Fallback: hardcoded list (regenerate with: find EaxRotations/classes -name "*_vanilla.lua" | sort)
    local files = {}
    for i = 1, #KNOWN_VANILLA_FILES do
        local f = io.open(KNOWN_VANILLA_FILES[i], "rb")
        if f then
            f:close()
            files[#files + 1] = KNOWN_VANILLA_FILES[i]
        end
    end
    return files
end

-- ============================================================================
-- 1. Verify spell_id_table covers all known swapped spells
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

-- Mock NS for TBC
_G.EaxRotations = {
    is_vanilla = function() return false end,
    is_tbc = function() return true end,
}

local spell_table = dofile("EaxRotations/shared/spell_id_table_sylvanas.lua")
assert_true(spell_table, "spell_id_table should load")

-- All known cross-expansion swapped spells MUST be in the table
local REQUIRED_SWAPPED = {
    { name = "Arcane Missiles",  tbc = 8418,  vanilla = 8417 },
    { name = "Cold Snap",        tbc = 11958, vanilla = 12472 },
    { name = "Death Wish",       tbc = 12292, vanilla = 12328 },
    { name = "Sweeping Strikes", tbc = 12328, vanilla = 12292 },
}

for _, req in ipairs(REQUIRED_SWAPPED) do
    assert_true(spell_table.is_swapped(req.name), req.name .. " must be in spell_id_table")
    assert_true(spell_table.tbc_id(req.name) == req.tbc, req.name .. " TBC ID mismatch")
    assert_true(spell_table.vanilla_id(req.name) == req.vanilla, req.name .. " Vanilla ID mismatch")
end

-- Known TBC-only spells with cross-expansion ID reuse conflicts
local REQUIRED_REUSE = {
    { name = "Icy Veins", tbc = 12472, note = "TBC=12472 is Cold Snap in Vanilla" },
}

for _, req in ipairs(REQUIRED_REUSE) do
    assert_true(spell_table.is_swapped(req.name), req.name .. " must be in spell_id_table (ID reuse)")
    assert_true(spell_table.tbc_id(req.name) == req.tbc, req.name .. " TBC ID mismatch")
    -- resolve() should return the TBC ID
    spell_table._reset_expansion()
    assert_true(spell_table.resolve(req.name) == req.tbc, req.name .. " should resolve to TBC ID")
    -- On Vanilla, resolve() should return nil (TBC-only spell)
    _G.EaxRotations.is_vanilla = function() return true end
    spell_table._reset_expansion()
    assert_true(spell_table.resolve(req.name) == nil, req.name .. " should resolve to nil on Vanilla")
    _G.EaxRotations.is_vanilla = function() return false end
    spell_table._reset_expansion()
end

-- ============================================================================
-- 2. Vanilla rotation files must not contain cross-expansion dangerous IDs.
--    These are IDs that mean DIFFERENT things in TBC vs Vanilla.
--    If a _vanilla.lua file contains one of these, it could cause a mis-cast.
-- ============================================================================

local CROSS_EXPANSION_DANGEROUS_IDS = {
    -- ID 12472: Icy Veins (TBC-only) = Cold Snap (Vanilla)
    -- A vanilla rotation file should NEVER reference Icy Veins (TBC talent).
    -- If 12472 appears, it means Cold Snap (correct) or is a TBC leak.
    -- We flag it because vanilla files should use the spell name, not this ID.
    { id = 12472, tbc_spell = "Icy Veins",  vanilla_spell = "Cold Snap" },
    -- ID 11958: Cold Snap (TBC) = Ice Block (Vanilla)
    -- 11958 means Cold Snap in TBC but Ice Block in Vanilla.
    -- A vanilla file using 11958 might intend Ice Block (correct) or
    -- accidentally use the TBC Cold Snap ID (wrong). Flag as suspicious.
    { id = 11958, tbc_spell = "Cold Snap",  vanilla_spell = "Ice Block" },
}

-- Note: IDs 12292 and 12328 (Death Wish / Sweeping Strikes swap) are NOT
-- flagged here because both are valid in Vanilla:
--   12292 = Sweeping Strikes (Vanilla), Death Wish (TBC)
--   12328 = Death Wish (Vanilla), Sweeping Strikes (TBC)
-- Vanilla files SHOULD use these IDs for their correct Vanilla spells.
-- The warrior _vanilla.lua fixes (SWEEPING_STRIKES_BUFF 12328→12292) were
-- caught by checking buff ID correctness, not by generic ID scanning.

-- Glob for all vanilla files dynamically
local vanilla_files = find_vanilla_files()
assert_true(#vanilla_files > 0, "Should find at least 1 *_vanilla.lua file under EaxRotations/classes/")

for _, path in ipairs(vanilla_files) do
    local data = read_file(path)
    if data then
        for _, danger in ipairs(CROSS_EXPANSION_DANGEROUS_IDS) do
            local id_str = tostring(danger.id)
            -- Check each line for the dangerous ID outside of comments
            for line in data:gmatch("[^\r\n]+") do
                -- Strip the comment portion of the line
                local code_part = line:match("^([^%-]*)") or line
                -- Handle -- inside strings is rare in our codebase; simple approach works
                if code_part:find(id_str, 1, true) then
                    -- Verify it's a standalone number (not part of a larger number)
                    local pos = code_part:find(id_str, 1, true)
                    local before = pos > 1 and code_part:sub(pos - 1, pos - 1) or ""
                    local after_pos = pos + #id_str
                    local after = after_pos <= #code_part and code_part:sub(after_pos, after_pos) or ""
                    local is_standalone = (before == "" or not before:match("%d")) and
                                          (after == "" or not after:match("%d"))
                    if is_standalone then
                        assert_false(true,
                            path .. " contains cross-expansion dangerous ID " .. danger.id ..
                            " (" .. danger.tbc_spell .. " in TBC, " .. danger.vanilla_spell .. " in Vanilla)")
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 3. Cross-expansion ID consistency: class files with swapped spells must
--    use spell_id_table.resolve() for expansion-aware resolution
-- ============================================================================

local function assert_requires_spell_table(path)
    local data = read_file(path)
    assert_true(data ~= nil, "Cannot read " .. path)
    assert_true(contains(data, "spell_id_table"),
        path .. " should require spell_id_table for expansion-aware spell resolution")
end

assert_requires_spell_table("EaxRotations/classes/mage/class_sylvanas.lua")
assert_requires_spell_table("EaxRotations/classes/warrior/class_sylvanas.lua")

-- Verify specific resolve() calls
local mage_class = read_file("EaxRotations/classes/mage/class_sylvanas.lua")
assert_true(contains(mage_class, 'spell_id_table.resolve("Cold Snap")'),
    "Mage class should use spell_id_table.resolve for Cold Snap")

local warrior_class = read_file("EaxRotations/classes/warrior/class_sylvanas.lua")
assert_true(contains(warrior_class, 'spell_id_table.resolve("Death Wish")'),
    "Warrior class should use spell_id_table.resolve for Death Wish")
assert_true(contains(warrior_class, 'spell_id_table.resolve("Sweeping Strikes")'),
    "Warrior class should use spell_id_table.resolve for Sweeping Strikes")

print("PASS test_cross_expansion_spell_validation (5 swapped/reuse entries verified, " .. #vanilla_files .. " vanilla files scanned)")
