# Code Awareness for Vim/Neovim - Implementation Plan

## Overview

This document outlines the phased implementation plan for kawa.vim, the Vim/Neovim extension for Code Awareness. The plan is organized into incremental phases, each delivering working functionality that can be tested against the real Kawa Code desktop app.

## Development Principles

1. **Test Early**: Test against real Kawa Code app from Phase 1
2. **Incremental Delivery**: Each phase produces working, testable features
3. **Neovim First**: Implement and test on Neovim 0.5+, add Vim compat later
4. **Documentation**: Update docs alongside code
5. **Code Quality**: Follow Lua style guide, add tests for critical paths

## Timeline Estimate

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 0: Setup | 1-2 days | Project structure, tooling |
| Phase 1: IPC Foundation | 3-5 days | Working connection to Kawa Code |
| Phase 2: Highlighting | 3-4 days | Visual highlights in buffers |
| Phase 3: Commands & UI | 2-3 days | User-facing commands |
| Phase 4: Diff Integration | 2-3 days | Peer and branch diffs |
| Phase 5: Polish & Testing | 3-5 days | Bug fixes, performance, docs |
| Phase 6: Vim Compatibility | 3-5 days | VimScript wrapper |
| **Total** | **17-27 days** | **Production-ready plugin** |

---

## Phase 0: Project Setup & Foundation

**Duration**: 1-2 days
**Goal**: Create project structure, tooling, and basic plugin skeleton

### Tasks

#### 0.1 Repository Structure
- [x] Initialize Git repository
- [ ] Create directory structure (see ARCHITECTURE.md §8)
- [ ] Add `.gitignore` (Vim swap files, OS files)
- [ ] Add `.editorconfig` for consistent formatting
- [ ] Create LICENSE file (MIT to match kawa.emacs)
- [ ] Create initial README.md with installation instructions

#### 0.2 Development Tools
- [ ] Set up `stylua` for Lua formatting
- [ ] Configure `luacheck` for static analysis
- [ ] Add `.luacheckrc` configuration
- [ ] Set up `plenary.nvim` for testing
- [ ] Create `Makefile` with targets:
  - `make format` - Format Lua files
  - `make lint` - Run luacheck
  - `make test` - Run plenary tests
  - `make install` - Symlink to ~/.local/share/nvim/site/pack/

#### 0.3 Plugin Skeleton
- [ ] Create `plugin/code-awareness.vim`
  - Guard against reloading
  - Check Neovim version (>= 0.5)
  - Define user commands (stubs)
- [ ] Create `lua/code-awareness/init.lua`
  - `setup(config)` function
  - `enable()` / `disable()` functions
  - Module state initialization
- [ ] Create `lua/code-awareness/config.lua`
  - Default configuration (see ARCHITECTURE.md §6)
  - `merge_config(user_config)` function
  - Config validation

#### 0.4 Documentation
- [ ] Create `doc/code-awareness.txt` (Vim help file)
  - Installation
  - Configuration
  - Commands (TBD in later phases)
- [ ] Generate help tags

**Acceptance Criteria**:
- [ ] `:PackerSync` (or `:Lazy sync`) successfully installs plugin
- [ ] `:help code-awareness` shows help documentation
- [ ] `:CodeAwareness` command exists (shows "Not implemented")
- [ ] No errors when calling `require('code-awareness').setup({})`

---

## Phase 1: IPC Foundation

**Duration**: 3-5 days
**Goal**: Establish bidirectional communication with Kawa Code desktop app

### Tasks

#### 1.1 Socket Utilities (`lua/code-awareness/ipc/socket.lua`)
- [ ] Implement `new_pipe()` wrapper around `vim.loop.new_pipe()`
- [ ] Implement `connect(path, on_connect)` async function
- [ ] Implement `write(data, callback)` function
- [ ] Implement `read_start(on_data)` function
- [ ] Implement `close()` function
- [ ] Handle errors and timeouts
- [ ] Add logging for debugging

**Test**: Manually connect to any Unix socket and send/receive data

#### 1.2 Message Protocol (`lua/code-awareness/ipc/protocol.lua`)
- [ ] Implement `encode_message(flow, domain, action, data, caw_id)`
  - Returns JSON string + `\f` delimiter
