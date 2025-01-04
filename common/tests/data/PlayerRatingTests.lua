local PlayerRating = require("common.data.PlayerRating")
local simpleCSV = require("server.simplecsv")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")

-- If starting RD is too high, or too many matches happen in one rating period, massive swings can happen.
-- This test is to explore that and come up with sane values.
local function testWeirdNumberStability() 

  local player1 = PlayerRating(1273, 20)
  local player2 = PlayerRating(1500, 20)

  local wins = 12
  local totalGames = 25

  local updatedPlayer1 = player1:newRatingForRatingPeriodWithResults(player1:createSetResults(player2, wins, totalGames))
  local updatedPlayer2 = player2:newRatingForRatingPeriodWithResults(player1:createSetResults(player1, totalGames-wins, totalGames))

  assert(updatedPlayer1:getRating() > 1073)
  assert(updatedPlayer2:getRating() < 1500)
  assert(updatedPlayer2:getRating() > 1338)
end

testWeirdNumberStability()

local function testRatingPeriodsForOccasionalPlayers() 
  local players = {}
  for _ = 1, 3 do
    players[#players+1] = PlayerRating()
  end
  
  local previousPlayers = nil
  for i = 1, 100, 1 do
    local playerResults = {}
    for _ = 1, 3 do
      playerResults[#playerResults+1] = {}
    end
    local gameCount = 10
    local winPercentage = .6
    local winCount = math.ceil(winPercentage*gameCount)
    tableUtils.appendToList(playerResults[1], players[1]:createSetResults(players[2], winCount, gameCount))
    tableUtils.appendToList(playerResults[2], players[2]:createSetResults(players[1], gameCount-winCount, gameCount))
    
    gameCount = 5
    winPercentage = .8
    winCount = math.ceil(winPercentage*gameCount)
    tableUtils.appendToList(playerResults[1], players[1]:createSetResults(players[3], winCount, gameCount))
    tableUtils.appendToList(playerResults[3], players[3]:createSetResults(players[1], gameCount-winCount, gameCount))

    gameCount = 5
    winPercentage = .6
    winCount = math.ceil(winPercentage*gameCount)
    tableUtils.appendToList(playerResults[2], players[2]:createSetResults(players[3], winCount, gameCount))
    tableUtils.appendToList(playerResults[3], players[3]:createSetResults(players[2], gameCount-winCount, gameCount))

    previousPlayers = {}
    for k = 1, 3 do
      previousPlayers[#previousPlayers+1] = players[k]:copy()
    end
    for k = 1, 3 do
      players[k] = players[k]:newRatingForRatingPeriodWithResults(playerResults[k])
    end
  end

  assert(players[1]:getRating() > players[2]:getRating())
  assert(players[1]:getRating() > players[3]:getRating())
  assert(players[2]:getRating() > players[3]:getRating())

  assert(players[1].glicko.RD < players[3].glicko.RD)
  assert(players[2].glicko.RD < players[3].glicko.RD)

  assert(players[1].glicko.RD < 60)
  assert(players[2].glicko.RD < 60)
  assert(players[3].glicko.RD < 60)

  for k = 1, 3 do
    -- rating and deviation should stabilize over time if players perform the same
    assert(math.abs(previousPlayers[k]:getRating() - players[k]:getRating()) < 1)
    assert(math.abs(previousPlayers[k].glicko.RD - players[k].glicko.RD) < 1)
    assert(previousPlayers[k]:isProvisional() == false)
  end
end 

testRatingPeriodsForOccasionalPlayers()

local function testRatingPeriodsForObsessivePlayers()
  local players = {}
  for _ = 1, 3 do
    players[#players+1] = PlayerRating()
  end

  local previousPlayers = nil
  for i = 1, 100, 1 do
    local playerResults = {}
    for _ = 1, 3 do
      playerResults[#playerResults+1] = {}
    end
    local gameCount = 100
    local winPercentage = .6
    local winCount = math.ceil(winPercentage*gameCount)
    tableUtils.appendToList(playerResults[1], players[1]:createSetResults(players[2], winCount, gameCount))
    tableUtils.appendToList(playerResults[2], players[2]:createSetResults(players[1], gameCount-winCount, gameCount))

    gameCount = 80
    winPercentage = .8
    winCount = math.ceil(winPercentage*gameCount)
    tableUtils.appendToList(playerResults[1], players[1]:createSetResults(players[3], winCount, gameCount))
    tableUtils.appendToList(playerResults[3], players[3]:createSetResults(players[1], gameCount-winCount, gameCount))

    gameCount = 60
    winPercentage = .6
    winCount = math.ceil(winPercentage*gameCount)
    tableUtils.appendToList(playerResults[2], players[2]:createSetResults(players[3], winCount, gameCount))
    tableUtils.appendToList(playerResults[3], players[3]:createSetResults(players[2], gameCount-winCount, gameCount))

    previousPlayers = {}
    for k = 1, 3 do
      previousPlayers[#previousPlayers+1] = players[k]:copy()
    end
    for k = 1, 3 do
      players[k] = players[k]:newRatingForRatingPeriodWithResults(playerResults[k])
    end
  end

  assert(players[1]:getRating() > players[2]:getRating())
  assert(players[1]:getRating() > players[3]:getRating())
  assert(players[2]:getRating() > players[3]:getRating())

  assert(players[1].glicko.RD < players[3].glicko.RD)
  assert(players[2].glicko.RD < players[3].glicko.RD)

  assert(players[1].glicko.RD < 20)
  assert(players[2].glicko.RD < 20)
  assert(players[3].glicko.RD < 20)

  for k = 1, 3 do
    -- rating and deviation should stabilize over time if players perform the same
    assert(math.abs(previousPlayers[k]:getRating() - players[k]:getRating()) < 1)
    assert(math.abs(previousPlayers[k].glicko.RD - players[k].glicko.RD) < 1)
    assert(previousPlayers[k]:isProvisional() == false)
  end
end

testRatingPeriodsForObsessivePlayers()

-- When a stable player doesn't play for a long time, we should lose some confidence in their rating, but not all.
local function testMaxRD() 
  local playerRating = PlayerRating(2000, 30)

  local threeMonthsInSeconds = 60 * 60 * 24 * 31 * 3
  local threeMonthsOfRatingPeriod = math.ceil(threeMonthsInSeconds / PlayerRating.RATING_PERIOD_IN_SECONDS)
  for i = 1, threeMonthsOfRatingPeriod, 1 do
    playerRating = playerRating:newRatingForRatingPeriodWithResults({})
  end

  assert(playerRating.glicko.RD >= 120)

  local nineMoreMonths = 60 * 60 * 24 * 31 * 9
  local oneYearOfRatingPeriod = math.ceil(nineMoreMonths / PlayerRating.RATING_PERIOD_IN_SECONDS)
  for i = 1, oneYearOfRatingPeriod, 1 do
    playerRating = playerRating:newRatingForRatingPeriodWithResults({})
  end

  assert(playerRating.glicko.RD >= 245)
end 

testMaxRD()

local function testFarming()
  local players = {}
  for _ = 1, 2 do
    players[#players+1] = PlayerRating()
  end

  -- Player 1 and 2 play normal sets to get a standard
  for i = 1, 100, 1 do
    local playerResults = {}
    for _ = 1, 2 do
      playerResults[#playerResults+1] = {}
    end

    tableUtils.appendToList(playerResults[1], players[1]:createSetResults(players[2], 11, 20))
    tableUtils.appendToList(playerResults[2], players[2]:createSetResults(players[1], 9, 20))

    for k = 1, 2 do
      players[k] = players[k]:newRatingForRatingPeriodWithResults(playerResults[k])
    end
  end

  -- Farm newcomers to see how much rating you can gain
  for i = 1, 100, 1 do
    local playerResults = {}
    for _ = 1, 1 do
      playerResults[#playerResults+1] = {}
    end

    local newbiePlayer = PlayerRating()
    tableUtils.appendToList(playerResults[1], players[1]:createSetResults(newbiePlayer, 10, 10))

    for k = 1, 1 do
      players[k] = players[k]:newRatingForRatingPeriodWithResults(playerResults[k])
    end
  end

  assert(players[1]:getRating() > PlayerRating.STARTING_RATING + PlayerRating.ALLOWABLE_RATING_SPREAD) -- Ranked high enough we can't play default players anymore
  assert(players[1]:getRating() < 2000) -- Thus we couldn't farm really high

end 

testFarming()

local function testNewcomerSwing()
  local players = {}
  players[#players+1] = PlayerRating()
  players[#players+1] = PlayerRating(1121.96, 29.65)

  -- Newcomer loses 40 times in a row...
  for i = 1, 40, 1 do
    local playerResults = {}
    for _ = 1, 2 do
      playerResults[#playerResults+1] = {}
    end

    tableUtils.appendToList(playerResults[1], players[1]:createSetResults(players[2], 0, 40))
    tableUtils.appendToList(playerResults[2], players[2]:createSetResults(players[1], 40, 40))

    for k = 1, 2 do
      players[k] = players[k]:newRatingForRatingPeriodWithResults(playerResults[k])
    end
  end

  assert(players[1]:getRating() > 0) -- We should never get a negative rating
end 

testNewcomerSwing()




local function testSingleGameNotTooBigRatingChange()
  local players = {}
  for _ = 1, 2 do
    players[#players+1] = PlayerRating()
  end

  -- Player 1 and 2 play normal sets to get a standard
  for i = 1, 100, 1 do
    local playerResults = {}
    for _ = 1, 2 do
      playerResults[#playerResults+1] = {}
    end

    tableUtils.appendToList(playerResults[1], players[1]:createSetResults(players[2], 11, 20))
    tableUtils.appendToList(playerResults[2], players[2]:createSetResults(players[1], 9, 20))

    for k = 1, 2 do
      players[k] = players[k]:newRatingForRatingPeriodWithResults(playerResults[k])
    end
  end

  local firstRating = players[1]:getRating()
  assert(firstRating > 1515 and firstRating < 1525)

  local playerResults = {}
  tableUtils.appendToList(playerResults, players[1]:createSetResults(players[2], 1, 1))
  players[1] = players[1]:newRatingForRatingPeriodWithResults(playerResults)

  local secondRating = players[1]:getRating()
  local ratingDifference = secondRating - firstRating
  assert(ratingDifference > 2 and ratingDifference < 4) -- Rating shouldn't change too much from one game
end 

testSingleGameNotTooBigRatingChange()

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

local function runRatingPeriods(firstRatingPeriod, lastRatingPeriod, players, glickoResultsTable)

  local totalGamesPlayed = 0

  -- Run each rating period (the later ones will just increase RD)
  for i = firstRatingPeriod, lastRatingPeriod, 1 do
    for playerID, playerTable in pairs(players) do

      local playerRating = playerTable.playerRating
      local gameResults = playerTable.gameResults
      totalGamesPlayed = totalGamesPlayed + #gameResults

      local newPlayerRating = playerRating:newRatingForRatingPeriodWithResults(gameResults)

      if playerTable.playerRating:getRating() < 0 then
        local newPlayerRating2 = playerRating:newRatingForRatingPeriodWithResults(gameResults)
      end

      playerTable.playerRating = newPlayerRating
      playerTable.gameResults = {}
    end

    if i == firstRatingPeriod then
      for playerID, playerTable in pairs(players) do
        local row = {}
        row[#row+1] = i
        row[#row+1] = playerID
        row[#row+1] = playerTable.playerRating:getRating()
        row[#row+1] = playerTable.playerRating.glicko.RD
        if firstRatingPeriod % 20 == 1 then
          glickoResultsTable[#glickoResultsTable+1] = row
        end
      end
    end
  end

  totalGamesPlayed = totalGamesPlayed / 2

  local now = os.date("*t", PlayerRating.timestampForRatingPeriod(firstRatingPeriod))
  logger.info("Processing " .. firstRatingPeriod .. " to " .. lastRatingPeriod .. " on " .. string.format("%02d/%02d/%04d", now.month, now.day, now.year) .. " with " .. totalGamesPlayed .. " games")
end

-- This test is to experiment with real world server data to verify the values work well.
-- put the players.txt, and GameResults.csv files in the root directory to run this test.
-- Make sure you don't keep this test enabled or commit those files!
local function testRealWorldData()
  local players = {}
  local glickoResultsTable = {}
  local ratingPeriodNeedingRun = nil
  local latestRatingPeriodFound = nil
  local gamesPlayedDays = {}
  local gameResults = simpleCSV.read("GameResults.csv")
  assert(gameResults)

  local playersFile, err = love.filesystem.newFile("players.txt", "r")
  if playersFile then
    local tehJSON = playersFile:read(playersFile:getSize())
    playersFile:close()
    playersFile = nil
    local playerData = json.decode(tehJSON) or {}
    if playerData then
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

    latestRatingPeriodFound = PlayerRating.ratingPeriodForTimeStamp(timestamp)
    if ratingPeriodNeedingRun == nil then
      ratingPeriodNeedingRun = latestRatingPeriodFound
    end

    -- if we just passed the rating period, time to update ratings
    if ratingPeriodNeedingRun ~= latestRatingPeriodFound then
      assert(latestRatingPeriodFound > ratingPeriodNeedingRun)
      runRatingPeriods(ratingPeriodNeedingRun, latestRatingPeriodFound-1, players, glickoResultsTable)
      ratingPeriodNeedingRun = latestRatingPeriodFound
    end

    local currentPlayerSets = {{player1ID, player2ID}, {player2ID, player1ID}}
    for _, currentPlayers in ipairs(currentPlayerSets) do
      local playerID = currentPlayers[1]
      -- Create a new player if one doesn't exist yet.
      if not players[playerID] then
        players[playerID] = {}
        players[playerID].playerRating = PlayerRating()
        assert(players[playerID].playerRating:getRating() > 0)
        players[playerID].gameResults = {}
        players[playerID].error = 0
        players[playerID].totalGames = 0
      end
    end

    for index, currentPlayers in ipairs(currentPlayerSets) do
      local player = players[currentPlayers[1]].playerRating
      local opponent = players[currentPlayers[2]].playerRating
      local gameResult = winResult
      if index == 2 then
        gameResult = PlayerRating.invertedGameResult(winResult)
      end
      local expected = player:expectedOutcome(opponent)
      --if player:isProvisional() == false then
        players[currentPlayers[1]].error = players[currentPlayers[1]].error + (gameResult - expected)
        players[currentPlayers[1]].totalGames = players[currentPlayers[1]].totalGames + 1
      --end
      local result = player:createGameResult(opponent, gameResult)
      local gameResults = players[currentPlayers[1]].gameResults
      gameResults[#gameResults+1] = result
    end

    ::continue::
  end

  -- Handle the last rating period
  assert(ratingPeriodNeedingRun == latestRatingPeriodFound)
  runRatingPeriods(ratingPeriodNeedingRun, latestRatingPeriodFound, players, glickoResultsTable)

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
  -- 0.03724587514630  RATING PERIOD = 16hrs -- DEFAULT_RATING_DEVIATION = 250 = MAX_DEVIATION -- PROVISIONAL_DEVIATION = RD * 0.5 -- DEFAULT_VOLATILITY = 0.06 = MAX_VOLATILITY
  -- 0.03792533617676  RATING PERIOD = 24hrs -- DEFAULT_RATING_DEVIATION = 250 = MAX_DEVIATION -- PROVISIONAL_DEVIATION = RD * 0.5 -- DEFAULT_VOLATILITY = 0.06 = MAX_VOLATILITY

  local gamesPlayedData = {}
  for dateKey, data in pairsSortedByKeys(gamesPlayedDays) do
    gamesPlayedData[#gamesPlayedData+1] = data
  end
  simpleCSV.write("GamesPlayed.csv", gamesPlayedData)
end 

-- testRealWorldData()