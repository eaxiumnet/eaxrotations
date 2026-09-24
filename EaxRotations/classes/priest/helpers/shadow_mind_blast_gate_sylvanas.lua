-- shadow_mind_blast_gate_sylvanas.lua — Shadow Priest Mind Blast prediction gate.
-- WHAT:  owns optional target-health/damage reads and the pure overkill policy.
-- WHEN:  loaded by shadow_sylvanas.lua while building per-tick rotation state.
-- WHY:   keeps API adaptation and caching out of the strategy/state composition file.
-- SAFETY: documented calls are validated and fail open; no rotation state or UI lives here.
-- ESTIMATE: two documented stages. Origin = common/utility/spell_helper:get_spell_damage
--   (the documented replacement for the removed core.spell_book.get_spell_damage).
--   Accuracy = health_prediction:speculate_spell_damage(caster, target, damage, spell_id),
--   the platform's target-aware speculator, resolved through the engine's own facades
--   (NS.health_prediction, then NS.GetAPIModule). Absent speculator or a non-numeric
--   answer falls back to the raw estimate (fail open), never to a guess.

local M = {}

local _spell_helper_ok, spell_helper = pcall(require, "common/utility/spell_helper")
if not _spell_helper_ok or type(spell_helper) ~= "table" then spell_helper = nil end

-- Platform health prediction module, resolved through the engine's own facades:
-- main_sylvanas publishes NS.health_prediction and core_sylvanas publishes the
-- NS.GetAPIModule map, so there is exactly one resolution path. Accessed with ":" per
-- the module's own header and the public docs
-- (docs.project-sylvanas.net/dev/libraries/modules/health-prediction).
-- Resolved lazily at call time because main_sylvanas assigns NS.health_prediction
-- after spec helpers load; nil means the stage is unavailable and the raw estimate
-- is kept.
local function health_prediction_module(ns)
    if type(ns) ~= "table" then return nil end
    local module = ns.health_prediction
    if type(module) ~= "table" and type(ns.GetAPIModule) == "function" then
        local ok, resolved = pcall(ns.GetAPIModule, "health_prediction")
        if ok then module = resolved end
    end
    if type(module) ~= "table" then return nil end
    return module
end

local DAMAGE_CACHE_TTL = 1.0
-- The speculated estimate is target-specific, so the target takes part in the key.
local damage_cache = { id = nil, inner_focus = nil, target_key = nil, value = 0, time = -math.huge }

local function is_positive_finite(value)
    return type(value) == "number" and value == value and value > 0 and value < math.huge
end

local function read_unit_health(unit)
    if not unit or type(unit.get_health) ~= "function" then return 0 end
    local ok, value = pcall(unit.get_health, unit)
    if ok and type(value) == "number" and value == value and value >= 0 and value < math.huge then
        return value
    end
    return 0
end

-- Cast caster for the speculator: the engine's NS.GetPlayer, else nil (fail open).
-- NS.me is deliberately not consulted: nothing in production assigns it, so a
-- fallback to it would be a branch that can never fire on the live path.
local function resolve_caster(ns)
    if type(ns) ~= "table" or type(ns.GetPlayer) ~= "function" then return nil end
    local ok, player = pcall(ns.GetPlayer)
    if ok and player then return player end
    return nil
end

-- Reduce the raw estimate to what `target` would actually take. Returns the raw
-- value unchanged whenever the platform cannot answer with a positive finite number.
local function speculate_damage(ns, target, raw, id)
    if raw <= 0 or not target then return raw end
    local module = health_prediction_module(ns)
    if not module then return raw end
    local speculate = module.speculate_spell_damage
    if type(speculate) ~= "function" then return raw end
    local caster = resolve_caster(ns)
    if not caster then return raw end
    local ok, value = pcall(speculate, module, caster, target, raw, id)
    if ok and is_positive_finite(value) then return value end
    return raw
end

-- Stable identity for cross-frame caching. Guid is this codebase's cross-frame
-- target key (shadow_sylvanas keys snapshot_target the same way) and it survives a
-- fresh wrapper object for the same unit, which a raw table reference does not; the
-- unit reference is the fallback for units that expose no guid. The two forms cannot
-- collide because a table never compares equal to a string.
local function target_identity(target)
    if not target then return nil end
    if type(target.get_guid) == "function" then
        local ok, guid = pcall(target.get_guid, target)
        if ok and guid ~= nil then return guid end
    end
    return target
end

local function read_damage(ns, action, inner_focus, target)
    if not spell_helper or type(spell_helper.get_spell_damage) ~= "function" then return 0 end
    if type(ns) ~= "table" or type(ns.get_spell_id) ~= "function" then return 0 end

    local ok_id, id = pcall(ns.get_spell_id, action)
    if not ok_id or not is_positive_finite(id) then return 0 end

    local now = type(ns.time_now) == "function" and ns.time_now() or 0
    local inner_focus_active = inner_focus == true
    local key = target_identity(target)
    if damage_cache.id == id
        and damage_cache.inner_focus == inner_focus_active
        and damage_cache.target_key == key
        and now >= damage_cache.time
        and now - damage_cache.time < DAMAGE_CACHE_TTL then
        return damage_cache.value
    end

    local ok, value = pcall(spell_helper.get_spell_damage, spell_helper, id)
    if not ok or not is_positive_finite(value) then value = 0 end
    if value > 0 then value = speculate_damage(ns, target, value, id) end
    damage_cache.id = id
    damage_cache.inner_focus = inner_focus_active
    damage_cache.target_key = key
    damage_cache.value = value
    damage_cache.time = now
    return value
end

function M.read_target_prediction(ns, action, target, inner_focus)
    if not target then return 0, 0 end
    return read_unit_health(target), read_damage(ns, action, inner_focus, target)
end

function M.would_overkill(target_health, damage)
    local hp = tonumber(target_health)
    local predicted_damage = tonumber(damage)
    if not hp or hp <= 0 or not predicted_damage or predicted_damage <= 0 then return false end
    return predicted_damage > hp
end

return M
