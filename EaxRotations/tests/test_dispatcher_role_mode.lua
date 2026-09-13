-- test_dispatcher_role_mode.lua — Validate dispatcher role selection and mode gating.
-- WHAT:  mocks player class/role and verifies the dispatcher routes to the correct rotation module.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   dispatcher bugs affect every spec; role mis-routing is a total rotation failure.
-- SAFETY: fully mocked; exercises dispatch table lookups only.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local casts = 0
local strategies_fired = {}
local enemy_hp = 80   -- target hp the mock enemy reports (sweep passes drive it)

local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
    get_class = function() return 5 end,
    get_target = function()
        return {
            is_alive = function() return true end,
            is_valid = function() return true end,
            is_enemy_with = function() return true end,
            get_health_percentage = function() return enemy_hp end,
            get_distance = function() return 15 end,
        }
    end,
    is_in_combat = function() return true end,
    gcd_remains = function() return 0 end,
    is_moving = function() return false end,
    is_casting = function() return false end,
    is_channeling = function() return false end,
}

_G.core = {
    time = function() return 100 end,
    game_time = function() return 100000 end,
    log = function(...) end,
    log_warning = function(...) end,
    log_error = function(...) end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return {} end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 0, 0 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
    },
    input = {},
}

package.loaded.core_sylvanas = nil
package.loaded.main_sylvanas = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")

-- Capture the REAL core registry's register method before the test's mock
-- registries replace NS.rotation_registry; section (e) proves the real merge.
local real_register = NS.rotation_registry.register

NS.izi = {
    spell = function(spell_id)
        return {
            is_castable_to_unit = function(_, unit, opts)
                return true, nil
            end,
            cast_safe = function(_, unit, reason)
                casts = casts + 1
                return true
            end,
        }
    end,
}

local dispatcher = require("main_sylvanas")

local function reset()
    casts = 0
    strategies_fired = {}
end

