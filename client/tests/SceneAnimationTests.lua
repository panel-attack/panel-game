local SceneAnimation = require("client.src.graphics.SceneAnimation")

local TEST_DATA = "client/tests/SceneAnimationTestData/"
-- a stage folder holding an animation, read from its own folder instead of the theme's
local ANIMATED_FOLDER = "client/tests/StageBackgroundTestData/AnimatedStage"

local function assertApproxEqual(actual, expected, message)
  if math.abs(actual - expected) > 0.001 then
    error(string.format("%s: Expected %f, got %f", message, expected, actual))
  end
end

-- Runs the test with two test themes registered and the first one selected, putting the real theme and scale back afterwards
local function withTestThemes(test)
  local originalTheme = config.theme
  local originalScale = GAME.canvasXScale
  themes.SceneAnimationFirstTheme = {path = TEST_DATA .. "FirstTheme"}
  themes.SceneAnimationOtherTheme = {path = TEST_DATA .. "OtherTheme"}
  themes.SceneAnimationOtherScenesTheme = {path = TEST_DATA .. "OtherScenesTheme"}
  config.theme = "SceneAnimationFirstTheme"
  local ok, err = pcall(test)
  config.theme = originalTheme
  GAME.canvasXScale = originalScale
  themes.SceneAnimationFirstTheme = nil
  themes.SceneAnimationOtherTheme = nil
  themes.SceneAnimationOtherScenesTheme = nil
  if not ok then
    error(err, 0)
  end
end

-- Asserts that loading the file fails with an error naming the file
local function assertRefused(fileName, reason)
  local ok, err = pcall(SceneAnimation, fileName)
  assert(not ok, reason)
  assert(tostring(err):find(fileName, 1, true), "The error should name the file, got: " .. tostring(err))
end

local function testTracksAnimateWhenUpdated()
  local animation = SceneAnimation("scene.json")

  animation:update(0.5)

  assertApproxEqual(animation.drawables[1].children[1].alpha, 0.5, "The track should be half way")
end

local function testKeepsItsDrawablesWhileNothingChanged()
  local animation = SceneAnimation("scene.json")
  local drawables = animation.drawables

  animation:update(0.1)

  assert(animation.drawables == drawables, "The drawables should not be reloaded")
end

local function testReloadsFromTheNewThemeAfterTheThemeChanged()
  local animation = SceneAnimation("scene.json")

  config.theme = "SceneAnimationOtherTheme"
  animation:update(0)

  assertApproxEqual(animation.drawables[1].children[1].alpha, 0.25, "The drawable should come from the new theme")
end

local function testReloadsAfterTheScaleChanged()
  local animation = SceneAnimation("scene.json")
  local drawables = animation.drawables

  GAME.canvasXScale = GAME.canvasXScale + 1
  animation:update(0)

  assert(animation.drawables ~= drawables, "The drawables should be reloaded for the new scale")
end

local function testReloadedTracksStartOver()
  local animation = SceneAnimation("scene.json")
  animation:update(0.5)

  GAME.canvasXScale = GAME.canvasXScale + 1
  animation:update(0)

  assertApproxEqual(animation.drawables[1].children[1].alpha, 1, "The reloaded track should start from the beginning")
end

