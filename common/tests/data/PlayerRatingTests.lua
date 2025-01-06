local PlayerRating = require("common.data.PlayerRating")
local simpleCSV = require("server.simplecsv")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")

local function createPlayer(playerTable, playerID, playerRating)
  playerTable[playerID] = {}
  playerTable[playerID].playerRating = playerRating
  assert(playerTable[playerID].playerRating:getRating() > 0)
  playerTable[playerID].error = 0
  playerTable[playerID].totalGames = 0
end

local function playGamesWithResults(playerTable, player1ID, player2ID, gameResults, ratingPeriodElapsed)
  for _, gameResult in ipairs(gameResults) do
    local player1Rating = playerTable[player1ID].playerRating
    local player2Rating = playerTable[player2ID].playerRating
    for i = 1, 2, 1 do
      local playerID = player1ID
      local playerRating = player1Rating
      local opponentRating = player2Rating
      if i == 2 then
        playerID = player2ID
        playerRating = player2Rating
        opponentRating = player1Rating
        gameResult = PlayerRating.invertedGameResult(gameResult)
      end
      local result = playerRating:createGameResult(opponentRating, gameResult)
      local expected = playerRating:expectedOutcome(opponentRating)

      playerTable[playerID].playerRating = playerRating:newRatingForResultsAndElapsedRatingPeriod(result, ratingPeriodElapsed)
      playerTable[playerID].error = playerTable[playerID].error + (gameResult - expected)
      playerTable[playerID].totalGames = playerTable[playerID].totalGames + 1
    end
  end
end

local function applyNewRatingPeriodToPlayers(playerTable, ratingPeriod)
  for _, playerRow in ipairs(playerTable) do
    playerRow.playerRating = playerRow.playerRating:newRatingForResultsAndLatestRatingPeriod(nil, ratingPeriod)
  end
end

local function testLowRDSimilarOpponents()

  local player1 = PlayerRating(1490, 20)
  local player2 = PlayerRating(1500, 20)
  local players = {}
  createPlayer(players, 1, player1)
  createPlayer(players, 2, player2)

  playGamesWithResults(players, 1, 2, PlayerRating.createTestSetResults(1, 1), 0)

  local player1RatingChange = players[1].playerRating:getRating() - player1:getRating()
  local player2RatingChange = players[2].playerRating:getRating() - player2:getRating()
  assert(player1RatingChange > 1 and player1RatingChange < 2)
  assert(player2RatingChange < -1 and player2RatingChange > -2)
end
testLowRDSimilarOpponents()

local function testLowRDFarOpponentUpset()

  local player1 = PlayerRating(1110, 20)
  local player2 = PlayerRating(1500, 20)
  local players = {}
  createPlayer(players, 1, player1)
  createPlayer(players, 2, player2)

  playGamesWithResults(players, 1, 2, PlayerRating.createTestSetResults(1, 1), 0)

  local player1RatingChange = players[1].playerRating:getRating() - player1:getRating()
  local player2RatingChange = players[2].playerRating:getRating() - player2:getRating()
  assert(player1RatingChange > 2 and player1RatingChange < 3)
  assert(player2RatingChange < -2 and player2RatingChange > -3)
end
testLowRDFarOpponentUpset()

local function testLowRDFarOpponentExpected()
  local player1 = PlayerRating(1110, 20)
  local player2 = PlayerRating(1500, 20)
  local players = {}
  createPlayer(players, 1, player1)
  createPlayer(players, 2, player2)

  playGamesWithResults(players, 1, 2, PlayerRating.createTestSetResults(0, 1), 0)

  local player1RatingChange = players[1].playerRating:getRating() - player1:getRating()
  local player2RatingChange = players[2].playerRating:getRating() - player2:getRating()
  assert(player1RatingChange < -0.2 and player1RatingChange > -0.3)
  assert(player2RatingChange > .2 and player2RatingChange < .3)
end
testLowRDFarOpponentExpected()

