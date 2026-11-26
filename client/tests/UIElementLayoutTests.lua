local UIElement = require("client.src.ui.UIElement")
local LayoutSolver = require("client.src.ui.LayoutSolver")
local Layout = require("client.src.ui.Layout")
local logger = require("common.lib.logger")

local fixedSize = Layout.fixedSize
local GROW = Layout.GROW

-- Counts the solves while fn runs
local function countSolves(fn)
  local solve = LayoutSolver.solve
  local count = 0
  LayoutSolver.solve = function(root)
    count = count + 1
    solve(root)
  end
  fn()
  LayoutSolver.solve = solve
  return count
end

local function element(rules)
  return UIElement({layoutRules = rules})
end

local function testAFloatingChildIsPinnedByItsAttachPointsAndOffset()
  local parent = element({sizing = fixedSize(200, 100)})
  local child = element({sizing = fixedSize(52, 30), floating = {attachTo = "parent", offset = {x = 4, y = -4},
                                                                 attachPoints = {element = "centerBottom", parent = "centerBottom"}}})
  parent:addChild(child)
  parent:layOut()
  local x, y = child:getScreenPos()
  assert(x == 78 and y == 66, "screen position " .. x .. "," .. y)
  logger.trace("passed test testAFloatingChildIsPinnedByItsAttachPointsAndOffset")
end

local function testFloatAtPinsTheSamePointOfElementAndParent()
  local parent = element({sizing = fixedSize(200, 100)})
  local child = element({sizing = fixedSize(50, 30), floating = Layout.floatAt("rightBottom", -10, -6)})
  parent:addChild(child)
  parent:layOut()
  local x, y = child:getScreenPos()
  assert(x == 140 and y == 64, "screen position " .. x .. "," .. y)
  logger.trace("passed test testFloatAtPinsTheSamePointOfElementAndParent")
end

local function testARuleChangedAfterLayoutIsPickedUpByTheNextOne()
  local parent = element({sizing = fixedSize(200, 100)})
  local child = element({sizing = fixedSize(50, 30), floating = {attachTo = "parent", attachPoints = {element = "rightCenter", parent = "rightCenter"}}})
  parent:addChild(child)
  parent:layOut()
  child:setLayoutRule("floating", {attachTo = "parent", attachPoints = {element = "rightCenter", parent = "rightCenter"}, offset = {x = -6}})
  child:setLayoutRule("sizing", fixedSize(60, 30))
  assert(child:getScreenPos() == 150, "the last layout's position until the next layout")
  parent:layOut()
  local x = child:getScreenPos()
  assert(x == 134, "screen x " .. x)
  logger.trace("passed test testARuleChangedAfterLayoutIsPickedUpByTheNextOne")
end

local function testGrowingChildFollowsItsParentsSize()
  local parent = element({sizing = fixedSize(200, 100)})
  local child = element({sizing = {horizontal = GROW, vertical = GROW}})
  parent:addChild(child)
  parent:layOut()
  assert(child.layoutRect.width == 200 and child.layoutRect.height == 100, "size " .. child.layoutRect.width .. "x" .. child.layoutRect.height)
  parent:setFixedSize(300, 100)
  parent:layOut()
  assert(child.layoutRect.width == 300, "width after the parent grew " .. child.layoutRect.width)
  logger.trace("passed test testGrowingChildFollowsItsParentsSize")
end

local function testAChildIsInItsParentsFlowUnlessItFloats()
  local column = element({layoutDirection = "topToBottom", childGap = 2})
  local first = element({sizing = fixedSize(30, 10)})
  local badge = element({sizing = fixedSize(8, 8), floating = {attachTo = "parent"}})
  local second = element({sizing = fixedSize(30, 20)})
  column:addChild(first)
  column:addChild(badge)
  column:addChild(second)
  column:layOut()
  assert(first.layoutRect.y == 0 and second.layoutRect.y == 12, "y " .. first.layoutRect.y .. " and " .. second.layoutRect.y)
  assert(column.layoutRect.height == 32, "the floating badge takes no room: height " .. column.layoutRect.height)
  logger.trace("passed test testAChildIsInItsParentsFlowUnlessItFloats")
