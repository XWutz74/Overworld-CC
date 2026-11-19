-- Overworld-CC - languages, names and number formatting.
local T = { lang = "en", L = {}, codes = { "en", "de" }, names = { en = "English", de = "Deutsch" } }

-- ComputerCraft draws ISO-8859-1. CC:Tweaked for Minecraft 1.18.2 already turns
-- UTF-8 files into that; newer versions read the raw bytes. fix() turns any
-- UTF-8 that is left into single characters, so both look the same.
local PUNCT = { ["\226\128\158"] = '"', ["\226\128\156"] = '"', ["\226\128\157"] = '"',
  ["\226\128\152"] = "'", ["\226\128\153"] = "'", ["\226\128\147"] = "-", ["\226\128\148"] = "-",
  ["\226\136\146"] = "-", ["\226\128\166"] = "..." }
function T.fix(s)
  if not s:find("[\194-\226]") then return s end
  s = s:gsub("\226[\128-\191][\128-\191]", function(c) return PUNCT[c] end)
  return (s:gsub("([\194\195])([\128-\191])", function(a, b)
    return string.char((a:byte() - 192) * 64 + (b:byte() - 128))
  end))
end

function T.fixAll(v)
  if type(v) == "string" then return T.fix(v) end
  if type(v) == "table" then for k, x in pairs(v) do v[k] = T.fixAll(x) end end
  return v
end

local function loadLang(code)
  local ok, base = pcall(require, "ow.lang." .. code)
  if not ok then return nil end
  local L = {}
  for k, v in pairs(base) do L[k] = v end
  local ok2, extra = pcall(require, "ow.lang." .. code .. "_cc")
  if ok2 and type(extra) == "table" then for k, v in pairs(extra) do L[k] = v end end
  return T.fixAll(L)
end

for _, code in ipairs(T.codes) do T.L[code] = loadLang(code) end

function T.set(code) if T.L[code] then T.lang = code end end

function T.t(key, vars)
  local L = T.L[T.lang] or T.L.en
  local s = L[key]
  if s == nil then s = T.L.en[key] end
  if s == nil then return key end
  if vars then
    s = s:gsub("{(%w+)}", function(k)
      local v = vars[k]
      if v ~= nil then return tostring(v) end
    end)
  end
  return s
end

-- A name from the data files: { en = "...", de = "..." } or a plain string.
function T.nm(o)
  if type(o) == "table" then return o[T.lang] or o.en or "" end
  return o or ""
end

function T.int(v)
  local n = tostring(math.floor(math.abs(v) + 0.5))
  local sep = T.lang == "de" and "." or ","
  local r = n:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if r:sub(1, 1) == sep then r = r:sub(2) end
  return r
end

function T.money(v)
  return (v < 0 and math.floor(math.abs(v) + 0.5) > 0 and "-" or "") .. "$" .. T.int(v)
end

return T
