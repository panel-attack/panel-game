-- The layout solver reads each element's LayoutRules and writes its LayoutRect.
-- The rules are Clay's element declaration: sizing, padding, childGap, childAlignment and layoutDirection place an
-- element's children, clip scrolls them, and floating takes an element out of its parent's flow and pins it.
-- It follows Clay's passes: fit widths, grow and shrink widths, wrap text, fit then grow and shrink heights,
-- then positions, each element's floating children last, then the rounded edges. A clipped element's childOffset moves
-- the children in its flow, never the floating ones.
-- Every edge is worked out exactly from the root's origin, then rounded to even points there, so each element is
-- within a point of its exact place however deep it is, and siblings that meet meet on the same point. Child offsets and
-- floating offsets are part of that exact place, so they are rounded with it. Content is measured up to even points first,
-- so rounding the edges of an element sized to its content never leaves it narrower than its text.
--
-- A node is any table with `children` and `layoutRules`. It may also have
--   measureContentWidth() returning its content's natural and smallest width, for sizing it to fit
--   measureContentHeight(width) returning its content's height at that width, for wrapping text
--   onLayoutSized(width, height) told its final size once the layout is done
--   getChildOffset(axis) returning how far its flow is scrolled along the axis once the flow is placed unscrolled at
--   its exact places, in place of its clip's childOffset, for keeping a child in view
-- The solver writes `layoutRect` ({x, y, width, height}, x and y measured from the parent) and keeps its own
-- working data in `layoutState`. Both tables are created once and reused.

---@alias LayoutSizingType "fit"|"grow"|"fixed"

-- How an element is sized along one axis, Clay's Clay_SizingAxis: fit wraps its content, grow fits and then takes a
-- share of the room left in its parent, and fixed is the size min and max both give
---@class LayoutSizing
---@field type LayoutSizingType
---@field min number? the smallest it is, and the smallest a flow shrinks it to even when its content is larger
---@field max number? the largest it is, unlimited if nil

---@class LayoutSizingAxes
---@field horizontal LayoutSizing? fit if nil
---@field vertical LayoutSizing? fit if nil

---@class LayoutPadding
---@field left number?
---@field right number?
---@field top number?
---@field bottom number?

---@class LayoutChildAlignment
---@field x ("left"|"center"|"right")? where the children sit horizontally, left if nil
---@field y ("top"|"center"|"bottom")? where the children sit vertically, top if nil

---@class LayoutVector
---@field x number?
---@field y number?

-- An element that scrolls the children in its flow, which are drawn only inside it
---@class LayoutClip
---@field horizontal boolean? clips and scrolls horizontally; the children in the flow never shrink to fit along it
---@field vertical boolean? clips and scrolls vertically
---@field childOffset LayoutVector? how far the children in the flow are moved, negative to scroll them left or up

---@alias LayoutAttachPoint "leftTop"|"leftCenter"|"leftBottom"|"centerTop"|"centerCenter"|"centerBottom"|"rightTop"|"rightCenter"|"rightBottom"

---@class LayoutAttachPoints
---@field element LayoutAttachPoint? the point of the floating element that is pinned, leftTop if nil
---@field parent LayoutAttachPoint? the point of the element it floats on that it is pinned to, leftTop if nil

-- Takes an element out of its parent's flow and pins it to its parent or a named element. A floating element that grows
-- takes the full size of the element it is pinned to.
---@class LayoutFloating
---@field attachTo "parent"|"element"
---@field parentId string? the id of the element it is pinned to, when it is attached to an element
---@field attachPoints LayoutAttachPoints?
---@field offset LayoutVector? added after pinning

---@class LayoutRules
---@field id string? lets a floating element pin to this one
---@field sizing LayoutSizingAxes?
---@field padding LayoutPadding?
---@field childGap number? between the children in the flow
---@field childAlignment LayoutChildAlignment?
---@field layoutDirection ("leftToRight"|"topToBottom")? how the children in the flow are placed, leftToRight if nil
---@field clip LayoutClip?
---@field floating LayoutFloating?

---@class LayoutRect
---@field x number
---@field y number
---@field width number
---@field height number

local LayoutSolver = {}

local NO_RULES = {}
local NO_VECTOR = {}
local FIT = {type = "fit"}

-- each attach point's place on an element, as shares of its width and height
LayoutSolver.ATTACH_POINTS = {
  leftTop = {0, 0}, centerTop = {0.5, 0}, rightTop = {1, 0},
  leftCenter = {0, 0.5}, centerCenter = {0.5, 0.5}, rightCenter = {1, 0.5},
  leftBottom = {0, 1}, centerBottom = {0.5, 1}, rightBottom = {1, 1},
}
local ATTACH_POINTS = LayoutSolver.ATTACH_POINTS

