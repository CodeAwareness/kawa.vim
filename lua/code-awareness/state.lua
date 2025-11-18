-- State management for Code Awareness
local M = {}

-- Global state
local state = {
  active = {
    buffer = nil,
    file_path = nil,
    project_root = nil,
  },
  project = nil,
  highlights = {},
  peers = {},
  selected_peer = nil,
}

--- Set active buffer
---@param bufnr number Buffer number
---@param filepath string File path
---@param project_root string|nil Project root directory
function M.set_active_buffer(bufnr, filepath, project_root)
  state.active.buffer = bufnr
  state.active.file_path = filepath
  state.active.project_root = project_root
end

--- Get active buffer
---@return number|nil
function M.get_active_buffer()
  return state.active.buffer
end

--- Get active file path
---@return string|nil
function M.get_active_file_path()
  return state.active.file_path
end

--- Get active project root
---@return string|nil
function M.get_active_project_root()
  return state.active.project_root
end

--- Set active project metadata returned from server
---@param project table|nil
function M.set_active_project(project)
  state.project = project
end

--- Get active project metadata
---@return table|nil
function M.get_active_project()
  return state.project
end

--- Set highlights for a buffer
---@param bufnr number Buffer number
---@param line_numbers table Array of line numbers to highlight
function M.set_highlights(bufnr, line_numbers)
  state.highlights[bufnr] = line_numbers or {}
end

--- Get highlights for a buffer
---@param bufnr number Buffer number
---@return table Array of line numbers
function M.get_highlights(bufnr)
  return state.highlights[bufnr] or {}
end

--- Set peers data
---@param peers_data table Peers information
function M.set_peers(peers_data)
  state.peers = peers_data or {}
end

--- Get peers data
---@return table
function M.get_peers()
  return state.peers
end

--- Set selected peer
---@param peer table|nil
function M.set_selected_peer(peer)
  state.selected_peer = peer
end

--- Get selected peer
---@return table|nil
function M.get_selected_peer()
  return state.selected_peer
end

--- Clear buffer state
---@param bufnr number Buffer number
function M.clear_buffer(bufnr)
  state.highlights[bufnr] = nil
end

--- Get all state
---@return table
function M.get_all()
  return state
end

return M
