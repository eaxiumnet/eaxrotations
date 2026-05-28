local izi = require("common/izi_sdk")
local dispatcher = require("EaxRotation2/engine/dispatcher")

local specs = {
    warrior = {
        arms        = require("EaxRotation2/specs/warrior/arms"),
        fury        = require("EaxRotation2/specs/warrior/fury"),
        protection  = require("EaxRotation2/specs/warrior/protection"),
    },
    paladin = {
        retribution = require("EaxRotation2/specs/paladin/retribution"),
        holy        = require("EaxRotation2/specs/paladin/holy"),
        protection  = require("EaxRotation2/specs/paladin/protection"),
    },
    hunter = {
        beast_mastery   = require("EaxRotation2/specs/hunter/beast_mastery"),
        marksmanship    = require("EaxRotation2/specs/hunter/marksmanship"),
        survival        = require("EaxRotation2/specs/hunter/survival"),
    },
    rogue = {
        assassination   = require("EaxRotation2/specs/rogue/assassination"),
        combat          = require("EaxRotation2/specs/rogue/combat"),
        subtlety        = require("EaxRotation2/specs/rogue/subtlety"),
    },
    priest = {
        discipline  = require("EaxRotation2/specs/priest/discipline"),
        holy        = require("EaxRotation2/specs/priest/holy"),
        shadow      = require("EaxRotation2/specs/priest/shadow"),
        smite       = require("EaxRotation2/specs/priest/smite"),
    },
    shaman = {
        elemental   = require("EaxRotation2/specs/shaman/elemental"),
        enhancement = require("EaxRotation2/specs/shaman/enhancement"),
        restoration = require("EaxRotation2/specs/shaman/restoration"),
    },
    mage = {
        frost   = require("EaxRotation2/specs/mage/frost"),
        fire    = require("EaxRotation2/specs/mage/fire"),
        arcane  = require("EaxRotation2/specs/mage/arcane"),
    },
    warlock = {
        affliction  = require("EaxRotation2/specs/warlock/affliction"),
        demonology  = require("EaxRotation2/specs/warlock/demonology"),
        destruction = require("EaxRotation2/specs/warlock/destruction"),
    },
    druid = {
        balance     = require("EaxRotation2/specs/druid/balance"),
        bear        = require("EaxRotation2/specs/druid/bear"),
        cat         = require("EaxRotation2/specs/druid/cat"),
        resto       = require("EaxRotation2/specs/druid/resto"),
    },
}

local active_spec = nil

-- Auto-detect by class ID. Defaults to first spec in each class.
-- Use set_spec(class, spec_name) for manual selection.
local function detect_spec()
    local me = izi.me()
    if not me then return nil end
    local get_class_fn = me.get_class
    local class = get_class_fn and get_class_fn(me)
    if not class then return nil end

    if class == 1 then
        return specs.warrior.arms
    elseif class == 2 then
        return specs.paladin.retribution
    elseif class == 3 then
        return specs.hunter.beast_mastery
    elseif class == 4 then
        return specs.rogue.combat
    elseif class == 5 then
        return specs.priest.shadow
    elseif class == 7 then
        return specs.shaman.enhancement
    elseif class == 8 then
        return specs.mage.frost
    elseif class == 9 then
        return specs.warlock.affliction
    elseif class == 11 then
        return specs.druid.balance
    end
    return nil
end

local function set_spec(class, spec_name)
    local t = specs[class]
    if not t then return false end
    active_spec = t[spec_name]
    return active_spec ~= nil
end

local function get_active_spec()
    return active_spec
end

local function on_update()
    if not active_spec then
        active_spec = detect_spec()
    end
    if active_spec then
        dispatcher.run(active_spec)
    end
end

return {
    on_update = on_update,
    set_spec = set_spec,
    get_active_spec = get_active_spec,
    detect_spec = detect_spec,
}
