-- Auto-generated package bootstrap for EAXHunterSurvival
+local __eax_src = debug.getinfo(1, "S").source:gsub("^@", "")
+local __eax_root = __eax_src:match("^(.*[\\/])main%.lua$") or (__eax_src:match("^(.*[\\/])") or "")
+local __eax_lib = __eax_root .. "libraries"
+package.path = table.concat({
+    __eax_lib .. "/?.lua",
+    __eax_lib .. "/?/init.lua",
+    package.path,
+}, ";")
+package.cpath = package.cpath
+assert(loadfile(__eax_lib .. "/main.lua"))()
+