local function testHighRDSimilarOpponents()
  local player1 = PlayerRating(1490, PlayerRating.STARTING_RATING_DEVIATION)
  local player2 = PlayerRating(1500, PlayerRating.STARTING_RATING_DEVIATION)
  local players = {}
  createPlayer(players, 1, player1)
  createPlayer(players, 2, player2)

  playGamesWithResults(players, 1, 2, PlayerRating.createTestSetResults(1, 1), 0)

  local player1RatingChange = players[1].playerRating:getRating() - player1:getRating()
  local player2RatingChange = players[2].playerRating:getRating() - player2:getRating()
  assert(player1RatingChange > 80 and player1RatingChange < 100)
  assert(player2RatingChange < -80 and player2RatingChange > -100)
end
testHighRDSimilarOpponents()

local function testNewcomerUpset()
  local player1 = PlayerRating()
  local player2 = PlayerRating(1890, 20)
  local players = {}
  createPlayer(players, 1, player1)
  createPlayer(players, 2, player2)

  playGamesWithResults(players, 1, 2, PlayerRating.createTestSetResults(1, 1), 0)

  local player1RatingChange = players[1].playerRating:getRating() - player1:getRating()
  local player2RatingChange = players[2].playerRating:getRating() - player2:getRating()
  assert(player1RatingChange > 180 and player1RatingChange < 200)
  assert(player2RatingChange < -1 and player2RatingChange > -5)
end
testNewcomerUpset()

local function testNewcomerExpected()
  local player1 = PlayerRating()
  local player2 = PlayerRating(1890, 20)
  local players = {}
  createPlayer(players, 1, player1)
  createPlayer(players, 2, player2)

  playGamesWithResults(players, 1, 2, PlayerRating.createTestSetResults(0, 1), 0)

  local player1RatingChange = players[1].playerRating:getRating() - player1:getRating()
  local player2RatingChange = players[2].playerRating:getRating() - player2:getRating()
  assert(player1RatingChange < -19 and player1RatingChange > -20)
  assert(player2RatingChange > .2 and player2RatingChange < .3)
end
testNewcomerExpected()

local function testNoMatchesInRatingPeriod()

  local player1 = PlayerRating(1500, 150)

  -- We shouldn't assert or blow up in here, v goes to infinity but it is okay to divide by infinity as that is 0...
  local updatedPlayer1 = player1:newRatingForResultsAndElapsedRatingPeriod({}, 1)
  assert(updatedPlayer1:getRating() == 1500) -- rating shouldn't change
  assert(updatedPlayer1.glicko.RD > 150) -- RD should go up
end
testNoMatchesInRatingPeriod()

local function testRatingPeriodsForOccasionalPlayers()
  local players = {}
  for i = 1, 3 do
    createPlayer(players, i, PlayerRating())
  end

  local ratingPeriodBetweenSets = 24 * 60 * 60 / PlayerRating.RATING_PERIOD_IN_SECONDS
  local previousPlayerRatings = {}
  for i = 1, 100, 1 do
    for k = 1, 3 do
      previousPlayerRatings[k] = players[k].playerRating:copy()
    end
    playGamesWithResults(players, 1, 2, PlayerRating.createTestSetResults(6, 10), 0)
    playGamesWithResults(players, 1, 3, PlayerRating.createTestSetResults(4, 5), 0)
    playGamesWithResults(players, 2, 3, PlayerRating.createTestSetResults(3, 5), 0)

    applyNewRatingPeriodToPlayers(players, i * ratingPeriodBetweenSets)
  end

  assert(players[1].playerRating:getRating() > players[2].playerRating:getRating())
  assert(players[1].playerRating:getRating() > players[3].playerRating:getRating())
  assert(players[2].playerRating:getRating() > players[3].playerRating:getRating())

  assert(players[1].playerRating.glicko.RD < 60)
  assert(players[2].playerRating.glicko.RD < 60)
  assert(players[3].playerRating.glicko.RD < 60)

  for k = 1, 3 do
    -- rating and deviation should stabilize over time if players perform the same
    assert(math.abs(previousPlayerRatings[k]:getRating() - players[k].playerRating:getRating()) < 6)
    assert(math.abs(previousPlayerRatings[k].glicko.RD - players[k].playerRating.glicko.RD) < 1)
    assert(previousPlayerRatings[k]:isProvisional() == false)
  end
end
testRatingPeriodsForOccasionalPlayers()

