local logger = require("common.lib.logger")
local Player = require("client.src.Player")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.data.GameModes")
local class = require("common.lib.class")
local Signal = require("common.lib.signal")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local ModController = require("client.src.mods.ModController")
local ModLoader = require("client.src.mods.ModLoader")
local ClientMatch = require("client.src.ClientMatch")
local BlackFadeTransition = require("client.src.scenes.Transitions.BlackFadeTransition")
local Easings = require("client.src.Easings")
local system = require("client.src.system")
local GeneratorSource = require("common.engine.GeneratorSource")
local DebugSettings = require("client.src.debug.DebugSettings")

-- A Battle Room is a session of matches, keeping track of the room number, player settings, wins / losses etc
---@class BattleRoom : Signal
---@field mode GameMode The game mode configuration defining rules, player count, and match settings for this battle room
---@field players Player[]
---@field spectators string[]
---@field spectating boolean
---@field allAssetsLoaded boolean
---@field ranked boolean
---@field state BattleRoomState
---@field matchesPlayed integer
---@field online boolean
---@field gameScene table
---@field match ClientMatch
---@field panelSource table?
---@field roomNumber integer?
---@field sceneParameters table?
---@field preferredStageId string? if set, this stage will be used for all matches in the session
---@overload fun(mode: GameMode, gameScene: table?): BattleRoom
BattleRoom = class(
function(self, mode, gameScene)
  assert(mode)
  self.mode = mode
  self.players = {}
  self.spectators = {}
  self.spectating = false
  self.allAssetsLoaded = false
  self.ranked = false
  self.state = 1
  self.matchesPlayed = 0
  self.panelSource = nil
  self.roomNumber = nil
  self.gameScene = gameScene or require("client.src.scenes." .. mode.gameScene)
  self.sceneParameters = nil
  -- this is a bit naive but effective for now
  self.online = GAME.netClient:isConnected()
  if self.online then
    GAME.netClient:connectSignal("clientDisconnected", self, self.onDisconnect)
  end

  -- Per-team wins for team game modes (nil for non-team modes). Indexed by team_index.
  -- Populated from server payloads (addToRoom, gameResult, lobbyStateV2). Use this in
  -- preference to per-player win counts when displaying team scoreboards so a player
  -- who joined late shows the team's accumulated wins rather than only their own.
  self.teamWins = nil

  -- Set true when the server tells us a player left/disconnected from this room.
  -- Voided rooms can't start a new match; the UI should disable Ready and surface
  -- the voidReason ("X left"). Players can still see the final state and leave
  -- manually; the room is fully torn down when the last player navigates back.
  self.voided = false
  self.voidReason = nil

  Signal.turnIntoEmitter(self)
  self:createSignal("rankedStatusChanged")
  self:createSignal("allAssetsLoadedChanged")
end)

---@enum BattleRoomState
BattleRoom.states = { Setup = 1, MatchInProgress = 2 }

