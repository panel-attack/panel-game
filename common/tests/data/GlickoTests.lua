local Glicko2 = require("common.data.Glicko")

local function basicTest() 
  local player1 = Glicko2.g1(1500, 350)
  local player2 = Glicko2.g1(1500, 350)

  local updatedPlayer1, updatedPlayer2 = Glicko2.updatedRatings(player1, player2, {1})

  assert(math.floor(updatedPlayer1.Rating) == 1662)
  assert(math.floor(updatedPlayer2.Rating) == 1337)

  assert(player1.RD > updatedPlayer1.RD)
  assert(player2.RD > updatedPlayer2.RD)
end 

basicTest()

local function expectedOutcome() 
  local player1 = Glicko2.g1(1500, 350)
  local player2 = Glicko2.g1(1500, 350)

  assert(player1:expectedOutcome(player2) == 0.5)
  assert(player2:expectedOutcome(player1) == 0.5)

  local updatedPlayer1, updatedPlayer2 = Glicko2.updatedRatings(player1, player2, {1})

  assert(math.floor(updatedPlayer1.Rating) == 1662)
  assert(math.floor(updatedPlayer2.Rating) == 1337)

  assert(player1.RD > updatedPlayer1.RD)
  assert(player2.RD > updatedPlayer2.RD)

  assert(math.round(updatedPlayer1:expectedOutcome(updatedPlayer2), 2) == 0.76)
  assert(math.round(updatedPlayer2:expectedOutcome(updatedPlayer1), 2) == 0.24)

  local player3 = Glicko2.g1(2000, 40)
  local player4 = Glicko2.g1(1500, 350)

  assert(math.round(player3:expectedOutcome(player4), 2) == 0.87)

  local player4 = Glicko2.g1(2000, 40)
  local player5 = Glicko2.g1(600, 40)

  assert(math.round(player4:expectedOutcome(player5), 4) == .9996)

  local player6 = Glicko2.g1(2500, 40)
  local player7 = Glicko2.g1(1500, 40)

  assert(math.round(player6:expectedOutcome(player7), 4) == .9965)
end 

expectedOutcome()

local function establishedVersusNew() 

  local player1 = Glicko2.g1(1500, 40)
  local player2 = Glicko2.g1(1500, 350)
  
  local updatedPlayer1, updatedPlayer2 = Glicko2.updatedRatings(player1, player2, {1, 1, 1, 1, 1, 1, 1, 1, 1, 0})
  
  assert(math.floor(updatedPlayer1.Rating) == 1524)
  assert(math.floor(updatedPlayer2.Rating) == 1245)

  assert(math.floor(updatedPlayer1.RD) == 40)
  assert(math.floor(updatedPlayer2.RD) == 105)
end 

establishedVersusNew()

local function orderDoesntMatter() 

  local player1 = Glicko2.g1(1500, 350)
  local player2 = Glicko2.g1(1500, 350)
  
  local player1Copy = player1:copy()
  local player2Copy = player2:copy()

  local updatedPlayer1, updatedPlayer2 = Glicko2.updatedRatings(player1, player2, {1, 1, 1, 0})
  
  local updatedPlayer1Copy, updatedPlayer2Copy = Glicko2.updatedRatings(player1Copy, player2Copy, {0, 1, 1, 1})

  assert(updatedPlayer1Copy.Rating == updatedPlayer1.Rating)
  assert(updatedPlayer2Copy.Rating == updatedPlayer2.Rating)
end 

orderDoesntMatter()

local function paperExample() 

  local player1 = Glicko2.g1(1500, 200)
  local player2 = Glicko2.g1(1400, 30)
  local player3 = Glicko2.g1(1550, 100)
  local player4 = Glicko2.g1(1700, 300)

  local player1Results = {}
  player1Results[#player1Results+1] = player2:score(1)
  player1Results[#player1Results+1] = player3:score(0)
  player1Results[#player1Results+1] = player4:score(0)

  local updatedPlayer1 = player1:update(player1Results)

  assert(math.round(updatedPlayer1.Rating, 2) == 1464.05)
  assert(math.round(updatedPlayer1.RD, 2) == 151.52)
  assert(math.round(updatedPlayer1.Vol, 2) == 0.06)
end 

paperExample()

