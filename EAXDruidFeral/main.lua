-- EAX Druid Feral | Project Sylvanas
-- Priority: Prowl -> Ravage -> DoTs -> Finishers -> Builders

-- Load header first to check if we should load at all
local header = require("header")
if not header.load then
    return
end

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local energy_tick = require("libraries/energy_tick")
local powershift = require("libraries/powershift")
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")
local swing_manager = require("libraries/swing_manager")  -- v1.8.13: For swing delay feature
local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")
local ooc_manager = require("libraries/ooc_manager")
local form_consumables = require("libraries/form_consumables")
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

-- Runtime state
local rt = {
    last_spell_refresh = 0,
    cached_mode = "solo",
    prev_toggle_state = false,
    combat_start_time = nil,
    -- Spell IDs
    shred_id = nil,
    rake_id = nil,
    rip_id = nil,
    ferocious_bite_id = nil,
    mangle_cat_id = nil,
    tigers_fury_id = nil,
    prowl_id = nil,
    ravage_id = nil,
    cat_form_id = nil,
    faerie_fire_id = nil,
    -- PvP Spell IDs
    entangling_roots_id = nil,
    hibernate_id = nil,
    -- State
    last_powershift_time = 0,
    pvp_context = nil,
    saved_form = nil,  -- For form_consumables restoration
    spell_costs = {
        shred = 42,
        mangle = 40,
        rake = 35,
        rip = 30,
        ferocious_bite = 35,
        ravage = 60,
        tigers_fury = 30,
    },
    -- DoT max durations for pandemic calculation
    dot_durations = {
        rake = 9,  -- Rake lasts 9 seconds
        rip = 12,  -- Rip lasts 12 seconds
    },
    -- Enemy count for AoE decisions
    enemy_count = 1,
    is_boss = false,
}

local SPELL_REFRESH = 1.0
local MODE_REFRESH = 4.5
local ENERGY_TICK = 2.0
local SHIFT_COOLDOWN = 1.0

-- Helpers
local function get_me() return _get_local_player() end

-- ============================================================================
-- v1.8.13: Swing Delay Check Utility
-- ============================================================================

---Check if we should delay ability to avoid clipping auto-attack swing
---Uses swing_manager for timing (0.15s threshold like flux)
---@param me userdata Player unit
---@return boolean True if swing landing soon and we should delay
local function should_delay_for_swing(me)
    -- Check if swing delay is enabled in menu
    if menu.cat_swing_delay then
        local ok, enabled = pcall(function() return menu.cat_swing_delay:get_state() end)
        if not ok or not enabled then
            return false
        end
    else
        return false  -- Toggle doesn't exist, don't delay
    end
    
    -- Use swing_manager to check if swing landing soon
    if swing_manager and swing_manager.is_swing_landing_soon then
        local ok, should_delay = pcall(function() return swing_manager:is_swing_landing_soon(0.15) end)
        if ok then return should_delay end
    end
    
    -- Fallback: try auto_attack_helper directly
    local has_helper, helper = pcall(require, "common/utility/auto_attack_helper")
    if has_helper and helper and helper.get_next_attack_core_time then
        local ok, next_swing = pcall(function() return helper:get_next_attack_core_time(me, 1) end)
        if ok and next_swing then
            local time_until = next_swing - _core_time()
            return time_until > 0 and time_until <= 0.15
        end
    end
    
    return false
end

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now

    local function get_spell_cost(spell_id, fallback)
        if not spell_id then return fallback end
        if core.spell_book and core.spell_book.get_spell_power_cost then
            local cost = core.spell_book.get_spell_power_cost(spell_id)
            if cost and cost > 0 then return cost end
        end
        return fallback
    end

    rt.shred_id = utils.resolve_spell_id(spells.SHRED)
    rt.rake_id = utils.resolve_spell_id(spells.RAKE)
    rt.rip_id = utils.resolve_spell_id(spells.RIP)
    rt.ferocious_bite_id = utils.resolve_spell_id(spells.FEROCIOUS_BITE)
    rt.mangle_cat_id = utils.resolve_spell_id(spells.MANGLE_CAT)
    rt.tigers_fury_id = utils.resolve_spell_id(spells.TIGERS_FURY)
    rt.prowl_id = utils.resolve_spell_id(spells.PROWL)
    rt.ravage_id = utils.resolve_spell_id(spells.RAVAGE)
    rt.cat_form_id = utils.resolve_spell_id(spells.CAT_FORM)
    rt.faerie_fire_id = utils.resolve_spell_id(spells.FAERIE_FIRE_FERAL) or utils.resolve_spell_id(spells.FAERIE_FIRE)
    
    -- PvP spells
    rt.entangling_roots_id = utils.resolve_spell_id(spells.ENTANGLING_ROOTS)
    rt.hibernate_id = utils.resolve_spell_id(spells.HIBERNATE)
    
    -- Form spell IDs (for form_consumables)
    rt.bear_form_id = utils.resolve_spell_id(spells.BEAR_FORM)
    rt.dire_bear_form_id = utils.resolve_spell_id(spells.DIRE_BEAR_FORM)

    rt.spell_costs.shred = get_spell_cost(rt.shred_id, 42)
    rt.spell_costs.mangle = get_spell_cost(rt.mangle_cat_id, 40)
    rt.spell_costs.rake = get_spell_cost(rt.rake_id, 35)
    rt.spell_costs.rip = get_spell_cost(rt.rip_id, 30)
    rt.spell_costs.ferocious_bite = get_spell_cost(rt.ferocious_bite_id, 35)
    rt.spell_costs.ravage = get_spell_cost(rt.ravage_id, 60)
    rt.spell_costs.tigers_fury = get_spell_cost(rt.tigers_fury_id, 30)

    -- Update energy tick module with current spell costs
    energy_tick.update_spell_costs(rt.spell_costs.mangle, rt.spell_costs.shred)

    -- OOC buffs
    rt.thorns_id = utils.resolve_spell_id(spells.THORNS)
end

local function energy(me)
    return utils.get_energy(me)
end

local function combo_points(me)
    return utils.get_combo_points(me)
end

local function has_debuff(target, tbl)
    return utils.has_debuff(target, tbl)
end

