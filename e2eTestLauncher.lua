-- Entry point for end-to-end multiplayer protocol tests.
-- Run with: zsh run_e2e_tests.sh
--
-- Mirrors serverLauncher.lua's bootstrapping (CPath setup, server_globals,
-- logger) but skips the persistent main loop — instead it spins up a Server
-- inside the harness for each test scenario, exercises it, and tears it down.

local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")

-- e2e tests want to instantiate REAL client modules (NetClient et al.) so the
-- test exercises the same code paths a real LÖVE button click would. Three
-- preconditions must be true before we require any client.* module:
--
--   1. The `utf8` builtin module needs to resolve. Production picks `utf8` when
--      LÖVE is around and `lua-utf8` otherwise (common/lib/utf8Additions.lua).
--      We're setting up the LÖVE-branch (see step 2), so wire `utf8` to the
--      already-installed `lua-utf8` luarocks shim.
--   2. The global `love` must exist for client modules (NetClient pulls in
--      scenes / SoundController / MessageTransition that touch love.* at
--      module-load and instantiation time). See server/tests/E2E/LoveStub.lua
--      for the no-op stub.
--   3. Server-side globals (SERVER_PORT etc.) for the harness's Server.
package.preload["utf8"] = function() return require("lua-utf8") end
_G.love = require("server.tests.E2E.LoveStub")

local logger = require("common.lib.logger")
logger.setLogLevel(logger.levels.INFO)

require("server.server_globals")
-- Boot the client-side globals + config the same way main.lua does. NetClient's
-- transitive require chain reaches into Player → MatchParticipant → config, so
-- the global `config` table has to exist before we touch any client.* module.
-- client/src/globals.lua sets GARBAGE_TRANSIT_TIME etc; client/src/config.lua
-- sets the global `config` table (and re-requires globals defensively).
require("client.src.globals")
require("client.src.config")
-- TcpClient depends on a `ServerQueue` global (registered as a side-effect
-- side-import — see client/src/server_queue.lua). Production loads it as part
-- of main.lua's boot; we mirror that here.
require("client.src.server_queue")
-- `loc` is the global localization function; LoginRoutine and other client
-- modules call it for user-facing error messages. Tests don't care about
-- translated strings — install a passthrough stub that returns the lookup
-- key itself, which is enough for log lines and assertion messages.
_G.loc = function(key) return tostring(key) end
-- BattleRoom is a globally-bound class (side effect of requiring its module —
-- `BattleRoom = class(...)` at module body). NetClient.lua:287 reads it when
-- handling an addToRoom message; production boots it in main.lua before any
-- network traffic, so we do the same here.
require("client.src.BattleRoom")

-- Scene classes pull in a deep tree of UI widgets (Label, Button, GridCursor,
-- ...) that ultimately need a real love.graphics.newText / newFont / canvas to
-- construct. We can't fake those from pure Lua. But NetClient only calls scene
-- constructors AT THE SCENE-RENDER BOUNDARY — after the protocol/state work is
-- done. So we pre-populate package.loaded with stub scene classes BEFORE
-- requiring NetClient. NetClient's `local Foo = require("...Foo")` then resolves
-- to our stub; `Foo({battleRoom = room})` returns a harmless stub instance and
-- the navigation step completes without instantiating UI widgets.
--
-- Production protocol/state code still runs real. Production UI rendering is
-- where the seam is — the natural cut for a non-LÖVE test process.
local function stubSceneClass(name)
  local methods = {
    update = function() end,
    draw   = function() end,
    onSceneEnter = function() end,
    onSceneLeave = function() end,
    onPushed = function() end,
    onRemoved = function() end,
    shutdown = function() end,
    receiveInputs = function() end,
  }
  -- Any unknown method call returns nil silently.
  setmetatable(methods, { __index = function() return function() end end })
  return setmetatable({ stubSceneName = name }, {
    __call = function(_, args)
      local instance = setmetatable({
        isStubScene = true,
        sceneName = name,
        args = args,
        battleRoom = args and args.battleRoom or nil,
      }, { __index = methods })
      return instance
    end,
  })
