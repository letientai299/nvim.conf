local M = {}

local function run(args, command)
  return vim
    .system(
      vim.list_extend(vim.list_extend({ "tmux" }, args), command),
      { text = true }
    )
    :wait()
end

function M.discover(processes)
  for _, process in ipairs(processes or {}) do
    local argv = process.cmdline or {}
    if vim.fs.basename(argv[1] or "") == "tmux" then
      local args = {}
      for i = 2, #argv do
        if argv[i] == "-L" or argv[i] == "-S" then
          args = { argv[i], argv[i + 1] }
          break
        end
      end
      if vim.fn.executable("tmux") ~= 1 then
        return nil, "tmux executable unavailable"
      end
      local clients = run(
        args,
        { "list-clients", "-F", "#{client_pid}\t#{pane_id}\t#{client_name}" }
      )
      if clients.code ~= 0 then
        return nil, "tmux client discovery failed"
      end
      for pid, pane, client in clients.stdout:gmatch("(%d+)\t(%%%d+)\t([^\n]+)") do
        if tonumber(pid) == process.pid then
          local result = run(args, {
            "list-panes",
            "-t",
            pane,
            "-F",
            "#{pane_id}\t#{pane_index}\t#{pane_current_command}",
          })
          if result.code ~= 0 then
            return nil, "tmux pane discovery failed"
          end
          local panes = {}
          for id, index, command in
            result.stdout:gmatch("(%%%d+)\t(%d+)\t([^\n]*)")
          do
            panes[#panes + 1] = { id = id, label = index .. ": " .. command }
          end
          return { args = args, panes = panes, pane = pane, client = client }
        end
      end
      return nil, "Kitty tmux client unavailable locally"
    end
  end
end

function M.activate(target, id)
  local result = run(target.args, { "select-pane", "-t", id })
  if result.code ~= 0 then
    return false, "tmux pane selection failed"
  end
  return true
end

local sequence = 0

function M.pick(target)
  sequence = sequence + 1
  local option = "@kitty-send-" .. vim.fn.getpid() .. "-" .. sequence
  local commands = run(target.args, { "list-commands" })
  if commands.code ~= 0 then
    return nil, "tmux command discovery failed"
  end
  -- Tmux 3.8 targets panes instead of clients.
  local modern = commands.stdout:match("display%-panes[^\n]*target%-pane")
    ~= nil
  local result = run(target.args, {
    "display-panes",
    "-t",
    modern and target.pane or target.client,
    "-d",
    "10000",
    "set-option -g " .. option .. " '%%'",
  })
  if result.code ~= 0 then
    return nil, "tmux pane overlay failed"
  end
  local finished = true
  if modern then
    finished = vim.wait(11000, function()
      local mode = run(target.args, {
        "display-message",
        "-p",
        "-t",
        target.pane,
        "#{pane_mode}",
      })
      return mode.code ~= 0 or not mode.stdout:find("panes-mode", 1, true)
    end, 50)
  end
  local chosen = run(target.args, { "show-options", "-gqv", option })
  run(target.args, { "set-option", "-gu", option })
  if not finished then
    return nil, "tmux pane overlay timed out"
  end
  local id = chosen.stdout:match("^%%%d+")
  if id then
    return { id = id }
  end
end

return M
