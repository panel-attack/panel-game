local class = require("common.lib.class")
local TcpClient = require("client.src.network.TcpClient")
local MessageListener = require("client.src.network.MessageListener")
local ServerMessages = require("client.src.network.ServerMessages")
local ClientMessages = require("common.network.ClientProtocol")
local tableUtils = require("common.lib.tableUtils")
local socket = require("common.lib.socket")
local NetworkProtocol = require("common.network.NetworkProtocol")
local logger = require("common.lib.logger")
local Signal = require("common.lib.signal")
local CharacterSelect2p = require("client.src.scenes.CharacterSelect2p")
local SoundController = require("client.src.music.SoundController")
local GameCatchUp = require("client.src.scenes.GameCatchUp")
local GameBase = require("client.src.scenes.GameBase")
local LoginRoutine = require("client.src.network.LoginRoutine")
local TraceWriter = require("client.src.network.TraceWriter")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local LevelData = require("common.data.LevelData")
local GameModes = require("common.data.GameModes")
local TeamUtils = require("common.data.TeamUtils")

---@enum NetClientStates
local states = { OFFLINE = 1, LOGIN = 2, ONLINE = 3, ROOM = 4, INGAME = 5 }
local getSceneFromRoom

-- Most functions of NetClient are private as they only should get triggered via incoming server messages
--  that get automatically processed via NetClient:update

-- Cross-cutting helpers. Defined early so every later local function can
-- reference them — Lua resolves local-name references against the lexical
-- scope at parse time, so forward references silently resolve to a global
-- (nil) instead of the local declared later in the file.

-- One place to clear all per-match input/visual state. Used at every match
-- boundary (start, end, abort, leave, state-transition out of INGAME) to
-- make sure stale input echoes / garbage / death events from a prior match
-- don't bleed into the next one. Safe to call when defers are already nil.
local function _clearMatchInputState(self)
  self.gameplayClient:dropOldInputMessages()
  self.spectateClient:dropOldInputMessages()
  self._deferredInputMsgs = nil
  self._deferredGarbageMsgs = nil
  self._deferredDeathMsgs = nil
end

-- One place to send a gameplay-channel fire-and-forget message (inputs / G / D).
-- These bypass the JSON Request/Response handshake — they're unacked frames.
local function _sendGameplay(self, prefix, body)
  if not self:isConnected() then return end
  self.gameplayClient:send(NetworkProtocol.markedMessageForTypeAndBody(prefix, body))
end

-- Process incoming on a non-critical side socket (lobby or spectate). If it
-- drops, log + reset + emit channelDegraded so the UI can surface it. Side
-- channels are isolation/perf wins, never required for play to continue.
local function _processSideSocket(self, client, channelName)
  if client:isConnected() and not client:processIncomingMessages() then
    logger.warn(channelName .. " socket dropped; resetting. Other channels unaffected.")
    client:resetNetwork()
    self:emitSignal("channelDegraded", channelName)
  end
end

local function resetLobbyData(self)
  ---@class PersonalizedLobbyDataV2
  self.lobbyDataV2 = {
    ---@type table<PublicPlayerID, LobbyPlayerV2>
    players = {},
    ---@type table<PublicPlayerID, table<GameModeID, boolean>>
    outgoingChallenges = {},
    ---@type table<PublicPlayerID, table<GameModeID, boolean>>
    incomingChallenges = {},
    ---@type table<roomNumber, LobbyRoomV2>
    rooms = {}
  }
end

