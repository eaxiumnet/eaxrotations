-- pet_manager_sylvanas.lua -- pet attack/cast/stance helpers for Hunter + Warlock + Mage.
-- WHAT:   Sends pet to attack current target + casts pet abilities on CD.
-- WHEN:   Called every frame by the dispatcher for hunter/warlock/mage classes.
-- WHY:    Single source of truth so specs don't duplicate pet control logic.
-- SAFETY: Engagement-gated pet_attack; nil-guarded API calls; throttled casts.
-- DECISION: State-machine per spec; no on_update side-effects outside this module.

local NS = _G.EaxRotations
if not NS then return nil end
local M = {}

-- Platform-provided pet handler for engine-level pet state management
local _ph_ok, pet_handler = pcall(require, "common/utility/pet_handler")
if not _ph_ok or type(pet_handler) ~= "table" then pet_handler = nil end

-- ============================================================================
-- Engagement safety (copied from shadow_sylvanas.lua -- same contract)
-- ============================================================================
local function _engaged_with_player(context)
    if not context then return true end
    if not context.in_combat then return true end
    local target = context.target
    local me = context.me
    if not target or not me then return true end
    if (context.target_hp or 100) < 100 then return true end
    local ok, enemy_target = pcall(function() return target:get_target() end)
    if not ok or not enemy_target then return false end
    if NS.same_unit and NS.same_unit(enemy_target, me) then return true end
    return false
end

-- ============================================================================
-- Pet state constants
-- ============================================================================
local STATE_IDLE, STATE_ENGAGING, STATE_FIGHTING, STATE_RETREATING = 0, 1, 2, 3

local _states = {}

-- ============================================================================
-- Pet spell ID tables (DBC-verified for TBC 2.5.5)
-- ============================================================================
-- Hunter pet abilities
local PET_GROWL       = { 2649, 14268, 14269, 14270, 14271, 14925 }
local PET_CLAW        = { 2981, 14261, 14262, 14263, 14264, 14265 }
local PET_BITE        = { 17253, 17254, 17255, 17256, 17257, 27050 }
local PET_GORE        = { 35290, 35291 }
local PET_HOWL        = { 24597, 24598, 24599, 24600 }
local PET_SCREECH     = { 24604 }
local PET_THUNDER     = { 26090, 26093 }
local PET_LIGHTNING   = { 25011, 25012, 25013, 25014, 25015, 25016 }
local PET_POISON      = { 24640 }
local PET_DASH        = { 23099 }
local PET_DIVE        = { 23145 }

-- Warlock pet abilities
local IMP_FIREBOLT    = { 3110, 7799, 7800, 7801, 7802, 11762, 11763, 27267 }
local VW_TAUNT        = { 17735, 11774, 11775 }
local VW_SACRIFICE    = { 7812, 19438, 19440, 19441, 19442, 19443 }
local VW_CONSUME      = { 17767, 17850, 17851, 17852, 17853, 17854 }
local SUCC_LASH       = { 7814, 11778, 11779, 11780, 11781 }
local SUCC_SEDUCE     = { 6358 }
local FELHUNTER_BITE  = { 54053, 54049, 54050, 54051, 54052 }
local FELHUNTER_DEVOUR= { 19505 }
local FELHUNTER_SPELL = { 19647 }
local FELGUARD_CLEAVE = { 30213 }
local FELGUARD_INTERCEPT = { 30198, 30197, 30196 }
local FELGUARD_ANGUISH = { 33698, 33699, 33700 }

-- Pet type detection: map identifying spell IDs to pet type.
-- A pet is considered a given type if it knows any of that type's signature spells.
local PET_TYPE_SPELLS = {
    imp        = IMP_FIREBOLT,
    voidwalker = VW_TAUNT,
    succubus   = SUCC_LASH,
    felhunter  = FELHUNTER_BITE,
    felguard   = FELGUARD_CLEAVE,
}

-- Module-level pet type cache keyed by pet GUID to avoid repeated spell scans.
local _pet_type_cache = { guid = nil, type = nil }

-- Mage pet abilities (Water Elemental)
local WATERBOLT       = { 31707 }
local WATER_FREEZE    = { 33395 }

