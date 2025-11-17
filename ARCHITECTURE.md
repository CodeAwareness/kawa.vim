# Code Awareness for Vim/Neovim - Architecture Overview

## 1. Introduction

### Purpose
Code Awareness for Vim/Neovim is a real-time collaboration extension that provides early warning of merge conflicts and instant code navigation for team members' changes. It highlights code intersections between your working copy and teammates' work before commits or pushes occur.

### Goals
- **Real-time awareness**: Highlight lines being worked on by you or your team
- **Non-blocking**: All IPC and highlighting operations must be asynchronous
- **Low overhead**: Minimal impact on editor performance
- **Cross-platform**: Support Linux, macOS, and Windows
- **Dual support**: Work with both Vim 8.2+ and Neovim 0.5+

### Architecture Philosophy
The architecture mirrors kawa.emacs but adapts to Vim/Neovim's event model and async capabilities:
- **Neovim-first**: Primary implementation uses Lua with native async
- **Vim compatibility layer**: VimScript wrapper for Vim 8.2+ with job control
- **Modular design**: Clear separation between IPC, state, highlighting, and UI

## 2. System Architecture

### High-Level Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    Vim/Neovim (Code Awareness Plugin)           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Highlight   │  │     State    │  │   Commands   │          │
│  │   Manager    │  │   Manager    │  │   & UI       │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
│         └──────────────────┼──────────────────┘                  │
│                            │                                     │
│                   ┌────────▼────────┐                            │
│                   │  Event Handler  │                            │
│                   └────────┬────────┘                            │
│                            │                                     │
│                   ┌────────▼────────┐                            │
│                   │  IPC Transport  │                            │
│                   │   (Async I/O)   │                            │
│                   └────────┬────────┘                            │
└────────────────────────────┼────────────────────────────────────┘
                             │ Unix Socket / Named Pipe
                             │ (JSON over \f delimiter)
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                  Code Awareness Desktop App                     │
│                    (Kawa Code at ~/.kawa-code)                  │
│  - Manages peer connections and authentication                  │
│  - Provides file extraction and diff services                   │
│  - Coordinates real-time change notifications                   │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

#### IPC Transport Layer
**Location**: `lua/code-awareness/ipc/`

**Responsibilities**:
- Establish connection to Kawa Code desktop app via Unix socket/named pipe
- Send/receive JSON messages with `\f` delimiter
- Handle connection lifecycle (connect, reconnect, disconnect)
- Provide async read/write operations
- Implement exponential backoff for connection polling

**Key APIs**:
- `connect(callback)` - Establish IPC connection
- `send(message, response_handler)` - Send request with optional callback
- `disconnect()` - Clean shutdown
- `is_connected()` - Connection status

**Implementation**:
- **Neovim**: `vim.loop` (libuv) for async socket operations
- **Vim**: `job_start()` with channel I/O

#### Event Handler
**Location**: `lua/code-awareness/events.lua`

**Responsibilities**:
- Route incoming IPC messages to appropriate handlers
- Manage request/response correlation
- Dispatch app-initiated events (peer:select, branch:select)
- Provide event registration API for other components

**Key APIs**:
- `register_handler(domain, action, callback)` - Register event handler
- `handle_message(json_string)` - Process incoming message
- `emit(event_name, data)` - Internal event bus

#### State Manager
**Location**: `lua/code-awareness/state.lua`

**Responsibilities**:
- Track current active file and buffer
- Store highlight data per buffer
- Manage peer information and selection
- Maintain configuration state
- Provide getter/setter APIs for other components

**State Structure**:
```lua
{
  active = {
    buffer = <bufnr>,
    file_path = <string>,
    project_root = <string>
  },
  highlights = {
    [bufnr] = { line_numbers... }  -- Array of highlighted line numbers
  },
  peers = {
    [peer_id] = { name, avatar, ... }
  },
  config = {
    enabled = true,
    debug = false,
    highlight_intensity = 0.3,
    ...
  }
}
```

#### Highlight Manager
**Location**: `lua/code-awareness/highlight.lua`

**Responsibilities**:
- Apply/remove buffer highlights based on state changes
- Define highlight groups and colors
- Handle theme changes (light/dark mode)
- Support multiple highlight styles (full-width, line number gutter)

**Technology Choices**:
- **Neovim**: Extmarks with `hl_group` and `hl_eol` properties
- **Vim**: Text properties or signs (fallback)

