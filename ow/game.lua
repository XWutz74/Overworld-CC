--[[
  Overworld-CC - game rules. A port of the browser game's engine (game.js),
  without any screen code, so it can be tested on its own.

  Actions return nil on success, or an error text for the player.
  Things that happen to the player (encounters, offers, arrest, death, end of
  the game) are returned as events: { kind = "encounter" | "offer" | "arrest" |
  "dead" | "end", ... }. The interface shows them.
]]
local U = require("ow.util")
local T = require("ow.text")
local t, nm, money = T.t, T.nm, T.money
local rnd, irnd, clamp, pick, round = U.rnd, U.irnd, U.clamp, U.pick, U.round

local G = {}
local W = T.fixAll(require("ow.data.world"))
local P = T.fixAll(require("ow.data.presets"))
G.W, G.P = W, P

-- Settings the rules need. The interface keeps this table up to date.
G.settings = { violence = false, keepCash = 100, keepBank = 100 }

local S          -- game state (saved)
local E          -- current encounter (not saved)

function G.state() return S end
function G.load(state) S = state; E = nil end
function G.encounter() return E end

--------------------------------------------------------------- lookups
function G.goodById(id) return U.find(W.goods, id) end
function G.itemById(id) return U.find(W.items, id) end
function G.city() return U.find(W.cities, S.city) end
function G.distById(id)
  for _, c in ipairs(W.cities) do
    for _, d in ipairs(c.districts) do if d.id == id then return d, c end end
  end
end
function G.here() return G.distById(S.district) end
function G.sharkById(id) return U.find(W.sharks, id) end
function G.bankById(id) return U.find(W.banks, id) end
function G.econ() return U.find(P.economy, S.econ) or P.economy[2] end
function G.fight() return U.find(P.combat, S.combat) or P.combat[2] end
function G.placeName() return nm(G.here().name) .. " (" .. nm(G.city().name) .. ")" end

--------------------------------------------------------------- derived values
function G.has(id) return (S.items[id] or 0) > 0 end
function G.tracker() return G.has("laptop") or G.has("tablet") end

function G.bestInSlot(slot, key)
  local best
  for _, it in ipairs(W.items) do
    if it.slot == slot and G.has(it.id) and (not best or (it[key] or 0) > (best[key] or 0)) then best = it end
  end
  return best
end
function G.vehicle() return G.bestInSlot("vehicle", "space") end
function G.armor() return G.bestInSlot("armor", "armor") end

function G.capacity()
  local cap = W.start.coat
  for _, slot in ipairs({ "coat", "pants", "bag", "vehicle" }) do
    local it = G.bestInSlot(slot, "space")
    if it then cap = cap + it.space end
  end
  return cap
end
function G.used()
  local n = 0
  for _, x in pairs(S.inv) do n = n + x.qty end
  return n
end
function G.free() return math.max(0, G.capacity() - G.used()) end
function G.bankTotal()
  local n = 0
  for _, a in ipairs(S.accounts) do n = n + a.balance end
  return n
end
function G.debtTotal()
  local n = 0
  for _, l in ipairs(S.loans) do n = n + l.amount end
  return n
end
function G.netWorth() return S.cash + G.bankTotal() - G.debtTotal() end
local function barter() return (S.char.skills.barter - 60) / 600 end
function G.buyPrice(p) return math.max(1, round(p * (1 - barter()))) end
function G.sellPrice(p) return math.max(1, round(p * (1 + barter()))) end
function G.weapon()
  if S.weapon and G.has(S.weapon) then return G.itemById(S.weapon) end
end
function G.atmAccounts()
  return U.filter(S.accounts, function(a) return G.bankById(a.bank).atm end)
end

