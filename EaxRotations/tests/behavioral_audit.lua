-- behavioral_audit.lua -- Behavioral battery harness for all 29 sylvanas spec files.
-- WHAT:  Loads every classes/<class>/<spec>_sylvanas.lua with a permissive mocked NS,
--        then runs each spec's strategy table across a battery of realistic combat
--        contexts exactly like the dispatcher (build state once, first match wins)
--        and reports which strategies fire and which NEVER fire across the battery.
-- WHEN:  Run standalone (report-only, exit 0) or via tests/test_behavioral_audit_battery.lua.
-- WHY:   Structural audits already pass (spell IDs exist, load compliance, safe_state
--        nil-guards). This harness hunts the SILENT-GATE defect class -- a strategy
--        that can never return true in any realistic state (e.g. the cat Rip TTD bug:
--        combo points banked forever because the only finisher was unreachable).
-- SAFETY: Pure read-only analysis with a mocked API. Spec loading is pcall-guarded;
--        no files are edited, no io side effects.
--
-- NOTE: This harness runs in a LENIENT mock. A strategy that never fires is a
-- TRIAGE CANDIDATE, not proof of a bug: it may be legitimately situational (stealth
-- only, PvP only, out-of-combat only, opt-in setting off). Each candidate must be
-- reviewed against its match() function before any fix. See plans/behavioral-audit-all-29-specs-2026-08-06.md.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local M = {}

-- ---------------------------------------------------------------------------
-- Spec manifest: every sylvanas spec file under classes/.
-- ---------------------------------------------------------------------------
M.SPEC_FILES = {
    druid = { "balance", "bear", "cat", "caster", "resto" },
    hunter = { "beast_mastery", "marksmanship", "survival" },
    mage = { "arcane", "fire", "frost" },
    paladin = { "holy", "protection", "retribution" },
    priest = { "discipline", "holy", "shadow", "smite" },
    rogue = { "assassination", "combat", "subtlety" },
    shaman = { "elemental", "enhancement", "restoration" },
    warlock = { "affliction", "demonology", "destruction" },
    warrior = { "arms", "fury", "protection", "kebab" },
}

-- Class profiles used to build representative contexts.
M.CLASS_PROFILE = {
    druid   = { resource = "energy", mana = true, form = true, melee = true, class_id = 11 },
    hunter  = { resource = "focus", mana = true, pet = true, ranged = true, class_id = 3 },
    mage    = { resource = "mana", mana = true, ranged = true, class_id = 8 },
    paladin = { resource = "mana", mana = true, melee = true, class_id = 2 },
    priest  = { resource = "mana", mana = true, ranged = true, healer = true, class_id = 5 },
    rogue   = { resource = "energy", melee = true, class_id = 4 },
    shaman  = { resource = "mana", mana = true, melee = true, healer = true, totem = true, class_id = 7 },
    warlock = { resource = "mana", mana = true, ranged = true, pet = true, class_id = 9 },
    warrior = { resource = "rage", melee = true, class_id = 1 },
}

