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
---@field lockCharacterAndStage boolean? if true, prevents character and stage from being refreshed between matches

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
---@field playerNumber integer the (external) id for the player within the room; used to assign server messages to the correct player when spectating
---@field stack ClientStack?

-- ============================================================================
-- Field lifecycle classification
-- ============================================================================
-- These categories are load-bearing — most "stale state contaminating a new
-- match" bugs trace back to mutating a per-match field on an object whose
-- lifecycle is account-level.
--
-- IDENTITY (account-level, never cleared after construction):
--   name, publicId, isLocal, human
--
-- PER-ROOM (cleared when leaving a room, persists across matches in same room):
--   seatId, playerNumber, player_number       — seat in the lobby (refreshed
--                                                via TeamUtils.assignSeatIdentity
--                                                on join / rejoin)
--   wins, modifiedWins, winrate, expectedWinrate
--   settings.*                                  — character / stage / level /
--                                                 panels / wantsRanked picks
--   ready, wantsReady, hasLoaded                — per-character-select cycle,
--                                                 reset between matches by
--                                                 resetMatchTransientState
--   rating, league, ratingHistory               — per-room view of ladder data
--
-- PER-MATCH (must NOT leak from one match to the next — cleared by
-- clearPerMatchState before the new match's state is written):
--   stack            — ClientStack ref (built fresh each match)
--   stackIndex       — dense engine position; only meaningful during a match
--   lastPlacement    — outcome of the just-ended match
--
-- SCENE-BOUND (owned by the scene that installs them, cleared by scene
-- lifecycle, must NEVER be touched by match flow):
--   cursor           — GridCursor widget installed by CharacterSelect
--   inputConfiguration — input device claim
--
-- Adding a new field? Decide which category it belongs to and document here.
-- "Per-match" fields belong in clearPerMatchState. "Per-room" fields belong in
-- the relevant reset path (MatchParticipant:reset, leaveRoom, etc.). Mutating
-- a "scene-bound" field from match-flow code is how the GridCursor crash
-- happened.
-- ============================================================================

-- a match participant represents the minimum spec for a what constitutes a "player" in a battleRoom / match
---@class MatchParticipant : Signal
---@overload fun(): MatchParticipant
local MatchParticipant = class(
function(self)
  self.name = "participant"
  self.settings = {
    selectedCharacterId = consts.RANDOM_CHARACTER_SPECIAL_VALUE,
    selectedStageId = consts.RANDOM_STAGE_SPECIAL_VALUE,
    panelId = config.panels,
  }
  self.human = false

  self:reset()

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

function MatchParticipant:reset()
  self.wins = 0
  self.modifiedWins = 0
  self.winrate = 0
  self.expectedWinrate = 0
  self.settings.wantsReady = false
  self.ready = false
  self.hasLoaded = false
end

-- returns the count of wins modified by the `modifiedWins` property
function MatchParticipant:getWinCountForDisplay()
  return self.wins + self.modifiedWins
end

function MatchParticipant:setWinCount(count)
  self.wins = tonumber(count) or 0
  self:emitSignal("winsChanged", self:getWinCountForDisplay())
end

function MatchParticipant:incrementWinCount()
  self:setWinCount((self.wins or 0) + 1)
end

-- Last match's ordinal placement (1 = winner, 2 = runner-up, etc.) from the
-- server's gameResult payload. Nil until first match completes.
function MatchParticipant:setPlacement(placement)
  self.lastPlacement = placement
end

function MatchParticipant:setWinrate(winrate)
  self.winrate = winrate
  self:emitSignal("winrateChanged", winrate)
end

function MatchParticipant:setExpectedWinrate(expectedWinrate)
  self.expectedWinrate = expectedWinrate
  self:emitSignal("expectedWinrateChanged", expectedWinrate)
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
    local stage = ModController:loadStageIdFor(self, self.settings.stageId)
    if self.isLocal and not stage.fullyLoaded then
      self:setLoaded(false)
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
    local character = ModController:loadCharacterIdFor(self, self.settings.characterId)
    if self.isLocal and not character.fullyLoaded then
      self:setLoaded(false)
    end
  end
end

function MatchParticipant:setPanels(panelId)
  if panelId ~= self.settings.panelId then
    if panels[panelId] then
      self.settings.panelId = panelId
    else
      -- default back to config panels always
      self.settings.panelId = config.panels
    end
    -- panels are always loaded so no loading is necessary

    self:emitSignal("panelIdChanged", self.settings.panelId)
  end
end

function MatchParticipant:setWantsReady(wantsReady)
  if wantsReady ~= self.settings.wantsReady then
    logger.info(string.format("setWantsReady %s -> %s for %s (isLocal=%s)",
      tostring(self.settings.wantsReady), tostring(wantsReady), tostring(self.name), tostring(self.isLocal)))
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
    logger.info(string.format("setLoaded %s -> %s for %s (isLocal=%s)",
      tostring(self.hasLoaded), tostring(hasLoaded), tostring(self.name), tostring(self.isLocal)))
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

-- Per-character-select-cycle reset. Server resends authoritative values via
-- menu_state at character-select, but resetting locally first avoids a stale-
-- display window between match-end and the server snapshot arriving.
--
-- NOTE: deliberately does NOT touch hasLoaded. The local player's hasLoaded is
-- owned by BattleRoom.allAssetsLoaded (signal-driven), and remote players'
-- hasLoaded is owned by server menu_state. Slamming it false here would leave
-- it stuck false between matches: assets are still loaded so the BattleRoom
-- signal doesn't re-fire, and the ready button stays gated. Mod changes still
-- correctly set loaded=false via refreshCharacter / refreshStage when the new
-- mod isn't fullyLoaded.
function MatchParticipant:resetMatchTransientState()
  if self.human then
    self:setWantsReady(false)
  end
  self:setReady(false)
  -- self.cursor is scene-bound (CharacterSelect's GridCursor widget). Match-
  -- flow code must not touch it.
end

-- Clear PER-MATCH state. Called at match start (in ClientMatch.createFromReplay)
-- before the new match's seat / stack identity gets written to a carried-over
-- player object. Without this, a player who rejoined into a different seat (or
-- whose stack index changed because of roster compaction) keeps stale pointers
-- to the previous match's ClientStack and placement. See the field-lifecycle
-- comment block above.
function MatchParticipant:clearPerMatchState()
  self.stack = nil
  self.stackIndex = nil
  self.lastPlacement = nil
end

-- a callback that runs whenever a match ended
---@param match ClientMatch
function MatchParticipant:onMatchEnded(match)
  self:resetMatchTransientState()
  -- Skip refresh if character and stage are locked (e.g., in puzzle mode)
  if not self.settings.lockCharacterAndStage then
    self:refreshCharacter()
    self:refreshStage()
  end
end

function MatchParticipant:isHuman()
  return self.human
end

---@param engineStack BaseStack
---@return PlayerStack | ChallengeModePlayerStack
function MatchParticipant:createClientStack(engineStack)
  error("Did not implement createClientStack")
end

return MatchParticipant