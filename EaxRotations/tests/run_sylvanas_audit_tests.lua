-- run_sylvanas_audit_tests.lua -- Audit sylvanas.lua rotation files for invalid spell IDs.
-- WHAT:  Scans rotation files for spell IDs absent from WoW 2.5.5.68101 DBC.
-- WHEN:  Run manually or in CI before releases.
-- WHY:   Catches invalid spell IDs that pass vanilla audit but are bogus for TBC Anniversary.
-- SAFETY: Read-only text scan + bridge lookup. No dofile(), no io writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local bridge_ok, bridge = pcall(require, "shared/wowhead_data_bridge_sylvanas")
if not bridge_ok or not bridge then
    print("[ERROR] Could not load wowhead_data_bridge_sylvanas")
    print("        Run: python build_tools/json_to_lua_data.py")
    os.exit(2)
end

local spell_index = bridge.spell_index_tbc or {}
local item_index  = bridge.item_index or {}

-- Name-agreement helper ("bridge-valid" must mean "same spell", not merely "some
-- spell with a valid id").  SoD loaders run on the TBC/SoD client, so they are
-- checked against the TBC bridge.  See tests/spell_name_agreement.lua for the
-- rule and the 2026-09-13 spell-id sweep that motivated it.
local name_ok, name_agreement = pcall(require, "tests/spell_name_agreement")
if not name_ok or not name_agreement then
    print("[ERROR] Could not load tests/spell_name_agreement")
    os.exit(2)
end

-- Count entries (hash tables, not arrays)
local spell_count, item_count = 0, 0
for _ in pairs(spell_index) do spell_count = spell_count + 1 end
for _ in pairs(item_index)  do item_count  = item_count  + 1 end

-- Build quick lookup tables
local valid_spell_ids = {}
for id in pairs(spell_index) do
    valid_spell_ids[id] = true
end

-- WotLK-era spell IDs that exist in the full-dataset bridge but are NOT valid
-- on the TBC Anniversary (2.5.5) client. The bridge contains all eras, so
-- bridge-membership alone cannot discriminate; these are the confirmed leaks
-- (wowhead TBC 404 / absent from the 2.5.x DBC). Kept as an explicit blocklist so
-- a WotLK rank can never silently return to a *_sylvanas.lua file.
local WOTLK_ONLY_IDS = {
    [50334] = "Berserk (WotLK druid; not in TBC)",
    [61305] = "Polymorph (Black Cat) (WotLK; not in TBC)",
    [61721] = "Polymorph (Rabbit) (WotLK; not in TBC)",
    [61780] = "Polymorph (Turkey) (WotLK; not in TBC)",
}

-- Cross-era signature heads (rank-audit 2026-08-08): shared/talent_inference_
-- sylvanas.lua runs on EVERY client (the dispatcher main.lua -> main_sylvanas.lua
-- calls TI.infer_cached on both TBC and WotLK). Its signature lists therefore
-- carry BOTH the TBC-era ladder AND the verified WotLK max rank (prepended
-- first). On a TBC client the WotLK ID is simply not learned; on a WotLK client
-- it is the rank-7 a max-level player actually has — without it, spec inference
-- silently fails on WotLK. These are the SAME IDs pinned in
-- run_wotlk_audit_tests.lua's WOTLK_REFERENCE_ALIASES; the allowlist below is
-- scoped to the one cross-era module (CROSS_ERA_FILES), so a WotLK rank can
-- still never return to a *_sylvanas.lua CLASS file.
local SHARED_CROSS_ERA_IDS = {
    [48160] = "Vampiric Touch (WotLK max)",
    [48089] = "Circle of Healing (WotLK max)",
    [42891] = "Pyroblast (WotLK max)",
    [47486] = "Mortal Strike (WotLK max)",
    [47488] = "Shield Slam (WotLK max)",
    [48666] = "Mutilate (WotLK max)",
    [48660] = "Hemorrhage (WotLK max)",
    [49050] = "Aimed Shot (WotLK max)",
    [48564] = "Mangle (Bear) (WotLK max)",
    [48566] = "Mangle (Cat) (WotLK max)",
    [48821] = "Holy Shock (WotLK max)",
    [48827] = "Avenger's Shield (WotLK max)",
}

local CROSS_ERA_FILES = {
    ["shared/talent_inference_sylvanas.lua"] = true,
}

-- ---------------------------------------------------------------------------
-- SoD rune/ability IDs (the 20 *_sod.lua loaders, 2026-08-14 W5.1 pin).
-- SoD rune spells (399956-458371) are NOT present in the 2.5.5 DBC — they are
-- Season-of-Discovery client additions, so bridge-membership alone would flag
-- every one of them. These 58 ids are pinned from the loaders' own ACTION
-- tables (the same ids the task-1 action map records) as the drift guard:
-- a NEW id added to a *_sod.lua file must be either TBC-bridge-valid (era-
-- common spells like Eviscerate/Rejuvenation ladders) or pinned here —
-- anything else fails the audit. file:line = first occurrence.
local SOD_RUNE_IDS = {
    [399956] = 399956,  -- rogue/combat_sod.lua:23  (Mutilate)
    [399963] = 399963,  -- rogue/tank_sod.lua:18    (Envenom)
    [400012] = 400012,  -- rogue/tank_sod.lua:15    (BladeDance)
    [400014] = 400014,  -- rogue/tank_sod.lua:14    (JustAFleshWound)
    [401502] = 401502,  -- mage/dps_mage_sod.lua:19
    [401977] = 401977,  -- priest/shadow_sod.lua:21
    [401859] = 401859,  -- priest/healing_sod.lua (PrayerOfMending, SoD Legs rune, wowhead-verified)
    [400613] = 400613,  -- mage/dps_mage_sod.lua (LivingBomb, SoD Helm rune, wowhead-verified)
    [402284] = 402284,  -- priest/healing_sod.lua:15
    [417045] = 417045,  -- druid/feral_sod.lua (TigersFury, SoD rune, wowhead-verified)
    [402842] = 402842,  -- priest/healing_sod.lua (CircleOfHealing, SoD Gloves rune, wowhead-verified)
    [402668] = 402668,  -- priest/shadow_sod.lua:17
    [402799] = 402799,  -- priest/shadow_sod.lua:20
    [402911] = 402911,  -- warrior/dps_warrior_sod.lua:16
    [403629] = 403629,  -- warlock/dps_sod.lua:14   (ChaosBolt)
    [403789] = 403789,  -- warlock/tank_sod.lua:8
    [403851] = 403851,  -- warlock/tank_sod.lua:10
    [407632] = 407632,  -- paladin/protection_sod.lua:19
    [407669] = 407669,  -- paladin/protection_sod.lua:18
    [407676] = 407676,  -- paladin/retribution_sod.lua:17
    [407778] = 407778,  -- paladin/retribution_sod.lua:15
    [407988] = 407988,  -- druid/feral_sod.lua:15   (SavageRoar)
    [407995] = 407995,  -- druid/tank_sod.lua:17    (Mangle Bear)
    [408120] = 408120,  -- druid/restoration_sod.lua:14 (WildGrowth)
    [408247] = 408247,  -- druid/restoration_sod.lua:15 (Nourish)
    [408427] = 408427,  -- shaman/elemental_sod.lua:19
    [408490] = 408490,  -- shaman/enhancement_sod.lua:16
    [408498] = 408498,  -- shaman/warden_sod.lua:17
    [408507] = 408507,  -- shaman/enhancement_sod.lua:21
    [408510] = 408510,  -- shaman/restoration_sod.lua:15 (WaterShield)
    [408521] = 408521,  -- shaman/restoration_sod.lua:16 (Riptide)
    [408531] = 408531,  -- shaman/warden_sod.lua:14
    [409433] = 409433,  -- hunter/dps_hunter_sod.lua:17
    [409593] = 409593,  -- hunter/dps_hunter_sod.lua:18
    [409824] = 409824,  -- druid/restoration_sod.lua:16 (Lifebloom)
    [409828] = 409828,  -- druid/feral_sod.lua:16   (Mangle Cat)
    [412096] = 412096,  -- rogue/tank_sod.lua:17    (CrimsonTempest)
    [412532] = 412532,  -- mage/dps_mage_sod.lua:18
    [412758] = 412758,  -- warlock/tank_sod.lua:13
    [414644] = 414644,  -- druid/tank_sod.lua:16    (Lacerate)
    [409809] = 409809,  -- druid/tank_sod.lua:15    (SurvivalInstincts, SoD rune, wowhead-verified)
    [408024] = 408024,  -- druid/tank_sod.lua:15    (SurvivalInstincts buff, wowhead-verified)
    [408514] = 408514,  -- shaman/restoration_sod.lua:34 (Earth Shield SoD cast, DBC+Wowhead-verified)
    [414684] = 414684,  -- druid/balance_sod.lua:16
    [415073] = 415073,  -- paladin/retribution_sod.lua:16 (Exorcism)
    [415236] = 415236,  -- shaman/restoration_sod.lua:17 (HealingRain)
    [417141] = 417141,  -- druid/tank_sod.lua:18    (Berserk)
    [417157] = 417157,  -- druid/balance_sod.lua:14
    [424785] = 424785,  -- rogue/tank_sod.lua:20    (SaberSlash)
    [424919] = 424919,  -- rogue/tank_sod.lua:16    (MainGauche)
    [425012] = 425012,  -- rogue/combat_sod.lua:25  (PoisonedKnife)
    [425204] = 425204,  -- priest/shadow_sod.lua:15
    [425336] = 425336,  -- shaman/warden_sod.lua:15
    [425339] = 425339,  -- shaman/warden_sod.lua:20
    [425463] = 425463,  -- warlock/tank_sod.lua:9
    [426940] = 426940,  -- warrior/tank_warrior_sod.lua:9 (Rampage)
    [428878] = 428878,  -- mage/dps_mage_sod.lua:17
    [429765] = 429765,  -- warrior/dps_warrior_sod.lua:17
    [431655] = 431655,  -- priest/shadow_sod.lua:23
    [439748] = 439748,  -- druid/balance_sod.lua:17
    [440488] = 440488,  -- warrior/tank_warrior_sod.lua:13 (Shockwave)
    [440580] = 440580,  -- shaman/enhancement_sod.lua:14
    [440658] = 440658,  -- paladin/protection_sod.lua:21
    [440802] = 440802,  -- mage/dps_mage_sod.lua:16
    [458371] = 458371,  -- paladin/protection_sod.lua:16
}

local valid_item_ids = {}
for id in pairs(item_index) do
    valid_item_ids[id] = true
end

local HAS_ITEM_INDEX = (item_count > 0)

-- ---------------------------------------------------------------------------
-- File list: every spec/leveling/class file for TBC Anniversary
--             + shared/ modules that contain spell IDs
-- ---------------------------------------------------------------------------
local SYLVANAS_FILES = {}
for _, class in ipairs({
    "druid", "hunter", "mage", "paladin", "priest",
    "rogue", "shaman", "warlock", "warrior",
}) do
    SYLVANAS_FILES[#SYLVANAS_FILES + 1] = "classes/" .. class .. "/class_sylvanas.lua"
    SYLVANAS_FILES[#SYLVANAS_FILES + 1] = "classes/" .. class .. "/leveling_sylvanas.lua"
    for _, suffix in ipairs({
        "balance", "bear", "cat", "caster", "resto",
        "beast_mastery", "marksmanship", "survival",
        "arcane", "fire", "frost",
        "holy", "protection", "retribution",
        "discipline", "shadow", "smite", "healing",
        "assassination", "combat", "subtlety",
        "elemental", "enhancement", "restoration",
        "affliction", "demonology", "destruction",
        "arms", "fury", "kebab",
    }) do
        SYLVANAS_FILES[#SYLVANAS_FILES + 1] = "classes/" .. class .. "/" .. suffix .. "_sylvanas.lua"
    end
end

-- SoD-era loaders (Season of Discovery runes on the 2.5.x client). Scanned
-- with the same bridge check PLUS the pinned SOD_RUNE_IDS set (runes are not
-- in the 2.5.5 DBC); single-numeric `define("Name", NNN, ...)` action ids are
-- also extracted (the rune-spell shape the brace-group scanner cannot see).
local SOD_FILES = {
    "classes/druid/balance_sod.lua",
    "classes/druid/feral_sod.lua",
    "classes/druid/restoration_sod.lua",
    "classes/druid/tank_sod.lua",
    "classes/hunter/dps_hunter_sod.lua",
    "classes/mage/dps_mage_sod.lua",
    "classes/paladin/protection_sod.lua",
    "classes/paladin/retribution_sod.lua",
    "classes/priest/healing_sod.lua",
    "classes/priest/shadow_sod.lua",
    "classes/rogue/combat_sod.lua",
    "classes/rogue/tank_sod.lua",
    "classes/shaman/elemental_sod.lua",
    "classes/shaman/enhancement_sod.lua",
    "classes/shaman/restoration_sod.lua",
    "classes/shaman/warden_sod.lua",
    "classes/warlock/dps_sod.lua",
    "classes/warlock/tank_sod.lua",
    "classes/warrior/dps_warrior_sod.lua",
    "classes/warrior/tank_warrior_sod.lua",
}

-- Shared modules known to contain spell IDs (buffs, debuffs, talents, consumables)
local SHARED_FILES_WITH_IDS = {
    "shared/buff_upgrade_sylvanas.lua",
    "shared/cast_bar_overlay_sylvanas.lua",
    "shared/consumable_manager_sylvanas.lua",
    "shared/hot_tick_tracker_sylvanas.lua",
    "shared/ooc_manager_sylvanas.lua",
    "shared/talent_inference_sylvanas.lua",
    "shared/tbc_data_sylvanas.lua",
    "shared/weapon_imbue_sylvanas.lua",
}
for _, f in ipairs(SHARED_FILES_WITH_IDS) do
    SYLVANAS_FILES[#SYLVANAS_FILES + 1] = f
end

local root = "EaxRotations"

-- ---------------------------------------------------------------------------
-- Tracked-file set from git: a "skipped" inventory entry whose file IS
-- git-tracked means the repo expects the file but the working tree lacks it
-- (deleted locally, case mismatch on a case-sensitive CI, etc.) — the audit
-- would silently skip a real repo file, a masking gap. Mirror the WotLK
-- audit's zero-skip strictness: only genuinely-absent files may be skipped.
-- io.popen is exempt from test_spec_layout_compliance's banned-API scan for
-- run_*.lua runners (same exemption run_verify_all relies on).
local TRACKED = {}
-- Fail-closed like run_clean_checkout_probe.lua: if the tracked set cannot be
-- populated (git missing, popen failure, empty output) the masking check must
-- NOT silently pass — a nil pipe or empty set would otherwise make is_tracked
-- return false for every entry and hide all masking gaps. This audit only runs
-- inside a git checkout (verify_all already requires git), so exit 1 loudly.
local TRACKED_LOADED = false
local function load_tracked()
    -- NOTE: no `2>/dev/null` — on Windows cmd.exe that redirect targets a
    -- literal file and popen fails, silently emptying the tracked set.
    local pipe = io.popen("git ls-files")
    if not pipe then return false end
    local count = 0
    for line in pipe:lines() do
        -- Strip trailing \r: some Windows Lua 5.1/CRT builds leave CRLF on
        -- popen text lines, which would make every lookup miss and silently
        -- disable the check on the dev OS.
        local p = line:gsub("\r$", ""):gsub("\\", "/"):gsub("^%./", "")
        if p ~= "" then
            TRACKED[p] = true
            count = count + 1
        end
    end
    pipe:close()
    TRACKED_LOADED = count > 0
    return TRACKED_LOADED
end

-- Inventory entries are EaxRotations-relative ("classes/..."); git lists
-- repo-root-relative ("EaxRotations/classes/..."). Canonicalize and check.
local EAX_PREFIX = "EaxRotations/"
local function is_tracked(file)
    -- Guard against a future repo-root-relative inventory entry:
    -- "EaxRotations/classes/..." must not become "EaxRotations/EaxRotations/...".
    local rel = file
    if rel:sub(1, #EAX_PREFIX) == EAX_PREFIX then
        rel = rel:sub(#EAX_PREFIX + 1)
    end
    return TRACKED[EAX_PREFIX .. rel] or false
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a") or ""
    f:close()
    return content
end

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

-- Patterns we scan for spell IDs:
--  - `ids = { N, N, ... }` inside spell_action/define calls
--  - `spell_ids = { N, N, ... }` in hot tick trackers
--  - Standalone BUFF/DEBUFF/SPELL arrays `local X_BUFF = { N, N }`
--  - `define("Name", { N, N }, ...)` second-arg tables
-- Skip plain counters like `local _work_ids = { n = 0 }` — only collect tables
-- whose *contents* are dense numeric literals (no field assignments). Every
-- balanced-brace group is walked so `local X = {...}` and `define(... {...} ...)`
-- (the exact shapes the Berserk/polymorph leaks used) cannot slip through.
--
-- Item-family tables (healthstones, mana gems, potions, dark runes, conjured
-- food/water) legitimately hold ITEM ids and are used via item-click, never
-- cast as spells — so their IDs must not be audited as spell IDs. They are
-- excluded by the ASSIGNMENT NAME: a name that ends in _IDS / _ID / _ITEM /
-- _ITEMS AND contains an item-family keyword (ITEM, POTION, GEM, SHARD, FOOD,
-- WATER, RUNE, HEALTHSTONE, SOUL). Spell tables that merely contain a keyword
-- but do NOT end in the ID suffix (e.g. MANA_GEM_CONJURE, CONJURE_MANA_GEM_SPELLS)
-- are still audited, as are debuff lists like SERPENT_STING_IDS (no keyword).
--
-- KNOWN LIMITATION (line-based scanner): only IDs inside a single-line brace
-- group are collected. A MULTI-LINE flat array (`local FOO = {` then `50334,`
-- on its own line) or a brace-less bare number (`local x = 50334`) is
-- invisible — the same limitation as the vanilla/WotLK audits. The historical
-- Berserk/polymorph leaks were single-line define-form, so the guard covers
-- the real attack surface; do not assume full multi-line coverage.
local function is_item_table_name(name)
    if not name or name == "" then return false end
    if not (name:match("_IDS$") or name:match("_ID$")
            or name:match("_ITEM$") or name:match("_ITEMS$")) then
        return false
    end
    return name:match("ITEM") ~= nil
        or name:match("POTION") ~= nil
        or name:match("GEM") ~= nil
        or name:match("SHARD") ~= nil
        or name:match("FOOD") ~= nil
        or name:match("WATER") ~= nil
        or name:match("RUNE") ~= nil
        or name:match("HEALTHSTONE") ~= nil
        or name:match("SOUL") ~= nil
end
local function extract_ids_from_line(line)
    local ids = {}
    local function collect(block)
        if block:find("=") then return end
        for n in block:gmatch("(%d+)") do
            local v = tonumber(n)
            -- Range covers all spell IDs across eras; 6-digit IDs (e.g. 348700)
            -- reach the WOTLK_ONLY / validity checks instead of being masked.
            if v >= 1000 and v <= 999999 then
                ids[#ids + 1] = v
            end
        end
    end
    -- Walk a block and RECURSE into any nested balanced-brace groups so
    -- single-line nested tables like
    --   magic = { spell = "DispelMagic", ids = { 988, 527 } }
    -- are fully covered (the outer group contains `=` so it is skipped by
    -- collect, but the inner ids group is visited recursively).
    local function walk(str)
        local pos = 1
        while true do
            local s, e = str:find("%b{}", pos)
            if not s then break end
            local body = str:sub(s + 1, e - 1)
            collect(body)
            walk(body)
            pos = e + 1
        end
    end
    local pos = 1
    while true do
        local s, e = line:find("%b{}", pos)
        if not s then break end
        -- Capture the assignment target directly before the brace group
        -- (`local NAME = {`, `NAME = {`, `foo.NAME = {`, or `or {` fallbacks).
        local prefix = line:sub(1, s - 1)
        local name = prefix:match("([%w_]+)%s*=%s*$")
            or prefix:match("local%s+([%w_]+)")
        -- Item-family tables are excluded at the assignment level; a nested
        -- keyed table inside a scanned group (e.g. `ids = {...}`) is walked.
        if not is_item_table_name(name) then
            local body = line:sub(s + 1, e - 1)
            -- collect() the OUTER body too: `ids = {5938},` ladder lines,
            -- `spell_ids = { 988, 527 }` hot-tick-tracker lines, and
            -- `define("Name", { 50334 }, ...)` second-arg tables are all FLAT
            -- (no nested braces) — walk() alone would skip every one of them.
            -- collect() skips bodies containing `=` (field-assignment tables),
            -- so nested `{ ids = {...}, levels = {...} }` spell_action blocks
            -- are still reached only via walk().
            collect(body)
            walk(body)
        end
        pos = e + 1
    end
    return ids
end

local function is_comment_line(line)
    return line:match("^%s*%-%-") ~= nil
end

local function scan_content(content, cross_era, sod)
    if type(content) ~= "string" then
        return { error = "content must be a string", hits = {} }
    end

    local hits = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if not is_comment_line(line) then
            local ids = extract_ids_from_line(line)
            if sod then
                -- SoD rune actions use the single-numeric define form
                -- (`Envenom = define("Envenom", 399963, ...)`) that the
                -- brace-group scanner cannot see — collect those ids too.
                for n in line:gmatch('define%(%s*"[^"]+"%s*,%s*(%d+)') do
                    local v = tonumber(n)
                    if v and v >= 1000 and v <= 999999 then
                        ids[#ids + 1] = v
                    end
                end
            end
            for _, id in ipairs(ids) do
                if WOTLK_ONLY_IDS[id] then
                    hits[#hits + 1] = {
                        line = line_no,
                        id = id,
                        kind = "WOTLK_ONLY",
                        desc = WOTLK_ONLY_IDS[id],
                        snippet = line:match("^%s*(.-)%s*$") or line,
                    }
                elseif sod and SOD_RUNE_IDS[id] then
                    -- allowed: pinned SoD rune/ability id (not in the 2.5.5 DBC)
                elseif not valid_spell_ids[id] then
                    -- Cross-era shared modules (talent_inference) legitimately
                    -- carry the verified WotLK max-rank signature heads; a TBC
                    -- client just never learns them, and they are pinned in the
                    -- WotLK audit. Class files never get this allowance.
                    if cross_era and SHARED_CROSS_ERA_IDS[id] then
                        -- allowed: cross-era signature head
                    else
                        local kind = "INVALID"
                        if valid_item_ids[id] then
                            kind = "ITEM_AS_SPELL"
                        end
                        hits[#hits + 1] = {
                            line = line_no,
                            id = id,
                            kind = kind,
                            snippet = (line:match("^%s*(.-)%s*$") or line):sub(1, 100),
                        }
                    end
                end
            end
        end
    end

    return { found = #hits > 0, hits = hits }
end

-- Ladder-label agreement: a define() label must describe the same spell as the
-- bridge name of each id it pins.  This is what turns "TBC-bridge-valid" into
-- "same spell": the sweep found SodHuntersMark headed by 30706 (Totem of Wrath),
-- SodVolley by 27019 (Arcane Shot) and SodAspectHawk by 13159 (Aspect of the
-- Pack) -- every one bridge-valid, so membership alone accepted lanes that cast
-- a different spell.  SoD labels carry a "Sod" prefix by convention; it is
-- stripped before comparison so the prefix is never the reason a check passes.
local function scan_name_agreement(content, sod, stats)
    if type(content) ~= "string" then return {} end
    return name_agreement.check_ladders(content, {
        index = spell_index,
        strip = sod and "Sod" or nil,
        stats = stats,
    })
end

-- Coverage accumulators (see spell_name_agreement.lua: a PASS that compared
-- nothing is not evidence).  The two tiers are counted separately so a shape
-- change that silently empties one of them is visible instead of averaging out.
local tbc_coverage = { ladders = 0, ids = 0, named = 0 }
local sod_coverage = { ladders = 0, ids = 0, named = 0 }

local function scan_file(filepath, sod)
    if not file_exists(filepath) then
        return { skipped = true, hits = {}, name_hits = {} }
    end
    local content = read_file(filepath)
    if not content then
        return { error = "could not read", hits = {}, name_hits = {} }
    end
    -- Cross-era flag is scoped to the shared talent_inference module only.
    local cross_era = CROSS_ERA_FILES[filepath:gsub("^" .. root .. "/", "")] == true
    local result = scan_content(content, cross_era, sod)
    -- Scope (widened 2026-09-13): the ladder-label check now runs on the TBC class
    -- tier as well as the SoD tier.  It was deferred because the TBC tier carries
    -- deliberate cross-spell ladders and abbreviated labels; that triage is done,
    -- and it came to 11 hits in four shapes, each written down rather than waved
    -- through: FrostArmor's Ice-Armor-first ladder and the HealingWave ladder that
    -- mixes in the Lesser Healing Wave ranks (both FALLBACK_LADDERS, naming the
    -- exact client string), plus RemoveCurse ("Remove Lesser Curse") and
    -- WaterElemental ("Summon Water Elemental").  Anything else now fails.
    result.name_hits = scan_name_agreement(content, sod, sod and sod_coverage or tbc_coverage)
    return result
end

-- ---------------------------------------------------------------------------
-- Self-tests (mirror the vanilla/WotLK audits' --self-test modes)
-- ---------------------------------------------------------------------------
local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    -- Malformed / missing input is controlled, not fatal.
    expect(scan_content(nil).error, "content must be a string", "malformed content")
    expect(scan_file("__missing_sylvanas_audit_fixture__.lua").skipped, true, "missing fixture")

    local function map_count(map)
        local n = 0
        for _ in pairs(map) do n = n + 1 end
        return n
    end

    -- Table integrity: every pinned WotLK-only ID must fire as a WOTLK_ONLY hit.
    local pinned = {}
    for id, desc in pairs(WOTLK_ONLY_IDS) do
        pinned[#pinned + 1] = { id = id, desc = desc }
    end
    expect(#pinned, 4, "WOTLK_ONLY_IDS size")
    local seen = {}
    for _, e in ipairs(pinned) do
        expect(seen[e.id], nil, "duplicate WOTLK_ONLY_IDS entry: " .. tostring(e.id))
        seen[e.id] = true
    end

    -- Every pinned WotLK-only rank must be flagged as WOTLK_ONLY, never silent.
    -- Probed in BOTH shapes the real leaks used: the nested spell_action form
    -- (`{ ids = { N } }`, class ladders) AND the flat define form
    -- (`Name = define("Name", { N }, "Name")`, spec ACTION tables) — the
    -- historical Berserk/polymorph leaks were flat define-form, so both must fire.
    local unfired = {}
    for _, e in ipairs(pinned) do
        local shapes = {
            "local PROBE = { ids = { " .. e.id .. " } }",
            "Berserk = define(\"Berserk\", { " .. e.id .. " }, \"Berserk\")",
        }
        for _, probe in ipairs(shapes) do
            local result = scan_content(probe)
            local fired = false
            for _, hit in ipairs(result.hits or {}) do
                if hit.id == e.id and hit.kind == "WOTLK_ONLY" then fired = true end
            end
            if not fired then
                unfired[#unfired + 1] = string.format("%d (%s) in shape %q", e.id, e.desc, probe)
            end
        end
    end
    expect(#unfired, 0, "all WOTLK_ONLY_IDS pins fire in both shapes (missed: " .. table.concat(unfired, "; ") .. ")")

    -- A known-valid TBC spell ID must NOT fire (30330 = Mortal Strike) in
    -- either shape.
    local valid = scan_content("local PROBE = { ids = { 30330 } }")
    expect(valid.found, false, "valid TBC ID must be silent (nested shape)")
    local valid2 = scan_content("Berserk = define(\"Berserk\", { 30330 }, \"Berserk\")")
    expect(valid2.found, false, "valid TBC ID must be silent (flat define shape)")

    -- Cross-era allowlist: every pinned WotLK max-rank signature head must be
    -- accepted in the cross-era shared module (cross_era=true) and REJECTED in
    -- a class-file context (cross_era=nil) — so the allowance can never leak
    -- into *_sylvanas.lua class files.
    local cross_count = 0
    for _ in pairs(SHARED_CROSS_ERA_IDS) do cross_count = cross_count + 1 end
    expect(cross_count, 12, "SHARED_CROSS_ERA_IDS size")
    local leaky = {}
    for id, desc in pairs(SHARED_CROSS_ERA_IDS) do
        local probe = "local PROBE = { ids = { " .. id .. " } }"
        local allowed = scan_content(probe, true)
        expect(allowed.found, false, "cross-era head allowed in shared module: " .. desc)
        local rejected = scan_content(probe)
        if not rejected.found then
            leaky[#leaky + 1] = string.format("%d (%s)", id, desc)
        end
    end
    expect(#leaky, 0, "cross-era heads rejected in class-file context (leaked: " .. table.concat(leaky, "; ") .. ")")

    -- Inventory: no duplicate file entries.
    local seen_files = {}
    for _, f in ipairs(SYLVANAS_FILES) do
        expect(seen_files[f], nil, "duplicate inventory entry: " .. tostring(f))
        seen_files[f] = true
    end
    for _, f in ipairs(SOD_FILES) do
        expect(seen_files[f], nil, "duplicate SoD inventory entry: " .. tostring(f))
        seen_files[f] = true
    end
    expect(#SOD_FILES, 20, "SOD_FILES size")

    -- SoD tier: pinned rune ids (single-numeric define form) must be silent in
    -- sod mode, flagged INVALID without it (proves the pin unlocks them), and
    -- an UNPINNED rune id must fail even in sod mode.
    local sod_pinned_count = 0
    for _ in pairs(SOD_RUNE_IDS) do sod_pinned_count = sod_pinned_count + 1 end
    expect(sod_pinned_count, 65, "SOD_RUNE_IDS size") -- +1 Earth Shield 408514 (shaman restoration guide pass 2026-09-09)
    local dup_runes = {}
    for id in pairs(SOD_RUNE_IDS) do
        if dup_runes[id] then error("duplicate SOD_RUNE_IDS entry: " .. tostring(id)) end
        dup_runes[id] = true
        if id < 399000 then
            error("SOD_RUNE_IDS entry below the SoD rune range: " .. tostring(id))
        end
    end
    local sod_pinned = scan_content(
        "Envenom = define(\"Envenom\", 399963, { rune_id = 399963 }, \"Envenom\")", nil, true)
    expect(sod_pinned.found, false, "pinned SoD rune id silent in sod mode (single-numeric define)")
    local sod_unlocked = scan_content(
        "Envenom = define(\"Envenom\", { 399963 }, \"Envenom\")")
    expect(sod_unlocked.found, true, "pinned SoD rune id INVALID without the sod flag")
    local sod_unpinned = scan_content(
        "NewRune = define(\"NewRune\", 412345, { rune_id = 412345 }, \"NewRune\")", nil, true)
    expect(sod_unpinned.found, true, "unpinned rune id fails in sod mode")
    local sod_tbc = scan_content(
        "Eviscerate = define(\"Eviscerate\", { 31016 }, nil, \"Eviscerate\")", nil, true)
    expect(sod_tbc.found, false, "TBC-bridge ladder id silent in sod mode")
    local sod_wotlk = scan_content(
        "Berserk = define(\"Berserk\", { 50334 }, \"Berserk\")", nil, true)
    expect(sod_wotlk.found, true, "WotLK-only id still fires in sod mode")

    -- Masking-gap helper: is_tracked() must resolve the EaxRotations-relative
    -- inventory form against the repo-root git ls-files form. Feed a synthetic
    -- tracked set and assert both the hit and the miss.
    local saved_tracked = TRACKED
    TRACKED = {
        ["EaxRotations/classes/warrior/arms_sylvanas.lua"] = true,
    }
    expect(is_tracked("classes/warrior/arms_sylvanas.lua"), true, "tracked inventory entry resolves")
    expect(is_tracked("classes/mage/arcane_sylvanas.lua"), false, "untracked inventory entry stays clear")
    TRACKED = saved_tracked

    -- Name agreement ("TBC-bridge-valid" must mean "same spell").  Every one of
    -- the sweep's SoD live defects was a bridge-VALID id pinned under a label
    -- naming a different spell, so this is the check that closes that class.
    local function agrees(label, bridge)
        return (name_agreement.name_agrees(label, bridge))
    end
    expect(agrees("HuntersMark", "Hunter's Mark"), true, "plural label, possessive client name")
    expect(agrees("SurvivalInstincts", "Survival Instinct"), true, "plural label, singular client name")
    expect(agrees("AvengerShield", "Avenger's Shield"), true, "possessive client name")
    expect(agrees("HealingWave", "Lesser Healing Wave"), false, "a spell-family qualifier is not a free pass")
    expect(agrees("RemoveCurse", "Remove Lesser Curse"), false, "nor is it one for the same-spell title")
    expect(agrees("WaterElemental", "Summon Water Elemental"), true, "a client verb on the same spell is forgiven")
    expect(agrees("HuntersMark", "Totem of Wrath"), false, "wrong spell (SodHuntersMark/30706 shape)")
    expect(agrees("AspectHawk", "Aspect of the Pack"), false, "same prefix, different spell")
    expect(agrees("Volley", "Arcane Shot"), false, "wrong spell (SodVolley/27019 shape)")
    expect(agrees("DemoralizingRoar", "Faerie Fire (Feral)"), false, "wrong spell (SodDemoralizingRoar/16857 shape)")
    expect(agrees("Devastate", "Sunder Armor"), false, "fallback id is not a rule-level free pass")

    -- Ladder-level non-vacuity in the exact SoD shape: the label carries the SoD
    -- prefix and the offending id (30706 Totem of Wrath) is TBC-bridge-VALID, so
    -- the id-existence scan alone is silent on it.
    local bad_sod = scan_name_agreement(
        'HuntersMark = define("SodHuntersMark", { 14325, 30706 }, {}, "HuntersMark")', true)
    expect(#bad_sod, 1, "mislabelled SoD ladder id flagged")
    expect(bad_sod[1].id, 30706, "flagged SoD ladder id")
    expect(bad_sod[1].bridge, "Totem of Wrath", "flagged SoD bridge name")
    local ok_sod = scan_name_agreement(
        'HuntersMark = define("SodHuntersMark", { 14325, 14324, 14323, 1130 }, {}, "HuntersMark")', true)
    expect(#ok_sod, 0, "correct SodHuntersMark ladder clean")

    -- The one documented cross-spell fallback ladder is excused by LABEL plus the
    -- exact client name, and ONLY when the ladder head agrees, so it cannot be
    -- used to smuggle an arbitrary id in.
    expect(#scan_name_agreement(
        'Devastate = define("SodDevastate", { 20243, 11597 }, {}, "Devastate")', true), 0,
        "documented SoD Devastate fallback accepted")
    expect(#scan_name_agreement(
        'Devastate = define("SodDevastate", { 20243, 16857 }, {}, "Devastate")', true), 1,
        "fallback allowance does not cover other ids")
    expect(#scan_name_agreement(
        'Devastate = define("SodDevastate", { 11597 }, {}, "Devastate")', true), 1,
        "fallback allowance needs an agreeing head")
    local fallback_count = 0
    for _ in pairs(name_agreement.FALLBACK_LADDERS) do fallback_count = fallback_count + 1 end
    expect(fallback_count, 4, "documented label/client-name exception count")

    -- Each allowance is checked as both halves: it excuses the exact client string
    -- written down and NOTHING else, and it never becomes a label-wide free pass.
    -- FrostArmor and RemoveCurse carry allow_disagreeing_head (their HEAD is the
    -- excused string); HealingWave keeps the normal head-agreement condition, so a
    -- ladder that leads with the other spell is still a mismatch.
    expect(#scan_name_agreement(
        'FrostArmor = define("FrostArmor", { 27124, 7301, 168 }, {}, "FrostArmor")', nil), 0,
        "Ice-Armor-first FrostArmor ladder accepted")
    expect(#scan_name_agreement(
        'FrostArmor = define("FrostArmor", { 27124, 30706 }, {}, "FrostArmor")', nil), 1,
        "FrostArmor allowance does not cover other ids")
    expect(#scan_name_agreement(
        'RemoveCurse = define("RemoveCurse", { 475 }, {}, "RemoveCurse")', nil), 0,
        "Remove Lesser Curse accepted under the RemoveCurse label")
    expect(#scan_name_agreement(
        'RemoveCurse = define("RemoveCurse", { 527 }, {}, "RemoveCurse")', nil), 1,
        "RemoveCurse allowance does not cover a different spell")
    expect(#scan_name_agreement(
        'HealingWave = define("HealingWave", { 25396, 10468 }, {}, "HealingWave")', nil), 0,
        "Lesser Healing Wave ranks in a HealingWave ladder accepted")
    expect(#scan_name_agreement(
        'HealingWave = define("HealingWave", { 10468 }, {}, "HealingWave")', nil), 1,
        "HealingWave allowance still needs an agreeing head")
    -- "Summon Water Elemental" is the same spell under its client title, so it is a
    -- token (whole-word, verb only), not a ladder allowance.
    expect(#scan_name_agreement(
        'WaterElemental = define("WaterElemental", { 31687 }, {}, "WaterElemental")', nil), 0,
        "Summon Water Elemental accepted under the WaterElemental label")
    expect(#scan_name_agreement(
        'WaterElemental = define("WaterElemental", { 31687, 11426 }, {}, "WaterElemental")', nil), 1,
        "the Summon qualifier does not cover an unrelated id")

    -- Live TBC class inventory must be name-clean at the tier this check was just
    -- extended to.  The 11 hits that motivated the deferral are the four shapes now
    -- excused above; anything new fails right here.
    local live_tbc_names = 0
    local tbc_cov = {}
    for _, file in ipairs(SYLVANAS_FILES) do
        local body = read_file(root .. "/" .. file)
        if body then live_tbc_names = live_tbc_names + #scan_name_agreement(body, nil, tbc_cov) end
    end
    expect(live_tbc_names, 0, "no live TBC class ladder label disagreements")
    expect(tbc_cov.ladders or 0, 717, "TBC name-agreement coverage: labelled ladders compared")
    expect(tbc_cov.ids or 0, 2974, "TBC name-agreement coverage: ids compared")
    expect(tbc_cov.named or 0, 2974, "TBC name-agreement coverage: ids the bridge names")

    -- Live SoD inventory must be name-clean (the audit's own HARD-bucket zero).
    local live_sod_names = 0
    local sod_cov = {}
    for _, file in ipairs(SOD_FILES) do
        local body = read_file(root .. "/" .. file)
        if body then live_sod_names = live_sod_names + #scan_name_agreement(body, true, sod_cov) end
    end
    expect(live_sod_names, 0, "no live SoD ladder label disagreements")
    expect(sod_cov.ladders or 0, 199, "SoD name-agreement coverage: labelled ladders compared")
    expect(sod_cov.ids or 0, 385, "SoD name-agreement coverage: ids compared")
    expect(sod_cov.named or 0, 308, "SoD name-agreement coverage: ids the bridge names")

    print("[PASS] Sylvanas audit self-tests: malformed input, all 4 WOTLK_ONLY_IDS pins fire, all 12 cross-era heads scoped to shared module only, valid TBC ID silent, no duplicate inventory entries, SoD tier (58 pinned rune ids / single-numeric define scan / unpinned rune fails / WotLK leak fires), name agreement (12 rule cases + SoD ladder probe + four exception gates + live SoD AND live TBC class inventories, coverage pinned 717/2974 TBC and 199/385 SoD), masking-gap helper resolves")
end

local function run_name_probe()
    -- Non-vacuity: 30706 (Totem of Wrath) is TBC-bridge-VALID, so the id-existence
    -- scan is silent on it -- only the name-agreement check rejects the
    -- SodHuntersMark label.  That is precisely the "bridge-valid means same spell"
    -- gap this assertion closes.
    local probe = 'HuntersMark = define("SodHuntersMark", { 14325, 30706 }, {}, "HuntersMark")'
    local ids = scan_content(probe, nil, true)
    local name_hits = scan_name_agreement(probe, true)
    if ids.error or ids.found then
        print("[ERROR] name probe was not bridge-valid (the id scan already rejects it)")
        os.exit(2)
    end
    if #name_hits == 0 then
        print("[ERROR] name probe did not flag a bridge-valid wrong-spell id")
        os.exit(2)
    end
    print(string.format("[FAIL] name-agreement probe rejected as expected: id %d [NAME_MISMATCH] label %q vs bridge %q",
        name_hits[1].id, name_hits[1].label, name_hits[1].bridge))
    os.exit(1)
end

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------
if arg and arg[1] == "--self-test" then
    run_self_tests()
    os.exit(0)
elseif arg and arg[1] == "--probe-name" then
    run_name_probe()
end

print("=============================================================================")
print("  SYLVANAS SPELL ID AUDIT (positive DBC existence check)")
print("  Source: wowheadScrape/dbc_extract/wowsims.db (client 2.5.5.68101)")
print(string.format("  Bridge: %d TBC spells, %d items loaded", spell_count, item_count))
print("=============================================================================")
print("")

local total, skipped, passed, failed = 0, 0, 0, 0
local failures = {}
local skipped_files = {}

local tracked_ok = load_tracked()
if not tracked_ok then
    print("")
    print("  [ERROR] masking-gap check could not run: git ls-files returned nothing")
    print("          (git missing, popen failure, or empty repo). The audit would")
    print("          silently skip covering real repo files. Run inside a git checkout.")
    os.exit(1)
end

local SCAN_LIST = {}
for _, file in ipairs(SYLVANAS_FILES) do
    SCAN_LIST[#SCAN_LIST + 1] = { file = file }
end
for _, file in ipairs(SOD_FILES) do
    SCAN_LIST[#SCAN_LIST + 1] = { file = file, sod = true }
end

for _, entry in ipairs(SCAN_LIST) do
    local file = entry.file
    local path = root .. "/" .. file
    total = total + 1

    local result = scan_file(path, entry.sod)
    local name_hits = result.name_hits or {}
    if result.skipped then
        skipped = skipped + 1
        skipped_files[#skipped_files + 1] = file
    elseif result.error then
        failed = failed + 1
        failures[#failures + 1] = { file = file, error = result.error }
        print(string.format("  [ ERROR ] %-50s %s", file, result.error))
    elseif result.found or #name_hits > 0 then
        failed = failed + 1
        failures[#failures + 1] = { file = file, hits = result.hits, name_hits = name_hits }
        print(string.format("  [ FAIL ]  %-50s %d invalid ID(s), %d name mismatch(es)",
            file, #result.hits, #name_hits))
        for _, hit in ipairs(result.hits) do
            print(string.format("            line %4d: id %d [%s]  %s",
                hit.line, hit.id, hit.kind, hit.snippet))
        end
        for _, hit in ipairs(name_hits) do
            print(string.format("            line %4d: id %d [NAME_MISMATCH]  label %q vs bridge %q (unmatched: %s)",
                hit.line, hit.id, hit.label, hit.bridge, table.concat(hit.extra or {}, ",")))
        end
    else
        passed = passed + 1
        print(string.format("  [ PASS ]  %-50s clean", file))
    end
end

print("")
print("=============================================================================")
print("  SYLVANAS SPELL AUDIT RESULTS")
print("=============================================================================")
print(string.format("  Total:     %3d sylvanas files (incl. %d SoD loaders)", total, #SOD_FILES))
print(string.format("  Ladder-label check: TBC %d ladder(s) / %d id(s) (%d named) | SoD %d / %d (%d named)",
    tbc_coverage.ladders or 0, tbc_coverage.ids or 0, tbc_coverage.named or 0,
    sod_coverage.ladders or 0, sod_coverage.ids or 0, sod_coverage.named or 0))
print(string.format("  Skipped:   %3d (file not present)", skipped))
print(string.format("  Clean:     %3d", passed))
print(string.format("  Invalid:   %3d", failed))

-- Masking-gap check: a skipped inventory entry that is git-tracked means a
-- real repo file exists but the audit could not read it at its expected
-- path (deleted from the worktree, case mismatch on case-sensitive CI, or
-- a stale inventory entry pointing at a moved file). The audit would
-- silently stop covering that file — a masking gap, not a legit skip.
local masked = {}
for _, file in ipairs(skipped_files) do
    if is_tracked(file) then
        masked[#masked + 1] = file
    end
end
if #masked > 0 then
    print(string.format("  Masked:    %3d (git-tracked but reported skipped)", #masked))
end
print("")

if failed > 0 or #masked > 0 then
    if failed > 0 then
        print("  Invalid spell IDs found in sylvanas files:")
        for _, f in ipairs(failures) do
            if f.error then
                print("    " .. f.file .. "  ERROR: " .. f.error)
            else
                for _, hit in ipairs(f.hits) do
                    print(string.format("    %s  line %d: id %d [%s]",
                        f.file, hit.line, hit.id, hit.kind))
                end
                for _, hit in ipairs(f.name_hits or {}) do
                    print(string.format("    %s  line %d: id %d [NAME_MISMATCH] label %q vs bridge %q",
                        f.file, hit.line, hit.id, hit.label, hit.bridge))
                end
            end
        end
        print("")
        print("  ID 'ITEM_AS_SPELL' means the ID exists in item_index but not spell_index.")
        print("  ID 'INVALID' means the ID exists in neither — definitely a bug.")
        print("  NAME_MISMATCH means a define() label and the bridge name of one of its ids")
        print("  describe different spells: bridge-valid, but NOT the same spell.")
    end
    if #masked > 0 then
        print("  Masking gaps (git-tracked files the audit could not scan):")
        for _, f in ipairs(masked) do
            print("    " .. f)
        end
        print("")
        print("  A 'Masked' entry means the file exists in git but was reported skipped —")
        print("  the audit silently stopped covering it. Fix the worktree/inventory so it is")
        print("  scanned (mirror the WotLK audit's zero-skip strictness).")
    end
    os.exit(1)
end

print("  All sylvanas files clean — every spell ID exists in DBC, zero masking gaps.")
os.exit(0)
