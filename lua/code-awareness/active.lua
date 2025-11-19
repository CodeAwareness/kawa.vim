-- Active path tracking for Code Awareness
local M = {}

-- Debounce timer
local update_timer = nil

--- Send active path update to Kawa Code
---@param bufnr number|nil Buffer number (default: current buffer)
function M.send_update(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local util = require("code-awareness.util")
  local state = require("code-awareness.state")
  local ipc = require("code-awareness.ipc")

  -- Check if this is a valid buffer
  if not util.is_normal_buffer(bufnr) then
    -- util.log.debug("Skipping update for non-file buffer")
    return
  end

  -- Get file information
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if not filepath or filepath == "" then
    return
  end

  -- Normalize path
  filepath = util.normalize_path(filepath)

  -- Get project root
  local project_root = util.get_git_root(filepath)
  if not project_root then
    util.log.debug("File not in Git repository, skipping: " .. filepath)
    return
  end

  project_root = util.normalize_path(project_root)

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  -- Get cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_data = {
    line = cursor[1],
    column = cursor[2],
  }

  -- Update state
  state.set_active_buffer(bufnr, filepath, project_root)

  -- Send active-path message (match VSCode/Emacs payload)
  local data = {
    fpath = filepath,
    doc = content,
    project = project_root,
    cursor = cursor_data,
  }

  util.log.debug("Sending active-path for: " .. filepath)

  ipc.send("code", "active-path", data, function(response_data, message)
    if message.flow == "err" then
      util.log.error("active-path error: " .. vim.inspect(response_data))
      return
    end

    util.log.debug(string.format("Received active-path response: %s:%s", message.domain, message.action))

    -- Persist project metadata for future requests (peer diffs, etc.)
    if response_data then
      state.set_active_project(response_data)
    end

    -- Extract highlight data
    local hl_data = response_data and response_data.hl
    if not hl_data then
      util.log.debug("No highlight data (hl field) in response")
      return
    end

    -- Convert 0-based line numbers to 1-based
    local line_numbers = {}
    if type(hl_data) == "table" then
      for _, line_nr in ipairs(hl_data) do
        if type(line_nr) == "number" then
          table.insert(line_numbers, line_nr + 1)
        else
          -- util.log.debug("Skipping non-numeric hl element: " .. tostring(line_nr) .. " (type: " .. type(line_nr) .. ")")
        end
      end
    else
      -- util.log.warn("hl_data is not a table: " .. type(hl_data))
      return
    end

    -- Update state
    state.set_highlights(bufnr, line_numbers)

    -- Apply highlights on main loop to avoid fast-event errors
    local highlight = require("code-awareness.highlight")
    highlight.apply_highlights(bufnr, line_numbers)
  end)
end

--- Send active path update with debouncing
---@param bufnr number|nil Buffer number
function M.send_update_debounced(bufnr)
  local config = require("code-awareness.config")
  local delay = config.get("update_delay") or 500

  -- Cancel existing timer
  if update_timer then
    vim.fn.timer_stop(update_timer)
    update_timer = nil
  end

  -- Schedule update
  update_timer = vim.defer_fn(function()
    M.send_update(bufnr)
    update_timer = nil
  end, delay)
end

return M