local ALIGN_SHARES = {left = 0, top = 0, center = 0.5, right = 1, bottom = 1}

---@class LayoutAxis the names one axis's rules and rect use, so each pass is written once for both axes
---@field size "width"|"height"
---@field position "x"|"y"
---@field direction "leftToRight"|"topToBottom" the layout direction that runs along the axis
---@field paddingStart "left"|"top"
---@field paddingEnd "right"|"bottom"
---@field orientation "horizontal"|"vertical" the axis's key in the clip and sizing rules
---@field share integer the index of the axis's share in an attach point
---@field smallest string the layoutState key of the smallest size along the axis
---@field exact string the layoutState key of the unrounded position from the root

---@type LayoutAxis
local X_AXIS = {
  size = "width", position = "x", direction = "leftToRight", paddingStart = "left", paddingEnd = "right",
  orientation = "horizontal", share = 1, smallest = "smallestWidth", exact = "exactX",
}
---@type LayoutAxis
local Y_AXIS = {
  size = "height", position = "y", direction = "topToBottom", paddingStart = "top", paddingEnd = "bottom",
  orientation = "vertical", share = 2, smallest = "smallestHeight", exact = "exactY",
}
LayoutSolver.X_AXIS = X_AXIS
LayoutSolver.Y_AXIS = Y_AXIS

-- the space in points below which a difference between exact places is float error, not room
local FLOAT_TOLERANCE = 0.0001
LayoutSolver.FLOAT_TOLERANCE = FLOAT_TOLERANCE

-- Rounds a position to a whole even number of points. The canvas scale is a multiple of 0.5, so 2 points are a whole
-- number of pixels at every scale, and the same layout lands on the pixel grid at every resolution.
---@param position number
---@return number
local function toEvenPoints(position)
  return 2 * math.round(position / 2)
end

-- Rounds a measured length up to a whole even number of points, ignoring float error. An even length keeps its size
-- when both of its edges are rounded to even points.
---@param length number
---@return number
local function toEvenPointsUp(length)
  return 2 * math.ceil(length / 2 - FLOAT_TOLERANCE)
end

-- The rules' sizing along the axis, fit when they set none
---@param rules LayoutRules
---@param axis LayoutAxis
---@return LayoutSizing
local function getSizingAlong(rules, axis)
  local axes = rules.sizing
  return axes and axes[axis.orientation] or FIT
end

-- The rules' padding at the start and end of the axis
---@param rules LayoutRules
---@param axis LayoutAxis
---@return number start
---@return number finish
local function getPaddingAlong(rules, axis)
  local padding = rules.padding
  if not padding then
    return 0, 0
  end
  return padding[axis.paddingStart] or 0, padding[axis.paddingEnd] or 0
end

---@param child UiElement
---@return boolean # whether the child takes its place in its parent's flow, which it does unless it floats
local function isInFlow(child)
  return child.layoutState.rules.floating == nil
end

---@param rules LayoutRules
---@param axis LayoutAxis
---@return boolean # whether the rules lay their children out one after another along the axis
local function isAlongFlow(rules, axis)
  return (rules.layoutDirection or "leftToRight") == axis.direction
end

---@param rules LayoutRules
---@param axis LayoutAxis
---@return boolean # whether the rules clip, and so scroll, their children along the axis
local function clips(rules, axis)
  local clip = rules.clip
  return clip ~= nil and clip[axis.orientation] == true
end

-- Keeps the size between the sizing's smallest and largest sizes
---@param size number
---@param sizingAxis LayoutSizing
---@return number
local function clamp(size, sizingAxis)
  local largest = sizingAxis.max
  if largest and size > largest then
    size = largest
  end
  local smallest = sizingAxis.min
  if smallest and size < smallest then
    size = smallest
  end
  return size
end

-- Gives every node its rect and working data and reads its rules for this solve
---@param node UiElement
local function prepare(node)
  node.layoutRect = node.layoutRect or {x = 0, y = 0, width = 0, height = 0}
  node.layoutState = node.layoutState or {}
  local state = node.layoutState
  state.rules = node.layoutRules or NO_RULES
  state.contentHeight = nil
  state.exactX = nil
  for _, child in ipairs(node.children) do
    prepare(child)
  end
end

