local F = require("core")
local M = {}

local function mapping(f)
  local function step(a, pair)
    a[pair[1]] = f(a[pair[2]])
    return a
  end
  
  return step
end

local function filtering(f)
  local function step(a, pair)
    if f(pair[2]) then
      local idx = a[1] + 1
      local res = a[2]
      res[idx] = pair[2]
    
      return {idx, res}
    end
  
    return a
  end
  
  return step
end

local function kvpairs(hash)
  return F.iterator2seq(pairs(hash))
end

local function keys(hash)
  return F.map(first, kvpairs(hash))
end

M.keys = keys

local function values(hash)
  return F.map(second, kvpairs(hash))
end

M.values = values

local function kvreduce(f, hash)
  return F.itreduce(f, init, pairs(hash))
end

M.kvreduce = kvreduce

local function kvmap(f, t)
  local stepf = mapping(f)
  return F.itreduce(stepf, {}, pairs(t))
end

M.kvmap = kvmap

local function kvfilter(f, t)
  local stepf = filtering(f)
  return F.itreduce(stepf, {}, pairs(t))[2]
end

M.kvfilter = kvfilter

local function amap(f, t)
  local stepf = mapping(f)
  return F.itreduce(stepf, {}, ipairs(t))
end

M.amap = amap

local function afilter(f, t)
  local stepf = filtering(f)
  return F.itreduce(stepf, {0, {}}, ipairs(t))[2]
end

M.afilter = afilter

return M
