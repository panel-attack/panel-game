local class = require("common.lib.class")
local TcpClient = require("client.src.network.TcpClient")
local MessageListener = require("client.src.network.MessageListener")
local ServerMessages = require("client.src.network.ServerMessages")
local ClientMessages = require("common.network.ClientProtocol")
local tableUtils = require("common.lib.tableUtils")
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
  -- this is so hacky oh my god
  if room.mode.name == "VS" or room.mode.name == "2p_timeattack" then
    return CharacterSelect2p({battleRoom = room})
  elseif room.mode.name == "endless" then
    return require("client.src.scenes.EndlessMenu")({battleRoom = room})
  elseif room.mode.name == "timeattack" then
    return require("client.src.scenes.TimeAttackMenu")({battleRoom = room})
  elseif room.mode.name == "vsSelf" then
    return require("client.src.scenes.CharacterSelectVsSelf")({battleRoom = room})
  elseif room.mode.name == "team_vs_all" or room.mode.name == "team_vs_shared"
      or room.mode.name == "three_player_vs_all" or room.mode.name == "three_player_vs_shared"
      or room.mode.name == "three_player_vs_all_2v1" or room.mode.name == "three_player_vs_shared_2v1"
      or room.mode.name == "four_player_1v3_all" or room.mode.name == "four_player_1v3_shared"
      or room.mode.name == "four_player_3v1_all" or room.mode.name == "four_player_3v1_shared"
      or room.mode.name == "3p_ffa" or room.mode.name == "4p_ffa" or room.mode.name == "5p_ffa" or room.mode.name == "7p_ffa"
      or room.mode.name == "3p_ffa_shared" or room.mode.name == "4p_ffa_shared" or room.mode.name == "5p_ffa_shared" or room.mode.name == "7p_ffa_shared"
      or room.mode.name == "open_ffa" or room.mode.name == "open_ffa_shared"
      or room.mode.name == "five_player_1v4_all" or room.mode.name == "five_player_1v4_shared"
      or room.mode.name == "five_player_4v1_all" or room.mode.name == "five_player_4v1_shared"
      or room.mode.name == "five_player_2v3_all" or room.mode.name == "five_player_2v3_shared"
      or room.mode.name == "five_player_3v2_all" or room.mode.name == "five_player_3v2_shared" then
    return CharacterSelect2p({battleRoom = room})
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

  -- Trace capture: open the match-scope file. Pre-match ambient context
  -- (lobby chatter, the addToRoom message itself which sits in the
  -- pre-match ring) drains into _match.jsonl so the file starts with
  -- the lead-up to this room-join. pcall'd so a TraceWriter regression
  -- can't break the room-join flow.
  pcall(function()
    local roomNumber = self.room and self.room.roomNumber or 0
    TraceWriter.beginMatch(roomNumber, os.time())
  end)
  love.window.requestAttention()
  SoundController:playSfx(themes[config.theme].sounds.notification)

  -- See isRoomReadyForWaitingRoom for the per-mode transition rule.
  -- Rejoin exception: if the room has held slots, the existing members are
  -- already in character select (they didn't navigate back when a peer left).
  -- A rejoiner needs to land in the same scene rather than getting stuck in
  -- lobby with no one to play against.
  local playerCount = #self.room.players
  local maxPlayers = self.room.mode.playerCount or self.room.mode.maxPlayers or 2
  local hasHeldSlots = self.room.heldSlots and #self.room.heldSlots > 0
  if not isRoomReadyForWaitingRoom(self.room) and not hasHeldSlots then
    -- Stay in lobby - room will show in lobby list with open slots
    logger.info("Joined partial room " .. (self.room.roomNumber or "?") .. " (" .. playerCount .. "/" .. maxPlayers .. " players). Staying in lobby.")
    self.state = states.ONLINE

    -- Update local lobby data with the new room so UI can display it
    if self.lobbyDataV2 and self.room.roomNumber then
      local roomNumber = self.room.roomNumber
      local playerIds = {}
      for i, player in ipairs(self.room.players) do
        playerIds[i] = player.publicId
      end
      -- Calculate open slots
      local openSlots = {}
      for slot = playerCount + 1, maxPlayers do
        openSlots[#openSlots + 1] = slot
      end
      self.lobbyDataV2.rooms[roomNumber] = {
        roomNumber = roomNumber,
        players = playerIds,
        spectators = {},
        state = "waiting",
        wins = {},
        gameModeId = self.room.mode.name,
        maxPlayers = maxPlayers,
        openSlots = openSlots,
        -- Held slots only get populated after someone leaves a fixed-roster room;
        -- this is the fresh-join path so there's nothing held yet. Next
        -- lobbyStateV2 from the server is authoritative.
        heldSlots = {},
      }
      -- Update local player's room assignment
      local localId = GAME.localPlayer.publicId
      if self.lobbyDataV2.players[localId] then
        self.lobbyDataV2.players[localId].roomNumber = roomNumber
      end
      -- Emit signal to refresh lobby UI
      self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
    end
    return
  end

  -- Min players reached (or fixed-roster room filled) - navigate to game scene.
  -- We are leaving lobby context now, so clear stale lobby/challenge data.
  resetLobbyData(self)
  local roomScene = getSceneFromRoom(self.room)
  if roomScene then
    GAME.navigationStack:push(roomScene)
  else
    logger.warn("No room scene available for mode '" .. tostring(self.room.mode and self.room.mode.name) .. "'. Staying in current scene.")
  end
  self.state = states.ROOM
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
  self.tcpClient:dropOldInputMessages()

  if not self.room then
    return
  end

  for _, roomPlayer in ipairs(self.room.players) do
    local messagePlayer = message.gameResult[roomPlayer.playerNumber]
    if messagePlayer then
      roomPlayer:setWinCount(messagePlayer.winCount)

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
  if self.room then
    local leavingRoomNumber = self.room.roomNumber
    local transition
    if self.room.match then
      -- we're ending the game via an abort so we don't want to enter the standard onMatchEnd callback
      self.room.match:disconnectSignal("matchEnded", self.room)
      -- instead we actively abort the match ourselves
      self.room.match:abort()
      self.room.match:deinit()

      if message.reason then
        -- the server sends a reason for leaveRoom only if a player (not a spectator) in the room leaves/crashes/disconnects
        -- the other player and spectators should be informed why the room is being closed
        transition = MessageTransition(love.timer.getTime(), 5, message.reason, false)
      end
    end

    -- and then shutdown the room
    self.room:shutdown()
    self.room = nil
    GAME.battleRoom = nil

    -- Trace capture: close match-scope file. Force-flushes any pending
    -- lines. pcall'd at the call site so a TraceWriter bug can't disturb
    -- the room-leave path.
    pcall(function() TraceWriter.endMatch() end)

    -- Immediately clear the local player's room assignment so room-invite UI
    -- cannot linger while waiting for the next lobbyStateV2 broadcast. Do NOT
    -- delete the room itself from lobbyDataV2 — open rooms can outlive a single
    -- leaver, and removing them here makes the lobby visually drop a room that
    -- still has players in it (server's next broadcast is authoritative on
    -- room presence). leavingRoomNumber is kept as a local-only hint and is
    -- intentionally unused now.
    if self.lobbyDataV2 then
      local localId = GAME.localPlayer and GAME.localPlayer.publicId
      if localId and self.lobbyDataV2.players[localId] then
        self.lobbyDataV2.players[localId].roomNumber = nil
      end
      self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
    end

    self.state = states.ONLINE
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

  self.tcpClient:dropOldInputMessages()
  local match = self.room:startMatch(message.replay)
  self:setState(states.INGAME)
  if match.supportsPause and match:hasLocalPlayer() then
    match:connectSignal("pauseChanged", self, self.sendPauseToggle)
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

    -- Navigate to the waiting room (CharacterSelect) once the room is ready,
    -- per the per-mode rule in isRoomReadyForWaitingRoom. Skip for clients
    -- already in the room scene (avoid duplicate push).
    local alreadyInRoom = self.state == states.ROOM or self.state == states.INGAME
    if isRoomReadyForWaitingRoom(self.room) and not alreadyInRoom then
      logger.info("Room " .. (self.room.roomNumber or "?") .. " ready for waiting room (" .. #self.room.players .. " player(s)). Navigating to game scene.")
      local roomScene = getSceneFromRoom(self.room)
      if roomScene then
        GAME.navigationStack:push(roomScene)
        self.state = states.ROOM
      else
        logger.warn("No room scene available for mode '" .. tostring(self.room.mode and self.room.mode.name) .. "'.")
      end
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

local function processInputMessages(self)
  -- Unified input message: every player's relayed input comes through the
  -- same "I" prefix; the sender is identified by playerNumber inside the
  -- JSON body. TcpClient.queueMessage already decoded the body to
  -- {playerNumber, input} when it pushed onto the queue.
  local inputPrefix = NetworkProtocol.serverMessageTypes.input.prefix
  local messages = self.tcpClient.receivedMessageQueue:pop_all_with(inputPrefix)
  if self.room and self.room.match then
    for _, msg in ipairs(messages) do
      local body = msg[inputPrefix]
      if body then
        self.room.match:receiveInput(body.playerNumber, body.input)
      end
    end
  end
end

---@param self NetClient
local function processGarbageEvents(self)
  local messages = self.tcpClient.receivedMessageQueue:pop_all_with(
    NetworkProtocol.serverMessageTypes.garbageEvent.prefix)
  for _, msg in ipairs(messages) do
    local body = msg[NetworkProtocol.serverMessageTypes.garbageEvent.prefix]
    if self.room and self.room.match then
      self.room.match:applyGarbageEvent(body)
    end
  end
end

---@param self NetClient
local function processDeathEvents(self)
  local messages = self.tcpClient.receivedMessageQueue:pop_all_with(
    NetworkProtocol.serverMessageTypes.deathEvent.prefix)
  for _, msg in ipairs(messages) do
    local body = msg[NetworkProtocol.serverMessageTypes.deathEvent.prefix]
    if self.room and self.room.match then
      self.room.match:applyDeathEvent(body)
    end
  end
end

---@param self NetClient
local function processKOArbitrations(self)
  local messages = self.tcpClient.receivedMessageQueue:pop_all_with(
    NetworkProtocol.serverMessageTypes.koArbitration.prefix)
  if self.room and self.room.match then
    for _, msg in ipairs(messages) do
      local body = msg[NetworkProtocol.serverMessageTypes.koArbitration.prefix]
      self.room.match:applyKOArbitration(body)
    end
  end
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
    self.tcpClient:dropOldInputMessages()
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

  return messageListeners
end

---@class NetClient : Signal
---@field tcpClient TcpClient
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
  self.tcpClient = TcpClient()
  self.leaderboard = nil
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
end)

NetClient.STATES = states

function NetClient:leaveRoom()
  if self:isConnected() and self.room then
    self.tcpClient:dropOldInputMessages()
    self.tcpClient:sendRequest(ClientMessages.leaveRoom())

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
  if #winners == 0 then
    return  -- aborted match, handled separately via sendMatchAbort
  end

  local gameMode = self.room and self.room.mode
  local isTeamGame = gameMode and gameMode.teamCount

  if isTeamGame then
    local totalPlayers = gameMode.playerCount or #self.room.players
    if #winners >= totalPlayers then
      -- all players tied (everyone died simultaneously)
      self.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(0))
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
              local localTeamIndex = TeamUtils.getPlayerTeamIndex(match.engine.teams, i)
              if localTeamIndex == winningTeam.id then
                localTeamWon = true
              end
              break
            end
          end
        end
      end
      self.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(localTeamWon and 1 or 2))
    end
  else
    -- non-team: report winner's player number, or 0 for any tie
    if #winners >= 2 then
      self.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(0))
    else
      self.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(winners[1].playerNumber))
    end
  end
