-- ============================================================================
-- Build-only audit tool: validates TBC spell IDs against wago.tools DB2 CSV.
-- ============================================================================
-- What: Fetches official spell data from wago.tools and checks against codebase
-- When: Run manually before release; NOT loaded by runtime
-- Why: Ensures all spell IDs in the repo match TBC 2.5.4 DB2
-- Safety: Requires network and curl; runs in isolated build context only
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local BUILD = "2.5.4.42940"
local ROOT = arg and arg[1] or "EaxRotations"
local UA = "Codex-EAX-ID-Audit/1.0"

local function fail(msg)
    io.stderr:write(msg .. "\n")
    os.exit(1)
end

local function command_output(command)
    local tmp = os.tmpname() or (os.getenv("TEMP") or "/tmp") .. "/eax_wago_out.txt"
    local redirect = command .. " > " .. tmp .. " 2>nul"
    local ok = os.execute(redirect)
    local f = io.open(tmp, "rb")
    local data = nil
    if f then
        data = f:read("*a")
        f:close()
    end
    os.remove(tmp)
    if ok ~= true and ok ~= 0 then return nil end
    return data
end

local function fetch_csv(table_name)
    local url = "https://wago.tools/db2/" .. table_name .. "/csv?build=" .. BUILD
    local command = 'curl -fsSL -A "' .. UA .. '" "' .. url .. '"'
    local data = command_output(command)
    if not data or data == "" then fail("failed to fetch " .. url) end
    return data, url
end

local function first_csv_field(line)
    local field = line:match("^([^,]+)")
    return tonumber(field)
end

local function id_set_from_csv(data)
    local set = {}
    local first = true
    for line in data:gmatch("[^\r\n]+") do
        if first then
            first = false
        else
            local id = first_csv_field(line)
            if id then set[id] = true end
        end
    end
    return set
end

