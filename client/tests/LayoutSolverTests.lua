local LayoutSolver = require("client.src.ui.LayoutSolver")
local Layout = require("client.src.ui.Layout")
local logger = require("common.lib.logger")

local fixed, grow, fit = Layout.fixed, Layout.grow, Layout.fit
local GROW = Layout.GROW

-- Returns a plain layout node with the given rules and children
local function node(rules, children)
  return {layoutRules = rules, children = children or {}}
end

-- Returns a node of a fixed size, with any other rules given
local function box(width, height, rules)
  rules = rules or {}
  rules.sizing = Layout.fixedSize(width, height)
  return node(rules)
end

-- Returns a node whose content is text of the given words, each wordWidth wide and lineHeight high, wrapping at spaces
local function textNode(rules, wordCount, wordWidth, lineHeight)
  local text = node(rules)
  function text:measureContentWidth()
    return wordCount * wordWidth, wordWidth
  end
  function text:measureContentHeight(width)
    local wordsPerLine = math.max(1, math.floor(width / wordWidth))
    return math.ceil(wordCount / wordsPerLine) * lineHeight
  end
  return text
end

-- The canvas scales the game draws at: one point is 1, 1.5, 2, 2.5 or 3 screen pixels
local CANVAS_SCALES = {1, 1.5, 2, 2.5, 3}
-- The width of the Mod Management title in points at a scale of 1.5, where it is 209 pixels wide
local TITLE_WIDTH = 209 / 1.5

-- Returns a node of text the given width in points, rounded to the whole pixels a font at the scale measures it in
local function measuredTextNode(rules, width, scale)
  local text = node(rules)
  local measured = math.round(width * scale) / scale
  function text:measureContentWidth()
    return measured, measured
  end
  function text:measureContentHeight()
    return 20
  end
  return text
end

-- Fails unless every position under the node is a whole number of pixels at every canvas scale
local function assertOnThePixelGrid(parent, name)
  for _, child in ipairs(parent.children) do
    for _, scale in ipairs(CANVAS_SCALES) do
      local x, y = child.layoutRect.x * scale, child.layoutRect.y * scale
      assert(x == math.floor(x) and y == math.floor(y),
             string.format("%s: a child at %s,%s is off the pixel grid at scale %s", name, child.layoutRect.x, child.layoutRect.y, scale))
    end
    assertOnThePixelGrid(child, name)
  end
end

-- Fails unless the element's center is within a point of the given one
local function assertCenteredWithinAPoint(element, centerX, name)
  local rect = element.layoutRect
  local actual = rect.x + rect.width / 2
  assert(math.abs(actual - centerX) <= 1, string.format("%s: centered at %s, not within a point of %s", name, actual, centerX))
end

local function assertRect(element, x, y, width, height, name)
  local rect = element.layoutRect
  assert(rect.x == x and rect.y == y and rect.width == width and rect.height == height,
         string.format("%s: expected %s,%s %sx%s but got %s,%s %sx%s", name, x, y, width, height, rect.x, rect.y, rect.width, rect.height))
end

-- pass 1: fit widths

local function testRowFitsTheSumOfItsChildrenPlusGapsAndPadding()
  local root = node({padding = Layout.padding(10), childGap = 4}, {box(30, 10), box(50, 10)})
  LayoutSolver.solve(root)
  assert(root.layoutRect.width == 10 + 30 + 4 + 50 + 10, "width " .. root.layoutRect.width)
  logger.trace("passed test testRowFitsTheSumOfItsChildrenPlusGapsAndPadding")
end

local function testColumnFitsItsWidestChild()
  local root = node({layoutDirection = "topToBottom", padding = Layout.padding(5)}, {box(30, 10), box(50, 10)})
  LayoutSolver.solve(root)
  assert(root.layoutRect.width == 60, "width " .. root.layoutRect.width)
  logger.trace("passed test testColumnFitsItsWidestChild")
end

local function testFitTakesTheNaturalWidthOfContent()
  local root = node({}, {textNode({}, 3, 20, 10)})
  LayoutSolver.solve(root)
  assert(root.layoutRect.width == 60, "width " .. root.layoutRect.width)
  logger.trace("passed test testFitTakesTheNaturalWidthOfContent")
end

