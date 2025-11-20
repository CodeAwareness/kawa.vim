-- Neovim-specific platform implementation
local M = {}

-- IPC/Socket operations
M.ipc = {}

--- Create a new pipe for socket communication
---@return table|nil pipe object
function M.ipc.new_pipe()
  if not vim.loop then
    return nil
  end
  return vim.loop.new_pipe(false)
end

--- Connect to a Unix socket or named pipe
---@param pipe table Pipe object
---@param path string Socket path
---@param callback function Callback(err)
function M.ipc.connect(pipe, path, callback)
  pipe:connect(path, callback)
end

--- Write data to pipe
---@param pipe table Pipe object
---@param data string Data to write
---@param callback function|nil Callback(err)
function M.ipc.write(pipe, data, callback)
  pipe:write(data, callback)
end

--- Start reading from pipe
---@param pipe table Pipe object
---@param callback function Callback(err, chunk)
function M.ipc.read_start(pipe, callback)
  pipe:read_start(callback)
end

--- Stop reading from pipe
---@param pipe table Pipe object
function M.ipc.read_stop(pipe)
  if pipe and not pipe:is_closing() then
    pipe:read_stop()
  end
end

--- Close pipe
---@param pipe table Pipe object
---@param callback function|nil Callback when closed
function M.ipc.close(pipe, callback)
  if not pipe or pipe:is_closing() then
    if callback then callback() end
    return
  end

  M.ipc.read_stop(pipe)
  pipe:close(callback)
end

--- Check if socket/file exists
---@param path string File path
---@return boolean
function M.ipc.fs_stat(path)
  return vim.loop.fs_stat(path) ~= nil
end

-- Highlighting operations
M.highlight = {}

--- Create namespace for highlights
---@param name string Namespace name
---@return number Namespace ID
function M.highlight.create_namespace(name)
  return vim.api.nvim_create_namespace(name)
end

--- Set highlight group
---@param ns_id number Namespace ID (unused for highlight groups)
---@param name string Highlight group name
---@param opts table Highlight options
function M.highlight.set_hl(ns_id, name, opts)
  vim.api.nvim_set_hl(0, name, opts)
end

--- Apply highlight to buffer line
---@param bufnr number Buffer number
---@param ns_id number Namespace ID
---@param line number Line number (0-based)
---@param opts table Extmark options
---@return boolean success
function M.highlight.set_extmark(bufnr, ns_id, line, opts)
  local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line, 0, opts)
  return ok
end

--- Clear highlights from buffer
---@param bufnr number Buffer number
---@param ns_id number Namespace ID
function M.highlight.clear_namespace(bufnr, ns_id)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

--- Get extmarks from buffer
---@param bufnr number Buffer number
---@param ns_id number Namespace ID
---@return table Extmarks
function M.highlight.get_extmarks(bufnr, ns_id)
  return vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
end

-- Buffer operations
M.buffer = {}

--- Check if buffer is valid
---@param bufnr number Buffer number
---@return boolean
function M.buffer.is_valid(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr)
end

--- Get buffer name (file path)
---@param bufnr number Buffer number
---@return string
function M.buffer.get_name(bufnr)
  return vim.api.nvim_buf_get_name(bufnr)
end

--- Get buffer lines
---@param bufnr number Buffer number
---@param start number Start line (0-based)
---@param end_ number End line (0-based, -1 for end of buffer)
---@return table Lines
function M.buffer.get_lines(bufnr, start, end_)
  return vim.api.nvim_buf_get_lines(bufnr, start, end_, false)
end

--- Get buffer option
---@param bufnr number Buffer number
---@param name string Option name
---@return any
function M.buffer.get_option(bufnr, name)
  return vim.api.nvim_buf_get_option(bufnr, name)
end

--- Get buffer line count
---@param bufnr number Buffer number
---@return number
function M.buffer.line_count(bufnr)
  return vim.api.nvim_buf_line_count(bufnr)
end

--- Get list of all buffers
---@return table Buffer numbers
function M.buffer.list()
  return vim.api.nvim_list_bufs()
end

-- Window operations
M.window = {}

--- Get current buffer
---@return number Buffer number
function M.window.get_current_buf()
  return vim.api.nvim_get_current_buf()
end

--- Get cursor position
---@return table {line, column}
function M.window.get_cursor()
  return vim.api.nvim_win_get_cursor(0)
end

-- Autocmd operations
M.autocmd = {}

--- Create autocommand group
---@param name string Group name
---@return number Group ID
function M.autocmd.create_group(name)
  return vim.api.nvim_create_augroup(name, { clear = true })
end

--- Delete autocommand group
---@param group_id number Group ID
function M.autocmd.delete_group(group_id)
  vim.api.nvim_del_augroup_by_id(group_id)
end

--- Create autocommand
---@param opts table Autocmd options
function M.autocmd.create(opts)
  vim.api.nvim_create_autocmd(opts.event, {
    group = opts.group,
    pattern = opts.pattern,
    callback = opts.callback,
  })
end

-- Utility operations
M.util = {}

--- Schedule function to run on main loop
---@param fn function Function to run
function M.util.schedule(fn)
  vim.schedule(fn)
end

--- Check if in fast event
---@return boolean
function M.util.in_fast_event()
  return vim.in_fast_event()
end

--- Defer function execution
---@param fn function Function to run
---@param timeout number Timeout in ms
---@return number Timer ID
function M.util.defer_fn(fn, timeout)
  return vim.defer_fn(fn, timeout)
end

--- Stop timer
---@param timer_id number Timer ID
function M.util.timer_stop(timer_id)
  vim.fn.timer_stop(timer_id)
end

--- JSON encode
---@param data table Data to encode
---@return string JSON string
function M.util.json_encode(data)
  return vim.json.encode(data)
end

--- JSON decode
---@param str string JSON string
---@return table Decoded data
function M.util.json_decode(str)
  return vim.json.decode(str)
end

--- Notify user
---@param msg string Message
---@param level number Log level
function M.util.notify(msg, level)
  vim.notify(msg, level)
end

--- Get log levels
---@return table Log levels
function M.util.log_levels()
  return vim.log.levels
end

return M
