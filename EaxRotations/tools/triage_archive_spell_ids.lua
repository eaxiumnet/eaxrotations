-- ============================================================================
-- Build-only audit tool: triages archive vs current spell IDs.
-- ============================================================================
-- What: Compares old archive spell lists against current implementation
-- When: Run manually during migration reviews; NOT loaded by runtime
-- Why: Prevents accidental reversion of corrected spell IDs
-- Safety: Requires network and curl; runs in isolated build context only
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local BUILD = "2.5.4.42940"
local UA = "Codex-EAX-Archive-Triage/1.0"
local archive_root = "archive_original_specs"
local current_root = "EaxRotations"
local report_path = "EaxRotations/docs/ARCHIVE_TRIAGE.md"

local specs = {
    { archive = "EAXDruidBalance", class = "druid", spec = "balance" },
    { archive = "EAXDruidFeral", class = "druid", spec = "cat" },
    { archive = "EAXDruidRestoration", class = "druid", spec = "resto" },
    { archive = "EAXHunterBeastMastery", class = "hunter", spec = "beast_mastery" },
    { archive = "EAXHunterMarksmanship", class = "hunter", spec = "marksmanship" },
    { archive = "EAXHunterSurvival", class = "hunter", spec = "survival" },
    { archive = "EAXMageArcane", class = "mage", spec = "arcane" },
    { archive = "EAXMageFire", class = "mage", spec = "fire" },
    { archive = "EAXMageFrost", class = "mage", spec = "frost" },
    { archive = "EAXPaladinHoly", class = "paladin", spec = "holy" },
    { archive = "EAXPaladinProtection", class = "paladin", spec = "protection" },
    { archive = "EAXPaladinRetribution", class = "paladin", spec = "retribution" },
    { archive = "EAXPriestDiscipline", class = "priest", spec = "discipline" },
    { archive = "EAXPriestHoly", class = "priest", spec = "holy" },
    { archive = "EAXPriestShadow", class = "priest", spec = "shadow" },
    { archive = "EAXRogueAssassination", class = "rogue", spec = "assassination" },
    { archive = "EAXRogueCombat", class = "rogue", spec = "combat" },
    { archive = "EAXRogueSubtlety", class = "rogue", spec = "subtlety" },
    { archive = "EAXShamanElemental", class = "shaman", spec = "elemental" },
    { archive = "EAXShamanEnhancement", class = "shaman", spec = "enhancement" },
    { archive = "EAXShamanRestoration", class = "shaman", spec = "restoration" },
    { archive = "EAXWarlockAffliction", class = "warlock", spec = "affliction" },
    { archive = "EAXWarlockDemonology", class = "warlock", spec = "demonology" },
    { archive = "EAXWarlockDestruction", class = "warlock", spec = "destruction" },
    { archive = "EAXWarriorArms", class = "warrior", spec = "arms" },
    { archive = "EAXWarriorFury", class = "warrior", spec = "fury" },
    { archive = "EAXWarriorProtection", class = "warrior", spec = "protection" },
}

local common_context = {
    berserking = true, bloodfury = true, shadowmeld = true, warstomp = true,
    arcanetorrent = true, perception = true, stoneform = true, heroicpresence = true,
    scroll = true, potion = true, hastepotion = true, supermanapotion = true,
    healthstone = true, soulstone = true, soulshard = true, firestone = true,
    pacify = true, dragon = true, drums = true,
}

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return "" end
    local data = f:read("*a")
    f:close()
    return data or ""
end

local function write_file(path, data)
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end

local function command_output(command)
    local tmp = os.tmpname() or (os.getenv("TEMP") or "/tmp") .. "/eax_wago_out.txt"
    local redirect = command .. " > " .. tmp .. " 2>nul"
    local ok = os.execute(redirect)
    local f = io.open(tmp, "rb")
    local data = ""
    if f then
        data = f:read("*a") or ""
        f:close()
    end
    os.remove(tmp)
    return data
end

local function fetch_csv(table_name)
    local url = "https://wago.tools/db2/" .. table_name .. "/csv?build=" .. BUILD
    local data = command_output('curl -fsSL -A "' .. UA .. '" "' .. url .. '"')
    return data, url
end