**Key APIs**:
- `apply_highlights(bufnr, highlight_data)` - Apply highlights to buffer
- `clear_highlights(bufnr)` - Remove all highlights from buffer
- `reinit_colors()` - Refresh colors based on theme
- `set_intensity(value)` - Adjust highlight opacity

#### Commands & UI
**Location**: `lua/code-awareness/commands.lua`, `lua/code-awareness/ui.lua`

**Responsibilities**:
- Provide user-facing commands
- Show status messages and errors
- Integrate with statusline/lualine
- Manage diff views and peer selection

**User Commands**:
- `:CodeAwareness toggle` - Enable/disable plugin
- `:CodeAwareness status` - Show connection and auth status
- `:CodeAwareness refresh` - Force refresh current buffer
- `:CodeAwareness diff_peer [name]` - Open diff with peer
- `:CodeAwareness diff_branch [name]` - Open diff with branch
- `:CodeAwareness clear` - Clear all highlights

## 3. IPC Protocol

### Connection Flow

1. **Catalog Registration**
   - Connect to `~/.kawa-code/sockets/caw.catalog` (Unix) or `\\.\pipe\caw.catalog` (Windows)
   - Send `clientId` request to register as new client
   - Receive client GUID in response
   - Close catalog connection

2. **Client Socket Polling**
   - Wait for app to create `~/.kawa-code/sockets/caw.<GUID>`
   - Poll with exponential backoff: 0.5s, 1s, 2s, 4s, 8s (max 5 attempts)
   - Connect once socket exists

3. **Active Session**
   - Bidirectional communication on client socket
   - Send file updates, requests for diffs
   - Receive highlight data, peer events

4. **Graceful Shutdown**
   - Send disconnect notification (optional)
   - Close socket on VimLeavePre

### Message Format

All messages are JSON objects delimited by form-feed character (`\f` / `0x0C`):

```json
{
  "flow": "req|res|err",
  "domain": "code|auth|*",
  "action": "active-path|diff-peer|auth:info|...",
  "data": { },
  "caw": "<client-guid>"
}
```

### Key Message Types

| Direction | Flow | Domain | Action | Description |
|-----------|------|--------|--------|-------------|
| → App | req | * | clientId | Register new client |
| ← App | res | * | clientId | Client GUID assignment |
| → App | req | * | auth:info | Get authentication status |
| ← App | res | * | auth:info | Auth status and user info |
| → App | req | code | active-path | Send current file + content |
| ← App | res | code | active-path | Highlight data for file |
| → App | req | code | diff-peer | Request peer's file version |
| ← App | res | code | diff-peer | Path to peer's extracted file |
| → App | req | code | diff-branch | Request branch file version |
| ← App | res | code | diff-branch | Path to extracted branch file |
| ← App | req | code | peer:select | User selected peer in app |
| ← App | req | code | branch:select | User selected branch in app |
| ← App | req | code | context:add | Add selection to context |
| ← App | req | code | context:open | Open file from context |

### active-path Message Details

**Request** (sent on buffer enter, save, or manual refresh):
```json
{
  "flow": "req",
  "domain": "code",
  "action": "active-path",
  "data": {
    "path": "/absolute/path/to/file.js",
    "content": "file contents...",
    "project": "/absolute/path/to/project",
    "cursor": {
      "line": 42,
      "column": 10
    }
  },
  "caw": "12345678-abcd-..."
}
```

**Response** (highlight data):
```json
{
  "flow": "res",
  "domain": "code",
  "action": "active-path",
  "data": {
    "hl": [0, 5, 10, 15]  // 0-based line numbers to highlight
  }
}
```

## 4. Highlighting System

### Neovim Implementation (Extmarks)

Extmarks provide efficient, buffer-integrated highlights with virtual text support:

```lua
local ns_id = vim.api.nvim_create_namespace('code_awareness')

-- Apply highlight to line
vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_nr - 1, 0, {
  hl_group = 'CodeAwarenessHighlight',
  hl_eol = true,  -- Extend to end of line
  hl_mode = 'combine',
  priority = 100,
  strict = false
})

-- Clear all highlights
vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
```

**Advantages**:
- Native to Neovim, very efficient
- Automatically handles line insertions/deletions
- Supports virtual text for future enhancements
- `hl_eol` extends highlight to full line width

### Vim Implementation (Text Properties)

Fallback for Vim 8.2+:

