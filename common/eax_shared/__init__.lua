-- EAX Shared Modules
-- Common utilities for all EAX rotation plugins

local eax_shared = {}

eax_shared.spell_resolver    = require("common.eax_shared.spell_resolver")
eax_shared.mode_detector     = require("common.eax_shared.mode_detector")
eax_shared.target_finder     = require("common.eax_shared.target_finder")
eax_shared.interrupt_manager = require("common.eax_shared.interrupt_manager")
eax_shared.defensive_manager = require("common.eax_shared.defensive_manager")
eax_shared.racial_manager    = require("common.eax_shared.racial_manager")
eax_shared.ttd_tracker       = require("common.eax_shared.ttd_tracker")
eax_shared.pet_manager       = require("common.eax_shared.pet_manager")
eax_shared.talents           = require("common.eax_shared.talents")

return eax_shared
