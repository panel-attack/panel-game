local PATH = (...):gsub('%.init$', '')

local ui = {
  ---@type fun(options: BoolSelectorOptions): BoolSelector
  ---@see BoolSelector
  BoolSelector = require(PATH .. ".BoolSelector"),
  ---@type fun(options: ButtonOptions): Button
  ---@see Button
  Button = require(PATH .. ".Button"),
  ButtonGroup = require(PATH .. ".ButtonGroup"),
  Carousel = require(PATH .. ".Carousel"),
  Focusable = require(PATH .. ".Focusable"),
  FocusDirector = require(PATH .. ".FocusDirector"),
  Grid = require(PATH .. ".Grid"),
  GridCursor = require(PATH .. ".GridCursor"),
  ImageContainer = require(PATH .. ".ImageContainer"),
  InputField = require(PATH .. ".InputField"),
  ---@type fun(options: LabelOptions): Label
  ---@see Label
  Label = require(PATH .. ".Label"),
  Leaderboard = require(PATH .. ".Leaderboard"),
  ---@type fun(options: SliderOptions): LevelSlider
  ---@see LevelSlider
  LevelSlider = require(PATH .. ".LevelSlider"),
  Menu = require(PATH .. ".Menu"),
  MenuItem = require(PATH .. ".MenuItem"),
  MultiPlayerSelectionWrapper = require(PATH .. ".MultiPlayerSelectionWrapper"),
  PagedUniGrid = require(PATH .. ".PagedUniGrid"),
  PanelCarousel = require(PATH .. ".PanelCarousel"),
  ---@type fun(options: PixelFontLabelOptions): PixelFontLabel
  ---@see PixelFontLabel
  PixelFontLabel = require(PATH .. ".PixelFontLabel"),
  ---@type fun(options: ScrollContainerOptions): ScrollContainer
  ---@see ScrollContainer
  ScrollContainer = require(PATH .. ".ScrollContainer"),
  ScrollText = require(PATH .. ".ScrollText"),
  ---@type fun(options: SliderOptions): Slider
  ---@see Slider
  Slider = require(PATH .. ".Slider"),
  StackPanel = require(PATH .. ".StackPanel"),
  StageCarousel = require(PATH .. ".StageCarousel"),
  Stepper = require(PATH .. ".Stepper"),
  ---@type fun(options: TextButtonOptions): TextButton
  ---@see TextButton
  TextButton = require(PATH .. ".TextButton"),
  ---@type fun(options:UiElementOptions): UiElement
  ---@see UiElement
  UiElement = require(PATH .. ".UIElement"),
  ValueLabel = require(PATH .. ".ValueLabel"),
}

return ui