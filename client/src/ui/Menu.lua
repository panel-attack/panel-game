local table = table

local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local Label = require(PATH .. ".Label")
local Layout = require(PATH .. ".Layout")
local LayoutSolver = require(PATH .. ".LayoutSolver")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")

local NAVIGATION_BUTTON_WIDTH = 30
local BUTTON_VERTICAL_PADDING = 8
local VERTICAL_CLIP = {vertical = true}

-- Menu is a collection of buttons that stack vertically and supports scrolling and keyboard navigation.
-- It requires the passed in menu items to have valid widths and adds padding between each. Its height is its
-- layoutRules' sizing.vertical, fitting all items when that isn't fixed, and the width is the maximum of all buttons.
-- Items that don't fit wholly at the scroll offset are hidden.
---@class Menu : UiElement
---@field equalItemWidths boolean true if every item is stretched to the widest so their boxes line up
---@field yOffset number how far the items are scrolled up
---@field scrollToSelected boolean true from a selection until the next layout scrolls the selected item into view
---@field centerOffset number how far the next layout moved the items down to center them vertically
local Menu = class(
  function(self, options)
    ---@class Menu
    self = self
    self.TYPE = "VerticalScrollingButtonMenu"

    self.selectedIndex = 1
    self.totalHeight = 0
    self.menuItemYOffsets = {}
    self.allContentShowing = true
    local heightSizing = self.layoutRules.sizing and self.layoutRules.sizing.vertical
    self.sizeToFit = heightSizing == nil or heightSizing.type == "fit"
    self.equalItemWidths = options.equalItemWidths or false
    self.supportsBackButton = true
    if options.supportsBackButton ~= nil and options.supportsBackButton == false then
      self.supportsBackButton = false
    end

    self:setLayoutRule("layoutDirection", "topToBottom")
    self:setLayoutRule("childGap", BUTTON_VERTICAL_PADDING)
    self:setLayoutRule("sizing", {horizontal = Layout.FIT, vertical = heightSizing or Layout.FIT})
    if not self.sizeToFit then
      -- keeps the items at their size when they don't all fit
      self:setLayoutRule("clip", VERTICAL_CLIP)
    end

    self.upIndicator = Label({
      text = "^",
      translate = false,
      isVisible = false,
      layoutRules = {floating = Layout.floatAt("centerTop", 0, -14)}
    })
    self.downIndicator = Label({
      text = "v",
      translate = false,
      isVisible = false,
      layoutRules = {floating = Layout.floatAt("centerBottom")}
    })
    self:addChild(self.upIndicator)
    self:addChild(self.downIndicator)

    -- bogus this should be passed in?
    self.centerVertically = themes[config.theme].centerMenusVertically and not self.sizeToFit

    self.yOffset = 0
    self.centerOffset = 0
    self.scrollToSelected = false
    self.firstActiveIndex = 1
    self.lastActiveIndex = 1
    self:setMenuItems(options.menuItems)
  end,
  UIElement
)

Menu.NAVIGATION_BUTTON_WIDTH = NAVIGATION_BUTTON_WIDTH
Menu.BUTTON_HORIZONTAL_PADDING = 0
Menu.BUTTON_VERTICAL_PADDING = BUTTON_VERTICAL_PADDING

-- Creates a menu centered in its parent unless options.layoutRules float it elsewhere
---@param items MenuItem[]
---@param height number? the menu's height, the theme's main_menu_max_height if nil, fitting the items if 0
---@param options table? the Menu's options
---@return Menu
function Menu.createCenteredMenu(items, height, options)
  options = options or {}
  local layoutRules = options.layoutRules and shallowcpy(options.layoutRules) or {}
  height = height or themes[config.theme].main_menu_max_height
  layoutRules.sizing = {vertical = height ~= 0 and Layout.fixed(height) or nil}
  layoutRules.floating = layoutRules.floating or Layout.floatAt("centerCenter")
  options.layoutRules = layoutRules
  options.menuItems = items

  local menu = Menu(options)
  return menu
end

