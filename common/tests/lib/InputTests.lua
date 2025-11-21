local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local input = require("client.src.inputManager")

-- NOTE: This test is currently disabled in testLauncher.lua because it requires client love callbacks.
-- Thus is hasn't been updated to get PlayerStack objects from createEndlessMatch so it was giving annotation warnings
-- when we update it and fix the warnings we can reenable

-- local processEvents = function()
--   if love.event then
--     love.event.pump()
--     for name, a, b, c, d, e, f in love.event.poll() do
--       if name == "quit" then
--         if not love.quit or not love.quit() then
--           return a or 0
--         end
--       end
--       love.handlers[name](a, b, c, d, e, f)
--     end
--   end
-- end

-- -- TODO: rewrite the test with sourcing the pressed keys from match.stacks[1].player.inputConfiguration
-- local function testSameFrameKeyPressRelease()
--   local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
--   local stack = match.stacks[1]
--   -- Stack instances from Match don't have .player or :send_controls() - these would be added dynamically in client context
--   ---@type any
--   local dynamicStack = stack
--   dynamicStack.player:restrictInputs(GAME.input.inputConfigurations[1])
--   -- advance past countdown
--   stack:receiveConfirmedInput(string.rep(stack:idleInput(), 200))
--   while stack.clock < 200 do
--     assert(not match:hasEnded(), "Game isn't expected to end yet")
--     assert(#stack.confirmedInput > stack.clock)
--     match:run()
--   end
--   assert(stack.clock == 200)
--   -- need local to be true to process input locally
--   stack.is_local = true
--   local raiseKey = GAME.input.inputConfigurations[1]["Raise1"]
--   assert(raiseKey ~= nil)
--   love.event.push("keypressed", raiseKey, raiseKey, false)
--   love.event.push("keyreleased", raiseKey, raiseKey, false)
--   processEvents()
--   input:update(1/60)
--   -- there is no way to directly control how many times match will run
--   -- so instead emulate the parts match would run but only once
--   dynamicStack:send_controls()
--   stack:run()
--   assert(stack.confirmedInput[201] == "g")
--   processEvents()
--   input:update(1/60)
--   dynamicStack:send_controls()
--   stack:run()
--   assert(stack.confirmedInput[202] == "A")
--   dynamicStack.player:unrestrictInputs()
-- end

-- testSameFrameKeyPressRelease()