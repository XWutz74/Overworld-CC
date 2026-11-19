-- Overworld on boot: installed as overworld_startup.lua and started by startup/overworld.lua (the installer asks).
-- Starting overworld.lua puts in an update downloaded last time, then runs the game and looks for the next update in
-- the background. After a crash it starts again; quitting the game (or Ctrl+T) leaves for the shell.
-- Based on SALTGATE's startup.lua from Roger-Code by Akkiruk, adapted with permission.
local LOG = "overworld.log"
local CRASH_DELAY = 5

local function log(msg)
  local h = fs.open(LOG, "a")
  if h then
    h.writeLine((os.date and os.date("%Y-%m-%d %H:%M:%S") or "") .. " [startup] " .. tostring(msg))
    h.close()
  end
end

local function isTerminate(err)
  return type(err) == "string" and err:find("Terminated", 1, true) ~= nil
end

while true do
  local previous = term.current()
  local callOk, runOk = pcall(shell.run, "/overworld.lua")
  term.redirect(previous)
  if not callOk then
    if isTerminate(runOk) then log("terminated"); return end
    log("crash: " .. tostring(runOk))
  elseif runOk == false then
    log("overworld crashed; starting again in " .. CRASH_DELAY .. " s")
    print("Starting again in " .. CRASH_DELAY .. " seconds (hold Ctrl+T to stop).")
    local ok = pcall(os.sleep, CRASH_DELAY)
    if not ok then return end
  else
    log("overworld exited normally")
    return
  end
end
