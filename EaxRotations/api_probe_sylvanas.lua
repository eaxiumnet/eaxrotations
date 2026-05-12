-- Readability notes:
--   What: runtime module.
--   When: loaded by bootstrap or tests when required.
--   Why: keeps related behavior in one auditable file.
--   Safety: use NS helpers, guard nil values, and avoid hot-path allocations.

-- Decision notes:
--   This support module keeps side effects explicit and routes runtime-sensitive work through NS helpers.
--   Comments emphasize intent and constraints so future edits preserve behavior without adding frame-costly checks.
--   When API data is missing, callers should skip unsafe work rather than guessing.
-- ============================================================================
-- EaxRotations - API Probe
-- Lightweight diagnostics for the Project Sylvanas API boundary.
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local core = NS.core or _G.core or {}
local izi = NS.izi
local tostring = tostring
local type = type
local tinsert = table.insert
local concat = table.concat
local ipairs = ipairs
local format = string.format

local last_results = {}
local last_failures = {}
local last_summary = "not run"
local has_run = false
local auto_probe_ran = false

local function callable(value)
    return type(value) == "function"
end

local function add_result(results, label, ok, detail, optional)
    results[#results + 1] = {
        label = label,
        ok = ok and true or false,
        detail = detail,
        optional = optional and true or false,
    }
end

local function probe_call(results, label, fn, optional)
    if not callable(fn) then
        add_result(results, label, false, "missing", optional)
        return
    end

    local ok, result = pcall(fn)
    add_result(results, label, ok, ok and tostring(result) or tostring(result), optional)
end

local function probe_function(results, label, value, optional)
    add_result(results, label, callable(value), callable(value) and "available" or "missing", optional)
end

local function summarize(results)
    local pass = 0
    local fail = 0
    local skip = 0

    for _, result in ipairs(results) do
        if result.ok then
            pass = pass + 1
        elseif result.optional then
            skip = skip + 1
        else
            fail = fail + 1
        end
    end

    return pass, fail, skip, ("PASS %d / FAIL %d / SKIP %d"):format(pass, fail, skip)
end

local function probe_method(results, object_label, object, method, optional)
    if not object then
        add_result(results, object_label .. ":" .. method, false, "object missing", optional)
        return
    end
    probe_function(results, object_label .. ":" .. method, object[method], optional)
end

local function probe_method_call(results, object_label, object, method, optional)
    if not object then
        add_result(results, object_label .. ":" .. method .. "()", false, "object missing", optional)
        return
    end
    if not callable(object[method]) then
        add_result(results, object_label .. ":" .. method .. "()", false, "missing", optional)
        return
    end
    probe_call(results, object_label .. ":" .. method .. "()", function()
        return object[method](object)
    end, optional)
end

local function first_spell_object()
    local class_spell_tables = {
        NS.DruidSpells, NS.HunterSpells, NS.MageSpells, NS.PaladinSpells,
        NS.PriestSpells, NS.RogueSpells, NS.ShamanSpells, NS.WarlockSpells,
        NS.WarriorSpells,
    }

    for _, spells in ipairs(class_spell_tables) do
        if type(spells) == "table" then
            for name, spell in pairs(spells) do
                if type(spell) == "table" and spell._meta then
                    return name, spell
                end
            end
        end
    end

    return "probe_attack", NS.CreateSpell and NS.CreateSpell(6603, {
        Desc = "Attack Probe",
        is_self_cast = true,
    }) or nil
end

local function first_known_spell_id(spell)
    if not spell or not spell._meta then return nil end
    local ids = spell._meta.ids
    if type(ids) == "table" then
        for _, spell_id in ipairs(ids) do
            if not NS.spell_id_is_known or NS.spell_id_is_known(spell_id, spell) then
                return spell_id
            end
        end
    end
    return spell._meta.id
end

local function safe_method(object, method, ...)
    if not object or not callable(object[method]) then return "missing" end
    local args = { ... }
    local ok, result = pcall(function()
        return object[method](object, unpack(args))
    end)
    return ok and tostring(result) or ("err:" .. tostring(result))
end