- [ ] Implement `decode_message(json_string)`
  - Returns parsed table or nil + error
- [ ] Implement stream parser with buffer:
  - `create_parser()` - Returns parser instance
  - `parser:feed(chunk)` - Add data to buffer
  - `parser:next_message()` - Extract complete message or nil
- [ ] Add message validation

**Test**: Unit tests for encoding/decoding and boundary detection

#### 1.3 Catalog Registration (`lua/code-awareness/ipc/catalog.lua`)
- [ ] Implement `register_client(callback)`
  - Connect to catalog socket
  - Send `clientId` request
  - Parse response for GUID
  - Close catalog connection
  - Return GUID via callback
- [ ] Handle catalog connection errors
- [ ] Add retry logic (2-3 attempts)

**Test**: Successfully register with real Kawa Code catalog

#### 1.4 IPC Manager (`lua/code-awareness/ipc/init.lua`)
- [ ] Implement `connect(on_ready)` function
  - Call `catalog.register_client()`
  - Poll for client socket with exponential backoff
  - Connect to client socket
  - Set up read loop
  - Call `on_ready()` when connected
- [ ] Implement `send(domain, action, data, response_handler)`
  - Encode message
  - Write to socket
  - Register response handler if provided
- [ ] Implement message dispatcher
  - Parse incoming messages
  - Route `res` messages to response handlers
  - Route `req` messages to event handlers
- [ ] Implement `disconnect()` function
- [ ] Implement `reconnect()` function
- [ ] Track connection state

**Test**: Full connection lifecycle with Kawa Code app

#### 1.5 Event System (`lua/code-awareness/events.lua`)
- [ ] Create event registry (hash table)
- [ ] Implement `register(domain, action, handler)` function
- [ ] Implement `dispatch(domain, action, data)` function
- [ ] Implement `unregister(domain, action)` function
- [ ] Add wildcard support for `domain = '*'`

**Test**: Register handlers and verify dispatch works

#### 1.6 Integration & Testing
- [ ] Wire IPC to main module (`init.lua`)
- [ ] Add `:CodeAwareness status` command
  - Show connection status
  - Show client GUID
  - Show auth status (via `auth:info` request)
- [ ] Add `:CodeAwareness debug` command
  - Toggle debug logging
  - Show last 50 IPC messages
- [ ] Add autocommand to connect on `VimEnter`
- [ ] Add autocommand to disconnect on `VimLeavePre`

**Acceptance Criteria**:
- [ ] Plugin connects to Kawa Code on Neovim startup
- [ ] `:CodeAwareness status` shows "Connected" and auth info
- [ ] `:CodeAwareness debug` shows IPC messages
- [ ] Plugin reconnects if Kawa Code restarts
- [ ] No errors in `:messages` log

---

## Phase 2: Highlighting System

**Duration**: 3-4 days
**Goal**: Apply visual highlights to buffers based on Code Awareness data

### Tasks

#### 2.1 Highlight Manager (`lua/code-awareness/highlight.lua`)
- [ ] Create namespace: `vim.api.nvim_create_namespace('code_awareness')`
- [ ] Define highlight groups:
  - `CodeAwarenessModified`
  - `CodeAwarenessPeer`
  - `CodeAwarenessConflict`
- [ ] Implement `init_colors(theme)` function
  - Set colors based on `vim.o.background`
  - Support custom colors from config
- [ ] Implement `apply_highlights(bufnr, highlights)` function
  - Clear existing highlights
  - Apply extmarks for each line
  - Set `hl_eol = true` for full-width
  - Handle invalid buffer/line numbers
- [ ] Implement `clear_highlights(bufnr)` function
  - Remove all extmarks in namespace
- [ ] Implement `refresh_colors()` function
  - Re-apply colors when theme changes
- [ ] Add per-buffer highlight tracking

**Test**: Manually call `apply_highlights()` with test data

