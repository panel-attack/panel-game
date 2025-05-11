local class = require("common.lib.class")
local GameModes = require("common.data.GameModes")
local LevelPresets = require("common.data.LevelPresets")
local input = require("client.src.inputManager")
local MatchParticipant = require("client.src.MatchParticipant")
local consts = require("common.engine.consts")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local PlayerStack = require("client.src.PlayerStack")
require("client.src.network.PlayerStack")
local logger = require("common.lib.logger")
local StackBehaviours = require("common.data.StackBehaviours")
---@module "common.data.LevelData"


---@class PlayerSettings : ParticipantSettings
---@field puzzleSet PuzzleSet?
---@field puzzleIndex integer?
---@field level integer
---@field difficulty integer
---@field speed integer
---@field levelData LevelData
---@field style Styles
---@field wantsRanked boolean
---@field inputMethod InputMethod


-- A player is mostly a data representation of a Panel Attack player
-- It holds data pertaining to their online status (like name, public id)
-- It holds data pertaining to their client status (like character, stage, panels, level etc)
-- Player implements a lot of setters that emit signals on changes, allowing other components to be notified about the changes by connecting a function to it
-- Due to this, unless for a good reason, all properties on Player should be set using the setters
---@class Player : MatchParticipant
---@field settings PlayerSettings
---@overload fun(name: string, publicId: integer, isLocal: boolean?): Player
local Player = class(
---@param self Player
---@param name string
---@param publicId integer?
---@param isLocal boolean?
function(self, name, publicId, isLocal)
  ---@class Player
  self = self
  self.name = name
  local settings = self.settings
  -- these need to all be initialized so subscription works
  -- the gist is that all settings inside here are modifiable clientside for local players as part of match setup
  -- while everything outside settings is static or dictated server side
  settings.level = 1
  settings.difficulty = 1
  settings.speed = 1
  ---@type LevelData
  settings.levelData = LevelPresets.getModern(1)
  settings.style = GameModes.Styles.MODERN
  settings.characterId = ""
  settings.stageId = ""
  settings.panelId = ""
  settings.wantsReady = false
  settings.wantsRanked = true
  settings.inputMethod = "controller"
  settings.attackEngineSettings = nil
  settings.puzzleSet = nil
  settings.puzzleIndex = nil

  -- planned for the future, players don't have public ids yet
  self.publicId = publicId or -1
  self.league = nil
  self.rating = nil
  self.ratingHistory = {}
  self.stack = nil
  self.playerNumber = nil
  self.isLocal = isLocal or false
  -- a player may have only one configuration at a time
  self.inputConfiguration = nil
  self.human = true

  -- the player emits signals when its properties change that other components may be interested in
  -- they can register a callback with each signal via Signal.connectSignal
  -- there are a few more signals in MatchParticipant (which is why we don't have to explicitly declare us as emitting Signals again)
  self:createSignal("styleChanged")
  self:createSignal("difficultyChanged")
  self:createSignal("startingSpeedChanged")
  self:createSignal("levelChanged")
  self:createSignal("levelDataChanged")
  self:createSignal("inputMethodChanged")
  self:createSignal("puzzleSetChanged")
  self:createSignal("ratingChanged")
  self:createSignal("leagueChanged")
  self:createSignal("wantsRankedChanged")
end,
MatchParticipant)

Player.TYPE = "Player"

function Player:reset()
  MatchParticipant.reset(self)
  self:unrestrictInputs()
  self.settings.puzzleSet = nil
  self.settings.puzzleIndex = nil
end

---@param engineStack Stack
---@param match ClientMatch
---@return PlayerStack
function Player:createClientStack(engineStack, match)
  local args = {
    engine = engineStack,
    player_number = self.playerNumber,
    panels_dir = self.settings.panelId,
    characterId = self.settings.characterId,
    player = self,
    match = match,
  }

  if self.settings.style == GameModes.Styles.MODERN then
    args.level = self.settings.level
  else
    args.difficulty = self.settings.difficulty
  end

  self.stack = PlayerStack(args)

  return self.stack
end

function Player:getRatingDiff()
  if self.rating and tonumber(self.rating) and #self.ratingHistory > 0 then
    return self.rating - self.ratingHistory[#self.ratingHistory]
  else
    return 0
  end
end

function Player:setWantsRanked(wantsRanked)
  if wantsRanked ~= self.settings.wantsRanked then
    self.settings.wantsRanked = wantsRanked
    self:emitSignal("wantsRankedChanged", wantsRanked)
  end
end

function Player:setDifficulty(difficulty)
  if difficulty ~= self.settings.difficulty then
    self.settings.difficulty = difficulty
    self:emitSignal("difficultyChanged", difficulty)
  end
end

---@param levelData LevelData
function Player:setLevelData(levelData)
  self.settings.levelData = levelData
  self:setSpeed(levelData.startingSpeed)
  self:emitSignal("levelDataChanged", levelData)
end

function Player:setSpeed(speed)
  if speed ~= self.settings.speed or speed ~= self.settings.levelData.startingSpeed then
    self.settings.levelData.startingSpeed = speed
    self.settings.speed = speed
    self:emitSignal("startingSpeedChanged", speed)
  end
end

function Player:setLevel(level)
  if level ~= self.settings.level then
    self.settings.level = level
    self:emitSignal("levelChanged", level)
  end
end

function Player:setInputMethod(inputMethod)
  if inputMethod ~= self.settings.inputMethod then
    self.settings.inputMethod = inputMethod
    self:emitSignal("inputMethodChanged", inputMethod)
  end
end

-- sets the style of "level" presets the player selects from
-- 1 = classic
-- 2 = modern
-- longterm we want to abandon the concept of "style" on the player / battleRoom level
-- just setting difficulty or level should set the levelData and done with it, style is a menu-only concept
-- there is no technical reason why someone on level 10 shouldn't be able to play against someone on Hard
function Player:setStyle(style)
  if style ~= self.settings.style then
    self.settings.style = style
    if style == GameModes.Styles.MODERN then
      self:setLevelData(LevelPresets.getModern(self.settings.level or config.level))
    else
      self:setLevelData(LevelPresets.getClassic(self.settings.difficulty or config.endless_difficulty))
      self:setSpeed(self.settings.speed)
    end
    self:emitSignal("styleChanged", style)
  end
end

function Player:setPuzzleSet(puzzleSet, index)
  if puzzleSet ~= self.settings.puzzleSet then
    self.settings.puzzleSet = puzzleSet
    self:emitSignal("puzzleSetChanged", puzzleSet)
  end
  self.settings.puzzleIndex = index
end

function Player:setPuzzleIndex(puzzleIndex)
  if puzzleIndex ~= self.settings.puzzleIndex then
    self.settings.puzzleIndex = puzzleIndex
  end
end

function Player:setRating(rating)
  if self.rating and tonumber(self.rating) then
    -- only save a rating if we actually have one, tonumber assures that rating does not track placement progress instead
    self.ratingHistory[#self.ratingHistory + 1] = self.rating
  end

  if rating and tonumber(rating) then
    rating = math.round(tonumber(rating))
  end

  self.rating = rating
  self:emitSignal("ratingChanged", rating, self:getRatingDiff())
end

function Player:setLeague(league)
  if self.league ~= league then
    self.league = league
    self:emitSignal("leagueChanged", league)
  end
end

function Player:restrictInputs(inputConfiguration)
  if self.inputConfiguration and self.inputConfiguration ~= inputConfiguration then
    error("Player " .. self.playerNumber .. " is trying to claim a second input configuration")
  end
  self.inputConfiguration = input:claimConfiguration(self, inputConfiguration)
end

function Player:unrestrictInputs()
  if self.inputConfiguration then
    -- in the case of online play, it is possible that we ready up, causing the server to send out a match start message
    -- and then before that arrives we unready, thus losing the input configuration which crashes the match
    -- for this case, the last used input configuration is stored here
    -- if a match start arrives while no input configuration is set, the player gets restricted to the last used one again
    logger.debug("Unrestricting inputs for player " .. self.playerNumber)
    self.lastUsedInputConfiguration = self.inputConfiguration
    input:releaseConfiguration(self, self.inputConfiguration)
    self.inputConfiguration = nil
  end
end

---@return Player
function Player.getLocalPlayer()
  local player = Player(config.name, -1, true)

  player:setDifficulty(config.endless_difficulty)
  player:setLevel(config.level)
  player:setCharacter(config.character)
  player:setStage(config.stage)
  player:setPanels(config.panels)
  player:setWantsReady(false)
  player:setWantsRanked(config.ranked)
  player:setInputMethod(config.inputMethod)
  if config.endless_level then
    player:setStyle(GameModes.Styles.MODERN)
    player:setLevelData(LevelPresets.getModern(player.settings.level))
  else
    player:setStyle(GameModes.Styles.CLASSIC)
    player:setLevelData(LevelPresets.getClassic(player.settings.difficulty))
    player:setSpeed(config.endless_speed)
  end

  return player
end

---@param stackMetadata StackMetadata
---@return Player
function Player.createFromReplayMetadata(stackMetadata)
  local player = Player(stackMetadata.name, stackMetadata.publicId, false)
  player.playerNumber = stackMetadata.stackIndex
  player:setWinCount(stackMetadata.wins)
  player:setPanels(stackMetadata.panelId)
  player:setCharacter(stackMetadata.characterId)
  if stackMetadata.level then
    player:setStyle(GameModes.Styles.MODERN)
    player:setLevel(stackMetadata.level)
  else
    player:setStyle(GameModes.Styles.CLASSIC)
    player:setDifficulty(stackMetadata.difficulty)
  end

  -- see if things like inputMethod and levelData need to be loaded on the Player too - I think not

  return player
end

function Player:updateSettings(settings)
  if settings.characterId ~= nil then
    if characters[settings.characterId] then
      -- if we have their character, use it
      self:setCharacter(settings.characterId)
      if characters[settings.selectedCharacterId] then
        -- picking their bundle for display is a bonus
        self.settings.selectedCharacterId = settings.selectedCharacterId
        self:emitSignal("selectedCharacterIdChanged", self.settings.selectedCharacterId)
      end
    elseif settings.selectedCharacterId and characters[settings.selectedCharacterId] then
      -- if we don't have their character rolled from their bundle, but the bundle itself, use that
      -- very unlikely tbh
      self:setCharacter(settings.selectedCharacterId)
    elseif self.settings.characterId == "" then
      -- we don't have their character and we didn't roll them a random character yet
      self:setCharacter(consts.RANDOM_CHARACTER_SPECIAL_VALUE)
    end
  end

  if settings.stageId ~= nil then
    if stages[settings.stageId] then
      -- if we have their stage, use it
      self:setStage(settings.stageId)
      if stages[settings.selectedStageId] then
        -- picking their bundle for display is a bonus
        self.settings.selectedStageId = settings.selectedStageId
        self:emitSignal("selectedStageIdChanged", self.settings.selectedStageId)
      end
    elseif settings.selectedStageId and stages[settings.selectedStageId] then
      -- if we don't have their stage rolled from their bundle, but the bundle itself, use that
      -- very unlikely tbh
      self:setStage(settings.selectedStageId)
    elseif self.settings.stageId == "" then
      -- we don't have their stage and we didn't roll them a random stage yet
      self:setStage(consts.RANDOM_STAGE_SPECIAL_VALUE)
    end
  end

  if settings.wantsRanked ~= nil then
    self:setWantsRanked(settings.wantsRanked)
  end

  if settings.panelId ~= nil then
    self:setPanels(settings.panelId)
  end

  if settings.levelData ~= nil then
    if settings.level ~= nil then
      if settings.levelData.frameConstants.GARBAGE_HOVER then
        self:setStyle(GameModes.Styles.MODERN)
        self:setLevel(settings.level)
      else
        self:setStyle(GameModes.Styles.CLASSIC)
        self:setDifficulty(settings.level)
      end
    end

    self:setLevelData(settings.levelData)
  end

  if settings.inputMethod ~= nil then
    self:setInputMethod(settings.inputMethod)
  end

  -- these are both simply not sent by the server for some messages so make sure they are there
  if settings.wantsReady ~= nil then
    self:setWantsReady(settings.wantsReady)
  end
  if settings.hasLoaded ~= nil then
    self:setLoaded(settings.hasLoaded)
  end

  if settings.ready ~= nil then
    self:setReady(settings.ready)
  end
end

function Player:getInfo()
  local info = {}
  info.name = self.name
  info.level = self.settings.level
  info.difficulty = self.settings.difficulty
  info.speed = self.settings.speed
  info.characterId = self.settings.characterId
  info.selectedCharacterId = self.settings.selectedCharacterId
  info.stageId = self.settings.stageId
  info.selectedStageId = self.settings.selectedStageId
  info.panelId = self.settings.panelId
  info.wantsReady = tostring(self.settings.wantsReady)
  info.wantsRanked = tostring(self.settings.wantsRanked)
  info.inputMethod = self.settings.inputMethod
  info.publicId = self.publicId
  info.playerNumber = self.playerNumber
  info.isLocal = tostring(self.isLocal)
  info.human = tostring(self.human)
  info.wins = self.wins
  info.modifiedWins = self.modifiedWins

  return info
end

return Player