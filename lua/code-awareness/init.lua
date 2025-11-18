-- Main module for Code Awareness
local M = {}

-- Module state
M._state = {
  enabled = false,
  initialized = false,
}

-- Default configuration
local default_config = {
  enabled = true,
  debug = false,

  -- IPC settings
  catalog_name = 'catalog',
  socket_dir = vim.fn.expand('~/.kawa-code/sockets'),
  connection_timeout = 5000,
  max_poll_attempts = 10,

  -- Highlight settings
  highlight = {
    enabled = true,
    style = 'extmark',
    intensity = 0.3,
    full_width = true,
    colors = {
      light = '#00b1a420',
      dark = '#03445f',
    },
  },

  -- Update behavior
  update_delay = 500,
  send_on_save = true,
  send_on_buffer_enter = true,

  -- Diff settings
  diff_tool = 'diffthis',
  diff_layout = 'vertical',

  -- UI settings
  statusline = {
    enabled = true,
    show_peer_count = true,
  },
}

--- Setup function called by user
---@param user_config table|nil User configuration
function M.setup(user_config)
  user_config = user_config or {}

  -- Merge user config with defaults
  local config = require('code-awareness.config')
  config.set(vim.tbl_deep_extend('force', default_config, user_config))

  M._state.initialized = true

  -- Auto-enable if configured
  if config.get('enabled') then
    M.enable()
  end
end

--- Enable Code Awareness
function M.enable()
  if M._state.enabled then
    return
  end

  local config = require('code-awareness.config')
  local util = require('code-awareness.util')

  util.log.info('Enabling Code Awareness')

  -- Initialize IPC connection
  local ipc = require('code-awareness.ipc')
  ipc.connect(function(err)
    if err then
      util.log.error('Failed to connect to Kawa Code: ' .. err)
      return
    end

    util.log.info('Connected to Kawa Code')
    M._state.enabled = true

    vim.schedule(function()
      -- Set up autocommands
      require('code-awareness.autocmds').setup()

      -- Initialize highlights
      require('code-awareness.highlight').init()

      -- Initialize peer event handlers
      require('code-awareness.peer').setup()
    end)
  end)
end

--- Disable Code Awareness
function M.disable()
  if not M._state.enabled then
    return
  end

  local util = require('code-awareness.util')
  util.log.info('Disabling Code Awareness')

  -- Clear all highlights
  require('code-awareness.highlight').clear_all()

  -- Disconnect IPC
  local ipc = require('code-awareness.ipc')
  ipc.disconnect()

  -- Remove autocommands
  require('code-awareness.autocmds').teardown()

  M._state.enabled = false
end

--- Toggle Code Awareness on/off
function M.toggle()
  if M._state.enabled then
    M.disable()
  else
    M.enable()
  end
end

--- Check if Code Awareness is enabled
---@return boolean
function M.is_enabled()
  return M._state.enabled
end

--- Get current state
---@return table
function M.get_state()
  return require('code-awareness.state').get_all()
end

--- Called on VimEnter
function M.on_vim_enter()
  if not M._state.initialized then
    -- User didn't call setup(), use defaults
    M.setup({})
  end
end

--- Called on VimLeavePre
function M.on_vim_leave()
  if M._state.enabled then
    M.disable()
  end
end

return M