local function testFitIsCappedByItsMax()
  local root = node({sizing = {horizontal = fit(nil, 40)}}, {box(30, 10), box(50, 10)})
  LayoutSolver.solve(root)
  assert(root.layoutRect.width == 40, "width " .. root.layoutRect.width)
  logger.trace("passed test testFitIsCappedByItsMax")
end

local function testFixedIgnoresItsContent()
  local text = textNode({sizing = {horizontal = fixed(24)}}, 3, 20, 10)
  local root = node({}, {text, box(50, 10)})
  LayoutSolver.solve(root)
  assert(text.layoutRect.width == 24 and root.layoutRect.width == 74, "widths " .. text.layoutRect.width .. " " .. root.layoutRect.width)
  logger.trace("passed test testFixedIgnoresItsContent")
end

-- pass 2: grow and shrink widths

local function testGrowChildTakesTheSpaceLeft()
  local label = node({sizing = {horizontal = GROW, vertical = fixed(10)}})
  local switch = box(52, 24)
  local root = node({sizing = {horizontal = fixed(300)}, padding = Layout.padding(12), childGap = 8}, {label, switch})
  LayoutSolver.solve(root)
  assert(label.layoutRect.width == 300 - 12 - 8 - 52 - 12, "label width " .. label.layoutRect.width)
  logger.trace("passed test testGrowChildTakesTheSpaceLeft")
end

local function testSmallestGrowChildGrowsFirst()
  local small = node({sizing = {horizontal = grow(10), vertical = fixed(10)}})
  local large = node({sizing = {horizontal = grow(50), vertical = fixed(10)}})
  local root = node({sizing = {horizontal = fixed(70)}}, {small, large})
  LayoutSolver.solve(root)
  assert(small.layoutRect.width == 20 and large.layoutRect.width == 50,
    "widths " .. small.layoutRect.width .. " " .. large.layoutRect.width)
  root.layoutRules.sizing.horizontal = fixed(200)
  LayoutSolver.solve(root)
  assert(small.layoutRect.width == 100 and large.layoutRect.width == 100,
    "widths " .. small.layoutRect.width .. " " .. large.layoutRect.width)
  logger.trace("passed test testSmallestGrowChildGrowsFirst")
end

local function testGrowStopsAtItsMax()
  local capped = node({sizing = {horizontal = grow(nil, 30), vertical = fixed(10)}})
  local free = node({sizing = {horizontal = GROW, vertical = fixed(10)}})
  local root = node({sizing = {horizontal = fixed(200)}}, {capped, free})
  LayoutSolver.solve(root)
  assert(capped.layoutRect.width == 30 and free.layoutRect.width == 170,
    "widths " .. capped.layoutRect.width .. " " .. free.layoutRect.width)
  logger.trace("passed test testGrowStopsAtItsMax")
end

local function testLargestChildShrinksFirstAndFixedDoesNotShrink()
  local fixedChild = box(40, 10)
  local wide = textNode({}, 10, 10, 10)
  local narrow = textNode({}, 3, 10, 10)
  local root = node({sizing = {horizontal = fixed(110)}}, {fixedChild, wide, narrow})
  LayoutSolver.solve(root)
  assert(fixedChild.layoutRect.width == 40, "fixed width " .. fixedChild.layoutRect.width)
  assert(wide.layoutRect.width == 40 and narrow.layoutRect.width == 30,
    "widths " .. wide.layoutRect.width .. " " .. narrow.layoutRect.width)
  logger.trace("passed test testLargestChildShrinksFirstAndFixedDoesNotShrink")
end

local function testTextStopsShrinkingAtItsLongestWord()
  local text = textNode({}, 5, 30, 10)
  local root = node({sizing = {horizontal = fixed(10)}}, {text})
  LayoutSolver.solve(root)
  assert(text.layoutRect.width == 30, "width " .. text.layoutRect.width)
  logger.trace("passed test testTextStopsShrinkingAtItsLongestWord")
end

local function testAMinBelowItsContentLetsAChildShrinkPastIt()
  local text = textNode({sizing = {horizontal = grow(0)}}, 1, 150, 10)
  local root = node({sizing = {horizontal = fixed(100)}}, {text, box(40, 10)})
  LayoutSolver.solve(root)
  assert(text.layoutRect.width == 60, "width " .. text.layoutRect.width)
  logger.trace("passed test testAMinBelowItsContentLetsAChildShrinkPastIt")
