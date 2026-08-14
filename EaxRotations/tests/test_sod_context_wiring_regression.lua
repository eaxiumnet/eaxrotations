-- test_sod_context_wiring_regression.lua — pins the SOD context wiring unit
-- (2026-08-11): shared/sod_context_sylvanas.lua enrich() wired into the
-- dispatcher's is_sod block (main_sylvanas.lua) produces the rotation-state
-- fields the _sod spec files read, waking rotations that were dead on live
-- SoD clients (bear/cat form, warden Rockbiter gate, warlock-tank
-- Metamorphosis gate, rogue Envenom, enhancement LavaBurst/LavaLash).
-- WHAT:  (1) producer-level: enrich() maps every wired field from the mock
--        API — fired when the API returns the value, silent/default
--        otherwise; (2) id-set verification: the spell-id lists passed to
--        buff_up/debuff_remains match the repo's own class data (era-data
--        mirroring); (3) consumption-side: feral / warden / warlock-tank
--        strategies FIRE with the wired context and stay SILENT without it
--        (non-vacuity at the rotation layer); (4) allowlist guard: the wired
--        fields must not be re-pinned in the read-side audit's
--        NO_WRITER_ALLOWLIST (a re-allowlist-to-hide-drift fails loudly).
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   the read-side audit flagged the ~25-field SOD family as read-but-
--        unproduced; every _sod rotation degraded to defaults. A future edit
--        that drops the wiring must fail loudly instead of silently
--        re-deading the rotations.
-- SAFETY: pure test with a local mock NS installed before dofile (the runner
--         snapshots/restores _G per suite); no game data, no fs writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
end

local function assert_eq(a, b, label)
    if a ~= b then
        error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

-- ============================================================================
-- Mock NS: every helper sod_context_sylvanas calls, driven by per-id tables
-- so each assertion controls exactly one field. Calls are recorded so the
-- test can verify the exact id sets the module passes to the API.
-- ============================================================================
local forms = {}             -- form name -> bool
local buff_flags = {}        -- buff id -> bool            (NS.buff_up)
local buff_remains_map = {}  -- buff id -> seconds         (NS.buff_remains)
local debuff_remains_map = {}-- debuff id -> seconds      (NS.debuff_remains)
local debuff_stacks_map = {} -- debuff id -> stacks       (NS.debuff_stacks)
local buff_points_map = {}   -- buff id -> {points}       (NS.buff_points)
local pet_hp = 100
local swing, oh_swing = 0, 0
local buff_calls = {}          -- {ids} for every NS.buff_up call
local debuff_remains_calls = {} -- {ids} for every NS.debuff_remains call
local last_debuff_stacks_ids = nil
local last_points_ids, last_form = nil, nil

local function contains_id_set(calls, wanted)
    for _, ids in ipairs(calls) do
        local ok = #ids == #wanted
        if ok then
            for i = 1, #wanted do if ids[i] ~= wanted[i] then ok = false break end end
        end
        if ok then return true end
    end
    return false
end

local function first_match(map, ids)
    for _, id in ipairs(ids) do
        if map[id] ~= nil then return map[id] end
    end
    return nil
end

