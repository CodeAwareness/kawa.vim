-- Configuration management for Code Awareness
local M = {}

-- Current configuration
local config = {}

--- Set configuration
---@param new_config table
function M.set(new_config)
  config = new_config
end

--- Get entire configuration
---@return table
function M.get_all()
  return config
end

--- Get configuration value by key (supports dot notation)
---@param key string Configuration key (e.g., 'highlight.enabled')
---@return any
function M.get(key)
  local keys = vim.split(key, '.', { plain = true })
  local value = config

  for _, k in ipairs(keys) do
    if type(value) ~= 'table' then
      return nil
    end
    value = value[k]
  end

  return value
end

--- Update configuration value by key
---@param key string Configuration key
---@param value any New value
function M.update(key, value)
  local keys = vim.split(key, '.', { plain = true })
  local current = config

  for i = 1, #keys - 1 do
    local k = keys[i]
    if type(current[k]) ~= 'table' then
      current[k] = {}
    end
    current = current[k]
  end

  current[keys[#keys]] = value
end

return M
