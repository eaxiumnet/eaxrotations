local source = debug.getinfo(1, "S").source:sub(2)
local scripts_dir = assert(source:match("^(.*[\\/])[^\\/]+[\\/][^\\/]+$"), "unable to resolve scripts dir")
-- enchant_checker not available in this spec
return nil
