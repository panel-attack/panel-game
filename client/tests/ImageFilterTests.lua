local GraphicsUtil = require("client.src.graphics.graphics_util")
local Character = require("client.src.mods.Character")
local Stage = require("client.src.mods.Stage")
local Theme = require("client.src.mods.Theme")
local json = require("common.lib.dkjson")
require("client.src.mods.Panels")

local TEST_DIRECTORY = "imageFilterTests"

local function writePng(path, width, height)
  local imageData = love.image.newImageData(width, height or width)
  imageData:mapPixel(function() return 1, 1, 1, 1 end)
  love.filesystem.write(path, imageData:encode("png"))
end

local function writeJson(path, data)
  love.filesystem.write(path, json.encode(data))
end

local function removeDirectory(folder)
  for _, name in ipairs(love.filesystem.getDirectoryItems(folder)) do
    local path = folder .. "/" .. name
    if love.filesystem.getInfo(path, "directory") then
      removeDirectory(path)
    else
      love.filesystem.remove(path)
    end
  end
  love.filesystem.remove(folder)
end

local function filterOf(texture)
  local filterMin = texture:getFilter()
  return filterMin
end

-- the issue reproduces at 1.5x (a 1920x1080 window), where nearest draws uneven pixel columns
local function atCanvasScale(scale, func)
  local oldScale = GAME.canvasXScale
  GAME.canvasXScale = scale
  local success, err = pcall(func)
  GAME.canvasXScale = oldScale
  removeDirectory(TEST_DIRECTORY)
  if not success then
    error(err, 0)
  end
end

local function createSinglePanelSet(name, size, firstImageSize)
  local path = TEST_DIRECTORY .. "/" .. name
  love.filesystem.createDirectory(path)
  writeJson(path .. "/config.json", {id = name})
  for color = 1, 8 do
    for index = 1, 7 do
      writePng(path .. "/panel" .. color .. index .. ".png", index == 1 and firstImageSize or size)
    end
  end
  local panelSet = Panels(path, name)
  assert(panelSet:json_init())
  panelSet:load()
  return panelSet
end

local function createSheetPanelSet(name, size)
  local path = TEST_DIRECTORY .. "/" .. name
  love.filesystem.createDirectory(path)
  local animationConfig = {}
  for _, state in ipairs({"normal", "landing", "swapping", "flash", "face", "popping", "hovering", "falling", "dimmed", "dead", "danger", "garbagePop"}) do
    animationConfig[state] = {row = 1, frames = 1}
  end
  writeJson(path .. "/config.json", {id = name, type = "sheet", animationConfig = animationConfig})
  for color = 1, 8 do
    writePng(path .. "/panel-" .. color .. ".png", size)
  end
  local panelSet = Panels(path, name)
  assert(panelSet:json_init())
  panelSet:load()
  return panelSet
end

local function testSmoothArtAtItsExpectedSizeIsLinear()
  atCanvasScale(1.5, function()
    love.filesystem.createDirectory(TEST_DIRECTORY)
    writePng(TEST_DIRECTORY .. "/smooth.png", 48)
    local image = GraphicsUtil.loadImageFromSupportedExtensions(TEST_DIRECTORY .. "/smooth", 48, 48)
    assert(filterOf(image) == "linear", "1x art at its expected size should be linear at 1.5x, got " .. filterOf(image))
  end)
end

local function testArtAtHalfItsExpectedSizeIsNearest()
  atCanvasScale(1.5, function()
    love.filesystem.createDirectory(TEST_DIRECTORY)
    writePng(TEST_DIRECTORY .. "/pixel.png", 24)
    local image = GraphicsUtil.loadImageFromSupportedExtensions(TEST_DIRECTORY .. "/pixel", 48, 48)
    assert(filterOf(image) == "nearest", "art at half its expected size should be nearest, got " .. filterOf(image))
  end)
end

local function testArtWithoutAnExpectedSizeIsLinear()
  atCanvasScale(1.5, function()
    love.filesystem.createDirectory(TEST_DIRECTORY)
    writePng(TEST_DIRECTORY .. "/unsized.png", 24)
    local image = GraphicsUtil.loadImageFromSupportedExtensions(TEST_DIRECTORY .. "/unsized")
    assert(filterOf(image) == "linear", "1x art without an expected size should be linear at 1.5x, got " .. filterOf(image))
  end)
end

local function test48pxSinglePanelSetIsLinear()
  atCanvasScale(1.5, function()
    local panelSet = createSinglePanelSet("smoothSingles", 48)
    assert(filterOf(panelSet.sheets[1]) == "linear", "48px single panel sheet should be linear, got " .. filterOf(panelSet.sheets[1]))
    assert(filterOf(panelSet.displayIcons[1]) == "linear", "48px display icon should be linear, got " .. filterOf(panelSet.displayIcons[1]))
  end)
