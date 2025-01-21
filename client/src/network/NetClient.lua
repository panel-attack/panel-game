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

---@enum NetClientStates
local states = { OFFLINE = 1, LOGIN = 2, ONLINE = 3, ROOM = 4, INGAME = 5 }

-- Most functions of NetClient are private as they only should get triggered via incoming server messages
--  that get automatically processed via NetClient:update

local function resetLobbyData(self)
  self.lobbyData = {
    players = {},
    unpairedPlayers = {},
    willingPlayers = {},
    spectatableRooms = {},
    sentRequests = {}
  }
end

local function updateLobbyState(self, lobbyState)
  if lobbyState.players then
    self.lobbyData.players = lobbyState.players
  end

  if lobbyState.unpaired then
    self.lobbyData.unpairedPlayers = lobbyState.unpaired
    -- players who leave the unpaired list no longer have standing invitations to us.\
    -- we also no longer have a standing invitation to them, so we'll remove them from sentRequests
    local newWillingPlayers = {}
    local newSentRequests = {}
    for _, player in ipairs(self.lobbyData.unpairedPlayers) do
      newWillingPlayers[player] = self.lobbyData.willingPlayers[player]
      newSentRequests[player] = self.lobbyData.sentRequests[player]
    end
    self.lobbyData.willingPlayers = newWillingPlayers
    self.lobbyData.sentRequests = newSentRequests
  end

  if lobbyState.spectatable then
    self.lobbyData.spectatableRooms = lobbyState.spectatable
  end

  self:emitSignal("lobbyStateUpdate", self.lobbyData)
end

local function getSceneByGameMode(gameMode)
  -- this is so hacky oh my god
  if gameMode.richPresenceLabel == "2p versus" then
    return CharacterSelect2p()
  elseif gameMode.richPresenceLabel == "Endless" then
    return require("client.src.scenes.EndlessMenu")()
  elseif gameMode.richPresenceLabel == "Time Attack" then
    return require("client.src.scenes.TimeAttackMenu")()
  elseif gameMode.richPresenceLabel == "1p vs self" then
    return require("client.src.scenes.CharacterSelectVsSelf")()
  end
end

-- starts a 2p vs online match
local function start2pVsOnlineMatch(self, createRoomMessage)
  resetLobbyData(self)
  GAME.battleRoom = BattleRoom.createFromServerMessage(createRoomMessage)
  self.room = GAME.battleRoom
  love.window.requestAttention()
  SoundController:playSfx(themes[config.theme].sounds.notification)
  GAME.navigationStack:push(getSceneByGameMode(self.room.mode))
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
      transition = MessageTransition(love.timer.getTime(), 5, message.reason or "", false)
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
local function processMatchStartMessage(self, message)
  if not self.room then
    return
  end

  for _, playerSettings in ipairs(message.playerSettings) do
    -- contains level, characterId, panelId
    for _, player in ipairs(self.room.players) do
      if playerSettings.playerNumber == player.playerNumber then
        -- verify that settings on server and local match to prevent desync / crash
        if playerSettings.level ~= player.settings.level then
          player:setLevel(playerSettings.level)
        end
        if playerSettings.levelData and LevelData.validate(playerSettings.levelData) then
          playerSettings.levelData = setmetatable(playerSettings.levelData, LevelData)
          player:setLevelData(playerSettings.levelData)
        end

        if playerSettings.inputMethod ~= player.settings.inputMethod then
          -- since only one player can claim touch, touch is unclaimed every time we return to character select
          -- this also means they will send controller as their input method until they ready up
          -- if the remote touch player readies up AFTER the local client, we never get informed about the change in input method
          -- besides for the match start message itself
          -- likewise if the local player readies up with touch and then unreadies their inputMethod will flip back to controller so we even have to overwrite the local player setting
          -- so it's very important to set this here
          player:setInputMethod(playerSettings.inputMethod)
        end

        if player.isLocal then
          if not player.inputConfiguration then
            if player.settings.inputMethod == "touch" then
              player:restrictInputs(GAME.input.mouse)
            else
              if player.lastUsedInputConfiguration.x then
                -- there is no configuration and the last one is a touch configuration
                -- there is no way to know which input configuration the player wanted to use in this scenario so throw an error
                error("Player's input configuration does not match input method " .. player.settings.inputMethod .. " sent by server.")
              else
                player:restrictInputs(player.lastUsedInputConfiguration)
              end
            end
            -- fallback in case the player lost their input config while the server sent the message
          end
        end
        -- generally I don't think it's a good idea to try and rematch the other diverging settings here
        -- everyone is loaded and ready which can only happen after character/panel data was already exchanged
        -- if they diverge it's because the chosen mod is missing on the other client
        -- generally I think server should only send physics relevant data with match_start
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
  self.room:startMatch(message.stageId, message.seed, message.replay)
  self:setState(states.INGAME)
