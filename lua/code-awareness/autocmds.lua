-- Autocommands for Code Awareness
local M = {}

-- Get platform implementation
local platform = require("code-awareness.platform").get_impl()

local augroup_id = nil

--- Set up autocommands
function M.setup()
  if augroup_id then
    return
  end

  augroup_id = platform.autocmd.create_group("CodeAwareness")

  -- Buffer tracking
  platform.autocmd.create({
    event = "BufEnter",
    group = augroup_id,
    pattern = "*",
    callback = function()
      M.on_buf_enter()
    end,
  })

  -- Save tracking
  platform.autocmd.create({
    event = "BufWritePost",
    group = augroup_id,
    pattern = "*",
    callback = function()
      M.on_buf_write()
    end,
  })

  -- Buffer cleanup
  platform.autocmd.create({
    event = "BufDelete",
    group = augroup_id,
    pattern = "*",
    callback = function()
      -- Get buffer number - in Vim, we need to use vim.fn.expand
      local bufnr
      if vim.fn.has("nvim") == 1 then
        bufnr = vim.fn.expand("<abuf>")
      else
        bufnr = vim.fn.expand("<abuf>")
      end
      M.on_buf_delete(tonumber(bufnr))
    end,
  })

  -- Theme change
  platform.autocmd.create({
    event = "ColorScheme",
    group = augroup_id,
    pattern = "*",
    callback = function()
      M.on_colorscheme()
    end,
  })

  -- Vim exit
  platform.autocmd.create({
    event = "VimLeavePre",
    group = augroup_id,
    pattern = "*",
    callback = function()
      require("code-awareness").on_vim_leave()
    end,
  })
end

--- Teardown autocommands
function M.teardown()
  if augroup_id then
    platform.autocmd.delete_group(augroup_id)
    augroup_id = nil
  end
end

--- Handle BufEnter event
function M.on_buf_enter()
  local bufnr = platform.window.get_current_buf()
  local util = require("code-awareness.util")
  local config = require("code-awareness.config")

  if not util.is_normal_buffer(bufnr) then
    return
  end

  if not config.get("send_on_buffer_enter") then
    return
  end

  util.log.debug("BufEnter: " .. platform.buffer.get_name(bufnr))

  -- Send active path update (debounced)
  local active = require("code-awareness.active")
  active.send_update_debounced(bufnr)
end

--- Handle BufWritePost event
function M.on_buf_write()
  local bufnr = platform.window.get_current_buf()
  local util = require("code-awareness.util")
  local config = require("code-awareness.config")

  if not util.is_normal_buffer(bufnr) then
    return
  end

  if not config.get("send_on_save") then
    return
  end

  util.log.debug("BufWritePost: " .. platform.buffer.get_name(bufnr))

  -- Send active path update (immediate)
  local active = require("code-awareness.active")
  active.send_update(bufnr)
end

--- Handle BufDelete event
---@param bufnr number
function M.on_buf_delete(bufnr)
  local state = require("code-awareness.state")
  local highlight = require("code-awareness.highlight")

  highlight.clear_highlights(bufnr)
  state.clear_buffer(bufnr)
end

--- Handle ColorScheme event
function M.on_colorscheme()
  local highlight = require("code-awareness.highlight")
  highlight.refresh_colors()
end

return M