local ns = {
    is_sod = function() return true end,
    is_tbc = function() return false end,
    is_vanilla = function() return false end,
    is_wotlk = function() return false end,
    rotation_registry = { register = function() end },
    PLAYER_UNIT = {},
    spell_ready = function() return true end,
    try_cast = function() return true end,
    has_form = function(name)
        last_form = name
        return forms[name] == true
    end,
    buff_up = function(unit, ids)
        buff_calls[#buff_calls + 1] = ids
        return first_match(buff_flags, ids) == true
    end,
    buff_remains = function(unit, ids)
        return first_match(buff_remains_map, ids) or 0
    end,
    debuff_remains = function(unit, ids)
        debuff_remains_calls[#debuff_remains_calls + 1] = ids
        return first_match(debuff_remains_map, ids) or 0
    end,
    debuff_stacks = function(unit, ids)
        last_debuff_stacks_ids = ids
        return first_match(debuff_stacks_map, ids) or 0
    end,
    buff_points = function(unit, ids)
        last_points_ids = ids
        return first_match(buff_points_map, ids)
    end,
    unit_health_pct = function(unit) return pet_hp end,
    get_time_until_swing = function() return swing end,
    get_time_until_oh_swing = function() return oh_swing end,
}
_G.EaxRotations = ns

package.loaded["shared/sod_context_sylvanas"] = nil
local sod = require("shared/sod_context_sylvanas")

local function fresh_ctx()
    return { me = {}, target = {}, pet = {}, lowest_unit = {},
        is_moving = false, hp = 80, target_hp = 50, pet_dead = false }
end

local function reset_mock()
    for k in pairs(forms) do forms[k] = nil end
    for k in pairs(buff_flags) do buff_flags[k] = nil end
    for k in pairs(buff_remains_map) do buff_remains_map[k] = nil end
    for k in pairs(debuff_remains_map) do debuff_remains_map[k] = nil end
    for k in pairs(debuff_stacks_map) do debuff_stacks_map[k] = nil end
    for k in pairs(buff_points_map) do buff_points_map[k] = nil end
    pet_hp, swing, oh_swing = 100, 0, 0
    buff_calls = {}
    debuff_remains_calls = {}
    last_debuff_stacks_ids = nil
    last_points_ids, last_form = nil
end

-- ============================================================================
-- (1) Producer-level: every wired field maps from the mock API.
-- ============================================================================
-- Forms: in_cat_form / in_bear_form via NS.has_form("cat"/"bear").
reset_mock()
forms.cat = true
local ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.in_cat_form, true, "in_cat_form from has_form(cat)")
assert_eq(ctx.in_bear_form, false, "in_bear_form silent without bear form")
assert_eq(last_form, "bear", "enrich checks bear form")
reset_mock()
forms.bear = true
ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.in_bear_form, true, "in_bear_form from has_form(bear)")
assert_eq(ctx.in_cat_form, false, "in_cat_form silent without cat form")

-- Aliases: moving / hp_pct / target_hp_pct.
reset_mock()
ctx = fresh_ctx()
ctx.is_moving = true
sod.enrich(ctx)
assert_eq(ctx.moving, true, "moving aliases is_moving")
assert_eq(ctx.hp_pct, 80, "hp_pct aliases hp")
assert_eq(ctx.target_hp_pct, 50, "target_hp_pct aliases target_hp")

-- Metamorphosis: buff_up with the WotLK aura + SoD rune candidate ids.
reset_mock()
buff_flags[47241] = true
ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.metamorphosis_active, true, "metamorphosis_active from buff 47241")
assert_eq(ctx.metamorphosis_active ~= nil, true, "metamorphosis_active boolean produced")

-- Pet health.
reset_mock()
pet_hp = 30
ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.pet_hp_pct, 30, "pet_hp_pct from unit_health_pct(pet)")

-- Rogue poison stacks / target_poisoned / refresh remains.
reset_mock()
debuff_stacks_map[11355] = 4
debuff_remains_map[412096] = 6
buff_remains_map[5171] = 5
ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.poison_stacks, 4, "poison_stacks from deadly-poison debuff stacks")
assert_eq(ctx.deadly_poison_stacks, 4, "deadly_poison_stacks mirrors poison_stacks")
assert_eq(ctx.target_poisoned, true, "target_poisoned true when poison stacks > 0")
assert_eq(ctx.crimson_tempest_remains, 6, "crimson_tempest_remains from debuff 412096")
assert_eq(ctx.snd_remains, 5, "snd_remains from S&D buff")
assert_eq(ctx.blade_dance_remains, 0, "blade_dance_remains default 0")
reset_mock()
ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.poison_stacks, 0, "poison_stacks 0 without poison")
assert_eq(ctx.target_poisoned, false, "target_poisoned false without poison")

-- Shaman: Maelstrom stacks, shields, rockbiter imbue, Riptide on heal target.
reset_mock()
buff_points_map[53817] = { 4 }
buff_flags[8134] = true
buff_flags[24398] = true
buff_flags[8017] = true
buff_remains_map[408521] = 7
ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.maelstrom_stacks, 4, "maelstrom_stacks from buff_points 53817")
assert_eq(ctx.lightning_shield_up, true, "lightning_shield_up from shield buff")
assert_eq(ctx.water_shield_up, true, "water_shield_up from water-shield buff")
assert_eq(ctx.has_rockbiter_imbue, true, "has_rockbiter_imbue from rockbiter buff")
assert_eq(ctx.mainhand_imbue, "rockbiter", "mainhand_imbue name when rockbiter active")
assert_eq(ctx.riptide_remains, 7, "riptide_remains on heal target")
-- Id-set mirroring: the exact era data sets must be passed to the API.
assert_true(contains_id_set(buff_calls, { 33736, 24398 }),
    "water shield id set passed (repo enhancement_sylvanas:99)")
