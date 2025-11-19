-- Luacheck configuration for kawa.vim

-- Global vim object
globals = {
  "vim",
}

-- Read-only globals
read_globals = {
  "vim",
}

-- Ignore unused self argument in methods
self = false

-- Max line length
max_line_length = 120

-- Exclude test files from some checks
files["tests/**/*_spec.lua"] = {
  std = "+busted",
}