local function safe_call(fn, ...)
    if not callable(fn) then return "missing" end
    local args = { ... }
    local ok, result = pcall(function()
        return fn(unpack(args))
    end)
    return ok and tostring(result) or ("err:" .. tostring(result))
end

local function run_range_probe(label, spell, player, target)
    if not spell or not player or not target then return end
    local spell_id = first_known_spell_id(spell)
    if not spell_id then return end

    local player_pos = callable(player.get_position) and player:get_position() or nil
    local target_pos = callable(target.get_position) and target:get_position() or nil
    local spell_helper = NS.GetAPIModule and NS.GetAPIModule("spell_helper") or nil
    local spell_book = core and core.spell_book or nil

    local helper = "missing"
    if spell_helper and callable(spell_helper.is_spell_in_range) and player_pos and target_pos then
        helper = safe_method(spell_helper, "is_spell_in_range", spell_id, target, player_pos, target_pos)
    end

    local distance = safe_method(target, "distance")
    local max_range = safe_call(spell_book and spell_book.get_spell_max_range, spell_id)
    local raw_target_caster = safe_call(spell_book and spell_book.is_spell_in_range, spell_id, target, player)
    local raw_caster_target = safe_call(spell_book and spell_book.is_spell_in_range, spell_id, player, target)
    local unit_extension = safe_method(target, "is_spell_in_range", spell)
    local ns_range = safe_call(NS.spell_in_range, spell, target, player)

    NS.log(format(
        "[RANGE_PROBE] %s id=%s dist=%s max=%s helper=%s raw_target_caster=%s raw_caster_target=%s unit_ext=%s ns=%s",
        tostring(label),
        tostring(spell_id),
        tostring(distance),
        tostring(max_range),
        tostring(helper),
        tostring(raw_target_caster),
        tostring(raw_caster_target),
        tostring(unit_extension),
        tostring(ns_range)
    ))
end

