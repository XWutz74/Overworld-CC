-- Overworld-CC - saves settings, games, characters and scores as files.
local St = { dir = "overworld-save" }

function St.init(dir) St.dir = dir end

local function path(k) return fs.combine(St.dir, k .. ".dat") end

function St.get(k, default)
  local p = path(k)
  if not fs.exists(p) then return default end
  local h = fs.open(p, "r")
  if not h then return default end
  local s = h.readAll()
  h.close()
  local v = textutils.unserialize(s or "")
  if v == nil then return default end
  return v
end

function St.set(k, v)
  if not fs.exists(St.dir) then fs.makeDir(St.dir) end
  local p, tmp = path(k), path(k) .. ".tmp"
  local h = fs.open(tmp, "w")
  if not h then return false end
  h.write(textutils.serialize(v))
  h.close()
  if fs.exists(p) then fs.delete(p) end
  fs.move(tmp, p)
  return true
end

function St.del(k)
  if fs.exists(path(k)) then fs.delete(path(k)) end
end

return St
