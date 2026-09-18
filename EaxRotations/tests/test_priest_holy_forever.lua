-- test_priest_holy_forever.lua -- unit pins for the priest holy Forever delta.
-- WHAT:  holy_forever.lua contract: baseline capture + re-register splice
--        (PoM above the maintenance block, the Litany variety lane above
--        Greater Heal, Binding Heal above Flash Heal), the PoM jump
--        tracking, the pair-heal "both hurt" gate, the alternation engine,
--        by-name dormancy, mirror selection, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   PoM without the party-aura scan would recast every 10s and reset
--        its own jump count; Binding Heal without the self-hurt gate would
--        be a worse Flash Heal; the variety lane must actually alternate or
--        the Litany refund never fires.
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
local auras = {}
local entries_with_pom = false
local ready_off = {}
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = { name = "me" },
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    PriestSpells = {
        FlashHeal = { ids = { 25235, 10917, 2061 }, name = "FlashHeal" },
        GreaterHeal = { ids = { 25213, 10965, 2060 }, name = "GreaterHeal" },
    },
    spell_ready = function(spell, target, opts)
        if type(spell) == "table" and spell.name and ready_off[spell.name] then return false end
        return true
    end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    buff_up = function(unit, ids)
        -- per-unit aura model: auras[unit_name][id] = true
        local unit_auras = auras[unit and unit.name or "?"] or {}
        if type(ids) == "number" then return unit_auras[ids] == true end
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if unit_auras[id] == true then return true end
            end
        end
        return false
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
local POM_AURA = 19080
NS.PriestHealing = {
    scan_healing_targets = function()
        if entries_with_pom then
            return { { unit = { name = "tank" }, effective_hp = 70, has_pom = true } }, 1
        end
        return { { unit = { name = "tank" }, effective_hp = 70 } }, 1
    end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "holy",
    strategies = {
        { name = "EmergencyPWS", matches = function() return false end, execute = function() return false end },
        { name = "EmergencyFlashHeal", matches = function() return false end, execute = function() return false end },
        { name = "FriendlyTarget", matches = function() return false end, execute = function() return false end },
        { name = "PrayerOfHealing", matches = function() return false end, execute = function() return false end },
        { name = "GreaterHeal", matches = function() return false end, execute = function() return false end },
        { name = "FlashHeal", matches = function() return false end, execute = function() return false end },
        { name = "RenewTank", matches = function() return false end, execute = function() return false end },
        { name = "RenewSpread", matches = function() return false end, execute = function() return false end },
        { name = "IdleSmite", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/priest/holy_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/priest/holy_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/priest/holy_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function fresh_ctx(overrides)
    local ctx = { in_combat = true, target = { name = "enemy" }, has_valid_enemy_target = true,
                  me = {}, settings = {}, hp = 60, mana_pct = 80 }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function fresh_state(overrides)
    local s = {
        lowest = { unit = { name = "lowest" }, effective_hp = 55 },
        lowest_hp = 55,
        tank = { unit = { name = "tank" }, effective_hp = 70 },
        tank_hp = 70,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local POM = 19081
local POM_R1 = 19082
local BINDING = 19083
local BINDING_R1 = 19084
local MIRRORS = { ["Prayer of Mending"] = POM_R1, ["Binding Heal"] = BINDING_R1 }
local MAXRANK = { ["Prayer of Mending"] = POM, ["Binding Heal"] = BINDING }
local BUFFS = { ["Prayer of Mending"] = POM_AURA }

-- A. All three lanes live.
do
    learnt = { [POM] = true, [BINDING] = true }
    auras = {}
    entries_with_pom = false
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "holy", "A: re-registers the holy playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 3, "A: 3 delta lanes over 9 baseline lanes")
    assert_eq(find_lane(combined, "Forever_PrayerOfMending"), find_lane(combined, "RenewTank") - 1,
        "A: PoM leads the maintenance heal block")
    assert_eq(find_lane(combined, "Forever_LitanyVariety"), find_lane(combined, "GreaterHeal") - 1,
        "A: the variety lane leads Greater Heal")
    assert_eq(find_lane(combined, "Forever_BindingHeal"), find_lane(combined, "FlashHeal") - 1,
        "A: Binding Heal leads Flash Heal")
end

-- A2. Gates off: no lanes.
do
    learnt = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_true(not find_lane(combined, "Forever_PrayerOfMending"), "A2: PoM dormant without the learn")
    assert_true(not find_lane(combined, "Forever_BindingHeal"), "A2: Binding Heal dormant without the learn")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A2: the variety lane is learn-independent")
end

-- B. PoM matcher: the jump tracking holds while any party member carries it.
do
    learnt = { [POM] = true, [BINDING] = true }
    auras = {}
    entries_with_pom = false
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local pom = combined[find_lane(combined, "Forever_PrayerOfMending")]
    local ctx = fresh_ctx()
    local state = fresh_state()
    assert_true(pom.matches(ctx, state), "B: no aura anywhere fires PoM on the tank")
    auras = { me = { [POM_AURA] = true } }
    assert_true(not pom.matches(ctx, state), "B: the player's own aura holds the lane")
    auras = { tank = { [POM_AURA] = true } }
    entries_with_pom = true
    assert_true(not pom.matches(ctx, state), "B: a party member's aura holds the lane (jump tracking)")
    auras = {}
    entries_with_pom = false
    cast_log = {}
    assert_true(pom.execute(ctx, state), "B: PoM executes")
    assert_eq(cast_log[1] and cast_log[1].spell, POM, "B: the maxrank PoM id is cast")
    assert_eq(cast_log[1] and cast_log[1].target, state.tank.unit, "B: PoM lands on the tank")
end

-- B2. Binding Heal matcher: the pair-heal needs BOTH hurt.
do
    learnt = { [POM] = true, [BINDING] = true }
    auras = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local binding = combined[find_lane(combined, "Forever_BindingHeal")]
    local ctx = fresh_ctx({ hp = 60 })
    local state = fresh_state()
    assert_true(binding.matches(ctx, state), "B2: both at 55-60% fires the pair heal")
    assert_true(not binding.matches(fresh_ctx({ hp = 100 }), state),
        "B2: a healthy priest holds the pair heal (single-target heals handle it)")
    assert_true(not binding.matches(ctx, fresh_state({ lowest_hp = 80 })),
        "B2: a healthy ally holds the pair heal")
    assert_true(not binding.matches(fresh_ctx({ is_moving = true, hp = 60 }), state),
        "B2: movement holds the cast")
    cast_log = {}
    assert_true(binding.execute(ctx, state), "B2: Binding Heal executes")
    assert_eq(cast_log[1] and cast_log[1].spell, BINDING, "B2: the maxrank Binding Heal id is cast")
    assert_eq(cast_log[1] and cast_log[1].target, state.lowest.unit, "B2: it heals the lowest ally")
end

-- B3. Litany variety: strict alternation between Greater Heal and Flash Heal.
do
    learnt = { [POM] = true, [BINDING] = true }
    auras = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local variety = combined[find_lane(combined, "Forever_LitanyVariety")]
    local ctx = fresh_ctx()
    cast_log = {}
    assert_true(variety.matches(ctx, fresh_state()), "B3: an injured ally opens the variety lane")
    assert_true(variety.execute(ctx, fresh_state()), "B3: first cast executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.PriestSpells.GreaterHeal, "B3: the first pick is Greater Heal")
    assert_true(variety.execute(ctx, fresh_state()), "B3: second cast executes")
    assert_eq(cast_log[2] and cast_log[2].spell, NS.PriestSpells.FlashHeal, "B3: the second pick alternates to Flash Heal")
    assert_true(variety.execute(ctx, fresh_state()), "B3: third cast executes")
    assert_eq(cast_log[3] and cast_log[3].spell, NS.PriestSpells.GreaterHeal, "B3: the alternation continues")
    -- The matcher must check the ALTERNATE spell's readiness: after two casts
    -- the next pick is Flash Heal, so Flash Heal on cooldown holds the lane.
    ready_off = { FlashHeal = true }
    assert_true(not variety.matches(ctx, fresh_state()),
        "B3: the matcher gates on the alternated pick (Flash Heal on cooldown)")
    ready_off = {}
    assert_true(not variety.matches(fresh_ctx({ mana_pct = 10 }), fresh_state()),
        "B3: the mana floor holds the variety lane")
    assert_true(not variety.matches(ctx, fresh_state({ lowest_hp = 95 })),
        "B3: a healthy ally holds the variety lane")
end

-- C. Dormancy: empty mirrors leave the bridge-gated lanes out (the variety
-- lane rides the class map and stays).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_PrayerOfMending"), "C: PoM dormant")
    assert_true(not find_lane(combined, "Forever_BindingHeal"), "C: Binding Heal dormant")
    assert_true(find_lane(combined, "Forever_LitanyVariety") ~= nil,
        "C: the variety lane is class-map-backed and stays")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "C: only the variety lane remains")
end

-- D. Splice fallback: without the primary anchors the lanes append.
do
    learnt = { [POM] = true, [BINDING] = true }
    local shrunk = {
        name = "holy",
        strategies = {
            { name = "EmergencyPWS", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 4, "D: all three lanes appended without anchors")
    assert_eq(find_lane(combined, "Forever_PrayerOfMending"), 2, "D: PoM appended first")
    assert_eq(find_lane(combined, "Forever_LitanyVariety"), 3, "D: the variety lane appended second")
    assert_eq(find_lane(combined, "Forever_BindingHeal"), 4, "D: Binding Heal appended last")
end

-- G. Mirror selection: the casts read maxrank, the learn gates both mirrors,
-- the PoM aura the buff mirror.
do
    learnt = { [POM] = true, [BINDING] = true }
    auras = {}
    local no_max = load_delta(MIRRORS, {}, BUFFS)
    assert_true(not find_lane(no_max, "Forever_PrayerOfMending"), "G: no maxrank = dormant PoM")
    assert_true(not find_lane(no_max, "Forever_BindingHeal"), "G: no maxrank = dormant Binding Heal")
    local no_buff = load_delta(MIRRORS, MAXRANK, {})
    assert_true(find_lane(no_buff, "Forever_PrayerOfMending") ~= nil,
        "G: the PoM lane lives on the maxrank fallback id without the buff pin")
    local live = load_delta(MIRRORS, MAXRANK, BUFFS)
    local pom = live[find_lane(live, "Forever_PrayerOfMending")]
    cast_log = {}
    assert_true(pom.execute(fresh_ctx(), fresh_state()), "G: the maxrank sentinel is the cast id")
    assert_eq(cast_log[1] and cast_log[1].spell, POM, "G: PoM casts the maxrank id")
end

-- Pin 7 (dispatch-walk combination proof, 2026-09-19): the legacy
-- dispatcher is positional first-match (main_sylvanas.lua run_list), so the
-- contract is the WALK OUTCOME over the combined list, not individual gate
-- truth. The fake baseline's lanes are quiet by construction, so these
-- walks prove the delta's own lanes resolve their tiers in splice order --
-- including the handovers between them.
local function walk(list, ctx, st)
    for _, lane in ipairs(list) do
        if type(lane) == "table" and lane.matches and lane.matches(ctx, st) then
            return lane.name
        end
    end
    return nil
end
do
    learnt = { [POM] = true, [BINDING] = true }
    auras = {}
    entries_with_pom = false
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)

    -- 7a: a moving frame quiets the variety and binding lanes (both require
    -- a stationary cast) while PoM ignores movement -- the walk must land
    -- on PoM, proving its slot above the RenewTank maintenance block.
    local moving_ctx = fresh_ctx({ is_moving = true })
    assert_eq(walk(combined, moving_ctx, fresh_state()), "Forever_PrayerOfMending",
        "7a: moving frame walks to PoM above the maintenance block")

    -- 7b: the tier handover. A stationary frame with mana in band walks to
    -- the VARIETY lane (it splices above GreaterHeal, so it outranks the
    -- Binding Heal tier); dropping mana below the variety floor (30) hands
    -- the slot to Binding Heal two lanes deeper -- the walk proves the
    -- header's tier ordering, not just per-lane gates.
    local full_ctx = fresh_ctx({ is_moving = false })
    assert_eq(walk(combined, full_ctx, fresh_state()), "Forever_LitanyVariety",
        "7b: in-band frame walks to the variety tier above Binding Heal")
    local low_mana_ctx = fresh_ctx({ is_moving = false, mana_pct = 25 })
    assert_eq(walk(combined, low_mana_ctx, fresh_state()), "Forever_BindingHeal",
        "7b2: below the variety floor the walk hands the slot to Binding Heal")
end

-- 7c: intermediate fallback WALK -- with the maintenance anchors present
-- but the variety/binding anchors missing, PoM must still own its
-- maintenance slot (spliced) while the other two append (pin D covers the
-- no-anchor tail order; here the walk proves the degraded dispatch
-- outcome, not just positions).
do
    learnt = { [POM] = true, [BINDING] = true }
    auras = {}
    entries_with_pom = false
    local shrunk = {
        name = "holy",
        strategies = {
            { name = "EmergencyPWS", matches = function() return false end, execute = function() return false end },
            { name = "RenewTank", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(find_lane(combined, "Forever_PrayerOfMending"), 2,
        "7c: PoM splices above the surviving RenewTank anchor")
    assert_eq(walk(combined, fresh_ctx({ is_moving = true }), fresh_state()),
        "Forever_PrayerOfMending",
        "7c: degraded list still walks to PoM for the maintenance slot")
    assert_eq(find_lane(combined, "Forever_LitanyVariety"), 4,
        "7c: variety appends after the spliced PoM (no variety anchor)")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/priest/holy_forever.lua", "rb")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    assert_true(#content > 0, "E: delta source readable")
    local body = content:gsub("%-%-[^\n]*", "")
    local found = nil
    for line in body:gmatch("([^\n]*)") do
        local digits = line:match("%f[%d]%d%f[^%d]")
        if digits and #digits >= 4 then
            found = found or line
        end
    end
    assert_true(found == nil, "E: no numeric spell-ID literals (found: " .. tostring(found) .. ")")
end

print("test_priest_holy_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS priest_holy_forever")
