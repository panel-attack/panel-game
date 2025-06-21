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

local function codePointIsAlphabet(codePoint)
  if codePoint < 65 then
    return false
  elseif codePoint > 123 then
    return false
  else
    if codePoint < 92 then
      return true
    elseif codePoint > 97 then
      return true
    else
      return false
    end
  end
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

local readingStates = { uninitialized = 0, character = 1, count = 2, uncompressed = 3 }

-- replaces the previous buggy decompressInputString
---@param inputs string
---@return string decompressedInputs
function InputCompression.decompressInputString2(inputs)
  -- reading state is based on the last character(s) to determine how we interpret the next one
  local readingState = 0
  local inputChunks = {}
  local count = 0

  for _, codePoint in utf8.codes(inputs) do
    if readingState == readingStates.uninitialized then
      -- uninitialized state means that we either haven't read anything yet
      -- or the previous character was a magic character for closing an uncompressed segment
      -- in either case we expect a character or the start of a new uncompressed segment

      -- 40 is ( and indicates the start of an uncompressed segment of the same character
      if codePoint == 40 then
        readingState = readingStates.uncompressed
      else
        readingState = readingStates.character
        inputChunks[#inputChunks+1] = utf8.char(codePoint)
      end
    elseif readingState == readingStates.character then
      -- when we have read a character we always expect a count next, anything else is invalid
      if codePointIsDigit(codePoint) then
        readingState = readingStates.count
---@diagnostic disable-next-line: cast-local-type
        count = tonumber(utf8.char(codePoint))
      else
        -- getting here means either getting a completely unexpected input or two repeated characters
        -- two repeated inputs after another indicate non-compressed inputs
        -- due to digits being both valid inputs and count indicators there is no way to differentiate the two
        -- so we have to give up immediately
        -- return inputs under the assumption that the input string is just not compressed rather than invalid
        return inputs
      end
    elseif readingState == readingStates.count then
      -- numbers stretch over multiple characters so concatenate for as long as there are numbers
      if codePointIsDigit(codePoint) then
        count = count * 10 + tonumber(utf8.char(codePoint))
      else
        -- otherwise apply the repeats of the previous character
        inputChunks[#inputChunks+1] = string.rep(inputChunks[#inputChunks], count - 1)

        -- 40 is ( and indicates the start of an uncompressed segment of the same character
        if codePoint == 40 then
          readingState = readingStates.uncompressed
        else
          readingState = readingStates.character
          inputChunks[#inputChunks+1] = utf8.char(codePoint)
        end
      end
    elseif readingState == readingStates.uncompressed then
      -- 41 is ) and indicates the end of the uncompressed segment
      if codePoint == 41 then
        readingState = readingStates.uninitialized
      else
        -- in uncompressed segments we take any non ) character at face value
        inputChunks[#inputChunks+1] = utf8.char(codePoint)
      end
    end
  end

  if readingState == readingStates.count then
    -- counts defer appending until the number is confirmed to be complete; end of input string is yet another count termination
    inputChunks[#inputChunks+1] = string.rep(inputChunks[#inputChunks], count - 1)
  end

  return table.concat(inputChunks)
end

local function writeToCache(cache, character, count)
  if tonumber(character) then
    cache[#cache+1] = "(" .. string.rep(character, count) .. ")"
  else
    cache[#cache+1] = character .. count
  end
end

--- convenience function to compress inputs directly from a table
--- this saves doing a table.concat as well as juggling utf8 codepoints
---@param inputs string[]
---@return string compressedInputs
function InputCompression.compressInputTable(inputs)
  if #inputs == 0 then
    return ""
  end

  local count = 1
  local lastCharacter = inputs[1]
  local cache = {}

  for i = 2, #inputs do
    local character = inputs[i]
    if character == lastCharacter then
      count = count + 1
    else
      writeToCache(cache, lastCharacter, count)
      lastCharacter = character
      count = 1
    end
  end

  writeToCache(cache, lastCharacter, count)

  return table.concat(cache)
end

return InputCompression