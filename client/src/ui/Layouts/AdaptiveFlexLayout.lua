local PATH = (...):gsub('%.[^%.]+$', '')
local Layout = require(PATH .. ".Layout")
local VerticalFlexLayout = require(PATH ..".VerticalFlexLayout")
local HorizontalFlexLayout = require(PATH ..".HorizontalFlexLayout")

---@class AdaptiveFlexLayout : FlexLayout
local AdaptiveFlexLayout = setmetatable({}, {__index = HorizontalFlexLayout})

function AdaptiveFlexLayout.resize(uiElement, width, height)
  local mt = getmetatable(AdaptiveFlexLayout)
  if width and height then
    if width < height and mt.__index ~= VerticalFlexLayout then
      mt.__index = VerticalFlexLayout
    elseif height < width and mt.__index ~= HorizontalFlexLayout then
      mt.__index = HorizontalFlexLayout
    end
  end

  Layout.resize(uiElement, width, height)
end

return AdaptiveFlexLayout