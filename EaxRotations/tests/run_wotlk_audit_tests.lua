-- run_wotlk_audit_tests.lua -- Audit _wotlk.lua rotation files for invalid spell IDs.
-- WHAT:  Scans WotLK rotation files for IDs that are neither indexed nor verified aliases.
-- WHEN:  Run manually or in CI before releases.
-- WHY:   The generated bridge omits rank and aura aliases, so absence alone is not invalidity.
-- SAFETY: Read-only text scan + static classification; --self-test has no filesystem writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local bridge_ok, bridge = pcall(require, "shared/wowhead_data_bridge_spell_index_wotlk_sylvanas")
if not bridge_ok or not bridge then
    print("[ERROR] Could not load wowhead_data_bridge_spell_index_wotlk_sylvanas")
    print("        Run: python build_tools/fetch_lexxer_wotlk.py")
    os.exit(2)
end

local tbc_bridge_ok, tbc_bridge = pcall(require, "shared/wowhead_data_bridge_sylvanas")
local vanilla_bridge_ok, vanilla_bridge = pcall(require, "shared/wowhead_data_bridge_spell_index_vanilla_sylvanas")

local wotlk_index = bridge.spell_index_wotlk or {}
local tbc_index = (tbc_bridge_ok and tbc_bridge.spell_index_tbc) or {}
local vanilla_index = (vanilla_bridge_ok and vanilla_bridge.spell_index_vanilla) or {}

local valid_wotlk_ids = {}
for id in pairs(wotlk_index) do
    valid_wotlk_ids[id] = true
end

local valid_tbc_ids = {}
for id in pairs(tbc_index) do
    valid_tbc_ids[id] = true
end

local valid_vanilla_ids = {}
for id in pairs(vanilla_index) do
    valid_vanilla_ids[id] = true
end

