-- behavioral_audit.lua -- Behavioral battery harness for sylvanas (TBC) AND wotlk spec files.
-- WHAT:  Loads every classes/<class>/<spec>_<era>.lua (era = "sylvanas" TBC default,
--        "wotlk" incl. Death Knight blood/frost/unholy) with a permissive mocked NS,
--        then runs each spec's strategy table across a battery of realistic combat
--        contexts exactly like the dispatcher (build state once, first match wins)
--        and reports which strategies fire and which NEVER fire across the battery.
-- WHEN:  Run standalone (`lua behavioral_audit.lua [wotlk]`, report-only, exit 0) or
--        via run_verify_all.lua (which parses this harness's never-firing totals
--        and pins the live contract: TBC never=13, WotLK 0).
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
-- reviewed against its match() function before any fix.
--
-- KNOWN LENIENCY (UPDATED 2026-08-09): spell_exists()/is_spell_learned() are
-- map-aware via the not_learned bank (a scenario can mark an id unlearned, so
-- fallbacks like cat ClawFallback before Mangle ARE observable — see
-- cat_claw_fallback). Residual leniency: snapshot-upgrade strategies (Rip/Rake
-- Snapshot) read the module-local snapshot_state populated only by a prior
-- in-combat cast the battery cannot reproduce, and enh FireNovaReplacement
-- reads module-local totem_state.fire_nova_active set by the totem-drop
-- lifecycle — all three are genuinely unpinnable (classified (c) in
-- tools/spec_scorecard.lua LANE_CLASS with rationale). Treat those NEVER
-- entries as mock limitations, not bugs.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

-- Lua 5.4 compat: global unpack was moved to table.unpack (safe on 5.1/5.2 too)
local unpack = table.unpack or unpack

local M = {}

-- Scenario clock: advanced by apply_battery_state so 1s module caches refresh.
local _battery_now = 100.0

-- ---------------------------------------------------------------------------
-- Spec manifests per era. `sylvanas` = TBC-era spec files (battery default,
-- every never-lane pin + scorecard totals are keyed to this set); `wotlk` =
-- the 41 WotLK files including Death Knight blood/frost/unholy + leveling.
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

-- (b) close-out (2026-08-10): per-spec require-time race override. smite binds
-- _player_race from load_player:get_race_id() at module load (smite:30-32);
-- the mock defaults to race 1 (human) so both racial lanes were structurally
-- dead. Loading smite as night elf (4) makes Starshards observable.
-- Threat-family close-out (2026-08-10): smite ALSO carries DevouringPlague
-- gated on race 5 (undead, smite:32) — one spec, two exclusive races.
-- RACE_VARIANTS loads the spec again per extra race and run_all merges the
-- never lists (a lane stays never only if it never fires under ANY variant
-- race), so both Starshards and DevouringPlague are observable.
M.RACE_OVERRIDES = { smite = 4 }
M.RACE_VARIANTS = { smite = { 5 } }

-- Race-gated vanilla lanes (2026-08-11): the vanilla battery loaded smite as
-- race 1 (human) because RACE_OVERRIDES/RACE_VARIANTS were era-gated to
-- sylvanas, leaving Starshards + DevouringPlague structurally dead. Vanilla
-- smite gates on the SAME race ids as TBC (smite_vanilla:28-29: night elf 4
-- for Starshards, undead 5 for DevouringPlague) — verified era-correct:
-- Classic Forsaken priests learn Devouring Plague at level 20 (Blizzard
-- Watch priest-racials guide), Night Elves learn Starshards at 10; TBC-era
-- sources (2.4.3 notes listing Shadowguard as the Troll racial, Apr-2008
-- GameFAQs calling Devouring Plague the Undead priest racial) confirm the
-- races did NOT swap between eras — the 2.0.1 'shuffle' is a myth; the real
-- change was Cataclysm, when DP became baseline for all priests. So the
-- vanilla lanes are a HARNESS gap, not a rotation defect: mirror the TBC
-- mechanism for the vanilla era. (warlock RacialArcaneTorrent is NOT here —
-- blood elves are TBC-only, so that lane is impossible-by-design and stays
-- pinned with evidence at affliction_vanilla.lua:83.)
M.RACE_OVERRIDES_VANILLA = { smite = 4 }
M.RACE_VARIANTS_VANILLA = { smite = { 5 } }

-- Per-era race override/variant lookup. RACE_VARIANTS loads a spec again per
-- extra race so exclusive-race lanes are observable under every race that can
-- gate them; run_all merges the never lists (a lane stays never only if it
-- never fires under ANY variant race). Era-scoped so a WotLK-era smite load
-- can't silently pick up a TBC or vanilla binding. Exposed on M so
-- test_race_override_regression.lua can pin the era-scoping.
function M.race_maps_for(era)
    if era == "vanilla" then return M.RACE_OVERRIDES_VANILLA, M.RACE_VARIANTS_VANILLA end
    if era == "sylvanas" then return M.RACE_OVERRIDES, M.RACE_VARIANTS end
    return nil, nil
end

M.SPEC_FILES_WOTLK = {
    deathknight = { "blood", "frost", "leveling", "unholy" },
    druid = { "balance", "bear", "cat", "leveling", "resto" },
    hunter = { "beast_mastery", "leveling", "marksmanship", "survival" },
    mage = { "arcane", "fire", "frost", "leveling" },
    paladin = { "holy", "leveling", "protection", "retribution" },
    priest = { "discipline", "holy", "leveling", "shadow" },
    rogue = { "assassination", "combat", "leveling", "subtlety" },
    shaman = { "elemental", "enhancement", "leveling", "restoration" },
    warlock = { "affliction", "demonology", "destruction", "leveling" },
    warrior = { "arms", "fury", "leveling", "protection" },
}

-- Vanilla era (Classic 1.15.x): the 30 non-leveling spec files mirror the TBC
-- manifest shape. Vanilla files are plain-style — they return their strategies
-- table directly and register get_state via NS.rotation_registry (fury_vanilla
-- is the canonical example) — which the harness supports via the registry mock
-- in build_ns + the run_spec build_state fallback. leveling_vanilla files run
-- via run_leveling_tests.lua (same exclusion as TBC).
M.SPEC_FILES_VANILLA = {
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

M.ERA_MANIFESTS = { sylvanas = M.SPEC_FILES, wotlk = M.SPEC_FILES_WOTLK, vanilla = M.SPEC_FILES_VANILLA }

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
    -- WotLK Death Knight (Phase 1): rune/resource profile; presence replaces
    -- stance, handled via the PresenceManager stub in build_ns.
    deathknight = { resource = "runic_power", mana = true, melee = true, class_id = 6 },
}

