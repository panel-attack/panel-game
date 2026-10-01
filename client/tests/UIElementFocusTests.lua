local UIElement = require("client.src.ui.UIElement")
local StackPanel = require("client.src.ui.StackPanel")
local MultiPlayerSelectionWrapper = require("client.src.ui.MultiPlayerSelectionWrapper")
local InputField = require("client.src.ui.InputField")
local InputSource = require("client.src.input.InputSource")
local Player = require("client.src.Player")
local logger = require("common.lib.logger")

local function createFakeInputs()
  return {isDown = {}, isPressed = {}, isUp = {}, isPressedWithRepeat = function() return false end}
end

local function createPlayerSource(name)
  local player = Player(name, -1, true)
  player.inputConfiguration = createFakeInputs()
  return player.inputSource
end

-- an element that counts the passes it handles itself and yields when told to
local function createRecordingElement()
  local element = UIElement({})
  element.received = {}
  element.yieldOnNextInput = {}
  element.receiveInputsSelf = function(self, inputSource)
    self.received[inputSource] = (self.received[inputSource] or 0) + 1
    if self.yieldOnNextInput[inputSource] then
      self.yieldOnNextInput[inputSource] = nil
      self:yieldFocus(inputSource)
    end
  end
  return element
end

local function testSetFocusable()
  local element = UIElement({})
  assert(not element.isFocusable, "elements start out not focusable")
  element:setFocusable(true)
  assert(element.isFocusable, "setFocusable(true) should make the element focusable")
  logger.trace("passed test testSetFocusable")
end

local function testEditingAnInputFieldKeepsHasFocusAMethod()
  local field = InputField({placeholder = "name"})

  field:startEditing()
  assert(field.isEditing, "startEditing should mark the field as editing")
  assert(type(field.hasFocus) == "function", "editing should not replace the hasFocus method")
  field:stopEditing()
  assert(not field.isEditing, "stopEditing should clear the editing mark")
  logger.trace("passed test testEditingAnInputFieldKeepsHasFocusAMethod")
end

local function testFocusedChildReceivesInputsInsteadOfParent()
  local source = createPlayerSource("p1")
  local parent = createRecordingElement()
  local child = createRecordingElement()
  parent:focusChild(child, source)

  parent:receiveInputs(source, 0)

  assert(child.received[source] == 1, "the focused child should receive the inputs")
  assert(parent.received[source] == nil, "the parent should not handle inputs while a child is focused")
  logger.trace("passed test testFocusedChildReceivesInputsInsteadOfParent")
end

local function testUnfocusedParentHandlesInputsItself()
  local source = createPlayerSource("p1")
  local parent = createRecordingElement()

  parent:receiveInputs(source, 0)

  assert(parent.received[source] == 1, "a parent without a focused child should handle inputs itself")
  logger.trace("passed test testUnfocusedParentHandlesInputsItself")
end

local function testTwoSourcesFocusTheSameElementIndependently()
  local p1 = createPlayerSource("p1")
  local p2 = createPlayerSource("p2")
  local p1Cursor = createRecordingElement()
  local p2Cursor = createRecordingElement()
  local shared = createRecordingElement()
  p1Cursor:focusChild(shared, p1)
  p2Cursor:focusChild(shared, p2)

  shared.yieldOnNextInput[p2] = true
  p2Cursor:receiveInputs(p2, 0)
  p1Cursor:receiveInputs(p1, 0)
  p2Cursor:receiveInputs(p2, 0)

  assert(p1Cursor.focusedChild[p1] == shared, "p2 leaving should not free p1's cursor")
  assert(p2Cursor.focusedChild[p2] == nil, "p2's cursor should be free after p2 yields")
  assert(p2Cursor.received[p2] == 1, "p2's cursor should handle the pass after p2 yields")
  assert(p1Cursor.received[p1] == nil, "p1's cursor should still forward to the shared element")
  logger.trace("passed test testTwoSourcesFocusTheSameElementIndependently")
end

local function testYieldClearsOnlyThatSourceAndRunsCallback()
  local p1 = createPlayerSource("p1")
  local p2 = createPlayerSource("p2")
  local parent = createRecordingElement()
  local child = createRecordingElement()
  local p1Yields = 0
  local p2Yields = 0
  parent:focusChild(child, p1, function() p1Yields = p1Yields + 1 end)
  parent:focusChild(child, p2, function() p2Yields = p2Yields + 1 end)

  child.yieldOnNextInput[p1] = true
  parent:receiveInputs(p1, 0)

  assert(parent.focusedChild[p1] == nil, "p1's entry should be cleared")
  assert(parent.focusedChild[p2] == child, "p2's entry should stay")
  assert(p1Yields == 1, "p1's callback should run once")
  assert(p2Yields == 0, "p2's callback should not run")
  logger.trace("passed test testYieldClearsOnlyThatSourceAndRunsCallback")
end

local function testUnfocusChildReleasesImmediatelyAndRunsCallback()
  local source = createPlayerSource("p1")
  local parent = createRecordingElement()
  local child = createRecordingElement()
  local yields = 0
  parent:focusChild(child, source, function() yields = yields + 1 end)

  parent:unfocusChild(source)

  assert(parent.focusedChild[source] == nil, "the entry should be cleared")
  assert(not child:hasFocus(source), "the child should no longer have focus")
  assert(yields == 1, "the callback should run")
  logger.trace("passed test testUnfocusChildReleasesImmediatelyAndRunsCallback")
end

