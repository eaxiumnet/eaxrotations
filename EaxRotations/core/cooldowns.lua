-- cooldowns.lua — Cooldown suggestion registry for EaxRotations.
-- WHAT:  registers offensive/defensive cooldowns and suggests the best one per situation.
-- WHEN:  installed by core_sylvanas.lua during addon load.
-- WHY:   separates cooldown priority logic from the 6,000-line core_sylvanas.lua.
-- SAFETY: NS-guarded install; no per-frame allocations; all suggestions use static tables.

-- =============================================================================
-- core/cooldowns.lua
--
-- Cooldown suggestion registry — extracted from EaxRotations/core_sylvanas.lua.
-- Owns NS.cooldown_registry + register_cooldown / unregister_cooldown /
-- get_cooldown_suggestions / get_best_offensive_cooldown /
-- get_best_defensive_cooldown / clear_cooldown_registry.
--
-- WHY THIS EXTRACT
--   The cooldown registry is a small but distinct domain (~120 lines).
--   Isolating it lets future changes (priority scoring, condition hooks)
--   stay inside this file.
--
-- CONTRACT
--   - install(NS): wires the cooldown registry onto NS. NS.spell_ready,
--     NS.spell_id_is_known, NS.cooldown_remains, NS.is_item_ready may all
--     be nil at install time (test mocks); this module nil-guards each.
-- =============================================================================

local M = {}

local _cd_suggestion_buffer

function M.install(NS)
    NS.cooldown_registry = NS.cooldown_registry or {}

    function NS.register_cooldown(entry)
        if type(entry) ~= "table" or not entry.name then return false end
        entry.priority = type(entry.priority) == "number" and entry.priority or 0
        table.insert(NS.cooldown_registry, entry)
        table.sort(NS.cooldown_registry, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
        return true
    end

    function NS.unregister_cooldown(name)
        for i = #NS.cooldown_registry, 1, -1 do
            if NS.cooldown_registry[i].name == name then
                table.remove(NS.cooldown_registry, i)
                return true
            end
        end
        return false
    end

    _cd_suggestion_buffer = { n = 0 }

    function NS.get_cooldown_suggestions(context, category_filter)
        for k in pairs(_cd_suggestion_buffer) do _cd_suggestion_buffer[k] = nil end
        _cd_suggestion_buffer.n = 0
        if type(NS.cooldown_registry) ~= "table" then return _cd_suggestion_buffer end
        for i = 1, #NS.cooldown_registry do
            local entry = NS.cooldown_registry[i]
            if entry and (not category_filter or entry.category == category_filter) then
                local condition_ok = true
                if type(entry.condition) == "function" then
                    local ok, result = pcall(entry.condition, context)
                    condition_ok = ok and result == true
                end
                if condition_ok then
                    local ready = false
                    if entry.spell then
                        if type(entry.spell) == "number" then
                            ready = (NS.spell_id_is_known and NS.spell_id_is_known(entry.spell)
                                and NS.cooldown_remains and NS.cooldown_remains(entry.spell) <= 0) or false
                        else
                            local target = (context and context.me) or (NS.GetPlayer and NS.GetPlayer())
                            ready = NS.spell_ready and NS.spell_ready(entry.spell, target) or false
                        end
                    elseif entry.item_id then
                        ready = NS.is_item_ready and NS.is_item_ready(entry.item_id) or false
                    end
                    if ready then
                        _cd_suggestion_buffer.n = _cd_suggestion_buffer.n + 1
                        _cd_suggestion_buffer[_cd_suggestion_buffer.n] = entry
                    end
                end
            end
        end
        return _cd_suggestion_buffer
    end

    function NS.get_best_offensive_cooldown(context)
        local suggestions = NS.get_cooldown_suggestions(context, "offensive")
        return suggestions.n > 0 and suggestions[1] or nil
    end

    function NS.get_best_defensive_cooldown(context)
        local suggestions = NS.get_cooldown_suggestions(context, "defensive")
        return suggestions.n > 0 and suggestions[1] or nil
    end

    function NS.clear_cooldown_registry()
        if type(NS.cooldown_registry) == "table" then
            for k in pairs(NS.cooldown_registry) do NS.cooldown_registry[k] = nil end
        end
        return true
    end
end

return M
