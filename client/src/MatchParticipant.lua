local class = require("common.lib.class")
local consts = require("common.engine.consts")
local Signal = require("common.lib.signal")
local logger = require("common.lib.logger")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local StageLoader = require("client.src.mods.StageLoader")
local ModController = require("client.src.mods.ModController")

---A set of settings that are modifiable by participants prior to starting a match
---@class ParticipantSettings
---@field selectedCharacterId string id of the selected (bundle) character
---@field characterId string id of the actually used character
---@field selectedStageId string id of the selected (bundle) stage
---@field stageId string id of the actually used stage
---@field panelId string id of the panelSet used to source shock garbage images
---@field wantsReady boolean
---@field attackEngineSettings table

---@class MatchParticipant
---@field name string the name of the participant for display
---@field wins integer number of wins gained within the room
---@field modifiedWins integer number of wins to be added to wins for display
---@field winrate number percentage of wins relative to matches played in the room (without ties I think)
---@field expectedWinrate number percentage of wins the participant is expected to get based on ladder ratings
---@field settings ParticipantSettings
---@field hasLoaded boolean if all assets needed for this participant have been loaded
---@field ready boolean if the participant is ready to start the game (wants to and actually is)
---@field human boolean if the participant is a human
---@field isLocal boolean if the participant is controlled by a local player

-- a match participant represents the minimum spec for a what constitutes a "player" in a battleRoom / match
---@class MatchParticipant : Signal
---@overload fun(): MatchParticipant
local MatchParticipant = class(
function(self)
  self.name = "participant"
  self.wins = 0
  self.modifiedWins = 0
  self.winrate = 0
  self.expectedWinrate = 0
  self.settings = {
    selectedCharacterId = consts.RANDOM_CHARACTER_SPECIAL_VALUE,
    selectedStageId = consts.RANDOM_STAGE_SPECIAL_VALUE,
    panelId = config.panels,
    wantsReady = false,
  }
  self.hasLoaded = false
  self.ready = false
  self.human = false

  Signal.turnIntoEmitter(self)
  self:createSignal("winsChanged")
  self:createSignal("winrateChanged")
  self:createSignal("expectedWinrateChanged")
  self:createSignal("panelIdChanged")
  self:createSignal("stageIdChanged")
  self:createSignal("selectedStageIdChanged")
  self:createSignal("characterIdChanged")
  self:createSignal("selectedCharacterIdChanged")
  self:createSignal("wantsReadyChanged")
  self:createSignal("readyChanged")
  self:createSignal("hasLoadedChanged")
  self:createSignal("attackEngineSettingsChanged")
end)

-- returns the count of wins modified by the `modifiedWins` property
function MatchParticipant:getWinCountForDisplay()
  return self.wins + self.modifiedWins
end

function MatchParticipant:setWinCount(count)
  self.wins = count
  self:emitSignal("winsChanged", self:getWinCountForDisplay())
end

function MatchParticipant:incrementWinCount()
  self:setWinCount(self.wins + 1)
end

function MatchParticipant:setWinrate(winrate)
  self.winrate = winrate
  self:emitSignal("winrateChanged", winrate)
end

function MatchParticipant:setExpectedWinrate(expectedWinrate)
  self.expectedWinrate = expectedWinrate
  self:emitSignal("expectedWinrateChanged", expectedWinrate)
end

-- returns a table with some key properties on functions to be run as part of a match
function MatchParticipant:createStackFromSettings(match, which)
  error("MatchParticipant needs to implement function createStackFromSettings")
end

function MatchParticipant:setStage(stageId)
  if stageId ~= self.settings.selectedStageId then
    self.settings.selectedStageId = StageLoader.resolveStageSelection(stageId)
    self:emitSignal("selectedStageIdChanged", self.settings.selectedStageId)
  end
  -- even if it's the same stage as before, refresh the pick, cause it could be bundle or random
  self:refreshStage()
end

function MatchParticipant:refreshStage()
  local currentId = self.settings.stageId
  self.settings.stageId = StageLoader.resolveBundle(self.settings.selectedStageId)
  if currentId ~= self.settings.stageId then
    self:emitSignal("stageIdChanged", self.settings.stageId)
    if not stages[self.settings.stageId].fullyLoaded then
      logger.debug("Loading stage " .. self.settings.stageId .. " as part of refreshStage for player " .. self.name)
      ModController:loadModFor(stages[self.settings.stageId], self)
      if self.isLocal then
        self:setLoaded(false)
      end
    end
  end
end

function MatchParticipant:setCharacter(characterId)
  if characterId ~= self.settings.selectedCharacterId or not self.settings.selectedCharacterId then
    if characters[characterId] then
      self.settings.selectedCharacterId = characterId
    else
      self.settings.selectedCharacterId = consts.RANDOM_CHARACTER_SPECIAL_VALUE
    end
    self:emitSignal("selectedCharacterIdChanged", self.settings.selectedCharacterId)
  end
  -- even if it's the same character as before, refresh the pick, cause it could be bundle or random
  self:refreshCharacter()
end

function MatchParticipant:refreshCharacter()
  local currentId = self.settings.characterId
  self.settings.characterId = CharacterLoader.resolveBundle(self.settings.selectedCharacterId)
  if currentId ~= self.settings.characterId then
    self:emitSignal("characterIdChanged", self.settings.characterId)
    if not characters[self.settings.characterId].fullyLoaded then
      logger.debug("Loading character " .. self.settings.characterId .. " as part of refreshCharacter for player " .. self.name)
      ModController:loadModFor(characters[self.settings.characterId], self)
      if self.isLocal then
        self:setLoaded(false)
      end
    end
  end
end

function MatchParticipant:setWantsReady(wantsReady)
  if wantsReady ~= self.settings.wantsReady then
    self.settings.wantsReady = wantsReady
    self:emitSignal("wantsReadyChanged", wantsReady)
  end
end

function MatchParticipant:setReady(ready)
  if ready ~= self.ready then
    self.ready = ready
    self:emitSignal("readyChanged", ready)
  end
end

function MatchParticipant:setLoaded(hasLoaded)
  if hasLoaded ~= self.hasLoaded then
    self.hasLoaded = hasLoaded
    self:emitSignal("hasLoadedChanged", hasLoaded)
  end
end

-- duality of attackEngineSettings:
-- In local play / replays the player sending the attacks should be setup as a separate player because it is its own stack
-- In online play it could be important for each player to have their own settings so that on Match:start a fitting player/stack can get generated
function MatchParticipant:setAttackEngineSettings(attackEngineSettings)
  if attackEngineSettings ~= self.settings.attackEngineSettings then
    self.settings.attackEngineSettings = attackEngineSettings
    self:emitSignal("attackEngineSettingsChanged", attackEngineSettings)
  end
end

-- a callback that runs whenever a match ended
function MatchParticipant:onMatchEnded()
   -- to prevent the game from instantly restarting, unready all players
   if self.human then
    self:setWantsReady(false)
   end
  self:refreshCharacter()
  self:refreshStage()
end

function MatchParticipant:isHuman()
  return self.human
end

return MatchParticipant