local function testRatingPeriodsForObsessivePlayers()
  local players = {}
  for i = 1, 3 do
    createPlayer(players, i, PlayerRating())
  end

  local ratingPeriodBetweenSets = 24 * 60 * 60 / PlayerRating.RATING_PERIOD_IN_SECONDS
  local previousPlayerRatings = {}
  for i = 1, 100, 1 do
    for k = 1, 3 do
      previousPlayerRatings[k] = players[k].playerRating:copy()
    end
    playGamesWithResults(players, 1, 2, PlayerRating.createTestSetResults(60, 100), 0)
    playGamesWithResults(players, 1, 3, PlayerRating.createTestSetResults(40, 50), 0)
    playGamesWithResults(players, 2, 3, PlayerRating.createTestSetResults(30, 50), 0)

    applyNewRatingPeriodToPlayers(players, i * ratingPeriodBetweenSets)
  end

  assert(players[1].playerRating:getRating() > players[2].playerRating:getRating())
  assert(players[1].playerRating:getRating() > players[3].playerRating:getRating())
  assert(players[2].playerRating:getRating() > players[3].playerRating:getRating())

  assert(players[1].playerRating.glicko.RD < 30)
  assert(players[2].playerRating.glicko.RD < 30)
  assert(players[3].playerRating.glicko.RD < 35) -- player 3 "only" played 100 games per day

  for k = 1, 3 do
    -- rating and deviation should stabilize over time if players perform the same
    assert(math.abs(previousPlayerRatings[k]:getRating() - players[k].playerRating:getRating()) < 6)
    assert(math.abs(previousPlayerRatings[k].glicko.RD - players[k].playerRating.glicko.RD) < 1)
    assert(previousPlayerRatings[k]:isProvisional() == false)
  end
end
testRatingPeriodsForObsessivePlayers()

-- When a stable player doesn't play for a long time, we should lose some confidence in their rating, but not all.
local function testMaxRD()
  local playerRating = PlayerRating(2000, 30)

  local threeMonthsInSeconds = 60 * 60 * 24 * 31 * 3
  local threeMonthsOfRatingPeriod = math.ceil(threeMonthsInSeconds / PlayerRating.RATING_PERIOD_IN_SECONDS)
  for i = 1, threeMonthsOfRatingPeriod, 1 do
    playerRating = playerRating:newRatingForResultsAndElapsedRatingPeriod({}, 1)
  end

  assert(playerRating.glicko.RD >= 120)

  local nineMoreMonths = 60 * 60 * 24 * 31 * 9
  local oneYearOfRatingPeriod = math.ceil(nineMoreMonths / PlayerRating.RATING_PERIOD_IN_SECONDS)
  for i = 1, oneYearOfRatingPeriod, 1 do
    playerRating = playerRating:newRatingForResultsAndElapsedRatingPeriod({}, 1)
  end

  assert(playerRating.glicko.RD >= PlayerRating.MAX_RATING_DEVIATION)
end
testMaxRD()

local function testFarming()
  local players = {}
  for i = 1, 2 do
    createPlayer(players, i, PlayerRating())
  end

  local ratingPeriodBetweenSets = 24 * 60 * 60 / PlayerRating.RATING_PERIOD_IN_SECONDS
  for i = 1, 100, 1 do
    playGamesWithResults(players, 1, 2, PlayerRating.createTestSetResults(11, 20), 0)
    applyNewRatingPeriodToPlayers(players, i * ratingPeriodBetweenSets)
  end

  -- Farm newcomers to see how much rating you can gain
  for i = 3, 1000, 1 do
    createPlayer(players, i, PlayerRating())
    playGamesWithResults(players, 1, i, PlayerRating.createTestSetResults(1, 1), 0)
  end

  assert(players[1].playerRating:getRating() > PlayerRating.STARTING_RATING + PlayerRating.ALLOWABLE_RATING_SPREAD) -- Ranked high enough we can't play default players anymore
  assert(players[1].playerRating:getRating() < 2000) -- Thus we couldn't farm really high
end
testFarming()

