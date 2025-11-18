-- Peer selection handling for Code Awareness
local M = {}

local util = require('code-awareness.util')
local initialized = false
local diff_win = nil
local diff_buf = nil

local function close_diff_window()
  if diff_win and vim.api.nvim_win_is_valid(diff_win) then
    pcall(vim.api.nvim_win_close, diff_win, true)
  end

  diff_win = nil
  diff_buf = nil

  pcall(vim.cmd, 'diffoff!')
end

local function ensure_main_thread(fn)
  if vim.in_fast_event() then
    vim.schedule(fn)
  else
    fn()
  end
end

local function open_diff_view(user_file, peer_file)
  ensure_main_thread(function()
    close_diff_window()

    local function edit_file(path)
      local escaped = vim.fn.fnameescape(path)
      local ok, err = pcall(vim.cmd, 'edit ' .. escaped)
      if not ok then
        util.log.error('Failed to open file for diff: ' .. tostring(err))
        return false
      end
      return true
    end

    local current_path = util.normalize_path(vim.api.nvim_buf_get_name(0))
    if current_path == '' or current_path ~= user_file then
      if not edit_file(user_file) then
        return
      end
    end

    local peer_ok, peer_err = pcall(vim.cmd, 'vert diffsplit ' .. vim.fn.fnameescape(peer_file))
    if not peer_ok then
      util.log.error('Failed to open peer diff window: ' .. tostring(peer_err))
      return
    end

    diff_win = vim.api.nvim_get_current_win()
    diff_buf = vim.api.nvim_get_current_buf()

    pcall(vim.api.nvim_buf_set_option, diff_buf, 'modifiable', false)
    pcall(vim.api.nvim_buf_set_option, diff_buf, 'readonly', true)
  end)
end

function M.handle_peer_diff_response(data)
  local state = require('code-awareness.state')
  local project = state.get_active_project()

  if not data then
    util.log.warn('diff-peer response missing data')
    return
  end

  local peer_file = data.peerFile or data.peer_file
  local user_file = data.userFile or data.fpath

  if not user_file and project and project.root and project.activePath then
    user_file = util.normalize_path(project.root .. '/' .. project.activePath)
  end

  if peer_file then
    peer_file = util.normalize_path(peer_file)
  end

  if not (peer_file and user_file) then
    util.log.warn('diff-peer response missing file paths')
    return
  end

  open_diff_view(user_file, peer_file)
end

function M.handle_peer_select(peer_data)
  local state = require('code-awareness.state')
  local ipc = require('code-awareness.ipc')

  state.set_selected_peer(peer_data)

  local project = state.get_active_project()
  if not project then
    util.log.warn('Peer selected but no active project data available')
    return
  end

  if not project.activePath then
    util.log.warn('Peer selected but active project has no activePath')
    return
  end

  -- Get current file content (doc) from active buffer
  -- Use schedule to ensure we're not in fast event context
  ensure_main_thread(function()
    local doc = ''
    local active_bufnr = state.get_active_buffer()
    if active_bufnr then
      -- Check validity and get content on main thread
      local ok, valid = pcall(vim.api.nvim_buf_is_valid, active_bufnr)
      if ok and valid then
        local lines = vim.api.nvim_buf_get_lines(active_bufnr, 0, -1, false)
        doc = table.concat(lines, '\n')
      end
    end

    -- Validate required fields
    if not peer_data or not peer_data._id then
      util.log.error('Peer data missing _id field: ' .. vim.inspect(peer_data))
      return
    end

    if not project.origin then
      util.log.error('Project missing origin field. Project data: ' .. vim.inspect(project))
      return
    end

    -- Get client GUID for payload
    local ipc_module = require('code-awareness.ipc')
    local client_guid = ipc_module.get_client_guid()

    -- Build payload matching Emacs/Gardener expectations
    -- Must match TContribDiffInfo: { fpath, peer: { _id }, origin, caw, doc }
    local payload = {
      peer = peer_data,  -- Must have _id field
      fpath = project.activePath,  -- Relative path from project root
      origin = project.origin,  -- Required: git origin URL
      caw = client_guid,  -- Client GUID (required by controller)
      doc = doc,  -- File content
    }

    util.log.info('Requesting peer diff:')
    util.log.info('  fpath: ' .. payload.fpath)
    util.log.info('  origin: ' .. payload.origin)
    util.log.info('  peer._id: ' .. payload.peer._id)
    util.log.info('  doc length: ' .. #doc)

    ipc.send('code', 'diff-peer', payload, function(response_data, message)
      if message.flow == 'err' then
        util.log.error('diff-peer error: ' .. vim.inspect(response_data))
        return
      end
      M.handle_peer_diff_response(response_data)
    end)
  end)
end

function M.handle_peer_unselect()
  local state = require('code-awareness.state')
  state.set_selected_peer(nil)
  ensure_main_thread(close_diff_window)
end

function M.setup()
  if initialized then
    return
  end

  local events = require('code-awareness.events')

  events.register('code', 'peer:select', function(data)
    ensure_main_thread(function()
      M.handle_peer_select(data)
    end)
  end)

  events.register('code', 'peer:unselect', function()
    M.handle_peer_unselect()
  end)

  initialized = true
end

return M