local function debuff_rem(target, tbl)
    if not target or not target:is_valid() then return 0 end
    local ok_d, d = pcall(function() return target:get_debuff_data(tbl) end)
    if not ok_d then d = nil end
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    local ok_a, d = pcall(function() return target:get_aura_data(tbl) end)
    if not ok_a then d = nil end
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    return 0
end

local function is_stealthed(me)
    return utils.has_buff(me, spells.BUFF_PROWL)
end

local function detect_mode()
    local n = 0
    local ok_objects, all_objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then all_objects = {} end
    for _, o in ipairs(all_objects) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() and o:is_party_member() then
            n = n + 1
        end
    end
    if n == 0 then return "solo" elseif n <= 4 then return "dungeon" end
    return "raid"
end

local function active_mode()
    local ok, s = pcall(function() return menu.mode:get() end)
    if not ok then s = 1 end
    if s == 2 then return "solo" elseif s == 3 then return "dungeon" elseif s == 4 then return "raid" end
    return rt.cached_mode
end

-- ============================================================================
-- Dynamic DoT Refresh with Pandemic (Feature 4 from flux cat.lua)
-- ============================================================================

---Calculate dynamic DoT refresh threshold (accounts for GCD and pandemic)
---From flux cat.lua lines 216-222
---@param user_setting number User-configured refresh threshold (seconds)
---@param max_duration number|nil Maximum DoT duration for pandemic window calculation
---@return number Adjusted refresh threshold
local function get_dot_refresh_threshold(user_setting, max_duration)
    -- Get current GCD
    local gcd_remains = 0
    if core.spell_book and core.spell_book.get_global_cooldown then
        local ok, gcd = pcall(core.spell_book.get_global_cooldown)
        if ok and gcd then
            gcd_remains = gcd
        end
    end
    
    local threshold = user_setting + gcd_remains
    if max_duration then
        threshold = math.max(threshold, max_duration * 0.3)  -- Pandemic: 30% of max duration
    end
    return threshold
end

-- ============================================================================
-- Enemy Count and Boss Detection (for AoE and Sapper decisions)
-- ============================================================================

---Update enemy count and boss status for AoE/sapper decisions
---@param me userdata Player unit
---@param target userdata Current target
local function update_combat_context(me, target)
    -- Count enemies near target
    local count = 1  -- Start with current target
    local is_boss = false
    local is_elite = false
    
    if target and target:is_valid() then
        -- Check if target is boss/elite
        local ok_class, classification = pcall(function() return target:get_classification() end)
    if not ok_class then classification = nil end
        if target.get_classification then
            local ok, cls = pcall(function() return target:get_classification() end)
            if ok then classification = cls end
        end
        is_boss = classification == "worldboss"
        is_elite = classification == "elite" or classification == "rareelite" or classification == "worldboss"
        
        -- Count nearby enemies
        local ok_pos, target_pos = pcall(function() return target:get_position() end)
    if not ok_pos then target_pos = nil end
        if target.get_position then
            local ok, pos = pcall(function() return target:get_position() end)
            if ok then target_pos = pos end
        end
        
        if target_pos then
            local ok_objects, all_objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then all_objects = {} end
    for _, obj in ipairs(all_objects) do
                if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() 
                   and obj ~= target and me:can_attack(obj) then
                    local ok_op, obj_pos = pcall(function() return obj:get_position() end)
    if not ok_op then obj_pos = nil end
                    if obj.get_position then
                        local ok, pos = pcall(function() return obj:get_position() end)
                        if ok then obj_pos = pos end
                    end
                    if obj_pos then
                        local dx = obj_pos.x - target_pos.x
                        local dy = obj_pos.y - target_pos.y
                        local dz = obj_pos.z - target_pos.z
                        local dist_sq = dx*dx + dy*dy + dz*dz
                        if dist_sq < 100 then  -- 10 yards squared
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    
    rt.enemy_count = count
    rt.is_boss = is_boss
    rt.is_elite = is_elite
end

-- Rotation functions
local function try_cat_form(me)
    if not rt.cat_form_id then return false end
    if utils.has_buff(me, spells.BUFF_CAT_FORM) then return false end
    
    -- Don't shift to cat if drinking (respect OOC drink)
    if utils.is_drinking(me) then return false end
    
    -- Don't shift to cat if in bear form (user wants to stay in bear)
    if utils.is_in_bear_form(me) then return false end
    
    if not utils.can_cast_self(rt.cat_form_id, me) then return false end
    if utils.cast_self(rt.cat_form_id, me) then
        utils.log_debug(menu, "Cat Form")
        energy_tick:on_shift()  -- Reset energy tick tracking after shift
        return true
    end
    return false
end

local function try_prowl(me)
    if not ((menu.use_prowl and menu.use_prowl:get_state()) or false) then return false end
    if not rt.prowl_id then return false end
    if me:is_in_combat() then return false end
    if is_stealthed(me) then return false end
    if not utils.can_cast_self(rt.prowl_id, me) then return false end
    if utils.cast_self(rt.prowl_id, me) then
        utils.log_debug(menu, "Prowl")
        return true
    end
    return false
end

local function try_ravage(me, t)
    if not rt.ravage_id then return false end
    if not is_stealthed(me) then return false end
    if energy(me) < 60 then return false end
    if not utils.can_cast_hostile(rt.ravage_id, me, t) then return false end
    if utils.cast_target(rt.ravage_id, me, t) then
        utils.log_debug(menu, "Ravage")
        return true
    end
    return false
end