assert_true(contains_id_set(buff_calls, { 25485, 25479, 16316, 16315, 16314, 10399, 8019, 8018, 8017 }),
    "rockbiter id set passed (repo enhancement_sylvanas:104)")
assert_eq(last_points_ids[1], 53817, "maelstrom id set starts with 53817 (repo enhancement_wotlk:32)")

-- Druid resto HoTs on the heal target.
reset_mock()
buff_flags[33763] = true
buff_flags[25299] = true
ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.has_lifebloom, true, "has_lifebloom from Lifebloom 33763")
assert_eq(ctx.has_rejuvenation, true, "has_rejuvenation from Rejuvenation 25299")

-- Swing timers.
reset_mock()
swing, oh_swing = 2.5, 1.5
ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.auto_swing_remains, 2.5, "auto_swing_remains from get_time_until_swing")
assert_eq(ctx.melee_swing_remains, 1.5, "melee_swing_remains from get_time_until_oh_swing")

-- Feral / feral-tank / warlock / warrior refresh remains.
reset_mock()
debuff_remains_map[409828] = 9
debuff_remains_map[9896] = 11
debuff_remains_map[414644] = 3
debuff_stacks_map[414644] = 2
debuff_remains_map[11717] = 8
debuff_remains_map[11668] = 4
debuff_remains_map[11672] = 13
debuff_remains_map[403851] = 5
debuff_remains_map[25295] = 12
debuff_stacks_map[25225] = 6
ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.mangle_remains, 9, "mangle_remains from Mangle 409828")
assert_eq(ctx.rip_remains, 11, "rip_remains from Rip 9896")
assert_eq(ctx.lacerate_remains, 3, "lacerate_remains from Lacerate 414644")
assert_eq(ctx.lacerate_stacks, 2, "lacerate_stacks from Lacerate stacks")
assert_eq(ctx.curse_remains, 8, "curse_remains from Curse of Recklessness")
assert_eq(ctx.immolate_remains, 4, "immolate_remains from Immolate 11668")
assert_eq(ctx.corruption_remains, 13, "corruption_remains from Corruption 11672")
assert_eq(ctx.shadow_cleave_remains, 5, "shadow_cleave_remains from 403851")
assert_eq(ctx.serpent_sting_remains, 12, "serpent_sting_remains from Serpent Sting")
assert_eq(ctx.sunder_stacks, 6, "sunder_stacks from Sunder 25225")
assert_eq(ctx.demoralizing_remains, 0, "demoralizing_remains default 0 without demo shout")
reset_mock()
debuff_remains_map[11556] = 10
ctx = fresh_ctx()
sod.enrich(ctx)
assert_eq(ctx.demoralizing_remains, 10, "demoralizing_remains from Demoralizing Shout 11556")
assert_true(contains_id_set(debuff_remains_calls, { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }),
    "demo shout id set passed (repo arms_sylvanas:79)")

-- ============================================================================
-- (2) Consumption-side: wired context wakes the rotations, absence keeps the
--     pre-wiring behavior (non-vacuity at the rotation layer).
-- ============================================================================
package.loaded["classes/druid/feral_sod"] = nil
local feral = require("classes/druid/feral_sod")
local runes_feral = { [407988] = true, [409828] = true, [407995] = true }
local function feral_ctx(with_state)
    local c = { is_sod = true, sod_phase = 8, in_combat = true, target = {}, me = {},
        sod_runes = runes_feral }
    if with_state then
        c.in_cat_form = true
        c.savage_roar_remains = 0
        c.combo_points = 5
        c.energy = 100
        c.target_ttd = 30
    end
    return c
end
local fc_w = feral_ctx(true)
local fs_w = feral.build_state(fc_w)
assert_true(feral.strategies[2].matches(fc_w, fs_w), "feral SavageRoar FIRES with wired in_cat_form")
assert_true(feral.strategies[4].matches(fc_w, fs_w), "feral Rip FIRES with wired state (5cp, ttd 30)")
local fc_wo = feral_ctx(false)
local fs_wo = feral.build_state(fc_wo)
assert_eq(feral.strategies[2].matches(fc_wo, fs_wo), false, "feral SavageRoar SILENT without wired form")
assert_eq(feral.strategies[3].matches(fc_wo, fs_wo), false, "feral Mangle SILENT without wired form")