end

local function testAnElementWithoutSizingFitsItsFlow()
  local row = element({childGap = 6})
  row:addChild(element({sizing = fixedSize(30, 10)}))
  row:addChild(element({sizing = fixedSize(20, 12)}))
  row:layOut()
  assert(row.layoutRect.width == 56 and row.layoutRect.height == 12, "size " .. row.layoutRect.width .. "x" .. row.layoutRect.height)
  logger.trace("passed test testAnElementWithoutSizingFitsItsFlow")
end

local function testOnResizeRunsWhenAddedAndWhenItsSizeChanges()
  local parent = element({sizing = fixedSize(200, 100)})
  local child = element({sizing = {horizontal = GROW, vertical = Layout.fixed(10)}})
  local calls = 0
  function child:onResize()
    calls = calls + 1
  end
  parent:addChild(child)
  parent:layOut()
  assert(calls == 1, "onResize calls after adding " .. calls)
  parent:addChild(element({sizing = fixedSize(10, 10)}))
  parent:layOut()
  assert(calls == 2, "onResize calls after a sibling took room " .. calls)
  parent:setLayoutRule("childGap", 0)
  parent:layOut()
  assert(calls == 2, "onResize calls after a layout that kept its size " .. calls)
  logger.trace("passed test testOnResizeRunsWhenAddedAndWhenItsSizeChanges")
end

local function testAnUnchangedTreeIsNotSolvedAgain()
  local parent = element({sizing = fixedSize(200, 100)})
  parent:addChild(element({sizing = fixedSize(10, 10)}))
  parent:layOut()
  local solves = countSolves(function()
    parent:layOut()
    parent:layOut()
  end)
  assert(solves == 0, "solves " .. solves)
  logger.trace("passed test testAnUnchangedTreeIsNotSolvedAgain")
end

local function testManyChangesAreSolvedOnce()
  local parent = element({sizing = fixedSize(200, 100)})
  local child = element({sizing = fixedSize(10, 10)})
  parent:addChild(child)
  parent:layOut()
  local solves = countSolves(function()
    child:setFixedSize(20, 10)
    parent:addChild(element({sizing = fixedSize(10, 10)}))
    parent:setLayoutRule("childGap", 4)
    parent:layOut()
    parent:layOut()
  end)
  assert(solves == 1, "solves " .. solves)
  logger.trace("passed test testManyChangesAreSolvedOnce")
end

local function testInBoundsUsesTheLayoutRect()
  local parent = element({sizing = fixedSize(200, 100)})
  local child = element({sizing = fixedSize(20, 20),
                         floating = {attachTo = "parent", attachPoints = {element = "centerCenter", parent = "centerCenter"}}})
  parent:addChild(child)
  parent:layOut()
  assert(child:inBounds(100, 50), "the center is inside")
  assert(not child:inBounds(5, 5), "the corner is outside")
  logger.trace("passed test testInBoundsUsesTheLayoutRect")
end

-- A detached subtree is not drawn, so it isn't laid out until it is added again or laid out as a root of its own
local function testADetachedElementIsLaidOutOnlyWhenAskedTo()
  local parent = element({sizing = fixedSize(200, 100), padding = Layout.padding(6)})
  local child = element({sizing = {horizontal = GROW, vertical = Layout.fixed(10)}})
  parent:addChild(child)
  parent:layOut()
  child:detach()
  parent:layOut()
  assert(child.layoutRect.x == 6 and child.layoutRect.width == 188, "the detached child keeps its last layout")
  child:layOut()
  local x, y = child:getScreenPos()
  assert(x == 0 and y == 0 and child.layoutRect.width == 0, "screen position " .. x .. "," .. y .. " width " .. child.layoutRect.width)
  logger.trace("passed test testADetachedElementIsLaidOutOnlyWhenAskedTo")
end

-- Returns a 100 by 20 column that clips vertically, holding three 30 by 10 children, laid out
---@return UiElement column
---@return UiElement[] children
local function scrollingColumn()
  local column = element({layoutDirection = "topToBottom", sizing = fixedSize(100, 20), clip = {vertical = true}})
  local children = {}
  for i = 1, 3 do
    children[i] = element({sizing = fixedSize(30, 10)})
    column:addChild(children[i])
  end
  column:layOut()
  return column, children
