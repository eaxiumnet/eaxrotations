-- test_shaman_enhancement_forever.lua -- unit pins for the shaman enhancement Forever delta.
-- WHAT:  enhancement_forever.lua contract: baseline capture + re-register
--        splice, lane set and ordering, by-name dormancy before the beta
--        DBC, matcher behavior, zero-numeric-literal audit contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   a lost baseline lane, a lane firing while dormant-resolved, or a
--        hardcoded spell ID each silently break day-1 enhancement.
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
local PLAYER_UNIT_REF = {}
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = PLAYER_UNIT_REF,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    ShamanSpells = {
        Stormstrike = { ids = { 17364 } },
        LightningBolt = { ids = { 49238, 27070, 25449 } },
    },
    has_player_buff = function() return false end,
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    cooldown_remains = function() return 0 end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "enhancement",
    strategies = {
        { name = "AutoAttack", matches = function() return false end, execute = function() return false end },
        { name = "FireNovaReplacement", matches = function() return false end, execute = function() return false end },
        { name = "Stormstrike", matches = function() return false end, execute = function() return false end },
        { name = "LightningBolt", matches = function() return false end, execute = function() return false end },
    },
    options = { get_state = function() return { fake = true } end },
}

local orig_require = require
local pending_by_name, pending_maxrank, pending_buff = {}, {}, {}
function require(path)
    if path == "shared/wowhead_data_bridge_spell_index_forever_sylvanas" then
        return { spell_index_by_name_forever = pending_by_name,
                 spell_maxrank_by_name_forever = pending_maxrank,
                 spell_buff_by_name_forever = pending_buff }
    end
    if path == "classes/shaman/enhancement_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/shaman/enhancement_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/shaman/enhancement_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