-- Sets the menu items for this menu
-- menuItems: a list of UIElement tuples of the form:
--   {{Label/Button, ButtonGroup/Stepper/Slider}, ...}
-- the actual self.menuItems list is formated slightly differently, consisting of a list of Labels or Buttons
-- each of which may have a ButtonGroup, Stepper, or Slider child element which controls the action for that item
function Menu:setMenuItems(menuItems)
  if self.menuItems then
    for i, menuItem in ipairs(self.menuItems) do
      menuItem:detach()
    end
  end

  self.menuItems = {}

  for i, menuItem in ipairs(menuItems) do
    self:addItemChild(menuItem)
    self.menuItems[#self.menuItems + 1] = menuItem
  end
  self:setSelectedIndex(1)
end

-- Adds the item to the menu's flow, stretched to the menu's width with equalItemWidths
---@param menuItem MenuItem
function Menu:addItemChild(menuItem)
  if self.equalItemWidths then
    menuItem:fillMenuWidth()
  end
  self:addChild(menuItem)
end

-- Shows the items that fit wholly in the menu at yOffset, from the items' places in the layout before scrolling,
-- and shows an indicator on each side items are cut off
---@return number # the height from the menu's top to the bottom of the last item shown
function Menu:showItemsInView()
  self.upIndicator:setVisibility(false)
  self.downIndicator:setVisibility(false)
  self.allContentShowing = self.yOffset == 0
  self.firstActiveIndex = nil
  self.lastActiveIndex = nil
  self.totalHeight = 0

  local height = self.layoutRect.height
  local totalMenuHeight = 0
  local menuFull = false
  for i, menuItem in ipairs(self.menuItems) do
    local rect = menuItem.layoutRect
    self.menuItemYOffsets[i] = rect.y
    menuItem:setVisibility(false)
    local realY = rect.y - self.yOffset
    if realY < 0 then
      self.upIndicator:setVisibility(true)
    end
    if menuFull == false and realY >= 0 then
      if realY + rect.height <= height + LayoutSolver.FLOAT_TOLERANCE then
        if self.firstActiveIndex == nil then
          self.firstActiveIndex = i
        end
        menuItem:setVisibility(true)
      else
        self.allContentShowing = false
        self.downIndicator:setVisibility(true)
        menuFull = true
      end
    end
    if menuFull == false then
      self.lastActiveIndex = i
      totalMenuHeight = realY + rect.height
    end
    self.totalHeight = rect.y + rect.height
  end
  return totalMenuHeight
end

-- Scrolls the selected item into view, by as little as the menu's height allows
function Menu:scrollSelectedIntoView()
  local index = self.selectedIndex
  if #self.menuItems == 0 then
    return
  end
  if self.firstActiveIndex == nil then
    -- first element that was added on an empty menu
    self.yOffset = self.menuItemYOffsets[index]
  elseif self.firstActiveIndex > index then
    self.yOffset = self.menuItemYOffsets[index]
  elseif self.lastActiveIndex < index then
    local currentIndex = 1
    local bottomOfDesiredIndex = self.menuItemYOffsets[index] + self.menuItems[index].layoutRect.height
    while self.menuItemYOffsets[currentIndex] + self.layoutRect.height + LayoutSolver.FLOAT_TOLERANCE < bottomOfDesiredIndex do
      currentIndex = currentIndex + 1
      if currentIndex >= #self.menuItems then
        break
      end
    end
    self.yOffset = self.menuItemYOffsets[currentIndex]
  end
end

-- Scrolls the items by yOffset, after scrolling a newly selected item into view, and centers the items shown vertically
-- when the theme asks for it. Called by the layout once the items are placed unscrolled at their exact places.
---@param axis table LayoutSolver.X_AXIS or LayoutSolver.Y_AXIS
---@return number
function Menu:getChildOffset(axis)
  if axis ~= LayoutSolver.Y_AXIS or #self.menuItems == 0 then
    return 0
  end
  local totalMenuHeight = self:showItemsInView()
  if self.scrollToSelected then
    self.scrollToSelected = false
    self:scrollSelectedIntoView()
    totalMenuHeight = self:showItemsInView()
  end
  if self.centerVertically then
    self.centerOffset = (self.layoutRect.height - totalMenuHeight) / 2
  else
    self.centerOffset = 0
  end
  return self.centerOffset - self.yOffset
end

function Menu:addMenuItem(index, menuItem)
  local needsIncreasedIndex = false
  if index <= self.selectedIndex and #self.menuItems > 0 then
    needsIncreasedIndex = true
  end
  table.insert(self.menuItems, index, menuItem)
  self:addItemChild(menuItem)
  local nextItem = self.menuItems[index + 1]
  if nextItem then
    self:moveChild(menuItem, tableUtils.indexOf(self.children, nextItem))
  end
  if needsIncreasedIndex then
    self:setSelectedIndex(self.selectedIndex + 1)
  end
end

function Menu:removeMenuItemAtIndex(index)
  return self:removeMenuItem(self.menuItems[index].id)
end

function Menu:indexOfMenuItemID(menuItemId)
  local menuItemIndex = nil
  for i, menuItem in ipairs(self.menuItems) do
    if menuItemId == menuItem.id then
      menuItemIndex = i
      break
    end
  end
  return menuItemIndex
end

function Menu:containsMenuItemID(menuItemId)
  return self:indexOfMenuItemID(menuItemId) ~= nil
end

function Menu:removeMenuItem(menuItemId)
  local menuItemIndex = self:indexOfMenuItemID(menuItemId)

  if menuItemIndex == nil then
    return
  end

  local needsDecreasedIndex = false
  if menuItemIndex <= self.selectedIndex then
    needsDecreasedIndex = true
  end

  local menuItem = table.remove(self.menuItems, menuItemIndex)
  menuItem:detach()

  if needsDecreasedIndex then
    self:setSelectedIndex(self.selectedIndex - 1)
  end

  return menuItem
end

-- Updates the selected index of the menu
-- Also has the next layout scroll to show the button if off screen
function Menu:setSelectedIndex(index)
  if index <= 0 then
    index = 1 -- 1 index is the default if no items
  end

  if #self.menuItems >= self.selectedIndex then
    self.menuItems[self.selectedIndex]:setSelected(false)
  end
  self.selectedIndex = index
  if #self.menuItems > 0 then
    self.menuItems[self.selectedIndex]:setSelected(true)
  end
  self.scrollToSelected = true
  self:markLayoutDirty()
end

function Menu:scrollUp()
  self:setSelectedIndex(wrap(1, self.selectedIndex - 1, #self.menuItems))
  self:playMoveSfx()
end

function Menu:scrollDown()
  self:setSelectedIndex(wrap(1, self.selectedIndex + 1, #self.menuItems))
  self:playMoveSfx()
end

---@param inputSource InputSource
---@param dt number?
function Menu:receiveInputs(inputSource, dt)
  if not self.isEnabled then
    return
  end
  UIElement.receiveInputs(self, inputSource, dt)
end

---@param inputSource InputSource
---@param dt number?
function Menu:receiveInputsSelf(inputSource, dt)
  local inputs = inputSource:getInputs()
  local selectedElement = self.menuItems[self.selectedIndex]

  if inputs.isDown["MenuEsc"] then
    if self.supportsBackButton then
      if self.selectedIndex ~= #self.menuItems then
        self:setSelectedIndex(#self.menuItems)
        self:playCancelSfx()
      else
        selectedElement:receiveInputs(inputSource, dt)
      end
    end
  elseif inputs:isPressedWithRepeat("MenuUp") then
    self:scrollUp()
  elseif inputs:isPressedWithRepeat("MenuDown") then
    self:scrollDown()
  else
    if inputs.isDown["MenuSelect"] and selectedElement.isFocusable then
      self:focusChild(selectedElement, inputSource)
    else
      selectedElement:receiveInputs(inputSource, dt)
    end
  end
end

function Menu:update(dt)

end

function Menu:drawSelf()

end

-- Draws the items unclipped, as the ones cut off are hidden, and the indicators moved with the centered items
function Menu:drawChildren()
  for _, uiElement in ipairs(self.children) do
    if uiElement.layoutRules.floating and self.centerOffset ~= 0 then
      love.graphics.push("transform")
      love.graphics.translate(0, self.centerOffset)
      uiElement:draw()
      love.graphics.pop()
    else
      uiElement:draw()
    end
  end
end

function Menu:onTouch(x, y)
  self.swiping = true
  self.initialTouchX = x
  self.initialTouchY = y
  self.originalY = self.yOffset
  local realTouchedElement = UIElement.getTouchedElement(self, x, y)
  if realTouchedElement and realTouchedElement ~= self then
    self.touchedChild = realTouchedElement
    self.touchedChild:onTouch(x, y)
  end
end

function Menu:onDrag(x, y)
  if not self.touchedChild or not self.touchedChild.onDrag then
    local yOffset = y - self.initialTouchY
    local height = self.layoutRect.height
    if height < self.totalHeight then
      if yOffset > 0 then
        self.yOffset = math.max(self.originalY - yOffset, -50)-- - 2 * NAVIGATION_BUTTON_WIDTH)
      else
        self.yOffset = math.min(self.totalHeight - height + 50, self.originalY - yOffset)
      end
      self.scrollToSelected = false
      self:markLayoutDirty()
    end
  else
    self.touchedChild:onDrag(x, y)
  end
end

function Menu:onRelease(x, y)
  if not self.touchedChild or not self.touchedChild.onRelease then
    self:onDrag(x, y)
  else
    if self.yOffset ~= self.originalY then
      -- we dragged so trigger with the original touch coordinates
      -- that way the button will only trigger its on-click if it still touches the start coords
      self.touchedChild:onRelease(self.initialTouchX, self.initialTouchY)
    else
      self.touchedChild:onRelease(x, y)
    end
  end

  self.swiping = false
  self.touchedChild = nil
end

-- overwrite the default callback to always return itself
-- while keeping a reference to the really touched element
function Menu:getTouchedElement(x, y)
  if self.isVisible and self.isEnabled and self:inBounds(x, y) then
    if self.allContentShowing then
      local touchedElement
      for i = 1, #self.children do
        touchedElement = self.children[i]:getTouchedElement(x, y)
        if touchedElement then
          return touchedElement
        end
      end
    else
      return self
    end
  end
end

return Menu
