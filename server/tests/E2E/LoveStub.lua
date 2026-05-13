-- Minimal LÖVE stub for running real client code (NetClient, scenes, etc.)
-- inside a plain LuaJIT test process.
--
-- The stub uses an auto-vivifying metatable: any access to a yet-unknown
-- love.* path returns another stub table that's also callable. So
-- `love.graphics.newCanvas(...)` and `love.audio.play()` and arbitrary other
-- chains return nil without crashing. We then hand-override a handful of
-- specific calls where the client expects a particular return shape (e.g.,
-- love.getVersion returns 4 values; love.timer.getTime returns a number used
-- as a timestamp).
--
-- Returns the love stub. Caller should `_G.love = require("...LoveStub")`
-- BEFORE requiring any client module.

local M = {}

local function noop() return nil end

local function makeStub(label)
  local t = { __stub_label = label }
  setmetatable(t, {
    __index = function(self, k)
      -- Auto-vivify nested stubs so love.foo.bar.baz never errors.
      local child = makeStub((label or "love") .. "." .. tostring(k))
      rawset(self, k, child)
      return child
    end,
    __call = noop,
    __tostring = function() return "<LoveStub " .. label .. ">" end,
  })
  return t
end

local love = makeStub("love")

-- Hand-overrides: callers expect specific return shapes here.

-- system.lua line 75 destructures four return values.
love.getVersion = function() return 12, 0, 0, "TestStub" end

-- timer is used for clock readings + occasional sleeps. We don't want real sleeps
-- in tests, so sleep is a no-op; getTime returns a monotonic-ish wall clock.
love.timer = makeStub("love.timer")
love.timer.getTime = function() return os.clock() end
love.timer.sleep  = function(_seconds) return nil end
love.timer.step   = function() return 0 end
love.timer.getDelta = function() return 0 end
love.timer.getFPS = function() return 60 end

-- Common graphics calls that return objects with their own callable methods.
-- We return a child stub which itself auto-vivifies, so `canvas:setFilter()`
-- and similar chained calls work without crashing.
love.graphics = makeStub("love.graphics")
local function gfxConstructor(_)
  return makeStub("love.graphics.<object>")
end
love.graphics.newCanvas  = gfxConstructor
love.graphics.newImage   = gfxConstructor
love.graphics.newShader  = gfxConstructor
love.graphics.newQuad    = gfxConstructor
love.graphics.newFont    = gfxConstructor
love.graphics.newText    = gfxConstructor
love.graphics.getFont    = gfxConstructor
love.graphics.newSpriteBatch = gfxConstructor
love.graphics.getDimensions = function() return 1280, 720 end
love.graphics.getWidth   = function() return 1280 end
love.graphics.getHeight  = function() return 720 end

love.window = makeStub("love.window")
love.window.requestAttention = noop
love.window.getMode = function() return 1280, 720, {} end

love.audio = makeStub("love.audio")
local function fakeAudioObject()
  local s = {}
  s.getSampleRate   = function() return 44100 end
  s.getBitDepth     = function() return 16 end
  s.getChannelCount = function() return 2 end
  s.getDuration     = function() return 60 end -- > 3s so Music.lua's loop-length check passes
  s.setVolume       = function() end
  s.setPitch        = function() end
  s.setLooping      = function() end
  s.setFilter       = function() end
  s.play            = function() end
  s.pause           = function() end
  s.stop            = function() return true end
  s.isPlaying       = function() return false end
  s.clone           = function() return fakeAudioObject() end
  s.release         = function() end
  -- Decoder API — return nil immediately to terminate the chunk-loop in
  -- FileUtils.loadSoundData. No audio data is needed for protocol tests.
  s.decode          = function() return nil end
  s.getSampleCount  = function() return 0 end
  return s
end
love.audio.newSource = function() return fakeAudioObject() end
love.sound = makeStub("love.sound")
love.sound.newDecoder = function() return fakeAudioObject() end
love.sound.newSoundData = function() return fakeAudioObject() end