local function parse_csv_lookup(data)
    local lookup = {}
    local first = true
    for line in data:gmatch("[^\r\n]+") do
        if first then
            first = false
        else
            local id, name = line:match("^([^,]+),\"?([^,\"]*)")
            id = tonumber(id)
            if id and name and name ~= "" and name ~= "-1" then lookup[id] = name end
        end
    end
    return lookup
end

local function nums(text)
    local out = {}
    for n in (text or ""):gmatch("%f[%d](%d+)%f[%D]") do
        out[#out + 1] = tonumber(n)
    end
    return out
end

local function normalize(name)
    name = name:gsub("^BUFF_", "")
    name = name:gsub("^DEBUFF_", "")
    name = name:gsub("_", "")
    return name:lower()
end

local stop_words = {
    buff = true, debuff = true, spell = true, rank = true, ranks = true,
    ids = true, id = true, effect = true, proc = true, aura = true,
    self = true, target = true, bear = true, cat = true, dire = true,
}

local name_aliases = {
    clearcasting = { "omenofclarity" },
    elementaldevastation = { "elementaldevastation" },
    flurry = { "flurry" },
    maelstromweapon = { "maelstromweapon" },
    naturesgrace = { "naturesgrace" },
}

local function compact_name(name)
    return (name or ""):lower():gsub("[^a-z0-9]", "")
end

local function name_matches(entry, label)
    local normalized = entry.normalized or ""
    local compact_label = compact_name(label)
    if compact_label == "" or compact_label == "-1" then return false end
    if compact_label:find(normalized, 1, true) or normalized:find(compact_label, 1, true) then return true end

    local aliases = name_aliases[normalized]
    if aliases then
        for i = 1, #aliases do
            if compact_label:find(aliases[i], 1, true) then return true end
        end
    end

    local raw = (entry.table_name or ""):lower()
    raw = raw:gsub("^buff_", ""):gsub("^debuff_", "")
    for word in raw:gmatch("[a-z0-9]+") do
        if #word >= 4 and not stop_words[word] and compact_label:find(word, 1, true) then
            return true
        end
    end
    return false
end

local function extract_archive_entries(data)
    local entries = {}
    for name, body in data:gmatch("spells%.([%w_]+)%s*=%s*%{([^}]*)%}") do
        if not name:match("_RADIUS$") then
            local ids = nums(body)
            for i = 1, #ids do
                entries[#entries + 1] = { table_name = name, normalized = normalize(name), id = ids[i] }
            end
        end
    end
    return entries
end

local function id_set(data)
    local set = {}
    for n in data:gmatch("%f[%d](%d+)%f[%D]") do set[tonumber(n)] = true end
    return set
end

local function central_id_set()
    local TBC = require("shared/tbc_data_sylvanas")
    local set = {}
    local function walk(value)
        if type(value) == "number" then
            set[value] = true
        elseif type(value) == "table" then
            for _, child in pairs(value) do walk(child) end
        end
    end
    walk(TBC.SPELLS)
    walk(TBC.BUFFS)
    walk(TBC.ITEMS)
    walk(TBC.WEAPON_ENCHANTS)
    return set
end

local function category(entry, current_ids, central_ids, spell_names, item_names)
    if current_ids[entry.id] then return "covered_current" end
    if central_ids[entry.id] then return "covered_central" end
    local n = entry.normalized
    for key in pairs(common_context) do
        if n:find(key, 1, true) then return "common_or_consumable" end
    end
    if spell_names[entry.id] then
        if name_matches(entry, spell_names[entry.id]) then return "candidate_spell" end
        return "archive_name_mismatch"
    end
    if item_names[entry.id] then return "item_not_central" end
    return "not_tbc_build"
end

local spell_csv, spell_url = fetch_csv("SpellName")
local item_csv, item_url = fetch_csv("ItemSparse")
local spell_names = parse_csv_lookup(spell_csv)
local item_names = parse_csv_lookup(item_csv)
local central_ids = central_id_set()

local total = {
    covered_current = 0,
    covered_central = 0,
    common_or_consumable = 0,
    item_not_central = 0,
    candidate_spell = 0,
    archive_name_mismatch = 0,
    not_tbc_build = 0,
}

local lines = {
    "# Archive Triage",
    "",
    "Generated by `EaxRotations/tools/triage_archive_spell_ids.lua`.",
    "",
    "Sources:",
    "- SpellName: " .. spell_url,
    "- ItemSparse: " .. item_url,
    "",
    "Categories:",
    "- `covered_current`: archive ID already appears in the current class/spec Lua.",
    "- `covered_central`: archive ID is in `shared/tbc_data_sylvanas.lua` but not the current class/spec file.",
    "- `common_or_consumable`: archive table name is racial, scroll, potion, healthstone, soulstone, pacify, or another cross-cutting utility bucket.",
    "- `item_not_central`: Wago recognizes the ID as an item, but central data does not yet carry it.",
    "- `candidate_spell`: Wago recognizes the ID as a TBC spell and it is absent from current class/spec and central data.",
    "- `archive_name_mismatch`: Wago recognizes the ID as a TBC spell, but the spell name does not match the archive table name.",
    "- `not_tbc_build`: ID was not found in Wago SpellName or ItemSparse for build " .. BUILD .. ".",
    "",
    "| Spec | Current | Central | Common/Consumable | Item Gap | Candidate Spell | Name Mismatch | Not TBC |",
    "|---|---:|---:|---:|---:|---:|---:|---:|",
}

local detail_lines = {}

for i = 1, #specs do
    local spec = specs[i]
    local archive_data = read_file(archive_root .. "/" .. spec.archive .. "/libraries/spells.lua")
    local current_data = read_file(current_root .. "/classes/" .. spec.class .. "/class_sylvanas.lua")
        .. "\n" .. read_file(current_root .. "/classes/" .. spec.class .. "/" .. spec.spec .. "_sylvanas.lua")
    local current_ids = id_set(current_data)
    local entries = extract_archive_entries(archive_data)
    local counts = {
        covered_current = 0,
        covered_central = 0,
        common_or_consumable = 0,
        item_not_central = 0,
        candidate_spell = 0,
        archive_name_mismatch = 0,
        not_tbc_build = 0,
    }
    local details = {}
    local seen = {}

    for j = 1, #entries do
        local entry = entries[j]
        local cat = category(entry, current_ids, central_ids, spell_names, item_names)
        counts[cat] = counts[cat] + 1
        total[cat] = total[cat] + 1

        if cat == "candidate_spell" or cat == "archive_name_mismatch" or cat == "item_not_central" or cat == "not_tbc_build" then
            local key = cat .. ":" .. tostring(entry.id)
            if not seen[key] then
                seen[key] = true
                local label = spell_names[entry.id] or item_names[entry.id] or "unknown"
                details[#details + 1] = string.format("- `%s` `%d` `%s` from `%s`", cat, entry.id, label, entry.table_name)
            end
        end
    end

    lines[#lines + 1] = string.format(
        "| %s | %d | %d | %d | %d | %d | %d | %d |",
        spec.archive,
        counts.covered_current,
        counts.covered_central,
        counts.common_or_consumable,
        counts.item_not_central,
        counts.candidate_spell,
        counts.archive_name_mismatch,
        counts.not_tbc_build
    )

    if #details > 0 then
        detail_lines[#detail_lines + 1] = ""
        detail_lines[#detail_lines + 1] = "## " .. spec.archive
        for _, detail in ipairs(details) do detail_lines[#detail_lines + 1] = detail end
    end
end

lines[#lines + 1] = ""
lines[#lines + 1] = string.format(
    "Summary: `%d` current-covered, `%d` central-covered, `%d` common/consumable, `%d` item gaps, `%d` candidate spells, `%d` archive name mismatches, `%d` not in TBC build.",
    total.covered_current,
    total.covered_central,
    total.common_or_consumable,
    total.item_not_central,
    total.candidate_spell,
    total.archive_name_mismatch,
    total.not_tbc_build
)

for i = 1, #detail_lines do lines[#lines + 1] = detail_lines[i] end

write_file(report_path, table.concat(lines, "\n") .. "\n")
print("Archive triage written: " .. report_path)
print("Candidate spells: " .. tostring(total.candidate_spell))
print("Archive name mismatches: " .. tostring(total.archive_name_mismatch))
print("Item gaps: " .. tostring(total.item_not_central))
print("Not TBC build: " .. tostring(total.not_tbc_build))
