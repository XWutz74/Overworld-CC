-- Tests for installing and updating (ow/lib/standalone_update.lua with standalone.txt), without the internet:
-- a fake GitHub serves the repo's files, and installs go into a sandbox folder.
local here = fs.getDir(fs.getDir((debug.getinfo(1, "S").source or ""):gsub("^@", "")))
local test, eq, truthy, contains = ccunit.test, ccunit.eq, ccunit.truthy, ccunit.contains
local up = dofile("/" .. fs.combine(here, "ow/lib/standalone_update.lua"))

local function read(path)
  local h = fs.open(path, "rb")
  if not h then return nil end
  local d = h.readAll()
  h.close()
  return d
end

local MANIFEST = read("/" .. fs.combine(here, "standalone.txt"))

-- An fs that works inside one folder, as if it were the computer's root.
local function sandboxFs(root)
  if fs.exists(root) then fs.delete(root) end
  fs.makeDir(root)
  local function p(path) return fs.combine(root, path) end
  return {
    exists = function(x) return fs.exists(p(x)) end,
    isDir = function(x) return fs.isDir(p(x)) end,
    open = function(x, m) return fs.open(p(x), m) end,
    getDir = fs.getDir,
    makeDir = function(x) return fs.makeDir(p(x)) end,
    delete = function(x) return fs.delete(p(x)) end,
    move = function(a, b) return fs.move(p(a), p(b)) end,
    getFreeSpace = function() return 10000000 end,
    root = root,
  }
end

-- A fake GitHub: commits[sha] = { [repo path] = data }; head = the sha main is at.
local function fakeGitHub()
  local gh = { commits = {}, head = nil, online = true, calls = 0 }
  local function answer(data, code)
    return {
      readAll = function() return data end, close = function() end,
      getResponseCode = function() return code end, getResponseHeaders = function() return {} end,
    }
  end
  gh.http = {
    get = function(url)
      gh.calls = gh.calls + 1
      if not gh.online then return nil, "Could not connect" end
      if url:find("api.github.com", 1, true) then return answer(gh.head, 200) end
      local sha, path = url:match("raw%.githubusercontent%.com/XWutz74/Overworld%-CC/(%x+)/(.+)$")
      local files = sha and gh.commits[sha]
      if files and files[path] then return answer(files[path], 200) end
      local failed = answer("404: Not Found", 404)
      return nil, "Not Found", failed
    end,
  }
  -- A commit with the repo's files as they are now, changed by edits { [path] = data }.
  function gh.commit(sha, edits)
    local files = {}
    local man = up.parse(edits and edits["standalone.txt"] or MANIFEST)
    for _, f in ipairs(man.files) do files[f.from] = read("/" .. fs.combine(here, f.from)) end
    files["standalone.txt"] = MANIFEST
    for k, v in pairs(edits or {}) do files[k] = v end
    gh.commits[sha] = files
    gh.head = sha
  end
  return gh
end

local A = ("a"):rep(40)
local B = ("b"):rep(40)
local C = ("c"):rep(40)

local function setup(name)
  local gh = fakeGitHub()
  local sfs = sandboxFs("/sandbox-" .. name)
  local settingsValues = {}
  local o = up.options("standalone.txt", "overworld", {
    fs = sfs, http = gh.http, interval = 0,
    settings = { get = function(k) return settingsValues[k] end },
  })
  return gh, sfs, o, settingsValues
end

test("every file in standalone.txt is in the repo", function()
  local man = up.parse(MANIFEST)
  truthy(man, "manifest parses")
  eq(man.program, "overworld")
  for _, f in ipairs(man.files) do truthy(fs.exists("/" .. fs.combine(here, f.from)), f.from .. " exists") end
  for _, f in ipairs(man.files) do truthy(not f.to:find("^overworld%-save"), "saves are never listed") end
end)

test("fresh install puts every file in place", function()
  local gh, sfs, o = setup("fresh")
  gh.commit(A)
  eq(up.install(o), A)
  for _, f in ipairs(up.parse(MANIFEST).files) do truthy(sfs.exists(f.to), f.to .. " installed") end
  eq(read(fs.combine(sfs.root, "ow/game.lua")), read("/" .. fs.combine(here, "ow/game.lua")))
  eq(up.readState(o).commit, A)
  eq(sfs.exists(up.STAGE), false)
end)

