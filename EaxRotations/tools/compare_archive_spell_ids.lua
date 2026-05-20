-- Compare original archived spell tables against current class/spec Lua.

local archive_root = "archive_original_specs"
local current_root = "EaxRotations"
local report_path = "EaxRotations/docs/ARCHIVE_SPELL_ID_COMPARISON.md"

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

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function write_file(path, data)
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end

local function normalize(name)
    name = name:gsub("^BUFF_", "")
    name = name:gsub("^DEBUFF_", "")
    name = name:gsub("_", "")
    return name:lower()
end

local function nums(text)
    local out = {}
    for n in (text or ""):gmatch("%f[%d](%d+)%f[%D]") do
        out[#out + 1] = tonumber(n)
    end
    return out
end

local function sorted_keys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local function extract_archive_tables(data)
    local out = {}
    if not data then return out end
    for name, body in data:gmatch("spells%.([%w_]+)%s*=%s*%{([^}]*)%}") do
        local ids = nums(body)
        if #ids > 0 and not name:match("_RADIUS$") then
            out[normalize(name)] = { raw = name, ids = ids }
        end
    end
    return out
end

local function extract_current_tables(data)
    local out = {}
    if not data then return out end
    for name, body in data:gmatch("([%w_]+)%s*=%s*NS%.spell_action%s*%(%s*%{([^}]*)%}%s*,") do
        local ids = nums(body)
        if #ids > 0 then out[normalize(name)] = { raw = name, ids = ids } end
    end
    for body, name in data:gmatch("NS%.spell_action%s*%(%s*%{([^}]*)%}%s*,%s*\"([^\"]+)\"") do
        local ids = nums(body)
        if #ids > 0 then out[normalize(name)] = { raw = name, ids = ids } end
    end
    for name, body in data:gmatch("name%s*=%s*\"([^\"]+)\".-ids%s*=%s*%{([^}]*)%}") do
        local ids = nums(body)
        if #ids > 0 then out[normalize(name)] = { raw = name, ids = ids } end
    end
    return out
end

local function extract_all_ids(data)
    local set = {}
    if not data then return set end
    for n in data:gmatch("%f[%d](%d+)%f[%D]") do
        set[tonumber(n)] = true
    end
    return set
end

local function extract_all_current(spec)
    local class_path = current_root .. "/classes/" .. spec.class .. "/class_sylvanas.lua"
    local spec_path = current_root .. "/classes/" .. spec.class .. "/" .. spec.spec .. "_sylvanas.lua"
    local combined = (read_file(class_path) or "") .. "\n" .. (read_file(spec_path) or "")
    return extract_current_tables(combined)
end

local function id_set(ids)
    local set = {}
    for i = 1, #ids do set[ids[i]] = true end
    return set
end

local function missing_ids(archive_ids, current_ids)
    local set = id_set(current_ids or {})
    local missing = {}
    for i = 1, #archive_ids do
        if not set[archive_ids[i]] then missing[#missing + 1] = archive_ids[i] end
    end
    return missing
end

local function join_ids(ids)
    if #ids == 0 then return "" end
    local out = {}
    for i = 1, #ids do out[#out + 1] = tostring(ids[i]) end
    return table.concat(out, ", ")
end

local lines = {
    "# Archive Spell ID Comparison",
    "",
    "Generated by `EaxRotations/tools/compare_archive_spell_ids.lua`.",
    "",
    "This compares `archive_original_specs/*/libraries/spells.lua` against the current class/spec Lua files by normalized spell-table name.",
    "",
    "| Spec | Archive Tables | Matched | Missing Tables | Same-Name ID Diffs | IDs Absent Anywhere |",
    "|---|---:|---:|---:|---:|---:|",
}

local total_missing_tables = 0
local total_missing_ids = 0
local total_absent_anywhere = 0

for i = 1, #specs do
    local spec = specs[i]
    local archive_path = archive_root .. "/" .. spec.archive .. "/libraries/spells.lua"
    local archive_data = read_file(archive_path) or ""
    local current_class_path = current_root .. "/classes/" .. spec.class .. "/class_sylvanas.lua"
    local current_spec_path = current_root .. "/classes/" .. spec.class .. "/" .. spec.spec .. "_sylvanas.lua"
    local current_data = (read_file(current_class_path) or "") .. "\n" .. (read_file(current_spec_path) or "")
    local archive_tables = extract_archive_tables(archive_data)
    local current_tables = extract_current_tables(current_data)
    local current_ids = extract_all_ids(current_data)
    local archive_keys = sorted_keys(archive_tables)
    local missing_tables = {}
    local id_misses = {}
    local absent_anywhere = {}
    local matched = 0

    for _, key in ipairs(archive_keys) do
        local archive_entry = archive_tables[key]
        local current_entry = current_tables[key]
        if current_entry then
            matched = matched + 1
            local miss = missing_ids(archive_entry.ids, current_entry.ids)
            if #miss > 0 then
                id_misses[#id_misses + 1] = archive_entry.raw .. " missing " .. join_ids(miss)
                total_missing_ids = total_missing_ids + #miss
            end
        else
            missing_tables[#missing_tables + 1] = archive_entry.raw
            total_missing_tables = total_missing_tables + 1
        end

        for j = 1, #archive_entry.ids do
            local id = archive_entry.ids[j]
            if not current_ids[id] then
                absent_anywhere[id] = archive_entry.raw
            end
        end
    end

    local absent_list = {}
    for id, source in pairs(absent_anywhere) do
        absent_list[#absent_list + 1] = { id = id, source = source }
        total_absent_anywhere = total_absent_anywhere + 1
    end
    table.sort(absent_list, function(a, b) return a.id < b.id end)

    lines[#lines + 1] = string.format(
        "| %s | %d | %d | %d | %d | %d |",
        spec.archive,
        #archive_keys,
        matched,
        #missing_tables,
        #id_misses,
        #absent_list
    )

    if #missing_tables > 0 or #id_misses > 0 or #absent_list > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "## " .. spec.archive
        if #missing_tables > 0 then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Missing current spell tables: `" .. table.concat(missing_tables, "`, `") .. "`"
        end
        if #id_misses > 0 then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Archive IDs not present under the same normalized table name:"
            for _, miss in ipairs(id_misses) do
                lines[#lines + 1] = "- " .. miss
            end
        end
        if #absent_list > 0 then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Archive IDs absent anywhere in current class/spec files:"
            for _, miss in ipairs(absent_list) do
                lines[#lines + 1] = "- " .. tostring(miss.id) .. " from " .. miss.source
            end
        end
        lines[#lines + 1] = ""
    end
end

lines[#lines + 1] = ""
lines[#lines + 1] = string.format("Summary: `%d` missing normalized tables, `%d` same-name archive ID differences, `%d` archive IDs absent anywhere.", total_missing_tables, total_missing_ids, total_absent_anywhere)

write_file(report_path, table.concat(lines, "\n") .. "\n")
print("Archive comparison written: " .. report_path)
print("Missing tables: " .. tostring(total_missing_tables))
print("Archive ID differences: " .. tostring(total_missing_ids))
print("Archive IDs absent anywhere: " .. tostring(total_absent_anywhere))