end

local function testGrowAcrossTheFlowTakesTheInnerSize()
  local child = node({sizing = {horizontal = GROW, vertical = fixed(10)}})
  local root = node({layoutDirection = "topToBottom", sizing = {horizontal = fixed(100)}, padding = Layout.padding(10)}, {child})
  LayoutSolver.solve(root)
  assert(child.layoutRect.width == 80, "width " .. child.layoutRect.width)
  logger.trace("passed test testGrowAcrossTheFlowTakesTheInnerSize")
end

-- pass 3: wrap text

local function testTextWrapsToTheWidthItWasGiven()
  local text = textNode({sizing = {horizontal = GROW}}, 6, 20, 10)
  local root = node({sizing = {horizontal = fixed(60)}}, {text})
  LayoutSolver.solve(root)
  assert(text.layoutRect.height == 20, "height " .. text.layoutRect.height)
  assert(root.layoutRect.height == 20, "parent height " .. root.layoutRect.height)
  logger.trace("passed test testTextWrapsToTheWidthItWasGiven")
end

-- pass 4: fit, grow and shrink heights

local function testColumnFitsTheSumOfItsChildrenHeights()
  local root = node({layoutDirection = "topToBottom", padding = Layout.padding(2), childGap = 4}, {box(10, 10), box(10, 20)})
  LayoutSolver.solve(root)
  assert(root.layoutRect.height == 2 + 10 + 4 + 20 + 2, "height " .. root.layoutRect.height)
  logger.trace("passed test testColumnFitsTheSumOfItsChildrenHeights")
end

local function testGrowHeightInARowTakesTheTallestChildsHeight()
  local stretched = node({sizing = {horizontal = fixed(10), vertical = GROW}})
  local root = node({}, {box(10, 40), stretched})
  LayoutSolver.solve(root)
  assert(stretched.layoutRect.height == 40, "height " .. stretched.layoutRect.height)
  logger.trace("passed test testGrowHeightInARowTakesTheTallestChildsHeight")
end

local function testGrowHeightInAColumnTakesTheSpaceLeft()
  local body = node({sizing = {horizontal = fixed(10), vertical = GROW}})
  local root = node({layoutDirection = "topToBottom", sizing = {vertical = fixed(100)}}, {box(10, 30), body})
  LayoutSolver.solve(root)
  assert(body.layoutRect.height == 70, "height " .. body.layoutRect.height)
  logger.trace("passed test testGrowHeightInAColumnTakesTheSpaceLeft")
end

-- pass 5: positions and alignment

local function testRowPlacesChildrenAfterEachOther()
  local first = box(30, 10)
  local second = box(50, 10)
  local root = node({padding = Layout.padding(10), childGap = 4}, {first, second})
  LayoutSolver.solve(root)
  assertRect(first, 10, 10, 30, 10, "first")
  assertRect(second, 44, 10, 50, 10, "second")
  logger.trace("passed test testRowPlacesChildrenAfterEachOther")
end

local function testUnevenPaddingPlacesChildrenFromEachSide()
  local child = box(10, 10)
  local root = node({sizing = Layout.fixedSize(50, 50), padding = {left = 4, right = 8, top = 6, bottom = 2},
                     childAlignment = {x = "right", y = "bottom"}}, {child})
  LayoutSolver.solve(root)
  assertRect(child, 32, 38, 10, 10, "child")
  logger.trace("passed test testUnevenPaddingPlacesChildrenFromEachSide")
end

local function testAlignmentCentersAlongAndAcrossTheFlow()
  local first = box(20, 10)
  local second = box(20, 30)
  local root = node({sizing = Layout.fixedSize(100, 50), childAlignment = {x = "center", y = "bottom"}}, {first, second})
  LayoutSolver.solve(root)
  assertRect(first, 30, 40, 20, 10, "first")
  assertRect(second, 50, 20, 20, 30, "second")
  logger.trace("passed test testAlignmentCentersAlongAndAcrossTheFlow")
end

