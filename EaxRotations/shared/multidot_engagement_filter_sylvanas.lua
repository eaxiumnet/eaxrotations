-- multidot_engagement_filter_sylvanas.lua � Safe enemy filtering for multi-DoT spread.
-- WHAT:   Filters enemy lists to only include mobs actively engaged with the player,
--         their pet, or their party. Prevents pulling patrols/wanderers via DoT spread.
-- WHEN:   Called by spec build_state or match functions before casting DoTs on secondary targets.
-- WHY:    NS.GetEnemiesInRange includes out-of-combat mobs; dotting them pulls unintended packs.
-- SAFETY: All game_object calls are pcall-wrapped; static table reuse; 0.5s party/pet cache TTL.
-- DECISION: Pure helper consumed via require(); no on_update side-effects.

local M = {}
local NS = _G.EaxRotations
if not NS then return M end

local _time_now = NS.time_now or (function() return 0 end)
local _same_unit = NS.same_unit or function(a, b) return a == b end
local _debuff_up = NS.debuff_up or function() return false end

-- ============================================================================
-- Internal caches (throttle expensive repeated calls)
-- ============================================================================
local _cached_party = nil
local _cached_party_time = 0
local _cached_pet = nil
local _cached_pet_time = 0
local _PARTY_TTL = 0.5
local _PET_TTL = 1.0

-- Static reusable tables (Pattern 4)
local _out_engaged = { n = 0 }
local _out_multidot = { n = 0 }

-- ============================================================================
-- Party / Pet cache helpers
-- ============================================================================
local function get_cached_party()
    local now = _time_now()
    if _cached_party and (now - _cached_party_time) < _PARTY_TTL then
        return _cached_party
    end
    local party = nil
    if NS.GetPartyMembers then
        local ok, result = pcall(NS.GetPartyMembers)
        if ok and type(result) == "table" then party = result end
    end
    _cached_party = party
    _cached_party_time = now
    return party
end

local function get_cached_pet()
    local now = _time_now()
    if _cached_pet and (now - _cached_pet_time) < _PET_TTL then
        return _cached_pet
    end
    local pet = nil
    if NS.GetPet then
        local ok, result = pcall(NS.GetPet)
        if ok and result and type(result) == "table" then pet = result end
    end
    _cached_pet = pet
    _cached_pet_time = now
    return pet
end

local _cached_raid = nil
local _cached_raid_time = 0
local _RAID_TTL = 1.0

local function get_cached_raid()
    local now = _time_now()
    if _cached_raid and (now - _cached_raid_time) < _RAID_TTL then
        return _cached_raid
    end
    local raid = nil
    if NS.GetRaidMembers then
        local ok, result = pcall(NS.GetRaidMembers)
        if ok and type(result) == 'table' then raid = result end
    end
    _cached_raid = raid
    _cached_raid_time = now
    return raid
end

-- ============================================================================
-- Core engagement check
-- ============================================================================

