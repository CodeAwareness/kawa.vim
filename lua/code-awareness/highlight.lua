-- Highlight management for Code Awareness
local M = {}

-- Namespace for extmarks
local ns_id = nil

--- Initialize highlighting system
function M.init()
  if ns_id then
    return
  end

  ns_id = vim.api.nvim_create_namespace('code_awareness')

  -- Define highlight groups
  M.init_colors()
end

--- Initialize highlight colors based on theme
function M.init_colors()
  local config = require('code-awareness.config')
  local colors = config.get('highlight.colors')

  local bg = vim.o.background
  local color = bg == 'light' and colors.light or colors.dark

  vim.api.nvim_set_hl(0, 'CodeAwarenessHighlight', {
    bg = color,
    default = true,
  })
end

--- Apply highlights to a buffer
---@param bufnr number Buffer number
---@param line_numbers table Array of line numbers (1-based)
function M.apply_highlights(bufnr, line_numbers)
  if not ns_id then
    M.init()
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Clear existing highlights
  M.clear_highlights(bufnr)

  -- Apply new highlights
  for _, line_nr in ipairs(line_numbers) do
    if line_nr > 0 then
      local ok = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_nr - 1, 0, {
        hl_group = 'CodeAwarenessHighlight',
        hl_eol = true,
        hl_mode = 'combine',
        priority = 100,
        strict = false,
      })

      if not ok then
        -- Line number out of range, skip
      end
    end
  end
end

--- Clear highlights from a buffer
---@param bufnr number Buffer number
function M.clear_highlights(bufnr)
  if not ns_id or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

--- Clear all highlights from all buffers
function M.clear_all()
  if not ns_id then
    return
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    end
  end
end

--- Refresh colors (e.g., after theme change)
function M.refresh_colors()
  M.init_colors()

  -- Reapply highlights to all buffers
  local state = require('code-awareness.state')
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local highlights = state.get_highlights(bufnr)
    if #highlights > 0 then
      M.apply_highlights(bufnr, highlights)
    end
  end
end

return M