end

local function test24pxSinglePanelSetIsNearest()
  atCanvasScale(1.5, function()
    local panelSet = createSinglePanelSet("pixelSingles", 24)
    assert(filterOf(panelSet.sheets[1]) == "nearest", "24px single panel sheet should be nearest, got " .. filterOf(panelSet.sheets[1]))
    assert(filterOf(panelSet.displayIcons[1]) == "nearest", "24px display icon should be nearest, got " .. filterOf(panelSet.displayIcons[1]))
  end)
end

local function testSinglePanelSheetFilterFollowsPanelSizeNotFirstImage()
  atCanvasScale(1.5, function()
    local panelSet = createSinglePanelSet("smallFirstImage", 48, 24)
    assert(filterOf(panelSet.sheets[1]) == "linear", "a 48px single panel sheet with a 24px first image should be linear, got " .. filterOf(panelSet.sheets[1]))
  end)
end

local function test48pxSheetPanelSetIsLinear()
  atCanvasScale(1.5, function()
    local panelSet = createSheetPanelSet("smoothSheet", 48)
    assert(filterOf(panelSet.sheets[1]) == "linear", "48px panel sheet should be linear, got " .. filterOf(panelSet.sheets[1]))
  end)
end

local function test24pxSheetPanelSetIsNearest()
  atCanvasScale(1.5, function()
    local panelSet = createSheetPanelSet("pixelSheet", 24)
    assert(filterOf(panelSet.sheets[1]) == "nearest", "24px panel sheet should be nearest, got " .. filterOf(panelSet.sheets[1]))
  end)
end

local function test1xCharacterIconIsLinear()
  atCanvasScale(1.5, function()
    local path = TEST_DIRECTORY .. "/smoothCharacter"
    love.filesystem.createDirectory(path)
    writePng(path .. "/icon.png", 84)
    local character = Character(path, "smoothCharacter")
    character:graphics_init(false, false)
    assert(filterOf(character.images.icon) == "linear", "84px character icon should be linear, got " .. filterOf(character.images.icon))
  end)
end

local function testPixelSizedStageThumbnailIsLinear()
  atCanvasScale(1.5, function()
    local path = TEST_DIRECTORY .. "/pixelStage"
    love.filesystem.createDirectory(path)
    writePng(path .. "/thumbnail.png", 40, 22)
    local stage = Stage(path, "pixelStage")
    stage:graphics_init(false, false)
    assert(filterOf(stage.images.thumbnail) == "linear", "40x22 stage thumbnail should be linear, got " .. filterOf(stage.images.thumbnail))
  end)
end

local function testPixelSizedStageBackgroundIsLinear()
  atCanvasScale(1.5, function()
    local path = TEST_DIRECTORY .. "/pixelBackground"
    love.filesystem.createDirectory(path)
    writePng(path .. "/background.png", 640, 360)
    local stage = Stage(path, "pixelBackground")
    stage:graphics_init(true, false)
    assert(filterOf(stage.images.background) == "linear", "640x360 stage background should be linear, got " .. filterOf(stage.images.background))
  end)
end

local function test2xFileAtItsExpectedSizeIsLinear()
  atCanvasScale(1.5, function()
    love.filesystem.createDirectory(TEST_DIRECTORY)
    writePng(TEST_DIRECTORY .. "/smooth@2x.png", 96)
    local image = GraphicsUtil.loadImageFromSupportedExtensions(TEST_DIRECTORY .. "/smooth", 48, 48)
    assert(filterOf(image) == "linear", "a 96px @2x file for a 48px image should be linear, got " .. filterOf(image))
  end)
end

local function testPixelArtIsNearestAt2xCanvas()
  atCanvasScale(2, function()
    love.filesystem.createDirectory(TEST_DIRECTORY)
    writePng(TEST_DIRECTORY .. "/pixel.png", 24)
    local image = GraphicsUtil.loadImageFromSupportedExtensions(TEST_DIRECTORY .. "/pixel", 48, 48)
    assert(filterOf(image) == "nearest", "a 24px image for a 48px image should be nearest at 2x, got " .. filterOf(image))
  end)
end

local function test1xMetalPanelsAreLinear()
  atCanvasScale(1.5, function()
    local panelSet = createSinglePanelSet("smoothMetals", 48)
    -- the set has no metals of its own and gets the 24x48 1x defaults
    assert(filterOf(panelSet.images.metals.left) == "linear", "24x48 metal end should be linear, got " .. filterOf(panelSet.images.metals.left))
    assert(filterOf(panelSet.images.metals.flash) == "linear", "48x48 garbage flash should be linear, got " .. filterOf(panelSet.images.metals.flash))
  end)