-- Pass 1 and the first half of pass 4: sizes every node to fit its content, innermost first,
-- and works out the smallest size it can shrink to
---@param node UiElement
---@param axis LayoutAxis
local function fitSize(node, axis)
  local children = node.children
  for _, child in ipairs(children) do
    fitSize(child, axis)
  end

  local state = node.layoutState
  local rules = state.rules
  local sizingAxis = getSizingAlong(rules, axis)
  local size, smallestSize
  if sizingAxis.type == "fixed" then
    size = clamp(0, sizingAxis)
    smallestSize = size
  else
    local paddingStart, paddingEnd = getPaddingAlong(rules, axis)
    local along = isAlongFlow(rules, axis)
    local childrenSize, childrenSmallest, count = 0, 0, 0
    for _, child in ipairs(children) do
      if isInFlow(child) then
        count = count + 1
        local childSize = child.layoutRect[axis.size]
        local childSmallest = child.layoutState[axis.smallest]
        if along then
          childrenSize = childrenSize + childSize
          childrenSmallest = childrenSmallest + childSmallest
        else
          childrenSize = math.max(childrenSize, childSize)
          childrenSmallest = math.max(childrenSmallest, childSmallest)
        end
      end
    end
    if along and count > 1 then
      local gaps = (rules.childGap or 0) * (count - 1)
      childrenSize = childrenSize + gaps
      childrenSmallest = childrenSmallest + gaps
    end
    local contentSize, contentSmallest = 0, 0
    if axis == X_AXIS and node.measureContentWidth then
      local natural, smallest = node:measureContentWidth()
      contentSize, contentSmallest = toEvenPointsUp(natural), toEvenPointsUp(smallest or natural)
    elseif axis == Y_AXIS and state.contentHeight then
      contentSize = toEvenPointsUp(state.contentHeight)
      contentSmallest = contentSize
    end
    local smallestContent = math.max(childrenSmallest, contentSmallest)
    if clips(rules, axis) then
      -- a flow that scrolls shows any part of its children, so it can shrink to its padding
      smallestContent = 0
    end
    local paddingTotal = paddingStart + paddingEnd
    size = clamp(math.max(childrenSize, contentSize) + paddingTotal, sizingAxis)
    -- a smallest size lets it shrink past its content, as text cut short does
    smallestSize = math.min(size, sizingAxis.min or clamp(smallestContent + paddingTotal, sizingAxis))
  end

  node.layoutRect[axis.size] = size
  state[axis.smallest] = smallestSize
end

---@param child UiElement
---@param axis LayoutAxis
---@return boolean # whether the child grows along the axis
local function grows(child, axis)
  return getSizingAlong(child.layoutState.rules, axis).type == "grow"
end

-- Grows the smallest growing children first until the space is used or every one reached its largest size
---@param children UiElement[]
---@param axis LayoutAxis
---@param remaining number the space left to hand out
local function growAlong(children, axis, remaining)
  while remaining > FLOAT_TOLERANCE do
    local smallest, secondSmallest, count = math.huge, math.huge, 0
    for _, child in ipairs(children) do
      local size = child.layoutRect[axis.size]
      if isInFlow(child) and grows(child, axis) and size < (getSizingAlong(child.layoutState.rules, axis).max or math.huge) then
        if size < smallest then
          secondSmallest = smallest
          smallest = size
          count = 1
        elseif size == smallest then
          count = count + 1
        elseif size < secondSmallest then
          secondSmallest = size
        end
      end
    end
    if count == 0 then
      return
    end
    local step = math.min(secondSmallest - smallest, remaining / count)
    for _, child in ipairs(children) do
      local rect = child.layoutRect
      if isInFlow(child) and grows(child, axis) and rect[axis.size] == smallest then
        local grown = math.min(smallest + step, getSizingAlong(child.layoutState.rules, axis).max or math.huge)
        remaining = remaining - (grown - smallest)
        rect[axis.size] = grown
      end
    end
  end
end

-- Shrinks the largest children first until they fit or every one reached its smallest size
---@param children UiElement[]
---@param axis LayoutAxis
---@param excess number the space the children take past what there is
local function shrinkAlong(children, axis, excess)
  while excess > FLOAT_TOLERANCE do
    local largest, secondLargest, count = -math.huge, -math.huge, 0
    for _, child in ipairs(children) do
      local size = child.layoutRect[axis.size]
      if isInFlow(child) and size > child.layoutState[axis.smallest] then
        if size > largest then
          secondLargest = largest
          largest = size
          count = 1
        elseif size == largest then
          count = count + 1
        elseif size > secondLargest then
          secondLargest = size
        end
      end
    end
    if count == 0 then
      return
    end
    local step = math.min(largest - secondLargest, excess / count)
    for _, child in ipairs(children) do
      local rect = child.layoutRect
      if isInFlow(child) and rect[axis.size] == largest then
        local shrunk = math.max(largest - step, child.layoutState[axis.smallest])
        excess = excess - (largest - shrunk)
        rect[axis.size] = shrunk
      end
    end
  end
