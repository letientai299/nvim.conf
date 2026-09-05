return {
  "L3MON4D3/LuaSnip",
  lazy = true,
  cmd = "FzfSnippets",
  version = "v2.*",
  build = "make install_jsregexp",
  dependencies = {
    "rafamadriz/friendly-snippets",
  },
  config = function()
    require("luasnip.loaders.from_vscode").lazy_load({
      include = {
        "go",
        "cs",
        "java",
        "javascript",
        "typescript",
        "javascriptreact",
        "typescriptreact",
        "markdown",
        "shellscript",
        "json",
        "yaml",
        "toml",
        "rust",
        "lua",
        "python",
        "html",
        "css",
        "sql",
      },
    })
    require("luasnip.loaders.from_vscode").lazy_load({
      paths = { vim.fn.stdpath("config") .. "/snippets" },
    })
    require("luasnip.loaders.from_lua").lazy_load({
      paths = { vim.fn.stdpath("config") .. "/lua/snippets" },
    })
    require("luasnip").filetype_extend("mdx", { "markdown" })

    vim.api.nvim_create_user_command("FzfSnippets", function()
      local luasnip = require("luasnip")
      local snippets = {}

      for ft, available in
        pairs(luasnip.available(function(snippet)
          return snippet
        end))
      do
        for _, snippet in ipairs(available) do
          snippets[#snippets + 1] = { ft = ft, snippet = snippet }
        end
      end

      table.sort(snippets, function(a, b)
        local a_key = a.snippet.trigger .. "\0" .. a.ft
        local b_key = b.snippet.trigger .. "\0" .. b.ft
        return a_key < b_key
      end)

      if #snippets == 0 then
        vim.notify("No snippets for this buffer", vim.log.levels.INFO)
        return
      end

      local function get_description(snippet)
        local description = snippet.description
        if type(description) == "table" then
          description = table.concat(description, " ")
        end
        local normalized =
          tostring(description or snippet.name or ""):gsub("%s+", " ")
        return normalized
      end

      local function snippet_json(entry)
        local snippet = entry.snippet
        local body = snippet:get_docstring()
        if type(body) == "string" then
          body = vim.split(body, "\n", { plain = true })
        end
        local lines = {
          "{",
          "  " .. vim.json.encode(snippet.name) .. ": {",
          '    "prefix": ' .. vim.json.encode(snippet.trigger) .. ",",
          '    "body": [',
        }
        for index, line in ipairs(body) do
          local comma = index < #body and "," or ""
          lines[#lines + 1] = "      " .. vim.json.encode(line) .. comma
        end
        vim.list_extend(lines, {
          "    ],",
          '    "description": '
            .. vim.json.encode(get_description(snippet))
            .. ",",
          '    "scope": ' .. vim.json.encode(entry.ft),
          "  }",
          "}",
        })
        return table.concat(lines, "\n")
      end

      local function format_entry(entry, colors)
        local trigger = string.format("%-20s", entry.snippet.trigger:sub(1, 20))
        local description =
          string.format("%-40s", get_description(entry.snippet):sub(1, 40))
        local filetype = entry.ft
        if colors then
          trigger = colors.magenta(trigger)
          filetype = colors.blue(filetype)
        end
        return table.concat({ trigger, description, filetype }, " │ ")
      end

      local function open_picker()
        local fzf = require("fzf-lua")
        local items = {
          "0\t"
            .. format_entry({
              ft = "filetype",
              snippet = { trigger = "trigger", description = "description" },
            }),
        }
        for index, entry in ipairs(snippets) do
          items[#items + 1] = index
            .. "\t"
            .. format_entry(entry, fzf.utils.ansi_codes)
        end

        fzf.fzf_exec(items, {
          prompt = "Snippets> ",
          preview = function(args)
            local index = tonumber((args[1] or ""):match("^(%d+)\t"))
            return index and snippet_json(snippets[index]) or ""
          end,
          fzf_opts = {
            ["--ansi"] = true,
            ["--delimiter"] = "\t",
            ["--header-lines"] = "1",
            ["--with-nth"] = "2..",
          },
          actions = {
            ["default"] = function(selected)
              local index = tonumber((selected[1] or ""):match("^(%d+)\t"))
              if index then
                luasnip.snip_expand(snippets[index].snippet)
              end
            end,
          },
        })
      end

      local ondemand = require("lib.lazy_ondemand")
      ondemand.on_load("fzf-lua", open_picker)
      require("lazy").load({ plugins = { "fzf-lua" } })
    end, { desc = "Search snippets with fzf-lua" })
  end,
}
