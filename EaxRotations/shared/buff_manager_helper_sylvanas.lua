-- buff_manager_helper_sylvanas.lua -- nil-safe wrapper for bulk aura cache access.
-- WHAT:  exposes one-call bulk buff/debuff scanning via the Sylvanas buff_manager module.
-- WHEN:  called from spec match/build_state functions that need to inspect many auras at once.
-- WHY:   buff_manager:get_debuff_data/get_buff_data returns ALL matching auras in a single
--        cached call, avoiding N separate unit:has_buff() API round-trips.
-- SAFETY: every public function returns a safe default when buff_manager is unavailable.
-- DECISION: keep the module tiny; specs iterate the returned table, not this helper.

local NS = _G.EaxRotations
local M = {}

local _bm_ok, _buff_manager = pcall(require, "common/modules/buff_manager")
if not _bm_ok or type(_buff_manager) ~= "table" then _buff_manager = nil end

local function safe_bm_call(method_name, unit, ids, ttl_ms)
    if not _buff_manager then return nil end
    local method = _buff_manager[method_name]
    if type(method) ~= "function" then return nil end
    -- API: get_buff_data/get_debuff_data(self, unit, ids, cache_ms?)
    --      get_buff_cache/get_debuff_cache(self, unit, cache_ms?)  — NO ids param
    local ok, data
    if ids then
        ok, data = pcall(method, _buff_manager, unit, ids, ttl_ms or 50)
    else
        ok, data = pcall(method, _buff_manager, unit, ttl_ms or 50)
    end
    if not ok then return nil end
    return data
end

function M.get_debuff_data(unit, ids, ttl_ms)
    return safe_bm_call("get_debuff_data", unit, ids, ttl_ms)
end

function M.get_buff_data(unit, ids, ttl_ms)
    return safe_bm_call("get_buff_data", unit, ids, ttl_ms)
end

function M.get_all_debuffs(unit, ttl_ms)
    -- Use the documented buff_manager cache method. The legacy "get_debuffs"
    -- method does not exist in the Sylvanas buff_manager API, so the old call
    -- always returned nil and caused specs (affliction/shadow) to see every
    -- DoT as expired, resulting in spam re-casts.
    return safe_bm_call("get_debuff_cache", unit, nil, ttl_ms)
end






return M

