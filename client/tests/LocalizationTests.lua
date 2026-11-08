local Localization = require("client.src.localization")

---@param test fun(warnings: string[])
local function withTranslations(test)
  local originalData = Localization.data
  local originalCodes = Localization.codes
  local originalLanguageIndex = Localization.lang_index
  local originalAppend = love.filesystem.append
  local warnings = {}

  Localization.codes = {"EN", "FR", "PT", "JP", "ES", "GE", "IT", "TH"}
  Localization.lang_index = 2
  Localization.data = {
    EN = {
      translated = "English translation",
      englishOnly = "English only",
      formatted = "%1 has %2 points",
    },
    FR = {
      translated = "French translation",
      formatted = "%1: %2 points",
    },
    PT = {},
    JP = {},
    ES = {},
    GE = {},
    IT = {},
    TH = {},
  }
  love.filesystem.append = function(filename, content)
    assert(filename == "warnings.txt")
    warnings[#warnings + 1] = content
    return true
  end

  local success, err = pcall(test, warnings)

  Localization.data = originalData
  Localization.codes = originalCodes
  Localization.lang_index = originalLanguageIndex
  love.filesystem.append = originalAppend

  assert(success, err)
end

-- Existing translations and replacements are preserved without warnings.
local function testExistingTranslations()
  withTranslations(function(warnings)
    assert(Localization.localize("EN", "translated") == "English translation")
    assert(Localization.localize("FR", "translated") == "French translation")
    assert(loc("translated") == "French translation")
    assert(loc("formatted", "Alice", 42) == "Alice: 42 points")
    assert(#warnings == 0)
  end)
end

-- Both APIs fall back to English in every language and still record missing translations.
local function testEnglishFallbackForEveryLanguage()
  withTranslations(function(warnings)
    for index, code in ipairs(Localization.codes) do
      Localization.lang_index = index
      assert(Localization.localize(code, "englishOnly") == "English only", "Missing fallback for " .. code)
      assert(loc("englishOnly") == "English only", "Missing loc fallback for " .. code)
    end
    assert(#warnings == 2 * (#Localization.codes - 1))
    for _, warning in ipairs(warnings) do
      assert(warning == "englishOnly,,,,,,,,,\n")
    end
  end)
end

-- English fallback replaces placeholders with string and number arguments.
local function testEnglishFallbackReplacements()
  withTranslations(function(warnings)
    Localization.lang_index = 3
    assert(Localization.localize("PT", "formatted", "Alice", 42) == "Alice has 42 points")
    assert(loc("formatted", "Bob", 7) == "Bob has 7 points")
    assert(#warnings == 2)
  end)
end

-- Keys missing in English too retain the #key output, appended arguments, and warnings.
local function testMissingEnglishTranslation()
  withTranslations(function(warnings)
    assert(Localization.localize("EN", "missing") == "#missing")
    assert(Localization.localize("FR", "missing") == "#missing")
    assert(loc("missing", "Alice", 42) == "#missing Alice 42")
    assert(#warnings == 3)
    for _, warning in ipairs(warnings) do
      assert(warning == "missing,,,,,,,,,\n")
    end
  end)
end

-- An unavailable language table defaults to English without missing-key warnings.
local function testUnavailableLanguage()
  withTranslations(function(warnings)
    Localization.data.PT = nil
    Localization.lang_index = 3
    assert(Localization.localize("PT", "translated") == "English translation")
    assert(loc("translated") == "English translation")
    assert(#warnings == 0)
  end)
end

testExistingTranslations()
testEnglishFallbackForEveryLanguage()
testEnglishFallbackReplacements()
testMissingEnglishTranslation()
testUnavailableLanguage()
