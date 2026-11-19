--[[
  Overworld-CC - the screens: title, new game, the main trading screen and
  every window (trade, encounters, hospital, loan sharks, bank, store, items,
  charts, messages, menu, settings, scores).
]]
local U = require("ow.util")
local T = require("ow.text")
local G = require("ow.game")
local ui = require("ow.ui")
local store = require("ow.storage")
local t, nm, money = T.t, T.nm, T.money
local C = ui.C
local W, P = G.W, G.P

local A = {}
local settings
local sel            -- selected good id on the main screen
local top = 1        -- first visible row of the goods table
local seenLog = 0    -- number of log entries already shown

local DEFAULT_SETTINGS = { lang = "en", violence = false, keepCash = 100, keepBank = 100 }

local function save()
  local S = G.state()
  if S then store.set("save", S) end
end

local function applySettings()
  T.set(settings.lang)
  G.settings.violence = settings.violence
  G.settings.keepCash = settings.keepCash
  G.settings.keepBank = settings.keepBank
end

local function btn(label, id, primary, disabled)
  return { label = label, id = id, primary = primary, disabled = disabled }
end

local function pct(v) return T.int(v) .. " %" end

--------------------------------------------------------------- main screen
local function goodsRows()
  local S = G.state()
  local rows = {}
  for _, g in ipairs(W.goods) do
    if S.market[g.id] or S.inv[g.id] then rows[#rows + 1] = g end
  end
  return rows
end

local function tableHeight()
  local _, SH = ui.size()
  return SH - 11
end

local function keepSelection()
  local rows = goodsRows()
  local idx
  for i, g in ipairs(rows) do if g.id == sel then idx = i end end
  if not idx then
    sel = rows[1] and rows[1].id or nil
    idx = 1
  end
  local h = tableHeight()
  if idx < top then top = idx end
  if idx > top + h - 1 then top = idx - h + 1 end
  top = math.max(1, math.min(top, math.max(1, #rows - h + 1)))
  return rows, idx
end

local function actionList()
  local S, d = G.state(), G.here()
  local live = not S.over
  local m, inv = sel and S.market[sel], sel and S.inv[sel]
  return {
    { "B", t("act.buy"), "buy", live and m },
    { "S", t("act.sell"), "sell", live and inv and m },
    { "D", t("act.drop"), "drop", live and inv },
    { "H", t("cc.a.hosp"), "hosp", live and d.hospital },
    { "L", t("cc.a.loans"), "loans", live },
    { "N", t("place.bank"), "bank", live },
    { "T", t("place.store"), "store", live and d.store },
    { "E", t("act.items"), "items", live },
    { "C", t("act.charts"), "charts", true },
    { "J", t("messages"), "log", true },
  }
end

function A.drawMain()
  local S = G.state()
  local SW, SH = ui.size()
  ui.clear()
  -- header
  ui.fill(1, 1, SW, 1, C.head)
  local dayText = t("day") .. " " .. S.day .. (S.length > 0 and (" / " .. S.length) or (" (" .. t("len.endless") .. ")"))
  local x = 2 + ui.text(2, 1, dayText, C.accent, C.head) + 2
  local menuLabel = " M " .. t("cc.a.menu") .. " "
  ui.text(x, 1, ui.sub(S.over and t("death.title") or G.placeName(), SW - x - #menuLabel), C.headfg, C.head)
  ui.text(SW - #menuLabel + 1, 1, menuLabel, C.btnfg, C.btn)
  ui.zone(SW - #menuLabel + 1, 1, #menuLabel, 1, "menu")

  -- status
  local function stat(xl, y, label, value, color)
    ui.text(xl, y, label, C.muted, C.bg)
    ui.text(xl + 11, y, value, color or C.fg, C.bg)
  end
  local debt, nw = G.debtTotal(), G.netWorth()
  stat(2, 2, t("cash"), money(S.cash), C.pos)
  stat(2, 3, t("bank"), money(G.bankTotal()))
  stat(28, 2, ui.sub(t("debt"), 10), money(debt), debt > 0 and C.neg or C.fg)
  stat(28, 3, ui.sub(t("networth"), 10), money(nw), nw >= 0 and C.pos or C.neg)
  local h = math.max(0, U.round(S.health))
  ui.text(2, 4, ui.sub(t("health"), 10), C.muted, C.bg)
  ui.bar(13, 4, 8, h / 100, ui.healthColor(h))
  ui.text(22, 4, h .. "%", ui.healthColor(h), C.bg)
  local cap, used = G.capacity(), G.used()
  stat(28, 4, ui.sub(t("space"), 10), used .. " / " .. cap, used >= cap and C.neg or C.fg)

  -- goods table
  local rows, _ = keepSelection()
  local th = tableHeight()
  local lap, tab = G.has("laptop"), G.has("tablet")
  local calc = G.has("calculator")
  ui.fill(1, 5, SW, 1, C.head)
  ui.text(2, 5, ui.pad(t("good"), 18), C.headfg, C.head)
  ui.text(20, 5, ui.pad(t("cc.col.stock"), 6, "r"), C.headfg, C.head)
  ui.text(26, 5, ui.pad(t("price"), 9, "r"), C.headfg, C.head)
  ui.text(36, 5, ui.pad(t("cc.col.have"), 6, "r"), C.headfg, C.head)
  ui.text(42, 5, ui.pad(t("paid"), 9, "r"), C.headfg, C.head)
  if #rows == 0 then
    ui.text(2, 6, ui.sub(t("market.empty"), SW - 2), C.muted, C.bg)
  end
  for i = top, math.min(#rows, top + th - 1) do
    local g = rows[i]
    local y = 6 + i - top
    local m, x = S.market[g.id], S.inv[g.id]
    local isSel = g.id == sel
    local bg = isSel and C.sel or C.bg
    ui.fill(1, y, SW, 1, bg)
    ui.text(2, y, ui.pad(nm(g.name), 18), m and C.fg or C.muted, bg)
    if m then
      ui.text(20, y, ui.pad(T.int(m.qty), 6, "r"), C.fg, bg)
      ui.text(26, y, ui.pad(money(G.buyPrice(m.price)), 9, "r"), C.fg, bg)
      if lap then
        local avg = G.seenAvg(g.id)
        if avg then
          local dd = m.price / avg - 1
          if dd < -0.15 then ui.text(35, y, ui.DOWN, C.pos, bg)
          elseif dd > 0.15 then ui.text(35, y, ui.UP, C.neg, bg)
          else ui.text(35, y, ui.RIGHT, C.muted, bg) end
        end
      end
    else
      ui.text(26, y, ui.pad("-", 9, "r"), C.muted, bg)
    end
    if x then
      ui.text(36, y, ui.pad(T.int(x.qty), 6, "r"), C.accent, bg)
      local pc = C.fg
      if calc and m then pc = G.sellPrice(m.price) >= x.paid and C.pos or C.neg end
      ui.text(42, y, ui.pad(money(x.paid), 9, "r"), pc, bg)
    end
    ui.zone(1, y, SW, 1, "good:" .. g.id)
  end
  if top > 1 then ui.text(SW, 6, ui.UP, C.accent, C.bg) end
  if top + th - 1 < #rows then ui.text(SW, 5 + th, ui.DOWN, C.accent, C.bg) end

  -- status bar for the selected good
  local sy = SH - 5
  ui.fill(1, sy, SW, 1, C.head)
  local parts = {}
  if sel then
    local m, x = S.market[sel], S.inv[sel]
    if m then parts[#parts + 1] = t("act.sell") .. " " .. money(G.sellPrice(m.price)) end
    if G.tracker() then
      local avg = G.seenAvg(sel)
      parts[#parts + 1] = t("sb.avg") .. " " .. (avg and money(avg) or "-")
      local lo, hi = G.seenHiLo(sel)
      if lo then
        parts[#parts + 1] = t("col.high") .. " " .. money(hi)
        if lap then parts[#parts + 1] = t("col.low") .. " " .. money(lo) end
      end
    end
    if calc and x and m then
      parts[#parts + 1] = t("sb.profit") .. " " .. money((G.sellPrice(m.price) - x.paid) * x.qty)
    end
  end
  local bar = table.concat(parts, "  ")
  if bar == "" or #bar > SW - 2 then
    if #parts > 0 then
      bar = ""
      for _, p in ipairs(parts) do
        if #bar + #p + 2 <= SW - 2 then bar = bar == "" and p or (bar .. "  " .. p) end
      end
    else
      bar = t("cc.sb.hint")
    end
  end
  ui.text(2, sy, ui.sub(bar, SW - 2), C.headfg, C.head)

  -- latest messages
  local lines = {}
  local first = math.max(1, #S.log - 6)
  for i = first, #S.log do
    local l = S.log[i]
    local col = ui.LOG[l.cls] or (i > seenLog and C.fg or C.muted)
    for _, w in ipairs(ui.wrap(l.text, SW - 2)) do lines[#lines + 1] = { w, col } end
  end
  for k = 1, 2 do
    local l = lines[#lines - 2 + k]
    if l then ui.text(2, SH - 5 + k, l[1], l[2], C.bg) end
  end
  ui.zone(1, SH - 4, SW, 2, "log")

  -- districts (travel)
  local city = G.city()
  local ty = SH - 2
  local names = {}
  local total = 0
  for i, d in ipairs(city.districts) do names[i] = nm(d.name); total = total + #names[i] + 2 end
  local room = SW - 1
  while total - 1 > room do
    local longest = 1
    for i, n in ipairs(names) do if #n > #names[longest] then longest = i end end
    names[longest] = names[longest]:sub(1, -2)
    total = total - 1
  end
  x = 2
  for i, d in ipairs(city.districts) do
    local here = d.id == S.district
    local bg = here and C.sel or C.bg
    ui.text(x, ty, tostring(i), C.accent, bg)
    ui.text(x + 1, ty, names[i], here and C.fg or C.muted, bg)
    ui.zone(x, ty, #names[i] + 1, 1, "go:" .. d.id)
    x = x + #names[i] + 2
  end

  -- actions
  x, ty = 1, SH - 1
  for _, a in ipairs(actionList()) do
    local wdt = #a[1] + 1 + #a[2]
    if x > 1 and x + wdt - 1 > SW then x = 1; ty = ty + 1 end
    if ty > SH then break end
    ui.text(x, ty, a[1], a[4] and C.accent or C.dim, C.bg)
    ui.text(x + 2, ty, a[2], a[4] and C.fg or C.dim, C.bg)
    ui.zone(x, ty, wdt, 1, a[3])
    x = x + wdt + 1
  end
end

--------------------------------------------------------------- small windows
local function info(title, text) ui.message(title, text, t("btn.ok")) end

local function payMethods()
  local S = G.state()
  local list = { { id = "cash", label = t("pay.cash") .. " (" .. money(S.cash) .. ")" } }
  for _, a in ipairs(G.atmAccounts()) do
    list[#list + 1] = { id = a.bank, label = t("pay.atm") .. ": " .. nm(G.bankById(a.bank).name) .. " (" .. money(a.balance) .. ")" }
  end
  return list
end

-- Asks how to pay when the player has a bank card. Returns "cash", a bank id or nil.
local function askPayment(title, amount)
  local methods = payMethods()
  if #methods == 1 then return "cash" end
  local id, st = ui.dialog({ title = title, text = t("cc.pay") .. " " .. money(amount),
    list = { cols = { {} }, rows = U.map(methods, function(m) return { cells = { m.label } } end), activate = "ok" },
    buttons = { btn(t("btn.cancel"), "cancel"), btn(t("btn.ok"), "ok", true) }, cancel = "cancel" })
  if id == "ok" then return methods[st.sel].id end
end

local function qtyDialog(o)
  return ui.dialog({ title = o.title, text = o.text, error = o.error, cancel = "cancel",
    input = { kind = "number", label = t("qty"), value = o.value or o.max, min = o.min or 1, max = o.max, pct = true, info = o.info },
    buttons = { btn(t(o.cancelKey or "btn.cancel"), "cancel"), btn(o.okLabel, "ok", true) } })
end

--------------------------------------------------------------- events
local handleEvent

local function trade(kind, max)
  local S = G.state()
  if S.over or not sel then return end
  local g = G.goodById(sel)
  local err
  if kind == "buy" then
    local lim, p, why = G.buyLimit(sel)
    if lim <= 0 then return info(t("buy.title"), why) end
    if max then local _, ev = G.buy(sel, lim); return ev end
    while true do
      local id, st = qtyDialog({ title = t("buy.title"), okLabel = t("btn.buy"), max = lim, error = err,
        text = t("buy.text", { good = nm(g.name), price = money(p), max = lim }),
        info = function(q) return { { t("q.cost"), money(q * p) }, { t("q.cashAfter"), money(S.cash - q * p) },
          { t("q.spaceAfter"), (G.used() + q) .. " / " .. G.capacity() } } end })
      if id ~= "ok" then return end
      local e, ev = G.buy(sel, st.num)
      if not e then return ev end
      err = e
    end
  elseif kind == "sell" then
    local lim, p, why = G.sellLimit(sel)
    if lim <= 0 then return info(t("sell.title"), why) end
    if max then local _, ev = G.sell(sel, lim); return ev end
    local paid = S.inv[sel].paid
    while true do
      local id, st = qtyDialog({ title = t("sell.title"), okLabel = t("btn.sell"), max = lim, error = err,
        text = t("sell.text", { good = nm(g.name), price = money(p), max = lim }),
        info = function(q) return { { t("q.revenue"), money(q * p) }, { t("paid"), money(q * paid) },
          { t("q.profit"), money(q * (p - paid)), p >= paid and C.pos or C.neg } } end })
      if id ~= "ok" then return end
      local e, ev = G.sell(sel, st.num)
      if not e then return ev end
      err = e
    end
  elseif kind == "drop" then
    local x = S.inv[sel]
    if not x then return info(t("drop.title"), t("msg.selectInv")) end
    if max then G.drop(sel, x.qty); return end
    local id, st = qtyDialog({ title = t("drop.title"), okLabel = t("btn.drop"), max = x.qty,
      text = t("drop.text", { good = nm(g.name), max = x.qty }) })
    if id == "ok" then G.drop(sel, st.num) end
  end
end

local function offerWindow(o)
  local err
  while true do
    local id, st = qtyDialog({ title = t(o.offer == "buy" and "offer.buyTitle" or "offer.sellTitle"),
      text = t(o.offer == "buy" and "offer.buyText" or "offer.sellText", { good = nm(o.good.name), price = money(o.price), qty = o.maxQty }),
      okLabel = t(o.offer == "buy" and "btn.buy" or "btn.sell"), cancelKey = "btn.decline", max = o.lim, error = err,
      info = function(q) return { { o.offer == "buy" and t("q.cost") or t("q.revenue"), money(q * o.price) } } end })
    if id ~= "ok" then return end
    err = G.takeOffer(o, st.num)
    if not err then return end
  end
end

local function weaponPicker()
  local S = G.state()
  local ws = U.filter(W.items, function(i) return i.type == "weapon" and G.has(i.id) end)
  local rows, ids = { { cells = { t("weapon.hands") } } }, { false }
  local selIdx = 1
  for _, w in ipairs(ws) do
    rows[#rows + 1] = { cells = { nm(w.name) .. (w.ammo and (" (" .. (S.ammo[w.ammo] or 0) .. ")") or "") } }
    ids[#ids + 1] = w.id
    if S.weapon == w.id then selIdx = #rows end
  end
  local id, st = ui.dialog({ title = t("btn.selectWeapon"), list = { cols = { {} }, rows = rows, sel = selIdx, activate = "ok" },
    buttons = { btn(t("btn.cancel"), "cancel"), btn(t("btn.ok"), "ok", true) }, cancel = "cancel" })
  if id == "ok" then G.equip(ids[st.sel] or nil) end
end

local function weaponText()
  local S = G.state()
  if not settings.violence then return t("weapon.words") end
  local w = G.weapon()
  if not w then return t("weapon.hands") end
  return nm(w.name) .. (w.ammo and (" (" .. (S.ammo[w.ammo] or 0) .. ")") or "")
end

local function encounterWindow()
  local E = G.encounter()
  -- Draws the encounter and returns the list of actions.
  local function draw()
    local S = G.state()
    local SW, SH = ui.size()
    ui.clear()
    ui.fill(1, 1, SW, 1, E.done and C.head or C.neg)
    ui.text(2, 1, E.done and t("enc.over") or t("enc.title." .. E.type, { name = E.leader }), C.fg, E.done and C.head or C.neg)
    -- actions
    local acts = {}
    local fightLabel = settings.violence and t("btn.fight") or t("btn.talk")
    if not E.done then
      if E.type == "shark" then
        acts = { { "pay", t("btn.payLoan", { amount = money(E.loan.amount) }), S.cash >= E.loan.amount },
          { "time", t("btn.moreTime"), true }, { "run", t("btn.run"), true }, { "fight", fightLabel, true } }
      else
        acts = { { "run", t("btn.run"), true }, { "fight", fightLabel, true }, { "bribe", t("btn.bribe"), true },
          { "surrender", t("btn.surrender"), true }, { "droprun", t("btn.dropRun"), G.used() > 0 } }
      end
      if settings.violence then acts[#acts + 1] = { "weapon", t("btn.selectWeapon"), true, "W" } end
    end
    -- layout actions from the bottom
    local rowsA, row, x = {}, {}, 2
    for i, a in ipairs(acts) do
      local key = a[4] or tostring(i)
      local wdt = #key + 1 + #a[2]
      if x > 2 and x + wdt - 1 > SW then rowsA[#rowsA + 1] = row; row = {}; x = 2 end
      row[#row + 1] = { a = a, key = key, x = x, w = wdt }
      x = x + wdt + 2
    end
    if #row > 0 then rowsA[#rowsA + 1] = row end
    local bottom = SH - math.max(1, #rowsA) + 1
    if E.done then
      local lab = " " .. t("btn.continue") .. " "
      ui.text(SW - #lab, SH, lab, C.focusfg, C.focus)
      ui.zone(SW - #lab, SH, #lab, 1, "continue")
    else
      for ri, r in ipairs(rowsA) do
        for _, p in ipairs(r) do
          local ok = p.a[3]
          ui.text(p.x, bottom + ri - 1, p.key, ok and C.accent or C.dim, C.bg)
          ui.text(p.x + #p.key + 1, bottom + ri - 1, p.a[2], ok and C.fg or C.dim, C.bg)
          ui.zone(p.x, bottom + ri - 1, p.w, 1, "enc:" .. p.a[1])
        end
      end
    end
    -- you and them
    local my = bottom - 2
    local h = math.max(0, U.round(S.health))
    ui.text(2, my, ui.sub(t("health"), 10), C.muted, C.bg)
    ui.bar(13, my, 8, h / 100, ui.healthColor(h))
    ui.text(22, my, h .. "%", ui.healthColor(h), C.bg)
    local arm = G.armor()
    local gear = t("armor") .. ": " .. (arm and nm(arm.name) or t("none"))
    if settings.violence then gear = weaponText() .. ", " .. gear end
    ui.text(2, my + 1, ui.sub(gear, SW - 2), C.muted, C.bg)
    x = 2 + ui.text(2, my - 1, t("cc.foes") .. ":", C.muted, C.bg) + 1
    for i, f in ipairs(E.foes) do
      local name = i == 1 and E.leader or ("#" .. (i - 1))
      if x + #name - 1 <= SW then
        ui.text(x, my - 1, name, f.hp > 0 and C.neg or C.dim, C.bg)
        x = x + #name + 1
      end
    end
    -- story so far, newest at the bottom
    local lines = {}
    for _, l in ipairs(E.lines) do
      local col = ui.LOG[l[1]] or C.fg
      for _, w in ipairs(ui.wrap(l[2], SW - 2)) do lines[#lines + 1] = { w, col } end
    end
    local area = my - 5          -- rows 3 .. my-3; my-2 asks, my-1 lists the enemies
    local start = math.max(1, #lines - area + 1)
    for i = start, #lines do ui.text(2, 2 + i - start + 1, lines[i][1], lines[i][2], C.bg) end
    if not E.done then ui.text(2, my - 2, t("enc.what"), C.accent, C.bg) end
    return acts
  end
  local before = ui.backdrop
  ui.backdrop = function() draw() end
  while E do
    local acts = draw()
    local ev = ui.read()
    local cmd
    if ev.kind == "click" then cmd = ev.cmd
    elseif ev.kind == "char" then
      local n = tonumber(ev.ch)
      if n and acts[n] and not acts[n][4] then cmd = "enc:" .. acts[n][1] end
      if (ev.ch == "w" or ev.ch == "W") and settings.violence and not E.done then cmd = "enc:weapon" end
    elseif ev.kind == "key" and (ev.key == keys.enter or ev.key == keys.numPadEnter) and E.done then
      cmd = "continue"
    end
    if cmd == "continue" then ui.backdrop = before; return end
    local a = cmd and cmd:match("^enc:(%a+)$")
    if a then
      local ok = true
      for _, x2 in ipairs(acts) do if x2[1] == a then ok = x2[3] end end
      if ok then
        if a == "weapon" then weaponPicker()
        elseif a == "bribe" then
          local lo, hi, def = G.bribeRange()
          if not lo then G.bribe(0)
          else
            local id, st = ui.dialog({ title = t("bribe.title"), text = t("bribe.text", { min = money(lo), max = money(hi) }),
              cancel = "cancel", input = { kind = "number", label = "$", value = def, min = lo, max = hi, pct = true },
              buttons = { btn(t("btn.cancel"), "cancel"), btn(t("btn.bribe"), "ok", true) } })
            if id == "ok" then G.bribe(st.num) end
          end
        else
          G.encAction(a)
        end
        save()
      end
    end
  end
end

local function deathWindow(reason)
  local S = G.state()
  save()
  local id = ui.dialog({ title = t("death.title"), text = { reason, t("death.text", { day = S.day }) },
    buttons = { btn(t("btn.scores"), "scores"), btn(t("btn.ok"), "ok", true) } })
  if id == "scores" then A.scores() end
  return "title"
end

local function endWindow(ev)
  local S = G.state()
  local list = store.get("scores", {})
  list[#list + 1] = ev.entry
  store.set("scores", list)
  save()
  local score = ev.entry.score
  local text = {
    t("end.sub", { days = S.day }),
    { ui.pad(t("cash"), 12) .. money(S.cash) },
    { ui.pad(t("bank"), 12) .. money(G.bankTotal()) },
    { ui.pad(t("debt"), 12) .. money(G.debtTotal()), G.debtTotal() > 0 and C.neg or nil },
    { ui.pad(t("end.score"), 12) .. money(score), score >= 0 and C.pos or C.neg },
    { t("end.stats", { enc = S.stats.encounters, wins = S.stats.wins, esc = S.stats.escapes, arr = S.stats.arrests }), C.boxmuted },
  }
  local id = ui.dialog({ title = t(ev.retired and "end.retiredTitle" or "end.title"), text = text,
    buttons = { btn(t("btn.scores"), "scores"), btn(t("btn.ok"), "ok", true) } })
  if id == "scores" then A.scores() end
  return "title"
end

-- Shows what happened. Returns "title" when the game is over.
function handleEvent(ev)
  while ev do
    save()
    if ev.kind == "encounter" then
      encounterWindow()
      ev = G.endEncounter()
    elseif ev.kind == "offer" then
      offerWindow(ev)
      ev = nil
    elseif ev.kind == "arrest" then
      local S = G.state()
      local a, b = S.log[#S.log - 1], S.log[#S.log]
      info(t("enc.title.cops", { name = G.here().cops }), { a and a.text or "", b and b.text or "" })
      ev = nil
    elseif ev.kind == "dead" then
      return deathWindow(ev.reason)
    elseif ev.kind == "end" then
      return endWindow(ev)
    else
      ev = nil
    end
  end
  save()
end

--------------------------------------------------------------- places
local function hospitalWindow()
  local d = G.here()
  if not d.hospital then return end
  local err
  while true do
    local S = G.state()
    local price, need, def = G.hospitalInfo()
    if need <= 0 then return info(d.hospital, t("hosp.fine")) end
    local methods = payMethods()
    local o = { title = d.hospital, error = err, cancel = "cancel",
      text = { t("hosp.text", { price = money(price), need = need }), { t("health") .. ": " .. U.round(S.health) .. "%", ui.healthColor(S.health) } },
      input = { kind = "number", label = t("qty"), value = def, min = 1, max = need, pct = true,
        info = function(q) return { { t("q.cost"), money(q * price) } } end },
      buttons = { btn(t("btn.done"), "cancel"), btn(t("btn.heal"), "ok", true) } }
    if #methods > 1 then
      o.list = { cols = { {} }, header = { t("pay.method") }, rows = U.map(methods, function(m) return { cells = { m.label } } end) }
    end
    local id, st = ui.dialog(o)
    if id ~= "ok" then return end
    err = G.heal(st.num, methods[st.sel] and methods[st.sel].id or "cash")
    if not err then save(); return end
  end
end

local function newLoanWindow()
  local err
  local selIdx = 1
  while true do
    local rows = U.map(W.sharks, function(s)
      return { cells = { s.name, nm(G.distById(s.district).name), money(s.amount[1]) .. "-" .. money(s.amount[2]),
        T.int(G.sharkRate(s)) .. "%", tostring(s.days) } }
    end)
    local id, st = ui.dialog({ title = t("loan.newTitle"), text = t("loan.newText"), width = 51, error = err, cancel = "cancel",
      list = { cols = { { w = 9 }, {}, { w = 17, align = "r" }, { w = 4, align = "r" }, { w = 4, align = "r" } },
        header = { t("loan.shark"), t("loan.location"), t("loan.range"), "%", t("loan.days") }, rows = rows, sel = selIdx },
      input = { kind = "number", label = t("loan.amount"), value = "", min = 0 },
      buttons = { btn(t("btn.cancel"), "cancel"), btn(t("btn.borrow"), "ok", true) } })
    if id ~= "ok" then return end
    selIdx = st.sel
    err = G.borrow(W.sharks[st.sel].id, st.num)
    if not err then save(); return end
  end
end

local function loansWindow()
  local err, selIdx = nil, 1
  while true do
    local S = G.state()
    local rows = U.map(S.loans, function(l)
      local s = G.sharkById(l.shark)
      return { cells = { s.name, nm(G.distById(s.district).name), money(l.amount), T.int(G.sharkRate(s)) .. "%", tostring(l.due - S.day) },
        color = l.due - S.day < 0 and C.neg or nil }
    end)
    local o = { title = t("loan.title", { total = money(G.debtTotal()) }), width = 51, error = err, cancel = "done",
      text = #rows > 0 and t("loan.text") or t("loan.none"),
      buttons = { btn(t("btn.done"), "done"), btn(t("btn.newLoan"), "new", #rows == 0) } }
    if #rows > 0 then
      o.list = { cols = { { w = 9 }, {}, { w = 11, align = "r" }, { w = 4, align = "r" }, { w = 5, align = "r" } },
        header = { t("loan.shark"), t("loan.location"), t("loan.owed"), "%", t("cc.days") }, rows = rows, sel = selIdx,
        detail = function(i) return t("btn.payLoanShort") .. ": " .. money(G.loanPayoff(S.loans[i])) end }
      o.buttons[#o.buttons + 1] = btn(t("btn.payLoanShort"), "pay", true)
    end
    local id, st = ui.dialog(o)
    err = nil
    if id == "new" then newLoanWindow()
    elseif id == "pay" then
      selIdx = st.sel
      err = G.payLoan(st.sel)
      save()
    else return end
  end
end

local function newAccountWindow()
  local err, selIdx = nil, 1
  local S = G.state()
  local banks = G.banksHere()
  if #banks == 0 then return info(t("bank.newTitle"), t("bank.noneHere")) end
  while true do
    local rows = U.map(banks, function(b)
      return { cells = { nm(b.name), money(b.min), T.int(G.bankRate(b)) .. "%", b.atm and t("yes") or t("no") } }
    end)
    local id, st = ui.dialog({ title = t("bank.newTitle"), text = t("bank.newText"), width = 51, error = err, cancel = "cancel",
      list = { cols = { {}, { w = 9, align = "r" }, { w = 4, align = "r" }, { w = 6, align = "r" } },
        header = { t("bank.name"), t("bank.min"), "%", t("bank.atm") }, rows = rows, sel = selIdx },
      input = { kind = "number", label = t("bank.deposit"), value = math.floor(S.cash), min = 0, max = math.floor(S.cash) },
      buttons = { btn(t("btn.cancel"), "cancel"), btn(t("btn.openAccount"), "ok", true) } })
    if id ~= "ok" then return end
    selIdx = st.sel
    err = G.openAccount(banks[st.sel].id, st.num)
    if not err then save(); return end
  end
end

local function bankWindow()
  local err, selIdx = nil, 1
  while true do
    local S = G.state()
    local rows = U.map(S.accounts, function(a)
      local b = G.bankById(a.bank)
      return { cells = { nm(b.name), nm(G.distById(b.district).name), money(a.balance), T.int(G.bankRate(b)) .. "%", b.atm and t("yes") or t("no") } }
    end)
    local has = #rows > 0
    local o = { title = t("bank.title", { total = money(G.bankTotal()) }), width = 51, error = err, cancel = "done",
      text = { has and t("bank.text") or t("bank.none"), { t("cash") .. ": " .. money(S.cash), C.pos } },
      buttons = { btn(t("btn.done"), "done"), btn(t("btn.newAccount"), "new", not has) } }
    if has then
      o.list = { cols = { {}, { w = 12 }, { w = 11, align = "r" }, { w = 3, align = "r" }, { w = 5, align = "r" } },
        header = { t("bank.name"), t("loan.location"), t("bank.balance"), "%", t("bank.atm") }, rows = rows, sel = selIdx }
      o.input = { kind = "number", label = t("bank.amount"), value = "", min = 0 }
      for _, b in ipairs({ btn(t("btn.close"), "close"), btn(t("btn.withdrawAll"), "wall"), btn(t("btn.withdraw"), "w"),
        btn(t("btn.depositAll"), "dall"), btn(t("btn.deposit"), "d", true) }) do o.buttons[#o.buttons + 1] = b end
    end
    local id, st = ui.dialog(o)
    err = nil
    if id == "new" then newAccountWindow()
    elseif id == "done" or id == nil then return
    else
      selIdx = st.sel
      local i = st.sel
      if id == "close" then err = G.closeAccount(i)
      elseif id == "wall" then err = G.withdrawAll(i)
      elseif id == "w" then err = G.withdraw(i, st.num)
      elseif id == "dall" then err = G.depositAll(i)
      elseif id == "d" then err = G.deposit(i, st.num) end
      if selIdx > #S.accounts then selIdx = math.max(1, #S.accounts) end
      save()
    end
  end
end

local CATS = { "all", "storage", "armor", "vehicle", "weapon", "ammo", "tool" }

local function storeWindow()
  if not G.here().store then return end
  local tab, cat, err, selIdx = "buy", 1, nil, 1
  while true do
    local S = G.state()
    local cats = U.filter(CATS, function(c) return settings.violence or (c ~= "weapon" and c ~= "ammo") end)
    if cat > #cats then cat = 1 end
    local o = { title = t("shop.title", { place = nm(G.here().name) }), width = 51, error = err, cancel = "done" }
    local items
    if tab == "buy" then
      items = G.storeItems(cats[cat])
      table.sort(items, function(a, b) return S.storePrices[a.id] < S.storePrices[b.id] end)
      o.text = { { t("shop.cash", { cash = money(S.cash) }), C.pos }, { "< " .. t("cat." .. cats[cat]) .. " >", C.accent }, { t("cc.shop.hint"), C.boxmuted } }
      o.list = { cols = { {}, { w = 10, align = "r" } }, header = { t("shop.item"), t("shop.price") },
        rows = U.map(items, function(i)
          local mark = (G.has(i.id) and i.type ~= "ammo") and " *" or ""
          return { cells = { nm(i.name) .. mark, money(S.storePrices[i.id]) }, color = mark ~= "" and C.boxmuted or nil }
        end), sel = selIdx, activate = "buy",
        detail = function(i) return nm(items[i].desc) end }
      o.buttons = { btn(t("btn.done"), "done"), btn(t("shop.sellTab"), "tab"), btn(t("btn.buy"), "buy", true) }
      o.onKey = function(ev)
        if ev.kind == "key" and ev.key == keys.left then cat = (cat - 2) % #cats + 1; return "cat" end
        if ev.kind == "key" and ev.key == keys.right then cat = cat % #cats + 1; return "cat" end
      end
    else
      items = G.sellableItems()
      o.text = { { t("shop.cash", { cash = money(S.cash) }), C.pos }, { t("cc.shop.sellHint"), C.boxmuted } }
      o.list = { cols = { {}, { w = 10, align = "r" } }, header = { t("shop.item"), t("shop.price") }, empty = t("shop.nothingToSell"),
        rows = U.map(items, function(i)
          return { cells = { nm(i.name) .. ((S.items[i.id] or 0) > 1 and (" x" .. S.items[i.id]) or ""), money(U.round(S.storePrices[i.id] / 2)) } }
        end), sel = selIdx, activate = "sell" }
      o.buttons = { btn(t("btn.done"), "done"), btn(t("shop.buyTab"), "tab"), btn(t("btn.sell"), "sell", true, #items == 0) }
    end
    local id, st = ui.dialog(o)
    err = nil
    if id == "cat" then selIdx = 1
    elseif id == "tab" then tab = tab == "buy" and "sell" or "buy"; selIdx = 1
    elseif id == "buy" and items[st.sel] then
      selIdx = st.sel
      local it = items[st.sel]
      local method = askPayment(nm(it.name), S.storePrices[it.id])
      if method then err = G.buyItem(it.id, method); save() end
    elseif id == "sell" and items[st.sel] then
      selIdx = math.max(1, st.sel)
      G.sellItem(items[st.sel].id)
      save()
    elseif id == "done" or id == nil then return
    end
  end
end

local function itemsWindow()
  local selIdx = 1
  while true do
    local S = G.state()
    local owned = U.filter(W.items, function(i) return G.has(i.id) end)
    local ammo = {}
    for _, it in ipairs(W.items) do
      if it.type == "ammo" and (S.ammo[it.id] or 0) > 0 then ammo[#ammo + 1] = nm(it.name):gsub("%s*%(%d+%)", "") .. " " .. S.ammo[it.id] end
    end
    local v, a = G.vehicle(), G.armor()
    local text = {
      t("items.space", { used = G.used(), cap = G.capacity() }),
      { t("vehicle") .. ": " .. (v and nm(v.name) or t("vehicle.foot")) .. ", " .. t("armor") .. ": " .. (a and nm(a.name) or t("none")), C.boxmuted },
      { t("cc.weapon") .. ": " .. weaponText(), C.boxmuted },
    }
    if #ammo > 0 then text[#text + 1] = { t("items.ammo") .. ": " .. table.concat(ammo, ", "), C.boxmuted } end
    local rows = U.map(owned, function(i)
      local mark = (i.type == "weapon" and S.weapon == i.id) and (" [" .. t("items.equipped") .. "]") or ""
      return { cells = { nm(i.name) .. ((S.items[i.id] or 0) > 1 and (" x" .. S.items[i.id]) or "") .. mark }, color = mark ~= "" and C.pos or nil }
    end)
    local id, st = ui.dialog({ title = t("items.title"), width = 51, text = text, cancel = "done",
      list = { cols = { {} }, header = { t("shop.item") }, rows = rows, sel = selIdx, empty = t("items.none"),
        detail = function(i) return nm(owned[i].desc) end },
      buttons = { btn(t("btn.drop"), "drop", false, #owned == 0), btn(t("btn.equip"), "equip", false, not settings.violence),
        btn(t("btn.done"), "done", true) },
      onKey = function(ev, s) selIdx = s.sel end })
    selIdx = st and st.sel or 1
    if id == "drop" and owned[st.sel] then G.dropItem(owned[st.sel].id); save()
    elseif id == "equip" and owned[st.sel] and owned[st.sel].type == "weapon" then G.equip(owned[st.sel].id); save()
    elseif id == "done" or id == nil then return end
  end
end

--------------------------------------------------------------- full screen viewers
-- Shows lines { {text, color}, ... } with a title and tabs; returns on Backspace/Enter.
local function viewer(o)
  local SW, SH = ui.size()
  local off = o.offset or 0
  while true do
    ui.clear()
    ui.fill(1, 1, SW, 1, C.head)
    ui.text(2, 1, o.title, C.accent, C.head)
    local done = " " .. t("btn.done") .. " "
    ui.text(SW - #done + 1, 1, done, C.btnfg, C.btn)
    ui.zone(SW - #done + 1, 1, #done, 1, "done")
    local y = 2
    if o.tabs then
      local x = 2
      for i, tb in ipairs(o.tabs) do
        local on = i == o.tab
        local col = tb.disabled and C.dim or (on and C.focusfg or C.fg)
        ui.text(x, y, " " .. tb.label .. " ", col, on and C.focus or C.bg)
        ui.zone(x, y, #tb.label + 2, 1, "tab:" .. i)
        x = x + #tb.label + 3
      end
      y = y + 1
    end
    local lines = o.lines()
    local area = SH - y
    off = math.max(0, math.min(off, #lines - area))
    for i = 1, area do
      local l = lines[off + i]
      if l then
        if type(l[1]) == "table" then       -- segments
          local x = 1
          for _, sgm in ipairs(l) do x = x + ui.text(x, y + i - 1, sgm[1], sgm[2] or C.fg, sgm[3] or C.bg) end
        else
          ui.text(2, y + i - 1, l[1], l[2] or C.fg, C.bg)
        end
      end
    end
    if off > 0 then ui.text(SW, y, ui.UP, C.accent, C.bg) end
    if off + area < #lines then ui.text(SW, SH - 1, ui.DOWN, C.accent, C.bg) end
    ui.text(2, SH, ui.sub(o.hint or "", SW - 2), C.dim, C.bg)
    local ev = ui.read()
    local function setTab(i)
      if o.tabs[i] and not o.tabs[i].disabled then o.tab = i; off = 0; if o.onTab then o.onTab(i) end end
    end
    if ev.kind == "key" then
      local k = ev.key
      if k == keys.backspace or k == keys.enter or k == keys.numPadEnter then return
      elseif k == keys.up then if o.onUp and o.onUp() then off = 0 else off = off - 1 end
      elseif k == keys.down then if o.onDown and o.onDown() then off = 0 else off = off + 1 end
      elseif k == keys.pageUp then off = off - area
      elseif k == keys.pageDown then off = off + area
      elseif k == keys.home then off = 0
      elseif k == keys["end"] then off = #lines
      elseif o.tabs and k == keys.left then
        local i = o.tab
        repeat i = i - 1 until i < 1 or not o.tabs[i].disabled
        setTab(i)
      elseif o.tabs and (k == keys.right or k == keys.tab) then
        local i = o.tab
        repeat i = i + 1 until i > #o.tabs or not o.tabs[i].disabled
        setTab(i)
      end
    elseif ev.kind == "char" and o.tabs and tonumber(ev.ch) then setTab(tonumber(ev.ch))
    elseif ev.kind == "scroll" then off = off + ev.dir
    elseif ev.kind == "click" and ev.cmd then
      if ev.cmd == "done" then return end
      local i = ev.cmd:match("^tab:(%d+)$")
      if i then setTab(tonumber(i)) end
    end
  end
end

local function logWindow()
  local S = G.state()
  local SW = ui.size()
  viewer({ title = t("messages"), hint = t("cc.log.hint"), offset = 1e9, lines = function()
    local out = {}
    for _, l in ipairs(S.log) do
      local prefix = t("day") .. " " .. l.d .. ": "
      local ws = ui.wrap(prefix .. l.text, SW - 2)
      for i, w in ipairs(ws) do out[#out + 1] = { w, ui.LOG[l.cls] or (i == 1 and C.fg or C.fg) } end
    end
    return out
  end })
  seenLog = #S.log
end

local function chartsWindow()
  local S = G.state()
  local SW = ui.size()
  local lap = G.tracker()
  local tabs = { { label = t("cc.tab.history"), disabled = not lap }, { label = t("cc.tab.overview"), disabled = not lap },
    { label = t("cc.tab.finance") }, { label = t("cc.tab.profit") } }
  local gi = 1
  for i, g in ipairs(W.goods) do if g.id == sel then gi = i end end
  local ds = G.city().districts
  local o = { title = t("chart.title"), tabs = tabs, tab = lap and 1 or 3, hint = t("cc.chart.hint") }
  local function dnames(w)
    return U.map(ds, function(d) return ui.pad(nm(d.name), w, "r") end)
  end
  o.onUp = function() if o.tab == 1 then gi = (gi - 2) % #W.goods + 1; return true end end
  o.onDown = function() if o.tab == 1 then gi = gi % #W.goods + 1; return true end end
  o.lines = function()
    local out = {}
    if not lap and o.tab <= 2 then o.tab = 3 end
    if not lap then
      for _, w in ipairs(ui.wrap(t("chart.needLaptop"), SW - 2)) do out[#out + 1] = { w, C.dim } end
    end
    if o.tab == 1 then
      local g = W.goods[gi]
      out[#out + 1] = { { " ", C.fg }, { ui.UP .. ui.DOWN .. " " .. nm(g.name), C.accent } }
      local s = S.seen[g.id] or {}
      local byDay, days = {}, {}
      for di, d in ipairs(ds) do
        for _, x in ipairs(s[d.id] or {}) do
          if not byDay[x[1]] then byDay[x[1]] = {}; days[#days + 1] = x[1] end
          byDay[x[1]][di] = x[2]
        end
      end
      if #days == 0 then
        out[#out + 1] = { t("chart.noData"), C.muted }
      else
        table.sort(days, function(a, b) return a > b end)
        local lo, hi = G.seenHiLo(g.id)
        local avg = G.seenAvg(g.id)
        for _, w in ipairs(ui.wrap(t("chart.range", { good = nm(g.name), min = money(lo), max = money(hi), avg = money(avg) }), SW - 2)) do
          out[#out + 1] = { w, C.muted }
        end
        local head = { { " " .. ui.pad(t("chart.dayShort"), 5), C.muted } }
        for _, n in ipairs(dnames(8)) do head[#head + 1] = { " " .. n, C.muted } end
        out[#out + 1] = head
        for _, day in ipairs(days) do
          local row = { { " " .. ui.pad(tostring(day), 5), C.fg } }
          for di = 1, #ds do
            local p = byDay[day][di]
            local col = C.fg
            if p == lo then col = C.pos elseif p == hi then col = C.accent end
            row[#row + 1] = { " " .. ui.pad(p and money(p) or "", 8, "r"), col }
          end
          out[#out + 1] = row
        end
      end
    elseif o.tab == 2 then
      local head = { { " " .. ui.pad(t("good"), 10), C.muted } }
      for _, n in ipairs(dnames(7)) do head[#head + 1] = { " " .. n, C.muted } end
      out[#out + 1] = head
      for _, g in ipairs(W.goods) do
        local s = S.seen[g.id] or {}
        local last, vals = {}, {}
        for di, d in ipairs(ds) do
          local a = s[d.id]
          if a and #a > 0 then last[di] = a[#a]; vals[#vals + 1] = a[#a][2] end
        end
        local lo, hi = math.huge, -math.huge
        for _, v in ipairs(vals) do lo = math.min(lo, v); hi = math.max(hi, v) end
        local row = { { " " .. ui.pad(nm(g.name), 10), C.fg } }
        for di = 1, #ds do
          local x = last[di]
          local txt, col = "-", C.dim
          if x then
            txt = money(x[2])
            col = (S.day - x[1] == 0) and C.fg or C.muted
            if #vals > 1 and x[2] == lo then col = C.pos elseif #vals > 1 and x[2] == hi then col = C.accent end
          end
          row[#row + 1] = { " " .. ui.pad(txt, 7, "r"), col }
        end
        out[#out + 1] = row
      end
      for _, w in ipairs(ui.wrap(t("chart.ovHint"), SW - 2)) do out[#out + 1] = { w, C.dim } end
    elseif o.tab == 3 then
      local cols = { t("chart.dayShort"), t("cash"), t("bank"), t("debt"), t("networth") }
      local wd = { 4, 11, 10, 10, 11 }
      local head = {}
      for i, c in ipairs(cols) do head[#head + 1] = { " " .. ui.pad(c, wd[i], i > 1 and "r" or "l"), C.muted } end
      out[#out + 1] = head
      for i = #S.fin, 1, -1 do
        local f = S.fin[i]
        local nw = f.cash + f.bank - f.debt
        out[#out + 1] = { { " " .. ui.pad(tostring(f.d), 4), C.fg }, { " " .. ui.pad(money(f.cash), 11, "r"), C.fg },
          { " " .. ui.pad(money(f.bank), 10, "r"), C.fg }, { " " .. ui.pad(money(f.debt), 10, "r"), f.debt > 0 and C.neg or C.fg },
          { " " .. ui.pad(money(nw), 11, "r"), nw >= 0 and C.pos or C.neg } }
      end
    else
      local rows = {}
      for id, v in pairs(S.profit) do rows[#rows + 1] = { id, v } end
      table.sort(rows, function(a, b) return a[2] > b[2] end)
      if #rows == 0 then out[#out + 1] = { t("chart.noProfit"), C.muted } end
      local max = 1
      for _, r in ipairs(rows) do max = math.max(max, math.abs(r[2])) end
      local bw = SW - 2 - 16 - 12
      for _, r in ipairs(rows) do
        local n = math.max(1, math.floor(math.abs(r[2]) / max * bw + 0.5))
        out[#out + 1] = { { " " .. ui.pad(nm(G.goodById(r[1]).name), 16) .. " ", C.fg },
          { (" "):rep(n), C.fg, r[2] >= 0 and C.pos or C.neg }, { " " .. money(r[2]), C.muted } }
      end
    end
    return out
  end
  viewer(o)
end

--------------------------------------------------------------- characters, settings, scores
local function chars()
  return store.get("chars", { { name = "Default", skills = { combat = 60, evade = 60, strength = 60, barter = 60 } } })
end

local SKILLS = { "combat", "evade", "strength", "barter" }

local function charWindow()
  local base, bonus = 60, 10
  local fields = { { label = t("char.name"), kind = "text", value = "", maxLen = 24 } }
  for _, k in ipairs(SKILLS) do
    fields[#fields + 1] = { label = t("skill." .. k), kind = "number", value = base, min = 0, max = 100, step = 1, skill = k }
  end
  local function left()
    local n = bonus
    for i = 2, #fields do n = n - ((fields[i].value or 0) - base) end
    return n
  end
  local err
  while true do
    local id = ui.form({ title = t("char.title"), text = t("char.text"), fields = fields, labelWidth = 14, error = err,
      hint = t("cc.form.hint"),
      status = function()
        local n = left()
        return t("char.points", { n = n }), n < 0 and C.neg or C.accent
      end,
      onChange = function(fs, i)
        local f = fs[i]
        if f.kind == "number" then
          f.value = math.max(0, math.min(100, f.value or 0))
          local n = left()
          if n < 0 then f.value = f.value + n end
        end
      end,
      buttons = { btn(t("btn.cancel"), "cancel"), btn(t("btn.createChar"), "ok", true) } })
    if id ~= "ok" then return nil end
    local name = (fields[1].value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then err = t("msg.nameNeeded")
    elseif left() < 0 then err = t("msg.tooManyPoints")
    else
      local cs = chars()
      local skills = {}
      for i = 2, #fields do skills[fields[i].skill] = fields[i].value end
      cs[#cs + 1] = { name = name, skills = skills }
      store.set("chars", cs)
      return #cs
    end
  end
end

local function charLabel(c)
  local s = c.skills
  return c.name .. " " .. s.combat .. "/" .. s.evade .. "/" .. s.strength .. "/" .. s.barter
end

local function newGameWindow()
  local charIdx = 1
  local lengths = U.map(P.lengths, function(l) return l > 0 and t("len.days", { n = l }) or t("len.endless") end)
  local lenIdx = U.indexOf(P.lengths, 30) or 1
  local econIdx, combatIdx = 2, 2
  while true do
    local cs = chars()
    charIdx = math.min(charIdx, #cs)
    local fields = {
      { label = t("new.length"), kind = "choice", options = lengths, idx = lenIdx },
      { label = t("new.location"), kind = "choice", options = { nm(W.cities[1].name) }, idx = 1 },
      { label = t("scores.econ"), kind = "choice", options = U.map(P.economy, function(p) return nm(p.name) end), idx = econIdx },
      { label = t("scores.combat"), kind = "choice", options = U.map(P.combat, function(p) return nm(p.name) end), idx = combatIdx },
      { label = t("new.char"), kind = "choice", options = U.map(cs, charLabel), idx = charIdx },
    }
    local skillsLine = t("cc.charSkills") .. ": " .. table.concat(U.map(SKILLS, function(k) return t("skill." .. k) end), "/")
    local id = ui.form({ title = t("new.title"), fields = fields, labelWidth = 14, width = 50, hint = t("cc.form.hint") .. " " .. skillsLine,
      buttons = { btn(t("btn.back"), "back"), btn(t("btn.newChar"), "char"), btn(t("btn.play"), "play", true) }, cancel = "back" })
    lenIdx, econIdx, combatIdx, charIdx = fields[1].idx, fields[3].idx, fields[4].idx, fields[5].idx
    if id == "char" then
      local n = charWindow()
      if n then charIdx = n end
    elseif id == "play" then
      local c = U.copy(cs[charIdx])
      G.newGame({ length = P.lengths[lenIdx], econ = P.economy[econIdx].id, combat = P.combat[combatIdx].id, char = c })
      sel, top, seenLog = nil, 1, 0
      save()
      return true
    else
      return false
    end
  end
end

function A.settingsWindow()
  local langIdx = U.indexOf(T.codes, settings.lang) or 1
  local fields = {
    { label = t("set.lang"), kind = "choice", options = U.map(T.codes, function(c) return T.names[c] end), idx = langIdx },
    { label = t("set.violence"), kind = "toggle", value = settings.violence, on = t("yes"), off = t("no") },
    { label = t("cc.set.keepCash"), kind = "number", value = settings.keepCash, min = 0, step = 100 },
    { label = t("cc.set.keepBank"), kind = "number", value = settings.keepBank, min = 0, step = 100 },
  }
  local id = ui.form({ title = t("set.title"), fields = fields, width = 51, labelWidth = 26, text = t("set.violenceHint"),
    hint = t("cc.form.hint"), cancel = "cancel",
    buttons = { btn(t("btn.cancel"), "cancel"), btn(t("btn.ok"), "ok", true) } })
  if id ~= "ok" then return end
  settings.lang = T.codes[fields[1].idx]
  settings.violence = fields[2].value
  settings.keepCash = math.max(0, fields[3].value or 0)
  settings.keepBank = math.max(0, fields[4].value or 0)
  store.set("settings", settings)
  applySettings()
end

function A.scores()
  while true do
    local list = store.get("scores", {})
    table.sort(list, function(a, b) return a.score > b.score end)
    local function lname(s) return s.length > 0 and t("len.days", { n = s.length }) or (t("len.endless") .. " (" .. s.days .. ")") end
    local rows = U.map(list, function(s)
      return { cells = { s.date or "", s.name, lname(s), money(s.score) }, colors = { nil, nil, nil, s.score >= 0 and C.pos or C.neg } }
    end)
    local id = ui.dialog({ title = t("scores.title"), width = 51, cancel = "done",
      list = { cols = { { w = 10 }, {}, { w = 13 }, { w = 11, align = "r" } }, rows = rows, empty = t("scores.none"),
        header = { t("scores.date"), t("scores.char"), t("scores.length"), t("end.score") },
        detail = function(i)
          local s = list[i]
          local e, c = U.find(P.economy, s.econ), U.find(P.combat, s.combat)
          return t("scores.econ") .. ": " .. nm(e and e.name) .. ", " .. t("scores.combat") .. ": " .. nm(c and c.name)
        end },
      buttons = { btn(t("btn.clearScores"), "clear", false, #list == 0), btn(t("btn.done"), "done", true) } })
    if id == "clear" then
      if ui.confirm(t("btn.clearScores"), t("scores.confirmClear"), t("yes"), t("no")) then store.set("scores", {}) end
    else
      return
    end
  end
end

local function helpWindow()
  info(t("menu.keysTitle"), t("cc.keysHelp"))
end

-- Returns "title" to leave the game, "new" for a new game, or nil.
local function menuWindow()
  local S = G.state()
  local items = {
    { "back", t("btn.backToGame") }, { "settings", t("btn.settings") }, { "scores", t("btn.scores") },
    { "help", t("menu.keysTitle") },
  }
  if S.length == 0 and not S.over then items[#items + 1] = { "retire", t("btn.retire") } end
  items[#items + 1] = { "new", t("btn.newGame") }
  items[#items + 1] = { "title", t("btn.toTitle") }
  local id, st = ui.dialog({ title = t("menu.title"), width = 34, cancel = "cancel",
    list = { cols = { {} }, rows = U.map(items, function(i) return { cells = { i[2] } } end), activate = "ok" },
    buttons = { btn(t("btn.ok"), "ok", true) } })
  if id ~= "ok" then return end
  local what = items[st.sel][1]
  if what == "settings" then A.settingsWindow()
  elseif what == "scores" then A.scores()
  elseif what == "help" then helpWindow()
  elseif what == "retire" then
    if ui.confirm(t("retire.title"), t("retire.text", { score = money(G.netWorth()) }), t("btn.retire"), t("btn.cancel")) then
      return handleEvent(G.endGame(true))
    end
  elseif what == "new" then save(); return "new"
  elseif what == "title" then save(); return "title"
  end
end

--------------------------------------------------------------- game loop
local function moveSel(d)
  local rows, idx = keepSelection()
  if #rows == 0 then return end
  idx = math.max(1, math.min(#rows, idx + d))
  sel = rows[idx].id
end

-- Runs the main screen until the player leaves. Returns "title" or "new".
local function gameLoop()
  ui.backdrop = A.drawMain
  while true do
    local S = G.state()
    A.drawMain()
    local ev = ui.read()
    local cmd, max = nil, ui.ctrl
    if ev.kind == "char" then
      local ch = ev.ch
      local lower = ch:lower()
      if ch ~= lower then max = true end
      local map = { b = "buy", s = "sell", d = "drop", h = "hosp", l = "loans", n = "bank", t = "store",
        e = "items", c = "charts", j = "log", m = "menu", ["0"] = "stay" }
      cmd = map[lower]
      local n = tonumber(ch)
      if n and n >= 1 then
        local d = G.city().districts[n]
        if d then cmd = "go:" .. d.id end
      end
    elseif ev.kind == "key" then
      local k = ev.key
      if k == keys.up then moveSel(-1)
      elseif k == keys.down then moveSel(1)
      elseif k == keys.pageUp then moveSel(-tableHeight())
      elseif k == keys.pageDown then moveSel(tableHeight())
      elseif k == keys.enter or k == keys.numPadEnter then
        if sel and S.market[sel] and not S.inv[sel] then cmd = "buy" elseif sel and S.inv[sel] then cmd = "sell" end
      end
    elseif ev.kind == "scroll" then
      moveSel(ev.dir)
    elseif ev.kind == "click" and ev.cmd then
      local id = ev.cmd:match("^good:(.+)$")
      if id then
        if id == sel then
          cmd = (S.market[id] and not S.inv[id]) and "buy" or (S.inv[id] and "sell") or nil
        else
          sel = id
        end
      else
        cmd = ev.cmd
      end
    end

    local result
    if cmd == "menu" then
      result = menuWindow()
      ui.backdrop = A.drawMain
    elseif cmd == "log" then logWindow()
    elseif cmd == "charts" then chartsWindow()
    elseif S.over then
      if cmd then result = "title" end
    elseif cmd == "buy" or cmd == "sell" or cmd == "drop" then
      local ev2 = trade(cmd, max)
      result = handleEvent(ev2)
    elseif cmd == "stay" then
      seenLog = #S.log
      result = handleEvent(G.travel(S.district))
    elseif cmd and cmd:match("^go:") then
      seenLog = #S.log
      result = handleEvent(G.travel(cmd:sub(4)))
    elseif cmd == "hosp" then hospitalWindow()
    elseif cmd == "loans" then loansWindow()
    elseif cmd == "bank" then bankWindow()
    elseif cmd == "store" then storeWindow()
    elseif cmd == "items" then itemsWindow()
    end
    if cmd then save() end
    if result == "title" or result == "new" then return result end
  end
end

--------------------------------------------------------------- title screen
local LOGO = {
  O = { "###", "# #", "# #", "# #", "###" }, V = { "# #", "# #", "# #", "# #", " # " },
  E = { "###", "#  ", "## ", "#  ", "###" }, R = { "## ", "# #", "## ", "# #", "# #" },
  W = { "# #", "# #", "# #", "###", "# #" }, L = { "#  ", "#  ", "#  ", "#  ", "###" },
  D = { "## ", "# #", "# #", "# #", "## " },
}

local function drawTitle()
  local SW, SH = ui.size()
  ui.clear()
  local word = "OVERWORLD"
  local x0 = math.floor((SW - (#word * 4 - 1)) / 2) + 1
  for i = 1, #word do
    local g = LOGO[word:sub(i, i)]
    for row = 1, 5 do
      local line = g[row]
      for col = 1, 3 do
        if line:sub(col, col) == "#" then ui.fill(x0 + (i - 1) * 4 + col - 1, 1 + row, 1, 1, C.accent) end
      end
    end
  end
  local tag = ui.wrap(t("title.tag"), SW - 6)
  for i, l in ipairs(tag) do ui.text(math.floor((SW - #l) / 2) + 1, 7 + i, l, C.muted, C.bg) end
  if A.notice then ui.text(math.floor((SW - #A.notice) / 2) + 1, 8 + #tag, A.notice, C.pos, C.bg) end
end

local function titleScreen()
  ui.backdrop = drawTitle
  while true do
    local saved = store.get("save", nil)
    local items = {}
    if saved and not saved.over then items[#items + 1] = { "continue", t("btn.continueGame") } end
    items[#items + 1] = { "new", t("btn.newGame") }
    items[#items + 1] = { "scores", t("btn.scores") }
    items[#items + 1] = { "settings", t("btn.settings") }
    items[#items + 1] = { "help", t("menu.keysTitle") }
    items[#items + 1] = { "quit", t("cc.btn.quit") }
    -- the menu sits below the logo
    local SW, SH = ui.size()
    local mw = 30
    local x0 = math.floor((SW - mw) / 2) + 1
    local y0 = SH - #items
    local selIdx = 1
    local chosen
    while not chosen do
      drawTitle()
      for i, it in ipairs(items) do
        local on = i == selIdx
        ui.text(x0, y0 + i - 1, ui.pad((on and "> " or "  ") .. it[2], mw), on and C.focusfg or C.fg, on and C.focus or C.bg)
        ui.zone(x0, y0 + i - 1, mw, 1, "item:" .. i)
      end
      local ev = ui.read()
      if ev.kind == "key" then
        if ev.key == keys.up then selIdx = (selIdx - 2) % #items + 1
        elseif ev.key == keys.down then selIdx = selIdx % #items + 1
        elseif ev.key == keys.enter or ev.key == keys.numPadEnter then chosen = items[selIdx][1] end
      elseif ev.kind == "scroll" then selIdx = math.max(1, math.min(#items, selIdx + ev.dir))
      elseif ev.kind == "click" and ev.cmd then
        local i = tonumber(ev.cmd:match("^item:(%d+)$"))
        if i then chosen = items[i][1] end
      end
    end
    if chosen == "quit" then return
    elseif chosen == "continue" then
      G.load(saved)
      sel, top, seenLog = nil, 1, #saved.log
      local r = gameLoop()
      while r == "new" do
        ui.backdrop = drawTitle
        if newGameWindow() then r = gameLoop() else r = "title" end
      end
      ui.backdrop = drawTitle
    elseif chosen == "new" then
      local r = newGameWindow() and gameLoop() or "title"
      while r == "new" do
        ui.backdrop = drawTitle
        if newGameWindow() then r = gameLoop() else r = "title" end
      end
      ui.backdrop = drawTitle
    elseif chosen == "scores" then A.scores()
    elseif chosen == "settings" then A.settingsWindow()
    elseif chosen == "help" then helpWindow()
    end
  end
end

--------------------------------------------------------------- start
-- opts.notice: a line for the title screen (e.g. "Updated to abc1234").
function A.run(dataDir, opts)
  A.notice = opts and opts.notice
  store.init(dataDir)
  local s = store.get("settings", nil)
  settings = {}
  for k, v in pairs(DEFAULT_SETTINGS) do settings[k] = v end
  for k, v in pairs(s or {}) do settings[k] = v end
  applySettings()
  local SW, SH = ui.size()
  if SW < 51 or SH < 19 then
    print(t("cc.needSize"))
    return
  end
  -- Texts start in English; other languages are picked in the settings.
  titleScreen()
end

-- Save the running game (used when the program is stopped).
function A.save() save() end

return A