local function testFlowSnapsChildrenToEvenPointsWithoutDrift()
  local second, third, fourth = box(10.5, 10), box(10.5, 10), box(10.5, 10)
  local root = node({sizing = Layout.fixedSize(100, 10)}, {box(10.5, 10), second, third, fourth})
  LayoutSolver.solve(root)
  assert(second.layoutRect.x == 10 and third.layoutRect.x == 22 and fourth.layoutRect.x == 32,
         "children at " .. second.layoutRect.x .. ", " .. third.layoutRect.x .. ", " .. fourth.layoutRect.x)
  logger.trace("passed test testFlowSnapsChildrenToEvenPointsWithoutDrift")
end

local function testTextKeepsItsWidthWhereverItsEdgesAreRounded()
  for _, offset in ipairs({0, 0.5, 1, 1.5, 2, 3}) do
    local text = node({})
    function text:measureContentWidth()
      return 132.67, 132.67
    end
    local root = node({padding = {left = offset}}, {text})
    LayoutSolver.solve(root)
    assert(text.layoutRect.width >= 132.67,
           string.format("offset %s: text 132.67 wide was given %s, so it wraps", offset, text.layoutRect.width))
  end
  logger.trace("passed test testTextKeepsItsWidthWhereverItsEdgesAreRounded")
end

local function testGrownSiblingsMeetEdgeToEdgeOnEvenPoints()
  local first, second, third = node({sizing = {horizontal = GROW}}), node({sizing = {horizontal = GROW}}), node({sizing = {horizontal = GROW}})
  local root = node({sizing = Layout.fixedSize(1280, 10)}, {first, second, third})
  LayoutSolver.solve(root)
  for i, child in ipairs({first, second, third}) do
    local rect = child.layoutRect
    assert(rect.x % 2 == 0 and (rect.x + rect.width) % 2 == 0, string.format("child %d spans %s to %s", i, rect.x, rect.x + rect.width))
  end
  assert(first.layoutRect.x + first.layoutRect.width == second.layoutRect.x, "the first ends where the second starts")
  assert(second.layoutRect.x + second.layoutRect.width == third.layoutRect.x, "the second ends where the third starts")
  assert(third.layoutRect.x + third.layoutRect.width == 1280, "the last ends at the row's end")
  logger.trace("passed test testGrownSiblingsMeetEdgeToEdgeOnEvenPoints")
end

local function testCenteredTextLandsOnThePixelGridAtEveryScale()
  for _, scale in ipairs(CANVAS_SCALES) do
    local title = measuredTextNode({}, TITLE_WIDTH, scale)
    local root = node({sizing = Layout.fixedSize(1280, 721), childAlignment = Layout.CENTER}, {title})
    LayoutSolver.solve(root)
    assertOnThePixelGrid(root, "scale " .. scale)
    assertCenteredWithinAPoint(title, 640, "scale " .. scale)
  end
  logger.trace("passed test testCenteredTextLandsOnThePixelGridAtEveryScale")
end

local function testAChildAfterTextLandsOnThePixelGridAtEveryScale()
  for _, scale in ipairs(CANVAS_SCALES) do
    local root = node({childGap = 4}, {measuredTextNode({}, TITLE_WIDTH, scale), box(30, 10)})
    LayoutSolver.solve(root)
    assertOnThePixelGrid(root, "scale " .. scale)
  end
  logger.trace("passed test testAChildAfterTextLandsOnThePixelGridAtEveryScale")
end

local function testTextAlignedAcrossTheFlowLandsOnThePixelGridAtEveryScale()
  for _, scale in ipairs(CANVAS_SCALES) do
    local title = measuredTextNode({}, TITLE_WIDTH, scale)
    local root = node({layoutDirection = "topToBottom", sizing = {horizontal = fixed(1280)}, padding = Layout.padding(5),
                       childAlignment = Layout.CENTER_HORIZONTALLY}, {title})
    LayoutSolver.solve(root)
    assertOnThePixelGrid(root, "scale " .. scale)
    assertCenteredWithinAPoint(title, 640, "scale " .. scale)
  end
  logger.trace("passed test testTextAlignedAcrossTheFlowLandsOnThePixelGridAtEveryScale")
end

