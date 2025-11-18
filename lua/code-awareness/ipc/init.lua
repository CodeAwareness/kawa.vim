-- IPC manager for Code Awareness
local M = {}

-- IPC state
local state = {
  connected = false,
  client_guid = nil,
  temp_guid = nil,  -- Temporary GUID used for registration
  socket = nil,
  parser = nil,
  poll_attempts = 0,
  poll_timer = nil,
}

--- Connect to Kawa Code app
---@param callback function Callback(err)
function M.connect(callback)
  local util = require('code-awareness.util')
  local catalog = require('code-awareness.ipc.catalog')
  local config = require('code-awareness.config')

  if state.connected then
    callback(nil)
    return
  end

  util.log.info('Starting IPC connection process')

  -- Generate temporary GUID for registration
  state.temp_guid = util.generate_guid()
  util.log.debug('Generated temporary GUID: ' .. state.temp_guid)

  -- Step 1: Register with catalog to get client GUID
  catalog.register_client(state.temp_guid, function(err, client_guid)
    if err then
      callback(err)
      return
    end

    state.client_guid = client_guid
    util.log.info('Got client GUID: ' .. client_guid)

    -- Step 2: Poll for client socket
    state.poll_attempts = 0
    M.poll_for_client_socket(callback)
  end)
end

--- Poll for client socket with exponential backoff
---@param callback function Callback(err)
function M.poll_for_client_socket(callback)
  local util = require('code-awareness.util')
  local socket = require('code-awareness.ipc.socket')
  local config = require('code-awareness.config')

  local max_attempts = config.get('max_poll_attempts') or 5
  local client_socket_path = util.get_socket_path(state.client_guid)

  state.poll_attempts = state.poll_attempts + 1

  util.log.debug(string.format('Polling for client socket (attempt %d/%d): %s',
    state.poll_attempts, max_attempts, client_socket_path))

  -- Check if socket exists
  if socket.exists(client_socket_path) then
    util.log.info('Client socket found, connecting...')
    M.connect_to_client_socket(client_socket_path, callback)
    return
  end

  -- Check if we've exceeded max attempts
  if state.poll_attempts >= max_attempts then
    callback('Client socket not found after ' .. max_attempts .. ' attempts')
    return
  end

  -- Calculate delay with exponential backoff: 500ms, 1s, 2s, 4s, 8s
  local delay_ms = 500 * math.pow(2, state.poll_attempts - 1)

  util.log.debug(string.format('Socket not found, retrying in %dms', delay_ms))

  -- Schedule next poll attempt
  state.poll_timer = vim.defer_fn(function()
    M.poll_for_client_socket(callback)
  end, delay_ms)
end

--- Connect to client socket
---@param socket_path string Socket path
---@param callback function Callback(err)
function M.connect_to_client_socket(socket_path, callback)
  local util = require('code-awareness.util')
  local socket = require('code-awareness.ipc.socket')
  local protocol = require('code-awareness.ipc.protocol')

  local pipe = socket.connect(socket_path, function(err, connected_pipe)
    if err then
      callback(err)
      return
    end

    if not connected_pipe then
      callback('Pipe is nil after connection')
      return
    end

    state.socket = connected_pipe
    state.parser = protocol.create_parser()
    state.connected = true

    util.log.info('Connected to client socket')

    -- Set up message read loop
    M.setup_read_loop()

    -- Connection successful
    callback(nil)
  end)

  if not pipe then
    callback('Failed to create socket')
  end
end

--- Set up message read loop
function M.setup_read_loop()
  local util = require('code-awareness.util')
  local socket = require('code-awareness.ipc.socket')
  local events = require('code-awareness.events')

  socket.read_start(state.socket, function(err, chunk)
    if err then
      util.log.error('Socket read error: ' .. err)
      M.on_disconnect()
      return
    end

    if not chunk then
      -- EOF - connection closed
      util.log.warn('Socket connection closed by server')
      M.on_disconnect()
      return
    end

    -- Feed chunk to parser
    state.parser:feed(chunk)

    -- Process all complete messages in buffer
    while true do
      local message, parse_err = state.parser:next_message()

      if parse_err then
        util.log.error('Message parse error: ' .. parse_err)
        break
      end

      if not message then
        -- No more complete messages
        break
      end

      -- Dispatch message to event system
      events.dispatch(message)
    end
  end)
end

--- Handle disconnection
function M.on_disconnect()
  local util = require('code-awareness.util')

  if not state.connected then
    return
  end

  util.log.warn('IPC disconnected')

  state.connected = false

  if state.socket then
    local socket = require('code-awareness.ipc.socket')
    socket.close(state.socket)
    state.socket = nil
  end

  state.parser = nil

  -- TODO: Implement auto-reconnect logic if needed
end

--- Disconnect from Kawa Code app
function M.disconnect()
  local util = require('code-awareness.util')

  if state.poll_timer then
    vim.fn.timer_stop(state.poll_timer)
    state.poll_timer = nil
  end

  if not state.connected then
    return
  end

  util.log.info('Disconnecting from Kawa Code')

  local socket = require('code-awareness.ipc.socket')
  socket.close(state.socket)

  state.connected = false
  state.client_guid = nil
  state.temp_guid = nil
  state.socket = nil
  state.parser = nil
  state.poll_attempts = 0
end

--- Send message to Kawa Code app
---@param domain string Message domain
---@param action string Message action
---@param data table Message data
---@param response_handler function|nil Response callback(data, message)
function M.send(domain, action, data, response_handler)
  local util = require('code-awareness.util')

  if not state.connected then
    util.log.error('Cannot send message: not connected')
    return
  end

  local protocol = require('code-awareness.ipc.protocol')
  local socket = require('code-awareness.ipc.socket')
  local events = require('code-awareness.events')

  -- Register response handler if provided
  if response_handler then
    events.register_response_handler(domain, action, response_handler)
  end

  -- Encode message
  local message_str = protocol.encode_message('req', domain, action, data, state.client_guid)

  util.log.debug(string.format('Sending: %s:%s', domain, action))

  -- Send message
  socket.write(state.socket, message_str, function(err)
    if err then
      util.log.error('Socket write error: ' .. err)
      M.on_disconnect()
    end
  end)
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
