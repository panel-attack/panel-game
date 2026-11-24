local consts = require("common.engine.consts")

-- Runs func with the given scale type, restoring the config and the game's scale and position after.
local function withGameScaleType(gameScaleType, func)
  local oldGameScaleType = config.gameScaleType
  local oldX, oldY, oldXScale, oldYScale = GAME.canvasX, GAME.canvasY, GAME.canvasXScale, GAME.canvasYScale
  config.gameScaleType = gameScaleType
  local success, err = pcall(func)
  config.gameScaleType = oldGameScaleType
  GAME.canvasX, GAME.canvasY, GAME.canvasXScale, GAME.canvasYScale = oldX, oldY, oldXScale, oldYScale
  if not success then
    error(err, 0)
  end
end

local function testAutoScaleFitsAWindowSmallerThanTheCanvas()
  withGameScaleType("auto", function()
    -- a 1600x720 phone screen without its status and navigation bars
    GAME:updateCanvasPositionAndScale(1520, 678)

    local fitScale = 678 / consts.CANVAS_HEIGHT
    assert(math.floatsEqualWithPrecision(GAME.canvasXScale, fitScale, 4),
      "auto should fit a window too small for scale 1, expected " .. fitScale .. " but got " .. GAME.canvasXScale)
    assert(math.floatsEqualWithPrecision(GAME.canvasYScale, fitScale, 4),
      "auto should fit a window too small for scale 1, expected " .. fitScale .. " but got " .. GAME.canvasYScale)
  end)
end

testAutoScaleFitsAWindowSmallerThanTheCanvas()

local function testAutoScaleKeepsWholeStepsWhenTheCanvasFits()
  withGameScaleType("auto", function()
    GAME:updateCanvasPositionAndScale(2000, 1100)

    assert(GAME.canvasXScale == 1.5 and GAME.canvasYScale == 1.5,
      "auto should pick the largest step that fits, expected 1.5 but got " .. GAME.canvasXScale .. "," .. GAME.canvasYScale)
  end)
end

testAutoScaleKeepsWholeStepsWhenTheCanvasFits()
