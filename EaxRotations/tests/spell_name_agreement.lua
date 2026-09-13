-- spell_name_agreement.lua -- shared "bridge-valid means same spell" helper.
-- WHAT:  decides whether a rotation label (or audit pin family) AGREES with the
--        bridge's own name for the same spell id.
-- WHEN:  required by run_wotlk_audit_tests.lua (WotLK tier) and
--        run_sylvanas_audit_tests.lua (SoD tier).
-- WHY:   bridge membership alone cannot tell "same spell" from "some spell with a
--        valid id".  The 2026-09-13 spell-id sweep proved the hole: SodCleave pinned
--        25286 (Heroic Strike) and Volley pinned 1543 (Flare) were both
--        bridge-valid, so the audits accepted two lanes that cast the wrong spell
--        (live bugs: NS.get_spell_id returns the first id the unit knows).
-- SAFETY: pure functions over strings/tables.  No io, no dofile, no state.

local M = {}

-- Tokens that legitimately appear in a client spell name but carry no family
-- meaning of their own, so their presence on either side is not a disagreement.
-- IMPORTANT: this is a TOKEN-level allowlist, never an id-level one -- it cannot
-- whitelist a wrong spell, it can only forgive a modifier word.  Adding "strike"
-- here, say, would NOT let define("SodCleave", { 25286 }) pass, because "heroic"
-- is still unmatched.
local MODIFIER_TOKENS = {
    -- client effect/twin suffixes (the cast spell and its aura share a name)
    ["passive"] = true, ["form"] = true, ["aura"] = true, ["effect"] = true,
    ["rank"] = true, ["r"] = true, ["dummy"] = true, ["visual"] = true,
    -- Judgement variants: one label covers Light / Justice / Wisdom
    ["light"] = true, ["justice"] = true, ["wisdom"] = true,
    -- Conjure-family item names (ConjureManaEmerald -> "Conjure Mana Gem")
    ["gem"] = true, ["emerald"] = true, ["agate"] = true, ["jade"] = true,
    ["citrine"] = true, ["ruby"] = true, ["star"] = true,
    -- Soulstone shape: Create <-> Use / Resurrection
    ["use"] = true, ["resurrection"] = true,
    -- Druid form naming (DireBearForm -> "Bear Form")
    ["dire"] = true,
}

-- Deliberate cross-spell FALLBACK ladders.  Some lanes are not rank ladders at
-- all: they are a cast-priority list whose later entries are a different spell
-- that fills the same role, so the tail id's client name legitimately differs
-- from the label.  Each entry is keyed by the LABEL and names the exact bridge
-- name it is allowed to resolve to, with the reason.  This is deliberately NOT
-- an id-level allowlist: an exception must name both the label and the client
-- name being excused, so a mislabelled id cannot be smuggled in without also
-- writing down what spell it actually is.  The self-test pins the entry count so
-- growth is visible in review.
local FALLBACK_LADDERS = {
    -- SoD Devastate: the rune (403195) is not a TBC-audited spell, so the ladder
    -- leads with the real Devastate (20243) and keeps Sunder Armor (11597) as the
    -- era-clean substitute for a warrior who has not slotted the rune.
    -- See classes/warrior/tank_warrior_sod.lua.
    Devastate = { ["Sunder Armor"] = true },
}

-- Words dropped before comparison: glue words that carry no family meaning.
local STOP_TOKENS = {
    ["of"] = true, ["the"] = true, ["a"] = true, ["an"] = true, ["and"] = true,
}

-- Fold a simple plural to its singular stem so "Survival Instincts" matches
-- the client's "Survival Instinct" and "Hunters" matches "Hunter".  Both sides
-- are stemmed identically, so this cannot create a false negative -- it only
-- stops a number agreement from being read as a different spell.
local function stem(word)
    if #word > 3 and word:sub(-3) == "ies" then return word:sub(1, -4) .. "y" end
    if #word > 2 and word:sub(-1) == "s" and word:sub(-2) ~= "ss" then
        return word:sub(1, -2)
    end
    return word