local PET_SPECIALS = {
    { ids = PET_HOWL,    type = "howl" },
    { ids = PET_SCREECH, type = "screech" },
    { ids = PET_THUNDER, type = "thunderstomp" },
    { ids = PET_DASH,    type = "dash" },
    { ids = PET_DIVE,    type = "dive" },
}

-- ============================================================================
-- Per-spec state
-- ============================================================================
local function _get_state(spec)
    if not _states[spec] then
        _states[spec] = {
            state = STATE_IDLE,
            last_target_guid = nil,
            pet_spells_scanned = false,
            growl_id = nil,
            damage_id = nil,
            special_id = nil,
            special_type = nil,
            warlock_id = nil,
            warlock_type = nil,
            felguard_intercept_id = nil,
            felguard_anguish_id = nil,
            pet_type = nil,
            mage_waterbolt_id = nil,
            mage_freeze_id = nil,
            last_growl = 0,
            last_damage = 0,
            last_special = 0,
            last_warlock = 0,
            last_felguard_intercept = 0,
            last_felguard_anguish = 0,
            last_mage_freeze = 0,
            last_mage_waterbolt = 0,
            last_mend = 0,
            last_follow = 0,
            last_attack = 0,
            last_autocast_check = 0,
            autocast_enabled = {},
            last_stance_change = 0,
            current_stance = nil,
        }
    end
    return _states[spec]
end

-- ============================================================================
-- Core helpers
-- ============================================================================
function M.get_pet(me)
    if not me then return nil end
    local ok, p = pcall(function() return me:get_pet() end)
    return ok and p or nil
end

function M.pet_alive(p)
    if not p then return false end
    local ok, dead = pcall(p.is_dead, p)
    return ok and not dead
end

function M.pet_hp_pct(p)
    if not p then return 0 end
    local ok, hp = pcall(function() return p:get_health_percentage() end)
    return ok and hp or 0
end

-- ============================================================================
-- Spell casting (safe wrapper around pet_cast_target_spell)
-- ============================================================================
function M.try_cast(spell_id, target)
    if not spell_id then return false end
    -- Check spell cooldown via spell_book
    local cd = 0
    local ok, cd_val = pcall(function()
        return core and core.spell_book and core.spell_book.get_spell_cooldown
            and core.spell_book.get_spell_cooldown(spell_id)
    end)
    if ok and cd_val then cd = cd_val end
    if cd > 0 then return false end
    -- Check if pet is in range (skip if API unavailable)
    local in_range = true
    if core and core.spell_book and core.spell_book.get_pet_action_info then
        local ok_info, info = pcall(core.spell_book.get_pet_action_info, spell_id)
        if ok_info and info and info.checks_range and info.in_range ~= nil then
            in_range = info.in_range
        end
    end
    if not in_range then return false end
    if not target then return false end
    -- Cast via pet_cast_target_spell (Sylvanas API)
    local ok2 = pcall(function()
        return core and core.input and core.input.pet_cast_target_spell
            and core.input.pet_cast_target_spell(spell_id, target)
    end)
    return ok2
end

-- Cast a position-targeted pet spell (e.g., Mage Water Elemental Freeze).
-- @param spell_id  number  Spell ID to cast
-- @param position  vec3    World position to cast at
-- @return boolean  true if cast was attempted
function M.try_cast_position(spell_id, position)
    if not spell_id then return false end
    if not position then return false end
    local ok = pcall(function()
        return core and core.input and core.input.pet_cast_position_spell
            and core.input.pet_cast_position_spell(spell_id, position)
    end)
    return ok
end

-- ============================================================================
-- Autocast management: enable autocast on primary pet abilities
-- ============================================================================
local function _ensure_autocast_enabled(spell_ids, state)
    if not core or not core.input or not core.input.enable_pet_autocast then return end
    for _, id in ipairs(spell_ids) do
        if not state.autocast_enabled[id] then
            local ok, info = pcall(function()
                if core.spell_book and core.spell_book.get_pet_action_info then
                    return core.spell_book.get_pet_action_info(id)
                end
                return nil
            end)
            if ok and info and info.auto_cast_allowed and not info.auto_cast_enabled then
                local ok_enable = pcall(core.input.enable_pet_autocast, id)
                if ok_enable then
                    state.autocast_enabled[id] = true
                end
            else
                -- Mark as checked even if not applicable (prevents repeated checks)
                state.autocast_enabled[id] = true
            end
        end
    end
