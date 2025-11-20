-- Vim 8.2+ platform implementation
-- Uses VimScript functions and Python3 for socket operations
local M = {}

-- IPC/Socket operations (delegated to VimScript + Python3)
M.ipc = {}

--- Create a new pipe for socket communication
---@return table|nil pipe object (handle to VimScript channel/job)
function M.ipc.new_pipe()
  -- In Vim, we use autoload functions that manage Python3 sockets
  -- Return a table that represents the pipe handle
  return {
    _type = "vim_pipe",
    _handle = nil, -- Will be set by connect
  }
end

--- Connect to a Unix socket or named pipe
---@param pipe table Pipe object
---@param path string Socket path
---@param callback function Callback(err)
function M.ipc.connect(pipe, path, callback)
  -- Delegate to VimScript autoload function
  local success = vim.fn["code_awareness#socket#connect"](path)

  if success == 1 then
    pipe._handle = path -- Store path as handle identifier
    vim.defer_fn(function()
      callback(nil)
    end, 0)
  else
    vim.defer_fn(function()
      callback("Failed to connect to " .. path)
    end, 0)
  end
end

--- Write data to pipe
---@param pipe table Pipe object
---@param data string Data to write
---@param callback function|nil Callback(err)
function M.ipc.write(pipe, data, callback)
  if not pipe._handle then
    if callback then
      callback("Pipe not connected")
    end
    return
  end

  local success = vim.fn["code_awareness#socket#write"](data)

  if callback then
    vim.defer_fn(function()
      if success == 1 then
        callback(nil)
      else
        callback("Write failed")
      end
    end, 0)
  end
end

--- Start reading from pipe
---@param pipe table Pipe object
---@param callback function Callback(err, chunk)
function M.ipc.read_start(pipe, callback)
  if not pipe._handle then
    callback("Pipe not connected", nil)
    return
  end

  -- Set up callback in VimScript that will poll for data
  vim.fn["code_awareness#socket#read_start"](function(chunk)
    if chunk then
      callback(nil, chunk)
    else
      callback("Read error", nil)
    end
  end)
end

--- Stop reading from pipe
---@param pipe table Pipe object
function M.ipc.read_stop(pipe)
  if pipe and pipe._handle then
    vim.fn["code_awareness#socket#read_stop"]()
  end
end

--- Close pipe
---@param pipe table Pipe object
---@param callback function|nil Callback when closed
function M.ipc.close(pipe, callback)
  if not pipe or not pipe._handle then
    if callback then
      callback()
    end
    return
  end

  M.ipc.read_stop(pipe)
  vim.fn["code_awareness#socket#close"]()
  pipe._handle = nil

  if callback then
    vim.defer_fn(callback, 0)
  end
end

--- Check if socket/file exists
---@param path string File path
---@return boolean
function M.ipc.fs_stat(path)
  return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

-- Highlighting operations (using text properties in Vim 8.1+)
M.highlight = {}

local prop_type_name = "code_awareness_highlight"
local prop_type_created = false

