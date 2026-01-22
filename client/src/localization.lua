-- TODO rename
local FILENAME = "client/assets/localization.csv"
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local fileUtils = require("client.src.FileUtils")

---@alias LanguageCode ("EN" | "FR" | "PT" | "JP" | "ES" | "GE" | "IT" | "TH")

-- Holds all the data for localizing the game
Localization = {
    data = {},
    langs = {},
    ---@type LanguageCode[]
    codes = {},
    lang_index = 1,
    init = false,
}

---@type table<LanguageCode, { fontPath: string?, fontSize: integer }>
Localization.languageCodeToFontData =
{
  EN = { fontPath = nil, fontSize = 12 },
  FR = { fontPath = nil, fontSize = 12 },
  PT = { fontPath = nil, fontSize = 12 },
  JP = { fontPath = "client/assets/fonts/jp.ttf", fontSize = 14 },
  ES = { fontPath = nil, fontSize = 12 },
  GE = { fontPath = nil, fontSize = 12 },
  IT = { fontPath = nil, fontSize = 12 },
  TH = { fontPath = "client/assets/fonts/th.otf", fontSize = 14 },
}

function Localization:get_list_codes()
  return self.codes
end

function Localization:get_language()
  return self.codes[self.lang_index]
end

function Localization.refresh_global_strings(self)
  join_community_msg = loc("join_community" ,"\ndiscord." .. consts.SERVER_LOCATION)
end

function Localization.csv_line(line, acc)
  local function trim(a, b)
    if line:sub(a, a) == '"' then
      a = a + 1
    end
    if line:sub(b, b) == '"' then
      b = b - 1
    end
    return line:sub(a, b)
  end

  local tokens = {}
  local leftover = nil
  local cur = 1
  local stop_cur = 1
  local escape = (acc ~= nil)
  local ch

  while cur <= line:len() do
    ch = line:sub(cur, cur)

    if ch == '"' then
      if line:sub(cur + 1, cur + 1) == '"' then
        cur = cur + 1
      else
        escape = not escape
      end
    elseif not escape and ch == "," then
      tokens[#tokens + 1] = trim(stop_cur, cur - 1)

      if acc then
        tokens[#tokens] = acc .. tokens[#tokens]
        acc = nil
      end

      tokens[#tokens] = tokens[#tokens]:gsub('""', '"')

      stop_cur = cur + 1
    end

    cur = cur + 1
  end

  if escape then
    if not acc then
      leftover = line:sub(stop_cur + 1, cur)
    else
      leftover = acc .. line:sub(stop_cur, cur)
    end
    leftover = leftover .. "\n"
  else
    tokens[#tokens + 1] = trim(stop_cur, cur)
  end

  return tokens, leftover
end

function Localization.init(self)
  self.init = true
  local num_line = 1
  local tokens, leftover
  local i = 1
  local key = nil
  -- Process all the localization strings
  if fileUtils.exists(FILENAME) then
    for line in love.filesystem.lines(FILENAME) do
      if num_line == 1 then
        tokens = Localization.csv_line(line)
        for j, v in ipairs(tokens) do
          if j > 2 and v:gsub("%s", ""):len() > 0 then
            self.codes[#self.codes + 1] = v
            self.data[v] = {}
          end
        end
      else
        tokens, leftover = Localization.csv_line(line, leftover)
        for j, v in ipairs(tokens) do
          -- Key all the other languages by the first column
          if not key then
            key = v
            if key == "" or key:match("%s+") then
              logger.warn("Invalid key in localization file")
              break
            end
            if self.data[self.codes[1]][key] ~= nil then
              logger.warn("Duplicate key in localization file: " .. key)
            end
          else
            -- Second column is the description, only used for making translations
            if j ~= 2 then
              if v ~= "" and not v:match("^%s+$") then
                if num_line == 2 then
                  self.langs[#self.langs + 1] = v
                end
                self.data[self.codes[i]][key] = v
              end
              i = i + 1
            end
          end
          if i > #self.codes then
            break
          end
        end

        if not leftover then
          i = 1
          key = nil
        end
      end

      num_line = num_line + 1
    end
  end

  --[[    for k, v in pairs(self.data) do
      print("LANG "..k)
      for a, b in pairs(v) do
        print(a..": "..b)
      end
    end--]]
end

-- Gets the localized string for a loc key
---@param textKey string
---@param ... string?
function loc(textKey, ...)
  local code = Localization.codes[Localization.lang_index]

  return Localization.localize(code, textKey, ...)
end

function Localization:getCurrentLanguageCode()
  if config.language_code then
    return config.language_code
  end
  return "EN"
end

-- Creates language labels by temporarily switching to each language to load proper fonts
-- Returns: array of {code, name} pairs, array of labels with proper fonts
function Localization:getLanguageLabelsWithFonts()
  local languageData = {}
  local languageLabels = {}
  local originalLanguageCode = self:getCurrentLanguageCode()

  for k, languageCode in ipairs(self:get_list_codes()) do
    GAME:setLanguage(languageCode)
    local languageName = self.data[languageCode]["LANG"]
    languageData[#languageData + 1] = {code = languageCode, name = languageName}
    languageLabels[#languageLabels + 1] = ui.Label({text = languageName, translate = false})
  end

  GAME:setLanguage(originalLanguageCode)

  return languageData, languageLabels
end

-- Gets the index of a language code in the list
function Localization:getLanguageIndex(languageCode)
  for k, code in ipairs(self:get_list_codes()) do
    if code == languageCode then
      return k
    end
  end
  return 1
end

---@return LanguageCode?
function Localization:getLanguageCode(languageName)
  for languageCode, translations in pairs(self.data) do
    if translations["LANG"] == languageName then
      return languageCode
    end
  end
end

---@param languageCode LanguageCode
---@param textKey string
---@param ... string?
---@return string
function Localization.localize(languageCode, textKey, ...)
  if not languageCode or not Localization.data[languageCode] then
    languageCode = Localization.codes[1]
  end
  assert(languageCode)

  local ret = nil
  if Localization.init then
    ret = Localization.data[languageCode][textKey]
  end

  if ret then
    for i = 1, select("#", ...) do
      local tmp = select(i, ...)
      ret = ret:gsub("%%" .. i, tmp)
    end
  else
    love.filesystem.append("warnings.txt", textKey .. ",,,,,,,,," .. "\n")
    ret = "#" .. textKey
    for i = 1, select("#", ...) do
      ret = ret .. " " .. select(i, ...)
    end
  end

  return ret
end

return Localization