local function try_rake(me, t)
    if not ((menu.use_rake and menu.use_rake:get_state()) or false) then return false end
    if not rt.rake_id then return false end
    
    local e = energy(me)
    if e < rt.spell_costs.rake then return false end
    
    -- Get TTD
    local ttd = 999
    if t and t:is_valid() then
        local ok, val = pcall(function() return combat_forecast:get_ttd(t) end)
        if ok and val then ttd = val end
    end
    
    -- Minimum TTD for Rake to be worth it (from flux: 4 seconds)
    if ttd < 4 then return false end
    
    -- Feature 4: Dynamic DoT Refresh with Pandemic
    local rake_rem = debuff_rem(t, spells.DEBUFF_RAKE)
    local should_rake = false
    
    -- Get user refresh setting
    local user_refresh = (menu.rake_refresh_seconds and menu.rake_refresh_seconds:get()) or 3
    
    -- Calculate dynamic threshold with pandemic (30% of max duration)
    local refresh_threshold = get_dot_refresh_threshold(user_refresh, rt.dot_durations.rake)
    
    -- Check if Rake needs refresh
    if rake_rem == 0 or rake_rem < refresh_threshold then
        should_rake = true
    end
    
    -- Feature 6: AoE Rake Spreading (from flux cat.lua lines 658-676)
    local is_aoe_situation = false
    if (menu.enable_aoe and menu.enable_aoe:get_state()) or false then
        local aoe_threshold = (menu.aoe_enemy_count and menu.aoe_enemy_count:get()) or 3
        
        if rt.enemy_count >= aoe_threshold then
            is_aoe_situation = true
        end
    end
    
    -- AoE Rake spreading logic
    if is_aoe_situation and ((menu.spread_rake and menu.spread_rake:get_state()) or false) then
        -- In AoE, we want Rake on all targets
        -- Primary target Rake maintenance (already checked above)
        -- For nearby targets, we rely on the rotation to switch targets
        -- The spread_rake setting enables this behavior
        should_rake = true
    elseif is_aoe_situation and not (menu.spread_rake and menu.spread_rake:get_state()) then
        -- AoE enabled but spread_rake disabled - only Rake primary target if CP <= 4
        local cp = combo_points(me)
        if cp > 4 then
            should_rake = false  -- Don't Rake at 5 CP in AoE without spread enabled
        end
    end
    
    if not should_rake then return false end
    if not utils.can_cast_hostile(rt.rake_id, me, t) then return false end
    if utils.cast_target(rt.rake_id, me, t) then
        utils.log_debug(menu, string.format("Rake (rem=%.1fs, TTD=%.1fs, enemies=%d)", rake_rem, ttd, rt.enemy_count))
        return true
    end
    return false
end

local function try_rip(me, t)
    if not (menu.use_rip and menu.use_rip:get_state()) then return false end
    if not rt.rip_id then return false end
    
    local cp = combo_points(me)
    local e = energy(me)
    
    -- Get minimum CP setting
    local rip_min_cp = (menu.rip_combo_points and menu.rip_combo_points:get()) or 5
    
    if cp < rip_min_cp then return false end
    if e < rt.spell_costs.rip then return false end
    
    -- Get TTD
    local ttd = 999
    if t and t:is_valid() then
        local ok, val = pcall(function() return combat_forecast:get_ttd(t) end)
        if ok and val then ttd = val end
    end
    
    -- Minimum TTD for Rip (from flux: 8 seconds)
    if ttd < 8 then return false end
    
    -- Feature 4: Dynamic DoT Refresh with Pandemic
    local rip_rem = debuff_rem(t, spells.DEBUFF_RIP)
    local should_rip = false
    
    -- Get user refresh setting
    local user_refresh = (menu.rip_refresh_seconds and menu.rip_refresh_seconds:get()) or 3
    
    -- Calculate dynamic threshold with pandemic (30% of max duration = 3.6s for Rip)
    local refresh_threshold = get_dot_refresh_threshold(user_refresh, rt.dot_durations.rip)
    
    -- Check if Rip needs refresh
    if rip_rem == 0 or rip_rem < refresh_threshold then
        should_rip = true
    end
    
    -- Check rip_only_elites setting
    if should_rip and ((menu.rip_only_elites and menu.rip_only_elites:get_state()) or false) then
        local classification = nil
        if t and t.get_classification then
            local ok, cls = pcall(function() return t:get_classification() end)
            if ok then classification = cls end
        end
        local is_elite = classification == "worldboss" or classification == "elite" or classification == "rareelite"
        if not is_elite then
            should_rip = false
        end
    end
    
    -- v1.8.13: Energy Pooling for Rip (only when enabled)
    if should_rip and ((menu.cat_energy_pooling and menu.cat_energy_pooling:get_state()) or false) then
        -- Pool energy: wait until near energy cap (80+) before casting Rip
        -- This maximizes the time we can spend building CP while Rip ticks
        local max_energy = utils.get_max_energy(me)
        local pool_threshold = max_energy - 20  -- Pool to 80+ energy
        
        if e < pool_threshold then
            -- Check if we have time to pool (Rip not expiring immediately)
            if rip_rem > 3 then  -- Safe to pool
                return false  -- Wait for more energy
            end
        end
    end
    
    -- Check Mangle debuff - defer Rip one GCD if Mangle is missing (from flux)
    -- 30% bleed damage bonus on the FULL Rip duration is worth one GCD delay
    if should_rip then
        local mangle_rem = debuff_rem(t, spells.DEBUFF_MANGLE)
        if mangle_rem == 0 and rt.mangle_cat_id and utils.can_cast_hostile(rt.mangle_cat_id, me, t) then
            -- Only defer if we have energy for Mangle or clearcasting
            local has_clearcasting = utils.has_buff(me, spells.BUFF_OMEN_OF_CLARITY)
            if e >= rt.spell_costs.mangle or has_clearcasting then
                should_rip = false  -- Defer to apply Mangle first
            end
        end
    end
    
    if not should_rip then return false end
    if not utils.can_cast_hostile(rt.rip_id, me, t) then return false end
    if utils.cast_target(rt.rip_id, me, t) then
        utils.log_debug(menu, string.format("Rip (CP=%d, rem=%.1fs, TTD=%.1fs)", cp, rip_rem, ttd))
        return true
    end
    return false
end