local function testNestedTextEndsWithinAPointOfItsPaddingAtEveryScale()
  for _, scale in ipairs(CANVAS_SCALES) do
    local text = measuredTextNode({}, TITLE_WIDTH, scale)
    local hint = node({childGap = 7}, {box(54, 28), text})
    local root = node({sizing = Layout.fixedSize(1280, 48), childAlignment = {x = "right"}, padding = {right = 36}}, {hint})
    LayoutSolver.solve(root)
    assertOnThePixelGrid(root, "scale " .. scale)
    local right = hint.layoutRect.x + text.layoutRect.x + text.layoutRect.width
    assert(math.abs(right - (1280 - 36)) <= 1,
           string.format("scale %s: the text ends at %s, not within a point of %s", scale, right, 1280 - 36))
  end
  logger.trace("passed test testNestedTextEndsWithinAPointOfItsPaddingAtEveryScale")
end

local function testColumnPlacesChildrenBelowEachOther()
  local first = box(30, 10)
  local second = box(50, 20)
  local root = node({layoutDirection = "topToBottom", childGap = 5, childAlignment = {x = "right"}}, {first, second})
  LayoutSolver.solve(root)
  assertRect(first, 20, 0, 30, 10, "first")
  assertRect(second, 0, 16, 50, 20, "second")
  logger.trace("passed test testColumnPlacesChildrenBelowEachOther")
end

-- pass 6: floating elements

local function testFloatingElementPinsToItsParentAndTakesNoRoom()
  local inFlow = box(30, 10)
  local badge = box(8, 8, {floating = {attachTo = "parent", attachPoints = {element = "centerCenter", parent = "rightTop"},
                                       offset = {x = 2, y = 2}}})
  local root = node({sizing = Layout.fixedSize(100, 40)}, {inFlow, badge})
  LayoutSolver.solve(root)
  assertRect(inFlow, 0, 0, 30, 10, "in flow")
  assertRect(badge, 98, -2, 8, 8, "badge")
  logger.trace("passed test testFloatingElementPinsToItsParentAndTakesNoRoom")
end

local function testFloatingElementPinsToAnElementById()
  local target = box(20, 10, {id = "target"})
  local cursor = box(24, 14, {floating = {attachTo = "element", parentId = "target",
                                          attachPoints = {element = "centerCenter", parent = "centerCenter"}}})
  local root = node({padding = Layout.padding(5), childGap = 5}, {box(30, 10), target, cursor})
  LayoutSolver.solve(root)
  assertRect(cursor, 38, 4, 24, 14, "cursor")
  logger.trace("passed test testFloatingElementPinsToAnElementById")
end

local function testTextFloatingAtTheTopOfTheScreenLandsOnThePixelGridAtEveryScale()
  for _, scale in ipairs(CANVAS_SCALES) do
    local title = measuredTextNode({floating = {attachTo = "parent", attachPoints = {element = "centerTop", parent = "centerTop"},
                                                offset = {y = 30}}}, TITLE_WIDTH, scale)
    local root = node({sizing = Layout.fixedSize(1280, 720)}, {title})
    LayoutSolver.solve(root)
    assertOnThePixelGrid(root, "scale " .. scale)
    assertCenteredWithinAPoint(title, 640, "scale " .. scale)
  end
  logger.trace("passed test testTextFloatingAtTheTopOfTheScreenLandsOnThePixelGridAtEveryScale")
end

local function testAnElementPinnedToAFloatingOneIsWithinAPointOfWhereItBelongs()
  local back = box(46, 46, {id = "back", floating = {attachTo = "parent",
                                                     attachPoints = {element = "leftCenter", parent = "leftCenter"}}})
  local crumb = box(30, 16, {floating = {attachTo = "element", parentId = "back",
                                         attachPoints = {element = "leftCenter", parent = "rightCenter"}}})
  local root = node({sizing = Layout.fixedSize(1200, 52)}, {back, crumb})
  LayoutSolver.solve(root)
  assertOnThePixelGrid(root, "top bar")
  local center = crumb.layoutRect.y + crumb.layoutRect.height / 2
  assert(math.abs(center - 26) <= 1, "the crumb is centered at " .. center .. ", not within a point of 26")
  logger.trace("passed test testAnElementPinnedToAFloatingOneIsWithinAPointOfWhereItBelongs")
end

local function testPinningToAnElementPlacedLaterIsAnError()
  local early = box(10, 10, {floating = {attachTo = "element", parentId = "late"}})
  local late = box(10, 10, {id = "late", floating = {attachTo = "parent"}})
  local ok, err = pcall(LayoutSolver.solve, node({sizing = Layout.fixedSize(100, 100)}, {early, late}))
  assert(not ok and tostring(err):find("late is attached to after it"), "solving gave " .. tostring(err))
  logger.trace("passed test testPinningToAnElementPlacedLaterIsAnError")