end

-- ============================================================================
-- Spell scanning
-- ============================================================================
local function _scan_hunter_spells(st)
    if st.pet_spells_scanned then return end
    -- Growl (taunt)
    for i = #PET_GROWL, 1, -1 do
        if NS.spell_id_is_known(PET_GROWL[i]) then st.growl_id = PET_GROWL[i]; break end
    end
    -- Damage ability (Claw > Bite > Gore > Lightning > Poison)
    for _, group in ipairs({ PET_CLAW, PET_BITE, PET_GORE, PET_LIGHTNING, PET_POISON }) do
        if not st.damage_id then
            for i = #group, 1, -1 do
                if NS.spell_id_is_known(group[i]) then st.damage_id = group[i]; break end
            end
        end
    end
    -- Special ability (Howl, Screech, Thunderstomp, Dash, Dive)
    for _, entry in ipairs(PET_SPECIALS) do
        if not st.special_id then
            for i = #entry.ids, 1, -1 do
                if NS.spell_id_is_known(entry.ids[i]) then
                    st.special_id = entry.ids[i]
                    st.special_type = entry.type
                    break
                end
            end
        end
    end
    -- Enable autocast on primary abilities (fallback if engine handles it)
    local autocast_ids = {}
    if st.growl_id then table.insert(autocast_ids, st.growl_id) end
    if st.damage_id then table.insert(autocast_ids, st.damage_id) end
    if st.special_id then table.insert(autocast_ids, st.special_id) end
    if #autocast_ids > 0 then _ensure_autocast_enabled(autocast_ids, st) end
    st.pet_spells_scanned = true
end

local function _scan_warlock_spells(st)
    if st.pet_spells_scanned then return end
    -- Scan for known warlock pet abilities
    -- Imp: Firebolt
    for i = #IMP_FIREBOLT, 1, -1 do
        if NS.spell_id_is_known(IMP_FIREBOLT[i]) then
            st.warlock_id = IMP_FIREBOLT[i]
            st.warlock_type = "firebolt"
            break
        end
    end
    -- Voidwalker: Taunt
    if not st.warlock_id then
        for i = #VW_TAUNT, 1, -1 do
            if NS.spell_id_is_known(VW_TAUNT[i]) then
                st.warlock_id = VW_TAUNT[i]
                st.warlock_type = "taunt"
                break
            end
        end
    end
    -- Succubus: Lash of Pain
    if not st.warlock_id then
        for i = #SUCC_LASH, 1, -1 do
            if NS.spell_id_is_known(SUCC_LASH[i]) then
                st.warlock_id = SUCC_LASH[i]
                st.warlock_type = "lash"
                break
            end
        end
    end
    -- Felguard: Cleave (primary DPS) + Intercept (gap closer) + Anguish (taunt)
    if not st.warlock_id then
        for i = #FELGUARD_CLEAVE, 1, -1 do
            if NS.spell_id_is_known(FELGUARD_CLEAVE[i]) then
                st.warlock_id = FELGUARD_CLEAVE[i]
                st.warlock_type = "cleave"
                break
            end
        end
    end
    if not st.felguard_intercept_id then
        for i = #FELGUARD_INTERCEPT, 1, -1 do
            if NS.spell_id_is_known(FELGUARD_INTERCEPT[i]) then
                st.felguard_intercept_id = FELGUARD_INTERCEPT[i]
                break
            end
        end
    end
    if not st.felguard_anguish_id then
        for i = #FELGUARD_ANGUISH, 1, -1 do
            if NS.spell_id_is_known(FELGUARD_ANGUISH[i]) then
                st.felguard_anguish_id = FELGUARD_ANGUISH[i]
                break
            end
        end
    end
    -- Felhunter: Bite
    if not st.warlock_id then
        for i = #FELHUNTER_BITE, 1, -1 do
            if NS.spell_id_is_known(FELHUNTER_BITE[i]) then
                st.warlock_id = FELHUNTER_BITE[i]
                st.warlock_type = "bite"
                break
            end
        end
    end
    -- Enable autocast on primary ability
    if st.warlock_id then _ensure_autocast_enabled({ st.warlock_id }, st) end
    st.pet_spells_scanned = true
