local PATH = (...):gsub('%.init$', '')

--[[
tag each with
---@source relative path
otherwise F12 on an import of ui elsewhere will lead to this file instead of the respective source file
the "./" is assumed given for relative paths but it's still a path so adding the extension is necessary
when addressing files in subdirectories (layouts) use forward slashes as the path separator
https://luals.github.io/wiki/annotations/#source

also tag with
---@type
so that you get intellisense
]]

local ui = {
  ---@source BoolSelector.lua
  ---@type BoolSelector
  BoolSelector = require(PATH .. ".BoolSelector"),
  ---@source Button.lua
  ---@type Button
  Button = require(PATH .. ".Button"),
  ButtonGroup = require(PATH .. ".ButtonGroup"),
  Carousel = require(PATH .. ".Carousel"),
  ---@source Cursor.lua
  ---@type Cursor
  Cursor = require(PATH .. ".Cursor"),
  Focusable = require(PATH .. ".Focusable"),
  FocusDirector = require(PATH .. ".FocusDirector"),
  Grid = require(PATH .. ".Grid"),
  GridCursor = require(PATH .. ".GridCursor"),
  ImageContainer = require(PATH .. ".ImageContainer"),
  InputField = require(PATH .. ".InputField"),
  ---@source Label.lua
  ---@type Label
  Label = require(PATH .. ".Label"),
  Layouts = {
    AdaptiveFlexLayout = require(PATH .. ".Layouts.AdaptiveFlexLayout"),
    HorizontalFlexLayout = require(PATH .. ".Layouts.HorizontalFlexLayout"),
    HorizontalWrapLayout = require(PATH .. ".Layouts.HorizontalWrapLayout"),
    VerticalFlexLayout = require(PATH .. ".Layouts.VerticalFlexLayout"),
  },
  Leaderboard = require(PATH .. ".Leaderboard"),
  ---@source LevelSlider.lua
  ---@type LevelSlider
  LevelSlider = require(PATH .. ".LevelSlider"),
  ---@source MenuItem.lua
  ---@type MenuItem
  MenuItem = require(PATH .. ".MenuItem"),
  MultiPlayerSelectionWrapper = require(PATH .. ".MultiPlayerSelectionWrapper"),
  PagedUniGrid = require(PATH .. ".PagedUniGrid"),
  PanelCarousel = require(PATH .. ".PanelCarousel"),
  ---@source PassThroughElement.lua
  ---@type PassThroughElement
  PassThroughElement = require(PATH .. ".PassThroughElement"),
  ---@source PixelFontLabel.lua
  ---@type PixelFontLabel
  PixelFontLabel = require(PATH .. ".PixelFontLabel"),
  ---@source ScrollContainer.lua
  ---@type ScrollContainer
  ScrollContainer = require(PATH .. ".ScrollContainer"),
  ScrollText = require(PATH .. ".ScrollText"),
  ---@source Slider.lua
  ---@type Slider
  Slider = require(PATH .. ".Slider"),
  StackPanel = require(PATH .. ".StackPanel"),
  StageCarousel = require(PATH .. ".StageCarousel"),
  Stepper = require(PATH .. ".Stepper"),
  ---@source TextButton.lua
  ---@type TextButton
  TextButton = require(PATH .. ".TextButton"),
  ---@source UiElement.lua
  ---@type UiElement
  ---@class UiElement
  UiElement = require(PATH .. ".UIElement"),
  ---@source UniSizedContainer.lua
  ---@type UniSizedContainer
  UniSizedContainer = require(PATH .. ".UniSizedContainer"),
  ValueLabel = require(PATH .. ".ValueLabel"),
  ---@source VerticalMenu.lua
  ---@type VerticalMenu
  VerticalMenu = require(PATH .. ".VerticalMenu"),
}

-- the default layout
ui.UiElement.layout = ui.Layouts.VerticalFlexLayout

return ui