end

-- Split camelCase / PascalCase into words, then fold to lowercase alpha tokens.
-- "PrayerofMending" -> prayer, of, mending: the "of" is spliced out of the
-- camelCase run so it is dropped like a real word rather than glued to "prayer".
local function tokenize(name)
    if type(name) ~= "string" or name == "" then return nil end
    local s = name:gsub("'", "")                  -- Hunter's -> Hunters
    s = s:gsub("(%a)of(%u)", "%1 of %2")          -- PrayerofMending -> Prayer of Mending
    s = s:gsub("([a-z0-9])([A-Z])", "%1 %2")      -- DireBear -> Dire Bear
    s = s:gsub("([A-Z]+)([A-Z][a-z])", "%1 %2")   -- PWShield -> PW Shield
    s = s:lower()
    s = s:gsub("[^%a]", " ")
    local set = {}
    for w in s:gmatch("%a+") do
        if not STOP_TOKENS[w] then set[stem(w)] = true end
    end
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    if n == 0 then return nil end
    return set
end

-- Whole-word modifier test.  Deliberately NOT a prefix match: "pack" must never
-- be forgiven as "passive", or a real wrong-spell pin would slip through.
local function is_modifier(word, modifiers)
    return modifiers[word] == true
end

-- The two shipped bridges disagree about entry SHAPE: the WotLK index is
-- keyed (`{ name = "Volley", class = "", level = 40 }`) while the TBC/vanilla
-- indexes are positional (`{"Volley", nil, 40, "physical", ...}`).  Reading only
-- `.name` made this check silently vacuous on every TBC id, so the accessor is
-- shared and shape-aware.
function M.entry_name(entry)
    if type(entry) ~= "table" then return nil end
    if type(entry.name) == "string" and entry.name ~= "" then return entry.name end
    if type(entry[1]) == "string" and entry[1] ~= "" then return entry[1] end
    return nil
end

