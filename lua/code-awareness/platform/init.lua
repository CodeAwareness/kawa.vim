-- Platform abstraction layer for Code Awareness
-- Provides common API that works on both Neovim and Vim
local M = {}

---  Detect current platform
---@return string 'neovim' or 'vim'
function M.detect()
  if vim.fn.has("nvim") == 1 then
    return "neovim"
  else
    return "vim"
  end
end

--- Get platform-specific implementation module
---@return table Platform implementation
function M.get_impl()
  local platform = M.detect()

  if platform == "neovim" then
    return require("code-awareness.platform.neovim")
  else
    return require("code-awareness.platform.vim")
  end
end

return M