#### 2.2 State Manager (`lua/code-awareness/state.lua`)
- [ ] Create state table structure (see ARCHITECTURE.md §2)
- [ ] Implement `set_active_buffer(bufnr, filepath, project)`
- [ ] Implement `get_active_buffer()`
- [ ] Implement `set_highlights(bufnr, highlight_data)`
  - Store `modified`, `peer`, `conflict` line arrays
- [ ] Implement `get_highlights(bufnr)`
- [ ] Implement `set_peers(peer_data)`
- [ ] Implement `get_peers()`
- [ ] Implement `clear_buffer(bufnr)` - Remove state for closed buffer

**Test**: Unit tests for state mutations

#### 2.3 Active Path Tracking
- [ ] Implement `send_active_path(bufnr)` function
  - Get file path, content, cursor position
  - Get project root (use Git or LSP root)
  - Send `active-path` request
  - Register response handler
- [ ] Implement response handler for `active-path`
  - Parse highlight data
  - Convert 0-based to 1-based line numbers
  - Update state via `state.set_highlights()`
  - Apply highlights via `highlight.apply_highlights()`
- [ ] Add debouncing (500ms default)

**Test**: Open file, verify highlight request sent

#### 2.4 Buffer Autocommands
- [ ] Add `BufEnter` autocommand
  - Update active buffer in state
  - Send active-path (debounced)
- [ ] Add `BufWritePost` autocommand
  - Send active-path with updated content
- [ ] Add `BufDelete` autocommand
  - Clear state for buffer
  - Clear highlights
- [ ] Add `ColorScheme` autocommand
  - Refresh highlight colors
- [ ] Only trigger for file buffers (not help, terminal, etc.)

**Test**: Switch between buffers, verify highlights update

#### 2.5 Integration & Commands
- [ ] Add `:CodeAwareness refresh` command
  - Force resend active-path
  - Reapply highlights
- [ ] Add `:CodeAwareness clear` command
  - Clear all highlights
  - Clear state
- [ ] Add `:CodeAwareness toggle` command
  - Enable/disable highlighting
  - Persist state

**Acceptance Criteria**:
- [ ] Opening a file sends `active-path` request
- [ ] Highlights appear on lines with changes/peer edits
- [ ] Correct colors for light and dark themes
- [ ] Highlights persist across buffer switches
- [ ] Saving file updates highlights
- [ ] `:CodeAwareness clear` removes all highlights
- [ ] No performance degradation on large files (test 10k lines)

---

## Phase 3: Commands & UI

**Duration**: 2-3 days
**Goal**: Provide user-friendly commands and status indicators

### Tasks

#### 3.1 Status UI (`lua/code-awareness/ui.lua`)
- [ ] Implement `show_status()` function
  - Connection status
  - Auth status
  - Active file
  - Peer count
  - Conflict count
  - Display in floating window or echo
- [ ] Implement `show_error(message)` function
  - Use `vim.notify()` or `vim.api.nvim_err_writeln()`
- [ ] Implement `show_info(message)` function
- [ ] Implement `confirm(message)` function
  - Use `vim.fn.confirm()`

**Test**: Call UI functions manually

#### 3.2 Statusline Integration
- [ ] Implement `get_statusline_component()` function
  - Return string for statusline
  - Format: `"✓"` (connected) or `"✗"` (disconnected)
  - Show peer count if > 0
  - Show conflict count if > 0
- [ ] Add example for `lualine.nvim`
- [ ] Add example for native statusline

**Test**: Verify statusline shows correct info

#### 3.3 Command System (`lua/code-awareness/commands.lua`)
- [ ] Implement `:CodeAwareness status`
  - Show detailed status UI
- [ ] Implement `:CodeAwareness toggle`
  - Enable/disable plugin
  - Show confirmation message
- [ ] Implement `:CodeAwareness refresh`
  - Force refresh current buffer
- [ ] Implement `:CodeAwareness clear`
  - Clear all highlights
- [ ] Implement `:CodeAwareness reconnect`
  - Disconnect and reconnect to app
- [ ] Add command completion
- [ ] Add command help text

**Test**: Run each command and verify behavior

