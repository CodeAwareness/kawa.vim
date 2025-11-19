-- Minimal init for running tests

-- Add plugin to runtimepath
vim.cmd([[set runtimepath+=.]])

-- Add plenary.nvim to runtimepath (check both opt and start locations)
local data_path = vim.fn.stdpath("data")
local plenary_paths = {
  data_path .. "/site/pack/*/opt/plenary.nvim",
  data_path .. "/site/pack/*/start/plenary.nvim",
  data_path .. "/site/pack/test/opt/plenary.nvim",
  data_path .. "/site/pack/test/start/plenary.nvim",
}

for _, path_pattern in ipairs(plenary_paths) do
  local matches = vim.fn.glob(path_pattern, false, true)
  if #matches > 0 then
    vim.opt.runtimepath:append(matches[1])
    break
  end
end

-- Set up test environment
vim.o.swapfile = false
vim.o.loadplugins = false
