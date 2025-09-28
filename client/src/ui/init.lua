local PATH = (...):gsub('%.init$', '')

local ui = {
  ---@see BoolSelector
  ---@type fun(options: BoolSelectorOptions): BoolSelector
  BoolSelector = require(PATH .. ".BoolSelector"),
  ---@see Button
  ---@type fun(options: ButtonOptions): Button
  Button = require(PATH .. ".Button"),
  ButtonGroup = require(PATH .. ".ButtonGroup"),
  Carousel = require(PATH .. ".Carousel"),
  Focusable = require(PATH .. ".Focusable"),
  FocusDirector = require(PATH .. ".FocusDirector"),
  Grid = require(PATH .. ".Grid"),
  GridCursor = require(PATH .. ".GridCursor"),
  ImageContainer = require(PATH .. ".ImageContainer"),
  InputField = require(PATH .. ".InputField"),
  ---@see Label
  ---@type fun(options: LabelOptions): Label
  Label = require(PATH .. ".Label"),
  Leaderboard = require(PATH .. ".Leaderboard"),
  ---@see LevelSlider
  ---@type fun(options: SliderOptions): LevelSlider
  LevelSlider = require(PATH .. ".LevelSlider"),
  Menu = require(PATH .. ".Menu"),
  MenuItem = require(PATH .. ".MenuItem"),
  MultiPlayerSelectionWrapper = require(PATH .. ".MultiPlayerSelectionWrapper"),
  PagedUniGrid = require(PATH .. ".PagedUniGrid"),
  PanelCarousel = require(PATH .. ".PanelCarousel"),
  ---@see PixelFontLabel
  ---@type fun(options: PixelFontLabelOptions): PixelFontLabel
  PixelFontLabel = require(PATH .. ".PixelFontLabel"),
  ---@see ScrollContainer
  ---@type fun(options: ScrollContainerOptions): ScrollContainer
  ScrollContainer = require(PATH .. ".ScrollContainer"),
  ScrollText = require(PATH .. ".ScrollText"),
  ---@see Slider
  ---@type fun(options: SliderOptions): Slider
  Slider = require(PATH .. ".Slider"),
  StackPanel = require(PATH .. ".StackPanel"),
  StageCarousel = require(PATH .. ".StageCarousel"),
  Stepper = require(PATH .. ".Stepper"),
  ---@see TextButton
  ---@type fun(options: TextButtonOptions): TextButton
  TextButton = require(PATH .. ".TextButton"),
  ---@see UiElement
  ---@type fun(options:UiElementOptions): UiElement
  UiElement = require(PATH .. ".UIElement"),
  ValueLabel = require(PATH .. ".ValueLabel"),
}

return ui