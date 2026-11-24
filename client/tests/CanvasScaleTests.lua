-- A stand-in for a texture or sprite batch that records whether it was released
---@param releasedNames string[] receives name when the stand-in is released
---@param name string
local function releasable(releasedNames, name)
  return {release = function() releasedNames[#releasedNames + 1] = name return true end}
end

local function testReleasingAPanelSetsSheetsReleasesEverySheetAndBatch()
  local panelSet = Panels("client/assets/panels/__default", "__default")
  local releasedNames = {}
  for color = 1, 8 do
    panelSet.sheets[color] = releasable(releasedNames, "sheet " .. color)
    panelSet.batches[color] = releasable(releasedNames, "batch " .. color)
  end

  panelSet:releaseSheets()

  assert(#releasedNames == 16, "all 8 sheets and 8 batches should be released, but " .. #releasedNames .. " were")
  assert(next(panelSet.sheets) == nil and next(panelSet.batches) == nil, "the panel set should not hold its released sheets or batches")
end

testReleasingAPanelSetsSheetsReleasesEverySheetAndBatch()

local function testAScaleChangeReleasesThePreviousPanelSheets()
  local previousPanelSets = shallowcpy(allPanels)
  assert(next(previousPanelSets) ~= nil, "there should be panel sets loaded before the scale change")

  GAME:refreshCanvasAndImagesForNewScale()

  for id, panelSet in pairs(previousPanelSets) do
    assert(allPanels[id] ~= panelSet, "panel set " .. id .. " should be loaded again")
    assert(next(panelSet.sheets) == nil, "the previous sheets of panel set " .. id .. " should be released")
    assert(#allPanels[id].sheets == 8, "panel set " .. id .. " should have its 8 sheets again, but has " .. #allPanels[id].sheets)
  end
end

testAScaleChangeReleasesThePreviousPanelSheets()