end

local function testFloatingGrowElementTakesTheFullSizeOfWhatItIsPinnedTo()
  local overlay = node({sizing = {horizontal = GROW, vertical = GROW}, floating = {attachTo = "parent"}})
  local root = node({sizing = Layout.fixedSize(100, 50), padding = Layout.padding(5)}, {overlay})
  LayoutSolver.solve(root)
  assertRect(overlay, 0, 0, 100, 50, "overlay")
  logger.trace("passed test testFloatingGrowElementTakesTheFullSizeOfWhatItIsPinnedTo")
end

local function testFloatingGrowElementTakesTheSizeOfALaterSibling()
  local highlight = node({sizing = {horizontal = GROW, vertical = GROW}, floating = {attachTo = "element", parentId = "row"}})
  local row = node({id = "row", sizing = {horizontal = GROW, vertical = fixed(12)}})
  local root = node({layoutDirection = "topToBottom", sizing = {horizontal = fixed(80)}}, {highlight, row})
  LayoutSolver.solve(root)
  assertRect(highlight, 0, 0, 80, 12, "highlight")
  logger.trace("passed test testFloatingGrowElementTakesTheSizeOfALaterSibling")
end

local function testSolvingAgainReusesTheRects()
  local child = box(10, 10)
  local root = node({}, {child})
  LayoutSolver.solve(root)
  local rect = child.layoutRect
  LayoutSolver.solve(root)
  assert(child.layoutRect == rect, "the rect table is kept between solves")
  logger.trace("passed test testSolvingAgainReusesTheRects")
end

local function testAnOddFloatingOffsetIsRoundedOntoThePixelGrid()
  local badge = box(6, 6, {floating = {attachTo = "parent", attachPoints = {element = "rightCenter", parent = "rightCenter"},
                                       offset = {x = -5, y = 27.3}}})
  local root = node({sizing = Layout.fixedSize(50, 30)}, {badge})
  LayoutSolver.solve(root)
  assertOnThePixelGrid(root, "badge")
  assert(math.abs(badge.layoutRect.x - 39) <= 1 and math.abs(badge.layoutRect.y - 39.3) <= 1,
         "the badge is at " .. badge.layoutRect.x .. "," .. badge.layoutRect.y)
  logger.trace("passed test testAnOddFloatingOffsetIsRoundedOntoThePixelGrid")
end

-- clipping and scrolling

local function testAPartlyScrolledFlowStaysOnThePixelGrid()
  local item = node({sizing = Layout.fixedSize(30, 10), childAlignment = Layout.CENTER}, {box(12, 8)})
  local root = node({layoutDirection = "topToBottom", sizing = Layout.fixedSize(50, 30),
                     clip = {vertical = true, childOffset = {y = -3.5}}}, {box(20, 10), item})
  LayoutSolver.solve(root)
  assertOnThePixelGrid(root, "scrolled")
  assert(math.abs(item.layoutRect.y - 6.5) <= 1, "the item is at " .. item.layoutRect.y)
  logger.trace("passed test testAPartlyScrolledFlowStaysOnThePixelGrid")
end

local function testChildOffsetMovesTheFlowButNotFloatingChildren()
  local item = box(20, 10)
  local badge = box(6, 6, {floating = {attachTo = "parent", attachPoints = {element = "rightTop", parent = "rightTop"}}})
  local root = node({layoutDirection = "topToBottom", sizing = Layout.fixedSize(50, 30), padding = Layout.padding(2),
                     clip = {vertical = true, childOffset = {y = -12}}}, {box(20, 10), item, badge})
  LayoutSolver.solve(root)
  assertRect(item, 2, 0, 20, 10, "item")
  assertRect(badge, 44, 0, 6, 6, "badge")
  logger.trace("passed test testChildOffsetMovesTheFlowButNotFloatingChildren")
end

local function testClippedContentKeepsItsSizeAlongTheClip()
  local text = textNode({}, 6, 10, 8)
  local root = node({sizing = Layout.fixedSize(20, 10), clip = {horizontal = true}}, {text})
  LayoutSolver.solve(root)
  assertRect(text, 0, 0, 60, 8, "text")
  logger.trace("passed test testClippedContentKeepsItsSizeAlongTheClip")
