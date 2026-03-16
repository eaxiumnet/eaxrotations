-- spell_resolver.lua
-- Unified spell ID resolution with caching

local spell_resolver = {}
local cache = {}

function spell_resolver.resolve_spell_id(spell_ranks)
    if not spell_ranks then return nil end
    
    local ranks = spell_ranks
    if type(spell_ranks) == "number" then
        ranks = {spell_ranks}
    end
    
    for _, rank in ipairs(ranks) do
        local id = core.spell_book.find_spell_by_id(rank)
        if id and id > 0 then
            return id
        end
    end
    return nil
end

function spell_resolver.get_cached(field_name)
    return cache[field_name]
end

function spell_resolver.set_cached(field_name, spell_id)
    cache[field_name] = spell_id
end

function spell_resolver.clear_cache()
    cache = {}
end

return spell_resolver
