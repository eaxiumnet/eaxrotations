-- run_vanilla_existence_audit.lua -- Audit _vanilla.lua files for spell IDs that do not exist in Vanilla data.
-- WHAT:  Scans vanilla rotation files for spell IDs absent from the Vanilla spell/item index.
-- WHEN:  Run manually or in CI before releases.
-- WHY:   The existing vanilla audit only detects TBC contamination; this catches invalid Vanilla IDs too.
-- SAFETY: Read-only text scan + bridge lookup. No dofile(), no io writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local vanilla_bridge_ok, vanilla_bridge = pcall(require, "shared/wowhead_data_bridge_spell_index_vanilla_sylvanas")
local tbc_bridge_ok, tbc_bridge = pcall(require, "shared/wowhead_data_bridge_sylvanas")

if not vanilla_bridge_ok and not tbc_bridge_ok then
    print("[ERROR] Could not load any spell index bridge")
    os.exit(2)
end

local vanilla_index = (vanilla_bridge_ok and vanilla_bridge.spell_index_vanilla) or {}
local tbc_index = (tbc_bridge_ok and tbc_bridge.spell_index_tbc) or {}
local item_index = (tbc_bridge_ok and tbc_bridge.item_index) or {}

local valid_spell_ids = {}
for id in pairs(vanilla_index) do
    valid_spell_ids[id] = true
end
for id in pairs(tbc_index) do
    valid_spell_ids[id] = true
end

local valid_item_ids = {}
for id in pairs(item_index) do
    valid_item_ids[id] = true
end

local root = "EaxRotations"

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a") or ""
    f:close()
    return content
end

local function extract_ids_from_line(line)
    local ids = {}

    local function collect(block)
        if not block then return end
        if block:find("=") then return end
        for n in block:gmatch("(%d+)") do
            local v = tonumber(n)
            if v >= 1000 and v <= 99999 then
                ids[#ids + 1] = v
            end
        end
    end

    -- Pattern 1: define("Name", { ids }, ...) or define("Name", id, "...")
    local pos = 1
    while true do
        local start_idx = line:find("define%s*(", pos, true)
        if not start_idx then break end
        local depth = 1
        local i = start_idx + 7
        local arg_start = nil
        local arg_end = nil
        local in_string = false
        local string_char = nil
        while i <= #line and depth > 0 do
            local c = line:sub(i, i)
            if in_string then
                if c == "\\" then
                    i = i + 1
                elseif c == string_char then
                    in_string = false
                end
            elseif c == '"' or c == "'" then
                in_string = true
                string_char = c
            elseif c == "(" then
                if depth == 1 and not arg_start then
                    arg_start = i + 1
                end
                depth = depth + 1
            elseif c == ")" then
                depth = depth - 1
                if depth == 0 then
                    arg_end = i - 1
                    break
                end
            elseif c == "," and depth == 1 and arg_start and not arg_end then
                arg_start = i + 1
            end
            i = i + 1
        end
        if arg_start and arg_end then
            local second_arg = line:sub(arg_start, arg_end)
            local table_part = second_arg:match("(%b{})")
            if table_part then
                collect(table_part:sub(2, -2))
            else
                local num = second_arg:match("^%s*(%d+)%s*$")
                if num then
                    local v = tonumber(num)
                    if v and v >= 1000 and v <= 99999 then
                        ids[#ids + 1] = v
                    end
                end
            end
        end
        pos = (arg_end or start_idx) + 1
    end

    -- Pattern 2: pure numeric table literals like { 123, 456 }
    for table_part in line:gmatch("(%b{})") do
        local inner = table_part:sub(2, -2)
        if inner:match("^[%s,,%d]*$") then
            collect(inner)
        end
    end

    return ids
end

local function is_comment_line(line)
    return line:match("^%s*%-%-") ~= nil
end

local function scan_file(filepath)
    if not file_exists(filepath) then
        return { skipped = true, hits = {} }
    end
    local content = read_file(filepath)
    if not content then
        return { error = "could not read", hits = {} }
    end

    local hits = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if not is_comment_line(line) then
            local ids = extract_ids_from_line(line)
            for _, id in ipairs(ids) do
                if not valid_spell_ids[id] and not valid_item_ids[id] then
                    hits[#hits + 1] = {
                        line = line_no,
                        id = id,
                        kind = "INVALID",
                        snippet = (line:match("^%s*(.-)%s*$") or line):sub(1, 100),
                    }
                end
            end
        end
    end

    return { found = #hits > 0, hits = hits }
end

print("=============================================================================")
print("  VANILLA SPELL ID EXISTENCE AUDIT")
print("  Source: wowhead_data_bridge_spell_index_vanilla_sylvanas")
print("=============================================================================")
print("")

local VANILLA_FILES = {}
for _, class in ipairs({
    "druid", "hunter", "mage", "paladin", "priest",
    "rogue", "shaman", "warlock", "warrior",
}) do
    for _, suffix in ipairs({
        "balance", "bear", "cat", "caster", "resto",
        "beast_mastery", "marksmanship", "survival",
        "arcane", "fire", "frost",
        "holy", "protection", "retribution",
        "discipline", "shadow", "smite",
        "assassination", "combat", "subtlety",
        "elemental", "enhancement", "restoration",
        "affliction", "demonology", "destruction",
        "arms", "fury", "kebab", "leveling",
    }) do
        VANILLA_FILES[#VANILLA_FILES + 1] = "classes/" .. class .. "/" .. suffix .. "_vanilla.lua"
    end
end

local total, skipped, passed, failed = 0, 0, 0, 0
local failures = {}

for _, file in ipairs(VANILLA_FILES) do
    local path = root .. "/" .. file
    total = total + 1

    local result = scan_file(path)
    if result.skipped then
        skipped = skipped + 1
    elseif result.error then
        failed = failed + 1
        failures[#failures + 1] = { file = file, error = result.error }
        print(string.format("  [ ERROR ] %-50s %s", file, result.error))
    elseif result.found then
        failed = failed + 1
        failures[#failures + 1] = { file = file, hits = result.hits }
        print(string.format("  [ FAIL ]  %-50s %d invalid ID(s)", file, #result.hits))
        for _, hit in ipairs(result.hits) do
            print(string.format("            line %4d: id %d [%s]  %s",
                hit.line, hit.id, hit.kind, hit.snippet))
        end
    else
        passed = passed + 1
        print(string.format("  [ PASS ]  %-50s clean", file))
    end
end

print("")
print("=============================================================================")
print("  VANILLA SPELL EXISTENCE AUDIT RESULTS")
print("=============================================================================")
print(string.format("  Total:     %3d vanilla files", total))
print(string.format("  Skipped:   %3d (file not present)", skipped))
print(string.format("  Clean:     %3d", passed))
print(string.format("  Invalid:   %3d", failed))
print("")

if failed > 0 then
    print("  Invalid spell IDs found in vanilla files:")
    for _, f in ipairs(failures) do
        if f.error then
            print("    " .. f.file .. "  ERROR: " .. f.error)
        else
            for _, hit in ipairs(f.hits) do
                print(string.format("    %s  line %d: id %d [%s]",
                    f.file, hit.line, hit.id, hit.kind))
            end
        end
    end
    print("")
    print("  ID 'ITEM_AS_SPELL' means the ID exists in item_index but not spell_index.")
    print("  ID 'INVALID' means the ID exists in neither — definitely a bug.")
    os.exit(1)
end

print("  All vanilla files clean — every spell ID exists in Vanilla data.")
os.exit(0)