M.CLASS_IDS = {
    warrior = 1, paladin = 2, hunter = 3, rogue = 4,
    priest = 5, shaman = 7, mage = 8, warlock = 9, druid = 11,
    -- Uppercase aliases mirror api/common/enums class_id so specs that gate on
    -- enums.class_id.PRIEST etc. pass when the real enums module is unable to
    -- load under the harness package.path (api/ absent, .api/ not on path).
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4,
    PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

-- Power type constants (mirror ns.POWER_* set per spec in build_ns).
M.POWER = { MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, COMBO = 4 }

-- ---------------------------------------------------------------------------
-- Helper: one shared permissive unit mock.
-- ---------------------------------------------------------------------------
local function _me_unit(class_id)
    return {
        get_power = function(self, p) return 100 end,
        get_max_power = function(self, p) return 100 end,
        get_health_percentage = function(self) return 100 end,
        get_health = function(self) return 10000 end,
        get_mana_percentage = function(self) return 100 end,
        energy_predicted = function(self) return 100 end,
        energy_time_to_x = function(self, v) return 0.5 end,
        is_in_combat = function(self) return true end,
        get_distance = function(self, t) return 5 end,
        get_shapeshift_form_id = function(self) return 0 end,
        get_attack_power = function(self) return 500 end,
        get_player_stance = function(self) return 0 end,
        get_race_id = function(self) return 1 end,
        get_position = function(self) return { x = 0, y = 0, z = 0 } end,
        is_behind = function(self) return true end,
        get_armor = function(self) return 1000 end,
        is_moving = function(self) return false end,
        get_class = function(self) return class_id or 0 end,
        get_name = function(self) return "AuditPlayer" end,
        is_in_party = function(self) return true end,
        is_in_raid = function(self) return false end,
        get_friends_in_range = function(self) return {} end,
    }
end

local function _target()
    return {
        is_valid = function(self) return true end,
        is_dead = function(self) return false end,
        is_player = function(self) return false end,
        get_health_percentage = function(self) return 100 end,
        get_health = function(self) return 10000 end,
        get_distance = function(self) return 5 end,
        get_creature_type = function(self) return 7 end,
        get_classification = function(self) return 0 end,
        is_behind = function(self, u) return true end,
        is_casting = function(self) return false end,
        is_channeling = function(self) return false end,
        is_interruptible = function(self) return true end,
        get_armor = function(self) return 1000 end,
        get_max_health = function(self) return 10000 end,
        get_max_power = function(self) return 0 end,
        get_power = function(self) return 0 end,
        get_name = function(self) return "AuditTarget" end,
        get_attack_power = function(self) return 0 end,
        get_target = function(self) return nil end,
    }
end

local function _friend(hp, dist)
    hp = type(hp) == "number" and hp or 100
    return {
        is_valid = function(self) return true end,
        is_dead = function(self) return hp <= 0 end,
        is_player = function(self) return true end,
        get_health_percentage = function(self) return hp end,
        get_health = function(self) return hp * 100 end,
        get_distance = function(self) return dist or 30 end,
        get_creature_type = function(self) return 7 end,
        get_power = function(self) return 0 end,
        get_max_power = function(self) return 0 end,
        get_name = function(self) return "AuditFriend" end,
        hp = hp,
    }
end

-- ---------------------------------------------------------------------------
-- Rich, permissive NS mock. Battery scenarios can override individual closures
-- (e.g. NS.buff_up returning true) by mutating the returned table.
-- ---------------------------------------------------------------------------
function M.build_ns(class_key)
    local ns = {}
    local profile = M.CLASS_PROFILE[class_key] or {}
    local class_id = profile.class_id or 0
    ns.PLAYER_UNIT = {}
    ns.POWER_MANA = 0
    ns.POWER_RAGE = 1
    ns.POWER_ENERGY = 3
    ns.POWER_COMBO = 4
    ns.POWER_FOCUS = 2

    ns.WarriorSpells = {}
    ns.PaladinSpells = {}
    ns.HunterSpells = {}
    ns.MageSpells = {}
    ns.WarlockSpells = {}
    ns.PriestSpells = {}
    ns.ShamanSpells = {}
    ns.RogueSpells = {}
    ns.DruidSpells = {}
    ns.CLASS_ID = M.CLASS_IDS
    ns.class_id = M.CLASS_IDS
    ns.WarriorConstants = { STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 } }
    ns.STANCE = ns.WarriorConstants.STANCE

    ns.log = function() end
    ns.debug = false
    ns.player_class_id = 0

    ns.time_now = function() return 100.0 end
    ns.game_time_ms = function() return 100000 end
    ns.now_ms = function() return 100000 end
    ns.core = {
        spell_book = { get_totem_info = function() return nil end },
        object_manager = { get_visible_objects = function() return {} end },
    }

    -- Warrior spec files call NS.import_helpers("try_cast", ...) at load; the
    -- real implementation is populated by warrior/shared_helpers_sylvanas.lua
    -- on class registration. Return a permissive stub per requested name.
    ns.import_helpers = function(...)
        local names = { ... }
        local typed_map = {
            debuff_remains = 0, debuff_stacks = 0, buff_remains = 0,
            health_pct = 100, buff_stacks = 0,
        }
        local floaty = {
            player_control_locked = false, has_breakable_cc_nearby = false,
            has_player_buff = false, can_attack_target = true,
            try_cast = true, spell_exists = true, spell_ready = true,
        }
        local results = {}
        for i = 1, #names do
            local n = names[i]
            if typed_map[n] ~= nil then
                results[i] = function() return typed_map[n] end
            elseif floaty[n] ~= nil then
                results[i] = function() return floaty[n] end
            else
                results[i] = function() return true end
            end
        end
        return unpack(results)
    end

    ns.spell_exists = function() return true end
    ns.spell_ready = function(spell, target, opts)
        return ns.cooldown_remains(spell) <= 0
    end
    ns.is_spell_learned = function() return true end
    ns.spell_cooldown_ready = function() return true end
    -- Scenario-driven cooldowns: scenarios set on_cd = { [spell_id] = seconds }.
    -- Accepts both numeric spell IDs and NS spell_action tables (kebab style).
    ns.cooldown_remains = function(spell)
        local on_cd = ns._bstate("on_cd", nil)
        if type(on_cd) == "table" and spell then
            local id = type(spell) == "number" and spell or (type(spell) == "table" and spell.ids and spell.ids[1])
            if id and on_cd[id] then return on_cd[id] end
        end
        return 0
    end

    ns.buff_up = function() return false end
    ns.buff_remains = function() return 0 end
    ns.buff_points = function() return nil end
    ns.debuff_up = function() return false end
    ns.debuff_remains = function() return 0 end
    ns.debuff_points = function() return nil end
    ns.get_buff_stacks = function() return 0 end
    ns.get_debuff_stacks = function() return 0 end
    ns.aura_remains = function() return 0 end
    ns.has_form = function() return true end
    ns.get_player_stance = function() return 0 end
    ns.is_behind_target = function() return true end
    ns.get_combo_points = function() return 0 end
    ns.combo_points = function() return 0 end

    ns.power_current = function() return 100 end
    ns.energy = function() return 100 end
    ns.focus = function() return 100 end
    ns.get_power = function() return 100 end
    ns.get_max_power = function() return 100 end
    ns.power_pct = function() return 100 end
    ns.mana_pct = function() return 100 end
    ns.health_pct = function() return 100 end
    ns.mana = function() return 100 end

    ns.GetPlayer = function() return _me_unit(class_id) end

    ns.try_cast = function() return true end
    ns.use_item_by_id = function() return true end
    ns.is_item_ready = function() return true end
    ns.get_item_count = function() return 1 end
    ns.use_item = function() return true end

    ns.get_setting = function() return nil end
    ns.get_any_setting = function() return nil end

    local _ok_kit, _spec_kit = pcall(require, "shared/spec_kit_sylvanas")
    local function _setting_bool(ctx, key, def)
        if _ok_kit and _spec_kit and _spec_kit.setting_bool then
            return _spec_kit.setting_bool(ctx, key, def)
        end
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] ~= false end
        return def ~= false
    end
    local function _setting_number(ctx, key, def)
        if _ok_kit and _spec_kit and _spec_kit.setting_number then
            return _spec_kit.setting_number(ctx, key, def)
        end
        if ctx and ctx.settings and type(ctx.settings[key]) == "number" then return ctx.settings[key] end
        return def
    end

    -- NS helper surface: permissive stubs so every spec's match/execute can run.
    ns.action_matches = function() return true end
    ns.action_execute = function() return true end
    ns.aoe_target_meets = function() return true end
    ns.aoe_cone_meets = function() return true end
    ns.aoe_count_meets = function() return true end
    ns.aoe_self_meets = function() return true end
    ns.cancel_buff = function() return true end
    ns.cancel_current_cast = function() return true end
    ns.cancel_spells = function() return true end
    ns.can_cast_in_form = function() return true end
    ns.start_attack = function() return true end
    ns.start_auto_attack = function() return true end
    ns.stop_casting = function() return true end
    ns.is_auto_attacking = function() return true end
    ns.is_current_spell = function() return false end
    ns.is_execute_phase = function(hp, threshold) return type(hp) == "number" and hp <= (threshold or 20) end
    ns.is_valid_target = function() return true end
    ns.is_melee_target = function() return true end
    ns.is_tank_unit = function() return true end
    ns.is_pvp_zone = function() return false end
    ns.is_wotlk = false
    ns.is_sod = false
    ns.should_kite = function() return false end
    ns.has_player_buff = function() return false end
    ns.has_player_debuff = function() return false end
    ns.has_buff = function() return false end
    ns.has_debuff = function() return false end
    ns.buff_stacks = function() return 0 end
    ns.debuff_stacks = function() return 0 end
    ns.get_aoe_cast_position = function() return nil end
    ns.cast_ground_aoe = function() return true end
    ns.try_cast_position = function() return true end
    ns.try_interrupt = function() return true end
    ns.is_interruptible = ns.is_interruptible
    ns.unit_alive = function() return true end
    ns.unit_health_pct = function() return 100 end
    ns.unit_mana_pct = function() return 100 end
    ns.unit_max_mana = function() return 10000 end
    ns.unit_distance = function() return 5 end
    ns.unit_faction = function() return 0 end
    ns.unit_is_boss = function() return false end
    ns.unit_interruptible = function() return true end
    ns.unit_creature_type = function() return 7 end
    ns.threat_status = function() return 0 end
    ns.is_threat_safe = function() return true end
    ns.get_party_members = function() return {} end
    ns.party_members = function() return {} end
    ns.get_pet = function() return nil end
    ns.GetPet = function() return nil end
    ns.get_pet_hp = function() return 100 end
    ns.has_pet = function() return false end
    ns.mana = ns.mana
    ns.get_spell_cd = function() return 0 end
    ns.get_spell_cooldown = function() return 0 end
    ns.get_spell_id = function() return 0 end
    ns.is_spell_in_range = function() return true end
    ns.get_time_until_swing = function() return 0.5 end
    ns.get_time_until_oh_swing = function() return 0.5 end
    ns.swing_progress = function() return 0.5 end
    ns.swing_time_until = function() return 0.5 end
    ns.get_totem_info = function() return false end
    ns.register_on_spell_cast = function() return true end
    ns.register_class_middleware = function() end
    ns.get_friendly_target_entry = function() end
    ns.find_dead_party_ally = function() return nil end
    ns.reset_api_health = function() end
    ns.get_local_player = ns.GetPlayer
    ns.dump_class_spells = function() end
    ns.pvp_trinket_used_recently = function() return false end
    ns.gate_overheal = function() return false end
    ns.gate_cooldown_boss_only = function() return true end
    ns.should_use_long_cd = function() return true end
    ns.should_refresh_dot = function() return not ns._bstate("buffs_up", false) end
    ns.has_dispel_type_debuff = function() return ns._bstate("friends_afflicted", false) end
    ns.is_breakable_cc_active = function() return false end
    ns.has_healing_reduction_debuff = function() return false end
    ns.get_best_heal_target = function() return nil end
    ns.healing_count_below_hp = function() return 0 end
    ns.healing_get_lowest_hp = function() return nil end
    ns.healing_get_tank = function() return nil end
    ns.get_local_player = ns.GetPlayer
    ns.get_energy = ns.energy
    ns.safe_field = function(v, d) if v == nil then return d end return v end
    ns.same_unit = ns.same_unit
    ns.not_same_unit = ns.not_same_unit
    ns.setting_bool = function(ctx, key, def) return _setting_bool(ctx, key, def) end
    ns.setting_number = function(ctx, key, def) return _setting_number(ctx, key, def) end
    ns.register_strategy = function() end
    ns.run_unified_strategies = function() return false end

    -- Subsystem namespaces specs access (populated by class registration in
    -- the live engine; permissive stubs keep the audit loadable).
    ns.ConsumableManager = { should_use = function() return false end, try_use = function() return false end }
    ns.DispelManager = { try_dispel = function() return ns._bstate("friends_afflicted", false) end, should_dispel = function() return ns._bstate("friends_afflicted", false) end }
    ns.Triage = { score = function() return 0 end, rank = function() return {} end }
    ns.HealerDeficit = { deficit_of = function() return 0 end }
    ns.TrinketManager = { try_use = function() return false end }
    ns.RageManager = { should_dump = function() return true end }
    ns.StanceManager = { ensure_stance = function() return true end }
    ns.SnapThreat = { try = function() return false end }
    ns.PvPBurstWindow = { should_burst = function() return false end }
    ns.StopCast = { stop_if_needed = function() return false end }
    ns.HotTickTracker = { on_tick = function() end }
    ns.InterruptManager = {
        try_interrupt = function() return true end,
        cast_has_interrupt_window = function() return true end,
        humanize_interrupt_elapsed = function() return true end,
    }
    ns.DRTracker = { is_dr = function() return false end }
    ns.Targeting = { pick = function() return nil end }
    ns.WeaponImbueManager = { apply = function() return false end }
    ns.OffensiveDispelDB = {
        should_purge = function() return ns._bstate("enemy_buffed", false) end,
        find_best_dispel_target = function(target)
            if ns._bstate("enemy_buffed", false) then return target, 10 end
            return nil
        end,
        is_breakable_cc_active = function() return false, nil end,
        is_casting_preemptive_cc = function() return false, nil end,
    }
    ns.SwingDiagnostics = {
        on_update = function() end,
        register_seals = function() end,
        is_active = function() return false end,
        get_swing_remains = function() return nil end,
        mark_twist_attempt = function() end,
        is_overpower_proc_active = function() return false end,
    }
    ns.HunterCore = { on_update = function() end }
    ns.HunterAdaptive = { on_update = function() end }
    ns.HunterClipTracker = { on_update = function() end }
    ns.PaladinHealing = {
        should_cast = function() return false end,
        scan_healing_targets = function() return {}, 0 end,
    }
        ns.PriestHealing = {
        should_cast = function() return false end,
        scan_healing_targets = function() return {}, 0 end,
        healing_count_below_hp = function() return 0 end,
        healing_get_lowest_hp = function() return nil end,
        healing_get_tank = function() return nil end,
        count_subgroup_below_hp = function() return 0 end,
    }
    ns.ShamanHealing = {
        should_cast = function() return false end,
        scan_healing_targets = function() return {}, 0 end,
        select_heal = function() return nil end,
    }
    ns.DruidHealing = {
        should_cast = function() return false end,
        scan_healing_targets = function() return {}, 0 end,
    }
    ns.class_middleware = {}
    ns.unified_registry = {}
    ns.unified_state_builders = {}
    ns.playstyles = { leveling = {} }

    ns.same_unit = function(a, b) return a == b end
    ns.not_same_unit = function(a, b) return a ~= b end
    ns.spell_action = function(rank_ids, label)
        local ids
        if type(rank_ids) == "table" then ids = rank_ids else ids = { rank_ids } end
        local obj = {
            label = label,
            ids = ids,
            id = function(self) return ids[1] or ids[#ids] end,
            rank = function(self, r) return ids[r or #ids] end,
            cooldown = function(self) return 0 end,
            is_known = function(self) return true end,
        }
        obj.rank_ids = function() return ids end
        return obj
    end
    ns.get_equipped_item_id = function() return 0 end
    ns.EQUIPMENT_SLOTS = { HEAD = 1 }
    ns.broken_api_throttled = function() return false end
    ns.is_interruptible = function() return true end
    ns.target_casting = function() return ns._bstate("target_is_casting", false) end
    ns.is_in_melee_range = function() return true end
    ns.cp_debug = function() end
    ns.time_until_swing = function() return 0.5 end
    ns.has_health_potion = false
    ns.gcd_remains = function() return 0 end
    ns.get_gcd = function() return 1.5 end
    ns.in_combat = true

    -- ------------------------------------------------------------------
    -- Scenario state bank: apply_battery_state() rewrites this per scenario
    -- so every numeric NS read reflects the CURRENT context, not a fixed
    -- value. Defaults keep the legacy behavior (buffs down, full bars).
    -- ------------------------------------------------------------------
    ns._battery = {
        power = { [M.POWER.MANA] = 100, [M.POWER.RAGE] = 70, [M.POWER.FOCUS] = 90, [M.POWER.ENERGY] = 90, [M.POWER.COMBO] = 5 },
        stance = 0,
        form = 0,
        buffs_up = false,
        faction = 0,
        hp = 100,
        mana_pct = 100,
    }
    ns._bstate = function(key, def)
        local v = ns._battery[key]
        if v == nil then return def end
        return v
    end
    ns._bpower = function(id, def)
        local v = ns._battery.power[id]
        if v == nil then return def end
        return v
    end
    -- Buffs/debuffs: buffs_up scenarios report auras present, otherwise down.
    ns.buff_up = function() return ns._bstate("buffs_up", false) end
    ns.buff_remains = function() if ns._bstate("buffs_up", false) then return 20 end return 0 end
    ns.aura_remains = function() if ns._bstate("buffs_up", false) then return 20 end return 0 end
    ns.debuff_up = function() if ns._bstate("buffs_up", false) then return true end return false end
    ns.debuff_remains = function() if ns._bstate("buffs_up", false) then return 20 end return 0 end
    ns.has_player_buff = function() return ns._bstate("buffs_up", false) end
    ns.get_buff_stacks = function() if ns._bstate("buffs_up", false) then return 1 end return 0 end
    -- Numeric reads delegate to the scenario state bank.
    ns.power_current = function(p) return ns._bpower(p or M.POWER.MANA, 100) end
    ns.get_power = function(p) return ns._bpower(p or M.POWER.MANA, 100) end
    ns.power_pct = function(p) return math.min(100, ns._bpower(p or M.POWER.MANA, 100)) end
    ns.power_mana = function() return ns._bpower(M.POWER.MANA, 100) end
    ns.energy = function() return ns._bpower(M.POWER.ENERGY, 100) end
    ns.focus = function() return ns._bpower(M.POWER.FOCUS, 90) end
    ns.rage = function() return ns._bpower(M.POWER.RAGE, 70) end
    ns.mana = function() return ns._bpower(M.POWER.MANA, 100) end
    ns.get_combo_points = function() return ns._bpower(M.POWER.COMBO, 5) end
    ns.combo_points = function() return ns._bpower(M.POWER.COMBO, 5) end
    ns.mana_pct = function() return ns._bstate("mana_pct", 100) end
    ns.health_pct = function(u)
        if u and u.get_health_percentage then
            local ok, v = pcall(u.get_health_percentage, u)
            if ok and type(v) == "number" then return v end
        end
        return ns._bstate("hp", 100)
    end
    ns.unit_health_pct = ns.health_pct
    ns.unit_mana_pct = function() return ns._bstate("mana_pct", 100) end
    ns.get_player_stance = function() return ns._bstate("stance", 0) end
    ns.unit_faction = function() return ns._bstate("faction", 0) end
    return ns
end

-- ---------------------------------------------------------------------------
-- Context builder
-- ---------------------------------------------------------------------------
local function _base_ctx(profile)
    local ctx = {
        me = _me_unit(),
        target = _target(),
        has_valid_enemy_target = true,
        has_target = true,
        in_combat = true,
        combat_state_known = true,
        target_ttd = 60,
        ttd = 60,
        target_hp = 100,
        hp = 100,
        player_hp = 100,
        mana_pct = 100,
        player_mana = 100,
        player_mana_pct = 100,
        enemy_count = 1,
        enemies_count = 1,
        enemies = {},
        target_range = 5,
        target_distance = 5,
        is_pvp = false,
        is_dungeon = false,
        is_raid = false,
        is_group = false,
        is_solo = true,
        is_leveling = false,
        level = 70,
        player_level = 70,
        stance = 0,
        rage = 100,
        energy = 100,
        focus = 100,
        combo_points = 5,
        attack_power = 300,
        target_armor = 1000,
        combat_time = 30,
        gcd_remains = 0,
        on_gcd = false,
        is_moving = false,
        me_casting = false,
        in_melee_range = true,
        ttd_known = true,
        has_health_potion = false,
        has_mana_potion = false,
        friends_afflicted = false,
        enemy_buffed = false,
        settings = {},
        lowest = { unit = nil, hp = 100 },
    }
    if profile ~= nil then
        if profile.ranged then
            ctx.target_range = 30
            ctx.target_distance = 30
        end
        if profile.melee then
            ctx.target_range = 5
            ctx.target_distance = 5
        end
        ctx.mana_pct = 90
        if profile.resource == "rage" then ctx.rage = 70 end
        if profile.resource == "energy" then ctx.energy = 90 end
        if profile.resource == "focus" then ctx.focus = 90 end
    end
    return ctx
end

-- ---------------------------------------------------------------------------
-- Scenario battery (deterministic order). Overrides drive BOTH the context
-- table and (via apply_battery_state) the NS state bank, so each scenario
-- presents realistic resource/stance/aura states to the match functions.
-- ---------------------------------------------------------------------------
M.SCENARIOS = {
    { name = "standard" },
    { name = "combo_build",      overrides = { combo_points = 0, energy = 60, focus = 60 } },
    { name = "energy_low",       overrides = { combo_points = 0, energy = 30 } },
    { name = "aoe",              overrides = { enemy_count = 4, enemies_count = 4 } },
    { name = "execute",          overrides = { target_hp = 8, ttd = 6, target_ttd = 6 } },
    { name = "low_mana",         overrides = { mana_pct = 10, player_mana = 300, player_mana_pct = 10, has_potions = true } },
    { name = "low_self",         overrides = { hp = 15, player_hp = 15, has_potions = true } },
    { name = "moving",           overrides = { is_moving = true } },
    { name = "target_casting",   overrides = { target_is_casting = true } },
    { name = "stealth",          overrides = { is_stealthed = true, combo_points = 0 } },
    { name = "buffs_up",         overrides = { buffs_up = true, combo_points = 0 } },
    { name = "pull",             overrides = { in_combat = false, buffs_up = true, is_stealthed = true, combo_points = 0 } },
    { name = "short_ttd",        overrides = { target_ttd = 2, ttd = 2, target_hp = 20, combo_points = 5, energy = 60 } },
    { name = "mid_ttd",          overrides = { target_ttd = 30, ttd = 30 } },
    { name = "long_ttd",         overrides = { target_ttd = 120, ttd = 120 } },
    { name = "pvp_interrupt",    overrides = { is_pvp = true, target_is_casting = true, combo_points = 3 } },
    { name = "berserker_interrupt", overrides = { stance = 3, target_is_casting = true } },
    { name = "potions_ready",    overrides = { has_potions = true } },
    { name = "friends_afflicted", overrides = { friends_afflicted = true, friends_hp = { 100, 100, 100 } } },
    { name = "enemy_buffed",     overrides = { enemy_buffed = true } },
    { name = "me_casting",       overrides = { me_casting = true, friends_hp = { 25, 60, 80 }, lowest_hp = 25 } },
    { name = "battle_stance",    overrides = { stance = 1 } },
    { name = "defensive_stance", overrides = { stance = 2 } },
    { name = "berserker_stance", overrides = { stance = 3 } },
    { name = "alliance",         overrides = { faction = "Alliance" } },
    { name = "pet_low",          overrides = { pet_hp = 25 } },
    { name = "pet_dead",         overrides = { pet_hp = 0, pet_dead = true } },
    { name = "friends_damaged",  overrides = { friends_hp = { 40, 60, 80 }, lowest_hp = 40 } },
    { name = "out_of_combat",    overrides = { in_combat = false }, no_target = true },
    { name = "ooc_buffs",        overrides = { in_combat = false }, no_target = true },
    { name = "pvp",              overrides = { is_pvp = true } },
    { name = "leveling",         overrides = { level = 25, player_level = 25, is_leveling = true } },
}

-- Scenario-aware player unit: every health/power read reflects the CURRENT
-- scenario numeric values instead of fixed 100s.
local function _scenario_me(profile, ctx)
    local me = _me_unit(profile.class_id or 0)
    me.get_health_percentage = function(self) return ctx.hp or 100 end
    me.get_health = function(self) return (ctx.hp or 100) * 100 end
    me.get_mana_percentage = function(self) return ctx.mana_pct or 100 end
    me.is_in_combat = function(self) return ctx.in_combat == true end
    me.get_shapeshift_form_id = function(self) return ctx.form or 0 end
    me.is_moving = function(self) return ctx.is_moving == true end
    me.get_power = function(self, p)
        if p == M.POWER.COMBO then return ctx.combo_points or 5 end
        if p == M.POWER.ENERGY then return ctx.energy or 100 end
        if p == M.POWER.RAGE then return ctx.rage or 70 end
        if p == M.POWER.FOCUS then return ctx.focus or 90 end
        if p == M.POWER.MANA then return ctx.player_mana or ctx.mana_pct or 100 end
        return 100
    end
    me.is_casting = function(self) return ctx.me_casting == true end
    me.is_channeling = function(self) return ctx.me_casting == true end
    return me
end

-- Scenario-aware target clone: HP reflects target_hp, casting reflects
-- target_is_casting, and get_target() reports the player (engaged target).
local function build_scenario_target(ctx)
    local target = _target()
    target.get_health_percentage = function(self) return ctx.target_hp or 100 end
    target.get_health = function(self) return (ctx.target_hp or 100) * 100 end
    target.is_casting = function(self) return ctx.target_is_casting == true end
    target.is_channeling = function(self) return ctx.target_is_casting == true end
    target.get_target = function(self) return ctx.me end
    return target
end

-- Build the context table for one scenario descriptor + class profile.
function M.build_context_for(class_key, scenario)
    local profile = M.CLASS_PROFILE[class_key] or {}
    local ctx = _base_ctx(profile)
    local overrides = scenario.overrides or {}
    -- apply only known numeric/boolean keys
    local known = {
        enemy_count=true, enemies_count=true, target_hp=true, ttd=true,
        mana_pct=true, player_mana=true, player_mana_pct=true,
        hp=true, player_hp=true, in_combat=true, is_pvp=true,
        level=true, player_level=true, is_leveling=true, target_ttd=true,
        combo_points=true, energy=true, rage=true, focus=true,
        is_moving=true, is_stealthed=true, target_is_casting=true,
        stance=true, buffs_up=true, faction=true, pet_hp=true, pet_dead=true,
        lowest_hp=true, has_potions=true, friends_afflicted=true,
        enemy_buffed=true, me_casting=true,
    }
    for k, v in pairs(overrides) do
        if k == "friends_hp" then
            ctx.friends_hp = v
        elseif k == "has_potions" then
            ctx.has_health_potion = true
            ctx.has_mana_potion = true
        elseif known[k] then
            ctx[k] = v
        end
    end
    -- Warriors start in Battle Stance (1); stance scenarios flip it.
    if class_key == "warrior" and ctx.stance == 0 then ctx.stance = 1 end
    -- Scenario-aware player + target
    ctx.me = _scenario_me(profile, ctx)
    ctx.target = build_scenario_target(ctx)
    if scenario.no_target then
        ctx.target = nil
        ctx.has_target = false
        ctx.has_valid_enemy_target = false
        ctx.target_ttd = nil
        ctx.ttd = nil
        ctx.target_hp = 100
        ctx.range = 0
    end
    -- Pets (hunter + warlock)
    if profile.pet then
        local pet_hp = ctx.pet_hp or 100
        local pet = _target()
        pet.get_health_percentage = function(self) return pet_hp end
        pet.get_health = function(self) return pet_hp * 100 end
        pet.is_dead = function(self) return pet_hp <= 0 end
        pet.get_distance = function(self) return 20 end
        ctx.pet = pet
        ctx.pet_dead = ctx.pet_dead == true or pet_hp <= 0
    end
    local is_healer = class_key == "priest" or class_key == "shaman"
        or class_key == "paladin" or class_key == "druid"
    if is_healer then
        ctx.is_group = true
        if not scenario.no_target then
            local hps = ctx.friends_hp or { 55, 70, 85 }
            ctx.friends = {}
            ctx.party = {}
            for i, hp in ipairs(hps) do
                local f = _friend(hp, 30)
                ctx.friends[i] = f
                ctx.party[i] = f
            end
            local lo = ctx.lowest_hp or (hps[1] or 100)
            ctx.lowest = { unit = ctx.friends[1], hp = lo }
        else
            ctx.friends = {}
            ctx.party = {}
            ctx.lowest = { unit = nil, hp = 100 }
        end
    end
    return ctx
end

-- ---------------------------------------------------------------------------
-- Sync NS state bank + subsystem stubs to the current scenario context so
-- every match/state read reflects this scenario's realistic state.
-- ---------------------------------------------------------------------------
function M.apply_battery_state(ns, ctx, class_key)
    ns._battery = {
        power = {
            [M.POWER.MANA] = ctx.player_mana or ctx.mana_pct or 100,
            [M.POWER.RAGE] = ctx.rage or ((class_key == "warrior") and 70 or 100),
            [M.POWER.FOCUS] = ctx.focus or 90,
            [M.POWER.ENERGY] = ctx.energy or 100,
            [M.POWER.COMBO] = ctx.combo_points or 5,
        },
        stance = ctx.stance or 0,
        form = ctx.form or 0,
        buffs_up = ctx.buffs_up == true,
        faction = ctx.faction or 0,
        hp = ctx.hp or 100,
        mana_pct = ctx.mana_pct or 100,
        on_cd = ctx.on_cd,
    }
    -- Pets (hunter + warlock)
    if ctx.pet ~= nil then
        ns.has_pet = function() return not (ctx.pet_dead == true) end
        ns.get_pet = function() return ctx.pet end
        ns.GetPet = function() return ctx.pet end
        ns.get_pet_hp = function() return ctx.pet_hp or 100 end
        ns.pet_hp_pct = function() return ctx.pet_hp or 100 end
    else
        ns.has_pet = function() return false end
        ns.get_pet = function() return nil end
        ns.GetPet = function() return nil end
        ns.get_pet_hp = function() return 100 end
    end
    ns.has_health_potion = ctx.has_health_potion == true
    -- Healers: bind healing scans to the current friend roster. Scans return
    -- ENTRIES ({ unit, hp, effective_hp }) exactly like the live modules, so
    -- the NS.healing_* rankers below produce a usable lowest/tank entry.
    local friends = ctx.friends or {}
    local function heal_scan()
        local ents = {}
        for i, f in ipairs(friends) do
            local hp = (type(f) == "table" and f.hp) or 100
            ents[i] = {
                unit = f,
                hp = hp,
                effective_hp = hp,
                health_pct = hp,
                has_renew = false,
                has_buff = false,
                has_poison = ctx.friends_afflicted == true,
                has_disease = ctx.friends_afflicted == true,
                has_magic = ctx.friends_afflicted == true,
            }
        end
        return ents, #ents
    end
    local function lowest_entry(ents, _count, threshold)
        local best = nil
        for _, e in ipairs(ents or {}) do
            local hp = (e and e.effective_hp) or (e and e.hp) or 100
            if hp < (threshold or 92) then
                if not best or hp < best.effective_hp then best = e end
            end
        end
        return best
    end
    local function count_below(ents, _count, threshold)
        local n = 0
        for _, e in ipairs(ents or {}) do
            if ((e and e.effective_hp) or (e and e.hp) or 100) < (threshold or 85) then n = n + 1 end
        end
        return n
    end
    if ns.PriestHealing then
        ns.PriestHealing.scan_healing_targets = heal_scan
        ns.PriestHealing.should_cast = function() return true end
        ns.PriestHealing.healing_count_below_hp = count_below
        ns.PriestHealing.healing_get_lowest_hp = function(entries, count, th) return lowest_entry(entries, count, th) end
        ns.PriestHealing.healing_get_tank = function(entries, count) return entries and entries[1] end
        ns.PriestHealing.count_subgroup_below_hp = function(th) return count_below(heal_scan()) end
    end
    if ns.PaladinHealing then
        ns.PaladinHealing.scan_healing_targets = heal_scan
        ns.PaladinHealing.should_cast = function() return true end
    end
    if ns.ShamanHealing then
        ns.ShamanHealing.scan_healing_targets = heal_scan
        ns.ShamanHealing.should_cast = function() return true end
        ns.ShamanHealing.select_heal = function() return lowest_entry(heal_scan()) or { unit = nil, hp = 100 } end
    end
    if ns.DruidHealing then
        ns.DruidHealing.scan_healing_targets = heal_scan
        ns.DruidHealing.should_cast = function() return true end
    end
    if ns.HealerDeficit then
        ns.HealerDeficit.deficit_of = function(u) return math.max(0, 100 - (u and u.hp or 100)) end
    end
    ns.get_party_members = function() return friends end
    ns.party_members = function() return friends end
    ns.healing_count_below_hp = count_below
    ns.healing_get_lowest_hp = function(e, c, th) return lowest_entry(e, c, th) end
    ns.healing_get_tank = function(e, c) return e and e[1] end
end

-- ---------------------------------------------------------------------------
-- Spec loader
-- ---------------------------------------------------------------------------
function M.load_spec(class_key, spec_key)
    local path = "EaxRotations/classes/" .. class_key .. "/" .. spec_key .. "_sylvanas.lua"
    local f = io.open(path, "rb")
    if not f then return nil, "missing file " .. path end
    f:close()

    local ns = M.build_ns(class_key)
    _G.EaxRotations = ns
    local had_core = _G.core
    _G.core = {
        spell_book = {
            get_totem_info = function() return nil end,
        },
    }
    local ok, result = pcall(dofile, path)
    _G.core = had_core
    if not ok then
        return nil, tostring(result)
    end
    return result, nil, ns
end

-- ---------------------------------------------------------------------------
-- Spec runner
-- ---------------------------------------------------------------------------
function M.run_spec(class_key, spec_key, scenarios)
    scenarios = scenarios or M.SCENARIOS
    local result, load_err, ns = M.load_spec(class_key, spec_key)
    if not result then
        return nil, load_err
    end
    local strategies = (type(result) == "table") and (result.strategies or result) or nil
    if type(strategies) ~= "table" then
        return nil, "no strategies table returned for " .. class_key .. "/" .. spec_key
    end
    local build_state = (type(result) == "table") and result.build_state or nil

    local fired = {}
    local fired_in = {}
    local dispatch_errors = {}
    for _, s in ipairs(strategies) do
        if type(s) == "table" and type(s.name) == "string" then
            fired[s.name] = 0
            fired_in[s.name] = {}
        end
    end

    for _, sc in ipairs(scenarios) do
        local ctx = M.build_context_for(class_key, sc)
        M.apply_battery_state(ns, ctx, class_key)
        local state = ctx
        if build_state then
            local ok, st = pcall(build_state, ctx)
            if ok and type(st) == "table" then state = st end
        end
        -- Dispatcher semantics: first match that returns true wins (stop).
        -- We record only the FIRST fired strategy per scenario (mirrors engine),
        -- but ALSO count how many strategies match so coverage is meaningful.
        for _, s in ipairs(strategies) do
            if type(s) == "table" and type(s.name) == "string" and type(s.matches) == "function" then
                local ok, m = pcall(s.matches, ctx, state)
                if not ok then
                    dispatch_errors[#dispatch_errors + 1] =
                        (s.name or "?") .. "@" .. sc.name .. ": " .. tostring(m)
                elseif m == true then
                    fired[s.name] = fired[s.name] + 1
                    fired_in[s.name][sc.name] = true
                end
            end
        end
    end

    local never = {}
    for name, count in pairs(fired) do
        if count == 0 then never[#never + 1] = name end
    end
    table.sort(never)
    return {
        fires_in = fired_in,
        fires = fired,
        never = never,
        dispatch_errors = dispatch_errors,
        strategy_count = #strategies,
    }, nil
end

-- ---------------------------------------------------------------------------
-- Run everything, return aggregate report
-- ---------------------------------------------------------------------------
function M.run_all()
    local total = 0
    local reports = {}
    local load_failures = {}
    for class_key, specs in pairs(M.SPEC_FILES) do
        for _, spec_key in ipairs(specs) do
            total = total + 1
            local report, err = M.run_spec(class_key, spec_key, M.SCENARIOS)
            if not report then
                load_failures[#load_failures + 1] = class_key .. "/" .. spec_key .. ": " .. tostring(err)
            else
                reports[#reports + 1] = {
                    class = class_key,
                    spec = spec_key,
                    never = report.never,
                    strategy_count = report.strategy_count,
                    dispatch_errors = report.dispatch_errors,
                }
            end
        end
    end
    table.sort(reports, function(a, b)
        if a.class == b.class then return a.spec < b.spec end
        return a.class < b.class
    end)
    return { total = total, reports = reports, class_failures = load_failures }
end

-- ---------------------------------------------------------------------------
-- Printer
-- ---------------------------------------------------------------------------
function M.print_report(agg)
    print("=============================================================================")
    print("  BEHAVIORAL BATTERY AUDIT (all " .. tostring(agg.total) .. " sylvanas specs)")
    print("=============================================================================")
    for _, f in ipairs(agg.class_failures) do
        print("  [ LOAD FAIL ] " .. f)
    end
    for _, r in ipairs(agg.reports) do
        local header = string.format("  [ %-9s %-22s ] strategies=%d never-fires=%d",
            r.class, r.spec, r.strategy_count, #r.never)
        print(header)
        if #r.dispatch_errors > 0 then
            for _, e in ipairs(r.dispatch_errors) do
                print("      dispatch ERR: " .. e)
            end
        end
        for _, name in ipairs(r.never or {}) do
            print("      NEVER: " .. name)
        end
    end
    print("")
    print("  Total: " .. tostring(agg.total) .. " | Load failures: " .. tostring(#(agg.class_failures or {})))
    print("  NOTE: every 'never' strategy is a TRIAGE candidate (must be reviewed)")
    print("=============================================================================")
end

-- Standalone entry: `lua EaxRotations/tests/behavioral_audit.lua`
if select("#", ...) == 0 then
    local agg = M.run_all()
    M.print_report(agg)
end

return M