end

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
        logger.trace("Processing: " .. type .. " with data:" .. data)
        if type == NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix then
          self.room.match.stacks[1]:receiveConfirmedInput(data)
        elseif type == NetworkProtocol.serverMessageTypes.opponentInput.prefix then
          self.room.match.stacks[2]:receiveConfirmedInput(data)
        end
      end
    end
  end
end

local function processGameRequest(self, gameRequestMessage)
  if gameRequestMessage.game_request then
    self.lobbyData.willingPlayers[gameRequestMessage.game_request.sender] = true
    love.window.requestAttention()
    SoundController:playSfx(themes[config.theme].sounds.notification)
    -- this might be moot if the server sends a lobby update to everyone after receiving the challenge
    self:emitSignal("lobbyStateUpdate", self.lobbyData)
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
    local catchUp = GameCatchUp(vsScene)
    -- need to push character select, otherwise the pop on match end will return to lobby
    -- directly add to the stack so it isn't getting displayed
    GAME.navigationStack.scenes[#GAME.navigationStack.scenes+1] = getSceneByGameMode(self.room.mode)
    GAME.navigationStack:push(catchUp)
  else
    self.state = states.ROOM
    GAME.navigationStack:push(getSceneByGameMode(self.room.mode))
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
  messageListeners.players = createListener(self, "unpaired", updateLobbyState)
  messageListeners.game_request = createListener(self, "game_request", processGameRequest)
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
---@field lobbyData table
---@overload fun(): NetClient
local NetClient = class(function(self)
  self.tcpClient = TcpClient()
  self.leaderboard = nil
  self.pendingResponses = {}
  self.state = states.OFFLINE

  resetLobbyData(self)

  local messageListeners = createListeners(self)

  -- all listeners running while online but not in a room/match
  self.lobbyListeners = {
    players = messageListeners.players,
    create_room = messageListeners.create_room,
    game_request = messageListeners.game_request,
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
  self:createSignal("leaderboardUpdate")
  -- only fires for unintended disconnects
  self:createSignal("disconnect")
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

function NetClient:requestLeaderboard()
  if not self.pendingResponses.leaderboardUpdate then
    self.pendingResponses.leaderboardUpdate = self.tcpClient:sendRequest(ClientMessages.requestLeaderboard())
  end
end

function NetClient:challengePlayer(name)
  if not self.lobbyData.sentRequests[name] then
    self.tcpClient:sendRequest(ClientMessages.challengePlayer(config.name, name))
    self.lobbyData.sentRequests[name] = true
    self:emitSignal("lobbyStateUpdate", self.lobbyData)
  end
end

function NetClient:requestSpectate(roomNumber)
  if not self.pendingResponses.spectateResponse then
    self.pendingResponses.spectateResponse = self.tcpClient:sendRequest(ClientMessages.requestSpectate(config.name, roomNumber))
  end
end

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
      player:connectSignal("stageIdChanged", player, sendPlayerSettings)
      player:connectSignal("panelIdChanged", player, sendPlayerSettings)
      player:connectSignal("wantsRankedChanged", player, sendPlayerSettings)
      player:connectSignal("wantsReadyChanged", player, sendPlayerSettings)
      player:connectSignal("difficultyChanged", player, sendPlayerSettings)
      player:connectSignal("startingSpeedChanged", player, sendPlayerSettings)
      player:connectSignal("levelChanged", player, sendPlayerSettings)
      player:connectSignal("colorCountChanged", player, sendPlayerSettings)
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
  love.timer.sleep(0.001)
  self.tcpClient:resetNetwork()
  self:setState(states.OFFLINE)
  resetLobbyData(self)
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
      else
        self.loginState = result.message
        self:setState(states.OFFLINE)
      end
      self:emitSignal("loginFinished", result)
    end
  end

  if not self.tcpClient:processIncomingMessages() then
    self:setState(states.OFFLINE)
    self.room = nil
    self.tcpClient:resetNetwork()
    resetLobbyData(self)
    self:emitSignal("disconnect")
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