#### 3.4 Logging System (`lua/code-awareness/util.lua`)
- [ ] Implement `log.debug(message)` function
- [ ] Implement `log.info(message)` function
- [ ] Implement `log.warn(message)` function
- [ ] Implement `log.error(message)` function
- [ ] Store logs in circular buffer (last 100 messages)
- [ ] Implement `get_logs()` function
- [ ] Add `:CodeAwareness logs` command to view logs

**Test**: Generate logs and view via command

#### 3.5 Error Handling
- [ ] Add error handling to IPC layer
  - Socket connection failures
  - Timeout errors
  - Malformed messages
- [ ] Add error handling to highlight layer
  - Invalid line numbers
  - Buffer no longer valid
- [ ] Show user-friendly error messages
- [ ] Log detailed errors for debugging

**Acceptance Criteria**:
- [ ] `:CodeAwareness status` shows comprehensive info
- [ ] Statusline component displays correctly
- [ ] All commands work without errors
- [ ] Errors are logged and shown to user
- [ ] `:help code-awareness` documents all commands

---

## Phase 4: Diff Integration

**Duration**: 2-3 days
**Goal**: Enable viewing peer and branch diffs

### Tasks

#### 4.1 Diff Manager (`lua/code-awareness/diff.lua`)
- [ ] Implement `diff_peer(peer_id)` function
  - Send `diff-peer` request with current file
  - Wait for response with peer file path
  - Open diff with `diffthis` or `diffview.nvim`
- [ ] Implement `diff_branch(branch_name)` function
  - Send `diff-branch` request
  - Wait for response with branch file path
  - Open diff
- [ ] Implement `close_diff()` function
  - Close diff buffers
  - Return to original buffer
- [ ] Handle diff layout (vertical/horizontal)

**Test**: Request diff with peer/branch

#### 4.2 Event Handlers
- [ ] Register handler for `peer:select` event
  - Called when user selects peer in app
  - Automatically open diff
  - Show notification
- [ ] Register handler for `branch:select` event
  - Automatically open branch diff
  - Show notification

**Test**: Select peer in Kawa Code app, verify diff opens

#### 4.3 Peer Selection
- [ ] Implement `:CodeAwareness diff_peer [name]` command
  - If name provided, diff with that peer
  - If no name, show peer picker
- [ ] Implement peer picker (basic version)
  - Use `vim.ui.select()` for built-in picker
  - Show peer names from state
- [ ] Implement `:CodeAwareness list_peers` command
  - Show all active peers

**Test**: Run commands with and without arguments

#### 4.4 Branch Selection
- [ ] Implement `:CodeAwareness diff_branch [name]` command
  - If name provided, diff with that branch
  - If no name, ask for branch name
- [ ] Use `vim.fn.input()` for branch name prompt
- [ ] Validate branch name (basic check)

**Test**: Request branch diff

#### 4.5 Diff View Options
- [ ] Add config option `diff_tool` ('diffthis' or 'diffview')
- [ ] Add config option `diff_layout` ('vertical' or 'horizontal')
- [ ] Implement diffthis integration:
  ```lua
  vim.cmd('vsplit ' .. peer_file)
  vim.cmd('diffthis')
  vim.cmd('wincmd p')
  vim.cmd('diffthis')
  ```
- [ ] Implement diffview.nvim integration (if available):
  ```lua
  require('diffview').file_history(peer_file, current_file)
  ```

**Acceptance Criteria**:
- [ ] `:CodeAwareness diff_peer alice` opens diff with alice's version
- [ ] Selecting peer in app automatically opens diff
- [ ] `:CodeAwareness diff_branch main` opens diff with main branch
- [ ] Diff layout respects config setting
- [ ] Can close diff and return to editing

---

## Phase 5: Polish & Testing

**Duration**: 3-5 days
**Goal**: Bug fixes, performance optimization, comprehensive testing

### Tasks

#### 5.1 Performance Optimization
- [ ] Profile plugin with large files (10k+ lines)
- [ ] Optimize highlight application (batch extmarks)
- [ ] Add viewport-based highlighting (only visible lines)
- [ ] Optimize IPC message parsing
- [ ] Add rate limiting for active-path updates
- [ ] Test memory usage with long-running sessions

**Test**: Open 50 files, switch rapidly, check responsiveness

