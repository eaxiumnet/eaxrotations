-- test_druid_resto_forever.lua -- unit pins for the druid resto Forever delta.
-- WHAT:  resto_forever.lua contract: baseline capture + re-register splice
--        (Wild Growth above SwiftmendEmergency, the Swiftmend spot-heal
--        right after it, the Rejuv blanket above PriorityRejuvenation), the
--        Gift-of-the-Earthmother learned gate, the healing-entry scans,
--        by-name dormancy, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Wild Growth is the kit's new party heal (6s CD) and the non-
--        consuming Swiftmend turns an emergency-only button into a spot
--        heal; both are entry-scan lanes — losing the hurt-count or HoT
--        gates either wastes the CD on healthy groups or makes Swiftmend
--        shadow the emergency lane.
-- SAFETY: fully mocked NS + require (fake baseline module).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

local pass, fail = 0, 0
local function assert_true(v, label)
    if v then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. tostring(label)) end
end
local function assert_eq(a, b, label)
    if a == b then pass = pass + 1
    else fail = fail + 1; print("  FAIL: " .. tostring(label) .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")") end
end

local registered = nil
local cast_log = {}
local learnt = {}
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = {},
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    DruidSpells = {
        Swiftmend = { ids = { 18562 } },
        Rejuvenation = { ids = { 774 } },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
    healing_get_tank = function(entries, count) return entries and entries[2] or nil end,
    healing_get_lowest_hp = function(entries, count, threshold)
        local best = nil
        for i = 1, (count or 0) do
            local entry = entries[i]
            if entry and (not best or (entry.effective_hp or 100) < (best.effective_hp or 100)) then best = entry end
        end
        return best
    end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "resto",
    strategies = {
        { name = "BarkskinSelfPreservation", matches = function() return false end, execute = function() return false end },
        { name = "InnervateSelf", matches = function() return false end, execute = function() return false end },
        { name = "SwiftmendEmergency", matches = function() return false end, execute = function() return false end },
        { name = "NaturesSwiftness", matches = function() return false end, execute = function() return false end },
        { name = "RegrowthSpotHeal", matches = function() return false end, execute = function() return false end },
        { name = "PriorityRejuvenation", matches = function() return false end, execute = function() return false end },
        { name = "FallbackHealingTouch", matches = function() return false end, execute = function() return false end },
    },
    options = { get_state = function() return { fake = true } end },
}

local orig_require = require
local pending_by_name, pending_maxrank, pending_buff = {}, {}, {}
local scan_entries, scan_count = nil, 0
function require(path)
    if path == "shared/wowhead_data_bridge_spell_index_forever_sylvanas" then
        return { spell_index_by_name_forever = pending_by_name,
                 spell_maxrank_by_name_forever = pending_maxrank,
                 spell_buff_by_name_forever = pending_buff }
    end
    if path == "classes/druid/healing_sylvanas" then
        return { scan_healing_targets = function() return scan_entries, scan_count end }
    end
    if path == "classes/druid/resto_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/druid/resto_vanilla' not found", 0)
    end
    if path == "shared/spec_kit_sylvanas" then
        return { setting = function(_, key, default) return default end }
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/druid/resto_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function mk_entry(hp, hot)
    return { unit = {}, effective_hp = hp, hp = hp, has_rejuvenation = hot == true }
end

local function fresh_ctx()
    return { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {}, is_moving = false }
end

