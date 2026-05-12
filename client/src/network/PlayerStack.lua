local TouchDataEncoding = require("common.data.TouchDataEncoding")
---@class PlayerStack
local PlayerStack = require("client.src.PlayerStack")
local KeyDataEncoding = require("common.data.KeyDataEncoding")

function PlayerStack.handle_input_taunt(self)
  if self.inputMethod ~= "touch" then
    local input = self.player.inputConfiguration
    if input.isDown["TauntUp"] and self:can_taunt() and self.character.sounds.taunt_up then
      self.taunt_up = math.random(#self.character.sounds.taunt_up.sources)
      GAME.netClient:sendTauntUp(self.taunt_up)
    elseif input.isDown["TauntDown"] and self:can_taunt() and self.character.sounds.taunt_down then
      self.taunt_down = math.random(#self.character.sounds.taunt_down.sources)
      GAME.netClient:sendTauntDown(self.taunt_down)
    end
  end
end

local touchIdleInput = TouchDataEncoding.touchDataToLatinString(false, 0, 0, 6)
function PlayerStack.idleInput(self)
  return (self.inputMethod == "touch" and touchIdleInput) or KeyDataEncoding.base64encode[1]
end

-- Override of the base PlayerStack stub. Tells the server our stack reached
-- game over so it can stop relaying our (now-absent) inputs and let the
-- surviving stacks finish the match. Other players get the death applied
-- authoritatively via the D-event relay.
function PlayerStack:notifyServerStackEliminated()
  if not self.is_local then
    return
  end
  if self._stackEliminationSent then
    return
  end
  if not GAME.netClient or not GAME.netClient:isConnected() then
    return
  end
  self._stackEliminationSent = true
  GAME.netClient:sendDeathEvent({
    senderFrame = self.engine.game_over_clock,
    reason = "topOut",
  })
end

function PlayerStack:send_controls()
  local buffer_len = #self.engine.confirmedInput - self.engine.clock
  if buffer_len > 0 then
    return
  end

  local to_send
  if self.inputMethod == "controller" then
    local input = self.player.inputConfiguration
    to_send = KeyDataEncoding.base64encode[
      ((input.isDown["Raise1"] or input.isDown["Raise2"] or input.isPressed["Raise1"] or input.isPressed["Raise2"]) and 32 or 0) +
      ((input.isDown["Swap1"] or input.isDown["Swap2"]) and 16 or 0) +
      ((input.isDown["Up"] or input.isPressed["Up"]) and 8 or 0) +
      ((input.isDown["Down"] or input.isPressed["Down"]) and 4 or 0) +
      ((input.isDown["Left"] or input.isPressed["Left"]) and 2 or 0) +
      ((input.isDown["Right"] or input.isPressed["Right"]) and 1 or 0) + 1
    ]
  elseif self.inputMethod == "touch" then
    to_send = self.touchInputDetector:encodedCharacterForCurrentTouchInput()
  end
  GAME.netClient:sendInput(to_send)

  self:handle_input_taunt()

  self.engine:receiveConfirmedInput(to_send)
end