#### 5.2 Edge Cases & Bug Fixes
- [ ] Handle non-file buffers (terminals, help, etc.)
- [ ] Handle remote files (SSH, fugitive, etc.)
- [ ] Handle files outside Git repos
- [ ] Handle socket disconnection during operation
- [ ] Handle app restart scenario
- [ ] Handle invalid highlight data from app
- [ ] Handle concurrent buffer switches
- [ ] Handle Neovim exit during pending IPC request

**Test**: Create test suite for edge cases

#### 5.3 Unit Tests
- [ ] Tests for `config.lua` (merge, validate)
- [ ] Tests for `state.lua` (all mutations)
- [ ] Tests for `ipc/protocol.lua` (encode/decode)
- [ ] Tests for `ipc/socket.lua` (mock socket)
- [ ] Tests for `highlight.lua` (mock buffer)
- [ ] Tests for `util.lua` (helpers)
- [ ] Achieve >80% code coverage

**Tools**: `plenary.nvim`, `luassert`

#### 5.4 Integration Tests
- [ ] Set up mock Kawa Code server (Lua socket server)
- [ ] Test full connection flow
- [ ] Test message request/response
- [ ] Test highlight application from mock data
- [ ] Test reconnection logic
- [ ] Test concurrent operations

**Test**: CI pipeline runs tests

#### 5.5 Documentation
- [ ] Complete `doc/code-awareness.txt`
  - Installation (lazy.nvim, packer, vim-plug)
  - Configuration (all options)
  - Commands (all user commands)
  - Functions (Lua API)
  - Troubleshooting
  - FAQ
- [ ] Update README.md
  - Features
  - Screenshots/GIFs
  - Installation
  - Quick start
  - Configuration examples
  - Comparison with kawa.emacs
- [ ] Add inline code comments
- [ ] Add module docstrings (LuaLS annotations)

#### 5.6 Code Quality
- [ ] Run `stylua` on all Lua files
- [ ] Run `luacheck` and fix all warnings
- [ ] Add type annotations (LuaLS/EmmyLua style)
- [ ] Refactor complex functions (max 50 lines)
- [ ] Add error handling to all public APIs
- [ ] Consistent naming conventions

#### 5.7 User Testing
- [ ] Dogfood plugin in real project for 1 week
- [ ] Test with multiple peers simultaneously
- [ ] Test with conflicting changes
- [ ] Test theme switching
- [ ] Test different file types
- [ ] Collect and fix any issues

**Acceptance Criteria**:
- [ ] All tests pass
- [ ] No performance regressions
- [ ] Documentation is complete and accurate
- [ ] Code quality checks pass
- [ ] No known critical bugs
- [ ] Plugin works reliably in real-world usage

---

## Phase 6: Vim Compatibility

**Duration**: 3-5 days
**Goal**: Add support for Vim 8.2+ with channels

### Tasks

#### 6.1 Compatibility Layer (`autoload/code_awareness_compat.vim`)
- [ ] Implement channel-based socket wrapper
  - `CodeAwarenessConnect(path, callback)` function
  - `CodeAwarenessSend(channel, data)` function
  - `CodeAwarenessClose(channel)` function
- [ ] Implement message parser in VimScript
  - Buffer incoming data
  - Split on `\f` delimiter
  - JSON decode via `json_decode()`
- [ ] Implement callback system
  - Map VimScript callbacks to Lua handlers
  - Bridge between channel callbacks and Lua

**Test**: Connect to socket from Vim

#### 6.2 Text Properties Highlighting
- [ ] Implement text property-based highlights
- [ ] Define property types for each highlight group
- [ ] Implement `apply_highlights_vim()` function
- [ ] Implement `clear_highlights_vim()` function
- [ ] Handle line insertions/deletions
- [ ] Fallback to signs if text properties unavailable

**Test**: Highlights appear in Vim 8.2+

#### 6.3 VimScript Commands (`plugin/code-awareness.vim`)
- [ ] Define `:CodeAwareness` command in VimScript
- [ ] Delegate to Lua functions if Neovim
- [ ] Delegate to VimScript functions if Vim
- [ ] Add Vim-specific error handling

