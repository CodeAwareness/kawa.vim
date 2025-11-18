.PHONY: help format lint test clean link-test unlink-test test-manual

help:
	@echo "Available targets:"
	@echo "  format      - Format Lua files with stylua"
	@echo "  lint        - Lint Lua files with luacheck"
	@echo "  test        - Run tests with plenary.nvim"
	@echo "  test-manual - Open Neovim with test config for manual testing"
	@echo "  link-test   - Create symlink for local testing"
	@echo "  unlink-test - Remove symlink for local testing"
	@echo "  clean       - Remove generated files"

format:
	@command -v stylua >/dev/null 2>&1 || { echo "stylua not found. Install with: cargo install stylua"; exit 1; }
	stylua lua/ tests/

lint:
	@command -v luacheck >/dev/null 2>&1 || { echo "luacheck not found. Install with: luarocks install luacheck"; exit 1; }
	luacheck lua/ tests/

test:
	@nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

test-manual:
	@mkdir -p ~/.config/nvim-test
	@echo "vim.opt.runtimepath:prepend('$(shell pwd)')" > ~/.config/nvim-test/init.lua
	@echo "require('code-awareness').setup({ debug = true })" >> ~/.config/nvim-test/init.lua
	@echo "Created test config at ~/.config/nvim-test/init.lua"
	@echo "Run: nvim -u ~/.config/nvim-test/init.lua"

link-test:
	@mkdir -p ~/.local/share/nvim/site/pack/test/start
	@ln -sf $(shell pwd) ~/.local/share/nvim/site/pack/test/start/kawa.vim
	@echo "Symlink created. Restart Neovim to test."

unlink-test:
	@rm -f ~/.local/share/nvim/site/pack/test/start/kawa.vim
	@echo "Symlink removed."

clean:
	find . -name "*.luac" -delete
	rm -rf .tests/
	rm -f doc/tags
