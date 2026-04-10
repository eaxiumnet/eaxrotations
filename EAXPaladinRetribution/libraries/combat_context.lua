-- libraries/combat_context.lua
-- Combat context builder for EAXPaladinRetribution
-- Follows AGENTS.md Pattern 6: 2s throttle, API caching, squared distance, static tables

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

-- ============================================================================
-- 1. API CACHING AT MODULE LOAD (Pattern 2)
-- ============================================================================
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_enemies = core.object_manager.get_enemy_list
local _get_visible_objects = core.object_manager.get_visible_objects

-- ============================================================================
-- 2. STATIC TABLES FOR REUSE (Pattern 4)
-- ============================================================================
local _enemy_list = { n = 0 }
local _party_members = { n = 0 }

-- ============================================================================
-- 3. CACHE VARIABLES (Pattern 6)
-- ============================================================================
local _last_build_time = 0
local _cached_context = nil

-- ============================================================================
-- 4. SQUARED DISTANCE HELPER (Pattern 3)
-- ============================================================================
local function dist_squared(a, b)
    if not a or not b then return math.huge end
    local ok_a, a_pos = pcall(function() return a:get_position() end)
    local ok_b, b_pos = pcall(function() return b:get_position() end)
    if not ok_a or not a_pos or not ok_b or not b_pos then return math.huge end

    local dx = a_pos.x - b_pos.x
    local dy = a_pos.y - b_pos.y
    local dz = a_pos.z - b_pos.z
    return dx * dx + dy * dy + dz * dz
end

