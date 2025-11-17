-- IPC manager for Code Awareness
local M = {}

-- IPC state
local state = {
  connected = false,
  client_guid = nil,
  socket = nil,
}

--- Connect to Kawa Code app
---@param callback function Callback(err)
function M.connect(callback)
  local util = require('code-awareness.util')
  util.log.debug('IPC connect called (stub)')

  -- TODO: Implement in Phase 1
  -- For now, just fail gracefully
  vim.defer_fn(function()
    callback('IPC not yet implemented')
  end, 100)
end

--- Disconnect from Kawa Code app
function M.disconnect()
  local util = require('code-awareness.util')
  util.log.debug('IPC disconnect called (stub)')

  state.connected = false
  state.client_guid = nil
  state.socket = nil
end

--- Send message to Kawa Code app
---@param domain string Message domain
---@param action string Message action
---@param data table Message data
---@param response_handler function|nil Response callback
function M.send(domain, action, data, response_handler)
  local util = require('code-awareness.util')
  util.log.debug(string.format('IPC send: %s:%s (stub)', domain, action))

  -- TODO: Implement in Phase 1
end

--- Check if connected
---@return boolean
function M.is_connected()
  return state.connected
end

--- Get client GUID
---@return string|nil
function M.get_client_guid()
  return state.client_guid
end

return M