local function try_ferocious_bite(me, t)
    if not ((menu.use_ferocious_bite and menu.use_ferocious_bite:get_state()) or false) then return false end
    if not rt.ferocious_bite_id then return false end
    
    local cp = combo_points(me)
    local e = energy(me)
    
    -- Get TTD for execute scaling
    local ttd = 999
    if t and t:is_valid() then
        local ok, val = pcall(function() return combat_forecast:get_ttd(t) end)
        if ok and val then ttd = val end
    end
    
    -- Get target HP percent
    local target_hp_pct = 100
    if t and t:is_valid() and t.get_health and t.get_max_health then
        local ok, hp = pcall(function() return ((t:get_health() / t:get_max_health()) * 100) end)
        if ok and hp then target_hp_pct = hp end
    end
    
    -- Feature 3: TTD-scaled Execute Bite (from flux cat.lua lines 487-509)
    -- Bite scales with CP: 1 CP bite only if mob dies in 1 GCD, 5 CP bite with 7.5s left
    local use_bite_execute = false
    if (menu.use_bite_execute and menu.use_bite_execute:get_state()) or false then
        -- Get execute settings
        local bite_execute_ttd = (menu.bite_execute_ttd and menu.bite_execute_ttd:get()) or 7.5
        local bite_execute_hp = (menu.bite_execute_hp and menu.bite_execute_hp:get()) or 20
        
        -- TTD-based execute: CP * 1.5 seconds (1 CP = 1.5s, 5 CP = 7.5s)
        if ttd <= cp * 1.5 then
            use_bite_execute = true
        end
        
        -- HP-based execute
        if target_hp_pct <= bite_execute_hp then
            use_bite_execute = true
        end
    end
    
    -- Standard bite logic
    local bite_min_cp = (menu.bite_min_cp and menu.bite_min_cp:get()) or 4
    
    -- Check if we should bite
    local should_bite = false
    
    -- Execute bite (bypasses normal CP requirements)
    if use_bite_execute and cp >= 1 and e >= rt.spell_costs.ferocious_bite then
        should_bite = true
    end
    
    -- Normal bite at sufficient CP
    if not should_bite and cp >= bite_min_cp and e >= rt.spell_costs.ferocious_bite then
        -- Check energy cap to avoid waste
        local fb_max_energy = (menu.bite_max_energy and menu.bite_max_energy:get()) or 39
        
        if e <= fb_max_energy then
            should_bite = true
        end
        
        -- If we have excess energy above cap, bite anyway
        if e > fb_max_energy then
            -- Check if Rip is up with good duration
            local rip_rem = debuff_rem(t, spells.DEBUFF_RIP)
            if rip_rem > 3 then  -- Rip has 3+ seconds left
                should_bite = true
            end
        end
    end
    
    if not should_bite then return false end
    if not utils.can_cast_hostile(rt.ferocious_bite_id, me, t) then return false end
    if utils.cast_target(rt.ferocious_bite_id, me, t) then
        utils.log_debug(menu, string.format("Ferocious Bite (CP=%d, TTD=%.1fs, HP=%.1f%%)", cp, ttd, target_hp_pct))
        return true
    end
    return false
end

-- ============================================================================
-- v1.8.13: Bite Trick - Low-energy FB dump to avoid energy waste
-- ============================================================================

local function try_bite_trick(me, t)
    if not ((menu.use_bite_trick and menu.use_bite_trick:get_state()) or false) then return false end
    if not rt.ferocious_bite_id then return false end
    
    local cp = combo_points(me)
    local e = energy(me)
    
    -- Bite trick: Low energy FB dump right before energy tick
    -- Requirements: 5 CP, energy < 35 (FB cost), tick imminent (< 0.1s), Rip up on target
    if cp < 5 then return false end
    if e >= rt.spell_costs.ferocious_bite then return false end  -- Must be below FB cost
    
    -- Check if Rip is up (per flux logic - only bite trick if Rip active)
    local rip_rem = debuff_rem(t, spells.DEBUFF_RIP)
    if rip_rem <= 0 then return false end
    
    -- Check tick timing - must be < 0.1s away (BITE_TRICK_TICK_THRESHOLD)
    if energy_tick:should_skip_bite_trick() then
        return false  -- Tick is too close, skip to avoid energy waste
    end
    
    if not utils.can_cast_hostile(rt.ferocious_bite_id, me, t) then return false end
    if utils.cast_target(rt.ferocious_bite_id, me, t) then
        local time_until = energy_tick:time_until_next_tick()
        utils.log_debug(menu, string.format("Bite Trick (%.1fs before tick, energy=%d)", time_until, e))
        return true
    end
    return false
end

-- ============================================================================
-- v1.8.13: Rake Trick - Low-energy Rake filler in the energy dead zone
-- ============================================================================

local function try_rake_trick(me, t)
    if not ((menu.use_rake_trick and menu.use_rake_trick:get_state()) or false) then return false end
    if not rt.rake_id then return false end
    
    local cp = combo_points(me)
    local e = energy(me)
    
    -- Rake trick: Use Rake in energy dead zone before tick
    -- Requirements: CP < 5, energy >= 35 (rake cost), tick < 1.0s away, no Rake on target
    if cp >= 5 then return false end  -- Don't waste CP at 5
    if e < rt.spell_costs.rake then return false end   -- Must have energy for Rake
    
    -- Check if Rake is NOT up (or expiring) - we want to apply it
    local rake_rem = debuff_rem(t, spells.DEBUFF_RAKE)
    if rake_rem > 3 then return false end  -- Don't refresh if > 3s left
    
    -- Check tick timing - must be < 1.0s away (RAKE_TRICK_TICK_THRESHOLD)
    if energy_tick:should_skip_rake_trick() then
        return false  -- Tick is too close, skip to avoid energy waste
    end
    
    -- Check Mangle debuff is up (per flux - rake trick only when mangle up)
    local mangle_rem = debuff_rem(t, spells.DEBUFF_MANGLE)
    if mangle_rem <= 0 then return false end
    
    if not utils.can_cast_hostile(rt.rake_id, me, t) then return false end
    if utils.cast_target(rt.rake_id, me, t) then
        local time_until = energy_tick:time_until_next_tick()
        utils.log_debug(menu, string.format("Rake Trick (%.1fs before tick, energy=%d)", time_until, e))
        return true
    end
    return false
end

local function try_mangle(me, t)
    if not ((menu.use_mangle_cat and menu.use_mangle_cat:get_state()) or false) then return false end
    if not rt.mangle_cat_id then return false end
    if has_debuff(t, spells.DEBUFF_MANGLE) then return false end
    if energy(me) < 40 then return false end
    if not utils.can_cast_hostile(rt.mangle_cat_id, me, t) then return false end
    if utils.cast_target(rt.mangle_cat_id, me, t) then
        utils.log_debug(menu, "Mangle")
        return true
    end
    return false
end