end

-- Returns the element with the id among node's descendants
---@param node UiElement
---@param id string
---@return UiElement?
local function findById(node, id)
  for _, child in ipairs(node.children) do
    if child.layoutState.rules.id == id then
      return child
    end
    local found = findById(child, id)
    if found then
      return found
    end
  end
end

-- Returns the element a floating child is pinned to: the node it is a child of, or the element it names under that node
---@param node UiElement
---@param child UiElement
---@return UiElement
local function floatingTarget(node, child)
  local floating = child.layoutState.rules.floating
  if floating.attachTo == "element" then
    local target = findById(node, floating.parentId)
    assert(target, "no element with the id " .. tostring(floating.parentId) .. " to attach to")
    return target
  end
  return node
end

-- Pass 2 and the second half of pass 4: hands each node's space to its children, from the root inward
---@param node UiElement
---@param axis LayoutAxis
local function growAndShrink(node, axis)
  local rules = node.layoutState.rules
  local children = node.children
  local paddingStart, paddingEnd = getPaddingAlong(rules, axis)
  local inner = node.layoutRect[axis.size] - paddingStart - paddingEnd

  if isAlongFlow(rules, axis) then
    local used, count = 0, 0
    for _, child in ipairs(children) do
      if isInFlow(child) then
        used = used + child.layoutRect[axis.size]
        count = count + 1
      end
    end
    if count > 1 then
      used = used + (rules.childGap or 0) * (count - 1)
    end
    if inner > used then
      growAlong(children, axis, inner - used)
    elseif inner < used and not clips(rules, axis) then
      shrinkAlong(children, axis, used - inner)
    end
  end

  if not isAlongFlow(rules, axis) then
    for _, child in ipairs(children) do
      local rect = child.layoutRect
      if isInFlow(child) then
        if grows(child, axis) then
          rect[axis.size] = math.max(child.layoutState[axis.smallest], clamp(inner, getSizingAlong(child.layoutState.rules, axis)))
        elseif rect[axis.size] > inner and not clips(rules, axis) then
          rect[axis.size] = math.max(child.layoutState[axis.smallest], inner)
        end
      end
    end
  end

  for _, child in ipairs(children) do
    if isInFlow(child) then
      growAndShrink(child, axis)
    end
  end
  -- floating children last, so every element they can be pinned to has its size
  for _, child in ipairs(children) do
    if not isInFlow(child) then
      if grows(child, axis) then
        local target = floatingTarget(node, child)
        child.layoutRect[axis.size] = clamp(target.layoutRect[axis.size], getSizingAlong(child.layoutState.rules, axis))
      end
      growAndShrink(child, axis)
    end
  end
end

-- Pass 3: works out the height of wrapping content now that its width is known
---@param node UiElement
local function wrapContent(node)
  if node.measureContentHeight then
    local paddingStart, paddingEnd = getPaddingAlong(node.layoutState.rules, X_AXIS)
    node.layoutState.contentHeight = node:measureContentHeight(node.layoutRect.width - paddingStart - paddingEnd)
  end
  for _, child in ipairs(node.children) do
    wrapContent(child)
  end
end

-- Tells every node its size once it is final
---@param node UiElement
local function reportSizes(node)
  if node.onLayoutSized then
    local rect = node.layoutRect
    node:onLayoutSized(rect.width, rect.height)
  end
  for _, child in ipairs(node.children) do
    reportSizes(child)
  end
end

-- Places the child at the exact position, measured from the node; its edges stay exact until they are snapped
---@param node UiElement
---@param child UiElement
---@param axis LayoutAxis
---@param position number
local function setPosition(node, child, axis, position)
  child.layoutState[axis.exact] = node.layoutState[axis.exact] + position
  child.layoutRect[axis.position] = position
end

-- Moves every child in the node's flow along the axis by the node's child offset, asking the node for it when it keeps a
-- child in view and reading it from its clip otherwise
---@param node UiElement
---@param axis LayoutAxis
local function offsetFlowChildren(node, axis)
  local rules = node.layoutState.rules
  local offset
  if node.getChildOffset then
    offset = node:getChildOffset(axis)
  else
    offset = rules.clip and (rules.clip.childOffset or NO_VECTOR)[axis.position]
  end
  if offset and offset ~= 0 then
    for _, child in ipairs(node.children) do
      if isInFlow(child) then
        setPosition(node, child, axis, child.layoutRect[axis.position] + offset)
      end
    end
  end
