local F = require("core")
local M = {}

local function join(separator, coll)
  local function joiner(acc, step)
    return acc .. separator .. step
  end
  
  return F.reduce(joiner, coll[1], F.next(coll))
end

M.join = join

local function str(coll)
  local function joiner(acc, step)
    return acc .. step
  end
  
  return F.reduce(joiner, coll[1], F.next(coll))
end

M.str = str

local function split(separator, str)
  local seplen = #separator - 1
  
  local function splitfrom(separator, str, start)
    local function step()
      local strend = string.find(str, separator, start, true)
      
      if strend then
        local sub = string.sub(str, start + seplen, strend - seplen - 1)
        return F.cons(sub, splitfrom(separator, str, strend + 1))
      else
        local sub = string.sub(str, start + seplen)
        return F.cons(sub, empty)
      end
    end
  
    return F.lazy(step)
  end
  
  return splitfrom(separator, str, 0)
end

M.split = split

return M
