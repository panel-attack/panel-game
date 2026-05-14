love = { math = { newRandomGenerator = function() return { setSeed = function() end, random = function() return 0 end , filesystem = { getSourceBaseDirectory = function() return "." end } } end } }
package.preload["socket"] = function() return { gettime = function() return 0 end } end
-- Lua script to recreate the crash using replay data

local Match = require("Match")
local replayData = {
  crossPlayerEvents = {
    deaths = {
      {
        sender = 1,
        senderFrame = 1,
        serverWallClockMs = 1778710015038,
        reason = "disconnect"
      }
    },
    garbage = {}
  },
  metadata = {
    timestamp = 1778724415,
    ranked = false,
    stacks = {
      {
        panelId = "pacci",
        wins = 0,
        name = "Ben",
        publicId = 8,
        level = 10,
        stackIndex = 1
      },
      {
        panelId = "pacci",
        wins = 1,
        name = "Alice",
        publicId = 5,
        level = 10,
        stackIndex = 2
      }
    },
    gameModeName = "VS"
  },
  garbageFlows = {
    { source = 1, recipients = {2} },
    { source = 2, recipients = {1} }
  },
  stacks = {
    {
      inputs = "",
      stackType = 1,
      stackBehaviours = {
        swapStallingPunish = 4,
        passiveRaise = true,
        allowManualRaise = true,
        swapStallingMode = 1
      },
      inputMethod = "controller",
      levelData = {
        speedIncreaseMode = 1,
        shockFrequency = 41,
        shockCap = 3,
        colors = 6,
        adjacentDenialFrequency = 1,
        maxHealth = 1,
        stop = {
          chainConstant = 56,
          dangerConstant = 88,
          coefficient = 2,
          dangerCoefficient = 2,
          formula = 1,
          comboConstant = 22
        },
        frameConstants = {
          FACE = 10,
          POP = 7,
          HOVER = 6,
          GARBAGE_HOVER = 4,
          FLASH = 28
        },
        startingSpeed = 32
      }
    },
    {
      inputs = "",
      stackType = 1,
      stackBehaviours = {
        swapStallingPunish = 4,
        passiveRaise = true,
        allowManualRaise = true,
        swapStallingMode = 1
      },
      inputMethod = "controller",
      levelData = {
        speedIncreaseMode = 1,
        shockFrequency = 41,
        shockCap = 3,
        colors = 6,
        adjacentDenialFrequency = 1,
        maxHealth = 1,
        stop = {
          chainConstant = 56,
          dangerConstant = 88,
          coefficient = 2,
          dangerCoefficient = 2,
          formula = 1,
          comboConstant = 22
        },
        frameConstants = {
          FACE = 10,
          POP = 7,
          HOVER = 6,
          GARBAGE_HOVER = 4,
          FLASH = 28
        },
        startingSpeed = 32
      }
    }
  },
  engineVersion = "049",
  rules = {
    matchWinRuleset = {
      { GAME_OVER_CLOCK = "HIGHEST" }
    },
    stackSetupModifications = {},
    doCountdown = true,
    matchEndConditions = {
      STACKS_ACTIVE = 1
    },
    stackWinConditions = {},
    stackOverConditions = {
      HEALTH = 0
    }
  },
  panelSource = {
    shockEnabled = true,
    sourceType = 3,
    seed = 1759580
  },
  replayVersion = 4
}

-- Ensure all four players are represented in the replay data
local function ensureAllPlayers(replayData)
  local requiredPlayers = 4
  local existingPlayers = #replayData.metadata.stacks

  for i = existingPlayers + 1, requiredPlayers do
    table.insert(replayData.metadata.stacks, {
      panelId = "unknown",
      wins = 0,
      name = "Player " .. i,
      publicId = i,
      level = 1,
      stackIndex = i
    })
  end
end

-- Call the function to ensure all players are present
ensureAllPlayers(replayData)

-- Recreate the match from replay data
local match = Match.createFromReplay(replayData)
match:start()

-- Simulate the disconnect event
match:simulateEvent({
  type = "disconnect",
  sender = 1,
  frame = 1
})

print("Recreation complete. Check logs for results.")