local function testNewcomerSwing()
  local players = {}
  createPlayer(players, 1, PlayerRating())
  createPlayer(players, 2, PlayerRating(1121.96, 29.65))

  -- Newcomer loses 40 times in a row...
  playGamesWithResults(players, 1, 2, PlayerRating.createTestSetResults(0, 40), 0)

  assert(players[1].playerRating:getRating() > 700) -- Newcomer shouldn't go too far below other player
  assert(players[1].playerRating:getRating() < 800) -- Newcomer should go down significantly though
  assert(players[1].playerRating.glicko.RD > 70) -- Newcomer RD should start going down, but not too much
  assert(players[1].playerRating.glicko.RD < 150) -- Newcomer RD should start going down, but not too much
  assert(players[2].playerRating:getRating() > 1130) -- Normal player shouldn't gain too much rating
  assert(players[2].playerRating:getRating() < 1200)
  assert(players[2].playerRating.glicko.RD > 25) -- Normal player RD should stay similar
  assert(players[2].playerRating.glicko.RD < 30)
end
testNewcomerSwing()

local usedNames = {}
local publicIDMap = {} -- mapping of privateID to publicID
local function cleanNameForName(name, privateID)
  name = name or "Player"
  privateID = tostring(privateID)
  if publicIDMap[privateID] == nil then
    local result = name
    while usedNames[result] ~= nil do
      result = name .. math.random(1000000, 9999999)
    end
    usedNames[result] = true
    publicIDMap[privateID] = result
  end

  return publicIDMap[privateID]
end