package.loaded["classes/shaman/warden_sod"] = nil
local warden = require("classes/shaman/warden_sod")
local function warden_ctx(with_imbue)
    local c = { is_sod = true, sod_phase = 8, mana_pct = 50, target = {},
        sod_runes = { [408531] = true, [425336] = true } }
    if with_imbue then c.mainhand_imbue = "rockbiter"; c.has_rockbiter_imbue = true end
    return c
end
local wc_w = warden_ctx(true)
local ws_w = warden.build_state(wc_w)
assert_true(warden.strategies[1].matches(wc_w, ws_w), "warden ShamanisticRage FIRES with rockbiter imbue")
local wc_wo = warden_ctx(false)
local ws_wo = warden.build_state(wc_wo)
assert_eq(warden.strategies[1].matches(wc_wo, ws_wo), false, "warden SILENT without imbue (whole rotation gated)")

package.loaded["classes/warlock/tank_sod"] = nil
local wtank = require("classes/warlock/tank_sod")
local function wtank_ctx(with_meta)
    local c = { is_sod = true, sod_phase = 8, in_combat = true, target = {}, me = {},
        sod_runes = { [403789] = true, [425463] = true, [412758] = true } }
    if with_meta then c.metamorphosis_active = true end
    return c
end
local wc_w2 = wtank_ctx(true)
local ws_w2 = wtank.build_state(wc_w2)
assert_true(wtank.strategies[2].matches(wc_w2, ws_w2), "warlock-tank DemonicGrace FIRES with metamorphosis_active")
local wc_wo2 = wtank_ctx(false)
local ws_wo2 = wtank.build_state(wc_wo2)
assert_eq(wtank.strategies[2].matches(wc_wo2, ws_wo2), false, "warlock-tank SILENT without meta (whole rotation gated)")

-- ============================================================================
-- (3) Allowlist guard: the wired fields must not be re-pinned in the read-side
--     audit's NO_WRITER_ALLOWLIST (a re-allowlist drift must fail loudly).
-- ============================================================================
local audit_path = "EaxRotations/tests/run_read_side_audit_tests.lua"
local f = io.open(audit_path, "rb")
assert_true(f ~= nil, "read-side audit file present: " .. audit_path)
local audit_src = f:read("*a")
f:close()
local allow_start = audit_src:find("local NO_WRITER_ALLOWLIST = {", 1, true)
assert_true(allow_start ~= nil, "audit allowlist block found")
local allow_block = audit_src:sub(allow_start)
local close_at = allow_block:find("\n    },\n", 1, true)
if close_at then allow_block = allow_block:sub(1, close_at) end
local WIRED_FIELDS = {
    "in_cat_form", "in_bear_form", "moving", "metamorphosis_active",
    "has_lifebloom", "has_rejuvenation", "poison_stacks",
    "deadly_poison_stacks", "target_poisoned", "snd_remains",
    "crimson_tempest_remains", "blade_dance_remains", "flame_shock_remains",
    "auto_swing_remains", "melee_swing_remains", "mainhand_imbue",
    "has_rockbiter_imbue", "water_shield_up", "riptide_remains",
    "maelstrom_stacks", "pet_hp_pct", "hp_pct", "target_hp_pct",
    "savage_roar_remains", "mangle_remains", "rip_remains", "rake_remains",
    "lacerate_remains", "lacerate_stacks", "curse_remains",
    "shadow_cleave_remains", "immolate_remains", "corruption_remains",
    "serpent_sting_remains", "sunder_stacks", "demoralizing_remains",
    "fire_totem_active", "water_totem_active", -- W4.2: wired via NS.get_totem_info
}
for _, field in ipairs(WIRED_FIELDS) do
    local pat = "\n%s*" .. field .. "%s*="
    assert_eq(allow_block:find(pat), nil,
        "wired field " .. field .. " must NOT be re-pinned in the audit allowlist")
end

print("PASS test_sod_context_wiring_regression (producer-level field map, id-set mirroring, "
    .. "consumption-side fired/silent for feral/warden/warlock-tank, allowlist guard)")
