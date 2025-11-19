-- Socket utilities for Code Awareness IPC
local M = {}

--- Create a new pipe (Unix socket or Windows named pipe)
---@return table|nil pipe object or nil on error
function M.new_pipe()
  if not vim.loop then
    return nil
  end

  local pipe = vim.loop.new_pipe(false)
  return pipe
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

  -- Determine if this is a Unix socket or named pipe
  local is_windows = vim.fn.has("win32") == 1

  if is_windows then
    -- Windows named pipe
    pipe:connect(path, function(err)
      if err then
        util.log.error("Socket connect error: " .. err)
        on_connect(err, nil)
      else
        util.log.debug("Socket connected: " .. path)
        on_connect(nil, pipe)
      end
    end)
  else
    -- Unix socket
    pipe:connect(path, function(err)
      if err then
        util.log.error("Socket connect error: " .. err)
        on_connect(err, nil)
      else
        util.log.debug("Socket connected: " .. path)
        on_connect(nil, pipe)
      end
    end)
  end

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

  pipe:write(data, callback)
end

--- Start reading from socket
---@param pipe table Pipe object
---@param on_data function Callback(err, chunk)
function M.read_start(pipe, on_data)
  if not pipe then
    on_data("Pipe is nil", nil)
    return
  end

  pipe:read_start(function(err, chunk)
    on_data(err, chunk)
  end)
end

--- Stop reading from socket
---@param pipe table Pipe object
function M.read_stop(pipe)
  if pipe and not pipe:is_closing() then
    pipe:read_stop()
  end
end

--- Close socket
---@param pipe table Pipe object
---@param callback function|nil Callback when closed
function M.close(pipe, callback)
  if not pipe or pipe:is_closing() then
    if callback then
      callback()
    end
    return
  end

  -- Stop reading first
  M.read_stop(pipe)

  -- Close the pipe
  pipe:close(callback)
end

--- Check if socket path exists
---@param path string Socket path
---@return boolean
function M.exists(path)
  local is_windows = vim.fn.has("win32") == 1

  if is_windows then
    -- For Windows named pipes, we can't easily check existence
    -- Try to connect to test
    return true -- Assume it exists, connection will fail if not
  else
    -- For Unix sockets, check if file exists
    return vim.loop.fs_stat(path) ~= nil
  end
end

return M
