local PuzzleEditorScene = require("client.src.scenes.PuzzleEditorScene")
local ui = require("client.src.ui")
local logger = require("common.lib.logger")

-- Every translated label of the editor controls has text in every language instead of showing its "#key"
local function testEditorControlLabelsHaveTranslations()
  local editor = {createPaletteButtons = function() return ui.UiElement({}) end}
  local controls = PuzzleEditorScene.createEditorControls(editor)

  for _, control in ipairs(controls) do
    local label = control.label or control
    if label.translate then
      for _, languageCode in ipairs(Localization:get_list_codes()) do
        local text = Localization.localize(languageCode, label.text)
        assert(text:sub(1, 1) ~= "#", "Label " .. label.text .. " has no " .. languageCode .. " translation")
      end
    end
  end
  logger.trace("passed test testEditorControlLabelsHaveTranslations")
end

testEditorControlLabelsHaveTranslations()
