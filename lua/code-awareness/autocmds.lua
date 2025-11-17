-- Autocommands for Code Awareness
local M = {}

local augroup_id = nil

--- Set up autocommands
function M.setup()
  if augroup_id then
    return
  end

  augroup_id = vim.api.nvim_create_augroup('CodeAwareness', { clear = true })

  -- Buffer tracking
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup_id,
    pattern = '*',
    callback = function()
      M.on_buf_enter()
    end,
  })

  -- Save tracking
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = augroup_id,
    pattern = '*',
    callback = function()
      M.on_buf_write()
    end,
  })

  -- Buffer cleanup
  vim.api.nvim_create_autocmd('BufDelete', {
    group = augroup_id,
    pattern = '*',
    callback = function(args)
      M.on_buf_delete(args.buf)
    end,
  })

  -- Theme change
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = augroup_id,
    pattern = '*',
    callback = function()
      M.on_colorscheme()
    end,
  })

  -- Vim exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup_id,
    callback = function()
      require('code-awareness').on_vim_leave()
    end,
  })
end

--- Teardown autocommands
function M.teardown()
  if augroup_id then
    vim.api.nvim_del_augroup_by_id(augroup_id)
    augroup_id = nil
  end
end

--- Handle BufEnter event
function M.on_buf_enter()
  local bufnr = vim.api.nvim_get_current_buf()
  local util = require('code-awareness.util')
  local config = require('code-awareness.config')

  if not util.is_normal_buffer(bufnr) then
    return
  end

  if not config.get('send_on_buffer_enter') then
    return
  end

  util.log.debug('BufEnter: ' .. vim.api.nvim_buf_get_name(bufnr))

  -- Send active path update (debounced)
  local active = require('code-awareness.active')
  active.send_update_debounced(bufnr)
end

--- Handle BufWritePost event
function M.on_buf_write()
  local bufnr = vim.api.nvim_get_current_buf()
  local util = require('code-awareness.util')
  local config = require('code-awareness.config')

  if not util.is_normal_buffer(bufnr) then
    return
  end

  if not config.get('send_on_save') then
    return
  end

  util.log.debug('BufWritePost: ' .. vim.api.nvim_buf_get_name(bufnr))

  -- Send active path update (immediate)
  local active = require('code-awareness.active')
  active.send_update(bufnr)
end

--- Handle BufDelete event
---@param bufnr number
function M.on_buf_delete(bufnr)
  local state = require('code-awareness.state')
  local highlight = require('code-awareness.highlight')

  highlight.clear_highlights(bufnr)
  state.clear_buffer(bufnr)
end

--- Handle ColorScheme event
function M.on_colorscheme()
  local highlight = require('code-awareness.highlight')
  highlight.refresh_colors()
end

return M