local function track(name, category)
    return {
        name = name,
        category = category,
        matches = function() return true end,
        execute = function()
            strategies_fired[#strategies_fired + 1] = { name = name, category = category }
            return true
        end,
    }
end

NS.class_middleware = {
    priest = {
        track("DPS_Buff_Middleware", "damage"),
    },
}

NS.rotation_registry = {
    class_config = { class_key = "priest", default_playstyle = "discipline" },
    playstyles = {
        discipline = {
            track("Heal_Greater", "healing"),
        },
    },
    options = {
        discipline = { get_state = function(ctx) return ctx end },
    },
}

NS.set_setting("playstyle", "discipline")

reset()
dispatcher.on_rotation_update()

assert_true(#strategies_fired == 1, "Dispatcher: exactly ONE strategy should fire per tick (current=" .. tostring(#strategies_fired) .. ")")
assert_true(strategies_fired[1].name == "Heal_Greater", "Dispatcher: role mode must be selected FIRST; healer mode should run only healer strategies (fired=" .. tostring(strategies_fired[1].name) .. ")")
assert_true(casts <= 1, "Dispatcher: at most ONE cast should be emitted per tick (casts=" .. tostring(casts) .. ")")

NS.class_middleware = { rogue = {} }
NS.rotation_registry = {
    class_config = {
        class_key = "rogue",
        default_playstyle = "combat",
        playstyles = { { name = "sod_rogue_combat", display_name = "DPS" } },
    },
    playstyles = {
        sod_rogue_combat = { track("SoD_Combat", "sod") },
    },
    options = { sod_rogue_combat = {} },
}
NS.set_setting("playstyle", nil)
NS.set_setting("active_playstyle", nil)
NS.refresh_settings_cache()
reset()
dispatcher.on_rotation_update()
assert_true(#strategies_fired == 1 and strategies_fired[1].name == "SoD_Combat",
    "Dispatcher: invalid legacy default must fall back to the first SoD playstyle")


-- ============================================================================
-- Test 3: CastTrace — the in-game "why" trace records fired rules through the
-- REAL dispatcher (run_list) when Diagnostics -> Trace Casts is on, and records
-- nothing when it is off. Exercises a DSL-compiled strategy end to end: real
-- compile, real dispatch, live state rendered into the entry.
-- ============================================================================
local dsl_ok3, dsl3 = pcall(require, "shared/strategy_dsl_sylvanas")
assert_true(dsl_ok3 and type(dsl3.compile_strategy) == "function", "strategy_dsl available for CastTrace dispatcher test")

local arcane_strat = dsl3.compile_strategy({
    name = "ArcaneBlast",
    conditions = {
        { type = "state", field = "in_combat", op = "truthy" },
        { type = "state", field = "arcane_blast_stacks", op = ">=", value = 2 },
        { type = "state", field = "mana_pct", op = ">=", value = 40 },
    },
    action = { type = "cast", spell = 30451, target = "target" },
})

NS.try_cast = function(spell, target, label, opts)
    casts = casts + 1
    return true
end
NS.rotation_registry = {
    class_config = { class_key = "mage", default_playstyle = "arcane" },
    playstyles = { arcane = { arcane_strat } },
    options = {
        arcane = {
            get_state = function()
                return { in_combat = true, arcane_blast_stacks = 3, mana_pct = 62 }
            end,
        },
    },
}
NS.class_middleware = { mage = {} }
NS.set_setting("playstyle", "arcane")
NS.set_setting("active_playstyle", nil)
NS.refresh_settings_cache()

assert_true(NS.CastTrace ~= nil, "CastTrace module loaded with the dispatcher")

-- Trace OFF: repeated real ticks record nothing.
NS._TRACE_CASTS = nil
NS.CastTrace.clear()
reset()
for _ = 1, 3 do dispatcher.on_rotation_update() end
assert_true(NS.CastTrace.count() == 0, "dispatcher records nothing with trace off (count=" .. tostring(NS.CastTrace.count()) .. ")")

-- Trace ON: the fired rule + live state land in the ring through run_list.
NS._TRACE_CASTS = true
NS.CastTrace.clear()
reset()
local fired_arcane = dispatcher.on_rotation_update()
assert_true(fired_arcane, "arcane tick fired a cast")
assert_true(NS.CastTrace.count() >= 1, "dispatcher recorded at least one entry with trace on (count=" .. tostring(NS.CastTrace.count()) .. ")")
local tlines3 = NS.CastTrace.lines(5)
local found_trace = false
for i = 1, #tlines3 do
    local l = tlines3[i]
    if l:find("ArcaneBlast", 1, true) and l:find("arcane_blast_stacks=3", 1, true) and l:find("mana_pct=62", 1, true) then
        found_trace = true
    end
end
assert_true(found_trace, "recorded entry names the rule and its live state through the real dispatcher")
NS._TRACE_CASTS = nil

-- ============================================================================
-- Test 4: the Diagnostics UI surface end to end. Both menu hosts (imperative
-- main.lua and declarative_menu_sylvanas) drive ONE shared gate — the
-- "eax_debug_trace_casts" checkbox (retained setting key), which main.lua
-- syncs to NS._TRACE_CASTS via read_debug_flag each tick. Declarative mode
-- writes the setting into NS.settings; the imperative widget is read live.
-- This pins the whole loop a player drives: toggle on -> combat ticks record
-- -> the "Last Casts" readout renders rule + DSL-watch state -> Print writes
-- one-line entries to the log -> Clear empties -> toggle off records nothing.
-- ============================================================================

-- (a) The imperative checkbox state read (main.lua read_debug_flag semantics
--     for _declarative_menu_active == false) must drive recording.
local chk_widget = { _state = false, get_state = function(self) return self._state end }
local function read_checkbox_flag(widget)
    if not widget then return false end
    local ok, val = pcall(function() return widget:get_state() end)
    return ok and val == true
end
local function drive_imperative_toggle(on)
    chk_widget._state = on
    NS._TRACE_CASTS = read_checkbox_flag(chk_widget)
end

-- (b) Declarative-mode read (main.lua read_debug_flag for
--     _declarative_menu_active == true): NS.settings carries the retained
--     page's setting value.
local function drive_declarative_toggle(on)
    NS.settings.eax_debug_trace_casts = on and true or nil
    NS._TRACE_CASTS = (NS.settings.eax_debug_trace_casts) == true
end

-- Toggle ON through the imperative checkbox path -> real dispatch records.
drive_imperative_toggle(true)
NS.CastTrace.clear()
reset()
dispatcher.on_rotation_update()
assert_true(NS.CastTrace.count() >= 1, "imperative Trace Casts checkbox on -> dispatcher records (count=" .. tostring(NS.CastTrace.count()) .. ")")
local ui_lines = NS.CastTrace.lines(4)
assert_true(#ui_lines >= 1 and ui_lines[1]:find("ArcaneBlast", 1, true)
    and ui_lines[1]:find("arcane_blast_stacks=3", 1, true),
    "Last Casts readout renders rule + DSL-watch state (line=" .. tostring(ui_lines[1] or "?"))

-- Print Last Casts -> writes one-line explanations through the addon log.
local logged = {}
local orig_log = NS.log
NS.log = function(msg) logged[#logged + 1] = tostring(msg) end
NS.CastTrace.print_recent(8)
NS.log = orig_log
assert_true(#logged >= 1 and logged[1]:find("[CastTrace]", 1, true),
    "Print Last Casts writes one-line entries to the log (got " .. tostring(#logged) .. " lines)")

-- Clear Trace -> the readout falls back to its empty-state line.
drive_imperative_toggle(true)
NS.CastTrace.clear()
assert_true(NS.CastTrace.count() == 0 and #NS.CastTrace.lines(4) == 0,
    "Clear Trace empties the ring (readout shows the empty-state line)")

-- Declarative host drives the SAME shared gate via NS.settings: toggle ON via
-- the retained setting key records through the real dispatcher.
drive_declarative_toggle(true)
NS.CastTrace.clear()
reset()
dispatcher.on_rotation_update()
assert_true(NS.CastTrace.count() >= 1, "declarative Trace Casts setting on -> dispatcher records (count=" .. tostring(NS.CastTrace.count()) .. ")")

-- Toggle OFF (both hosts -> NS._TRACE_CASTS false): ticks record nothing.
drive_imperative_toggle(false)
drive_declarative_toggle(false)
NS.CastTrace.clear()
reset()
for _ = 1, 3 do dispatcher.on_rotation_update() end
assert_true(NS.CastTrace.count() == 0, "toggle off -> repeated real ticks record nothing (count=" .. tostring(NS.CastTrace.count()) .. ")")
NS.settings.eax_debug_trace_casts = nil
NS._TRACE_CASTS = nil

-- ============================================================================
-- Channel-clip opt-in (2026-09-12): the dispatcher's "casting or channeling ->
-- stop" early exit yields ONLY for a channel the active registry declared
-- clip-managed (registry.channel_clip_ids) — which is what makes the shadow
-- priest / affliction Mind Flay + Drain Soul clip lanes reachable at all.
-- Everything else keeps the blanket skip, and a hard cast always keeps it.
-- ============================================================================
local clip_evaluated = {}
local function clip_track(name)
    return {
        name = name,
        category = "damage",
        matches = function() clip_evaluated[#clip_evaluated + 1] = name; return false end,
        execute = function() return false end,
    }
end

local function shadow_registry(clip_ids)
    local reg = {
        class_config = { class_key = "priest", default_playstyle = "shadow" },
        playstyles = { shadow = { clip_track("VampiricTouch") } },
        options = { shadow = { get_state = function(ctx) return ctx end } },
    }
    if clip_ids then reg.channel_clip_ids = clip_ids end
    return reg
end

NS.class_middleware = { priest = {} }
NS.set_setting("playstyle", "shadow")
NS.set_setting("active_playstyle", nil)

-- (a) Declared clip channel + reconciling id -> the loop re-enters mid-channel.
NS.rotation_registry = shadow_registry({ [48156] = true })
player.is_casting = function() return false end
player.is_channeling = function() return true end
player.get_active_channel_spell_id = function() return 48156 end
clip_evaluated = {}
dispatcher.on_rotation_update()
assert_true(#clip_evaluated == 1,
    "declared clip channel: the playstyle loop must re-enter mid-channel (evaluated=" .. tostring(#clip_evaluated) .. ")")

-- (b) Same channeling state, channel id NOT declared -> blanket skip holds.
player.get_active_channel_spell_id = function() return 15407 end
clip_evaluated = {}
dispatcher.on_rotation_update()
assert_true(#clip_evaluated == 0,
    "undeclared channel: blanket skip must keep the loop out (evaluated=" .. tostring(#clip_evaluated) .. ")")

-- (c) A hard cast never re-enters, even when the id matches.
player.is_casting = function() return true end
player.is_channeling = function() return false end
player.get_active_channel_spell_id = function() return 48156 end
clip_evaluated = {}
dispatcher.on_rotation_update()
assert_true(#clip_evaluated == 0,
    "hard cast: the channel-clip opt-in must not apply (evaluated=" .. tostring(#clip_evaluated) .. ")")

-- (d) Registry with no channel_clip_ids (the pre-signal shape) -> unchanged.
NS.rotation_registry = shadow_registry(nil)
player.is_casting = function() return false end
player.is_channeling = function() return true end
clip_evaluated = {}
dispatcher.on_rotation_update()
assert_true(#clip_evaluated == 0,
    "registry without channel_clip_ids: blanket skip unchanged (evaluated=" .. tostring(#clip_evaluated) .. ")")

-- (e) The REAL core registry merges declarations at register time (single owner).
local real_registry = { playstyles = {}, options = {}, channel_clip_ids = {} }
real_register(real_registry, "shadow", {}, { channel_clip_ids = { 47855, 11675 } })
assert_true(real_registry.channel_clip_ids[47855] == true
    and real_registry.channel_clip_ids[11675] == true,
    "core register() must merge declared channel_clip_ids into the registry set")
assert_true(real_registry.channel_clip_ids[48156] == nil,
    "core register() must not invent undeclared clip ids")
assert_true(real_registry.channel_clip_ids[true] == nil and real_registry.channel_clip_ids["47855"] == nil,
    "core register() must ignore non-numeric clip ids")

player.is_casting = function() return false end
player.is_channeling = function() return false end

-- ============================================================================
-- Thin-spec guide pass (2026-09-12): a NEW lane fires through the REAL
-- dispatcher, not just the battery harness. The real affliction_wotlk spec is
-- loaded, its real DSL-compiled strategies registered as the active playstyle,
-- and the REAL dispatcher builds context.target_is_boss from NS.unit_is_boss
-- (main_sylvanas.lua:1333). With the earlier DoT lanes satisfied, the new
-- Curse of Doom lane must claim the cast on a boss and emit it via cast_safe.
-- ============================================================================
player.is_casting = function() return false end
player.is_channeling = function() return false end

-- Real-read mocks keyed to the ids the real spec reads (Haunt 59164,
-- Corruption 47813, UA 47843, CoA 47864 healthy; Curse of Doom 47867 down).
local dot_healthy = { [59164] = true, [47813] = true, [47843] = true, [47864] = true }
NS.debuff_remains = function(unit, ids)
    for _, id in ipairs(ids) do
        if dot_healthy[id] then return 30 end
    end
    return 0
end
NS.buff_up = function() return false end
NS.cooldown_remains = function() return 0 end
NS.aoe_target_meets = function() return false end
NS.should_use_long_cd = function() return true end
NS.unit_is_boss = function() return true end

local affl = dofile("EaxRotations/classes/warlock/affliction_wotlk.lua")
assert_true(type(affl) == "table" and type(affl.strategies) == "table",
    "affliction_wotlk loads for the dispatcher proof")

-- Name the lane the real dispatcher actually executed.
local fired_lane = nil
for i = 1, #affl.strategies do
    local s = affl.strategies[i]
    local orig = s.execute
    s.execute = function(ctx, state)
        local res = orig(ctx, state)
        if res then fired_lane = s.name end
        return res
    end
end

NS.class_middleware = { warlock = {} }
NS.rotation_registry = {
    class_config = { class_key = "warlock", default_playstyle = "affliction" },
    playstyles = { affliction = affl.strategies },
    options = { affliction = { get_state = affl.build_state } },
}
NS.set_setting("playstyle", "affliction")
NS.set_setting("active_playstyle", nil)
NS.refresh_settings_cache()

reset()
fired_lane = nil
local ok_affl, err_affl = pcall(dispatcher.on_rotation_update)
assert_true(ok_affl, "real dispatcher tick with the real affliction spec must not error: " .. tostring(err_affl))
assert_eq(fired_lane, "CurseOfDoom",
    "the new Curse of Doom lane must fire through the REAL dispatcher on a boss (fired=" .. tostring(fired_lane) .. ")")
assert_true(casts >= 1, "the new lane must emit a real cast through NS.izi.cast_safe (casts=" .. tostring(casts) .. ")")

-- ============================================================================
-- Thin-spec guide pass (2026-09-12), part 2: the REAL warrior protection spec
-- through the REAL dispatcher. With the earlier lanes held (hp 100, nothing to
-- interrupt, rage 15 = enough for a shout but under Shield Slam/Heroic Strike/
-- Shield Block), the new CommandingShout upkeep lane must claim the cast and
-- emit it via cast_safe -- the same proof shape as the affliction lane above.
-- ============================================================================
player.get_health_percentage = function() return 100 end
player.is_casting = function() return false end
player.is_channeling = function() return false end

-- rage 15: enough for a shout (10) but under Shield Slam (20) / Heroic Strike
-- (30) / Shield Block (60); Revenge is held on cooldown so the shout is next.
player.get_power = function() return 15 end
NS.POWER_RAGE = 1
NS.swing_time_until = function() return 999 end
NS.is_interruptible = function() return false end
NS.buff_remains = function() return 0 end     -- Commanding Shout down
NS.debuff_remains = function() return 0 end
NS.cooldown_remains = function(action)
    local id = action
    if type(action) == "table" and type(action.id) == "function" then id = action:id() end
    if id == 57823 or id == 30357 then return 5 end   -- Revenge on cooldown
    return 0
end
NS.unit_is_boss = function() return false end

local prot = dofile("EaxRotations/classes/warrior/protection_wotlk.lua")
assert_true(type(prot) == "table" and type(prot.strategies) == "table",
    "protection_wotlk loads for the dispatcher proof")

local fired_prot = nil
for i = 1, #prot.strategies do
    local s = prot.strategies[i]
    local orig = s.execute
    s.execute = function(ctx, state)
        local res = orig(ctx, state)
        if res then fired_prot = s.name end
        return res
    end
end

NS.class_middleware = { warrior = {} }
NS.rotation_registry = {
    class_config = { class_key = "warrior", default_playstyle = "protection" },
    playstyles = { protection = prot.strategies },
    options = { protection = { get_state = prot.build_state } },
}
NS.set_setting("playstyle", "protection")
NS.set_setting("active_playstyle", nil)
NS.refresh_settings_cache()

reset()
fired_prot = nil
local ok_prot, err_prot = pcall(dispatcher.on_rotation_update)
assert_true(ok_prot, "real dispatcher tick with the real warrior protection spec must not error: " .. tostring(err_prot))
assert_eq(fired_prot, "CommandingShout",
    "the new CommandingShout lane must fire through the REAL dispatcher (fired=" .. tostring(fired_prot) .. ")")
assert_true(casts >= 1, "the new shout lane must emit a real cast through NS.izi.cast_safe (casts=" .. tostring(casts) .. ")")

-- Non-vacuity: with the 2-min shout already up the same tick must not fire it.
NS.buff_remains = function() return 120 end
reset()
fired_prot = nil
local ok_prot2, err_prot2 = pcall(dispatcher.on_rotation_update)
assert_true(ok_prot2, "second dispatcher tick must not error: " .. tostring(err_prot2))
assert_true(fired_prot ~= "CommandingShout",
    "with the shout up the lane must hold (fired=" .. tostring(fired_prot) .. ")")

-- ============================================================================
-- Destruction priority-race pass (2026-09-13): the curse lanes must be able
-- to WIN THE GCD through the REAL dispatcher. WotLK Conflagrate has a real
-- 10s cooldown and, once Immolate is up, its lane sits at the top of the
-- race; without a cooldown gate it claimed the slot on every frame it was
-- cooling down, so the Curse of Agony lane below it (wl_destro_wotlk.apl.json
-- entry 8) only got a turn when the central guard happened to reject the
-- recast. State: Immolate healthy (12s) so Conflagrate's Immolate gate is
-- open, CoE healthy, non-boss (so Curse of Doom holds and Agony owns the
-- curse slot), Agony down, mana 19 (ChaosBolt/Incinerate out of the race),
-- no Backdraft, target hp 80 (Shadowburn holds).
-- ============================================================================
player.get_mana_percentage = function() return 19 end
player.is_casting = function() return false end
player.is_channeling = function() return false end

local DESTRO_IMMOLATE, DESTRO_COE = 47811, 47865
NS.debuff_remains = function(unit, ids)
    for _, id in ipairs(ids) do
        if id == DESTRO_IMMOLATE then return 12 end
        if id == DESTRO_COE then return 60 end
    end
    return 0
end
NS.buff_up = function() return false end
NS.buff_remains = function() return 0 end
NS.aoe_target_meets = function() return false end
NS.unit_is_boss = function() return false end

-- Conflagrate 30912 ready / cooling; everything else ready.
local conflag_cd = 0
NS.cooldown_remains = function(action)
    local id = action
    if type(action) == "table" then
        if type(action.id) == "function" then id = action:id() end
        if type(id) ~= "number" then id = action._meta and action._meta.ids and action._meta.ids[1] end
    end
    if id == 30912 then return conflag_cd end
    return 0
end

local dest = dofile("EaxRotations/classes/warlock/destruction_wotlk.lua")
assert_true(type(dest) == "table" and type(dest.strategies) == "table",
    "destruction_wotlk loads for the dispatcher priority-race proof")

local fired_dest = nil
for i = 1, #dest.strategies do
    local st = dest.strategies[i]
    local orig = st.execute
    st.execute = function(ctx, state)
        local res = orig(ctx, state)
        if res then fired_dest = st.name end
        return res
    end
end

NS.class_middleware = { warlock = {} }
NS.rotation_registry = {
    class_config = { class_key = "warlock", default_playstyle = "destruction" },
    playstyles = { destruction = dest.strategies },
    options = { destruction = { get_state = dest.build_state } },
}
NS.set_setting("playstyle", "destruction")
NS.set_setting("active_playstyle", nil)
NS.refresh_settings_cache()

-- Tick A: Conflagrate available -> the top-of-race lane wins.
conflag_cd = 0
reset()
fired_dest = nil
local ok_d1, err_d1 = pcall(dispatcher.on_rotation_update)
assert_true(ok_d1, "destruction dispatcher tick must not error: " .. tostring(err_d1))
assert_eq(fired_dest, "Conflagrate",
    "with Conflagrate available it must still win the race (fired=" .. tostring(fired_dest) .. ")")

-- Tick B: same state, Conflagrate cooling -> the CURSE lane wins the GCD.
conflag_cd = 4
reset()
fired_dest = nil
local ok_d2, err_d2 = pcall(dispatcher.on_rotation_update)
assert_true(ok_d2, "second destruction tick must not error: " .. tostring(err_d2))
assert_eq(fired_dest, "CurseOfAgony",
    "with Conflagrate on cooldown the Curse of Agony lane must claim the GCD (fired=" .. tostring(fired_dest) .. ")")
assert_true(casts >= 1, "the curse lane must emit a real cast through NS.izi.cast_safe (casts=" .. tostring(casts) .. ")")

-- Tick C: Conflagrate available but Immolate DOWN -> its own gate still holds,
-- and the APL order takes over: Immolate (entry 4) is re-applied before the
-- curse (entry 8), so the curse lane only owns the GCD once Immolate is up.
conflag_cd = 0
NS.debuff_remains = function(unit, ids)
    for _, id in ipairs(ids) do
        if id == DESTRO_COE then return 60 end
    end
    return 0
end
reset()
fired_dest = nil
local ok_d3, err_d3 = pcall(dispatcher.on_rotation_update)
assert_true(ok_d3, "third destruction tick must not error: " .. tostring(err_d3))
assert_true(fired_dest ~= "Conflagrate",
    "without Immolate the Conflagrate lane must hold (fired=" .. tostring(fired_dest) .. ")")
assert_eq(fired_dest, "Immolate",
    "with Immolate down the entry-4 refresh lane outranks the entry-8 curse (fired=" .. tostring(fired_dest) .. ")")

-- Tick D: the other named lane — on a boss with Conflagrate cooling, Curse
-- of Doom (entry 3) owns the curse slot and wins the GCD.
NS.unit_is_boss = function() return true end
NS.debuff_remains = function(unit, ids)
    for _, id in ipairs(ids) do
        if id == DESTRO_IMMOLATE then return 12 end
        if id == DESTRO_COE then return 60 end
    end
    return 0
end
conflag_cd = 4
reset()
fired_dest = nil
local ok_d4, err_d4 = pcall(dispatcher.on_rotation_update)
assert_true(ok_d4, "boss destruction tick must not error: " .. tostring(err_d4))
assert_eq(fired_dest, "CurseOfDoom",
    "with Conflagrate cooling, Curse of Doom must claim the GCD on a boss (fired=" .. tostring(fired_dest) .. ")")
assert_true(casts >= 1, "the boss curse lane must emit a real cast through NS.izi.cast_safe (casts=" .. tostring(casts) .. ")")

-- ============================================================================
-- Full WotLK dispatcher coverage (2026-09-13): EVERY WotLK spec (41 files)
-- must not just match under the battery harness - it must load and drive the
-- REAL decision loop and have at least one lane claim the cast. The channel
-- pass exposed lanes that matched statelessly in the battery while being dead
-- in the live dispatcher, so per-spec reachability is proven here for the whole
-- era instead of for the handful of specs picked by hand.
--
-- Each spec runs with the SAME friendly baseline: real spec file, real
-- build_state, real DSL strategies, real dispatcher (context build + role/
-- playstyle filter + matches + execute). Only the engine surface is mocked -
-- cooldowns ready, target valid and in range, no movement/cast/channel - and
-- per-spec preparation only sets the shapeshift form a spec needs (the same
-- thing the battery models with its form scenario bank). No spec state is
-- fabricated: the state under test is whatever the spec's own build_state
-- derives from that engine surface.
-- ============================================================================
local WOTLK_SPECS = {
    { "deathknight", "blood" }, { "deathknight", "frost" }, { "deathknight", "leveling" }, { "deathknight", "unholy" },
    { "druid", "balance" }, { "druid", "bear" }, { "druid", "cat" }, { "druid", "leveling" }, { "druid", "resto" },
    { "hunter", "beast_mastery" }, { "hunter", "leveling" }, { "hunter", "marksmanship" }, { "hunter", "survival" },
    { "mage", "arcane" }, { "mage", "fire" }, { "mage", "frost" }, { "mage", "leveling" },
    { "paladin", "holy" }, { "paladin", "leveling" }, { "paladin", "protection" }, { "paladin", "retribution" },
    { "priest", "discipline" }, { "priest", "holy" }, { "priest", "leveling" }, { "priest", "shadow" },
    { "rogue", "assassination" }, { "rogue", "combat" }, { "rogue", "leveling" }, { "rogue", "subtlety" },
    { "shaman", "elemental" }, { "shaman", "enhancement" }, { "shaman", "leveling" }, { "shaman", "restoration" },
    { "warlock", "affliction" }, { "warlock", "demonology" }, { "warlock", "destruction" }, { "warlock", "leveling" },
    { "warrior", "arms" }, { "warrior", "fury" }, { "warrior", "leveling" }, { "warrior", "protection" },
}
local wotlk_form = nil          -- shapeshift form the running spec expects
local wotlk_buffs_up = false    -- are my own buffs already up?
local wotlk_cd_ready = true     -- are my cooldowns ready?
local healer_hp = 100           -- friendly hp the running spec sees

-- One friendly engine surface per pass. Pass 1 is "usable now" (cooldowns
-- ready, debuffs down so refresh lanes want to apply, my own buffs down so
-- upkeep lanes want to apply); later passes flip buffs/cooldowns so those
-- lanes hold and the damage/heal arc is the one that claims the GCD.
local function install_dispatcher_baseline(pass)
    wotlk_form = nil
    wotlk_buffs_up = pass.buffs_up
    wotlk_cd_ready = pass.cooldown_ready
    healer_hp = pass.hp

    enemy_hp = pass.target_hp or 80
    player.get_health_percentage = function() return healer_hp end
    player.get_mana_percentage = function() return 100 end
    player.get_power = function() return 1000 end
    player.gcd_remains = function() return 0 end
    player.is_moving = function() return false end
    player.is_casting = function() return false end
    player.is_channeling = function() return false end
    player.is_in_combat = function() return true end
    player.get_stance = function() return 1 end   -- Battle stance (warrior files read me:get_stance())
    player.is_behind = function() return true end
    -- Forms are buff-driven in the engine (NS.has_form -> has_player_buff), so
    -- the shape is mocked here the way the battery's form scenario bank does it.
    NS.has_form = function(name)
        if type(name) ~= "string" then return false end
        return wotlk_form ~= nil and name == wotlk_form
    end
    NS.spell_ready = function() return wotlk_cd_ready end
    NS.cooldown_remains = function() return wotlk_cd_ready and 0 or 30 end
    NS.get_spell_cooldown = function() return wotlk_cd_ready and 0 or 30 end
    NS.buff_up = function() return wotlk_buffs_up end
    NS.buff_remains = function() return wotlk_buffs_up and 30 or 0 end
    NS.buff_stacks = function() return 0 end
    NS.buff_points = function() return 0 end
    NS.debuff_up = function() return false end
    NS.debuff_remains = function() return 0 end
    NS.get_debuff_stacks = function() return 0 end
    NS.aoe_target_meets = function() return pass.aoe == true end
    NS.aoe_self_meets = function() return pass.aoe == true end
    NS.aoe_cone_meets = function() return pass.aoe == true end
    NS.should_use_long_cd = function() return wotlk_cd_ready end
    NS.unit_mana_pct = function() return 100 end
    NS.time_now = function() return 100 end
    NS.game_time_ms = function() return 100000 end
    NS.swing_time_until = function() return 0 end
    NS.is_interruptible = function() return true end
    NS.is_behind_target = function() return true end
    NS.has_dispel_type_debuff = function() return false end
    NS.has_pet = function() return true end
    NS.pet_exists = function() return true end
    NS.find_dead_party_ally = function() return nil end
    NS.get_totem_info = function() return nil end
    NS.gate_overheal = function() return true end
    NS.gate_cooldown_boss_only = function() return true end
    NS.threat_status = function() return 0 end
    NS.unit_is_boss = function() return false end
    NS.is_in_party = function() return false end
    NS.is_in_raid = function() return false end
    NS._TRACE_CASTS = nil
    -- try_cast is the decision loop's commit point: count it and accept - the
    -- same shape the CastTrace proof above uses.
    NS.try_cast = function(spell, target, label, opts)
        casts = casts + 1
        return true
    end
    NS.try_cast_position = function(spell, position, range_target, label, opts)
        casts = casts + 1
        return true
    end
end
local WOTLK_PREPARE = {
    ["druid/cat"] = function() wotlk_form = "cat" end,
    ["druid/bear"] = function() wotlk_form = "bear" end,
    ["druid/balance"] = function() wotlk_form = "moonkin" end,
}

-- Engine surfaces per sweep pass. Pass 1 proves the upkeep/cooldown lane the
-- spec opens with; the later passes put those lanes on hold (my buffs up,
-- cooldowns spent, then a hurt friendly) so the lane that then claims the GCD
-- is the spec's damage/heal arc rather than the first upkeep lane in the list.
local WOTLK_PASSES = {
    { key = "upkeep",   buffs_up = false, cooldown_ready = true,  hp = 100 },
    { key = "damage",   buffs_up = true,  cooldown_ready = true,  hp = 100 },
    { key = "spent",    buffs_up = true,  cooldown_ready = false, hp = 100 },
    { key = "low_hp",   buffs_up = true,  cooldown_ready = true,  hp = 40 },

    { key = "execute",  buffs_up = true,  cooldown_ready = false, hp = 100, target_hp = 20 },
    { key = "aoe",      buffs_up = true,  cooldown_ready = false, hp = 100, aoe = true },
}

local wotlk_failures = {}
local wotlk_proven = {}
local wotlk_lanes_seen = {}
local wotlk_proven_specs, wotlk_proven_lanes, wotlk_passes_run = 0, 0, 0
for wi = 1, #WOTLK_SPECS do
    local entry = WOTLK_SPECS[wi]
    local class_key, spec_key = entry[1], entry[2]
    local key = class_key .. "/" .. spec_key
    local rel = "classes/" .. class_key .. "/" .. spec_key .. "_wotlk"
    local path = "EaxRotations/" .. rel .. ".lua"
    package.loaded[rel] = nil
    local loaded, mod = pcall(dofile, path)
    if not loaded or type(mod) ~= "table" or type(mod.strategies) ~= "table" then
        wotlk_failures[#wotlk_failures + 1] = key .. " (load: " .. tostring(mod) .. ")"
    else
        local lanes = {}
        for i = 1, #mod.strategies do
            local strat = mod.strategies[i]
            local orig_exec = strat.execute
            strat.execute = function(ctx, state)
                local res = orig_exec(ctx, state)
                if res then lanes[strat.name] = true end
                return res
            end
        end
        local last_tick_error = nil
        for pi = 1, #WOTLK_PASSES do
            local pass = WOTLK_PASSES[pi]
            install_dispatcher_baseline(pass)
            local prepare = WOTLK_PREPARE[key]
            if prepare then prepare() end
            NS.class_middleware = { [class_key] = {} }
            NS.rotation_registry = {
                class_config = { class_key = class_key, default_playstyle = spec_key },
                playstyles = { [spec_key] = mod.strategies },
                options = { [spec_key] = { get_state = mod.build_state } },
            }
            NS.set_setting("playstyle", spec_key)
            NS.set_setting("active_playstyle", nil)
            NS.refresh_settings_cache()
            reset()
            local ticked, err = pcall(dispatcher.on_rotation_update)
            wotlk_passes_run = wotlk_passes_run + 1
            if not ticked and not last_tick_error then last_tick_error = tostring(err) end
        end
        local lane_names = {}
        for name in pairs(lanes) do lane_names[#lane_names + 1] = name end
        table.sort(lane_names)
        if last_tick_error and #lane_names == 0 then
            wotlk_failures[#wotlk_failures + 1] = key .. " (tick error: " .. last_tick_error .. ")"
        elseif #lane_names == 0 then
            wotlk_failures[#wotlk_failures + 1] = key .. " (no lane claimed a cast in any sweep pass)"
        else
            wotlk_proven_specs = wotlk_proven_specs + 1
            for i = 1, #lane_names do
                if not wotlk_lanes_seen[lane_names[i]] then
                    wotlk_lanes_seen[lane_names[i]] = true
                    wotlk_proven_lanes = wotlk_proven_lanes + 1
                end
            end
            wotlk_proven[#wotlk_proven + 1] = key .. " (" .. #lane_names .. ") -> " .. table.concat(lane_names, ", ")
        end
    end
end

-- Evidence on demand: WOTLK_DISPATCH_VERBOSE=1 prints the lanes each spec proved.
if os.getenv and os.getenv("WOTLK_DISPATCH_VERBOSE") then
    for i = 1, #wotlk_proven do io.write("  [ WOTLK LANES ] " .. wotlk_proven[i] .. "\n") end
end
io.write(string.format("[wotlk-dispatcher] specs proven: %d/%d across %d passes | distinct lanes proven: %d\n",
    wotlk_proven_specs, #WOTLK_SPECS, wotlk_passes_run, wotlk_proven_lanes))
for i = 1, #wotlk_failures do io.write("  [ UNREACHED ] " .. wotlk_failures[i] .. "\n") end
assert_true(#wotlk_failures == 0,
    "every WotLK spec must claim a cast through the real dispatcher; unreached: " .. table.concat(wotlk_failures, " | "))
assert_true(wotlk_proven_specs == #WOTLK_SPECS, "the sweep must cover every WotLK spec (" .. wotlk_proven_specs .. "/" .. #WOTLK_SPECS .. ")")
print("PASS test_dispatcher_role_mode")
