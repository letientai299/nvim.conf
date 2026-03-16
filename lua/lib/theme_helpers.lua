local M = {}

local function copy_value(value)
  if type(value) == "table" then
    return vim.deepcopy(value)
  end

  return value
end

local function apply_init_globals(spec)
  if spec._theme_init_globals_wrapped or type(spec.init_globals) ~= "table" then
    return spec
  end

  spec._theme_init_globals_wrapped = true

  local init_globals = spec.init_globals
  spec.init_globals = nil
  local user_init = spec.init
  spec.init = function(...)
    for name, value in pairs(init_globals) do
      if vim.g[name] == nil then
        vim.g[name] = copy_value(value)
      end
    end

    if user_init then
      return user_init(...)
    end
  end

  return spec
end

function M.prepare_specs(specs)
  for _, spec in ipairs(specs) do
    apply_init_globals(spec)
  end

  return specs
end

return M