M.CLASS_IDS = {
    warrior = 1, paladin = 2, hunter = 3, rogue = 4,
    priest = 5, deathknight = 6, shaman = 7, mage = 8, warlock = 9, druid = 11,
    -- Uppercase aliases mirror api/common/enums class_id so specs that gate on
    -- enums.class_id.PRIEST etc. pass when the real enums module is unable to
    -- load under the harness package.path (api/ absent, .api/ not on path).
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4,
    PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

-- Power type constants (mirror ns.POWER_* set per spec in build_ns).
M.POWER = { MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, COMBO = 4 }

-- ---------------------------------------------------------------------------
-- (b) close-out (2026-08-10): scenario-driven enemy mock for resto's
-- scan_pvp_pressure (GetEnemiesInRange). PRIEST (5) lands in resto
-- HEALER_CLASS_IDS; melee uses WARRIOR (1). Unit surface covers everything
-- the PvP-pressure scan + offensive-dispel preemptive scan read.
-- ---------------------------------------------------------------------------
local function _battery_enemy(kind)
    return {
        is_valid = function() return true end,
        is_alive = function() return true end,
        is_dead = function() return false end,
        is_cc = function() return false end,
        get_name = function() return "AuditEnemy_" .. kind end,
        get_class = function() return kind == "healer" and 5 or 1 end,
        get_distance = function() return 5 end,
        get_target = function() return nil end,
        get_health_percentage = function() return 100 end,
        get_active_spell_id = function() return 0 end,
        get_active_cast_or_channel_id = function() return 0 end,
    }
end

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
        -- 0.4s sits inside both pooling (<=0.45) and powershift (>0.35) windows.
        energy_predicted = function(self) return 100 end,
        energy_time_to_x = function(self, v) return 0.4 end,
        is_in_combat = function(self) return true end,
        get_distance = function(self, t) return 5 end,
        get_shapeshift_form_id = function(self) return 0 end,
        get_attack_power = function(self) return 500 end,
        get_player_stance = function(self) return 0 end,
        get_race_id = function(self) return M._race_override or 1 end,
        -- vec3 position (contract verified 2026-08-08): the platform's
        -- get_position returns ONE vec3 TABLE {x,y,z} (with [1]/[2] index
        -- aliases) — see shared/auto_loot (p.x,p.y,p.z), shared/targeting
        -- (pos.x,pos.y,pos.z) and EaxESP (base.x or base[1]). The Intervene
        -- close-out wrongly modeled multi-value returns; prot now reads the
        -- table form too (protection:430/767), and shaman's my_pos.x reads
        -- were already correct.
        get_position = function(self) return { x = 0, y = 0, z = 0, [1] = 0, [2] = 0 } end,
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

local function _friend(hp, dist, class_id, opts)
    hp = type(hp) == "number" and hp or 100
    opts = opts or {}
    local f = {
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
        -- Threat-family close-out (2026-08-10): opts.role feeds bear growl's
        -- target-of-target is_tank/is_healer reads (get_group_role);
        -- opts.threat_status / opts.has_aggro feed prot's ally-threatened scan
        -- (protection:584 reads the FIELD directly). All default nil —
        -- is_tank/is_healer read false and the threat scan skips, identical to
        -- the pre-opts behavior for every existing _friend consumer.
        get_group_role = function(self) return opts.role end,
        threat_status = opts.threat_status,
        has_aggro = opts.has_aggro,
        -- vec3 position (contract verified 2026-08-08): one {x,y,z} table
        -- with [1]/[2] aliases, matching the real API; prot's party scan
        -- (protection:443) reads the table fields for Intervene's range gate.
        get_position = function(self) return { x = 0, y = 0, z = 0, [1] = 0, [2] = 0 } end,
    }
    -- Class-id (ranked #4): only present when a scenario sets it via the
    -- `friend_class` override (druid/resto innervate + balance scan friends via
    -- unit_class_id -> get_class to find a healer ally). Absent by default so
    -- no other spec's class reads change.
    if type(class_id) == "number" then
        f.get_class = function(self) return class_id end
    end
    return f
end

-- ---------------------------------------------------------------------------
-- Rich, permissive NS mock. Battery scenarios can override individual closures
-- (e.g. NS.buff_up returning true) by mutating the returned table.
-- ---------------------------------------------------------------------------
function M.build_ns(class_key, era)
    era = era or "sylvanas"
    local ns = {}
    local profile = M.CLASS_PROFILE[class_key] or {}
    local class_id = profile.class_id or 0
    -- Scenario-aware player unit: holy/smite build_state derive
    -- context.hp = health_pct(NS.PLAYER_UNIT), and the unit-aware health_pct
    -- helper (import_helpers) reads unit.get_health_percentage when present.
    -- An empty stub made that read fall back to 100 and CLOBBER the scenario's
    -- low_self hp override, hiding every priest self-preservation lane.
    -- Delegate to the state bank so it reflects ctx.hp after apply_battery_state.
    ns.PLAYER_UNIT = {
        get_health_percentage = function(self) return ns._bstate("hp", 100) end,
        get_health = function(self) return ns._bstate("hp", 100) * 100 end,
    }
    ns.POWER_MANA = 0
    ns.POWER_RAGE = 1
    ns.POWER_ENERGY = 3
    ns.POWER_COMBO = 4
    ns.POWER_FOCUS = 2

    -- Warrior specs resolve ACTION ids through NS.WarriorSpells (mirrors
    -- classes/warrior/class_sylvanas.lua SPELLS). Seeded just below, after
    -- ns.spell_action is defined, so the entries are spell_action objects
    -- (method surface = live fidelity) — see the WarriorSpells block near
    -- ns.spell_action.
    ns.WarriorSpells = {}
    ns.PaladinSpells = {}
    ns.HunterSpells = {}
    ns.MageSpells = {}
    ns.WarlockSpells = {}
    ns.PriestSpells = {}
    ns.ShamanSpells = {}
    ns.RogueSpells = {}
    ns.DruidSpells = {}
    -- WotLK Death Knight spell table (Phase 1): empty table is fine —
    -- define_action_for_class falls back to ns.spell_action on a nil field,
    -- but the table must EXIST so `NS.DeathKnightSpells or {}` in the spec
    -- files resolves consistently and DKConstants reads don't hit nil.
    ns.DeathKnightSpells = {}
    ns.DeathKnightConstants = {
        FROST_FEVER_DEBUFF = { 55095 },
        BLOOD_PLAGUE_DEBUFF = { 55078 },
        HORN_OF_WINTER_BUFF = { 57623, 57330 },
    }
    ns.CLASS_ID = M.CLASS_IDS
    ns.class_id = M.CLASS_IDS
    ns.WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
        -- Mirrors classes/warrior/class_sylvanas.lua so kebab's
        -- Constants.BUFF_ID.SWEEPING_STRIKES index doesn't error on nil.
        BUFF_ID = { SWEEPING_STRIKES = 12328 },
    }
    ns.STANCE = ns.WarriorConstants.STANCE

    ns.log = function() end
    ns.debug = false
    ns.player_class_id = 0

    -- Scenario-aware clock: apply_battery_state advances _battery_now each
    -- scenario so module-level 1s scan caches (e.g. hunter_core pet scan,
    -- swing/mend cooldown gates) actually refresh between scenarios instead of
    -- pinning to scenario #1's state forever.
    ns.time_now = function() return _battery_now end
    ns.game_time_ms = function() return _battery_now * 1000 end
    ns.now_ms = function() return _battery_now * 1000 end
    ns._battery_now = _battery_now
    ns.core = {
        -- Scenario-aware clock (2026-08-08): enhancement's TotemicCall caches
        -- _core = NS.core at load time and throttles the visible-object scan
        -- on _core.time(); without a time() here now=0 always and the 1s
        -- throttle returns the stale cached result, never scanning.
        time = function() return _battery_now end,
        -- Scenario-aware (2026-08-08): enhancement's TotemicCall caches
        -- _get_totem_info = NS.core.spell_book.get_totem_info at load time;
        -- the totem_far scenario sets the totem_active bank key so the
        -- has_totem gate passes. Default (no key) keeps the legacy nil.
        spell_book = {
            get_totem_info = function(slot)
                if ns._bstate("totem_active") then return { have_totem = true } end
                return nil
            end,
            -- (b) close-out (2026-08-10): demo pet-type detection
            -- (demonology:210-228) reads NS.core.spell_book.get_pet_spells() to
            -- classify imp vs succubus. Bank-driven; the pvp_succubus scenario
            -- presents a Lash of Pain id (27274) so pet_type_succubus binds.
            get_pet_spells = function() return ns._bstate("pet_spells", {}) end,
        },
        -- Scenario-aware mirror of the load_spec _G.core stub: the visible
        -- scan (enh TotemicCall, prot threat scan) must see the scenario's
        -- visible_enemies list through the same bank.
        object_manager = { get_visible_objects = function() return ns._bstate("visible_enemies", {}) end },
    }

    -- Warrior spec files call NS.import_helpers("try_cast", ...) at load; the
    -- real implementation is populated by warrior/shared_helpers_sylvanas.lua
    -- on class registration. Return a permissive stub per requested name.
    ns.import_helpers = function(...)
        local names = { ... }
        local typed_map = {
            debuff_remains = 0, debuff_stacks = 0, buff_remains = 0,
            buff_stacks = 0,
        }
        local floaty = {
            -- NOTE: has_player_buff is NOT here on purpose — it has its own
            -- branch above that forwards to the map-aware ns.has_player_buff
            -- (buff_remains_map), so a constant false here would be dead data.
            player_control_locked = false, has_breakable_cc_nearby = false,
            can_attack_target = true,
            try_cast = true, spell_exists = true, spell_ready = true,
        }
        local results = {}
        for i = 1, #names do
            local n = names[i]
            if n == "health_pct" then
                -- Unit-aware: read the scenario target/unit HP (scenarios set
                -- target_hp), NOT a constant 100 — otherwise build_state
                -- calls like kebab's context.target_hp = health_pct(target)
                -- clobber the scenario override back to 100.
                results[i] = function(unit)
                    if unit and unit.get_health_percentage then
                        local ok, v = pcall(unit.get_health_percentage, unit)
                        if ok and type(v) == "number" then return v end
                    end
                    return 100
                end
            elseif n == "has_player_buff" then
                -- Per-buff state (Phase 3): specs capture this helper AT
                -- require() time (holy_sylvanas.lua:240-242 imports
                -- has_player_buff; ClearcastingGreaterHeal + SurgeOfLightSmite
                -- gate on the per-buff flags). A constant `false` here would
                -- deadlock those lanes even though the map-aware
                -- ns.has_player_buff (buff_remains_map) is defined later in
                -- build_ns — forward to the LATEST binding at call time.
                results[i] = function(ids)
                    if ns.has_player_buff then return ns.has_player_buff(ids) end
                    return false
                end
            elseif n == "buff_up" then
                -- Map-aware per-buff state (ranked #5 semantics): smite /
                -- priest-healing capture buff_up via import_helpers at require
                -- time. Without this branch the catch-all below returns a
                -- constant-true function, so every captured buff check read
                -- "up" and SoloRenew (needs has_renew=false) + InnerFocus
                -- (needs has_inner_focus=false) could never fire. Forward to
                -- the LATEST ns.buff_up binding (map-first + buffs_up
                -- fallback) at call time, mirroring has_player_buff.
                results[i] = function(unit, ids)
                    if ns.buff_up then return ns.buff_up(unit, ids) end
                    return false
                end
            elseif typed_map[n] ~= nil then
                results[i] = function() return typed_map[n] end
            elseif floaty[n] ~= nil then
                results[i] = function() return floaty[n] end
            else
                results[i] = function() return true end
            end
        end
        return unpack(results)
    end

    -- Scenario-aware learned/exists mock (ranked #9): the low_level scenario
    -- marks pre-level spells as NOT learned via the `not_learned` state-bank
    -- key ({ [spell_id] = true }). Default (no key) keeps the legacy
    -- everything-learned behavior, so non-leveling scenarios are untouched.
    -- Both spell_exists and is_spell_learned share the check — a spell that
    -- isn't learned yet also isn't in the spellbook (arcane
    -- low_level_bolt_matches reads spell_exists(ArcaneBlast 30451); frost
    -- frost_armor_matches reads is_spell_learned(MageArmor 27125/6117);
    -- warlock needs_imp_fallback reads is_spell_learned(30146)/688).
    -- Accepts numeric ids and spell_action tables (checks all rank ids — same
    -- normalization as the bank-aware get_spell_cd; keep them in sync).
    -- NOTE: the not_learned map is global per scenario (not spec-scoped), so
    -- the ids a scenario marks must remain class-specific (the low_level map
    -- is mage/warlock only).
    local function not_learned(spell)
        local nl = ns._bstate("not_learned", nil)
        if type(nl) ~= "table" or not spell then return false end
        local ids = type(spell) == "number" and { spell } or (type(spell) == "table" and spell.ids) or {}
        for _, id in ipairs(ids) do
            if nl[id] then return true end
        end
        return false
    end
    ns.spell_exists = function(spell) return not not_learned(spell) end
    ns.spell_ready = function(spell, target, opts)
        return ns.cooldown_remains(spell) <= 0
    end
    ns.is_spell_learned = function(spell) return not not_learned(spell) end
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
    -- Form-aware has_form: form id comes from the scenario state bank (default
    -- 0 = caster). Previously returned true unconditionally, which made every
    -- druid spec believe it was shapeshifted: cat damage actions fired in every
    -- scenario while form-gated strategies (CatForm, HealthPotion-while-cat,
    -- powershift) could NEVER match. Map names to the same ids the specs use
    -- (cat=3, bear=1, travel=4, moonkin=2).
    local FORM_IDS = { caster = 0, bear = 1, moonkin = 2, cat = 3, travel = 4, aquatic = 5, flight = 6 }
    ns.has_form = function(name)
        local form = ns._bstate("form", 0) or 0
        if name == nil then return form ~= 0 end
        -- String forms ("cat"/"bear") come from the leveling_wotlk scenarios
        -- (leveling_wotlk compares state.form STRINGS) and must match by NAME;
        -- numeric ids compare against FORM_IDS. Without this branch a string
        -- form would silently read as "not in form" for every name — the same
        -- string-in-numeric-slot hazard fixed for ctx.stance below.
        if type(form) == "string" then return form == name end
        local want = FORM_IDS[name]
        if want == nil then return false end
        return form == want
    end
    ns.is_stealthed = function() return ns._bstate("is_stealthed", false) end
    ns.pet_hp_pct = function() return ns._bstate("pet_hp", 100) end
    ns.pet_alive = function() return not (ns._bstate("pet_dead", false) == true) end
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

    -- (b) close-out (2026-08-10): return the scenario-aware me unit once
    -- apply_battery_state publishes ns.me, so build_state reads that resolve
    -- the player via NS.GetPlayer() (shadow:460, warlock files, etc.) see the
    -- SAME unit the debuff_up/debuff_remains player-map branch compares
    -- against (SW:D CC break's is_breakable_cc_active(me, NS)). Before this,
    -- GetPlayer() minted a fresh default mock every call, so player-debuff
    -- reads via me never matched ns.me. Require-time reads (smite's
    -- load_player race binding) still hit the default mock — ns.me is nil
    -- until the first scenario.
    ns.GetPlayer = function() return ns.me or _me_unit(class_id) end

    ns.try_cast = function() return true end
    ns.use_item_by_id = function() return true end
    ns.is_item_ready = function() return true end
    ns.get_item_count = function() return 1 end
    ns.use_item = function() return true end

    ns.get_setting = function(key, default)
        -- Scenario-aware: setting_overrides flow through the spec_kit fallback
        -- chain (spec_kit.setting -> NS.get_setting), so e.g.
        -- { holy_refresh_enabled = false } (fsr_pause) disables paladin
        -- choose_blessing (BlessingRefresh would otherwise fire before
        -- FSRPause — buffs_up makes every blessing "up" with exactly 120s
        -- remaining == the refresh threshold). Unconfigured keys return nil.
        local ov = ns._bstate("setting_overrides", nil)
        if type(ov) == "table" and key and ov[key] ~= nil then return ov[key] end
        return nil
    end
    -- Vanilla-era support (2026-08-11): mirror core/settings.lua's NS.setting
    -- (context.settings first, then NS.get_setting, then default). The vanilla
    -- files capture `local setting = NS.setting` at require time — without the
    -- stub, subtlety_vanilla's matchers (option()/Evasion/Vanish/Preparation/
    -- Feint, subtlety_vanilla:133-368) crashed on every scenario and all seven
    -- of its lanes reported never. Scenario-aware via the get_setting chain.
    ns.setting = function(context, key, default)
        local settings = context and context.settings
        if settings and settings[key] ~= nil then return settings[key] end
        if ns.get_setting then
            -- get_setting returns nil for unconfigured keys (deliberately, so
            -- spec_kit.setting's chain can apply ITS default) — NS.setting must
            -- fall through to its own default in that case (engine semantics).
            local v = ns.get_setting(key, nil)
            if v ~= nil then return v end
        end
        return default
    end
    -- Scenario-aware settings: `setting_overrides = { [setting_key] = value }`
    -- (e.g. { seal_twisting_enabled = true }) flips get_any_setting for the
    -- scenario; unconfigured keys return nil, so retri can_twist stays false
    -- everywhere except the seal-twist scenarios (retribution_sylvanas.lua:403
    -- falls back to the `true` default only when the setting is unreadable,
    -- which we must NOT mimic battery-wide or SealTwistPrepCommand would fire
    -- in every scenario at the default 0.5s swing).
    ns.get_any_setting = function(ctx, key, key2, default)
        local ov = ns._bstate("setting_overrides", nil)
        if type(ov) == "table" then
            if key and ov[key] ~= nil then return ov[key] end
            if key2 and ov[key2] ~= nil then return ov[key2] end
        end
        return nil
    end

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
    -- (b) close-out (2026-08-10): enh AutoAttack gates on NOT auto-attacking
    -- (enhancement:1207); the legacy always-true stub hard-blocked the lane.
    -- Bank-driven with default true so every other scenario is unchanged; the
    -- enh_autoattack scenario flips it to false. Battery artifact only — the
    -- live client's is_auto_attacking is false at combat start, so the lane
    -- fires in-game; no spec-file change.
    ns.is_auto_attacking = function() return ns._bstate("is_auto_attacking", true) == true end
    ns.is_current_spell = function() return false end
    ns.is_execute_phase = function(hp, threshold) return type(hp) == "number" and hp <= (threshold or 20) end
    ns.is_valid_target = function() return true end
    ns.is_melee_target = function() return true end
    ns.is_tank_unit = function() return true end
    ns.is_pvp_zone = function() return false end
    -- Era flag: DK specs + presence_manager call NS.is_wotlk() as a FUNCTION.
    -- The legacy TBC battery set a boolean false; era="wotlk" must provide the
    -- callable form or presence_manager's `if not (NS.is_wotlk and NS.is_wotlk())`
    -- short-circuits on the boolean and every DK spec bails at load.
    ns.is_wotlk = (era == "wotlk") and function() return true end or false
    -- Vanilla era flag, callable like is_wotlk (vanilla file headers reference
    -- NS.is_vanilla() as the loader contract; keep it a function for parity).
    ns.is_vanilla = (era == "vanilla") and function() return true end or false
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
    ns.unit_creature_type = function() return ns._bstate("target_creature_type", 7) end
    ns.threat_status = function() return 0 end
    ns.is_threat_safe = function() return true end
    ns.get_party_members = function() return {} end
    ns.party_members = function() return {} end
    ns.get_pet = function() return nil end
    ns.GetPet = function() return nil end
    ns.get_pet_hp = function() return 100 end
    ns.has_pet = function() return false end
    ns.mana = ns.mana
    -- Bank-aware get_spell_cd (ranked #8): subtlety's Preparation matcher
    -- requires a major CD burned (vanish_cd/sprint_cd/evasion_cd derived from
    -- NS.get_spell_cd in build_state); this stub was hardwired 0 so the CD
    -- was never "burned" and Preparation could never fire. Now reads on_cd
    -- like cooldown_remains (same table; DIFFERENT scan semantics — this one
    -- checks ALL rank ids so scenarios may key by any rank, e.g. 1856 =
    -- Vanish low rank, ids[1] the TBC top rank 26889, while cooldown_remains
    -- stays ids[1]-only for its top-rank-keyed scenarios). Only
    -- subtlety_sylvanas/subtlety_vanilla consume get_spell_cd, so no other
    -- spec is affected.
    ns.get_spell_cd = function(spell)
        local on_cd = ns._bstate("on_cd", nil)
        if type(on_cd) == "table" and spell then
            local ids
            if type(spell) == "number" then
                ids = { spell }
            elseif type(spell) == "table" then
                ids = spell.ids
            end
            for _, id in ipairs(ids or {}) do
                if on_cd[id] then return on_cd[id] end
            end
        end
        return 0
    end
    ns.get_spell_cooldown = function() return 0 end
    ns.get_spell_id = function() return 0 end
    ns.is_spell_in_range = function() return true end
    ns.get_time_until_swing = function() return ns._bstate("swing_until", 0.5) end
    ns.get_time_until_oh_swing = function() return ns._bstate("swing_until", 0.5) end
    ns.swing_progress = function() return 0.5 end
    ns.swing_time_until = function() return ns._bstate("swing_until", 0.5) end
    ns.get_totem_info = function() return false end
    ns.register_on_spell_cast = function() return true end
    ns.register_class_middleware = function() end
    -- Scenario-aware (2026-08-08): the healer FriendlyTarget lanes (disc +
    -- holy priest, holy paladin, resto druid + shaman) gate on
    -- state.friendly_target_ready / state.friendly_target, populated from
    -- NS.get_friendly_target_entry (core/units.lua:129 — { unit, hp_pct,
    -- effective_hp, is_player } of the current target when it is friendly).
    -- The friendly_target scenario presents a friendly unit below the 90%
    -- threshold; absent the flag every spec keeps the nil-entry behavior
    -- (hostile/default targets never produce an entry). Keyed on
    -- friendly_target_hp ALONE (a number is non-nil only when the scenario
    -- sets it) — deliberately NOT a friendly_target boolean, which would
    -- collide with healing_sylvanas.lua:454 reading context.friendly_target
    -- as a UNIT.
    ns.get_friendly_target_entry = function()
        local hp = ns._bstate("friendly_target_hp", nil)
        if not hp then return nil end
        local unit = _friend(hp, 30)
        return { unit = unit, hp_pct = hp, effective_hp = hp, is_player = true }
    end
    -- (c) close-out (2026-08-09): balance RebirthBattleRez (balance:381-386)
    -- reads `_find_dead()` and needs a dead PLAYER ally for the is_player gate
    -- (dead:is_player()). The dead_ally scenario presents _friend(0, 5) — hp 0
    -- makes is_dead true, is_player stays true; absent the flag we keep the
    -- legacy nil so every other find_dead consumer is unchanged.
    ns.find_dead_party_ally = function()
        if ns._bstate("dead_ally", false) then return _friend(0, 5) end
        return nil
    end
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
    ns.healing_count_below_hp = function(entries, count, threshold)
        threshold = threshold or 100
        if not entries then return 0 end
        local n = 0
        for i = 1, (count or #entries) do
            if entries[i] and (entries[i].effective_hp or 100) < threshold then n = n + 1 end
        end
        return n
    end
    ns.healing_get_lowest_hp = function(entries, count, threshold)
        if not entries or not count or count <= 0 then return nil end
        threshold = threshold or 100
        local best, best_hp = nil, 999
        for i = 1, count do
            local e = entries[i]
            if e and e.effective_hp then
                local hp = e.effective_hp
                if hp <= threshold and hp < best_hp then best, best_hp = e, hp end
            end
        end
        return best
    end
    ns.healing_get_tank = function(entries, count)
        if not entries or not count or count <= 0 then return nil end
        for i = 1, count do
            local e = entries[i]
            if e and e.is_tank then return e end
        end
        return entries[1]
    end
    ns.get_local_player = ns.GetPlayer
    ns.get_energy = ns.energy
    -- Real safe_field(obj, key) semantics (shared/safe_helpers_sylvanas.lua:
    -- 45): returns obj[key] or nil. Every consumer passes (obj, key) — druid
    -- unit_class_id(unit, "get_class"), offensive_dispel, ooc_manager, mage/
    -- warrior middleware. The old (value, default) shape returned the whole
    -- object, making unit_class_id pcall a table (always error -> nil).
    ns.safe_field = function(obj, key)
        if obj == nil then return nil end
        local ok, value = pcall(function() return obj[key] end)
        if not ok then return nil end
        return value
    end
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
    -- (c) close-out (2026-08-09): BM Trinket (beast_mastery:378-385) reads
    -- NS.TrinketManager.get_equipped_trinkets for trinket_1_id; the battery
    -- stub only had try_use, so trinket_1_id stayed nil and the lane could
    -- never fire even with trinket_mode = slot1. The has_trinket scenario
    -- presents one equipped item (id 1); is_item_ready below returns true.
    ns.TrinketManager = {
        try_use = function() return false end,
        get_equipped_trinkets = function()
            if ns._bstate("has_trinket", false) then return { { item_id = 1 } } end
            return nil
        end,
    }
    ns.RageManager = { should_dump = function() return true end }
    -- Mirrors shared/stance_manager_sylvanas.lua semantics: get_optimal_stance
    -- returns a stance NAME (string) or nil; should_switch returns false when
    -- already in the desired stance. Unblocks protection StanceSwitch
    -- (prot build_state reads SM.get_optimal_stance into desired_stance).
    ns.StanceManager = {
        ensure_stance = function() return true end,
        get_optimal_stance = function(context, state)
            local stance = (state and state.stance) or (context and context.stance) or 2
            if stance ~= 2 then return "defensive" end
            return nil
        end,
        should_switch = function(context, state, desired)
            if not desired then return false end
            local stance = (state and state.stance) or (context and context.stance) or 1
            local desired_id = desired == "defensive" and 2
                or (desired == "berserker" and 3)
                or (desired == "battle" and 1)
                or nil
            if not desired_id then return false end
            if stance == desired_id then return false end
            return true
        end,
    }
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
        -- Priority tiers mirror shared/offensive_dispel_sylvanas.lua so specs
        -- that gate on OffensiveDispelDB.PRIORITY_HIGH work in the battery.
        PRIORITY_CRITICAL = 4,
        PRIORITY_HIGH = 3,
        PRIORITY_MEDIUM = 2,
        PRIORITY_LOW = 1,
        should_purge = function() return ns._bstate("enemy_buffed", false) end,
        -- Real module returns (best_id, priority, best_name); rogue ShivPurge
        -- reads all three, so the stub must return a name too or shiv_purge_name
        -- stays nil and the whole purge lane is invisible.
        find_best_dispel_target = function(target)
            if ns._bstate("enemy_buffed", false) then return target, 10, "Bloodlust" end
            return nil, 0, nil
        end,
        -- (b) close-out (2026-08-10): shadow binds CCBreakDB = NS.OffensiveDispelDB
        -- (shadow:55), so this stub IS the SW:D CC-break reader. Delegate to
        -- ns.debuff_up over the damage-breakable CC ids (Polymorph/Sap/Gouge/
        -- Blind/Repentance/Fear family) — debuff_up consults the player-debuff
        -- map for the player unit, so the shadow_cc_break scenario's
        -- player_debuff_remains_map { [118] = 5 } drives has_breakable_cc.
        is_breakable_cc_active = function(unit, ns2)
            local ids = { 118, 12824, 12825, 12826, 28271, 28272, 6770, 2070, 11297, 2094, 1776, 1079, 5782, 6215 }
            for _, id in ipairs(ids) do
                if ns.debuff_up(unit or ns.me, id) then return true, "CC" end
            end
            return false, nil
        end,
        is_casting_preemptive_cc = function() return false, nil end,
    }
    -- Note: NS.purge_should_cast / NS.PurgeManager stubs were considered but
    -- removed — enhancement_sylvanas.lua now mirrors the middleware gate
    -- (OffensiveDispelDB + purge_manager) and no spec reads those helpers.
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
    -- Scenario-driven heal-scan stubs (healer triage upgrade): the per-class
    -- Healing modules expose the triage surface the specs' build_state reads.
    -- Entries mirror the scenario's friends_hp (default { 55, 70, 85 }) plus a
    -- player entry. CONTRACT: entry[2] is ALWAYS the tank (is_tank/role="tank")
    -- so tank ~= lowest (PreHeal/Emergency PWS lanes) — scenario authors must
    -- keep the tank at friends_hp index 2 or add a tank_low-style override;
    -- the player entry (is_self, hp from ctx.hp) enables PurifySelf/self-cure.
    -- Per-debuff-type affliction flags come from the scenario `afflicted` table
    -- (poison/disease/curse/magic) — this unblocks the dispel/cleanse/cure lanes.
    local function _heal_entries()
        -- Default to an INJURED group (55/70/85) so the heal lanes that gate on
        -- state.lowest/tank fire in the base scenarios (mirrors the prior scan
        -- behavior). The `group_healthy` scenario (friends_hp 100s) presents a
        -- fully-healthy group so the Idle*/Solo* DPS lanes stay observable.
        local hps = ns._bstate("friends_hp", nil)
        if not hps or type(hps) ~= "table" or #hps == 0 then hps = { 55, 70, 85 } end
        local aff = ns._bstate("afflicted", nil) or {}
        local a = { poison = aff.poison == true, disease = aff.disease == true,
                    curse = aff.curse == true, magic = aff.magic == true }
        local friend_class = ns._bstate("friend_class", nil)
        -- (b) close-out (2026-08-10): snared_friend marks the lowest ally
        -- entry is_snared → holy entry_needs_freedom (holy:319-324) picks it as
        -- freedom_target → BlessingOfFreedomSnare observable. Only freedom
        -- lanes read is_snared, so other heal-scan consumers are unaffected.
        local entries, count = {}, 0
        for i, hp in ipairs(hps) do
            count = count + 1
            -- Low-HP targets carry a short TTD so TTD-gated urgency lanes
            -- (druid NaturesSwiftness) are observable; healthy ones do not.
            local ttd = (hp <= 30) and 3 or 999
            entries[count] = {
                unit = _friend(hp, 30, friend_class), hp = hp, effective_hp = hp, max_hp = 10000,
                time_to_die = ttd, future_hp = hp, death_risk = 0, will_die_soon = false,
                is_snared = (ns._bstate("snared_friend", false) == true and i == 1) or nil,
                -- Threat-family close-out (2026-08-10): friendly_target_threat
                -- marks the lowest ally entry threatened (holy:332
                -- entry_needs_protection ORs threat_status >= 2). Only holy
                -- BoPFocusedAlly reads it; default nil is a no-op for every
                -- other heal-scan consumer.
                threat_status = (i == 1) and ns._bstate("friendly_target_threat", nil) or nil,
                -- Deficit must mirror the real scan semantics (heal modules set
                -- deficit = max_hp - current_hp): a low-HP entry needs a
                -- positive deficit or every deficit_of(...) > 0 gate (paladin
                -- LightGraceBuild/LightGraceChain) is battery-dead. Percentage
                -- scale (100 - effective_hp) is consistent with effective_hp.
                -- NOTE: percentage scale is fine for `> 0` gates only; do not
                -- compare against raw-HP constants (LARGE/MEDIUM/LIGHT_HEAL_
                -- DEFICIT are raw-scale in live play).
                deficit = math.max(0, 100 - hp), effective_deficit = math.max(0, 100 - hp),
                is_tank = (i == 2), role = (i == 2) and "tank" or "dps",
                is_player = false, is_self = false,
                is_valid = true, is_friendly = true, hostile = false,
                has_weakened_soul = false, has_renew = false, renew_remains = 0,
                has_poison = a.poison, has_disease = a.disease, has_curse = a.curse,
                has_magic = a.magic, needs_cleanse = a.poison or a.disease or a.curse or a.magic,
            }
        end
        count = count + 1
        local ph = ns._bstate("hp", 100)
        entries[count] = {
            unit = ns.PLAYER_UNIT, hp = ph, effective_hp = ph, max_hp = 10000,
            time_to_die = 999, future_hp = ph, death_risk = 0, will_die_soon = false,
            deficit = math.max(0, 100 - ph), effective_deficit = math.max(0, 100 - ph),
            is_tank = false, role = "dps",
            is_player = true, is_self = true,
            is_valid = true, is_friendly = true, hostile = false,
            has_weakened_soul = false, has_renew = false, renew_remains = 0,
            has_poison = a.poison, has_disease = a.disease, has_curse = a.curse,
            has_magic = a.magic, needs_cleanse = a.poison or a.disease or a.curse or a.magic,
        }
        -- Lifebloom let-bloom state (healer (c) close-out): the resto druid
        -- LifebloomLetBloom lane needs an entry with Lifebloom stacks near
        -- expiry (should_let_lifebloom_bloom gates on lifebloom_stacks > 0 +
        -- lifebloom_remains <= LIFEBLOOM_BLOOM_SOON). The scenario override
        -- `lifebloom = { index = N, stacks = S, remains = R }` attaches the
        -- fields so the lane becomes observable.
        local lb = ns._bstate("lifebloom", nil)
        if type(lb) == "table" and type(lb.index) == "number" and entries[lb.index] then
            entries[lb.index].lifebloom_stacks = lb.stacks or 0
            entries[lb.index].lifebloom_remains = lb.remains or 0
        end
        return entries, count
    end
    local function _afflicted_flag(key)
        local aff = ns._bstate("afflicted", nil)
        return type(aff) == "table" and aff[key] == true
    end
    local function _heal_module()
        return {
            should_cast = function() return true end,
            scan_healing_targets = _heal_entries,
            count_below_hp = function(threshold)
                local entries, count = _heal_entries()
                return ns.healing_count_below_hp(entries, count, threshold)
            end,
            count_subgroup_below_hp = function(threshold)
                local entries, count = _heal_entries()
                return ns.healing_count_below_hp(entries, count, threshold)
            end,
            healing_count_below_hp = function(threshold)
                local entries, count = _heal_entries()
                return ns.healing_count_below_hp(entries, count, threshold)
            end,
            get_lowest_hp_target = function(threshold)
                local entries, count = _heal_entries()
                return ns.healing_get_lowest_hp(entries, count, threshold)
            end,
            get_tank_target = function()
                local entries, count = _heal_entries()
                return ns.healing_get_tank(entries, count)
            end,
            get_cleanse_target = function()
                local entries, count = _heal_entries()
                for i = 1, count do
                    if entries[i].needs_cleanse then return entries[i] end
                end
                return nil
            end,
            all_members_above_hp = function(threshold)
                local entries, count = _heal_entries()
                for i = 1, count do
                    if (entries[i].effective_hp or 100) < threshold then return false end
                end
                return true
            end,
            has_disease = function() return _afflicted_flag("disease") end,
            has_poison = function() return _afflicted_flag("poison") end,
            has_curse = function() return _afflicted_flag("curse") end,
            has_magic = function() return _afflicted_flag("magic") end,
            has_dangerous_dispel = function() return _afflicted_flag("magic") end,
            has_weakened_soul = function() return false end,
            has_renew = function() return false end,
            renew_remains = function() return 0 end,
            has_pws = function() return false end,
            pws_absorb_remaining = function() return 0 end,
            predict_effective_deficit = function() return 0 end,
            group_mana_avg = function() return ns._bstate("mana_pct", 100) end,
            is_in_raid = function() return false end,
            is_in_party = function() return true end,
            select_heal = function(context, state, lowest)
                local entry = lowest or { unit = ns.PLAYER_UNIT, effective_hp = 60 }
                return {
                    spell = ns.spell_action({ 1064, 1062, 25423, 25422, 25421, 25420, 1061, 1060, 421, 930, 913, 943, 604 }, "ChainHeal"),
                    name = "ChainHeal",
                    unit = entry.unit,
                    effective_hp = entry.effective_hp or 60,
                }
            end,
        }
    end
    ns.PaladinHealing = _heal_module()
    ns.PriestHealing = _heal_module()
    ns.ShamanHealing = _heal_module()
    ns.DruidHealing = _heal_module()
    ns.class_middleware = {}
    ns.unified_registry = {}
    ns.unified_state_builders = {}
    ns.playstyles = { leveling = {} }

    -- Vanilla-era support (2026-08-11): plain-style vanilla files register via
    -- NS.rotation_registry:register(name, strategies, { get_state = build_state })
    -- and return their bare strategies table (fury_vanilla is the canonical
    -- example). The real engine resolves get_state from this registry, so the
    -- mock captures the registration per load (build_ns runs once per
    -- load_spec) and run_spec falls back to it when result.build_state is
    -- absent — without this, every vanilla state-field read in a matcher
    -- (s.target_casting etc.) silently sees nil and the lanes report never.
    ns.rotation_registry = {
        register = function(self, name, strategies, options)
            ns._registry = { name = name, strategies = strategies, options = options or {} }
        end,
    }
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
            -- WotLK era (Phase 1 triage): *_wotlk.lua specs gate on
            -- `action:cooldown_remaining() <= 0` (e.g. retribution Judgement /
            -- CrusaderStrike / DivineStorm, mage arcane PresenceOfMind, rogue
            -- combat BladeFlurry). Without this method the caller's
            -- cd_remaining() fell through to 99, so every `<= 0` gate failed
            -- and all 8 retri lanes (plus others) never fired. Mirrors
            -- ns.get_spell_cd: on_cd-map aware, 0 (ready) otherwise.
            cooldown_remaining = function(self)
                local on_cd = ns._bstate and ns._bstate("on_cd", nil)
                if type(on_cd) == "table" then
                    for _, id in ipairs(ids or {}) do
                        if on_cd[id] then return on_cd[id] end
                    end
                end
                return 0
            end,
        }
        obj.rank_ids = function() return ids end
        return obj
    end

    -- Warrior spell resolution (mirrors classes/warrior/class_sylvanas.lua
    -- SPELLS rank tables). The primary-on-cooldown filler lanes
    -- (Devastate/Rend/HeroicStrike) gate on
    -- `ss_ready == false and revenge_ready == false`, which the battery can
    -- only exercise when ShieldSlam/Revenge resolve to real ids and appear in
    -- a scenario's on_cd table (30356 = ShieldSlam top rank, 30357 = Revenge
    -- top rank — the low-rank 23922/6572 are never read since cooldown_remains
    -- uses ids[1]). Built via ns.spell_action so ACTION entries carry the same
    -- method surface (id/rank/cooldown/is_known) as live SPELLS entries.
    ns.WarriorSpells = {
        ShieldSlam = ns.spell_action({ 30356, 25258, 23925, 23924, 23923, 23922 }, "ShieldSlam"),
        Revenge = ns.spell_action({ 30357, 25269, 25288, 11601, 11600, 7379, 6574, 6572 }, "Revenge"),
        -- Taunt (ranked #6): the elite_taunt_cd scenario puts Taunt on CD via
        -- on_cd = { [355] = 6 }; without a real spell_action entry the spec's
        -- ACTION.Taunt has no ids and cooldown_remains can't resolve 355, so
        -- taunt_ready stays true and TauntSecondary's "Taunt on CD" gate never
        -- passes. Mirrors class_sylvanas.lua (ids = { 355 }).
        Taunt = ns.spell_action({ 355 }, "Taunt"),
        -- Devastate (close-out ranked #1): WITHOUT this entry the spec's
        -- define("Devastate") falls back to spell_action(nil) -> ids { nil }
        -- -> cooldown_remains can never resolve an on_cd key -> dev_ready
        -- stays true in every scenario -> SunderArmor's pre-Devastate
        -- fallback (prot:531 `if state.dev_ready then return false end`) can
        -- never fire. The `not_learned` map does NOT help here: it only gates
        -- spell_exists/is_spell_learned, while dev_ready comes from the
        -- cooldown-only spell_ready mock. Seeding the ids makes the
        -- sunder_fallback scenario's on_cd { [30022] = 6 } resolvable.
        -- Mirrors class_sylvanas.lua (ids = { 30022, 30016, 20243 }).
        Devastate = ns.spell_action({ 30022, 30016, 20243 }, "Devastate"),
    }
    -- Druid spell resolution for the balance multi-DoT spread lanes: the
    -- spread matchers explicitly gate on `SPELLS.Moonfire`/`SPELLS.InsectSwarm`
    -- existing (the main DoT lanes use the lenient NS.action_matches path and
    -- fire regardless, but the spreads return false on nil). Rank ids mirror
    -- classes/druid/class_sylvanas.lua (27013/26988 top ranks — the same ids
    -- the multidot scenario's debuff_remains_map uses).
    ns.DruidSpells = {
        Moonfire = ns.spell_action({ 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
        InsectSwarm = ns.spell_action({ 27013, 24977, 24976, 24975, 24974, 5570 }, "InsectSwarm"),
        -- (c) close-out (2026-08-09): balance HurricaneAoE (balance:421) does
        -- `if not SPELLS.Hurricane then return false end` — the battery
        -- DruidSpells had no Hurricane, so the lane was structurally dead even
        -- with aoe+mana+barkskin in place. 27011 is the TBC max rank (matches
        -- the class_sylvanas ladder).
        Hurricane = ns.spell_action({ 27011, 27012, 27013 }, "Hurricane"),
    }
    -- Scenario-aware equipped-item mock: the mutilate_daggers scenario sets
    -- equipped_daggers = true and get_equipped_item_id returns a real dagger
    -- item id (776, from shared/dagger_set_sylvanas DAGGER_IDS) for the
    -- MAIN_HAND/OFF_HAND slots, so assassination's build_state derives
    -- state.has_daggers = true (assn:234-240 reads both hands + is_dagger
    -- map). Default 0 preserves the legacy no-weapon behavior everywhere else.
    -- NOTE: kebab's has_offhand_weapon also reads slot 17, so it sees the
    -- dagger in mutilate_daggers too — benign (kebab has 0 never-firing lanes
    -- and no exclusivity pin reads has_offhand).
    ns.get_equipped_item_id = function(slot)
        if ns._bstate("equipped_daggers", false)
            and (slot == ns.EQUIPMENT_SLOTS.MAIN_HAND or slot == ns.EQUIPMENT_SLOTS.OFF_HAND) then
            return 776
        end
        return 0
    end
    ns.EQUIPMENT_SLOTS = { HEAD = 1, MAIN_HAND = 16, OFF_HAND = 17 }
    ns.broken_api_throttled = function() return false end
    ns.is_interruptible = function() return true end
    ns.target_casting = function() return ns._bstate("target_is_casting", false) end
    ns.is_in_melee_range = function() return true end
    ns.cp_debug = function() end
    ns.time_until_swing = function() return ns._bstate("swing_until", 0.5) end
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
    -- FSR manager (ranked #6): the real shared/fsr_manager_sylvanas loads and
    -- its game-state reads (is_inside_fsr via last-cast time, get_regen_delta
    -- via _core.spell_book power regen) return false/0 in the battery, so the
    -- 5 FSRPause healer lanes could never fire. Preload a scenario-driven
    -- stub backed by the state bank (the fsr_pause scenario sets the flags);
    -- each spec module captures THIS table at require() time, so the closures
    -- see the current scenario's bank on every build_state/match call.
    -- load_spec restores package.loaded after dofile so other suites get the
    -- real module back.
    package.loaded["shared/fsr_manager_sylvanas"] = {
        is_inside_fsr = function() return ns._bstate("fsr_inside", false) == true end,
        seconds_until_fsr = function() return ns._bstate("fsr_seconds", 0) end,
        get_regen_delta = function() return ns._bstate("fsr_regen_delta", 0) end,
        should_pause_for_fsr = function(state, context)
            local ok = ns._bstate("fsr_pause_ok", false) == true
            return ok, ok and "battery: inside FSR window" or "battery: outside FSR window"
        end,
        is_fsr_pause_enabled = function() return ns._bstate("fsr_pause_ok", false) == true end,
    }
    -- TSHelper (ranked #1): the real shared/ts_helper_sylvanas reads live
    -- target_selector state, so get_dps_targets returns empty in the battery
    -- and the multi-DoT spread lanes (warlock find_dot_target, shadow
    -- _find_multidot_target, balance _multidot_enemy_list) could never find a
    -- second unit. Preload a stub whose get_dps_targets returns the scenario's
    -- enemy list (ctx.enemies — populated for 2+ enemy scenarios, ranked #7);
    -- specs capture THIS table at require() time. get_heal_targets stays
    -- empty: the heal-scan stubs replace scan_healing_targets wholesale and
    -- must not see phantom allies.
    package.loaded["shared/ts_helper_sylvanas"] = {
        get_dps_targets = function(limit)
            local list = ns._bstate("enemies", {})
            if type(list) ~= "table" then return {} end
            return list
        end,
        get_heal_targets = function(limit) return {} end,
    }
    -- Buffs/debuffs: buffs_up scenarios report auras present, otherwise down.
    -- Per-buff remains: the `buff_remains_map` override ({ [buff_id] = seconds })
    -- takes precedence — this is the per-buff state mechanism (paladin holy
    -- LightGraceChain gates on lights_grace_remains in (0, 2.5), id 31834;
    -- future per-buff lanes — clearcasting, Surge of Light, Inner Focus —
    -- reuse it). NOTE: aura_remains/debuff_remains intentionally stay on the
    -- buffs_up fallback (no map lookup) — extend the map if a future lane
    -- gates on those APIs.
    -- buff_up is map-aware (ranked #5): combat's BladeFlurry needs SnD up
    -- (SND_BUFF {6774, 5171}) AND Blade Flurry's own buff down (13877) — both
    -- read ns.buff_up, so the all-or-nothing buffs_up fallback self-blocks
    -- (buffs_up=true marks BF already-up; buffs_up=false leaves SnD down). The
    -- battle_ready scenario sets buff_remains_map = { [6774]=20, [5171]=20 }
    -- → has_snd=true, has_blade_flurry=false. Map-miss ids fall back to
    -- buffs_up exactly as before, so non-map scenarios stay byte-identical.
    -- Shared with has_player_buff below (same map-first + buffs_up fallback
    -- semantics, identical normalization) — keep them on ONE helper so they
    -- can't drift apart.
    -- (a) opt-in close-out (2026-08-10): enh GraceOfAirTotemTwist reads
    -- NS.buff_remains(PLAYER, ACTION.WindfuryTotem / ACTION.GraceOfAirTotem)
    -- where ACTION.* is a spell_action OBJECT ({ids={...}}, no top-level
    -- numeric keys) — the legacy stubs iterated the object itself, so the
    -- map lookup always missed (buff 0) and the WF-buff/GoA-expiry gates
    -- could never pass. cooldown_remains already normalizes via spell.ids;
    -- share that normalization across every map-aware id consumer so
    -- callers passing lists, numbers, or spell_action objects all resolve.
    local function normalize_ids(ids)
        if type(ids) == "number" then return { ids } end
        if type(ids) == "table" then
            -- spell_action object (method surface, .ids list) vs plain list
            -- of numeric ids (SEAL_*_BUFF, RIP_DEBUFF, etc.).
            if type(ids.ids) == "table" then return ids.ids end
            return ids
        end
        return {}
    end
    local function map_aware_buff(ids)
        local map = ns._bstate("buff_remains_map", nil)
        ids = normalize_ids(ids)
        if type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return true end
            end
        end
        return ns._bstate("buffs_up", false)
    end
    ns.buff_up = function(unit, ids) return map_aware_buff(ids) end
    ns.buff_remains = function(unit, ids)
        local map = ns._bstate("buff_remains_map", nil)
        -- callers pass either a list of ids, a single numeric id (e.g. bear
        -- THORNS_BUFF), or a spell_action object (enh totem auras);
        -- normalize so ipairs never sees a number or an object.
        ids = normalize_ids(ids)
        if type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return map[id] end
            end
        end
        if ns._bstate("buffs_up", false) then return 20 end
        return 0
    end
    ns.aura_remains = function() if ns._bstate("buffs_up", false) then return 20 end return 0 end
    -- Per-target DoT model (ranked #1): the `debuff_remains_map` override
    -- ({ [debuff_id] = seconds }) marks the PRIMARY target as carrying those
    -- debuffs while peers stay clean, so multi-DoT spread lanes see
    -- primary-dotted + peer-undotted simultaneously. Previously `buffs_up`
    -- marked EVERY target dotted (deadlocking the spreads: primary-dot gate
    -- passes but find_dot_target sees the peer as already-dotted) and no
    -- scenario could set the primary's dot remains at all. Peers and
    -- map-less scenarios keep the buffs_up fallback unchanged, so Rupture /
    -- WintersChill / poison-stack consumers are byte-identical.
    ns.debuff_up = function(unit, ids)
        local map = ns._bstate("debuff_remains_map", nil)
        local prim = ns._bstate("primary_target", nil)
        ids = normalize_ids(ids)
        if unit == prim and type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return true end
            end
        end
        -- (b) close-out (2026-08-10): player-side debuff reads — SW:D CC break
        -- (offensive_dispel.is_breakable_cc_active(me, NS) → ns.debuff_up(me,
        -- id)) — consult the player-debuff map when the unit is the player
        -- (ns.me, published per scenario by apply_battery_state). The snare_self
        -- scenario uses player_debuff_remains_map { [122] = 5 }.
        if unit ~= nil and unit == ns.me then
            local pmap = ns._bstate("player_debuff_remains_map", nil)
            if type(pmap) == "table" then
                for _, id in ipairs(ids or {}) do
                    if pmap[id] ~= nil then return true end
                end
            end
        end
        if ns._bstate("buffs_up", false) then return true end
        return false
    end
    ns.debuff_remains = function(unit, ids)
        local map = ns._bstate("debuff_remains_map", nil)
        local prim = ns._bstate("primary_target", nil)
        ids = normalize_ids(ids)
        if unit == prim and type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return map[id] end
            end
        end
        -- (b) close-out (2026-08-10): player-side mirror of the debuff_up
        -- branch above (unit == ns.me → player_debuff_remains_map).
        if unit ~= nil and unit == ns.me then
            local pmap = ns._bstate("player_debuff_remains_map", nil)
            if type(pmap) == "table" then
                for _, id in ipairs(ids or {}) do
                    if pmap[id] ~= nil then return pmap[id] end
                end
            end
        end
        if ns._bstate("buffs_up", false) then return 20 end
        return 0
    end
    ns.has_player_buff = function(ids) return map_aware_buff(ids) end
    -- (c) close-out (2026-08-09): retribution Cleanse/Purify lanes read
    -- NS.has_player_debuff(COMMON_CLEANSE) (retribution:265-267); the early
    -- stub returned false always, so Ret_Cleanse_Self / Ret_Purify_SelfFallback
    -- / Ret_Cleanse_Ally were structurally dead. Map-aware over the new
    -- player_debuff_remains_map bank (scenario-driven); absent the map every
    -- caller keeps the legacy false. has_target_debuff mirrors it for
    -- unit_has_debuff(me) so find_ally can match the player when self is the
    -- debuffed unit (Cleanse_Ally falls back to me with no party members).
    ns.has_player_debuff = function(ids)
        local map = ns._bstate("player_debuff_remains_map", nil)
        ids = normalize_ids(ids)
        if type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return true end
            end
        end
        return false
    end
    ns.has_target_debuff = function(unit, ids)
        -- Cleanse_Ally's unit_has_debuff(me, ...) passes the PLAYER; reuse the
        -- player-debuff map so a self-afflicted scenario fires it (find_ally
        -- falls back to me when the battery presents no party members).
        return ns.has_player_debuff(ids)
    end
    -- Stealth helper (ranked #7): the real shared/stealth_helper_sylvanas
    -- caches `NS = _G.EaxRotations` at ITS first require() — the first spec
    -- that loads it (druid cat, run order) — so every later rogue spec's
    -- is_stealthed_for_class() read the FIRST spec's state bank, stale across
    -- specs and scenario-order-dependent (combat CheapShot/Garrote fired or
    -- not depending on which process/order ran). Stub it scenario-driven like
    -- fsr/ts_helper: has_player_buff is map-aware, so stealth maps to the
    -- current spec's own bank (stealth_opener's buff_remains_map [1784], or
    -- the buffs_up fallback). load_spec restores package.loaded afterwards.
    package.loaded["shared/stealth_helper_sylvanas"] = {
        STEALTH_BUFF_IDS = { 1787, 1786, 1785, 1784 },
        PROWL_BUFF_IDS = { 9913, 6783, 5215 },
        is_stealthed = function()
            return ns.has_player_buff({ 1787, 1786, 1785, 1784, 9913, 6783, 5215, 20580 })
        end,
        is_stealthed_for_class = function(class)
            local ids = class == "druid" and { 9913, 6783, 5215 } or { 1787, 1786, 1785, 1784 }
            return ns.has_player_buff(ids)
        end,
        try = function() return true end,
    }
    -- has_buff: map-only (NO buffs_up fallback) — holy's PrayerOfMending
    -- (holy_sylvanas.lua:786) and hunter BM Misdirection (beast_mastery:556)
    -- use it as an anti-overwrite gate. The fsr_pause scenario carries the PoM
    -- buff id (33076) so PoM (position 5, before FSRPause at 13) stops
    -- stealing the lane; every other scenario has no map entry so the return
    -- is false — byte-identical to the pre-map behavior. (No buffs_up fallback:
    -- unlike has_player_buff, these callers must NOT see "all buffs up" in
    -- buffs_up scenarios or Misdirection/PoM would silently stop firing there.)
    ns.has_buff = function(unit, ids)
        local map = ns._bstate("buff_remains_map", nil)
        if type(ids) == "number" then ids = { ids } end
        if type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return true end
            end
        end
        return false
    end
    ns.get_buff_stacks = function() if ns._bstate("buffs_up", false) then return 1 end return 0 end
    -- buff_stacks alias: shaman resto reads NS.buff_stacks for water/earth
    -- shield charges (water_shield_matches refreshes at 0 charges); without
    -- it charges read nil->0 and WaterShield fires before FSRPause even in
    -- buffs_up scenarios. Mirroring get_buff_stacks (1 when buffs_up) also
    -- keeps earth-shield refresh suppressed (remains 20 > 5 + charges 1).
    -- buff_stacks alias (enh LightningBolt maelstrom gate reads this with the
    -- MAELSTROM_WEAPON_BUFF ids): make it map-aware like buff_remains — a
    -- buff_remains_map entry for a queried id returns its stack value (the
    -- enh_procs scenario sets [53817] = 5), else the buffs_up fallback (1) to
    -- keep resto water/earth-shield reads byte-identical.
    ns.buff_stacks = function(unit, ids)
        local map = ns._bstate("buff_remains_map", nil)
        if type(ids) == "number" then ids = { ids } end
        if type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return map[id] end
            end
        end
        if ns._bstate("buffs_up", false) then return 1 end
        return 0
    end
    -- Scenario-driven debuff stacks (poison_stacks scenario). Scoped by aura
    -- ids so one spec's stacks never bleed into another (e.g. mage AB stacks /
    -- frost Winter's Chill must stay 0 when only deadly-poison stacks are set).
    ns.debuff_stacks = function(unit, ids)
        local v = ns._bstate("debuff_stacks", 0)
        if not (v and v > 0) then return 0 end
        -- Strict id-scoping: a scenario that raises stacks MUST carry the aura
        -- ids, otherwise unrelated readers (mage AB stacks, frost Winter's
        -- Chill) would spuriously see the value.
        local aura_ids = ns._bstate("debuff_aura_ids", nil)
        if type(aura_ids) ~= "table" or type(ids) ~= "table" then return 0 end
        for _, id in ipairs(ids) do
            for _, aid in ipairs(aura_ids) do
                if id == aid then return v end
            end
        end
        return 0
    end
    ns.get_debuff_stacks = ns.debuff_stacks
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
    -- Mock marker (survey item #2, require-time NS-caching fix): shared modules
    -- that bind their exports into _G.EaxRotations at require() time (e.g.
    -- auto_tremor, dot_refresh, purge_manager, mf_tick_compute) must NOT write
    -- into a mock NS — the mock is discarded after each battery load and any
    -- bindings are pure pollution (they'd shadow the real engine's bindings if
    -- the mock's table were ever cached by a later tool). All 8 write-back
    -- modules now gate on `not _G.EaxRotations._EAX_MOCK`, so a mock NS can
    -- never capture a module instance.
    ns._EAX_MOCK = true
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
    { name = "aoe",              overrides = { enemy_count = 4, enemies_count = 4, stance = 1 } },
    { name = "execute",          overrides = { target_hp = 8, ttd = 6, target_ttd = 6, on_cd = { [30330] = 6, [1680] = 10 } } },
    { name = "cd_pressure",      overrides = { on_cd = { [30356] = 6, [30357] = 5, [30330] = 6, [1680] = 10, [11585] = 1, [30335] = 6 } } },
    { name = "leveling_execute", overrides = { level = 25, player_level = 25, is_leveling = true, target_hp = 8, ttd = 6, target_ttd = 6 } },
    { name = "swing_window",     overrides = { swing_until = 1.0, on_cd = { [30330] = 6, [1680] = 10, [11585] = 1, [30335] = 6 } } },
    -- Primary-on-cooldown fillers (triage upgrade): prot Devastate/Rend/
    -- HeroicStrike gate on `ss_ready == false and revenge_ready == false`
    -- (ShieldSlam 30356 / Revenge 30357 on cd); stance=2 (defensive) matches
    -- live tanking and rage=100 clears the HS dump floor (default 70 == the
    -- HEROIC_STRIKE_RAGE_DUMP constant, a razor edge). Requires the
    -- WarriorSpells seed. (Devastate fires here: dev_ready true, ss/rev on CD.)
    { name = "prot_filler_cd",   overrides = { stance = 2, rage = 100, on_cd = { [30356] = 6, [30357] = 5 } } },
    -- Close-out ranked #1 (2026-08-08): SunderArmor's pre-Devastate fallback
    -- needs dev_ready false (prot:531) — Devastate {30022,...} on CD — PLUS
    -- ss_ready/revenge_ready false (prot:533) so the filler branch fires.
    -- NOT the not_learned map: it only gates spell_exists/is_spell_learned,
    -- while dev_ready comes from the cooldown-only spell_ready mock. The
    -- Devastate entry in the WarriorSpells seed makes the [30022] key
    -- resolvable by cooldown_remains (ids[1]). Devastate itself is silenced
    -- in THIS scenario only (dev_ready false) — harmless, it fires in
    -- prot_filler_cd and elsewhere.
    { name = "sunder_fallback",  overrides = { stance = 2, rage = 100, on_cd = { [30022] = 6, [30356] = 6, [30357] = 5 } } },
    -- Tank triage (ranked #6): elite classification (1) + an un-tanked target
    -- (target_get_target = false → target:get_target() nil) + visible
    -- un-tanked enemies (visible_enemies) make the smart-taunt lanes
    -- observable. Taunt needs Taunt ready; TauntSecondary needs Taunt on CD
    -- (355) + no_threat_target from the visible-objects scan + enemy_count ≥ 3.
    -- MockingBlow/ChallengingShout share the elite gates and clear here too.
    { name = "elite_target",   overrides = { target_classification = 1, enemy_count = 3, enemies_count = 3, target_get_target = false, visible_enemies = true } },
    { name = "elite_taunt_cd", overrides = { target_classification = 1, enemy_count = 3, enemies_count = 3, target_get_target = false, visible_enemies = true, on_cd = { [355] = 6 } } },
    -- Tank triage (last (c) item): prot IntimidatingShout needs min_enemies 3
    -- (protection:505 via s.enemy_count) AND state.hp <= 50 (matcher:825).
    -- elite_target has the 3 enemies but hp 100; low_self has hp 15 but 1
    -- enemy — only this combo clears it (and fires exclusively here: no other
    -- scenario combines enemy_count >= 3 with hp <= 50).
    -- NOTE: this is a SUPERSET of elite_target + low_self — low-self-gated
    -- prot lanes (e.g. HealthPotion) may also fire here even though they are
    -- pinned elsewhere; do NOT pin such a lane to this scenario.
    { name = "elite_low_self", overrides = { target_classification = 1, hp = 15, player_hp = 15, enemy_count = 3, enemies_count = 3 } },
    -- Ice Block (45438) on cooldown + low HP (triage upgrade): arcane/frost
    -- ColdSnap defensive lanes gate on `not spell_ready(IceBlock)` and hp <= 35.
    { name = "cold_snap_cd",     overrides = { on_cd = { [45438] = 60 }, hp = 15, player_hp = 15 } },
    { name = "low_mana",         overrides = { mana_pct = 10, player_mana = 300, player_mana_pct = 10, has_potions = true } },
    { name = "low_self",         overrides = { hp = 15, player_hp = 15, has_potions = true } },
    -- Mana emergency floor (healer triage upgrade): elemental/restoration
    -- default mana_emergency to strict `< 5` (MANA_EMERGENCY_DEFAULT=5) and
    -- holy's ManaBelow5Wand blocks at `>= 5`, so the scenario must set 4 — a
    -- 5 would leave all four wand lanes invisible. Unblocks ManaEmergencyWand
    -- x3 (elemental/enhancement/restoration) + holy ManaBelow5Wand.
    { name = "mana_critical",     overrides = { mana_pct = 4, player_mana = 120, player_mana_pct = 4 } },
    { name = "moving",           overrides = { is_moving = true } },
    { name = "target_casting",   overrides = { target_is_casting = true } },
    -- WotLK rogue Kick interrupt (2026-08-10): the three *_wotlk.lua rogue
    -- rotations gained a baseline Kick strategy (combat/subtlety/assassination
    -- had zero interrupt handling). It gates on in_combat + target_is_casting
    -- like arcane Counterspell; this scenario keeps it observable so the
    -- WotLK never=0 pin stays non-vacuous.
    { name = "wotlk_rogue_kick", overrides = { target_is_casting = true, target_cast_pct = 60 } },
    -- WotLK era-coverage close-out (2026-08-10): prot/fury Pummel, elemental
    -- EarthShock, shadow Silence — the remaining specs whose class siblings
    -- already interrupted (arms Pummel, rogue Kick, arcane Counterspell) but
    -- that had zero interrupt handling. Same gate, same dedicated scenario so
    -- the WotLK never=0 pin stays non-vacuous for the new strategies.
    { name = "wotlk_interrupts", overrides = { target_is_casting = true, target_cast_pct = 60 } },
    { name = "stealth",          overrides = { is_stealthed = true, combo_points = 0 } },
    -- Rogue stealth openers (ranked #7): combat Garrote needs stealth + a
    -- casting target; subtlety CheapShot needs stealth + the explicit
    -- opener_preference (auto resolves garrote-on-caster / ambush-elsewhere,
    -- so the pref is what isolates CheapShot). buff_remains_map [1784]
    -- (Stealth) is map-first, so no buffs_up fallback claims the lane.
    { name = "stealth_opener", overrides = { buff_remains_map = { [1784] = 10 }, target_is_casting = true, setting_overrides = { opener_preference = "cheap_shot" } } },
    -- PvP combo scenarios (warrior/rogue triage, 2026-08-08): the remaining
    -- rogue (b) lanes need ONE extra flag on top of an existing scenario.
    -- NOTE: the pvp_low_hp combo from the triage ({ is_pvp, hp = 15 }) is
    -- ALREADY satisfied by defensive_casting — combat/subtlety Blind cleared
    -- there and are exclusivity-pinned (fires-in(1)), so a separate scenario
    -- would only break that pin; do not add it.
    -- pvp_stealth_opener: assassin PvP_CheapShotOpen needs stealth_active
    -- (NS.has_player_buff(STEALTH_BUFF = {1787..1784}) — map-driven, so the
    -- is_stealthed bank key does NOT feed it) + is_pvp. The stealth_opener
    -- scenario has the stealth map but no is_pvp; `stealth`/`pvp` have one
    -- flag each. This is the only is_pvp + stealth-map combo. No
    -- target_is_casting / opener_preference, so the combat Garrote + subtlety
    -- CheapShot pins (stealth_opener exclusivity) are untouched.
    { name = "pvp_stealth_opener", overrides = { is_pvp = true, buff_remains_map = { [1784] = 10 } } },
    -- pvp_gap_close: assassin PvP_SprintGapClose needs is_pvp AND
    -- target_distance >= 15 (pvp = dist 5; gap_close = 15 but not pvp).
    -- This is the only is_pvp + range combo. Already-firing lanes that read
    -- dist >= 15 (subtlety sprint_gap, warrior Intercept) legitimately gain a
    -- fires-in here — never-list unchanged.
    { name = "pvp_gap_close",     overrides = { is_pvp = true, target_distance = 15 } },
    -- Rogue Preparation reset (ranked #8): subtlety's matcher needs
    -- state.hp <= 40 (subtlety_prep_hp default) AND a major CD burned
    -- (vanish_cd/sprint_cd/evasion_cd from state). vanish_cd derives from
    -- NS.get_spell_cd, now bank-aware; prep_ready puts Vanish on CD (1856,
    -- any rank) at low HP. Preparation fires ONLY here (no other scenario has
    -- a Vanish/Sprint/Evasion CD entry).
    { name = "prep_ready",   overrides = { hp = 15, player_hp = 15, on_cd = { [1856] = 60 } } },
    -- Alt/leveling lanes (ranked #9): the low_level scenario marks pre-level
    -- spells as NOT learned (not_learned map) so the leveling fallbacks become
    -- observable: arcane FireballLeveling/FrostboltLeveling (is_leveling +
    -- spell_exists(ArcaneBlast 30451) false), frost FrostArmor (MageArmor
    -- 27125/6117 not learned — pre-34 fallback), warlock demonology SummonImp
    -- (SummonFelguard 30146 not learned + Imp 688 learned, OOC, no pet).
    -- Every lane fires ONLY here (no other scenario sets is_leveling together
    -- with a not-learned entry; OOC no-pet lanes already exist).
    { name = "low_level",    overrides = { level = 20, player_level = 20, is_leveling = true, in_combat = false, not_learned = { [30451] = true, [27125] = true, [6117] = true, [30146] = true } }, no_pet = true },
    -- Phase 3 (2026-08-09): first batch of ranked (c) fixtures from the
    -- non-DPS triage — hunter Readiness x3, SerpentStingRefresh x2, holy
    -- ClearcastingGreaterHeal/SurgeOfLightSmite, elem moving shocks x2.
    --
    -- readiness_window: hunter Readiness (BM DSL + MM + survival) gates on
    -- `rapid_fire_cd >= 60` (state from safe_cooldown_remains(RapidFire 3045),
    -- which reads the bank-aware cooldown_remains mock). MM additionally needs
    -- ttd >= 20 (marksmanship:495). No other scenario puts 3045 on cd.
    { name = "readiness_window", overrides = { on_cd = { [3045] = 61 }, ttd = 60, target_ttd = 60 } },
    -- serpent_refresh: SerpentStingRefresh (BM + survival) gates on the
    -- serpent debuff being up with <= 3s remaining (hunter_core.sting_remains
    -- / NS.debuff_remains read the primary-target debuff_remains_map) plus a
    -- ttd floor (survival:420 needs ttd >= 6). [27016] is the max-rank
    -- Serpent Sting id in SERPENT_STING_DEBUFF {27016,...} (BM:44, MM:79,
    -- survival:87). The map is primary-target-scoped (debuff_up/remains check
    -- unit == primary_target), and the primary is ctx.target (line ~2059).
    { name = "serpent_refresh", overrides = { debuff_remains_map = { [27016] = 2 }, ttd = 30, target_ttd = 30 } },
    -- clearcast_surge: holy ClearcastingGreaterHeal + SurgeOfLightSmite read
    -- per-buff state via has_player_buff (HOLY_CONCENTRATION_BUFF {34753,...}
    -- / SURGE_OF_LIGHT_BUFF {33151,...}) — the all-or-nothing buffs_up can't
    -- express "one buff up". buff_remains_map is map-first, so this is the
    -- only scenario where those two are up. Default injured friends
    -- {55,70,85} satisfy both lanes' lowest_hp bands (GH < 95, surge >= 50).
    { name = "clearcast_surge", overrides = { buff_remains_map = { [34753] = 1, [33151] = 1 } } },
    -- elem_shock_moving: EarthShockMoving gates is_moving + the
    -- elemental_interrupt_reserve setting DEFAULT true (elemental:250) — the
    -- plain `moving` scenario leaves the reserve on, so this is the only
    -- scenario where the filler is legal while moving.
    { name = "elem_shock_moving", overrides = { is_moving = true, setting_overrides = { elemental_interrupt_reserve = false } } },
    -- elem_shock_pvp: FrostShockMoving gates is_moving AND is_pvp
    -- (elemental:255-256) — no single existing scenario combines both.
    { name = "elem_shock_pvp",    overrides = { is_moving = true, is_pvp = true } },
    { name = "buffs_up",         overrides = { buffs_up = true, combo_points = 0 } },
    { name = "pull",             overrides = { in_combat = false, buffs_up = true, is_stealthed = true, combo_points = 0 } },
    { name = "short_ttd",        overrides = { target_ttd = 2, ttd = 2, target_hp = 20, combo_points = 5, energy = 60 } },
    { name = "mid_ttd",          overrides = { target_ttd = 30, ttd = 30 } },
    { name = "long_ttd",         overrides = { target_ttd = 120, ttd = 120 } },
    { name = "pvp_interrupt",    overrides = { is_pvp = true, target_is_casting = true, combo_points = 3 } },
    { name = "berserker_interrupt", overrides = { stance = 3, target_is_casting = true } },
    { name = "potions_ready",    overrides = { has_potions = true } },
    { name = "friends_afflicted", overrides = { friends_afflicted = true, friends_hp = { 80, 90, 95 }, afflicted = { poison = true, disease = true, curse = true, magic = true } } },
    -- Healer group-damage scenarios (healer triage upgrade): friends_hp bands
    -- are tuned per lane family — group_light (62/72/85: GH + PreHeal + RenewTank),
    -- group_critical (30/45/60 + low self: BindingHeal + Emergency PWS),
    -- group_aoe (4 injured: PrayerOfHealing + CircleOfHealing + ChainHeal),
    -- group_healthy (100s: nobody injured → idle-DPS lanes fire),
    -- tank_low (entry[2] = tank at 30: disc PowerWordShieldTank + PainSuppression),
    -- mana_tide_window (healthy group + low mana: resto ManaTideTotem).
    { name = "group_healthy",   overrides = { friends_hp = { 100, 100, 100 }, friend_class = 11 } },
    -- Per-buff state (ranked #2): Light's Grace active at 1.5s remaining —
    -- paladin holy LightGraceChain gates on lights_grace_remains in (0, 2.5)
    -- (buff id 31834); the default injured group (55/70/85) satisfies the
    -- tank-deficit gate. General mechanism: any buff_remains_map entry.
    { name = "lights_grace",    overrides = { buff_remains_map = { [31834] = 1.5 } } },
    -- Seal-twist state (ranked #5): retri SealTwistBlood needs the Command seal
    -- up (buff 27170), no Blood seal, and swing <= twist window (0.45s);
    -- SealTwistPrepCommand needs the Blood seal up (31892), Judgement on CD
    -- > 1.5s (id 20271), and swing in (0.45, 1.2]. can_twist only flips on here
    -- (via setting_overrides) so both lanes stay silent in every other scenario.
    { name = "seal_twist_blood", overrides = { setting_overrides = { seal_twisting_enabled = true }, buff_remains_map = { [27170] = 5 }, swing_until = 0.4 } },
    { name = "seal_twist_prep",  overrides = { setting_overrides = { seal_twisting_enabled = true }, buff_remains_map = { [31892] = 5 }, swing_until = 0.9, on_cd = { [20271] = 2.0 } } },
    -- Friend class-id (ranked #4): the group scenarios present a healer ally
    -- (class 11) so druid/resto's innervate scan (is_healer_entry via
    -- unit_class_id -> get_class) can pick a non-self healer; mana_tide_window's
    -- low mana makes InnervateHealer fire. InnervateSelf stays observable via
    -- the non-group low-mana scenarios (low_mana/mana_critical), which keep
    -- friends class-less.
    { name = "group_light",     overrides = { friends_hp = { 62, 72, 85 }, friend_class = 11 } },
    { name = "group_critical",  overrides = { hp = 50, player_hp = 50, friends_hp = { 30, 45, 60 }, friend_class = 11 } },
    { name = "group_aoe",       overrides = { friends_hp = { 40, 55, 65, 75 }, friend_class = 11 } },
    { name = "tank_low",        overrides = { friends_hp = { 55, 30, 80 }, friend_class = 11 } },
    { name = "mana_tide_window", overrides = { friends_hp = { 100, 100, 100 }, mana_pct = 10, player_mana = 300, player_mana_pct = 10, friend_class = 11 } },
    -- FSR pause window (ranked #6): mid-Five-Second-Rule pause — inside FSR
    -- (fsr_inside), positive regen delta (fsr_regen_delta), healthy group
    -- (friends 100s so no triage heal fires first), mana 30 (<= the 35 gate
    -- but above the emergency floors). buffs_up=true is load-bearing: shaman
    -- WaterShield/LightningShield and paladin AuraManagement/BlessingRefresh
    -- all read "shield/aura already up" and would otherwise match before
    -- FSRPause. ManaTide (16190) + Innervate (29166) on cd — used in the
    -- window; without them ManaTideTotem (mana <= 60) / InnervateSelf /
    -- RebirthBattleRez (no dead-ally model — see report) steal the lane;
    -- Bloodlust (2825) fires on healthy groups. player_mana_pct drives holy's
    -- context.mana_pct (no NS.unit_mana_pct fallback — disc has one); the PoM
    -- buff id (33076) in the map blocks holy PrayerOfMending (position 5) via
    -- the map-aware ns.has_buff; holy_refresh_enabled/holy_blessing_light
    -- false block paladin BlessingRefresh + BlessingOfLightTank (blessings
    -- read "up" at exactly the 120s refresh boundary). buff_stacks (new)
    -- keeps shaman WaterShield from refreshing at 0 charges.
    -- Unblocks FSRPause x5 (holy/disc priest, holy paladin, resto
    -- druid/shaman) + retri Ret_JudgementWisdom_LowMana (incidental).
    { name = "fsr_pause",      overrides = { mana_pct = 30, player_mana_pct = 30, friends_hp = { 100, 100, 100 }, buffs_up = true, fsr_inside = true, fsr_seconds = 3.0, fsr_regen_delta = 20, fsr_pause_ok = true, buff_remains_map = { [33076] = 15 }, setting_overrides = { holy_refresh_enabled = false, holy_blessing_light = false }, on_cd = { [16190] = 60, [29166] = 60, [26994] = 60, [2825] = 600 } } },
    -- Emergency group + HoT buffs: druid resto SwiftmendEmergency /
    -- TranquilityEmergency (3 targets <= 25) / NaturesSwiftnessHealingTouch
    -- (buff present); NaturesSwiftness (buff absent) via group_critical's
    -- <= 30 target + short TTD.
    { name = "group_emergency", overrides = { buffs_up = true, friends_hp = { 18, 22, 24 } } },
    -- Pushback: enemy in range casting on the player. Unblocks the priest
    -- PreHeal lanes (disc + holy pre_heal_matches gate on _check_pushback,
    -- which scans NS.GetEnemiesInRange for a casting enemy). Tank band
    -- {62,72,85} puts entry[2] = 72 inside PreHeal's [60, 95] window.
    { name = "pushback",        overrides = { enemies_casting = true, target_is_casting = true, friends_hp = { 62, 72, 85 } } },
    -- Friendly target (ranked): NS.get_friendly_target_entry returns a
    -- friendly unit at 60% (below the 90 threshold) so the 5 healer
    -- FriendlyTarget lanes (disc + holy priest, holy paladin, resto druid +
    -- shaman) become observable. Group stays healthy so the spot-heal lanes
    -- don't steal the frame; hp must stay < 90 and > 0.
    { name = "friendly_target", overrides = { friendly_target_hp = 60, friends_hp = { 100, 100, 100 }, lowest_hp = 100 } },
    -- Healer (c) close-out (2026-08-09): the 13 TBC healer category-(c)
    -- never-lanes, mirroring the WotLK fixture campaign (battery fixtures
    -- only, no spec-file matcher changes). is_solo defaults true in the
    -- battery; holy solo-DPS lanes also need a healthy group so the
    -- solo_damage_enabled safe_hp gate (lowest < 88) can't veto them.
    { name = "holy_last_resort",       overrides = { friends_hp = { 10, 70, 85 } } },
    { name = "holy_jow_boss",          overrides = { target_hp = 100, buff_remains_map = { [20166] = 5 } } },
    { name = "holy_jol_boss",          overrides = { target_hp = 100, buff_remains_map = { [20165] = 5 } } },
    { name = "holy_solo_execute",      overrides = { target_hp = 8, friends_hp = { 96, 97, 98 } } },
    { name = "holy_solo_judge",        overrides = { buff_remains_map = { [20154] = 5 }, friends_hp = { 96, 97, 98 } } },
    { name = "holy_solo_aoe",          overrides = { enemy_count = 4, enemies_count = 4, friends_hp = { 96, 97, 98 } } },
    { name = "smite_solo_renew",       overrides = { hp = 15, player_hp = 15 } },
    { name = "shadow_holy_nova",       overrides = { setting_overrides = { shadow_combat_mode = "aoe" }, enemy_count = 4, enemies_count = 4 } },
    { name = "resto_lightning_shield", overrides = { setting_overrides = { restoration_shield_type = "lightning" } } },
    { name = "resto_chain_lightning",  overrides = { enemy_count = 4, enemies_count = 4, friends_hp = { 96, 97, 98 } } },
    { name = "resto_travel_reposition", overrides = { is_moving = true, in_combat = false, target_distance = 30 } },
    { name = "resto_lifebloom_bloom",  overrides = { friends_hp = { 100, 70, 85 }, lifebloom = { index = 1, stacks = 3, remains = 0.6 } } },
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
    -- Form scenarios (druid): cat/bear/moonkin/travel put the spec into the
    -- matching form so form-gated strategies become reachable.
    { name = "cat_form",            overrides = { form = 3, energy = 60, combo_points = 3 } },
    { name = "cat_form_5cp",        overrides = { form = 3, energy = 60, combo_points = 5 } },
    { name = "cat_form_low_energy", overrides = { form = 3, energy = 25, combo_points = 4, mana_pct = 30 } },
    { name = "cat_form_low_energy_5cp", overrides = { form = 3, energy = 25, combo_points = 5 } },
    { name = "cat_mangle_up",       overrides = { form = 3, energy = 80, combo_points = 2, buffs_up = true } },
    { name = "cat_stealth",         overrides = { form = 3, is_stealthed = true, combo_points = 0, in_combat = false, buffs_up = true } },
    { name = "cat_stealth_pvp",     overrides = { form = 3, is_stealthed = true, combo_points = 0, in_combat = false, is_pvp = true } },
    { name = "cat_burst",           overrides = { form = 3, should_burst = true, combat_time = 3 } },
    { name = "cat_short_ttd",       overrides = { form = 3, target_ttd = 2, ttd = 2, target_hp = 20, combo_points = 5, energy = 60 } },
    { name = "cat_execute",         overrides = { form = 3, target_hp = 15, ttd = 4, combo_points = 5, energy = 25, has_potions = true } },
    { name = "cat_emergency",       overrides = { form = 3, energy = 8, combo_points = 2, mana_pct = 40 } },
    { name = "cat_gap",             overrides = { form = 3, target_distance = 15, energy = 70 } },
    { name = "cat_2target",         overrides = { form = 3, enemy_count = 2, enemies_count = 2, energy = 70, combo_points = 3 } },
    { name = "cat_target_casting",  overrides = { form = 3, target_is_casting = true, energy = 60, combo_points = 3 } },
    { name = "cat_pvp_interrupt",   overrides = { form = 3, is_pvp = true, target_is_casting = true, energy = 60, combo_points = 3 } },
    { name = "pvp_ooc",             overrides = { in_combat = false, is_pvp = true } },
    { name = "bear_form",           overrides = { form = 1, rage = 50 } },
    { name = "bear_low_self",       overrides = { form = 1, rage = 60, hp = 15 } },
    { name = "bear_aoe",            overrides = { form = 1, rage = 60, enemy_count = 4, enemies_count = 4 } },
    { name = "moonkin_form",        overrides = { form = 2, mana_pct = 90 } },
    { name = "travel_form",         overrides = { form = 4, is_moving = true, in_combat = false, target_distance = 28 } },
    -- Enemy-buffed + PvP: purge / Shiv purge / Mass Dispel lanes.
    { name = "purge_buffed",        overrides = { enemy_buffed = true, is_pvp = true } },
    -- Dead pet, out of combat: Revive Pet / pet summon lanes.
    { name = "pet_dead_ooc",        overrides = { pet_hp = 0, pet_dead = true, in_combat = false }, no_target = true },
    -- No pet at all (never summoned): Call Pet / demon summoning lanes.
    { name = "pet_absent",          overrides = { in_combat = false }, no_target = true, no_pet = true },
    -- Destro pet-preference summons: SummonFelhunter/SummonVoidwalker/
    -- SummonFelguard only fire when destro_pet_preference is explicitly set to
    -- that pet (auto mode resolves to imp/succubus only). One scenario per
    -- pref so each lane is observable; no_target + in_combat=false match the
    -- OOC summon gates (dead/absent pet via pet_dead_ooc/pet_absent above).
    { name = "destro_pet_felhunter",  overrides = { in_combat = false, setting_overrides = { destro_pet_preference = "felhunter" } }, no_target = true, no_pet = true },
    { name = "destro_pet_voidwalker", overrides = { in_combat = false, setting_overrides = { destro_pet_preference = "voidwalker" } }, no_target = true, no_pet = true },
    { name = "destro_pet_felguard",   overrides = { in_combat = false, setting_overrides = { destro_pet_preference = "felguard" } }, no_target = true, no_pet = true },
    -- SummonSuccubus (the last (a) warlock lane): fires only when the pref is
    -- explicitly "succubus" (auto resolves to imp via the Incinerate-learned
    -- heuristic), so the succubus-pref scenario makes it observable.
    { name = "destro_pet_succubus",  overrides = { in_combat = false, setting_overrides = { destro_pet_preference = "succubus" } }, no_target = true, no_pet = true },
    -- Low rage: warrior executes / rage-gated finishers under pressure.
    { name = "low_rage",            overrides = { rage = 15 } },
    -- Burst windows: DamagePotion / cooldown lanes gated on should_burst.
    -- has_potions added (triage upgrade): DamagePotion lanes gate on
    -- context.has_damage_potion, which only has_potions=true sets — without it
    -- the potion lane was invisible in every spec (9 DamagePotion never-lanes).
    { name = "burst",               overrides = { should_burst = true, buffs_up = true, has_potions = true } },
    -- Gap close: warrior Charge / Intercept / sprint lanes need range.
    { name = "gap_close",           overrides = { target_distance = 15 } },
    { name = "berserker_gap",       overrides = { stance = 3, target_distance = 15 } },
    { name = "pull_gap",            overrides = { in_combat = false, target_distance = 15 } },
    -- Triage battery upgrades (2026-08-07): scenario COMBINATIONS the battery
    -- could not previously express — stance+execute (Recklessness), defensive+
    -- low-HP (ShieldWall), rage-capped (RageDumpSafetyNet), poison-stack
    -- (Envenom lanes), berserker+AoE (fury BattleStance), and melee-range
    -- targets (keeps me:get_distance-bound FrostNova/ConeOfCold reachable).
    { name = "berserker_execute",   overrides = { stance = 3, target_hp = 8, ttd = 6, target_ttd = 6 } },
    -- Recklessness (fury) refuses to fire below 20s TTD AND before 60s combat
    -- without a major-CD window — needs berserker + LONG fight, not execute.
    { name = "berserker_long",      overrides = { stance = 3, combat_time = 90, ttd = 60, target_ttd = 60 } },
    { name = "defensive_low_self",  overrides = { stance = 2, hp = 15 } },
    -- Close-out triage (2026-08-08, ranked #2): prot Disarm needs is_pvp
    -- (ACTIONS requires_pvp) + disarm_class_ok (target:get_class() melee id
    -- in DISARM_CLASS_IDS {1,2,4,7} — class 1 = warrior). The matcher's
    -- on_burst trigger needs disarm_burst_name (via enemy_buffed), so we use
    -- the cheaper `disarm_trigger = "always"` setting override instead — this
    -- avoids enemy_buffed entirely, so no purge-buffed lane collateral (the
    -- purge_buffed scenario keeps its exclusivity). target_class is only
    -- applied here, so warlock ShadowWard (needs 5/9) and hunter ViperSting
    -- middleware stay silent in every other scenario.
    { name = "pvp_disarm", overrides = { is_pvp = true, target_class = 1, setting_overrides = { disarm_trigger = "always" } } },
    -- Campaign ranked-(b) #1 (2026-08-08): warlock ShadowWard (affl + demo)
    -- needs hp <= shadow_ward_hp (default 70) + a shadow-caster target class
    -- in SHADOW_CASTER_CLASS_IDS {5,9} = Priest, Warlock
    -- (shared/warlock_shadow_ward_sylvanas.lua pcall's target:get_class()
    -- when enemy_shadow_caster is unset) + is_pvp for affliction's
    -- use_group_aware gate (demo skips it). Reuses the pvp_disarm
    -- target_class -> target:get_class() mechanism; class 9 is NOT in prot
    -- DISARM_CLASS_IDS {1,2,4,7}, so Disarm stays blocked here, and hunter
    -- ViperSting's string-class guard skips numeric ids.
    { name = "shadow_caster", overrides = { is_pvp = true, target_class = 9, hp = 50, player_hp = 50 } },
    -- Campaign follow-up (2026-08-08): shaman/enhancement TotemicCall. The
    -- real get_position contract is a vec3 TABLE (verified vs auto_loot /
    -- targeting / EaxESP), so the matcher's my_pos.x reads are CORRECT; the
    -- battery path needs a totem present (totem_active -> get_totem_info
    -- have_totem) + a distant totem object in the visible scan (totem_far ->
    -- mock at 30,30 = 1800 sq > 400 yd-sq gate).
    { name = "totem_far",     overrides = { totem_active = true, totem_far = true, visible_enemies = true } },
    -- Close-out triage (2026-08-08, ranked #3): prot Intervene needs is_group
    -- (protection:757) + is_pvp (warrior_intervene_pvp_only default true) + a
    -- low-hp in-range ally via the party scan (state.lowest_allied from
    -- get_party_members). The party stub presents the _friend(30, 5) ally only
    -- here (party_low_ally flag), so no other spec's party reads change; the
    -- me + ally get_position multi-value mocks satisfy the 25-yard range gate.
    { name = "group_ally_low", overrides = { is_group = true, is_pvp = true, party_low_ally = true, friend_hp = 30 } },
    -- Defensive-casting PvP (warrior/rogue triage 2026-08-08): prot Pummel +
    -- SpellReflection read state.target_is_casting, which prot derives from
    -- target:is_casting_spell() (wired in build_scenario_target — arms reads
    -- ctx.target_is_casting, so only prot was blocked). SpellReflection's
    -- ACTIONS metadata is requires_pvp = true, so the scenario carries is_pvp
    -- (a tank reflecting under spell pressure); stance 2 + hp 15 mirror the
    -- defensive_low_self family. The is_pvp + hp flags incidentally clear
    -- rogue combat/subtlety Blind (hp 15 ≤ combat_blind_hp 40 / subtlety 35) —
    -- the pvp_low_hp combo from the triage, same gate family, not a leak.
    { name = "defensive_casting", overrides = { stance = 2, target_is_casting = true, hp = 15, player_hp = 15, is_pvp = true } },
    { name = "rage_capped",         overrides = { rage = 100 } },
    { name = "poison_stacks",       overrides = { debuff_stacks = 5, debuff_aura_ids = { 27187, 27186, 26968, 26967, 25349, 25347, 11356, 11355, 11354, 11353, 11352, 11351, 11350, 11349, 2819, 2837, 2818, 2835 }, buffs_up = true, combo_points = 5, energy = 60 } },
    { name = "berserker_aoe",       overrides = { stance = 3, enemy_count = 4, enemies_count = 4 } },
    -- Melee-range target: keeps me:get_distance-bound self-peel lanes reachable
    -- (mage FrostNova / ConeOfCold need dist<=10 AND the AoE cone gate needs
    -- enemy_count>=2, so this carries both).
    { name = "target_melee",        overrides = { target_distance = 5, enemy_count = 3, enemies_count = 3 } },
    -- Undead target (healer triage upgrade): creature-type 6 (undead) + 2
    -- enemies. Unblocks the ShackleUndead x4 (priest), TurnEvil x2,
    -- Exorcism + HolyWrath (prot), and Ret_HolyWrath_AoE lanes — all gate on
    -- state.target_creature_type in DEMON_OR_UNDEAD {3,6}; the HolyWrath lanes
    -- additionally need enemy_count >= 2. (Docs labeled this "classification=3";
    -- the specs read get_creature_type, and undead is 6.)
    { name = "undead_target",      overrides = { target_creature_type = 6, enemy_count = 2, enemies_count = 2, setting_overrides = { use_exorcism = true } } },
    -- Multi-DoT spread (ranked #1): the PRIMARY target carries the DoTs
    -- (debuff_remains_map → unit-aware debuff_up/debuff_remains) while the
    -- second enemy is clean, so warlock find_dot_target / shadow
    -- _find_multidot_target / balance _multidot_enemy_list pick the peer.
    -- ttd 30 selects Curse of Agony in auto curse mode (select_curse: ttd < 60
    -- → agony). balance spreads share this via balance_multidot_enabled.
    { name = "multidot",         overrides = { enemy_count = 2, enemies_count = 2, target_hp = 60, ttd = 30, target_ttd = 30, debuff_remains_map = { [27216] = 8, [27218] = 8, [30405] = 8, [30911] = 8, [27215] = 8, [26988] = 8, [27013] = 8 }, setting_overrides = { balance_multidot_enabled = true } } },
    -- shadow MultiDot maintenance (opt-in shadow_multidot_mode=2 via the
    -- settings fixture) — primary has SW:P/VT, peer is clean.
    { name = "shadow_multidot",  overrides = { enemy_count = 2, enemies_count = 2, target_hp = 60, debuff_remains_map = { [25368] = 8, [34917] = 8 }, setting_overrides = { shadow_multidot_mode = 2 } } },
    -- shadow cleave-mode SW:P/VT spread (shadow_combat_mode="cleave" + 3
    -- enemies — the Spread matchers require enemy_count >= 3).
    { name = "shadow_cleave",    overrides = { enemy_count = 3, enemies_count = 3, target_hp = 60, debuff_remains_map = { [25368] = 8, [34917] = 8 }, setting_overrides = { shadow_combat_mode = "cleave" } } },
    -- Low-mana Wand (ranked #3): warlock/affliction Wand fires only when mana
    -- < 30 AND hp < 35 (Life Tap unsafe) AND in_combat — no prior scenario
    -- combined all three. mana_pct 4 (< aff_wand_mana 30), hp 15 (<
    -- LIFE_TAP_SAFETY_HP 35). hp 100 correctly keeps it blocked (prefer Life
    -- Tap → Shadow Bolt), so the lane stays exclusive to this scenario.
    { name = "wand_low_mana",   overrides = { mana_pct = 4, hp = 15 } },
    -- AB-stack conserve (ranked #4): mage/arcane FrostboltConserve fires when
    -- phase == conserve AND ab_stacks >= 3 AND ab_remains > cast_time (~1.0).
    -- ab_stacks reads NS.debuff_stacks(me, ARCANE_BLAST_DEBUFF = {36032, 36033,
    -- 36034}) → scenario debuff_stacks 4 + those aura ids (id-scoped so mage
    -- AB stacks can't leak into rogue poison stacks); ab_remains reads
    -- NS.debuff_remains → buffs_up fallback 20. mana_pct 15 keeps phase
    -- conserve: with the ranked-#2 bank max_mana (15000), mtte_burn ≈ 14 ≥ 5
    -- AND buffs_up=true sets bloodlust_active=true, whose burn-override needs
    -- mana_pct >= 20 — 15 stays under both, so can_burn stays false and the
    -- phase never flips to burn (mana 15 >= 10 also avoids the emergency
    -- branch, and FrostboltConserve has no mana gate).
    { name = "ab_stack_conserve", overrides = { mana_pct = 15, buffs_up = true, debuff_stacks = 4, debuff_aura_ids = { 36032, 36033, 36034 } } },
    -- Battle-ready SnD (ranked #5): rogue/combat BladeFlurry needs Slice and
    -- Dice up (SND_BUFF {6774, 5171}) while Blade Flurry itself is DOWN
    -- (13877) — the map-aware ns.buff_up reads buff_remains_map so the two
    -- are independently observable. 3 enemies satisfies the min_targets gate
    -- (combat_blade_flurry_count default 1); cooldowns_enabled defaults true.
    { name = "battle_ready",    overrides = { buff_remains_map = { [6774] = 20, [5171] = 20 }, enemy_count = 3, enemies_count = 3 } },
    -- Settings-modeling (ranked #7): opt-in (a) lanes become observable by
    -- flipping their spec settings via the ctx.settings merge above. Each key
    -- is spec-scoped so shared scenarios never leak into other specs.
    -- auto_dispel: druid balance/cat RemoveCurse (balance reads
    -- ctx.settings.balance_auto_dispel DIRECTLY; cat via cat_auto_dispel).
    { name = "auto_dispel",      overrides = { setting_overrides = { balance_auto_dispel = true, cat_auto_dispel = true } } },
    -- blessings: retri Ret_BlessingKings_Self/Party (both default false); the
    -- party lane's find_ally falls back to self in the battery (candidate_members
    -- returns a number, not a table, so no party scan happens).
    { name = "blessings",        overrides = { setting_overrides = { blessing_of_kings_self = true, blessing_of_kings_party = true } } },
    -- Pre-classified (a) opt-in lanes (focused triage 2026-08-08, warrior/rogue
    -- pass): each previously never-firing lane is gated on a spec setting PLUS
    -- a state the battery's default context can't express. One scenario per
    -- lane, keys spec-scoped so nothing leaks across specs.
    -- fury Overpower: setting + BT/WW on CD (matcher delays when bt_cd/ww_cd
    -- < 1.5 — default context has both at 0, so the lane could never fire even
    -- with the setting flipped). on_cd ids are ACTION.Bloodthirst.ids[1]
    -- (30335) and ACTION.Whirlwind (1680); Battle stance + rage 70 are the
    -- defaults.
    { name = "fury_overpower",  overrides = { setting_overrides = { fury_overpower_weave = true }, on_cd = { [30335] = 6, [1680] = 10 } } },
    -- fury SwingDesync: setting + swing_until >= DESYNC_SLAM_WINDOW (1.6);
    -- default swing 0.5 < 1.6 blocks it. 2.0 also clears the bt/ww reserve +
    -- rage-cap windows (rage 70 default, no on_cd).
    { name = "fury_swing_desync", overrides = { setting_overrides = { fury_swing_desync = true }, swing_until = 2.0 } },
    -- kebab SunderMaintain: setting (read DIRECTLY from ctx.settings by
    -- kebab's settings_for) + defensive stance (matcher requires
    -- context.stance == DEFENSIVE; default battle 1 blocks it).
    { name = "kebab_sunder",    overrides = { setting_overrides = { sunder_armor_mode = "maintain" }, stance = 2 } },
    -- assn ColdBloodEnvenom: setting + SnD up + 5 deadly-poison stacks
    -- (debuff_aura_ids scoped) + combo 5 / energy 60. SnD must be up while
    -- Cold Blood is NOT (matcher: `if state.has_cold_blood then return false`)
    -- — so the buff_remains_map carries ONLY the SnD ids (6774/5171) and
    -- buffs_up stays false, otherwise Cold Blood looks already-active.
    -- combat_blade_flurry_count = 99 keeps combat's BladeFlurry (whose gate
    -- ALSO reads SnD up via the same 6774/5171 ids) exclusive to battle_ready
    -- — target_count 1 < 99 blocks it here; assassin never reads that key.
    { name = "cold_blood",      overrides = { setting_overrides = { assassin_cold_blood_auto = true, combat_blade_flurry_count = 99 }, buff_remains_map = { [6774] = 20, [5171] = 20 }, debuff_stacks = 5, debuff_aura_ids = { 27187, 27186, 26968, 26967, 25349, 25347, 11356, 11355, 11354, 11353, 11352, 11351, 11350, 11349, 2819, 2837, 2818, 2835 }, combo_points = 5, energy = 60 } },
    -- assn ThistleTea: setting + energy <= 40 + combo <= 3 (energy_low shape;
    -- the setting alone flips it on, verified match=true in energy_low).
    { name = "thistle_tea",     overrides = { setting_overrides = { assassin_thistle_tea = true }, energy = 30, combo_points = 0 } },
    -- hit_cap_deficit: the HitCapPriority lanes (combat/arms/fury — identical
    -- matcher: state.hit_cap_rating_needed - context.hit_rating, fires when
    -- the deficit exceeds 30) need a non-nil hit_rating. Caps: melee specs 142
    -- (hunter_ranged/paladin_melee also 142); mage_caster is 202 — still
    -- clears at rating 50 (deficit 152 > 30).
    { name = "hit_cap_deficit", overrides = { hit_rating = 50 } },
    -- mutilate_daggers: assassin Mutilate's has_daggers needs a dagger in BOTH
    -- hands (assn:234-240 reads get_equipped_item_id for MAIN_HAND/OFF_HAND +
    -- the is_dagger map). equipped_daggers=true makes the mock return 776 for
    -- both slots; energy 90 default keeps energy_low false (cost 60 gate).
    { name = "mutilate_daggers", overrides = { equipped_daggers = true } },
    -- Remaining (a) opt-in gates (2026-08-08 close-out): four scenarios clear
    -- the last 6 opt-in lanes. Keys are spec-scoped (arms reads
    -- use_sunder_armor; fury reads sunder_mode; arms+prot read
    -- use_commanding_shout; combat/subtlety read their own expose key).
    -- arms SunderArmor ALSO needs DEFENSIVE stance (its build_action has
    -- required_stance = STANCE.DEFENSIVE — battle-stance default blocks it
    -- even with the setting); prot SunderArmor is unaffected (dev_ready gate,
    -- no use_sunder_armor read).
    { name = "arms_sunder",     overrides = { setting_overrides = { use_sunder_armor = true }, stance = 2 } },
    -- fury SunderArmor: sunder_mode "maintain" (default "off" blocks;
    -- "maintain" has no rage gate — the "low" branch requires rage >= 60,
    -- which rage 70 would satisfy anyway; min_rage 15 build_action passes).
    { name = "fury_sunder",     overrides = { setting_overrides = { sunder_mode = "maintain" } } },
    -- CommandingShout x2: arms (matcher: setting + rage >= 10, battle stance
    -- fine) and prot (DSL `{ type = "setting" }` condition — evaluated via
    -- spec_kit.setting, which reads ctx.settings first; has_commanding_shout /
    -- has_battle_shout falsy defaults + commanding_ready true all pass).
    { name = "commanding_shout", overrides = { setting_overrides = { use_commanding_shout = true } } },
    -- ExposeArmor x2: combat (expose_armor_ready true via spell_ready +
    -- expose_assigned from combat_expose_assigned) + subtlety (setting + combo
    -- 5 default >= 4 + ttd 60 default >= 20 + no sunder).
    { name = "expose_armor",    overrides = { setting_overrides = { combat_expose_assigned = true, subtlety_expose_assigned = true } } },
    -- Warlock opt-in fixture (ranked #11): the 9 CurseOf* lanes are gated on
    -- select_curse() which only returns elements/recklessness/weakness when
    -- warlock_curse_mode is set to that value (auto mode resolves to
    -- agony/doom). One scenario per mode so each lane is observable; the mode
    -- key is warlock-scoped so no other spec reads it. All 9 probe-verified
    -- to fire with the mode override.
    { name = "curse_mode_elements",     overrides = { setting_overrides = { warlock_curse_mode = "elements" } } },
    { name = "curse_mode_recklessness", overrides = { setting_overrides = { warlock_curse_mode = "recklessness" } } },
    { name = "curse_mode_weakness",     overrides = { setting_overrides = { warlock_curse_mode = "weakness" } } },
    -- Warlock Healthstone (affl/demo/destro, shared warlock_healthstone
    -- helper): the matcher gates on healthstone_hp > 0 AND hp <= threshold
    -- (default 0 -> never). hp 25 + healthstone_hp 40 makes all three
    -- observable; probe-verified. (low_self hp 15 already exists; this adds
    -- the warlock-specific threshold setting.)
    { name = "low_self_healthstone", overrides = { hp = 25, setting_overrides = { healthstone_hp = 40 } } },
    -- High-threat context (ranked #12): Soulshatter (shared
    -- warlock_soulshatter helper) gates on `(threat_pct or 0) >= 80` OR
    -- `has_aggro`; priest Fade (threshold 80) and rogue Feint (90) are the
    -- same threat-drop family and may legitimately clear too (realistic —
    -- they were only invisible because the battery never set threat).
    -- hunter FeignDeath reads state.threat_level via hunter_core, so it does
    -- NOT clear from these ctx keys (verified below).
    { name = "threat_high", overrides = { threat_pct = 95, threat_status = 3, has_aggro = true } },
    -- Retri seal choice = "command" (seal_preference drives should_use_blood →
    -- preferred_damage_seal): Ret_SealCommand_Primary fires when the Command
    -- seal is ABSENT; Ret_HotC_Opener_Judge needs the Crusader seal up (map
    -- 27158) with combat_time < 8 and no Crusader debuff on the target.
    { name = "seal_command_apply", overrides = { setting_overrides = { seal_preference = "command" }, buff_remains_map = { [27158] = 5 }, combat_time = 3 } },
    -- Command seal ACTIVE + a second melee enemy (context.enemies fixture):
    -- Ret_JudgeSecondary_CommandCleave (swing in the judge band, mana >= 30).
    { name = "seal_command_active", overrides = { setting_overrides = { seal_preference = "command" }, buff_remains_map = { [27170] = 5 }, swing_until = 0.9, enemy_count = 2, enemies_count = 2, mana_pct = 40 } },
    -- Hunter toggles: AdaptiveRotation x3 (use_adaptive_rotation + the
    -- NS.HunterAdaptive stub), Volley + ExplosiveTrap (use_volley /
    -- use_explosive_trap; 4 enemies for the AoE gates).
    { name = "hunter_toggles",   overrides = { setting_overrides = { use_adaptive_rotation = true, use_volley = true, use_explosive_trap = true }, enemy_count = 4, enemies_count = 4 } },
    -- Arcane burn phase (ranked #2): the battery's get_max_power now returns
    -- the bank max_mana (15000 default) so mage/arcane's burn phase is
    -- mathematically reachable (mtte_burn ≈ 50.6 ≥ 5). can_burn additionally
    -- needs available_mana ≥ burn_mana_needed = 760·ttd/1.5 = 30400 at ttd 60;
    -- available = current_mana + (regen+49)·ttd/2 = 45000 + 1470 → the
    -- scenarios drive current_mana via player_mana 45000 (base ctx defaults
    -- player_mana 100 → available 1570 < 30400 → can_burn stays false in
    -- every other scenario, so phase stays conserve there). ArcanePower
    -- (12042) on cd makes PresenceOfMind's ap_on_cd sync gate pass; IcyVeins
    -- NOT on cd so its own lane fires. Unblocks ArcanePower + PresenceOfMind
    -- + IcyVeins. NOTE: kept LAST in SCENARIOS — arcane's build_state
    -- mutates a module-level phase that carries across scenarios (real engine
    -- semantics: phase is a state machine), so placing the burn scenarios
    -- after hunter_toggles means no later scenario inherits a leaked burn
    -- phase. (buffs_up scenarios like burst also reach burn via the
    -- bloodlust_active override — realistic, not a leak.)
    { name = "burn_ready",      overrides = { player_mana = 45000, mana_pct = 100, ttd = 60, target_ttd = 60, on_cd = { [12042] = 180 } } },
    -- Burn + IcyVeins (12472) on cd > 3s: ColdSnapIVReset fires (its matcher
    -- needs icy_veins_remains > 3 AND ColdSnap ready); IcyVeins itself
    -- self-blocks here (its matcher requires IV not on cd), so each lane
    -- stays exclusive to its own scenario.
    { name = "burn_coldsnap",   overrides = { player_mana = 45000, mana_pct = 100, ttd = 60, target_ttd = 60, on_cd = { [12042] = 180, [12472] = 180 } } },
    -- =========================================================================
    -- WotLK Phase-1 triage (2026-08-09): the 38 remaining never-lanes after the
    -- resource/cooldown accessor fixes (149 -> 65 -> 38). ALL 38 are (c) mock/
    -- shape gaps — zero (d) dead lanes and zero order divergences, so no spec
    -- file changes; these scenarios + the DK stub upgrades clear the lanes.
    -- =========================================================================
    -- DK runic power (runic_power >= 60 DancingRuneWeapon blood; >= 100
    -- DeathCoil unholy). Base ctx defaults runic_power 50 — one flag short.
    { name = "dk_runic",        overrides = { runic_power = 100 } },
    -- DK unholy SummonGargoyle: is_boss truthy AND runic_power >= 60. is_boss
    -- is a new bank key (ctx.is_boss); runic_power rides the same flag as
    -- dk_runic. (Gargoyle is a boss-target DPS CD — realistic shape.)
    { name = "dk_boss",         overrides = { is_boss = true, runic_power = 100 } },
    -- DK disease refresh (Pestilence x3 — blood/unholy/leveling): all three
    -- gate on frost_fever_remains > 0 AND blood_plague_remains > 0 with one
    -- below 3s (blood/unholy) or diseases_up (leveling: ff>0 or bp>0). The
    -- debuff_remains_map mechanism (frost fever 55095, blood plague 55078)
    -- marks the primary target. NOTE: the DK files install the REAL
    -- aoe_hit_volume (leveling/unholy Pestilence gate on aoe_target_meets(2)),
    -- which overrides the battery's always-true stub — its ctx fallback
    -- consults enemy_count/enemies_count, so the scenario must carry 2+ real
    -- enemies or the spread lane stays 0. Blood's Pestilence (no aoe gate)
    -- clears from the disease map alone.
    { name = "dk_disease",      overrides = { debuff_remains_map = { [55095] = 1, [55078] = 1 }, enemy_count = 3, enemies_count = 3 } },
    -- DK EmpowerRuneWeapon x2 (frost + unholy): both gate on total runes ready
    -- == 0; the rune bank defaults 2/2/2/0 (6 total), so an all-zero ready map
    -- is the only shape where the CD fires. rune_state is a new bank key
    -- consumed by the rune_manager stub getters.
    { name = "dk_runes_depleted", overrides = { rune_state = { ready = { blood = 0, frost = 0, unholy = 0, death = 0 } } } },
    -- DK presence switch x3 (blood Presence, unholy Presence, frost
    -- FrostPresence): all go through presence_manager.get_optimal_presence /
    -- should_switch_presence. optimal_presence is a new bank key; with it set
    -- and no presence buff up (state.presence nil/1), each lane fires here.
    { name = "dk_presence",     overrides = { optimal_presence = "blood" } },
    -- Druid leveling feral opt-in: CatForm gates on druid_leveling_feral=true
    -- (and druid_leveling_bear=false, the default) + in_combat + form ~= cat.
    -- The settings fixture makes this opt-in lane observable (mirrors the TBC
    -- (a) close-out: use_sunder_armor etc.).
    { name = "lvl_feral",       overrides = { setting_overrides = { druid_leveling_feral = true } } },
    -- Druid leveling bear opt-in: DireBearForm gates on druid_leveling_bear
    -- = true + in_combat + form ~= bear.
    { name = "lvl_bear",        overrides = { setting_overrides = { druid_leveling_bear = true } } },
    -- Druid leveling cat abilities x6 (Rip/FerociousBite/Rake/MangleCat/
    -- Shred/Claw): all gate `form == "cat"` (STRING — leveling_wotlk compares
    -- strings, unlike the numeric form ids TBC specs use). The battery context
    -- passes ctx.form through verbatim, so a string override lands in
    -- state.form and the string gates match. combo_points 4 satisfies both the
    -- >= 4 finishers (Rip/FerociousBite) and < 5 builders (MangleCat/Shred/
    -- Claw) — default 5 blocks the builders, default 0 blocks the finishers.
    { name = "lvl_cat_form",    overrides = { form = "cat", combo_points = 4 } },
    -- Druid leveling bear abilities x3 (Swipe/Lacerate/MangleBear): form ==
    -- "bear" string; Swipe additionally needs enemy_count >= 2.
    { name = "lvl_bear_form",   overrides = { form = "bear", enemy_count = 3, enemies_count = 3 } },
    -- Druid resto Swiftmend: target_hp < 50 AND (rejuvenation_remains > 0 or
    -- regrowth_remains > 0). Rejuv id 26982 (first in REJUVENATION_BUFF) in
    -- the buff_remains_map marks the primary target as carrying the HoT;
    -- target_hp 30 satisfies the low-health gate. (buffs_up=false elsewhere so
    -- the lane stays silent in every other scenario.)
    { name = "resto_swiftmend", overrides = { target_hp = 30, buff_remains_map = { [26982] = 1 } } },
    -- Hunter survival ExplosiveShotProc: lock_and_load truthy (proc flag —
    -- new bank key, ctx.lock_and_load). No other scenario sets it.
    { name = "surv_lockload",   overrides = { lock_and_load = true } },
    -- Mage fire FireBlast (scorch-window weave): gates on scorch_cast_time > 0
    -- (number) AND state.ttd <= cast_time. scorch_cast_time is a new bank key;
    -- ttd 2 <= cast_time 3 makes the lane fire (base ttd 60 > 3 blocks it
    -- everywhere else). FireBlast is a real weaving lane, not a dead one.
    { name = "fire_scorch",     overrides = { scorch_cast_time = 3, ttd = 2, target_ttd = 2 } },
    -- Mage leveling ConjureManaGem: in_combat falsy + mana_pct < 80. The
    -- existing out_of_combat scenario has mana_pct 100 (never < 80); this is
    -- the OOC + low-mana combo (like low_mana but OOC — low_mana keeps
    -- in_combat=true, and the lane requires falsy).
    { name = "ooc_low_mana",    overrides = { in_combat = false, mana_pct = 70 } },
    -- Priest leveling Shadowform opt-in: eaxpriestlvl_use_shadowform=true +
    -- in_combat falsy + shadowform_up falsy. Settings fixture, like lvl_feral.
    { name = "lvl_shadowform",  overrides = { in_combat = false, setting_overrides = { eaxpriestlvl_use_shadowform = true } } },
    -- Shaman ready flags x4 (elem Bloodlust + ElementalMastery + FireElemental,
    -- enh Bloodlust): all gate on ctx.bloodlust_ready / elemental_mastery_ready
    -- / fire_elemental_ready, which the base ctx leaves false. One scenario
    -- with all three set clears the four lanes (elem + enh share bloodlust).
    { name = "shaman_ready",    overrides = { bloodlust_ready = true, elemental_mastery_ready = true, fire_elemental_ready = true } },
    -- Shaman enh totem/proc lanes x2: CallOfTheElements gates water_totem_remains
    -- < 20 (base 300); LightningBolt gates maelstrom_stacks >= 5 — enh reads
    -- NS.buff_stacks(me, MAELSTROM_WEAPON_BUFF {53817,..}), which is
    -- buff_remains_map-aware, so the map entry [53817] = 5 supplies the stacks
    -- (buffs_up=false elsewhere keeps the lane silent). water_totem_remains is
    -- a ctx/bank key read directly by build_state.
    { name = "enh_procs",       overrides = { water_totem_remains = 5, buff_remains_map = { [53817] = 5 } } },
    -- Shaman resto triage x2: ChainHeal needs injured_count >= 2 + lowest_hp
    -- < 85 + mana >= 25; ManaTideTotem needs mana_tide_ready + mana < 30. One
    -- scenario satisfies both: mana 27 (>= 25 and < 30), 2 injured, lowest_hp
    -- 50. injured_count/mana_tide_ready are new bank keys.
    { name = "resto_triage",    overrides = { injured_count = 2, lowest_hp = 50, mana_pct = 27, mana_tide_ready = true } },

    -- (c) close-out batch 2 (2026-08-09): the 18 remaining TBC (c) lanes.
    -- druid/balance: HurricaneAoE (aoe + mana + Barkskin active so the
    -- ready-Barkskin deferral gate passes); RebirthBattleRez (dead player
    -- ally via find_dead_party_ally).
    { name = "hurricane_aoe",   overrides = { enemy_count = 4, enemies_count = 4, mana_pct = 60, buff_remains_map = { [22812] = 10 } } },
    { name = "rebirth_dead_ally", overrides = { in_combat = true, dead_ally = true } },
    -- druid/bear: Swipe (aoe + rage + short TTD so the Lacerate pre-stack gate
    -- passes); EnrageCombat (rage-starved, non-boss, single target).
    { name = "bear_swipe_aoe",  overrides = { form = 1, in_combat = true, enemy_count = 4, enemies_count = 4, rage = 40, ttd = 5 } },
    { name = "bear_enrage",     overrides = { form = 1, in_combat = true, rage = 10, hp = 100, enemy_count = 1, ttd = 60 } },
    -- druid/cat: ClawFallback (Mangle unlearned); MangleFiller (not behind so
    -- the Shred-preference gate passes).
    { name = "cat_claw_fallback", overrides = { form = 3, combo_points = 0, energy = 60, not_learned = { [33983] = true } } },
    { name = "cat_mangle_filler", overrides = { form = 3, combo_points = 0, energy = 60, is_behind = false } },
    -- hunter: BM Trinket (combat + equipped trinket + slot1 mode); MM
    -- InCombatAimedShot (fresh-combat opener, no Serpent Sting).
    { name = "bm_trinket",      overrides = { in_combat = true, has_trinket = true, setting_overrides = { trinket_mode = "slot1" } } },
    { name = "mm_aimed_opener", overrides = { in_combat = true, combat_time = 0.2 } },
    -- paladin/protection: AvengingWrath (use_cooldowns enabled, ttd above the
    -- 15s expiry gate); LayOnHands (self below the 10% threshold).
    { name = "prot_cd_window",  overrides = { in_combat = true, ttd = 60, setting_overrides = { use_cooldowns = true } } },
    { name = "prot_low_self",   overrides = { in_combat = true, hp = 5, player_hp = 5 } },
    -- paladin/retribution: cleanse/purify self + ally (player-debuff map).
    { name = "ret_cleanse_self", overrides = { player_debuff_remains_map = { [1330] = 5 } } },
    -- shaman/elemental: ChainHeal (group injured); ElementalMastery (burst
    -- window + enabled); TotemicCall (moving + totems up).
    { name = "elem_group_injured", overrides = { in_combat = true, group_injured = true } },
    { name = "elem_burst_cd",   overrides = { in_combat = true, should_burst = true, setting_overrides = { elemental_use_elemental_mastery = true } } },
    { name = "elem_totemic_call", overrides = { in_combat = true, is_moving = true, has_totems = true } },
    -- shaman/enhancement: EarthShock interrupt (target casting in the kick
    -- window); ShamanisticRage (low mana defensive use + the per-CD toggle
    -- setting enabled — the DSL condition requires it, the battery settings
    -- fixture defaults to unset).
    { name = "enh_interrupt",   overrides = { in_combat = true, target_is_casting = true, target_cast_pct = 60 } },
    { name = "enh_low_mana",    overrides = { in_combat = true, mana_pct = 30, player_mana_pct = 30, ttd = 60, setting_overrides = { enhancement_cd_shamanistic_rage = true } } },

    -- (a) opt-in close-out (2026-08-10): the 14 remaining TBC category-(a)
    -- never-lanes are ALL gated on spec settings the battery's
    -- setting_overrides fixture can drive (plus a few state shapes). One
    -- scenario per lane, keys spec-scoped so nothing leaks across specs.
    -- druid/balance MoonkinForm: setting + OUT of combat (DSL
    -- `{ type = "in_combat", invert = true }` at balance:695) + spell ready.
    -- NOTE: named moonkin_form_OPTIN — a pre-existing `moonkin_form`
    -- scenario (form=2, mana_pct=90) already exists for the form-sync
    -- scenarios; build_scenario returns the FIRST match, so reusing the
    -- name would silently shadow this one.
    { name = "moonkin_form_optin", overrides = { in_combat = false, setting_overrides = { balance_moonkin_auto = true } } },
    -- druid/bear Barkskin: setting + in combat + NOT bear form (TBC: casting
    -- it in bear breaks the form) + hp in (15, barkskin_hp=55] (15 reserved
    -- for Frenzied Regen) + no barkskin buff.
    { name = "bear_barkskin",   overrides = { in_combat = true, form = 0, hp = 40, player_hp = 40, setting_overrides = { bear_use_barkskin = true } } },
    -- druid/cat RipTrick: cat_use_rip_trick + would_rip_fire (ttd >= floor) +
    -- is_cat + mana >= 8 + combo >= 1 + rip NOT up + energy in the
    -- [RIP_COST=30, MANGLE_COST=40) window (energy 35 sits inside; next tick
    -- 55 exceeds the Mangle floor, so only the current-window branch passes).
    { name = "cat_rip_trick",   overrides = { in_combat = true, form = 3, combo_points = 1, energy = 35, mana_pct = 50, ttd = 30, target_ttd = 30, setting_overrides = { cat_use_rip_trick = true } } },
    -- druid/cat ShredTrick: cat_use_shred_trick + is_cat + behind + a bleed
    -- up (rip map 27008 -> bleed_active) + mana >= 16 + energy >= SHRED_COST
    -- (42; 80 leaves 58 >= MANGLE_COST after a tick) + next_tick_in > 1.0
    -- (energy_time_to_x 2.0, see _scenario_me) + combo < 5.
    { name = "cat_shred_trick", overrides = { in_combat = true, form = 3, is_behind = true, combo_points = 2, energy = 80, mana_pct = 50, debuff_remains_map = { [27008] = 8 }, energy_time_to_x = 2.0, setting_overrides = { cat_use_shred_trick = true } } },
    -- mage/frost x3: pure setting toggles (frost:400/432/440 read
    -- context.settings.<key> == true directly).
    { name = "frost_fire_blast",   overrides = { setting_overrides = { frost_use_fire_blast = true } } },
    { name = "frost_scorch",       overrides = { setting_overrides = { frost_use_scorch = true } } },
    { name = "frost_arcane_missiles", overrides = { setting_overrides = { frost_use_arcane_missiles = true } } },
    -- paladin/protection AvengerShield: setting + avenger_ready (spell_ready
    -- stub) + no CC nearby + normal in-combat mode (has_valid_enemy_target +
    -- in_combat, both base defaults).
    { name = "prot_avenger_shield", overrides = { in_combat = true, setting_overrides = { prot_avenger_shield = true } } },
    -- paladin/protection HammerOfWrath (DSL): prot_hammer_of_wrath + ready +
    -- target_hp <= prot_hammer_of_wrath_hp (default 20).
    { name = "prot_hammer_wrath",   overrides = { target_hp = 15, ttd = 30, target_ttd = 30, setting_overrides = { prot_hammer_of_wrath = true } } },
    -- paladin/protection Judgement: prot_judgement + ready + damage mode
    -- needs a damage seal up (Seal of Righteousness buff 27155 -> has_seal;
    -- mana 100 > jow_threshold+5 so wisdom mode is off).
    { name = "prot_judgement",      overrides = { buff_remains_map = { [27155] = 30 }, setting_overrides = { prot_judgement = true } } },
    -- paladin/protection SealOfCommandAoE: prot_seal_of_command + 3+ enemies
    -- + no seal up (no buff map) + spell ready + 3s throttle (module-local
    -- stamp starts 0; battery now 100 -> passes).
    { name = "prot_seal_command",   overrides = { enemy_count = 4, enemies_count = 4, setting_overrides = { prot_seal_of_command = true } } },
    -- paladin/retribution Consecration: use_consecration + not twist-window
    -- + not mana_emergency + mana >= 35 + 3+ enemies (aoe_self_meets stub).
    { name = "ret_consecration",    overrides = { enemy_count = 4, enemies_count = 4, mana_pct = 60, setting_overrides = { use_consecration = true } } },
    -- paladin/retribution Ret_Consecration_ManaDump: consecration_single_target
    -- + not mana_emergency + mana >= 75 (single-target; no enemy gate).
    { name = "ret_consec_dump",     overrides = { mana_pct = 80, setting_overrides = { consecration_single_target = true } } },
    -- shaman/enhancement GraceOfAirTotemTwist: totem_twisting (default true)
    -- + in combat + not moving + gcd 0 + mana >= 40 + GoA ready + WF buff up
    -- (25587 > 2.0) + GoA buff expiring (25359 < 5.0) + no recent GoA cast
    -- (battery now_ms 100000 >> 1500ms window).
    { name = "enh_goa_twist",       overrides = { in_combat = true, mana_pct = 60, buff_remains_map = { [25587] = 4, [25359] = 4 } } },
    -- (b) close-out (2026-08-10): PvP mega-scenario. is_pvp + melee_on_you +
    -- enemy_healer + enemy_caster + cc_target + target_fleeing + a low-hp
    -- fleeing target drive the 9 PvP-gated lanes (balance Cyclone /
    -- EntanglingRoots / NaturesGrasp, affliction HowlOfTerror / CurseExhaustion
    -- / CurseTongues, retribution HammerWrath_FleeingPvP, arcane + fire
    -- Polymorph via cc_target).
    { name = "pvp_melee",          overrides = { is_pvp = true, melee_on_you = true, enemy_healer = true, enemy_caster = true, cc_target = true, target_fleeing = true, target_hp = 15 } },
    -- Resto PvP pressure: enemies_in_range feeds ns.GetEnemiesInRange so
    -- scan_pvp_pressure fills melee_pressure_count / enemy_healer / root_target
    -- → BearFormFocusedByMelee, NaturesGraspMelee, CycloneEnemyHealer,
    -- EntanglingRootsMelee.
    { name = "pvp_pressure_resto", overrides = { is_pvp = true, hp = 30, enemies_in_range = { melee = 1, healer = 1 } } },
    -- Fear tremor: fear_nearby drives TremorTotem in elemental/enhancement/
    -- restoration (each reads context.fear_nearby).
    { name = "fear_nearby",        overrides = { fear_nearby = true } },
    -- Snare: self_rooted_snared + a root-snare player debuff (122 ∈ COMMON_SNARES)
    -- drive Blink ×2, retribution BlessingOfFreedom Self + Ally, holy
    -- BlessingOfFreedomSnare (entry_needs_freedom → has_any_debuff → the
    -- player-debuff map via has_target_debuff fallback to me).
    { name = "snare_self",         overrides = { self_rooted_snared = true, player_debuff_remains_map = { [122] = 5 }, snared_friend = true } },
    -- SW:D CC break: a damage-breakable CC on the player (Polymorph 118 ∈
    -- BREAKABLE_CC_DEBUFFS) drives the has_breakable_cc fallback path of
    -- swd_cc_break_matches (offensive_dispel.is_breakable_cc_active →
    -- ns.debuff_up → debuff_remains_map).
    { name = "shadow_cc_break",    overrides = { player_debuff_remains_map = { [118] = 5 } } },
    -- BM Misdirection: opening-seconds window (combat_time ≤ 6) + the
    -- use_misdirection setting.
    { name = "bm_misdirection",    overrides = { combat_time = 2, setting_overrides = { use_misdirection = true } } },
    -- Bear Challenging Roar: dedicated toggle (bear_use_challenging_roar) +
    -- 3+ enemies (bear:610-616).
    { name = "bear_challenging_roar", overrides = { form = 1, enemy_count = 4, enemies_count = 4, setting_overrides = { bear_use_challenging_roar = true } } },
    -- Enh AutoAttack: the battery's is_auto_attacking stub defaults true
    -- (legacy posture); flip it so the lane's `not auto-attacking` gate passes.
    { name = "enh_autoattack",     overrides = { is_auto_attacking = false } },
    -- Demo Seduction: succubus pet (has_pet) with Lash of Pain 27274 known
    -- (pet_spells) + PvP. Starshards needs no scenario: the per-spec
    -- RACE_OVERRIDES loads smite as night elf (race 4), so it fires in the
    -- standard scenarios.
    { name = "pvp_succubus",       overrides = { is_pvp = true, has_pet = true, pet_spells = { 27274 } } },
    -- Threat-family close-out (2026-08-10): bear Growl needs a target-of-target
    -- unit that is a player/healer (target.get_target defaults to ctx.me → the
    -- already-tanking gate always blocks); now > TAUNT_COOLDOWN_WINDOW (8) so
    -- the throttle passes (state.now defaults 0 → 0 - 0 < 8 always throttles).
    { name = "bear_growl",         overrides = { form = 1, now = 1000, target_get_target = _friend(50, 30, nil, { role = "healer" }) } },
    -- prot peel: one party ally that is BOTH low-HP (<=35 → low_hp_ally, BoP)
    -- AND threatened (threat_status >= 2 → ally_threatened, RighteousDefense);
    -- target_classification feeds RighteousDefense's elite gate.
    { name = "prot_party_peel",    overrides = { target_classification = 1, party_members = { _friend(30, 5, nil, { threat_status = 2 }) } } },
    -- holy BoP focused-ally: heal-scan entry hp <= 38 + threat_status >= 2
    -- (entry_needs_protection holy:326-333) → protection_target set.
    { name = "holy_bop_focused",   overrides = { friends_hp = { 30, 70, 85 }, friendly_target_threat = 2 } },
    -- BM FeignDeath: fd_mode defaults "off" (use_threat_drop off); the setting
    -- override flips it so should_feign_death(threat 2, "high_threat") passes.
    { name = "bm_feign_death",     overrides = { threat_level = 2, setting_overrides = { fd_mode = "high_threat" } } },
    -- shadow DevouringPlague: NOT race-gated — the (b) audit's race-5-load
    -- claim was wrong (shadow never binds race at require time; only smite
    -- does). The real gate is _engaged_with_player (shadow:743-754), which
    -- needs target_hp < 100. No RACE_OVERRIDES extension needed.
    { name = "shadow_devouring_plague", overrides = { target_hp = 80 } },
}

-- Scenario-aware player unit: every health/power read reflects the CURRENT
-- scenario numeric values instead of fixed 100s.
local function _scenario_me(profile, ctx)
    local me = _me_unit(profile.class_id or 0)
    me.get_health_percentage = function(self) return ctx.hp or 100 end
    me.get_health = function(self) return (ctx.hp or 100) * 100 end
    me.get_mana_percentage = function(self) return ctx.mana_pct or 100 end
    me.is_in_combat = function(self) return ctx.in_combat == true end
    me.get_shapeshift_form_id = function(self)
        -- Coerce string forms (leveling_wotlk scenarios pass form="cat"/"bear")
        -- to 0 (caster) so numeric form-id consumers never see a string.
        local f = ctx.form
        return type(f) == "number" and f or 0
    end
    me.is_moving = function(self) return ctx.is_moving == true end
    me.get_power = function(self, p)
        if p == M.POWER.COMBO then return ctx.combo_points or 5 end
        if p == M.POWER.ENERGY then return ctx.energy or 100 end
        if p == M.POWER.RAGE then return ctx.rage or 70 end
        if p == M.POWER.FOCUS then return ctx.focus or 90 end
        if p == M.POWER.MANA then return ctx.player_mana or ctx.mana_pct or 100 end
        return 100
    end
    -- (a) opt-in close-out (2026-08-10): cat ShredTrick gates on
    -- state.next_tick_in > 1.0 (cat:1143), which derives from
    -- me:energy_time_to_x (cat:543). The legacy mock hardwired 0.4 (inside
    -- the pooling window), so the lane could never fire even with the
    -- cat_use_shred_trick setting on. Scenario-overridable via the
    -- energy_time_to_x ctx key (mirrors the batch-2 target_cast_pct stub);
    -- default 0.4 preserves every existing scenario's energy shape.
    me.energy_time_to_x = function(self, v) return ctx.energy_time_to_x or 0.4 end
    -- (b) close-out (2026-08-10): demo Seduction needs a live succubus pet
    -- (demonology:198-228: me:has_pet() + me:get_pet() + pet:is_valid/alive +
    -- pet spells). The pvp_succubus scenario sets has_pet; other scenarios
    -- keep the legacy no-pet posture (nil from get_pet → scan skipped).
    me.has_pet = function(self) return ctx.has_pet == true end
    me.get_pet = function(self)
        if not ctx.has_pet then return nil end
        return {
            is_valid = function() return true end,
            is_alive = function() return true end,
            is_dead = function() return false end,
            get_health_percentage = function() return 100 end,
        }
    end
    -- Arcane burn phase (ranked #2): the battery previously hardwired
    -- get_max_power to 100, so mage/arcane s.max_mana = 100 → mtte_burn ≈ 0.3
    -- < 5 → should_conserve always true → phase could never become "burn" and
    -- ArcanePower/PresenceOfMind/IcyVeins/ColdSnapIVReset could never fire.
    -- Realistic 15000 pool (scenario-overridable via `max_mana`) makes the
    -- burn phase reachable (mtte_burn ≈ 50.6 ≥ 5; can_burn needs a big
    -- current_mana, driven by the burn scenarios' player_mana 45000).
    -- Non-MANA power types (energy/rage/focus/combo) keep the legacy 100 so
    -- cat's ENERGY_CAP read and warrior rage math are unchanged.
    me.get_max_power = function(self, p)
        if p == M.POWER.MANA then -- M.POWER.MANA == 0 (power type 0 = mana)
            return ctx.max_mana or 15000
        end
        return 100
    end
    me.is_casting = function(self) return ctx.me_casting == true end
    me.is_channeling = function(self) return ctx.me_casting == true end
    -- Pet accessors (warlock specs read me:has_pet() / me:get_pet() directly;
    -- the NS-level pet binding alone left the whole warlock pet lane invisible).
    me.has_pet = function(self) return ctx.pet ~= nil and not (ctx.pet_dead == true) end
    me.get_pet = function(self) return ctx.pet end
    -- Range/stance reads bound to the scenario context (triage upgrade):
    -- me:get_distance() reflects ctx.target_distance so gap/melee gates see a
    -- realistic range instead of a hardwired 5 (unblocks mage Slow, makes
    -- FrostNova/ConeOfCold range-gated); get_player_stance reflects ctx.stance
    -- (warrior stance scenarios, druid form-as-stance).
    me.get_distance = function(self, t) return ctx.target_distance or ctx.target_range or 5 end
    me.get_player_stance = function(self) return ctx.stance or 0 end
    me.get_stance = function(self) return ctx.stance or 0 end
    -- WotLK era resource accessors (Phase 1 triage): the 41 *_wotlk.lua
    -- files resolve `local me = NS.me or NS.GetPlayer()` and read rage /
    -- energy / combo points / runic power DIRECTLY off the player unit, while
    -- TBC-era files read context.rage / ns.rage() etc. (bank-driven). Without
    -- these, every WotLK resource read fell back to 0 — warrior arms 18/19,
    -- fury 5/6, protection 6/6, rogue 4+5+8+3, cat 7/8, DK lanes all dead.
    me.get_rage = function(self) return ctx.rage or 70 end
    me.get_energy = function(self) return ctx.energy or 100 end
    me.get_combo_points = function(self) return ctx.combo_points or 5 end
    me.get_runic_power = function(self) return ctx.runic_power or 50 end
    return me
end

-- Scenario-aware target clone: HP reflects target_hp, casting reflects
-- target_is_casting, and get_target() reports the player (engaged target).
-- In PvP scenarios the target IS a player unit (unlocks Shiv purge player
-- checks, garrote/cheap-shot openers, PvP-only gates).
local function build_scenario_target(ctx)
    local target = _target()
    target.get_health_percentage = function(self) return ctx.target_hp or 100 end
    target.get_health = function(self) return (ctx.target_hp or 100) * 100 end
    target.is_casting = function(self) return ctx.target_is_casting == true end
    target.is_channeling = function(self) return ctx.target_is_casting == true end
    -- (c) close-out (2026-08-09, batch 2): enh EarthShock interrupt mode reads
    -- target:get_cast_pct() (enhancement:459-462) and gates on
    -- kick_min_pct..kick_max_pct (40..80 default). The legacy mock had no
    -- get_cast_pct, so cast_pct stayed 0 and the lane could never fire even
    -- with target_is_casting=true. Scenario-overridable via target_cast_pct;
    -- default 60 sits inside the kick window when the target is casting.
    target.get_cast_pct = function(self) return ctx.target_cast_pct or 60 end
    -- Defensive-casting (warrior/rogue triage 2026-08-08): prot build_state
    -- derives state.target_is_casting from target:is_casting_spell()
    -- (protection_sylvanas.lua:310) while arms reads ctx.target_is_casting —
    -- that's why arms/fury Pummel fired in berserker_interrupt but prot
    -- Pummel/SpellReflection never could. Wire the same ctx flag here (the
    -- scenario target is built AFTER the overrides merge, so
    -- ctx.target_is_casting is final). Only prot + warrior middleware read
    -- is_casting_spell on the TARGET (affliction/demonology read the PET's,
    -- which has no method — unaffected), so collateral is confined to prot.
    target.is_casting_spell = function(self) return ctx.target_is_casting == true end
    -- get_target() reports the player (engaged target) unless the scenario
    -- overrides it: the elite_target/elite_taunt_cd scenarios set
    -- target_get_target = false ("nobody is currently being attacked") so
    -- Taunt's already-tanking gate passes (ranked #6). Default stays ctx.me.
    target.get_target = function(self)
        if ctx.target_get_target == false then return nil end
        return ctx.target_get_target or ctx.me
    end
    target.is_player = function(self) return ctx.is_pvp == true end
    -- get_class (close-out triage 2026-08-08): prot Disarm's disarm_class_ok
    -- (protection:358) pcall's target:get_class() and needs a melee class id
    -- in DISARM_CLASS_IDS {1,2,4,7}. Absent by default (mirrors the
    -- friend_class pattern) so no other get_class consumer changes — warlock
    -- ShadowWard wants {5,9}, and hunter ViperSting middleware only checks the
    -- class when `type(class_key) == "string"` (numeric ids skip that guard),
    -- so both stay untouched. Bonus: a future target_class = 5/9 scenario
    -- would make warlock ShadowWard observable with zero new wiring.
    if type(ctx.target_class) == "number" then
        target.get_class = function(self) return ctx.target_class end
    end
    -- Creature type reflects the scenario (undead_target scenario sets 6) so
    -- the ShackleUndead / TurnEvil / HolyWrath / Exorcism lanes are observable.
    -- NOTE: undead is creature-type 6 (WoW enum), not 3 — 3 is DEMON; the
    -- specs' DEMON_OR_UNDEAD / UNDEAD_OR_DEMON tables accept {3, 6}.
    target.get_creature_type = function(self) return ctx.target_creature_type or 7 end
    -- kebab build_state derives context.in_melee_range from target:is_in_melee_range();
    -- without it the DemoShout/melee gates always read false in the battery.
    target.is_in_melee_range = function(self) return (ctx.target_distance or ctx.target_range or 5) <= 5 end
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
        enemy_buffed=true, me_casting=true, on_cd=true, swing_until=true, afflicted=true,
        form=true, target_distance=true, should_burst=true,
        debuff_stacks=true, debuff_aura_ids=true, combat_time=true,
        target_creature_type=true, enemies_casting=true, buff_remains_map=true,
        debuff_remains_map=true, not_learned=true,
        -- (c) close-out (2026-08-09, batch 2): cat MangleFiller reads
        -- context.is_behind (cat:514) so the battery target's always-true
        -- is_behind no longer blocks it; elem ChainHeal reads context.
        -- group_injured; elem TotemicCall reads context.has_totems; enh
        -- EarthShock reads target:get_cast_pct() via the scenario target;
        -- ret cleanse reads player_debuff_remains_map via has_player_debuff;
        -- balance Rebirth reads dead_ally via find_dead_party_ally; BM Trinket
        -- reads has_trinket via TrinketManager.get_equipped_trinkets.
        is_behind=true, group_injured=true, has_totems=true, target_cast_pct=true,
        player_debuff_remains_map=true, dead_ally=true, has_trinket=true,
        friend_class=true, setting_overrides=true,
        -- (a) opt-in close-out (2026-08-10): cat ShredTrick's next_tick_in
        -- gate reads me:energy_time_to_x; scenario-overridable (default 0.4).
        energy_time_to_x=true,
        -- Healer (c) close-out (2026-08-09): lifebloom feeds the heal-scan
        -- stub's Lifebloom let-bloom fields (resto druid LifebloomLetBloom).
        lifebloom=true,
        fsr_inside=true, fsr_seconds=true, fsr_regen_delta=true, fsr_pause_ok=true,
        -- Friendly-target context (ranked): friendly_target_hp presents a
        -- friendly unit via NS.get_friendly_target_entry so the 5 healer
        -- FriendlyTarget lanes (disc + holy priest, holy paladin, resto druid
        -- + shaman) become observable; it is the unit's pct (must be < the 90
        -- threshold). No separate boolean — the hp presence is the signal.
        friendly_target_hp=true, friendly_target_threat=true,
        max_mana=true,
        -- Threat context (ranked #12): high-threat scenarios make the threat-
        -- drop lanes (Soulshatter, priest Fade, rogue Feint) observable. These
        -- keys feed ctx.threat_pct / ctx.has_aggro / ctx.threat_status reads;
        -- lanes like hunter FeignDeath read state.threat_level instead (via
        -- hunter_core.should_feign_death) so they stay silent here.
        -- threat_level is currently forward-looking (no battery lane reads
        -- ctx.threat_level yet — hunter uses state.threat_level).
        threat_pct=true, threat_status=true, has_aggro=true, threat_level=true,
        -- Elite-target context (ranked #6): target_classification feeds the
        -- smart-taunt matchers (warrior Taunt/TauntSecondary/MockingBlow,
        -- paladin RighteousDefense, druid cat rip-elite gate); target_get_target
        -- models an un-tanked target (false = nobody). visible_enemies is
        -- consumed directly in build_context_for (mock unit list, not a scalar).
        target_classification=true, target_get_target=true,
        -- Close-out triage (2026-08-08): target_class feeds the scenario
        -- target's get_class (prot Disarm disarm_class_ok gate); only prot
        -- reads it, so it stays scoped.
        target_class=true,
        -- Close-out triage (2026-08-08, ranked #3): is_group drives prot
        -- Intervene's group gate (protection:757) and party_low_ally presents
        -- a low-hp ally through get_party_members so the party scan populates
        -- lowest_allied. Both are prot-scoped reads.
        is_group=true, party_low_ally=true, friend_hp=true,
        -- Threat-family close-out (2026-08-10): party_members / group_members
        -- present the ally scan for prot's peel lanes (protection:566 reads
        -- context.party_members OR context.group_members directly); now feeds
        -- bear build_state's clock so Growl's taunt throttle passes.
        party_members=true, group_members=true, now=true,
        -- Stat/weapon mocks (2026-08-08 focused triage): hit_rating feeds the
        -- HitCapPriority matchers (combat/arms/fury read context.hit_rating and
        -- gate on deficit = hit_cap_rating_needed - hit_rating > 30 — default
        -- ctx has no rating so they could never fire); equipped_daggers feeds
        -- the dagger mock above for assassin Mutilate.
        hit_rating=true, equipped_daggers=true,
        -- Totemic Call (2026-08-08): totem_active drives the
        -- core.spell_book.get_totem_info stub (has_totem gate); totem_far
        -- appends a distant totem mock to the visible-objects scan. Both are
        -- shaman/enhancement-scoped reads.
        totem_active=true, totem_far=true,
        -- WotLK Phase-1 triage (2026-08-09): resource/state banks for the
        -- *_wotlk.lua specs. runic_power feeds the DK rune stub (DancingRune
        -- Weapon >= 60 / DeathCoil >= 100); rune_state drives the rune bank
        -- (dk_runes_depleted → EmpowerRuneWeapon); is_boss gates unholy
        -- SummonGargoyle; optimal_presence drives the presence stub
        -- (dk_presence → blood/unholy Presence + frost FrostPresence);
        -- lock_and_load gates survival ExplosiveShotProc; scorch_cast_time
        -- + ttd unlock fire FireBlast's scorch-window gate; bloodlust_ready /
        -- elemental_mastery_ready / fire_elemental_ready drive the shaman
        -- ready flags; water_totem_remains + maelstrom_stacks gate enh
        -- CallOfTheElements / LightningBolt; injured_count + mana_tide_ready
        -- gate resto ChainHeal / ManaTideTotem; diseases/ff-bp remain handled
        -- by the existing debuff_remains_map (dk_disease scenario).
        runic_power=true, rune_state=true, is_boss=true, optimal_presence=true,
        lock_and_load=true, scorch_cast_time=true,
        bloodlust_ready=true, elemental_mastery_ready=true,
        fire_elemental_ready=true, water_totem_remains=true,
        maelstrom_stacks=true, injured_count=true, mana_tide_ready=true,
        -- (b) close-out (2026-08-10): PvP/situational fixture keys. is_pvp /
        -- combat_time / player_debuff_remains_map / setting_overrides already
        -- whitelisted; these add the remaining ctx reads (balance/affliction
        -- PvP lanes, ret fleeing, mage polymorph cc_target, snare self-root,
        -- shaman tremor) and the stub-driven banks (enemies_in_range,
        -- is_auto_attacking, pet_spells, has_pet).
        melee_on_you=true, enemy_healer=true, enemy_caster=true, cc_target=true,
        target_fleeing=true, target_is_fleeing=true, self_rooted_snared=true,
        fear_nearby=true, enemies_in_range=true, is_auto_attacking=true,
        pet_spells=true, has_pet=true, snared_friend=true,
    }
    for k, v in pairs(overrides) do
        if k == "friends_hp" then
            ctx.friends_hp = v
        elseif k == "has_potions" then
            ctx.has_health_potion = true
            ctx.has_mana_potion = true
            ctx.has_damage_potion = true
            ctx.has_potions = true
        elseif known[k] then
            ctx[k] = v
        end
    end
    -- Settings-modeling fixture (ranked #7): merge setting_overrides into
    -- ctx.settings so ALL read channels see them — direct `ctx.settings[key]`
    -- reads (balance RemoveCurse, hunter AdaptiveRotation via
    -- NS.setting_bool), spec_kit.setting/setting_bool (context.settings is
    -- FIRST in the resolution chain), and the DSL `{ type = "setting" }`
    -- condition evaluator (spec_kit.setting). The scenario-aware
    -- ns.get_setting/get_any_setting stubs remain the fallback for callers
    -- that pass the ctx directly. Keys are spec-scoped, so an override never
    -- leaks into another spec's gates.
    if type(overrides.setting_overrides) == "table" then
        for k, v in pairs(overrides.setting_overrides) do
            ctx.settings[k] = v
        end
    end
    if ctx.target_distance then ctx.target_range = ctx.target_distance end
    -- Warriors start in Battle Stance (1); stance scenarios flip it.
    if class_key == "warrior" and ctx.stance == 0 then ctx.stance = 1 end
    -- Druids: stance IS form (bear=1, moonkin=2, cat=3, travel=4). Keep them
    -- in sync so shared scenarios that set stance (e.g. aoe→1) can't make a
    -- druid spec believe it is in bear form, and NUMERIC form scenarios
    -- actually flip stance-based checks. String forms ("cat"/"bear") are
    -- only consumed by leveling_wotlk via context.form and must NOT leak into
    -- ctx.stance — TBC druid files compare stance against numeric STANCE
    -- constants (bear_sylvanas:376, cat_sylvanas:737), and a string would
    -- silently read as 'not in form' (or crash on arithmetic if ever added).
    if class_key == "druid" and type(ctx.form) == "number" then
        ctx.stance = ctx.form
    end
    -- Scenario-aware player + target
    ctx.me = _scenario_me(profile, ctx)
    ctx.target = build_scenario_target(ctx)
    -- (b) close-out (2026-08-10): mage Polymorph reads context.cc_target and
    -- calls cc_t.is_cc() on it — a boolean scenario value crashes the matcher
    -- (attempt to index a boolean). Present a real unit: default to the
    -- scenario target so the PvP mega-scenario's cc_target=true resolves to a
    -- CC-able unit (is_cc absent → the SDK skip-gate is bypassed, which is the
    -- permissive-mock posture everywhere else).
    if ctx.cc_target == true then
        ctx.cc_target = ctx.target or build_scenario_target(ctx)
    end
    if scenario.no_target then
        ctx.target = nil
        ctx.has_target = false
        ctx.has_valid_enemy_target = false
        ctx.target_ttd = nil
        ctx.ttd = nil
        ctx.target_hp = 100
        ctx.range = 0
    end
    -- Secondary enemies (ranked #7): multi-enemy scenarios present the
    -- target's peers so lanes that scan `context.enemies` (retri
    -- find_secondary_enemy → Ret_JudgeSecondary_CommandCleave, multi-target
    -- DoT-spread lanes) see a realistic enemy list instead of the empty
    -- default. The clone is a fresh unit sharing the scenario's closures, so
    -- `enemy ~= context.target` holds and distance/HP reads are scenario-true.
    -- FOOTGUN: this fixture makes `enemies` non-empty in EVERY 2+ enemy
    -- scenario (aoe, group_aoe, undead_target, hunter_toggles, ...). Lanes
    -- that scan it will start firing battery-wide — the multi-DoT spread
    -- lanes (shadow MultiDot*/balance *Spread) must stay silent until a
    -- per-debuff afflictable-targets model exists; verify any future
    -- enemies-scanning lane fires ONLY in its intended scenario.
    if (ctx.enemy_count or ctx.enemies_count or 1) >= 2 then
        ctx.enemies = { ctx.target, build_scenario_target(ctx) }
    end

    -- Warrior threat-scan mocks (ranked #6): TauntSecondary's no_threat_target
    -- derives from the protection visible-objects scan (get_threat_targets,
    -- fed by core.object_manager.get_visible_objects and throttled by
    -- core.time — both stubbed in load_spec). Scenarios opt in via
    -- `visible_enemies = true`. Mocks must be enemies of the player
    -- (is_enemy_with → true) NOT currently targeting the player (get_target
    -- nil — the _target base already returns nil) or the scan treats them as
    -- already-tanked. No get_owner/get_position, so the shaman enhancement
    -- totem-recall scan (which skips owner-less objects) is unaffected.
    -- NOTE: TauntSecondary additionally requires prot_state.enemy_count >= 3
    -- (from ctx.enemy_count), so a visible_enemies scenario must also set
    -- enemy_count >= 3 — the two elite scenarios do (3).
    if overrides.visible_enemies then
        local count = ctx.enemy_count or ctx.enemies_count or 2
        local list = {}
        for i = 1, count do
            local e = _target()
            e.is_enemy_with = function() return true end
            -- Real game objects always expose get_owner() (nil for units) —
            -- the enh TotemicCall scan calls obj:get_owner() unconditionally
            -- (enhancement_sylvanas.lua:1265), so owner-less mocks must
            -- return nil here or the scan errors instead of skipping them.
            e.get_owner = function() return nil end
            list[i] = e
        end
        -- Totemic Call (campaign follow-up 2026-08-08): the enh totem-recall
        -- scan (enhancement_sylvanas.lua:1225-1277) iterates visible objects,
        -- keeps only those with get_owner() (summoned), and fires when one
        -- sits beyond TOTEM_CALL_DISTANCE (20 yd -> 400 sq). Enemy mocks have
        -- no get_owner (skipped); the totem_far flag appends a distant totem
        -- at (30, 30) -> 1800 sq > 400 so the recall fires.
        if overrides.totem_far then
            list[#list + 1] = {
                is_valid = function() return true end,
                get_owner = function() return {} end,
                get_position = function() return { x = 30, y = 30, z = 0, [1] = 30, [2] = 30 } end,
            }
        end
        ctx.visible_enemies = list
    end
    -- Pets (hunter + warlock) — skipped when the scenario says the pet was
    -- never summoned (no_pet) so Call Pet / summon lanes are reachable.
    if profile.pet and not scenario.no_pet then
        local pet_hp = ctx.pet_hp or 100
        local pet = _target()
        pet.get_health_percentage = function(self) return pet_hp end
        pet.get_health = function(self) return pet_hp * 100 end
        pet.is_dead = function(self) return pet_hp <= 0 end
        -- Warlock specs gate pet state on pet:is_alive(); without it the live
        -- pet lane read pet_alive=false and pet_hp_pct=100 in every scenario.
        pet.is_alive = function(self) return pet_hp > 0 end
        pet.get_distance = function(self) return 20 end
        ctx.pet = pet
        ctx.pet_dead = ctx.pet_dead == true or pet_hp <= 0
    else
        ctx.pet = nil
        ctx.pet_dead = true
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
    -- WotLK era (Phase 1 triage): *_wotlk.lua specs resolve the player unit
    -- via `NS.me or NS.GetPlayer()` (not `context.me` like TBC files), so the
    -- scenario-aware unit must be published as NS.me per scenario or every
    -- WotLK unit read (rage/energy/combo/runic) hits the raw mock and returns
    -- 0 — the root cause of the 149-lane WotLK never-firing inventory.
    if ctx.me then ns.me = ctx.me end
    -- Advance the scenario clock: module-level 1s scan caches (hunter_core pet
    -- scan, purge delay cache, swing gates) must see a fresh timestamp per
    -- scenario or they freeze on the first scenario's observations.
    _battery_now = _battery_now + 2.0
    ns._battery_now = _battery_now
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
        in_combat = ctx.in_combat == true,
        is_stealthed = ctx.is_stealthed == true,
        target_is_casting = ctx.target_is_casting == true,
        me_casting = ctx.me_casting == true,
        swing_until = ctx.swing_until,
        enemy_buffed = ctx.enemy_buffed == true,
        friends_afflicted = ctx.friends_afflicted == true,
        friends_hp = ctx.friends_hp,
        lifebloom = ctx.lifebloom,
        afflicted = ctx.afflicted or {},
        pet_hp = ctx.pet_hp or 100,
        pet_dead = ctx.pet_dead == true,
        has_potions = ctx.has_potions == true,
        level = ctx.level or ctx.player_level or 70,
        is_leveling = ctx.is_leveling == true,
        debuff_stacks = ctx.debuff_stacks or 0,
        debuff_aura_ids = ctx.debuff_aura_ids,
        not_learned = ctx.not_learned,
        target_creature_type = ctx.target_creature_type or 7,
        buff_remains_map = ctx.buff_remains_map,
        player_debuff_remains_map = ctx.player_debuff_remains_map,
        -- (c) close-out (2026-08-09): dead_ally feeds find_dead_party_ally
        -- (balance Rebirth); has_trinket feeds TrinketManager (BM Trinket).
        dead_ally = ctx.dead_ally == true,
        has_trinket = ctx.has_trinket == true,
        -- Multi-DoT spread model (ranked #1): the TSHelper stub returns this
        -- enemy list, and debuff_up/debuff_remains consult the primary-target
        -- dot map before the buffs_up fallback.
        enemies = ctx.enemies,
        primary_target = ctx.target,
        debuff_remains_map = ctx.debuff_remains_map,
        visible_enemies = ctx.visible_enemies,
        friend_class = ctx.friend_class,
        setting_overrides = ctx.setting_overrides,
        -- (b) close-out (2026-08-10): stub-driven banks for the PvP/situational
        -- fixtures (GetEnemiesInRange, is_auto_attacking, pet_spells). The
        -- is_auto_attacking default stays TRUE (legacy posture) unless a
        -- scenario explicitly sets it false.
        enemies_in_range = ctx.enemies_in_range,
        is_auto_attacking = ctx.is_auto_attacking ~= false,
        pet_spells = ctx.pet_spells,
        snared_friend = ctx.snared_friend == true,
        -- Equipped-weapon mock (2026-08-08): the mutilate_daggers scenario's
        -- equipped_daggers flag lands here so the get_equipped_item_id stub
        -- (which reads _bstate) returns a dagger id for both hands → assn
        -- has_daggers = true → Mutilate observable.
        equipped_daggers = ctx.equipped_daggers == true,
        -- Totemic Call (2026-08-08): ns.core.spell_book.get_totem_info reads
        -- this bank key (enh cached the stub at load time); the totem_far
        -- scenario sets it so the has_totem gate passes.
        totem_active = ctx.totem_active == true,
        fsr_inside = ctx.fsr_inside == true,
        fsr_seconds = ctx.fsr_seconds or 0,
        fsr_regen_delta = ctx.fsr_regen_delta or 0,
        fsr_pause_ok = ctx.fsr_pause_ok == true,
        -- WotLK Phase-1 triage (2026-08-09): resource/state banks for the DK
        -- stubs (rune_manager/presence_manager/interrupt_manager read these via
        -- ns._bstate) and the *_wotlk build_state context reads.
        runic_power = ctx.runic_power,
        rune_state = ctx.rune_state,
        is_boss = ctx.is_boss == true,
        optimal_presence = ctx.optimal_presence,
        lock_and_load = ctx.lock_and_load == true,
        scorch_cast_time = ctx.scorch_cast_time,
        bloodlust_ready = ctx.bloodlust_ready == true,
        elemental_mastery_ready = ctx.elemental_mastery_ready == true,
        fire_elemental_ready = ctx.fire_elemental_ready == true,
        water_totem_remains = ctx.water_totem_remains,
        maelstrom_stacks = ctx.maelstrom_stacks,
        injured_count = ctx.injured_count,
        mana_tide_ready = ctx.mana_tide_ready == true,
        -- Friendly-target context (2026-08-08): friendly_target_hp feeds
        -- NS.get_friendly_target_entry so the healer FriendlyTarget lanes
        -- (disc + holy priest, holy paladin, resto druid + shaman) get a
        -- friendly unit below the 90 threshold. Keyed on the hp alone (no
        -- boolean — avoids colliding with context.friendly_target-as-unit).
        friendly_target_hp = ctx.friendly_target_hp,
        -- Threat-family close-out (2026-08-10): friendly_target_threat marks
        -- the lowest heal-scan ally threatened for holy BoPFocusedAlly.
        friendly_target_threat = ctx.friendly_target_threat,
    }
    -- Party members: holy MassDispel (holy_sylvanas.lua:1031) scans
    -- context.party_members for dangerous magic via Healing.has_dangerous_dispel.
    -- Present the scenario's friends as the party when the group carries magic
    -- affliction (the friends_afflicted scenario) so the scan finds a target;
    -- other scenarios keep party_members empty so the matcher stays silent (and
    -- ally-scanning paladin lanes keep their current battery behavior). Any
    -- healer module's scan returns identical entries (same _heal_entries factory
    -- + state bank), so ns.PriestHealing is just a convenient accessor.
    local _afflicted_t = ctx.afflicted or {}
    if _afflicted_t.magic == true then
        local heal_mod = ns.PriestHealing
        local entries = heal_mod and heal_mod.scan_healing_targets and heal_mod.scan_healing_targets()
        if type(entries) == "table" then
            ctx.party_members = {}
            for i = 1, #entries do ctx.party_members[i] = entries[i].unit end
        end
    end
    -- Scenario-aware unit_alive: pet reads reflect pet_dead so the dead-pet
    -- lane (Revive Pet, Call Pet, Mend Pet suppression) is observable.
    ns.unit_alive = function(unit)
        if unit == ctx.pet then return not (ctx.pet_dead == true) end
        return true
    end
    -- Enemy scan: priest pre_heal_matches gates on _check_pushback, which
    -- iterates NS.GetEnemiesInRange looking for a casting enemy. Absent this
    -- stub the scan is empty and PreHeal can never fire. Only the `pushback`
    -- scenario presents a casting enemy; everything else stays empty so other
    -- enemies-in-range consumers (fade fallback, defensive middleware) keep
    -- their current battery behavior.
    ns.GetEnemiesInRange = function(range)
        if ctx.enemies_casting == true then return { ctx.target } end
        -- (b) close-out (2026-08-10): the pvp_pressure_resto scenario sets
        -- enemies_in_range = { melee = N, healer = N } so resto's
        -- scan_pvp_pressure fills melee_pressure_count / enemy_healer /
        -- root_target. Default (no key) stays {} — identical to the legacy
        -- empty scan, so no other spec's reads change.
        local spec = ctx.enemies_in_range
        if type(spec) ~= "table" then return {} end
        local out = {}
        for i = 1, (spec.melee or 0) do out[#out + 1] = _battery_enemy("melee") end
        for i = 1, (spec.healer or 0) do out[#out + 1] = _battery_enemy("healer") end
        return out
    end
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
    -- Heal-scan stubs live in build_ns and are driven by the state bank
    -- (_bstate "friends_hp" / "afflicted"): only scenarios that SET friends_hp
    -- (friends_damaged, me_casting, group_*, friends_afflicted) present injured
    -- allies, so solo/healthy scenarios keep the idle-DPS lanes observable and
    -- injured-group scenarios drive the *Heal/cleanse lanes. This replaces the
    -- earlier always-injured scan (every healer scenario reported 55/70/85 hp
    -- friends, which silenced every Idle*/Solo* DPS lane).
    local friends = ctx.friends or {}
    -- NS-level party accessors fall back to the populated ctx.party_members
    -- (holy MassDispel scans it) so both entry points see the same party.
    local party = ctx.party_members or friends
    -- Intervene close-out (2026-08-08, ranked #3): the group_ally_low scenario
    -- presents one low-hp ally (30%, within range) through the party scan so
    -- prot build_state (protection:428-449) populates state.lowest_allied —
    -- the Intervene matcher needs is_group + a low-hp in-range ally. Only prot
    -- reads get_party_members, so this stays scoped (priest middleware uses
    -- NS.GetPartyMembers, a separate stub).
    if ctx.party_low_ally == true then
        party = { _friend(ctx.friend_hp or 30, 5) }
    end
    ns.get_party_members = function() return party end
    ns.party_members = function() return party end
    if ns.HealerDeficit then
        ns.HealerDeficit.deficit_of = function(u) return math.max(0, 100 - (u and u.hp or 100)) end
    end
end

-- ---------------------------------------------------------------------------
-- Spec loader
-- ---------------------------------------------------------------------------
function M.load_spec(class_key, spec_key, era, race_override)
    era = era or "sylvanas"
    local path = "EaxRotations/classes/" .. class_key .. "/" .. spec_key .. "_" .. era .. ".lua"
    local f = io.open(path, "rb")
    if not f then return nil, "missing file " .. path end
    f:close()

    -- Death Knight shared-manager stubs (Phase 1): the real rune_manager /
    -- presence_manager / interrupt_manager load fine standalone but read live
    -- game state (rune APIs, presence settings) that the battery cannot
    -- reproduce; without stubs every DK rune read returns 0/{} and the
    -- presence lane can never fire. Scenario-driven where useful (see below).
    -- Restored after dofile: load_spec nils package.loaded for the six stubbed
    -- modules (rune/presence/interrupt/fsr/ts/stealth managers) in the dofile
    -- error-handler block so later suites get the real modules back.

    -- Seed binary-only game modules spec files require (present in the live
    -- client but absent from this repo). Without this, hunter specs' item
    -- lanes (Healthstone / potions / trinkets) silently read nil helpers and
    -- the battery reports them never-firing even though they work in game.
    package.loaded["common/utility/inventory_helper"] = {
        has_item = function(id) return true end,
        get_item_count = function(id) return 1 end,
        is_item_ready = function(id) return true end,
    }

    local ns = M.build_ns(class_key, era)
    _G.EaxRotations = ns
    local had_core = _G.core
    _G.core = {
        spell_book = {
            get_totem_info = function() return nil end,
        },
        -- Scenario-aware clock (ranked #6): protection's TauntSecondary threat
        -- scan throttles on core.time(). Wire it to the advancing _battery_now
        -- so the scan runs fresh per scenario instead of freezing on the first
        -- (constant 0 previously → scan never ran → no_threat_target nil).
        -- Module-level 1s caches (enhancement totem recall, aura_cache) now
        -- re-evaluate per scenario; their battery results are constant (false
        -- / empty), so never-lists are byte-identical and no exclusivity-pinned
        -- lane's fires_in changed (all 12 battery regression tests green).
        time = function() return _battery_now end,
        object_manager = {
            -- Visible enemies for the protection threat scan; empty everywhere
            -- except the elite_target/elite_taunt_cd scenarios (which populate
            -- ctx.visible_enemies). Other consumers (enhancement totem scan,
            -- aura_probe get_local_player, auto_loot get_all_objects) are
            -- pcall/owner-guarded and see {} / nil as before.
            get_visible_objects = function() return ns._bstate("visible_enemies", {}) end,
        },
    }
    if class_key == "deathknight" then
        -- Rune bank (Phase 1, second pass): the per-rune getters were hardcoded
        -- 2/2/2/0, so frost/unholy EmpowerRuneWeapon (gate: total_runes_ready
        -- == 0) could NEVER fire — the dk_runes_depleted scenario's rune_state
        -- override never reached them. All four now read the bank's ready map
        -- (default 2s, the original battery posture).
        local function _rune_bank()
            local rs = ns and ns._bstate and ns._bstate("rune_state", nil)
            if type(rs) == "table" and type(rs.ready) == "table" then return rs end
            return nil
        end
        package.loaded["shared/rune_manager_sylvanas"] = {
            get_runic_power = function(unit)
                return ns and ns._bstate and ns._bstate("runic_power", 50) or 50
            end,
            get_rune_state = function()
                return ns and ns._bstate and ns._bstate("rune_state", nil) or {
                    blood = 2, frost = 2, unholy = 2, death = 0,
                    ready = { blood = 2, frost = 2, unholy = 2, death = 0 },
                }
            end,
            get_blood_runes_ready = function()
                local rs = _rune_bank()
                return rs and rs.ready.blood or 2
            end,
            get_frost_runes_ready = function()
                local rs = _rune_bank()
                return rs and rs.ready.frost or 2
            end,
            get_unholy_runes_ready = function()
                local rs = _rune_bank()
                return rs and rs.ready.unholy or 2
            end,
            get_death_runes_ready = function()
                local rs = _rune_bank()
                return rs and rs.ready.death or 0
            end,
        }
        -- Presence (Phase 1, second pass): get_optimal_presence hardcoded nil and
        -- should_switch_presence hardcoded false, so the 3 presence lanes (blood
        -- Presence, unholy Presence, frost FrostPresence) could never fire. Now
        -- scenario-driven: the dk_presence scenario sets optimal_presence in the
        -- bank; the lanes fire wherever the bank's desired presence differs from
        -- the current state (nil in the battery — no presence buffs up).
        package.loaded["shared/presence_manager_sylvanas"] = {
            get_optimal_presence = function()
                return ns and ns._bstate and ns._bstate("optimal_presence", nil)
            end,
            should_switch_presence = function(ctx, st, desired)
                local want = ns and ns._bstate and ns._bstate("optimal_presence", nil)
                if not want or not desired then return false end
                local cur = st and st.presence
                return cur == nil or cur ~= desired
            end,
            presence_id = function(name) return name end,
            presence_name = function(id) return id end,
            presence_spell_id = function() return 0 end,
        }
        -- Interrupts (Phase 1, second pass): register_interrupt_spell returned a
        -- matches=false strategy, so MindFreeze (blood/frost/unholy) could never
        -- fire. Now bank-aware: matches on target_is_casting, so the existing
        -- target_casting scenario makes the 3 MindFreeze lanes observable.
        package.loaded["shared/interrupt_manager_sylvanas"] = {
            register_interrupt_spell = function()
                return {
                    name = "MindFreeze",
                    matches = function()
                        return ns and ns._bstate and ns._bstate("target_is_casting", false) == true
                    end,
                    execute = function() return false end,
                }
            end,
        }
    end
    -- (b) close-out (2026-08-10): smite binds _player_race from
    -- load_player:get_race_id() at require time (smite:30-32). RACE_OVERRIDES
    -- makes smite load as night elf (4) so Starshards is observable;
    -- run_spec passes an explicit race_override for RACE_VARIANTS (undead 5)
    -- so DevouringPlague is observable too. Other specs get nil → race 1
    -- (human), unchanged.
    -- Era-gated: the TBC and vanilla batteries each bind their own race
    -- override (smite loads as night elf 4 so Starshards is observable); a
    -- future WotLK-era smite load can't silently pick up a binding.
    local overrides = M.race_maps_for(era)
    M._race_override = race_override or (overrides and overrides[spec_key])
    local ok, result = pcall(dofile, path)
    M._race_override = nil
    -- Keep the stub installed when there was no pre-existing core: runtime
    -- reads during dispatch (protection's threat-scan throttle calls
    -- core.time() live) would otherwise see nil and freeze the scan at now=0,
    -- leaving no_threat_target nil forever. Restore a caller-provided core if
    -- one exists; otherwise leave the stub in place. The stub is benign
    -- (spell_book.get_totem_info nil, get_visible_objects {} unless a scenario
    -- sets visible_enemies) and the rotation runner snapshots/restores _G
    -- between suites, so no sibling test sees it.
    _G.core = had_core or _G.core
    -- The FSR/TSHelper stubs are captured by the spec module at require()
    -- time; restore the real modules for any later suite in the same process
    -- (all tests share one dofile process).
    package.loaded["shared/fsr_manager_sylvanas"] = nil
    package.loaded["shared/ts_helper_sylvanas"] = nil
    package.loaded["shared/stealth_helper_sylvanas"] = nil
    package.loaded["shared/rune_manager_sylvanas"] = nil
    package.loaded["shared/presence_manager_sylvanas"] = nil
    package.loaded["shared/interrupt_manager_sylvanas"] = nil
    if not ok then
        return nil, tostring(result)
    end
    return result, nil, ns
end

-- ---------------------------------------------------------------------------
-- Spec runner
-- ---------------------------------------------------------------------------
function M.run_spec(class_key, spec_key, scenarios, era, race_override)
    era = era or "sylvanas"
    scenarios = scenarios or M.SCENARIOS
    local result, load_err, ns = M.load_spec(class_key, spec_key, era, race_override)
    if not result then
        return nil, load_err
    end
    local strategies = (type(result) == "table") and (result.strategies or result) or nil
    if type(strategies) ~= "table" then
        return nil, "no strategies table returned for " .. class_key .. "/" .. spec_key
    end
    local build_state = (type(result) == "table") and result.build_state or nil
    -- Plain-style vanilla files return their bare strategies table and register
    -- get_state via the registry mock in build_ns; recover it here so stateful
    -- matchers see the real safe_state instead of the raw scenario ctx.
    if not build_state and ns and ns._registry and ns._registry.options
        and type(ns._registry.options.get_state) == "function" then
        build_state = ns._registry.options.get_state
    end

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
            if not ok then
                -- build_state crashes were silently swallowed (state fell back
                -- to ctx); record them so the battery surfaces state-builder
                -- runtime bugs, not just match() errors.
                dispatch_errors[#dispatch_errors + 1] =
                    "build_state@" .. sc.name .. ": " .. tostring(st)
            elseif type(st) == "table" then
                state = st
            end
        end
        -- Dispatcher semantics: the real engine fires on any TRUTHY matcher
        -- return; the battery previously required `m == true`, which silently
        -- hid strategies whose matchers return an object (hunter MM/survival
        -- AdaptiveRotation return `c.target`). Truthy check mirrors the engine
        -- and can only shrink the never-list (pinned lanes all return boolean).
        for _, s in ipairs(strategies) do
            if type(s) == "table" and type(s.name) == "string" and type(s.matches) == "function" then
                local ok, m = pcall(s.matches, ctx, state)
                if not ok then
                    dispatch_errors[#dispatch_errors + 1] =
                        (s.name or "?") .. "@" .. sc.name .. ": " .. tostring(m)
                elseif m then
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
-- ---------------------------------------------------------------------------
-- Loud load-order guard (survey item #2): the require-time NS-caching hazard.
-- 79 shared/*_sylvanas.lua modules capture `local NS = _G.EaxRotations` at
-- require() time, and 8 write back into whatever NS is loaded (see the
-- _EAX_MOCK gates in auto_tremor/dot_refresh/execute_phase/melee_combat_math/
-- combat_forecast_gate/mf_tick_compute/purge_manager/ttd_tracker). If a tool
-- requires shared modules while a MOCK NS is installed (e.g. the scorecard's
-- compute() running before the battery, or a future tool dofiling specs), those
-- modules silently cache the mock — the pollution signature tracked by
-- tools/spec_scorecard.lua. The battery must ALWAYS see virgin shared modules:
-- this guard fails loudly at run_all entry if any shared module was already
-- loaded, and load_spec's restore block self-cleans after each spec so nothing
-- leaks to sibling suites in the same process.
function M.guard_shared_virgin()
    -- Only shared modules that bind to _G.EaxRotations AT REQUIRE TIME are a
    -- pollution hazard, in two forms:
    --   (1) top-level capture at column 0: `local X = _G.EaxRotations` (X is
    --       usually NS, but snapshot_sylvanas uses `_G_NS`) — the module is
    --       bound to whatever NS is installed when it loads, so a preloaded
    --       instance would keep referencing a discarded mock;
    --   (2) write-back binding: `_G.EaxRotations.FIELD = ...` (or an alias
    --       form `_G_NS.FIELD = ...`) at load time — the 8 gated modules'
    --       export blocks.
    -- LAZY references are harmless and must NOT trip the guard: spec_kit's
    -- `ns()` returns _G.EaxRotations at CALL time (spec_kit:48), and
    -- combat_forecast_gate captures it inside _is_boss() (line 15) — both
    -- resolve against the current _G at call time, so preloading them under a
    -- mock changes nothing. Pure utilities with zero NS references (e.g.
    -- shared/apl_parser, loaded by tools/apl_status.lua before the battery in
    -- the scorecard's process) are likewise exempt. The patterns below are
    -- column-anchored / write-form specific so lazy readers never false-
    -- positive, while a genuine require-time binder always fails loudly.
    local loaded = {}
    for k in pairs(package.loaded) do
        if type(k) == "string" and k:find("^shared/", 1) then
            local path = "EaxRotations/" .. k .. ".lua"
            local f = io.open(path, "rb")
            local hazardous = true  -- fail-closed: unreadable file is flagged
            if f then
                local src = f:read("*a")
                f:close()
                hazardous = false
                if src then
                    -- (1) top-level require-time capture at column 0, ANY
                    -- identifier (NS, _G_NS, ...): the capture line begins at
                    -- column 0 (`\nlocal` or file start), so lazy in-function
                    -- captures (indented) never match. File-start uses a real
                    -- PATTERN so `^` anchors (plain text would treat `^` as a
                    -- literal caret); the newline-prefixed form matches every
                    -- non-first line via plain text.
                    if src:find("\nlocal [%a_][%w_]* = _G.EaxRotations")
                        or src:find("^local [%a_][%w_]* = _G.EaxRotations") then
                        hazardous = true
                    end
                    -- (2) write-back binding: `_G.EaxRotations.FIELD = ...` at
                    -- load time (the 8 gated modules' export blocks). Matched
                    -- as an ASSIGNMENT (`=`) so doc comments like spec_kit:25's
                    -- "-- _G.EaxRotations. When NS is absent" never trip it.
                    -- The snapshot alias form `_G_NS.SnapshotHelper = M` is
                    -- caught via (1) (its top-level `_G_NS` capture).
                    if src:find("_G.EaxRotations%.[%a_][%w_]*%s*=") then
                        hazardous = true
                    end
                end
            end
            if hazardous then loaded[#loaded + 1] = k end
        end
    end
    if #loaded > 0 then
        table.sort(loaded)
        error("behavioral_audit: " .. #loaded .. " NS-capturing shared module(s) already "
            .. "loaded before the battery: " .. table.concat(loaded, ", ")
            .. " — these cache _G.EaxRotations at require() time, so a preloaded "
            .. "module would bind to whatever NS the caller installed (possibly a mock), "
            .. "the compute()-vs-battery pollution signature. Run the battery before any "
            .. "tool requires NS-capturing shared modules (see tools/spec_scorecard.lua "
            .. "POLLUTION_SIGNATURE).", 0)
    end
end

function M.run_all(era)
    era = era or "sylvanas"
    M.guard_shared_virgin()
    local manifest = M.ERA_MANIFESTS[era]
    if not manifest then
        error("behavioral_audit: unknown era '" .. tostring(era)
            .. "' (expected 'sylvanas', 'wotlk' or 'vanilla')", 0)
    end
    local total = 0
    local reports = {}
    local load_failures = {}
    for class_key, specs in pairs(manifest) do
        for _, spec_key in ipairs(specs) do
            total = total + 1
            local report, err = M.run_spec(class_key, spec_key, M.SCENARIOS, era)
            if not report then
                load_failures[#load_failures + 1] = class_key .. "/" .. spec_key .. ": " .. tostring(err)
            else
                -- Threat-family close-out (2026-08-10): race-variant merge.
                -- smite binds race at require time; RACE_VARIANTS loads the
                -- spec again per extra race and a lane stays never ONLY if it
                -- never fires under ANY variant (Starshards fires as night
                -- elf 4, DevouringPlague as undead 5 — both observable).
                -- Era-gated like RACE_OVERRIDES: a future WotLK-era smite load
                -- can't silently pick up the undead variant. If a variant load
                -- fails, never_set is left untouched (conservative: lanes stay
                -- never) and the failure surfaces via the load-failures pin.
                local _, variant_map = M.race_maps_for(era)
                local variants = variant_map and variant_map[spec_key]
                local never_set = {}
                for _, n in ipairs(report.never) do never_set[n] = true end
                local errs = {}
                for _, e in ipairs(report.dispatch_errors) do errs[#errs + 1] = e end
                if type(variants) == "table" then
                    for _, race in ipairs(variants) do
                        local vrep, verr = M.run_spec(class_key, spec_key, M.SCENARIOS, era, race)
                        if not vrep then
                            load_failures[#load_failures + 1] = class_key .. "/" .. spec_key
                                .. " (race " .. tostring(race) .. "): " .. tostring(verr)
                        else
                            local vnever = {}
                            for _, n in ipairs(vrep.never) do vnever[n] = true end
                            for n in pairs(never_set) do
                                if not vnever[n] then never_set[n] = nil end
                            end
                            for _, e in ipairs(vrep.dispatch_errors) do errs[#errs + 1] = e end
                        end
                    end
                end
                local merged = {}
                for n in pairs(never_set) do merged[#merged + 1] = n end
                table.sort(merged)
                reports[#reports + 1] = {
                    class = class_key,
                    spec = spec_key,
                    never = merged,
                    strategy_count = report.strategy_count,
                    dispatch_errors = errs,
                }
            end
        end
    end
    -- Manifest drift: every *_<era>.lua under classes/ must appear in the era
    -- manifest, and every manifest entry must exist on disk. A new spec file
    -- that lands without a manifest row silently loses battery coverage —
    -- surface it as a load failure so the report AND verify_all's
    -- "Load failures: 0" pin catch it.
    local drift = M.check_manifest_drift(era)
    for _, rel in ipairs(drift.missing) do
        load_failures[#load_failures + 1] = "MANIFEST entry missing on disk: " .. rel
    end
    for _, rel in ipairs(drift.extra) do
        load_failures[#load_failures + 1] = "MANIFEST file not in " .. era .. " manifest: " .. rel
    end
    table.sort(reports, function(a, b)
        if a.class == b.class then return a.spec < b.spec end
        return a.class < b.class
    end)
    -- Self-cleaning battery (survey item #2): guard_shared_virgin() guarantees a
    -- virgin shared-module namespace at entry; evict everything we loaded so the
    -- NEXT run_all in the same process (the scorecard runs TBC then WotLK) also
    -- starts virgin, and so no sibling tool in the same process can reuse a
    -- shared module bound to one of our (discarded) mock NSes. Also drop the
    -- last mock from _G so a later tool that requires shared modules can't
    -- silently capture a battery mock (the compute()-vs-battery pollution bug).
    for k in pairs(package.loaded) do
        if type(k) == "string" and k:find("^shared/", 1) then
            package.loaded[k] = nil
        end
    end
    if _G.EaxRotations and _G.EaxRotations._EAX_MOCK then
        _G.EaxRotations = nil
    end
    return { total = total, era = era, reports = reports, class_failures = load_failures }
end

-- ---------------------------------------------------------------------------
-- Manifest drift check (reviewer-hardened): cross-check the era manifest
-- against the files actually on disk under classes/. Non-spec helper files
-- (class_/schema_/middleware_/healing_/cliptracker_/heal_helper_/shared_helpers_)
-- are excluded; TBC leveling files are covered by run_leveling_tests.lua, but
-- WotLK leveling files ARE battery specs, so the exclusion is era-aware.
-- ---------------------------------------------------------------------------
function M.check_manifest_drift(era)
    era = era or "sylvanas"
    local manifest = M.ERA_MANIFESTS[era] or M.SPEC_FILES
    local expected = {}
    for class_key, specs in pairs(manifest) do
        for _, spec_key in ipairs(specs) do
            expected[class_key .. "/" .. spec_key .. "_" .. era .. ".lua"] = true
        end
    end
    local non_spec = {
        "class_", "schema_", "middleware_", "healing_", "cliptracker_",
        "heal_helper_", "shared_helpers_",
    }
    if era == "sylvanas" or era == "vanilla" then
        -- TBC + vanilla leveling files run via run_leveling_tests.lua, not the
        -- battery (WotLK leveling files ARE battery specs).
        non_spec[#non_spec + 1] = "leveling_"
    end
    local drift = { missing = {}, extra = {} }
    local ok_lfs, lfs = pcall(require, "lfs")
    if not ok_lfs then return drift end
    local root = "EaxRotations/classes"
    for class_key in lfs.dir(root) do
        if class_key ~= "." and class_key ~= ".." then
            local dir = root .. "/" .. class_key
            local attrs = lfs.attributes(dir)
            if attrs and attrs.mode == "directory" then
                for fname in lfs.dir(dir) do
                    if fname:match("^.*_" .. era .. "%.lua$") then
                        local is_non_spec = false
                        -- Prefix match against the FULL filename (stem drops the
                        -- trailing _<era>, so a stem-based match would never see
                        -- e.g. "class_" inside "class_sylvanas").
                        for _, p in ipairs(non_spec) do
                            if fname:find(p, 1, true) == 1 then
                                is_non_spec = true
                                break
                            end
                        end
                        if not is_non_spec then
                            local rel = class_key .. "/" .. fname
                            if not expected[rel] then
                                drift.extra[#drift.extra + 1] = rel
                            end
                        end
                    end
                end
            end
        end
    end
    for rel in pairs(expected) do
        local f = io.open("EaxRotations/classes/" .. rel, "rb")
        if not f then
            drift.missing[#drift.missing + 1] = rel
        else
            f:close()
        end
    end
    return drift
end

-- ---------------------------------------------------------------------------
-- Printer
-- ---------------------------------------------------------------------------
function M.print_report(agg)
    local era_label = (agg.era == "wotlk") and "wotlk"
        or ((agg.era == "vanilla") and "vanilla" or "sylvanas")
    print("=============================================================================")
    print("  BEHAVIORAL BATTERY AUDIT (" .. tostring(agg.total) .. " " .. era_label .. " specs)")
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

-- Standalone entry: `lua EaxRotations/tests/behavioral_audit.lua [wotlk|vanilla]`
-- Direct runs are detected via arg[0] (the invoked script path), NOT via
-- select("#", ...): in Lua 5.1 the main chunk's `...` IS the CLI args, but the
-- spec scorecard loads this file via loadfile + chunk('scorecard'), which also
-- makes select("#", ...) == 1 — so a vararg-only guard would either skip the
-- direct run (typo'd era silently no-ops) or mis-fire under loadfile. arg[0]
-- contains "behavioral_audit" only for genuine direct runs. Unknown eras error
-- out with usage instead of silently producing no report.
if arg and arg[0] and arg[0]:find("behavioral_audit", 1, true) then
    local cli_era = arg[1]
    if cli_era and cli_era ~= "wotlk" and cli_era ~= "vanilla" then
        io.stderr:write("behavioral_audit: unknown era '" .. tostring(cli_era)
            .. "' — expected 'wotlk', 'vanilla' or no argument (default sylvanas)\n")
        os.exit(1)
    end
    local era = (cli_era == "wotlk") and "wotlk"
        or ((cli_era == "vanilla") and "vanilla" or "sylvanas")
    local agg = M.run_all(era)
    M.print_report(agg)
end

return M