#### 6.4 Autocommands
- [ ] Convert Neovim autocmds to Vim autocmds
- [ ] Use `augroup` for organization
- [ ] Handle Vim-specific events

#### 6.5 Testing on Vim
- [ ] Set up Vim 8.2 test environment
- [ ] Test all commands
- [ ] Test highlighting
- [ ] Test IPC connection
- [ ] Test diffs
- [ ] Document known limitations

**Acceptance Criteria**:
- [ ] Plugin loads without errors in Vim 8.2
- [ ] Basic functionality works (connect, highlight, diff)
- [ ] Documentation notes Vim vs Neovim differences
- [ ] CI tests both Vim and Neovim

---

## Phase 7: Release Preparation

**Duration**: 1-2 days
**Goal**: Prepare for public release

### Tasks

#### 7.1 Packaging
- [ ] Create `.rockspec` for LuaRocks (optional)
- [ ] Verify plugin manager compatibility:
  - [ ] lazy.nvim
  - [ ] packer.nvim
  - [ ] vim-plug
  - [ ] Vundle
- [ ] Add installation instructions for each

#### 7.2 CI/CD
- [ ] Set up GitHub Actions
  - [ ] Lint on PR
  - [ ] Run tests on PR
  - [ ] Test on multiple Neovim versions (0.5, 0.7, 0.9, 0.10)
  - [ ] Test on Vim 8.2, 9.0
- [ ] Add badges to README (CI status, license)

#### 7.3 Release Notes
- [ ] Create CHANGELOG.md
- [ ] Document initial release (v0.1.0)
- [ ] List features
- [ ] List known limitations
- [ ] List future roadmap

#### 7.4 Community
- [ ] Create GitHub issue templates
  - Bug report
  - Feature request
- [ ] Create PR template
- [ ] Add CONTRIBUTING.md
- [ ] Add CODE_OF_CONDUCT.md

#### 7.5 Announcement
- [ ] Create demo GIF/video
- [ ] Post to Reddit r/neovim
- [ ] Post to Vim subreddit
- [ ] Tweet announcement
- [ ] Update Code Awareness website (if applicable)

**Acceptance Criteria**:
- [ ] v0.1.0 tagged and released
- [ ] README has clear installation instructions
- [ ] CI pipeline is green
- [ ] No critical bugs

---

## Testing Milestones

### Milestone 1: IPC Working (End of Phase 1)
- [ ] Can connect to Kawa Code app
- [ ] Can send messages
- [ ] Can receive messages
- [ ] Can parse JSON correctly
- [ ] Handles reconnection

### Milestone 2: Highlights Working (End of Phase 2)
- [ ] Modified lines are highlighted
- [ ] Peer lines are highlighted
- [ ] Conflict lines are highlighted
- [ ] Colors change with theme
- [ ] Works on multiple buffers

### Milestone 3: Feature Complete (End of Phase 4)
- [ ] All commands work
- [ ] Diffs work
- [ ] Statusline integration works
- [ ] No critical bugs

### Milestone 4: Production Ready (End of Phase 5)
- [ ] All tests pass
- [ ] Documentation complete
- [ ] Performance is acceptable
- [ ] User testing complete

### Milestone 5: Released (End of Phase 7)
- [ ] v0.1.0 tagged
- [ ] Announced publicly
- [ ] Available on plugin managers

---

## Risk Mitigation

### Risk 1: Kawa Code API Changes
**Mitigation**: Version the protocol, add compatibility checks

### Risk 2: Performance Issues
**Mitigation**: Profile early, optimize incrementally, add config for features

### Risk 3: Vim Compatibility Challenges
**Mitigation**: Implement Neovim first, add Vim later, document limitations

### Risk 4: Complex Socket Issues (Windows)
**Mitigation**: Test on Windows early, use named pipe API, consider external helper

### Risk 5: User Adoption
**Mitigation**: Great documentation, demo videos, responsive to issues

---

## Success Criteria

**Phase 1-5 (Neovim MVP)**:
- [ ] Connects to Kawa Code successfully
- [ ] Shows highlights in real-time
- [ ] Opens peer/branch diffs
- [ ] No critical bugs
- [ ] Documentation complete

