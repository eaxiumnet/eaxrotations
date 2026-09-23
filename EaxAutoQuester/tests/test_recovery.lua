-- What: shared/recovery.lua — the eat/drink pause the pull gate's hold allows.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: The pull gate refuses a pull, walks the retreat, parks — then waits for natural regen.
--      This suite pins the recovery half of that feature AND the constraints that keep it the
--      lesson learned rather than the disabled regen wait's return:
--        * it fires only below the PULL GATE's own refusal floor (asked from the gate, never
--          restated here), only while the gate holds, never in combat, and ends on schedule
--          (R1–R7, R13);
--        * a probe that cannot answer fails closed, the combat probe included (R14);
--        * quest items are never lunch (R8);
--        * the pause owns no navigation state and drives no movement (R9).
-- Safety: pure module + unit stubs; no client, no network, no writes.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local _time = 1000
local _logs = {}
local _used = {}             -- every use_item call, in order
local _bags = {}             -- bag fixtures, per scenario: _bags[bag] = { { object = ... } }
                              -- (declared before `core`: the closure below must capture this
                              --  upvalue, not a global of the same name)

-- Recovery is called from idle_state with the plugin's own core; the suite provides the
-- minimal surface the module reads (time, inventory, input).
core = {
    time = function() return _time end,
    inventory = {
        get_items_in_bag = function(bag)
            return _bags and _bags[bag] or {}
        end,
    },
    input = {
        use_item = function(item_id)
            _used[#_used + 1] = item_id
        end,
    },
    log = function(msg) _logs[#_logs + 1] = tostring(msg) end,
    log_warning = function(msg) _logs[#_logs + 1] = tostring(msg) end,
}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.set_warning = function() end

local recovery = require("shared/recovery")
local pull_safety = require("shared/pull_safety")

-- No helper in this environment: the module takes its raw-bag-walk backstop, which is the
-- path whose classification the generated table owns. (The helper-backed path is exercised by
-- R10 with an explicitly installed stand-in.)
package.loaded["common/utility/inventory_helper"] = nil

-- No waypoint fixer needed here: the gate computes a retreat point, and the stub keeps the
-- suite from loading the real module.
package.loaded["waypoint_fixer_sylvanas"] = {
    fix_z = function(pos) return pos end,
}

-- =============================================================================
-- Stubs
-- =============================================================================

--- A player: hp/max_hp as raw values (1000/1000 = 100%), mana nil means "no mana bar".
local function player(o)
    o = o or {}
    return {
        get_position = function() return o.pos or { x = 0, y = 0, z = 0 } end,
        get_health = function() return o.hp or 1000 end,
        get_max_health = function() return o.max_hp or 1000 end,
        get_power = function(_, t) return o.mana or 0 end,
        get_max_power = function(_, t) return o.max_mana or 0 end,
        is_in_combat = function() return o.combat == true end,
        get_level = function() return o.level or 60 end,
        is_unit = function() return true end,
        is_dead = function() return false end,
        can_attack = function() return false end,
        get_movement_speed = function() return 0 end,
    }
end

--- A hostile unit, for gate scenarios.
local function mob(o)
    o = o or {}
    return {
        is_unit = function() return true end,
        is_dead = function() return o.dead == true end,
        can_attack = function() return true end,
        get_position = function() return o.pos or { x = 0, y = 0, z = 0 } end,
        get_movement_speed = function() return o.speed or 0 end,
        is_in_combat = function() return o.combat == true end,
        get_health = function() return 100 end,
        get_max_health = function() return 100 end,
        get_power = function() return 0 end,
        get_max_power = function() return 0 end,
    }
end

local function ctx_for(o)
    o = o or {}
    return {
        me = o.me,
        now = o.now or _time,
        menu = o.menu,
        debug_log = function(msg) _logs[#_logs + 1] = tostring(msg) end,
    }
end

local function fresh_shared()
    return { _recov_since = 0, _recov_used_at = 0 }
end

local function item(id)
    return { object = { get_item_id = function() return id end } }
end

local function reset_used()
    _used = {}                  -- per-scenario counting (the closure re-reads this upvalue)
end

--- Menu stub: answers the gate's own rows, and answers the legacy eaxaq_min_hp / _min_mana pair
--- with something deliberately loud (90) whenever a scenario does not override it — a recovery
--- that still read those rows would eat for no reason.
local function menu_with(o)
    o = o or {}
    return { get = function(key, fallback)
        if key == "pull_gate_min_hp" then
            if o.min_hp ~= nil then return o.min_hp end
        elseif key == "pull_gate_min_mana" then
            if o.min_mana ~= nil then return o.min_mana end
        elseif key == "min_hp" or key == "min_mana" then
            return 90
        end
        return fallback
    end }
end

--- Arm the gate's hold the way production does: a refused pull on a low bar.
--- @param opts table|nil { menu = <stub> } — the gate's own rows, when a scenario owns them
local function arm_gate(me, opts)
    pull_safety.reset()
    reset_used()
    _time = 1000
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local shared = fresh_shared()
    local ctx = ctx_for({ me = me, menu = opts and opts.menu })
    pull_safety.gate(ctx, shared, enemy)
    return shared, ctx
end

local function used_count()
    return #_used
end

-- =============================================================================
-- R1 — below the mana floor, parked, holding: the item is used
-- =============================================================================

do
    local me = player({ mana = 100, max_mana = 1000 })            -- 10% mana
    _bags = { [0] = { item(2136) } }                              -- Conjured Fresh Water
    local shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == true, "R1 FAIL: a parked low-mana bot must recover")
    assert(used_count() == 1 and _used[1] == 2136,
        "R1 FAIL: the drink in the bags must be used (got " .. tostring(_used[1]) .. ")")
    print("  R1 PASS: below the mana floor, parked and holding, the drink is used")
end

-- =============================================================================
-- R2 — the gate's own floor is the boundary: only the bar below it is refilled
-- =============================================================================
-- The gate parks on ONE bar, so each half of the band is pinned with the pause genuinely live:
-- the low bar's item is used, and a bar sitting exactly on its floor is left alone. (That an
-- ordinary post-fight bar is never parked in the first place is the gate's own contract — see
-- test_pull_safety's N1/P6 — and is deliberately not restated here.)

do
    -- R2a — health below the gate's floor (40 < 50), mana exactly on it (30 is not 30 < 30).
    local me = player({ hp = 400, max_hp = 1000, mana = 300, max_mana = 1000 })
    _bags = { [0] = { item(2136), item(8950) } }                  -- drink + food
    local shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == true, "R2a FAIL: health under the floor must pause")
    assert(used_count() == 1 and _used[1] == 8950,
        "R2a FAIL: the food must be used and the drink left alone for mana on its floor (got "
        .. tostring(_used[1]) .. ")")
    print("  R2a PASS: below the health floor the food is used; mana on its floor is not drunk for")

    -- R2b — mana below the gate's floor (29 < 30), health comfortably above it (60).
    me = player({ hp = 600, max_hp = 1000, mana = 290, max_mana = 1000 })
    shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == true, "R2b FAIL: mana under the floor must pause")
    assert(used_count() == 1 and _used[1] == 2136,
        "R2b FAIL: the drink must be used and the food left alone (got " .. tostring(_used[1]) .. ")")
    print("  R2b PASS: below the mana floor the drink is used; a healthy bar is not eaten for")
end

-- =============================================================================
-- R3 — in combat: never, not even while the gate technically holds
-- =============================================================================

do
    local me = player({ mana = 50, max_mana = 1000, combat = true })
    _bags = { [0] = { item(2136) } }
    local shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == false, "R3 FAIL: combat recovery is the rotation's business")
    assert(used_count() == 0, "R3 FAIL: no item may be used in combat")
    print("  R3 PASS: in combat, never")
