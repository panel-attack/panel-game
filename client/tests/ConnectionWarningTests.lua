local ConnectionWarning = require("client.src.ui.ConnectionWarning")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local UiElement = require("client.src.ui.UIElement")

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

local function testTheCardIsTwoGridCellsWideAndOneTallUnlessItFills()
  pings = {[1] = SLOW, [2] = FINE}
  local warning = warningFor()

  warning:refresh()

  assert(warning.width == ConnectionWarning.WIDTH and warning.height == ConnectionWarning.HEIGHT,
    "the card should be " .. ConnectionWarning.WIDTH .. "x" .. ConnectionWarning.HEIGHT .. ", not " .. warning.width .. "x" .. warning.height)
  assert(ConnectionWarning.WIDTH == 184 and ConnectionWarning.HEIGHT == 84, "the card should match a 2x1 element of the room's 100 unit grid with 8 margins")
end

testTheCardIsTwoGridCellsWideAndOneTallUnlessItFills()

local function testAFillingCardTakesTheSizeOfWhatItIsIn()
  pings = {[1] = FINE, [2] = SLOW}
  local cell = UiElement({x = 100, y = 100, width = 200, height = 90})
  local warning = ConnectionWarning({players = {{publicId = 1, name = "Ann"}, {publicId = 2, name = "Ben"}}, pingOf = pingOf, hFill = true, vFill = true})
  cell:addChild(warning)

  warning:refresh()

  assert(warning.width == 200 and warning.height == 90, "the card should fill its 200x90 cell, not " .. warning.width .. "x" .. warning.height)
end

testAFillingCardTakesTheSizeOfWhatItIsIn()

