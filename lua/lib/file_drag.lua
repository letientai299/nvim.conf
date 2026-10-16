local M = {}

function M.start()
  if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
    vim.notify("File dragging requires a local session", vim.log.levels.WARN)
    return
  end
  local path = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= "" or vim.fn.filereadable(path) == 0 then
    vim.notify("Current buffer has no readable file", vim.log.levels.WARN)
    return
  end
  if vim.bo.modified then
    vim.notify("Save changes before dragging the file", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable("kitty") == 0 or vim.fn.executable("kitten") == 0 then
    vim.notify("File dragging requires Kitty and kitten", vim.log.levels.WARN)
    return
  end

  -- Never expose the original to move operations.
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p", 448)
  local copy = directory .. "/" .. vim.fs.basename(path)
  local copied, err = vim.uv.fs_copyfile(path, copy)
  if not copied then
    vim.fn.delete(directory, "rf")
    vim.notify("File copy failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  -- Uploads may read after the drag finishes.
  -- Neovim removes its temporary directory on exit.
  local launched, launch_error = pcall(vim.system, {
    "kitty",
    "--config",
    "NONE",
    "--title",
    "Drag file copy to upload",
    "--override",
    "initial_window_width=640",
    "--override",
    "initial_window_height=360",
    "--override",
    "remember_window_size=no",
    "--override",
    "macos_quit_when_last_window_closed=yes",
    vim.fn.exepath("kitten"),
    "dnd",
    "--exit-on=drag-finish,esc-key",
    "--drop=text/plain",
    "--drop=text/uri-list",
    "--",
    copy,
  }, { text = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify(
          "File drag failed: " .. vim.trim(result.stderr),
          vim.log.levels.ERROR
        )
      end)
    end
  end)
  if not launched then
    vim.fn.delete(directory, "rf")
    vim.notify(
      "File drag failed: " .. tostring(launch_error),
      vim.log.levels.ERROR
    )
  end
end

return M
