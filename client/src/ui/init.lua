local import = require("common.lib.import")

--[[
tag each with
---@source relative path
that way "Go to source" on an import of ui elsewhere will lead to the respective source instead of this one
the "./" is assumed given for relative paths but it's still a path so adding the extension is necessary
when addressing files in subdirectories (layouts) use forward slashes as the path separator
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
  ---@source CharacterButton.lua
  ---@type CharacterButton
  CharacterButton = import("./CharacterButton"),
  ---@source Cursor.lua
  ---@type Cursor
  Cursor = import("./Cursor"),
  ---@source CursorInteractable
  CursorInteractable = import("./CursorInteractable"),
  ---@source CursorNavigable.lua
  CursorNavigable = import("./CursorNavigable"),
  Focusable = import("./Focusable"),
  FocusDirector = import("./FocusDirector"),
  Grid = import("./Grid"),
  GridCursor = import("./GridCursor"),
  ---@source ImageContainer.lua
  ImageContainer = import("./ImageContainer"),
  ---@source ImageCursor.lua
  ImageCursor = import("./ImageCursor"),
  ---@source InputField.lua
  InputField = import("./InputField"),
  ---@source Label.lua
  ---@type Label
  Label = import("./Label"),
  Layouts = {
    ---@source Layouts/AdaptiveFlexLayout.lua
    AdaptiveFlexLayout = import("./Layouts.AdaptiveFlexLayout"),
    ---@source Layouts/HorizontalFlexLayout.lua
    HorizontalFlexLayout = import("./Layouts.HorizontalFlexLayout"),
    ---@source Layouts/HorizontalWrapLayout.lua
    HorizontalWrapLayout = import("./Layouts.HorizontalWrapLayout"),
    ---@source Layouts/VerticalFlexLayout.lua
    VerticalFlexLayout = import("./Layouts.VerticalFlexLayout"),
  },
  Leaderboard = import("./Leaderboard"),
  ---@source LevelSlider.lua
  ---@type LevelSlider
  LevelSlider = import("./LevelSlider"),
  ---@source MenuItem.lua
  ---@type MenuItem
  MenuItem = import("./MenuItem"),
  MultiPlayerSelectionWrapper = import("./MultiPlayerSelectionWrapper"),
  PagedUniGrid = import("./PagedUniGrid"),
  PanelCarousel = import("./PanelCarousel"),
  ---@source PanelSetButton.lua
  PanelSetButton = import("./PanelSetButton"),
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
  StackPanel = import("./StackPanel"),
  StageCarousel = import("./StageCarousel"),
  Stepper = import("./Stepper"),
  ---@source TextButton.lua
  ---@type TextButton
  TextButton = import("./TextButton"),
  ---@source UiElement.lua
  ---@type UiElement
  ---@class UiElement
  UiElement = import("./UIElement"),
  ---@source UniSizedContainer.lua
  ---@type UniSizedContainer
  UniSizedContainer = import("./UniSizedContainer"),
  ValueLabel = import("./ValueLabel"),
  ---@source VerticalMenu.lua
  ---@type VerticalMenu
  VerticalMenu = import("./VerticalMenu"),
}

-- the default layout
ui.UiElement.layout = ui.Layouts.VerticalFlexLayout

return ui