-- ============================================================================
-- 5. MAIN BUILD FUNCTION WITH 2S THROTTLE (Pattern 6)
-- ============================================================================
local function build(me)
    local now = _core_time()

    -- Return cached context if within 2s throttle
    if _cached_context and (now - _last_build_time) <= 2 then
        return _cached_context
    end

    -- Clear static tables (reuse, don't recreate)
    _enemy_list.n = 0
    _party_members.n = 0

    local ctx = {
        -- Time
        time = now,
        combat_time = 0,

        -- Player state
        me = me,
        hp = 100,
        max_hp = 0,
        mana = 0,
        mana_pct = 0,
        in_combat = false,

        -- Target state
        target = nil,
        has_target = false,
        target_hp = 100,
        target_max_hp = 0,
        in_melee_range = false,
        target_is_player = false,
        target_classification = "normal",
        target_is_casting = false,

        -- Threat
        threat_pct = 0,
        threat_status = 0,
        has_aggro = false,

        -- Combat context
        enemy_count = 0,
        enemies = {},
        melee_enemies = 0,
        incoming_dps = 0,

        -- Party context
        party_size = 0,
        party_members = {},

        -- Retribution-specific: Seal twisting state
        seal_twist_window = false,
        time_to_swing = 0,
        swing_speed = 3.5,
        current_seal = nil,
        twist_ready = false,

        -- Retribution-specific: Vengeance tracking
        vengeance_stacks = 0,
        vengeance_remains = 0,

        -- Retribution-specific: Cooldown tracking
        crusader_strike_cd = 0,
        judgement_cd = 0,
        divine_storm_cd = 0,

        -- Settings cache
        settings = {},
    }

    -- === PLAYER STATE ===
    if me and me:is_valid() then
        local ok_hp, hp = pcall(function() return me:get_health_percentage() end)
        ctx.hp = ok_hp and hp or 100

        local ok_max_hp, max_hp = pcall(function() return me:get_max_health() end)
        ctx.max_hp = ok_max_hp and max_hp or 0

        local ok_combat, in_combat = pcall(function() return me:is_in_combat() end)
        ctx.in_combat = ok_combat and in_combat or false

        -- Mana for paladin
        local ok_mana, mana = pcall(function() return me:get_power(0) end)
        local ok_max_mana, max_mana = pcall(function() return me:get_max_power(0) end)
        if ok_mana then
            ctx.mana = mana
            if ok_max_mana and max_mana > 0 then
                ctx.mana_pct = mana / max_mana
            end
        end

        -- Get weapon speed for swing timing
        local ok_weapon, weapon = pcall(me.get_weapon_info, me, 0)
        if ok_weapon and weapon and weapon.speed then
            ctx.swing_speed = weapon.speed
        end
    end

    -- === TARGET STATE ===
    if me and me:is_valid() then
        local ok_target, target = pcall(function() return me:get_target() end)
        if ok_target and target then
            local ok_valid, is_valid = pcall(function() return target:is_valid() end)
            local ok_dead, is_dead = pcall(function() return target:is_dead() end)

            if ok_valid and is_valid and not (ok_dead and is_dead) then
                ctx.target = target
                ctx.has_target = true

                local ok_thp, thp = pcall(function() return target:get_health_percentage() end)
                ctx.target_hp = ok_thp and thp or 100

                local ok_tmax, tmax = pcall(function() return target:get_max_health() end)
                ctx.target_max_hp = ok_tmax and tmax or 0

                -- Squared distance check (Pattern 3)
                local dist_sq = dist_squared(me, target)
                ctx.in_melee_range = dist_sq <= 25  -- 5 yards squared

                local ok_player, is_player = pcall(function() return target:is_player() end)
                ctx.target_is_player = ok_player and is_player or false

                local ok_class, class = pcall(function() return target:get_classification() end)
                ctx.target_classification = ok_class and class or "normal"

                local ok_casting, is_casting = pcall(function() return target:is_casting() end)
                ctx.target_is_casting = ok_casting and is_casting or false

                -- Threat data
                if target.get_threat_situation then
                    local ok_threat, threat_data = pcall(function() return target:get_threat_situation(me) end)
                    if ok_threat and threat_data then
                        ctx.threat_pct = threat_data.threat_percent or 0
                        ctx.threat_status = threat_data.status or 0
                        ctx.has_aggro = ctx.threat_status >= 3
                    end
                else
                    -- Fallback: check target's target
                    local ok_tt, target_target = pcall(function() return target:get_target() end)
                    if ok_tt and target_target then
                        local ok_ttv, ttv_valid = pcall(function() return target_target:is_valid() end)
                        if ok_ttv and ttv_valid then
                            if target_target == me then
                                ctx.threat_status = 3
                                ctx.has_aggro = true
                            else
                                ctx.threat_status = 1
                            end
                        end
                    end
                end
            end
        end
    end

    -- === ENEMY SCANNING WITH STATIC TABLE (Pattern 4) ===
    local objects = _get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj then
            local ok_valid, is_valid = pcall(function() return obj:is_valid() end)
            local ok_unit, is_unit = pcall(function() return obj:is_unit() end)
            local ok_dead, is_dead = pcall(function() return obj:is_dead() end)

            if ok_valid and is_valid and ok_unit and is_unit and not (ok_dead and is_dead) then
                local ok_attack, can_attack = pcall(function() return me:can_attack(obj) end)
                if ok_attack and can_attack then
                    -- Add to static enemy list
                    _enemy_list.n = _enemy_list.n + 1
                    _enemy_list[_enemy_list.n] = obj

                    -- Check melee range (squared distance)
                    local dist_sq = dist_squared(me, obj)
                    if dist_sq <= 25 then  -- 5 yards squared
                        ctx.melee_enemies = ctx.melee_enemies + 1
                    end
                end
            end
        end
    end

    ctx.enemy_count = _enemy_list.n
    ctx.enemies = _enemy_list

    -- === PARTY/RAID CONTEXT ===
    if me and me.get_party_member then
        for i = 1, 4 do
            local ok_member, member = pcall(function() return me:get_party_member(i) end)
            if ok_member and member then
                local ok_valid, is_valid = pcall(function() return member:is_valid() end)
                if ok_valid and is_valid then
                    _party_members.n = _party_members.n + 1
                    _party_members[_party_members.n] = member
                end
            end
        end
    end
    ctx.party_size = _party_members.n
    ctx.party_members = _party_members

    -- === RETRIBUTION-SPECIFIC: SEAL TWISTING STATE ===
    -- Check for active seal
    if me and me.has_aura then
        local seal_ids = {
            20375,  -- Seal of Command
            31892,  -- Seal of Blood
            53720,  -- Seal of Martyr
            31801,  -- Seal of Vengeance
            348704, -- Seal of Corruption
            21084,  -- Seal of Righteousness
            20305,  -- Seal of the Crusader
            20165,  -- Seal of Wisdom
        }

        for _, seal_id in ipairs(seal_ids) do
            local ok_has, has_seal = pcall(function() return me:has_aura(seal_id) end)
            if ok_has and has_seal then
                ctx.current_seal = seal_id
                break
            end
        end

        -- Check Vengeance stacks (Retribution talent)
        local ok_veng, veng_data = pcall(function() return buff_manager:get_buff_data(me, {20057, 20056, 20055}) end)
        if ok_veng and veng_data then
            ctx.vengeance_stacks = veng_data.stacks or 0
            ctx.vengeance_remains = veng_data.remains or 0
        end
    end

    -- === RETRIBUTION-SPECIFIC: SWING TIMER DATA ===
    -- Estimate time to next swing for seal twisting window
    if ctx.swing_speed > 0 then
        -- Default estimate: assume swing just happened, next in swing_speed
        ctx.time_to_swing = ctx.swing_speed * 0.5  -- Rough estimate

        -- Seal twist window: 0.4s before swing lands
        ctx.seal_twist_window = ctx.time_to_swing <= 0.4 and ctx.time_to_swing > 0
        ctx.twist_ready = ctx.seal_twist_window and ctx.current_seal ~= nil
    end

    -- Cache and return
    _cached_context = ctx
    _last_build_time = now
    return ctx
end

-- ============================================================================
-- 6. UTILITY FUNCTIONS
-- ============================================================================

---Clear the cached context (call on zone change, combat end, etc.)
local function clear_cache()
    _cached_context = nil
    _last_build_time = 0
    _enemy_list.n = 0
    _party_members.n = 0
end

---Count enemies within radius using squared distance
---@param me game_object
---@param radius number Radius in yards
---@return number count
local function count_enemies_in_radius(me, radius)
    local radius_sq = radius * radius
    local count = 0
    local objects = _get_visible_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj then
            local ok_valid, is_valid = pcall(function() return obj:is_valid() end)
            local ok_unit, is_unit = pcall(function() return obj:is_unit() end)
            local ok_dead, is_dead = pcall(function() return obj:is_dead() end)

            if ok_valid and is_valid and ok_unit and is_unit and not (ok_dead and is_dead) then
                local ok_attack, can_attack = pcall(function() return me:can_attack(obj) end)
                if ok_attack and can_attack then
                    local dist_sq = dist_squared(me, obj)
                    if dist_sq <= radius_sq then
                        count = count + 1
                    end
                end
            end
        end
    end

    return count
end

---Get debuff data for a target
---@param target game_object
---@param debuff_ids table Array of spell IDs
---@return table|nil debuff_data
local function get_debuff_data(target, debuff_ids)
    if not target then return nil end
    local ok, is_valid = pcall(function() return target:is_valid() end)
    if not ok or not is_valid then return nil end
    return buff_manager:get_debuff_data(target, debuff_ids)
end

---Get buff data for a unit
---@param unit game_object
---@param buff_ids table Array of spell IDs
---@return table|nil buff_data
local function get_buff_data(unit, buff_ids)
    if not unit then return nil end
    local ok, is_valid = pcall(function() return unit:is_valid() end)
    if not ok or not is_valid then return nil end
    return buff_manager:get_buff_data(unit, buff_ids)
end

-- ============================================================================
-- 7. EXPORT
-- ============================================================================
local combat_context = {
    build = build,
    clear_cache = clear_cache,
    dist_squared = dist_squared,
    count_enemies_in_radius = count_enemies_in_radius,
    get_debuff_data = get_debuff_data,
    get_buff_data = get_buff_data,
}

return combat_context
