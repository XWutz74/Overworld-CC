-- Plays the whole game with thousands of random keys and clicks and checks it never crashes.
local here = fs.getDir(fs.getDir((debug.getinfo(1, "S").source or ""):gsub("^@", "")))
package.path = "/" .. fs.combine(here, "?.lua") .. ";/?.lua;" .. package.path
local test, truthy, eq = ccunit.test, ccunit.truthy, ccunit.eq

local CHARS = { "b", "s", "d", "B", "S", "D", "B", "S", "h", "l", "n", "t", "e", "c", "j", "m", "w",
  "0", "1", "2", "3", "4", "5", "1", "2", "3", "4", "5", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a" }
local KEYS = { keys.enter, keys.enter, keys.enter, keys.enter, keys.backspace, keys.backspace, keys.up, keys.down,
  keys.down, keys.left, keys.right, keys.tab, keys.pageUp, keys.pageDown, keys.home, keys["end"] }

-- Feeds random input to the game through os.pullEventRaw.
-- profile "player" mostly travels, trades and answers encounters; "random" presses anything.
local function fuzz(seed, count, settings, profile)
  math.randomseed(seed)
  local real = os.pullEventRaw
  local n = 0
  local stats = { days = 0, games = 0 }
  local G = require("ow.game")
  local lastId
  -- Only the game gets fake input; the test runner around it keeps the real events.
  local gameCo = coroutine.running()
  os.pullEventRaw = function(filter)
    if coroutine.running() ~= gameCo then return real(filter) end
    n = n + 1
    local cur = G.state()
    if cur then
      stats.days = math.max(stats.days, cur.day)
      if cur.id ~= lastId then lastId = cur.id; stats.games = stats.games + 1 end
    end
    if n % 100 == 0 then os.queueEvent("fuzz_yield"); real("fuzz_yield") end
    if n > count then return "terminate" end
    local r = math.random()
    if profile == "player" and r < 0.6 then
      local p = math.random()
      if p < 0.4 then return "char", tostring(math.random(1, 5))
      elseif p < 0.6 then return "char", ({ "B", "S", "b", "s" })[math.random(4)]
      elseif p < 0.8 then return "key", keys.enter, false
      else return "key", ({ keys.up, keys.down })[math.random(2)], false end
    end
    r = math.random()
    if r < 0.55 then return "char", CHARS[math.random(#CHARS)]
    elseif r < 0.92 then return "key", KEYS[math.random(#KEYS)], false
    elseif r < 0.98 then return "mouse_click", 1, math.random(1, 51), math.random(1, 19)
    else return "mouse_scroll", math.random() < 0.5 and -1 or 1, math.random(1, 51), math.random(1, 19) end
  end
  local store = require("ow.storage")
  local dir = "/fuzz-" .. seed
  if fs.exists(dir) then fs.delete(dir) end
  store.init(dir)
  store.set("settings", settings)
  local app = require("ow.app")
  local err
  while n <= count do
    local ok, e = pcall(app.run, dir)
    if not ok then
      if not (type(e) == "table" and e.terminate) then err = e end
      break
    end
    local S = G.state()
    if S then stats.days = math.max(stats.days, S.day) end
  end
  os.pullEventRaw = real
  local S = G.state()
  if S then
    stats.days = math.max(stats.days, S.day)
    stats.cash = S.cash
  end
  return err, stats, S
end

local function check(seed, settings, profile)
  local err, stats, S = fuzz(seed, 12000, settings, profile)
  eq(err, nil, "crash with seed " .. seed)
  if S then
    truthy(S.cash == S.cash, "cash is a number")
    truthy(S.health == S.health, "health is a number")
    for id, x in pairs(S.inv) do truthy(x.qty > 0, "positive quantity of " .. id) end
  end
  truthy(stats.games >= 1, "seed " .. seed .. " never started a game")
  if profile == "player" then truthy(stats.days >= 10, "seed " .. seed .. " only reached day " .. tostring(stats.days)) end
  return stats
end

for _, profile in ipairs({ "random", "player" }) do
  for _, seed in ipairs({ 1, 2, 3 }) do
    test(profile .. " play (English, no violence) seed " .. seed, function()
      check(seed, { lang = "en", violence = false, keepCash = 100, keepBank = 100 }, profile)
    end, { timeout = 120 })
  end
  for _, seed in ipairs({ 4, 5, 6 }) do
    test(profile .. " play (German, violence) seed " .. seed, function()
      check(seed, { lang = "de", violence = true, keepCash = 0, keepBank = 0 }, profile)
    end, { timeout = 120 })
  end
end
