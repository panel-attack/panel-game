local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local InputCompression = require("common.data.InputCompression")
local consts = require("common.engine.consts")
local FileUtils = require("client.src.FileUtils")

-- Scene for a puzzle mode instance of the game
---@class PuzzleGame : GameBase
---@field player Player
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
---@diagnostic disable-next-line: assign-type-mismatch
  self.player = self.match.players[1]
  self.inputConfiguration = self.player.inputConfiguration
  local puzzle = self.player.settings.puzzleSet.puzzles[self.player.settings.puzzleIndex]
  local isValid, validationError = puzzle:validate()
  if not isValid then
    validationError = "Validation error in puzzle set " .. self.player.settings.puzzleSet.setName .. "\n"
                    .. validationError
    local transition = MessageTransition(GAME.timer, 5, validationError)
    GAME.navigationStack:popToTop(transition)
  end
end

function PuzzleGame:customRun()
  -- reset level
  if (self.player.inputConfiguration and self.player.inputConfiguration.isDown["TauntUp"]) then
    if not self.match.ended and not self.match.isPaused then
      GAME.theme:playValidationSfx()
      self:savePuzzleRecordResult(false)
      self.match:resetPuzzle()
    end
  end
end

function PuzzleGame:readyToProceedToNextScene()
  if (self.inputConfiguration and self.inputConfiguration.isDown["TauntDown"]) then
    FileUtils.saveReplay(self.match.replay)
  else
    return tableUtils.trueForAny(self.inputConfiguration.isDown, function(key) return key end)
  end
end

function PuzzleGame:startNextScene()
  if self.match.engine.aborted then
    GAME.navigationStack:pop()
  elseif self.player.settings.puzzleIndex <= #self.player.settings.puzzleSet.puzzles then
    local puzzle = self.player.settings.puzzleSet.puzzles[self.player.settings.puzzleIndex]
    GAME.battleRoom:setGameMode(puzzle:toGameMode())
    self.player:setWantsReady(true)
  else
    GAME.navigationStack:pop()
  end
end

-- TODO: ideally this would be in the puzzle library
function PuzzleGame:savePuzzleRecordResult(success)
  local inputs = InputCompression.compressInputString(table.concat(self.match.players[1].stack.engine.confirmedInput))
  GAME.scores:savePuzzleRecord(self.player.settings.puzzleSet.puzzles[self.player.settings.puzzleIndex], inputs, to_UTC(os.time()), success)
end

function PuzzleGame:customGameOverSetup()
  if self.match.stacks[1].engine.game_over_clock <= 0 and not self.match.engine.aborted then -- puzzle has been solved successfully
    self.text = loc("pl_you_win")
    -- the below code is kind of hacky, the game scene isn't in charge of whats next.
    self:savePuzzleRecordResult(true)
    self.player:setPuzzleIndex(self.player.settings.puzzleIndex + 1)
  else -- puzzle failed
    self.text = loc("pl_you_lose")
    if (self.match.aborted == nil or self.match.aborted == false) then
      self:savePuzzleRecordResult(false)
    end
  end
end

return PuzzleGame