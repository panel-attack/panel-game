local class = require("common.lib.class")
local ui = require("client.src.ui")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local WIDTH = 220
local PADDING = 14
local HEADING_GAP = 4
local SECTION_GAP = 14
local CORNER_RADIUS = 6

-- A heading over one of the values, quieter than the value itself
---@param text string the heading's localization key
---@return Label
local function heading(text)
  return ui.Label({text = text, hAlign = "center", textColor = {0.7, 0.7, 0.8, 1}})
end

-- The records of the selected Challenge Mode difficulty beside its menu: the unfinished run's stage, continues and time,
-- and the fewest continues and fastest time of the beaten runs, laid out like the heading and value pairs of the challenge HUD
---@class ChallengeRunRecords : StackPanel
---@field stageValue PixelFontLabel
---@field continuesValue PixelFontLabel
---@field timeValue PixelFontLabel
---@field bestValue PixelFontLabel
---@field bestTimeValue PixelFontLabel
---@field noRunLabel Label
---@field notBeatenLabel Label
---@field headings table<UiElement, Label> the heading each value is shown under
local ChallengeRunRecords = class(function(self, options)
  self.width = WIDTH
  local theme = themes[config.theme]
  self.stageValue = ui.PixelFontLabel({fontMap = theme.fontMaps.numbers[2], xScale = theme.win_Scale, yScale = theme.win_Scale,
                                       hAlign = "center"})
  self.continuesValue = ui.PixelFontLabel({fontMap = theme.fontMaps.numbers[2], xScale = theme.win_Scale,
                                           yScale = theme.win_Scale, hAlign = "center"})
  self.timeValue = ui.PixelFontLabel({fontMap = theme.fontMaps.time, xScale = theme.time_Scale, yScale = theme.time_Scale,
                                      hAlign = "center"})
  self.bestValue = ui.PixelFontLabel({fontMap = theme.fontMaps.numbers[2], xScale = theme.win_Scale, yScale = theme.win_Scale,
                                      hAlign = "center"})
  self.bestTimeValue = ui.PixelFontLabel({fontMap = theme.fontMaps.time, xScale = theme.time_Scale, yScale = theme.time_Scale,
                                          hAlign = "center"})
  self.noRunLabel = ui.Label({text = "challenge_no_run", hAlign = "center"})
  self.notBeatenLabel = ui.Label({text = "challenge_not_beaten", hAlign = "center"})

  self.headings = {
    [self.stageValue] = heading("challenge_stage"),
    [self.continuesValue] = heading("challenge_continues"),
    [self.timeValue] = heading("challenge_time"),
    [self.bestValue] = heading("challenge_best_continues"),
    [self.bestTimeValue] = heading("challenge_best_time"),
    [self.notBeatenLabel] = heading("challenge_best_continues"),
  }
end, ui.StackPanel)

-- Shows the unfinished run, or that there is none, and the best continues and time, or that the difficulty was never beaten
---@param run ChallengeRun?
---@param bestContinues integer?
---@param bestTime integer? frames
function ChallengeRunRecords:show(run, bestContinues, bestTime)
  while #self.children > 0 do
    self:remove(self.children[1])
  end
  self:addElement(ui.UiElement({height = PADDING}))
  if run then
    self.stageValue:setText(run.stageIndex)
    self.continuesValue:setText(run.continues)
    self.timeValue:setText(frames_to_time_string(run.expendedTime, true))
    self:addSection(self.stageValue)
    self:addSection(self.continuesValue)
    self:addSection(self.timeValue)
  else
    self:addSection(self.noRunLabel)
  end
  if bestContinues then
    self.bestValue:setText(bestContinues)
    self:addSection(self.bestValue)
  else
    self:addSection(self.notBeatenLabel)
  end
  if bestTime then
    self.bestTimeValue:setText(frames_to_time_string(bestTime, true))
    self:addSection(self.bestTimeValue)
  end
  self:addElement(ui.UiElement({height = PADDING}))
end

-- Adds the value under its heading, apart from the section above it
---@param value UiElement
function ChallengeRunRecords:addSection(value)
  if #self.children > 1 then
    self:addElement(ui.UiElement({height = SECTION_GAP}))
  end
  local valueHeading = self.headings[value]
  if valueHeading then
    self:addElement(valueHeading)
    self:addElement(ui.UiElement({height = HEADING_GAP}))
  end
  self:addElement(value)
end

function ChallengeRunRecords:drawSelf()
  GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, 0, 0, 0, 0.75, CORNER_RADIUS, CORNER_RADIUS)
  GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height, 0.5, 0.5, 0.6, 0.8, CORNER_RADIUS, CORNER_RADIUS)
end

return ChallengeRunRecords
