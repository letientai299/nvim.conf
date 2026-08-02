-- Run: busted lua/lib/doxygen_spec.lua
package.path = "lua/?.lua;" .. package.path

-- Minimal vim shim: to_markdown/clean_input only use vim.split and vim.islist.
_G.vim = _G.vim
  or {
    split = function(s, sep, _)
      local out, i = {}, 1
      while true do
        local j = string.find(s, sep, i, true)
        if not j then
          out[#out + 1] = s:sub(i)
          break
        end
        out[#out + 1] = s:sub(i, j - 1)
        i = j + #sep
      end
      return out
    end,
    islist = function(t)
      if type(t) ~= "table" then
        return false
      end
      local n = 0
      for _ in pairs(t) do
        n = n + 1
      end
      return n == #t
    end,
    deepcopy = function(t)
      local c = {}
      for k, v in pairs(t) do
        c[k] = v
      end
      return c
    end,
  }

local doxy = require("lib.doxygen")

-- Each case = { input, expected, [desc] }.
local function run_cases(cases)
  for _, c in ipairs(cases) do
    local input, expected, desc = c[1], c[2], c[3] or c[1]
    it(desc, function()
      assert.are.equal(expected, doxy.to_markdown(input))
    end)
  end
end

describe("to_markdown", function()
  describe("no-op fast path", function()
    run_cases({
      { "plain text with no doxygen", "plain text with no doxygen" },
      { "code `std::vector<int>` inline", "code `std::vector<int>` inline", "keeps qualified names" },
      { "", "" },
    })
  end)

  describe("section commands", function()
    run_cases({
      { "\\\\brief Wait for the device", "Wait for the device", "brief -> bare text" },
      { "\\\\return zero on success", "**Returns:** zero on success" },
      { "\\\\note be careful", "**Note:** be careful" },
      { "\\\\warning danger", "**Warning:** danger" },
      { "\\\\sa other_fn", "**See also:** other_fn" },
    })
  end)

  describe("scope auto-links", function()
    run_cases({
      { "::cudaSuccess at start", "`cudaSuccess` at start" },
      { "returns ::cudaSuccess here", "returns `cudaSuccess` here" },
      { "std::vector stays", "std::vector stays", "non-leading :: untouched" },
    })
  end)

  describe("params and inline faces", function()
    run_cases({
      { "\\\\param[in] count items", "**Param** `count` — items" },
      { "use \\\\p buffer now", "use `buffer` now" },
      { "the \\\\b important bit", "the **important** bit" },
    })
  end)

  describe("unknown aliases", function()
    it("drops a line that is only an unknown alias", function()
      assert.are.equal("", doxy.to_markdown("\\\\notefnerr"))
    end)
    it("strips unknown alias but keeps a real line", function()
      assert.are.equal("text", doxy.to_markdown("\\\\note_init_rt text"))
    end)
  end)

  describe("code fences pass through", function()
    it("does not rewrite :: inside a fence", function()
      local input = "text ::foo\n```cpp\nstd::sync ::bar\n```"
      local expected = "text `foo`\n```cpp\nstd::sync ::bar\n```"
      assert.are.equal(expected, doxy.to_markdown(input))
    end)
  end)

  describe("full CUDA hover sample", function()
    it("renders cudaDeviceSynchronize docs", function()
      local input = table.concat({
        "\\\\brief Wait for compute device to finish",
        "\\\\return ::cudaSuccess,",
        "::cudaErrorStreamCaptureUnsupported",
        "\\\\notefnerr",
        "\\\\sa ::cudaDeviceReset,",
        "::cuCtxSynchronize",
      }, "\n")
      local out = doxy.to_markdown(input)
      assert.is_truthy(out:find("Wait for compute device to finish", 1, true))
      assert.is_truthy(out:find("**Returns:** `cudaSuccess`", 1, true))
      assert.is_truthy(out:find("`cudaErrorStreamCaptureUnsupported`", 1, true))
      assert.is_truthy(out:find("**See also:** `cudaDeviceReset`", 1, true))
      assert.is_truthy(out:find("`cuCtxSynchronize`", 1, true))
      assert.is_nil(out:find("notefnerr", 1, true))
      assert.is_nil(out:find("\\", 1, true))
    end)
  end)
end)
