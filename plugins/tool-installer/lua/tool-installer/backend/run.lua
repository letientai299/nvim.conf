--- Shared async command runner for backends.
---@param cmd string[]
---@param callback fun(ok: boolean, err?: string)
return function(cmd, callback)
  vim.system(cmd, {}, function(result)
    if result.code == 0 then
      callback(true)
    else
      callback(false, result.stderr or ("exit " .. result.code))
    end
  end)
end
