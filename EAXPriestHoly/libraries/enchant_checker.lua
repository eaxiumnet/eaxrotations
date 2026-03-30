local source = debug.getinfo(1, "S").source:sub(2)
local scripts_dir = assert(source:match("^(.*[\\/])[^\\/]+[\\/][^\\/]+$"), "unable to resolve scripts dir")
return assert(loadfile(scripts_dir .. "../eax_shared/enchant_checker.lua"))()