local function testEachPlayersRowHoldsTheirAveragePing()
  pings = {[1] = {current = 900, average = 700, jitter = 90}, [2] = FINE}

  local rows = warningFor():buildRows()

  assert(#rows == 2, "expected a row per player, got " .. #rows)
  assert(rows[1].name == "Ann" and rows[1].ping == "700 ms", "Ann's row should read Ann, 700 ms, got " .. tostring(rows[1].name) .. ", " .. tostring(rows[1].ping))
  assert(rows[2].ping == "38 ms", "Ben's row should read 38 ms, got " .. tostring(rows[2].ping))
end

testEachPlayersRowHoldsTheirAveragePing()

local function testATwelveCharacterNameBesideASlowPingFitsWholeInJapanese()
  local language = Localization:getCurrentLanguageCode()
  GAME:setLanguage("JP")
  pings = {[1] = SLOW}

  local warning = warningFor({{publicId = 1, name = "JpGuestName1"}})
  local row = warning:buildRows()[1]
  local fullWidth = GraphicsUtil.getGlobalFontWithSize(GraphicsUtil.fontSize - 1):getWidth("JpGuestName1")

  GAME:setLanguage(language)
  assert(row.name == "JpGuestName1", "the name should fit whole, got " .. row.name .. ": it is " .. fullWidth .. " wide in "
    .. warning:nameRoom() .. " of room beside a " .. warning.pingColumnWidth .. " wide ping")
end

testATwelveCharacterNameBesideASlowPingFitsWholeInJapanese()

local function testAnUnmeasuredPlayersPingIsBlank()
  pings = {}

  local row = warningFor({{publicId = 1, name = "Ann"}}):buildRows()[1]

  assert(row.name == "Ann" and row.ping == "", "Ann's row should hold her name and no ping yet, got '" .. tostring(row.ping) .. "'")
end

testAnUnmeasuredPlayersPingIsBlank()

local function testTheRowOfAPlayerWhoseConnectionMakesRollbackLikelyIsMarkedSlow()
  pings = {[1] = FINE, [2] = SLOW}

  local rows = warningFor():buildRows()

  assert(not rows[1].slow and rows[2].slow, "only Ben's row should be marked slow")
end

testTheRowOfAPlayerWhoseConnectionMakesRollbackLikelyIsMarkedSlow()

local function testASlowPlayersPingIsTheWarningsYellow()
  pings = {[1] = FINE, [2] = SLOW}

  local rows = warningFor():buildRows()

  assert(ConnectionWarning.pingColor(rows[2]) == ConnectionWarning.WARNING_COLOR, "Ben's slow ping should be the warning's yellow")
  assert(ConnectionWarning.pingColor(rows[1]) ~= ConnectionWarning.WARNING_COLOR, "Ann's fine ping should not")
end

testASlowPlayersPingIsTheWarningsYellow()

local function testALongNameIsShortenedToLeaveRoomForThePing()
  pings = {[1] = SLOW}
  local warning = warningFor({{publicId = 1, name = "WWWWWWWWWWWWWWWW"}})

  local row = warning:buildRows()[1]

  local nameWidth = GraphicsUtil.getGlobalFontWithSize(GraphicsUtil.fontSize - 1):getWidth(row.name)
  assert(row.name:sub(-3) == "...", "a name too wide for the card should end in ..., got " .. row.name)
  assert(nameWidth <= warning:nameRoom(), "the shortened name is " .. nameWidth .. " wide, more than its " .. warning:nameRoom())
end

testALongNameIsShortenedToLeaveRoomForThePing()

local function testTheWarningRowSitsBelowThePlayersAndInsideTheCard()
  pings = {[1] = FINE, [2] = SLOW}
  local warning = warningFor()

  warning:refresh()

  local layout = warning:layout()
  assert(layout.warningTop >= layout.rowTops[#layout.rowTops] + layout.rowHeight, "the warning should sit below the last player's row")
  assert(layout.warningTop + layout.warningHeight <= warning.height, "the warning row should end inside the card, at "
    .. layout.warningTop + layout.warningHeight .. " of " .. warning.height)
  local _, iconY = warning.icon:getScreenPos()
  assert(iconY - 100 >= layout.warningTop, "the icon should be in the warning row")
end

testTheWarningRowSitsBelowThePlayersAndInsideTheCard()

local function testTheWarningSaysRollbackIsLikely()
  assert(ConnectionWarning.warningText() == loc("ss_rollback_likely"), "the warning should come from the localization")
  assert(ConnectionWarning.warningText() == "Rollback likely", "got " .. ConnectionWarning.warningText())
end

testTheWarningSaysRollbackIsLikely()

local function testTheCardOnlyRebuildsItsRowsWhenAPingChanges()
  pings = {[1] = SLOW, [2] = FINE}
  local warning = warningFor()
  local builds = 0
  local buildRows = warning.buildRows
  warning.buildRows = function(self)
    builds = builds + 1
    return buildRows(self)
  end

  warning:refresh()
  warning:refresh()
  assert(builds == 0, "the pings haven't changed since the card was made, so its rows should be reused, built " .. builds .. " times")
  pings[2] = {current = 50, average = 45, jitter = 4}
  warning:refresh()
  assert(builds == 1, "a new ping update should rebuild the rows once, built " .. builds .. " times")
end

testTheCardOnlyRebuildsItsRowsWhenAPingChanges()

local function testAWarningOnlyCardIsHiddenWhileEveryConnectionIsFine()
  pings = {[1] = FINE, [2] = FINE}
  local warning = warningFor()

  warning:refresh()

  assert(not warning:isShown(), "a card that only warns should stay hidden while every connection is fine")
end

testAWarningOnlyCardIsHiddenWhileEveryConnectionIsFine()

local function testAnAlwaysShownCardShowsThePingsWithoutTheIconWhileConnectionsAreFine()
  pings = {[1] = FINE, [2] = FINE}
  local warning = ConnectionWarning({x = 100, y = 100, players = {{publicId = 1, name = "Ann"}}, pingOf = pingOf, alwaysShown = true})

  warning:refresh()

  assert(warning:isShown(), "an always shown card should show while every connection is fine")
  assert(not warning.icon.isVisible, "without a warning there should be no warning icon")
  assert(warning.rows[1].ping == "38 ms", "the card should list the pings, got " .. tostring(warning.rows[1].ping))
end

testAnAlwaysShownCardShowsThePingsWithoutTheIconWhileConnectionsAreFine()

local function testTheCardIsTitledNetworkLatency()
  assert(ConnectionWarning.title() == loc("ss_network_latency"), "the title should come from the localization")
  assert(ConnectionWarning.title() == "Network Latency", "the English title should be 'Network Latency', got " .. ConnectionWarning.title())
end

testTheCardIsTitledNetworkLatency()

local function testEveryLanguageTranslatesTheCardsText()
  for _, code in ipairs(Localization.codes) do
    for _, key in ipairs({"ss_network_latency", "ss_ping_average", "ss_rollback_likely"}) do
      local text = Localization.data[code][key]
      assert(text and text ~= "", code .. " should translate " .. key)
    end
  end
end

testEveryLanguageTranslatesTheCardsText()