function NS.run_api_probe()
    local results = {}
    local player = izi and izi.me and izi.me() or nil
    local target = izi and ((izi.ts and izi.ts()) or (izi.target and izi.target())) or nil

    probe_function(results, "core.log", core.log)
    probe_function(results, "core.log_warning", core.log_warning, true)
    probe_function(results, "core.log_error", core.log_error, true)
    probe_function(results, "core.register_on_update_callback", core.register_on_update_callback)
    probe_function(results, "core.register_on_render_menu_callback", core.register_on_render_menu_callback)
    probe_function(results, "core.register_on_render_window_callback", core.register_on_render_window_callback)
    probe_function(results, "core.spell_book", core.spell_book and core.spell_book.is_spell_learned)
    probe_function(results, "core.input.cast_target_spell", core.input and core.input.cast_target_spell)
    probe_function(results, "core.input.cast_position_spell", core.input and core.input.cast_position_spell)
    probe_function(results, "core.spell_book.is_spell_position_cast", core.spell_book and core.spell_book.is_spell_position_cast, true)
    probe_function(results, "core.object_manager.get_local_player", core.object_manager and core.object_manager.get_local_player)

    probe_call(results, "core.time", function()
        return core.time and core.time() or nil
    end)
    probe_call(results, "izi.me", function()
        return izi and izi.me and izi.me() or nil
    end)
    probe_call(results, "izi.target", function()
        return izi and izi.target and izi.target() or nil
    end)

    probe_function(results, "NS.CreateSpell", NS.CreateSpell)
    probe_function(results, "NS.GetPlayer", NS.GetPlayer)
    probe_function(results, "NS.GetTarget", NS.GetTarget)
    probe_function(results, "NS.GetEnemiesInRange", NS.GetEnemiesInRange)
    probe_function(results, "NS.try_cast", NS.try_cast)
    probe_function(results, "NS.spell_ready", NS.spell_ready)
    probe_function(results, "NS.time_now", NS.time_now)
    probe_function(results, "NS.rotation_registry", NS.rotation_registry and NS.rotation_registry.register)
    probe_function(results, "NS.GetFriendsInRange", NS.GetFriendsInRange)
    probe_function(results, "NS.GetEnemiesCount", NS.GetEnemiesCount)
    probe_function(results, "NS.find_dead_party_ally", NS.find_dead_party_ally)

    probe_method_call(results, "player", player, "get_class")
    probe_method_call(results, "player", player, "is_in_combat")
    probe_method_call(results, "player", player, "is_moving", true)
    probe_method_call(results, "player", player, "mana_pct", true)
    probe_method_call(results, "player", player, "health_pct", true)
    probe_method_call(results, "player", player, "time_in_combat", true)
    probe_method(results, "player", player, "buff_up", true)
    probe_method(results, "player", player, "debuff_up", true)
    probe_method(results, "player", player, "buff_remains", true)
    probe_method(results, "player", player, "debuff_remains", true)
    probe_method(results, "player", player, "get_party_members_in_range", true)

    if target then
        probe_method_call(results, "target", target, "is_valid_enemy", true)
        probe_method_call(results, "target", target, "health_pct", true)
        probe_method_call(results, "target", target, "time_to_die", true)
        probe_method_call(results, "target", target, "is_casting", true)
        probe_method_call(results, "target", target, "distance", true)
        probe_method(results, "target", target, "debuff_up", true)
        probe_method(results, "target", target, "debuff_remains", true)
    else
        add_result(results, "target object probes", false, "no target selected", true)
    end

    local spell_name, spell = first_spell_object()
    add_result(results, "sample spell object", spell ~= nil, tostring(spell_name))
    if spell then
        probe_method(results, "spell:" .. tostring(spell_name), spell, "IsExists")
        probe_method(results, "spell:" .. tostring(spell_name), spell, "IsReady")
        probe_method(results, "spell:" .. tostring(spell_name), spell, "IsInRange", true)
        probe_method(results, "spell:" .. tostring(spell_name), spell, "GetSpellPowerCost", true)
        probe_method(results, "spell:" .. tostring(spell_name), spell, "is_castable_to_position", true)
        probe_method(results, "spell:" .. tostring(spell_name), spell, "cast_position", true)
        probe_call(results, "spell:" .. tostring(spell_name) .. ":IsExists()", function()
            return spell:IsExists()
        end)
        probe_call(results, "spell:" .. tostring(spell_name) .. ":GetSpellPowerCost()", function()
            local cost, power_type = spell:GetSpellPowerCost()
            return tostring(cost) .. "/" .. tostring(power_type)
        end, true)
    end

    local spell_helper = NS.GetAPIModule and NS.GetAPIModule("spell_helper") or nil
    probe_method(results, "spell_helper", spell_helper, "is_spell_castable_position", true)
    probe_method(results, "spell_helper", spell_helper, "is_spell_in_range", true)

    local pass, fail, skip, summary = summarize(results)
    local failed = {}
    last_results = results
    last_summary = summary
    has_run = true

    for _, result in ipairs(results) do
        if not result.ok and not result.optional then
            tinsert(failed, result.label .. "=" .. tostring(result.detail))
        end
    end
    last_failures = failed

    if fail == 0 then
        NS.log("API probe complete: " .. summary)
    else
        NS.log_warning("API probe complete: " .. summary .. " [" .. concat(failed, ", ") .. "]")
    end

    if player and target and NS.PriestSpells then
        run_range_probe("Priest Mind Blast", NS.PriestSpells.MindBlast, player, target)
        run_range_probe("Priest Vampiric Touch", NS.PriestSpells.VampiricTouch, player, target)
    end

    return fail == 0, summary, pass, fail, skip, results, failed
end

function NS.get_api_probe_results()
    return last_results, last_summary, has_run, last_failures
end

function NS.get_api_probe_report()
    if not has_run then
        return "API probe has not run."
    end
    if #last_failures == 0 then
        return "API probe OK: " .. tostring(last_summary)
    end
    return "API probe failures: " .. concat(last_failures, "; ")
end

function NS.maybe_auto_run_api_probe()
    if auto_probe_ran then return end
    if NS.get_setting and NS.get_setting("run_api_probe_on_start", false) then
        auto_probe_ran = true
        NS.run_api_probe()
    end
end

NS.log("API probe ready")

return {
    run = NS.run_api_probe,
    get_results = NS.get_api_probe_results,
    maybe_auto_run = NS.maybe_auto_run_api_probe,
}
