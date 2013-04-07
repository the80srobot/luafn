local F = require("core")
local M = {}

local function fibonacci()
  local function _fib(step)
    local function f()
      local x = step[1]
      local y = step[2]
      local z = {y, x + y}
      
      return F.cons(x, _fib(z))
    end
    
    return F.lazy(f)
  end
  
  return _fib({0, 1})
end

M.fibonacci = fibonacci

local function naturals()
  return F.iterate(F.inc, 1)
end

M.naturals = naturals

return M