```vim
" Define property type
call prop_type_add('code_awareness_highlight', {'highlight': 'CodeAwarenessHighlight'})

" Apply to line
call prop_add(line_nr, 1, {
  \ 'type': 'code_awareness_highlight',
  \ 'length': 0,
  \ 'end_lnum': line_nr + 1
  \ })

" Clear all properties
call prop_remove({'type': 'code_awareness_highlight', 'all': 1}, 1, line('$'))
```

**Fallback**: If text properties unavailable, use signs in gutter (less intrusive but visible).

### Highlight Groups

```vim
" Light theme
hi CodeAwarenessHighlight guibg=#00b1a420 ctermbg=23

" Dark theme
hi CodeAwarenessHighlight guibg=#03445f ctermbg=24
```

Theme detection:
```lua
local bg = vim.o.background  -- 'light' or 'dark'
```

## 5. Autocommand Integration

### Buffer Tracking

```lua
-- Update active file on buffer switch
vim.api.nvim_create_autocmd('BufEnter', {
  group = 'CodeAwareness',
  pattern = '*',
  callback = function()
    require('code-awareness').on_buffer_enter()
  end
})

-- Send file content on save
vim.api.nvim_create_autocmd('BufWritePost', {
  group = 'CodeAwareness',
  pattern = '*',
  callback = function()
    require('code-awareness').on_buffer_save()
  end
})

-- Cleanup on exit
vim.api.nvim_create_autocmd('VimLeavePre', {
  group = 'CodeAwareness',
  callback = function()
    require('code-awareness').shutdown()
  end
})
```

### Debouncing

Avoid flooding the app with rapid buffer switches:

```lua
local timer = vim.loop.new_timer()
local debounce_ms = 500

function debounced_update()
  timer:stop()
  timer:start(debounce_ms, 0, vim.schedule_wrap(function()
    send_active_path_update()
  end))
end
```

## 6. Configuration System

### Default Configuration

```lua
{
  enabled = true,
  debug = false,

  -- IPC settings
  catalog_name = 'catalog',
  socket_dir = vim.fn.expand('~/.kawa-code/sockets'),
  connection_timeout = 5000,  -- ms
  max_poll_attempts = 5,

  -- Highlight settings
  highlight = {
    enabled = true,
    style = 'extmark',  -- 'extmark', 'textprop', 'sign'
    intensity = 0.3,
    full_width = true,

    colors = {
      light = '#00b1a420',
      dark = '#03445f'
    }
  },

  -- Update behavior
  update_delay = 500,  -- ms debounce
  send_on_save = true,
  send_on_buffer_enter = true,

  -- Diff settings
  diff_tool = 'diffthis',  -- 'diffthis', 'diffview'
  diff_layout = 'vertical',  -- 'vertical', 'horizontal'

  -- UI settings
  statusline = {
    enabled = true,
    show_peer_count = true
  }
}
```

### User Configuration

```lua
-- init.lua / init.vim
require('code-awareness').setup({
  highlight = {
    intensity = 0.5,
    colors = {
      dark = '#004466'  -- Custom color
    }
  },
  debug = true
})
```

## 7. Technology Choices

### Primary: Neovim 0.5+ with Lua

**Rationale**:
- Native async I/O via `vim.loop` (libuv)
- Extmarks are superior to overlays/text properties
- Lua is faster and easier to maintain than VimScript
- Modern plugin ecosystem (Telescope, lualine integration)

**Minimum version**: Neovim 0.5.0 (for basic Lua, extmarks, autocmds)
**Recommended**: Neovim 0.8.0+ (for improved APIs)

### Secondary: Vim 8.2+ Compatibility

**Rationale**:
- VimScript wrapper around core Lua logic
- Use `job_start()` for async socket operations
- Text properties (Vim 8.1+) or signs as fallback

**Limitations**:
- No native socket support (requires Python/external helper or channel I/O)
- Text properties less flexible than extmarks
- Performance may be slower than Neovim

**Strategy**: Provide best-effort Vim support, but optimize for Neovim.

### Socket Communication

**Neovim**:
```lua
local socket = vim.loop.new_tcp()
socket:connect('127.0.0.1', 12345, function(err)
  if not err then
    socket:read_start(function(err, chunk)
      -- Process data
    end)
  end
end)
```

**Vim** (via channels):
```vim
let s:channel = ch_open('localhost:12345', {
  \ 'mode': 'raw',
  \ 'callback': 'CodeAwareness_OnMessage',
  \ 'close_cb': 'CodeAwareness_OnClose'
  \ })
```