end

-- =============================================================================
-- R4 — the gate's hold is the only licence: no hold, no pause
-- =============================================================================

do
    pull_safety.reset()
    reset_used()
    local me = player({ mana = 50, max_mana = 1000 })             -- 5% mana
    _bags = { [0] = { item(2136) } }
    local shared = fresh_shared()
    local ctx = ctx_for({ me = me })

    assert(recovery.tick(ctx, shared) == false,
        "R4 FAIL: recovery must not fire without the pull gate's hold")
    assert(used_count() == 0, "R4 FAIL: no item may be used outside the hold")
    print("  R4 PASS: without the gate's hold, no pause")
end

-- =============================================================================
-- R5 — the pause is one pause: it ends above the floor and does not re-arm on its own
-- =============================================================================

do
    local me = player({ mana = 100, max_mana = 1000 })            -- 10%
    _bags = { [0] = { item(2136) } }
    local shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == true, "R5 FAIL: pause must start below the floor")
    assert(shared._recov_since == 1000, "R5 FAIL: the pause clock must start once")

    -- The client's regen: 40s later the bot is above the floor again.
    _time = 1040
    me = player({ mana = 700, max_mana = 1000 })
    assert(recovery.tick(ctx_for({ me = me }), shared) == false,
        "R5 FAIL: the pause must end once the bar is above the floor")
    assert(shared._recov_since == 0, "R5 FAIL: an ended pause must be forgotten")

    -- ... and does not re-arm on its own: the NEXT low bar must start a fresh clock.
    _time = 1100
    me = player({ mana = 50, max_mana = 1000 })
    assert(recovery.tick(ctx_for({ me = me }), shared) == false,
        "R5 FAIL: no hold, no pause — even below the floor again")
    assert(shared._recov_since == 0, "R5 FAIL: no pause may be armed outside a hold")
    print("  R5 PASS: pause ends above the floor and never re-arms outside a hold")
