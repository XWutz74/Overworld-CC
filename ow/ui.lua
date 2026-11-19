--[[
  Overworld-CC - screen building blocks: text, bars, clickable zones,
  dialog windows (text, list, number or text input, buttons) and forms.
  Everything works with the keyboard and, on advanced computers, the mouse.
  Esc and the F keys are not used: Minecraft keeps them for itself.
]]
local ui = {}

ui.C = {
  bg = colors.black, fg = colors.white, muted = colors.lightGray, dim = colors.gray,
  head = colors.gray, headfg = colors.white, accent = colors.orange,
  pos = colors.lime, neg = colors.red, sel = colors.blue, tip = colors.lightBlue, event = colors.yellow,
  box = colors.gray, boxfg = colors.white, boxmuted = colors.lightGray,
  title = colors.orange, titlefg = colors.black,
  btn = colors.lightGray, btnfg = colors.black, focus = colors.orange, focusfg = colors.black, off = colors.gray,
  field = colors.black, fieldfg = colors.white,
}
local C = ui.C
ui.LOG = { good = C.pos, bad = C.neg, event = C.event, tip = C.tip, miss = C.muted }
ui.UP, ui.DOWN, ui.RIGHT = string.char(30), string.char(31), string.char(16)

ui.zones = {}
ui.ctrl = false
ui.backdrop = nil   -- function that redraws what is behind a dialog

function ui.size() return term.getSize() end

function ui.sub(s, n)
  s = tostring(s)
  if n <= 0 then return "" end
  if #s > n then return s:sub(1, n) end
  return s
end

function ui.pad(s, w, align)
  s = ui.sub(s, w)
  local gap = w - #s
  if align == "r" then return (" "):rep(gap) .. s end
  if align == "c" then
    local l = math.floor(gap / 2)
    return (" "):rep(l) .. s .. (" "):rep(gap - l)
  end
  return s .. (" "):rep(gap)
end

function ui.text(x, y, s, fg, bg, maxw)
  local W = ui.size()
  s = tostring(s)
  if x < 1 then s = s:sub(2 - x); x = 1 end
  s = ui.sub(s, math.min(maxw or 999, W - x + 1))
  if s == "" then return 0 end
  term.setCursorPos(x, y)
  if fg then term.setTextColor(fg) end
  if bg then term.setBackgroundColor(bg) end
  term.write(s)
  return #s
end

function ui.fill(x, y, w, h, bg)
  if w <= 0 then return end
  term.setBackgroundColor(bg)
  local line = (" "):rep(w)
  for yy = y, y + h - 1 do
    term.setCursorPos(x, yy)
    term.write(line)
  end
end

function ui.clear()
  term.setBackgroundColor(C.bg)
  term.setTextColor(C.fg)
  term.clear()
  ui.zones = {}
end

