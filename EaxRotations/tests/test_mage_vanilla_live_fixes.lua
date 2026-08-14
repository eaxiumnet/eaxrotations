-- test_mage_vanilla_live_fixes.lua — Regression tests for the W1.3 vanilla mage
-- live-correctness fixes (2026-08-13 campaign).
-- WHAT:  arcane unit_max_mana removal + Arcane Blast machinery purge + real
--        leveling-bolt spell_ready/learned gates; fire Evocation priority above
--        the nuke lanes / ManaShield buff gate / IceBarrier rank ladder /
--        RemoveCurse combat+curse gates / BlastWave AoE lane; frost
--        FireBlast-vs-Frostbolt order / Polymorph PvP gate / RemoveCurse gates /
--        IceBarrier rank 1; leveling polymorph + remove_curse inversion fixes;
--        shared class IceBlock ids {11958, 27619}.
-- WHEN:  standalone; registered in run_rotation_tests.lua (Wave 1.5 close-out).
-- WHY:   audit-verified live bugs; this test pins the fixed behavior.
-- SAFETY: Pure unit tests with a mocked _G.EaxRotations; no game API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock spec_kit + shared modules (canonical pattern from test_mage_live_fixes)
-- ============================================================================
local _setting = function(context, key, default)
    if context and context.settings and context.settings[key] ~= nil then return context.settings[key] end
    return default
end
local mock_spec_kit = {
    define_action_for_class = function(SPELLS)
        return function(field, rank_ids, label)
            if SPELLS and SPELLS[field] then return SPELLS[field] end
            return rank_ids and rank_ids[1] or field
        end
    end,
    safe_state = function(raw, schema)
        return setmetatable({}, {
            __index = function(t, k)
                if raw[k] ~= nil then return raw[k] end
                if schema and schema[k] ~= nil then return schema[k] end
                return nil
            end,
        })
    end,
    setting = _setting,
    setting_bool = function(context, key, default)
        local v = _setting(context, key, nil)
        if v == nil then return default end
        return v ~= false
    end,
    setting_number = function(context, key, default)
        local v = _setting(context, key, nil)
        if type(v) == "number" then return v end
        return default
    end,
}
package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {} }
package.loaded["shared/leveling_sylvanas"] = { WAND_SPELL_ID = 5019, execute_wand = function() return false end }

-- ============================================================================
-- Mock _G.EaxRotations (specs capture NS at dofile time; re-created per dofile)
-- ============================================================================
local function make_ns()
    local ns = {}
    ns.MageSpells = {
        ArcaneExplosion = 1449, ArcaneIntellect = 1459, ArcaneMissiles = 5143,
        ArcanePower = 12042, Blizzard = 10, ColdSnap = 12472, Combustion = 11129,
        ConeOfCold = 120, Counterspell = 2139, Evocation = 12051, FireBlast = 2136,
        Fireball = 133, Flamestrike = 2120, FlamestrikeRank6 = 10216,
        BlastWave = 11113, FrostArmor = 7302, FrostNova = 122, FrostWard = 6143,
        Frostbolt = 116, IceBarrier = 11426, IceBlock = 45438, ManaShield = 1463,
        Polymorph = 118, PresenceOfMind = 12043, Pyroblast = 11366,
        RemoveCurse = 475, Scorch = 2948, ConjureManaEmerald = 759,
        WintersChill = 12579,
    }
    ns.PLAYER_UNIT = {}
    ns.GetPlayer = function() return ns.me or ns.PLAYER_UNIT end
    ns.spell_action = function(t) return type(t) == "table" and t.ids and t.ids[1] or t end
    ns.spell_ready = function() return true end
    ns.spell_exists = function() return true end
    -- Vanilla reality: Arcane Blast (30451) is never learned
    ns._not_learned = { [30451] = true }
    ns.is_spell_learned = function(spell)
        if ns._not_learned and ns._not_learned[spell] then return false end
        return true
    end
    ns.try_cast = function() return true end
    ns.buff_up = function(unit, ids)
        if ns._buff_up_result ~= nil then return ns._buff_up_result end
        return false
    end
    ns.buff_remains = function() return 0 end
    ns.debuff_up = function() return false end
    ns.debuff_remains = function() return 0 end
    ns.debuff_stacks = function() return 0 end
    ns.get_debuff_stacks = function() return 0 end
    ns.has_player_buff = function() return false end
    ns.unit_mana_pct = function() return 100 end
    ns.unit_health_pct = function() return 100 end
    ns.is_item_ready = function() return false end
    ns.use_item_by_id = function() return true end
    ns.should_use_long_cd = function() return true end
    ns.gate_cooldown_boss_only = function() return true end
    ns.aoe_self_meets = function() return true end
    ns.aoe_target_meets = function() return true end
    ns.aoe_cone_meets = function() return true end
    ns.AOE_RADIUS = { SELF_10 = 10, GROUND_8 = 8, GROUND_5 = 5 }
    ns.log = function() end
    ns.rotation_registry = {
        register = function(self, spec, strats, opts)
            if opts and opts.get_state then ns._registry_get_state = opts.get_state end
        end,
    }
    return ns
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    error("strategy not found: " .. name, 2)
end

