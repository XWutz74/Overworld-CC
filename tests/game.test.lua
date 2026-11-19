-- Tests for the game rules (ow/game.lua). Run with craftos_test.
local here = fs.getDir(fs.getDir((debug.getinfo(1, "S").source or ""):gsub("^@", "")))
package.path = "/" .. fs.combine(here, "?.lua") .. ";/?.lua;" .. package.path
local T = require("ow.text")
local G = require("ow.game")
local test, eq, truthy, contains = ccunit.test, ccunit.eq, ccunit.truthy, ccunit.contains

local CHAR = { name = "Tester", skills = { combat = 60, evade = 60, strength = 60, barter = 60 } }
local function fresh(seed)
  math.randomseed(seed or 1)
  T.set("en")
  return G.newGame({ char = CHAR, econ = "normal", combat = "normal", length = 30 })
end

test("text: money and umlauts", function()
  T.set("de")
  eq(T.money(1234567), "$1.234.567")
  eq(T.money(-5500), "-$5.500")
  T.set("en")
  eq(T.money(1234567), "$1,234,567")
  eq(T.money(0.3), "$0")
  eq(T.fix("f\195\188r"), "f\252r")       -- UTF-8 "für" becomes one character
  eq(T.fix("f\252r"), "f\252r")           -- already one character: unchanged
  eq(T.fix("\226\128\158Hi\226\128\156"), '"Hi"')
  T.set("de")
  eq(#T.t("place.hospital"), 11)          -- "Krankenhaus"
  eq(T.t("len.days", { n = 5 }), "5 Tage")
  T.set("en")
end)

test("new game starts like the browser game", function()
  local S = fresh()
  eq(S.cash, 2000)
  eq(S.day, 1)
  eq(S.district, "manhattan")
  eq(#S.loans, 1)
  eq(S.loans[1].amount, 5500)
  eq(S.loans[1].due, 11)
  eq(G.capacity(), 100)
  eq(G.netWorth(), -3500)
  truthy(next(S.market), "market has goods")
  contains(S.log[1].text, "Tester")
end)

test("buy and sell update cash, space and profit", function()
  local S = fresh(7)
  S.cash = 1000000
  local id
  for _, g in ipairs(G.W.goods) do if S.market[g.id] then id = g.id; break end end
  local lim, p = G.buyLimit(id)
  truthy(lim > 0)
  local q = math.min(lim, 10)
  local err = G.buy(id, q)
  eq(err, nil)
  eq(S.inv[id].qty, q)
  eq(S.inv[id].paid, p)
  eq(G.used(), q)
  if not S.over and S.inv[id] then
    local sl, sp = G.sellLimit(id)
    eq(sl, q)
    G.sell(id, q)
    eq(S.inv[id], nil)
    ccunit.near(S.profit[id], (sp - p) * q)
  end
end)

test("buy refuses more than allowed", function()
  local S = fresh(3)
  local id = next(S.market)
  local lim = G.buyLimit(id)
  truthy(G.buy(id, lim + 1) ~= nil, "too many is an error")
  truthy(G.buy(id, 0) ~= nil, "zero is an error")
end)

test("travel: interest, day count and market", function()
  local S = fresh(11)
  G.travel("bronx")
  eq(S.day, 2)
  eq(S.loans[1].amount, 6325)            -- 5500 * 1.15
  if not G.encounter() then eq(S.district, "bronx") end
end)

test("game ends after its length", function()
  local S = fresh(5)
  S.length = 2
  S.day = 2
  local ev = G.travel("bronx")
  eq(ev.kind, "end")
  eq(S.over, true)
  eq(ev.entry.score, -3500)
end)

test("overdue loan brings the loan shark", function()
  local S = fresh(2)
  S.loans[1].due = 1
  local ev = G.travel("manhattan")
  eq(ev.kind, "encounter")
  eq(ev.encounter.type, "shark")
  eq(ev.encounter.leader, "Tybalt")
  S.cash = 100000
  G.encAction("pay")
  eq(ev.encounter.done, "paid")
  eq(#S.loans, 0)
  eq(G.endEncounter(), nil)
end)

test("fights end", function()
  for seed = 1, 40 do
    local S = fresh(seed)
    G.startEncounter("gang")
    local n = 0
    while not G.encounter().done and n < 200 do G.encAction("fight"); n = n + 1 end
    truthy(G.encounter().done, "seed " .. seed .. " finished")
    local ev = G.endEncounter()
    if ev then eq(ev.kind, "dead"); eq(S.over, true) end
  end
end)

test("surrender to cops is an arrest", function()
  local S = fresh(4)
  S.cash = 1000
  S.inv.gold = { qty = 3, paid = 10 }
  G.startEncounter("cops")
  G.encAction("surrender")
  eq(G.encounter().done, "arrested")
  eq(S.cash, 800)
  eq(next(S.inv), nil)
end)

test("bank: open, deposit, withdraw, close", function()
  local S = fresh(1)
  S.cash = 10000
  eq(G.openAccount("first", 50) ~= nil, true)      -- below minimum
  eq(G.openAccount("first", 1000), nil)
  eq(S.cash, 9000)
  eq(G.deposit(1, 500), nil)
  eq(S.accounts[1].balance, 1500)
  truthy(G.withdraw(1, 1450) ~= nil, "must keep minimum")
  eq(G.withdraw(1, 400), nil)
  G.depositAll(1)
  eq(S.cash, 100)
  G.withdrawAll(1)
  eq(S.accounts[1].balance, 100)
  G.closeAccount(1)
  eq(#S.accounts, 0)
end)

test("loans: borrow and pay back early with fee", function()
  local S = fresh(1)
  eq(G.borrow("tybalt", 500) ~= nil, true)       -- out of range
  eq(G.borrow("tybalt", 2000), nil)
  eq(#S.loans, 2)
  eq(G.loanPayoff(S.loans[2]), 2200)
  eq(G.payLoan(2), nil)
  eq(S.cash, 2000 + 2000 - 2200)
  eq(G.payLoan(1) ~= nil, true)                   -- not enough cash
  S.district = "bronx"
  contains(G.payLoan(1), "Manhattan")             -- Tybalt only in Manhattan
end)

test("store: space, vehicles trade in, no double tools", function()
  local S = fresh(1)
  S.cash = 1000000
  eq(G.buyItem("backpack"), nil)
  eq(G.capacity(), 160)
  eq(G.buyItem("motorcycle"), nil)
  eq(G.capacity(), 200)
  eq(G.buyItem("sedan"), nil)
  eq(G.has("motorcycle"), false)
  eq(G.capacity(), 280)
  eq(G.buyItem("calculator"), nil)
  truthy(G.buyItem("calculator") ~= nil, "second calculator refused")
  G.sellItem("calculator")
  eq(G.has("calculator"), false)
end)

test("hospital heals and costs", function()
  local S = fresh(1)
  S.health = 50
  local price, need = G.hospitalInfo()
  eq(need, 50)
  eq(G.heal(10), nil)
  eq(S.health, 60)
  eq(S.cash, 2000 - 10 * price)
end)

test("state survives textutils.serialize", function()
  local S = fresh(9)
  G.travel("queens")
  G.endEncounter()
  local copy = textutils.unserialize(textutils.serialize(S))
  eq(copy.day, S.day)
  eq(copy.loans[1].amount, S.loans[1].amount)
end)
