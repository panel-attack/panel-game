local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local ModLoader = require("client.src.mods.ModLoader")
local SoundController = require("client.src.music.SoundController")
local logger = require("common.lib.logger")
local ModController = require("client.src.mods.ModController")

local states = { loadingMods = 1, catchingUp = 2 }

-- A scene showing a progress bar to indicate catching up to the current state of a match
local GameCatchUp = class(function(self, sceneParams)
  self.vsScene = sceneParams
  self.match = self.vsScene.match
  -- normally the game starts music only on countdown via its onGameStart callback
  -- game catchup stalls the music start so if the music should have started (at countdownEnded) already
  -- we need to make sure we start it afterwards
  self.match:connectSignal("countdownEnded", self, function()
    self.callback = function()
      self.vsScene:changeMusic(self.match.currentMusicIsDanger)
      self.vsScene:onGameStart()
    end
  end)

  self.timePassed = 0
  self.progress = 0

  local state = states.catchingUp

  for _, player in ipairs(self.match.players) do
    local character = characters[player.settings.characterId]
    if not character.fullyLoaded then
      state = states.loadingMods
      logger.debug("triggering character load from catchup transition for mod " .. character.id)
      ModController:loadModFor(character, player)
    end
  end

  local stage = stages[self.match.stageId]
  if not stage.fullyLoaded then
    state = states.loadingMods
    logger.debug("triggering stage load from catchup transition for mod " .. stage.id)
    ModController:loadModFor(stage, match)
  end

  self.state = state
end,
Scene)

GameCatchUp.name = "GameCatchUp"

local function modLoadValidation(match)
  logger.debug("Match has caught up, switching to gameScene")
  for i, stack in ipairs(match.stacks) do
    local character = characters[stack.character]
    logger.debug("Stack " .. i .. " uses character " .. character.id)
    logger.debug("Character " .. character.id .. " is fully loaded: " .. tostring(character.fullyLoaded))
    logger.debug("Character " .. character.id .. " has a portrait loaded: " .. tostring(character.images.portrait ~= nil))
  end
end

local function hasTimeLeft(t)
  return love.timer.getTime() < t + 0.9 * consts.FRAME_RATE
end

function GameCatchUp:update(dt)
  GAME.muteSound = true

  self.timePassed = self.timePassed + dt

  if not self.match.stacks[1].play_to_end then
    modLoadValidation(self.match)
    self.progress = 1
    SoundController:applyConfigVolumes()
    GAME.navigationStack:replace(self.vsScene, nil, self.callback)
  else
    self.progress = self.match.stacks[1].clock / #self.match.stacks[1].confirmedInput
  end
  local t = love.timer.getTime()
  -- convert the nil check into a bool
  local shouldCatchUp = not not ModLoader.loading_mod
  for _, stack in ipairs(self.match.stacks) do
    if shouldCatchUp then
      break
    elseif stack.play_to_end then
      shouldCatchUp = true
    end
  end

  -- spend 90% of frame time on catchup
  -- since we're not drawing anything big that should be realistic for catching ASAP
  while shouldCatchUp and hasTimeLeft(t) do
    if self.state == states.loadingMods then
      if not ModLoader.update() then
        self.state = states.catchingUp
      end
    elseif self.state == states.catchingUp then
      self.match:run()
    end
  end
end

function GameCatchUp:draw()
  local match = self.match
  GraphicsUtil.setColor(1, 1, 1, 1)
  GraphicsUtil.drawRectangle("line", consts.CANVAS_WIDTH / 4 - 5, consts.CANVAS_HEIGHT / 2 - 25, consts.CANVAS_WIDTH / 2 + 10, 50)
  GraphicsUtil.drawRectangle("fill", consts.CANVAS_WIDTH / 4, consts.CANVAS_HEIGHT / 2 - 20, consts.CANVAS_WIDTH / 2 * self.progress, 40)
  GraphicsUtil.printf("Catching up: " .. match.stacks[1].clock .. " out of " .. #match.stacks[1].confirmedInput .. " frames", 0, 500, consts.CANVAS_WIDTH, "center")
end

return GameCatchUp