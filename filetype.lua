--- True for dotenv filenames. `.envrc` is direnv (shell), not dotenv.
local function is_dotenv_name(path)
  local name = vim.fs.basename(path)
  if name == ".envrc" or name:match("^%.envrc%.") then
    return false
  end
  return name == ".env" or name:match("%.env$") or name:match("^%.env%.")
end

vim.filetype.add({
  extension = {
    cshtml = "razor",
    env = "env",
    mdx = "mdx",
    log = "log",
    razor = "razor",
  },
  filename = {
    [".env"] = "env",
  },
  pattern = {
    -- `.env.local`, `.env.production`, `.env.example`, …
    ["^%.env%..+"] = "env",
  },
})

-- Modelines like `# vim: set ft=sh:` win over filename detection and pull in
-- bashls/shellcheck. Reclaim dotenv names so unused-variable noise stays off.
local dotenv_augroup =
  vim.api.nvim_create_augroup("DotenvFiletype", { clear = true })

local function set_dotenv_ft(buf)
  if
    is_dotenv_name(vim.api.nvim_buf_get_name(buf))
    and vim.bo[buf].filetype ~= "env"
  then
    vim.bo[buf].filetype = "env"
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = dotenv_augroup,
  pattern = { "sh", "bash", "zsh" },
  callback = function(ev)
    set_dotenv_ft(ev.buf)
  end,
})

-- Modelines run around BufReadPost; BufWinEnter is after that.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWinEnter" }, {
  group = dotenv_augroup,
  pattern = { "*.env", ".env", ".env.*" },
  callback = function(ev)
    set_dotenv_ft(ev.buf)
  end,
})
