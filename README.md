# Code Awareness for Vim/Neovim

Real-time collaboration extension that highlights code intersections between your working copy and teammates' work.

## Features

- **Real-time highlights**: See lines being worked on by you or your team
- **Early conflict detection**: Know about potential conflicts before pushing
- **Instant navigation**: View and diff peer code without waiting for commits
- **Low overhead**: Asynchronous IPC and efficient highlighting
- **Cross-platform**: Works on Linux, macOS, and Windows

## Requirements

- **Neovim** 0.5.0 or higher (recommended: 0.8.0+)
- Support is planned for **Vim** 8.2+ -- currently not working
- **Kawa Code** desktop app ([download here](https://code-awareness.com))

## Installation

### lazy.nvim

```lua
{
  'CodeAwareness/kawa.vim',
  config = function()
    require('code-awareness').setup({
      -- Optional configuration
      debug = false,
    })
  end,
}
```

### packer.nvim

```lua
use {
  'CodeAwareness/kawa.vim',
  config = function()
    require('code-awareness').setup()
  end
}
```

### vim-plug

```vim
Plug 'CodeAwareness/kawa.vim'

" In your vimrc:
lua << EOF
require('code-awareness').setup()
EOF
```

## Quick Start

1. Install the Kawa Code desktop app and login
2. Install this plugin using your package manager
3. Open Neovim in a Git repository
4. Plugin will automatically connect to Kawa Code
5. Highlights will appear on lines you or your teammates are working on
6. Kawa Code will display the contributors for that file, as well as other info

## Commands

| Command | Description |
|---------|-------------|
| `:CodeAwareness status` | Show connection and auth status |
| `:CodeAwareness toggle` | Enable/disable plugin |
| `:CodeAwareness refresh` | Force refresh current buffer |
| `:CodeAwareness clear` | Clear all highlights |
| `:CodeAwareness reconnect` | Reconnect to Kawa Code app |

## Configuration

```lua
require('code-awareness').setup({
  -- Enable debug logging
  debug = false,

  -- Highlight settings
  highlight = {
    enabled = true,
    intensity = 0.3,
    full_width = true,
    colors = {
      light = '#00b1a420',
      dark = '#03445f',
    },
  },

  -- Update behavior
  update_delay = 500,  -- ms debounce
  send_on_save = true,
  send_on_buffer_enter = true,

  -- IPC settings
  connection_timeout = 5000,
  max_poll_attempts = 5,
})
```

## Documentation

See `:help code-awareness` for full documentation.

For architecture details, see [ARCHITECTURE.md](ARCHITECTURE.md).

For development and contributing, see [DEVELOPMENT.md](DEVELOPMENT.md).

## License

MIT License - see [LICENSE](LICENSE) for details.

## Related Projects

- [kawa.emacs](https://github.com/CodeAwareness/kawa.emacs) - Code Awareness for Emacs