--- Determine if an enemy is actively engaged with the player/party/pet.
--
-- Engagement hierarchy (strong ? weak):
--   1. enemy:is_in_combat()  � fast reject if false
--   2. enemy:get_target() == me|pet|party|raid_member  � ONLY pass condition in strict mode
--   3. (lenient only) both enemy and player in combat � only when get_target() unavailable
--   
--   NOTE: hp < 100 is NOT used as an engagement signal. A damaged mob fighting a
--   stranger would pass that check and cause us to "help" them. We only dot mobs
--   whose current target is in our group (or us personally).
--
-- @param enemy       game_object|nil  The enemy to check
-- @param me          game_object|nil  The local player
-- @param party       table|nil        Party member list (optional; cached if nil)
-- @param pet         game_object|nil  Player pet (optional; cached if nil)
-- @param strictness  string|nil       "strict" (default) or "lenient"
-- @return boolean  true if the enemy is safe to dot (confirmed combatant)
function M.is_engaged_with_us(enemy, me, party, pet, strictness)
    if not enemy then return false end
    strictness = strictness or "strict"

    local has_combat_method = type(enemy.is_in_combat) == "function"
    local has_target_method = type(enemy.get_target) == "function"

    -- 1. Fast reject: must be in combat (only if method exists)
    if has_combat_method then
        local ok_combat, in_combat = pcall(function()
            return enemy:is_in_combat()
        end)
        if not ok_combat or not in_combat then return false end
    end

    -- 2. CRITICAL: enemy MUST be targeting me, my pet, or a party/raid member.
    --    This prevents "helping" random strangers fighting nearby mobs.
    if has_target_method then
        local ok_target, enemy_target = pcall(function()
            return enemy:get_target()
        end)
        if ok_target and enemy_target then
            if me and _same_unit(enemy_target, me) then return true end
            if pet and _same_unit(enemy_target, pet) then return true end

            local members = party or get_cached_party()
            if members and type(members) == "table" then
                for i = 1, #members do
                    local member = members[i]
                    if member and _same_unit(enemy_target, member) then
                        return true
                    end
                end
            end

            local raid_members = get_cached_raid()
            if raid_members and type(raid_members) == "table" then
                for i = 1, #raid_members do
                    local member = raid_members[i]
                    if member and _same_unit(enemy_target, member) then
                        return true
                    end
                end
            end

            -- Target is known but is NOT us / pet / party / raid -> explicitly deny.
            -- We never help strangers, escort NPCs, or random friendlies.
            return false
        end
    end

    -- 3. Lenient fallback: target determination failed, but both we and enemy are in combat.
    --    Only used when get_target() is unavailable or errors (rare in production).
    if strictness == "lenient" then
        local ok_me, me_in_combat = pcall(function()
            return me and me.is_in_combat and me:is_in_combat()
        end)
        if ok_me and me_in_combat then return true end
    end

    -- 4. Stub fallback: no game_object methods (test stubs / raw tables) -> allow through.
    if not has_combat_method and not has_target_method then
        return true
    end

    return false
end

-- ============================================================================
-- Batch filter: return only engaged enemies from a raw list
-- ============================================================================

