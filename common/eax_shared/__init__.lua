-- EAX Shared Modules
-- Common utilities for all EAX rotation plugins

local eax_shared = {}

eax_shared.spell_resolver = require("common.eax_shared.spell_resolver")
eax_shared.mode_detector = require("common.eax_shared.mode_detector")
eax_shared.target_finder = require("common.eax_shared.target_finder")

return eax_shared
