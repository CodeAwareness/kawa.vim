-- Catalog registration for Code Awareness
local M = {}

--- Register client with catalog to get client GUID
---@param callback function Callback(err, client_guid)
function M.register_client(callback)
  local util = require('code-awareness.util')
  local socket = require('code-awareness.ipc.socket')
  local protocol = require('code-awareness.ipc.protocol')

  local catalog_path = util.get_socket_path('catalog')

  util.log.debug('Registering with catalog: ' .. catalog_path)

  -- Check if catalog socket exists (Unix only)
  if vim.fn.has('win32') == 0 and not socket.exists(catalog_path) then
    callback('Catalog socket not found: ' .. catalog_path, nil)
    return
  end

  -- Connect to catalog
  local pipe = socket.connect(catalog_path, function(err)
    if err then
      callback('Failed to connect to catalog: ' .. err, nil)
      return
    end

    -- Create message parser
    local parser = protocol.create_parser()
    local response_received = false

    -- Set up read handler
    socket.read_start(pipe, function(read_err, chunk)
      if read_err then
        if not response_received then
          socket.close(pipe)
          callback('Read error: ' .. read_err, nil)
        end
        return
      end

      if not chunk then
        -- EOF
        if not response_received then
          socket.close(pipe)
          callback('Connection closed before receiving response', nil)
        end
        return
      end

      -- Feed chunk to parser
      parser:feed(chunk)

      -- Try to extract message
      local message, parse_err = parser:next_message()

      if parse_err then
        socket.close(pipe)
        callback('Parse error: ' .. parse_err, nil)
        return
      end

      if message then
        response_received = true

        -- Close catalog connection
        socket.close(pipe)

        -- Extract client GUID
        if message.flow == 'res' and message.action == 'clientId' then
          local client_guid = message.data and message.data.clientId

          if client_guid then
            util.log.info('Registered with catalog, client GUID: ' .. client_guid)
            callback(nil, client_guid)
          else
            callback('No clientId in response', nil)
          end
        else
          callback('Unexpected response from catalog', nil)
        end
      end
    end)

    -- Send clientId request
    local request = protocol.encode_message('req', '*', 'clientId', {})

    socket.write(pipe, request, function(write_err)
      if write_err then
        socket.close(pipe)
        callback('Write error: ' .. write_err, nil)
      end
    end)
  end)

  if not pipe then
    callback('Failed to create pipe', nil)
  end
end

return M
