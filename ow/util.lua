-- Overworld-CC - small helpers shared by every module.
local U = {}

function U.rnd(a, b) return a + math.random() * (b - a) end
function U.irnd(a, b) return math.floor(U.rnd(a, b + 1)) end
function U.clamp(v, a, b) return math.max(a, math.min(b, v)) end
function U.pick(list) return list[math.random(#list)] end
-- Same as JavaScript's Math.round.
function U.round(v) return math.floor(v + 0.5) end

function U.find(list, id)
  for _, x in ipairs(list) do if x.id == id then return x end end
end

function U.filter(list, fn)
  local r = {}
  for _, x in ipairs(list) do if fn(x) then r[#r + 1] = x end end
  return r
end

function U.map(list, fn)
  local r = {}
  for i, x in ipairs(list) do r[i] = fn(x, i) end
  return r
end

function U.indexOf(list, v)
  for i, x in ipairs(list) do if x == v then return i end end
end

function U.remove(list, v)
  local i = U.indexOf(list, v)
  if i then table.remove(list, i) end
end

function U.copy(v)
  if type(v) ~= "table" then return v end
  local r = {}
  for k, x in pairs(v) do r[k] = U.copy(x) end
  return r
end

function U.keys(t)
  local r = {}
  for k in pairs(t) do r[#r + 1] = k end
  table.sort(r)
  return r
end

return U
