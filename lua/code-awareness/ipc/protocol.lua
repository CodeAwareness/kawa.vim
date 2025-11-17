-- Message protocol for Code Awareness IPC
local M = {}

-- Message delimiter (form-feed character)
M.DELIMITER = '\f'

--- Encode a message to JSON string with delimiter
---@param flow string 'req' or 'res' or 'err'
---@param domain string Message domain
---@param action string Message action
---@param data table Message data
---@param caw_id string|nil Client GUID
---@return string JSON string with delimiter
function M.encode_message(flow, domain, action, data, caw_id)
  local message = {
    flow = flow,
    domain = domain,
    action = action,
    data = data or {},
  }

  if caw_id then
    message.caw = caw_id
  end

  local json_str = vim.json.encode(message)
  return json_str .. M.DELIMITER
end

--- Decode a JSON message string
---@param json_str string JSON string (without delimiter)
---@return table|nil, string|nil Decoded message or nil, error message
function M.decode_message(json_str)
  if not json_str or json_str == '' then
    return nil, 'Empty message'
  end

  local ok, decoded = pcall(vim.json.decode, json_str)
  if not ok then
    return nil, 'JSON decode error: ' .. tostring(decoded)
  end

  -- Validate message structure
  if type(decoded) ~= 'table' then
    return nil, 'Message is not a table'
  end

  if not decoded.flow or not decoded.domain or not decoded.action then
    return nil, 'Missing required fields (flow, domain, action)'
  end

  return decoded, nil
end

--- Create a message parser with internal buffer
---@return table Parser instance
function M.create_parser()
  local parser = {
    buffer = '',
  }

  --- Feed data into the parser
  ---@param chunk string Data chunk
  function parser:feed(chunk)
    if chunk and chunk ~= '' then
      self.buffer = self.buffer .. chunk
    end
  end

  --- Extract next complete message from buffer
  ---@return table|nil, string|nil Message or nil if incomplete, error message
  function parser:next_message()
    if self.buffer == '' then
      return nil, nil
    end

    -- Find delimiter
    local delimiter_pos = self.buffer:find(M.DELIMITER, 1, true)

    if not delimiter_pos then
      -- No complete message yet
      return nil, nil
    end

    -- Extract message (excluding delimiter)
    local message_str = self.buffer:sub(1, delimiter_pos - 1)

    -- Remove from buffer (including delimiter)
    self.buffer = self.buffer:sub(delimiter_pos + 1)

    -- Decode message
    return M.decode_message(message_str)
  end

  --- Check if buffer has pending data
  ---@return boolean
  function parser:has_pending()
    return self.buffer ~= ''
  end

  --- Clear buffer
  function parser:clear()
    self.buffer = ''
  end

  return parser
end

return M