end
for _, sceneModule in ipairs({
  "client.src.scenes.CharacterSelect2p",
  "client.src.scenes.CharacterSelectVsSelf",
  "client.src.scenes.CharacterSelectTeamVs",
  "client.src.scenes.CharacterSelectThreePlayerVs",
  "client.src.scenes.CharacterSelectFourPlayerVs",
  "client.src.scenes.CharacterSelectFivePlayerVs",
  "client.src.scenes.CharacterSelectSevenPlayerVs",
  "client.src.scenes.CharacterSelectOpenFFA",
  "client.src.scenes.GameBase",
  "client.src.scenes.GameCatchUp",
  "client.src.scenes.EndlessMenu",
  "client.src.scenes.TimeAttackMenu",
  "client.src.scenes.PuzzleGame",
  "client.src.scenes.Transitions.MessageTransition",
}) do
  package.loaded[sceneModule] = stubSceneClass(sceneModule)
end

-- Real asset boot — equivalent of Game:setupRoutine() in main.lua minus the
-- graphics/audio paths. Production walks client/assets/* via love.filesystem;
-- LoveStub wires that to real disk so the same loaders populate the same
-- globals (characters, stages, themes, panels) as in a real LÖVE client.
-- Once these run, the receive-side NetClient paths (refreshCharacter,
-- ModController:loadModFor, ...) find the entries they expect.

-- The one production code path we DO have to stub: real PNG/JPG decoding
-- requires LÖVE's image module, which depends on graphics hardware/SDL we
-- don't have in a luajit test process. Return a tiny fake image with the
-- methods downstream UI code calls. Asset-metadata loading (config.json,
-- character.lua, theme.json, etc.) goes through love.filesystem.read which
-- IS real. We're stubbing the pixel layer, not the asset graph.
local GraphicsUtil = require("client.src.graphics.graphics_util")
local function fakeImage(width, height)
  width, height = width or 4, height or 4
  local image = {}
  image.getWidth        = function() return width end
  image.getHeight       = function() return height end
  image.getDimensions   = function() return width, height end
  image.getPixelDimensions = function() return width, height end
  image.getDPIScale     = function() return 1 end
  image.getFilter       = function() return "nearest", "nearest" end
  image.setFilter       = function() end
  image.setWrap         = function() end
  image.setMipmapFilter = function() end
  image.release         = function() end
  image.isValid         = function() return true end
  image.newQuad         = function() return image end
  image.getFormat       = function() return "rgba8" end
  image.typeOf          = function() return false end
  -- Many UI/asset paths call methods on images we never see (replaceImage,
  -- generateMipmaps, etc.). Auto-vivify the rest as no-ops returning nil.
  setmetatable(image, { __index = function(self, k)
    local fn = function() return nil end
    rawset(self, k, fn)
    return fn
  end })
  return image
end
GraphicsUtil.loadImageFromSupportedExtensions = function() return fakeImage() end
GraphicsUtil.privateLoadImage = function() return fakeImage() end
GraphicsUtil.privateLoadImageWithExtensionAndScale = function() return fakeImage() end
-- renderToTexture runs a draw callback against a canvas; in tests we just
-- need it to produce SOMETHING with image methods. Returning fakeImage()
-- without invoking the callback avoids any graphics-state mutation.
GraphicsUtil.renderToTexture = function(w, h) return fakeImage(w or 4, h or 4) end

-- SoundController's volume/playback paths inspect `userdata` types and call
-- love.audio methods on real Source objects — we can't fake either from pure
-- Lua. Stub the public API to no-ops; sound is not on any test's critical path.
local SoundController = require("client.src.music.SoundController")
SoundController.applySfxVolume    = function() end
SoundController.applyMusicVolume  = function() end
SoundController.applyConfigVolumes = function() end
SoundController.playSfx           = function() end
SoundController.playMusic         = function() end
SoundController.stopMusic         = function() end

local Theme = require("client.src.mods.Theme")  -- registers theme_init global
local Panels = require("client.src.mods.Panels") -- registers panels_init global
local CharacterLoader = require("client.src.mods.CharacterLoader")
local StageLoader = require("client.src.mods.StageLoader")

theme_init()
StageLoader.initStages()
panels_init()
CharacterLoader.initCharacters()

local scenarios = {
  require("server.tests.E2E.ThreePlayerFFATests"),
  require("server.tests.E2E.RegressionTests"),
  require("server.tests.E2E.TraceReplayTests"),
}

local function main()
  local failures = {}
  for _, suite in ipairs(scenarios) do
    local ok, err = pcall(suite.runAll)
    if not ok then table.insert(failures, err) end
  end

  if #failures > 0 then
    logger.error("E2E suite FAILED with " .. #failures .. " error(s):")
    for i, e in ipairs(failures) do logger.error("  [" .. i .. "] " .. tostring(e)) end
    os.exit(1)
  end
  logger.info("E2E suite PASSED")
end

main()