end

local function _scan_mage_spells(st)
    if st.pet_spells_scanned then return end
    -- Water Elemental: Waterbolt
    for i = #WATERBOLT, 1, -1 do
        if NS.spell_id_is_known(WATERBOLT[i]) then
            st.mage_waterbolt_id = WATERBOLT[i]
            break
        end
    end
    -- Water Elemental: Freeze (AoE root)
    for i = #WATER_FREEZE, 1, -1 do
        if NS.spell_id_is_known(WATER_FREEZE[i]) then
            st.mage_freeze_id = WATER_FREEZE[i]
            break
        end
    end
    -- Enable autocast on Waterbolt (Freeze is better manually controlled)
    if st.mage_waterbolt_id then _ensure_autocast_enabled({ st.mage_waterbolt_id }, st) end
    st.pet_spells_scanned = true
end

-- ============================================================================
-- Stance helpers (via platform pet_handler or fallback) with deduplication
-- ============================================================================
-- Cached pet mode check to avoid redundant stance calls
local function _get_current_pet_mode()
    if core and core.spell_book and core.spell_book.get_pet_mode then
        local ok, mode = pcall(core.spell_book.get_pet_mode)
        if ok and type(mode) == "number" then return mode end
    end
    return nil
end

local function _set_pet_state(state_const, delay)
    if pet_handler and type(pet_handler.set_pet_state) == "function" then
        if pet_handler.pet_state and pet_handler.pet_state[state_const] then
            return pcall(pet_handler.set_pet_state, pet_handler, pet_handler.pet_state[state_const], delay or 0)
        end
    end
    return false
end

-- Stance constants (TBC: 0=passive, 1=defensive, 2=aggressive)
local PET_MODE_PASSIVE = 0
local PET_MODE_DEFENSIVE = 1
local PET_MODE_AGGRESSIVE = 2

function M.set_passive(delay)
    local mode = _get_current_pet_mode()
    if mode == PET_MODE_PASSIVE then return true end
    return _set_pet_state("PASSIVE", delay)
end
function M.set_aggressive(delay)
    local mode = _get_current_pet_mode()
    if mode == PET_MODE_AGGRESSIVE then return true end
    return _set_pet_state("AGGRESSIVE", delay)
end
function M.set_defensive(delay)
    local mode = _get_current_pet_mode()
    if mode == PET_MODE_DEFENSIVE then return true end
    return _set_pet_state("DEFENSIVE", delay)
end

