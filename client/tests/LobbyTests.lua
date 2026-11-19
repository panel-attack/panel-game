local Lobby = require("client.src.scenes.Lobby")
local ConnectionWarning = require("client.src.ui.ConnectionWarning")

---@param publicIds PublicPlayerID[]
---@return PersonalizedLobbyDataV2
local function lobbyDataWith(publicIds)
  local players = {}
  for _, publicId in ipairs(publicIds) do
    players[publicId] = {publicId = publicId, name = "Player" .. publicId, state = "lobby", ratings = {}}
  end
  return {players = players, outgoingChallenges = {}, incomingChallenges = {}, rooms = {}}
end

---@param lobby LobbyScene
---@param lobbyData PersonalizedLobbyDataV2
local function updateLobby(lobby, lobbyData)
  GAME.netClient.lobbyDataV2 = lobbyData
  lobby:onLobbyStateUpdate(lobbyData)
end

---@param lobby LobbyScene
---@param publicId PublicPlayerID
---@return Button?
local function playerButton(lobby, publicId)
  for _, child in ipairs(lobby.lobbyMenu.children) do
    if child.lobbyType == "player" and child.player.publicId == publicId then
      ---@cast child Button
      return child
    end
  end
end

---@param lobby LobbyScene
---@return ConnectionWarning?
local function challengeWarning(lobby)
  for _, child in ipairs(lobby.uiRoot.children) do
    if child.TYPE == ConnectionWarning.TYPE then
      ---@cast child ConnectionWarning
      return child
    end
  end
end

local function testTheChallengeWarningFollowsTheMenuWhenThePlayerMovesUp()
  local savedLobbyData = GAME.netClient.lobbyDataV2
  local lobby = Lobby({})
  updateLobby(lobby, lobbyDataWith({9001, 9002, 9003}))
  local button = playerButton(lobby, 9003)
  assert(button, "the lobby should list player 9003")
  lobby.lobbyMenu:select(button)
  lobby:openPlayerSubMenu(9003, button)
  lobby.uiRoot:layOut()
  local _, menuYBefore = lobby.playerSubMenu:getScreenPos()

  updateLobby(lobby, lobbyDataWith({9002, 9003}))
  lobby.uiRoot:layOut()

  local warning = challengeWarning(lobby)
  assert(warning, "the challenge menu should still have its connection warning")
  local movedButton = playerButton(lobby, 9003)
  assert(movedButton, "the lobby should still list player 9003")
  local _, buttonY = movedButton:getScreenPos()
  local _, menuY = lobby.playerSubMenu:getScreenPos()
  local _, warningY = warning:getScreenPos()
  assert(menuY < menuYBefore, "the challenge menu should move up a row, from " .. menuYBefore .. " but is at " .. menuY)
  assert(menuY == buttonY, "the challenge menu should stay level with the player's button at " .. buttonY .. " but is at " .. menuY)
  assert(warningY == menuY, "the warning should move up a row with the challenge menu, at " .. menuY .. " but is at " .. warningY)

  GAME.netClient:disconnectSubscriber(lobby)
  GAME.netClient.lobbyDataV2 = savedLobbyData
end

testTheChallengeWarningFollowsTheMenuWhenThePlayerMovesUp()

local function testTheChallengeWarningsCardStartsAPaddingRightOfTheMenuAtItsTop()
  local savedLobbyData = GAME.netClient.lobbyDataV2
  local lobby = Lobby({})
  updateLobby(lobby, lobbyDataWith({9001, 9002}))
  local button = playerButton(lobby, 9002)
  assert(button, "the lobby should list player 9002")
  lobby.lobbyMenu:select(button)
  lobby:openPlayerSubMenu(9002, button)
  lobby.uiRoot:layOut()

  local warning = challengeWarning(lobby)
  assert(warning, "the challenge menu should have a connection warning")
  local menuX, menuY = lobby.playerSubMenu:getScreenPos()
  local x, y = warning:getScreenPos()
  local expectedX = menuX + lobby.playerSubMenu.layoutRect.width + ConnectionWarning.PADDING
  assert(x == expectedX, "the card should start a padding right of the menu, at x " .. expectedX .. " but is at " .. x)
  assert(y == menuY, "the card's top should line up with the menu's top, at y " .. menuY .. " but is at " .. y)

  GAME.netClient:disconnectSubscriber(lobby)
  GAME.netClient.lobbyDataV2 = savedLobbyData
end

testTheChallengeWarningsCardStartsAPaddingRightOfTheMenuAtItsTop()
