-- User commands for Code Awareness
local M = {}

--- Execute a Code Awareness command
---@param command string Command name
---@vararg any Command arguments
function M.execute(command, ...)
  local args = {...}

  if command == 'status' then
    M.status()
  elseif command == 'toggle' then
    M.toggle()
  elseif command == 'refresh' then
    M.refresh()
  elseif command == 'clear' then
    M.clear()
  elseif command == 'reconnect' then
    M.reconnect()
  elseif command == 'debug' or command == 'logs' then
    M.show_logs()
  else
    vim.notify('[code-awareness] Unknown command: ' .. command, vim.log.levels.ERROR)
  end
end

--- Show status
function M.status()
  local ca = require('code-awareness')
  local ipc = require('code-awareness.ipc')

  local lines = {
    'Code Awareness Status',
    '=====================',
    '',
    'Enabled: ' .. tostring(ca.is_enabled()),
    'Connected: ' .. tostring(ipc.is_connected()),
  }

  -- Show in floating window or echo
  for _, line in ipairs(lines) do
    print(line)
  end
end

--- Toggle Code Awareness
function M.toggle()
  local ca = require('code-awareness')
  ca.toggle()

  if ca.is_enabled() then
    vim.notify('[code-awareness] Enabled', vim.log.levels.INFO)
  else
    vim.notify('[code-awareness] Disabled', vim.log.levels.INFO)
  end
end

--- Refresh current buffer
function M.refresh()
  local ca = require('code-awareness')

  if not ca.is_enabled() then
    vim.notify('[code-awareness] Not enabled', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local active = require('code-awareness.active')

  active.send_update(bufnr)
  vim.notify('[code-awareness] Refreshing...', vim.log.levels.INFO)
end

--- Clear all highlights
function M.clear()
  local highlight = require('code-awareness.highlight')
  highlight.clear_all()
  vim.notify('[code-awareness] Cleared all highlights', vim.log.levels.INFO)
end

--- Reconnect to Kawa Code
function M.reconnect()
  local ipc = require('code-awareness.ipc')
  ipc.disconnect()

  vim.defer_fn(function()
    ipc.connect(function(err)
      if err then
        vim.notify('[code-awareness] Reconnect failed: ' .. err, vim.log.levels.ERROR)
      else
        vim.notify('[code-awareness] Reconnected', vim.log.levels.INFO)
      end
    end)
  end, 100)
end

--- Show debug logs
function M.show_logs()
  local util = require('code-awareness.util')
  local logs = util.log.get_logs()

  if #logs == 0 then
    print('No logs available')
    return
  end

  print('Code Awareness Logs')
  print('===================')
  for _, log in ipairs(logs) do
    print(log)
  end
end

return M
