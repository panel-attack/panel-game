local SceneAnimation = require("client.src.graphics.SceneAnimation")
local Animator = require("client.src.graphics.Animator")

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
  local ok, err = pcall(SceneAnimation, fileName, nil, Animator())
  assert(not ok, reason)
  assert(tostring(err):find(fileName, 1, true), "The error should name the file, got: " .. tostring(err))
end

local function testTracksAnimateWhenTheAnimatorUpdates()
  local animator = Animator()
  local animation = SceneAnimation("scene.json", nil, animator)

  animator:update(0.5)

  assertApproxEqual(animation.drawables[1].children[1].alpha, 0.5, "The track should be half way")
end

local function testKeepsItsDrawablesWhileNothingChanged()
  local animator = Animator()
  local animation = SceneAnimation("scene.json", nil, animator)
  local drawables = animation.drawables

  animation:play(animator)
  animator:update(0.1)

  assert(animation.drawables == drawables, "The drawables should not be reloaded")
end

local function testReloadsFromTheNewThemeAfterTheThemeChanged()
  local animator = Animator()
  local animation = SceneAnimation("scene.json", nil, animator)

  config.theme = "SceneAnimationOtherTheme"
  animation:play(animator)

  assertApproxEqual(animation.drawables[1].children[1].alpha, 0.25, "The drawable should come from the new theme")
end

local function testReloadsAfterTheScaleChanged()
  local animator = Animator()
  local animation = SceneAnimation("scene.json", nil, animator)
  local drawables = animation.drawables

  GAME.canvasXScale = GAME.canvasXScale + 1
  animation:play(animator)

  assert(animation.drawables ~= drawables, "The drawables should be reloaded for the new scale")
end

-- A scene is drawn at the canvas's snapped scale, so a scale change that snaps to the same one leaves it as it is
local function testKeepsItsDrawablesWhileTheSnappedScaleIsTheSame()
  GAME.canvasXScale = 1.5
  local animator = Animator()
  local animation = SceneAnimation("scene.json", nil, animator)
  local drawables = animation.drawables

  GAME.canvasXScale = 1.75
  animation:play(animator)

  assert(animation.drawables == drawables, "The drawables should not be reloaded for a scale that snaps to the same one")
end

-- The images a reload replaces are freed at once, as the garbage collector doesn't see how much memory they hold
local function testReloadFreesTheImagesItReplaces()
  if not love.graphics.isActive() then
    -- without a window there are no run images
    return
  end
  local animator = Animator()
  local animation = SceneAnimation("stillParts.json", nil, animator)
  local runImage = animation.drawables[1].bakedRun.texture

  GAME.canvasXScale = GAME.canvasXScale + 1
  animation:play(animator)

  assert(not pcall(runImage.getWidth, runImage), "The old run image should be freed")
end

local function testReloadedTracksStartOver()
  local animator = Animator()
  local animation = SceneAnimation("scene.json", nil, animator)
  animator:update(0.5)

  GAME.canvasXScale = GAME.canvasXScale + 1
  animation:play(animator)

  assertApproxEqual(animation.drawables[1].children[1].alpha, 1, "The reloaded track should start from the beginning")
end

-- The drawables a reload replaces stop animating, so the animator doesn't keep running tracks nothing draws
local function testAReloadStopsTheOldTracks()
  local animator = Animator()
  local animation = SceneAnimation("scene.json", nil, animator)
  local oldDrawable = animation.drawables[1].children[1]

  GAME.canvasXScale = GAME.canvasXScale + 1
  animation:play(animator)
  animator:update(0.5)

  assertApproxEqual(oldDrawable.alpha, 1, "The replaced drawable's track should have stopped at its start")
end

-- Playing on another animator moves its tracks there, starting over
local function testPlayingOnAnotherAnimatorMovesItsTracks()
  local first = Animator()
  local second = Animator()
  local animation = SceneAnimation("scene.json", nil, first)

  animation:play(second)
  first:update(0.5)

  assertApproxEqual(animation.drawables[1].children[1].alpha, 1, "The first animator should not run its tracks any more")
  second:update(0.5)
  assertApproxEqual(animation.drawables[1].children[1].alpha, 0.5, "The second animator should run its tracks")
end

-- A scene's still parts are drawn as one image, so drawing it costs less
local function testStillPartsAreBaked()
  if not love.graphics.isActive() then
    -- without a window there is nothing to bake into
    return
  end
  local animation = SceneAnimation("stillParts.json", nil, Animator())

  assert(animation.drawables[1].bakedRun ~= nil, "The two still parts should be baked into one image")
end

