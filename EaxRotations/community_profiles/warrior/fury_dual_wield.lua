-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "community_profiles/warrior/fury_dual_wield.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
return {
   name = "Fury Dual Wield",
   author = "EaxRotations",
   class = "warrior",
   spec = "fury",
   patch = "2.4.3",
   description = "Dual wield fury warrior rotation for raid play",
   settings = {
      use_cooldowns = true,
      use_bloodthirst = true,
      use_whirlwind = true,
      use_heroic_strike = true,
      heroic_strike_rage = 60,
   },
   metadata = {
      date = "2026-05-13",
      version = "1.0.0",
   },
}