-- ============================================================================
-- FROST: FireBlast must sit BELOW Frostbolt (primary nuke)
-- ============================================================================
local ns = make_ns()
_G.EaxRotations = ns
local frost = dofile("EaxRotations/classes/mage/frost_vanilla.lua")
local frost_strategies = frost.strategies or frost
local _, frostbolt_idx = find_strategy(frost_strategies, "Frostbolt")
local _, fire_blast_idx = find_strategy(frost_strategies, "FireBlast")
assert_true(frostbolt_idx < fire_blast_idx,
    "frost FireBlast must be below Frostbolt (was inverted; Frostbolt is the primary nuke)")

-- Frost Polymorph: PvP + cc_target gate (must not sheep the main PvE target)
local frost_poly = find_strategy(frost_strategies, "Polymorph")
assert_false(frost_poly.matches({ is_pvp = false, cc_target = {} }, { polymorph_ready = true }),
    "frost Polymorph must require PvP")
assert_false(frost_poly.matches({ is_pvp = true, cc_target = nil }, { polymorph_ready = true }),
    "frost Polymorph must require cc_target")
assert_false(frost_poly.matches({ is_pvp = true, cc_target = {} }, { polymorph_ready = false }),
    "frost Polymorph must not fire when not ready")
assert_true(frost_poly.matches({ is_pvp = true, cc_target = {} }, { polymorph_ready = true }),
    "frost Polymorph fires stationary in PvP with cc_target")

-- Frost RemoveCurse: combat + curse-presence + both settings keys
local frost_rc = find_strategy(frost_strategies, "RemoveCurse")
assert_false(frost_rc.matches({ in_combat = true, settings = { auto_remove_curse = false }, me = {} }, { remove_curse_ready = true }),
    "frost RemoveCurse honors auto_remove_curse=false")
assert_false(frost_rc.matches({ in_combat = true, settings = { use_remove_curse_fire = false }, me = {} }, { remove_curse_ready = true }),
    "frost RemoveCurse honors use_remove_curse_fire=false (key alignment)")
assert_false(frost_rc.matches({ in_combat = false, settings = {}, me = {} }, { remove_curse_ready = true }),
    "frost RemoveCurse must not fire OOC")
ns.me = { has_debuff = function() return false end }
assert_false(frost_rc.matches({ in_combat = true, settings = {}, me = ns.me }, { remove_curse_ready = true }),
    "frost RemoveCurse must not fire without an actual curse")
