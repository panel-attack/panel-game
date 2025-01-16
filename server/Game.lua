local class = require("common.lib.class")
local GameModes = require("common.engine.GameModes")
local Replay = require("common.data.Replay")
local ReplayPlayer = require("common.data.ReplayPlayer")
local LevelPresets = require("common.data.LevelPresets")
local logger = require("common.lib.logger")

---@class ServerGame
---@field id integer?
---@field seed integer
---@field players ServerPlayer[]
---@field replay Replay
---@field winnerId integer?
---@field winnerIndex integer?
---@field ranked boolean
---@field package inputs string[][]
---@field package outcomeReports integer[]
---@field complete boolean
local Game = class(
---@param players ServerPlayer[]
---@param id integer?
function(self, players, id)
  self.seed = math.random(1,9999999)
  self.players = players
  self.id = id
  self.outcomeReports = {}
  self.complete = false
end)

---@param room Room
---@return ServerGame game
function Game.createFromRoomState(room)
  local game = Game(room.players)

  game.replay = Replay(ENGINE_VERSION, game.seed, room.gameMode)
  game.replay:setStage(room.stageId)

  game.inputs = {}
  for i, player in ipairs(room.players) do
    game.inputs[i] = {}
    local replayPlayer = ReplayPlayer(player.name, player.publicPlayerID, true)
    replayPlayer:setWins(room.win_counts[i])
    replayPlayer:setCharacterId(player.character)
    replayPlayer:setPanelId(player.panels_dir)
    if player.levelData then
      replayPlayer:setLevelData(player.levelData)
    else
      replayPlayer:setLevelData(LevelPresets.getModern(player.level))
    end
    replayPlayer:setInputMethod(player.inputMethod)
    -- TODO: pack the adjacent color setting with level data or send it with player settings
    -- this is not something for the server to decide, it should just take what it gets
    if game.replay.gameMode.stackInteraction == GameModes.StackInteractions.NONE then
      replayPlayer:setAllowAdjacentColors(true)
    else
      replayPlayer:setAllowAdjacentColors(player.level < 8)
    end
    -- this is a display-only prop, the true info is stored in levelData
    replayPlayer:setLevel(player.level)

    game.replay:updatePlayer(i, replayPlayer)
  end

  local roomIsRanked, reasons = room:rating_adjustment_approved()

  game.ranked = roomIsRanked
  game.replay:setRanked(roomIsRanked)

  return game
end

---@param player ServerPlayer
---@param input string
function Game:receiveInput(player, input)
  if not self.complete then
    self.inputs[player.player_number][#self.inputs[player.player_number] + 1] = input
  end
end

---@param compressInputs boolean
---@return Replay?
function Game:getPartialReplay(compressInputs)
  if not self.replay then
    return nil
  else
    for i, player in ipairs(self.replay.players) do
      player.settings.inputs = table.concat(self.inputs[i])
      if compressInputs then
        player.settings.inputs = ReplayPlayer.compressInputString(player.settings.inputs)
      end
    end
    return self.replay
  end
end

function Game:receiveOutcomeReport(player, outcome)
  self.outcomeReports[player.player_number] = outcome

  -- cannot compare #self.outcomeReports == #self.players because # is undefined regarding gaps near 0
  -- so if we have the report for player 2 but not player 1, #self.outcomeReports may return 2 instead of 0
  -- see https://www.lua.org/manual/5.1/manual.html#2.5.5
  for i = 1, #self.players do
    if not self.outcomeReports[i] then
      return
    end
  end

  local result = Game.getOutcome(self.outcomeReports)
  if not result then
    --if clients disagree, the server needs to decide the outcome, perhaps by watching a replay it had created during the game.
    --for now though...
    logger.warn("clients " .. self.players[1].name .. " and " .. self.players[2].name .. " disagree on their game outcome. So the server will declare a tie.")
    result = 0
    self.aborted = true
  else
    if result ~= 0 then
      self.winnerIndex = result
      self.winnerId = self.players[result].publicPlayerID
    end
    self.aborted = false
  end

  self.complete = true
  self:finalizeReplay(result)
end

---@param outcomeReports integer[]
---@return integer? winnerIndex the winner of the game, 0 if tie, nil if the players disagreed on the outcome
function Game.getOutcome(outcomeReports)
  for i, outcomeA in ipairs(outcomeReports) do
    for j, outcomeB in ipairs(outcomeReports) do
      if i ~= j then
        if outcomeA ~= outcomeB then
          return
        end
      end
    end
  end

  -- everyone agrees on the outcome
  return outcomeReports[1]
end

---@param result integer?
function Game:finalizeReplay(result)
  self.replay:setOutcome(result)

  for i, player in ipairs(self.replay.players) do
    player.settings.inputs = table.concat(self.inputs[i])
    if COMPRESS_REPLAYS_ENABLED then
      player.settings.inputs = ReplayPlayer.compressInputString(player.settings.inputs)
    end
  end

  for i, player in ipairs(self.players) do
    if player.save_replays_publicly == "anonymously" then
      self.replay.players[i].name = "anonymous"
      if self.replay.players[i].publicId == self.replay.winnerId then
        self.replay.winnerId = - i
      end
      self.replay.players[i].publicId = - i
    end
  end
end

---@param id integer
---@return integer gameId
function Game:setId(id)
  if not self.id then
    self.id = id
  end

  if self.replay then
    self.replay.gameId = self.id
  end

  return self.id
end

---@param player ServerPlayer
---@return integer
function Game:getPlacement(player)
  if not self.winnerId then
    return 0
  else
    if self.winnerIndex == player.player_number then
      return 1
    else
      return 2
    end
  end
end

---@return integer
function Game:getInputCountDifference()
  if #self.inputs == 1 then
    return 0
  elseif #self.inputs == 2 then
    return math.abs(#self.inputs[1] - #self.inputs[2])
  else
    return 0
  end
end

return Game