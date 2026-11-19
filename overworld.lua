--[[
  Overworld for ComputerCraft (CC: Tweaked).
  Buy low, sell high, stay out of trouble.
  Start it with: overworld
]]
local args = { ... }
local dir = fs.getDir(shell.getRunningProgram())
package.path = "/" .. fs.combine(dir, "?.lua") .. ";/" .. fs.combine(dir, "?/init.lua") .. ";" .. package.path

------------------------------------------------------------------ keeping itself up to date
-- A copy installed with overworld_install.lua keeps itself up to date through ow/lib/standalone_update.lua (from
-- Roger-Code by Akkiruk): an update downloaded last time goes in here, before anything loads, never mid-game; the next
-- one is looked for, and downloaded, in the background while you play. standalone.txt in the repo lists the files.
-- Off: set overworld.autoupdate false. A copy that was not installed (no overworld_install.dat) never updates.
local UPDATE_LIB = fs.combine(dir, "ow/lib/standalone_update.lua")
local MANIFEST = "standalone.txt"
local installed = dir == "" and fs.exists("/overworld_install.dat") and fs.exists("/" .. UPDATE_LIB)
local autoupdate = installed and not (settings and settings.get("overworld.autoupdate") == false)
local updater, updaterOpts, notice

local function log(msg)
  local h = fs.open("/overworld.log", "a")
  if h then
    h.writeLine((os.date and os.date("%Y-%m-%d %H:%M:%S") or "") .. " " .. tostring(msg))
    h.close()
  end
end

if autoupdate then
  local okL, lib = pcall(dofile, "/" .. UPDATE_LIB)
  if okL and type(lib) == "table" and lib.options then
    updater = lib
    updaterOpts = lib.options(MANIFEST, "overworld", { log = log, sleep = function(s) os.sleep(s) end })
    local okA, commit = pcall(updater.applyStaged, updaterOpts)
    if okA and commit then
      -- this file may be one of the new ones: start again on the new files
      return shell.run("/" .. shell.getRunningProgram(), table.unpack and table.unpack(args) or unpack(args))
    elseif not okA then
      log("update not put in: " .. tostring(commit))
    end
    -- "Updated to abc1234" on the title screen, once
    local okS, st = pcall(updater.readState, updaterOpts)
    if okS and st.commit and st.updatedAt and st.noted ~= st.commit then
      notice = (st.previous and "Updated to " or "Installed ") .. st.commit:sub(1, 7)
      st.noted = st.commit
      pcall(updater.writeState, updaterOpts, st)
    end
  else
    log("updater not loaded: " .. tostring(lib))
  end
end

-- In the background while the game runs: look for an update and download it (it goes in at the next start).
local function backgroundUpdate()
  local okB, why = pcall(updater.check, updaterOpts)
  log("update check: " .. tostring(why))
  while true do os.pullEventRaw("overworld_never") end
end

------------------------------------------------------------------ the game
local app = require("ow.app")

local ok, err
local function game() ok, err = pcall(app.run, fs.combine(dir, "overworld-save"), { notice = notice }) end
if updater and parallel then
  parallel.waitForAny(game, backgroundUpdate)
else
  game()
end

-- Ctrl+T or a crash: keep the game.
pcall(app.save)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
if not ok and not (type(err) == "table" and err.terminate) then
  log("crash: " .. tostring(err))
  printError("Overworld crashed: " .. tostring(err))
  print("Your game was saved. Please report this error.")
  error(nil, 0)   -- tells overworld_startup.lua it crashed (prints nothing more)
end