-- ============================================================================
-- Main on_update: called every frame by dispatcher for hunter + warlock + mage
-- ============================================================================
function M.on_update(me, target, spec, context)
    if not me then return end
    if not context then return end

    local st = _get_state(spec or "default")
    local pet = M.get_pet(me)
    local now = NS.time_now and NS.time_now() or 0

    -- No pet or dead pet -> reset state and return
    if not pet or not M.pet_alive(pet) then
        st.state = STATE_IDLE
        st.last_target_guid = nil
        st.pet_spells_scanned = false
        st.autocast_enabled = {}
        st.current_stance = nil
        st.pet_type = nil
        return
    end

    -- Cache pet type once per frame (cheap; used for ability gating)
    st.pet_type = M.get_pet_type(pet)

    -- Scan spells once per spec (with autocast enable)
    local class_key = context.player_class_name or ""
    local class_lower = class_key:lower()
    if class_lower == "warlock" then
        _scan_warlock_spells(st)
    elseif class_lower == "mage" then
        _scan_mage_spells(st)
    else
        _scan_hunter_spells(st)
    end

    -- No target -> idle, but keep last_target_guid so we don't re-attack on tab-back
    if not target then
        st.state = STATE_IDLE
        return
    end

    -- Target must be engaged before we send pet (prevents pulling patrols)
    if not _engaged_with_player(context) then
        st.state = STATE_IDLE
        print("DEBUG: not engaged with player")
        return
    end

    local ok_guid, guid = pcall(function() return target:get_guid() end)
    guid = ok_guid and guid or nil

    -- Target changed or was nil -> send pet to attack (throttled to 1s)
    if guid and (st.last_target_guid ~= guid) then
        if now - st.last_attack > 1 then
            local ok = pcall(function()
                return core and core.input and core.input.pet_attack
                    and core.input.pet_attack(target)
            end)
            if ok then
                st.state = STATE_ENGAGING
                st.last_target_guid = guid
                st.last_attack = now
            end
        end
        return
    end

    -- Pet is already on this target -> cast abilities
    -- Hunter: Growl (taunt) every 5s — SKIP in group content (don't pull from tank)
    if st.growl_id and now - st.last_growl > 5 then
        local in_group = context.is_group or false
        if not in_group then
            if M.try_cast(st.growl_id, target) then
                st.last_growl = now
                return
            end
        end
    end

    -- Hunter: Damage ability every 2s
    if st.damage_id and now - st.last_damage > 2 then
        if M.try_cast(st.damage_id, target) then
            st.last_damage = now
            return
        end
    end

    -- Hunter: Special ability every 6s
    if st.special_id and now - st.last_special > 6 then
        if M.try_cast(st.special_id, target) then
            st.last_special = now
            return
        end
    end

    -- Warlock: Pet ability
    -- Imp Firebolt: 'machine gun' — cast immediately when NOT casting (no throttle).
    -- The TBC engine doesn't queue the next Firebolt after one finishes, so the
    -- Imp stands idle ~0.5s between casts. Community workaround: spam Firebolt
    -- every frame when the Imp is not casting. This eliminates the gap.
    -- Other warlock pets (Felguard/Succubus/VW/Felhunter): 2s throttle is fine.
    if st.warlock_id then
        local is_imp = st.warlock_type == "firebolt"
        if is_imp then
            -- Machine gun: check if pet is NOT casting, then immediately fire
            local pet_casting = false
            if pet and pet.is_casting_spell then
                local ok_c, casting = pcall(function() return pet:is_casting_spell() end)
                pet_casting = ok_c and casting or false
            end
            if not pet_casting then
                if M.try_cast(st.warlock_id, target) then
                    st.last_warlock = now
                    return
                end
            end
        else
            -- Non-Imp pets: 2s throttle
            if now - st.last_warlock > 2 then
                if M.try_cast(st.warlock_id, target) then
                    st.last_warlock = now
                    return
                end
            end
        end
    end

    -- Warlock Felguard: Intercept when target is at range (>8 yards).
    -- Gated by pet type (Felguard) and combat state.
    print("DEBUG Intercept check: pet_type=" .. tostring(st.pet_type) .. " in_combat=" .. tostring(context.in_combat) .. " intercept_id=" .. tostring(st.felguard_intercept_id) .. " last=" .. st.last_felguard_intercept .. " now=" .. now)
    if st.pet_type == "felguard" and context.in_combat and st.felguard_intercept_id and now - st.last_felguard_intercept > 15 then
        local at_range = false
        if me and target and me.get_distance then
            local ok_dist, dist = pcall(me.get_distance, me, target)
            if ok_dist and dist and dist > 8 then at_range = true end
        end
        if at_range then
            if M.try_cast(st.felguard_intercept_id, target) then
                st.last_felguard_intercept = now
                return
            end
        end
    end

    -- Warlock Felguard: Anguish (taunt) — SKIP in group content (don't pull from tank).
    -- Gated by pet type (Felguard) and combat state.
    if st.pet_type == "felguard" and context.in_combat and st.felguard_anguish_id and now - st.last_felguard_anguish > 5 then
        local in_group = context.is_group or false
        if not in_group then
            if M.try_cast(st.felguard_anguish_id, target) then
                st.last_felguard_anguish = now
                return
            end
        end
    end

    -- Mage Water Elemental: Freeze (AoE root) — ground-targeted spell.
    -- Community macro: /cast [@cursor] !Freeze — casts at cursor position.
    -- We cast at the target's current position using pet_cast_position_spell.
    if st.mage_freeze_id and now - st.last_mage_freeze > 25 then
        local target_rooted = false
        if target and NS.debuff_up then
            target_rooted = NS.debuff_up(target, { 33395, 122, 865, 6131, 10230, 27088 }) -- Freeze / Frost Nova ranks
        end
        if not target_rooted then
            local ok_pos, pos = pcall(function() return target:get_position() end)
            if ok_pos and pos then
                if M.try_cast_position(st.mage_freeze_id, pos) then
                    st.last_mage_freeze = now
                    return
                end
            end
        end
    end

    -- Mage Water Elemental: Waterbolt — machine gun (same as Imp Firebolt).
    -- Waterbolt has a 2.5s cast time and the TBC engine doesn't queue the
    -- next autocast, so the Water Elemental stands idle ~0.5s between casts.
    -- Fix: check if pet is NOT casting, then immediately fire Waterbolt.
    if st.mage_waterbolt_id then
        local pet_casting = false
        if pet and pet.is_casting_spell then
            local ok_c, casting = pcall(function() return pet:is_casting_spell() end)
            pet_casting = ok_c and casting or false
        end
        if not pet_casting then
            if M.try_cast(st.mage_waterbolt_id, target) then
                st.last_mage_waterbolt = now
                return
            end
        end
    end

    st.state = STATE_FIGHTING
end

-- ============================================================================
-- Warlock-specific: auto-summon helpers
-- ============================================================================
function M.needs_summon(me, desired_pet_spell)
    if not me then return false end
    local ok, has_pet = pcall(function() return me:has_pet() end)
    if ok and has_pet then
        local pet = M.get_pet(me)
        if pet and M.pet_alive(pet) then return false end
    end
    if not desired_pet_spell then return false end
    return NS.spell_ready and NS.spell_ready(desired_pet_spell, me, { skip_range = true }) or false
end

-- ============================================================================
-- Pet info helpers for specs
-- ============================================================================
function M.get_pet_mode()
    if core and core.spell_book and core.spell_book.get_pet_mode then
        local ok, mode = pcall(core.spell_book.get_pet_mode)
        if ok and type(mode) == "number" then return mode end
    end
    return nil
end

function M.get_pet_spells()
    if core and core.spell_book and core.spell_book.get_pet_spells then
        local ok, spells = pcall(core.spell_book.get_pet_spells)
        if ok and type(spells) == "table" then return spells end
    end
    return {}
end

function M.get_pet_action_info(spell_id)
    if not spell_id then return nil end
    if core and core.spell_book and core.spell_book.get_pet_action_info then
        local ok, info = pcall(core.spell_book.get_pet_action_info, spell_id)
        if ok and type(info) == "table" then return info end
    end
    return nil
end

-- ============================================================================
-- Pet type detection
-- ============================================================================

-- Detect the active pet's type by inspecting its known spells.
-- Returns one of: "imp", "voidwalker", "succubus", "felhunter", "felguard", or nil.
function M.get_pet_type(pet)
    if not pet then return nil end
    -- Use cached value when the pet GUID hasn't changed.
    local guid_ok, guid = pcall(function() return pet:get_guid() end)
    if guid_ok and guid and _pet_type_cache.guid == guid and _pet_type_cache.type ~= nil then
        return _pet_type_cache.type
    end

    -- Try to read the pet's spell list from the engine.
    local spells = nil
    if core and core.spell_book and core.spell_book.get_pet_spells then
        local ok, sp = pcall(core.spell_book.get_pet_spells)
        if ok and type(sp) == "table" then spells = sp end
    end
    -- Fallback: some builds expose spells on the pet object.
    if not spells then
        local ok, sp = pcall(function() return pet.get_spells and pet:get_spells() end)
        if ok and type(sp) == "table" then spells = sp end
    end
    if not spells then
        if guid_ok and guid then
            _pet_type_cache.guid = guid
            _pet_type_cache.type = nil
        end
        return nil
    end

    local known = {}
    for _, id in ipairs(spells) do known[id] = true end
    for type_name, ids in pairs(PET_TYPE_SPELLS) do
        for _, id in ipairs(ids) do
            if known[id] then
                if guid_ok and guid then
                    _pet_type_cache.guid = guid
                    _pet_type_cache.type = type_name
                end
                return type_name
            end
        end
    end
    if guid_ok and guid then
        _pet_type_cache.guid = guid
        _pet_type_cache.type = nil
    end
    return nil
end

-- Convenience predicates for gating pet abilities by type.
function M.is_pet_type(pet, type_name)
    return M.get_pet_type(pet) == type_name
end

return M