-- Do a label (or pin family) and a bridge name describe the SAME spell?
-- Returns agreed (bool) plus the bridge tokens that blocked agreement, so a
-- failure prints WHY instead of just "mismatch".
-- Only the bridge's own tokens are required to be accounted for: the client name
-- is the authority on what the spell IS, while the rotation label is a chosen
-- key that may add qualifiers (MagmaTotem for "Magma Totem Passive").
function M.name_agrees(label, bridge_name, modifiers)
    local mods = modifiers or MODIFIER_TOKENS
    local lt = tokenize(label)
    local bt = tokenize(bridge_name)
    if not lt or not bt then return true, {} end

    local extra = {}
    for w in pairs(bt) do
        if not lt[w] and not is_modifier(w, mods) then
            extra[#extra + 1] = w
        end
    end
    table.sort(extra)
    return #extra == 0, extra
end

-- Walk a define(...) call on one line and return { label, ids } or nil.
-- Mirrors the audits' own arg walker (top-level commas at paren depth 1, brace
-- depth 0) so the two scanners cannot disagree about what a ladder contains.
local function parse_define_at(line, s)
    local p = line:find("%(", s)
    if not p then return nil end
    local depth, i = 1, p + 1
    local args, cur, in_str, sc, braces = {}, "", false, nil, 0
    while i <= #line and depth > 0 do
        local c = line:sub(i, i)
        if in_str then
            if c == "\\" then i = i + 1
            elseif c == sc then in_str = false end
            cur = cur .. c
        elseif c == '"' or c == "'" then in_str = true; sc = c; cur = cur .. c
        elseif c == "(" then depth = depth + 1; cur = cur .. c
        elseif c == ")" then
            depth = depth - 1
            if depth == 0 then args[#args + 1] = cur; break end
            cur = cur .. c
        elseif c == "{" then braces = braces + 1; cur = cur .. c
        elseif c == "}" then braces = braces - 1; cur = cur .. c
        elseif c == "," and depth == 1 and braces == 0 then
            args[#args + 1] = cur; cur = ""
        else cur = cur .. c end
        i = i + 1
    end
    local label = args[1] and args[1]:match('^%s*"(.-)"%s*$')
    if not label then return nil end
    local ids = {}
    if args[2] then
        local t = args[2]:match("(%b{})")
        if t and not t:find("=") then
            for n in t:gmatch("(%d+)") do ids[#ids + 1] = tonumber(n) end
        else
            local n = args[2]:match("^%s*(%d+)%s*$")
            if n then ids[1] = tonumber(n) end
        end
    end
    return { label = label, ids = ids, end_pos = p }
end

-- Scan a file body for `define("Label", <ids>)` ladders and return every
-- (label, id) pair whose bridge name disagrees with the label.
-- opts.index     = { [id] = { name = "..." } }  (required)
-- opts.modifiers = override the token allowlist  (optional)
-- opts.strip     = label prefix to ignore, e.g. "Sod" (optional)
-- Returns { { line, id, label, bridge, extra = {...} }, ... }.
function M.check_ladders(content, opts)
    local index = (opts and opts.index) or {}
    local mods = (opts and opts.modifiers) or MODIFIER_TOKENS
    local strip = opts and opts.strip
    local out = {}
    if type(content) ~= "string" then return out end

    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if not line:match("^%s*%-%-") then
            local pos = 1
            while true do
                local s = line:find("define%s*%(", pos)
                if not s then break end
                local call = parse_define_at(line, s)
                if call then
                    local label = call.label
                    local probe = label
                    if strip and probe:sub(1, #strip) == strip then
                        probe = probe:sub(#strip + 1)
                    end
                    -- A fallback allowance only applies when the ladder's HEAD
                    -- agrees with the label: the head is the id a max-level player
                    -- resolves to, so a ladder whose head is already the wrong
                    -- spell is never excused.  (An id the bridge does not describe
                    -- cannot be compared, so it fails open like everywhere else.)
                    local head_agrees = true
                    local head_name = M.entry_name(index[call.ids[1]])
                    if head_name then
                        head_agrees = (M.name_agrees(probe, head_name, mods))
                    end
                    local fallbacks = head_agrees and FALLBACK_LADDERS[probe] or nil
                    for _, id in ipairs(call.ids) do
                        local bname = M.entry_name(index[id])
                        if bname and not (fallbacks and fallbacks[bname]) then
                            local ok, extra = M.name_agrees(probe, bname, mods)
                            if not ok then
                                out[#out + 1] = {
                                    line = line_no, id = id, label = label,
                                    bridge = bname, extra = extra,
                                }
                            end
                        end
                    end
                    pos = call.end_pos + 1
                else
                    pos = s + 1
                end
            end
        end
    end
    return out
end

-- Scan an audit pin table for `[id] = { kind = ..., family = "..." }` lines whose
-- declared family disagrees with the bridge name for that id (the
-- PIN-FAMILY-MISMATCH defect: 2944 was pinned "Shadow Word: Death" while the
-- client calls it Devouring Plague -- the pin was self-certifying).
-- Returns { { id, family, bridge, extra = {...} }, ... }.
function M.check_pin_families(content, opts)
    local index = (opts and opts.index) or {}
    local mods = (opts and opts.modifiers) or MODIFIER_TOKENS
    local out = {}
    if type(content) ~= "string" then return out end
    for line in content:gmatch("[^\r\n]+") do
        if not line:match("^%s*%-%-") then
            local id = line:match("^%s*%[(%d+)%]")
            local family = line:match('family%s*=%s*"(.-)"')
            if id and family then
                local bname = M.entry_name(index[tonumber(id)])
                if bname then
                    local ok, extra = M.name_agrees(family, bname, mods)
                    if not ok then
                        out[#out + 1] = {
                            id = tonumber(id), family = family,
                            bridge = bname, extra = extra,
                        }
                    end
                end
            end
        end
    end
    return out
end

M.MODIFIER_TOKENS = MODIFIER_TOKENS
M.FALLBACK_LADDERS = FALLBACK_LADDERS
M.STOP_TOKENS = STOP_TOKENS
M.tokenize = tokenize

return M
