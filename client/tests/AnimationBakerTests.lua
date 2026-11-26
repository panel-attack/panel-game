local AnimationBaker = require("client.src.graphics.AnimationBaker")
local AnimationLoader = require("client.src.graphics.AnimationLoader")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local Animator = require("client.src.graphics.Animator")
local consts = require("common.engine.consts")
local TestUtils = require("common.tests.TestUtils")
local FileUtils = require("client.src.FileUtils")

local TEST_PATH = "client/tests/AnimationLoaderTestData/"

local assertEqual = TestUtils.assertEqual

-- Returns the ids of the nodes in each run, joined so a whole result compares as one string
local function runIds(runs)
  local parts = {}
  for _, run in ipairs(runs) do
    local ids = {}
    for _, node in ipairs(run) do
      ids[#ids + 1] = node.id
    end
    parts[#parts + 1] = table.concat(ids, ",")
  end
  return table.concat(parts, " | ")
end

-- Returns a node drawing an image with the defaults loadFromFile gives, with the given fields set
local function node(id, fields)
  local result = {
    id = id, texture = {}, animationTracks = {}, children = {}, blendMode = "alpha", alphaMode = "alphamultiply", stencil = false
  }
  for key, value in pairs(fields or {}) do
    result[key] = value
  end
  return result
end

local TRACK = {{steps = {}}}

local stillRuns = AnimationBaker.findStillRuns

-- Still parts between moving ones are split into one run before the moving part and one after it
local function testStillPartsAroundAMovingOneFormTwoRuns()
  local group = {id = "FrontGroup", animationTracks = {}, children = {node("Front"), node("FrontChild")}}
  local runs = stillRuns({node("Back"), node("BackOverlap"), node("Mover", {animationTracks = TRACK}), group})

  assertEqual(runIds(runs), "Back,BackOverlap | Front,FrontChild", "The parts before and after Mover should be two runs")
end

-- A part inside a moving group moves with it, so it isn't still
local function testPartInsideAMovingGroupIsNotStill()
  local group = node("Group", {texture = nil, animationTracks = TRACK, children = {node("Inside")}})
  local runs = stillRuns({node("A"), group, node("B"), node("C")})

  assertEqual(runIds(runs), "B,C", "The part in the moving group should end the first run")
end

-- A part blended any other way than plain alpha can't be drawn into an image first and look the same
local function testOtherBlendModeEndsARun()
  local runs = stillRuns({node("A"), node("B"), node("Added", {blendMode = "add"}), node("C"), node("D")})

  assertEqual(runIds(runs), "A,B | C,D", "The added part should split the runs")
end

-- A repeated image tiles over its size through its quad, which a run image doesn't, so it isn't baked whether or not it scrolls
local function testRepeatedImageEndsARun()
  local runs = stillRuns({node("A"), node("B"), node("Repeated", {isRepeated = true}), node("C"), node("D")})

  assertEqual(runIds(runs), "A,B | C,D", "The repeated part should split the runs")
end

-- A stencil masks with the siblings drawn before it, so none of them can be drawn ahead of time
local function testSiblingsOfAStencilAreNotStill()
  local group = {id = "Group", animationTracks = {}, children = {node("Mask"), node("Masked", {stencil = true})}}
  local runs = stillRuns({node("A"), node("B"), group, node("C"), node("D")})

  assertEqual(runIds(runs), "A,B | C,D", "The stencil and the siblings it masks with should split the runs")
end

-- A lone still part is already one image, so baking it gains nothing
local function testLoneStillPartIsNotARun()
  local runs = stillRuns({node("Lone"), node("Moving", {animationTracks = TRACK}), node("A"), node("B")})

  assertEqual(runIds(runs), "A,B", "Only the two still parts together should be a run")
end

-- Draws the drawables into a new canvas at the given pixel density and returns the pixels
local function render(drawables, density)
  local canvas = love.graphics.newCanvas(200, 140, {dpiscale = density})
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.2, 0.3, 0.4, 1)
  AnimationLoader.drawDrawables(drawables)
  love.graphics.pop()
  return GraphicsUtil.readbackTexture(canvas)
end

-- Loads the bake scene baked at the given density, and as data, which draws each part on its own
local function loadBakedAndPartByPart(drawScale, bakedAnimator, partByPartAnimator)
  local baked = AnimationLoader.loadFromFile(TEST_PATH, TEST_PATH .. "bakeScene.json", bakedAnimator, drawScale)
  local partByPart = AnimationLoader.loadFromData(TEST_PATH, FileUtils.readJsonFile(TEST_PATH .. "bakeScene.json"), partByPartAnimator)
  assert(baked[1].bakedRun, "The file's still parts should be baked")
  return baked, partByPart
end

-- A baked scene looks the same as one drawn part by part, while its moving part moves
local function testBakedSceneDrawsTheSame()
  local bakedAnimator, partByPartAnimator = Animator(), Animator()
  local baked, partByPart = loadBakedAndPartByPart(1, bakedAnimator, partByPartAnimator)

  local before = TestUtils.largestPixelDifference(render(partByPart, 1), render(baked, 1))
  assert(before <= 1, "The baked scene should look the same before anything moves")
  bakedAnimator:update(0.5)
  partByPartAnimator:update(0.5)
  local after = TestUtils.largestPixelDifference(render(partByPart, 1), render(baked, 1))
  assert(after <= 1, "The baked scene should look the same once Mover moved")
end

-- A run baked at a density its area's pixels don't divide by still lands on the same pixels as its parts
local function testBakedSceneDrawsTheSameAtAFractionalDensity()
  local baked, partByPart = loadBakedAndPartByPart(1.5, Animator(), Animator())

  local difference = TestUtils.largestPixelDifference(render(partByPart, 1.5), render(baked, 1.5))
  assert(difference <= 1, "The baked scene should look the same at 1.5x, it is " .. difference .. "/255 off")
end

-- Each run of still parts is drawn as one image, so the scene draws one image per run plus its moving part
local function testEachRunIsDrawnAsOneImage()
  local baked = AnimationLoader.loadFromFile(TEST_PATH, TEST_PATH .. "bakeScene.json", Animator(), 1)
  local draws = 0
  local originalDraw = love.graphics.draw
  love.graphics.draw = function(...)
    draws = draws + 1
    originalDraw(...)
  end
  local ok, err = pcall(render, baked, 1)
  love.graphics.draw = originalDraw
  assert(ok, err)

  assertEqual(draws, 3, "Two run images and Mover should be drawn")
end

-- A run is baked only as far as the canvas, as nothing still ever moves onto it
local function testRunIsCroppedToTheShownArea()
  local baked = AnimationLoader.loadFromFile(TEST_PATH, TEST_PATH .. "runPastTheCanvas.json", Animator(), 1)

  local run = baked[1].bakedRun.texture
  assertEqual(run:getPixelWidth(), consts.CANVAS_WIDTH - 1250, "The run should stop at the canvas's right edge")
end

local function runAllTests()
  testStillPartsAroundAMovingOneFormTwoRuns()
  testPartInsideAMovingGroupIsNotStill()
  testOtherBlendModeEndsARun()
  testRepeatedImageEndsARun()
  testSiblingsOfAStencilAreNotStill()
  testLoneStillPartIsNotARun()
  -- without a window there is nothing to bake into
  if love.graphics.isActive() then
    testBakedSceneDrawsTheSame()
    testBakedSceneDrawsTheSameAtAFractionalDensity()
    testEachRunIsDrawnAsOneImage()
    testRunIsCroppedToTheShownArea()
  end
end

runAllTests()
