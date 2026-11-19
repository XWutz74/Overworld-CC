-- overworld_install.lua
-- Installs Overworld on this computer straight from GitHub (XWutz74/Overworld-CC, main). It is the installer players
-- get from Pastebin:   pastebin run <code>     or    pastebin get <code> install, then: install
-- It fetches ow/lib/standalone_update.lua and lets it install every file standalone.txt lists. Afterwards the game
-- keeps itself up to date (set overworld.autoupdate false to stop that). Run it again to repair or update:
-- your games, characters, settings and scores (overworld-save/) are kept.
-- Based on SALTGATE's installer from Roger-Code by Akkiruk, adapted with permission.

local OWNER, REPO, BRANCH = "XWutz74", "Overworld-CC", "main"
local RAW = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/"
local API = "https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/"
local LIB = "ow/lib/standalone_update.lua"
local STARTUP = "startup/overworld.lua"
local TRIES = 4

local w = term.getSize()

local function colour(c)
  if term.isColour() then term.setTextColour(c) end
end

local function say(text, c)
  colour(c or colours.white)
  print(text)
  colour(colours.white)
end

local function ask(question)
  while true do
    colour(colours.yellow)
    write(question .. " (y/n) ")
    colour(colours.white)
    local answer = (read() or ""):lower()
    if answer == "y" or answer == "yes" then return true end
    if answer == "n" or answer == "no" then return false end
  end
end

--- A progress bar on line y, and what it is doing on the line under it.
local function bar(y, done, total, label)
  local width = math.max(10, w - 2)
  local fill = math.floor(width * math.min(1, done / math.max(1, total)) + 0.5)
  term.setCursorPos(1, y)
  term.clearLine()
  if term.isColour() then
    term.setBackgroundColour(colours.orange)
    write(string.rep(" ", fill))
    term.setBackgroundColour(colours.grey)
    write(string.rep(" ", width - fill))
    term.setBackgroundColour(colours.black)
  else
    write(string.rep("#", fill) .. string.rep("-", width - fill))
  end
  term.setCursorPos(1, y + 1)
  term.clearLine()
  colour(colours.lightGrey)
  write((label or ""):sub(1, w))
  colour(colours.white)
end

local function get(url, headers)
  local ok, response, err = pcall(http.get, url, headers, true)
  if not ok then return nil, tostring(response) end
  if not response then return nil, tostring(err or "no answer") end
  local code = response.getResponseCode and response.getResponseCode() or 200
  local data = response.readAll()
  response.close()
  if code ~= 200 then return nil, "HTTP " .. tostring(code) end
  if not data or #data == 0 then return nil, "empty answer" end
  return data
end

--- get, tried TRIES times with a growing wait between.
local function fetch(url)
  local data, err
  for try = 1, TRIES do
    data, err = get(url)
    if data then return data end
    if try < TRIES then sleep(try * 2) end
  end
  return nil, err
end

--- The commit main is at now (GitHub caches raw files for minutes); main itself if GitHub will not say.
local function commitOfMain()
  local sha = get(API .. "commits/" .. BRANCH, { ["Accept"] = "application/vnd.github.sha", ["User-Agent"] = "overworld-installer" })
  if sha and sha:match("^%x+$") and #sha == 40 then return sha end
  return BRANCH
end

local function writeFile(path, data)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local f, err = fs.open(path, "w")
  if not f then return false, err end
  f.write(data)
  f.close()
  return true
end

local function main()
  term.clear()
  term.setCursorPos(1, 1)
  say("Overworld - installer", colours.orange)
  say("Buy low, sell high, stay out of trouble.", colours.lightGrey)
  print()
  local sw, sh = term.getSize()
  if sw < 51 or sh < 19 then
    say("Overworld needs a screen of at least 51 x 19 characters. Please use a computer, not a pocket computer.", colours.red)
    return false
  end
  if not http then
    say("This computer cannot reach the internet: the http API is off. Ask the server owner to allow http in the ComputerCraft config.", colours.red)
    return false
  end

  say("Finding the newest version...", colours.lightGrey)
  local commit = commitOfMain()
  local libData, err = fetch(RAW .. commit .. "/" .. LIB)
  if not libData then
    say("Could not download the installer's helper: " .. tostring(err), colours.red)
    say("Nothing was changed. Try again in a minute.", colours.red)
    return false
  end
  local fn, lerr = load(libData, "=standalone_update")
  local okL, up = false, nil
  if fn then okL, up = pcall(fn) end
  if not okL or type(up) ~= "table" or not up.install then
    say("The installer's helper came down damaged: " .. tostring(lerr or up), colours.red)
    return false
  end

  print()
  print()
  local _, below = term.getCursorPos()
  local barY = below - 2
  local o = up.options("standalone.txt", "overworld", { sleep = function(s) sleep(s) end })
  local done, ierr = up.install(o, function(i, total, path)
    bar(barY, i, total, path and ("downloading " .. path) or "checking")
  end)
  term.setCursorPos(1, barY + 2)
  if not done then
    say("The install failed: " .. tostring(ierr), colours.red)
    say("Nothing was changed. Try again in a minute.", colours.red)
    if tostring(ierr):find("secure connection", 1, true) then
      say("Minecraft's Java does not trust GitHub's certificate. Updating Java (or the launcher) fixes it.", colours.yellow)
    end
    return false
  end
  say("Installed version " .. done:sub(1, 7) .. ". " .. math.floor(fs.getFreeSpace("/") / 1024) .. " KB free.", colours.lime)
  say("It keeps itself up to date (set overworld.autoupdate false to stop that).", colours.lightGrey)
  print()

  if ask("Start Overworld when this computer turns on?") then
    local ok = writeFile(STARTUP, '-- Overworld on boot (overworld_install.lua). Delete this file to stop it.\nshell.run("/overworld_startup.lua")\n')
    if ok then say("It will. (Delete " .. STARTUP .. " to stop it.)", colours.lightGrey) end
  elseif fs.exists(STARTUP) then
    fs.delete(STARTUP)
  end
  print()
  say("Type overworld to play.", colours.orange)
  if ask("Play now?") then
    shell.run("/overworld.lua")
  end
  return true
end

local ok, err = pcall(main)
colour(colours.white)
if not ok then
  if tostring(err):find("Terminated", 1, true) then print("Cancelled.") return end
  printError("The installer crashed: " .. tostring(err))
end
