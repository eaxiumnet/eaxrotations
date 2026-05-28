-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "community_profiles/warlock/affliction_ht10.lua"
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
   name = "Affliction HT10",
   author = "EaxRotations",
   class = "warlock",
   spec = "affliction",
   patch = "2.4.3",
   description = "High throughput affliction rotation tuned for HT10",
   settings = {
      use_cooldowns = true,
      use_shadow_bolt = true,
      maintain_curse_of_elements = true,
      maintain_corruption = true,
      shadow_embrace_stacks = 5,
   },
   metadata = {
      date = "2026-05-13",
      version = "1.0.0",
   },
}
