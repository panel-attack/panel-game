local Stepper = require("client.src.ui.Stepper")
local Label = require("client.src.ui.Label")
local Layout = require("client.src.ui.Layout")
local logger = require("common.lib.logger")

-- the arrow buttons' width on each side of the label
local NAV_BUTTON_WIDTH = 25

local function testTheStepperFitsItsWidestLabelBetweenItsArrows()
  local short = Label({text = "Easy", translate = false})
  local wide = Label({text = "Breezy (Easy)", translate = false})
  local stepper = Stepper({labels = {short, wide}, values = {1, 2}, layoutRules = {sizing = Layout.fixedSize(70, 25)}})
  stepper:layOut()

  local needed = wide.contentWidth + 2 * NAV_BUTTON_WIDTH
  assert(stepper.layoutRect.width >= needed,
         string.format("the stepper is %s wide, less than the %s its widest label and arrows take", stepper.layoutRect.width, needed))
  logger.trace("passed test testTheStepperFitsItsWidestLabelBetweenItsArrows")
end

testTheStepperFitsItsWidestLabelBetweenItsArrows()
