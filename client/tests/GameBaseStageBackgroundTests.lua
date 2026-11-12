local GameBase = require("client.src.scenes.GameBase")
local Flux = require("client.lib.flux.flux")
local Stage = require("client.src.mods.Stage")
local SceneAnimation = require("client.src.graphics.SceneAnimation")
local UpdatingImage = require("client.src.graphics.UpdatingImage")

local TEST_DATA = "client/tests/StageBackgroundTestData/"

-- Returns a game scene playing on the stage in the given test folder, without the match the scene would load it for
local function gameOnStage(folderName)
  local path = TEST_DATA .. folderName
  local game = setmetatable({tweens = Flux.group()}, {__index = GameBase})
  game.stage = Stage(path, folderName)
  game.stage.images.background = love.graphics.newImage(path .. "/background.png")
  game:loadStageBackground()
  return game
end

local function testStaticStageGetsItsImage()
  local game = gameOnStage("StaticStage")

  assert(getmetatable(game.stageBackground) == UpdatingImage, "The stage's background should be its image")
end

local function testAnimatedStageGetsItsAnimation()
  local game = gameOnStage("AnimatedStage")

  assert(getmetatable(game.stageBackground) == SceneAnimation, "The stage's background should be its animation")
end

local function testDrawsTheStageBackground()
  local game = gameOnStage("AnimatedStage")
  local drawn = false
  game.stageBackground.draw = function()
    drawn = true
  end

  game:drawStageBackground()

  assert(drawn, "The stage background should be drawn")
end

-- The navigation stack advances the active scene's animations, the stage background's included
local function testUpdatingTheAnimationsAdvancesTheStageBackground()
  local game = gameOnStage("AnimatedStage")

  game:updateAnimations(0.5)

  local alpha = game.stageBackground.drawables[1].alpha
  assert(math.abs(alpha - 0.5) < 0.001, "The stage animation's track should be half way, got " .. alpha)
end

testStaticStageGetsItsImage()
testAnimatedStageGetsItsAnimation()
testDrawsTheStageBackground()
testUpdatingTheAnimationsAdvancesTheStageBackground()
