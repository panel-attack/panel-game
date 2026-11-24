local LanguageSelectSetup = require("client.src.scenes.LanguageSelectSetup")

-- Runs the test with the language select scene, putting the player's language back afterwards
local function withLanguageSelectSetup(test)
  local originalLanguageCode = Localization:get_language()
  local ok, err = pcall(test, LanguageSelectSetup())
  GAME:setLanguage(originalLanguageCode)
  if not ok then
    error(err, 0)
  end
end

-- The disclaimer is about machine translation, which English doesn't have
local function testHasNoDisclaimerInEnglish()
  withLanguageSelectSetup(function(scene)
    scene:setLanguage("EN")

    assert(scene.disclaimerLabel.text == "", "English should have no translation disclaimer")
  end)
end

local function testShowsTheDisclaimerInATranslatedLanguage()
  withLanguageSelectSetup(function(scene)
    scene:setLanguage("EN")
    scene:setLanguage("FR")

    assert(scene.disclaimerLabel.text == "translation_disclaimer", "the translation disclaimer should be shown in French")
  end)
end

testHasNoDisclaimerInEnglish()
testShowsTheDisclaimerInATranslatedLanguage()