**Phase 6 (Vim Support)**:
- [ ] Works on Vim 8.2+
- [ ] Core features functional
- [ ] Documented limitations

**Overall Success**:
- [ ] 100+ GitHub stars in first month
- [ ] Positive feedback from users
- [ ] Feature parity with kawa.emacs
- [ ] Active maintenance and support

---

## Post-Release Roadmap

### v0.2.0 (Future)
- Virtual text peer names
- Floating window previews
- Conflict resolution UI
- Better Telescope integration

### v0.3.0 (Future)
- LSP diagnostic integration
- Tree-sitter semantic highlights
- Multi-cursor coordination
- Session replay

### v1.0.0 (Stable)
- All features tested and stable
- Comprehensive documentation
- Wide adoption
- Regular maintenance

---

## Development Workflow

### Daily Workflow
1. Pull latest from `main` branch
2. Create feature branch: `feature/phase-N-task-description`
3. Write failing test (if applicable)
4. Implement feature
5. Run tests: `make test`
6. Run linter: `make lint`
7. Format code: `make format`
8. Commit with conventional commit message
9. Push and create PR
10. Merge after review

### Commit Message Format
```
type(scope): subject

body

footer
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Examples**:
- `feat(ipc): add exponential backoff for socket polling`
- `fix(highlight): handle invalid line numbers gracefully`
- `docs(readme): add installation instructions for lazy.nvim`

### Code Review Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No linter errors
- [ ] Follows style guide
- [ ] Backwards compatible (or breaking change documented)

---

## Appendix: File Checklist

**Must-Have Files**:
- [x] `README.md`
- [ ] `ARCHITECTURE.md`
- [ ] `IMPLEMENTATION_PLAN.md` (this file)
- [ ] `LICENSE`
- [ ] `CHANGELOG.md`
- [ ] `.gitignore`
- [ ] `.editorconfig`
- [ ] `.luacheckrc`
- [ ] `Makefile`
- [ ] `plugin/code-awareness.vim`
- [ ] `lua/code-awareness/init.lua`
- [ ] `lua/code-awareness/config.lua`
- [ ] `lua/code-awareness/state.lua`
- [ ] `lua/code-awareness/highlight.lua`
- [ ] `lua/code-awareness/events.lua`
- [ ] `lua/code-awareness/commands.lua`
- [ ] `lua/code-awareness/ui.lua`
- [ ] `lua/code-awareness/diff.lua`
- [ ] `lua/code-awareness/util.lua`
- [ ] `lua/code-awareness/ipc/init.lua`
- [ ] `lua/code-awareness/ipc/socket.lua`
- [ ] `lua/code-awareness/ipc/protocol.lua`
- [ ] `lua/code-awareness/ipc/catalog.lua`
- [ ] `doc/code-awareness.txt`
- [ ] `tests/minimal_init.lua`

**Total Estimated LOC**: ~3,000-4,000 lines Lua + VimScript

---

## Questions & Decisions

### Q1: Support Vim or Neovim-only?
**Decision**: Neovim-first, add Vim compat in Phase 6

### Q2: Lua vs VimScript?
**Decision**: Lua for core, VimScript for compatibility layer

### Q3: Which diff tool?
**Decision**: Support both `diffthis` (built-in) and `diffview.nvim` (optional)

### Q4: How to handle theme changes?
**Decision**: Listen to `ColorScheme` autocmd, reinit colors

### Q5: How to test without Kawa Code app?
**Decision**: Create mock server in Lua for integration tests

---

## Conclusion

This implementation plan provides a clear roadmap from initial setup to production-ready plugin. Each phase builds on the previous, delivering testable functionality incrementally. The plan balances ambition (full feature parity with kawa.emacs) with pragmatism (Neovim-first approach).

**Next Steps**:
1. Review this plan with stakeholders
2. Set up Phase 0 (project structure)
3. Begin Phase 1 (IPC foundation)
4. Test early and often with real Kawa Code app

**Estimated Total Time**: 17-27 days (3-5 weeks) for Phases 0-6, assuming full-time development.
