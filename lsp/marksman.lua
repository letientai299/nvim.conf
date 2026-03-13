-- Marksman skips gitignored directories when indexing, so links between
-- files in e.g. .ai.dump/ produce "Link to non-existent document" even
-- when the target file exists on disk. Verify before forwarding.
-- https://github.com/artempyanykh/marksman/blob/main/docs/features.md

local function link_exists_on_disk(dir, target)
  local path = vim.fs.joinpath(dir, target)
  return vim.uv.fs_stat(path) or vim.uv.fs_stat(path .. ".md")
end

local function filter_false_link_diags(result)
  local dir = vim.fs.dirname(vim.uri_to_fname(result.uri))
  result.diagnostics = vim.tbl_filter(function(d)
    local target = d.message:match("Link to non%-existent document '(.+)'")
    return not target or not link_exists_on_disk(dir, target)
  end, result.diagnostics)
end

return {
  cmd = { "marksman" },
  filetypes = { "markdown", "markdown.mdx" },
  root_markers = { ".marksman.toml", ".git" },
  handlers = {
    ["textDocument/publishDiagnostics"] = function(err, result, ctx)
      filter_false_link_diags(result)
      vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
    end,
  },
}
