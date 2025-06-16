local AnimationLoader = require("client.src.graphics.AnimationLoader")

-- Helper function to assert equality with detailed error messages
local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s: Expected %s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)))
  end
end

-- Helper function to check if a value is approximately equal (for floating point comparisons)
local function assertApproxEqual(actual, expected, tolerance, message)
  tolerance = tolerance or 0.001
  if math.abs(actual - expected) > tolerance then
    error(string.format("%s: Expected %f (±%f), got %f", message or "Approximation failed", expected, tolerance, actual))
  end
end

-- Test basic JSON loading
local function testBasicJSONLoading()
  print("Testing basic JSON loading...")
  
  local testPath = "client/tests/AnimationLoaderTestData/"
  local results = AnimationLoader.loadFromFile(testPath, testPath .. "basic.json")
  
  assertEqual(#results, 1, "Should load exactly one drawable")
  
  local drawable = results[1]
  assertEqual(drawable.id, "BasicElement", "ID should match")
  assertEqual(drawable.x, 100, "X position should match")
  assertEqual(drawable.y, 200, "Y position should match")
  assertApproxEqual(drawable.alpha, 0.8, nil, "Alpha should match")
  assertEqual(drawable.anchor, "center", "Anchor should match")
  assertEqual(drawable.pivot, "center", "Pivot should match")
  assertApproxEqual(drawable.rotation, 0.5, nil, "Rotation should match")
  assertApproxEqual(drawable.xScale, 0.781, nil, "X scale should match")
  assertApproxEqual(drawable.yScale, 1.171875, nil, "Y scale should match")
  assertEqual(drawable.blendMode, "add", "Blend mode should match")
  assertEqual(drawable.alphaMode, "premultiplied", "Alpha mode should match")
  
  -- Check tint array
  assertEqual(#drawable.tint, 3, "Tint should have 3 components")
  assertApproxEqual(drawable.tint[1], 1.0, nil, "Tint red component should match")
  assertApproxEqual(drawable.tint[2], 0.5, nil, "Tint green component should match")
  assertApproxEqual(drawable.tint[3], 0.2, nil, "Tint blue component should match")
  
  print("✓ Basic JSON loading test passed")
end

-- Test loading a reference
local function testLoadingRef()
  print("Testing loading with reference...")
  
  local testPath = "client/tests/AnimationLoaderTestData/"
  local results = AnimationLoader.loadFromFile(testPath, testPath .. "withRef.json")
  
  assertEqual(#results, 2, "Should load exactly two drawables")
  
  local original = results[1]
  local referenced = results[2]
  
  assertEqual(original.id, "OriginalElement", "Original ID should match")
  assertEqual(referenced.originalRef, "OriginalElement", "Referenced element should have ref property")
  
  -- Both should have the same properties (reference should be resolved)
  assertEqual(original.x, referenced.x, "X positions should match")
  assertEqual(original.y, referenced.y, "Y positions should match")
  assertEqual(original.width, referenced.width, "Widths should match")
  assertEqual(original.height, referenced.height, "Heights should match")
  
  print("✓ Reference loading test passed")
end

-- Test loading a reference with overrides
local function testLoadingRefWithOverrides()
  print("Testing loading reference with overrides...")
  
  local testPath = "client/tests/AnimationLoaderTestData/"
  local results = AnimationLoader.loadFromFile(testPath, testPath .. "withRefOverrides.json")
  
  assertEqual(#results, 2, "Should load exactly two drawables")
  
  local base = results[1]
  local overridden = results[2]
  
  assertEqual(base.id, "BaseElement", "Base ID should match")
  assertEqual(overridden.originalRef, "BaseElement", "Overridden element should have ref property")
  
  -- Check that overrides were applied
  assertEqual(overridden.x, 200, "Overridden X position should match")
  assertEqual(overridden.y, 300, "Overridden Y position should match")
  assertApproxEqual(overridden.rotation, 1.57, nil, "Overridden rotation should match")
  
  -- Check tint override
  assertApproxEqual(overridden.tint[1], 1.0, nil, "Overridden tint red should match")
  assertApproxEqual(overridden.tint[2], 0.0, nil, "Overridden tint green should match")
  assertApproxEqual(overridden.tint[3], 0.0, nil, "Overridden tint blue should match")
  
  -- Check that non-overridden properties remain the same
  assertEqual(overridden.width, base.width, "Non-overridden width should match base")
  assertEqual(overridden.height, base.height, "Non-overridden height should match base")
  
  -- Check that animation tracks were overridden
  assertEqual(#overridden.animationTracks, 1, "Should have one animation track")
  assertEqual(overridden.animationTracks[1].yoyo, true, "Animation should be yoyo")
  assertEqual(overridden.animationTracks[1].steps[1].durationSeconds, 2.0, "Animation duration should be overridden")
  
  print("✓ Reference with overrides test passed")
end

-- Test loading a reference that references a different file
local function testLoadingRefToDifferentFile()
  print("Testing loading reference to different file...")
  
  local testPath = "client/tests/AnimationLoaderTestData/"
  local results = AnimationLoader.loadFromFile(testPath, testPath .. "withFileRef.json")
  
  -- Should load local element + all elements from externalRef.json + overridden external element
  assertEqual(#results, 3, "Should load three drawables")
  
  local localElement = results[1]
  local externalFileRef = results[2]
  local overriddenExternal = results[3]
  
  assertEqual(localElement.id, "LocalElement", "Local element ID should match")
  
  -- The file reference should import all drawables from the external file as children
  assertEqual(#externalFileRef.children, 1, "File reference should have children from external file")
  assertEqual(externalFileRef.children[1].id, "ExternalElement", "Child should be the external element")
  
  -- Check that the overridden external element has the correct properties
  assertEqual(overriddenExternal.originalRef, "ExternalElement", "Should reference ExternalElement")
  assertEqual(overriddenExternal.x, 300, "Overridden X should match")
  assertEqual(overriddenExternal.y, 400, "Overridden Y should match")
  assertApproxEqual(overriddenExternal.tint[1], 0.5, nil, "Overridden tint red should match")
  assertApproxEqual(overriddenExternal.tint[2], 1.0, nil, "Overridden tint green should match")
  assertApproxEqual(overriddenExternal.tint[3], 0.5, nil, "Overridden tint blue should match")
  
  print("✓ Reference to different file test passed")
end

-- Test loading a reference to a file while loading from another file (nested file references)
local function testLoadingNestedFileReferences()
  print("Testing loading nested file references...")
  
  local testPath = "client/tests/AnimationLoaderTestData/"
  local results = AnimationLoader.loadFromFile(testPath, testPath .. "nestedFileRef.json")
  
  -- Should load nested element + all elements from withFileRef.json (which includes externalRef.json)
  assertEqual(#results, 2, "Should load two top-level drawables")
  
  local nestedElement = results[1]
  local fileRef = results[2]
  
  assertEqual(nestedElement.id, "NestedElement", "Nested element ID should match")
  
  -- The file reference should contain all the drawables from withFileRef.json
  assertEqual(#fileRef.children, 3, "File reference should have all children from withFileRef.json")
  
  -- Check that nested file references are properly resolved
  local localElement = fileRef.children[1]
  local externalFileRef = fileRef.children[2]
  local overriddenExternal = fileRef.children[3]
  
  assertEqual(localElement.id, "LocalElement", "Nested local element should be present")
  assertEqual(#externalFileRef.children, 1, "Nested external file ref should have children")
  assertEqual(externalFileRef.children[1].id, "ExternalElement", "Deeply nested element should be present")
  assertEqual(overriddenExternal.originalRef, "ExternalElement", "Nested override should reference correct element")
  
  print("✓ Nested file references test passed")
end

-- Test templateOnly property
local function testTemplateOnly()
  print("Testing templateOnly property...")
  
  local testPath = "client/tests/AnimationLoaderTestData/"
  local results = AnimationLoader.loadFromFile(testPath, testPath .. "templateOnly.json")
  
  -- Should only load 2 drawables: NormalElement and the referenced Template
  -- The Template itself should not be loaded directly because templateOnly=true
  assertEqual(#results, 2, "Should load exactly two drawables (normal element + referenced template)")
  
  local normalElement = results[1]
  local referencedTemplate = results[2]
  
  -- First drawable should be the normal element (not template-only)
  assertEqual(normalElement.id, "NormalElement", "First element should be NormalElement")
  assertEqual(normalElement.x, 200, "Normal element X should match")
  assertEqual(normalElement.y, 200, "Normal element Y should match")
  assertEqual(normalElement.width, 64, "Normal element width should match")
  assertEqual(normalElement.height, 64, "Normal element height should match")
  
  -- Check children of normal element - should only have 2 children (NormalChild + referenced ChildTemplate)
  -- ChildTemplate itself should not be loaded because templateOnly=true
  assertEqual(#normalElement.children, 2, "Normal element should have 2 children (normal child + referenced child template)")
  
  local normalChild = normalElement.children[1]
  local referencedChildTemplate = normalElement.children[2]
  
  assertEqual(normalChild.id, "NormalChild", "First child should be NormalChild")
  assertEqual(normalChild.x, 20, "Normal child X should match")
  assertEqual(normalChild.y, 20, "Normal child Y should match")
  
  assertEqual(referencedChildTemplate.originalRef, "ChildTemplate", "Second child should reference ChildTemplate")
  assertEqual(referencedChildTemplate.x, 30, "Referenced child template X should be overridden")
  assertEqual(referencedChildTemplate.y, 30, "Referenced child template Y should be overridden")
  
  -- Second drawable should be the referenced template with overrides applied
  assertEqual(referencedTemplate.originalRef, "Template", "Second element should reference Template")
  assertEqual(referencedTemplate.x, 300, "Referenced template X should be overridden")
  assertEqual(referencedTemplate.y, 300, "Referenced template Y should be overridden")
  assertApproxEqual(referencedTemplate.alpha, 0.8, nil, "Referenced template alpha should match template")
  
  print("✓ TemplateOnly test passed")
end

-- Test that anchor is preserved when overriding x position of a template
local function testAnchorPreservationWithXOverride()
  print("Testing anchor preservation with x position override...")
  
  local testPath = "client/tests/AnimationLoaderTestData/"
  local results = AnimationLoader.loadFromFile(testPath, testPath .. "anchorOverrideTest.json")
  
  -- Should load exactly two drawables (the referenced templates with overrides)
  -- The template itself should not be loaded because templateOnly=true
  assertEqual(#results, 2, "Should load exactly two drawables (referenced templates)")
  
  local firstOverride = results[1]
  local secondOverride = results[2]
  
  -- Test first override: only x position changed
  assertEqual(firstOverride.originalRef, "CenterAnchorTemplate", "First should reference CenterAnchorTemplate")
  assertEqual(firstOverride.x, 250, "X position should be overridden to 250")
  assertEqual(firstOverride.y, 100, "Y position should remain 100 (not overridden)")
  assertEqual(firstOverride.width, 64, "Width should match template")
  assertEqual(firstOverride.height, 64, "Height should match template")
  assertEqual(firstOverride.anchor, "center", "Anchor should remain 'center' from template")
  assertApproxEqual(firstOverride.alpha, 0.9, nil, "Alpha should match template")
  
  -- Verify that the anchor offset calculation works correctly with the new x position
  local anchorOffsetX, anchorOffsetY = AnimationLoader.anchorOffset(firstOverride, firstOverride.anchor)
  assertEqual(anchorOffsetX, 32, "Anchor offset X should be width/2 for center anchor")
  assertEqual(anchorOffsetY, 32, "Anchor offset Y should be height/2 for center anchor")
  
  -- Verify that the object transform calculation uses the correct anchor with the new x position
  local transformX, transformY = AnimationLoader.objectTransform(firstOverride)
  assertEqual(transformX, 218, "Transform X should be x - anchorOffsetX (250 - 32)")
  assertEqual(transformY, 68, "Transform Y should be y - anchorOffsetY (100 - 32)")
  
  -- Test second override: both position and size changed (like the Windows.json case)
  assertEqual(secondOverride.originalRef, "CenterAnchorTemplate", "Second should reference CenterAnchorTemplate")
  assertEqual(secondOverride.x, 0, "X position should be overridden to 0")
  assertEqual(secondOverride.y, 216, "Y position should be overridden to 216")
  assertEqual(secondOverride.anchor, "center", "Anchor should remain 'center' from template")
  assertApproxEqual(secondOverride.alpha, 0.9, nil, "Alpha should match template")
  
  -- Verify that the anchor offset calculation works correctly with the new size
  local anchorOffsetX2, anchorOffsetY2 = AnimationLoader.anchorOffset(secondOverride, secondOverride.anchor)
  assertApproxEqual(anchorOffsetX2, 32, nil, "Anchor offset X should be width/2 for center anchor (64/2)")
  assertApproxEqual(anchorOffsetY2, 32, nil, "Anchor offset Y should be height/2 for center anchor (64/2)")
  
  -- Verify that the object transform calculation uses the correct anchor with the new position and size
  local transformX2, transformY2 = AnimationLoader.objectTransform(secondOverride)
  assertApproxEqual(transformX2, -32, nil, "Transform X should be x - anchorOffsetX (0 - 32)")
  assertApproxEqual(transformY2, 184, nil, "Transform Y should be y - anchorOffsetY (216 - 32)")
  
  print("✓ Anchor preservation with x position override test passed")
end


-- Test that anchor is preserved when overriding x position of a template
local function testLoadingReferenceToReference()
  print("Testing reference to a reference...")
  
  local testPath = "client/tests/AnimationLoaderTestData/"
  local results = AnimationLoader.loadFromFile(testPath, testPath .. "referenceToReferenceTest.json")
  
  -- Should load exactly two drawables (the referenced templates with overrides)
  -- The template itself should not be loaded because templateOnly=true
  assertEqual(#results, 3, "Should load exactly 3 drawables")
  
  local drawable = results[1]
  local firstOverride = results[2]
  local secondOverride = results[3]
  
  assertEqual(drawable.id, "Element")
  assertEqual(drawable.originalRef, nil)
  assertEqual(drawable.x, 100)
  assertEqual(drawable.y, 100)

  assertEqual(firstOverride.id, "Element2")
  assertEqual(firstOverride.originalRef, "Element")
  assertEqual(firstOverride.x, 200)
  assertEqual(firstOverride.y, 100)
  
  assertEqual(secondOverride.id, nil)
  assertEqual(secondOverride.originalRef, "Element2")
  assertEqual(secondOverride.x, 200)
  assertEqual(secondOverride.y, 200)

  print("✓ Testing reference to a reference")
end

-- Run all tests
local function runAllTests()
  print("Running AnimationLoader tests...")
  
  testBasicJSONLoading()
  testLoadingRef()
  testLoadingRefWithOverrides()
  testLoadingRefToDifferentFile()
  testLoadingNestedFileReferences()
  testTemplateOnly()
  testAnchorPreservationWithXOverride()
  testLoadingReferenceToReference()
  
  print("✓ All AnimationLoader tests passed!")
end

runAllTests()
