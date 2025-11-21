-- FocusDirector Mixin
--
-- Manages keyboard/controller focus for a container of focusable objects.
-- Use in tandem with Focusable.lua
--
-- Usage:
-- 1. Apply FocusDirector(container) to enable focus management
-- 2. Call container:setFocus(focusableObject, callback) to focus an object
-- 3. The focused object receives a dynamically assigned yieldFocus() method
-- 4. When yieldFocus() is called, focus is cleared and callback is executed
--
-- The director assigns yieldFocus() to the focused object, which:
-- - Sets object.hasFocus = false
-- - Clears director.focused = nil
-- - Executes optional callback function

local function directsFocus(uiElement)
  uiElement.focused = nil

  -- Sets focus to a focusable uiElement
  -- @param focusable The object to focus (must have been marked with Focusable mixin)
  -- @param callback Optional function to call when focus is yielded
  uiElement.setFocus = function(self, focusable, callback)
    -- Clear focus from currently focused object
    if self.focused then
      self.focused.hasFocus = false
    end

    self.focused = focusable

    if focusable then
      focusable.hasFocus = true
      -- Dynamically assign yieldFocus method to the focused object
      focusable.yieldFocus = function()
        focusable.hasFocus = false
        self.focused = nil
        if callback then
          callback()
        end
      end
    end
  end
end

return directsFocus