-- Utility functions for Code Awareness
local M = {}

-- Log buffer (circular buffer of last 100 messages)
local log_buffer = {}
local log_max_size = 100

-- Seed RNG once for GUID generation
math.randomseed(os.time() + vim.loop.hrtime())

-- Log levels
local LOG_LEVELS = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

--- Add message to log buffer
---@param level string Log level
---@param message string Log message
local function add_to_buffer(level, message)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local entry = string.format("[%s] [%s] %s", timestamp, level, message)

  table.insert(log_buffer, entry)

  if #log_buffer > log_max_size then
    table.remove(log_buffer, 1)
  end
end

--- Check if debug mode is enabled
---@return boolean
local function is_debug()
  local config = require("code-awareness.config")
  return config.get("debug") == true
end

-- Logging functions
M.log = {}

--- Log debug message
---@param message string
function M.log.debug(message)
  add_to_buffer("DEBUG", message)

  if is_debug() then
    print("[code-awareness] DEBUG: " .. message)
  end
end

--- Log info message
---@param message string
function M.log.info(message)
  add_to_buffer("INFO", message)

  if is_debug() then
    print("[code-awareness] INFO: " .. message)
  end
end

--- Log warning message
---@param message string
function M.log.warn(message)
  add_to_buffer("WARN", message)
  vim.schedule(function()
    vim.notify("[code-awareness] " .. message, vim.log.levels.WARN)
  end)
end

--- Log error message
---@param message string
function M.log.error(message)
  add_to_buffer("ERROR", message)
  vim.schedule(function()
    vim.notify("[code-awareness] " .. message, vim.log.levels.ERROR)
  end)
end

--- Get log buffer
---@return table
function M.log.get_logs()
  return log_buffer
end

--- Get socket path (cross-platform)
---@param name string Socket name
---@return string
function M.get_socket_path(name)
  local config = require("code-awareness.config")
  local socket_dir = config.get("socket_dir")

  if vim.fn.has("win32") == 1 then
    -- Windows named pipe
    return "\\\\.\\pipe\\caw." .. name
  else
    -- Unix socket
    return socket_dir .. "/caw." .. name
  end
end

--- Get Git root directory for a file
---@param filepath string File path
---@return string|nil Git root or nil if not in Git repo
function M.get_git_root(filepath)
  if not filepath then
    return nil
  end

  local dir = vim.fn.fnamemodify(filepath, ":h")
  local git_dir = vim.fn.finddir(".git", dir .. ";")

  if git_dir and git_dir ~= "" then
    return vim.fn.fnamemodify(git_dir, ":h")
  end

  return nil
end

--- Normalize path to use forward slashes (cross-platform)
---@param path string
---@return string
function M.normalize_path(path)
  if not path then
    return ""
  end
  return path:gsub("\\", "/")
end

--- Check if buffer is a normal file buffer
---@param bufnr number Buffer number
---@return boolean
function M.is_normal_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
  if buftype ~= "" then
    return false
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if not filepath or filepath == "" then
    return false
  end

  return true
end

--- Generate a unique temporary GUID for this Neovim instance
---@return string GUID string (format: "pid-random")
function M.generate_guid()
  local pid = vim.fn.getpid()
  local random = math.random(1000000)
  return string.format("%d-%d", pid, random)
end

return M
