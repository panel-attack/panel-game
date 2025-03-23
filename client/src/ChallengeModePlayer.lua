local MatchParticipant = require("client.src.MatchParticipant")
local class = require("common.lib.class")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local ChallengeModePlayerStack = require("client.src.ChallengeModePlayerStack")

---@class ChallengeModePlayerSettings : ParticipantSettings
---@field attackEngineSettings table
---@field healthSettings table
---@field difficulty integer the overall difficulty of the selected challenge mode this player is used in
---@field level integer the current stage within the challenge mode difficulty

---@class ChallengeModePlayer : MatchParticipant
---@field usedCharacterIds string[] array of character ids that have already been used during the life time of the player
---@field settings ChallengeModePlayerSettings

local ChallengeModePlayer = class(
function(self, playerNumber)
  self.name = "Challenger"
  self.playerNumber = playerNumber
  self.isLocal = true
  self.settings.attackEngineSettings = nil
  self.settings.healthSettings = nil
  self.settings.wantsReady = true
  self.usedCharacterIds = {}
  self.human = false
end,
MatchParticipant)

ChallengeModePlayer.TYPE = "ChallengeModePlayer"

local function characterForStageNumber(stageNumber)
  -- Get all other characters than the player character
  local otherCharacters = {}
  for _, currentCharacter in ipairs(visibleCharacters) do
    if currentCharacter ~= config.character and characters[currentCharacter]:isBundle() == false then
      otherCharacters[#otherCharacters+1] = currentCharacter
    end
  end

  -- If we couldn't find any characters, try sub characters as a last resort
  if #otherCharacters == 0 then
    for _, currentCharacter in ipairs(visibleCharacters) do
      if characters[currentCharacter]:isBundle() == true then
        currentCharacter = characters[currentCharacter].subIds[1]
      end
      if currentCharacter ~= config.character then
        otherCharacters[#otherCharacters+1] = currentCharacter
      end
    end
  end

  local character = otherCharacters[((stageNumber - 1) % #otherCharacters) + 1]
  return character
end

---@param engineStack SimulatedStack
---@param match ClientMatch
---@return ChallengeModePlayerStack
function ChallengeModePlayer:createClientStack(engineStack, match)
  local args = {
    engine = engineStack,
    player_number = self.playerNumber,
    panels_dir = self.settings.panelId,
    characterId = self.settings.characterId,
    player = self,
    attackSettings = self.settings.attackEngineSettings,
    healthSettings = self.settings.healthSettings,
    match = match,
  }

  self.stack = ChallengeModePlayerStack(args)

  return self.stack
end

function ChallengeModePlayer:setCharacterForStage(stageNumber)
  self:setCharacter(characterForStageNumber(stageNumber))
end

-- challenge mode players are always ready
function ChallengeModePlayer:setWantsReady(wantsReady)
  self.settings.wantsReady = true
  self:emitSignal("wantsReadyChanged", true)
end

---@param stackMetadata SimulatedStackMetadata
---@return ChallengeModePlayer
function ChallengeModePlayer.createFromReplayMetadata(stackMetadata)
  local player = ChallengeModePlayer(stackMetadata.stackIndex)
  player:setCharacter(stackMetadata.characterId)
  player:setPanels(stackMetadata.panelId)
  player.settings.difficulty = stackMetadata.challengeModeDifficulty
  player.settings.level = stackMetadata.stageIndex

  -- see if things like attackEngineSettings and healthSettings need to be loaded on the ChallengeModePlayer too - I think not

  return player
end

function ChallengeModePlayer:getInfo()
  local info = {}
  info.characterId = self.settings.characterId
  info.selectedCharacterId = self.settings.selectedCharacterId
  info.stageId = self.settings.stageId
  info.selectedStageId = self.settings.selectedStageId
  info.panelId = self.settings.panelId
  info.wantsReady = self.settings.wantsReady
  info.playerNumber = self.playerNumber
  info.isLocal = self.isLocal
  info.human = self.human
  info.wins = self.wins
  info.modifiedWins = self.modifiedWins

  return info
end

return ChallengeModePlayer