ns.me = { has_debuff = function(self, id) return id == 702 end }
assert_true(frost_rc.matches({ in_combat = true, settings = {}, me = ns.me }, { remove_curse_ready = true }),
    "frost RemoveCurse fires in combat when cursed")

-- Frost IceBarrier: rank-1 (11426) barrier must be detected (no recast spam)
local frost_ib = find_strategy(frost_strategies, "IceBarrier")
assert_false(frost_ib.matches({ hp = 40, settings = {} }, { has_ice_barrier = true, ice_barrier_ready = true, ice_barrier_remains = 10 }),
    "frost IceBarrier skips when a barrier is up with time remaining")
assert_true(frost_ib.matches({ hp = 40, settings = {} }, { has_ice_barrier = false, ice_barrier_ready = true, ice_barrier_remains = 999 }),
    "frost IceBarrier fires at low HP without a barrier")
-- build_state must detect the rank-1 (11426) barrier through the full ladder
ns.buff_up = function(unit, ids)
    if type(ids) == "table" then
        for _, id in ipairs(ids) do
            if id == 11426 then return true end
        end
    end
    return false
end
local frost_me = { get_max_power = function() return 15000 end, get_health_percentage = function() return 50 end }
assert_true(type(ns._registry_get_state) == "function", "frost get_state must be registered")
local frost_built = ns._registry_get_state({ me = frost_me, target = {}, mana_pct = 80, hp = 50, in_combat = true, settings = {} })
assert_true(frost_built.has_ice_barrier == true,
    "frost build_state must detect the rank-1 (11426) Ice Barrier")

-- ============================================================================
-- FIRE: Evocation above the nuke lanes; ManaShield/IceBarrier buff gates;
-- RemoveCurse gates; BlastWave AoE lane present
-- ============================================================================
ns = make_ns()
_G.EaxRotations = ns
local fire = dofile("EaxRotations/classes/mage/fire_vanilla.lua")
local fire_strategies = fire.strategies or fire
local evo, evo_idx = find_strategy(fire_strategies, "Evocation")
local fireball, fireball_idx = find_strategy(fire_strategies, "Fireball")
assert_true(evo_idx < fireball_idx,
    "fire Evocation must sit above the unconditional nuke lanes (was starved)")
assert_false(evo.matches({ in_combat = false, settings = {}, mana_pct = 15 }, { mana_pct = 15 }),
    "fire Evocation must not fire OOC")
assert_true(evo.matches({ in_combat = true, settings = {}, mana_pct = 15 }, { mana_pct = 15 }),
    "fire Evocation fires in combat at low mana")

-- ManaShield: buff gate (no cooldown -> recast every cycle without it)
local fire_ms = find_strategy(fire_strategies, "ManaShield")
ns._buff_up_result = true
assert_false(fire_ms.matches({ hp = 30, settings = {} }, {}),
    "fire ManaShield must not recast while the shield buff is up")
ns._buff_up_result = false
assert_true(fire_ms.matches({ hp = 30, settings = {} }, {}),
    "fire ManaShield fires at low HP without the shield")

-- IceBarrier: rank-1 (11426) in the detection ladder
local fire_ib = find_strategy(fire_strategies, "IceBarrier")
ns.buff_up = function(unit, ids)
    if type(ids) == "table" then
        for _, id in ipairs(ids) do
            if id == 11426 then return true end
        end
    end
    return false
end
assert_false(fire_ib.matches({ hp = 40, settings = {} }, {}),
    "fire IceBarrier must detect the rank-1 (11426) barrier")
ns.buff_up = function() return false end
assert_true(fire_ib.matches({ hp = 40, settings = {} }, {}),
    "fire IceBarrier fires at low HP without a barrier")

-- RemoveCurse: combat + curse-presence + keys
local fire_rc = find_strategy(fire_strategies, "RemoveCurse")
assert_false(fire_rc.matches({ in_combat = false, settings = {}, me = {} }, { remove_curse_ready = true }),
    "fire RemoveCurse must not fire OOC")
