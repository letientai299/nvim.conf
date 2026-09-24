local M = {}

local function config_words(text)
  local words, word, quote = {}, "", nil
  for char in text:gmatch(".") do
    if quote then
      if char == quote then
        quote = nil
      else
        word = word .. char
      end
    elseif char == '"' or char == "'" then
      quote = char
    elseif char == "#" then
      break
    elseif char:match("%s") then
      if word ~= "" then
        words[#words + 1], word = word, ""
      end
    else
      word = word .. char
    end
  end
  if word ~= "" then
    words[#words + 1] = word
  end
  return words
end

local function read_hosts(file, base, hosts, seen)
  file = vim.uv.fs_realpath(file)
  if not file or seen[file] then
    return
  end
  seen[file] = true
  local ok, lines = pcall(vim.fn.readfile, file)
  if not ok then
    return
  end
  for _, line in ipairs(lines) do
    local key, value = line:match("^%s*(%a+)%s*=?%s*(.*)$")
    key = key and key:lower()
    if key == "host" or key == "include" then
      for _, word in ipairs(config_words(value)) do
        if key == "host" then
          if word:match("^[%w_][%w_.%-]*$") then
            hosts[word] = true
          end
        else
          local path = word:gsub("%${([%w_]+)}", function(name)
            return vim.env[name] or "${" .. name .. "}"
          end)
          if path:sub(1, 1) ~= "/" and path:sub(1, 1) ~= "~" then
            path = base .. "/" .. path
          end
          for _, included in ipairs(vim.fn.glob(path, false, true)) do
            read_hosts(included, base, hosts, seen)
          end
        end
      end
    end
  end
end

function M.complete(lead, line, pos)
  local args = line:sub(1, pos):match("^%s*Ssh%s+(.*)$") or ""
  if args:match("%S+%s") then
    return {}
  end
  local hosts, seen = {}, {}
  local base = vim.fn.expand("~/.ssh")
  read_hosts(base .. "/config", base, hosts, seen)
  read_hosts("/etc/ssh/ssh_config", "/etc/ssh", hosts, seen)
  local user = lead:match("^([^@]+@)") or ""
  local matches = {}
  for host in pairs(hosts) do
    local candidate = user .. host
    if vim.startswith(candidate, lead) then
      matches[#matches + 1] = candidate
    end
  end
  table.sort(matches)
  return matches
end

function M.status()
  local name = vim.api.nvim_buf_get_name(0)
  local host = name:match("^oil%-ssh://([^/]+)/")
  return host and ("SSH " .. host):gsub("%%", "%%%%") or ""
end

function M.directory()
  local name = vim.api.nvim_buf_get_name(0)
  local path = name:match("^oil%-ssh://[^/]+/(.*)$")
  if path then
    if path:sub(1, 1) ~= "/" then
      path = "~/" .. path
    end
  else
    path = vim.fn.fnamemodify(require("oil").get_current_dir() or "", ":~")
  end
  return (path:gsub("%%", "%%%%"))
end

function M.open(args)
  local host, path = args[1], args[2] or ""
  if #args > 2 or not host or not host:match("^[%w_][%w_.@:%-]*$") then
    vim.notify("Usage: Ssh [user@]host[:port] [path]", vim.log.levels.ERROR)
    return
  end
  if path == "~" then
    path = ""
  else
    path = path:gsub("^~/", "")
  end
  local url = "oil-ssh://" .. host .. "/" .. path
  local win = vim.api.nvim_get_current_win()
  -- Leave LazyLoad before triggering Oil's BufReadCmd.
  require("lib.lazy_ondemand").on_load(
    "oil.nvim",
    vim.schedule_wrap(function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_call(win, function()
          require("oil").open(url)
        end)
      end
    end)
  )
  require("lazy").load({ plugins = { "oil.nvim" } })
end

return M
