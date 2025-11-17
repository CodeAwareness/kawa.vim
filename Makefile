.PHONY: help format lint test clean

help:
	@echo "Available targets:"
	@echo "  format  - Format Lua files with stylua"
	@echo "  lint    - Lint Lua files with luacheck"
	@echo "  test    - Run tests with plenary.nvim"
	@echo "  clean   - Remove generated files"

format:
	@command -v stylua >/dev/null 2>&1 || { echo "stylua not found. Install with: cargo install stylua"; exit 1; }
	stylua lua/ tests/

lint:
	@command -v luacheck >/dev/null 2>&1 || { echo "luacheck not found. Install with: luarocks install luacheck"; exit 1; }
	luacheck lua/ tests/

test:
	@nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

clean:
	find . -name "*.luac" -delete
	rm -rf .tests/
	rm -f doc/tags