local function testNestedYieldReachesTheParentThatFocusedTheContainer()
  local source = createPlayerSource("p1")
  local cursor = createRecordingElement()
  local container = StackPanel({alignment = "left"})
  local inner = createRecordingElement()
  container:addElement(UIElement({width = 8, height = 8}))
  container:addElement(inner)
  cursor:focusChild(container, source)
  assert(inner:hasFocus(source), "focusing the container should focus its inner widget")

  inner.yieldOnNextInput[source] = true
  cursor:receiveInputs(source, 0)

  assert(inner.received[source] == 1, "the container should delegate to the inner widget")
  assert(cursor.focusedChild[source] == nil, "the inner widget's yield should free the cursor")
  logger.trace("passed test testNestedYieldReachesTheParentThatFocusedTheContainer")
end

-- a container that passes its focus on to one inner widget, counting the inner widget's yields
local function createForwardingContainer(inner)
  local container = UIElement({})
  container.innerYields = 0
  container.onFocus = function(self, inputSource)
    self:forwardFocus(inner, inputSource, function() self.innerYields = self.innerYields + 1 end)
  end
  container:addChild(inner)
  return container
end

local function testForwardFocusRunsItsCallbackWhenTheInnerWidgetYields()
  local source = createPlayerSource("p1")
  local cursor = createRecordingElement()
  local inner = createRecordingElement()
  local container = createForwardingContainer(inner)
  cursor:focusChild(container, source)

  inner.yieldOnNextInput[source] = true
  cursor:receiveInputs(source, 0)

  assert(container.innerYields == 1, "the container's callback should run when the inner widget yields")
  assert(cursor.focusedChild[source] == nil, "the inner widget's yield should free the cursor")
  assert(not container:hasFocus(source), "the container should have given its focus back")
  logger.trace("passed test testForwardFocusRunsItsCallbackWhenTheInnerWidgetYields")
end

local function testUnfocusChildReleasesTheWholeChain()
  local source = createPlayerSource("p1")
  local cursor = createRecordingElement()
  local inner = createRecordingElement()
  local container = createForwardingContainer(inner)
  cursor:focusChild(container, source)

  cursor:unfocusChild(source)

  assert(not inner:hasFocus(source), "releasing the container should release its inner widget")
  assert(container.focusedChild[source] == nil, "the container should no longer forward to its inner widget")
  assert(not container.yielded[source], "a release from outside should not leave the container marked as yielded")
  assert(container.innerYields == 0, "a release from outside is not the inner widget yielding")
  logger.trace("passed test testUnfocusChildReleasesTheWholeChain")
end

local function testFocusingAnotherChildReleasesThePreviousChain()
  local source = createPlayerSource("p1")
  local cursor = createRecordingElement()
  local inner = createRecordingElement()
  local container = createForwardingContainer(inner)
  cursor:focusChild(container, source)

  cursor:focusChild(createRecordingElement(), source)

  assert(not inner:hasFocus(source), "focusing something else should release the previous inner widget")
  logger.trace("passed test testFocusingAnotherChildReleasesThePreviousChain")
end

local function testHasFocusPerSourceAndForAnySource()
  local p1 = createPlayerSource("p1")
  local p2 = createPlayerSource("p2")
  local parent = createRecordingElement()
  local child = createRecordingElement()

  assert(not child:hasFocus(), "nobody has focused the child yet")
  parent:focusChild(child, p1)
  assert(child:hasFocus(p1), "p1 has focused the child")
  assert(not child:hasFocus(p2), "p2 has not focused the child")
  assert(child:hasFocus(), "someone has focused the child")
  child:yieldFocus(p1)
  assert(not child:hasFocus(p1), "yielding should drop focus right away")
  assert(not child:hasFocus(), "nobody has focus after the yield")
  logger.trace("passed test testHasFocusPerSourceAndForAnySource")
end

local function testWrapperRoutesByPlayer()
  local p1 = createPlayerSource("p1")
  local p2 = createPlayerSource("p2")
  local wrapper = MultiPlayerSelectionWrapper({alignment = "top"})
  local p1Element = createRecordingElement()
  local p2Element = createRecordingElement()
  wrapper:addElement(p1Element, p1.player)
  wrapper:addElement(p2Element, p2.player)
  local p2Cursor = createRecordingElement()
  p2Cursor:focusChild(wrapper, p2)
  assert(p2Element:hasFocus(p2), "focusing the wrapper should focus p2's element for p2")
  assert(not p1Element:hasFocus(), "focusing the wrapper for p2 should not focus p1's element")

  p2Element.yieldOnNextInput[p2] = true
  p2Cursor:receiveInputs(p2, 0)

  assert(p2Element.received[p2] == 1, "p2's inputs should reach p2's element")
  assert(p1Element.received[p2] == nil, "p2's inputs should not reach p1's element")
  assert(p2Cursor.focusedChild[p2] == nil, "p2's element yielding should free p2's cursor")
  logger.trace("passed test testWrapperRoutesByPlayer")
end

testSetFocusable()
testEditingAnInputFieldKeepsHasFocusAMethod()
testFocusedChildReceivesInputsInsteadOfParent()
testUnfocusedParentHandlesInputsItself()
testTwoSourcesFocusTheSameElementIndependently()
testYieldClearsOnlyThatSourceAndRunsCallback()
testUnfocusChildReleasesImmediatelyAndRunsCallback()
testNestedYieldReachesTheParentThatFocusedTheContainer()
testForwardFocusRunsItsCallbackWhenTheInnerWidgetYields()
testUnfocusChildReleasesTheWholeChain()
testFocusingAnotherChildReleasesThePreviousChain()
testHasFocusPerSourceAndForAnySource()
testWrapperRoutesByPlayer()
