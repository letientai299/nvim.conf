DEPS_DIR := .tests/deps
DATA_DIR := .tests/data
MINI_DIR := $(DEPS_DIR)/mini.nvim
TEST_FILES := $(wildcard tests/test_*.lua)

# Clone mini.nvim if missing
$(MINI_DIR):
	@mkdir -p $(DEPS_DIR)
	git clone --depth 1 https://github.com/echasnovski/mini.nvim $@

# Install plugins into cached data dir (skip if already populated)
deps: $(MINI_DIR)
	@nvim --headless -i NONE -u tests/init.lua \
		-c "luafile tests/install.lua" -c quitall

# Run all test files in parallel (each file in its own nvim process)
test: deps
	@pids=""; fail=0; \
	for f in $(TEST_FILES); do \
		nvim --headless -i NONE -u tests/init.lua \
			-c "lua MiniTest.run_file('$$f')" -c quitall & \
		pids="$$pids $$!"; \
	done; \
	for p in $$pids; do wait $$p || fail=1; done; \
	exit $$fail

# Run a single test file: make test-one F=tests/test_startup.lua
test-one: deps
	nvim --headless -u tests/init.lua \
		-c "lua MiniTest.run_file('$(F)')" -c quitall

clean:
	rm -rf .tests/deps .tests/data

.PHONY: test test-one deps clean
