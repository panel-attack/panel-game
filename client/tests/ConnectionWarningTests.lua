local ConnectionWarning = require("client.src.ui.ConnectionWarning")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@type table<PublicPlayerID, PingSummary>
local pings = {}

local function pingOf(publicId)
  return pings[publicId]
end

local FINE = {current = 40, average = 38, jitter = 3}
local SLOW = {current = 1500, average = 1400, jitter = 40}

-- A warning whose card starts at x 100, y 100, watching Ann (1) and Ben (2) unless other players are given
---@param players ConnectionWarningPlayer[]?
---@return ConnectionWarning
local function warningFor(players)
  return ConnectionWarning({
    x = 100,
    y = 100,
    players = players or {{publicId = 1, name = "Ann"}, {publicId = 2, name = "Ben"}},
    pingOf = pingOf,
  })
end

local function testNoWarningWhileEveryConnectionIsFast()
  pings = {[1] = FINE, [2] = FINE}

  assert(not warningFor():isWarning(), "fast connections everywhere should show no warning")
end

testNoWarningWhileEveryConnectionIsFast()

local function testAConnectionWhereRollbackIsOnlyPossibleDoesNotWarn()
  pings = {[1] = FINE, [2] = {current = 800, average = 700, jitter = 50}}

  assert(not warningFor():isWarning(), "Ben at 700 ms ±50 stays under a second, which is no reason to warn")
end

testAConnectionWhereRollbackIsOnlyPossibleDoesNotWarn()

local function testEitherPlayersSlowConnectionWarns()
  pings = {[1] = FINE, [2] = SLOW}
  assert(warningFor():isWarning(), "Ben's slow connection should warn")

  pings = {[1] = SLOW, [2] = FINE}
  assert(warningFor():isWarning(), "Ann's slow connection should warn the same way")
end

testEitherPlayersSlowConnectionWarns()

local function testNoWarningWhileThePingIsUnknown()
  pings = {}

  assert(not warningFor():isWarning(), "an unmeasured connection is no reason to warn")
end

testNoWarningWhileThePingIsUnknown()

local function testRollbackIsLikelyOnceTheAveragePlusFourJittersPassesOneSecond()
  local expected = {
    {0, 0, false}, {1000, 0, false}, {1001, 0, true}, {800, 50, false}, {800, 51, true}, {200, 300, true},
  }
  for _, case in ipairs(expected) do
    local likely = ConnectionWarning.rollbackLikely({average = case[1], jitter = case[2]})
    assert(likely == case[3], case[1] .. " ms ±" .. case[2] .. " should " .. (case[3] and "" or "not ") .. "make rollback likely")
  end
  assert(ConnectionWarning.rollbackLikely(nil) == false, "an unmeasured player makes no rollback likely")
end

testRollbackIsLikelyOnceTheAveragePlusFourJittersPassesOneSecond()

local function testTheRollbackThresholdFollowsHowLongGarbageWaitsToLand()
  local landTime = GARBAGE_DELAY_LAND_TIME
  GARBAGE_DELAY_LAND_TIME = 90

  local slowerThanBefore = ConnectionWarning.rollbackLikely({average = 1400, jitter = 0})
  local pastTheNewDelay = ConnectionWarning.rollbackLikely({average = 1501, jitter = 0})

  GARBAGE_DELAY_LAND_TIME = landTime
  assert(not slowerThanBefore, "with garbage waiting 1.5 seconds to land, 1400 ms should not make rollback likely")
  assert(pastTheNewDelay, "with garbage waiting 1.5 seconds to land, 1501 ms should make rollback likely")
end

testTheRollbackThresholdFollowsHowLongGarbageWaitsToLand()

local function testTheIconIsTheThemesConnectionWarning()
  assert(warningFor().icon.image == GAME.theme.images.IMG_connectionWarning, "the icon should be the theme's image for a bad connection")
end

testTheIconIsTheThemesConnectionWarning()

local function testTheIconShowsOnlyWhileWarning()
  pings = {[1] = FINE, [2] = FINE}
  local warning = warningFor()

  warning:refresh()
  assert(not warning.icon.isVisible, "no icon while every connection is fine")
  pings[2] = SLOW
  warning:refresh()
  assert(warning.icon.isVisible, "the icon should show once rollback is likely")
end

testTheIconShowsOnlyWhileWarning()

local function testTheIconSitsCentredAtTheTopOfTheCard()
  pings = {[1] = FINE, [2] = SLOW}
  local warning = warningFor()

  warning:refresh()

  local iconX, iconY = warning.icon:getScreenPos()
  assert(math.abs(iconX + warning.icon.width / 2 - (100 + warning.width / 2)) <= 1, "the icon should be centred in the card")
  assert(iconY == 100 + ConnectionWarning.PADDING, "the icon should sit a padding below the card's top, at y " .. iconY)
  local lines = #warning:detailLines()
  local lineHeight = GraphicsUtil.getGlobalFont():getHeight()
  assert(warning.height >= ConnectionWarning.PADDING + ConnectionWarning.ICON_SIZE + lines * lineHeight,
    "the card should hold the icon and every line below it, but is " .. warning.height .. " tall")
end

testTheIconSitsCentredAtTheTopOfTheCard()

local function testTheLinesGiveEachPlayersCurrentAndAveragePing()
  pings = {[1] = {current = 900, average = 700, jitter = 90}, [2] = FINE}

  local lines = warningFor():detailLines()

  local expected = {"Ann 900 ms - 700 ms avg", "Ben 40 ms - 38 ms avg"}
  assert(#lines == #expected, "expected " .. #expected .. " lines, got " .. table.concat(lines, " | "))
  for i, line in ipairs(expected) do
    assert(lines[i] == line, "line " .. i .. " should be '" .. line .. "', got '" .. tostring(lines[i]) .. "'")
  end
end

testTheLinesGiveEachPlayersCurrentAndAveragePing()

local function testTheLineOfAnUnmeasuredPlayerSaysTheyAreBeingMeasured()
  pings = {}

  local lines = warningFor({{publicId = 1, name = "Ann"}}):detailLines()

  assert(#lines == 1 and lines[1] == "Ann measuring", "got " .. table.concat(lines, " | "))
end

testTheLineOfAnUnmeasuredPlayerSaysTheyAreBeingMeasured()

local function testTheCardIsSizedToItsLines()
  pings = {[1] = SLOW, [2] = SLOW}
  local warning = warningFor()

  warning:refresh()
  local twoPlayers = warning.height
  warning.players = {{publicId = 1, name = "Ann"}}
  warning:refresh()

  assert(warning.width > ConnectionWarning.ICON_SIZE and twoPlayers > warning.height,
    "two players' lines should make a taller card than one player's")
end

testTheCardIsSizedToItsLines()

local function testTheCardOnlyRebuildsItsLinesWhenAPingChanges()
  pings = {[1] = SLOW, [2] = FINE}
  local warning = warningFor()
  local builds = 0
  local detailLines = warning.detailLines
  warning.detailLines = function(self)
    builds = builds + 1
    return detailLines(self)
  end

  warning:refresh()
  warning:refresh()
  assert(builds == 0, "the pings haven't changed since the card was made, so its lines should be reused, built " .. builds .. " times")
  pings[2] = {current = 50, average = 45, jitter = 4}
  warning:refresh()
  assert(builds == 1, "a new ping update should rebuild the lines once, built " .. builds .. " times")
end

testTheCardOnlyRebuildsItsLinesWhenAPingChanges()
