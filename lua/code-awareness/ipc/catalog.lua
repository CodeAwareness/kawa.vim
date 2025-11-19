-- Catalog registration for Code Awareness
local M = {}

--- Register client with catalog to get client GUID
---@param temp_guid string Temporary GUID for registration
---@param callback function Callback(err, client_guid)
function M.register_client(temp_guid, callback)
  local util = require("code-awareness.util")
  local socket = require("code-awareness.ipc.socket")
  local protocol = require("code-awareness.ipc.protocol")

  local catalog_path = util.get_socket_path("catalog")

  util.log.debug("Registering with catalog: " .. catalog_path)

  -- Check if catalog socket exists (Unix only)
  if vim.fn.has("win32") == 0 and not socket.exists(catalog_path) then
    callback("Catalog socket not found: " .. catalog_path, nil)
    return
  end

  -- Connect to catalog
  local pipe = socket.connect(catalog_path, function(err, connected_pipe)
    if err then
      callback("Failed to connect to catalog: " .. err, nil)
      return
    end

    if not connected_pipe then
      callback("Pipe is nil after connection", nil)
      return
    end

    local active_pipe = connected_pipe

    -- Send clientId request with temporary GUID in data and caw fields
    local request = protocol.encode_message("req", "*", "clientId", temp_guid, temp_guid)

    socket.write(active_pipe, request, function(write_err)
      if write_err then
        socket.close(active_pipe)
        callback("Write error: " .. write_err, nil)
        return
      end

      util.log.info("Registered with catalog using GUID: " .. temp_guid)
      socket.close(active_pipe)
      callback(nil, temp_guid)
    end)
  end)

  if not pipe then
    callback("Failed to create pipe", nil)
    return
  end
end

return M