local function try_shred(me, t)
    if not ((menu.use_shred and menu.use_shred:get_state()) or false) then return false end
    if not rt.shred_id then return false end
    if not is_behind_target(me, t) then return false end

    local cp = combo_points(me)
    local e = energy(me)

        -- At 5 CP: only shred if energy above FB cap (energy dump for next Rip)
    if cp >= 5 then
        local fb_max_energy = (menu.fb_max_energy and menu.fb_max_energy:get()) or 39
        if e <= fb_max_energy then return false end
        -- Energy is above FB cap, continue to shred for energy dump
    else
        -- CP < 5: Check tick optimization (prefer Mangle in dead-zone)
        if (menu.cat_tick_optimization and menu.cat_tick_optimization:get_state()) or false then
            if energy_tick.should_prefer_mangle(e, rt.spell_costs.mangle, rt.spell_costs.shred) then
                if utils.throttle("tick_opt_debug", 2.0) then
                    utils.log_debug(menu, string.format("Tick opt: preferring Mangle over Shred (energy=%d, tick in %.2fs)",
                        e, energy_tick:time_until_next_tick()))
                end
                return false
            end
        end
    end

    if e < 42 then return false end
    if not utils.can_cast_hostile(rt.shred_id, me, t) then return false end
    if utils.cast_target(rt.shred_id, me, t) then
        utils.log_debug(menu, "Shred")
        return true
    end
    return false
end

-- ============================================================================
-- Flux v1.8.12 Fix: Mangle Builder at 5 CP when not behind target
-- ============================================================================

---Check if player is behind target (for Shred positional requirement)
---Uses is_usable_spell as proxy ONLY when Shred has energy and no cooldown
---This distinguishes positional failure from resource/cooldown constraints
---@param me userdata Player unit
---@param target userdata Target unit
---@return boolean True if player is likely behind target
local function is_behind_target(me, target)
    if not rt.shred_id or not me or not target then return false end
    
    -- Only use is_usable_spell as proxy when we have energy and no cooldown
    -- This ensures we're detecting POSITION, not resource/cooldown issues
    local has_energy = energy(me) >= rt.spell_costs.shred
    local has_no_cd = true
    
    if core.spell_book and core.spell_book.get_spell_cooldown then
        local ok, cd = pcall(function() return core.spell_book.get_spell_cooldown(rt.shred_id) end)
        if ok and cd and cd > 0 then has_no_cd = false end
    end
    
    -- Only check position if we have resources and no cooldown
    if has_energy and has_no_cd then
        if core.spell_book and core.spell_book.is_usable_spell then
            local ok, usable = pcall(function() return core.spell_book.is_usable_spell(rt.shred_id) end)
            if ok and not usable then
                -- Shred is not usable despite having energy and no cooldown = not behind target
                return false
            end
        end
    end
    
    return true  -- Default to assuming behind (let Shred fail naturally if not)
end

---Claw - Fallback CP builder when Shred is not available (not behind target)
---Ported from flux cat.lua logic + TBC spell reference
---@param me userdata Player unit
---@param t userdata Target unit
---@return boolean True if Claw was cast
local function try_claw(me, t)
    if not ((menu.use_claw and menu.use_claw:get_state()) or false) then return false end
    
    -- Resolve Claw spell ID (not cached in rt)
    local claw_id = utils.resolve_spell_id(spells.CLAW)
    if not claw_id then return false end
    
    local cp = combo_points(me)
    local e = energy(me)
    
    -- Only use Claw as fallback when CP < 5
    if cp >= 5 then return false end
    
    -- Only use Claw when we have enough energy
    -- Claw costs 40 energy (same as Mangle)
    local claw_cost = 40
    if e < claw_cost then return false end
    
    -- Only use Claw when Shred can't be used (positional check)
    if is_behind_target(me, t) then
        -- We're behind target, Shred should be used instead
        return false
    end
    
    -- Note: Claw can be used regardless of Mangle debuff state
    -- The rotation already prioritizes Mangle maintenance in try_mangle()
    -- which runs before Claw in the priority order
    
    if not utils.can_cast_hostile(claw_id, me, t) then return false end
    if utils.cast_target(claw_id, me, t) then
        utils.log_debug(menu, string.format("Claw (CP=%d, fallback - not behind target)", cp))
        return true
    end
    return false
end