function ui.zone(x, y, w, h, cmd)
  ui.zones[#ui.zones + 1] = { x = x, y = y, w = w, h = h, cmd = cmd }
end

function ui.hit(x, y)
  for i = #ui.zones, 1, -1 do
    local z = ui.zones[i]
    if x >= z.x and x < z.x + z.w and y >= z.y and y < z.y + z.h then return z.cmd end
  end
end

-- Health/space bar. frac 0..1.
function ui.bar(x, y, w, frac, color, back)
  local n = math.max(0, math.min(w, math.floor(frac * w + 0.5)))
  ui.fill(x, y, n, 1, color)
  ui.fill(x + n, y, w - n, 1, back or C.dim)
end

function ui.healthColor(h)
  if h > 60 then return C.pos elseif h > 30 then return C.event end
  return C.neg
end

-- Word wrap. "|" or "\n" start a new line.
function ui.wrap(s, w)
  local out = {}
  for para in (tostring(s) .. "\n"):gsub("|", "\n"):gmatch("(.-)\n") do
    if #para <= w then
      out[#out + 1] = para       -- fits: keep it exactly (spacing used for columns)
    else
    local line = ""
    for word in para:gmatch("%S+") do
      while #word > w do
        if line ~= "" then out[#out + 1] = line; line = "" end
        out[#out + 1] = word:sub(1, w)
        word = word:sub(w + 1)
      end
      if line == "" then line = word
      elseif #line + 1 + #word <= w then line = line .. " " .. word
      else out[#out + 1] = line; line = word end
    end
    out[#out + 1] = line
    end
  end
  return out
end

--------------------------------------------------------------- input
-- Waits for the next useful event. Ctrl+T (terminate) raises an error the
-- program catches, so the game can be saved first.
function ui.read()
  while true do
    local e = { os.pullEventRaw() }
    local n = e[1]
    if n == "terminate" then
      error({ terminate = true }, 0)
    elseif n == "key" then
      if e[2] == keys.leftCtrl or e[2] == keys.rightCtrl then ui.ctrl = true
      else return { kind = "key", key = e[2] } end
    elseif n == "key_up" then
      if e[2] == keys.leftCtrl or e[2] == keys.rightCtrl then ui.ctrl = false end
    elseif n == "char" then
      return { kind = "char", ch = e[2] }
    elseif n == "mouse_click" then
      return { kind = "click", x = e[3], y = e[4], button = e[2], cmd = ui.hit(e[3], e[4]) }
    elseif n == "mouse_scroll" then
      return { kind = "scroll", dir = e[2], x = e[3], y = e[4] }
    elseif n == "term_resize" then
      return { kind = "resize" }
    end
  end
end

--------------------------------------------------------------- buttons
local function layoutButtons(buttons, width)
  local rows, row, x = {}, {}, 0
  for i, b in ipairs(buttons) do
    local bw = #b.label + 2
    if x > 0 and x + 1 + bw > width then
      rows[#rows + 1] = row; row = {}; x = 0
    end
    if x > 0 then x = x + 1 end
    row[#row + 1] = { i = i, x = x, w = bw }
    x = x + bw
  end
  if #row > 0 then rows[#rows + 1] = row end
  for _, r in ipairs(rows) do
    local last = r[#r]
    r.width = last.x + last.w
  end
  return rows
end

local function drawButtons(rows, buttons, focus, x0, y0, width)
  for ri, r in ipairs(rows) do
    local off = width - r.width       -- right aligned like a dialog footer
    for _, p in ipairs(r) do
      local b = buttons[p.i]
      local bg, fg = C.btn, C.btnfg
      if b.disabled then bg, fg = C.off, C.boxmuted
      elseif p.i == focus then bg, fg = C.focus, C.focusfg end
      local x, y = x0 + off + p.x, y0 + ri - 1
      ui.text(x, y, " " .. b.label .. " ", fg, bg)
      ui.zone(x, y, p.w, 1, "btn:" .. p.i)
    end
  end
end

local function moveFocus(buttons, focus, dir)
  local n = #buttons
  if n == 0 then return focus end
  local i = focus or 0
  for _ = 1, n do
    i = (i - 1 + dir) % n + 1
    if not buttons[i].disabled then return i end
  end
  return focus
end

local function startFocus(buttons)
  for i, b in ipairs(buttons) do if b.primary and not b.disabled then return i end end
  for i, b in ipairs(buttons) do if not b.disabled then return i end end
end

--------------------------------------------------------------- dialog
--[[
  ui.dialog{
    title, text (string or list of strings / {text, color}), width,
    list = { cols = { {w = 10, align = "r"}, ... (w = nil: takes the rest) },
             header = {...}, rows = { {cells = {...}, colors = {...}, color = c} },
             sel = 1, empty = "text", detail = function(sel) -> text, activate = button id },
    input = { kind = "number" | "text", label, value, min, max, pct = true, maxLen,
              info = function(n) -> { {label, value, color}, ... } },
    buttons = { {label, id, primary = true, disabled = true}, ... },
    cancel = id (Backspace), keys = { [char] = id }, error = text, onKey = function(ev, st) -> id
  }
  Returns the id of the pressed button and the state { sel, num, text }.
]]
function ui.dialog(o)
  local SW, SH = ui.size()
  local w = math.min(SW, o.width or 44)
  local iw = w - 2
  local buttons = o.buttons or {}
  local list, input = o.list, o.input
  local st = { sel = 1, top = 1, focus = startFocus(buttons), fresh = true, text = "" }
  if list then st.sel = math.max(1, math.min(list.sel or 1, #list.rows)) end
  if input and input.value ~= nil then st.text = tostring(input.value) end
  local err = o.error

  local function num()
    local n = tonumber(st.text)
    return n and math.floor(n)
  end
  local function clampNum(n)
    n = n or input.min or 0
    if input.min and n < input.min then n = input.min end
    if input.max and n > input.max then n = input.max end
    return n
  end
  local function setNum(n) st.text = tostring(clampNum(n)); st.fresh = false end

  while true do
    if ui.backdrop then ui.backdrop() else ui.clear() end
    ui.zones = {}
    -- content
    local textLines = {}
    local paras = o.text
    if type(paras) == "string" then paras = { paras } end
    for _, p in ipairs(paras or {}) do
      local s, c = p, C.boxfg
      if type(p) == "table" then s, c = p[1], p[2] or C.boxfg end
      for _, l in ipairs(ui.wrap(s, iw)) do textLines[#textLines + 1] = { l, c } end
    end
    local btnRows = layoutButtons(buttons, iw)
    local info = (input and input.info) and input.info(clampNum(num())) or {}
    local detail = {}
    if list and list.detail and list.rows[st.sel] then
      local d = list.detail(st.sel)
      if d and d ~= "" then detail = ui.wrap(d, iw) end
      while #detail > 2 do table.remove(detail) end
    end
    local errLines = err and ui.wrap(err, iw) or {}
    local hasBody = list or input
    local fixed = 1 + 1 + #info + #errLines + (#btnRows > 0 and (#btnRows + 1) or 0) + (input and 1 or 0) + #detail
    if list then fixed = fixed + 1 end                       -- header
    if #textLines > 0 and hasBody then fixed = fixed + 1 end -- gap
    local listRows = 0
    if list then
      local room = SH - fixed - #textLines
      if room < 3 then
        local cut = math.min(#textLines, 3 - room)
        for _ = 1, cut do table.remove(textLines) end
        room = SH - fixed - #textLines
      end
      listRows = math.max(1, math.min(math.max(#list.rows, 1), room))
    else
      while #textLines > 0 and fixed + #textLines > SH do table.remove(textLines) end
    end
    local h = fixed + #textLines + listRows
    local x0 = math.floor((SW - w) / 2) + 1
    local y0 = math.max(1, math.floor((SH - h) / 2) + 1)
    ui.fill(x0, y0, w, h, C.box)
    ui.fill(x0, y0, w, 1, C.title)
    ui.text(x0 + 1, y0, ui.sub(o.title or "", iw), C.titlefg, C.title)
    local y = y0 + 2
    for _, l in ipairs(textLines) do ui.text(x0 + 1, y, l[1], l[2], C.box); y = y + 1 end
    if #textLines > 0 and hasBody then y = y + 1 end

    -- list
    if list then
      local cols, fixedW, flex = list.cols, 0, nil
      for i, c in ipairs(cols) do
        if c.w then fixedW = fixedW + c.w else flex = i end
      end
      local widths = {}
      for i, c in ipairs(cols) do widths[i] = c.w or math.max(1, iw - 1 - fixedW - (#cols - 1)) end
      local function drawRow(yy, cells, fg, bg, cellColors)
        ui.fill(x0 + 1, yy, iw, 1, bg)
        local xx = x0 + 1
        for i, c in ipairs(cols) do
          ui.text(xx, yy, ui.pad(cells[i] or "", widths[i], c.align), (cellColors and cellColors[i]) or fg, bg)
          xx = xx + widths[i] + 1
        end
      end
      drawRow(y, list.header or {}, C.boxmuted, C.box)
      y = y + 1
      local listY = y
      if #list.rows == 0 then
        ui.text(x0 + 1, y, ui.sub(list.empty or "", iw), C.boxmuted, C.box)
      else
        if st.sel < st.top then st.top = st.sel end
        if st.sel > st.top + listRows - 1 then st.top = st.sel - listRows + 1 end
        st.top = math.max(1, math.min(st.top, #list.rows - listRows + 1))
        for i = st.top, math.min(#list.rows, st.top + listRows - 1) do
          local r = list.rows[i]
          local isSel = i == st.sel
          drawRow(y, r.cells, isSel and C.fg or (r.color or C.boxfg), isSel and C.sel or C.box, not isSel and r.colors or nil)
          ui.zone(x0 + 1, y, iw, 1, "row:" .. i)
          y = y + 1
        end
        if st.top > 1 then ui.text(x0 + w - 1, y - listRows, ui.UP, C.accent, C.box) end
        if st.top + listRows - 1 < #list.rows then ui.text(x0 + w - 1, y - 1, ui.DOWN, C.accent, C.box) end
      end
      y = listY + listRows
      for _, l in ipairs(detail) do ui.text(x0 + 1, y, l, C.boxmuted, C.box); y = y + 1 end
    end

    -- input
    if input then
      local label = (input.label or "") .. " "
      ui.text(x0 + 1, y, label, C.boxmuted, C.box)
      local fx = x0 + 1 + #label
      local fw = input.kind == "text" and math.min(iw - #label, (input.maxLen or 20) + 1) or 12
      local shown = st.text
      if input.kind == "text" then shown = shown .. "_" end
      ui.text(fx, y, ui.pad(shown, fw, input.kind == "number" and "r" or "l"), C.fieldfg, C.field)
      ui.zone(fx, y, fw, 1, "field")
      if input.kind == "number" and input.pct then
        local px = fx + fw + 1
        for _, p in ipairs({ 25, 50, 75, 100 }) do
          local lab = p .. "%"
          if px + #lab <= x0 + w - 1 then
            ui.text(px, y, lab, C.btnfg, C.btn)
            ui.zone(px, y, #lab, 1, "pct:" .. p)
            px = px + #lab + 1
          end
        end
      end
      y = y + 1
      for _, r in ipairs(info) do
        ui.text(x0 + 1, y, ui.pad(r[1], 18), C.boxmuted, C.box)
        ui.text(x0 + 20, y, ui.sub(r[2], iw - 19), r[3] or C.boxfg, C.box)
        y = y + 1
      end
    end
    for _, l in ipairs(errLines) do ui.text(x0 + 1, y, l, C.event, C.box); y = y + 1 end
    if #btnRows > 0 then drawButtons(btnRows, buttons, st.focus, x0 + 1, y0 + h - #btnRows, iw) end

    -- events
    local ev = ui.read()
    local function finish(i)
      local b = buttons[i]
      if b and not b.disabled then
        st.num = num()
        return b.id
      end
    end
    local function moveSel(d)
      if list and #list.rows > 0 then st.sel = math.max(1, math.min(#list.rows, st.sel + d)) end
    end
    local result
    if o.onKey then
      local r = o.onKey(ev, st)
      if r then st.num = num(); return r, st end
      if r == false then ev = {} end   -- handled, nothing to return
    end
    if ev.kind == "key" then
      local k = ev.key
      if k == keys.enter or k == keys.numPadEnter then result = finish(st.focus)
      elseif k == keys.tab or (k == keys.right and not (input and input.kind == "text")) then st.focus = moveFocus(buttons, st.focus, 1)
      elseif k == keys.left and not (input and input.kind == "text") then st.focus = moveFocus(buttons, st.focus, -1)
      elseif k == keys.up then if list then moveSel(-1) elseif input and input.kind == "number" then setNum(clampNum(num()) + 1) end
      elseif k == keys.down then if list then moveSel(1) elseif input and input.kind == "number" then setNum(clampNum(num()) - 1) end
      elseif k == keys.pageUp then if list then moveSel(-listRows) elseif input and input.kind == "number" then setNum(clampNum(num()) + (ui.ctrl and 100 or 10)) end
      elseif k == keys.pageDown then if list then moveSel(listRows) elseif input and input.kind == "number" then setNum(clampNum(num()) - (ui.ctrl and 100 or 10)) end
      elseif k == keys.home then if input and input.kind == "number" and input.min then setNum(input.min) elseif list then st.sel = 1 end
      elseif k == keys["end"] then if input and input.kind == "number" and input.max then setNum(input.max) elseif list then st.sel = #list.rows end
      elseif k == keys.backspace then
        -- Backspace edits a field; on an empty field (or without one) it goes back.
        if input and st.text ~= "" then st.text = st.text:sub(1, -2); st.fresh = false
        elseif o.cancel then return o.cancel, st end
      end
    elseif ev.kind == "char" then
      local ch = ev.ch
      if input and input.kind == "number" and ch:match("%d") then
        if st.fresh then st.text = "" end
        st.fresh = false
        if #st.text < 12 then st.text = (st.text == "0" and "" or st.text) .. ch end
        -- like the browser game: a number above the maximum becomes the maximum
        if input.max and tonumber(st.text) > input.max then st.text = tostring(input.max) end
      elseif input and input.kind == "text" then
        if #st.text < (input.maxLen or 20) then st.text = st.text .. ch end
      elseif o.keys and o.keys[ch] then
        st.num = num()
        return o.keys[ch], st
      end
    elseif ev.kind == "click" and ev.cmd then
      local what, arg = ev.cmd:match("^(%a+):?(.*)$")
      if what == "btn" then result = finish(tonumber(arg))
      elseif what == "row" then
        local i = tonumber(arg)
        if i == st.sel and list.activate then st.num = num(); return list.activate, st end
        st.sel = i
      elseif what == "pct" then
        local p = tonumber(arg)
        setNum(math.max(input.min or 0, math.floor((input.max or 0) * p / 100)))
      end
    elseif ev.kind == "scroll" then
      if list then moveSel(ev.dir) elseif input and input.kind == "number" then setNum(clampNum(num()) - ev.dir) end
    end
    if result then return result, st end
  end
end

function ui.message(title, text, label)
  ui.dialog({ title = title, text = text, buttons = { { label = label or "OK", id = "ok", primary = true } }, cancel = "ok" })
end

function ui.confirm(title, text, yes, no)
  local id = ui.dialog({ title = title, text = text, cancel = "no",
    buttons = { { label = no, id = "no" }, { label = yes, id = "yes", primary = true } } })
  return id == "yes"
end

--------------------------------------------------------------- form
--[[
  ui.form{ title, text, width, labelWidth, fields = {
      { label, kind = "choice", options = {...}, idx = 1 },
      { label, kind = "toggle", value = true, on = "Yes", off = "No" },
      { label, kind = "number", value = 0, min, max, step = 1 },
      { label, kind = "text", value = "", maxLen = 20 } },
    buttons, cancel, error, status = function(fields) -> text, color,
    onChange = function(fields, i), hint = text }
  Returns the button id and the fields (with their new values).
]]
function ui.form(o)
  local SW, SH = ui.size()
  local w = math.min(SW, o.width or 46)
  local iw = w - 2
  local fields, buttons = o.fields, o.buttons or {}
  local lw = o.labelWidth or 18
  local st = { field = 1, focus = startFocus(buttons), fresh = true }
  local err = o.error

  local function change(f, d)
    if f.kind == "choice" then f.idx = (f.idx - 1 + d) % #f.options + 1
    elseif f.kind == "toggle" then f.value = not f.value
    elseif f.kind == "number" then
      f.value = math.max(f.min or -math.huge, math.min(f.max or math.huge, (f.value or 0) + d * (f.step or 1)))
    end
    if o.onChange then o.onChange(fields, st.field) end
  end

  while true do
    if ui.backdrop then ui.backdrop() else ui.clear() end
    ui.zones = {}
    local textLines = o.text and ui.wrap(o.text, iw) or {}
    local hint = ui.wrap(o.hint or "", iw)
    if o.hint == nil then hint = {} end
    local status, scol
    if o.status then status, scol = o.status(fields) end
    local errLines = err and ui.wrap(err, iw) or {}
    local btnRows = layoutButtons(buttons, iw)
    local h = 2 + #textLines + (#textLines > 0 and 1 or 0) + #fields + (status and 2 or 0) + #hint + #errLines + #btnRows + 1
    while h > SH and #textLines > 0 do table.remove(textLines); h = h - 1 end
    local x0 = math.floor((SW - w) / 2) + 1
    local y0 = math.max(1, math.floor((SH - h) / 2) + 1)
    ui.fill(x0, y0, w, h, C.box)
    ui.fill(x0, y0, w, 1, C.title)
    ui.text(x0 + 1, y0, ui.sub(o.title or "", iw), C.titlefg, C.title)
    local y = y0 + 2
    for _, l in ipairs(textLines) do ui.text(x0 + 1, y, l, C.boxfg, C.box); y = y + 1 end
    if #textLines > 0 then y = y + 1 end
    for i, f in ipairs(fields) do
      local focused = i == st.field
      ui.text(x0 + 1, y, ui.pad(f.label, lw), focused and C.accent or C.boxmuted, C.box)
      local vx, vw = x0 + 2 + lw, iw - lw - 1
      local val
      if f.kind == "choice" then val = "< " .. tostring(f.options[f.idx]) .. " >"
      elseif f.kind == "toggle" then val = (f.value and "[x] " or "[ ] ") .. (f.value and (f.on or "") or (f.off or ""))
      elseif f.kind == "number" then val = tostring(f.value or "")
      else val = (f.value or "") .. (focused and "_" or "") end
      local bg = focused and C.sel or C.field
      ui.text(vx, y, ui.pad(val, vw), C.fg, bg)
      ui.zone(x0, y, w, 1, "field:" .. i)
      y = y + 1
    end
    if status then y = y + 1; ui.text(x0 + 1, y, ui.sub(status, iw), scol or C.boxfg, C.box); y = y + 1 end
    for _, l in ipairs(hint) do ui.text(x0 + 1, y, l, C.boxmuted, C.box); y = y + 1 end
    for _, l in ipairs(errLines) do ui.text(x0 + 1, y, l, C.event, C.box); y = y + 1 end
    drawButtons(btnRows, buttons, st.focus, x0 + 1, y0 + h - #btnRows, iw)

    local ev = ui.read()
    local f = fields[st.field]
    if ev.kind == "key" then
      local k = ev.key
      if k == keys.enter or k == keys.numPadEnter then
        local b = buttons[st.focus]
        if b and not b.disabled then return b.id, fields end
      elseif k == keys.up then st.field = math.max(1, st.field - 1); st.fresh = true
      elseif k == keys.down then st.field = math.min(#fields, st.field + 1); st.fresh = true
      elseif k == keys.left and f.kind ~= "text" then change(f, -1)
      elseif k == keys.right and f.kind ~= "text" then change(f, 1)
      elseif k == keys.tab then st.focus = moveFocus(buttons, st.focus, 1)
      elseif k == keys.backspace then
        if f.kind == "text" then f.value = (f.value or ""):sub(1, -2)
        elseif f.kind == "number" then
          local s = tostring(f.value or ""):sub(1, -2)
          f.value = tonumber(s) or 0; st.fresh = false
          if o.onChange then o.onChange(fields, st.field) end
        elseif o.cancel then return o.cancel, fields end
      end
    elseif ev.kind == "char" then
      if f.kind == "text" then
        if #(f.value or "") < (f.maxLen or 20) then f.value = (f.value or "") .. ev.ch end
      elseif f.kind == "number" and ev.ch:match("%d") then
        local s = st.fresh and "" or tostring(f.value or "")
        st.fresh = false
        if #s < 9 then f.value = tonumber(s .. ev.ch) end
        if f.max and f.value > f.max then f.value = f.max end
        if o.onChange then o.onChange(fields, st.field) end
      elseif f.kind ~= "text" and ev.ch == " " then change(f, 1)
      end
    elseif ev.kind == "click" and ev.cmd then
      local what, arg = ev.cmd:match("^(%a+):?(.*)$")
      if what == "btn" then
        local b = buttons[tonumber(arg)]
        if b and not b.disabled then return b.id, fields end
      elseif what == "field" then
        local i = tonumber(arg)
        if i == st.field and fields[i].kind ~= "text" and fields[i].kind ~= "number" then change(fields[i], 1) end
        st.field = i; st.fresh = true
      end
    elseif ev.kind == "scroll" and f.kind ~= "text" then
      change(f, -ev.dir)
    end
    err = nil
  end
end

return ui
