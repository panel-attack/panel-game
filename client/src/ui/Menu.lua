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
-- Items that don't fit wholly where the menu is scrolled to are hidden.
---@class Menu : UiElement
---@field equalItemWidths boolean true if every item is stretched to the widest so their boxes line up
---@field scrollToSelected boolean true from a selection made while the layout was out of date until the next layout
--- scrolls the selected item into view
---@field centerOffset number how far the items shown are drawn down to center them vertically
local Menu = class(
  function(self, options)
    ---@class Menu
    self = self
    self.TYPE = "VerticalScrollingButtonMenu"

    self.selectedIndex = 1
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

-- Shows the items that fit wholly in the menu where it is scrolled to, shows an indicator on each side items are cut
-- off, and centers the items shown vertically when the theme asks for it
function Menu:showItemsInView()
  self.upIndicator:setVisibility(false)
  self.downIndicator:setVisibility(false)
  self.firstActiveIndex = nil
  self.lastActiveIndex = nil

  local height = self.layoutRect.height
  local shownHeight = 0
  local menuFull = false
  for i, menuItem in ipairs(self.menuItems) do
    local rect = menuItem.layoutRect
    menuItem:setVisibility(false)
    local scrolledY = rect.y + self.scrollY
    if scrolledY < 0 then
      self.upIndicator:setVisibility(true)
    end
    if menuFull == false and scrolledY >= 0 then
      if scrolledY + rect.height <= height + LayoutSolver.FLOAT_TOLERANCE then
        if self.firstActiveIndex == nil then
          self.firstActiveIndex = i
        end
        menuItem:setVisibility(true)
      else
        self.downIndicator:setVisibility(true)
        menuFull = true
      end
    end
    if menuFull == false then
      self.lastActiveIndex = i
      shownHeight = scrolledY + rect.height
    end
  end
  self.centerOffset = self.centerVertically and LayoutSolver.toEvenPoints((height - shownHeight) / 2) or 0
end

-- Scrolls the selected item into view, to the item that puts it at the top, or the bottom when it was below
function Menu:scrollSelectedIntoView()
  local index = self.selectedIndex
  if #self.menuItems == 0 then
    return
  end
  if self.firstActiveIndex == nil or self.firstActiveIndex > index then
    self:setScroll(0, -self.menuItems[index].layoutRect.y)
  elseif self.lastActiveIndex < index then
    local currentIndex = 1
    local bottomOfDesiredIndex = self.menuItems[index].layoutRect.y + self.menuItems[index].layoutRect.height
    while self.menuItems[currentIndex].layoutRect.y + self.layoutRect.height + LayoutSolver.FLOAT_TOLERANCE < bottomOfDesiredIndex do
      currentIndex = currentIndex + 1
      if currentIndex >= #self.menuItems then
        break
      end
    end
    self:setScroll(0, -self.menuItems[currentIndex].layoutRect.y)
  end
end

-- Returns how far the menu scrolls: to the first item that, at the top, leaves the last item wholly in the menu
---@return number maxX
---@return number maxY
function Menu:getMaxScroll()
  local lastItem = self.menuItems[#self.menuItems]
  if not self.layoutRules.clip or not lastItem then
    return 0, 0
  end
  local contentHeight = lastItem.layoutRect.y + lastItem.layoutRect.height
  local reach = self.layoutRect.height + LayoutSolver.FLOAT_TOLERANCE
  if contentHeight <= reach then
    return 0, 0
  end
  for _, menuItem in ipairs(self.menuItems) do
    if menuItem.layoutRect.y + reach >= contentHeight then
      return 0, menuItem.layoutRect.y
    end
  end
  return 0, lastItem.layoutRect.y
end

-- Shows the items in view once the layout placed them, after scrolling to an item selected since the last layout
---@param width number
---@param height number
function Menu:onLayoutSized(width, height)
  UIElement.onLayoutSized(self, width, height)
  self:showItemsInView()
  if self.scrollToSelected then
    self.scrollToSelected = false
    self:scrollSelectedIntoView()
  end
end

-- Shows the items that fit where the menu was scrolled to
function Menu:onScrollChanged()
  self:showItemsInView()
end

-- The items are drawn and touched where the menu is scrolled to, moved down when they are centered
---@return number x
---@return number y
function Menu:getFlowOffset()
  return 0, self.centerOffset + self.scrollY
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
-- Also scrolls to show the button if off screen, in the next layout when the layout is out of date
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
  if self:hasCurrentLayout() then
    self:scrollSelectedIntoView()
  else
    self.scrollToSelected = true
  end
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

-- Moves the selection one item per wheel step, stopping at either end
---@param dx number sideways wheel movement, which a menu ignores
---@param dy number wheel movement, positive away from the player
function Menu:onScroll(dx, dy)
  local step = dy > 0 and -1 or 1
  local index = math.max(1, math.min(#self.menuItems, self.selectedIndex + step))
  if dy ~= 0 and index ~= self.selectedIndex then
    self:setSelectedIndex(index)
    self:playMoveSfx()
  end
end

-- Draws the items unclipped where the menu is scrolled to, as the ones cut off are hidden, and the indicators moved
-- with the centered items
function Menu:drawChildren()
  local _, flowOffsetY = self:getFlowOffset()
  for _, uiElement in ipairs(self.children) do
    love.graphics.push("transform")
    love.graphics.translate(0, uiElement.layoutRules.floating and self.centerOffset or flowOffsetY)
    uiElement:draw()
    love.graphics.pop()
  end
end

return Menu
