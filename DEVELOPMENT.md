# Development Guide

This guide covers how to test the plugin locally and publish it for users.

## Local Testing

### Method 1: Symlink to Neovim Runtime Path (Recommended)

The easiest way to test during development is to symlink your plugin directory to Neovim's runtime path:

```bash
# For Neovim (recommended)
ln -s /Users/markvasile/Code/CodeAwareness/Odin/kawa.vim ~/.local/share/nvim/site/pack/test/start/kawa.vim

# Or for a specific Neovim config (e.g., nvim-config)
ln -s /Users/markvasile/Code/CodeAwareness/Odin/kawa.vim ~/.config/nvim/pack/test/start/kawa.vim
```

Then restart Neovim and test the plugin. Changes to the plugin files will be immediately available.

**To remove the symlink:**
```bash
rm ~/.local/share/nvim/site/pack/test/start/kawa.vim
```

### Method 2: Test Neovim Config

Create a minimal test Neovim configuration that loads your plugin:

```bash
# Create a test config directory
mkdir -p ~/.config/nvim-test

# Create init.lua
cat > ~/.config/nvim-test/init.lua << 'EOF'
-- Minimal test config
vim.opt.runtimepath:prepend('/Users/markvasile/Code/CodeAwareness/Odin/kawa.vim')

require('code-awareness').setup({
  debug = true,  -- Enable debug logging for testing
})
EOF

# Run Neovim with test config
nvim -u ~/.config/nvim-test/init.lua
```

### Method 3: Using a Plugin Manager in Test Mode

If you use lazy.nvim, you can test locally by pointing to the local path:

```lua
-- In your test Neovim config
{
  dir = '/Users/markvasile/Code/CodeAwareness/Odin/kawa.vim',
  -- or use a relative path if your config is in the same workspace
  config = function()
    require('code-awareness').setup({
      debug = true,
    })
  end,
}
```

### Running Automated Tests

The plugin uses `plenary.nvim` for testing. Make sure you have it installed:

```bash
# Install plenary.nvim as a test dependency
git clone https://github.com/nvim-lua/plenary.nvim.git ~/.local/share/nvim/site/pack/test/opt/plenary.nvim
```

Then run tests:

```bash
# Run tests
make test-manual
```

### Manual Testing Checklist

Before publishing, test the following:

- [ ] Plugin loads without errors
- [ ] `:CodeAwareness status` shows connection status
- [ ] Highlights appear when Kawa Code app is running
- [ ] `:CodeAwareness toggle` enables/disables the plugin
- [ ] `:CodeAwareness refresh` updates highlights
- [ ] `:CodeAwareness clear` removes highlights
- [ ] `:CodeAwareness reconnect` reconnects to Kawa Code
- [ ] Plugin works with both Neovim 0.5.0+ and Vim 8.2+
- [ ] No errors in `:messages` when opening/closing buffers

## Publishing

### Prerequisites

1. **GitHub Repository**: Ensure your plugin is in a GitHub repository
   ```bash
   # If not already a git repo
   git init
   git remote add origin https://github.com/CodeAwareness/kawa.vim.git
   ```

2. **Version Tagging**: Use semantic versioning (e.g., `v1.0.0`)

### Publishing Steps

#### 1. Prepare for Release

```bash
# Ensure all tests pass
make test-manual

# Format and lint code
make format
make lint

# Commit any changes
git add .
git commit -m "Prepare for release v1.0.0"
```

#### 2. Create a Git Tag

```bash
# Create an annotated tag
git tag -a v1.0.0 -m "Release v1.0.0: Initial stable release"

# Push tag to GitHub
git push origin v1.0.0
```

#### 3. Create a GitHub Release (Optional but Recommended)

1. Go to your GitHub repository
2. Click "Releases" → "Create a new release"
3. Select the tag you just created
4. Add release notes describing changes
5. Publish the release

#### 4. Users Can Now Install

Once published, users can install via any plugin manager:

**lazy.nvim:**
```lua
{
  'CodeAwareness/kawa.vim',
  config = function()
    require('code-awareness').setup()
  end,
}
```

**packer.nvim:**
```lua
use {
  'CodeAwareness/kawa.vim',
  config = function()
    require('code-awareness').setup()
  end
}
```

**vim-plug:**
```vim
Plug 'CodeAwareness/kawa.vim'
```

**Manual installation:**
```bash
git clone https://github.com/CodeAwareness/kawa.vim.git ~/.local/share/nvim/site/pack/plugins/start/kawa.vim
```

### Version Management

For future releases:

```bash
# Update version (e.g., patch release)
git tag -a v1.0.1 -m "Release v1.0.1: Bug fixes"
git push origin v1.0.1

# Or minor release
git tag -a v1.1.0 -m "Release v1.1.0: New features"
git push origin v1.1.0

# Or major release
git tag -a v2.0.0 -m "Release v2.0.0: Breaking changes"
git push origin v2.0.0
```

### Publishing Checklist

Before publishing a new version:

- [ ] All tests pass (`make test-manual`)
- [ ] Code is formatted (`make format`)
- [ ] Code passes linting (`make lint`)
- [ ] README.md is up to date
- [ ] Version number is updated (if using a version file)
- [ ] CHANGELOG.md is updated (if maintained)
- [ ] Git tag is created and pushed
- [ ] GitHub release is created (optional)
- [ ] Plugin works with latest Neovim version

## Continuous Integration (TODO)

Consider setting up GitHub Actions for automated testing:

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: neovim/setup-neovim@v1
        with:
          version: stable
      - name: Install dependencies
        run: |
          git clone https://github.com/nvim-lua/plenary.nvim.git ~/.local/share/nvim/site/pack/test/opt/plenary.nvim
      - name: Run tests
        run: make test-manual
```

## Troubleshooting

### Plugin not loading

- Check `:messages` for errors
- Verify runtimepath includes plugin: `:echo &runtimepath`
- Check plugin file exists: `:echo globpath(&rtp, 'plugin/code-awareness.vim')`

### Tests failing

- Ensure plenary.nvim is installed
- Check minimal_init.lua paths are correct
- Run with verbose output: `nvim --headless -c "lua require('plenary.test_harness').test_directory('tests/')"`

### Publishing issues

- Verify GitHub repository is public (or user has access)
- Check tag format matches semantic versioning
- Ensure all files are committed and pushed

