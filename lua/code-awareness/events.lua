-- Event system for Code Awareness
local M = {}

-- Event handlers registry
-- Format: { "domain:action" = handler_function }
local handlers = {}

-- Response handlers registry (for request/response correlation)
-- Format: { "request_id" = handler_function }
local response_handlers = {}

-- Request ID counter
local next_request_id = 1

--- Register an event handler
---@param domain string Event domain (or '*' for wildcard)
---@param action string Event action
---@param handler function Handler function(data, message)
function M.register(domain, action, handler)
  local key = domain .. ":" .. action
  handlers[key] = handler

  local util = require("code-awareness.util")
  util.log.debug("Registered handler: " .. key)
end

--- Dispatch an incoming message to registered handlers
---@param message table Decoded message
function M.dispatch(message)
  local util = require("code-awareness.util")

  if not message or not message.domain or not message.action then
    util.log.error("Invalid message for dispatch")
    return
  end

  util.log.debug(string.format("Dispatching: %s %s:%s", message.flow, message.domain, message.action))

  if message.flow == "res" or message.flow == "err" then
    -- This is a response to a request
    M.dispatch_response(message)
  elseif message.flow == "req" then
    -- This is an incoming request from the app
    M.dispatch_request(message)
  else
    util.log.warn("Unknown message flow: " .. tostring(message.flow))
  end
end

--- Dispatch a response message
---@param message table Response message
function M.dispatch_response(message)
  local util = require("code-awareness.util")

  -- Look for response handler
  local key = message.domain .. ":" .. message.action

  local handler = response_handlers[key]

  if handler then
    -- Remove one-time handler
    response_handlers[key] = nil

    -- Call handler
    local ok, err = pcall(handler, message.data, message)
    if not ok then
      util.log.error("Response handler error: " .. tostring(err))
    end
  else
    util.log.debug("No response handler for: " .. key)
  end
end

--- Dispatch an incoming request message
---@param message table Request message
function M.dispatch_request(message)
  local util = require("code-awareness.util")

  -- Look for registered handler
  local key = message.domain .. ":" .. message.action

  local handler = handlers[key]

  if not handler then
    -- Try wildcard domain
    key = "*:" .. message.action
    handler = handlers[key]
  end

  if handler then
    -- Call handler
    local ok, err = pcall(handler, message.data, message)
    if not ok then
      util.log.error("Request handler error: " .. tostring(err))
    end
  else
    util.log.debug("No handler for: " .. message.domain .. ":" .. message.action)
  end
end

--- Register a one-time response handler for a request
---@param domain string Request domain
---@param action string Request action
---@param handler function Handler function(data, message)
---@return number request_id
function M.register_response_handler(domain, action, handler)
  local key = domain .. ":" .. action
  response_handlers[key] = handler

  local id = next_request_id
  next_request_id = next_request_id + 1

  return id
end

return M