local WOTLK_REFERENCE_SHA = "563e4a08cb15729f1fdcbcf68e6d68224553bfef"
local WOTLK_REFERENCE_ALIASES = {
    [27011] = { kind = "VALID_RANK_ALIAS", family = "Feral Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [17392] = { kind = "VALID_RANK_ALIAS", family = "Feral Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [17391] = { kind = "VALID_RANK_ALIAS", family = "Feral Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [17390] = { kind = "VALID_RANK_ALIAS", family = "Feral Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [26993] = { kind = "VALID_RANK_ALIAS", family = "Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [9907] = { kind = "VALID_RANK_ALIAS", family = "Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [9749] = { kind = "VALID_RANK_ALIAS", family = "Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [13544] = { kind = "VALID_RANK_ALIAS", family = "Mend Pet", source = "sim/hunter/pet_abilities.go pet surface" },
    [3662] = { kind = "VALID_RANK_ALIAS", family = "Mend Pet", source = "sim/hunter/pet_abilities.go pet surface" },
    [3661] = { kind = "VALID_RANK_ALIAS", family = "Mend Pet", source = "sim/hunter/pet_abilities.go pet surface" },
    [38692] = { kind = "VALID_RANK_ALIAS", family = "Fireball", source = "sim/mage/fireball.go" },
    [55360] = { kind = "VALID_BRIDGE_GAP", family = "Living Bomb", source = "sim/mage/living_bomb.go" },
    [42873] = { kind = "VALID_BRIDGE_GAP", family = "Fire Blast", source = "sim/mage/fire_blast.go" },
    [44448] = { kind = "VALID_AURA_ALIAS", family = "Hot Streak", source = "sim/mage/talents.go" },
    [12873] = { kind = "VALID_AURA_ALIAS", family = "Scorch", source = "sim/core/debuffs.go" },
    [19940] = { kind = "VALID_RANK_ALIAS", family = "Flash of Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [19939] = { kind = "VALID_RANK_ALIAS", family = "Flash of Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [25292] = { kind = "VALID_RANK_ALIAS", family = "Holy Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [10329] = { kind = "VALID_RANK_ALIAS", family = "Holy Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [10328] = { kind = "VALID_RANK_ALIAS", family = "Holy Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [3472] = { kind = "VALID_RANK_ALIAS", family = "Holy Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [32700] = { kind = "VALID_RANK_ALIAS", family = "Avenger's Shield", source = "sim/paladin/avengers_shield.go" },
    [32699] = { kind = "VALID_RANK_ALIAS", family = "Avenger's Shield", source = "sim/paladin/avengers_shield.go" },
    [31935] = { kind = "VALID_RANK_ALIAS", family = "Avenger's Shield", source = "sim/paladin/avengers_shield.go" },
    [61411] = { kind = "VALID_BRIDGE_GAP", family = "Shield of Righteousness", source = "sim/paladin/shield_of_righteousness.go" },
    [27170] = { kind = "VALID_RANK_ALIAS", family = "Seal of Command", source = "sim/paladin/seals.go" },
    [20920] = { kind = "VALID_RANK_ALIAS", family = "Seal of Command", source = "sim/paladin/seals.go" },
    [20919] = { kind = "VALID_RANK_ALIAS", family = "Seal of Command", source = "sim/paladin/seals.go" },
    [20918] = { kind = "VALID_RANK_ALIAS", family = "Seal of Command", source = "sim/paladin/seals.go" },
    [20915] = { kind = "VALID_RANK_ALIAS", family = "Seal of Command", source = "sim/paladin/seals.go" },
    [25533] = { kind = "VALID_RANK_ALIAS", family = "Searing Totem", source = "sim/shaman/fire_totems.go" },
    [6365] = { kind = "VALID_RANK_ALIAS", family = "Searing Totem", source = "sim/shaman/fire_totems.go" },
    [6364] = { kind = "VALID_RANK_ALIAS", family = "Searing Totem", source = "sim/shaman/fire_totems.go" },
    [30912] = { kind = "VALID_RANK_ALIAS", family = "Conflagrate", source = "sim/warlock/conflagrate.go" },
    [27266] = { kind = "VALID_RANK_ALIAS", family = "Conflagrate", source = "sim/warlock/conflagrate.go" },
    [18932] = { kind = "VALID_RANK_ALIAS", family = "Conflagrate", source = "sim/warlock/conflagrate.go" },
    [18931] = { kind = "VALID_RANK_ALIAS", family = "Conflagrate", source = "sim/warlock/conflagrate.go" },
    [18930] = { kind = "VALID_RANK_ALIAS", family = "Conflagrate", source = "sim/warlock/conflagrate.go" },
    [49045] = { kind = "VALID_BRIDGE_GAP", family = "Arcane Shot", source = "sim/hunter/arcane_shot.go" },
    [49050] = { kind = "VALID_BRIDGE_GAP", family = "Aimed Shot", source = "sim/hunter/aimed_shot.go" },
    [49052] = { kind = "VALID_BRIDGE_GAP", family = "Steady Shot", source = "sim/hunter/steady_shot.go" },
    [49067] = { kind = "VALID_BRIDGE_GAP", family = "Explosive Trap", source = "sim/hunter/explosive_trap.go + local DBC rank family" },
    [49284] = { kind = "VALID_BRIDGE_GAP", family = "Earth Shield", source = "sim/shaman/heals.go" },
    [2894] = { kind = "VALID_BRIDGE_GAP", family = "Fire Elemental Totem", source = "sim/shaman/fire_elemental_totem.go + ui/elemental_shaman/apls/default.apl.json" },
    [57722] = { kind = "VALID_BRIDGE_GAP", family = "Totem of Wrath", source = "sim/shaman/totems.go + ui/elemental_shaman/apls/default.apl.json" },
}

local WOTLK_UNVERIFIED_ALIASES = {
    [48785] = { kind = "UNVERIFIED_ALIAS", family = "Flash of Light", source = "no direct pinned ID or local rank-data proof" },
    [48782] = { kind = "UNVERIFIED_ALIAS", family = "Holy Light", source = "no direct pinned ID or local rank-data proof" },
    [48999] = { kind = "UNVERIFIED_ALIAS", family = "Avenger's Shield", source = "no direct pinned ID or local rank-data proof" },
    [48826] = { kind = "UNVERIFIED_ALIAS", family = "Avenger's Shield", source = "no direct pinned ID or local rank-data proof" },
}

local WOTLK_REJECTED_IDS = {
    [44459] = true,
}

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
    if type(line) ~= "string" then return ids end

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
    -- Scan the whole line for define calls and pull the second argument.
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
                -- End of first argument, skip to second argument.
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

    -- Pattern 2: pure numeric table literals like { 123, 456 } — common for spell/buff/debuff lists.
    for table_part in line:gmatch("(%b{})") do
        local inner = table_part:sub(2, -2)
        -- Only collect if the table contains only numbers, commas, and whitespace.
        if inner:match("^[%s,,%d]*$") then
            collect(inner)
        end
    end

    return ids
end

local function classify_id(id)
    if valid_wotlk_ids[id] then return nil end

    local alias = WOTLK_REFERENCE_ALIASES[id]
    if alias then return alias.kind, alias.family end
    local unverified = WOTLK_UNVERIFIED_ALIASES[id]
    if unverified then return unverified.kind, unverified.family end
    if WOTLK_REJECTED_IDS[id] then return "INVALID" end
    if valid_tbc_ids[id] then return "TBC_ID_IN_WOTLK" end
    if valid_vanilla_ids[id] then return "VANILLA_ID_IN_WOTLK" end
    return "INVALID"
end

local function is_comment_line(line)
    return line:match("^%s*%-%-") ~= nil
end

local function scan_content(content)
    if type(content) ~= "string" then
        return { error = "content must be a string", hits = {} }
    end
    local hits = {}
    local unverified = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if not is_comment_line(line) then
            local ids = extract_ids_from_line(line)
            for _, id in ipairs(ids) do
                local kind, family = classify_id(id)
                local hit = {
                    line = line_no,
                    id = id,
                    kind = kind,
                    family = family,
                    snippet = (line:match("^%s*(.-)%s*$") or line):sub(1, 100),
                }
                if kind == "INVALID" or kind == "TBC_ID_IN_WOTLK" or kind == "VANILLA_ID_IN_WOTLK" then
                    hits[#hits + 1] = hit
                elseif kind == "UNVERIFIED_ALIAS" then
                    unverified[#unverified + 1] = hit
                end
            end
        end
    end

    return { found = #hits > 0, hits = hits, unverified = unverified }
end

local function scan_file(filepath)
    if not file_exists(filepath) then
        return { skipped = true, hits = {}, unverified = {} }
    end
    local content = read_file(filepath)
    if not content then
        return { error = "could not read", hits = {}, unverified = {} }
    end
    return scan_content(content)
end

local WOTLK_FILES = {
    "classes/deathknight/blood_wotlk.lua",
    "classes/deathknight/frost_wotlk.lua",
    "classes/deathknight/leveling_wotlk.lua",
    "classes/deathknight/unholy_wotlk.lua",
    "classes/druid/balance_wotlk.lua",
    "classes/druid/bear_wotlk.lua",
    "classes/druid/cat_wotlk.lua",
    "classes/druid/leveling_wotlk.lua",
    "classes/druid/resto_wotlk.lua",
    "classes/hunter/beast_mastery_wotlk.lua",
    "classes/hunter/leveling_wotlk.lua",
    "classes/hunter/marksmanship_wotlk.lua",
    "classes/hunter/survival_wotlk.lua",
    "classes/mage/arcane_wotlk.lua",
    "classes/mage/fire_wotlk.lua",
    "classes/mage/frost_wotlk.lua",
    "classes/mage/leveling_wotlk.lua",
    "classes/paladin/holy_wotlk.lua",
    "classes/paladin/leveling_wotlk.lua",
    "classes/paladin/protection_wotlk.lua",
    "classes/paladin/retribution_wotlk.lua",
    "classes/priest/discipline_wotlk.lua",
    "classes/priest/holy_wotlk.lua",
    "classes/priest/leveling_wotlk.lua",
    "classes/priest/shadow_wotlk.lua",
    "classes/rogue/assassination_wotlk.lua",
    "classes/rogue/combat_wotlk.lua",
    "classes/rogue/leveling_wotlk.lua",
    "classes/rogue/subtlety_wotlk.lua",
    "classes/shaman/elemental_wotlk.lua",
    "classes/shaman/enhancement_wotlk.lua",
    "classes/shaman/leveling_wotlk.lua",
    "classes/shaman/restoration_wotlk.lua",
    "classes/warlock/affliction_wotlk.lua",
    "classes/warlock/demonology_wotlk.lua",
    "classes/warlock/destruction_wotlk.lua",
    "classes/warlock/leveling_wotlk.lua",
    "classes/warrior/arms_wotlk.lua",
    "classes/warrior/fury_wotlk.lua",
    "classes/warrior/leveling_wotlk.lua",
    "classes/warrior/protection_wotlk.lua",
}

local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    expect(#extract_ids_from_line(nil), 0, "malformed nil line")
    expect(scan_content(nil).error, "content must be a string", "malformed content")
    expect(scan_file("__missing_wotlk_audit_fixture__.lua").skipped, true, "missing fixture")

    local function map_count(map)
        local count = 0
        for _ in pairs(map) do count = count + 1 end
        return count
    end

    local kind, family = classify_id(61411)
    expect(kind, "VALID_BRIDGE_GAP", "pinned bridge gap")
    expect(family, "Shield of Righteousness", "bridge gap family")
    expect(classify_id(27011), "VALID_RANK_ALIAS", "rank alias")
    expect(classify_id(44448), "VALID_AURA_ALIAS", "pinned aura alias")
    expect(classify_id(49045), "VALID_BRIDGE_GAP", "pinned Arcane Shot ID")
    expect(classify_id(49050), "VALID_BRIDGE_GAP", "pinned Aimed Shot ID")
    expect(classify_id(49052), "VALID_BRIDGE_GAP", "pinned Steady Shot ID")
    expect(classify_id(49067), "VALID_BRIDGE_GAP", "pinned Explosive Trap ID")
    expect(classify_id(49284), "VALID_BRIDGE_GAP", "pinned Earth Shield ID")
    expect(classify_id(2894), "VALID_BRIDGE_GAP", "pinned Fire Elemental Totem ID")
    expect(classify_id(57722), "VALID_BRIDGE_GAP", "pinned Totem of Wrath ID")
    expect(classify_id(48782), "UNVERIFIED_ALIAS", "unverified alias is separate")
    expect(classify_id(44459), "INVALID", "disproven Living Bomb alias")
    expect(classify_id(99999), "INVALID", "negative unknown ID")

    local result = scan_content and scan_content('define("Probe", { 61411, 27011, 48782, 44459, 99999 }, "Probe")')
    expect(result and #result.hits, 2, "negative scan hit count")
    expect(result.hits[1].id, 44459, "disproven alias scan ID")
    expect(result.hits[2].id, 99999, "negative scan ID")
    expect(result and #result.unverified, 1, "unverified scan count")
    expect(result.unverified[1].id, 48782, "unverified scan ID")

    expect(map_count(WOTLK_REFERENCE_ALIASES), 45, "pinned allowlist size")
    expect(map_count(WOTLK_UNVERIFIED_ALIASES), 4, "unverified alias size")
    expect(WOTLK_REFERENCE_ALIASES[44459], nil, "disproven ID absent from allowlist")
    expect(#WOTLK_FILES, 41, "WotLK inventory size")
    local seen = {}
    for _, file in ipairs(WOTLK_FILES) do
        expect(seen[file], nil, "duplicate inventory entry")
        seen[file] = true
    end
    print("[PASS] WotLK audit self-tests: malformed input, pinned allowlist, unverified separation, negative IDs, 41-file inventory")
end

local function run_invalid_probe()
    local result = scan_content('define("InvalidProbe", { 44459, 99999 }, "InvalidProbe")')
    if result.error or not result.found then
        print("[ERROR] invalid-ID probe did not produce a rejection")
        os.exit(2)
    end
    print("[FAIL] invalid-ID probe rejected as expected")
    os.exit(1)
end

local function run_missing_probe()
    local result = scan_file("__missing_wotlk_audit_fixture__.lua")
    if not result.skipped then
        print("[ERROR] missing-file probe did not report skipped input")
        os.exit(2)
    end
    print("[FAIL] missing-file probe rejected as expected")
    os.exit(1)
end

local function run_unverified_probe()
    local result = scan_content('define("UnverifiedProbe", { 48782 }, "UnverifiedProbe")')
    if result.error or not result.unverified or #result.unverified ~= 1 then
        print("[ERROR] unverified-alias probe did not observe exactly one unverified alias")
        os.exit(2)
    end
    local hit = result.unverified[1]
    if hit.id ~= 48782 or hit.kind ~= "UNVERIFIED_ALIAS" then
        print("[ERROR] unverified-alias probe observed the wrong classification")
        os.exit(2)
    end
    print("[FAIL] unverified-alias probe rejected as expected: id 48782 [UNVERIFIED_ALIAS]")
    os.exit(1)
end

local function run_malformed_probe()
    local result = scan_content(nil)
    if result.error ~= "content must be a string" then
        print("[ERROR] malformed probe was not controlled")
        os.exit(2)
    end
    print("[PASS] malformed probe returned a controlled error")
    os.exit(0)
end

if arg and arg[1] == "--self-test" then
    run_self_tests()
    os.exit(0)
elseif arg and arg[1] == "--probe-invalid" then
    run_invalid_probe()
elseif arg and arg[1] == "--probe-missing" then
    run_missing_probe()
elseif arg and arg[1] == "--probe-unverified" then
    run_unverified_probe()
elseif arg and arg[1] == "--probe-malformed" then
    run_malformed_probe()
end

print("=============================================================================")
print("  WOTLK SPELL ID AUDIT (bridge + pinned semantic aliases)")
print("  Reference: wowsims/wotlk@" .. WOTLK_REFERENCE_SHA)
print("  Bridge: " .. tostring(require("shared/wowhead_data_bridge_spell_index_wotlk_sylvanas").spell_index_wotlk and "loaded" or "missing"))
print("=============================================================================")
print("")

local total, skipped, passed, failed, unverified_total = 0, 0, 0, 0, 0
local failures = {}

for _, file in ipairs(WOTLK_FILES) do
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
    if result.unverified and #result.unverified > 0 then
        unverified_total = unverified_total + #result.unverified
        print(string.format("  [ WARN ]  %-50s %d unverified alias(es)", file, #result.unverified))
        for _, hit in ipairs(result.unverified) do
            print(string.format("            line %4d: id %d [%s]  %s",
                hit.line, hit.id, hit.kind, hit.snippet))
        end
    end
end

print("")
print("=============================================================================")
print("  WOTLK SPELL AUDIT RESULTS")
print("=============================================================================")
print(string.format("  Total:     %3d wotlk files", total))
print(string.format("  Skipped:   %3d (file not present)", skipped))
print(string.format("  Clean:     %3d", passed))
print(string.format("  Invalid:   %3d", failed))
print(string.format("  Unverified:%3d IDs (reported separately; not allowlisted)", unverified_total))
print("")

if failed > 0 or skipped > 0 then
    print("  Invalid spell IDs found in wotlk files:")
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
    print("  ID 'TBC_ID_IN_WOTLK' means the ID exists in TBC data but not WotLK.")
    print("  ID 'VANILLA_ID_IN_WOTLK' means the ID exists in Vanilla data but not WotLK.")
    print("  VALID_RANK_ALIAS, VALID_AURA_ALIAS, and VALID_BRIDGE_GAP IDs are accepted only from the pinned reference table.")
    print("  UNVERIFIED_ALIAS IDs are reported separately and are not part of the valid allowlist.")
    print("  ID 'INVALID' means no WotLK bridge or pinned alias classification exists.")
    os.exit(1)
end

print("  All 41 WotLK files accounted for; unknown IDs are the only audit failures.")
os.exit(0)
