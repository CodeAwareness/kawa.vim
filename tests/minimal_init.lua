-- Minimal init for running tests

-- Add plugin to runtimepath
vim.cmd([[set runtimepath+=.]])

-- Add plenary.nvim to runtimepath (assuming it's installed)
local plenary_path = vim.fn.stdpath('data') .. '/site/pack/*/start/plenary.nvim'
local plenary_matches = vim.fn.glob(plenary_path, false, true)
if #plenary_matches > 0 then
  vim.opt.runtimepath:append(plenary_matches[1])
end

-- Set up test environment
vim.o.swapfile = false
vim.o.loadplugins = false
