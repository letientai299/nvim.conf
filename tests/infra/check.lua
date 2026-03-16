--- Headless smoke test: verify treesitter highlighting and LSP diagnostics.
---
--- Designed to run after bootstrap in test containers:
---   nvim --headless -c "luafile tests/infra/check.lua" /tmp/check-target.bashrc
---
--- Exits 0 if treesitter parser loads and diagnostics appear within 30s.
--- Exits 1 with diagnostic output on failure.

local ok_all = true

local function check(label, timeout_ms, pred)
  local ok = vim.wait(timeout_ms, pred, 500)
  local status = ok and "OK" or "FAIL"
  io.write(string.format("  %-40s [%s]\n", label, status))
  if not ok then
    ok_all = false
  end
  return ok
end

io.write("smoke-test: running checks\n")

-- 1. Treesitter parser for bash
check("treesitter parser (bash)", 30000, function()
  local s, parser = pcall(vim.treesitter.get_parser, 0, "bash")
  return s and parser ~= nil
end)

-- 2. LSP diagnostics (shellcheck via bashls)
check("LSP diagnostics", 30000, function()
  return #vim.diagnostic.get(0) > 0
end)

-- 3. No error messages in :messages
local msgs = vim.api.nvim_exec2("messages", { output = true }).output or ""
local has_errors = msgs:match("E%d+:") or msgs:match("Error")
if has_errors then
  io.write("  nvim :messages contained errors:\n")
  for line in msgs:gmatch("[^\n]+") do
    if line:match("E%d+:") or line:match("Error") then
      io.write("    " .. line .. "\n")
    end
  end
  ok_all = false
else
  io.write(string.format("  %-40s [OK]\n", "no errors in :messages"))
end

io.write(string.format("smoke-test: %s\n", ok_all and "PASSED" or "FAILED"))
vim.cmd(ok_all and "qa!" or "cq!")