---Mangle Builder - Fallback CP builder at 5 CP when not behind target (Flux v1.8.12 Fix)
---This is the key fix: allows Mangle to be used as builder at 5 CP when:
---1. Not behind target (can't use Shred)
---2. Energy above FB cap (need to dump energy)
---3. Mangle debuff is already up (or we're just dumping energy)
---This prevents the rotation from idling at 5 CP when positioning prevents Shred
---@param me userdata Player unit
---@param t userdata Target unit
---@return boolean True if Mangle was cast as builder
local function try_mangle_builder(me, t)
    if not ((menu.use_mangle_builder and menu.use_mangle_builder:get_state()) or false) then return false end
    if not rt.mangle_cat_id then return false end
    
    local cp = combo_points(me)
    local e = energy(me)
    
    -- Only use at 5 CP (the flux v1.8.12 fix removes this restriction)
    if cp < 5 then return false end
    
    -- Only use when not behind target (Shred's position)
    if is_behind_target(me, t) then
        -- We're behind target, Shred should be used for energy dump instead
        return false
    end
    
    -- Only dump energy if above FB max energy cap
    -- This prevents wasting energy that could be used for Rip
    local fb_max_energy = (menu.fb_max_energy and menu.fb_max_energy:get()) or 39
    if e <= fb_max_energy then return false end
    
    -- Check if we have energy for Mangle (or clearcasting)
    local has_clearcasting = utils.has_buff(me, spells.BUFF_OMEN_OF_CLARITY)
    if e < rt.spell_costs.mangle and not has_clearcasting then return false end
    
    -- Don't use as builder if Mangle debuff needs maintenance (let try_mangle handle that)
    if has_debuff(t, spells.DEBUFF_MANGLE) then
        -- Debuff is up, safe to use as builder
    else
        -- No debuff - only use if we can't afford to apply debuff now
        -- (this is an edge case, usually we want debuff up)
    end
    
    if not utils.can_cast_hostile(rt.mangle_cat_id, me, t) then return false end
    if utils.cast_target(rt.mangle_cat_id, me, t) then
        utils.log_debug(menu, string.format("Mangle Builder (5 CP energy dump, not behind, e=%d)", e))
        return true
    end
    return false
end

local function try_tigers_fury(me, target)
    if not ((menu.use_tigers_fury and menu.use_tigers_fury:get_state()) or false) then return false end
    if not rt.tigers_fury_id then return false end
    if utils.has_buff(me, spells.BUFF_TIGERS_FURY) then return false end
    if energy(me) > 40 then return false end
    
    -- TTD gating for burst CDs
    local min_ttd = ((menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0)
    if min_ttd > 0 and target then
        ---@type combat_forecast
        local forecast = require("libraries/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
            return false
        end
    end
    
    if not utils.can_cast_self(rt.tigers_fury_id, me) then return false end
    if utils.cast_self(rt.tigers_fury_id, me) then
        utils.log_debug(menu, "Tiger's Fury")
        return true
    end
    return false
end

local function try_powershift(me)
    -- Use powershift library for decision and execution
    if not rt.cat_form_id then return false end
    
    local current_energy = energy(me)
    
    -- Check if we should powershift using the library
    if powershift:should_powershift(me, current_energy, energy_tick, menu) then
        -- FIXED: Correct argument order - cat_form_id is the 4th parameter
        if powershift:execute(me, me:get_target(), energy_tick, rt.cat_form_id) then
            rt.last_powershift_time = _core_time()
            if utils.throttle("powershift_debug", 2.0) then
                local debug_info = powershift:get_debug_info(me, current_energy, energy_tick)
                utils.log_debug(menu, string.format("Powershift: %d -> %d energy (Wolfshead: %s)",
                    debug_info.current_energy, debug_info.energy_after_shift, tostring(debug_info.has_wolfshead)))
            end
            return true
        end
    end
    return false
end

local function try_faerie_fire(me, t)
    if not ((menu.use_faerie_fire and menu.use_faerie_fire:get_state()) or false) then return false end
    if not rt.faerie_fire_id then return false end
    if is_stealthed(me) then return false end  -- Don't break stealth
    if has_debuff(t, spells.DEBUFF_FAERIE_FIRE) then return false end
    if not utils.can_cast_hostile(rt.faerie_fire_id, me, t) then return false end
    if utils.cast_target(rt.faerie_fire_id, me, t) then
        utils.log_debug(menu, "Faerie Fire")
        return true
    end
    return false
end

-- PvP rotation functions
local function try_pvp_entangling_roots(me, t)
    if not utils.is_pvp_setting_enabled(menu, "pvp_entangling_roots") then return false end
    if not rt.entangling_roots_id then return false end
    if not rt.pvp_context or not rt.pvp_context.is_pvp then return false end
    
    -- Only root melee targets that are attacking us
    local distance = utils.get_distance_to_target(me, t)
    if distance > 10 then return false end  -- Only close targets
    
    -- Check if target already has root
    if utils.has_debuff(t, {339, 1062, 5195, 5196, 9852, 9853}) then return false end
    
    -- Don't root if we're in cat form and can fight
    if utils.has_buff(me, spells.BUFF_CAT_FORM) then
        local energy_val = energy(me)
        if energy_val > 40 then return false end  -- Save roots for when we're low on energy
    end
    
    if not utils.can_cast_hostile(rt.entangling_roots_id, me, t) then return false end
    if utils.cast_target(rt.entangling_roots_id, me, t) then
        utils.log_debug(menu, "PvP: Entangling Roots")
        return true
    end
    return false
end

local function try_pvp_hibernate(me, t)
    if not utils.is_pvp_setting_enabled(menu, "pvp_hibernate") then return false end
    if not rt.hibernate_id then return false end
    if not rt.pvp_context or not rt.pvp_context.is_pvp then return false end
    
    -- Hibernate only works on beasts and dragonkin
    -- Check target class for Druid/Shaman (can shift to beast forms)
    local target_class = nil
    if t.get_class then
        local ok, class = pcall(function() return t:get_class() end)
        if ok then target_class = class end
    end
    
    -- Only hibernate druids (can be in cat/bear form) and shamans (ghost wolf)
    if target_class ~= "DRUID" and target_class ~= "SHAMAN" then return false end
    
    -- Check if target already has hibernate
    if utils.has_debuff(t, {2637, 18657, 18658}) then return false end
    
    if not utils.can_cast_hostile(rt.hibernate_id, me, t) then return false end
    if utils.cast_target(rt.hibernate_id, me, t) then
        utils.log_debug(menu, "PvP: Hibernate")
        return true
    end
    return false
end

-- Main rotation
local function do_rotation(me, t)

    -- Debug: Log entry and state
    if utils.throttle("feral_debug", 2.0) then
        local e = energy(me)
        local cp = combo_points(me)
        local rip_ok = utils.can_cast_hostile(rt.rip_id, me, t)
        local rake_ok = utils.can_cast_hostile(rt.rake_id, me, t)
        core.log(string.format("|cFF00FF00[EAX Feral]|r Energy=%d CP=%d RipOK=%s RakeOK=%s", e, cp, tostring(rip_ok), tostring(rake_ok)))
    end

    -- Check rotation toggles
    local cat_rotation_enabled = ((menu.use_cat_rotation and menu.use_cat_rotation:get_state()) or false)
    local bear_rotation_enabled = ((menu.use_bear_rotation and menu.use_bear_rotation:get_state()) or false)

    -- Ensure in cat form (if cat rotation enabled)
    if cat_rotation_enabled and not utils.has_buff(me, spells.BUFF_CAT_FORM) then
        -- Only force cat form if not drinking and not in bear
        if not utils.is_drinking(me) and not utils.is_in_bear_form(me) then
            if try_cat_form(me) then return end
        end
    end

    -- Cat Form Rotation (only if enabled)
    if cat_rotation_enabled and utils.has_buff(me, spells.BUFF_CAT_FORM) then
        -- Stealth opener
        if not me:is_in_combat() then
            if try_prowl(me) then return end
        end
        if is_stealthed(me) then
            if try_ravage(me, t) then return end
        end

        -- Powershift check (BEFORE spending energy - Flux-style GCD check)
        -- Only consider powershift if GCD is ready (prevents "ability not ready" spam)
        local ok_gcd, gcd_remains = pcall(function() return _get_gcd() end)
        if (not ok_gcd or not gcd_remains or gcd_remains <= 0.1) then
            if try_powershift(me) then return end
        end

        -- Cooldowns (Tiger's Fury after powershift decision)
        if try_tigers_fury(me, t) then return end

        -- Rotation priority (v1.8.13: Bite Trick and Rake Trick before Mangle)
        -- v1.8.13: Check swing timer delay before each ability to avoid clipping auto-attacks
        if not should_delay_for_swing(me) then
            if try_faerie_fire(me, t) then return end
        end
        if not should_delay_for_swing(me) then
            if try_rip(me, t) then return end
        end
        if not should_delay_for_swing(me) then
            if try_ferocious_bite(me, t) then return end
        end
        -- v1.8.13: Bite Trick and Rake Trick now check BEFORE Mangle debuff (sim priority)
        if not should_delay_for_swing(me) then
            if try_bite_trick(me, t) then return end
        end
        if not should_delay_for_swing(me) then
            if try_rake_trick(me, t) then return end
        end
        if not should_delay_for_swing(me) then
            if try_mangle(me, t) then return end
        end
        if not should_delay_for_swing(me) then
            if try_rake(me, t) then return end
        end
        if not should_delay_for_swing(me) then
            if try_shred(me, t) then return end
        end
        -- Flux v1.8.12 Fix: Fallback builders when Shred fails (not behind target or at 5 CP)
        if try_mangle_builder(me, t) then return end  -- Energy dump at 5 CP when not behind
        if try_claw(me, t) then return end             -- Fallback builder when CP < 5 and not behind
    end
    
    -- Bear Form Rotation (only if enabled and in bear)
    if bear_rotation_enabled and utils.is_in_bear_form(me) then
        -- Bear tank rotation: Faerie Fire > Mangle > Lacerate > Swipe (AoE) > Maul
        if try_faerie_fire(me, t) then return end
        
        -- Use Bear Mangle if enabled (primary threat ability, cast on cooldown)
        if (menu.use_mangle_bear and menu.use_mangle_bear:get_state()) or false then
            local mangle_bear_id = utils.resolve_spell_id(spells.MANGLE_BEAR)
            if mangle_bear_id and utils.can_cast_hostile(mangle_bear_id, me, t) then
                if utils.cast_target(mangle_bear_id, me, t) then
                    utils.log_debug(menu, "Mangle (Bear)")
                    return true
                end
            end
        end
        
        -- Use Lacerate if enabled
        if (menu.use_lacerate and menu.use_lacerate:get_state()) or false then
            local lacerate_id = utils.resolve_spell_id(spells.LACERATE)
            if lacerate_id and utils.can_cast_hostile(lacerate_id, me, t) then
                -- Check Lacerate stacks/refresh
                local debuff_data = t:get_debuff_data(spells.DEBUFF_LACERATE or {33745})
                local stacks = (debuff_data and debuff_data.stacks) or 0
                local remaining = (debuff_data and debuff_data.remaining) or 0
                -- Apply if < 5 stacks or about to expire
                if stacks < 5 or remaining < 3 then
                    if utils.cast_target(lacerate_id, me, t) then
                        utils.log_debug(menu, "Lacerate")
                        return true
                    end
                end
            end
        end
        
        -- Use Swipe for AoE if enabled
        if ((menu.use_swipe and menu.use_swipe:get_state()) or false) and rt.enemy_count >= 3 then
            local swipe_id = utils.resolve_spell_id(spells.SWIPE)
            if swipe_id and utils.can_cast_hostile(swipe_id, me, t) then
                if utils.cast_target(swipe_id, me, t) then
                    utils.log_debug(menu, "Swipe (AoE)")
                    return true
                end
            end
        end
        
        -- Use Maul as rage dump
        if (menu.use_maul and menu.use_maul:get_state()) or false then
            local maul_id = utils.resolve_spell_id(spells.MAUL)
            if maul_id then
                -- Get rage
                local rage = 0
                local max_rage = 100
                if me.get_power then
                    rage = me:get_power(1) or 0  -- 1 = rage
                    max_rage = (me.get_max_power and me:get_max_power(1)) or 100
                end
                -- Use Maul if above threshold
                local maul_threshold = (menu.maul_min_rage and menu.maul_min_rage:get()) or 25
                if rage >= maul_threshold and utils.can_cast_hostile(maul_id, me, t) then
                    if utils.cast_target(maul_id, me, t) then
                        utils.log_debug(menu, "Maul")
                        return true
                    end
                end
            end
        end
    end
end

    -- Update loop
local function on_update()
    resolve()
    local me = get_me()
    if not me or not me:is_valid() then return end

    -- Update energy tick tracker with new parameters (Feature 5)
    local current_energy = energy(me)
    local in_cat_form = utils.has_buff(me, spells.BUFF_CAT_FORM)
    energy_tick.update(current_energy, in_cat_form, rt.last_powershift_time)

    -- Update combat context for enemy count and boss detection (Features 2 & 6)
    local ok_t, t = pcall(function() return me:get_target() end)
    if not ok_t then t = nil end
    update_combat_context(me, t)

    -- Sample TTD for combat forecast (~1 second throttle)
    if utils.throttle("combat_forecast_sample", 1.0) then
        if t and t:is_valid() then
            combat_forecast:sample(t)
        end
    end

    if utils.throttle("feral_mode", MODE_REFRESH) then
        rt.cached_mode = detect_mode()
    end

    -- Debug: Check if menu exists and is enabled
    if not menu then
        if utils.throttle("feral_no_menu", 5.0) then
            core.log("|cFFFF0000[EAX Feral]|r menu is nil!")
        end
        return
    end

    -- Debug: Check unified state directly
    local is_enabled = (menu.enabled and menu.enabled:get_state()) or false

    if not is_enabled then
        dashboard.set_enabled(false)  -- Disable dashboard when rotation is off
        return
    end

    -- Enable dashboard when rotation is active (respect menu setting)
    local show_dashboard = ((menu.show_dashboard and menu.show_dashboard.get and menu.show_dashboard:get()) or false)
    dashboard.set_enabled(show_dashboard)

    -- OOC Manager: Handle out-of-combat buffs
    -- Order matters: Buffs first (in human form), then shift to Cat Form
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD),
                    buff_ids = spells.BUFF_MARK_OF_THE_WILD,
                    name = "Mark of the Wild",
                    toggle = menu.use_mark_of_the_wild
                },
                {
                    spell_id = rt.thorns_id,
                    buff_ids = spells.BUFF_THORNS,
                    name = "Thorns",
                    toggle = menu.use_thorns
                },
                {
                    spell_id = rt.cat_form_id,
                    buff_ids = spells.BUFF_CAT_FORM,
                    name = "Cat Form",
                    toggle = menu.use_cat_form
                },
            }
        })
        return  -- Exit after OOC buffs to prevent combat rotation from overwriting
    end

    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    -- Druid special: Try shapeshift for roots before stopping
    if should_stop and cc_reason == "ROOTS" then
        if utils.try_shapeshift_root_break(me, menu) then
            return  -- Successfully broke root
        end
    end

    if should_stop then
        return  -- Stop rotation while crowd controlled
    end

    -- Sync dashboard settings (safe pcall for uninitialized menu items)
    local ok_show, show_dashboard = pcall(function() return menu.show_dashboard:get_state() end)
    if ok_show then
        dashboard.set_enabled(show_dashboard)
    end
    
    local ok_opacity, opacity = pcall(function() return menu.dashboard_opacity:get() end)
    if ok_opacity then
        dashboard.set_opacity(opacity)
    end
    
    local ok_scale, scale = pcall(function() return menu.dashboard_scale:get() end)
    if ok_scale then
        dashboard.set_scale(scale)
    end
    
    local ok_x, pos_x = pcall(function() return menu.dashboard_x:get() end)
    local ok_y, pos_y = pcall(function() return menu.dashboard_y:get() end)
    if ok_x and ok_y then
        dashboard.set_position(pos_x, pos_y)
    end

    local ok_dead, is_dead = pcall(function() return me:is_dead() end)
    if not me or (ok_dead and is_dead) then return end

    -- Track combat start time for burst manager
    local now = _core_time()
    if me:is_in_combat() then
        if not rt.combat_start_time then
            rt.combat_start_time = now
        end
    else
        rt.combat_start_time = nil
    end

    -- Target already retrieved above
    if not t or not t:is_valid() or t:is_dead() then return end
    local ok_attack, can_attack = pcall(function() return me:can_attack(t) end)
    if not (ok_attack and can_attack) then return end

    -- Build settings table for middleware
    local settings = {
        use_healthstone = ((menu.use_healthstone and menu.use_healthstone:get_state()) or false),
        use_healing_potion = ((menu.use_healing_potion and menu.use_healing_potion:get_state()) or false),
        use_racial = ((menu.use_racial and menu.use_racial:get_state()) or false),
    }

    -- Initialize middleware on first run
    if not rt.middleware_initialized then
        middleware_manager.initialize(menu)
        rt.middleware_initialized = true
    end

    -- Build context and execute middleware (FIXED: proper args + nil icon)
    local context = middleware_manager.build_context(me, t, settings)
    local mw_result, mw_msg = middleware_manager.execute(nil, context)
    if mw_result then
        return  -- Middleware handled action (healthstone, potion, racial, etc.)
    end

    -- Try to break roots via shapeshift
    if utils.try_shapeshift_root_break(me, menu) then return end

    -- Form-aware consumables
    local use_form_consumables = ((menu.use_form_consumables and menu.use_form_consumables.get and menu.use_form_consumables:get()) or false)
    if use_form_consumables then
        local form_spells = {
            CAT = rt.cat_form_id,
            BEAR = rt.bear_form_id,
            DIRE_BEAR = rt.dire_bear_form_id,
        }
        local used, saved_form, reason = form_consumables.check_and_use(me, menu, form_spells, rt.saved_form)
        if used then
            rt.saved_form = saved_form
            if reason then utils.log_debug(menu, "Form consumable: " .. reason) end
        elseif saved_form == nil and rt.saved_form then
            -- Form was restored, clear saved_form
            rt.saved_form = nil
        end
    end

    -- PvP context detection
    if not rt.last_pvp_check or (now - rt.last_pvp_check) > 1.0 then
        rt.pvp_context = utils.detect_pvp_context(me, t)
        rt.last_pvp_check = now
    end

    -- PvP rotation
    if utils.is_pvp_active(menu, rt.pvp_context) then
        if try_pvp_entangling_roots(me, t) then return end
        if try_pvp_hibernate(me, t) then return end
    end

    -- Burst & Trinket Automation with Flux V2 API
    local combat_time = now - (rt.combat_start_time or now)
    local is_burst_window = burst_manager.should_auto_burst(me, t, combat_time, menu)
    if is_burst_window then
        -- Tiger's Fury is our main burst CD - already called in do_rotation
        -- but we can force it here if in burst window
        if try_tigers_fury(me, t) then return end
    end
    
    -- V2 Trinket check with TTD gating, boss/elite check, and force command integration
    local is_burst = burst_manager and burst_manager.is_burst_active and burst_manager:is_burst_active()
    trinket_manager:check_trinkets_v2(me, t, is_burst, force_commands, combat_forecast, menu, {
        offensive_ttd = (menu.trinket_ttd and menu.trinket_ttd:get()) or 10,
        defensive_hp = (menu.defensive_trinket_hp and menu.defensive_trinket_hp:get()) or 35,
        is_boss = rt.is_boss,
        is_elite = rt.is_elite,
    })

    do_rotation(me, t)
end

core.register_on_update_callback(on_update)

-- Register menu render callback
core.register_on_render_menu_callback(function()
    menu.render()
end)

-- Initialize dashboard
local config = require("libraries/dashboard_config")
dashboard.init(config)
dashboard.register_render_callback()

-- Initialize force commands
force_commands:init()

-- Export toggle settings for external access (only if header loaded successfully)
if header.load then
    local NS = _G.EAXDruidFeral_ and _G.EAXDruidFeral_.NS or {}
    _G.EAXDruidFeral_ = _G.EAXDruidFeral_ or {}
    _G.EAXDruidFeral_.NS = NS
    NS.toggle_menu = menu.toggle_menu
end

return {}








