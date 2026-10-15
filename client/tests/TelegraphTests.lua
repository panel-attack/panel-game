local ClientMatch = require("client.src.ClientMatch")
local GameModes = require("common.data.GameModes")
local Player = require("client.src.Player")
local GeneratorSource = require("common.engine.GeneratorSource")
local LevelPresets = require("common.data.LevelPresets")
local Telegraph = require("client.src.graphics.Telegraph")

local function test(func)
  func()
end

---@return ClientMatch
local function createVersusClientMatch()
  local versus = GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS)
  local players = {}
  for i = 1, 2 do
    local player = Player.createLocalPlayerFromConfig()
    player.isLocal = false
    player:setLevel(10)
    player:setLevelData(LevelPresets.getModern(10))
    player:setStyle(GameModes.Styles.MODERN)
    player.playerNumber = i
    players[#players+1] = player
  end

  local clientMatch = ClientMatch.createFromGameMode(players, versus, GeneratorSource(1, true), false)
  clientMatch:start()
  return clientMatch
end

-- garbage records the stopWatch it was earned at; in a match with a countdown that lags far behind the clock
-- the attack animation has to be measured against the same timer or it is over before it starts
local function testAttackFrameUsesStopWatch()
  local match = createVersusClientMatch()
  local sender = match.stacks[1]
  local engine = sender.engine
  ---@cast engine Stack
  engine:receiveConfirmedInput(string.rep(engine:idleInput(), 400))

  while engine.stopWatch < 10 do
    engine:run()
  end
  assert(engine.clock > engine.stopWatch + Telegraph:attackAnimationEndFrame(), "match needs a countdown for this test to mean anything")

  engine:pushGarbage({row = 3, column = 2}, false, 4, 0)
  local garbage = engine.outgoingGarbage.stagedGarbage[1]
  assert(garbage.frameEarned == engine.stopWatch)

  assert(Telegraph:attackFrame(sender, garbage.frameEarned) == 0)
  engine:run()
  assert(Telegraph:attackFrame(sender, garbage.frameEarned) == 1)
end

test(testAttackFrameUsesStopWatch)

-- Records the order in which the match draws its stacks, telegraphs and effects
---@param match ClientMatch
---@return string[] order
---@return function restore puts Telegraph.render back
local function recordDrawOrder(match)
  local order = {}
  for i, stack in ipairs(match.stacks) do
    stack.render = function()
      order[#order + 1] = "stack" .. i
    end
    stack.renderEffects = function()
      order[#order + 1] = "effects" .. i
    end
  end
  local originalRender = Telegraph.render
  ---@diagnostic disable-next-line: duplicate-set-field
  Telegraph.render = function(_, sender)
    order[#order + 1] = "telegraph" .. (sender == match.stacks[1] and 1 or 2)
  end
  return order, function()
    Telegraph.render = originalRender
  end
end

---@return ClientMatch
local function createRunningVersusClientMatch()
  local match = createVersusClientMatch()
  for _, stack in ipairs(match.stacks) do
    stack.engine:receiveConfirmedInput(string.rep(stack.engine:idleInput(), 10))
  end
  match:run()
  return match
end

-- attack sprites fly over the receiver's stack but under the cards, so the match draws every stack, then every telegraph,
-- then every stack's effects
local function testTelegraphsDrawBetweenStacksAndEffects()
  local match = createRunningVersusClientMatch()
  local order, restore = recordDrawOrder(match)
  local ok, err = pcall(match.render, match)
  restore()
  assert(ok, err)

  assert(table.concat(order, " ") == "stack1 stack2 telegraph1 telegraph2 effects1 effects2", table.concat(order, " "))
end

test(testTelegraphsDrawBetweenStacksAndEffects)

-- scenes that draw the stacks themselves share the telegraph and effects passes with the match
local function testRenderAttacksAndEffectsDrawsTelegraphsBeforeEffects()
  local match = createRunningVersusClientMatch()
  local order, restore = recordDrawOrder(match)
  local ok, err = pcall(match.renderAttacksAndEffects, match)
  restore()
  assert(ok, err)

  assert(table.concat(order, " ") == "telegraph1 telegraph2 effects1 effects2", table.concat(order, " "))
end

test(testRenderAttacksAndEffectsDrawsTelegraphsBeforeEffects)
