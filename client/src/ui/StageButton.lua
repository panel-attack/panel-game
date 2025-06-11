local import = require("common.lib.import")
local class = require("common.lib.class")
local Button = import("./Button")
local Label = import("./Label")
local Image = import("./ImageContainer")
local VerticalFlexLayout = import("./Layouts/VerticalFlexLayout")

---@class StageButtonOptions : ButtonOptions
---@field stage Stage

---@class StageButton : Button
---@operator call(StageButtonOptions): StageButton
---@overload fun(options: StageButtonOptions): StageButton
---@field stage Stage
local StageButton = class(
---@param self StageButton
---@param options StageButtonOptions
function(self, options)
  self.stage = options.stage

  self.childGap = 4

  self.hAlign = "center"
  self.vAlign = "center"

  self.image = Image({
    image = self.stage.images.thumbnail,
    hFill = true,
    vFill = true,
    hAlign = "center",
    vAlign = "center",
    backgroundColor = {0.2, 0.7, 0.3, 0.6}
  })

  self.label = Label({
    text = self.stage.display_name,
    hAlign = "center",
    vAlign = "center",
    vFill = true,
    backgroundColor = {0.2, 0.1, 0.7, 0.6}
  })

  self:addChild(self.image)
  self:addChild(self.label)
end,
Button)

StageButton.TYPE = "StageButton"
StageButton.layout = VerticalFlexLayout

function StageButton:action(inputSource)
  if not inputSource or not inputSource.player then
    return
  else
    local player = inputSource.player
    player:setStage(self.stage.id)
    GAME.theme:playValidationSfx()
  end
end

function StageButton:drawSelf()

end

return StageButton