end

function NetClient:sendTauntUp(index)
  if self:isConnected() then
    self.tcpClient:sendRequest(ClientMessages.sendTaunt("up", index))
  end
end

function NetClient:sendTauntDown(index)
  if self:isConnected() then
    self.tcpClient:sendRequest(ClientMessages.sendTaunt("down", index))
  end
end

function NetClient:sendInput(input)
  if self:isConnected() then
    local message = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.clientMessageTypes.playerInput.prefix, input)
    self.tcpClient:send(message)
  end
end

---Loose-sync: send a GarbageEvent from the local sim. body is JSON-encoded inline
---(no Request wrapper — these are fire-and-forget like inputs).
---@param body table parsed event payload
function NetClient:sendGarbageEvent(body)
  if self:isConnected() then
    local message = NetworkProtocol.markedMessageForTypeAndBody(
      NetworkProtocol.clientMessageTypes.garbageEvent.prefix, json.encode(body))
    self.tcpClient:send(message)
  end
end

---Loose-sync: send a DeathEvent from the local sim.
---@param body table parsed event payload
function NetClient:sendDeathEvent(body)
  if self:isConnected() then
    local message = NetworkProtocol.markedMessageForTypeAndBody(
      NetworkProtocol.clientMessageTypes.deathEvent.prefix, json.encode(body))
    self.tcpClient:send(message)
  end