--- Filter a list of enemies to only those engaged with us.
--
-- @param enemies     table    Raw enemy list (array-like, may have .n count)
-- @param me          game_object|nil  Local player
-- @param opts        table|nil  Options:
--                    - strictness: "strict"|"lenient" (default "strict")
--                    - skip_cc_debuffs: table|nil  CC debuff ID arrays to skip
--                    - skip_tapped: boolean  Skip tap-denied mobs (leveling)
--                    - ctx: table|nil  Rotation context (for tap-denied check)
-- @return table  Array-like table with .n count of engaged enemies
function M.filter_engaged_enemies(enemies, me, opts)
    opts = opts or {}
    local strictness = opts.strictness or "strict"
    local skip_cc = opts.skip_cc_debuffs
    local skip_tapped = opts.skip_tapped or false
    local ctx = opts.ctx

    -- Reset static output table
    _out_engaged.n = 0
    for k in pairs(_out_engaged) do
        if k ~= "n" then _out_engaged[k] = nil end
    end

    local party = get_cached_party()
    local pet = get_cached_pet()
    local raid = get_cached_raid()
    local count = type(enemies) == "table" and (enemies.n or #enemies) or 0
    for i = 1, count do
        local enemy = enemies[i]
        if enemy then
            -- Validity check
            local ok_valid, valid = pcall(function()
                return enemy.is_valid and enemy:is_valid()
            end)
            -- Fails open for test stubs / raw tables without is_valid
            local is_valid = (ok_valid and valid) or (not ok_valid) or (ok_valid and not enemy.is_valid)
            if is_valid then
                -- CC skip
                local cc_skip = false
                if skip_cc and _debuff_up then
                    for _, cc_ids in ipairs(skip_cc) do
                        if _debuff_up(enemy, cc_ids) then
                            cc_skip = true
                            break
                        end
                    end
                end
                if not cc_skip then
                    -- Tap-denied skip (leveling)
                    local tapped_skip = false
                    if skip_tapped and ctx and ctx.is_leveling then
                        if NS.Targeting and NS.Targeting.is_tapped then
                            tapped_skip = NS.Targeting.is_tapped(enemy)
                        end
                    end
                    if not tapped_skip then
                        if M.is_engaged_with_us(enemy, me, party, pet, strictness, raid) then
                            _out_engaged.n = _out_engaged.n + 1
                            _out_engaged[_out_engaged.n] = enemy
                        end
                    end
                end
            end
        end
    end

    return _out_engaged
end

-- ============================================================================
-- Multi-DoT target finder (drop-in replacement for per-spec _find_multidot_target)
-- ============================================================================

--- Find the best secondary target missing a given debuff, restricting to engaged enemies.
--
-- Two-pass search:
--   Pass 1: prefer enemies that are NOT the current target (real spread)
--   Pass 2: allow current target if it needs refresh
--
-- @param context     table    Rotation context (needs .target, .me)
-- @param debuff_ids  table    Array of debuff spell IDs to check
-- @param range       number|nil  Scan range in yards (default 30)
-- @param opts        table|nil  Options:
--                    - strictness: "strict"|"lenient"
--                    - skip_cc_debuffs: table|nil
--                    - skip_tapped: boolean
--                    - prefer_damaged: boolean  Prefer lower-HP enemies (default true)
-- @return game_object|nil  Best target to dot, or nil if none found
function M.find_multidot_target(context, debuff_ids, range, opts)
    opts = opts or {}
    if not context then return nil end
    if not NS.GetEnemiesInRange then return nil end

    range = range or 30
    local me = context.me
    local current = context.target

    -- Get raw enemies
    local raw_enemies = NS.GetEnemiesInRange(range)
    if type(raw_enemies) ~= "table" or (raw_enemies.n or #raw_enemies) == 0 then
        return nil
    end

    -- Filter to engaged only
    local engaged = M.filter_engaged_enemies(raw_enemies, me, {
        strictness = opts.strictness,
        skip_cc_debuffs = opts.skip_cc_debuffs,
        skip_tapped = opts.skip_tapped,
        ctx = context,
    })
    local engaged_count = engaged.n or #engaged
    if engaged_count == 0 then return nil end

    local prefer_damaged = opts.prefer_damaged ~= false
    local best_pass1 = nil
    local best_pass1_hp = 100
    local best_pass2 = nil
    local best_pass2_hp = 100

    for i = 1, engaged_count do
        local enemy = engaged[i]
        if enemy then
            local is_current = current and _same_unit(enemy, current)
            local has_debuff = _debuff_up(enemy, debuff_ids)
            if not has_debuff then
                local hp = 100
                if prefer_damaged then
                    local ok, val = pcall(function()
                        return enemy.get_health_percentage and enemy:get_health_percentage()
                    end)
                    if ok and type(val) == "number" then hp = val end
                end
                if is_current then
                    if hp <= best_pass2_hp then
                        best_pass2 = enemy
                        best_pass2_hp = hp
                    end
                else
                    if hp <= best_pass1_hp then
                        best_pass1 = enemy
                        best_pass1_hp = hp
                    end
                end
            end
        end
    end

    return best_pass1 or best_pass2 or nil
end

-- ============================================================================
-- Count engaged enemies (convenience for state-building)
-- ============================================================================

--- Count how many enemies in range are actively engaged with us.
--
-- @param context     table    Rotation context
-- @param range       number|nil  Scan range (default 30)
-- @param strictness  string|nil  "strict"|"lenient"
-- @return number  Count of engaged enemies
function M.count_engaged_enemies(context, range, strictness)
    if not context or not NS.GetEnemiesInRange then return 0 end
    range = range or 30
    local raw = NS.GetEnemiesInRange(range)
    if type(raw) ~= "table" or (raw.n or #raw) == 0 then return 0 end
    local engaged = M.filter_engaged_enemies(raw, context.me, {
        strictness = strictness,
        ctx = context,
    })
    return engaged.n or #engaged or 0
end

-- ============================================================================
-- Export
-- ============================================================================

NS.MultiDotEngagement = M
return M