end

local function screenY(uiElement)
  local _, y = uiElement:getScreenPos()
  return y
end

local function testScrollingMovesTheFlowWithoutALayout()
  local column, children = scrollingColumn()
  local badge = element({sizing = fixedSize(6, 6), floating = Layout.floatAt("leftTop")})
  column:addChild(badge)
  column:layOut()
  local solves = countSolves(function()
    column:setScroll(0, -6)
    column:layOut()
  end)
  assert(solves == 0 and not column.layoutDirty, "scrolling solved the layout " .. solves .. " times")
  assert(children[1].layoutRect.y == 0 and screenY(children[1]) == -6, "the first child is at " .. screenY(children[1]))
  assert(screenY(badge) == 0, "the floating child moved to " .. screenY(badge))
  assert(children[3]:inBounds(10, 15) and not children[2]:inBounds(10, 15), "touches don't follow the scroll")
  logger.trace("passed test testScrollingMovesTheFlowWithoutALayout")
end

local function testScrollStopsAtTheEndsOfTheContent()
  local column = scrollingColumn()
  column:setScroll(0, -300)
  assert(column.scrollY == -10, "scrolled down to " .. column.scrollY)
  column:scrollBy(0, 300)
  assert(column.scrollY == 0, "scrolled up to " .. column.scrollY)
  column:setScroll(-8, 0)
  assert(column.scrollX == 0, "scrolled to " .. column.scrollX .. " along the axis it doesn't clip")
  logger.trace("passed test testScrollStopsAtTheEndsOfTheContent")
end

local function testScrollStaysOnThePixelGrid()
  local column = scrollingColumn()
  column:setScroll(0, -3.2)
  assert(column.scrollY == -4, "scrolled to " .. column.scrollY)
  logger.trace("passed test testScrollStaysOnThePixelGrid")
end

local function testAnElementThatDoesNotClipDoesNotScroll()
  local column = element({layoutDirection = "topToBottom", sizing = fixedSize(100, 20)})
  column:addChild(element({sizing = fixedSize(30, 50)}))
  column:layOut()
  column:setScroll(0, -6)
  assert(column.scrollY == 0, "scrolled to " .. column.scrollY)
  logger.trace("passed test testAnElementThatDoesNotClipDoesNotScroll")
end

local function testAChildIsScrolledIntoViewByAsLittleAsItTakes()
  local column, children = scrollingColumn()
  column:scrollChildIntoView(children[3])
  assert(column.scrollY == -10, "scrolled to " .. column.scrollY .. " for the last child")
  column:scrollChildIntoView(children[2])
  assert(column.scrollY == -10, "scrolled to " .. column.scrollY .. " for a child already in view")
  column:scrollChildIntoView(children[1])
  assert(column.scrollY == 0, "scrolled to " .. column.scrollY .. " for the first child")
  logger.trace("passed test testAChildIsScrolledIntoViewByAsLittleAsItTakes")
end

local function testAChildAddedSinceTheLayoutIsScrolledIntoViewByTheNextOne()
  local column = scrollingColumn()
  local added = element({sizing = fixedSize(30, 10)})
  column:addChild(added)
  column:scrollChildIntoView(added)
  column:layOut()
  assert(column.scrollY == -20 and screenY(added) == 10, "scrolled to " .. column.scrollY)
  logger.trace("passed test testAChildAddedSinceTheLayoutIsScrolledIntoViewByTheNextOne")
end

local function testTheLayoutKeepsTheScrollWithinContentThatShrank()
  local column, children = scrollingColumn()
  column:setScroll(0, -10)
  children[3]:detach()
  column:layOut()
  assert(column.scrollY == 0, "scrolled to " .. column.scrollY)
  logger.trace("passed test testTheLayoutKeepsTheScrollWithinContentThatShrank")
end

