-- Configuration management for Code Awareness
local M = {}

-- Current configuration
local config = {}

--- Set configuration
---@param new_config table
function M.set(new_config)
  config = new_config
end

--- Get configuration value by key (supports dot notation)
---@param key string Configuration key (e.g., 'highlight.enabled')
---@return any
function M.get(key)
  local keys = vim.split(key, ".", { plain = true })
  local value = config

  for _, k in ipairs(keys) do
    if type(value) ~= "table" then
      return nil
    end
    value = value[k]
  end

  return value
end

return M