-- An animation given its folder reads the file and its image paths from that folder
local function testLoadsFromTheGivenFolder()
  local animation = SceneAnimation("background.json", ANIMATED_FOLDER)

  assert(#animation.drawables == 1, "The animation should have the folder's one drawable")
end

-- Its folder doesn't depend on the theme, so a theme change keeps it
local function testAnAnimationFromAFolderKeepsItsDrawablesAfterAThemeChange()
  local animation = SceneAnimation("background.json", ANIMATED_FOLDER)
  local drawables = animation.drawables

  config.theme = "SceneAnimationOtherTheme"
  animation:update(0)

  assert(animation.drawables == drawables, "The drawables should not be reloaded")
end

local function testAnAnimationFromAFolderReloadsAfterTheScaleChanged()
  local animation = SceneAnimation("background.json", ANIMATED_FOLDER)
  local drawables = animation.drawables

  GAME.canvasXScale = GAME.canvasXScale + 1
  animation:update(0)

  assert(animation.drawables ~= drawables, "The drawables should be reloaded for the new scale")
end

local function testHasNothingToDrawWhenTheThemeLacksTheFile()
  local animation = SceneAnimation("missing.json")

  assert(#animation.drawables == 0, "A theme without the file has nothing to draw")
end

local function testHasNothingToDrawAfterSwitchingToAThemeWithoutTheFile()
  local animation = SceneAnimation("scene.json")

  config.theme = "SceneAnimationOtherScenesTheme"
  animation:update(0)

  assert(#animation.drawables == 0, "The new theme has no file to draw")
end

-- Returns an image recording whether it was drawn and how far it was updated
local function recordingImage()
  local image = {drawn = false, updated = 0}
  image.draw = function() image.drawn = true end
  image.update = function(_, dt) image.updated = image.updated + dt end
  return image
end

-- An animation given an image draws it in its file's place when the file is missing
local function testDrawsItsImageWithoutTheFile()
  local image = recordingImage()
  local animation = SceneAnimation("missing.json", nil, image)

  animation:draw()

  assert(image.drawn, "The image should be drawn in the missing file's place")
end

local function testDoesNotDrawItsImageWithTheFile()
  local image = recordingImage()
  local animation = SceneAnimation("scene.json", nil, image)

  animation:draw()

  assert(not image.drawn, "The image should not be drawn under the file's scene")
end

local function testUpdatesItsImageWithoutTheFile()
  local image = recordingImage()
  local animation = SceneAnimation("missing.json", nil, image)

  animation:update(0.5)

  assertApproxEqual(image.updated, 0.5, "The image should be updated in the missing file's place")
end

-- A scene is drawn straight onto the canvas, so its file's one top-level drawable is a container the canvas's size
local function testRefusesAFileWithoutACanvasContainer()
  assertRefused("noCanvas.json", "A file whose top-level drawable is an image should be refused")
end

local function testRefusesACanvasContainerOfAnotherSize()
  assertRefused("wrongSizeCanvas.json", "A 768x512 container should be refused")
end

local function testRefusesAScaledCanvasContainer()
  assertRefused("scaledCanvas.json", "A container scaled up to the canvas should be refused")
end

local function testRefusesAMovedCanvasContainer()
  assertRefused("movedCanvas.json", "A container moved off the canvas's origin should be refused")
end

local function testRefusesMoreThanOneTopLevelDrawable()
  assertRefused("twoCanvases.json", "A file with two top-level drawables should be refused")
end

-- An anchor other than the top left shifts the container off the canvas's origin
local function testRefusesAnAnchoredCanvasContainer()
  assertRefused("anchoredCanvas.json", "A container anchored at its center should be refused")
end

local function testRefusesARotatedCanvasContainer()
  assertRefused("rotatedCanvas.json", "A rotated container should be refused")
end

withTestThemes(testTracksAnimateWhenUpdated)
withTestThemes(testKeepsItsDrawablesWhileNothingChanged)
withTestThemes(testReloadsFromTheNewThemeAfterTheThemeChanged)
withTestThemes(testReloadsAfterTheScaleChanged)
withTestThemes(testReloadedTracksStartOver)
withTestThemes(testLoadsFromTheGivenFolder)
withTestThemes(testAnAnimationFromAFolderKeepsItsDrawablesAfterAThemeChange)
withTestThemes(testAnAnimationFromAFolderReloadsAfterTheScaleChanged)
withTestThemes(testHasNothingToDrawWhenTheThemeLacksTheFile)
withTestThemes(testHasNothingToDrawAfterSwitchingToAThemeWithoutTheFile)
withTestThemes(testDrawsItsImageWithoutTheFile)
withTestThemes(testDoesNotDrawItsImageWithTheFile)
withTestThemes(testUpdatesItsImageWithoutTheFile)
withTestThemes(testRefusesAFileWithoutACanvasContainer)
withTestThemes(testRefusesACanvasContainerOfAnotherSize)
withTestThemes(testRefusesAScaledCanvasContainer)
withTestThemes(testRefusesAMovedCanvasContainer)
withTestThemes(testRefusesMoreThanOneTopLevelDrawable)
withTestThemes(testRefusesAnAnchoredCanvasContainer)
withTestThemes(testRefusesARotatedCanvasContainer)