-- An animation given its folder reads the file and its image paths from that folder
local function testLoadsFromTheGivenFolder()
  local animator = Animator()
  local animation = SceneAnimation("background.json", ANIMATED_FOLDER, animator)

  assert(#animation.drawables == 1, "The animation should have the folder's one drawable")
end

-- Its folder doesn't depend on the theme, so a theme change keeps it
local function testAnAnimationFromAFolderKeepsItsDrawablesAfterAThemeChange()
  local animator = Animator()
  local animation = SceneAnimation("background.json", ANIMATED_FOLDER, animator)
  local drawables = animation.drawables

  config.theme = "SceneAnimationOtherTheme"
  animation:play(animator)

  assert(animation.drawables == drawables, "The drawables should not be reloaded")
end

local function testAnAnimationFromAFolderReloadsAfterTheScaleChanged()
  local animator = Animator()
  local animation = SceneAnimation("background.json", ANIMATED_FOLDER, animator)
  local drawables = animation.drawables

  GAME.canvasXScale = GAME.canvasXScale + 1
  animation:play(animator)

  assert(animation.drawables ~= drawables, "The drawables should be reloaded for the new scale")
end

local function testHasNothingToDrawWhenTheThemeLacksTheFile()
  local animation = SceneAnimation("missing.json", nil, Animator())

  assert(#animation.drawables == 0, "A theme without the file has nothing to draw")
end

local function testHasNothingToDrawAfterSwitchingToAThemeWithoutTheFile()
  local animator = Animator()
  local animation = SceneAnimation("scene.json", nil, animator)

  config.theme = "SceneAnimationOtherScenesTheme"
  animation:play(animator)

  assert(#animation.drawables == 0, "The new theme has no file to draw")
end

-- Returns an image recording whether it was drawn and the animator it last played on
local function recordingImage()
  local image = {drawn = false}
  image.draw = function()
    image.drawn = true
  end
  image.play = function(_, animator)
    image.animator = animator
  end
  return image
end

-- An animation given an image draws it in its file's place when the file is missing
local function testDrawsItsImageWithoutTheFile()
  local image = recordingImage()
  local animation = SceneAnimation("missing.json", nil, Animator(), image)

  animation:draw()

  assert(image.drawn, "The image should be drawn in the missing file's place")
end

local function testDoesNotDrawItsImageWithTheFile()
  local image = recordingImage()
  local animation = SceneAnimation("scene.json", nil, Animator(), image)

  animation:draw()

  assert(not image.drawn, "The image should not be drawn under the file's scene")
end

local function testPlaysItsImageWithoutTheFile()
  local image = recordingImage()
  local animator = Animator()
  local animation = SceneAnimation("missing.json", nil, animator, image)

  animation:play(animator)

  assert(image.animator == animator, "The image should play on the animator in the missing file's place")
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

withTestThemes(testTracksAnimateWhenTheAnimatorUpdates)
withTestThemes(testKeepsItsDrawablesWhileNothingChanged)
withTestThemes(testReloadsFromTheNewThemeAfterTheThemeChanged)
withTestThemes(testReloadsAfterTheScaleChanged)
withTestThemes(testKeepsItsDrawablesWhileTheSnappedScaleIsTheSame)
withTestThemes(testReloadFreesTheImagesItReplaces)
withTestThemes(testReloadedTracksStartOver)
withTestThemes(testAReloadStopsTheOldTracks)
withTestThemes(testPlayingOnAnotherAnimatorMovesItsTracks)
withTestThemes(testStillPartsAreBaked)
withTestThemes(testLoadsFromTheGivenFolder)
withTestThemes(testAnAnimationFromAFolderKeepsItsDrawablesAfterAThemeChange)
withTestThemes(testAnAnimationFromAFolderReloadsAfterTheScaleChanged)
withTestThemes(testHasNothingToDrawWhenTheThemeLacksTheFile)
withTestThemes(testHasNothingToDrawAfterSwitchingToAThemeWithoutTheFile)
withTestThemes(testDrawsItsImageWithoutTheFile)
withTestThemes(testDoesNotDrawItsImageWithTheFile)
withTestThemes(testPlaysItsImageWithoutTheFile)
withTestThemes(testRefusesAFileWithoutACanvasContainer)
withTestThemes(testRefusesACanvasContainerOfAnotherSize)
withTestThemes(testRefusesAScaledCanvasContainer)
withTestThemes(testRefusesAMovedCanvasContainer)
withTestThemes(testRefusesMoreThanOneTopLevelDrawable)
withTestThemes(testRefusesAnAnchoredCanvasContainer)
withTestThemes(testRefusesARotatedCanvasContainer)