--------------------------------------------------------------- log
local function log(text, cls)
  S.log[#S.log + 1] = { d = S.day, text = text, cls = cls or "" }
  while #S.log > 400 do table.remove(S.log, 1) end
end
G.log = log

--------------------------------------------------------------- market
local function recordSeen()
  for id, m in pairs(S.market) do
    S.seen[id] = S.seen[id] or {}
    local arr = S.seen[id][S.district] or {}
    S.seen[id][S.district] = arr
    if #arr == 0 or arr[#arr][1] ~= S.day then arr[#arr + 1] = { S.day, m.price } end
  end
end

local function genMarket()
  local e, m = G.econ(), {}
  for _, g in ipairs(W.goods) do
    local tip
    for _, x in ipairs(S.tips) do
      if x.day == S.day and x.district == S.district and x.good == g.id then tip = x; break end
    end
    if tip or math.random() <= g.avail then
      local mid = (g.min + g.max) / 2
      local p = mid + (rnd(g.min, g.max) - mid) * e.volatility
      local spike
      if tip then spike = tip.dir
      elseif math.random() < e.spikeChance then spike = math.random() < 0.5 and "down" or "up" end
      if spike == "down" then p = g.min * g.lowSpike * rnd(0.8, 1.05) end
      if spike == "up" then p = g.max * g.highSpike * rnd(0.9, 1.1) end
      m[g.id] = { price = math.max(1, round(p)), qty = irnd(g.qty[1], g.qty[2]) }
      if spike then
        log(t(spike == "down" and "log.crash" or "log.boom", { good = nm(g.name), place = nm(G.here().name) }),
          spike == "down" and "good" or "bad")
      end
    end
  end
  S.market = m
  S.storePrices = {}
  for _, it in ipairs(W.items) do S.storePrices[it.id] = round(it.price * e.costs * rnd(0.92, 1.12)) end
  -- tips for today are used up
  S.tips = U.filter(S.tips, function(x) return x.day > S.day end)
  if G.tracker() then recordSeen() end
end

function G.seenHiLo(id)
  local s = S.seen[id]
  if not s then return nil end
  local lo, hi = math.huge, 0
  for _, arr in pairs(s) do
    for _, x in ipairs(arr) do lo = math.min(lo, x[2]); hi = math.max(hi, x[2]) end
  end
  if hi > 0 then return lo, hi end
end

function G.seenAvg(id)
  local s = S.seen[id]
  if not s then return nil end
  local sum, n = 0, 0
  for _, arr in pairs(s) do
    for _, x in ipairs(arr) do sum = sum + x[2]; n = n + 1 end
  end
  if n > 0 then return sum / n end
end

local function recordFin()
  local f = { d = S.day, cash = S.cash, bank = round(G.bankTotal()), debt = G.debtTotal() }
  local last = S.fin[#S.fin]
  if last and last.d == S.day then S.fin[#S.fin] = f else S.fin[#S.fin + 1] = f end
end
G.recordFin = recordFin

--------------------------------------------------------------- new game
-- opt = { char = {name, skills}, econ = id, combat = id, length = days (0 endless) }
function G.newGame(opt)
  local e, c = U.find(P.economy, opt.econ), U.find(P.combat, opt.combat)
  local shark = G.sharkById(W.start.debtShark)
  local debt = round(W.start.debt * e.startDebt)
  S = {
    v = 1, id = os.epoch and os.epoch("utc") or os.time(), char = opt.char, econ = opt.econ, combat = opt.combat,
    length = opt.length, day = 1, city = W.start.city, district = W.start.district,
    cash = round(W.start.cash * e.startCash), health = c.startHealth,
    inv = {}, items = {}, ammo = {}, weapon = nil,
    loans = { { shark = shark.id, principal = debt, amount = debt, taken = 1, due = 1 + shark.days } },
    accounts = {}, market = {}, seen = {}, tips = {}, storePrices = {},
    log = {}, fin = {}, profit = {},
    stats = { encounters = 0, arrests = 0, escapes = 0, wins = 0, bought = 0, sold = 0 },
    atmDay = -9, over = false,
  }
  E = nil
  log(t("log.start", { name = S.char.name, place = G.placeName() }), "event")
  genMarket()
  recordFin()
  return S
end

--------------------------------------------------------------- inventory
local function addInv(id, q, price)
  local x = S.inv[id] or { qty = 0, paid = 0 }
  S.inv[id] = x
  x.paid = (x.paid * x.qty + price * q) / (x.qty + q)
  x.qty = x.qty + q
end

local function takeInv(id, q, price)
  local x = S.inv[id]
  if not x then return end
  if price ~= nil then S.profit[id] = (S.profit[id] or 0) + (price - x.paid) * q end
  x.qty = x.qty - q
  if x.qty <= 0 then S.inv[id] = nil end
end

--------------------------------------------------------------- events
local function startEncounter(etype, loan)
  local def, f, d = W.enemies[etype], G.fight(), G.here()
  local n = clamp(round(irnd(def.count[1], def.count[2]) * f.enemyCount), 1, 8)
  local leader = etype == "cops" and d.cops or etype == "mafia" and d.mafia or etype == "gang" and d.gang
    or G.sharkById(loan.shark).name
  local foes = {}
  for i = 1, n do foes[i] = { hp = round(def.hp * f.enemyStrength) } end
  E = { type = etype, loan = loan, leader = leader, foes = foes, lines = {}, done = false }
  S.stats.encounters = S.stats.encounters + 1
  local intro
  if etype == "shark" then
    intro = t("enc.sharkIntro", { name = leader, debt = money(loan.amount) })
  else
    intro = t("enc.intro." .. etype .. (n == 1 and ".solo" or ""),
      { name = leader, n = n - 1, members = nm(n == 2 and def.member or def.members) })
  end
  E.lines[#E.lines + 1] = { "", intro }
  return { kind = "encounter", encounter = E }
end
G.startEncounter = startEncounter

-- A special offer from a stranger. kind "buy" or "sell".
local function offer(kind, g, price, maxQty)
  local lim = maxQty
  if kind == "buy" then lim = math.min(maxQty, G.free(), math.floor(S.cash / price)) end
  if lim <= 0 then return nil end
  return { kind = "offer", offer = kind, good = g, price = price, maxQty = maxQty, lim = lim }
end
G.makeOffer = offer

local function randomEvent()
  local r = math.random()
  if r < 0.4 then
    local g, q = pick(W.goods), math.min(G.free(), irnd(2, 15))
    if q <= 0 then return nil end
    addInv(g.id, q, 0)
    log(t("log.find", { qty = q, good = nm(g.name), place = nm(G.here().name) }), "good")
  elseif r < 0.7 then
    local owned = {}
    for _, g in ipairs(W.goods) do if S.inv[g.id] and S.inv[g.id].qty > 0 then owned[#owned + 1] = g.id end end
    if #owned == 0 then return nil end
    local id = pick(owned)
    local g = G.goodById(id)
    local base = S.market[id] and S.market[id].price or (g.min + g.max) / 2
    return offer("sell", g, round(base * rnd(1.6, 2.4)), S.inv[id].qty)
  else
    local g = pick(W.goods)
    return offer("buy", g, round(g.min * rnd(0.35, 0.6)), irnd(5, 40))
  end
end

-- Accept a special offer for q pieces.
function G.takeOffer(o, q)
  if not (q and q >= 1 and q <= o.lim) then return t("msg.qtyRange", { min = 1, max = o.lim }) end
  if o.offer == "buy" then
    S.cash = S.cash - q * o.price
    addInv(o.good.id, q, o.price)
    log(t("log.specialBuy", { qty = q, good = nm(o.good.name), price = money(o.price) }), "good")
  else
    S.cash = S.cash + q * o.price
    takeInv(o.good.id, q, o.price)
    log(t("log.specialSell", { qty = q, good = nm(o.good.name), price = money(o.price) }), "good")
  end
end

--------------------------------------------------------------- end of the game
function G.die(reason)
  S.over = true
  S.health = 0
  log(reason, "bad")
  return { kind = "dead", reason = reason }
end

-- Ends the game and returns the score entry for the high score list.
function G.endGame(retired)
  S.over = true
  local score = round(G.netWorth())
  return { kind = "end", retired = retired, entry = {
    date = os.date and os.date("%Y-%m-%d") or "", name = S.char.name, length = S.length, days = S.day,
    econ = S.econ, combat = S.combat, score = score } }
end

--------------------------------------------------------------- day passing
-- Go to district did (the same district = stay a day). Returns an event or nil.
function G.travel(did)
  if S.over then return nil end
  if S.length > 0 and S.day >= S.length then return G.endGame(false) end
  local stay = did == S.district
  S.day = S.day + 1
  local e = G.econ()
  for _, l in ipairs(S.loans) do l.amount = round(l.amount * (1 + G.sharkById(l.shark).rate * e.loanRate / 100)) end
  for _, a in ipairs(S.accounts) do a.balance = a.balance * (1 + G.bankById(a.bank).rate * e.bankRate / 36500) end
  if S.health < 30 then
    S.health = S.health - 4
    log(t("log.worse"), "bad")
  elseif S.health < 100 then
    S.health = math.min(100, S.health + 3)
  end
  if S.health <= 0 then return G.die(t("death.wounds")) end
  S.district = did
  log(t(stay and "log.stay" or "log.enter", { place = G.placeName() }))
  genMarket()
  recordFin()
  for _, l in ipairs(S.loans) do
    if S.day > l.due then return startEncounter("shark", l) end
  end
  local veh = G.vehicle()
  local chance = G.fight().encounterChance + (veh and veh.notice or 0) + (S.day - S.atmDay <= 1 and 5 or 0)
  if math.random() * 100 < chance then return startEncounter(pick({ "cops", "cops", "gang", "mafia" })) end
  if math.random() < 0.12 then return randomEvent() end
end

--------------------------------------------------------------- trading
local function arrest()
  local fine = round(S.cash * G.fight().arrestFine / 100)
  S.cash = S.cash - fine
  S.inv = {}
  S.stats.arrests = S.stats.arrests + 1
  log(t("log.arrested", { fine = money(fine) }), "bad")
  return { kind = "arrest", fine = fine }
end

local function afterDeal(g, kind)
  if math.random() < 0.015 * G.fight().enemyStrength then
    log(t(kind == "buy" and "log.stingBuy" or "log.stingSell", { good = nm(g.name) }), "bad")
    return arrest()
  end
  if math.random() < 0.14 then
    local tg, td = pick(W.goods), pick(G.city().districts)
    local dir = math.random() < 0.5 and "down" or "up"
    S.tips[#S.tips + 1] = { day = S.day + 1, district = td.id, good = tg.id, dir = dir }
    log(t(dir == "down" and "log.tipDown" or "log.tipUp", { good = nm(tg.name), place = nm(td.name) }), "tip")
  end
end

-- How many of good id the player can buy now. Returns limit, price, or 0 and a reason.
function G.buyLimit(id)
  local m = S.market[id]
  if not m then return 0, nil, t("msg.selectMarket") end
  local p = G.buyPrice(m.price)
  local lim = math.min(math.floor(S.cash / p), G.free(), m.qty)
  if lim <= 0 then
    return 0, p, S.cash < p and t("msg.noMoney") or G.free() <= 0 and t("msg.noSpace") or t("msg.soldOut")
  end
  return lim, p
end

-- Returns error, event.
function G.buy(id, q)
  if S.over then return "" end
  local lim, p, why = G.buyLimit(id)
  if lim <= 0 then return why end
  if not (q and q >= 1 and q <= lim) then return t("msg.qtyRange", { min = 1, max = lim }) end
  local g = G.goodById(id)
  S.cash = S.cash - q * p
  S.market[id].qty = S.market[id].qty - q
  addInv(id, q, p)
  S.stats.bought = S.stats.bought + q * p
  log(t("log.bought", { qty = q, good = nm(g.name), price = money(q * p) }))
  return nil, afterDeal(g, "buy")
end

function G.sellLimit(id)
  local x = S.inv[id]
  if not x then return 0, nil, t("msg.selectInv") end
  if not S.market[id] then return 0, nil, t("msg.noBuyer", { good = nm(G.goodById(id).name) }) end
  return x.qty, G.sellPrice(S.market[id].price)
end

function G.sell(id, q)
  if S.over then return "" end
  local lim, p, why = G.sellLimit(id)
  if lim <= 0 then return why end
  if not (q and q >= 1 and q <= lim) then return t("msg.qtyRange", { min = 1, max = lim }) end
  local g = G.goodById(id)
  S.cash = S.cash + q * p
  takeInv(id, q, p)
  S.stats.sold = S.stats.sold + q * p
  log(t("log.sold", { qty = q, good = nm(g.name), price = money(q * p) }))
  return nil, afterDeal(g, "sell")
end

function G.drop(id, q)
  local x = S.inv[id]
  if not x then return t("msg.selectInv") end
  if not (q and q >= 1 and q <= x.qty) then return t("msg.qtyRange", { min = 1, max = x.qty }) end
  takeInv(id, q, 0)
  log(t("log.dropped", { qty = q, good = nm(G.goodById(id).name) }))
end

--------------------------------------------------------------- encounters
local function alive()
  return U.filter(E.foes, function(x) return x.hp > 0 end)
end
G.alive = alive
local function eLine(text, cls) E.lines[#E.lines + 1] = { cls or "", text } end

local function enemyTurn()
  local def, f, arm, sk = W.enemies[E.type], G.fight(), G.armor(), S.char.skills
  for _ in ipairs(alive()) do
    local acc = def.accuracy * f.enemyStrength - (sk.evade - 60) * 0.4
    if math.random() * 100 < acc then
      local dmg = rnd(def.damage[1], def.damage[2]) * f.enemyStrength * (1 - (sk.strength - 60) / 300)
      if arm then dmg = dmg * (1 - arm.armor / 100) end
      dmg = math.max(1, round(dmg))
      S.health = S.health - dmg
      eLine(t(G.settings.violence and "enc.hitYou" or "enc.hitYouTalk", { dmg = dmg }), "bad")
      if S.health <= 0 then
        S.health = 0
        eLine(t("enc.youDie"), "bad")
        E.done = "dead"
        return
      end
    else
      eLine(t(G.settings.violence and "enc.missYou" or "enc.missYouTalk"), "miss")
    end
  end
end

local function winEncounter()
  local def = W.enemies[E.type]
  local loot = irnd(def.loot[1], def.loot[2])
  S.cash = S.cash + loot
  S.stats.wins = S.stats.wins + 1
  eLine(t("enc.won"), "good")
  if loot > 0 then eLine(t("enc.loot", { amount = money(loot) }), "good") end
  if E.type == "shark" then
    E.loan.due = S.day + 1
    eLine(t("enc.sharkBack", { name = E.leader }))
  end
  log(t("log.won", { name = E.leader }), "good")
  E.done = "won"
end

local function sharkBeat()
  S.health = S.health - 15
  E.loan.due = S.day + 1
  eLine(t("enc.sharkBeat", { name = E.leader }), "bad")
  log(t("log.sharkBeat", { name = E.leader }), "bad")
end

-- a = "run" | "droprun" | "fight" | "surrender" | "pay" | "time"
function G.encAction(a)
  if not E or E.done then return end
  local sk, f, veh = S.char.skills, G.fight(), G.vehicle()
  local violence = G.settings.violence
  if a == "run" or a == "droprun" then
    if a == "droprun" then S.inv = {}; eLine(t("enc.dropped")) end
    local ch = 38 + (sk.evade - 50) * 0.6 + (veh and veh.run or 0) + f.runBonus - #alive() * 3
    if a == "droprun" then ch = ch + (E.type == "cops" and 35 or 15) end
    ch = clamp(ch, 5, 90)
    eLine(t("enc.youRun"))
    if math.random() * 100 < ch then
      eLine(t("enc.escaped"), "good")
      S.stats.escapes = S.stats.escapes + 1
      E.done = "escaped"
      log(t("log.escaped", { name = E.leader }))
    else
      eLine(t("enc.notAway"), "bad")
      enemyTurn()
    end
  elseif a == "fight" then
    local w = G.weapon()
    local useW = w and (not w.ammo or (S.ammo[w.ammo] or 0) > 0)
    local shots = useW and (w.shots or 1) or 1
    if w and not useW then eLine(t("enc.noAmmo"), "bad") end
    eLine(violence and t("enc.attack", { weapon = useW and nm(w.name) or t("weapon.hands") }) or t("enc.talk"))
    for _ = 1, shots do
      local target = alive()[1]
      if not target then break end
      if useW and w.ammo then
        if (S.ammo[w.ammo] or 0) <= 0 then break end
        S.ammo[w.ammo] = S.ammo[w.ammo] - 1
      end
      local acc = (useW and w.accuracy or 75) + (sk.combat - 60) * 0.5
      if math.random() * 100 < acc then
        local dr = useW and w.damage or (violence and { 4, 9 } or { 6, 12 })
        local dmg = round(rnd(dr[1], dr[2]) * (1 + (sk.strength - 60) / 200))
        target.hp = target.hp - dmg
        if target.hp <= 0 then eLine(t(violence and "enc.downOne" or "enc.convincedOne"), "good")
        else eLine(t(violence and "enc.hit" or "enc.argueHit"), "good") end
      else
        eLine(t(violence and "enc.miss" or "enc.argueMiss"), "miss")
      end
    end
    if not violence then
      S.health = S.health - 1
      if S.health <= 0 then
        S.health = 0
        eLine(t("enc.youDie"), "bad")
        E.done = "dead"
        return
      end
    end
    if #alive() == 0 then return winEncounter() end
    enemyTurn()
  elseif a == "surrender" then
    if E.type == "cops" then
      local ev = arrest()
      eLine(t("log.arrested", { fine = money(ev.fine) }), "bad")
      E.done = "arrested"
      return
    end
    if E.type == "shark" then
      E.done = "beaten"
      sharkBeat()
    else
      local take = round(S.cash * rnd(0.3, 0.6))
      S.cash = S.cash - take
      for _, id in ipairs(U.keys(S.inv)) do takeInv(id, math.ceil(S.inv[id].qty / 2), nil) end
      eLine(t("enc.robbed", { amount = money(take) }), "bad")
      log(t("log.robbed", { amount = money(take) }), "bad")
      E.done = "robbed"
    end
    if S.health <= 0 then S.health = 0; E.done = "dead" end
  elseif a == "pay" then
    if S.cash < E.loan.amount then
      eLine(t("enc.cantPay"), "bad")
    else
      S.cash = S.cash - E.loan.amount
      log(t("log.loanPaid", { name = E.leader, amount = money(E.loan.amount) }), "good")
      U.remove(S.loans, E.loan)
      eLine(t("enc.paid"), "good")
      E.done = "paid"
    end
  elseif a == "time" then
    if math.random() < 0.55 then
      E.loan.due = S.day + 1
      eLine(t("enc.moreTime", { name = E.leader }), "good")
      log(t("log.moreTime", { name = E.leader }))
    else
      sharkBeat()
      if S.health <= 0 then S.health = 0; E.done = "dead" end
    end
    if E.done ~= "dead" then E.done = "time" end
  end
end

-- Limits for a bribe: min, max, default; nil if the player has nothing to offer.
function G.bribeRange()
  if S.cash < 2 then return nil end
  local max = math.floor(S.cash)
  return 2, max, math.min(max, 500)
end

function G.bribe(amt)
  if not E or E.done then return end
  if S.cash < 2 then eLine(t("enc.noBribeMoney"), "bad"); return end
  local _, max = G.bribeRange()
  if not (amt and amt >= 2 and amt <= max) then return t("msg.qtyRange", { min = 2, max = max }) end
  S.cash = S.cash - amt
  local want = W.enemies[E.type].bribe * #alive() * G.fight().enemyStrength
  local chance = want > 0 and clamp(amt / want, 0, 0.95) or 0.95
  if math.random() < chance then
    eLine(t("enc.bribeOk", { amount = money(amt) }), "good")
    E.done = "bribed"
    log(t("log.bribed", { name = E.leader, amount = money(amt) }))
  elseif math.random() < 0.4 then
    eLine(t("enc.bribeHostile"), "bad")
    enemyTurn()
  else
    eLine(t("enc.bribeNo"), "bad")
  end
end

-- Call when the player leaves the encounter screen. Returns an event or nil.
function G.endEncounter()
  local done = E and E.done
  E = nil
  if done == "dead" then return G.die(t("death.fight")) end
end

--------------------------------------------------------------- paying
-- method: "cash" or a bank id with a card (ATM).
function G.pay(amount, method)
  if not method or method == "cash" then
    if S.cash < amount then return t("msg.noMoney") end
    S.cash = S.cash - amount
    return nil
  end
  local a
  for _, x in ipairs(S.accounts) do if x.bank == method then a = x end end
  if not a or a.balance - amount < G.bankById(a.bank).min then return t("msg.noBalance") end
  a.balance = a.balance - amount
  S.atmDay = S.day
end

--------------------------------------------------------------- hospital
function G.hospitalInfo()
  local price = round(W.hospitalPrice * G.econ().costs)
  local need = 100 - math.ceil(S.health)
  local max = math.min(need, math.floor(S.cash / price) + (#G.atmAccounts() > 0 and 999 or 0))
  return price, need, math.max(1, math.min(need, max))
end

function G.heal(q, method)
  local d = G.here()
  local price, need = G.hospitalInfo()
  if not (q and q >= 1 and q <= need) then return t("msg.qtyRange", { min = 1, max = need }) end
  local err = G.pay(q * price, method)
  if err then return err end
  S.health = math.min(100, S.health + q)
  log(t("log.healed", { qty = q, place = d.hospital, price = money(q * price) }), "good")
end

--------------------------------------------------------------- loan sharks
function G.sharkRate(s) return s.rate * G.econ().loanRate end

function G.borrow(sharkId, a)
  local s = G.sharkById(sharkId)
  if not s then return t("msg.pickShark") end
  if not (a and a >= s.amount[1] and a <= s.amount[2]) then
    return t("msg.loanRange", { min = money(s.amount[1]), max = money(s.amount[2]) })
  end
  S.cash = S.cash + a
  S.loans[#S.loans + 1] = { shark = s.id, principal = a, amount = a, taken = S.day, due = S.day + s.days }
  log(t("log.borrowed", { amount = money(a), name = s.name }), "event")
end

-- Total to pay back loan i today (with the early repayment fee).
function G.loanPayoff(l)
  local s = G.sharkById(l.shark)
  local fee = S.day < l.due and round(l.amount * s.early / 100) or 0
  return l.amount + fee
end

function G.payLoan(i)
  local l = S.loans[i]
  if not l then return t("msg.pickLoan") end
  local s = G.sharkById(l.shark)
  if s.district ~= S.district then
    return t("msg.sharkElsewhere", { name = s.name, place = nm(G.distById(s.district).name) })
  end
  local total = G.loanPayoff(l)
  if S.cash < total then return t("msg.payNeed", { amount = money(total) }) end
  S.cash = S.cash - total
  table.remove(S.loans, i)
  log(t("log.loanPaid", { name = s.name, amount = money(total) }), "good")
end

--------------------------------------------------------------- banks
function G.bankRate(b) return b.rate * G.econ().bankRate end
function G.banksHere() return U.filter(W.banks, function(b) return b.district == S.district end) end

function G.openAccount(bankId, a)
  local b = G.bankById(bankId)
  if not b then return t("msg.pickBank") end
  if not (a and a >= b.min and a <= S.cash) then
    return t("msg.depositRange", { min = money(b.min), max = money(S.cash) })
  end
  S.cash = S.cash - a
  S.accounts[#S.accounts + 1] = { bank = b.id, balance = a }
  log(t("log.accountOpened", { bank = nm(b.name) }), "event")
end

function G.closeAccount(i)
  local a = S.accounts[i]
  if not a then return t("msg.pickAccount") end
  S.cash = S.cash + round(a.balance)
  table.remove(S.accounts, i)
  log(t("log.accountClosed", { bank = nm(G.bankById(a.bank).name) }))
end

function G.withdrawAll(i)
  local a = S.accounts[i]
  if not a then return t("msg.pickAccount") end
  local b = G.bankById(a.bank)
  local m = math.max(0, math.floor(a.balance - math.max(b.min, G.settings.keepBank)))
  a.balance = a.balance - m
  S.cash = S.cash + m
end

function G.withdraw(i, m)
  local a = S.accounts[i]
  if not a then return t("msg.pickAccount") end
  local b = G.bankById(a.bank)
  if not (m and m > 0 and a.balance - m >= b.min) then
    return t("msg.withdrawLimit", { max = money(math.max(0, a.balance - b.min)) })
  end
  a.balance = a.balance - m
  S.cash = S.cash + m
end

function G.depositAll(i)
  local a = S.accounts[i]
  if not a then return t("msg.pickAccount") end
  local m = math.max(0, S.cash - G.settings.keepCash)
  a.balance = a.balance + m
  S.cash = S.cash - m
end

function G.deposit(i, m)
  local a = S.accounts[i]
  if not a then return t("msg.pickAccount") end
  if not (m and m > 0 and m <= S.cash) then return t("msg.noMoney") end
  a.balance = a.balance + m
  S.cash = S.cash - m
end

--------------------------------------------------------------- store and items
-- Items the store sells, in category cat ("all" or an item type).
function G.storeItems(cat)
  return U.filter(W.items, function(i)
    return (G.settings.violence or not i.violence) and (cat == "all" or i.type == cat)
  end)
end

function G.sellableItems()
  return U.filter(W.items, function(i) return G.has(i.id) and i.sellable ~= false end)
end

function G.buyItem(id, method)
  local it = G.itemById(id)
  if not it then return "" end
  if it.type ~= "ammo" and it.type ~= "storage" and it.type ~= "armor" and G.has(id) then return t("msg.haveItem") end
  local price = S.storePrices[id]
  local err = G.pay(price, method)
  if err then return err end
  if it.type == "ammo" then
    S.ammo[id] = (S.ammo[id] or 0) + it.rounds
  elseif it.type == "vehicle" then
    local old = G.vehicle()
    if old then
      local back = round(S.storePrices[old.id] / 2)
      S.cash = S.cash + back
      S.items[old.id] = nil
      log(t("log.tradeIn", { item = nm(old.name), price = money(back) }))
    end
    S.items[id] = 1
  else
    S.items[id] = (S.items[id] or 0) + 1
  end
  if it.type == "weapon" and not S.weapon then S.weapon = id end
  if id == "laptop" or id == "tablet" then recordSeen() end
  log(t("log.shopped", { items = nm(it.name), price = money(price) }), "event")
end

local function loseItem(id)
  S.items[id] = S.items[id] - 1
  if S.items[id] <= 0 then
    S.items[id] = nil
    if S.weapon == id then S.weapon = nil end
  end
end

function G.sellItem(id)
  if not G.has(id) then return "" end
  local p = round(S.storePrices[id] / 2)
  loseItem(id)
  S.cash = S.cash + p
  log(t("log.itemSold", { item = nm(G.itemById(id).name), price = money(p) }))
end

function G.dropItem(id)
  if not G.has(id) then return "" end
  loseItem(id)
  log(t("log.itemDropped", { item = nm(G.itemById(id).name) }))
end

function G.equip(id)
  if id == nil or G.has(id) then S.weapon = id end
end

return G