local function mk_state(entries)
    local state = { in_combat = true, mana_pct = 80, entries = entries, count = #entries }
    state.lowest = entries[1]
    state.tank = entries[2]
    scan_entries, scan_count = entries, #entries
    return state
end

-- A. Full kit: three lanes in their slots.
do
    learnt = {}
    learnt[19133] = true
    local combined = load_delta({}, { ["Wild Growth"] = 19134, ["Gift of the Earthmother"] = 19133 }, {})
    assert_eq(registered and registered.name, "resto", "A: re-registers the resto playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 3, "A: 3 delta lanes over 7 baseline lanes")
    local sm = find_lane(combined, "SwiftmendEmergency")
    assert_eq(find_lane(combined, "Forever_WildGrowth"), sm - 1, "A: Wild Growth leads the heal block")
    assert_eq(find_lane(combined, "Forever_SwiftmendSpotHeal"), sm + 1, "A: the spot-heal follows the emergency lane")
    assert_true(find_lane(combined, "Forever_RejuvBlanket") < find_lane(combined, "PriorityRejuvenation"),
        "A: the blanket sits above the baseline Rejuvenation lane")
    assert_true(find_lane(combined, "Forever_RejuvBlanket") < find_lane(combined, "RegrowthSpotHeal"),
        "A: the blanket sits above the regrowth spot-heal too (first anchor)")
    assert_eq(find_lane(combined, "BarkskinSelfPreservation"), 1, "A: defensive head lanes untouched")
    learnt = {}
end

-- B. Wild Growth matcher: hurt-count gate, CD declaration, tank anchor.
do
    learnt = {}
    local combined = load_delta({}, { ["Wild Growth"] = 19134 }, {})
    local wg = combined[find_lane(combined, "Forever_WildGrowth")]
    local ctx = fresh_ctx()

    local two_hurt = mk_state({ mk_entry(60), mk_entry(80), mk_entry(100) })
    local seen_opts = nil
    local orig_ready = NS.spell_ready
    NS.spell_ready = function(spell, target, opts) seen_opts = opts; return true end
    assert_true(wg.matches(ctx, two_hurt), "B: Wild Growth fires with two hurt members")
    assert_eq(seen_opts and seen_opts.expected_cooldown, 6, "B: Wild Growth declares the DBC 6s cooldown")
    NS.spell_ready = orig_ready
    local one_hurt = mk_state({ mk_entry(60), mk_entry(100), mk_entry(100) })
    assert_true(not wg.matches(ctx, one_hurt), "B: Wild Growth holds with a single hurt member")
    local poor = mk_state({ mk_entry(60), mk_entry(80), mk_entry(100) })
    poor.mana_pct = 5
    assert_true(not wg.matches(ctx, poor), "B: Wild Growth respects the mana floor")
    scan_entries, scan_count = two_hurt.entries, #two_hurt.entries
    cast_log = {}
    assert_true(wg.execute(ctx, two_hurt), "B: Wild Growth executes on a hurt group")
    assert_eq(cast_log[1] and cast_log[1].target, two_hurt.tank.unit, "B: the tank anchors the party HoT when hurt")
end

-- B2. Swiftmend spot-heal: HoT-carrying allies inside the broad window.
do
    learnt = {}
    local combined = load_delta({}, {}, {})
    local spot = combined[find_lane(combined, "Forever_SwiftmendSpotHeal")]
    local ctx = fresh_ctx()

    local with_hot = mk_state({ mk_entry(85, true), mk_entry(100, false) })
    assert_true(spot.matches(ctx, with_hot), "B2: spot-heal fires on a HoT-carrying ally")
    cast_log = {}
    assert_true(spot.execute(ctx, with_hot), "B2: spot-heal executes")
    assert_eq(cast_log[1] and cast_log[1].target, with_hot.entries[1].unit, "B2: spot-heal targets the HoT carrier")
    local no_hot = mk_state({ mk_entry(85, false), mk_entry(100, false) })
    assert_true(not spot.matches(ctx, no_hot), "B2: spot-heal holds without any HoT carrier")
    local healthy = mk_state({ mk_entry(98, true), mk_entry(100, false) })
    assert_true(not spot.matches(ctx, healthy), "B2: spot-heal holds above the hurt window")
end

-- B3. Rejuv blanket: GotE-gated, tops up un-HoT'd members.
do
    learnt = {}
    learnt[19133] = true
    local combined = load_delta({}, { ["Gift of the Earthmother"] = 19133 }, {})
    local blanket = combined[find_lane(combined, "Forever_RejuvBlanket")]
    local ctx = fresh_ctx()

    local covers = mk_state({ mk_entry(100, true), mk_entry(94, false) })
    assert_true(blanket.matches(ctx, covers), "B3: blanket fires for an un-HoT'd member inside the window")
    cast_log = {}
    assert_true(blanket.execute(ctx, covers), "B3: blanket executes")
    assert_eq(cast_log[1] and cast_log[1].target, covers.entries[2].unit, "B3: blanket targets the un-HoT'd member")
    local all_hot = mk_state({ mk_entry(90, true), mk_entry(94, true) })
    assert_true(not blanket.matches(ctx, all_hot), "B3: blanket holds when everyone carries the HoT")
    local poor = mk_state({ mk_entry(90, false), mk_entry(94, false) })
    poor.mana_pct = 5
    assert_true(not blanket.matches(ctx, poor), "B3: blanket respects the mana floor")
    learnt = {}
    local without = load_delta({}, {}, {})
    assert_true(not find_lane(without, "Forever_RejuvBlanket"), "B3: no blanket lane without the talent")
end

-- C. Dormancy: empty mirrors keep only the class-map spot-heal lane.
do
    learnt = {}
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "C: only the class-map spot-heal splices")
    assert_true(not find_lane(combined, "Forever_WildGrowth"), "C: Wild Growth dormant")
    assert_true(not find_lane(combined, "Forever_RejuvBlanket"), "C: blanket dormant")
    assert_true(find_lane(combined, "Forever_SwiftmendSpotHeal"), "C: spot-heal present (class map)")
end

-- D. Splice fallback: no anchors appends the lanes in order.
do
    FAKE_BASELINE.strategies = {
        { name = "InnervateSelf", matches = function() return false end, execute = function() return false end },
    }
    learnt = {}
    learnt[19133] = true
    local combined = load_delta({}, { ["Wild Growth"] = 19134, ["Gift of the Earthmother"] = 19133 }, {})
    assert_eq(find_lane(combined, "Forever_WildGrowth"), #combined - 2, "D: Wild Growth appends first")
    assert_eq(find_lane(combined, "Forever_SwiftmendSpotHeal"), #combined - 1, "D: spot-heal next")
    assert_eq(find_lane(combined, "Forever_RejuvBlanket"), #combined, "D: blanket last")
    learnt = {}
end

-- G. Mirror selection: Wild Growth casts the maxrank sentinel; the blanket's
-- learned gate reads the same mirror.
do
    learnt = {}
    learnt[19133] = true
    local combined = load_delta({}, { ["Wild Growth"] = 19134, ["Gift of the Earthmother"] = 19133 }, {})
    local ctx = fresh_ctx()
    local state = mk_state({ mk_entry(60), mk_entry(80), mk_entry(100) })
    local wg = combined[find_lane(combined, "Forever_WildGrowth")]
    cast_log = {}
    assert_true(wg.execute(ctx, state), "G: Wild Growth executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19134, "G: Wild Growth casts the maxrank sentinel")
    learnt = {}
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/druid/resto_forever.lua", "r")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    assert_true(#content > 0, "E: delta source readable")
    local bad = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if line:match("^%s*%-%-") ~= nil then
            -- comment line: exempt
        else
            for table_part in line:gmatch("(%b{})") do
                local inner = table_part:sub(2, -2)
                if inner:match("^[%s%d,]*$") then
                    for num in inner:gmatch("%d+") do
                        if tonumber(num) >= 100 then bad[#bad + 1] = line_no .. ":" .. num end
                    end
                end
            end
        end
    end
    assert_eq(#bad, 0, "E: zero numeric ID literals in code (found: " .. table.concat(bad, ", ") .. ")")
end

-- F. Baseline load failure is loud.
do
    FAKE_BASELINE = nil
    local ok, err = pcall(load_delta, {})
    assert_true(not ok, "F: delta errors when the baseline cannot load")
    assert_true(tostring(err):find("baseline load failed", 1, true) ~= nil, "F: error names the baseline failure")
end

require = orig_require

print(string.format("test_druid_resto_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS druid_resto_forever")