local function testOnlyClaysRulesCanBeSet()
  local ok, err = pcall(element({}).setLayoutRule, element({}), "width", 30)
  assert(not ok and tostring(err):find("no layout rule is called width"), "setting width gave " .. tostring(err))
  logger.trace("passed test testOnlyClaysRulesCanBeSet")
end

local function testOnlyClaysRulesCanBeGiven()
  local ok, err = pcall(element, {width = 30})
  assert(not ok and tostring(err):find("no layout rule is called width"), "giving width gave " .. tostring(err))
  logger.trace("passed test testOnlyClaysRulesCanBeGiven")
end

local function testSettingARuleLeavesTheGivenRulesAsTheyWere()
  local given = {sizing = fixedSize(50, 10), childGap = 4}
  local first = element(given)
  local second = element(given)

  first:setLayoutRule("childGap", 8)
  first:setFixedSize(80, 10)

  assert(given.childGap == 4 and given.sizing.horizontal.min == 50, "rules given to many elements, like a layout file's, stay as they were")
  assert(second.layoutRules.sizing == given.sizing and first.layoutRules.sizing.horizontal.min == 80)
  logger.trace("passed test testSettingARuleLeavesTheGivenRulesAsTheyWere")
end

local function testSettingTheSameFixedSizeChangesNothing()
  local root = element({})
  root:setFixedSize(40, 30)
  root:layOut()
  local sizing = root.layoutRules.sizing
  root:setFixedSize(40, 30)
  assert(not root.layoutDirty, "the same size marks no change")
  root:setFixedSize(50, 30)
  assert(root.layoutDirty and root.layoutRules.sizing ~= sizing and sizing.horizontal.min == 40, "a new size replaces the sizing")
  logger.trace("passed test testSettingTheSameFixedSizeChangesNothing")
end

local function testChangingTheLayoutWhileItIsLaidOutIsAnError()
  local parent = element({sizing = fixedSize(200, 100)})
  local child = element({sizing = {horizontal = GROW, vertical = GROW}})
  function child:onResize()
    self:setLayoutRule("childGap", 3)
  end
  parent:addChild(child)
  local ok, err = pcall(parent.layOut, parent)
  assert(not ok and tostring(err):find("the layout changed while it was being laid out"), "laying out gave " .. tostring(err))
  logger.trace("passed test testChangingTheLayoutWhileItIsLaidOutIsAnError")
end

local function testOnlyARootIsLaidOut()
  local parent = element({})
  local child = element({})
  parent:addChild(child)
  local ok, err = pcall(child.layOut, child)
  assert(not ok and tostring(err):find("only the root of a tree is laid out"), "laying out a child gave " .. tostring(err))
  logger.trace("passed test testOnlyARootIsLaidOut")
end

testAFloatingChildIsPinnedByItsAttachPointsAndOffset()
testFloatAtPinsTheSamePointOfElementAndParent()
testARuleChangedAfterLayoutIsPickedUpByTheNextOne()
testGrowingChildFollowsItsParentsSize()
testAChildIsInItsParentsFlowUnlessItFloats()
testAnElementWithoutSizingFitsItsFlow()
testOnResizeRunsWhenAddedAndWhenItsSizeChanges()
testAnUnchangedTreeIsNotSolvedAgain()
testManyChangesAreSolvedOnce()
testInBoundsUsesTheLayoutRect()
testADetachedElementIsLaidOutOnlyWhenAskedTo()
testScrollingMovesTheFlowWithoutALayout()
testScrollStopsAtTheEndsOfTheContent()
testScrollStaysOnThePixelGrid()
testAnElementThatDoesNotClipDoesNotScroll()
testAChildIsScrolledIntoViewByAsLittleAsItTakes()
testAChildAddedSinceTheLayoutIsScrolledIntoViewByTheNextOne()
testTheLayoutKeepsTheScrollWithinContentThatShrank()
testOnlyClaysRulesCanBeSet()
testOnlyClaysRulesCanBeGiven()
testSettingARuleLeavesTheGivenRulesAsTheyWere()
testSettingTheSameFixedSizeChangesNothing()
testChangingTheLayoutWhileItIsLaidOutIsAnError()
testOnlyARootIsLaidOut()
