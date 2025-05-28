local import = require("common.lib.import")
local Layout = import("./Layout")
local VerticalFlexLayout = import("./VerticalFlexLayout")
local HorizontalFlexLayout = import("./HorizontalFlexLayout")

---@class AdaptiveFlexLayout : FlexLayout
---@diagnostic disable-next-line: assign-type-mismatch
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