local function collect_numbers(value, out)
    if type(value) == "number" then
        out[#out + 1] = value
    elseif type(value) == "table" then
        for _, child in pairs(value) do
            collect_numbers(child, out)
        end
    end
end

local function list_non_lua_md_files(root)
    local command = "powershell -NoProfile -Command \"Get-ChildItem -LiteralPath '" .. root .. "' -Recurse -File | ForEach-Object { $_.FullName }\""
    local data = command_output(command) or ""
    local bad = {}
    for path in data:gmatch("[^\r\n]+") do
        local lower = path:lower()
        if not lower:match("%.lua$") and not lower:match("%.md$") then
            bad[#bad + 1] = path
        end
    end
    return bad
end

local function list_lua_files(root)
    local command = "powershell -NoProfile -Command \"Get-ChildItem -LiteralPath '" .. root .. "' -Recurse -File -Filter *.lua | ForEach-Object { $_.FullName }\""
    local data = command_output(command) or ""
    local files = {}
    for path in data:gmatch("[^\r\n]+") do
        local lower = path:lower():gsub("\\", "/")
        if not lower:find("/tests/", 1, true)
            and not lower:find("/tools/", 1, true)
            and not lower:find("/docs/", 1, true)
            and not lower:find("/community_profiles/", 1, true) then
            files[#files + 1] = path
        end
    end
    return files
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function normalize_path(path)
    return (path or ""):gsub("\\", "/")
end

local function numbers_from_table(table_text)
    local out = {}
    table_text = table_text:gsub("[Nn]%s*=%s*%d+", "")
    for n in table_text:gmatch("%f[%d](%d+)%f[%D]") do
        local value = tonumber(n)
        if value and value > 0 then out[#out + 1] = value end
    end
    return out
end

local function strip_comments(data)
    data = data:gsub("%-%-%[%[.-%]%]", "")
    data = data:gsub("%-%-[^\r\n]*", "")
    return data
end

local SPELL_CONTEXT_KEYS = {
    "spell", "spells", "aura", "auras", "buff", "buffs", "debuff", "debuffs",
    "dot", "dots", "hot", "hots", "shield", "poison", "curse", "disease",
    "magic", "cc", "fear", "stun", "silence", "root", "snare", "aspect",
    "seal", "blessing", "totem", "imbue", "shout", "stance", "form",
}

local ITEM_CONTEXT_KEYS = {
    "item", "items", "potion", "potions", "food", "drink", "drinks", "flask",
    "flasks", "elixir", "elixirs", "healthstone", "healthstones", "rune",
    "runes", "bandage", "bandages", "scroll", "scrolls", "drum", "drums",
}

local function contains_context_key(text, keys)
    local lower = (text or ""):lower()
    for i = 1, #keys do
        if lower:find(keys[i], 1, true) then return true end
    end
    return false
end

local function has_excluded_context(text)
    local lower = (text or ""):lower()
    local excluded = {
        "map", "slot", "class", "school", "flag", "state", "chance", "rating",
        "threshold", "cooldown", "duration", "interval", "priority", "level",
        "power", "mana", "rage", "energy", "timer", "range", "distance",
        "caster_ids", "npc", "creature", "totem_slot", "talent",
    }
    for i = 1, #excluded do
        if lower:find(excluded[i], 1, true) then return true end
    end
    return false
end

local function simple_id_list(body)
    local normalized = (body or ""):gsub("[Nn]%s*=%s*%d+", "")
    if normalized:find("=", 1, true) then return false end
    if normalized:find("[\"']") then return false end
    return true
end

local function add_context(results, kind, file, line_no, label, ids)
    if #ids == 0 then return end
    results[#results + 1] = {
        kind = kind,
        file = file,
        line = line_no,
        label = label,
        ids = ids,
    }
end

local function line_number_at(data, index)
    local line = 1
    for _ in data:sub(1, index):gmatch("\n") do line = line + 1 end
    return line
end

local function scan_static_contexts(root)
    local contexts = {}
    local files = list_lua_files(root)
    for i = 1, #files do
        local path = files[i]
        local data = read_file(path)
        if data then
            data = strip_comments(data)
            local rel = normalize_path(path)
            local lower_rel = rel:lower()
            local skip_static = lower_rel:find("/shared/tbc_data_sylvanas.lua", 1, true)
                or lower_rel:find("/sim_constants_sylvanas.lua", 1, true)
                or lower_rel:find("/shared/talent_inference_sylvanas.lua", 1, true)

            if not skip_static then
                for start_pos, prefix, body in data:gmatch("()([%w_%.:%[%]\"']+%s*=%s*)%{([^{}]-)%}") do
                    local label = prefix:gsub("%s+", "")
                    local ids = numbers_from_table(body)
                    if #ids > 0 and simple_id_list(body) and not has_excluded_context(label) then
                        local kind = nil
                        if contains_context_key(label, ITEM_CONTEXT_KEYS) then
                            kind = "item"
                        elseif contains_context_key(label, SPELL_CONTEXT_KEYS) or label:lower():find("ids=", 1, true) then
                            kind = "spell"
                        end
                        if kind then add_context(contexts, kind, rel, line_number_at(data, start_pos), label, ids) end
                    end
                end

                for start_pos, body in data:gmatch("()NS%.spell_action%s*%(%s*%{([^{}]-)%}") do
                    if simple_id_list(body) then
                        add_context(contexts, "spell", rel, line_number_at(data, start_pos), "NS.spell_action", numbers_from_table(body))
                    end
                end

                for start_pos, body in data:gmatch("()NS%.CreateSpell%s*%(%s*%{([^{}]-)%}") do
                    if simple_id_list(body) then
                        add_context(contexts, "spell", rel, line_number_at(data, start_pos), "NS.CreateSpell", numbers_from_table(body))
                    end
                end
            end
        end
    end
    return contexts
end

local function add_bad_context(out, context, id)
    out[#out + 1] = {
        file = context.file,
        line = context.line,
        label = context.label,
        kind = context.kind,
        id = id,
    }
end

local TBC = require("shared/tbc_data_sylvanas")

local spell_csv, spell_url = fetch_csv("SpellName")
local item_csv, item_url = fetch_csv("ItemSparse")
local known_spells = id_set_from_csv(spell_csv)
local known_items = id_set_from_csv(item_csv)

local spell_ids = {}
collect_numbers(TBC.SPELLS, spell_ids)
collect_numbers(TBC.BUFFS, spell_ids)

local item_ids = {}
collect_numbers(TBC.ITEMS, item_ids)

local bad_spells, bad_items = {}, {}
for i = 1, #spell_ids do
    local id = spell_ids[i]
    if not known_spells[id] then bad_spells[#bad_spells + 1] = id end
end
for i = 1, #item_ids do
    local id = item_ids[i]
    if not known_items[id] then bad_items[#bad_items + 1] = id end
end

local bad_files = list_non_lua_md_files(ROOT)
local static_contexts = scan_static_contexts(ROOT)
local bad_static = {}

for i = 1, #static_contexts do
    local context = static_contexts[i]
    local known = context.kind == "item" and known_items or known_spells
    for j = 1, #context.ids do
        local id = context.ids[j]
        if not known[id] then add_bad_context(bad_static, context, id) end
    end
end

print("Spell source: " .. spell_url)
print("Item source: " .. item_url)
print("Checked spell/aura IDs: " .. tostring(#spell_ids))
print("Checked item IDs: " .. tostring(#item_ids))
print("Checked static code contexts: " .. tostring(#static_contexts))
print("Non Lua/Markdown files: " .. tostring(#bad_files))

if #bad_spells > 0 then
    print("Invalid spell/aura IDs:")
    for i = 1, #bad_spells do print("  " .. tostring(bad_spells[i])) end
end
if #bad_items > 0 then
    print("Invalid item IDs:")
    for i = 1, #bad_items do print("  " .. tostring(bad_items[i])) end
end
if #bad_files > 0 then
    print("Disallowed files:")
    for i = 1, #bad_files do print("  " .. tostring(bad_files[i])) end
end
if #bad_static > 0 then
    print("Invalid static code contexts:")
    for i = 1, #bad_static do
        local bad = bad_static[i]
        print("  " .. bad.kind .. " " .. tostring(bad.id) .. " at " .. bad.file .. ":" .. tostring(bad.line) .. " (" .. bad.label .. ")")
    end
end

if #bad_spells > 0 or #bad_items > 0 or #bad_files > 0 or #bad_static > 0 then os.exit(1) end
print("PASS audit_online_tbc_ids")