end

local function testAGrowingClippedElementTakesTheSpaceItIsGivenNotItsContentsSize()
  local list = node({layoutDirection = "topToBottom", sizing = {horizontal = fixed(100), vertical = GROW}, clip = {vertical = true}},
                    {box(20, 1089)})
  local root = node({sizing = Layout.fixedSize(100, 720)}, {list})
  LayoutSolver.solve(root)
  assert(list.layoutRect.height == 720, "the clipped element is " .. list.layoutRect.height .. " high")
  logger.trace("passed test testAGrowingClippedElementTakesTheSpaceItIsGivenNotItsContentsSize")
end

local function testANodeKeepsAChildInViewFromWhereTheFlowPutIt()
  local target = box(20, 10)
  local list = node({layoutDirection = "topToBottom", sizing = Layout.fixedSize(50, 20), clip = {vertical = true}},
                    {box(20, 10), box(20, 10), target})
  function list:getChildOffset(axis)
    if axis == LayoutSolver.Y_AXIS then
      local rect = target.layoutRect
      return math.min(0, self.layoutRect.height - (rect.y + rect.height))
    end
    return 0
  end
  LayoutSolver.solve(list)
  assertRect(target, 0, 10, 20, 10, "the target scrolled to the bottom edge")
  assertRect(list.children[1], 0, -10, 20, 10, "the first row scrolled above the top edge")
  logger.trace("passed test testANodeKeepsAChildInViewFromWhereTheFlowPutIt")
end

testRowFitsTheSumOfItsChildrenPlusGapsAndPadding()
testColumnFitsItsWidestChild()
testFitTakesTheNaturalWidthOfContent()
testFitIsCappedByItsMax()
testFixedIgnoresItsContent()
testGrowChildTakesTheSpaceLeft()
testSmallestGrowChildGrowsFirst()
testGrowStopsAtItsMax()
testLargestChildShrinksFirstAndFixedDoesNotShrink()
testTextStopsShrinkingAtItsLongestWord()
testAMinBelowItsContentLetsAChildShrinkPastIt()
testGrowAcrossTheFlowTakesTheInnerSize()
testTextWrapsToTheWidthItWasGiven()
testColumnFitsTheSumOfItsChildrenHeights()
testGrowHeightInARowTakesTheTallestChildsHeight()
testGrowHeightInAColumnTakesTheSpaceLeft()
testRowPlacesChildrenAfterEachOther()
testUnevenPaddingPlacesChildrenFromEachSide()
testAlignmentCentersAlongAndAcrossTheFlow()
testFlowSnapsChildrenToEvenPointsWithoutDrift()
testTextKeepsItsWidthWhereverItsEdgesAreRounded()
testGrownSiblingsMeetEdgeToEdgeOnEvenPoints()
testCenteredTextLandsOnThePixelGridAtEveryScale()
testAChildAfterTextLandsOnThePixelGridAtEveryScale()
testTextAlignedAcrossTheFlowLandsOnThePixelGridAtEveryScale()
testNestedTextEndsWithinAPointOfItsPaddingAtEveryScale()
testColumnPlacesChildrenBelowEachOther()
testFloatingElementPinsToItsParentAndTakesNoRoom()
testFloatingElementPinsToAnElementById()
testTextFloatingAtTheTopOfTheScreenLandsOnThePixelGridAtEveryScale()
testAnElementPinnedToAFloatingOneIsWithinAPointOfWhereItBelongs()
testPinningToAnElementPlacedLaterIsAnError()
testFloatingGrowElementTakesTheFullSizeOfWhatItIsPinnedTo()
testFloatingGrowElementTakesTheSizeOfALaterSibling()
testSolvingAgainReusesTheRects()
testAnOddFloatingOffsetIsRoundedOntoThePixelGrid()
testAPartlyScrolledFlowStaysOnThePixelGrid()
testChildOffsetMovesTheFlowButNotFloatingChildren()
testClippedContentKeepsItsSizeAlongTheClip()
testAGrowingClippedElementTakesTheSpaceItIsGivenNotItsContentsSize()
testANodeKeepsAChildInViewFromWhereTheFlowPutIt()
