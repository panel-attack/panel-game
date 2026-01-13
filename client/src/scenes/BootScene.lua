local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")
local ModLoader = require("client.src.mods.ModLoader")

local BootScene = class(function(scene, sceneParams)
  scene.migrationRoutine = coroutine.create(scene.migrate)
  scene.setupRoutine = coroutine.create(sceneParams.setupRoutine)
  scene.message = "Startup"
  scene.migrationPath = scene:checkIfMigrationIsPossible()

  local saveDir = love.filesystem.getSaveDirectory()

  if scene.migrationPath then
    scene.migrationMessage = "Migrating save directory" ..
            "\nOld save directory at " .. scene.migrationPath ..
            "\nNew save directory at " .. saveDir
    logger.debug(scene.migrationMessage)
  end

  love.graphics.setFont(GraphicsUtil.getGlobalFontWithSize(GraphicsUtil.fontSize + 10))
end, Scene)

BootScene.name = "BootScene"

function BootScene:updateSelf(dt)
  if self.migrationPath then
    local success, status = coroutine.resume(self.migrationRoutine, self)
    if success then
      if status then
        self.message = self.migrationMessage .. "\n" .. status
      end
    else
      GAME.crashTrace = debug.traceback(self.migrationRoutine)
      error(status)
    end
  else
    local success, status = coroutine.resume(self.setupRoutine, GAME)
    if success then
      if status then
        self.message = status
      end
    else
      GAME.crashTrace = debug.traceback(self.setupRoutine)
      error(status)
    end

    if coroutine.status(self.setupRoutine) == "dead" then
      love.graphics.setFont(GraphicsUtil.getGlobalFont())

      -- we need the late require for all scenes here because localization is only initialized by the coroutine and all scenes depend on it being loaded
      if themes[config.theme].images.bg_title then
        GAME.navigationStack:replace(require("client.src.scenes.TitleScreen")())
      else
        GAME.navigationStack:replace(require("client.src.scenes.MainMenu")())
      end

      -- scenes that are displayed before anything else on either first startup or if a new input device was found
      -- they are just pushed on top and will pop off as the player works through them until the regular game start is left

      local input = require("client.src.inputManager")

      if input.hasUnsavedChanges or input:hasUnconfiguredJoysticks() then
        local InputConfigMenu = require("client.src.scenes.InputConfigMenu")
        GAME.navigationStack:push(InputConfigMenu({}))
      end

      if not config.discordCommunityShown then
        local DiscordCommunitySetup = require("client.src.scenes.DiscordCommunitySetup")
        GAME.navigationStack:push(DiscordCommunitySetup({}))
      end

      if not config.language_code then
        local LanguageSelectSetup = require("client.src.scenes.LanguageSelectSetup")
        GAME.navigationStack:push(LanguageSelectSetup({}))
      end
    end
  end
end

function BootScene:drawLoadingString(loadingString)
  local textHeight = 40
  local x = 0
  local y = consts.CANVAS_HEIGHT / 2 - textHeight / 2
  GraphicsUtil.setColor(1, 1, 1, 1)
  love.graphics.printf(loadingString, x, y, consts.CANVAS_WIDTH, "center", 0, 1)
end

function BootScene:drawSelf()
  self:drawLoadingString(self.message)
end

function BootScene:checkIfMigrationIsPossible()
  local loveMajor = love.getVersion()
  if loveMajor < 12 then
    return false
  end

  local os = love.system.getOS()
  if os == "Linux" or os == "OS X" then
    if not fileUtils.exists("conf.json") then
      local path = love.filesystem.getAppdataDirectory()
      if path:sub(-1) ~= "/" then
        path = path .. "/"
      end
      if os == "Linux" then
        path = path .. "love/"
      elseif os == "OS X" then
        path = path .. "LOVE/"
      end
      path = path .. love.filesystem.getIdentity()
      logger.debug("Trying to mount old install under " .. path)

      if not love.filesystem.mountFullPath(path, "oldInstall") then
        -- if we couldn't mount that directory, that means there is no old install
        logger.debug("No old install found")
      else
        if fileUtils.exists("oldInstall/conf.json") then
          return path
        end
      end
    end
  end
end

function BootScene:migrate()
  fileUtils.recursiveCopy("oldInstall", "", true)
  love.filesystem.unmountFullPath(self.migrationPath)
  self.migrationPath = nil
  self.migrationMessage = nil
  readConfigFile(config)
  love.window.updateMode(config.windowWidth, config.windowHeight,
    {
      x = config.windowX,
      y = config.windowY,
      fullscreen = config.fullscreen,
      borderless = config.borderless,
      displayindex = config.display,
      resizable = true,
    })
  love.load()
end

return BootScene
