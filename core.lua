local M = {}

-- NUMBERS LIBRARY

local function inc(n)
  return n + 1
end

M.inc = inc

local function dec(n)
  return n - 1
end

M.dec = dec

-- FUNCTION LIBRARY

-- Returns a function that returns NOT f(...).
local function complement(f)
  return function(...) return not f(unpack({...})) end
end

M.complement = complement

local function identity(...)
  return ...
end

M.identity = identity

local function constantly(...)
  local constant = {...}
  return function(...) return unpack(constant) end
end

M.constantly = constantly

-- Takes f, which is a function with no parameters and free of side-effects.
-- Returns a function that calls f once, caches the result, and returns it
-- on subsequent calls.
local function cache(f)
  local empty_sentinel = function() return nil end
  local cache = empty_sentinel
  
  local function memoized()
    if cache == empty_sentinel then
      cache = f()
    end
    
    return cache
  end
  
  return memoized
end

M.cache = cache

-- SEQ CORE

local empty = setmetatable({}, {__meta = {_type = "empty", _isseq = false}})

-- EXPORT
local function kind(coll, ...)
  local mt = getmetatable(coll)
  if mt and mt["__meta"] then
    return mt["__meta"]["_type"]
  end
  
  local k = type(coll)
  local args = {...}
  if k == "function" and args[1] and args[2] then
    return "iterator"
  end
  
  return k
end

M.kind = kind

local function isseq(...)
  local k = kind(...)
  return k == "lazy" or k == "cons"
end

M.isseq = isseq

local function isiter(...)
  return kind(...) == "iterator"
end

M.isiter = isiter

local function iscoll(coll)
  return type(coll) == "table"
end

M.iscoll = iscoll

local function istable(...)
  return kind(...) == "table"
end

M.istable = istable

local function islazy(...)
  return kind(...) == "lazy"
end

M.islazy = islazy

local function isempty(coll, ...)
  if coll == empty or coll == nil then return true end
  
  local k = kind(coll, ...)
  if k == "table" and #k == 0 then return true end
  if k == "lazy" and coll[1] == nil then return true end
  
  return false
end

M.isempty = isempty

local notempty = complement(isempty)

M.notempty = notempty

-- Takes an x, which is any value, and seq, which is an existing cons sequence.
-- Returns a cons sequence where the first element is x, 2nd element is the 1st element of seq, and so on.
--
-- A cons sequence is essentially a singly-linked list, defined recursively.
local function cons(x, seq)
  if not isseq(seq) and seq ~= nil then
    error("2nd parameter to cons must be a sequence. Did you mean to use conj?")
  end
  
  return setmetatable({}, {
    __index = function(t, idx)
      if idx == 1 then
        return x
      end
      
      if seq == nil then
        return nil
      end
      
      -- The following loop is logically equivalent to a recursive call to seq[idx - 1],
      -- which would blow the stack in combination with a lazy sequence by creating
      -- trampoline recursion, which would make it impossible for Lua to reuse stack frame.
      -- The loop also happens to be faster than the recursion.
      local s = seq
      for i = idx - 2, 1, -1 do
        if isempty(s) then return nil end
        s = getmetatable(s)["__meta"]["_rest"]()
      end
      
      return s[1]
    end,
    
    __meta = {_type = "cons", _isseq = true, _rest = function() return seq end}
  })
end

M.cons = cons