end

---@param clientMatch ClientMatch
function NetClient:sendPauseToggle(clientMatch)
  if self:isConnected() and self.room and self.room.roomNumber then
    self.tcpClient:sendRequest(ClientMessages.sendPauseToggle(self.room.roomNumber, clientMatch.isPaused))
  end
end

---@param gameModeId GameModeID?
function NetClient:requestLeaderboard(gameModeId)
  if not self.pendingResponses.leaderboardUpdate then
    gameModeId = gameModeId or GameModes.IDs.TWO_PLAYER_VS
    self.pendingResponses.leaderboardUpdate = self.tcpClient:sendRequest(ClientMessages.requestLeaderboard(gameModeId))
  end
end

---@param opponentId PublicPlayerID
---@param gameModeId GameModeID
function NetClient:challengePlayerById(opponentId, gameModeId)
  self.lobbyDataV2.outgoingChallenges[opponentId] = self.lobbyDataV2.outgoingChallenges[opponentId] or {}
  self.tcpClient:sendRequest(ClientMessages.updateChallengeStatus(GAME.localPlayer.publicId, opponentId, gameModeId, true))
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
  self.tcpClient:sendRequest(ClientMessages.updateChallengeStatus(GAME.localPlayer.publicId, opponentId, gameModeId, true, roomNumber, slotNumber))
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
  self.tcpClient:sendRequest(ClientMessages.updateChallengeStatus(GAME.localPlayer.publicId, opponentId, gameModeId, false, roomNumber, slotNumber))
  self.lobbyDataV2.outgoingChallenges[opponentId][inviteKey] = false
  self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