-- A. Full kit: bridge names resolve in every mirror; splice + registration shape.
do
    local combined = load_delta({ ["Maelstrom Weapon"] = 19004, ["Fire Nova"] = 19005 },
        { ["Fire Nova"] = 19105 }, { ["Maelstrom Weapon"] = 19204 })
    assert_eq(registered and registered.name, "enhancement", "A: re-registers the enhancement playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 3, "A: 3 delta lanes over 4 baseline lanes")
    assert_eq(find_lane(combined, "Forever_MaelstromWeave"), 4, "A: MW weave above SS core")
    assert_eq(find_lane(combined, "Forever_StormstrikeCore"), 5, "A: SS core above baseline Stormstrike")
    local nova_i = find_lane(combined, "Forever_FireNovaSpell")
    local fnr = find_lane(combined, "FireNovaReplacement")
    assert_true(nova_i and fnr and nova_i == fnr - 1, "A: Fire Nova sits just above FireNovaReplacement")
    assert_true(find_lane(combined, "AutoAttack") ~= nil, "A: baseline lanes preserved")
end

-- B. Matcher behavior.
do
    local combined = load_delta({ ["Maelstrom Weapon"] = 19004, ["Fire Nova"] = 19005 },
        { ["Fire Nova"] = 19105 }, { ["Maelstrom Weapon"] = 19204 })
    local state = { mana_pct = 80 }
    local ctx = { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }

    local mw = combined[find_lane(combined, "Forever_MaelstromWeave")]
    NS.has_player_buff = function() return true end
    assert_true(mw.matches(ctx, state), "B: MW weave matches with buff + mana")
    NS.has_player_buff = function() return false end
    assert_true(not mw.matches(ctx, state), "B: MW weave dormant without the buff")
    state.mana_pct = 10
    NS.has_player_buff = function() return true end
    assert_true(not mw.matches(ctx, state), "B: MW weave respects the mana floor")
    state.mana_pct = 80

    local core = combined[find_lane(combined, "Forever_StormstrikeCore")]
    assert_true(core.matches(ctx, state), "B: SS core matches with a valid enemy")
    local no_target = { in_combat = true, has_valid_enemy_target = false, me = {}, settings = {} }
    assert_true(not core.matches(no_target, state), "B: SS core holds without an enemy")

    local nova = combined[find_lane(combined, "Forever_FireNovaSpell")]
    assert_true(nova.matches(ctx, state), "B: Fire Nova matches with mana")
    state.mana_pct = 10
    assert_true(not nova.matches(ctx, state), "B: Fire Nova respects the mana floor")
    state.mana_pct = 80
end

-- B2. Maelstrom Weapon stack gate (DBC: CumulativeAura 5): spend at the cap,
-- hold below it, and fail open when the stack read is unusable (0/nil).
do
    local combined = load_delta({ ["Maelstrom Weapon"] = 19004, ["Fire Nova"] = 19005 },
        { ["Fire Nova"] = 19105 }, { ["Maelstrom Weapon"] = 19204 })
    local state = { mana_pct = 80 }
    local ctx = { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }
    local mw = combined[find_lane(combined, "Forever_MaelstromWeave")]

    NS.has_player_buff = function() return true end
    NS.buff_stacks = function() return 5 end
    assert_true(mw.matches(ctx, state), "B2: MW weave fires at the 5-stack cap")
    NS.buff_stacks = function() return 3 end
    assert_true(not mw.matches(ctx, state), "B2: MW weave holds below the stack cap")
    NS.buff_stacks = function() return 0 end
    assert_true(mw.matches(ctx, state), "B2: MW weave fails open on a 0 (unusable) stack read")
    NS.buff_stacks = nil
    assert_true(mw.matches(ctx, state), "B2: MW weave fails open when buff_stacks is unavailable")
    NS.has_player_buff = function() return false end
end

-- B3. Fire Nova live-fire-totem gate: the Forever cast detonates the active
-- Fire Totem, so no totem -> no cast (all three client shapes: table with
-- have_totem, the battery's no-totem false, and an unavailable API).
do
    local combined = load_delta({ ["Maelstrom Weapon"] = 19004, ["Fire Nova"] = 19005 },
        { ["Fire Nova"] = 19105 }, { ["Maelstrom Weapon"] = 19204 })
    local state = { mana_pct = 80 }
    local ctx = { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }
    local nova = combined[find_lane(combined, "Forever_FireNovaSpell")]

    NS.get_totem_info = function(slot) return { have_totem = true, spell_id = 0 } end
    assert_true(nova.matches(ctx, state), "B3: Fire Nova fires with a live fire totem")
    NS.get_totem_info = function() return false end
    assert_true(not nova.matches(ctx, state), "B3: Fire Nova holds with no fire totem (false shape)")
    NS.get_totem_info = function() return { have_totem = false } end
    assert_true(not nova.matches(ctx, state), "B3: Fire Nova holds with no fire totem (table shape)")
    NS.get_totem_info = nil
    assert_true(nova.matches(ctx, state), "B3: Fire Nova fails open when get_totem_info is unavailable")
    state.mana_pct = 10
    assert_true(not nova.matches(ctx, state), "B3: Fire Nova still respects the mana floor")
    state.mana_pct = 80
    ctx.has_valid_enemy_target = false
    assert_true(not nova.matches(ctx, state), "B3: Fire Nova needs a valid enemy")
    ctx.has_valid_enemy_target = true
end

-- C. Dormancy on nil lookups: empty mirrors leave lanes out.
do
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "C: only the always-resolvable SS core exists on empty mirrors")
    assert_true(find_lane(combined, "Forever_StormstrikeCore"), "C: SS core present")
    assert_true(not find_lane(combined, "Forever_MaelstromWeave"), "C: MW weave dormant")
    assert_true(not find_lane(combined, "Forever_FireNovaSpell"), "C: Fire Nova dormant")
    local ss = find_lane(combined, "Stormstrike")
    assert_eq(find_lane(combined, "Forever_StormstrikeCore"), ss - 1, "C: core still spliced above baseline SS")
end

-- D. Splice fallback: missing anchors append.
do
    FAKE_BASELINE.strategies = {
        { name = "AutoAttack", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({ ["Maelstrom Weapon"] = 19004 }, {}, { ["Maelstrom Weapon"] = 19204 })
    assert_eq(find_lane(combined, "Forever_MaelstromWeave"), #combined - 1, "D: weave appends after nova, MW above core")
    assert_eq(find_lane(combined, "Forever_StormstrikeCore"), #combined, "D: core appends last")
end

-- G. Mirror selection: the MW weave gates on the buff-mirror sentinel and
-- the Fire Nova lane casts the maxrank sentinel -- never the rank-1 baseline
-- (distinct sentinels per mirror prove which table each lane read).
do
    local combined = load_delta({ ["Maelstrom Weapon"] = 19004, ["Fire Nova"] = 19005 },
        { ["Fire Nova"] = 19105 }, { ["Maelstrom Weapon"] = 19204 })
    local state = { mana_pct = 80 }
    local ctx = { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }

    local mw = combined[find_lane(combined, "Forever_MaelstromWeave")]
    NS.has_player_buff = function(id) return id == 19204 end
    assert_true(mw.matches(ctx, state), "G: MW matches on the buff-mirror sentinel")
    NS.has_player_buff = function(id) return id == 19004 end
    assert_true(not mw.matches(ctx, state), "G: MW ignores the rank-1 baseline sentinel")
    NS.has_player_buff = function() return false end

    local nova = combined[find_lane(combined, "Forever_FireNovaSpell")]
    cast_log = {}
    assert_true(nova.execute(ctx, state), "G: Fire Nova executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19105, "G: Fire Nova casts the maxrank sentinel (not the 19005 baseline)")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/shaman/enhancement_forever.lua", "r")
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

print(string.format("test_shaman_enhancement_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS shaman_enhancement_forever")