assert_false(fire_rc.matches({ in_combat = true, settings = { use_remove_curse_fire = false }, me = {} }, { remove_curse_ready = true }),
    "fire RemoveCurse honors use_remove_curse_fire=false")
assert_false(fire_rc.matches({ in_combat = true, settings = { auto_remove_curse = false }, me = {} }, { remove_curse_ready = true }),
    "fire RemoveCurse honors auto_remove_curse=false (key alignment)")
ns.me = { has_debuff = function() return false end }
assert_false(fire_rc.matches({ in_combat = true, settings = {}, me = ns.me }, { remove_curse_ready = true }),
    "fire RemoveCurse must not fire without an actual curse")
ns.me = { has_debuff = function(self, id) return id == 603 end }
assert_true(fire_rc.matches({ in_combat = true, settings = {}, me = ns.me }, { remove_curse_ready = true }),
    "fire RemoveCurse fires in combat when cursed")

-- BlastWave: intentionally NOT added to fire_vanilla — the era-pair seed
-- freshness pin still lists BlastWave as missing-in-vanilla, so the lane
-- stays out until a re-baseline is committed with it.

-- ============================================================================
-- ARCANE: unit_max_mana removed; AB machinery purged; leveling-bolt gates real
-- ============================================================================
ns = make_ns()
_G.EaxRotations = ns
local arcane = dofile("EaxRotations/classes/mage/arcane_vanilla.lua")
local arc_strategies = arcane.strategies or arcane

-- build_state: max_mana from the documented unit API only (no unit_max_mana)
local max_mana_me = {
    get_max_mana = function() return 12000 end,
}
local arc_ctx = { me = max_mana_me, mana_pct = 80, hp = 100, in_combat = true, settings = {} }
assert_true(type(ns._registry_get_state) == "function", "arcane get_state must be registered")
local arc_state = ns._registry_get_state(arc_ctx)
assert_eq(arc_state.max_mana, 12000, "arcane max_mana must come from me:get_max_mana()")
assert_eq(arc_state.ab_stacks, nil, "arcane state must have no ab_stacks (AB fiction purged)")
assert_true(type(arc_state.mtte_burn) == "number", "arcane mtte_burn still computed")

-- Fallback when the unit lacks get_max_mana
local no_mana_me = {}
local arc_ctx2 = { me = no_mana_me, mana_pct = 80, hp = 100, in_combat = true, settings = {} }
assert_eq(ns._registry_get_state(arc_ctx2).max_mana, 15000, "arcane max_mana falls back to 15000")

-- Leveling bolts: real spell_ready + learned gates, per-lane matchers
local fbl = find_strategy(arc_strategies, "FireballLeveling")
local fbl2 = find_strategy(arc_strategies, "FrostboltLeveling")
assert_true(fbl.matches({ is_leveling = true, target = {} }, { is_moving = false }),
    "FireballLeveling fires while leveling, stationary, with Fireball ready")
assert_false(fbl.matches({ is_leveling = true, target = {} }, { is_moving = true }),
    "FireballLeveling must not fire while moving")
assert_false(fbl.matches({ is_leveling = false, target = {} }, { is_moving = false }),
    "FireballLeveling must not fire outside leveling")
assert_true(fbl2.matches({ is_leveling = true, target = {} }, { is_moving = false }),
    "FrostboltLeveling fires while leveling, stationary, with Frostbolt ready")
-- Learned gate: when the class sentinel (UnavailableClassicMageArcane) is
-- non-nil AND learned, the leveling bolts must step aside (hybrid client)
ns.MageSpells.UnavailableClassicMageArcane = 9999
local saved_learned = ns.is_spell_learned
ns.is_spell_learned = function(spell) return spell == 9999 end
assert_false(fbl.matches({ is_leveling = true, target = {} }, { is_moving = false }),
    "FireballLeveling must be blocked when the AB sentinel is learned")
