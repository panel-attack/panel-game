local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local FileUtils = require("client.src.FileUtils")

-- Scene for a puzzle mode instance of the game
---@class PuzzleGame : GameBase
local PuzzleGame = class(
  function (self, sceneParams)
    self.keepMusic = true
    self.fadeOutMusicOnGameOver = false
    self.saveReplay = false
  end,
  GameBase
)

PuzzleGame.name = "PuzzleGame"

function PuzzleGame:customLoad()
  -- we cache the player's input configuration here so that only inputs from this config can start the next puzzle
  self.inputConfiguration = self.match.players[1].inputConfiguration
  self.puzzleSet = self.match.players[1].settings.puzzleSet
  self.puzzleIndex = self.match.players[1].settings.puzzleIndex
  local puzzle = self.puzzleSet.puzzles[self.puzzleIndex]
  local isValid, validationError = puzzle:validate()
  if not isValid then
    validationError = "Validation error in puzzle set " .. self.puzzleSet.setName .. "\n"
                    .. validationError
    local transition = MessageTransition(GAME.timer, 5, validationError)
    GAME.navigationStack:pop(transition)
  end
end

function PuzzleGame:customRun()
  -- reset level
  if (self.inputConfiguration and self.inputConfiguration.isDown["TauntUp"]) then
    if not self.match.ended and not self.match.isPaused then
      GAME.theme:playValidationSfx()
      self.match:resetPuzzle()
    end
  end
end

function PuzzleGame:readyToProceedToNextScene()
  if (self.inputConfiguration and self.inputConfiguration.isDown["TauntUp"]) then 
    FileUtils.saveReplay(self.match.replay)
  else
    return tableUtils.trueForAny(self.inputConfiguration.isDown, function(key) return key end)
  end
end

function PuzzleGame:startNextScene()
  if self.match.engine.aborted then
    GAME.navigationStack:pop()
  elseif self.match.players[1].settings.puzzleIndex <= #self.match.players[1].settings.puzzleSet.puzzles then
    local puzzle = self.puzzleSet.puzzles[self.match.players[1].settings.puzzleIndex]
    local isValid, validationError = puzzle:validate()
    if not isValid then
      validationError = "Validation error in puzzle set " .. self.puzzleSet.setName .. "\n"
                      .. validationError
      local transition = MessageTransition(GAME.timer, 5, validationError)
      GAME.navigationStack:popToTop(transition)
    else
      GAME.battleRoom:setGameMode(puzzle:toGameMode())
    end
    self.match.players[1]:setWantsReady(true)
  else
    GAME.navigationStack:pop()
  end
end

function PuzzleGame:customGameOverSetup()
  if self.match.stacks[1].engine.game_over_clock <= 0 and not self.match.engine.aborted then -- puzzle has been solved successfully
    self.text = loc("pl_you_win")
    self.match.players[1]:setPuzzleIndex(self.puzzleIndex + 1)
  else -- puzzle failed or manually reset
    self.text = loc("pl_you_lose")
  end
end

return PuzzleGame