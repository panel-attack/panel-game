local class = require("common.lib.class")
local GameModes = require("common.data.GameModes")
local logger = require("common.lib.logger")
local StackBehaviours = require("common.data.StackBehaviours")
local InputCompression = require("common.data.InputCompression")
local ReplayV3 = require("common.data.ReplayV3")
local GeneratorSource = require("common.engine.GeneratorSource")

---@class ServerGame
---@field id integer?
---@field seed integer
---@field players ServerPlayer[]
---@field replay ReplayV3
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
  self.seed = math.random(1, 9999999)
  self.players = players
  self.inputs = {}
  for i = 1, #players do
    self.inputs[i] = {}
  end
  self.id = id
  self.outcomeReports = {}
  self.complete = false
end)

---@param room Room
---@return ServerGame game
function Game.createFromRoomState(room)
  local game = Game(room.players)

  local roomIsRanked, reasons = room:rating_adjustment_approved()
  game.ranked = roomIsRanked

  local replay = ReplayV3(ENGINE_VERSION, room.gameMode.matchRules, GeneratorSource(game.seed, true):toReplaySource())
  replay:setStage(room.stageId)
  replay:setRanked(game.ranked)

  for i, player in ipairs(room.players) do
    ---@type ReplayStack
    local stack = {
      inputMethod = player.inputMethod,
      inputs = "",
      levelData = player.levelData,
      stackType = 1,
      stackBehaviours = StackBehaviours.getDefault(),
    }

    replay.stacks[i] = stack

    ---@type StackMetadata
    local metadata = {
      stackIndex = i,
      characterId = player.character,
      panelId = player.panels_dir,
      name = player.name,
      publicId = player.publicPlayerID,
      wins = room.win_counts[i],
    }

    if player.levelData.frameConstants.GARBAGE_HOVER then
      metadata.level = player.level
    else
      -- TODO: https://github.com/panel-attack/panel-game/issues/602
      metadata.difficulty = player.level
    end

    replay.metadata.stacks[i] = metadata
  end

  if room.gameMode.stackInteraction == GameModes.StackInteractions.SELF then
    for i, _ in ipairs(replay.stacks) do
      replay.garbageFlows[#replay.garbageFlows+1] = {
        source = i,
        recipients = { i }
      }
    end
  elseif room.gameMode.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
    logger.error("Attack engine game modes are not implemented yet")
  elseif room.gameMode.stackInteraction == GameModes.StackInteractions.VERSUS then
    for i = 1, #replay.stacks do
      local recipients = {}
      for j = 1, #replay.stacks do
        if i ~= j then
          recipients[#recipients+1] = j
        end
      end
      replay.garbageFlows[#replay.garbageFlows+1] = {
        source = i,
        recipients = recipients,
      }
    end
  end

  game.replay = replay

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
---@return ReplayV3?
function Game:getPartialReplay(compressInputs)
  if not self.replay then
    return nil
  else
    for i, stack in ipairs(self.replay.stacks) do
      if stack.stackType == 1 then
        ---@cast stack ReplayStack
        stack.inputs = table.concat(self.inputs[i])
        if compressInputs then
          stack.inputs = InputCompression.compressInputString(stack.inputs)
        end
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

  for i, stack in ipairs(self.replay.stacks) do
    if stack.stackType == 1 then
      ---@cast stack ReplayStack
      stack.inputs = table.concat(self.inputs[i])
      if COMPRESS_REPLAYS_ENABLED then
        stack.inputs = InputCompression.compressInputString(stack.inputs)
      end
    end
  end

  for i, player in ipairs(self.players) do
    if player.save_replays_publicly == "anonymously" then
      local playerMetadata = self.replay.metadata.stacks[i]
      ---@cast playerMetadata StackMetadata
      playerMetadata.name = "anonymous"
      playerMetadata.publicId = - i
      if playerMetadata.publicId == self.replay.metadata.winnerId then
        self.replay.metadata.winnerId = - i
      end
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
    self.replay.metadata.gameId = self.id
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