end

-- =============================================================================
-- R6 — the pause is bounded: past the cap it resumes whatever the bars say
-- =============================================================================

do
    local me = player({ mana = 50, max_mana = 1000 })
    _bags = { [0] = { item(2136), item(4536), item(8950) } }
    local shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == true, "R6 FAIL: pause must start")
    local started = shared._recov_since

    -- Production re-arms the hold every refusal while parked (the state machine keeps
    -- retrying, the gate keeps refusing, HOLD_SECONDS is short); mirror that re-arm so the
    -- pause actually reaches its own cap instead of dying with the first hold.
    _time = started + recovery.MAX_PAUSE_SECONDS + 1
    pull_safety.gate(ctx_for({ me = me }), shared, mob({ pos = { x = 10, y = 0, z = 0 } }))
    assert(recovery.tick(ctx_for({ me = me }), shared) == false,
        "R6 FAIL: past the cap the pause must end, even below the floor")
    assert(shared._recov_since == 0, "R6 FAIL: the cap must clear the pause clock")
    print("  R6 PASS: past MAX_PAUSE_SECONDS the pause resumes whatever the bars say")
end

-- =============================================================================
-- R7 — the channel guard: no second use sooner than CHANNEL_SECONDS
-- =============================================================================

do
    local me = player({ mana = 50, max_mana = 1000 })
    _bags = { [0] = { item(2136) } }
    local shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == true and used_count() == 1, "R7 FAIL: first use")
    _time = 1000 + 1
    assert(recovery.tick(ctx, shared) == true, "R7 FAIL: the pause must hold under the floor")
    assert(used_count() == 1, "R7 FAIL: re-using mid-channel cancels it — must not happen")
    print("  R7 PASS: one use per channel window")
end

-- =============================================================================
-- R8 — quest items are never lunch, even when they classify as food
-- =============================================================================

do
    -- A consumable the quest manager holds for a step (stubbed here): whatever its tooltip
    -- says, the id is quest_item_manager's and recovery must never use it. 1205 classifies
    -- as a drink in the generated table AND out-tiers the other drink in the bags, so a
    -- broken exclusion would pick it and this scenario fails loudly if that ever happens.
    package.loaded["quest_item_manager_sylvanas"] = {
        get_all_inventory_items = function()
            return { { item_id = 1205, name = "Melon Juice" } }
        end,
    }
    recovery.reset()                                              -- the scan is a snapshot

    local me = player({ mana = 50, max_mana = 1000 })
    _bags = { [0] = { item(2136), item(4536), item(1205) } }
    local shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == true, "R8 FAIL: the pause may still start (food present)")
    assert(used_count() == 1 and _used[1] == 2136,
        "R8 FAIL: the quest item must never be used (got " .. tostring(_used[1]) .. ")")
    print("  R8 PASS: quest items are never used, whatever their tooltip says")

    package.loaded["quest_item_manager_sylvanas"] = nil
    recovery.reset()
end

-- =============================================================================
-- R9 — the pause drives nothing: no nav field is written, no walk is issued
-- =============================================================================

do
    local me = player({ mana = 50, max_mana = 1000 })
    _bags = { [0] = { item(2136) } }
    local shared, ctx = arm_gate(me)
    shared._nav_destination = { x = 1, y = 2, z = 3 }             -- a walk already armed

    recovery.tick(ctx, shared)
    assert(shared._nav_destination ~= nil, "R9 FAIL: recovery must not clear others' state")
    assert(shared._nav_unit_dest == nil, "R9 FAIL: recovery must not write nav fields")
    assert(shared._nav_engage_sq == nil, "R9 FAIL: recovery must not write nav fields")
    print("  R9 PASS: the pause drives no navigation and writes no nav field")
end

-- =============================================================================
-- R10 — the helper-backed path: the client's own list is used when the build provides it
-- =============================================================================

do
    package.loaded["common/utility/inventory_helper"] = {
        get_current_consumables_list = function()
            return {
                { is_food_or_drink = true, item = { get_item_id = function() return 8950 end } },
                { is_food_or_drink = false, item = { get_item_id = function() return 2136 end } },
            }
        end,
    }
    recovery.reset()

    local me = player({ hp = 200, max_hp = 1000 })                -- 20% hp, no mana bar
    _bags = { [0] = { item(2136), item(8950) } }
    local shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == true, "R10 FAIL: low hp must pause")
    assert(used_count() == 1 and _used[1] == 8950,
        "R10 FAIL: the helper's food must be used (got " .. tostring(_used[1]) .. ")")
    print("  R10 PASS: the helper's verdict is preferred when the build provides it")

    package.loaded["common/utility/inventory_helper"] = nil
    recovery.reset()