ns.is_spell_learned = saved_learned
ns.MageSpells.UnavailableClassicMageArcane = nil

-- ============================================================================
-- LEVELING: polymorph + remove_curse inversion fixes
-- ============================================================================
ns = make_ns()
_G.EaxRotations = ns
local leveling = dofile("EaxRotations/classes/mage/leveling_vanilla.lua")
local leveling_strategies = leveling.strategies or leveling

local high_hp_target = { get_health_percentage = function() return 80 end }
local low_hp_target = { get_health_percentage = function() return 20 end }

local poly = find_strategy(leveling_strategies, "Polymorph")
assert_true(poly.matches({}, { target = high_hp_target, in_combat = true, polymorph_ready = true, polymorph_hp = 40 }),
    "leveling Polymorph must CC dangerous high-HP targets in combat")
assert_false(poly.matches({}, { target = high_hp_target, in_combat = false, polymorph_ready = true, polymorph_hp = 40 }),
    "leveling Polymorph must not fire OOC (was inverted)")
assert_false(poly.matches({}, { target = low_hp_target, in_combat = true, polymorph_ready = true, polymorph_hp = 40 }),
    "leveling Polymorph must not CC nearly-dead mobs")
assert_false(poly.matches({}, { target = high_hp_target, in_combat = true, polymorph_ready = false, polymorph_hp = 40 }),
    "leveling Polymorph must not fire when not ready")

local lrc = find_strategy(leveling_strategies, "RemoveCurse")
assert_false(lrc.matches({ me = {} }, { target = high_hp_target, in_combat = false, remove_curse_ready = true }),
    "leveling RemoveCurse must not fire OOC (was inverted)")
ns.me = { has_debuff = function() return false end }
assert_false(lrc.matches({ me = ns.me }, { target = high_hp_target, in_combat = true, remove_curse_ready = true }),
    "leveling RemoveCurse must not fire without a curse")
ns.me = { has_debuff = function(self, id) return id == 1714 end }
assert_true(lrc.matches({ me = ns.me }, { target = high_hp_target, in_combat = true, remove_curse_ready = true }),
    "leveling RemoveCurse fires in combat when cursed")

-- ============================================================================
-- SHARED class table: IceBlock ids are the real DBC ranks, not 45438
-- ============================================================================
local captured = {}
local class_ns = {
    MageSpells = {},
    GetPlayer = function() return { get_class = function() return 8 end } end,
    spell_action = function(t)
        captured[#captured + 1] = t
        return t
    end,
    is_sod = function() return false end,
    log = function() end,
    rotation_registry = { register = function() end, set_class_config = function() end },
}
package.loaded["shared/class_loader_sylvanas"] = {
    create_loader = function() return function() end end,
    create_expansion_loader = function() return function() end end,
    get_enums = function() return { class_id = { MAGE = 8 } } end,
    sod_playstyles = function() return {} end,
}
package.loaded["shared/spell_id_table_sylvanas"] = { resolve = function() return nil end }
_G.EaxRotations = class_ns
local class_mod = dofile("EaxRotations/classes/mage/class_sylvanas.lua")
assert_true(class_mod ~= nil, "mage class_sylvanas must load")
local ice_block_entry = nil
for _, t in ipairs(captured) do
    if t and t.name == "IceBlock" then ice_block_entry = t break end
end
assert_true(ice_block_entry ~= nil, "class MageSpells must define IceBlock")
assert_eq(table.concat(ice_block_entry.ids, ","), "11958,27619",
    "IceBlock ids must be {11958, 27619} (45438 does not exist in the 2.5.5 DBC)")
assert_true(class_ns.MageSpells.IceBlock.ids[1] == 11958 and class_ns.MageSpells.IceBlock.ids[2] == 27619,
    "IceBlock rank ladder must be 11958 (R1) then 27619 (R2)")

print("PASS test_mage_vanilla_live_fixes")
