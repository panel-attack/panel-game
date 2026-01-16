-- import is getting "live replaced" for intellisense via the lua LS plugin so the editor incorrectly detects it as unused-local
-- but without lua LS it is a real function that manages the relative require
---@diagnostic disable-next-line: unused-local
local import = require("common.lib.import")

--[[
tag each with
---@source relative path
that way "Go to source" on an import of ui elsewhere will lead to the respective source instead of this file
the "./" is assumed given for relative paths but it's still a path so adding the file extension is necessary
when addressing files in subdirectories of ui use forward slashes as the path separator
https://luals.github.io/wiki/annotations/#source

Intellisense for constructors that have their constructor annotated usually works fine if you type
ui.UiElement({})
and then navigate back into the {} and hit Ctrl+Space for suggestions

"Go to source" on functions will work after annotating either
---@operator call(argType): classname
or
---@overload fun(options: argType): classname
on the class itself as luaLS only then correctly infers the return from the constructor
]]


local ui = {
  ---@source BoolSelector.lua
  BoolSelector = import("./BoolSelector"),
  ---@source Button.lua
  Button = import("./Button"),
  ---@source ButtonGroup.lua
  ButtonGroup = import("./ButtonGroup"),
  ---@source Carousel.lua
  Carousel = import("./Carousel"),
  ---@source Focusable.lua
  Focusable = import("./Focusable"),
  ---@source FocusDirector.lua
  FocusDirector = import("./FocusDirector"),
  ---@source Grid.lua
  Grid = import("./Grid"),
  ---@source GridCursor.lua
  GridCursor = import("./GridCursor"),
  ---@source ImageButton.lua
  ImageButton = import("./ImageButton"),
  ---@source ImageContainer.lua
  ImageContainer = import("./ImageContainer"),
  ---@source InputField.lua
  InputField = import("./InputField"),
  ---@source Label.lua
  Label = import("./Label"),
  ---@source Leaderboard.lua
  Leaderboard = import("./Leaderboard"),
  ---@source LevelSlider.lua
  LevelSlider = import("./LevelSlider"),
  ---@source Menu.lua
  Menu = import("./Menu"),
  ---@source MenuItem.lua
  MenuItem = import("./MenuItem"),
  ---@source MultiPlayerSelectionWrapper.lua
  MultiPlayerSelectionWrapper = import("./MultiPlayerSelectionWrapper"),
  ---@source PagedUniGrid.lua
  PagedUniGrid = import("./PagedUniGrid"),
  ---@source PanelCarousel.lua
  PanelCarousel = import("./PanelCarousel"),
  ---@source PixelFontLabel.lua
  PixelFontLabel = import("./PixelFontLabel"),
  ---@source ScrollContainer.lua
  ScrollContainer = import("./ScrollContainer"),
  ---@source ScrollText.lua
  ScrollText = import("./ScrollText"),
  ---@source Slider.lua
  Slider = import("./Slider"),
  ---@source StackElement.lua
  StackElement = import("./StackElement"),
  ---@source StackPanel.lua
  StackPanel = import("./StackPanel"),
  ---@source StageCarousel.lua
  StageCarousel = import("./StageCarousel"),
  ---@source Stepper.lua
  Stepper = import("./Stepper"),
  ---@source TextButton.lua
  TextButton = import("./TextButton"),
  ---@source UiElement.lua
  UiElement = import("./UIElement"),
  ---@source ValueLabel.lua
  ValueLabel = import("./ValueLabel"),
}

return ui