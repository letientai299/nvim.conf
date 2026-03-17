--- Shared async command runner for backends.
---@param cmd string[]
---@param opts? vim.SystemOpts
---@param callback fun(ok: boolean, err?: string)
return function(cmd, opts, callback)
  if callback == nil then
    callback = opts
    opts = {}
  end
  vim.system(cmd, opts or {}, function(result)
    if result.code == 0 then
      callback(true)
    else
      callback(false, result.stderr or ("exit " .. result.code))
    end
  end)
end