-- Appends element x to coll in the most efficient manner possible.
-- For sequences (including lazy seqs) this is equivalent to cons.
-- For tables, x will be inserted at #coll + 1 - this will mutate the
-- table. (There is no copy-on-write).
local function conj(x, coll)
  if isseq(coll) then
    return cons(x, coll)
  elseif istable(coll) then
    coll[#coll + 1] = x
    return coll
  else
    error("conj currently only works with tables and sequences.")
  end
end

M.conj = conj

local function first(coll)
  if coll then return coll[1] end
end

M.first = first

local function second(coll)
  if coll then return coll[2] end
end

M.second = second

local function rest(seq)
  if isempty(seq) then
    return empty
  elseif not isseq(seq) then
    error("rest must be called with a sequence. You could use drop(1, coll) instead.")
  end
  
  local r = getmetatable(seq)["__meta"]["_rest"]()
  if r == nil then return empty end
  
  return r
end

M.rest = rest

-- Returns a lazy sequence, which is a sequence that will be realized by calling
-- +expr+ with no parameters, as soon as any element from it is requested.
-- +expr+ may include additional recursive calls to a function that returns expr,
-- which will be realized in sequence, as the lazy seq is assembled using semantics
-- similar to cons. Results of each call to expr are cached.
local function lazy(f)
  local cf = cache(f)
  
  return setmetatable({}, {
    __index = function(t, idx)
      local seq = cf()
      if seq ~= nil then return seq[idx] end
    end,
    
    __meta = {_type = "lazy", isseq = true, _rest = function() return rest(cf()) end}
  })
end

M.lazy = lazy

-- PRIVATE
local function seqmap(f, seq)
  local function mapping()
    local x = first(seq)
    local s = rest(seq)
    
    if x then return cons(f(x), seqmap(f, s)) end
  end
  
  return lazy(mapping)
end

-- Creates a lazy sequence from the output of Lua iterator factories.
-- The parameters are what's returned by pairs/ipairs:
-- iter: the stateless iterator function
-- invar: the invariant state input
-- lastx: the last index returned by the iter
--
-- PRIVATE
local function iterator2kvseq(iter, invar, lastx)
  local function step()
    x, y = iter(invar, lastx)
    
    if x then return cons({x, y}, iterator2kvseq(iter, invar, x)) end
  end
  
  return lazy(step)
end

local function iterator2table(iter, invar, lastx)
  local t = {}
  for i, v in iter, invar, lastx do
    t[i] = v
  end
  
  return t
end

-- PRIVATE
local function iterator2seq(...)
  return seqmap(second, iterator2kvseq(...))
end

-- PRIVATE
local function seq2iterator(seq)
  local function iterate(id, state)
    local x = first(state)
    
    if isempty(state) or x == nil then return nil, x end
    
    return rest(state), first(state)
  end
  
  return iterate, seq, seq
end

local function seq(coll, ...)
  local k = kind(coll)
  
  if k == "lazy" or k == "cons" then
    return coll
  elseif k == "function" then
    return iterator2seq(coll, ...)
  elseif k == "table" then
    return iterator2seq(ipairs(coll))
  else
    return cons(coll, nil)
  end
end

M.seq = seq

local function iterator(coll, ...)
  local k = kind(coll, ...)
  
  if k == "iterator" then
    return coll, ...
  elseif k == "cons" or k == "lazy" then
    return seq2iterator(coll)
  else
    return ipairs(coll)
  end
end

M.iterator = iterator

local function table(...)
  if istable(...) then return ... end
  
  return iterator2table(iterator(...))
end

M.table = table

local function apply(f, args)
  return f(unpack(table(args)))
end

M.apply = apply

local function concat(...)
  
  -- concat2 implements the special case of two seq parameters.
  -- Other cases are implemented by (possibly repeated) calls to
  -- concat2.
  local function concat2(s1, s2)
    local function gen()
      if not isempty(s1) then
        return cons(first(s1), concat2(rest(s1), s2))
      else
        return s2
      end
    end

    return lazy(gen)
  end
  
  local arg = {...}
  local n = #arg
  
  if n == 0 then
    return nil
  elseif n == 1 then
    return arg[1]
  elseif n == 2 then
    return concat2(seq(arg[1]), seq(arg[2]))
  else
    local function f()
      return concat(concat2(seq(arg[1]), seq(arg[2])), unpack(arg, 3))
    end
    
    return lazy(f)
  end
end

M.concat = concat

local function map(f, coll)
  return seqmap(f, seq(coll))
end

M.map = map

local function filter(f, coll)
  local seq = seq(coll)
  
  local function filtering()
    local x
    local s = seq
    
    repeat
      s = rest(s)
      x = first(s)
    until (x == nil or f(x))
    
    if x then return cons(x, filter(f, s)) end
  end
  
  return lazy(filtering)
end

M.filter = filter

local function remove(f, coll)
  return filter(complement(f), coll)
end

M.remove = remove

local function list(...)
  local args = {...}
  local s
  
  for i = #args, 1, -1 do
    s = cons(args[i], s)
  end
  
  return s
end

M.list = list

local function itreduce(f, init, iter, invar, state)
  local val = init
  local stop = false
  
  local function stopf()
    stop = true
  end
  
  for idx, x in iter, invar, state do
    val = f(val, x, stopf)
    if stop then break end
  end
  
  return val
end

local function reduce(f, init, coll)
  return itreduce(f, init, iterator(coll))
end

M.reduce = reduce

local function each(f, coll)
  for s, x in iterator(coll) do
    f(x)
  end
end

M.each = each

local function iterate(f, x)
  local function iter()
    return iterate(f, f(x))
  end
  
  return cons(x, lazy(iter))
end

M.iterate = iterate

local function repeatedly(f)
  local function iter()
    return cons(f(), repeatedly(f))
  end
  
  return lazy(iter)
end

M.repeatedly = repeatedly

local function take(n, coll)
  local function seqtake(n, seq)
    local function gen()
      if n ~= 0 then
        return cons(first(seq), seqtake(n - 1, rest(seq)))
      end
    end
    
    return lazy(gen)
  end
  
  return seqtake(n, seq(coll))
end

M.take = take

local function drop(n, coll)
  local function seqdrop(n, seq)
    local function step(n, seq)
      if n == 0 then
        return seq
      else
        return step(n - 1, rest(seq))
      end
    end
    
    return lazy(function() return step(n, seq) end)
  end
  
  return seqdrop(n, seq(coll))
end

M.drop = drop

local function next(coll)
  if isseq(coll) then
    return rest(coll)
  else
    return drop(1, coll)
  end
end

M.next = next

local function count(coll)
  if istable(coll) then return #coll end
  
  local function counter(n, x)
    return n + 1
  end
  
  return reduce(counter, 0, coll)
end

M.count = count

local function every(pred, coll)
  if isempty(coll) then
    return true
  elseif pred(first(coll)) then
    return every(pred, next(coll))
  else
    return false
  end
end

M.every = every

local function interleave(...)
  -- interleave2 implements the special case of two seq
  -- parameters. Other cases are implemented using map.
  local function interleave2(s1, s2)
    local function gen()
      if notempty(s1) and notempty(s2) then
        return cons(first(s1), cons(first(s2), interleave2(rest(s1), rest(s2))))
      end
    end
    
    return lazy(gen)
  end
  
  -- interleaven implements the general case of
  -- N seq parameters.
  local function interleaven(seqs)
    local function gen()
      if every(notempty, seqs) then
        return concat(map(first, seqs), interleaven(map(rest, seqs)))
      end
    end
    
    return lazy(gen)
  end
  
  local colls = {...}
  if #colls == 2 then
    return interleave2(seq(colls[1]), seq(colls[2]))
  else
    return interleaven(map(seq, colls))
  end
end

M.interleave = interleave

local function interpose(separator, coll)
  local sepseq = repeatedly(constantly(separator))
  return drop(1, interleave(sepseq, coll))
end

M.interpose = interpose

local function partition(n, coll)
  local function p()
    local step = take(n, coll)
    if step then return cons(step, partition(n, drop(n, coll))) end
  end
  
  return lazy(p)
end

M.partition = partition

return M
