local utf8 = require("common.lib.utf8Additions")

local InputCompression = {}

-- Returns if the unicode codepoint (representative number) is either the left or right parenthesis
local function codePointIsParenthesis(codePoint)
  if codePoint >= 40 and codePoint <= 41 then
    return true
  end
  return false
end

-- Returns if the unicode codepoint (representative number) is a digit from 0-9
local function codePointIsDigit(codePoint)
  if codePoint >= 48 and codePoint <= 57 then
    return true
  end
  return false
end

---@param inputs string
---@return string compressedInputs
function InputCompression.compressInputString(inputs)
  assert(inputs ~= nil, "string must be provided for compression")
  assert(type(inputs) == "string", "input to be compressed must be a string")
  if string.len(inputs) == 0 then
    return inputs
  end

  local compressedTable = {}
  local function addToTable(codePoint, repeatCount)
    local currentInput = utf8.char(codePoint)
    -- write the input
    if tonumber(currentInput) == nil then
      compressedTable[#compressedTable+1] = currentInput .. repeatCount
    else
      local completeInput = "(" .. currentInput
      for j = 2, repeatCount do
        completeInput = completeInput .. currentInput
      end
      compressedTable[#compressedTable+1] = completeInput .. ")"
    end
  end

  local previousCodePoint = nil
  local repeatCount = 1
  for p, codePoint in utf8.codes(inputs) do
    if codePointIsDigit(codePoint) and codePointIsParenthesis(previousCodePoint) == true then
      -- Detected a digit enclosed in parentheses in the inputs, the inputs are already compressed.
      return inputs
    end
    if p > 1 then
      if previousCodePoint ~= codePoint then
        addToTable(previousCodePoint, repeatCount)
        repeatCount = 1
      else
        repeatCount = repeatCount + 1
      end
    end
    previousCodePoint = codePoint
  end
  -- add the final entry without having to check for table length in every iteration
  addToTable(previousCodePoint, repeatCount)

  return table.concat(compressedTable)
end

---@param inputs string
---@return string decompressedInputs
function InputCompression.decompressInputString(inputs)
  local previousCodePoint = nil
  local inputChunks = {}
  local numberString = nil
  local characterCodePoint = nil
  -- Go through the characters one by one, saving character and then the number sequence and after passing it writing out that many characters
  for p, codePoint in utf8.codes(inputs) do
    if p > 1 then
      if codePointIsDigit(codePoint) then
        local number = utf8.char(codePoint)
        if numberString == nil then
          characterCodePoint = previousCodePoint
          numberString = ""
        end
        numberString = numberString .. number
      else
        if numberString ~= nil then
          if codePointIsParenthesis(characterCodePoint) then
            inputChunks[#inputChunks+1] = numberString
          else
            local character = utf8.char(characterCodePoint)
            local repeatCount = tonumber(numberString)
            inputChunks[#inputChunks+1] = string.rep(character, repeatCount)
          end
          numberString = nil
        end
        if previousCodePoint == codePoint then
          -- Detected two consecutive letters or symbols in the inputs, the inputs are not compressed.
          return inputs
        else
          -- Nothing to do yet
        end
      end
    end
    previousCodePoint = codePoint
  end

  local result
  if numberString ~= nil then
    local character = utf8.char(characterCodePoint)
    local repeatCount = tonumber(numberString)
    inputChunks[#inputChunks+1] = string.rep(character, repeatCount)
    result = table.concat(inputChunks)
  else
    -- We never encountered a single number, this string wasn't compressed
    result = inputs
  end
  return result
end

return InputCompression