-- love.filesystem is wired to the real disk so the production asset loaders
-- (CharacterLoader, StageLoader, theme_init, panels_init) can walk
-- client/assets/* and load real fixtures without us mocking each loader.
-- All paths are interpreted relative to the project root (the cwd at boot).
-- Writes are sandboxed to /tmp/panel-game-test/<run-id>/ so tests don't
-- clobber the user's real config, leaderboard, etc.
local lfs_ok, lfs = pcall(require, "lfs")
if not lfs_ok then
  error("LoveStub: e2e tests require luafilesystem (lfs). Install with: " ..
        "luarocks install --local luafilesystem --lua-version 5.1")
end

local TEST_SAVE_ROOT = "/tmp/panel-game-test-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))
lfs.mkdir(TEST_SAVE_ROOT)

local fs = {}
function fs.getInfo(path, infoType)
  local attr = lfs.attributes(path)
  if not attr then return nil end
  local typeStr
  if attr.mode == "directory" then typeStr = "directory"
  elseif attr.mode == "file" then typeStr = "file"
  else typeStr = attr.mode end
  if infoType and infoType ~= typeStr then return nil end
  return { type = typeStr, size = attr.size, modtime = attr.modification }
end
function fs.exists(path) return fs.getInfo(path) ~= nil end
function fs.read(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local data = f:read("*a")
  f:close()
  return data
end
function fs.write(name, data)
  -- Sandbox: writes go under TEST_SAVE_ROOT. Production paths are relative
  -- (logs/server.log, players.txt) — prefix them with the test root.
  local path = TEST_SAVE_ROOT .. "/" .. name
  -- Ensure parent dirs exist.
  for parent in path:gmatch("(.*)/[^/]+$") do
    fs.createDirectory(parent)
    break
  end
  local f, err = io.open(path, "wb")
  if not f then return false, err end
  f:write(data or "")
  f:close()
  return true
end
function fs.createDirectory(path)
  if path:sub(1, 1) ~= "/" then path = TEST_SAVE_ROOT .. "/" .. path end
  -- mkdir -p semantics
  local parts = {}
  for part in path:gmatch("[^/]+") do parts[#parts + 1] = part end
  local p = (path:sub(1, 1) == "/") and "" or "."
  for _, part in ipairs(parts) do
    p = p .. "/" .. part
    lfs.mkdir(p)
  end
  return true
end
function fs.getDirectoryItems(path)
  if not lfs.attributes(path) then return {} end
  local items = {}
  for entry in lfs.dir(path) do
    if entry ~= "." and entry ~= ".." then items[#items + 1] = entry end
  end
  table.sort(items) -- determinism across runs
  return items
end
function fs.getSaveDirectory() return TEST_SAVE_ROOT end
function fs.getSourceBaseDirectory() return "." end
function fs.getRequirePath() return "?.lua;?/init.lua" end
-- love.filesystem.getRealDirectory returns the on-disk dir of a mounted path.
-- We don't do mounts, so the on-disk directory is the parent of path itself.
function fs.getRealDirectory(path) return (path or ""):match("(.*)/[^/]+$") or "." end
function fs.append(name, data)
  local path = TEST_SAVE_ROOT .. "/" .. name
  local f = io.open(path, "ab")
  if not f then return false end
  f:write(data or "")
  f:close()
  return true
end
function fs.remove(path) os.remove(path); return true end

-- love.filesystem is exposed as a stub so any unlisted call still auto-vivifies,
-- but the methods above shadow that with real-disk semantics.
love.filesystem = makeStub("love.filesystem")
for k, v in pairs(fs) do love.filesystem[k] = v end

love.event = makeStub("love.event")
love.event.push = noop
love.event.quit = noop

-- love.math is occasionally used for seeded RNG. PanelGenerator on the engine
-- side uses love.math.newRandomGenerator. Forward to LuaJIT's math.random with
-- per-instance state so different stacks don't share an rng.
love.math = makeStub("love.math")
love.math.newRandomGenerator = function(seed)
  local rng = { _seed = seed or 0, _state = seed or os.time() }
  function rng:setSeed(s) self._seed = s; self._state = s end
  function rng:getSeed() return self._seed end
  -- LÖVE's RNG carries 64-bit state across getState/setState. PanelGenerator
  -- uses these to snapshot + restore the RNG between panel generations for
  -- determinism. Two 32-bit ints round-trip our LCG state.
  function rng:getState() return tostring(self._state) end
  function rng:setState(s) self._state = tonumber(s) or self._state end
  function rng:random(a, b)
    -- LCG so we don't disturb the global math.random state.
    self._state = (self._state * 1103515245 + 12345) % 2147483648
    if not a then return self._state / 2147483648 end
    if not b then return math.floor(self._state / 2147483648 * a) + 1 end
    return a + math.floor(self._state / 2147483648 * (b - a + 1))
  end
  return rng
end
love.math.random = math.random
love.math.randomseed = math.randomseed

return love
