-- Socket utilities for Code Awareness IPC
local M = {}

-- Get platform implementation
local platform = require("code-awareness.platform").get_impl()

--- Create a new pipe (Unix socket or Windows named pipe)
---@return table|nil pipe object or nil on error
function M.new_pipe()
  return platform.ipc.new_pipe()
end

--- Connect to a socket
---@param path string Socket path
---@param on_connect function Callback(err, pipe)
---@return table|nil pipe object or nil
function M.connect(path, on_connect)
  local util = require("code-awareness.util")
  local pipe = M.new_pipe()

  if not pipe then
    on_connect("Failed to create pipe", nil)
    return nil
  end

  util.log.debug("Connecting to socket: " .. path)

  -- Use platform abstraction for connection
  platform.ipc.connect(pipe, path, function(err)
    if err then
      util.log.error("Socket connect error: " .. err)
      on_connect(err, nil)
    else
      util.log.debug("Socket connected: " .. path)
      on_connect(nil, pipe)
    end
  end)

  return pipe
end

--- Write data to socket
---@param pipe table Pipe object
---@param data string Data to write
---@param callback function|nil Callback(err)
function M.write(pipe, data, callback)
  if not pipe then
    if callback then
      callback("Pipe is nil")
    end
    return
  end

  platform.ipc.write(pipe, data, callback)
end

--- Start reading from socket
---@param pipe table Pipe object
---@param on_data function Callback(err, chunk)
function M.read_start(pipe, on_data)
  if not pipe then
    on_data("Pipe is nil", nil)
    return
  end

  platform.ipc.read_start(pipe, on_data)
end

--- Stop reading from socket
---@param pipe table Pipe object
function M.read_stop(pipe)
  platform.ipc.read_stop(pipe)
end

--- Close socket
---@param pipe table Pipe object
---@param callback function|nil Callback when closed
function M.close(pipe, callback)
  platform.ipc.close(pipe, callback)
end

--- Check if socket path exists
---@param path string Socket path
---@return boolean
function M.exists(path)
  return platform.ipc.fs_stat(path)
end

return M
