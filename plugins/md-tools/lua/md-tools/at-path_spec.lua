-- Run: busted plugins/md-tools/lua/md-tools/at-path_spec.lua
package.path = "plugins/md-tools/lua/?.lua;" .. package.path

local wrap_line = require("md-tools.at-path").wrap_line

-- Helper: run table-driven cases. Each case = { input, expected, [desc] }.
local function run_cases(cases)
  for _, c in ipairs(cases) do
    local input, expected, desc = c[1], c[2], c[3] or c[1]
    it(desc, function()
      local result = wrap_line(input)
      assert.are.equal(expected, result)
    end)
  end
end

describe("wrap_line", function()
  describe("@ paths (always wrap)", function()
    run_cases({
      { "see @org/repo for details", "see `@org/repo` for details" },
      { "use @scope/pkg/file", "use `@scope/pkg/file`" },
      { "@a/b at start", "`@a/b` at start" },
      { "end @a/b", "end `@a/b`" },
    })
  end)

  describe("long bare paths (3+ segments, always wrap)", function()
    run_cases({
      { "see path/to/file here", "see `path/to/file` here" },
      { "open src/lib/utils.lua", "open `src/lib/utils.lua`" },
      { "a/b/c/d deep path", "`a/b/c/d` deep path" },
    })
  end)

  describe("URLs (never wrap)", function()
    run_cases({
      {
        "visit https://example.com/path/to",
        "visit https://example.com/path/to",
      },
      { "see http://foo.bar/baz/qux", "see http://foo.bar/baz/qux" },
      {
        "link https://github.com/user/repo/issues",
        "link https://github.com/user/repo/issues",
      },
      {
        "connect to host:8080/api/v1",
        "connect to host:8080/api/v1",
        "host:port URL",
      },
    })
  end)

  describe("markdown links (never wrap)", function()
    run_cases({
      { "[text](path/to/file)", "[text](path/to/file)" },
      { "[ref](../some/dir)", "[ref](../some/dir)" },
    })
  end)

  describe("already in backticks (never wrap)", function()
    run_cases({
      { "use `path/to/file` here", "use `path/to/file` here" },
      { "run `@scope/pkg`", "run `@scope/pkg`" },
    })
  end)

  describe("2-segment paths", function()
    describe("should NOT wrap (plain 2-segment, no special markers)", function()
      run_cases({
        { "use this/that style", "use this/that style", "plain a/b" },
        { "either yes/no works", "either yes/no works", "yes/no" },
        { "try foo/bar here", "try foo/bar here", "foo/bar" },
        { "input/output mapping", "input/output mapping", "input/output" },
      })
    end)

    describe("should wrap (dot prefix)", function()
      run_cases({
        { "see .dir/some here", "see `.dir/some` here", ".dir/some" },
        { "from ../dir next", "from `../dir` next", "../dir" },
        { "in ./local/path", "in `./local/path`", "./local/path" },
      })
    end)

    describe("should wrap (has file extension)", function()
      run_cases({
        { "edit dir/file.lua", "edit `dir/file.lua`", "dir/file.lua" },
        { "open src/main.rs", "open `src/main.rs`", "src/main.rs" },
        {
          "read config/settings.json",
          "read `config/settings.json`",
          "config/settings.json",
        },
      })
    end)

    describe("should wrap (@ prefix)", function()
      run_cases({
        { "install @scope/pkg", "install `@scope/pkg`", "@scope/pkg" },
      })
    end)
  end)
end)