---@param self NetClient
---@param lobbyStateV2Message { content: LobbyStateV2 }
local function updateLobbyStateV2(self, lobbyStateV2Message)
  local lobbyStateV2 = lobbyStateV2Message.content
  if lobbyStateV2.players then
    self.lobbyDataV2.players = lobbyStateV2.players
  end
  self.lobbyDataV2.rooms = lobbyStateV2.rooms or {}
  local localId = GAME.localPlayer and GAME.localPlayer.publicId
  local localRoomNumber = localId and self.lobbyDataV2.players[localId] and self.lobbyDataV2.players[localId].roomNumber

  local function isRoomInviteKey(key)
    return type(key) == "string" and key:match("^room_%d+_%d+$") ~= nil
  end

  local function isInviteSlotStillOpen(inviteKey)
    if type(inviteKey) ~= "string" then
      return false
    end

    local roomNumberStr, slotNumberStr = inviteKey:match("^room_(%d+)_(%d+)$")
    if not roomNumberStr or not slotNumberStr then
      return false
    end

    local room = self.lobbyDataV2.rooms[tonumber(roomNumberStr)]
    local slotNumber = tonumber(slotNumberStr)
    if not room or not room.openSlots or not slotNumber then
      return false
    end

    for _, openSlot in ipairs(room.openSlots) do
      if tonumber(openSlot) == slotNumber then
        return true
      end
    end

    return false
  end

  local function isInviteObsoleteForJoinedPlayer(targetPlayerId, inviteKey)
    if type(inviteKey) ~= "string" then
      return false
    end
    local roomNumberStr, slotNumberStr = inviteKey:match("^room_(%d+)_(%d+)$")
    if not roomNumberStr or not slotNumberStr then
      return false
    end

    local targetRoomNumber = self.lobbyDataV2.players[targetPlayerId] and self.lobbyDataV2.players[targetPlayerId].roomNumber
    local inviteRoomNumber = tonumber(roomNumberStr)
    local inviteSlotNumber = tonumber(slotNumberStr)
    local room = inviteRoomNumber and self.lobbyDataV2.rooms[inviteRoomNumber]
    local slotStillOpen = false
    if room and room.openSlots and inviteSlotNumber then
      for _, openSlot in ipairs(room.openSlots) do
        if tonumber(openSlot) == inviteSlotNumber then
          slotStillOpen = true
          break
        end
      end
    end

    -- Only clear when the target is already in the local player's room.
    -- Also keep other slot invites intact; only remove this key when its slot is no longer open.
    return targetRoomNumber ~= nil
      and localRoomNumber ~= nil
      and targetRoomNumber == localRoomNumber
      and inviteRoomNumber == localRoomNumber
      and not slotStillOpen
  end

  -- if a player we challenged is not in lobby data or is in a room, they cannot accept our challenge anymore
  for publicId, playerChallenges in pairs(self.lobbyDataV2.outgoingChallenges) do
    local roomNumber = self.lobbyDataV2.players[publicId] and self.lobbyDataV2.players[publicId].roomNumber
    if not self.lobbyDataV2.players[publicId] then
      self.lobbyDataV2.outgoingChallenges[publicId] = nil
    else
      for challengeKey, active in pairs(playerChallenges) do
        if isRoomInviteKey(challengeKey) then
          -- Remove stale slot-specific invites when their slot closes, while preserving
          -- other slot invites for the same room/player.
          local roomNumberStr, slotNumberStr = challengeKey:match("^room_(%d+)_(%d+)$")
          local roomNum = tonumber(roomNumberStr)
          local room = roomNum and self.lobbyDataV2.rooms[roomNum]
          local roomIsFull = room and room.openSlots and #room.openSlots == 0
          local slotStillOpen = isInviteSlotStillOpen(challengeKey)
          local shouldClearForClosedSlot = room and (not slotStillOpen)
          
          if roomIsFull or shouldClearForClosedSlot or isInviteObsoleteForJoinedPlayer(publicId, challengeKey) then
            playerChallenges[challengeKey] = nil
          end
        elseif roomNumber and not isRoomInviteKey(challengeKey) then
          playerChallenges[challengeKey] = nil
        end
      end
    end
  end

  -- if a player that challenged us is not in lobby data or is in a room, we cannot accept their challenge anymore
  for publicId, playerChallenges in pairs(self.lobbyDataV2.incomingChallenges) do
    local roomNumber = self.lobbyDataV2.players[publicId] and self.lobbyDataV2.players[publicId].roomNumber
    if not self.lobbyDataV2.players[publicId] then
      self.lobbyDataV2.incomingChallenges[publicId] = nil
    else
      for challengeKey, active in pairs(playerChallenges) do
        if isRoomInviteKey(challengeKey) then
          -- Remove stale slot-specific invites when their slot closes, while preserving
          -- other slot invites for the same room/player.
          local roomNumberStr, slotNumberStr = challengeKey:match("^room_(%d+)_(%d+)$")
          local roomNum = tonumber(roomNumberStr)
          local room = roomNum and self.lobbyDataV2.rooms[roomNum]
          local roomIsFull = room and room.openSlots and #room.openSlots == 0
          local slotStillOpen = isInviteSlotStillOpen(challengeKey)
          local shouldClearForClosedSlot = room and (not slotStillOpen)
          
          if roomIsFull or shouldClearForClosedSlot or isInviteObsoleteForJoinedPlayer(publicId, challengeKey) then
            playerChallenges[challengeKey] = nil
          end
        elseif roomNumber and not isRoomInviteKey(challengeKey) then
          playerChallenges[challengeKey] = nil
        end
      end
    end
  end

  -- Fallback transition: if the local player's room is now full, leave lobby and enter room scene.
  -- This mirrors PvP behavior even if a playerJoinedRoom message was missed or processed out-of-order.
  local localId = GAME.localPlayer and GAME.localPlayer.publicId
  local localRoomNumber = (self.room and self.room.roomNumber)
    or (localId and self.lobbyDataV2.players[localId] and self.lobbyDataV2.players[localId].roomNumber)
  local localLobbyRoom = localRoomNumber and self.lobbyDataV2.rooms[localRoomNumber]
  -- "Full" here means every seat is held by a present player. A held slot
  -- (reserved for a leaver) counts as empty even though openSlots is empty,
  -- so the fallback below must not treat openSlots==0 as full when heldSlots
  -- still has entries — otherwise we'd hard-skip the lobby and push the room
  -- scene with an absent player.
  local heldCount = (localLobbyRoom and localLobbyRoom.heldSlots and #localLobbyRoom.heldSlots) or 0
  local roomIsFull = localLobbyRoom and (
    (localLobbyRoom.maxPlayers and localLobbyRoom.players and #localLobbyRoom.players >= localLobbyRoom.maxPlayers)
    or (localLobbyRoom.openSlots and #localLobbyRoom.openSlots == 0 and heldCount == 0)
  )
  if self.room and roomIsFull and self.state == states.ONLINE then
    local roomScene = getSceneFromRoom(self.room)
    if roomScene then
      GAME.navigationStack:push(roomScene)
      self.state = states.ROOM
    end
  end

  self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
end

---@param room BattleRoom
getSceneFromRoom = function(room)
  local mode = room.mode or {}
  -- FFA (playersPerTeam == 1): every player is their own team, route straight
  -- to the multi-slot character select without a teamCount gate.
  if mode.playersPerTeam == 1 then
    return CharacterSelect2p({battleRoom = room})
  end
  -- Open team modes: teamCount >= 2 with playersPerTeam > 1 (or asymmetric table).
  if mode.teamCount and mode.teamCount >= 2 and mode.playersPerTeam and ((type(mode.playersPerTeam) == "number" and mode.playersPerTeam > 1) or type(mode.playersPerTeam) == "table") then
    return CharacterSelect2p({battleRoom = room})
  end
  -- Fallbacks for other modes
  if room.mode.name == "VS" or room.mode.name == "2p_timeattack" then
    return CharacterSelect2p({battleRoom = room})
  elseif room.mode.name == "endless" then
    return require("client.src.scenes.EndlessMenu")({battleRoom = room})
  elseif room.mode.name == "timeattack" then
    return require("client.src.scenes.TimeAttackMenu")({battleRoom = room})
  elseif room.mode.name == "vsSelf" then
    return require("client.src.scenes.CharacterSelectVsSelf")({battleRoom = room})
  end
end

-- Decide whether a (multiplayer) room has enough players to leave the lobby
-- and enter the waiting room.
--
--  * Fixed-roster rooms (min == max, e.g. invite-only): wait for the full slate.
--  * Dynamic-roster FFA (playersPerTeam == 1, e.g. open_ffa / "open" 7p_ffa):
--    transition once playerCount >= minPlayers.
--  * Dynamic-roster team rooms (playersPerTeam > 1 or table): transition once
--    every team has at least one player. Slots are assigned in arrival order
--    using `playersPerTeam`, so for symmetric brackets (2v2) this naturally
--    requires the first joiner on the second team; for asymmetric brackets
--    (1v3) it can fire as early as the second join.
---@param room BattleRoom
---@return boolean
local function isRoomReadyForWaitingRoom(room)
  local mode = room and room.mode
  if not mode then return false end
  local playerCount = #room.players
  local maxPlayers = mode.playerCount or mode.maxPlayers or 2
  local minPlayers = mode.minPlayers or maxPlayers

  -- Fixed-roster room.
  if minPlayers >= maxPlayers then
    return playerCount >= maxPlayers
  end

  local playersPerTeam = mode.playersPerTeam
  local isTeamMode = playersPerTeam ~= nil and (
    (type(playersPerTeam) == "number" and playersPerTeam > 1) or
    type(playersPerTeam) == "table"
  )

  if isTeamMode then
    local teamCount = mode.teamCount or 2
    local seen = {}
    local covered = 0
    for _, p in ipairs(room.players) do
      local pos = p.playerNumber
      if pos then
        local teamIdx
        if type(playersPerTeam) == "number" then
          teamIdx = math.floor((pos - 1) / playersPerTeam) + 1
        else
          local acc = 0
          for idx, count in ipairs(playersPerTeam) do
            acc = acc + count
            if pos <= acc then
              teamIdx = idx
              break
            end
          end
        end
        if teamIdx and not seen[teamIdx] then
          seen[teamIdx] = true
          covered = covered + 1
        end
      end
    end
    return covered >= teamCount
  end

  -- Dynamic-roster FFA.
  return playerCount >= minPlayers
end

-- starts a 2p vs online match (or joins a team room)
local function start2pVsOnlineMatch(self, createRoomMessage)
  GAME.battleRoom = BattleRoom.createFromServerMessage(createRoomMessage)
  self.room = GAME.battleRoom
  self:registerPlayerUpdates(self.room)

  TraceWriter.beginMatch(self.room and self.room.roomNumber or 0, os.time())
  love.window.requestAttention()
  SoundController:playSfx(themes[config.theme].sounds.notification)

  local function tryEnterWaitingRoom()
    local playerCount = #self.room.players
    local maxPlayers = self.room.mode.playerCount or self.room.mode.maxPlayers or 2
    local hasHeldSlots = self.room.heldSlots and #self.room.heldSlots > 0
    if not isRoomReadyForWaitingRoom(self.room) and not hasHeldSlots then
      -- Stay in lobby - room will show in lobby list with open slots
      logger.info("Joined partial room " .. (self.room.roomNumber or "?") .. " (" .. playerCount .. "/" .. maxPlayers .. " players). Staying in lobby.")
      self.state = states.ONLINE
      if self.lobbyDataV2 and self.room.roomNumber then
        local roomNumber = self.room.roomNumber
        local playerIds = {}
        local playerSlots = {}
        local occupied = {}
        for i, player in ipairs(self.room.players) do
          playerIds[i] = player.publicId
          local slot = player.playerNumber or i
          playerSlots[i] = slot
          occupied[slot] = true
        end
        local openSlots = {}
        for slot = 1, maxPlayers do
          if not occupied[slot] then
            openSlots[#openSlots + 1] = slot
          end
        end
        self.lobbyDataV2.rooms[roomNumber] = {
          roomNumber = roomNumber,
          players = playerIds,
          playerSlots = playerSlots,
          spectators = {},
          state = "waiting",
          wins = {},
          gameModeId = self.room.mode.name,
          maxPlayers = maxPlayers,
          openSlots = openSlots,
          heldSlots = {},
        }
        local localId = GAME.localPlayer.publicId
        if self.lobbyDataV2.players[localId] then
          self.lobbyDataV2.players[localId].roomNumber = roomNumber
        end
        self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
      end
      return
    end
    -- Min players reached (or fixed-roster room filled) - navigate to game scene.
    resetLobbyData(self)
    local roomScene = getSceneFromRoom(self.room)
    if roomScene then
      GAME.navigationStack:push(roomScene)
    else
      logger.warn("No room scene available for mode '" .. tostring(self.room.mode and self.room.mode.name) .. "'. Staying in current scene.")
    end
    self.state = states.ROOM
  end

  tryEnterWaitingRoom()
end

local function processSpectatorListMessage(self, message)
  if self.room then
    self.room:setSpectatorList(message.spectators)
  end
end

---Server replies with joinQueued when a player tries to join an open-FFA room
---while a match is running. The player stays in the lobby; when the match ends
---the server will replay the join via the normal addToRoom flow.
local function processJoinQueuedMessage(self, message)
  local roomNumber = message.joinQueued and message.joinQueued.roomNumber
  logger.info("Join queued for room " .. tostring(roomNumber) .. " (match in progress)")
  self:emitSignal("joinQueued", roomNumber)
end

---@param self NetClient
local function processGameResultMessage(self, message)
  -- receiving a gameResult message means that both players have reported their game results to the server
  -- that means from here on it is expected to receive no further input messages from either player
  -- if we went game over first, the opponent will notice later and keep sending inputs until we went game over on their end too
  -- these extra messages will remain unprocessed in the queue and need to be cleared up so they don't get applied the next match
  _clearMatchInputState(self)

  if not self.room then
    return
  end

  -- Tell the match the server has authoritatively confirmed end. With the
  -- hasEnded-display-only architecture the engine keeps ticking on local
  -- match-end conditions until this signal arrives (or an abort fires).
  if self.room.match and self.room.match.serverConfirmedEnd then
    self.room.match:serverConfirmedEnd()
  end

  for _, roomPlayer in ipairs(self.room.players) do
    local messagePlayer = message.gameResult[roomPlayer.playerNumber]
    if messagePlayer then
      roomPlayer:setWinCount(messagePlayer.winCount)
      roomPlayer:setPlacement(messagePlayer.placement)

      if messagePlayer.ratingInfo then
        local ratingInfo = messagePlayer.ratingInfo
        roomPlayer:setRating(ratingInfo.placement_match_progress or ratingInfo.new)
        roomPlayer:setLeague(ratingInfo.league)
      end
    end
  end

  if message.teamWins then
    self.room:setTeamWins(message.teamWins)
  end

  self.room:updateWinrates()
  self.room:updateExpectedWinrates()
  self:setState(states.ROOM)
end

local function processLeaveRoomMessage(self, message)
  local transition
  if self.room then
    if self.room.match then
      self.room.match:disconnectSignal("matchEnded", self.room)
      self.room.match:abort()
      self.room.match:deinit()
      if message.reason then
        transition = MessageTransition(love.timer.getTime(), 5, message.reason, false)
      end
    end
    self.room:shutdown()
    self.room = nil
    GAME.battleRoom = nil
    TraceWriter.endMatch()
  end

  -- Always clear stale lobbyData entry + transition out of room state, even if
  -- self.room was already nil (e.g., shutdown ran ahead of the ACK). Otherwise
  -- the "Leave game" button stays armed because lobbyDataV2 still shows us in
  -- the room — exactly the stuck state we just fixed.
  if self.lobbyDataV2 then
    local localId = GAME.localPlayer and GAME.localPlayer.publicId
    if localId and self.lobbyDataV2.players[localId] then
      self.lobbyDataV2.players[localId].roomNumber = nil
    end
    self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
  end

  if self.state == states.INGAME or self.state == states.ROOM then
    self:setState(states.ONLINE)
    GAME.navigationStack:popToName("Lobby", transition)
  end
end

local function processTauntMessage(self, message)
  if not self.room then
    return
  end

  local characterId = tableUtils.first(self.room.players, function(player)
    return player.playerNumber == message.player_number
  end).settings.characterId
  characters[characterId]:playTaunt(message.type, message.index)
end

---@param self NetClient
---@param message { replay: ReplayV3, [string]: any }
local function processMatchStartMessage(self, message)
  if not self.room then
    return
  end

  for j, player in ipairs(self.room.players) do
    for i, metadata in ipairs(message.replay.metadata.stacks) do
      if player.playerNumber == metadata.stackIndex then
        if player.human then
          ---@cast metadata StackMetadata
          if metadata.level and metadata.level ~= player.settings.level then
            player:setLevel(metadata.level)
          end
        end
      end
    end

    for i, stackSettings in ipairs(message.replay.stacks) do
      if player.playerNumber == i then
        if player.human then
          ---@cast stackSettings ReplayStack
          if LevelData.validate(stackSettings.levelData) and not LevelData.__eq(stackSettings.levelData, player.settings.levelData) then
            setmetatable(stackSettings.levelData, LevelData)
            player:setLevelData(stackSettings.levelData)
          end

          if stackSettings.inputMethod ~= player.settings.inputMethod then
            -- since only one player can claim touch, touch is unclaimed every time we return to character select
            -- this also means they will send controller as their input method until they ready up
            -- if the remote touch player readies up AFTER the local client, we never get informed about the change in input method
            -- besides for the match start message itself
            -- likewise if the local player readies up with touch and then unreadies their inputMethod will flip back to controller so we even have to overwrite the local player setting
            -- so it's very important to set this here
            player:setInputMethod(stackSettings.inputMethod)
          end

          if player.isLocal then
            if not player.inputConfiguration then
              -- fallback in case the player lost their input config while the server sent the message
              if player.settings.inputMethod == "touch" then
                player:restrictInputs(GAME.input.getTouchInputConfiguration())
              elseif player.lastUsedInputConfiguration then
                if player.lastUsedInputConfiguration.deviceType == "touch" then
                  -- there is no configuration and the last one is a touch configuration
                  -- while we could assume that the player wanted to use touch after all, if the server reports the setting as controller, we can no longer change
                  -- because the other client already has us clocked as controller and the inputs have to match
                  -- there is no way to know which input configuration the player would want to use in this scenario so throw an error
                  error("Player's input configuration does not match input method " .. player.settings.inputMethod .. " sent by server.")
                else
                  player:restrictInputs(player.lastUsedInputConfiguration)
                end
              end
            end
          end
          -- generally I don't think it's a good idea to try and rematch the other diverging settings here
          -- everyone is loaded and ready which can only happen after character/panel data was already exchanged
          -- if they diverge it's because the chosen mod is missing on the other client
          -- generally I think server should only send physics relevant data with match_start
        end
      end
    end
  end

  if self.state == states.INGAME then
    -- if there is a match in progress when receiving a match start that means we are in the process of catching up via transition
    -- deinit and nil to cancel the catchup
    self.room.match:deinit()
    self.room.match = nil

    -- although the most important thing is replacing the on-going transition but startMatch already does that as a default
  end

  _clearMatchInputState(self)
  local match = self.room:startMatch(message.replay)
  self:setState(states.INGAME)
  if match.supportsPause and match:hasLocalPlayer() then
    match:connectSignal("pauseChanged", self, self.sendPauseToggle)
  end
  -- Translate the server's scheduled start moment to our local clock if we have
  -- a server-time-offset estimate. GameBase:runGame holds engine ticks until then.
  if message.startAtMs and self.lobbyClient and self.lobbyClient.serverOffsetMs then
    match.scheduledStartLocalMs = message.startAtMs - self.lobbyClient.serverOffsetMs
  end
end

---@param self NetClient
local function processRankedStatusMessage(self, message)
  if not self.room then
    return
  end

  local rankedStatus = message.ranked_match_approved or false
  local comments = ""
  if message.reasons then
    comments = comments .. table.concat(message.reasons, "\n")
  end
  if message.caveats then
    comments = comments .. table.concat(message.caveats, "\n")
  end
  self.room:updateRankedStatus(rankedStatus, comments)
end

---@param self NetClient
local function processPlayerJoinedRoom(self, message)
  if not self.room then
    return
  end

  -- A new player joined the room - create a Player and add them to the BattleRoom
  local playerData = message.playerJoinedRoom
  if playerData then
    local existingPlayer = tableUtils.first(self.room.players, function(p)
      return p.publicId == playerData.publicId
    end)
    if existingPlayer then
      if playerData.settings then
        existingPlayer:updateSettings(playerData.settings)
      end
    else
      local Player = require("client.src.Player")
      local player = Player(playerData.name, playerData.publicId, false)
      player.playerNumber = playerData.playerNumber
      if playerData.settings then
        player:updateSettings(playerData.settings)
      end
      self.room:addPlayer(player)
    end
    -- If this joiner was the holder of a reserved seat, release it locally so
    -- the in-room view stops showing "waiting for <name>". The server clears
    -- the reservation on join too; this just mirrors that state without
    -- waiting for the next lobbyStateV2 snapshot.
    if self.room.heldSlots and playerData.publicId then
      for i = #self.room.heldSlots, 1, -1 do
        if self.room.heldSlots[i].publicId == playerData.publicId then
          table.remove(self.room.heldSlots, i)
        end
      end
    end
    self:registerPlayerUpdates(self.room)
    love.window.requestAttention()
    SoundController:playSfx(themes[config.theme].sounds.notification)

    -- Immediately check if the room is now ready for the waiting room (e.g., one player per team)
    -- and trigger the transition for all clients, including the host.
    local alreadyInRoom = self.state == states.ROOM or self.state == states.INGAME
    if isRoomReadyForWaitingRoom(self.room) and not alreadyInRoom then
      logger.info("[playerJoin] Room " .. (self.room.roomNumber or "?") .. " ready for waiting room (" .. #self.room.players .. " player(s)). Navigating to game scene.")
      local roomScene = getSceneFromRoom(self.room)
      if roomScene then
        GAME.navigationStack:push(roomScene)
      else
        logger.warn("[playerJoin] No room scene available for mode '" .. tostring(self.room.mode and self.room.mode.name) .. "'.")
      end
      self.state = states.ROOM
    end
  end
end

---@param self NetClient
local function processPlayerLeftRoom(self, message)
  if not self.room then
    return
  end

  local data = message.playerLeftRoom
  if not data or not data.publicId then
    return
  end

  -- Remove the leaver from the local room view. Only void the room when the
  -- server says so (mid-game abort); no voidReason means the room stays open
  -- and the leaver can rejoin from the lobby.
  self.room:removePlayerByPublicId(data.publicId)
  if data.voidReason then
    self.room:setVoided(data.voidReason)
  end
  -- Refresh held-slot snapshot so the room view can show "waiting for <name>"
  -- on the seat just vacated (fixed-roster rooms) or leave it empty for fcfs
  -- (open-FFA). Server sends an empty array for the latter.
  self.room.heldSlots = data.heldSlots or {}
end

local function processMenuStateMessage(player, message)
  local menuState = message.menu_state
  if menuState.playerNumber then
    -- only update if playernumber matches the player's
    if menuState.playerNumber == player.playerNumber then
      player:updateSettings(menuState)
    else
      -- this update is for someone else
    end
  else
    player:updateSettings(menuState)
  end
end

-- Drain a prefix from BOTH the gameplay and spectate queues. Same
-- message type can arrive on either socket depending on the recipient
-- context (gameplay = data targeting you; spectate = opponent visuals).
-- Order: gameplay first so your-critical events apply before bulk visuals.
local function _drainBoth(self, prefix)
  local out = {}
  for _, m in ipairs(self.gameplayClient.receivedMessageQueue:pop_all_with(prefix)) do
    out[#out+1] = m
  end
  for _, m in ipairs(self.spectateClient.receivedMessageQueue:pop_all_with(prefix)) do
    out[#out+1] = m
  end
  return out
end

-- Per-tick wall-clock budget for visual-only message work. Local-gameplay
-- messages (garbage targeting you) bypass this and always apply.
local VISUAL_MESSAGE_BUDGET_MS = 4

local function _localSlot(self)
  if not self.room or not self.room.match or not self.room.match.stacks then return nil end
  for i, stack in ipairs(self.room.match.stacks) do
    if stack and stack.is_local then return i end
  end
  return nil
end

-- Drains deferred FIFO then fresh under the budget; always applies at least one.
local function _drainBudgeted(self, deferKey, fresh, applyFn)
  self[deferKey] = self[deferKey] or {}
  local deferred = self[deferKey]
  local startMs = socket.gettime() * 1000
  local applied = 0

  while #deferred > 0 do
    if applied > 0 and (socket.gettime() * 1000 - startMs) > VISUAL_MESSAGE_BUDGET_MS then break end
    applyFn(table.remove(deferred, 1))
    applied = applied + 1
  end

  for _, msg in ipairs(fresh) do
    if applied > 0 and (socket.gettime() * 1000 - startMs) > VISUAL_MESSAGE_BUDGET_MS then
      deferred[#deferred + 1] = msg
    else
      applyFn(msg)
      applied = applied + 1
    end
  end
end

local function processInputMessages(self)
  local inputPrefix = NetworkProtocol.serverMessageTypes.input.prefix
  local messages = _drainBoth(self, inputPrefix)
  if not (self.room and self.room.match) then return end
  -- All I are visual: server never echoes your own inputs.
  _drainBudgeted(self, "_deferredInputMsgs", messages, function(msg)
    local body = msg[inputPrefix]
    if body then self.room.match:receiveInput(body.playerNumber, body.input) end
  end)
end

---@param self NetClient
local function processGarbageEvents(self)
  local prefix = NetworkProtocol.serverMessageTypes.garbageEvent.prefix
  local messages = _drainBoth(self, prefix)
  if not (self.room and self.room.match) then return end
  -- G targeting local stack bypasses budget; rest is visual.
  local localSlot = _localSlot(self)
  local visual = {}
  for _, msg in ipairs(messages) do
    local body = msg[prefix]
    if not body then
      -- skip malformed
    elseif localSlot and body.recipients and tableUtils.contains(body.recipients, localSlot) then
      self.room.match:applyGarbageEvent(body)
    else
      visual[#visual + 1] = msg
    end
  end

  _drainBudgeted(self, "_deferredGarbageMsgs", visual, function(msg)
    local body = msg[prefix]
    if body then self.room.match:applyGarbageEvent(body) end
  end)
end

---@param self NetClient
local function processDeathEvents(self)
  local prefix = NetworkProtocol.serverMessageTypes.deathEvent.prefix
  local messages = _drainBoth(self, prefix)
  if not (self.room and self.room.match) then return end
  -- All D are visual: applyDeathEvent early-returns for is_local.
  _drainBudgeted(self, "_deferredDeathMsgs", messages, function(msg)
    local body = msg[prefix]
    if body then self.room.match:applyDeathEvent(body) end
  end)
end

---@param self NetClient
local function processChallengeUpdate(self, challengeUpdateMessage)
  if challengeUpdateMessage.challengeUpdate then
    local challengeUpdate = challengeUpdateMessage.challengeUpdate
    local challenges = self.lobbyDataV2.incomingChallenges[challengeUpdate.senderId] or {}
    -- Use slot-specific key for room invites so each slot tracks independently
    local key = challengeUpdate.roomNumber
      and ("room_" .. challengeUpdate.roomNumber .. "_" .. (challengeUpdate.slotNumber or 0))
      or challengeUpdate.gameModeId
    logger.info(string.format("Received challengeUpdate from %s: key=%s, active=%s, room=%s, slot=%s",
      tostring(challengeUpdate.senderId),
      tostring(key),
      tostring(challengeUpdate.challengeActive),
      tostring(challengeUpdate.roomNumber),
      tostring(challengeUpdate.slotNumber)))
    challenges[key] = challengeUpdate.challengeActive
    self.lobbyDataV2.incomingChallenges[challengeUpdate.senderId] = challenges
    if challengeUpdate.challengeActive then
      love.window.requestAttention()
      SoundController:playSfx(themes[config.theme].sounds.notification)
    end
    self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
  end
end

-- starts to spectate a 2p vs online match
local function spectate2pVsOnlineMatch(self, spectateRequestGrantedMessage)
  resetLobbyData(self)
  GAME.battleRoom = BattleRoom.createFromServerMessage(spectateRequestGrantedMessage)
  self.room = GAME.battleRoom
  self:registerPlayerUpdates(self.room)
  local roomScene = getSceneFromRoom(self.room)
  if GAME.battleRoom.match then
    -- Clear any defer queues left over from a previous match (e.g., your own
    -- match where TCP dropped without a clean gameResult/gameAbort). Slot
    -- indices are per-match; stale events would apply to wrong stacks.
    _clearMatchInputState(self)
    self.state = states.INGAME
    local vsScene = GameBase({match = GAME.battleRoom.match})
    vsScene:load()
    local catchUp = GameCatchUp(vsScene)
    -- need to push character select, otherwise the pop on match end will return to lobby
    -- directly add to the stack so it isn't getting displayed
    if roomScene then
      GAME.navigationStack.scenes[#GAME.navigationStack.scenes+1] = roomScene
    else
      logger.warn("No room scene available for spectator mode '" .. tostring(self.room.mode and self.room.mode.name) .. "'.")
    end
    GAME.navigationStack:push(catchUp)
  else
    self.state = states.ROOM
    if roomScene then
      GAME.navigationStack:push(roomScene)
    else
      logger.warn("No room scene available for spectator mode '" .. tostring(self.room.mode and self.room.mode.name) .. "'. Staying in current scene.")
    end
  end
end

---@param self NetClient
local function handleGameAbort(self, gameAbortMessage)
  if self.room and self.room.match and self.state == states.INGAME then
    _clearMatchInputState(self)
    -- we're ending the game via an abort so we don't want to enter the standard onMatchEnd callback
    self.room.match:disconnectSignal("matchEnded", self.room)
    -- instead we actively abort the match ourselves
    self.room.match:abort()
    self.room.match:deinit()
    self.state = states.ROOM
    if not gameAbortMessage.source or gameAbortMessage.source ~= GAME.localPlayer.name then
      -- only pop if the local player is not the source of the abort
      -- otherwise this might obscure the network error
      local infoMessage = loc("game_abort", gameAbortMessage.source or loc("unknown_player"))
      if gameAbortMessage.reason and gameAbortMessage.reason == "latency_error" then
        infoMessage = infoMessage .. ": " .. loc("ss_latency_error")
      end
      transition = MessageTransition(love.timer.getTime(), 5, infoMessage, false)
      GAME.navigationStack:pop(transition)
    end
  end
end

local function createListener(self, messageType, callback)
  local listener = MessageListener(messageType)
  listener:subscribe(self, callback)
  return listener
end

local function createListeners(self)
  -- messageListener holds *all* available listeners
  local messageListeners = {}
  messageListeners.create_room = createListener(self, "create_room", start2pVsOnlineMatch)
  messageListeners.addToRoom = createListener(self, "addToRoom", start2pVsOnlineMatch)
  messageListeners.playerJoinedRoom = createListener(self, "playerJoinedRoom", processPlayerJoinedRoom)
  messageListeners.playerLeftRoom = createListener(self, "playerLeftRoom", processPlayerLeftRoom)
  messageListeners.lobbyStateV2 = createListener(self, "lobbyStateV2", updateLobbyStateV2)
  messageListeners.challengeUpdate = createListener(self, "challengeUpdate", processChallengeUpdate)
  messageListeners.menu_state = createListener(self, "menu_state", processMenuStateMessage)
  messageListeners.ranked_match_approved = createListener(self, "ranked_match_approved", processRankedStatusMessage)
  messageListeners.leave_room = createListener(self, "leave_room", processLeaveRoomMessage)
  messageListeners.match_start = createListener(self, "match_start", processMatchStartMessage)
  messageListeners.taunt = createListener(self, "taunt", processTauntMessage)
  messageListeners.gameResult = createListener(self, "gameResult", processGameResultMessage)
  messageListeners.spectators = createListener(self, "spectators", processSpectatorListMessage)
  messageListeners.gameAbort = createListener(self, "gameAbort", handleGameAbort)
  messageListeners.joinQueued = createListener(self, "joinQueued", processJoinQueuedMessage)
  -- Handles both explicit Spectate and the server's join->pending-promote conversion.
  messageListeners.spectate_request_granted = createListener(self, "spectate_request_granted", function(self, msg)
    self.pendingResponses.spectateResponse = nil
    spectate2pVsOnlineMatch(self, msg)
  end)

  return messageListeners
end

---@class NetClient : Signal
---@field gameplayClient TcpClient
---@field lobbyClient TcpClient
---@field spectateClient TcpClient
---@field leaderboard table
---@field pendingResponses table
---@field state NetClientStates
---@field lobbyListeners table
---@field roomListeners table
---@field matchListeners table
---@field messageListeners table
---@field room BattleRoom?
---@field lobbyDataV2 PersonalizedLobbyDataV2
---@field serverTimeDelta integer in seconds
---@overload fun(): NetClient
local NetClient = class(function(self)
  -- Triple-socket split (three independent TCP connections via one shared class):
  --   gameplayClient → YOUR critical traffic (outgoing I, incoming G targeting you, K)
  --   spectateClient → opponents' I/G/D (rendering their boards) — bulky, isolated
  --   lobbyClient    → J (lobby/room/chat/replays/settings)
  -- Independent sockets, independent failure. Gameplay drop = full disconnect.
  -- Spectate drop = opponents' boards freeze for that player but their own
  -- game continues. Lobby drop = silent reconnect.
  self.gameplayClient = TcpClient({name = "gameplay", defaultPort = 49569})
  self.lobbyClient    = TcpClient({name = "lobby",    defaultPort = 49570})
  self.spectateClient = TcpClient({name = "spectate", defaultPort = 49571})
  -- For ops that need every client (reset/updateNetwork/lag config).
  -- Named fields stay for ops that target a specific channel.
  self.clients = { self.gameplayClient, self.lobbyClient, self.spectateClient }
  self.leaderboard = nil

  local lagMs = tonumber(os.getenv("PA_NETWORK_LAG_MS"))
  local lagMinMs = tonumber(os.getenv("PA_NETWORK_LAG_MIN_MS")) or lagMs
  local lagMaxMs = tonumber(os.getenv("PA_NETWORK_LAG_MAX_MS")) or lagMs
  if lagMinMs and lagMinMs > 0 then
    local sMin = lagMinMs / 1000
    local sMax = (lagMaxMs or lagMinMs) / 1000
    for _, client in ipairs(self.clients) do
      client:activateDelayedProcessing()
      client:setNetworkLag(sMin, sMax, sMin, sMax)
    end
    logger.info(string.format("Simulating network lag: %d-%d ms each direction on all 3 sockets", lagMinMs, lagMaxMs or lagMinMs))
  end
  self.pendingResponses = {}
  self.state = states.OFFLINE
  self.serverTimeDelta = 0

  resetLobbyData(self)

  local messageListeners = createListeners(self)

  -- all listeners running while online but not in a room/match
  self.lobbyListeners = {
    players = messageListeners.players,
    lobbyStateV2 = messageListeners.lobbyStateV2,
    create_room = messageListeners.create_room,
    addToRoom = messageListeners.addToRoom,
    playerJoinedRoom = messageListeners.playerJoinedRoom,
    challengeUpdate = messageListeners.challengeUpdate,
    leave_room = messageListeners.leave_room,
    joinQueued = messageListeners.joinQueued,
    spectate_request_granted = messageListeners.spectate_request_granted,
  }

  -- all listeners running while in a room but not in a match
  self.roomListeners = {
    ranked_match_approved = messageListeners.ranked_match_approved,
    leave_room = messageListeners.leave_room,
    match_start = messageListeners.match_start,
    spectators = messageListeners.spectators,
    gameResult = messageListeners.gameResult,
    playerJoinedRoom = messageListeners.playerJoinedRoom,
    playerLeftRoom = messageListeners.playerLeftRoom,
  }

  -- all listeners running while in a match
  self.matchListeners = {
    leave_room = messageListeners.leave_room,
    taunt = messageListeners.taunt,
    -- for spectators catching up to an ongoing match, a match_start acts as a cancel
    match_start = messageListeners.match_start,
    spectators = messageListeners.spectators,
    gameResult = messageListeners.gameResult,
    gameAbort = messageListeners.gameAbort,
    playerLeftRoom = messageListeners.playerLeftRoom,
  }

  self.messageListeners = messageListeners

  self.room = nil

  Signal.turnIntoEmitter(self)
  self:createSignal("lobbyStateUpdate")
  self:createSignal("lobbyStateV2Update")
  self:createSignal("leaderboardUpdate")
  -- only fires for unintended disconnects
  self:createSignal("clientDisconnected")
  self:createSignal("loginFinished")
  -- emitted with (channelName) when a side socket (lobby/spectate) drops
  self:createSignal("channelDegraded")
end)

NetClient.STATES = states

function NetClient:leaveRoom()
  -- Trust the lobby's view too: if lobbyDataV2 says we're in a room but
  -- self.room is nil (state-divergence from a half-completed prior leave or
  -- a partial-join + disconnect), the "Leave game" button on Lobby still
  -- needs to send the request so the server can clean its side.
  local localId = GAME.localPlayer and GAME.localPlayer.publicId
  local lobbySaysInRoom = self.lobbyDataV2 and self.lobbyDataV2.players
      and localId and self.lobbyDataV2.players[localId]
      and self.lobbyDataV2.players[localId].roomNumber ~= nil
  if self:isConnected() and (self.room or lobbySaysInRoom) then
    _clearMatchInputState(self)
    self.lobbyClient:sendRequest(ClientMessages.leaveRoom())
    -- the server sends us back the confirmation that we left the room
    -- so we reenter ONLINE state via processLeaveRoomMessage, not here
  elseif self.room then
    -- Connection lost but we're still in a room locally - clean up
    logger.info("Cleaning up room locally (disconnected)")
    local roomNumber = self.room.roomNumber
    self.room:shutdown()
    self.room = nil
    GAME.battleRoom = nil

    -- Update local lobby data
    if self.lobbyDataV2 and roomNumber then
      self.lobbyDataV2.rooms[roomNumber] = nil
      local localId = GAME.localPlayer.publicId
      if self.lobbyDataV2.players[localId] then
        self.lobbyDataV2.players[localId].roomNumber = nil
      end
      self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
    end
  end
end

function NetClient:reportLocalGameResult(winners)
  winners = winners or {}
  if #winners == 0 then
    return  -- aborted match, handled separately via sendMatchAbort
  end

  local gameMode = self.room and self.room.mode
  local isTeamGame = gameMode and gameMode.teamCount

  if isTeamGame then
    local totalPlayers = gameMode.playerCount or #self.room.players
    if #winners >= totalPlayers then
      -- all players tied (everyone died simultaneously)
      self.lobbyClient:sendRequest(ClientMessages.reportLocalGameResult(0))
    else
      -- "Did MY TEAM win" — not "is my own stack in the winners list". A teammate
      -- who died is still on the winning team if their teammate finished off the
      -- enemies. Without this, the dead teammate would report 2 (lost) while the
      -- alive teammate reports 1 (won), the server would see the team disagree, and
      -- the whole match would resolve as a tie instead of a team win.
      local localTeamWon = false
      local match = self.room.match
      if match and match.engine and match.engine.teams then
        local winningTeam = match.engine:getWinningTeam()
        if winningTeam then
          for i, player in ipairs(match.players) do
            if player.isLocal then
              local slot = (player and player.playerNumber) or i
              local localTeamIndex = TeamUtils.getPlayerTeamIndex(match.engine.teams, slot)
              if localTeamIndex == winningTeam.id then
                localTeamWon = true
              end
              break
            end
          end
        end
      end
      self.lobbyClient:sendRequest(ClientMessages.reportLocalGameResult(localTeamWon and 1 or 2))
    end
  else
    -- non-team: report winner's player number, or 0 for any tie
    if #winners >= 2 then
      self.lobbyClient:sendRequest(ClientMessages.reportLocalGameResult(0))
    else
      self.lobbyClient:sendRequest(ClientMessages.reportLocalGameResult(winners[1].playerNumber))
    end
  end
end

function NetClient:sendTauntUp(index)
  if self:isConnected() then
    self.lobbyClient:sendRequest(ClientMessages.sendTaunt("up", index))
  end
end

function NetClient:sendTauntDown(index)
  if self:isConnected() then
    self.lobbyClient:sendRequest(ClientMessages.sendTaunt("down", index))
  end
end

function NetClient:sendInput(input)
  _sendGameplay(self, NetworkProtocol.clientMessageTypes.playerInput.prefix, input)
end

---Loose-sync: send a GarbageEvent from the local sim. body is JSON-encoded inline
---(no Request wrapper — these are fire-and-forget like inputs).
---@param body table parsed event payload
function NetClient:sendGarbageEvent(body)
  _sendGameplay(self, NetworkProtocol.clientMessageTypes.garbageEvent.prefix, json.encode(body))
end

---Loose-sync: send a DeathEvent from the local sim.
---@param body table parsed event payload
function NetClient:sendDeathEvent(body)
  _sendGameplay(self, NetworkProtocol.clientMessageTypes.deathEvent.prefix, json.encode(body))
end

---@param clientMatch ClientMatch
function NetClient:sendPauseToggle(clientMatch)
  if self:isConnected() and self.room and self.room.roomNumber then
    self.lobbyClient:sendRequest(ClientMessages.sendPauseToggle(self.room.roomNumber, clientMatch.isPaused))
  end
end

---@param gameModeId GameModeID?
function NetClient:requestLeaderboard(gameModeId)
  if not self.pendingResponses.leaderboardUpdate then
    gameModeId = gameModeId or GameModes.IDs.TWO_PLAYER_VS
    self.pendingResponses.leaderboardUpdate = self.lobbyClient:sendRequest(ClientMessages.requestLeaderboard(gameModeId))
  end
end

---@param opponentId PublicPlayerID
---@param gameModeId GameModeID
function NetClient:challengePlayerById(opponentId, gameModeId)
  self.lobbyDataV2.outgoingChallenges[opponentId] = self.lobbyDataV2.outgoingChallenges[opponentId] or {}
  self.lobbyClient:sendRequest(ClientMessages.updateChallengeStatus(GAME.localPlayer.publicId, opponentId, gameModeId, true))
  self.lobbyDataV2.outgoingChallenges[opponentId][gameModeId] = true
  self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
end

---@param roomNumber integer
---@return GameModeID?
local function getRoomGameModeId(roomNumber)
  local lobbyRoom = GAME.netClient
    and GAME.netClient.lobbyDataV2
    and GAME.netClient.lobbyDataV2.rooms
    and GAME.netClient.lobbyDataV2.rooms[roomNumber]
  return lobbyRoom and lobbyRoom.gameModeId or nil
end

---@param opponentId PublicPlayerID
---@param roomNumber integer
---@param slotNumber integer
---@param gameModeId GameModeID?
function NetClient:invitePlayerToRoom(opponentId, roomNumber, slotNumber, gameModeId)
  gameModeId = gameModeId or getRoomGameModeId(roomNumber) or GameModes.IDs.TWO_PLAYER_VS
  local inviteKey = "room_" .. roomNumber .. "_" .. slotNumber
  logger.info(string.format("Sending invite to player %s for room %d slot %d (key=%s)", tostring(opponentId), roomNumber, slotNumber, inviteKey))
  self.lobbyDataV2.outgoingChallenges[opponentId] = self.lobbyDataV2.outgoingChallenges[opponentId] or {}
  self.lobbyClient:sendRequest(ClientMessages.updateChallengeStatus(GAME.localPlayer.publicId, opponentId, gameModeId, true, roomNumber, slotNumber))
  self.lobbyDataV2.outgoingChallenges[opponentId][inviteKey] = true
  logger.info(string.format("outgoingChallenges after invite: %s", json.encode(self.lobbyDataV2.outgoingChallenges)))
  self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
end

---@param opponentId PublicPlayerID
---@param roomNumber integer
---@param slotNumber integer
---@param gameModeId GameModeID?
function NetClient:withdrawRoomInvite(opponentId, roomNumber, slotNumber, gameModeId)
  gameModeId = gameModeId or getRoomGameModeId(roomNumber) or GameModes.IDs.TWO_PLAYER_VS
  local inviteKey = "room_" .. roomNumber .. "_" .. slotNumber
  self.lobbyDataV2.outgoingChallenges[opponentId] = self.lobbyDataV2.outgoingChallenges[opponentId] or {}
  self.lobbyClient:sendRequest(ClientMessages.updateChallengeStatus(GAME.localPlayer.publicId, opponentId, gameModeId, false, roomNumber, slotNumber))
  self.lobbyDataV2.outgoingChallenges[opponentId][inviteKey] = false
  self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
end

function NetClient:withdrawChallengeForId(opponentId, gameModeId)
  if self.lobbyDataV2.outgoingChallenges[opponentId] then
    self.lobbyClient:sendRequest(ClientMessages.updateChallengeStatus(GAME.localPlayer.publicId, opponentId, gameModeId, false))
    self.lobbyDataV2.outgoingChallenges[opponentId] = self.lobbyDataV2.outgoingChallenges[opponentId] or {}
    self.lobbyDataV2.outgoingChallenges[opponentId][gameModeId] = false
    self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
  end
end

function NetClient:requestSpectate(roomNumber)
  if not self.pendingResponses.spectateResponse then
    self.pendingResponses.spectateResponse = self.lobbyClient:sendRequest(ClientMessages.requestSpectate(config.name, roomNumber))
  end
end

---@param roomNumber integer
---@param slotNumber integer
function NetClient:requestJoinRoom(roomNumber, slotNumber)
  if self:isConnected() then
    logger.info("Sending joinRoomRequest for room " .. tostring(roomNumber) .. " slot " .. tostring(slotNumber))
    self.lobbyClient:sendRequest(ClientMessages.requestJoinRoom(roomNumber, slotNumber))
  end
end

---@param gameMode GameMode|GameModeID|string
---@param latencyTolerance ("strict"|"normal"|"relaxed")?
---@param openRoom boolean? whether this room should accept direct joiners (no invite handshake)
function NetClient:requestRoom(gameMode, latencyTolerance, openRoom)
  if self:isConnected() then
    if type(gameMode) == "string" then
      local ok, resolvedGameMode = pcall(GameModes.getPreset, gameMode)
      if ok then
        gameMode = resolvedGameMode
      else
        logger.error("Refusing room request for unknown game mode id: " .. tostring(gameMode))
        return
      end
    end

    if type(gameMode) ~= "table" or type(gameMode.getGameModeJSONData) ~= "function" then
      logger.error("Refusing room request with invalid game mode payload")
      return
    end

    self.lobbyClient:sendRequest(ClientMessages.sendRoomRequest(gameMode, latencyTolerance, openRoom))
  end
end

function NetClient:sendMatchAbort()
  if self:isConnected() then
    self.lobbyClient:sendRequest(ClientMessages.sendMatchAbort())
    self:setState(states.ROOM)
  end
end

function sendPlayerSettings(player)
  GAME.netClient.lobbyClient:sendRequest(ClientMessages.sendPlayerSettings(ServerMessages.toServerMenuState(player)))
end

function NetClient:sendPlayerSettings(player)
  self.lobbyClient:sendRequest(ClientMessages.sendPlayerSettings(ServerMessages.toServerMenuState(player)))
end

function NetClient:registerPlayerUpdates(room)
  local listener = MessageListener("menu_state")
  for _, player in ipairs(room.players) do
    if player.isLocal then
      if not player._netClientSettingsHooked then
        -- seems a bit silly to subscribe a player to itself but it works and the player doesn't have to become part of the closure
        player:connectSignal("characterIdChanged", player, sendPlayerSettings)
        player:connectSignal("selectedCharacterIdChanged", player, sendPlayerSettings)
        player:connectSignal("stageIdChanged", player, sendPlayerSettings)
        player:connectSignal("selectedStageIdChanged", player, sendPlayerSettings)
        player:connectSignal("panelIdChanged", player, sendPlayerSettings)
        player:connectSignal("wantsRankedChanged", player, sendPlayerSettings)
        player:connectSignal("wantsReadyChanged", player, sendPlayerSettings)
        player:connectSignal("difficultyChanged", player, sendPlayerSettings)
        player:connectSignal("startingSpeedChanged", player, sendPlayerSettings)
        player:connectSignal("levelChanged", player, sendPlayerSettings)
        player:connectSignal("levelDataChanged", player, sendPlayerSettings)
        player:connectSignal("inputMethodChanged", player, sendPlayerSettings)
        player:connectSignal("hasLoadedChanged", player, sendPlayerSettings)
        player._netClientSettingsHooked = true
      end
    else
      listener:subscribe(player, processMenuStateMessage)
    end
  end
  self.messageListeners.menu_state = listener
  self.roomListeners.menu_state = listener
end

---@param errorData table
---@param server string
---@param port integer
function NetClient:sendErrorReport(errorData, server, port)
  logger.warn("sendErrorReport blocked in unofficial build; no report sent")
end

function NetClient:isConnected()
  -- Gameplay socket is the critical one. Lobby socket independently up/down
  -- doesn't change "are we logged in and playing?"
  return self.gameplayClient:isConnected()
end

function NetClient:login(ip, port)
  if not self:isConnected() then
    local gameplayPort = port
    -- Port convention: SERVER_PORT (gameplay), SERVER_PORT+1 (lobby),
    -- SERVER_PORT+2 (spectate). Mirrors server_globals on the server.
    local lobbyPort = (port or 49569) + 1
    local spectatePort = (port or 49569) + 2
    self.loginRoutine = LoginRoutine(
      self.gameplayClient, ip, gameplayPort,
      self.lobbyClient, lobbyPort,
      self.spectateClient, spectatePort)
    self:setState(states.LOGIN)
  end
end

function NetClient:logout()
  self.lobbyClient:sendRequest(ClientMessages.logout())
  -- we want to give the message a chance to actually be sent to the network before we free the socket
  -- otherwise the socket might get cleared before that and the server will only disconnect the player after a delay (which means they still get shown in lobby for ~10s)
  -- it would be more reliable to only actually reset the socket after a server confirmation so there is no delay (however small)
  --  but then we'd have the same problem on the server (how does the server know the client received logout?) so it's actually not nearly as simple as this
  love.timer.sleep(0.05)
  self:disconnect(true)
end

---@param voluntary boolean if the disconnect happened through player intent or not
function NetClient:disconnect(voluntary)
  self.room = nil
  -- Reset all three sockets — full session teardown.
  for _, client in ipairs(self.clients) do client:resetNetwork() end
  self:setState(states.OFFLINE)
  resetLobbyData(self)
  GAME.localPlayer:disconnectSubscriber(GAME.netClient)
  -- this is because the online updates are currently subscribed to the player itself
  -- that should probably get changed because while mildly convenient it is unexpected for the interaction
  GAME.localPlayer:disconnectSubscriber(GAME.localPlayer)
  -- Clear the "already hooked" flag so registerPlayerUpdates re-attaches signals on
  -- the next connection. Without this, after a disconnect+reconnect, ready/loaded
  -- changes fire locally but never reach the server: the subscriptions are gone but
  -- the flag still marks the player as hooked, so registration skips the re-attach.
  GAME.localPlayer._netClientSettingsHooked = nil
  self:emitSignal("clientDisconnected", voluntary)
end

function NetClient:update(dt)
  if self.state == states.OFFLINE then
    return
  end

  -- Drain the simulated-lag queues (PA_NETWORK_LAG_MS). When delayedProcessing
  -- is on, send() pushes to sendNetworkQueue and processIncomingMessages
  -- pushes to receiveNetworkQueue with a delay; updateNetwork is what actually
  -- flushes them once their delay has elapsed. Without this call, sends never
  -- reach the socket and the 5s Response timeout fires on the first H message.
  dt = dt or 0
  for _, client in ipairs(self.clients) do client:updateNetwork(dt) end

  if self.state == states.LOGIN then
    local done, result = self.loginRoutine:progress()
    if not done then
      self.loginState = result
    else
      if result.loggedIn then
        self:setState(states.ONLINE)
        self.loginState = result.message
        self.loginTime = love.timer.getTime()
        local t = os.time()
        self.serverTimeDelta = os.difftime(t, result.serverTime)
        local date = os.date("*t")
        if date.isdst then
          self.serverTimeDelta = self.serverTimeDelta - 3600
        end
      else
        self.loginState = result.message
        self:setState(states.OFFLINE)
      end
      self:emitSignal("loginFinished", result)
    end
  end

  -- Process incoming on all three sockets.
  --   Gameplay drop  = full disconnect (your critical channel).
  --   Spectate drop  = silent reset; opponent boards freeze visually but
  --                    your own gameplay continues uninterrupted.
  --   Lobby drop     = silent reset; JSON falls back to gameplay temporarily.
  if not self.gameplayClient:processIncomingMessages() then
    self:disconnect(false)
    return
  end
  _processSideSocket(self, self.spectateClient, "Spectate")
  _processSideSocket(self, self.lobbyClient, "Lobby")

  if self.state == states.ONLINE then
    for _, listener in pairs(self.lobbyListeners) do
      listener:listen()
    end
    _clearMatchInputState(self)
    if self.pendingResponses.leaderboardUpdate then
      local status, value = self.pendingResponses.leaderboardUpdate:tryGetValue()
      if status == "timeout" then
        GAME.theme:playCancelSfx()
        self.pendingResponses.leaderboardUpdate = nil
      elseif status == "received" then
        self.leaderboard = value.leaderboard_report
        self:emitSignal("leaderboardUpdate", self.leaderboard)
        self.pendingResponses.leaderboardUpdate = nil
      end
    end
    if self.pendingResponses.spectateResponse then
      local status, value = self.pendingResponses.spectateResponse:tryGetValue()
      if status == "timeout" then
        GAME.theme:playCancelSfx()
        self.pendingResponses.spectateResponse = nil
      elseif status == "received" then
        self.pendingResponses.spectateResponse = nil
        spectate2pVsOnlineMatch(self, value)
      end
    end
  elseif self.state == states.ROOM then
    for _, listener in pairs(self.roomListeners) do
      listener:listen()
    end
  elseif self.state == states.INGAME then
    processInputMessages(self)
    processGarbageEvents(self)
    processDeathEvents(self)

    for _, listener in pairs(self.matchListeners) do
      listener:listen()
    end
  end
end

---@param state NetClientStates
function NetClient:setState(state)
  logger.debug("Setting netclient state to " .. state)
  -- Whenever we leave INGAME (cleanly, abort, disconnect, anything), drop the
  -- budgeted defer queues. Slot indices are per-match; messages held over from
  -- a previous match would apply to stacks they weren't meant for — including
  -- potentially the local stack if slot mappings overlap. Belt-and-suspenders
  -- against every transition path; the per-handler clears stay as defense-in-
  -- depth at the explicit match-end / spectate sites.
  if self.state == states.INGAME and state ~= states.INGAME then
    _clearMatchInputState(self)
  end
  self.state = state
end

return NetClient