**Alternative for Vim**: Use Python3 helper script for socket operations:

```python
# autoload/code_awareness_socket.py
import vim
import socket
import json

def connect_to_socket(path):
    sock = socket.socket(socket.AF_UNIX)
    sock.connect(path)
    return sock
```

## 8. File Structure

```
kawa.vim/
├── README.md                          # User documentation
├── ARCHITECTURE.md                    # This document
├── IMPLEMENTATION_PLAN.md             # Development roadmap
├── LICENSE                            # MIT license
├── plugin/
│   └── code-awareness.vim             # Entry point, registers commands
├── autoload/
│   └── code_awareness.vim             # VimScript API for Vim support
├── lua/
│   └── code-awareness/
│       ├── init.lua                   # Main module, setup()
│       ├── config.lua                 # Configuration management
│       ├── state.lua                  # State management
│       ├── commands.lua               # User commands
│       ├── highlight.lua              # Highlight manager
│       ├── events.lua                 # Event dispatcher
│       ├── ui.lua                     # Status, messages, notifications
│       ├── diff.lua                   # Diff integration
│       ├── util.lua                   # Helper functions
│       └── ipc/
│           ├── init.lua               # IPC manager
│           ├── socket.lua             # Socket operations (Neovim)
│           ├── protocol.lua           # Message encoding/decoding
│           └── catalog.lua            # Catalog registration
├── autoload/
│   └── code_awareness_compat.vim      # Vim 8.2 compatibility shims
├── doc/
│   └── code-awareness.txt             # Vim help documentation
└── tests/
    ├── minimal_init.lua               # Test setup
    └── code-awareness/
        ├── ipc_spec.lua               # IPC tests
        ├── highlight_spec.lua         # Highlight tests
        └── state_spec.lua             # State tests
```

## 9. Key Challenges & Solutions

### Challenge 1: Cross-Platform Socket Support

**Problem**: Windows uses named pipes (`\\.\pipe\...`), Unix uses Unix sockets.

**Solution**:
```lua
local function get_socket_path(name)
  if vim.fn.has('win32') == 1 then
    return '\\\\.\\pipe\\' .. name
  else
    return vim.fn.expand('~/.kawa-code/sockets/') .. name
  end
end

local function connect_socket(path)
  if vim.fn.has('win32') == 1 then
    -- Named pipe connection
    return vim.loop.new_pipe(false)
  else
    -- Unix socket connection
    return vim.loop.new_pipe(false)  -- Same API, different underlying impl
  end
end
```

### Challenge 2: Vim Async Limitations

**Problem**: Vim doesn't have native async socket support like Neovim's `vim.loop`.

**Solution**: Use one of these approaches:
1. **Channels** (Vim 8.0+): Built-in async I/O
2. **Python3 helper**: Use `py3eval()` to run async Python socket code
3. **External job**: Launch separate process that communicates via stdin/stdout

**Chosen approach**: Channels for simplicity and no external dependencies.

### Challenge 3: Message Boundary Detection

**Problem**: TCP streams don't have message boundaries; JSON messages arrive fragmented.

**Solution**: Buffer incoming data and split on delimiter:

```lua
local buffer = ''

local function on_read(err, chunk)
  if chunk then
    buffer = buffer .. chunk

    -- Process complete messages (delimited by \f)
    while true do
      local delimiter_pos = buffer:find('\f')
      if not delimiter_pos then break end

      local message = buffer:sub(1, delimiter_pos - 1)
      buffer = buffer:sub(delimiter_pos + 1)

      handle_message(vim.json.decode(message))
    end
  end
end
```

### Challenge 4: Highlight Synchronization

**Problem**: Buffer content changes (insert/delete lines) invalidate line numbers.

**Solution**: Extmarks automatically track line movements. For Vim text properties, we need to:
1. Clear and reapply highlights after buffer changes, OR
2. Use buffer change tracking to adjust line numbers

```lua
-- Neovim: extmarks handle this automatically
vim.api.nvim_buf_set_extmark(bufnr, ns_id, line - 1, 0, {
  hl_group = 'CodeAwarenessHighlight',
  hl_eol = true
})

-- Vim: manual tracking required
vim.api.nvim_create_autocmd('TextChanged', {
  callback = function()
    -- Re-request highlights from app
    send_active_path_update()
  end
})
```

### Challenge 5: Performance with Large Files

**Problem**: Highlighting thousands of lines can be slow.

