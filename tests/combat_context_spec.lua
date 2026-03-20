local combat_context = require("eax_shared/combat_context")

local function make_unit(fields)
    fields = fields or {}
    return {
        get_health = function()
            return fields.health
        end,
        get_max_health = function()
            return fields.max_health
        end,
        get_incoming_heals = function()
            return fields.incoming_heals
        end,
        get_target = function()
            return fields.target
        end,
        is_casting_spell = function()
            return fields.is_casting_spell
        end,
        is_channelling_spell = function()
            return fields.is_channelling_spell
        end,
        get_active_spell_id = function()
            return fields.spell_id
        end,
        get_active_channel_spell_id = function()
            return fields.channel_spell_id
        end,
        get_cast_pct = function()
            return fields.cast_pct
        end,
        is_active_spell_interruptable = function()
            return fields.interruptible
        end,
        get_threat_situation = function()
            return fields.threat_table
        end,
        get_role_id = function()
            return fields.role_id
        end,
        is_valid = function()
            if fields.is_valid == nil then
                return true
            end
            return fields.is_valid
        end,
        is_dead = function()
            return fields.is_dead or false
        end,
        get_guid = function()
            return fields.guid
        end,
    }
end

local function make_deps(overrides)
    local deps = {
        now_s = function()
            return 123.45
        end,
        health_prediction = {
            get_incoming_damage = function(_, unit)
                if unit == nil then
                    return nil
                end
                return 250
            end,
            get_role_id = function(_, unit)
                if unit and unit.get_role_id then
                    return unit:get_role_id()
                end
                return 2
            end,
            is_tank = function(_, unit)
                return unit and unit:get_role_id() == 0 or false
            end,
        },
        encounter_manager = {
            get_policy = function()
                return {
                    hold_cooldowns = true,
                    burn_phase = false,
                    interrupt_priority = true,
                    tank_damage_heavy = false,
                    raid_aoe_heavy = true,
                }
            end,
        },
        party_reader = function()
            return {
                { guid = "party-healer", hp_pct = 0.42, incoming_heal_pct = 0.05, role = "healer", is_tank = false },
                { guid = "party-dps", hp_pct = 0.18, incoming_heal_pct = 0.00, role = "damager", is_tank = false },
            }
        end,
    }

    if overrides then
        for key, value in pairs(overrides) do
            deps[key] = value
        end
    end

    return deps
end

do
    local me = make_unit({
        health = 500,
        max_health = 1000,
        incoming_heals = 100,
        threat_table = { threat_percent = 55 },
    })
    local ctx = combat_context.build(me, nil, nil, make_deps())

    assert(type(ctx) == "table", "build should return a table")
    assert(type(ctx.meta) == "table", "meta table missing")
    assert(type(ctx.self) == "table", "self table missing")
    assert(type(ctx.target) == "table", "target table missing")
    assert(type(ctx.party) == "table", "party table missing")
    assert(type(ctx.encounter) == "table", "encounter table missing")
    assert(ctx.target.exists == false, "missing target should normalize to exists=false")
end

do
    local target = make_unit({
        health = 250,
        max_health = 1000,
        is_casting_spell = true,
        spell_id = 1234,
        cast_pct = 61,
        interruptible = true,
        target = make_unit({ guid = "tank-guid", role_id = 0 }),
    })
    local me = make_unit({
        health = 250,
        max_health = 1000,
        incoming_heals = 125,
        target = target,
        threat_table = { threat_percent = 40 },
    })
    local ctx = combat_context.build(me, target, nil, make_deps())

    assert(ctx.self.hp_pct == 0.25, "self hp_pct should be normalized to 0..1")
    assert(ctx.self.incoming_heal_pct == 0.125, "incoming_heal_pct should be normalized to 0..1")
    assert(ctx.target.hp_pct == 0.25, "target hp_pct should be normalized to 0..1")
    assert(ctx.self.incoming_damage_pct_2s == 0.25, "incoming_damage_pct_2s should be normalized to self max health")
    assert(ctx.party.lowest_hp_pct == 0.18, "party lowest_hp_pct should be normalized to 0..1")
    assert(ctx.party.any_ally_critical == true, "critical ally should be detected")
    assert(type(ctx.party.members) == "table", "party members should be preserved for role policy")
    assert(ctx.party.urgent_ally and ctx.party.urgent_ally.guid == "party-dps", "urgent_ally should identify the lowest uncovered ally")
    assert(ctx.party.tank and ctx.party.tank.guid == "tank-guid", "party tank should be detected from party data or target victim")
    assert(ctx.party.group_collapse_risk > 0, "group collapse risk should surface party danger")
    assert(ctx.target.cast_progress_pct == 0.61, "cast progress should normalize to 0..1")
    assert(ctx.target.victim_role == "tank", "target victim role should be normalized")
    assert(ctx.target.victim_is_self == false, "target victim_is_self should reflect enemy cast target")
end

do
    local me = make_unit({
        health = 0,
        max_health = 0,
        incoming_heals = nil,
        threat_table = nil,
    })
    local ctx = combat_context.build(me, nil, nil, make_deps({
        health_prediction = {
            get_incoming_damage = function()
                error("prediction unavailable")
            end,
            get_role_id = function()
                error("role unavailable")
            end,
            is_tank = function()
                error("tank unavailable")
            end,
        },
        party_reader = function()
            error("party unavailable")
        end,
        encounter_manager = {
            get_policy = function()
                error("policy unavailable")
            end,
        },
    }))

    assert(ctx.meta.valid == true, "fail-safe context should still be valid")
    assert(ctx.meta.fail_safe == true, "fail-safe should be enabled on incomplete reads")
    assert(ctx.self.incoming_damage_2s == 0, "throughput hints should zero when reads fail")
    assert(ctx.self.incoming_damage_pct_2s == 0, "normalized damage hints should zero when reads fail")
    assert(ctx.party.lowest_hp_pct == 0, "party hints should zero when reads fail")
    assert(ctx.party.urgent_ally == nil, "urgent ally should clear when reads fail")
    assert(ctx.target.exists == false, "target should fall back to non-existent in fail-safe mode")
end

print("combat_context_spec: ok")
