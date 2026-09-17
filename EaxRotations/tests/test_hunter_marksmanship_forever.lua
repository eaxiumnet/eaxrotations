-- test_hunter_marksmanship_forever.lua -- unit pins for the hunter MM Forever delta.
-- WHAT:  marksmanship_forever.lua contract: baseline capture + re-register
--        splice (Sniper Shot + reordered Multi above the in-combat Aimed
--        lane; both Aimed lanes preserved), the Lone Wolf pet fork
--        (pet lanes dropped only when the talent is known), matcher gates,
--        by-name dormancy, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   the Sniper window is a deliberate exception to the filler rule, the
--        Multi reorder is the shared-cooldown decision, and the Lone Wolf
--        fork is the spec's defining branch — losing any of them silently
--        reverts the playstyle (filler Sniper casts, starved Multi, or a pet
--        that cancels the +21%).
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
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    HunterSpells = {},
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "marksmanship",
    strategies = {
        { name = "MendPet", matches = function() return false end, execute = function() return false end },
        { name = "CallPet", matches = function() return false end, execute = function() return false end },
        { name = "RevivePet", matches = function() return false end, execute = function() return false end },
        { name = "AspectOfTheHawk", matches = function() return false end, execute = function() return false end },
        { name = "RapidFire", matches = function() return false end, execute = function() return false end },
        { name = "InCombatAimedShot", matches = function() return false end, execute = function() return false end },
        { name = "AimedShotPrepull", matches = function() return false end, execute = function() return false end },
        { name = "LevelingArcaneShot", matches = function() return false end, execute = function() return false end },
        { name = "MultiShot", matches = function() return false end, execute = function() return false end },
        { name = "ArcaneShot", matches = function() return false end, execute = function() return false end },
        { name = "SerpentSting", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/hunter/marksmanship_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/hunter/marksmanship_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/hunter/marksmanship_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function count_lane(list, name)
    local n = 0
    for _, st in ipairs(list) do
        if type(st) == "table" and st.name == name then n = n + 1 end
    end
    return n
end

local function fresh_ctx()
    return { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {},
             is_moving = false, is_pvp = false }
end

-- A. Full kit (Lone Wolf NOT known): pet lanes stay, Sniper + Multi land
-- above the in-combat Aimed lane, both Aimed lanes preserved.
do
    local combined = load_delta({}, { ["Sniper Shot"] = 19118, ["Lone Wolf"] = 19119 }, {})
    assert_eq(registered and registered.name, "marksmanship", "A: re-registers the marksmanship playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane, reorder is count-neutral")
    assert_eq(count_lane(combined, "MultiShot"), 1, "A: exactly one MultiShot lane remains")
    assert_eq(count_lane(combined, "InCombatAimedShot"), 1, "A: the in-combat Aimed lane is preserved")
    assert_eq(count_lane(combined, "AimedShotPrepull"), 1, "A: the prepull Aimed lane is preserved")
    assert_eq(find_lane(combined, "Forever_SniperShot"), find_lane(combined, "MultiShot") - 1,
        "A: Sniper leads the reordered shot pair")
    assert_eq(find_lane(combined, "MultiShot"), find_lane(combined, "InCombatAimedShot") - 1,
        "A: Multi now sits just above the in-combat Aimed lane (shared CD picks the shot)")
    assert_eq(find_lane(combined, "AimedShotPrepull"), find_lane(combined, "InCombatAimedShot") + 1,
        "A: the deferred Aimed lanes follow Multi in their baseline order")
    assert_true(find_lane(combined, "MendPet"), "A: pet lanes stay when Lone Wolf is not known")
    assert_eq(find_lane(combined, "AspectOfTheHawk"), 4, "A: buff/utility head lanes untouched")
end

-- B. Lone Wolf known: the pet recall/maintenance lanes are dropped.
do
    learnt = {}
    learnt[19119] = true
    local combined = load_delta({}, { ["Sniper Shot"] = 19118, ["Lone Wolf"] = 19119 }, {})
    assert_true(not find_lane(combined, "CallPet"), "B: CallPet dropped under Lone Wolf")
    assert_true(not find_lane(combined, "RevivePet"), "B: RevivePet dropped under Lone Wolf")
    assert_true(not find_lane(combined, "MendPet"), "B: MendPet dropped under Lone Wolf")
    assert_true(find_lane(combined, "AspectOfTheHawk"), "B: the buff lane survives the fork")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1 - 3, "B: three pet lanes dropped, one added")
    learnt = {}
end

-- B2. Sniper matcher: the execute/PvP window, cast-safety, readiness.
do
    local combined = load_delta({}, { ["Sniper Shot"] = 19118 }, {})
    local sniper = combined[find_lane(combined, "Forever_SniperShot")]
    local state = { in_combat = true, target_hp = 50 }
    local ctx = fresh_ctx()

    assert_true(not sniper.matches(ctx, state), "B2: Sniper holds on a healthy non-PvP target")
    state.target_hp = 15
    assert_true(sniper.matches(ctx, state), "B2: Sniper fires in the execute window")
    state.target_hp = 50
    ctx.is_pvp = true
    assert_true(sniper.matches(ctx, state), "B2: Sniper fires in PvP")
    ctx.is_pvp = false
    ctx.is_moving = true
    state.target_hp = 15
    assert_true(not sniper.matches(ctx, state), "B2: Sniper holds while moving (4s cast)")
    ctx.is_moving = false
    local ooc = { in_combat = false, target_hp = 15 }
    assert_true(not sniper.matches(ctx, ooc), "B2: Sniper needs combat")
    local no_target = fresh_ctx()
    no_target.has_valid_enemy_target = false
    assert_true(not sniper.matches(no_target, state), "B2: Sniper needs a valid enemy")
    local seen_opts = nil
    local orig_ready = NS.spell_ready
    NS.spell_ready = function(spell, target, opts) seen_opts = opts; return true end
    assert_true(sniper.matches(ctx, state), "B2: Sniper passes readiness")
    assert_eq(seen_opts and seen_opts.expected_cooldown, 15, "B2: Sniper declares the 15s cooldown")
    NS.spell_ready = orig_ready
    cast_log = {}
    assert_true(sniper.execute(ctx, state), "B2: Sniper executes")
end

-- C. Dormancy: no Sniper lane on empty mirrors; no Lone Wolf fork either;
-- the shot reorder is bridge-independent and still applies.
do
    learnt = {}
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: zero delta lanes on empty mirrors")
    assert_true(not find_lane(combined, "Forever_SniperShot"), "C: Sniper dormant")
    assert_true(find_lane(combined, "CallPet"), "C: pet lanes kept without a Lone Wolf lookup")
    assert_eq(count_lane(combined, "MultiShot"), 1, "C: the Multi lane survives the reorder")
    assert_true(find_lane(combined, "MultiShot") < find_lane(combined, "InCombatAimedShot"),
        "C: the shared-CD reorder applies without the bridge (no ids needed)")
end

-- D. Splice fallback: no Aimed anchor appends Sniper then Multi.
do
    FAKE_BASELINE.strategies = {
        { name = "AspectOfTheHawk", matches = function() return false end, execute = function() return false end },
        { name = "ArcaneShot", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({}, { ["Sniper Shot"] = 19118 }, {})
    assert_eq(find_lane(combined, "Forever_SniperShot"), #combined, "D: Sniper appends with no anchor")
end

-- G. Mirror selection: Sniper casts the maxrank sentinel.
do
    local combined = load_delta({}, { ["Sniper Shot"] = 19118 }, {})
    local sniper = combined[find_lane(combined, "Forever_SniperShot")]
    local state = { in_combat = true, target_hp = 15 }
    local ctx = fresh_ctx()
    cast_log = {}
    assert_true(sniper.execute(ctx, state), "G: Sniper executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19118, "G: Sniper casts the maxrank sentinel")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/hunter/marksmanship_forever.lua", "r")
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

print(string.format("test_hunter_marksmanship_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS hunter_marksmanship_forever")