local function saveToResultsTable(currentRatingPeriod, players, glickoResultsTable)
  for playerID, playerTable in pairs(players) do
      -- Make sure the player is up to date with the current rating period
  local newPlayerRating = playerTable.playerRating:newRatingForResultsAndLatestRatingPeriod({}, currentRatingPeriod)
  playerTable.playerRating = newPlayerRating
    local row = {}
    row[#row+1] = playerTable.playerRating.lastRatingPeriodCalculated
    row[#row+1] = playerID
    row[#row+1] = playerTable.playerRating:getRating()
    row[#row+1] = playerTable.playerRating.glicko.RD
    row[#row+1] = playerTable.playerRating.glicko.Vol
    row[#row+1] = playerTable.error
    row[#row+1] = playerTable.totalGames
    glickoResultsTable[#glickoResultsTable+1] = row
  end
end

local function runRatingPeriods(latestRatingPeriodFound, lastRatingPeriodSaved, players, playerID, gameResults, glickoResultsTable)

end

-- This test is to experiment with real world server data to verify the values work well.
-- put the players.txt, and GameResults.csv files in the root directory to run this test.
-- Make sure you don't keep this test enabled or commit those files!
local function testRealWorldData()
  local players = {}
  local glickoResultsTable = {}
  local lastRatingPeriodSaved = 0
  local lastRatingPeriodFound = 0
  local gamesPlayedDays = {}
  local gameResults = simpleCSV.read("GameResults.csv")
  assert(gameResults)

  local tehJSON, err = love.filesystem.read("players.txt")
  if tehJSON then
    local playerData = json.decode(tehJSON)
    if playerData then
      ---@cast playerData table
      for key, value in pairs(playerData) do
        cleanNameForName(value, key)
      end
    end
  end

  for row = 1, #gameResults do
    local player1ID = cleanNameForName(nil, gameResults[row][1])
    local player2ID = cleanNameForName(nil, gameResults[row][2])
    local winResult = tonumber(gameResults[row][3])
    local ranked = tonumber(gameResults[row][4])
    local timestamp = tonumber(gameResults[row][5])
    local dateTable = os.date("*t", timestamp)

    assert(player1ID)
    assert(player2ID)
    assert(winResult)
    assert(ranked)
    assert(timestamp)
    assert(dateTable)

    local now = os.date("*t", timestamp)
    local dateKey = string.format("%02d/%02d/%04d", now.month, now.day, now.year)

    if gamesPlayedDays[dateKey] == nil then
      gamesPlayedDays[dateKey] = {"",0,0}
      gamesPlayedDays[dateKey][1] = dateKey
    end

    if ranked == 0 then
      gamesPlayedDays[dateKey][2] = gamesPlayedDays[dateKey][2] + 1
    else
      gamesPlayedDays[dateKey][3] = gamesPlayedDays[dateKey][3] + 1
    end

    if ranked == 0 then
      goto continue
    end

    local currentRatingPeriod = PlayerRating.ratingPeriodForTimeStamp(timestamp)
    lastRatingPeriodFound = currentRatingPeriod

    local now = os.date("*t", PlayerRating.timestampForRatingPeriod(currentRatingPeriod))
    logger.info("Processing " .. currentRatingPeriod .. " on " .. string.format("%02d/%02d/%04d", now.month, now.day, now.year))

    local currentPlayerSets = {{player1ID, player2ID}, {player2ID, player1ID}}
    for _, playerID in ipairs(currentPlayerSets[1]) do
      -- Create a new player if one doesn't exist yet.
      if not players[playerID] then
        createPlayer(players, playerID, PlayerRating())
      end
      players[playerID].playerRating = players[playerID].playerRating:newRatingForResultsAndLatestRatingPeriod(nil, currentRatingPeriod)
    end

    playGamesWithResults(players, player1ID, player2ID, {winResult}, 0)

    -- Save off to a table for data analysis
    local periodDifferenceFromLastRecord = currentRatingPeriod - lastRatingPeriodSaved
    local shouldRecordRatings = (periodDifferenceFromLastRecord > 10) or (periodDifferenceFromLastRecord >= 1 and (currentRatingPeriod > 30130 or currentRatingPeriod < 29440))
    if lastRatingPeriodSaved == nil or shouldRecordRatings then
      saveToResultsTable(currentRatingPeriod, players, glickoResultsTable)
      lastRatingPeriodSaved = currentRatingPeriod
    end

    ::continue::
  end

  saveToResultsTable(lastRatingPeriodFound, players, glickoResultsTable)

  local totalError = 0
  local totalGames = 0
  local provisionalCount = 0
  local playerCount = 0
  for playerID, playerTable in pairs(players) do
    if playerTable.totalGames > 0 then
      local error = math.abs(playerTable.error)
      totalError = totalError + error
      totalGames = totalGames + playerTable.totalGames
    end
    if playerTable.playerRating:isProvisional() then
      provisionalCount = provisionalCount + 1
    end
    playerCount = playerCount + 1
  end
  local totalErrorPerGame = totalError / totalGames

  simpleCSV.write("Glicko.csv", glickoResultsTable)
  -- 0.014760291450591 1 game per evaluation      DEFAULT_RATING_DEVIATION:200 MAX_DEVIATION:200 DEFAULT_VOLATILITY:0.06 MAX_VOLATILITY:0.3  Tau:0.5  RATING PERIOD = 16hrs
  -- 0.019420264639828 1 game per evaluation      DEFAULT_RATING_DEVIATION:250 MAX_DEVIATION:250 DEFAULT_VOLATILITY:0.06 MAX_VOLATILITY:0.3  Tau:0.2  RATING PERIOD = 16hrs
  -- 0.019439095055957 1 game per evaluation      DEFAULT_RATING_DEVIATION:250 MAX_DEVIATION:250 DEFAULT_VOLATILITY:0.06 MAX_VOLATILITY:0.3  Tau:0.75 RATING PERIOD = 16hrs
  -- 0.01944363557018  1 game per evaluation      DEFAULT_RATING_DEVIATION:250 MAX_DEVIATION:350 DEFAULT_VOLATILITY:0.06 MAX_VOLATILITY:0.06 Tau:?    RATING PERIOD = 16hrs
  -- 0.03724587514630  all games in rating period DEFAULT_RATING_DEVIATION:250 MAX_DEVIATION:250 DEFAULT_VOLATILITY:0.06 MAX_VOLATILITY:0.06 Tau:?    RATING PERIOD = 16hrs
  -- 0.03792533617676  all games in rating period DEFAULT_RATING_DEVIATION:250 MAX_DEVIATION:250 DEFAULT_VOLATILITY:0.06 MAX_VOLATILITY:0.06 Tau:?    RATING PERIOD = 24hrs

  local gamesPlayedData = {}
  for dateKey, data in pairsSortedByKeys(gamesPlayedDays) do
    gamesPlayedData[#gamesPlayedData+1] = data
  end
  simpleCSV.write("GamesPlayed.csv", gamesPlayedData)
end

testRealWorldData()