end

local function createCharacter(name, config, images)
  local path = TEST_DIRECTORY .. "/" .. name
  love.filesystem.createDirectory(path .. "/telegraph")
  config.id = name
  writeJson(path .. "/config.json", config)
  for file, size in pairs(images) do
    writePng(path .. "/" .. file .. ".png", size[1], size[2])
  end
  local character = Character(path, name)
  assert(character:json_init())
  character:graphics_init(true, false)
  return character
end

local function test1xTelegraphImagesAreLinear()
  atCanvasScale(1.5, function()
    local character = createCharacter("smoothTelegraph", {}, {["telegraph/1-wide"] = {72, 48}, ["telegraph/attack"] = {48, 48}})
    local wide = character.telegraph_garbage_images[1][1]
    local attack = character.telegraph_garbage_images["attack"]
    assert(filterOf(wide) == "linear", "72x48 telegraph garbage should be linear, got " .. filterOf(wide))
    assert(filterOf(attack) == "linear", "48x48 telegraph attack should be linear, got " .. filterOf(attack))
  end)
end

local function testBurstExpectedSizeFollowsBurstScale()
  atCanvasScale(1.5, function()
    -- drawn at 96 per frame, so 48px frames are pixel art
    local character = createCharacter("bigBurst", {popfx_burstScale = 2}, {burst = {9 * 48, 48}})
    assert(filterOf(character.images.burst) == "nearest", "48px burst frames drawn at 96 should be nearest, got " .. filterOf(character.images.burst))
  end)
end

local function testFadeExpectedSizeFollowsFadeScale()
  atCanvasScale(1.5, function()
    -- drawn at 48 per frame, so 48px frames are not pixel art
    local character = createCharacter("smallFade", {popfx_fadeScale = 0.5}, {fade = {9 * 48, 48}})
    assert(filterOf(character.images.fade) == "linear", "48px fade frames drawn at 48 should be linear, got " .. filterOf(character.images.fade))
  end)
end

local function createTheme(name, images)
  local path = TEST_DIRECTORY .. "/" .. name
  love.filesystem.createDirectory(path .. "/combo")
  love.filesystem.createDirectory(path .. "/frame")
  writeJson(path .. "/config.json", {version = 2})
  for file, size in pairs(images) do
    writePng(path .. "/" .. file .. ".png", size[1], size[2])
  end
  local theme = Theme(path, name)
  theme:load()
  return theme
end

local function test1xRandomCharacterIconIsLinear()
  atCanvasScale(1.5, function()
    local theme = createTheme("smoothRandomCharacter", {random_character = {84, 84}})
    assert(filterOf(theme.images.IMG_random_character) == "linear", "84px random character icon should be linear, got " .. filterOf(theme.images.IMG_random_character))
  end)
end

local function testPixelSizedRandomStageThumbnailIsLinear()
  atCanvasScale(1.5, function()
    local theme = createTheme("pixelRandomStage", {random_stage = {40, 22}})
    assert(filterOf(theme.images.IMG_random_stage) == "linear", "40x22 random stage thumbnail should be linear, got " .. filterOf(theme.images.IMG_random_stage))
  end)
end

local function test1xCardsAreLinear()
  atCanvasScale(1.5, function()
    local theme = createTheme("smoothCards", {["combo/combo04"] = {48, 48}})
    assert(filterOf(theme.images.IMG_cards[false][4]) == "linear", "48px combo card should be linear, got " .. filterOf(theme.images.IMG_cards[false][4]))
  end)
end

local function testPixelArtFrameIsNearest()
  atCanvasScale(1.5, function()
    -- drawn at 312x612
    local theme = createTheme("pixelFrame", {["frame/frame1P"] = {104, 204}})
    assert(filterOf(theme.images.frames[1]) == "nearest", "104x204 frame should be nearest, got " .. filterOf(theme.images.frames[1]))
  end)
end

local function testPixelArtWallIsNearest()
  atCanvasScale(1.5, function()
    -- drawn 288 wide
    local theme = createTheme("pixelWall", {["frame/wall1P"] = {96, 199}})
    assert(filterOf(theme.images.walls[1]) == "nearest", "96px wide wall should be nearest, got " .. filterOf(theme.images.walls[1]))
  end)
end

local function testPixelArtStackCursorIsNearest()
  atCanvasScale(1.5, function()
    -- drawn at 120x72
    local theme = createTheme("pixelCursor", {cursor1 = {40, 24}})
    assert(filterOf(theme.images.cursor[1].image) == "nearest", "40x24 cursor should be nearest, got " .. filterOf(theme.images.cursor[1].image))
  end)