function BattleRoom.createFromServerMessage(message)
  local gameMode = GameModes.createFromServerData(message.gameMode)
  local battleRoom = BattleRoom(gameMode)
  battleRoom.roomNumber = message.roomNumber

  if message.spectate_request_granted then
    logger.debug("Joining a match as spectator")
    if message.replay then
      local replay = message.replay
      -- Spectator path: pass gameMode so team-based hasEnded works for the spectator
      -- view of the match too. Without this, the spectator's local engine never ends
      -- a 4p_ffa or team match until the last surviving player dies.
      local match = ClientMatch.createFromReplay(replay, nil, gameMode)
      for i = 1, #match.players do
        battleRoom:addPlayer(match.players[i])
      end

      battleRoom.match = match
      battleRoom.match:start()
      battleRoom.state = BattleRoom.states.MatchInProgress
    else
      for i = 1, #message.players do
        local player = Player(message.players[i].name, message.players[i].publicId or -i, false)
        battleRoom:addPlayer(player)
        player:updateSettings(message.players[i].settings)
      end
    end

    for i = 1, #battleRoom.players do
      if message.players[i].ratingInfo then
        local ratingInfo = message.players[i].ratingInfo
        battleRoom.players[i]:setRating(ratingInfo.placement_match_progress or ratingInfo.new)
        battleRoom.players[i]:setLeague(ratingInfo.league)
      end
    end
    if message.winCounts then
      battleRoom:setWinCounts(message.winCounts)
    end
    battleRoom.spectating = true
  else
    local gameMode = message.gameMode
    for i, player in ipairs(message.players) do
      local p
      local samePublicId = (player.publicId and GAME.localPlayer.publicId and GAME.localPlayer.publicId > 0 and player.publicId == GAME.localPlayer.publicId)
      local sameName = (player.name == GAME.localPlayer.name)

      -- Match local player by publicId when available; fallback to name for dev/self-play setups.
      if samePublicId or sameName then
        logger.debug("Local player is player number " .. player.playerNumber)
        p = GAME.localPlayer
        if GAME.localPlayer.publicId < 0 and player.publicId > 0 then
          GAME.localPlayer.publicId = player.publicId
        end
      else
        p = Player(player.name, player.publicId or -i, false)
      end

      -- updateSettings will set levelData which triggers levelDataChanged signal
      -- which will automatically update style based on the levelData
      p:updateSettings(player.settings)

      if player.ratingInfo then
        p:setRating(player.ratingInfo.placement_match_progress or player.ratingInfo.new)
        p:setLeague(player.ratingInfo.league)
      end

      p.playerNumber = player.playerNumber
      battleRoom:addPlayer(p)
    end
  end

  battleRoom:updateRankedStatus(message.ranked)

  if message.teamWins then
    battleRoom:setTeamWins(message.teamWins)
  end

  battleRoom:restoreInputConfigurations()
  GAME.netClient:registerPlayerUpdates(battleRoom)

  return battleRoom
end