**Solution**:
1. Only highlight visible lines (use `winsaveview()` to get viewport)
2. Batch extmark operations
3. Debounce highlight updates during rapid typing

```lua
local function apply_highlights_in_viewport(bufnr, highlights)
  local win = vim.fn.bufwinid(bufnr)
  if win == -1 then return end

  local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  local top_line = view.topline
  local bot_line = view.topline + vim.api.nvim_win_get_height(win)

  for _, hl in ipairs(highlights) do
    if hl.line >= top_line and hl.line <= bot_line then
      apply_highlight(bufnr, hl)
    end
  end
end
```

## 10. Integration Points

### Statusline Integration

**Lualine.nvim**:
```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      function()
        local ca = require('code-awareness')
        if not ca.is_enabled() then return '' end

        local state = ca.get_state()
        local peer_count = vim.tbl_count(state.peers)

        if peer_count > 0 then
          return string.format('👥 %d peers', peer_count)
        end
        return '✓ CA'
      end
    }
  }
})
```

### Telescope.nvim

Provide peer/branch pickers:

```lua
require('telescope').extensions.code_awareness.peers()
require('telescope').extensions.code_awareness.branches()
```

### diffview.nvim

Use diffview for richer diff UI:

```lua
require('diffview').open(peer_file, current_file)
```

## 11. Testing Strategy

### Unit Tests (Plenary.nvim)

```lua
-- tests/code-awareness/state_spec.lua
describe('State Manager', function()
  it('tracks active buffer', function()
    local state = require('code-awareness.state')
    state.set_active_buffer(1, '/tmp/test.lua')
    assert.are.equal(1, state.get_active_buffer())
  end)
end)
```

### Integration Tests

- Mock IPC socket with test server
- Verify message encoding/decoding
- Test highlight application with dummy buffer

### Manual Testing Checklist

- [ ] Connect to real Kawa Code app
- [ ] Receive highlights from app
- [ ] Send active-path updates
- [ ] Open peer diff
- [ ] Open branch diff
- [ ] Handle app disconnect/reconnect
- [ ] Theme switching (light/dark)
- [ ] Performance with large files (10k+ lines)

## 12. Comparison with kawa.emacs

| Feature | kawa.emacs | kawa.vim (Neovim) | kawa.vim (Vim) |
|---------|------------|-------------------|----------------|
| **Language** | Elisp | Lua | VimScript wrapper + Lua |
| **Async I/O** | Threads + processes | vim.loop (libuv) | Channels / jobs |
| **Highlighting** | Overlays | Extmarks | Text properties / signs |
| **Socket API** | `make-network-process` | `vim.loop.new_pipe()` | `ch_open()` |
| **JSON** | Built-in `json.el` | `vim.json` | `json_decode()` |
| **Threading** | Mutex + cond vars | Coroutines | Single-threaded |
| **Diff Tool** | ediff | diffthis / diffview.nvim | diffthis |
| **Min Version** | Emacs 27.1 | Neovim 0.5 | Vim 8.2 |

**Key Advantages of Neovim**:
- `vim.loop` provides better async primitives than Emacs processes
- Extmarks are more powerful and efficient than overlays
- Lua is faster and easier to debug than Elisp
- Native LSP integration for future enhancements

**Key Advantages of Emacs**:
- Mature threading model
- `ediff` is more sophisticated than vimdiff
- Easier to distribute (single `.el` file possible)

## 13. Future Enhancements

### Phase 2 Features
- **Virtual text peer annotations**: Show peer names inline
- **Floating window previews**: Hover to see peer's code
- **Conflict resolution UI**: Accept mine/theirs/both for conflicts
- **Branch switching integration**: Sync with Git plugins

### Phase 3 Features
- **LSP integration**: Code Awareness as LSP diagnostics
- **Tree-sitter queries**: Better semantic understanding of changes
- **Multi-cursor support**: Coordinate cursor positions with peers
- **Session recording**: Replay peer's editing session

---

## Conclusion

This architecture provides a solid foundation for implementing Code Awareness in Vim/Neovim while maintaining feature parity with kawa.emacs. The design prioritizes:

1. **Performance**: Async I/O and efficient highlighting
2. **Reliability**: Robust error handling and reconnection logic
3. **Usability**: Intuitive commands and unobtrusive UI
4. **Extensibility**: Clean APIs for future enhancements

The modular design allows incremental development and testing, with clear interfaces between components. The Neovim-first approach leverages modern capabilities while maintaining Vim compatibility through a thin compatibility layer.
