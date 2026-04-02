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
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local LevelData = require("common.data.LevelData")
local GameModes = require("common.data.GameModes")

---@enum NetClientStates
local states = { OFFLINE = 1, LOGIN = 2, ONLINE = 3, ROOM = 4, INGAME = 5 }

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

  -- if a player we challenged is not in lobby data or is in a room, they cannot accept our challenge anymore
  for publicId, player in pairs(self.lobbyDataV2.outgoingChallenges) do
    if not self.lobbyDataV2.players[publicId] then
      self.lobbyDataV2.outgoingChallenges[publicId] = nil
    elseif self.lobbyDataV2.players[publicId].roomNumber then
      self.lobbyDataV2.outgoingChallenges[publicId] = nil
    end
  end

  -- if a player that challenged us is not in lobby data or is in a room, we cannot accept their challenge anymore
  for publicId, player in pairs(self.lobbyDataV2.incomingChallenges) do
    if not self.lobbyDataV2.players[publicId] then
      self.lobbyDataV2.incomingChallenges[publicId] = nil
    elseif self.lobbyDataV2.players[publicId].roomNumber then
      self.lobbyDataV2.incomingChallenges[publicId] = nil
    end
  end

  self.lobbyDataV2.rooms = lobbyStateV2.rooms

  self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
end

---@param room BattleRoom
local function getSceneFromRoom(room)
  -- this is so hacky oh my god
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

-- starts a 2p vs online match
local function start2pVsOnlineMatch(self, createRoomMessage)
  resetLobbyData(self)
  GAME.battleRoom = BattleRoom.createFromServerMessage(createRoomMessage)
  self.room = GAME.battleRoom
  love.window.requestAttention()
  SoundController:playSfx(themes[config.theme].sounds.notification)
  GAME.navigationStack:push(getSceneFromRoom(self.room))
  self.state = states.ROOM
end

local function processSpectatorListMessage(self, message)
  if self.room then
    self.room:setSpectatorList(message.spectators)
  end
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
    roomPlayer:setWinCount(messagePlayer.winCount)

    if messagePlayer.ratingInfo then
      local ratingInfo = messagePlayer.ratingInfo
      roomPlayer:setRating(ratingInfo.placement_match_progress or ratingInfo.new)
      roomPlayer:setLeague(ratingInfo.league)
    end
  end

  self.room:updateWinrates()
  self.room:updateExpectedWinrates()
  self:setState(states.ROOM)
end

local function processLeaveRoomMessage(self, message)
  if self.room then
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
  local messages = self.tcpClient.receivedMessageQueue:pop_all_with(NetworkProtocol.serverMessageTypes.opponentInput.prefix, NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix)
  if self.room and self.room.match then
    for _, msg in ipairs(messages) do
      for type, data in pairs(msg) do
        self.room.match:receiveInput(type, data)
      end
    end
  end
end

---@param self NetClient
local function processChallengeUpdate(self, challengeUpdateMessage)
  if challengeUpdateMessage.challengeUpdate then
    local challengeUpdate = challengeUpdateMessage.challengeUpdate
    local challenges = self.lobbyDataV2.incomingChallenges[challengeUpdate.senderId] or {}
    challenges[challengeUpdate.gameModeId] = challengeUpdate.challengeActive
    self.lobbyDataV2.incomingChallenges[challengeUpdate.senderId] = challenges
    self:emitSignal("lobbyStateV2Update", self.lobbyDataV2)
  end
end

-- starts to spectate a 2p vs online match
local function spectate2pVsOnlineMatch(self, spectateRequestGrantedMessage)
  resetLobbyData(self)
  GAME.battleRoom = BattleRoom.createFromServerMessage(spectateRequestGrantedMessage)
  self.room = GAME.battleRoom
  if GAME.battleRoom.match then
    self.state = states.INGAME
    local vsScene = GameBase({match = GAME.battleRoom.match})
    vsScene:load()
    local catchUp = GameCatchUp(vsScene)
    -- need to push character select, otherwise the pop on match end will return to lobby
    -- directly add to the stack so it isn't getting displayed
    GAME.navigationStack.scenes[#GAME.navigationStack.scenes+1] = getSceneFromRoom(self.room)
    GAME.navigationStack:push(catchUp)
  else
    self.state = states.ROOM
    GAME.navigationStack:push(getSceneFromRoom(self.room))
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
    transition = MessageTransition(love.timer.getTime(), 5, "Game aborted by " .. (gameAbortMessage.source or "unknown"), false)
    GAME.navigationStack:pop(transition)
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
    challengeUpdate = messageListeners.challengeUpdate,
  }

  -- all listeners running while in a room but not in a match
  self.roomListeners = {
    ranked_match_approved = messageListeners.ranked_match_approved,
    leave_room = messageListeners.leave_room,
    match_start = messageListeners.match_start,
    spectators = messageListeners.spectators,
    gameResult = messageListeners.gameResult,
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
  end
end

function NetClient:reportLocalGameResult(winners)
  if #winners == 2 then
    -- we need to translate the result for the server to understand it
    -- two winners means a draw which the server thinks of as 0
    self.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(0))
  elseif #winners == 1 then
    self.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(winners[1].playerNumber))
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

---@param gameMode GameMode
function NetClient:requestRoom(gameMode)
  if self:isConnected() then
    self.tcpClient:sendRequest(ClientMessages.sendRoomRequest(gameMode))
  end
end

function NetClient:sendMatchAbort()
  if self:isConnected() then
    self.tcpClient:sendRequest(ClientMessages.sendMatchAbort())
    self:setState(states.ROOM)
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
  if not self:isConnected() then
    self.tcpClient:connectToServer(server, port)
  end
  self.tcpClient:sendRequest(ClientMessages.sendErrorReport(errorData))
  self.tcpClient:resetNetwork()
  self:setState(states.OFFLINE)
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