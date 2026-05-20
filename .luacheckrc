std = "luajit"
cache = true
codes = true

read_globals = {
  "vim",
}

globals = {
  "vim",
}

ignore = {
  "212", -- unused argument
  "631", -- line too long
}

exclude_files = {
  "tests/fixtures/*",
}
