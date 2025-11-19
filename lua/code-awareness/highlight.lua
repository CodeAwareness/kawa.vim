-- Highlight management for Code Awareness
local M = {}

-- Namespace for extmarks
local ns_id = nil

--- Initialize highlighting system
function M.init()
  if ns_id then
    return
  end

  ns_id = vim.api.nvim_create_namespace("code_awareness")

  -- Define highlight groups
  M.init_colors()
end

--- Initialize highlight colors based on theme
function M.init_colors()
  local config = require("code-awareness.config")
  local colors = config.get("highlight.colors")

  if not colors then
    -- Fallback colors if config not set
    colors = {
      light = "#00b1a420",
      dark = "#03445f",
    }
  end

  local bg = vim.o.background
  local color = bg == "light" and colors.light or colors.dark

  if not color then
    -- Fallback if color not found
    color = bg == "light" and "#00b1a420" or "#03445f"
  end

  -- Neovim may not support 8-digit hex with alpha directly
  -- Convert #RRGGBBAA to #RRGGBB and use blend for transparency
  local hex_color = color
  local use_blend = false
  local blend_value = nil

  if #color == 9 and color:sub(1, 1) == "#" then
    -- Extract RGB and alpha
    local rgb = color:sub(1, 7)
    local alpha_hex = color:sub(8, 9)
    local alpha = tonumber(alpha_hex, 16) / 255.0
    hex_color = rgb
    use_blend = true
    blend_value = math.floor(alpha * 100)
  end

  -- Set highlight group
  local hl_opts = {
    bg = hex_color,
    default = true,
  }

  -- Only add blend if we have alpha (and it's not too transparent)
  -- Very low alpha might make highlights invisible
  if use_blend and blend_value and blend_value > 10 then
    hl_opts.blend = blend_value
  end

  vim.api.nvim_set_hl(0, "CodeAwarenessHighlight", hl_opts)
end

--- Apply highlights to a buffer
---@param bufnr number Buffer number
---@param line_numbers table Array of line numbers (1-based)
---@param skip_color_init boolean|nil If true, skip color initialization (for testing)
function M.apply_highlights(bufnr, line_numbers, skip_color_init)
  local util = require("code-awareness.util")

  local function apply()
    if not ns_id then
      M.init()
    end

    -- Ensure highlight group is defined (unless skipped for testing)
    if not skip_color_init then
      M.init_colors()
    end

    if not vim.api.nvim_buf_is_valid(bufnr) then
      util.log.debug("Cannot apply highlights: invalid buffer " .. tostring(bufnr))
      return
    end

    if not line_numbers or #line_numbers == 0 then
      util.log.debug("No highlights to apply for buffer " .. tostring(bufnr))
      -- Clear existing highlights if no new ones
      M.clear_highlights(bufnr)
      return
    end

    util.log.debug(string.format("Applying %d highlights to buffer %d", #line_numbers, bufnr))

    -- Clear existing highlights
    M.clear_highlights(bufnr)

    -- Get buffer line count for validation
    local line_count = vim.api.nvim_buf_line_count(bufnr)

    -- Apply new highlights
    local applied_count = 0
    for _, line_nr in ipairs(line_numbers) do
      if type(line_nr) == "number" and line_nr > 0 and line_nr <= line_count then
        local extmark_line = line_nr - 1 -- Convert to 0-based for extmark API

        -- Use line_hl_group for full-width highlighting (like cursorline/vimdiff)
        local opts = {
          line_hl_group = "CodeAwarenessHighlight",
          priority = 100,
          strict = false,
        }

        util.log.debug(string.format("Setting extmark on line %d with opts: %s", line_nr, vim.inspect(opts)))

        local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, extmark_line, 0, opts)

        if ok then
          applied_count = applied_count + 1
          util.log.debug(string.format("Successfully set extmark on line %d (0-based: %d)", line_nr, extmark_line))
        else
          util.log.debug(string.format("Failed to set extmark on line %d: %s", line_nr, tostring(err)))
        end
      else
        util.log.debug(
          string.format(
            "Skipping invalid line number: %s (type: %s, buffer lines: %d)",
            tostring(line_nr),
            type(line_nr),
            line_count
          )
        )
      end
    end

    util.log.info(string.format("Applied %d/%d highlights to buffer %d", applied_count, #line_numbers, bufnr))

    -- Verify extmarks were created and log details
    if applied_count > 0 then
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
      util.log.info(string.format("Verified: %d extmarks exist in buffer %d", #extmarks, bufnr))

      if #extmarks ~= applied_count then
        util.log.warn(string.format("Mismatch: Created %d extmarks but %d were requested", #extmarks, applied_count))
      end

      -- Log first few extmark details for debugging
      for i = 1, math.min(3, #extmarks) do
        local extmark = extmarks[i]
        util.log.debug(
          string.format("Extmark %d: line=%d, col=%d, details=%s", i, extmark[2], extmark[3], vim.inspect(extmark[4]))
        )
      end
    end
  end

  if vim.in_fast_event() then
    vim.schedule(apply)
  else
    apply()
  end
end

--- Clear highlights from a buffer
---@param bufnr number Buffer number
function M.clear_highlights(bufnr)
  local function clear()
    if not ns_id or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end

  if vim.in_fast_event() then
    vim.schedule(clear)
  else
    clear()
  end
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
  local state = require("code-awareness.state")
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local highlights = state.get_highlights(bufnr)
    if #highlights > 0 then
      M.apply_highlights(bufnr, highlights)
    end
  end
end

--- Get namespace ID (for debugging)
---@return number|nil
function M.get_namespace_id()
  return ns_id
end

return M
