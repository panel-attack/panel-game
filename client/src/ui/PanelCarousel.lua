local PATH = (...):gsub('%.[^%.]+$', '')
local Carousel = require(PATH .. ".Carousel")
local class = require("common.lib.class")
local StackPanel = require(PATH .. ".StackPanel")
local ImageContainer = require(PATH .. ".ImageContainer")

local PanelCarousel = class(function(carousel, options)
  carousel.colorCount = 5
end, Carousel)

function PanelCarousel:createPassenger(id)
  local stackPanel = StackPanel({alignment = "left", height = 20, hAlign = "center", vAlign = "center"})
  local panelImages = {}
  -- outlineColor
  for color = 1, #panels[id].displayIcons do
    panelImages[color] = ImageContainer({image = panels[id].displayIcons[color], vAlign = "center", drawBorders = false, width = 20, height = 20})
  end

  for i = 1, self.colorCount do
    stackPanel:addElement(panelImages[i])
  end
  -- always add shock
  stackPanel:addElement(panelImages[8])

  return {id = id, uiElement = stackPanel, panelImages = panelImages}
end

function PanelCarousel:setColorCount(count)
  if self.colorCount ~= count and count >= 2 and count < 8 then
    for _, passenger in ipairs(self.passengers) do
      if self.colorCount > count then
        for j = self.colorCount, count + 1, -1 do
          passenger.uiElement:remove(passenger.panelImages[j])
        end
      elseif self.colorCount < count then
        for j = self.colorCount + 1, count do
          passenger.uiElement:insertElementAtIndex(passenger.panelImages[j], j)
        end
      end
    end
    self.colorCount = count
  end
end

-- Selects the panel set, adding it first if it is in use but hidden so the carousel always shows the one in use
---@param id string
function PanelCarousel:setPassengerById(id)
  if panels[id] and not self:getPassengerById(id) then
    self:addPassenger(self:createPassenger(id))
  end
  Carousel.setPassengerById(self, id)
end

function PanelCarousel:loadPanels()
  for i = 1, #visiblePanels do
    local passenger = self:createPassenger(visiblePanels[i])
    self:addPassenger(passenger)
  end

  self:setPassengerById(config.panels)
end

return PanelCarousel