end

function NetClient:withdrawChallengeForId(opponentId, gameModeId)
  if self.lobbyDataV2.outgoingChallenges[opponentId] then
    self.tcpClient:sendRequest(ClientMessages.updateChallengeStatus(GAME.localPlayer.publicId, opponentId, gameModeId, false))
    self.lobbyDataV2.outgoingChallenges[opponentId] = self.lobbyDataV2.outgoingChallenges[opponentId] or {}
    self.lobbyDataV2.outgoingChallenges[opponentId][gameModeId] = false
    self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
  end
end

function NetClient:requestSpectate(roomNumber)
  if not self.pendingResponses.spectateResponse then
    self.pendingResponses.spectateResponse = self.tcpClient:sendRequest(ClientMessages.requestSpectate(config.name, roomNumber))
  end
end

---@param roomNumber integer
---@param slotNumber integer
function NetClient:requestJoinRoom(roomNumber, slotNumber)
  if self:isConnected() then
    logger.info("Sending joinRoomRequest for room " .. tostring(roomNumber) .. " slot " .. tostring(slotNumber))
    self.tcpClient:sendRequest(ClientMessages.requestJoinRoom(roomNumber, slotNumber))
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

    self.tcpClient:sendRequest(ClientMessages.sendRoomRequest(gameMode, latencyTolerance, openRoom))
  end
end

function NetClient:sendMatchAbort()
  if self:isConnected() then
    self.tcpClient:sendRequest(ClientMessages.sendMatchAbort())
    self:setState(states.ROOM)
  end
end

---@param frame integer game_over_clock frame at which the local stack died
function NetClient:sendStackEliminated(frame)
  if self:isConnected() then
    self.tcpClient:sendRequest(ClientMessages.sendStackEliminated(frame))
  end
end

function sendPlayerSettings(player)
  GAME.netClient.tcpClient:sendRequest(ClientMessages.sendPlayerSettings(ServerMessages.toServerMenuState(player)))
end

function NetClient:sendPlayerSettings(player)
  self.tcpClient:sendRequest(ClientMessages.sendPlayerSettings(ServerMessages.toServerMenuState(player)))
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
  return self.tcpClient:isConnected()
end

function NetClient:login(ip, port)
  if not self:isConnected() then
    self.loginRoutine = LoginRoutine(self.tcpClient, ip, port)
    self:setState(states.LOGIN)
  end
end

function NetClient:logout()
  self.tcpClient:sendRequest(ClientMessages.logout())
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
  self.tcpClient:resetNetwork()
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

function NetClient:update()
  if self.state == states.OFFLINE then
    return
  end

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

  if not self.tcpClient:processIncomingMessages() then
    self:disconnect(false)
    return
  end

  if self.state == states.ONLINE then
    for _, listener in pairs(self.lobbyListeners) do
      listener:listen()
    end
    self.tcpClient:dropOldInputMessages()
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
    processKOArbitrations(self)

    for _, listener in pairs(self.matchListeners) do
      listener:listen()
    end
  end
end

---@param state NetClientStates
function NetClient:setState(state)
  logger.debug("Setting netclient state to " .. state)
  self.state = state
end

return NetClient