end

-- puts sub mods into the global mod tables for the duration of func
local function withSubMods(allMods, loadedMods, subMods, func)
  local previous = {}
  for id, mod in pairs(subMods) do
    previous[id] = {allMods[id], loadedMods[id]}
    allMods[id] = mod
    loadedMods[id] = mod
  end
  local success, err = pcall(func)
  for id, _ in pairs(subMods) do
    allMods[id] = previous[id][1]
    loadedMods[id] = previous[id][2]
  end
  if not success then
    error(err, 0)
  end
end

local function createSubCharacters(iconSizes)
  local subCharacters = {}
  local subIds = {}
  for i, size in ipairs(iconSizes) do
    local id = "subCharacter" .. i
    local path = TEST_DIRECTORY .. "/" .. id
    love.filesystem.createDirectory(path)
    writePng(path .. "/icon.png", size)
    subCharacters[id] = Character(path, id)
    subCharacters[id]:graphics_init(false, false)
    subIds[i] = id
  end
  return subCharacters, subIds
end

local function bundleIconFilter(iconSizes)
  local subCharacters, subIds = createSubCharacters(iconSizes)
  local filter
  withSubMods(allCharacters, characters, subCharacters, function()
    local bundle = Character(TEST_DIRECTORY .. "/characterBundle", "characterBundle")
    bundle.subIds = subIds
    filter = filterOf(bundle:createBundleIcon())
  end)
  return filter
end

local function createSubStages(thumbnailSizes)
  local subStages = {}
  local subIds = {}
  for i, size in ipairs(thumbnailSizes) do
    local id = "subStage" .. i
    local path = TEST_DIRECTORY .. "/" .. id
    love.filesystem.createDirectory(path)
    writePng(path .. "/thumbnail.png", size[1], size[2])
    subStages[id] = Stage(path, id)
    subStages[id]:graphics_init(false, false)
    subIds[i] = id
  end
  return subStages, subIds
end

local function bundleThumbnailFilter(thumbnailSizes)
  local subStages, subIds = createSubStages(thumbnailSizes)
  local filter
  withSubMods(allStages, stages, subStages, function()
    local bundle = Stage(TEST_DIRECTORY .. "/stageBundle", "stageBundle")
    bundle.subIds = subIds
    filter = filterOf(bundle:createBundleThumbnail())
  end)
  return filter
end

local function testBundleIconOfPixelArtIconsIsNearest()
  atCanvasScale(1.5, function()
    local filter = bundleIconFilter({42, 42})
    assert(filter == "nearest", "a bundle icon of 42px icons should be nearest, got " .. filter)
  end)
end

local function testBundleIconWithASmoothIconIsLinear()
  atCanvasScale(1.5, function()
    -- the first icon is pixel art, the second is not
    local filter = bundleIconFilter({42, 84})
    assert(filter == "linear", "a bundle icon with an 84px icon should be linear, got " .. filter)
  end)
end

local function testBundleThumbnailOfPixelSizedThumbnailsIsLinear()
  atCanvasScale(1.5, function()
    local filter = bundleThumbnailFilter({{40, 22}, {40, 22}})
    assert(filter == "linear", "a bundle thumbnail of 40x22 thumbnails should be linear, got " .. filter)
  end)
end

testSmoothArtAtItsExpectedSizeIsLinear()
testArtAtHalfItsExpectedSizeIsNearest()
testArtWithoutAnExpectedSizeIsLinear()
test48pxSinglePanelSetIsLinear()
test24pxSinglePanelSetIsNearest()
testSinglePanelSheetFilterFollowsPanelSizeNotFirstImage()
test48pxSheetPanelSetIsLinear()
test24pxSheetPanelSetIsNearest()
test1xCharacterIconIsLinear()
testPixelSizedStageThumbnailIsLinear()
testPixelSizedStageBackgroundIsLinear()
test2xFileAtItsExpectedSizeIsLinear()
testPixelArtIsNearestAt2xCanvas()
test1xMetalPanelsAreLinear()
test1xTelegraphImagesAreLinear()
testBurstExpectedSizeFollowsBurstScale()
testFadeExpectedSizeFollowsFadeScale()
test1xRandomCharacterIconIsLinear()
testPixelSizedRandomStageThumbnailIsLinear()
test1xCardsAreLinear()
testPixelArtFrameIsNearest()
testPixelArtWallIsNearest()
testPixelArtStackCursorIsNearest()
testBundleIconOfPixelArtIconsIsNearest()
testBundleIconWithASmoothIconIsLinear()
testBundleThumbnailOfPixelSizedThumbnailsIsLinear()