-- Creates a local (offline) BattleRoom from a GameMode configuration.
-- For single-player modes, uses the game's main local player. For multi-player modes,
-- creates temporary local players that don't persist settings changes.
---@param gameMode GameMode The game mode configuration defining rules and player count
---@param gameScene table? Optional scene class to use for matches (defaults to mode's gameScene)
---@param settingChangesUpdateConfig boolean? If true, setting changes update config (default: true). Only applies to single-player modes.
---@return BattleRoom? battleRoom The created battle room, or nil if input configuration assignment fails
function BattleRoom.createLocalFromGameMode(gameMode, gameScene, settingChangesUpdateConfig)
  if settingChangesUpdateConfig == nil then
    settingChangesUpdateConfig = true
  end

  local battleRoom = BattleRoom(gameMode, gameScene)

  if settingChangesUpdateConfig and gameMode.playerCount == 1 then
    -- always use the game client's local player
    battleRoom:addPlayer(GAME.localPlayer)
  else
    -- with more than 1 local player we can't be sure which player is the "real" regular user
    -- so make them both local players that don't update config settings
    for i = 1, gameMode.playerCount do
      local player = Player.createLocalPlayerFromConfig()
      player.name = loc("player_n", i)
      battleRoom:addPlayer(player)
    end
  end

  if battleRoom:restoreInputConfigurations() then
    return battleRoom
  else
    return nil
  end
end

---Removes a player from the local room view by publicId. Used when the server
---broadcasts playerLeftRoom (someone left/disconnected mid-room). Doesn't tear
---down the room — remaining players keep the room visible until they manually leave.
---@param publicId integer
function BattleRoom:removePlayerByPublicId(publicId)
  for i = #self.players, 1, -1 do
    if self.players[i].publicId == publicId then
      local p = self.players[i]
      table.remove(self.players, i)
      -- Renumber remaining players to match server (server does the same compaction)
      for j, remaining in ipairs(self.players) do
        remaining.playerNumber = j
      end
      logger.info("BattleRoom: removed player " .. tostring(p.name) .. " (publicId " .. tostring(publicId) .. ")")
      return p
    end
  end
end

---Mark the local room as voided (no more matches can start). Stores the reason for
---display in CharacterSelect / banner. Use room:isVoided() to check.
---@param reason string?
function BattleRoom:setVoided(reason)
  self.voided = true
  self.voidReason = reason
end

---@return boolean
function BattleRoom:isVoided()
  return self.voided == true
end

function BattleRoom.setWinCounts(self, winCounts)
  for _, player in ipairs(self.players) do
    -- win counts are sent indexed by player number
    player:setWinCount(winCounts[player.playerNumber])
  end

  self:updateWinrates()
end

---@param teamWins integer[]? per-team win counts indexed by team_index, or nil for non-team modes
function BattleRoom:setTeamWins(teamWins)
  self.teamWins = teamWins
end

function BattleRoom:updateWinrates()
  local gamesPlayed
  if tableUtils.trueForAny(self.players, function(p) return p.isLocal end) then
    gamesPlayed = self.matchesPlayed
  else
    gamesPlayed = self:totalGames()
  end
  for _, player in ipairs(self.players) do
    if gamesPlayed > 0 then
      local winrate = 100 * math.round(player.wins / gamesPlayed, 2)
      player:setWinrate(winrate)
    else
      player:setWinrate(0)
    end
  end
end

local RATING_SPREAD_MODIFIER = 400
function BattleRoom:updateExpectedWinrates()
  -- this isn't feasible to do for n-player matchups at this point
  if #self.players == 2 and tableUtils.trueForAll(self.players, function(p) return p.rating and tonumber(p.rating) end) then
    local p1 = self.players[1]
    local p2 = self.players[2]
    p1:setExpectedWinrate((100 * math.round(1 / (1 + 10 ^ ((p2.rating - p1.rating) / RATING_SPREAD_MODIFIER)), 2)))
    p2:setExpectedWinrate((100 * math.round(1 / (1 + 10 ^ ((p1.rating - p2.rating) / RATING_SPREAD_MODIFIER)), 2)))
  end
end

-- returns the total amount of games played, derived from the sum of wins across all players
-- (this means draws don't count as games, reference BattleRoom.matchesPlayed if you want draws included)
function BattleRoom:totalGames()
  local totalGames = 0
  for i = 1, #self.players do
    totalGames = totalGames + self.players[i].wins
  end
  return totalGames
end

-- Returns the player with more win count.
-- TODO handle ties?
function BattleRoom:winningPlayer()
  if #self.players == 1 then
    return self.players[1]
  else
    if self.players[1].wins >= self.players[2].wins then
      return self.players[1]
    else
      return self.players[2]
    end
  end
end

---@return PanelSource
function BattleRoom:createPanelSource()
  if self.panelSource then
    return self.panelSource
  else
    return GeneratorSource(math.random(1, 999999), self.mode.stackInteraction ~= GameModes.StackInteractions.NONE)
  end
end

-- creates a match with the players in the BattleRoom
---@return ClientMatch
function BattleRoom:createMatch()
  self.match = ClientMatch.createFromBattleRoom(self)

  self.match:connectSignal("matchEnded", self, self.onMatchEnded)

  for _, player in ipairs(self.players) do
    self.match:connectSignal("matchEnded", player, player.onMatchEnded)
  end

  return self.match
end

---@param gameMode GameMode
function BattleRoom:setGameMode(gameMode)
  self.mode = gameMode
  if gameMode.gameScene then
    self.gameScene = require("client.src.scenes." .. gameMode.gameScene)
  end
end

-- adds an existing Player to the BattleRoom
function BattleRoom:addPlayer(player)
  if not player.playerNumber then
    player.playerNumber = #self.players + 1
  end
  self.players[#self.players + 1] = player

  if player.isLocal then
    self:connectSignal("allAssetsLoadedChanged", player, player.setLoaded)
  end
end

function BattleRoom:updateLoadingState()
  local fullyLoaded = true
  local blockerName, blockerAsset = nil, nil
  for i = 1, #self.players do
    local player = self.players[i]
    local character = characters[player.settings.characterId]
    local stage = stages[player.settings.stageId]
    if not character or not character.fullyLoaded then
      fullyLoaded = false
      if not blockerName then
        blockerName, blockerAsset = player.name, "character " .. tostring(player.settings.characterId)
      end
    end
    if not stage or not stage.fullyLoaded then
      fullyLoaded = false
      if not blockerName then
        blockerName, blockerAsset = player.name, "stage " .. tostring(player.settings.stageId)
      end
    end
  end

  if self.allAssetsLoaded ~= fullyLoaded then
    if fullyLoaded then
      logger.info("BattleRoom: allAssetsLoaded -> true")
    else
      logger.info(string.format("BattleRoom: allAssetsLoaded -> false (blocker: %s needs %s)",
        tostring(blockerName), tostring(blockerAsset)))
    end
    self.allAssetsLoaded = fullyLoaded
    self:emitSignal("allAssetsLoadedChanged", self.allAssetsLoaded)
    if self.allAssetsLoaded then
      -- force a collect of assets that may have gotten unloaded as part of the modloader
      collectgarbage("collect")
      collectgarbage("collect")
    end
  end

  if not self.allAssetsLoaded then
    self:startLoadingNewAssets()
  end
end

function BattleRoom:refreshReadyStates()
  local minimumCondition = tableUtils.trueForAll(self.players, function(p)
    -- everyone remote finished loading and actually wants to start
    return p.isLocal or (p.hasLoaded and p.settings.wantsReady)
  end)

  for _, player in ipairs(self.players) do
    if player.isLocal then
      -- every local human player has an input configuration assigned; touch substitutes for an inputConfiguration
      local ready = minimumCondition
        and self.allAssetsLoaded and player.settings.wantsReady
        and (not player.human or (player.inputConfiguration or player.settings.inputMethod == "touch"))
      player:setReady(ready)
    else
      -- non local players send us their ready via network
    end
  end
end

-- returns true if all players are ready, false otherwise
function BattleRoom:allReady()
  -- ready should probably be a battleRoom prop, not a player prop? at least for local player(s)?
  for playerNumber = 1, #self.players do
    if not self.players[playerNumber].ready then
      return false
    end
  end

  return true
end

function BattleRoom:updateRankedStatus(rankedStatus, comments)
  if self.online then
    self.ranked = rankedStatus
    self.rankedComments = comments or ""
    self:emitSignal("rankedStatusChanged", rankedStatus, comments)
  else
    error("Trying to apply ranked state to the room even though it is either not online or does not support ranked")
  end
end

-- creates a match based on the room and player settings, starts it up and switches to the Game scene
---@param replay ReplayV3?
---@return ClientMatch match
function BattleRoom:startMatch(replay)
  local match
  if replay then
    -- Pass self.mode through so createFromReplay can restore the team config on the
    -- engine (otherwise Match:hasEnded's TEAMS_ACTIVE check is silently skipped on
    -- online team/FFA games and the match never ends until everyone dies).
    match = ClientMatch.createFromReplay(replay, self.players, self.mode)
  else
    match = ClientMatch.createFromBattleRoom(self)
  end

  match:connectSignal("matchEnded", self, self.onMatchEnded)

  for _, player in ipairs(self.players) do
    match:connectSignal("matchEnded", player, player.onMatchEnded)
  end

  if (#match.players > 1 or match.stackInteraction == GameModes.StackInteractions.VERSUS) then
    GAME.rich_presence:setPresence((match:hasLocalPlayer() and "Playing" or "Spectating") .. " a " .. (self.mode.richPresenceLabel or self.mode.gameScene) ..
                                       " match", match.players[1].name .. " vs " .. (match.players[2].name), true)
  else
    GAME.rich_presence:setPresence("Playing " .. self.mode.richPresenceLabel .. " mode", nil, true)
  end

  match:start()
  self.match = match
  self.state = BattleRoom.states.MatchInProgress

  -- Use instant transition if requested, otherwise fade
  local transition = nil
  if not (self.sceneParameters and self.sceneParameters.useInstantTransition) then
    transition = BlackFadeTransition(GAME.timer, 0.4, Easings.getSineIn())
  end

  local scene = self:createScene(match)
  scene:load()
  GAME.navigationStack:push(scene, transition)

  return match
end

function BattleRoom:createScene(match)
  local sceneParams = {match = match}
  
  -- Merge any additional scene parameters
  if self.sceneParameters then
    for key, value in pairs(self.sceneParameters) do
      sceneParams[key] = value
    end
  end
  
  -- for touch android players load a different scene
  if (system.isMobileOS() or DebugSettings.simulateMobileOS()) and self.gameScene.name ~= "PuzzleGame" and
  --but only if they are the only local player cause for 2p vs local using portrait mode would be bad
      tableUtils.count(self.players, function(p) return p.isLocal and p.human end) == 1 then
    for _, player in ipairs(self.players) do
      if player.isLocal and player.human and player.settings.inputMethod == "touch" then
        return require("client.src.scenes.PortraitGame")(sceneParams)
      end
    end
  end
  if self.gameScene then
    return self.gameScene(sceneParams)
  end
end

function BattleRoom:startLoadingNewAssets()
  if ModLoader.loading_mod == nil then
    for _, player in ipairs(self.players) do
      if not stages[player.settings.stageId].fullyLoaded then
        logger.debug("Loading stage " .. player.settings.stageId .. " as part of BattleRoom:startLoadingNewAssets")
        ModController:loadModFor(stages[player.settings.stageId], player)
      end
      if not characters[player.settings.characterId].fullyLoaded then
        logger.debug("Loading stage " .. player.settings.characterId .. " as part of BattleRoom:startLoadingNewAssets")
        ModController:loadModFor(characters[player.settings.characterId], player)
      end
    end
  end
end

-- Validates that there are enough input configurations for local players and attempts to restore previous assignments
function BattleRoom:restoreInputConfigurations()
  local localPlayers = self:getLocalHumanPlayers()

  if #GAME.input:getAssignableDevices() < #localPlayers then
    local transition = MessageTransition(GAME.timer, 5, "more_players_than_configs")
    GAME.navigationStack:popToTop(transition, function() self:shutdown() end)
    return false
  end

  -- Try to restore previous device assignments
  for _, player in ipairs(localPlayers) do
    if player.lastUsedInputConfiguration then
      -- Check if the device is available (not already claimed by another player)
      local deviceAvailable = true
      for _, otherPlayer in ipairs(localPlayers) do
        if otherPlayer ~= player and otherPlayer.inputConfiguration == player.lastUsedInputConfiguration then
          deviceAvailable = false
          break
        end
      end

      if deviceAvailable then
        local success = self:claimDeviceForPlayer(player, player.lastUsedInputConfiguration)
        if success then
          logger.debug(string.format("BattleRoom: restored device for player %d", player.playerNumber))
        end
      end
    end
  end

  return true
end

-- Gets all local human players in the battle room
---@return Player[] localHumanPlayers
function BattleRoom:getLocalHumanPlayers()
  local localPlayers = {}
  for _, player in ipairs(self.players) do
    if player.isLocal and player.human then
      localPlayers[#localPlayers + 1] = player
    end
  end
  return localPlayers
end

-- Claims an input device for a specific player
function BattleRoom:claimDeviceForPlayer(player, device)
  assert(player, "player is required")
  assert(device, "device is required")
  logger.debug(string.format("BattleRoom:claimDeviceForPlayer player=%s device=%s", tostring(player.playerNumber), tostring(device)))

  if player.inputConfiguration == device then
    logger.debug("BattleRoom:claimDeviceForPlayer device already assigned to player")
    return true
  end

  assert(not device.claimed or device.player == player, "device already claimed by another player")

  player:unrestrictInputs()
  player:restrictInputs(device)

  return true
end

function BattleRoom:update(dt)
  -- if there are still unloaded assets, we can load them 1 asset a frame in the background
  ModController:update()

  if self.state == BattleRoom.states.Setup then
    -- the setup phase of the room
    self:updateLoadingState()
    self:refreshReadyStates()
    if self:allReady() then
      -- if online we have to wait for the server message
      if not self.online then
        self:startMatch()
      end
    end
  end
end

function BattleRoom:shutdown()
  for _, player in ipairs(self.players) do
    player:disconnectSubscriber(self)
    player:reset()
  end
  if self.match then
    self.match:deinit()
    self.match = nil
  end
  if self.online then
    GAME.netClient:leaveRoom()
  end
  self.hasShutdown = true
  GAME.battleRoom = nil
  self = nil
end

-- a callback function that is getting registered to the ClientMatch's matchEnded signal
-- may get unregistered from the match in case of abortion
---@param match ClientMatch
function BattleRoom:onMatchEnded(match)
  self.matchesPlayed = self.matchesPlayed + 1

  if not match.engine.aborted then
    local winners = match:getWinners()
    -- apply wins and possibly statistical data up for collection
    if #winners == 1 then
      winners[1].stack.character:playWinSfx()
      if not self.online then
        -- increment win count on winning player if there is only one
        winners[1]:incrementWinCount()
      -- else
      -- in online play the win counts get updated by the server sending out the game result instead
      end
    end
    if self.online and match:hasLocalPlayer() then
      GAME.netClient:reportLocalGameResult(winners)
    end
  else
    -- in the case of a network based abort (== opponent left / disconnected in some way),
    --  the network part of the battleRoom would unregister from the onMatchEnded signal
    --  and initialise the transition to wherever else before calling abort on the match to finalize it
    -- that means whenever we land here, it was a CLIENT SIDE abort that leaves the room intact

    if self.online and match:hasLocalPlayer() then
      -- as the abort is client side we NEED to tell the server we aborted as otherwise the server match stalls
      GAME.netClient:sendMatchAbort()

      if match.engine.desyncError then
        -- match could have a desync error
        -- -> back to select screen, battleRoom stays intact
        -- ^ this behaviour is different to the past but until the server tells us the room is dead there is no reason to assume it to be dead
        local transition = MessageTransition(GAME.timer, 5, "ss_latency_error")
        GAME.navigationStack:pop(transition)
      else
        -- local player could pause and leave
        -- -> back to select screen, battleRoom stays intact
        -- the UI used to abort handles the pop directly
      end
    end

    -- other aborts come via network and are directly handled in response to the network message (or lack thereof)
  end

  -- nilling the match here doesn't keep the game scene from rendering it as the scene has its own reference
  self.match = nil
  self.state = BattleRoom.states.Setup
end

-- called in the errorhandler and thus has a lot worried checking
function BattleRoom:getInfo()
  local info = {}
  if self.players and type(self.players == "table") then
    info.players = {}
    for i, player in ipairs(self.players) do
      if player.getInfo and type(player.getInfo) == "function" then
        info.players[i] = player:getInfo()
      end
    end
  end
  info.online = tostring(self.online)
  info.spectating = tostring(self.spectating)
  info.allAssetsLoaded = tostring(self.allAssetsLoaded)
  info.state = self.state

  return info
end

function BattleRoom:setSpectatorList(spectatorList)
  self.spectators = spectatorList
  local str = ""
  for k, v in ipairs(spectatorList) do
    str = str .. v
    if k < #spectatorList then
      str = str .. "\n"
    end
  end
  if str ~= "" then
    str = loc("pl_spectators") .. "\n" .. str
  end
  self.spectatorString = str
end

function BattleRoom:onDisconnect()
  self:shutdown()
  GAME.navigationStack:popToName("Lobby")
end

function BattleRoom:hasLocalPlayer()
  for _, player in ipairs(self.players) do
    if player.isLocal then
      return true
    end
  end

  return false
end

return BattleRoom