end

-- =============================================================================
-- R11 — the level guard: an item above the player's level is never picked
-- =============================================================================

do
    local me = player({ mana = 50, max_mana = 1000, level = 1 })
    _bags = { [0] = { item(2136) } }                              -- min_level 5
    local shared, ctx = arm_gate(me)

    assert(not recovery.tick(ctx, shared),
        "R11 FAIL: nothing usable must not wedge the caller (stand, don't wedge)")
    assert(used_count() == 0,
        "R11 FAIL: an item above the player's level must not be used")
    print("  R11 PASS: an unusable-tier item is never picked and nothing wedges")
end

-- =============================================================================
-- R12 — the generated table: the ids this suite used, and its shape
-- =============================================================================

do
    local table_ = require("shared/recovery_items_sylvanas")
    assert(type(table_) == "table" and table_[2136] and table_[8950],
        "R12 FAIL: the corpus table must carry the suite's fixtures")
    assert(table_[2136].kind == "drink" and table_[8950].kind == "food",
        "R12 FAIL: kinds must be food/drink")
    assert(type(table_[2136].min_level) == "number", "R12 FAIL: min_level must be numeric")
    -- The false-positive classes the generator excludes, and the included conjured line:
    assert(not table_[728] and not table_[3097], "R12 FAIL: recipes and conjure tomes must stay out")
    assert(table_[5349], "R12 FAIL: conjured food stays in")
    print("  R12 PASS: table shape and the generator's exclusions")
end

-- =============================================================================
-- R13 — the floor is the gate's own number, not one restated here
-- =============================================================================
-- The gate's rows are the user's: raise them and recovery follows; lower them and recovery
-- stops refilling at levels the gate now calls healthy. A floor kept privately (the 35/20 this
-- module shipped with) fails R13a, and a restated 50 fails R13b.

do
    -- R13a — the gate's floor at 70: a bot at 60% health is parked by that row and must eat.
    local me = player({ hp = 600, max_hp = 1000, mana = 1000, max_mana = 1000 })
    _bags = { [0] = { item(8950) } }
    local shared, ctx = arm_gate(me, { menu = menu_with({ min_hp = 70, min_mana = 70 }) })

    assert(pull_safety.holding(ctx) == true, "R13a FAIL: the gate's 70 floor must park a 60% bot")
    assert(recovery.tick(ctx, shared) == true,
        "R13a FAIL: with the gate's floor at 70, 60% health is below it and must eat")
    assert(used_count() == 1 and _used[1] == 8950, "R13a FAIL: the food must be used")
    print("  R13a PASS: the floor the gate refuses at is the floor recovery refills at")

    -- R13b — the gate's health row at 20: 40% health is above it, so health must not be eaten
    -- for even while a 5%-mana park is live and food is the ONLY thing in the bags. The legacy
    -- rows say 90 (see the stub): a floor read from them would eat here.
    me = player({ hp = 400, max_hp = 1000, mana = 50, max_mana = 1000 })
    _bags = { [0] = { item(8950) } }                              -- food only, no drink
    shared, ctx = arm_gate(me, { menu = menu_with({ min_hp = 20 }) })

    assert(recovery.tick(ctx, shared) == false,
        "R13b FAIL: the low bar has nothing usable — stand, don't wedge")
    assert(used_count() == 0,
        "R13b FAIL: health above the gate's 20 floor must not be eaten for, even as the only "
        .. "item in the bags (got " .. tostring(_used[1]) .. ")")
    print("  R13b PASS: a lowered health floor is followed, and the legacy rows drive nothing")
end

-- =============================================================================
-- R14 — an unreadable combat probe fails closed: no answer, no lunch
-- =============================================================================
-- The module's doctrine is that a bot which cannot answer must fight, not stand. Both shapes of
-- "no answer" are pinned: the probe that raises, and the probe that returns nothing.

do
    local me = player({ mana = 50, max_mana = 1000 })
    me.is_in_combat = function() error("client cannot say") end
    _bags = { [0] = { item(2136) } }
    local shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == false,
        "R14a FAIL: a combat probe that raises must fail closed")
    assert(used_count() == 0, "R14a FAIL: no item may be used on an unreadable probe")
    assert(shared._recov_since == 0, "R14a FAIL: a failed probe must leave no pause clock")

    me = player({ mana = 50, max_mana = 1000 })
    me.is_in_combat = function() return nil end
    shared, ctx = arm_gate(me)

    assert(recovery.tick(ctx, shared) == false,
        "R14b FAIL: a combat probe that says nothing must fail closed")
    assert(used_count() == 0, "R14b FAIL: no item may be used when the probe says nothing")
    print("  R14 PASS: an unreadable combat probe is never read as \"not in combat\"")
end

print("PASS test_recovery")
os.exit(0)