end

-- Pass 5: places the children in the flow
---@param node UiElement
local function placeFlowChildren(node)
  local rules = node.layoutState.rules
  local children = node.children
  local alignment = rules.childAlignment or NO_RULES
  for axisIndex = 1, 2 do
    local axis = axisIndex == 1 and X_AXIS or Y_AXIS
    local start, paddingEnd = getPaddingAlong(rules, axis)
    local inner = node.layoutRect[axis.size] - start - paddingEnd
    local share = ALIGN_SHARES[alignment[axis.position]] or 0
    if isAlongFlow(rules, axis) then
      local gap = rules.childGap or 0
      local used = -gap
      for _, child in ipairs(children) do
        if isInFlow(child) then
          used = used + child.layoutRect[axis.size] + gap
        end
      end
      local cursor = start + math.max(0, inner - used) * share
      for _, child in ipairs(children) do
        if isInFlow(child) then
          setPosition(node, child, axis, cursor)
          cursor = cursor + child.layoutRect[axis.size] + gap
        end
      end
    else
      for _, child in ipairs(children) do
        if isInFlow(child) then
          setPosition(node, child, axis, start + (inner - child.layoutRect[axis.size]) * share)
        end
      end
    end
    offsetFlowChildren(node, axis)
  end
end

-- Pass 6: pins a floating child to its target, the node or the element it names
---@param node UiElement
---@param child UiElement
local function placeFloating(node, child)
  local floating = child.layoutState.rules.floating
  local target = floatingTarget(node, child)
  assert(target.layoutState.exactX, tostring(floating.parentId) .. " is attached to after it, so it isn't placed yet")
  local attachPoints = floating.attachPoints or NO_RULES
  local point = ATTACH_POINTS[attachPoints.element or "leftTop"]
  local toPoint = ATTACH_POINTS[attachPoints.parent or "leftTop"]
  local offset = floating.offset or NO_VECTOR
  local rect = child.layoutRect
  local targetRect = target.layoutRect
  local nodeState, targetState = node.layoutState, target.layoutState
  local x = targetState.exactX - nodeState.exactX + targetRect.width * toPoint[1] - rect.width * point[1] + (offset.x or 0)
  local y = targetState.exactY - nodeState.exactY + targetRect.height * toPoint[2] - rect.height * point[2] + (offset.y or 0)
  setPosition(node, child, X_AXIS, x)
  setPosition(node, child, Y_AXIS, y)
end

-- Places the node's children, then their children, from the root inward. Each floating child is pinned once every
-- element in the flow under the node is placed, and each pinned element is a target for the ones after it.
---@param node UiElement
local function placeChildren(node)
  placeFlowChildren(node)
  for _, child in ipairs(node.children) do
    if isInFlow(child) then
      placeChildren(child)
    end
  end
  for _, child in ipairs(node.children) do
    if not isInFlow(child) then
      placeFloating(node, child)
      placeChildren(child)
    end
  end
end

-- Pass 7: moves each node's edges onto the even points nearest their exact places from the root's origin, so a node
-- ends where the next one in its flow starts
---@param node UiElement
---@param parentLeft number the parent's snapped left edge from the root's origin
---@param parentTop number the parent's snapped top edge from the root's origin
local function snapEdges(node, parentLeft, parentTop)
  local state, rect = node.layoutState, node.layoutRect
  local left, top = toEvenPoints(state.exactX), toEvenPoints(state.exactY)
  rect.x, rect.y = left - parentLeft, top - parentTop
  rect.width = toEvenPoints(state.exactX + rect.width) - left
  rect.height = toEvenPoints(state.exactY + rect.height) - top
  for _, child in ipairs(node.children) do
    snapEdges(child, left, top)
  end
end

-- Lays out the tree under root, writing every node's layoutRect; the root is placed at the origin
---@param root UiElement
function LayoutSolver.solve(root)
  prepare(root)
  fitSize(root, X_AXIS)
  growAndShrink(root, X_AXIS)
  wrapContent(root)
  fitSize(root, Y_AXIS)
  growAndShrink(root, Y_AXIS)
  local state = root.layoutState
  state.exactX, state.exactY = 0, 0
  root.layoutRect.x, root.layoutRect.y = 0, 0
  placeChildren(root)
  snapEdges(root, 0, 0)
  reportSizes(root)
end

return LayoutSolver