--- Create namespace for highlights (returns a unique identifier for Vim)
---@param name string Namespace name
---@return number Namespace ID (we use a constant since Vim doesn't have namespaces)
function M.highlight.create_namespace(name)
  -- Vim doesn't have namespaces like Neovim, so we use a constant
  -- and manage highlights via text property types
  return 1
end

--- Set highlight group
---@param ns_id number Namespace ID (unused in Vim)
---@param name string Highlight group name
---@param opts table Highlight options
function M.highlight.set_hl(ns_id, name, opts)
  -- Build highlight command
  local cmd = "highlight " .. name

  if opts.bg then
    cmd = cmd .. " guibg=" .. opts.bg
  end
  if opts.fg then
    cmd = cmd .. " guifg=" .. opts.fg
  end
  if opts.blend then
    -- Vim doesn't support blend directly, ignore
  end
  if opts.default then
    cmd = "highlight default " .. string.gsub(cmd, "highlight ", "")
  end

  vim.cmd(cmd)

  -- Also create/update text property type if needed
  if not prop_type_created and vim.fn.exists("*prop_type_add") == 1 then
    -- Remove if exists
    pcall(vim.fn.prop_type_delete, prop_type_name)

    -- Create new
    vim.fn.prop_type_add(prop_type_name, {
      highlight = name,
      priority = 100,
    })

    prop_type_created = true
  end
end

--- Apply highlight to buffer line
---@param bufnr number Buffer number
---@param ns_id number Namespace ID (unused in Vim)
---@param line number Line number (0-based)
---@param opts table Highlight options
---@return boolean success
function M.highlight.set_extmark(bufnr, ns_id, line, opts)
  -- Convert 0-based line to 1-based for Vim
  local vim_line = line + 1

  -- Check if text properties are available
  if vim.fn.exists("*prop_add") ~= 1 then
    -- Fall back to signs
    return M.highlight._set_sign(bufnr, vim_line, opts.line_hl_group or opts.hl_group)
  end

  -- Ensure property type exists
  if not prop_type_created then
    M.highlight.set_hl(ns_id, "CodeAwarenessHighlight", {
      bg = "#03445f",
      default = true,
    })
  end

  -- Add text property to entire line
  local ok, err = pcall(function()
    vim.fn.prop_add(vim_line, 1, {
      type = prop_type_name,
      bufnr = bufnr,
      end_lnum = vim_line,
    })
  end)

  return ok
end

--- Fallback: use signs for highlighting
---@param bufnr number Buffer number
---@param line number Line number (1-based)
---@param hl_group string Highlight group
---@return boolean success
function M.highlight._set_sign(bufnr, line, hl_group)
  -- Define sign if not exists
  if vim.fn.sign_getdefined("CodeAwarenessHighlight")[1] == nil then
    vim.fn.sign_define("CodeAwarenessHighlight", {
      linehl = hl_group or "CodeAwarenessHighlight",
    })
  end

  -- Place sign
  local sign_id = 9000 + line -- Use unique ID based on line
  vim.fn.sign_place(sign_id, "code_awareness", "CodeAwarenessHighlight", bufnr, {
    lnum = line,
  })

  return true
end

--- Clear highlights from buffer
---@param bufnr number Buffer number
---@param ns_id number Namespace ID (unused in Vim)
function M.highlight.clear_namespace(bufnr, ns_id)
  if vim.fn.exists("*prop_remove") == 1 then
    -- Clear text properties
    pcall(vim.fn.prop_remove, {
      type = prop_type_name,
      bufnr = bufnr,
      all = 1,
    }, 1, vim.fn.line("$", bufnr))
  end

  -- Also clear signs
  vim.fn.sign_unplace("code_awareness", { buffer = bufnr })
end

--- Get extmarks from buffer (not fully supported in Vim)
---@param bufnr number Buffer number
---@param ns_id number Namespace ID
---@return table Empty table (Vim doesn't support querying text properties easily)
function M.highlight.get_extmarks(bufnr, ns_id)
  -- Vim doesn't have an easy way to query text properties
  -- Return empty table
  return {}
end

-- Buffer operations
M.buffer = {}

--- Check if buffer is valid
---@param bufnr number Buffer number
---@return boolean
function M.buffer.is_valid(bufnr)
  return vim.fn.bufexists(bufnr) == 1 and vim.fn.bufloaded(bufnr) == 1
end

--- Get buffer name (file path)
---@param bufnr number Buffer number
---@return string
function M.buffer.get_name(bufnr)
  return vim.fn.bufname(bufnr)
end

--- Get buffer lines
---@param bufnr number Buffer number
---@param start number Start line (0-based)
---@param end_ number End line (0-based, -1 for end of buffer)
---@return table Lines
function M.buffer.get_lines(bufnr, start, end_)
  -- Convert 0-based to 1-based
  local start_line = start + 1
  local end_line = end_

  if end_ == -1 then
    end_line = vim.fn.line("$", bufnr)
  else
    end_line = end_
  end

  return vim.fn.getbufline(bufnr, start_line, end_line)
end

--- Get buffer option
---@param bufnr number Buffer number
---@param name string Option name
---@return any
function M.buffer.get_option(bufnr, name)
  return vim.fn.getbufvar(bufnr, "&" .. name)
end

--- Get buffer line count
---@param bufnr number Buffer number
---@return number
function M.buffer.line_count(bufnr)
  return vim.fn.line("$", bufnr)
end

--- Get list of all buffers
---@return table Buffer numbers
function M.buffer.list()
  local buffers = {}
  for i = 1, vim.fn.bufnr("$") do
    if vim.fn.bufexists(i) == 1 then
      table.insert(buffers, i)
    end
  end
  return buffers
end

-- Window operations
M.window = {}

--- Get current buffer
---@return number Buffer number
function M.window.get_current_buf()
  return vim.fn.bufnr("%")
end

--- Get cursor position
---@return table {line, column}
function M.window.get_cursor()
  local pos = vim.fn.getcurpos()
  return { pos[2], pos[3] - 1 } -- Return 1-based line, 0-based column to match Neovim
end

-- Autocmd operations
M.autocmd = {}

local augroups = {}
local next_group_id = 1

--- Create autocommand group
---@param name string Group name
---@return number Group ID
function M.autocmd.create_group(name)
  vim.cmd("augroup " .. name)
  vim.cmd("autocmd!")
  vim.cmd("augroup END")

  local group_id = next_group_id
  next_group_id = next_group_id + 1

  augroups[group_id] = name

  return group_id
end

--- Delete autocommand group
---@param group_id number Group ID
function M.autocmd.delete_group(group_id)
  local name = augroups[group_id]
  if name then
    vim.cmd("augroup " .. name)
    vim.cmd("autocmd!")
    vim.cmd("augroup END")
    augroups[group_id] = nil
  end
end

--- Create autocommand
---@param opts table Autocmd options
function M.autocmd.create(opts)
  local group_name = augroups[opts.group]
  if not group_name then
    return
  end

  local events = opts.event
  if type(events) == "string" then
    events = { events }
  end

  local pattern = opts.pattern or "*"

  for _, event in ipairs(events) do
    vim.cmd(
      string.format(
        "autocmd %s %s %s lua require('code-awareness')._autocmd_callback(%d, '%s')",
        group_name,
        event,
        pattern,
        opts.group,
        event
      )
    )
  end

  -- Store callback
  if not M._callbacks then
    M._callbacks = {}
  end
  M._callbacks[opts.group] = M._callbacks[opts.group] or {}
  M._callbacks[opts.group][opts.event[1]] = opts.callback
end

--- Internal callback dispatcher
---@param group_id number Group ID
---@param event string Event name
function M._autocmd_dispatch(group_id, event)
  if M._callbacks and M._callbacks[group_id] and M._callbacks[group_id][event] then
    M._callbacks[group_id][event]()
  end
end

-- Utility operations
M.util = {}

--- Schedule function to run on main loop
---@param fn function Function to run
function M.util.schedule(fn)
  -- Vim doesn't have schedule, run immediately
  vim.defer_fn(fn, 0)
end

--- Check if in fast event (Vim doesn't have this concept)
---@return boolean
function M.util.in_fast_event()
  return false
end

--- Defer function execution
---@param fn function Function to run
---@param timeout number Timeout in ms
---@return number Timer ID
function M.util.defer_fn(fn, timeout)
  return vim.fn.timer_start(timeout, function()
    fn()
  end)
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
  return vim.fn.json_encode(data)
end

--- JSON decode
---@param str string JSON string
---@return table Decoded data
function M.util.json_decode(str)
  return vim.fn.json_decode(str)
end

--- Notify user
---@param msg string Message
---@param level number Log level (ignored in Vim, just use echomsg)
function M.util.notify(msg, level)
  if level >= 3 then -- ERROR or WARN
    vim.cmd("echohl WarningMsg")
    vim.cmd('echom "' .. vim.fn.escape(msg, '"\\') .. '"')
    vim.cmd("echohl None")
  else
    vim.cmd('echom "' .. vim.fn.escape(msg, '"\\') .. '"')
  end
end

--- Get log levels (Vim doesn't have vim.log.levels)
---@return table Log levels
function M.util.log_levels()
  return {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
  }
end

return M
