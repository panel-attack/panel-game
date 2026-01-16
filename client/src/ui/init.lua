local import = require("common.lib.import")

--[[
tag each with
---@source relative path
that way "Go to source" on an import of ui elsewhere will lead to the respective source instead of this file
the "./" is assumed given for relative paths but it's still a path so adding the file extension is necessary
when addressing files in subdirectories of ui use forward slashes as the path separator
https://luals.github.io/wiki/annotations/#source
]]


local ui = {
  ---@source BoolSelector.lua
  BoolSelector = import("./BoolSelector"),
  ---@source Button.lua
  Button = import("./Button"),
  ---@source ButtonGroup.lua
  ButtonGroup = import("./ButtonGroup"),
  Carousel = import("./Carousel"),
  Focusable = import("./Focusable"),
  FocusDirector = import("./FocusDirector"),
  Grid = import("./Grid"),
  GridCursor = import("./GridCursor"),
  ---@source ImageButton.lua
  ImageButton = import("./ImageButton"),
  ---@source ImageContainer.lua
  ImageContainer = import("./ImageContainer"),
  ---@source InputField.lua
  InputField = import("./InputField"),
  ---@source Label.lua
  ---@type Label
  Label = import("./Label"),
  Leaderboard = import("./Leaderboard"),
  ---@source LevelSlider.lua
  ---@type LevelSlider
  LevelSlider = import("./LevelSlider"),
  ---@source Menu.lua
  Menu = import("./Menu"),
  ---@source MenuItem.lua
  MenuItem = import("./MenuItem"),
  MultiPlayerSelectionWrapper = import("./MultiPlayerSelectionWrapper"),
  PagedUniGrid = import("./PagedUniGrid"),
  ---@source PanelCarousel.lua
  PanelCarousel = import("./PanelCarousel"),
  ---@source PixelFontLabel.lua
  ---@type PixelFontLabel
  PixelFontLabel = import("./PixelFontLabel"),
  ---@source ScrollContainer.lua
  ---@type ScrollContainer
  ScrollContainer = import("./ScrollContainer"),
  ScrollText = import("./ScrollText"),
  ---@source Slider.lua
  ---@type Slider
  Slider = import("./Slider"),
  ---@source StackElement.lua
  StackElement = import("./StackElement"),
  StackPanel = import("./StackPanel"),
  StageCarousel = import("./StageCarousel"),
  Stepper = import("./Stepper"),
  ---@source TextButton.lua
  ---@type TextButton
  TextButton = import("./TextButton"),
  ---@source UiElement.lua
  ---@type UiElement
  UiElement = import("./UIElement"),
  ValueLabel = import("./ValueLabel"),
}

return ui