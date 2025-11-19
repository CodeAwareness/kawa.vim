-- User commands for Code Awareness
local M = {}

--- Execute a Code Awareness command
---@param command string Command name
---@vararg any Command arguments
function M.execute(command, ...)
  local args = { ... }

  if command == "status" then
    M.status()
  elseif command == "toggle" then
    M.toggle()
  elseif command == "refresh" then
    M.refresh()
  elseif command == "clear" then
    M.clear()
  elseif command == "reconnect" then
    M.reconnect()
  elseif command == "debug" or command == "logs" then
    M.show_logs()
  elseif command == "test-highlights" then
    M.test_highlights()
  else
    vim.notify("[code-awareness] Unknown command: " .. command, vim.log.levels.ERROR)
  end
end

--- Show status
function M.status()
  local ca = require("code-awareness")
  local ipc = require("code-awareness.ipc")

  local lines = {
    "Code Awareness Status",
    "=====================",
    "",
    "Enabled: " .. tostring(ca.is_enabled()),
    "Connected: " .. tostring(ipc.is_connected()),
  }

  -- Show in floating window or echo
  for _, line in ipairs(lines) do
    print(line)
  end
end

--- Toggle Code Awareness
function M.toggle()
  local ca = require("code-awareness")
  ca.toggle()

  if ca.is_enabled() then
    vim.notify("[code-awareness] Enabled", vim.log.levels.INFO)
  else
    vim.notify("[code-awareness] Disabled", vim.log.levels.INFO)
  end
end

--- Refresh current buffer
function M.refresh()
  local ca = require("code-awareness")

  if not ca.is_enabled() then
    vim.notify("[code-awareness] Not enabled", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local active = require("code-awareness.active")

  active.send_update(bufnr)
  vim.notify("[code-awareness] Refreshing...", vim.log.levels.INFO)
end

--- Clear all highlights
function M.clear()
  local highlight = require("code-awareness.highlight")
  highlight.clear_all()
  vim.notify("[code-awareness] Cleared all highlights", vim.log.levels.INFO)
end

--- Reconnect to Kawa Code
function M.reconnect()
  local ipc = require("code-awareness.ipc")
  ipc.disconnect()

  vim.defer_fn(function()
    ipc.connect(function(err)
      if err then
        vim.notify("[code-awareness] Reconnect failed: " .. err, vim.log.levels.ERROR)
      else
        vim.notify("[code-awareness] Reconnected", vim.log.levels.INFO)
      end
    end)
  end, 100)
end

--- Show debug logs
function M.show_logs()
  local util = require("code-awareness.util")
  local logs = util.log.get_logs()

  if #logs == 0 then
    print("No logs available")
    return
  end

  print("Code Awareness Logs")
  print("===================")
  for _, log in ipairs(logs) do
    print(log)
  end
end

--- Test highlights by applying to lines 1, 5, 10, 15
function M.test_highlights()
  local bufnr = vim.api.nvim_get_current_buf()
  local highlight = require("code-awareness.highlight")
  local util = require("code-awareness.util")

  -- Initialize highlight system first
  highlight.init()

  -- Use a very visible test color (bright red) for testing
  vim.api.nvim_set_hl(0, "CodeAwarenessHighlight", {
    bg = "#ff0000", -- Bright red for testing
    default = true,
  })

  -- Verify the color was set
  local test_hl = vim.api.nvim_get_hl(0, { name = "CodeAwarenessHighlight" })
  util.log.info("Test highlight group set to: " .. vim.inspect(test_hl))

  -- Test with lines 1, 5, 10, 15
  local test_lines = { 1, 5, 10, 15 }

  util.log.info("Testing highlights with bright red color on lines: " .. table.concat(test_lines, ", "))
  -- Skip color init to preserve our test color
  highlight.apply_highlights(bufnr, test_lines, true)

  -- Verify extmarks were created and inspect them
  vim.defer_fn(function()
    local ns_id = highlight.get_namespace_id()
    if ns_id then
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
      util.log.info(string.format("Created %d extmarks. Check if highlights are visible.", #extmarks))

      -- Check highlight group
      local hl_def = vim.api.nvim_get_hl(0, { name = "CodeAwarenessHighlight" })
      util.log.info("Highlight group definition: " .. vim.inspect(hl_def))

      -- Inspect first extmark details
      if #extmarks > 0 then
        local first_extmark = extmarks[1]
        util.log.info("First extmark details: " .. vim.inspect(first_extmark))
      end

      -- Show detailed info
      local msg =
        string.format("[code-awareness] Test highlights: %d extmarks, highlight: %s", #extmarks, vim.inspect(hl_def))
      vim.notify(msg, vim.log.levels.INFO)

      if #extmarks == 0 then
        vim.notify("[code-awareness] WARNING: No extmarks found! Highlights may not be applied.", vim.log.levels.WARN)
      else
        -- Try to verify the highlight is actually set on the extmark
        vim.notify(
          "[code-awareness] Extmarks created. If highlights are not visible, check highlight group and color.",
          vim.log.levels.INFO
        )
      end
    else
      vim.notify("[code-awareness] Warning: namespace not found", vim.log.levels.WARN)
    end
  end, 100)
end

return M