test("update: staged in the background, put in at the next start, save kept", function()
  local gh, sfs, o = setup("update")
  gh.commit(A)
  up.install(o)
  -- the player has a game
  local h = sfs.open("overworld-save/save.dat", "w"); h.write("{ day = 7 }"); h.close()
  h = sfs.open("overworld-save/settings.dat", "w"); h.write("{ lang = \"de\" }"); h.close()
  -- a new commit changes one file
  local changed = read("/" .. fs.combine(here, "ow/util.lua")) .. "\n-- changed in commit B\n"
  gh.commit(B, { ["ow/util.lua"] = changed })
  eq(up.check(o), "staged")
  -- not swapped yet: the running game keeps its files
  truthy(not read(fs.combine(sfs.root, "ow/util.lua")):find("commit B"), "old file until the next start")
  eq(up.applyStaged(o), B)
  eq(read(fs.combine(sfs.root, "ow/util.lua")), changed)
  eq(up.readState(o).commit, B)
  eq(read(fs.combine(sfs.root, "overworld-save/save.dat")), "{ day = 7 }")
  eq(read(fs.combine(sfs.root, "overworld-save/settings.dat")), "{ lang = \"de\" }")
  eq(up.check(o), "current")
end)

test("a file that left the list is deleted, saves never", function()
  local gh, sfs, o = setup("removed")
  gh.commit(A)
  up.install(o)
  local h = sfs.open("overworld-save/save.dat", "w"); h.write("x"); h.close()
  local man = MANIFEST:gsub("file ow/lang/de_cc.lua ow/lang/de_cc.lua\n", "")
  gh.commit(B, { ["standalone.txt"] = man })
  gh.commits[B]["standalone.txt"] = man
  eq(up.check(o), "staged")
  eq(up.applyStaged(o), B)
  eq(sfs.exists("ow/lang/de_cc.lua"), false)
  eq(sfs.exists("overworld-save/save.dat"), true)
end)

test("a broken file is refused and nothing changes", function()
  local gh, sfs, o = setup("broken")
  gh.commit(A)
  up.install(o)
  gh.commit(C, { ["ow/game.lua"] = "this is not lua (" })
  contains(up.check(o), "does not compile")
  eq(sfs.exists(up.STAGE), false)
  eq(up.applyStaged(o), nil)
  eq(up.readState(o).commit, A)
end)

test("no internet: the installed game carries on", function()
  local gh, sfs, o = setup("offline")
  gh.commit(A)
  up.install(o)
  gh.commit(B, { ["ow/util.lua"] = "return {}\n" })
  gh.online = false
  contains(up.check(o), "failed")
  eq(up.applyStaged(o), nil)
  eq(up.readState(o).commit, A)
  truthy(up.readState(o).backoffUntil, "waits longer before asking again")
  eq(read(fs.combine(sfs.root, "ow/game.lua")), read("/" .. fs.combine(here, "ow/game.lua")))
  -- and a fresh install without internet changes nothing
  local gh2, sfs2, o2 = setup("offline2")
  gh2.online = false
  local done, err = up.install(o2)
  eq(done, nil)
  truthy(err, "an error is given")
  eq(sfs2.exists("overworld.lua"), false)
end)

test("set overworld.autoupdate false switches it off", function()
  local gh, sfs, o, values = setup("off")
  gh.commit(A)
  up.install(o)
  gh.commit(B, { ["ow/util.lua"] = "return {}\n" })
  values["overworld.autoupdate"] = false
  local before = gh.calls
  eq(up.check(o), "off")
  eq(gh.calls, before)
  local o2 = up.options("standalone.txt", "overworld", { fs = sfs, http = false, interval = 0, settings = { get = function() end } })
  eq(up.check(o2), "no http")
end)

test("the updater and installer are Lua 5.1 (no goto)", function()
  for _, f in ipairs({ "ow/lib/standalone_update.lua", "overworld_install.lua", "startup.lua", "overworld.lua" }) do
    local src = read("/" .. fs.combine(here, f))
    truthy(not src:find("%f[%w]goto%f[%W]"), f .. " has no goto")
    truthy(loadstring(src, "=" .. f), f .. " compiles")
  end
end)
