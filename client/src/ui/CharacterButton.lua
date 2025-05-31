local import = require("common.lib.import")
local class = require("common.lib.class")
local Button = import("./Button")
local consts = require("client.src.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local SUPER_SELECTION_DURATION = 0.5 -- time held in seconds at which super select actually happens
local SUPER_SELECTION_START = 0.1 -- time held in seconds at which super select is considered started

---@class CharacterButtonOptions : ButtonOptions
---@field character Character

---@class CharacterButton : Button
---@operator call(CharacterButtonOptions): CharacterButton
---@field character Character
---@field characterId string
---@field displayName string
---@field characterIcon love.Texture
---@field flagIcon love.Texture?
---@field stageIcon love.Texture?
---@field panelIcon love.Texture?
---@field holdTime number
---@field superSelectVisible boolean
---@overload fun(options: CharacterButtonOptions): CharacterButton
---@type CharacterButton
local CharacterButton = class(
---@param self CharacterButton
---@param options CharacterButtonOptions
function (self, options)
  assert(options.character)
  self.character = options.character
  self.characterId = self.character.id
  if self.characterId == consts.RANDOM_CHARACTER_SPECIAL_VALUE then
    self.displayName = loc("random")
  else
    self.displayName = self.character.display_name
  end

  self.characterIcon = self.character.images.icon
  self.flagIcon = GAME.theme:getFlag(self.character.flag)
  if self.character.stage and stages[self.character.stage] then
    self.stageIcon = stages[self.character.stage].images.thumbnail
  end
  if self.character.panels and panels[self.character.panels] then
    self.panelIcon = panels[self.character.panels].displayIcons[1]
  end

  self.holdTime = 0
  self.holding = false
  self.superSelectVisible = false
end,
Button)

local super_select_pixelcode = [[
      uniform float percent;
      vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
      {
          vec4 c = Texel(tex, texture_coords) * color;
          if( texture_coords.x < percent )
          {
            return c;
          }
          float ret = (c.x+c.y+c.z)/3.0;
          return vec4(ret, ret, ret, c.a);
      }
  ]]

CharacterButton.stageIconScale = 0.4
CharacterButton.padding = 2
CharacterButton.superSelectShader = love.graphics.newShader(super_select_pixelcode)

function CharacterButton:updateSuperSelectShader(timer)
  if timer > SUPER_SELECTION_START then
    if self.superSelectVisible == false then
      self.superSelectVisible = true
    end
    local progress = (timer - SUPER_SELECTION_START) / SUPER_SELECTION_DURATION
    if progress <= 1 then
      CharacterButton.superSelectShader:send("percent", progress)
    end
  else
    if self.superSelectVisible then
      self.superSelectVisible = false
    end
    CharacterButton.superSelectShader:send("percent", 0)
  end
end

function CharacterButton:addChild()
  error("CharacterButtons cannot have children")
end

function CharacterButton:action(inputSource, holdTime)
  local character = self.character
  character:playSelectionSfx()

  if not inputSource or not inputSource.player then
    return
  else
    local player = inputSource.player
    GAME.theme:playValidationSfx()
    if character:canSuperSelect() and holdTime > SUPER_SELECTION_START + SUPER_SELECTION_DURATION then
      -- super select
      if character.panels and panels[character.panels] then
        player:setPanels(character.panels)
      end
      if character.stage and stages[character.stage] then
        player:setStage(character.stage)
      end
    end
    player:setCharacter(self.characterId)
  end
end

-- touch interaction
-- by implementing onHold we can provide updates to the shader
function CharacterButton:onHold(timer)
  self:updateSuperSelectShader(timer)
end

  -- we need to override the standard onRelease to reset the shader
function CharacterButton:onRelease(x, y, timeHeld)
  self:updateSuperSelectShader(0)
  if self:inBounds(x, y) then
    self:action(input.mouse, timeHeld)
  end
  self.holdTime = 0
end

---@param cursor Cursor
---@param dt number?
function CharacterButton:receiveInputs(cursor, dt)
  local inputs = cursor.keyInput
  if not self.holding then
    if inputs.isDown.Swap1 then
      self.holding = true
    end
  else
    if inputs.isPressed.Swap1 then
      -- measure the time the press is held for
      self.holdTime = inputs.isPressed.Swap1
    else
      -- apply the actual click on release with the held time and reset it afterwards
      self:action(inputs, self.holdTime)
      self.holdTime = 0
      self.holding = false
    end
  end
  self:updateSuperSelectShader(self.holdTime)
end

---@param scale number
---@return FontSize
local function getFontSizeByScale(scale)
  if scale < 0.8 then
    return "small"
  elseif scale < 1.2 then
    return "normal"
  elseif scale < 1.8 then
    return "medium"
  else
    return "big"
  end
end

function CharacterButton:drawSelf()
  GraphicsUtil.setColor(1, 1, 1, 1)
  local imageWidth, imageHeight = self.characterIcon:getDimensions()
  local scale = math.min(self.width / imageWidth, self.height / imageHeight)

  love.graphics.push("transform")
  love.graphics.translate(self.x, self.y)
  GraphicsUtil.draw(self.characterIcon, 0, 0, 0, scale, scale)
  GraphicsUtil.printf(self.displayName, 0, 0, self.width, "center", nil, nil, getFontSizeByScale(scale))

  local bottomOffset = self.height - CharacterButton.padding * scale

  if self.flagIcon then
    imageWidth, imageHeight = self.flagIcon:getDimensions()
    GraphicsUtil.draw(self.flagIcon, self.width - CharacterButton.padding * scale, bottomOffset, 0, scale, scale, imageWidth, imageHeight)
  end

  if self.panelIcon then
    imageWidth, imageHeight = self.panelIcon:getDimensions()
    GraphicsUtil.draw(self.panelIcon, CharacterButton.padding * scale, bottomOffset, 0, scale, scale, 0, imageHeight)
  end

  if self.stageIcon then
    imageWidth, imageHeight = self.stageIcon:getDimensions()
    local stageScale = scale * CharacterButton.stageIconScale
    GraphicsUtil.draw(self.stageIcon, self.width / 2, bottomOffset, 0, stageScale, stageScale, imageWidth / 2, imageHeight)
    love.graphics.rectangle("line", (self.width / 2 - imageWidth * stageScale / 2), bottomOffset - imageHeight * stageScale, imageWidth * stageScale, imageHeight * stageScale)
  end

  if self.superSelectVisible then
    imageWidth, imageHeight = GAME.theme.images.IMG_super:getDimensions()
    scale = math.min(self.width / imageWidth, self.height / imageHeight)
    GraphicsUtil.setShader(CharacterButton.superSelectShader)
    GraphicsUtil.draw(GAME.theme.images.IMG_super, self.width / 2, self.height / 2, 0, scale, scale, imageWidth / 2, imageHeight / 2)
    GraphicsUtil.setShader()
  end

  GraphicsUtil.drawRectangle("line", 0, 0, self.width, self.height)
  love.graphics.pop()
end

return CharacterButton